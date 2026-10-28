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
## Deslocamento do indicador para a frente, em metros, sem alterar as falanges.
@export_range(0.0, 0.03, 0.001) var avanco_indicador := 0.0
@export_group("Abertura lateral (graus)")
@export var abertura := Vector3(6, 0, -3)
@export var abertura_mindinho := -7.0
@export var abertura_polegar := -17.0
## Rotacao do antebraco em relacao a palma: permite pronacao sem travar o pulso.
@export_range(-45.0, 45.0, 0.1) var torcao_antebraco := 0.0
## Mantem o antebraco na continuidade da palma. 0 usa a entrada do cotovelo;
## 1 deixa o pulso neutro. Util para empunhaduras de machado com duas maos.
@export_range(0.0, 1.0, 0.01) var alinhamento_antebraco := 0.0
## Limita a dobra entre a mao e o antebraco sem apagar a direcao do cotovelo.
## 180 preserva o comportamento antigo; empunhaduras longas usam um valor menor.
@export_range(0.0, 180.0, 0.1) var limite_flexao_pulso := 180.0

func dedos() -> Dictionary:
	return {"indicador": indicador, "medio": medio, "anelar": anelar,
		"mindinho": mindinho, "polegar": polegar}

func aberturas() -> Dictionary:
	return {"indicador": abertura.x, "medio": abertura.y, "anelar": abertura.z,
		"mindinho": abertura_mindinho, "polegar": abertura_polegar}
