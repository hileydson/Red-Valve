"""O que faz a escola parecer ESCOLA — e abandonada.

Este modulo nao mexe em parede nem em movel grande (isso e' `planta.py` e
`mobilia.py`). Ele espalha a CAMADA DE VIDA por cima:

  - o que esta' ESCRITO: lousa, placa de porta, sinalizacao, cartaz, aviso no
    mural, e o que rabiscaram depois (tudo `Label3D` com chave de traducao,
    ver `textos.py`);
  - o que esta' PREGADO: cartaz didatico, desenho de crianca, aviso, foto de
    desaparecido (quads com as texturas de `texturas.py`);
  - o que CAIU: papel, bolinha de papel, lata, maco de cigarro, folha seca que
    entrou pela janela quebrada, caco de vidro, placa de forro;
  - o que o TEMPO fez: poca embaixo de janela sem vidro e de goteira, mancha de
    infiltracao, teia de canto, forro furado;
  - e o que conta HISTORIA sem uma palavra: a picareta encostada no rombo do
    deposito, a trilha de pezinhos de barro que leva ate' ele, a mao na parede.

==============================================================================
A REGRA DE OURO CONTINUA VALENDO

"Nada no meio do caminho." Tudo aqui ou e' CHATO (decalque no chao, sem
colisao — o jogador pisa por cima), ou e' PEQUENO e solto (lata, garrafa: corpo
fisico que o pe' empurra), ou mora NA PAREDE. Nenhuma peca deste arquivo
declara `bloqueia`, entao o navmesh nao muda por causa dele.

==============================================================================
SEMENTE FIXA, DE NOVO

Cada comodo sorteia com a propria semente (`random.Random("detalhe/<sala>")`):
o papel no chao da sala 102 e' o mesmo em toda build e em toda visita. Lugar
que muda de uma vez pra outra parece bug, nao assombracao.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mobilia as MOB
import planta as P
import texturas as T

GIRO = {"n": 0.0, "s": math.pi, "o": math.pi * 0.5, "l": -math.pi * 0.5}
# o lado de dentro de cada parede, como vetor no chao
NORMAL = {"n": (0.0, 1.0), "s": (0.0, -1.0), "o": (1.0, 0.0), "l": (-1.0, 0.0)}

FONTES = {
    "giz": "res://assets/fonts/Caveat.ttf",
    "placa": "res://assets/fonts/Oswald.ttf",
    "maquina": "res://assets/fonts/SpecialElite-Regular.ttf",
    "pincel": "res://assets/fonts/PermanentMarker-Regular.ttf",
    "garrancho": "res://assets/fonts/RockSalt-Regular.ttf",
}

COR_GIZ = (0.86, 0.88, 0.84, 0.88)
COR_GIZ_AMARELO = (0.90, 0.84, 0.46, 0.85)
COR_TINTA = (0.10, 0.10, 0.12, 0.92)
COR_SANGUE = (0.34, 0.05, 0.04, 0.92)
COR_PICHE = (0.04, 0.04, 0.05, 0.95)
COR_PLACA = (0.92, 0.92, 0.88, 1.0)
COR_TINTA_PATIO = (0.62, 0.66, 0.58, 0.80)


# ==========================================================================
# GEOMETRIA DE PAREDE
# ==========================================================================

def ponto_na_parede(s, lado, ao_longo, y, afasta):
    """(x, y, z) a `afasta` metros da face interna da parede `lado` do comodo,
    na coordenada `ao_longo` (X pras paredes n/s, Z pras o/l)."""
    if lado == "n":
        return (ao_longo, y, s["z0"] + afasta)
    if lado == "s":
        return (ao_longo, y, s["z1"] - afasta)
    if lado == "o":
        return (s["x0"] + afasta, y, ao_longo)
    return (s["x1"] - afasta, y, ao_longo)


def extensao(s, lado):
    """(a, b) da face da parede, ao longo dela."""
    return (s["x0"], s["x1"]) if lado in ("n", "s") else (s["z0"], s["z1"])


def vaos_da_face(s, lado):
    """[(a, b, y0, y1)] dos vaos (porta, janela, buraco) nesta face."""
    if lado in ("n", "s"):
        face = s["z0"] if lado == "n" else s["z1"]
        eixo = "x"
    else:
        face = s["x0"] if lado == "o" else s["x1"]
        eixo = "z"
    saida = []
    for m in P.muros():
        if m["eixo"] != eixo:
            continue
        if abs(abs(m["coord"] - face) - m["esp"] * 0.5) > 0.06:
            continue
        for v in m["vaos"]:
            saida.append((v["c"] - v["l"] * 0.5, v["c"] + v["l"] * 0.5,
                          v["y0"], v["y1"]))
    return saida


# --------------------------------------------------------------------------
# ocupacao: onde os moveis ja' estao
# --------------------------------------------------------------------------

def _caixa_do_prop(p):
    """(x0, x1, z0, z1, y0, y1) aproximado, em coordenada de MUNDO."""
    giro = p["giro"]
    c, s_ = abs(math.cos(giro)), abs(math.sin(giro))
    base = p["y"] + p.get("dy", 0.0)
    if p["tipo"] == "caixas":
        xs = [(q[0] - q[3] * 0.5, q[0] + q[3] * 0.5) for q in p["pecas"]]
        ys = [(q[1] - q[4] * 0.5, q[1] + q[4] * 0.5) for q in p["pecas"]]
        zs = [(q[2] - q[5] * 0.5, q[2] + q[5] * 0.5) for q in p["pecas"]]
        lx = max(b for (_a, b) in xs) - min(a for (a, _b) in xs)
        lz = max(b for (_a, b) in zs) - min(a for (a, _b) in zs)
        y0, y1 = min(a for (a, _b) in ys), max(b for (_a, b) in ys)
    else:
        mn, mx = MOB.aabb(p["modelo"])
        e = p.get("escala", 1.0)
        lx, lz = (mx[0] - mn[0]) * e, (mx[2] - mn[2]) * e
        y0, y1 = mn[1] * e, mx[1] * e
    wx = lx * c + lz * s_
    wz = lx * s_ + lz * c
    return (p["x"] - wx * 0.5, p["x"] + wx * 0.5, p["z"] - wz * 0.5,
            p["z"] + wz * 0.5, base + y0, base + y1)


class Ocupacao:
    def __init__(self, props):
        self.caixas = [_caixa_do_prop(p) for p in props]

    def livre(self, x0, x1, z0, z1, y0, y1, folga=0.05):
        for (a0, a1, b0, b1, c0, c1) in self.caixas:
            if (a0 - folga < x1 and x0 < a1 + folga and b0 - folga < z1
                    and z0 < b1 + folga and c0 - folga < y1 and y0 < c1 + folga):
                return False
        return True

    def ocupar(self, x0, x1, z0, z1, y0, y1):
        self.caixas.append((x0, x1, z0, z1, y0, y1))


def _cabe_na_parede(s, lado, centro, largura, y0, y1, ocup, profundidade=0.45):
    """O retangulo [centro +- largura/2] x [y0, y1] na parede esta' livre de vao
    e de movel encostado?"""
    a, b = extensao(s, lado)
    if centro - largura * 0.5 < a + 0.15 or centro + largura * 0.5 > b - 0.15:
        return False
    for (va, vb, vy0, vy1) in vaos_da_face(s, lado):
        if va - 0.25 < centro + largura * 0.5 and centro - largura * 0.5 < vb + 0.25 \
                and vy0 - 0.15 < y1 and y0 < vy1 + 0.15:
            return False
    p0 = ponto_na_parede(s, lado, centro - largura * 0.5, 0, 0.0)
    p1 = ponto_na_parede(s, lado, centro + largura * 0.5, 0, profundidade)
    x0, x1 = sorted((p0[0], p1[0]))
    z0, z1 = sorted((p0[2], p1[2]))
    return ocup.livre(x0, x1, z0, z1, y0, y1)


def _reservar(s, lado, centro, largura, y0, y1, ocup, profundidade=0.10):
    p0 = ponto_na_parede(s, lado, centro - largura * 0.5, 0, 0.0)
    p1 = ponto_na_parede(s, lado, centro + largura * 0.5, 0, profundidade)
    x0, x1 = sorted((p0[0], p1[0]))
    z0, z1 = sorted((p0[2], p1[2]))
    ocup.ocupar(x0, x1, z0, z1, y0, y1)


# ==========================================================================
# CONSTRUTORES DE ITEM
# ==========================================================================

class Saida:
    def __init__(self):
        self.quads = []
        self.textos = []
        self.props = []
        self.bolas = []
        self.ventiladores = []
        self.sons = []
        self.bandeiras = []     # (pos, eixo_x, eixo_y, eixo_z, cor)
        self.cordoes = []       # (centro, vetor do trecho)

    def quad(self, atlas, cel, pos, plano, giro, largura, altura=None,
             tipo="papel", tom=1.0):
        if altura is None:
            altura = largura * T.proporcao(atlas)
        self.quads.append({"atlas": atlas, "cel": cel, "pos": pos,
                           "plano": plano, "giro": giro, "largura": largura,
                           "altura": altura, "tipo": tipo, "tom": tom})

    def texto(self, chave, fonte, pos, giro, tamanho, cor, px=0.0025,
              alinhar="centro", aceso=False, inclinacao=0.0, largura=0.0):
        self.textos.append({"chave": chave, "fonte": fonte, "pos": pos,
                            "giro": giro, "tamanho": tamanho, "cor": cor,
                            "px": px, "alinhar": alinhar, "aceso": aceso,
                            "inclinacao": inclinacao, "largura": largura})


def _na_parede(saida, s, lado, centro, y, afasta=0.025):
    return ponto_na_parede(s, lado, centro, P.cota() + y, afasta), GIRO[lado]


def _modelo(s, nome, x, z, giro, rotulo, dy=0.0, escala=None, incl=0.0,
            fisico=None):
    p = MOB.modelo_solto(s, nome, x, z, giro, rotulo, dy=dy, escala=escala)
    if incl:
        p["incl"] = incl
    if fisico is False:
        p.pop("fisico", None)
    return p


def _livre_de_tudo(x, z):
    return MOB.livre_de_porta(x, z, 1.3) and MOB.livre_da_grade(x, z)


# ==========================================================================
# CHAO: papel, bolinha, lixo miudo
# ==========================================================================

PAPEIS_DE_CHAO = ("caderno", "caderno_amassado", "quadriculado", "prova",
                  "aviso", "jornal", "pardo", "desenho_casa")


def _papel_no_chao(saida, d, x, z, cel=None):
    cel = cel or d.choice(PAPEIS_DE_CHAO)
    saida.quad("papeis", cel, (x, P.cota() + 0.012 + d.uniform(0, 0.004), z),
               "chao", d.uniform(0, math.tau), d.uniform(0.20, 0.25),
               tipo="papel", tom=d.uniform(0.55, 0.85))


def _espalhar_chao(saida, s, d, ocup, papeis, bolas, lixo, margem=0.5,
                   miolo=True):
    """Lixo de chao num comodo. `miolo=False` (corredor) segura tudo rente as
    paredes, numa faixa de 1,2 m — o meio do corredor continua limpo pro olho,
    alem de pro pe'."""
    x0, x1 = s["x0"] + margem, s["x1"] - margem
    z0, z1 = s["z0"] + margem, s["z1"] - margem

    def sorteia():
        for _ in range(12):
            if miolo:
                x, z = d.uniform(x0, x1), d.uniform(z0, z1)
            else:
                largo = (s["x1"] - s["x0"]) >= (s["z1"] - s["z0"])
                faixa = d.uniform(0.0, 1.2)
                if largo:
                    x = d.uniform(x0, x1)
                    z = (z0 + faixa) if d.random() < 0.5 else (z1 - faixa)
                else:
                    z = d.uniform(z0, z1)
                    x = (x0 + faixa) if d.random() < 0.5 else (x1 - faixa)
            if _livre_de_tudo(x, z):
                return x, z
        return None

    for _ in range(papeis):
        pt = sorteia()
        if pt:
            _papel_no_chao(saida, d, *pt)
    for _ in range(bolas):
        pt = sorteia()
        if pt:
            saida.bolas.append({"pos": (pt[0], P.cota() + 0.035, pt[1]),
                                "giro": d.uniform(0, math.tau),
                                "escala": d.uniform(0.8, 1.3)})
    miudos = ("can_rusted", "cigarette_pack", "bleach_bottle",
              "russian_food_cans_01", "plastic_jerrycan")
    for i in range(lixo):
        pt = sorteia()
        if not pt:
            continue
        nome = miudos[d.randrange(len(miudos))]
        # deitado: lata e garrafa no chao de um lugar abandonado nao ficam em
        # pe'. O corpo fisico assenta sozinho a partir daqui.
        deitado = nome in ("can_rusted", "bleach_bottle", "russian_food_cans_01") \
            and d.random() < 0.7
        saida.props.append(_modelo(s, nome, pt[0], pt[1], d.uniform(0, math.tau),
                                   "lixo_%s_%d" % (nome, i),
                                   dy=0.06 if deitado else 0.0,
                                   incl=math.pi * 0.5 if deitado else 0.0))


