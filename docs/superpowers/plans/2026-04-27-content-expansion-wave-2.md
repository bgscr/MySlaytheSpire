# Content Expansion Wave 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Wave 1 into a denser playable chapter by adding status gameplay for poison, sword focus, and broken stance, plus 10 cards, 3 enemies, 6 relics, and 3 events.

**Architecture:** Add one focused `CombatStatusRuntime` as the only gameplay rules home for status ids. Wire status-aware damage through `EffectExecutor`, turn-start poison through `CombatSession`, and keep content expansion data-driven through existing Godot Resource files and `ContentCatalog`.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resource `.tres` files, gettext `.po` localization, custom headless test runner, Rust Token Killer command wrapper.

---

## Execution Context

This project must be developed directly on local `main`.

Before implementation, verify:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
main
```

and no unrelated staged or unstaged changes. Do not create worktrees or feature branches.

If using subagents, AGENTS.md requires `gpt-5.5` with extra-high reasoning for each delegated development task.

## Scope Check

This plan implements `docs/superpowers/specs/2026-04-27-content-expansion-wave-2-design.md`.

Included:

- New `CombatStatusRuntime` for `poison`, `sword_focus`, and `broken_stance`.
- Damage integration through `EffectExecutor.execute_in_state()`.
- Turn-start poison integration in `CombatSession`.
- Minimal combat UI status text using `CombatStatusRuntime.status_text()`.
- 5 new sword cards and 5 new alchemy cards.
- 3 new enemies.
- 6 new relics.
- 3 new events.
- `ContentCatalog`, character pools, localization, tests, README, and this plan status.
- Project-required two-stage review after implementation.

Excluded:

- No `StatusDef` resource database.
- No status icons, rich tooltip UI, animation, audio, VFX, or camera work.
- No new card target rules, save schema, shop system, reward system, event runtime system, or map system.
- No event deck mutation, card rewards, relic rewards, or persistent event flags.
- No enemy status intents or enemy-targeting relic event payloads.
- No release/export/CI work.

## File Structure

Create:

- `scripts/combat/combat_status_runtime.gd`: status gameplay hooks and compact status text.
- `tests/unit/test_combat_status_runtime.gd`: focused status runtime unit tests.
- `resources/cards/sword/wind_splitting_step.tres`
- `resources/cards/sword/clear_mind_guard.tres`
- `resources/cards/sword/thread_the_needle.tres`
- `resources/cards/sword/echoing_sword_heart.tres`
- `resources/cards/sword/heaven_cutting_arc.tres`
- `resources/cards/alchemy/coiling_miasma.tres`
- `resources/cards/alchemy/needle_rain.tres`
- `resources/cards/alchemy/purifying_brew.tres`
- `resources/cards/alchemy/cauldron_overflow.tres`
- `resources/cards/alchemy/golden_core_detox.tres`
- `resources/enemies/scarlet_mantis_acolyte.tres`
- `resources/enemies/jade_armor_sentinel.tres`
- `resources/enemies/boss_void_tiger.tres`
- `resources/relics/mist_vein_bracelet.tres`
- `resources/relics/verdant_antidote_gourd.tres`
- `resources/relics/copper_mantis_hook.tres`
- `resources/relics/white_tiger_tally.tres`
- `resources/relics/nine_smoke_censer.tres`
- `resources/relics/starforged_meridian.tres`
- `resources/events/sealed_sword_tomb.tres`
- `resources/events/alchemist_market.tres`
- `resources/events/spirit_beast_tracks.tres`

Modify:

- `scripts/testing/test_runner.gd`: register `test_combat_status_runtime.gd`.
- `scripts/combat/effect_executor.gd`: apply status-aware damage only when a `CombatState` exists.
- `scripts/combat/combat_session.gd`: own/share status runtime and call turn-start poison hooks.
- `scripts/ui/combat_screen.gd`: append compact status text to player and enemy labels.
- `scripts/content/content_catalog.gd`: register new resource paths.
- `resources/characters/sword_cultivator.tres`: append 5 sword card pool ids; keep starting deck unchanged.
- `resources/characters/alchemy_cultivator.tres`: append 5 alchemy card pool ids; keep starting deck unchanged.
- `localization/zh_CN.po`: add status, card, enemy, relic, and event localization keys.
- `tests/unit/test_combat_engine.gd`: cover status-aware stateful damage and plain stateless compatibility.
- `tests/unit/test_combat_session.gd`: cover poison turn-start win/loss/skip-intent behavior.
- `tests/unit/test_content_catalog.gd`: update counts and expected ids.
- `tests/unit/test_reward_generator.gd`: update expanded card/relic reward coverage.
- `tests/unit/test_encounter_generator.gd`: update default enemy tier composition.
- `tests/unit/test_event_resolver.gd`: update event pool usability ids.
- `tests/smoke/test_scene_flow.gd`: keep existing smoke passing; only update if compact status text changes assertions.
- `README.md`: record Wave 2 completion after acceptance.
- `docs/superpowers/plans/2026-04-27-content-expansion-wave-2.md`: mark steps complete during execution.

## Resource Data

Sword cards:

| id | file | type | rarity | cost | effects |
| --- | --- | --- | --- | --- | --- |
| `sword.wind_splitting_step` | `wind_splitting_step.tres` | attack | common | 1 | damage 6 enemy; apply_status 1 broken_stance enemy |
| `sword.clear_mind_guard` | `clear_mind_guard.tres` | skill | common | 1 | block 7 player; apply_status 1 sword_focus player |
| `sword.thread_the_needle` | `thread_the_needle.tres` | attack | uncommon | 1 | damage 8 enemy; draw_card 1 player |
| `sword.echoing_sword_heart` | `echoing_sword_heart.tres` | skill | uncommon | 1 | apply_status 2 sword_focus player; draw_card 1 player |
| `sword.heaven_cutting_arc` | `heaven_cutting_arc.tres` | attack | rare | 2 | damage 18 enemy; apply_status 2 broken_stance enemy |

Alchemy cards:

| id | file | type | rarity | cost | effects |
| --- | --- | --- | --- | --- | --- |
| `alchemy.coiling_miasma` | `coiling_miasma.tres` | skill | common | 1 | apply_status 3 poison enemy |
| `alchemy.needle_rain` | `needle_rain.tres` | attack | common | 1 | damage 4 enemy; apply_status 2 poison enemy |
| `alchemy.purifying_brew` | `purifying_brew.tres` | skill | uncommon | 1 | heal 4 player; draw_card 1 player |
| `alchemy.cauldron_overflow` | `cauldron_overflow.tres` | skill | uncommon | 2 | apply_status 5 poison enemy; block 5 player |
| `alchemy.golden_core_detox` | `golden_core_detox.tres` | skill | rare | 1 | gain_energy 1 player; draw_card 2 player; heal 3 player |

Enemies:

| id | tier | max_hp | intents | reward_tier | gold bounds |
| --- | --- | --- | --- | --- | --- |
| `scarlet_mantis_acolyte` | normal | 28 | `attack_7`, `block_4`, `attack_5` | normal | 9-15 |
| `jade_armor_sentinel` | elite | 54 | `block_10`, `attack_11`, `attack_8` | elite | 20-30 |
| `boss_void_tiger` | boss | 110 | `attack_14`, `block_12`, `attack_18` | boss | 45-65 |

Relics:

| id | tier | trigger_event | effects |
| --- | --- | --- | --- |
| `mist_vein_bracelet` | common | `combat_started` | apply_status 1 sword_focus player |
| `verdant_antidote_gourd` | common | `combat_started` | heal 3 player |
| `copper_mantis_hook` | common | `combat_won` | gain_gold 6 player |
| `white_tiger_tally` | uncommon | `turn_started` | block 2 player |
| `nine_smoke_censer` | uncommon | `combat_started` | block 5 player |
| `starforged_meridian` | rare | `combat_started` | gain_energy 1 player; apply_status 2 sword_focus player |

Events:

| id | options |
| --- | --- |
| `sealed_sword_tomb` | `draw_blade`: hp_delta -8, gold_delta 45, min_hp 9; `meditate`: hp_delta -3; `leave`: no mutation |
| `alchemist_market` | `buy_brew`: min_gold 20, gold_delta -20, hp_delta 10; `sample`: hp_delta 4; `leave`: no mutation |
| `spirit_beast_tracks` | `chase`: hp_delta -5, gold_delta 28, min_hp 6; `hide`: hp_delta 3; `leave`: no mutation |

## Task 1: Add Status Runtime with Focused Tests

**Files:**

- Create: `tests/unit/test_combat_status_runtime.gd`
- Modify: `scripts/testing/test_runner.gd`
- Create: `scripts/combat/combat_status_runtime.gd`

- [x] **Step 1: Register the status runtime test**

Modify `scripts/testing/test_runner.gd` and insert `test_combat_status_runtime.gd` before `test_combat_engine.gd`:

```gdscript
	"res://tests/unit/test_run_state.gd",
	"res://tests/unit/test_combat_status_runtime.gd",
	"res://tests/unit/test_combat_engine.gd",
	"res://tests/unit/test_combat_session.gd",
