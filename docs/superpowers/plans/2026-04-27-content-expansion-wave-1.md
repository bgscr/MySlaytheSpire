# Content Expansion Wave 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the current Phase 2 combat sandbox to 30 cards, 9 enemies, and 6 relics using existing Godot Resource pipelines.

**Architecture:** This wave is data-first. New cards, enemies, and relics are `.tres` resources registered through `ContentCatalog`, with validation and reward/encounter tests proving the expanded pools are usable without adding new runtime mechanics.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resource `.tres` files, gettext `.po` localization, custom headless test runner.

---

## Scope Check

This plan implements only `docs/superpowers/specs/2026-04-27-content-expansion-wave-1-design.md`.

Included:

- Add 6 sword card resources and append their ids to the sword character pool.
- Add 6 alchemy card resources and append their ids to the alchemy character pool.
- Add 6 enemy resources and register them in the default catalog.
- Add 5 relic resources and register them in the default catalog.
- Add localization keys for all new resource names/descriptions.
- Update tests for pool counts, expected ids, encounter tiers, relic tiers, reward behavior, and validation.
- Update README Phase 2 progress after acceptance.

Excluded:

- No new effect types.
- No relic runtime trigger behavior.
- No event, shop, save schema, presentation, scene flow, or input map changes.

## File Structure

Create:

- `resources/cards/sword/iron_wind_cut.tres`
- `resources/cards/sword/rising_arc.tres`
- `resources/cards/sword/guardian_stance.tres`
- `resources/cards/sword/meridian_flash.tres`
- `resources/cards/sword/heart_piercer.tres`
- `resources/cards/sword/unbroken_focus.tres`
- `resources/cards/alchemy/bitter_extract.tres`
- `resources/cards/alchemy/smoke_screen.tres`
- `resources/cards/alchemy/quick_simmer.tres`
- `resources/cards/alchemy/white_jade_paste.tres`
- `resources/cards/alchemy/mercury_bloom.tres`
- `resources/cards/alchemy/ninefold_refine.tres`
- `resources/enemies/wild_fox_spirit.tres`
- `resources/enemies/ash_lantern_cultist.tres`
- `resources/enemies/stone_grove_guardian.tres`
- `resources/enemies/mirror_blade_adept.tres`
- `resources/enemies/venom_cauldron_hermit.tres`
- `resources/enemies/boss_storm_dragon.tres`
- `resources/relics/bronze_incense_burner.tres`
- `resources/relics/cracked_spirit_coin.tres`
- `resources/relics/moonwell_seed.tres`
- `resources/relics/thunderseal_charm.tres`
- `resources/relics/dragon_bone_flute.tres`

Modify:

- `scripts/content/content_catalog.gd`
- `resources/characters/sword_cultivator.tres`
- `resources/characters/alchemy_cultivator.tres`
- `localization/zh_CN.po`
- `tests/unit/test_content_catalog.gd`
- `tests/unit/test_reward_generator.gd`
- `tests/unit/test_encounter_generator.gd`
- `README.md`
- `docs/superpowers/plans/2026-04-27-content-expansion-wave-1.md`

## Resource Data

Sword cards:

| id | file | type | rarity | cost | effects |
| --- | --- | --- | --- | --- | --- |
| `sword.iron_wind_cut` | `iron_wind_cut.tres` | attack | common | 1 | damage 7 enemy; block 2 player |
| `sword.rising_arc` | `rising_arc.tres` | attack | common | 1 | damage 5 enemy; draw_card 1 player |
| `sword.guardian_stance` | `guardian_stance.tres` | skill | common | 1 | block 9 player |
| `sword.meridian_flash` | `meridian_flash.tres` | skill | uncommon | 0 | gain_energy 1 player; draw_card 1 player |
| `sword.heart_piercer` | `heart_piercer.tres` | attack | uncommon | 2 | damage 13 enemy; apply_status 1 broken_stance enemy |
| `sword.unbroken_focus` | `unbroken_focus.tres` | skill | rare | 1 | apply_status 3 sword_focus player; block 5 player |

Alchemy cards:

