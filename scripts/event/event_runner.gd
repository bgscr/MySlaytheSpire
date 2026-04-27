class_name EventRunner
extends RefCounted

const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func is_option_available(run: RunState, option: EventOptionDef) -> bool:
	if run == null or option == null:
		return false
	return run.current_hp >= option.min_hp and run.gold >= option.min_gold

func unavailable_reason(run: RunState, option: EventOptionDef) -> String:
	if run == null or option == null:
		return "Unavailable"
	if run.current_hp < option.min_hp:
		return "Requires %s HP" % option.min_hp
	if run.gold < option.min_gold:
		return "Requires %s gold" % option.min_gold
	return ""

func apply_option(run: RunState, option: EventOptionDef) -> bool:
	if not is_option_available(run, option):
		return false
	run.current_hp = clamp(run.current_hp + option.hp_delta, 1, run.max_hp)
	run.gold = max(0, run.gold + option.gold_delta)
	return true
