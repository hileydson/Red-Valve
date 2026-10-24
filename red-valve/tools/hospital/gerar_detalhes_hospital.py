"""Gera a camada visual complementar do hospital sem tocar na planta/navmesh.

Execute da raiz red-valve: python3 tools/hospital/gerar_detalhes_hospital.py
As coordenadas seguem as portas e salas de scenes/stages/hospital/hospital.tscn.
"""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DESTINO = ROOT / "scenes/stages/hospital/hospital_detalhes.tscn"


def q(value):
    return json.dumps(value, ensure_ascii=False)


def v(x, y, z):
    return f"Vector3({x:.4f}, {y:.4f}, {z:.4f})"


linhas = ["[gd_scene load_steps=19 format=3]", ""]
assets = {
    "saco": "res://assets/3d_model/polyhaven/trashbag/trashbag_1k.gltf",
    "caixa_medica": "res://assets/3d_model/polyhaven/medical_box/medical_box_1k.gltf",
    "bloco": "res://assets/3d_model/polyhaven/office_notepads/office_notepads_1k.gltf",
    "pasta": "res://assets/3d_model/polyhaven/binder_notebook/binder_notebook_1k.gltf",
    "papelao": "res://assets/3d_model/polyhaven/cardboard_box_01/cardboard_box_01_1k.gltf",
    "frasco": "res://assets/3d_model/polyhaven/plastic_bottle_gallon/plastic_bottle_gallon_1k.gltf",
}
linhas.append('[ext_resource type="Script" path="res://scripts/stages/hospital/hospital_detalhes.gd" id="1"]')
for i, path in enumerate(assets.values(), 2):
    linhas.append(f'[ext_resource type="PackedScene" path={q(path)} id="{i}"]')
linhas.append("")

materiais = {
    "placa": "Color(0.030, 0.077, 0.073, 1)",
    "borda": "Color(0.18, 0.24, 0.22, 1)",
    "vermelho": "Color(0.48, 0.065, 0.060, 1)",
    "amarelo": "Color(0.60, 0.42, 0.075, 1)",
    "papel": "Color(0.63, 0.61, 0.51, 1)",
    "papel_sujo": "Color(0.40, 0.38, 0.31, 1)",
    "metal": "Color(0.16, 0.20, 0.20, 1)",
    "tampa": "Color(0.46, 0.075, 0.065, 1)",
    "bolsa": "Color(0.13, 0.14, 0.12, 1)",
}
for nome, cor in materiais.items():
    linhas.extend([
        f'[sub_resource type="StandardMaterial3D" id="mat_{nome}"]',
        f'albedo_color = {cor}',
        "metallic = 0.12" if nome in ("placa", "borda", "metal") else "metallic = 0.0",
        "roughness = 0.82",
        "",
    ])
linhas.extend([
    '[sub_resource type="BoxMesh" id="cubo"]',
    'size = Vector3(1, 1, 1)',
    '',
    '[sub_resource type="CylinderMesh" id="cilindro"]',
    'top_radius = 0.5',
    'bottom_radius = 0.5',
    'height = 1.0',
    'radial_segments = 16',
    '',
    '[node name="hospital_detalhes" type="Node3D"]',
    'script = ExtResource("1")',
    '',
])


def node(nome, tipo, pai=".", props=(), instancia=None):
    head = f'[node name={q(nome)}'
    if tipo:
        head += f' type="{tipo}"'
    head += f' parent={q(pai)}'
    if instancia:
        head += f' instance=ExtResource("{instancia}")'
    linhas.append(head + "]")
    linhas.extend(props)
    linhas.append("")


def caixa(nome, pai, x, y, z, sx, sy, sz, mat, rot=0.0):
    node(nome, "MeshInstance3D", pai, (
        'mesh = SubResource("cubo")',
        f'material_override = SubResource("mat_{mat}")',
        f'position = {v(x, y, z)}',
        f'rotation = {v(0, rot, 0)}',
        f'scale = {v(sx, sy, sz)}',
        'cast_shadow = 0',
    ))


def modelo(nome, tipo, x, y, z, rot=0, escala=1):
    indice = list(assets).index(tipo) + 2
    node(nome, None, ".", (
        f'position = {v(x, y, z)}',
        f'rotation = {v(0, rot, 0)}',
        f'scale = {v(escala, escala, escala)}',
    ), str(indice))


