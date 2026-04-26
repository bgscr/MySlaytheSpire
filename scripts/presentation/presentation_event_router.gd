class_name PresentationEventRouter
extends Node

const GameEventScript := preload("res://scripts/core/game_event.gd")

var camera_shake_enabled := true
var particles_enabled := true
var slow_motion_enabled := true

func handle_event(event: GameEventScript) -> void:
	match event.type:
		"card_played":
			print("Presentation card_played: %s" % event.payload)
		"damage_dealt":
			print("Presentation damage_dealt: %s" % event.payload)