# ==========================================================================
# PAREDE: cartaz, desenho, aviso, rabisco
# ==========================================================================

CARTAZ_TITULO = {"alfabeto": "ESC_CARTAZ_ALFABETO", "tabuada": "ESC_CARTAZ_TABUADA",
                 "corpo": "ESC_CARTAZ_CORPO", "planetas": "ESC_CARTAZ_PLANETAS",
                 "tabela": "ESC_CARTAZ_TABELA", "mapa": "ESC_CARTAZ_MAPA"}


def _cartaz(saida, s, lado, centro, nome, ocup, y=1.75, largura=0.62, d=None):
    alt = largura * T.proporcao("cartazes")
    if not _cabe_na_parede(s, lado, centro, largura, y - alt * 0.5, y + alt * 0.5, ocup):
        return False
    _reservar(s, lado, centro, largura, y - alt * 0.5, y + alt * 0.5, ocup)
    pos, giro = _na_parede(saida, s, lado, centro, y, 0.022)
    saida.quad("cartazes", nome, pos, "parede", giro, largura, alt, tipo="cartaz",
               tom=(d.uniform(0.62, 0.82) if d else 0.7))
    # o titulo vai na faixa colorida do alto do cartaz
    faixa_y = y + alt * 0.5 - alt * (40.0 / 512.0)
    tpos, _g = _na_parede(saida, s, lado, centro, faixa_y, 0.028)
    saida.texto(CARTAZ_TITULO[nome], "placa", tpos, giro, 40, (0.95, 0.95, 0.92, 0.95),
                px=0.0018)
    return True


def _desenhos(saida, s, lado, centro, d, ocup, quantos=6, y=1.55):
    """O varal de desenhos de crianca: duas fileiras tortas de folha A4."""
    cels = ["desenho_casa", "desenho_familia", "desenho_escada", "desenho_casa",
            "caderno", "desenho_familia"]
    larg = 0.24
    alt = larg * T.proporcao("papeis")
    cols = (quantos + 1) // 2
    total = cols * (larg + 0.06)
    if not _cabe_na_parede(s, lado, centro, total, y - alt, y + alt, ocup):
        return False
    _reservar(s, lado, centro, total, y - alt, y + alt, ocup)
    n = 0
    for fila in range(2):
        for k in range(cols):
            if n >= quantos:
                break
            c = centro - total * 0.5 + (k + 0.5) * (larg + 0.06) + d.uniform(-0.02, 0.02)
            yy = y + (0.5 - fila) * (alt + 0.05) + d.uniform(-0.03, 0.03)
            pos, giro = _na_parede(saida, s, lado, c, yy, 0.02 + n * 0.0015)
            saida.quad("papeis", cels[(n + d.randrange(3)) % len(cels)], pos, "parede",
                       giro + d.uniform(-0.04, 0.04), larg, tipo="papel",
                       tom=d.uniform(0.6, 0.8))
            n += 1
    return True