def placa(nome, chave, texto, x, y, z, rot=0, largura=2.7, alerta=False):
    node(nome, "Node3D", ".", (
        f'position = {v(x, y, z)}',
        f'rotation = {v(0, rot, 0)}',
    ))
    caixa("base", nome, 0, 0, 0, largura, .43, .045, "borda")
    caixa("face", nome, 0, 0, .026, largura - .055, .38, .008, "placa")
    caixa("faixa", nome, -largura / 2 + .085, 0, .034, .09, .32, .012,
          "vermelho" if alerta else "amarelo")
    node("texto", "Label3D", nome, (
        f'text = {q(texto)}',
        f'metadata/chave_traducao = {q(chave)}',
        f'position = {v(.08, -.015, .042)}',
        'font_size = 40',
        'pixel_size = 0.0034',
        'outline_size = 7',
        'modulate = Color(0.86, 0.91, 0.82, 1)',
        'outline_modulate = Color(0.015, 0.025, 0.022, 1)',
    ))


# Placas acima das portas: ficam fora do vão e da colisão, visíveis dos corredores.
portas = [
    ("101", "HOSP_SALA_101", "Quarto 101", 5.6, 0, 10.32, 0),
    ("102", "HOSP_SALA_102", "Quarto 102", 16.6, 0, 10.32, 0),
    ("103", "HOSP_SALA_103", "Quarto 103", 27.6, 0, 10.32, 0),
    ("raiox", "HOSP_SALA_RAIOX", "Radiologia", 38.6, 0, 10.32, 0),
    ("lab", "HOSP_SALA_LAB", "Laboratório", 50.0, 0, 10.32, 0),
    ("104", "HOSP_SALA_104", "Quarto 104", 5.2, 0, 15.39, 3.14159),
    ("105", "HOSP_SALA_105", "Quarto 105", 15.2, 0, 15.39, 3.14159),
    ("cirurgia", "HOSP_SALA_CIRURGIA", "Centro Cirúrgico", 30.2, 0, 15.39, 3.14159),
    ("uti", "HOSP_SALA_UTI", "UTI", 42.8, 0, 15.39, 3.14159),
    ("ps", "HOSP_SALA_PS", "Pronto-Socorro", 40.3, 0, 35.69, 0),
    ("106", "HOSP_SALA_106", "Quarto 106", 5.2, 0, 52.96, 0),
    ("107", "HOSP_SALA_107", "Quarto 107", 15.2, 0, 52.96, 0),
    ("refeitorio", "HOSP_SALA_REFEITORIO", "Refeitório", 30.6, 0, 52.96, 0),
    ("necroterio", "HOSP_SALA_NECROTERIO", "Necrotério", 43.3, 0, 52.96, 0),
    ("108", "HOSP_SALA_108", "Quarto 108", 5.6, 0, 58.04, 3.14159),
    ("109", "HOSP_SALA_109", "Quarto 109", 16.6, 0, 58.04, 3.14159),
    ("farmacia", "HOSP_SALA_FARMACIA", "Farmácia", 27.6, 0, 58.04, 3.14159),
    ("esteril", "HOSP_SALA_ESTERIL", "Central de Esterilização", 38.6, 0, 58.04, 3.14159),
    ("maquinas", "HOSP_SALA_MAQUINAS", "Casa de Máquinas", 50.0, 0, 58.04, 3.14159),
    ("arquivo", "HOSP_SALA_ARQUIVO", "Arquivo Médico", 16.175, 4.2, 6.32, 0),
    ("201", "HOSP_SALA_201", "Quarto 201", 6.5, 4.2, 28.31, 0),
    ("202", "HOSP_SALA_202", "Quarto 202", 19.3, 4.2, 28.31, 0),
    ("203", "HOSP_SALA_203", "Quarto 203", 31.9, 4.2, 28.31, 0),
    ("psiq", "HOSP_SALA_PSIQ", "Ala Psiquiátrica", 8.2, 4.2, 33.64, 3.14159),
    ("terapia", "HOSP_SALA_TERAPIA", "Sala de Terapia", 24.2, 4.2, 33.64, 3.14159),
    ("204", "HOSP_SALA_204", "Quarto 204", 5.6, 4.2, 53.96, 0),
    ("205", "HOSP_SALA_205", "Quarto 205", 16.6, 4.2, 53.96, 0),
    ("cirurgia2", "HOSP_SALA_CIRURGIA2", "Centro Cirúrgico 2", 27.6, 4.2, 53.96, 0),
    ("observacao", "HOSP_SALA_OBSERVACAO", "Sala de Observação", 38.6, 4.2, 53.96, 0),
]
for nome, chave, texto, x, piso, z, rot in portas:
    placa("porta_" + nome, chave, texto, x, piso + 2.88, z, rot)


