# -*- coding: utf-8 -*-
"""Retarget de captura de movimento (esqueleto Meshy de 24 ossos) para os rigs
da cena da igreja, mais as ferramentas de pose feita a mao.

Roda DENTRO do Blender.

DE ONDE VEM O MOVIMENTO
-----------------------
O projeto ja' tem uma biblioteca de clipes de captura no esqueleto Meshy
(Hips, Spine02, Spine01, Spine, neck, Head, LeftShoulder...): zombie.glb,
maycow_lopes.glb, the_anti_lopes.glb, the-cobalt-husker.glb. Andar
cambaleante, cair morto, dor de cabeca, pancada no chao, pegar algo do chao
— movimento de gente de verdade, que pose escrita a mao nao alcanca.

COMO O RETARGET FUNCIONA (e por que nao depende do roll dos ossos)
-------------------------------------------------------------------
Tudo e' feito em rotacao de MUNDO, osso a osso:

    alvo_mundo(t) = fonte_mundo(t) * fonte_repouso^-1 * alvo_referencia

`alvo_referencia` e' o alvo posto na MESMA SILHUETA do repouso da fonte (cada
osso girado pelo menor arco que leva a direcao dele a' direcao do osso
correspondente da fonte). Sem isso, um rig em pose T (a Dona Nice normal)
tocando captura feita em pose A sairia com os bracos 45 graus pra cima o clipe
inteiro. E como so' entram direcoes e rotacoes de mundo, o roll de cada osso
(que e' diferente na Dona Nice e nos rigs novos) nao importa.

O quadril anda o que o quadril da fonte andou, escalado pela razao das alturas
de quadril (o Jonny tem 0,6 da perna da fonte). `no_lugar` zera o deslocamento
horizontal: quem anda pelo cenario e' o no' no Godot, nao o osso.

O QUE E' FEITO A MAO
--------------------
- `ajustes`: rotacoes de mundo aplicadas por cima do clipe, numa SUBARVORE
  (girar o pescoco leva a cabeca junto). E' assim que a cabeca da Dona Nice
  gira 180 graus no meio de um clipe de captura.
- `pose_por_direcoes`: pose inteira descrita como "este osso aponta pra la'".
  Pra o que nao existe em captura (ajoelhar com a faca, o Jonny caido).
"""

import bpy
from mathutils import Matrix, Quaternion, Vector

# alvo -> fonte (Meshy)
MAPA = {
    "hips": "Hips", "spine": "Spine02", "chest": "Spine01",
    "upper_chest": "Spine", "neck": "neck", "head": "Head",
}
for _l, _m in (("L", "Left"), ("R", "Right")):
    MAPA.update({
        "shoulder." + _l: _m + "Shoulder", "upper_arm." + _l: _m + "Arm",
        "forearm." + _l: _m + "ForeArm", "hand." + _l: _m + "Hand",
        "thigh." + _l: _m + "UpLeg", "shin." + _l: _m + "Leg",
        "foot." + _l: _m + "Foot", "toe." + _l: _m + "ToeBase",
    })

# a direcao de cada osso da fonte: cabeca dele -> cabeca deste filho
DIR_FONTE = {
    "Hips": "Spine02", "Spine02": "Spine01", "Spine01": "Spine",
    "Spine": "neck", "neck": "Head", "Head": "head_end",
}
for _m in ("Left", "Right"):
    DIR_FONTE.update({
        _m + "Shoulder": _m + "Arm", _m + "Arm": _m + "ForeArm",
        _m + "ForeArm": _m + "Hand", _m + "UpLeg": _m + "Leg",
        _m + "Leg": _m + "Foot", _m + "Foot": _m + "ToeBase",
    })
# osso sem filho usa o alinhamento do pai (mao segue o antebraco, dedo do pe'
# segue o pe')
HERDA_ALINHAMENTO = {"hand.L": "forearm.L", "hand.R": "forearm.R",
                     "toe.L": "foot.L", "toe.R": "foot.R"}

