@tool
extends Marker3D

## Controle do PULSO em metros. -Z aponta para os dedos; +Y aponta para a palma.
## As tres componentes de cada dedo sao as dobras das falanges, em graus.
## Anime este no e estas propriedades no AnimationPlayer da mao_armada.
@export_group("Dedos (graus por falange)")
@export var indicador := Vector3(40, 48, 22)
@export var medio := Vector3(56, 34, 20)
@export var anelar := Vector3(57, 34, 20)
@export var mindinho := Vector3(58, 32, 18)
@export var polegar := Vector3(20, 20, 12)
@export_group("Abertura lateral (graus)")
@export var abertura := Vector3(6, 0, -3)
@export var abertura_mindinho := -7.0
@export var abertura_polegar := -17.0

func dedos() -> Dictionary:
	return {"indicador": indicador, "medio": medio, "anelar": anelar,
		"mindinho": mindinho, "polegar": polegar}

func aberturas() -> Dictionary:
	return {"indicador": abertura.x, "medio": abertura.y, "anelar": abertura.z,
		"mindinho": abertura_mindinho, "polegar": abertura_polegar}