# Sinalização institucional e avisos clínicos perto do fluxo natural do jogador.
avisos = [
    ("recepcao", "HOSP_SIGN_RECEPCAO", "RECEPÇÃO / TRIAGEM", 15.2, 2.75, 25.58, 0, 3.5, False),
    ("emergencia", "HOSP_SIGN_EMERGENCIA", "EMERGÊNCIA", 40.3, 2.55, 42.52, 3.14159, 3.3, True),
    ("higiene", "HOSP_SIGN_HIGIENE", "HIGIENIZE AS MÃOS", 34.8, 1.8, 25.58, 0, 2.5, False),
    ("silencio", "HOSP_SIGN_SILENCIO", "SILÊNCIO / PACIENTES", 20.6, 1.8, 10.32, 0, 2.7, False),
    ("restrito", "HOSP_SIGN_RESTRITO", "ACESSO RESTRITO", 38.6, 1.85, 58.04, 3.14159, 2.7, True),
    ("isolamento", "HOSP_SIGN_ISOLAMENTO", "ISOLAMENTO", 42.8, 1.8, 15.39, 3.14159, 2.6, True),
    ("elevador_1", "HOSP_SIGN_ELEVADOR", "ELEVADOR", 51.0, 2.85, 36.0, -1.5708, 2.6, False),
    ("elevador_2", "HOSP_SIGN_ELEVADOR", "ELEVADOR", 51.0, 7.05, 36.0, -1.5708, 2.6, False),
    ("saida", "HOSP_SIGN_SAIDA", "SAÍDA", 1.1, 2.8, 34.2, 1.5708, 2.5, False),
    ("ala_1", "HOSP_SIGN_ALA_1", "ALA CLÍNICA / 1º ANDAR", 24.2, 2.78, 10.32, 0, 3.2, False),
    ("ala_2", "HOSP_SIGN_ALA_2", "ALA CLÍNICA / 2º ANDAR", 24.2, 6.98, 28.31, 0, 3.2, False),
    ("residuos", "HOSP_SIGN_RESIDUOS", "RESÍDUOS INFECTANTES", 49.8, 1.8, 67.52, 3.14159, 2.8, True),
]
for args in avisos:
    placa(*args)


# Quadros de procedimento amarelados. O miolo usa marcas gráficas em vez de
# parágrafos ilegíveis; somente o título legível precisa de tradução.
cartazes = [
    ("espera_norte", "HOSP_POSTER_HIGIENE", "HIGIENE", 4.5, 1.72, 25.84, 0),
    ("espera_sul", "HOSP_POSTER_SILENCIO", "SILÊNCIO", 7.1, 1.72, 42.52, 3.14159),
    ("triagem", "HOSP_POSTER_TRIAGEM", "TRIAGEM", 31.0, 1.72, 25.84, 0),
    ("farmacia", "HOSP_POSTER_RESTRITO", "RESTRITO", 23.5, 1.72, 67.52, 3.14159),
    ("necroterio", "HOSP_POSTER_RESIDUOS", "INFECTANTE", 47.2, 1.72, 52.52, 3.14159),
    ("psiquiatria", "HOSP_POSTER_SILENCIO", "SILÊNCIO", 4.0, 5.92, 43.15, 3.14159),
]
for nome, chave, texto, x, y, z, rot in cartazes:
    pai = "quadro_" + nome
    node(pai, "Node3D", ".", (
        f'position = {v(x, y, z)}', f'rotation = {v(0, rot, 0)}',
    ))
    caixa("moldura", pai, 0, 0, 0, .95, 1.28, .04, "borda")
    caixa("papel", pai, 0, 0, .027, .85, 1.17, .009, "papel")
    caixa("faixa", pai, 0, .42, .035, .85, .16, .01, "vermelho")
    caixa("cruz_v", pai, -.31, .15, .037, .035, .16, .011, "vermelho")
    caixa("cruz_h", pai, -.31, .15, .039, .14, .035, .011, "vermelho")
    node("titulo", "Label3D", pai, (
        f'text = {q(texto)}', f'metadata/chave_traducao = {q(chave)}',
        f'position = {v(0, .41, .046)}', 'font_size = 38',
        'pixel_size = 0.0026', 'modulate = Color(0.93, 0.90, 0.80, 1)',
    ))
    for i in range(6):
        caixa(f"linha_{i}", pai, .06, .18 - i * .12, .038,
              .58 if i % 2 else .68, .009, .007, "papel_sujo")


