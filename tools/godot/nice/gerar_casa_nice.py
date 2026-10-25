"""Gera as duas cenas editáveis da casa de Dona Nice com recursos já usados no jogo."""
from pathlib import Path
from math import cos, sin, pi

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


def interior():
    c = Cena()
    c.externo('PackedScene', 'res://scenes/player/player.tscn', 'player')
    c.externo('PackedScene', 'res://scenes/configs/pause.tscn', 'pause')
    c.externo('PackedScene', 'res://scenes/configs/fade.tscn', 'fade')
    script = c.externo('Script', 'res://scripts/stages/nice_house/casa_nice_interior.gd', 'script')
    ambience = c.externo('AudioStream', 'res://assets/sounds/episodios/ambiente_noise_sublime.mp3', 'ambiente')
    floor = c.material('chao', '0.42, 0.37, 0.32, 1', 'wood_floor_worn')
    wall = c.material('parede', '0.58, 0.55, 0.49, 1', 'grey_plaster_02')
    wood = c.material('madeira', '0.33, 0.25, 0.22, 1', 'dark_wooden_planks')
    red = c.material('sangue_seco', '0.22, 0.035, 0.03, 1')
    ink = c.material('tinta', '0.12, 0.095, 0.075, 1')
    glass = c.material('vidro', '0.08, 0.11, 0.15, 1', glow='0.15, 0.19, 0.28, 1')
    c.sub.append('[sub_resource type="Environment" id="ambiente_casa"]\nbackground_mode = 1\nbackground_color = Color(0.009, 0.009, 0.014, 1)\nambient_light_source = 2\nambient_light_color = Color(0.18, 0.14, 0.15, 1)\nambient_light_energy = 0.33\ntonemap_mode = 3\nglow_enabled = true\nglow_intensity = 0.42\nfog_enabled = true\nfog_light_color = Color(0.16, 0.08, 0.09, 1)\nfog_density = 0.012\nadjustment_enabled = true\nadjustment_contrast = 1.09\nadjustment_saturation = 0.74')
    c.sub.append('[sub_resource type="CameraAttributesPractical" id="camera_casa"]')
    c.node('casa_nice_interior', 'Node3D', props=[f'script = {script}'])
    c.node('Pause', parent='.', instance='ExtResource("pause")')
    c.node('fade', parent='.', instance='ExtResource("fade")')
    c.node('Player', parent='.', instance='ExtResource("player")', props=[f'transform = {c.transform((0, 1.05, -3.4), pi)}'])
    c.node('WorldEnvironment', 'WorldEnvironment', props=['environment = SubResource("ambiente_casa")', 'camera_attributes = SubResource("camera_casa")'])
    c.node('geometria', 'Node3D')
    c.node('colisoes', 'StaticBody3D', props=['collision_layer = 2', 'collision_mask = 0'])
    c.node('objetos', 'Node3D')
    c.node('luzes', 'Node3D')
    # 9 x 10 m; sala e cozinha à frente, quarto e escritório secreto atrás.
    c.box('piso', (0, -0.16, 0), (9.1, 0.32, 10.2), floor, collision=True)
    c.box('teto', (0, 3.18, 0), (9.1, 0.24, 10.2), wood, collision=True)
    c.box('parede_fundo', (0, 1.5, 5.0), (9.1, 3.0, 0.2), wall, collision=True)
    c.box('parede_esquerda', (-4.5, 1.5, 0), (0.2, 3.0, 10.2), wall, collision=True)
    c.box('parede_direita', (4.5, 1.5, 0), (0.2, 3.0, 10.2), wall, collision=True)
    for name, x, width in [('oeste', -3.0, 3.1), ('meio', 0, 1.3), ('leste', 3, 3.1)]:
        c.box('parede_entrada_'+name, (x, 1.5, -5), (width, 3, 0.2), wall, collision=True)
    c.box('verga_porta', (0, 2.65, -5), (1.5, 0.7, 0.2), wall, collision=True)
    # Partição traseira com aberturas para os dois cômodos.
    for name, x, width in [('esq', -4.0, 1), ('centro_esq', -1.0, 3), ('centro_dir', 1.0, 1), ('dir', 4.0, 1)]:
        c.box('divisoria_'+name, (x, 1.5, 0.5), (width, 3, 0.15), wall, collision=True)
    for x, name in [(-3, 'escritorio'), (3, 'quarto')]:
        c.box('verga_'+name, (x, 2.6, 0.5), (1.1, 0.8, 0.15), wall, collision=True)
    c.box('divisoria_quartos', (0, 1.5, 2.77), (0.15, 3, 4.5), wall, collision=True)
    c.box('porta_saida_folha', (0.84, 1.2, -4.92), (0.1, 2.3, 1.35), wood)
    # Sala realmente habitada: móvel gasto, relógio, livros, cozinha simples.
    c.model('tapete', MB+'tiny_living_contemporary_carpet_40.tscn', (-1.2, 0.04, -2.3), 0, 0.8)
    c.model('sofa', MB+'tiny_living_lovely_loveseat_12.tscn', (-2.5, 0, -2.0), pi/2)
    c.model('mesa_centro', PH+'side_table_01/side_table_01_1k.gltf', (-1.0, 0, -1.8), 0.3)
    c.physical_model('cadeira_balanco', PH+'Rockingchair_01/Rockingchair_01_1k.gltf', (-3.5, 0, -4.0), (0.72, 1.0, 0.95), 0.3)
    c.model('relogio', PH+'vintage_grandfather_clock_01/vintage_grandfather_clock_01_1k.gltf', (3.7, 0, -4.2), pi)
    c.model('mesa_jantar', PH+'round_wooden_table_01/round_wooden_table_01_1k.gltf', (2.3, 0, -2.2), 0.1)
    for i, (x,z) in enumerate([(1.4,-2.7), (3.1,-1.8)]):
        c.physical_model('cadeira_jantar_'+str(i), PH+'painted_wooden_chair_01/painted_wooden_chair_01_1k.gltf', (x, 0, z), (0.45, 0.96, 0.55), i*pi)
    c.model('fogao', PH+'electric_stove/electric_stove_1k.gltf', (3.5, 0, -0.3), pi)
    c.model('estante_sala', PH+'wooden_bookshelf_worn/wooden_bookshelf_worn_1k.gltf', (-3.8, 0, -0.1), pi/2)
    c.model('cama', PH+'old_bed_frame/old_bed_frame_1k.gltf', (2.6, 0, 3.0), 0)
    c.model('criado_mudo', PH+'painted_wooden_nightstand/painted_wooden_nightstand_1k.gltf', (3.9, 0, 3.0), 0)
    c.model('armario', PH+'painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf', (0.9, 0, 4.2), pi)
    c.model('espelho', PH+'ornate_mirror_01/ornate_mirror_01_1k.gltf', (4.37, 0.5, 2.0), -pi/2, 0.75)
    c.model('mesa_ritual', PH+'painted_wooden_table/painted_wooden_table_1k.gltf', (-2.1, 0, 3.4), 0.2)
    c.model('livros_ritual', PH+'book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf', (-2.1, 0.9, 3.4), 0.4, 0.8)
    c.model('lamparina', PH+'vintage_oil_lamp/vintage_oil_lamp_1k.gltf', (-3.2, 0.85, 3.5), 0)
    c.physical_model('mala', PH+'vintage_suitcase/vintage_suitcase_1k.gltf', (-3.65, 0, 1.7), (0.7, 0.42, 0.45), 0.8)
    c.physical_model('caixa', PH+'cardboard_box_01/cardboard_box_01_1k.gltf', (-1.0, 0, 1.5), (0.5, 0.5, 0.5), 0.4)
    c.model('quadro', PH+'hanging_picture_frame_02/hanging_picture_frame_02_1k.gltf', (-2.7, 1.45, 4.84), pi)
    for nome, pos, tamanho, giro in [
        ('sofa', (-2.5, 0, -2.0), (1.55, 0.85, 0.75), pi/2),
        ('mesa_centro', (-1.0, 0, -1.8), (0.7, 0.55, 0.7), 0.3),
        ('relogio', (3.7, 0, -4.2), (0.7, 2.0, 0.45), pi),
        ('mesa_jantar', (2.3, 0, -2.2), (1.3, 0.8, 1.3), 0),
        ('fogao', (3.5, 0, -0.3), (0.7, 0.9, 0.7), pi),
        ('estante_sala', (-3.8, 0, -0.1), (0.65, 2.0, 1.1), pi/2),
        ('cama', (2.6, 0, 3.0), (1.65, 0.65, 2.1), 0),
        ('armario', (0.9, 0, 4.2), (1.1, 1.9, 0.6), pi),
        ('mesa_ritual', (-2.1, 0, 3.4), (1.5, 0.8, 0.9), 0.2),
    ]:
        c.collider(nome, pos, tamanho, giro)
    # Círculo irregular e marcas riscadas no piso, parcialmente escondidos pela mesa.
    for i in range(16):
        a = 2*pi*i/16
        b = 2*pi*(i+1)/16
        mx, mz = -2.15 + 1.3*(cos(a)+cos(b))/2, 2.85 + 1.3*(sin(a)+sin(b))/2
        c.box('circulo_%02d'%i, (mx, 0.012, mz), (0.05, 0.012, 2*1.3*sin(pi/16)), red, yaw=-a-pi/16)
    for i in range(5):
        a=2*pi*i/5
        c.box('raio_%02d'%i, (-2.15+0.6*cos(a), 0.014, 2.85+0.6*sin(a)),
              (0.035, 0.01, 1.12), red, yaw=-a)
    for i, (x,z) in enumerate([(-3.35,2.85),(-0.95,2.85),(-2.15,1.65),(-2.15,4.05)]):
        c.box('vela_'+str(i), (x,0.13,z), (0.07,0.26,0.07), ink)
        c.light('chama_'+str(i), (x,0.36,z), '1, 0.25, 0.12, 1', 0.18, 2.5, flicker=True)
    c.light('luz_sala', (-1.2, 2.7, -2.2), '0.95, 0.65, 0.38, 1', 0.7, 7, flicker=True)
    c.light('luz_cozinha', (2.7, 2.6, -1.7), '0.72, 0.78, 0.82, 1', 0.45, 5)
    c.light('luz_quarto', (2.3, 2.55, 3.0), '0.48, 0.55, 0.76, 1', 0.35, 5)
    c.light('luz_escritorio', (-2.2, 2.0, 3.0), '0.88, 0.21, 0.17, 1', 0.38, 5, flicker=True)
    c.node('inscricao', 'Label3D', props=[f'transform = {c.transform((-2.0, 1.78, 4.85), pi)}',
                                               'pixel_size = 0.003', 'font_size = 36', 'modulate = Color(0.43, 0.08, 0.06, 1)',
                                               'text = ""'])
    c.node('anotacao', 'Label3D', props=[f'transform = {c.transform((-2.15, 1.09, 3.4), 0)}',
                                              'pixel_size = 0.0016', 'font_size = 34', 'modulate = Color(0.7, 0.59, 0.47, 1)',
                                              'text = ""'])
    c.node('ambiencia', 'AudioStreamPlayer', props=[f'stream = {ambience}', 'volume_db = -20', 'autoplay = true'])
    c.node('porta_saida', 'Area3D', props=[f'transform = {c.transform((0, 1.05, -4.25))}', 'collision_layer = 0', 'collision_mask = 1', 'monitorable = false'])
    c.node('CollisionShape3D', 'CollisionShape3D', 'porta_saida', [f'shape = {c.box_resource((1.9, 2.1, 1.1), True)}'])
    c.save(DEST/'casa_nice_interior.tscn', [
        '[connection signal="body_entered" from="porta_saida" to="." method="_ao_entrar_na_porta"]',
        '[connection signal="body_exited" from="porta_saida" to="." method="_ao_sair_da_porta"]'])


if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    exterior()
    interior()
    print('Cenas da casa de Dona Nice geradas em', DEST)
