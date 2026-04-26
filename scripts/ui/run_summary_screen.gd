extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func _ready() -> void:
	var app = get_tree().root.get_node("App")
	var run = app.game.current_run
	var run_failed: bool = run != null and run.failed
	var label := Label.new()
	label.text = "失败结算" if run_failed else "通关结算"
	add_child(label)
	_clear_ended_run(app)

	var menu := Button.new()
	menu.text = "返回主菜单"
	menu.position.y = 48
	menu.pressed.connect(func(): app.game.router.go_to(SceneRouterScript.MAIN_MENU))
	add_child(menu)

func _clear_ended_run(app) -> void:
	var run = app.game.current_run
	if run == null or not (run.failed or run.completed):
		return
	if app.game.save_service:
		app.game.save_service.delete_save()
	app.game.current_run = null