```

- [x] **Step 2: Write failing status runtime tests**

Create `tests/unit/test_combat_status_runtime.gd`:

```gdscript
extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const CombatStatusRuntime := preload("res://scripts/combat/combat_status_runtime.gd")

func test_poison_turn_start_loses_hp_ignores_block_and_decays() -> bool:
	var state := _state()
	var enemy := state.enemies[0]
	enemy.block = 99
	enemy.statuses["poison"] = 3
	CombatStatusRuntime.new().on_turn_started(enemy, state)
	var passed: bool = enemy.current_hp == 17 \
		and enemy.block == 99 \
		and enemy.statuses.get("poison", 0) == 2
	assert(passed)
	return passed

func test_poison_turn_start_removes_status_at_zero() -> bool:
	var state := _state()
	var enemy := state.enemies[0]
	enemy.statuses["poison"] = 1
	CombatStatusRuntime.new().on_turn_started(enemy, state)
	var passed: bool = enemy.current_hp == 19 \
		and not enemy.statuses.has("poison")
	assert(passed)
	return passed

func test_player_focus_and_target_broken_stance_modify_damage_then_decay() -> bool:
	var state := _state()
	var player := state.player
	var enemy := state.enemies[0]
	player.statuses["sword_focus"] = 2
	enemy.statuses["broken_stance"] = 3
	var runtime := CombatStatusRuntime.new()
	var modified := runtime.modify_damage(state, player, enemy, 10)
	var hp_lost := enemy.take_damage(modified)
	runtime.after_damage(state, player, enemy, modified, hp_lost)
	var passed: bool = modified == 15 \
		and enemy.current_hp == 5 \
		and player.statuses.get("sword_focus", 0) == 1 \
		and enemy.statuses.get("broken_stance", 0) == 2
	assert(passed)
	return passed

func test_non_player_sword_focus_does_not_modify_damage() -> bool:
	var state := _state()
	var enemy := state.enemies[0]
	enemy.statuses["sword_focus"] = 5
	var modified := CombatStatusRuntime.new().modify_damage(state, enemy, state.player, 7)
	var passed: bool = modified == 7 \
		and enemy.statuses.get("sword_focus", 0) == 5
	assert(passed)
	return passed

func test_non_positive_base_damage_stays_zero_and_does_not_decay() -> bool:
	var state := _state()
	state.player.statuses["sword_focus"] = 2
	state.enemies[0].statuses["broken_stance"] = 2
	var runtime := CombatStatusRuntime.new()
	var modified := runtime.modify_damage(state, state.player, state.enemies[0], -5)
	runtime.after_damage(state, state.player, state.enemies[0], modified, 0)
	var passed: bool = modified == 0 \
		and state.player.statuses.get("sword_focus", 0) == 2 \
		and state.enemies[0].statuses.get("broken_stance", 0) == 2
	assert(passed)
	return passed

func test_status_text_lists_positive_status_layers_in_key_order() -> bool:
	var combatant := CombatantState.new("sample", 10)
	combatant.statuses["sword_focus"] = 2
	combatant.statuses["poison"] = 3
	combatant.statuses["empty"] = 0
	var passed := CombatStatusRuntime.new().status_text(combatant) == "poison:3 sword_focus:2"
	assert(passed)
	return passed

func _state() -> CombatState:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 30)
	var enemies: Array[CombatantState] = [CombatantState.new("enemy", 20)]
	state.enemies = enemies
	return state