def _rabisco(saida, s, lado, centro, chave, d, ocup, y=1.6, fonte="garrancho",
             cor=COR_SANGUE, tamanho=64, px=0.0022, largura_m=1.6):
    if not _cabe_na_parede(s, lado, centro, largura_m, y - 0.4, y + 0.4, ocup, 0.3):
        return False
    pos, giro = _na_parede(saida, s, lado, centro, y, 0.03)
    saida.texto(chave, fonte, pos, giro, tamanho, cor, px=px,
                inclinacao=d.uniform(-0.06, 0.06))
    return True


def _marca(saida, s, lado, centro, cel, y, largura, d, tom=0.8):
    pos, giro = _na_parede(saida, s, lado, centro, y, 0.018 + d.uniform(0, 0.004))
    saida.quad("marcas", cel, pos, "parede", giro, largura, tipo="marca", tom=tom)


def _teias(saida, s, d, quantas=2):
    """Teia nos cantos de cima. O quad da teia tem o canto (0,0) no alto e na
    esquerda; e' espelhado pelo giro pra cair no canto certo."""
    cantos = [("n", "o"), ("n", "l"), ("s", "o"), ("s", "l")]
    d.shuffle(cantos)
    for (lado, ponta) in cantos[:quantas]:
        larg = d.uniform(0.6, 1.0)
        a, b = extensao(s, lado)
        centro = (a + larg * 0.5) if ponta in ("o", "n") else (b - larg * 0.5)
        y = P.PE - larg * 0.5 - 0.01
        pos, giro = _na_parede(saida, s, lado, centro, y, 0.012)
        # espelha quando o canto esta' na outra ponta da parede
        espelho = (ponta in ("l", "s")) != (lado in ("s", "l"))
        saida.quad("marcas", "teia", pos, "parede", giro + (math.pi if espelho else 0.0),
                   larg, tipo="marca", tom=0.7)


def _infiltracao(saida, s, lado, centro, d, larg=None):
    larg = larg or d.uniform(1.0, 2.2)
    alt = larg * T.proporcao("marcas")
    pos, giro = _na_parede(saida, s, lado, centro, P.PE - alt * 0.5 - 0.02, 0.016)
    saida.quad("marcas", "infiltracao", pos, "parede", giro, larg, alt, tipo="marca",
               tom=d.uniform(0.6, 0.9))


def _forro_caido(saida, s, d, x, z, n):
    """Placa de forro no chao, o buraco em cima e o fio pendurado."""
    if not _livre_de_tudo(x, z):
        return
    saida.quad("marcas", "buraco_forro", (x, P.cota() + P.PE - 0.004, z), "teto",
               d.uniform(0, math.tau), d.uniform(0.9, 1.3), tipo="marca", tom=1.0)
    for k in range(d.randrange(2, 4)):
        ox, oz = d.uniform(-0.8, 0.8), d.uniform(-0.8, 0.8)
        saida.props.append(_prop_caixas(s, [(0.0, 0.012, 0.0, d.uniform(0.45, 0.62),
                                             0.024, d.uniform(0.45, 0.62), "teto")],
                                        x + ox, z + oz, d.uniform(0, math.tau),
                                        "forro_%s_%d" % (n, k),
                                        incl=d.uniform(-0.12, 0.12)))
    # o fio que ficou pendurado
    saida.props.append(_prop_caixas(s, [(0.0, -0.45, 0.0, 0.012, 0.9, 0.012, "lum_fio")],
                                    x + 0.1, z - 0.1, 0.0, "fio_%s" % n,
                                    dy=P.PE, incl=d.uniform(-0.25, 0.25)))
    _papel_no_chao(saida, d, x + d.uniform(-1, 1), z + d.uniform(-1, 1), "pardo")


def _prop_caixas(s, pecas, x, z, giro, nome, dy=0.0, incl=0.0):
    p = MOB.caixas_solto(s, pecas, x, z, giro, nome, dy=dy)
    if incl:
        p["incl"] = incl
    return p


def _poca(saida, x, z, d, larg=None):
    larg = larg or d.uniform(1.2, 2.4)
    saida.quad("chao", "poca", (x, P.cota() + 0.006, z), "chao",
               d.uniform(0, math.tau), larg, larg * d.uniform(0.6, 0.9), tipo="poca")


# ==========================================================================
# JANELAS QUEBRADAS: caco e folha seca pra dentro, poca embaixo
# ==========================================================================

def _janelas_quebradas(saida, d):
    for m in P.muros():
        if m["tipo"] != "externa":
            continue
        for v in m["vaos"]:
            if v["tipo"] != "janela" or not v.get("quebrada"):
                continue
            for lado_ in (1.0, -1.0):
                if m["eixo"] == "x":
                    x, z = v["c"], m["coord"] + lado_ * 0.9
                else:
                    x, z = m["coord"] + lado_ * 0.9, v["c"]
                e = P.espaco_em(x, z)
                if e is None:
                    continue
                gir = d.uniform(0, math.tau)
                saida.quad("chao", "cacos", (x, P.cota() + 0.008, z), "chao", gir,
                           d.uniform(1.0, 1.5), tipo="caco")
                # a folha seca e a agua entram pela abertura e escorrem pra dentro
                fx = x + (0.0 if m["eixo"] == "x" else lado_ * 0.8)
                fz = z + (lado_ * 0.8 if m["eixo"] == "x" else 0.0)
                saida.quad("chao", "folhas", (fx, P.cota() + 0.010, fz), "chao",
                           d.uniform(0, math.tau), d.uniform(1.0, 1.6), tipo="chao")
                if d.random() < 0.7:
                    _poca(saida, fx + d.uniform(-0.4, 0.4), fz + d.uniform(-0.4, 0.4), d)
                break


# ==========================================================================
# POR COMODO
# ==========================================================================

def _parede_da_lousa(s):
    largo = (s["x1"] - s["x0"]) >= (s["z1"] - s["z0"])
    return "o" if largo else "n"


LOUSA_DA_SALA = {"sala_101": "ESC_LOUSA_101", "sala_102": "ESC_LOUSA_102",
                 "sala_103": "ESC_LOUSA_103", "sala_104": "ESC_LOUSA_104",
                 "sala_105": "ESC_LOUSA_105", "sala_106": "ESC_LOUSA_106",
                 "sala_107": "ESC_LOUSA_107"}

RABISCO_DA_SALA = {"sala_104": "ESC_RABISCO_PROFESSORA",
                   "sala_106": "ESC_RABISCO_FUNDO",
                   "sala_103": "ESC_RABISCO_NOMES",
                   "sala_107": "ESC_RABISCO_DESCULPA"}

# Os ventiladores que ainda giram. Poucos: um ventilador girando devagar numa
# sala sem ninguem e' a coisa mais estranha da escola justamente porque nao
# deveria haver energia nenhuma ali.
VENTILADOR_GIRANDO = {("sala_102", 0): 0.9, ("sala_106", 1): 0.45,
                      ("sala_104", 0): 0.25}


