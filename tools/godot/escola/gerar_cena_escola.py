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

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comum as C
import detalhes as DET
import gltf
import luzes as L
import materiais as M
import mobilia as MOB
import navmesh as NAV
import pichacao as PICH
import planta as P
import textos as TXT
import texturas as TEX

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
    print("== texturas e textos ==")
    TEX.gerar()
    novas, atualizadas = TXT.sincronizar()
    print("  csv de traducao: %d chaves novas, %d atualizadas"
          % (novas, atualizadas))

    # Moveis e detalhes ANTES da luz: as placas de SAIDA trazem luz propria,
    # e a conta de luz por malha (que escolhe o tamanho do setor) tem de
    # enxergar todas.
    print("== moveis ==")
    # Antes de qualquer coisa: modelo grande demais pra caber onde a receita o
    # poe. Um .gltf modular do Poly Haven ja' atravessou tres comodos aqui sem
    # dar erro nenhum — melhor descobrir contando.
    for erro in MOB.conferir_modelos():
        print("  !! " + erro)
    props = MOB.mobiliar()
    print("== detalhes ==")
    det = DET.montar(props)
    extras = det.props + _placas(det, props)
    print("  %d decalques, %d textos, %d pecas soltas, %d bolinhas de papel, "
          "%d ventiladores" % (len(det.quads), len(det.textos), len(extras),
                               len(det.bolas), len(det.ventiladores)))

    print("== luzes ==")
    plano_luz = L.montar() + L.luzes_de_saida(det.saidas)
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

    print("== pecas ==")
    pecas = C.Pecas()
    for p in props + extras:
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
          % (len(props) + len(extras), len(pecas.arquivos), tris_pecas))
    print("  %d portas (%d duplas)"
          % (len(portas), sum(1 for d in portas if d["dupla"])))

    print("== pichacao ==")
    rabiscos = PICH.montar()
    for r in rabiscos:
        r["_res_atlas"] = PICH.RES_ATLAS[r["atlas"]]
    print("  %d rabiscos" % len(rabiscos))

    print("== navmesh ==")
    nav = NAV.malha(props + extras)

    print("== cena ==")
    escrever_cena(colisoes, props + extras, portas, plano_luz, lista_luminarias,
                  nav, rabiscos, arq_grade, det)
    print("  gravado: %s" % SAIDA_CENA)


# --------------------------------------------------------------------------
# placas: o nome da sala sobre a porta, a SAIDA acesa, a placa pendurada do
# corredor
# --------------------------------------------------------------------------

def _textos_do_csv():
    """chave -> (en, pt), do CSV do jogo (os nomes das salas nao estao no
    textos.py: vieram antes dele)."""
    import csv
    caminho = os.path.join(C.BASE, "assets", "textos", "red_valve_textos_gerais.csv")
    with open(caminho, encoding="utf-8") as f:
        return {l["keys"]: (l["en"], l["pt"]) for l in csv.DictReader(f)}


