extends Control

const CombatSession := preload("res://scripts/combat/combat_session.gd")
const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationCueResolver := preload("res://scripts/presentation/combat_presentation_cue_resolver.gd")
const CombatPresentationDelta := preload("res://scripts/presentation/combat_presentation_delta.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationIntentCueResolver := preload("res://scripts/presentation/combat_presentation_intent_cue_resolver.gd")
const CombatPresentationLayer := preload("res://scripts/presentation/combat_presentation_layer.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")
const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EnemyIntentDisplayResolver := preload("res://scripts/presentation/enemy_intent_display_resolver.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var session: CombatSession
var presentation_config: CombatPresentationConfig
var presentation_queue := CombatPresentationQueue.new()
var presentation_delta := CombatPresentationDelta.new()
var presentation_cue_resolver := CombatPresentationCueResolver.new()
var presentation_intent_resolver := CombatPresentationIntentCueResolver.new()
var enemy_intent_display_resolver := EnemyIntentDisplayResolver.new()
var combat_visual_resolver := CombatVisualResolver.new()
var visual_theme := {}
var presentation_layer: CombatPresentationLayer
var combat_background_layer: Control
var combat_background_texture: TextureRect
var combat_background_dimmer: ColorRect
var is_sandbox := false
var enemy_buttons: Array[Button] = []
var card_buttons: Array[Button] = []
var dragging_hand_index := -1
var drag_start_position := Vector2.ZERO
var current_highlight_target := ""
var status_label: Label
var pile_label: Label
var error_label: Label
var enemy_container: VBoxContainer
var hand_container: HBoxContainer
var player_target_button: Button
var cancel_button: Button
var end_turn_button: Button

func _ready() -> void:
	set_process_unhandled_input(true)
	_build_layout()
	_start_session()
	_refresh()

func _process(_delta: float) -> void:
	if presentation_layer != null:
		presentation_layer.process_queue()

func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_selection()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_selection()

func _build_layout() -> void:
	_build_background_layer()

	status_label = Label.new()
	status_label.name = "PlayerStatus"
	add_child(status_label)

	pile_label = Label.new()
	pile_label.name = "PileStatus"
	pile_label.position.y = 24
	add_child(pile_label)

	error_label = Label.new()
	error_label.name = "CombatError"
	error_label.position.y = 48
	add_child(error_label)

	enemy_container = VBoxContainer.new()
	enemy_container.name = "EnemyContainer"
	enemy_container.position = Vector2(320, 88)
	add_child(enemy_container)

	player_target_button = Button.new()
	player_target_button.name = "PlayerTargetButton"
	player_target_button.text = "Confirm Player Target"
	player_target_button.position = Vector2(16, 88)
	player_target_button.pressed.connect(_on_player_target_pressed)
	add_child(player_target_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelSelectionButton"
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(16, 136)
	cancel_button.pressed.connect(_cancel_selection)
	add_child(cancel_button)

	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "End Turn"
	end_turn_button.position = Vector2(16, 184)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)

	hand_container = HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.position = Vector2(16, 360)
	add_child(hand_container)

	presentation_layer = CombatPresentationLayer.new()
	presentation_layer.name = "PresentationLayer"
	presentation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(presentation_layer)

func _build_background_layer() -> void:
	combat_background_layer = Control.new()
	combat_background_layer.name = "CombatBackgroundLayer"
	combat_background_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_background_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combat_background_layer)

	combat_background_texture = TextureRect.new()
	combat_background_texture.name = "CombatBackgroundTexture"
	combat_background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	combat_background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combat_background_texture.stretch_mode = TextureRect.STRETCH_SCALE
	combat_background_layer.add_child(combat_background_texture)

	combat_background_dimmer = ColorRect.new()
	combat_background_dimmer.name = "CombatBackgroundDimmer"
	combat_background_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_background_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	combat_background_layer.add_child(combat_background_dimmer)

func _apply_combat_background() -> void:
	if session == null or combat_background_texture == null or combat_background_dimmer == null:
		return
	var background := combat_visual_resolver.resolve_combat_background(session.state.player.id, session.catalog)
	var texture_path := String(background.get("texture_path", ""))
	combat_background_texture.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	combat_background_texture.set_meta("background_id", String(background.get("background_id", "")))
	var accent := background.get("accent_color", Color.BLACK) as Color
	var opacity := float(background.get("dim_opacity", 0.35))
	combat_background_dimmer.color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2, opacity)

