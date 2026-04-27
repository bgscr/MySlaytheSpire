class_name RelicRuntime
extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EffectExecutor := preload("res://scripts/combat/effect_executor.gd")
const GameEvent := preload("res://scripts/core/game_event.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const RunState := preload("res://scripts/run/run_state.gd")

const ONCE_PER_COMBAT_EVENTS := {
	"combat_started": true,
	"combat_won": true,
}

var executor := EffectExecutor.new()
var applied_once_events := {}

func reset() -> void:
	applied_once_events.clear()

func handle_event(event: GameEvent, catalog: ContentCatalog, run: RunState, state: CombatState) -> void:
	if event == null or catalog == null or run == null or state == null or state.player == null:
		return
	if applied_once_events.has(event.type):
		return

	for relic_id: String in run.relic_ids:
		var relic := catalog.get_relic(relic_id)
		if relic == null or relic.trigger_event != event.type:
			continue
		for effect: EffectDef in relic.effects:
			executor.execute_in_state(effect, state, state.player, state.player)

	if ONCE_PER_COMBAT_EVENTS.has(event.type):
		applied_once_events[event.type] = true
