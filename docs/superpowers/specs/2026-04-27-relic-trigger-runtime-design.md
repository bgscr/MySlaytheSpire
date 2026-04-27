# Relic Trigger Runtime Design

Date: 2026-04-27

## Goal

Make registered relics affect combat through their existing `trigger_event` and `effects` data, while keeping the runtime shape compatible with a future shared event system.

This stage turns the Wave 1 relic pool from reward-only data into a small playable rules layer:

- `combat_started` relics apply once when combat starts.
- `turn_started` relics apply at the start of each player turn.
- `combat_won` relics apply once when combat is won.
- Relic effects reuse the existing `EffectExecutor` behavior.
- The implementation keeps a clear path to later EventBus-driven event, shop, achievement, and presentation systems.

## Current Baseline

The project already has the pieces needed for a focused relic runtime:

- `RunState.relic_ids` stores the relic ids owned by the current run.
- `RelicDef` stores `id`, localization keys, `trigger_event`, `effects`, `tier`, and `reward_weight`.
- `ContentCatalog` loads and validates relic resources.
- `EffectExecutor.execute_in_state(...)` supports the effect types current relics use:
  - `block`
  - `heal`
  - `gain_energy`
  - `gain_gold`
  - `apply_status`
- `CombatSession` owns the combat lifecycle, terminal win/loss transitions, and `terminal_rewards_applied` guard.
- `GameEvent` and `EventBus` already exist, but the combat flow does not yet use an event bus.

Current Wave 1 relics:

| Relic id | Trigger | Effect |
| --- | --- | --- |
| `jade_talisman` | `combat_started` | block 3 player |
| `bronze_incense_burner` | `combat_started` | block 4 player |
| `cracked_spirit_coin` | `combat_won` | gain_gold 8 player |
| `moonwell_seed` | `combat_started` | heal 2 player |
| `thunderseal_charm` | `turn_started` | gain_energy 1 player |
| `dragon_bone_flute` | `combat_started` | apply_status 2 sword_focus player |

## Scope

Included:

- Add a `RelicRuntime` class for applying relic triggers.
- Use `GameEvent` as the input shape for `RelicRuntime`, even though `CombatSession` calls it directly in this stage.
- Trigger supported relic events from `CombatSession`:
  - `combat_started`
  - `turn_started`
  - `combat_won`
- Add tests for event matching, missing relic ids, duplicate trigger guards, and all three supported trigger points.
- Keep the implementation deterministic and local to combat rules.
- Update README Phase 2 progress after acceptance.

Excluded:

- No global EventBus wiring in this stage.
- No new relic resource fields.
- No new effect types.
- No event scene flow.
- No shop flow.
- No achievement or platform callbacks.
- No presentation animation for relic triggers.
- No relic reward selection UI.
- No save schema change.

## Design Decision

Use an event-shaped runtime now, and defer global event dispatch until more systems need it.

`RelicRuntime` should expose a core method shaped around `GameEvent`:

```gdscript
func handle_event(event: GameEvent, catalog: ContentCatalog, run: RunState, state: CombatState) -> void:
```

`CombatSession` will call `handle_event(...)` directly:

```gdscript
relic_runtime.handle_event(GameEvent.new("combat_started"), catalog, run, state)
```

This is intentionally a middle path between a direct string-trigger helper and a full event bus.

Why not a plain helper:

- A method like `trigger("combat_started", ...)` would work now, but it would not match the rest of the project's event model.
- Later migration to `EventBus` would force API changes in relic logic.

Why not full `EventBus` now:

- Only combat needs relic triggers today.
- Global subscription lifecycle is easy to get wrong too early.
- Implicit event flow would make the current combat tests harder to reason about.

The chosen shape lets future work connect `EventBus.event_emitted` to `RelicRuntime.handle_event` without rewriting the relic application rules.

## Architecture

### New File: `scripts/relic/relic_runtime.gd`

Responsibility:

- Read owned relic ids from `RunState.relic_ids`.
- Look up each `RelicDef` in `ContentCatalog`.
- Match `RelicDef.trigger_event` against `GameEvent.type`.
- Execute matching relic effects against the current `CombatState`.
- Track per-combat one-shot trigger keys so `combat_started` and `combat_won` cannot double-apply.

Proposed class shape:

```gdscript
class_name RelicRuntime
extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
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
	if event == null or catalog == null or run == null or state == null:
		return
	if _is_once_event_already_applied(event.type):
		return
	for relic_id in run.relic_ids:
		var relic := catalog.get_relic(relic_id)
		if relic == null:
			continue
		if relic.trigger_event == event.type:
			_apply_relic(relic, state)
	_mark_once_event_applied(event.type)
```

Implementation detail:

- Missing relic ids should be ignored, not fatal. Save files may survive content changes.
- Unknown effect types remain handled by `EffectExecutor`, preserving one source of behavior.
- Relic effects target the player for the current content set. If future relics target enemies, the runtime can extend payload handling by reading `event.payload`.

### Combat Integration

Modify `scripts/combat/combat_session.gd`:

- Preload `GameEvent`.
- Preload `RelicRuntime`.
- Add `var relic_runtime := RelicRuntime.new()`.
- Reset the runtime in `start(...)`.
- Emit direct event-shaped calls at lifecycle boundaries:
  - `combat_started`: after player and enemy combatants are initialized, before initial hand draw.
  - `turn_started`: at the start of each player turn, including turn 1.
  - `combat_won`: during `_finish_win()`, before applying `state.gold_delta` to `run.gold`.

Suggested placement:

