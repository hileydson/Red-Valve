extends Node3D

var player: Node3D = null

## A chuva.mp3 (91 s) entra com fade no primeiro segundo e sai com outro a
## partir dos 88,5 s. Chuva nao "acaba": o loop roda so' pelo trecho cheio. A
## ANTES_DO_FIM segundos do fim (antes do fade) a outra copia ja' entra em
## INICIO, cruzando com a que sai em CRUZA segundos — sem buraco nem queda.
const INICIO := 1.0
const ANTES_DO_FIM := 4.0
const CRUZA := 0.6

var _chuvas: Array[AudioStreamPlayer] = []
var _ativa := 0
var _volume := 0.0

func _ready() -> void:
	# Busca o jogador na cena (usando o grupo 'player')
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	var audio := get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	if audio and audio.stream:
		_volume = audio.volume_db
		var outra := audio.duplicate() as AudioStreamPlayer
		outra.name = "AudioStreamPlayer2"
		outra.autoplay = false
		add_child(outra)
		_chuvas = [audio, outra]

func _process(delta: float) -> void:
	if is_instance_valid(player):
		# Acompanha o jogador no eixo X e Z para a chuva sempre cair sobre ele,
		# mas pode manter um Y fixo ou acompanhar também (depende da altura do mundo)
		# Acompanhar X, Y, Z garante que a caixa de chuva sempre cobre a visão da câmera.
		self.global_position = player.global_position + Vector3(0, 15.0, 0)
	_emenda_a_chuva()

func _emenda_a_chuva() -> void:
	if _chuvas.is_empty():
		return
	var sai := _chuvas[_ativa]
	if not sai.playing:
		# parou de algum jeito: religa, como o `finished -> play` de antes fazia
		if not _chuvas[1 - _ativa].playing:
			sai.play(INICIO)
		return
	if sai.get_playback_position() < sai.stream.get_length() - ANTES_DO_FIM:
		return
	var entra := _chuvas[1 - _ativa]
	_ativa = 1 - _ativa
	entra.volume_db = -80.0
	entra.play(INICIO)
	# potencia constante: chuva e' ruido, as duas copias nao estao em fase
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		entra.volume_db = _volume + linear_to_db(maxf(sqrt(k), 0.0001))
		sai.volume_db = _volume + linear_to_db(maxf(sqrt(1.0 - k), 0.0001)), 0.0, 1.0, CRUZA)
	tw.tween_callback(func() -> void:
		sai.stop()
		sai.volume_db = _volume)