func _start_session() -> void:
	var app = get_tree().root.get_node("App")
	var catalog := ContentCatalog.new()
	catalog.load_default()
	session = CombatSession.new()
	is_sandbox = false
	var sandbox_config: Dictionary = {}
	if app.game.has_method("take_debug_combat_sandbox_config"):
		sandbox_config = app.game.take_debug_combat_sandbox_config()
	if sandbox_config.is_empty():
		session.start(catalog, app.game.current_run)
	else:
		is_sandbox = true
		session.start_sandbox(
			catalog,
			String(sandbox_config.get("character_id", "")),
			_string_array_from_variant(sandbox_config.get("deck_ids", [])),
			_string_array_from_variant(sandbox_config.get("enemy_ids", [])),
			int(sandbox_config.get("seed_value", 1))
		)
	presentation_config = app.game.presentation_config
	visual_theme = combat_visual_resolver.resolve_theme(session.state.player.id, session.catalog)
	_apply_combat_background()
	presentation_queue.config = presentation_config
	presentation_layer.queue = presentation_queue
	for event in presentation_delta.events_from_initial_state(session.state):
		presentation_queue.enqueue(event)

func _refresh() -> void:
	if session == null:
		return
	status_label.text = _player_status_text()
	pile_label.text = "Draw %s | Discard %s | Exhaust %s | Phase %s" % [
		session.state.draw_pile.size(),
		session.state.discard_pile.size(),
		session.state.exhausted_pile.size(),
		session.phase,
	]
	error_label.text = session.error_text
	player_target_button.visible = session.phase == CombatSession.PHASE_CONFIRMING_PLAYER_TARGET
	cancel_button.visible = session.phase == CombatSession.PHASE_SELECTING_ENEMY_TARGET \
		or session.phase == CombatSession.PHASE_CONFIRMING_PLAYER_TARGET
	end_turn_button.disabled = session.phase != CombatSession.PHASE_PLAYER_TURN
	if presentation_layer != null:
		_clear_current_highlight()
		presentation_layer.clear_bindings()
		presentation_layer.bind_target("player", status_label)
		presentation_layer.bind_status_target("player", status_label)
	_refresh_enemies()
	_refresh_hand()
	_route_if_terminal()

func _player_status_text() -> String:
	if session.state.player == null:
		return "No player"
	var text := "Player %s HP %s/%s Block %s Energy %s Turn %s" % [
		session.state.player.id,
		session.state.player.current_hp,
		session.state.player.max_hp,
		session.state.player.block,
		session.state.energy,
		session.state.turn,
	]
	var statuses := session.status_runtime.status_display_text(session.state.player)
	if not statuses.is_empty():
		text += " Status %s" % statuses
	return text

func _enemy_summary_text(enemy, _enemy_index: int) -> String:
	var text := "%s HP %s/%s Block %s" % [
		enemy.id,
		enemy.current_hp,
		enemy.max_hp,
		enemy.block,
	]
	var statuses := session.status_runtime.status_display_text(enemy)
	if not statuses.is_empty():
		text += " Status %s" % statuses
	return text

func _add_enemy_visual(parent: Control, enemy_index: int, enemy) -> void:
	var visual := combat_visual_resolver.resolve_enemy_visual(enemy.id, session.catalog)

	var root := HBoxContainer.new()
	root.name = "EnemyVisualRoot_%s" % enemy_index
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	var frame := ColorRect.new()
	frame.name = "EnemyPortraitFrame_%s" % enemy_index
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(6, 54)
	frame.color = visual.get("accent_color", Color.WHITE)
	frame.set_meta("frame_style", String(visual.get("frame_style", "")))
	root.add_child(frame)

	var portrait := TextureRect.new()
	portrait.name = "EnemyPortrait_%s" % enemy_index
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(72, 54)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path := String(visual.get("portrait_path", ""))
	portrait.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	portrait.set_meta("enemy_id", String(visual.get("enemy_id", enemy.id)))
	portrait.set_meta("silhouette_tag", String(visual.get("silhouette_tag", "")))
	root.add_child(portrait)

