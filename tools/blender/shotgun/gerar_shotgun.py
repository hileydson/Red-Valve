# -*- coding: utf-8 -*-
"""Corta a The Negotiator V3 em DUAS pecas para ela poder dobrar, e monta o
item de dois cartuchos que o jogador pega no balcao.

    blender -b -P tools/blender/shotgun/gerar_shotgun.py

POR QUE ISTO EXISTE
-------------------
`the_negotiator_V3.glb` e' uma casca UNICA de 4.497 tris, sem osso, sem .blend
fonte, com a textura assada num atlas so'. Uma break-action precisa abrir, e
nao da' pra pesar vertice nenhum numa dobradica que a malha nao tem: cano e
coronha sao a MESMA superficie continua. Entao a dobra e' CORTE, nao rig.

ONDE A MALHA QUEBRA (medido, nao chutado)
-----------------------------------------
Perfilando a malha ao longo do X (o comprimento da arma) a bascula aparece
sozinha: em X = 0,00 a largura estreita de 0,226 pra 0,188 e o fundo despenca
de +0,057 pra -0,035 — e' o guarda-mato surgindo. A quina do desenho (o anel
gravado da foto) esta' em X = -0,06..-0,03, e e' nela que o corte se esconde.

    X < -0,030   canos + fore-end   (a peca que dobra)
    X > -0,030   bascula + coronha  (a peca que fica na mao)

O pino da charneira e' o canto inferior dianteiro da bascula: o fundo dos canos
naquele X, que e' +0,057. E o eixo de giro e' o Z do modelo (o lado).

O QUE SE MODELA A MAIS
----------------------
Cortar uma casca fechada abre um buraco nos dois lados, e com a arma aberta
esse buraco fica DE FRENTE pra camera — e' o quadro principal da recarga. Numa
break-action ele nao e' tampa cega: e' a culatra, com as duas camaras abertas
de um lado e os extratores do outro. Entao o corte vem com furo e pino.

As duas camaras saem dos BORES de verdade: os vertices da boca do cano se
agrupam em Z = +-0,060, e o eixo sobe 0,152 por unidade de X ao longo da arma —
dai' o centro delas no corte.

CONVENCAO DE ESPACO
-------------------
O .glb entra e sai na convencao glTF (Y pra cima). O Blender converte na
importacao (glTF x,y,z -> Blender x,-z,y) e desconverte no export com o
`export_yup` PADRAO (True) — que e' o certo para quem faz round-trip de um
arquivo que ja' existe. (Os geradores de malha de tools/blender/ autoram direto
na convencao do jogo e por isso exportam com export_yup=False; aqui nao.)

O QUE SAI
---------
    the_negotiator_V3/the_negotiator_V3_dobravel.glb
        raiz
        +- corpo        bascula + coronha, com os dois extratores
        +- charneira    vazio no pino; girar ELE abre a arma
           +- canos     canos + fore-end, com as duas camaras

    the_negotiator_V3/cartridge/the_negotiator_V3_bullet_x2.glb
        os dois cartuchos deitados lado a lado, ja' no tamanho de verdade
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BASE = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "player",
                    "the_negotiator_V3")
ARMA_ENTRA = os.path.join(BASE, "the_negotiator_V3.glb")
ARMA_SAI = os.path.join(BASE, "the_negotiator_V3_dobravel.glb")
BALA_ENTRA = os.path.join(BASE, "cartridge", "the_negotiator_V3_bullet.glb")
BALA_SAI = os.path.join(BASE, "cartridge", "the_negotiator_V3_bullet_x2.glb")

# ---- as medidas da arma, no espaco do MODELO (glTF) --------------------------
## Onde a casca e' cortada. E' o X em que a bascula comeca, e cai na quina
## gravada que o desenho ja' tem.
CORTE_X = -0.030
## O pino da charneira: o fundo dos canos no X do corte.
CHARNEIRA = (CORTE_X, 0.057, 0.0)
## As duas camaras. Z sai dos bores da boca; Y sobe com o eixo do cano.
CAMARA_Z = 0.060
CAMARA_Y = 0.127
CAMARA_RAIO = 0.030
CAMARA_FUNDO = 0.105
## Os extratores, na face da bascula, apontando pro cano.
EXTRATOR_RAIO = 0.013
EXTRATOR_COMP = 0.030

# ---- o cartucho --------------------------------------------------------------
## Um 12 de verdade tem 70 mm. O modelo tem 1,912 unidade de comprimento.
CARTUCHO_COMPRIMENTO = 0.070
## Folga entre os dois, de casco a casco.
CARTUCHO_FOLGA = 0.004


def bl(x, y, z):
    """Ponto do modelo (glTF) no espaco do Blender."""
    return Vector((x, -z, y))


def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def importar(caminho):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=caminho)
    novos = [o for o in bpy.data.objects if o not in antes]
    malhas = [o for o in novos if o.type == "MESH"]
    if not malhas:
        raise RuntimeError("nada de malha em %s" % caminho)
    # O .glb vem com um Empty de raiz por cima da malha; a malha e' o que
    # interessa, e ela sai da hierarquia com a transformacao ja' aplicada.
    alvo = malhas[0]
    alvo.matrix_basis = alvo.matrix_world.copy()
    alvo.parent = None
    for o in novos:
        if o is not alvo:
            bpy.data.objects.remove(o, do_unlink=True)
    aplicar_transformacao(alvo)
    soldar(alvo)
    return alvo


def soldar(obj):
    """Funde os vertices repetidos que o .glb traz.

    Sem isto nada mais aqui funciona. O glTF guarda um vertice POR CANTO DE
    FACE nas costuras de UV e de normal: os 2.245 vertices da arma chegam como
    3.841, e a casca — que e' fechada — entra no Blender com 2.819 arestas de
    borda. Cortar uma malha assim nao abre um buraco, abre 68 pedacos soltos, e
    `holes_fill` nao tem o que tapar. Soldado: 2 bordas, zero nao-manifold.

    As UVs nao se perdem: no Blender elas moram no CANTO DA FACE, nao no
    vertice, entao a costura continua ali depois da solda.
    """
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    antes = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    depois = len(bm.verts)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    print("== soldado: %d -> %d verts" % (antes, depois))


def aplicar_transformacao(obj):
    obj.data.transform(obj.matrix_basis)
    obj.matrix_basis = Matrix.Identity(4)


def material_interior():
    """O metal de dentro: cap, parede de camara, extrator.

    O atlas assado nao tem "interior" — ele e' a pele de fora da peca inteira.
    Qualquer face nova que nascesse com UV daqui puxaria pixel de um lugar
    aleatorio da textura. Entao as faces novas ganham material PROPRIO, escuro e
    metalico, que e' o que a culatra de uma caçadeira e' de verdade.
    """
    mat = bpy.data.materials.get("negotiator_interior")
    if mat is not None:
        return mat
    mat = bpy.data.materials.new("negotiator_interior")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        # Nem preto nem cromado: preto puro apaga o relevo das camaras (a
        # culatra vira uma mancha chapada na tela) e claro demais rouba a
        # atencao do resto da arma. Isto e' aco escuro meio fosco.
        bsdf.inputs["Base Color"].default_value = (0.135, 0.130, 0.126, 1.0)
        bsdf.inputs["Metallic"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = 0.52
    return mat


def indice_do_material(obj, mat):
    for i, slot in enumerate(obj.data.materials):
        if slot is mat:
            return i
    obj.data.materials.append(mat)
    return len(obj.data.materials) - 1


def cortar(obj, nome, ficar_com_frente, idx_interior):
    """Copia `obj`, corta no plano do CORTE_X e tapa o buraco.

    `ficar_com_frente` escolhe o lado: True devolve os canos (X menor que o
    corte), False a bascula com a coronha.
    """
    novo = obj.copy()
    novo.data = obj.data.copy()
    novo.name = nome
    novo.data.name = nome
    bpy.context.collection.objects.link(novo)

    idx = indice_do_material(novo, material_interior())

    bm = bmesh.new()
    bm.from_mesh(novo.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    # O plano e' o X do modelo, que no Blender continua sendo o X.
    res = bmesh.ops.bisect_plane(
        bm, geom=geom, dist=1e-6,
        plane_co=bl(CORTE_X, 0.0, 0.0), plane_no=Vector((1.0, 0.0, 0.0)),
        # `clear_inner` limpa o lado CONTRA a normal do plano — entao ficar
        # com a frente (X menor) e' limpar o "outer". Medido: o contrario
        # devolve a coronha no lugar dos canos, e o `assert` la' embaixo pega.
        clear_inner=not ficar_com_frente, clear_outer=ficar_com_frente)

    # As bordas de verdade da malha cortada, e nao o `geom_cut` do bisect: o
    # clear apaga geometria e invalida parte daquela lista.
    bm.edges.ensure_lookup_table()
    cortadas = [e for e in bm.edges if len(e.link_faces) == 1]
    tapadas = []
    if cortadas:
        # `sides=0` e' "tampe o buraco com quantos lados ele tiver". O padrao
        # e' 4, e a culatra tem 68 — era por isso que a tampa nao nascia, e sem
        # tampa a peca fica aberta e os booleanos exatos depois nao colam nada.
        tapadas = bmesh.ops.holes_fill(bm, edges=cortadas, sides=0)["faces"]
        if not tapadas:
            tapadas = bmesh.ops.edgenet_fill(bm, edges=cortadas)["faces"]
        for f in tapadas:
            f.material_index = idx
            f.smooth = False
    print("== %s: %d arestas de corte, %d faces de tampa"
          % (nome, len(cortadas), len(tapadas)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(novo.data)
    bm.free()
    novo.data.update()
    return novo


def cilindro(x0, x1, y, z, raio, nome):
    """Cilindro deitado no eixo X do MODELO, de x0 a x1.

    O X entra explicito porque os dois usos apontam pra lados opostos: a camara
    e' furada da culatra PRA BOCA (X diminuindo) e o extrator sai da bascula
    PRA FRENTE (X diminuindo tambem, mas atravessando a face). Deixar isso
    implicito num "comprimento" ja' furou pro lado errado uma vez.
    """
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=raio,
                                        depth=abs(x1 - x0), location=(0, 0, 0))
    cil = bpy.context.active_object
    cil.name = nome
    # O primitivo nasce em pe' no Z do Blender; deitar no X e' um quarto de
    # volta no Y.
    cil.rotation_euler = (0.0, math.radians(90.0), 0.0)
    cil.location = bl((x0 + x1) * 0.5, y, z)
    bpy.context.view_layer.update()
    aplicar_transformacao(cil)
    return cil


def furar_camaras(canos):
    """Abre as duas camaras na culatra dos canos."""
    cortadores = []
    for lado in (-1, 1):
        # Comeca um tiquinho DEPOIS da culatra e vai pra dentro do cano (X
        # diminuindo): sobrar 2 mm pra tras evita face coincidente com a tampa,
        # que o boolean exato detesta.
        cortadores.append(cilindro(
            CORTE_X + 0.002, CORTE_X - CAMARA_FUNDO,
            CAMARA_Y, lado * CAMARA_Z, CAMARA_RAIO, "camara_%+d" % lado))

    juntar(cortadores)
    cortador = cortadores[0]
    cortador.data.materials.clear()
    cortador.data.materials.append(material_interior())

    indice_do_material(canos, material_interior())
    booleano(canos, cortador, "DIFFERENCE")
    bpy.data.objects.remove(cortador, do_unlink=True)


def por_extratores(corpo):
    """Os dois pinos de extrator na face da bascula, olhando pro cano."""
    pinos = []
    for lado in (-1, 1):
        # Entra 10 mm DENTRO da bascula e sai o comprimento dele pra frente:
        # encostado exatamente na face, a uniao exata nao cola.
        pinos.append(cilindro(
            CORTE_X + 0.010, CORTE_X - EXTRATOR_COMP,
            CAMARA_Y, lado * CAMARA_Z, EXTRATOR_RAIO, "extrator_%+d" % lado))
    juntar(pinos)
    pino = pinos[0]
    pino.data.materials.clear()
    pino.data.materials.append(material_interior())
    indice_do_material(corpo, material_interior())
    booleano(corpo, pino, "UNION")
    bpy.data.objects.remove(pino, do_unlink=True)


def juntar(objetos):
    """Funde a lista num so' objeto (o primeiro). Os outros somem."""
    if len(objetos) < 2:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in objetos:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    bpy.ops.object.join()


