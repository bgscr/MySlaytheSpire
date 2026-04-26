extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EventBus := preload("res://scripts/core/event_bus.gd")
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

func _record_emitted_event(event: GameEvent) -> void:
	_received_event = event
