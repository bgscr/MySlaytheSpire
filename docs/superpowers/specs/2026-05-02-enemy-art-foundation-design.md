# Enemy Art Foundation Design

Date: 2026-05-02

## Goal

Add a data-backed enemy art foundation for combat. Every default enemy should have explicit visual metadata, and combat should render an enemy portrait slot without changing targeting, combat rules, enemy intent execution, or run flow.

This is a foundation pass. It proves the resource, catalog, resolver, and UI path for enemy portraits while allowing shared first-batch foundation textures. It does not require final bespoke enemy illustrations.

## Current Baseline

The project already has:

- `EnemyDef` resources for 16 default enemies.
- `ContentCatalog` loading enemies, cards, characters, relics, events, enemy intent displays, card visuals, combat backgrounds, and character visual themes.
- `CombatVisualResolver` resolving card visuals, combat backgrounds, and character themes.
- `CombatScreen` rendering enemy entries as stable `EnemyButton_<index>` targets with summary and intent row child controls.
- Tests that verify combat targeting, drag play, enemy intent display rows, presentation effects, and visual theme backgrounds.

Current gaps:

- Enemies have gameplay/content definitions but no presentation-owned portrait metadata.
- Combat has card thumbnail slots and data-backed backgrounds, but enemy entries remain text-first.
- There is no catalog validation proving all default enemies have visual assets.

## Confirmed Direction

Use an enemy visual catalog plus combat portrait slots.

Add one visual resource for each default enemy, load those resources through `ContentCatalog`, resolve them through `CombatVisualResolver`, and render portrait children inside the existing `EnemyButton_<index>` entries.

The first pass must cover all 16 default enemies. Multiple enemy visual resources may share foundation textures grouped by tier, silhouette, or faction.

## Scope

Included:

- Add `EnemyVisualDef` as a data-only resource.
- Add one `resources/visuals/enemy_visuals/*.tres` resource for each default enemy.
- Add a small first-batch texture pool under `assets/presentation/enemy_portraits/`.
- Load and expose enemy visual resources through `ContentCatalog`.
- Validate enemy visual coverage, references, required fields, and portrait texture loading.
- Extend `CombatVisualResolver` with enemy visual fallback behavior.
- Render enemy portrait child nodes inside existing combat enemy entries.
- Keep `EnemyButton_<index>` as the click, drag, highlight, and presentation target node.
- Add tests for schema, catalog coverage, validation, resolver fallback, combat rendering, and unchanged targeting.
- Update README progress and Next Plans after acceptance.

Excluded:

- No enemy behavior changes.
- No enemy intent execution changes.
- No combat rule changes.
- No reward, event, shop, map, save, release, or localization changes.
- No animation timeline, skeletal animation, or idle motion system.
- No full combat layout redesign.
- No final bespoke art requirement.
- No DevTools enemy art preview in this phase.

## Approaches Considered

### Chosen: Enemy Visual Catalog And Combat Portrait Slots

Add separate enemy visual resources and let combat UI consume resolved display dictionaries. This matches the recent visual theme system and keeps presentation metadata out of core enemy definitions.

### Alternative: Add Visual Fields To `EnemyDef`

Add portrait fields directly to existing enemy resources. This would reduce file count, but it would mix gameplay/content data with presentation metadata and make future enemy visual variants harder to manage.

### Alternative: Full Enemy Presentation Pass

Add visual resources, portrait slots, boss/elite sizing, animation metadata, hit variants, and DevTools previews together. This is too broad for a safe foundation phase and would likely force a larger combat layout redesign.

## Data Model

Add `scripts/data/enemy_visual_def.gd`:

```gdscript
class_name EnemyVisualDef
extends Resource

@export var id: String = ""
@export var enemy_id: String = ""
@export var portrait_path: String = ""
@export var frame_style: String = ""
@export var accent_color: Color = Color.WHITE
@export var silhouette_tag: String = ""
@export var portrait_alt_label: String = ""
```

The `id` should match the enemy id for default catalog enemies. `portrait_alt_label` is inspectable metadata for tests and future accessibility/tooltips; it is not a localization system.

Default coverage must include:

- `training_puppet`
- `forest_bandit`
- `boss_heart_demon`
- `wild_fox_spirit`
- `ash_lantern_cultist`
- `stone_grove_guardian`
- `mirror_blade_adept`
- `venom_cauldron_hermit`
- `boss_storm_dragon`
- `scarlet_mantis_acolyte`
- `jade_armor_sentinel`
- `boss_void_tiger`
- `plague_jade_imp`
- `iron_oath_duelist`
- `miasma_cauldron_elder`
- `boss_sword_ghost`

## Asset Strategy

Add first-batch project-owned textures under:

- `assets/presentation/enemy_portraits/`

The first implementation should not require 16 unique polished illustrations. It should require 16 `EnemyVisualDef` resources, but those resources may share a smaller pool of portrait textures grouped by tier, silhouette, or faction.

Initial texture pool should include a safe fallback plus enough distinct foundation portraits to make normal, elite, and boss entries visibly different in tests and manual play.

Tests should verify portrait paths load as `Texture2D` through Godot.

## Content Catalog

`ContentCatalog` should load default enemy visual resources from:

- `resources/visuals/enemy_visuals/`

Add:

```gdscript
var enemy_visuals_by_enemy_id: Dictionary = {}
```

Add:

```gdscript
func get_enemy_visual(enemy_id: String) -> EnemyVisualDef
```

Validation should report:

- a default enemy with no enemy visual;
- an enemy visual with empty `enemy_id`;
- an enemy visual referencing a missing enemy;
- an enemy visual with empty `portrait_path`;
- a portrait path that does not load as `Texture2D`;
- an enemy visual with empty `frame_style`;
- a missing fallback portrait texture path used by the resolver.

