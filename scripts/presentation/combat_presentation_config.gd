class_name CombatPresentationConfig
extends RefCounted

var enabled := true
var drag_enabled := true
var floating_text_enabled := true
var flash_enabled := true
var target_highlight_enabled := true
var status_pulse_enabled := true
var cinematic_enabled := true
var particle_enabled := true
var camera_impulse_enabled := true
var slow_motion_enabled := true
var audio_cue_enabled := true

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
	if not cinematic_enabled and (event_type == "cinematic_slash" or event.tags.has("cinematic")):
		return false
	if not particle_enabled and event_type == "particle_burst":
		return false
	if not camera_impulse_enabled and event_type == "camera_impulse":
		return false
	if not slow_motion_enabled and event_type == "slow_motion":
		return false
	if not audio_cue_enabled and event_type == "audio_cue":
		return false
	return true

func _is_floating_text_event(event_type: String) -> bool:
	return event_type == "damage_number" \
		or event_type == "block_number" \
		or event_type == "status_number"