# Mapa identidade, pra quando o ALVO tambem e' Meshy (o Maycow normal).
MAPA_MESHY = {v: v for v in MAPA.values()}


def _rot(m):
    return m.to_3x3().normalized().to_quaternion()


def importar_fonte(caminho):
    """Importa um .glb de captura. Devolve (armadura, {nome: acao})."""
    antes_obj = set(bpy.data.objects)
    antes_acao = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=caminho)
    novos = [o for o in bpy.data.objects if o not in antes_obj]
    arm = [o for o in novos if o.type == 'ARMATURE'][0]
    for o in novos:
        if o.type == 'MESH':
            o.hide_render = True
            o.hide_set(True)
    acoes = {a.name: a for a in bpy.data.actions if a not in antes_acao}
    for a in acoes.values():
        a.use_fake_user = False
    return arm, acoes


def _cadeia(arm):
    """Ossos em ordem de hierarquia (pai antes de filho)."""
    ordem = []

    def desce(b):
        ordem.append(b.name)
        for f in b.children:
            desce(f)
    for b in arm.data.bones:
        if b.parent is None:
            desce(b)
    return ordem


def _cabeca_mundo(arm, nome):
    return arm.matrix_world @ arm.data.bones[nome].head_local


class Alvo:
    """Cache do rig alvo: repouso, hierarquia e a referencia de silhueta."""

    def __init__(self, arm, fonte=None, mapa=MAPA):
        self.arm = arm
        self.mapa = {k: v for k, v in mapa.items() if k in arm.data.bones}
        self.ordem = _cadeia(arm)
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        self.pai = {b.name: (b.parent.name if b.parent else None)
                    for b in arm.data.bones}
        self.filhos = {b.name: [f.name for f in b.children] for b in arm.data.bones}
        self.q_rest = {n: _rot(m) for n, m in self.rest.items()}
        self.quadril = "hips" if "hips" in arm.data.bones else "Hips"
        self.ref = dict(self.q_rest)
        self._eixos()
        if fonte is not None:
            self._referencia(fonte)

    def _eixos(self):
        """Eixo de cada osso no espaco do proprio osso: cabeca -> cabeca do
        filho que continua a cadeia.

        Nos rigs feitos aqui isso e' o +Y do osso (osso conectado). No
        esqueleto Meshy NAO: o glTF nao guarda cauda, e o importador do
        Blender chuta uma — o Y do osso aponta pra qualquer lado. Apontar
        por esse Y mandaria o braco do Maycow pra onde a cauda chutada
        aponta. Osso sem filho (mao, ponta do pe') herda o eixo do pai.
        """
        ossos = self.arm.data.bones
        meshy = "Hips" in ossos
        cont = dict(DIR_FONTE)
        cont.update({"hips": "spine", "upper_chest": "neck", "head": None})
        self.eixo = {}
        self.comp = {}
        for n in self.ordem:
            b = ossos[n]
            alvo = cont.get(n, "") if n in cont else None
            filho = None
            if alvo and alvo in ossos:
                filho = ossos[alvo]
            elif len(b.children) == 1:
                filho = b.children[0]
            if filho is not None and (filho.head_local - b.head_local).length > 1e-6:
                d_mundo = (filho.head_local - b.head_local)
                self.comp[n] = d_mundo.length
                d_mundo = d_mundo.normalized()
            elif not meshy:
                # rig feito aqui: a cauda e' o fim de verdade do osso
                d_mundo = (b.tail_local - b.head_local).normalized()
                self.comp[n] = b.length
            elif b.parent is not None and b.parent.name in self.eixo:
                d_mundo = self.q_rest[b.parent.name] @ self.eixo[b.parent.name]
                self.comp[n] = 8.0          # cm: mao e ponta do pe' do Meshy
            else:
                d_mundo = self.q_rest[n] @ Vector((0, 1, 0))
                self.comp[n] = b.length
            self.eixo[n] = self.q_rest[n].inverted() @ d_mundo

    def dir_rest(self, nome):
        return (self.q_rest[nome] @ self.eixo[nome]).normalized()

    def _referencia(self, fonte):
        alinh = {}
        for alvo, fnome in self.mapa.items():
            if alvo in HERDA_ALINHAMENTO or fnome not in DIR_FONTE:
                continue
            ds = (_cabeca_mundo(fonte, DIR_FONTE[fnome])
                  - _cabeca_mundo(fonte, fnome)).normalized()
            dt = self._dir_alvo(alvo)
            alinh[alvo] = dt.rotation_difference(ds)
        for alvo, de in HERDA_ALINHAMENTO.items():
            if alvo in self.mapa and de in alinh:
                alinh[alvo] = alinh[de]
        for alvo, a in alinh.items():
            self.ref[alvo] = a @ self.q_rest[alvo]

    def _dir_alvo(self, alvo):
        # mesma definicao da fonte: cabeca -> cabeca do osso mapeado "filho"
        fnome = self.mapa[alvo]
        filho_f = DIR_FONTE.get(fnome)
        inv = {v: k for k, v in self.mapa.items()}
        if filho_f in inv and inv[filho_f] in self.arm.data.bones:
            return (self.arm.data.bones[inv[filho_f]].head_local
                    - self.arm.data.bones[alvo].head_local).normalized()
        return self.dir_rest(alvo)

    def subarvore(self, nome):
        out = [nome]
        for f in self.filhos[nome]:
            out += self.subarvore(f)
        return out

    # ------------------------------------------------------------------
    def aplicar(self, q_mundo, pos_quadril, quadro=None):
        """Escreve a pose (rotacoes de mundo por osso + cabeca do quadril) e,
        com `quadro`, grava chave. Osso fora de `q_mundo` fica no repouso
        relativo ao pai."""
        pose = {}
        for n in self.ordem:
            p = self.pai[n]
            if p is None:
                cab = self.rest[n].translation.copy()
                base = Matrix.Identity(4)
                ref_pai = Matrix.Identity(4)
            else:
                base = pose[p]
                ref_pai = self.rest[p]
                cab = (base @ ref_pai.inverted() @ self.rest[n]).translation
            if n == self.quadril and pos_quadril is not None:
                cab = pos_quadril
            if n in q_mundo:
                r = q_mundo[n].to_matrix().to_4x4()
            else:
                r = (base @ ref_pai.inverted() @ self.rest[n]).to_3x3().normalized().to_4x4()
            m = r.copy()
            m.translation = cab
            pose[n] = m
            pb = self.arm.pose.bones[n]
            if p is None:
                basis = self.rest[n].inverted() @ m
            else:
                basis = self.rest[n].inverted() @ ref_pai @ base.inverted() @ m
            loc, rot, _ = basis.decompose()
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = rot
            pb.location = loc
            if quadro is not None:
                pb.keyframe_insert("rotation_quaternion", frame=quadro)
                pb.keyframe_insert("location", frame=quadro)
        return pose


