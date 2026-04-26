extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func _ready() -> void:
	var app = get_tree().root.get_node("App")
	var label := Label.new()
	label.text = "失败结算" if app.game.current_run.failed else "通关结算"
	add_child(label)

	var menu := Button.new()
	menu.text = "返回主菜单"
	menu.position.y = 48
	menu.pressed.connect(func(): app.game.router.go_to(SceneRouterScript.MAIN_MENU))
	add_child(menu)
