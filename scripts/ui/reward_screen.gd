extends Control

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func _ready() -> void:
	var label := Label.new()
	label.text = "奖励"
	add_child(label)

	var next := Button.new()
	next.text = "继续"
	next.position.y = 48
	next.pressed.connect(_on_next_pressed)
	add_child(next)

func _on_next_pressed() -> void:
	var app = get_tree().root.get_node("App")
	if not _unlock_next_node(app.game.current_run):
		push_error("Cannot advance run; current map node is missing.")
		return
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouterScript.SUMMARY)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _unlock_next_node(run) -> bool:
	var current_index := -1
	for i in range(run.map_nodes.size()):
		if run.map_nodes[i].id == run.current_node_id:
			current_index = i
			run.map_nodes[i].visited = true
			break
	if current_index == -1:
		return false
	if current_index + 1 < run.map_nodes.size():
		run.map_nodes[current_index + 1].unlocked = true
	else:
		run.completed = true
	return true
