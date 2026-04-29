# DevTools Save Inspector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a future-ready read-only Save Inspector in DevTools that diagnoses save state and predicts Main Menu Continue routing without mutating saves or active run state.

**Architecture:** `DevToolsScreen` owns the Save Inspector panel and converts the configured `SaveService` into a read-only snapshot dictionary. Unit-testable helpers classify save status and resume target, while UI code only renders those helpers and exposes disabled future action slots.

**Tech Stack:** Godot 4.6.2-stable, GDScript, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Before editing code, verify `git branch --show-current` is `main`; stop if it is not.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`.
- Save Inspector must not write saves, delete saves, repair saves, route away from DevTools, assign `Game.current_run`, or mutate a loaded run.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-dev-tools-save-inspector-design.md`

## Verification Commands

Run full tests:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

The existing `test_malformed_status_intent_advances_without_mutation` test emits a Godot `ERROR` log intentionally. Treat the process exit code and `TESTS PASSED` line as the test result.

Run import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Modify:

- `scripts/ui/dev_tools_screen.gd`: Save Inspector constants, state, snapshot helpers, resume prediction, read-only panel UI, reload refresh, and future disabled action slots.
- `tests/unit/test_dev_tools_screen.gd`: Save Inspector snapshot and text helper coverage.
- `tests/smoke/test_scene_flow.gd`: Save Inspector UI, reload, routing, current-run, and no-delete smoke coverage.
- `README.md`: record Save Inspector completion and update Next Plans after acceptance.
- `docs/superpowers/plans/2026-04-29-dev-tools-save-inspector.md`: mark steps complete during execution.

Do not create a new runtime script in this pass. If resume classification grows later, extract it into a shared helper in a separate plan.

## Task 1: Save Inspector Snapshot Helpers

**Files:**

- Modify: `tests/unit/test_dev_tools_screen.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [ ] **Step 1: Verify branch and working tree**

Run:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
main
```

`git status --short` may show this plan file while it is being executed. Stop and ask the user if the branch is not `main`.

- [ ] **Step 2: Add failing Save Inspector unit tests**

In `tests/unit/test_dev_tools_screen.gd`, add these preloads near the existing constants:

```gdscript
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const SaveService := preload("res://scripts/save/save_service.gd")
```

Append these tests before helper functions:

```gdscript
func test_save_inspector_reports_missing_service_without_tree_app() -> bool:
	var screen := DevToolsScreen.new()
	var snapshot: Dictionary = screen.save_inspector_snapshot()
	var passed: bool = snapshot.get("has_service") == false \
		and snapshot.get("has_save") == false \
		and snapshot.get("status") == "missing_service" \
		and snapshot.get("resume_target") == "none" \
		and screen.save_inspector_status_text().contains("status: missing_service")
	screen.free()
	assert(passed)
	return passed

func test_save_inspector_reports_no_save() -> bool:
	var save_path := "user://test_dev_tools_save_inspector_no_save.json"
	_delete_test_save(save_path)
	var screen := DevToolsScreen.new()
	screen.set_save_inspector_save_service_override(SaveService.new(save_path))
	var snapshot: Dictionary = screen.save_inspector_snapshot()
	var passed: bool = snapshot.get("has_service") == true \
		and snapshot.get("has_save") == false \
		and snapshot.get("status") == "no_save" \
		and snapshot.get("resume_target") == "none" \
		and screen.save_inspector_summary_text().contains("run: none")
	screen.free()
	_delete_test_save(save_path)
	assert(passed)
	return passed

func test_save_inspector_reports_invalid_save_without_deleting() -> bool:
	var save_path := "user://test_dev_tools_save_inspector_invalid.json"
	_delete_test_save(save_path)
	_write_test_save(save_path, "{")
	var service := SaveService.new(save_path)
	var screen := DevToolsScreen.new()
	screen.set_save_inspector_save_service_override(service)
	var snapshot: Dictionary = screen.save_inspector_snapshot()
	var passed: bool = snapshot.get("status") == "invalid" \
		and snapshot.get("resume_target") == "invalid_delete_on_continue" \
		and service.has_save() \
		and screen.save_inspector_status_text().contains("has_save: true")
	screen.free()
	_delete_test_save(save_path)
	assert(passed)
	return passed

func test_save_inspector_reports_terminal_save_without_deleting() -> bool:
	var save_path := "user://test_dev_tools_save_inspector_terminal.json"
	_delete_test_save(save_path)
	var run := _save_inspector_run("combat")
	run.completed = true
	var service := SaveService.new(save_path)
	service.save_run(run)
	var screen := DevToolsScreen.new()
	screen.set_save_inspector_save_service_override(service)
	var snapshot: Dictionary = screen.save_inspector_snapshot()
	var passed: bool = snapshot.get("status") == "terminal" \
		and snapshot.get("resume_target") == "terminal_delete_on_continue" \
		and service.has_save() \
		and screen.save_inspector_summary_text().contains("completed: true")
	screen.free()
	_delete_test_save(save_path)
	assert(passed)
	return passed

func test_save_inspector_predicts_map_resume_for_active_run() -> bool:
	var save_path := "user://test_dev_tools_save_inspector_map.json"
	_delete_test_save(save_path)
	var service := SaveService.new(save_path)
	service.save_run(_save_inspector_run("combat"))
	var screen := DevToolsScreen.new()
	screen.set_save_inspector_save_service_override(service)
	var snapshot: Dictionary = screen.save_inspector_snapshot()
	var passed: bool = snapshot.get("status") == "active" \
		and snapshot.get("resume_target") == "map" \
		and screen.save_inspector_resume_target() == "map" \
		and screen.save_inspector_summary_text().contains("current_node_type: combat") \
		and screen.save_inspector_map_text().contains("visited_count: 0") \
		and screen.save_inspector_map_text().contains("unlocked_count: 1")
	screen.free()
	_delete_test_save(save_path)
	assert(passed)
	return passed

func test_save_inspector_predicts_shop_resume_for_matching_shop_state() -> bool:
	var save_path := "user://test_dev_tools_save_inspector_shop.json"
	_delete_test_save(save_path)
	var run := _save_inspector_run("shop")
	run.current_shop_state = {
		"node_id": "node_0",
		"offers": [
			{"id": "card_0", "type": "card", "sold": true},
			{"id": "relic_0", "type": "relic", "sold": false},
		],
	}
	var service := SaveService.new(save_path)
	service.save_run(run)
	var screen := DevToolsScreen.new()
	screen.set_save_inspector_save_service_override(service)
	var passed: bool = screen.save_inspector_snapshot().get("resume_target") == "shop" \
		and screen.save_inspector_shop_text().contains("shop_state: matching") \
		and screen.save_inspector_shop_text().contains("offers: 2") \
		and screen.save_inspector_shop_text().contains("sold: 1")
	screen.free()
	_delete_test_save(save_path)
	assert(passed)
	return passed

func test_save_inspector_predicts_reward_resume_for_matching_event_reward() -> bool:
	var save_path := "user://test_dev_tools_save_inspector_reward.json"
	_delete_test_save(save_path)
	var run := _save_inspector_run("event")
	run.current_reward_state = {
		"source": "event",
		"node_id": "node_0",
		"event_id": "forgotten_armory",
		"option_id": "train",
		"rewards": [
			{
				"id": "event-card:node_0:train",
				"type": "card_choice",
				"card_ids": ["sword.flash_cut", "sword.guard"],
			},
		],
	}
	var service := SaveService.new(save_path)
	service.save_run(run)
	var screen := DevToolsScreen.new()
	screen.set_save_inspector_save_service_override(service)
	var passed: bool = screen.save_inspector_snapshot().get("resume_target") == "reward" \
		and screen.save_inspector_reward_text().contains("reward_state: matching") \
		and screen.save_inspector_reward_text().contains("source: event") \
		and screen.save_inspector_reward_text().contains("rewards: 1")
	screen.free()
	_delete_test_save(save_path)
	assert(passed)
	return passed
```

