# Dual Starter Card Pools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add eight starter card resources for sword cultivator and eight starter card resources for alchemy cultivator while preserving role-specific reward pools.

**Architecture:** New cards are plain `CardDef` `.tres` resources with embedded `EffectDef` sub-resources. `ContentCatalog.DEFAULT_CARD_PATHS` explicitly lists all new resources, `CharacterDef.card_pool_ids` references them by id, and existing validation/reward tests prove catalog loading, localization, pool isolation, and resource effect composition.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resource `.tres`, gettext `.po`, custom headless test runner, PowerShell local verification.

---

## Execution Status

Completed on 2026-04-26 in the current `main` workspace.

- Expanded sword starter card pool to 9 total catalog cards.
- Expanded alchemy starter card pool to 9 total catalog cards.
- Verified catalog, reward, resource effect composition, and Godot import checks.

## Execution Constraints

- Work directly in `D:\prj\Slay the Spire 2` on `main`; do not create a worktree.
- If subagents are used, they must use model `gpt-5.5` with `xhigh` reasoning, per `AGENTS.md`.
- Follow TDD: write or update tests first, run them to see the expected failure, then implement resources/code, then rerun tests.
- After each Godot feature, run the two-stage review required by `AGENTS.md`:
  1. Spec Compliance Review.
  2. Code Quality Review.

## Scope Check

This plan implements `docs/superpowers/specs/2026-04-26-dual-starter-card-pools-design.md`.

Included:

- 16 new starter card resources.
- Character card pool updates.
- Explicit catalog path updates.
- Localization key additions.
- Catalog, reward, and combat logic tests.
- Final Godot test/import verification.

Excluded:

- New combat effect types.
- Card art, UI, animation, audio, upgrades, events, shop, relics, enemies, and multi-enemy encounter logic.

## File Structure

Create:

```text
resources/cards/sword/guard.tres
resources/cards/sword/flash_cut.tres
resources/cards/sword/qi_surge.tres
resources/cards/sword/break_stance.tres
resources/cards/sword/cloud_step.tres
resources/cards/sword/focused_slash.tres
resources/cards/sword/sword_resonance.tres
resources/cards/sword/horizon_arc.tres
resources/cards/alchemy/healing_draught.tres
resources/cards/alchemy/poison_mist.tres
resources/cards/alchemy/inner_fire_pill.tres
resources/cards/alchemy/cauldron_burst.tres
resources/cards/alchemy/calming_powder.tres
resources/cards/alchemy/toxin_needle.tres
resources/cards/alchemy/spirit_distill.tres
resources/cards/alchemy/cinnabar_seal.tres
```

Modify:

```text
scripts/content/content_catalog.gd
resources/characters/sword_cultivator.tres
resources/characters/alchemy_cultivator.tres
localization/zh_CN.po
tests/unit/test_content_catalog.gd
tests/unit/test_reward_generator.gd
tests/unit/test_combat_engine.gd
README.md
docs/superpowers/plans/2026-04-26-dual-starter-card-pools.md
```

## Command Conventions

