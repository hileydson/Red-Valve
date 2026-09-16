"""Monta o porao: geometria (.gltf) + cena (.tscn).

    python3 tools/godot/escola/gerar_cena_porao.py

Sai:
    red-valve/assets/3d_model/stages/escola/porao_estrutura.gltf (+ .bin)
    red-valve/assets/3d_model/stages/escola/pecas_porao/*.gltf
    red-valve/scenes/stages/escola/porao.tscn

==============================================================================
COMO O TUNEL VIRA CAIXA

O tracado esta' rasterizado numa grade de 1 m (ver `porao.py`). Daqui saem
quatro coisas, todas da MESMA grade:

    chao      uma caixa por corrida horizontal de celulas
    teto      idem, mas a altura muda entre tunel e camara
    parede    uma caixa por fronteira aberta/fechada, crescendo PRA FORA
    navmesh   a grade erodida de uma celula

Nada disso tem angulo: sao todas caixas alinhadas ao eixo. E' de proposito —
caixa girada ao longo de uma polilinha deixa cunha aberta em todo cotovelo, e
o jogador enxerga o vazio por ela.

==============================================================================
O QUE TIRA A CARA DE GAVETA

Grade de 1 m, sozinha, parece armario. Tres passadas desmancham isso, e
nenhuma delas mexe na estanqueidade — todas sao geometria SOLTA, por cima:

  1. TORROES: caixas pequenas e giradas pendudardas na parede, avancando de 15
     a 40 cm. Elas quebram a linha reta da fronteira, que e' o que denuncia a
     grade.
  2. RAIZES: fiapos escuros descendo do teto. Alem de quebrarem o plano do
     forro, dao ESCALA — o olho mede a altura do tunel por elas.
  3. ESCORAS: quadro de tabua (dois montantes e uma verga) a cada tantos
     metros. Elas dizem que alguem CAVOU isto, e dao ritmo ao caminho: sem
     elas nao ha' como perceber que se andou 40 m.

==============================================================================
A LUZ

O pedido foi explicito: aqui e' mais escuro, e a lanterna tem de ser
necessaria. Entao a `ambient_light_energy` desta cena e' 0,42 — a escola usa
1,75. Sao as lampadas do teto que marcam o caminho, e nao que o iluminam.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import comum as C
import gltf
import luzes as L
import materiais as M
import mobilia as MOB
import pichacao as PICH
import porao as PO

SAIDA_CENA = os.path.join(C.BASE, "scenes", "stages", "escola", "porao.tscn")
DIR_PECAS = os.path.join(C.DIR_MODELO, "pecas_porao")

ESP_PAREDE = 0.80       # espessura da terra em volta do tunel
ESP_LAJE = 0.60         # espessura do chao e do teto
NAV_Y = 0.06


# ==========================================================================
# ESTRUTURA
# ==========================================================================

def montar_estrutura(tamanho, celulas):
    cena = gltf.Cena("../../../images/textures/polyhaven")
    M.registrar(cena, [M.PORAO, M.LUMINARIAS])
    setores = C.Setores(cena, tamanho, prefixo="por")
    colisoes = []
    colisoes += emitir_chao(setores, celulas)
    colisoes += emitir_teto(setores, celulas)
    colisoes += emitir_paredes(setores, celulas)
    emitir_torroes(setores, celulas)
    emitir_raizes(setores, celulas)
    emitir_escoras(setores, celulas)
    colisoes += emitir_bocas(setores)
    return cena, colisoes


def emitir_chao(setores, celulas):
    colisoes = []
    for (i0, i1, j, _k) in PO.corridas(celulas):
        x0, x1 = i0 * PO.CELULA, i1 * PO.CELULA
        z0, z1 = j * PO.CELULA, (j + 1) * PO.CELULA
        setores.caixa("po_chao", x0, x1, -ESP_LAJE, 0.0, z0, z1, 3.0)
        colisoes.append((x0, x1, -0.45, 0.0, z0, z1))
    return colisoes


def emitir_teto(setores, celulas):
    """Uma corrida por ALTURA: tunel e camara tem tetos diferentes, e juntar
    os dois numa caixa so' deixaria a camara com forro de 2,60."""
    colisoes = []
    for (i0, i1, j, teto) in PO.corridas(celulas, chave=PO.teto_da_celula):
        x0, x1 = i0 * PO.CELULA, i1 * PO.CELULA
        z0, z1 = j * PO.CELULA, (j + 1) * PO.CELULA
        setores.caixa("po_teto", x0, x1, teto, teto + ESP_LAJE, z0, z1, 3.4)
        colisoes.append((x0, x1, teto, teto + 0.45, z0, z1))
    return colisoes


