# High Presentation Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a combat presentation event queue, programmatic feedback layer, and mouse drag play so combat feels readable and responsive without coupling animation to gameplay rules.

**Architecture:** Add `CombatPresentationEvent`, `CombatPresentationConfig`, `CombatPresentationQueue`, `CombatPresentationDelta`, and `CombatPresentationLayer` under `scripts/presentation`. `CombatScreen` owns UI interaction events and pre/post combat state snapshots, while `CombatSession`, `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` remain presentation-free.

**Tech Stack:** Godot 4.6.2-stable, GDScript, dynamic Control nodes, Tweens, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature task, run the project-required two-stage review:
  - Stage 1 Spec Compliance Review.
  - Stage 2 Code Quality Review only after Stage 1 passes.
- Keep gameplay rules independent from presentation classes.

## Reference Spec

- `docs/superpowers/specs/2026-04-28-high-presentation-foundation-design.md`

## File Structure

Create:

- `scripts/presentation/combat_presentation_event.gd`: typed runtime event envelope.
- `scripts/presentation/combat_presentation_config.gd`: development presentation toggles.
- `scripts/presentation/combat_presentation_queue.gd`: FIFO queue with filtering.
- `scripts/presentation/combat_presentation_delta.gd`: pre/post combatant snapshot diff helper.
- `scripts/presentation/combat_presentation_layer.gd`: programmatic feedback playback layer.
- `tests/unit/test_combat_presentation.gd`: unit tests for event, config, queue, delta, and layer helpers.

Modify:

- `scripts/testing/test_runner.gd`: add the new unit test file.
- `scripts/app/game.gd`: store shared presentation config.
- `scripts/ui/debug_overlay.gd`: expose presentation toggles.
- `scripts/ui/combat_screen.gd`: integrate queue, layer, delta capture, hover, drag, target highlight, and click fallback.
- `tests/smoke/test_scene_flow.gd`: smoke coverage for drag play and debug toggles.
- `README.md`: mark high-presentation foundation progress after final acceptance.
- `docs/superpowers/plans/2026-04-28-high-presentation-foundation.md`: mark completed checkboxes as work proceeds.

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

---

## Task 1: Presentation Event, Config, and Queue

**Files:**

- Create: `scripts/presentation/combat_presentation_event.gd`
- Create: `scripts/presentation/combat_presentation_config.gd`
- Create: `scripts/presentation/combat_presentation_queue.gd`
- Create: `tests/unit/test_combat_presentation.gd`
- Modify: `scripts/testing/test_runner.gd`

- [x] **Step 1: Write failing primitive tests**

Create `tests/unit/test_combat_presentation.gd`:

```gdscript
extends RefCounted

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")

func test_event_copy_does_not_alias_payload_or_tags() -> bool:
	var event := CombatPresentationEvent.new("damage_number")
	event.target_id = "enemy:0"
	event.amount = 7
	event.tags = ["cinematic"]
	event.payload = {"points": [Vector2(1, 2)]}
	var copied := event.copy()
	event.tags.append("mutated")
	event.payload["points"].append(Vector2(3, 4))

	var copied_points: Array = copied.payload.get("points", [])
	var passed: bool = copied.event_type == "damage_number" \
		and copied.target_id == "enemy:0" \
		and copied.amount == 7 \
		and copied.tags == ["cinematic"] \
		and copied_points.size() == 1
	assert(passed)
	return passed

func test_queue_drains_fifo_and_clears() -> bool:
	var queue := CombatPresentationQueue.new()
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	var drained := queue.drain()
	var empty_after_drain := queue.size() == 0
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.clear()
	var passed: bool = drained.size() == 2 \
		and drained[0].event_type == "card_hovered" \
		and drained[1].event_type == "damage_number" \
		and empty_after_drain \
		and queue.size() == 0
	assert(passed)
	return passed

func test_queue_filters_disabled_floating_text_flash_highlight_drag_and_cinematic() -> bool:
	var config := CombatPresentationConfig.new()
	config.floating_text_enabled = false
	config.flash_enabled = false
	config.target_highlight_enabled = false
	config.drag_enabled = false
	config.cinematic_enabled = false

	var queue := CombatPresentationQueue.new()
	queue.config = config
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	queue.enqueue(CombatPresentationEvent.new("block_number"))
	queue.enqueue(CombatPresentationEvent.new("status_number"))
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.enqueue(CombatPresentationEvent.new("target_highlighted"))
	queue.enqueue(CombatPresentationEvent.new("card_drag_started"))
	var cinematic := CombatPresentationEvent.new("cinematic_slash")
	cinematic.tags = ["cinematic"]
	queue.enqueue(cinematic)
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))

	var drained := queue.drain()
	var passed: bool = drained.size() == 1 and drained[0].event_type == "card_hovered"
	assert(passed)
	return passed

func test_queue_drops_all_events_when_disabled() -> bool:
	var config := CombatPresentationConfig.new()
	config.enabled = false
	var queue := CombatPresentationQueue.new()
	queue.config = config
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	var passed: bool = queue.size() == 0
	assert(passed)
	return passed
```

Modify `scripts/testing/test_runner.gd` and insert the new file before `test_combat_status_runtime.gd`:

```gdscript
	"res://tests/unit/test_combat_presentation.gd",
```

- [x] **Step 2: Run tests to verify red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures loading missing presentation scripts.

- [x] **Step 3: Implement event envelope**

Create `scripts/presentation/combat_presentation_event.gd`:

