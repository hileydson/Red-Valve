"""Pichacao, cartaz e mancha na escola — e no porao.

Escolha o lugar aqui; quem emite o quad e' o gerador da cena.

==============================================================================
POR QUE ESTE ARQUIVO REAPROVEITA O ATLAS DA CIDADE

Ja' existe um catalogo de rabisco pronto no projeto:
`assets/images/textures/pichacao/`, gerado por `tools/texturas/gerar_pichacao.py`
e usado pela etapa 09 da cidade. Sao 29 artes num atlas so' — tag, bomba,
simbolo, cartaz rasgado, escorrido de ferrugem, mancha de limo.

E' o mesmo mundo e a mesma gente: as faccoes que pixam o muro da rua sao as que
pixam a escola. Fazer um segundo catalogo aqui seria inventar uma segunda
cidade — e, na pratica, seria mais 2 MB de textura pra dizer a mesma coisa.

==============================================================================
COMO O RABISCO CHEGA NA CENA, E POR QUE NAO E' UM MultiMesh

A cidade usa MultiMesh + shader proprio, e ela precisa: sao 900 rabiscos
espalhados por 680 m de mapa, e sem instanciar seriam centenas de chamadas de
desenho.

Aqui sao ~150, dentro de um predio. Cada um vira um `MeshInstance3D` com um
`QuadMesh` e um `StandardMaterial3D` que aponta pro atlas com `uv1_offset` e
`uv1_scale` — que e' exatamente a mesma conta do shader da cidade
(`recorte.xy + UV * recorte.zw`), so' que feita pelo material padrao. Como o
material e' por ARTE e nao por rabisco, 150 quads dividem ~20 materiais.

Duas armadilhas ja' pagas na cidade, e que valem aqui do mesmo jeito:

  - `cull_mode` TEM de ser 2 (desabilitado). O `QuadMesh` com `orientation =
    FACE_Z` nao encara o +Z local, e com culling de costas o quad some sem
    erro nenhum em log. Desabilitado tambem resolve a normal: o shader padrao
    do Godot inverte a normal na face de tras sozinho, entao o rabisco fica
    iluminado seja qual for o lado que aparecer.
  - MISTURA, nao alpha scissor. O traco do spray tem 3-4 px no atlas; o mipmap
    dilui isso e o corte engoliria o desenho inteiro a partir de uns 20 m.

==============================================================================
ONDE O RABISCO NASCE

Rabisco vive de ser visto, entao ele so' nasce em parede que da' pra um espaco
onde se anda, e nunca em cima de porta, janela ou buraco. A sondagem e' a mesma
que o gerador usa pra decidir a cor da parede: espeta um ponto 30 cm adentro e
pergunta a' planta que comodo e' aquele.

A densidade muda por comodo, e isso e' o desenho do lugar, nao acaso:

  - CORREDOR e PATIO levam quase tudo. Sao os lugares por onde passou gente
    depois que a escola fechou.
  - SALA DE AULA leva pouco, e o pouco fica perto da porta.
  - SECRETARIA e BIBLIOTECA quase nao levam: elas ficaram trancadas.
  - O PORAO nao leva pichacao NENHUMA — quem pixa quer plateia, e ninguem
    passa ali. La' so' vao manchas de umidade.
"""

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import planta as P

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
MANIFESTO = os.path.join(RAIZ, "red-valve", "assets", "images", "textures",
                         "pichacao", "pichacao.json")

RES_ATLAS = {
    "parede": "res://assets/images/textures/pichacao/pichacao_parede.png",
    "chao": "res://assets/images/textures/pichacao/pichacao_chao.png",
}

# Quanto o quad descola da superficie. Menos que isto briga com a parede
# (z-fighting); mais e o rabisco flutua e a sombra denuncia.
AFASTAMENTO = 0.05
AFASTAMENTO_CHAO = 0.03

# Passo da varredura ao longo de cada muro, em metros.
PASSO = 2.6

# Chance de sair rabisco em cada ponto sondado, por tipo de comodo.
DENSIDADE = {
    "corredor": 0.62,
    "patio": 0.70,
    "deposito": 0.34,
    "almoxarifado": 0.34,
    "refeitorio": 0.30,
    "laboratorio": 0.22,
    "sala_aula": 0.16,
    "biblioteca": 0.08,
    "secretaria": 0.08,
}