def _sala_aula(saida, s, d, ocup):
    lado = _parede_da_lousa(s)
    a, b = extensao(s, lado)
    meio = (a + b) * 0.5
    # a lousa: mesma conta de `mobilia.lousa()` posta a 0,10 m da parede
    # (face a 0,13 m), centro em 1,55 m
    chave = LOUSA_DA_SALA.get(s["ident"])
    if chave:
        pos, giro = _na_parede(saida, s, lado, meio, 1.58, 0.145)
        # Letra de professora: ~20 cm de corpo nas lousas de 3-4 linhas, um
        # pouco menos nas que enchem o quadro (a 102 e a castigo da 104). Na
        # primeira versao o texto ocupava um quarto da lousa e so' se lia
        # encostado nela.
        cheia = s["ident"] in ("sala_104", "sala_102")
        saida.texto(chave, "giz", pos, giro, 64,
                    COR_GIZ if s["ident"] != "sala_104" else COR_GIZ_AMARELO,
                    px=0.0022 if cheia else 0.0032)
    # ventiladores de teto: dois, no eixo curto, entre as luminarias
    cx, cz = (s["x0"] + s["x1"]) * 0.5, (s["z0"] + s["z1"]) * 0.5
    largo = (s["x1"] - s["x0"]) >= (s["z1"] - s["z0"])
    for k, off in enumerate((-2.4, 2.4)):
        x, z = (cx, cz + off) if largo else (cx + off, cz)
        saida.ventiladores.append({"pos": (x, P.cota() + P.PE, z), "sala": s["ident"],
                                   "giro": d.uniform(0, math.tau),
                                   "velocidade": VENTILADOR_GIRANDO.get((s["ident"], k), 0.0)})
    # a parede do fundo (oposta a' lousa) leva os desenhos; as laterais, os
    # cartazes
    fundo = {"o": "l", "n": "s"}[lado]
    fa, fb = extensao(s, fundo)
    for t in (0.30, 0.68, 0.5, 0.2, 0.82):
        if _desenhos(saida, s, fundo, fa + (fb - fa) * t, d, ocup, quantos=d.choice((4, 6, 6))):
            break
    laterais = ("n", "s") if lado == "o" else ("o", "l")
    cartazes = ["alfabeto", "tabuada", "mapa", "planetas"]
    d.shuffle(cartazes)
    n = 0
    for lat in laterais:
        la, lb = extensao(s, lat)
        for t in (0.25, 0.55, 0.8, 0.4):
            if n >= 3:
                break
            if _cartaz(saida, s, lat, la + (lb - la) * t, cartazes[n % 4], ocup, d=d):
                n += 1
    rab = RABISCO_DA_SALA.get(s["ident"])
    if rab:
        for t in (0.6, 0.35, 0.8):
            if _rabisco(saida, s, fundo, fa + (fb - fa) * t, rab, d, ocup,
                        y=1.25 if rab != "ESC_RABISCO_NOMES" else 1.1,
                        fonte="pincel" if rab == "ESC_RABISCO_NOMES" else "garrancho",
                        cor=COR_PICHE if rab == "ESC_RABISCO_NOMES" else COR_SANGUE,
                        tamanho=56):
                break
    _teias(saida, s, d, 2)
    if d.random() < 0.6:
        lad = d.choice(laterais)
        la, lb = extensao(s, lad)
        _infiltracao(saida, s, lad, la + (lb - la) * d.uniform(0.2, 0.8), d)
    _espalhar_chao(saida, s, d, ocup, papeis=d.randrange(8, 14), bolas=d.randrange(5, 10),
                   lixo=d.randrange(0, 3))
    # o cesto de lixo pequeno, transbordando, perto da porta
    px, pz = _ponto_livre_rente(s, d, ocup)
    if px is not None:
        saida.props.append(_prop_caixas(s, cesto(), px, pz, d.uniform(0, math.tau),
                                        "cesto"))
        for _ in range(4):
            saida.bolas.append({"pos": (px + d.uniform(-0.5, 0.5), P.cota() + 0.035,
                                        pz + d.uniform(-0.5, 0.5)),
                                "giro": d.uniform(0, math.tau), "escala": d.uniform(0.8, 1.2)})
    if s["ident"] == "sala_105":
        # no dia da prova, a sala inteira levou papel
        for _ in range(10):
            _papel_no_chao(saida, d, d.uniform(s["x0"] + 1, s["x1"] - 1),
                           d.uniform(s["z0"] + 1, s["z1"] - 1), "prova")
    if s["ident"] == "sala_101":
        # o patinho de borracha na mesa da professora: nada a ver com nada
        mx, _y, mz = ponto_na_parede(s, lado, meio + 0.4, 0, 1.30)
        saida.props.append(_modelo(s, "rubber_duck_toy", mx, mz, GIRO[lado], "patinho",
                                   dy=0.77, fisico=False, escala=0.6))
    if s["ident"] == "sala_103":
        tx, _y, tz = ponto_na_parede(s, fundo, fa + (fb - fa) * 0.88, 0, 0.6)
        saida.props.append(_modelo(s, "Television_01", tx, tz, GIRO[fundo], "tv",
                                   dy=0.0, fisico=False))
    if s["ident"] == "sala_106":
        tx, _y, tz = ponto_na_parede(s, lado, a + (b - a) * 0.12, 0, 0.9)
        saida.props.append(_modelo(s, "standing_chalkboard_01", tx, tz, GIRO[lado] + 0.5,
                                   "cavalete", fisico=False))
    if s["ident"] == "sala_107":
        tx, _y, tz = ponto_na_parede(s, lado, a + (b - a) * 0.88, 0, 1.0)
        saida.props.append(_modelo(s, "projector_screen", tx, tz, GIRO[lado] - 0.3,
                                   "tela", fisico=False))


def _ponto_livre_rente(s, d, ocup):
    for _ in range(20):
        lado = d.choice(("n", "s", "o", "l"))
        a, b = extensao(s, lado)
        c = d.uniform(a + 0.6, b - 0.6)
        x, _y, z = ponto_na_parede(s, lado, c, 0, 0.35)
        if _livre_de_tudo(x, z) and ocup.livre(x - 0.25, x + 0.25, z - 0.25, z + 0.25, 0.0, 0.6):
            ocup.ocupar(x - 0.25, x + 0.25, z - 0.25, z + 0.25, 0.0, 0.6)
            return x, z
    return None, None


def cesto():
    """Cesto de lixo de sala de aula: quatro paredes finas de plastico."""
    t, h, e = 0.32, 0.38, 0.015
    return [(0.0, h * 0.5, -t * 0.5, t, h, e, "mat_plastico_azul"),
            (0.0, h * 0.5, t * 0.5, t, h, e, "mat_plastico_azul"),
            (-t * 0.5, h * 0.5, 0.0, e, h, t, "mat_plastico_azul"),
            (t * 0.5, h * 0.5, 0.0, e, h, t, "mat_plastico_azul"),
            (0.0, 0.01, 0.0, t, 0.02, t, "mat_plastico_azul"),
            (0.0, h - 0.02, 0.0, t - 0.04, 0.05, t - 0.04, "mat_papel")]


