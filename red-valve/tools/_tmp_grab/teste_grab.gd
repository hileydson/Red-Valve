extends Node

var _sala: Node
var _ok := 0
var _total := 0

func _ready() -> void:
	SaveManager.current_slot = 9
	await get_tree().process_frame
	_sala = load("res://scenes/tests/sala_de_teste.tscn").instantiate()
	add_child(_sala)
	await get_tree().create_timer(2.0).timeout
	var p: Node3D = _sala._player
	var lek: Node3D = _sala._inimigos[0]
	for caso in ["frente_atirando", "costas", "cambaleando_perto", "lado_atirando"]:
		await _caso(caso, p, lek)
	print("RESULTADO ", _ok, "/", _total)
	get_tree().quit()

func _caso(nome: String, p: Node3D, lek: Node3D) -> void:
	# espera qualquer agarrao anterior acabar
	var t := 0.0
	while GlobalEvents.agarrao_rodando and t < 15.0:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	await get_tree().create_timer(2.5).timeout
	p.current_health = p.max_health
	p.global_position = Vector3(0, 1.12, 0)
	p.rotation.y = 0.0  # olha pro -Z
	var ang := 0.0
	match nome:
		"costas", "costas_atirando": ang = PI      # atras: +Z
		"lado_atirando": ang = PI * 0.5
		_: ang = 0.0                               # frente: -Z
	var d := 2.6
	if nome == "cambaleando_perto":
		d = 1.6
	var pos := Vector3(sin(ang) * -d, 0.05, cos(ang) * -d)
	lek.global_position = pos
	lek.velocity = Vector3.ZERO
	lek.look_at(Vector3(0, pos.y, 0), Vector3.UP, true)
	lek.set("_solto_ate", 0.0)
	lek.set("_ultimo_toque", -10.0)
	lek.current_health = lek.max_health
	lek._comecar_caca(Time.get_ticks_msec() / 1000.0)
	if nome == "cambaleando_perto":
		lek._tranco(&"dano_forte", 0.0, 0.08)
	var pegou := false
	var tiros := 0
	var t0 := 0.0
	while t0 < 6.0:
		await get_tree().create_timer(0.1).timeout
		t0 += 0.1
		if nome.ends_with("atirando") and int(t0 * 10) % 3 == 0:
			lek.take_damage(1)
			tiros += 1
		if GlobalEvents.agarrao_rodando:
			pegou = true
			break
	_total += 1
	if pegou: _ok += 1
	print("CASO ", nome, " pegou=", pegou, " t=", snappedf(t0, 0.1), " estado=", lek.get("_estado"), " dist=", snappedf(lek._dist_h(p.global_position), 0.01), " tiros=", tiros)
