"""Planta baixa dos DOIS andares do hospital, para o minimapa e a aba MAPA.

    python3 tools/godot/hospital/make_mapa_hospital.py     (precisa de Pillow)

Saidas (uma prancha por andar):
    red-valve/assets/3d_model/stages/hospital/textures/T_hospitalmap_1.png
    red-valve/assets/3d_model/stages/hospital/textures/T_hospitalmap_2.png
    red-valve/assets/3d_model/stages/hospital/hospitalmap_1.json
    red-valve/assets/3d_model/stages/hospital/hospitalmap_2.json

==============================================================================
DUAS PRANCHAS, E NAO UMA COM HACHURA

A igreja resolve o "segundo andar" com hachura diagonal por cima do piso de
baixo (`tools/godot/igreja/make_mapa_igreja.py`), e la' isso esta' certo: as
galerias dela sao duas varandas estreitas em cima das naves laterais, e o
resto do predio e' pe-direito duplo.

Aqui nao da'. Os dois andares do hospital sao andares INTEIROS, 56 x 68 m um
em cima do outro, com plantas completamente diferentes — 20 salas embaixo, 10
em cima. Sobrepostos viram rabisco. Entao sao duas imagens, e quem escolhe
qual mostrar e' o `minimap.gd`, pela altura do jogador: abaixo de 2,10 m e' o
terreo, acima e' o segundo andar. Trocar de andar no elevador troca o mapa.

==============================================================================
COMO A PLANTA E' DESENHADA

Pelo avesso, que e' o mesmo truque da igreja: preenche o retangulo do andar
INTEIRO de massa de parede e depois ESCAVA o vao interno de cada sala e de
cada area de circulacao. O que sobra sem escavar sao exatamente as paredes —
sem precisar desenhar parede nenhuma, e sem chance de a parede do mapa nao
bater com a parede do jogo.

Por cima disso vao os vaos (`planta.muros()`): porta em cor quente, janela em
cor fria. O desenho da porta e' o que faz a planta ser navegavel de relance —
sem ele o mapa vira um monte de caixas fechadas.

Circulacao sai um tom mais claro que sala. E' o que da', num olhar, a leitura
de "por onde eu ando" — mesma ideia da rua clara contra a quadra escura no
mapa da cidade.

==============================================================================
DE ONDE VEM CADA NUMERO

Tudo de `planta.py` — o mesmo modulo que gera a geometria, a colisao e o
navmesh. Mover uma parede la' move a parede aqui. O unico numero digitado
neste arquivo e' o da paleta.
"""

import json
import os
import sys

from PIL import Image, ImageDraw

_AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _AQUI)

import planta as P  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(_AQUI)))
ASSETS = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages",
                      "hospital")
DIR_TEX = os.path.join(ASSETS, "textures")

# 2048: o predio tem 73 m de recorte, o que da' 28 px/m. O painel do menu deixa
# aproximar ate' 24 m de altura numa area de ~740 px — 31 px/m na tela. Fica
# 1,1x de ampliacao, ou seja, nunca borra.
RES = 2048
SS = 2                # supersampling: desenha em 2x e reduz
MARGEM = 2.50         # metros de folga em volta do predio

# Altura a partir da qual o jogador esta' no andar de cima. Metade do pe' entre
# as duas lajes: alto o bastante pra nao piscar com o jogador pulando no
# terreo, baixo o bastante pra trocar assim que ele sai da cabine em cima.
ALTURA_ANDAR_2 = P.ANDAR_2 * 0.5

# Paleta: familia sepia do mapa da cidade, um degrau mais escura, igual a' da
# igreja. O contraste que carrega a leitura e' piso claro x parede escura.
C_FORA      = (13, 14, 15)
C_MASSA     = (46, 43, 38)      # a parede, que e' o que sobra sem escavar
C_MASSA_BRD = (19, 18, 16)
C_SALA      = (104,  98,  86)
C_CIRC      = (134, 126, 110)   # corredor e hall
C_SAGUAO    = (146, 138, 120)   # os vazios grandes do 2o andar
C_PORTA     = (176, 132,  70)
C_JANELA    = ( 92, 120, 126)
C_ELEV      = (158,  94,  66)   # o poco: a unica ligacao entre os dois andares
C_ELEV_BRD  = ( 60,  34,  24)

# Tipos de area que sao circulacao aberta, e nao corredor.
SAGUOES = ("saguao",)

