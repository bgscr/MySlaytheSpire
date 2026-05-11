extends RefCounted

const LocalizationService := preload("res://scripts/app/localization_service.gd")

func test_default_locale_is_chinese() -> bool:
	var service := LocalizationService.new("user://test_locale_default.cfg")
	service.clear_saved_locale()
	service.load_or_default()
	var passed := service.current_locale == "zh_CN" and TranslationServer.get_locale() == "zh_CN"
	service.clear_saved_locale()
	assert(passed)
	return passed

func test_switch_locale_emits_signal_and_persists() -> bool:
	var service := LocalizationService.new("user://test_locale_switch.cfg")
	service.clear_saved_locale()
	var emitted: Array[String] = []
	service.locale_changed.connect(func(locale: String): emitted.append(locale))
	service.load_or_default()
	service.set_locale("en")
	var reloaded := LocalizationService.new("user://test_locale_switch.cfg")
	reloaded.load_or_default()
	var passed := service.current_locale == "en" \
		and reloaded.current_locale == "en" \
		and emitted == ["zh_CN", "en"]
	service.clear_saved_locale()
	assert(passed)
	return passed

func test_unsupported_locale_falls_back_to_chinese() -> bool:
	var service := LocalizationService.new("user://test_locale_fallback.cfg")
	service.clear_saved_locale()
	service.set_locale("ja")
	var passed := service.current_locale == "zh_CN"
	service.clear_saved_locale()
	assert(passed)
	return passed
