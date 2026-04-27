# Reward Claim Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the post-combat reward screen where every generated reward item can be claimed or skipped before saving and advancing the map.

**Architecture:** Keep reward rules out of UI by adding `RewardResolver`, which builds a deterministic reward package for the current map node. Extend `RewardGenerator` with rarity-aware card draws, then make `RewardScreen` render generic reward items and apply only claimed rewards to `RunState`.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot dynamic UI nodes, custom headless test runner.

---

## Execution Context

The user explicitly prefers continuing development directly on local `main`, without worktrees.

If using subagents, `AGENTS.md` requires every development or review subagent to use extra-high 5.5 only. In this environment, spawn subagents with:

```text
model: gpt-5.5
reasoning_effort: xhigh
```

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

This plan implements `docs/superpowers/specs/2026-04-27-reward-claim-loop-design.md`.

Included:

- Extend `RewardGenerator` with rarity-weighted card rewards and boss rare-preferred card rewards.
- Add `RewardResolver` as the strategy layer for current-node reward packages.
- Register and add `test_reward_resolver.gd`.
- Replace the current minimal `RewardScreen` script with a generic claim/skip reward item UI.
- Extend smoke tests for reward claim/skip/save/map progression.
- Update README Phase 2 progress after acceptance.
- Update this plan's execution status after acceptance.

Excluded:

- No pending reward save schema.
- No resource-driven reward table system.
- No new card, relic, enemy, or save resource fields.
- No event-node reward flow.
- No relic-modified reward decorators.
- No presentation animation or reward VFX.
- No localization pass for reward button labels.

## File Structure

Create:

- `scripts/reward/reward_resolver.gd`: current-node reward strategy and reward package builder.
- `tests/unit/test_reward_resolver.gd`: focused resolver tests.

Modify:

- `scripts/reward/reward_generator.gd`: add weighted card and boss rare-preferred draw helpers.
- `tests/unit/test_reward_generator.gd`: add generator tests.
- `scripts/testing/test_runner.gd`: register `test_reward_resolver.gd`.
- `scripts/ui/reward_screen.gd`: render claim/skip reward items and continue gate.
- `tests/smoke/test_scene_flow.gd`: add reward screen smoke tests.
- `README.md`: record Phase 2 reward claim loop progress.
- `docs/superpowers/plans/2026-04-27-reward-claim-loop.md`: mark completed steps.

## Task 1: Add Rarity-Aware RewardGenerator Helpers

**Files:**

- Modify: `scripts/reward/reward_generator.gd`
- Modify: `tests/unit/test_reward_generator.gd`

- [ ] **Step 1: Add failing RewardGenerator tests**

Append these tests to `tests/unit/test_reward_generator.gd` after `test_alchemy_reward_draws_three_unique_cards_from_expanded_pool`:

```gdscript
func test_weighted_card_rewards_are_deterministic_and_character_scoped() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var weights := {
		"common": 75,
		"uncommon": 20,
		"rare": 5,
	}
	var first := generator.generate_weighted_card_reward(catalog, 501, "sword", "weighted_node", weights, 3)
	var second := generator.generate_weighted_card_reward(catalog, 501, "sword", "weighted_node", weights, 3)
	var ids: Array = first.get("card_ids", [])
	var sword_pool := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = first == second \
		and ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, sword_pool) \
		and not ids.has("alchemy.toxic_pill")
	assert(passed)
	return passed

func test_weighted_card_rewards_honor_requested_rarity_when_available() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_weighted_card_reward(catalog, 502, "sword", "rare_only", {
		"rare": 100,
	}, 1)
	var ids: Array = reward.get("card_ids", [])
	var card := catalog.get_card(String(ids[0])) if ids.size() > 0 else null
	var passed: bool = ids.size() == 1 \
		and card != null \
		and card.rarity == "rare"
	assert(passed)
	return passed

func test_rare_preferred_card_reward_uses_rare_first_and_fills_lower_rarities() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_rare_preferred_card_reward(catalog, 503, "sword", "boss_node", 3)
	var ids: Array = reward.get("card_ids", [])
	var rarities := _rarities_for_ids(catalog, ids)
	var sword_pool := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, sword_pool) \
		and rarities.size() == 3 \
		and rarities[0] == "rare" \
		and rarities.has("uncommon")
	assert(passed)
	return passed
```