```gdscript
class_name CombatPresentationEvent
extends RefCounted

var event_type: String = ""
var source_id: String = ""
var target_id: String = ""
var card_id: String = ""
var amount: int = 0
var status_id: String = ""
var text: String = ""
var intensity: float = 1.0
var tags: Array[String] = []
var payload: Dictionary = {}

func _init(input_event_type: String = "") -> void:
	event_type = input_event_type

func copy() -> CombatPresentationEvent:
	var copied := CombatPresentationEvent.new(event_type)
	copied.source_id = source_id
	copied.target_id = target_id
	copied.card_id = card_id
	copied.amount = amount
	copied.status_id = status_id
	copied.text = text
	copied.intensity = intensity
	copied.tags = tags.duplicate()
	copied.payload = payload.duplicate(true)
	return copied
```

- [x] **Step 4: Implement config**

Create `scripts/presentation/combat_presentation_config.gd`:

```gdscript
class_name CombatPresentationConfig
extends RefCounted

var enabled := true
var drag_enabled := true
var floating_text_enabled := true
var flash_enabled := true
var target_highlight_enabled := true
var status_pulse_enabled := true
var cinematic_enabled := false

func allows(event) -> bool:
	if event == null:
		return false
	if not enabled:
		return false
	var event_type := String(event.event_type)
	if not floating_text_enabled and _is_floating_text_event(event_type):
		return false
	if not flash_enabled and event_type == "combatant_flash":
		return false
	if not status_pulse_enabled and event_type == "status_badge_pulse":
		return false
	if not target_highlight_enabled and (event_type == "target_highlighted" or event_type == "target_unhighlighted"):
		return false
	if not drag_enabled and event_type.begins_with("card_drag_"):
		return false
	if not cinematic_enabled and event.tags.has("cinematic"):
		return false
	return true

func _is_floating_text_event(event_type: String) -> bool:
	return event_type == "damage_number" \
		or event_type == "block_number" \
		or event_type == "status_number"
```

- [x] **Step 5: Implement queue**

Create `scripts/presentation/combat_presentation_queue.gd`:

```gdscript
class_name CombatPresentationQueue
extends RefCounted

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")

var config: CombatPresentationConfig
var _events: Array[CombatPresentationEvent] = []

func enqueue(event: CombatPresentationEvent) -> void:
	if event == null:
		return
	if config != null and not config.allows(event):
		return
	_events.append(event.copy())

func drain() -> Array[CombatPresentationEvent]:
	var drained := _events.duplicate()
	_events.clear()
	return drained

func clear() -> void:
	_events.clear()

func size() -> int:
	return _events.size()
```

- [x] **Step 6: Run full tests to verify green**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 7: Review and commit Task 1**

Stage 1 Spec Compliance Review:

- `CombatPresentationEvent`, `CombatPresentationConfig`, and `CombatPresentationQueue` exist under `scripts/presentation`.
- Queue drains FIFO and filters disabled event categories.
- No combat gameplay file imports the new presentation classes.

Stage 2 Code Quality Review:

- Typed fields are explicit.
- Queue copies events on enqueue so later mutations do not affect queued events.
- Config filtering stays readable and deterministic.

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_event.gd scripts/presentation/combat_presentation_config.gd scripts/presentation/combat_presentation_queue.gd tests/unit/test_combat_presentation.gd scripts/testing/test_runner.gd docs/superpowers/plans/2026-04-28-high-presentation-foundation.md
rtk proxy git commit -m "feat: add combat presentation event queue"
```

---

## Task 2: Combat State Delta Events

**Files:**

- Create: `scripts/presentation/combat_presentation_delta.gd`
- Modify: `tests/unit/test_combat_presentation.gd`

- [ ] **Step 1: Add failing delta tests**

Append to `tests/unit/test_combat_presentation.gd`:

```gdscript
const CombatPresentationDelta := preload("res://scripts/presentation/combat_presentation_delta.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func test_delta_emits_damage_flash_block_status_and_pulse_events() -> bool:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.player.current_hp = 50
	state.player.block = 1
	state.player.statuses = {"poison": 1}
	state.enemies = [CombatantState.new("enemy_a", 30)]
	state.enemies[0].current_hp = 30
	state.enemies[0].block = 0
	state.enemies[0].statuses = {}

	var delta := CombatPresentationDelta.new()
	var before := delta.capture_state(state)

	state.player.current_hp = 44
	state.player.block = 5
	state.player.statuses["poison"] = 3
	state.enemies[0].current_hp = 21
	state.enemies[0].statuses["broken_stance"] = 2

	var events := delta.events_between(before, state)
	var passed: bool = _has_event(events, "damage_number", "player", 6, "") \
		and _has_event(events, "combatant_flash", "player", 0, "") \
		and _has_event(events, "block_number", "player", 4, "") \
		and _has_event(events, "status_number", "player", 2, "poison") \
		and _has_event(events, "status_badge_pulse", "player", 0, "poison") \
		and _has_event(events, "damage_number", "enemy:0", 9, "") \
		and _has_event(events, "combatant_flash", "enemy:0", 0, "") \
		and _has_event(events, "status_number", "enemy:0", 2, "broken_stance") \
		and _has_event(events, "status_badge_pulse", "enemy:0", 0, "broken_stance")
	assert(passed)
	return passed

func test_delta_ignores_unchanged_hp_block_and_status_values() -> bool:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.player.block = 2
	state.player.statuses = {"poison": 1}
	var delta := CombatPresentationDelta.new()
	var before := delta.capture_state(state)
	var events := delta.events_between(before, state)
	var passed: bool = events.is_empty()
	assert(passed)
	return passed

func test_initial_state_events_report_starting_block_and_statuses() -> bool:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.player.block = 4
	state.player.statuses = {"sword_focus": 2}
	state.enemies = [CombatantState.new("enemy_a", 30)]
	state.enemies[0].block = 3
	var delta := CombatPresentationDelta.new()
	var events := delta.events_from_initial_state(state)
	var passed: bool = _has_event(events, "block_number", "player", 4, "") \
		and _has_event(events, "status_number", "player", 2, "sword_focus") \
		and _has_event(events, "status_badge_pulse", "player", 0, "sword_focus") \
		and _has_event(events, "block_number", "enemy:0", 3, "")
	assert(passed)
	return passed

func _has_event(events: Array, event_type: String, target_id: String, amount: int, status_id: String) -> bool:
	for event in events:
		if event.event_type != event_type:
			continue
		if event.target_id != target_id:
			continue
		if amount != 0 and event.amount != amount:
			continue
		if not status_id.is_empty() and event.status_id != status_id:
			continue
		return true
	return false
```

- [ ] **Step 2: Run tests to verify red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures for missing `combat_presentation_delta.gd`.

- [ ] **Step 3: Implement delta helper**

Create `scripts/presentation/combat_presentation_delta.gd`:

```gdscript
class_name CombatPresentationDelta
extends RefCounted

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func capture_state(state: CombatState) -> Dictionary:
	var result := {}
	if state == null:
		return result
	if state.player != null:
		result["player"] = _capture_combatant(state.player)
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index] as CombatantState
		if enemy == null:
			continue
		result[_enemy_target_id(enemy_index)] = _capture_combatant(enemy)
	return result

