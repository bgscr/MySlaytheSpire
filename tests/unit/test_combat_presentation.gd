extends RefCounted

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationDelta := preload("res://scripts/presentation/combat_presentation_delta.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationLayer := preload("res://scripts/presentation/combat_presentation_layer.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func test_event_copy_does_not_alias_payload_or_tags() -> bool:
	var event := CombatPresentationEvent.new("damage_number")
	event.target_id = "enemy:0"
	event.amount = 7
	event.tags = ["cinematic"]
	event.payload = {"points": [Vector2(1, 2)]}
	var copied := event.copy()
	event.tags.append("mutated")
	event.payload["points"].append(Vector2(3, 4))

	var copied_points: Array = copied.payload.get("points", [])
	var passed: bool = copied.event_type == "damage_number" \
		and copied.target_id == "enemy:0" \
		and copied.amount == 7 \
		and copied.tags == ["cinematic"] \
		and copied_points.size() == 1
	assert(passed)
	return passed

func test_queue_drains_fifo_and_clears() -> bool:
	var queue := CombatPresentationQueue.new()
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	var drained := queue.drain()
	var empty_after_drain := queue.size() == 0
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.clear()
	var passed: bool = drained.size() == 2 \
		and drained[0].event_type == "card_hovered" \
		and drained[1].event_type == "damage_number" \
		and empty_after_drain \
		and queue.size() == 0
	assert(passed)
	return passed

func test_queue_enqueue_copies_event_without_aliasing_original() -> bool:
	var queue := CombatPresentationQueue.new()
	var event := CombatPresentationEvent.new("damage_number")
	event.target_id = "enemy:0"
	event.amount = 9
	event.tags = ["impact"]
	event.payload = {"points": [Vector2(5, 6)]}
	queue.enqueue(event)

	event.target_id = "enemy:1"
	event.amount = 99
	event.tags.append("mutated")
	event.payload["points"].append(Vector2(7, 8))

	var drained := queue.drain()
	var queued_event = drained[0] if drained.size() > 0 else null
	var queued_points: Array = queued_event.payload.get("points", []) if queued_event != null else []
	var passed: bool = drained.size() == 1 \
		and queued_event.event_type == "damage_number" \
		and queued_event.target_id == "enemy:0" \
		and queued_event.amount == 9 \
		and queued_event.tags == ["impact"] \
		and queued_points.size() == 1
	assert(passed)
	return passed

func test_queue_filters_disabled_floating_text_flash_highlight_drag_and_cinematic() -> bool:
	var config := CombatPresentationConfig.new()
	config.floating_text_enabled = false
	config.flash_enabled = false
	config.target_highlight_enabled = false
	config.drag_enabled = false
	config.status_pulse_enabled = false
	config.cinematic_enabled = false

	var queue := CombatPresentationQueue.new()
	queue.config = config
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	queue.enqueue(CombatPresentationEvent.new("block_number"))
	queue.enqueue(CombatPresentationEvent.new("status_number"))
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.enqueue(CombatPresentationEvent.new("target_highlighted"))
	queue.enqueue(CombatPresentationEvent.new("card_drag_started"))
	queue.enqueue(CombatPresentationEvent.new("status_badge_pulse"))
	var cinematic := CombatPresentationEvent.new("cinematic_slash")
	cinematic.tags = ["cinematic"]
	queue.enqueue(cinematic)
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))

	var drained := queue.drain()
	var passed: bool = drained.size() == 1 and drained[0].event_type == "card_hovered"
	assert(passed)
	return passed

func test_queue_drops_all_events_when_disabled() -> bool:
	var config := CombatPresentationConfig.new()
	config.enabled = false
	var queue := CombatPresentationQueue.new()
	queue.config = config
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	var passed: bool = queue.size() == 0
	assert(passed)
	return passed