```

- [x] **Step 3: Run the new tests and confirm red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because `scripts/combat/combat_status_runtime.gd` does not exist.

- [x] **Step 4: Implement `CombatStatusRuntime`**

Create `scripts/combat/combat_status_runtime.gd`:

```gdscript
class_name CombatStatusRuntime
extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

const STATUS_POISON := "poison"
const STATUS_SWORD_FOCUS := "sword_focus"
const STATUS_BROKEN_STANCE := "broken_stance"

const STATUS_METADATA := {
	STATUS_POISON: {
		"name_key": "status.poison.name",
		"description_key": "status.poison.desc",
	},
	STATUS_SWORD_FOCUS: {
		"name_key": "status.sword_focus.name",
		"description_key": "status.sword_focus.desc",
	},
	STATUS_BROKEN_STANCE: {
		"name_key": "status.broken_stance.name",
		"description_key": "status.broken_stance.desc",
	},
}

func modify_damage(state: CombatState, source: CombatantState, target: CombatantState, base_amount: int) -> int:
	if state == null or source == null or target == null:
		return max(0, base_amount)
	if base_amount <= 0:
		return 0
	var amount := base_amount
	if source == state.player:
		amount += _layers(source, STATUS_SWORD_FOCUS)
	amount += _layers(target, STATUS_BROKEN_STANCE)
	return max(0, amount)

func after_damage(state: CombatState, source: CombatantState, target: CombatantState, final_amount: int, _hp_lost: int) -> void:
	if state == null or source == null or target == null or final_amount <= 0:
		return
	if source == state.player and _layers(source, STATUS_SWORD_FOCUS) > 0:
		_decay(source, STATUS_SWORD_FOCUS)
	if _layers(target, STATUS_BROKEN_STANCE) > 0:
		_decay(target, STATUS_BROKEN_STANCE)

func on_turn_started(combatant: CombatantState, _state: CombatState) -> void:
	if combatant == null:
		return
	var poison := _layers(combatant, STATUS_POISON)
	if poison <= 0:
		return
	combatant.current_hp = max(0, combatant.current_hp - poison)
	_decay(combatant, STATUS_POISON)

func status_text(combatant: CombatantState) -> String:
	if combatant == null:
		return ""
	var keys := combatant.statuses.keys()
	keys.sort()
	var result := ""
	for key in keys:
		var status_id := String(key)
		var layers := int(combatant.statuses.get(status_id, 0))
		if layers <= 0:
			continue
		if not result.is_empty():
			result += " "
		result += "%s:%s" % [status_id, layers]
	return result

func _layers(combatant: CombatantState, status_id: String) -> int:
	if combatant == null:
		return 0
	return max(0, int(combatant.statuses.get(status_id, 0)))

func _decay(combatant: CombatantState, status_id: String) -> void:
	var remaining := _layers(combatant, status_id) - 1
	if remaining <= 0:
		combatant.statuses.erase(status_id)
	else:
		combatant.statuses[status_id] = remaining
```

- [x] **Step 5: Run tests and confirm green for Task 1**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 6: Commit Task 1**

Run:

```powershell
rtk proxy git add scripts/testing/test_runner.gd scripts/combat/combat_status_runtime.gd tests/unit/test_combat_status_runtime.gd
rtk proxy git commit -m "feat: add combat status runtime"
```

## Task 2: Integrate Status Runtime into Combat Damage and Turns

**Files:**

- Modify: `tests/unit/test_combat_engine.gd`
- Modify: `tests/unit/test_combat_session.gd`
- Modify: `scripts/combat/effect_executor.gd`
- Modify: `scripts/combat/combat_session.gd`
- Modify: `scripts/ui/combat_screen.gd`

- [x] **Step 1: Add failing `EffectExecutor` integration tests**

Append these tests to `tests/unit/test_combat_engine.gd` near the existing stateful effect tests:

```gdscript
func test_stateful_damage_uses_sword_focus_and_broken_stance() -> bool:
	var damage := _make_effect("damage", 10, "enemy")
	var effects: Array[EffectDef] = [damage]
	var card := _make_card(effects)
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 30)
	state.player.statuses["sword_focus"] = 2
	var enemy := CombatantState.new("enemy", 30)
	enemy.statuses["broken_stance"] = 3
	CombatEngine.new().play_card_in_state(card, state, state.player, enemy)
	var passed: bool = enemy.current_hp == 15 \
		and state.player.statuses.get("sword_focus", 0) == 1 \
		and enemy.statuses.get("broken_stance", 0) == 2
	assert(passed)
	return passed

func test_stateless_damage_does_not_use_status_runtime() -> bool:
	var damage := _make_effect("damage", 10, "enemy")
	var effects: Array[EffectDef] = [damage]
	var card := _make_card(effects)
	var player := CombatantState.new("sword", 30)
	player.statuses["sword_focus"] = 2
	var enemy := CombatantState.new("enemy", 30)
	enemy.statuses["broken_stance"] = 3
	CombatEngine.new().play_card(card, player, enemy)
	var passed: bool = enemy.current_hp == 20 \
		and player.statuses.get("sword_focus", 0) == 2 \
		and enemy.statuses.get("broken_stance", 0) == 3
	assert(passed)
	return passed
```

- [x] **Step 2: Add failing poison flow tests**

Append these tests to `tests/unit/test_combat_session.gd` near the enemy turn tests:

```gdscript
func test_enemy_poison_triggers_before_enemy_intent_and_can_win() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.guard"]
	session.state.draw_pile.clear()
	session.state.discard_pile.clear()
	var enemies: Array[CombatantState] = [CombatantState.new("first_attacker", 3)]
	session.state.enemies = enemies
	session.state.enemies[0].statuses["poison"] = 3
	session.enemy_defs_by_id.clear()
	session.enemy_defs_by_id["first_attacker"] = _enemy("first_attacker", "normal", 3, ["attack_99"])
	var intent_indices: Array[int] = [0]
	session.enemy_intent_indices = intent_indices
	var hp_before := session.state.player.current_hp

	var ended := session.end_player_turn()

	var passed: bool = ended \
		and session.phase == CombatSession.PHASE_WON \
		and session.state.player.current_hp == hp_before \
		and session.state.enemies[0].is_defeated()
	assert(passed)
	return passed

