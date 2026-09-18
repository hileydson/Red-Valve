# -*- coding: utf-8 -*-
"""Retrato das poses de ARMA das maos de primeira pessoa, direto do Blender.

    blender -b <mao_rig_new.blend> -P tools/blender/maos_fp/previa_armas.py \\
        -- shotgun_idle:1 shotgun_recarga:34 pistola_tiro:3

Sem argumento, retrata uma lista curta de quadros-chave (`PADRAO`).

Monta os dois rigs como o gerador faz, aplica o quadro pedido de uma animacao
de verdade e fotografa do OLHO: camera na origem olhando pro +Y, 75 graus na
vertical, que e' a Camera3D do jogo.

A ARMA NAO E' POSTA PELA MESMA CONTA QUE FEZ A POSE. Ela e' pendurada no osso
`mao` da direita pelo deslocamento constante que o `offset_no_osso` mede — que
e' exatamente o que o Godot faz com um BoneAttachment3D. Assim, se a previa
mostra a arma na mao, o jogo tambem mostra; e se um dia alguem mexer numa pose
de mao sem mexer na arma, o erro aparece aqui antes de chegar no jogo.
"""

import bpy
import os
import sys
import math
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar_maos_fp as G

SAIDA = "/tmp/previa_armas"
LARGURA = 1100
ALTURA = 620

MODELOS = {
    "pistola": "red-valve/assets/3d_model/player/the_negotiator_V1/the_negotiator_v1.glb",
    "shotgun": "red-valve/assets/3d_model/player/the_negotiator_V3/the_negotiator_V3_dobravel.glb",
}

## Qual arma cada animacao segura. As `magic_*` e as de mao vazia nao seguram
## nada e nao aparecem aqui.
ARMA_DA_ANIM = {
    "pistola_idle": "pistola", "pistola_tiro": "pistola",
    "pistola_guardar": "pistola", "pistola_sacar": "pistola",
    "shotgun_idle": "shotgun", "shotgun_tiro": "shotgun",
    "shotgun_recarga": "shotgun", "shotgun_guardar": "shotgun",
    "shotgun_sacar": "shotgun",
}

PADRAO = ["pistola_idle:1", "pistola_tiro:3", "shotgun_idle:1",
          "shotgun_tiro:4", "shotgun_recarga:1", "shotgun_recarga:22",
          "shotgun_recarga:32", "shotgun_recarga:52", "shotgun_recarga:65",
          "shotgun_recarga:98", "shotgun_guardar:14", "shotgun_sacar:1"]


def montar_camera():
    cena = bpy.context.scene
    dados = bpy.data.cameras.new("olho")
    dados.sensor_fit = 'VERTICAL'
    dados.angle = math.radians(75.0)
    dados.clip_start = 0.02 * G.UNI
    cam = bpy.data.objects.new("olho", dados)
    cena.collection.objects.link(cam)
    # A camera do Blender olha pro -Z; girada 90 graus em X ela olha pro +Y,
    # com o +Z do mundo pra cima. E' o espaco em que as poses sao escritas.
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    cam.location = (0.0, 0.0, 0.0)
    cena.camera = cam

    sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", 'SUN'))
    cena.collection.objects.link(sol)
    sol.rotation_euler = (math.radians(58.0), 0.0, math.radians(35.0))
    sol.data.energy = 2.5

    cena.render.engine = 'BLENDER_WORKBENCH'
    cena.render.resolution_x = LARGURA
    cena.render.resolution_y = ALTURA


def trazer_arma(nome):
    """Importa a arma uma unica vez e devolve (raiz, charneira)."""
    marca = "arma_" + nome
    achado = next((o for o in bpy.data.objects if o.get("previa") == marca
                   and o.parent is None), None)
    if achado is not None:
        return achado, next((o for o in bpy.data.objects
                             if o.get("previa") == marca
                             and o.name.startswith("charneira")), None)
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(G.raiz_projeto(), MODELOS[nome]))
    novos = [o for o in bpy.data.objects if o not in antes]
    for o in novos:
        o["previa"] = marca
        o.hide_render = True
    raiz = next(o for o in novos if o.parent is None)
    charneira = next((o for o in novos if o.name.startswith("charneira")), None)
    return raiz, charneira


