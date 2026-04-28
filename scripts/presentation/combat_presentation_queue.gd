class_name CombatPresentationQueue
extends RefCounted

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")

var config: CombatPresentationConfig
var _events: Array[CombatPresentationEvent] = []

func enqueue(event: CombatPresentationEvent) -> void:
	if event == null:
		return
	if config != null and not config.allows(event):
		return
	_events.append(event.copy())

func drain() -> Array[CombatPresentationEvent]:
	var drained := _events.duplicate()
	_events.clear()
	return drained

func clear() -> void:
	_events.clear()

func size() -> int:
	return _events.size()