func test_player_poison_at_turn_start_can_lose_combat() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	run.current_hp = 4
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.guard"]
	session.state.draw_pile = ["sword.strike"]
	session.state.player.statuses["poison"] = 4
	var enemies: Array[CombatantState] = [CombatantState.new("test_block_boss", 50)]
	session.state.enemies = enemies
	session.enemy_defs_by_id.clear()
	session.enemy_defs_by_id["test_block_boss"] = _enemy("test_block_boss", "boss", 50, ["block_0"])
	var intent_indices: Array[int] = [0]
	session.enemy_intent_indices = intent_indices

	var ended := session.end_player_turn()

	var passed: bool = ended \
		and session.phase == CombatSession.PHASE_LOST \
		and run.failed \
		and run.current_hp == 0
	assert(passed)
	return passed
```

- [x] **Step 3: Run tests and confirm red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because damage ignores status modifiers and turn-start poison is not called.

- [x] **Step 4: Wire status-aware damage in `EffectExecutor`**

Modify the top of `scripts/combat/effect_executor.gd`:

```gdscript
const CombatStatusRuntime := preload("res://scripts/combat/combat_status_runtime.gd")

var status_runtime := CombatStatusRuntime.new()
```

Replace only the `"damage"` branch in `_execute_effect()`:

```gdscript
		"damage":
			var damage_amount := amount
			if state != null:
				damage_amount = status_runtime.modify_damage(state, source, recipient, amount)
			var hp_lost := recipient.take_damage(damage_amount)
			if state != null:
				status_runtime.after_damage(state, source, recipient, damage_amount, hp_lost)
```

Keep the existing `"apply_status"` branch generic:

```gdscript
		"apply_status":
			if amount > 0 and not effect.status_id.is_empty():
				recipient.statuses[effect.status_id] = recipient.statuses.get(effect.status_id, 0) + amount
```

- [x] **Step 5: Wire turn-start poison in `CombatSession`**

Modify the preload section of `scripts/combat/combat_session.gd`:

```gdscript
const CombatStatusRuntime := preload("res://scripts/combat/combat_status_runtime.gd")
```

Add a runtime property near `var engine := CombatEngine.new()`:

```gdscript
var status_runtime := CombatStatusRuntime.new()
```

In `start()`, reset and share the runtime with the engine immediately after `engine = CombatEngine.new()`:

```gdscript
	status_runtime = CombatStatusRuntime.new()
	engine.executor.status_runtime = status_runtime
```

In `_run_enemy_turn()`, apply enemy poison before each living enemy acts:

```gdscript
func _run_enemy_turn() -> void:
	_clear_enemy_blocks()
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index]
		if enemy.is_defeated():
			continue
		status_runtime.on_turn_started(enemy, state)
		if _update_terminal_phase():
			return
		if enemy.is_defeated():
			continue
		_execute_enemy_intent(enemy_index)
		if state.player.is_defeated():
			_finish_loss()
			return
```

In `_start_player_turn()`, apply player poison before relics and draws:

```gdscript
func _start_player_turn() -> void:
	status_runtime.on_turn_started(state.player, state)
	if _update_terminal_phase():
		return
	_handle_relic_event("turn_started")
	_resolve_pending_draws()
	if _update_terminal_phase():
		return
	draw_cards(5)
	phase = PHASE_PLAYER_TURN
```

- [x] **Step 6: Append compact status text in combat UI**

Modify `_player_status_text()` in `scripts/ui/combat_screen.gd`:

```gdscript
func _player_status_text() -> String:
	if session.state.player == null:
		return "No player"
	var text := "Player %s HP %s/%s Block %s Energy %s Turn %s" % [
		session.state.player.id,
		session.state.player.current_hp,
		session.state.player.max_hp,
		session.state.player.block,
		session.state.energy,
		session.state.turn,
	]
	var statuses := session.status_runtime.status_text(session.state.player)
	if not statuses.is_empty():
		text += " Status %s" % statuses
	return text
```

Modify enemy button text construction in `_refresh_enemies()`:

```gdscript
		var text := "%s HP %s/%s Block %s Intent %s" % [
			enemy.id,
			enemy.current_hp,
			enemy.max_hp,
			enemy.block,
			session.get_enemy_intent(enemy_index),
		]
		var statuses := session.status_runtime.status_text(enemy)
		if not statuses.is_empty():
			text += " Status %s" % statuses
		button.text = text
```

- [x] **Step 7: Run tests and confirm green for Task 2**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 8: Commit Task 2**

Run:

```powershell
rtk proxy git add scripts/combat/effect_executor.gd scripts/combat/combat_session.gd scripts/ui/combat_screen.gd tests/unit/test_combat_engine.gd tests/unit/test_combat_session.gd
rtk proxy git commit -m "feat: apply combat status hooks"
```

## Task 3: Add Wave 2 Content Resources and Registration

**Files:**

- Create: all Wave 2 `.tres` files listed in File Structure.
- Modify: `scripts/content/content_catalog.gd`
- Modify: `resources/characters/sword_cultivator.tres`
- Modify: `resources/characters/alchemy_cultivator.tres`
- Modify: `localization/zh_CN.po`

- [x] **Step 1: Create card resources from the Resource Data table**

Use the existing Wave 1 `.tres` format. For a two-effect attack such as `sword.wind_splitting_step`, the file shape is:

```gdresource
[gd_resource type="Resource" script_class="CardDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_damage"]
script = ExtResource("2_effect")
effect_type = "damage"
amount = 6
target = "enemy"

[sub_resource type="Resource" id="Resource_broken_stance"]
script = ExtResource("2_effect")
effect_type = "apply_status"
amount = 1
status_id = "broken_stance"
target = "enemy"

