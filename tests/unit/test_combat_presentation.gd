extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const CombatPresentationAssetCatalog := preload("res://scripts/presentation/combat_presentation_asset_catalog.gd")
const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationCueResolver := preload("res://scripts/presentation/combat_presentation_cue_resolver.gd")
const CombatPresentationDelta := preload("res://scripts/presentation/combat_presentation_delta.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationIntentCueResolver := preload("res://scripts/presentation/combat_presentation_intent_cue_resolver.gd")
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

func test_resolver_uses_migrated_catalog_cues_with_card_cue_ids() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var card := catalog.get_card("sword.flash_cut")
	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "enemy:0"
	damage.amount = 4

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [damage])
	var slash := _first_event(events, "cinematic_slash")
	var camera := _first_event(events, "camera_impulse")
	var passed: bool = slash != null \
		and slash.payload.get("cue_id") == "sword.flash_cut" \
		and slash.target_id == "enemy:0" \
		and slash.tags.has("cinematic") \
		and camera != null \
		and camera.payload.get("cue_id") == "sword.flash_cut" \
		and camera.target_id == ""
	assert(passed)
	return passed

func test_resolver_uses_migrated_utility_and_status_cues() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var guard := catalog.get_card("sword.guard")
	var poison := catalog.get_card("alchemy.poison_mist")
	var guard_events := CombatPresentationCueResolver.new().resolve_card_play(guard, "player", "", [])
	var poison_events := CombatPresentationCueResolver.new().resolve_card_play(poison, "player", "enemy:0", [])
	var guard_particle := _first_event(guard_events, "particle_burst")
	var poison_particle := _first_event(poison_events, "particle_burst")
	var passed: bool = guard_particle != null \
		and guard_particle.payload.get("cue_id") == "sword.guard" \
		and guard_particle.target_id == "player" \
		and poison_particle != null \
		and poison_particle.payload.get("cue_id") == "alchemy.poison_mist" \
		and poison_particle.target_id == "enemy:0"
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

func test_config_defaults_to_full_motion_profile() -> bool:
	var config := CombatPresentationConfig.new()
	var passed: bool = config.motion_profile == CombatPresentationConfig.MOTION_PROFILE_FULL \
		and not config.is_reduced_motion()
	assert(passed)
	return passed

func test_config_set_motion_profile_validates_known_values() -> bool:
	var config := CombatPresentationConfig.new()
	config.set_motion_profile(CombatPresentationConfig.MOTION_PROFILE_REDUCED)
	var reduced_applied: bool = config.motion_profile == CombatPresentationConfig.MOTION_PROFILE_REDUCED \
		and config.is_reduced_motion()
	config.set_motion_profile("unknown_profile")
	var unknown_reset: bool = config.motion_profile == CombatPresentationConfig.MOTION_PROFILE_FULL \
		and not config.is_reduced_motion()
	var passed: bool = reduced_applied and unknown_reset
	assert(passed)
	return passed

func test_reduced_motion_filters_high_motion_events_but_keeps_low_motion_feedback() -> bool:
	var config := CombatPresentationConfig.new()
	config.set_motion_profile(CombatPresentationConfig.MOTION_PROFILE_REDUCED)
	var queue := CombatPresentationQueue.new()
	queue.config = config

	queue.enqueue(CombatPresentationEvent.new("cinematic_slash"))
	var tagged := CombatPresentationEvent.new("card_hovered")
	tagged.tags = ["cinematic"]
	queue.enqueue(tagged)
	queue.enqueue(CombatPresentationEvent.new("particle_burst"))
	queue.enqueue(CombatPresentationEvent.new("camera_impulse"))
	queue.enqueue(CombatPresentationEvent.new("slow_motion"))
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	queue.enqueue(CombatPresentationEvent.new("block_number"))
	queue.enqueue(CombatPresentationEvent.new("status_number"))
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.enqueue(CombatPresentationEvent.new("status_badge_pulse"))
	queue.enqueue(CombatPresentationEvent.new("target_highlighted"))
	queue.enqueue(CombatPresentationEvent.new("target_unhighlighted"))
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))
	queue.enqueue(CombatPresentationEvent.new("audio_cue"))

	var event_types := _event_types(queue.drain())
	var passed: bool = event_types == [
		"damage_number",
		"block_number",
		"status_number",
		"combatant_flash",
		"status_badge_pulse",
		"target_highlighted",
		"target_unhighlighted",
		"card_hovered",
		"audio_cue",
	]
	assert(passed)
	return passed

