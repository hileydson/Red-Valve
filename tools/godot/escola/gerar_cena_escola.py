"""Monta a escola inteira: geometria (.gltf) + cena (.tscn).

    python3 tools/godot/escola/gerar_cena_escola.py

Sai:
    red-valve/assets/3d_model/stages/escola/escola_estrutura.gltf (+ .bin)
    red-valve/assets/3d_model/stages/escola/pecas/*.gltf
    red-valve/scenes/stages/escola/escola.tscn

O .tscn resultante e' um arquivo NORMAL do Godot: da' pra abrir, mexer e salvar
pelo editor. Rodar este script de novo SOBRESCREVE — ele existe pra quando a
planta mudar (`planta.py`) e luz, movel, colisao e navmesh precisarem seguir
junto sem ninguem recolocar nada na mao.

==============================================================================
O QUE ESTA CENA TEM QUE O HOSPITAL NAO TEM

1. UM PATIO SEM TETO. A "area de lazer" do desenho e' um espaco descoberto
   dentro do predio. Ele nao leva laje de forro, leva CEU — e por isso esta
   cena tem uma luz direcional (a lua) e chuva, que um interior fechado nao
   teria. As paredes que dao pra ele sobem alem do pe-direito, senao o ceu
   apareceria por baixo do predio.

2. A GRADE. Um objeto solido atravessando o corredor sul. Ela e' a regra de
   jogo inteira desta fase: e' por causa dela que o porao existe.

3. OS DOIS BURACOS. Rombos na parede que trocam de cena. Cada um tem um NICHO
   de terra atras — sem ele o jogador olha pelo buraco e ve o vazio da rua,
   que e' o contrario do que o buraco promete.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comum as C
import gltf
import luzes as L
import materiais as M
import mobilia as MOB
import navmesh as NAV
import pichacao as PICH
import planta as P

SAIDA_CENA = os.path.join(C.BASE, "scenes", "stages", "escola", "escola.tscn")

DADO = 1.30            # altura do azulejo de parede
LAJE_TETO = 0.15       # espessura visivel do forro


# ==========================================================================
# ESTRUTURA
# ==========================================================================

def montar_estrutura(tamanho):
    cena = gltf.Cena("../../../images/textures/polyhaven")
    M.registrar(cena, [M.ESTRUTURA, M.MOVEIS, M.LUMINARIAS])
    setores = C.Setores(cena, tamanho)
    colisoes = []
    colisoes += emitir_paredes(setores)
    emitir_janelas(setores)
    colisoes += emitir_lajes(setores)
    colisoes += emitir_quadra(setores)
    colisoes += emitir_buracos(setores)
    colisoes += emitir_calcada_do_patio(setores)
    return cena, setores, colisoes


def pedacos_do_muro(m):
    """Fatia o muro nos pedacos CHEIOS que sobram em volta dos vaos.

    A regra da casa (a mesma da igreja e do hospital): parede com vao nao e' um
    retangulo furado, e' um monte de caixa em volta do buraco. Furo booleano
    daria normal invertida em algum canto e um buraco preto que so' aparece
    depois de a cena estar montada.
    """
    alto = m["alto"]
    pedacos = []
    corrente = m["a"]
    for v in sorted(m["vaos"], key=lambda v: v["c"]):
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


def _tipo_do_lado(m, a, b, lado):
    """Que comodo esta' deste lado do muro? Sonda um ponto 30 cm adentro."""
    meio = (a + b) * 0.5
    fora = m["esp"] * 0.5 + 0.30
    if m["eixo"] == "x":
        x, z = meio, m["coord"] + lado * fora
    else:
        x, z = m["coord"] + lado * fora, meio
    e = P.espaco_em(x, z)
    return e["tipo"] if e else None


def emitir_paredes(setores):
    colisoes = []
    base = P.cota()
    for m in P.muros():
        esp = m["esp"]
        for (a, b, y0, y1) in pedacos_do_muro(m):
            ya, yb = base + y0, base + y1
            colisoes.append(_caixa_colisao(m, a, b, ya, yb, esp))

            for lado in (-1, 1):
                tipo = _tipo_do_lado(m, a, b, lado) or "corredor"
                c0 = m["coord"] + (0.0 if lado > 0 else -esp * 0.5)
                c1 = m["coord"] + (esp * 0.5 if lado > 0 else 0.0)
                # No patio nao tem dado de azulejo: aquilo e' parede de rua,
                # batida de chuva. Um pano so', de cima a baixo.
                if tipo == "patio":
                    faixas = [(ya, yb, "parede_patio", 3.0)]
                else:
                    faixas = []
                    corte = base + DADO
                    if ya < corte:
                        faixas.append((ya, min(yb, corte),
                                       M.parede_de(tipo, False), 1.5))
                    if yb > corte:
                        faixas.append((max(ya, corte), yb,
                                       M.parede_de(tipo, True), 2.6))
                for (fa, fb, mat, uv) in faixas:
                    if m["eixo"] == "x":
                        setores.caixa(mat, a, b, fa, fb, c0, c1, uv)
                    else:
                        setores.caixa(mat, c0, c1, fa, fb, a, b, uv)
                # friso sobre o dado, saliente 2 cm pra pegar luz rasante
                corte = base + DADO
                if tipo != "patio" and ya < corte < yb:
                    s0 = c0 - (0.02 if lado < 0 else 0.0)
                    s1 = c1 + (0.02 if lado > 0 else 0.0)
                    if m["eixo"] == "x":
                        setores.caixa("friso", a, b, corte - 0.05,
                                      corte + 0.02, s0, s1, 1.0)
                    else:
                        setores.caixa("friso", s0, s1, corte - 0.05,
                                      corte + 0.02, a, b, 1.0)
    return colisoes


def _caixa_colisao(m, a, b, y0, y1, esp):
    if m["eixo"] == "x":
        return (a, b, y0, y1, m["coord"] - esp * 0.5, m["coord"] + esp * 0.5)
    return (m["coord"] - esp * 0.5, m["coord"] + esp * 0.5, y0, y1, a, b)


# ==========================================================================
# JANELAS
# ==========================================================================

