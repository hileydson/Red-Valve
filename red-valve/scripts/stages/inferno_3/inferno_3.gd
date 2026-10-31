extends "res://scripts/stages/inferno/inferno.gd"

## O INFERNO 3 — A CIDADE DOS ENLUTADOS.
##
## Modelo de `tools/blender/inferno_3/gerar_inferno_3.py`, cena de
## `tools/godot/inferno_3/gerar_cena_inferno_3.py`: luz, prop e navmesh mexidos
## no editor somem na próxima regeração. Este script é só comportamento.
##
## O anel do fim do inferno 2 traz o jogador a uma cidade gótica de noite, na
## névoa, e quem anda aqui é o Maycow NORMAL — a cena liga `maycow_normal`.
## O escuro é feito para a lanterna:
##
##  - a LANTERNA está acesa num altar logo na chegada, para quem ainda não a
##    tem (o mesmo pickup da escola); quem já tem encontra o altar vazio;
##  - quem chega com ela apagada recebe uma dica curta de acendê-la;
##  - o SINO da catedral toca de tempos em tempos, de longe (três badaladas);
##  - a NÉVOA respira: a densidade sobe e desce devagar;
##  - SUSSURROS e um grito distante, raros;
##  - as sombras gigantes do abismo e o anel de volta vêm do inferno.gd.
##
## No Capítulo 4 (`Eventos.inferno_3_leva_a_arena`) a porta da catedral, o
## portal do fim, deixa de voltar pro porão: leva à ARENA 2 — e está selada até
## o Maycow pagar os iron rusks dela (`portal_selado.gd`).

const ITEM_LANTERNA := "lanterna"
const MODELO_LANTERNA := "res://assets/3d_model/player/lanterna/lanterna.glb"
const CENA_ITEM_OBTIDO := "res://scenes/ui/item_obtido.tscn"
const ItemSelecionavel := preload("res://scripts/stages/hospital/item_selecionavel.gd")
const DICA_ID := "inferno_3_lanterna"
const PortalSelado := preload("res://scripts/effects/portal_selado.gd")
const CENA_ARENA_2 := "res://scenes/stages/battlefield/battlefield_2.tscn"

@export_group("Sino")
@export var sino_espera_min: float = 40.0
@export var sino_espera_max: float = 95.0
@export var sino_badaladas: int = 3
@export var sino_intervalo: float = 2.6

@export_group("Névoa")
## Quanto a densidade sobe e desce em volta da base (fração).
@export var nevoa_respira: float = 0.18
@export var nevoa_periodo: float = 38.0

@export_group("Lanterna")
## A lanterna do player é afinada para corredor (escola, hospital). Na rua
## aberta o facho bate rasante a 7 m e some: aqui ela ganha força e alcance.
## Só nesta cena — o player é instanciado de novo em cada uma.
@export var lanterna_energia: float = 10.0
@export var lanterna_alcance: float = 24.0
@export var lanterna_angulo: float = 22.0
@export var halo_energia: float = 2.4
@export var halo_alcance: float = 13.0

@export_group("Sussurros")
@export var sussurro_espera_min: float = 30.0
@export var sussurro_espera_max: float = 80.0

var _sino: AudioStreamPlayer3D
var _sino_prazo: float = 12.0
var _ambiente: Environment
var _nevoa_base: float = 0.0
var _sussurro: AudioStreamPlayer
var _grito: AudioStreamPlayer
var _sussurro_prazo: float = 20.0
var _dica_prazo: float = 3.5


func _preparar() -> void:
	# antes do super: é ele que monta os portais a partir de `cena_saida`
	_ligacoes_da_historia()
	super._preparar()
	_historia_do_capitulo_4()
	_sino = get_node_or_null("sino") as AudioStreamPlayer3D
	_sino_prazo = randf_range(8.0, 20.0)
	var amb := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if amb:
		_ambiente = amb.environment
		_nevoa_base = _ambiente.fog_density
	_sussurro = get_node_or_null("sussurro") as AudioStreamPlayer
	_grito = get_node_or_null("grito") as AudioStreamPlayer
	_sussurro_prazo = randf_range(sussurro_espera_min * 0.5, sussurro_espera_max * 0.6)
	_preparar_lanterna()
	_reforcar_lanterna()


## Aqui não há mar de lava: nada de fogo ao longe.
func _ponto_erupcao(_cam: Camera3D) -> Vector3:
	return Vector3.INF


# ==============================================================================
# O CAPÍTULO 4
# ==============================================================================
## Pra onde as pontas levam nesta visita. O inferno 4 herda daqui e tem as
## dele (sobrescreve as duas funções abaixo).
func _ligacoes_da_historia() -> void:
	if Eventos.inferno_3_leva_a_arena():
		cena_saida = CENA_ARENA_2
		ponto_saida = ""


## A porta da catedral selada até pagar, e o que fazer agora.
func _historia_do_capitulo_4() -> void:
	if not Eventos.inferno_3_leva_a_arena():
		return
	if _portal_saida and not Eventos.feito(Eventos.CAP4_PORTAL_INFERNO_3):
		_selar(_portal_saida, Eventos.CAP4_PORTAL_INFERNO_3)
	var chave := Eventos.objetivo_atual()
	if chave != "":
		GlobalUtils.mostrar_objetivo(tr(chave), 40.0)


