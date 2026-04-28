extends Control

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventDef := preload("res://scripts/data/event_def.gd")
const EventResolver := preload("res://scripts/event/event_resolver.gd")
const EventRunner := preload("res://scripts/event/event_runner.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var catalog: ContentCatalog
var current_event: EventDef
var runner := EventRunner.new()
var title_label: Label
var body_label: Label
var option_container: VBoxContainer
var advance_requested := false

func _ready() -> void:
	_build_layout()
	_load_event()
	_render()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "EventTitle"
	add_child(title_label)

	body_label = Label.new()
	body_label.name = "EventBody"
	body_label.position.y = 32
	add_child(body_label)

	option_container = VBoxContainer.new()
	option_container.name = "EventOptionContainer"
	option_container.position = Vector2(16, 96)
	option_container.size = Vector2(620, 360)
	add_child(option_container)

func _load_event() -> void:
	catalog = ContentCatalog.new()
	catalog.load_default()
	var app = _app()
	if app == null or app.game.current_run == null:
		current_event = null
		return
	current_event = EventResolver.new().resolve(catalog, app.game.current_run)

func _render() -> void:
	_clear_children(option_container)
	if current_event == null:
		title_label.text = "Event"
		body_label.text = "No event available"
		var button := Button.new()
		button.name = "ContinueButton"
		button.text = "Continue"
		button.pressed.connect(_on_fallback_continue_pressed)
		option_container.add_child(button)
		return
	title_label.text = tr(current_event.title_key)
	body_label.text = tr(current_event.body_key)
	for i in range(current_event.options.size()):
		_add_option_button(i)

func _add_option_button(index: int) -> void:
	var option = current_event.options[index]
	var app = _app()
	var run = app.game.current_run if app != null else null
	var button := Button.new()
	button.name = "EventOption_%s" % index
	button.text = tr(option.label_key)
	if not option.description_key.is_empty():
		button.text = "%s - %s" % [button.text, tr(option.description_key)]
	var reason := runner.unavailable_reason(run, option)
	if not reason.is_empty():
		button.text = "%s (%s)" % [button.text, reason]
	button.disabled = not runner.is_option_available(run, option)
	button.pressed.connect(func(): _on_option_pressed(index))
	option_container.add_child(button)

func _on_option_pressed(index: int) -> void:
	if advance_requested or current_event == null or index < 0 or index >= current_event.options.size():
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if not runner.apply_event_option(catalog, app.game.current_run, current_event, current_event.options[index]):
		return
	if not app.game.current_run.current_reward_state.is_empty():
		_save_and_route_to_reward(app)
		return
	_advance_and_route(app)

func _on_fallback_continue_pressed() -> void:
	if advance_requested:
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	_advance_and_route(app)

func _advance_and_route(app) -> void:
	advance_requested = true
	_set_option_buttons_disabled()
	if not RunProgression.new().advance_current_node(app.game.current_run):
		push_error("Cannot advance event; current map node is missing.")
		return
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouterScript.SUMMARY)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _save_and_route_to_reward(app) -> void:
	advance_requested = true
	_set_option_buttons_disabled()
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	app.game.router.go_to(SceneRouterScript.REWARD)

func _set_option_buttons_disabled() -> void:
	for child in option_container.get_children():
		if child is Button:
			child.disabled = true

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _app():
	return get_tree().root.get_node_or_null("App")
