# Relic Trigger Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make owned relics apply their existing `trigger_event` effects during combat.

**Architecture:** Add a focused `RelicRuntime` that accepts `GameEvent` objects, reads `RunState.relic_ids`, resolves `RelicDef` resources through `ContentCatalog`, and executes matching effects through `EffectExecutor`. `CombatSession` calls this runtime directly at explicit lifecycle points now, while preserving an easy future migration to global `EventBus` dispatch.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resource `.tres` files, custom headless test runner.

---

## Execution Context

The user explicitly prefers continuing development directly on local `main`, without worktrees.

Before starting implementation, verify:

```powershell
git branch --show-current
git status --short
```

Expected:

```text
main
```

and no unstaged or staged changes unless they belong to this plan.

## Scope Check

This plan implements `docs/superpowers/specs/2026-04-27-relic-trigger-runtime-design.md`.

Included:

- New `scripts/relic/relic_runtime.gd`.
- New `tests/unit/test_relic_runtime.gd`.
- Register the new relic runtime test in `scripts/testing/test_runner.gd`.
- Integrate `RelicRuntime` with `scripts/combat/combat_session.gd`.
- Extend `tests/unit/test_combat_session.gd` for real relic effects in combat.
- Update `README.md` Phase 2 progress after acceptance.
- Update this plan's execution status after acceptance.

Excluded:

- No global `EventBus` wiring.
- No new relic resource fields.
- No new effect types.
- No save schema changes.
- No event scene, shop scene, achievement callback, presentation animation, or relic reward selection UI.

## File Structure

Create:

- `scripts/relic/relic_runtime.gd`: event-shaped runtime for owned relic triggers.
- `tests/unit/test_relic_runtime.gd`: focused unit coverage for trigger matching and one-shot guards.

Modify:

- `scripts/testing/test_runner.gd`: register `test_relic_runtime.gd`.
- `scripts/combat/combat_session.gd`: call `RelicRuntime` at combat lifecycle points.
- `tests/unit/test_combat_session.gd`: add integration tests using actual relic resources.
- `README.md`: record Phase 2 relic trigger runtime progress.
- `docs/superpowers/plans/2026-04-27-relic-trigger-runtime.md`: mark completed steps.

## Task 1: Add RelicRuntime Unit Coverage and Runtime

**Files:**

- Create: `tests/unit/test_relic_runtime.gd`
- Modify: `scripts/testing/test_runner.gd`
- Create: `scripts/relic/relic_runtime.gd`

- [ ] **Step 1: Register the new test file**

Modify `scripts/testing/test_runner.gd` and insert the relic runtime test after `test_reward_generator.gd`:

```gdscript
const TEST_FILES := [
	"res://tests/unit/test_rng_service.gd",
	"res://tests/unit/test_resource_schemas.gd",
	"res://tests/unit/test_content_catalog.gd",
	"res://tests/unit/test_reward_generator.gd",
	"res://tests/unit/test_relic_runtime.gd",
	"res://tests/unit/test_encounter_generator.gd",
	"res://tests/unit/test_scene_router.gd",
	"res://tests/unit/test_map_generator.gd",
	"res://tests/unit/test_run_state.gd",
	"res://tests/unit/test_combat_engine.gd",
	"res://tests/unit/test_combat_session.gd",
	"res://tests/unit/test_save_service.gd",
	"res://tests/smoke/test_scene_flow.gd",
]
```

- [ ] **Step 2: Write failing RelicRuntime tests**

Create `tests/unit/test_relic_runtime.gd`:

```gdscript
extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const GameEvent := preload("res://scripts/core/game_event.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const RelicRuntime := preload("res://scripts/relic/relic_runtime.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_combat_started_applies_matching_relic_block() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_started", [
		_effect("block", 4, "player"),
	])
	var run := _run_with_relics(["test.block"])
	var state := _combat_state()
	RelicRuntime.new().handle_event(GameEvent.new("combat_started"), catalog, run, state)
	var passed := state.player.block == 4
	assert(passed)
	return passed

func test_missing_relic_ids_are_ignored() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_started", [
		_effect("block", 4, "player"),
	])
	var run := _run_with_relics(["missing.relic", "test.block"])
	var state := _combat_state()
	RelicRuntime.new().handle_event(GameEvent.new("combat_started"), catalog, run, state)
	var passed := state.player.block == 4
	assert(passed)
	return passed

func test_non_matching_trigger_does_not_apply() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_started", [
		_effect("block", 4, "player"),
	])
	var run := _run_with_relics(["test.block"])
	var state := _combat_state()
	RelicRuntime.new().handle_event(GameEvent.new("turn_started"), catalog, run, state)
	var passed := state.player.block == 0
	assert(passed)
	return passed

func test_combat_started_applies_only_once() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_started", [
		_effect("block", 4, "player"),
	])
	var run := _run_with_relics(["test.block"])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	runtime.handle_event(GameEvent.new("combat_started"), catalog, run, state)
	runtime.handle_event(GameEvent.new("combat_started"), catalog, run, state)
	var passed := state.player.block == 4
	assert(passed)
	return passed

func test_combat_won_applies_only_once() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.gold"] = _relic("test.gold", "combat_won", [
		_effect("gain_gold", 8, "player"),
	])
	var run := _run_with_relics(["test.gold"])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	runtime.handle_event(GameEvent.new("combat_won"), catalog, run, state)
	runtime.handle_event(GameEvent.new("combat_won"), catalog, run, state)
	var passed := state.gold_delta == 8
	assert(passed)
	return passed

func test_turn_started_applies_every_time() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.energy"] = _relic("test.energy", "turn_started", [
		_effect("gain_energy", 1, "player"),
	])
	var run := _run_with_relics(["test.energy"])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	runtime.handle_event(GameEvent.new("turn_started"), catalog, run, state)
	runtime.handle_event(GameEvent.new("turn_started"), catalog, run, state)
	var passed := state.energy == 5
	assert(passed)
	return passed

func test_apply_status_effects_stack_on_player() -> bool:
	var catalog := ContentCatalog.new()
	var focus := _effect("apply_status", 2, "player")
	focus.status_id = "sword_focus"
	var more_focus := _effect("apply_status", 1, "player")
	more_focus.status_id = "sword_focus"
	catalog.relics_by_id["test.focus"] = _relic("test.focus", "combat_started", [focus])
	catalog.relics_by_id["test.more_focus"] = _relic("test.more_focus", "combat_started", [more_focus])
	var run := _run_with_relics(["test.focus", "test.more_focus"])
	var state := _combat_state()
	RelicRuntime.new().handle_event(GameEvent.new("combat_started"), catalog, run, state)
	var passed := state.player.statuses.get("sword_focus", 0) == 3
	assert(passed)
	return passed

func _combat_state() -> CombatState:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.energy = 3
	return state

func _run_with_relics(relic_ids: Array[String]) -> RunState:
	var run := RunState.new()
	run.relic_ids = relic_ids
	return run

func _relic(relic_id: String, trigger_event: String, effects: Array[EffectDef]) -> RelicDef:
	var relic := RelicDef.new()
	relic.id = relic_id
	relic.trigger_event = trigger_event
	relic.effects = effects
	return relic

func _effect(effect_type: String, amount: int, target: String) -> EffectDef:
	var effect := EffectDef.new()
	effect.effect_type = effect_type
	effect.amount = amount
	effect.target = target
	return effect
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: the new test file fails to load because `res://scripts/relic/relic_runtime.gd` does not exist.

- [ ] **Step 4: Implement RelicRuntime**

Create `scripts/relic/relic_runtime.gd`:

```gdscript
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
	if _is_once_event_already_applied(event.type):
		return
	for relic_id in run.relic_ids:
		var relic := catalog.get_relic(relic_id)
		if relic == null:
			continue
		if relic.trigger_event == event.type:
			_apply_relic(relic, state)
	_mark_once_event_applied(event.type)

func _apply_relic(relic: RelicDef, state: CombatState) -> void:
	for effect: EffectDef in relic.effects:
		executor.execute_in_state(effect, state, state.player, state.player)

func _is_once_event_already_applied(event_type: String) -> bool:
	return ONCE_PER_COMBAT_EVENTS.has(event_type) and applied_once_events.has(event_type)

func _mark_once_event_applied(event_type: String) -> void:
	if ONCE_PER_COMBAT_EVENTS.has(event_type):
		applied_once_events[event_type] = true
```

- [ ] **Step 5: Run tests and verify GREEN for RelicRuntime**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `test_relic_runtime.gd` runs and passes. Other tests should remain green.

- [ ] **Step 6: Run Task 1 review gates**

Stage 1 Spec Compliance Review:

- Confirm `RelicRuntime.handle_event(...)` takes `GameEvent`.
- Confirm no global `EventBus` wiring was added.
- Confirm one-shot events are `combat_started` and `combat_won`.
- Confirm `turn_started` can repeat.
- Confirm missing relic ids are ignored.

Stage 2 Code Quality Review:

- Check `RelicRuntime` has no UI, scene, save, or reward generator dependencies.
- Check tests return `bool`.
- Check helper variables and function returns are typed.
- Classify issues as Critical, Important, or Minor.

- [ ] **Step 7: Commit Task 1**

```powershell
git add scripts/relic/relic_runtime.gd scripts/testing/test_runner.gd tests/unit/test_relic_runtime.gd
git commit -m "feat: add event-shaped relic runtime"
```

## Task 2: Integrate RelicRuntime Into CombatSession

**Files:**

- Modify: `scripts/combat/combat_session.gd`
- Modify: `tests/unit/test_combat_session.gd`

- [ ] **Step 1: Add failing CombatSession relic integration tests**

Append these tests to `tests/unit/test_combat_session.gd` after `test_player_death_sets_lost_and_failed_run`:

```gdscript
func test_combat_started_relics_apply_current_resource_effects() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.cloud_step",
	])
	run.relic_ids = [
		"jade_talisman",
		"bronze_incense_burner",
		"moonwell_seed",
		"dragon_bone_flute",
	]
	var session := CombatSession.new()
	session.start(catalog, run)
	var passed: bool = session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.player.block == 7 \
		and session.state.player.current_hp == 67 \
		and session.state.player.statuses.get("sword_focus", 0) == 2
	assert(passed)
	return passed

func test_turn_started_relic_applies_on_first_turn() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.cloud_step",
	])
	run.relic_ids = ["thunderseal_charm"]
	var session := CombatSession.new()
	session.start(catalog, run)
	var passed: bool = session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.energy == 4
	assert(passed)
	return passed

func test_turn_started_relic_applies_after_enemy_turn() -> bool:
	var catalog := _catalog_with_low_hp_enemy()
	var run := _run_with_single_node("node_0", "combat", [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.cloud_step",
	])
	run.relic_ids = ["thunderseal_charm"]
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.guard"]
	session.state.draw_pile = [
		"sword.strike",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.cloud_step",
		"sword.guard",
	]
	var ended := session.end_player_turn()
	var passed: bool = ended \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.turn == 2 \
		and session.state.energy == 4
	assert(passed)
	return passed

func test_combat_won_relic_adds_gold_once() -> bool:
	var catalog := _catalog_with_low_hp_enemy()
	var run := _run_with_single_node("node_0", "combat", ["test.execute"])
	run.relic_ids = ["cracked_spirit_coin"]
	run.gold = 5
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["test.execute"]
	session.state.draw_pile.clear()
	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(0)
	session._finish_win()
	var passed: bool = selected \
		and confirmed \
		and session.phase == CombatSession.PHASE_WON \
		and run.gold == 13
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: the new CombatSession tests fail because relic triggers are not integrated into combat yet.

- [ ] **Step 3: Add relic runtime dependencies to CombatSession**

Modify the preload section of `scripts/combat/combat_session.gd` to include:

```gdscript
const GameEvent := preload("res://scripts/core/game_event.gd")
const RelicRuntime := preload("res://scripts/relic/relic_runtime.gd")
```

Add this property near the existing runtime state:

```gdscript
var relic_runtime := RelicRuntime.new()
```

In `start(...)`, after `engine = CombatEngine.new()`, reset the runtime:

```gdscript
relic_runtime.reset()
```

- [ ] **Step 4: Add CombatSession relic event helper and player turn helper**

Add these functions to `scripts/combat/combat_session.gd` near `_resolve_pending_draws()`:

```gdscript
func _start_player_turn() -> void:
	_handle_relic_event("turn_started")
	_resolve_pending_draws()
	if _update_terminal_phase():
		return
	draw_cards(5)
	phase = PHASE_PLAYER_TURN

func _handle_relic_event(event_type: String) -> void:
	relic_runtime.handle_event(GameEvent.new(event_type), catalog, run, state)
```

- [ ] **Step 5: Trigger relics during combat initialization**

In `_initialize_from_run()`, replace the final lines:

```gdscript
	draw_cards(5)
	phase = PHASE_PLAYER_TURN
```

with:

```gdscript
	_handle_relic_event("combat_started")
	_resolve_pending_draws()
	_start_player_turn()
