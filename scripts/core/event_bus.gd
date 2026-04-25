class_name EventBus
extends Node

const GameEvent := preload("res://scripts/core/game_event.gd")

signal event_emitted(event: GameEvent)

func emit(event_type: String, payload: Dictionary = {}) -> void:
	event_emitted.emit(GameEvent.new(event_type, payload))