func test_reduced_motion_preserves_individual_category_toggles() -> bool:
	var config := CombatPresentationConfig.new()
	config.set_motion_profile(CombatPresentationConfig.MOTION_PROFILE_REDUCED)
	config.floating_text_enabled = false
	config.flash_enabled = false
	config.audio_cue_enabled = false
	var queue := CombatPresentationQueue.new()
	queue.config = config

	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.enqueue(CombatPresentationEvent.new("audio_cue"))
	queue.enqueue(CombatPresentationEvent.new("target_highlighted"))

	var event_types := _event_types(queue.drain())
	var passed: bool = event_types == ["target_highlighted"]
	assert(passed)
	return passed

func test_layer_plays_cinematic_slash_and_particle_assets(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var target := Button.new()
	target.position = Vector2(40, 50)
	layer.bind_target("enemy:0", target)
	layer.add_child(target)

	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.target_id = "enemy:0"
	slash.payload = {"cue_id": "sword.strike"}
	layer.play_event(slash)
	var particle := CombatPresentationEvent.new("particle_burst")
	particle.target_id = "enemy:0"
	particle.payload = {"cue_id": "alchemy.toxic_pill"}
	layer.play_event(particle)

	var slash_node := layer.get_node_or_null("CinematicSlash_0") as TextureRect
	var particle_node := layer.get_node_or_null("ParticleBurst_0_0") as TextureRect
	var passed: bool = slash_node != null \
		and slash_node.texture != null \
		and particle_node != null \
		and particle_node.texture != null \
		and layer.get_node_or_null("CinematicSlash_0") is TextureRect \
		and layer.get_node_or_null("ParticleBurst_0_0") is TextureRect
	layer.free()
	assert(passed)
	return passed

func test_layer_uses_event_fallback_assets_without_cue_id(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var target := Button.new()
	target.position = Vector2(24, 36)
	layer.bind_target("enemy:0", target)
	layer.add_child(target)

	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.target_id = "enemy:0"
	layer.play_event(slash)

	var slash_node := layer.get_node_or_null("CinematicSlash_0") as TextureRect
	var passed: bool = slash_node != null and slash_node.texture != null
	layer.free()
	assert(passed)
	return passed

func test_layer_camera_impulse_uses_catalog_and_restores_position(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	layer.position = Vector2(12, 18)
	var impulse := CombatPresentationEvent.new("camera_impulse")
	impulse.intensity = 1.5
	layer.play_event(impulse)
	var moved := layer.position == Vector2(18.0, 15.0)
	_finish_processed_tweens(tree)
	var restored := layer.position == Vector2(12, 18)
	var passed: bool = moved and restored
	layer.free()
	assert(passed)
	return passed

func test_layer_overlapping_camera_impulses_restore_original_position(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	layer.position = Vector2(12, 18)
	var first := CombatPresentationEvent.new("camera_impulse")
	first.intensity = 1.5
	layer.play_event(first)
	var second := CombatPresentationEvent.new("camera_impulse")
	second.intensity = 1.5
	layer.play_event(second)
	var did_not_stack_from_displaced_position := layer.position == Vector2(18.0, 15.0)
	_finish_processed_tweens(tree)
	var restored := layer.position == Vector2(12, 18)
	var passed: bool = did_not_stack_from_displaced_position and restored
	layer.free()
	assert(passed)
	return passed

func test_layer_plays_slow_motion_wash_and_audio_stream_without_global_timescale(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var original_time_scale := Engine.time_scale

	var slow := CombatPresentationEvent.new("slow_motion")
	slow.intensity = 0.5
	slow.payload = {"cue_id": "sword.heaven_cutting_arc"}
	layer.play_event(slow)

	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "sword.heaven_cutting_arc"}
	layer.play_event(audio)

	var wash := layer.get_node_or_null("SlowMotionWash_0") as TextureRect
	var player := layer.get_node_or_null("PresentationAudioPlayer") as AudioStreamPlayer
	var passed: bool = is_equal_approx(layer.active_slow_motion_scale, 0.45) \
		and wash != null \
		and wash.texture != null \
		and player != null \
		and player.stream != null \
		and layer.last_audio_cue_id == "sword.heaven_cutting_arc" \
		and layer.audio_cue_count == 1 \
		and is_equal_approx(Engine.time_scale, original_time_scale)
	layer.free()
	assert(passed)
	return passed

func test_layer_overlapping_slow_motion_ignores_stale_reset(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var first := CombatPresentationEvent.new("slow_motion")
	layer.play_event(first)
	var second := CombatPresentationEvent.new("slow_motion")
	second.payload = {"cue_id": "sword.heaven_cutting_arc"}
	layer.play_event(second)
	var latest_scale_applied := is_equal_approx(layer.active_slow_motion_scale, 0.45)
	for tween in tree.get_processed_tweens():
		tween.custom_step(0.36)
	var stale_reset_ignored := is_equal_approx(layer.active_slow_motion_scale, 0.45)
	_finish_processed_tweens(tree)
	var restored := is_equal_approx(layer.active_slow_motion_scale, 1.0)
	var passed: bool = latest_scale_applied and stale_reset_ignored and restored
	layer.free()
	assert(passed)
	return passed

func test_intent_cue_resolver_emits_attack_slash_and_damage_camera() -> bool:
	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "player"
	damage.amount = 6
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "attack_6"},
	], [damage])
	var slash: CombatPresentationEvent = _first_event(events, "cinematic_slash")
	var impulse: CombatPresentationEvent = _first_event(events, "camera_impulse")
	var passed: bool = slash != null \
		and slash.source_id == "enemy:0" \
		and slash.target_id == "player" \
		and slash.amount == 6 \
		and slash.payload.get("cue_id") == "enemy.attack" \
		and slash.tags.has("enemy_intent") \
		and slash.tags.has("cinematic") \
		and impulse != null \
		and impulse.target_id == "" \
		and impulse.amount == 6 \
		and impulse.payload.get("cue_id") == "enemy.attack"
	assert(passed)
	return passed

func test_intent_cue_resolver_emits_block_burst_on_actor() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:1", "target_id": "player", "intent": "block_10"},
	], [])
	var burst: CombatPresentationEvent = _first_event(events, "particle_burst")
	var passed: bool = events.size() == 1 \
		and burst != null \
		and burst.source_id == "enemy:1" \
		and burst.target_id == "enemy:1" \
		and burst.amount == 10 \
		and burst.payload.get("cue_id") == "enemy.block" \
		and burst.tags.has("block")
	assert(passed)
	return passed

