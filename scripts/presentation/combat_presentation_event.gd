class_name CombatPresentationEvent
extends RefCounted

const CombatPresentationEventScript := preload("res://scripts/presentation/combat_presentation_event.gd")

var event_type: String = ""
var source_id: String = ""
var target_id: String = ""
var card_id: String = ""
var amount: int = 0
var status_id: String = ""
var text: String = ""
var intensity: float = 1.0
var tags: Array[String] = []
var payload: Dictionary = {}

func _init(input_event_type: String = "") -> void:
	event_type = input_event_type

func copy() -> CombatPresentationEventScript:
	var copied := CombatPresentationEventScript.new(event_type)
	copied.source_id = source_id
	copied.target_id = target_id
	copied.card_id = card_id
	copied.amount = amount
	copied.status_id = status_id
	copied.text = text
	copied.intensity = intensity
	copied.tags = tags.duplicate()
	copied.payload = payload.duplicate(true)
	return copied
