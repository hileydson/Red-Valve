@tool
extends Node3D

## Pinta um modelo gerado por script: casa cada malha do .glb com um .tres.
##
## É o `arena_2_materiais.gd` com a tabela exportada em vez de constante, para
## servir aos cenários novos (arena 3, cemitério, inferno) sem um script por
## cena. Os objetos vêm do Blender nomeados `SM_<prefixo>_<setor>_<material>`;
## a busca é pelo sufixo MAIS LONGO que casar ("pedra_esc" ganha de "pedra").
##
## `@tool` para o editor mostrar o cenário pintado em vez de um bloco cinza.

## Pasta dos .tres (termina em "/").
@export var pasta: String = ""
## Sufixo do nome do objeto -> arquivo .tres dentro de `pasta`.
@export var materiais: Dictionary = {}
## Sufixos que não projetam sombra (silhueta de horizonte, emissão).
@export var sem_sombra: PackedStringArray = []
## Distância (m) a partir da qual uma malha deixa de ser desenhada. 0 = sempre.
## Para cenário de névoa fechada (o inferno 3): o que a névoa já apagou não
## precisa custar desenho. As malhas vêm em setores pequenos, então o corte é
## por pedaço de mapa e não por cenário inteiro.
@export var alcance_visivel: float = 0.0
## Sufixos que ignoram `alcance_visivel` (silhueta grande que se vê de longe).
@export var sempre_visivel: PackedStringArray = []

var _cache: Dictionary = {}


func _ready() -> void:
	aplicar()


## Pública de propósito: dá para chamar do editor depois de reimportar o .glb.
func aplicar() -> void:
	for malha in find_children("*", "MeshInstance3D", true, false):
		var chave := _chave_do_nome(malha.name)
		if chave == "":
			continue
		var material := _material(chave)
		if material == null:
			continue
		malha.set_surface_override_material(0, material)
		if chave in sem_sombra:
			malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if alcance_visivel > 0.0 and not chave in sempre_visivel:
			malha.visibility_range_end = alcance_visivel
			malha.visibility_range_end_margin = alcance_visivel * 0.1


func _chave_do_nome(nome: String) -> String:
	var limpo := nome.to_lower()
	var melhor := ""
	for chave in materiais.keys():
		if limpo.ends_with(chave) and String(chave).length() > melhor.length():
			melhor = chave
	return melhor


func _material(chave: String) -> Material:
	if _cache.has(chave):
		return _cache[chave]
	var caminho: String = pasta + String(materiais[chave])
	var material: Material = null
	if ResourceLoader.exists(caminho):
		material = load(caminho)
	else:
		push_warning("materiais: não encontrado: " + caminho)
	_cache[chave] = material
	return material