def emitir_janelas(setores):
    base = P.cota()
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        esp = m["esp"]
        for v in m["vaos"]:
            if v["tipo"] != "janela":
                continue
            a, b = v["c"] - v["l"] * 0.5, v["c"] + v["l"] * 0.5
            y0, y1 = base + v["y0"], base + v["y1"]
            c = m["coord"]
            # Janela quebrada nao fica sem vidro nenhum: fica com um caco no
            # caixilho. Vazio de verdade le' como "esqueceram de modelar".
            mat_vidro = "vidro_caco" if v.get("quebrada") else "vidro"

            def caixa(x0, x1, ya, yb, z0, z1, mat, uv=1.0):
                setores.caixa(mat, x0, x1, ya, yb, z0, z1, uv)

            if m["eixo"] == "x":
                if v.get("quebrada"):
                    # so' as duas pontas de vidro, encostadas no caixilho
                    for (qa, qb) in ((a, a + v["l"] * 0.22),
                                     (b - v["l"] * 0.16, b)):
                        caixa(qa, qb, y0 + 0.04, y1 - 0.04, c - 0.02, c + 0.02,
                              mat_vidro)
                else:
                    caixa(a, b, y0 + 0.04, y1 - 0.04, c - 0.03, c + 0.03,
                          mat_vidro)
                caixa(a, b, y0, y0 + 0.06, c - esp * 0.5, c + esp * 0.5,
                      "esquadria")
                caixa(a, b, y1 - 0.06, y1, c - esp * 0.5, c + esp * 0.5,
                      "esquadria")
                for x in (a, b - 0.06):
                    caixa(x, x + 0.06, y0, y1, c - esp * 0.5, c + esp * 0.5,
                          "esquadria")
                dentro = 1 if P.espaco_em(v["c"], c + 0.6) else -1
                caixa(a - 0.08, b + 0.08, y0 - 0.07, y0,
                      c + (0.0 if dentro > 0 else -0.26),
                      c + (0.26 if dentro > 0 else 0.0), "peitoril")
            else:
                if v.get("quebrada"):
                    for (qa, qb) in ((a, a + v["l"] * 0.22),
                                     (b - v["l"] * 0.16, b)):
                        caixa(c - 0.02, c + 0.02, y0 + 0.04, y1 - 0.04, qa, qb,
                              mat_vidro)
                else:
                    caixa(c - 0.03, c + 0.03, y0 + 0.04, y1 - 0.04, a, b,
                          mat_vidro)
                caixa(c - esp * 0.5, c + esp * 0.5, y0, y0 + 0.06, a, b,
                      "esquadria")
                caixa(c - esp * 0.5, c + esp * 0.5, y1 - 0.06, y1, a, b,
                      "esquadria")
                for z in (a, b - 0.06):
                    caixa(c - esp * 0.5, c + esp * 0.5, y0, y1, z, z + 0.06,
                          "esquadria")
                dentro = 1 if P.espaco_em(c + 0.6, v["c"]) else -1
                caixa(c + (0.0 if dentro > 0 else -0.26),
                      c + (0.26 if dentro > 0 else 0.0),
                      y0 - 0.07, y0, a - 0.08, b + 0.08, "peitoril")


# ==========================================================================
# PISO E TETO
# ==========================================================================

def emitir_lajes(setores):
    colisoes = []
    base = P.cota()
    for e in P.espacos():
        mat = M.piso_de(e["tipo"])
        setores.caixa(mat, e["x0"], e["x1"], base - LAJE_TETO, base,
                      e["z0"], e["z1"], 2.4)
        colisoes.append((e["x0"], e["x1"], base - 0.45, base,
                         e["z0"], e["z1"]))
        if e.get("descoberto"):
            # o patio nao tem forro: e' aqui que o ceu entra na cena
            continue
        teto = base + P.PE
        setores.caixa(M.teto_de(e["tipo"]), e["x0"], e["x1"], teto,
                      teto + LAJE_TETO, e["z0"], e["z1"], 1.8)
        colisoes.append((e["x0"], e["x1"], teto, teto + 0.45,
                         e["z0"], e["z1"]))
    return colisoes


def emitir_calcada_do_patio(setores):
    """A faixa de piso que corre rente aos muros do patio.

    Ela e' cosmetica e serve pra uma coisa so': separar, no chao, o que e'
    circulacao do que e' quadra. Sem essa borda o patio inteiro e' um plano de
    cimento de 45 x 36 m sem nenhuma junta, e a quadra pintada parece flutuar
    nele.
    """
    e = P.por_ident("patio")
    base = P.cota()
    faixa = 2.20
    for (x0, x1, z0, z1) in (
            (e["x0"], e["x1"], e["z0"], e["z0"] + faixa),
            (e["x0"], e["x1"], e["z1"] - faixa, e["z1"]),
            (e["x0"], e["x0"] + faixa, e["z0"] + faixa, e["z1"] - faixa),
            (e["x1"] - faixa, e["x1"], e["z0"] + faixa, e["z1"] - faixa)):
        setores.caixa("piso_concreto", x0, x1, base - 0.02, base + 0.015,
                      z0, z1, 3.0)
    return []


# ==========================================================================
# A QUADRA
#
# Ela e' PINTURA, e nao construcao: uma laje rasa de asfalto com as linhas por
# cima, salientes 1 cm. Nada disso tem colisao — quadra que atrapalha andar
# seria exatamente o que o pedido proibiu.
# ==========================================================================

def emitir_quadra(setores):
    x0, z0, x1, z1 = MOB.QUADRA
    base = P.cota()
    e = MOB.QUADRA_LINHA
    setores.caixa("piso_quadra", x0 - 1.2, x1 + 1.2, base - 0.01, base + 0.02,
                  z0 - 1.2, z1 + 1.2, 4.5)

    def linha(ax0, az0, ax1, az1):
        setores.caixa("linha_quadra", ax0, ax1, base + 0.02, base + 0.032,
                      az0, az1, 1.0)

    # a moldura
    linha(x0, z0, x1, z0 + e)
    linha(x0, z1 - e, x1, z1)
    linha(x0, z0, x0 + e, z1)
    linha(x1 - e, z0, x1, z1)
    # o meio de campo
    cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    linha(cx - e * 0.5, z0, cx + e * 0.5, z1)
    # o circulo central, em 24 tracinhos — circulo de verdade em caixa seria
    # um poligono de 24 lados de qualquer jeito, e assim a espessura fica igual
    raio = 3.0
    for k in range(24):
        ang = k * math.pi / 12.0
        px, pz = cx + math.cos(ang) * raio, cz + math.sin(ang) * raio
        setores.caixa("linha_quadra", px - 0.22, px + 0.22,
                      base + 0.02, base + 0.032, pz - 0.22, pz + 0.22, 1.0)
    # as duas areas
    for lado in (0, 1):
        ax = x0 if lado == 0 else x1 - 5.0
        linha(ax, cz - 4.5, ax + 5.0, cz - 4.5 + e)
        linha(ax, cz + 4.5 - e, ax + 5.0, cz + 4.5)
        bx = ax + 5.0 - e if lado == 0 else ax
        linha(bx, cz - 4.5, bx + e, cz + 4.5)
    return []


# ==========================================================================
# OS BURACOS
#
# Cada um e' um nicho de terra do lado de FORA da fachada, descendo. O jogador
# olha pelo rombo e ve um tunel cavado sumindo pra baixo — nao a rua. Fechado
# por colisao no fundo: quem entra ali nao anda pra lugar nenhum, ele aciona o
# prompt. O nicho tambem e' o que faz o prompt ter sentido antes de o jogador
# saber que existe um porao.
# ==========================================================================