def emitir_paredes(setores, celulas):
    """A terra em volta. Cresce sempre PRA FORA do tunel (ver `sentido`).

    Ela desce ate' abaixo do chao e sobe ate' acima do teto de proposito: e'
    essa sobreposicao que faz a juncao com a laje nao ter fresta nenhuma, sem
    precisar de nenhuma caixa de remendo de canto.
    """
    colisoes = []
    d = random.Random("escola/porao/parede")
    for (eixo, coord, a0, a1, teto, sentido) in PO.faces_de_parede(celulas):
        # espessura sorteada: parede de espessura constante volta a desenhar a
        # grade quando duas fronteiras vizinhas ficam paralelas
        esp = ESP_PAREDE * d.uniform(0.85, 1.6)
        c0, c1 = sorted((coord, coord + sentido * esp))
        mat = "po_pedra" if d.random() < 0.18 else "po_terra"
        if eixo == "x":
            setores.caixa(mat, a0, a1, -ESP_LAJE, teto + ESP_LAJE, c0, c1, 2.6)
            colisoes.append((a0, a1, -0.45, teto + 0.45, c0, c1))
        else:
            setores.caixa(mat, c0, c1, -ESP_LAJE, teto + ESP_LAJE, a0, a1, 2.6)
            colisoes.append((c0, c1, -0.45, teto + 0.45, a0, a1))
    return colisoes


def emitir_torroes(setores, celulas):
    """Caixas pequenas saindo da parede pro tunel. Sem colisao: elas avancam
    no maximo 40 cm, e colisor de 40 cm no meio de um corredor de 3,6 m e'
    exatamente o tipo de tranco que o pedido mandou nao ter."""
    d = random.Random("escola/porao/torrao")
    for (eixo, coord, a0, a1, teto, sentido) in PO.faces_de_parede(celulas):
        quantos = int((a1 - a0) * 0.55)
        for _k in range(quantos):
            if d.random() > 0.55:
                continue
            t = d.uniform(a0, a1)
            avanco = d.uniform(0.15, 0.40)
            largura = d.uniform(0.5, 1.5)
            altura = d.uniform(0.35, min(1.3, teto - 0.3))
            y = d.uniform(0.1, teto - altura - 0.1)
            mat = "po_pedra" if d.random() < 0.30 else "po_cascalho"
            c0, c1 = sorted((coord, coord - sentido * avanco))
            if eixo == "x":
                setores.caixa(mat, t - largura * 0.5, t + largura * 0.5,
                              y, y + altura, c0, c1, 1.4)
            else:
                setores.caixa(mat, c0, c1, y, y + altura,
                              t - largura * 0.5, t + largura * 0.5, 1.4)


def emitir_raizes(setores, celulas):
    """Fiapos descendo do teto. Sao o que da' ESCALA ao tunel: sem nada
    pendurado, uma galeria de 2,60 e uma de 5 m parecem a mesma coisa."""
    d = random.Random("escola/porao/raiz")
    for (i, j) in sorted(celulas):
        if d.random() > 0.10:
            continue
        teto = PO.teto_da_celula(i, j)
        x = (i + d.uniform(0.2, 0.8)) * PO.CELULA
        z = (j + d.uniform(0.2, 0.8)) * PO.CELULA
        comp = d.uniform(0.25, min(1.1, teto * 0.4))
        larg = d.uniform(0.03, 0.08)
        setores.caixa("po_raiz", x - larg, x + larg, teto - comp, teto,
                      z - larg, z + larg, 0.6)


