# DevTools Reward Inspector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a DevTools Reward Inspector that previews generated rewards and simulates claim or skip choices against an isolated run.

**Architecture:** Add `RewardApplier` as shared reward-claim logic used by both `RewardScreen` and DevTools. `DevToolsScreen` owns Reward Inspector configuration, creates an isolated `RunState`, generates rewards through `RewardResolver`, and applies simulated claims only to that isolated run.

**Tech Stack:** Godot 4.6.2-stable, GDScript, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Before editing code, verify `git branch --show-current` is `main`; stop if it is not.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`.
- Preserve existing Event Tester work already present in the working tree.
- Reward Inspector must not write saves, edit resources, route away from DevTools, advance map state, or mutate an existing run.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-dev-tools-reward-inspector-design.md`

## Verification Commands

Run full tests:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

Run import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Create:

- `scripts/reward/reward_applier.gd`: shared reward claim helper.
- `tests/unit/test_reward_applier.gd`: unit coverage for reward application.

Modify:

- `scripts/testing/test_runner.gd`: register the new reward applier test file.
- `scripts/ui/reward_screen.gd`: replace inline claim mutations with `RewardApplier`.
- `scripts/ui/dev_tools_screen.gd`: Reward Inspector state helpers, isolated run creation, reward claim simulation, and panel UI.
- `tests/unit/test_dev_tools_screen.gd`: Reward Inspector helper and isolated simulation coverage.
- `tests/smoke/test_scene_flow.gd`: DevTools Reward Inspector UI smoke coverage.
- `README.md`: record Reward Inspector completion and update next plans after acceptance.
- `docs/superpowers/plans/2026-04-29-dev-tools-reward-inspector.md`: mark steps complete during execution.

## Task 1: Shared RewardApplier

**Files:**

- Modify: `scripts/testing/test_runner.gd`
- Create: `tests/unit/test_reward_applier.gd`
- Create: `scripts/reward/reward_applier.gd`
- Modify: `scripts/ui/reward_screen.gd`

- [ ] **Step 1: Verify branch and inspect working tree**

Run:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
main
```

`git status --short` may show existing Event Tester files and this Reward Inspector plan. Do not revert or overwrite those changes.

- [ ] **Step 2: Register the new RewardApplier test file**

In `scripts/testing/test_runner.gd`, insert the new test file immediately after `test_reward_resolver.gd`:

```gdscript
	"res://tests/unit/test_reward_resolver.gd",
	"res://tests/unit/test_reward_applier.gd",
	"res://tests/unit/test_event_resolver.gd",
```

- [ ] **Step 3: Add failing RewardApplier unit tests**

Create `tests/unit/test_reward_applier.gd`:

```gdscript
extends RefCounted