def booleano(alvo, cortador, operacao):
    mod = alvo.modifiers.new("bool", "BOOLEAN")
    mod.operation = operacao
    mod.solver = "EXACT"
    mod.object = cortador
    bpy.context.view_layer.objects.active = alvo
    bpy.ops.object.modifier_apply(modifier=mod.name)


def refazer_sombreamento(obj):
    """Tira as normais customizadas do .glb e reconstroi por angulo.

    O glTF traz uma normal por CANTO DE FACE, e a solda transforma isso em
    "custom split normals". Elas mandam mais que o flag de suave/chato, entao a
    tampa e a parede da camara — que sao faces NOVAS, sem normal propria —
    saem onduladas, com a sombra escorrendo de um lado pro outro da chapa.

    Apagar as normais e remontar por angulo (35 graus) devolve quina onde ha'
    quina e continua liso onde o corpo e' liso, nas faces velhas e nas novas.
    """
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.shade_auto_smooth(angle=math.radians(35.0))


def deslocar_malha(obj, delta):
    obj.data.transform(Matrix.Translation(delta))


def contar(obj):
    return len(obj.data.polygons), len(obj.data.vertices)


# ==============================================================================
# A ARMA
# ==============================================================================
def gerar_arma():
    limpar_cena()
    inteira = importar(ARMA_ENTRA)
    print("== entrada: %d faces, %d verts" % contar(inteira))

    idx = indice_do_material(inteira, material_interior())
    canos = cortar(inteira, "canos", True, idx)
    corpo = cortar(inteira, "corpo", False, idx)
    bpy.data.objects.remove(inteira, do_unlink=True)

    # Confere que cada peca ficou do lado que devia. Se o `clear_inner` do
    # bmesh trocar de sentido numa versao futura, isto estoura aqui em vez de
    # entregar uma arma que dobra pelo lado errado.
    for peca, esperado in ((canos, "frente"), (corpo, "tras")):
        xs = [v.co.x for v in peca.data.vertices]
        meio = sum(xs) / len(xs)
        lado = "frente" if meio < CORTE_X else "tras"
        if lado != esperado:
            raise RuntimeError("a peca '%s' saiu do lado %s (x medio %.3f)"
                               % (peca.name, lado, meio))

    furar_camaras(canos)
    por_extratores(corpo)
    refazer_sombreamento(canos)
    refazer_sombreamento(corpo)
    print("== canos: %d faces, %d verts" % contar(canos))
    print("== corpo: %d faces, %d verts" % contar(corpo))

    # A hierarquia. O `canos` fica com os vertices medidos A PARTIR do pino, e
    # o pino e' que carrega a posicao — assim girar a charneira gira a peca em
    # volta do eixo de verdade, e o transform local do `canos` pode ficar
    # identidade (que e' o que o Godot le' como "fechada").
    pino = bl(*CHARNEIRA)
    deslocar_malha(canos, -pino)

    raiz = bpy.data.objects.new("the_negotiator_V3_dobravel", None)
    bpy.context.collection.objects.link(raiz)
    charneira = bpy.data.objects.new("charneira", None)
    charneira.empty_display_size = 0.05
    bpy.context.collection.objects.link(charneira)

    charneira.parent = raiz
    charneira.location = pino
    canos.parent = charneira
    canos.location = (0.0, 0.0, 0.0)
    corpo.parent = raiz
    corpo.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()

    exportar(ARMA_SAI)