NICHO_FUNDO = 3.40          # quanto o nicho entra pra dentro da terra
NICHO_QUEDA = 1.10          # quanto o chao dele desce no caminho


def _direcao_do_buraco(b):
    return {"n": (0.0, -1.0), "s": (0.0, 1.0),
            "o": (-1.0, 0.0), "l": (1.0, 0.0)}[b["lado"]]


def emitir_buracos(setores):
    colisoes = []
    base = P.cota()
    for b in (P.BURACO_ENTRADA, P.BURACO_SAIDA):
        dx, dz = _direcao_do_buraco(b)
        x, z = b["x"], b["z"]
        meia = P.BURACO_L * 0.5 + 0.55
        for k in range(7):
            t0 = k * NICHO_FUNDO / 7.0
            t1 = (k + 1) * NICHO_FUNDO / 7.0
            # o chao desce e o teto desce junto: o tunel inteiro mergulha
            y0 = base - NICHO_QUEDA * (t1 / NICHO_FUNDO)
            y1 = base + P.BURACO_H - NICHO_QUEDA * (t0 / NICHO_FUNDO) * 0.55
            if dz:
                ax0, ax1 = x - meia, x + meia
                az0, az1 = z + dz * t0, z + dz * t1
                if az0 > az1:
                    az0, az1 = az1, az0
            else:
                az0, az1 = z - meia, z + meia
                ax0, ax1 = x + dx * t0, x + dx * t1
                if ax0 > ax1:
                    ax0, ax1 = ax1, ax0
            # chao, teto e as duas laterais de terra
            setores.caixa("terra_buraco", ax0, ax1, y0 - 0.45, y0, az0, az1, 2.0)
            colisoes.append((ax0, ax1, y0 - 0.45, y0, az0, az1))
            setores.caixa("terra_buraco", ax0, ax1, y1, y1 + 0.45, az0, az1, 2.0)
            colisoes.append((ax0, ax1, y1, y1 + 0.45, az0, az1))
            if dz:
                for lx in (ax0 - 0.45, ax1):
                    setores.caixa("terra_buraco", lx, lx + 0.45, y0, y1 + 0.45,
                                  az0, az1, 2.0)
                    colisoes.append((lx, lx + 0.45, y0, y1 + 0.45, az0, az1))
            else:
                for lz in (az0 - 0.45, az1):
                    setores.caixa("terra_buraco", ax0, ax1, y0, y1 + 0.45,
                                  lz, lz + 0.45, 2.0)
                    colisoes.append((ax0, ax1, y0, y1 + 0.45, lz, lz + 0.45))
        # o fundo: preto, e solido. E' ele que impede o jogador de sair do
        # predio andando por um buraco que devia trocar de cena.
        fx = x + dx * NICHO_FUNDO
        fz = z + dz * NICHO_FUNDO
        y0 = base - NICHO_QUEDA
        y1 = base + P.BURACO_H
        if dz:
            setores.caixa("escuro", x - meia, x + meia, y0, y1,
                          min(fz, fz + dz * 0.4), max(fz, fz + dz * 0.4), 2.0)
            colisoes.append((x - meia, x + meia, y0 - 0.5, y1 + 0.5,
                             min(fz, fz + dz * 0.4), max(fz, fz + dz * 0.4)))
        else:
            setores.caixa("escuro", min(fx, fx + dx * 0.4),
                          max(fx, fx + dx * 0.4), y0, y1, z - meia, z + meia, 2.0)
            colisoes.append((min(fx, fx + dx * 0.4), max(fx, fx + dx * 0.4),
                             y0 - 0.5, y1 + 0.5, z - meia, z + meia))
    return colisoes


# ==========================================================================
# PECAS
# ==========================================================================

def folha_de_porta(largura, altura=P.PORTA_H - 0.05, metal=False):
    """Folha com a DOBRADICA na origem: ela cresce pro +X local.

    Assim o no' do pivo so' precisa girar em torno de si mesmo, e a mesma malha
    serve pras duas folhas de uma porta dupla — a segunda nasce virada 180.
    """
    e = 0.055
    corpo = "porta_metal" if metal else "porta_folha"
    p = [(largura * 0.5, altura * 0.5, 0.0, largura, altura, e, corpo)]
    if not metal:
        # o visor de vidro alto, que e' o que faz porta de escola parecer de
        # escola: da' pra ver quem esta' na sala sem abrir
        p.append((largura * 0.5, altura * 0.74, 0.0,
                  largura * 0.42, altura * 0.20, e + 0.012, "vidro"))
    p.append((largura * 0.5, 0.16, 0.0, largura - 0.06, 0.26, e + 0.014,
              "porta_metal"))
    for lado in (-1, 1):
        p.append((largura - 0.15, altura * 0.42, lado * (e * 0.5 + 0.045),
                  0.18, 0.04, 0.09, "porta_metal"))
    return p


def folha_de_portao(largura, altura=P.PORTA_H + 0.20):
    """O portao: quadro de cantoneira com barra chata no meio.

    Vazado de proposito: e' por ele que o jogador ve o patio do outro lado e
    entende que aquilo e' um atalho, e nao uma porta qualquer trancada.
    """
    p = [(largura * 0.5, altura * 0.5, 0.0, 0.08, altura, 0.07, "ferro"),
         (largura - 0.04, altura * 0.5, 0.0, 0.08, altura, 0.07, "ferro"),
         (largura * 0.5, altura - 0.04, 0.0, largura, 0.08, 0.07, "ferro"),
         (largura * 0.5, 0.04, 0.0, largura, 0.08, 0.07, "ferro"),
         (largura * 0.5, altura * 0.55, 0.0, largura, 0.06, 0.07, "ferro")]
    n = max(int(largura / 0.22), 3)
    for i in range(1, n):
        p.append((largura * i / n, altura * 0.5, 0.0, 0.035, altura - 0.12,
                  0.045, "ferro"))
    p.append((largura - 0.20, altura * 0.42, 0.06, 0.22, 0.05, 0.10, "ferro"))
    return p


def pecas_da_grade():
    """A grade que atravessa o corredor sul, em torno do proprio centro.

    Ela nao e' porta: nao tem folha, nao tem dobradica e nao abre. E' uma
    chapa de barra soldada no vao inteiro, com um cadeado e uma corrente — o
    cadeado existe pra dizer, sem texto, que alguem fechou isto de proposito.
    """
    larg = P.GRADE_Z1 - P.GRADE_Z0
    alto = P.PE
    p = []
    # marco: dois montantes e duas travessas
    for dz in (-larg * 0.5 + 0.06, larg * 0.5 - 0.06):
        p.append((0.0, alto * 0.5, dz, 0.12, alto, 0.12, "ferro"))
    p.append((0.0, alto - 0.06, 0.0, 0.12, 0.12, larg, "ferro"))
    p.append((0.0, 0.06, 0.0, 0.12, 0.12, larg, "ferro"))
    # travessas horizontais
    for y in (alto * 0.30, alto * 0.62, alto * 0.88):
        p.append((0.0, y, 0.0, 0.07, 0.07, larg - 0.12, "ferro"))
    # as barras verticais
    n = max(int(larg / 0.16), 8)
    for i in range(1, n):
        p.append((0.0, alto * 0.5, -larg * 0.5 + larg * i / n,
                  0.045, alto - 0.12, 0.045, "ferro"))
    # a chapa de aviso e a corrente com cadeado, no meio
    p.append((0.05, 1.70, 0.0, 0.02, 0.36, 0.52, "mat_placa"))
    p.append((0.0, 1.20, 0.0, 0.10, 0.34, 0.10, "ferro"))
    p.append((0.0, 1.02, 0.0, 0.12, 0.16, 0.09, "mat_metal_escuro"))
    return p