| id | file | type | rarity | cost | effects |
| --- | --- | --- | --- | --- | --- |
| `alchemy.bitter_extract` | `bitter_extract.tres` | attack | common | 1 | damage 5 enemy; apply_status 1 poison enemy |
| `alchemy.smoke_screen` | `smoke_screen.tres` | skill | common | 1 | block 5 player; apply_status 1 poison enemy |
| `alchemy.quick_simmer` | `quick_simmer.tres` | skill | common | 0 | draw_card 1 player |
| `alchemy.white_jade_paste` | `white_jade_paste.tres` | skill | uncommon | 1 | heal 3 player; block 4 player |
| `alchemy.mercury_bloom` | `mercury_bloom.tres` | attack | uncommon | 2 | damage 8 enemy; apply_status 3 poison enemy |
| `alchemy.ninefold_refine` | `ninefold_refine.tres` | skill | rare | 1 | gain_energy 1 player; draw_card 2 player |

Enemies:

| id | tier | max_hp | intents | reward_tier | gold bounds |
| --- | --- | --- | --- | --- | --- |
| `wild_fox_spirit` | normal | 18 | `attack_4`, `block_3` | normal | 8-14 |
| `ash_lantern_cultist` | normal | 24 | `attack_6`, `attack_5` | normal | 8-14 |
| `stone_grove_guardian` | normal | 32 | `block_6`, `attack_7` | normal | 8-14 |
| `mirror_blade_adept` | elite | 42 | `attack_8`, `block_6`, `attack_10` | elite | 18-28 |
| `venom_cauldron_hermit` | elite | 46 | `block_8`, `attack_9`, `attack_7` | elite | 18-28 |
| `boss_storm_dragon` | boss | 95 | `attack_12`, `block_10`, `attack_16` | boss | 40-60 |

Relics:

| id | tier | trigger_event | effects |
| --- | --- | --- | --- |
| `bronze_incense_burner` | common | `combat_started` | block 4 player |
| `cracked_spirit_coin` | common | `combat_won` | gain_gold 8 player |
| `moonwell_seed` | uncommon | `combat_started` | heal 2 player |
| `thunderseal_charm` | uncommon | `turn_started` | gain_energy 1 player |
| `dragon_bone_flute` | rare | `combat_started` | apply_status 2 sword_focus player |

## Task 1: Lock Expanded Catalog Tests

**Files:**

- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `tests/unit/test_reward_generator.gd`
- Modify: `tests/unit/test_encounter_generator.gd`

- [x] **Step 1: Update catalog count and id tests**

Change `test_default_catalog_loads_dual_starter_card_pool_counts` to expect 30 total cards, 15 sword cards, and 15 alchemy cards.

Extend `test_dual_starter_card_pools_are_character_isolated` expected arrays with:

```gdscript
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
	"sword.iron_wind_cut",
	"sword.rising_arc",
	"sword.guardian_stance",
	"sword.meridian_flash",
	"sword.heart_piercer",
	"sword.unbroken_focus",
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
	"alchemy.bitter_extract",
	"alchemy.smoke_screen",
	"alchemy.quick_simmer",
	"alchemy.white_jade_paste",
	"alchemy.mercury_bloom",
	"alchemy.ninefold_refine",
]
```

Add a new test:

```gdscript
func test_wave_1_catalog_loads_expanded_enemy_and_relic_counts() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var elite_ids := _ids(catalog.get_enemies_by_tier("elite"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var common_relic_ids := _ids(catalog.get_relics_by_tier("common"))
	var uncommon_relic_ids := _ids(catalog.get_relics_by_tier("uncommon"))
	var rare_relic_ids := _ids(catalog.get_relics_by_tier("rare"))
	var passed: bool = catalog.enemies_by_id.size() == 9 \
		and catalog.relics_by_id.size() == 6 \
		and normal_ids.size() == 4 \
		and elite_ids.size() == 3 \
		and boss_ids.size() == 2 \
		and common_relic_ids.size() == 3 \
		and uncommon_relic_ids.size() == 2 \
		and rare_relic_ids.size() == 1 \
		and normal_ids.has("wild_fox_spirit") \
		and elite_ids.has("mirror_blade_adept") \
		and boss_ids.has("boss_storm_dragon") \
		and rare_relic_ids.has("dragon_bone_flute")
	assert(passed)
	return passed
```

- [x] **Step 2: Update reward tests**

Add a relic tier coverage test to `tests/unit/test_reward_generator.gd`:

```gdscript
func test_relic_rewards_draw_from_each_populated_wave_1_tier() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var common := generator.generate_relic_reward(catalog, 91, "wave_1_common", "common")
	var uncommon := generator.generate_relic_reward(catalog, 91, "wave_1_uncommon", "uncommon")
	var rare := generator.generate_relic_reward(catalog, 91, "wave_1_rare", "rare")
	var passed: bool = not String(common.get("relic_id", "")).is_empty() \
		and not String(uncommon.get("relic_id", "")).is_empty() \
		and rare.get("relic_id") == "dragon_bone_flute"
	assert(passed)
	return passed
```