[resource]
script = ExtResource("1_card")
id = "sword.wind_splitting_step"
name_key = "card.sword.wind_splitting_step.name"
description_key = "card.sword.wind_splitting_step.desc"
cost = 1
card_type = "attack"
rarity = "common"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_damage"), SubResource("Resource_broken_stance")])
character_id = "sword"
pool_tags = Array[String](["wave_2"])
reward_weight = 100
```

Create these ten card files. The `sub_resources` column names the exact `EffectDef` subresources to put in the `effects = Array[ExtResource("2_effect")]([...])` list in the same order:

| file | load_steps | id | cost | type | rarity | character_id | sub_resources |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `resources/cards/sword/wind_splitting_step.tres` | 4 | `sword.wind_splitting_step` | 1 | attack | common | sword | `Resource_damage`: damage 6 enemy; `Resource_broken_stance`: apply_status 1 broken_stance enemy |
| `resources/cards/sword/clear_mind_guard.tres` | 4 | `sword.clear_mind_guard` | 1 | skill | common | sword | `Resource_block`: block 7 player; `Resource_sword_focus`: apply_status 1 sword_focus player |
| `resources/cards/sword/thread_the_needle.tres` | 4 | `sword.thread_the_needle` | 1 | attack | uncommon | sword | `Resource_damage`: damage 8 enemy; `Resource_draw`: draw_card 1 player |
| `resources/cards/sword/echoing_sword_heart.tres` | 4 | `sword.echoing_sword_heart` | 1 | skill | uncommon | sword | `Resource_sword_focus`: apply_status 2 sword_focus player; `Resource_draw`: draw_card 1 player |
| `resources/cards/sword/heaven_cutting_arc.tres` | 4 | `sword.heaven_cutting_arc` | 2 | attack | rare | sword | `Resource_damage`: damage 18 enemy; `Resource_broken_stance`: apply_status 2 broken_stance enemy |
| `resources/cards/alchemy/coiling_miasma.tres` | 3 | `alchemy.coiling_miasma` | 1 | skill | common | alchemy | `Resource_poison`: apply_status 3 poison enemy |
| `resources/cards/alchemy/needle_rain.tres` | 4 | `alchemy.needle_rain` | 1 | attack | common | alchemy | `Resource_damage`: damage 4 enemy; `Resource_poison`: apply_status 2 poison enemy |
| `resources/cards/alchemy/purifying_brew.tres` | 4 | `alchemy.purifying_brew` | 1 | skill | uncommon | alchemy | `Resource_heal`: heal 4 player; `Resource_draw`: draw_card 1 player |
| `resources/cards/alchemy/cauldron_overflow.tres` | 4 | `alchemy.cauldron_overflow` | 2 | skill | uncommon | alchemy | `Resource_poison`: apply_status 5 poison enemy; `Resource_block`: block 5 player |
| `resources/cards/alchemy/golden_core_detox.tres` | 5 | `alchemy.golden_core_detox` | 1 | skill | rare | alchemy | `Resource_energy`: gain_energy 1 player; `Resource_draw`: draw_card 2 player; `Resource_heal`: heal 3 player |

Every card resource uses:

```gdresource
pool_tags = Array[String](["wave_2"])
reward_weight = 100
```

- [x] **Step 2: Create enemy resources**

Use this shape for `resources/enemies/scarlet_mantis_acolyte.tres` and the Resource Data table for all three enemies:

```gdresource
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/enemy_def.gd" id="1_enemy"]

[resource]
script = ExtResource("1_enemy")
id = "scarlet_mantis_acolyte"
name_key = "enemy.scarlet_mantis_acolyte.name"
max_hp = 28
intent_sequence = Array[String](["attack_7", "block_4", "attack_5"])
reward_tier = "normal"
tier = "normal"
encounter_weight = 100
gold_reward_min = 9
gold_reward_max = 15
```

- [x] **Step 3: Create relic resources**

Use this shape for `resources/relics/mist_vein_bracelet.tres` and the Resource Data table for all six relics:

```gdresource
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_sword_focus"]
script = ExtResource("2_effect")
effect_type = "apply_status"
amount = 1
status_id = "sword_focus"
target = "player"

[resource]
script = ExtResource("1_relic")
id = "mist_vein_bracelet"
name_key = "relic.mist_vein_bracelet.name"
description_key = "relic.mist_vein_bracelet.desc"
trigger_event = "combat_started"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_sword_focus")])
tier = "common"
reward_weight = 100
```

For `starforged_meridian`, use `load_steps=4` and include both `gain_energy 1 player` and `apply_status 2 sword_focus player`.

- [x] **Step 4: Create event resources**

Use this shape for `resources/events/sealed_sword_tomb.tres` and the Resource Data table for all three events:

```gdresource
[gd_resource type="Resource" script_class="EventDef" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_draw_blade"]
script = ExtResource("2_option")
id = "draw_blade"
label_key = "event.sealed_sword_tomb.option.draw_blade"
description_key = "event.sealed_sword_tomb.option.draw_blade.desc"
min_hp = 9
hp_delta = -8
gold_delta = 45

[sub_resource type="Resource" id="Resource_meditate"]
script = ExtResource("2_option")
id = "meditate"
label_key = "event.sealed_sword_tomb.option.meditate"
description_key = "event.sealed_sword_tomb.option.meditate.desc"
hp_delta = -3

[sub_resource type="Resource" id="Resource_leave"]
script = ExtResource("2_option")
id = "leave"
label_key = "event.sealed_sword_tomb.option.leave"
description_key = "event.sealed_sword_tomb.option.leave.desc"

[resource]
script = ExtResource("1_event")
id = "sealed_sword_tomb"
title_key = "event.sealed_sword_tomb.title"
body_key = "event.sealed_sword_tomb.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_draw_blade"), SubResource("Resource_meditate"), SubResource("Resource_leave")])
```

- [x] **Step 5: Register resources in `ContentCatalog`**

Append new card paths after the existing sword and alchemy groups in `DEFAULT_CARD_PATHS`:

```gdscript
	"res://resources/cards/sword/wind_splitting_step.tres",
	"res://resources/cards/sword/clear_mind_guard.tres",
	"res://resources/cards/sword/thread_the_needle.tres",
	"res://resources/cards/sword/echoing_sword_heart.tres",
	"res://resources/cards/sword/heaven_cutting_arc.tres",
	"res://resources/cards/alchemy/coiling_miasma.tres",
	"res://resources/cards/alchemy/needle_rain.tres",
	"res://resources/cards/alchemy/purifying_brew.tres",
	"res://resources/cards/alchemy/cauldron_overflow.tres",
	"res://resources/cards/alchemy/golden_core_detox.tres",
