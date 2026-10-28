@tool
extends Node3D

## Pinta a arena 2: casa cada malha do .glb com um material .tres.
##
## Mesma mecânica da igreja (`igreja_materiais.gd`). O modelo vem do gerador do
## Blender (`tools/blender/arena_2/gerar_arena_2.py`) com os objetos nomeados
## `SM_ar2_<setor>_<material>` — "setor" é o pedaço da arena (piso_ne, anel_4,
## boca, horizonte...) e "material" é o que este script procura. O .glb carrega
## só um material de marcação, cinza; quem vale é o que se aplica aqui.
##
## Por que não deixar o material no .glb: o modelo é REGERADO por script. Todo
## ajuste feito no material importado se perderia na próxima reimportação.
##
## `@tool` para o editor mostrar a arena pintada em vez de um bloco cinza.

const PASTA := "res://assets/3d_model/stages/battlefield_2/materiais/"

## Sufixo do nome do objeto -> arquivo de material. A busca é pelo sufixo MAIS
## LONGO que casar: "pedra_esc" tem de ganhar de "pedra", senão a arena inteira
## sai com o material da parede clara.
const MATERIAIS := {
	"pedra_esc": "mat_pedra_esc.tres",
	"pedra": "mat_pedra.tres",
	"queimado": "mat_queimado.tres",
	"terra": "mat_terra.tres",
	"metal": "mat_metal.tres",
	"osso": "mat_osso.tres",
	"carne": "mat_carne.tres",
	"brasa": "mat_brasa.tres",
	"sigilo": "mat_sigilo.tres",
	"silhueta": "mat_silhueta.tres",
}

## Malhas que não projetam sombra. A silhueta do horizonte está a 100 m e fora
## do alcance do shadow split; brasa e sigilo são luz, não bloqueio de luz.
const SEM_SOMBRA := ["silhueta", "brasa", "sigilo"]

var _cache: Dictionary = {}


func _ready() -> void:
	aplicar()


## Pública de propósito: dá para chamar do editor depois de reimportar o .glb,
## sem recarregar a cena inteira.
func aplicar() -> void:
	for malha in find_children("*", "MeshInstance3D", true, false):
		var chave := _chave_do_nome(malha.name)
		if chave == "":
			continue
		var material := _material(chave)
		if material == null:
			continue
		malha.set_surface_override_material(0, material)
		if chave in SEM_SOMBRA:
			malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
		push_warning("arena_2: material não encontrado: " + caminho)
	_cache[chave] = material
	return material
