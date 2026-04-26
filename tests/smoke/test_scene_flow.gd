extends RefCounted

const AppScene := preload("res://scenes/app/App.tscn")
const DebugOverlayScene := preload("res://scenes/dev/DebugOverlay.tscn")

func test_app_scene_instantiates() -> bool:
	var app := AppScene.instantiate()
	var passed := app != null
	assert(passed)
	if app != null:
		app.free()
	return passed

func test_debug_overlay_is_anchored_away_from_main_menu_actions() -> bool:
	var debug_overlay := DebugOverlayScene.instantiate() as Control
	var passed := debug_overlay.anchor_left == 1.0 \
		and debug_overlay.anchor_right == 1.0 \
		and debug_overlay.offset_left < 0.0 \
		and debug_overlay.offset_right == 0.0
	debug_overlay.free()
	return passed