# ==============================================================================
# OS DOIS CARTUCHOS
# ==============================================================================
def gerar_cartuchos():
    limpar_cena()
    um = importar(BALA_ENTRA)

    xs = [v.co.x for v in um.data.vertices]
    ys = [v.co.y for v in um.data.vertices]
    comprimento = max(xs) - min(xs)
    diametro = max(ys) - min(ys)
    escala = CARTUCHO_COMPRIMENTO / comprimento
    print("== cartucho: %.3f de comprimento -> escala %.4f" % (comprimento, escala))

    um.data.transform(Matrix.Diagonal((escala, escala, escala, 1.0)))
    # Deitado no chao e centrado: o item nasce POUSADO no tampo do balcao, e o
    # gerador do hospital so' soma a meia espessura (`apoio`).
    passo = diametro * escala + CARTUCHO_FOLGA
    um.name = "cartucho_1"
    deslocar_malha(um, Vector((0.0, -passo * 0.5, 0.0)))

    outro = um.copy()
    outro.data = um.data.copy()
    outro.name = "cartucho_2"
    bpy.context.collection.objects.link(outro)
    deslocar_malha(outro, Vector((0.0, passo, 0.0)))

    juntar([um, outro])
    um.name = "the_negotiator_V3_bullet_x2"
    um.data.name = um.name
    print("== par: %d faces, %d verts" % contar(um))

    exportar(BALA_SAI)


def exportar(caminho):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=caminho,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_animations=False,
        export_skins=False,
        export_morph=False,
        export_cameras=False,
        export_lights=False)
    print("== escrito %s (%.1f MB)"
          % (caminho, os.path.getsize(caminho) / 1048576.0))


def main():
    gerar_arma()
    gerar_cartuchos()


main()
