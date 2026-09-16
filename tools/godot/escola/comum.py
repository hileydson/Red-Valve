"""Ferramentas compartilhadas pelos tres geradores da escola.

Setor de malha, escrita de Transform3D e o juntador de pecas iguais. Tudo o que
os geradores da escola, do porao e da fachada fazem igual mora aqui.

==============================================================================
POR QUE ISTO NAO IMPORTA DO GERADOR DO HOSPITAL

O `gerar_cena_hospital.py` tem as mesmas funcoes, e a tentacao e' importar de
la'. Nao da': aquele modulo faz `import planta as P` no topo, e a pasta da
escola esta' na FRENTE do `sys.path` — o gerador do hospital acordaria com a
planta da ESCOLA na mao e montaria um predio que nao existe.

O escritor de glTF (`gltf.py`) pode ser importado porque nao importa planta
nenhuma: ele so' sabe transformar caixa em arquivo.

==============================================================================
ATENCAO: O Transform3D DO .tscn E' POR LINHAS

No GDScript, `Transform3D(x_axis, y_axis, z_axis, origem)` recebe os EIXOS (as
colunas da base). No arquivo de texto, os mesmos 12 numeros sao lidos como as
LINHAS da base — ou seja, a transposta.

Emitir coluna inverte o sinal de TODO giro em Y da cena de uma vez: a porta
passa a abrir pelo lado errado, o movel encostado na parede vira de costas pra
sala e o feixe da janela aponta pra fora do predio. E como tudo inverte junto,
a cena continua "parecendo certa" ate' alguem reparar que as macanetas estao do
lado do batente.
"""

import hashlib
import math
import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "hospital"))

import gltf  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
BASE = os.path.join(RAIZ, "red-valve")
DIR_MODELO = os.path.join(BASE, "assets", "3d_model", "stages", "escola")
DIR_PECAS = os.path.join(DIR_MODELO, "pecas")
RES_MODELO = "res://assets/3d_model/stages/escola"

LIMITE_LUZ = 8       # teto de omni e de spot por malha no renderer mobile


# ==========================================================================
# texto do .tscn
# ==========================================================================

def v3(v):
    return "Vector3(%s)" % ", ".join("%.4f" % c for c in v)


def cor(c):
    return "Color(%s)" % ", ".join("%.4f" % x for x in c)


def _matriz(x_eixo, y_eixo, z_eixo, pos):
    linhas = [x_eixo[0], y_eixo[0], z_eixo[0],
              x_eixo[1], y_eixo[1], z_eixo[1],
              x_eixo[2], y_eixo[2], z_eixo[2]]
    return "Transform3D(%s)" % ", ".join("%.5f" % n for n in linhas + list(pos))


def transform_pos(pos, giro_y=0.0, escala=1.0):
    c, s = math.cos(giro_y) * escala, math.sin(giro_y) * escala
    return _matriz((c, 0.0, -s), (0.0, escala, 0.0), (s, 0.0, c), pos)


def transform_olhando(pos, direcao):
    """Transform3D com o -Z do no' apontando pra `direcao` — e' pro proprio -Z
    que uma luz do Godot ilumina."""
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
# SETORES
#
# Parede, piso e teto viram UM objeto por setor quadrado. O tamanho nao e'
# chutado: o gerador comeca grande e vai encolhendo ate' que nenhum setor seja
# alcancado por mais de 8 luzes omni ou 8 spot, que e' o teto do renderer
# `mobile`. Acima disso o Godot descarta luz em silencio, e o sintoma no jogo
# e' a lampada que apaga sozinha quando o jogador anda pra tras.
# ==========================================================================

