@tool
extends Node3D

## Pinta o interior da igreja: casa cada malha do .glb com um material .tres.
##
## O modelo vem do gerador do Blender (`tools/blender/igreja/gerar_igreja.py`)
## com os objetos nomeados `SM_igr_<setor>_<material>` — "setor" é a fatia da
## nave (a, b, c, d) e "material" é o que este script procura. O .glb carrega
## só um material de marcação, cinza; quem vale é o que se aplica aqui.
##
## Por que não deixar o material no .glb: o modelo é REGERADO por script. Todo
## ajuste feito no material importado (e são muitos: escala de textura,
## emissão do vitral, normal) se perderia na próxima reimportação. Aqui o
## ajuste mora num .tres versionado, fora do modelo.
##
## `@tool` para o editor mostrar a igreja pintada em vez de um bloco cinza.

const PASTA := "res://assets/3d_model/stages/igreja/materiais/"

## Sufixo do nome do objeto -> arquivo de material. A ordem importa:
## "pedra_esc" tem de ser testado ANTES de "pedra", senão o chão inteiro sai
## com o material da parede. Por isso a busca é pelo sufixo MAIS LONGO que
## casar, e não pela primeira chave do dicionário.
const MATERIAIS := {
	"vitral_lanceta_roto": "mat_vitral_lanceta_roto.tres",
	"vitral_lanceta": "mat_vitral_lanceta.tres",
	"vitral_larga_roto": "mat_vitral_larga_roto.tres",
	"vitral_larga": "mat_vitral_larga.tres",
	"vitral_rosacea": "mat_vitral_rosacea.tres",
	"pedra_esc": "mat_pedra_esc.tres",
	"pedra": "mat_pedra.tres",
	"madeira": "mat_madeira.tres",
	"metal": "mat_metal.tres",
	"ouro": "mat_ouro.tres",
	"pano": "mat_pano.tres",
	"vidro": "mat_vidro.tres",
}

## Malhas que não devem projetar sombra. Vitral projetando sombra come
## performance e não acrescenta nada: a luz que atravessa a janela já é um
## spot posicionado do lado de fora.
const SEM_SOMBRA := ["vitral", "vidro", "pano"]

var _cache: Dictionary = {}


func _ready() -> void:
	aplicar()


## Pública de propósito: dá para chamar do editor (ou de um @tool_button) depois
## de reimportar o .glb, sem recarregar a cena inteira.
func aplicar() -> void:
	for malha in find_children("*", "MeshInstance3D", true, false):
		var chave := _chave_do_nome(malha.name)
		if chave == "":
			continue
		var material := _material(chave)
		if material == null:
			continue
		malha.set_surface_override_material(0, material)
		for marca in SEM_SOMBRA:
			if chave.begins_with(marca):
				malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				break


func _chave_do_nome(nome: String) -> String:
	var limpo := nome.to_lower()
	var melhor := ""
	for chave in MATERIAIS.keys():
		if limpo.ends_with(chave) and chave.length() > melhor.length():
			melhor = chave
	return melhor


func _material(chave: String) -> Material:
	if _cache.has(chave):
		return _cache[chave]
	var caminho: String = PASTA + MATERIAIS[chave]
	var material: Material = null
	if ResourceLoader.exists(caminho):
		material = load(caminho)
	else:
		push_warning("igreja: material não encontrado: " + caminho)
	_cache[chave] = material
	return material
