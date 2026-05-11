class_name LocalizationService
extends RefCounted

signal locale_changed(locale: String)

const LOCALE_ZH_CN := "zh_CN"
const LOCALE_EN := "en"
const SUPPORTED_LOCALES: Array[String] = [LOCALE_ZH_CN, LOCALE_EN]
const DEFAULT_SETTINGS_PATH := "user://locale_settings.cfg"
const SECTION := "locale"
const KEY_CURRENT := "current"

var current_locale := LOCALE_ZH_CN
var settings_path := DEFAULT_SETTINGS_PATH

func _init(path: String = DEFAULT_SETTINGS_PATH) -> void:
	settings_path = path

func load_or_default() -> void:
	var config := ConfigFile.new()
	var loaded_locale := LOCALE_ZH_CN
	if config.load(settings_path) == OK:
		loaded_locale = String(config.get_value(SECTION, KEY_CURRENT, LOCALE_ZH_CN))
	set_locale(loaded_locale)

func set_locale(locale: String) -> void:
	var normalized := _normalized_locale(locale)
	current_locale = normalized
	TranslationServer.set_locale(normalized)
	_save_locale(normalized)
	locale_changed.emit(normalized)

func is_chinese() -> bool:
	return current_locale == LOCALE_ZH_CN

func toggle_locale() -> void:
	set_locale(LOCALE_EN if current_locale == LOCALE_ZH_CN else LOCALE_ZH_CN)

func clear_saved_locale() -> void:
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))

func _normalized_locale(locale: String) -> String:
	return locale if SUPPORTED_LOCALES.has(locale) else LOCALE_ZH_CN

func _save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY_CURRENT, locale)
	config.save(settings_path)
