#!/usr/bin/env python3
"""Lapida a casa do Jimmy para ficar navegável (mesmo critério da casa da Dona Nice).

A cena `casa_jimmy_interior.tscn` foi gerada por um script que se perdeu; este
aqui EDITA a cena existente, e pode ser rodado de novo sem estragar nada (cada
passo regera do zero o que ele mesmo controla).

Critério (ver gerar_casa_nice.py): a cápsula do jogador tem 1,35 m de largura,
então toda passagem tem pelo menos 1,6 m e todo corredor entre móveis 1,5 m.

O que muda:
- Os vãos das portas dos quartos e do banheiro (parede sul dos corredores em
  z=10,15 e parede norte dos quartos em z=10,25) passam de 1,05-1,2 m para
  1,7 m (banheiro 1,6 m). As folhas viram portas de duas folhas abertas para
  dentro do cômodo, encostadas no batente, sem invadir o vão.
- Móveis que fechavam o caminho dentro dos quartos são reposicionados
  (MOVER, abaixo), sempre encostados na parede.

Uso:  python3 tools/godot/jimmy_house/ajustar_casa_jimmy.py
"""
import math
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
CENA = os.path.join(RAIZ, 'red-valve', 'scenes', 'stages', 'jimmy_house', 'casa_jimmy_interior.tscn')

ALTURA = 3.1          # pé-direito das paredes (centro em 1,55)
TOPO_VAO = 2.3        # verga das portas (a antiga também era 2,3)
ESP = 0.1

# (pai, prefixo, z, x_ini, x_fim, [(centro, largura), ...])
PAREDES = [
    ('estrutura/corredor_1', 'parede_sul', 10.15, 0.0, 5.5, [(2.5, 1.7)]),
    ('estrutura/corredor_2', 'parede_sul', 10.15, 5.5, 13.0, [(7.3, 1.7), (11.8, 1.7)]),
    ('estrutura/corredor_3', 'parede_sul', 10.15, 13.0, 20.0, [(15.65, 1.7), (18.6, 1.6)]),
    ('estrutura/q1', 'parede_norte', 10.25, 0.0, 5.0, [(2.5, 1.7)]),
    ('estrutura/q2', 'parede_norte', 10.25, 5.0, 9.6, [(7.3, 1.7)]),
    ('estrutura/q3', 'parede_norte', 10.25, 9.6, 14.0, [(11.8, 1.7)]),
    ('estrutura/q4', 'parede_norte', 10.25, 14.0, 17.3, [(15.65, 1.7)]),
    ('estrutura/banheiro', 'parede_norte', 10.25, 17.3, 20.0, [(18.6, 1.6)]),
]

# Portas de duas folhas: (sufixo, centro, largura, ângulo folha esquerda, ângulo folha direita).
# Ângulo em graus a partir da parede, abrindo para +Z (dentro do quarto).
# None = sem folha naquele lado (a do q3 está caída no chão).
PORTAS = [
    ('q1', 2.5, 1.7, 92, 78),
    ('q2', 7.3, 1.7, 100, 84),
    ('q3', 11.8, 1.7, None, 58),
    ('q4', 15.65, 1.7, 88, 96),
    ('banho', 18.6, 1.6, 95, 82),
]
Z_BATENTE = 10.3      # face de dentro da parede do quarto

# Móveis reposicionados: nome do nó -> (x, y, z, giro em graus ou None p/ manter).
# Mexe no nó em `mobilia/` e no `colisoes_mobilia/col_<nome>` junto.
MOVER = {
    # as malas ficavam coladas na parede entre a porta do q4 e a do banheiro e
    # comiam a aproximação das duas; vão para o fundo cego do corredor_1
    'malas_corredor': (0.36, 0.0, 8.35, 90),
    # a cômoda do q4 tampava a entrada (sobrava 1,55 m até a cama); desce para
    # o meio da parede leste, a luminária de pé continua no canto
    'comoda_q4': (16.86, 0.0, 13.0, None),
    'enfeite_q4': (16.86, 1.36, 13.0, None),
    # q3: caixa e cadeira caída abriam só uma fresta entre a cama e o armário
    'caixa_q3': (13.55, 0.0, 12.4, None),
    'cadeira_caida_q3': (13.35, 0.33, 13.55, None),
    # banheiro: o cesto fechava o caminho até o vaso
    'cesto_banheiro': (19.5, 0.0, 14.45, None),
}


def fmt(v):
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    return s.replace('.', 'p').replace('-', 'm')


def blocos(texto):
    partes = re.split(r'\n(?=\[)', texto)
    return partes


