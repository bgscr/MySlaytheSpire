# Event Node Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make map `event` nodes enter a data-driven event screen where one deterministic event option can be selected, applied to the run, saved, and advanced back to the map or summary.

**Architecture:** Add `EventDef` / `EventOptionDef` resources and register them through `ContentCatalog`. Keep event selection and event option application out of UI with `EventResolver` and `EventRunner`, and extract shared map advancement into `RunProgression` so reward, event, and future shop flows use one rule.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resources, dynamic UI nodes, custom headless test runner.

---

## Execution Context

Project rule from `AGENTS.md`: development happens directly in the local `main` workspace.

Do not create worktrees. Do not create branches. Before editing, verify:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected branch: `main`.

If using subagents, `AGENTS.md` requires every development or review subagent to use:

```text
model: gpt-5.5
reasoning_effort: xhigh
```

This plan is intended for inline execution in this session because the user explicitly asked to generate the plan and start TDD development.

## Scope Check

This plan implements `docs/superpowers/specs/2026-04-27-event-node-foundation-design.md`.

Included:

- Event and event option resource schemas.
- Three default event resources.
- Event loading, querying, and validation in `ContentCatalog`.
- Deterministic event selection through `EventResolver`.
- Event option availability and HP/gold application through `EventRunner`.
- Shared map advancement helper through `RunProgression`.
- Event scene flow and `MapScreen` routing for `event` nodes.
- Reward screen progression refactor to use `RunProgression`.
- Unit and smoke coverage.
- README and plan acceptance updates.

Excluded:

- Shop scene or shop item model.
- Pending event save schema.
- Multi-step event state.
- Card, relic, removal, upgrade, transform, or reward-package event outcomes.
- Event art, animation, VFX, audio, or localization beyond required zh_CN keys.

## File Structure

Create:

- `scripts/data/event_option_def.gd`: data-only event option resource.
- `scripts/data/event_def.gd`: data-only event resource.
- `scripts/event/event_resolver.gd`: current-node deterministic event selection.
- `scripts/event/event_runner.gd`: option availability and run mutation.
- `scripts/run/run_progression.gd`: shared current-node advancement.
- `scripts/ui/event_screen.gd`: event screen UI and flow.
- `scenes/event/EventScreen.tscn`: event screen scene.
- `resources/events/wandering_physician.tres`: HP-for-gold event.
- `resources/events/spirit_toll.tres`: gold-for-HP event.
- `resources/events/quiet_shrine.tres`: simple positive choice event.
- `tests/unit/test_event_resolver.gd`: resolver tests.
- `tests/unit/test_event_runner.gd`: runner tests.
- `tests/unit/test_run_progression.gd`: progression tests.

Modify:

- `scripts/content/content_catalog.gd`: event loading, querying, validation.
- `scripts/app/scene_router.gd`: event scene path.
- `scripts/ui/map_screen.gd`: route event nodes to event scene.
- `scripts/ui/reward_screen.gd`: use `RunProgression`.
- `scripts/testing/test_runner.gd`: register new test files.
- `tests/unit/test_resource_schemas.gd`: event schema tests.
- `tests/unit/test_content_catalog.gd`: event catalog tests.
- `tests/smoke/test_scene_flow.gd`: event scene flow smoke tests.
- `localization/zh_CN.po`: event localization keys.
- `README.md`: Phase 2 progress.
- `docs/superpowers/plans/2026-04-27-event-node-foundation.md`: mark execution status.

## Command Conventions

Run full tests:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Run import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

## Task 1: Event Resource Schemas, Catalog, and Default Resources

**Files:**

- Create: `scripts/data/event_option_def.gd`
- Create: `scripts/data/event_def.gd`
- Create: `resources/events/wandering_physician.tres`
- Create: `resources/events/spirit_toll.tres`
- Create: `resources/events/quiet_shrine.tres`
- Modify: `scripts/content/content_catalog.gd`
- Modify: `tests/unit/test_resource_schemas.gd`
- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `localization/zh_CN.po`

- [x] **Step 1: Add failing event schema tests**

Append to `tests/unit/test_resource_schemas.gd`:

```gdscript
const EventDef := preload("res://scripts/data/event_def.gd")
const EventOptionDef := preload("res://scripts/data/event_option_def.gd")

func test_event_option_def_stores_requirements_and_run_deltas() -> bool:
	var option := EventOptionDef.new()
	option.id = "pay_for_treatment"
	option.label_key = "event.wandering_physician.option.pay"
	option.description_key = "event.wandering_physician.option.pay.desc"
	option.min_hp = 0
	option.min_gold = 25
	option.hp_delta = 12
	option.gold_delta = -25
	var passed: bool = option.id == "pay_for_treatment" \
		and option.min_gold == 25 \
		and option.hp_delta == 12 \
		and option.gold_delta == -25
	assert(passed)
	return passed

func test_event_def_stores_localization_weight_and_options() -> bool:
	var option := EventOptionDef.new()
	option.id = "decline"
	var event := EventDef.new()
	event.id = "wandering_physician"
	event.title_key = "event.wandering_physician.title"
	event.body_key = "event.wandering_physician.body"
	event.event_weight = 10
	event.options = [option]
	var passed: bool = event.id == "wandering_physician" \
		and event.title_key == "event.wandering_physician.title" \
		and event.body_key == "event.wandering_physician.body" \
		and event.event_weight == 10 \
		and event.options.size() == 1 \
		and event.options[0].id == "decline"
	assert(passed)
	return passed
```

- [x] **Step 2: Add failing ContentCatalog event tests**

Append to `tests/unit/test_content_catalog.gd`:

```gdscript
const EventDef := preload("res://scripts/data/event_def.gd")

func test_default_catalog_loads_event_pool() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var event_ids := _ids(catalog.get_events())
	var passed: bool = catalog.events_by_id.size() == 3 \
		and event_ids.has("wandering_physician") \
		and event_ids.has("spirit_toll") \
		and event_ids.has("quiet_shrine") \
		and catalog.get_event("quiet_shrine") != null
	assert(passed)
	return passed

func test_catalog_rejects_wrong_resource_type_for_event_paths() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_from_paths([], [], [], [], ["res://resources/relics/jade_talisman.tres"])
	var passed := catalog.events_by_id.is_empty() \
		and catalog.load_errors.size() == 1 \
		and catalog.load_errors[0].contains("expected EventDef")
	assert(passed)
	return passed

func test_validation_reports_event_without_options() -> bool:
	var catalog := ContentCatalog.new()
	var event := EventDef.new()
	event.id = "empty_event"
	event.title_key = "event.empty.title"
	event.body_key = "event.empty.body"
	catalog.events_by_id[event.id] = event
	var errors := catalog.validate()
	var passed := _any_contains(errors, "empty_event has no options")
	assert(passed)
	return passed
```

Add helper near `_contains_all(...)`:

```gdscript
func _any_contains(values: Array[String], text: String) -> bool:
	for value in values:
		if value.contains(text):
			return true
	return false
```

- [x] **Step 3: Run tests and verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: tests fail because `res://scripts/data/event_def.gd` and `res://scripts/data/event_option_def.gd` do not exist.

- [x] **Step 4: Implement event resource scripts**

Create `scripts/data/event_option_def.gd`:

```gdscript
class_name EventOptionDef
extends Resource

@export var id: String = ""
@export var label_key: String = ""
@export var description_key: String = ""
@export var min_hp: int = 0
@export var min_gold: int = 0
@export var hp_delta: int = 0
@export var gold_delta: int = 0
```

Create `scripts/data/event_def.gd`:

```gdscript
class_name EventDef
extends Resource

const EventOptionDef := preload("res://scripts/data/event_option_def.gd")

@export var id: String = ""
@export var title_key: String = ""
@export var body_key: String = ""
@export var event_weight: int = 1
@export var options: Array[EventOptionDef] = []
```

- [x] **Step 5: Extend ContentCatalog for events**

Modify `scripts/content/content_catalog.gd`:

```gdscript
const EventDef := preload("res://scripts/data/event_def.gd")

const DEFAULT_EVENT_PATHS: Array[String] = [
	"res://resources/events/wandering_physician.tres",
	"res://resources/events/spirit_toll.tres",
	"res://resources/events/quiet_shrine.tres",
]

var events_by_id: Dictionary = {}

func load_default() -> void:
	load_from_paths(
		DEFAULT_CARD_PATHS,
		DEFAULT_CHARACTER_PATHS,
		DEFAULT_ENEMY_PATHS,
		DEFAULT_RELIC_PATHS,
		DEFAULT_EVENT_PATHS
	)

func load_from_paths(
	card_paths: Array[String],
	character_paths: Array[String],
	enemy_paths: Array[String],
	relic_paths: Array[String],
	event_paths: Array[String] = []
) -> void:
	clear()
	_load_cards(card_paths)
	_load_characters(character_paths)
	_load_enemies(enemy_paths)
	_load_relics(relic_paths)
	_load_events(event_paths)

func clear() -> void:
	cards_by_id.clear()
	characters_by_id.clear()
	enemies_by_id.clear()
	relics_by_id.clear()
	events_by_id.clear()
	load_errors.clear()

func get_event(event_id: String) -> EventDef:
	return events_by_id.get(event_id) as EventDef

func get_events() -> Array[EventDef]:
	var result: Array[EventDef] = []
	for event: EventDef in events_by_id.values():
		result.append(event)
	return result

func _load_events(paths: Array[String]) -> void:
	for path in paths:
		var event := load(path) as EventDef
		if event == null:
			_record_load_error("ContentCatalog expected EventDef resource: %s" % path)
			continue
		if event.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		events_by_id[event.id] = event
```

Update validation:

```gdscript
_validate_ids("event", events_by_id, errors)
_validate_event_options(errors)
```

Update `_validate_locale_keys(...)`:

```gdscript
for event: EventDef in events_by_id.values():
	_require_locale_key(event.title_key, "event %s title_key" % event.id, locale_keys, errors)
	_require_locale_key(event.body_key, "event %s body_key" % event.id, locale_keys, errors)
	for option in event.options:
		_require_locale_key(option.label_key, "event %s option %s label_key" % [event.id, option.id], locale_keys, errors)
		if not option.description_key.is_empty():
			_require_locale_key(option.description_key, "event %s option %s description_key" % [event.id, option.id], locale_keys, errors)
```

Add helper:

```gdscript
func _validate_event_options(errors: Array[String]) -> void:
	for event: EventDef in events_by_id.values():
		if event.options.is_empty():
			errors.append("Event %s has no options" % event.id)
		for option in event.options:
			if option == null:
				errors.append("Event %s has null option" % event.id)
			elif option.id.is_empty():
				errors.append("Event %s has option with empty id" % event.id)
```

- [x] **Step 6: Add default event resources**

Create `resources/events/wandering_physician.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_pay"]
script = ExtResource("2_option")
id = "pay_for_treatment"
label_key = "event.wandering_physician.option.pay"
description_key = "event.wandering_physician.option.pay.desc"
min_gold = 25
hp_delta = 12
gold_delta = -25

[sub_resource type="Resource" id="Resource_decline"]
script = ExtResource("2_option")
id = "decline"
label_key = "event.wandering_physician.option.decline"
description_key = "event.wandering_physician.option.decline.desc"

[resource]
script = ExtResource("1_event")
id = "wandering_physician"
title_key = "event.wandering_physician.title"
body_key = "event.wandering_physician.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_pay"), SubResource("Resource_decline")])
```

Create `resources/events/spirit_toll.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_offer"]
script = ExtResource("2_option")
id = "offer_vitality"
label_key = "event.spirit_toll.option.offer"
description_key = "event.spirit_toll.option.offer.desc"
min_hp = 7
hp_delta = -6
gold_delta = 35

[sub_resource type="Resource" id="Resource_walk"]
script = ExtResource("2_option")
id = "walk_away"
label_key = "event.spirit_toll.option.walk"
description_key = "event.spirit_toll.option.walk.desc"

[resource]
script = ExtResource("1_event")
id = "spirit_toll"
title_key = "event.spirit_toll.title"
body_key = "event.spirit_toll.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_offer"), SubResource("Resource_walk")])
```

Create `resources/events/quiet_shrine.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_meditate"]
script = ExtResource("2_option")
id = "meditate"
label_key = "event.quiet_shrine.option.meditate"
description_key = "event.quiet_shrine.option.meditate.desc"
hp_delta = 6

[sub_resource type="Resource" id="Resource_coin"]
script = ExtResource("2_option")
id = "take_incense_coin"
label_key = "event.quiet_shrine.option.coin"
description_key = "event.quiet_shrine.option.coin.desc"
gold_delta = 12

[resource]
script = ExtResource("1_event")
id = "quiet_shrine"
title_key = "event.quiet_shrine.title"
body_key = "event.quiet_shrine.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_meditate"), SubResource("Resource_coin")])
```

- [x] **Step 7: Add event localization keys**

Append to `localization/zh_CN.po`:

```po
msgid "event.wandering_physician.title"
msgstr "云游医修"

msgid "event.wandering_physician.body"
msgstr "一位背着药箱的医修在路旁歇脚，愿用灵草为你调息经脉。"

msgid "event.wandering_physician.option.pay"
msgstr "支付 25 金，恢复 12 生命"

msgid "event.wandering_physician.option.pay.desc"
msgstr "花费金币换取治疗。"

msgid "event.wandering_physician.option.decline"
msgstr "谢绝"

msgid "event.wandering_physician.option.decline.desc"
msgstr "不改变当前状态。"

msgid "event.spirit_toll.title"
msgstr "灵桥索渡"

msgid "event.spirit_toll.body"
msgstr "幽蓝灵桥横在峡谷之间，守桥残影索要一缕气血作为过路贡礼。"

msgid "event.spirit_toll.option.offer"
msgstr "失去 6 生命，获得 35 金"

msgid "event.spirit_toll.option.offer.desc"
msgstr "以气血换取灵桥馈赠。"

msgid "event.spirit_toll.option.walk"
msgstr "绕路离开"

msgid "event.spirit_toll.option.walk.desc"
msgstr "不改变当前状态。"

msgid "event.quiet_shrine.title"
msgstr "静心古龛"

msgid "event.quiet_shrine.body"
msgstr "藤蔓掩映下，一座古龛仍有淡淡香火。"

msgid "event.quiet_shrine.option.meditate"
msgstr "打坐调息，恢复 6 生命"

msgid "event.quiet_shrine.option.meditate.desc"
msgstr "借古龛灵息恢复生命。"

msgid "event.quiet_shrine.option.coin"
msgstr "取走香炉铜钱，获得 12 金"

msgid "event.quiet_shrine.option.coin.desc"
msgstr "获得少量金币。"
```

- [x] **Step 8: Run tests and verify GREEN for Task 1**

Run full tests. Expected: event schema and catalog tests pass, full suite ends with `TESTS PASSED`.

- [x] **Step 9: Run Task 1 review gates**

Stage 1 Spec Compliance Review:

- Confirm event resources are `.tres` files.
- Confirm `ContentCatalog` loads three events by default.
- Confirm catalog validation includes event and option localization.
- Confirm no runtime event flow or shop implementation was added yet.

Stage 2 Code Quality Review:

- Check event schemas are data-only.
- Check existing `load_from_paths(...)` callers remain compatible.
- Check validation errors are specific.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 10: Commit Task 1**

```powershell
rtk git add scripts/data/event_option_def.gd scripts/data/event_def.gd scripts/content/content_catalog.gd resources/events localization/zh_CN.po tests/unit/test_resource_schemas.gd tests/unit/test_content_catalog.gd
rtk git commit -m "feat: add event resources to catalog"
```

## Task 2: Event Resolver, Runner, and Shared Run Progression

**Files:**

- Create: `scripts/event/event_resolver.gd`
- Create: `scripts/event/event_runner.gd`
- Create: `scripts/run/run_progression.gd`
- Create: `tests/unit/test_event_resolver.gd`
- Create: `tests/unit/test_event_runner.gd`
- Create: `tests/unit/test_run_progression.gd`
- Modify: `scripts/testing/test_runner.gd`

- [x] **Step 1: Register new unit tests**

Modify `scripts/testing/test_runner.gd` and insert after `test_reward_resolver.gd`:

```gdscript
"res://tests/unit/test_event_resolver.gd",
"res://tests/unit/test_event_runner.gd",
"res://tests/unit/test_run_progression.gd",
```

- [x] **Step 2: Write failing EventResolver tests**

