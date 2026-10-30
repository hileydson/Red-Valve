extends Node

## OS EVENTOS DA HISTÓRIA — o que já aconteceu, e o que depende do quê.
##
## Autoload `Eventos`. Todo acontecimento que muda o que o jogo deixa fazer
## (um lugar que abre, uma cutscene que já passou, um chefe que morreu) mora no
## CATALOGO abaixo, com o capítulo dele e a lista do que precisa ter acontecido
## ANTES. Um evento só se conclui com as dependências cumpridas: é isso que
## impede, por exemplo, a escola de virar a versão escura sem o Maycow ter
## falado com ninguém lá dentro — e é o que um ajuste futuro tem de respeitar.
##
##     Eventos.feito(Eventos.CAP1_DIARIO_JIMMY)
##     Eventos.concluir(Eventos.CAP1_DIARIO_JIMMY)     # grava o save
##     Eventos.local_aberto("escola")
##     tr(Eventos.objetivo_atual())
##
## ==========================================================================
## ONDE O ESTADO MORA
##
## Os eventos novos ficam em `SaveManager.eventos_concluidos` (uma lista de
## ids, gravada no save). Os que já existiam antes deste controle continuam nas
## variáveis de sempre — `prolog_finished`, `tutorial_amuleto_visto`,
## `igreja_destrancada`... — e aqui são só LIDOS e ESCRITOS por elas (ver
## `_legado_ler`/`_legado_escrever`). Assim nenhum save antigo perde nada e
## nenhum script antigo precisa mudar para continuar funcionando.
##
## ==========================================================================
## A ABA "DEBUG EVENTOS"
##
## O debug usa `forcar(id, valor)`, e não `concluir`: ligar um evento liga
## antes tudo o que ele exige; desligar desliga junto tudo o que dependia dele.
## O save fica sempre coerente — nunca existe "escola escura" sem "falou do
## Jonny", nem "falou do Jonny" sem "leu o diário".
##
## ==========================================================================
## OS PODERES DA COGBLADE
##
## O círculo que abre segurando o botão da cogblade só mostra os poderes já
## LIBERADOS (`SaveManager.poderes_cogblade`); o jogo começa sem nenhum e o
## círculo abre vazio. Cada poder é liberado por um momento da história —
## `CAP1_AURA_AMULETO` (a aura no altar do inferno 4) libera o arremesso — e o
## debug liga e desliga cada um com `forcar_poder`.

signal mudou(id: String, feito: bool)
signal poder_mudou(id: String, liberado: bool)

const PROLOGO := 0
const CAPITULO_1 := 1
const CAPITULO_2 := 2

# --- Prólogo (estado nas variáveis antigas) ---------------------------------
const PROLOGO_TELEFONE := "prologo_telefone"
const PROLOGO_INTRO_CIDADE := "prologo_intro_cidade"
const PROLOGO_ARENA_INTRO := "prologo_arena_intro"
const PROLOGO_CONCLUIDO := "prologo_concluido"

