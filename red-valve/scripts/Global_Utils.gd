extends Node




func ativar_camera_lenta(escala: float, duracao: float):
	# Muda a velocidade do tempo
	Engine.time_scale = escala
	
	# Cria um timer para voltar ao normal
	# Usamos 'get_tree().create_timer' com o último parâmetro como 'true' 
	# para que o próprio timer ignore a câmera lenta, senão ele demoraria para acabar!
	await get_tree().create_timer(duracao * escala, true, false, true).timeout
	
	# Volta para a velocidade normal suavemente (opcional, mas fica mais bonito)
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Faz o tween ignorar o time_scale
	tween.tween_property(Engine, "time_scale", 1.0, 0.2)


func remover_camera_lenta():
	# 1. Volta a velocidade do motor ao normal imediatamente
	Engine.time_scale = 1.0
	
	# 2. Volta o áudio ao normal (usando o AudioServer que configuraste antes)
	AudioServer.set_playback_speed_scale(1.0)
	
	# 3. Se estiveres a usar Tweens para suavizar o tempo, é bom matá-los 
	# para evitar que eles tentem continuar a mudar o time_scale
	# Exemplo: se guardaste o tween numa variável 'tween_tempo'
	# if tween_tempo and tween_tempo.is_valid():
	#    tween_tempo.kill()
	
	
# No script da sua Camera3D
func shake_camera(duracao: float, forca: float):
	var camera = get_viewport().get_camera_3d()
	var original_h = camera.h_offset
	var original_v = camera.v_offset
	
	var tween = create_tween()
	
	# Cria várias posições aleatórias rápidas
	for i in range(10):
		var offset_random = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
		tween.tween_property(camera, "h_offset", offset_random.x, duracao / 10)
		tween.tween_property(camera, "v_offset", offset_random.y, duracao / 10)
	
	# Volta para a posição original no final
	tween.tween_property(camera, "h_offset", original_h, 0.1)
	tween.tween_property(camera, "v_offset", original_v, 0.1)
