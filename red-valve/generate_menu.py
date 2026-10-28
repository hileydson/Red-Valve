uid_scene = "uid://cnew_menu123"

gd = """extends Node3D

@onready var start: Button = $UI/Control/VBoxContainer/start
@onready var load_btn: Button = $UI/Control/VBoxContainer/load
@onready var ashen: AudioStreamPlayer = $AshenSerenity

var input_locked: bool = true

func _ready() -> void:
\tInput.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
\tstart.grab_focus()
\t
\tif not FileAccess.file_exists("user://save_game.json"):
\t\tload_btn.disabled = true
\t
\tvar ashen_target = ashen.volume_db
\tashen.volume_db = -80.0
\tvar audio_in_tween = create_tween()
\taudio_in_tween.tween_property(ashen, "volume_db", ashen_target, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
\t
\t# Tocar idle
\tvar maycow = $maycow_lopes
\tif maycow.has_node("AnimationPlayer"):
\t\tvar ap = maycow.get_node("AnimationPlayer")
\t\tif ap.has_animation("idle"):
\t\t\tap.play("idle")
\t
\tawait get_tree().create_timer(2.0).timeout
\tinput_locked = false

func _on_load_pressed() -> void:
\tif input_locked: return
\t$UI/Control.visible = false
\tvar audio_out_tween = create_tween()
\taudio_out_tween.tween_property(ashen, "volume_db", -80.0, 2.0)
\t$UI/fade.fade_out()
\tawait get_tree().create_timer(2.0).timeout
\tSaveManager.load_game()

func _on_start_pressed() -> void:
\tif input_locked: return
\t$UI/Control.visible = false
\tvar audio_out_tween = create_tween()
\taudio_out_tween.tween_property(ashen, "volume_db", -80.0, 2.0)
\t$UI/fade.fade_out()
\tawait get_tree().create_timer(2.0).timeout
\tget_tree().change_scene_to_file("res://scenes/stages/stage_1/stage_1_cutscene_prologo.tscn")

func _on_config_pressed() -> void:
\tif input_locked: return
\tvar config_script = load("res://scripts/ui/config_menu.gd")
\tif config_script:
\t\tvar config_menu = config_script.new()
\t\tadd_child(config_menu)
\t\t$UI/Control.visible = false
\t\tconfig_menu.back_btn.pressed.disconnect(config_menu._on_back_pressed)
\t\tconfig_menu.back_btn.pressed.connect(func():
\t\t\tSaveManager.save_game()
\t\t\t$UI/Control.visible = true
\t\t\t$UI/Control/VBoxContainer/config.grab_focus()
\t\t\tconfig_menu.queue_free()
\t\t)

func _on_exit_pressed() -> void:
\tif input_locked: return
\tget_tree().quit()
"""

tscn = """[gd_scene format=3 uid="uid://cnew_menu123"]

[ext_resource type="Script" uid="uid://cnew_menu_script" path="res://scripts/configs/main_menu_v2.gd" id="1_menu"]
[ext_resource type="AudioStream" uid="uid://d34lkiwwli5f0" path="res://assets/sounds/menu/Ashen_Serenity.mp3" id="2_audio"]
[ext_resource type="Texture2D" uid="uid://bvgwpas0j658a" path="res://assets/images/enemies/blood_mark.png" id="3_blood"]
[ext_resource type="PackedScene" uid="uid://dy356o67p6jyn" path="res://scenes/configs/fade.tscn" id="4_fade"]
[ext_resource type="PackedScene" uid="uid://c5s652o5x75x1" path="res://assets/3d_model/player/maycow_lopes.glb" id="5_maycow"]
[ext_resource type="FontFile" uid="uid://bx5lqom14sryx" path="res://assets/fonts/Montserrat-ExtraBold.ttf" id="6_font"]

[sub_resource type="Environment" id="Environment_menu"]
background_mode = 1
background_color = Color(0.15, 0.15, 0.15, 1)

[node name="Main_Menu_V2" type="Node3D"]
script = ExtResource("1_menu")

[node name="AshenSerenity" type="AudioStreamPlayer" parent="."]
stream = ExtResource("2_audio")
volume_db = -4.208
pitch_scale = 0.45
autoplay = true

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_menu")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.25, 0.433013, 0, 0.866025, 0.5, -0.5, -0.433013, 0.75, 0, 5, 0)
light_color = Color(1, 0.95, 0.9, 1)
light_energy = 0.5
shadow_enabled = true

[node name="maycow_lopes" parent="." instance=ExtResource("5_maycow")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(-1, 0, 8.74228e-08, 0, 1, 0, -8.74228e-08, 0, -1, 0, 0.9, -1.3)
current = true

[node name="UI" type="CanvasLayer" parent="."]

[node name="TitleLabel" type="Label" parent="UI"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -600.0
offset_top = -130.0
offset_right = 600.0
offset_bottom = 130.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(1, 0.08, 0.08, 1)
theme_override_fonts/font = ExtResource("6_font")
theme_override_font_sizes/font_size = 200
text = "RED VALVE"
horizontal_alignment = 1
vertical_alignment = 1

[node name="Control" type="Control" parent="UI"]
layout_mode = 3
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -300.0
offset_top = -300.0
offset_right = 0.0
offset_bottom = 0.0
grow_horizontal = 0
grow_vertical = 0
mouse_filter = 2

[node name="BloodMark" type="Sprite2D" parent="UI/Control"]
modulate = Color(0.7564044, 0.7564044, 0.7564044, 1)
position = Vector2(82, 138)
scale = Vector2(0.73162943, 0.6501597)
texture = ExtResource("3_blood")

[node name="VBoxContainer" type="VBoxContainer" parent="UI/Control"]
layout_mode = 0
offset_left = 0.0
offset_top = 56.0
offset_right = 144.0
offset_bottom = 192.0

[node name="start" type="Button" parent="UI/Control/VBoxContainer"]
layout_mode = 2
text = "BTN_START"

[node name="load" type="Button" parent="UI/Control/VBoxContainer"]
layout_mode = 2
text = "BTN_LOAD_GAME"

[node name="config" type="Button" parent="UI/Control/VBoxContainer"]
layout_mode = 2
text = "MENU_CONFIG"

[node name="exit" type="Button" parent="UI/Control/VBoxContainer"]
layout_mode = 2
text = "BTN_EXIT"

[node name="fade" parent="UI" instance=ExtResource("4_fade")]

[connection signal="pressed" from="UI/Control/VBoxContainer/start" to="." method="_on_start_pressed"]
[connection signal="pressed" from="UI/Control/VBoxContainer/load" to="." method="_on_load_pressed"]
[connection signal="pressed" from="UI/Control/VBoxContainer/config" to="." method="_on_config_pressed"]
[connection signal="pressed" from="UI/Control/VBoxContainer/exit" to="." method="_on_exit_pressed"]
"""

with open("scenes/configs/main_menu_v2.tscn", "w") as f:
    f.write(tscn)
    
with open("scripts/configs/main_menu_v2.gd", "w") as f:
    f.write(gd)
    
print("generated files")