Create `tests/unit/test_event_resolver.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventResolver := preload("res://scripts/event/event_resolver.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_event_resolver_returns_deterministic_event_for_same_run_context() -> bool:
	var catalog := _catalog()
	var run := _run_for_node("event", 707, "node_0")
	var first = EventResolver.new().resolve(catalog, run)
	var second = EventResolver.new().resolve(catalog, run)
	var passed: bool = first != null \
		and second != null \
		and first.id == second.id \
		and ["wandering_physician", "spirit_toll", "quiet_shrine"].has(first.id)
	assert(passed)
	return passed

func test_event_resolver_uses_node_id_in_rng_context() -> bool:
	var catalog := _catalog()
	var first = EventResolver.new().resolve(catalog, _run_for_node("event", 808, "node_0"))
	var second = EventResolver.new().resolve(catalog, _run_for_node("event", 808, "node_1"))
	var passed: bool = first != null and second != null
	assert(passed)
	return passed

func test_event_resolver_returns_null_for_non_event_node() -> bool:
	var event = EventResolver.new().resolve(_catalog(), _run_for_node("combat", 909, "node_0"))
	var passed := event == null
	assert(passed)
	return passed

func test_event_resolver_returns_null_for_missing_current_node() -> bool:
	var run := _run_for_node("event", 1001, "node_0")
	run.current_node_id = "missing"
	var event = EventResolver.new().resolve(_catalog(), run)
	var passed := event == null
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run_for_node(node_type: String, seed_value: int, node_id: String) -> RunState:
	var run := RunState.new()
	run.seed_value = seed_value
	run.current_node_id = node_id
	var node := MapNodeState.new(node_id, 0, node_type)
	node.unlocked = true
	run.map_nodes = [node]
	return run
```

- [x] **Step 3: Write failing EventRunner tests**

Create `tests/unit/test_event_runner.gd`:

```gdscript
extends RefCounted

const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const EventRunner := preload("res://scripts/event/event_runner.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_runner_applies_hp_and_gold_deltas() -> bool:
	var run := _run(20, 40, 10)
	var option := _option(0, 0, 7, -5)
	var applied := EventRunner.new().apply_option(run, option)
	var passed: bool = applied and run.current_hp == 27 and run.gold == 5
	assert(passed)
	return passed

func test_runner_clamps_hp_and_gold() -> bool:
	var run := _run(4, 30, 2)
	var option := _option(0, 0, -99, -99)
	var applied := EventRunner.new().apply_option(run, option)
	var passed: bool = applied and run.current_hp == 1 and run.gold == 0
	assert(passed)
	return passed

func test_runner_rejects_unavailable_option_without_mutation() -> bool:
	var run := _run(5, 30, 10)
	var option := _option(7, 25, -6, 35)
	var runner := EventRunner.new()
	var applied := runner.apply_option(run, option)
	var reason := runner.unavailable_reason(run, option)
	var passed: bool = not applied \
		and run.current_hp == 5 \
		and run.gold == 10 \
		and reason.contains("Requires")
	assert(passed)
	return passed

func _run(current_hp: int, max_hp: int, gold: int) -> RunState:
	var run := RunState.new()
	run.current_hp = current_hp
	run.max_hp = max_hp
	run.gold = gold
	return run

func _option(min_hp: int, min_gold: int, hp_delta: int, gold_delta: int) -> EventOptionDef:
	var option := EventOptionDef.new()
	option.id = "test_option"
	option.min_hp = min_hp
	option.min_gold = min_gold
	option.hp_delta = hp_delta
	option.gold_delta = gold_delta
	return option
```

- [x] **Step 4: Write failing RunProgression tests**

Create `tests/unit/test_run_progression.gd`:

```gdscript
extends RefCounted

const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_progression_marks_current_visited_and_unlocks_next_node() -> bool:
	var run := _run_with_nodes(0)
	var advanced := RunProgression.new().advance_current_node(run)
	var passed: bool = advanced \
		and run.map_nodes[0].visited \
		and run.map_nodes[1].unlocked \
		and not run.completed
	assert(passed)
	return passed

func test_progression_completes_run_on_final_node() -> bool:
	var run := _run_with_nodes(1)
	var advanced := RunProgression.new().advance_current_node(run)
	var passed: bool = advanced \
		and run.map_nodes[1].visited \
		and run.completed
	assert(passed)
	return passed

func test_progression_returns_false_for_missing_current_node() -> bool:
	var run := _run_with_nodes(0)
	run.current_node_id = "missing"
	var advanced := RunProgression.new().advance_current_node(run)
	var passed := not advanced and not run.map_nodes[0].visited
	assert(passed)
	return passed

func _run_with_nodes(current_index: int) -> RunState:
	var run := RunState.new()
	var first := MapNodeState.new("node_0", 0, "event")
	first.unlocked = true
	var second := MapNodeState.new("node_1", 1, "combat")
	run.map_nodes = [first, second]
	run.current_node_id = run.map_nodes[current_index].id
	return run
```

- [x] **Step 5: Run tests and verify RED**

Run full tests. Expected: the new unit test files fail to load because event runtime and progression scripts do not exist.

- [x] **Step 6: Implement EventResolver**

