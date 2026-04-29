class_name RewardApplier
extends RefCounted

const RunState := preload("res://scripts/run/run_state.gd")

func claim_card(run: RunState, reward: Dictionary, card_index: int) -> bool:
	if run == null or String(reward.get("type", "")) != "card_choice":
		return false
	var card_ids: Array = reward.get("card_ids", [])
	if card_index < 0 or card_index >= card_ids.size():
		return false
	var card_id := String(card_ids[card_index])
	if card_id.is_empty():
		return false
	run.deck_ids.append(card_id)
	return true

func claim_gold(run: RunState, reward: Dictionary) -> bool:
	if run == null or String(reward.get("type", "")) != "gold":
		return false
	var amount := int(reward.get("amount", 0))
	if amount <= 0:
		return false
	run.gold += amount
	return true

func claim_relic(run: RunState, reward: Dictionary) -> bool:
	if run == null or String(reward.get("type", "")) != "relic":
		return false
	var relic_id := String(reward.get("relic_id", ""))
	if relic_id.is_empty():
		return false
	if not run.relic_ids.has(relic_id):
		run.relic_ids.append(relic_id)
	return true
