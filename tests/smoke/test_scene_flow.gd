extends RefCounted

const AppScene := preload("res://scenes/app/App.tscn")
const DebugOverlayScene := preload("res://scenes/dev/DebugOverlay.tscn")
const CardDefScript := preload("res://scripts/data/card_def.gd")
const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")
const EventResolverScript := preload("res://scripts/event/event_resolver.gd")
const MapNodeStateScript := preload("res://scripts/run/map_node_state.gd")
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

func test_reward_screen_claims_card_skips_gold_and_saves_on_continue(tree: SceneTree) -> bool:
	var save_path := "user://test_reward_screen_claim_skip_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("combat", true)
	var deck_size_before := run.deck_ids.size()
	var gold_before := run.gold
	app.game.current_run = run

	var reward_screen = app.game.router.go_to(SceneRouterScript.REWARD)
	var continue_button := _find_node_by_name(reward_screen, "ContinueButton") as Button
	var card_button := _find_node_by_name(reward_screen, "ClaimCard_0_0") as Button
	var disabled_before: bool = continue_button != null and continue_button.disabled
	if card_button != null:
		card_button.pressed.emit()
	var deck_claimed: bool = run.deck_ids.size() == deck_size_before + 1
	var still_disabled_after_card: bool = continue_button != null and continue_button.disabled
	var skip_gold := _find_node_by_name(reward_screen, "SkipReward_1") as Button
	if skip_gold != null:
		skip_gold.pressed.emit()
	var enabled_after_all_resolved: bool = continue_button != null and not continue_button.disabled
	if continue_button != null:
		continue_button.pressed.emit()
	var routed_scene = app.game.router.current_scene
	var disabled_after_continue: bool = continue_button != null and continue_button.disabled
	if continue_button != null:
		continue_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = disabled_before \
		and deck_claimed \
		and still_disabled_after_card \
		and enabled_after_all_resolved \
		and disabled_after_continue \
		and run.gold == gold_before \
		and loaded_run != null \
		and loaded_run.deck_ids.size() == run.deck_ids.size() \
		and loaded_run.gold == gold_before \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and routed_scene != reward_screen \
		and app.game.router.current_scene == routed_scene
	app.free()
	_delete_test_save(save_path)
	return passed

func test_reward_screen_can_claim_boss_relic_and_skip_remaining_rewards(tree: SceneTree) -> bool:
	var save_path := "user://test_reward_screen_relic_claim_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("boss", false)
	app.game.current_run = run

	var reward_screen = app.game.router.go_to(SceneRouterScript.REWARD)
	var skip_card := _find_node_by_name(reward_screen, "SkipReward_0") as Button
	var skip_gold := _find_node_by_name(reward_screen, "SkipReward_1") as Button
	var claim_relic := _find_node_by_name(reward_screen, "ClaimRelic_2") as Button
	if skip_card != null:
		skip_card.pressed.emit()
	skip_gold = _find_node_by_name(reward_screen, "SkipReward_1") as Button
	if skip_gold != null:
		skip_gold.pressed.emit()
	claim_relic = _find_node_by_name(reward_screen, "ClaimRelic_2") as Button
	if claim_relic != null:
		claim_relic.pressed.emit()
	var continue_button := _find_node_by_name(reward_screen, "ContinueButton") as Button
	var passed: bool = claim_relic != null \
		and run.relic_ids.size() == 1 \
		and not run.relic_ids[0].is_empty() \
		and continue_button != null \
		and not continue_button.disabled
	app.free()
	_delete_test_save(save_path)
	return passed

func test_map_event_node_routes_to_event_screen(tree: SceneTree) -> bool:
	var save_path := "user://test_event_route_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	app.game.current_run = run
	var map_screen = app.game.router.go_to(SceneRouterScript.MAP)
	var event_button := _find_node_by_text(map_screen, "node_0: event") as Button
	if event_button != null:
		event_button.pressed.emit()
	var passed: bool = event_button != null \
		and app.game.router.current_scene != null \
		and app.game.router.current_scene.name == "EventScreen"
	app.free()
	_delete_test_save(save_path)
	return passed

func test_event_screen_option_applies_saves_and_advances(tree: SceneTree) -> bool:
	var save_path := "user://test_event_screen_apply_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	run.seed_value = 1
	run.current_hp = 20
	run.max_hp = 40
	run.gold = 50
	app.game.current_run = run
	var event_screen = app.game.router.go_to(SceneRouterScript.EVENT)
	var option_button := _find_node_by_name(event_screen, "EventOption_0") as Button
	if option_button != null:
		option_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = option_button != null \
		and loaded_run != null \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != event_screen
	app.free()
	_delete_test_save(save_path)
	return passed

func test_event_screen_disables_unavailable_option(tree: SceneTree) -> bool:
	var save_path := "user://test_event_screen_disabled_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	run.seed_value = _seed_for_event_with_unavailable_option()
	run.current_hp = 1
	run.max_hp = 40
	run.gold = 0
	app.game.current_run = run
	var event_screen = app.game.router.go_to(SceneRouterScript.EVENT)
	var disabled_button := _first_disabled_event_option(event_screen)
	var passed: bool = disabled_button != null and disabled_button.disabled
	app.free()
	_delete_test_save(save_path)
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

func _reward_run(node_type: String, include_next_node: bool) -> RunStateScript:
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.gold = 10
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	run.current_node_id = "node_0"
	var current := MapNodeStateScript.new("node_0", 0, node_type)
	current.unlocked = true
	var nodes: Array = [current]
	if include_next_node:
		nodes.append(MapNodeStateScript.new("node_1", 1, "combat"))
	run.map_nodes = nodes
	return run

func _find_continue_button(menu: Node) -> Button:
	return menu.get_node_or_null("ContinueButton") as Button

func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null

func _find_node_by_text(root: Node, text: String) -> Node:
	if root == null:
		return null
	if root is Button and (root as Button).text == text:
		return root
	for child in root.get_children():
		var found := _find_node_by_text(child, text)
		if found != null:
			return found
	return null

func _first_disabled_event_option(root: Node) -> Button:
	if root == null:
		return null
	if root is Button and root.name.begins_with("EventOption_") and (root as Button).disabled:
		return root as Button
	for child in root.get_children():
		var found := _first_disabled_event_option(child)
		if found != null:
			return found
	return null

func _seed_for_event_with_unavailable_option() -> int:
	var catalog := ContentCatalogScript.new()
	catalog.load_default()
	for seed in range(1, 100):
		var run := _reward_run("event", true)
		run.seed_value = seed
		run.current_hp = 1
		run.gold = 0
		var event = EventResolverScript.new().resolve(catalog, run)
		if event == null:
			continue
		for option in event.options:
			if option.min_hp > run.current_hp or option.min_gold > run.gold:
				return seed
	return 1

func _delete_test_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
