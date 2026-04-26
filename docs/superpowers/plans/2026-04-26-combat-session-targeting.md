# Combat Session Targeting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first complete, testable combat loop: encounter-backed multi-enemy fights, real draw/hand/discard piles, card-first target selection, cancellable confirmations, enemy turns, and win/loss routing.

**Architecture:** Add `CombatSession` as a pure combat-flow state machine between `CombatScreen` and the existing `CombatEngine`. `CombatSession` owns run-to-combat initialization, deck flow, pending target state, enemy intent execution, and terminal phase detection; `CombatScreen` renders state and forwards clicks. This keeps combat rules unit-testable and leaves presentation free to grow later.

**Tech Stack:** Godot 4.6.2, GDScript, existing lightweight test runner, existing `ContentCatalog`, `EncounterGenerator`, `CombatEngine`, `CombatState`, and `CombatantState`.

---

## Execution Constraints

- Work directly in `D:\prj\Slay the Spire 2` on the current `main` branch. Do not create a worktree.
- Follow TDD: write or extend tests first, run them and verify RED, then implement minimal production code.
- After each completed Godot feature task, run the project's two-stage review gate:
  1. Spec Compliance Review against `docs/superpowers/specs/2026-04-26-combat-session-targeting-design.md`.
  2. Code Quality Review only after spec compliance passes.
- Any subagent used for implementation or review must use `gpt-5.5` with `xhigh` reasoning.
- Do not add formal enemy, card, relic, event, or shop content resources in this plan.
- Do not add save fields for in-combat state.

## Scope Check

This plan implements the approved spec:

```text
docs/superpowers/specs/2026-04-26-combat-session-targeting-design.md
```

The plan covers one cohesive subsystem: the first real combat loop. It intentionally keeps animation, polished visuals, relic triggers, event/shop flow, and combat save recovery out of scope.

## File Structure

Create:

```text
scripts/combat/combat_session.gd
tests/unit/test_combat_session.gd
```

Modify:

```text
scripts/testing/test_runner.gd
scripts/ui/combat_screen.gd
tests/smoke/test_scene_flow.gd
README.md
docs/superpowers/plans/2026-04-26-combat-session-targeting.md
```

Responsibilities:

- `scripts/combat/combat_session.gd`: Pure combat-flow state machine. It has no UI node creation.
- `tests/unit/test_combat_session.gd`: Rules coverage for initialization, deck flow, targeting, enemy turns, and terminal outcomes.
- `scripts/ui/combat_screen.gd`: Programmatic testable UI that renders session state and forwards input.
- `tests/smoke/test_scene_flow.gd`: Scene-level proof that `CombatScreen` creates a session and supports pending/cancel UI.
- `scripts/testing/test_runner.gd`: Registers the new unit test file.
- `README.md`: Records Phase 2 combat loop progress after final acceptance.

## Command Conventions

