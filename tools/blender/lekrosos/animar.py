# -*- coding: utf-8 -*-
"""Clipes do Lekroso e o .glb do jogo.

    blender -b Red-Valve-Blender/lekrosos/lekroso_1_cortado.blend \
        -P tools/blender/lekrosos/animar.py -- lekroso_1

Abre o .blend do `cortar.py`, grava as acoes NELE e exporta malha + esqueleto
(com os ossos-sombra) + pecas soltas + clipes:
    red-valve/assets/3d_model/enemies/lekrosos/lekroso_1/lekroso_1_rig.glb

Clipes (o jogo le' os nomes; os "laco" ficam em laco no Godot):

  (OS NOMES DO zombie.glb MENTEM: ver `clipes()`)
  parado       laco — o parado curvado do zombie.glb, com a cabeca caida pro
               lado e um tremor de nervo morto no pescoco e nas maos
  parado_2     laco — o parado quieto do zombie.glb
  vagar        laco — o arrastado de zumbi do zombie.glb, mais lento e de
               cabeca baixa: o perambular sem alvo
  andar        laco — o andar de braco esticado do zombie.glb, o tronco e a
               cabeca indo na frente: a cacada
  tropeco      o corpo despenca pra frente e se segura (feito a mao) — o
               tranco que ele da' sozinho no meio do andar
  dano         a pancada de um tiro (Hit_Reaction_with_Bow do Maycow)
  dano_forte   perder um membro: dobra inteiro pra frente e se endireita
               devagar (Hit_Reaction_with_Bow do Maycow, completo)
  agarrar      o bote: os bracos sobem e fecham (0,55 s)
  segurar      laco — segurando o Maycow pelos ombros, puxando
  morder       a cabeca mergulha no pescoco dele; a mordida fecha em
               MORDIDA_FECHA (s)
  empurrar     os dois bracos empurram ele pra tras e voltam (0,7 s)
  morrer       cai e fica no chao (a morte do zombie.glb)

Os tempos do agarrao batem com `scripts/player/player_grab.gd` (ramo
"mordida"): ver o `agarrao_atacar()` do `lekroso.gd`.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(AQUI), "igreja_dona_nice"))
import anim_comum as A  # noqa: E402
import retarget_lib as RT  # noqa: E402
from anim_comum import D  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
MODELOS = os.path.join(RAIZ, "red-valve/assets/3d_model")
SAIDA = os.path.join(MODELOS, "enemies/lekrosos")

FONTES = {
    "zombie": "enemies/zombie.glb",
    "maycow_lopes": "player/Maycow Lopes/maycow_lopes.glb",
}

MORDIDA_FECHA = 0.30
LADO = Vector((1, 0, 0))     # eixo da esquerda dele (girar em -X leva o braco pra frente)
FRENTE = Vector((0, -1, 0))


def DR(fora, frente, cima):
    return D(-fora, frente, cima)


# ------------------------------------------------------------------ poses
BASE_PERNAS = {
    "thigh.L": (0.10, 0.10, -1), "shin.L": (0.02, -0.12, -1),
    "foot.L": (0.08, 1, -0.55), "toe.L": (0.08, 1, 0),
    "thigh.R": DR(0.10, -0.18, -1), "shin.R": DR(0.02, -0.30, -1),
    "foot.R": DR(0.08, 1, -0.55), "toe.R": DR(0.08, 1, 0),
}

GUARDA = dict(BASE_PERNAS)
GUARDA.update({
    "spine": (0, 0.20, 1), "chest": (0, 0.18, 1), "upper_chest": (0, 0.12, 1),
    "neck": (0, 0.55, 1), "head": (0.12, 0.45, 1),
    "upper_arm.L": (0.30, 0.55, -0.75), "forearm.L": (0.10, 0.75, -0.45),
    "hand.L": (0.05, 0.6, -0.7), "fingers.L": (0.0, 0.5, -0.9),
    "upper_arm.R": DR(0.30, 0.45, -0.8), "forearm.R": DR(0.10, 0.7, -0.5),
    "hand.R": DR(0.05, 0.6, -0.7), "fingers.R": DR(0.0, 0.5, -0.9),
})

# Bote, segurar e morder com o tronco quase em pe': o player_grab.gd cola o
# inimigo a 1,05 m e depois a 0,5 m do Maycow, e a camera de primeira pessoa
# anda 32 cm pra frente. Tronco inclinado poe a cabeca dentro da camera.
BOTE = dict(BASE_PERNAS)
BOTE.update({
    "spine": (0, 0.22, 1), "chest": (0, 0.18, 1), "upper_chest": (0, 0.12, 1),
    "neck": (0, 0.50, 1), "head": (0, 0.35, 1),
    "upper_arm.L": (0.35, 1, 0.30), "forearm.L": (0.10, 1, 0.20),
    "hand.L": (0.0, 1, 0.0), "fingers.L": (-0.1, 1, -0.3),
    "upper_arm.R": DR(0.35, 1, 0.25), "forearm.R": DR(0.10, 1, 0.15),
    "hand.R": DR(0.0, 1, 0.0), "fingers.R": DR(-0.1, 1, -0.3),
    "thigh.L": (0.10, 0.45, -1), "shin.L": (0.02, -0.25, -1),
})

SEGURA = dict(BASE_PERNAS)
SEGURA.update({
    "spine": (0, 0.15, 1), "chest": (0, 0.12, 1), "upper_chest": (0, 0.08, 1),
    "neck": (0, 0.45, 1), "head": (0.05, 0.30, 1),
    # cotovelos abertos, maos nos ombros de quem esta' a meio metro
    "upper_arm.L": (0.55, 0.80, -0.05), "forearm.L": (-0.45, 0.85, 0.30),
    "hand.L": (-0.35, 0.75, 0.30), "fingers.L": (-0.2, 0.4, -0.8),
    "upper_arm.R": DR(0.55, 0.80, -0.05), "forearm.R": DR(-0.45, 0.85, 0.30),
    "hand.R": DR(-0.35, 0.75, 0.30), "fingers.R": DR(-0.2, 0.4, -0.8),
})

# A mordida mergulha so' o PESCOCO: o agarrao (player_grab.gd) cola o
# inimigo a meio metro do Maycow, e com o tronco inteiro indo junto a cabeca
# atravessava a camera de primeira pessoa.
MORDE = dict(SEGURA)
MORDE.update({
    "spine": (0, 0.20, 1), "chest": (0, 0.18, 1), "upper_chest": (0, 0.14, 1),
    "neck": (0.06, 0.60, 0.9), "head": (0.12, 0.45, 1),
    "upper_arm.L": (0.50, 0.85, -0.15), "forearm.L": (-0.55, 0.75, 0.25),
    "upper_arm.R": DR(0.50, 0.85, -0.15), "forearm.R": DR(-0.55, 0.75, 0.25),
})

EMPURRA = dict(BASE_PERNAS)
EMPURRA.update({
    "spine": (0, 0.25, 1), "chest": (0, 0.20, 1), "upper_chest": (0, 0.10, 1),
    "neck": (0, 0.45, 1), "head": (0, 0.30, 1),
    "upper_arm.L": (0.18, 1, 0.05), "forearm.L": (0.05, 1, 0.08),
    "hand.L": (0.0, 0.3, 1.0), "fingers.L": (0.0, 0.2, 1.0),
    "upper_arm.R": DR(0.18, 1, 0.05), "forearm.R": DR(0.05, 1, 0.08),
    "hand.R": DR(0.0, 0.3, 1.0), "fingers.R": DR(0.0, 0.2, 1.0),
    "thigh.L": (0.10, 0.40, -1), "shin.L": (0.02, -0.10, -1),
    "thigh.R": DR(0.10, -0.35, -1), "shin.R": DR(0.02, -0.15, -1),
})

TODOS_APOIOS = ("toe.L", "toe.R", "foot.L", "foot.R")


def _acao(acoes, nome):
    if nome in acoes:
        return acoes[nome]
    for k, a in acoes.items():
        if k.split(".")[0] == nome:
            return a
    raise KeyError(nome)


# TROPECO: o corpo despenca pra frente, a perna direita vem segurar e os
# bracos se debatem — e' o que tira o andar do compasso.
CAI = dict(BASE_PERNAS)
CAI.update({
    "spine": (0.05, 0.75, 1), "chest": (0.05, 0.65, 1), "upper_chest": (0.05, 0.55, 1),
    "neck": (0.15, 1.0, 0.7), "head": (0.20, 0.9, 0.5),
    "upper_arm.L": (0.75, 0.55, -0.25), "forearm.L": (0.55, 0.65, 0.1),
    "upper_arm.R": DR(0.55, -0.35, -0.65), "forearm.R": DR(0.25, 0.30, -0.80),
    "thigh.R": DR(0.10, 0.65, -1), "shin.R": DR(0.02, 0.05, -1),
    "thigh.L": (0.10, -0.35, -1), "shin.L": (0.02, -0.55, -1),
})
SEGURA_A_QUEDA = dict(CAI)
SEGURA_A_QUEDA.update({
    "spine": (0.0, 0.55, 1), "chest": (0.0, 0.45, 1), "upper_chest": (0.0, 0.35, 1),
    "neck": (0.0, 0.8, 1), "head": (-0.1, 0.6, 1),
    "upper_arm.L": (0.45, 0.70, -0.45), "upper_arm.R": DR(0.45, 0.40, -0.80),
    "thigh.R": DR(0.10, 0.45, -1), "shin.R": DR(0.02, -0.10, -1),
})


def clipes(rig, fontes):
    """Os nomes dos clipes do zombie.glb NAO dizem o que eles sao (o proprio
    zombie_1.tscn toca "Idle_11" no estado walk e "Weapon_Combo_2" no dead).
    Escolhido pelo que se ve' quadro a quadro, nao pelo nome."""
    zb, a_zb = fontes["zombie"]
    ml, a_ml = fontes["maycow_lopes"]

    # --- parado: a cabeca pendurada pro lado, tremor de nervo morto
    # (o "Shot_in_the_Back_and_Fall" do zombie.glb e' o PARADO dele)
    def parado_extra(t, q, pos):
        s = t / A.FPS
        A.girar(rig, q, "neck", A.em_torno(FRENTE, 16.0))
        A.girar(rig, q, "head", A.em_torno(LADO, 12.0))
        A.tremor(rig, q, ["neck", "head"], 2.5, 3, s, freq=7.0)
        A.tremor(rig, q, ["hand.L", "fingers.R"], 6.0, 5, s, freq=11.0)
        return pos
    A.retarget(rig, zb, _acao(a_zb, "Shot_in_the_Back_and_Fall"), "parado", laco=True,
               velocidade=0.8, ajustes=parado_extra)
    # o "Running" do zombie.glb e' o parado quieto
    A.retarget(rig, zb, _acao(a_zb, "Running"), "parado_2", laco=True, velocidade=0.7,
               ajustes=parado_extra)

    # --- vagar: o arrastado de zumbi ("Idle_11" do zombie.glb), mais lento,
    # cabeca baixa balancando
    def vagar_extra(t, q, pos):
        s = t / A.FPS
        A.girar(rig, q, "neck", A.em_torno(LADO, 12.0))
        A.girar(rig, q, "neck", A.em_torno(FRENTE, 10.0 * math.sin(s * 0.7)))
        A.tremor(rig, q, ["head"], 3.0, 9, s, freq=6.0)
        return pos
    A.retarget(rig, zb, _acao(a_zb, "Idle_11"), "vagar", laco=True, velocidade=0.8,
               ajustes=vagar_extra)

    # --- andar (cacada): o "Unsteady_Walk" do zombie.glb anda com o braco
    # esticado pra agarrar; o tronco e a cabeca vao na frente
    def andar_extra(t, q, pos):
        s = t / A.FPS
        A.girar(rig, q, "spine", A.em_torno(LADO, 8.0))
        A.girar(rig, q, "neck", A.em_torno(LADO, 10.0))
        A.tremor(rig, q, ["head", "hand.L", "hand.R"], 3.0, 13, s, freq=8.0)
        return pos
    A.retarget(rig, zb, _acao(a_zb, "Unsteady_Walk"), "andar", laco=True, velocidade=0.9,
               ajustes=andar_extra)

    # a pancada de um tiro: so' o comeco do "Hit_Reaction_with_Bow" do Maycow
    # (o tranco pra frente; a volta e' a mistura pro proximo clipe)
    A.retarget(rig, ml, _acao(a_ml, "Hit_Reaction_with_Bow"), "dano", ini=0, fim=26,
               velocidade=1.3)
    # perder um membro: ele dobra INTEIRO pra frente e se endireita devagar
    A.retarget(rig, ml, _acao(a_ml, "Hit_Reaction_with_Bow"), "dano_forte", ini=0, fim=82,
               velocidade=1.4)
    # cai e fica no chao: o "Weapon_Combo_2" do zombie.glb e' a MORTE dele
    A.retarget(rig, zb, _acao(a_zb, "Weapon_Combo_2"), "morrer")

    # --- as poses feitas a mao
    q_g = rig.pose(GUARDA)
    p_g = rig.assentar(q_g, apoios=TODOS_APOIOS)
    q_b = rig.pose(BOTE)
    p_b = rig.assentar(q_b, apoios=TODOS_APOIOS)
    q_s = rig.pose(SEGURA)
    p_s = rig.assentar(q_s, apoios=TODOS_APOIOS)
    q_m = rig.pose(MORDE)
    p_m = rig.assentar(q_m, apoios=TODOS_APOIOS)
    q_e = rig.pose(EMPURRA)
    p_e = rig.assentar(q_e, apoios=TODOS_APOIOS)
    q_c = rig.pose(CAI)
    p_c = rig.assentar(q_c, apoios=TODOS_APOIOS)
    q_q = rig.pose(SEGURA_A_QUEDA)
    p_q = rig.assentar(q_q, apoios=TODOS_APOIOS)

    def treme(semente, graus):
        def f(t, q, pos):
            A.tremor(rig, q, ["head", "hand.L", "hand.R"], graus, semente, t, freq=10.0)
            return pos
        return f

    A.sequencia(rig, "agarrar", [
        (0.0, q_g, p_g), (0.30, q_b, p_b), (0.55, q_s, p_s)], extra=treme(21, 2.5))
    A.sequencia(rig, "segurar", [
        (0.0, q_s, p_s), (0.5, A.mistura(q_s, q_m, 0.18), p_s), (1.0, q_s, p_s)],
        laco=True, extra=treme(23, 3.5))
    A.sequencia(rig, "morder", [
        (0.0, q_s, p_s), (0.16, A.mistura(q_s, q_m, 0.4), p_s),
        (MORDIDA_FECHA, q_m, p_m), (0.42, A.mistura(q_s, q_m, 0.85), p_m),
        (0.55, q_m, p_m), (0.80, q_s, p_s)], extra=treme(25, 4.5))
    A.sequencia(rig, "empurrar", [
        (0.0, q_s, p_s), (0.18, q_e, p_e), (0.34, q_e, p_e), (0.70, q_g, p_g)])
    A.sequencia(rig, "tropeco", [
        (0.0, q_g, p_g), (0.28, q_c, p_c), (0.55, q_q, p_q), (0.80, q_c, p_c),
        (1.25, q_g, p_g)], extra=treme(27, 6.0))



