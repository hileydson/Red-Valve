extends RefCounted
class_name ArquivosDados

## Catalogo dos arquivos de texto que o Maycow vai juntando pelo jogo e que
## aparecem na aba ARQUIVOS do menu.
##
## Cada arquivo e uma lista de PARAGRAFOS, e cada paragrafo e uma lista de
## chaves de traducao. Essa forma nao e enfeite: e exatamente o formato que as
## cutscenes ja usavam pra exibir texto (a do prologo chama de "chunks", uma
## leva de falas por tomada de camera). Assim o arquivo e a cutscene leem a
## MESMA lista — mexer no texto num lugar so ja arruma os dois, e nao existe o
## risco de o arquivo do menu ficar contando uma versao velha da cena.
##
## Quem desbloqueia:
##   apos_um_dia_de_trabalho  -> the_house.gd, ao entrar na casa
##   telefonema_dona_nice     -> the_house.gd, ao terminar a ligacao
##   caderno_do_jimmy         -> stage_1.gd, quando o Capitulo 1 comeca
##
## O que o jogador ja abriu mora em SaveManager.arquivos_desbloqueados; aqui so
## existe o conteudo.

const CATALOGO := [
	{
		"id": "apos_um_dia_de_trabalho",
		"titulo": "FILE_APOS_DIA_TRABALHO_TITLE",
		# a introducao do jogo, narrada na stage_1_cutscene_prologo
		"paragrafos": [
			["PROLOG_BEGIN_1_1", "PROLOG_BEGIN_1_2", "PROLOG_BEGIN_1_3"],
			["PROLOG_BEGIN_1_4", "PROLOG_BEGIN_1_5", "PROLOG_BEGIN_2_1"],
			["PROLOG_BEGIN_3_1", "PROLOG_BEGIN_3_2", "PROLOG_BEGIN_4_1", "PROLOG_BEGIN_4_2"],
			["PROLOG_BEGIN_4_3", "PROLOG_BEGIN_4_4"],
		],
	},
	{
		"id": "telefonema_dona_nice",
		"titulo": "FILE_TELEFONEMA_NICE_TITLE",
		# a ligacao inteira, do "alo" ate o "eu vou la verificar"
		"paragrafos": [
			["PROLOG_PHONE_1_1", "PROLOG_PHONE_1_2", "PROLOG_PHONE_1_3", "PROLOG_PHONE_1_4",
				"PROLOG_PHONE_1_5", "PROLOG_PHONE_1_6", "PROLOG_PHONE_1_7"],
			["PROLOG_PHONE_2_1", "PROLOG_PHONE_2_2", "PROLOG_PHONE_2_3", "PROLOG_PHONE_2_4",
				"PROLOG_PHONE_2_5", "PROLOG_PHONE_2_6", "PROLOG_PHONE_2_7", "PROLOG_PHONE_2_8"],
			["PROLOG_PHONE_3_1", "PROLOG_PHONE_3_2", "PROLOG_PHONE_3_3", "PROLOG_PHONE_3_4"],
		],
	},
	{
		"id": "caderno_do_jimmy",
		"titulo": "FILE_CADERNO_JIMMY_TITLE",
		# o fim do prologo narrado na cutscene_fight_with_power: a arena, o golpe
		# final, o despertar na oficina e o que o caderno de Jimmy contava
		"paragrafos": [
			["WITH_POWER_1_1", "WITH_POWER_1_2", "WITH_POWER_1_3", "WITH_POWER_1_4"],
			["WITH_POWER_2_1", "WITH_POWER_2_2", "WITH_POWER_2_3"],
			["WITH_POWER_3_1", "WITH_POWER_3_2", "WITH_POWER_3_3"],
			["WITH_POWER_4_1", "WITH_POWER_4_2", "WITH_POWER_4_3", "WITH_POWER_4_4"],
		],
	},
]


## O arquivo inteiro, ou um dicionario vazio se o id nao existir.
static func por_id(id: String) -> Dictionary:
	for arq in CATALOGO:
		if arq["id"] == id:
			return arq
	return {}


## Titulo ja traduzido.
static func titulo(id: String) -> String:
	var arq := por_id(id)
	if arq.is_empty():
		return id
	return TranslationServer.translate(String(arq["titulo"]))


## Os paragrafos como a cutscene do prologo espera: lista de listas de chaves.
static func paragrafos(id: String) -> Array:
	var arq := por_id(id)
	if arq.is_empty():
		return []
	return arq["paragrafos"]


## As chaves numa lista so, na ordem, como a cutscene do telefone espera.
static func linhas(id: String) -> Array:
	var out: Array = []
	for p in paragrafos(id):
		out.append_array(p)
	return out


## O texto montado pra leitura no menu: uma frase por linha, linha em branco
## entre paragrafos. E como as falas foram escritas — cada chave e uma frase
## curta, exibida sozinha na cutscene —, entao emenda-las num bloco corrido
## deixaria o arquivo pesado de ler.
static func corpo(id: String) -> String:
	var blocos := PackedStringArray()
	for p in paragrafos(id):
		var linhas_p := PackedStringArray()
		for chave in p:
			linhas_p.append(TranslationServer.translate(String(chave)))
		blocos.append("\n".join(linhas_p))
	return "\n\n".join(blocos)


## Os ids que o jogador ja desbloqueou, na ordem do catalogo (que e a ordem em
## que a historia acontece), e nao na ordem em que foram salvos.
static func desbloqueados() -> Array:
	var out: Array = []
	for arq in CATALOGO:
		if SaveManager.tem_arquivo(String(arq["id"])):
			out.append(arq["id"])
	return out
