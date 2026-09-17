"""As duas plantas do menu: a da escola e a do porao.

    python3 tools/godot/escola/make_mapa_escola.py     (precisa de Pillow)

Saidas:
    red-valve/assets/3d_model/stages/escola/textures/T_escolamap.png
    red-valve/assets/3d_model/stages/escola/escolamap.json
    red-valve/assets/3d_model/stages/escola/textures/T_poraomap.png
    red-valve/assets/3d_model/stages/escola/poraomap.json

==============================================================================
DUAS PRANCHAS, E NENHUMA TROCA AUTOMATICA

O hospital tem duas plantas porque tem dois andares no MESMO predio, e o
`minimap.gd` troca de uma pra outra pela altura do jogador.

Aqui e' diferente: escola e porao sao duas CENAS. Cada uma instancia o seu
proprio perfil de minimapa (`minimap_escola.tscn` e `minimap_porao.tscn`), e o
mapa certo vem de graca — trocar de cena ja' troca o no' que declara o mapa.
Nao ha' nada de altura pra decidir.

==============================================================================
COMO A PLANTA DA ESCOLA E' DESENHADA

Pelo avesso, o mesmo truque da igreja e do hospital: preenche o retangulo do
predio INTEIRO de massa de parede e depois ESCAVA o vao interno de cada sala e
de cada area. O que sobra sem escavar sao exatamente as paredes — sem desenhar
parede nenhuma, e sem chance de a parede do mapa nao bater com a do jogo.

Por cima vao os vaos de `planta.muros()`: porta em cor quente, janela em cor
fria. E' o desenho da porta que faz a planta virar caminho de relance, em vez
de um monte de caixa fechada.

Tres coisas so' existem neste mapa, e as tres sao a regra de jogo desta fase:

  - o PATIO sai numa cor propria (esverdeada) porque e' o unico espaco
    descoberto, e porque e' onde o jogador nasce;
  - a QUADRA aparece desenhada dentro dele, que e' o que faz o patio ser
    reconhecivel como patio e nao como mais um salao;
  - a GRADE e' uma barra VERMELHA atravessando o corredor sul. Sem ela o mapa
    mostraria um corredor continuo que nao existe, e o jogador ficaria dando
    voltas atras de um caminho que o mapa promete e o jogo nao tem.

==============================================================================
AS ZONAS DE DESCOBERTA

O mapa nasce APAGADO e vai acendendo conforme o jogador anda (ver
`scripts/ui/mapa_nevoa.gd`). Quem diz o que acende de uma vez e o que acende
aos poucos e' a lista `zonas` que este script escreve no JSON:

  - "sala": acende INTEIRA quando o jogador entra. Entrou na sala, viu a sala;
  - "gradual": acende so' em volta do jogador, recortado na propria zona. E' o
    caso dos tres corredores e do patio — corredor que aparece inteiro de uma
    vez nao e' corredor descoberto, e' corredor entregue.

Os dois NICHOS dos buracos sao zona "sala" com `gatilho` na sala de dentro:
eles ficam FORA do predio e o jogador nunca pisa neles, mas sao a saida da
fase — entrar no deposito tem de mostrar onde e' o rombo.

==============================================================================
COMO A PLANTA DO PORAO E' DESENHADA

Direto da grade de celulas de `porao.py` — a MESMA que vira geometria. Uma
celula aberta e' um quadradinho claro; o resto e' terra. Nao tem "pelo avesso"
aqui porque nao tem parede a escavar: o tunel ja' E' a lista de celulas.

A camara grande sai um tom mais clara, e o caminho principal ganha um fio no
meio. E' a unica ajuda que este mapa da': num tunel de terra sem rotulo nenhum,
o que o jogador precisa saber e' qual das ramificacoes leva a algum lugar.
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw

_AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _AQUI)

import mobilia as MOB  # noqa: E402
import planta as P  # noqa: E402
import porao as PO  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(_AQUI)))
ASSETS = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages",
                      "escola")
DIR_TEX = os.path.join(ASSETS, "textures")

# 2048: o recorte da escola tem 81 m, o que da' 25 px/m. O painel do menu
# aproxima ate' 26 m de altura numa area de ~740 px — 28 px/m na tela. Fica
# 1,1x de ampliacao, ou seja, nunca borra.
RES = 2048
SS = 2                # supersampling: desenha em 2x e reduz
MARGEM = 2.50         # metros de folga em volta

# Paleta: familia sepia do mapa da cidade, um degrau mais escura — a mesma da
# igreja e do hospital, pra os mapas do jogo parecerem um jogo so'.
C_FORA      = (13, 14, 15)
C_MASSA     = (46, 43, 38)      # a parede, que e' o que sobra sem escavar
C_MASSA_BRD = (19, 18, 16)
C_SALA      = (104,  98,  86)
C_CIRC      = (134, 126, 110)   # corredor
C_PATIO     = (86, 104,  78)    # o unico espaco descoberto: puxa pro verde
C_QUADRA    = (66,  82,  62)
C_QUADRA_LN = (142, 152, 128)
C_PORTA     = (176, 132,  70)
C_JANELA    = ( 92, 120, 126)
C_BURACO    = (168,  96,  48)   # os dois rombos: a unica saida desta fase
C_BURACO_BRD = (58, 30, 16)
C_GRADE     = (176,  54,  44)   # o bloqueio, em vermelho

# porao
C_TERRA     = (34, 27, 20)
C_TUNEL     = (118, 96, 70)
C_CAMARA    = (142, 118, 88)
C_TRILHA    = (176, 150, 112)
C_BOCA      = (196, 132, 62)

# Parede tem 35 cm, o que a 25 px/m da' 9 px: uma janela desenhada na espessura
# exata da parede sumia no contorno. Ela transborda 15 cm pra cada lado.
FOLGA_JANELA = 0.15
BORDA = 0.14           # espessura, em metros, da linha de contorno do volume

# --------------------------------------------------------------------------
# NEVOA (o mapa que acende andando)
#
# `raio_m` aqui e' o raio de quem esta' FORA de qualquer zona — porta, soleira,
# o nicho do buraco. Pequeno de proposito: ali o disco nao tem parede que o
# recorte, e um raio grande vazaria pra dentro de sala que o jogador nao viu.
#
# `margem_m` e' o quanto cada carimbo transborda pra fora da zona, pra a PAREDE
# acender junto com o comodo. Parede tem 0,35: com 0,45 ela acende inteira e
# sobra 0,10 pro comodo vizinho — menos de um pixel da mascara.
# --------------------------------------------------------------------------
NEVOA_RES = 256
NEVOA_RAIO_SOLTO = 5.0
NEVOA_MARGEM = 0.45
# Corredor: generoso de proposito. O recorte na zona segura o vazamento, entao
# um raio grande num corredor so' acende corredor — pra frente e pra tras.
NEVOA_RAIO_CORREDOR = 11.0
NEVOA_RAIO_PATIO = 16.0


# ==========================================================================
# ESCOLA
# ==========================================================================

def _recorte_escola():
    """Quadrado do mundo que a imagem cobre.

    Quadrado, e nao o retangulo justo do predio, porque o MINIMAPA GIRA: com
    escala diferente nos dois eixos a planta apareceria esticada em umas
    direcoes e achatada em outras.

    O recorte inclui os dois nichos dos buracos, que ficam FORA do volume — sem
    isso a unica saida da fase cairia pra fora da folha.
    """
    x0, x1 = P.PREDIO_X0 - 3.6, P.PREDIO_X1
    z0, z1 = P.PREDIO_Z0, P.PREDIO_Z1 + 3.6
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    meio = max(x1 - x0, z1 - z0) / 2.0 + MARGEM
    return cx - meio, cz - meio, meio * 2.0


def build_escola():
    X0, Z0, TAM = _recorte_escola()
    N = RES * SS
    ppm = N / TAM

    def p(x, z):
        return ((x - X0) * ppm, (z - Z0) * ppm)

    def cx(x0, z0, x1, z1):
        return [p(min(x0, x1), min(z0, z1)), p(max(x0, x1), max(z0, z1))]

    img = Image.new("RGB", (N, N), C_FORA)
    dr = ImageDraw.Draw(img)

    # ---- a massa de parede: o predio inteiro, cheio
    dr.rectangle(cx(P.PREDIO_X0, P.PREDIO_Z0, P.PREDIO_X1, P.PREDIO_Z1),
                 fill=C_MASSA)

    # ---- o vazio por dentro, escavado na massa
    for s in P.salas():
        dr.rectangle(cx(s["x0"], s["z0"], s["x1"], s["z1"]), fill=C_SALA)
    for a in P.areas():
        cor = C_PATIO if a["tipo"] == "patio" else C_CIRC
        dr.rectangle(cx(a["x0"], a["z0"], a["x1"], a["z1"]), fill=cor)

    # ---- a quadra, dentro do patio
    qx0, qz0, qx1, qz1 = MOB.QUADRA
    dr.rectangle(cx(qx0, qz0, qx1, qz1), fill=C_QUADRA,
                 outline=C_QUADRA_LN, width=max(1, int(0.22 * ppm)))
    cxx, czz = (qx0 + qx1) * 0.5, (qz0 + qz1) * 0.5
    dr.rectangle(cx(cxx - 0.11, qz0, cxx + 0.11, qz1), fill=C_QUADRA_LN)
    r = 3.0
    dr.ellipse(cx(cxx - r, czz - r, cxx + r, czz + r), outline=C_QUADRA_LN,
               width=max(1, int(0.22 * ppm)))

    # ---- contorno do volume. Fino de proposito: a 0,30 m ele comia a fachada
    # inteira (que tem 0,35) e o predio ficava com a borda preta, sem parede
    # nenhuma — e os dois buracos sumiam junto.
    dr.rectangle(cx(P.PREDIO_X0, P.PREDIO_Z0, P.PREDIO_X1, P.PREDIO_Z1),
                 outline=C_MASSA_BRD, width=max(1, int(BORDA * ppm)))

    # ---- os vaos, POR CIMA do contorno — senao a borda tapava justo as
    # janelas da fachada e os dois buracos, que sao o que o mapa existe pra
    # mostrar.
    for m in P.muros():
        for v in m["vaos"]:
            if v["tipo"] == "buraco":
                continue
            eh_janela = v["tipo"] == "janela"
            dr.rectangle(
                cx(*_caixa_do_vao(m, v, FOLGA_JANELA if eh_janela else 0.0)),
                fill=C_JANELA if eh_janela else C_PORTA)

    # ---- os dois buracos, com o nicho de terra que sai do predio
    for b in (P.BURACO_ENTRADA, P.BURACO_SAIDA):
        _buraco(dr, cx, ppm, b)

    # ---- a GRADE, por ultimo e em vermelho. Ela e' a unica coisa deste mapa
    # que nao e' arquitetura: e' a regra do jogo desenhada.
    dr.rectangle(cx(P.GRADE_X - 0.30, P.GRADE_Z0, P.GRADE_X + 0.30,
                    P.GRADE_Z1), fill=C_GRADE)

    img = img.resize((RES, RES), Image.LANCZOS)
    os.makedirs(DIR_TEX, exist_ok=True)
    png = os.path.join(DIR_TEX, "T_escolamap.png")
    img.save(png)

    meta = {
        "nota": "planta da escola, coberta por T_escolamap.png; gerado por "
                "tools/godot/escola/make_mapa_escola.py",
        "nome": "MAP_NOME_ESCOLA",
        "mundo_x0": round(X0, 2), "mundo_z0": round(Z0, 2),
        "tamanho_m": round(TAM, 2), "resolucao": RES,
        "nevoa": {"resolucao": NEVOA_RES, "raio_m": NEVOA_RAIO_SOLTO,
                  "margem_m": NEVOA_MARGEM},
        "zonas": _zonas_escola(),
        "pontos": _pontos_escola(),
    }
    caminho = os.path.join(ASSETS, "escolamap.json")
    json.dump(meta, open(caminho, "w", encoding="utf-8"), indent=1)
    return meta, png, caminho


def _caixa_do_vao(m, v, folga=0.0):
    """(x0, z0, x1, z1) do recorte que um vao abre na parede."""
    meia = m["esp"] * 0.5 + folga
    a, b = v["c"] - v["l"] * 0.5, v["c"] + v["l"] * 0.5
    if m["eixo"] == "x":
        return (a, m["coord"] - meia, b, m["coord"] + meia)
    return (m["coord"] - meia, a, m["coord"] + meia, b)


def _buraco(dr, cx, ppm, b):
    """O rombo mais o nicho de terra atras dele.

    Desenhado saindo do predio de proposito: e' o que diz, sem texto, que
    aquilo NAO e' uma porta pra rua — e' um caminho que atravessa o terreno.
    """
    dx, dz = {"n": (0.0, -1.0), "s": (0.0, 1.0),
              "o": (-1.0, 0.0), "l": (1.0, 0.0)}[b["lado"]]
    meia = P.BURACO_L * 0.5 + 0.55
    fundo = 3.40
    if dz:
        caixa = (b["x"] - meia, b["z"], b["x"] + meia, b["z"] + dz * fundo)
    else:
        caixa = (b["x"], b["z"] - meia, b["x"] + dx * fundo, b["z"] + meia)
    dr.rectangle(cx(*caixa), fill=C_BURACO, outline=C_BURACO_BRD,
                 width=max(1, int(0.18 * ppm)))


def _zonas_escola():
    """O que acende de uma vez e o que acende aos poucos.

    Sala e' "sala" e area de circulacao e' "gradual" — a divisao ja' existe na
    `planta.py` (`_sala` x `_area`), entao nao ha' lista digitada aqui: sala
    nova na planta ja' nasce com zona.
    """
    zonas = []
    for s in P.salas():
        zonas.append({"id": s["ident"], "tipo": "sala",
                      "x0": s["x0"], "z0": s["z0"],
                      "x1": s["x1"], "z1": s["z1"]})
    for a in P.areas():
        raio = NEVOA_RAIO_PATIO if a["tipo"] == "patio" else NEVOA_RAIO_CORREDOR
        zonas.append({"id": a["ident"], "tipo": "gradual", "raio_m": raio,
                      "x0": a["x0"], "z0": a["z0"],
                      "x1": a["x1"], "z1": a["z1"]})

    # Os dois nichos: ficam FORA do predio, o jogador nunca pisa neles, e sao a
    # unica saida da fase. Zona "sala" com gatilho na sala de dentro — mesmo
    # raciocinio do altar da igreja: nao da' pra andar ate' la', mas chegar
    # perto ja' e' ter visto.
    for b in (P.BURACO_ENTRADA, P.BURACO_SAIDA):
        sala = P.por_ident(b["sala"])
        if sala is None:
            continue
        ax, az, bx, bz = _nicho(b)
        zonas.append({"id": "nicho_" + b["ident"], "tipo": "sala",
                      "x0": round(min(ax, bx), 2), "z0": round(min(az, bz), 2),
                      "x1": round(max(ax, bx), 2), "z1": round(max(az, bz), 2),
                      "gatilho": {"x0": sala["x0"], "z0": sala["z0"],
                                  "x1": sala["x1"], "z1": sala["z1"]}})
    return zonas


def _nicho(b):
    """(x0, z0, x1, z1) do nicho de terra atras de um buraco.

    As mesmas contas do `_buraco`, que e' quem o DESENHA — e por isso elas
    moram aqui uma vez so': nicho desenhado num lugar e aceso noutro seria um
    retangulo claro em cima de terra preta.
    """
    dx, dz = {"n": (0.0, -1.0), "s": (0.0, 1.0),
              "o": (-1.0, 0.0), "l": (1.0, 0.0)}[b["lado"]]
    meia = P.BURACO_L * 0.5 + 0.55
    fundo = 3.40
    if dz:
        return (b["x"] - meia, b["z"], b["x"] + meia, b["z"] + dz * fundo)
    return (b["x"], b["z"] - meia, b["x"] + dx * fundo, b["z"] + meia)


def _pontos_escola():
    """Um ponto por sala, mais o patio, os dois buracos, a grade e a rua.

    `chave` sai da propria `planta.py`, que ja' guarda a chave de traducao de
    cada sala (`ESC_SALA_*`, as mesmas que o prompt da porta usa). Nada de nome
    digitado aqui: renomear a sala no CSV renomeia no mapa.

    Corredor nao entra — `_area` nasce com `chave` None de proposito, e rotular
    corredor e' rotular o obvio. O PATIO entra, porque ele tem nome e e' onde o
    jogador nasce.
    """
    pontos = []
    for s in P.salas():
        x, z = P.centro(s)
        pontos.append({"id": s["ident"], "chave": s["chave"], "tipo": "sala",
                       "x": round(x, 2), "z": round(z, 2)})
    for a in P.areas():
        if not a.get("chave"):
            continue
        x, z = P.centro(a)
        pontos.append({"id": a["ident"], "chave": a["chave"], "tipo": "marco",
                       "x": round(x, 2), "z": round(z, 2)})

    for (b, chave) in ((P.BURACO_ENTRADA, "MAP_POI_ESC_BURACO_E"),
                       (P.BURACO_SAIDA, "MAP_POI_ESC_BURACO_S")):
        ponto = P.ponto_do_vao(b["ident"], 1.40)
        if ponto:
            pontos.append({"id": b["ident"], "chave": chave, "tipo": "local",
                           "x": round(ponto[0], 2), "z": round(ponto[1], 2)})

    pontos.append({"id": "grade", "chave": "MAP_POI_ESC_GRADE",
                   "tipo": "local", "x": round(P.GRADE_X, 2),
                   "z": round((P.GRADE_Z0 + P.GRADE_Z1) * 0.5, 2)})

    ponto = P.ponto_do_vao("portao_rua", 1.60)
    if ponto:
        pontos.append({"id": "saida", "chave": "MAP_POI_ESC_SAIDA",
                       "tipo": "marco", "x": round(ponto[0], 2),
                       "z": round(ponto[1], 2)})
    return pontos


# ==========================================================================
# PORAO
# ==========================================================================

def _recorte_porao(celulas):
    x0, z0, x1, z1 = PO.limites(celulas)
    x0, z0, x1, z1 = x0 - 4.0, z0 - 4.0, x1 + 4.0, z1 + 4.0
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    meio = max(x1 - x0, z1 - z0) / 2.0 + MARGEM
    return cx - meio, cz - meio, meio * 2.0


def build_porao():
    celulas = PO.celulas_abertas()
    X0, Z0, TAM = _recorte_porao(celulas)
    N = RES * SS
    ppm = N / TAM

    def p(x, z):
        return ((x - X0) * ppm, (z - Z0) * ppm)

    def cx(x0, z0, x1, z1):
        return [p(min(x0, x1), min(z0, z1)), p(max(x0, x1), max(z0, z1))]

    img = Image.new("RGB", (N, N), C_TERRA)
    dr = ImageDraw.Draw(img)

    # ---- o tunel, celula a celula. Aqui nao ha' "pelo avesso": nao existe
    # parede a escavar, o tunel ja' E' a lista de celulas.
    #
    # As corridas horizontais (as mesmas que viram caixa na geometria) em vez
    # de um retangulo por celula: 131 desenhos no lugar de 1.402, e sem juntas
    # visiveis entre celulas vizinhas.
    for (i0, i1, j, _k) in PO.corridas(celulas):
        cor = C_CAMARA if PO.na_camara(i0, j) else C_TUNEL
        dr.rectangle(cx(i0 * PO.CELULA, j * PO.CELULA,
                        i1 * PO.CELULA, (j + 1) * PO.CELULA), fill=cor)

    # ---- o fio do caminho principal.
    #
    # E' a unica ajuda que este mapa da', e ele precisa dar alguma: num tunel
    # de terra sem rotulo nenhum, o que falta saber e' qual das ramificacoes
    # leva a algum lugar. Os becos sem saida ficam de fora do fio de proposito.
    linha = [p(x, z) for (x, z, _r) in PO.CAMINHO]
    dr.line(linha, fill=C_TRILHA, width=max(1, int(0.30 * ppm)), joint="curve")

    # ---- as duas bocas
    for (x, z) in (PO.BOCA_ENTRADA, PO.BOCA_SAIDA):
        r = 1.6
        dr.ellipse(cx(x - r, z - r, x + r, z + r), fill=C_BOCA,
                   outline=C_TERRA, width=max(1, int(0.18 * ppm)))

    img = img.resize((RES, RES), Image.LANCZOS)
    os.makedirs(DIR_TEX, exist_ok=True)
    png = os.path.join(DIR_TEX, "T_poraomap.png")
    img.save(png)

    meta = {
        "nota": "planta do porao da escola, coberta por T_poraomap.png; "
                "gerado por tools/godot/escola/make_mapa_escola.py",
        "nome": "MAP_NOME_PORAO",
        "mundo_x0": round(X0, 2), "mundo_z0": round(Z0, 2),
        "tamanho_m": round(TAM, 2), "resolucao": RES,
        # No tunel a nevoa anda quase sempre SOLTA (so' a camara e' zona), e e'
        # por isso que o raio de fora de zona aqui e' maior que o da escola:
        # ele e' a regra, nao a excecao. 6,5 m mostra a curva que vem e nao
        # alcanca o ramo vizinho — o mais perto deles passa a 10 m.
        "nevoa": {"resolucao": NEVOA_RES, "raio_m": 6.5, "margem_m": 1.0},
        "zonas": _zonas_porao(),
        "pontos": _pontos_porao(),
    }
    caminho = os.path.join(ASSETS, "poraomap.json")
    json.dump(meta, open(caminho, "w", encoding="utf-8"), indent=1)
    return meta, png, caminho


def _zonas_porao():
    """Uma zona so': a camara.

    O resto do porao e' tunel de 2 m de largura, e tunel nao tem "entrou,
    viu" — tem curva. La' a nevoa anda solta, no raio do bloco `nevoa`.

    A camara e' o unico espaco em que o jogador PARA e olha em volta, e e' a
    referencia dele pra saber se ja' passou da metade: acende inteira. O
    retangulo e' o cheio da camara (os cantos dela sao comidos em diagonal),
    o que acende um naco de terra nas quinas — de graca, e' terra igual a'
    de fora.
    """
    x0, z0, x1, z1 = PO.CAMARA
    return [{"id": "camara", "tipo": "sala",
             "x0": x0, "z0": z0, "x1": x1, "z1": z1}]


def _pontos_porao():
    """Tres pontos, e nem um a mais.

    Um tunel de terra nao tem comodo pra rotular, e encher o mapa de losango
    aqui seria inventar informacao que o lugar nao tem. O que o jogador precisa
    e' saber onde ele entrou, onde ele sai e onde fica o unico espaco grande —
    que e' a referencia dele pra saber se ja' passou da metade.
    """
    x0, z0, x1, z1 = PO.CAMARA
    return [
        {"id": "boca_entrada", "chave": "MAP_POI_POR_ENTRADA", "tipo": "local",
         "x": round(PO.BOCA_ENTRADA[0], 2), "z": round(PO.BOCA_ENTRADA[1], 2)},
        {"id": "camara", "chave": "MAP_POI_POR_CAMARA", "tipo": "marco",
         "x": round((x0 + x1) * 0.5, 2), "z": round((z0 + z1) * 0.5, 2)},
        {"id": "boca_saida", "chave": "MAP_POI_POR_SAIDA", "tipo": "marco",
         "x": round(PO.BOCA_SAIDA[0], 2), "z": round(PO.BOCA_SAIDA[1], 2)},
    ]


def gerar():
    for (nome, fn) in (("escola", build_escola), ("porao", build_porao)):
        meta, png, js = fn()
        print("== %s ==" % nome)
        print("  %s" % png)
        print("  %s" % js)
        print("  recorte X0=%.1f Z0=%.1f tamanho=%.1f m  (%.2f px/m)"
              % (meta["mundo_x0"], meta["mundo_z0"], meta["tamanho_m"],
                 meta["resolucao"] / meta["tamanho_m"]))
        print("  %d pontos" % len(meta["pontos"]))


if __name__ == "__main__":
    gerar()