# --- Capítulo 1 — O Amuleto ---------------------------------------------------
const CAP1_TUTORIAL_AMULETO := "cap1_tutorial_amuleto"
## Leu o diário em cima da mesa da casa do Jimmy. Abre a escola.
const CAP1_DIARIO_JIMMY := "cap1_diario_jimmy"
## Entrou na escola (versão clara, 18 h) e viu a cutscene dos adultos.
const CAP1_ESCOLA_ADULTOS := "cap1_escola_adultos"
## Falou com a professora da sala 107: a Dona Nice já levou o Jonny.
const CAP1_FALOU_DO_JONNY := "cap1_falou_do_jonny"
## A cutscene da quadra: o raio da Dona Nice transforma a escola na versão
## escura e o Grizzolito aparece.
const CAP1_ESCOLA_TRANSFORMADA := "cap1_escola_transformada"
## O Grizzolito morreu (na arena, na terceira forma).
const CAP1_GRIZZOLITO_DERROTADO := "cap1_grizzolito_derrotado"
## O portão da rua se fechou na cara dele; o mapa da escola zerou.
const CAP1_ESCOLA_PRESA := "cap1_escola_presa"
## A primeira travessia da red valve do porão (automática) até o inferno 4.
const CAP1_RED_VALVE := "cap1_red_valve"
## Pegou a aura do amuleto no altar do começo do inferno 4: o amuleto ganha a
## aura roxa e a cogblade, o primeiro poder (o arremesso).
const CAP1_AURA_AMULETO := "cap1_aura_amuleto"
## Viu a cutscene do mirante no topo do inferno 4 (a vista do grande inferno e
## a gárgula voando sobre a cratera). Só passa uma vez.
const CAP1_INFERNO_4_MIRANTE := "cap1_inferno_4_mirante"
## Chegou no fim do inferno 4 e o portal não o quis: ainda é fraco demais.
const CAP1_INFERNO_4_LIMITE := "cap1_inferno_4_limite"
## Destrancou por dentro o portão do pátio (estado em
## `GlobalEvents.escola_portao_destrancado`).
const CAP1_PORTAO_PATIO := "cap1_portao_patio"
## Saiu da escola: começa o Capítulo 2.
const CAP1_CONCLUIDO := "cap1_concluido"

# --- Capítulo 2 — Dona Nice ---------------------------------------------------
const CAP2_IGREJA_DESTRANCADA := "cap2_igreja_destrancada"

## A ordem da lista é a ordem da história (e a do debug).
## `rotulo` é a chave do CSV mostrada no debug.
const CATALOGO := [
	{"id": PROLOGO_TELEFONE, "cap": PROLOGO, "rotulo": "DEBUG_EVENT_PHONE_ANSWERED",
		"depende": []},
	{"id": PROLOGO_INTRO_CIDADE, "cap": PROLOGO, "rotulo": "DEBUG_EVENT_STAGE1_INTRO",
		"depende": [PROLOGO_TELEFONE]},
	{"id": PROLOGO_ARENA_INTRO, "cap": PROLOGO, "rotulo": "DEBUG_EVENT_BATTLEFIELD1_INTRO",
		"depende": [PROLOGO_INTRO_CIDADE]},
	{"id": PROLOGO_CONCLUIDO, "cap": PROLOGO, "rotulo": "DEBUG_EVENT_PROLOG_FINISHED",
		"depende": [PROLOGO_ARENA_INTRO]},

	{"id": CAP1_TUTORIAL_AMULETO, "cap": CAPITULO_1, "rotulo": "DEBUG_EVENT_AMULETO_TUTORIAL",
		"depende": [PROLOGO_CONCLUIDO]},
	{"id": CAP1_DIARIO_JIMMY, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_DIARIO",
		"depende": [PROLOGO_CONCLUIDO]},
	{"id": CAP1_ESCOLA_ADULTOS, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_ADULTOS",
		"depende": [CAP1_DIARIO_JIMMY]},
	{"id": CAP1_FALOU_DO_JONNY, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_FALOU_JONNY",
		"depende": [CAP1_ESCOLA_ADULTOS]},
	{"id": CAP1_ESCOLA_TRANSFORMADA, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_TRANSFORMADA",
		"depende": [CAP1_FALOU_DO_JONNY]},
	{"id": CAP1_GRIZZOLITO_DERROTADO, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_GRIZZOLITO",
		"depende": [CAP1_ESCOLA_TRANSFORMADA]},
	{"id": CAP1_ESCOLA_PRESA, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_PRESA",
		"depende": [CAP1_GRIZZOLITO_DERROTADO]},
	{"id": CAP1_RED_VALVE, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_RED_VALVE",
		"depende": [CAP1_ESCOLA_PRESA]},
	{"id": CAP1_AURA_AMULETO, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_AURA_AMULETO",
		"depende": [CAP1_RED_VALVE]},
	{"id": CAP1_INFERNO_4_MIRANTE, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_MIRANTE",
		"depende": [CAP1_RED_VALVE]},
	{"id": CAP1_INFERNO_4_LIMITE, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_INFERNO_4",
		"depende": [CAP1_RED_VALVE]},
	{"id": CAP1_PORTAO_PATIO, "cap": CAPITULO_1, "rotulo": "DEBUG_EVENT_ESCOLA_PORTAO",
		"depende": [CAP1_RED_VALVE]},
	{"id": CAP1_CONCLUIDO, "cap": CAPITULO_1, "rotulo": "DEBUG_EVT_CAP1_CONCLUIDO",
		"depende": [CAP1_PORTAO_PATIO]},

	{"id": CAP2_IGREJA_DESTRANCADA, "cap": CAPITULO_2, "rotulo": "DEBUG_EVENT_IGREJA_DESTRANCADA",
		"depende": [CAP1_CONCLUIDO]},
]