func events_between(before: Dictionary, state: CombatState) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if state == null:
		return events
	if state.player != null:
		_append_delta_events(events, "player", before.get("player", {}), state.player)
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index] as CombatantState
		if enemy == null:
			continue
		var target_id := _enemy_target_id(enemy_index)
		_append_delta_events(events, target_id, before.get(target_id, {}), enemy)
	return events

func events_from_initial_state(state: CombatState) -> Array[CombatPresentationEvent]:
	var before := {}
	if state == null:
		return []
	if state.player != null:
		before["player"] = {
			"id": state.player.id,
			"current_hp": state.player.current_hp,
			"block": 0,
			"statuses": {},
		}
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index] as CombatantState
		if enemy == null:
			continue
		before[_enemy_target_id(enemy_index)] = {
			"id": enemy.id,
			"current_hp": enemy.current_hp,
			"block": 0,
			"statuses": {},
		}
	return events_between(before, state)

func _capture_combatant(combatant: CombatantState) -> Dictionary:
	return {
		"id": combatant.id,
		"current_hp": combatant.current_hp,
		"block": combatant.block,
		"statuses": _positive_statuses(combatant),
	}

func _positive_statuses(combatant: CombatantState) -> Dictionary:
	var result := {}
	for key in combatant.statuses.keys():
		var status_id := String(key)
		var layers := int(combatant.statuses.get(status_id, 0))
		if layers > 0:
			result[status_id] = layers
	return result

func _append_delta_events(
	events: Array[CombatPresentationEvent],
	target_id: String,
	before_payload: Dictionary,
	after: CombatantState
) -> void:
	var hp_before := int(before_payload.get("current_hp", after.current_hp))
	var hp_lost := hp_before - after.current_hp
	if hp_lost > 0:
		events.append(_event("damage_number", target_id, hp_lost))
		events.append(_event("combatant_flash", target_id, 0))

	var block_before := int(before_payload.get("block", after.block))
	var block_gained := after.block - block_before
	if block_gained > 0:
		events.append(_event("block_number", target_id, block_gained))

	var before_statuses: Dictionary = before_payload.get("statuses", {})
	var after_statuses := _positive_statuses(after)
	var status_ids := _status_union(before_statuses, after_statuses)
	for status_id in status_ids:
		var delta := int(after_statuses.get(status_id, 0)) - int(before_statuses.get(status_id, 0))
		if delta == 0:
			continue
		var status_event := _event("status_number", target_id, delta)
		status_event.status_id = status_id
		status_event.text = _status_text(status_id, delta)
		events.append(status_event)
		var pulse := _event("status_badge_pulse", target_id, 0)
		pulse.status_id = status_id
		events.append(pulse)

