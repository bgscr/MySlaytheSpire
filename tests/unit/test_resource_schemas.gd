extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EventBus := preload("res://scripts/core/event_bus.gd")
const EventDef := preload("res://scripts/data/event_def.gd")
const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const GameEvent := preload("res://scripts/core/game_event.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")

var _received_event = null

func test_card_def_stores_effects_and_localization_keys() -> bool:
	var effect := EffectDef.new()
	effect.effect_type = "damage"
	effect.amount = 6
	var card := CardDef.new()
	card.id = "sword.strike"
	card.name_key = "card.sword.strike.name"
	card.description_key = "card.sword.strike.desc"
	card.cost = 1
	card.effects = [effect]
	var passed := card.id == "sword.strike" \
		and card.effects[0].amount == 6 \
		and card.name_key == "card.sword.strike.name" \
		and card.description_key == "card.sword.strike.desc"
	assert(passed)
	return passed

func test_character_def_has_starting_deck() -> bool:
	var character := CharacterDef.new()
	character.id = "sword"
	character.max_hp = 72
	character.starting_deck_ids = ["sword.strike", "sword.guard"]
	var passed := character.starting_deck_ids.size() == 2
	assert(passed)
	return passed

func test_enemy_def_has_intent_sequence() -> bool:
	var enemy := EnemyDef.new()
	enemy.id = "training_puppet"
	enemy.max_hp = 24
	enemy.intent_sequence = ["attack_5", "block_4"]
	var passed := enemy.intent_sequence[0] == "attack_5"
	assert(passed)
	return passed

func test_relic_def_stores_trigger_and_effects() -> bool:
	var effect := EffectDef.new()
	effect.effect_type = "block"
	effect.amount = 3
	effect.target = "player"
	var relic := RelicDef.new()
	relic.id = "jade_guard"
	relic.name_key = "relic.jade_guard.name"
	relic.description_key = "relic.jade_guard.desc"
	relic.trigger_event = "card_played"
	relic.effects = [effect]
	var passed := relic.trigger_event == "card_played" \
		and relic.effects.size() == 1 \
		and relic.effects[0].amount == 3 \
		and relic.effects[0].target == "player"
	assert(passed)
	return passed

func test_event_bus_emits_game_event_payload() -> bool:
	_received_event = null
	var bus := EventBus.new()
	bus.event_emitted.connect(Callable(self, "_record_emitted_event"))
	bus.emit("card_played", {"card_id": "sword.strike"})
	var passed: bool = _received_event != null \
		and _received_event is GameEvent \
		and _received_event.type == "card_played" \
		and _received_event.payload.get("card_id") == "sword.strike"
	bus.free()
	assert(passed)
	return passed

func test_card_presentation_cue_def_stores_runtime_event_fields() -> bool:
	var cue := CardPresentationCueDef.new()
	cue.event_type = "cinematic_slash"
	cue.target_mode = "played_target"
	cue.amount = 3
	cue.intensity = 1.4
	cue.cue_id = "slash.test"
	cue.tags = ["cinematic"]
	cue.payload = {"color": "gold"}
	var passed: bool = cue.event_type == "cinematic_slash" \
		and cue.target_mode == "played_target" \
		and cue.amount == 3 \
		and is_equal_approx(cue.intensity, 1.4) \
		and cue.cue_id == "slash.test" \
		and cue.tags == ["cinematic"] \
		and cue.payload.get("color") == "gold"
	assert(passed)
	return passed

func test_card_def_exports_presentation_cues() -> bool:
	var cue := CardPresentationCueDef.new()
	cue.event_type = "particle_burst"
	var card := CardDef.new()
	card.id = "alchemy.test"
	card.presentation_cues = [cue]
	var passed: bool = _has_property(card, "presentation_cues") \
		and card.presentation_cues.size() == 1 \
		and card.presentation_cues[0].event_type == "particle_burst"
	assert(passed)
	return passed

func test_event_option_def_stores_requirements_and_run_deltas() -> bool:
	var option := EventOptionDef.new()
	option.id = "pay_for_treatment"
	option.label_key = "event.wandering_physician.option.pay"
	option.description_key = "event.wandering_physician.option.pay.desc"
	option.min_hp = 0
	option.min_gold = 25
	option.hp_delta = 12
	option.gold_delta = -25
	var passed: bool = option.id == "pay_for_treatment" \
		and option.min_gold == 25 \
		and option.hp_delta == 12 \
		and option.gold_delta == -25
	assert(passed)
	return passed

func test_event_def_stores_localization_weight_and_options() -> bool:
	var option := EventOptionDef.new()
	option.id = "decline"
	var event := EventDef.new()
	event.id = "wandering_physician"
	event.title_key = "event.wandering_physician.title"
	event.body_key = "event.wandering_physician.body"
	event.event_weight = 10
	event.options = [option]
	var passed: bool = event.id == "wandering_physician" \
		and event.title_key == "event.wandering_physician.title" \
		and event.body_key == "event.wandering_physician.body" \
		and event.event_weight == 10 \
		and event.options.size() == 1 \
		and event.options[0].id == "decline"
	assert(passed)
	return passed

func test_content_schema_exports_pool_metadata() -> bool:
	var card := CardDef.new()
	var enemy := EnemyDef.new()
	var relic := RelicDef.new()
	var passed := _has_property(card, "character_id") \
		and _has_property(card, "pool_tags") \
		and _has_property(card, "reward_weight") \
		and _has_property(enemy, "tier") \
		and _has_property(enemy, "encounter_weight") \
		and _has_property(enemy, "gold_reward_min") \
		and _has_property(enemy, "gold_reward_max") \
		and _has_property(relic, "tier") \
		and _has_property(relic, "reward_weight")
	assert(passed)
	return passed

func _record_emitted_event(event: GameEvent) -> void:
	_received_event = event

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.name) == property_name:
			return true
	return false