def pecas_da_luminaria(lum):
    if lum.get("vermelha"):
        return [(0.0, 0.0, 0.0, 0.32, 0.17, 0.20, "lum_corpo"),
                (0.0, 0.0, 0.11, 0.24, 0.11, 0.04, "lum_vermelha")]
    if lum.get("refletor"):
        # o refletor de quadra, no alto do poste: caixa inclinada num braco
        aceso = "lum_tubo_aceso" if lum["acesa"] else "lum_tubo_morto"
        p = [(0.0, -L.REFLETOR_H * 0.5 + 0.2, 0.0, 0.18, L.REFLETOR_H, 0.18,
              "lum_corpo"),
             (0.0, 0.0, 0.10, 0.90, 0.55, 0.30, "lum_corpo"),
             (0.0, -0.02, 0.26, 0.78, 0.42, 0.04, aceso)]
        return p
    tubo = "lum_tubo_aceso" if lum["acesa"] else "lum_tubo_morto"
    comp = lum["comprimento"]
    if lum["eixo"] == "x":
        corpo, vidro = (comp, 0.10, 0.32), (comp - 0.12, 0.05, 0.22)
    else:
        corpo, vidro = (0.32, 0.10, comp), (0.22, 0.05, comp - 0.12)
    return [(0.0, 0.05, 0.0, corpo[0], corpo[1], corpo[2], "lum_corpo"),
            (0.0, -0.02, 0.0, vidro[0], vidro[1], vidro[2], tubo)]


def portas_da_planta():
    saida = []
    base = P.cota()
    for m in P.muros():
        for v in m["vaos"]:
            if v["tipo"] != "porta":
                continue
            # eixo "x": o muro corre em X, entao a normal dele e' Z. O no' da
            # porta nasce com +X ao longo do vao e +Z pra fora — e' desse
            # acordo que o script tira pra que lado abrir.
            giro = 0.0 if m["eixo"] == "x" else math.pi * 0.5
            pos = ((v["c"], base, m["coord"]) if m["eixo"] == "x"
                   else (m["coord"], base, v["c"]))
            s = P.por_ident(v["sala"])
            saida.append({
                "ident": v["ident"], "sala": v["sala"],
                "chave": s["chave"] if s and s.get("chave")
                else "ESC_SALA_GENERICA",
                "pos": pos, "giro": giro, "largura": v["l"],
                "dupla": v["dupla"], "trancada": v.get("trancada", False),
                "saida": v.get("saida", False),
                "portao": v.get("portao", False),
                # o portao da rua tambem e' de chapa; folha de madeira numa
                # entrada de muro nao existe
                "metal": v.get("portao", False) or v.get("saida", False)})
    return saida


# ==========================================================================
# GERACAO
# ==========================================================================

def gerar():
    print("== luzes ==")
    plano_luz = L.montar()
    todas_luzes = L.so_luzes(plano_luz)
    lista_luminarias = L.luminarias(plano_luz)
    print("  %d luzes, %d luminarias" % (len(todas_luzes),
                                         len(lista_luminarias)))

    print("== estrutura: escolhendo o tamanho do setor ==")
    melhor = None
    for tamanho in (20.0, 18.0, 16.0, 14.0, 12.0, 10.0, 8.0, 6.0):
        cena, setores, colisoes = montar_estrutura(tamanho)
        o, s, onde = C.contar_luzes(cena, todas_luzes)
        print("  setor de %.0f m: pior malha ve %d omni e %d spot (%s)"
              % (tamanho, o, s, onde))
        melhor = (tamanho, cena, setores, colisoes)
        if o <= C.LIMITE_LUZ and s <= C.LIMITE_LUZ:
            break
    tamanho, cena, setores, colisoes = melhor
    print("  setor escolhido: %.0f m" % tamanho)
    os.makedirs(C.DIR_MODELO, exist_ok=True)
    tris = cena.salvar(os.path.join(C.DIR_MODELO, "escola_estrutura.gltf"))
    vivos = [o for o in cena.objetos if not o.vazio()]
    print("  %d objetos de setor, %d triangulos, %d caixas de colisao"
          % (len(vivos), tris, len(colisoes)))

    print("== moveis ==")
    # Antes de qualquer coisa: modelo grande demais pra caber onde a receita o
    # poe. Um .gltf modular do Poly Haven ja' atravessou tres comodos aqui sem
    # dar erro nenhum — melhor descobrir contando.
    for erro in MOB.conferir_modelos():
        print("  !! " + erro)
    props = MOB.mobiliar()
    pecas = C.Pecas()
    for p in props:
        if p["tipo"] == "caixas":
            p["arquivo"] = pecas.registrar("mov", p["pecas"])
    portas = portas_da_planta()
    for d in portas:
        larg = d["largura"] * (0.5 if d["dupla"] else 1.0)
        if d["portao"]:
            d["arquivo"] = pecas.registrar("portao", folha_de_portao(larg))
        else:
            d["arquivo"] = pecas.registrar(
                "folha", folha_de_porta(larg, metal=d["metal"]))
        d["larg_folha"] = larg
    for lum in lista_luminarias:
        lum["arquivo"] = pecas.registrar("lum", pecas_da_luminaria(lum))
    arq_grade = pecas.registrar("grade", pecas_da_grade())
    tris_pecas = pecas.escrever([M.ESTRUTURA, M.MOVEIS, M.LUMINARIAS])
    print("  %d moveis, %d geometrias distintas, %d triangulos"
          % (len(props), len(pecas.arquivos), tris_pecas))
    print("  %d portas (%d duplas)"
          % (len(portas), sum(1 for d in portas if d["dupla"])))

    print("== pichacao ==")
    rabiscos = PICH.montar()
    for r in rabiscos:
        r["_res_atlas"] = PICH.RES_ATLAS[r["atlas"]]
    print("  %d rabiscos" % len(rabiscos))

    print("== navmesh ==")
    nav = NAV.malha(props)

    print("== cena ==")
    escrever_cena(colisoes, props, portas, plano_luz, lista_luminarias, nav,
                  rabiscos, arq_grade)
    print("  gravado: %s" % SAIDA_CENA)


