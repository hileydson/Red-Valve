"""Gera as duas cenas editáveis da casa de Dona Nice com recursos já usados no jogo."""
from pathlib import Path
from math import atan2, cos, sin, pi

ROOT = Path(__file__).resolve().parents[3] / "red-valve"
DEST = ROOT / "scenes/stages/nice_house"
TEX = "res://assets/images/textures/polyhaven/"
PH = "res://assets/3d_model/polyhaven/"
MB = "res://assets/3d_model/mobilia/"


class Cena:
    def __init__(self):
        self.ext = []
        self.sub = []
        self.nodes = []
        self.meshes = {}
        self.shapes = {}
        self.models = {}

    def externo(self, typ, path, key):
        self.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{key}"]')
        return f'ExtResource("{key}")'

    def material(self, key, color, texture=None, glow=None):
        props = [f'albedo_color = Color({color})', 'roughness = 0.92']
        if texture:
            base = self.externo("Texture2D", TEX + texture + "_diff.jpg", key + "_diff")
            normal = self.externo("Texture2D", TEX + texture + "_nor_gl.jpg", key + "_normal")
            arm = self.externo("Texture2D", TEX + texture + "_arm.jpg", key + "_arm")
            props += [f'albedo_texture = {base}', 'normal_enabled = true',
                      f'normal_texture = {normal}', 'normal_scale = 0.8',
                      f'roughness_texture = {arm}', 'roughness_texture_channel = 1',
                      'ao_enabled = true', f'ao_texture = {arm}', 'ao_texture_channel = 0',
                      'uv1_triplanar = true', 'uv1_world_triplanar = true',
                      'uv1_scale = Vector3(0.55, 0.55, 0.55)']
        if glow:
            props += ['emission_enabled = true', f'emission = Color({glow})',
                      'emission_energy_multiplier = 1.4']
        self.sub.append(f'[sub_resource type="StandardMaterial3D" id="{key}"]\n' + '\n'.join(props))
        return f'SubResource("{key}")'

    def box_resource(self, dims, shape=False):
        dims = tuple(round(v, 3) for v in dims)
        cache = self.shapes if shape else self.meshes
        if dims not in cache:
            kind = "BoxShape3D" if shape else "BoxMesh"
            key = ("shape" if shape else "mesh") + str(len(cache) + 1)
            cache[dims] = key
            self.sub.append(f'[sub_resource type="{kind}" id="{key}"]\nsize = Vector3({dims[0]}, {dims[1]}, {dims[2]})')
        return f'SubResource("{cache[dims]}")'

    def node(self, name, typ=None, parent=".", props=(), instance=None):
        header = f'[node name="{name}"'
        if typ:
            header += f' type="{typ}"'
        if name not in ('casa_nice_exterior', 'casa_nice_interior'):
            header += f' parent="{parent}"'
        if instance:
            header += f' instance={instance}'
        header += ']'
        self.nodes.append(header + ('\n' + '\n'.join(props) if props else ''))

    @staticmethod
    def transform(pos, yaw=0, scale=1):
        x, y, z = pos
        c, s = cos(yaw) * scale, sin(yaw) * scale
        return f'Transform3D({c:.5f}, 0, {-s:.5f}, 0, {scale:.5f}, 0, {s:.5f}, 0, {c:.5f}, {x:.4f}, {y:.4f}, {z:.4f})'

    def box(self, name, pos, dims, material, parent="geometria", yaw=0, collision=False):
        props = [f'transform = {self.transform(pos, yaw)}',
                 f'mesh = {self.box_resource(dims)}', f'material_override = {material}']
        self.node(name, "MeshInstance3D", parent, props)
        if collision:
            self.node(name + "_forma", "CollisionShape3D", "colisoes",
                      [f'transform = {self.transform(pos, yaw)}',
                       f'shape = {self.box_resource(dims, True)}'])

    def model(self, name, resource, pos, yaw=0, scale=1, parent="objetos"):
        if resource not in self.models:
            key = f'modelo_{len(self.models) + 1}'
            self.models[resource] = self.externo("PackedScene", resource, key)
        self.node(name, parent=parent, instance=self.models[resource],
                  props=[f'transform = {self.transform(pos, yaw, scale)}'])

    def collider(self, name, pos, dims, yaw=0):
        self.node('col_'+name, 'CollisionShape3D', 'colisoes', [
            f'transform = {self.transform((pos[0], dims[1] * 0.5, pos[2]), yaw)}',
            f'shape = {self.box_resource(dims, True)}'])

    def physical_model(self, name, resource, pos, dims, yaw=0):
        if resource not in self.models:
            key = f'modelo_{len(self.models) + 1}'
            self.models[resource] = self.externo('PackedScene', resource, key)
        self.node(name, 'RigidBody3D', 'objetos', [
            f'transform = {self.transform(pos, yaw)}', 'collision_layer = 2',
            'collision_mask = 2', 'mass = 3.0', 'linear_damp = 2.0',
            'angular_damp = 3.0'])
        self.node(name+'_malha', parent='objetos/'+name,
                  instance=self.models[resource])
        self.node(name+'_colisao', 'CollisionShape3D', 'objetos/'+name, [
            f'transform = {self.transform((0, dims[1]*0.5, 0))}',
            f'shape = {self.box_resource(dims, True)}'])

    def light(self, name, pos, color, energy, radius, parent="luzes", flicker=False):
        props = [f'transform = {self.transform(pos)}', f'light_color = Color({color})',
                 f'light_energy = {energy}', f'omni_range = {radius}',
                 'shadow_enabled = true', 'light_volumetric_fog_energy = 0.25']
        if flicker:
            props.append('metadata/piscar = true')
        self.node(name, 'OmniLight3D', parent, props)

    def save(self, path, connections=()):
        body = ['[gd_scene format=3]', *self.ext, *self.sub, *self.nodes, *connections]
        path.write_text('\n\n'.join(body) + '\n', encoding='utf-8')