def _corredor(saida, s, d, ocup):
    largo = (s["x1"] - s["x0"]) >= (s["z1"] - s["z0"])
    lados = ("n", "s") if largo else ("o", "l")
    a, b = extensao(s, lados[0])
    comprimento = b - a
    # avisos sobre os murais de cortica (o `mural()` do mobilia.py: 2,40 x
    # 1,10 a 1,70 m de altura e 0,10 m da parede)
    for p in list(saida._props_mobilia):
        if p["sala"] != s["ident"] or not p.get("nome", "").startswith("mural_"):
            continue
        lado = _lado_do_prop(s, p)
        if lado is None:
            continue
        c = p["x"] if lado in ("n", "s") else p["z"]
        avisos = ["aviso", "desaparecido", "prova", "jornal", "aviso", "caderno"]
        d.shuffle(avisos)
        titulos = ["ESC_AVISO_REUNIAO", "ESC_AVISO_VACINA", "ESC_AVISO_ACHADOS",
                   "ESC_AVISO_FESTA", "ESC_AVISO_FECHADO"]
        for k in range(4):
            cel = avisos[k]
            off = -0.80 + k * 0.53 + d.uniform(-0.04, 0.04)
            yy = 1.70 + d.uniform(-0.18, 0.18)
            pos, giro = _na_parede(saida, s, lado, c + off, yy, 0.165 + k * 0.002)
            saida.quad("papeis", cel, pos, "parede", giro + d.uniform(-0.05, 0.05),
                       0.28, tipo="papel", tom=d.uniform(0.6, 0.85))
            alt = 0.28 * T.proporcao("papeis")
            if cel == "aviso":
                tp, _g = _na_parede(saida, s, lado, c + off, yy + alt * 0.30, 0.172)
                saida.texto(titulos[d.randrange(len(titulos))], "maquina", tp, giro, 26,
                            COR_TINTA, px=0.0012)
            elif cel == "desaparecido":
                tp, _g = _na_parede(saida, s, lado, c + off, yy + alt * 0.40, 0.172)
                saida.texto("ESC_CARTAZ_DESAPARECIDO", "placa", tp, giro, 40, COR_TINTA,
                            px=0.0012)
                tp, _g = _na_parede(saida, s, lado, c + off, yy - alt * 0.36, 0.172)
                saida.texto("ESC_CARTAZ_DESAPARECIDO_TEXTO", "maquina", tp, giro, 16,
                            COR_TINTA, px=0.0012)
        tp, _g = _na_parede(saida, s, lado, c, 2.18, 0.12)
        saida.texto("ESC_MURAL_TITULO", "placa", tp, GIRO[lado], 64, (0.86, 0.84, 0.70, 0.9),
                    px=0.0024)

    # cartazes soltos e desenhos entre as portas
    t = 0.07
    n = 0
    nomes = ["alfabeto", "mapa", "planetas", "tabuada", "corpo"]
    while t < 0.95:
        lado = lados[n % 2]
        c = a + comprimento * t
        if d.random() < 0.5:
            if _cartaz(saida, s, lado, c, nomes[n % len(nomes)], ocup, d=d):
                n += 1
        elif _desenhos(saida, s, lado, c, d, ocup, quantos=4, y=1.6):
            n += 1
        t += d.uniform(0.05, 0.09)

    # rabiscos grandes de quem passou depois
    rabiscos = {"corredor_norte": ["ESC_RABISCO_CONTE", "ESC_RABISCO_VOLTA"],
                "corredor_leste": ["ESC_RABISCO_EMBAIXO", "ESC_RABISCO_NOMES"],
                "corredor_sul": ["ESC_RABISCO_CANOS", "ESC_RABISCO_NAO_DESCA"]}
    for k, chave in enumerate(rabiscos.get(s["ident"], [])):
        for t in d.sample([0.15, 0.3, 0.45, 0.6, 0.75, 0.88], 6):
            lado = lados[(k + int(t * 10)) % 2]
            if _rabisco(saida, s, lado, a + comprimento * t, chave, d, ocup, y=2.2,
                        fonte="pincel" if chave == "ESC_RABISCO_NOMES" else "garrancho",
                        cor=COR_PICHE if k == 1 else COR_SANGUE, tamanho=72,
                        largura_m=2.2):
                break

    # marcas de mao e arrasto, so' no lado de ca' da grade, a caminho do deposito
    if s["ident"] == "corredor_sul":
        for k in range(3):
            x = P.GRADE_X + 3.5 + k * 2.6
            _marca(saida, s, "s", x, "mao", 1.0 + d.uniform(-0.2, 0.3), 0.55, d)
        _marca(saida, s, "n", P.GRADE_X + 4.0, "arrasto", 0.9, 0.6, d)
        # a trilha de pezinhos de barro: sai da grade e entra no deposito
        for k in range(6):
            x = P.GRADE_X + 1.6 + k * 1.5
            saida.quad("chao", "pezinhos", (x, P.cota() + 0.009, 54.5 + k * 0.35), "chao",
                       -math.pi * 0.5 + 0.35, 0.9, tipo="chao", tom=0.9)
        saida.quad("marcas", "riscos", (P.GRADE_X + 0.35, P.cota() + 1.4, 53.2), "parede",
                   math.pi * 0.5, 0.9, tipo="marca", tom=0.9)

    _teias(saida, s, d, 2)
    for k in range(int(comprimento / 14)):
        lado = lados[d.randrange(2)]
        _infiltracao(saida, s, lado, a + comprimento * d.uniform(0.05, 0.95), d)
    _espalhar_chao(saida, s, d, ocup, papeis=int(comprimento / 3.0),
                   bolas=int(comprimento / 6.0), lixo=int(comprimento / 12.0),
                   margem=0.35, miolo=False)
    # placas de forro caidas — no meio do corredor sim: sao planas e finas
    for k in range(int(comprimento / 25)):
        tt = d.uniform(0.15, 0.85)
        if largo:
            x, z = a + comprimento * tt, (s["z0"] + s["z1"]) * 0.5 + d.uniform(-1, 1)
        else:
            x, z = (s["x0"] + s["x1"]) * 0.5 + d.uniform(-1, 1), a + comprimento * tt
        _forro_caido(saida, s, d, x, z, "%s_%d" % (s["ident"], k))
    # agua: goteira no meio do corredor, poca embaixo
    for k in range(int(comprimento / 18)):
        tt = d.uniform(0.1, 0.9)
        if largo:
            x, z = a + comprimento * tt, (s["z0"] + s["z1"]) * 0.5 + d.uniform(-1.4, 1.4)
        else:
            x, z = (s["x0"] + s["x1"]) * 0.5 + d.uniform(-1.4, 1.4), a + comprimento * tt
        if _livre_de_tudo(x, z):
            _poca(saida, x, z, d)
            saida.quad("marcas", "infiltracao", (x, P.cota() + P.PE - 0.004, z), "teto",
                       d.uniform(0, math.tau), 1.3, tipo="marca", tom=0.8)
            saida.sons.append({"tipo": "goteira", "pos": (x, P.cota() + 2.6, z)})


def _lado_do_prop(s, p):
    """De que parede do comodo este movel encostado esta' mais perto."""
    dists = {"n": p["z"] - s["z0"], "s": s["z1"] - p["z"],
             "o": p["x"] - s["x0"], "l": s["x1"] - p["x"]}
    lado = min(dists, key=dists.get)
    return lado if dists[lado] < 0.6 else None


def _patio(saida, s, d, ocup):
    # o nome da escola pintado no muro, por cima da porta principal, e o lema
    # que alguem riscou
    pos, giro = _na_parede(saida, s, "n", 20.0, 3.55, 0.03)
    saida.texto("ESC_PINTURA_NOME", "placa", pos, giro, 140, COR_TINTA_PATIO, px=0.004)
    pos, giro = _na_parede(saida, s, "l", 33.0, 2.9, 0.03)
    saida.texto("ESC_PINTURA_LEMA", "placa", pos, giro, 120, (0.50, 0.58, 0.48, 0.75),
                px=0.004)
    pos, giro = _na_parede(saida, s, "l", 33.5, 2.25, 0.04)
    saida.texto("ESC_RABISCO_SEM_CAMINHO", "garrancho", pos, giro, 110, COR_SANGUE,
                px=0.0035, inclinacao=-0.05)
    # agua: a chuva junta no piso do patio
    for _ in range(14):
        x, z = d.uniform(s["x0"] + 2, s["x1"] - 2), d.uniform(s["z0"] + 2, s["z1"] - 2)
        _poca(saida, x, z, d, d.uniform(1.6, 3.4))
    for _ in range(18):
        x, z = d.uniform(s["x0"] + 0.6, s["x1"] - 0.6), d.uniform(s["z0"] + 0.6, s["z1"] - 0.6)
        saida.quad("chao", "folhas", (x, P.cota() + 0.03, z), "chao",
                   d.uniform(0, math.tau), d.uniform(1.0, 2.0), tipo="chao")
    _espalhar_chao(saida, s, d, ocup, papeis=10, bolas=6, lixo=5, margem=1.0)
    x, z = s["x1"] - 3.0, s["z1"] - 4.2
    saida.props.append(_modelo(s, "baseball_bat", x, z, 0.7, "taco", dy=0.03,
                               fisico=False))
    _bandeirinhas(saida, d)


