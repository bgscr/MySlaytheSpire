extends RefCounted

const AppScene := preload("res://scenes/app/App.tscn")
const DebugOverlayScene := preload("res://scenes/dev/DebugOverlay.tscn")
const DevToolsScene := preload("res://scenes/dev/DevToolsScreen.tscn")
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
		var first_card_text := _find_node_by_name(first_card, "CardText_0") as Label
		first_card_has_type = first_card_def != null \
			and first_card_text != null \
			and first_card_text.text.contains(first_card_def.card_type)
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

func test_combat_screen_shows_attack_intent_row(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_attack_intent_row_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.strike"],
		"enemy_ids": ["training_puppet"],
		"seed_value": 201,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var row := _find_node_by_name(combat, "EnemyIntentRow_0") as HBoxContainer
	var icon := _find_node_by_name(combat, "IntentIcon_0") as Label
	var label := _find_node_by_name(combat, "IntentLabel_0") as Label
	var amount := _find_node_by_name(combat, "IntentAmount_0") as Label
	var target := _find_node_by_name(combat, "IntentTarget_0") as Label
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	var passed: bool = row != null \
		and icon != null \
		and icon.text == "ATK" \
		and label != null \
		and label.text == "Attack" \
		and amount != null \
		and amount.text == "5" \
		and target != null \
		and target.text == "Player" \
		and enemy_button != null \
		and not enemy_button.text.contains("attack_5")
	app.free()
	_delete_test_save("user://test_attack_intent_row_save.json")
	return passed

func test_combat_screen_shows_block_intent_row(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_block_intent_row_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["stone_grove_guardian"],
		"seed_value": 202,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var icon := _find_node_by_name(combat, "IntentIcon_0") as Label
	var label := _find_node_by_name(combat, "IntentLabel_0") as Label
	var amount := _find_node_by_name(combat, "IntentAmount_0") as Label
	var target := _find_node_by_name(combat, "IntentTarget_0") as Label
	var passed: bool = icon != null \
		and icon.text == "BLK" \
		and label != null \
		and label.text == "Block" \
		and amount != null \
		and amount.text == "6" \
		and target != null \
		and target.text == "Self"
	app.free()
	_delete_test_save("user://test_block_intent_row_save.json")
	return passed

func test_combat_screen_shows_status_intent_row(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_status_intent_row_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["plague_jade_imp"],
		"seed_value": 203,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var icon := _find_node_by_name(combat, "IntentIcon_0") as Label
	var label := _find_node_by_name(combat, "IntentLabel_0") as Label
	var amount := _find_node_by_name(combat, "IntentAmount_0") as Label
	var target := _find_node_by_name(combat, "IntentTarget_0") as Label
	var passed: bool = icon != null \
		and icon.text == "PSN" \
		and label != null \
		and label.text == "Poison" \
		and amount != null \
		and amount.text == "2" \
		and target != null \
		and target.text == "Player"
	app.free()
	_delete_test_save("user://test_status_intent_row_save.json")
	return passed

func test_combat_screen_renders_sword_visual_theme_background(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_sword_visual_background_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.strike"],
		"enemy_ids": ["training_puppet"],
		"seed_value": 301,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var layer := _find_node_by_name(combat, "CombatBackgroundLayer") as Control
	var texture := _find_node_by_name(combat, "CombatBackgroundTexture") as TextureRect
	var dimmer := _find_node_by_name(combat, "CombatBackgroundDimmer") as ColorRect
	var presentation_layer := _find_node_by_name(combat, "PresentationLayer")
	var passed: bool = layer != null \
		and texture != null \
		and texture.texture != null \
		and texture.get_meta("background_id") == "sword_training_ground" \
		and dimmer != null \
		and dimmer.color.a > 0.0 \
		and presentation_layer != null \
		and combat.get_children().find(layer) < combat.get_children().find(presentation_layer)
	app.free()
	_delete_test_save("user://test_sword_visual_background_save.json")
	return passed

func test_combat_screen_renders_alchemy_visual_theme_background(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_alchemy_visual_background_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "alchemy",
		"deck_ids": ["alchemy.toxic_pill"],
		"enemy_ids": ["training_puppet"],
		"seed_value": 302,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var texture := _find_node_by_name(combat, "CombatBackgroundTexture") as TextureRect
	var passed: bool = texture != null \
		and texture.texture != null \
		and texture.get_meta("background_id") == "alchemy_mist_grove"
	app.free()
	_delete_test_save("user://test_alchemy_visual_background_save.json")
	return passed

func test_combat_screen_renders_card_thumbnail_children(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_card_thumbnail_children_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.strike"],
		"enemy_ids": ["training_puppet"],
		"seed_value": 303,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var card := _find_node_by_name(combat, "CardButton_0") as Button
	var root := _find_node_by_name(combat, "CardVisualRoot_0") as VBoxContainer
	var thumbnail := _find_node_by_name(combat, "CardThumbnail_0") as TextureRect
	var frame := _find_node_by_name(combat, "CardFrame_0") as ColorRect
	var text := _find_node_by_name(combat, "CardText_0") as Label
	var passed: bool = card != null \
		and root != null \
		and root.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and frame != null \
		and frame.color.a > 0.0 \
		and text != null \
		and text.text.contains("sword.strike") \
		and card.text.is_empty()
	app.free()
	_delete_test_save("user://test_card_thumbnail_children_save.json")
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

func test_combat_screen_enemy_intent_row_keeps_targeting_clickable(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_intent_row_targeting_save.json")
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
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	var row := _find_node_by_name(combat, "EnemyIntentRow_0") as HBoxContainer
	var passed: bool = first_card != null \
		and enemy_button != null \
		and row != null \
		and combat.session.state.enemies[0].current_hp < enemy_hp_before \
		and combat.session.state.hand.is_empty()
	app.free()
	_delete_test_save("user://test_intent_row_targeting_save.json")
	return passed

func test_combat_screen_visual_card_button_still_clicks_and_drags(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_visual_card_interaction_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike", "sword.guard"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var enemy_hp_before: int = combat.session.state.enemies[0].current_hp
	var click_card := _find_node_by_name(combat, "CardButton_0") as Button
	if click_card != null:
		click_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	var click_played: bool = combat.session.state.enemies[0].current_hp < enemy_hp_before

	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var block_before: int = combat.session.state.player.block
	var dragged: bool = combat.try_play_dragged_card(0, "upward", -1)
	var thumbnail := _find_node_by_name(combat, "CardThumbnail_0") as TextureRect
	var passed: bool = click_card != null \
		and enemy_button != null \
		and click_played \
		and dragged \
		and combat.session.state.player.block > block_before \
		and thumbnail != null \
		and thumbnail.texture != null
	app.free()
	_delete_test_save("user://test_visual_card_interaction_save.json")
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

func test_debug_overlay_updates_reduced_motion_profile(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_reduced_motion_save.json")
	var debug_overlay: Node = app.get_node_or_null("DebugLayer/DebugOverlay")
	var reduced_toggle := _find_node_by_name(debug_overlay, "DebugPresentationReducedMotion") as CheckBox
	var initially_full: bool = reduced_toggle != null \
		and not reduced_toggle.button_pressed \
		and app.game.presentation_config.motion_profile == "full"
	if reduced_toggle != null:
		reduced_toggle.button_pressed = true
		reduced_toggle.toggled.emit(true)
	var reduced_applied: bool = app.game.presentation_config.motion_profile == "reduced" \
		and app.game.presentation_config.is_reduced_motion()
	if reduced_toggle != null:
		reduced_toggle.button_pressed = false
		reduced_toggle.toggled.emit(false)
	var full_restored: bool = app.game.presentation_config.motion_profile == "full" \
		and not app.game.presentation_config.is_reduced_motion()
	var passed: bool = initially_full and reduced_applied and full_restored
	app.free()
	_delete_test_save("user://test_debug_reduced_motion_save.json")
	return passed

func test_debug_overlay_routes_to_dev_tools_screen(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_dev_tools_save.json")
	var debug_overlay: Node = app.get_node_or_null("DebugLayer/DebugOverlay")
	var dev_tools_button := _find_node_by_name(debug_overlay, "DebugDevTools") as Button
	if dev_tools_button != null:
		dev_tools_button.pressed.emit()
	var current_scene: Node = app.game.router.current_scene
	var passed: bool = dev_tools_button != null \
		and current_scene != null \
		and current_scene.name == "DevToolsScreen"
	app.free()
	_delete_test_save("user://test_debug_dev_tools_save.json")
	return passed

func test_dev_tools_screen_starts_on_card_browser_and_selects_strike(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	screen.set_filters("sword", "common", "attack")
	screen.select_card("sword.strike")
	var panel := _find_node_by_name(screen, "CardBrowserPanel")
	var detail := _find_node_by_name(screen, "CardDetailLabel") as Label
	var passed: bool = screen.active_tool_id == "card_browser" \
		and panel != null \
		and detail != null \
		and detail.text.contains("id: sword.strike")
	screen.free()
	return passed

func test_dev_tools_enemy_sandbox_button_shows_panel(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_enemy_sandbox") as Button
	if button != null:
		button.pressed.emit()
	var panel := _find_node_by_name(screen, "EnemySandboxPanel")
	var summary := _find_node_by_name(screen, "EnemySandboxSummaryLabel") as Label
	var launch := _find_node_by_name(screen, "EnemySandboxLaunchButton") as Button
	var passed: bool = button != null \
		and screen.active_tool_id == "enemy_sandbox" \
		and panel != null \
		and summary != null \
		and summary.text.contains("enemy: training_puppet") \
		and launch != null
	screen.free()
	return passed

func test_dev_tools_event_tester_button_shows_panel(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_event_tester") as Button
	if button != null:
		button.pressed.emit()
	var panel := _find_node_by_name(screen, "EventTesterPanel")
	var summary := _find_node_by_name(screen, "EventTesterRunSummaryLabel") as Label
	var option := _find_node_by_name(screen, "EventTesterOption_0") as Button
	var reset := _find_node_by_name(screen, "EventTesterResetButton") as Button
	var passed: bool = button != null \
		and screen.active_tool_id == "event_tester" \
		and panel != null \
		and summary != null \
		and summary.text.contains("event: alchemist_market") \
		and option != null \
		and reset != null
	screen.free()
	return passed

func test_dev_tools_enemy_sandbox_launch_routes_to_sandbox_combat(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_sandbox_launch_save.json")
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var enemy_sandbox_button := _find_node_by_name(dev_tools, "ToolButton_enemy_sandbox") as Button
	if enemy_sandbox_button != null:
		enemy_sandbox_button.pressed.emit()
	var launch_button := _find_node_by_name(dev_tools, "EnemySandboxLaunchButton") as Button
	if launch_button != null:
		launch_button.pressed.emit()
	var combat = app.game.router.current_scene
	var passed: bool = launch_button != null \
		and combat != null \
		and combat.name == "CombatScreen" \
		and combat.is_sandbox \
		and app.game.current_run == null \
		and combat.session != null \
		and combat.session.run == null \
		and combat.session.state.enemies.size() == 1 \
		and combat.session.state.enemies[0].id == "training_puppet"
	app.free()
	_delete_test_save("user://test_enemy_sandbox_launch_save.json")
	return passed

func test_dev_tools_event_tester_apply_option_stays_in_dev_tools_without_current_run(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_event_tester_apply_save.json")
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var event_tester_button := _find_node_by_name(dev_tools, "ToolButton_event_tester") as Button
	if event_tester_button != null:
		event_tester_button.pressed.emit()
	var option_button := _find_node_by_name(dev_tools, "EventTesterOption_0") as Button
	if option_button != null:
		option_button.pressed.emit()
	var result := _find_node_by_name(dev_tools, "EventTesterResultLabel") as Label
	var summary := _find_node_by_name(dev_tools, "EventTesterRunSummaryLabel") as Label
	var passed: bool = option_button != null \
		and result != null \
		and result.text.contains("Applied option: buy_brew") \
		and summary != null \
		and summary.text.contains("gold: 30") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save("user://test_event_tester_apply_save.json")
	return passed

func test_dev_tools_reward_inspector_button_shows_panel(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_reward_inspector") as Button
	if button != null:
		button.pressed.emit()
	var panel := _find_node_by_name(screen, "RewardInspectorPanel")
	var summary := _find_node_by_name(screen, "RewardInspectorRunSummaryLabel") as Label
	var reward := _find_node_by_name(screen, "RewardInspectorReward_0")
	var claim := _find_node_by_name(screen, "RewardInspectorClaimCard_0_0") as Button
	var reset := _find_node_by_name(screen, "RewardInspectorResetButton") as Button
	var passed: bool = button != null \
		and screen.active_tool_id == "reward_inspector" \
		and panel != null \
		and summary != null \
		and summary.text.contains("node_type: combat") \
		and summary.text.contains("seed: 1") \
		and reward != null \
		and claim != null \
		and reset != null
	screen.free()
	return passed

func test_dev_tools_reward_inspector_claim_stays_in_dev_tools_without_current_run(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_reward_inspector_claim_save.json")
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var reward_button := _find_node_by_name(dev_tools, "ToolButton_reward_inspector") as Button
	if reward_button != null:
		reward_button.pressed.emit()
	var claim := _find_node_by_name(dev_tools, "RewardInspectorClaimCard_0_0") as Button
	if claim != null:
		claim.pressed.emit()
	var summary := _find_node_by_name(dev_tools, "RewardInspectorRunSummaryLabel") as Label
	var passed: bool = claim != null \
		and summary != null \
		and summary.text.contains("deck_count: 4") \
		and summary.text.contains("resolved: 1/2") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save("user://test_reward_inspector_claim_save.json")
	return passed

func test_dev_tools_reward_inspector_keeps_unresolved_rewards_enabled(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_reward_inspector") as Button
	if button != null:
		button.pressed.emit()
	var claim_card := _find_node_by_name(screen, "RewardInspectorClaimCard_0_0") as Button
	if claim_card != null:
		claim_card.pressed.emit()
	var claim_gold := _find_node_by_name(screen, "RewardInspectorClaimGold_1") as Button
	var summary_after_card := _find_node_by_name(screen, "RewardInspectorRunSummaryLabel") as Label
	var summary_text_after_card := summary_after_card.text if summary_after_card != null else ""
	var gold_was_enabled := claim_gold != null and not claim_gold.disabled
	if gold_was_enabled:
		claim_gold.pressed.emit()
	var summary_after_gold := _find_node_by_name(screen, "RewardInspectorRunSummaryLabel") as Label
	var passed: bool = claim_card != null \
		and claim_gold != null \
		and gold_was_enabled \
		and summary_after_card != null \
		and summary_text_after_card.contains("resolved: 1/2") \
		and summary_after_gold != null \
		and summary_after_gold.text.contains("resolved: 2/2") \
		and screen.reward_inspector_run.gold > 0
	screen.free()
	return passed

func test_dev_tools_reward_inspector_node_type_selection_refreshes_rewards(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_reward_inspector") as Button
	if button != null:
		button.pressed.emit()
	var node_select := _find_node_by_name(screen, "RewardInspectorNodeTypeSelect") as OptionButton
	if node_select != null:
		node_select.select(2)
		node_select.item_selected.emit(2)
	var summary := _find_node_by_name(screen, "RewardInspectorRunSummaryLabel") as Label
	var relic_button := _find_node_by_name(screen, "RewardInspectorClaimRelic_2") as Button
	var passed: bool = node_select != null \
		and summary != null \
		and summary.text.contains("node_type: boss") \
		and summary.text.contains("resolved: 0/3") \
		and relic_button != null
	screen.free()
	return passed

func test_dev_tools_save_inspector_button_shows_read_only_panel(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var panel := _find_node_by_name(screen, "SaveInspectorPanel")
	var status := _find_node_by_name(screen, "SaveInspectorStatusLabel") as Label
	var target := _find_node_by_name(screen, "SaveInspectorResumeTargetLabel") as Label
	var reload := _find_node_by_name(screen, "SaveInspectorReloadButton") as Button
	var delete_button := _find_node_by_name(screen, "SaveInspectorDeleteButton") as Button
	var export_button := _find_node_by_name(screen, "SaveInspectorExportButton") as Button
	var copy_button := _find_node_by_name(screen, "SaveInspectorCopyJsonButton") as Button
	var repair_button := _find_node_by_name(screen, "SaveInspectorRepairButton") as Button
	var passed: bool = button != null \
		and screen.active_tool_id == "save_inspector" \
		and panel != null \
		and status != null \
		and status.text.contains("status: missing_service") \
		and target != null \
		and target.text.contains("continue_target: none") \
		and reload != null \
		and not reload.disabled \
		and delete_button != null \
		and delete_button.disabled \
		and export_button != null \
		and export_button.disabled \
		and copy_button != null \
		and copy_button.disabled \
		and repair_button != null \
		and repair_button.disabled
	screen.free()
	return passed

func test_dev_tools_save_inspector_displays_saved_run_and_stays_in_dev_tools(tree: SceneTree) -> bool:
	var save_path := "user://test_save_inspector_panel_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("combat", true)
	app.game.save_service.save_run(run)
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var button := _find_node_by_name(dev_tools, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var status := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var target := _find_node_by_name(dev_tools, "SaveInspectorResumeTargetLabel") as Label
	var summary := _find_node_by_name(dev_tools, "SaveInspectorRunSummaryLabel") as Label
	var map_section := _find_node_by_name(dev_tools, "SaveInspectorMapSectionLabel") as Label
	var passed: bool = status != null \
		and status.text.contains("status: active") \
		and target != null \
		and target.text.contains("continue_target: map") \
		and summary != null \
		and summary.text.contains("character: sword") \
		and summary.text.contains("current_node_type: combat") \
		and map_section != null \
		and map_section.text.contains("map_nodes: 2") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save(save_path)
	return passed

func test_dev_tools_save_inspector_reload_refreshes_without_routing_or_current_run(tree: SceneTree) -> bool:
	var save_path := "user://test_save_inspector_reload_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var button := _find_node_by_name(dev_tools, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var status_before := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var before_text := status_before.text if status_before != null else ""
	app.game.save_service.save_run(_reward_run("shop", true))
	var reload := _find_node_by_name(dev_tools, "SaveInspectorReloadButton") as Button
	if reload != null:
		reload.pressed.emit()
	var status_after := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var target_after := _find_node_by_name(dev_tools, "SaveInspectorResumeTargetLabel") as Label
	var passed: bool = before_text.contains("status: no_save") \
		and reload != null \
		and status_after != null \
		and status_after.text.contains("status: active") \
		and target_after != null \
		and target_after.text.contains("continue_target: map") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save(save_path)
	return passed

func test_dev_tools_save_inspector_does_not_delete_invalid_save(tree: SceneTree) -> bool:
	var save_path := "user://test_save_inspector_invalid_kept.json"
	var app = _create_app_with_save_service(tree, save_path)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		app.free()
		return false
	file.store_string("{")
	file.close()
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var button := _find_node_by_name(dev_tools, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var status := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var target := _find_node_by_name(dev_tools, "SaveInspectorResumeTargetLabel") as Label
	var passed: bool = status != null \
		and status.text.contains("status: invalid") \
		and target != null \
		and target.text.contains("continue_target: invalid_delete_on_continue") \
		and app.game.save_service.has_save() \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save(save_path)
	return passed

func test_dev_tools_save_inspector_can_reopen_after_switching_tools(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var save_button := _find_node_by_name(screen, "ToolButton_save_inspector") as Button
	if save_button != null:
		save_button.pressed.emit()
	var card_button := _find_node_by_name(screen, "ToolButton_card_browser") as Button
	if card_button != null:
		card_button.pressed.emit()
	var refs_cleared_after_switch: bool = screen.save_inspector_status_label == null \
		and screen.save_inspector_resume_target_label == null \
		and screen.save_inspector_run_summary_label == null
	if save_button != null:
		save_button.pressed.emit()
	var panel := _find_node_by_name(screen, "SaveInspectorPanel")
	var status := _find_node_by_name(screen, "SaveInspectorStatusLabel") as Label
	var passed: bool = save_button != null \
		and card_button != null \
		and refs_cleared_after_switch \
		and screen.active_tool_id == "save_inspector" \
		and panel != null \
		and status != null \
		and status.text.contains("status: missing_service")
	screen.free()
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
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0") as TextureRect
	var passed: bool = first_card != null \
		and enemy_button != null \
		and slash != null \
		and slash.texture != null
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

func test_combat_screen_click_play_triggers_particle_asset_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_particle_asset_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "alchemy"
	run.max_hp = 68
	run.current_hp = 68
	run.deck_ids = ["alchemy.toxic_pill"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("alchemy.toxic_pill")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = first_card != null \
		and enemy_button != null \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_combat_particle_asset_save.json")
	return passed

func test_migrated_utility_card_triggers_explicit_particle_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_migrated_utility_card_feedback_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "alchemy"
	run.max_hp = 68
	run.current_hp = 68
	run.deck_ids = ["alchemy.quick_simmer"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("alchemy.quick_simmer")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var played: bool = combat.try_play_dragged_card(0, "player", -1)
	combat.presentation_layer.process_queue()

	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = played \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_migrated_utility_card_feedback_save.json")
	return passed

func test_migrated_sword_card_uses_explicit_slash_and_camera_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_migrated_sword_card_feedback_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.flash_cut"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.flash_cut")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var layer_position_before: Vector2 = combat.presentation_layer.position
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()

	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0") as TextureRect
	var passed: bool = played \
		and slash != null \
		and slash.texture != null \
		and combat.presentation_layer.position != layer_position_before
	app.free()
	_delete_test_save("user://test_migrated_sword_card_feedback_save.json")
	return passed

func test_explicit_slow_motion_and_audio_cues_are_recorded(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_explicit_slow_audio_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.heaven_cutting_arc"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.energy = 3
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.heaven_cutting_arc")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()
	var wash := _find_node_by_name(combat.presentation_layer, "SlowMotionWash_0") as TextureRect
	var audio_player := _find_node_by_name(combat.presentation_layer, "PresentationAudioPlayer") as AudioStreamPlayer
	var passed: bool = played \
		and combat.presentation_layer.active_slow_motion_scale < 1.0 \
		and combat.presentation_layer.last_audio_cue_id == "sword.heaven_cutting_arc" \
		and wash != null \
		and wash.texture != null \
		and audio_player != null \
		and audio_player.stream != null
	app.free()
	_delete_test_save("user://test_explicit_slow_audio_save.json")
	return passed

func test_reduced_motion_filters_card_play_motion_but_keeps_damage_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_reduced_motion_card_feedback_save.json")
	app.game.presentation_config.set_motion_profile("reduced")
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
	var layer_position_before: Vector2 = combat.presentation_layer.position
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()

	var float_text := _find_node_by_name(combat.presentation_layer, "FloatText_0") as Label
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0")
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0")
	var passed: bool = played \
		and combat.session.state.enemies[0].current_hp < enemy_hp_before \
		and float_text != null \
		and float_text.text.begins_with("-") \
		and slash == null \
		and particle == null \
		and combat.presentation_layer.position == layer_position_before \
		and is_equal_approx(combat.presentation_layer.active_slow_motion_scale, 1.0)
	app.free()
	_delete_test_save("user://test_reduced_motion_card_feedback_save.json")
	return passed

func test_reduced_motion_filters_explicit_slow_motion_but_keeps_audio_cue(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_reduced_motion_slow_audio_save.json")
	app.game.presentation_config.set_motion_profile("reduced")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.heaven_cutting_arc"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.energy = 3
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.heaven_cutting_arc")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()

	var wash := _find_node_by_name(combat.presentation_layer, "SlowMotionWash_0")
	var audio_player := _find_node_by_name(combat.presentation_layer, "PresentationAudioPlayer") as AudioStreamPlayer
	var passed: bool = played \
		and wash == null \
		and is_equal_approx(combat.presentation_layer.active_slow_motion_scale, 1.0) \
		and combat.presentation_layer.last_audio_cue_id == "sword.heaven_cutting_arc" \
		and combat.presentation_layer.audio_cue_count == 1 \
		and audio_player != null \
		and audio_player.stream != null
	app.free()
	_delete_test_save("user://test_reduced_motion_slow_audio_save.json")
	return passed

func test_combat_screen_end_turn_triggers_enemy_attack_polish(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_attack_polish_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["training_puppet"],
		"seed_value": 101,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var hp_before: int = combat.session.state.player.current_hp
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0") as TextureRect
	var passed: bool = end_turn != null \
		and combat.session.state.player.current_hp < hp_before \
		and slash != null \
		and slash.texture != null
	app.free()
	_delete_test_save("user://test_enemy_attack_polish_save.json")
	return passed

func test_combat_screen_end_turn_triggers_enemy_block_polish(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_block_polish_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["stone_grove_guardian"],
		"seed_value": 102,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = end_turn != null \
		and combat.session.state.enemies[0].block > 0 \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_enemy_block_polish_save.json")
	return passed

func test_combat_screen_end_turn_triggers_enemy_status_polish(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_status_polish_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["plague_jade_imp"],
		"seed_value": 103,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = end_turn != null \
		and int(combat.session.state.player.statuses.get("poison", 0)) > 0 \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_enemy_status_polish_save.json")
	return passed

func test_enemy_intent_polish_respects_particle_toggle(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_particle_toggle_save.json")
	app.game.presentation_config.particle_enabled = false
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["stone_grove_guardian"],
		"seed_value": 104,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0")
	var passed: bool = end_turn != null \
		and combat.session.state.enemies[0].block > 0 \
		and particle == null
	app.free()
	_delete_test_save("user://test_enemy_particle_toggle_save.json")
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