def emitir_escoras(setores, celulas):
    """Quadros de tabua a cada tantos metros do caminho principal.

    Nao e' so' enfeite: um tunel de terra sem marco nenhum e' impossivel de
    medir andando. Cada escora que passa e' uma conta a mais no caminho, e e'
    o que impede o trecho do meio de parecer infinito.
    """
    passo = 9.0
    total = 0.0
    for k in range(len(PO.CAMINHO) - 1):
        ax, az, _ = PO.CAMINHO[k]
        bx, bz, _ = PO.CAMINHO[k + 1]
        comp = math.hypot(bx - ax, bz - az)
        n = int(comp / passo)
        for i in range(n):
            t = (i + 0.5) / max(n, 1)
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            ci, cj = int(x // PO.CELULA), int(z // PO.CELULA)
            if (ci, cj) not in celulas or PO.na_camara(ci, cj):
                continue
            teto = PO.teto_da_celula(ci, cj)
            # o quadro acompanha a direcao do trecho, encaixado no eixo mais
            # proximo — tabua girada em angulo qualquer atravessaria a parede
            if abs(bx - ax) >= abs(bz - az):
                meia = 1.9
                for dz in (-meia, meia):
                    setores.caixa("po_tabua", x - 0.10, x + 0.10, 0.0,
                                  teto - 0.12, z + dz - 0.10, z + dz + 0.10, 1.0)
                setores.caixa("po_tabua", x - 0.12, x + 0.12, teto - 0.24,
                              teto - 0.06, z - meia - 0.1, z + meia + 0.1, 1.0)
            else:
                meia = 1.9
                for dx in (-meia, meia):
                    setores.caixa("po_tabua", x + dx - 0.10, x + dx + 0.10,
                                  0.0, teto - 0.12, z - 0.10, z + 0.10, 1.0)
                setores.caixa("po_tabua", x - meia - 0.1, x + meia + 0.1,
                              teto - 0.24, teto - 0.06, z - 0.12, z + 0.12, 1.0)
            total += 1
    return total


def emitir_bocas(setores):
    """As duas bocas: rampas de terra subindo pra fora do tunel.

    Elas terminam em painel preto e colisao. O jogador nao sobe por ali — quem
    o tira daqui e' o prompt. A rampa existe pra o buraco ter PARA ONDE ir:
    sem ela, as duas pontas do porao sao parede lisa, e o prompt "subir pra
    escola" apareceria em frente a um monte de terra.
    """
    colisoes = []
    for (nome, (x, z), direcao) in (
            ("entrada", PO.BOCA_ENTRADA, (-1.0, 0.0)),
            ("saida", PO.BOCA_SAIDA, (1.0, 0.0))):
        dx, dz = direcao
        for k in range(6):
            t0, t1 = k * 0.8, (k + 1) * 0.8
            y = 0.20 * k
            ax0, ax1 = sorted((x + dx * t0, x + dx * t1))
            az0, az1 = sorted((z + dz * t0, z + dz * t1))
            if dx:
                az0, az1 = z - 1.4, z + 1.4
            else:
                ax0, ax1 = x - 1.4, x + 1.4
            setores.caixa("po_cascalho", ax0, ax1, y - 0.5, y, az0, az1, 2.0)
            colisoes.append((ax0, ax1, y - 0.5, y, az0, az1))
        fim = (x + dx * 5.0, z + dz * 5.0)
        setores.caixa("po_escuro", fim[0] - 1.6, fim[0] + 1.6, 0.8, 3.6,
                      fim[1] - 1.6, fim[1] + 1.6, 2.0)
        colisoes.append((fim[0] - 1.6, fim[0] + 1.6, 0.0, 4.0,
                         fim[1] - 1.6, fim[1] + 1.6))
    return colisoes


# ==========================================================================
# PECAS
# ==========================================================================

def pecas_do_bulbo(lum):
    """Lampada pelada no fio. O fio e' o que a faz parecer improvisada."""
    queda = lum["queda"]
    aceso = "lum_bulbo" if lum["acesa"] else "lum_bulbo_morto"
    return [(0.0, -queda * 0.5, 0.0, 0.012, queda, 0.012, "lum_fio"),
            (0.0, -queda + 0.05, 0.0, 0.10, 0.10, 0.10, aceso),
            (0.0, -queda + 0.13, 0.0, 0.05, 0.07, 0.05, "po_ferro")]


# ==========================================================================
# NAVMESH
# ==========================================================================

def navmesh(celulas):
    nav = PO.celulas_navegaveis(celulas)
    ilhas = PO.ilhas(nav)
    boas = ilhas[0] if ilhas else set()
    indice = {}
    vertices = []

    def vid(i, j):
        if (i, j) not in indice:
            indice[(i, j)] = len(vertices)
            vertices.append((i * PO.CELULA, NAV_Y, j * PO.CELULA))
        return indice[(i, j)]

    poligonos = [[vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)]
                 for (i, j) in sorted(boas)]
    return vertices, poligonos, ilhas[1:]


# ==========================================================================
# GERACAO
# ==========================================================================