func test_intent_cue_resolver_emits_player_status_burst() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "apply_status_poison_2_player"},
	], [])
	var burst: CombatPresentationEvent = _first_event(events, "particle_burst")
	var passed: bool = events.size() == 1 \
		and burst != null \
		and burst.source_id == "enemy:0" \
		and burst.target_id == "player" \
		and burst.amount == 2 \
		and burst.status_id == "poison" \
		and burst.payload.get("cue_id") == "enemy.status.poison"
	assert(passed)
	return passed

func test_intent_cue_resolver_emits_self_status_burst_and_parses_multi_token_status() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "self_status_broken_stance_1"},
	], [])
	var burst: CombatPresentationEvent = _first_event(events, "particle_burst")
	var passed: bool = events.size() == 1 \
		and burst != null \
		and burst.source_id == "enemy:0" \
		and burst.target_id == "enemy:0" \
		and burst.amount == 1 \
		and burst.status_id == "broken_stance" \
		and burst.payload.get("cue_id") == "enemy.status.broken_stance" \
		and burst.tags.has("self")
	assert(passed)
	return passed

func test_intent_cue_resolver_ignores_unknown_and_malformed_intents() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "attack_bad"},
		{"source_id": "enemy:1", "target_id": "player", "intent": "apply_status_poison_player"},
		{"source_id": "enemy:2", "target_id": "player", "intent": "wait"},
	], [])
	var passed: bool = events.is_empty()
	assert(passed)
	return passed

func test_asset_catalog_resolves_exact_cue_before_event_fallback() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var event := CombatPresentationEvent.new("particle_burst")
	event.payload = {"cue_id": "alchemy.toxic_pill"}

	var resolved := catalog.resolve(event)
	var passed: bool = resolved.get("texture_path", "") == "res://assets/presentation/textures/mist_violet.png" \
		and int(resolved.get("particle_count", 0)) == 7 \
		and is_equal_approx(float(resolved.get("radius", 0.0)), 30.0)

	resolved["texture_path"] = "res://mutated.png"
	var resolved_again := catalog.resolve(event)
	passed = passed \
		and resolved_again.get("texture_path", "") == "res://assets/presentation/textures/mist_violet.png"

	assert(passed)
	return passed