Use:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
& $env:GODOT4 --headless --path . --quit
```

Expected final test output:

```text
TESTS PASSED
```

## Card Data Reference

### Sword Cards

| id | file | cost | type | rarity | effects |
| --- | --- | --- | --- | --- | --- |
| `sword.guard` | `resources/cards/sword/guard.tres` | 1 | `skill` | `common` | `block 7 -> player` |
| `sword.flash_cut` | `resources/cards/sword/flash_cut.tres` | 1 | `attack` | `common` | `damage 4 -> enemy`, `draw_card 1 -> player` |
| `sword.qi_surge` | `resources/cards/sword/qi_surge.tres` | 0 | `skill` | `uncommon` | `gain_energy 1 -> player` |
| `sword.break_stance` | `resources/cards/sword/break_stance.tres` | 2 | `attack` | `uncommon` | `damage 10 -> enemy`, `apply_status 1 broken_stance -> enemy` |
| `sword.cloud_step` | `resources/cards/sword/cloud_step.tres` | 1 | `skill` | `common` | `block 4 -> player`, `draw_card 1 -> player` |
| `sword.focused_slash` | `resources/cards/sword/focused_slash.tres` | 1 | `attack` | `common` | `damage 8 -> enemy` |
| `sword.sword_resonance` | `resources/cards/sword/sword_resonance.tres` | 1 | `skill` | `uncommon` | `block 3 -> player`, `apply_status 2 sword_focus -> player` |
| `sword.horizon_arc` | `resources/cards/sword/horizon_arc.tres` | 2 | `attack` | `uncommon` | `damage 6 -> enemy`, `block 4 -> player` |

### Alchemy Cards

| id | file | cost | type | rarity | effects |
| --- | --- | --- | --- | --- | --- |
| `alchemy.healing_draught` | `resources/cards/alchemy/healing_draught.tres` | 1 | `skill` | `common` | `heal 5 -> player` |
| `alchemy.poison_mist` | `resources/cards/alchemy/poison_mist.tres` | 1 | `skill` | `common` | `apply_status 3 poison -> enemy` |
| `alchemy.inner_fire_pill` | `resources/cards/alchemy/inner_fire_pill.tres` | 0 | `skill` | `uncommon` | `gain_energy 1 -> player`, `draw_card 1 -> player` |
| `alchemy.cauldron_burst` | `resources/cards/alchemy/cauldron_burst.tres` | 2 | `attack` | `uncommon` | `damage 7 -> enemy`, `block 4 -> player` |
| `alchemy.calming_powder` | `resources/cards/alchemy/calming_powder.tres` | 1 | `skill` | `common` | `block 6 -> player`, `heal 2 -> player` |
| `alchemy.toxin_needle` | `resources/cards/alchemy/toxin_needle.tres` | 1 | `attack` | `common` | `damage 3 -> enemy`, `apply_status 2 poison -> enemy` |
| `alchemy.spirit_distill` | `resources/cards/alchemy/spirit_distill.tres` | 1 | `skill` | `uncommon` | `draw_card 2 -> player` |
| `alchemy.cinnabar_seal` | `resources/cards/alchemy/cinnabar_seal.tres` | 2 | `skill` | `uncommon` | `block 8 -> player`, `apply_status 1 elixir_guard -> player` |

Every new card must have:

```gdscript
character_id = "sword" # or "alchemy"
pool_tags = Array[String](["starter"])
reward_weight = 100
```

## Task 1: Catalog and Reward Tests

**Files:**

- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `tests/unit/test_reward_generator.gd`

- [ ] **Step 1: Write failing catalog tests**

Append these tests before `_ids()` in `tests/unit/test_content_catalog.gd`:

```gdscript
func test_default_catalog_loads_dual_starter_card_pool_counts() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var sword_ids := _ids(catalog.get_cards_for_character("sword"))
	var alchemy_ids := _ids(catalog.get_cards_for_character("alchemy"))
	var passed: bool = catalog.cards_by_id.size() == 18 \
		and sword_ids.size() == 9 \
		and alchemy_ids.size() == 9
	assert(passed)
	return passed

func test_dual_starter_card_pools_are_character_isolated() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var sword_ids := _ids(catalog.get_cards_for_character("sword"))
	var alchemy_ids := _ids(catalog.get_cards_for_character("alchemy"))
	var expected_sword: Array[String] = [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.break_stance",
		"sword.cloud_step",
		"sword.focused_slash",
		"sword.sword_resonance",
		"sword.horizon_arc",
	]
	var expected_alchemy: Array[String] = [
		"alchemy.toxic_pill",
		"alchemy.healing_draught",
		"alchemy.poison_mist",
		"alchemy.inner_fire_pill",
		"alchemy.cauldron_burst",
		"alchemy.calming_powder",
		"alchemy.toxin_needle",
		"alchemy.spirit_distill",
		"alchemy.cinnabar_seal",
	]
	var passed := _contains_all(sword_ids, expected_sword) \
		and _contains_all(alchemy_ids, expected_alchemy) \
		and not sword_ids.has("alchemy.toxic_pill") \
		and not alchemy_ids.has("sword.strike")
	assert(passed)
	return passed
