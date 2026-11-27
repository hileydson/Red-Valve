# -*- coding: utf-8 -*-
"""Cena do Godot de um lekroso novo: red-valve/scenes/enemies/lekrosos/<nome>.tscn

    python3 tools/blender/lekrosos/gerar_cena.py lekroso_N

So' escreve se a cena NAO existe: depois de criada ela e' do jogo (pode ser
ajustada no editor sem medo de o construir.sh desfazer). Todo lekroso e' o
mesmo corpo de regras (`lekroso.gd`); o que muda e' o modelo (`modelo`) e a
tabela das pecas dele (`dados`, o `<nome>_dados.gd` do cortar.py/animar.py).
"""

import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
CENAS = os.path.join(RAIZ, "red-valve/scenes/enemies/lekrosos")

MOLDE = """[gd_scene load_steps=10 format=3]

[ext_resource type="Script" path="res://scripts/enemies/lekrosos/lekroso.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/3d_model/enemies/lekrosos/{nome}/{nome}_rig.glb" id="2_modelo"]
[ext_resource type="AudioStream" path="res://assets/sounds/enemies/zombies/zombie_steps.mp3" id="3_passos"]
[ext_resource type="AudioStream" path="res://assets/sounds/enemies/zombies/zombie_1_attack.mp3" id="4_ataque"]
[ext_resource type="AudioStream" path="res://assets/sounds/enemies/zombies/zombie_dead.mp3" id="5_morte"]
[ext_resource type="AudioStream" path="res://assets/sounds/enemies/growl_2.mp3" id="6_dor"]
[ext_resource type="AudioStream" path="res://assets/sounds/igreja/mordida_1.ogg" id="7_mordida"]
[ext_resource type="Script" path="res://scripts/enemies/lekrosos/{nome}_dados.gd" id="8_dados"]

[sub_resource type="CapsuleShape3D" id="corpo"]
radius = 0.15
height = 1.45

[node name="{nome}" type="CharacterBody3D" groups=["enemies"]]
editor_description = "{titulo}, um dos lekrosos (cena gerada por tools/blender/lekrosos/gerar_cena.py). Mesmo comportamento de todos: zumbi que perambula onde for posto, persegue devagar e agarra/morde (player_grab, ramo mordida). Dano por regiao e desmembramento (pecas feitas em tools/blender/lekrosos/). Frente = +Z."
collision_layer = 4
collision_mask = 2
script = ExtResource("1_script")
dados = ExtResource("8_dados")

[node name="forma" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.725, 0)
shape = SubResource("corpo")

[node name="modelo" parent="." instance=ExtResource("2_modelo")]

[node name="growl_attack" type="AudioStreamPlayer3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)
stream = ExtResource("4_ataque")
volume_db = 2.0
max_distance = 30.0

[node name="sons" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.3, 0)

[node name="passos" type="AudioStreamPlayer3D" parent="sons"]
stream = ExtResource("3_passos")
volume_db = -8.0
max_distance = 22.0

[node name="gemido" type="AudioStreamPlayer3D" parent="sons"]
volume_db = -2.0
max_distance = 32.0

[node name="dor" type="AudioStreamPlayer3D" parent="sons"]
stream = ExtResource("6_dor")
max_distance = 30.0

[node name="morte" type="AudioStreamPlayer3D" parent="sons"]
stream = ExtResource("5_morte")
volume_db = 2.0
max_distance = 35.0

[node name="mordida" type="AudioStreamPlayer3D" parent="sons"]
stream = ExtResource("7_mordida")
volume_db = 4.0
max_distance = 15.0
"""


def main():
    nome = sys.argv[1]
    destino = os.path.join(CENAS, nome + ".tscn")
    if os.path.exists(destino):
        print("== cena ja' existe (nao mexi):", destino)
        return
    titulo = nome.replace("_", " ").capitalize()
    os.makedirs(CENAS, exist_ok=True)
    with open(destino, "w", encoding="utf-8") as f:
        f.write(MOLDE.format(nome=nome, titulo=titulo))
    print("== cena", destino)


main()
