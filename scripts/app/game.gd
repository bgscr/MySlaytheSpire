class_name Game
extends Node

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var router := SceneRouterScript.new()
var current_run
var platform_service
var save_service
var presentation_config := CombatPresentationConfig.new()
var debug_combat_sandbox_config: Dictionary = {}

func set_debug_combat_sandbox_config(config: Dictionary) -> void:
	debug_combat_sandbox_config = config.duplicate(true)

func take_debug_combat_sandbox_config() -> Dictionary:
	var config := debug_combat_sandbox_config.duplicate(true)
	debug_combat_sandbox_config.clear()
	return config