def gerar():
    erros = PO.conferir()
    for e in erros:
        print("  !! " + e)

    celulas = PO.celulas_abertas()
    print("== tunel ==")
    print("  %d celulas (%d m2)" % (len(celulas), len(celulas)))

    print("== luzes ==")
    plano = L.montar_porao()
    todas_luzes = L.so_luzes(plano)
    lista_luminarias = L.luminarias(plano)
    print("  %d lampadas (%d acesas)"
          % (len(lista_luminarias), len(todas_luzes)))

    print("== estrutura ==")
    melhor = None
    for tamanho in (24.0, 20.0, 16.0, 12.0, 10.0):
        cena, colisoes = montar_estrutura(tamanho, celulas)
        o, s, onde = C.contar_luzes(cena, todas_luzes)
        print("  setor de %.0f m: pior malha ve %d omni e %d spot (%s)"
              % (tamanho, o, s, onde))
        melhor = (tamanho, cena, colisoes)
        if o <= C.LIMITE_LUZ and s <= C.LIMITE_LUZ:
            break
    tamanho, cena, colisoes = melhor
    print("  setor escolhido: %.0f m" % tamanho)
    os.makedirs(C.DIR_MODELO, exist_ok=True)
    tris = cena.salvar(os.path.join(C.DIR_MODELO, "porao_estrutura.gltf"))
    vivos = [o for o in cena.objetos if not o.vazio()]
    print("  %d objetos de setor, %d triangulos, %d caixas de colisao"
          % (len(vivos), tris, len(colisoes)))

    print("== entulho ==")
    props = MOB.mobiliar_porao()
    pecas = C.Pecas(DIR_PECAS)
    for lum in lista_luminarias:
        lum["arquivo"] = pecas.registrar("bulbo", pecas_do_bulbo(lum))
    pecas.escrever([M.PORAO, M.LUMINARIAS])
    print("  %d pecas, %d geometrias de lampada"
          % (len(props), len(pecas.arquivos)))

    print("== manchas ==")
    rabiscos = PICH.montar_porao(celulas, PO.CELULA, PO.teto_da_celula)
    for r in rabiscos:
        r["_res_atlas"] = PICH.RES_ATLAS[r["atlas"]]
    print("  %d manchas de umidade" % len(rabiscos))

    print("== navmesh ==")
    nav = navmesh(celulas)
    print("  %d vertices, %d poligonos, %d ilha(s) descartada(s)"
          % (len(nav[0]), len(nav[1]), len(nav[2])))

    print("== cena ==")
    escrever_cena(colisoes, props, plano, lista_luminarias, nav, rabiscos)
    print("  gravado: %s" % SAIDA_CENA)


