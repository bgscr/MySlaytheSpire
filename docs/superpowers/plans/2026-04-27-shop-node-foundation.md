# Shop Node Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make map `shop` nodes enter a transaction-saved shop screen with deterministic card, relic, heal, removal, and one paid refresh action.

**Architecture:** Add shop state persistence to `RunState`, deterministic stock generation in `ShopResolver`, transaction validation in `ShopRunner`, and a dynamic `ShopScreen` that saves after every successful transaction. Route `shop` nodes directly to the shop scene and resume in-progress shops from the main menu.

**Tech Stack:** Godot 4.6.2-stable, GDScript, dynamic UI nodes, custom headless test runner.

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

This plan is intended for inline execution because the project forbids worktrees and the current request did not explicitly ask for subagent delegation.

## Scope Check

This plan implements `docs/superpowers/specs/2026-04-27-shop-node-foundation-design.md`.

Included:

- `RunState.current_shop_state` persistence.
- Backward-compatible save loading for older saves without shop state.
- Deterministic shop stock generation for card, relic, heal, and remove offers.
- One paid refresh per shop.
- Transaction validation and application for card, relic, heal, remove, and refresh.
- Shop scene flow, map routing, and continue routing into in-progress shops.
- Unit and smoke coverage.
- README and plan acceptance updates.

Excluded:

- Shop art, shopkeeper UI, audio, VFX, animation, and camera work.
- Discounts, coupons, memberships, dynamic pricing, ascension modifiers, or multiple currencies.
- Multiple refreshes.
- Card upgrades, card transforms, duplication, or reward-package shop items.
- A dedicated shop content `.tres` database.
- Any combat reward generation changes.

## File Structure

Create:

- `scripts/shop/shop_resolver.gd`: deterministic shop state creation and refresh stock helpers.
- `scripts/shop/shop_runner.gd`: transaction validation and mutation.
- `scripts/ui/shop_screen.gd`: shop UI, save boundary, and route flow.
- `scenes/shop/ShopScreen.tscn`: shop scene.
- `tests/unit/test_shop_resolver.gd`: resolver tests.
- `tests/unit/test_shop_runner.gd`: runner tests.

Modify:

- `scripts/run/run_state.gd`: add `current_shop_state`.
- `scripts/save/save_service.gd`: save/load and validate shop state.
- `scripts/app/scene_router.gd`: add `SHOP`.
- `scripts/ui/map_screen.gd`: route `shop` nodes.
- `scripts/ui/main_menu.gd`: resume in-progress shop.
- `scripts/testing/test_runner.gd`: register shop tests.
- `tests/unit/test_run_state.gd`: shop state serialization tests.
- `tests/unit/test_save_service.gd`: shop save tests.
- `tests/smoke/test_scene_flow.gd`: shop scene flow smoke tests.
- `README.md`: Phase 2 progress.
- `docs/superpowers/plans/2026-04-27-shop-node-foundation.md`: mark execution status.

## Command Conventions

Run full tests:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Run import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

## Task 1: Shop Save-State Schema

**Files:**

- Modify: `scripts/run/run_state.gd`
- Modify: `scripts/save/save_service.gd`
- Modify: `tests/unit/test_run_state.gd`
- Modify: `tests/unit/test_save_service.gd`

- [x] **Step 1: Add failing RunState shop serialization tests**

Append to `tests/unit/test_run_state.gd`:

```gdscript
func test_to_dict_serializes_current_shop_state_without_aliasing() -> bool:
	var run := RunState.new()
	run.current_shop_state = {
		"node_id": "node_shop",
		"refresh_used": false,
		"offers": [
			{
				"id": "card_0",
				"type": "card",
				"item_id": "sword.flash_cut",
				"price": 40,
				"sold": false,
			},
		],
	}

	var payload := run.to_dict()
	var shop_state: Dictionary = payload.get("current_shop_state", {})
	var offers: Array = shop_state.get("offers", [])
	if not offers.is_empty():
		(offers[0] as Dictionary)["sold"] = true

	var run_offers: Array = run.current_shop_state.get("offers", [])
	var passed: bool = payload.has("current_shop_state") \
		and shop_state.get("node_id") == "node_shop" \
		and not run_offers.is_empty() \
		and (run_offers[0] as Dictionary).get("sold") == false
	assert(passed)
	return passed
```

- [x] **Step 2: Add failing SaveService shop-state tests**

Append to `tests/unit/test_save_service.gd`:

```gdscript
func test_save_round_trip_preserves_current_shop_state() -> bool:
	var save_path := "user://test_shop_state_save.json"
	_delete_test_save(save_path)
	var run := RunState.new()
	run.current_shop_state = {
		"node_id": "node_shop",
		"refresh_used": true,
		"offers": [
			{
				"id": "relic_0",
				"type": "relic",
				"item_id": "jade_talisman",
				"price": 120,
				"sold": true,
			},
		],
	}
	var service := SaveService.new(save_path)
	service.save_run(run)

	var loaded := service.load_run()
	var loaded_shop_state: Dictionary = loaded.current_shop_state if loaded != null else {}
	var offers: Array = loaded_shop_state.get("offers", [])
	var passed: bool = loaded != null \
		and loaded_shop_state.get("node_id") == "node_shop" \
		and loaded_shop_state.get("refresh_used") == true \
		and offers.size() == 1 \
		and (offers[0] as Dictionary).get("id") == "relic_0" \
		and (offers[0] as Dictionary).get("sold") == true
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_accepts_legacy_save_without_shop_state() -> bool:
	var save_path := "user://test_legacy_without_shop_state.json"
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
	var passed: bool = loaded != null and loaded.current_shop_state.is_empty()
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_returns_null_for_invalid_shop_state_type() -> bool:
	var save_path := "user://test_invalid_shop_state_type.json"
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
		"current_shop_state": "bad",
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

Run full tests.

Expected: tests fail because `RunState` does not have `current_shop_state` and `SaveService` does not load it.

- [x] **Step 4: Implement RunState shop state**

Modify `scripts/run/run_state.gd`:

```gdscript
class_name RunState
extends RefCounted

