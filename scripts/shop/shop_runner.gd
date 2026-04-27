class_name ShopRunner
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const ShopResolver := preload("res://scripts/shop/shop_resolver.gd")

func can_buy_offer(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String = "") -> bool:
	return _validate_purchase(catalog, run, offer_id, remove_card_id).is_empty()

func buy_offer(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String = "") -> bool:
	var error := _validate_purchase(catalog, run, offer_id, remove_card_id)
	if not error.is_empty():
		return false
	var offer := _find_offer(run, offer_id)
	var price := int(offer.get("price", 0))
	match String(offer.get("type", "")):
		"card":
			run.gold -= price
			run.deck_ids.append(String(offer.get("item_id", "")))
			offer["sold"] = true
			return true
		"relic":
			run.gold -= price
			run.relic_ids.append(String(offer.get("item_id", "")))
			offer["sold"] = true
			return true
		"heal":
			run.gold -= price
			run.current_hp = min(run.max_hp, run.current_hp + _heal_amount(run))
			offer["sold"] = true
			return true
		"remove":
			var index := run.deck_ids.find(remove_card_id)
			run.gold -= price
			run.deck_ids.remove_at(index)
			offer["sold"] = true
			return true
	return false

func can_refresh(catalog: ContentCatalog, run: RunState) -> bool:
	return _validate_refresh(catalog, run).is_empty()

func refresh(catalog: ContentCatalog, run: RunState) -> bool:
	var error := _validate_refresh(catalog, run)
	if not error.is_empty():
		return false
	var refreshed := ShopResolver.new().build_refreshed_item_offers(catalog, run)
	var card_index := 0
	var relic_index := 0
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if bool(payload.get("sold", false)):
			continue
		match String(payload.get("type", "")):
			"card":
				var replacement := _next_offer_of_type(refreshed, "card", card_index)
				card_index += 1
				if not replacement.is_empty():
					payload["item_id"] = replacement.get("item_id", "")
					payload["price"] = replacement.get("price", payload.get("price", 0))
			"relic":
				var replacement := _next_offer_of_type(refreshed, "relic", relic_index)
				relic_index += 1
				if not replacement.is_empty():
					payload["item_id"] = replacement.get("item_id", "")
					payload["price"] = replacement.get("price", payload.get("price", 0))
	run.gold -= ShopResolver.REFRESH_PRICE
	run.current_shop_state["refresh_used"] = true
	return true

func unavailable_reason(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String = "") -> String:
	var purchase_error := _validate_purchase(catalog, run, offer_id, remove_card_id)
	return purchase_error if not purchase_error.is_empty() else ""

func refresh_unavailable_reason(catalog: ContentCatalog, run: RunState) -> String:
	var refresh_error := _validate_refresh(catalog, run)
	return refresh_error if not refresh_error.is_empty() else ""

func _validate_purchase(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String) -> String:
	if catalog == null or run == null:
		return "Unavailable"
	if not _has_current_shop_state(run):
		return "Unavailable"
	var offer := _find_offer(run, offer_id)
	if offer.is_empty():
		return "Missing offer"
	if bool(offer.get("sold", false)):
		return "Sold out"
	var price := int(offer.get("price", 0))
	if run.gold < price:
		return "Requires %s gold" % price
	match String(offer.get("type", "")):
		"card":
			var card_id := String(offer.get("item_id", ""))
			if card_id.is_empty() or catalog.get_card(card_id) == null:
				return "Missing card"
		"relic":
			var relic_id := String(offer.get("item_id", ""))
			if relic_id.is_empty() or catalog.get_relic(relic_id) == null:
				return "Missing relic"
			if run.relic_ids.has(relic_id):
				return "Already owned"
		"heal":
			if run.current_hp >= run.max_hp:
				return "Full HP"
		"remove":
			if run.deck_ids.size() <= 1:
				return "Deck too small"
			if remove_card_id.is_empty() or not run.deck_ids.has(remove_card_id):
				return "Choose a card"
		_:
			return "Unavailable"
	return ""

func _validate_refresh(catalog: ContentCatalog, run: RunState) -> String:
	if catalog == null or run == null:
		return "Unavailable"
	if not _has_current_shop_state(run):
		return "Unavailable"
	if bool(run.current_shop_state.get("refresh_used", false)):
		return "Already refreshed"
	if run.gold < ShopResolver.REFRESH_PRICE:
		return "Requires %s gold" % ShopResolver.REFRESH_PRICE
	return ""

func _has_current_shop_state(run: RunState) -> bool:
	if run.current_shop_state.is_empty():
		return false
	var node := _current_node(run)
	return node != null \
		and node.node_type == "shop" \
		and String(run.current_shop_state.get("node_id", "")) == run.current_node_id

func _find_offer(run: RunState, offer_id: String) -> Dictionary:
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if String(payload.get("id", "")) == offer_id:
			return payload
	return {}

func _next_offer_of_type(offers: Array[Dictionary], offer_type: String, index: int) -> Dictionary:
	var seen := 0
	for offer in offers:
		if String(offer.get("type", "")) != offer_type:
			continue
		if seen == index:
			return offer
		seen += 1
	return {}

func _heal_amount(run: RunState) -> int:
	return max(8, int(floor(float(run.max_hp) * 0.2)))

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