Use this command for all local test runs:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Use this command for import checks:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --quit
```

## Review Gates

After each task:

- Spec Compliance Review checks implementation exactly against this plan and the approved design spec.
- Code Quality Review checks GDScript structure, static typing, node paths, resource loading, duplication, testability, and maintainability.
- Do not move to the next task while either review has open Critical or Important issues.

## Task 1: CombatSession Initialization

**Files:**

- Create: `tests/unit/test_combat_session.gd`
- Create: `scripts/combat/combat_session.gd`
- Modify: `scripts/testing/test_runner.gd`

- [ ] **Step 1: Register the new test file**

Modify `scripts/testing/test_runner.gd` so `TEST_FILES` includes `test_combat_session.gd` immediately after `test_combat_engine.gd`:

```gdscript
const TEST_FILES := [
	"res://tests/unit/test_rng_service.gd",
	"res://tests/unit/test_resource_schemas.gd",
	"res://tests/unit/test_content_catalog.gd",
	"res://tests/unit/test_reward_generator.gd",
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

- [ ] **Step 2: Write failing initialization tests**

Create `tests/unit/test_combat_session.gd`:

```gdscript
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const CombatSession := preload("res://scripts/combat/combat_session.gd")

func test_session_initializes_from_run_current_node() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.cloud_step",
		"sword.focused_slash",
	])
	var session := CombatSession.new()
	session.start(catalog, run)

	var passed: bool = session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.player.id == "sword" \
		and session.state.player.max_hp == 72 \
		and session.state.player.current_hp == 65 \
		and session.state.energy == 3 \
		and session.state.turn == 1 \
		and session.state.hand.size() == 5 \
		and session.state.draw_pile.size() == 1 \
		and session.state.discard_pile.is_empty() \
		and session.state.enemies.size() >= 1 \
		and session.state.enemies[0].id == "training_puppet" \
		and session.get_enemy_intent(0) == "attack_5"
	assert(passed)
	return passed

func test_session_invalid_when_current_node_is_missing() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("missing_node", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)

	var passed: bool = session.phase == CombatSession.PHASE_INVALID \
		and session.error_text.contains("current map node")
	assert(passed)
	return passed

func test_session_invalid_when_deck_is_empty() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [])
	var session := CombatSession.new()
	session.start(catalog, run)

	var passed: bool = session.phase == CombatSession.PHASE_INVALID \
		and session.error_text.contains("deck")
	assert(passed)
	return passed

func _default_catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run_with_single_node(current_node_id: String, node_type: String, deck_ids: Array[String]) -> RunState:
	var run := RunState.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 65
	run.deck_ids = deck_ids
	run.current_node_id = current_node_id
	var node := MapNodeState.new("node_0", 0, node_type)
	node.unlocked = true
	run.map_nodes = [node]
	return run
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS FAILED` because `res://scripts/combat/combat_session.gd` does not exist yet, causing `test_combat_session.gd` to fail loading.

- [ ] **Step 4: Create CombatSession initialization implementation**

Create `scripts/combat/combat_session.gd`:

```gdscript
class_name CombatSession
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const CombatEngine := preload("res://scripts/combat/combat_engine.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const EncounterGenerator := preload("res://scripts/run/encounter_generator.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

const PHASE_INVALID := "invalid"
const PHASE_PLAYER_TURN := "player_turn"
const PHASE_SELECTING_ENEMY_TARGET := "selecting_enemy_target"
const PHASE_CONFIRMING_PLAYER_TARGET := "confirming_player_target"
const PHASE_ENEMY_TURN := "enemy_turn"
const PHASE_WON := "won"
const PHASE_LOST := "lost"

var catalog: ContentCatalog
var run
var state := CombatState.new()
var engine := CombatEngine.new()
var phase := PHASE_INVALID
var error_text := ""
var pending_hand_index := -1
var pending_card: CardDef
var enemy_defs_by_id: Dictionary = {}
var enemy_intent_indices: Array[int] = []
var rng := RngService.new(1)
var terminal_rewards_applied := false

func start(input_catalog: ContentCatalog, input_run) -> void:
	catalog = input_catalog
	run = input_run
	state = CombatState.new()
	engine = CombatEngine.new()
	phase = PHASE_INVALID
	error_text = ""
	pending_hand_index = -1
	pending_card = null
	enemy_defs_by_id.clear()
	enemy_intent_indices.clear()
	terminal_rewards_applied = false
	if run == null:
		_set_invalid("CombatSession cannot start without a run.")
		return
	rng = RngService.new(run.seed_value).fork("combat:%s" % run.current_node_id)
	_initialize_from_run()

func get_enemy_intent(enemy_index: int) -> String:
	if enemy_index < 0 or enemy_index >= state.enemies.size():
		return ""
	var enemy := state.enemies[enemy_index]
	var enemy_def := enemy_defs_by_id.get(enemy.id) as EnemyDef
	if enemy_def == null or enemy_def.intent_sequence.is_empty():
		return ""
	var intent_index := enemy_intent_indices[enemy_index] % enemy_def.intent_sequence.size()
	return enemy_def.intent_sequence[intent_index]

func draw_cards(count: int) -> void:
	for _i in range(max(0, count)):
		if state.draw_pile.is_empty():
			if state.discard_pile.is_empty():
				return
			state.draw_pile = _shuffle_card_ids(state.discard_pile)
			state.discard_pile.clear()
		state.hand.append(state.draw_pile.pop_back())

func _initialize_from_run() -> void:
	var node = _find_current_node()
	if node == null:
		_set_invalid("CombatSession current map node is missing: %s" % run.current_node_id)
		return
	if run.deck_ids.is_empty():
		_set_invalid("CombatSession cannot start with an empty deck.")
		return
	var character := catalog.get_character(run.character_id)
	if character == null:
		_set_invalid("CombatSession character is missing: %s" % run.character_id)
		return

	state.player = CombatantState.new(run.character_id, max(1, run.max_hp))
	state.player.current_hp = clamp(run.current_hp, 0, state.player.max_hp)
	state.energy = 3
	state.turn = 1
	state.draw_pile = _shuffle_card_ids(run.deck_ids)

	var encounter_ids := EncounterGenerator.new().generate(catalog, run.seed_value, node.id, node.node_type)
	if encounter_ids.is_empty():
		_set_invalid("CombatSession encounter is empty for node: %s" % node.id)
		return
	for enemy_id in encounter_ids:
		var enemy_def := catalog.get_enemy(enemy_id)
		if enemy_def == null:
			_set_invalid("CombatSession enemy is missing: %s" % enemy_id)
			return
		enemy_defs_by_id[enemy_id] = enemy_def
		state.enemies.append(CombatantState.new(enemy_id, enemy_def.max_hp))
		enemy_intent_indices.append(0)

	draw_cards(5)
	phase = PHASE_PLAYER_TURN

func _find_current_node():
	for node in run.map_nodes:
		if node.id == run.current_node_id:
			return node
	return null

func _shuffle_card_ids(card_ids: Array[String]) -> Array[String]:
	var shuffled: Array = rng.shuffle_copy(card_ids)
	var result: Array[String] = []
	for card_id in shuffled:
		result.append(String(card_id))
	return result

func _set_invalid(message: String) -> void:
	phase = PHASE_INVALID
	error_text = message
```

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [ ] **Step 6: Run Task 1 review gates**

Spec Compliance Review must verify:

- `CombatSession` exists and is UI-independent.
- It initializes player, enemies, draw pile, hand, energy, and turn from run/catalog/current node.
- It uses `EncounterGenerator`.
- It handles missing current node and empty deck without crashing.

Code Quality Review must verify:

- Typed function signatures and variables are clear.
- Initialization helpers have single responsibilities.
- No UI code or scene routing entered `CombatSession`.

- [ ] **Step 7: Commit Task 1**

```powershell
git add scripts/testing/test_runner.gd tests/unit/test_combat_session.gd scripts/combat/combat_session.gd
git commit -m "feat: initialize combat session from encounter"
```

## Task 2: Player Card Selection, Deck Flow, and Cancellable Targeting

**Files:**

- Modify: `tests/unit/test_combat_session.gd`
- Modify: `scripts/combat/combat_session.gd`

- [ ] **Step 1: Add failing player-turn tests**

Append these test methods before `_default_catalog()` in `tests/unit/test_combat_session.gd`:

```gdscript
func test_enemy_target_card_waits_for_enemy_and_can_cancel() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	var selected := session.select_card(0)
	var canceled := session.cancel_selection()

	var passed: bool = selected \
		and canceled \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.pending_hand_index == -1 \
		and session.state.energy == 3 \
		and session.state.hand == ["sword.strike"] \
		and session.state.discard_pile.is_empty() \
		and session.state.enemies[0].current_hp == 20
	assert(passed)
	return passed

func test_enemy_target_card_damages_selected_enemy_and_discards() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.strike"]
	session.state.draw_pile.clear()
	session.state.discard_pile.clear()
	var enemies: Array[CombatantState] = [
		CombatantState.new("first_enemy", 30),
		CombatantState.new("second_enemy", 30),
	]
	session.state.enemies = enemies

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(1)

	var first_enemy_hp := session.state.enemies[0].current_hp
	var second_enemy_hp := session.state.enemies[1].current_hp
	var passed: bool = selected \
		and confirmed \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and first_enemy_hp == session.state.enemies[0].max_hp \
		and second_enemy_hp == session.state.enemies[1].max_hp - 6 \
		and session.state.energy == 2 \
		and session.state.hand.is_empty() \
		and session.state.discard_pile == ["sword.strike"]
	assert(passed)
	return passed

func test_player_target_card_requires_confirmation_and_can_cancel() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)
	var selected := session.select_card(0)
	var canceled := session.cancel_selection()
	selected = selected and session.select_card(0)
	var confirmed := session.confirm_player_target()

	var passed: bool = selected \
		and canceled \
		and confirmed \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.player.block == 7 \
		and session.state.energy == 2 \
		and session.state.hand.is_empty() \
		and session.state.discard_pile == ["sword.guard"]
	assert(passed)
	return passed

func test_mixed_target_card_affects_enemy_and_player() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.horizon_arc"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.horizon_arc"]
	session.state.energy = 3
	var enemy_hp_before := session.state.enemies[0].current_hp

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(0)

	var passed: bool = selected \
		and confirmed \
		and session.state.enemies[0].current_hp == enemy_hp_before - 6 \
		and session.state.player.block == 4 \
		and session.state.energy == 1
	assert(passed)
	return passed

func test_draw_effect_resolves_before_played_card_enters_discard() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.flash_cut"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.flash_cut"]
	session.state.draw_pile.clear()
	session.state.discard_pile.clear()

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(0)

	var passed: bool = selected \
		and confirmed \
		and session.state.hand.is_empty() \
		and session.state.discard_pile == ["sword.flash_cut"]
	assert(passed)
	return passed

func test_insufficient_energy_keeps_card_in_hand() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.horizon_arc"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.energy = 1
	var selected := session.select_card(0)

	var passed: bool = not selected \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.error_text.contains("energy") \
		and session.state.energy == 1 \
		and session.state.hand == ["sword.horizon_arc"] \
		and session.state.discard_pile.is_empty()
	assert(passed)
	return passed

func test_draw_reshuffles_discard_when_draw_pile_is_empty() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand.clear()
	session.state.draw_pile.clear()
	session.state.discard_pile = ["sword.guard", "sword.qi_surge"]

	session.draw_cards(2)

	var passed: bool = session.state.hand.size() == 2 \
		and session.state.draw_pile.is_empty() \
		and session.state.discard_pile.is_empty() \
		and _all_values_in_pool(session.state.hand, ["sword.guard", "sword.qi_surge"])
	assert(passed)
	return passed
```

Append this helper after `_run_with_single_node()`:

```gdscript
func _all_values_in_pool(values: Array[String], pool: Array[String]) -> bool:
	for value in values:
		if not pool.has(value):
			return false
	return true
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: failures in `test_combat_session.gd` because `select_card()`, `cancel_selection()`, `confirm_enemy_target()`, and `confirm_player_target()` do not exist yet.

- [ ] **Step 3: Implement player selection and card play**

Add these public methods to `scripts/combat/combat_session.gd` after `draw_cards()`:

```gdscript
func select_card(hand_index: int) -> bool:
	error_text = ""
	if phase != PHASE_PLAYER_TURN:
		error_text = "Cannot select a card outside the player turn."
		return false
	if hand_index < 0 or hand_index >= state.hand.size():
		error_text = "Card index is outside the hand."
		return false
	var card := catalog.get_card(state.hand[hand_index])
	if card == null:
		error_text = "Card is missing from catalog: %s" % state.hand[hand_index]
		return false
	if card.cost > state.energy:
		error_text = "Not enough energy to play card: %s" % card.id
		return false
	pending_hand_index = hand_index
	pending_card = card
	if _card_requires_enemy_target(card):
		phase = PHASE_SELECTING_ENEMY_TARGET
	else:
		phase = PHASE_CONFIRMING_PLAYER_TARGET
	return true

func cancel_selection() -> bool:
	if phase != PHASE_SELECTING_ENEMY_TARGET and phase != PHASE_CONFIRMING_PLAYER_TARGET:
		return false
	_clear_pending_selection()
	phase = PHASE_PLAYER_TURN
	error_text = ""
	return true

func confirm_enemy_target(enemy_index: int) -> bool:
	error_text = ""
	if phase != PHASE_SELECTING_ENEMY_TARGET:
		error_text = "No enemy-target card is pending."
		return false
	if enemy_index < 0 or enemy_index >= state.enemies.size():
		error_text = "Enemy target index is invalid."
		return false
	var target := state.enemies[enemy_index]
	if target.is_defeated():
		error_text = "Cannot target a defeated enemy."
		return false
	return _play_pending_card(target)

func confirm_player_target() -> bool:
	error_text = ""
	if phase != PHASE_CONFIRMING_PLAYER_TARGET:
		error_text = "No player-target card is pending."
		return false
	return _play_pending_card(state.player)
```

Add these private helpers near the bottom of `scripts/combat/combat_session.gd`:

```gdscript
func _card_requires_enemy_target(card: CardDef) -> bool:
	for effect in card.effects:
		var target_name := String(effect.target).to_lower()
		if target_name == "enemy" or target_name == "target":
			return true
	return false

func _play_pending_card(target: CombatantState) -> bool:
	if pending_card == null or pending_hand_index < 0 or pending_hand_index >= state.hand.size():
		error_text = "No pending card can be played."
		return false
	if pending_card.cost > state.energy:
		error_text = "Not enough energy to play pending card: %s" % pending_card.id
		return false
	var played_card_id := state.hand[pending_hand_index]
	state.energy -= pending_card.cost
	state.hand.remove_at(pending_hand_index)
	engine.play_card_in_state(pending_card, state, state.player, target)
	_clear_pending_selection()
	_resolve_pending_draws()
	state.discard_pile.append(played_card_id)
	_update_terminal_phase()
	if phase != PHASE_WON and phase != PHASE_LOST:
		phase = PHASE_PLAYER_TURN
	return true

func _resolve_pending_draws() -> void:
	if state.pending_draw_count <= 0:
		return
	var draw_count := state.pending_draw_count
	state.pending_draw_count = 0
	draw_cards(draw_count)

func _clear_pending_selection() -> void:
	pending_hand_index = -1
	pending_card = null

func _update_terminal_phase() -> void:
	if state.player != null and state.player.is_defeated():
		_finish_loss()
		return
	var any_enemy_alive := false
	for enemy in state.enemies:
		if not enemy.is_defeated():
			any_enemy_alive = true
			break
	if not any_enemy_alive and not state.enemies.is_empty():
		_finish_win()

func _finish_win() -> void:
	phase = PHASE_WON
	run.current_hp = state.player.current_hp
	if not terminal_rewards_applied:
		run.gold += state.gold_delta
		terminal_rewards_applied = true

func _finish_loss() -> void:
	phase = PHASE_LOST
	run.current_hp = 0
	run.failed = true
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [ ] **Step 5: Run Task 2 review gates**

Spec Compliance Review must verify:

- Enemy-target cards enter `selecting_enemy_target`.
- Player/self cards enter `confirming_player_target`.
- Mixed cards require enemy target and still apply player effects.
- Pending selection can be canceled before costs/effects/card movement.
- Full draw/discard reshuffle behavior exists.

Code Quality Review must verify:

- Target classification is based on effect targets, not card type.
- `_play_pending_card()` does not duplicate effect execution logic.
- Tests use real `CardDef` resources where possible.

- [ ] **Step 6: Commit Task 2**

```powershell
git add tests/unit/test_combat_session.gd scripts/combat/combat_session.gd
git commit -m "feat: add combat card targeting flow"
```

## Task 3: Enemy Turns and Terminal Outcomes

**Files:**

- Modify: `tests/unit/test_combat_session.gd`
- Modify: `scripts/combat/combat_session.gd`

- [ ] **Step 1: Add failing enemy-turn tests**

Append these test methods before `_default_catalog()` in `tests/unit/test_combat_session.gd`:

```gdscript
func test_end_turn_discards_hand_and_enemies_act_in_order() -> bool:
	var catalog := _catalog_with_ordered_enemies()
	var run := _run_with_single_node("node_0", "boss", [
		"sword.strike",
		"sword.guard",
		"sword.qi_surge",
		"sword.cloud_step",
		"sword.focused_slash",
	])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.guard", "sword.qi_surge"]
	session.state.draw_pile = [
		"sword.strike",
		"sword.flash_cut",
		"sword.cloud_step",
		"sword.focused_slash",
		"sword.guard",
	]
	session.state.player.block = 3
	var enemies: Array[CombatantState] = [
		CombatantState.new("first_attacker", 20),
		CombatantState.new("second_attacker", 20),
	]
	session.state.enemies = enemies
	session.enemy_defs_by_id.clear()
	session.enemy_defs_by_id["first_attacker"] = _enemy("first_attacker", "normal", 20, ["attack_5"])
	session.enemy_defs_by_id["second_attacker"] = _enemy("second_attacker", "normal", 20, ["attack_6"])
	var intent_indices: Array[int] = [0, 0]
	session.enemy_intent_indices = intent_indices
	var hp_before := session.state.player.current_hp

	var ended := session.end_player_turn()

	var passed: bool = ended \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.turn == 2 \
		and session.state.energy == 3 \
		and session.state.player.block == 0 \
		and session.state.player.current_hp == hp_before - 11 \
		and session.state.discard_pile.has("sword.guard") \
		and session.state.discard_pile.has("sword.qi_surge")
	assert(passed)
	return passed

func test_enemy_block_clears_at_start_of_next_enemy_turn() -> bool:
	var catalog := _catalog_with_blocking_enemy()
	var run := _run_with_single_node("node_0", "boss", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)

	session.end_player_turn()
	var block_after_first_enemy_turn := session.state.enemies[0].block
	session.end_player_turn()
	var block_after_second_enemy_turn := session.state.enemies[0].block

	var passed: bool = block_after_first_enemy_turn == 8 \
		and block_after_second_enemy_turn == 8
	assert(passed)
	return passed

func test_defeating_all_enemies_sets_won_and_writes_run() -> bool:
	var catalog := _catalog_with_low_hp_enemy()
	var run := _run_with_single_node("node_0", "combat", ["test.execute"])
	run.gold = 5
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["test.execute"]
	session.state.draw_pile.clear()

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(0)

	var passed: bool = selected \
		and confirmed \
		and session.phase == CombatSession.PHASE_WON \
		and run.current_hp == session.state.player.current_hp \
		and run.gold == 5
	assert(passed)
	return passed

func test_player_death_sets_lost_and_failed_run() -> bool:
	var catalog := _catalog_with_lethal_enemy()
	var run := _run_with_single_node("node_0", "boss", ["sword.guard"])
	run.current_hp = 4
	var session := CombatSession.new()
	session.start(catalog, run)

	var ended := session.end_player_turn()

	var passed: bool = ended \
		and session.phase == CombatSession.PHASE_LOST \
		and run.failed \
		and run.current_hp == 0
	assert(passed)
	return passed
```

Append these helpers after `_all_values_in_pool()`:

```gdscript
func _catalog_with_ordered_enemies() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var boss := _enemy("test_boss", "boss", 50, ["attack_5"])
	var elite := _enemy("test_elite", "elite", 40, ["attack_6"])
	catalog.enemies_by_id[boss.id] = boss
	catalog.enemies_by_id[elite.id] = elite
	return catalog

func _catalog_with_blocking_enemy() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var boss := _enemy("test_block_boss", "boss", 50, ["block_8"])
	catalog.enemies_by_id[boss.id] = boss
	return catalog

func _catalog_with_low_hp_enemy() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var enemy := _enemy("test_low_hp", "normal", 3, [])
	catalog.enemies_by_id[enemy.id] = enemy
	var card := CardDef.new()
	card.id = "test.execute"
	card.cost = 1
	card.effects = [_effect("damage", 99, "enemy")]
	catalog.cards_by_id[card.id] = card
	return catalog

func _catalog_with_lethal_enemy() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var boss := _enemy("test_lethal_boss", "boss", 50, ["attack_99"])
	catalog.enemies_by_id[boss.id] = boss
	return catalog

func _enemy(enemy_id: String, tier: String, hp: int, intents: Array[String]) -> EnemyDef:
	var enemy := EnemyDef.new()
	enemy.id = enemy_id
	enemy.tier = tier
	enemy.max_hp = hp
	enemy.intent_sequence = intents
	return enemy

func _effect(effect_type: String, amount: int, target: String) -> EffectDef:
	var effect := EffectDef.new()
	effect.effect_type = effect_type
	effect.amount = amount
	effect.target = target
	return effect
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: failures because `end_player_turn()` does not exist.

- [ ] **Step 3: Implement enemy turns**

Add this public method to `scripts/combat/combat_session.gd` after `confirm_player_target()`:

```gdscript
func end_player_turn() -> bool:
	error_text = ""
	if phase != PHASE_PLAYER_TURN:
		error_text = "Cannot end turn outside the player turn."
		return false
	state.discard_pile.append_array(state.hand)
	state.hand.clear()
	engine.end_turn(state)
	phase = PHASE_ENEMY_TURN
	_run_enemy_turn()
	if phase == PHASE_LOST:
		return true
	draw_cards(5)
	_update_terminal_phase()
	if phase != PHASE_WON and phase != PHASE_LOST:
		phase = PHASE_PLAYER_TURN
	return true
```

Add these private helpers before `_card_requires_enemy_target()`:

```gdscript
func _run_enemy_turn() -> void:
	_clear_enemy_blocks()
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index]
		if enemy.is_defeated():
			continue
		_execute_enemy_intent(enemy_index)
		if state.player.is_defeated():
			_finish_loss()
			return