# Lixeiras clínicas pequenas, com tampa vermelha e etiqueta. Sem colisão nova:
# a navmesh do hospital permanece válida e os objetos ficam próximos das paredes.
lixeiras = [
    ("triagem", 31.45, 0, 26.35), ("recepcao", 11.10, 0, 30.4),
    ("raiox", 43.20, 0, 1.0), ("laboratorio", 54.75, 0, 8.9),
    ("cirurgia", 25.85, 0, 24.55), ("uti", 49.35, 0, 24.6),
    ("ps", 49.35, 0, 34.65), ("farmacia", 23.25, 0, 66.8),
    ("esterilizacao", 43.1, 0, 66.75), ("necroterio", 49.35, 0, 51.9),
    ("arquivo", 15.25, 4.2, 1.1), ("psiquiatria", 1.0, 4.2, 42.5),
    ("observacao", 43.0, 4.2, 65.0), ("cirurgia2", 32.3, 4.2, 52.1),
]
for nome, x, y, z in lixeiras:
    pai = "lixeira_" + nome
    node(pai, "Node3D", ".", (f'position = {v(x, y, z)}',))
    node("corpo", "MeshInstance3D", pai, (
        'mesh = SubResource("cilindro")', 'material_override = SubResource("mat_metal")',
        f'position = {v(0, .31, 0)}', f'scale = {v(.44, .62, .44)}', 'cast_shadow = 0',
    ))
    node("tampa", "MeshInstance3D", pai, (
        'mesh = SubResource("cilindro")', 'material_override = SubResource("mat_tampa")',
        f'position = {v(0, .64, 0)}', f'scale = {v(.49, .07, .49)}', 'cast_shadow = 0',
    ))
    caixa("etiqueta", pai, 0, .38, .232, .32, .18, .012, "papel")
    node("texto", "Label3D", pai, (
        'text = "INFECTANTE"', 'metadata/chave_traducao = "HOSP_SIGN_LIXO"',
        f'position = {v(0, .38, .243)}', 'font_size = 26', 'pixel_size = 0.0019',
        'modulate = Color(0.24, 0.045, 0.040, 1)',
    ))


# Pequenos objetos contam o abandono sem transformar cada sala em um obstáculo.
modelos = [
    ("saco_saguão", "saco", 1.25, 0, 39.95, 0.5, .55),
    ("saco_corredor_sul", "saco", 49.3, 0, 57.3, 1.4, .52),
    ("saco_necroterio", "saco", 49.2, 0, 44.0, 2.1, .65),
    ("saco_maquinas", "saco", 54.6, 0, 66.1, .6, .60),
    ("saco_galeria_2", "saco", 49.3, 4.2, 49.0, 1.8, .5),
    ("caixa_ps", "caixa_medica", 34.0, .95, 26.4, .3, .48),
    ("caixa_uti", "caixa_medica", 48.5, .75, 16.5, 1.2, .52),
    ("caixa_cirurgia", "caixa_medica", 33.8, .95, 24.4, .8, .48),
    ("caixa_observacao", "caixa_medica", 33.8, 5.0, 58.5, .8, .45),
    ("bloco_recepcao", "bloco", 15.1, 1.13, 31.1, .3, .70),
    ("bloco_triagem", "bloco", 34.2, 1.13, 26.4, 1.1, .65),
    ("bloco_lab", "bloco", 49.6, .96, .8, 2.1, .55),
    ("pasta_recepcao", "pasta", 15.9, 1.13, 31.2, 1.2, .55),
    ("pasta_arquivo", "pasta", 14.6, 4.9, 3.0, .1, .60),
    ("pasta_psiq", "pasta", 16.1, 5.0, 42.0, .7, .55),
    ("papelao_farmacia", "papelao", 23.0, 0, 66.0, 1.8, .50),
    ("papelao_arquivo", "papelao", 15.3, 4.2, 8.8, 2.0, .55),
    ("frasco_esteril", "frasco", 35.1, .95, 66.8, .2, .40),
    ("frasco_refeitorio", "frasco", 33.8, .95, 43.7, 2.4, .42),
]
for item in modelos:
    modelo(*item)


