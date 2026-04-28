class_name CombatPresentationLayer
extends Control

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")

const FLOAT_DURATION := 0.55
const FLASH_COLOR := Color(1.0, 0.92, 0.72)
const HIGHLIGHT_COLOR := Color(1.0, 0.82, 0.35)
const PULSE_COLOR := Color(0.58, 0.86, 0.82)
const SLASH_DURATION := 0.32
const PARTICLE_DURATION := 0.42
const CAMERA_IMPULSE_DURATION := 0.18
const SLOW_MOTION_DURATION := 0.35
const SLASH_COLOR := Color(0.9, 0.96, 1.0, 0.9)
const PARTICLE_COLOR := Color(0.46, 0.92, 0.66, 0.85)

var queue: CombatPresentationQueue
var targets := {}
var status_targets := {}
var _card_base_positions := {}
var _float_index := 0
var active_slow_motion_scale: float = 1.0
var last_audio_cue_id: String = ""
var audio_cue_count: int = 0
var _slash_index := 0
var _particle_burst_index := 0
var _camera_base_position := Vector2.ZERO

func bind_target(target_id: String, node: Control) -> void:
	if target_id.is_empty() or node == null:
		return
	targets[target_id] = node

func bind_status_target(target_id: String, node: Control) -> void:
	if target_id.is_empty() or node == null:
		return
	status_targets[target_id] = node

func clear_bindings() -> void:
	targets.clear()
	status_targets.clear()
	_card_base_positions.clear()

func process_queue() -> void:
	if queue == null:
		return
	for event in queue.drain():
		play_event(event)

func play_event(event: CombatPresentationEvent) -> void:
	if event == null:
		return
	match event.event_type:
		"damage_number":
			_show_float_text(event, "-%s" % event.amount, Color(0.86, 0.28, 0.24))
		"block_number":
			_show_float_text(event, "+%s Block" % event.amount, Color(0.36, 0.62, 0.92))
		"status_number":
			_show_float_text(event, _status_text(event), Color(0.42, 0.72, 0.48))
		"combatant_flash":
			_flash_target(event.target_id)
		"status_badge_pulse":
			_pulse_status(event.target_id)
		"target_highlighted":
			_set_highlight(event.target_id, true)
		"target_unhighlighted":
			_set_highlight(event.target_id, false)
		"card_hovered", "card_drag_started":
			_set_card_lift(event.target_id, true)
		"card_unhovered", "card_drag_released":
			_set_card_lift(event.target_id, false)
		"cinematic_slash":
			_show_cinematic_slash(event)
		"particle_burst":
			_show_particle_burst(event)
		"camera_impulse":
			_play_camera_impulse(event)
		"slow_motion":
			_record_slow_motion(event)
		"audio_cue":
			_record_audio_cue(event)

func _show_float_text(event: CombatPresentationEvent, text: String, color: Color) -> void:
	if not targets.has(event.target_id):
		return
	var label := Label.new()
	label.name = "FloatText_%s" % _float_index
	_float_index += 1
	label.text = text
	label.modulate = color
	label.position = _target_position(event.target_id) + Vector2(0.0, -24.0)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, FLOAT_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION)
	tween.finished.connect(label.queue_free)

func _flash_target(target_id: String) -> void:
	var target := targets.get(target_id) as Control
	if target == null:
		return
	var original_modulate := target.modulate
	target.modulate = FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(target, "modulate", original_modulate, FLOAT_DURATION)

func _pulse_status(target_id: String) -> void:
	var target := status_targets.get(target_id, targets.get(target_id)) as Control
	if target == null:
		return
	var original_modulate := target.modulate
	target.modulate = PULSE_COLOR
	var tween := create_tween()
	tween.tween_property(target, "modulate", original_modulate, FLOAT_DURATION)

func _set_highlight(target_id: String, enabled: bool) -> void:
	var target := targets.get(target_id) as Control
	if target == null:
		return
	if enabled:
		target.add_theme_color_override("font_color", HIGHLIGHT_COLOR)
	else:
		target.remove_theme_color_override("font_color")

func _set_card_lift(target_id: String, enabled: bool) -> void:
	var target := targets.get(target_id) as Control
	if target == null:
		return
	if enabled:
		if not _card_base_positions.has(target_id):
			_card_base_positions[target_id] = target.position
		var base_position := _card_base_positions[target_id] as Vector2
		target.position = base_position + Vector2(0.0, -8.0)
	elif _card_base_positions.has(target_id):
		target.position = _card_base_positions[target_id]
		_card_base_positions.erase(target_id)

func _target_position(target_id: String) -> Vector2:
	var target := targets.get(target_id) as Control
	if target == null:
		return Vector2.ZERO
	if target.is_inside_tree() and is_inside_tree():
		return target.global_position - global_position
	return target.position

func _status_text(event: CombatPresentationEvent) -> String:
	if not event.text.is_empty():
		return event.text
	var prefix := "+" if event.amount > 0 else ""
	if event.status_id.is_empty():
		return "%s%s Status" % [prefix, event.amount]
	return "%s%s %s" % [prefix, event.amount, event.status_id]

func _show_cinematic_slash(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var slash := ColorRect.new()
	slash.name = "CinematicSlash_%s" % _slash_index
	_slash_index += 1
	slash.color = SLASH_COLOR
	slash.size = Vector2(74.0, 4.0)
	slash.pivot_offset = slash.size * 0.5
	slash.rotation = -0.55
	slash.position = _target_position(event.target_id) + Vector2(-20.0, -18.0)
	add_child(slash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "position:x", slash.position.x + 28.0, SLASH_DURATION)
	tween.tween_property(slash, "modulate:a", 0.0, SLASH_DURATION)
	tween.finished.connect(slash.queue_free)

func _show_particle_burst(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var burst_index := _particle_burst_index
	_particle_burst_index += 1
	var origin := _target_position(event.target_id) + Vector2(12.0, -10.0)
	for particle_index in range(5):
		var particle := ColorRect.new()
		particle.name = "ParticleBurst_%s_%s" % [burst_index, particle_index]
		particle.color = PARTICLE_COLOR
		particle.size = Vector2(5.0, 5.0)
		particle.position = origin
		add_child(particle)
		var angle := TAU * float(particle_index) / 5.0
		var offset := Vector2(cos(angle), sin(angle)) * 24.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", origin + offset, PARTICLE_DURATION)
		tween.tween_property(particle, "modulate:a", 0.0, PARTICLE_DURATION)
		tween.finished.connect(particle.queue_free)

func _play_camera_impulse(event: CombatPresentationEvent) -> void:
	_camera_base_position = position
	var strength := 4.0 * maxf(0.25, event.intensity)
	position = _camera_base_position + Vector2(strength, -strength * 0.5)
	var tween := create_tween()
	tween.tween_property(self, "position", _camera_base_position, CAMERA_IMPULSE_DURATION)

func _record_slow_motion(event: CombatPresentationEvent) -> void:
	active_slow_motion_scale = clampf(event.intensity, 0.1, 1.0)
	var tween := create_tween()
	tween.tween_interval(SLOW_MOTION_DURATION)
	tween.tween_callback(func(): active_slow_motion_scale = 1.0)

func _record_audio_cue(event: CombatPresentationEvent) -> void:
	last_audio_cue_id = String(event.payload.get("cue_id", event.text))
	audio_cue_count += 1