Add this helper near the existing test helpers:

```gdscript
func _rarities_for_ids(catalog: ContentCatalog, card_ids: Array) -> Array[String]:
	var rarities: Array[String] = []
	for card_id in card_ids:
		var card := catalog.get_card(String(card_id))
		if card != null:
			rarities.append(card.rarity)
	return rarities
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `test_reward_generator.gd` fails because `generate_weighted_card_reward` and `generate_rare_preferred_card_reward` do not exist.

- [ ] **Step 3: Implement weighted card helpers**

Modify `scripts/reward/reward_generator.gd`.

Add this constant after the existing preloads:

```gdscript
const RARITY_FALLBACK_ORDER: Array[String] = ["rare", "uncommon", "common"]
```

Add these functions after `generate_card_reward(...)`:

```gdscript
func generate_weighted_card_reward(
	catalog: ContentCatalog,
	seed_value: int,
	character_id: String,
	context_key: String,
	rarity_weights: Dictionary,
	count: int = 3
) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:weighted_card:%s" % context_key)
	var candidates: Array = catalog.get_cards_for_character(character_id)
	var card_ids: Array[String] = []
	while card_ids.size() < count and not candidates.is_empty():
		var rarity := _pick_weighted_rarity(rng, rarity_weights)
		var matching := _cards_with_rarity(candidates, rarity)
		var card: CardDef = rng.pick(matching) if not matching.is_empty() else rng.pick(candidates)
		card_ids.append(card.id)
		candidates.erase(card)
	return {
		"type": "card",
		"character_id": character_id,
		"card_ids": card_ids,
	}

func generate_rare_preferred_card_reward(
	catalog: ContentCatalog,
	seed_value: int,
	character_id: String,
	context_key: String,
	count: int = 3
) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:rare_preferred_card:%s" % context_key)
	var pool: Array = catalog.get_cards_for_character(character_id)
	var card_ids: Array[String] = []
	for rarity in RARITY_FALLBACK_ORDER:
		var cards := rng.shuffle_copy(_cards_with_rarity(pool, rarity))
		for card: CardDef in cards:
			if card_ids.size() >= count:
				break
			if not card_ids.has(card.id):
				card_ids.append(card.id)
		if card_ids.size() >= count:
			break
	return {
		"type": "card",
		"character_id": character_id,
		"card_ids": card_ids,
	}
```

Add these private helpers near `_gold_bounds_for_tier(...)`:

```gdscript
func _pick_weighted_rarity(rng: RngService, rarity_weights: Dictionary) -> String:
	var total := 0
	for rarity in rarity_weights.keys():
		total += max(0, int(rarity_weights[rarity]))
	if total <= 0:
		return "common"
	var roll := rng.next_int(1, total)
	var cumulative := 0
	for rarity in rarity_weights.keys():
		cumulative += max(0, int(rarity_weights[rarity]))
		if roll <= cumulative:
			return String(rarity)
	return "common"

func _cards_with_rarity(cards: Array, rarity: String) -> Array:
	var result: Array = []
	for card: CardDef in cards:
		if card.rarity == rarity:
			result.append(card)
	return result