func _clear_enemy_blocks() -> void:
	for enemy in state.enemies:
		if not enemy.is_defeated():
			enemy.block = 0

func _execute_enemy_intent(enemy_index: int) -> void:
	var enemy := state.enemies[enemy_index]
	var intent := get_enemy_intent(enemy_index)
	if intent.is_empty():
		_advance_enemy_intent(enemy_index)
		return
	var parts := intent.split("_")
	if parts.size() != 2:
		push_error("Unknown enemy intent format: %s" % intent)
		_advance_enemy_intent(enemy_index)
		return
	var amount := max(0, int(parts[1]))
	match String(parts[0]).to_lower():
		"attack":
			state.player.take_damage(amount)
		"block":
			enemy.gain_block(amount)
		_:
			push_error("Unknown enemy intent action: %s" % intent)
	_advance_enemy_intent(enemy_index)

func _advance_enemy_intent(enemy_index: int) -> void:
	if enemy_index >= 0 and enemy_index < enemy_intent_indices.size():
		enemy_intent_indices[enemy_index] += 1
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [ ] **Step 5: Run Task 3 review gates**

Spec Compliance Review must verify:

- Enemy turn order follows `CombatState.enemies`.
- Defeated enemies are skipped.
- `attack_N` and `block_N` intents work.
- Intent indices advance and wrap through `get_enemy_intent()`.
- Win/loss phases write back to `RunState`.