var version := 1
var seed_value := 1
var character_id := ""
var current_hp := 1
var max_hp := 1
var gold := 0
var deck_ids: Array[String] = []
var relic_ids: Array[String] = []
var map_nodes: Array = []
var current_node_id := ""
var current_shop_state: Dictionary = {}
var completed := false
var failed := false

func to_dict() -> Dictionary:
	var node_payload := []
	for node in map_nodes:
		node_payload.append({
			"id": node.id,
			"layer": node.layer,
			"node_type": node.node_type,
			"visited": node.visited,
			"unlocked": node.unlocked,
		})
	return {
		"version": version,
		"seed_value": seed_value,
		"character_id": character_id,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck_ids": deck_ids.duplicate(),
		"relic_ids": relic_ids.duplicate(),
		"map_nodes": node_payload,
		"current_node_id": current_node_id,
		"current_shop_state": current_shop_state.duplicate(true),
		"completed": completed,
		"failed": failed,
	}
```

- [x] **Step 5: Implement SaveService shop state loading and validation**

Modify `scripts/save/save_service.gd`:

```gdscript
func load_run() -> RunState:
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return null

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	var parsed = json.data
	if not parsed is Dictionary:
		return null

	var payload: Dictionary = parsed
	if not _is_valid_run_payload(payload):
		return null

	var run := RunState.new()
	run.version = int(payload["version"])
	run.seed_value = int(payload["seed_value"])
	run.character_id = payload["character_id"]
	run.current_hp = int(payload["current_hp"])
	run.max_hp = int(payload["max_hp"])
	run.gold = int(payload["gold"])
	run.deck_ids.assign(payload["deck_ids"])
	run.relic_ids.assign(payload["relic_ids"])
	run.map_nodes = _load_map_nodes(payload["map_nodes"])
	run.current_node_id = payload["current_node_id"]
	var shop_state: Dictionary = payload.get("current_shop_state", {})
	run.current_shop_state = shop_state.duplicate(true)
	run.completed = payload["completed"]
	run.failed = payload["failed"]
	return run

func _is_valid_run_payload(payload: Dictionary) -> bool:
	return _has_int(payload, "version") \
		and _has_int(payload, "seed_value") \
		and _has_string(payload, "character_id") \
		and _has_int(payload, "current_hp") \
		and _has_int(payload, "max_hp") \
		and _has_int(payload, "gold") \
		and _has_string_array(payload, "deck_ids") \
		and _has_string_array(payload, "relic_ids") \
		and _has_valid_map_nodes(payload, "map_nodes") \
		and _has_string(payload, "current_node_id") \
		and _has_optional_dictionary(payload, "current_shop_state") \
		and _has_bool(payload, "completed") \
		and _has_bool(payload, "failed")

func _has_optional_dictionary(payload: Dictionary, key: String) -> bool:
	return not payload.has(key) or payload[key] is Dictionary
```

Keep all other existing functions unchanged.

- [x] **Step 6: Run tests and verify GREEN for Task 1**

Run full tests. Expected: new RunState and SaveService tests pass, full suite ends with `TESTS PASSED`.

- [x] **Step 7: Run Task 1 review gates**

Stage 1 Spec Compliance Review:

- Confirm `RunState.to_dict()` writes `current_shop_state`.
- Confirm save/load preserves shop state.
- Confirm old saves without `current_shop_state` load with `{}`.
- Confirm invalid non-dictionary shop state is rejected.

Stage 2 Code Quality Review:

- Check `current_shop_state` is deep-duplicated to avoid aliasing.
- Check validation remains explicit and does not weaken existing save checks.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 8: Commit Task 1**

```powershell
rtk proxy git add scripts/run/run_state.gd scripts/save/save_service.gd tests/unit/test_run_state.gd tests/unit/test_save_service.gd
rtk proxy git commit -m "feat: persist shop state"
```

## Task 2: ShopResolver

**Files:**

- Create: `scripts/shop/shop_resolver.gd`
- Create: `tests/unit/test_shop_resolver.gd`
- Modify: `scripts/testing/test_runner.gd`

- [x] **Step 1: Register shop unit tests**

Modify `scripts/testing/test_runner.gd` and insert after `test_run_progression.gd`:

```gdscript
"res://tests/unit/test_shop_resolver.gd",
"res://tests/unit/test_shop_runner.gd",
```

`test_shop_runner.gd` is created in Task 3. Registering both now intentionally causes RED until both scripts exist.

- [x] **Step 2: Write failing ShopResolver tests**

Create `tests/unit/test_shop_resolver.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const ShopResolver := preload("res://scripts/shop/shop_resolver.gd")

func test_shop_resolver_generates_deterministic_shop_state() -> bool:
	var catalog := _catalog()
	var first_run := _shop_run(707)
	var second_run := _shop_run(707)
	var first_resolver := ShopResolver.new()
	var second_resolver := ShopResolver.new()
	var first := first_resolver.resolve(catalog, first_run)
	var second := second_resolver.resolve(catalog, second_run)
	var passed: bool = first == second \
		and first_resolver.created_new_state \
		and second_resolver.created_new_state \
		and String(first.get("node_id", "")) == "node_0" \
		and first.get("refresh_used", true) == false \
		and _offers_of_type(first, "card").size() == 3 \
		and _offers_of_type(first, "relic").size() == 2 \
		and _offers_of_type(first, "heal").size() == 1 \
		and _offers_of_type(first, "remove").size() == 1
	assert(passed)
	return passed

func test_shop_resolver_resumes_matching_saved_state() -> bool:
	var run := _shop_run(808)
	run.current_shop_state = {
		"node_id": "node_0",
		"refresh_used": true,
		"offers": [
			_offer("card_0", "card", "sword.guard", 40, true),
		],
	}
	var resolver := ShopResolver.new()
	var state := resolver.resolve(_catalog(), run)
	var offers: Array = state.get("offers", [])
	var passed: bool = not resolver.created_new_state \
		and offers.size() == 1 \
		and (offers[0] as Dictionary).get("item_id") == "sword.guard" \
		and (offers[0] as Dictionary).get("sold") == true
	assert(passed)
	return passed