def _placas(det, props):
    """Converte as placas que `detalhes.py` posicionou em pecas de caixa — e
    escreve o TEXTO de cada uma na lista de textos do `det`."""
    saida = []
    falso = {"ident": "placas"}
    for (i, pp) in enumerate(det.placas_porta):
        x, y, z = pp["pos"]
        # plaquinha do tamanho do nome (o mais comprido entre EN e PT)
        letras = max(len(t) for t in _textos_do_csv().get(pp["chave"], ("x" * 12,)))
        larg = max(0.34, letras * 48 * 0.0012 * 0.56 + 0.10)
        pecas = [(0.0, 0.0, 0.0, larg, 0.13, 0.018, "mat_placa"),
                 (0.0, 0.0, -0.006, larg + 0.03, 0.16, 0.008, "mat_metal_escuro")]
        p = MOB.caixas_solto(falso, pecas, x, z, pp["giro"], "porta_%d" % i,
                             dy=y - P.cota())
        saida.append(p)
        nx, nz = math.sin(pp["giro"]), math.cos(pp["giro"])
        det.texto(pp["chave"], "placa", (x + nx * 0.011, y, z + nz * 0.011),
                  pp["giro"], 48, (0.10, 0.12, 0.11, 0.95), px=0.0012)
    for (i, sd) in enumerate(det.saidas):
        x, y, z = sd["pos"]
        p = MOB.caixas_solto(falso, [(0.0, 0.0, 0.0, 0.66, 0.26, 0.07,
                                      "mat_placa_saida")],
                             x, z, sd["giro"], "saida_%d" % i, dy=y - P.cota())
        saida.append(p)
        nx, nz = math.sin(sd["giro"]), math.cos(sd["giro"])
        det.texto("ESC_PLACA_SAIDA", "placa", (x + nx * 0.037, y, z + nz * 0.037),
                  sd["giro"], 96, (0.62, 0.80, 0.66, 1.0), px=0.0019, aceso=True)
    # A chapa de aviso presa na grade (`pecas_da_grade`: 0,52 x 0,36 m, a
    # 1,70 m, deslocada 5 cm pro leste do eixo das barras). Escrita nas duas
    # faces: quem chega pelo corredor e quem chega pelo almoxarifado le' o
    # mesmo "nao passa".
    cz = (P.GRADE_Z0 + P.GRADE_Z1) * 0.5
    for (dx, g) in ((0.065, math.pi * 0.5), (0.035, -math.pi * 0.5)):
        det.texto("ESC_PLACA_INTERDITADO", "placa",
                  (P.GRADE_X + dx, P.cota() + 1.70, cz), g, 40,
                  (0.55, 0.08, 0.06, 0.95), px=0.0011)
    # A placa pendurada no forro de cada corredor (`placa_seta` do
    # mobilia.py) ganha o nome da ala — dos dois lados, porque e' vista
    # chegando e voltando.
    nome_ala = {"corredor_norte": "ESC_PLACA_BLOCO_A",
                "corredor_sul": "ESC_PLACA_BLOCO_B",
                "corredor_leste": "ESC_PLACA_LESTE"}
    for p in props:
        if not p.get("nome", "").startswith("placa_") or p["sala"] not in nome_ala:
            continue
        y = p["y"] + p.get("dy", 0.0) + MOB.PLACA_TEXTO_Y
        for lado in (1.0, -1.0):
            g = p["giro"] + (0.0 if lado > 0 else math.pi)
            nx, nz = math.sin(g), math.cos(g)
            det.texto(nome_ala[p["sala"]], "placa",
                      (p["x"] + nx * 0.022, y, p["z"] + nz * 0.022), g, 56,
                      (0.90, 0.92, 0.88, 0.95), px=0.0016)
    return saida


# ==========================================================================
# O .tscn
# ==========================================================================

