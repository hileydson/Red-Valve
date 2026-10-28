"""Monta a escola POR FORA: a casca que entra na cidade.

    python3 tools/godot/escola/gerar_cena_exterior.py

Sai:
    red-valve/assets/3d_model/stages/escola/escola_exterior.gltf (+ .bin)
    red-valve/scenes/stages/escola/escola_exterior.tscn
    red-valve/assets/3d_model/stages/escola/escola_mapa.json

A cena resultante e' uma instancia so': da' pra arrastar, girar e subir/descer
pelo editor sem quebrar nada. Quem consome ela e' a `stage_1`, que a encaixa em
cima do `Marker3D` chamado `escola_local`.

O que e' fachada mora em `exterior.py` (medidas, estado das janelas, o
letreiro). Aqui fica so' a emissao: caixa, colisao, luz e o texto do .tscn.

Regenerar SOBRESCREVE o .tscn — mexer no predio pelo editor se perde, igual ao
interior. O que NAO se perde e' a posicao: ela mora na `stage_1`, nao aqui.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comum as C
import exterior as E
import gltf
import materiais as M
import planta as P

SAIDA_CENA = os.path.join(C.BASE, "scenes", "stages", "escola",
                          "escola_exterior.tscn")
SAIDA_MAPA = os.path.join(C.DIR_MODELO, "escola_mapa.json")

SETOR = 16.0


class Fachada(C.Setores):
    """O mesmo fatiador do interior, com nome de objeto proprio.

    Fatiar importa aqui pelo mesmo motivo de la' dentro: uma fachada de 76 m
    numa malha so' entra INTEIRA no alcance de qualquer poste da cidade, e o
    renderer mobile descarta luz calado depois da oitava.
    """

    def _objeto(self, i, j):
        if (i, j) not in self.objetos:
            self.objetos[(i, j)] = self.cena.objeto("ext_%02d_%02d" % (i, j))
        return self.objetos[(i, j)]


# ==========================================================================
# A CASCA
# ==========================================================================

def _buracos_da_fachada(lado):
    """Todos os vaos daquele lado, como (a, b, y0, y1) — pra `E.pedacos`."""
    saida = []
    for (l, _plano, a, b, y0, y1, _q) in E.janelas():
        if l == lado:
            saida.append((a, b, y0, y1))
    for (l, _plano, a, b, y0, y1) in E.buracos():
        if l == lado:
            saida.append((a, b, y0, y1))
    if lado == "o":
        saida.append((E.PORTAO_Z0, E.PORTAO_Z1, E.CHAO, E.PORTAO_TOPO))
    return saida


def _corrida(lado):
    return (E.Z0, E.Z1) if lado in ("o", "l") else (E.X0, E.X1)


def emitir_casca(fac):
    colisoes = []
    for lado in ("n", "s", "o", "l"):
        plano = {"n": E.Z0, "s": E.Z1, "o": E.X0, "l": E.X1}[lado]
        a, b = _corrida(lado)
        buracos = _buracos_da_fachada(lado)
        # embasamento, pano, cinta e platibanda
        E.faixa(fac, lado, plano, a, b, E.Y_BASE[0], E.Y_BASE[1],
                "fac_embasamento", buracos, avanco=E.AVANCO_BASE, uv=2.4)
        E.faixa(fac, lado, plano, a, b, E.Y_CORPO[0], E.Y_CORPO[1],
                "fac_reboco_sujo" if lado in ("s", "l") else "fac_reboco",
                buracos, uv=3.0)
        E.faixa(fac, lado, plano, a, b, E.Y_COROA[0], E.Y_COROA[1],
                "fac_concreto", (), avanco=E.AVANCO_CINTA, uv=2.6)
        E.faixa(fac, lado, plano, a, b, E.Y_PLATIBANDA[0], E.Y_PLATIBANDA[1],
                "fac_reboco", (), uv=3.0)
        # colisao: um bloco so' por fachada, do chao ao alto da platibanda.
        # Mais fino que a casca de proposito — o jogador nunca encosta nos
        # 45 cm de dentro, e uma caixa por pedaco seriam 300 formas.
        if lado in ("o", "l"):
            d = E.DENTRO[lado]
            colisoes.append((min(plano, plano + d * E.ESP),
                             max(plano, plano + d * E.ESP),
                             E.CALCADA_Y[0], E.Y_PLATIBANDA[1], a, b))
        else:
            d = E.DENTRO[lado]
            colisoes.append((a, b, E.CALCADA_Y[0], E.Y_PLATIBANDA[1],
                             min(plano, plano + d * E.ESP),
                             max(plano, plano + d * E.ESP)))
    return colisoes


def emitir_janelas(fac):
    """Vidro, esquadria, peitoril — e o PAINEL PRETO atras de cada um.

    O painel e' o que segura a ilusao: a casca e' oca, e sem ele da' pra ver o
    vazio do predio pelo proprio buraco da janela.
    """
    contagem = {}
    for (i, (lado, plano, a, b, y0, y1, quebrada)) in enumerate(E.janelas()):
        estado = "quebrada" if quebrada else \
            E.ESTADO_JANELA[i % len(E.ESTADO_JANELA)]
        contagem[estado] = contagem.get(estado, 0) + 1
        d = E.DENTRO[lado]
        if estado == "tapada":
            # tapume de tabua pregado por fora
            E.caixa_fachada(fac, lado, plano, a, b, y0, y1, "fac_tabua",
                            esp=0.06, avanco=0.05, uv=1.2)
            E.caixa_fachada(fac, lado, plano, a, b, y0, y1, "fac_escuro",
                            esp=E.ESP, uv=1.0)
        else:
            mat = {"acesa": "fac_vidro_aceso",
                   "quebrada": "fac_vidro_quebrado"}.get(estado, "fac_vidro")
            E.caixa_fachada(fac, lado, plano, a, b, y0 + 0.05, y1 - 0.05, mat,
                            esp=0.05, avanco=-0.04, uv=1.4)
            # o fundo preto, 12 cm atras do vidro
            E.caixa_fachada(fac, lado, plano, a, b, y0, y1, "fac_escuro",
                            esp=E.ESP - 0.12, avanco=-0.12, uv=1.0)
        # caixilho
        for (ca, cb) in ((a, a + 0.07), (b - 0.07, b)):
            E.caixa_fachada(fac, lado, plano, ca, cb, y0, y1, "fac_esquadria",
                            esp=0.10, avanco=0.04, uv=1.0)
        for (cy0, cy1) in ((y0, y0 + 0.07), (y1 - 0.07, y1)):
            E.caixa_fachada(fac, lado, plano, a, b, cy0, cy1, "fac_esquadria",
                            esp=0.10, avanco=0.04, uv=1.0)
        # peitoril, saliente
        E.caixa_fachada(fac, lado, plano, a - 0.10, b + 0.10, y0 - 0.08, y0,
                        "fac_concreto", esp=0.12, avanco=0.16, uv=1.0)
        _ = d
    return contagem


def emitir_buracos(fac):
    """Os dois rombos vistos da rua: um vao escuro com entulho na boca."""
    for (lado, plano, a, b, y0, y1) in E.buracos():
        E.caixa_fachada(fac, lado, plano, a, b, y0, y1, "fac_escuro",
                        esp=E.ESP + 0.60, uv=1.0)
        # a borda de tijolo arrebentado em volta
        for (ca, cb) in ((a - 0.25, a), (b, b + 0.25)):
            E.caixa_fachada(fac, lado, plano, ca, cb, y0, y1 + 0.20,
                            "fac_tijolo", esp=0.30, avanco=0.06, uv=1.2)
        E.caixa_fachada(fac, lado, plano, a - 0.25, b + 0.25, y1, y1 + 0.20,
                        "fac_tijolo", esp=0.30, avanco=0.06, uv=1.2)
        # a terra revirada no chao, saindo do rombo
        d = E.DENTRO[lado]
        fora = plano - d * 1.8
        lo, hi = sorted((plano, fora))
        if lado in ("o", "l"):
            fac.caixa("fac_terra", lo, hi, E.CHAO - 0.10, E.CHAO + 0.28,
                      a - 0.6, b + 0.6, 2.0)
        else:
            fac.caixa("fac_terra", a - 0.6, b + 0.6, E.CHAO - 0.10,
                      E.CHAO + 0.28, lo, hi, 2.0)


def emitir_portao(fac):
    """O portao de chapa e o portal de concreto em volta dele.

    A chapa e' CEGA, e nao vazada: portao de grade ali mostraria que o patio do
    outro lado nao existe nesta casca.
    """
    colisoes = []
    # as duas ombreiras e a verga do portal
    for (za, zb) in ((E.PORTAO_Z0, E.FOLHA_Z0), (E.FOLHA_Z1, E.PORTAO_Z1)):
        fac.caixa("fac_concreto", E.X0 - 0.30, E.X0 + E.ESP, E.CHAO,
                  E.PORTAO_TOPO, za, zb, 2.4)
        colisoes.append((E.X0 - 0.30, E.X0 + E.ESP, E.CALCADA_Y[0],
                         E.PORTAO_TOPO, za, zb))
    fac.caixa("fac_concreto", E.X0 - 0.30, E.X0 + E.ESP, E.FOLHA_TOPO,
              E.PORTAO_TOPO, E.FOLHA_Z0, E.FOLHA_Z1, 2.4)
    colisoes.append((E.X0 - 0.30, E.X0 + E.ESP, E.FOLHA_TOPO, E.PORTAO_TOPO,
                     E.FOLHA_Z0, E.FOLHA_Z1))
    # a folha: duas chapas
    for (za, zb) in ((E.FOLHA_Z0, E.PORTAO_Z), (E.PORTAO_Z, E.FOLHA_Z1)):
        fac.caixa("fac_metal", E.X0 - 0.04, E.X0 + 0.06, E.CHAO + 0.04,
                  E.FOLHA_TOPO, za + 0.03, zb - 0.03, 1.6)
    colisoes.append((E.X0 - 0.10, E.X0 + 0.10, E.CALCADA_Y[0], E.FOLHA_TOPO,
                     E.FOLHA_Z0, E.FOLHA_Z1))
    return colisoes


def emitir_letreiro(fac):
    """A palavra ESCOLA em bloco, na platibanda acima do portao."""
    largura = (len(E.PALAVRA) * E.LETRA_L
               + (len(E.PALAVRA) - 1) * E.LETRA_VAO)
    z = E.PORTAO_Z - largura * 0.5
    for (i, ch) in enumerate(E.PALAVRA):
        mat = "fac_letra_morta" if i in E.LETRAS_MORTAS else "fac_letra_acesa"
        base = z + i * (E.LETRA_L + E.LETRA_VAO)
        for (rx0, rx1, ry0, ry1) in E.TRACOS.get(ch, []):
            fac.caixa(mat, E.X0 - 0.22, E.X0 - 0.10,
                      E.LETRA_Y + ry0 * E.LETRA_H,
                      E.LETRA_Y + ry1 * E.LETRA_H,
                      base + rx0 * E.LETRA_L, base + rx1 * E.LETRA_L, 1.0)


def emitir_telhado(fac):
    """Laje sobre a PARTE CONSTRUIDA. O patio fica descoberto.

    Sao quatro faixas em volta do vazio central, e nao uma laje inteira: com a
    laje fechada o jogador que olhasse por cima do muro veria um bloco macico
    onde a planta do menu mostra uma quadra.
    """
    colisoes = []
    pa = E.PATIO
    for (x0, x1, z0, z1) in (
            (E.X0, E.X1, E.Z0, pa["z0"] - P.PAREDE),
            (E.X0, E.X1, pa["z1"] + P.PAREDE, E.Z1),
            (E.X0, pa["x0"] - P.PAREDE, pa["z0"] - P.PAREDE,
             pa["z1"] + P.PAREDE),
            (pa["x1"] + P.PAREDE, E.X1, pa["z0"] - P.PAREDE,
             pa["z1"] + P.PAREDE)):
        if x1 - x0 < 0.2 or z1 - z0 < 0.2:
            continue
        fac.caixa("fac_laje", x0, x1, E.Y_TELHADO[0], E.Y_TELHADO[1],
                  z0, z1, 3.4)
        colisoes.append((x0, x1, E.Y_TELHADO[0], E.Y_TELHADO[1], z0, z1))
    return colisoes


def emitir_patio(fac):
    """O chao do patio, visto por cima do muro: cimento e a mancha da quadra.

    Uma duzia de caixas pra a casca nao mentir sobre o que tem la' dentro.
    """
    pa = E.PATIO
    fac.caixa("fac_calcada", pa["x0"], pa["x1"], E.CHAO - 0.20, 0.0,
              pa["z0"], pa["z1"], 3.6)
    qx0, qz0, qx1, qz1 = E.QUADRA
    fac.caixa("fac_quadra", qx0 - 1.0, qx1 + 1.0, 0.0, 0.03,
              qz0 - 1.0, qz1 + 1.0, 4.5)
    e = 0.10
    for (ax0, az0, ax1, az1) in ((qx0, qz0, qx1, qz0 + e),
                                 (qx0, qz1 - e, qx1, qz1),
                                 (qx0, qz0, qx0 + e, qz1),
                                 (qx1 - e, qz0, qx1, qz1),
                                 ((qx0 + qx1) * 0.5 - e * 0.5, qz0,
                                  (qx0 + qx1) * 0.5 + e * 0.5, qz1)):
        fac.caixa("fac_linha", ax0, ax1, 0.03, 0.045, az0, az1, 1.0)


def emitir_calcada(fac):
    colisoes = []
    faixas = [
        (E.X0 - E.CALCADA_L, E.X1 + E.CALCADA_L, E.Z0 - E.CALCADA_L, E.Z0),
        (E.X0 - E.CALCADA_L, E.X1 + E.CALCADA_L, E.Z1, E.Z1 + E.CALCADA_L),
        (E.X0 - E.CALCADA_L, E.X0, E.Z0, E.Z1),
        (E.X1, E.X1 + E.CALCADA_L, E.Z0, E.Z1),
        (E.RECUO_PORTAO[0], E.RECUO_PORTAO[1], E.RECUO_PORTAO[2],
         E.RECUO_PORTAO[3]),
    ]
    for (x0, x1, z0, z1) in faixas:
        fac.caixa("fac_calcada", x0, x1, E.CALCADA_Y[0], E.CALCADA_Y[1],
                  z0, z1, 3.0)
        colisoes.append((x0, x1, E.CALCADA_Y[0], E.CALCADA_Y[1], z0, z1))
    return colisoes


def montar():
    cena = gltf.Cena("../../../images/textures/polyhaven")
    M.registrar(cena, [M.EXTERIOR])
    fac = Fachada(cena, SETOR)
    colisoes = []
    colisoes += emitir_casca(fac)
    contagem = emitir_janelas(fac)
    emitir_buracos(fac)
    colisoes += emitir_portao(fac)
    emitir_letreiro(fac)
    colisoes += emitir_telhado(fac)
    emitir_patio(fac)
    colisoes += emitir_calcada(fac)
    return cena, colisoes, contagem


# ==========================================================================
# LUZ
#
# Tres, e nem uma a mais. Fachada e' lugar de luz emissiva (janela acesa, letra
# acesa), nao de luz de verdade: o predio divide o orcamento de 8 por malha com
# os postes da cidade, e quem perde a disputa some sem avisar.
# ==========================================================================

LUZES = [
    ("portao", (-2.60, 3.60, E.PORTAO_Z), (0.68, 0.72, 0.62), 2.6, 10.0),
    ("letreiro", (-1.60, E.LETRA_Y + E.LETRA_H * 0.5, E.PORTAO_Z),
     (0.52, 0.72, 0.56), 2.8, 12.0),
    ("patio", (24.0, 6.0, 30.0), (0.56, 0.64, 0.78), 1.8, 18.0),
]


# ==========================================================================
# O .tscn
# ==========================================================================

def escrever_cena(colisoes):
    dx, dy, dz = -E.ORIGEM[0], -E.ORIGEM[1], -E.ORIGEM[2]
    c = C.Cena()
    id_gltf = c.externo("PackedScene", C.RES_MODELO + "/escola_exterior.gltf")

    c.no("escola_exterior", tipo="Node3D")
    # Tudo o que e' predio vive DENTRO deste no', deslocado. Assim o (0,0,0) da
    # cena e' a calcada diante do portao, e nao o canto do terreno.
    c.no("predio", tipo="Node3D", pai=".",
         props=[("transform", C.transform_pos((dx, dy, dz)))])
    c.no("estrutura", pai="predio", instancia=id_gltf)
    C.emitir_colisoes(c, colisoes, nome="colisao", pai="predio")

    c.no("luzes", tipo="Node3D", pai="predio")
    for (nome, pos, cor_, energia, alcance) in LUZES:
        c.no(nome, tipo="OmniLight3D", pai="predio/luzes", props=[
            ("transform", C.transform_pos(pos)),
            ("light_color", C.cor(list(cor_) + [1.0])),
            ("light_energy", "%.3f" % energia),
            ("light_specular", "0.15"),
            ("shadow_enabled", "false"),
            ("omni_range", "%.3f" % alcance),
            ("omni_attenuation", "1.35"),
        ])

    # O ponto pra onde o jogador volta quando sai da escola: na calcada, dois
    # metros e meio a' frente do portao, ja' de costas pra ele.
    c.no("ponto_de_saida", tipo="Marker3D", pai=".",
         props=[("transform", C.transform_pos((-2.50, 0.15, 0.0),
                                              -math.pi * 0.5))])

    # A area do prompt cobre o recuo do portao inteiro. LARGA (14 m em Z) pelo
    # mesmo motivo que a do hospital teve de crescer: o recuo tem 13 m de
    # frente, e quem chega por uma das pontas chegaria na soleira sem prompt
    # nenhum, como se o portao nao existisse.
    ident = c.forma(9.0, 5.0, 14.0)
    c.no("area_entrada", tipo="Area3D", pai=".",
         props=[("transform", C.transform_pos((-1.0, 1.80, 0.0))),
                ("collision_layer", "0"), ("collision_mask", "1"),
                ("monitorable", "false")])
    c.no("forma", tipo="CollisionShape3D", pai="area_entrada",
         props=[("shape", 'SubResource("%s")' % ident)])

    c.gravar(SAIDA_CENA)
    return len(c.sub)


# ==========================================================================
# A SILHUETA PARA O MAPA DA CIDADE
#
# A escola nao sai do gerador da cidade: e' cena a parte, encaixada a mao na
# `stage_1`. Entao o mapa do menu nao tem como saber que ela existe — a menos
# que alguem conte. E' o que este arquivo faz.
# ==========================================================================

def escrever_mapa():
    """A planta baixa grosseira da escola, pro mapa da cidade desenhar.

    Quem le' e' `tools/blender/citygen/textures/make_minimap.py`. Sai daqui, e
    nao digitado la', porque a fachada e' GERADA: mudar a medida do predio tem
    que mudar o retangulo do mapa junto, senao o mapa passa a mentir sem que
    ninguem perceba.

    Retangulos em coordenadas LOCAIS DA CENA — a origem e' a calcada diante do
    portao —, no formato (x0, z0, x1, z1). Quem os leva pro mundo e' o
    make_minimap, que tira posicao e giro da instancia direto da `stage_1`:
    assim, girar o predio no editor gira a silhueta no mapa junto.
    """
    dx, dz = -E.ORIGEM[0], -E.ORIGEM[2]
    pa = E.PATIO

    def r(x0, z0, x1, z1):
        return [round(x0 + dx, 2), round(z0 + dz, 2),
                round(x1 + dx, 2), round(z1 + dz, 2)]

    dados = {
        "nota": "silhueta da escola para o mapa da cidade; gerado por "
                "tools/godot/escola/gerar_cena_exterior.py",
        "porta": [0.0, 0.0],
        "lote": [
            r(E.X0 - E.CALCADA_L, E.Z0 - E.CALCADA_L,
              E.X1 + E.CALCADA_L, E.Z1 + E.CALCADA_L),
            r(E.RECUO_PORTAO[0], E.RECUO_PORTAO[2], E.RECUO_PORTAO[1],
              E.RECUO_PORTAO[3]),
        ],
        # O PATIO sai a parte do predio de proposito: ele nao e' massa
        # construida, e' um vazio de 45 x 36 m dentro dela. Desenhado junto, a
        # escola vira um bloco macico maior que a igreja — e some justamente o
        # que a torna reconhecivel de cima.
        "patio": [r(pa["x0"], pa["z0"], pa["x1"], pa["z1"])],
        "predio": [r(E.X0, E.Z0, E.X1, E.Z1)],
    }
    with open(SAIDA_MAPA, "w", encoding="utf-8") as f:
        json.dump(dados, f, indent=1)
    return dados


def gerar():
    print("== fachada ==")
    cena, colisoes, contagem = montar()
    os.makedirs(C.DIR_MODELO, exist_ok=True)
    tris = cena.salvar(os.path.join(C.DIR_MODELO, "escola_exterior.gltf"))
    vivos = [o for o in cena.objetos if not o.vazio()]
    print("  %d objetos de setor, %d triangulos" % (len(vivos), tris))
    print("  %d janelas (%s)"
          % (len(E.janelas()),
             ", ".join("%s %d" % (k, v) for (k, v) in sorted(contagem.items()))))
    print("  %d caixas de colisao, %d luzes" % (len(colisoes), len(LUZES)))
    formas = escrever_cena(colisoes)
    print("  %d sub-recursos" % formas)
    print("  gravado: %s" % SAIDA_CENA)
    mapa = escrever_mapa()
    print("  %d retangulos de silhueta pro mapa da cidade"
          % sum(len(mapa[k]) for k in ("lote", "patio", "predio")))
    print("  gravado: %s" % SAIDA_MAPA)
    print("  (o mapa da cidade so' muda depois de rodar"
          " tools/blender/citygen/textures/make_minimap.py)")


if __name__ == "__main__":
    gerar()
