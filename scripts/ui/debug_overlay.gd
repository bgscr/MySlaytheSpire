extends PanelContainer

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func _ready() -> void:
	visible = OS.is_debug_build()
	var box := VBoxContainer.new()
	add_child(box)

	var heal := Button.new()
	heal.text = "Debug: Full HP"
	heal.pressed.connect(_full_hp)
	box.add_child(heal)

	var gold := Button.new()
	gold.text = "Debug: +100 Gold"
	gold.pressed.connect(_add_gold)
	box.add_child(gold)

	var map := Button.new()
	map.text = "Debug: Map"
	map.pressed.connect(_go_map)
	box.add_child(map)

func _get_app() -> Node:
	return get_tree().root.get_node_or_null("App")

func _full_hp() -> void:
	var app := _get_app()
	if app == null:
		return
	if app.game.current_run:
		app.game.current_run.current_hp = app.game.current_run.max_hp

func _add_gold() -> void:
	var app := _get_app()
	if app == null:
		return
	if app.game.current_run:
		app.game.current_run.gold += 100

func _go_map() -> void:
	var app := _get_app()
	if app == null:
		return
	if app.game.current_run:
		app.game.router.go_to(SceneRouterScript.MAP)
