extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")
const MapGeneratorScript := preload("res://scripts/run/map_generator.gd")

func _ready() -> void:
	var new_run := Button.new()
	new_run.text = tr("ui.new_run")
	new_run.pressed.connect(_on_new_run_pressed)
	add_child(new_run)

	var continue_run := Button.new()
	continue_run.text = tr("ui.continue")
	continue_run.position.y = 48
	continue_run.pressed.connect(_on_continue_pressed)
	add_child(continue_run)

func _on_new_run_pressed() -> void:
	var app = get_tree().root.get_node("App")
	app.game.current_run = _create_minimal_run("sword", 12345)
	app.game.router.go_to(SceneRouterScript.MAP)

func _on_continue_pressed() -> void:
	var app = get_tree().root.get_node("App")
	if app.game.save_service and app.game.save_service.has_save():
		app.game.current_run = app.game.save_service.load_run()
		app.game.router.go_to(SceneRouterScript.MAP)

func _create_minimal_run(character_id: String, seed_value: int):
	var run := RunStateScript.new()
	run.seed_value = seed_value
	run.character_id = character_id
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike", "sword.strike", "sword.strike"]
	run.map_nodes = MapGeneratorScript.new().generate(seed_value)
	return run
