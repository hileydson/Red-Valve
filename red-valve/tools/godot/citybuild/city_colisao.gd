@tool
extends Node
## Põe a colisão da cidade na camada que o projeto usa de fato.
##
## O importador de glTF cria os `StaticBody3D` dos nós `-col` sempre na
## camada 1. Mas neste projeto o mundo sólido está na camada 2 — os
## `stop_walls` do stage_1 estão em layer=2, e o Player tem mask=2. Com a
## cidade em layer=1 o jogador atravessava casa, muro e igreja: a colisão
## existia, só que ninguém a consultava.
##
## Corrigir no `.import` exigiria uma entrada por nó em `_subresources`;
## uma varredura no `_ready` resolve os 40 corpos de uma vez e continua
## valendo depois de qualquer reimportação.

## Camada onde fica o mundo sólido. Espelha `stop_walls` do stage_1.
@export_flags_3d_physics var camada: int = 2

@export_multiline var last_result: String = ""

@export var aplicar: bool = false:
	set(v):
		aplicar = false
		if v and Engine.is_editor_hint():
			last_result = "corpos ajustados: %d" % _aplicar()


func _ready() -> void:
	if not Engine.is_editor_hint():
		_aplicar()


func _aplicar() -> int:
	var n := 0
	var pilha: Array[Node] = [self]
	while not pilha.is_empty():
		var nd: Node = pilha.pop_back()
		# PhysicsBody3D e não CollisionObject3D: Area3D também herda de
		# CollisionObject3D, e gatilho não é parede.
		if nd is PhysicsBody3D:
			var co := nd as PhysicsBody3D
			if co.collision_layer != camada:
				co.collision_layer = camada
				n += 1
		for c in nd.get_children():
			pilha.append(c)
	return n