def passada(rig, acao, ossos=("toe.L", "toe.R")):
    """Velocidade do pe' de apoio (m/s) no clipe: o que o no' tem de andar
    pra o pe' nao patinar. Mede o pe' mais baixo de cada quadro."""
    arm = rig.arm
    arm.animation_data.action = acao
    if acao.slots:
        arm.animation_data.action_slot = acao.slots[0]
    f0, f1 = (int(x) for x in acao.frame_range)
    cena = bpy.context.scene
    ant = {}
    vels = []
    for f in range(f0, f1 + 1):
        cena.frame_set(f)
        for o in ossos:
            p = arm.matrix_world @ arm.pose.bones[o].head
            if o in ant:
                dz = p.z
                dy = -(p.y - ant[o].y)
                if dz < 0.06:
                    vels.append(-dy * A.FPS)
            ant[o] = p
    if not vels:
        return 0.0
    vels.sort()
    return vels[len(vels) // 2]


def tirar_ossos_sombra(acao):
    """Os ossos-sombra ficam em repouso em todo clipe: tirar as curvas deles
    (o retarget grava chave em TODO osso da armadura)."""
    for camada in acao.layers:
        for faixa in camada.strips:
            for slot in acao.slots:
                cb = faixa.channelbag(slot)
                if cb is None:
                    continue
                for fc in list(cb.fcurves):
                    if 'pose.bones["pk_' in fc.data_path:
                        cb.fcurves.remove(fc)


def main():
    nome = sys.argv[sys.argv.index("--") + 1]
    bpy.context.scene.render.fps = A.FPS
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    antes = set(bpy.data.actions)
    fontes = {n: RT.importar_fonte(os.path.join(MODELOS, FONTES[n]))
              for n in FONTES}
    rig = A.Rig(arm, fontes["maycow_lopes"][0])
    clipes(rig, fontes)

    novas = [a for a in bpy.data.actions if a.use_fake_user and a not in antes]
    for arm_f, acoes in fontes.values():
        for filho in list(arm_f.children):
            bpy.data.objects.remove(filho, do_unlink=True)
        bpy.data.objects.remove(arm_f, do_unlink=True)
        for a in acoes.values():
            if a in bpy.data.actions.values() and a not in novas:
                bpy.data.actions.remove(a)
    for a in list(bpy.data.actions):
        if a not in novas:
            bpy.data.actions.remove(a)
    for a in novas:
        tirar_ossos_sombra(a)
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)

    for n in ("andar", "vagar"):
        print("PASSADA %s %.3f m/s" % (n, passada(rig, bpy.data.actions[n])))
    for a in sorted(novas, key=lambda a: a.name):
        print("CLIPE %-11s %5.2f s laco=%s" % (a.name, (a.frame_range[1] - a.frame_range[0]) / A.FPS,
                                              bool(a.get("laco", False))))

    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.ops.wm.save_mainfile()

    destino = os.path.join(SAIDA, nome, nome + "_rig.glb")
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    pecas = bpy.data.objects.get("pecas")
    objs = [arm] + [o for o in arm.children_recursive if o.type == 'MESH']
    if pecas:
        objs += [pecas] + list(pecas.children)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False)
        o.hide_render = False
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=destino, export_format='GLB', use_selection=True,
        export_yup=True, export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_skins=True, export_def_bones=False,
        export_reset_pose_bones=True, export_image_format='AUTO')
    print("== exportado", destino)


main()