const RewardApplier := preload("res://scripts/reward/reward_applier.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_claim_card_adds_selected_card_to_deck() -> bool:
	var run := RunState.new()
	run.deck_ids = ["sword.strike"]
	var reward := {
		"type": "card_choice",
		"card_ids": ["sword.guard", "sword.flash_cut"],
	}
	var applied := RewardApplier.new().claim_card(run, reward, 1)
	var passed: bool = applied \
		and run.deck_ids == ["sword.strike", "sword.flash_cut"]
	assert(passed)
	return passed

func test_claim_card_rejects_invalid_index_without_mutation() -> bool:
	var run := RunState.new()
	run.deck_ids = ["sword.strike"]
	var reward := {
		"type": "card_choice",
		"card_ids": ["sword.guard"],
	}
	var applied := RewardApplier.new().claim_card(run, reward, 3)
	var passed: bool = not applied and run.deck_ids == ["sword.strike"]
	assert(passed)
	return passed

func test_claim_gold_adds_amount_to_run_gold() -> bool:
	var run := RunState.new()
	run.gold = 7
	var reward := {
		"type": "gold",
		"amount": 12,
	}
	var applied := RewardApplier.new().claim_gold(run, reward)
	var passed: bool = applied and run.gold == 19
	assert(passed)
	return passed

func test_claim_relic_adds_unique_relic_only_once() -> bool:
	var run := RunState.new()
	run.relic_ids = ["jade_talisman"]
	var reward := {
		"type": "relic",
		"relic_id": "jade_talisman",
		"tier": "common",
	}
	var first := RewardApplier.new().claim_relic(run, reward)
	var second_reward := {
		"type": "relic",
		"relic_id": "moonwell_seed",
		"tier": "uncommon",
	}
	var second := RewardApplier.new().claim_relic(run, second_reward)
	var passed: bool = first \
		and second \
		and run.relic_ids == ["jade_talisman", "moonwell_seed"]
	assert(passed)
	return passed

func test_claim_relic_rejects_empty_relic_id() -> bool:
	var run := RunState.new()
	var reward := {
		"type": "relic",
		"relic_id": "",
	}
	var applied := RewardApplier.new().claim_relic(run, reward)
	var passed: bool = not applied and run.relic_ids.is_empty()
	assert(passed)
	return passed
```

- [ ] **Step 4: Run tests to verify RED**

Run the full test command.

Expected: FAIL because `res://scripts/reward/reward_applier.gd` does not exist.

- [ ] **Step 5: Implement RewardApplier**

Create `scripts/reward/reward_applier.gd`:

```gdscript
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
```

- [ ] **Step 6: Refactor RewardScreen to use RewardApplier**

In `scripts/ui/reward_screen.gd`, add the preload:

```gdscript
const RewardApplier := preload("res://scripts/reward/reward_applier.gd")
```

Add the instance field near the existing state vars:

```gdscript
var reward_applier := RewardApplier.new()
```

Replace `_claim_card()` with:

```gdscript
func _claim_card(reward_index: int, card_index: int) -> void:
	if not _is_reward_available(reward_index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if reward_applier.claim_card(app.game.current_run, rewards[reward_index], card_index):
		reward_states[reward_index] = STATE_CLAIMED
		_render_rewards()
		_refresh_continue_button()
```

Replace `_claim_gold()` with:

```gdscript
func _claim_gold(reward_index: int) -> void:
	if not _is_reward_available(reward_index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if reward_applier.claim_gold(app.game.current_run, rewards[reward_index]):
		reward_states[reward_index] = STATE_CLAIMED
		_render_rewards()
		_refresh_continue_button()
```

Replace `_claim_relic()` with:

```gdscript
func _claim_relic(reward_index: int) -> void:
	if not _is_reward_available(reward_index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if reward_applier.claim_relic(app.game.current_run, rewards[reward_index]):
		reward_states[reward_index] = STATE_CLAIMED
		_render_rewards()
		_refresh_continue_button()
```

- [ ] **Step 7: Run tests to verify GREEN for Task 1**

Run the full test command.

Expected: `TESTS PASSED`.

- [ ] **Step 8: Task 1 review gates**

Stage 1:

- `RewardApplier` exists and applies card, gold, and relic rewards.
- `RewardScreen` uses `RewardApplier` for claim mutations.
- `RewardScreen` still owns skip, continue gating, save, map advancement, and routing.
- Existing reward smoke tests still cover real RewardScreen behavior.

Stage 2:

- `RewardApplier` is typed and small.
- Reward application rules are not duplicated in `RewardScreen`.
- Invalid reward shapes return `false` without mutating runs.
- No save, routing, or catalog dependencies were added to `RewardApplier`.

## Task 2: Reward Inspector Helpers

**Files:**

- Modify: `tests/unit/test_dev_tools_screen.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [ ] **Step 1: Add failing Reward Inspector unit tests**

In `tests/unit/test_dev_tools_screen.gd`, add these constants near the existing DevTools preload:

```gdscript
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")
```

Append these tests before helper functions:

```gdscript
func test_reward_inspector_default_config_uses_sword_combat_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var config: Dictionary = screen.reward_inspector_config()
	var run: Variant = screen.reward_inspector_run
	var passed: bool = config.get("character_id") == "sword" \
		and config.get("node_type") == "combat" \
		and config.get("seed_value") == 1 \
		and config.get("deck_ids") == ["sword.strike", "sword.strike", "sword.strike"] \
		and run != null \
		and run.character_id == "sword" \
		and run.current_node_id == "reward_inspector_node" \
		and run.map_nodes.size() == 1 \
		and run.map_nodes[0].node_type == "combat"
	screen.free()
	assert(passed)
	return passed

func test_reward_inspector_rewards_match_resolver_for_current_config() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_reward_inspector_node_type("boss")
	screen.set_reward_inspector_seed(222)
	var expected: Array[Dictionary] = RewardResolver.new().resolve(screen.catalog, screen.reward_inspector_run)
	var passed: bool = screen.reward_inspector_rewards == expected \
		and expected.size() == 3 \
		and screen.reward_inspector_reward_text(0).contains("type: card_choice") \
		and screen.reward_inspector_reward_text(1).contains("type: gold") \
		and screen.reward_inspector_reward_text(2).contains("type: relic")
	screen.free()
	assert(passed)
	return passed

func test_reward_inspector_claim_card_mutates_only_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var before_size: int = screen.reward_inspector_run.deck_ids.size()
	var claimed := screen.claim_reward_inspector_card(0, 0)
	var summary := screen.reward_inspector_run_summary_text()
	var passed: bool = claimed \
		and screen.reward_inspector_run.deck_ids.size() == before_size + 1 \
		and screen.reward_inspector_reward_states[0] == "claimed" \
		and summary.contains("resolved: 1/2") \
		and summary.contains("deck_count: 4")
	screen.free()
	assert(passed)
	return passed

func test_reward_inspector_skip_and_reset_clear_reward_state() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var skipped := screen.skip_reward_inspector_reward(1)
	screen.reset_reward_inspector_run()
	var passed: bool = skipped \
		and screen.reward_inspector_run.gold == 0 \
		and screen.reward_inspector_reward_states.size() == screen.reward_inspector_rewards.size() \
		and screen.reward_inspector_reward_states[0] == "available" \
		and screen.reward_inspector_run_summary_text().contains("resolved: 0/2")
	screen.free()
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests to verify RED**

Run the full test command.

Expected: FAIL because Reward Inspector helper methods and fields do not exist.

- [ ] **Step 3: Add Reward Inspector preloads, constants, and state**

In `scripts/ui/dev_tools_screen.gd`, add preloads:

```gdscript
const RewardApplier := preload("res://scripts/reward/reward_applier.gd")
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")
```

Add constants:

```gdscript
const TOOL_REWARD_INSPECTOR := "reward_inspector"
const DEFAULT_REWARD_INSPECTOR_CHARACTER := "sword"
const DEFAULT_REWARD_INSPECTOR_NODE_TYPE := "combat"
const DEFAULT_REWARD_INSPECTOR_SEED := 1
const REWARD_INSPECTOR_NODE_ID := "reward_inspector_node"
const REWARD_INSPECTOR_NODE_TYPES: Array[String] = ["combat", "elite", "boss"]
const REWARD_STATE_AVAILABLE := "available"
const REWARD_STATE_CLAIMED := "claimed"
const REWARD_STATE_SKIPPED := "skipped"
```

Add state:

```gdscript
var selected_reward_inspector_character_id := DEFAULT_REWARD_INSPECTOR_CHARACTER
var selected_reward_inspector_node_type := DEFAULT_REWARD_INSPECTOR_NODE_TYPE
var selected_reward_inspector_seed := DEFAULT_REWARD_INSPECTOR_SEED
var reward_inspector_run: RunState
var reward_inspector_rewards: Array[Dictionary] = []
var reward_inspector_reward_states: Array[String] = []
var reward_applier := RewardApplier.new()
```

Call `reset_reward_inspector_run()` from `_ready()` and `load_default_catalog()` after Event Tester defaults are set.

- [ ] **Step 4: Implement Reward Inspector public helpers**

Add these methods to `scripts/ui/dev_tools_screen.gd` near the Event Tester helpers:

```gdscript
func set_reward_inspector_character(character_id: String) -> void:
	if catalog.get_character(character_id) == null:
		return
	selected_reward_inspector_character_id = character_id
	reset_reward_inspector_run()
	_refresh_reward_inspector_if_ready()

func set_reward_inspector_node_type(node_type: String) -> void:
	if not REWARD_INSPECTOR_NODE_TYPES.has(node_type):
		return
	selected_reward_inspector_node_type = node_type
	reset_reward_inspector_run()
	_refresh_reward_inspector_if_ready()

func set_reward_inspector_seed(seed_value: int) -> void:
	selected_reward_inspector_seed = max(1, seed_value)
	reset_reward_inspector_run()
	_refresh_reward_inspector_if_ready()

func reset_reward_inspector_run() -> void:
	_ensure_reward_inspector_defaults()
	reward_inspector_run = _create_reward_inspector_run()
	reward_inspector_rewards = RewardResolver.new().resolve(catalog, reward_inspector_run)
	reward_inspector_reward_states.clear()
	for _reward in reward_inspector_rewards:
		reward_inspector_reward_states.append(REWARD_STATE_AVAILABLE)

func reward_inspector_config() -> Dictionary:
	_ensure_reward_inspector_defaults()
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	return {
		"character_id": selected_reward_inspector_character_id,
		"node_type": selected_reward_inspector_node_type,
		"seed_value": selected_reward_inspector_seed,
		"deck_ids": reward_inspector_run.deck_ids.duplicate(),
	}

func reward_inspector_run_summary_text() -> String:
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	return "\n".join([
		"character: %s" % reward_inspector_run.character_id,
		"node_type: %s" % selected_reward_inspector_node_type,
		"seed: %s" % selected_reward_inspector_seed,
		"hp: %s/%s" % [reward_inspector_run.current_hp, reward_inspector_run.max_hp],
		"gold: %s" % reward_inspector_run.gold,
		"deck_count: %s" % reward_inspector_run.deck_ids.size(),
		"deck: %s" % _join_string_array(reward_inspector_run.deck_ids),
		"relics: %s" % _join_string_array(reward_inspector_run.relic_ids),
		"resolved: %s/%s" % [_resolved_reward_inspector_count(), reward_inspector_rewards.size()],
	])

func reward_inspector_reward_text(index: int) -> String:
	if index < 0 or index >= reward_inspector_rewards.size():
		return "reward: unavailable"
	var reward := reward_inspector_rewards[index]
	var lines: Array[String] = [
		"reward: %s" % String(reward.get("id", "")),
		"type: %s" % String(reward.get("type", "")),
		"state: %s" % reward_inspector_reward_states[index],
	]
	match String(reward.get("type", "")):
		"card_choice":
			var card_ids: Array = reward.get("card_ids", [])
			lines.append("cards: %s" % _join_variant_string_array(card_ids))
		"gold":
			lines.append("amount: %s" % int(reward.get("amount", 0)))
			lines.append("tier: %s" % String(reward.get("tier", "")))
		"relic":
			lines.append("relic: %s" % String(reward.get("relic_id", "")))
			lines.append("tier: %s" % String(reward.get("tier", "")))
	return " | ".join(lines)

func claim_reward_inspector_card(reward_index: int, card_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	if reward_applier.claim_card(reward_inspector_run, reward_inspector_rewards[reward_index], card_index):
		reward_inspector_reward_states[reward_index] = REWARD_STATE_CLAIMED
		_refresh_reward_inspector_if_ready()
		return true
	return false

func claim_reward_inspector_gold(reward_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	if reward_applier.claim_gold(reward_inspector_run, reward_inspector_rewards[reward_index]):
		reward_inspector_reward_states[reward_index] = REWARD_STATE_CLAIMED
		_refresh_reward_inspector_if_ready()
		return true
	return false

func claim_reward_inspector_relic(reward_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	if reward_applier.claim_relic(reward_inspector_run, reward_inspector_rewards[reward_index]):
		reward_inspector_reward_states[reward_index] = REWARD_STATE_CLAIMED
		_refresh_reward_inspector_if_ready()
		return true
	return false

func skip_reward_inspector_reward(reward_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	reward_inspector_reward_states[reward_index] = REWARD_STATE_SKIPPED
	_refresh_reward_inspector_if_ready()
	return true
```

- [ ] **Step 5: Implement Reward Inspector private helpers**

Add:

```gdscript
func _ensure_reward_inspector_defaults() -> void:
	if catalog.get_character(selected_reward_inspector_character_id) == null:
		var character_ids := _dev_tools_character_ids(DEFAULT_REWARD_INSPECTOR_CHARACTER)
		selected_reward_inspector_character_id = character_ids[0] if not character_ids.is_empty() else ""
	if not REWARD_INSPECTOR_NODE_TYPES.has(selected_reward_inspector_node_type):
		selected_reward_inspector_node_type = DEFAULT_REWARD_INSPECTOR_NODE_TYPE
	selected_reward_inspector_seed = max(1, selected_reward_inspector_seed)

func _create_reward_inspector_run() -> RunState:
	var run := RunState.new()
	var character := catalog.get_character(selected_reward_inspector_character_id)
	run.seed_value = selected_reward_inspector_seed
	run.character_id = selected_reward_inspector_character_id
	run.gold = 0
	run.current_node_id = REWARD_INSPECTOR_NODE_ID
	var node := MapNodeState.new(REWARD_INSPECTOR_NODE_ID, 0, selected_reward_inspector_node_type)
	node.unlocked = true
	run.map_nodes = [node]
	if character != null:
		run.max_hp = character.max_hp
		run.current_hp = character.max_hp
		run.deck_ids = _copy_string_array(character.starting_deck_ids)
	return run

func _is_reward_inspector_reward_available(reward_index: int) -> bool:
	return reward_inspector_run != null \
		and reward_index >= 0 \
		and reward_index < reward_inspector_reward_states.size() \
		and reward_inspector_reward_states[reward_index] == REWARD_STATE_AVAILABLE

func _resolved_reward_inspector_count() -> int:
	var result := 0
	for state in reward_inspector_reward_states:
		if state != REWARD_STATE_AVAILABLE:
			result += 1
	return result

func _join_variant_string_array(values: Array) -> String:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return _join_string_array(result)

func _refresh_reward_inspector_if_ready() -> void:
	if reward_inspector_reward_list != null and reward_inspector_run_summary_label != null:
		_refresh_reward_inspector_panel()
```

Do not add any save, router, or `Game.current_run` references in these helpers.

- [ ] **Step 6: Run tests to verify GREEN for Task 2**

Run the full test command.

Expected: `TESTS PASSED`.

- [ ] **Step 7: Task 2 review gates**

Stage 1:

- Reward Inspector helper methods exist.
- Default isolated run uses `sword`, `combat`, seed `1`, and `reward_inspector_node`.
- Reward packages are generated through `RewardResolver`.
- Claim and skip mutate only `reward_inspector_run` and local reward states.

Stage 2:

- Helpers are typed and deterministic.
- Reward claim logic calls `RewardApplier`.
- Empty catalog fallback paths avoid crashes.
- No `current_run`, save, resource write, router, or progression calls were added.

## Task 3: Reward Inspector Panel UI

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [ ] **Step 1: Add failing Reward Inspector smoke tests**

Append these smoke tests near the other DevTools tests in `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_dev_tools_reward_inspector_button_shows_panel(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_reward_inspector") as Button
	if button != null:
		button.pressed.emit()
	var panel := _find_node_by_name(screen, "RewardInspectorPanel")
	var summary := _find_node_by_name(screen, "RewardInspectorRunSummaryLabel") as Label
	var reward := _find_node_by_name(screen, "RewardInspectorReward_0")
	var claim := _find_node_by_name(screen, "RewardInspectorClaimCard_0_0") as Button
	var reset := _find_node_by_name(screen, "RewardInspectorResetButton") as Button
	var passed: bool = button != null \
		and screen.active_tool_id == "reward_inspector" \
		and panel != null \
		and summary != null \
		and summary.text.contains("node_type: combat") \
		and summary.text.contains("seed: 1") \
		and reward != null \
		and claim != null \
		and reset != null
	screen.free()
	return passed

func test_dev_tools_reward_inspector_claim_stays_in_dev_tools_without_current_run(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_reward_inspector_claim_save.json")
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var reward_button := _find_node_by_name(dev_tools, "ToolButton_reward_inspector") as Button
	if reward_button != null:
		reward_button.pressed.emit()
	var claim := _find_node_by_name(dev_tools, "RewardInspectorClaimCard_0_0") as Button
	if claim != null:
		claim.pressed.emit()
	var summary := _find_node_by_name(dev_tools, "RewardInspectorRunSummaryLabel") as Label
	var passed: bool = claim != null \
		and summary != null \
		and summary.text.contains("deck_count: 4") \
		and summary.text.contains("resolved: 1/2") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save("user://test_reward_inspector_claim_save.json")
	return passed

func test_dev_tools_reward_inspector_node_type_selection_refreshes_rewards(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_reward_inspector") as Button
	if button != null:
		button.pressed.emit()
	var node_select := _find_node_by_name(screen, "RewardInspectorNodeTypeSelect") as OptionButton
	if node_select != null:
		node_select.select(2)
		node_select.item_selected.emit(2)
	var summary := _find_node_by_name(screen, "RewardInspectorRunSummaryLabel") as Label
	var relic_button := _find_node_by_name(screen, "RewardInspectorClaimRelic_2") as Button
	var passed: bool = node_select != null \
		and summary != null \
		and summary.text.contains("node_type: boss") \
		and summary.text.contains("resolved: 0/3") \
		and relic_button != null
	screen.free()
	return passed
```

- [ ] **Step 2: Run tests to verify RED**

Run the full test command.

Expected: FAIL because Reward Inspector panel nodes do not exist.

- [ ] **Step 3: Add Reward Inspector UI vars and routing**

In `scripts/ui/dev_tools_screen.gd`, add UI state vars:

```gdscript
var reward_inspector_character_select: OptionButton
var reward_inspector_node_type_select: OptionButton
var reward_inspector_seed_spin_box: SpinBox
var reward_inspector_run_summary_label: Label
var reward_inspector_reward_list: VBoxContainer
```

Update `_show_tool()` so `TOOL_REWARD_INSPECTOR` calls `_build_reward_inspector()`:

```gdscript
	elif tool_id == TOOL_REWARD_INSPECTOR:
		_build_reward_inspector()
```

- [ ] **Step 4: Implement Reward Inspector panel**

Add these methods:

```gdscript
func _build_reward_inspector() -> void:
	_ensure_reward_inspector_defaults()
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	var panel := VBoxContainer.new()
	panel.name = "RewardInspectorPanel"
	tool_content.add_child(panel)

	reward_inspector_character_select = OptionButton.new()
	reward_inspector_character_select.name = "RewardInspectorCharacterSelect"
	for character_id in _dev_tools_character_ids(DEFAULT_REWARD_INSPECTOR_CHARACTER):
		reward_inspector_character_select.add_item(character_id)
		if character_id == selected_reward_inspector_character_id:
			reward_inspector_character_select.select(reward_inspector_character_select.get_item_count() - 1)
	reward_inspector_character_select.item_selected.connect(_on_reward_inspector_character_selected)
	panel.add_child(reward_inspector_character_select)

	reward_inspector_node_type_select = OptionButton.new()
	reward_inspector_node_type_select.name = "RewardInspectorNodeTypeSelect"
	for node_type in REWARD_INSPECTOR_NODE_TYPES:
		reward_inspector_node_type_select.add_item(node_type)
		if node_type == selected_reward_inspector_node_type:
			reward_inspector_node_type_select.select(reward_inspector_node_type_select.get_item_count() - 1)
	reward_inspector_node_type_select.item_selected.connect(_on_reward_inspector_node_type_selected)
	panel.add_child(reward_inspector_node_type_select)

	reward_inspector_seed_spin_box = SpinBox.new()
	reward_inspector_seed_spin_box.name = "RewardInspectorSeedSpinBox"
	reward_inspector_seed_spin_box.min_value = 1
	reward_inspector_seed_spin_box.max_value = 999999
	reward_inspector_seed_spin_box.step = 1
	reward_inspector_seed_spin_box.value = selected_reward_inspector_seed
	reward_inspector_seed_spin_box.value_changed.connect(_on_reward_inspector_seed_changed)
	panel.add_child(reward_inspector_seed_spin_box)

	reward_inspector_run_summary_label = Label.new()
	reward_inspector_run_summary_label.name = "RewardInspectorRunSummaryLabel"
	reward_inspector_run_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(reward_inspector_run_summary_label)

	reward_inspector_reward_list = VBoxContainer.new()
	reward_inspector_reward_list.name = "RewardInspectorRewardList"
	panel.add_child(reward_inspector_reward_list)

	var reset := Button.new()
	reset.name = "RewardInspectorResetButton"
	reset.text = "Reset Reward Run"
	reset.pressed.connect(_on_reward_inspector_reset_pressed)
	panel.add_child(reset)

	_refresh_reward_inspector_panel()

func _on_reward_inspector_character_selected(index: int) -> void:
	if reward_inspector_character_select == null:
		return
	set_reward_inspector_character(reward_inspector_character_select.get_item_text(index))

func _on_reward_inspector_node_type_selected(index: int) -> void:
	if reward_inspector_node_type_select == null:
		return
	set_reward_inspector_node_type(reward_inspector_node_type_select.get_item_text(index))

func _on_reward_inspector_seed_changed(value: float) -> void:
	set_reward_inspector_seed(int(value))

func _on_reward_inspector_reset_pressed() -> void:
	reset_reward_inspector_run()
	_refresh_reward_inspector_panel()
```

- [ ] **Step 5: Implement Reward Inspector panel refresh**

Add:

```gdscript
func _refresh_reward_inspector_panel() -> void:
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	if reward_inspector_run_summary_label != null:
		reward_inspector_run_summary_label.text = reward_inspector_run_summary_text()
	if reward_inspector_reward_list == null:
		return
	_clear_children(reward_inspector_reward_list)
	if reward_inspector_rewards.is_empty():
		var empty := Label.new()
		empty.name = "RewardInspectorNoRewardsLabel"
		empty.text = "No rewards"
		reward_inspector_reward_list.add_child(empty)
		return
	for i in range(reward_inspector_rewards.size()):
		_add_reward_inspector_reward_row(i)

func _add_reward_inspector_reward_row(reward_index: int) -> void:
	var reward := reward_inspector_rewards[reward_index]
	var item := VBoxContainer.new()
	item.name = "RewardInspectorReward_%s" % reward_index
	reward_inspector_reward_list.add_child(item)

	var label := Label.new()
	label.name = "RewardInspectorRewardLabel_%s" % reward_index
	label.text = reward_inspector_reward_text(reward_index)
	item.add_child(label)

	if reward_inspector_reward_states[reward_index] != REWARD_STATE_AVAILABLE:
		return

	match String(reward.get("type", "")):
		"card_choice":
			var card_ids: Array = reward.get("card_ids", [])
			for card_index in range(card_ids.size()):
				var button := Button.new()
				button.name = "RewardInspectorClaimCard_%s_%s" % [reward_index, card_index]
				button.text = "Claim %s" % String(card_ids[card_index])
				var selected_reward_index := reward_index
				var selected_card_index := card_index
				button.pressed.connect(func(): claim_reward_inspector_card(selected_reward_index, selected_card_index))
				item.add_child(button)
			item.add_child(_reward_inspector_skip_button(reward_index))
		"gold":
			var gold_button := Button.new()
			gold_button.name = "RewardInspectorClaimGold_%s" % reward_index
			gold_button.text = "Claim %s gold" % int(reward.get("amount", 0))
			var selected_gold_reward_index := reward_index
			gold_button.pressed.connect(func(): claim_reward_inspector_gold(selected_gold_reward_index))
			item.add_child(gold_button)
			item.add_child(_reward_inspector_skip_button(reward_index))
		"relic":
			var relic_button := Button.new()
			relic_button.name = "RewardInspectorClaimRelic_%s" % reward_index
			relic_button.text = "Claim %s" % String(reward.get("relic_id", ""))
			var selected_relic_reward_index := reward_index
			relic_button.pressed.connect(func(): claim_reward_inspector_relic(selected_relic_reward_index))
			item.add_child(relic_button)
			item.add_child(_reward_inspector_skip_button(reward_index))
		_:
			item.add_child(_reward_inspector_skip_button(reward_index))

func _reward_inspector_skip_button(reward_index: int) -> Button:
	var button := Button.new()
	button.name = "RewardInspectorSkip_%s" % reward_index
	button.text = "Skip"
	var selected_reward_index := reward_index
	button.pressed.connect(func(): skip_reward_inspector_reward(selected_reward_index))
	return button
```

- [ ] **Step 6: Run tests to verify GREEN for Task 3**

Run the full test command.

Expected: `TESTS PASSED`.

- [ ] **Step 7: Task 3 review gates**

Stage 1:

- Reward Inspector is no longer a placeholder.
- Stable UI nodes exist.
- Character, node type, seed, reset, reward rows, claim, and skip controls exist.
- Claiming a reward stays on DevTools and leaves `current_run` null.

Stage 2:

- UI refresh does not duplicate reward application logic.
- Button callbacks are small and deterministic.
- Existing Card Browser, Enemy Sandbox, Event Tester, and RewardScreen behavior remains intact.

## Task 4: Documentation, Verification, and Acceptance

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-dev-tools-reward-inspector.md`

- [ ] **Step 1: Verify no Reward Inspector persistence, resource writes, progression, or routing were added**

Run:

```powershell
rtk proxy rg -n "save_run|delete_save|FileAccess.open|ResourceSaver|current_run\\s*=|router\\.go_to|RunProgression|SceneRouterScript\\.(REWARD|MAP|SUMMARY)" scripts/ui/dev_tools_screen.gd scripts/reward/reward_applier.gd
```

Expected: no matches that belong to Reward Inspector or `RewardApplier`.

- [ ] **Step 2: Run full local tests**

Run the full test command.

Expected: `TESTS PASSED`.

- [ ] **Step 3: Run Godot import check**

Run the import check command.

Expected: process exits 0.

- [ ] **Step 4: Update README progress**

Record Reward Inspector completion and update Next Plans to leave Save Inspector:

```markdown
- Developer tools reward inspector: complete; DevTools can now preview generated reward packages and simulate card, gold, relic, and skip choices against an isolated run without touching saves or the active run.

## Next Plans

1. Developer tools: save inspector.
2. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
3. Presentation expansion: more per-card cue ids, enemy intent polish, card art, richer combat backgrounds, and formal audio mixing.
```

- [ ] **Step 5: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [ ] **Step 6: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Reward Inspector is no longer a placeholder.
- Character, node type, and seed controls exist.
- Isolated run uses deterministic defaults.
- Rewards are generated through `RewardResolver`.
- Card, gold, relic, and skip actions update only `reward_inspector_run` and local reward states.
- Reset rebuilds the isolated run and reward package.
- `RewardScreen` uses shared `RewardApplier` claim logic.
- Reward Inspector does not mutate `current_run`, write saves, edit resources, advance map state, or route away from DevTools.

Stage 2 Code Quality Review:

- New helpers are typed.
- Reward application rules live in `RewardApplier`.
- Reward Inspector helpers are deterministic and testable.
- UI node names are stable.
- Normal Card Browser, Enemy Sandbox, Event Tester, and RewardScreen behavior remains unchanged.
- Classify any findings as Critical, Important, or Minor.

Fix any Critical or Important findings before acceptance.

## Final Acceptance Criteria

- Reward Inspector is reachable inside DevTools.
- Developers can choose a catalog character, node type, and seed.
- The isolated run summary updates from the selected character and seed.
- Developers can preview rewards generated by `RewardResolver`.
- Developers can simulate claiming card, gold, and relic rewards against the isolated run.
- Developers can skip any reward item.
- Resolved reward items are disabled until reset or config change.
- Reward Inspector never writes saves, edits resources, routes into normal flow, advances map state, or mutates an existing run.
- `RewardScreen` and Reward Inspector use shared reward application logic.
- Existing local tests pass.
- Godot import check exits 0.

