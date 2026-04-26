extends SceneTree

const TEST_FILES := [
	"res://tests/unit/test_rng_service.gd",
	"res://tests/unit/test_resource_schemas.gd",
	"res://tests/unit/test_content_catalog.gd",
	"res://tests/unit/test_scene_router.gd",
	"res://tests/unit/test_map_generator.gd",
	"res://tests/unit/test_run_state.gd",
	"res://tests/unit/test_combat_engine.gd",
	"res://tests/unit/test_save_service.gd",
	"res://tests/smoke/test_scene_flow.gd",
]

var failures := 0
var started := false

func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	for file in TEST_FILES:
		if ResourceLoader.exists(file):
			_run_file(file)
	if failures > 0:
		print("TESTS FAILED: %s" % failures)
		quit(1)
	else:
		print("TESTS PASSED")
		quit(0)
	return false

func _run_file(path: String) -> void:
	var script := load(path)
	if script == null or not script.can_instantiate():
		failures += 1
		print("FAIL %s: could not load test script" % path)
		return
	var instance = script.new()
	for method in instance.get_method_list():
		var method_name := String(method.name)
		if method_name.begins_with("test_"):
			_run_method(instance, method_name, path)

func _run_method(instance, method_name: String, path: String) -> void:
	print("RUN %s:%s" % [path, method_name])
	var method_info := {}
	for method in instance.get_method_list():
		if String(method.name) == method_name:
			method_info = method
			break
	var args: Array = method_info.get("args", [])
	var result = instance.call(method_name, self) if args.size() == 1 else instance.call(method_name)
	if not result is bool:
		failures += 1
		print("FAIL %s:%s did not return bool" % [path, method_name])
	elif not result:
		failures += 1
		print("FAIL %s:%s" % [path, method_name])
