extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationCueResolver := preload("res://scripts/presentation/combat_presentation_cue_resolver.gd")
const CombatPresentationDelta := preload("res://scripts/presentation/combat_presentation_delta.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationLayer := preload("res://scripts/presentation/combat_presentation_layer.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")

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

func test_layer_ignores_float_events_without_bound_targets(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)

	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "missing"
	damage.amount = 5
	layer.play_event(damage)
	var block := CombatPresentationEvent.new("block_number")
	block.target_id = "missing"
	block.amount = 3
	layer.play_event(block)
	var status := CombatPresentationEvent.new("status_number")
	status.target_id = "missing"
	status.status_id = "poison"
	status.amount = 2
	layer.play_event(status)

	var passed: bool = layer.get_node_or_null("FloatText_0") == null
	layer.free()
	assert(passed)
	return passed

func test_layer_flash_and_status_pulse_restore_original_modulate(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var combatant_target := Label.new()
	combatant_target.modulate = Color(0.45, 0.55, 0.65, 0.75)
	layer.bind_target("player", combatant_target)
	layer.add_child(combatant_target)
	var status_target := Label.new()
	status_target.modulate = Color(0.25, 0.35, 0.45, 0.55)
	layer.bind_status_target("player", status_target)
	layer.add_child(status_target)

	var flash := CombatPresentationEvent.new("combatant_flash")
	flash.target_id = "player"
	layer.play_event(flash)
	_finish_processed_tweens(tree)
	var flash_restored := combatant_target.modulate == Color(0.45, 0.55, 0.65, 0.75)

	var pulse := CombatPresentationEvent.new("status_badge_pulse")
	pulse.target_id = "player"
	layer.play_event(pulse)
	_finish_processed_tweens(tree)
	var pulse_restored := status_target.modulate == Color(0.25, 0.35, 0.45, 0.55)

	var passed: bool = flash_restored and pulse_restored
	layer.free()
	assert(passed)
	return passed

func test_layer_card_lift_restores_original_position_y(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var card_target := Button.new()
	card_target.position = Vector2(12.0, 42.0)
	layer.bind_target("card:0", card_target)
	layer.add_child(card_target)

	var hovered := CombatPresentationEvent.new("card_hovered")
	hovered.target_id = "card:0"
	layer.play_event(hovered)
	var lifted := card_target.position.y == 34.0
	var unhovered := CombatPresentationEvent.new("card_unhovered")
	unhovered.target_id = "card:0"
	layer.play_event(unhovered)
	var restored_after_hover := card_target.position.y == 42.0

	var dragged := CombatPresentationEvent.new("card_drag_started")
	dragged.target_id = "card:0"
	layer.play_event(dragged)
	var drag_lifted := card_target.position.y == 34.0
	var released := CombatPresentationEvent.new("card_drag_released")
	released.target_id = "card:0"
	layer.play_event(released)
	var restored_after_drag := card_target.position.y == 42.0

	var passed: bool = lifted and restored_after_hover and drag_lifted and restored_after_drag
	layer.free()
	assert(passed)
	return passed

func test_cue_resolver_converts_explicit_card_cues_without_aliasing() -> bool:
	var cue := CardPresentationCueDef.new()
	cue.event_type = "cinematic_slash"
	cue.target_mode = "played_target"
	cue.amount = 2
	cue.intensity = 1.25
	cue.cue_id = "slash.explicit"
	cue.tags = ["cinematic"]
	cue.payload = {"points": [Vector2(1, 2)]}
	var card := CardDef.new()
	card.id = "sword.explicit"
	card.presentation_cues = [cue]

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [])
	cue.tags.append("mutated")
	cue.payload["points"].append(Vector2(3, 4))
	var event = events[0] if events.size() > 0 else null
	var points: Array = event.payload.get("points", []) if event != null else []
	var passed: bool = events.size() == 1 \
		and event.event_type == "cinematic_slash" \
		and event.card_id == "sword.explicit" \
		and event.target_id == "enemy:0" \
		and event.amount == 2 \
		and is_equal_approx(event.intensity, 1.25) \
		and event.tags == ["cinematic"] \
		and event.payload.get("cue_id") == "slash.explicit" \
		and points.size() == 1
	assert(passed)
	return passed

func test_cue_resolver_maps_target_modes() -> bool:
	var card := CardDef.new()
	card.id = "mode.test"
	card.presentation_cues = [
		_cue("particle_burst", "played_target"),
		_cue("camera_impulse", "source"),
		_cue("slow_motion", "player"),
		_cue("audio_cue", "none"),
	]
	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:1", [])
	var passed: bool = events.size() == 4 \
		and events[0].target_id == "enemy:1" \
		and events[1].target_id == "player" \
		and events[2].target_id == "player" \
		and events[3].target_id == ""
	assert(passed)
	return passed

func test_cue_resolver_fallback_emits_sword_slash_and_damage_camera() -> bool:
	var card := CardDef.new()
	card.id = "sword.fallback"
	card.character_id = "sword"
	card.card_type = "attack"
	var damage_effect := EffectDef.new()
	damage_effect.effect_type = "damage"
	damage_effect.amount = 6
	damage_effect.target = "enemy"
	card.effects = [damage_effect]
	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "enemy:0"
	damage.amount = 6

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [damage])
	var passed: bool = _has_event(events, "cinematic_slash", "enemy:0", 0, "") \
		and _has_event(events, "camera_impulse", "", 0, "") \
		and _event_count(events, "cinematic_slash") == 1 \
		and _event_count(events, "camera_impulse") == 1
	assert(passed)
	return passed

func test_cue_resolver_fallback_emits_alchemy_and_poison_particles() -> bool:
	var card := CardDef.new()
	card.id = "alchemy.poison_test"
	card.character_id = "alchemy"
	var poison_effect := EffectDef.new()
	poison_effect.effect_type = "apply_status"
	poison_effect.status_id = "poison"
	poison_effect.amount = 2
	poison_effect.target = "enemy"
	card.effects = [poison_effect]

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [])
	var passed: bool = _has_event(events, "particle_burst", "enemy:0", 0, "") \
		and _event_count(events, "particle_burst") == 1
	assert(passed)
	return passed