- [x] **Step 3: Update encounter tests**

Add a default tier composition test to `tests/unit/test_encounter_generator.gd`:

```gdscript
func test_default_catalog_has_wave_1_enemy_tier_composition() -> bool:
	var catalog := _catalog()
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var elite_ids := _ids(catalog.get_enemies_by_tier("elite"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var passed: bool = normal_ids.size() == 4 \
		and elite_ids.size() == 3 \
		and boss_ids.size() == 2 \
		and normal_ids.has("ash_lantern_cultist") \
		and normal_ids.has("stone_grove_guardian") \
		and elite_ids.has("venom_cauldron_hermit") \
		and boss_ids.has("boss_storm_dragon")
	assert(passed)
	return passed
```

Add helper:

```gdscript
func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids
```

- [x] **Step 4: Run tests and verify RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: failures from expected card/enemy/relic counts and missing Wave 1 ids.

- [x] **Step 5: Commit is not allowed**

Do not commit the failing tests by themselves.

## Task 2: Add Sword and Alchemy Card Resources

**Files:**

- Create: the 12 card `.tres` files listed in File Structure
- Modify: `scripts/content/content_catalog.gd`
- Modify: `resources/characters/sword_cultivator.tres`
- Modify: `resources/characters/alchemy_cultivator.tres`
- Modify: `localization/zh_CN.po`

- [x] **Step 1: Create sword card resources**

Create the six sword card resources from the Resource Data table. Each file must use:

```ini
[gd_resource type="Resource" script_class="CardDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]

[sub_resource type="Resource" id="Resource_<effect_name>"]
script = ExtResource("2_effect")
effect_type = "<effect_type>"
amount = <amount>
status_id = "<status_id only for apply_status>"
target = "<player or enemy>"

[resource]
script = ExtResource("1_card")
id = "<card id>"
name_key = "card.<character>.<name>.name"
description_key = "card.<character>.<name>.desc"
cost = <cost>
card_type = "<attack or skill>"
rarity = "<common, uncommon, or rare>"
effects = Array[ExtResource("2_effect")]([SubResource("Resource_<first>"), SubResource("Resource_<second if present>")])
character_id = "<sword or alchemy>"
pool_tags = Array[String](["wave_1"])
reward_weight = 100
```

- [x] **Step 2: Create alchemy card resources**

Create the six alchemy card resources from the Resource Data table using the same style as Step 1.

- [x] **Step 3: Register card paths**

Append these paths to `ContentCatalog.DEFAULT_CARD_PATHS` after the existing sword/alchemy groups:

```gdscript
"res://resources/cards/sword/iron_wind_cut.tres",
"res://resources/cards/sword/rising_arc.tres",
"res://resources/cards/sword/guardian_stance.tres",
"res://resources/cards/sword/meridian_flash.tres",
"res://resources/cards/sword/heart_piercer.tres",
"res://resources/cards/sword/unbroken_focus.tres",
"res://resources/cards/alchemy/bitter_extract.tres",
"res://resources/cards/alchemy/smoke_screen.tres",
"res://resources/cards/alchemy/quick_simmer.tres",
"res://resources/cards/alchemy/white_jade_paste.tres",
"res://resources/cards/alchemy/mercury_bloom.tres",
"res://resources/cards/alchemy/ninefold_refine.tres",
```

- [x] **Step 4: Append character card pool ids**

Append only the new sword ids to `resources/characters/sword_cultivator.tres` and only the new alchemy ids to `resources/characters/alchemy_cultivator.tres`. Do not change `starting_deck_ids`.

- [x] **Step 5: Add card localization keys**

Add `name` and `desc` keys for all 12 new cards to `localization/zh_CN.po`.

- [x] **Step 6: Run tests and verify partial GREEN**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: card count and card id tests pass; enemy/relic count tests still fail until Task 3.

- [x] **Step 7: Do not commit partial feature**

Do not commit until all Wave 1 data and tests are green.

## Task 3: Add Enemy and Relic Resources

**Files:**

- Create: the 6 enemy `.tres` files listed in File Structure
- Create: the 5 relic `.tres` files listed in File Structure
- Modify: `scripts/content/content_catalog.gd`
- Modify: `localization/zh_CN.po`

- [x] **Step 1: Create enemy resources**

Create the six enemy resources from the Resource Data table. Use `encounter_weight = 100` for each, and use the tier-specific gold bounds from the table.

- [x] **Step 2: Create relic resources**