```

Append new enemy paths:

```gdscript
	"res://resources/enemies/scarlet_mantis_acolyte.tres",
	"res://resources/enemies/jade_armor_sentinel.tres",
	"res://resources/enemies/boss_void_tiger.tres",
```

Append new relic paths:

```gdscript
	"res://resources/relics/mist_vein_bracelet.tres",
	"res://resources/relics/verdant_antidote_gourd.tres",
	"res://resources/relics/copper_mantis_hook.tres",
	"res://resources/relics/white_tiger_tally.tres",
	"res://resources/relics/nine_smoke_censer.tres",
	"res://resources/relics/starforged_meridian.tres",
```

Append new event paths:

```gdscript
	"res://resources/events/sealed_sword_tomb.tres",
	"res://resources/events/alchemist_market.tres",
	"res://resources/events/spirit_beast_tracks.tres",
```

- [x] **Step 6: Append card ids to character pools**

In `resources/characters/sword_cultivator.tres`, append:

```gdresource
"sword.wind_splitting_step", "sword.clear_mind_guard", "sword.thread_the_needle", "sword.echoing_sword_heart", "sword.heaven_cutting_arc"
```

In `resources/characters/alchemy_cultivator.tres`, append:

```gdresource
"alchemy.coiling_miasma", "alchemy.needle_rain", "alchemy.purifying_brew", "alchemy.cauldron_overflow", "alchemy.golden_core_detox"
```

Do not change `starting_deck_ids`.

- [x] **Step 7: Add localization keys**

Append these keys to `localization/zh_CN.po` with non-empty `msgstr` values:

```po
msgid "status.poison.name"
msgstr "毒"

msgid "status.poison.desc"
msgstr "回合开始时失去等同层数的生命，然后减少 1 层。"

msgid "status.sword_focus.name"
msgstr "剑心"

msgid "status.sword_focus.desc"
msgstr "下一次由玩家造成的伤害增加等同层数的数值，然后减少 1 层。"

msgid "status.broken_stance.name"
msgstr "破势"

msgid "status.broken_stance.desc"
msgstr "下一次受到伤害时额外受到等同层数的伤害，然后减少 1 层。"

msgid "card.sword.wind_splitting_step.name"
msgstr "分风踏"

msgid "card.sword.wind_splitting_step.desc"
msgstr "造成 6 点伤害。施加 1 层破势。"

msgid "card.sword.clear_mind_guard.name"
msgstr "清心守"

msgid "card.sword.clear_mind_guard.desc"
msgstr "获得 7 点护体。获得 1 层剑心。"

msgid "card.sword.thread_the_needle.name"
msgstr "穿针剑"

msgid "card.sword.thread_the_needle.desc"
msgstr "造成 8 点伤害。抽 1 张牌。"

msgid "card.sword.echoing_sword_heart.name"
msgstr "回响剑心"

msgid "card.sword.echoing_sword_heart.desc"
msgstr "获得 2 层剑心。抽 1 张牌。"

msgid "card.sword.heaven_cutting_arc.name"
msgstr "斩天弧"

msgid "card.sword.heaven_cutting_arc.desc"
msgstr "造成 18 点伤害。施加 2 层破势。"

msgid "card.alchemy.coiling_miasma.name"
msgstr "缠雾瘴"

msgid "card.alchemy.coiling_miasma.desc"
msgstr "施加 3 层毒。"

msgid "card.alchemy.needle_rain.name"
msgstr "针雨"

msgid "card.alchemy.needle_rain.desc"
msgstr "造成 4 点伤害。施加 2 层毒。"

msgid "card.alchemy.purifying_brew.name"
msgstr "净灵酿"

msgid "card.alchemy.purifying_brew.desc"
msgstr "恢复 4 点生命。抽 1 张牌。"

msgid "card.alchemy.cauldron_overflow.name"
msgstr "鼎沸溢流"

msgid "card.alchemy.cauldron_overflow.desc"
msgstr "施加 5 层毒。获得 5 点护体。"

msgid "card.alchemy.golden_core_detox.name"
msgstr "金丹解厄"

msgid "card.alchemy.golden_core_detox.desc"
msgstr "获得 1 点能量。抽 2 张牌。恢复 3 点生命。"

msgid "enemy.scarlet_mantis_acolyte.name"
msgstr "赤螳侍徒"

msgid "enemy.jade_armor_sentinel.name"
msgstr "玉甲镇卫"

msgid "enemy.boss_void_tiger.name"
msgstr "虚虎妖王"

msgid "relic.mist_vein_bracelet.name"
msgstr "雾脉手环"

msgid "relic.mist_vein_bracelet.desc"
msgstr "战斗开始时，获得 1 层剑心。"

msgid "relic.verdant_antidote_gourd.name"
msgstr "翠药葫芦"

msgid "relic.verdant_antidote_gourd.desc"
msgstr "战斗开始时，恢复 3 点生命。"

msgid "relic.copper_mantis_hook.name"
msgstr "铜螳钩"

msgid "relic.copper_mantis_hook.desc"
msgstr "战斗胜利时，获得 6 金。"

msgid "relic.white_tiger_tally.name"
msgstr "白虎符"

msgid "relic.white_tiger_tally.desc"
msgstr "回合开始时，获得 2 点护体。"

msgid "relic.nine_smoke_censer.name"
msgstr "九烟炉"

msgid "relic.nine_smoke_censer.desc"
msgstr "战斗开始时，获得 5 点护体。"

msgid "relic.starforged_meridian.name"
msgstr "星铸经脉"

msgid "relic.starforged_meridian.desc"
msgstr "战斗开始时，获得 1 点能量和 2 层剑心。"

msgid "event.sealed_sword_tomb.title"
msgstr "封剑古冢"

msgid "event.sealed_sword_tomb.body"
msgstr "石门半掩，旧剑意仍在冢中回响。"

msgid "event.sealed_sword_tomb.option.draw_blade"
msgstr "拔出残剑，失去 8 生命，获得 45 金"

msgid "event.sealed_sword_tomb.option.draw_blade.desc"
msgstr "以气血换取古冢馈赠。"

msgid "event.sealed_sword_tomb.option.meditate"
msgstr "静坐参悟，失去 3 生命"

msgid "event.sealed_sword_tomb.option.meditate.desc"
msgstr "承受余锋，磨炼心神。"