Add these helper functions at the bottom of `tests/unit/test_dev_tools_screen.gd`:

```gdscript
func _save_inspector_run(node_type: String) -> RunState:
	var run := RunState.new()
	run.version = 1
	run.seed_value = 12345
	run.character_id = "sword"
	run.current_hp = 55
	run.max_hp = 72
	run.gold = 99
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	run.relic_ids = ["jade_talisman"]
	run.current_node_id = "node_0"
	var current := MapNodeState.new("node_0", 0, node_type)
	current.unlocked = true
	run.map_nodes = [current, MapNodeState.new("node_1", 1, "combat")]
	return run

func _delete_test_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_test_save(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true
```

- [ ] **Step 3: Run tests to verify RED**

Run the full test command.

Expected: FAIL because `set_save_inspector_save_service_override()`, `save_inspector_snapshot()`, and the Save Inspector text helpers do not exist.

- [ ] **Step 4: Add Save Inspector constants and state**

In `scripts/ui/dev_tools_screen.gd`, add this preload near the existing preloads:

```gdscript
const SaveService := preload("res://scripts/save/save_service.gd")
```

Add these constants near the tool constants:

```gdscript
const TOOL_SAVE_INSPECTOR := "save_inspector"
const SAVE_STATUS_MISSING_SERVICE := "missing_service"
const SAVE_STATUS_NO_SAVE := "no_save"
const SAVE_STATUS_INVALID := "invalid"
const SAVE_STATUS_TERMINAL := "terminal"
const SAVE_STATUS_ACTIVE := "active"
const SAVE_RESUME_NONE := "none"
const SAVE_RESUME_INVALID_DELETE_ON_CONTINUE := "invalid_delete_on_continue"
const SAVE_RESUME_TERMINAL_DELETE_ON_CONTINUE := "terminal_delete_on_continue"
const SAVE_RESUME_REWARD := "reward"
const SAVE_RESUME_SHOP := "shop"
const SAVE_RESUME_MAP := "map"
```

Add this state near the other DevTools state vars:

```gdscript
var save_inspector_save_service_override: Variant
var save_inspector_current_snapshot: Dictionary = {}
var save_inspector_status_label: Label
var save_inspector_resume_target_label: Label
var save_inspector_run_summary_label: Label
var save_inspector_state_sections: VBoxContainer
var save_inspector_map_section_label: Label
var save_inspector_shop_section_label: Label
var save_inspector_reward_section_label: Label
```

Update `_show_tool()` to use the new constant:

```gdscript
	elif tool_id == TOOL_SAVE_INSPECTOR:
		_build_save_inspector()
```

Update `tool_ids()` to keep the same public id while using the constant:

```gdscript
func tool_ids() -> Array[String]:
	return [
		TOOL_CARD_BROWSER,
		TOOL_ENEMY_SANDBOX,
		TOOL_EVENT_TESTER,
		TOOL_REWARD_INSPECTOR,
		TOOL_SAVE_INSPECTOR,
	]
```

- [ ] **Step 5: Implement public Save Inspector helper API**

Add these methods near the other public DevTools helper methods:

```gdscript
func set_save_inspector_save_service_override(service: Variant) -> void:
	save_inspector_save_service_override = service
	refresh_save_inspector()

func refresh_save_inspector() -> void:
	save_inspector_current_snapshot = _build_save_inspector_snapshot()
	_refresh_save_inspector_if_ready()

func save_inspector_snapshot() -> Dictionary:
	if save_inspector_current_snapshot.is_empty():
		save_inspector_current_snapshot = _build_save_inspector_snapshot()
	return save_inspector_current_snapshot

func save_inspector_resume_target() -> String:
	return String(save_inspector_snapshot().get("resume_target", SAVE_RESUME_NONE))

func save_inspector_status_text() -> String:
	var snapshot := save_inspector_snapshot()
	return "\n".join([
		"status: %s" % String(snapshot.get("status", SAVE_STATUS_MISSING_SERVICE)),
		"has_service: %s" % _bool_text(bool(snapshot.get("has_service", false))),
		"has_save: %s" % _bool_text(bool(snapshot.get("has_save", false))),
		"reason: %s" % String(snapshot.get("reason", "")),
	])

func save_inspector_summary_text() -> String:
	var snapshot := save_inspector_snapshot()
	var run: RunState = snapshot.get("run", null)
	if run == null:
		return "run: none"
	return "\n".join([
		"version: %s" % run.version,
		"seed: %s" % run.seed_value,
		"character: %s" % run.character_id,
		"hp: %s/%s" % [run.current_hp, run.max_hp],
		"gold: %s" % run.gold,
		"deck_count: %s" % run.deck_ids.size(),
		"relic_count: %s" % run.relic_ids.size(),
		"current_node_id: %s" % run.current_node_id,
		"current_node_type: %s" % _save_inspector_current_node_type(run),
		"completed: %s" % _bool_text(run.completed),
		"failed: %s" % _bool_text(run.failed),
	])

func save_inspector_map_text() -> String:
	var run: RunState = save_inspector_snapshot().get("run", null)
	if run == null:
		return "map: none"
	var visited_count := 0
	var unlocked_count := 0
	for node in run.map_nodes:
		if node.visited:
			visited_count += 1
		if node.unlocked:
			unlocked_count += 1
	return "\n".join([
		"map_nodes: %s" % run.map_nodes.size(),
		"current_node_id: %s" % run.current_node_id,
		"current_node_type: %s" % _save_inspector_current_node_type(run),
		"visited_count: %s" % visited_count,
		"unlocked_count: %s" % unlocked_count,
	])

func save_inspector_shop_text() -> String:
	var run: RunState = save_inspector_snapshot().get("run", null)
	if run == null:
		return "shop_state: none"
	if run.current_shop_state.is_empty():
		return "shop_state: empty"
	var offers: Array = run.current_shop_state.get("offers", [])
	var sold_count := 0
	for offer in offers:
		if not offer is Dictionary:
			continue
		var payload: Dictionary = offer
		if bool(payload.get("sold", false)):
			sold_count += 1
	var matching := _save_inspector_shop_state_matches(run)
	return "\n".join([
		"shop_state: %s" % ("matching" if matching else "mismatched"),
		"node_id: %s" % String(run.current_shop_state.get("node_id", "")),
		"offers: %s" % offers.size(),
		"sold: %s" % sold_count,
	])

func save_inspector_reward_text() -> String:
	var run: RunState = save_inspector_snapshot().get("run", null)
	if run == null:
		return "reward_state: none"
	if run.current_reward_state.is_empty():
		return "reward_state: empty"
	var rewards: Array = run.current_reward_state.get("rewards", [])
	var matching := _save_inspector_reward_state_matches(run)
	return "\n".join([
		"reward_state: %s" % ("matching" if matching else "mismatched"),
		"source: %s" % String(run.current_reward_state.get("source", "")),
		"node_id: %s" % String(run.current_reward_state.get("node_id", "")),
		"event_id: %s" % String(run.current_reward_state.get("event_id", "")),
		"option_id: %s" % String(run.current_reward_state.get("option_id", "")),
		"rewards: %s" % rewards.size(),
	])
```

- [ ] **Step 6: Implement private Save Inspector snapshot helpers**

Add these methods near the other private DevTools helpers:

```gdscript
func _build_save_inspector_snapshot() -> Dictionary:
	var service: Variant = _save_inspector_save_service()
	var snapshot := {
		"has_service": service != null,
		"has_save": false,
		"status": SAVE_STATUS_MISSING_SERVICE,
		"resume_target": SAVE_RESUME_NONE,
		"reason": "save_service: missing",
		"run": null,
	}
	if service == null:
		return snapshot
	if not service.has_method("has_save") or not service.has_method("load_run"):
		return snapshot
	snapshot["has_save"] = service.has_save()
	if not bool(snapshot["has_save"]):
		snapshot["status"] = SAVE_STATUS_NO_SAVE
		snapshot["reason"] = "save_file: missing"
		return snapshot
	var loaded_run: RunState = service.load_run()
	if loaded_run == null:
		snapshot["status"] = SAVE_STATUS_INVALID
		snapshot["resume_target"] = SAVE_RESUME_INVALID_DELETE_ON_CONTINUE
		snapshot["reason"] = "load_run: invalid"
		return snapshot
	snapshot["run"] = loaded_run
	if loaded_run.failed or loaded_run.completed:
		snapshot["status"] = SAVE_STATUS_TERMINAL
		snapshot["resume_target"] = SAVE_RESUME_TERMINAL_DELETE_ON_CONTINUE
		snapshot["reason"] = "run: terminal"
		return snapshot
	var resume_target := _save_inspector_resume_target_for_run(loaded_run)
	snapshot["status"] = SAVE_STATUS_ACTIVE
	snapshot["resume_target"] = resume_target
	snapshot["reason"] = "continue_target: %s" % resume_target
	return snapshot

func _save_inspector_save_service() -> Variant:
	if save_inspector_save_service_override != null:
		return save_inspector_save_service_override
	var app := _get_app()
	if app == null or app.get("game") == null:
		return null
	return app.game.save_service

func _save_inspector_resume_target_for_run(run: RunState) -> String:
	if _save_inspector_reward_state_matches(run):
		return SAVE_RESUME_REWARD
	if _save_inspector_shop_state_matches(run):
		return SAVE_RESUME_SHOP
	return SAVE_RESUME_MAP

func _save_inspector_reward_state_matches(run: RunState) -> bool:
	if run == null or run.current_reward_state.is_empty():
		return false
	if String(run.current_reward_state.get("source", "")) != "event":
		return false
	if String(run.current_reward_state.get("node_id", "")) != run.current_node_id:
		return false
	return _save_inspector_current_node_type(run) == "event"

func _save_inspector_shop_state_matches(run: RunState) -> bool:
	if run == null or run.current_shop_state.is_empty():
		return false
	if String(run.current_shop_state.get("node_id", "")) != run.current_node_id:
		return false
	return _save_inspector_current_node_type(run) == "shop"

func _save_inspector_current_node_type(run: RunState) -> String:
	if run == null:
		return "none"
	for node in run.map_nodes:
		if node.id == run.current_node_id:
			return node.node_type
	return "missing"

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
```

Update `_get_app()` so unit tests on an unparented `DevToolsScreen` cannot crash:

```gdscript
func _get_app() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("App")
```

- [ ] **Step 7: Run tests to verify GREEN for Task 1**

Run the full test command.

Expected: `TESTS PASSED`.

- [ ] **Step 8: Task 1 review gates**

Stage 1:

- Save Inspector snapshot helpers exist.
- Missing service, no save, invalid, terminal, map, shop, and reward states are classified.
- Invalid and terminal saves are not deleted.
- Resume prediction matches Main Menu rules.

Stage 2:

- Helpers are typed and deterministic.
- Loaded `RunState` is read-only.
- Save service override is isolated to DevTools tests and does not affect runtime behavior.
- No save writes, deletes, routing, or current-run assignments were added.

## Task 2: Save Inspector Panel UI

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [ ] **Step 1: Add failing Save Inspector smoke tests**