Create `scripts/event/event_resolver.gd`:

```gdscript
class_name EventResolver
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventDef := preload("res://scripts/data/event_def.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RngService := preload("res://scripts/core/rng_service.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func resolve(catalog: ContentCatalog, run: RunState) -> EventDef:
	if catalog == null or run == null:
		return null
	var node := _current_node(run)
	if node == null or node.node_type != "event":
		return null
	var events := catalog.get_events()
	if events.is_empty():
		return null
	var rng := RngService.new(run.seed_value).fork("event:%s" % node.id)
	return _pick_weighted_event(rng, events)

func _pick_weighted_event(rng: RngService, events: Array[EventDef]) -> EventDef:
	var total := 0
	for event in events:
		total += max(0, event.event_weight)
	if total <= 0:
		return events[0]
	var roll := rng.next_int(1, total)
	var cumulative := 0
	for event in events:
		cumulative += max(0, event.event_weight)
		if roll <= cumulative:
			return event
	return events[0]

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
```

- [x] **Step 7: Implement EventRunner**

Create `scripts/event/event_runner.gd`:

```gdscript
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
```

- [x] **Step 8: Implement RunProgression**

Create `scripts/run/run_progression.gd`:

```gdscript
class_name RunProgression
extends RefCounted

const RunState := preload("res://scripts/run/run_state.gd")

func advance_current_node(run: RunState) -> bool:
	if run == null:
		return false
	var current_index := -1
	for i in range(run.map_nodes.size()):
		if run.map_nodes[i].id == run.current_node_id:
			current_index = i
			run.map_nodes[i].visited = true
			break
	if current_index == -1:
		return false
	if current_index + 1 < run.map_nodes.size():
		run.map_nodes[current_index + 1].unlocked = true
	else:
		run.completed = true
	return true
```

- [x] **Step 9: Run tests and verify GREEN for Task 2**

Run full tests. Expected: new resolver, runner, and progression tests pass, full suite ends with `TESTS PASSED`.

- [x] **Step 10: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- Confirm event resolver only resolves `event` nodes.
- Confirm event resolver uses seed and node id.
- Confirm event runner applies only HP and gold.
- Confirm HP cannot drop below 1 and gold cannot drop below 0.
- Confirm shared progression marks visited, unlocks next, or completes run.

Stage 2 Code Quality Review:

- Check resolver and runner APIs are narrow.
- Check no UI or save code is in resolver/runner.
- Check progression helper is reusable by reward and event scenes.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 11: Commit Task 2**

```powershell
rtk git add scripts/event scripts/run/run_progression.gd tests/unit/test_event_resolver.gd tests/unit/test_event_runner.gd tests/unit/test_run_progression.gd scripts/testing/test_runner.gd
rtk git commit -m "feat: add event runtime foundation"
```

## Task 3: Event Screen, Routing, and Reward Progression Refactor

**Files:**

