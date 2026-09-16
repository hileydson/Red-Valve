"""Navmesh do hospital — e, de quebra, o conferidor da planta.

    python3 tools/godot/hospital/navmesh.py     # so' o relatorio

==============================================================================
POR QUE A MALHA E' UMA GRADE, E NAO POLIGONOS GRANDES

O caminho obvio seria emitir um retangulo convexo por comodo. Parece
melhor (menos poligono, funil mais limpo), mas encosta num detalhe do Godot: dois
poligonos de navegacao so' se ligam quando as ARESTAS batem. A aresta longa de
um corredor contra as tres arestas curtas de tres portas nao bate em nada — a
ligacao ai depende do `edge_connection_margin`, que e' um segundo mecanismo,
por aproximacao, e que ja' deu ilha silenciosa neste projeto antes.

Grade resolve na origem: toda celula tira os quatro cantos de um mesmo
reticulado, entao celula vizinha COMPARTILHA vertice de verdade e a ligacao e'
exata. O custo e' poligono a mais (uns 5 mil nos dois andares), que para
NavigationServer3D e' pouco.

==============================================================================
A REGRA DA CELULA

Uma celula de 1 m entra na malha quando o CENTRO dela cai dentro de algum
retangulo pisavel. Os retangulos vem em duas dosagens:

  - comodo/corredor: encolhido RECUO (0,75 m) pra dentro das paredes. Isso
    mantem o caminho longe do rodape — importante porque o inimigo persegue
    pelo navmesh mas colide pela capsula, e caminho colado na parede vira
    inimigo raspando parede.
  - vao de porta: encolhido so' FOLGA_PORTA (0,15 m). Uma porta de 2,20 m
    encolhida 0,75 dos dois lados sobraria 0,70 m — menos que o diametro do
    jogador (1,35 m) — e, pior, podia nao conter nenhum centro de celula e
    fechar a sala. Com 1,90 m sempre sobra pelo menos uma coluna de celulas.

Props ficam encostados na parede de proposito (o pedido foi caminho limpo),
entao quase todos ja' caem fora do retangulo encolhido. Os que avancam pro meio
do comodo (cama, mesa cirurgica, balcao) entram em BLOQUEIOS e sao furados na
grade.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import planta as P

CELULA = 1.0
RECUO = 0.75
FOLGA_PORTA = 0.15
ALTURA_NAV = 0.06      # o navmesh flutua um dedo acima do piso


# --------------------------------------------------------------------------
# retangulos pisaveis
# --------------------------------------------------------------------------

def _encolher(x0, x1, z0, z1, r):
    return (x0 + r, x1 - r, z0 + r, z1 - r)


def vaos_de_porta(andar):
    """Retangulos que atravessam a parede em cada porta/passagem.

    Vao fundo de proposito (1,2 m pra cada lado alem da parede): assim ele
    sempre pega celulas que TAMBEM pertencem ao comodo e ao corredor, e a
    costura acontece sozinha.
    """
    saida = []
    for m in P.muros(andar):
        esp = m["esp"]
        for v in m["vaos"]:
            if v["tipo"] not in ("porta", "passagem"):
                continue
            meia = v["l"] * 0.5 - FOLGA_PORTA
            fundo = esp * 0.5 + 1.2
            if m["eixo"] == "x":
                saida.append((v["c"] - meia, v["c"] + meia,
                              m["coord"] - fundo, m["coord"] + fundo))
            else:
                saida.append((m["coord"] - fundo, m["coord"] + fundo,
                              v["c"] - meia, v["c"] + meia))
    return saida


def costuras(andar):
    """Retangulos que emendam dois espacos de circulacao que se encostam.

    Corredor com corredor nao tem parede no meio: a quina nordeste e' so' o
    corredor norte acabando onde o leste comeca. Mas o RECUO encolhe os dois
    pra dentro e abre uma faixa de 1,5 m sem celula nenhuma bem no meio da
    quina — a malha rachava em duas exatamente onde o predio e' mais aberto.
    Esta emenda devolve a faixa, do mesmo jeito que o vao de porta devolve a
    passagem pelo muro.
    """
    lista = [e for e in P.espacos(andar) if e.get("circulacao")]
    saida = []
    for i in range(len(lista)):
        for j in range(i + 1, len(lista)):
            a, b = lista[i], lista[j]
            for (p, q) in ((a, b), (b, a)):
                if abs(p["z1"] - q["z0"]) < 0.01:
                    x0 = max(p["x0"], q["x0"]) + FOLGA_PORTA
                    x1 = min(p["x1"], q["x1"]) - FOLGA_PORTA
                    if x1 - x0 > 0.5:
                        saida.append((x0, x1, p["z1"] - 1.2, p["z1"] + 1.2))
                if abs(p["x1"] - q["x0"]) < 0.01:
                    z0 = max(p["z0"], q["z0"]) + FOLGA_PORTA
                    z1 = min(p["z1"], q["z1"]) - FOLGA_PORTA
                    if z1 - z0 > 0.5:
                        saida.append((p["x1"] - 1.2, p["x1"] + 1.2, z0, z1))
    return saida


def bloqueios(andar, props):
    """Pegadas de movel que avancam pro meio do comodo."""
    saida = []
    for p in props:
        if p.get("andar") != andar or not p.get("bloqueia"):
            continue
        lx, lz = p["bloqueia"]
        saida.append((p["x"] - lx * 0.5, p["x"] + lx * 0.5,
                      p["z"] - lz * 0.5, p["z"] + lz * 0.5))
    return saida


# --------------------------------------------------------------------------
# a grade
# --------------------------------------------------------------------------

def _dentro(x, z, rects):
    for (x0, x1, z0, z1) in rects:
        if x0 <= x <= x1 and z0 <= z <= z1:
            return True
    return False


def _vizinhos(c):
    i, j = c
    return ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1))


def _maior_ilha(celulas):
    """Fica so' com a maior componente conexa.

    Nao e' paranoia: grade com porta apertada fecha sala sem avisar, e o
    sintoma no jogo e' um inimigo que simplesmente para de te seguir quando
    voce entra num quarto. Melhor descobrir aqui, contando.
    """
    restam = set(celulas)
    ilhas = []
    while restam:
        semente = restam.pop()
        ilha = {semente}
        fila = [semente]
        while fila:
            atual = fila.pop()
            for viz in _vizinhos(atual):
                if viz in restam:
                    restam.discard(viz)
                    ilha.add(viz)
                    fila.append(viz)
        ilhas.append(ilha)
    ilhas.sort(key=len, reverse=True)
    return ilhas


def grade(andar, props=()):
    pisaveis = []
    for e in P.espacos(andar):
        pisaveis.append(_encolher(e["x0"], e["x1"], e["z0"], e["z1"], RECUO))
    pisaveis.extend(vaos_de_porta(andar))
    pisaveis.extend(costuras(andar))
    proibidos = bloqueios(andar, props)

    x0 = min(r[0] for r in pisaveis)
    x1 = max(r[1] for r in pisaveis)
    z0 = min(r[2] for r in pisaveis)
    z1 = max(r[3] for r in pisaveis)

    celulas = set()
    i0, i1 = int(x0 // CELULA) - 1, int(x1 // CELULA) + 2
    j0, j1 = int(z0 // CELULA) - 1, int(z1 // CELULA) + 2
    for i in range(i0, i1):
        for j in range(j0, j1):
            cx = (i + 0.5) * CELULA
            cz = (j + 0.5) * CELULA
            if not _dentro(cx, cz, pisaveis):
                continue
            if _dentro(cx, cz, proibidos):
                continue
            celulas.add((i, j))
    return celulas


def malha(andar, props=(), relatar=True):
    """(vertices, poligonos, ilhas_descartadas) — ja' so' com a maior ilha."""
    celulas = grade(andar, props)
    ilhas = _maior_ilha(celulas)
    boas = ilhas[0] if ilhas else set()
    perdidas = ilhas[1:]

    if relatar:
        print("  andar %d: %d celulas, %d ilha(s)" % (andar, len(celulas), len(ilhas)))
        for ilha in perdidas:
            algum = next(iter(ilha))
            print("    ILHA SOLTA de %d celula(s) perto de x=%.1f z=%.1f — "
                  "alguma sala ficou sem ligacao"
                  % (len(ilha), (algum[0] + 0.5), (algum[1] + 0.5)))

    y = P.cota(andar) + ALTURA_NAV
    indice = {}
    vertices = []

    def vid(i, j):
        chave = (i, j)
        if chave not in indice:
            indice[chave] = len(vertices)
            vertices.append((i * CELULA, y, j * CELULA))
        return indice[chave]

    poligonos = []
    for (i, j) in sorted(boas):
        poligonos.append([vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)])
    return vertices, poligonos, perdidas


# --------------------------------------------------------------------------
# conferencia da planta
# --------------------------------------------------------------------------

def _cruza(a, b):
    return (a["x0"] < b["x1"] - 1e-6 and b["x0"] < a["x1"] - 1e-6
            and a["z0"] < b["z1"] - 1e-6 and b["z0"] < a["z1"] - 1e-6)


def conferir():
    problemas = []

    for andar in (1, 2):
        lista = P.espacos(andar)
        for i in range(len(lista)):
            for j in range(i + 1, len(lista)):
                if _cruza(lista[i], lista[j]):
                    problemas.append("andar %d: '%s' invade '%s'"
                                     % (andar, lista[i]["ident"], lista[j]["ident"]))

    for m in P.muros():
        for v in m["vaos"]:
            if v["c"] - v["l"] * 0.5 < m["a"] - 1e-6 or v["c"] + v["l"] * 0.5 > m["b"] + 1e-6:
                problemas.append("muro %s %.3f (%.2f..%.2f): vao em %.2f larg %.2f sai da parede"
                                 % (m["eixo"], m["coord"], m["a"], m["b"], v["c"], v["l"]))

    com_porta = set()
    for m in P.muros():
        for v in m["vaos"]:
            if v["tipo"] == "porta" and v.get("sala"):
                com_porta.add(v["sala"])
    for s in P.salas():
        if s["ident"] not in com_porta:
            problemas.append("sala '%s' nao tem porta nenhuma" % s["ident"])

    return problemas


if __name__ == "__main__":
    print("== conferindo a planta ==")
    erros = conferir()
    for e in erros:
        print("  !! " + e)
    if not erros:
        print("  planta ok")

    print("== navmesh ==")
    total_p = 0
    for andar in (1, 2):
        v, p, perdidas = malha(andar)
        total_p += len(p)
        print("    %d vertices, %d poligonos" % (len(v), len(p)))
    print("  total de poligonos: %d" % total_p)