class Setores:
    def __init__(self, cena, tamanho, prefixo="est"):
        self.cena = cena
        self.tamanho = tamanho
        self.prefixo = prefixo
        self.objetos = {}

    def _objeto(self, i, j):
        if (i, j) not in self.objetos:
            self.objetos[(i, j)] = self.cena.objeto(
                "%s_%02d_%02d" % (self.prefixo, i, j))
        return self.objetos[(i, j)]

    def caixa(self, material, x0, x1, y0, y1, z0, z1, uv_escala=2.0):
        """Emite a caixa PARTIDA nas linhas do setor.

        Sem partir, uma parede de 70 m cairia inteira no setor do centro dela e
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
                self._objeto(i, j).caixa(
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
# CONTAGEM DE LUZ POR MALHA
# ==========================================================================

def _caixa_da_luz(luz):
    """AABB de influencia — CONE pro spot, esfera pro omni.

    Medir spot como esfera da' doze por setor onde o Godot enxerga tres: spot
    apontado pro chao nao ilumina o teto atras dele, e o motor cula pela caixa
    do cone. Medir errado aqui pica a geometria em centenas de pedacos sem
    necessidade nenhuma.
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


def contar_luzes(cena, todas_luzes):
    """Pior caso de luz por MALHA, medido na caixa de verdade de cada uma.

    Medir pelo quadrado do setor e' pessimista: um setor que so' tem uma laje
    de piso tem caixa de 15 cm de altura, e metade das luzes que cruzam o
    quadrado nao encosta nela.
    """
    pior_omni = pior_spot = 0
    pior_nome = None
    for obj in cena.objetos:
        if obj.vazio():
            continue
        mn, mx = obj.aabb()
        o = s = 0
        for luz in todas_luzes:
            lx0, lx1, ly0, ly1, lz0, lz1 = _caixa_da_luz(luz)
            if not (lx0 <= mx[0] and mn[0] <= lx1 and ly0 <= mx[1]
                    and mn[1] <= ly1 and lz0 <= mx[2] and mn[2] <= lz1):
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


# ==========================================================================
# PECAS SOLTAS — uma malha por GEOMETRIA DISTINTA
# ==========================================================================

class Pecas:
    """Junta geometrias iguais num arquivo so'.

    A chave e' o hash da lista de caixas. Trinta carteiras identicas viram um
    .gltf instanciado trinta vezes, e ninguem precisou dizer que sao iguais.
    """

    def __init__(self, pasta=None):
        self.pasta = pasta or DIR_PECAS
        self.arquivos = {}    # hash -> (nome, pecas)

    def registrar(self, prefixo, pecas):
        assinatura = hashlib.md5(
            repr([normalizar(p) for p in pecas]).encode()).hexdigest()[:10]
        if assinatura not in self.arquivos:
            self.arquivos[assinatura] = ("%s_%s" % (prefixo, assinatura), pecas)
        return self.arquivos[assinatura][0]

    def escrever(self, materiais, prefixo_tex="../../../../images/textures/polyhaven"):
        os.makedirs(self.pasta, exist_ok=True)
        # Apaga o que sobrou de geracoes anteriores. O nome de cada peca vem do
        # hash da geometria, entao mudar uma carteira gera um arquivo NOVO e
        # abandona o antigo — sem esta limpeza a pasta so' cresce, e o Godot
        # continua importando malhas que a cena nao referencia mais.
        vivos = {nome for (nome, _p) in self.arquivos.values()}
        for f in sorted(os.listdir(self.pasta)):
            base = f.split(".")[0]
            if base and base not in vivos:
                os.remove(os.path.join(self.pasta, f))
        total = 0
        for (nome, pecas) in self.arquivos.values():
            cena = gltf.Cena(prefixo_tex)
            for grupo in materiais:
                for m in grupo:
                    cena.material(m)
            obj = cena.objeto(nome)
            for p in pecas:
                d = normalizar(p)
                obj.caixa(d["mat"], d["pos"], d["tam"], d["giro"], uv=d["uv"])
            total += cena.salvar(os.path.join(self.pasta, nome + ".gltf"))
        return total


def normalizar(p):
    """Aceita tanto a tupla curta quanto o dicionario com giro proprio."""
    if isinstance(p, dict):
        return {"pos": tuple(p["pos"]), "tam": tuple(p["tam"]),
                "giro": p.get("giro", 0.0), "mat": p["mat"],
                "uv": p.get("uv", "local")}
    dx, dy, dz, sx, sy, sz, mat = p
    return {"pos": (dx, dy, dz), "tam": (sx, sy, sz), "giro": 0.0,
            "mat": mat, "uv": "local"}


