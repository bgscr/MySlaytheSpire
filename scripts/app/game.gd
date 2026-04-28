class_name Game
extends Node

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var router := SceneRouterScript.new()
var current_run
var platform_service
var save_service
var presentation_config := CombatPresentationConfig.new()
