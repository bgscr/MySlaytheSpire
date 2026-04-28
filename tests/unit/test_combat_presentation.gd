extends RefCounted

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")

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

func test_queue_filters_disabled_floating_text_flash_highlight_drag_and_cinematic() -> bool:
	var config := CombatPresentationConfig.new()
	config.floating_text_enabled = false
	config.flash_enabled = false
	config.target_highlight_enabled = false
	config.drag_enabled = false
	config.cinematic_enabled = false

	var queue := CombatPresentationQueue.new()
	queue.config = config
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	queue.enqueue(CombatPresentationEvent.new("block_number"))
	queue.enqueue(CombatPresentationEvent.new("status_number"))
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.enqueue(CombatPresentationEvent.new("target_highlighted"))
	queue.enqueue(CombatPresentationEvent.new("card_drag_started"))
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