def exterior():
    c = Cena()
    script = c.externo('Script', 'res://scripts/stages/nice_house/casa_nice_exterior.gd', 'script')
    wall = c.material('parede', '0.34, 0.29, 0.26, 1', 'weathered_brown_planks')
    roof = c.material('telha', '0.27, 0.25, 0.28, 1', 'roof_slates_02')
    stone = c.material('pedra', '0.39, 0.37, 0.35, 1', 'brushed_concrete_03')
    wood = c.material('madeira', '0.24, 0.18, 0.15, 1', 'dark_wooden_planks')
    window = c.material('janela', '0.11, 0.055, 0.038, 1', glow='0.9, 0.34, 0.2, 1')
    red = c.material('sinal', '0.22, 0.035, 0.025, 1', glow='0.5, 0.03, 0.02, 1')
    c.node('casa_nice_exterior', 'Node3D', props=[f'script = {script}'])
    c.node('geometria', 'Node3D')
    c.node('colisoes', 'StaticBody3D', props=['collision_layer = 2', 'collision_mask = 0'])
    c.node('objetos', 'Node3D')
    c.node('luzes', 'Node3D')
    c.box('fundacao', (0, 0.22, 0), (9.2, 0.45, 10.4), stone, collision=True)
    c.box('corpo', (0, 2.1, 0), (9, 3.35, 10.2), wall, collision=True)
    # Porta na face sul (-Z); caixa do corpo bloqueia o prédio, como na casa do Jimmy.
    c.box('alpendre', (0, 0.12, -6.0), (4.2, 0.24, 2.1), wood, collision=True)
    c.box('degrau', (0, 0.055, -7.2), (3.1, 0.11, 0.65), stone, collision=True)
    for x in (-1.75, 1.75):
        c.box('coluna_%s' % x, (x, 1.7, -6.8), (0.18, 3.2, 0.18), wood)
    c.box('cobertura_alpendre', (0, 3.32, -6.0), (4.5, 0.2, 2.5), roof)
    for lado, angulo in [('oeste', 0.27), ('leste', -0.27)]:
        x = -2.4 if lado == 'oeste' else 2.4
        co, si = cos(angulo), sin(angulo)
        c.node('telhado_'+lado, 'MeshInstance3D', 'geometria', [
            f'transform = Transform3D({co:.5f}, {si:.5f}, 0, {-si:.5f}, {co:.5f}, 0, 0, 0, 1, {x}, 4.1, 0)',
            f'mesh = {c.box_resource((5.2, 0.28, 11.0))}', f'material_override = {roof}'])
    c.box('cumeeira', (0, 4.8, 0), (0.3, 0.3, 11), wood)
    c.box('porta', (0, 1.37, -5.18), (1.45, 2.5, 0.12), wood)
    c.box('fechadura', (0.52, 1.2, -5.27), (0.1, 0.12, 0.1), stone)
    for side in (-1, 1):
        x = side * 2.9
        c.box('janela_frente_%s' % side, (x, 2.15, -5.2), (1.35, 1.45, 0.07), window)
        c.box('postigo_esq_%s' % side, (x-0.78, 2.15, -5.28), (0.16, 1.7, 0.1), wood)
        c.box('postigo_dir_%s' % side, (x+0.78, 2.15, -5.28), (0.16, 1.7, 0.1), wood)
    c.box('janela_lateral', (4.56, 2.1, 2.2), (0.08, 1.3, 1.35), window)
    c.box('chamine', (-2.6, 5.2, 2.6), (0.85, 2.4, 0.85), stone)
    c.box('placa_porta', (0, 2.78, -5.29), (1.05, 0.38, 0.06), red)
    c.node('placa_nice', 'Label3D', props=[f'transform = {c.transform((0, 2.76, -5.34), pi)}',
                                           'pixel_size = 0.002', 'font_size = 28',
                                           'modulate = Color(0.95, 0.78, 0.62, 1)', 'text = ""'])
    c.model('cadeira_balanco', PH+'Rockingchair_01/Rockingchair_01_1k.gltf', (-2.1, 0.25, -5.95), 0.3)
    c.model('vaso_entrada', PH+'planter_box_02/planter_box_02_1k.gltf', (3.5, 0.05, -6.1), 0.3)
    c.model('tronco_seco', PH+'dead_tree_trunk_02/dead_tree_trunk_02_1k.gltf', (-6.0, 0, 2.2), 0.3)
    c.model('barril', PH+'Barrel_02/Barrel_02_1k.gltf', (5.1, 0, -3.6), 0.4)
    c.model('caixa', PH+'cardboard_box_01/cardboard_box_01_1k.gltf', (5.9, 0, -3.3), 0.1)
    c.light('luz_alpendre', (0, 2.75, -6), '1, 0.52, 0.29, 1', 1.5, 6)
    c.light('luz_janela', (-1, 2.4, -4.9), '0.75, 0.16, 0.12, 1', 0.7, 4)
    c.node('area_entrada', 'Area3D', props=[f'transform = {c.transform((0, 1.25, -6.5))}', 'collision_layer = 0', 'collision_mask = 1', 'monitorable = false'])
    c.node('CollisionShape3D', 'CollisionShape3D', 'area_entrada',
           [f'shape = {c.box_resource((2.7, 2.5, 2.2), True)}'])
    c.node('ponto_de_saida', 'Marker3D', props=[f'transform = {c.transform((0, 0.35, -8.1))}'])
    c.save(DEST/'casa_nice_exterior.tscn')


# ==============================================================================
# INTERIOR
#
# A casa por dentro (9 x 10 m, um andar so'), com a porta da rua no meio da
# frente (-Z):
#
#     z  4.9  +------------------+---------------------------+
#             |  QUARTO          |  O COMODO DO RITUAL       |
#             |  (cama, comoda,  |  (pentagrama, laje, altar,|
#             |   espelho)       |   quadro de desaparecidos)|
#     z -0.2  +----[ porta ]-----+--[ porta ]----------------+
#             |  SALA                    |  COZINHA          |
#             |  (sofa, relogio, estante)[ passagem ]        |
#     z -4.9  +----------[ entrada ]-----+-------------------+
#           x -4.4                       1.2                4.4
#
# A porta do ritual fica alinhada com a da rua: quem entra ja' ve' o brilho
# vermelho das velas no fundo da casa.
#
# O JOGADOR E' LARGO. A capsula dele tem 1,35 m de lado e chega a 1,44 m
# atras da origem (ela gira com a camera). Por isso toda passagem tem 1,6 m ou
# mais, os moveis ficam encostados nas paredes e cada comodo guarda um
# corredor livre da porta ate' o miolo. A casa antiga tinha portas de 0,8-1 m
# (a da rua com um pedaco de parede NO MEIO) e moveis no caminho.
# ==============================================================================

ALTURA = 3.0          # pe'-direito (o forro comeca em 3,06)
ESP = 0.2             # parede externa
ESP_INT = 0.15        # divisoria
VAO_ALTO = 2.3        # topo das portas e passagens
X_COZINHA = 1.2       # divisoria sala | cozinha
Z_FUNDOS = -0.2       # divisoria frente | fundos
X_QUARTO = -0.9       # divisoria quarto | ritual


