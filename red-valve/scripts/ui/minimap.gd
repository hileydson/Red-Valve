extends CanvasLayer
## Minimapa no canto superior esquerdo, girando com o player.
##
## Existe no stage_1 e no interior da igreja, e só aparece no gameplay com o
## Maycow normal. O mapa em tamanho grande é outra coisa: fica na aba MAPA do
## menu do jogo (scenes/ui/mapa_painel.tscn).
##
## A textura é assada a partir dos DADOS — da cidade em
## tools/blender/citygen/textures/make_minimap.py, da igreja em
## tools/godot/igreja/make_mapa_igreja.py — e não é um render da cena: fica
## legível a 190 px, não depende da hora do dia nem da iluminação, e regerar
## custa dois segundos. No caso da igreja tem um motivo a mais: é um interior
## com teto, e uma câmera de cima só veria a abóbada.
##
## O grupo "mapa_cidade" é como o menu descobre que esta fase tem mapa — e,
## desde o mapa do interior da igreja, também QUAL mapa. Este nó é o perfil de
## mapa da cena: o JSON, a textura e as faixas de zoom saem daqui, e a aba MAPA
## do menu pergunta a ele. Cena com mapa próprio é só instanciar uma variante
## desta cena lá dentro (ver `scenes/ui/minimap_igreja.tscn`).

## Dados do recorte e os pontos de interesse. A cena da cidade fica com o
## padrão; o interior da igreja aponta para o mapa dele.
@export_file("*.json") var dados_json: String = MapaDados.CAMINHO
## Textura do mapa. Vazio = a que já está no material da cena.
@export var textura_mapa: Texture2D = null

## Diâmetro, em metros de mundo, do que cabe dentro do círculo.
@export var alcance_m: float = 130.0
## Lado do minimapa em pixels.
@export var tamanho_px: float = 190.0
## Distância até o canto da tela.
@export var margem_px: Vector2 = Vector2(26.0, 26.0)
## Suavização do giro. 0 = acompanha na hora.
@export var suavidade: float = 12.0
## Mostrar os pontos de interesse também no minimapa (sem rótulo).
@export var pontos_no_minimapa: bool = true

@export_group("Prédio de dois andares")
## Planta do andar de cima. Vazio = esta cena tem um andar só, e nada disto
## roda. Preenchido, o mapa TROCA sozinho quando o jogador muda de andar.
##
## São duas plantas e não uma porque os dois andares do hospital são andares
## inteiros, 56 x 68 m um em cima do outro, com plantas diferentes —
## sobrepostos com hachura (o truque das galerias da igreja) viram rabisco.
@export_file("*.json") var dados_json_andar_2: String = ""
@export var textura_mapa_andar_2: Texture2D = null
## Altura de mundo a partir da qual o jogador está no andar de cima.
@export var altura_andar_2: float = 2.10

@export_group("Aba MAPA do menu")
## Altura da janela visível, em metros, nos extremos do zoom do painel grande.
## Ficam aqui, e não no painel, porque dependem do mapa: 80 m é zoom fechado
## numa cidade de 680 m e é a igreja inteira dentro da tela.
@export var zoom_min_m: float = 80.0
@export var zoom_max_m: float = 560.0
@export var zoom_inicial_m: float = 260.0
## Espaçamento da grade do painel, em metros.
@export var grade_m: float = 100.0

const COR_TIPO := {
	"marco": Color(0.55, 0.86, 0.70),
	"local": Color(0.95, 0.62, 0.30),
	"casa": Color(0.62, 0.80, 0.96),
	"sala": Color(0.80, 0.77, 0.64),
}
const COR_PADRAO := Color(0.85, 0.85, 0.85)
## Amarelo de interrogação: nenhum tipo de ponto usa esta cor, então "amarelo"
## passa a significar "tem coisa aqui e o jogo não vai dizer o quê".
const COR_INTERROGACAO := Color(1.0, 0.86, 0.25)

