extends "res://scripts/stages/inferno_3/inferno_3.gd"

## O INFERNO 4 — O MORRO DO MIRANTE.
##
## Modelo de `tools/blender/inferno_4/gerar_inferno_4.py`, cena de
## `tools/godot/inferno_4/gerar_cena_inferno_4.py`: luz, prop e navmesh mexidos
## no editor somem na próxima regeração. Este script é só comportamento.
##
## A porta da catedral do inferno 3 traz o Maycow NORMAL à mesma cidade escura;
## o caminho sobe um morro e desce do outro lado. Tudo o que o inferno 3 faz
## continua (lanterna no altar, sino, sussurros, névoa que respira). O que é
## daqui:
##
##  - a NÉVOA ABRE no fim da subida: no topo ela fica rala e cor de brasa, o
##    vórtice do céu acende em cima da catedral colossal e o drone sobe — é o
##    que deixa ver o GRANDE INFERNO lá embaixo. Descendo, ela fecha um pouco
##    de novo (o largo do fim precisa de vista para a luta);
##  - a CUTSCENE DO MIRANTE, uma vez por visita, ao pisar no patamar do topo
##    (ver `cutscene_mirante.gd`);
##  - o BANDO de gárgulas que voa sobre a cratera, além das do céu da base;
##  - os gigantes de sombra da vista olham pro mirante.
##
## O anel do largo do fim é a SAÍDA, mas ainda não leva a lugar nenhum
## (`cena_saida` vazia). O espaço em volta do selo é o do mini chefe: o
## marcador `boss/mini_boss` fica no centro, com o raio livre na metadata.

const CutsceneMirante := preload("res://scripts/stages/inferno_4/cutscene_mirante.gd")

@export_group("Névoa do mirante")
## z (mundo) onde a névoa começa a abrir, onde fica toda aberta (o topo), onde
## começa a fechar de novo (a descida) e onde para (o largo do fim). O caminho
## anda sempre pro -z.
@export var nevoa_z: Vector4 = Vector4(-30.0, -102.0, -160.0, -280.0)
@export var topo_densidade: float = 0.0022
## A névoa do topo é cor de BRASA, e o horizonte do céu também: é contra esse
## brilho que as torres e mesas da vista viram silhueta. Com a névoa escura do
## resto do mapa tudo lá embaixo era preto no preto.
@export var topo_cor: Color = Color(0.16, 0.066, 0.046)
@export var topo_horizonte: Color = Color(0.17, 0.05, 0.038)
@export var topo_borda_nuvem: Color = Color(0.42, 0.12, 0.07)
@export var topo_brilho_baixo: float = 0.55
@export var topo_ceu: float = 0.3
@export var topo_baixa: float = 0.035
@export var fosso_densidade: float = 0.009
@export var fosso_cor: Color = Color(0.08, 0.058, 0.062)
@export var fosso_ceu: float = 0.42
@export var fosso_baixa: float = 0.07
@export var vortice_forca: float = 0.9
## Volume do drone com a vista toda aberta.
@export var drone_volume: float = -8.0

@export_group("Bando da cratera")
@export var bando_vista: int = 8
@export var bando_centro: Vector3 = Vector3.ZERO
@export var bando_raio: float = 560.0

var _cor_base: Color
var _horizonte_base: Color
var _borda_base: Color
var _ceu_base: float = 0.62
var _baixa_base: float = 0.12
var _drone: AudioStreamPlayer
## Quanto a vista está aberta (0 na subida, 1 no topo): a cutscene lê.
var abertura: float = 0.0
var _mirante_visto: bool = false
## Capítulo 1: o portal do fim não leva a lugar nenhum (o Maycow ainda é fraco
## demais pra ir além) e o aviso disso sai uma vez, chegando perto dele.
var _fim_trancado := false
var _avisou_do_fim := false
## A que distância (no chão) do portal do fim o aviso aparece.
const PERTO_DO_FIM := 16.0


func _preparar() -> void:
	super._preparar()
	if _ambiente:
		_cor_base = _ambiente.fog_light_color
		_ceu_base = _ambiente.fog_sky_affect
		_baixa_base = _ambiente.fog_height_density
	if _ceu_material:
		_horizonte_base = _ceu_material.get_shader_parameter("cor_horizonte")
		_borda_base = _ceu_material.get_shader_parameter("cor_borda_nuvem")
	_drone = get_node_or_null("drone_vista") as AudioStreamPlayer
	_soltar_bando_da_cratera()
	var gatilho := get_node_or_null("gatilho_mirante") as Area3D
	if gatilho:
		gatilho.body_entered.connect(_ao_pisar_no_mirante)
	_regras_da_historia()


## O portal do COMEÇO é a volta pra red valve do porão: pergunta antes de
## levar (não suga quem só passou perto). O do FIM, no Capítulo 1, não suga
## ninguém — é o limite do que o Maycow aguenta (ver `Eventos`).
func _regras_da_historia() -> void:
	if _portal_entrada:
		_portal_entrada.com_prompt = true
	if Eventos.capitulo_atual() == Eventos.CAPITULO_1 and _portal_saida:
		_portal_saida.bloqueado = true
		_fim_trancado = true
		_avisou_do_fim = Eventos.feito(Eventos.CAP1_INFERNO_4_LIMITE)
		GlobalUtils.mostrar_objetivo(tr("OBJ_CAP1_INFERNO_4_VOLTAR" if _avisou_do_fim
			else "OBJ_CAP1_INFERNO_4_SEGUIR"), 40.0)


