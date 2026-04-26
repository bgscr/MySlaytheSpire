class_name ContentCatalog
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")

const DEFAULT_CARD_PATHS: Array[String] = [
	"res://resources/cards/sword/strike_sword.tres",
	"res://resources/cards/alchemy/toxic_pill.tres",
]

const DEFAULT_CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/sword_cultivator.tres",
	"res://resources/characters/alchemy_cultivator.tres",
]

const DEFAULT_ENEMY_PATHS: Array[String] = [
	"res://resources/enemies/training_puppet.tres",
	"res://resources/enemies/forest_bandit.tres",
	"res://resources/enemies/boss_heart_demon.tres",
]

const DEFAULT_RELIC_PATHS: Array[String] = [
	"res://resources/relics/jade_talisman.tres",
]

var cards_by_id: Dictionary = {}
var characters_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var relics_by_id: Dictionary = {}
var load_errors: Array[String] = []

func load_default() -> void:
	load_from_paths(DEFAULT_CARD_PATHS, DEFAULT_CHARACTER_PATHS, DEFAULT_ENEMY_PATHS, DEFAULT_RELIC_PATHS)

func load_from_paths(
	card_paths: Array[String],
	character_paths: Array[String],
	enemy_paths: Array[String],
	relic_paths: Array[String]
) -> void:
	clear()
	_load_cards(card_paths)
	_load_characters(character_paths)
	_load_enemies(enemy_paths)
	_load_relics(relic_paths)

func clear() -> void:
	cards_by_id.clear()
	characters_by_id.clear()
	enemies_by_id.clear()
	relics_by_id.clear()
	load_errors.clear()

func get_card(card_id: String) -> CardDef:
	return cards_by_id.get(card_id) as CardDef

func get_character(character_id: String) -> CharacterDef:
	return characters_by_id.get(character_id) as CharacterDef

func get_enemy(enemy_id: String) -> EnemyDef:
	return enemies_by_id.get(enemy_id) as EnemyDef

func get_relic(relic_id: String) -> RelicDef:
	return relics_by_id.get(relic_id) as RelicDef

func get_cards_for_character(character_id: String) -> Array[CardDef]:
	var result: Array[CardDef] = []
	var character := get_character(character_id)
	for card: CardDef in cards_by_id.values():
		if card.character_id == character_id:
			result.append(card)
		elif character != null and character.card_pool_ids.has(card.id):
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

func _record_load_error(message: String) -> void:
	load_errors.append(message)