# ==========================================================================
# O .tscn
# ==========================================================================

def escrever_cena(colisoes, props, portas, plano_luz, lista_luminarias, nav,
                  rabiscos, arq_grade):
    c = C.Cena()

    id_player = c.externo("PackedScene", "res://scenes/player/player.tscn")
    id_pause = c.externo("PackedScene", "res://scenes/configs/pause.tscn")
    id_fade = c.externo("PackedScene", "res://scenes/configs/fade.tscn")
    id_minimapa = c.externo("PackedScene", "res://scenes/ui/minimap_escola.tscn")
    id_script = c.externo("Script", "res://scripts/stages/escola/escola.gd")
    id_porta_gd = c.externo("Script",
                            "res://scripts/stages/escola/porta_escola.gd")
    # O MESMO script das bocas do porao: as duas pontas do tunel fazem a
    # mesma coisa, e quem sabe o que "trocar de lugar" significa e' a cena.
    id_buraco_gd = c.externo("Script", "res://scripts/stages/escola/buraco.gd")
    id_grade_gd = c.externo("Script",
                            "res://scripts/stages/escola/grade_escola.gd")
    id_estrutura = c.externo("PackedScene",
                             C.RES_MODELO + "/escola_estrutura.gltf")
    id_ambiente = c.externo(
        "AudioStream", "res://assets/sounds/episodios/ambiente_noise_sublime.mp3")

    _ambiente(c)
    familias_cone, malhas_cone = _cones(c, L.so_luzes(plano_luz))
    _navmesh(c, nav)
    _poeira(c)
    _chuva(c)

    # ---- raiz
    c.no("escola", tipo="Node3D",
         props=[("script", 'ExtResource("%s")' % id_script)])
    c.no("WorldEnvironment", tipo="WorldEnvironment", pai=".",
         props=[("environment", 'SubResource("ambiente")')])
    c.no("Pause", pai=".", instancia=id_pause)
    c.no("fade", pai=".", instancia=id_fade)
    # O minimapa NAO e' so' o canto da tela: ele e' o no' que declara qual mapa
    # esta cena usa (grupo "mapa_cidade"), e a aba MAPA do menu pergunta a ele.
    # Sem isto aqui dentro, o menu diz "nenhum mapa disponivel".
    c.no("minimapa", pai=".", instancia=id_minimapa)

    entrada, giro = _ponto_de_entrada()
    c.no("Player", pai=".", instancia=id_player,
         props=[("transform", C.transform_pos(entrada, giro))])

    c.no("estrutura", pai=".", instancia=id_estrutura)
    C.emitir_colisoes(c, colisoes)

    # ---- moveis
    c.no("mobilia", tipo="Node3D", pai=".")
    c.no("colisao_mobilia", tipo="StaticBody3D", pai=".",
         props=[("collision_layer", "2"), ("collision_mask", "0")])
    usados = set()
    n_bloqueio = 0
    for (i, p) in enumerate(props):
        nome = "%s_%s" % (p["sala"], p["nome"])
        if nome in usados:
            nome += "_%d" % i
        usados.add(nome)
        y = p["y"] + p.get("dy", 0.0)
        id_peca = (c.peca(p["arquivo"]) if p["tipo"] == "caixas"
                   else c.externo("PackedScene", MOB.caminho(p["modelo"])))
        c.no(nome, pai="mobilia", instancia=id_peca,
             props=[("transform", C.transform_pos((p["x"], y, p["z"]),
                                                  p["giro"],
                                                  p.get("escala", 1.0)))])
        if p.get("bloqueia"):
            lx, lz = p["bloqueia"]
            ident = c.forma(lx, 1.6, lz)
            c.no("cm%d" % n_bloqueio, tipo="CollisionShape3D",
                 pai="colisao_mobilia",
                 props=[("transform",
                         C.transform_pos((p["x"], p["y"] + 0.8, p["z"]))),
                        ("shape", 'SubResource("%s")' % ident)])
            n_bloqueio += 1

    # ---- luminarias
    c.no("luminarias", tipo="Node3D", pai=".")
    for (i, lum) in enumerate(lista_luminarias):
        giro_l = lum.get("giro", 0.0 if lum["eixo"] == "x" else math.pi * 0.5)
        c.no("lum_%d" % i, pai="luminarias", instancia=c.peca(lum["arquivo"]),
             props=[("transform", C.transform_pos(lum["pos"], giro_l))])

    # ---- cones de luz (o "volumetrico" possivel no renderer mobile)
    c.no("cones", tipo="Node3D", pai=".")
    for (chave, grupo) in familias_cone.items():
        ident_malha, altura = malhas_cone[chave]
        for luz in grupo:
            x, y, z = luz["pos"]
            c.no("cone_" + luz["nome"], tipo="MeshInstance3D", pai="cones",
                 props=[("transform", C.transform_pos((x, y - altura * 0.5, z))),
                        ("mesh", 'SubResource("%s")' % ident_malha),
                        ("cast_shadow", "0")])

    # ---- luzes
    c.no("luzes", tipo="Node3D", pai=".")
    for luz in L.so_luzes(plano_luz):
        props_ = [("light_color", C.cor(luz["cor"])),
                  ("light_energy", "%.3f" % luz["energia"]),
                  ("light_volumetric_fog_energy", "%.2f" % luz["fog"]),
                  ("shadow_enabled", "true" if luz["sombra"] else "false"),
                  ("distance_fade_enabled", "true"),
                  ("distance_fade_begin", "26.0"),
                  ("distance_fade_shadow", "16.0"),
                  ("distance_fade_length", "8.0")]
        if luz["tipo"] == "OmniLight3D":
            props_.append(("omni_range", "%.2f" % luz["alcance"]))
            props_.append(("omni_attenuation", "1.35"))
            xform = C.transform_pos(luz["pos"])
        else:
            props_.append(("spot_range", "%.2f" % luz["alcance"]))
            props_.append(("spot_angle", "%.1f" % luz["angulo"]))
            props_.append(("spot_angle_attenuation", "0.9"))
            props_.append(("spot_attenuation", "%.2f" % L.QUEDA_TETO))
            props_.append(("shadow_bias", "0.05"))
            props_.append(("shadow_normal_bias", "1.4"))
            xform = C.transform_olhando(luz["pos"], luz["mira"])
        metas = []
        if luz["piscar"]:
            metas.append(("piscar", '"%s"' % luz["piscar"]))
        c.no(luz["nome"], tipo=luz["tipo"], pai="luzes",
             props=[("transform", xform)] + props_, metas=metas)

    # ---- a lua
    #
    # A unica luz direcional da cena, e ela existe por causa do PATIO: sem ceu
    # entrando por aquela abertura, o unico espaco descoberto do mapa ficaria
    # tao escuro quanto o corredor, e a diferenca entre "dentro" e "fora" — que
    # e' a leitura do lugar inteiro — sumiria. O predio tem forro em cima de
    # todos os outros comodos, entao ela nao vaza pra lugar nenhum.
    #
    # 1,5 de energia, e nao os 0,55 da primeira versao. Medido no jogo: com
    # 0,55 o patio ficava mais escuro que o corredor coberto, o que inverte a
    # leitura do mapa inteiro — o unico lugar aberto tem de ser o lugar em que
    # se enxerga. O piso de cimento tem albedo 0,40 e come quase tudo o que
    # recebe; e' preciso jogar luz de verdade nele.
    c.no("lua", tipo="DirectionalLight3D", pai=".",
         props=[("transform", C.transform_olhando((24.0, 22.0, 30.0),
                                                  (0.35, -1.0, 0.55))),
                ("light_color", C.cor(L.LUAR)),
                ("light_energy", "1.50"),
                ("light_specular", "0.25"),
                ("shadow_enabled", "true"),
                ("shadow_bias", "0.06"),
                ("directional_shadow_mode", "1"),
                ("directional_shadow_max_distance", "85.0")])

    # ---- portas
    c.no("portas", tipo="Node3D", pai=".")
    for d in portas:
        _emitir_porta(c, d, id_porta_gd)

    # ---- a grade do corredor sul
    _emitir_grade(c, arq_grade, id_grade_gd)

    # ---- os dois buracos
    for b in (P.BURACO_ENTRADA, P.BURACO_SAIDA):
        _emitir_buraco(c, b, id_buraco_gd)

    # ---- os pontos de chegada
    #
    # Sao tres: a rua, o deposito (buraco de entrada) e o almoxarifado (buraco
    # de saida). Moram na CENA, e nao no codigo, pelo mesmo motivo do hospital:
    # mexer na planta move o buraco, e uma coordenada escrita no .gd ficaria
    # mentindo sem ninguem perceber ate' um jogador nascer dentro da parede.
    for (nome, ident, recuo) in (("chegada_rua", "portao_rua", 3.20),
                                 ("chegada_deposito", "buraco_entrada", 2.60),
                                 ("chegada_almoxarifado", "buraco_saida", 2.60)):
        ponto = P.ponto_do_vao(ident, recuo)
        alvo = P.ponto_do_vao(ident, recuo + 3.0) or ponto
        c.no(nome, tipo="Marker3D", pai=".",
             props=[("transform", C.transform_pos(
                 (ponto[0], P.cota() + 0.10, ponto[1]),
                 _olhar_para(ponto, alvo)))])

    # ---- navegacao
    c.no("NavigationRegion3D", tipo="NavigationRegion3D", pai=".",
         props=[("navigation_mesh", 'SubResource("navmesh")'),
                ("navigation_layers", "4")])

    # ---- pichacao
    n_mat = C.emitir_pichacao(c, rabiscos)

    # ---- poeira, chuva e som
    c.no("poeira", tipo="GPUParticles3D", pai=".",
         props=[("transform", C.transform_pos((38.0, P.cota() + 1.6, 34.0))),
                ("amount", "700"), ("lifetime", "16.0"), ("preprocess", "9.0"),
                ("visibility_aabb", "AABB(-40, -2.5, -36, 80, 5, 72)"),
                ("process_material", 'SubResource("poeira_proc")'),
                ("draw_pass_1", 'SubResource("poeira_quad")')])
    patio = P.por_ident("patio")
    px, pz = P.centro(patio)
    c.no("chuva_patio", tipo="GPUParticles3D", pai=".",
         props=[("transform", C.transform_pos((px, P.PATIO_MURO_ALTO + 1.5, pz))),
                ("amount", "1400"), ("lifetime", "1.6"), ("preprocess", "1.4"),
                ("visibility_aabb", "AABB(-24, -8, -20, 48, 12, 40)"),
                ("process_material", 'SubResource("chuva_proc")'),
                ("draw_pass_1", 'SubResource("chuva_quad")')])
    c.no("ambiencia", tipo="AudioStreamPlayer", pai=".",
         props=[("stream", 'ExtResource("%s")' % id_ambiente),
                ("volume_db", "-14.0"), ("autoplay", "true")])

    c.gravar(SAIDA_CENA)
    print("  %d materiais de rabisco, %d nos, %d sub-recursos"
          % (n_mat, sum(1 for l in c.linhas if l.startswith("[node ")),
             len(c.sub)))