def escrever_cena(colisoes, props, portas, plano_luz, lista_luminarias, nav,
                  rabiscos, arq_grade, det):
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
    encostos = _encostos()
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
        ex, ey, ez = encostos.get("mobilia/" + nome, (0.0, 0.0, 0.0))
        p = dict(p, x=p["x"] + ex, z=p["z"] + ez)
        y += ey
        id_peca = (c.peca(p["arquivo"]) if p["tipo"] == "caixas"
                   else c.externo("PackedScene", MOB.caminho(p["modelo"])))
        if p.get("fisico"):
            # RigidBody3D carrega posicao e giro; a malha e a colisao vivem
            # DENTRO dele, com transform proprio, pra ele levar as duas junto
            # quando rolar. Mesma layer/mask do chao: o player esbarra nele
            # igual esbarraria numa parede.
            c.no(nome, tipo="RigidBody3D", pai="mobilia",
                 props=[("transform", C.transform_geral((p["x"], y, p["z"]),
                                                        p["giro"],
                                                        p.get("incl", 0.0),
                                                        p.get("incl_z", 0.0))),
                        ("collision_layer", "2"), ("collision_mask", "2"),
                        ("mass", "%.2f" % p.get("massa", 5.0)),
                        ("linear_damp", "2.0"), ("angular_damp", "3.0")])
            c.no(nome + "_malha", pai="mobilia/" + nome, instancia=id_peca,
                 props=[("transform", C.transform_pos((0.0, 0.0, 0.0), 0.0,
                                                      p.get("escala", 1.0)))])
            cx, cy, cz = p["fisico_centro"]
            ident = c.forma(*p["fisico_caixa"])
            c.no(nome + "_colisao", tipo="CollisionShape3D", pai="mobilia/" + nome,
                 props=[("transform", C.transform_pos((cx, cy, cz))),
                        ("shape", 'SubResource("%s")' % ident)])
            continue
        c.no(nome, pai="mobilia", instancia=id_peca,
             props=[("transform", C.transform_geral((p["x"], y, p["z"]),
                                                    p["giro"],
                                                    p.get("incl", 0.0),
                                                    p.get("incl_z", 0.0),
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
        ex, ey, ez = encostos.get("luminarias/lum_%d" % i, (0.0, 0.0, 0.0))
        pos_l = (lum["pos"][0] + ex, lum["pos"][1] + ey, lum["pos"][2] + ez)
        c.no("lum_%d" % i, pai="luminarias", instancia=c.peca(lum["arquivo"]),
             props=[("transform", C.transform_pos(pos_l, giro_l))])

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

    # ---- a camada de vida: papel, cartaz, escrita, lixo, agua, teia
    _emitir_decalques(c, det.quads)
    _emitir_textos(c, det.textos)
    _emitir_bolas(c, det.bolas)
    _emitir_ventiladores(c, det.ventiladores)
    _emitir_bandeirinhas(c, det.bandeiras, det.cordoes)
    _emitir_feixes(c)
    _emitir_sons(c, det.sons, L.so_luzes(plano_luz))
    _emitir_lente(c)

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


# ==========================================================================
# A CAMADA DE VIDA (ver `detalhes.py`)
# ==========================================================================

# Ate' onde cada coisa pequena e' desenhada. Papel de 20 cm a 30 m de distancia
# ocupa meio pixel e custa uma chamada de desenho inteira; a escuridao e a
# nevoa ja' engoliram tudo antes disso.
ALCANCE_CHAO = 26.0
ALCANCE_PAREDE = 34.0


def _material_decalque(c, ident, q, tom):
    u0, v0, du, dv = TEX.recorte(q["atlas"], q["cel"])
    tex = c.externo("Texture2D", TEX.caminho_res(q["atlas"]))
    linhas = [
        'albedo_texture = ExtResource("%s")' % tex,
        "texture_repeat = false",
        "uv1_scale = Vector3(%.6f, %.6f, 1)" % (du, dv),
        "uv1_offset = Vector3(%.6f, %.6f, 0)" % (u0, v0),
        # `cull_mode = 2`: o QuadMesh FACE_Z nao encara o +Z local, e com
        # culling ele some sem erro nenhum (ver `pichacao.py`)
        "cull_mode = 2",
    ]
    tipo = q["tipo"]
    if tipo in ("papel", "cartaz"):
        # Papel tem silhueta cheia: corte por alfa (opaco, escreve
        # profundidade, recebe sombra) e nao mistura. Cartaz e' plastificado,
        # e o brilho dele e' o que a lanterna pega de raspao.
        linhas += ["transparency = 2", "alpha_scissor_threshold = 0.5",
                   "albedo_color = Color(%.3f, %.3f, %.3f, 1)" % (tom, tom, tom * 0.97),
                   "roughness = %.2f" % (0.55 if tipo == "cartaz" else 0.92),
                   "distance_fade_mode = 3",
                   "distance_fade_min_distance = %.1f" % (ALCANCE_PAREDE if tipo == "cartaz" else ALCANCE_CHAO),
                   "distance_fade_max_distance = %.1f" % ((ALCANCE_PAREDE if tipo == "cartaz" else ALCANCE_CHAO) - 6.0)]
    elif tipo == "poca":
        # A poca e' a unica superficie espelhada da escola: a cor vem do
        # material (quase preta) e a textura so' da' a forma. O brilho e' o
        # reflexo especular das lampadas — a coisa que mais vende "agua" no
        # escuro.
        # Meio transparente: opaca e escura, a poca virava um BURACO preto no
        # chao (a curva de sombra da lente denunciava a borda dela de longe).
        # Mistura comum com alfa BAIXO. Opaca e escura, a poca virava um
        # buraco preto no chao; com alfa pre-multiplicado o reflexo entrava no
        # quad INTEIRO (inclusive fora da mascara) e ela virava um quadrado.
        linhas += ["transparency = 1", "depth_draw_mode = 2",
                   "albedo_color = Color(0.07, 0.08, 0.09, 0.32)",
                   "roughness = 0.02", "metallic = 0.0", "metallic_specular = 1.0"]
    elif tipo == "caco":
        linhas += ["transparency = 1", "depth_draw_mode = 2",
                   "albedo_color = Color(0.80, 0.86, 0.88, 0.9)",
                   "roughness = 0.10", "metallic = 0.55", "metallic_specular = 1.0"]
    else:
        linhas += ["transparency = 1", "depth_draw_mode = 2",
                   "albedo_color = Color(%.3f, %.3f, %.3f, 1)" % (tom, tom, tom),
                   "roughness = 0.95"]
    if tipo not in ("papel", "cartaz"):
        alcance = ALCANCE_PAREDE if q["plano"] != "chao" else ALCANCE_CHAO
        linhas += ["distance_fade_mode = 1",
                   "distance_fade_min_distance = %.1f" % alcance,
                   "distance_fade_max_distance = %.1f" % (alcance - 6.0)]
    c.recurso(ident, "StandardMaterial3D", linhas)


def _xform_decalque(q):
    x, y, z = q["pos"]
    g = q["giro"]
    co, si = math.cos(g), math.sin(g)
    if q["plano"] == "chao":
        return C._matriz((co, 0.0, -si), (-si, 0.0, -co), (0.0, 1.0, 0.0), (x, y, z))
    if q["plano"] == "teto":
        return C._matriz((co, 0.0, -si), (si, 0.0, co), (0.0, -1.0, 0.0), (x, y, z))
    return C.transform_pos((x, y, z), g)


def _decalque_sem_parede(q):
    """Decalque de parede que caiu onde a parede nao existe — numa esquina de
    corredores ou num vao de porta — ficava pregado no ar."""
    if q["plano"] in ("chao", "teto"):
        return False
    x, y, z = q["pos"]
    nx, nz = math.sin(q["giro"]), math.cos(q["giro"])
    bx, bz = x - nx * 0.2, z - nz * 0.2
    for e in P.espacos():
        if e["x0"] <= bx <= e["x1"] and e["z0"] <= bz <= e["z1"]:
            return True
    if y < P.PORTA_H:
        for (px, pz, l) in MOB._portas():
            if abs(x - px) < l * 0.5 and abs(z - pz) < 0.4:
                return True
    return False


def _emitir_decalques(c, quads):
    c.no("detalhes", tipo="Node3D", pai=".")
    c.no("decalques", tipo="Node3D", pai="detalhes")
    mats, malhas = {}, {}
    quads = [q for q in quads if not _decalque_sem_parede(q)]
    for (i, q) in enumerate(quads):
        tom = round(q["tom"] * 5.0) / 5.0
        chave = (q["atlas"], q["cel"], q["tipo"], tom)
        if chave not in mats:
            mats[chave] = "dec_mat_%d" % len(mats)
            _material_decalque(c, mats[chave], q, tom)
        w, h = round(q["largura"], 2), round(q["altura"], 2)
        mchave = (mats[chave], w, h)
        if mchave not in malhas:
            malhas[mchave] = "dec_malha_%d" % len(malhas)
            c.recurso(malhas[mchave], "QuadMesh", [
                'material = SubResource("%s")' % mats[chave],
                "size = Vector2(%.2f, %.2f)" % (w, h)])
        c.no("d%d" % i, tipo="MeshInstance3D", pai="detalhes/decalques",
             props=[("transform", _xform_decalque(q)),
                    ("mesh", 'SubResource("%s")' % malhas[mchave]),
                    ("cast_shadow", "0"),
                    ("visibility_range_end", "%.1f" % (ALCANCE_CHAO if q["plano"] == "chao"
                                                       else ALCANCE_PAREDE))])
    print("  decalques: %d quads, %d materiais, %d malhas"
          % (len(quads), len(mats), len(malhas)))


def _emitir_textos(c, textos):
    """Cada texto e' um Label3D com a CHAVE do CSV no `text`: o Godot traduz
    sozinho (e retraduz quando o idioma muda no menu)."""
    c.no("textos", tipo="Node3D", pai="detalhes")
    for (i, t) in enumerate(textos):
        fonte = c.externo("FontFile", DET.FONTES[t["fonte"]])
        props_ = [
            ("transform", C.transform_geral(t["pos"], t["giro"], 0.0, t["inclinacao"])),
            ("cast_shadow", "0"),
            ("visibility_range_end", "%.1f" % ALCANCE_PAREDE),
            ("pixel_size", "%.5f" % t["px"]),
            # aceso (a SAIDA) nao recebe luz: ele E' a luz. O resto recebe, e
            # e' isso que deixa a lousa invisivel ate' a lanterna passar nela.
            ("shaded", "false" if t["aceso"] else "true"),
            ("double_sided", "false"),
            ("modulate", C.cor(t["cor"])),
            ("render_priority", "2"),
            ("outline_render_priority", "1"),
            ("outline_size", "0"),
            ("text", '"%s"' % t["chave"]),
            ("font", 'ExtResource("%s")' % fonte),
            ("font_size", "%d" % t["tamanho"]),
        ]
        c.no("t%d" % i, tipo="Label3D", pai="detalhes/textos", props=props_)
    print("  textos: %d Label3D" % len(textos))


def _emitir_bolas(c, bolas):
    """Bolinha de papel amassado: esfera de poucos lados, e e' justamente o
    poligono grosseiro que a faz parecer papel amassado e nao bola de gude."""
    c.recurso("bola_mat", "StandardMaterial3D", [
        "albedo_color = Color(0.70, 0.68, 0.60, 1)", "roughness = 0.95"])
    c.recurso("bola_malha", "SphereMesh", [
        'material = SubResource("bola_mat")', "radius = 0.036", "height = 0.066",
        "radial_segments = 6", "rings = 3"])
    c.no("bolinhas", tipo="Node3D", pai="detalhes")
    for (i, b) in enumerate(bolas):
        c.no("b%d" % i, tipo="MeshInstance3D", pai="detalhes/bolinhas",
             props=[("transform", C.transform_geral(b["pos"], b["giro"], 0.4, 0.2,
                                                    b["escala"])),
                    ("mesh", 'SubResource("bola_malha")'),
                    ("cast_shadow", "0"),
                    ("visibility_range_end", "%.1f" % (ALCANCE_CHAO - 6.0))])


def _emitir_ventiladores(c, ventiladores):
    """Ventilador de teto. Os que giram levam `velocidade` > 0 (voltas por
    segundo) e quem os gira e' o `escola.gd`, pelo grupo."""
    id_vent = c.externo("PackedScene", MOB.caminho("ceiling_fan"))
    c.no("ventiladores", tipo="Node3D", pai="detalhes")
    for (i, v) in enumerate(ventiladores):
        c.no("ventilador_%d" % i, pai="detalhes/ventiladores", instancia=id_vent,
             grupos=["ventilador"],
             props=[("transform", C.transform_pos(v["pos"], v["giro"]))],
             metas=[("velocidade", "%.2f" % v["velocidade"])])


def _linha_multimesh(ex, ey, ez, pos):
    """As 12 floats de uma instancia num buffer de MultiMesh 3D: as LINHAS da
    matriz 3x4 (a mesma convencao por linhas do Transform3D do .tscn)."""
    return [ex[0], ey[0], ez[0], pos[0],
            ex[1], ey[1], ez[1], pos[1],
            ex[2], ey[2], ez[2], pos[2]]


def _multimesh(c, ident, malha, linhas):
    buf = []
    for l_ in linhas:
        buf.extend(l_)
    c.recurso(ident, "MultiMesh", [
        "transform_format = 1",
        "instance_count = %d" % len(linhas),
        'mesh = SubResource("%s")' % malha,
        "buffer = PackedFloat32Array(%s)" % ", ".join("%.4f" % v for v in buf)])


def _emitir_bandeirinhas(c, bandeiras, cordoes):
    """As bandeirinhas e o barbante, em MultiMesh: sao ~220 bandeiras e ~270
    trechos de barbante, e um no' por peca seriam quinhentas chamadas de
    desenho pra uma decoracao que se ve' de longe."""
    if not bandeiras:
        return
    c.no("bandeirinhas", tipo="Node3D", pai="detalhes")
    tex = c.externo("Texture2D", TEX.caminho_res("bandeiras"))
    for (k, cor) in enumerate(TEX.BANDEIRAS):
        u0, v0, du, dv = TEX.recorte("bandeiras", cor)
        c.recurso("band_mat_%d" % k, "StandardMaterial3D", [
            "transparency = 2", "alpha_scissor_threshold = 0.5", "cull_mode = 2",
            'albedo_texture = ExtResource("%s")' % tex,
            "albedo_color = Color(1, 1, 1, 1)", "roughness = 0.9",
            "texture_repeat = false",
            "uv1_scale = Vector3(%.5f, %.5f, 1)" % (du, dv),
            "uv1_offset = Vector3(%.5f, %.5f, 0)" % (u0, v0)])
        c.recurso("band_malha_%d" % k, "QuadMesh", [
            'material = SubResource("band_mat_%d")' % k,
            "size = Vector2(%.2f, %.2f)" % (DET.BANDEIRA_L, DET.BANDEIRA_H)])
        linhas = [_linha_multimesh(ex, ey, ez, pos)
                  for (pos, ex, ey, ez, ci) in bandeiras if ci == k]
        if not linhas:
            continue
        _multimesh(c, "band_mm_%d" % k, "band_malha_%d" % k, linhas)
        c.no("cor_%d" % k, tipo="MultiMeshInstance3D", pai="detalhes/bandeirinhas",
             props=[("multimesh", 'SubResource("band_mm_%d")' % k), ("cast_shadow", "0")])
    c.recurso("barbante_mat", "StandardMaterial3D", [
        "albedo_color = Color(0.36, 0.34, 0.29, 1)", "roughness = 0.95"])
    c.recurso("barbante_malha", "BoxMesh", [
        'material = SubResource("barbante_mat")', "size = Vector3(1, 0.012, 0.012)"])
    linhas = []
    for (centro, v) in cordoes:
        comp = math.sqrt(sum(x * x for x in v)) or 1.0
        xn = tuple(x / comp for x in v)
        z = DET._cruz(xn, (0.0, 1.0, 0.0))
        if math.sqrt(sum(x * x for x in z)) < 1e-3:
            z = (0.0, 0.0, 1.0)
        z = DET._norm(z)
        y = DET._cruz(z, xn)
        linhas.append(_linha_multimesh(v, y, z, centro))
    _multimesh(c, "barbante_mm", "barbante_malha", linhas)
    c.no("barbante", tipo="MultiMeshInstance3D", pai="detalhes/bandeirinhas",
         props=[("multimesh", 'SubResource("barbante_mm")'), ("cast_shadow", "0")])


# --------------------------------------------------------------------------
# luar pelas janelas, em geometria
# --------------------------------------------------------------------------

FEIXE_COMPRIMENTO = 4.6
FEIXE_FORCA = 0.030
FEIXE_FORCA_QUEBRADA = 0.042


def _feixes():
    """[(centro, eixo_x, eixo_y, eixo_z, quebrada)] — um prisma por janela.

    So' janela de fora pra dentro de comodo COBERTO: no patio nao ha' o que
    recortar a luz (ele ja' esta' no ceu).
    """
    saida = []
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        for v in m["vaos"]:
            if v["tipo"] != "janela":
                continue
            lado = None
            for l_ in (1.0, -1.0):
                if m["eixo"] == "x":
                    e = P.espaco_em(v["c"], m["coord"] + l_ * 0.8)
                else:
                    e = P.espaco_em(m["coord"] + l_ * 0.8, v["c"])
                if e is not None:
                    lado = l_ if not e.get("descoberto") else None
                    break
            if lado is None:
                continue
            if m["eixo"] == "x":
                n, t = (0.0, lado), (1.0, 0.0)
                base = (v["c"], 0.0, m["coord"])
            else:
                n, t = (lado, 0.0), (0.0, 1.0)
                base = (m["coord"], 0.0, v["c"])
            d = (n[0] + t[0] * 0.20, -0.62, n[1] + t[1] * 0.20)
            norma = math.sqrt(sum(k * k for k in d))
            d = tuple(k / norma for k in d)
            h = v["y1"] - v["y0"] - 0.10
            larg = v["l"] - 0.12
            cy = P.cota() + (v["y0"] + v["y1"]) * 0.5
            L_ = FEIXE_COMPRIMENTO
            centro = (base[0] + d[0] * L_ * 0.5, cy + d[1] * L_ * 0.5,
                      base[2] + d[2] * L_ * 0.5)
            saida.append((centro, (t[0] * larg, 0.0, t[1] * larg), (0.0, h, 0.0),
                          (d[0] * L_, d[1] * L_, d[2] * L_), v.get("quebrada", False)))
    return saida


def _emitir_feixes(c):
    id_sh = c.externo("Shader", "res://shaders/environment/feixe_janela.gdshader")
    for (ident, forca) in (("feixe_mat", FEIXE_FORCA),
                           ("feixe_mat_quebrada", FEIXE_FORCA_QUEBRADA)):
        c.recurso(ident, "ShaderMaterial", [
            'shader = ExtResource("%s")' % id_sh,
            "shader_parameter/cor = Color(%.3f, %.3f, %.3f, 1)" % L.LUAR[:3],
            "shader_parameter/forca = %.4f" % forca])
    c.recurso("feixe_caixa", "BoxMesh", ["size = Vector3(1, 1, 1)"])
    c.no("feixes", tipo="Node3D", pai="detalhes")
    lista = _feixes()
    for (i, (centro, ex, ey, ez, quebrada)) in enumerate(lista):
        c.no("feixe_%d" % i, tipo="MeshInstance3D", pai="detalhes/feixes",
             props=[("transform", C._matriz(ex, ey, ez, centro)),
                    ("mesh", 'SubResource("feixe_caixa")'),
                    ("material_override", 'SubResource("%s")'
                     % ("feixe_mat_quebrada" if quebrada else "feixe_mat")),
                    ("cast_shadow", "0"),
                    ("visibility_range_end", "30.0")])
    print("  %d feixes de luar" % len(lista))


# --------------------------------------------------------------------------
# som
# --------------------------------------------------------------------------

SONS = {
    "zumbido": "res://assets/sounds/escola/zumbido_eletrico.ogg",
    "goteira": "res://assets/sounds/escola/goteira_porao.ogg",
    "vento": "res://assets/sounds/escola/vento_janela.ogg",
    "fantasma": "res://assets/sounds/escola/atmosfera_fantasma.ogg",
    "chuva": "res://assets/sounds/episodios/prologo/chuva.mp3",
    "relogio": "res://assets/sounds/episodios/capitulo_1/intro/relogio.mp3",
}
# Quantas fluorescentes zumbem. Todo AudioStreamPlayer3D tocando custa
# mixagem, mesmo longe; vinte fontes curtas cobrem os corredores.
MAX_ZUMBIDOS = 20


def _som3d(c, nome, tipo, pos, volume, alcance, unidade=2.0, laco=False):
    c.no(nome, tipo="AudioStreamPlayer3D", pai="detalhes/sons",
         grupos=["som_em_laco"] if laco else None,
         props=[("transform", C.transform_pos(pos)),
                ("stream", 'ExtResource("%s")' % c.externo("AudioStream", SONS[tipo])),
                ("volume_db", "%.1f" % volume),
                ("unit_size", "%.1f" % unidade),
                ("max_distance", "%.1f" % alcance),
                ("max_polyphony", "1"),
                ("autoplay", "true")])


def _emitir_sons(c, sons, luzes):
    """Zumbido nas fluorescentes que piscam (o `escola.gd` liga o volume ao
    piscar), goteira onde ha' poca, vento nas janelas quebradas, a chuva do
    patio e o relogio que ainda anda."""
    c.no("sons", tipo="Node3D", pai="detalhes")
    n = 0
    for luz in luzes:
        if n >= MAX_ZUMBIDOS:
            break
        if luz["tipo"] != "SpotLight3D" or luz["piscar"] is None \
                or luz["nome"].startswith("refletor"):
            continue
        _som3d(c, "som_" + luz["nome"], "zumbido", luz["pos"], -20.0, 9.0, 1.5)
        n += 1
    for (i, s_) in enumerate(sons):
        _som3d(c, "goteira_%d" % i, "goteira", s_["pos"], -12.0, 11.0, 2.5)
    k = 0
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        for v in m["vaos"]:
            if v["tipo"] != "janela" or not v.get("quebrada") or k % 2:
                k += 1
                continue
            k += 1
            if m["eixo"] == "x":
                pos = (v["c"], P.cota() + 2.0, m["coord"])
            else:
                pos = (m["coord"], P.cota() + 2.0, v["c"])
            _som3d(c, "vento_%d" % k, "vento", pos, -16.0, 12.0, 2.0)
    patio = P.por_ident("patio")
    px, pz = P.centro(patio)
    _som3d(c, "chuva", "chuva", (px, P.cota() + 3.0, pz), -6.0, 46.0, 14.0, laco=True)
    sala = P.por_ident("sala_102")
    _som3d(c, "relogio", "relogio", (sala["x0"] + 0.3, P.cota() + 2.6,
                                     sala["z0"] + (sala["z1"] - sala["z0"]) * 0.14),
           -14.0, 7.0, 1.0, laco=True)
    c.no("atmosfera", tipo="AudioStreamPlayer", pai="detalhes/sons",
         props=[("stream", 'ExtResource("%s")' % c.externo("AudioStream", SONS["fantasma"])),
                ("volume_db", "-22.0"), ("autoplay", "true")])


# --------------------------------------------------------------------------
# a lente
# --------------------------------------------------------------------------

def _emitir_lente(c, valores=None):
    """O acabamento de camera (`shaders/post_process/escola_lente.gdshader`).

    CanvasLayer -1: pega so' o 3D. O HUD (minimapa, layer 100), o fade e a
    pausa ficam por cima dele, intocados.
    """
    id_sh = c.externo("Shader", "res://shaders/post_process/escola_lente.gdshader")
    c.recurso("lente_mat", "ShaderMaterial", ['shader = ExtResource("%s")' % id_sh]
              + ["shader_parameter/%s = %s" % kv for kv in (valores or LENTE)])
    c.no("lente", tipo="CanvasLayer", pai=".", props=[("layer", "-1")])
    c.no("tela", tipo="ColorRect", pai="lente",
         props=[("material", 'SubResource("lente_mat")'),
                ("anchors_preset", "15"), ("anchor_right", "1.0"),
                ("anchor_bottom", "1.0"), ("grow_horizontal", "2"),
                ("grow_vertical", "2"), ("mouse_filter", "2")])


# Os numeros da lente DESTA cena (o porao usa outros, mais fechados).
LENTE = [
    ("barril", "0.0"),
    ("aberracao", "1.4"),
    ("exposicao", "1.0"),
    ("gama", "0.70"),
    ("piso_preto", "Color(0.02, 0.026, 0.028, 1)"),
    ("contraste", "1.05"),
    ("saturacao", "0.78"),
    ("forca_tom", "0.42"),
    ("grao", "0.065"),
    ("vinheta", "0.70"),
    ("respiracao", "0.035"),
    ("interferencia", "0.35"),
]


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


def _encostos():
    """{no: (dx, dy, dz)}: o quanto encostar cada peca que sairia flutuando.

    Sai de `red-valve/tools/flutuantes/achar.gd` rodado na cena gerada (raios
    curtos nas 6 faces de cada malha): quadro a 4 cm da parede, luminaria a
    7 cm do forro, poste de refletor 20 cm acima do chao. A tabela fica em
    `encostos.json` ao lado deste arquivo, por nome de no' — regerar a escola
    reaplica.
    """
    caminho = os.path.join(os.path.dirname(os.path.abspath(__file__)), "encostos.json")
    if not os.path.exists(caminho):
        return {}
    with open(caminho) as f:
        return {k: tuple(v) for k, v in json.load(f).items()}


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
        # COR, e nao ceu (3 = ceu). Com a fonte no ceu o ambiente vinha do
        # ceu noturno quase preto e a `energy` abaixo nao chegava em lugar
        # nenhum: a cena saia preta como breu, com 1,75 ou 3,0. Medido com o
        # harness `tools/escola/fotos.tscn`.
        "ambient_light_source = 2",
        "ambient_light_color = Color(0.17, 0.20, 0.23, 1)",
        # O PISO DO ESCURO desta cena. Ele define o quao preto fica um comodo
        # sem lampada nenhuma. Alto para uma cena de terror, e de proposito:
        # quem faz o medo aqui sao as lampadas piscando, nao a ausencia de
        # imagem — o trecho entre duas luminarias precisa mostrar a FORMA das
        # coisas sem mostrar o detalhe delas. (No porao este numero e' quatro
        # vezes menor: la' o escuro E' o assunto.)
        "ambient_light_energy = 1.5",
        "reflected_light_source = 2",
        "tonemap_mode = 3",
        # 1,6 e nao 1,0: a escola tem de chegar a lente com as sombras FORA do
        # primeiro degrau de 32 do filtro PS1 do jogador (ver
        # `escola_lente.gdshader`, `gama`). Medido no harness: com 1,0 a
        # mediana da imagem era 9/255 — o primeiro degrau — em qualquer vista.
        "tonemap_exposure = 1.6",
        "tonemap_white = 7.5",
        "glow_enabled = true",
        "glow_intensity = 0.42",
        "glow_strength = 1.05",
        "glow_bloom = 0.15",
        "glow_blend_mode = 1",
        "glow_hdr_threshold = 1.10",
        "fog_enabled = true",
        "fog_mode = 0",
        # Nevoa ESCURA: o fundo do corredor some no preto, e nao num cinza
        # azulado. E' o que faz a poca de luz da proxima luminaria ser a unica
        # coisa la' no fim.
        "fog_light_color = Color(0.035, 0.042, 0.05, 1)",
        "fog_light_energy = 1.0",
        "fog_density = 0.03",
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
    id_sh = c.externo("Shader", "res://shaders/environment/cone_luz.gdshader")
    for (raio, alcance, cor_) in familias:
        ident_mat = "cone_mat_%d" % len(feito)
        ident_malha = "cone_malha_%d" % len(feito)
        altura = min(alcance, P.PE - 0.30)
        # Shader proprio (`cone_luz.gdshader`), e nao StandardMaterial: o
        # material chapado desenhava um triangulo de borda dura, e a curva de
        # sombra da lente o transformava numa cunha cinza solida no meio do
        # corredor.
        c.recurso(ident_mat, "ShaderMaterial", [
            'shader = ExtResource("%s")' % id_sh,
            "shader_parameter/cor = Color(%.3f, %.3f, %.3f, 1)" % cor_,
            "shader_parameter/forca = 0.030",
            "shader_parameter/altura = %.3f" % altura,
        ])
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