```

- [ ] **Step 4: Run tests and verify GREEN for Task 1**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all reward generator tests pass and full suite ends with `TESTS PASSED`.

- [ ] **Step 5: Run Task 1 review gates**

Stage 1 Spec Compliance Review:

- Confirm normal weighted card draw accepts explicit rarity weights.
- Confirm boss rare-preferred draw selects rare cards first and fills from lower rarities.
- Confirm card rewards remain character-scoped and unique.
- Confirm existing `generate_card_reward`, `generate_gold_reward`, and `generate_relic_reward` behavior remains available.

Stage 2 Code Quality Review:

- Check deterministic RNG context labels are distinct from existing card rewards.
- Check no UI or resolver rule decisions were added to `RewardGenerator`.
- Check helper functions are typed and small.
- Classify issues as Critical, Important, or Minor.

- [ ] **Step 6: Commit Task 1**

```powershell
git add scripts/reward/reward_generator.gd tests/unit/test_reward_generator.gd
git commit -m "feat: add rarity-aware reward draws"
```

## Task 2: Add RewardResolver Strategy Layer

**Files:**

- Create: `scripts/reward/reward_resolver.gd`
- Create: `tests/unit/test_reward_resolver.gd`
- Modify: `scripts/testing/test_runner.gd`

- [ ] **Step 1: Register the new resolver test file**

Modify `scripts/testing/test_runner.gd` and insert the resolver test immediately after `test_reward_generator.gd`:

```gdscript
const TEST_FILES := [
	"res://tests/unit/test_rng_service.gd",
	"res://tests/unit/test_resource_schemas.gd",
	"res://tests/unit/test_content_catalog.gd",
	"res://tests/unit/test_reward_generator.gd",
	"res://tests/unit/test_reward_resolver.gd",
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

- [ ] **Step 2: Write failing RewardResolver tests**

Create `tests/unit/test_reward_resolver.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_combat_node_generates_card_choice_and_gold_only() -> bool:
	var rewards := RewardResolver.new().resolve(_catalog(), _run_for_node("combat", 111))
	var card := _find_reward(rewards, "card_choice")
	var gold := _find_reward(rewards, "gold")
	var relic := _find_reward(rewards, "relic")
	var passed: bool = rewards.size() == 2 \
		and not card.is_empty() \
		and not gold.is_empty() \
		and relic.is_empty() \
		and _array_value_count(card.get("card_ids", [])) == 3 \
		and int(gold.get("amount", 0)) >= 8 \
		and int(gold.get("amount", 0)) <= 14
	assert(passed)
	return passed

func test_elite_node_generates_card_gold_and_deterministic_relic_chance() -> bool:
	var catalog := _catalog()
	var saw_relic := false
	var saw_no_relic := false
	for seed in range(1, 80):
		var rewards := RewardResolver.new().resolve(catalog, _run_for_node("elite", seed))
		var card := _find_reward(rewards, "card_choice")
		var gold := _find_reward(rewards, "gold")
		var relic := _find_reward(rewards, "relic")
		if relic.is_empty():
			saw_no_relic = true
		else:
			saw_relic = saw_relic or String(relic.get("tier", "")) == "uncommon"
		if not card.is_empty() and not gold.is_empty() and saw_relic and saw_no_relic:
			break
	var passed: bool = saw_relic and saw_no_relic
	assert(passed)
	return passed

func test_boss_node_generates_rare_preferred_card_gold_and_rare_relic() -> bool:
	var catalog := _catalog()
	var rewards := RewardResolver.new().resolve(catalog, _run_for_node("boss", 222))
	var card := _find_reward(rewards, "card_choice")
	var gold := _find_reward(rewards, "gold")
	var relic := _find_reward(rewards, "relic")
	var card_ids: Array = card.get("card_ids", [])
	var first_card := catalog.get_card(String(card_ids[0])) if card_ids.size() > 0 else null
	var passed: bool = rewards.size() == 3 \
		and card_ids.size() == 3 \
		and first_card != null \
		and first_card.rarity == "rare" \
		and int(gold.get("amount", 0)) >= 40 \
		and int(gold.get("amount", 0)) <= 60 \
		and String(relic.get("tier", "")) == "rare" \
		and not String(relic.get("relic_id", "")).is_empty()
	assert(passed)
	return passed

func test_missing_current_node_returns_empty_reward_package() -> bool:
	var run := _run_for_node("combat", 333)
	run.current_node_id = "missing_node"
	var rewards := RewardResolver.new().resolve(_catalog(), run)
	var passed := rewards.is_empty()
	assert(passed)
	return passed

func test_empty_relic_pool_omits_relic_reward_item() -> bool:
	var catalog := _catalog()
	catalog.relics_by_id.clear()
	var rewards := RewardResolver.new().resolve(catalog, _run_for_node("boss", 444))
	var card := _find_reward(rewards, "card_choice")
	var gold := _find_reward(rewards, "gold")
	var relic := _find_reward(rewards, "relic")
	var passed: bool = rewards.size() == 2 \
		and not card.is_empty() \
		and not gold.is_empty() \
		and relic.is_empty()
	assert(passed)
	return passed

func test_resolver_is_deterministic_for_same_run_context() -> bool:
	var catalog := _catalog()
	var run := _run_for_node("elite", 555)
	var first := RewardResolver.new().resolve(catalog, run)
	var second := RewardResolver.new().resolve(catalog, run)
	var passed := first == second
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run_for_node(node_type: String, seed_value: int) -> RunState:
	var run := RunState.new()
	run.seed_value = seed_value
	run.character_id = "sword"
	run.current_node_id = "node_0"
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	var node := MapNodeState.new("node_0", 0, node_type)
	node.unlocked = true
	run.map_nodes = [node]
	return run

func _find_reward(rewards: Array[Dictionary], reward_type: String) -> Dictionary:
	for reward in rewards:
		if String(reward.get("type", "")) == reward_type:
			return reward
	return {}

func _array_value_count(values: Array) -> int:
	return values.size()
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `test_reward_resolver.gd` fails to load because `res://scripts/reward/reward_resolver.gd` does not exist.

- [ ] **Step 4: Implement RewardResolver**

Create `scripts/reward/reward_resolver.gd`:

```gdscript
class_name RewardResolver
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RewardGenerator := preload("res://scripts/reward/reward_generator.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

const NORMAL_CARD_WEIGHTS := {
	"common": 75,
	"uncommon": 20,
	"rare": 5,
}
const ELITE_CARD_WEIGHTS := {
	"common": 45,
	"uncommon": 40,
	"rare": 15,
}
const ELITE_RELIC_CHANCE := 0.5

var generator := RewardGenerator.new()

func resolve(catalog: ContentCatalog, run: RunState) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if catalog == null or run == null:
		return rewards
	var node := _current_node(run)
	if node == null:
		return rewards
	match node.node_type:
		"elite":
			_append_weighted_card_choice(rewards, catalog, run, node, ELITE_CARD_WEIGHTS)
			_append_gold(rewards, run, node, "elite")
			if _should_offer_elite_relic(run, node):
				_append_relic(rewards, catalog, run, node, "uncommon")
		"boss":
			_append_boss_card_choice(rewards, catalog, run, node)
			_append_gold(rewards, run, node, "boss")
			_append_relic(rewards, catalog, run, node, "rare")
		_:
			_append_weighted_card_choice(rewards, catalog, run, node, NORMAL_CARD_WEIGHTS)
			_append_gold(rewards, run, node, "normal")
	return rewards

func _append_weighted_card_choice(
	rewards: Array[Dictionary],
	catalog: ContentCatalog,
	run: RunState,
	node: MapNodeState,
	rarity_weights: Dictionary
) -> void:
	var reward := generator.generate_weighted_card_reward(
		catalog,
		run.seed_value,
		run.character_id,
		"%s:%s" % [node.id, node.node_type],
		rarity_weights,
		3
	)
	_append_card_choice_from_reward(rewards, node, reward)

func _append_boss_card_choice(
	rewards: Array[Dictionary],
	catalog: ContentCatalog,
	run: RunState,
	node: MapNodeState
) -> void:
	var reward := generator.generate_rare_preferred_card_reward(
		catalog,
		run.seed_value,
		run.character_id,
		"%s:%s" % [node.id, node.node_type],
		3
	)
	_append_card_choice_from_reward(rewards, node, reward)

func _append_card_choice_from_reward(
	rewards: Array[Dictionary],
	node: MapNodeState,
	reward: Dictionary
) -> void:
	var card_ids: Array = reward.get("card_ids", [])
	if card_ids.is_empty():
		return
	rewards.append({
		"id": "card:%s" % node.id,
		"type": "card_choice",
		"card_ids": card_ids,
	})

func _append_gold(rewards: Array[Dictionary], run: RunState, node: MapNodeState, tier: String) -> void:
	var reward := generator.generate_gold_reward(run.seed_value, node.id, tier)
	rewards.append({
		"id": "gold:%s" % node.id,
		"type": "gold",
		"amount": int(reward.get("amount", 0)),
		"tier": tier,
	})

func _append_relic(
	rewards: Array[Dictionary],
	catalog: ContentCatalog,
	run: RunState,
	node: MapNodeState,
	tier: String
) -> void:
	var reward := generator.generate_relic_reward(catalog, run.seed_value, node.id, tier)
	var relic_id := String(reward.get("relic_id", ""))
	if relic_id.is_empty():
		return
	rewards.append({
		"id": "relic:%s" % node.id,
		"type": "relic",
		"relic_id": relic_id,
		"tier": tier,
	})

func _should_offer_elite_relic(run: RunState, node: MapNodeState) -> bool:
	var rng := RngService.new(run.seed_value).fork("reward:elite_relic:%s" % node.id)
	return rng.next_float() < ELITE_RELIC_CHANCE

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
```

- [ ] **Step 5: Run tests and verify GREEN for Task 2**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `test_reward_resolver.gd` runs and passes. Full suite ends with `TESTS PASSED`.

- [ ] **Step 6: Run Godot import check**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

Expected: exit 0 with no parse errors or missing resources.

- [ ] **Step 7: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- Confirm combat nodes produce card choice and gold only.
- Confirm elite nodes produce card choice, gold, and deterministic 50% chance for uncommon relic.
- Confirm boss nodes produce rare-preferred card choice, boss gold, and guaranteed rare relic.
- Confirm empty relic pool omits relic reward item.
- Confirm missing current node returns empty package.

Stage 2 Code Quality Review:

- Check reward rules live in `RewardResolver`, not UI.
- Check resolver API is narrow: `resolve(catalog, run) -> Array[Dictionary]`.
- Check RNG context labels are deterministic and node-scoped.
- Check reward item dictionaries match the spec shape.
- Classify issues as Critical, Important, or Minor.

- [ ] **Step 8: Commit Task 2**

```powershell
git add scripts/reward/reward_resolver.gd scripts/testing/test_runner.gd tests/unit/test_reward_resolver.gd
git commit -m "feat: resolve node reward packages"
```

## Task 3: Add Claim/Skip RewardScreen Flow

**Files:**

- Modify: `scripts/ui/reward_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [ ] **Step 1: Add failing reward screen smoke tests**

Modify `tests/smoke/test_scene_flow.gd`.

Add this preload near the existing preloads:

```gdscript
const MapNodeStateScript := preload("res://scripts/run/map_node_state.gd")
```

Append these tests after `test_combat_screen_creates_session_and_cancels_pending_card`:

```gdscript
func test_reward_screen_claims_card_skips_gold_and_saves_on_continue(tree: SceneTree) -> bool:
	var save_path := "user://test_reward_screen_claim_skip_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("combat", true)
	var deck_size_before := run.deck_ids.size()
	var gold_before := run.gold
	app.game.current_run = run

	var reward_screen = app.game.router.go_to(SceneRouterScript.REWARD)
	var continue_button := _find_node_by_name(reward_screen, "ContinueButton") as Button
	var card_button := _find_node_by_name(reward_screen, "ClaimCard_0_0") as Button
	var disabled_before: bool = continue_button != null and continue_button.disabled
	if card_button != null:
		card_button.pressed.emit()
	var deck_claimed: bool = run.deck_ids.size() == deck_size_before + 1
	var still_disabled_after_card: bool = continue_button != null and continue_button.disabled
	var skip_gold := _find_node_by_name(reward_screen, "SkipReward_1") as Button
	if skip_gold != null:
		skip_gold.pressed.emit()
	var enabled_after_all_resolved: bool = continue_button != null and not continue_button.disabled
	if continue_button != null:
		continue_button.pressed.emit()
	var loaded_run = app.game.save_service.load_run()
	var passed: bool = disabled_before \
		and deck_claimed \
		and still_disabled_after_card \
		and enabled_after_all_resolved \
		and run.gold == gold_before \
		and loaded_run != null \
		and loaded_run.deck_ids.size() == run.deck_ids.size() \
		and loaded_run.gold == gold_before \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != reward_screen
	app.free()
	_delete_test_save(save_path)
	return passed

func test_reward_screen_can_claim_boss_relic_and_skip_remaining_rewards(tree: SceneTree) -> bool:
	var save_path := "user://test_reward_screen_relic_claim_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("boss", false)
	app.game.current_run = run

	var reward_screen = app.game.router.go_to(SceneRouterScript.REWARD)
	var skip_card := _find_node_by_name(reward_screen, "SkipReward_0") as Button
	var skip_gold := _find_node_by_name(reward_screen, "SkipReward_1") as Button
	var claim_relic := _find_node_by_name(reward_screen, "ClaimRelic_2") as Button
	if skip_card != null:
		skip_card.pressed.emit()
	skip_gold = _find_node_by_name(reward_screen, "SkipReward_1") as Button
	if skip_gold != null:
		skip_gold.pressed.emit()
	claim_relic = _find_node_by_name(reward_screen, "ClaimRelic_2") as Button
	if claim_relic != null:
		claim_relic.pressed.emit()
	var continue_button := _find_node_by_name(reward_screen, "ContinueButton") as Button
	var passed: bool = claim_relic != null \
		and run.relic_ids.size() == 1 \
		and not run.relic_ids[0].is_empty() \
		and continue_button != null \
		and not continue_button.disabled
	app.free()
	_delete_test_save(save_path)
	return passed
```

Add these helpers near the existing smoke test helpers:

```gdscript
func _reward_run(node_type: String, include_next_node: bool) -> RunStateScript:
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.gold = 10
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	run.current_node_id = "node_0"
	var current := MapNodeStateScript.new("node_0", 0, node_type)
	current.unlocked = true
	var nodes: Array = [current]
	if include_next_node:
		nodes.append(MapNodeStateScript.new("node_1", 1, "combat"))
	run.map_nodes = nodes
	return run

func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: new reward screen smoke tests fail because `RewardScreen` does not create `ContinueButton`, claim buttons, skip buttons, or reward item state.

- [ ] **Step 3: Replace RewardScreen with claim/skip UI**

Replace the body of `scripts/ui/reward_screen.gd` with:

```gdscript
extends Control

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

const STATE_AVAILABLE := "available"
const STATE_CLAIMED := "claimed"
const STATE_SKIPPED := "skipped"

var catalog := ContentCatalog.new()
var resolver := RewardResolver.new()
var rewards: Array[Dictionary] = []
var reward_states := {}
var reward_container: VBoxContainer
var continue_button: Button
var status_label: Label

func _ready() -> void:
	_build_layout()
	_load_rewards()
	_render_rewards()
	_refresh_continue_button()

func _build_layout() -> void:
	var title := Label.new()
	title.name = "RewardTitle"
	title.text = "Rewards"
	add_child(title)

	status_label = Label.new()
	status_label.name = "RewardStatus"
	status_label.position.y = 28
	add_child(status_label)

	reward_container = VBoxContainer.new()
	reward_container.name = "RewardContainer"
	reward_container.position = Vector2(16, 64)
	add_child(reward_container)

	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	continue_button.position = Vector2(16, 320)
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

func _load_rewards() -> void:
	catalog.load_default()
	var app = _app()
	if app == null or app.game.current_run == null:
		rewards.clear()
		return
	rewards = resolver.resolve(catalog, app.game.current_run)
	reward_states.clear()
	for i in range(rewards.size()):
		reward_states[_item_id(rewards[i], i)] = STATE_AVAILABLE

func _render_rewards() -> void:
	_clear_children(reward_container)
	if rewards.is_empty():
		var empty := Label.new()
		empty.name = "NoRewardsLabel"
		empty.text = "No rewards"
		reward_container.add_child(empty)
	for i in range(rewards.size()):
		_add_reward_item(rewards[i], i)
	status_label.text = "Resolve all rewards to continue."
	if _all_rewards_resolved():
		status_label.text = "Rewards resolved."

func _add_reward_item(item: Dictionary, index: int) -> void:
	var box := VBoxContainer.new()
	box.name = "RewardItem_%s" % index
	reward_container.add_child(box)

	var state := _item_state(item, index)
	var label := Label.new()
	label.name = "RewardLabel_%s" % index
	label.text = _reward_label(item, state)
	box.add_child(label)

	if state != STATE_AVAILABLE:
		return
	match String(item.get("type", "")):
		"card_choice":
			_add_card_choice_buttons(box, item, index)
		"gold":
			_add_gold_button(box, item, index)
		"relic":
			_add_relic_button(box, item, index)
		_:
			_add_skip_button(box, index)
	_add_skip_button(box, index)

func _add_card_choice_buttons(parent: Node, item: Dictionary, index: int) -> void:
	var card_ids: Array = item.get("card_ids", [])
	for card_index in range(card_ids.size()):
		var selected_card_id := String(card_ids[card_index])
		var item_index := index
		var button := Button.new()
		button.name = "ClaimCard_%s_%s" % [index, card_index]
		button.text = "Take %s" % _card_label(selected_card_id)
		button.pressed.connect(func(): _claim_card(item_index, selected_card_id))
		parent.add_child(button)

func _add_gold_button(parent: Node, item: Dictionary, index: int) -> void:
	var amount := int(item.get("amount", 0))
	var button := Button.new()
	button.name = "ClaimGold_%s" % index
	button.text = "Take %s gold" % amount
	button.pressed.connect(func(): _claim_gold(index))
	parent.add_child(button)

func _add_relic_button(parent: Node, item: Dictionary, index: int) -> void:
	var relic_id := String(item.get("relic_id", ""))
	var button := Button.new()
	button.name = "ClaimRelic_%s" % index
	button.text = "Take %s" % relic_id
	button.pressed.connect(func(): _claim_relic(index))
	parent.add_child(button)

func _add_skip_button(parent: Node, index: int) -> void:
	var button := Button.new()
	button.name = "SkipReward_%s" % index
	button.text = "Skip"
	button.pressed.connect(func(): _skip_reward(index))
	parent.add_child(button)

func _claim_card(index: int, card_id: String) -> void:
	if not _is_reward_available(index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	app.game.current_run.deck_ids.append(card_id)
	_resolve_reward(index, STATE_CLAIMED)

func _claim_gold(index: int) -> void:
	if not _is_reward_available(index):
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	app.game.current_run.gold += int(rewards[index].get("amount", 0))
	_resolve_reward(index, STATE_CLAIMED)

func _claim_relic(index: int) -> void:
	if not _is_reward_available(index):
		return
	var relic_id := String(rewards[index].get("relic_id", ""))
	if relic_id.is_empty():
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	app.game.current_run.relic_ids.append(relic_id)
	_resolve_reward(index, STATE_CLAIMED)

func _skip_reward(index: int) -> void:
	if not _is_reward_available(index):
		return
	_resolve_reward(index, STATE_SKIPPED)

func _resolve_reward(index: int, state: String) -> void:
	reward_states[_item_id(rewards[index], index)] = state
	_render_rewards()
	_refresh_continue_button()

func _refresh_continue_button() -> void:
	if continue_button == null:
		return
	continue_button.disabled = not _all_rewards_resolved()

func _on_continue_pressed() -> void:
	if not _all_rewards_resolved():
		return
	var app = _app()
	if app == null or app.game.current_run == null:
		return
	if not _unlock_next_node(app.game.current_run):
		push_error("Cannot advance run; current map node is missing.")
		return
	if app.game.save_service:
		app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouterScript.SUMMARY)
	else:
		app.game.router.go_to(SceneRouterScript.MAP)

func _unlock_next_node(run) -> bool:
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

func _all_rewards_resolved() -> bool:
	for i in range(rewards.size()):
		if _item_state(rewards[i], i) == STATE_AVAILABLE:
			return false
	return true

func _is_reward_available(index: int) -> bool:
	if index < 0 or index >= rewards.size():
		return false
	return _item_state(rewards[index], index) == STATE_AVAILABLE

func _item_state(item: Dictionary, index: int) -> String:
	return String(reward_states.get(_item_id(item, index), STATE_AVAILABLE))

func _item_id(item: Dictionary, index: int) -> String:
	return String(item.get("id", "reward:%s" % index))

func _reward_label(item: Dictionary, state: String) -> String:
	var suffix := "" if state == STATE_AVAILABLE else " [%s]" % state
	match String(item.get("type", "")):
		"card_choice":
			return "Choose a card%s" % suffix
		"gold":
			return "Gold: %s%s" % [int(item.get("amount", 0)), suffix]
		"relic":
			return "Relic: %s%s" % [String(item.get("relic_id", "")), suffix]
		_:
			return "Reward%s" % suffix

func _card_label(card_id: String) -> String:
	var card = catalog.get_card(card_id)
	if card == null:
		return card_id
	return "%s [%s]" % [card.id, card.rarity]

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _app():
	return get_tree().root.get_node_or_null("App")
```

- [ ] **Step 4: Run tests and verify GREEN for Task 3**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: reward screen smoke tests pass and full suite ends with `TESTS PASSED`.

- [ ] **Step 5: Run Godot import check**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

Expected: exit 0 with no parse errors or missing resources.

- [ ] **Step 6: Run Task 3 review gates**

Stage 1 Spec Compliance Review:

- Confirm every reward item can be claimed or skipped.
- Confirm continue is disabled until all items are resolved.
- Confirm card claim mutates only `deck_ids`.
- Confirm gold claim mutates only `gold`.
- Confirm relic claim mutates only `relic_ids`.
- Confirm skipping does not mutate run reward fields.
- Confirm map progress and save happen on continue, not on each claim.

Stage 2 Code Quality Review:

- Check reward UI state is generic enough for future reward item types.
- Check each reward item is idempotent after claimed/skipped.
- Check reward rules do not live in `RewardScreen`.
- Check smoke tests use real scene routing and save service.
- Classify issues as Critical, Important, or Minor.

- [ ] **Step 7: Commit Task 3**

```powershell
git add scripts/ui/reward_screen.gd tests/smoke/test_scene_flow.gd
git commit -m "feat: add selectable reward screen"
```

## Task 4: Acceptance Docs and Final Verification

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-27-reward-claim-loop.md`

- [ ] **Step 1: Update README Phase 2 progress**

Add this bullet under `## Phase 2 Progress` in `README.md`:

```markdown
- Reward claim loop: complete; combat rewards now generate card, gold, and relic choices that can be claimed or skipped before map advancement
```

- [ ] **Step 2: Mark completed plan steps**

Update completed checkboxes in `docs/superpowers/plans/2026-04-27-reward-claim-loop.md` from `[ ]` to `[x]`.

Only mark a step complete after its command, review, or commit has actually happened.

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

- Verify every acceptance criterion in `docs/superpowers/specs/2026-04-27-reward-claim-loop-design.md`.
- Do not proceed to quality review if any requirement is missing.

Stage 2 Code Quality Review:

- Check GDScript typing, UI state boundaries, resource loading, save boundaries, deterministic RNG, duplication, and maintainability.
- Classify issues as Critical, Important, or Minor.

- [ ] **Step 6: Commit acceptance docs**

```powershell
git add README.md docs/superpowers/plans/2026-04-27-reward-claim-loop.md
git commit -m "docs: record reward claim loop acceptance"
```

## Acceptance Criteria

- Winning combat leads to a reward screen with generated rewards for the current node type.
- Combat rewards include card choice and gold, both skippable.
- Elite rewards include card choice, gold, and a deterministic 50% chance to show an uncommon relic, all skippable.
- Boss rewards include rare-preferred card choice, boss gold, and a guaranteed rare relic, all skippable.
- Claiming a card adds exactly one selected card to `RunState.deck_ids`.
- Claiming gold adds exactly the displayed amount to `RunState.gold`.
- Claiming a relic adds exactly one relic id to `RunState.relic_ids`.
- Skipping any item leaves the relevant run field unchanged.
- Continue stays disabled until all reward items are claimed or skipped.
- Pressing continue saves once, marks the current node visited, unlocks the next node or completes the run, and routes correctly.
- Existing saves remain compatible.
- No pending reward save schema was added.
- Reward rules live in `RewardResolver`, not `RewardScreen`.
- Godot tests pass.
- Godot import check exits 0.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-27-reward-claim-loop.md`.

Recommended execution: **Subagent-Driven** if using subagents. Per `AGENTS.md`, every development and review subagent must use extra-high 5.5 only.

User preference for this session: continue directly on local `main`, without worktrees.
