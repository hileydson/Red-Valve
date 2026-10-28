"""Gera a camada visual complementar do hospital sem tocar na planta/navmesh.

Execute da raiz red-valve: python3 tools/hospital/gerar_detalhes_hospital.py
As coordenadas seguem as portas e salas de scenes/stages/hospital/hospital.tscn.
"""

import csv
import json
import math
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DESTINO = ROOT / "scenes/stages/hospital/hospital_detalhes.tscn"

# A planta do hospital: as placas de porta saem das PORTAS dela, e os avisos
# encostam na face da parede que ela diz que existe.
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT.parent / "tools/godot/hospital"))
import planta as P  # noqa: E402

with open(ROOT / "assets/textos/red_valve_textos_gerais.csv", encoding="utf-8") as f:
    TEXTOS = {linha["keys"]: linha for linha in csv.DictReader(f)}


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
    '[sub_resource type="CylinderShape3D" id="colisao_lixeira"]',
    'radius = 0.245',
    'height = 0.70',
    '',
    '[node name="hospital_detalhes" type="Node3D"]',
    'script = ExtResource("1")',
    '',
])
formas_fisicas = []


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


def modelo(nome, tipo, x, y, z, rot=0, escala=1, fisico=False):
    indice = list(assets).index(tipo) + 2
    if fisico:
        caminho = ROOT / assets[tipo].removeprefix("res://")
        dados = json.loads(caminho.read_text(encoding="utf-8"))
        minimo, maximo = [float("inf")] * 3, [float("-inf")] * 3
        for malha in dados["meshes"]:
            for primitiva in malha["primitives"]:
                acesso = dados["accessors"][primitiva["attributes"]["POSITION"]]
                for eixo in range(3):
                    minimo[eixo] = min(minimo[eixo], acesso["min"][eixo])
                    maximo[eixo] = max(maximo[eixo], acesso["max"][eixo])
        forma = "fisico_" + str(len(formas_fisicas) // 3)
        formas_fisicas.extend([
            f'[sub_resource type="BoxShape3D" id={q(forma)}]',
            f'size = {v(*(max(.05, (maximo[e] - minimo[e]) * escala) for e in range(3)))}',
            '',
        ])
        # Algumas caixas têm origem no centro; compensar evita nascerem sob o piso.
        altura = max(0.0, -minimo[1] * escala)
        node(nome, "RigidBody3D", ".", (
            f'position = {v(x, y + altura, z)}',
            f'rotation = {v(0, rot, 0)}',
            'collision_layer = 2', 'collision_mask = 2',
            'mass = 3.0', 'linear_damp = 2.0', 'angular_damp = 3.0',
        ))
        node("malha", None, nome, (f'scale = {v(escala, escala, escala)}',), str(indice))
        node("colisao", "CollisionShape3D", nome, (
            f'position = {v(*( (minimo[e] + maximo[e]) * .5 * escala for e in range(3)))}',
            f'shape = SubResource({q(forma)})',
        ))
        return
    node(nome, None, ".", (
        f'position = {v(x, y, z)}',
        f'rotation = {v(0, rot, 0)}',
        f'scale = {v(escala, escala, escala)}',
    ), str(indice))


def _largura_do_texto(chave, texto, font_size, pixel_size):
    """Quanto o texto ocupa (m), pelo mais comprido entre o PT e o EN."""
    linha = TEXTOS.get(chave, {})
    letras = max(len(texto), len(linha.get("en", "")), len(linha.get("pt", "")))
    return letras * font_size * pixel_size * 0.56


def placa(nome, chave, texto, x, y, z, rot=0, alerta=False, font_size=34,
          pixel_size=0.0022, altura=.20):
    """Placa de parede: o tamanho segue o texto. O texto e' SOMBREADO (recebe a
    luz da cena como a chapa): sem isso o Label3D desenha sem luz nenhuma e
    a palavra parece acesa no corredor escuro."""
    largura = _largura_do_texto(chave, texto, font_size, pixel_size) + .16
    node(nome, "Node3D", ".", (
        f'position = {v(x, y, z)}',
        f'rotation = {v(0, rot, 0)}',
    ))
    caixa("base", nome, 0, 0, 0, largura, altura, .024, "borda")
    caixa("face", nome, 0, 0, .014, largura - .03, altura - .03, .005, "placa")
    caixa("faixa", nome, -largura / 2 + .045, 0, .018, .03, altura - .06, .005,
          "vermelho" if alerta else "amarelo")
    node("texto", "Label3D", nome, (
        f'text = {q(texto)}',
        f'metadata/chave_traducao = {q(chave)}',
        f'position = {v(.02, -.004, .0185)}',
        f'font_size = {font_size}',
        f'pixel_size = {pixel_size}',
        'shaded = true',
        'outline_size = 0',
        'modulate = Color(0.80, 0.84, 0.76, 1)',
    ))


def _frente(rot):
    """Pra onde a placa olha (o +Z dela, girado)."""
    return math.sin(rot), math.cos(rot)


def _na_face_da_parede(x, y, z, rot):
    """Encosta a placa (dada mais ou menos no lugar) na face da parede mais
    proxima atras dela. As coordenadas antigas eram do eixo da parede: a chapa
    ficava DENTRO dela e so' o texto aparecia."""
    fx, fz = _frente(rot)
    andar = 2 if y >= P.ANDAR_2 - .1 else 1
    melhor = None
    for m in P.muros(andar):
        if abs(fz) > .5 and m["eixo"] == "x":
            perto, ao_longo, sinal = abs(m["coord"] - z), x, fz
        elif abs(fx) > .5 and m["eixo"] == "z":
            perto, ao_longo, sinal = abs(m["coord"] - x), z, fx
        else:
            continue
        if perto < .6 and min(m["a"], m["b"]) - .1 <= ao_longo <= max(m["a"], m["b"]) + .1:
            if melhor is None or perto < melhor[0]:
                melhor = (perto, m, sinal)
    if melhor is None:
        return x, y, z
    _, m, sinal = melhor
    face = m["coord"] + sinal * (m["esp"] * .5 + .013)
    return (x, y, face) if m["eixo"] == "x" else (face, y, z)


def _espaco_em(x, z, andar):
    for e in P.espacos(andar):
        if e["x0"] <= x <= e["x1"] and e["z0"] <= z <= e["z1"]:
            return e
    return None


# Placas acima das portas, tiradas das portas da planta: do lado de FORA da
# sala, coladas na face da parede, centradas no vao e logo acima do batente.
def _placas_de_porta():
    lista = []
    for m in P.muros():
        for vao in m["vaos"]:
            if vao.get("tipo") != "porta" or not vao.get("sala"):
                continue
            sala = P.por_ident(vao["sala"])
            if not sala or not sala.get("chave"):
                continue
            for lado in (1.0, -1.0):
                if m["eixo"] == "x":
                    px, pz = vao["c"], m["coord"] + lado * .6
                else:
                    px, pz = m["coord"] + lado * .6, vao["c"]
                e = _espaco_em(px, pz, m["andar"])
                if e is None or e["ident"] == sala["ident"]:
                    continue
                face = m["coord"] + lado * (m["esp"] * .5 + .013)
                y = P.cota(m["andar"]) + P.PORTA_H + .16
                if m["eixo"] == "x":
                    pos, rot = (vao["c"], y, face), (0.0 if lado > 0 else math.pi)
                else:
                    pos, rot = (face, y, vao["c"]), (math.pi * .5 if lado > 0 else -math.pi * .5)
                lista.append((sala["ident"], sala["chave"], pos, rot))
                break
    return lista


portas = _placas_de_porta()
vistos = {}
for ident, chave, (x, y, z), rot in portas:
    vistos[ident] = vistos.get(ident, 0) + 1
    nome = "porta_" + ident + ("" if vistos[ident] == 1 else "_%d" % vistos[ident])
    placa(nome, chave, TEXTOS[chave]["pt"], x, y, z, rot,
          font_size=30, pixel_size=0.0019, altura=.17)


# Sinalização institucional e avisos clínicos perto do fluxo natural do jogador.
avisos = [
    ("recepcao", "HOSP_SIGN_RECEPCAO", "RECEPÇÃO / TRIAGEM", 15.2, 2.75, 25.58, 0, False),
    ("emergencia", "HOSP_SIGN_EMERGENCIA", "EMERGÊNCIA", 40.3, 2.55, 42.52, 3.14159, True),
    ("higiene", "HOSP_SIGN_HIGIENE", "HIGIENIZE AS MÃOS", 34.8, 1.8, 25.58, 0, False),
    ("silencio", "HOSP_SIGN_SILENCIO", "SILÊNCIO / PACIENTES", 20.6, 1.8, 10.32, 0, False),
    ("restrito", "HOSP_SIGN_RESTRITO", "ACESSO RESTRITO", 38.6, 1.85, 58.04, 3.14159, True),
    ("isolamento", "HOSP_SIGN_ISOLAMENTO", "ISOLAMENTO", 42.8, 1.8, 15.39, 3.14159, True),
    ("elevador_1", "HOSP_SIGN_ELEVADOR", "ELEVADOR", 51.0, 2.85, 36.0, -1.5708, False),
    ("elevador_2", "HOSP_SIGN_ELEVADOR", "ELEVADOR", 51.0, 7.05, 36.0, -1.5708, False),
    ("saida", "HOSP_SIGN_SAIDA", "SAÍDA", 1.1, 2.8, 34.2, 1.5708, False),
    ("ala_1", "HOSP_SIGN_ALA_1", "ALA CLÍNICA / 1º ANDAR", 24.2, 2.78, 10.32, 0, False),
    ("ala_2", "HOSP_SIGN_ALA_2", "ALA CLÍNICA / 2º ANDAR", 24.2, 6.98, 28.31, 0, False),
    ("residuos", "HOSP_SIGN_RESIDUOS", "RESÍDUOS INFECTANTES", 49.8, 1.8, 67.52, 3.14159, True),
]
for nome, chave, texto, x, y, z, rot, alerta in avisos:
    placa(nome, chave, texto, *_na_face_da_parede(x, y, z, rot), rot, alerta)


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
    x, y, z = _na_face_da_parede(x, y, z, rot)
    node(pai, "Node3D", ".", (
        f'position = {v(x + _frente(rot)[0] * .008, y, z + _frente(rot)[1] * .008)}',
        f'rotation = {v(0, rot, 0)}',
    ))
    caixa("moldura", pai, 0, 0, 0, .95, 1.28, .04, "borda")
    caixa("papel", pai, 0, 0, .027, .85, 1.17, .009, "papel")
    caixa("faixa", pai, 0, .42, .035, .85, .16, .01, "vermelho")
    caixa("cruz_v", pai, -.31, .15, .037, .035, .16, .011, "vermelho")
    caixa("cruz_h", pai, -.31, .15, .039, .14, .035, .011, "vermelho")
    node("titulo", "Label3D", pai, (
        f'text = {q(texto)}', f'metadata/chave_traducao = {q(chave)}',
        f'position = {v(0, .41, .046)}', 'font_size = 38',
        'pixel_size = 0.0026', 'shaded = true', 'modulate = Color(0.93, 0.90, 0.80, 1)',
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
    node(pai, "RigidBody3D", ".", (
        f'position = {v(x, y, z)}',
        'collision_layer = 2', 'collision_mask = 2',
        'mass = 3.0', 'linear_damp = 2.0', 'angular_damp = 3.0',
    ))
    node("colisao", "CollisionShape3D", pai, (
        f'position = {v(0, .35, 0)}',
        'shape = SubResource("colisao_lixeira")',
    ))
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
        f'position = {v(0, .38, .243)}', 'font_size = 26', 'pixel_size = 0.0019', 'shaded = true',
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
    modelo(*item, fisico=(item[1] in ("saco", "papelao") and item[3] in (0, 4.2)))


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

raiz = linhas.index('[node name="hospital_detalhes" type="Node3D"]')
linhas[raiz:raiz] = formas_fisicas
linhas[0] = f'[gd_scene load_steps={1 + sum(l.startswith(("[ext_resource", "[sub_resource")) for l in linhas)} format=3]'
DESTINO.parent.mkdir(parents=True, exist_ok=True)
DESTINO.write_text("\n".join(linhas), encoding="utf-8")
print(f"{DESTINO}: {len(portas)} placas de salas, {len(avisos)} avisos, "
      f"{len(cartazes)} cartazes, {len(lixeiras)} lixeiras, "
      f"{len(modelos)} modelos e {len(acentos)} luzes")