def nova_acao(arm, nome):
    """Cria (ou recria) uma acao vazia no `arm` e a deixa ativa."""
    velha = bpy.data.actions.get(nome)
    if velha:
        bpy.data.actions.remove(velha)
    acao = bpy.data.actions.new(nome)
    acao.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = acao
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
        pb.scale = Vector((1, 1, 1))
    return acao


def girar_subarvore(alvo, q_mundo, nome, rot, pivo_cache=None):
    """Aplica `rot` (mundo) no osso `nome` e em todos os descendentes."""
    for n in alvo.subarvore(nome):
        if n in q_mundo:
            q_mundo[n] = rot @ q_mundo[n]
        else:
            q_mundo[n] = rot @ alvo.q_rest[n]


def retarget(fonte, acao_fonte, alvo, nome, ini=None, fim=None, no_lugar=True,
             ajustes=None, velocidade=1.0, quadro0=0):
    """Copia `acao_fonte` (na armadura `fonte`) pro rig do `alvo` como `nome`.

    `ajustes(t, q_mundo, pos)`: chamado a cada quadro de saida (t em quadros
    desde o comeco do clipe novo), pode mexer em q_mundo/pos antes da gravacao.
    `velocidade` < 1 alonga o clipe (o andar lento da Dona Nice).
    Devolve o numero de quadros gravados.
    """
    cena = bpy.context.scene
    fonte.animation_data_create()
    fonte.animation_data.action = acao_fonte
    if acao_fonte.slots:
        fonte.animation_data.action_slot = acao_fonte.slots[0]
    a0, a1 = acao_fonte.frame_range
    ini = a0 if ini is None else ini
    fim = a1 if fim is None else fim

    # repouso da fonte (pose de repouso, sem acao)
    q_rest_f = {b.name: _rot(fonte.matrix_world @ b.matrix_local)
                for b in fonte.data.bones}
    quadril_f = alvo.mapa.get(alvo.quadril, "Hips")
    h_rest_f = fonte.matrix_world @ fonte.data.bones[quadril_f].head_local
    h_rest_a = alvo.rest[alvo.quadril].translation.copy()
    escala = h_rest_a.z / max(h_rest_f.z, 1e-4)

    acao = nova_acao(alvo.arm, nome)
    n_saida = int(round((fim - ini) / velocidade)) + 1
    for t in range(n_saida):
        f = ini + t * velocidade
        cena.frame_set(int(f), subframe=f - int(f))
        q = {}
        for a_nome, f_nome in alvo.mapa.items():
            pb = fonte.pose.bones.get(f_nome)
            if pb is None:
                continue
            qf = _rot(fonte.matrix_world @ pb.matrix)
            q[a_nome] = qf @ q_rest_f[f_nome].inverted() @ alvo.ref[a_nome]
        hf = fonte.matrix_world @ fonte.pose.bones[quadril_f].head
        delta = (hf - h_rest_f) * escala
        if no_lugar:
            delta.x = 0.0
            delta.y = 0.0
        pos = h_rest_a + delta
        if ajustes:
            pos = ajustes(t, q, pos) or pos
        alvo.aplicar(q, pos, quadro=quadro0 + t)
    return acao, n_saida