def escrever_cena(colisoes, props, plano, lista_luminarias, nav, rabiscos):
    c = C.Cena()

    id_player = c.externo("PackedScene", "res://scenes/player/player.tscn")
    id_pause = c.externo("PackedScene", "res://scenes/configs/pause.tscn")
    id_fade = c.externo("PackedScene", "res://scenes/configs/fade.tscn")
    id_minimapa = c.externo("PackedScene", "res://scenes/ui/minimap_porao.tscn")
    id_script = c.externo("Script", "res://scripts/stages/escola/porao.gd")
    id_buraco_gd = c.externo("Script", "res://scripts/stages/escola/buraco.gd")
    id_estrutura = c.externo("PackedScene",
                             C.RES_MODELO + "/porao_estrutura.gltf")
    id_ambiente = c.externo(
        "AudioStream", "res://assets/sounds/episodios/ambiente_noise_sublime.mp3")

    _ambiente(c)
    _navmesh(c, nav)
    _poeira(c)

    c.no("porao", tipo="Node3D",
         props=[("script", 'ExtResource("%s")' % id_script)])
    c.no("WorldEnvironment", tipo="WorldEnvironment", pai=".",
         props=[("environment", 'SubResource("ambiente")')])
    c.no("Pause", pai=".", instancia=id_pause)
    c.no("fade", pai=".", instancia=id_fade)
    c.no("minimapa", pai=".", instancia=id_minimapa)

    pos, giro = _ponto_de_entrada()
    c.no("Player", pai=".", instancia=id_player,
         props=[("transform", C.transform_pos(pos, giro))])

    c.no("estrutura", pai=".", instancia=id_estrutura)
    C.emitir_colisoes(c, colisoes)

    # ---- entulho
    c.no("entulho", tipo="Node3D", pai=".")
    c.no("colisao_entulho", tipo="StaticBody3D", pai=".",
         props=[("collision_layer", "2"), ("collision_mask", "0")])
    for (i, p) in enumerate(props):
        c.no(p["nome"], pai="entulho",
             instancia=c.externo("PackedScene", MOB.caminho(p["modelo"])),
             props=[("transform", C.transform_pos((p["x"], p["y"], p["z"]),
                                                  p["giro"], p["escala"]))])
        lx, lz = p["bloqueia"]
        ident = c.forma(lx, 1.2, lz)
        c.no("ce%d" % i, tipo="CollisionShape3D", pai="colisao_entulho",
             props=[("transform", C.transform_pos((p["x"], 0.6, p["z"]))),
                    ("shape", 'SubResource("%s")' % ident)])

    # ---- lampadas
    c.no("luminarias", tipo="Node3D", pai=".")
    for (i, lum) in enumerate(lista_luminarias):
        c.no("bulbo_%d" % i, pai="luminarias", instancia=c.peca_em(
            "pecas_porao", lum["arquivo"]),
            props=[("transform", C.transform_pos(lum["pos"]))])

    c.no("luzes", tipo="Node3D", pai=".")
    for luz in L.so_luzes(plano):
        metas = [("piscar", '"%s"' % luz["piscar"])] if luz["piscar"] else []
        c.no(luz["nome"], tipo="OmniLight3D", pai="luzes",
             props=[("transform", C.transform_pos(luz["pos"])),
                    ("light_color", C.cor(luz["cor"])),
                    ("light_energy", "%.3f" % luz["energia"]),
                    ("light_volumetric_fog_energy", "%.2f" % luz["fog"]),
                    ("shadow_enabled", "false"),
                    ("omni_range", "%.2f" % luz["alcance"]),
                    ("omni_attenuation", "1.5"),
                    ("distance_fade_enabled", "true"),
                    ("distance_fade_begin", "22.0"),
                    ("distance_fade_length", "8.0")],
             metas=metas)

    # ---- as duas bocas
    for (papel, (x, z), olhar) in (
            ("boca_entrada", PO.BOCA_ENTRADA, math.pi * 0.5),
            ("boca_saida", PO.BOCA_SAIDA, -math.pi * 0.5)):
        c.no(papel, tipo="Node3D", pai=".",
             props=[("transform", C.transform_pos((x, 0.0, z), olhar)),
                    ("script", 'ExtResource("%s")' % id_buraco_gd)],
             metas=[("papel", '"%s"' % papel)])
        ident = c.forma(4.0, 2.4, 4.0)
        c.no("area", tipo="Area3D", pai=papel,
             props=[("transform", C.transform_pos((0.0, 1.2, 0.0))),
                    ("collision_layer", "0"), ("monitorable", "false")])
        c.no("forma", tipo="CollisionShape3D", pai=papel + "/area",
             props=[("shape", 'SubResource("%s")' % ident)])

    # Os dois pontos de chegada. Sao dois porque o tunel e' de MAO DUPLA: da'
    # pra descer pelo buraco do deposito e da' pra descer de volta pelo do
    # almoxarifado. Tunel de mao unica viraria armadilha — quem entrasse sem
    # lanterna ficaria preso no escuro sem poder voltar.
    c.no("chegada_entrada", tipo="Marker3D", pai=".",
         props=[("transform", C.transform_pos(
             (PO.BOCA_ENTRADA[0] + 1.6, 0.10, PO.BOCA_ENTRADA[1]),
             -math.pi * 0.5))])
    c.no("chegada_saida", tipo="Marker3D", pai=".",
         props=[("transform", C.transform_pos(
             (PO.BOCA_SAIDA[0] - 1.6, 0.10, PO.BOCA_SAIDA[1]),
             math.pi * 0.5))])

    c.no("NavigationRegion3D", tipo="NavigationRegion3D", pai=".",
         props=[("navigation_mesh", 'SubResource("navmesh")'),
                ("navigation_layers", "4")])

    C.emitir_pichacao(c, rabiscos, nome="manchas")

    x0, z0, x1, z1 = PO.limites(PO.celulas_abertas())
    c.no("poeira", tipo="GPUParticles3D", pai=".",
         props=[("transform", C.transform_pos(((x0 + x1) * 0.5, 1.2,
                                               (z0 + z1) * 0.5))),
                ("amount", "600"), ("lifetime", "14.0"), ("preprocess", "8.0"),
                ("visibility_aabb", "AABB(%.1f, -3, %.1f, %.1f, 8, %.1f)"
                 % (-(x1 - x0) * 0.5 - 4, -(z1 - z0) * 0.5 - 4,
                    x1 - x0 + 8, z1 - z0 + 8)),
                ("process_material", 'SubResource("poeira_proc")'),
                ("draw_pass_1", 'SubResource("poeira_quad")')])
    c.no("ambiencia", tipo="AudioStreamPlayer", pai=".",
         props=[("stream", 'ExtResource("%s")' % id_ambiente),
                ("volume_db", "-10.0"), ("autoplay", "true")])

    c.gravar(SAIDA_CENA)
    print("  %d nos, %d sub-recursos"
          % (sum(1 for l in c.linhas if l.startswith("[node ")), len(c.sub)))