## Os poderes da cogblade, na ordem do círculo (o primeiro fica no topo).
## `rotulo` é o nome do poder no CSV (o mesmo nas duas línguas).
const PODER_THROWN := "thrown"
const PODER_SLAIN := "slain"
const PODER_CUT := "cut"
const PODER_FIRE_CROSS := "fire_cross"
const PODERES_COGBLADE := [
	{"id": PODER_THROWN, "rotulo": "COGBLADE_PODER_THROWN"},
	{"id": PODER_SLAIN, "rotulo": "COGBLADE_PODER_SLAIN"},
	{"id": PODER_CUT, "rotulo": "COGBLADE_PODER_CUT"},
	{"id": PODER_FIRE_CROSS, "rotulo": "COGBLADE_PODER_FIRE_CROSS"},
]
## O evento que libera cada poder (os que ainda não têm momento na história
## ficam de fora até ganhar um).
const EVENTO_DO_PODER := {
	PODER_THROWN: CAP1_AURA_AMULETO,
}

## Rótulo de cada capítulo no debug.
const TITULOS_CAPITULO := {
	PROLOGO: "TXT_PROLOGUE",
	CAPITULO_1: "TXT_CHAPTER_1",
	CAPITULO_2: "TXT_CHAPTER_2",
}

## Os lugares da cidade com porta. O que cada um precisa para abrir está em
## `local_aberto`; o aviso de trancado, em `aviso_local_fechado`.
const LOCAIS := ["casa_maycow", "casa_jimmy", "escola", "igreja", "hospital", "casa_nice"]


# ==============================================================================
# CONSULTA
# ==============================================================================

func feito(id: String) -> bool:
	var legado = _legado_ler(id)
	if legado != null:
		return bool(legado)
	return SaveManager.eventos_concluidos.has(id)


## Pode acontecer agora? (ainda não aconteceu e tudo o que ele exige, sim)
func pode(id: String) -> bool:
	if feito(id):
		return false
	for dep in dependencias(id):
		if not feito(dep):
			return false
	return true


func dependencias(id: String) -> Array:
	var e := _evento(id)
	return e.get("depende", []) if not e.is_empty() else []


func do_capitulo(cap: int) -> Array:
	var out: Array = []
	for e in CATALOGO:
		if int(e["cap"]) == cap:
			out.append(String(e["id"]))
	return out


func rotulo(id: String) -> String:
	return String(_evento(id).get("rotulo", id))


## 0 prólogo, 1 Capítulo 1, 2 Capítulo 2...
func capitulo_atual() -> int:
	if not (feito(PROLOGO_CONCLUIDO) or GlobalEvents.entering_chapter_1):
		return PROLOGO
	if not feito(CAP1_CONCLUIDO):
		return CAPITULO_1
	return CAPITULO_2


# ==============================================================================
# MUDANÇA
# ==============================================================================

## O jogo concluindo um evento. Recusa (e avisa no log) se faltar alguma
## dependência — é o que segura a ordem da história no lugar.
func concluir(id: String, gravar: bool = true) -> bool:
	if _evento(id).is_empty():
		push_warning("Eventos: evento desconhecido '%s'" % id)
		return false
	if feito(id):
		return false
	for dep in dependencias(id):
		if not feito(dep):
			push_warning("Eventos: '%s' exige '%s' antes" % [id, dep])
			return false
	_escrever(id, true)
	if gravar:
		SaveManager.save_game()
	return true


