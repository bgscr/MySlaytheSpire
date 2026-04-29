# DevTools Event Tester Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the DevTools Event Tester entry into a real no-persistence tool for applying catalog event options against an isolated test run.

**Architecture:** `DevToolsScreen` owns the Event Tester state, creates a disposable `RunState`, and reuses `EventRunner` to check and apply options. The tester stays inside DevTools, never assigns `Game.current_run`, and never calls save or scene routing APIs.

**Tech Stack:** Godot 4.6.2-stable, GDScript, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Before editing code, verify `git branch --show-current` is `main`; stop if it is not.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`.
- Event Tester must not write saves, edit resources, route away from DevTools, or mutate an existing run.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-dev-tools-event-tester-design.md`

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

Modify:

- `scripts/ui/dev_tools_screen.gd`: Event Tester state helpers, isolated run creation, option application, and panel UI.
- `tests/unit/test_dev_tools_screen.gd`: Event Tester helper and isolated run coverage.
- `tests/smoke/test_scene_flow.gd`: DevTools Event Tester UI smoke coverage.
- `README.md`: record progress and update next plans after acceptance.
- `docs/superpowers/plans/2026-04-29-dev-tools-event-tester.md`: mark steps complete during execution.

## Task 1: Event Tester Isolated Run Helpers

**Files:**

- Modify: `tests/unit/test_dev_tools_screen.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [x] **Step 1: Verify branch and clean workspace**

Run:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
main
```

`git status --short` should show this spec and plan before implementation starts.

- [x] **Step 2: Add failing Event Tester unit tests**

Append these tests before helper functions in `tests/unit/test_dev_tools_screen.gd`:

```gdscript
func test_event_tester_exposes_deterministic_event_ids() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var event_ids: Array[String] = screen.event_tester_event_ids()
	var passed: bool = event_ids.size() == 12 \
		and event_ids[0] == "alchemist_market" \
		and event_ids.has("tea_house_rumor") \
		and event_ids.has("withered_master")
	screen.free()
	assert(passed)
	return passed

func test_event_tester_default_config_uses_sword_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var config: Dictionary = screen.event_tester_config()
	var run = screen.event_tester_run
	var passed: bool = config.get("event_id") == "alchemist_market" \
		and config.get("character_id") == "sword" \
		and config.get("seed_value") == 1 \
		and config.get("gold") == 50 \
		and config.get("deck_ids") == ["sword.strike", "sword.strike", "sword.strike"] \
		and run != null \
		and run.character_id == "sword" \
		and run.current_hp == 72 \
		and run.max_hp == 72 \
		and run.current_node_id == "event_tester_node"
	screen.free()
	assert(passed)
	return passed

func test_event_tester_option_text_includes_availability_and_effects() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_event_tester_event("tea_house_rumor")
	var reward_text := screen.event_tester_option_text(1)
	screen.set_event_tester_event("forgotten_armory")
	var grant_text := screen.event_tester_option_text(0)
	screen.set_event_tester_event("withered_master")
	var remove_text := screen.event_tester_option_text(0)
	var passed: bool = reward_text.contains("option: buy_rumor") \
		and reward_text.contains("available") \
		and reward_text.contains("min_gold=18") \
		and reward_text.contains("gold_delta=-18") \
		and reward_text.contains("card_reward_count=3") \
		and grant_text.contains("grant_cards=sword.flash_cut") \
		and remove_text.contains("remove_card=sword.strike")
	screen.free()
	assert(passed)
	return passed

func test_event_tester_apply_option_mutates_only_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var applied := screen.apply_event_tester_option(0)
	var summary := screen.event_tester_run_summary_text()
	var passed: bool = applied \
		and screen.event_tester_option_applied \
		and screen.event_tester_result_text == "Applied option: buy_brew" \
		and screen.event_tester_run.gold == 30 \
		and screen.event_tester_run.current_hp == 72 \
		and summary.contains("gold: 30") \
		and summary.contains("pending_rewards: none")
	screen.free()
	assert(passed)
	return passed

func test_event_tester_pending_reward_and_reset_are_visible() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_event_tester_event("tea_house_rumor")
	var applied := screen.apply_event_tester_option(1)
	var summary_after := screen.event_tester_run_summary_text()
	screen.reset_event_tester_run()
	var summary_reset := screen.event_tester_run_summary_text()
	var passed: bool = applied \
		and summary_after.contains("gold: 32") \
		and summary_after.contains("pending_rewards: 1") \
		and not screen.event_tester_option_applied \
		and screen.event_tester_result_text.is_empty() \
		and summary_reset.contains("gold: 50") \
		and summary_reset.contains("pending_rewards: none")
	screen.free()
	assert(passed)
	return passed
```

