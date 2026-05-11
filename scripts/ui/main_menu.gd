extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")
const MapGeneratorScript := preload("res://scripts/run/map_generator.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

var title_label: Label
var new_run_button: Button
var continue_button: Button
var language_toggle: Button
var current_app

func _ready() -> void:
	current_app = get_tree().root.get_node("App")
	_build_layout()
	if current_app.game.localization_service != null:
		current_app.game.localization_service.locale_changed.connect(_on_locale_changed)
	_refresh_continue_button(current_app)
	_refresh_locale_text()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "MainMenuTitle"
	title_label.position = Vector2(24, 24)
	UiStyle.apply_title(title_label)
	add_child(title_label)

	new_run_button = Button.new()
	new_run_button.name = "NewRunButton"
	new_run_button.position = Vector2(24, 60)
	UiStyle.apply_primary_button(new_run_button)
	new_run_button.pressed.connect(_on_new_run_pressed)
	add_child(new_run_button)

	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.position = Vector2(24, 108)
	UiStyle.apply_secondary_button(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

	language_toggle = Button.new()
	language_toggle.name = "LanguageToggleButton"
	language_toggle.position = Vector2(24, 152)
	UiStyle.apply_secondary_button(language_toggle)
	language_toggle.pressed.connect(_on_language_toggle_pressed)
	add_child(language_toggle)

func _refresh_locale_text() -> void:
	if title_label != null:
		title_label.text = tr("ui.main_menu.title")
	if new_run_button != null:
		new_run_button.text = tr("ui.new_run")
	if continue_button != null:
		continue_button.text = tr("ui.continue")
		continue_button.tooltip_text = tr("ui.main_menu.continue_disabled") if continue_button.disabled else ""
	if language_toggle != null:
		language_toggle.text = tr("ui.language_toggle")

func _on_locale_changed(_locale: String) -> void:
	_refresh_locale_text()

func _on_language_toggle_pressed() -> void:
	current_app.game.localization_service.toggle_locale()

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
	if _should_resume_reward(loaded_run):
		app.game.router.go_to(SceneRouterScript.REWARD)
	elif _should_resume_shop(loaded_run):
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
	continue_button.tooltip_text = tr("ui.main_menu.continue_disabled") if continue_button.disabled else ""

func _should_resume_reward(run: RunStateScript) -> bool:
	if run == null or run.current_reward_state.is_empty():
		return false
	if String(run.current_reward_state.get("source", "")) != "event":
		return false
	if String(run.current_reward_state.get("node_id", "")) != run.current_node_id:
		return false
	for node in run.map_nodes:
		if node.id == run.current_node_id:
			return node.node_type == "event"
	return false

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
