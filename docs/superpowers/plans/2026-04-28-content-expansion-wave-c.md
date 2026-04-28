# Content Expansion Wave C Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Content Expansion Wave C: event rewards, pending event reward save/resume, enemy status intents, compact status display, and expanded event/enemy/relic pools.

**Architecture:** Extend the current resource-driven systems instead of replacing them. `EventRunner` owns event option mutations and pending reward creation, `RewardResolver`/`RewardScreen` reuse the existing claim loop, `CombatSession` keeps deterministic enemy intent strings, and `CombatStatusRuntime` remains the only home for gameplay status rules.

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

and no unrelated staged or unstaged changes.

Project rules:

- Do not create or use git worktrees.
- Do not create or switch branches.
- Prefix shell commands with `rtk`.
- Use TDD for behavior changes: write failing tests, verify RED, implement, verify GREEN.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`.

## Scope Check

This plan implements `docs/superpowers/specs/2026-04-28-content-expansion-wave-c-design.md`.

Included:

- Event option direct card grants, relic grants, card removal, generated card choices, and generated relic choices.
- `RunState.current_reward_state` save/load support for pending event rewards.
- Pending event rewards through existing `RewardResolver` and `RewardScreen`.
- Enemy status intent strings for applying statuses to the player or acting enemy.
- Compact status display text using known status name keys.
- 6 new event resources, 8 new relic resources, 4 new enemy resources.
- Catalog registration, localization, tests, README, and plan status updates.

Excluded:

- No worktrees or feature branches.
- No full `StatusDef` database.
- No rich tooltip/icon/animation/audio/VFX presentation.
- No shop, map generator, combat reward redesign, CI, export, or release work.

## File Structure

Create:

- `resources/events/forgotten_armory.tres`
- `resources/events/jade_debt_collector.tres`
- `resources/events/moonlit_ferry.tres`
- `resources/events/spirit_compact.tres`
- `resources/events/tea_house_rumor.tres`
- `resources/events/withered_master.tres`
- `resources/enemies/plague_jade_imp.tres`
- `resources/enemies/iron_oath_duelist.tres`
- `resources/enemies/miasma_cauldron_elder.tres`
- `resources/enemies/boss_sword_ghost.tres`
- `resources/relics/paper_lantern_charm.tres`
- `resources/relics/mothwing_sachet.tres`
- `resources/relics/rusted_meridian_ring.tres`
- `resources/relics/silk_thread_prayer.tres`
- `resources/relics/black_pill_vial.tres`
- `resources/relics/cloudstep_sandals.tres`
- `resources/relics/immortal_peach_core.tres`
- `resources/relics/void_tiger_eye.tres`

Modify:

- `scripts/data/event_option_def.gd`: add optional reward/mutation fields.
- `scripts/run/run_state.gd`: add `current_reward_state`.
- `scripts/save/save_service.gd`: validate and load pending reward state.
- `scripts/event/event_runner.gd`: apply extended event option rewards.
- `scripts/ui/event_screen.gd`: route pending event rewards to reward screen.
- `scripts/reward/reward_resolver.gd`: resolve pending event reward packages first.
- `scripts/ui/reward_screen.gd`: clear pending event reward state on continue.
- `scripts/combat/combat_session.gd`: parse and execute status intents.
- `scripts/combat/combat_status_runtime.gd`: add status display text.
- `scripts/ui/combat_screen.gd`: use compact display status text.
- `scripts/content/content_catalog.gd`: register new resources and validate reward references.
- `tests/unit/test_event_runner.gd`: event option reward tests.
- `tests/unit/test_run_state.gd`: pending reward serialization test.
- `tests/unit/test_save_service.gd`: pending reward save/load validation tests.
- `tests/unit/test_reward_resolver.gd`: pending event reward resolver tests.
- `tests/unit/test_combat_session.gd`: status intent tests.
- `tests/unit/test_combat_status_runtime.gd`: display text tests.
- `tests/unit/test_content_catalog.gd`: Wave C counts and validation tests.
- `tests/unit/test_reward_generator.gd`: populated expanded relic tier tests.
- `tests/unit/test_encounter_generator.gd`: Wave C enemy tier composition tests.
- `tests/unit/test_event_resolver.gd`: expanded event pool usability tests.
- `tests/smoke/test_scene_flow.gd`: pending event reward screen flow smoke test.
- `localization/zh_CN.po`: new localization keys.
- `README.md`: record Wave C completion after acceptance.
- `docs/superpowers/plans/2026-04-28-content-expansion-wave-c.md`: mark steps complete during execution.

## Task 1: Pending Reward State Schema and Save Compatibility

**Files:**

- Modify: `scripts/run/run_state.gd`
- Modify: `scripts/save/save_service.gd`
- Modify: `tests/unit/test_run_state.gd`
- Modify: `tests/unit/test_save_service.gd`

- [x] **Step 1: Add failing RunState pending reward serialization test**

Append this test to `tests/unit/test_run_state.gd`:

```gdscript
func test_to_dict_serializes_current_reward_state_without_aliasing() -> bool:
	var run := RunState.new()
	run.current_reward_state = {
		"source": "event",
		"node_id": "node_event",
		"event_id": "forgotten_armory",
		"option_id": "choose_blade",
		"rewards": [
			{
				"id": "event-card:node_event:choose_blade",
				"type": "card_choice",
				"card_ids": ["sword.flash_cut", "sword.heart_piercer"],
			},
		],
	}
	var payload := run.to_dict()
	var reward_state: Dictionary = payload.get("current_reward_state", {})
	var rewards: Array = reward_state.get("rewards", [])
	(rewards[0] as Dictionary)["card_ids"].append("sword.strike")
	var passed: bool = reward_state.get("source") == "event" \
		and reward_state.get("node_id") == "node_event" \
		and run.current_reward_state["rewards"][0]["card_ids"].size() == 2
	assert(passed)
	return passed
```

- [x] **Step 2: Add failing SaveService pending reward tests**

Append these tests to `tests/unit/test_save_service.gd` before helper functions:

```gdscript
func test_save_round_trip_preserves_current_reward_state() -> bool:
	var save_path := "user://test_reward_state_save.json"
	_delete_test_save(save_path)
	var run := RunState.new()
	run.current_reward_state = {
		"source": "event",
		"node_id": "node_event",
		"event_id": "forgotten_armory",
		"option_id": "choose_blade",
		"rewards": [
			{
				"id": "event-card:node_event:choose_blade",
				"type": "card_choice",
				"card_ids": ["sword.flash_cut", "sword.heart_piercer"],
			},
			{
				"id": "event-relic:node_event:choose_blade",
				"type": "relic",
				"relic_id": "paper_lantern_charm",
				"tier": "common",
			},
		],
	}
	var service := SaveService.new(save_path)
	service.save_run(run)

	var loaded := service.load_run()
	var reward_state: Dictionary = loaded.current_reward_state if loaded != null else {}
	var rewards: Array = reward_state.get("rewards", [])
	var passed: bool = loaded != null \
		and reward_state.get("source") == "event" \
		and reward_state.get("node_id") == "node_event" \
		and rewards.size() == 2 \
		and (rewards[0] as Dictionary).get("type") == "card_choice" \
		and ((rewards[0] as Dictionary).get("card_ids", []) as Array).size() == 2 \
		and (rewards[1] as Dictionary).get("relic_id") == "paper_lantern_charm"
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_accepts_legacy_save_without_reward_state() -> bool:
	var save_path := "user://test_legacy_without_reward_state.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, JSON.stringify({
		"version": 1,
		"seed_value": 42,
		"character_id": "sword",
		"current_hp": 55,
		"max_hp": 72,
		"gold": 99,
		"deck_ids": [],
		"relic_ids": [],
		"map_nodes": [],
		"current_node_id": "",
		"completed": false,
		"failed": false,
	})):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var loaded := service.load_run()
	var passed: bool = loaded != null and loaded.current_reward_state.is_empty()
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_returns_null_for_invalid_reward_state_type() -> bool:
	var save_path := "user://test_invalid_reward_state_type.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, JSON.stringify({
		"version": 1,
		"seed_value": 42,
		"character_id": "sword",
		"current_hp": 55,
		"max_hp": 72,
		"gold": 99,
		"deck_ids": [],
		"relic_ids": [],
		"map_nodes": [],
		"current_node_id": "",
		"completed": false,
		"failed": false,
		"current_reward_state": "bad",
	})):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var passed: bool = service.load_run() == null
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_returns_null_for_invalid_reward_state_rewards_type() -> bool:
	var save_path := "user://test_invalid_reward_state_rewards_type.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, JSON.stringify({
		"version": 1,
		"seed_value": 42,
		"character_id": "sword",
		"current_hp": 55,
		"max_hp": 72,
		"gold": 99,
		"deck_ids": [],
		"relic_ids": [],
		"map_nodes": [],
		"current_node_id": "",
		"completed": false,
		"failed": false,
		"current_reward_state": {
			"source": "event",
			"node_id": "node_event",
			"event_id": "forgotten_armory",
			"option_id": "choose_blade",
			"rewards": "bad",
		},
	})):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var passed: bool = service.load_run() == null
	assert(passed)
	service.delete_save()
	return passed
