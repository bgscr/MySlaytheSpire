class_name EventRunner
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventDef := preload("res://scripts/data/event_def.gd")
const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const RewardGenerator := preload("res://scripts/reward/reward_generator.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func is_option_available(run: RunState, option: EventOptionDef) -> bool:
	if run == null or option == null:
		return false
	if run.current_hp < option.min_hp or run.gold < option.min_gold:
		return false
	if not option.remove_card_id.is_empty() and not run.deck_ids.has(option.remove_card_id):
		return false
	return true

func unavailable_reason(run: RunState, option: EventOptionDef) -> String:
	if run == null or option == null:
		return "Unavailable"
	if run.current_hp < option.min_hp:
		return "Requires %s HP" % option.min_hp
	if run.gold < option.min_gold:
		return "Requires %s gold" % option.min_gold
	if not option.remove_card_id.is_empty() and not run.deck_ids.has(option.remove_card_id):
		return "Requires card %s" % option.remove_card_id
	return ""

func apply_option(run: RunState, option: EventOptionDef) -> bool:
	if not is_option_available(run, option):
		return false
	run.current_hp = clamp(run.current_hp + option.hp_delta, 1, run.max_hp)
	run.gold = max(0, run.gold + option.gold_delta)
	return true

func apply_event_option(
	catalog: ContentCatalog,
	run: RunState,
	event: EventDef,
	option: EventOptionDef
) -> bool:
	if catalog == null or run == null or event == null or option == null:
		return false
	if not is_option_available(run, option):
		return false

	_apply_run_deltas(run, option)
	_remove_selected_card(run, option)
	_grant_direct_cards(catalog, run, option)
	_grant_direct_relics(catalog, run, option)
	_build_pending_rewards(catalog, run, event, option)
	return true

func _apply_run_deltas(run: RunState, option: EventOptionDef) -> void:
	run.current_hp = clamp(run.current_hp + option.hp_delta, 1, run.max_hp)
	run.gold = max(0, run.gold + option.gold_delta)

func _remove_selected_card(run: RunState, option: EventOptionDef) -> void:
	if option.remove_card_id.is_empty():
		return
	run.deck_ids.erase(option.remove_card_id)

func _grant_direct_cards(catalog: ContentCatalog, run: RunState, option: EventOptionDef) -> void:
	for card_id in option.grant_card_ids:
		if catalog.get_card(card_id) != null:
			run.deck_ids.append(card_id)

func _grant_direct_relics(catalog: ContentCatalog, run: RunState, option: EventOptionDef) -> void:
	for relic_id in option.grant_relic_ids:
		if catalog.get_relic(relic_id) != null and not run.relic_ids.has(relic_id):
			run.relic_ids.append(relic_id)

func _build_pending_rewards(
	catalog: ContentCatalog,
	run: RunState,
	event: EventDef,
	option: EventOptionDef
) -> void:
	run.current_reward_state = {}
	var rewards: Array[Dictionary] = []
	var generator := RewardGenerator.new()
	var context_key := _reward_context_key(run, event, option)

	if option.card_reward_count > 0:
		var card_reward := generator.generate_card_reward(
			catalog,
			run.seed_value,
			run.character_id,
			context_key,
			option.card_reward_count
		)
		var card_ids: Array = card_reward.get("card_ids", [])
		if not card_ids.is_empty():
			rewards.append({
				"id": "event-card:%s:%s" % [run.current_node_id, option.id],
				"type": "card_choice",
				"card_ids": card_ids,
			})

	if not option.relic_reward_tier.is_empty():
		var relic_reward := generator.generate_relic_reward(
			catalog,
			run.seed_value,
			context_key,
			option.relic_reward_tier
		)
		var relic_id := String(relic_reward.get("relic_id", ""))
		if not relic_id.is_empty():
			rewards.append({
				"id": "event-relic:%s:%s" % [run.current_node_id, option.id],
				"type": "relic",
				"relic_id": relic_id,
				"tier": option.relic_reward_tier,
			})

	if rewards.is_empty():
		return

	run.current_reward_state = {
		"source": "event",
		"node_id": run.current_node_id,
		"event_id": event.id,
		"option_id": option.id,
		"rewards": rewards,
	}

func _reward_context_key(run: RunState, event: EventDef, option: EventOptionDef) -> String:
	if not option.reward_context.is_empty():
		return option.reward_context
	return "%s:%s:%s" % [run.current_node_id, event.id, option.id]