- [x] **Step 3: Run tests to verify RED**

Run the full test command. Expected: FAIL because Event Tester helpers do not exist.

- [x] **Step 4: Implement Event Tester helpers**

Update `scripts/ui/dev_tools_screen.gd`:

```gdscript
const EventDef := preload("res://scripts/data/event_def.gd")
const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const EventRunner := preload("res://scripts/event/event_runner.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
```

Add constants:

```gdscript
const TOOL_EVENT_TESTER := "event_tester"
const DEFAULT_EVENT_TESTER_CHARACTER := "sword"
const DEFAULT_EVENT_TESTER_GOLD := 50
const DEFAULT_EVENT_TESTER_SEED := 1
const EVENT_TESTER_NODE_ID := "event_tester_node"
```

Add state:

```gdscript
var selected_event_tester_event_id := ""
var selected_event_tester_character_id := DEFAULT_EVENT_TESTER_CHARACTER
var event_tester_run: RunState
var event_tester_option_applied := false
var event_tester_result_text := ""
```

Implement these public helpers:

```gdscript
func event_tester_event_ids() -> Array[String]:
	var result: Array[String] = []
	for event_id in catalog.events_by_id.keys():
		result.append(String(event_id))
	result.sort()
	return result

func set_event_tester_event(event_id: String) -> void:
	if catalog.get_event(event_id) == null:
		return
	selected_event_tester_event_id = event_id
	reset_event_tester_run()
	_refresh_event_tester_if_ready()

func set_event_tester_character(character_id: String) -> void:
	if catalog.get_character(character_id) == null:
		return
	selected_event_tester_character_id = character_id
	reset_event_tester_run()
	_refresh_event_tester_if_ready()

func reset_event_tester_run() -> void:
	_ensure_event_tester_defaults()
	event_tester_run = _create_event_tester_run()
	event_tester_option_applied = false
	event_tester_result_text = ""

func event_tester_config() -> Dictionary:
	_ensure_event_tester_defaults()
	if event_tester_run == null:
		event_tester_run = _create_event_tester_run()
	return {
		"event_id": selected_event_tester_event_id,
		"character_id": selected_event_tester_character_id,
		"seed_value": event_tester_run.seed_value,
		"gold": event_tester_run.gold,
		"deck_ids": event_tester_run.deck_ids.duplicate(),
	}

func event_tester_run_summary_text() -> String:
	if event_tester_run == null:
		reset_event_tester_run()
	var pending_rewards: Array = event_tester_run.current_reward_state.get("rewards", [])
	return "\n".join([
		"event: %s" % selected_event_tester_event_id,
		"character: %s" % event_tester_run.character_id,
		"hp: %s/%s" % [event_tester_run.current_hp, event_tester_run.max_hp],
		"gold: %s" % event_tester_run.gold,
		"deck: %s" % _join_string_array(event_tester_run.deck_ids),
		"relics: %s" % _join_string_array(event_tester_run.relic_ids),
		"pending_rewards: %s" % ("none" if pending_rewards.is_empty() else str(pending_rewards.size())),
	])

func event_tester_option_text(index: int) -> String:
	var event := catalog.get_event(selected_event_tester_event_id)
	if event == null or index < 0 or index >= event.options.size():
		return "option: unavailable"
	if event_tester_run == null:
		reset_event_tester_run()
	var option: EventOptionDef = event.options[index]
	var runner := EventRunner.new()
	var available := runner.is_option_available(event_tester_run, option)
	var lines: Array[String] = [
		"option: %s" % option.id,
		"state: %s" % ("available" if available else "blocked"),
	]
	var reason := runner.unavailable_reason(event_tester_run, option)
	if not reason.is_empty():
		lines.append("reason=%s" % reason)
	if option.min_hp > 0:
		lines.append("min_hp=%s" % option.min_hp)
	if option.min_gold > 0:
		lines.append("min_gold=%s" % option.min_gold)
	if option.hp_delta != 0:
		lines.append("hp_delta=%s" % option.hp_delta)
	if option.gold_delta != 0:
		lines.append("gold_delta=%s" % option.gold_delta)
	if not option.remove_card_id.is_empty():
		lines.append("remove_card=%s" % option.remove_card_id)
	if not option.grant_card_ids.is_empty():
		lines.append("grant_cards=%s" % _join_string_array(option.grant_card_ids))
	if not option.grant_relic_ids.is_empty():
		lines.append("grant_relics=%s" % _join_string_array(option.grant_relic_ids))
	if option.card_reward_count > 0:
		lines.append("card_reward_count=%s" % option.card_reward_count)
	if not option.relic_reward_tier.is_empty():
		lines.append("relic_reward_tier=%s" % option.relic_reward_tier)
	return " | ".join(lines)

func apply_event_tester_option(index: int) -> bool:
	var event := catalog.get_event(selected_event_tester_event_id)
	if event == null or event_tester_run == null or event_tester_option_applied:
		return false
	if index < 0 or index >= event.options.size():
		return false
	var option: EventOptionDef = event.options[index]
	var applied := EventRunner.new().apply_event_option(catalog, event_tester_run, event, option)
	if applied:
		event_tester_option_applied = true
		event_tester_result_text = "Applied option: %s" % option.id
	else:
		event_tester_result_text = "Option failed: %s" % option.id
	_refresh_event_tester_if_ready()
	return applied
```

