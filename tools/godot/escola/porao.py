"""O porao debaixo da escola: o tunel de barro, em numeros.

Este modulo NAO escreve nada. Ele descreve o tracado — por onde o tunel passa,
onde ele alarga, onde estao as duas bocas — e rasteriza isso numa grade de
celulas. Quem vira geometria e' `gerar_cena_porao.py`; quem vira desenho e'
`make_mapa_escola.py`. Os dois leem a MESMA grade, entao o mapa nao tem como
discordar do chao.

==============================================================================
POR QUE UMA GRADE DE CELULAS, E NAO CAIXAS AO LONGO DA LINHA

A primeira ideia obvia e' emitir, por trecho da polilinha, um chao, um teto e
duas paredes girados no angulo do trecho. Funciona em reta e QUEBRA em curva:
na parte de fora de cada cotovelo sobra uma cunha sem parede nenhuma, e o
jogador ve o vazio por ela. Fechar aquilo pede caixa de remendo em cada vertice,
com angulo proprio, e nunca fecha inteiro.

Rasterizar resolve na origem. O tunel vira um conjunto de celulas de 1 m; a
parede e' emitida na FRONTEIRA entre celula aberta e celula fechada. Nao existe
canto sem tratamento porque nao existe canto: existe celula. O tunel sai
estanque por construcao, em qualquer tracado, inclusive nos que se cruzam.

De quebra vem tudo o mais de graca:

  - o navmesh sai da mesma grade (erodida de uma celula);
  - o mapa do menu sai da mesma grade (uma celula = um pixel);
  - alargar um trecho e' mudar um numero de raio, nao redesenhar caixa.

O preco e' a aparencia de gaveta que uma grade de 1 m tem. Ela nao aparece
porque o tunel nao e' feito so' dela: a parede leva TORROES (caixas pequenas,
giradas, sorteadas com semente fixa) e o teto leva raiz e escora. A silhueta
irregular vem desses, e a grade fica embaixo, segurando a estanqueidade.

==============================================================================
O TRACADO

O do segundo desenho do caderno: entra em cima a' esquerda, serpenteia pra
direita, faz o gancho la' em cima, desce pra CAMARA GRANDE no meio, sai por
baixo e termina embaixo a' direita. Mais dois becos sem saida, que e' o que faz
o jogador ter de escolher — sem eles, um tunel de uma linha so' nao e' um
lugar, e' um corredor comprido.

==============================================================================
AS MEDIDAS

    pe-direito do tunel   2,60 m    (baixo de proposito: e' cavado na mao)
    pe-direito da camara  5,20 m
    largura do tunel      3,6 a 4,8 m

2,60 e' o menor pe-direito que a camera de terceira pessoa aguenta sem entrar
no teto. A largura NAO acompanha: apertar os dois faz a camera bater na parede
em toda curva, e o jogador passa o tunel inteiro olhando pra terra.
"""

import math

CELULA = 1.0

# 2,60: o menor pe-direito que a camera de terceira pessoa aguenta sem entrar
# no teto. A claustrofobia vem daqui, da altura — e nao da largura, que tem de
# seguir dando espaco pra camera ficar atras do jogador na curva.
PE_TUNEL = 2.60
PE_CAMARA = 5.20

# A camara grande — a "Area Grande" do desenho. Retangulo com os cantos
# comidos: quadrado perfeito no meio de um tunel cavado na mao denuncia o
# gerador na hora, e o desenho do caderno tambem nao tem canto reto nenhum.
CAMARA = (24.0, 36.0, 48.0, 54.0)      # x0, z0, x1, z1
CAMARA_CANTO = 5.0                     # raio comido de cada canto

# --------------------------------------------------------------------------
# A POLILINHA
#
# (x, z, raio). O raio e' a meia-largura do tunel naquele ponto, e ele varia de
# proposito: tunel de largura constante le' como cano. Onde ele aperta (1,8) o
# jogador encolhe; onde ele abre (2,4) ele respira. E' o unico ritmo que um
# corredor sem porta tem.
# --------------------------------------------------------------------------

CAMINHO = [
    (6.0, 8.0, 2.0),        # a boca de entrada, embaixo do deposito
    (16.0, 9.0, 2.2),
    (26.0, 13.0, 1.8),
    (30.0, 22.0, 2.2),
    (40.0, 25.0, 1.8),
    (52.0, 21.0, 2.0),
    (64.0, 15.0, 1.8),
    (74.0, 18.0, 2.4),      # o gancho do alto a' direita
    (78.0, 28.0, 2.0),
    (68.0, 33.0, 1.8),
    (56.0, 34.0, 2.2),
    (46.0, 38.0, 2.4),      # entra na camara
    (28.0, 52.0, 2.2),      # sai da camara pelo canto de baixo
    (16.0, 58.0, 2.0),      # o braco da esquerda
    (20.0, 68.0, 1.8),
    (34.0, 72.0, 2.2),
    (48.0, 70.0, 1.8),
    (60.0, 66.0, 2.0),
    (70.0, 70.0, 2.2),
    (78.0, 74.0, 2.0),      # a boca de saida
]

