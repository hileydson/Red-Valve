extends Node3D

@export_group("Configurações do Caos")
@export var velocidade_movimento: float = 2.0
@export var area_de_movimento: Vector3 = Vector3(3.0, 2.0, 3.0)
@export var velocidade_rotacao: float = 3.0

# Classe interna para guardar o estado de cada peça
class PecaData:
	var node: Node3D
	var posicao_inicial: Vector3
	var offset_tempo: float
	var eixo_rotacao: Vector3
	var multiplicador_velocidade: float

var pecas_ativas: Array[PecaData] = []
var tempo_decorrido: float = 0.0

func _ready() -> void:
	randomize()
	
	# Percorre todos os filhos do nó "pecas"
	for child in get_children():
		if child is Node3D:
			var data = PecaData.new()
			data.node = child
			data.posicao_inicial = child.position
			
			# Cada peça começa em um "tempo" diferente para não sincronizarem
			data.offset_tempo = randf_range(0.0, 100.0)
			
			# Um eixo 3D maluco aleatório para ela ficar capotando no ar
			data.eixo_rotacao = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			
			# Algumas peças giram mais rápido que as outras
			data.multiplicador_velocidade = randf_range(0.5, 2.5)
			
			pecas_ativas.append(data)

func _process(delta: float) -> void:
	tempo_decorrido += delta * velocidade_movimento
	
	for data in pecas_ativas:
		var t = tempo_decorrido + data.offset_tempo
		
		# Matemática de ondas combinadas (Lissajous) para criar um movimento super caótico (não repetitivo)
		var offset_x = sin(t * 1.3) * cos(t * 0.8) * area_de_movimento.x
		var offset_y = sin(t * 1.1) * sin(t * 0.5) * area_de_movimento.y
		var offset_z = cos(t * 1.2) * sin(t * 0.9) * area_de_movimento.z
		
		# Aplica a nova posição baseada no ponto onde você colocou elas na Godot
		var nova_posicao = data.posicao_inicial + Vector3(offset_x, offset_y, offset_z)
		data.node.position = data.node.position.lerp(nova_posicao, delta * 8.0) # Lerp deixa macio
		
		# Faz ela capotar no ar
		data.node.rotate(data.eixo_rotacao, velocidade_rotacao * data.multiplicador_velocidade * delta)