```

- [x] **Step 3: Run tests and verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures mentioning missing `current_reward_state`.

- [x] **Step 4: Implement RunState reward state serialization**

Modify `scripts/run/run_state.gd`:

```gdscript
var current_reward_state: Dictionary = {}
```

Add it after `current_shop_state`, then update `to_dict()`:

```gdscript
		"current_shop_state": current_shop_state.duplicate(true),
		"current_reward_state": current_reward_state.duplicate(true),
		"completed": completed,
```

- [x] **Step 5: Implement SaveService reward state validation and loading**

In `scripts/save/save_service.gd`, after loading `current_shop_state`, add:

```gdscript
	var reward_state: Dictionary = payload.get("current_reward_state", {})
	run.current_reward_state = reward_state.duplicate(true)
```

In `_is_valid_run_payload()`, add the optional reward state check after `current_shop_state`:

```gdscript
		and _has_optional_dictionary(payload, "current_shop_state") \
		and _has_optional_reward_state(payload, "current_reward_state") \
		and _has_bool(payload, "completed") \
```

Add these helper functions after `_has_optional_dictionary()`:

```gdscript
func _has_optional_reward_state(payload: Dictionary, key: String) -> bool:
	if not payload.has(key):
		return true
	if not payload[key] is Dictionary:
		return false
	var reward_state: Dictionary = payload[key]
	if reward_state.is_empty():
		return true
	return _has_string(reward_state, "source") \
		and _has_string(reward_state, "node_id") \
		and _has_string(reward_state, "event_id") \
		and _has_string(reward_state, "option_id") \
		and _has_valid_reward_list(reward_state, "rewards")

func _has_valid_reward_list(payload: Dictionary, key: String) -> bool:
	if not payload.has(key) or not payload[key] is Array:
		return false
	for reward in payload[key]:
		if not reward is Dictionary:
			return false
		var reward_payload: Dictionary = reward
		if not _has_string(reward_payload, "id") or not _has_string(reward_payload, "type"):
			return false
		match String(reward_payload["type"]):
			"card_choice":
				if not _has_string_array(reward_payload, "card_ids"):
					return false
			"gold":
				if not _has_int(reward_payload, "amount"):
					return false
			"relic":
				if not _has_string(reward_payload, "relic_id"):
					return false
			_:
				return false
	return true
```

- [x] **Step 6: Run tests and verify GREEN for Task 1**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [x] **Step 7: Run Task 1 review gates**

Stage 1 Spec Compliance Review:

- `RunState.current_reward_state` exists and serializes without aliasing.
- `SaveService` accepts legacy saves without reward state.
- `SaveService` rejects malformed reward state types and malformed reward lists.
- `current_shop_state` behavior remains unchanged.

Stage 2 Code Quality Review:

- Reward state validation is narrow and only validates existing reward shapes.
- Dictionary duplication uses `duplicate(true)`.
- No save version bump is added.

- [x] **Step 8: Commit Task 1**

Run:

```powershell
rtk proxy git add scripts/run/run_state.gd scripts/save/save_service.gd tests/unit/test_run_state.gd tests/unit/test_save_service.gd
rtk proxy git commit -m "feat: save pending event reward state"
```

## Task 2: Event Option Rewards and Pending Reward Creation

**Files:**

- Modify: `scripts/data/event_option_def.gd`
- Modify: `scripts/event/event_runner.gd`
- Modify: `scripts/ui/event_screen.gd`
- Modify: `tests/unit/test_event_runner.gd`

- [ ] **Step 1: Add failing EventRunner reward tests**

Append these tests to `tests/unit/test_event_runner.gd`:

```gdscript
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventDef := preload("res://scripts/data/event_def.gd")

func test_runner_grants_direct_cards_and_relics() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	var option := _option(0, 0, 0, 0)
	option.grant_card_ids = ["sword.flash_cut"]
	option.grant_relic_ids = ["jade_talisman"]
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("test_event", option), option)
	var passed: bool = applied \
		and run.deck_ids.has("sword.flash_cut") \
		and run.relic_ids == ["jade_talisman"] \
		and run.current_reward_state.is_empty()
	assert(passed)
	return passed

func test_runner_rejects_duplicate_direct_relic_without_duplicate() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.relic_ids = ["jade_talisman"]
	var option := _option(0, 0, 0, 0)
	option.grant_relic_ids = ["jade_talisman"]
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("test_event", option), option)
	var passed: bool = applied and run.relic_ids == ["jade_talisman"]
	assert(passed)
	return passed

func test_runner_remove_card_option_requires_card_and_removes_one_copy() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.deck_ids = ["sword.strike", "sword.strike", "sword.guard"]
	var option := _option(0, 0, 0, 0)
	option.remove_card_id = "sword.strike"
	var runner := EventRunner.new()
	var available_before := runner.is_option_available(run, option)
	var applied := runner.apply_event_option(catalog, run, _event("test_event", option), option)
	var passed: bool = available_before \
		and applied \
		and run.deck_ids == ["sword.strike", "sword.guard"]
	assert(passed)
	return passed

func test_runner_remove_card_option_unavailable_when_card_missing() -> bool:
	var run := _run(20, 40, 10)
	run.deck_ids = ["sword.guard"]
	var option := _option(0, 0, 0, 0)
	option.remove_card_id = "sword.strike"
	var runner := EventRunner.new()
	var available := runner.is_option_available(run, option)
	var reason := runner.unavailable_reason(run, option)
	var applied := runner.apply_event_option(_catalog(), run, _event("test_event", option), option)
	var passed: bool = not available \
		and not applied \
		and reason.contains("Requires card") \
		and run.deck_ids == ["sword.guard"]
	assert(passed)
	return passed

func test_runner_creates_deterministic_card_reward_state() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.seed_value = 777
	run.character_id = "sword"
	run.current_node_id = "node_event"
	var option := _option(0, 0, -3, 0)
	option.id = "train"
	option.card_reward_count = 2
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("forgotten_armory", option), option)
	var rewards: Array = run.current_reward_state.get("rewards", [])
	var first_reward: Dictionary = rewards[0] if rewards.size() > 0 else {}
	var card_ids: Array = first_reward.get("card_ids", [])
	var passed: bool = applied \
		and run.current_hp == 17 \
		and run.current_reward_state.get("source") == "event" \
		and run.current_reward_state.get("node_id") == "node_event" \
		and first_reward.get("type") == "card_choice" \
		and card_ids.size() == 2
	assert(passed)
	return passed

func test_runner_creates_deterministic_relic_reward_state() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.seed_value = 778
	run.current_node_id = "node_event"
	var option := _option(0, 0, 0, 0)
	option.id = "claim"
	option.relic_reward_tier = "common"
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("moonlit_ferry", option), option)
	var rewards: Array = run.current_reward_state.get("rewards", [])
	var first_reward: Dictionary = rewards[0] if rewards.size() > 0 else {}
	var passed: bool = applied \
		and first_reward.get("type") == "relic" \
		and first_reward.get("tier") == "common" \
		and not String(first_reward.get("relic_id", "")).is_empty()
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _event(event_id: String, option: EventOptionDef) -> EventDef:
	var event := EventDef.new()
	event.id = event_id
	event.options = [option]
	return event
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures for missing `grant_card_ids`, `grant_relic_ids`, `remove_card_id`, `card_reward_count`, `relic_reward_tier`, `apply_event_option`.

- [ ] **Step 3: Extend EventOptionDef**

