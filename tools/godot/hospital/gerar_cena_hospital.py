"""Monta o hospital inteiro: geometria (.gltf) + cena (.tscn).

    python3 tools/godot/hospital/gerar_cena_hospital.py

Sai:
    red-valve/assets/3d_model/stages/hospital/hospital_estrutura.gltf (+ .bin)
    red-valve/assets/3d_model/stages/hospital/pecas/*.gltf
    red-valve/scenes/stages/hospital/hospital.tscn

O .tscn resultante e' um arquivo NORMAL do Godot: da' pra abrir, mexer e salvar
pelo editor. Rodar este script de novo SOBRESCREVE — ele existe pra quando a
planta mudar (`planta.py`) e luz, movel, colisao e navmesh precisarem seguir
junto sem ninguem recolocar nada na mao.

==============================================================================
COMO A GEOMETRIA E' PARTIDA

Parede, piso e teto viram UM objeto por SETOR quadrado. O tamanho do setor nao
e' chutado: o script comeca grande e vai encolhendo ate' que nenhum setor seja
alcancado por mais de 8 luzes omni ou 8 spot, que e' o teto do renderer
`mobile` do projeto. Acima disso o Godot descarta luz em silencio, e o sintoma
no jogo e' a lampada que apaga sozinha quando o jogador anda pra tras.

Movel e' o contrario: agrupado por GEOMETRIA IGUAL. Todas as camas de hospital
sao o mesmo arquivo, instanciado N vezes.
"""

import hashlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gltf
import luzes as L
import materiais as M
import mobilia as MOB
import navmesh as NAV
import planta as P

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
BASE = os.path.join(RAIZ, "red-valve")
DIR_MODELO = os.path.join(BASE, "assets", "3d_model", "stages", "hospital")
DIR_PECAS = os.path.join(DIR_MODELO, "pecas")
SAIDA_CENA = os.path.join(BASE, "scenes", "stages", "hospital", "hospital.tscn")

RES_MODELO = "res://assets/3d_model/stages/hospital"
DADO = 1.35            # altura do azulejo de parede
LAJE_TETO = 0.15       # espessura visivel do forro
LIMITE_LUZ = 8


# ==========================================================================
# ferramentas de texto do .tscn
# ==========================================================================

def v3(v):
    return "Vector3(%s)" % ", ".join("%.4f" % c for c in v)


def cor(c):
    return "Color(%s)" % ", ".join("%.4f" % x for x in c)


# ==========================================================================
# ATENCAO: O Transform3D DO .tscn E' POR LINHAS
#
# No GDScript, `Transform3D(x_axis, y_axis, z_axis, origem)` recebe os EIXOS
# (as colunas da base). No arquivo de texto, os mesmos 12 numeros sao lidos
# como as LINHAS da base — ou seja, a transposta.
#
# Conferido rodando: `Transform3D(0,0,1, 0,1,0, -1,0,0)` escrito num .tscn
# chega no jogo com basis.x = (0,0,-1), que e' um giro de +90 e nao de -90.
#
# Emitir coluna aqui inverte o sinal de TODO giro em Y da cena de uma vez: a
# porta passa a abrir pelo lado errado, o movel encostado na parede vira de
# costas pra sala e o feixe de luz da janela aponta pra fora do predio. E como
# tudo inverte junto, a cena continua "parecendo certa" ate' alguem reparar
# que as macanetas estao do lado do batente.
#
# Por isso estas duas funcoes montam a matriz em LINHAS.
# ==========================================================================

def _matriz(x_eixo, y_eixo, z_eixo, pos):
    linhas = [x_eixo[0], y_eixo[0], z_eixo[0],
              x_eixo[1], y_eixo[1], z_eixo[1],
              x_eixo[2], y_eixo[2], z_eixo[2]]
    return "Transform3D(%s)" % ", ".join("%.5f" % n for n in linhas + list(pos))


def transform_pos(pos, giro_y=0.0, escala=1.0):
    c, s = math.cos(giro_y) * escala, math.sin(giro_y) * escala
    return _matriz((c, 0.0, -s), (0.0, escala, 0.0), (s, 0.0, c), pos)


def transform_olhando(pos, direcao):
    """Transform3D com o -Z do no' apontando pra `direcao` (luz do Godot
    ilumina pro proprio -Z)."""
    n = math.sqrt(sum(c * c for c in direcao)) or 1.0
    z = [-c / n for c in direcao]
    cima = (0.0, 0.0, 1.0) if abs(z[1]) > 0.985 else (0.0, 1.0, 0.0)
    x = [cima[1] * z[2] - cima[2] * z[1], cima[2] * z[0] - cima[0] * z[2],
         cima[0] * z[1] - cima[1] * z[0]]
    n = math.sqrt(sum(c * c for c in x)) or 1.0
    x = [c / n for c in x]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2],
         z[0] * x[1] - z[1] * x[0]]
    return _matriz(x, y, z, pos)


# ==========================================================================
# SETORES — o tamanho sai da conta de luz, nao do chute
# ==========================================================================

def _caixa_da_luz(luz):
    """AABB de influencia — CONE pro spot, esfera pro omni.

    A primeira versao media todo mundo como esfera e dava 12 spots por setor
    onde o Godot enxerga 3: spot apontado pro chao nao ilumina o teto atras
    dele, e o motor cula pela caixa do cone. Medir errado aqui faz o script
    picar a geometria em 232 pedacos sem necessidade nenhuma.
    """
    px, py, pz = luz["pos"]
    r = luz["alcance"]
    if luz["tipo"] == "OmniLight3D":
        return (px - r, px + r, py - r, py + r, pz - r, pz + r)
    dx, dy, dz = luz["mira"]
    n = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
    dx, dy, dz = dx / n, dy / n, dz / n
    raio = r * math.tan(math.radians(luz["angulo"]))
    fx, fy, fz = px + dx * r, py + dy * r, pz + dz * r
    return (min(px, fx - raio), max(px, fx + raio),
            min(py, fy - raio), max(py, fy + raio),
            min(pz, fz - raio), max(pz, fz + raio))


def _alcanca(luz, cx0, cx1, cy0, cy1, cz0, cz1):
    lx0, lx1, ly0, ly1, lz0, lz1 = _caixa_da_luz(luz)
    return (lx0 <= cx1 and cx0 <= lx1 and ly0 <= cy1 and cy0 <= ly1
            and lz0 <= cz1 and cz0 <= lz1)


def contar_luzes(cena, todas_luzes):
    """Pior caso de luz por MALHA, medido na caixa de verdade de cada uma.

    Medir pelo quadrado do setor (que foi a primeira versao) e' pessimista: um
    setor que so' tem uma laje de piso tem caixa de 15 cm de altura, e metade
    das luzes que cruzam o quadrado nao encosta nela. Medindo a malha, o mesmo
    predio passa com setor de 14 m em vez de 6 — 70% menos objeto.
    """
    pior_omni = pior_spot = 0
    pior_nome = None
    for obj in cena.objetos:
        if obj.vazio():
            continue
        mn, mx = obj.aabb()
        o = s = 0
        for luz in todas_luzes:
            if not _alcanca(luz, mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]):
                continue
            if luz["tipo"] == "OmniLight3D":
                o += 1
            else:
                s += 1
        if s > pior_spot or o > pior_omni:
            pior_nome = obj.nome
        pior_omni = max(pior_omni, o)
        pior_spot = max(pior_spot, s)
    return pior_omni, pior_spot, pior_nome


def montar_estrutura(tamanho):
    cena = gltf.Cena("../../../images/textures/polyhaven")
    M.registrar(cena, [M.ESTRUTURA, M.MOVEIS, M.LUMINARIAS])
    setores = Setores(cena, tamanho)
    colisoes = []
    colisoes += emitir_paredes(setores)
    emitir_janelas(setores)
    colisoes += emitir_lajes(setores)
    colisoes += emitir_poco(setores)
    colisoes += emitir_terraco(setores)
    return cena, setores, colisoes


