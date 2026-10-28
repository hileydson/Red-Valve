with open("scripts/configs/main_menu_v2.gd", "r") as f:
    content = f.read()

old_loop = """func _start_menu_loop() -> void:
\tvar maycow = get_node_or_null("maycow_lopes")
\tvar cam = $Camera3D
\t
\tif not maycow or not cam:
\t\treturn
\t
\t# Cria um pivot no centro (mesma posicao inicial do maycow)
\tvar pivot = Node3D.new()
\tadd_child(pivot)
\tpivot.global_position = Vector3(0, 0, 0)
\t
\t# Reparenta a camera para o pivot para fazer orbita facilmente
\tcam.get_parent().remove_child(cam)
\tpivot.add_child(cam)
\t
\tvar duration = 14.0
\tvar pause_duration = 4.0
\t
\tvar maycow_orig_pos = maycow.position
\t# Move para a esquerda na visão da camera (a camera olha para +Z, logo a esquerda dela é +X)
\tvar maycow_target_pos = maycow_orig_pos + Vector3(0.5, 0, 0)
\t
\tvar pivot_orig_rot = pivot.rotation
\t# Gira a camera para a direita (negativo no eixo Y)
\tvar pivot_target_rot = pivot_orig_rot + Vector3(0, -0.4, 0)
\t
\tvar loop_tween = create_tween().set_loops()
\t
\t# Vai devagar e gradual
\tloop_tween.tween_property(maycow, "position", maycow_target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\tloop_tween.parallel().tween_property(pivot, "rotation", pivot_target_rot, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\t
\t# Espera
\tloop_tween.tween_interval(pause_duration)
\t
\t# Volta
\tloop_tween.tween_property(maycow, "position", maycow_orig_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\tloop_tween.parallel().tween_property(pivot, "rotation", pivot_orig_rot, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\t
\t# Espera
\tloop_tween.tween_interval(pause_duration)"""

new_loop = """func _start_menu_loop() -> void:
\tvar maycow = get_node_or_null("maycow_lopes")
\tvar cam = $Camera3D
\t
\tif not maycow or not cam:
\t\treturn
\t
\t# 1. Primeiro move para a esquerda e dá um pequeno zoom.
\tvar move_duration = 6.0
\tvar maycow_target_pos = maycow.position + Vector3(0.5, 0, 0)
\t
\tvar intro_tween = create_tween()
\tintro_tween.tween_property(maycow, "position", maycow_target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\t
\t# Zoom - camera olha para +Z (Z=-1.3 para Z=-0.9)
\tvar cam_target_pos = cam.position + Vector3(0, 0, 0.4)
\tintro_tween.parallel().tween_property(cam, "position", cam_target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\t
\tawait intro_tween.finished
\t
\t# 2. Depois de ir para a esquerda, começa o loop de girar a camera em volta do modelo.
\tvar pivot = Node3D.new()
\tadd_child(pivot)
\tpivot.global_position = maycow.global_position
\t
\tcam.get_parent().remove_child(cam)
\tpivot.add_child(cam)
\t
\tvar duration_loop = 16.0
\tvar pause_duration = 3.0
\t
\tvar pivot_orig_rot = pivot.rotation
\t# Gira 1/4 de volta partindo das costas (-PI/2 ou +PI/2 dependendo da orientacao)
\t# A camera começa de costas para o personagem (0). Vamos girar até ver ele de lado.
\tvar pivot_target_rot = pivot_orig_rot + Vector3(0, -1.57, 0)
\t
\tvar loop_tween = create_tween().set_loops()
\t
\t# Vai devagar em volta do modelo 3d
\tloop_tween.tween_property(pivot, "rotation", pivot_target_rot, duration_loop).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\tloop_tween.tween_interval(pause_duration)
\t
\t# Volta
\tloop_tween.tween_property(pivot, "rotation", pivot_orig_rot, duration_loop).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\tloop_tween.tween_interval(pause_duration)"""

content = content.replace(old_loop, new_loop)

old_idle = """\t# Tocar idle
\tvar maycow = get_node_or_null("maycow_lopes")
\tif maycow and maycow.has_node("AnimationPlayer"):
\t\tvar ap = maycow.get_node("AnimationPlayer")
\t\tif ap.has_animation("idle"):
\t\t\tap.play("idle")"""

new_idle = """\t# Tocar idle
\tvar maycow = get_node_or_null("maycow_lopes")
\tif maycow and maycow.has_node("AnimationPlayer"):
\t\tvar ap = maycow.get_node("AnimationPlayer")
\t\tfor anim in ap.get_animation_list():
\t\t\tif "idle" in anim.to_lower():
\t\t\t\tap.get_animation(anim).loop_mode = 1 # Animation.LOOP_LINEAR
\t\t\t\tap.play(anim)
\t\t\t\tbreak"""

content = content.replace(old_idle, new_idle)

with open("scripts/configs/main_menu_v2.gd", "w") as f:
    f.write(content)

