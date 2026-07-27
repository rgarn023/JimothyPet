extends Node
## Runtime translations for Play Store languages (loaded from res://i18n/strings.json).

signal locale_changed(code: String)

const DATA_PATH := "res://i18n/strings.json"

var _locales: Array = []
var _ready_ok: bool = false


func _ready() -> void:
	_load_translations()
	_ready_ok = true
	call_deferred("_apply_saved_or_system")


func _load_translations() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("JimothyI18n: missing %s" % DATA_PATH)
		return
	var raw := FileAccess.get_file_as_string(DATA_PATH)
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("JimothyI18n: bad JSON")
		return
	_locales = data.get("locales", [])
	var strings: Dictionary = data.get("strings", {})
	for locale_code in strings.keys():
		var table: Dictionary = strings[locale_code]
		if typeof(table) != TYPE_DICTIONARY:
			continue
		var tr := Translation.new()
		tr.locale = str(locale_code)
		for key in table.keys():
			tr.add_message(str(key), str(table[key]))
		TranslationServer.add_translation(tr)


func locales() -> Array:
	return _locales


func _apply_saved_or_system() -> void:
	if PetState == null:
		return
	var code := str(PetState.locale_code)
	apply_locale(code, false)


func apply_locale(code: String, save: bool = true) -> void:
	var use := code.strip_edges()
	if use == "":
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(use)
	if save and PetState != null:
		PetState.locale_code = use
		PetState.save_game()
	locale_changed.emit(use)


func t(key: String, fallback: String = "") -> String:
	var translated := tr(key)
	if translated == key:
		return fallback if fallback != "" else key
	return translated
