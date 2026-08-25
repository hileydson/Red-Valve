import re

with open("scripts/configs/main_menu_v2.gd", "r") as f:
    content = f.read()

new_funcs = """
var old_film_layer: CanvasLayer = null

func _setup_old_film_filter() -> void:
\told_film_layer = CanvasLayer.new()
\told_film_layer.layer = 110
\tadd_child(old_film_layer)
\t
\tvar back_buffer = BackBufferCopy.new()
\tback_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
\told_film_layer.add_child(back_buffer)
\t
\tvar film_rect = ColorRect.new()
\tfilm_rect.name = "OldFilmOverlay"
\tfilm_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
\tfilm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t
\tvar shader_code: String = \"\"\"
\tshader_type canvas_item;

\tuniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
\tuniform float sepia_amount : hint_range(0.0, 1.0) = 0.35;
\tuniform float grain_amount : hint_range(0.0, 1.0) = 0.18;
\tuniform float scratch_amount : hint_range(0.0, 1.0) = 0.35;
\tuniform float vignette_amount : hint_range(0.0, 1.0) = 0.65;
\tuniform float flicker_amount : hint_range(0.0, 1.0) = 0.08;

\tfloat rand(vec2 co) {
\t\treturn fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
\t}

\tvoid fragment() {
\t\tvec2 uv = SCREEN_UV;
\t\tvec4 color = texture(screen_texture, uv);
\t\t
\t\tvec3 sepia = vec3(
\t\t\tdot(color.rgb, vec3(0.393, 0.769, 0.189)),
\t\t\tdot(color.rgb, vec3(0.349, 0.686, 0.168)),
\t\t\tdot(color.rgb, vec3(0.272, 0.534, 0.131))
\t\t);
\t\tcolor.rgb = mix(color.rgb, sepia, sepia_amount);
\t\t
\t\tfloat noise = rand(uv + vec2(TIME * 18.0, TIME * 33.0));
\t\tcolor.rgb += (noise - 0.5) * grain_amount;
\t\t
\t\tfloat scratch_rand = rand(vec2(floor(uv.x * 250.0), floor(TIME * 12.0)));
\t\tif (scratch_rand > (1.0 - scratch_amount * 0.04)) {
\t\t\tfloat scratch_int = rand(vec2(uv.x, TIME * 5.0));
\t\t\tcolor.rgb -= vec3(scratch_int * 0.35);
\t\t}
\t\t
\t\tfloat dist = distance(uv, vec2(0.5, 0.5));
\t\tfloat vignette = smoothstep(0.85, 0.25, dist * vignette_amount);
\t\tcolor.rgb *= mix(1.0, vignette, vignette_amount);
\t\t
\t\tfloat flicker = sin(TIME * 35.0) * 0.5 + 0.5;
\t\tcolor.rgb *= (1.0 - flicker * flicker_amount);
\t\t
\t\tCOLOR = color;
\t}
\t\"\"\"
\tvar shader = Shader.new()
\tshader.code = shader_code
\t
\tvar mat = ShaderMaterial.new()
\tmat.shader = shader
\tfilm_rect.material = mat
\told_film_layer.add_child(film_rect)

func _start_menu_loop() -> void:
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
\tloop_tween.tween_interval(pause_duration)
"""

# Insert new_funcs right before _ready
content = content.replace("func _ready() -> void:", new_funcs + "\nfunc _ready() -> void:")

# Add calls to _ready
ready_calls = """
\t_setup_old_film_filter()
\t_start_menu_loop()
"""
content = content.replace("input_locked = false", "input_locked = false\n" + ready_calls)

with open("scripts/configs/main_menu_v2.gd", "w") as f:
    f.write(content)
