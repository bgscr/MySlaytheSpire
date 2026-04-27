extends Control

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const ShopResolver := preload("res://scripts/shop/shop_resolver.gd")
const ShopRunner := preload("res://scripts/shop/shop_runner.gd")

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
var selected_remove_offer_id := ""
var leave_requested := false

func _ready() -> void:
	_build_layout()
	_load_shop()
	_render()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "ShopTitle"
	title_label.text = "Shop"
	add_child(title_label)

	gold_label = Label.new()
	gold_label.name = "ShopGoldLabel"
	gold_label.position.y = 28
	add_child(gold_label)

	status_label = Label.new()
	status_label.name = "ShopStatusLabel"
	status_label.position.y = 52
	add_child(status_label)

	offer_container = VBoxContainer.new()
	offer_container.name = "ShopOfferContainer"
	offer_container.position = Vector2(16, 88)
	offer_container.size = Vector2(640, 320)
	add_child(offer_container)

	removal_container = VBoxContainer.new()
	removal_container.name = "ShopRemovalContainer"
	removal_container.position = Vector2(680, 88)
	removal_container.size = Vector2(320, 320)
	add_child(removal_container)

	refresh_button = Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.position = Vector2(16, 430)
	refresh_button.pressed.connect(_on_refresh_pressed)
	add_child(refresh_button)

	leave_button = Button.new()
	leave_button.name = "LeaveShopButton"
	leave_button.text = "Leave"
	leave_button.position = Vector2(160, 430)
	leave_button.pressed.connect(_on_leave_pressed)
	add_child(leave_button)

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
	_clear_children(offer_container)
	_clear_children(removal_container)
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or run.current_shop_state.is_empty():
		gold_label.text = "Gold: 0"
		status_label.text = "No shop available"
		refresh_button.disabled = true
		return
	gold_label.text = "Gold: %s" % run.gold
	status_label.text = ""
	for offer in run.current_shop_state.get("offers", []):
		_add_offer_row(offer as Dictionary)
	_refresh_refresh_button()
	_render_removal_choices()

func _add_offer_row(offer: Dictionary) -> void:
	var item := VBoxContainer.new()
	var offer_id := String(offer.get("id", ""))
	item.name = "ShopOffer_%s" % offer_id
	offer_container.add_child(item)

	var label := Label.new()
	label.text = _offer_label(offer)
	item.add_child(label)

	if bool(offer.get("sold", false)):
		var sold_label := Label.new()
		sold_label.text = "Sold out"
		item.add_child(sold_label)
		return

	var button := Button.new()
	button.name = "BuyOffer_%s" % offer_id
	button.text = _buy_button_text(offer)
	button.disabled = not _can_buy_offer(offer)
	button.pressed.connect(func(): _on_buy_pressed(offer_id))
	item.add_child(button)

func _offer_label(offer: Dictionary) -> String:
	var offer_type := String(offer.get("type", ""))
	var item_id := String(offer.get("item_id", ""))
	var price := int(offer.get("price", 0))
	match offer_type:
		"card":
			var card = catalog.get_card(item_id)
			if card != null:
				return "Card: %s [%s] (%s) - %s gold" % [card.id, card.rarity, card.cost, price]
			return "Card: %s - %s gold" % [item_id, price]
		"relic":
			var relic = catalog.get_relic(item_id)
			if relic != null:
				return "Relic: %s [%s] - %s gold" % [relic.id, relic.tier, price]
			return "Relic: %s - %s gold" % [item_id, price]
		"heal":
			return "Heal - %s gold" % price
		"remove":
			return "Remove a card - %s gold" % price
	return "Unknown offer"

func _buy_button_text(offer: Dictionary) -> String:
	if String(offer.get("type", "")) == "remove":
		return "Choose card"
	return "Buy"

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
	label.text = "Choose a card to remove"
	removal_container.add_child(label)
	for i in range(run.deck_ids.size()):
		var card_id := String(run.deck_ids[i])
		var button := Button.new()
		button.name = "RemoveCard_%s" % i
		button.text = card_id
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
	refresh_button.text = "Refresh (%s gold)" % ShopResolver.REFRESH_PRICE
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

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _app():
	return get_tree().root.get_node_or_null("App")