Add private helpers:

```gdscript
func _ensure_event_tester_defaults() -> void:
	if catalog.get_event(selected_event_tester_event_id) == null:
		var event_ids := event_tester_event_ids()
		selected_event_tester_event_id = event_ids[0] if not event_ids.is_empty() else ""
	if catalog.get_character(selected_event_tester_character_id) == null:
		var character_ids := _dev_tools_character_ids(DEFAULT_EVENT_TESTER_CHARACTER)
		selected_event_tester_character_id = character_ids[0] if not character_ids.is_empty() else ""

func _create_event_tester_run() -> RunState:
	var run := RunState.new()
	var character := catalog.get_character(selected_event_tester_character_id)
	run.seed_value = DEFAULT_EVENT_TESTER_SEED
	run.character_id = selected_event_tester_character_id
	run.gold = DEFAULT_EVENT_TESTER_GOLD
	run.current_node_id = EVENT_TESTER_NODE_ID
	run.map_nodes = [MapNodeState.new(EVENT_TESTER_NODE_ID, 0, "event")]
	if character != null:
		run.max_hp = character.max_hp
		run.current_hp = character.max_hp
		run.deck_ids = _copy_string_array(character.starting_deck_ids)
	return run

func _dev_tools_character_ids(preferred_id: String) -> Array[String]:
	var result: Array[String] = []
	for character_id in catalog.characters_by_id.keys():
		result.append(String(character_id))
	result.sort()
	if result.has(preferred_id):
		result.erase(preferred_id)
		result.push_front(preferred_id)
	return result

func _refresh_event_tester_if_ready() -> void:
	pass
```

Call `_ensure_event_tester_defaults()` and `reset_event_tester_run()` from `_ready()` and `load_default_catalog()` after catalog loading.

- [x] **Step 5: Run tests to verify GREEN for Task 1**

Run the full test command. Expected: `TESTS PASSED`.

- [x] **Step 6: Task 1 review gates**

Stage 1:

- Event Tester helper methods exist.
- Event ids are deterministic.
- Isolated run defaults match the spec.
- Option text includes requirements, deltas, grants, removals, and rewards.
- Apply and reset mutate only `event_tester_run`.

Stage 2:

- Helpers are typed and deterministic.
- Event option gameplay logic remains in `EventRunner`.
- Empty catalog fallback paths avoid crashes.

## Task 2: Event Tester Panel UI

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [x] **Step 1: Add failing Event Tester smoke tests**

Replace `test_dev_tools_deferred_event_tester_button_shows_planned_placeholder()` in `tests/smoke/test_scene_flow.gd` with:

