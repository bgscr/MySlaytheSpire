extends Control

const GameScript := preload("res://scripts/app/game.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const SaveServiceScript := preload("res://scripts/save/save_service.gd")
const LocalPlatformServiceScript := preload("res://scripts/platform/local_platform_service.gd")

var game := GameScript.new()

func _ready() -> void:
	game.save_service = SaveServiceScript.new()
	game.platform_service = LocalPlatformServiceScript.new()
	add_child(game)
	game.router.setup(self)
	game.router.go_to(SceneRouterScript.MAIN_MENU)
