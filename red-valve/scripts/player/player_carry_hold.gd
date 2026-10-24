extends SkeletonModifier3D

## Os bracos do Maycow normal na pose de COLO (o Jonny nos bracos).
##
## As pernas continuam no andar da AnimationTree; so' os bracos (e o pescoco,
## olhando pro menino) sao reescritos por cima, na pose do clipe
## `parado_carregando` da biblioteca `maycow_clipes.tres` — a MESMA que a
## cutscene da igreja usa. Pra mudar a pose do colo, mexa no clipe no
## AnimationPlayer (ex.: cena maycow_cena.tscn), nao aqui.
##
## Rotacao LOCAL de cada osso: como a cadeia pende do peito (Spine), a pose
## anda junto com o tronco do andar sem conta nenhuma.

const CLIPES := "res://assets/3d_model/npc/igreja/maycow_clipes.tres"
const CLIPE := &"parado_carregando"
const OSSOS := ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand", "neck"]
## Quanto tempo (s) a pose leva pra entrar e sair.
const TRANSICAO := 0.35

## 1 = colo, 0 = bracos livres (quem liga/desliga e' o player_carregar_jonny).
var peso_alvo: float = 1.0
var _peso: float = 0.0
var _rot: Dictionary = {}       # indice do osso -> Quaternion


func _ready() -> void:
	var lib := load(CLIPES) as AnimationLibrary
	if lib == null or not lib.has_animation(CLIPE):
		push_warning("player_carry_hold: sem o clipe %s" % CLIPE)
		return
	var anim := lib.get_animation(CLIPE)
	var sk := get_skeleton()
	if sk == null:
		return
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var osso := String(anim.track_get_path(t)).get_slice(":", 1)
		if osso in OSSOS:
			var i := sk.find_bone(osso)
			if i >= 0:
				_rot[i] = anim.rotation_track_interpolate(t, 0.0)


func esta_solto() -> bool:
	return _peso <= 0.001 and peso_alvo <= 0.0


func _process_modification_with_delta(delta: float) -> void:
	_peso = move_toward(_peso, peso_alvo, delta / TRANSICAO)
	if _peso <= 0.0:
		return
	var sk := get_skeleton()
	var u := _peso * _peso * (3.0 - 2.0 * _peso)
	for i in _rot:
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(_rot[i], u))
