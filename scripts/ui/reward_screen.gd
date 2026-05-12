extends Control

const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const ItemDetailPanel := preload("res://scripts/ui/item_detail_panel.gd")
const ItemVisualPresenter := preload("res://scripts/ui/item_visual_presenter.gd")
const RewardApplier := preload("res://scripts/reward/reward_applier.gd")
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")

const STATE_AVAILABLE := "available"
const STATE_CLAIMED := "claimed"
const STATE_SKIPPED := "skipped"

var catalog: ContentCatalog
var rewards: Array[Dictionary] = []
var reward_states: Array[String] = []
var title_label: Label
var status_label: Label
var reward_container: VBoxContainer
var continue_button: Button
var item_detail_panel: ItemDetailPanel
var advance_requested := false
var reward_applier := RewardApplier.new()

func _ready() -> void:
	_build_layout()
	_load_rewards()
	_render_rewards()
	_refresh_continue_button()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "RewardTitle"
	title_label.text = tr("ui.reward.title")
	UiStyle.apply_title(title_label)
	add_child(title_label)

	status_label = Label.new()
	status_label.name = "RewardStatus"
	status_label.position.y = 28
	UiStyle.apply_body_label(status_label)
	add_child(status_label)

	reward_container = VBoxContainer.new()
	reward_container.name = "RewardContainer"
	reward_container.position = Vector2(16, 72)
	reward_container.size = Vector2(560, 320)
	add_child(reward_container)

	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = tr("ui.continue")
	continue_button.position = Vector2(16, 420)
	UiStyle.apply_primary_button(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

	item_detail_panel = ItemDetailPanel.new()
	item_detail_panel.position = Vector2(620, 72)
	add_child(item_detail_panel)

func _load_rewards() -> void:
	catalog = ContentCatalog.new()
	catalog.load_default()
	rewards.clear()
	reward_states.clear()

	var app = _app()
	if app == null or app.game.current_run == null:
		return
	rewards = RewardResolver.new().resolve(catalog, app.game.current_run)
	for _reward in rewards:
		reward_states.append(STATE_AVAILABLE)

func _render_rewards() -> void:
	_hide_item_detail()
	_clear_children(reward_container)
	if rewards.is_empty():
		var no_rewards := Label.new()
		no_rewards.name = "NoRewardsLabel"
		no_rewards.text = tr("ui.reward.no_rewards")
		UiStyle.apply_body_label(no_rewards)
		reward_container.add_child(no_rewards)
		return

	for reward_index in range(rewards.size()):
		var reward := rewards[reward_index]
		var item := VBoxContainer.new()
		item.name = "RewardItem_%s" % reward_index
		reward_container.add_child(item)

		var label := Label.new()
		label.name = "RewardLabel_%s" % reward_index
		label.text = _reward_label_text(reward)
		UiStyle.apply_body_label(label)
		item.add_child(label)

		var state := reward_states[reward_index]
		if state == STATE_CLAIMED or state == STATE_SKIPPED:
			var state_label := Label.new()
			state_label.text = _reward_state_text(state)
			UiStyle.apply_body_label(state_label)
			item.add_child(state_label)
			continue

		_add_reward_actions(item, reward_index, reward)

func _add_reward_actions(item: VBoxContainer, reward_index: int, reward: Dictionary) -> void:
	match String(reward.get("type", "")):
		"card_choice":
			var card_ids: Array = reward.get("card_ids", [])
			for card_index in range(card_ids.size()):
				var card_id := String(card_ids[card_index])
				var button := Button.new()
				button.name = "ClaimCard_%s_%s" % [reward_index, card_index]
				button.text = ""
				UiStyle.apply_primary_button(button)
				button.custom_minimum_size = Vector2(148, 104)
				button.pressed.connect(func(): _claim_card(reward_index, card_index))
				var theme := _visual_theme()
				ItemVisualPresenter.add_card_preview(
					button,
					"Reward",
					"%s_%s" % [reward_index, card_index],
					card_id,
					catalog,
					theme
				)
				button.mouse_entered.connect(func(): _show_card_detail(card_id))
				button.mouse_exited.connect(_hide_item_detail)
				button.focus_entered.connect(func(): _show_card_detail(card_id))
				button.focus_exited.connect(_hide_item_detail)
				item.add_child(button)
			item.add_child(_skip_button(reward_index))
		"gold":
			var gold_button := Button.new()
			gold_button.name = "ClaimGold_%s" % reward_index
			gold_button.text = tr("ui.reward.take_gold").format({"amount": int(reward.get("amount", 0))})
			UiStyle.apply_primary_button(gold_button)
			gold_button.pressed.connect(func(): _claim_gold(reward_index))
			item.add_child(gold_button)
			item.add_child(_skip_button(reward_index))
		"relic":
			var relic_button := Button.new()
			relic_button.name = "ClaimRelic_%s" % reward_index
			relic_button.text = ""
			UiStyle.apply_primary_button(relic_button)
			relic_button.custom_minimum_size = Vector2(128, 104)
			var relic_id := String(reward.get("relic_id", ""))
			ItemVisualPresenter.add_relic_preview(relic_button, "Reward", str(reward_index), relic_id, catalog)
			relic_button.mouse_entered.connect(func(): _show_relic_detail(relic_id))
			relic_button.mouse_exited.connect(_hide_item_detail)
			relic_button.focus_entered.connect(func(): _show_relic_detail(relic_id))
			relic_button.focus_exited.connect(_hide_item_detail)
			relic_button.pressed.connect(func(): _claim_relic(reward_index))
			item.add_child(relic_button)
			item.add_child(_skip_button(reward_index))
		_:
			item.add_child(_skip_button(reward_index))

func _skip_button(reward_index: int) -> Button:
	var button := Button.new()
	button.name = "SkipReward_%s" % reward_index
	button.text = tr("ui.reward.skip")
	UiStyle.apply_secondary_button(button)
	button.pressed.connect(func(): _skip_reward(reward_index))
	return button

func _claim_card(reward_index: int, card_index: int) -> void:
	if not _is_reward_available(reward_index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if reward_applier.claim_card(app.game.current_run, rewards[reward_index], card_index):
		reward_states[reward_index] = STATE_CLAIMED
		_render_rewards()
		_refresh_continue_button()

func _claim_gold(reward_index: int) -> void:
	if not _is_reward_available(reward_index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if reward_applier.claim_gold(app.game.current_run, rewards[reward_index]):
		reward_states[reward_index] = STATE_CLAIMED
		_render_rewards()
		_refresh_continue_button()

func _claim_relic(reward_index: int) -> void:
	if not _is_reward_available(reward_index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if reward_applier.claim_relic(app.game.current_run, rewards[reward_index]):
		reward_states[reward_index] = STATE_CLAIMED
		_render_rewards()
		_refresh_continue_button()

func _skip_reward(reward_index: int) -> void:
	if not _is_reward_available(reward_index):
		return
	reward_states[reward_index] = STATE_SKIPPED
	_render_rewards()
	_refresh_continue_button()

func _on_continue_pressed() -> void:
	if advance_requested:
		return
	if not _all_rewards_resolved():
		_refresh_continue_button()
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	advance_requested = true
	if continue_button != null:
		continue_button.disabled = true
	var clear_event_reward_state := _has_pending_event_rewards(app.game.current_run)
	if clear_event_reward_state:
		app.game.current_run.current_reward_state.clear()
	if not RunProgression.new().advance_current_node(app.game.current_run):
		push_error("Cannot advance run; current map node is missing.")
		return
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouterScript.SUMMARY)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _is_reward_available(reward_index: int) -> bool:
	return reward_index >= 0 \
		and reward_index < reward_states.size() \
		and reward_states[reward_index] == STATE_AVAILABLE

func _all_rewards_resolved() -> bool:
	for state in reward_states:
		if state == STATE_AVAILABLE:
			return false
	return true

func _has_pending_event_rewards(run: RunStateScript) -> bool:
	return run != null \
		and not run.current_reward_state.is_empty() \
		and String(run.current_reward_state.get("source", "")) == "event"

func _refresh_continue_button() -> void:
	if continue_button == null:
		return
	continue_button.disabled = advance_requested or not _all_rewards_resolved()
	if rewards.is_empty():
		status_label.text = tr("ui.reward.no_rewards_available")
	elif continue_button.disabled:
		status_label.text = tr("ui.reward.resolve_prompt")
	else:
		status_label.text = tr("ui.reward.resolved")

func _reward_label_text(reward: Dictionary) -> String:
	match String(reward.get("type", "")):
		"card_choice":
			return tr("ui.reward.choose_one_card")
		"gold":
			return tr("ui.reward.gold_label").format({"amount": int(reward.get("amount", 0))})
		"relic":
			return tr("ui.reward.relic_label").format({"name": UiText.relic_name(catalog, String(reward.get("relic_id", "")))})
	return tr("ui.common.unknown_reward")

func _reward_state_text(state: String) -> String:
	match state:
		STATE_CLAIMED:
			return tr("ui.reward.state_claimed")
		STATE_SKIPPED:
			return tr("ui.reward.state_skipped")
	return state.capitalize()

func _card_text(card_id: String) -> String:
	if catalog == null:
		return card_id
	var card = catalog.get_card(card_id)
	if card == null:
		return card_id
	return "%s [%s] (%s)" % [card.id, card.card_type, card.cost]

func _visual_theme() -> Dictionary:
	var app = _app()
	if app == null or app.game.current_run == null or catalog == null:
		return {}
	return CombatVisualResolver.new().resolve_theme(app.game.current_run.character_id, catalog)

func _show_card_detail(card_id: String) -> void:
	if item_detail_panel != null:
		item_detail_panel.show_card(card_id, catalog, _visual_theme())

func _show_relic_detail(relic_id: String) -> void:
	if item_detail_panel != null:
		item_detail_panel.show_relic(relic_id, catalog)

func _hide_item_detail() -> void:
	if item_detail_panel != null:
		item_detail_panel.hide_detail()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _app():
	return get_tree().root.get_node_or_null("App")
