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
const ShopResolverScript := preload("res://scripts/shop/shop_resolver.gd")

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

func test_combat_screen_click_play_enqueues_delta_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_presentation_click_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	var presentation_layer: Node = combat.get_node_or_null("PresentationLayer")
	if presentation_layer != null:
		presentation_layer.call("process_queue")
	var float_text := _find_node_by_name(presentation_layer, "FloatText_0") as Label if presentation_layer != null else null
	var passed: bool = presentation_layer != null \
		and first_card != null \
		and enemy_button != null \
		and float_text != null \
		and float_text.text.begins_with("-")
	app.free()
	_delete_test_save("user://test_combat_presentation_click_save.json")
	return passed

func test_combat_screen_drag_enemy_target_card_to_enemy(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_drag_enemy_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var enemy_hp_before: int = combat.session.state.enemies[0].current_hp
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()
	var float_text := _find_node_by_name(combat.presentation_layer, "FloatText_0") as Label
	var passed: bool = played \
		and combat.session.state.enemies[0].current_hp < enemy_hp_before \
		and combat.session.state.hand.is_empty() \
		and float_text != null
	app.free()
	_delete_test_save("user://test_combat_drag_enemy_save.json")
	return passed

func test_combat_screen_invalid_drag_release_does_not_mutate_state(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_invalid_drag_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var enemy_hp_before: int = combat.session.state.enemies[0].current_hp
	var played: bool = combat.try_play_dragged_card(0, "player", -1)
	var passed: bool = not played \
		and combat.session.state.enemies[0].current_hp == enemy_hp_before \
		and combat.session.state.hand.size() == 1 \
		and combat.session.state.hand[0] == "sword.strike"
	app.free()
	_delete_test_save("user://test_combat_invalid_drag_save.json")
	return passed

func test_combat_screen_drag_self_card_upward_plays_to_player(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_drag_self_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.guard"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var block_before: int = combat.session.state.player.block
	var played: bool = combat.try_play_dragged_card(0, "upward", -1)
	var passed: bool = played \
		and combat.session.state.player.block > block_before \
		and combat.session.state.hand.is_empty()
	app.free()
	_delete_test_save("user://test_combat_drag_self_save.json")
	return passed

func test_debug_overlay_updates_presentation_config(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_presentation_config_save.json")
	var debug_overlay: Node = app.get_node_or_null("DebugLayer/DebugOverlay")
	var drag_toggle := _find_node_by_name(debug_overlay, "DebugPresentationDrag") as CheckBox
	if drag_toggle != null:
		drag_toggle.button_pressed = false
		drag_toggle.toggled.emit(false)
	var passed: bool = drag_toggle != null \
		and app.game.presentation_config.drag_enabled == false
	app.free()
	_delete_test_save("user://test_debug_presentation_config_save.json")
	return passed

func test_debug_overlay_updates_polish_presentation_config(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_polish_config_save.json")
	var debug_overlay: Node = app.get_node_or_null("DebugLayer/DebugOverlay")
	var particle_toggle := _find_node_by_name(debug_overlay, "DebugPresentationParticles") as CheckBox
	var camera_toggle := _find_node_by_name(debug_overlay, "DebugPresentationCameraImpulse") as CheckBox
	var slow_toggle := _find_node_by_name(debug_overlay, "DebugPresentationSlowMotion") as CheckBox
	var audio_toggle := _find_node_by_name(debug_overlay, "DebugPresentationAudioCue") as CheckBox
	if particle_toggle != null:
		particle_toggle.button_pressed = false
		particle_toggle.toggled.emit(false)
	if camera_toggle != null:
		camera_toggle.button_pressed = false
		camera_toggle.toggled.emit(false)
	if slow_toggle != null:
		slow_toggle.button_pressed = false
		slow_toggle.toggled.emit(false)
	if audio_toggle != null:
		audio_toggle.button_pressed = false
		audio_toggle.toggled.emit(false)
	var passed: bool = particle_toggle != null \
		and camera_toggle != null \
		and slow_toggle != null \
		and audio_toggle != null \
		and app.game.presentation_config.particle_enabled == false \
		and app.game.presentation_config.camera_impulse_enabled == false \
		and app.game.presentation_config.slow_motion_enabled == false \
		and app.game.presentation_config.audio_cue_enabled == false
	app.free()
	_delete_test_save("user://test_debug_polish_config_save.json")
	return passed

func test_combat_screen_drag_disabled_keeps_click_fallback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_drag_disabled_click_save.json")
	var config: Variant = app.game.get("presentation_config")
	if config != null:
		config.drag_enabled = false
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var drag_played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	var passed: bool = not drag_played \
		and config != null \
		and first_card != null \
		and enemy_button != null \
		and combat.session.state.hand.is_empty()
	app.free()
	_delete_test_save("user://test_drag_disabled_click_save.json")
	return passed

func test_combat_screen_click_play_triggers_slash_polish_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_slash_polish_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	combat.presentation_layer.process_queue()
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0")
	var passed: bool = first_card != null and enemy_button != null and slash != null
	app.free()
	_delete_test_save("user://test_combat_slash_polish_save.json")
	return passed

func test_combat_screen_cinematic_disabled_filters_slash_but_plays_card(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_cinematic_disabled_save.json")
	app.game.presentation_config.cinematic_enabled = false
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var enemy_hp_before: int = combat.session.state.enemies[0].current_hp
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0")
	var passed: bool = played \
		and combat.session.state.enemies[0].current_hp < enemy_hp_before \
		and slash == null
	app.free()
	_delete_test_save("user://test_combat_cinematic_disabled_save.json")
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

func test_reward_screen_claims_pending_event_reward_then_advances_event(tree: SceneTree) -> bool:
	var save_path := "user://test_event_reward_screen_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	run.current_reward_state = {
		"source": "event",
		"node_id": "node_0",
		"event_id": "forgotten_armory",
		"option_id": "train",
		"rewards": [
			{
				"id": "event-card:node_0:train",
				"type": "card_choice",
				"card_ids": ["sword.flash_cut", "sword.guard"],
			},
		],
	}
	app.game.current_run = run

	var reward_screen = app.game.router.go_to(SceneRouterScript.REWARD)
	var claim_card := _find_node_by_name(reward_screen, "ClaimCard_0_0") as Button
	if claim_card != null:
		claim_card.pressed.emit()
	var continue_button := _find_node_by_name(reward_screen, "ContinueButton") as Button
	if continue_button != null:
		continue_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = claim_card != null \
		and continue_button != null \
		and loaded_run != null \
		and loaded_run.current_reward_state.is_empty() \
		and loaded_run.deck_ids.has("sword.flash_cut") \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != reward_screen
	app.free()
	_delete_test_save(save_path)
	return passed

func test_map_shop_node_routes_to_shop_screen(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_route_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	app.game.current_run = run
	var map_screen = app.game.router.go_to(SceneRouterScript.MAP)
	var shop_button := _find_node_by_text(map_screen, "node_0: shop") as Button
	if shop_button != null:
		shop_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = shop_button != null \
		and app.game.router.current_scene != null \
		and app.game.router.current_scene.name == "ShopScreen" \
		and loaded_run != null \
		and not loaded_run.current_shop_state.is_empty()
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_buy_card_saves_immediately(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_buy_card_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var card_button := _first_button_with_prefix(shop_screen, "BuyOffer_card_")
	var deck_size_before := run.deck_ids.size()
	if card_button != null:
		card_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = card_button != null \
		and loaded_run != null \
		and loaded_run.deck_ids.size() == deck_size_before + 1 \
		and not loaded_run.current_shop_state.is_empty() \
		and _has_sold_offer(loaded_run.current_shop_state, "card")
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_buy_relic_saves_immediately(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_buy_relic_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var relic_button := _first_button_with_prefix(shop_screen, "BuyOffer_relic_")
	if relic_button != null:
		relic_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = relic_button != null \
		and loaded_run != null \
		and loaded_run.relic_ids.size() == 1 \
		and not loaded_run.relic_ids[0].is_empty() \
		and _has_sold_offer(loaded_run.current_shop_state, "relic")
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_refresh_is_one_use_and_saved(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_refresh_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var refresh_button := _find_node_by_name(shop_screen, "RefreshButton") as Button
	if refresh_button != null:
		refresh_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var refreshed_once: bool = loaded_run != null and loaded_run.current_shop_state.get("refresh_used") == true
	refresh_button = _find_node_by_name(app.game.router.current_scene, "RefreshButton") as Button
	var disabled_after_refresh := refresh_button != null and refresh_button.disabled
	var passed: bool = refreshed_once and disabled_after_refresh
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_remove_card_and_heal_services_sell_out(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_services_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	run.current_hp = 40
	run.max_hp = 72
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var heal_button := _find_node_by_name(shop_screen, "BuyOffer_heal_0") as Button
	if heal_button != null:
		heal_button.pressed.emit()
	var remove_button := _find_node_by_name(app.game.router.current_scene, "BuyOffer_remove_0") as Button
	if remove_button != null:
		remove_button.pressed.emit()
	var remove_card := _find_node_by_name(app.game.router.current_scene, "RemoveCard_0") as Button
	if remove_card != null:
		remove_card.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = loaded_run != null \
		and loaded_run.current_hp > 40 \
		and loaded_run.deck_ids.size() == 2 \
		and _offer_sold(loaded_run.current_shop_state, "heal_0") \
		and _offer_sold(loaded_run.current_shop_state, "remove_0")
	app.free()
	_delete_test_save(save_path)
	return passed

func test_main_menu_continue_resumes_in_progress_shop(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_continue_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	var catalog := ContentCatalogScript.new()
	catalog.load_default()
	ShopResolverScript.new().resolve(catalog, run)
	app.game.save_service.save_run(run)
	var main_menu = app.game.router.go_to(SceneRouterScript.MAIN_MENU)
	var continue_button := _find_continue_button(main_menu)
	if continue_button != null:
		continue_button.pressed.emit()
	var passed: bool = app.game.router.current_scene != null \
		and app.game.router.current_scene.name == "ShopScreen"
	app.free()
	_delete_test_save(save_path)
	return passed

func test_main_menu_continue_resumes_pending_event_reward(tree: SceneTree) -> bool:
	var save_path := "user://test_event_reward_continue_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	run.current_reward_state = {
		"source": "event",
		"node_id": "node_0",
		"event_id": "forgotten_armory",
		"option_id": "train",
		"rewards": [
			{
				"id": "event-card:node_0:train",
				"type": "card_choice",
				"card_ids": ["sword.flash_cut", "sword.guard"],
			},
		],
	}
	app.game.save_service.save_run(run)
	var main_menu = app.game.router.go_to(SceneRouterScript.MAIN_MENU)
	var continue_button := _find_continue_button(main_menu)
	if continue_button != null:
		continue_button.pressed.emit()
	var claim_card := _find_node_by_name(app.game.router.current_scene, "ClaimCard_0_0") as Button
	var passed: bool = continue_button != null \
		and app.game.router.current_scene != null \
		and app.game.router.current_scene.name == "RewardScreen" \
		and claim_card != null
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_leave_clears_state_saves_and_advances(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_leave_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var leave_button := _find_node_by_name(shop_screen, "LeaveShopButton") as Button
	if leave_button != null:
		leave_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = leave_button != null \
		and loaded_run != null \
		and loaded_run.current_shop_state.is_empty() \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != shop_screen
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

func _first_button_with_prefix(root: Node, prefix: String) -> Button:
	if root == null:
		return null
	if root is Button and root.name.begins_with(prefix):
		return root as Button
	for child in root.get_children():
		var found := _first_button_with_prefix(child, prefix)
		if found != null:
			return found
	return null

func _has_sold_offer(shop_state: Dictionary, offer_type: String) -> bool:
	for offer in shop_state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("type") == offer_type and payload.get("sold") == true:
			return true
	return false

func _offer_sold(shop_state: Dictionary, offer_id: String) -> bool:
	for offer in shop_state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("id") == offer_id:
			return payload.get("sold") == true
	return false

func _delete_test_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