func test_cue_resolver_does_not_infer_slow_motion_or_audio() -> bool:
	var card := CardDef.new()
	card.id = "sword.no_audio"
	card.character_id = "sword"
	card.card_type = "attack"
	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [])
	var passed: bool = _event_count(events, "slow_motion") == 0 \
		and _event_count(events, "audio_cue") == 0
	assert(passed)
	return passed

func test_config_filters_polish_event_categories() -> bool:
	var config := CombatPresentationConfig.new()
	config.cinematic_enabled = false
	config.particle_enabled = false
	config.camera_impulse_enabled = false
	config.slow_motion_enabled = false
	config.audio_cue_enabled = false

	var queue := CombatPresentationQueue.new()
	queue.config = config
	queue.enqueue(CombatPresentationEvent.new("cinematic_slash"))
	queue.enqueue(CombatPresentationEvent.new("particle_burst"))
	queue.enqueue(CombatPresentationEvent.new("camera_impulse"))
	queue.enqueue(CombatPresentationEvent.new("slow_motion"))
	queue.enqueue(CombatPresentationEvent.new("audio_cue"))
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))

	var drained := queue.drain()
	var passed: bool = drained.size() == 1 and drained[0].event_type == "card_hovered"
	assert(passed)
	return passed

func test_layer_plays_cinematic_slash_and_particle_placeholders(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var target := Button.new()
	target.position = Vector2(40, 50)
	layer.bind_target("enemy:0", target)
	layer.add_child(target)

	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.target_id = "enemy:0"
	layer.play_event(slash)
	var particle := CombatPresentationEvent.new("particle_burst")
	particle.target_id = "enemy:0"
	layer.play_event(particle)

	var slash_node := layer.get_node_or_null("CinematicSlash_0")
	var particle_node := layer.get_node_or_null("ParticleBurst_0_0")
	var passed: bool = slash_node != null and particle_node != null
	layer.free()
	assert(passed)
	return passed

func test_layer_camera_impulse_restores_position(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	layer.position = Vector2(12, 18)
	var impulse := CombatPresentationEvent.new("camera_impulse")
	impulse.intensity = 1.0
	layer.play_event(impulse)
	var moved := layer.position != Vector2(12, 18)
	_finish_processed_tweens(tree)
	var restored := layer.position == Vector2(12, 18)
	var passed: bool = moved and restored
	layer.free()
	assert(passed)
	return passed

func test_layer_records_slow_motion_and_audio_cue_without_global_timescale(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var original_time_scale := Engine.time_scale

	var slow := CombatPresentationEvent.new("slow_motion")
	slow.intensity = 0.5
	layer.play_event(slow)

	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "slash.heavy"}
	layer.play_event(audio)

	var passed: bool = is_equal_approx(layer.active_slow_motion_scale, 0.5) \
		and layer.last_audio_cue_id == "slash.heavy" \
		and layer.audio_cue_count == 1 \
		and is_equal_approx(Engine.time_scale, original_time_scale)
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

func _cue(event_type: String, target_mode: String) -> CardPresentationCueDef:
	var cue := CardPresentationCueDef.new()
	cue.event_type = event_type
	cue.target_mode = target_mode
	return cue

func _event_count(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if event.event_type == event_type:
			count += 1
	return count

func _finish_processed_tweens(tree: SceneTree) -> void:
	for tween in tree.get_processed_tweens():
		tween.custom_step(1.0)
