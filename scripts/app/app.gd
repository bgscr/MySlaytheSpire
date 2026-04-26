extends Control

const GameScript := preload("res://scripts/app/game.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const SaveServiceScript := preload("res://scripts/save/save_service.gd")
const LocalPlatformServiceScript := preload("res://scripts/platform/local_platform_service.gd")
const DebugOverlayScene := preload("res://scenes/dev/DebugOverlay.tscn")

var game := GameScript.new()

func _ready() -> void:
	game.save_service = SaveServiceScript.new()
	game.platform_service = LocalPlatformServiceScript.new()
	add_child(game)
	game.router.setup(self)
	game.router.go_to(SceneRouterScript.MAIN_MENU)
	if OS.is_debug_build():
		var debug_layer := CanvasLayer.new()
		debug_layer.name = "DebugLayer"
		debug_layer.layer = 100
		add_child(debug_layer)
		debug_layer.add_child(DebugOverlayScene.instantiate())
