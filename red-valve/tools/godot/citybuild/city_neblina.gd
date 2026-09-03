extends Node
## Névoa que fecha quando o jogador entra na mata.
##
## O renderizador Mobile não tem névoa volumétrica nem `FogVolume` — só a
## névoa de profundidade do Environment, que é global. Então em vez de
## colocar névoa "dentro do bosque", eu mudo a névoa do mundo conforme o
## jogador sai da mancha urbana: dentro da cidade fica a névoa quente de
## sempre; ao passar da última casa ela engrossa e desatura até fechar em
## uns 25 m de visibilidade.
##
## Sem `@tool` de propósito: mexer no Environment vivo dentro do editor
## sujaria o recurso salvo na cena.

## Retângulo da mancha construída, em coordenadas de mundo (X, Z).
## Sai de `extensao_construida()` do gerador, com a mesma folga de 26 m.
@export var caixa_min := Vector2(294.0, -436.5)
@export var caixa_max := Vector2(916.0, 4.0)
## Metros, a partir da borda, para a névoa fechar por completo.
@export var transicao: float = 50.0
## Segundos para a névoa acompanhar o jogador. Alto demais e ela "arrasta";
## baixo demais e pisca ao andar na borda.
@export var resposta: float = 1.2

@export_group("Cidade")
@export var densidade_cidade: float = 0.0012
@export var cor_cidade := Color(0.5775, 0.3917, 0.1621)
@export var energia_cidade: float = 1.0
@export var aerea_cidade: float = 0.35
@export var ceu_cidade: float = 0.4

@export_group("Mata")
## Densidade alta e cor QUASE PRETA. Névoa no Godot é aditiva: ela pinta a
## própria cor por cima do que está atrás. Com cinza médio e energia 1 ela
## clareia a cena em vez de esconder — foi o que aconteceu na primeira
## tentativa, a mata ficou mais fácil de ler, não mais difícil.
@export var densidade_mata: float = 0.048
@export var cor_mata := Color(0.055, 0.06, 0.062)
@export var energia_mata: float = 0.45
## Perspectiva aérea puxa a cor do CÉU para dentro da névoa. À noite o céu
## tem nuvem clara, então 0,9 acendia a mata inteira. Aqui tem de ser zero.
@export var aerea_mata: float = 0.0
@export var ceu_mata: float = 1.0

var _env: Environment = null
var _t: float = 0.0


func _ready() -> void:
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if _env == null:
		# find_world_3d().environment pega o WorldEnvironment ativo seja
		# quem for: não preciso de um NodePath que quebra se a cena mudar.
		var w := get_viewport().find_world_3d()
		if w == null:
			return
		_env = w.environment
		if _env == null:
			return

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position

	var dx: float = maxf(maxf(caixa_min.x - p.x, 0.0), p.x - caixa_max.x)
	var dz: float = maxf(maxf(caixa_min.y - p.z, 0.0), p.z - caixa_max.y)
	var alvo: float = clampf(sqrt(dx * dx + dz * dz) / maxf(transicao, 0.001), 0.0, 1.0)

	# suavização exponencial, independente do frame rate
	_t = lerpf(_t, alvo, 1.0 - exp(-delta / maxf(resposta, 0.01)))

	_env.fog_enabled = true
	_env.fog_density = lerpf(densidade_cidade, densidade_mata, _t)
	_env.fog_light_color = cor_cidade.lerp(cor_mata, _t)
	_env.fog_light_energy = lerpf(energia_cidade, energia_mata, _t)
	_env.fog_aerial_perspective = lerpf(aerea_cidade, aerea_mata, _t)
	_env.fog_sky_affect = lerpf(ceu_cidade, ceu_mata, _t)