# Parede tem 35 cm, o que a 28 px/m da' 10 px: uma janela desenhada na
# espessura exata da parede sumia no contorno. Ela transborda 15 cm pra cada
# lado — sai da parede e encosta no escuro de fora, que e' onde ela e' vista.
FOLGA_JANELA = 0.15

# Espessura, em metros, da linha de contorno do volume.
BORDA = 0.14

# Salas com nome proprio no mapa. Fora desta lista nada vira rotulo: area de
# circulacao nao tem `chave`, e rotular corredor e' rotular o obvio.
TIPO_SALA = "sala"


def _recorte():
    """Quadrado do mundo que a imagem cobre.

    Quadrado, e nao o retangulo justo do predio, pelo mesmo motivo da igreja: o
    minimapa GIRA, e com escala diferente nos dois eixos a planta apareceria
    esticada em umas direcoes e achatada em outras.

    Entra o poco do elevador, que fica FORA do volume (x ate' 62) — sem ele o
    elevador cairia pra fora da folha justo no mapa que existe pra achar o
    elevador.
    """
    x0, x1 = P.PREDIO_X0, P.POCO_X1
    z0, z1 = P.A1_Z0, P.A1_Z1
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    meio = max(x1 - x0, z1 - z0) / 2.0 + MARGEM
    return cx - meio, cz - meio, meio * 2.0


X0, Z0, TAM = _recorte()


def _fundo(andar):
    """Retangulo do andar: o 2o e' 3,6 m mais curto que o terreo."""
    z1 = P.A1_Z1 if andar == 1 else P.A2_Z1
    return (P.PREDIO_X0, 0.0, P.PREDIO_X1, z1)


def build(andar):
    N = RES * SS
    ppm = N / TAM

    def p(x, z):
        return ((x - X0) * ppm, (z - Z0) * ppm)

    def cx(x0, z0, x1, z1):
        return [p(min(x0, x1), min(z0, z1)), p(max(x0, x1), max(z0, z1))]

    img = Image.new("RGB", (N, N), C_FORA)
    dr = ImageDraw.Draw(img)

    # ---- a massa de parede: o andar inteiro, cheio
    dr.rectangle(cx(*_fundo(andar)), fill=C_MASSA)

    # ---- o vazio por dentro, escavado na massa
    for s in P.salas(andar):
        dr.rectangle(cx(s["x0"], s["z0"], s["x1"], s["z1"]), fill=C_SALA)
    for a in P.areas(andar):
        cor = C_SAGUAO if a["tipo"] in SAGUOES else C_CIRC
        dr.rectangle(cx(a["x0"], a["z0"], a["x1"], a["z1"]), fill=cor)

    # ---- contorno do volume. Fino de proposito: a 0,30 m ele comia a fachada
    # inteira (que tem 0,35) e o predio ficava com a borda preta, sem parede
    # nenhuma de leste — a junta com o poco do elevador sumia junto.
    dr.rectangle(cx(*_fundo(andar)), outline=C_MASSA_BRD,
                 width=max(1, int(BORDA * ppm)))

    # ---- o poco do elevador, encostado na fachada leste. DEPOIS do contorno:
    # antes, a linha grossa da borda passava por cima da junta e o poco
    # aparecia solto no escuro, como se nao encostasse no predio.
    _elevador(dr, cx, ppm)

    # ---- os vaos por ultimo, tambem por cima do contorno — senao a borda
    # tapava justo o vao do elevador e as janelas da fachada. E' o desenho do
    # vao que faz a planta virar caminho, em vez de um monte de caixa fechada.
    for m in P.muros(andar):
        for v in m["vaos"]:
            eh_janela = v["tipo"] == "janela"
            dr.rectangle(cx(*_caixa_do_vao(m, v, FOLGA_JANELA if eh_janela
                                           else 0.0)),
                         fill=C_JANELA if eh_janela else C_PORTA)

    img = img.resize((RES, RES), Image.LANCZOS)
    os.makedirs(DIR_TEX, exist_ok=True)
    png = os.path.join(DIR_TEX, "T_hospitalmap_%d.png" % andar)
    img.save(png)

    meta = {
        "nota": "planta do %do andar do hospital, coberta por "
                "T_hospitalmap_%d.png; gerado por "
                "tools/godot/hospital/make_mapa_hospital.py" % (andar, andar),
        "nome": "MAP_FLOOR_HOSP_%d" % andar,
        "mundo_x0": round(X0, 2), "mundo_z0": round(Z0, 2),
        "tamanho_m": round(TAM, 2), "resolucao": RES,
        "pontos": _pontos(andar),
    }
    caminho = os.path.join(ASSETS, "hospitalmap_%d.json" % andar)
    json.dump(meta, open(caminho, "w", encoding="utf-8"), indent=1)
    return meta, png, caminho