func test_delta_emits_damage_flash_block_status_and_pulse_events() -> bool:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.player.current_hp = 50
	state.player.block = 1
	state.player.statuses = {"poison": 1}
	state.enemies = [CombatantState.new("enemy_a", 30)]
	state.enemies[0].current_hp = 30
	state.enemies[0].block = 0
	state.enemies[0].statuses = {}

	var delta := CombatPresentationDelta.new()
	var before := delta.capture_state(state)

	state.player.current_hp = 44
	state.player.block = 5
	state.player.statuses["poison"] = 3
	state.enemies[0].current_hp = 21
	state.enemies[0].statuses["broken_stance"] = 2

	var events := delta.events_between(before, state)
	var passed: bool = _has_event(events, "damage_number", "player", 6, "") \
		and _has_event(events, "combatant_flash", "player", 0, "") \
		and _has_event(events, "block_number", "player", 4, "") \
		and _has_event(events, "status_number", "player", 2, "poison") \
		and _has_event(events, "status_badge_pulse", "player", 0, "poison") \
		and _has_event(events, "damage_number", "enemy:0", 9, "") \
		and _has_event(events, "combatant_flash", "enemy:0", 0, "") \
		and _has_event(events, "status_number", "enemy:0", 2, "broken_stance") \
		and _has_event(events, "status_badge_pulse", "enemy:0", 0, "broken_stance")
	assert(passed)
	return passed

func test_delta_ignores_unchanged_hp_block_and_status_values() -> bool:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.player.block = 2
	state.player.statuses = {"poison": 1}
	var delta := CombatPresentationDelta.new()
	var before := delta.capture_state(state)
	var events := delta.events_between(before, state)
	var passed: bool = events.is_empty()
	assert(passed)
	return passed

func test_initial_state_events_report_starting_block_and_statuses() -> bool:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.player.block = 4
	state.player.statuses = {"sword_focus": 2}
	state.enemies = [CombatantState.new("enemy_a", 30)]
	state.enemies[0].block = 3
	var delta := CombatPresentationDelta.new()
	var events := delta.events_from_initial_state(state)
	var passed: bool = _has_event(events, "block_number", "player", 4, "") \
		and _has_event(events, "status_number", "player", 2, "sword_focus") \
		and _has_event(events, "status_badge_pulse", "player", 0, "sword_focus") \
		and _has_event(events, "block_number", "enemy:0", 3, "")
	assert(passed)
	return passed

func test_layer_processes_queue_into_feedback_nodes(tree: SceneTree) -> bool:
	var queue := CombatPresentationQueue.new()
	var layer := CombatPresentationLayer.new()
	layer.queue = queue
	layer.name = "PresentationLayer"
	tree.root.add_child(layer)
	var player_target := Label.new()
	player_target.name = "PlayerTarget"
	layer.bind_target("player", player_target)
	layer.add_child(player_target)

	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "player"
	damage.amount = 5
	queue.enqueue(damage)
	var flash := CombatPresentationEvent.new("combatant_flash")
	flash.target_id = "player"
	queue.enqueue(flash)
	layer.process_queue()

	var float_text := layer.get_node_or_null("FloatText_0") as Label
	var passed: bool = float_text != null \
		and float_text.text == "-5" \
		and player_target.modulate != Color.WHITE
	layer.free()
	assert(passed)
	return passed

func test_layer_target_highlight_applies_and_clears(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var enemy_target := Button.new()
	layer.bind_target("enemy:0", enemy_target)
	layer.add_child(enemy_target)
	var highlighted := CombatPresentationEvent.new("target_highlighted")
	highlighted.target_id = "enemy:0"
	layer.play_event(highlighted)
	var has_highlight := enemy_target.has_theme_color_override("font_color")
	var cleared := CombatPresentationEvent.new("target_unhighlighted")
	cleared.target_id = "enemy:0"
	layer.play_event(cleared)
	var passed: bool = has_highlight and not enemy_target.has_theme_color_override("font_color")
	layer.free()
	assert(passed)
	return passed

func _has_event(events: Array, event_type: String, target_id: String, amount: int, status_id: String) -> bool:
	for event in events:
		if event.event_type != event_type:
			continue
		if event.target_id != target_id:
			continue
		if amount != 0 and event.amount != amount:
			continue
		if not status_id.is_empty() and event.status_id != status_id:
			continue
		return true
	return false
