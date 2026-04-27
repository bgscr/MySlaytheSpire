# Content Expansion Wave 1 Design

Date: 2026-04-27

## Goal

Expand the current playable combat loop from a thin sample set into a small but varied resource pool. This wave is content-first: add more cards, enemies, and relic definitions using the existing Godot Resource pipeline, while keeping runtime systems stable.

The intended result is a richer Phase 2 combat and reward sandbox:

- Sword and alchemy each have 15 catalog cards.
- Encounter generation has enough normal, elite, and boss enemies to vary multi-enemy fights.
- Relic rewards can draw from a small tiered data pool.
- All new resources are registered, localized, and covered by validation tests.

## Scope

Included:

- Add 6 sword card resources.
- Add 6 alchemy card resources.
- Add 6 enemy resources, bringing the default enemy pool to 4 normal, 3 elite, and 2 boss enemies.
- Add 5 relic resources, bringing the default relic pool to 6 total relics.
- Register all new resources in `ContentCatalog`.
- Add new localization keys to `localization/zh_CN.po`.
- Update tests for catalog counts, card pool isolation, encounter pool composition, reward generation, and resource validation.
- Update README Phase 2 progress after acceptance.

Excluded:

- No new `EffectDef.effect_type` values.
- No relic trigger runtime behavior.
- No event system implementation.
- No shop implementation.
- No new scene flow for events, shops, or relic selection.
- No high-presentation animation, particles, audio, generated art, or card illustrations.
- No save schema changes.

## Current Baseline

The project already has the content capacity needed for this wave:

- `CardDef` supports id, localization keys, cost, type, rarity, tags, effects, character id, pool tags, and reward weight.
- `EnemyDef` supports id, localization key, max HP, `intent_sequence`, reward tier, enemy tier, encounter weight, and gold reward bounds.
- `RelicDef` supports id, localization keys, trigger event, effects, tier, and reward weight.
- `ContentCatalog` loads and validates cards, characters, enemies, and relics.
- `RewardGenerator` can generate card, gold, and relic rewards.
- `EncounterGenerator` can generate normal, elite, and boss encounters with support enemies.
- `CombatSession` can resolve cards with current effects and enemies with `attack_N` / `block_N` intents.

Current content counts:

- Sword cards: 9.
- Alchemy cards: 9.
- Enemies: 1 normal, 1 elite, 1 boss.
- Relics: 1 common.

## Design Principles

Stay data-first. New content must be added as `.tres` resources and catalog registrations, not hard-coded runtime behavior.

Use existing mechanics. Cards may combine current effects: `damage`, `block`, `heal`, `draw_card`, `gain_energy`, `apply_status`, and `gain_gold`. Enemies may only use `attack_N` and `block_N` intents in this wave.

Make character identity sharper. Sword cards lean into direct pressure, tempo, energy, and sword-focus style statuses. Alchemy cards lean into poison, healing, block, draw, and elixir-style setup.

Prefer small, testable variety. The new resources broaden reward and encounter outcomes without introducing untested mechanics.

Keep future hooks honest. Relics may declare `trigger_event` and effects, but tests must treat them as data/reward resources only until the relic runtime is implemented in the next wave.

## Card Expansion

### Sword Cards

Add 6 sword cards, bringing the pool to 15 cards.

Wave 1 cards:

| id | type | rarity | cost | effects | purpose |
| --- | --- | --- | --- | --- | --- |
| `sword.iron_wind_cut` | attack | common | 1 | damage 7 enemy; block 2 player | Basic attack/defense hybrid. |
| `sword.rising_arc` | attack | common | 1 | damage 5 enemy; draw 1 player | Tempo attack. |
| `sword.guardian_stance` | skill | common | 1 | block 9 player | Strong simple defense. |
| `sword.meridian_flash` | skill | uncommon | 0 | gain_energy 1 player; draw 1 player | Combo enabler using existing effects. |
| `sword.heart_piercer` | attack | uncommon | 2 | damage 13 enemy; apply_status 1 broken_stance enemy | Heavy pressure card. |
| `sword.unbroken_focus` | skill | rare | 1 | apply_status 3 sword_focus player; block 5 player | Rare setup card without new runtime behavior. |