In `tests/smoke/test_scene_flow.gd`, append these tests near the other DevTools tests:

```gdscript
func test_dev_tools_save_inspector_button_shows_read_only_panel(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var panel := _find_node_by_name(screen, "SaveInspectorPanel")
	var status := _find_node_by_name(screen, "SaveInspectorStatusLabel") as Label
	var target := _find_node_by_name(screen, "SaveInspectorResumeTargetLabel") as Label
	var reload := _find_node_by_name(screen, "SaveInspectorReloadButton") as Button
	var delete_button := _find_node_by_name(screen, "SaveInspectorDeleteButton") as Button
	var export_button := _find_node_by_name(screen, "SaveInspectorExportButton") as Button
	var copy_button := _find_node_by_name(screen, "SaveInspectorCopyJsonButton") as Button
	var repair_button := _find_node_by_name(screen, "SaveInspectorRepairButton") as Button
	var passed: bool = button != null \
		and screen.active_tool_id == "save_inspector" \
		and panel != null \
		and status != null \
		and status.text.contains("status: missing_service") \
		and target != null \
		and target.text.contains("continue_target: none") \
		and reload != null \
		and not reload.disabled \
		and delete_button != null \
		and delete_button.disabled \
		and export_button != null \
		and export_button.disabled \
		and copy_button != null \
		and copy_button.disabled \
		and repair_button != null \
		and repair_button.disabled
	screen.free()
	return passed

func test_dev_tools_save_inspector_displays_saved_run_and_stays_in_dev_tools(tree: SceneTree) -> bool:
	var save_path := "user://test_save_inspector_panel_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("combat", true)
	app.game.save_service.save_run(run)
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var button := _find_node_by_name(dev_tools, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var status := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var target := _find_node_by_name(dev_tools, "SaveInspectorResumeTargetLabel") as Label
	var summary := _find_node_by_name(dev_tools, "SaveInspectorRunSummaryLabel") as Label
	var map_section := _find_node_by_name(dev_tools, "SaveInspectorMapSectionLabel") as Label
	var passed: bool = status != null \
		and status.text.contains("status: active") \
		and target != null \
		and target.text.contains("continue_target: map") \
		and summary != null \
		and summary.text.contains("character: sword") \
		and summary.text.contains("current_node_type: combat") \
		and map_section != null \
		and map_section.text.contains("map_nodes: 2") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save(save_path)
	return passed

func test_dev_tools_save_inspector_reload_refreshes_without_routing_or_current_run(tree: SceneTree) -> bool:
	var save_path := "user://test_save_inspector_reload_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var button := _find_node_by_name(dev_tools, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var status_before := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var before_text := status_before.text if status_before != null else ""
	app.game.save_service.save_run(_reward_run("shop", true))
	var reload := _find_node_by_name(dev_tools, "SaveInspectorReloadButton") as Button
	if reload != null:
		reload.pressed.emit()
	var status_after := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var target_after := _find_node_by_name(dev_tools, "SaveInspectorResumeTargetLabel") as Label
	var passed: bool = before_text.contains("status: no_save") \
		and reload != null \
		and status_after != null \
		and status_after.text.contains("status: active") \
		and target_after != null \
		and target_after.text.contains("continue_target: map") \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save(save_path)
	return passed

func test_dev_tools_save_inspector_does_not_delete_invalid_save(tree: SceneTree) -> bool:
	var save_path := "user://test_save_inspector_invalid_kept.json"
	var app = _create_app_with_save_service(tree, save_path)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		app.free()
		return false
	file.store_string("{")
	file.close()
	var dev_tools = app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
	var button := _find_node_by_name(dev_tools, "ToolButton_save_inspector") as Button
	if button != null:
		button.pressed.emit()
	var status := _find_node_by_name(dev_tools, "SaveInspectorStatusLabel") as Label
	var target := _find_node_by_name(dev_tools, "SaveInspectorResumeTargetLabel") as Label
	var passed: bool = status != null \
		and status.text.contains("status: invalid") \
		and target != null \
		and target.text.contains("continue_target: invalid_delete_on_continue") \
		and app.game.save_service.has_save() \
		and app.game.current_run == null \
		and app.game.router.current_scene == dev_tools
	app.free()
	_delete_test_save(save_path)
	return passed
```

