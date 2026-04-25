extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")

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
