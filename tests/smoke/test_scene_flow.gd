extends RefCounted

const AppScene := preload("res://scenes/app/App.tscn")
const DebugOverlayScene := preload("res://scenes/dev/DebugOverlay.tscn")
const CardDefScript := preload("res://scripts/data/card_def.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")
const SaveServiceScript := preload("res://scripts/save/save_service.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func test_app_scene_instantiates(tree: SceneTree) -> bool:
	var app := AppScene.instantiate()
	tree.root.add_child(app)
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

func test_failed_run_summary_clears_save(tree: SceneTree) -> bool:
	return _run_summary_clears_save(tree, true, false, "user://test_failed_summary_save.json")

func test_completed_run_summary_clears_save(tree: SceneTree) -> bool:
	return _run_summary_clears_save(tree, false, true, "user://test_completed_summary_save.json")

func test_main_menu_disables_continue_without_save(tree: SceneTree) -> bool:
	var save_path := "user://test_no_continue_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var main_menu = app.game.router.go_to(SceneRouterScript.MAIN_MENU)
	var continue_button := _find_continue_button(main_menu)
	var passed: bool = continue_button != null and continue_button.disabled
	app.free()
	_delete_test_save(save_path)
	return passed

func test_main_menu_rejects_terminal_save(tree: SceneTree) -> bool:
	return _main_menu_rejects_terminal_save(tree, true, false, "user://test_failed_terminal_continue_save.json")

func test_main_menu_rejects_completed_save(tree: SceneTree) -> bool:
	return _main_menu_rejects_terminal_save(tree, false, true, "user://test_completed_terminal_continue_save.json")

func test_combat_screen_creates_session_and_cancels_pending_card(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_screen_session_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut", "sword.qi_surge", "sword.cloud_step"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var enemy_container: Node = combat.get_node_or_null("EnemyContainer")
	var hand_container: Node = combat.get_node_or_null("HandContainer")
	var cancel_button := combat.get_node_or_null("CancelSelectionButton") as Button
	var end_turn_button := combat.get_node_or_null("EndTurnButton") as Button
	var first_card: Button = hand_container.get_child(0) as Button if hand_container != null and hand_container.get_child_count() > 0 else null
	var first_card_has_type := false
	if first_card != null and combat.session.state.hand.size() > 0:
		var first_card_id: String = combat.session.state.hand[0]
		var first_card_def: CardDefScript = combat.session.catalog.get_card(first_card_id)
		first_card_has_type = first_card_def != null and first_card.text.contains(first_card_def.card_type)
	if first_card != null:
		first_card.pressed.emit()
	var pending_phase: bool = combat.session.phase == "selecting_enemy_target" \
		or combat.session.phase == "confirming_player_target"
	if cancel_button != null:
		cancel_button.pressed.emit()

	var passed: bool = combat.session != null \
		and enemy_container != null \
		and enemy_container.get_child_count() >= 1 \
		and hand_container != null \
		and hand_container.get_child_count() >= 1 \
		and end_turn_button != null \
		and cancel_button != null \
		and first_card_has_type \
		and pending_phase \
		and combat.session.phase == "player_turn"
	app.free()
	_delete_test_save("user://test_combat_screen_session_save.json")
	return passed

func _main_menu_rejects_terminal_save(tree: SceneTree, failed: bool, completed: bool, save_path: String) -> bool:
	var app = _create_app_with_save_service(tree, save_path)

	var run := RunStateScript.new()
	run.failed = failed
	run.completed = completed
	app.game.save_service.save_run(run)

	var main_menu = app.game.router.go_to(SceneRouterScript.MAIN_MENU)
	var continue_button := _find_continue_button(main_menu)
	var continue_was_enabled: bool = continue_button != null and not continue_button.disabled
	if continue_button != null:
		continue_button.pressed.emit()

	var passed: bool = continue_was_enabled \
		and app.game.save_service.has_save() == false \
		and app.game.current_run == null \
		and app.game.router.current_scene == main_menu \
		and continue_button.disabled
	app.free()
	_delete_test_save(save_path)
	return passed

func _run_summary_clears_save(tree: SceneTree, failed: bool, completed: bool, save_path: String) -> bool:
	var app = _create_app_with_save_service(tree, save_path)

	var run := RunStateScript.new()
	run.failed = failed
	run.completed = completed
	app.game.current_run = run
	app.game.save_service.save_run(run)

	app.game.router.go_to(SceneRouterScript.SUMMARY)
	var passed: bool = app.game.save_service.has_save() == false \
		and app.game.current_run == null
	app.free()
	_delete_test_save(save_path)
	return passed

func _create_app_with_save_service(tree: SceneTree, save_path: String):
	_delete_test_save(save_path)
	var app := AppScene.instantiate()
	tree.root.add_child(app)
	app.game.save_service = SaveServiceScript.new(save_path)
	return app

func _find_continue_button(menu: Node) -> Button:
	return menu.get_node_or_null("ContinueButton") as Button

func _delete_test_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