def _caixa_do_vao(m, v, folga=0.0):
    """(x0, z0, x1, z1) do recorte que um vao abre na parede.

    `eixo` e' a direcao em que a parede CORRE, e `c`/`l` do vao sao medidos
    nessa mesma direcao; a espessura e' o outro eixo, metade pra cada lado de
    `coord`. `folga` engorda o recorte na espessura — ver FOLGA_JANELA.
    """
    meia = m["esp"] * 0.5 + folga
    a, b = v["c"] - v["l"] * 0.5, v["c"] + v["l"] * 0.5
    if m["eixo"] == "x":
        return (a, m["coord"] - meia, b, m["coord"] + meia)
    return (m["coord"] - meia, a, m["coord"] + meia, b)


def _elevador(dr, cx, ppm):
    """O poco, igual nos dois andares — e' um so', atravessando o predio.

    Cor propria e nao a de sala: num mapa de dois andares, a unica coisa que
    o jogador precisa achar rapido e' por onde se troca de andar.
    """
    # a casca do poco e' parede como qualquer outra — pintada de escuro ela
    # ficava da cor do lado de fora, e o elevador parecia solto no vazio, sem
    # encostar no predio
    dr.rectangle(cx(P.POCO_X0 - P.PAREDE, P.POCO_Z0, P.POCO_X1, P.POCO_Z1),
                 fill=C_MASSA, outline=C_MASSA_BRD,
                 width=max(1, int(BORDA * ppm)))
    dr.rectangle(cx(P.CABINE_X0, P.CABINE_Z0, P.CABINE_X1, P.CABINE_Z1),
                 fill=C_ELEV, outline=C_ELEV_BRD,
                 width=max(1, int(0.16 * ppm)))


# --------------------------------------------------------------------------
# pontos
# --------------------------------------------------------------------------

def _pontos(andar):
    """Um ponto por sala, mais o elevador — e a saida, no terreo.

    `chave` sai da propria `planta.py`, que ja' guarda a chave de traducao de
    cada sala (`HOSP_SALA_*`, as mesmas que o prompt da porta usa). Nada de
    nome digitado aqui: renomear a sala no CSV renomeia no mapa.

    Corredor, hall e saguao NAO entram: `_area` nasce com `chave` None de
    proposito, e rotular corredor e' rotular o obvio.

    Estes rotulos so' aparecem na aba MAPA. O minimapa do hospital desliga os
    pontos (`pontos_no_minimapa = false`): trinta losangos em 190 px tapariam
    a planta que eles deviam explicar.
    """
    pontos = []
    for s in P.salas(andar):
        x, z = P.centro(s)
        pontos.append({"id": s["ident"], "chave": s["chave"],
                       "tipo": TIPO_SALA, "x": round(x, 2), "z": round(z, 2)})

    pontos.append({
        "id": "elevador", "chave": "MAP_POI_HOSP_ELEVADOR", "tipo": "local",
        "x": round((P.CABINE_X0 + P.CABINE_X1) * 0.5, 2),
        "z": round((P.CABINE_Z0 + P.CABINE_Z1) * 0.5, 2)})

    if andar == 1:
        # a porta da rua e' um VAO num muro, e nao um espaco: quem sabe onde
        # ela esta' e' a fachada oeste, nao a lista de salas
        z = _vao_por_ident(1, "entrada_principal")
        if z is not None:
            pontos.append({
                "id": "saida", "chave": "MAP_POI_HOSP_SAIDA", "tipo": "marco",
                "x": round(P.PREDIO_X0 + 1.20, 2), "z": round(z, 2)})
    return pontos


def _vao_por_ident(andar, ident):
    for m in P.muros(andar):
        for v in m["vaos"]:
            if v.get("ident") == ident:
                return v["c"]
    return None


def gerar():
    for andar in (1, 2):
        meta, png, js = build(andar)
        print("== %do andar ==" % andar)
        print("  %s" % png)
        print("  %s" % js)
        print("  recorte X0=%.1f Z0=%.1f tamanho=%.1f m  (%.2f px/m)" % (
            meta["mundo_x0"], meta["mundo_z0"], meta["tamanho_m"],
            meta["resolucao"] / meta["tamanho_m"]))
        print("  %d pontos" % len(meta["pontos"]))


if __name__ == "__main__":
    gerar()