func test_shop_resolver_replaces_state_for_different_node() -> bool:
	var run := _shop_run(909)
	run.current_shop_state = {
		"node_id": "old_node",
		"refresh_used": true,
		"offers": [],
	}
	var resolver := ShopResolver.new()
	var state := resolver.resolve(_catalog(), run)
	var passed: bool = resolver.created_new_state \
		and state.get("node_id") == "node_0" \
		and state.get("refresh_used") == false \
		and not (state.get("offers", []) as Array).is_empty()
	assert(passed)
	return passed

func test_shop_resolver_returns_empty_for_non_shop_node() -> bool:
	var run := _shop_run(1001)
	run.map_nodes[0].node_type = "event"
	var state := ShopResolver.new().resolve(_catalog(), run)
	var passed: bool = state.is_empty()
	assert(passed)
	return passed

func test_shop_resolver_excludes_owned_relics() -> bool:
	var run := _shop_run(1002)
	run.relic_ids = [
		"jade_talisman",
		"bronze_incense_burner",
		"cracked_spirit_coin",
		"moonwell_seed",
		"thunderseal_charm",
	]
	var state := ShopResolver.new().resolve(_catalog(), run)
	var relic_offers := _offers_of_type(state, "relic")
	var passed: bool = relic_offers.size() == 1 \
		and not run.relic_ids.has(String((relic_offers[0] as Dictionary).get("item_id", "")))
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _shop_run(seed_value: int) -> RunState:
	var run := RunState.new()
	run.seed_value = seed_value
	run.character_id = "sword"
	run.current_hp = 50
	run.max_hp = 72
	run.gold = 300
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	run.current_node_id = "node_0"
	var current := MapNodeState.new("node_0", 0, "shop")
	current.unlocked = true
	run.map_nodes = [current]
	return run

func _offer(offer_id: String, offer_type: String, item_id: String, price: int, sold: bool) -> Dictionary:
	return {
		"id": offer_id,
		"type": offer_type,
		"item_id": item_id,
		"price": price,
		"sold": sold,
	}

func _offers_of_type(state: Dictionary, offer_type: String) -> Array:
	var result := []
	for offer in state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("type", "") == offer_type:
			result.append(payload)
	return result
```

- [x] **Step 3: Run tests and verify RED**

Run full tests.

Expected: tests fail because `scripts/shop/shop_resolver.gd` and `tests/unit/test_shop_runner.gd` do not exist.

- [x] **Step 4: Implement ShopResolver**

Create `scripts/shop/shop_resolver.gd`:

```gdscript
class_name ShopResolver
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")
const RunState := preload("res://scripts/run/run_state.gd")

const CARD_PRICES := {
	"common": 40,
	"uncommon": 60,
	"rare": 85,
}

const RELIC_PRICES := {
	"common": 120,
	"uncommon": 160,
	"rare": 220,
	"boss": 260,
}

const HEAL_PRICE := 45
const REMOVE_PRICE := 75
const REFRESH_PRICE := 35

var created_new_state := false

func resolve(catalog: ContentCatalog, run: RunState) -> Dictionary:
	created_new_state = false
	if catalog == null or run == null:
		return {}
	var node := _current_node(run)
	if node == null or node.node_type != "shop":
		return {}
	if _matches_current_shop(run.current_shop_state, node.id):
		return run.current_shop_state
	var rng := RngService.new(run.seed_value).fork("shop:%s" % node.id)
	var state := {
		"node_id": node.id,
		"refresh_used": false,
		"offers": _build_initial_offers(catalog, run, rng),
	}
	run.current_shop_state = state
	created_new_state = true
	return run.current_shop_state

func build_refreshed_item_offers(catalog: ContentCatalog, run: RunState) -> Array[Dictionary]:
	var node := _current_node(run)
	if catalog == null or run == null or node == null:
		return []
	var rng := RngService.new(run.seed_value).fork("shop:refresh:%s" % node.id)
	var result: Array[Dictionary] = []
	result.append_array(_card_offers(catalog, run, rng))
	result.append_array(_relic_offers(catalog, run, rng))
	return result

func card_price(rarity: String) -> int:
	return int(CARD_PRICES.get(rarity, CARD_PRICES["common"]))

func relic_price(tier: String) -> int:
	return int(RELIC_PRICES.get(tier, RELIC_PRICES["common"]))

func _build_initial_offers(catalog: ContentCatalog, run: RunState, rng: RngService) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	offers.append_array(_card_offers(catalog, run, rng))
	offers.append_array(_relic_offers(catalog, run, rng))
	offers.append({
		"id": "heal_0",
		"type": "heal",
		"item_id": "",
		"price": HEAL_PRICE,
		"sold": false,
	})
	offers.append({
		"id": "remove_0",
		"type": "remove",
		"item_id": "",
		"price": REMOVE_PRICE,
		"sold": false,
	})
	return offers

func _card_offers(catalog: ContentCatalog, run: RunState, rng: RngService) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var pool: Array = rng.shuffle_copy(catalog.get_cards_for_character(run.character_id))
	for card: CardDef in pool:
		if offers.size() >= 3:
			break
		offers.append({
			"id": "card_%s" % offers.size(),
			"type": "card",
			"item_id": card.id,
			"price": card_price(card.rarity),
			"sold": false,
		})
	return offers

func _relic_offers(catalog: ContentCatalog, run: RunState, rng: RngService) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var relics: Array = rng.shuffle_copy(catalog.relics_by_id.values())
	for relic: RelicDef in relics:
		if offers.size() >= 2:
			break
		if run.relic_ids.has(relic.id):
			continue
		offers.append({
			"id": "relic_%s" % offers.size(),
			"type": "relic",
			"item_id": relic.id,
			"price": relic_price(relic.tier),
			"sold": false,
		})
	return offers