- [ ] **Step 2: Run tests to verify RED**

Run the full test command.

Expected: FAIL because `SaveInspectorPanel`, labels, and action buttons do not exist.

- [ ] **Step 3: Implement Save Inspector panel builder**

In `scripts/ui/dev_tools_screen.gd`, add:

```gdscript
func _build_save_inspector() -> void:
	refresh_save_inspector()
	var panel := VBoxContainer.new()
	panel.name = "SaveInspectorPanel"
	tool_content.add_child(panel)

	save_inspector_status_label = Label.new()
	save_inspector_status_label.name = "SaveInspectorStatusLabel"
	save_inspector_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(save_inspector_status_label)

	save_inspector_resume_target_label = Label.new()
	save_inspector_resume_target_label.name = "SaveInspectorResumeTargetLabel"
	panel.add_child(save_inspector_resume_target_label)

	save_inspector_run_summary_label = Label.new()
	save_inspector_run_summary_label.name = "SaveInspectorRunSummaryLabel"
	save_inspector_run_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(save_inspector_run_summary_label)

	save_inspector_state_sections = VBoxContainer.new()
	save_inspector_state_sections.name = "SaveInspectorStateSections"
	panel.add_child(save_inspector_state_sections)

	save_inspector_map_section_label = Label.new()
	save_inspector_map_section_label.name = "SaveInspectorMapSectionLabel"
	save_inspector_map_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_inspector_state_sections.add_child(save_inspector_map_section_label)

	save_inspector_shop_section_label = Label.new()
	save_inspector_shop_section_label.name = "SaveInspectorShopSectionLabel"
	save_inspector_shop_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_inspector_state_sections.add_child(save_inspector_shop_section_label)

	save_inspector_reward_section_label = Label.new()
	save_inspector_reward_section_label.name = "SaveInspectorRewardSectionLabel"
	save_inspector_reward_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_inspector_state_sections.add_child(save_inspector_reward_section_label)

	var action_bar := HBoxContainer.new()
	action_bar.name = "SaveInspectorActionBar"
	panel.add_child(action_bar)

	var reload := Button.new()
	reload.name = "SaveInspectorReloadButton"
	reload.text = "Reload"
	reload.pressed.connect(_on_save_inspector_reload_pressed)
	action_bar.add_child(reload)

	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorDeleteButton", "Delete"))
	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorExportButton", "Export"))
	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorCopyJsonButton", "Copy JSON"))
	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorRepairButton", "Repair"))

	_refresh_save_inspector_panel()

func _disabled_save_inspector_action(node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.disabled = true
	return button

func _on_save_inspector_reload_pressed() -> void:
	refresh_save_inspector()
```

- [ ] **Step 4: Implement Save Inspector panel refresh**

Add:

```gdscript
func _refresh_save_inspector_panel() -> void:
	var snapshot := save_inspector_snapshot()
	if save_inspector_status_label != null:
		save_inspector_status_label.text = save_inspector_status_text()
	if save_inspector_resume_target_label != null:
		save_inspector_resume_target_label.text = "continue_target: %s\nreason: %s" % [
			String(snapshot.get("resume_target", SAVE_RESUME_NONE)),
			String(snapshot.get("reason", "")),
		]
	if save_inspector_run_summary_label != null:
		save_inspector_run_summary_label.text = save_inspector_summary_text()
	if save_inspector_map_section_label != null:
		save_inspector_map_section_label.text = save_inspector_map_text()
	if save_inspector_shop_section_label != null:
		save_inspector_shop_section_label.text = save_inspector_shop_text()
	if save_inspector_reward_section_label != null:
		save_inspector_reward_section_label.text = save_inspector_reward_text()

func _refresh_save_inspector_if_ready() -> void:
	if save_inspector_status_label != null and save_inspector_resume_target_label != null:
		_refresh_save_inspector_panel()
```