func _passo(delta: float) -> void:
	super._passo(delta)
	if not _fim_trancado or _avisou_do_fim or GlobalEvents.in_cutscene:
		return
	var jogador := get_node_or_null("Player") as Node3D
	if jogador == null or not is_instance_valid(_portal_saida):
		return
	var d := Vector2(jogador.global_position.x - _portal_saida.global_position.x,
		jogador.global_position.z - _portal_saida.global_position.z).length()
	if d < PERTO_DO_FIM:
		_avisou_do_fim = true
		GlobalUtils.show_center_message("inferno_4_limite", tr("AVISO_INFERNO_4_FRACO"), 20, 6.0)
		GlobalUtils.shake_camera(0.6, 0.2)
		Eventos.concluir(Eventos.CAP1_INFERNO_4_LIMITE)
		GlobalUtils.mostrar_objetivo(tr("OBJ_CAP1_INFERNO_4_VOLTAR"), 60.0)


## Os gigantes da vista olham pro mirante, não pro meio do mapa.
func _giro_sombra(p: Vector3) -> float:
	var m := get_node_or_null("mirante") as Node3D
	if m == null:
		return super._giro_sombra(p)
	return atan2(m.global_position.x - p.x, m.global_position.z - p.z)


# ==============================================================================
# A NÉVOA QUE ABRE NO TOPO
# ==============================================================================
## Substitui a respiração do inferno 3: a base dela agora depende de onde o
## jogador está (a respiração continua por cima).
func _passo_nevoa() -> void:
	if _ambiente == null:
		return
	var jogador := get_node_or_null("Player") as Node3D
	var z := jogador.global_position.z if jogador else nevoa_z.x + 1.0
	var abre := _entre(z, nevoa_z.x, nevoa_z.y)
	var fecha := _entre(z, nevoa_z.z, nevoa_z.w)
	abertura = abre * (1.0 - fecha * 0.5)
	var f := sin(_tempo * TAU / nevoa_periodo) * 0.7 + sin(_tempo * TAU / (nevoa_periodo * 0.37) + 1.3) * 0.3
	var densidade := lerpf(lerpf(_nevoa_base, topo_densidade, abre), fosso_densidade, fecha)
	_ambiente.fog_density = densidade * (1.0 + nevoa_respira * f)
	_ambiente.fog_light_color = _cor_base.lerp(topo_cor, abre).lerp(fosso_cor, fecha)
	_ambiente.fog_sky_affect = lerpf(lerpf(_ceu_base, topo_ceu, abre), fosso_ceu, fecha)
	_ambiente.fog_height_density = lerpf(lerpf(_baixa_base, topo_baixa, abre), fosso_baixa, fecha)
	if _ceu_material:
		_ceu_material.set_shader_parameter("vortice_forca", vortice_forca * abre)
		var brasa := abre * (1.0 - fecha * 0.4)
		_ceu_material.set_shader_parameter("cor_horizonte", _horizonte_base.lerp(topo_horizonte, brasa))
		_ceu_material.set_shader_parameter("cor_borda_nuvem", _borda_base.lerp(topo_borda_nuvem, brasa))
		_ceu_material.set_shader_parameter("brilho_baixo", topo_brilho_baixo * brasa)
	if _drone:
		_drone.volume_db = lerpf(-40.0, drone_volume, sqrt(abre))


## 0 antes de `de`, 1 depois de `ate`, suave no meio (o z diminui andando).
static func _entre(z: float, de: float, ate: float) -> float:
	var t := clampf((z - de) / (ate - de), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ==============================================================================
# O BANDO DA CRATERA
# ==============================================================================
## As gárgulas do céu da base seguem a câmera (estão sempre na tomada). Estas
## voam LÁ FORA, sobre a vista, maiores (de longe uma gárgula de 2 m vira um
## ponto), e passam também abaixo do topo, contra a névoa da cratera.
func _soltar_bando_da_cratera() -> void:
	var ninho := get_node_or_null("gargulas")
	if ninho == null or bando_vista <= 0:
		return
	for i in bando_vista:
		var g = GARGULA.instantiate()
		g.body_scale = randf_range(2.8, 4.4)
		g.flight_speed = randf_range(14.0, 24.0)
		g.roam_follow_camera = false
		ninho.add_child(g)
		g.setup_roam(Vector3(bando_centro.x, 0.0, bando_centro.z), bando_raio,
			bando_centro.y - 20.0, bando_centro.y + 140.0)
		for luz in g.find_children("*", "OmniLight3D", true, false):
			luz.visible = false


# ==============================================================================
# A CUTSCENE DO MIRANTE
# ==============================================================================
func _ao_pisar_no_mirante(corpo: Node3D) -> void:
	if _mirante_visto or not _eh_player(corpo) or GlobalEvents.in_cutscene:
		return
	if not (corpo is CharacterBody3D):
		return
	_mirante_visto = true
	var cena := CutsceneMirante.new()
	cena.name = "cutscene_mirante"
	add_child(cena)
	cena.rodar(self, corpo as CharacterBody3D)
