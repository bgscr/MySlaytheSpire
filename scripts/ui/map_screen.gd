extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func _ready() -> void:
	var label := Label.new()
	label.text = "路线地图"
	add_child(label)

	var app = get_tree().root.get_node("App")
	var y := 48
	for node in app.game.current_run.map_nodes:
		var button := Button.new()
		button.text = "%s: %s" % [node.id, node.node_type]
		button.position.y = y
		button.disabled = node.visited or not node.unlocked
		button.pressed.connect(func(): _enter_node(node))
		add_child(button)
		y += 40

func _enter_node(node) -> void:
	var app = get_tree().root.get_node("App")
	app.game.current_run.current_node_id = node.id
	if node.node_type == "combat" or node.node_type == "elite" or node.node_type == "boss":
		app.game.router.go_to(SceneRouterScript.COMBAT)
	elif node.node_type == "event":
		app.game.router.go_to(SceneRouterScript.EVENT)
	else:
		app.game.router.go_to(SceneRouterScript.REWARD)
