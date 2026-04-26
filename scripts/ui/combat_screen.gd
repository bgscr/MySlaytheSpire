extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func _ready() -> void:
	var label := Label.new()
	label.text = "战斗"
	add_child(label)

	var win := Button.new()
	win.text = "模拟胜利"
	win.position.y = 48
	win.pressed.connect(_on_win_pressed)
	add_child(win)

	var lose := Button.new()
	lose.text = "模拟失败"
	lose.position.y = 96
	lose.pressed.connect(_on_lose_pressed)
	add_child(lose)

func _on_win_pressed() -> void:
	var app = get_tree().root.get_node("App")
	app.game.router.go_to(SceneRouterScript.REWARD)

func _on_lose_pressed() -> void:
	var app = get_tree().root.get_node("App")
	app.game.current_run.failed = true
	app.game.router.go_to(SceneRouterScript.SUMMARY)
