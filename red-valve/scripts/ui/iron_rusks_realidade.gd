extends Node2D

## O CONTADOR DE IRON RUSKS QUANDO A CIDADE ESTÁ COBRANDO (amuleto fora).
##
## Sem o amuleto cada 10 s custam 1 iron rusk (`realidade_do_amuleto.gd`), e o
## contador mostra isso: o número cresce, fica avermelhado, treme de leve e
## pinga sangue — gotas que se formam embaixo dos algarismos, esticam e caem,
## como as que voam pro medidor da cogblade (`player_combat.gd`). Cada gasto
## dá um soco no número, um clarão e um "-1" subindo, com um respingo.
##
## Mora dentro da camada do contador (`player_hud._setup_iron_rusks_hud`) e só
## mexe no `value_label` dela. No menu (o contador desce pro rodapé) o efeito
## fica parado, pra não brigar com a animação de lá.

const ESCALA_COBRANDO := 1.45
const COR_COBRANDO := Color(1.0, 0.42, 0.36)
const TREMOR_PX := 1.6
const COR_SANGUE := Color(0.72, 0.02, 0.02, 1.0)
const COR_HALO := Color(0.55, 0.0, 0.0, 0.35)
const GRAVIDADE := 900.0
## Uma gota nova a cada intervalo destes (s), sorteado.
const PINGO_A_CADA := Vector2(0.35, 0.9)

var value_label: Label
## A camada (o script dela diz se o menu está aberto: `is_in_menu`).
var camada: CanvasLayer

var _peso := 0.0          # 0 = normal, 1 = cobrando (suavizado)
var _soco := 0.0          # o pulo do gasto, decai sozinho
var _clarao := 0.0
var _desvio := Vector2.ZERO
var _proximo_pingo := 0.0
var _gotas: Array = []    # [{no, vel, pendurada, cresce}]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.iron_rusks_gastos.connect(_ao_gastar)


func _exit_tree() -> void:
	if SaveManager.iron_rusks_gastos.is_connected(_ao_gastar):
		SaveManager.iron_rusks_gastos.disconnect(_ao_gastar)


func _process(delta: float) -> void:
	if not is_instance_valid(value_label):
		return
	var no_menu: bool = camada != null and camada.get("is_in_menu") == true
	var cobrando := SaveManager.realidade_normal() and camada.visible and not no_menu
	_peso = move_toward(_peso, 1.0 if cobrando else 0.0, delta * 3.0)
	_soco = move_toward(_soco, 0.0, delta * 2.6)
	_clarao = move_toward(_clarao, 0.0, delta * 3.2)

	# tamanho: cresce pela DIREITA (o texto é alinhado à direita)
	value_label.pivot_offset = Vector2(value_label.size.x, value_label.size.y * 0.5)
	var s := lerpf(1.0, ESCALA_COBRANDO, _peso) + _soco * 0.7
	value_label.scale = Vector2(s, s)
	var cor := Color.WHITE.lerp(COR_COBRANDO, _peso)
	value_label.modulate = cor.lerp(Color(1.8, 1.6, 1.5), _clarao)

	# tremor: desfaz o do quadro anterior antes de pôr o novo, pra não
	# acumular e pra não brigar com quem mexe nos offsets (o menu)
	_mover(-_desvio)
	_desvio = Vector2.ZERO
	if not no_menu and (_peso > 0.01 or _soco > 0.01):
		var forca := TREMOR_PX * _peso + 5.0 * _soco
		_desvio = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
		_mover(_desvio)

	if cobrando:
		_proximo_pingo -= delta
		if _proximo_pingo <= 0.0:
			_proximo_pingo = randf_range(PINGO_A_CADA.x, PINGO_A_CADA.y)
			_nova_gota(true)
	_animar_gotas(delta)


func _mover(d: Vector2) -> void:
	value_label.offset_left += d.x
	value_label.offset_right += d.x
	value_label.offset_top += d.y
	value_label.offset_bottom += d.y