All sword cards must use `character_id = "sword"` and must be included in the sword character `card_pool_ids`.

### Alchemy Cards

Add 6 alchemy cards, bringing the pool to 15 cards.

Wave 1 cards:

| id | type | rarity | cost | effects | purpose |
| --- | --- | --- | --- | --- | --- |
| `alchemy.bitter_extract` | attack | common | 1 | damage 5 enemy; apply_status 1 poison enemy | Simple poison attack. |
| `alchemy.smoke_screen` | skill | common | 1 | block 5 player; apply_status 1 poison enemy | Defensive poison. |
| `alchemy.quick_simmer` | skill | common | 0 | draw 1 player | Low-risk deck smoothing. |
| `alchemy.white_jade_paste` | skill | uncommon | 1 | heal 3 player; block 4 player | Sustain/defense hybrid. |
| `alchemy.mercury_bloom` | attack | uncommon | 2 | damage 8 enemy; apply_status 3 poison enemy | Premium poison attack. |
| `alchemy.ninefold_refine` | skill | rare | 1 | gain_energy 1 player; draw 2 player | Rare resource engine card. |

All alchemy cards must use `character_id = "alchemy"` and must be included in the alchemy character `card_pool_ids`.

## Enemy Expansion

Add 6 enemies, bringing the default pool to:

- Normal: 4 total.
- Elite: 3 total.
- Boss: 2 total.

Wave 1 enemies:

| id | tier | max_hp | intents | reward_tier | purpose |
| --- | --- | --- | --- | --- | --- |
| `wild_fox_spirit` | normal | 18 | `attack_4`, `block_3` | normal | Light normal support enemy. |
| `ash_lantern_cultist` | normal | 24 | `attack_6`, `attack_5` | normal | Aggressive normal enemy. |
| `stone_grove_guardian` | normal | 32 | `block_6`, `attack_7` | normal | Defensive normal enemy. |
| `mirror_blade_adept` | elite | 42 | `attack_8`, `block_6`, `attack_10` | elite | Sword-themed elite. |
| `venom_cauldron_hermit` | elite | 46 | `block_8`, `attack_9`, `attack_7` | elite | Alchemy-themed elite. |
| `boss_storm_dragon` | boss | 95 | `attack_12`, `block_10`, `attack_16` | boss | Second boss option. |

The encounter generator does not currently use `encounter_weight`, so this wave only requires metadata correctness and pool composition. Weight-aware encounter selection can be a later balancing pass.

## Relic Expansion

Add 5 relic resources, bringing the relic pool to 6 total.

Wave 1 relics:

| id | tier | trigger_event | effects | purpose |
| --- | --- | --- | --- | --- |
| `bronze_incense_burner` | common | `combat_started` | block 4 player | Another simple defensive common. |
| `cracked_spirit_coin` | common | `combat_won` | gain_gold 8 player | Economy relic data. |
| `moonwell_seed` | uncommon | `combat_started` | heal 2 player | Sustain relic data. |
| `thunderseal_charm` | uncommon | `turn_started` | gain_energy 1 player | Future energy trigger relic. |
| `dragon_bone_flute` | rare | `combat_started` | apply_status 2 sword_focus player | Rare setup relic data. |

Relic effects use existing `EffectDef` syntax. Their runtime behavior is intentionally not active until the relic trigger system is implemented in Wave 2.

## Architecture

### Resource Files

Create new `.tres` files under existing folders:

- `resources/cards/sword/`
- `resources/cards/alchemy/`
- `resources/enemies/`
- `resources/relics/`

Each card resource must follow current resource style:

- `CardDef` external script resource.
- Inline `EffectDef` sub-resources.
- Stable `id`, `name_key`, `description_key`, `cost`, `card_type`, `rarity`, `effects`, `character_id`, `pool_tags`, and `reward_weight`.

Each enemy resource must follow current `EnemyDef` style:

- Stable `id`.
- `name_key`.
- `max_hp`.
- `intent_sequence`.
- `reward_tier`.
- `tier`.
- `encounter_weight`.
- Gold reward bounds.

Each relic resource must follow current `RelicDef` style:

- Stable `id`.
- `name_key`.
- `description_key`.
- `trigger_event`.
- Inline effects.
- `tier`.
- `reward_weight`.

### Catalog Registration

Update `ContentCatalog.DEFAULT_CARD_PATHS`, `DEFAULT_ENEMY_PATHS`, and `DEFAULT_RELIC_PATHS` to include all new resources.

Update character resources:

- `resources/characters/sword_cultivator.tres`
- `resources/characters/alchemy_cultivator.tres`

Only append new card ids to `card_pool_ids`. Do not change starting decks in this wave.

### Localization

Add `name` and `desc` keys for each new card and relic, plus `name` keys for each new enemy.

The current `zh_CN.po` file has encoding artifacts in display output, but validation reads keys, not rendered text. New keys must follow current naming:

- `card.sword.<name>.name`
- `card.sword.<name>.desc`
- `card.alchemy.<name>.name`
- `card.alchemy.<name>.desc`
- `enemy.<name>.name`
- `relic.<name>.name`
- `relic.<name>.desc`

## Data Flow

1. `ContentCatalog.load_default()` loads all registered resources.
2. `ContentCatalog.validate()` confirms ids and localization keys.
3. `get_cards_for_character("sword")` returns exactly the sword character pool, now 15 cards.
4. `get_cards_for_character("alchemy")` returns exactly the alchemy character pool, now 15 cards.
5. `RewardGenerator.generate_card_reward()` draws only from the selected character pool.
6. `EncounterGenerator.generate()` has larger tier pools for normal, elite, and boss encounters.
7. `RewardGenerator.generate_relic_reward()` can draw from multiple relic tiers.
8. Combat can play newly added cards as long as they use existing effects.

## Testing Strategy

Update or add unit tests:

- Default catalog loads all new resource ids.
- Catalog validation passes with all new localization keys.
- Default card count is 30 total.
- Sword card pool count is 15.
- Alchemy card pool count is 15.
- Sword and alchemy card pools remain isolated.
- Each expected new sword card id appears in sword pool.
- Each expected new alchemy card id appears in alchemy pool.
- Normal enemy pool has 4 ids.
- Elite enemy pool has 3 ids.
- Boss enemy pool has 2 ids.
- Relic pool has 6 ids across common/uncommon/rare tiers.
- Card rewards still return unique cards from the selected character pool.
- Encounter generation still returns valid tier composition with expanded pools.
- Relic rewards can deterministically return non-empty ids for common, uncommon, and rare pools.

Run the existing full Godot test command after implementation:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Run import check:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --quit
```

## Acceptance Criteria

- The default catalog loads 30 cards, 9 enemies, and 6 relics.
- Sword and alchemy each have exactly 15 cards in their character pools.
- Existing starting decks are unchanged.
- All new resources have non-empty ids and required localization keys.
- Catalog validation returns no errors.
- Card reward generation remains character-isolated.
- Encounter generation works with expanded normal, elite, and boss pools.
- Relic reward generation can draw from each populated relic tier.
- No runtime relic trigger behavior is added.
- No event, shop, save schema, presentation, or input map changes are added.
- Godot tests pass.
- Godot import check exits 0.

## Follow-Up Wave

After this content expansion lands, the next planned wave is:

- Relic trigger runtime.
- Event resource schema and basic event scene flow.
- Shop item model and basic shop scene flow.

That follow-up must consume this wave's expanded card, enemy, and relic pools rather than adding another large content batch first.
