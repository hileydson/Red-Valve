"""Gera detalhes da marquise do hospital sem alterar a navegação.

Execute da raiz red-valve: python3 tools/hospital/gerar_detalhes_exterior.py
Coordenadas no espaço de hospital_exterior.tscn.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DESTINO = ROOT / "scenes/stages/hospital/hospital_exterior_detalhes.tscn"


def q(valor):
    return json.dumps(valor, ensure_ascii=False)


def v(x, y, z):
    return f"Vector3({x:.4f}, {y:.4f}, {z:.4f})"


linhas = ["[gd_scene load_steps=16 format=3]", ""]
linhas.append('[ext_resource type="Script" path="res://scripts/stages/hospital/hospital_detalhes.gd" id="1"]')
modelos = {
    "cadeira_rodas": "res://assets/3d_model/polyhaven/wheelchair_01/wheelchair_01_1k.gltf",
    "banco": "res://assets/3d_model/polyhaven/painted_wooden_bench/painted_wooden_bench_1k.gltf",
    "saco": "res://assets/3d_model/polyhaven/trashbag/trashbag_1k.gltf",
    "caixa": "res://assets/3d_model/polyhaven/plastic_crate_02/plastic_crate_02_1k.gltf",
}
for indice, caminho in enumerate(modelos.values(), 2):
    linhas.append(f'[ext_resource type="PackedScene" path={q(caminho)} id="{indice}"]')
linhas.append("")
for nome, cor, emissao in [
    ("placa", "Color(0.034, 0.095, 0.089, 1)", None),
    ("borda", "Color(0.13, 0.20, 0.19, 1)", None),
    ("vermelho", "Color(0.49, 0.055, 0.047, 1)", "Color(0.20, 0.015, 0.012, 1)"),
    ("papel", "Color(0.40, 0.39, 0.33, 1)", None),
    ("metal", "Color(0.095, 0.14, 0.14, 1)", None),
]:
    linhas.extend([f'[sub_resource type="StandardMaterial3D" id="mat_{nome}"]', f'albedo_color = {cor}', 'roughness = 0.83'])
    if emissao:
        linhas.extend(['emission_enabled = true', f'emission = {emissao}', 'emission_energy_multiplier = 0.55'])
    linhas.append("")
linhas.extend([
    '[sub_resource type="BoxMesh" id="cubo"]',
    'size = Vector3(1, 1, 1)',
    '',
    '[sub_resource type="CylinderMesh" id="cilindro"]',
    'top_radius = 0.5',
    'bottom_radius = 0.5',
    'height = 1.0',
    'radial_segments = 12',
    '',
    '[sub_resource type="BoxShape3D" id="colisao_banco"]',
    'size = Vector3(0.75, 1.18, 1.62)',
    '',
    '[sub_resource type="BoxShape3D" id="colisao_cadeira"]',
    'size = Vector3(1.1, 1.15, 1.2)',
    '',
    '[sub_resource type="BoxShape3D" id="colisao_lixeira"]',
    'size = Vector3(0.62, 0.83, 0.62)',
    '',
    '[node name="hospital_exterior_detalhes" type="Node3D"]',
    'script = ExtResource("1")',
    '',
])


def no(nome, tipo, pai=".", props=(), instancia=None):
    cabecalho = f'[node name={q(nome)}'
    if tipo:
        cabecalho += f' type="{tipo}"'
    cabecalho += f' parent={q(pai)}'
    if instancia:
        cabecalho += f' instance=ExtResource("{instancia}")'
    linhas.extend([cabecalho + "]", *props, ""])


def cubo(nome, pai, x, y, z, sx, sy, sz, material, rot=0):
    no(nome, "MeshInstance3D", pai, (
        'mesh = SubResource("cubo")',
        f'material_override = SubResource("mat_{material}")',
        f'position = {v(x, y, z)}',
        f'rotation = {v(0, rot, 0)}',
        f'scale = {v(sx, sy, sz)}',
        'cast_shadow = 0',
    ))


def modelo(nome, chave, x, y, z, rot=0, escala=1):
    indice = list(modelos).index(chave) + 2
    no(nome, None, ".", (
        f'position = {v(x, y, z)}',
        f'rotation = {v(0, rot, 0)}',
        f'scale = {v(escala, escala, escala)}',
    ), str(indice))


# A placa fica acima das portas, paralela à fachada e orientada para a marquise.
no("placa_emergencia", "Node3D", ".", (
    f'position = {v(9.32, 3.05, 0.7)}',
    f'rotation = {v(0, -1.5708, 0)}',
))
cubo("chapa", "placa_emergencia", 0, 0, 0, 3.5, .52, .055, "borda")
cubo("face", "placa_emergencia", 0, 0, .035, 3.40, .42, .010, "placa")
cubo("faixa", "placa_emergencia", -1.64, 0, .044, .10, .36, .011, "vermelho")
no("texto", "Label3D", "placa_emergencia", (
    'text = "EMERGÊNCIA"',
    'metadata/chave_traducao = "HOSP_SIGN_EMERGENCIA"',
    f'position = {v(.06, -.015, .052)}',
    'font_size = 44',
    'pixel_size = 0.0037',
    'outline_size = 8',
    'modulate = Color(0.90, 0.95, 0.88, 1)',
    'outline_modulate = Color(0.02, 0.03, 0.028, 1)',
))

# Mobiliário e descarte ficam junto à parede e ao extremo da marquise.
modelo("cadeira_rodas_abandonada", "cadeira_rodas", 7.65, 0, -5.5, 2.50, 1.0)
modelo("banco_espera", "banco", 8.0, 0, 5.6, 1.5708, 1.35)
modelo("saco_entrada", "saco", 8.25, 0, 8.0, .8, .85)
modelo("saco_descartado", "saco", 1.15, 0, -7.5, 2.2, .65)
modelo("caixa_residuos", "caixa", 7.9, 0, 8.8, .3, 1.25)

for nome, forma, x, y, z in [
    ("banco_espera", "colisao_banco", 8.0, .59, 5.6),
    ("cadeira_rodas", "colisao_cadeira", 7.65, .575, -5.5),
    ("lixeira_marquise", "colisao_lixeira", 8.45, .415, 7.1),
]:
    pai = "colisao_" + nome
    no(pai, "StaticBody3D", ".", (
        f'position = {v(x, y, z)}',
        'collision_layer = 2',
        'collision_mask = 0',
    ))
    no("forma", "CollisionShape3D", pai, (f'shape = SubResource("{forma}")',))

no("lixeira_marquise", "Node3D", ".", (f'position = {v(8.45, 0, 7.1)}',))
no("corpo", "MeshInstance3D", "lixeira_marquise", (
    'mesh = SubResource("cilindro")',
    'material_override = SubResource("mat_metal")',
    f'position = {v(0, .38, 0)}',
    f'scale = {v(.54, .76, .54)}',
    'cast_shadow = 0',
))
no("tampa", "MeshInstance3D", "lixeira_marquise", (
    'mesh = SubResource("cilindro")',
    'material_override = SubResource("mat_vermelho")',
    f'position = {v(0, .79, 0)}',
    f'scale = {v(.59, .08, .59)}',
    'cast_shadow = 0',
))
cubo("etiqueta", "lixeira_marquise", 0, .47, .285, .39, .19, .012, "papel")
no("texto", "Label3D", "lixeira_marquise", (
    'text = "INFECTANTE"',
    'metadata/chave_traducao = "HOSP_SIGN_LIXO"',
    f'position = {v(0, .47, .297)}',
    'font_size = 28',
    'pixel_size = 0.0019',
    'modulate = Color(0.22, 0.035, 0.03, 1)',
))

for indice, (x, z, angulo) in enumerate([
    (7.15, 3.65, .28), (7.55, 4.1, -.4), (6.9, 6.6, 1.1),
    (1.35, -5.6, -.8), (2.25, -6.1, .3), (8.05, -6.85, -.2),
]):
    cubo(f"papel_sujo_{indice}", ".", x, .012, z, .17, .003, .23, "papel", angulo)

# Um foco vermelho discreto conserva a leitura do letreiro no ambiente escuro.
no("luz_emergencia", "OmniLight3D", ".", (
    f'position = {v(8.85, 3.14, 0.7)}',
    'light_color = Color(0.85, 0.13, 0.10, 1)',
    'light_energy = 0.65',
    'light_specular = 0.12',
    'shadow_enabled = false',
    'omni_range = 4.3',
    'omni_attenuation = 1.6',
))

DESTINO.write_text("\n".join(linhas).rstrip("\n") + "\n", encoding="utf-8")
print(f"{DESTINO.relative_to(ROOT)}: {len(linhas)} linhas")