1. `_initialize_from_run()` builds `state.player`, `state.enemies`, and intent indices.
2. Call `_handle_relic_event("combat_started")`.
3. Call `_start_player_turn()`.
4. `_start_player_turn()` handles `turn_started`, resolves pending draws, then draws 5 cards only when combat is still non-terminal.

The first turn should get both `combat_started` and `turn_started` effects. This makes `thunderseal_charm` immediately visible in combat and matches the meaning of "turn started."

### Turn Start Flow

Today `CombatEngine.end_turn(state)` increments the turn, resets energy to 3, and clears player block. `CombatSession.end_player_turn()` then runs enemy actions and draws 5 cards.

With relic triggers:

```text
Player ends turn
Discard hand
CombatEngine.end_turn(state)
Enemy turn resolves
If player still alive:
  start player turn
    trigger turn_started relics
    resolve pending draws from relics
    draw 5 normal turn cards
    enter player_turn phase
```

`turn_started` happens after base energy reset. That means `thunderseal_charm` makes the player start with 4 energy, not 3.

### Draw Effects From Relics

Current relics do not draw cards, but future relics may use `draw_card`.

Rule:

- After each relic trigger, resolve `state.pending_draw_count`.
- If a `combat_started` relic draws cards, those cards appear before the normal initial 5-card draw.
- If a `turn_started` relic draws cards, those cards appear before the normal turn draw.
- If a `combat_won` relic draws cards, the pending draw is cleared but has no visible impact after terminal routing.

This preserves the existing "effects write pending draw; session resolves it" pattern from card play.

### Gold Effects From Relics

`gain_gold` already writes to `state.gold_delta`.

Rule:

- `combat_won` relic gold is added through `state.gold_delta`.
- `_finish_win()` applies `run.gold += state.gold_delta` once using the existing `terminal_rewards_applied` guard.
- This makes `cracked_spirit_coin` work without a separate reward path.

### Event Payload Future-Proofing

In this stage, `RelicRuntime` does not require payload fields.

Future events may add:

```gdscript
GameEvent.new("card_played", {
	"card_id": card.id,
	"source": state.player,
	"target": target,
})
```

The `RelicRuntime.handle_event(...)` signature already accepts `GameEvent`, so new trigger types can read `event.payload` without changing the public API.

## Data Flow

```text
CombatSession lifecycle
  -> GameEvent(type)
  -> RelicRuntime.handle_event(event, catalog, run, state)
  -> run.relic_ids
  -> ContentCatalog.get_relic(id)
  -> RelicDef.trigger_event == event.type
  -> EffectExecutor.execute_in_state(effect, state, state.player, state.player)
  -> CombatState / player changes
  -> CombatSession resolves pending draws and terminal rewards
```

For this wave, relic effects use player as both source and target. Enemy-targeting relics are out of scope until an event payload identifies a target.

## Testing Strategy

Add `tests/unit/test_relic_runtime.gd` and register it in `scripts/testing/test_runner.gd`.

Core `RelicRuntime` tests:

- `combat_started` applies matching relic block.
- Missing relic ids are ignored.
- Non-matching trigger events do not apply.
- `combat_started` only applies once after repeated events.
- `combat_won` only applies once after repeated events.
- `turn_started` applies every time.
- `gain_gold` effects update `state.gold_delta`.
- `apply_status` effects stack on the player.

Add or update `tests/unit/test_combat_session.gd`:

- Starting a combat with `jade_talisman` gives initial player block.
- Starting a combat with `thunderseal_charm` gives 4 energy on turn 1.
- Ending a turn with `thunderseal_charm` gives 4 energy on turn 2.
- Winning combat with `cracked_spirit_coin` adds gold once.
- Calling win logic twice does not double-apply `combat_won` relics.

Run full verification:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Run import check:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

## Review Gates

Stage 1: Spec Compliance Review

- Confirm `RelicRuntime` uses `GameEvent`, not plain strings.
- Confirm no global EventBus wiring is added yet.
- Confirm exactly these triggers are supported:
  - `combat_started`
  - `turn_started`
  - `combat_won`
- Confirm current relic resources all have working runtime effects.
- Confirm no save schema, shop, event scene, or presentation work is included.

Stage 2: Code Quality Review

- Check `RelicRuntime` has one responsibility and no UI dependencies.
- Check combat lifecycle trigger placement is explicit and test-covered.
- Check one-shot trigger guards are scoped to a single combat session.
- Check tests use typed helpers and bool-returning test methods.
- Check missing content is handled defensively without hiding validation errors in `ContentCatalog`.

## Acceptance Criteria

- Runs with `relic_ids` apply matching relic effects during combat.
- `combat_started` relics apply once per combat.
- `turn_started` relics apply once per player turn.
- `combat_won` relics apply once per combat win.
- `thunderseal_charm` makes player turns start with 4 energy.
- `cracked_spirit_coin` adds 8 gold on combat win and cannot double-apply.
- Existing card effects and enemy turns still behave as before.
- Existing saves remain compatible.
- No global EventBus subscription system is required in this stage.
- Godot tests pass.
- Godot import check exits 0.

## Future Expansion Path

When more systems need events, introduce a shared event dispatch layer without rewriting relic rules:

1. Add an `EventBus` instance to the app or game root.
2. Have `CombatSession` emit `GameEvent`s to the bus.
3. Connect `RelicRuntime.handle_event` to the bus with a thin adapter that supplies `catalog`, `run`, and `state`.
4. Connect presentation, achievements, event nodes, or shop systems as separate subscribers.

The public relic runtime contract remains event-shaped, so the migration changes who calls `handle_event`, not how relic effects are resolved.