func _matches_current_shop(state: Dictionary, node_id: String) -> bool:
	return not state.is_empty() and String(state.get("node_id", "")) == node_id

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
```

- [x] **Step 5: Add temporary empty ShopRunner test file for GREEN**

Create `tests/unit/test_shop_runner.gd`:

```gdscript
extends RefCounted
```

Task 3 replaces this file with real failing tests.

- [x] **Step 6: Run tests and verify GREEN for Task 2**

Run full tests. Expected: resolver tests pass, full suite ends with `TESTS PASSED`.

- [x] **Step 7: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- Confirm resolver only resolves `shop` nodes.
- Confirm resolver uses seed and node id.
- Confirm card, relic, heal, and remove offers are generated.
- Confirm saved matching state is resumed.
- Confirm already-owned relics are excluded.

Stage 2 Code Quality Review:

- Check resolver has no UI or save calls.
- Check pricing constants are centralized.
- Check returned state shape matches the spec.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 8: Commit Task 2**

```powershell
rtk proxy git add scripts/shop/shop_resolver.gd tests/unit/test_shop_resolver.gd tests/unit/test_shop_runner.gd scripts/testing/test_runner.gd
rtk proxy git commit -m "feat: add shop resolver"
```

## Task 3: ShopRunner

**Files:**

- Create: `scripts/shop/shop_runner.gd`
- Modify: `tests/unit/test_shop_runner.gd`

- [x] **Step 1: Replace ShopRunner tests with failing behavior tests**

Replace `tests/unit/test_shop_runner.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const ShopRunner := preload("res://scripts/shop/shop_runner.gd")

func test_runner_buys_card_and_marks_offer_sold() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var applied := runner.buy_offer(_catalog(), run, "card_0")
	var offer := _offer(run, "card_0")
	var passed: bool = applied \
		and run.gold == 160 \
		and run.deck_ids.has("sword.flash_cut") \
		and offer.get("sold") == true
	assert(passed)
	return passed

func test_runner_buys_relic_and_rejects_duplicate_relic() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var first := runner.buy_offer(_catalog(), run, "relic_0")
	var gold_after_first := run.gold
	var second := runner.buy_offer(_catalog(), run, "relic_0")
	var passed: bool = first \
		and not second \
		and run.relic_ids == ["jade_talisman"] \
		and run.gold == gold_after_first
	assert(passed)
	return passed

func test_runner_rejects_insufficient_gold_without_mutation() -> bool:
	var run := _run()
	run.gold = 10
	var applied := ShopRunner.new().buy_offer(_catalog(), run, "card_0")
	var offer := _offer(run, "card_0")
	var passed: bool = not applied \
		and run.gold == 10 \
		and not run.deck_ids.has("sword.flash_cut") \
		and offer.get("sold") == false
	assert(passed)
	return passed

func test_runner_heals_with_clamp_and_rejects_full_hp() -> bool:
	var run := _run()
	run.current_hp = 60
	run.max_hp = 72
	var runner := ShopRunner.new()
	var healed := runner.buy_offer(_catalog(), run, "heal_0")
	var hp_after_heal := run.current_hp
	var gold_after_heal := run.gold
	var second := runner.buy_offer(_catalog(), run, "heal_0")
	var passed: bool = healed \
		and hp_after_heal == 72 \
		and gold_after_heal == 155 \
		and not second \
		and run.current_hp == 72 \
		and run.gold == gold_after_heal
	assert(passed)
	return passed

func test_runner_removes_selected_card_once() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var removed := runner.buy_offer(_catalog(), run, "remove_0", "sword.guard")
	var second := runner.buy_offer(_catalog(), run, "remove_0", "sword.strike")
	var passed: bool = removed \
		and not second \
		and run.gold == 125 \
		and run.deck_ids == ["sword.strike", "sword.flash_cut"] \
		and _offer(run, "remove_0").get("sold") == true
	assert(passed)
	return passed

func test_runner_rejects_missing_remove_card_without_mutation() -> bool:
	var run := _run()
	var applied := ShopRunner.new().buy_offer(_catalog(), run, "remove_0", "missing.card")
	var passed: bool = not applied \
		and run.gold == 200 \
		and run.deck_ids == ["sword.strike", "sword.guard", "sword.flash_cut"] \
		and _offer(run, "remove_0").get("sold") == false
	assert(passed)
	return passed

func test_runner_refreshes_once_and_preserves_sold_offers() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var bought := runner.buy_offer(_catalog(), run, "card_0")
	var sold_card_item := String(_offer(run, "card_0").get("item_id", ""))
	var refreshed := runner.refresh(_catalog(), run)
	var second_refresh := runner.refresh(_catalog(), run)
	var passed: bool = bought \
		and refreshed \
		and not second_refresh \
		and run.gold == 125 \
		and run.current_shop_state.get("refresh_used") == true \
		and _offer(run, "card_0").get("sold") == true \
		and _offer(run, "card_0").get("item_id") == sold_card_item \
		and _offer(run, "card_1").get("sold") == false
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run() -> RunState:
	var run := RunState.new()
	run.seed_value = 123
	run.character_id = "sword"
	run.current_hp = 40
	run.max_hp = 72
	run.gold = 200
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	run.current_node_id = "node_0"
	var current := MapNodeState.new("node_0", 0, "shop")
	current.unlocked = true
	run.map_nodes = [current]
	run.current_shop_state = {
		"node_id": "node_0",
		"refresh_used": false,
		"offers": [
			{
				"id": "card_0",
				"type": "card",
				"item_id": "sword.flash_cut",
				"price": 40,
				"sold": false,
			},
			{
				"id": "card_1",
				"type": "card",
				"item_id": "sword.guardian_stance",
				"price": 60,
				"sold": false,
			},
			{
				"id": "relic_0",
				"type": "relic",
				"item_id": "jade_talisman",
				"price": 120,
				"sold": false,
			},
			{
				"id": "heal_0",
				"type": "heal",
				"item_id": "",
				"price": 45,
				"sold": false,
			},
			{
				"id": "remove_0",
				"type": "remove",
				"item_id": "",
				"price": 75,
				"sold": false,
			},
		],
	}
	return run

func _offer(run: RunState, offer_id: String) -> Dictionary:
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("id") == offer_id:
			return payload
	return {}
