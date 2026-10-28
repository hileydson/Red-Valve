extends Area3D

## A cabeca de um chefe da igreja: repassa o tiro pro corpo, um pouco mais
## forte. Sem a luz vermelha do `head.gd` dos inimigos comuns: a nave da
## igreja ja' esta' no teto de 8 omni por malha (ver cena_dona_nice.gd).

@export var multiplicador: float = 1.25


func take_damage(dano: int) -> void:
	var corpo := get_parent()
	if corpo and corpo.has_method("take_damage"):
		corpo.take_damage(int(round(dano * multiplicador)))
