# -*- coding: utf-8 -*-
"""Ferramentas comuns das animacoes da cena da igreja.

Convencao das direcoes escritas a mao: D(esquerda, frente, cima), no espaco do
PERSONAGEM. Vira vetor de mundo do Blender (+X esquerda, -Y frente, Z cima).
Num dicionario de pose, chave terminada em ".L" e' espelhada sozinha pro
".R" (lateral trocada) quando o ".R" nao for dado.

Posicoes sao em METROS. O Maycow e' o unico rig com a armadura em escala 0,01
(centimetros, como veio do Meshy); `Rig` converte.
"""

import math
import random

import bpy
from mathutils import Euler, Quaternion, Vector

import retarget_lib as RT

FPS = 30


def D(esq, frente, cima):
    return Vector((esq, -frente, cima)).normalized()


def espelhar_dir(v):
    return Vector((-v.x, v.y, v.z))


def com_lados(dirs):
    out = {}
    for k, v in dirs.items():
        v = v if isinstance(v, Vector) else D(*v)
        out[k] = v
        if k.endswith(".L"):
            r = k[:-2] + ".R"
            if r not in dirs:
                out[r] = espelhar_dir(v)
    return out


def rz(graus):
    """Giro de mundo em torno do vertical (positivo = vira pra ESQUERDA dele)."""
    return Quaternion((0, 0, 1), math.radians(graus))


def em_torno(eixo, graus):
    return Quaternion(Vector(eixo).normalized(), math.radians(graus))


class Rig:
    """Envolve o `RT.Alvo` com nomes de osso por papel e unidades em metro."""

    def __init__(self, arm, fonte=None, mapa=None, nomes=None):
        self.arm = arm
        self.alvo = RT.Alvo(arm, fonte, mapa or RT.MAPA)
        self.escala = arm.matrix_world.to_scale().x      # 0,01 no Maycow
        # papel -> nome do osso neste rig (identidade nos rigs da igreja)
        self.nomes = nomes or {}

    def n(self, papel):
        return self.nomes.get(papel, papel)

    def dirs(self, d):
        """Traduz um dicionario {papel: direcao} pros nomes deste rig."""
        return {self.n(k): v for k, v in com_lados(d).items()}

    def pose(self, d, giros=None):
        g = {self.n(k): v for k, v in (giros or {}).items()}
        return RT.pose_por_direcoes(self.alvo, self.dirs(d), g)

    def quadril_rest(self):
        return self.alvo.rest[self.alvo.quadril].translation * self.escala

    def aplicar(self, q, pos_m, quadro=None):
        return self.alvo.aplicar(q, None if pos_m is None else pos_m / self.escala,
                                 quadro)

    def pontas(self, pose, ossos):
        """Menor z (m) entre cabeca e cauda dos ossos dados, na pose calculada."""
        z = 1e9
        for papel in ossos:
            nome = self.n(papel)
            if nome not in pose:
                continue
            m = pose[nome]
            cab = m.translation
            cau = cab + m.to_3x3().normalized() @ (self.alvo.eixo[nome] * self.alvo.comp[nome])
            z = min(z, cab.z, cau.z)
        return z * self.escala

    def assentar(self, q, xy=(0.0, 0.0), apoios=("toe.L", "toe.R", "foot.L", "foot.R"),
                 folga=0.0, dz=0.0):
        """Posicao do quadril que poe o ponto mais baixo dos `apoios` em z=folga."""
        base = self.quadril_rest()
        tentativa = Vector((base.x + xy[0], base.y + xy[1], base.z))
        pose = self.aplicar(q, tentativa)
        z = self.pontas(pose, apoios)
        tentativa.z += folga - z + dz
        return tentativa

    def chave(self, q, pos_m, quadro):
        self.aplicar(q, pos_m, quadro)


def nova_acao(rig, nome):
    return RT.nova_acao(rig.arm, nome)