func _status_union(before_statuses: Dictionary, after_statuses: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for key in before_statuses.keys():
		var status_id := String(key)
		if not ids.has(status_id):
			ids.append(status_id)
	for key in after_statuses.keys():
		var status_id := String(key)
		if not ids.has(status_id):
			ids.append(status_id)
	ids.sort()
	return ids

func _event(event_type: String, target_id: String, amount: int) -> CombatPresentationEvent:
	var event := CombatPresentationEvent.new(event_type)
	event.target_id = target_id
	event.amount = amount
	return event

func _status_text(status_id: String, amount: int) -> String:
	var prefix := "+" if amount > 0 else ""
	return "%s%s %s" % [prefix, amount, status_id]

func _enemy_target_id(enemy_index: int) -> String:
	return "enemy:%s" % enemy_index
```

- [ ] **Step 4: Run full tests to verify green**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [ ] **Step 5: Review and commit Task 2**

Stage 1 Spec Compliance Review:

- Delta helper emits damage, flash, block, status, and pulse events from state differences.
- It does not import or mutate `CombatEngine`, `EffectExecutor`, or gameplay status rules.
- Initial state helper can report start-of-combat relic block/status feedback.

Stage 2 Code Quality Review:

- Snapshot dictionaries are local copies.
- Enemy target ids are deterministic by visible enemy index.
- Status union logic is sorted for stable event order.

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_delta.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-28-high-presentation-foundation.md
rtk proxy git commit -m "feat: add combat presentation delta events"
```

---

## Task 3: Programmatic Presentation Layer

**Files:**

- Create: `scripts/presentation/combat_presentation_layer.gd`
- Modify: `tests/unit/test_combat_presentation.gd`

- [ ] **Step 1: Add failing layer tests**

Append to `tests/unit/test_combat_presentation.gd`:

```gdscript
const CombatPresentationLayer := preload("res://scripts/presentation/combat_presentation_layer.gd")

func test_layer_processes_queue_into_feedback_nodes(tree: SceneTree) -> bool:
	var queue := CombatPresentationQueue.new()
	var layer := CombatPresentationLayer.new()
	layer.queue = queue
	layer.name = "PresentationLayer"
	tree.root.add_child(layer)
	var player_target := Label.new()
	player_target.name = "PlayerTarget"
	layer.bind_target("player", player_target)
	layer.add_child(player_target)

	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "player"
	damage.amount = 5
	queue.enqueue(damage)
	var flash := CombatPresentationEvent.new("combatant_flash")
	flash.target_id = "player"
	queue.enqueue(flash)
	layer.process_queue()

	var float_text := layer.get_node_or_null("FloatText_0") as Label
	var passed: bool = float_text != null \
		and float_text.text == "-5" \
		and player_target.modulate != Color.WHITE
	layer.free()
	assert(passed)
	return passed

func test_layer_target_highlight_applies_and_clears(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var enemy_target := Button.new()
	layer.bind_target("enemy:0", enemy_target)
	layer.add_child(enemy_target)
	var highlighted := CombatPresentationEvent.new("target_highlighted")
	highlighted.target_id = "enemy:0"
	layer.play_event(highlighted)
	var has_highlight := enemy_target.has_theme_color_override("font_color")
	var cleared := CombatPresentationEvent.new("target_unhighlighted")
	cleared.target_id = "enemy:0"
	layer.play_event(cleared)
	var passed: bool = has_highlight and not enemy_target.has_theme_color_override("font_color")
	layer.free()
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests to verify red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures for missing `combat_presentation_layer.gd`.

- [ ] **Step 3: Implement presentation layer**

Create `scripts/presentation/combat_presentation_layer.gd`:

```gdscript
class_name CombatPresentationLayer
extends Control

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")

const FLOAT_DURATION := 0.55
const FLASH_COLOR := Color(1.0, 0.92, 0.72)
const HIGHLIGHT_COLOR := Color(1.0, 0.82, 0.35)
const PULSE_COLOR := Color(0.58, 0.86, 0.82)

var queue: CombatPresentationQueue
var targets := {}
var status_targets := {}
var _float_index := 0

func bind_target(target_id: String, node: Control) -> void:
	if target_id.is_empty() or node == null:
		return
	targets[target_id] = node

func bind_status_target(target_id: String, node: Control) -> void:
	if target_id.is_empty() or node == null:
		return
	status_targets[target_id] = node

func clear_bindings() -> void:
	targets.clear()
	status_targets.clear()

func process_queue() -> void:
	if queue == null:
		return
	var events := queue.drain()
	for event in events:
		play_event(event)

func play_event(event: CombatPresentationEvent) -> void:
	if event == null:
		return
	match event.event_type:
		"damage_number":
			_show_float_text(event, "-%s" % event.amount, Color(1.0, 0.38, 0.32))
		"block_number":
			_show_float_text(event, "+%s Block" % event.amount, Color(0.55, 0.75, 1.0))
		"status_number":
			var text := event.text if not event.text.is_empty() else "%s %s" % [event.status_id, event.amount]
			_show_float_text(event, text, Color(0.72, 0.92, 0.72))
		"combatant_flash":
			_flash_target(event.target_id)
		"status_badge_pulse":
			_pulse_status(event.target_id)
		"target_highlighted":
			_set_highlight(event.target_id, true)
		"target_unhighlighted":
			_set_highlight(event.target_id, false)
		"card_hovered":
			_set_card_lift(event.target_id, true)
		"card_unhovered", "card_drag_released":
			_set_card_lift(event.target_id, false)
		"card_drag_started":
			_set_card_lift(event.target_id, true)

func _show_float_text(event: CombatPresentationEvent, text: String, color: Color) -> void:
	var label := Label.new()
	label.name = "FloatText_%s" % _float_index
	_float_index += 1
	label.text = text
	label.modulate = color
	label.position = _target_position(event.target_id) + Vector2(0, -24)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -28), FLOAT_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, FLOAT_DURATION)
	tween.finished.connect(label.queue_free)

func _flash_target(target_id: String) -> void:
	var node := targets.get(target_id) as Control
	if node == null:
		return
	node.modulate = FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, 0.18)

func _pulse_status(target_id: String) -> void:
	var node := status_targets.get(target_id, targets.get(target_id)) as Control
	if node == null:
		return
	node.modulate = PULSE_COLOR
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, 0.22)

func _set_highlight(target_id: String, enabled: bool) -> void:
	var node := targets.get(target_id) as Control
	if node == null:
		return
	if enabled:
		node.add_theme_color_override("font_color", HIGHLIGHT_COLOR)
	else:
		node.remove_theme_color_override("font_color")