# Que papeis cada comodo aceita, e com que peso. "alto" e' a peca grande, que
# so' cabe em pe-direito livre: dentro de sala ela passa por cima do armario.
PAPEIS = {
    "corredor": (("pichacao", 6), ("mancha_parede", 4), ("cartaz", 3),
                 ("alto", 2)),
    "patio": (("pichacao", 8), ("alto", 5), ("mancha_parede", 3)),
    "sala_aula": (("pichacao", 5), ("mancha_parede", 4), ("cartaz", 2)),
    "_padrao": (("mancha_parede", 6), ("pichacao", 3), ("cartaz", 2)),
}

# Faixa de altura do CENTRO do rabisco, por papel.
ALTURA = {
    "pichacao": (1.05, 2.05),
    "cartaz": (1.35, 1.85),
    "mancha_parede": (1.20, 2.60),
    "alto": (2.40, 3.80),
}


def _artes():
    with open(MANIFESTO, encoding="utf-8") as fp:
        return json.load(fp)["artes"]


def _por_papel(artes):
    saida = {}
    for a in artes:
        saida.setdefault(a["papel"], []).append(a)
    return saida


def _sortear(d, itens):
    """Sorteio com peso — `itens` e' [(coisa, peso), ...]."""
    total = sum(p for (_c, p) in itens)
    n = d.uniform(0.0, total)
    for (coisa, peso) in itens:
        n -= peso
        if n <= 0.0:
            return coisa
    return itens[-1][0]


def _livre_de_vao(m, c, meia):
    """Tem vao (porta, janela, buraco) neste trecho do muro?"""
    for v in m["vaos"]:
        if abs(v["c"] - c) < v["l"] * 0.5 + meia + 0.35:
            return False
    return True


def montar():
    """[{atlas, uv, x, y, z, giro, largura, altura, desbotado}, ...]

    `giro` e' a rotacao em Y do quad; ele nasce no plano XY local, entao giro
    0 serve pra muro que corre em X e PI/2 pra muro que corre em Z.
    """
    d = random.Random("escola/pichacao")
    por_papel = _por_papel(_artes())
    saida = []

    for m in P.muros():
        comprimento = m["b"] - m["a"]
        if comprimento < PASSO:
            continue
        passos = max(int(comprimento / PASSO), 1)
        for k in range(passos):
            c = m["a"] + comprimento * (k + 0.5) / passos
            for lado in (-1.0, 1.0):
                fora = m["esp"] * 0.5 + 0.30
                if m["eixo"] == "x":
                    px, pz = c, m["coord"] + lado * fora
                else:
                    px, pz = m["coord"] + lado * fora, c
                espaco = P.espaco_em(px, pz)
                if espaco is None:
                    continue
                tipo = espaco["tipo"]
                if d.random() > DENSIDADE.get(tipo, 0.12):
                    continue
                papel = _sortear(d, PAPEIS.get(tipo, PAPEIS["_padrao"]))
                lista = por_papel.get(papel)
                if not lista:
                    continue
                arte = _sortear(d, [(a, a["peso"]) for a in lista])
                larg = d.uniform(*arte["largura"])
                alt = larg * arte["px"][1] / float(arte["px"][0])
                if not _livre_de_vao(m, c, larg * 0.5):
                    continue
                y0, y1 = ALTURA[papel]
                # "alto" so' cabe onde o pe-direito e' livre: dentro de sala o
                # forro esta' em 3,50 e a peca de 2 m de altura sairia por ele
                topo = (P.PATIO_MURO_ALTO if tipo == "patio" else P.PE) - 0.25
                y = min(d.uniform(y0, y1), topo - alt * 0.5)
                if y - alt * 0.5 < 0.08:
                    continue
                desloc = m["esp"] * 0.5 + AFASTAMENTO
                if m["eixo"] == "x":
                    x, z, giro = c, m["coord"] + lado * desloc, 0.0
                else:
                    x, z, giro = m["coord"] + lado * desloc, c, math.pi * 0.5
                saida.append({
                    "atlas": arte["atlas"], "uv": arte["uv"],
                    "arte": arte["n"], "x": x, "y": P.cota() + y, "z": z,
                    "giro": giro, "largura": larg, "altura": alt,
                    "desbotado": d.uniform(0.55, 1.0), "chao": False})

    saida.extend(_manchas_de_chao(d, por_papel))
    return saida