# ==========================================================================
# ESCRITOR DE .tscn
# ==========================================================================

class Cena:
    """Junta ext_resource, sub_resource e nos, e so' monta o texto no fim.

    A ordem importa: `forma()` e `peca()` criam recurso ENQUANTO os nos sao
    escritos. Montando o cabecalho antes, nenhuma das BoxShape3D de colisao
    chegava ao arquivo — e o Godot recusava a cena inteira com um "Invalid
    parameter" apontando pro primeiro no' que citava uma delas.
    """

    def __init__(self):
        self.externos = []
        self._ids = {}
        self.sub = []
        self._formas = {}
        self.linhas = []

    def externo(self, tipo, caminho):
        if caminho in self._ids:
            return self._ids[caminho]
        ident = "e%d" % len(self.externos)
        self.externos.append((tipo, caminho, ident))
        self._ids[caminho] = ident
        return ident

    def peca(self, nome):
        return self.peca_em("pecas", nome)

    def peca_em(self, pasta, nome):
        """As duas cenas dividem a pasta de assets mas nao a de pecas: o porao
        escreve em `pecas_porao/` pra a limpeza de orfaos de um gerador nao
        apagar as pecas do outro (ver `Pecas.escrever`)."""
        return self.externo("PackedScene", "%s/%s/%s.gltf"
                            % (RES_MODELO, pasta, nome))

    def recurso(self, ident, tipo, corpo):
        self.sub.append((ident, tipo, corpo))
        return ident

    def forma(self, lx, ly, lz):
        chave = (round(lx, 3), round(ly, 3), round(lz, 3))
        if chave not in self._formas:
            ident = "f%d" % len(self._formas)
            self._formas[chave] = ident
            self.recurso(ident, "BoxShape3D", ["size = %s" % v3(chave)])
        return self._formas[chave]

    def no(self, nome, tipo=None, pai=None, instancia=None, props=(), metas=(),
           grupos=None):
        cab = '[node name="%s"' % nome
        if tipo:
            cab += ' type="%s"' % tipo
        if pai:
            cab += ' parent="%s"' % pai
        if instancia:
            cab += ' instance=ExtResource("%s")' % instancia
        if grupos:
            cab += ' groups=["%s"]' % '", "'.join(grupos)
        self.linhas.append(cab + "]")
        for (chave, valor) in props:
            self.linhas.append("%s = %s" % (chave, valor))
        for (chave, valor) in metas:
            self.linhas.append("metadata/%s = %s" % (chave, valor))
        self.linhas.append("")

    def gravar(self, caminho):
        cab = ["[gd_scene load_steps=%d format=3]"
               % (len(self.externos) + len(self.sub) + 1), ""]
        for (tipo, arq, ident) in self.externos:
            cab.append('[ext_resource type="%s" path="%s" id="%s"]'
                       % (tipo, arq, ident))
        cab.append("")
        for (ident, tipo, corpo) in self.sub:
            cab.append('[sub_resource type="%s" id="%s"]' % (tipo, ident))
            cab.extend(corpo)
            cab.append("")
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        with open(caminho, "w") as fp:
            fp.write("\n".join(cab + self.linhas).rstrip() + "\n")


# ==========================================================================
# COLISAO
# ==========================================================================

def emitir_colisoes(cena, caixas, nome="colisao", pai="."):
    """Um StaticBody3D na layer 2 com uma BoxShape3D por caixa.

    Layer 2 e mask 0: o jogador e' um CharacterBody3D com `collision_mask = 2`
    e SO' enxerga essa layer. Corpo na layer errada = jogador atravessando o
    predio em queda livre.
    """
    cena.no(nome, tipo="StaticBody3D", pai=pai,
            props=[("collision_layer", "2"), ("collision_mask", "0")])
    caminho = (nome if pai == "." else pai + "/" + nome)
    for (i, (x0, x1, y0, y1, z0, z1)) in enumerate(caixas):
        ident = cena.forma(x1 - x0, y1 - y0, z1 - z0)
        cena.no("c%d" % i, tipo="CollisionShape3D", pai=caminho,
                props=[("transform", transform_pos(
                    ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5))),
                    ("shape", 'SubResource("%s")' % ident)])