```gdscript
func test_dev_tools_event_tester_button_shows_panel(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_event_tester") as Button
	if button != null:
		button.pressed.emit()
	var panel := _find_node_by_name(screen, "EventTesterPanel")
	var summary := _find_node_by_name(screen, "EventTesterRunSummaryLabel") as Label
	var option := _find_node_by_name(screen, "EventTesterOption_0") as Button
	var reset := _find_node_by_name(screen, "EventTesterResetButton") as Button
	var passed: bool = button != null \
		and screen.active_tool_id == "event_tester" \
		and panel != null \
		and summary != null \
		and summary.text.contains("event: alchemist_market") \
		and option != null \
		and reset != null
	screen.free()
	return passed
```

Append this smoke test near the other DevTools tests:

```gdscript
func test_dev_tools_event_tester_apply_option_stays_in_dev_tools_without_current_run(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_event_tester_apply_save.json")
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var event_tester_button := _find_node_by_name(dev_tools, "ToolButton_event_tester") as Button
	if event_tester_button != null:
		event_tester_button.pressed.emit()
	var option_button := _find_node_by_name(dev_tools, "EventTesterOption_0") as Button
	if option_button != null:
		option_button.pressed.emit()
	var result := _find_node_by_name(dev_tools, "EventTesterResultLabel") as Label
	var summary := _find_node_by_name(dev_tools, "EventTesterRunSummaryLabel") as Label
	var passed: bool = option_button != null \
		and result != null \
		and result.text.contains("Applied option: buy_brew") \
		and summary != null \
		and summary.text.contains("gold: 30") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save("user://test_event_tester_apply_save.json")
	return passed
```

- [x] **Step 2: Run tests to verify RED**

Run the full test command. Expected: FAIL because Event Tester panel nodes do not exist.

- [x] **Step 3: Implement Event Tester panel**

Add UI vars to `scripts/ui/dev_tools_screen.gd`:

```gdscript
var event_tester_event_select: OptionButton
var event_tester_character_select: OptionButton
var event_tester_run_summary_label: Label
var event_tester_option_list: VBoxContainer
var event_tester_result_label: Label
```

Update `_show_tool()` to call `_build_event_tester()` for `TOOL_EVENT_TESTER`.

Add panel methods:

```gdscript
func _build_event_tester() -> void:
	_ensure_event_tester_defaults()
	if event_tester_run == null:
		reset_event_tester_run()
	var panel := VBoxContainer.new()
	panel.name = "EventTesterPanel"
	tool_content.add_child(panel)

	event_tester_event_select = OptionButton.new()
	event_tester_event_select.name = "EventTesterEventSelect"
	for event_id in event_tester_event_ids():
		event_tester_event_select.add_item(event_id)
		if event_id == selected_event_tester_event_id:
			event_tester_event_select.select(event_tester_event_select.get_item_count() - 1)
	event_tester_event_select.item_selected.connect(_on_event_tester_event_selected)
	panel.add_child(event_tester_event_select)

	event_tester_character_select = OptionButton.new()
	event_tester_character_select.name = "EventTesterCharacterSelect"
	for character_id in _dev_tools_character_ids(DEFAULT_EVENT_TESTER_CHARACTER):
		event_tester_character_select.add_item(character_id)
		if character_id == selected_event_tester_character_id:
			event_tester_character_select.select(event_tester_character_select.get_item_count() - 1)
	event_tester_character_select.item_selected.connect(_on_event_tester_character_selected)
	panel.add_child(event_tester_character_select)

	event_tester_run_summary_label = Label.new()
	event_tester_run_summary_label.name = "EventTesterRunSummaryLabel"
	event_tester_run_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(event_tester_run_summary_label)

	event_tester_option_list = VBoxContainer.new()
	event_tester_option_list.name = "EventTesterOptionList"
	panel.add_child(event_tester_option_list)

	event_tester_result_label = Label.new()
	event_tester_result_label.name = "EventTesterResultLabel"
	panel.add_child(event_tester_result_label)

	var reset := Button.new()
	reset.name = "EventTesterResetButton"
	reset.text = "Reset Test Run"
	reset.pressed.connect(_on_event_tester_reset_pressed)
	panel.add_child(reset)

	_refresh_event_tester_panel()

func _on_event_tester_event_selected(index: int) -> void:
	if event_tester_event_select == null:
		return
	set_event_tester_event(event_tester_event_select.get_item_text(index))

func _on_event_tester_character_selected(index: int) -> void:
	if event_tester_character_select == null:
		return
	set_event_tester_character(event_tester_character_select.get_item_text(index))

func _on_event_tester_reset_pressed() -> void:
	reset_event_tester_run()
	_refresh_event_tester_panel()

func _refresh_event_tester_if_ready() -> void:
	if event_tester_option_list != null and event_tester_run_summary_label != null:
		_refresh_event_tester_panel()

func _refresh_event_tester_panel() -> void:
	if event_tester_run == null:
		reset_event_tester_run()
	if event_tester_run_summary_label != null:
		event_tester_run_summary_label.text = event_tester_run_summary_text()
	if event_tester_result_label != null:
		event_tester_result_label.text = event_tester_result_text
	if event_tester_option_list == null:
		return
	_clear_children(event_tester_option_list)
	var event := catalog.get_event(selected_event_tester_event_id)
	if event == null:
		var empty := Label.new()
		empty.name = "EventTesterNoEventLabel"
		empty.text = "No event available"
		event_tester_option_list.add_child(empty)
		return
	for i in range(event.options.size()):
		var button := Button.new()
		button.name = "EventTesterOption_%s" % i
		button.text = event_tester_option_text(i)
		button.disabled = event_tester_option_applied or not EventRunner.new().is_option_available(event_tester_run, event.options[i])
		var option_index := i
		button.pressed.connect(func(): apply_event_tester_option(option_index))
		event_tester_option_list.add_child(button)
```