def _ponto_de_entrada():
    """Na boca de cima, de costas pra rampa.

        PORAO_SPAWN="70,1.05,70,180" tools/godot/escola/construir.sh
    """
    teste = os.environ.get("PORAO_SPAWN")
    if teste:
        n = [float(v) for v in teste.split(",")]
        return (n[0], n[1], n[2]), math.radians(n[3] if len(n) > 3 else 0.0)
    x, z = PO.BOCA_ENTRADA
    return (x + 1.6, 1.05, z), -math.pi * 0.5


# ==========================================================================
# sub_resources
# ==========================================================================

def _ambiente(c):
    c.recurso("ambiente", "Environment", [
        "background_mode = 0",
        "background_color = Color(0.008, 0.007, 0.006, 1)",
        "ambient_light_source = 2",
        # Um marrom bem escuro, e nao cinza: o pouco que se enxerga sem a
        # lanterna tem de ser da cor da terra, senao o tunel fica azulado e
        # parece caverna de gelo.
        "ambient_light_color = Color(0.22, 0.17, 0.12, 1)",
        # ======================================================
        # ESTE NUMERO E' O PORAO INTEIRO
        #
        # A escola roda com 1,75. Aqui 0,42: e' quatro vezes mais escuro, e e'
        # por isso que a lanterna deixa de ser conforto e vira ferramenta. A
        # tentacao e' baixar mais ainda, e ja' foi medida: abaixo de ~0,3 o
        # jogador para de enxergar a PAREDE e passa a bater nela, o que nao da'
        # medo, da' raiva. 0,42 mostra a silhueta do tunel e esconde tudo o
        # mais.
        # ======================================================
        "ambient_light_energy = 0.42",
        "reflected_light_source = 0",
        "tonemap_mode = 3",
        "tonemap_exposure = 1.0",
        "tonemap_white = 6.0",
        "glow_enabled = true",
        "glow_intensity = 0.55",
        "glow_strength = 1.1",
        "glow_bloom = 0.22",
        "glow_blend_mode = 1",
        "glow_hdr_threshold = 0.95",
        # A nevoa e' mais densa que a da escola e mais quente: e' poeira em
        # suspensao, nao ar de corredor. E' ela que faz o facho da lanterna
        # aparecer no ar e o fim do tunel sumir a 12 m.
        "fog_enabled = true",
        "fog_mode = 0",
        "fog_light_color = Color(0.16, 0.12, 0.09, 1)",
        "fog_light_energy = 0.7",
        "fog_density = 0.042",
        "fog_aerial_perspective = 0.15",
        "fog_sky_affect = 0.0",
        "adjustment_enabled = true",
        "adjustment_brightness = 1.0",
        "adjustment_contrast = 1.18",
        "adjustment_saturation = 0.72",
    ])


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
        "albedo_color = Color(0.78, 0.66, 0.50, 0.16)",
        "billboard_mode = 3", "billboard_keep_scale = true",
        "disable_receive_shadows = true",
    ])
    c.recurso("poeira_quad", "QuadMesh", [
        'material = SubResource("poeira_mat")', "size = Vector2(0.035, 0.035)",
    ])
    c.recurso("poeira_proc", "ParticleProcessMaterial", [
        "lifetime_randomness = 0.8", "emission_shape = 3",
        "emission_box_extents = Vector3(40.0, 1.4, 36.0)",
        "direction = Vector3(0, -1, 0)", "spread = 70.0",
        "initial_velocity_min = 0.01", "initial_velocity_max = 0.10",
        "gravity = Vector3(0.01, -0.03, 0.01)",
        "scale_min = 0.4", "scale_max = 1.8",
        "color = Color(1, 1, 1, 0.20)",
        "turbulence_enabled = true", "turbulence_noise_strength = 0.20",
    ])


if __name__ == "__main__":
    gerar()
