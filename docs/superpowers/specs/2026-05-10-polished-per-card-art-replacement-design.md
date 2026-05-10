# Polished Per-Card Art Replacement Design

Date: 2026-05-10

## Goal

Replace the current shared foundation card thumbnails with 40 unique project-owned PNG thumbnails, one for each default card, without changing gameplay or UI behavior.

This pass should make every catalog card feel visually distinct across combat, reward, shop, and event preview surfaces while continuing to use the existing `CardVisualDef` and `CombatVisualResolver` pipeline.

## Current Baseline

The project already has:

- 40 default card resources across sword and alchemy characters.
- 40 `CardVisualDef` resources under `resources/visuals/card_visuals/`.
- 7 current thumbnail PNGs under `assets/presentation/card_thumbnails/`: 6 shared foundation thumbnails plus `fallback_card.png`.
- Catalog validation that verifies card visual coverage and loadable texture paths.
- Combat hand thumbnails.
- Reward, shop, shop removal, and event direct-card previews through `CardVisualPresenter`.
- Fallback card visual behavior through `CombatVisualResolver`.

The current gap is that many cards still point to shared type-level foundation images such as `sword_attack.png`, `sword_skill.png`, and `alchemy_attack_status.png`. The visual pipeline is in place, but the card art is not yet card-specific.

## Confirmed Direction

Use a direct 40-asset replacement:

- Create and commit 40 unique project-owned PNG thumbnail assets.
- Keep the current `128x96` thumbnail dimensions.
- Repoint the existing 40 `CardVisualDef` resources to card-specific thumbnail paths.
- Keep the existing UI layout, resolver API, catalog shape, and fallback behavior.
- Add tests that require unique default-card thumbnail paths.

This is an asset and data pass, not a UI redesign or gameplay pass.

## Scope

Included:

- Add 40 unique card-specific PNG files under `assets/presentation/card_thumbnails/`.
- Use stable snake-case filenames derived from card ids:
  - `sword.strike` -> `sword_strike.png`
  - `alchemy.poison_mist` -> `alchemy_poison_mist.png`
- Update each existing `CardVisualDef.thumbnail_path` to its matching card-specific PNG.
- Update each `CardVisualDef.thumbnail_alt_label` to name the specific card thumbnail.
- Preserve existing `frame_style`, `accent_color`, and `element_tag` unless a direct card-specific correction is needed.
- Update tests that currently expect shared foundation thumbnail paths.
- Add coverage proving all default card visuals use unique thumbnail paths.
- Add coverage proving no default card visual uses the old shared foundation thumbnails.
- Update README progress and Next Plans after acceptance.

Excluded:

- No combat rule changes.
- No card effect, card cost, card type, reward, event, shop, map, save, release, Steam, or localization changes.
- No new deck browser or UI surface.
- No card preview layout redesign.
- No new `CardVisualDef` schema fields.
- No new art manifest or regeneration pipeline.
- No changes to enemy art, backgrounds, relic art, presentation cues, or audio.
- No deletion of existing shared foundation thumbnails unless implementation review proves a cleanup is directly necessary and safe.

## Art Direction

Use a hybrid thumbnail style: painterly xianxia-inspired backdrops with a bold central emblem, object, or action silhouette.

The goal is readable, distinct thumbnail art for small UI slots, not detailed full-card poster art.

Rules:

- Sword cards use crisp blade arcs, guard stances, meridian light, cloud-step movement, sword focus, and broken-stance fracture motifs.
- Alchemy cards use cauldrons, pills, mist, needles, jade paste, mercury bloom, poison vapor, refining circles, and elixir glow motifs.
- Each card needs a unique subject cue tied to the card id or card name.
- No text, logos, watermarks, UI chrome, borders, or card frames inside the PNG.
- Use regular rectangular PNGs with full artwork and no transparency requirement.
- Keep strong central silhouettes and contrast because previews can render compactly in `CardVisualPresenter`.
- Preserve broad character identity:
  - Sword assets lean cyan, gold, steel, cloud, and blade-energy motifs.
  - Alchemy assets lean jade, violet, gold, mist, elixir, and poison motifs.
- Avoid making all cards within one character pool look like recolors of the same image.

## Asset Model

Assets should live in:

```text
assets/presentation/card_thumbnails/
```

The first implementation should add these 40 files:

```text
alchemy_bitter_extract.png
alchemy_calming_powder.png
alchemy_cauldron_burst.png
alchemy_cauldron_overflow.png
alchemy_cinnabar_seal.png
alchemy_coiling_miasma.png
alchemy_golden_core_detox.png
alchemy_healing_draught.png
alchemy_inner_fire_pill.png
alchemy_mercury_bloom.png
alchemy_needle_rain.png
alchemy_ninefold_refine.png
alchemy_poison_mist.png
alchemy_purifying_brew.png
alchemy_quick_simmer.png
alchemy_smoke_screen.png
alchemy_spirit_distill.png
alchemy_toxic_pill.png
alchemy_toxin_needle.png
alchemy_white_jade_paste.png
sword_break_stance.png
sword_clear_mind_guard.png
sword_cloud_step.png
sword_echoing_sword_heart.png
sword_flash_cut.png
sword_focused_slash.png
sword_guard.png
sword_guardian_stance.png
sword_heart_piercer.png
sword_heaven_cutting_arc.png
sword_horizon_arc.png
sword_iron_wind_cut.png
sword_meridian_flash.png
sword_qi_surge.png
sword_rising_arc.png
sword_strike.png
sword_sword_resonance.png
sword_thread_the_needle.png
sword_unbroken_focus.png
sword_wind_splitting_step.png
```