def _olhar_para(de, para):
    """rotation.y que poe o -Z do no' apontando de `de` pra `para`.

    Um no' com rotation.y = t olha pra (-sen t, 0, -cos t) — dai o atan2 com os
    dois sinais trocados. Escrever so' `atan2(dx, dz)` espelha o jogador e ele
    nasce de cara pra parede que acabou de atravessar.
    """
    dx, dz = para[0] - de[0], para[1] - de[1]
    if abs(dx) < 1e-6 and abs(dz) < 1e-6:
        return 0.0
    return math.atan2(-dx, -dz)


def _ponto_de_entrada():
    """No patio, logo dentro do portao da rua, olhando pra quadra.

    Da' pra nascer em outro lugar sem mexer no codigo, o que economiza muita
    caminhada quando se esta' testando o outro lado do predio:

        ESCOLA_SPAWN="60,1.05,54,180" tools/godot/escola/construir.sh

    (x, y, z, giro em graus).
    """
    teste = os.environ.get("ESCOLA_SPAWN")
    if teste:
        n = [float(v) for v in teste.split(",")]
        return (n[0], n[1], n[2]), math.radians(n[3] if len(n) > 3 else 0.0)
    ponto = P.ponto_do_vao("portao_rua", 3.20)
    return (ponto[0], P.cota() + 1.05, ponto[1]), -math.pi * 0.5


