extends Control

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const ItemDetailPanel := preload("res://scripts/ui/item_detail_panel.gd")
const ItemVisualPresenter := preload("res://scripts/ui/item_visual_presenter.gd")
const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const ShopResolver := preload("res://scripts/shop/shop_resolver.gd")
const ShopRunner := preload("res://scripts/shop/shop_runner.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")

var catalog: ContentCatalog
var resolver := ShopResolver.new()
var runner := ShopRunner.new()
var title_label: Label
var gold_label: Label
var status_label: Label
var offer_container: VBoxContainer
var removal_container: VBoxContainer
var refresh_button: Button
var leave_button: Button
var item_detail_panel: ItemDetailPanel
var selected_remove_offer_id := ""
var leave_requested := false

func _ready() -> void:
	_build_layout()
	_load_shop()
	_render()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "ShopTitle"
	title_label.text = tr("ui.shop.title")
	UiStyle.apply_title(title_label)
	add_child(title_label)

	gold_label = Label.new()
	gold_label.name = "ShopGoldLabel"
	gold_label.position.y = 28
	UiStyle.apply_body_label(gold_label)
	add_child(gold_label)

	status_label = Label.new()
	status_label.name = "ShopStatusLabel"
	status_label.position.y = 52
	UiStyle.apply_body_label(status_label)
	add_child(status_label)

	offer_container = VBoxContainer.new()
	offer_container.name = "ShopOfferContainer"
	offer_container.position = Vector2(16, 88)
	offer_container.size = Vector2(640, 320)
	UiStyle.apply_panel(offer_container)
	add_child(offer_container)

	removal_container = VBoxContainer.new()
	removal_container.name = "ShopRemovalContainer"
	removal_container.position = Vector2(680, 88)
	removal_container.size = Vector2(320, 320)
	UiStyle.apply_panel(removal_container)
	add_child(removal_container)

	refresh_button = Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.position = Vector2(16, 430)
	UiStyle.apply_secondary_button(refresh_button)
	refresh_button.pressed.connect(_on_refresh_pressed)
	add_child(refresh_button)

	leave_button = Button.new()
	leave_button.name = "LeaveShopButton"
	leave_button.text = tr("ui.shop.leave")
	leave_button.position = Vector2(160, 430)
	UiStyle.apply_secondary_button(leave_button)
	leave_button.pressed.connect(_on_leave_pressed)
	add_child(leave_button)

	item_detail_panel = ItemDetailPanel.new()
	item_detail_panel.position = Vector2(1020, 88)
	add_child(item_detail_panel)

func _load_shop() -> void:
	catalog = ContentCatalog.new()
	catalog.load_default()
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	resolver.resolve(catalog, app.game.current_run)
	if resolver.created_new_state and app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)

func _render() -> void:
	_hide_item_detail()
	_clear_children(offer_container)
	_clear_children(removal_container)
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or run.current_shop_state.is_empty():
		gold_label.text = tr("ui.shop.gold").format({"amount": 0})
		status_label.text = tr("ui.shop.no_shop")
		refresh_button.disabled = true
		return
	gold_label.text = tr("ui.shop.gold").format({"amount": run.gold})
	status_label.text = ""
	for offer in run.current_shop_state.get("offers", []):
		_add_offer_row(offer as Dictionary)
	_refresh_refresh_button()
	_render_removal_choices()

func _add_offer_row(offer: Dictionary) -> void:
	var item := VBoxContainer.new()
	var offer_id := String(offer.get("id", ""))
	item.name = "ShopOffer_%s" % offer_id
	UiStyle.apply_panel(item)
	offer_container.add_child(item)

	var label := Label.new()
	label.text = _offer_label(offer)
	UiStyle.apply_body_label(label)
	item.add_child(label)

	var item_id := String(offer.get("item_id", ""))
	if String(offer.get("type", "")) == "card":
		ItemVisualPresenter.add_card_preview(item, "ShopOffer", offer_id, item_id, catalog, _visual_theme())
	elif String(offer.get("type", "")) == "relic":
		ItemVisualPresenter.add_relic_preview(item, "ShopOffer", offer_id, item_id, catalog)

	if bool(offer.get("sold", false)):
		var sold_label := Label.new()
		sold_label.text = tr("ui.shop.sold_out")
		UiStyle.apply_body_label(sold_label)
		item.add_child(sold_label)
		return

	var button := Button.new()
	button.name = "BuyOffer_%s" % offer_id
	button.text = _buy_button_text(offer)
	UiStyle.apply_primary_button(button)
	button.disabled = not _can_buy_offer(offer)
	button.pressed.connect(func(): _on_buy_pressed(offer_id))
	_connect_offer_detail(button, offer)
	item.add_child(button)