All generated or created PNGs should be committed inside the project. Project-referenced assets must not remain only in an external generated-images directory.

Godot may generate `.import` files for the new PNGs during import. Include those generated import files in the implementation commit if they are created.

## Card Visual Resource Updates

Each existing `CardVisualDef` resource should stay in place and receive only targeted data updates.

Example:

```text
resources/visuals/card_visuals/sword_strike.tres
  thumbnail_path = "res://assets/presentation/card_thumbnails/sword_strike.png"
  thumbnail_alt_label = "Sword strike thumbnail"
```

The implementation should avoid rewriting unrelated fields or changing resource formatting beyond what is needed for the thumbnail path and alt label updates.

The fallback thumbnail remains:

```text
assets/presentation/card_thumbnails/fallback_card.png
```

Missing or unknown cards should continue resolving through the fallback path.

## Data Flow

The runtime data flow stays unchanged:

```text
CardDef.id
  -> ContentCatalog.get_card_visual(card_id)
  -> CombatVisualResolver.resolve_card_visual(card_id, catalog, theme)
  -> CombatScreen hand card thumbnails
  -> CardVisualPresenter previews in reward/shop/event surfaces
```

Only the resolved `thumbnail_path` values change for known default cards.

## Testing Strategy

Unit tests:

- `ContentCatalog.load_default()` still loads exactly 40 card visuals.
- Representative sword and alchemy card visuals resolve to card-specific filenames, not shared foundation filenames.
- Every default card visual texture path loads as `Texture2D`.
- Every default card visual has a unique `thumbnail_path`.
- No default card visual points to these old shared foundation thumbnails:
  - `sword_attack.png`
  - `sword_skill.png`
  - `sword_power.png`
  - `alchemy_attack_status.png`
  - `alchemy_skill.png`
  - `alchemy_power.png`
- `CombatVisualResolver.resolve_card_visual()` returns the new card-specific path and specific alt label for a representative card.
- Missing card fallback still uses `fallback_card.png`.

Smoke tests:

- Existing combat hand thumbnail smoke tests continue to pass.
- Existing reward card preview smoke tests continue to pass.
- Existing shop card offer and remove-choice preview smoke tests continue to pass.
- Existing event direct-card preview smoke tests continue to pass.
- No new UI interactions are required for this pass.

Asset verification:

- Run the shared Godot check script so Godot imports new PNGs and validates project load.
- Confirm the direct import check exits 0.

## Review Requirements

Run the project-required two-stage review after implementation.

Stage 1: Spec Compliance Review

- Verify all 40 default cards have unique project-owned PNG thumbnails.
- Verify each `CardVisualDef` points to its matching card-specific thumbnail.
- Verify every thumbnail path loads through Godot.
- Verify no default card visual still points to the old shared foundation thumbnails.
- Verify fallback behavior still points to `fallback_card.png`.
- Verify combat, reward, shop, shop removal, and event preview surfaces still render through existing paths.
- Verify no gameplay, save schema, card effect, reward, event, shop, map, release, Steam, audio, enemy art, background, or localization changes were added.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Check the implementation is asset/data focused and does not add unnecessary abstractions.
- Check tests are focused on catalog coverage, path uniqueness, texture loading, and fallback behavior.
- Check resource updates are surgical and avoid unrelated formatting churn.
- Check generated import files are included only for the new PNG assets.
- Check old shared foundation thumbnails are not removed unless the implementation proves that removal is directly safe.
- Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Documentation

After implementation acceptance:

- Add a README Phase 2 Progress bullet for polished per-card art replacement.
- Update README Next Plans so polished per-card art replacement is no longer listed as open presentation scope.
- Keep release expansion as a future lane.

No changelog entry is required unless this is later shipped with a release branch.

## Acceptance Criteria

- 40 unique card-specific PNG thumbnails exist under `assets/presentation/card_thumbnails/`.
- All 40 default `CardVisualDef` resources point to card-specific thumbnail paths.
- Each default card visual has a specific thumbnail alt label.
- All default card thumbnail paths load as `Texture2D`.
- No default card visual uses the old shared foundation thumbnail paths.
- Missing-card fallback still resolves to `fallback_card.png`.
- Combat hand cards, reward choices, shop card offers, shop remove choices, and direct-card event previews continue rendering through existing UI paths.
- No gameplay, save, card effect, reward, shop, event, map, release, Steam, audio, enemy art, background, or localization behavior changes are added.
- Shared Godot checks pass.
- Direct Godot import check exits 0.

## Future Work

- Add full-size card artwork or hover/detail card panels if the UI later needs larger art.
- Add a lightweight art-generation manifest only if repeatable regeneration becomes useful.
- Add relic visuals to reward and shop surfaces.
- Add release expansion: packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