def _giro(pos, giro=0.0, escala=1.0):
    """Transform3D com rotacao Y de VERDADE (`giro` positivo = anti-horario
    visto de cima, como `rotation.y`): o +Z do modelo vai pra (sen, 0, cos).
    O `Cena.transform` antigo gira ao contrario — fica como esta' pro
    exterior, que foi afinado nele."""
    x, y, z = pos
    co, si = cos(giro) * escala, sin(giro) * escala
    return (f'Transform3D({co:.5f}, 0, {si:.5f}, 0, {escala:.5f}, 0, {-si:.5f}, 0, {co:.5f}, '
            f'{x:.4f}, {y:.4f}, {z:.4f})')


def _deitado(pos, giro=0.0):
    """Transform3D de algo DEITADO (o -Z do Label3D olhando pro teto)."""
    x, y, z = pos
    co, si = cos(giro), sin(giro)
    # gira -90 graus em X (deita) e depois `giro` em Y
    return (f'Transform3D({co:.5f}, {si:.5f}, 0, 0, 0, 1, {si:.5f}, {-co:.5f}, 0, '
            f'{x:.4f}, {y:.4f}, {z:.4f})')


class Casa(Cena):
    """A Cena com as pecas da casa: paredes com vao, modelos pela rotacao de
    verdade, velas, decalques de sangue, escritas e os itens pegaveis."""

    def __init__(self):
        super().__init__()
        self.n = {}

    def nome(self, base):
        self.n[base] = self.n.get(base, 0) + 1
        return base if self.n[base] == 1 else '%s_%d' % (base, self.n[base])

    def caixa(self, nome, pos, dims, mat, giro=0.0, pai='geometria', colisao=False):
        nome = self.nome(nome)
        self.node(nome, 'MeshInstance3D', pai, [
            f'transform = {_giro(pos, giro)}', f'mesh = {self.box_resource(dims)}',
            f'material_override = {mat}'])
        if colisao:
            self.node(nome + '_forma', 'CollisionShape3D', 'colisoes', [
                f'transform = {_giro(pos, giro)}', f'shape = {self.box_resource(dims, True)}'])

    def solido(self, nome, pos, dims, giro=0.0):
        """So' a colisao (caixa apoiada no chao em `pos`)."""
        self.node(self.nome('col_' + nome), 'CollisionShape3D', 'colisoes', [
            f'transform = {_giro((pos[0], pos[1] + dims[1] * 0.5, pos[2]), giro)}',
            f'shape = {self.box_resource(dims, True)}'])

    def modelo(self, nome, recurso, pos, giro=0.0, escala=1.0, pai='objetos', solido=None):
        if recurso not in self.models:
            self.models[recurso] = self.externo('PackedScene', recurso, 'modelo_%d' % (len(self.models) + 1))
        nome = self.nome(nome)
        self.node(nome, parent=pai, instance=self.models[recurso],
                  props=[f'transform = {_giro(pos, giro, escala)}'])
        if solido:
            self.solido(nome, pos, solido, giro)

    def fisico(self, nome, recurso, pos, dims, giro=0.0):
        if recurso not in self.models:
            self.models[recurso] = self.externo('PackedScene', recurso, 'modelo_%d' % (len(self.models) + 1))
        nome = self.nome(nome)
        self.node(nome, 'RigidBody3D', 'objetos', [
            f'transform = {_giro(pos, giro)}', 'collision_layer = 2', 'collision_mask = 2',
            'mass = 3.0', 'linear_damp = 2.0', 'angular_damp = 3.0'])
        self.node(nome + '_malha', parent='objetos/' + nome, instance=self.models[recurso])
        self.node(nome + '_colisao', 'CollisionShape3D', 'objetos/' + nome, [
            f'transform = {_giro((0, dims[1] * 0.5, 0))}', f'shape = {self.box_resource(dims, True)}'])

    def parede(self, nome, eixo, coord, a, b, mat_neg, mat_pos, vaos=(), esp=ESP, cortes=()):
        """Parede reta de `a` a `b` (em X se eixo == 'x', na linha z = coord;
        em Z se eixo == 'z', na linha x = coord), com `vaos` = [(de, ate')]
        abertos ate' VAO_ALTO, com verga e batente.

        Cada face tem o material do comodo pra onde olha (`mat_neg` pro lado
        de coordenada menor). Um material pode ser funcao da posicao ao longo
        da parede, pra parede que atravessa dois comodos; `cortes` sao os
        pontos onde ela muda de comodo. A colisao e' uma caixa so', inteira."""
        pontos = sorted({a, b, *cortes, *[v for vao in vaos for v in vao]})
        dentro = lambda m: any(v0 <= m <= v1 for v0, v1 in vaos)
        for i in range(len(pontos) - 1):
            p0, p1 = pontos[i], pontos[i + 1]
            meio, comp = (p0 + p1) * 0.5, p1 - p0
            if comp < 0.01:
                continue
            aberto = dentro(meio)
            y0, alt = (VAO_ALTO, ALTURA - VAO_ALTO) if aberto else (0.0, ALTURA)
            for lado, mat in ((-1, mat_neg), (1, mat_pos)):
                mat = mat(meio) if callable(mat) else mat
                off = lado * esp * 0.25
                if eixo == 'x':
                    pos, dims = (meio, y0 + alt * 0.5, coord + off), (comp, alt, esp * 0.5)
                else:
                    pos, dims = (coord + off, y0 + alt * 0.5, meio), (esp * 0.5, alt, comp)
                self.caixa('%s_%d' % (nome, i), pos, dims, mat)
            if eixo == 'x':
                pos, dims = (meio, y0 + alt * 0.5, coord), (comp, alt, esp)
            else:
                pos, dims = (coord, y0 + alt * 0.5, meio), (esp, alt, comp)
            self.node(self.nome('%s_forma' % nome), 'CollisionShape3D', 'colisoes', [
                f'transform = {_giro(pos)}', f'shape = {self.box_resource(dims, True)}'])
        # batente de madeira em volta de cada vao, nas duas faces
        for v0, v1 in vaos:
            for lado in (-1, 1):
                d = lado * (esp * 0.5 + 0.015)
                for x, comp_ in ((v0, None), (v1, None)):
                    pos = (x, VAO_ALTO * 0.5, coord + d) if eixo == 'x' else (coord + d, VAO_ALTO * 0.5, x)
                    dims = (0.09, VAO_ALTO, 0.04) if eixo == 'x' else (0.04, VAO_ALTO, 0.09)
                    self.caixa(nome + '_batente', pos, dims, self.mats['batente'])
                pos = ((v0 + v1) * 0.5, VAO_ALTO + 0.045, coord + d) if eixo == 'x' else (coord + d, VAO_ALTO + 0.045, (v0 + v1) * 0.5)
                dims = (v1 - v0 + 0.18, 0.09, 0.04) if eixo == 'x' else (0.04, 0.09, v1 - v0 + 0.18)
                self.caixa(nome + '_batente', pos, dims, self.mats['batente'])

    def janela_tapada(self, nome, pos, giro):
        """Janela vista de dentro: moldura, vidro escuro e tabuas pregadas de
        atravessado. `pos` e' o centro, encostado na face da parede."""
        fx, fz = sin(giro), cos(giro)
        p = lambda d, y=0.0, lat=0.0: (pos[0] + fx * d + cos(giro) * lat, pos[1] + y, pos[2] + fz * d - sin(giro) * lat)
        self.caixa(nome + '_vidro', p(0.01), (1.25, 1.35, 0.02), self.mats['vidro'], giro)
        for lat, y, w, h in ((0, 0.72, 1.45, 0.1), (0, -0.72, 1.45, 0.12), (-0.68, 0, 0.1, 1.45), (0.68, 0, 0.1, 1.45)):
            self.caixa(nome + '_moldura', p(0.03, y, lat), (w, h, 0.06), self.mats['batente'], giro)
        for i, (y, inc) in enumerate(((0.42, 0.10), (0.02, -0.07), (-0.40, 0.05))):
            nome_t = self.nome(nome + '_tabua')
            x, yy, z = p(0.075, y)
            co, si, ci, sn = cos(giro), sin(giro), cos(inc), sin(inc)
            # tabua torta: inclinacao `inc` em volta da normal da parede, depois o giro
            self.node(nome_t, 'MeshInstance3D', 'geometria', [
                f'transform = Transform3D({co * ci:.5f}, {-co * sn:.5f}, {si:.5f}, {sn:.5f}, {ci:.5f}, 0, '
                f'{-si * ci:.5f}, {si * sn:.5f}, {co:.5f}, {x:.4f}, {yy:.4f}, {z:.4f})',
                f'mesh = {self.box_resource((1.6, 0.17, 0.035))}',
                f'material_override = {self.mats["tabua"]}'])

    def vela(self, nome, pos, altura=0.2):
        nome = self.nome(nome)
        x, y, z = pos
        self.node(nome, 'MeshInstance3D', 'objetos', [
            f'transform = {_giro((x, y + altura * 0.5, z))}',
            f'mesh = {self.cilindro(0.026, altura)}', f'material_override = {self.mats["cera"]}'])
        self.node('chama', 'MeshInstance3D', 'objetos/' + nome, [
            f'transform = {_giro((0, altura * 0.5 + 0.03, 0))}',
            'mesh = SubResource("chama_quad")', 'cast_shadow = 0'])

    def cilindro(self, raio, altura):
        chave = ('cil', round(raio, 3), round(altura, 3))
        if chave not in self.meshes:
            ident = 'cil%d' % (len(self.meshes) + 1)
            self.meshes[chave] = ident
            self.sub.append(f'[sub_resource type="CylinderMesh" id="{ident}"]\ntop_radius = {raio * 0.9}\n'
                            f'bottom_radius = {raio}\nheight = {altura}\nradial_segments = 10\nrings = 1')
        return f'SubResource("{self.meshes[chave]}")'

    def sangue(self, nome, textura, pos, tam, giro=0.0, parede=None, opac=1.0):
        """Decalque de sangue. No chao projeta pra baixo; numa parede
        (`parede` = giro da face) ele deita de lado e projeta contra ela."""
        nome = self.nome(nome)
        if parede is None:
            tr = _giro(pos, giro)
        else:
            fx, fz = sin(parede), cos(parede)
            # o -Y do decalque aponta pra dentro da parede (contra a normal)
            x, y, z = pos
            tr = (f'Transform3D({cos(parede):.5f}, {fx:.5f}, 0, 0, 0, -1, {-sin(parede):.5f}, {fz:.5f}, 0, '
                  f'{x:.4f}, {y:.4f}, {z:.4f})')
        self.node(nome, 'Decal', 'sangue', [
            f'transform = {tr}', f'size = Vector3({tam[0]}, {tam[1]}, {tam[2]})',
            f'texture_albedo = {self.texturas[textura]}', f'texture_orm = {self.texturas[textura + "_orm"]}',
            f'albedo_mix = {opac}', 'upper_fade = 0.15', 'lower_fade = 0.15'])

    def escrita(self, nome, chave, pos, giro, tam=64, cor='0.78, 0.07, 0.05, 1', px=0.004):
        """Frase dela na parede, a sangue. O texto vem do CSV (metadata
        `chave`, traduzida pelo script da cena) e RECEBE luz: escrita a
        sangue nao brilha no escuro."""
        self.node(nome, 'Label3D', props=[
            f'transform = {_giro(pos, giro)}', f'pixel_size = {px}', f'font_size = {tam}',
            f'font = {self.fonte}', 'shaded = true', 'double_sided = false',
            f'modulate = Color({cor})', 'outline_size = 0', 'text = ""',
            f'metadata/chave = "{chave}"'])

    def pegavel(self, nome, item, qtd, pos, giro, prompt, texto, repetido, modelo, modelo_tr):
        """Item que o jogador pega (o mesmo script dos itens do balcao do
        hospital: prompt pela mira, tela de item obtido, id proprio no save)."""
        if modelo not in self.models:
            self.models[modelo] = self.externo('PackedScene', modelo, 'modelo_%d' % (len(self.models) + 1))
        self.node(nome, 'Node3D', props=[
            f'transform = {_giro(pos, giro)}', f'script = {self.script_item}',
            f'metadata/id = "casa_nice_{nome}"', f'metadata/item = "{item}"',
            f'metadata/quantidade = {qtd}', f'metadata/prompt = "{prompt}"',
            f'metadata/texto = "{texto}"', f'metadata/repetido = "{repetido}"'])
        self.node('modelo', parent=nome, instance=self.models[modelo],
                  props=[f'transform = {modelo_tr}'])
        self.node('area', 'Area3D', nome, [
            f'transform = {_giro((0, 0.25, 0))}', 'collision_layer = 0', 'monitorable = false'])
        self.node('forma', 'CollisionShape3D', nome + '/area',
                  [f'shape = {self.box_resource((2.6, 2.4, 2.6), True)}'])