func _add_enemy_intent_row(parent: Control, enemy_index: int, raw_intent: String) -> void:
	var display := enemy_intent_display_resolver.resolve(raw_intent, session.catalog)
	var row := HBoxContainer.new()
	row.name = "EnemyIntentRow_%s" % enemy_index
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var icon := Label.new()
	icon.name = "IntentIcon_%s" % enemy_index
	icon.text = _intent_icon_text(String(display.get("icon_key", "unknown")))
	icon.modulate = display.get("color", Color.WHITE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.name = "IntentLabel_%s" % enemy_index
	label.text = String(display.get("label", "Unknown"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var amount := Label.new()
	amount.name = "IntentAmount_%s" % enemy_index
	var amount_value := int(display.get("amount", 0))
	amount.visible = bool(display.get("show_amount", true)) and amount_value > 0
	amount.text = str(amount_value) if amount.visible else ""
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount)

	var target := Label.new()
	target.name = "IntentTarget_%s" % enemy_index
	var target_value := String(display.get("target", ""))
	target.visible = bool(display.get("show_target", true)) and not target_value.is_empty()
	target.text = _intent_target_text(target_value) if target.visible else ""
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(target)

func _intent_icon_text(icon_key: String) -> String:
	match icon_key:
		"attack":
			return "ATK"
		"block":
			return "BLK"
		"poison":
			return "PSN"
		"broken_stance":
			return "BRK"
		"sword_focus":
			return "FOC"
	return "UNK"

func _intent_target_text(target: String) -> String:
	match target:
		"player":
			return "Player"
		"self":
			return "Self"
	return target.capitalize()

func _refresh_enemies() -> void:
	_clear_children(enemy_container)
	enemy_buttons.clear()
	for enemy_index in range(session.state.enemies.size()):
		var enemy = session.state.enemies[enemy_index]
		var button := Button.new()
		button.name = "EnemyButton_%s" % enemy_index
		button.text = ""
		button.custom_minimum_size = Vector2(520, 72)
		button.disabled = enemy.is_defeated()
		button.pressed.connect(func(): _on_enemy_pressed(enemy_index))

		var content := VBoxContainer.new()
		content.name = "EnemyContent_%s" % enemy_index
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_top = 6
		content.offset_right = -8
		content.offset_bottom = -6
		button.add_child(content)

		_add_enemy_visual(content, enemy_index, enemy)

		var summary := Label.new()
		summary.name = "EnemySummaryLabel_%s" % enemy_index
		summary.text = _enemy_summary_text(enemy, enemy_index)
		content.add_child(summary)

		_add_enemy_intent_row(content, enemy_index, session.get_enemy_intent(enemy_index))

		enemy_container.add_child(button)
		enemy_buttons.append(button)
		if presentation_layer != null:
			var target_id := "enemy:%s" % enemy_index
			presentation_layer.bind_target(target_id, button)
			presentation_layer.bind_status_target(target_id, button)

func _refresh_hand() -> void:
	_clear_children(hand_container)
	card_buttons.clear()
	for hand_index in range(session.state.hand.size()):
		var card_id := session.state.hand[hand_index]
		var card = session.catalog.get_card(card_id)
		var button := Button.new()
		button.name = "CardButton_%s" % hand_index
		button.text = ""
		button.disabled = session.phase != CombatSession.PHASE_PLAYER_TURN
		button.pressed.connect(func(): _on_card_pressed(hand_index))
		button.mouse_entered.connect(func(): _on_card_hovered(hand_index))
		button.mouse_exited.connect(func(): _on_card_unhovered(hand_index))
		button.gui_input.connect(func(event): _on_card_gui_input(event, hand_index, button))
		_add_card_visual(button, hand_index, card)
		hand_container.add_child(button)
		card_buttons.append(button)
		if presentation_layer != null:
			presentation_layer.bind_target("card:%s" % hand_index, button)

func _add_card_visual(button: Button, hand_index: int, card) -> void:
	var card_id := session.state.hand[hand_index]
	var visual := combat_visual_resolver.resolve_card_visual(card_id, session.catalog, visual_theme)
	button.custom_minimum_size = Vector2(148, 116)

	var root := VBoxContainer.new()
	root.name = "CardVisualRoot_%s" % hand_index
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 6
	root.offset_top = 6
	root.offset_right = -6
	root.offset_bottom = -6
	button.add_child(root)

	var frame := ColorRect.new()
	frame.name = "CardFrame_%s" % hand_index
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(132, 6)
	frame.color = visual.get("accent_color", Color.WHITE)
	root.add_child(frame)

	var thumbnail := TextureRect.new()
	thumbnail.name = "CardThumbnail_%s" % hand_index
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.custom_minimum_size = Vector2(132, 58)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path := String(visual.get("thumbnail_path", ""))
	thumbnail.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	root.add_child(thumbnail)

	var label := Label.new()
	label.name = "CardText_%s" % hand_index
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _card_visual_text(card_id, card)
	root.add_child(label)

func _card_visual_text(card_id: String, card) -> String:
	if card == null:
		return "%s (?)" % card_id
	return "%s [%s] (%s)" % [card.id, card.card_type, card.cost]

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _on_card_pressed(hand_index: int) -> void:
	session.select_card(hand_index)
	_refresh()

func try_play_dragged_card(hand_index: int, target_kind: String, enemy_index: int = -1) -> bool:
	if presentation_config != null and not presentation_config.drag_enabled:
		return false
	if session == null or session.phase != CombatSession.PHASE_PLAYER_TURN:
		return false
	if hand_index < 0 or hand_index >= session.state.hand.size():
		return false
	var card_id := session.state.hand[hand_index]
	var mode := _card_target_mode(hand_index)
	match target_kind:
		"enemy":
			if mode != "enemy":
				return false
			if enemy_index < 0 or enemy_index >= session.state.enemies.size():
				return false
			var enemy_action := func():
				if not session.select_card(hand_index):
					return false
				return session.confirm_enemy_target(enemy_index)
			return _run_with_feedback(enemy_action, card_id, "enemy:%s" % enemy_index)
		"player":
			if mode == "enemy":
				return false
			var player_action := func():
				if not session.select_card(hand_index):
					return false
				return session.confirm_player_target()
			return _run_with_feedback(player_action, card_id, "player")
		"upward":
			if mode == "enemy":
				return false
			var upward_action := func():
				if not session.select_card(hand_index):
					return false
				return session.confirm_player_target()
			return _run_with_feedback(upward_action, card_id, "player")
	return false

func _card_target_mode(hand_index: int) -> String:
	if session == null or hand_index < 0 or hand_index >= session.state.hand.size():
		return "invalid"
	var card = session.catalog.get_card(session.state.hand[hand_index])
	if card == null:
		return "invalid"
	for effect in card.effects:
		var target := String(effect.target).to_lower()
		if target == "enemy" or target == "target":
			return "enemy"
	return "player"

func _on_card_hovered(hand_index: int) -> void:
	_enqueue_card_event("card_hovered", hand_index)

func _on_card_unhovered(hand_index: int) -> void:
	_enqueue_card_event("card_unhovered", hand_index)

func _on_card_gui_input(event: InputEvent, hand_index: int, button: Button) -> void:
	if presentation_config != null and not presentation_config.drag_enabled:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_start_card_drag(hand_index, button, mouse_button.global_position)
		elif dragging_hand_index == hand_index:
			_release_card_drag(mouse_button.global_position)
	elif event is InputEventMouseMotion and dragging_hand_index == hand_index:
		var mouse_motion := event as InputEventMouseMotion
		_update_card_drag(mouse_motion.global_position)

func _start_card_drag(hand_index: int, _button: Button, global_position: Vector2) -> void:
	if session == null or session.phase != CombatSession.PHASE_PLAYER_TURN:
		return
	if hand_index < 0 or hand_index >= session.state.hand.size():
		return
	dragging_hand_index = hand_index
	drag_start_position = global_position
	_enqueue_card_event("card_drag_started", hand_index)

func _update_card_drag(global_position: Vector2) -> void:
	if dragging_hand_index < 0:
		return
	var target_id := _target_id_at_position(global_position)
	if target_id != current_highlight_target:
		_clear_current_highlight()
		current_highlight_target = target_id
		if not current_highlight_target.is_empty():
			var event := CombatPresentationEvent.new("target_highlighted")
			event.target_id = current_highlight_target
			presentation_queue.enqueue(event)

func _release_card_drag(global_position: Vector2) -> void:
	if dragging_hand_index < 0:
		return
	var hand_index := dragging_hand_index
	dragging_hand_index = -1
	_clear_current_highlight()
	_enqueue_card_event("card_drag_released", hand_index)
	var target_id := _target_id_at_position(global_position)
	var played := false
	if target_id.begins_with("enemy:"):
		played = try_play_dragged_card(hand_index, "enemy", int(target_id.trim_prefix("enemy:")))
	elif target_id == "player":
		played = try_play_dragged_card(hand_index, "player", -1)
	elif drag_start_position.y - global_position.y >= 80.0:
		played = try_play_dragged_card(hand_index, "upward", -1)
	if played:
		_refresh()

func _target_id_at_position(global_position: Vector2) -> String:
	for enemy_index in range(enemy_buttons.size()):
		var button := enemy_buttons[enemy_index]
		if button != null and button.get_global_rect().has_point(global_position):
			return "enemy:%s" % enemy_index
	if player_target_button != null and player_target_button.get_global_rect().has_point(global_position):
		return "player"
	if status_label != null and status_label.get_global_rect().has_point(global_position):
		return "player"
	return ""

func _clear_current_highlight() -> void:
	if current_highlight_target.is_empty():
		return
	var event := CombatPresentationEvent.new("target_unhighlighted")
	event.target_id = current_highlight_target
	presentation_queue.enqueue(event)
	current_highlight_target = ""

func _on_enemy_pressed(enemy_index: int) -> void:
	var card_id := _pending_card_id()
	var action := func(): return session.confirm_enemy_target(enemy_index)
	_run_with_feedback(action, card_id, "enemy:%s" % enemy_index)
	_refresh()

func _on_player_target_pressed() -> void:
	var card_id := _pending_card_id()
	var action := func(): return session.confirm_player_target()
	_run_with_feedback(action, card_id, "player")
	_refresh()

func _cancel_selection() -> void:
	session.cancel_selection()
	_refresh()

func _on_end_turn_pressed() -> void:
	var intent_snapshots := _capture_enemy_intent_snapshots()
	_run_with_feedback(func(): return session.end_player_turn(), "", "", intent_snapshots)
	_refresh()

func _capture_enemy_intent_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if session == null:
		return snapshots
	for enemy_index in range(session.state.enemies.size()):
		var enemy = session.state.enemies[enemy_index]
		if enemy == null or enemy.is_defeated():
			continue
		var source_id := "enemy:%s" % enemy_index
		var intent := session.get_enemy_intent(enemy_index)
		if intent.is_empty():
			continue
		snapshots.append({
			"source_id": source_id,
			"target_id": "player",
			"intent": intent,
		})
	return snapshots

func _run_with_feedback(
	action: Callable,
	played_card_id: String = "",
	played_target_id: String = "",
	enemy_intent_snapshots: Array[Dictionary] = []
) -> bool:
	var before := presentation_delta.capture_state(session.state)
	var played_card = session.catalog.get_card(played_card_id) if not played_card_id.is_empty() else null
	var succeeded := bool(action.call())
	if succeeded:
		var delta_events := presentation_delta.events_between(before, session.state)
		if not played_card_id.is_empty():
			var played_event := CombatPresentationEvent.new("card_played")
			played_event.card_id = played_card_id
			played_event.source_id = "player"
			played_event.target_id = played_target_id
			presentation_queue.enqueue(played_event)
			for event in presentation_cue_resolver.resolve_card_play(
				played_card,
				"player",
				played_target_id,
				delta_events
			):
				presentation_queue.enqueue(event)
		if not enemy_intent_snapshots.is_empty():
			for event in presentation_intent_resolver.resolve_enemy_turn(enemy_intent_snapshots, delta_events):
				presentation_queue.enqueue(event)
		for event in delta_events:
			presentation_queue.enqueue(event)
	return succeeded

func _enqueue_card_event(event_type: String, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= session.state.hand.size():
		return
	var event := CombatPresentationEvent.new(event_type)
	event.target_id = "card:%s" % hand_index
	event.card_id = session.state.hand[hand_index]
	presentation_queue.enqueue(event)

func _pending_card_id() -> String:
	if session.pending_card == null:
		return ""
	return session.pending_card.id

func _string_array_from_variant(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(String(value))
	return result

func _route_if_terminal() -> void:
	if is_sandbox:
		return
	if session.phase == CombatSession.PHASE_WON:
		var app = get_tree().root.get_node("App")
		app.game.router.go_to(SceneRouterScript.REWARD)
	elif session.phase == CombatSession.PHASE_LOST:
		var app = get_tree().root.get_node("App")
		app.game.current_run.failed = true
		app.game.router.go_to(SceneRouterScript.SUMMARY)
