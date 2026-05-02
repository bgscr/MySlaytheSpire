class_name ContentCatalog
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CardVisualDef := preload("res://scripts/data/card_visual_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const CombatBackgroundDef := preload("res://scripts/data/combat_background_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EnemyIntentDisplayDef := preload("res://scripts/data/enemy_intent_display_def.gd")
const EnemyIntentDisplayResolver := preload("res://scripts/presentation/enemy_intent_display_resolver.gd")
const EnemyVisualDef := preload("res://scripts/data/enemy_visual_def.gd")
const EventDef := preload("res://scripts/data/event_def.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const VisualThemeDef := preload("res://scripts/data/visual_theme_def.gd")

const DEFAULT_CARD_PATHS: Array[String] = [
	"res://resources/cards/sword/strike_sword.tres",
	"res://resources/cards/sword/guard.tres",
	"res://resources/cards/sword/flash_cut.tres",
	"res://resources/cards/sword/qi_surge.tres",
	"res://resources/cards/sword/break_stance.tres",
	"res://resources/cards/sword/cloud_step.tres",
	"res://resources/cards/sword/focused_slash.tres",
	"res://resources/cards/sword/sword_resonance.tres",
	"res://resources/cards/sword/horizon_arc.tres",
	"res://resources/cards/sword/iron_wind_cut.tres",
	"res://resources/cards/sword/rising_arc.tres",
	"res://resources/cards/sword/guardian_stance.tres",
	"res://resources/cards/sword/meridian_flash.tres",
	"res://resources/cards/sword/heart_piercer.tres",
	"res://resources/cards/sword/unbroken_focus.tres",
	"res://resources/cards/sword/wind_splitting_step.tres",
	"res://resources/cards/sword/clear_mind_guard.tres",
	"res://resources/cards/sword/thread_the_needle.tres",
	"res://resources/cards/sword/echoing_sword_heart.tres",
	"res://resources/cards/sword/heaven_cutting_arc.tres",
	"res://resources/cards/alchemy/toxic_pill.tres",
	"res://resources/cards/alchemy/healing_draught.tres",
	"res://resources/cards/alchemy/poison_mist.tres",
	"res://resources/cards/alchemy/inner_fire_pill.tres",
	"res://resources/cards/alchemy/cauldron_burst.tres",
	"res://resources/cards/alchemy/calming_powder.tres",
	"res://resources/cards/alchemy/toxin_needle.tres",
	"res://resources/cards/alchemy/spirit_distill.tres",
	"res://resources/cards/alchemy/cinnabar_seal.tres",
	"res://resources/cards/alchemy/bitter_extract.tres",
	"res://resources/cards/alchemy/smoke_screen.tres",
	"res://resources/cards/alchemy/quick_simmer.tres",
	"res://resources/cards/alchemy/white_jade_paste.tres",
	"res://resources/cards/alchemy/mercury_bloom.tres",
	"res://resources/cards/alchemy/ninefold_refine.tres",
	"res://resources/cards/alchemy/coiling_miasma.tres",
	"res://resources/cards/alchemy/needle_rain.tres",
	"res://resources/cards/alchemy/purifying_brew.tres",
	"res://resources/cards/alchemy/cauldron_overflow.tres",
	"res://resources/cards/alchemy/golden_core_detox.tres",
]

const DEFAULT_CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/sword_cultivator.tres",
	"res://resources/characters/alchemy_cultivator.tres",
]

const DEFAULT_ENEMY_PATHS: Array[String] = [
	"res://resources/enemies/training_puppet.tres",
	"res://resources/enemies/forest_bandit.tres",
	"res://resources/enemies/boss_heart_demon.tres",
	"res://resources/enemies/wild_fox_spirit.tres",
	"res://resources/enemies/ash_lantern_cultist.tres",
	"res://resources/enemies/stone_grove_guardian.tres",
	"res://resources/enemies/mirror_blade_adept.tres",
	"res://resources/enemies/venom_cauldron_hermit.tres",
	"res://resources/enemies/boss_storm_dragon.tres",
	"res://resources/enemies/scarlet_mantis_acolyte.tres",
	"res://resources/enemies/jade_armor_sentinel.tres",
	"res://resources/enemies/boss_void_tiger.tres",
	"res://resources/enemies/plague_jade_imp.tres",
	"res://resources/enemies/iron_oath_duelist.tres",
	"res://resources/enemies/miasma_cauldron_elder.tres",
	"res://resources/enemies/boss_sword_ghost.tres",
]

const DEFAULT_RELIC_PATHS: Array[String] = [
	"res://resources/relics/jade_talisman.tres",
	"res://resources/relics/bronze_incense_burner.tres",
	"res://resources/relics/cracked_spirit_coin.tres",
	"res://resources/relics/moonwell_seed.tres",
	"res://resources/relics/thunderseal_charm.tres",
	"res://resources/relics/dragon_bone_flute.tres",
	"res://resources/relics/mist_vein_bracelet.tres",
	"res://resources/relics/verdant_antidote_gourd.tres",
	"res://resources/relics/copper_mantis_hook.tres",
	"res://resources/relics/white_tiger_tally.tres",
	"res://resources/relics/nine_smoke_censer.tres",
	"res://resources/relics/starforged_meridian.tres",
	"res://resources/relics/paper_lantern_charm.tres",
	"res://resources/relics/mothwing_sachet.tres",
	"res://resources/relics/rusted_meridian_ring.tres",
	"res://resources/relics/silk_thread_prayer.tres",
	"res://resources/relics/black_pill_vial.tres",
	"res://resources/relics/cloudstep_sandals.tres",
	"res://resources/relics/immortal_peach_core.tres",
	"res://resources/relics/void_tiger_eye.tres",
]

const DEFAULT_EVENT_PATHS: Array[String] = [
	"res://resources/events/wandering_physician.tres",
	"res://resources/events/spirit_toll.tres",
	"res://resources/events/quiet_shrine.tres",
	"res://resources/events/sealed_sword_tomb.tres",
	"res://resources/events/alchemist_market.tres",
	"res://resources/events/spirit_beast_tracks.tres",
	"res://resources/events/forgotten_armory.tres",
	"res://resources/events/jade_debt_collector.tres",
	"res://resources/events/moonlit_ferry.tres",
	"res://resources/events/spirit_compact.tres",
	"res://resources/events/tea_house_rumor.tres",
	"res://resources/events/withered_master.tres",
]

const DEFAULT_ENEMY_INTENT_DISPLAY_PATHS: Array[String] = [
	"res://resources/intents/attack.tres",
	"res://resources/intents/block.tres",
	"res://resources/intents/status_poison.tres",
	"res://resources/intents/status_broken_stance.tres",
	"res://resources/intents/status_sword_focus.tres",
	"res://resources/intents/unknown.tres",
]

const DEFAULT_CARD_VISUAL_PATHS: Array[String] = [
	"res://resources/visuals/card_visuals/sword_strike.tres",
	"res://resources/visuals/card_visuals/sword_guard.tres",
	"res://resources/visuals/card_visuals/sword_flash_cut.tres",
	"res://resources/visuals/card_visuals/sword_qi_surge.tres",
	"res://resources/visuals/card_visuals/sword_break_stance.tres",
	"res://resources/visuals/card_visuals/sword_cloud_step.tres",
	"res://resources/visuals/card_visuals/sword_focused_slash.tres",
	"res://resources/visuals/card_visuals/sword_sword_resonance.tres",
	"res://resources/visuals/card_visuals/sword_horizon_arc.tres",
	"res://resources/visuals/card_visuals/sword_iron_wind_cut.tres",
	"res://resources/visuals/card_visuals/sword_rising_arc.tres",
	"res://resources/visuals/card_visuals/sword_guardian_stance.tres",
	"res://resources/visuals/card_visuals/sword_meridian_flash.tres",
	"res://resources/visuals/card_visuals/sword_heart_piercer.tres",
	"res://resources/visuals/card_visuals/sword_unbroken_focus.tres",
	"res://resources/visuals/card_visuals/sword_wind_splitting_step.tres",
	"res://resources/visuals/card_visuals/sword_clear_mind_guard.tres",
	"res://resources/visuals/card_visuals/sword_thread_the_needle.tres",
	"res://resources/visuals/card_visuals/sword_echoing_sword_heart.tres",
	"res://resources/visuals/card_visuals/sword_heaven_cutting_arc.tres",
	"res://resources/visuals/card_visuals/alchemy_toxic_pill.tres",
	"res://resources/visuals/card_visuals/alchemy_healing_draught.tres",
	"res://resources/visuals/card_visuals/alchemy_poison_mist.tres",
	"res://resources/visuals/card_visuals/alchemy_inner_fire_pill.tres",
	"res://resources/visuals/card_visuals/alchemy_cauldron_burst.tres",
	"res://resources/visuals/card_visuals/alchemy_calming_powder.tres",
	"res://resources/visuals/card_visuals/alchemy_toxin_needle.tres",
	"res://resources/visuals/card_visuals/alchemy_spirit_distill.tres",
	"res://resources/visuals/card_visuals/alchemy_cinnabar_seal.tres",
	"res://resources/visuals/card_visuals/alchemy_bitter_extract.tres",
	"res://resources/visuals/card_visuals/alchemy_smoke_screen.tres",
	"res://resources/visuals/card_visuals/alchemy_quick_simmer.tres",
	"res://resources/visuals/card_visuals/alchemy_white_jade_paste.tres",
	"res://resources/visuals/card_visuals/alchemy_mercury_bloom.tres",
	"res://resources/visuals/card_visuals/alchemy_ninefold_refine.tres",
	"res://resources/visuals/card_visuals/alchemy_coiling_miasma.tres",
	"res://resources/visuals/card_visuals/alchemy_needle_rain.tres",
	"res://resources/visuals/card_visuals/alchemy_purifying_brew.tres",
	"res://resources/visuals/card_visuals/alchemy_cauldron_overflow.tres",
	"res://resources/visuals/card_visuals/alchemy_golden_core_detox.tres",
]

const DEFAULT_COMBAT_BACKGROUND_PATHS: Array[String] = [
	"res://resources/visuals/backgrounds/default_combat.tres",
	"res://resources/visuals/backgrounds/sword_training_ground.tres",
	"res://resources/visuals/backgrounds/alchemy_mist_grove.tres",
]

const DEFAULT_VISUAL_THEME_PATHS: Array[String] = [
	"res://resources/visuals/themes/sword.tres",
	"res://resources/visuals/themes/alchemy.tres",
]

const DEFAULT_ENEMY_VISUAL_PATHS: Array[String] = [
	"res://resources/visuals/enemy_visuals/training_puppet.tres",
	"res://resources/visuals/enemy_visuals/forest_bandit.tres",
	"res://resources/visuals/enemy_visuals/boss_heart_demon.tres",
	"res://resources/visuals/enemy_visuals/wild_fox_spirit.tres",
	"res://resources/visuals/enemy_visuals/ash_lantern_cultist.tres",
	"res://resources/visuals/enemy_visuals/stone_grove_guardian.tres",
	"res://resources/visuals/enemy_visuals/mirror_blade_adept.tres",
	"res://resources/visuals/enemy_visuals/venom_cauldron_hermit.tres",
	"res://resources/visuals/enemy_visuals/boss_storm_dragon.tres",
	"res://resources/visuals/enemy_visuals/scarlet_mantis_acolyte.tres",
	"res://resources/visuals/enemy_visuals/jade_armor_sentinel.tres",
	"res://resources/visuals/enemy_visuals/boss_void_tiger.tres",
	"res://resources/visuals/enemy_visuals/plague_jade_imp.tres",
	"res://resources/visuals/enemy_visuals/iron_oath_duelist.tres",
	"res://resources/visuals/enemy_visuals/miasma_cauldron_elder.tres",
	"res://resources/visuals/enemy_visuals/boss_sword_ghost.tres",
]

var cards_by_id: Dictionary = {}
var characters_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var relics_by_id: Dictionary = {}
var events_by_id: Dictionary = {}
var enemy_intent_displays_by_id: Dictionary = {}
var card_visuals_by_card_id: Dictionary = {}
var combat_backgrounds_by_id: Dictionary = {}
var visual_themes_by_character_id: Dictionary = {}
var enemy_visuals_by_enemy_id: Dictionary = {}
var load_errors: Array[String] = []
var locale_path := "res://localization/zh_CN.po"

func load_default() -> void:
	load_from_paths(
		DEFAULT_CARD_PATHS,
		DEFAULT_CHARACTER_PATHS,
		DEFAULT_ENEMY_PATHS,
		DEFAULT_RELIC_PATHS,
		DEFAULT_EVENT_PATHS,
		DEFAULT_ENEMY_INTENT_DISPLAY_PATHS,
		DEFAULT_CARD_VISUAL_PATHS,
		DEFAULT_COMBAT_BACKGROUND_PATHS,
		DEFAULT_VISUAL_THEME_PATHS,
		DEFAULT_ENEMY_VISUAL_PATHS
	)

func load_from_paths(
	card_paths: Array[String],
	character_paths: Array[String],
	enemy_paths: Array[String],
	relic_paths: Array[String],
	event_paths: Array[String] = [],
	enemy_intent_display_paths: Array[String] = [],
	card_visual_paths: Array[String] = [],
	combat_background_paths: Array[String] = [],
	visual_theme_paths: Array[String] = [],
	enemy_visual_paths: Array[String] = []
) -> void:
	clear()
	_load_cards(card_paths)
	_load_characters(character_paths)
	_load_enemies(enemy_paths)
	_load_relics(relic_paths)
	_load_events(event_paths)
	_load_enemy_intent_displays(enemy_intent_display_paths)
	_load_card_visuals(card_visual_paths)
	_load_combat_backgrounds(combat_background_paths)
	_load_visual_themes(visual_theme_paths)
	_load_enemy_visuals(enemy_visual_paths)

func clear() -> void:
	cards_by_id.clear()
	characters_by_id.clear()
	enemies_by_id.clear()
	relics_by_id.clear()
	events_by_id.clear()
	enemy_intent_displays_by_id.clear()
	card_visuals_by_card_id.clear()
	combat_backgrounds_by_id.clear()
	visual_themes_by_character_id.clear()
	enemy_visuals_by_enemy_id.clear()
	load_errors.clear()

func get_card(card_id: String) -> CardDef:
	return cards_by_id.get(card_id) as CardDef

func get_character(character_id: String) -> CharacterDef:
	return characters_by_id.get(character_id) as CharacterDef

func get_enemy(enemy_id: String) -> EnemyDef:
	return enemies_by_id.get(enemy_id) as EnemyDef

func get_relic(relic_id: String) -> RelicDef:
	return relics_by_id.get(relic_id) as RelicDef

func get_event(event_id: String) -> EventDef:
	return events_by_id.get(event_id) as EventDef

func get_enemy_intent_display(display_id: String) -> EnemyIntentDisplayDef:
	return enemy_intent_displays_by_id.get(display_id) as EnemyIntentDisplayDef

func get_card_visual(card_id: String) -> CardVisualDef:
	return card_visuals_by_card_id.get(card_id) as CardVisualDef

func get_combat_background(background_id: String) -> CombatBackgroundDef:
	return combat_backgrounds_by_id.get(background_id) as CombatBackgroundDef

func get_visual_theme(character_id: String) -> VisualThemeDef:
	return visual_themes_by_character_id.get(character_id) as VisualThemeDef

func get_enemy_visual(enemy_id: String) -> EnemyVisualDef:
	return enemy_visuals_by_enemy_id.get(enemy_id) as EnemyVisualDef

func get_events() -> Array[EventDef]:
	var result: Array[EventDef] = []
	for event: EventDef in events_by_id.values():
		result.append(event)
	return result

func get_cards_for_character(character_id: String) -> Array[CardDef]:
	var result: Array[CardDef] = []
	var character := get_character(character_id)
	if character != null:
		for card_id in character.card_pool_ids:
			var card := get_card(card_id)
			if card != null:
				result.append(card)
		return result
	for card: CardDef in cards_by_id.values():
		if card.character_id == character_id:
			result.append(card)
	return result

func get_cards_by_rarity(character_id: String, rarity: String) -> Array[CardDef]:
	var result: Array[CardDef] = []
	for card: CardDef in get_cards_for_character(character_id):
		if card.rarity == rarity:
			result.append(card)
	return result

func get_enemies_by_tier(tier: String) -> Array[EnemyDef]:
	var result: Array[EnemyDef] = []
	for enemy: EnemyDef in enemies_by_id.values():
		if enemy.tier == tier:
			result.append(enemy)
	return result

func get_relics_by_tier(tier: String) -> Array[RelicDef]:
	var result: Array[RelicDef] = []
	for relic: RelicDef in relics_by_id.values():
		if relic.tier == tier:
			result.append(relic)
	return result

func validate() -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	var locale_error_count := errors.size()
	var locale_keys := _load_locale_keys(errors)
	var locale_loaded := errors.size() == locale_error_count
	_validate_ids("card", cards_by_id, errors)
	_validate_ids("character", characters_by_id, errors)
	_validate_ids("enemy", enemies_by_id, errors)
	_validate_ids("relic", relics_by_id, errors)
	_validate_ids("event", events_by_id, errors)
	_validate_ids("enemy intent display", enemy_intent_displays_by_id, errors)
	_validate_enemy_intent_displays(errors)
	_validate_default_enemy_intent_displays(errors)
	_validate_visual_catalog(errors)
	_validate_character_card_refs(errors)
	_validate_event_options(errors)
	if locale_loaded:
		_validate_locale_keys(locale_keys, errors)
	return errors

func _load_cards(paths: Array[String]) -> void:
	for path in paths:
		var card := load(path) as CardDef
		if card == null:
			_record_load_error("ContentCatalog expected CardDef resource: %s" % path)
			continue
		if card.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		cards_by_id[card.id] = card

func _load_characters(paths: Array[String]) -> void:
	for path in paths:
		var character := load(path) as CharacterDef
		if character == null:
			_record_load_error("ContentCatalog expected CharacterDef resource: %s" % path)
			continue
		if character.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		characters_by_id[character.id] = character

func _load_enemies(paths: Array[String]) -> void:
	for path in paths:
		var enemy := load(path) as EnemyDef
		if enemy == null:
			_record_load_error("ContentCatalog expected EnemyDef resource: %s" % path)
			continue
		if enemy.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		enemies_by_id[enemy.id] = enemy

func _load_relics(paths: Array[String]) -> void:
	for path in paths:
		var relic := load(path) as RelicDef
		if relic == null:
			_record_load_error("ContentCatalog expected RelicDef resource: %s" % path)
			continue
		if relic.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		relics_by_id[relic.id] = relic

func _load_events(paths: Array[String]) -> void:
	for path in paths:
		var event := load(path) as EventDef
		if event == null:
			_record_load_error("ContentCatalog expected EventDef resource: %s" % path)
			continue
		if event.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		events_by_id[event.id] = event

func _load_enemy_intent_displays(paths: Array[String]) -> void:
	for path in paths:
		var display := load(path) as EnemyIntentDisplayDef
		if display == null:
			_record_load_error("ContentCatalog expected EnemyIntentDisplayDef resource: %s" % path)
			continue
		if display.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		enemy_intent_displays_by_id[display.id] = display

func _load_card_visuals(paths: Array[String]) -> void:
	for path in paths:
		var visual := load(path) as CardVisualDef
		if visual == null:
			_record_load_error("ContentCatalog expected CardVisualDef resource: %s" % path)
			continue
		if visual.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		if visual.card_id.is_empty():
			_record_load_error("ContentCatalog card visual has empty card_id: %s" % path)
			continue
		card_visuals_by_card_id[visual.card_id] = visual

func _load_combat_backgrounds(paths: Array[String]) -> void:
	for path in paths:
		var background := load(path) as CombatBackgroundDef
		if background == null:
			_record_load_error("ContentCatalog expected CombatBackgroundDef resource: %s" % path)
			continue
		if background.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		combat_backgrounds_by_id[background.id] = background

func _load_visual_themes(paths: Array[String]) -> void:
	for path in paths:
		var theme := load(path) as VisualThemeDef
		if theme == null:
			_record_load_error("ContentCatalog expected VisualThemeDef resource: %s" % path)
			continue
		if theme.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		if theme.character_id.is_empty():
			_record_load_error("ContentCatalog visual theme has empty character_id: %s" % path)
			continue
		visual_themes_by_character_id[theme.character_id] = theme

func _load_enemy_visuals(paths: Array[String]) -> void:
	for path in paths:
		var visual := load(path) as EnemyVisualDef
		if visual == null:
			_record_load_error("ContentCatalog expected EnemyVisualDef resource: %s" % path)
			continue
		if visual.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		if visual.enemy_id.is_empty():
			_record_load_error("ContentCatalog enemy visual has empty enemy_id: %s" % path)
			continue
		enemy_visuals_by_enemy_id[visual.enemy_id] = visual

func _record_load_error(message: String) -> void:
	load_errors.append(message)

func _validate_ids(resource_type: String, resources: Dictionary, errors: Array[String]) -> void:
	for id in resources.keys():
		if String(id).is_empty():
			errors.append("%s has empty id" % resource_type)

func _validate_character_card_refs(errors: Array[String]) -> void:
	for character: CharacterDef in characters_by_id.values():
		for card_id in character.starting_deck_ids:
			if not cards_by_id.has(card_id):
				errors.append("Character %s starting deck references missing card %s" % [character.id, card_id])
		for card_id in character.card_pool_ids:
			if not cards_by_id.has(card_id):
				errors.append("Character %s card pool references missing card %s" % [character.id, card_id])

func _validate_locale_keys(locale_keys: Dictionary, errors: Array[String]) -> void:
	for card: CardDef in cards_by_id.values():
		_require_locale_key(card.name_key, "card %s name_key" % card.id, locale_keys, errors)
		_require_locale_key(card.description_key, "card %s description_key" % card.id, locale_keys, errors)
	for character: CharacterDef in characters_by_id.values():
		_require_locale_key(character.name_key, "character %s name_key" % character.id, locale_keys, errors)
	for enemy: EnemyDef in enemies_by_id.values():
		_require_locale_key(enemy.name_key, "enemy %s name_key" % enemy.id, locale_keys, errors)
	for relic: RelicDef in relics_by_id.values():
		_require_locale_key(relic.name_key, "relic %s name_key" % relic.id, locale_keys, errors)
		_require_locale_key(relic.description_key, "relic %s description_key" % relic.id, locale_keys, errors)
	for event: EventDef in events_by_id.values():
		_require_locale_key(event.title_key, "event %s title_key" % event.id, locale_keys, errors)
		_require_locale_key(event.body_key, "event %s body_key" % event.id, locale_keys, errors)
		for option in event.options:
			_require_locale_key(option.label_key, "event %s option %s label_key" % [event.id, option.id], locale_keys, errors)
			if not option.description_key.is_empty():
				_require_locale_key(
					option.description_key,
					"event %s option %s description_key" % [event.id, option.id],
					locale_keys,
					errors
				)

func _validate_event_options(errors: Array[String]) -> void:
	for event: EventDef in events_by_id.values():
		if event.options.is_empty():
			errors.append("Event %s has no options" % event.id)
		for option in event.options:
			if option == null:
				errors.append("Event %s has null option" % event.id)
				continue
			if option.id.is_empty():
				errors.append("Event %s has option with empty id" % event.id)
			for card_id in option.grant_card_ids:
				if not cards_by_id.has(card_id):
					errors.append("Event %s option %s references missing card %s" % [event.id, option.id, card_id])
			if not option.remove_card_id.is_empty() and not cards_by_id.has(option.remove_card_id):
				errors.append("Event %s option %s references missing remove card %s" % [event.id, option.id, option.remove_card_id])
			for relic_id in option.grant_relic_ids:
				if not relics_by_id.has(relic_id):
					errors.append("Event %s option %s references missing relic %s" % [event.id, option.id, relic_id])
			if not option.relic_reward_tier.is_empty() and get_relics_by_tier(option.relic_reward_tier).is_empty():
				errors.append("Event %s option %s references empty relic tier %s" % [event.id, option.id, option.relic_reward_tier])

func _validate_enemy_intent_displays(errors: Array[String]) -> void:
	if not enemy_intent_displays_by_id.has("unknown"):
		errors.append("Enemy intent display catalog is missing unknown fallback")
	for display: EnemyIntentDisplayDef in enemy_intent_displays_by_id.values():
		if display.intent_kind.is_empty():
			errors.append("Enemy intent display %s has empty intent_kind" % display.id)
		if display.icon_key.is_empty():
			errors.append("Enemy intent display %s has empty icon_key" % display.id)
		if display.label.is_empty():
			errors.append("Enemy intent display %s has empty label" % display.id)

func _validate_default_enemy_intent_displays(errors: Array[String]) -> void:
	var resolver := EnemyIntentDisplayResolver.new()
	for enemy: EnemyDef in enemies_by_id.values():
		for intent in enemy.intent_sequence:
			var display := resolver.resolve(intent, self)
			if not bool(display.get("is_known", false)):
				errors.append("Enemy %s intent %s has no known display" % [enemy.id, intent])

func _validate_visual_catalog(errors: Array[String]) -> void:
	if not combat_backgrounds_by_id.has("default_combat"):
		errors.append("Combat background catalog is missing default_combat fallback")
	for card: CardDef in cards_by_id.values():
		if not card_visuals_by_card_id.has(card.id):
			errors.append("Card %s has no card visual" % card.id)
	for character: CharacterDef in characters_by_id.values():
		if not visual_themes_by_character_id.has(character.id):
			errors.append("Character %s has no visual theme" % character.id)
	for enemy: EnemyDef in enemies_by_id.values():
		if not enemy_visuals_by_enemy_id.has(enemy.id):
			errors.append("Enemy %s has no enemy visual" % enemy.id)
	for visual: CardVisualDef in card_visuals_by_card_id.values():
		_validate_card_visual(visual, errors)
	for background: CombatBackgroundDef in combat_backgrounds_by_id.values():
		_validate_combat_background(background, errors)
	for theme: VisualThemeDef in visual_themes_by_character_id.values():
		_validate_visual_theme(theme, errors)
	for enemy_visual: EnemyVisualDef in enemy_visuals_by_enemy_id.values():
		_validate_enemy_visual(enemy_visual, errors)

func _validate_card_visual(visual: CardVisualDef, errors: Array[String]) -> void:
	if visual.card_id.is_empty():
		errors.append("Card visual %s has empty card_id" % visual.id)
	elif not cards_by_id.has(visual.card_id):
		errors.append("Card visual %s references missing card %s" % [visual.id, visual.card_id])
	if visual.thumbnail_path.is_empty():
		errors.append("Card visual %s has empty thumbnail_path" % visual.id)
	else:
		var texture := load(visual.thumbnail_path) as Texture2D
		if texture == null:
			errors.append("Card visual %s texture failed to load %s" % [visual.id, visual.thumbnail_path])
	if visual.frame_style.is_empty():
		errors.append("Card visual %s has empty frame_style" % visual.id)

func _validate_combat_background(background: CombatBackgroundDef, errors: Array[String]) -> void:
	if background.texture_path.is_empty():
		errors.append("Combat background %s has empty texture_path" % background.id)
	else:
		var texture := load(background.texture_path) as Texture2D
		if texture == null:
			errors.append("Combat background %s texture failed to load %s" % [background.id, background.texture_path])

func _validate_visual_theme(theme: VisualThemeDef, errors: Array[String]) -> void:
	if theme.character_id.is_empty():
		errors.append("Visual theme %s has empty character_id" % theme.id)
	elif not characters_by_id.has(theme.character_id):
		errors.append("Visual theme %s references missing character %s" % [theme.id, theme.character_id])
	if theme.default_background_id.is_empty():
		errors.append("Visual theme %s has empty default_background_id" % theme.id)
	elif not combat_backgrounds_by_id.has(theme.default_background_id):
		errors.append("Visual theme %s references missing background %s" % [theme.id, theme.default_background_id])
	if theme.card_frame_style.is_empty():
		errors.append("Visual theme %s has empty card_frame_style" % theme.id)

func _validate_enemy_visual(visual: EnemyVisualDef, errors: Array[String]) -> void:
	if visual.enemy_id.is_empty():
		errors.append("Enemy visual %s has empty enemy_id" % visual.id)
	elif not enemies_by_id.has(visual.enemy_id):
		errors.append("Enemy visual %s references missing enemy %s" % [visual.id, visual.enemy_id])
	if visual.portrait_path.is_empty():
		errors.append("Enemy visual %s has empty portrait_path" % visual.id)
	else:
		var texture := load(visual.portrait_path) as Texture2D
		if texture == null:
			errors.append("Enemy visual %s texture failed to load %s" % [visual.id, visual.portrait_path])
	if visual.frame_style.is_empty():
		errors.append("Enemy visual %s has empty frame_style" % visual.id)

func _require_locale_key(key: String, label: String, locale_keys: Dictionary, errors: Array[String]) -> void:
	if key.is_empty():
		errors.append("%s is empty" % label)
	elif not locale_keys.has(key):
		errors.append("%s missing localization key %s" % [label, key])

func _load_locale_keys(errors: Array[String]) -> Dictionary:
	var keys := {}
	var file := FileAccess.open(locale_path, FileAccess.READ)
	if file == null:
		errors.append("ContentCatalog could not open localization file: %s" % locale_path)
		return keys
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("msgid \"") and line != "msgid \"\"":
			var key := line.trim_prefix("msgid \"").trim_suffix("\"")
			keys[key] = true
	return keys
