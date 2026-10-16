@tool
extends Node3D

signal recarga_evento(evento: String)

## PRIMEIRA PESSOA. A cena e a fonte de verdade: nao instancia armas escondidas,
## nao muda enquadramento em codigo. Edite Armas, as pegadas e o AnimationPlayer.
## Os controles usam metros e eixos de camera (-Z para frente, +Y para cima).
## O rig importado fica isolado em Malhas; so este adaptador converte seus ossos.

@export_group("Previa no editor")
@export var arma_previa := "shotgun":
	set(valor):
		arma_previa = valor
		if is_inside_tree() and Engine.is_editor_hint():
			_prever()
@export_enum("idle", "tiro", "recarga", "guardar", "sacar") var acao_previa := "idle":
	set(valor):
		acao_previa = valor
		if is_inside_tree() and Engine.is_editor_hint():
			_prever()
@export_range(0.0, 1.0, 0.001) var instante_previa := 0.0:
	set(valor):
		instante_previa = valor
		if is_inside_tree() and Engine.is_editor_hint():
			_prever()

## Anime de 1 (mao na telha da shotgun) a 0 (mao livre para recarregar).
@export_range(0.0, 1.0) var apoio_esquerdo := 1.0
@export_range(0.0, 1.0) var pressao_gatilho := 0.0
@export_group("Entrada dos antebracos (metros)")
@export var cotovelo_direito := Vector3(0.30, -0.55, 0.12)
@export var cotovelo_esquerdo := Vector3(-0.32, -0.55, 0.12)

var _animador: AnimationPlayer
var _dir: Skeleton3D
var _esq: Skeleton3D
var _armas := {}
var _na_mao := ""
var _trocando := false
var _recarregando := false
var _player: Node
var _mao_magica: Node3D
var _malha_magica: MeshInstance3D
var _peso_magia := 0.0
var _geracao_troca := 0
var _modo_previa := false

func _ready() -> void:
	process_priority = 10 # Depois do AnimationPlayer e do movimento do jogador.
	_animador = get_node_or_null("AnimationPlayer")
	_animador.animation_finished.connect(_ao_terminar_clipe)
	_dir = get_node_or_null("Malhas/Armature_dir/Skeleton3D")
	_esq = get_node_or_null("Malhas/Armature/Skeleton3D")
	for arma in $Armas.get_children():
		if "item_id" in arma:
			_armas[arma.item_id] = arma
	if Engine.is_editor_hint():
		notify_property_list_changed()
		_prever()
		return
	var camera := get_parent().get_parent()
	_modo_previa = not camera is Camera3D
	if _modo_previa:
		_prever()
		var olho := get_parent().get_node_or_null("PreviaDaTela") as Camera3D
		if olho != null:
			olho.make_current()
			var ambiente := Environment.new()
			ambiente.background_mode = Environment.BG_COLOR
			ambiente.background_color = Color(0.10,0.12,0.15)
			ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			ambiente.ambient_light_energy = 0.8
			olho.environment = ambiente
			var luz := DirectionalLight3D.new()
			luz.rotation_degrees = Vector3(-35,-35,0)
			luz.light_energy = 1.5
			get_parent().add_child.call_deferred(luz)
		return
	if camera != null:
		_player = camera.get_parent()
		_mao_magica = camera.get_node_or_null("hand_with_magic")
		if _mao_magica != null:
			_malha_magica = _mao_magica.get_node_or_null("hand_magic/Armature/Skeleton3D/mao_esq")
	# A camera de autoria tem a mesma origem da camera real, sem inversoes.
	var previa := get_parent().get_node_or_null("PreviaDaTela") as Camera3D
	if previa != null:
		previa.current = false
	_mostrar_arma("")

func _process(delta: float) -> void:
	if _animador == null or _dir == null:
		return
	if Engine.is_editor_hint():
		# Tambem reconhece a animacao escolhida no painel Animation.
		for item in _armas:
			if String(_animador.assigned_animation).begins_with(_armas[item].prefixo + "_"):
				_na_mao = item
				break
	else:
		var quer := arma_previa if _modo_previa else _arma_equipada()
		if quer != _na_mao and not _trocando:
			_trocar_para(quer)
		if not _trocando and not _animador.is_playing() and _na_mao != "":
			_recarregando = false
			_animador.play(_clipe(_na_mao, "idle"), 0.10)
		_atualizar_mao_magica(delta)
	_atualizar_pose()

