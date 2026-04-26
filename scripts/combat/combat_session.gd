class_name CombatSession
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CombatEngine := preload("res://scripts/combat/combat_engine.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EncounterGenerator := preload("res://scripts/run/encounter_generator.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

const PHASE_INVALID := "invalid"
const PHASE_PLAYER_TURN := "player_turn"
const PHASE_SELECTING_ENEMY_TARGET := "selecting_enemy_target"
const PHASE_CONFIRMING_PLAYER_TARGET := "confirming_player_target"
const PHASE_ENEMY_TURN := "enemy_turn"
const PHASE_WON := "won"
const PHASE_LOST := "lost"

var catalog: ContentCatalog
var run
var state := CombatState.new()
var engine := CombatEngine.new()
var phase := PHASE_INVALID
var error_text := ""
var pending_hand_index := -1
var pending_card: CardDef
var enemy_defs_by_id: Dictionary = {}
var enemy_intent_indices: Array[int] = []
var rng := RngService.new(1)
var terminal_rewards_applied := false

func start(input_catalog: ContentCatalog, input_run) -> void:
	catalog = input_catalog
	run = input_run
	state = CombatState.new()
	engine = CombatEngine.new()
	phase = PHASE_INVALID
	error_text = ""
	pending_hand_index = -1
	pending_card = null
	enemy_defs_by_id.clear()
	enemy_intent_indices.clear()
	rng = RngService.new(1)
	terminal_rewards_applied = false
	if run == null:
		_set_invalid("CombatSession cannot start without a run.")
		return
	if catalog == null:
		_set_invalid("CombatSession cannot start without a catalog.")
		return
	rng = RngService.new(run.seed_value).fork("combat:%s" % run.current_node_id)
	_initialize_from_run()

func get_enemy_intent(enemy_index: int) -> String:
	if enemy_index < 0 or enemy_index >= state.enemies.size():
		return ""
	var enemy := state.enemies[enemy_index]
	var enemy_def := enemy_defs_by_id.get(enemy.id) as EnemyDef
	if enemy_def == null or enemy_def.intent_sequence.is_empty():
		return ""
	var intent_index := enemy_intent_indices[enemy_index] % enemy_def.intent_sequence.size()
	return enemy_def.intent_sequence[intent_index]

func draw_cards(count: int) -> void:
	for _i in range(max(0, count)):
		if state.draw_pile.is_empty():
			if state.discard_pile.is_empty():
				return
			state.draw_pile = _shuffle_card_ids(state.discard_pile)
			state.discard_pile.clear()
		state.hand.append(state.draw_pile.pop_back())

func _initialize_from_run() -> void:
	var node = _find_current_node()
	if node == null:
		_set_invalid("CombatSession current map node is missing: %s" % run.current_node_id)
		return
	if run.deck_ids.is_empty():
		_set_invalid("CombatSession cannot start with an empty deck.")
		return
	var character := catalog.get_character(run.character_id)
	if character == null:
		_set_invalid("CombatSession character is missing: %s" % run.character_id)
		return

	state.player = CombatantState.new(run.character_id, max(1, run.max_hp))
	state.player.current_hp = clamp(run.current_hp, 0, state.player.max_hp)
	state.energy = 3
	state.turn = 1
	state.draw_pile = _shuffle_card_ids(run.deck_ids)

	var encounter_ids := EncounterGenerator.new().generate(catalog, run.seed_value, node.id, node.node_type)
	if encounter_ids.is_empty():
		_set_invalid("CombatSession encounter is empty for node: %s" % node.id)
		return
	for enemy_id in encounter_ids:
		var enemy_def := catalog.get_enemy(enemy_id)
		if enemy_def == null:
			_set_invalid("CombatSession enemy is missing: %s" % enemy_id)
			return
		enemy_defs_by_id[enemy_id] = enemy_def
		state.enemies.append(CombatantState.new(enemy_id, enemy_def.max_hp))
		enemy_intent_indices.append(0)

	draw_cards(5)
	phase = PHASE_PLAYER_TURN

func _find_current_node():
	for node in run.map_nodes:
		if node.id == run.current_node_id:
			return node
	return null

func _shuffle_card_ids(card_ids: Array[String]) -> Array[String]:
	var shuffled: Array = rng.shuffle_copy(card_ids)
	var result: Array[String] = []
	for card_id in shuffled:
		result.append(String(card_id))
	return result

func _set_invalid(message: String) -> void:
	phase = PHASE_INVALID
	error_text = message