def interior():
    c = Casa()
    c.externo('PackedScene', 'res://scenes/player/player.tscn', 'player')
    c.externo('PackedScene', 'res://scenes/configs/pause.tscn', 'pause')
    c.externo('PackedScene', 'res://scenes/configs/fade.tscn', 'fade')
    script = c.externo('Script', 'res://scripts/stages/nice_house/casa_nice_interior.gd', 'script')
    c.script_item = c.externo('Script', 'res://scripts/stages/hospital/item_de_balcao.gd', 'item_script')
    c.fonte = c.externo('FontFile', 'res://assets/fonts/Nosifer-Regular.ttf', 'fonte_sangue')
    ambience = c.externo('AudioStream', 'res://assets/sounds/episodios/ambiente_noise_sublime.mp3', 'ambiente')
    c.texturas = {}
    for t in ('sangue_poca', 'sangue_rastro', 'sangue_respingo'):
        c.texturas[t] = c.externo('Texture2D', 'res://assets/images/textures/igreja/%s.png' % t, t)
        c.texturas[t + '_orm'] = c.externo('Texture2D', 'res://assets/images/textures/igreja/%s_orm.png' % t, t + '_orm')

    piso_sala = c.material('chao', '0.40, 0.34, 0.29, 1', 'wood_floor_worn')
    piso_cozinha = c.material('chao_cozinha', '0.46, 0.43, 0.38, 1', 'dirty_tiles')
    piso_ritual = c.material('chao_ritual', '0.24, 0.19, 0.17, 1', 'dark_wooden_planks')
    papel = c.material('papel_parede', '0.52, 0.47, 0.40, 1', 'decrepit_wallpaper')
    papel_quarto = c.material('papel_quarto', '0.44, 0.40, 0.42, 1', 'decrepit_wallpaper')
    azulejo = c.material('azulejo', '0.55, 0.54, 0.48, 1', 'dirty_tiles')
    reboco = c.material('reboco_ritual', '0.36, 0.29, 0.26, 1', 'peeling_painted_wall')
    forro = c.material('forro', '0.30, 0.25, 0.22, 1', 'dark_wooden_planks')
    madeira = c.material('madeira', '0.30, 0.22, 0.18, 1', 'dark_wooden_planks')
    c.mats = {
        'batente': madeira,
        'tabua': c.material('tabua', '0.36, 0.28, 0.22, 1', 'weathered_brown_planks'),
        'vidro': c.material('vidro', '0.05, 0.06, 0.09, 1', glow='0.05, 0.07, 0.11, 1'),
        'cera': c.material('cera', '0.62, 0.55, 0.46, 1'),
    }
    couro = c.material('couro', '0.10, 0.07, 0.05, 1')
    laje = c.material('laje', '0.30, 0.28, 0.27, 1', 'brushed_concrete_03')
    tapete = c.material('tapete', '0.22, 0.07, 0.06, 1')
    giz = c.material('giz', '0.42, 0.05, 0.04, 1')
    papel_nota = c.material('papel_nota', '0.62, 0.57, 0.46, 1')
    c.sub.append('[sub_resource type="StandardMaterial3D" id="chama_mat"]\ntransparency = 1\nblend_mode = 1\n'
                 'shading_mode = 0\nalbedo_color = Color(1, 0.55, 0.2, 0.9)\nbillboard_mode = 2\n'
                 'billboard_keep_scale = true')
    c.sub.append('[sub_resource type="QuadMesh" id="chama_quad"]\nmaterial = SubResource("chama_mat")\n'
                 'size = Vector2(0.035, 0.07)')
    c.sub.append('[sub_resource type="Environment" id="ambiente_casa"]\nbackground_mode = 1\n'
                 'background_color = Color(0.009, 0.009, 0.014, 1)\nambient_light_source = 2\n'
                 'ambient_light_color = Color(0.20, 0.15, 0.15, 1)\nambient_light_energy = 0.7\n'
                 'tonemap_mode = 3\nglow_enabled = true\nglow_intensity = 0.42\nfog_enabled = true\n'
                 'fog_light_color = Color(0.16, 0.08, 0.09, 1)\nfog_density = 0.012\nadjustment_enabled = true\n'
                 'adjustment_contrast = 1.09\nadjustment_saturation = 0.74')
    c.sub.append('[sub_resource type="CameraAttributesPractical" id="camera_casa"]')

    c.node('casa_nice_interior', 'Node3D', props=[f'script = {script}'])
    c.node('Pause', parent='.', instance='ExtResource("pause")')
    c.node('fade', parent='.', instance='ExtResource("fade")')
    c.node('Player', parent='.', instance='ExtResource("player")',
           props=[f'transform = {_giro((0, 1.05, -3.5), pi)}'])
    c.node('WorldEnvironment', 'WorldEnvironment', props=[
        'environment = SubResource("ambiente_casa")', 'camera_attributes = SubResource("camera_casa")'])
    for no in ('geometria', 'objetos', 'luzes', 'sangue'):
        c.node(no, 'Node3D')
    c.node('colisoes', 'StaticBody3D', props=['collision_layer = 2', 'collision_mask = 0'])

    # ---------------------------------------------------------------- casca
    # piso e forro por comodo (cada um com o seu material); a colisao do piso
    # e do forro e' uma caixa inteira
    for nome, x0, x1, z0, z1, mat in (('sala', -4.5, X_COZINHA, -5.0, Z_FUNDOS, piso_sala),
                                      ('cozinha', X_COZINHA, 4.5, -5.0, Z_FUNDOS, piso_cozinha),
                                      ('quarto', -4.5, X_QUARTO, Z_FUNDOS, 5.0, piso_sala),
                                      ('ritual', X_QUARTO, 4.5, Z_FUNDOS, 5.0, piso_ritual)):
        c.caixa('piso_' + nome, ((x0 + x1) / 2, -0.16, (z0 + z1) / 2), (x1 - x0, 0.32, z1 - z0), mat)
        c.caixa('forro_' + nome, ((x0 + x1) / 2, ALTURA + 0.18, (z0 + z1) / 2), (x1 - x0, 0.36, z1 - z0), forro)
    c.solido('piso', (0, -0.32, 0), (9.2, 0.32, 10.2))
    c.solido('forro', (0, ALTURA + 0.06, 0), (9.2, 0.32, 10.2))

    frente = lambda x: papel if x < X_COZINHA else azulejo
    fundos = lambda x: papel_quarto if x < X_QUARTO else reboco
    c.parede('parede_frente', 'x', -5.0, -4.6, 4.6, papel, frente, vaos=[(-0.8, 0.8)], cortes=[X_COZINHA])
    c.parede('parede_fundo', 'x', 5.0, -4.6, 4.6, fundos, papel, cortes=[X_QUARTO])
    c.parede('parede_oeste', 'z', -4.5, -5.0, 5.0, papel, papel)
    c.parede('parede_leste', 'z', 4.5, -5.0, 5.0, lambda z: azulejo if z < Z_FUNDOS else reboco, papel,
             cortes=[Z_FUNDOS])
    c.parede('divisoria_cozinha', 'z', X_COZINHA, -4.9, Z_FUNDOS - ESP_INT * 0.5, papel, azulejo,
             vaos=[(-3.0, -1.3)], esp=ESP_INT)
    c.parede('divisoria_fundos', 'x', Z_FUNDOS, -4.4, 4.4, frente, fundos,
             vaos=[(-3.4, -1.8), (-0.6, 1.0)], esp=ESP_INT, cortes=[X_QUARTO, X_COZINHA])
    c.parede('divisoria_quarto', 'z', X_QUARTO, Z_FUNDOS + ESP_INT * 0.5, 4.9, papel_quarto, reboco, esp=ESP_INT)
    # a folha da porta da rua, aberta pra dentro e encostada (sem colisao)
    c.caixa('porta_saida_folha', (0.8, 1.15, -4.18), (0.06, 2.25, 1.45), madeira)
    c.caixa('rodape_sala', (-1.4, 0.06, -4.88), (6.0, 0.12, 0.02), madeira)

    # janelas tapadas, onde a casa tem janela por fora
    c.janela_tapada('janela_sala', (-2.9, 1.75, -4.9), 0.0)
    c.janela_tapada('janela_cozinha', (2.9, 1.75, -4.9), 0.0)
    c.janela_tapada('janela_ritual', (4.4, 1.75, 2.2), -pi / 2)

    # ---------------------------------------------------------------- sala
    # Uma senhora morava aqui: sofa velho, relogio de pe', estante. A cadeira
    # de balanco olha pro canto.
    c.modelo('sofa', MB + 'tiny_living_lovely_loveseat_12.tscn', (-4.0, 0, -2.6), pi / 2, solido=(1.83, 0.9, 0.78))
    c.caixa('tapete', (-2.6, 0.005, -2.6), (2.4, 0.01, 1.7), tapete)
    c.modelo('mesa_centro', PH + 'side_table_01/side_table_01_1k.gltf', (-2.9, 0, -2.6), 0.0, solido=(0.56, 0.55, 0.46))
    c.modelo('lamparina_sala', PH + 'vintage_oil_lamp/vintage_oil_lamp_1k.gltf', (-2.95, 0.55, -2.55), 0.4, 0.8)
    c.fisico('cadeira_balanco', PH + 'Rockingchair_01/Rockingchair_01_1k.gltf', (-3.75, 0, -4.2),
             (0.72, 1.0, 0.85), -3 * pi / 4)
    c.modelo('relogio', PH + 'vintage_grandfather_clock_01/vintage_grandfather_clock_01_1k.gltf',
             (-1.5, 0, -4.66), 0.0, solido=(0.64, 2.2, 0.44))
    c.modelo('estante', PH + 'wooden_bookshelf_worn/wooden_bookshelf_worn_1k.gltf', (-4.1, 0, -0.98), pi / 2,
             solido=(1.38, 2.06, 0.6))
    c.modelo('quadro_sofa', PH + 'fancy_picture_frame_01/fancy_picture_frame_01_1k.gltf', (-4.39, 1.6, -2.6), pi / 2)
    c.modelo('quadro_torto', PH + 'hanging_picture_frame_01/hanging_picture_frame_01_1k.gltf', (-1.2, 1.65, -0.29), pi)
    c.modelo('relogio_parede', PH + 'wall_clock/wall_clock_1k.gltf', (-0.6, 2.65, -4.89), 0.0)
    c.modelo('lanterna_chao', PH + 'wooden_lantern_01/wooden_lantern_01_1k.gltf', (-4.05, 0, -0.1), 0.3)

    # ---------------------------------------------------------------- cozinha
    c.modelo('armario_cozinha', MB + 'cozinha_armario_leve.tscn', (4.16, 0.49, -3.7), -pi / 2, solido=(1.9, 0.97, 0.5))
    c.modelo('fogao', PH + 'electric_stove/electric_stove_1k.gltf', (4.1, 0, -2.25), -pi / 2, solido=(0.5, 0.86, 0.66))
    c.modelo('mesa_cozinha', PH + 'WoodenTable_03/WoodenTable_03_1k.gltf', (2.95, 0, -4.6), 0.0, solido=(1.34, 0.83, 0.6))
    c.fisico('cadeira_cozinha', PH + 'painted_wooden_chair_01/painted_wooden_chair_01_1k.gltf', (2.75, 0, -3.75),
             (0.45, 0.96, 0.55), pi)
    c.modelo('latas', PH + 'russian_food_cans_01/russian_food_cans_01_1k.gltf', (3.35, 0.83, -4.62), 0.5)
    c.modelo('rato_mesa', PH + 'street_rat/street_rat_1k.gltf', (3.45, 0.83, -4.42), 2.2, 1.4)
    c.modelo('lata_chao', PH + 'can_rusted/can_rusted_1k.gltf', (2.1, 0, -0.75), 0.0)
    c.fisico('balde', PH + 'wooden_bucket_01/wooden_bucket_01_1k.gltf', (2.05, 0, -4.5), (0.37, 0.55, 0.35))
    c.modelo('lixo', PH + 'trash_pile_clutter/trash_pile_clutter_1k.gltf', (3.75, 0, -0.85), 0.4)
    c.modelo('rato_lixo', PH + 'street_rat/street_rat_1k.gltf', (3.2, 0, -1.15), -0.7, 1.4)
    c.modelo('ratoeira', PH + 'mousetrap/mousetrap_1k.gltf', (2.3, 0, -1.8), 0.9)

    # ---------------------------------------------------------------- quarto
    c.modelo('cama', PH + 'old_bed_frame/old_bed_frame_1k.gltf', (-3.93, 0, 3.88), pi, solido=(0.92, 0.65, 2.02))
    c.modelo('criado_mudo', PH + 'painted_wooden_nightstand/painted_wooden_nightstand_1k.gltf', (-3.1, 0, 4.62), pi,
             solido=(0.5, 0.62, 0.52))
    c.modelo('lamparina_quarto', PH + 'vintage_oil_lamp/vintage_oil_lamp_1k.gltf', (-2.95, 0.62, 4.7), 0.0, 0.7)
    c.modelo('comoda', PH + 'painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf', (-1.29, 0, 2.7), -pi / 2,
             solido=(1.2, 1.18, 0.63))
    c.modelo('espelho_quarto', PH + 'ornate_mirror_01/ornate_mirror_01_1k.gltf', (-0.99, 1.75, 2.7), -pi / 2, 1.3)
    c.modelo('mala', PH + 'vintage_suitcase/vintage_suitcase_1k.gltf', (-4.27, 0, 1.75), pi / 2, solido=(1.62, 0.57, 0.26))
    c.modelo('quadro_quarto', PH + 'hanging_picture_frame_03/hanging_picture_frame_03_1k.gltf', (-2.2, 1.85, 4.89), pi)
    c.fisico('caixa_quarto', PH + 'cardboard_box_01/cardboard_box_01_1k.gltf', (-1.3, 0, 4.4), (0.4, 0.35, 0.53), 0.3)

    # ---------------------------------------------------------------- ritual
    # O coracao da casa: o circulo riscado no chao, a laje de pedra com as
    # correias no meio dele, o altar de velas no fundo e, na parede, o quadro
    # dos desaparecidos — as criancas que ela levou pro "outro lado".
    cx, cz, raio = 1.75, 2.1, 1.3
    for i in range(20):
        a0, a1 = 2 * pi * i / 20, 2 * pi * (i + 1) / 20
        mx, mz = cx + raio * (cos(a0) + cos(a1)) / 2, cz + raio * (sin(a0) + sin(a1)) / 2
        c.caixa('circulo', (mx, 0.006, mz), (0.06, 0.008, 2 * raio * sin(pi / 20) + 0.02), giz, -(a0 + a1) / 2)
    pontas = [(cx + raio * 0.92 * sin(2 * pi * k / 5), cz + raio * 0.92 * cos(2 * pi * k / 5)) for k in range(5)]
    for k in range(5):
        (x0, z0), (x1, z1) = pontas[k], pontas[(k + 2) % 5]
        comp = ((x1 - x0) ** 2 + (z1 - z0) ** 2) ** 0.5
        c.caixa('estrela', ((x0 + x1) / 2, 0.007, (z0 + z1) / 2), (0.05, 0.008, comp), giz, atan2(x1 - x0, z1 - z0))
        c.vela('vela_circulo', (pontas[k][0], 0, pontas[k][1]), 0.18 + 0.05 * (k % 2))
    # a laje: tampo de pedra em pes de madeira, com as correias de couro
    # (ao longo do comodo: sobra um corredor de cada lado, e e' por eles que
    # se chega ao fundo — a capsula do jogador precisa de 1,35 m)
    c.caixa('laje_tampo', (cx, 0.82, cz), (0.82, 0.12, 2.0), laje)
    for dx in (-0.3, 0.3):
        for dz in (-0.85, 0.85):
            c.caixa('laje_pe', (cx + dx, 0.38, cz + dz), (0.12, 0.76, 0.12), madeira)
    for dz in (-0.6, 0.0, 0.62):
        c.caixa('correia', (cx, 0.885, cz + dz), (0.86, 0.012, 0.07), couro)
        for dx in (-0.43, 0.43):
            c.caixa('fivela', (cx + dx, 0.82, cz + dz), (0.02, 0.1, 0.08), couro)
    c.solido('laje', (cx, 0, cz), (0.82, 0.88, 2.0))
    c.caixa('bilhete', (cx - 0.18, 0.882, cz - 0.35), (0.17, 0.004, 0.24), papel_nota, 0.2)
    c.node('anotacao', 'Label3D', props=[
        f'transform = {_deitado((cx - 0.18, 0.886, cz - 0.35), 0.2 - pi / 2)}', 'pixel_size = 0.0012',
        'font_size = 32', 'shaded = true', 'modulate = Color(0.14, 0.05, 0.04, 1)', 'outline_size = 0',
        'width = 180.0', 'autowrap_mode = 3', 'text = ""', 'metadata/chave = "NICE_HOUSE_NOTE"'])
    # o altar no fundo, com as velas e o livro dela
    c.modelo('altar', PH + 'WoodenTable_03/WoodenTable_03_1k.gltf', (cx, 0, 4.6), pi, solido=(1.34, 0.83, 0.6))
    c.modelo('grimorio', PH + 'book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf', (cx - 0.55, 0.83, 4.62), pi)
    for i, dx in enumerate((-0.15, 0.1, 0.32, 0.5)):
        c.vela('vela_altar', (cx + dx, 0.83, 4.55 + 0.08 * (i % 2)), 0.14 + 0.07 * (i % 3))
    c.modelo('nicho_velas', PH + 'street_shrine_velas/street_shrine_velas_1k.gltf', (3.55, 0, 4.68), pi, solido=(0.53, 0.8, 0.37))
    c.escrita('inscricao', 'NICE_HOUSE_INSCRIPTION', (cx, 2.15, 4.88), pi, 64, px=0.0024)
    c.modelo('quadro_desaparecidos', PH + 'missing_board_1994/missing_board_1994_1k.gltf', (4.21, 0, 0.95), pi / 2,
             solido=(1.3, 1.94, 0.4))
    c.escrita('escrita_inocentes', 'NICE_HOUSE_WALL_RITUAL', (4.38, 2.68, 0.75), -pi / 2, 48, px=0.0021)
    c.modelo('espelho_portal', PH + 'ornate_mirror_01/ornate_mirror_01_1k.gltf', (-0.82, 1.65, 1.5), pi / 2, 2.0)
    c.escrita('escrita_espelho', 'NICE_HOUSE_WALL_MIRROR', (-0.81, 2.66, 1.5), pi / 2, 40, px=0.0022)
    c.modelo('prateleira', PH + 'wooden_display_shelves_01/wooden_display_shelves_01_1k.gltf', (-0.25, 0, 4.71), pi,
             solido=(0.38, 1.56, 1.09))
    c.modelo('mesa_frascos', PH + 'small_wooden_table_01/small_wooden_table_01_1k.gltf', (4.18, 0, 3.6), -pi / 2,
             solido=(0.93, 0.53, 0.45))
    c.modelo('frascos', PH + 'chemistry_set/chemistry_set_1k.gltf', (4.15, 0.53, 3.6), -pi / 2, 0.8)
    for i, (x, z, g) in enumerate(((0.55, 0.9, 0.4), (3.3, 3.45, 2.6), (0.2, 3.2, -1.2), (3.6, 1.55, 1.9))):
        c.modelo('rato_morto', PH + 'street_rat/street_rat_1k.gltf', (x, 0, z), g, 1.5)

    # sangue: a poca debaixo da laje, o rastro arrastado ate' a porta, o
    # respingo no tampo e na parede do altar, a mancha velha do lado da cama
    c.sangue('poca_laje', 'sangue_poca', (cx, 0.0, cz), (1.8, 0.6, 2.4))
    c.sangue('respingo_laje', 'sangue_respingo', (cx, 0.86, cz + 0.2), (0.7, 0.3, 1.0), 0.8)
    c.sangue('rastro_porta', 'sangue_rastro', (0.75, 0.0, 0.55), (0.9, 0.6, 1.8), -0.35, opac=0.85)
    c.sangue('respingo_altar', 'sangue_respingo', (cx + 0.6, 1.6, 4.9), (1.5, 0.3, 1.5), parede=pi)
    c.sangue('respingo_espelho', 'sangue_respingo', (-0.8, 0.9, 2.6), (0.9, 0.3, 0.9), parede=pi / 2, opac=0.8)
    c.sangue('mancha_cama', 'sangue_poca', (-3.1, 0.0, 3.4), (0.9, 0.6, 0.7), 1.1, opac=0.7)
    c.sangue('respingo_cozinha', 'sangue_respingo', (2.4, 0.0, -2.0), (0.7, 0.6, 0.7), 0.4, opac=0.6)
    c.escrita('escrita_quarto', 'NICE_HOUSE_WALL_BEDROOM', (-3.0, 2.4, 4.88), pi, 40, px=0.0024)

    # ---------------------------------------------------------------- itens
    # Bala de pistola, onde faz sentido: na mesa da cozinha (debaixo da janela
    # tapada) e no criado-mudo dela.
    cartucho = 'res://assets/3d_model/player/the_negotiator_V1/cartridge/scene.gltf'
    c.pegavel('municao_cozinha', 'pistol_ammo', 15, (2.7, 0.83, -4.62), 0.25, 'PROMPT_TAKE_AMMO',
              'PICKUP_AMMO', 'PICKUP_AMMO_AGAIN', cartucho, _giro((0, 0.036, 0)))
    c.pegavel('municao_quarto', 'pistol_ammo', 10, (-3.22, 0.62, 4.55), -0.4, 'PROMPT_TAKE_AMMO',
              'PICKUP_AMMO', 'PICKUP_AMMO_AGAIN', cartucho, _giro((0, 0.036, 0)))

    # A PISTOLA, na laje do meio do comodo do ritual (era no balcao do
    # hospital), com uma caixa de bala do lado: entre a correia do meio e a
    # dos pes, onde o tampo (0,88) esta' livre. Deitada de lado, como estava no
    # balcao: o .glb tem 1,92 unidade de cano, 0,115 devolve os 22 cm, e 0,021
    # e' a meia espessura que tira a arma de dentro do tampo.
    # (Os ids continuam `_altar`: um save que ja' pegou nao ve' de novo.)
    pistola = 'res://assets/3d_model/player/the_negotiator_V1/the_negotiator_v1.glb'
    deitada = 'Transform3D(0.115, 0, 0, 0, 0, 0.115, 0, -0.115, 0, 0, 0.021, 0)'
    c.pegavel('pistola_altar', 'pistol', 1, (cx + 0.12, 0.88, cz + 0.31), 1.4, 'PROMPT_TAKE_PISTOL',
              'PICKUP_PISTOL', '', pistola, deitada)
    c.pegavel('municao_altar', 'pistol_ammo', 16, (cx - 0.2, 0.88, cz + 0.33), 0.3, 'PROMPT_TAKE_AMMO',
              'PICKUP_AMMO', 'PICKUP_AMMO_AGAIN', cartucho, _giro((0, 0.036, 0)))

    # A chave reserva da igreja, no quarto dela: em cima da comoda, debaixo do
    # espelho. Um pouco maior que a real (7,5 cm) pra se ver de pe'.
    c.pegavel('chave_igreja', 'chave_igreja', 1, (-1.33, 1.18, 3.05), 0.5, 'PROMPT_TAKE_KEY',
              'PICKUP_CHAVE_IGREJA', 'PICKUP_AMMO_AGAIN',
              'res://assets/3d_model/objects/chave_igreja/chave_igreja.glb', _giro((0, 0, 0), 0.0, 1.4))

    # A seringa de adrenalina, na mesma laje, entre a correia da cabeca e a do
    # meio (do outro lado do bilhete).
    c.pegavel('seringa_ritual', 'seringa_adrenalina', 1, (cx + 0.16, 0.88, cz - 0.3), 0.3, 'PROMPT_TAKE_SYRINGE',
              'PICKUP_SERINGA', 'PICKUP_AMMO_AGAIN',
              'res://assets/3d_model/objects/seringa_adrenalina/seringa_adrenalina.glb', _giro((0, 0, 0), 0.0, 1.3))

    # ---------------------------------------------------------------- luz
    # Sete luzes ao todo (o renderer mobile aguenta 8 por malha): a lamparina
    # da sala, a lampada fria da cozinha, a da entrada, a do criado-mudo, e no
    # ritual as velas do circulo, as do altar e o vermelho do teto.
    c.light('luz_sala', (-2.95, 1.1, -2.55), '1, 0.62, 0.34, 1', 0.95, 6.5, flicker=True)
    c.light('luz_cozinha', (2.7, 2.6, -2.4), '0.70, 0.78, 0.84, 1', 0.85, 5.5, flicker=True)
    c.light('luz_entrada', (-0.2, 2.5, -3.7), '1, 0.70, 0.45, 1', 0.4, 4.5)
    c.light('luz_quarto', (-2.95, 1.25, 4.5), '1, 0.55, 0.30, 1', 0.55, 4.5, flicker=True)
    c.light('luz_circulo', (cx - 0.9, 0.55, cz), '1, 0.22, 0.10, 1', 0.75, 5.5, flicker=True)
    c.light('luz_altar', (cx + 0.15, 1.35, 4.3), '1, 0.40, 0.16, 1', 0.6, 4.5, flicker=True)
    c.light('luz_teto_ritual', (cx, 2.55, cz), '0.75, 0.10, 0.08, 1', 0.35, 5.0)

    c.node('ambiencia', 'AudioStreamPlayer', props=[f'stream = {ambience}', 'volume_db = -20', 'autoplay = true'])
    c.node('porta_saida', 'Area3D', props=[f'transform = {_giro((0, 1.05, -4.3))}', 'collision_layer = 0',
                                           'collision_mask = 1', 'monitorable = false'])
    c.node('CollisionShape3D', 'CollisionShape3D', 'porta_saida', [f'shape = {c.box_resource((1.9, 2.1, 1.1), True)}'])
    c.save(DEST / 'casa_nice_interior.tscn', [
        '[connection signal="body_entered" from="porta_saida" to="." method="_ao_entrar_na_porta"]',
        '[connection signal="body_exited" from="porta_saida" to="." method="_ao_sair_da_porta"]'])


if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    exterior()
    interior()
    print('Cenas da casa de Dona Nice geradas em', DEST)