Code Quality Review must verify:

- Intent parsing is small and isolated.
- Terminal result writeback is guarded against repeated reward application.
- Tests do not rely on brittle random output beyond primary/support order.

- [ ] **Step 6: Commit Task 3**

```powershell
git add tests/unit/test_combat_session.gd scripts/combat/combat_session.gd
git commit -m "feat: add enemy turns to combat session"
```

## Task 4: CombatScreen Session UI Wiring

**Files:**

- Modify: `scripts/ui/combat_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [ ] **Step 1: Add failing CombatScreen smoke test**

Append this test after `test_main_menu_rejects_completed_save()` in `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_combat_screen_creates_session_and_cancels_pending_card(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_screen_session_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut", "sword.qi_surge", "sword.cloud_step"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var enemy_container := combat.get_node_or_null("EnemyContainer")
	var hand_container := combat.get_node_or_null("HandContainer")
	var cancel_button := combat.get_node_or_null("CancelSelectionButton") as Button
	var end_turn_button := combat.get_node_or_null("EndTurnButton") as Button
	var first_card := hand_container.get_child(0) as Button if hand_container != null and hand_container.get_child_count() > 0 else null
	if first_card != null:
		first_card.pressed.emit()
	var pending_phase := combat.session.phase == "selecting_enemy_target" \
		or combat.session.phase == "confirming_player_target"
	if cancel_button != null:
		cancel_button.pressed.emit()

	var passed: bool = combat.session != null \
		and enemy_container != null \
		and enemy_container.get_child_count() >= 1 \
		and hand_container != null \
		and hand_container.get_child_count() >= 1 \
		and end_turn_button != null \
		and cancel_button != null \
		and pending_phase \
		and combat.session.phase == "player_turn"
	app.free()
	_delete_test_save("user://test_combat_screen_session_save.json")
	return passed
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: smoke test fails because `CombatScreen` does not create `session`, `EnemyContainer`, `HandContainer`, `CancelSelectionButton`, or `EndTurnButton`.

- [ ] **Step 3: Replace CombatScreen UI script**

Replace `scripts/ui/combat_screen.gd` with:

```gdscript
extends Control

const CombatSession := preload("res://scripts/combat/combat_session.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var session: CombatSession
var status_label: Label
var pile_label: Label
var error_label: Label
var enemy_container: VBoxContainer
var hand_container: HBoxContainer
var player_target_button: Button
var cancel_button: Button
var end_turn_button: Button

func _ready() -> void:
	set_process_unhandled_input(true)
	_build_layout()
	_start_session()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_selection()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_selection()

func _build_layout() -> void:
	status_label = Label.new()
	status_label.name = "PlayerStatus"
	add_child(status_label)

	pile_label = Label.new()
	pile_label.name = "PileStatus"
	pile_label.position.y = 24
	add_child(pile_label)

	error_label = Label.new()
	error_label.name = "CombatError"
	error_label.position.y = 48
	add_child(error_label)

	enemy_container = VBoxContainer.new()
	enemy_container.name = "EnemyContainer"
	enemy_container.position = Vector2(320, 88)
	add_child(enemy_container)

	player_target_button = Button.new()
	player_target_button.name = "PlayerTargetButton"
	player_target_button.text = "Confirm Player Target"
	player_target_button.position = Vector2(16, 88)
	player_target_button.pressed.connect(_on_player_target_pressed)
	add_child(player_target_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelSelectionButton"
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(16, 136)
	cancel_button.pressed.connect(_cancel_selection)
	add_child(cancel_button)

	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "End Turn"
	end_turn_button.position = Vector2(16, 184)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)

	hand_container = HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.position = Vector2(16, 360)
	add_child(hand_container)

func _start_session() -> void:
	var app = get_tree().root.get_node("App")
	var catalog := ContentCatalog.new()
	catalog.load_default()
	session = CombatSession.new()
	session.start(catalog, app.game.current_run)

func _refresh() -> void:
	if session == null:
		return
	status_label.text = _player_status_text()
	pile_label.text = "Draw %s | Discard %s | Exhaust %s | Phase %s" % [
		session.state.draw_pile.size(),
		session.state.discard_pile.size(),
		session.state.exhausted_pile.size(),
		session.phase,
	]
	error_label.text = session.error_text
	player_target_button.visible = session.phase == CombatSession.PHASE_CONFIRMING_PLAYER_TARGET
	cancel_button.visible = session.phase == CombatSession.PHASE_SELECTING_ENEMY_TARGET \
		or session.phase == CombatSession.PHASE_CONFIRMING_PLAYER_TARGET
	end_turn_button.disabled = session.phase != CombatSession.PHASE_PLAYER_TURN
	_refresh_enemies()
	_refresh_hand()
	_route_if_terminal()

func _player_status_text() -> String:
	if session.state.player == null:
		return "No player"
	return "Player %s HP %s/%s Block %s Energy %s Turn %s" % [
		session.state.player.id,
		session.state.player.current_hp,
		session.state.player.max_hp,
		session.state.player.block,
		session.state.energy,
		session.state.turn,
	]

func _refresh_enemies() -> void:
	_clear_children(enemy_container)
	for enemy_index in range(session.state.enemies.size()):
		var enemy = session.state.enemies[enemy_index]
		var button := Button.new()
		button.name = "EnemyButton_%s" % enemy_index
		button.text = "%s HP %s/%s Block %s Intent %s" % [
			enemy.id,
			enemy.current_hp,
			enemy.max_hp,
			enemy.block,
			session.get_enemy_intent(enemy_index),
		]
		button.disabled = enemy.is_defeated()
		button.pressed.connect(func(): _on_enemy_pressed(enemy_index))
		enemy_container.add_child(button)

func _refresh_hand() -> void:
	_clear_children(hand_container)
	for hand_index in range(session.state.hand.size()):
		var card_id := session.state.hand[hand_index]
		var card = session.catalog.get_card(card_id)
		var button := Button.new()
		button.name = "CardButton_%s" % hand_index
		if card == null:
			button.text = "%s (?)" % card_id
		else:
			button.text = "%s (%s)" % [card.id, card.cost]
		button.disabled = session.phase != CombatSession.PHASE_PLAYER_TURN
		button.pressed.connect(func(): _on_card_pressed(hand_index))
		hand_container.add_child(button)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _on_card_pressed(hand_index: int) -> void:
	session.select_card(hand_index)
	_refresh()

func _on_enemy_pressed(enemy_index: int) -> void:
	session.confirm_enemy_target(enemy_index)
	_refresh()

func _on_player_target_pressed() -> void:
	session.confirm_player_target()
	_refresh()

func _cancel_selection() -> void:
	session.cancel_selection()
	_refresh()

func _on_end_turn_pressed() -> void:
	session.end_player_turn()
	_refresh()

func _route_if_terminal() -> void:
	if session.phase == CombatSession.PHASE_WON:
		var app = get_tree().root.get_node("App")
		app.game.router.go_to(SceneRouterScript.REWARD)
	elif session.phase == CombatSession.PHASE_LOST:
		var app = get_tree().root.get_node("App")
		app.game.current_run.failed = true
		app.game.router.go_to(SceneRouterScript.SUMMARY)
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [ ] **Step 5: Run Godot import check**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --quit
```

Expected: exit code `0`.

- [ ] **Step 6: Run Task 4 review gates**

Spec Compliance Review must verify:

- `CombatScreen` creates `CombatSession`.
- UI renders player state, piles, enemies, hand, cancel, player target confirmation, and end turn.
- UI forwards card, enemy, player target, cancel, and end turn actions to session.
- Esc and right-click cancellation are wired.

Code Quality Review must verify:

- UI script owns presentation only; combat rules remain in `CombatSession`.
- Node names used by smoke tests are stable.
- There are no hard-coded assumptions of one enemy.

- [ ] **Step 7: Commit Task 4**

```powershell
git add scripts/ui/combat_screen.gd tests/smoke/test_scene_flow.gd
git commit -m "feat: wire combat screen to session"
```

## Task 5: Final Acceptance and Documentation

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-26-combat-session-targeting.md`

- [ ] **Step 1: Run all local tests**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [ ] **Step 2: Run project import check**

Run:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --quit
```

Expected: exit code `0`.

- [ ] **Step 3: Update README Phase 2 progress**

Add this bullet under `## Phase 2 Progress` in `README.md`:

```markdown
- Combat session targeting loop: complete; map encounters now create multi-enemy combat sessions with real hand, energy, target selection, enemy turns, and win/loss routing
```

- [ ] **Step 4: Update plan execution status**

Add near the top of this plan after the header:

```markdown
## Execution Status

- Completed Task 1: CombatSession initialization.
- Completed Task 2: Player card targeting and deck flow.
- Completed Task 3: Enemy turns and terminal outcomes.
- Completed Task 4: CombatScreen session UI wiring.
- Completed Task 5: Final acceptance and documentation.
- Final verification: Godot tests passed and import check exited 0.
```

- [ ] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Compare implementation against `docs/superpowers/specs/2026-04-26-combat-session-targeting-design.md`.
- Verify all planned files exist.
- Verify no unplanned content resources, save fields, autoloads, input map changes, or polished presentation work were added.
- Verify map-to-combat, deck flow, target selection, enemy turns, and terminal routing are covered by tests.

Stage 2 Code Quality Review:

- Check GDScript typing.
- Check UI/session separation.
- Check helper names and single responsibility.
- Check resource loading and node path usage.
- Check tests are behavior-focused and not overly brittle.

- [ ] **Step 6: Commit final docs**

```powershell
git add README.md docs/superpowers/plans/2026-04-26-combat-session-targeting.md
git commit -m "docs: mark combat session targeting complete"
```

## Self-Review Checklist

Before considering this plan complete, verify:

- Spec coverage: every requirement in `2026-04-26-combat-session-targeting-design.md` maps to a task.
- TDD coverage: every behavior change has a failing-test step before implementation.
- Targeting coverage: enemy-target, player-target, mixed-target, insufficient-energy, and cancel paths are included.
- Enemy turn coverage: attack, block, intent order, block clearing, win, and loss are included.
- UI coverage: CombatScreen creates session and exposes stable nodes for smoke tests.
- Scope discipline: no formal new content resources, save schema fields, animation, relics, events, shops, or combat save recovery.
- Verification: final Godot tests and import check are required.

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-04-26-combat-session-targeting.md`.

Two execution options:

1. **Subagent-Driven (recommended)** - Dispatch a fresh `gpt-5.5` + `xhigh` subagent per task, with two-stage review between tasks.
2. **Inline Execution** - Execute tasks in this session using plan checkpoints, still running the same tests and reviews.
