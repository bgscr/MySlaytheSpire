class_name GameEvent
extends RefCounted

var type: String
var payload: Dictionary

func _init(event_type: String = "", event_payload: Dictionary = {}) -> void:
	type = event_type
	payload = event_payload
