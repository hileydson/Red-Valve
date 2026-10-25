extends Node3D

## A cusparada da Dona Nice gigante: uma bola de gosma em arco ate' onde o
## Maycow estava. Acertou ele: dano e a tela suja de verde. Bateu no chao:
## vira poca.

const DANO := 9
const GRAVIDADE := 9.0
const RAIO := 0.55

var velocidade := Vector3.ZERO
var dono: Node = null
var _vida := 0.0

@onready var som: AudioStreamPlayer3D = $som


## Arco que chega em `alvo` em `tempo` segundos.
func lancar(origem: Vector3, alvo: Vector3, tempo: float) -> void:
	global_position = origem
	var d := alvo - origem
	velocidade = Vector3(d.x / tempo, (d.y + 0.5 * GRAVIDADE * tempo * tempo) / tempo, d.z / tempo)


func _physics_process(delta: float) -> void:
	_vida += delta
	velocidade.y -= GRAVIDADE * delta
	var antes := global_position
	global_position += velocidade * delta
	var jogador := get_tree().get_first_node_in_group("player") as Node3D
	if jogador and global_position.distance_to(jogador.global_position + Vector3(0, 0.3, 0)) < RAIO + 0.35:
		if not GlobalEvents.in_cutscene and not GlobalEvents.agarrao_rodando:
			if jogador.has_method("take_damage"):
				jogador.take_damage(DANO)
			_sujar_tela()
		_estourar(false)
		return
	# chao: raio curto do ultimo passo
	var q := PhysicsRayQueryParameters3D.create(antes, global_position + Vector3(0, -0.05, 0))
	q.collision_mask = 2
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() or _vida > 4.0:
		if not r.is_empty():
			global_position = r["position"]
		_estourar(true)


func _sujar_tela() -> void:
	var cena := get_tree().get_first_node_in_group("cena_dona_nice")
	if cena == null:
		return
	cena.gosma_na_tela = 0.7
	var t := cena.create_tween()
	t.tween_interval(0.4)
	t.tween_property(cena, "gosma_na_tela", 0.0, 2.6)


func _estourar(no_chao: bool) -> void:
	set_physics_process(false)
	$bola.visible = false
	$rastro.emitting = false
	som.play()
	if no_chao and dono and dono.has_method("criar_poca"):
		dono.criar_poca(Vector3(global_position.x, 0.0, global_position.z))
	await get_tree().create_timer(1.6, false).timeout
	queue_free()
