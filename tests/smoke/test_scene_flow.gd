extends RefCounted

const AppScene := preload("res://scenes/app/App.tscn")

func test_app_scene_instantiates() -> bool:
	var app := AppScene.instantiate()
	var passed := app != null
	assert(passed)
	if app != null:
		app.queue_free()
	return passed