func _prever() -> void:
	if _animador == null or not _armas.has(arma_previa):
		return
	_na_mao = arma_previa
	var nome := _clipe(arma_previa, acao_previa)
	if _animador.has_animation(nome):
		_animador.play(nome)
		_animador.seek(_animador.get_animation(nome).length * instante_previa, true)
		_animador.pause()
	_mostrar_arma(arma_previa)
	_atualizar_pose()

func _arma_equipada() -> String:
	for item in _armas:
		if SaveManager.is_equipped(item):
			return item
	return ""

func _clipe(item: String, acao: String) -> String:
	return _armas[item].prefixo + "_" + acao

func _mostrar_arma(item: String) -> void:
	for chave in _armas:
		_armas[chave].visible = chave == item
	for caminho in ["Malhas/Armature/Skeleton3D/mao_esq", "Malhas/Armature_dir/Skeleton3D/mao_dir"]:
		var malha := get_node_or_null(caminho) as MeshInstance3D
		if malha != null:
			malha.visible = item != ""

func _trocar_para(nova: String) -> void:
	_trocando = true
	if _recarregando:
		_recarregando = false
		recarga_evento.emit("cancelada")
	_geracao_troca += 1
	var geracao := _geracao_troca
	if _na_mao != "" and _animador.has_animation(_clipe(_na_mao, "guardar")):
		_animador.play(_clipe(_na_mao, "guardar"), 0.06)
		await get_tree().create_timer(_animador.current_animation_length).timeout
	if geracao != _geracao_troca or not is_inside_tree():
		return
	_na_mao = nova
	_mostrar_arma(nova)
	if nova != "" and _animador.has_animation(_clipe(nova, "sacar")):
		_animador.play(_clipe(nova, "sacar"))
		await get_tree().create_timer(_animador.current_animation_length).timeout
	_trocando = false

func _atualizar_pose() -> void:
	if not _armas.has(_na_mao) or _esq == null:
		return
	var arma: Node3D = _armas[_na_mao]
	var direita: Node3D = arma.get_node("Movimento/PegadaDireita")
	var esquerda: Node3D = $AjusteEsquerdo/ControleEsquerdo
	var alvo_esq := esquerda.global_transform
	var dedos_esq: Dictionary = esquerda.dedos()
	var aberturas_esq: Dictionary = esquerda.aberturas()
	var torcao_esq: float = esquerda.torcao_antebraco
	if arma.usa_apoio:
		var apoio: Node3D = arma.get_node("Movimento/Articulacao/ApoioEsquerdo")
		alvo_esq = alvo_esq.interpolate_with(apoio.global_transform, apoio_esquerdo)
		torcao_esq = lerpf(torcao_esq, apoio.torcao_antebraco, apoio_esquerdo)
		for dedo in dedos_esq:
			dedos_esq[dedo] = (dedos_esq[dedo] as Vector3).lerp(apoio.dedos()[dedo], apoio_esquerdo)
			aberturas_esq[dedo] = lerpf(aberturas_esq[dedo], apoio.aberturas()[dedo], apoio_esquerdo)
	var dedos_dir: Dictionary = direita.dedos()
	dedos_dir["indicador"] += Vector3(10,10,5) * pressao_gatilho
	_aplicar_mao(_dir, direita.global_transform, dedos_dir, direita.aberturas(), cotovelo_direito, true)
	_aplicar_mao(_esq, alvo_esq, dedos_esq, aberturas_esq, cotovelo_esquerdo, false, torcao_esq)
	for nome in ["fire", "faisca"]:
		var efeito := get_parent().get_node_or_null(nome) as Node3D
		if efeito != null:
			efeito.global_position = boca_do_cano()
	if not Engine.is_editor_hint() and _peso_magia > 0.0:
		_copiar_gesto_magico()