def _emitir_porta(c, d, id_script):
    caminho = "portas/" + d["ident"]
    metas = [("sala", '"%s"' % d["chave"]),
             ("largura", "%.3f" % d["largura"]),
             ("dupla", "true" if d["dupla"] else "false"),
             ("trancada", "true" if d["trancada"] else "false"),
             ("saida", "true" if d["saida"] else "false"),
             ("portao", "true" if d["portao"] else "false")]
    c.no(d["ident"], tipo="Node3D", pai="portas",
         props=[("transform", C.transform_pos(d["pos"], d["giro"])),
                ("script", 'ExtResource("%s")' % id_script)], metas=metas)

    meia = d["largura"] * 0.5
    folhas = [("pivo", -meia, 0.0)]
    if d["dupla"]:
        folhas.append(("pivo_b", meia, math.pi))

    altura = (P.PORTA_H + 0.20) if d["portao"] else (P.PORTA_H - 0.05)
    for (nome, dx, giro) in folhas:
        c.no(nome, tipo="Node3D", pai=caminho,
             props=[("transform", C.transform_pos((dx, 0.0, 0.0), giro))])
        c.no("folha", pai=caminho + "/" + nome,
             instancia=c.peca(d["arquivo"]))
        corpo = caminho + "/" + nome + "/corpo"
        c.no("corpo", tipo="AnimatableBody3D", pai=caminho + "/" + nome,
             props=[("collision_layer", "2"), ("collision_mask", "0"),
                    ("sync_to_physics", "false")])
        ident = c.forma(d["larg_folha"], altura, 0.09)
        c.no("forma", tipo="CollisionShape3D", pai=corpo,
             props=[("transform", C.transform_pos(
                 (d["larg_folha"] * 0.5, altura * 0.5, 0.0))),
                 ("shape", 'SubResource("%s")' % ident)])

    # A area cobre os DOIS lados do vao: e' ela que acende o prompt, e o
    # jogador pode chegar por dentro ou por fora. JUSTA de proposito (0,3 m de
    # folga lateral, 1,2 m pra cada lado do muro): area larga demais faz dois
    # prompts aparecerem juntos na tela onde duas portas ficam perto.
    ident = c.forma(d["largura"] + 0.6, P.PORTA_H, 2.4)
    c.no("area", tipo="Area3D", pai=caminho,
         props=[("transform", C.transform_pos((0.0, P.PORTA_H * 0.5, 0.0))),
                ("collision_layer", "0"), ("monitorable", "false")])
    c.no("forma", tipo="CollisionShape3D", pai=caminho + "/area",
         props=[("shape", 'SubResource("%s")' % ident)])


def _emitir_grade(c, arquivo, id_script):
    """A grade e o aviso dela.

    A Area3D e' generosa (4 m) e nao justa como a de porta: aqui nao existe
    outro prompt por perto pra brigar com ela, e o que se quer e' que o jogador
    leia "nao passa" ANTES de encostar o nariz na barra — quem encosta primeiro
    e le' depois ja' achou que era bug.
    """
    cz = (P.GRADE_Z0 + P.GRADE_Z1) * 0.5
    c.no("grade", tipo="Node3D", pai=".",
         props=[("transform", C.transform_pos((P.GRADE_X, P.cota(), cz))),
                ("script", 'ExtResource("%s")' % id_script)])
    c.no("malha", pai="grade", instancia=c.peca(arquivo))
    # A caixa de colisao vai em coordenadas LOCAIS (centrada em zero), e nao
    # nas de mundo: ela e' filha do no' `grade`, que JA' esta' deslocado ate' o
    # corredor. Com as coordenadas de mundo a colisao somava duas vezes e ia
    # parar a cinquenta metros fora do predio — e a grade continuava desenhada
    # no lugar certo, entao o defeito so' aparecia andando: o jogador
    # atravessava a barra e o porao deixava de ter motivo pra existir.
    meia_z = (P.GRADE_Z1 - P.GRADE_Z0) * 0.5 + 0.2
    C.emitir_colisoes(c, [(-P.GRADE_ESP * 0.5, P.GRADE_ESP * 0.5,
                           0.0, P.PE, -meia_z, meia_z)],
                      nome="colisao", pai="grade")
    ident = c.forma(4.0, P.PE, P.GRADE_Z1 - P.GRADE_Z0 + 1.0)
    c.no("area", tipo="Area3D", pai="grade",
         props=[("transform", C.transform_pos((0.0, P.PE * 0.5, 0.0))),
                ("collision_layer", "0"), ("monitorable", "false")])
    c.no("forma", tipo="CollisionShape3D", pai="grade/area",
         props=[("shape", 'SubResource("%s")' % ident)])


def _emitir_buraco(c, b, id_script):
    """O rombo: uma Area3D com script na boca do nicho.

    O no' fica no plano da parede e a area avanca pro lado de DENTRO do
    comodo — quem esta' no nicho ja' passou do ponto de acionar.
    """
    dx, dz = _direcao_do_buraco_no_plano(b)
    x, z = b["x"], b["z"]
    pos = (x - dx * 1.0, P.cota(), z - dz * 1.0)
    c.no(b["ident"], tipo="Node3D", pai=".",
         props=[("transform", C.transform_pos(pos)),
                ("script", 'ExtResource("%s")' % id_script)],
         metas=[("papel", '"%s"' % b["ident"])])
    ident = c.forma(P.BURACO_L + 2.2 if dz else 3.0,
                    P.BURACO_H + 0.6,
                    3.0 if dz else P.BURACO_L + 2.2)
    c.no("area", tipo="Area3D", pai=b["ident"],
         props=[("transform", C.transform_pos((0.0, P.BURACO_H * 0.5, 0.0))),
                ("collision_layer", "0"), ("monitorable", "false")])
    c.no("forma", tipo="CollisionShape3D", pai=b["ident"] + "/area",
         props=[("shape", 'SubResource("%s")' % ident)])


def _direcao_do_buraco_no_plano(b):
    return {"n": (0.0, -1.0), "s": (0.0, 1.0),
            "o": (-1.0, 0.0), "l": (1.0, 0.0)}[b["lado"]]


# ==========================================================================
# sub_resources fixos
# ==========================================================================

def _ambiente(c):
    c.recurso("ceu_mat", "ProceduralSkyMaterial", [
        "sky_top_color = Color(0.040, 0.046, 0.068, 1)",
        "sky_horizon_color = Color(0.10, 0.11, 0.15, 1)",
        "sky_curve = 0.15",
        "ground_bottom_color = Color(0.02, 0.02, 0.03, 1)",
        "ground_horizon_color = Color(0.06, 0.07, 0.09, 1)",
        "sun_angle_max = 2.0",
        "use_debanding = true",
    ])
    c.recurso("ceu", "Sky", ['sky_material = SubResource("ceu_mat")'])
    # ==================================================================
    # O QUE NAO ESTA' AQUI, E POR QUE
    #
    # O projeto roda em `rendering_method="mobile"` (project.godot). Nevoa
    # VOLUMETRICA, SSAO, SSIL, SSR e SDFGI sao exclusivos do Forward+: no
    # mobile eles nao fazem nada e ainda avisam no console a cada carga.
    #
    # Entao o feixe de luz no ar e' GEOMETRIA (um cone translucido por
    # luminaria acesa, ver `_cones`), a oclusao de canto vem assada no canal
    # de oclusao das texturas do Poly Haven, e a profundidade do corredor vem
    # da nevoa de distancia, que essa o mobile tem.
    # ==================================================================
    c.recurso("ambiente", "Environment", [
        "background_mode = 2",
        'sky = SubResource("ceu")',
        "background_energy_multiplier = 0.6",
        "ambient_light_source = 3",
        "ambient_light_color = Color(0.20, 0.23, 0.28, 1)",
        "ambient_light_sky_contribution = 0.30",
        # O PISO DO ESCURO desta cena. Ele define o quao preto fica um comodo
        # sem lampada nenhuma. Alto para uma cena de terror, e de proposito:
        # quem faz o medo aqui sao as lampadas piscando, nao a ausencia de
        # imagem — o trecho entre duas luminarias precisa mostrar a FORMA das
        # coisas sem mostrar o detalhe delas. (No porao este numero e' quatro
        # vezes menor: la' o escuro E' o assunto.)
        "ambient_light_energy = 1.75",
        "reflected_light_source = 2",
        "tonemap_mode = 3",
        "tonemap_exposure = 1.0",
        "tonemap_white = 7.5",
        "glow_enabled = true",
        "glow_intensity = 0.42",
        "glow_strength = 1.05",
        "glow_bloom = 0.15",
        "glow_blend_mode = 1",
        "glow_hdr_threshold = 1.10",
        "fog_enabled = true",
        "fog_mode = 0",
        "fog_light_color = Color(0.13, 0.15, 0.19, 1)",
        "fog_light_energy = 0.8",
        "fog_density = 0.015",
        "fog_aerial_perspective = 0.1",
        "fog_sky_affect = 0.20",
        "fog_height = -2.0",
        "fog_height_density = 0.05",
        "adjustment_enabled = true",
        "adjustment_brightness = 1.0",
        "adjustment_contrast = 1.12",
        "adjustment_saturation = 0.82",
    ])


