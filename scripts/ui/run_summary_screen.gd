extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

func _ready() -> void:
	var app = get_tree().root.get_node("App")
	var run = app.game.current_run
	var run_failed: bool = run != null and run.failed
	var label := Label.new()
	label.name = "RunSummaryTitle"
	label.text = tr("ui.summary.defeat") if run_failed else tr("ui.summary.victory")
	UiStyle.apply_title(label)
	add_child(label)

	var stats := Label.new()
	stats.name = "RunSummaryStats"
	stats.text = tr("ui.summary.stats")
	stats.position.y = 28
	UiStyle.apply_body_label(stats)
	add_child(stats)

	_clear_ended_run(app)

	var menu := Button.new()
	menu.name = "RunSummaryMenuButton"
	menu.text = tr("ui.summary.return_menu")
	menu.position.y = 48
	UiStyle.apply_primary_button(menu)
	menu.pressed.connect(func(): app.game.router.go_to(SceneRouterScript.MAIN_MENU))
	add_child(menu)

func _clear_ended_run(app) -> void:
	var run = app.game.current_run
	if run == null or not (run.failed or run.completed):
		return
	if app.game.save_service:
		app.game.save_service.delete_save()
	app.game.current_run = null