- [x] **Step 4: Run tests to verify GREEN for Task 2**

Run the full test command. Expected: `TESTS PASSED`.

- [x] **Step 5: Task 2 review gates**

Stage 1:

- Event Tester is no longer a placeholder.
- Stable UI nodes exist.
- Applying an option stays on DevTools.
- `current_run` remains null.

Stage 2:

- UI refresh does not duplicate gameplay logic.
- Existing Card Browser and Enemy Sandbox behavior remains intact.
- Button callbacks are small and deterministic.

## Task 3: Documentation, Verification, and Acceptance

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-dev-tools-event-tester.md`

- [x] **Step 1: Verify no persistence/resource/routing writes were added**

Run:

```powershell
rtk proxy rg -n "save_run|delete_save|FileAccess.open|ResourceSaver|current_run\\s*=|router\\.go_to|SceneRouterScript\\.(EVENT|REWARD|MAP|SUMMARY)" scripts/ui/dev_tools_screen.gd
```

Expected: no Event Tester save, resource write, current run assignment, or normal flow route.

- [x] **Step 2: Run full local tests**

Run the full test command. Expected: `TESTS PASSED`.

- [x] **Step 3: Run Godot import check**

Run the import check command. Expected: process exits 0.

- [x] **Step 4: Update README progress**

Record Event Tester completion and update Next Plans to leave Reward Inspector and Save Inspector:

```markdown
- Developer tools event tester: complete; DevTools can now apply catalog event options against an isolated test run without writing saves, routing away, or mutating the active run.

## Next Plans

1. Developer tools: reward inspector and save inspector.
2. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
3. Presentation expansion: more per-card cue ids, enemy intent polish, card art, richer combat backgrounds, and formal audio mixing.
```

- [x] **Step 5: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [x] **Step 6: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Event Tester is no longer a placeholder.
- Event and character selections exist.
- Isolated run uses deterministic defaults.
- Option summaries include availability, requirements, deltas, grants, removals, and generated reward configuration.
- Applying an option uses `EventRunner.apply_event_option()`.
- Applying an option does not mutate `current_run`, write saves, edit resources, or route away from DevTools.
- Reset rebuilds the isolated run.

Stage 2 Code Quality Review:

- New helpers are typed.
- Event Tester helpers are deterministic and testable.
- UI node names are stable.
- Normal Card Browser and Enemy Sandbox behavior remains unchanged.
- Event option gameplay logic is not duplicated outside `EventRunner`.
- Classify any findings as Critical, Important, or Minor.

Fix any Critical or Important findings before acceptance.

## Final Acceptance Criteria

- Event Tester is reachable inside DevTools.
- Developers can choose a catalog event and character.
- The isolated run summary updates from the selected character.
- Developers can apply an available event option to the isolated run.
- Applied option results, including pending rewards, are visible in DevTools.
- Event Tester never writes saves, edits resources, routes into normal flow, or mutates an existing run.
- Existing local tests pass.
- Godot import check exits 0.