@onready var _raiz: Control = $Raiz
@onready var _mini: ColorRect = $Raiz/Mapa
@onready var _marcas: Control = $Raiz/Marcadores
@onready var _seta: Polygon2D = $Raiz/Seta

var _dados: MapaDados
var _mat: ShaderMaterial
var _player: Node3D = null
var _giro: float = 0.0
## Prancha em uso. Guardo a do térreo à parte porque `dados_json` e
## `textura_mapa` são REESCRITOS ao trocar de andar: é por eles que a aba MAPA
## do menu pergunta qual mapa esta cena está mostrando agora (ver
## `MapaDados.caminho_da_cena`), então eles têm de apontar para o andar atual.
var _json_terreo: String = ""
var _textura_terreo: Texture2D = null
var _no_andar_2: bool = false


func _ready() -> void:
	# PROCESS_MODE_ALWAYS: sem isto o `_process` para junto com a árvore
	# quando o jogo pausa, e o minimapa ficaria congelado por cima do menu em
	# vez de sumir.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dados = MapaDados.new(dados_json)
	if not _dados.ok:
		visible = false
		set_process(false)
		return
	# duplicate(): o ShaderMaterial é sub-recurso da cena base, e a variante da
	# igreja é uma INSTÂNCIA dela. Sem a cópia, trocar a textura aqui trocaria
	# também a do minimapa da cidade — as duas usariam o mesmo material.
	_mat = (_mini.material as ShaderMaterial).duplicate() as ShaderMaterial
	_mini.material = _mat
	if textura_mapa:
		_mat.set_shader_parameter("mapa", textura_mapa)
	_raiz.position = margem_px
	_raiz.size = Vector2(tamanho_px, tamanho_px)
	_mini.position = Vector2.ZERO
	_mini.size = _raiz.size
	_seta.position = _raiz.size * 0.5
	_mat.set_shader_parameter("raio_uv", (alcance_m * 0.5) / _dados.tam)
	_json_terreo = dados_json
	_textura_terreo = textura_mapa
	_criar_marcadores()
	visible = false


## Losango sem rótulo: nome escrito não cabe em 190 px. A exceção é a
## interrogação, que é um caractere só e cabe — e que, aliás, É o rótulo: o
## ponto existe justamente para não dizer o que tem lá.
func _criar_marcadores() -> void:
	if not pontos_no_minimapa:
		_marcas.visible = false
		return
	for p in _dados.pontos:
		var no := Control.new()
		no.mouse_filter = Control.MOUSE_FILTER_IGNORE
		no.set_meta("mundo", Vector2(float(p["x"]), float(p["z"])))
		no.set_meta("ponto", p)
		var tipo := String(p.get("tipo", ""))
		if tipo == "interrogacao":
			no.add_child(_interrogacao(20))
			_marcas.add_child(no)
			continue
		var cor: Color = COR_TIPO.get(tipo, COR_PADRAO)
		var losango := Polygon2D.new()
		losango.polygon = PackedVector2Array([
			Vector2(0, -3.5), Vector2(3.5, 0), Vector2(0, 3.5), Vector2(-3.5, 0)])
		losango.color = cor
		no.add_child(losango)
		var borda := Line2D.new()
		borda.points = PackedVector2Array([
			Vector2(0, -3.5), Vector2(3.5, 0), Vector2(0, 3.5),
			Vector2(-3.5, 0), Vector2(0, -3.5)])
		borda.width = 1.4
		borda.default_color = Color(0.05, 0.05, 0.05, 0.85)
		no.add_child(borda)
		_marcas.add_child(no)