```

This applies combat-start relics after player and enemies exist, then applies the first turn-start relics before the initial 5-card draw.

- [ ] **Step 6: Trigger turn-start relics after enemy turns**

In `end_player_turn()`, replace:

```gdscript
	draw_cards(5)
	_update_terminal_phase()
	if phase != PHASE_WON and phase != PHASE_LOST:
		phase = PHASE_PLAYER_TURN
	return true
```

with:

```gdscript
	_start_player_turn()
	return true
```

- [ ] **Step 7: Trigger combat-won relics before terminal gold is applied**

In `_finish_win()`, replace:

```gdscript
	if not terminal_rewards_applied:
		run.gold += state.gold_delta
		terminal_rewards_applied = true
```

with:

```gdscript
	if not terminal_rewards_applied:
		_handle_relic_event("combat_won")
		_resolve_pending_draws()
		run.gold += state.gold_delta
		terminal_rewards_applied = true
```

- [ ] **Step 8: Run tests and verify GREEN**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all tests pass, including the new CombatSession relic integration tests.

- [ ] **Step 9: Run Godot import check**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

Expected: exit 0 with no parse errors or missing resources.

- [ ] **Step 10: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- Confirm `combat_started`, `turn_started`, and `combat_won` are all triggered from `CombatSession`.
- Confirm `combat_started` and `combat_won` are one-shot through `RelicRuntime`.
- Confirm `turn_started` applies on turn 1 and later player turns.
- Confirm no global `EventBus`, save schema, shop, event scene, presentation animation, or new effect type was added.

Stage 2 Code Quality Review:

- Check lifecycle placement is explicit and readable.
- Check `_start_player_turn()` does not hide terminal transitions.
- Check `_finish_win()` still uses `terminal_rewards_applied` to prevent duplicate gold.
- Check tests are deterministic and use actual Wave 1 relic resources for jade, bronze incense, moonwell, dragon flute, thunderseal, and cracked coin behavior.
- Classify issues as Critical, Important, or Minor.

- [ ] **Step 11: Commit Task 2**

```powershell
git add scripts/combat/combat_session.gd tests/unit/test_combat_session.gd
git commit -m "feat: trigger owned relics during combat"
```

## Task 3: Acceptance Docs and Final Verification

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-27-relic-trigger-runtime.md`

- [ ] **Step 1: Update README Phase 2 progress**

Add this bullet under `## Phase 2 Progress` in `README.md`:

```markdown
- Relic trigger runtime: complete; owned relics now react to combat start, player turn start, and combat win events through an event-shaped runtime
```

- [ ] **Step 2: Mark plan steps complete**

Update completed checkboxes in `docs/superpowers/plans/2026-04-27-relic-trigger-runtime.md` from `[ ]` to `[x]`.

Only mark a step complete after its command or review has actually happened.

- [ ] **Step 3: Run final full tests**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 4: Run final import check**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

Expected: exit 0 with no parse errors or missing resources.

- [ ] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Verify every acceptance criterion in `docs/superpowers/specs/2026-04-27-relic-trigger-runtime-design.md`.
- Do not proceed to quality review if any requirement is missing.

Stage 2 Code Quality Review:

- Check GDScript typing, signal boundaries, node independence, resource loading, duplication, and maintainability.
- Classify all issues as Critical, Important, or Minor.

- [ ] **Step 6: Commit acceptance docs**

```powershell
git add README.md docs/superpowers/plans/2026-04-27-relic-trigger-runtime.md
git commit -m "docs: record relic trigger runtime acceptance"
```

## Acceptance Criteria

- Runs with `relic_ids` apply matching relic effects during combat.
- `combat_started` relics apply once per combat.
- `turn_started` relics apply once per player turn.
- `combat_won` relics apply once per combat win.
- `thunderseal_charm` makes player turns start with 4 energy.
- `cracked_spirit_coin` adds 8 gold on combat win and cannot double-apply.
- Existing card effects and enemy turns still behave as before.
- Existing saves remain compatible.
- No global `EventBus` subscription system is required in this stage.
- Godot tests pass.
- Godot import check exits 0.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-27-relic-trigger-runtime.md`.

Recommended execution: **Subagent-Driven** if using subagents. Per `AGENTS.md`, every development subagent must use extra-high 5.5 only.

User preference for this session: continue directly on local `main`, without worktrees.