## Onde estão os algarismos agora, em coordenadas da camada: [x0, x1, y de baixo].
func _faixa_do_texto() -> Array:
	var fonte := value_label.get_theme_font("font")
	var tam := value_label.get_theme_font_size("font_size")
	var largura := fonte.get_string_size(value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var t := value_label.get_global_transform()
	var dir := t * Vector2(value_label.size.x, value_label.size.y * 0.78)
	var esq := t * Vector2(value_label.size.x - largura, value_label.size.y * 0.78)
	return [esq.x, dir.x, dir.y]


## Uma gota. `pendurada`: nasce colada embaixo do número, engorda e só então
## solta (o pingar); sem isso, é respingo do gasto, já voando.
func _nova_gota(pendurada: bool, vel := Vector2.ZERO) -> void:
	var faixa := _faixa_do_texto()
	var raio := randf_range(2.6, 4.4) if pendurada else randf_range(2.0, 3.6)
	var no := Node2D.new()
	no.position = Vector2(randf_range(faixa[0] + 4.0, faixa[1] - 4.0), faixa[2])
	var halo := Polygon2D.new()
	halo.polygon = _circulo(raio * 1.9)
	halo.color = COR_HALO
	no.add_child(halo)
	var gota := Polygon2D.new()
	gota.polygon = _circulo(raio)
	gota.color = COR_SANGUE
	no.add_child(gota)
	no.scale = Vector2(0.2, 0.2) if pendurada else Vector2.ONE
	add_child(no)
	_gotas.append({"no": no, "vel": vel, "pendurada": pendurada,
		"cresce": randf_range(0.35, 0.7), "vida": 0.0})


func _animar_gotas(delta: float) -> void:
	var altura := get_viewport_rect().size.y
	for g in _gotas.duplicate():
		var no: Node2D = g["no"]
		g["vida"] += delta
		if g["pendurada"]:
			# engorda presa ao número, esticando pra baixo
			var k := clampf(g["vida"] / g["cresce"], 0.0, 1.0)
			no.scale = Vector2(lerpf(0.2, 1.0, k), lerpf(0.2, 1.35, k))
			if k >= 1.0:
				g["pendurada"] = false
				g["vel"] = Vector2(0.0, randf_range(10.0, 40.0))
			continue
		g["vel"] += Vector2(0.0, GRAVIDADE * delta)
		no.position += g["vel"] * delta
		# estica na queda, como gota de verdade
		no.scale = Vector2(0.85, clampf(1.0 + g["vel"].y / 700.0, 1.0, 2.2))
		no.modulate.a = clampf(1.0 - (g["vida"] - 0.5) / 0.9, 0.0, 1.0)
		if no.modulate.a <= 0.0 or no.position.y > altura + 20.0:
			no.queue_free()
			_gotas.erase(g)


func _ao_gastar(qtd: int, _restam: int) -> void:
	if not is_instance_valid(value_label):
		return
	_soco = 1.0
	_clarao = 1.0
	# respingo: um punhado de gotas pulando dos algarismos
	for i in 7:
		_nova_gota(false, Vector2(randf_range(-160.0, 160.0), randf_range(-260.0, -90.0)))
	# o "-1" subindo e sumindo
	var faixa := _faixa_do_texto()
	var menos := Label.new()
	menos.text = "-%d" % qtd
	menos.add_theme_font_size_override("font_size", 30)
	menos.add_theme_color_override("font_color", Color(0.95, 0.12, 0.08))
	menos.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	menos.add_theme_constant_override("outline_size", 6)
	menos.position = Vector2(faixa[0] - 46.0, faixa[2] - 34.0)
	add_child(menos)
	var t := menos.create_tween().set_parallel(true)
	t.tween_property(menos, "position:y", menos.position.y - 46.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(menos, "modulate:a", 0.0, 0.9).set_delay(0.25)
	t.chain().tween_callback(menos.queue_free)


func _circulo(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