Modify `scripts/data/event_option_def.gd`:

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
@export var grant_card_ids: Array[String] = []
@export var grant_relic_ids: Array[String] = []
@export var remove_card_id: String = ""
@export var card_reward_count: int = 0
@export var relic_reward_tier: String = ""
@export var reward_context: String = ""
```

- [ ] **Step 4: Extend EventRunner with catalog-aware event option application**

Replace `scripts/event/event_runner.gd` with:

```gdscript
class_name EventRunner
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventDef := preload("res://scripts/data/event_def.gd")
const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const RewardGenerator := preload("res://scripts/reward/reward_generator.gd")
const RunState := preload("res://scripts/run/run_state.gd")

var reward_generator := RewardGenerator.new()

func is_option_available(run: RunState, option: EventOptionDef) -> bool:
	if run == null or option == null:
		return false
	if run.current_hp < option.min_hp or run.gold < option.min_gold:
		return false
	if not option.remove_card_id.is_empty() and not run.deck_ids.has(option.remove_card_id):
		return false
	return true

func unavailable_reason(run: RunState, option: EventOptionDef) -> String:
	if run == null or option == null:
		return "Unavailable"
	if run.current_hp < option.min_hp:
		return "Requires %s HP" % option.min_hp
	if run.gold < option.min_gold:
		return "Requires %s gold" % option.min_gold
	if not option.remove_card_id.is_empty() and not run.deck_ids.has(option.remove_card_id):
		return "Requires card %s" % option.remove_card_id
	return ""

func apply_option(run: RunState, option: EventOptionDef) -> bool:
	if not is_option_available(run, option):
		return false
	_apply_hp_gold(run, option)
	return true

func apply_event_option(catalog: ContentCatalog, run: RunState, event: EventDef, option: EventOptionDef) -> bool:
	if catalog == null or event == null or not is_option_available(run, option):
		return false
	_apply_hp_gold(run, option)
	_apply_remove_card(run, option)
	_apply_direct_grants(catalog, run, option)
	var rewards := _build_pending_rewards(catalog, run, event, option)
	if not rewards.is_empty():
		run.current_reward_state = {
			"source": "event",
			"node_id": run.current_node_id,
			"event_id": event.id,
			"option_id": option.id,
			"rewards": rewards,
		}
	return true

func _apply_hp_gold(run: RunState, option: EventOptionDef) -> void:
	run.current_hp = clamp(run.current_hp + option.hp_delta, 1, run.max_hp)
	run.gold = max(0, run.gold + option.gold_delta)

func _apply_remove_card(run: RunState, option: EventOptionDef) -> void:
	if option.remove_card_id.is_empty():
		return
	var index := run.deck_ids.find(option.remove_card_id)
	if index >= 0:
		run.deck_ids.remove_at(index)

func _apply_direct_grants(catalog: ContentCatalog, run: RunState, option: EventOptionDef) -> void:
	for card_id in option.grant_card_ids:
		if catalog.get_card(card_id) != null:
			run.deck_ids.append(card_id)
	for relic_id in option.grant_relic_ids:
		if catalog.get_relic(relic_id) != null and not run.relic_ids.has(relic_id):
			run.relic_ids.append(relic_id)

func _build_pending_rewards(
	catalog: ContentCatalog,
	run: RunState,
	event: EventDef,
	option: EventOptionDef
) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var context := _reward_context(run, event, option)
	if option.card_reward_count > 0:
		var card_reward := reward_generator.generate_card_reward(
			catalog,
			run.seed_value,
			run.character_id,
			context,
			option.card_reward_count
		)
		var card_ids: Array = card_reward.get("card_ids", [])
		if not card_ids.is_empty():
			rewards.append({
				"id": "event-card:%s:%s" % [run.current_node_id, option.id],
				"type": "card_choice",
				"card_ids": card_ids,
			})
	if not option.relic_reward_tier.is_empty():
		var relic_reward := reward_generator.generate_relic_reward(
			catalog,
			run.seed_value,
			context,
			option.relic_reward_tier
		)
		var relic_id := String(relic_reward.get("relic_id", ""))
		if not relic_id.is_empty():
			rewards.append({
				"id": "event-relic:%s:%s" % [run.current_node_id, option.id],
				"type": "relic",
				"relic_id": relic_id,
				"tier": option.relic_reward_tier,
			})
	return rewards

func _reward_context(run: RunState, event: EventDef, option: EventOptionDef) -> String:
	if not option.reward_context.is_empty():
		return option.reward_context
	return "%s:%s:%s" % [run.current_node_id, event.id, option.id]
```

- [ ] **Step 5: Route EventScreen pending rewards to RewardScreen**

In `scripts/ui/event_screen.gd`, change `_on_option_pressed()`:

```gdscript
	if not runner.apply_event_option(catalog, app.game.current_run, current_event, current_event.options[index]):
		return
	if not app.game.current_run.current_reward_state.is_empty():
		_save_and_route_to_reward(app)
	else:
		_advance_and_route(app)
```

Add this helper before `_advance_and_route()`:

```gdscript
func _save_and_route_to_reward(app) -> void:
	advance_requested = true
	_set_option_buttons_disabled()
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	app.game.router.go_to(SceneRouterScript.REWARD)
```

- [ ] **Step 6: Run tests and verify GREEN for Task 2**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 7: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- Event options support direct card grants, relic grants, one-card removal, card reward choices, and relic reward choices.
- Direct grants do not create pending reward state.
- Pending reward options save reward dictionaries in `run.current_reward_state`.
- EventScreen routes pending rewards to `SceneRouterScript.REWARD` without advancing the event node.

Stage 2 Code Quality Review:

- Existing `apply_option(run, option)` remains compatible with old tests.
- `EventRunner` owns event option mutation and reward package creation.
- Direct relic grants reject duplicates.
- No reward UI logic is added to `EventRunner`.

- [ ] **Step 8: Commit Task 2**

Run:

```powershell
rtk proxy git add scripts/data/event_option_def.gd scripts/event/event_runner.gd scripts/ui/event_screen.gd tests/unit/test_event_runner.gd
rtk proxy git commit -m "feat: add event option rewards"
```

## Task 3: Pending Event Rewards Through Reward Resolver and Screen

**Files:**

- Modify: `scripts/reward/reward_resolver.gd`
- Modify: `scripts/ui/reward_screen.gd`
- Modify: `tests/unit/test_reward_resolver.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [ ] **Step 1: Add failing RewardResolver pending event reward tests**

Append these tests to `tests/unit/test_reward_resolver.gd`:

```gdscript
func test_pending_event_reward_state_is_returned_for_current_event_node() -> bool:
	var run := _run_for_node("event", 777)
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
	var rewards := RewardResolver.new().resolve(_catalog(), run)
	var card := _find_reward(rewards, "card_choice")
	var passed: bool = rewards.size() == 1 \
		and card.get("id") == "event-card:node_0:train" \
		and _array_value_count(card.get("card_ids", [])) == 2
	assert(passed)
	return passed

func test_pending_event_reward_state_ignored_for_different_node() -> bool:
	var run := _run_for_node("event", 777)
	run.current_reward_state = {
		"source": "event",
		"node_id": "other_node",
		"event_id": "forgotten_armory",
		"option_id": "train",
		"rewards": [
			{
				"id": "event-card:other_node:train",
				"type": "card_choice",
				"card_ids": ["sword.flash_cut"],
			},
		],
	}
	var rewards := RewardResolver.new().resolve(_catalog(), run)
	var passed: bool = rewards.is_empty()
	assert(passed)
	return passed
```

- [ ] **Step 2: Add failing smoke test for event reward screen flow**

Append this test to `tests/smoke/test_scene_flow.gd` after event screen tests:

```gdscript
func test_reward_screen_claims_pending_event_reward_then_advances_event(tree: SceneTree) -> bool:
	var save_path := "user://test_event_reward_screen_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
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
	app.game.current_run = run

	var reward_screen = app.game.router.go_to(SceneRouterScript.REWARD)
	var claim_card := _find_node_by_name(reward_screen, "ClaimCard_0_0") as Button
	if claim_card != null:
		claim_card.pressed.emit()
	var continue_button := _find_node_by_name(reward_screen, "ContinueButton") as Button
	if continue_button != null:
		continue_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = claim_card != null \
		and continue_button != null \
		and loaded_run != null \
		and loaded_run.current_reward_state.is_empty() \
		and loaded_run.deck_ids.has("sword.flash_cut") \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != reward_screen
	app.free()
	_delete_test_save(save_path)
	return passed
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: pending event reward resolver/smoke tests fail because reward resolver ignores `current_reward_state` and reward screen does not clear it.

- [ ] **Step 4: Implement pending event reward path in RewardResolver**

In `scripts/reward/reward_resolver.gd`, inside `resolve()` after current node lookup and before the node type match:

```gdscript
	var pending_rewards := _pending_event_rewards(run, node)
	if not pending_rewards.is_empty():
		return pending_rewards
