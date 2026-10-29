extends "res://scripts/cutscenes/cutscene_cap1.gd"

## A CHEGADA NA ESCOLA (Capítulo 1): seis da tarde, fim de expediente.
##
## Só câmera passando pela escola acesa: professores e funcionários andando e
## conversando, os alunos já foram embora. Nenhuma fala — é o retrato do lugar
## ANTES do raio, pra o jogador saber o que vai perder.
##
## Os planos ficam onde o `capitulo_1_escola.gd` pôs os adultos (as mesmas
## coordenadas da planta da escola). Cada um anda um pouco, sem corte seco:
## a tela escurece rápido entre um e outro.

## [de, olhando, até, olhando, segundos]
const PLANOS := [
	# o pátio, do alto do canto do portão: a quadra, os bancos, gente conversando
	[Vector3(3.0, 6.5, 47.0), Vector3(16.0, 0.5, 30.0),
		Vector3(5.0, 5.2, 41.0), Vector3(14.0, 0.8, 24.0), 3.6],
	# o corredor norte, rasteiro, alguém vindo na direção da câmera
	[Vector3(62.0, 1.5, 12.5), Vector3(20.0, 1.4, 12.9),
		Vector3(55.0, 1.6, 12.8), Vector3(20.0, 1.5, 12.9), 3.2],
	# a secretaria: duas pessoas no fim do turno
	[Vector3(72.0, 2.1, 8.5), Vector3(65.5, 1.2, 6.0),
		Vector3(71.0, 1.9, 3.0), Vector3(65.5, 1.3, 6.0), 3.0],
	# o corredor sul, longo, até a última sala
	[Vector3(4.0, 2.2, 55.5), Vector3(60.0, 1.0, 54.5),
		Vector3(10.0, 2.0, 54.0), Vector3(60.0, 1.1, 54.5), 3.2],
]


func rodar(dono: Node3D, jogador: CharacterBody3D) -> void:
	travar(dono, jogador, 55.0)
	await escurecer(1.0, 0.35)
	for i in PLANOS.size():
		var p: Array = PLANOS[i]
		plantar(p[0], p[1])
		await escurecer(0.0, 0.45)
		if not vale():
			break
		var ate: float = p[4] - 0.8
		await plano(p[0], p[1], p[2], p[3], ate)
		if not vale():
			break
		await escurecer(1.0, 0.35)
	# de volta pro Maycow, na tela preta
	encerrar(1.0)