def _cones(c, luzes):
    """Um cone translucido por luminaria acesa — o feixe no ar, em geometria.

    Sem nevoa volumetrica (o renderer do projeto e' o mobile), o feixe tem de
    existir como malha. Tres ingredientes o impedem de parecer plastico:
    `blend_mode` aditivo com `shading_mode` unshaded (ele SOMA luz em vez de
    tapar o que esta' atras), `proximity_fade` (apaga a aresta onde o cone
    encosta no chao — sem isso aparece um circulo duro no piso) e
    `distance_fade` (alem de 20 m ele some; sem isso o corredor vira sopa
    branca e o overdraw explode).
    """
    familias = {}
    for luz in luzes:
        if luz["tipo"] != "SpotLight3D" or luz["mira"][1] > -0.9:
            continue
        raio = luz["alcance"] * math.tan(math.radians(luz["angulo"]))
        chave = (round(raio, 1), round(luz["alcance"], 1),
                 tuple(round(x, 2) for x in luz["cor"][:3]))
        familias.setdefault(chave, []).append(luz)

    feito = {}
    for (raio, alcance, cor_) in familias:
        ident_mat = "cone_mat_%d" % len(feito)
        ident_malha = "cone_malha_%d" % len(feito)
        c.recurso(ident_mat, "StandardMaterial3D", [
            "transparency = 1",
            "blend_mode = 1",
            "shading_mode = 0",
            # So' a casca de TRAS do cone. Com as duas faces o olhar atravessa
            # duas camadas aditivas de uma vez e o feixe dobra de intensidade
            # bem no meio da tela.
            "cull_mode = 1",
            "albedo_color = Color(%.3f, %.3f, %.3f, 0.011)" % cor_,
            "disable_receive_shadows = true",
            "proximity_fade_enabled = true",
            "proximity_fade_distance = 1.8",
            "distance_fade_mode = 1",
            "distance_fade_min_distance = 20.0",
            "distance_fade_max_distance = 13.0",
        ])
        altura = min(alcance, P.PE - 0.30)
        c.recurso(ident_malha, "CylinderMesh", [
            'material = SubResource("%s")' % ident_mat,
            "top_radius = 0.22",
            "bottom_radius = %.3f" % max(raio * (altura / alcance), 0.4),
            "height = %.3f" % altura,
            "radial_segments = 16",
            "rings = 0",
            "cap_top = false",
            "cap_bottom = false",
        ])
        feito[(raio, alcance, cor_)] = (ident_malha, altura)
    return familias, feito


def _navmesh(c, nav):
    vertices, poligonos, _perdidas = nav
    pv = ", ".join("%.2f, %.2f, %.2f" % tuple(v) for v in vertices)
    pp = ", ".join("PackedInt32Array(%s)" % ", ".join(str(k) for k in pol)
                   for pol in poligonos)
    c.recurso("navmesh", "NavigationMesh", [
        "vertices = PackedVector3Array(%s)" % pv,
        "polygons = [%s]" % pp,
    ])


def _poeira(c):
    c.recurso("poeira_mat", "StandardMaterial3D", [
        "transparency = 1", "blend_mode = 1", "shading_mode = 0",
        "vertex_color_use_as_albedo = true",
        "albedo_color = Color(0.72, 0.74, 0.78, 0.13)",
        "billboard_mode = 3",
        # sem isto o billboard descarta a escala e scale_min/max nao valem nada
        "billboard_keep_scale = true",
        "disable_receive_shadows = true",
    ])
    c.recurso("poeira_quad", "QuadMesh", [
        'material = SubResource("poeira_mat")', "size = Vector2(0.03, 0.03)",
    ])
    c.recurso("poeira_proc", "ParticleProcessMaterial", [
        "lifetime_randomness = 0.8", "emission_shape = 3",
        "emission_box_extents = Vector3(37.0, 1.7, 33.0)",
        "direction = Vector3(0, -1, 0)", "spread = 60.0",
        "initial_velocity_min = 0.02", "initial_velocity_max = 0.14",
        "gravity = Vector3(0.02, -0.05, 0.01)",
        "scale_min = 0.3", "scale_max = 1.5",
        "color = Color(1, 1, 1, 0.16)",
        "turbulence_enabled = true", "turbulence_noise_strength = 0.16",
    ])


def _chuva(c):
    """Chuva SO' EM CIMA DO PATIO.

    E' o unico lugar da cena que tem ceu. Emitida de uma caixa do tamanho do
    patio e com vida curta o bastante pra a gota morrer perto do chao — chuva
    atravessando a laje do corredor vizinho denunciaria na hora que o predio
    nao tem telhado de verdade.
    """
    c.recurso("chuva_mat", "StandardMaterial3D", [
        "transparency = 1", "blend_mode = 1", "shading_mode = 0",
        "albedo_color = Color(0.62, 0.70, 0.82, 0.10)",
        "billboard_mode = 2", "billboard_keep_scale = true",
        "disable_receive_shadows = true",
    ])
    c.recurso("chuva_quad", "QuadMesh", [
        'material = SubResource("chuva_mat")', "size = Vector2(0.012, 0.75)",
    ])
    c.recurso("chuva_proc", "ParticleProcessMaterial", [
        "emission_shape = 3",
        "emission_box_extents = Vector3(22.0, 0.5, 18.0)",
        "direction = Vector3(0.10, -1, 0.06)", "spread = 3.0",
        "initial_velocity_min = 16.0", "initial_velocity_max = 21.0",
        "gravity = Vector3(0, -12, 0)",
        "scale_min = 0.7", "scale_max = 1.3",
        "color = Color(1, 1, 1, 0.5)",
    ])


if __name__ == "__main__":
    gerar()