```

- [x] **Step 2: Run tests and verify RED**

Run full tests.

Expected: tests fail because `scripts/shop/shop_runner.gd` does not exist.

- [x] **Step 3: Implement ShopRunner**

Create `scripts/shop/shop_runner.gd`:

```gdscript
class_name ShopRunner
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const ShopResolver := preload("res://scripts/shop/shop_resolver.gd")

func can_buy_offer(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String = "") -> bool:
	return _validate_purchase(catalog, run, offer_id, remove_card_id).is_empty()

func buy_offer(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String = "") -> bool:
	var error := _validate_purchase(catalog, run, offer_id, remove_card_id)
	if not error.is_empty():
		return false
	var offer := _find_offer(run, offer_id)
	var price := int(offer.get("price", 0))
	match String(offer.get("type", "")):
		"card":
			run.gold -= price
			run.deck_ids.append(String(offer.get("item_id", "")))
			offer["sold"] = true
			return true
		"relic":
			run.gold -= price
			run.relic_ids.append(String(offer.get("item_id", "")))
			offer["sold"] = true
			return true
		"heal":
			run.gold -= price
			run.current_hp = min(run.max_hp, run.current_hp + _heal_amount(run))
			offer["sold"] = true
			return true
		"remove":
			var index := run.deck_ids.find(remove_card_id)
			run.gold -= price
			run.deck_ids.remove_at(index)
			offer["sold"] = true
			return true
	return false

func can_refresh(catalog: ContentCatalog, run: RunState) -> bool:
	return _validate_refresh(catalog, run).is_empty()

func refresh(catalog: ContentCatalog, run: RunState) -> bool:
	var error := _validate_refresh(catalog, run)
	if not error.is_empty():
		return false
	var refreshed := ShopResolver.new().build_refreshed_item_offers(catalog, run)
	var card_index := 0
	var relic_index := 0
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if bool(payload.get("sold", false)):
			continue
		match String(payload.get("type", "")):
			"card":
				var replacement := _next_offer_of_type(refreshed, "card", card_index)
				card_index += 1
				if not replacement.is_empty():
					payload["item_id"] = replacement.get("item_id", "")
					payload["price"] = replacement.get("price", payload.get("price", 0))
			"relic":
				var replacement := _next_offer_of_type(refreshed, "relic", relic_index)
				relic_index += 1
				if not replacement.is_empty():
					payload["item_id"] = replacement.get("item_id", "")
					payload["price"] = replacement.get("price", payload.get("price", 0))
	run.gold -= ShopResolver.REFRESH_PRICE
	run.current_shop_state["refresh_used"] = true
	return true

func unavailable_reason(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String = "") -> String:
	var purchase_error := _validate_purchase(catalog, run, offer_id, remove_card_id)
	return purchase_error if not purchase_error.is_empty() else ""

func refresh_unavailable_reason(catalog: ContentCatalog, run: RunState) -> String:
	var refresh_error := _validate_refresh(catalog, run)
	return refresh_error if not refresh_error.is_empty() else ""

func _validate_purchase(catalog: ContentCatalog, run: RunState, offer_id: String, remove_card_id: String) -> String:
	if catalog == null or run == null:
		return "Unavailable"
	if not _has_current_shop_state(run):
		return "Unavailable"
	var offer := _find_offer(run, offer_id)
	if offer.is_empty():
		return "Missing offer"
	if bool(offer.get("sold", false)):
		return "Sold out"
	var price := int(offer.get("price", 0))
	if run.gold < price:
		return "Requires %s gold" % price
	match String(offer.get("type", "")):
		"card":
			var card_id := String(offer.get("item_id", ""))
			if card_id.is_empty() or catalog.get_card(card_id) == null:
				return "Missing card"
		"relic":
			var relic_id := String(offer.get("item_id", ""))
			if relic_id.is_empty() or catalog.get_relic(relic_id) == null:
				return "Missing relic"
			if run.relic_ids.has(relic_id):
				return "Already owned"
		"heal":
			if run.current_hp >= run.max_hp:
				return "Full HP"
		"remove":
			if run.deck_ids.size() <= 1:
				return "Deck too small"
			if remove_card_id.is_empty() or not run.deck_ids.has(remove_card_id):
				return "Choose a card"
		_:
			return "Unavailable"
	return ""

func _validate_refresh(catalog: ContentCatalog, run: RunState) -> String:
	if catalog == null or run == null:
		return "Unavailable"
	if not _has_current_shop_state(run):
		return "Unavailable"
	if bool(run.current_shop_state.get("refresh_used", false)):
		return "Already refreshed"
	if run.gold < ShopResolver.REFRESH_PRICE:
		return "Requires %s gold" % ShopResolver.REFRESH_PRICE
	return ""

func _has_current_shop_state(run: RunState) -> bool:
	if run.current_shop_state.is_empty():
		return false
	var node := _current_node(run)
	return node != null \
		and node.node_type == "shop" \
		and String(run.current_shop_state.get("node_id", "")) == run.current_node_id

func _find_offer(run: RunState, offer_id: String) -> Dictionary:
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if String(payload.get("id", "")) == offer_id:
			return payload
	return {}

func _next_offer_of_type(offers: Array[Dictionary], offer_type: String, index: int) -> Dictionary:
	var seen := 0
	for offer in offers:
		if String(offer.get("type", "")) != offer_type:
			continue
		if seen == index:
			return offer
		seen += 1
	return {}