## O "?" propriamente dito. Label e não Polygon2D: o contorno grosso é o que
## faz o caractere sobreviver por cima do piso claro da planta, e desenhar a
## curva do "?" à mão em polígono seria trabalho para um resultado pior.
##
## `position` negativo e não `anchors`: um Label solto dentro de um Control de
## tamanho zero não tem retângulo para se ancorar, então o jeito de centrá-lo
## no ponto é descontar metade do próprio tamanho.
static func _interrogacao(tamanho: int) -> Label:
	var lb := Label.new()
	lb.text = "?"
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_theme_font_size_override("font_size", tamanho)
	lb.add_theme_color_override("font_color", COR_INTERROGACAO)
	lb.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 1))
	lb.add_theme_constant_override("outline_size", max(4, tamanho / 3))
	lb.position = Vector2(-tamanho * 0.28, -tamanho * 0.78)
	return lb


func _process(delta: float) -> void:
	if get_tree().paused or not MapaDados.disponivel(get_tree()):
		visible = false
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			visible = false
			return

	var p := _player.global_position
	_ver_andar(p.y)
	var uv := _dados.uv(p.x, p.z)

	# -rotation.y, e não +. Um nó com rotation.y = θ olha para
	# (-sen θ, 0, -cos θ). Para essa direção cair em CIMA na tela, a matriz
	# que gira a amostragem tem de ser a inversa — ou seja, ângulo -θ.
	var alvo := -_player.global_rotation.y
	if suavidade > 0.0:
		_giro = lerp_angle(_giro, alvo, clampf(delta * suavidade, 0.0, 1.0))
	else:
		_giro = alvo

	_mat.set_shader_parameter("centro_uv", uv)
	_mat.set_shader_parameter("giro", _giro)
	_pos_marcas(uv)
	visible = true


## Em que andar o jogador está, e troca a prancha quando ele muda.
##
## Pela ALTURA e não por sinal do elevador: assim vale para qualquer forma de
## mudar de andar que venha a existir depois (escada, buraco no piso, queda), e
## um save carregado no andar de cima já abre com o mapa certo.
func _ver_andar(y: float) -> void:
	if dados_json_andar_2 == "":
		return
	var cima: bool = y >= altura_andar_2
	if cima == _no_andar_2:
		return
	_no_andar_2 = cima
	_trocar_prancha(
		dados_json_andar_2 if cima else _json_terreo,
		textura_mapa_andar_2 if cima else _textura_terreo)


func _trocar_prancha(caminho: String, textura: Texture2D) -> void:
	var novos := MapaDados.new(caminho)
	if not novos.ok:
		return
	_dados = novos
	# reescreve os exports: é por eles que a aba MAPA do menu descobre qual
	# prancha mostrar, e ela lê isto quando o jogador abre o menu
	dados_json = caminho
	if textura:
		textura_mapa = textura
		_mat.set_shader_parameter("mapa", textura)
	_mat.set_shader_parameter("raio_uv", (alcance_m * 0.5) / _dados.tam)
	# remove_child ANTES do queue_free: o queue_free só apaga no fim do quadro,
	# e até lá os marcadores do andar velho continuariam na lista que
	# `_pos_marcas` percorre — o mapa de cima abriria com os pontos de baixo.
	for velho in _marcas.get_children():
		_marcas.remove_child(velho)
		velho.queue_free()
	_criar_marcadores()


func _pos_marcas(centro: Vector2) -> void:
	if not pontos_no_minimapa:
		return
	var raio_uv: float = (alcance_m * 0.5) / _dados.tam
	var meio := _raiz.size * 0.5
	# inversa do shader: p = R(-giro) · (uv - centro) / raio
	var s := sin(-_giro)
	var c := cos(-_giro)
	for no in _marcas.get_children():
		# a cada quadro, e não uma vez só: a interrogação da lanterna some no
		# mesmo instante em que ela é pega, sem sair e voltar para a cena
		if not MapaDados.ponto_visivel(no.get_meta("ponto", {})):
			no.visible = false
			continue
		var m: Vector2 = no.get_meta("mundo")
		var d := (_dados.uv(m.x, m.y) - centro) / raio_uv
		var q := Vector2(d.x * c - d.y * s, d.x * s + d.y * c)
		if q.length() > 0.94:
			no.visible = false
			continue
		no.visible = true
		no.position = meio + q * meio
