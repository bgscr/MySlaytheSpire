extends Control

const CombatSession := preload("res://scripts/combat/combat_session.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var session: CombatSession
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

func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_selection()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_selection()

func _build_layout() -> void:
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

func _start_session() -> void:
	var app = get_tree().root.get_node("App")
	var catalog := ContentCatalog.new()
	catalog.load_default()
	session = CombatSession.new()
	session.start(catalog, app.game.current_run)

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

func _refresh_enemies() -> void:
	_clear_children(enemy_container)
	for enemy_index in range(session.state.enemies.size()):
		var enemy = session.state.enemies[enemy_index]
		var button := Button.new()
		button.name = "EnemyButton_%s" % enemy_index
		var text := "%s HP %s/%s Block %s Intent %s" % [
			enemy.id,
			enemy.current_hp,
			enemy.max_hp,
			enemy.block,
			session.get_enemy_intent(enemy_index),
		]
		var statuses := session.status_runtime.status_display_text(enemy)
		if not statuses.is_empty():
			text += " Status %s" % statuses
		button.text = text
		button.disabled = enemy.is_defeated()
		button.pressed.connect(func(): _on_enemy_pressed(enemy_index))
		enemy_container.add_child(button)

func _refresh_hand() -> void:
	_clear_children(hand_container)
	for hand_index in range(session.state.hand.size()):
		var card_id := session.state.hand[hand_index]
		var card = session.catalog.get_card(card_id)
		var button := Button.new()
		button.name = "CardButton_%s" % hand_index
		if card == null:
			button.text = "%s (?)" % card_id
		else:
			button.text = "%s [%s] (%s)" % [card.id, card.card_type, card.cost]
		button.disabled = session.phase != CombatSession.PHASE_PLAYER_TURN
		button.pressed.connect(func(): _on_card_pressed(hand_index))
		hand_container.add_child(button)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _on_card_pressed(hand_index: int) -> void:
	session.select_card(hand_index)
	_refresh()

func _on_enemy_pressed(enemy_index: int) -> void:
	session.confirm_enemy_target(enemy_index)
	_refresh()

func _on_player_target_pressed() -> void:
	session.confirm_player_target()
	_refresh()

func _cancel_selection() -> void:
	session.cancel_selection()
	_refresh()

func _on_end_turn_pressed() -> void:
	session.end_player_turn()
	_refresh()

func _route_if_terminal() -> void:
	if session.phase == CombatSession.PHASE_WON:
		var app = get_tree().root.get_node("App")
		app.game.router.go_to(SceneRouterScript.REWARD)
	elif session.phase == CombatSession.PHASE_LOST:
		var app = get_tree().root.get_node("App")
		app.game.current_run.failed = true
		app.game.router.go_to(SceneRouterScript.SUMMARY)
