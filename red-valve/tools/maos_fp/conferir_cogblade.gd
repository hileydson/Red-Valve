extends Node

## Bancada sem fase e sem gravar saves: pegadas, clipes, dano e estamina.
## Godot --headless --path red-valve res://tools/maos_fp/conferir_cogblade.tscn
var falhas := 0
var rig: Node3D
var ap: AnimationPlayer
var combate: Node
var jogador: JogadorDeProva

class JogadorDeProva extends CharacterBody3D:
	var camera: Camera3D
	var is_magic_attacking := false
	var is_blade_returning := false
	var is_using_ultimate := false
	var cogblade_menu_open := false
	var cogblade_melee_active := false
	var cogblade_blocking := false
	var transition_camera := false
	var is_exhausted := false
	var current_stamina := 100.0
	var stamina_fade_timer := 0.0
	var cogblade_attack_stamina := 10.0
	var cogblade_attack_duration := 0.90
	var cogblade_attack_cooldown_ms := 100
	var cogblade_attack_damage := 5
	var cogblade_attack_range := 3.2
	var cogblade_block_stamina_drain := 5.0
	var cogblade_block_hit_stamina := 15.0
	var cogblade_block_damage_reduction := 0.4
	var blade_in: AudioStreamPlayer3D
	var infinita := false
	func _stamina_infinita() -> bool: return infinita
	func are_cutscene_inputs_blocked() -> bool: return false

class CombateDeProva extends "res://scripts/player/player_cogblade_combat.gd":
	# A bancada avanca os clipes manualmente, sem tocar dezenas de sons no mesmo frame.
	func _play_blade_sound(_path: String, _pitch: float = 1.0, _volume_db: float = 0.0) -> void:
		pass

class AlvoDeProva extends Node3D:
	var impactos := 0
	func take_damage(_dano: int) -> void: impactos += 1

func _ok(condicao: bool, mensagem: String) -> void:
	if not condicao: falhas += 1
	print(("ok " if condicao else "FALHA ") + mensagem)