msgid "event.sealed_sword_tomb.option.leave"
msgstr "离开"

msgid "event.sealed_sword_tomb.option.leave.desc"
msgstr "不改变当前状态。"

msgid "event.alchemist_market.title"
msgstr "炼丹市集"

msgid "event.alchemist_market.body"
msgstr "游方丹师在雾中摆摊，丹香与苦味混在一起。"

msgid "event.alchemist_market.option.buy_brew"
msgstr "支付 20 金，恢复 10 生命"

msgid "event.alchemist_market.option.buy_brew.desc"
msgstr "买下一盏温热药汤。"

msgid "event.alchemist_market.option.sample"
msgstr "试饮赠药，恢复 4 生命"

msgid "event.alchemist_market.option.sample.desc"
msgstr "药性微弱，但没有代价。"

msgid "event.alchemist_market.option.leave"
msgstr "离开"

msgid "event.alchemist_market.option.leave.desc"
msgstr "不改变当前状态。"

msgid "event.spirit_beast_tracks.title"
msgstr "灵兽踪迹"

msgid "event.spirit_beast_tracks.body"
msgstr "潮湿泥地里留着发光爪印，远处林叶无风自动。"

msgid "event.spirit_beast_tracks.option.chase"
msgstr "追踪灵兽，失去 5 生命，获得 28 金"

msgid "event.spirit_beast_tracks.option.chase.desc"
msgstr "冒险追入林中，搜得散落灵石。"

msgid "event.spirit_beast_tracks.option.hide"
msgstr "屏息潜伏，恢复 3 生命"

msgid "event.spirit_beast_tracks.option.hide.desc"
msgstr "借林间灵气调息片刻。"

msgid "event.spirit_beast_tracks.option.leave"
msgstr "离开"

msgid "event.spirit_beast_tracks.option.leave.desc"
msgstr "不改变当前状态。"
```

- [x] **Step 8: Run import check for new resources**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: Godot exits 0.

Do not commit until Task 4 tests prove the expanded catalog is correct.

## Task 4: Lock Expanded Content Tests

**Files:**

- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `tests/unit/test_reward_generator.gd`
- Modify: `tests/unit/test_encounter_generator.gd`
- Modify: `tests/unit/test_event_resolver.gd`

- [x] **Step 1: Update catalog card pool counts and expected ids**

In `tests/unit/test_content_catalog.gd`, change `test_default_catalog_loads_dual_starter_card_pool_counts()` to expect:

```gdscript
	var passed: bool = catalog.cards_by_id.size() == 40 \
		and sword_ids.size() == 20 \
		and alchemy_ids.size() == 20
```

Extend `expected_sword` with:

```gdscript
		"sword.wind_splitting_step",
		"sword.clear_mind_guard",
		"sword.thread_the_needle",
		"sword.echoing_sword_heart",
		"sword.heaven_cutting_arc",
```

Extend `expected_alchemy` with:

```gdscript
		"alchemy.coiling_miasma",
		"alchemy.needle_rain",
		"alchemy.purifying_brew",
		"alchemy.cauldron_overflow",
		"alchemy.golden_core_detox",
