class_name CombatPresentationLayer
extends Control

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")

const FLOAT_DURATION := 0.55
const FLASH_COLOR := Color(1.0, 0.92, 0.72)
const HIGHLIGHT_COLOR := Color(1.0, 0.82, 0.35)
const PULSE_COLOR := Color(0.58, 0.86, 0.82)

var queue: CombatPresentationQueue
var targets := {}
var status_targets := {}
var _float_index := 0

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
	target.modulate = FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color.WHITE, FLOAT_DURATION)

func _pulse_status(target_id: String) -> void:
	var target := status_targets.get(target_id, targets.get(target_id)) as Control
	if target == null:
		return
	target.modulate = PULSE_COLOR
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color.WHITE, FLOAT_DURATION)

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
	target.position.y = -8.0 if enabled else 0.0

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