func _set_card_lift(target_id: String, enabled: bool) -> void:
	var node := targets.get(target_id) as Control
	if node == null:
		return
	node.position.y = -8.0 if enabled else 0.0

func _target_position(target_id: String) -> Vector2:
	var node := targets.get(target_id) as Control
	if node == null:
		return Vector2.ZERO
	return node.global_position - global_position
```

- [ ] **Step 4: Run full tests to verify green**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [ ] **Step 5: Review and commit Task 3**

Stage 1 Spec Compliance Review:

- Presentation layer drains queue and plays programmatic floating text, flash, pulse, and target highlight.
- It does not mutate combat state or block input.
- The first pass uses neutral development colors.

Stage 2 Code Quality Review:

- Layer has focused responsibilities.
- Temporary nodes queue-free after tween completion.
- Missing targets are ignored safely.

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_layer.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-28-high-presentation-foundation.md
rtk proxy git commit -m "feat: add combat presentation layer"
```

---

## Task 4: CombatScreen Queue and Snapshot Integration

**Files:**

- Modify: `scripts/ui/combat_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [ ] **Step 1: Add failing smoke test for presentation layer and click feedback**

Append this test after `test_combat_screen_creates_session_and_cancels_pending_card` in `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_combat_screen_click_play_enqueues_delta_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_presentation_click_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand = ["sword.strike"]
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	combat.presentation_layer.process_queue()
	var float_text := _find_node_by_name(combat.presentation_layer, "FloatText_0") as Label
	var passed: bool = combat.get_node_or_null("PresentationLayer") != null \
		and first_card != null \
		and enemy_button != null \
		and float_text != null \
		and float_text.text.begins_with("-")
	app.free()
	_delete_test_save("user://test_combat_presentation_click_save.json")
	return passed