func _heal_amount(run: RunState) -> int:
	return max(8, int(floor(float(run.max_hp) * 0.2)))

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
```

- [x] **Step 4: Run tests and verify GREEN for Task 3**

Run full tests. Expected: shop runner tests pass, full suite ends with `TESTS PASSED`.

- [x] **Step 5: Run Godot import check**

Run import check. Expected: exit 0 with no parse errors or missing resources.

- [x] **Step 6: Run Task 3 review gates**

Stage 1 Spec Compliance Review:

- Confirm each transaction applies exactly one mutation.
- Confirm insufficient-gold, sold-out, duplicate relic, full-HP heal, impossible removal, and second refresh fail without mutation.
- Confirm refresh costs gold, is one-use, preserves sold offers, and updates unsold card/relic offers.
- Confirm runner has no save or route calls.

Stage 2 Code Quality Review:

- Check validation happens before mutation.
- Check helper APIs are narrow.
- Check constants are reused from `ShopResolver`.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 7: Commit Task 3**

```powershell
rtk proxy git add scripts/shop/shop_runner.gd tests/unit/test_shop_runner.gd
rtk proxy git commit -m "feat: add shop transactions"
```

## Task 4: ShopScreen, Routing, and Continue Resume

**Files:**

- Create: `scripts/ui/shop_screen.gd`
- Create: `scenes/shop/ShopScreen.tscn`
- Modify: `scripts/app/scene_router.gd`
- Modify: `scripts/ui/map_screen.gd`
- Modify: `scripts/ui/main_menu.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [x] **Step 1: Add failing shop smoke tests**

Modify `tests/smoke/test_scene_flow.gd`:

Add preloads near the existing constants:

```gdscript
const ShopResolverScript := preload("res://scripts/shop/shop_resolver.gd")
```

Append shop tests after the event tests:

```gdscript
func test_map_shop_node_routes_to_shop_screen(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_route_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	app.game.current_run = run
	var map_screen = app.game.router.go_to(SceneRouterScript.MAP)
	var shop_button := _find_node_by_text(map_screen, "node_0: shop") as Button
	if shop_button != null:
		shop_button.pressed.emit()
	var passed: bool = shop_button != null \
		and app.game.router.current_scene != null \
		and app.game.router.current_scene.name == "ShopScreen"
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_buy_card_saves_immediately(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_buy_card_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var card_button := _first_button_with_prefix(shop_screen, "BuyOffer_card_")
	var deck_size_before := run.deck_ids.size()
	if card_button != null:
		card_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = card_button != null \
		and loaded_run != null \
		and loaded_run.deck_ids.size() == deck_size_before + 1 \
		and not loaded_run.current_shop_state.is_empty() \
		and _has_sold_offer(loaded_run.current_shop_state, "card")
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_refresh_is_one_use_and_saved(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_refresh_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var refresh_button := _find_node_by_name(shop_screen, "RefreshButton") as Button
	if refresh_button != null:
		refresh_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var refreshed_once := loaded_run != null and loaded_run.current_shop_state.get("refresh_used") == true
	refresh_button = _find_node_by_name(app.game.router.current_scene, "RefreshButton") as Button
	var disabled_after_refresh := refresh_button != null and refresh_button.disabled
	var passed: bool = refreshed_once and disabled_after_refresh
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_remove_card_and_heal_services_sell_out(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_services_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	run.current_hp = 40
	run.max_hp = 72
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var heal_button := _find_node_by_name(shop_screen, "BuyOffer_heal_0") as Button
	if heal_button != null:
		heal_button.pressed.emit()
	var remove_button := _find_node_by_name(app.game.router.current_scene, "BuyOffer_remove_0") as Button
	if remove_button != null:
		remove_button.pressed.emit()
	var remove_card := _find_node_by_name(app.game.router.current_scene, "RemoveCard_0") as Button
	if remove_card != null:
		remove_card.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = loaded_run != null \
		and loaded_run.current_hp > 40 \
		and loaded_run.deck_ids.size() == 2 \
		and _offer_sold(loaded_run.current_shop_state, "heal_0") \
		and _offer_sold(loaded_run.current_shop_state, "remove_0")
	app.free()
	_delete_test_save(save_path)
	return passed

func test_main_menu_continue_resumes_in_progress_shop(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_continue_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	var catalog := ContentCatalogScript.new()
	catalog.load_default()
	ShopResolverScript.new().resolve(catalog, run)
	app.game.save_service.save_run(run)
	var main_menu = app.game.router.go_to(SceneRouterScript.MAIN_MENU)
	var continue_button := _find_continue_button(main_menu)
	if continue_button != null:
		continue_button.pressed.emit()
	var passed: bool = app.game.router.current_scene != null \
		and app.game.router.current_scene.name == "ShopScreen"
	app.free()
	_delete_test_save(save_path)
	return passed

func test_shop_screen_leave_clears_state_saves_and_advances(tree: SceneTree) -> bool:
	var save_path := "user://test_shop_leave_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("shop", true)
	run.gold = 300
	app.game.current_run = run
	var shop_screen = app.game.router.go_to(SceneRouterScript.SHOP)
	var leave_button := _find_node_by_name(shop_screen, "LeaveShopButton") as Button
	if leave_button != null:
		leave_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = leave_button != null \
		and loaded_run != null \
		and loaded_run.current_shop_state.is_empty() \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != shop_screen
	app.free()
	_delete_test_save(save_path)
	return passed
```

Append helpers near the existing smoke helpers:

```gdscript
func _first_button_with_prefix(root: Node, prefix: String) -> Button:
	if root == null:
		return null
	if root is Button and root.name.begins_with(prefix):
		return root as Button
	for child in root.get_children():
		var found := _first_button_with_prefix(child, prefix)
		if found != null:
			return found
	return null

func _has_sold_offer(shop_state: Dictionary, offer_type: String) -> bool:
	for offer in shop_state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("type") == offer_type and payload.get("sold") == true:
			return true
	return false

func _offer_sold(shop_state: Dictionary, offer_id: String) -> bool:
	for offer in shop_state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("id") == offer_id:
			return payload.get("sold") == true
	return false
```

- [x] **Step 2: Run tests and verify RED**

Run full tests.

Expected: smoke tests fail because `SceneRouter.SHOP` and `ShopScreen` do not exist.

- [x] **Step 3: Add shop route**

Modify `scripts/app/scene_router.gd`:

```gdscript
const SHOP := "res://scenes/shop/ShopScreen.tscn"
```

Modify `scripts/ui/map_screen.gd`:

```gdscript
func _enter_node(node) -> void:
	var app = get_tree().root.get_node("App")
	app.game.current_run.current_node_id = node.id
	if node.node_type == "combat" or node.node_type == "elite" or node.node_type == "boss":
		app.game.router.go_to(SceneRouterScript.COMBAT)
	elif node.node_type == "event":
		app.game.router.go_to(SceneRouterScript.EVENT)
	elif node.node_type == "shop":
		app.game.router.go_to(SceneRouterScript.SHOP)
	else:
		app.game.router.go_to(SceneRouterScript.REWARD)
```

- [x] **Step 4: Update main menu continue routing**

Modify `scripts/ui/main_menu.gd`:

```gdscript
func _on_continue_pressed() -> void:
	var app = get_tree().root.get_node("App")
	var loaded_run = _load_continuable_run(app)
	if loaded_run == null:
		_refresh_continue_button(app)
		return
	app.game.current_run = loaded_run
	if _should_resume_shop(loaded_run):
		app.game.router.go_to(SceneRouterScript.SHOP)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _should_resume_shop(run) -> bool:
	if run == null or run.current_shop_state.is_empty():
		return false
	if String(run.current_shop_state.get("node_id", "")) != run.current_node_id:
		return false
	for node in run.map_nodes:
		if node.id == run.current_node_id:
			return node.node_type == "shop"
	return false
```

- [x] **Step 5: Implement ShopScreen**

Create `scripts/ui/shop_screen.gd`:

```gdscript
extends Control

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const ShopResolver := preload("res://scripts/shop/shop_resolver.gd")
const ShopRunner := preload("res://scripts/shop/shop_runner.gd")

var catalog: ContentCatalog
var resolver := ShopResolver.new()
var runner := ShopRunner.new()
var title_label: Label
var gold_label: Label
var status_label: Label
var offer_container: VBoxContainer
var removal_container: VBoxContainer
var refresh_button: Button
var leave_button: Button
var selected_remove_offer_id := ""
var leave_requested := false

func _ready() -> void:
	_build_layout()
	_load_shop()
	_render()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "ShopTitle"
	title_label.text = "Shop"
	add_child(title_label)

	gold_label = Label.new()
	gold_label.name = "ShopGoldLabel"
	gold_label.position.y = 28
	add_child(gold_label)

	status_label = Label.new()
	status_label.name = "ShopStatusLabel"
	status_label.position.y = 52
	add_child(status_label)

	offer_container = VBoxContainer.new()
	offer_container.name = "ShopOfferContainer"
	offer_container.position = Vector2(16, 88)
	offer_container.size = Vector2(640, 320)
	add_child(offer_container)

	removal_container = VBoxContainer.new()
	removal_container.name = "ShopRemovalContainer"
	removal_container.position = Vector2(680, 88)
	removal_container.size = Vector2(320, 320)
	add_child(removal_container)

	refresh_button = Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.position = Vector2(16, 430)
	refresh_button.pressed.connect(_on_refresh_pressed)
	add_child(refresh_button)

	leave_button = Button.new()
	leave_button.name = "LeaveShopButton"
	leave_button.text = "Leave"
	leave_button.position = Vector2(160, 430)
	leave_button.pressed.connect(_on_leave_pressed)
	add_child(leave_button)

func _load_shop() -> void:
	catalog = ContentCatalog.new()
	catalog.load_default()
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	resolver.resolve(catalog, app.game.current_run)
	if resolver.created_new_state and app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)

func _render() -> void:
	_clear_children(offer_container)
	_clear_children(removal_container)
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or run.current_shop_state.is_empty():
		gold_label.text = "Gold: 0"
		status_label.text = "No shop available"
		refresh_button.disabled = true
		return
	gold_label.text = "Gold: %s" % run.gold
	status_label.text = ""
	for offer in run.current_shop_state.get("offers", []):
		_add_offer_row(offer as Dictionary)
	_refresh_refresh_button()
	_render_removal_choices()

func _add_offer_row(offer: Dictionary) -> void:
	var item := VBoxContainer.new()
	var offer_id := String(offer.get("id", ""))
	item.name = "ShopOffer_%s" % offer_id
	offer_container.add_child(item)

	var label := Label.new()
	label.text = _offer_label(offer)
	item.add_child(label)

	if bool(offer.get("sold", false)):
		var sold_label := Label.new()
		sold_label.text = "Sold out"
		item.add_child(sold_label)
		return

	var button := Button.new()
	button.name = "BuyOffer_%s" % offer_id
	button.text = _buy_button_text(offer)
	button.disabled = not _can_buy_offer(offer)
	button.pressed.connect(func(): _on_buy_pressed(offer_id))
	item.add_child(button)

func _offer_label(offer: Dictionary) -> String:
	var offer_type := String(offer.get("type", ""))
	var item_id := String(offer.get("item_id", ""))
	var price := int(offer.get("price", 0))
	match offer_type:
		"card":
			var card = catalog.get_card(item_id)
			if card != null:
				return "Card: %s [%s] (%s) - %s gold" % [card.id, card.rarity, card.cost, price]
			return "Card: %s - %s gold" % [item_id, price]
		"relic":
			var relic = catalog.get_relic(item_id)
			if relic != null:
				return "Relic: %s [%s] - %s gold" % [relic.id, relic.tier, price]
			return "Relic: %s - %s gold" % [item_id, price]
		"heal":
			return "Heal - %s gold" % price
		"remove":
			return "Remove a card - %s gold" % price
	return "Unknown offer"

func _buy_button_text(offer: Dictionary) -> String:
	if String(offer.get("type", "")) == "remove":
		return "Choose card"
	return "Buy"

func _can_buy_offer(offer: Dictionary) -> bool:
	var app = _app()
	var run = app.game.current_run if app != null else null
	var offer_type := String(offer.get("type", ""))
	if offer_type == "remove":
		return runner.can_buy_offer(catalog, run, String(offer.get("id", "")), _first_removable_card(run))
	return runner.can_buy_offer(catalog, run, String(offer.get("id", "")))

func _on_buy_pressed(offer_id: String) -> void:
	var offer := _find_offer(offer_id)
	if String(offer.get("type", "")) == "remove":
		selected_remove_offer_id = offer_id
		_render()
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if runner.buy_offer(catalog, app.game.current_run, offer_id):
		_save_and_render(app)

func _render_removal_choices() -> void:
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or selected_remove_offer_id.is_empty():
		return
	var label := Label.new()
	label.text = "Choose a card to remove"
	removal_container.add_child(label)
	for i in range(run.deck_ids.size()):
		var card_id := run.deck_ids[i]
		var button := Button.new()
		button.name = "RemoveCard_%s" % i
		button.text = card_id
		button.pressed.connect(func(): _on_remove_card_pressed(card_id))
		removal_container.add_child(button)

func _on_remove_card_pressed(card_id: String) -> void:
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if runner.buy_offer(catalog, app.game.current_run, selected_remove_offer_id, card_id):
		selected_remove_offer_id = ""
		_save_and_render(app)

func _on_refresh_pressed() -> void:
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if runner.refresh(catalog, app.game.current_run):
		_save_and_render(app)

func _refresh_refresh_button() -> void:
	var app = _app()
	var run = app.game.current_run if app != null else null
	refresh_button.text = "Refresh (%s gold)" % ShopResolver.REFRESH_PRICE
	refresh_button.disabled = not runner.can_refresh(catalog, run)

func _on_leave_pressed() -> void:
	if leave_requested:
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	leave_requested = true
	leave_button.disabled = true
	if not RunProgression.new().advance_current_node(app.game.current_run):
		push_error("Cannot advance shop; current map node is missing.")
		return
	app.game.current_run.current_shop_state = {}
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouterScript.SUMMARY)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _save_and_render(app) -> void:
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	_render()

func _find_offer(offer_id: String) -> Dictionary:
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null:
		return {}
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if String(payload.get("id", "")) == offer_id:
			return payload
	return {}

func _first_removable_card(run) -> String:
	if run == null or run.deck_ids.is_empty():
		return ""
	return String(run.deck_ids[0])

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _app():
	return get_tree().root.get_node_or_null("App")
```