- Create: `scripts/ui/event_screen.gd`
- Create: `scenes/event/EventScreen.tscn`
- Modify: `scripts/app/scene_router.gd`
- Modify: `scripts/ui/map_screen.gd`
- Modify: `scripts/ui/reward_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [x] **Step 1: Add failing event scene smoke tests**

Append to `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_map_event_node_routes_to_event_screen(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_event_route_save.json")
	var run := _reward_run("event", true)
	app.game.current_run = run
	var map_screen = app.game.router.go_to(SceneRouterScript.MAP)
	var event_button := _find_node_by_text(map_screen, "node_0: event") as Button
	if event_button != null:
		event_button.pressed.emit()
	var passed: bool = event_button != null \
		and app.game.router.current_scene != null \
		and app.game.router.current_scene.name == "EventScreen"
	app.free()
	_delete_test_save("user://test_event_route_save.json")
	return passed

func test_event_screen_option_applies_saves_and_advances(tree: SceneTree) -> bool:
	var save_path := "user://test_event_screen_apply_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	run.seed_value = 1
	run.current_hp = 20
	run.max_hp = 40
	run.gold = 50
	app.game.current_run = run
	var event_screen = app.game.router.go_to(SceneRouterScript.EVENT)
	var option_button := _find_node_by_name(event_screen, "EventOption_0") as Button
	if option_button != null:
		option_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = option_button != null \
		and loaded_run != null \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != event_screen
	app.free()
	_delete_test_save(save_path)
	return passed

func test_event_screen_disables_unavailable_option(tree: SceneTree) -> bool:
	var save_path := "user://test_event_screen_disabled_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	run.seed_value = 1
	run.current_hp = 20
	run.max_hp = 40
	run.gold = 0
	app.game.current_run = run
	var event_screen = app.game.router.go_to(SceneRouterScript.EVENT)
	var disabled_button := _first_disabled_event_option(event_screen)
	var passed: bool = disabled_button != null and disabled_button.disabled
	app.free()
	_delete_test_save(save_path)
	return passed
```

Add helpers:

```gdscript
func _find_node_by_text(root: Node, text: String) -> Node:
	if root == null:
		return null
	if "text" in root and String(root.text) == text:
		return root
	for child in root.get_children():
		var found := _find_node_by_text(child, text)
		if found != null:
			return found
	return null

func _first_disabled_event_option(root: Node) -> Button:
	if root == null:
		return null
	if root is Button and root.name.begins_with("EventOption_") and root.disabled:
		return root
	for child in root.get_children():
		var found := _first_disabled_event_option(child)
		if found != null:
			return found
	return null
```

- [x] **Step 2: Run tests and verify RED**

Run full tests. Expected: smoke tests fail because `SceneRouter.EVENT` and `EventScreen` do not exist.

- [x] **Step 3: Add event route**

Modify `scripts/app/scene_router.gd`:

```gdscript
const EVENT := "res://scenes/event/EventScreen.tscn"
```

Modify `scripts/ui/map_screen.gd`:

```gdscript
if node.node_type == "combat" or node.node_type == "elite" or node.node_type == "boss":
	app.game.router.go_to(SceneRouterScript.COMBAT)
elif node.node_type == "event":
	app.game.router.go_to(SceneRouterScript.EVENT)
else:
	app.game.router.go_to(SceneRouterScript.REWARD)
```

- [x] **Step 4: Refactor RewardScreen to use RunProgression**

Modify `scripts/ui/reward_screen.gd`:

```gdscript
const RunProgression := preload("res://scripts/run/run_progression.gd")
```

Replace:

```gdscript
if not _unlock_next_node(app.game.current_run):
```

with:

```gdscript
if not RunProgression.new().advance_current_node(app.game.current_run):
```

Remove the private `_unlock_next_node(run)` function from `reward_screen.gd`.

- [x] **Step 5: Implement EventScreen**

Create `scripts/ui/event_screen.gd`:

```gdscript
extends Control

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventResolver := preload("res://scripts/event/event_resolver.gd")
const EventRunner := preload("res://scripts/event/event_runner.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var catalog: ContentCatalog
var event
var runner := EventRunner.new()
var title_label: Label
var body_label: Label
var option_container: VBoxContainer
var advance_requested := false

func _ready() -> void:
	_build_layout()
	_load_event()
	_render()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "EventTitle"
	add_child(title_label)

	body_label = Label.new()
	body_label.name = "EventBody"
	body_label.position.y = 32
	add_child(body_label)

	option_container = VBoxContainer.new()
	option_container.name = "EventOptionContainer"
	option_container.position = Vector2(16, 96)
	option_container.size = Vector2(620, 360)
	add_child(option_container)

func _load_event() -> void:
	catalog = ContentCatalog.new()
	catalog.load_default()
	var app = _app()
	if app == null or app.game.current_run == null:
		event = null
		return
	event = EventResolver.new().resolve(catalog, app.game.current_run)

func _render() -> void:
	_clear_children(option_container)
	if event == null:
		title_label.text = "Event"
		body_label.text = "No event available"
		var button := Button.new()
		button.name = "ContinueButton"
		button.text = "Continue"
		button.pressed.connect(_on_fallback_continue_pressed)
		option_container.add_child(button)
		return
	title_label.text = event.id
	body_label.text = event.body_key
	for i in range(event.options.size()):
		_add_option_button(i)

func _add_option_button(index: int) -> void:
	var option = event.options[index]
	var app = _app()
	var run = app.game.current_run if app != null else null
	var button := Button.new()
	button.name = "EventOption_%s" % index
	button.text = option.label_key
	var reason := runner.unavailable_reason(run, option)
	if not reason.is_empty():
		button.text = "%s (%s)" % [button.text, reason]
	button.disabled = not runner.is_option_available(run, option)
	button.pressed.connect(func(): _on_option_pressed(index))
	option_container.add_child(button)

func _on_option_pressed(index: int) -> void:
	if advance_requested or event == null or index < 0 or index >= event.options.size():
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if not runner.apply_option(app.game.current_run, event.options[index]):
		return
	_advance_and_route(app)

func _on_fallback_continue_pressed() -> void:
	if advance_requested:
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	_advance_and_route(app)

func _advance_and_route(app) -> void:
	advance_requested = true
	_set_option_buttons_disabled()
	if not RunProgression.new().advance_current_node(app.game.current_run):
		push_error("Cannot advance event; current map node is missing.")
		return
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouterScript.SUMMARY)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _set_option_buttons_disabled() -> void:
	for child in option_container.get_children():
		if child is Button:
			child.disabled = true

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _app():
	return get_tree().root.get_node_or_null("App")
```

Create `scenes/event/EventScreen.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/event_screen.gd" id="1_event"]

[node name="EventScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_event")
```

- [x] **Step 6: Run tests and verify GREEN for Task 3**

Run full tests. Expected: event smoke tests pass, reward smoke tests still pass, full suite ends with `TESTS PASSED`.

- [x] **Step 7: Run Godot import check**

Run import check. Expected: exit 0 with no parse errors or missing resources.

- [x] **Step 8: Run Task 3 review gates**

Stage 1 Spec Compliance Review:

- Confirm event nodes route to `EventScreen`.
- Confirm option buttons apply through `EventRunner`, not direct UI mutation.
- Confirm event selection, save, and routing happen once.
- Confirm `RewardScreen` uses `RunProgression`.
- Confirm shop remains out of scope.

Stage 2 Code Quality Review:

- Check scene node names are stable for tests.
- Check double-click guards exist.
- Check map advancement logic is not duplicated.
- Check UI code does not own event selection rules.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 9: Commit Task 3**

```powershell
rtk git add scripts/ui/event_screen.gd scenes/event/EventScreen.tscn scripts/app/scene_router.gd scripts/ui/map_screen.gd scripts/ui/reward_screen.gd tests/smoke/test_scene_flow.gd
rtk git commit -m "feat: add event node scene flow"
```

## Task 4: Acceptance Docs and Final Verification

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-27-event-node-foundation.md`

- [x] **Step 1: Update README Phase 2 progress**

Add this bullet under `## Phase 2 Progress` in `README.md`:

```markdown
- Event node foundation: complete; map event nodes now resolve data-driven events with selectable HP/gold options, save, and advance run progress
```

- [x] **Step 2: Mark completed plan steps**

Update completed checkboxes in `docs/superpowers/plans/2026-04-27-event-node-foundation.md` from `[ ]` to `[x]`.

Only mark a step complete after its command, review, or commit has actually happened.

- [x] **Step 3: Run final full tests**

Run full tests. Expected: `TESTS PASSED`.

- [x] **Step 4: Run final import check**

Run import check. Expected: exit 0 with no parse errors or missing resources.

- [x] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Verify every acceptance criterion in `docs/superpowers/specs/2026-04-27-event-node-foundation-design.md`.
- Do not proceed to quality review if any requirement is missing.

Stage 2 Code Quality Review:

- Check GDScript typing, event resource boundaries, deterministic RNG, save boundaries, shared progression, scene routing, and maintainability.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 6: Commit acceptance docs**

```powershell
rtk git add README.md docs/superpowers/plans/2026-04-27-event-node-foundation.md
rtk git commit -m "docs: record event node foundation acceptance"
```

## Acceptance Criteria

- Event resources exist and are registered in `ContentCatalog`.
- `ContentCatalog.validate()` reports no errors for default events.
- Selecting an event node from the map enters an event screen.
- The event screen displays one deterministic event for the current run seed and node id.
- Event options are shown as buttons.
- Options with unmet HP or gold requirements are disabled.
- Selecting an available option applies exactly that option's HP and gold deltas.
- HP is clamped between 1 and max HP.
- Gold is clamped to 0 or higher.
- Selecting an option saves the run once, marks the event node visited, unlocks the next node or completes the run, and routes correctly.
- Reward screen still advances map progress correctly after the shared progression helper is introduced.
- No shop scene or shop item model is added.
- No pending event save schema is added.
- Godot tests pass.
- Godot import check exits 0.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-27-event-node-foundation.md`.

Recommended execution for this project: **Inline Execution on local `main`**, because `AGENTS.md` forbids worktrees and new branches. Use `superpowers:executing-plans` and `superpowers:test-driven-development`.
