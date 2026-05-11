class_name UiText
extends RefCounted

static func label(key: String) -> String:
	return _tr(key)

static func key_value(label_key: String, value: Variant) -> String:
	return "%s: %s" % [_tr("ui.label.%s" % label_key), str(value)]

static func card_name(catalog: Object, card_id: String) -> String:
	var card = catalog.get_card(card_id) if catalog != null and catalog.has_method("get_card") else null
	if card == null:
		return _tr("ui.common.unknown_card")
	return _tr(card.name_key)

static func card_detail(catalog: Object, card_id: String) -> String:
	var card = catalog.get_card(card_id) if catalog != null and catalog.has_method("get_card") else null
	if card == null:
		return "%s\n%s" % [_tr("ui.common.unknown_card"), key_value("id", card_id)]
	return "%s\n%s\n%s\n%s" % [
		key_value("type", _tr("card_type.%s" % card.card_type)),
		key_value("rarity", _tr("rarity.%s" % card.rarity)),
		key_value("cost", card.cost),
		_tr(card.description_key),
	]

static func relic_name(catalog: Object, relic_id: String) -> String:
	var relic = catalog.get_relic(relic_id) if catalog != null and catalog.has_method("get_relic") else null
	if relic == null:
		return _tr("ui.common.unknown_relic")
	return _tr(relic.name_key)

static func relic_detail(catalog: Object, relic_id: String) -> String:
	var relic = catalog.get_relic(relic_id) if catalog != null and catalog.has_method("get_relic") else null
	if relic == null:
		return "%s\n%s" % [_tr("ui.common.unknown_relic"), key_value("id", relic_id)]
	return "%s\n%s" % [
		key_value("tier", _tr("relic_tier.%s" % relic.tier)),
		_tr(relic.description_key),
	]

static func player_summary(values: Dictionary) -> String:
	return "%s %s/%s  %s %s  %s %s  %s %s" % [
		_tr("ui.label.hp"),
		int(values.get("hp", 0)),
		int(values.get("max_hp", 0)),
		_tr("ui.label.block"),
		int(values.get("block", 0)),
		_tr("ui.label.energy"),
		int(values.get("energy", 0)),
		_tr("ui.label.turn"),
		int(values.get("turn", 0)),
	]

static func enemy_summary(catalog: Object, enemy_id: String, hp: int, max_hp: int, block: int) -> String:
	var enemy = catalog.get_enemy(enemy_id) if catalog != null and catalog.has_method("get_enemy") else null
	var name := _tr(enemy.name_key) if enemy != null else enemy_id
	return "%s  %s %s/%s  %s %s" % [
		name,
		_tr("ui.label.hp"),
		hp,
		max_hp,
		_tr("ui.label.block"),
		block,
	]

static func pile_summary(draw_count: int, discard_count: int, exhaust_count: int, phase: String) -> String:
	return "%s %s | %s %s | %s %s | %s %s" % [
		_tr("ui.combat.draw"),
		draw_count,
		_tr("ui.combat.discard"),
		discard_count,
		_tr("ui.combat.exhaust"),
		exhaust_count,
		_tr("ui.combat.phase"),
		_tr("phase.%s" % phase),
	]

static func bool_text(value: bool) -> String:
	return _tr("bool.true") if value else _tr("bool.false")

static func _tr(key: String) -> String:
	return TranslationServer.translate(key)