## Converte um controle do pulso em pose do rig; sem escalar os ossos.
func _aplicar_mao(sk: Skeleton3D, alvo: Transform3D, dedos: Dictionary,
		aberturas: Dictionary, cotovelo: Vector3, direita: bool, torcao := 0.0) -> void:
	var local := sk.global_transform.affine_inverse() * alvo
	var y := -local.basis.z.normalized()
	var z := local.basis.y.normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	var pulso := Transform3D(Basis(x, y, z), local.origin)
	_assentar_pulso(sk, pulso, cotovelo, torcao)
	for dedo in dedos:
		var dobras: Vector3 = dedos[dedo] * (PI / 180.0)
		for f in 3:
			var i := sk.find_bone("%s_%d" % [dedo, f + 1])
			if i < 0:
				continue
			var lateral: float = deg_to_rad(aberturas[dedo]) if f == 0 else 0.0
			if direita:
				lateral = -lateral
			var rest := sk.get_bone_rest(i)
			# O descanso importado traz os dedos abertos com desvios alternados
			# entre as falanges. Dobrar sobre esses desvios produz dedos em zigue-zague.
			# Cada cadeia usa agora seu eixo longitudinal; o polegar preserva a oposicao.
			if dedo != "polegar":
				rest.basis = Basis.IDENTITY
			_pose(sk, i, rest * Transform3D(Basis.from_euler(Vector3(dobras[f], 0, lateral)), Vector3.ZERO))

func _assentar_pulso(sk: Skeleton3D, pulso: Transform3D, cotovelo: Vector3, torcao := 0.0) -> void:
	var z := pulso.basis.z
	var origem := sk.to_local(to_global(cotovelo))
	var direcao := (pulso.origin - origem).normalized()
	z = z.rotated(direcao, deg_to_rad(torcao))
	var comprimento := sk.get_bone_rest(1).origin.length()
	var ante := Transform3D(_base(direcao, z), pulso.origin - direcao * comprimento)
	_pose(sk, 0, ante)
	_pose(sk, 1, ante.affine_inverse() * pulso)

func _base(y: Vector3, z: Vector3) -> Basis:
	var x := y.cross(z).normalized()
	return Basis(x, y, x.cross(y).normalized())

func _pose(sk: Skeleton3D, i: int, t: Transform3D) -> void:
	sk.set_bone_pose_position(i, t.origin)
	sk.set_bone_pose_rotation(i, t.basis.orthonormalized().get_rotation_quaternion())
	sk.set_bone_pose_scale(i, Vector3.ONE)

## A logica da cogblade continua com seus nos originais. Enquanto ela age,
## esta mao larga o apoio, acompanha o gesto existente e depois volta suavemente.
func _atualizar_mao_magica(delta: float) -> void:
	var armado := _na_mao != ""
	if _malha_magica != null:
		_malha_magica.visible = not armado
	var usando := false
	if is_instance_valid(_player):
		usando = _player.is_magic_attacking or _player.cogblade_melee_active or _player.is_using_ultimate
	_peso_magia = move_toward(_peso_magia, 1.0 if usando and armado else 0.0, delta / 0.16)

func _copiar_gesto_magico() -> void:
	if _mao_magica == null:
		return
	var fonte := _mao_magica.get_node_or_null("hand_magic/Armature/Skeleton3D") as Skeleton3D
	if fonte == null:
		return
	var peso := smoothstep(0.0, 1.0, _peso_magia)
	var outro := _esq.global_transform.affine_inverse() * fonte.global_transform * fonte.get_bone_global_pose(1)
	outro.basis = outro.basis.orthonormalized()
	var pulso := _esq.get_bone_global_pose(1).interpolate_with(outro, peso)
	# Retorno em arco por baixo da arma, em vez de cortar a telha com a palma.
	pulso.origin += _esq.global_basis.inverse() * global_basis * Vector3(-0.045, -0.065, 0.02) * sin(peso * PI)
	_assentar_pulso(_esq, pulso, cotovelo_esquerdo)
	# Interpolar POSICOES globais de cada falange encurta os dedos no meio
	# da transicao. So as rotacoes locais mudam; os comprimentos ficam rigidos.
	for i in range(2, 17):
		var rot := _esq.get_bone_pose_rotation(i).slerp(fonte.get_bone_pose_rotation(i), peso)
		_esq.set_bone_pose_rotation(i, rot)

