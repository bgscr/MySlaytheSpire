extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const CombatSession := preload("res://scripts/combat/combat_session.gd")

func test_session_initializes_from_run_current_node() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.cloud_step",
		"sword.focused_slash",
	])
	var session := CombatSession.new()
	session.start(catalog, run)
	var first_enemy_def: EnemyDef
	var expected_intent := ""
	if not session.state.enemies.is_empty():
		first_enemy_def = catalog.get_enemy(session.state.enemies[0].id)
		if first_enemy_def != null and not first_enemy_def.intent_sequence.is_empty():
			expected_intent = first_enemy_def.intent_sequence[0]

	var passed: bool = session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.player.id == "sword" \
		and session.state.player.max_hp == 72 \
		and session.state.player.current_hp == 65 \
		and session.state.energy == 3 \
		and session.state.turn == 1 \
		and session.state.hand.size() == 5 \
		and session.state.draw_pile.size() == 1 \
		and session.state.discard_pile.is_empty() \
		and session.state.enemies.size() >= 1 \
		and first_enemy_def != null \
		and session.get_enemy_intent(0) == expected_intent
	assert(passed)
	return passed

func test_session_invalid_when_current_node_is_missing() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("missing_node", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)

	var passed: bool = session.phase == CombatSession.PHASE_INVALID \
		and session.error_text.contains("current map node")
	assert(passed)
	return passed

func test_session_invalid_when_deck_is_empty() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [])
	var session := CombatSession.new()
	session.start(catalog, run)

	var passed: bool = session.phase == CombatSession.PHASE_INVALID \
		and session.error_text.contains("deck")
	assert(passed)
	return passed

func test_enemy_intent_returns_empty_when_intent_indices_drift() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.enemy_intent_indices.clear()

	var passed: bool = session.get_enemy_intent(0) == ""
	assert(passed)
	return passed

func _default_catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run_with_single_node(current_node_id: String, node_type: String, deck_ids: Array[String]) -> RunState:
	var run := RunState.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 65
	run.deck_ids = deck_ids
	run.current_node_id = current_node_id
	var node := MapNodeState.new("node_0", 0, node_type)
	node.unlocked = true
	run.map_nodes = [node]
	return run
