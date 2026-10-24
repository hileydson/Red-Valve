extends Node3D

## Atualiza as placas 3D quando o idioma muda durante a visita ao hospital.
var _idioma: String = ""
var _placas: Array[Label3D] = []


func _ready() -> void:
	for no in find_children("*", "Label3D", true, false):
		if no.has_meta("chave_traducao"):
			_placas.append(no)
	_atualizar_textos()
	set_process(true)


func _process(_delta: float) -> void:
	if _idioma != TranslationServer.get_locale():
		_atualizar_textos()


func _atualizar_textos() -> void:
	_idioma = TranslationServer.get_locale()
	for placa in _placas:
		placa.text = tr(String(placa.get_meta("chave_traducao")))