```

Add this helper before `_current_node()`:

```gdscript
func _pending_event_rewards(run: RunState, node: MapNodeState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var reward_state := run.current_reward_state
	if reward_state.is_empty():
		return result
	if String(reward_state.get("source", "")) != "event":
		return result
	if String(reward_state.get("node_id", "")) != node.id:
		return result
	var rewards: Array = reward_state.get("rewards", [])
	for reward in rewards:
		if reward is Dictionary:
			result.append((reward as Dictionary).duplicate(true))
	return result
```

- [ ] **Step 5: Clear pending event reward state in RewardScreen on continue**

In `scripts/ui/reward_screen.gd`, add this helper:

```gdscript
func _has_pending_event_rewards(run) -> bool:
	return run != null \
		and not run.current_reward_state.is_empty() \
		and String(run.current_reward_state.get("source", "")) == "event"
```

In `_on_continue_pressed()`, before `RunProgression.new().advance_current_node(...)`, add:

```gdscript
	var clear_event_reward_state := _has_pending_event_rewards(app.game.current_run)
	if clear_event_reward_state:
		app.game.current_run.current_reward_state.clear()
```

The surrounding block should become:

```gdscript
	advance_requested = true
	if continue_button != null:
		continue_button.disabled = true
	var clear_event_reward_state := _has_pending_event_rewards(app.game.current_run)
	if clear_event_reward_state:
		app.game.current_run.current_reward_state.clear()
	if not RunProgression.new().advance_current_node(app.game.current_run):
		push_error("Cannot advance run; current map node is missing.")
		return
```

- [ ] **Step 6: Run tests and verify GREEN for Task 3**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 7: Run Task 3 review gates**

Stage 1 Spec Compliance Review:

- Pending event rewards resolve before node-type reward generation.
- Pending event rewards only resolve for the current event node.
- RewardScreen uses the existing claim/skip mechanics for event rewards.
- Continuing after pending event rewards clears `current_reward_state`, advances through `RunProgression`, saves, and routes correctly.
- Combat reward behavior is unchanged.

Stage 2 Code Quality Review:

- Reward dictionaries are duplicated before returning from resolver.
- RewardScreen branching is limited to clearing pending state.
- No separate event reward screen is added.

- [ ] **Step 8: Commit Task 3**

Run:

```powershell
rtk proxy git add scripts/reward/reward_resolver.gd scripts/ui/reward_screen.gd tests/unit/test_reward_resolver.gd tests/smoke/test_scene_flow.gd
rtk proxy git commit -m "feat: route event rewards through reward screen"
```

## Task 4: Enemy Status Intents

**Files:**

- Modify: `scripts/combat/combat_session.gd`
- Modify: `tests/unit/test_combat_session.gd`

- [ ] **Step 1: Add failing enemy status intent tests**

Append these tests to `tests/unit/test_combat_session.gd` before helper functions:

```gdscript
func test_enemy_intent_applies_status_to_player() -> bool:
	var catalog := _catalog_with_single_enemy_intent("test_status_enemy", "normal", ["apply_status_poison_2_player"])
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session._execute_enemy_intent(0)
	var passed: bool = session.state.player.statuses.get("poison", 0) == 2 \
		and session.enemy_intent_indices[0] == 1
	assert(passed)
	return passed

func test_enemy_intent_applies_broken_stance_to_player() -> bool:
	var catalog := _catalog_with_single_enemy_intent("test_status_enemy", "normal", ["apply_status_broken_stance_1_player"])
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session._execute_enemy_intent(0)
	var passed: bool = session.state.player.statuses.get("broken_stance", 0) == 1 \
		and session.enemy_intent_indices[0] == 1
	assert(passed)
	return passed

func test_enemy_self_status_intent_applies_status_to_acting_enemy() -> bool:
	var catalog := _catalog_with_single_enemy_intent("test_focus_enemy", "normal", ["self_status_sword_focus_1"])
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session._execute_enemy_intent(0)
	var passed: bool = session.state.enemies[0].statuses.get("sword_focus", 0) == 1 \
		and session.enemy_intent_indices[0] == 1
	assert(passed)
	return passed

func test_malformed_status_intent_advances_without_mutation() -> bool:
	var catalog := _catalog_with_single_enemy_intent("test_bad_status_enemy", "normal", ["apply_status_poison_player"])
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session._execute_enemy_intent(0)
	var passed: bool = session.state.player.statuses.is_empty() \
		and session.state.enemies[0].statuses.is_empty() \
		and session.enemy_intent_indices[0] == 1
	assert(passed)
	return passed

func _catalog_with_single_enemy_intent(enemy_id: String, tier: String, intents: Array[String]) -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var enemy := _enemy(enemy_id, tier, 30, intents)
	catalog.enemies_by_id[enemy.id] = enemy
	return catalog
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: enemy status intent tests fail because current parser only supports two-part intent strings.

- [ ] **Step 3: Implement status intent parsing and execution**

In `scripts/combat/combat_session.gd`, add:

```gdscript
const EffectDef := preload("res://scripts/data/effect_def.gd")
```

Replace `_execute_enemy_intent()` with:

```gdscript
func _execute_enemy_intent(enemy_index: int) -> void:
	var enemy: CombatantState = state.enemies[enemy_index]
	var intent := get_enemy_intent(enemy_index)
	if intent.is_empty():
		_advance_enemy_intent(enemy_index)
		return
	if intent.begins_with("apply_status_"):
		_execute_status_intent(enemy, enemy_index, intent.trim_prefix("apply_status_"), state.player)
		return
	if intent.begins_with("self_status_"):
		_execute_status_intent(enemy, enemy_index, intent.trim_prefix("self_status_"), enemy)
		return
	var parts := intent.split("_")
	if parts.size() != 2:
		push_error("Unknown enemy intent format: %s" % intent)
		_advance_enemy_intent(enemy_index)
		return
	var amount: int = max(0, int(parts[1]))
	match String(parts[0]).to_lower():
		"attack":
			state.player.take_damage(amount)
		"block":
			enemy.gain_block(amount)
		_:
			push_error("Unknown enemy intent action: %s" % intent)
	_advance_enemy_intent(enemy_index)
```

Add these helpers after `_execute_enemy_intent()`:

```gdscript
func _execute_status_intent(
	enemy: CombatantState,
	enemy_index: int,
	payload: String,
	recipient: CombatantState
) -> void:
	var normalized_payload := payload
	if recipient == state.player:
		if not normalized_payload.ends_with("_player"):
			push_error("Unknown enemy status intent target: %s" % payload)
			_advance_enemy_intent(enemy_index)
			return
		normalized_payload = normalized_payload.trim_suffix("_player")
	var parsed := _parse_status_intent_payload(normalized_payload)
	if parsed.is_empty():
		push_error("Unknown enemy status intent format: %s" % payload)
		_advance_enemy_intent(enemy_index)
		return
	var effect := EffectDef.new()
	effect.effect_type = "apply_status"
	effect.status_id = String(parsed.get("status_id", ""))
	effect.amount = int(parsed.get("amount", 0))
	effect.target = "target"
	engine.executor.execute_in_state(effect, state, enemy, recipient)
	_advance_enemy_intent(enemy_index)

func _parse_status_intent_payload(payload: String) -> Dictionary:
	var amount_separator := payload.rfind("_")
	if amount_separator <= 0 or amount_separator >= payload.length() - 1:
		return {}
	var status_id := payload.substr(0, amount_separator)
	var amount_text := payload.substr(amount_separator + 1)
	if status_id.is_empty() or not amount_text.is_valid_int():
		return {}
	var amount := int(amount_text)
	if amount <= 0:
		return {}
	return {
		"status_id": status_id,
		"amount": amount,
	}
```

- [ ] **Step 4: Run tests and verify GREEN for Task 4**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 5: Run Task 4 review gates**

Stage 1 Spec Compliance Review:

- `attack_N` and `block_N` still work.
- `apply_status_<status_id>_<amount>_player` applies generic status stacks to the player.
- `self_status_<status_id>_<amount>` applies generic status stacks to the acting enemy.
- Malformed status intents push an error, do not mutate statuses, and advance the intent index.
- Gameplay status effects remain in `CombatStatusRuntime`.

Stage 2 Code Quality Review:

- Status intent parsing is isolated in helpers.
- Status ids with underscores, such as `broken_stance` and `sword_focus`, parse correctly.
- The implementation reuses `EffectExecutor.execute_in_state()` for generic `apply_status`.

- [ ] **Step 6: Commit Task 4**

Run:

```powershell
rtk proxy git add scripts/combat/combat_session.gd tests/unit/test_combat_session.gd
rtk proxy git commit -m "feat: support enemy status intents"
```

## Task 5: Compact Status Display Text

**Files:**

- Modify: `scripts/combat/combat_status_runtime.gd`
- Modify: `scripts/ui/combat_screen.gd`
- Modify: `tests/unit/test_combat_status_runtime.gd`

- [ ] **Step 1: Add failing status display tests**

Append these tests to `tests/unit/test_combat_status_runtime.gd`:

```gdscript
func test_status_display_text_uses_stable_known_order_and_layers() -> bool:
	var combatant := CombatantState.new("sample", 10)
	combatant.statuses["broken_stance"] = 1
	combatant.statuses["poison"] = 3
	combatant.statuses["sword_focus"] = 2
	var display := CombatStatusRuntime.new().status_display_text(combatant)
	var poison_index := display.find("3")
	var focus_index := display.find("2")
	var broken_index := display.rfind("1")
	var passed: bool = not display.contains("poison:3") \
		and display.contains(" | ") \
		and poison_index >= 0 \
		and focus_index > poison_index \
		and broken_index > focus_index
	assert(passed)
	return passed

func test_status_display_text_lists_unknown_statuses_after_known_statuses() -> bool:
	var combatant := CombatantState.new("sample", 10)
	combatant.statuses["zzz_unknown"] = 4
	combatant.statuses["poison"] = 1
	var display := CombatStatusRuntime.new().status_display_text(combatant)
	var passed: bool = display.find("1") >= 0 \
		and display.find("zzz_unknown 4") > display.find("1")
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: missing `status_display_text`.

- [ ] **Step 3: Implement status display text**

In `scripts/combat/combat_status_runtime.gd`, add:

```gdscript
const STATUS_DISPLAY_ORDER: Array[String] = [
	STATUS_POISON,
	STATUS_SWORD_FOCUS,
	STATUS_BROKEN_STANCE,
]
```

Add this public method after `status_text()`:

```gdscript
func status_display_text(combatant: CombatantState) -> String:
	if combatant == null:
		return ""
	var parts: Array[String] = []
	for status_id in STATUS_DISPLAY_ORDER:
		var layers := _layers(combatant, status_id)
		if layers > 0:
			parts.append("%s %s" % [_status_display_name(status_id), layers])
	var unknown_ids := _unknown_positive_status_ids(combatant)
	for status_id in unknown_ids:
		parts.append("%s %s" % [status_id, _layers(combatant, status_id)])
	return " | ".join(parts)
```

Add these helpers before `_layers()`:

```gdscript
func _status_display_name(status_id: String) -> String:
	var metadata: Dictionary = STATUS_METADATA.get(status_id, {})
	var name_key := String(metadata.get("name_key", status_id))
	var translated := tr(name_key)
	return translated if not translated.is_empty() else status_id

func _unknown_positive_status_ids(combatant: CombatantState) -> Array[String]:
	var result: Array[String] = []
	for key in combatant.statuses.keys():
		var status_id := String(key)
		if STATUS_METADATA.has(status_id):
			continue
		if _layers(combatant, status_id) > 0:
			result.append(status_id)
	result.sort()
	return result
```

- [ ] **Step 4: Use display text in CombatScreen**

In `scripts/ui/combat_screen.gd`, replace both calls to `status_runtime.status_text(...)` with:

```gdscript
session.status_runtime.status_display_text(...)
```

The player block should become:

```gdscript
	var statuses := session.status_runtime.status_display_text(session.state.player)
```

The enemy block should become:

```gdscript
		var statuses := session.status_runtime.status_display_text(enemy)
```

- [ ] **Step 5: Run tests and verify GREEN for Task 5**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 6: Run Task 5 review gates**

Stage 1 Spec Compliance Review:

- `status_text()` remains available for existing tests/backward compatibility.
- `status_display_text()` shows only positive layers.
- Known statuses use metadata order.
- Unknown statuses sort alphabetically after known statuses.
- Combat UI uses display text.

Stage 2 Code Quality Review:

- No gameplay rules move out of `CombatStatusRuntime`.
- Display helpers are small and deterministic.
- UI does not duplicate status ordering rules.

- [ ] **Step 7: Commit Task 5**

Run:

```powershell
rtk proxy git add scripts/combat/combat_status_runtime.gd scripts/ui/combat_screen.gd tests/unit/test_combat_status_runtime.gd
rtk proxy git commit -m "feat: improve compact status display"
```

## Task 6: Wave C Content Resources and Catalog Validation

**Files:**

- Create: resource files listed in File Structure.
- Modify: `scripts/content/content_catalog.gd`
- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `tests/unit/test_reward_generator.gd`
- Modify: `tests/unit/test_encounter_generator.gd`
- Modify: `tests/unit/test_event_resolver.gd`
- Modify: `localization/zh_CN.po`

- [ ] **Step 1: Add failing catalog, reward, encounter, and event tests**

In `tests/unit/test_content_catalog.gd`, rename `test_wave_2_catalog_loads_expanded_enemy_relic_and_event_counts()` to `test_wave_c_catalog_loads_expanded_enemy_relic_and_event_counts()` and update the assertions:

```gdscript
func test_wave_c_catalog_loads_expanded_enemy_relic_and_event_counts() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var elite_ids := _ids(catalog.get_enemies_by_tier("elite"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var common_relic_ids := _ids(catalog.get_relics_by_tier("common"))
	var uncommon_relic_ids := _ids(catalog.get_relics_by_tier("uncommon"))
	var rare_relic_ids := _ids(catalog.get_relics_by_tier("rare"))
	var event_ids := _ids(catalog.get_events())
	var passed: bool = catalog.enemies_by_id.size() == 16 \
		and catalog.relics_by_id.size() == 20 \
		and catalog.events_by_id.size() == 12 \
		and normal_ids.size() == 7 \
		and elite_ids.size() == 5 \
		and boss_ids.size() == 4 \
		and common_relic_ids.size() == 9 \
		and uncommon_relic_ids.size() == 7 \
		and rare_relic_ids.size() == 4 \
		and normal_ids.has("plague_jade_imp") \
		and normal_ids.has("iron_oath_duelist") \
		and elite_ids.has("miasma_cauldron_elder") \
		and boss_ids.has("boss_sword_ghost") \
		and common_relic_ids.has("paper_lantern_charm") \
		and common_relic_ids.has("mothwing_sachet") \
		and common_relic_ids.has("rusted_meridian_ring") \
		and uncommon_relic_ids.has("silk_thread_prayer") \
		and uncommon_relic_ids.has("black_pill_vial") \
		and uncommon_relic_ids.has("cloudstep_sandals") \
		and rare_relic_ids.has("immortal_peach_core") \
		and rare_relic_ids.has("void_tiger_eye") \
		and event_ids.has("forgotten_armory") \
		and event_ids.has("jade_debt_collector") \
		and event_ids.has("moonlit_ferry") \
		and event_ids.has("spirit_compact") \
		and event_ids.has("tea_house_rumor") \
		and event_ids.has("withered_master")
	assert(passed)
	return passed
```

Update `test_default_catalog_loads_event_pool()` to expect 12 events and include all Wave C event ids:

```gdscript
func test_default_catalog_loads_event_pool() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var event_ids := _ids(catalog.get_events())
	var passed: bool = catalog.events_by_id.size() == 12 \
		and event_ids.has("wandering_physician") \
		and event_ids.has("spirit_toll") \
		and event_ids.has("quiet_shrine") \
		and event_ids.has("sealed_sword_tomb") \
		and event_ids.has("alchemist_market") \
		and event_ids.has("spirit_beast_tracks") \
		and event_ids.has("forgotten_armory") \
		and event_ids.has("jade_debt_collector") \
		and event_ids.has("moonlit_ferry") \
		and event_ids.has("spirit_compact") \
		and event_ids.has("tea_house_rumor") \
		and event_ids.has("withered_master") \
		and catalog.get_event("withered_master") != null
	assert(passed)
	return passed
```

Append this validation test:

```gdscript
func test_validation_reports_event_reward_references_missing_catalog_ids() -> bool:
	var catalog := ContentCatalog.new()
	var event := EventDef.new()
	event.id = "bad_rewards"
	event.title_key = "event.bad_rewards.title"
	event.body_key = "event.bad_rewards.body"
	var option := preload("res://scripts/data/event_option_def.gd").new()
	option.id = "bad"
	option.label_key = "event.bad_rewards.option.bad"
	option.grant_card_ids = ["missing.card"]
	option.grant_relic_ids = ["missing_relic"]
	option.remove_card_id = "missing.remove_card"
	event.options = [option]
	catalog.events_by_id[event.id] = event
	var errors := catalog.validate()
	var passed := _any_contains(errors, "missing card missing.card") \
		and _any_contains(errors, "missing relic missing_relic") \
		and _any_contains(errors, "missing remove card missing.remove_card")
	assert(passed)
	return passed
```

In `tests/unit/test_reward_generator.gd`, replace `test_relic_rewards_draw_from_each_populated_wave_2_tier()` with:

```gdscript
func test_relic_rewards_draw_from_each_populated_wave_c_tier() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var common := RewardGenerator.new().generate_relic_reward(catalog, 1, "wave_c_common", "common")
	var uncommon := RewardGenerator.new().generate_relic_reward(catalog, 1, "wave_c_uncommon", "uncommon")
	var rare := RewardGenerator.new().generate_relic_reward(catalog, 1, "wave_c_rare", "rare")
	var passed: bool = not String(common.get("relic_id", "")).is_empty() \
		and not String(uncommon.get("relic_id", "")).is_empty() \
		and not String(rare.get("relic_id", "")).is_empty()
	assert(passed)
	return passed
```

In `tests/unit/test_encounter_generator.gd`, replace `test_default_catalog_has_wave_2_enemy_tier_composition()` with:

```gdscript
func test_default_catalog_has_wave_c_enemy_tier_composition() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var passed: bool = catalog.get_enemies_by_tier("normal").size() == 7 \
		and catalog.get_enemies_by_tier("elite").size() == 5 \
		and catalog.get_enemies_by_tier("boss").size() == 4
	assert(passed)
	return passed
```

In `tests/unit/test_event_resolver.gd`, add:

```gdscript
func test_default_event_pool_includes_wave_c_events_with_options() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var expected := [
		"forgotten_armory",
		"jade_debt_collector",
		"moonlit_ferry",
		"spirit_compact",
		"tea_house_rumor",
		"withered_master",
	]
	var passed := true
	for event_id in expected:
		var event := catalog.get_event(event_id)
		passed = passed and event != null and not event.options.is_empty()
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: count and missing resource tests fail.

- [ ] **Step 3: Extend ContentCatalog validation for event reward references**

In `scripts/content/content_catalog.gd`, extend `_validate_event_options(errors)` inside the non-null option block:

```gdscript
			for card_id in option.grant_card_ids:
				if not cards_by_id.has(card_id):
					errors.append("Event %s option %s references missing card %s" % [event.id, option.id, card_id])
			if not option.remove_card_id.is_empty() and not cards_by_id.has(option.remove_card_id):
				errors.append("Event %s option %s references missing remove card %s" % [event.id, option.id, option.remove_card_id])
			for relic_id in option.grant_relic_ids:
				if not relics_by_id.has(relic_id):
					errors.append("Event %s option %s references missing relic %s" % [event.id, option.id, relic_id])
			if not option.relic_reward_tier.is_empty() and get_relics_by_tier(option.relic_reward_tier).is_empty():
				errors.append("Event %s option %s references empty relic tier %s" % [event.id, option.id, option.relic_reward_tier])
```

- [ ] **Step 4: Create Wave C enemy resources**

Create these files.

`resources/enemies/plague_jade_imp.tres`:

```ini
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/enemy_def.gd" id="1_enemy"]

[resource]
script = ExtResource("1_enemy")
id = "plague_jade_imp"
name_key = "enemy.plague_jade_imp.name"
max_hp = 24
intent_sequence = Array[String](["apply_status_poison_2_player", "attack_5", "block_4"])
reward_tier = "normal"
tier = "normal"
encounter_weight = 100
gold_reward_min = 10
gold_reward_max = 16
```

`resources/enemies/iron_oath_duelist.tres`:

```ini
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/enemy_def.gd" id="1_enemy"]

[resource]
script = ExtResource("1_enemy")
id = "iron_oath_duelist"
name_key = "enemy.iron_oath_duelist.name"
max_hp = 34
intent_sequence = Array[String](["self_status_sword_focus_1", "attack_7", "attack_9"])
reward_tier = "normal"
tier = "normal"
encounter_weight = 100
gold_reward_min = 11
gold_reward_max = 18
```

`resources/enemies/miasma_cauldron_elder.tres`:

```ini
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/enemy_def.gd" id="1_enemy"]

[resource]
script = ExtResource("1_enemy")
id = "miasma_cauldron_elder"
name_key = "enemy.miasma_cauldron_elder.name"
max_hp = 62
intent_sequence = Array[String](["apply_status_poison_3_player", "block_12", "attack_12"])
reward_tier = "elite"
tier = "elite"
encounter_weight = 100
gold_reward_min = 24
gold_reward_max = 34
```

`resources/enemies/boss_sword_ghost.tres`:

```ini
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/enemy_def.gd" id="1_enemy"]

[resource]
script = ExtResource("1_enemy")
id = "boss_sword_ghost"
name_key = "enemy.boss_sword_ghost.name"
max_hp = 125
intent_sequence = Array[String](["self_status_sword_focus_2", "apply_status_broken_stance_2_player", "attack_20"])
reward_tier = "boss"
tier = "boss"
encounter_weight = 100
gold_reward_min = 55
gold_reward_max = 75
```

- [ ] **Step 5: Create Wave C relic resources**

Create these files. Use the same `.tres` style as existing relics.

`resources/relics/paper_lantern_charm.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_block"]
script = ExtResource("2_effect")
effect_type = "block"
amount = 3
target = "player"

[resource]
script = ExtResource("1_relic")
id = "paper_lantern_charm"
name_key = "relic.paper_lantern_charm.name"
description_key = "relic.paper_lantern_charm.desc"
trigger_event = "combat_started"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_block")])
tier = "common"
reward_weight = 100
```

`resources/relics/mothwing_sachet.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_heal"]
script = ExtResource("2_effect")
effect_type = "heal"
amount = 1
target = "player"

[resource]
script = ExtResource("1_relic")
id = "mothwing_sachet"
name_key = "relic.mothwing_sachet.name"
description_key = "relic.mothwing_sachet.desc"
trigger_event = "turn_started"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_heal")])
tier = "common"
reward_weight = 100
```

`resources/relics/rusted_meridian_ring.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_gold"]
script = ExtResource("2_effect")
effect_type = "gain_gold"
amount = 4
target = "player"

[resource]
script = ExtResource("1_relic")
id = "rusted_meridian_ring"
name_key = "relic.rusted_meridian_ring.name"
description_key = "relic.rusted_meridian_ring.desc"
trigger_event = "combat_won"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_gold")])
tier = "common"
reward_weight = 100
```

`resources/relics/silk_thread_prayer.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_focus"]
script = ExtResource("2_effect")
effect_type = "apply_status"
amount = 1
status_id = "sword_focus"
target = "player"

[resource]
script = ExtResource("1_relic")
id = "silk_thread_prayer"
name_key = "relic.silk_thread_prayer.name"
description_key = "relic.silk_thread_prayer.desc"
trigger_event = "combat_started"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_focus")])
tier = "uncommon"
reward_weight = 100
```

`resources/relics/black_pill_vial.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_poison"]
script = ExtResource("2_effect")
effect_type = "apply_status"
amount = 1
status_id = "poison"
target = "player"

[sub_resource type="Resource" id="Resource_energy"]
script = ExtResource("2_effect")
effect_type = "gain_energy"
amount = 1
target = "player"

[resource]
script = ExtResource("1_relic")
id = "black_pill_vial"
name_key = "relic.black_pill_vial.name"
description_key = "relic.black_pill_vial.desc"
trigger_event = "combat_started"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_poison"), SubResource("Resource_energy")])
tier = "uncommon"
reward_weight = 100
```

`resources/relics/cloudstep_sandals.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_block"]
script = ExtResource("2_effect")
effect_type = "block"
amount = 3
target = "player"

[resource]
script = ExtResource("1_relic")
id = "cloudstep_sandals"
name_key = "relic.cloudstep_sandals.name"
description_key = "relic.cloudstep_sandals.desc"
trigger_event = "turn_started"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_block")])
tier = "uncommon"
reward_weight = 100
```

`resources/relics/immortal_peach_core.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_heal"]
script = ExtResource("2_effect")
effect_type = "heal"
amount = 6
target = "player"

[resource]
script = ExtResource("1_relic")
id = "immortal_peach_core"
name_key = "relic.immortal_peach_core.name"
description_key = "relic.immortal_peach_core.desc"
trigger_event = "combat_started"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_heal")])
tier = "rare"
reward_weight = 100
```

`resources/relics/void_tiger_eye.tres`:

```ini
[gd_resource type="Resource" script_class="RelicDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/relic_def.gd" id="1_relic"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_gold"]
script = ExtResource("2_effect")
effect_type = "gain_gold"
amount = 12
target = "player"

[resource]
script = ExtResource("1_relic")
id = "void_tiger_eye"
name_key = "relic.void_tiger_eye.name"
description_key = "relic.void_tiger_eye.desc"
trigger_event = "combat_won"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_gold")])
tier = "rare"
reward_weight = 100
```

- [ ] **Step 6: Create Wave C event resources**

Create these event files. All options use only Wave C fields added to `EventOptionDef`.

`resources/events/forgotten_armory.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_take_blade"]
script = ExtResource("2_option")
id = "take_blade"
label_key = "event.forgotten_armory.option.take_blade"
description_key = "event.forgotten_armory.option.take_blade.desc"
grant_card_ids = Array[String](["sword.flash_cut"])

[sub_resource type="Resource" id="Resource_train"]
script = ExtResource("2_option")
id = "train"
label_key = "event.forgotten_armory.option.train"
description_key = "event.forgotten_armory.option.train.desc"
min_hp = 8
hp_delta = -7
card_reward_count = 3

[sub_resource type="Resource" id="Resource_take_pill"]
script = ExtResource("2_option")
id = "take_pill"
label_key = "event.forgotten_armory.option.take_pill"
description_key = "event.forgotten_armory.option.take_pill.desc"
grant_card_ids = Array[String](["alchemy.toxin_needle"])

[sub_resource type="Resource" id="Resource_leave"]
script = ExtResource("2_option")
id = "leave"
label_key = "event.forgotten_armory.option.leave"
description_key = "event.forgotten_armory.option.leave.desc"

[resource]
script = ExtResource("1_event")
id = "forgotten_armory"
title_key = "event.forgotten_armory.title"
body_key = "event.forgotten_armory.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_take_blade"), SubResource("Resource_take_pill"), SubResource("Resource_train"), SubResource("Resource_leave")])
```

`resources/events/jade_debt_collector.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_pay"]
script = ExtResource("2_option")
id = "pay"
label_key = "event.jade_debt_collector.option.pay"
description_key = "event.jade_debt_collector.option.pay.desc"
min_gold = 25
gold_delta = -25

[sub_resource type="Resource" id="Resource_bargain"]
script = ExtResource("2_option")
id = "bargain"
label_key = "event.jade_debt_collector.option.bargain"
description_key = "event.jade_debt_collector.option.bargain.desc"
remove_card_id = "sword.strike"
gold_delta = 10

[sub_resource type="Resource" id="Resource_refuse"]
script = ExtResource("2_option")
id = "refuse"
label_key = "event.jade_debt_collector.option.refuse"
description_key = "event.jade_debt_collector.option.refuse.desc"
min_hp = 7
hp_delta = -6

[resource]
script = ExtResource("1_event")
id = "jade_debt_collector"
title_key = "event.jade_debt_collector.title"
body_key = "event.jade_debt_collector.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_pay"), SubResource("Resource_bargain"), SubResource("Resource_refuse")])
```

`resources/events/moonlit_ferry.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_cross"]
script = ExtResource("2_option")
id = "cross"
label_key = "event.moonlit_ferry.option.cross"
description_key = "event.moonlit_ferry.option.cross.desc"
min_hp = 9
hp_delta = -8
relic_reward_tier = "common"

[sub_resource type="Resource" id="Resource_wait"]
script = ExtResource("2_option")
id = "wait"
label_key = "event.moonlit_ferry.option.wait"
description_key = "event.moonlit_ferry.option.wait.desc"
hp_delta = 2

[resource]
script = ExtResource("1_event")
id = "moonlit_ferry"
title_key = "event.moonlit_ferry.title"
body_key = "event.moonlit_ferry.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_cross"), SubResource("Resource_wait")])
```

`resources/events/spirit_compact.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_accept"]
script = ExtResource("2_option")
id = "accept"
label_key = "event.spirit_compact.option.accept"
description_key = "event.spirit_compact.option.accept.desc"
min_hp = 11
hp_delta = -10
grant_relic_ids = Array[String](["paper_lantern_charm"])

[sub_resource type="Resource" id="Resource_refuse"]
script = ExtResource("2_option")
id = "refuse"
label_key = "event.spirit_compact.option.refuse"
description_key = "event.spirit_compact.option.refuse.desc"

[resource]
script = ExtResource("1_event")
id = "spirit_compact"
title_key = "event.spirit_compact.title"
body_key = "event.spirit_compact.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_accept"), SubResource("Resource_refuse")])
```

`resources/events/tea_house_rumor.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_rest"]
script = ExtResource("2_option")
id = "rest"
label_key = "event.tea_house_rumor.option.rest"
description_key = "event.tea_house_rumor.option.rest.desc"
hp_delta = 6

[sub_resource type="Resource" id="Resource_buy_rumor"]
script = ExtResource("2_option")
id = "buy_rumor"
label_key = "event.tea_house_rumor.option.buy_rumor"
description_key = "event.tea_house_rumor.option.buy_rumor.desc"
min_gold = 18
gold_delta = -18
card_reward_count = 3

[sub_resource type="Resource" id="Resource_leave"]
script = ExtResource("2_option")
id = "leave"
label_key = "event.tea_house_rumor.option.leave"
description_key = "event.tea_house_rumor.option.leave.desc"

[resource]
script = ExtResource("1_event")
id = "tea_house_rumor"
title_key = "event.tea_house_rumor.title"
body_key = "event.tea_house_rumor.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_rest"), SubResource("Resource_buy_rumor"), SubResource("Resource_leave")])
```

`resources/events/withered_master.tres`:

```ini
[gd_resource type="Resource" script_class="EventDef" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/event_def.gd" id="1_event"]
[ext_resource type="Script" path="res://scripts/data/event_option_def.gd" id="2_option"]

[sub_resource type="Resource" id="Resource_prune_sword"]
script = ExtResource("2_option")
id = "prune_sword"
label_key = "event.withered_master.option.prune_sword"
description_key = "event.withered_master.option.prune_sword.desc"
remove_card_id = "sword.strike"

[sub_resource type="Resource" id="Resource_prune_alchemy"]
script = ExtResource("2_option")
id = "prune_alchemy"
label_key = "event.withered_master.option.prune_alchemy"
description_key = "event.withered_master.option.prune_alchemy.desc"
remove_card_id = "alchemy.toxic_pill"

[sub_resource type="Resource" id="Resource_work"]
script = ExtResource("2_option")
id = "work"
label_key = "event.withered_master.option.work"
description_key = "event.withered_master.option.work.desc"
min_hp = 6
hp_delta = -5
gold_delta = 22

[resource]
script = ExtResource("1_event")
id = "withered_master"
title_key = "event.withered_master.title"
body_key = "event.withered_master.body"
event_weight = 100
options = Array[ExtResource("2_option")]([SubResource("Resource_prune_sword"), SubResource("Resource_prune_alchemy"), SubResource("Resource_work")])
```

- [ ] **Step 7: Register Wave C resources in ContentCatalog**

Append these paths to `ContentCatalog.DEFAULT_ENEMY_PATHS` after existing Wave 2 enemies:

```gdscript
	"res://resources/enemies/plague_jade_imp.tres",
	"res://resources/enemies/iron_oath_duelist.tres",
	"res://resources/enemies/miasma_cauldron_elder.tres",
	"res://resources/enemies/boss_sword_ghost.tres",
```

Append these paths to `ContentCatalog.DEFAULT_RELIC_PATHS`:

```gdscript
	"res://resources/relics/paper_lantern_charm.tres",
	"res://resources/relics/mothwing_sachet.tres",
	"res://resources/relics/rusted_meridian_ring.tres",
	"res://resources/relics/silk_thread_prayer.tres",
	"res://resources/relics/black_pill_vial.tres",
	"res://resources/relics/cloudstep_sandals.tres",
	"res://resources/relics/immortal_peach_core.tres",
	"res://resources/relics/void_tiger_eye.tres",
```

Append these paths to `ContentCatalog.DEFAULT_EVENT_PATHS`:

```gdscript
	"res://resources/events/forgotten_armory.tres",
	"res://resources/events/jade_debt_collector.tres",
	"res://resources/events/moonlit_ferry.tres",
	"res://resources/events/spirit_compact.tres",
	"res://resources/events/tea_house_rumor.tres",
	"res://resources/events/withered_master.tres",
```

- [ ] **Step 8: Add localization keys**

Append non-empty `msgid` / `msgstr` entries to `localization/zh_CN.po` for:

```text
enemy.plague_jade_imp.name
enemy.iron_oath_duelist.name
enemy.miasma_cauldron_elder.name
enemy.boss_sword_ghost.name
relic.paper_lantern_charm.name
relic.paper_lantern_charm.desc
relic.mothwing_sachet.name
relic.mothwing_sachet.desc
relic.rusted_meridian_ring.name
relic.rusted_meridian_ring.desc
relic.silk_thread_prayer.name
relic.silk_thread_prayer.desc
relic.black_pill_vial.name
relic.black_pill_vial.desc
relic.cloudstep_sandals.name
relic.cloudstep_sandals.desc
relic.immortal_peach_core.name
relic.immortal_peach_core.desc
relic.void_tiger_eye.name
relic.void_tiger_eye.desc
event.forgotten_armory.title
event.forgotten_armory.body
event.forgotten_armory.option.take_blade
event.forgotten_armory.option.take_blade.desc
event.forgotten_armory.option.take_pill
event.forgotten_armory.option.take_pill.desc
event.forgotten_armory.option.train
event.forgotten_armory.option.train.desc
event.forgotten_armory.option.leave
event.forgotten_armory.option.leave.desc
event.jade_debt_collector.title
event.jade_debt_collector.body
event.jade_debt_collector.option.pay
event.jade_debt_collector.option.pay.desc
event.jade_debt_collector.option.bargain
event.jade_debt_collector.option.bargain.desc
event.jade_debt_collector.option.refuse
event.jade_debt_collector.option.refuse.desc
event.moonlit_ferry.title
event.moonlit_ferry.body
event.moonlit_ferry.option.cross
event.moonlit_ferry.option.cross.desc
event.moonlit_ferry.option.wait
event.moonlit_ferry.option.wait.desc
event.spirit_compact.title
event.spirit_compact.body
event.spirit_compact.option.accept
event.spirit_compact.option.accept.desc
event.spirit_compact.option.refuse
event.spirit_compact.option.refuse.desc
event.tea_house_rumor.title
event.tea_house_rumor.body
event.tea_house_rumor.option.rest
event.tea_house_rumor.option.rest.desc
event.tea_house_rumor.option.buy_rumor
event.tea_house_rumor.option.buy_rumor.desc
event.tea_house_rumor.option.leave
event.tea_house_rumor.option.leave.desc
event.withered_master.title
event.withered_master.body
event.withered_master.option.prune_sword
event.withered_master.option.prune_sword.desc
event.withered_master.option.prune_alchemy
event.withered_master.option.prune_alchemy.desc
event.withered_master.option.work
event.withered_master.option.work.desc
```

Use concise Chinese `msgstr` values matching the existing file style. Do not add empty `msgstr` values.

- [ ] **Step 9: Run tests and verify GREEN for Task 6**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 10: Run Godot import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 11: Run Task 6 review gates**

Stage 1 Spec Compliance Review:

- All 6 new event resources exist, are registered, have options, and load.
- All 8 new relic resources exist, are registered, and target only player-compatible effects.
- All 4 new enemy resources exist, are registered, and use allowed status intent strings.
- Catalog loads 40 cards, 16 enemies, 20 relics, and 12 events.
- Character card pools and starting decks are unchanged.
- New localization keys are present and non-empty.

Stage 2 Code Quality Review:

- `.tres` formatting matches existing resources.
- Catalog path ordering stays grouped and readable.
- Validation for event reward references is focused and deterministic.
- Tests do not rely on dictionary ordering.

- [ ] **Step 12: Commit Task 6**

Run:

```powershell
rtk proxy git add scripts/content/content_catalog.gd tests/unit/test_content_catalog.gd tests/unit/test_reward_generator.gd tests/unit/test_encounter_generator.gd tests/unit/test_event_resolver.gd resources/enemies resources/relics resources/events localization/zh_CN.po
rtk proxy git commit -m "feat: expand wave c content pools"
```

## Task 7: Final Acceptance, Documentation, and Reviews

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-28-content-expansion-wave-c.md`

- [ ] **Step 1: Run all local tests**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 2: Run project import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 3: Update README Phase 2 progress**

Append under `## Phase 2 Progress` in `README.md`:

```markdown
- Content expansion wave C: complete; events can grant cards, relics, card removal, and pending reward choices, enemies can use status intents, combat shows compact status names, and default content has 16 enemies, 20 relics, and 12 events.
```

Update `## Next Plans` to remove Wave C from the first slot and keep the remaining items:

```markdown
## Next Plans

1. High-presentation pass: generated assets, animation, particles, camera, audio.
2. Developer tools: card browser, enemy sandbox, event tester, reward inspector, save inspector.
3. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
```

- [ ] **Step 4: Mark completed plan steps**

Update completed checkboxes in `docs/superpowers/plans/2026-04-28-content-expansion-wave-c.md` from `[ ]` to `[x]` after verifying implementation and reviews.

- [ ] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Event options support direct card grants, direct relic grants, one-card removal, generated card reward choices, and generated relic reward choices.
- Pending event rewards save, load, resume, clear, and route through the reward screen.
- Combat rewards still work unchanged.
- Enemy status intents apply statuses through generic status stacking and do not duplicate gameplay status rules.
- Compact status UI uses `status_display_text()` and remains simple.
- All new enemies, relics, and events exist, are registered, localized, and load through `ContentCatalog`.
- Default counts are 40 cards, 16 enemies, 20 relics, and 12 events.
- No `StatusDef`, rich presentation system, event history system, new shop/map system, or release infrastructure was added.

Stage 2 Code Quality Review:

- GDScript typing is clear for new fields, functions, and dictionaries.
- Event reward state validation is narrow and testable.
- Reward screen branching remains readable and does not duplicate claim logic.
- Enemy intent parsing is isolated and deterministic.
- Status rules remain centralized in `CombatStatusRuntime`.
- Resource formatting and catalog ordering remain consistent.
- Localization keys are non-empty and not duplicated incorrectly.

Classify any found issues as Critical, Important, or Minor. Fix Critical and Important issues before acceptance. Minor issues can be fixed immediately if low risk or recorded in final summary.

- [ ] **Step 6: Commit acceptance docs**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-28-content-expansion-wave-c.md
rtk proxy git commit -m "docs: record content expansion wave c acceptance"
```

## Final Acceptance Criteria

- Event options can grant cards, grant relics, remove a card, or create pending card/relic reward choices.
- Pending event rewards route through the existing reward screen and advance the event node only after completion.
- Save/load preserves pending event reward state and accepts legacy saves.
- Enemy status intents can apply statuses to the player or acting enemy.
- Status gameplay rules remain in `CombatStatusRuntime`.
- Combat UI shows compact known status names rather than raw id-only text.
- Default catalog loads 40 cards, 16 enemies, 20 relics, and 12 events.
- New events, enemies, and relics have required localization keys.
- Catalog validation returns no errors.
- Reward, event, shop, save, and combat smoke flows pass.
- Godot tests pass.
- Godot import check exits 0.

## Execution Handoff

After this plan is accepted, choose one execution mode:

1. **Subagent-Driven:** only if the user explicitly authorizes subagents. If used, dispatch one fresh subagent per task and require `gpt-5.5` with extra-high reasoning as stated in project instructions.
2. **Inline Execution:** execute tasks in this session with `superpowers:executing-plans`, staying on local `main` and using the review gates after each completed Godot feature.