```

- [x] **Step 2: Replace Wave 1 count test with Wave 2 count test**

Rename `test_wave_1_catalog_loads_expanded_enemy_and_relic_counts()` to `test_wave_2_catalog_loads_expanded_enemy_relic_and_event_counts()` and use:

```gdscript
func test_wave_2_catalog_loads_expanded_enemy_relic_and_event_counts() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var elite_ids := _ids(catalog.get_enemies_by_tier("elite"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var common_relic_ids := _ids(catalog.get_relics_by_tier("common"))
	var uncommon_relic_ids := _ids(catalog.get_relics_by_tier("uncommon"))
	var rare_relic_ids := _ids(catalog.get_relics_by_tier("rare"))
	var event_ids := _ids(catalog.get_events())
	var passed: bool = catalog.enemies_by_id.size() == 12 \
		and catalog.relics_by_id.size() == 12 \
		and catalog.events_by_id.size() == 6 \
		and normal_ids.size() == 5 \
		and elite_ids.size() == 4 \
		and boss_ids.size() == 3 \
		and common_relic_ids.size() == 6 \
		and uncommon_relic_ids.size() == 4 \
		and rare_relic_ids.size() == 2 \
		and normal_ids.has("scarlet_mantis_acolyte") \
		and elite_ids.has("jade_armor_sentinel") \
		and boss_ids.has("boss_void_tiger") \
		and common_relic_ids.has("mist_vein_bracelet") \
		and uncommon_relic_ids.has("nine_smoke_censer") \
		and rare_relic_ids.has("starforged_meridian") \
		and event_ids.has("sealed_sword_tomb") \
		and event_ids.has("alchemist_market") \
		and event_ids.has("spirit_beast_tracks")
	assert(passed)
	return passed
```

Keep the catalog helper untyped so it accepts cards, enemies, relics, and events:

```gdscript
func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids
```

- [x] **Step 3: Update event pool test**

In `test_default_catalog_loads_event_pool()`, expect 6 events and all ids:

```gdscript
	var passed: bool = catalog.events_by_id.size() == 6 \
		and event_ids.has("wandering_physician") \
		and event_ids.has("spirit_toll") \
		and event_ids.has("quiet_shrine") \
		and event_ids.has("sealed_sword_tomb") \
		and event_ids.has("alchemist_market") \
		and event_ids.has("spirit_beast_tracks") \
		and catalog.get_event("quiet_shrine") != null \
		and catalog.get_event("spirit_beast_tracks") != null
```

- [x] **Step 4: Update reward generator tests**

In `tests/unit/test_reward_generator.gd`, rename `test_relic_rewards_draw_from_each_populated_wave_1_tier()` to `test_relic_rewards_draw_from_each_populated_wave_2_tier()` and assert all three tiers return populated ids:

```gdscript
func test_relic_rewards_draw_from_each_populated_wave_2_tier() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var common := generator.generate_relic_reward(catalog, 91, "wave_2_common", "common")
	var uncommon := generator.generate_relic_reward(catalog, 91, "wave_2_uncommon", "uncommon")
	var rare := generator.generate_relic_reward(catalog, 91, "wave_2_rare", "rare")
	var passed: bool = not String(common.get("relic_id", "")).is_empty() \
		and not String(uncommon.get("relic_id", "")).is_empty() \
		and not String(rare.get("relic_id", "")).is_empty()
	assert(passed)
	return passed
```

Keep existing card reward tests; they should now draw from 20-card character pools.

- [x] **Step 5: Update encounter generator tier composition test**

In `tests/unit/test_encounter_generator.gd`, rename `test_default_catalog_has_wave_1_enemy_tier_composition()` to `test_default_catalog_has_wave_2_enemy_tier_composition()` and use:

```gdscript
func test_default_catalog_has_wave_2_enemy_tier_composition() -> bool:
	var catalog := _catalog()
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var elite_ids := _ids(catalog.get_enemies_by_tier("elite"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var passed: bool = normal_ids.size() == 5 \
		and elite_ids.size() == 4 \
		and boss_ids.size() == 3 \
		and normal_ids.has("scarlet_mantis_acolyte") \
		and elite_ids.has("jade_armor_sentinel") \
		and boss_ids.has("boss_void_tiger")
	assert(passed)
	return passed
```

- [x] **Step 6: Update event resolver expected ids**

In `tests/unit/test_event_resolver.gd`, replace the three-id list in `test_event_resolver_returns_deterministic_event_for_same_run_context()` with:

```gdscript
		and [
			"wandering_physician",
			"spirit_toll",
			"quiet_shrine",
			"sealed_sword_tomb",
			"alchemist_market",
			"spirit_beast_tracks",
		].has(first.id)
```

- [x] **Step 7: Run tests and import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected:

```text
TESTS PASSED
```

and Godot import check exits 0.

- [x] **Step 8: Commit Tasks 3 and 4**

Run:

```powershell
rtk proxy git add scripts/content/content_catalog.gd resources/characters/sword_cultivator.tres resources/characters/alchemy_cultivator.tres localization/zh_CN.po resources/cards/sword resources/cards/alchemy resources/enemies resources/relics resources/events tests/unit/test_content_catalog.gd tests/unit/test_reward_generator.gd tests/unit/test_encounter_generator.gd tests/unit/test_event_resolver.gd
rtk proxy git commit -m "feat: expand wave 2 content pools"
```

## Task 5: Acceptance Docs, Verification, and Review

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-27-content-expansion-wave-2.md`

- [x] **Step 1: Update README Phase 2 progress**

Add this bullet under `## Phase 2 Progress`:

```markdown
- Content expansion wave 2: complete; poison, sword focus, and broken stance now have combat behavior, sword and alchemy each have 20 cards, default content has 12 enemies, 12 relics, and 6 events.
```

Update `## Next Plans` item 1 to avoid duplicating completed Wave 2 scope:

```markdown
1. Content expansion wave C: larger event and relic pools, event rewards, enemy status intents, and richer status presentation.
```

- [x] **Step 2: Run full verification**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
rtk proxy git status --short
```

Expected:

```text
TESTS PASSED
```

Godot import check exits 0. `git status --short` shows only README and this plan before the final docs commit.

- [x] **Step 3: Run Stage 1 Spec Compliance Review**

Check every item from the spec:

- `CombatStatusRuntime` is the only file with poison, sword focus, and broken stance gameplay rules.
- `EffectExecutor` still treats `apply_status` as a generic stack operation.
- `poison` deals direct HP loss at turn start, ignores block, decays by 1, and can win or lose combat.
- `sword_focus` increases only player outgoing stateful damage and decays after modifying a damage effect.
- `broken_stance` increases target incoming stateful damage and decays after modifying a damage effect.
- Damage modifiers do not affect poison life loss.
- New card resources exist and are registered.
- New enemy resources exist and are registered.
- New relic resources exist and target only player-compatible effects.
- New event resources exist and only use current `EventOptionDef` fields.
- `ContentCatalog` loads 40 cards, 12 enemies, 12 relics, and 6 events.
- Sword and alchemy card pools each contain exactly 20 ids.
- Starting decks are unchanged.
- New localization keys are present and non-empty.
- No `StatusDef`, new save schema, new shop/reward/map/event runtime systems, or C-scope content was added.

If any item fails, fix it before continuing to Stage 2.

- [x] **Step 4: Run Stage 2 Code Quality Review**

Classify any findings as Critical, Important, or Minor:

- GDScript typing is clear enough for all new functions and variables.
- `CombatStatusRuntime` has narrow hook methods and small helpers.
- Status rules are not duplicated in UI, resources, or session code.
- Damage hook integration preserves stateless `execute()` compatibility.
- Turn-start hook ordering is deterministic and does not double-trigger relic events.
- Resource formatting follows existing `.tres` style.
- Catalog path ordering is readable and grouped by content type.
- Tests are deterministic and use local helpers consistently.
- Localization keys are not duplicated.

Fix Critical and Important issues before acceptance. Minor issues can be fixed immediately if low risk, or recorded in the final summary.

- [x] **Step 5: Commit acceptance docs**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-27-content-expansion-wave-2.md
rtk proxy git commit -m "docs: record content expansion wave 2 acceptance"
```

## Final Acceptance Criteria

- `poison` deals direct HP loss at turn start, ignores block, decays by 1, and can win or lose combat.
- `sword_focus` increases player outgoing damage by its layer count and decays after modifying a damage effect.
- `broken_stance` increases target incoming damage by its layer count and decays after modifying a damage effect.
- Status gameplay rules live in `CombatStatusRuntime`.
- `apply_status` remains a generic stack operation.
- Default catalog loads 40 cards, 12 enemies, 12 relics, and 6 events.
- Sword and alchemy each have exactly 20 cards in their character pools.
- Starting decks are unchanged.
- New cards, enemies, relics, and events have required localization keys.
- Catalog validation returns no errors.
- Reward, encounter, event, shop, save, and combat smoke flows pass.
- Godot tests pass.
- Godot import check exits 0.

## Execution Handoff

After this plan is accepted, choose one execution mode:

1. **Subagent-Driven (recommended):** dispatch one fresh subagent per task, using `gpt-5.5` with extra-high reasoning as required by AGENTS.md, then review between tasks.
2. **Inline Execution:** execute tasks in this session with `superpowers:executing-plans`, batching only when the checkpoint is low risk.