## Só pro debug: liga levando junto as dependências, ou desliga levando junto
## quem dependia dele. Grava no fim.
func forcar(id: String, valor: bool) -> void:
	if valor:
		_ligar_com_dependencias(id)
	else:
		_desligar_com_dependentes(id)
	SaveManager.save_game()


func _ligar_com_dependencias(id: String) -> void:
	for dep in dependencias(id):
		_ligar_com_dependencias(dep)
	if not feito(id):
		_escrever(id, true)


func _desligar_com_dependentes(id: String) -> void:
	for e in CATALOGO:
		if (e["depende"] as Array).has(id):
			_desligar_com_dependentes(String(e["id"]))
	if feito(id):
		_escrever(id, false)


func _escrever(id: String, valor: bool) -> void:
	if not _legado_escrever(id, valor):
		if valor:
			if not SaveManager.eventos_concluidos.has(id):
				SaveManager.eventos_concluidos.append(id)
		else:
			SaveManager.eventos_concluidos.erase(id)
	# o poder que este evento libera vai e volta junto com ele
	for poder in EVENTO_DO_PODER:
		if EVENTO_DO_PODER[poder] == id:
			_escrever_poder(poder, valor)
	mudou.emit(id, valor)


func _evento(id: String) -> Dictionary:
	for e in CATALOGO:
		if e["id"] == id:
			return e
	return {}


# ==============================================================================
# OS PODERES DA COGBLADE
# ==============================================================================

func poder_liberado(id: String) -> bool:
	return SaveManager.poderes_cogblade.has(id)


## Os ids liberados, na ordem do círculo.
func poderes_liberados() -> Array:
	var out: Array = []
	for p in PODERES_COGBLADE:
		if poder_liberado(String(p["id"])):
			out.append(String(p["id"]))
	return out


func rotulo_poder(id: String) -> String:
	for p in PODERES_COGBLADE:
		if p["id"] == id:
			return String(p["rotulo"])
	return id


## Só pro debug: liga ou desliga um poder e grava. (O jogo libera os poderes
## pelos eventos de `EVENTO_DO_PODER`.)
func forcar_poder(id: String, valor: bool) -> void:
	_escrever_poder(id, valor)
	SaveManager.save_game()


func _escrever_poder(id: String, valor: bool) -> void:
	if valor and not SaveManager.poderes_cogblade.has(id):
		SaveManager.poderes_cogblade.append(id)
	elif not valor:
		SaveManager.poderes_cogblade.erase(id)
	poder_mudou.emit(id, valor)


## O amuleto já tem a aura roxa (a do altar do inferno 4)?
func amuleto_com_aura() -> bool:
	return feito(CAP1_AURA_AMULETO)


# ==============================================================================
# OS EVENTOS QUE JÁ EXISTIAM (estado nas variáveis de antes)
# ==============================================================================

## null = o evento é novo e mora em `eventos_concluidos`.
func _legado_ler(id: String) -> Variant:
	match id:
		PROLOGO_TELEFONE:
			return SaveManager.tem_arquivo("telefonema_dona_nice")
		PROLOGO_INTRO_CIDADE:
			return SaveManager.stage_1_intro_played
		PROLOGO_ARENA_INTRO:
			return SaveManager.battlefield_1_intro_played
		PROLOGO_CONCLUIDO:
			return SaveManager.prolog_finished
		CAP1_TUTORIAL_AMULETO:
			return SaveManager.tutorial_amuleto_visto
		CAP1_PORTAO_PATIO:
			return GlobalEvents.escola_portao_destrancado
		CAP2_IGREJA_DESTRANCADA:
			return SaveManager.igreja_destrancada
	return null


