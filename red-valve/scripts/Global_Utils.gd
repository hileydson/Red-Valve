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