def pose_por_direcoes(alvo, direcoes, giros=None):
    """Rotacoes de mundo que apontam cada osso pra direcao pedida.

    `direcoes`: {osso: Vector mundo}. Osso sem direcao herda o giro do pai
    (fica parado em relacao a ele). `giros`: {osso: (eixo, angulo)} — torcao
    em torno do proprio eixo depois de apontar (punho, cabeca).
    Pernas/bracos sao processados em ordem de hierarquia: o giro do pai e'
    levado ao filho ANTES de o filho ser apontado, entao so' e' preciso dar
    direcao pro que importa.
    """
    q = {}
    for n in alvo.ordem:
        p = alvo.pai[n]
        if p is None:
            herdado = Quaternion()
        else:
            herdado = q[p] @ alvo.q_rest[p].inverted()
        atual = herdado @ alvo.q_rest[n]
        if n in direcoes:
            d_atual = atual @ alvo.eixo[n]
            atual = d_atual.rotation_difference(Vector(direcoes[n]).normalized()) @ atual
        if giros and n in giros:
            eixo = atual @ alvo.eixo[n]
            atual = Quaternion(eixo, giros[n]) @ atual
        q[n] = atual
    return q


def interpolar(qa, qb, t):
    out = {}
    for n in qa:
        out[n] = qa[n].slerp(qb.get(n, qa[n]), t) if n in qb else qa[n]
    for n in qb:
        if n not in out:
            out[n] = qb[n]
    return out


def suave(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)