# Papéis abandonados em pontos controlados, com variação de ângulo e cor.
papeis = [
    (13.5, 1.14, 31.1, .2), (14.0, 1.14, 31.3, -.1),
    (16.8, 1.14, 37.2, .4), (34.4, 1.0, 26.75, -.2),
    (46.8, .96, .85, .35), (48.2, .96, .85, -.15),
    (38.0, .02, 55.1, .8), (38.5, .02, 55.3, -.5),
    (42.5, .02, 48.5, .4), (42.85, .02, 48.6, -.2),
    (14.2, 4.22, 8.8, .6), (14.5, 4.22, 8.95, -.15),
    (6.2, 4.22, 41.2, .5), (6.55, 4.22, 41.5, -.7),
]
for i, (x, y, z, rot) in enumerate(papeis):
    caixa(f"papel_{i:02d}", ".", x, y, z, .30, .006, .22,
          "papel" if i % 3 else "papel_sujo", rot)


# Lâmpadas de cor local dão leitura aos setores sem iluminar todo o prédio.
acentos = [
    ("espera_norte", 7.2, 2.45, 29.4, "Color(0.49, 0.64, 0.59, 1)", 1.35, 7.5),
    ("espera_sul", 7.2, 2.45, 39.0, "Color(0.49, 0.64, 0.59, 1)", 1.35, 7.5),
    ("recepcao", 15.2, 2.85, 31.6, "Color(0.52, 0.75, 0.64, 1)", 1.15, 5.5),
    ("triagem", 34.7, 2.6, 28.8, "Color(0.68, 0.82, 0.74, 1)", 1.0, 5.0),
    ("raiox", 40.3, 2.65, 5.0, "Color(0.28, 0.49, 0.64, 1)", .80, 5.0),
    ("cirurgia", 30.1, 2.65, 20.2, "Color(0.57, 0.78, 0.69, 1)", 1.15, 5.0),
    ("necroterio", 43.1, 2.6, 48.2, "Color(0.30, 0.46, 0.55, 1)", .85, 5.0),
    ("maquinas", 51.0, 2.45, 63.0, "Color(0.71, 0.20, 0.16, 1)", .75, 4.5),
    ("arquivo", 8.0, 6.65, 5.2, "Color(0.43, 0.62, 0.54, 1)", .75, 5.0),
    ("observacao", 38.6, 6.85, 61.9, "Color(0.42, 0.67, 0.62, 1)", .9, 5.0),
]
for nome, x, y, z, cor, energia, alcance in acentos:
    node("acento_" + nome, "OmniLight3D", ".", (
        f'position = {v(x, y, z)}', f'light_color = {cor}',
        f'light_energy = {energia}', f'omni_range = {alcance}',
        'omni_attenuation = 1.4', 'shadow_enabled = false',
        'distance_fade_enabled = true', 'distance_fade_begin = 19.0',
        'distance_fade_length = 9.0',
    ))

DESTINO.parent.mkdir(parents=True, exist_ok=True)
DESTINO.write_text("\n".join(linhas), encoding="utf-8")
print(f"{DESTINO}: {len(portas)} placas de salas, {len(avisos)} avisos, "
      f"{len(cartazes)} cartazes, {len(lixeiras)} lixeiras, "
      f"{len(modelos)} modelos e {len(acentos)} luzes")