# Becos sem saida. Cada um e' uma polilinha propria que nasce grudada no
# caminho principal.
BECOS = [
    [(52.0, 21.0, 1.8), (50.0, 12.0, 1.8), (44.0, 8.0, 1.4)],
    [(60.0, 66.0, 1.8), (63.0, 57.0, 1.8), (68.0, 52.0, 1.8)],
    [(28.0, 52.0, 1.8), (14.0, 46.0, 1.6)],
]

# As duas bocas, em coordenadas de mundo do porao.
BOCA_ENTRADA = (6.0, 8.0)
BOCA_SAIDA = (78.0, 74.0)

# De que lado de cada boca fica a parede do fundo — e' a direcao em que o
# jogador esta' OLHANDO quando chega. Sai daqui pro gerador nao ter de
# adivinhar pra onde virar o jogador que acabou de cair no tunel.
OLHAR_ENTRADA = math.atan2(16.0 - 6.0, 9.0 - 8.0)
OLHAR_SAIDA = math.atan2(78.0 - 70.0, 74.0 - 70.0)


# ==========================================================================
# RASTERIZACAO
# ==========================================================================

def _dist_segmento(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    comp2 = dx * dx + dz * dz
    if comp2 < 1e-9:
        return math.hypot(px - ax, pz - az), 0.0
    t = ((px - ax) * dx + (pz - az) * dz) / comp2
    t = max(0.0, min(1.0, t))
    return math.hypot(px - (ax + dx * t), pz - (az + dz * t)), t


def _marcar_linha(celulas, linha):
    for k in range(len(linha) - 1):
        ax, az, ar = linha[k]
        bx, bz, br = linha[k + 1]
        raio = max(ar, br)
        i0 = int((min(ax, bx) - raio - 1) // CELULA)
        i1 = int((max(ax, bx) + raio + 1) // CELULA) + 1
        j0 = int((min(az, bz) - raio - 1) // CELULA)
        j1 = int((max(az, bz) + raio + 1) // CELULA) + 1
        for i in range(i0, i1):
            for j in range(j0, j1):
                cx = (i + 0.5) * CELULA
                cz = (j + 0.5) * CELULA
                d, t = _dist_segmento(cx, cz, ax, az, bx, bz)
                # raio interpolado ao longo do trecho: a mudanca de largura
                # acontece devagar, e nao num degrau no vertice
                if d <= ar + (br - ar) * t:
                    celulas.add((i, j))


def celulas_abertas():
    """O conjunto de celulas (i, j) por onde se anda."""
    celulas = set()
    _marcar_linha(celulas, CAMINHO)
    for beco in BECOS:
        _marcar_linha(celulas, beco)
    x0, z0, x1, z1 = CAMARA
    for i in range(int(x0 // CELULA), int(x1 // CELULA)):
        for j in range(int(z0 // CELULA), int(z1 // CELULA)):
            if na_camara(i, j):
                celulas.add((i, j))
    return celulas


def na_camara(i, j):
    x0, z0, x1, z1 = CAMARA
    cx, cz = (i + 0.5) * CELULA, (j + 0.5) * CELULA
    if not (x0 <= cx <= x1 and z0 <= cz <= z1):
        return False
    r = CAMARA_CANTO
    dx = max(x0 + r - cx, cx - (x1 - r), 0.0)
    dz = max(z0 + r - cz, cz - (z1 - r), 0.0)
    return dx * dx + dz * dz <= r * r


def teto_da_celula(i, j):
    return PE_CAMARA if na_camara(i, j) else PE_TUNEL


def limites(celulas):
    xs = [c[0] for c in celulas]
    zs = [c[1] for c in celulas]
    return (min(xs) * CELULA, min(zs) * CELULA,
            (max(xs) + 1) * CELULA, (max(zs) + 1) * CELULA)


# ==========================================================================
# MERGE: transformar celulas em CAIXAS
#
# Sem isto o porao sairia com uma caixa de chao e uma de teto por celula — umas
# 3.400 caixas so' de laje, 40 mil triangulos pra desenhar um chao plano. A
# juncao por corrida horizontal derruba isso pra umas 300.
# ==========================================================================

def corridas(celulas, chave=lambda i, j: 0):
    """Junta celulas vizinhas em X que tenham a mesma `chave`.

    Devolve (i0, i1, j, chave) — i1 EXCLUSIVO, como em range().
    """
    saida = []
    for j in sorted({c[1] for c in celulas}):
        fila = sorted(i for (i, jj) in celulas if jj == j)
        k = 0
        while k < len(fila):
            i0 = fila[k]
            k_chave = chave(i0, j)
            m = k
            while (m + 1 < len(fila) and fila[m + 1] == fila[m] + 1
                   and chave(fila[m + 1], j) == k_chave):
                m += 1
            saida.append((i0, fila[m] + 1, j, k_chave))
            k = m + 1
    return saida


def faces_de_parede(celulas):
    """As fronteiras entre celula aberta e celula fechada, ja' juntadas.

    Devolve (eixo, coord, a0, a1, teto, sentido):

      eixo "x" -> a parede corre em X, no plano z = coord
      eixo "z" -> a parede corre em Z, no plano x = coord

    `sentido` diz de que lado do plano esta' a TERRA: +1 = coordenada maior,
    -1 = menor. Ele existe porque a parede tem espessura e ela toda tem de
    crescer pra fora — engrossada pros dois lados, ela comeria meio metro do
    tunel em toda fronteira, e um corredor de 3,6 m viraria um de 2,6.

    `teto` e' a maior altura das celulas abertas encostadas nela: uma parede
    entre o tunel e a camara tem de subir ate' o teto da camara, senao abre
    uma fresta de 2,5 m em cima dela.
    """
    # (linha, indice) -> (altura, sentido)
    lado_x = {}      # paredes perpendiculares a Z (correm em X)
    lado_z = {}

    def por(tabela, chave, h, sentido):
        velho = tabela.get(chave)
        tabela[chave] = (max(velho[0], h) if velho else h, sentido)

    for (i, j) in celulas:
        h = teto_da_celula(i, j)
        if (i, j - 1) not in celulas:
            por(lado_x, (j, i), h, -1)
        if (i, j + 1) not in celulas:
            por(lado_x, (j + 1, i), h, +1)
        if (i - 1, j) not in celulas:
            por(lado_z, (i, j), h, -1)
        if (i + 1, j) not in celulas:
            por(lado_z, (i + 1, j), h, +1)

    saida = []
    for (eixo, tabela) in (("x", lado_x), ("z", lado_z)):
        for linha in sorted({k[0] for k in tabela}):
            fila = sorted(k[1] for k in tabela if k[0] == linha)
            k = 0
            while k < len(fila):
                a0 = fila[k]
                h, sentido = tabela[(linha, fila[k])]
                m = k
                while m + 1 < len(fila) and fila[m + 1] == fila[m] + 1:
                    prox = tabela[(linha, fila[m + 1])]
                    if abs(prox[0] - h) > 1e-6 or prox[1] != sentido:
                        break
                    m += 1
                saida.append((eixo, linha * CELULA, a0 * CELULA,
                              (fila[m] + 1) * CELULA, h, sentido))
                k = m + 1
    return saida


# ==========================================================================
# NAVMESH
# ==========================================================================

def celulas_navegaveis(celulas):
    """Erode uma celula: so' fica quem tem os quatro vizinhos abertos.

    E' o equivalente ao RECUO de 0,75 m do navmesh da escola — caminho colado
    na parede vira inimigo raspando parede, porque ele persegue pelo navmesh e
    colide pela capsula. Aqui a erosao de uma celula ja' da' 1 m de folga.
    """
    return {(i, j) for (i, j) in celulas
            if (i + 1, j) in celulas and (i - 1, j) in celulas
            and (i, j + 1) in celulas and (i, j - 1) in celulas}


def ilhas(celulas):
    restam = set(celulas)
    saida = []
    while restam:
        semente = restam.pop()
        ilha = {semente}
        fila = [semente]
        while fila:
            i, j = fila.pop()
            for viz in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
                if viz in restam:
                    restam.discard(viz)
                    ilha.add(viz)
                    fila.append(viz)
        saida.append(ilha)
    saida.sort(key=len, reverse=True)
    return saida


def conferir():
    """O tunel e' uma peca so', e da' pra ir de uma boca a' outra?"""
    problemas = []
    abertas = celulas_abertas()
    partes = ilhas(abertas)
    if len(partes) > 1:
        problemas.append("o tunel esta' em %d pedacos soltos (%s celulas)"
                         % (len(partes), ", ".join(str(len(p)) for p in partes)))

    nav = celulas_navegaveis(abertas)
    partes_nav = ilhas(nav)
    if len(partes_nav) > 1:
        # Isto e' o defeito mais chato desta cena: o tunel PARECE inteiro e o
        # inimigo nao atravessa, porque a erosao cortou a malha num aperto.
        for extra in partes_nav[1:]:
            algum = next(iter(extra))
            problemas.append(
                "navmesh partido: ilha de %d celula(s) perto de x=%.1f z=%.1f "
                "— algum trecho ficou estreito demais"
                % (len(extra), algum[0] + 0.5, algum[1] + 0.5))

    for nome, (x, z) in (("entrada", BOCA_ENTRADA), ("saida", BOCA_SAIDA)):
        if (int(x // CELULA), int(z // CELULA)) not in abertas:
            problemas.append("a boca de %s caiu fora do tunel" % nome)
    return problemas


if __name__ == "__main__":
    abertas = celulas_abertas()
    x0, z0, x1, z1 = limites(abertas)
    print("== porao ==")
    print("  %d celulas abertas (%.0f m2)" % (len(abertas), len(abertas)))
    print("  recorte x %.0f..%.0f  z %.0f..%.0f" % (x0, x1, z0, z1))
    print("  %d corridas de chao" % len(corridas(abertas)))
    print("  %d faces de parede" % len(faces_de_parede(abertas)))
    print("  %d celulas navegaveis" % len(celulas_navegaveis(abertas)))
    erros = conferir()
    for e in erros:
        print("  !! " + e)
    if not erros:
        print("  tracado ok")