- [ ] **Step 5: Run tests to verify GREEN for Task 2**

Run the full test command.

Expected: `TESTS PASSED`.

- [ ] **Step 6: Task 2 review gates**

Stage 1:

- Save Inspector is no longer a placeholder.
- Stable UI nodes exist.
- Reload refreshes labels.
- Future action buttons exist and are disabled.
- Opening and reloading stays on DevTools and leaves `current_run` unchanged.
- Invalid saves remain present after inspection.

Stage 2:

- UI rendering delegates to helper text methods.
- Disabled future actions have no destructive signal handlers.
- No save writes, deletes, routing, or current-run assignments were added.
- Existing Card Browser, Enemy Sandbox, Event Tester, and Reward Inspector behavior remains intact.

## Task 3: Documentation, Verification, and Acceptance

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-dev-tools-save-inspector.md`

- [ ] **Step 1: Verify no Save Inspector destructive or routing calls were added**

Run:

```powershell
rtk proxy rg -n "save_run|delete_save|FileAccess\.open|ResourceSaver|current_run\s*=|router\.go_to" scripts/ui/dev_tools_screen.gd
```

Expected: the only match should be the pre-existing Enemy Sandbox route to combat:

```text
scripts/ui/dev_tools_screen.gd:<line>:	app.game.router.go_to(SceneRouterScript.COMBAT)
```

If the scan finds Save Inspector matches, fix them before continuing.

- [ ] **Step 2: Run full local tests**

Run the full test command.

Expected: `TESTS PASSED`.

- [ ] **Step 3: Run Godot import check**

Run the import check command.

Expected: process exits 0.

- [ ] **Step 4: Update README progress**

In `README.md`, add this progress bullet near the other DevTools bullets:

```markdown
- Developer tools save inspector: complete; DevTools can now diagnose save presence, validity, terminal state, map/shop/reward resume targets, and run state sections without writing, deleting, repairing, routing, or mutating the active run.
```

Update `## Next Plans` to remove Save Inspector from the first slot:

```markdown
## Next Plans

1. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
2. Presentation expansion: more per-card cue ids, enemy intent polish, card art, richer combat backgrounds, and formal audio mixing.
```

- [ ] **Step 5: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [ ] **Step 6: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Save Inspector is no longer a placeholder.
- Snapshot helpers exist.
- Status and resume target predictions match the spec.
- Map, shop, and reward sections render.
- Reload is read-only.
- Future action structure exists without destructive behavior.
- Save Inspector does not mutate `current_run`, write or delete saves, edit resources, repair saves, or route away from DevTools.

Stage 2 Code Quality Review:

- New helpers are typed and deterministic.
- Loaded `RunState` is treated as read-only.
- UI node names are stable.
- Resume prediction duplication is small and easy to extract later.
- No save management action is partially wired to destructive behavior.
- Classify any findings as Critical, Important, or Minor.

Fix any Critical or Important findings before acceptance.

## Final Acceptance Criteria

- Save Inspector is reachable inside DevTools.
- Developers can see whether a save service and save file exist.
- Developers can see if a save is invalid, terminal, or active.
- Developers can see the predicted Main Menu Continue target.
- Developers can inspect the run summary, map state, shop state, and pending reward state.
- Reload refreshes diagnostics without side effects.
- Future save management action structure is present but non-destructive.
- Save Inspector never writes saves, deletes saves, repairs saves, routes into normal flow, or mutates an existing run.
- Existing local tests pass.
- Godot import check exits 0.
