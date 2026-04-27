extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")
const MapGeneratorScript := preload("res://scripts/run/map_generator.gd")

var continue_button: Button

func _ready() -> void:
	var app = get_tree().root.get_node("App")
	var new_run := Button.new()
	new_run.name = "NewRunButton"
	new_run.text = tr("ui.new_run")
	new_run.pressed.connect(_on_new_run_pressed)
	add_child(new_run)

	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = tr("ui.continue")
	continue_button.position.y = 48
	_refresh_continue_button(app)
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

func _on_new_run_pressed() -> void:
	var app = get_tree().root.get_node("App")
	app.game.current_run = _create_minimal_run("sword", 12345)
	app.game.router.go_to(SceneRouterScript.MAP)

func _on_continue_pressed() -> void:
	var app = get_tree().root.get_node("App")
	var loaded_run = _load_continuable_run(app)
	if loaded_run == null:
		_refresh_continue_button(app)
		return
	app.game.current_run = loaded_run
	if _should_resume_shop(loaded_run):
		app.game.router.go_to(SceneRouterScript.SHOP)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _load_continuable_run(app):
	if not app.game.save_service or not app.game.save_service.has_save():
		return null
	var loaded_run = app.game.save_service.load_run()
	if loaded_run == null:
		app.game.save_service.delete_save()
		push_error("Failed to load saved run; invalid save deleted.")
		return null
	if loaded_run.failed or loaded_run.completed:
		app.game.save_service.delete_save()
		app.game.current_run = null
		return null
	return loaded_run

func _refresh_continue_button(app) -> void:
	if continue_button == null:
		return
	continue_button.disabled = not app.game.save_service or not app.game.save_service.has_save()

func _should_resume_shop(run) -> bool:
	if run == null or run.current_shop_state.is_empty():
		return false
	if String(run.current_shop_state.get("node_id", "")) != run.current_node_id:
		return false
	for node in run.map_nodes:
		if node.id == run.current_node_id:
			return node.node_type == "shop"
	return false

func _create_minimal_run(character_id: String, seed_value: int):
	var run := RunStateScript.new()
	run.seed_value = seed_value
	run.character_id = character_id
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike", "sword.strike", "sword.strike"]
	run.map_nodes = MapGeneratorScript.new().generate(seed_value)
	return run