## Põe o selo de iron rusks no portal (`portal_selado.gd`).
func _selar(portal: Node3D, evento: String) -> void:
	var selo = PortalSelado.new()
	selo.name = "selo"
	selo.evento = evento
	portal.add_child(selo)


## As sombras ficam no abismo dos dois lados da cidade: olham pra ela.
func _giro_sombra(p: Vector3) -> float:
	return atan2(-p.x, 0.0)


func _passo(delta: float) -> void:
	super._passo(delta)
	_passo_sino(delta)
	_passo_nevoa()
	_passo_sussurros(delta)
	_passo_dica(delta)


# ==============================================================================
# A LANTERNA NO ALTAR
# ==============================================================================
## O mesmo evento da escola (`escola.gd`): quem já pegou a lanterna não a
## encontra de novo — a checagem é no inventário salvo.
func _preparar_lanterna() -> void:
	var conjunto := get_node_or_null("lanterna_no_chao")
	if conjunto == null:
		return
	if SaveManager.tem_item(ITEM_LANTERNA):
		conjunto.queue_free()
		return
	var selecao := ItemSelecionavel.new()
	conjunto.add_child(selecao)
	selecao.configurar(conjunto, conjunto.get_node_or_null("area") as Area3D,
		"PROMPT_TAKE_FLASHLIGHT")
	selecao.pegar.connect(_pegar_lanterna)


func _pegar_lanterna() -> void:
	SaveManager.add_item(ITEM_LANTERNA, 1)
	SaveManager.save_game()
	var conjunto := get_node_or_null("lanterna_no_chao")
	if conjunto:
		conjunto.queue_free()
	# o prompt some num tween que não anda com a árvore pausada: espera ele
	await get_tree().create_timer(0.55).timeout
	var chave := "PICKUP_FLASHLIGHT_L3" if GlobalEvents.usando_controle \
		else "PICKUP_FLASHLIGHT_KEY"
	var tela: CanvasLayer = load(CENA_ITEM_OBTIDO).instantiate()
	tela.model_path = MODELO_LANTERNA
	tela.texto = tr(chave)
	get_tree().root.add_child(tela)
	await tela.fechado
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador and jogador.has_method("acender_lanterna_agora"):
		jogador.acender_lanterna_agora()


func _reforcar_lanterna() -> void:
	var jogador := get_node_or_null("Player")
	if jogador == null:
		return
	var facho := jogador.get("lanterna") as SpotLight3D
	if facho:
		facho.light_energy = lanterna_energia
		facho.spot_range = lanterna_alcance
		facho.spot_angle = lanterna_angulo
	var halo := jogador.get("_lanterna_halo") as SpotLight3D
	if halo:
		halo.light_energy = halo_energia
		halo.spot_range = halo_alcance


## Quem chega com a lanterna apagada recebe UMA dica, alguns segundos depois
## de entrar. Sem lanterna no inventário quem fala é o altar.
func _passo_dica(delta: float) -> void:
	if _dica_prazo <= 0.0:
		return
	_dica_prazo -= delta
	if _dica_prazo > 0.0:
		return
	if not SaveManager.tem_item(ITEM_LANTERNA) or GlobalEvents.in_cutscene:
		return
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador == null or bool(jogador.get("lanterna_ligada")):
		return
	var chave := "HINT_DARK_FLASHLIGHT_L3" if GlobalEvents.usando_controle \
		else "HINT_DARK_FLASHLIGHT_KEY"
	GlobalUtils.show_center_message(DICA_ID, tr(chave), 18, 4.5)


# ==============================================================================
# O SINO, A NÉVOA E OS SUSSURROS
# ==============================================================================
func _passo_sino(delta: float) -> void:
	if _sino == null:
		return
	_sino_prazo -= delta
	if _sino_prazo > 0.0:
		return
	_sino_prazo = randf_range(sino_espera_min, sino_espera_max)
	_badalar()


func _badalar() -> void:
	for k in sino_badaladas:
		if not is_instance_valid(_sino):
			return
		_sino.pitch_scale = randf_range(0.9, 0.96)
		_sino.play()
		await get_tree().create_timer(sino_intervalo).timeout


func _passo_nevoa() -> void:
	if _ambiente == null or _nevoa_base <= 0.0:
		return
	var f := sin(_tempo * TAU / nevoa_periodo) * 0.7 + sin(_tempo * TAU / (nevoa_periodo * 0.37) + 1.3) * 0.3
	_ambiente.fog_density = _nevoa_base * (1.0 + nevoa_respira * f)


func _passo_sussurros(delta: float) -> void:
	_sussurro_prazo -= delta
	if _sussurro_prazo > 0.0:
		return
	_sussurro_prazo = randf_range(sussurro_espera_min, sussurro_espera_max)
	if _grito and randf() < 0.25:
		_grito.pitch_scale = randf_range(0.55, 0.75)
		_grito.play()
	elif _sussurro:
		_sussurro.pitch_scale = randf_range(0.85, 1.05)
		_sussurro.play()