func test_asset_catalog_resolves_event_fallbacks_and_unknown_safely() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var slash := catalog.resolve(CombatPresentationEvent.new("cinematic_slash"))
	var camera := catalog.resolve(CombatPresentationEvent.new("camera_impulse"))
	var unknown := catalog.resolve(CombatPresentationEvent.new("unknown_event"))
	var audio := catalog.resolve(CombatPresentationEvent.new("audio_cue"))

	var passed: bool = slash.get("texture_path", "") == "res://assets/presentation/textures/slash_cyan.png" \
		and is_equal_approx(float(camera.get("strength", 0.0)), 4.0) \
		and is_equal_approx(float(camera.get("duration", 0.0)), 0.18) \
		and unknown.is_empty() \
		and audio.is_empty()
	assert(passed)
	return passed

func test_asset_catalog_resolves_heaven_cutting_arc_slow_and_audio_separately() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var slow := CombatPresentationEvent.new("slow_motion")
	slow.payload = {"cue_id": "sword.heaven_cutting_arc"}
	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "sword.heaven_cutting_arc"}

	var slow_asset := catalog.resolve(slow)
	var audio_asset := catalog.resolve(audio)

	var passed: bool = slow_asset.get("texture_path", "") == "res://assets/presentation/textures/slow_motion_wash.png" \
		and is_equal_approx(float(slow_asset.get("scale", 1.0)), 0.45) \
		and audio_asset.get("audio_path", "") == "res://assets/presentation/audio/spirit_impact_heavy.wav" \
		and not audio_asset.has("texture_path")
	assert(passed)
	return passed

func test_asset_catalog_resolves_enemy_intent_cues() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var attack := CombatPresentationEvent.new("cinematic_slash")
	attack.payload = {"cue_id": "enemy.attack"}
	var attack_impulse := CombatPresentationEvent.new("camera_impulse")
	attack_impulse.payload = {"cue_id": "enemy.attack"}
	var block := CombatPresentationEvent.new("particle_burst")
	block.payload = {"cue_id": "enemy.block"}
	var poison := CombatPresentationEvent.new("particle_burst")
	poison.payload = {"cue_id": "enemy.status.poison"}
	var broken := CombatPresentationEvent.new("particle_burst")
	broken.payload = {"cue_id": "enemy.status.broken_stance"}
	var focus := CombatPresentationEvent.new("particle_burst")
	focus.payload = {"cue_id": "enemy.status.sword_focus"}

	var attack_asset := catalog.resolve(attack)
	var impulse_asset := catalog.resolve(attack_impulse)
	var block_asset := catalog.resolve(block)
	var poison_asset := catalog.resolve(poison)
	var broken_asset := catalog.resolve(broken)
	var focus_asset := catalog.resolve(focus)

	var passed: bool = attack_asset.get("texture_path", "") == "res://assets/presentation/textures/slash_gold.png" \
		and float(impulse_asset.get("strength", 0.0)) > 4.0 \
		and block_asset.get("texture_path", "") == "res://assets/presentation/textures/mist_green.png" \
		and poison_asset.get("texture_path", "") == "res://assets/presentation/textures/mist_violet.png" \
		and not broken_asset.is_empty() \
		and not focus_asset.is_empty()
	assert(passed)
	return passed

func test_asset_catalog_unknown_enemy_status_uses_particle_fallback() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var event := CombatPresentationEvent.new("particle_burst")
	event.payload = {"cue_id": "enemy.status.unknown"}
	var asset := catalog.resolve(event)
	var passed: bool = asset.get("texture_path", "") == "res://assets/presentation/textures/mist_green.png" \
		and int(asset.get("particle_count", 0)) == 6
	assert(passed)
	return passed

func test_asset_catalog_registered_resources_load() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	for path in catalog.resource_paths():
		var resource := load(path)
		if resource == null:
			push_error("Presentation asset failed to load: %s" % path)
			assert(false)
			return false
	assert(true)
	return true

func test_layer_records_unmapped_audio_cue_without_stream(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)

	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "unmapped.cue"}
	layer.play_event(audio)

	var player := layer.get_node_or_null("PresentationAudioPlayer") as AudioStreamPlayer
	var passed: bool = layer.last_audio_cue_id == "unmapped.cue" \
		and layer.audio_cue_count == 1 \
		and player == null
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

func _event_types(events: Array) -> Array[String]:
	var event_types: Array[String] = []
	for event in events:
		event_types.append(String(event.event_type))
	return event_types

func _first_event(events: Array, event_type: String) -> CombatPresentationEvent:
	for event in events:
		if event.event_type == event_type:
			return event
	return null

func _finish_processed_tweens(tree: SceneTree) -> void:
	for tween in tree.get_processed_tweens():
		tween.custom_step(1.0)