Create `scenes/shop/ShopScreen.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/shop_screen.gd" id="1_shop"]

[node name="ShopScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_shop")
```

- [x] **Step 6: Run tests and verify GREEN for Task 4**

Run full tests. Expected: shop smoke tests pass, reward/event smoke tests still pass, full suite ends with `TESTS PASSED`.

- [x] **Step 7: Run Godot import check**

Run import check. Expected: exit 0 with no parse errors or missing resources.

- [x] **Step 8: Run Task 4 review gates**

Stage 1 Spec Compliance Review:

- Confirm shop nodes route to `ShopScreen`.
- Confirm entering a shop saves created shop state.
- Confirm card purchase, relic purchase, heal, remove, and refresh are exposed by UI.
- Confirm transactions save immediately.
- Confirm continue resumes in-progress shop.
- Confirm leaving shop clears state and advances through `RunProgression`.

Stage 2 Code Quality Review:

- Check UI does not duplicate transaction rules from `ShopRunner`.
- Check dynamic node names are stable.
- Check double-click leave guard exists.
- Check map advancement logic is not duplicated.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 9: Commit Task 4**

```powershell
rtk proxy git add scripts/ui/shop_screen.gd scenes/shop/ShopScreen.tscn scripts/app/scene_router.gd scripts/ui/map_screen.gd scripts/ui/main_menu.gd tests/smoke/test_scene_flow.gd
rtk proxy git commit -m "feat: add shop node scene flow"
```

## Task 5: Acceptance Docs and Final Verification

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-27-shop-node-foundation.md`

- [x] **Step 1: Update README Phase 2 progress**

Add this bullet under `## Phase 2 Progress` in `README.md`:

```markdown
- Shop node foundation: complete; map shop nodes now offer transaction-saved cards, relics, healing, removal, and one paid refresh before map advancement
```

- [x] **Step 2: Mark completed plan steps**

Update completed checkboxes in `docs/superpowers/plans/2026-04-27-shop-node-foundation.md` from `[ ]` to `[x]`.

Only mark a step complete after its command, review, or commit has actually happened.

- [x] **Step 3: Run final full tests**

Run full tests. Expected: `TESTS PASSED`.

- [x] **Step 4: Run final import check**

Run import check. Expected: exit 0 with no parse errors or missing resources.

- [x] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Verify every acceptance criterion in `docs/superpowers/specs/2026-04-27-shop-node-foundation-design.md`.
- Do not proceed to quality review if any requirement is missing.

Stage 2 Code Quality Review:

- Check GDScript typing, transaction boundaries, save compatibility, deterministic RNG, UI routing, and maintainability.
- Classify issues as Critical, Important, or Minor.

- [x] **Step 6: Commit acceptance docs**

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-27-shop-node-foundation.md
rtk proxy git commit -m "docs: record shop node foundation acceptance"
```

## Acceptance Criteria

- `shop` nodes enter `ShopScreen`.
- Shops show deterministic card, relic, heal, removal, and refresh options.
- Card offers come from the current character pool.
- Relic offers exclude already-owned relics.
- Prices follow the fixed table in the spec.
- Unaffordable, sold-out, invalid, full-HP heal, and impossible-removal actions are disabled or rejected without mutation.
- Successful card purchase adds exactly that card id to the deck.
- Successful relic purchase adds exactly that relic id to owned relics.
- Successful healing clamps current HP to max HP.
- Successful removal removes exactly one selected card id from the deck.
- Successful refresh costs gold, can happen once, rerolls only unsold card/relic offers, and preserves service offers.
- Entering a shop and each successful transaction saves `current_shop_state`.
- Save/load preserves sold-out state, refresh state, deck, relics, HP, and gold.
- Continue from main menu resumes an in-progress shop.
- Leaving the shop clears `current_shop_state`, advances map progress, saves, and routes to map or summary.
- Reward and event flows still advance correctly.
- Godot tests pass.
- Godot import check exits 0.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-27-shop-node-foundation.md`.

Recommended execution for this project: **Inline Execution on local `main`**, because `AGENTS.md` forbids worktrees and new branches. Use `superpowers:executing-plans` and `superpowers:test-driven-development`.
