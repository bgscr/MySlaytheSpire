extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

var title_label: Label
var node_container: VBoxContainer

func _ready() -> void:
	var app = get_tree().root.get_node("App")
	if app.game.localization_service != null:
		app.game.localization_service.locale_changed.connect(func(_locale: String): _render())
	_build_layout()
	_render()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "MapTitle"
	UiStyle.apply_title(title_label)
	add_child(title_label)
	node_container = VBoxContainer.new()
	node_container.name = "MapNodeContainer"
	node_container.position = Vector2(16, 56)
	add_child(node_container)

func _render() -> void:
	title_label.text = tr("ui.map.title")
	_clear_children(node_container)
	var app = get_tree().root.get_node("App")
	for node in app.game.current_run.map_nodes:
		var button := Button.new()
		button.name = "MapNodeButton_%s" % node.id
		button.text = tr("ui.map.node_label").format({
			"id": node.id,
			"type": tr("node_type.%s" % node.node_type),
			"state": _node_state_text(node),
		})
		button.disabled = node.visited or not node.unlocked
		UiStyle.apply_secondary_button(button)
		button.pressed.connect(func(): _enter_node(node))
		node_container.add_child(button)

func _node_state_text(node) -> String:
	if node.visited:
		return tr("ui.map.state_visited")
	if node.unlocked:
		return tr("ui.map.state_unlocked")
	return tr("ui.map.state_locked")

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _enter_node(node) -> void:
	var app = get_tree().root.get_node("App")
	app.game.current_run.current_node_id = node.id
	if node.node_type == "combat" or node.node_type == "elite" or node.node_type == "boss":
		app.game.router.go_to(SceneRouterScript.COMBAT)
	elif node.node_type == "event":
		app.game.router.go_to(SceneRouterScript.EVENT)
	elif node.node_type == "shop":
		app.game.router.go_to(SceneRouterScript.SHOP)
	else:
		app.game.router.go_to(SceneRouterScript.REWARD)