func _ready() -> void:
	GlobalEvents.is_maycow_normal = false
	SaveManager.inventory_combat = [{"id": "cogblade", "amount": 1}]
	SaveManager.cogblade_arma_ativa = true
	jogador = JogadorDeProva.new()
	add_child(jogador)
	jogador.camera = Camera3D.new()
	jogador.camera.name = "Camera3D"
	jogador.add_child(jogador.camera)
	jogador.camera.make_current()
	var mao: Node3D = load("res://scenes/player/first_person_view/mao_armada.tscn").instantiate()
	mao.name = "hand_with_pistol"
	jogador.camera.add_child(mao)
	mao.set_process(false)
	rig = mao.get_node("rig")
	rig.set_process(false)
	rig._na_mao = "cogblade"
	rig._mostrar_arma("cogblade")
	ap = rig.get_node("AnimationPlayer")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	combate = CombateDeProva.new()
	jogador.add_child(combate)
	combate.set_process(false)
	combate._process(0.0)
	var alvo := AlvoDeProva.new()
	alvo.position = Vector3(0, 0, -1.5)
	add_child(alvo)
	alvo.add_to_group("enemies")
	await get_tree().process_frame
	# As pegadas precisam continuar certas ao olhar para cima/baixo e girar.
	jogador.rotation_degrees.y = 63.0
	jogador.camera.rotation_degrees.x = -42.0
	var pior := 0.0
	var maior_flexao := 0.0
	var menor_separacao := INF
	for acao in ["idle", "sacar", "guardar", "ataque_1", "ataque_2", "ataque_3", "ataque_4", "defesa", "impacto_defesa"]:
		var clipe: String = "cogblade/cogblade_" + acao
		_ok(ap.has_animation(clipe), acao + " editavel no AnimationPlayer")
		var anim := ap.get_animation(clipe)
		for k in 41:
			ap.play(clipe)
			ap.seek(anim.length * float(k) / 40.0, true)
			rig._atualizar_pose()
			for par in [["Malhas/Armature_dir/Skeleton3D", "Movimento/PegadaDireita"], ["Malhas/Armature/Skeleton3D", "Movimento/Articulacao/ApoioEsquerdo"]]:
				var sk: Skeleton3D = rig.get_node(par[0])
				var pegada: Node3D = rig.get_node("Armas/Cogblade/" + par[1])
				var ante := sk.get_bone_global_pose(0).basis.y.normalized()
				var palma := sk.get_bone_global_pose(1).basis.y.normalized()
				maior_flexao = maxf(maior_flexao, rad_to_deg(ante.angle_to(palma)))
				pior = maxf(pior, (sk.global_transform * sk.get_bone_global_pose(1).origin).distance_to(pegada.global_position))
			var direita: Node3D = rig.get_node("Armas/Cogblade/Movimento/PegadaDireita")
			var esquerda: Node3D = rig.get_node("Armas/Cogblade/Movimento/Articulacao/ApoioEsquerdo")
			menor_separacao = minf(menor_separacao, direita.position.y - esquerda.position.y)
	_ok(maior_flexao < 28.0, "pulsos sem dobra extrema em todos os clipes (maximo %.1f graus)" % maior_flexao)
	_ok(menor_separacao >= 0.15, "direita guia a frente e esquerda apoia a base, com espaco entre as maos")
	_ok(pior < 0.0001, "ambos os pulsos presos ao cabo em 369 poses (erro %.6f m)" % pior)
	jogador.rotation = Vector3.ZERO
	jogador.camera.rotation = Vector3.ZERO
	ap.play("cogblade/cogblade_idle")
	ap.seek(0, true)
	var modelo: Node3D = rig.get_node("Armas/Cogblade/Movimento/Modelo")
	var fio := modelo.global_basis * Vector3.FORWARD
	_ok(fio.dot(-jogador.camera.global_basis.z) > 0.0, "fio orientado para a frente do jogador")
	seed(1701)
	var variantes := {}
	for i in 16:
		combate._ready_ms = 0
		jogador.current_stamina = 100.0
		var anterior: int = combate._ultimo_ataque
		var penultimo: int = combate._penultimo_ataque
		_ok(combate.executar_ataque(), "golpe %d inicia" % (i + 1))
		var idx: int = combate._ultimo_ataque
		variantes[idx] = true
		_ok(idx != anterior and idx != penultimo, "golpe evita os dois anteriores")
		_ok(is_equal_approx(jogador.current_stamina, 90.0), "custo unico de 10 de estamina")
		_ok(not combate.executar_ataque(), "sem sobrepor golpes")
		ap.advance(0.0)
		for frame in 100:
			ap.advance(0.01)
			rig._atualizar_pose()
			combate._atualizar_rastro(0.01)
		_ok(not jogador.cogblade_melee_active, "fim do clipe libera combate")
	_ok(variantes.size() == 4, "quatro variantes sorteadas")
	_ok(alvo.impactos == 16, "exatamente um impacto por golpe (%d)" % alvo.impactos)
	jogador.current_stamina = 100.0
	Input.action_press("ui_hold_first_person_view")
	combate._process(1.0)
	_ok(jogador.cogblade_blocking and is_equal_approx(jogador.current_stamina, 95.0), "defesa drena lentamente")
	_ok(combate.processar_dano_bloqueio(100) == 60, "defesa reduz dano em 40 por cento")
	_ok(is_equal_approx(jogador.current_stamina, 80.0), "impacto consome estamina adicional")
	jogador.current_stamina = 2.0
	combate._process(1.0)
	_ok(not jogador.cogblade_blocking and jogador.is_exhausted, "estamina vazia derruba a guarda")
	Input.action_release("ui_hold_first_person_view")
	jogador.current_stamina = 100.0
	jogador.is_exhausted = false
	Input.action_press("ui_hold_first_person_view")
	combate._process(0.0)
	jogador.is_magic_attacking = true
	combate._process(0.0)
	_ok(not jogador.cogblade_blocking and not jogador.cogblade_melee_active, "poder interrompe guarda e melee")
	_ok(combate.processar_dano_bloqueio(100) == 100, "sem defesa durante o poder")
	jogador.is_magic_attacking = false
	Input.action_release("ui_hold_first_person_view")
	SaveManager.cogblade_arma_ativa = false
	combate._process(0.0)
	_ok(not combate.executar_ataque(), "nao ataca sem equipar a cogblade")
	# Exercita tambem o processamento real, inclusive a troca com arma de fogo.
	SaveManager.inventory_combat.append({"id": "shotgun", "amount": 1})
	SaveManager.equipped_items = ["shotgun"]
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	rig.set_process(true)
	combate.set_process(true)
	await get_tree().create_timer(1.2).timeout
	_ok(rig.arma_na_mao() == "shotgun" and not rig.em_troca(), "troca para shotgun conclui")
	SaveManager.cogblade_arma_ativa = true
	await get_tree().create_timer(1.2).timeout
	_ok(rig.arma_na_mao() == "cogblade" and not rig.em_troca(), "saque da cogblade conclui")
	_ok(not rig.get_node("Armas/Shotgun").visible and rig.get_node("Armas/Cogblade").visible, "somente cogblade aparece ao equipar")
	jogador.current_stamina = 100.0
	combate._ready_ms = 0
	var impactos_antes := alvo.impactos
	_ok(combate.executar_ataque(), "golpe em processamento real inicia")
	await get_tree().create_timer(1.0).timeout
	_ok(not jogador.cogblade_melee_active and alvo.impactos == impactos_antes + 1, "golpe real aplica um impacto e retorna ao idle")
	jogador.is_magic_attacking = true
	await get_tree().create_timer(0.05).timeout
	_ok(not rig.get_node("Armas/Cogblade").visible, "poder assume o visual sem duplicar lamina")
	jogador.is_magic_attacking = false
	await get_tree().create_timer(0.05).timeout
	_ok(rig.get_node("Armas/Cogblade").visible, "empunhadura retorna depois do poder")
	combate._cancelar()
	jogador.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("COGBLADE: %d falhas" % falhas)
	get_tree().quit(1 if falhas else 0)
