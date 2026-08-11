extends Node3D

var player: Node3D = null

func _ready() -> void:
	# Busca o jogador na cena (usando o grupo 'player')
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _process(delta: float) -> void:
	if is_instance_valid(player):
		# Acompanha o jogador no eixo X e Z para a chuva sempre cair sobre ele,
		# mas pode manter um Y fixo ou acompanhar também (depende da altura do mundo)
		# Acompanhar X, Y, Z garante que a caixa de chuva sempre cobre a visão da câmera.
		self.global_position = player.global_position + Vector3(0, 15.0, 0)