def cabecalho(b):
    m = re.match(r'\[node name="([^"]+)"(?: type="([^"]+)")? parent="([^"]+)"', b)
    return m.groups() if m else None


def pos_do(b):
    t = re.search(r'transform = Transform3D\(([^)]*)\)', b)
    if not t:
        return None
    return [float(x) for x in t.group(1).split(',')]


def tf(pos, giro=0.0):
    """Transform3D de nó girado `giro` rad em Y, emitido por LINHAS."""
    c, s = math.cos(giro), math.sin(giro)
    linhas = [c, 0, s, 0, 1, 0, -s, 0, c]
    nums = linhas + list(pos)
    return 'Transform3D(%s)' % ', '.join(('%.6f' % n).rstrip('0').rstrip('.') if n != 0 else '0' for n in nums)


class Recursos:
    def __init__(self, texto):
        self.existentes = set(re.findall(r'\[sub_resource type="[^"]+" id="([^"]+)"\]', texto))
        self.novos = []

    def caixa(self, dims, forma=False):
        rid = ('bs_' if forma else 'bm_') + '_'.join(fmt(d) for d in dims)
        if rid not in self.existentes:
            tipo = 'BoxShape3D' if forma else 'BoxMesh'
            self.novos.append('[sub_resource type="%s" id="%s"]\nsize = Vector3(%s, %s, %s)\n' % (
                tipo, rid, *[('%.4f' % d).rstrip('0').rstrip('.') for d in dims]))
            self.existentes.add(rid)
        return rid


def segmentos(x0, x1, vaos):
    """Peças cheias e vergas de uma parede com vãos."""
    cheios, vergas = [], []
    cursor = x0
    for c, w in sorted(vaos):
        a, b = c - w / 2, c + w / 2
        if a - cursor > 1e-3:
            cheios.append((cursor, a))
        vergas.append((a, b))
        cursor = b
    if x1 - cursor > 1e-3:
        cheios.append((cursor, x1))
    return cheios, vergas


def main():
    texto = open(CENA, encoding='utf-8').read()
    rec = Recursos(texto)
    bs = blocos(texto)

    # --- índice de formas existentes para numerar as novas
    max_forma = max(int(n) for n in re.findall(r'\[node name="forma_(\d+)"', texto))
    prox = [max_forma + 1]

    def nova_forma():
        n = prox[0]
        prox[0] += 1
        return 'forma_%d' % n

    alvo_z = {round(p[2], 3) for p in PAREDES}

    def eh_parede_alvo(b):
        h = cabecalho(b)
        if not h:
            return None
        nome, tipo, pai = h
        for i, (p_pai, pref, z, *_r) in enumerate(PAREDES):
            if pai == p_pai and nome.startswith(pref + '_'):
                return i
        return None

    def eh_forma_alvo(b):
        h = cabecalho(b)
        if not h or h[2] != 'colisao_estrutura':
            return False
        v = pos_do(b)
        if v is None:
            return False
        # formas das paredes de porta: z da parede, y=1,55 (cheia) ou >2 (verga)
        return round(v[11], 3) in alvo_z and (abs(v[10] - 1.55) < 1e-3 or v[10] > 2.0) and abs(v[0] - 1) < 1e-6

    def eh_folha(b):
        h = cabecalho(b)
        return bool(h) and h[2] == 'portas' and (
            re.match(r'(folha|macaneta)_porta_(q\d|banho)', h[0]) or h[0] == 'folha_q3_caida')

    saida = []
    emitida = set()
    portas_emitidas = False
    for b in bs:
        i = eh_parede_alvo(b)
        if i is not None:
            if i in emitida:
                continue
            emitida.add(i)
            saida.extend(gerar_parede(i, rec, nova_forma))
            continue
        if eh_forma_alvo(b):
            continue
        if eh_folha(b):
            if not portas_emitidas:
                portas_emitidas = True
                saida.extend(gerar_folhas(rec))
            continue
        h = cabecalho(b)
        if h and h[2] in ('mobilia', 'colisoes_mobilia'):
            b = mover(b, h)
        saida.append(b)

    # sub_resources novos entram antes do primeiro [node
    # (os blocos do split perderam só o '\n' que antecede o '['; os novos
    # terminam em '\n' para o join deixar a linha em branco de praxe)
    final = []
    inserido = False
    for b in saida:
        if not inserido and b.startswith('[node'):
            final.extend(rec.novos)
            inserido = True
        final.append(b)
    novo = '\n'.join(final)
    open(CENA, 'w', encoding='utf-8').write(novo)
    print('ok: %d paredes, %d recursos novos' % (len(emitida), len(rec.novos)))