def girar(rig, q, papel, rot):
    """Gira o osso e tudo o que pende dele (rotacao de mundo)."""
    RT.girar_subarvore(rig.alvo, q, rig.n(papel), rot)


def mistura(qa, qb, t):
    return RT.interpolar(qa, qb, RT.suave(t))


def tremor(rig, q, papeis, graus, semente, t, freq=9.0):
    """Tremor pequeno e nervoso (possessao, frio, dor). Deterministico."""
    for i, papel in enumerate(papeis):
        rnd = random.Random(semente * 131 + i)
        fase = rnd.random() * 10
        a = graus * (math.sin(t * freq + fase) * 0.6
                     + math.sin(t * freq * 2.7 + fase * 1.7) * 0.4)
        eixo = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        girar(rig, q, papel, em_torno(eixo, a))


def sequencia(rig, nome, chaves, laco=False, passo=1, extra=None):
    """Grava uma acao a partir de poses-chave.

    `chaves`: [(segundos, q_mundo, pos_quadril_m)]. Entre duas chaves a pose e'
    interpolada com suavizacao; `extra(t_seg, q, pos)` pode mexer em cada
    quadro (respiracao, tremor) e devolver uma nova posicao.
    `passo` > 1 grava uma chave a cada N quadros — clipe feito a mao fica com
    poucas chaves, que e' o que deixa ele editavel no AnimationPlayer.
    """
    nova_acao(rig, nome)
    fim = chaves[-1][0]
    total = int(round(fim * FPS))
    quadros = list(range(0, total + 1, passo))
    if quadros[-1] != total:
        quadros.append(total)
    for f in quadros:
        t = f / FPS
        for i in range(len(chaves) - 1):
            if chaves[i][0] <= t <= chaves[i + 1][0]:
                a, b = chaves[i], chaves[i + 1]
                break
        else:
            a = b = chaves[-1]
        u = 0.0 if b[0] == a[0] else (t - a[0]) / (b[0] - a[0])
        q = mistura(a[1], b[1], u)
        pos = a[2].lerp(b[2], RT.suave(u))
        if extra:
            pos = extra(t, q, pos) or pos
        rig.chave(q, pos, f)
    acao = rig.arm.animation_data.action
    acao["laco"] = bool(laco)
    return acao


def retarget(rig, fonte, acao_fonte, nome, laco=False, **kw):
    acao, n = RT.retarget(fonte, acao_fonte, rig.alvo, nome, **kw)
    acao["laco"] = bool(laco)
    return acao, n


def copiar_canais(origem, destino, prefixos, duracao_quadros):
    """Copia (em laco) as curvas de alguns ossos de uma acao pra outra.

    Usado pra levar a boca do `talk_loop` da Dona Nice pra dentro do clipe do
    sussurro: o corpo e' feito aqui, a boca ja' existia.
    """
    def bag(acao):
        return acao.layers[0].strips[0].channelbag(acao.slots[0])

    cb_o = bag(origem)
    cb_d = bag(destino)
    for fc in list(cb_d.fcurves):
        if any(('pose.bones["%s' % p) in fc.data_path for p in prefixos):
            cb_d.fcurves.remove(fc)
    o0, o1 = origem.frame_range
    periodo = o1 - o0
    for fc in cb_o.fcurves:
        if not any(('pose.bones["%s' % p) in fc.data_path for p in prefixos):
            continue
        novo = cb_d.fcurves.new(fc.data_path, index=fc.array_index,
                                group_name=fc.group.name if fc.group else "")
        voltas = int(duracao_quadros // periodo) + 1
        for v in range(voltas):
            for k in fc.keyframe_points:
                f = k.co.x - o0 + v * periodo
                if f > duracao_quadros:
                    break
                novo.keyframe_points.insert(f, k.co.y, options={'FAST'})
        novo.update()


def marcar_laco(acao, laco=True):
    acao["laco"] = bool(laco)