class Setores:
    """Distribui caixas entre objetos de malha, um por setor."""

    def __init__(self, cena, tamanho):
        self.cena = cena
        self.tamanho = tamanho
        self.objetos = {}

    def _objeto(self, andar, i, j):
        chave = (andar, i, j)
        if chave not in self.objetos:
            self.objetos[chave] = self.cena.objeto(
                "est_a%d_%02d_%02d" % (andar, i, j))
        return self.objetos[chave]

    def caixa(self, andar, material, x0, x1, y0, y1, z0, z1, uv_escala=2.0):
        """Emite a caixa PARTIDA nas linhas do setor.

        Sem partir, uma parede de 50 m cairia inteira no setor do centro dela e
        levaria junto a luz de tres corredores.
        """
        t = self.tamanho
        cortes_x = self._cortes(x0, x1, t)
        cortes_z = self._cortes(z0, z1, t)
        for a in range(len(cortes_x) - 1):
            for b in range(len(cortes_z) - 1):
                ax0, ax1 = cortes_x[a], cortes_x[a + 1]
                az0, az1 = cortes_z[b], cortes_z[b + 1]
                if ax1 - ax0 < 1e-4 or az1 - az0 < 1e-4 or y1 - y0 < 1e-4:
                    continue
                i = int((ax0 + ax1) * 0.5 // t)
                j = int((az0 + az1) * 0.5 // t)
                self._objeto(andar, i, j).caixa(
                    material,
                    ((ax0 + ax1) * 0.5, (y0 + y1) * 0.5, (az0 + az1) * 0.5),
                    (ax1 - ax0, y1 - y0, az1 - az0),
                    uv_escala=uv_escala)

    @staticmethod
    def _cortes(a, b, t):
        pontos = [a]
        k = int(a // t) + 1
        while k * t < b - 1e-6:
            if k * t > a + 1e-6:
                pontos.append(k * t)
            k += 1
        pontos.append(b)
        return pontos


# ==========================================================================
# PAREDES
# ==========================================================================

def pedacos_do_muro(m):
    """Fatia o muro nos pedacos CHEIOS que sobram em volta dos vaos.

    A regra da casa (a mesma do gerador da igreja): parede com vao nao e' um
    retangulo furado, e' um monte de caixa em volta do buraco. Furo booleano
    daria normal invertida em algum canto e um buraco preto que so' aparece
    depois de a cena estar montada.
    """
    alto = P.PE
    vaos = sorted(m["vaos"], key=lambda v: v["c"])
    pedacos = []
    corrente = m["a"]
    for v in vaos:
        v0 = v["c"] - v["l"] * 0.5
        v1 = v["c"] + v["l"] * 0.5
        if v0 > corrente + 1e-4:
            pedacos.append((corrente, v0, 0.0, alto))
        if v["y0"] > 1e-4:
            pedacos.append((v0, v1, 0.0, v["y0"]))
        if v["y1"] < alto - 1e-4:
            pedacos.append((v0, v1, v["y1"], alto))
        corrente = max(corrente, v1)
    if corrente < m["b"] - 1e-4:
        pedacos.append((corrente, m["b"], 0.0, alto))
    return pedacos


def _espaco_em(x, z, andar):
    for e in P.espacos(andar):
        if e["x0"] - 0.01 <= x <= e["x1"] + 0.01 and \
                e["z0"] - 0.01 <= z <= e["z1"] + 0.01:
            return e
    return None


def _tipo_do_lado(m, a, b, lado):
    """Que comodo esta' deste lado do muro? Sonda um ponto 30 cm adentro."""
    meio = (a + b) * 0.5
    fora = m["esp"] * 0.5 + 0.30
    if m["eixo"] == "x":
        x, z = meio, m["coord"] + lado * fora
    else:
        x, z = m["coord"] + lado * fora, meio
    e = _espaco_em(x, z, m["andar"])
    return e["tipo"] if e else None


def emitir_paredes(setores):
    colisoes = []
    for m in P.muros():
        andar = m["andar"]
        base = P.cota(andar)
        esp = m["esp"]
        externa = m["tipo"] == "externa"
        # A parede externa sobe ate' cobrir a laje, senao a fachada fica com
        # uma fresta de 60 cm entre um andar e outro.
        topo_extra = P.LAJE if externa else 0.0

        for (a, b, y0, y1) in pedacos_do_muro(m):
            ya, yb = base + y0, base + y1
            if externa and y1 >= P.PE - 1e-4:
                yb += topo_extra
            # colisao: pedaco inteiro, espessura cheia
            colisoes.append(_caixa_colisao(m, a, b, ya, yb, esp))

            for lado in (-1, 1):
                tipo = _tipo_do_lado(m, a, b, lado) or "corredor"
                c0 = m["coord"] + (0.0 if lado > 0 else -esp * 0.5)
                c1 = m["coord"] + (esp * 0.5 if lado > 0 else 0.0)
                # dado embaixo, reboco em cima
                faixas = []
                corte = base + DADO
                if ya < corte:
                    faixas.append((ya, min(yb, corte), M.parede_de(tipo, False), 1.5))
                if yb > corte:
                    faixas.append((max(ya, corte), yb, M.parede_de(tipo, True), 2.6))
                for (fa, fb, mat, uv) in faixas:
                    if m["eixo"] == "x":
                        setores.caixa(andar, mat, a, b, fa, fb, c0, c1, uv)
                    else:
                        setores.caixa(andar, mat, c0, c1, fa, fb, a, b, uv)
                # friso sobre o dado, saliente 2 cm pra pegar luz rasante
                if ya < corte < yb:
                    s0 = c0 - (0.02 if lado < 0 else 0.0)
                    s1 = c1 + (0.02 if lado > 0 else 0.0)
                    if m["eixo"] == "x":
                        setores.caixa(andar, "friso", a, b, corte - 0.05,
                                      corte + 0.02, s0, s1, 1.0)
                    else:
                        setores.caixa(andar, "friso", s0, s1, corte - 0.05,
                                      corte + 0.02, a, b, 1.0)
    return colisoes


def _caixa_colisao(m, a, b, y0, y1, esp):
    if m["eixo"] == "x":
        return (a, b, y0, y1, m["coord"] - esp * 0.5, m["coord"] + esp * 0.5)
    return (m["coord"] - esp * 0.5, m["coord"] + esp * 0.5, y0, y1, a, b)


# ==========================================================================
# JANELAS: vidro, esquadria e peitoril
# ==========================================================================

def emitir_janelas(setores):
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        base = P.cota(m["andar"])
        esp = m["esp"]
        for v in m["vaos"]:
            if v["tipo"] != "janela":
                continue
            a, b = v["c"] - v["l"] * 0.5, v["c"] + v["l"] * 0.5
            y0, y1 = base + v["y0"], base + v["y1"]
            c = m["coord"]
            def caixa(x0, x1, ya, yb, z0, z1, mat, uv=1.0):
                setores.caixa(m["andar"], mat, x0, x1, ya, yb, z0, z1, uv)
            if m["eixo"] == "x":
                caixa(a, b, y0 + 0.04, y1 - 0.04, c - 0.03, c + 0.03, "vidro")
                caixa(a, b, y0, y0 + 0.06, c - esp * 0.5, c + esp * 0.5, "esquadria")
                caixa(a, b, y1 - 0.06, y1, c - esp * 0.5, c + esp * 0.5, "esquadria")
                for x in (a, b - 0.06):
                    caixa(x, x + 0.06, y0, y1, c - esp * 0.5, c + esp * 0.5, "esquadria")
                # peitoril virado pra dentro
                dentro = 1 if _espaco_em(v["c"], c + 0.6, m["andar"]) else -1
                caixa(a - 0.08, b + 0.08, y0 - 0.07, y0,
                      c + (0.0 if dentro > 0 else -0.28) + (0.0 if dentro > 0 else 0),
                      c + (0.28 if dentro > 0 else 0.0), "peitoril")
            else:
                caixa(c - 0.03, c + 0.03, y0 + 0.04, y1 - 0.04, a, b, "vidro")
                caixa(c - esp * 0.5, c + esp * 0.5, y0, y0 + 0.06, a, b, "esquadria")
                caixa(c - esp * 0.5, c + esp * 0.5, y1 - 0.06, y1, a, b, "esquadria")
                for z in (a, b - 0.06):
                    caixa(c - esp * 0.5, c + esp * 0.5, y0, y1, z, z + 0.06, "esquadria")
                dentro = 1 if _espaco_em(c + 0.6, v["c"], m["andar"]) else -1
                caixa(c + (0.0 if dentro > 0 else -0.28),
                      c + (0.28 if dentro > 0 else 0.0),
                      y0 - 0.07, y0, a - 0.08, b + 0.08, "peitoril")


# ==========================================================================
# PISO E TETO
# ==========================================================================

def emitir_lajes(setores):
    colisoes = []
    for andar in (1, 2):
        base = P.cota(andar)
        for e in P.espacos(andar):
            mat = M.piso_de(e["tipo"])
            setores.caixa(andar, mat, e["x0"], e["x1"], base - LAJE_TETO, base,
                          e["z0"], e["z1"], 2.4)
            colisoes.append((e["x0"], e["x1"], base - 0.45, base,
                             e["z0"], e["z1"]))
            teto = base + P.PE
            setores.caixa(andar, M.teto_de(e["tipo"]), e["x0"], e["x1"],
                          teto, teto + LAJE_TETO, e["z0"], e["z1"], 1.8)
            colisoes.append((e["x0"], e["x1"], teto, teto + 0.45,
                             e["z0"], e["z1"]))
    return colisoes


# ==========================================================================
# O POCO DO ELEVADOR
# ==========================================================================

def emitir_poco(setores):
    colisoes = []
    x0, x1 = P.POCO_X0, P.POCO_X1
    z0, z1 = P.POCO_Z0, P.POCO_Z1
    esp = P.PAREDE
    y_fundo = -1.10
    y_topo = P.ANDAR_2 + P.PE + 0.60

    def parede(ax0, ax1, az0, az1):
        setores.caixa(1, "poco_concreto", ax0, ax1, y_fundo, y_topo, az0, az1, 2.6)
        colisoes.append((ax0, ax1, y_fundo, y_topo, az0, az1))

    # --- A SOLEIRA
    #
    # O piso do corredor acaba em 55,65 (face interna da fachada) e o da cabine
    # comeca em 56,45. Sobra um rasgo de 80 cm bem no meio do vao do elevador —
    # e o jogador simplesmente NAO ATRAVESSA: ele encosta no nada, o corpo para
    # e a impressao e' de porta emperrada, nao de buraco.
    #
    # A soleira e' fixa (nao anda com a cabine) e isso e' seguro: a porta de
    # pavimento so' abre quando a cabine esta' naquele andar, entao nunca ha'
    # poco aberto atras dela.
    for andar in (1, 2):
        base = P.cota(andar)
        sx0, sx1 = P.PREDIO_X1 - P.PAREDE, P.CABINE_X0 + 0.20
        sz0 = P.POCO_PORTA_C - P.POCO_PORTA_L * 0.5 - 0.45
        sz1 = P.POCO_PORTA_C + P.POCO_PORTA_L * 0.5 + 0.45
        setores.caixa(andar, "cabine_piso", sx0, sx1, base - 0.18, base,
                      sz0, sz1, 1.6)
        colisoes.append((sx0, sx1, base - 0.45, base, sz0, sz1))

    parede(x0, x1, z0, z0 + esp)                 # norte
    parede(x0, x1, z1 - esp, z1)                 # sul
    parede(x1 - esp, x1, z0, z1)                 # leste
    # fundo do poco e laje de cobertura
    setores.caixa(1, "poco_concreto", x0, x1, y_fundo - 0.40, y_fundo,
                  z0, z1, 2.6)
    colisoes.append((x0, x1, y_fundo - 0.40, y_fundo, z0, z1))
    setores.caixa(1, "poco_concreto", x0, x1, y_topo, y_topo + 0.40, z0, z1, 2.6)
    colisoes.append((x0, x1, y_topo, y_topo + 0.40, z0, z1))
    return colisoes


def emitir_terraco(setores):
    """A calcada coberta da entrada principal.

    Ela existe por um motivo pratico antes de estetico: a entrada e' de vidro, e
    sem nada do lado de fora o jogador olha pela porta e ve o vazio. Com o
    tablado, a marquise e os pilares, o hall ganha profundidade e a fachada
    passa a ler como fachada de hospital.
    """
    colisoes = []
    x0, x1 = -9.0, 0.0
    z0, z1 = 24.0, 45.0
    setores.caixa(1, "piso_concreto", x0, x1, -0.18, 0.0, z0, z1, 3.0)
    colisoes.append((x0, x1, -0.45, 0.0, z0, z1))
    # tres degraus descendo pro lado de fora
    for i in range(3):
        y = -0.18 - i * 0.16
        setores.caixa(1, "piso_concreto", x0 - 0.5 - i * 0.5, x0 - i * 0.5,
                      y - 0.16, y, z0 + 4.0, z1 - 4.0, 3.0)
        colisoes.append((x0 - 0.5 - i * 0.5, x0 - i * 0.5, y - 0.45, y,
                         z0 + 4.0, z1 - 4.0))
    # marquise e pilares
    setores.caixa(1, "teto_concreto", x0 - 0.6, 0.0, P.PE + 0.2, P.PE + 0.6,
                  z0, z1, 3.0)
    colisoes.append((x0 - 0.6, 0.0, P.PE + 0.2, P.PE + 0.6, z0, z1))
    for z in (z0 + 1.6, z1 - 1.6, 29.6, 39.4):
        setores.caixa(1, "poco_concreto", x0 + 0.5, x0 + 1.1, 0.0, P.PE + 0.2,
                      z - 0.3, z + 0.3, 2.0)
        colisoes.append((x0 + 0.5, x0 + 1.1, 0.0, P.PE + 0.2, z - 0.3, z + 0.3))
    return colisoes


# ==========================================================================
# PECAS SOLTAS (movel, porta, cabine, luminaria) — uma malha por geometria
# ==========================================================================

class Pecas:
    """Junta geometrias iguais num arquivo so'.

    A chave e' o hash da lista de caixas. Dez camas identicas viram um .gltf
    instanciado dez vezes, e ninguem precisou dizer que sao iguais.
    """

    def __init__(self):
        self.arquivos = {}    # hash -> (nome, pecas)

    def registrar(self, prefixo, pecas):
        assinatura = hashlib.md5(
            repr([_normalizar(p) for p in pecas]).encode()).hexdigest()[:10]
        if assinatura not in self.arquivos:
            self.arquivos[assinatura] = ("%s_%s" % (prefixo, assinatura), pecas)
        return self.arquivos[assinatura][0]

    def escrever(self, materiais):
        os.makedirs(DIR_PECAS, exist_ok=True)
        # Apaga o que sobrou de geracoes anteriores. O nome de cada peca vem do
        # hash da geometria, entao mudar uma cama gera um arquivo NOVO e
        # abandona o antigo — sem esta limpeza a pasta so' cresce, e o Godot
        # continua importando e guardando dezenas de malhas que a cena nao
        # referencia mais.
        vivos = {nome for (nome, _p) in self.arquivos.values()}
        for f in sorted(os.listdir(DIR_PECAS)):
            base = f.split(".")[0]
            if base and base not in vivos:
                os.remove(os.path.join(DIR_PECAS, f))
        total = 0
        for (nome, pecas) in self.arquivos.values():
            cena = gltf.Cena("../../../../images/textures/polyhaven")
            M.registrar(cena, materiais)
            obj = cena.objeto(nome)
            for p in pecas:
                d = _normalizar(p)
                obj.caixa(d["mat"], d["pos"], d["tam"], d["giro"], uv="local")
            total += cena.salvar(os.path.join(DIR_PECAS, nome + ".gltf"))
        return total


def _normalizar(p):
    """Aceita tanto a tupla curta quanto o dicionario com giro proprio."""
    if isinstance(p, dict):
        return {"pos": tuple(p["pos"]), "tam": tuple(p["tam"]),
                "giro": p.get("giro", 0.0), "mat": p["mat"]}
    dx, dy, dz, sx, sy, sz, mat = p
    return {"pos": (dx, dy, dz), "tam": (sx, sy, sz), "giro": 0.0, "mat": mat}


# ==========================================================================
# PORTAS
# ==========================================================================

def folha_de_porta(largura, altura=P.PORTA_H - 0.05):
    """Folha com a DOBRADICA na origem: ela cresce pro +X local.

    Assim o no' do pivo so' precisa girar em torno de si mesmo, e a mesma malha
    serve pras duas folhas de uma porta dupla — a segunda nasce virada 180 graus.
    """
    e = 0.055
    p = [(largura * 0.5, altura * 0.5, 0.0, largura, altura, e, "porta_folha")]
    # visor de vidro, que e' o que faz porta de hospital parecer de hospital
    p.append((largura * 0.5, altura * 0.72, 0.0,
              largura * 0.46, altura * 0.26, e + 0.012, "vidro"))
    # chapa de chute embaixo
    p.append((largura * 0.5, 0.18, 0.0, largura - 0.06, 0.30, e + 0.014,
              "porta_metal"))
    # macaneta dos dois lados
    for lado in (-1, 1):
        p.append((largura - 0.16, altura * 0.42, lado * (e * 0.5 + 0.045),
                  0.20, 0.045, 0.09, "porta_metal"))
    return p


def portas_da_planta():
    saida = []
    for m in P.muros():
        for v in m["vaos"]:
            if v["tipo"] != "porta":
                continue
            base = P.cota(m["andar"])
            # eixo "x": o muro corre em X, entao a normal dele e' Z. O no' da
            # porta nasce com +X ao longo do vao e +Z pra fora — e' desse
            # acordo que o script tira pra que lado abrir.
            giro = 0.0 if m["eixo"] == "x" else math.pi * 0.5
            if m["eixo"] == "x":
                pos = (v["c"], base, m["coord"])
            else:
                pos = (m["coord"], base, v["c"])
            saida.append({"ident": v["ident"], "sala": v["sala"],
                          "chave": _chave_da_sala(v["sala"]),
                          "pos": pos, "giro": giro, "largura": v["l"],
                          "dupla": v["dupla"], "andar": m["andar"],
                          "trancada": v.get("trancada", False),
                          "saida": v.get("saida", False),
                          "eixo": m["eixo"], "coord": m["coord"], "c": v["c"]})
    return saida


def _chave_da_sala(ident):
    s = P.por_ident(ident)
    return s["chave"] if s and s.get("chave") else "HOSP_SALA_GENERICA"


# ==========================================================================
# CABINE DO ELEVADOR
# ==========================================================================

CABINE_L = 5.10        # lado util da cabine
CABINE_H = 2.90
CABINE_PORTA_L = 2.20


def pecas_da_cabine():
    """Cabine com a boca virada pro -X (o predio fica a oeste do poco)."""
    h = CABINE_L * 0.5
    p = []
    p.append((0.0, -0.09, 0.0, CABINE_L, 0.18, CABINE_L, "cabine_piso"))
    p.append((0.0, CABINE_H + 0.09, 0.0, CABINE_L, 0.18, CABINE_L, "cabine_parede"))
    # fundo (leste) e as duas laterais
    p.append((h - 0.06, CABINE_H * 0.5, 0.0, 0.12, CABINE_H, CABINE_L, "cabine_parede"))
    for lado in (-1, 1):
        p.append((0.0, CABINE_H * 0.5, lado * (h - 0.06), CABINE_L, CABINE_H, 0.12,
                  "cabine_parede"))
    # frente (oeste): so' as ombreiras, o meio e' a porta
    ombro = (CABINE_L - CABINE_PORTA_L) * 0.5
    for lado in (-1, 1):
        p.append((-h + 0.06, CABINE_H * 0.5,
                  lado * (CABINE_L - ombro) * 0.5, 0.12, CABINE_H, ombro,
                  "cabine_parede"))
    p.append((-h + 0.06, (CABINE_H + P.PORTA_H) * 0.5 + 0.02, 0.0,
              0.12, CABINE_H - P.PORTA_H - 0.04, CABINE_PORTA_L, "cabine_parede"))
    # corrimao nas tres paredes fechadas
    p.append((h - 0.18, 0.92, 0.0, 0.10, 0.08, CABINE_L - 0.4, "mat_inox"))
    for lado in (-1, 1):
        p.append((0.0, 0.92, lado * (h - 0.18), CABINE_L - 0.4, 0.08, 0.10,
                  "mat_inox"))
    # forro luminoso
    p.append((0.0, CABINE_H - 0.06, 0.0, CABINE_L - 1.0, 0.06, CABINE_L - 1.0,
              "lum_forro_cabine"))
    return p


def pecas_do_painel():
    """Painel de botoes, na lateral direita de quem entra."""
    p = [(0.0, 1.30, 0.0, 0.06, 0.78, 0.30, "mat_inox")]
    for i in range(2):
        p.append((0.045, 1.52 - i * 0.30, 0.0, 0.03, 0.12, 0.12, "mat_botao"))
    return p


def pecas_da_folha_corredica(largura, altura=P.PORTA_H):
    return [(0.0, altura * 0.5, 0.0, 0.10, altura, largura, "porta_metal"),
            (0.055, altura * 0.60, 0.0, 0.02, 0.44, largura * 0.5, "vidro")]


# ==========================================================================
# LUMINARIAS
# ==========================================================================

def pecas_da_luminaria(lum):
    comp = lum["comprimento"]
    if lum.get("vermelha"):
        return [(0.0, 0.0, 0.0, 0.34, 0.18, 0.22, "lum_corpo"),
                (0.0, 0.0, 0.12, 0.26, 0.12, 0.04, "lum_vermelha")]
    tubo = "lum_tubo_aceso" if lum["acesa"] else "lum_tubo_morto"
    if lum["eixo"] == "x":
        corpo = (comp, 0.10, 0.34)
        vidro = (comp - 0.12, 0.05, 0.24)
    else:
        corpo = (0.34, 0.10, comp)
        vidro = (0.24, 0.05, comp - 0.12)
    return [(0.0, 0.05, 0.0, corpo[0], corpo[1], corpo[2], "lum_corpo"),
            (0.0, -0.02, 0.0, vidro[0], vidro[1], vidro[2], tubo)]


# ==========================================================================
# GERACAO
# ==========================================================================

def gerar():
    print("== luzes ==")
    plano_luz = L.montar()
    todas_luzes = L.so_luzes(plano_luz)
    lista_luminarias = L.luminarias(plano_luz)
    print("  %d luzes, %d luminarias" % (len(todas_luzes), len(lista_luminarias)))

    print("== estrutura: escolhendo o tamanho do setor ==")
    melhor = None
    for tamanho in (20.0, 18.0, 16.0, 14.0, 12.0, 10.0, 8.0, 6.0):
        cena, setores, colisoes = montar_estrutura(tamanho)
        o, s, onde = contar_luzes(cena, todas_luzes)
        print("  setor de %.0f m: pior malha ve %d omni e %d spot (%s)"
              % (tamanho, o, s, onde))
        melhor = (tamanho, cena, setores, colisoes)
        if o <= LIMITE_LUZ and s <= LIMITE_LUZ:
            break
    tamanho, cena, setores, colisoes = melhor
    print("  setor escolhido: %.0f m" % tamanho)
    os.makedirs(DIR_MODELO, exist_ok=True)
    tris = cena.salvar(os.path.join(DIR_MODELO, "hospital_estrutura.gltf"))
    vivos = [o for o in cena.objetos if not o.vazio()]
    print("  %d objetos de setor, %d triangulos, %d caixas de colisao"
          % (len(vivos), tris, len(colisoes)))

    print("== moveis ==")
    props = MOB.mobiliar()
    pecas = Pecas()
    for p in props:
        if p["tipo"].startswith("caixas"):
            p["arquivo"] = pecas.registrar("mov", p["pecas"])
    portas = portas_da_planta()
    for d in portas:
        larg = d["largura"] * (0.5 if d["dupla"] else 1.0)
        d["arquivo"] = pecas.registrar("folha", folha_de_porta(larg))
        d["larg_folha"] = larg
    for lum in lista_luminarias:
        lum["arquivo"] = pecas.registrar("lum", pecas_da_luminaria(lum))
    arq_cabine = pecas.registrar("cabine", pecas_da_cabine())
    arq_painel = pecas.registrar("painel", pecas_do_painel())
    arq_corredica = pecas.registrar("corredica",
                                    pecas_da_folha_corredica(CABINE_PORTA_L * 0.5))
    tris_pecas = pecas.escrever([M.ESTRUTURA, M.MOVEIS, M.LUMINARIAS])
    print("  %d moveis, %d geometrias distintas, %d triangulos"
          % (len(props), len(pecas.arquivos), tris_pecas))
    print("  %d portas (%d duplas)"
          % (len(portas), sum(1 for d in portas if d["dupla"])))

    print("== navmesh ==")
    navs = {}
    for andar in (1, 2):
        navs[andar] = NAV.malha(andar, props)

    print("== cena ==")
    escrever_cena(cena, setores, colisoes, props, portas, plano_luz,
                  lista_luminarias, navs,
                  {"cabine": arq_cabine, "painel": arq_painel,
                   "corredica": arq_corredica})
    print("  gravado: %s" % SAIDA_CENA)


# ==========================================================================
# O .tscn
# ==========================================================================

def escrever_cena(cena_gltf, setores, colisoes, props, portas, plano_luz,
                  lista_luminarias, navs, elevador):
    externos = []
    ids = {}

    def externo(tipo, caminho):
        if caminho in ids:
            return ids[caminho]
        ident = "e%d" % len(externos)
        externos.append((tipo, caminho, ident))
        ids[caminho] = ident
        return ident

    id_player = externo("PackedScene", "res://scenes/player/player.tscn")
    id_pause = externo("PackedScene", "res://scenes/configs/pause.tscn")
    id_fade = externo("PackedScene", "res://scenes/configs/fade.tscn")
    id_script = externo("Script", "res://scripts/stages/hospital/hospital.gd")
    id_porta_gd = externo("Script", "res://scripts/stages/hospital/porta_hospital.gd")
    id_elev_gd = externo("Script", "res://scripts/stages/hospital/elevador_hospital.gd")
    id_estrutura = externo("PackedScene", RES_MODELO + "/hospital_estrutura.gltf")
    id_ambiente = externo("AudioStream",
                          "res://assets/sounds/episodios/ambiente_noise_sublime.mp3")

    def peca(nome):
        return externo("PackedScene", "%s/pecas/%s.gltf" % (RES_MODELO, nome))

    sub = []
    formas = {}

    def forma(lx, ly, lz):
        chave = (round(lx, 3), round(ly, 3), round(lz, 3))
        if chave not in formas:
            ident = "f%d" % len(formas)
            formas[chave] = ident
            sub.append((ident, "BoxShape3D",
                        ["size = %s" % v3(chave)]))
        return formas[chave]

    _ambiente(sub)
    familias_cone, malhas_cone = _cones(sub, L.so_luzes(plano_luz))
    _navmesh(sub, navs)
    _poeira(sub)

    # Os nos vao pra uma lista PROPRIA e o cabecalho e' montado so' no fim.
    # Motivo: `forma()` e `peca()` criam sub_resource e ext_resource enquanto os
    # nos sao escritos. Montando o cabecalho antes, nenhuma das 190 BoxShape3D
    # de colisao chegava ao arquivo — e o Godot recusava a cena inteira com um
    # "Invalid parameter" apontando pro primeiro no' que citava uma delas.
    linhas = []

    def no(nome, tipo=None, pai=None, instancia=None, props_=(), metas=()):
        cab = '[node name="%s"' % nome
        if tipo:
            cab += ' type="%s"' % tipo
        if pai:
            cab += ' parent="%s"' % pai
        if instancia:
            cab += ' instance=ExtResource("%s")' % instancia
        linhas.append(cab + "]")
        for chave, valor in props_:
            linhas.append("%s = %s" % (chave, valor))
        for chave, valor in metas:
            linhas.append('metadata/%s = %s' % (chave, valor))
        linhas.append("")

    # ---- raiz
    no("hospital", tipo="Node3D", props_=[("script", 'ExtResource("%s")' % id_script)])
    no("WorldEnvironment", tipo="WorldEnvironment", pai=".",
       props_=[("environment", 'SubResource("ambiente")')])
    no("Pause", pai=".", instancia=id_pause)
    no("fade", pai=".", instancia=id_fade)

    entrada = _ponto_de_entrada()
    no("Player", pai=".", instancia=id_player,
       props_=[("transform", transform_pos(entrada, _giro_de_entrada()))])

    no("estrutura", pai=".", instancia=id_estrutura)

    # ---- colisao da estrutura
    no("colisao", tipo="StaticBody3D", pai=".",
       props_=[("collision_layer", "2"), ("collision_mask", "0")])
    for i, (x0, x1, y0, y1, z0, z1) in enumerate(colisoes):
        ident = forma(x1 - x0, y1 - y0, z1 - z0)
        no("c%d" % i, tipo="CollisionShape3D", pai="colisao",
           props_=[("transform", transform_pos(((x0 + x1) * 0.5, (y0 + y1) * 0.5,
                                                (z0 + z1) * 0.5))),
                   ("shape", 'SubResource("%s")' % ident)])

    # ---- moveis
    no("mobilia", tipo="Node3D", pai=".")
    no("colisao_mobilia", tipo="StaticBody3D", pai=".",
       props_=[("collision_layer", "2"), ("collision_mask", "0")])
    usados = set()
    n_bloqueio = 0
    for i, p in enumerate(props):
        nome = "%s_%s" % (p["sala"], p["nome"])
        if nome in usados:
            nome += "_%d" % i
        usados.add(nome)
        y = p["y"] + p.get("dy", 0.0)
        if p["tipo"].startswith("caixas"):
            id_peca = peca(p["arquivo"])
        else:
            id_peca = externo("PackedScene", MOB.caminho(p["modelo"]))
        no(nome, pai="mobilia", instancia=id_peca,
           props_=[("transform", transform_pos((p["x"], y, p["z"]), p["giro"],
                                               p.get("escala", 1.0)))])
        if p.get("bloqueia"):
            lx, lz = p["bloqueia"]
            ident = forma(lx, 1.6, lz)
            no("cm%d" % n_bloqueio, tipo="CollisionShape3D", pai="colisao_mobilia",
               props_=[("transform", transform_pos((p["x"], p["y"] + 0.8, p["z"]))),
                       ("shape", 'SubResource("%s")' % ident)])
            n_bloqueio += 1

    # ---- luminarias
    no("luminarias", tipo="Node3D", pai=".")
    for i, lum in enumerate(lista_luminarias):
        giro = 0.0 if lum["eixo"] == "x" else math.pi * 0.5
        no("lum_%d" % i, pai="luminarias", instancia=peca(lum["arquivo"]),
           props_=[("transform", transform_pos(lum["pos"], giro))])

    # ---- cones de luz (o "volumetrico" possivel no renderer mobile)
    no("cones", tipo="Node3D", pai=".")
    for chave, grupo in familias_cone.items():
        ident_malha, altura = malhas_cone[chave]
        for luz in grupo:
            x, y, z = luz["pos"]
            no("cone_" + luz["nome"], tipo="MeshInstance3D", pai="cones",
               props_=[("transform", transform_pos((x, y - altura * 0.5, z))),
                       ("mesh", 'SubResource("%s")' % ident_malha),
                       ("cast_shadow", "0")])

    # ---- luzes
    no("luzes", tipo="Node3D", pai=".")
    for luz in L.so_luzes(plano_luz):
        props_ = [("light_color", cor(luz["cor"])),
                  ("light_energy", "%.3f" % luz["energia"]),
                  ("light_volumetric_fog_energy", "%.2f" % luz["fog"]),
                  ("shadow_enabled", "true" if luz["sombra"] else "false"),
                  ("distance_fade_enabled", "true"),
                  ("distance_fade_begin", "24.0"),
                  ("distance_fade_shadow", "14.0"),
                  ("distance_fade_length", "8.0")]
        if luz["tipo"] == "OmniLight3D":
            props_.append(("omni_range", "%.2f" % luz["alcance"]))
            props_.append(("omni_attenuation", "1.35"))
            xform = transform_pos(luz["pos"])
        else:
            props_.append(("spot_range", "%.2f" % luz["alcance"]))
            props_.append(("spot_angle", "%.1f" % luz["angulo"]))
            props_.append(("spot_angle_attenuation", "0.9"))
            props_.append(("spot_attenuation", "%.2f" % L.QUEDA_TETO))
            props_.append(("shadow_bias", "0.05"))
            props_.append(("shadow_normal_bias", "1.4"))
            xform = transform_olhando(luz["pos"], luz["mira"])
        metas = []
        if luz["piscar"]:
            metas.append(("piscar", '"%s"' % luz["piscar"]))
        no(luz["nome"], tipo=luz["tipo"], pai="luzes",
           props_=[("transform", xform)] + props_, metas=metas)

    # ---- portas
    no("portas", tipo="Node3D", pai=".")
    for d in portas:
        _emitir_porta(no, peca, forma, d, id_porta_gd)

    # ---- elevador
    _emitir_elevador(no, peca, forma, elevador, id_elev_gd)

    # ---- navegacao
    no("NavigationRegion3D", tipo="NavigationRegion3D", pai=".",
       props_=[("navigation_mesh", 'SubResource("navmesh")'),
               ("navigation_layers", "4")])

    # ---- poeira e som
    for andar in (1, 2):
        no("poeira_%d" % andar, tipo="GPUParticles3D", pai=".",
           props_=[("transform", transform_pos((28.0, P.cota(andar) + 1.6, 30.0))),
                   ("amount", "900"), ("lifetime", "16.0"), ("preprocess", "9.0"),
                   ("visibility_aabb", "AABB(-30, -2.5, -32, 60, 5, 64)"),
                   ("process_material", 'SubResource("poeira_proc")'),
                   ("draw_pass_1", 'SubResource("poeira_quad")')])
    no("ambiencia", tipo="AudioStreamPlayer", pai=".",
       props_=[("stream", 'ExtResource("%s")' % id_ambiente),
               ("volume_db", "-14.0"), ("autoplay", "true")])

    cabecalho = ["[gd_scene load_steps=%d format=3]"
                 % (len(externos) + len(sub) + 1), ""]
    for tipo, caminho, ident in externos:
        cabecalho.append('[ext_resource type="%s" path="%s" id="%s"]'
                         % (tipo, caminho, ident))
    cabecalho.append("")
    for ident, tipo, corpo in sub:
        cabecalho.append('[sub_resource type="%s" id="%s"]' % (tipo, ident))
        cabecalho.extend(corpo)
        cabecalho.append("")

    os.makedirs(os.path.dirname(SAIDA_CENA), exist_ok=True)
    with open(SAIDA_CENA, "w") as fp:
        fp.write("\n".join(cabecalho + linhas))


def _ponto_de_entrada():
    """Dentro do hall, de costas pra porta da rua, olhando pra recepcao.

    Da' pra nascer em outro lugar sem mexer no codigo, o que economiza muita
    caminhada quando se esta' testando uma porta do outro lado do predio:

        HOSPITAL_SPAWN="40.3,1.05,38,180" tools/godot/hospital/construir.sh

    (x, y, z, giro em graus). Sem a variavel, vale o hall.

    A cota X nao e' 3,4 (colado na porta) por um motivo de leitura: ali o
    jogador nasce no vao entre a fachada e a primeira luminaria, ou seja, no
    escuro, de cara pra uma parede. Dois metros adiante ele nasce na borda da
    primeira poca de luz, com o balcao redondo da recepcao ja' no campo de
    visao — que e' a imagem que apresenta o lugar.
    """
    teste = os.environ.get("HOSPITAL_SPAWN")
    if teste:
        n = [float(v) for v in teste.split(",")]
        return (n[0], n[1], n[2])
    return (6.0, P.ANDAR_1 + 1.05, 34.20)


def _giro_de_entrada():
    teste = os.environ.get("HOSPITAL_SPAWN")
    if teste:
        n = [float(v) for v in teste.split(",")]
        if len(n) > 3:
            return math.radians(n[3])
    return -math.pi * 0.5


def _emitir_porta(no, peca, forma, d, id_script):
    caminho = "portas/" + d["ident"]
    metas = [("sala", '"%s"' % d["chave"]),
             ("largura", "%.3f" % d["largura"]),
             ("dupla", "true" if d["dupla"] else "false"),
             ("trancada", "true" if d["trancada"] else "false"),
             ("saida", "true" if d["saida"] else "false")]
    no(d["ident"], tipo="Node3D", pai="portas",
       props_=[("transform", transform_pos(d["pos"], d["giro"])),
               ("script", 'ExtResource("%s")' % id_script)], metas=metas)

    meia = d["largura"] * 0.5
    folhas = [("pivo", -meia, 0.0)]
    if d["dupla"]:
        folhas.append(("pivo_b", meia, math.pi))

    for (nome, dx, giro) in folhas:
        no(nome, tipo="Node3D", pai=caminho,
           props_=[("transform", transform_pos((dx, 0.0, 0.0), giro))])
        no("folha", pai=caminho + "/" + nome, instancia=peca(d["arquivo"]))
        corpo = caminho + "/" + nome + "/corpo"
        no("corpo", tipo="AnimatableBody3D", pai=caminho + "/" + nome,
           props_=[("collision_layer", "2"), ("collision_mask", "0"),
                   ("sync_to_physics", "false")])
        ident = forma(d["larg_folha"], P.PORTA_H - 0.05, 0.08)
        no("forma", tipo="CollisionShape3D", pai=corpo,
           props_=[("transform", transform_pos((d["larg_folha"] * 0.5,
                                                (P.PORTA_H - 0.05) * 0.5, 0.0))),
                   ("shape", 'SubResource("%s")' % ident)])

    # A area cobre os DOIS lados do vao: e' ela que acende o "abrir porta", e
    # o jogador pode chegar por dentro ou por fora.
    #
    # Ela e' JUSTA de proposito (0,3 m de folga lateral, 1,2 m pra cada lado do
    # muro). Na primeira versao tinha 3,2 m de profundidade e 1,4 de folga, e
    # ali onde o corredor leste passa rente a' porta do pronto-socorro a area
    # da porta alcancava o vao do elevador: os dois prompts apareciam juntos na
    # tela e um unico "aceitar" disparava os dois.
    ident = forma(d["largura"] + 0.6, P.PORTA_H, 2.4)
    no("area", tipo="Area3D", pai=caminho,
       props_=[("transform", transform_pos((0.0, P.PORTA_H * 0.5, 0.0))),
               ("collision_layer", "0"), ("monitorable", "false")])
    no("forma", tipo="CollisionShape3D", pai=caminho + "/area",
       props_=[("shape", 'SubResource("%s")' % ident)])


def _emitir_elevador(no, peca, forma, arquivos, id_script):
    cx = (P.CABINE_X0 + P.CABINE_X1) * 0.5
    cz = P.POCO_PORTA_C
    # `process_physics_priority` alto = roda DEPOIS de todo mundo no quadro de
    # fisica, inclusive depois do `move_and_slide()` do jogador. E' isso que faz
    # o passageiro subir: o elevador soma a altura da cabine na posicao dele
    # DEPOIS que a gravidade ja' terminou de puxa-lo pra baixo. Com a prioridade
    # padrao a ordem se inverte e o move_and_slide desfaz a subida todo quadro —
    # a cabine ia embora e o jogador ficava no poco.
    no("elevador", tipo="Node3D", pai=".",
       props_=[("transform", transform_pos((cx, 0.0, cz))),
               ("process_physics_priority", "100"),
               ("script", 'ExtResource("%s")' % id_script)],
       metas=[("andar_1", "%.3f" % P.ANDAR_1),
              ("andar_2", "%.3f" % P.ANDAR_2)])

    # --- a cabine (anda em Y)
    no("cabine", tipo="Node3D", pai="elevador")
    no("corpo", pai="elevador/cabine", instancia=peca(arquivos["cabine"]))
    # `sync_to_physics` FALSO de proposito. Ligado, o AnimatableBody3D passa a
    # se mover sozinho pelo servidor de fisica e ignora o no' PAI — e aqui quem
    # anda e' o pai (a cabine inteira). O resultado era um colisor de chao que
    # ficava parado no terreo enquanto a cabine subia: o jogador continuava
    # apoiado no nada, no nivel de baixo.
    no("chao", tipo="AnimatableBody3D", pai="elevador/cabine",
       props_=[("collision_layer", "2"), ("collision_mask", "0"),
               ("sync_to_physics", "false")])
    ident = forma(CABINE_L, 0.20, CABINE_L)
    no("forma", tipo="CollisionShape3D", pai="elevador/cabine/chao",
       props_=[("transform", transform_pos((0.0, -0.10, 0.0))),
               ("shape", 'SubResource("%s")' % ident)])
    # paredes da cabine: solidas, senao o jogador atravessa a lateral em
    # movimento e cai dentro do poco
    ident_lat = forma(CABINE_L, CABINE_H, 0.14)
    for nome, dz in (("lat_n", -CABINE_L * 0.5), ("lat_s", CABINE_L * 0.5)):
        no(nome, tipo="CollisionShape3D", pai="elevador/cabine/chao",
           props_=[("transform", transform_pos((0.0, CABINE_H * 0.5, dz))),
                   ("shape", 'SubResource("%s")' % ident_lat)])
    ident_fundo = forma(0.14, CABINE_H, CABINE_L)
    no("fundo", tipo="CollisionShape3D", pai="elevador/cabine/chao",
       props_=[("transform", transform_pos((CABINE_L * 0.5, CABINE_H * 0.5, 0.0))),
               ("shape", 'SubResource("%s")' % ident_fundo)])

    no("painel", pai="elevador/cabine",
       instancia=peca(arquivos["painel"]),
       props_=[("transform", transform_pos((-CABINE_L * 0.5 + 0.22, 0.0,
                                            CABINE_PORTA_L * 0.5 + 0.55)))])
    no("luz_cabine", tipo="OmniLight3D", pai="elevador/cabine",
       props_=[("transform", transform_pos((0.0, CABINE_H - 0.35, 0.0))),
               ("light_color", cor(L.FLUOR)),
               ("light_energy", "3.0"), ("omni_range", "7.5"),
               ("light_volumetric_fog_energy", "1.4"),
               ("shadow_enabled", "false")],
       metas=[("piscar", '"nervoso"')])
    ident_dentro = forma(CABINE_L - 0.6, 2.4, CABINE_L - 0.6)
    no("area_dentro", tipo="Area3D", pai="elevador/cabine",
       props_=[("transform", transform_pos((0.0, 1.2, 0.0))),
               ("collision_layer", "0"), ("monitorable", "false")])
    no("forma", tipo="CollisionShape3D", pai="elevador/cabine/area_dentro",
       props_=[("shape", 'SubResource("%s")' % ident_dentro)])

    # portas da cabine (corredicas)
    no("portas_cabine", tipo="Node3D", pai="elevador/cabine")
    _corredicas(no, peca, forma, arquivos, "elevador/cabine/portas_cabine",
                -CABINE_L * 0.5 + 0.06)

    # --- portas de pavimento, uma por andar
    for andar in (1, 2):
        base = P.cota(andar)
        pai = "elevador/pavimento_%d" % andar
        no("pavimento_%d" % andar, tipo="Node3D", pai="elevador",
           props_=[("transform", transform_pos((0.0, base, 0.0)))])
        _corredicas(no, peca, forma, arquivos, pai,
                    -(P.CABINE_X1 - P.CABINE_X0) * 0.5 - P.PAREDE * 0.5)
        ident_ch = forma(2.6, P.PORTA_H, P.POCO_PORTA_L + 1.4)
        no("area_chamar", tipo="Area3D", pai=pai,
           props_=[("transform", transform_pos(
               (-(P.CABINE_X1 - P.CABINE_X0) * 0.5 - 1.5, P.PORTA_H * 0.5, 0.0))),
               ("collision_layer", "0"), ("monitorable", "false")])
        no("forma", tipo="CollisionShape3D", pai=pai + "/area_chamar",
           props_=[("shape", 'SubResource("%s")' % ident_ch)])


def _corredicas(no, peca, forma, arquivos, pai, dx):
    """Duas folhas que correm pros lados a partir do centro do vao."""
    meia = CABINE_PORTA_L * 0.5
    for nome, lado in (("folha_n", -1.0), ("folha_s", 1.0)):
        no(nome, tipo="Node3D", pai=pai,
           props_=[("transform", transform_pos((dx, 0.0, lado * meia * 0.5)))])
        no("malha", pai=pai + "/" + nome, instancia=peca(arquivos["corredica"]))
        no("corpo", tipo="AnimatableBody3D", pai=pai + "/" + nome,
           props_=[("collision_layer", "2"), ("collision_mask", "0"),
                   ("sync_to_physics", "false")])
        ident = forma(0.12, P.PORTA_H, meia)
        no("forma", tipo="CollisionShape3D", pai=pai + "/" + nome + "/corpo",
           props_=[("transform", transform_pos((0.0, P.PORTA_H * 0.5, 0.0))),
                   ("shape", 'SubResource("%s")' % ident)])


# ==========================================================================
# sub_resources fixos
# ==========================================================================

def _ambiente(sub):
    sub.append(("ceu_mat", "ProceduralSkyMaterial", [
        "sky_top_color = Color(0.035, 0.04, 0.06, 1)",
        "sky_horizon_color = Color(0.09, 0.10, 0.14, 1)",
        "sky_curve = 0.15",
        "ground_bottom_color = Color(0.02, 0.02, 0.03, 1)",
        "ground_horizon_color = Color(0.06, 0.07, 0.09, 1)",
        "sun_angle_max = 2.0",
        "use_debanding = true",
    ]))
    sub.append(("ceu", "Sky", ['sky_material = SubResource("ceu_mat")']))
    # ==================================================================
    # O QUE NAO ESTA' AQUI, E POR QUE
    #
    # O projeto roda em `rendering_method="mobile"` (project.godot). Nevoa
    # VOLUMETRICA, SSAO, SSIL, SSR e SDFGI sao exclusivos do Forward+: no
    # mobile eles nao fazem nada e ainda avisam no console a cada carga.
    #
    # Isso muda o jeito de fazer o clima. O feixe de luz no ar, que num
    # Forward+ sairia de graca da nevoa volumetrica, aqui e' GEOMETRIA — um
    # cone translucido por luminaria acesa (ver `emitir_cones`). A oclusao de
    # canto, que viria do SSAO, vem assada nas texturas (o canal de oclusao do
    # `_arm` do Poly Haven). E a profundidade do corredor vem da nevoa de
    # distancia, que essa sim o mobile tem.
    # ==================================================================
    sub.append(("ambiente", "Environment", [
        "background_mode = 2",
        'sky = SubResource("ceu")',
        "background_energy_multiplier = 0.5",
        "ambient_light_source = 3",
        "ambient_light_color = Color(0.20, 0.23, 0.29, 1)",
        "ambient_light_sky_contribution = 0.25",
        # A luz ambiente e' o PISO da cena: define o quao escuro chega a ficar
        # um comodo sem lampada nenhuma. Em 0,55 (a primeira tentativa) o
        # jogador nao enxergava a propria mao e o predio inteiro virava uma
        # tela preta. O trecho entre duas luminarias de corredor tem uns 4 m de
        # escuro, e esse escuro precisa mostrar a FORMA das coisas (onde acaba
        # a parede, que tem uma maca no caminho) sem mostrar o detalhe delas.
        # E' esse o trabalho deste numero — e e' por isso que ele e' alto para
        # uma cena de terror: quem faz o medo aqui sao as lampadas, nao a
        # ausencia total de imagem.
        "ambient_light_energy = 1.90",
        "reflected_light_source = 2",
        "tonemap_mode = 3",
        "tonemap_exposure = 1.0",
        "tonemap_white = 7.5",
        "glow_enabled = true",
        "glow_intensity = 0.45",
        "glow_strength = 1.05",
        "glow_bloom = 0.16",
        "glow_blend_mode = 1",
        "glow_hdr_threshold = 1.10",
        # A nevoa e' o que faz o fim do corredor sumir. Densidade alta o
        # bastante pra engolir 25 m, e `fog_aerial_perspective` baixo pra ela
        # nao lavar o que esta' perto.
        "fog_enabled = true",
        "fog_mode = 0",
        "fog_light_color = Color(0.13, 0.15, 0.19, 1)",
        "fog_light_energy = 0.8",
        "fog_density = 0.016",
        "fog_aerial_perspective = 0.1",
        "fog_sky_affect = 0.15",
        "fog_height = -2.0",
        "fog_height_density = 0.06",
        "adjustment_enabled = true",
        "adjustment_brightness = 1.0",
        "adjustment_contrast = 1.12",
        "adjustment_saturation = 0.80",
    ]))


def _cones(sub, luzes):
    """Um cone translucido por luminaria acesa — o feixe no ar, em geometria.

    Sem nevoa volumetrica (o renderer do projeto e' o mobile), o cone de luz
    tem de existir como malha. Sao tres ingredientes que fazem ele nao parecer
    um cone de plastico:

      - `blend_mode = 1` (aditivo) e `shading_mode = 0` (unshaded): o cone SOMA
        luz em vez de tapar o que esta' atras.
      - `proximity_fade`: apaga a aresta onde o cone encosta no chao. Sem isso
        aparece um circulo duro no piso, que denuncia tudo.
      - `distance_fade`: alem de 20 m ele some. Num predio com 60 luminarias,
        sem isso o corredor inteiro vira sopa branca e o custo de overdraw
        explode.
    """
    familias = {}
    for luz in luzes:
        if luz["tipo"] != "SpotLight3D" or luz["mira"][1] > -0.9:
            continue
        raio = luz["alcance"] * math.tan(math.radians(luz["angulo"]))
        chave = (round(raio, 1), round(luz["alcance"], 1),
                 tuple(round(c, 2) for c in luz["cor"][:3]))
        familias.setdefault(chave, []).append(luz)

    feito = {}
    for (raio, alcance, c) in familias:
        ident_mat = "cone_mat_%d" % len(feito)
        ident_malha = "cone_malha_%d" % len(feito)
        sub.append((ident_mat, "StandardMaterial3D", [
            "transparency = 1",
            "blend_mode = 1",
            "shading_mode = 0",
            # So' a casca de TRAS do cone. Com as duas faces (cull_mode 2) o
            # olhar atravessa duas camadas aditivas de uma vez e o feixe dobra
            # de intensidade bem no meio da tela, que foi o que lavou a
            # primeira tentativa de branco.
            "cull_mode = 1",
            "albedo_color = Color(%.3f, %.3f, %.3f, 0.011)" % c,
            "disable_receive_shadows = true",
            "proximity_fade_enabled = true",
            "proximity_fade_distance = 1.8",
            "distance_fade_mode = 1",
            "distance_fade_min_distance = 20.0",
            "distance_fade_max_distance = 13.0",
        ]))
        altura = min(alcance, P.PE - 0.30)
        sub.append((ident_malha, "CylinderMesh", [
            'material = SubResource("%s")' % ident_mat,
            "top_radius = 0.22",
            "bottom_radius = %.3f" % max(raio * (altura / alcance), 0.4),
            "height = %.3f" % altura,
            "radial_segments = 16",
            "rings = 0",
            "cap_top = false",
            "cap_bottom = false",
        ]))
        feito[(raio, alcance, c)] = (ident_malha, altura)
    return familias, feito


def _navmesh(sub, navs):
    vertices = []
    poligonos = []
    for andar in (1, 2):
        v, p, _ = navs[andar]
        base = len(vertices)
        vertices.extend(v)
        for pol in p:
            poligonos.append([k + base for k in pol])
    pv = ", ".join("%.2f, %.2f, %.2f" % tuple(v) for v in vertices)
    pp = ", ".join("PackedInt32Array(%s)" % ", ".join(str(k) for k in pol)
                   for pol in poligonos)
    sub.append(("navmesh", "NavigationMesh", [
        "vertices = PackedVector3Array(%s)" % pv,
        "polygons = [%s]" % pp,
    ]))


def _poeira(sub):
    sub.append(("poeira_mat", "StandardMaterial3D", [
        "transparency = 1", "blend_mode = 1", "shading_mode = 0",
        "vertex_color_use_as_albedo = true",
        "albedo_color = Color(0.72, 0.74, 0.78, 0.13)",
        "billboard_mode = 3",
        # sem isto o billboard descarta a escala e scale_min/max nao valem nada
        "billboard_keep_scale = true",
        "disable_receive_shadows = true",
    ]))
    sub.append(("poeira_quad", "QuadMesh", [
        'material = SubResource("poeira_mat")', "size = Vector2(0.03, 0.03)",
    ]))
    sub.append(("poeira_proc", "ParticleProcessMaterial", [
        "lifetime_randomness = 0.8", "emission_shape = 3",
        "emission_box_extents = Vector3(29.0, 1.7, 31.0)",
        "direction = Vector3(0, -1, 0)", "spread = 60.0",
        "initial_velocity_min = 0.02", "initial_velocity_max = 0.14",
        "gravity = Vector3(0.02, -0.05, 0.01)",
        "scale_min = 0.3", "scale_max = 1.5",
        "color = Color(1, 1, 1, 0.16)",
        "turbulence_enabled = true", "turbulence_noise_strength = 0.16",
    ]))


if __name__ == "__main__":
    gerar()
