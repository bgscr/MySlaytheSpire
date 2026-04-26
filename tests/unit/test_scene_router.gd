extends RefCounted

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func test_scene_router_is_not_an_unparented_node() -> bool:
	var router = SceneRouterScript.new()
	var passed: bool = router is RefCounted and not router is Node
	assert(passed)
	return passed