# --------------------------------------------------------------------------
# as bandeirinhas da festa junina
#
# Ficaram penduradas desde a ultima festa — a do aviso no mural. Cordoes dos
# postes dos refletores ate' o alto dos muros, e um cordao entre os dois
# postes, cruzando a quadra. Um deles arrebentou: desce do poste ate' o chao e
# o resto das bandeiras ficou deitado na agua.
# --------------------------------------------------------------------------

BANDEIRA_PASSO = 0.42
BANDEIRA_L, BANDEIRA_H = 0.22, 0.30


def _norm(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def _cruz(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _cordao(saida, d, a, b, flecha, rompido_em=None):
    """Um cordao de `a` a `b` caindo `flecha` metros no meio (parabola, que a
    essa distancia nao se distingue da catenaria). `rompido_em` (0..1): dali
    pra frente o cordao despencou ate' o chao."""
    comp = math.dist(a, b)
    n = max(int(comp / BANDEIRA_PASSO), 2)
    pts = []
    for k in range(n + 1):
        t = k / float(n)
        p = [a[i] + (b[i] - a[i]) * t for i in range(3)]
        p[1] -= flecha * 4.0 * t * (1.0 - t)
        pts.append(tuple(p))
    if rompido_em is not None:
        corte = int(n * rompido_em)
        topo = pts[corte]
        resto = []
        # do ponto do rompimento ele pende quase reto e depois deita no chao
        queda = topo[1] - P.cota()
        for k in range(n + 1 - corte):
            dist = k * BANDEIRA_PASSO
            if dist < queda:
                resto.append((topo[0] + dist * 0.18 * (b[0] - a[0]) / comp, topo[1] - dist,
                              topo[2] + dist * 0.18 * (b[2] - a[2]) / comp))
            else:
                sobra = dist - queda
                resto.append((topo[0] + (queda * 0.18 + sobra) * (b[0] - a[0]) / comp,
                               P.cota() + 0.02,
                               topo[2] + (queda * 0.18 + sobra) * (b[2] - a[2]) / comp
                               + math.sin(sobra * 0.9) * 0.4))
        pts = pts[:corte] + resto
    for k in range(len(pts) - 1):
        p0, p1 = pts[k], pts[k + 1]
        centro = tuple((p0[i] + p1[i]) * 0.5 for i in range(3))
        saida.cordoes.append((centro, tuple(p1[i] - p0[i] for i in range(3))))
        if d.random() < 0.16:
            continue                    # arrancada pelo vento
        x = _norm(tuple(p1[i] - p0[i] for i in range(3)))
        no_chao = centro[1] < P.cota() + 0.1
        if no_chao:
            # deitada na agua, de qualquer jeito
            g = d.uniform(0, math.tau)
            ex, ey, ez = (math.cos(g), 0.0, -math.sin(g)), (-math.sin(g), 0.0, -math.cos(g)), (0.0, 1.0, 0.0)
            pos = (centro[0] + d.uniform(-0.2, 0.2), P.cota() + 0.025, centro[2] + d.uniform(-0.2, 0.2))
        else:
            cima = (0.0, 1.0, 0.0)
            z = _norm(_cruz(x, cima))
            y = _cruz(z, x)
            # torcao do vento em volta do barbante
            ang = d.uniform(-0.6, 0.6)
            ca, sa = math.cos(ang), math.sin(ang)
            y2 = tuple(y[i] * ca + z[i] * sa for i in range(3))
            z2 = tuple(z[i] * ca - y[i] * sa for i in range(3))
            ex, ey, ez = x, y2, z2
            pos = tuple(centro[i] - ey[i] * BANDEIRA_H * 0.5 for i in range(3))
        saida.bandeiras.append((pos, ex, ey, ez, d.randrange(len(T.BANDEIRAS))))


def _bandeirinhas(saida, d):
    import luzes as L
    (x1, z1, _v1), (x2, z2, _v2) = L.REFLETORES[0], L.REFLETORES[1]
    alto_poste = L.REFLETOR_H - 1.2
    alto_muro = P.PATIO_MURO_ALTO - 0.25
    patio = P.por_ident("patio")
    norte, sul = patio["z0"] + 0.2, patio["z1"] - 0.2
    _cordao(saida, d, (x1, alto_poste, z1), (x1 + 3.0, alto_muro, norte), 0.9)
    _cordao(saida, d, (x1, alto_poste, z1), (x1 + 3.0, alto_muro, sul), 0.9)
    _cordao(saida, d, (x2, alto_poste, z2), (x2 - 3.0, alto_muro, norte), 0.9)
    _cordao(saida, d, (x2, alto_poste, z2), (x2 - 6.0, alto_muro, sul), 1.0, rompido_em=0.35)
    _cordao(saida, d, (x1, alto_poste, z1), (x2, alto_poste, z2), 1.8)
    _cordao(saida, d, (x1, alto_poste, z1), (patio["x0"] + 0.2, alto_muro, z1 + 9.0), 0.8)


def _secretaria(saida, s, d, ocup):
    # a ficharia arrombada: papel pra todo lado
    for _ in range(30):
        _papel_no_chao(saida, d, d.uniform(s["x0"] + 0.6, s["x1"] - 0.6),
                       d.uniform(s["z0"] + 0.6, s["z1"] - 0.6),
                       d.choice(("aviso", "prova", "jornal", "pardo", "quadriculado")))
    pos, giro = _na_parede(saida, s, "o", (s["z0"] + s["z1"]) * 0.5, 2.55, 0.03)
    saida.texto("ESC_PLACA_ATENDIMENTO", "placa", pos, giro, 52, (0.80, 0.80, 0.74, 0.85),
                px=0.0024)
    # o retrato do diretor fundador, torto
    for (t, nome, y) in ((0.45, "fancy_picture_frame_01", 1.95), (0.7, "hanging_picture_frame_01", 1.8)):
        a, b = extensao(s, "n")
        x, _y, z = ponto_na_parede(s, "n", a + (b - a) * t, 0, 0.02)
        p = _modelo(s, nome, x, z, GIRO["n"], "quadro_%d" % int(t * 100), dy=y, fisico=False)
        p["incl_z"] = d.uniform(-0.12, 0.12)
        saida.props.append(p)
    # sobre o balcao
    bx, _y, bz = ponto_na_parede(s, "s", s["x0"] + (s["x1"] - s["x0"]) * 0.32, 0, 1.40)
    for (k, (nome, dx)) in enumerate((("Megaphone_01", -1.2), ("cassette_player", -0.4),
                                      ("vintage_stapler", 0.3), ("alarm_clock_01", 1.1))):
        saida.props.append(_modelo(s, nome, bx + dx, bz, d.uniform(0, math.tau),
                                   "balcao_%d" % k, dy=1.06, fisico=False))
    _teias(saida, s, d, 3)
    _infiltracao(saida, s, "l", (s["z0"] + s["z1"]) * 0.5, d, 2.6)
    _espalhar_chao(saida, s, d, ocup, papeis=0, bolas=6, lixo=1)


def _refeitorio(saida, s, d, ocup):
    lado = "n"
    a, b = extensao(s, lado)
    # o quadro do cardapio, ao lado da porta do corredor
    for t in (0.18, 0.3, 0.75, 0.86):
        c = a + (b - a) * t
        if _cabe_na_parede(s, lado, c, 1.5, 1.2, 2.3, ocup):
            _reservar(s, lado, c, 1.5, 1.2, 2.3, ocup)
            saida.props.append(MOB.caixas_na_parede(s, MOB.lousa(1.4, 1.0), lado, t, 0.06,
                                                    "cardapio", dy=1.75))
            pos, giro = _na_parede(saida, s, lado, c, 1.76, 0.105)
            saida.texto("ESC_LOUSA_CARDAPIO", "giz", pos, giro, 56, COR_GIZ, px=0.0024)
            break
    for (t, chave) in ((0.55, "ESC_PLACA_LAVE_MAOS"), (0.42, "ESC_PLACA_PROIBIDO_FUMAR")):
        c = a + (b - a) * t
        if _cabe_na_parede(s, lado, c, 1.0, 1.9, 2.5, ocup):
            _placa_parede(saida, s, lado, c, 2.2, chave, 1.0, 0.42)
    # a comida que ficou: bandeja nas mesas, lata no chao
    for p in list(saida._props_mobilia):
        if p["sala"] != s["ident"] or not p.get("nome", "").startswith("mesa_"):
            continue
        for k in range(d.randrange(1, 4)):
            saida.props.append(_prop_caixas(
                s, bandeja(d), p["x"] + d.uniform(-1.0, 1.0), p["z"] + d.uniform(-0.25, 0.25),
                d.uniform(-0.4, 0.4), "bandeja_%s_%d" % (p["nome"], k), dy=0.77))
    bx, _y, bz = ponto_na_parede(s, "s", (s["x0"] + s["x1"]) * 0.5, 0, 1.20)
    for k in range(6):
        saida.props.append(_modelo(s, "russian_food_cans_01", bx + d.uniform(-2.2, 2.2),
                                   bz + d.uniform(-0.2, 0.2), d.uniform(0, math.tau),
                                   "lata_balcao_%d" % k, dy=1.05, fisico=False))
    _teias(saida, s, d, 3)
    _espalhar_chao(saida, s, d, ocup, papeis=6, bolas=8, lixo=6)
    for _ in range(3):
        _poca(saida, d.uniform(s["x0"] + 1, s["x1"] - 1), d.uniform(s["z0"] + 1, s["z1"] - 1), d)


def bandeja(d):
    cor = d.choice(("mat_plastico_azul", "mat_plastico_verde", "mat_inox"))
    p = [(0.0, 0.01, 0.0, 0.42, 0.02, 0.30, cor)]
    if d.random() < 0.6:
        p.append((0.08, 0.04, 0.02, 0.12, 0.05, 0.12, "mat_inox"))
    return p


def _placa_parede(saida, s, lado, centro, y, chave, larg, alt, aceso=False):
    """Placa de chapa pintada, com o texto em cima."""
    a, b = extensao(s, lado)
    t = (centro - a) / (b - a)
    mat = "mat_placa_saida" if aceso else "mat_placa"
    saida.props.append(MOB.caixas_na_parede(s, [(0.0, 0.0, 0.0, larg, alt, 0.02, mat)], lado,
                                            t, 0.012, "placa_%s" % chave.lower(), dy=y))
    pos, giro = _na_parede(saida, s, lado, centro, y, 0.026)
    cor = (0.95, 1.0, 0.95, 1.0) if aceso else (0.12, 0.14, 0.13, 0.95)
    saida.texto(chave, "placa", pos, giro, 64, cor, px=0.0014 * min(larg / 1.0, 1.4),
                aceso=aceso)


def _biblioteca(saida, s, d, ocup):
    for lado, t in (("n", 0.5), ("s", 0.75)):
        a, b = extensao(s, lado)
        c = a + (b - a) * t
        if _cabe_na_parede(s, lado, c, 1.6, 2.2, 2.9, ocup):
            pos, giro = _na_parede(saida, s, lado, c, 2.55, 0.03)
            saida.texto("ESC_PLACA_SILENCIO", "placa", pos, giro, 200, (0.55, 0.20, 0.16, 0.85),
                        px=0.0034)
    a, b = extensao(s, "o")
    _cartaz(saida, s, "o", a + (b - a) * 0.5, "mapa", ocup, d=d)
    # livro caido: pilhas tortas no chao, entre as estantes
    for k in range(14):
        x, z = d.uniform(s["x0"] + 0.8, s["x1"] - 0.8), d.uniform(s["z0"] + 1.0, s["z1"] - 1.0)
        if not ocup.livre(x - 0.3, x + 0.3, z - 0.3, z + 0.3, 0.0, 0.3):
            continue
        saida.props.append(_prop_caixas(s, pilha_de_livros(d), x, z, d.uniform(0, math.tau),
                                        "livros_chao_%d" % k))
    x, _y, z = ponto_na_parede(s, "n", s["x0"] + (s["x1"] - s["x0"]) * 0.70, 0, 2.20)
    saida.props.append(_modelo(s, "desk_lamp_arm_01", x + 0.3, z, 2.5, "luminaria_mesa",
                               dy=0.75, fisico=False))
    _teias(saida, s, d, 4)
    _espalhar_chao(saida, s, d, ocup, papeis=10, bolas=3, lixo=0)


CORES_LIVRO = ("mat_livro_1", "mat_livro_2", "mat_livro_3", "mat_livro_4",
               "mat_livro_5", "mat_livro_6")


def pilha_de_livros(d):
    p = []
    y = 0.0
    for k in range(d.randrange(1, 5)):
        h = d.uniform(0.025, 0.05)
        p.append({"pos": (d.uniform(-0.04, 0.04), y + h * 0.5, d.uniform(-0.04, 0.04)),
                  "tam": (d.uniform(0.15, 0.24), h, d.uniform(0.21, 0.30)),
                  "giro": d.uniform(-0.5, 0.5), "mat": d.choice(CORES_LIVRO)})
        y += h
    return p


def livros_na_prateleira(d, largura, y, profundidade, ocupacao=0.85):
    """Uma fileira de lombadas numa prateleira de `largura` m, base em `y`."""
    p = []
    x = -largura * 0.5 + 0.03
    while x < largura * 0.5 - 0.05:
        if d.random() > ocupacao:
            x += d.uniform(0.08, 0.30)
            continue
        e = d.uniform(0.022, 0.06)
        h = d.uniform(0.18, 0.30)
        prof = d.uniform(0.14, min(0.24, profundidade - 0.06))
        p.append((x + e * 0.5, y + h * 0.5, 0.0, e, h, prof, d.choice(CORES_LIVRO)))
        x += e + 0.003
    return p


def _laboratorio(saida, s, d, ocup):
    lado = "n"
    a, b = extensao(s, lado)
    pos, giro = _na_parede(saida, s, lado, (a + b) * 0.5, 1.58, 0.145)
    saida.texto("ESC_LOUSA_LAB", "giz", pos, giro, 64, COR_GIZ, px=0.0030)
    for (lado_, t, nome) in (("l", 0.70, "tabela"), ("l", 0.85, "corpo"), ("s", 0.52, "planetas")):
        la, lb = extensao(s, lado_)
        _cartaz(saida, s, lado_, la + (lb - la) * t, nome, ocup, d=d)
    for (t, chave) in ((0.15, "ESC_PLACA_OCULOS"), (0.85, "ESC_PLACA_PROIBIDO_FUMAR")):
        c = a + (b - a) * t
        if _cabe_na_parede(s, lado, c, 0.9, 2.0, 2.5, ocup):
            _placa_parede(saida, s, lado, c, 2.25, chave, 0.9, 0.38)
    # o que sobrou na bancada
    ox, _y, oz = ponto_na_parede(s, "o", s["z0"] + (s["z1"] - s["z0"]) * 0.50, 0, 0.50)
    for (k, (nome, dz)) in enumerate((("vintage_microscope", -0.6), ("magnifying_glass_01", 0.1),
                                      ("bleach_bottle", 0.5), ("drain_cleaner", 0.8))):
        saida.props.append(_modelo(s, nome, ox, oz + dz, d.uniform(0, math.tau),
                                   "bancada_%d" % k, dy=0.90, fisico=False))
    cx, cz = (s["x0"] + s["x1"]) * 0.5, (s["z0"] + s["z1"]) * 0.5
    saida.props.append(_modelo(s, "filmstrip_projector_8mm", cx, s["z0"] + (s["z1"] - s["z0"]) * 0.62,
                               1.2, "projetor", dy=0.90 + 0.16, fisico=False))
    _teias(saida, s, d, 3)
    _espalhar_chao(saida, s, d, ocup, papeis=6, bolas=4, lixo=3)
    saida.quad("chao", "mancha", (cx + 1.2, P.cota() + 0.007, cz - 2.0), "chao", 0.7, 1.6,
               tipo="chao", tom=0.8)


def _servico(saida, s, d, ocup):
    """Almoxarifado e deposito: zeladoria, e as pistas dos dois buracos."""
    produtos = ("bleach_bottle", "multi_cleaner_5_litre", "drain_cleaner",
                "plastic_jerrycan", "plunger", "dustpan", "wooden_broom", "mousetrap")
    for k in range(8):
        lado = d.choice(("n", "o", "l"))
        a, b = extensao(s, lado)
        c = d.uniform(a + 0.8, b - 0.8)
        x, _y, z = ponto_na_parede(s, lado, c, 0, 0.30)
        if not _livre_de_tudo(x, z) or not ocup.livre(x - 0.2, x + 0.2, z - 0.2, z + 0.2, 0, 0.5):
            continue
        nome = produtos[k % len(produtos)]
        incl = 0.0
        if nome == "wooden_broom":
            incl = -0.25    # encostada na parede
        saida.props.append(_modelo(s, nome, x, z, GIRO[lado] + d.uniform(-0.6, 0.6),
                                   "zeladoria_%d" % k, incl=incl,
                                   dy=0.05 if nome == "wooden_broom" else 0.0,
                                   fisico=False if nome in ("wooden_broom", "plunger") else None))
    if s["ident"] == "deposito":
        b = P.BURACO_ENTRADA
        # a picareta que cavou o rombo, encostada do lado dele
        saida.props.append(_modelo(s, "picke_dirty_01", b["x"] + 1.6, b["z"] - 0.3, 0.2,
                                   "picareta", dy=0.32, incl=0.32, fisico=False))
        saida.quad("chao", "barro", (b["x"], P.cota() + 0.01, b["z"] - 1.6), "chao", 0.0, 2.8,
                   tipo="chao", tom=1.0)
        saida.quad("chao", "barro", (b["x"] - 1.6, P.cota() + 0.01, b["z"] - 3.2), "chao", 1.3, 2.0,
                   tipo="chao", tom=0.9)
        for k in range(4):
            saida.quad("chao", "pezinhos", (b["x"] - 0.4 + k * 0.25, P.cota() + 0.011,
                                            b["z"] - 6.4 + k * 1.3),
                       "chao", math.pi + 0.15, 0.9, tipo="chao", tom=0.9)
        a_, b_ = extensao(s, "s")
        _marca(saida, s, "s", b["x"] - 1.9, "seta", 1.3, 0.8, d, 1.0)
        _rabisco(saida, s, "s", b["x"] + 3.6, "ESC_RABISCO_NAO_DESCA", d, ocup, y=2.1,
                 tamanho=60, largura_m=1.4)
        _placa_parede(saida, s, "n", 64.0, 2.25, "ESC_PLACA_RESTRITO", 1.1, 0.36)
    else:
        b = P.BURACO_SAIDA
        saida.quad("chao", "barro", (b["x"] + 1.6, P.cota() + 0.01, b["z"]), "chao", 0.4, 2.6,
                   tipo="chao", tom=1.0)
        _marca(saida, s, "o", b["z"] - 1.8, "unhas", 0.9, 0.7, d, 0.9)
        _marca(saida, s, "o", b["z"] + 1.9, "mao", 1.1, 0.6, d, 0.9)
    _teias(saida, s, d, 4)
    _infiltracao(saida, s, "n", (s["x0"] + s["x1"]) * 0.5, d, 2.8)
    _espalhar_chao(saida, s, d, ocup, papeis=5, bolas=3, lixo=4)
    saida.sons.append({"tipo": "goteira", "pos": ((s["x0"] + s["x1"]) * 0.5, P.cota() + 2.8,
                                                   (s["z0"] + s["z1"]) * 0.5)})


RECEITUARIO = {"sala_aula": _sala_aula, "corredor": _corredor, "patio": _patio,
               "secretaria": _secretaria, "refeitorio": _refeitorio,
               "biblioteca": _biblioteca, "laboratorio": _laboratorio,
               "almoxarifado": _servico, "deposito": _servico}


# ==========================================================================
# PLACAS DE PORTA E SINALIZACAO
# ==========================================================================

def _placas_de_porta(saida):
    """A plaquinha com o nome da sala, sobre a porta, do lado do corredor."""
    for m in P.muros():
        for v in m["vaos"]:
            if v["tipo"] != "porta" or not v.get("sala"):
                continue
            sala = P.por_ident(v["sala"])
            if not sala or not sala.get("chave") or sala.get("circulacao"):
                continue
            for lado_ in (1.0, -1.0):
                if m["eixo"] == "x":
                    px, pz = v["c"], m["coord"] + lado_ * 0.6
                else:
                    px, pz = m["coord"] + lado_ * 0.6, v["c"]
                e = P.espaco_em(px, pz)
                if e is None or e["ident"] == sala["ident"]:
                    continue
                # do lado de fora da sala
                desloc = m["esp"] * 0.5 + 0.012
                if m["eixo"] == "x":
                    pos = (v["c"], P.cota() + P.PORTA_H + 0.30, m["coord"] + lado_ * desloc)
                    giro = 0.0 if lado_ > 0 else math.pi
                else:
                    pos = (m["coord"] + lado_ * desloc, P.cota() + P.PORTA_H + 0.30, v["c"])
                    giro = math.pi * 0.5 if lado_ > 0 else -math.pi * 0.5
                saida.placas_porta.append({"pos": pos, "giro": giro, "chave": sala["chave"]})
                break


def _saidas(saida):
    """Placa verde de SAIDA, acesa. Sobre a porta principal (lado do corredor) e
    sobre o portao do patio (lado do corredor sul): as duas portas que levam pra
    fora do predio coberto."""
    for ident in ("porta_principal", "portao_lazer"):
        m, v = P.vao_por_ident(ident)
        if m is None:
            continue
        for lado_ in (1.0, -1.0):
            pz = m["coord"] + lado_ * 0.6
            e = P.espaco_em(v["c"], pz)
            if e is None or e["tipo"] != "corredor":
                continue
            desloc = m["esp"] * 0.5 + 0.05
            pos = (v["c"], P.cota() + P.PORTA_H + 0.42, m["coord"] + lado_ * desloc)
            saida.saidas.append({"pos": pos, "giro": 0.0 if lado_ > 0 else math.pi})


# ==========================================================================

def montar(props_mobilia):
    saida = Saida()
    saida._props_mobilia = props_mobilia
    saida.placas_porta = []
    saida.saidas = []
    ocup = Ocupacao(props_mobilia)
    for e in P.espacos():
        receita = RECEITUARIO.get(e["tipo"])
        if receita:
            receita(saida, e, random.Random("detalhe/" + e["ident"]), ocup)
    _janelas_quebradas(saida, random.Random("detalhe/janelas"))
    _placas_de_porta(saida)
    _saidas(saida)
    # nenhum prop pode nascer num vao de porta: o jogador ficaria preso
    saida.props = [p for p in saida.props
                   if MOB.livre_de_porta(p["x"], p["z"], 0.6) or p.get("dy", 0) > 0.5]
    return saida


if __name__ == "__main__":
    s = montar(MOB.mobiliar())
    print("detalhes: %d quads, %d textos, %d props, %d bolinhas, %d ventiladores, "
          "%d placas de porta, %d sons"
          % (len(s.quads), len(s.textos), len(s.props), len(s.bolas),
             len(s.ventiladores), len(s.placas_porta), len(s.sons)))
    por = {}
    for q in s.quads:
        por[q["atlas"] + "/" + q["cel"]] = por.get(q["atlas"] + "/" + q["cel"], 0) + 1
    print("  " + ", ".join("%s=%d" % kv for kv in sorted(por.items())))