```

- [ ] **Step 2: Run tests to verify red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failure because `CombatScreen` has no `presentation_layer`.

- [ ] **Step 3: Add presentation preloads and fields to CombatScreen**

Modify the top of `scripts/ui/combat_screen.gd`:

```gdscript
const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const CombatPresentationDelta := preload("res://scripts/presentation/combat_presentation_delta.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationLayer := preload("res://scripts/presentation/combat_presentation_layer.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")
```

Add fields:

```gdscript
var presentation_config: CombatPresentationConfig
var presentation_queue := CombatPresentationQueue.new()
var presentation_delta := CombatPresentationDelta.new()
var presentation_layer: CombatPresentationLayer
var enemy_buttons: Array[Button] = []
var card_buttons: Array[Button] = []
```

- [ ] **Step 4: Instantiate layer and shared config**

In `_build_layout()`, after creating `hand_container`, add:

```gdscript
	presentation_layer = CombatPresentationLayer.new()
	presentation_layer.name = "PresentationLayer"
	presentation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(presentation_layer)
```

In `_start_session()`, after `session.start(...)`, add:

```gdscript
	presentation_config = CombatPresentationConfig.new()
	presentation_queue.config = presentation_config
	presentation_layer.queue = presentation_queue
	for event in presentation_delta.events_from_initial_state(session.state):
		presentation_queue.enqueue(event)
```

Task 6 will replace this local config with the shared `app.game.presentation_config` after the debug toggles exist.

- [ ] **Step 5: Bind presentation targets during refresh**

In `_refresh()`, before `_refresh_enemies()`, reset dynamic bindings and rebind the player:

```gdscript
	if presentation_layer != null:
		presentation_layer.clear_bindings()
		presentation_layer.bind_target("player", status_label)
		presentation_layer.bind_status_target("player", status_label)
```

At the start of `_refresh_enemies()`:

```gdscript
	enemy_buttons.clear()
```

After creating each enemy button:

```gdscript
		enemy_buttons.append(button)
		if presentation_layer != null:
			var target_id := "enemy:%s" % enemy_index
			presentation_layer.bind_target(target_id, button)
			presentation_layer.bind_status_target(target_id, button)
```

In `_refresh_hand()`:

```gdscript
	card_buttons.clear()
```

After creating each card button:

```gdscript
		card_buttons.append(button)
		if presentation_layer != null:
			presentation_layer.bind_target("card:%s" % hand_index, button)
```

- [ ] **Step 6: Add snapshot wrapper and use it around gameplay mutations**

Add helper:

```gdscript
func _run_with_feedback(action: Callable, played_card_id: String = "") -> bool:
	var before := presentation_delta.capture_state(session.state)
	var succeeded := bool(action.call())
	if succeeded:
		if not played_card_id.is_empty():
			var played_event := CombatPresentationEvent.new("card_played")
			played_event.card_id = played_card_id
			presentation_queue.enqueue(played_event)
		for event in presentation_delta.events_between(before, session.state):
			presentation_queue.enqueue(event)
	return succeeded
```

Modify target confirmation handlers:

```gdscript
func _on_enemy_pressed(enemy_index: int) -> void:
	var card_id := _pending_card_id()
	var action := func(): return session.confirm_enemy_target(enemy_index)
	_run_with_feedback(action, card_id)
	_refresh()

func _on_player_target_pressed() -> void:
	var card_id := _pending_card_id()
	var action := func(): return session.confirm_player_target()
	_run_with_feedback(action, card_id)
	_refresh()

func _on_end_turn_pressed() -> void:
	_run_with_feedback(func(): return session.end_player_turn())
	_refresh()
```

Leave `_on_card_pressed()` as selection-only:

```gdscript
func _on_card_pressed(hand_index: int) -> void:
	session.select_card(hand_index)
	_refresh()
```

Add helper:

```gdscript
func _enqueue_card_event(event_type: String, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= session.state.hand.size():
		return
	var event := CombatPresentationEvent.new(event_type)
	event.target_id = "card:%s" % hand_index
	event.card_id = session.state.hand[hand_index]
	presentation_queue.enqueue(event)

func _pending_card_id() -> String:
	if session.pending_card == null:
		return ""
	return session.pending_card.id
```

- [ ] **Step 7: Process queue without blocking input**

Add:

```gdscript
func _process(_delta: float) -> void:
	if presentation_layer != null:
		presentation_layer.process_queue()
```

Do not add awaits or timers that gate gameplay.

- [ ] **Step 8: Run full tests to verify green**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [ ] **Step 9: Review and commit Task 4**

Stage 1 Spec Compliance Review:

- `CombatScreen` has queue, delta, and presentation layer.
- Click fallback still plays cards.
- Player and enemy turn actions generate feedback from snapshots.
- Presentation playback is non-blocking.

Stage 2 Code Quality Review:

- Snapshot wrapper is small and reusable.
- Target binding is deterministic.
- No presentation class is imported by core combat files.

Run:

```powershell
rtk proxy git add scripts/ui/combat_screen.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-28-high-presentation-foundation.md
rtk proxy git commit -m "feat: route combat feedback through presentation queue"
```

---

## Task 5: Mouse Hover, Drag Play, and Target Highlight

**Files:**

- Modify: `scripts/ui/combat_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [ ] **Step 1: Add failing drag smoke tests**

Append to `tests/smoke/test_scene_flow.gd` after the click feedback test:

```gdscript
func test_combat_screen_drag_enemy_target_card_to_enemy(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_drag_enemy_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand = ["sword.strike"]
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var enemy_hp_before: int = combat.session.state.enemies[0].current_hp
	var played := combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()
	var float_text := _find_node_by_name(combat.presentation_layer, "FloatText_0") as Label
	var passed: bool = played \
		and combat.session.state.enemies[0].current_hp < enemy_hp_before \
		and combat.session.state.hand.is_empty() \
		and float_text != null
	app.free()
	_delete_test_save("user://test_combat_drag_enemy_save.json")
	return passed

func test_combat_screen_invalid_drag_release_does_not_mutate_state(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_invalid_drag_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand = ["sword.strike"]
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var enemy_hp_before: int = combat.session.state.enemies[0].current_hp
	var played := combat.try_play_dragged_card(0, "player", -1)
	var passed: bool = not played \
		and combat.session.state.enemies[0].current_hp == enemy_hp_before \
		and combat.session.state.hand == ["sword.strike"]
	app.free()
	_delete_test_save("user://test_combat_invalid_drag_save.json")
	return passed

func test_combat_screen_drag_self_card_upward_plays_to_player(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_drag_self_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.guard"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand = ["sword.guard"]
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var block_before: int = combat.session.state.player.block
	var played := combat.try_play_dragged_card(0, "upward", -1)
	var passed: bool = played \
		and combat.session.state.player.block > block_before \
		and combat.session.state.hand.is_empty()
	app.free()
	_delete_test_save("user://test_combat_drag_self_save.json")
	return passed
```

- [ ] **Step 2: Run tests to verify red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures for missing `try_play_dragged_card`.

- [ ] **Step 3: Add target mode and drag helpers**

Add fields to `scripts/ui/combat_screen.gd`:

```gdscript
var dragging_hand_index := -1
var drag_start_position := Vector2.ZERO
var current_highlight_target := ""
```

Add helpers:

```gdscript
func try_play_dragged_card(hand_index: int, target_kind: String, enemy_index: int = -1) -> bool:
	if presentation_config != null and not presentation_config.drag_enabled:
		return false
	if session == null or session.phase != CombatSession.PHASE_PLAYER_TURN:
		return false
	if hand_index < 0 or hand_index >= session.state.hand.size():
		return false
	var card_id := session.state.hand[hand_index]
	var mode := _card_target_mode(hand_index)
	match target_kind:
		"enemy":
			if mode != "enemy":
				return false
			var enemy_action := func():
				if not session.select_card(hand_index):
					return false
				return session.confirm_enemy_target(enemy_index)
			return _run_with_feedback(enemy_action, card_id)
		"player":
			if mode == "enemy":
				return false
			var player_action := func():
				if not session.select_card(hand_index):
					return false
				return session.confirm_player_target()
			return _run_with_feedback(player_action, card_id)
		"upward":
			if mode == "enemy":
				return false
			var upward_action := func():
				if not session.select_card(hand_index):
					return false
				return session.confirm_player_target()
			return _run_with_feedback(upward_action, card_id)
	return false

func _card_target_mode(hand_index: int) -> String:
	if hand_index < 0 or hand_index >= session.state.hand.size():
		return "invalid"
	var card = session.catalog.get_card(session.state.hand[hand_index])
	if card == null:
		return "invalid"
	for effect in card.effects:
		var target := String(effect.target).to_lower()
		if target == "enemy" or target == "target":
			return "enemy"
	return "player"
```

- [ ] **Step 4: Wire hover and GUI input to card buttons**

In `_refresh_hand()`, after `button.pressed.connect(...)`, add:

```gdscript
		button.mouse_entered.connect(func(): _on_card_hovered(hand_index))
		button.mouse_exited.connect(func(): _on_card_unhovered(hand_index))
		button.gui_input.connect(func(event): _on_card_gui_input(event, hand_index, button))
```

Add helpers:

```gdscript
func _on_card_hovered(hand_index: int) -> void:
	_enqueue_card_event("card_hovered", hand_index)

func _on_card_unhovered(hand_index: int) -> void:
	_enqueue_card_event("card_unhovered", hand_index)

func _on_card_gui_input(event: InputEvent, hand_index: int, button: Button) -> void:
	if presentation_config != null and not presentation_config.drag_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_card_drag(hand_index, button, event.global_position)
		elif dragging_hand_index == hand_index:
			_release_card_drag(event.global_position)
	elif event is InputEventMouseMotion and dragging_hand_index == hand_index:
		_update_card_drag(event.global_position)
```

- [ ] **Step 5: Implement drag start, move, release, and highlight**

Add:

```gdscript
func _start_card_drag(hand_index: int, _button: Button, global_position: Vector2) -> void:
	if session == null or session.phase != CombatSession.PHASE_PLAYER_TURN:
		return
	dragging_hand_index = hand_index
	drag_start_position = global_position
	_enqueue_card_event("card_drag_started", hand_index)

func _update_card_drag(global_position: Vector2) -> void:
	if dragging_hand_index < 0:
		return
	var target_id := _target_id_at_position(global_position)
	if target_id != current_highlight_target:
		_clear_current_highlight()
		current_highlight_target = target_id
		if not current_highlight_target.is_empty():
			var event := CombatPresentationEvent.new("target_highlighted")
			event.target_id = current_highlight_target
			presentation_queue.enqueue(event)

func _release_card_drag(global_position: Vector2) -> void:
	if dragging_hand_index < 0:
		return
	var hand_index := dragging_hand_index
	dragging_hand_index = -1
	_clear_current_highlight()
	_enqueue_card_event("card_drag_released", hand_index)
	var target_id := _target_id_at_position(global_position)
	var played := false
	if target_id.begins_with("enemy:"):
		played = try_play_dragged_card(hand_index, "enemy", int(target_id.trim_prefix("enemy:")))
	elif target_id == "player":
		played = try_play_dragged_card(hand_index, "player", -1)
	elif drag_start_position.y - global_position.y >= 80.0:
		played = try_play_dragged_card(hand_index, "upward", -1)
	if played:
		_refresh()

func _target_id_at_position(global_position: Vector2) -> String:
	for enemy_index in range(enemy_buttons.size()):
		var button := enemy_buttons[enemy_index]
		if button != null and button.get_global_rect().has_point(global_position):
			return "enemy:%s" % enemy_index
	if player_target_button != null and player_target_button.get_global_rect().has_point(global_position):
		return "player"
	if status_label != null and status_label.get_global_rect().has_point(global_position):
		return "player"
	return ""

func _clear_current_highlight() -> void:
	if current_highlight_target.is_empty():
		return
	var event := CombatPresentationEvent.new("target_unhighlighted")
	event.target_id = current_highlight_target
	presentation_queue.enqueue(event)
	current_highlight_target = ""
```

- [ ] **Step 6: Run full tests to verify green**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [ ] **Step 7: Review and commit Task 5**

Stage 1 Spec Compliance Review:

- Mouse drag supports enemy, player, and upward release rules.
- Invalid drag release does not mutate combat state.
- Click fallback remains usable.
- Target highlight events are emitted and cleared.

Stage 2 Code Quality Review:

- Drag helpers do not duplicate core play logic beyond target-mode validation.
- Selection cancellation and pending state remain valid.
- Button refresh does not leave stale highlight state.

Run:

```powershell
rtk proxy git add scripts/ui/combat_screen.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-28-high-presentation-foundation.md
rtk proxy git commit -m "feat: add mouse drag combat play"
```

---

## Task 6: DebugOverlay Presentation Toggles

**Files:**

- Modify: `scripts/app/game.gd`
- Modify: `scripts/ui/combat_screen.gd`
- Modify: `scripts/ui/debug_overlay.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [ ] **Step 1: Add failing debug toggle smoke tests**

Append to `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_debug_overlay_updates_presentation_config(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_presentation_config_save.json")
	var debug_overlay := app.get_node_or_null("DebugLayer/DebugOverlay")
	var drag_toggle := _find_node_by_name(debug_overlay, "DebugPresentationDrag") as CheckBox
	if drag_toggle != null:
		drag_toggle.button_pressed = false
		drag_toggle.toggled.emit(false)
	var passed: bool = drag_toggle != null \
		and app.game.presentation_config.drag_enabled == false
	app.free()
	_delete_test_save("user://test_debug_presentation_config_save.json")
	return passed

func test_combat_screen_drag_disabled_keeps_click_fallback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_drag_disabled_click_save.json")
	app.game.presentation_config.drag_enabled = false
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand = ["sword.strike"]
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var drag_played := combat.try_play_dragged_card(0, "enemy", 0)
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	var passed: bool = not drag_played \
		and first_card != null \
		and enemy_button != null \
		and combat.session.state.hand.is_empty()
	app.free()
	_delete_test_save("user://test_drag_disabled_click_save.json")
	return passed
```

- [ ] **Step 2: Run tests to verify red**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures for missing `presentation_config` or missing debug toggle nodes.

- [ ] **Step 3: Store presentation config in Game**

Modify `scripts/app/game.gd`:

```gdscript
class_name Game
extends Node

const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var router := SceneRouterScript.new()
var current_run
var platform_service
var save_service
var presentation_config := CombatPresentationConfig.new()
```

- [ ] **Step 4: Add DebugOverlay toggles**

In `scripts/ui/debug_overlay.gd`, add after the existing map button:

```gdscript
	_add_presentation_toggle(box, "DebugPresentationEnabled", "Presentation", "enabled")
	_add_presentation_toggle(box, "DebugPresentationDrag", "Drag Play", "drag_enabled")
	_add_presentation_toggle(box, "DebugPresentationFloatingText", "Float Text", "floating_text_enabled")
	_add_presentation_toggle(box, "DebugPresentationFlash", "Hit Flash", "flash_enabled")
	_add_presentation_toggle(box, "DebugPresentationHighlight", "Target Highlight", "target_highlight_enabled")
	_add_presentation_toggle(box, "DebugPresentationStatusPulse", "Status Pulse", "status_pulse_enabled")
	_add_presentation_toggle(box, "DebugPresentationCinematic", "Future Cinematic", "cinematic_enabled")
```

Add helper:

```gdscript
func _add_presentation_toggle(box: VBoxContainer, node_name: String, label: String, property_name: String) -> void:
	var app := _get_app()
	if app == null or app.game == null or app.game.presentation_config == null:
		return
	var toggle := CheckBox.new()
	toggle.name = node_name
	toggle.text = "Debug: %s" % label
	toggle.button_pressed = bool(app.game.presentation_config.get(property_name))
	toggle.toggled.connect(func(enabled: bool): app.game.presentation_config.set(property_name, enabled))
	box.add_child(toggle)
```

In `scripts/ui/combat_screen.gd`, replace the local config line added in Task 4:

```gdscript
	presentation_config = CombatPresentationConfig.new()
```

with:

```gdscript
	presentation_config = app.game.presentation_config
```

- [ ] **Step 5: Run full tests to verify green**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [ ] **Step 6: Review and commit Task 6**

Stage 1 Spec Compliance Review:

- DebugOverlay exposes all specified presentation toggles.
- Drag disabled prevents drag play but does not break click play.
- Config is not persisted in save files.

Stage 2 Code Quality Review:

- Toggle helper avoids duplicated wiring.
- `Game` owns one shared config.
- CombatScreen reads shared config instead of creating divergent state.

Run:

```powershell
rtk proxy git add scripts/app/game.gd scripts/ui/combat_screen.gd scripts/ui/debug_overlay.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-28-high-presentation-foundation.md
rtk proxy git commit -m "feat: add combat presentation debug toggles"
```

---

## Task 7: Final Acceptance, Documentation, and Reviews

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-28-high-presentation-foundation.md`

- [ ] **Step 1: Run full local tests**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 2: Run Godot import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 3: Update README progress**

Append under `## Phase 2 Progress` in `README.md`:

```markdown
- High-presentation foundation: complete; combat now routes feedback through a presentation event queue, supports mouse drag play with click fallback, and shows programmatic hover, target highlight, floating number, flash, and status pulse feedback.
```

Update `## Next Plans` to remove the completed high-presentation foundation item and keep:

```markdown
## Next Plans

1. High-presentation polish: generated assets, sword-qi trails, medicine mist, camera impulse, slow motion, particles, and audio cues.
2. Developer tools: card browser, enemy sandbox, event tester, reward inspector, save inspector.
3. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
```

- [ ] **Step 4: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [ ] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Combat has `CombatPresentationEvent`, `CombatPresentationConfig`, `CombatPresentationQueue`, `CombatPresentationDelta`, and `CombatPresentationLayer`.
- `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` do not import presentation scripts.
- Mouse drag can play enemy-target, player-target, and self/no-target cards.
- Click fallback still works.
- Invalid drag release does not mutate combat state.
- Player and enemy turns both produce visible feedback from state deltas.
- Floating numbers show damage, block, and status changes.
- Flash, target highlight, and status pulse feedback exist.
- DebugOverlay can disable presentation categories.
- Presentation playback does not block gameplay input.
- No final art, audio, real slow motion, real camera shake, touch/controller support, formal settings screen, or save schema work was added.

Stage 2 Code Quality Review:

- GDScript types are clear.
- Presentation queue and delta helpers are unit-testable.
- CombatScreen integration is readable and does not duplicate gameplay rules.
- Drag logic does not corrupt `CombatSession` pending selection state.
- Debug toggles share one config object.
- Temporary feedback nodes clean themselves up.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

- [ ] **Step 6: Commit acceptance docs**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-28-high-presentation-foundation.md
rtk proxy git commit -m "docs: record high presentation foundation acceptance"
```

## Final Acceptance Criteria

- Combat has a presentation event queue and presentation layer separate from core combat rules.
- `CombatEngine`, `EffectExecutor`, and status gameplay rules do not depend on presentation classes.
- Mouse drag can play valid enemy-target, player-target, and self/no-target cards.
- Existing click play flow still works.
- Invalid drag release does not mutate combat state.
- Player and enemy turns both produce visible feedback from state deltas.
- Floating numbers show damage, block, and status changes.
- Combatants flash or pulse when hit or when status layers change.
- Target highlighting appears during drag targeting.
- DebugOverlay can disable presentation categories for development.
- Presentation playback does not block gameplay input or require animations to finish.
- Existing local tests and Godot import check pass.

## Out of Scope Confirmation

Do not add:

- Final UI skin or broad generated asset pack.
- Real audio assets.
- Real slow motion or camera shake playback.
- Touch or controller drag input.
- Animation-driven gameplay sequencing.
- Formal player settings or persisted presentation settings.
- Full cinematic combat playback.
- Presentation imports in `CombatEngine`, `EffectExecutor`, or `CombatStatusRuntime`.