def _manchas_de_chao(d, por_papel):
    """Limo e terra no piso dos corredores e do patio.

    So' nesses dois: e' onde entra agua de chuva pela janela quebrada e pela
    abertura do patio. Mancha de limo no meio de uma sala de aula fechada nao
    faz sentido nenhum, e mancha em todo lugar vira textura, nao mancha.
    """
    lista = por_papel.get("mancha_chao", [])
    if not lista:
        return []
    saida = []
    for e in P.espacos():
        if e["tipo"] not in ("corredor", "patio"):
            continue
        area = (e["x1"] - e["x0"]) * (e["z1"] - e["z0"])
        # Teto de 14 por espaco. Sem ele o patio sozinho (1.620 m2) levava 62
        # manchas e o piso dele deixava de ser piso manchado pra virar piso de
        # mancha — que e' textura, nao sujeira.
        quantas = min(int(area / 70.0), 14)
        for i in range(quantas):
            arte = _sortear(d, [(a, a["peso"]) for a in lista])
            larg = d.uniform(*arte["largura"])
            alt = larg * arte["px"][1] / float(arte["px"][0])
            x = d.uniform(e["x0"] + larg * 0.5, e["x1"] - larg * 0.5)
            z = d.uniform(e["z0"] + alt * 0.5, e["z1"] - alt * 0.5)
            saida.append({
                "atlas": arte["atlas"], "uv": arte["uv"], "arte": arte["n"],
                "x": x, "y": P.cota() + AFASTAMENTO_CHAO, "z": z,
                "giro": d.uniform(0.0, 6.28), "largura": larg, "altura": alt,
                "desbotado": d.uniform(0.5, 0.9), "chao": True})
    return saida


def montar_porao(celulas, celula_m, teto_de):
    """Manchas de umidade nas paredes do tunel — e nada mais.

    Sem pichacao nenhuma la' embaixo, de proposito: quem pixa quer ser visto, e
    o tunel foi cavado as escondidas. O que existe e' escorrido de agua, e ele
    tambem serve de marca de caminho — e' a unica coisa que difere uma curva de
    terra da curva de terra seguinte.
    """
    d = random.Random("escola/porao/mancha")
    lista = _por_papel(_artes()).get("mancha_parede", [])
    if not lista:
        return []
    saida = []
    for (i, j) in sorted(celulas):
        for (vx, vz) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (i + vx, j + vz) in celulas:
                continue
            if d.random() > 0.07:
                continue
            arte = _sortear(d, [(a, a["peso"]) for a in lista])
            larg = d.uniform(arte["largura"][0], arte["largura"][1]) * 0.8
            alt = larg * arte["px"][1] / float(arte["px"][0])
            teto = teto_de(i, j)
            alt = min(alt, teto - 0.5)
            larg = alt * arte["px"][0] / float(arte["px"][1])
            y = d.uniform(alt * 0.5 + 0.15, teto - alt * 0.5 - 0.15)
            # o quad encosta na face da celula, deslocado pro lado aberto
            x = (i + 0.5 + vx * (0.5 - AFASTAMENTO)) * celula_m
            z = (j + 0.5 + vz * (0.5 - AFASTAMENTO)) * celula_m
            saida.append({
                "atlas": arte["atlas"], "uv": arte["uv"], "arte": arte["n"],
                "x": x, "y": y, "z": z,
                "giro": 0.0 if vz else math.pi * 0.5,
                "largura": larg, "altura": alt,
                "desbotado": d.uniform(0.35, 0.7), "chao": False})
    return saida


if __name__ == "__main__":
    tudo = montar()
    print("escola: %d rabiscos" % len(tudo))
    por_arte = {}
    for r in tudo:
        por_arte[r["arte"]] = por_arte.get(r["arte"], 0) + 1
    print("  %d artes distintas, %d no chao"
          % (len(por_arte), sum(1 for r in tudo if r["chao"])))