def gerar_parede(i, rec, nova_forma):
    pai, pref, z, x0, x1, vaos = PAREDES[i]
    cheios, vergas = segmentos(x0, x1, vaos)
    malhas, formas = [], []
    k = 0
    pecas = [(a, b, ALTURA / 2, ALTURA) for a, b in cheios] + \
            [(a, b, TOPO_VAO + (ALTURA - TOPO_VAO) / 2, ALTURA - TOPO_VAO) for a, b in vergas]
    pecas.sort(key=lambda p: p[0])
    for a, b, yc, h in pecas:
        w = round(b - a, 4)
        cx = round((a + b) / 2, 4)
        dims = (w, round(h, 4), ESP)
        bm = rec.caixa(dims)
        bsr = rec.caixa(dims, forma=True)
        malhas.append('[node name="%s_%d" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("%s")\nmaterial_override = SubResource("mat_parede")\n' % (
            pref, k, pai, tf((cx, yc, z)), bm))
        formas.append('[node name="%s" type="CollisionShape3D" parent="colisao_estrutura"]\ntransform = %s\nshape = SubResource("%s")\n' % (
            nova_forma(), tf((cx, yc, z)), bsr))
        k += 1
    return malhas + formas


def gerar_folhas(rec):
    out = []
    for suf, c, w, ang_e, ang_d in PORTAS:
        larg = round(w / 2 - 0.01, 3)
        folha = rec.caixa((larg, 2.25, 0.055))
        mac = 'bm_0p06_0p06_0p18'
        for lado, ang in (('e', ang_e), ('d', ang_d)):
            if ang is None:
                continue
            a = math.radians(ang)
            if lado == 'e':
                dobradica = (c - w / 2 + 0.02, Z_BATENTE)
                dirx, dirz = math.cos(a), math.sin(a)
            else:
                dobradica = (c + w / 2 - 0.02, Z_BATENTE)
                dirx, dirz = -math.cos(a), math.sin(a)
            # +X local do nó aponta para (dirx, dirz): giro = atan2(-dirz, dirx)
            giro = math.atan2(-dirz, dirx)
            cx = dobradica[0] + dirx * (larg / 2 + 0.03)
            cz = dobradica[1] + dirz * (larg / 2 + 0.03)
            mx = dobradica[0] + dirx * (larg - 0.06)
            mz = dobradica[1] + dirz * (larg - 0.06)
            out.append('[node name="folha_porta_%s_%s" type="MeshInstance3D" parent="portas"]\ntransform = %s\nmesh = SubResource("%s")\nmaterial_override = SubResource("mat_madeira")\n' % (
                suf, lado, tf((cx, 1.125, cz), giro), folha))
            out.append('[node name="macaneta_porta_%s_%s" type="MeshInstance3D" parent="portas"]\ntransform = %s\nmesh = SubResource("%s")\nmaterial_override = SubResource("mat_madeira")\n' % (
                suf, lado, tf((mx, 1.05, mz), giro), mac))
        if suf == 'q3':
            # a folha esquerda caiu e está deitada no quarto
            caida = rec.caixa((larg, 0.06, 2.25))
            out.append('[node name="folha_q3_caida" type="MeshInstance3D" parent="portas"]\ntransform = %s\nmesh = SubResource("%s")\nmaterial_override = SubResource("mat_madeira")\n' % (
                tf((11.25, 0.05, 12.9), math.radians(18)), caida))
    return out


def mover(b, h):
    nome, tipo, pai = h
    chave = nome[4:] if pai == 'colisoes_mobilia' and nome.startswith('col_') else nome
    if chave not in MOVER:
        return b
    x, y, z, giro = MOVER[chave]
    v = pos_do(b)
    if giro is None:
        base = v[:9]
    else:
        g = math.radians(giro)
        c, s = math.cos(g), math.sin(g)
        sx = math.sqrt(v[0] ** 2 + v[6] ** 2)
        base = [c * sx, 0, s * sx, 0, v[4], 0, -s * sx, 0, c * sx]
    if pai == 'colisoes_mobilia' and y != v[10]:
        y = y  # a colisão acompanha o móvel
    nums = base + [x, y, z]
    novo = 'transform = Transform3D(%s)' % ', '.join(('%.6f' % n).rstrip('0').rstrip('.') if n != 0 else '0' for n in nums)
    return re.sub(r'transform = Transform3D\([^)]*\)', novo, b, count=1)


if __name__ == '__main__':
    main()