## Resolver

Extend `scripts/presentation/combat_visual_resolver.gd`.

Recommended API:

```gdscript
func resolve_enemy_visual(enemy_id: String, catalog: Object) -> Dictionary
```

Resolved enemy visual dictionaries should include:

- `enemy_id`
- `portrait_path`
- `frame_style`
- `accent_color`
- `silhouette_tag`
- `portrait_alt_label`
- `is_known`

Fallback rules:

- If an enemy visual is missing, use a safe fallback portrait dictionary and mark `is_known = false`.
- If the catalog is null or does not expose enemy visuals, return fallback data.
- The resolver should not crash if catalog data is incomplete.

## UI Design

`CombatScreen` should keep existing combat entry behavior.

Expected node shape:

```text
EnemyButton_0
  EnemyContent_0
    EnemyVisualRoot_0
      EnemyPortraitFrame_0
      EnemyPortrait_0
    EnemySummaryLabel_0
    EnemyIntentRow_0
```

Requirements:

- `EnemyButton_<index>` remains the click, drag, highlight, and presentation target.
- Visual children ignore mouse input.
- Existing enemy summary and intent rows remain visible.
- Portrait texture comes from `EnemyVisualDef`.
- Frame/accent color comes from the enemy visual resource.
- Normal, elite, and boss encounters render portrait nodes.
- Enemy target selection remains functional.

No full production combat layout redesign is included. This phase adds enemy portrait slots to the existing programmatic combat UI.

## Data Flow

```text
EnemyDef.id
  -> ContentCatalog.get_enemy_visual(enemy_id)
  -> CombatVisualResolver.resolve_enemy_visual(enemy_id, catalog)
  -> CombatScreen EnemyPortrait_<index>
```

Presentation effects continue to bind to `EnemyButton_<index>`.

## Testing Strategy

Unit tests:

- `EnemyVisualDef` stores enemy id, portrait path, frame style, accent color, silhouette tag, and alt label.
- `ContentCatalog.load_default()` loads 16 enemy visual resources.
- Every default enemy has an enemy visual.
- Default enemy portrait paths load as `Texture2D`.
- Catalog validation reports missing and invalid enemy visual resources.
- `CombatVisualResolver` resolves a known enemy visual.
- `CombatVisualResolver` falls back safely for missing enemy visual data.

Combat smoke tests:

- A normal enemy combat entry renders `EnemyVisualRoot_<index>`, `EnemyPortraitFrame_<index>`, and `EnemyPortrait_<index>`.
- An elite enemy combat entry renders a portrait.
- A boss enemy combat entry renders a portrait.
- Enemy entries remain targetable through `EnemyButton_<index>` after portrait children are added.
- Existing enemy intent row tests continue to pass.

Boundary checks:

- `scripts/combat`, `scripts/reward`, `scripts/event`, `scripts/shop`, `scripts/save`, and `scripts/run` do not import enemy visual resources or depend on `CombatVisualResolver`.

## Implementation Stages

1. Add enemy visual schema.
   Verify schema tests fail first, then pass.

2. Add catalog loading and validation.
   Verify missing visual coverage and invalid references are reported.

3. Add first-batch enemy portrait assets and all 16 enemy visual resources.
   Verify catalog coverage and texture load tests pass.

4. Extend `CombatVisualResolver`.
   Verify known and fallback enemy visual resolution.

5. Render enemy portrait slots in combat.
   Verify stable nodes and unchanged targeting behavior.

6. Update README and run project review.
   Verify shared Godot checks, direct import check, boundary checks, and two-stage review.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify all 16 default enemies have catalog-backed enemy visual metadata.
- Verify enemy portrait texture paths load through Godot.
- Verify combat renders stable enemy portrait nodes.
- Verify normal, elite, and boss enemies render portraits.
- Verify missing enemy visual data falls back safely.
- Verify enemy target selection, drag targeting, intent rows, highlights, status pulses, and enemy intent polish still work.
- Verify no combat rules, save data, rewards, events, shops, map flow, release tooling, or localization changed.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Check `EnemyVisualDef` is data-only and focused.
- Check `ContentCatalog` enemy visual loading follows existing visual catalog patterns.
- Check `CombatVisualResolver` owns fallback behavior instead of scattering it through UI code.
- Check `CombatScreen` changes are scoped to rendering enemy visuals.
- Check visual children do not intercept enemy button input.
- Check tests use stable node names and real catalog resources.
- Check asset paths are validated through Godot loading.
- Check no unrelated refactors or formatting churn were included.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Documentation

Update README after acceptance:

- Add a Phase 2 progress bullet for enemy art foundation.
- Update Next Plans so enemy art foundation is no longer listed as open first-pass presentation scope.
- Keep formal audio mixing, polished per-card art replacement, and broader card-art rendering in rewards, shop, events, and deck views as future presentation expansion items.
- Keep release expansion unchanged.

No changelog entry is required unless this is later shipped with a release branch.

## Acceptance Criteria

- All 16 default enemies have catalog-backed visual metadata.
- Combat renders data-backed enemy portrait nodes.
- Normal, elite, and boss enemies all render portraits.
- Missing enemy visual data falls back safely and is reported by catalog validation.
- Enemy button targeting, drag targeting, highlights, status pulses, intent rows, and enemy intent polish remain functional.
- No core combat execution class imports enemy visual resources or the visual resolver.
- Shared Godot checks pass.
- Direct Godot import check exits 0.

## Future Work

- Replace foundation portraits with polished per-enemy art.
- Add enemy idle or hit animation metadata.
- Add larger boss presentation layouts.
- Add enemy art previews to DevTools.
- Add broader card-art rendering in rewards, shop, events, and deck views.
- Add formal audio mixing and volume controls.
