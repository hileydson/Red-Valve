"""Navmesh da escola — e, de quebra, o conferidor da planta.

    python3 tools/godot/escola/navmesh.py     # so' o relatorio

==============================================================================
POR QUE A MALHA E' UMA GRADE, E NAO POLIGONOS GRANDES

O mesmo motivo do hospital: dois poligonos de navegacao so' se ligam quando as
ARESTAS batem, e a aresta longa de um corredor contra as arestas curtas de
cinco portas nao bate em nada — a ligacao passaria a depender do
`edge_connection_margin`, que e' um segundo mecanismo, por aproximacao, e que
ja' deu ilha silenciosa neste projeto antes.

Grade resolve na origem: celula vizinha compartilha vertice de verdade.

==============================================================================
O QUE E' BLOQUEIO AQUI, E O QUE NAO E'

Duas coisas fecham caminho nesta escola, e so' UMA delas entra na malha:

  - A GRADE do corredor sul entra. Ela e' solida e nao abre nunca; inimigo que
    a atravessasse pelo navmesh ficaria preso nela pela capsula.
  - O PORTAO DO PATIO nao entra. Ele esta' trancado no comeco do jogo, mas
    destranca — e navmesh nao se regera em tempo de jogo. Porta trancada e'
    assunto do script da porta, igual as do hospital.

Com a grade bloqueada, a malha CONTINUA inteira numa ilha so': os dois lados do
corredor sul se reencontram pelo patio. Isso e' de proposito e nao e' um furo —
quem impede o jogador de dar essa volta e' o portao trancado, nao a geometria.
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


def vaos_de_porta():
    """Retangulos que atravessam a parede em cada porta/passagem.

    Vao fundo de proposito (1,2 m pra cada lado alem da parede): assim ele
    sempre pega celulas que TAMBEM pertencem ao comodo e ao corredor, e a
    costura acontece sozinha.

    O BURACO fica de fora: do lado de la' dele nao tem cena nenhuma — e' uma
    troca de cena, nao uma passagem. Malha entrando ali seria inimigo andando
    pra dentro da parede.
    """
    saida = []
    for m in P.muros():
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


def costuras():
    """Retangulos que emendam dois espacos de circulacao que se encostam.

    Corredor com corredor nao tem parede no meio: a quina nordeste e' so' o
    corredor norte acabando onde o leste comeca. Mas o RECUO encolhe os dois
    pra dentro e abriria uma faixa de 1,5 m sem celula nenhuma bem no meio da
    quina — a malha racharia em duas exatamente onde o predio e' mais aberto.
    """
    lista = [e for e in P.espacos() if e.get("circulacao")]
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


def bloqueios(props):
    """Pegadas de movel que avancam pro meio do comodo, mais a grade."""
    saida = [(P.GRADE_X - 0.7, P.GRADE_X + 0.7,
              P.GRADE_Z0 - 0.4, P.GRADE_Z1 + 0.4)]
    for p in props:
        if not p.get("bloqueia"):
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


def _ilhas(celulas):
    """Componentes conexas, da maior pra menor.

    Nao e' paranoia: grade com porta apertada fecha sala sem avisar, e o
    sintoma no jogo e' um inimigo que simplesmente para de te seguir quando
    voce entra num comodo. Melhor descobrir aqui, contando.
    """
    restam = set(celulas)
    saida = []
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
        saida.append(ilha)
    saida.sort(key=len, reverse=True)
    return saida


def grade_de_celulas(props=()):
    pisaveis = []
    for e in P.espacos():
        pisaveis.append(_encolher(e["x0"], e["x1"], e["z0"], e["z1"], RECUO))
    pisaveis.extend(vaos_de_porta())
    pisaveis.extend(costuras())
    proibidos = bloqueios(props)

    x0 = min(r[0] for r in pisaveis)
    x1 = max(r[1] for r in pisaveis)
    z0 = min(r[2] for r in pisaveis)
    z1 = max(r[3] for r in pisaveis)

    celulas = set()
    for i in range(int(x0 // CELULA) - 1, int(x1 // CELULA) + 2):
        for j in range(int(z0 // CELULA) - 1, int(z1 // CELULA) + 2):
            cx = (i + 0.5) * CELULA
            cz = (j + 0.5) * CELULA
            if not _dentro(cx, cz, pisaveis):
                continue
            if _dentro(cx, cz, proibidos):
                continue
            celulas.add((i, j))
    return celulas


def malha(props=(), relatar=True):
    """(vertices, poligonos, ilhas_descartadas) — ja' so' com a maior ilha."""
    celulas = grade_de_celulas(props)
    ilhas = _ilhas(celulas)
    boas = ilhas[0] if ilhas else set()
    perdidas = ilhas[1:]

    if relatar:
        print("  %d celulas, %d ilha(s)" % (len(celulas), len(ilhas)))
        for ilha in perdidas:
            algum = next(iter(ilha))
            print("    ILHA SOLTA de %d celula(s) perto de x=%.1f z=%.1f — "
                  "algum comodo ficou sem ligacao"
                  % (len(ilha), (algum[0] + 0.5), (algum[1] + 0.5)))

    y = P.cota() + ALTURA_NAV
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
        poligonos.append([vid(i, j), vid(i + 1, j), vid(i + 1, j + 1),
                          vid(i, j + 1)])
    return vertices, poligonos, perdidas


# --------------------------------------------------------------------------
# conferencia da planta
# --------------------------------------------------------------------------

def _cruza(a, b):
    return (a["x0"] < b["x1"] - 1e-6 and b["x0"] < a["x1"] - 1e-6
            and a["z0"] < b["z1"] - 1e-6 and b["z0"] < a["z1"] - 1e-6)


def conferir():
    problemas = []

    lista = P.espacos()
    for i in range(len(lista)):
        for j in range(i + 1, len(lista)):
            if _cruza(lista[i], lista[j]):
                problemas.append("'%s' invade '%s'"
                                 % (lista[i]["ident"], lista[j]["ident"]))

    for m in P.muros():
        vaos = sorted(m["vaos"], key=lambda v: v["c"])
        anterior = None
        for v in vaos:
            v0 = v["c"] - v["l"] * 0.5
            v1 = v["c"] + v["l"] * 0.5
            if v0 < m["a"] - 1e-6 or v1 > m["b"] + 1e-6:
                problemas.append(
                    "muro %s %.3f (%.2f..%.2f): vao em %.2f larg %.2f sai da parede"
                    % (m["eixo"], m["coord"], m["a"], m["b"], v["c"], v["l"]))
            if anterior is not None and v0 < anterior - 1e-6:
                problemas.append(
                    "muro %s %.3f: vao em %.2f encavala no anterior"
                    % (m["eixo"], m["coord"], v["c"]))
            anterior = v1

    com_porta = set()
    for m in P.muros():
        for v in m["vaos"]:
            if v["tipo"] == "porta" and v.get("sala"):
                com_porta.add(v["sala"])
    for s in P.salas():
        if s["ident"] not in com_porta:
            problemas.append("sala '%s' nao tem porta nenhuma" % s["ident"])

    # Os dois buracos tem de cair DENTRO da sala que a planta diz que eles
    # estao. Um buraco fora da sala e' uma troca de cena disparada de dentro
    # de uma parede, e isso nao aparece ate' alguem jogar.
    for b in (P.BURACO_ENTRADA, P.BURACO_SAIDA):
        m, v = P.vao_por_ident(b["ident"])
        if m is None:
            problemas.append("buraco '%s' nao esta' em muro nenhum" % b["ident"])
            continue
        ponto = P.ponto_do_vao(b["ident"], 1.20)
        dentro = P.espaco_em(*ponto) if ponto else None
        if dentro is None or dentro["ident"] != b["sala"]:
            problemas.append("buraco '%s' devia abrir em '%s' e abre em '%s'"
                             % (b["ident"], b["sala"],
                                dentro["ident"] if dentro else "nada"))

    return problemas


# --------------------------------------------------------------------------
# o teste que importa: a grade separa MESMO os dois lados do corredor?
# --------------------------------------------------------------------------

def lados_da_grade():
    """(alcanca_sem_patio, total) — quantas celulas o jogador alcanca saindo do
    patio se o portao continuar trancado.

    E' a unica conferencia desta escola que nao existe no hospital, e existe
    porque o desenho inteiro depende dela: se der pra chegar no almoxarifado
    sem passar pelo porao, o porao vira enfeite. Aqui o portao do patio entra
    como bloqueio (que e' o estado dele no comeco do jogo) e a conta e' de
    quanto sobra alcancavel.
    """
    celulas = grade_de_celulas()
    m, v = P.vao_por_ident("portao_lazer")
    meia = v["l"] * 0.5 + 0.6
    trancado = (v["c"] - meia, v["c"] + meia,
                m["coord"] - 1.6, m["coord"] + 1.6)

    abertas = {c for c in celulas
               if not (trancado[0] <= (c[0] + 0.5) <= trancado[1]
                       and trancado[2] <= (c[1] + 0.5) <= trancado[3])}
    partida = P.ponto_do_vao("portao_rua", 2.0)
    semente = (int(partida[0] // CELULA), int(partida[1] // CELULA))
    if semente not in abertas:
        return 0, len(celulas)

    vistos = {semente}
    fila = [semente]
    while fila:
        atual = fila.pop()
        for viz in _vizinhos(atual):
            if viz in abertas and viz not in vistos:
                vistos.add(viz)
                fila.append(viz)
    return len(vistos), len(celulas)


if __name__ == "__main__":
    print("== conferindo a planta ==")
    erros = conferir()
    for e in erros:
        print("  !! " + e)
    if not erros:
        print("  planta ok")

    print("== navmesh ==")
    v, p, _perdidas = malha()
    print("    %d vertices, %d poligonos" % (len(v), len(p)))

    print("== a grade separa os dois lados? ==")
    alcanca, total = lados_da_grade()
    print("    com a grade e o portao fechados: %d de %d celulas alcancaveis"
          % (alcanca, total))
    if alcanca >= total - 4:
        print("    !! NAO SEPARA — da' pra chegar no outro lado sem o porao")
    else:
        print("    separa: %d celulas so' pelo porao" % (total - alcanca))
