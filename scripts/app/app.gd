extends Control

const GameScript := preload("res://scripts/app/game.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var game := GameScript.new()

func _ready() -> void:
	add_child(game)
	game.router.setup(self)
	game.router.go_to(SceneRouterScript.MAIN_MENU)