func _legado_escrever(id: String, valor: bool) -> bool:
	match id:
		PROLOGO_TELEFONE:
			if valor:
				if not SaveManager.arquivos_desbloqueados.has("telefonema_dona_nice"):
					SaveManager.arquivos_desbloqueados.append("telefonema_dona_nice")
			else:
				SaveManager.arquivos_desbloqueados.erase("telefonema_dona_nice")
		PROLOGO_INTRO_CIDADE:
			SaveManager.stage_1_intro_played = valor
		PROLOGO_ARENA_INTRO:
			SaveManager.battlefield_1_intro_played = valor
		PROLOGO_CONCLUIDO:
			SaveManager.prolog_finished = valor
		CAP1_TUTORIAL_AMULETO:
			SaveManager.tutorial_amuleto_visto = valor
		CAP1_PORTAO_PATIO:
			GlobalEvents.escola_portao_destrancado = valor
		CAP2_IGREJA_DESTRANCADA:
			SaveManager.igreja_destrancada = valor
		_:
			return false
	return true


# ==============================================================================
# O QUE OS EVENTOS LIBERAM
# ==============================================================================

## A porta deste lugar da cidade abre?
##
## No prólogo nada muda (o roteiro de lá já se controla sozinho). No Capítulo 1
## a cidade inteira está fechada, menos a casa do Maycow, a do Jimmy e — depois
## do diário — a escola. Do Capítulo 2 em diante valem as regras de cada lugar
## (a igreja continua pedindo a chave, ver `SaveManager.igreja_aberta`).
func local_aberto(local: String) -> bool:
	match capitulo_atual():
		PROLOGO:
			return true
		CAPITULO_1:
			match local:
				"casa_maycow", "casa_jimmy":
					return true
				"escola":
					return feito(CAP1_DIARIO_JIMMY)
			return false
	return true


## A frase de "trancado" deste lugar (chave do CSV), ou "" se ele está aberto.
func aviso_local_fechado(local: String) -> String:
	if local_aberto(local):
		return ""
	match local:
		"escola":
			return "PROMPT_ESCOLA_FECHADA"
		"igreja":
			return "PROMPT_CHURCH_LOCKED"
		"hospital":
			return "PROMPT_HOSPITAL_FECHADO"
		"casa_nice":
			return "PROMPT_CASA_NICE_FECHADA"
	return "PROMPT_LOCAL_FECHADO"


## A escola desta visita: a CLARA (fim de expediente, 18 h, gente andando) até
## o raio da quadra; a ESCURA, a de sempre, dali em diante. Antes do Capítulo 1
## (debug, viagem rápida) ela é a escura, como sempre foi.
func escola_clara() -> bool:
	return capitulo_atual() == CAPITULO_1 and not feito(CAP1_ESCOLA_TRANSFORMADA)


## A luta com o Grizzolito na quadra está valendo (a escola já escureceu e
## ele ainda não morreu)?
func luta_grizzolito() -> bool:
	return feito(CAP1_ESCOLA_TRANSFORMADA) and not feito(CAP1_GRIZZOLITO_DERROTADO)


## O Maycow está preso na escola (do portão fechado até destrancar o do pátio).
func escola_presa() -> bool:
	return feito(CAP1_ESCOLA_PRESA) and not feito(CAP1_PORTAO_PATIO)


## O que fazer agora (chave do CSV), ou "" quando não há objetivo.
func objetivo_atual() -> String:
	match capitulo_atual():
		CAPITULO_1:
			if not feito(CAP1_DIARIO_JIMMY):
				return "OBJ_CAP1_CASA_JIMMY"
			if not feito(CAP1_ESCOLA_ADULTOS):
				return "OBJ_CAP1_IR_ESCOLA"
			if not feito(CAP1_FALOU_DO_JONNY):
				return "OBJ_CAP1_ULTIMA_SALA"
			if not feito(CAP1_ESCOLA_TRANSFORMADA):
				return "OBJ_CAP1_CASA_NICE"
			if not feito(CAP1_GRIZZOLITO_DERROTADO):
				return "OBJ_CAP1_GRIZZOLITO"
			if not feito(CAP1_RED_VALVE):
				return "OBJ_CAP1_SAIR_ESCOLA"
			if not feito(CAP1_PORTAO_PATIO):
				return "OBJ_CAP1_ATRAVESSAR_PORAO"
			return "OBJ_CAP1_SAIR_PELO_PATIO"
		CAPITULO_2:
			if SaveManager.evento_dona_nice == 0:
				return "OBJ_CAP2_CASA_NICE"
	return ""