func _offer_label(offer: Dictionary) -> String:
	var offer_type := String(offer.get("type", ""))
	var item_id := String(offer.get("item_id", ""))
	var price := int(offer.get("price", 0))
	match offer_type:
		"card":
			var card = catalog.get_card(item_id)
			if card != null:
				return tr("ui.shop.card_offer").format({
					"name": UiText.card_name(catalog, item_id),
					"rarity": tr("rarity.%s" % card.rarity),
					"cost": card.cost,
					"price": price,
				})
			return tr("ui.shop.card_offer").format({
				"name": item_id,
				"rarity": "?",
				"cost": "?",
				"price": price,
			})
		"relic":
			var relic = catalog.get_relic(item_id)
			if relic != null:
				return tr("ui.shop.relic_offer").format({
					"name": UiText.relic_name(catalog, item_id),
					"tier": tr("relic_tier.%s" % relic.tier),
					"price": price,
				})
			return tr("ui.shop.relic_offer").format({
				"name": item_id,
				"tier": "?",
				"price": price,
			})
		"heal":
			return tr("ui.shop.heal_offer").format({"price": price})
		"remove":
			return tr("ui.shop.remove_offer").format({"price": price})
	return tr("ui.shop.unknown_offer")

func _buy_button_text(offer: Dictionary) -> String:
	return tr("ui.shop.choose_card") if String(offer.get("type", "")) == "remove" else tr("ui.shop.buy")

func _can_buy_offer(offer: Dictionary) -> bool:
	var app = _app()
	var run = app.game.current_run if app != null else null
	var offer_type := String(offer.get("type", ""))
	if offer_type == "remove":
		return runner.can_buy_offer(catalog, run, String(offer.get("id", "")), _first_removable_card(run))
	return runner.can_buy_offer(catalog, run, String(offer.get("id", "")))

func _on_buy_pressed(offer_id: String) -> void:
	var offer := _find_offer(offer_id)
	if String(offer.get("type", "")) == "remove":
		selected_remove_offer_id = offer_id
		_render()
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if runner.buy_offer(catalog, app.game.current_run, offer_id):
		_save_and_render(app)

func _render_removal_choices() -> void:
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or selected_remove_offer_id.is_empty():
		return
	var label := Label.new()
	label.text = tr("ui.shop.choose_remove_card")
	UiStyle.apply_body_label(label)
	removal_container.add_child(label)
	for i in range(run.deck_ids.size()):
		var card_id := String(run.deck_ids[i])
		var button := Button.new()
		button.name = "RemoveCard_%s" % i
		button.text = ""
		UiStyle.apply_primary_button(button)
		button.custom_minimum_size = Vector2(148, 104)
		ItemVisualPresenter.add_card_preview(
			button,
			"ShopRemove",
			str(i),
			card_id,
			catalog,
			_visual_theme()
		)
		button.mouse_entered.connect(func(): _show_card_detail(card_id))
		button.mouse_exited.connect(_hide_item_detail)
		button.focus_entered.connect(func(): _show_card_detail(card_id))
		button.focus_exited.connect(_hide_item_detail)
		button.pressed.connect(func(): _on_remove_card_pressed(card_id))
		removal_container.add_child(button)

func _on_remove_card_pressed(card_id: String) -> void:
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if runner.buy_offer(catalog, app.game.current_run, selected_remove_offer_id, card_id):
		selected_remove_offer_id = ""
		_save_and_render(app)

func _on_refresh_pressed() -> void:
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if runner.refresh(catalog, app.game.current_run):
		_save_and_render(app)

func _refresh_refresh_button() -> void:
	var app = _app()
	var run = app.game.current_run if app != null else null
	refresh_button.text = tr("ui.shop.refresh").format({"price": ShopResolver.REFRESH_PRICE})
	refresh_button.disabled = not runner.can_refresh(catalog, run)

func _on_leave_pressed() -> void:
	if leave_requested:
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	leave_requested = true
	leave_button.disabled = true
	if not RunProgression.new().advance_current_node(app.game.current_run):
		push_error("Cannot advance shop; current map node is missing.")
		return
	app.game.current_run.current_shop_state = {}
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouterScript.SUMMARY)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _save_and_render(app) -> void:
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	_render()

func _find_offer(offer_id: String) -> Dictionary:
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null:
		return {}
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if String(payload.get("id", "")) == offer_id:
			return payload
	return {}

func _first_removable_card(run) -> String:
	if run == null or run.deck_ids.is_empty():
		return ""
	return String(run.deck_ids[0])

func _visual_theme() -> Dictionary:
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or catalog == null:
		return {}
	return CombatVisualResolver.new().resolve_theme(run.character_id, catalog)

func _connect_offer_detail(button: Button, offer: Dictionary) -> void:
	var offer_type := String(offer.get("type", ""))
	var item_id := String(offer.get("item_id", ""))
	if offer_type == "card":
		button.mouse_entered.connect(func(): _show_card_detail(item_id))
		button.mouse_exited.connect(_hide_item_detail)
		button.focus_entered.connect(func(): _show_card_detail(item_id))
		button.focus_exited.connect(_hide_item_detail)
	elif offer_type == "relic":
		button.mouse_entered.connect(func(): _show_relic_detail(item_id))
		button.mouse_exited.connect(_hide_item_detail)
		button.focus_entered.connect(func(): _show_relic_detail(item_id))
		button.focus_exited.connect(_hide_item_detail)

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
