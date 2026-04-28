class_name CombatPresentationConfig
extends RefCounted

var enabled := true
var drag_enabled := true
var floating_text_enabled := true
var flash_enabled := true
var target_highlight_enabled := true
var status_pulse_enabled := true
var cinematic_enabled := false

func allows(event) -> bool:
	if event == null:
		return false
	if not enabled:
		return false
	var event_type := String(event.event_type)
	if not floating_text_enabled and _is_floating_text_event(event_type):
		return false
	if not flash_enabled and event_type == "combatant_flash":
		return false
	if not status_pulse_enabled and event_type == "status_badge_pulse":
		return false
	if not target_highlight_enabled and (event_type == "target_highlighted" or event_type == "target_unhighlighted"):
		return false
	if not drag_enabled and event_type.begins_with("card_drag_"):
		return false
	if not cinematic_enabled and event.tags.has("cinematic"):
		return false
	return true

func _is_floating_text_event(event_type: String) -> bool:
	return event_type == "damage_number" \
		or event_type == "block_number" \
		or event_type == "status_number"