```

Append this helper after `_ids()`:

```gdscript
func _contains_all(values: Array[String], expected: Array[String]) -> bool:
	for value in expected:
		if not values.has(value):
			return false
	return true
```

- [ ] **Step 2: Write failing reward tests**

Append these tests before `_catalog()` in `tests/unit/test_reward_generator.gd`:

```gdscript
func test_sword_reward_draws_three_unique_cards_from_expanded_pool() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 177, "sword", "expanded_pool", 3)
	var ids: Array = reward.get("card_ids", [])
	var sword_pool := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, sword_pool) \
		and not ids.has("alchemy.toxic_pill")
	assert(passed)
	return passed

func test_alchemy_reward_draws_three_unique_cards_from_expanded_pool() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 177, "alchemy", "expanded_pool", 3)
	var ids: Array = reward.get("card_ids", [])
	var alchemy_pool := _ids(catalog.get_cards_for_character("alchemy"))
	var passed: bool = ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, alchemy_pool) \
		and not ids.has("sword.strike")
	assert(passed)
	return passed
```

Append these helpers after `_catalog()`:

```gdscript
func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids

func _unique_count(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()

func _all_values_in_pool(values: Array, pool: Array[String]) -> bool:
	for value in values:
		if not pool.has(value):
			return false
	return true
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: failures in the new catalog/reward tests because the catalog still only has 2 cards and the new card ids do not exist.

- [ ] **Step 4: Commit the failing tests is not allowed**

Do not commit RED tests by themselves. Continue to Task 2.

## Task 2: Sword Starter Cards

**Files:**

- Create: all 8 `resources/cards/sword/*.tres` files listed in the Sword Cards table.
- Modify: `resources/characters/sword_cultivator.tres`
- Modify: `scripts/content/content_catalog.gd`
- Modify: `localization/zh_CN.po`

- [ ] **Step 1: Add sword resource paths to catalog**

Update `scripts/content/content_catalog.gd`:

```gdscript
const DEFAULT_CARD_PATHS: Array[String] = [
	"res://resources/cards/sword/strike_sword.tres",
	"res://resources/cards/sword/guard.tres",
	"res://resources/cards/sword/flash_cut.tres",
	"res://resources/cards/sword/qi_surge.tres",
	"res://resources/cards/sword/break_stance.tres",
	"res://resources/cards/sword/cloud_step.tres",
	"res://resources/cards/sword/focused_slash.tres",
	"res://resources/cards/sword/sword_resonance.tres",
	"res://resources/cards/sword/horizon_arc.tres",
	"res://resources/cards/alchemy/toxic_pill.tres",
]
```

- [ ] **Step 2: Update sword character card pool**

Update `resources/characters/sword_cultivator.tres`:

```ini
card_pool_ids = Array[String](["sword.strike", "sword.guard", "sword.flash_cut", "sword.qi_surge", "sword.break_stance", "sword.cloud_step", "sword.focused_slash", "sword.sword_resonance", "sword.horizon_arc"])
```

- [ ] **Step 3: Create sword cards**

Create the eight sword `.tres` resources. Use this exact shape for each file, changing sub-resource ids and fields according to the Sword Cards table:

```ini
[gd_resource type="Resource" script_class="CardDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_block"]
script = ExtResource("2_effect")
effect_type = "block"
amount = 7
target = "player"

[resource]
script = ExtResource("1_card")
id = "sword.guard"
name_key = "card.sword.guard.name"
description_key = "card.sword.guard.desc"
cost = 1
card_type = "skill"
rarity = "common"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_block")])
character_id = "sword"
pool_tags = Array[String](["starter"])
reward_weight = 100
```

For multi-effect cards, set `load_steps=4` or `load_steps=5` as needed and list effects in order. Example for `resources/cards/sword/flash_cut.tres`:

```ini
[gd_resource type="Resource" script_class="CardDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_damage"]
script = ExtResource("2_effect")
effect_type = "damage"
amount = 4
target = "enemy"

[sub_resource type="Resource" id="Resource_draw"]
script = ExtResource("2_effect")
effect_type = "draw_card"
amount = 1
target = "player"

[resource]
script = ExtResource("1_card")
id = "sword.flash_cut"
name_key = "card.sword.flash_cut.name"
description_key = "card.sword.flash_cut.desc"
cost = 1
card_type = "attack"
rarity = "common"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_damage"), SubResource("Resource_draw")])
character_id = "sword"
pool_tags = Array[String](["starter"])
reward_weight = 100
```

- [ ] **Step 4: Add sword localization keys**

Append to `localization/zh_CN.po`:

```po
msgid "card.sword.guard.name"
msgstr "凝气护身"

msgid "card.sword.guard.desc"
msgstr "获得 7 点护体。"

msgid "card.sword.flash_cut.name"
msgstr "流光斩"

msgid "card.sword.flash_cut.desc"
msgstr "造成 4 点伤害。抽 1 张牌。"

msgid "card.sword.qi_surge.name"
msgstr "剑气回流"

msgid "card.sword.qi_surge.desc"
msgstr "获得 1 点能量。"

msgid "card.sword.break_stance.name"
msgstr "破势一剑"

msgid "card.sword.break_stance.desc"
msgstr "造成 10 点伤害。施加 1 层破势。"

msgid "card.sword.cloud_step.name"
msgstr "云身步"

msgid "card.sword.cloud_step.desc"
msgstr "获得 4 点护体。抽 1 张牌。"

msgid "card.sword.focused_slash.name"
msgstr "凝神斩"

msgid "card.sword.focused_slash.desc"
msgstr "造成 8 点伤害。"

msgid "card.sword.sword_resonance.name"
msgstr "剑鸣入体"

msgid "card.sword.sword_resonance.desc"
msgstr "获得 3 点护体。获得 2 层剑心。"

msgid "card.sword.horizon_arc.name"
msgstr "横天剑弧"

msgid "card.sword.horizon_arc.desc"
msgstr "造成 6 点伤害。获得 4 点护体。"
```

- [ ] **Step 5: Run tests and verify partial progress**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: tests still fail because alchemy expanded pool is not implemented yet. Failures should no longer mention missing sword card paths or sword localization keys.

- [ ] **Step 6: Do not commit partial feature**

Do not commit until both role pools pass. Continue to Task 3.

## Task 3: Alchemy Starter Cards

**Files:**

- Create: all 8 `resources/cards/alchemy/*.tres` files listed in the Alchemy Cards table.
- Modify: `resources/characters/alchemy_cultivator.tres`
- Modify: `scripts/content/content_catalog.gd`
- Modify: `localization/zh_CN.po`

- [ ] **Step 1: Add alchemy resource paths to catalog**

Update `scripts/content/content_catalog.gd` so `DEFAULT_CARD_PATHS` is:

```gdscript
const DEFAULT_CARD_PATHS: Array[String] = [
	"res://resources/cards/sword/strike_sword.tres",
	"res://resources/cards/sword/guard.tres",
	"res://resources/cards/sword/flash_cut.tres",
	"res://resources/cards/sword/qi_surge.tres",
	"res://resources/cards/sword/break_stance.tres",
	"res://resources/cards/sword/cloud_step.tres",
	"res://resources/cards/sword/focused_slash.tres",
	"res://resources/cards/sword/sword_resonance.tres",
	"res://resources/cards/sword/horizon_arc.tres",
	"res://resources/cards/alchemy/toxic_pill.tres",
	"res://resources/cards/alchemy/healing_draught.tres",
	"res://resources/cards/alchemy/poison_mist.tres",
	"res://resources/cards/alchemy/inner_fire_pill.tres",
	"res://resources/cards/alchemy/cauldron_burst.tres",
	"res://resources/cards/alchemy/calming_powder.tres",
	"res://resources/cards/alchemy/toxin_needle.tres",
	"res://resources/cards/alchemy/spirit_distill.tres",
	"res://resources/cards/alchemy/cinnabar_seal.tres",
]
```

- [ ] **Step 2: Update alchemy character card pool**

Update `resources/characters/alchemy_cultivator.tres`:

```ini
card_pool_ids = Array[String](["alchemy.toxic_pill", "alchemy.healing_draught", "alchemy.poison_mist", "alchemy.inner_fire_pill", "alchemy.cauldron_burst", "alchemy.calming_powder", "alchemy.toxin_needle", "alchemy.spirit_distill", "alchemy.cinnabar_seal"])
```

- [ ] **Step 3: Create alchemy cards**

Create the eight alchemy `.tres` resources using the Alchemy Cards table. Example for `resources/cards/alchemy/inner_fire_pill.tres`:

```ini
[gd_resource type="Resource" script_class="CardDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_energy"]
script = ExtResource("2_effect")
effect_type = "gain_energy"
amount = 1
target = "player"

[sub_resource type="Resource" id="Resource_draw"]
script = ExtResource("2_effect")
effect_type = "draw_card"
amount = 1
target = "player"

[resource]
script = ExtResource("1_card")
id = "alchemy.inner_fire_pill"
name_key = "card.alchemy.inner_fire_pill.name"
description_key = "card.alchemy.inner_fire_pill.desc"
cost = 0
card_type = "skill"
rarity = "uncommon"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_energy"), SubResource("Resource_draw")])
character_id = "alchemy"
pool_tags = Array[String](["starter"])
reward_weight = 100
```

- [ ] **Step 4: Add alchemy localization keys**

Append to `localization/zh_CN.po`:

```po
msgid "card.alchemy.healing_draught.name"
msgstr "回春丹露"

msgid "card.alchemy.healing_draught.desc"
msgstr "回复 5 点生命。"

msgid "card.alchemy.poison_mist.name"
msgstr "淬毒烟岚"

msgid "card.alchemy.poison_mist.desc"
msgstr "施加 3 层毒。"

msgid "card.alchemy.inner_fire_pill.name"
msgstr "内火丹"

msgid "card.alchemy.inner_fire_pill.desc"
msgstr "获得 1 点能量。抽 1 张牌。"

msgid "card.alchemy.cauldron_burst.name"
msgstr "丹炉迸火"

msgid "card.alchemy.cauldron_burst.desc"
msgstr "造成 7 点伤害。获得 4 点护体。"

msgid "card.alchemy.calming_powder.name"
msgstr "定神散"

msgid "card.alchemy.calming_powder.desc"
msgstr "获得 6 点护体。回复 2 点生命。"

msgid "card.alchemy.toxin_needle.name"
msgstr "毒针入脉"

msgid "card.alchemy.toxin_needle.desc"
msgstr "造成 3 点伤害。施加 2 层毒。"

msgid "card.alchemy.spirit_distill.name"
msgstr "灵液萃取"

msgid "card.alchemy.spirit_distill.desc"
msgstr "抽 2 张牌。"

msgid "card.alchemy.cinnabar_seal.name"
msgstr "朱砂护印"

msgid "card.alchemy.cinnabar_seal.desc"
msgstr "获得 8 点护体。获得 1 层丹护。"
```

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all tests pass with `TESTS PASSED`.

- [ ] **Step 6: Run Task 1-3 review gates**

Spec Compliance Review:

- `ContentCatalog.DEFAULT_CARD_PATHS` lists 18 cards.
- Sword and alchemy characters each have 9 `card_pool_ids`.
- Every new card id matches the spec.
- Every new card has `character_id`, `pool_tags`, `reward_weight`, name key, desc key, cost, type, rarity, and effects.
- No scene, autoload, input map, event, shop, relic, enemy, or multi-enemy combat behavior was added.

Code Quality Review:

- `.tres` files use existing `CardDef`/`EffectDef` schema only.
- Effect target strings are existing valid values.
- Multi-effect resources use stable sub-resource ids.
- Tests check behavior through `ContentCatalog` and `RewardGenerator`, not private implementation details.

- [ ] **Step 7: Commit expanded card pool resources**

Run:

```powershell
git add scripts/content/content_catalog.gd resources/cards resources/characters localization/zh_CN.po tests/unit/test_content_catalog.gd tests/unit/test_reward_generator.gd
git commit -m "feat: expand dual starter card pools"
```

## Task 4: Resource Effect Composition and Final Acceptance

**Files:**

- Modify: `tests/unit/test_combat_engine.gd`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-26-dual-starter-card-pools.md`

- [ ] **Step 1: Write failing resource composition tests**

Append to `tests/unit/test_combat_engine.gd`:

```gdscript
func test_sword_flash_cut_resource_deals_damage_and_draws() -> bool:
	var card := load("res://resources/cards/sword/flash_cut.tres") as CardDef
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	var enemy := CombatantState.new("enemy", 20)
	CombatEngine.new().play_card_in_state(card, state, state.player, enemy)
	var passed: bool = enemy.current_hp == 16 and state.pending_draw_count == 1
	assert(passed)
	return passed

func test_alchemy_inner_fire_pill_resource_gains_energy_and_draws() -> bool:
	var card := load("res://resources/cards/alchemy/inner_fire_pill.tres") as CardDef
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	state.energy = 0
	var enemy := CombatantState.new("enemy", 20)
	CombatEngine.new().play_card_in_state(card, state, state.player, enemy)
	var passed: bool = state.energy == 1 and state.pending_draw_count == 1 and enemy.current_hp == 20
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify RED if resources are absent**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected if Task 3 has not been implemented: the new tests fail because resources cannot load. If Task 3 has been implemented in the same working tree, these tests may pass immediately because they validate already-created resources; record that in the task notes before continuing.

- [ ] **Step 3: Implement only if needed**

If either test fails because a resource effect is misconfigured, fix the relevant `.tres` resource to match:

```ini
effects = Array[ExtResource("2_effect")]([SubResource("Resource_damage"), SubResource("Resource_draw")])
```

for `sword.flash_cut`, and:

```ini
effects = Array[ExtResource("2_effect")]([SubResource("Resource_energy"), SubResource("Resource_draw")])
```

for `alchemy.inner_fire_pill`.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [ ] **Step 5: Run Godot import check**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected: exit code 0 with no missing resource or parse errors.

- [ ] **Step 6: Update README**

Add under `## Phase 2 Progress`:

```markdown
- Dual starter card pools: complete; sword and alchemy each have 9 catalog cards
```

- [ ] **Step 7: Update plan execution status**

Add near the top of this plan:

```markdown
## Execution Status

Completed on 2026-04-26 in the current `main` workspace.

- Expanded sword starter card pool to 9 total catalog cards.
- Expanded alchemy starter card pool to 9 total catalog cards.
- Verified catalog, reward, resource effect composition, and Godot import checks.
```

- [ ] **Step 8: Run final two-stage review**

Spec Compliance Review:

- Compare implementation against `docs/superpowers/specs/2026-04-26-dual-starter-card-pools-design.md`.
- Verify all planned files exist.
- Verify `ContentCatalog` loads 18 cards.
- Verify no multi-enemy encounter behavior was added in this card-pool task.

Code Quality Review:

- Check GDScript typing in tests.
- Check resource paths and localization keys.
- Check `.tres` effect targets.
- Check no code duplication was introduced outside expected resource repetition.

- [ ] **Step 9: Commit final acceptance**

Run:

```powershell
git add tests/unit/test_combat_engine.gd README.md docs/superpowers/plans/2026-04-26-dual-starter-card-pools.md
git commit -m "docs: record dual starter card pool acceptance"
```

## Self-Review Checklist

- Spec coverage: every card in the spec appears in the plan.
- Placeholder scan: complete; this plan contains no unfinished implementation instructions.
- Type consistency: all paths, ids, localization keys, and effect types match existing Godot schemas.
- Test coverage: catalog count, role isolation, reward uniqueness, and representative resource effect composition are covered.
- Multi-enemy note: the plan records that multi-enemy encounter generation is out of scope for this card-pool implementation.

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-04-26-dual-starter-card-pools.md`.

Recommended execution: Subagent-Driven Development. If subagents are used for implementation or review, they must use `gpt-5.5` with `xhigh` reasoning, per `AGENTS.md`.