func tem_arma_na_mao() -> bool:
	return _armas.has(_na_mao) and _armas[_na_mao].visible

func arma_na_mao() -> String:
	return _na_mao

func em_troca() -> bool:
	return _trocando

func atirar() -> void:
	if not tem_arma_na_mao() or _trocando or _recarregando:
		return
	_animador.play(_clipe(_na_mao, "tiro"), 0.025)
	if _na_mao == "pistol":
		get_parent().get_node("fire").play("shoot")
		var faisca := get_parent().get_node("faisca") as GPUParticles3D
		faisca.restart()
		faisca.emitting = true
	elif _modo_previa:
		var fx = load("res://scenes/effects/fogo_shotgun.tscn").instantiate()
		fx.arma = self
		get_tree().current_scene.add_child(fx)

func recarregar(tempo: float, quantidade: int = 2) -> bool:
	if not tem_arma_na_mao() or _trocando or _recarregando:
		return false
	var nome := _clipe(_na_mao, "recarga")
	if _na_mao == "shotgun" and quantidade == 1 and _animador.has_animation(nome + "_uma"):
		nome += "_uma"
	if not _animador.has_animation(nome):
		return false
	_recarregando = true
	_animador.play(nome, 0.06, _animador.get_animation(nome).length / maxf(tempo, 0.2))
	return true

## Chaves de metodo dos clipes: mover a chave move junto o som e a municao.
func evento_recarga(evento: String) -> void:
	if not Engine.is_editor_hint() and _recarregando:
		recarga_evento.emit(evento)

func _ao_terminar_clipe(nome: StringName) -> void:
	if _recarregando and "recarga" in String(nome):
		_recarregando = false
		recarga_evento.emit("fim")

func duracao_recarga() -> float:
	return _animador.get_animation(_clipe(_na_mao, "recarga")).length if tem_arma_na_mao() else 0.0

func mirar(_quer: bool, _alvo: Vector3 = Vector3.ZERO) -> void:
	pass

func boca_do_cano() -> Vector3:
	return _armas[_na_mao].ponto("BocaDoCano") if tem_arma_na_mao() else global_position

func ponto_do_cabo() -> Vector3:
	return _armas[_na_mao].ponto("Cabo") if tem_arma_na_mao() else global_position

func ponto_de_ejecao() -> Vector3:
	return _armas[_na_mao].ponto("Ejecao") if tem_arma_na_mao() else global_position

func direcao_do_cano() -> Vector3:
	var b := _armas[_na_mao].find_child("BocaDoCano", true, false) as Node3D if tem_arma_na_mao() else null
	return -b.global_basis.z.normalized() if b != null else -global_basis.z

func bocas_das_camaras() -> Array:
	if _na_mao != "shotgun":
		return []
	return [_armas[_na_mao].ponto("Camara1"), _armas[_na_mao].ponto("Camara2")]

## F6 nesta cena: F1 pistola, F2 shotgun, R recarga e clique esquerdo tiro.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _modo_previa:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: arma_previa = "pistol"
			KEY_F2: arma_previa = "shotgun"
			KEY_R:
				if tem_arma_na_mao(): recarregar(duracao_recarga())
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		atirar()

## A lista de previa acompanha as armas da cena; adicionar outra nao exige ifs.
func _validate_property(propriedade: Dictionary) -> void:
	if propriedade.name != "arma_previa": return
	var grupo := get_node_or_null("Armas")
	if grupo == null: return
	var ids := PackedStringArray()
	for arma in grupo.get_children():
		if "item_id" in arma: ids.append(arma.item_id)
	propriedade.hint = PROPERTY_HINT_ENUM
	propriedade.hint_string = ",".join(ids)
