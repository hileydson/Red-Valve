extends CharacterBody3D

## Jogador de mentira da bancada do Unknown Neighbor — NAO faz parte do jogo.
##
## Existe por um motivo so: conferir se da mesmo pra PULAR a onda do Coro. O
## alvo de antes era um corpo parado sem `take_damage`, entao o poder passava
## por ele sem dizer nada e nao havia como saber se o salto funcionava.
##
## Copia os numeros do jogador de verdade (`player.gd`): mesma JUMP_VELOCITY e
## a gravidade do projeto. Se o salto escapa aqui, escapa la.
##
##   ESPACO   pula
##   J        pula em laco, uma vez por segundo (pra pegar a onda sem contar
##            o tempo na mao)

const JUMP_VELOCITY := 4.5

var _laco: bool = false
var _relogio: float = 0.0
var _levou: int = 0
var _escapou: int = 0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
		if _laco:
			_relogio -= delta
			if _relogio <= 0.0:
				_relogio = 1.0
				velocity.y = JUMP_VELOCITY
	move_and_slide()


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match (evento as InputEventKey).keycode:
		KEY_SPACE:
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
		KEY_J:
			_laco = not _laco
			print("[teste_alvo] pulo em laco: ", _laco)


## O Coro chama isto quando a onda pega. Quem pulou na hora certa nunca ve esta
## funcao — e e' exatamente isso que o teste quer medir.
func take_damage(quanto) -> void:
	_levou += 1
	print("[teste_alvo] LEVOU %d de dano (altura=%.2f)  levou=%d escapou=%d"
		% [int(quanto), global_position.y, _levou, _escapou])


func apply_slow(_mult: float, _dur: float) -> void:
	pass


func clear_slow() -> void:
	pass