Create the five relic resources from the Resource Data table using inline `EffectDef` sub-resources. Do not add any relic runtime behavior.

- [x] **Step 3: Register enemy and relic paths**

Append these paths to `ContentCatalog.DEFAULT_ENEMY_PATHS`:

```gdscript
"res://resources/enemies/wild_fox_spirit.tres",
"res://resources/enemies/ash_lantern_cultist.tres",
"res://resources/enemies/stone_grove_guardian.tres",
"res://resources/enemies/mirror_blade_adept.tres",
"res://resources/enemies/venom_cauldron_hermit.tres",
"res://resources/enemies/boss_storm_dragon.tres",
```

Append these paths to `ContentCatalog.DEFAULT_RELIC_PATHS`:

```gdscript
"res://resources/relics/bronze_incense_burner.tres",
"res://resources/relics/cracked_spirit_coin.tres",
"res://resources/relics/moonwell_seed.tres",
"res://resources/relics/thunderseal_charm.tres",
"res://resources/relics/dragon_bone_flute.tres",
```

- [x] **Step 4: Add enemy and relic localization keys**

Add `enemy.<id>.name`, `relic.<id>.name`, and `relic.<id>.desc` keys for all new resources to `localization/zh_CN.po`.

- [x] **Step 5: Run tests and verify GREEN**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [x] **Step 6: Run Godot import check**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

Expected: exit 0 with no parse errors or missing resources.

- [x] **Step 7: Run Task 1-3 review gates**

Stage 1 Spec Compliance Review must confirm:

- 12 cards exist, are registered, localized, character-scoped, and in the right card pools.
- 6 enemies exist, are registered, localized, and produce 4 normal / 3 elite / 2 boss defaults.
- 5 relics exist, are registered, localized, and produce 3 common / 2 uncommon / 1 rare defaults.
- Starting decks are unchanged.
- No excluded runtime systems were added.

Only if Stage 1 passes, run Stage 2 Code Quality Review for:

- Typed GDScript test helpers.
- Resource formatting consistency.
- Catalog array ordering.
- No duplicated or wrong localization keys.
- No unsupported effect types or enemy intents.

- [x] **Step 8: Commit Wave 1 resource expansion**

```powershell
git add scripts/content/content_catalog.gd resources/cards resources/enemies resources/relics resources/characters localization/zh_CN.po tests/unit/test_content_catalog.gd tests/unit/test_reward_generator.gd tests/unit/test_encounter_generator.gd docs/superpowers/plans/2026-04-27-content-expansion-wave-1.md
git commit -m "feat: add content expansion wave 1 resources"
```

## Task 4: Acceptance Docs

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-27-content-expansion-wave-1.md`

- [x] **Step 1: Update README Phase 2 progress**

Add this bullet under `## Phase 2 Progress`:

```markdown
- Content expansion wave 1: complete; sword and alchemy each have 15 cards, default encounters have 4 normal / 3 elite / 2 boss enemies, and relic rewards draw from 6 registered relics
```

- [x] **Step 2: Mark plan checkboxes complete**

Update this plan's completed steps from `[ ]` to `[x]` after verifying the implementation and reviews.

- [x] **Step 3: Run final full tests**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: `TESTS PASSED`.

- [x] **Step 4: Run final import check**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

Expected: exit 0 with no parse errors or missing resources.

- [x] **Step 5: Run final two-stage review**

Stage 1 must verify this plan and the design spec are fully satisfied. Stage 2 must classify any quality issues as Critical, Important, or Minor.

- [x] **Step 6: Commit acceptance docs**

```powershell
git add README.md docs/superpowers/plans/2026-04-27-content-expansion-wave-1.md
git commit -m "docs: record content expansion wave 1 acceptance"
```

## Acceptance Criteria

- Default catalog loads 30 cards, 9 enemies, and 6 relics.
- Sword and alchemy each have exactly 15 cards in their character pools.
- Existing starting decks are unchanged.
- All new resources have non-empty ids and required localization keys.
- Catalog validation returns no errors.
- Card reward generation remains character-isolated.
- Encounter generation works with expanded normal, elite, and boss pools.
- Relic reward generation can draw from common, uncommon, and rare populated pools.
- No runtime relic trigger behavior is added.
- No event, shop, save schema, presentation, or input map changes are added.
- Godot tests pass.
- Godot import check exits 0.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-27-content-expansion-wave-1.md`.

Recommended execution: **Subagent-Driven**. Dispatch a fresh implementer per task and run the required two-stage review after each completed Godot feature.
