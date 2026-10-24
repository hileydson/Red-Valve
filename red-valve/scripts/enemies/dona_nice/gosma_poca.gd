extends Node3D

## Poca de baba verde que a Dona Nice gigante (fase 2) vai largando no chao.
##
## Queima quem pisa: dano pequeno a cada `INTERVALO` e o jogador fica lento
## enquanto estiver em cima. Some sozinha depois de `DURACAO` (encolhe antes,
## pra nao sumir de uma vez). Quem cria e' o boss_dona_nice_fase_2.gd.

const DANO := 4
const INTERVALO := 0.6
const DURACAO := 13.0
const LENTIDAO := 0.55

var _jogador_dentro: Node3D = null
var _proximo := 0.0
var _idade := 0.0
var _tamanho := 1.0

@onready var decal: Decal = $decal
@onready var area: Area3D = $area
@onready var bolhas: GPUParticles3D = $bolhas


func _ready() -> void:
	_tamanho = randf_range(0.85, 1.35)
	scale = Vector3(0.05, 1.0, 0.05)
	rotation.y = randf() * TAU
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(_tamanho, 1.0, _tamanho), 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	area.body_entered.connect(_ao_entrar)
	area.body_exited.connect(_ao_sair)


func _ao_entrar(b: Node3D) -> void:
	if b.is_in_group("player"):
		_jogador_dentro = b


func _ao_sair(b: Node3D) -> void:
	if b == _jogador_dentro:
		_jogador_dentro = null


func _physics_process(delta: float) -> void:
	_idade += delta
	if _idade > DURACAO:
		set_physics_process(false)
		bolhas.emitting = false
		var t := create_tween()
		t.tween_property(self, "scale", Vector3(0.02, 1.0, 0.02), 1.2)
		t.tween_callback(queue_free)
		return
	if _jogador_dentro == null or GlobalEvents.in_cutscene or GlobalEvents.agarrao_rodando:
		return
	if _jogador_dentro.has_method("apply_slow"):
		_jogador_dentro.apply_slow(LENTIDAO, 0.4)
	_proximo -= delta
	if _proximo <= 0.0:
		_proximo = INTERVALO
		if _jogador_dentro.has_method("take_damage"):
			_jogador_dentro.take_damage(DANO)