def offset_no_osso(arm_dir, arma, comp):
    """A transformacao da arma DENTRO do osso `arma`.

    Nao tem misterio nenhum: o osso e' o proprio quadro da arma, sem escala
    (ver `criar_osso_da_arma` e `quadro_do_osso` no gerador), entao o que
    falta e' so' levar o modelo das unidades dele pras do rig.

    E' este mesmo numero que o `maos_fp_armas.gd` monta no Godot, la' dividido
    pela escala do no' do rig em vez de multiplicado por UNI — que da' no
    mesmo, porque a escala do no' e' 1/UNI.
    """
    return Matrix.Scale(G.ARMAS[arma]["escala"] * G.UNI, 4)


def retratar(nome, comp, arm_esq, arm_dir, poses, arma, offset, abertura):
    G.aplicar_pose(arm_esq, poses[0], comp, False)
    G.aplicar_pose(arm_dir, poses[1], comp, True)
    bpy.context.view_layer.update()
    for o in bpy.data.objects:
        if o.get("previa", "").startswith("arma_"):
            o.hide_render = True
    if arma is not None:
        raiz, charneira = trazer_arma(arma)
        osso = arm_dir.matrix_world @ arm_dir.pose.bones[G.NOME_OSSO_ARMA].matrix
        raiz.matrix_world = osso @ offset
        if charneira is not None:
            charneira.rotation_mode = 'XYZ'
            # Abrir a arma gira em volta do eixo lateral: Y no Blender, Z no
            # Godot (e' a mesma rotacao, so' muda o nome do eixo).
            # Negativo: no Blender o +Y LEVANTA a boca, e uma break-action
            # abre com os canos caindo. No Godot esse mesmo giro e' +Z.
            charneira.rotation_euler = (0.0, -math.radians(abertura), 0.0)
        for o in bpy.data.objects:
            if o.get("previa") == "arma_" + arma:
                o.hide_render = False
    bpy.context.view_layer.update()
    caminho = os.path.join(SAIDA, "%s.png" % nome)
    bpy.context.scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    print("previa: %s" % caminho)


def _pose_no_quadro(fabrica, lado, alvo):
    """A pose da chave mais proxima de `alvo` — sem interpolar.

    Interpolar aqui seria mentira diferente da do Godot (que interpola a
    ROTACAO do osso, nao a pose em metros); o que interessa na previa e' se as
    chaves estao certas.
    """
    quadros = fabrica(lado)
    return min(quadros, key=lambda par: abs(par[0] - alvo))[1]


def main():
    os.makedirs(SAIDA, exist_ok=True)
    arm = bpy.data.objects["Armature"]
    mesh = bpy.data.objects["Mesh0"]
    bpy.context.scene.render.fps = G.FPS
    comp = G.preparar(arm)
    G.limpar_temporarios()
    mesh_esq = G.criar_mao_esquerda(arm, mesh)
    arm_dir, _mesh_dir = G.criar_mao_direita(arm, mesh_esq)
    G.criar_osso_da_arma(arm)
    G.criar_osso_da_arma(arm_dir)
    G.preparar(arm)
    G.preparar(arm_dir)
    mesh.hide_render = True
    montar_camera()

    offsets = {}
    for nome_arma in MODELOS:
        offsets[nome_arma] = offset_no_osso(arm_dir, nome_arma, comp)
        print("offset_no_osso[%s] = %s" % (nome_arma,
              [round(v, 5) for linha in offsets[nome_arma] for v in linha]))

    fabricas = dict(G.ANIMACOES)
    pedidos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for pedido in (pedidos or PADRAO):
        nome, _sep, texto = pedido.partition(":")
        if nome not in fabricas:
            print("previa: nao existe animacao '%s'" % nome)
            continue
        alvo = int(texto) if texto else 1
        poses = (_pose_no_quadro(fabricas[nome], 0, alvo),
                 _pose_no_quadro(fabricas[nome], 1, alvo))
        arma = ARMA_DA_ANIM.get(nome)
        # A dobra so' existe na cacadeira, e so' na recarga.
        abertura = 0.0
        if nome == "shotgun_recarga":
            abertura = G.abertura_da_recarga(alvo)
        retratar("%s_q%03d" % (nome, alvo), comp, arm, arm_dir, poses,
                 arma, offsets.get(arma), abertura)


if __name__ == "__main__":
    main()