# ==========================================================================
# OS QUADS DE RABISCO
#
# Um material por ARTE (nao por rabisco): 140 quads dividem ~20 materiais.
# `cull_mode = 2` e' obrigatorio — ver o cabecalho de `pichacao.py`.
# ==========================================================================

def emitir_pichacao(cena, rabiscos, pai=".", nome="pichacao"):
    if not rabiscos:
        return 0
    cena.no(nome, tipo="Node3D", pai=pai)
    caminho = (nome if pai == "." else pai + "/" + nome)
    mats = {}
    malhas = {}
    for (i, r) in enumerate(rabiscos):
        # O desbotado entra na chave em TRES DEGRAUS, e nao no valor cru.
        # Cru, cada rabisco virava um material proprio (124 materiais pra 137
        # quads) e o atlas deixava de servir pra alguma coisa. Tres degraus dao
        # a mesma variacao aos olhos e derrubam a conta pra uma dezena.
        g = round(0.55 + 0.22 * int((r["desbotado"] - 0.55) / 0.22), 2)
        chave = (r["arte"], g)
        if chave not in mats:
            ident = "pich_mat_%d" % len(mats)
            u0, v0, du, dv = r["uv"]
            cena.recurso(ident, "StandardMaterial3D", [
                "transparency = 1",
                # mistura, e nao alpha scissor: o traco do spray tem 3-4 px no
                # atlas e o mipmap o dilui abaixo de qualquer limiar util
                "blend_mode = 0",
                "depth_draw_mode = 2",
                "cull_mode = 2",
                "shading_mode = 1",
                "specular_mode = 2",
                "albedo_color = Color(%.3f, %.3f, %.3f, 1)" % (g, g, g),
                'albedo_texture = ExtResource("%s")'
                % cena.externo("Texture2D", r["_res_atlas"]),
                "texture_repeat = false",
                "uv1_scale = Vector3(%.6f, %.6f, 1)" % (du, dv),
                "uv1_offset = Vector3(%.6f, %.6f, 0)" % (u0, v0),
                "distance_fade_mode = 1",
                "distance_fade_min_distance = 34.0",
                "distance_fade_max_distance = 24.0",
            ])
            mats[chave] = ident
        # A malha tambem e' compartilhada, e ela depende do TAMANHO: dois
        # rabiscos da mesma arte com larguras diferentes sao dois QuadMesh.
        malha_chave = (mats[chave], round(r["largura"], 1),
                       round(r["altura"], 1))
        if malha_chave not in malhas:
            ident = "pich_malha_%d" % len(malhas)
            cena.recurso(ident, "QuadMesh", [
                'material = SubResource("%s")' % mats[chave],
                "size = Vector2(%.2f, %.2f)" % (round(r["largura"], 1),
                                                round(r["altura"], 1)),
            ])
            malhas[malha_chave] = ident
        if r["chao"]:
            # Deitado. O quad nasce EM PE' no plano XY local, entao aqui o X
            # local vira uma direcao no chao e o Y local vira a perpendicular
            # dela, tambem no chao; a normal (o Z local) sobra apontando pra
            # cima. Escrito como eixo e nao como "giro de -90 em X mais giro em
            # Y" de proposito: composicao de dois giros num arquivo de texto e'
            # onde o sinal se perde.
            c, s = math.cos(r["giro"]), math.sin(r["giro"])
            xform = _matriz((c, 0.0, -s), (-s, 0.0, -c), (0.0, 1.0, 0.0),
                            (r["x"], r["y"], r["z"]))
        else:
            xform = transform_pos((r["x"], r["y"], r["z"]), r["giro"])
        cena.no("rab_%d" % i, tipo="MeshInstance3D", pai=caminho,
                props=[("transform", xform),
                       ("mesh", 'SubResource("%s")' % malhas[malha_chave]),
                       ("cast_shadow", "0")])
    return len(mats)
