# Reusable Item Preview And Detail Presentation Design

Date: 2026-05-10

## Goal

Add a reusable presentation system for compact card and relic previews, shared hover/focus detail panels, and 20 unique project-owned relic icon assets.

This slice should make cards and relics feel like first-class visual items across combat, reward, shop, event, and existing DevTools reward surfaces while preserving all current gameplay, save, routing, pricing, and reward behavior.

## Current Baseline

The project already has:

- 40 default cards with `CardVisualDef` resources and unique polished `128x96` thumbnails.
- A `CombatVisualResolver` that resolves card visuals and theme data.
- A small `CardVisualPresenter` used by reward, shop, removal, and event card preview surfaces.
- Combat hand cards with separate inline visual construction and existing hover/focus-adjacent event hooks.
- 20 default relic resources with ids, tiers, trigger events, and effects.
- Relic rewards and shop relic offers that are still text-only.
- Event options that can grant relics directly, but currently only card grant/remove options render compact previews.
- DevTools reward inspector claim controls that remain mostly text-driven.

The gap is no longer whether cards can display art; the gap is that item presentation is split across several screen scripts, card details are not shared across surfaces, and relics have no visual resources or icons.

## Confirmed Direction

Use a bounded reusable item presentation system:

- Support exactly two item kinds in this slice: cards and relics.
- Add shared compact preview rendering through an item presenter.
- Add a shared read-only detail panel that appears on hover or focus only.
- Add 20 unique relic icon PNGs and catalog-backed relic visual resources.
- Wire the shared system into existing surfaces without adding new navigation or changing interaction targets.

This is a presentation and visual data pass, not an inventory framework, gameplay pass, release pass, or UI redesign.

## Scope

Included:

- Add `RelicVisualDef` resource data for relic icon path, frame style, accent color, tier style, and icon alt label.
- Add 20 `RelicVisualDef` resources under `resources/visuals/relic_visuals/`.
- Add 20 unique project-owned small relic icon PNGs under `assets/presentation/relic_icons/`.
- Register and validate relic visuals in `ContentCatalog`.
- Add an `ItemVisualPresenter` for compact card and relic previews.
- Add an `ItemDetailPanel` for read-only card and relic details.
- Make card and relic detail panels appear on hover and keyboard/controller focus only.
- Use stable node names for tests and future surface wiring.
- Preserve existing action buttons and rows as the click targets.
- Replace or wrap existing `CardVisualPresenter` surgically so existing card-preview callers migrate safely.
- Show card details on combat hand cards, reward card choices, shop card offers, shop removal choices, and event direct-card previews.
- Show relic previews and details on reward relics, shop relic offers, direct relic-grant event options, and DevTools reward inspector relic claims where that control already exists.
- Update README progress and Next Plans after acceptance.

Excluded:

- No true full-size bespoke card art generation.
- No new deck browser, inventory screen, relic collection screen, modal browser, or navigation route.
- No click-to-pin detail panel behavior.
- No drag/drop, equipment, item ownership, item sorting, or generalized inventory model.
- No potions or future item kinds.
- No changes to card effects, relic effects, reward generation, shop prices, event outcomes, map flow, combat rules, save schema, release tooling, Steam work, audio, enemy art, backgrounds, or localization.
- No broad screen layout redesign beyond space needed for existing compact previews and one shared detail panel.

## Approaches Considered

### Chosen: Bounded Reusable Item Preview System

Create a small reusable system for card and relic previews plus read-only hover/focus details. The public API should stay explicit rather than fully generic:

```gdscript
ItemVisualPresenter.add_card_preview(...)
ItemVisualPresenter.add_relic_preview(...)
ItemDetailPanel.show_card(...)
ItemDetailPanel.show_relic(...)
```

This keeps card/relic behavior consistent and makes future polish easier without inventing a generic item framework.

### Alternative: Focused Shared Presenters

Keep card and relic presenters separate and add a detail panel on top. This is simpler in the short term, but card and relic surfaces would still need more duplicated wiring for hover/focus detail behavior.

### Alternative: Screen-Local Rendering

Patch each screen directly. This would be fastest to start, but it would spread repeated preview/detail code across combat, reward, shop, event, and DevTools scripts.

## Architecture

### Relic Visual Data

Add `scripts/data/relic_visual_def.gd`:

```gdscript
class_name RelicVisualDef
extends Resource

@export var id: String = ""
@export var relic_id: String = ""
@export var icon_path: String = ""
@export var frame_style: String = ""
@export var accent_color: Color = Color.WHITE
@export var tier_style: String = ""
@export var icon_alt_label: String = ""
```

`ContentCatalog` should load default relic visual paths into `relic_visuals_by_relic_id`, expose `get_relic_visual(relic_id)`, and validate:

- every default relic has a visual.
- every relic visual references an existing relic.
- every icon path is non-empty and loads as `Texture2D`.
- a fallback relic icon path exists and loads.

### Item Visual Presenter

Add `scripts/ui/item_visual_presenter.gd`.

Responsibilities:

- Create compact card preview roots using existing `CardVisualDef` and `CombatVisualResolver`.
- Create compact relic preview roots using `RelicVisualDef` and catalog fallback data.
- Use stable node names:
  - `<prefix>CardVisual_<suffix>`
  - `<prefix>CardFrame_<suffix>`
  - `<prefix>CardThumbnail_<suffix>`
  - `<prefix>CardText_<suffix>`
  - `<prefix>RelicVisual_<suffix>`
  - `<prefix>RelicFrame_<suffix>`
  - `<prefix>RelicIcon_<suffix>`
  - `<prefix>RelicText_<suffix>`
- Set preview children to `Control.MOUSE_FILTER_IGNORE` so they never steal button presses.
- Attach enough metadata for tests and detail panel resolution:
  - `item_kind`
  - `item_id`
  - `is_known`
  - visual style tags
- Return the preview root so callers can place or inspect it.
- Avoid mutating run state, reward state, shop state, event state, or combat state.

`CardVisualPresenter` can remain as a compatibility wrapper that forwards to `ItemVisualPresenter.add_card_preview`, or existing callers can migrate directly if the implementation plan finds that cleaner.

### Item Detail Panel

Add `scripts/ui/item_detail_panel.gd`.

Responsibilities:

- Own one read-only panel instance per screen.
- Show card details from a card id, catalog, and optional theme.
- Show relic details from a relic id and catalog.
- Hide on mouse exit, focus exit, rerender, or owner removal.
- Never claim, buy, play, remove, skip, select, route, save, or otherwise mutate state.

Card detail content:

- Polished thumbnail.
- Card id/name text from existing catalog data.
- Type, rarity, cost, and character id.
- Compact effect summary using existing `EffectDef` fields.
- Safe fallback text for missing cards or missing visuals.

Relic detail content:

- Unique relic icon.
- Relic id/name text from existing catalog data.
- Tier.
- Trigger event.
- Compact effect summary using existing `EffectDef` fields.
- Safe fallback text for missing relics or missing visuals.

Hover/focus behavior:

- `mouse_entered` or `focus_entered` on the owning button/control shows the detail panel.
- `mouse_exited` or `focus_exited` hides it.
- There is no click-to-pin state in this slice.

### Surface Wiring

Combat:

- Replace inline hand-card visual construction with the item presenter or a thin helper around it.
- Preserve `CardButton_<index>` as the play/select target.
- Keep existing hover presentation events and card drag/play behavior.
- Add detail panel show/hide for hand cards on hover/focus.

Reward:

- Card choices keep `ClaimCard_<reward_index>_<card_index>`.
- Relic rewards keep `ClaimRelic_<reward_index>`.
- Add card/relic previews inside or immediately under those buttons.
- Claim, skip, continue gating, saving, and routing stay unchanged.

Shop:

- Card offers keep `BuyOffer_<offer_id>`.
- Relic offers keep `BuyOffer_<offer_id>`.
- Removal choices keep `RemoveCard_<index>`.
- Add card/relic previews and hover/focus details without changing buy/remove/refresh/leave behavior.

Event:

- Existing `EventOption_<index>` buttons remain the option targets.
- Direct `grant_card_ids` and `remove_card_id` previews use item presenter card previews.
- Direct `grant_relic_ids` previews use item presenter relic previews.
- Pending generated reward options stay routed to the reward screen for their actual choices.
- Event option availability and apply behavior stay unchanged.

DevTools:

- Reward inspector can show relic previews/details where it already renders relic claim controls.
- Do not add a new DevTools route, item browser, or modal.

## Relic Icon Assets

Assets should live in:

```text
assets/presentation/relic_icons/
```

Add these first-pass icon files:

```text
black_pill_vial.png
bronze_incense_burner.png
cloudstep_sandals.png
copper_mantis_hook.png
cracked_spirit_coin.png
dragon_bone_flute.png
immortal_peach_core.png
jade_talisman.png
mist_vein_bracelet.png
moonwell_seed.png
mothwing_sachet.png
nine_smoke_censer.png
paper_lantern_charm.png
rusted_meridian_ring.png
silk_thread_prayer.png
starforged_meridian.png
thunderseal_charm.png
verdant_antidote_gourd.png
void_tiger_eye.png
white_tiger_tally.png
```

Also add a fallback icon:

```text
fallback_relic.png
```

Recommended dimensions: `96x96`. The implementation plan may choose another small square size only if it documents why and tests the loaded texture paths.

Art direction:

- Painterly xianxia item icons with a strong central silhouette.
- No text, numbers, logos, watermarks, UI chrome, or borders inside the PNG.
- Relic identities should be distinct at small size.
- Tier colors can appear through frame/accent data, not painted text.
- Use project-owned generated or hand-authored bitmap assets committed inside the repo.

Suggested icon subjects:

- `black_pill_vial`: black-green vial with toxic pill glow.
- `bronze_incense_burner`: bronze censer with warm protective smoke.
- `cloudstep_sandals`: light sandals trailing white-blue cloud wisps.
- `copper_mantis_hook`: copper hook shaped like a mantis claw.
- `cracked_spirit_coin`: cracked old coin with spirit light leaking out.
- `dragon_bone_flute`: pale bone flute with dragon-scale etching.
- `immortal_peach_core`: glowing peach pit with immortal nectar aura.
- `jade_talisman`: polished jade charm with protective glow.
- `mist_vein_bracelet`: bracelet threaded with misty blue veins.
- `moonwell_seed`: luminous seed cupped in moonlit water.
- `mothwing_sachet`: small sachet with pale wing-like cloth.
- `nine_smoke_censer`: nine wisps rising from a small censer.
- `paper_lantern_charm`: folded lantern charm with soft amber light.
- `rusted_meridian_ring`: rusted ring traced with faint meridian sparks.
- `silk_thread_prayer`: red silk prayer thread tied around a charm.
- `starforged_meridian`: star-metal meridian disk with celestial lines.
- `thunderseal_charm`: talisman snapped with blue-white lightning.
- `verdant_antidote_gourd`: green gourd with cleansing leaf aura.
- `void_tiger_eye`: dark tiger eye gem with void-purple slit light.
- `white_tiger_tally`: white tiger command tally with ivory-gold mark.

## Data Flow

Card:

```text
card_id
  -> ContentCatalog.get_card(card_id)
  -> CombatVisualResolver.resolve_theme(character_id, catalog)
  -> CombatVisualResolver.resolve_card_visual(card_id, catalog, theme)
  -> ItemVisualPresenter.add_card_preview(...)
  -> ItemDetailPanel.show_card(...)
```

Relic:

```text
relic_id
  -> ContentCatalog.get_relic(relic_id)
  -> ContentCatalog.get_relic_visual(relic_id)
  -> ItemVisualPresenter.add_relic_preview(...)
  -> ItemDetailPanel.show_relic(...)
```

Unknown or missing item data should fall back to readable raw ids and fallback visual assets rather than crashing.

## Testing Strategy

Unit tests:

- `RelicVisualDef` stores icon path, frame style, accent color, tier style, and alt label.
- `ContentCatalog.load_default()` loads exactly 20 relic visuals.
- Catalog validation reports missing relic visuals for default relics.
- Catalog validation reports relic visuals that reference missing relic ids.
- Every default relic visual icon path loads as `Texture2D`.
- The fallback relic icon path loads as `Texture2D`.
- `ItemVisualPresenter.add_card_preview()` creates stable card nodes and preserves mouse-ignore child behavior.
- `ItemVisualPresenter.add_relic_preview()` creates stable relic nodes and preserves mouse-ignore child behavior.
- Missing card and relic ids render fallback-safe previews.
- Duplicate card ids and duplicate relic ids can render with unique suffixes.
- `ItemDetailPanel` shows and hides card details without mutating state.
- `ItemDetailPanel` shows and hides relic details without mutating state.

Smoke tests:

- Combat hand card hover/focus shows and hides a card detail panel while card play, target selection, drag, and cancel behavior still work.
- Reward card choices still claim/skip/continue and show card details.
- Reward relics show relic previews/details and still claim/skip/continue.
- Shop card offers, relic offers, and removal choices show previews/details while buy/remove/refresh/save/leave behavior stays unchanged.
- Event direct card and relic options show previews/details while option availability, apply behavior, reward routing, and map advancement stay unchanged.
- DevTools reward inspector keeps existing claim/skip/reset behavior if previews are added there.

Boundary checks:

- No card, relic, reward, shop, event, combat, run, save, map, release, Steam, audio, enemy art, background, or localization behavior changes.
- No new save fields.
- No new item kinds beyond card and relic.
- No generic inventory abstractions.
- Existing click targets remain available under their current node names.

## Implementation Stages

1. Add relic visual schema and catalog validation.
2. Add tests for relic visual loading and fallback behavior.
3. Generate or create the 20 relic icon PNGs plus fallback icon.
4. Add `ItemVisualPresenter` card/relic preview creation and migrate/wrap card preview callers.
5. Add `ItemDetailPanel` and unit tests for card/relic show/hide behavior.
6. Wire combat hand card details.
7. Wire reward card/relic previews and details.
8. Wire shop card/relic/remove previews and details.
9. Wire event direct card/relic previews and details.
10. Wire DevTools reward inspector relic previews only where existing controls fit.
11. Update README progress and run the required two-stage project review.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify the reusable system supports cards and relics only.
- Verify all 20 default relics have unique project-owned icon assets.
- Verify all 20 default relics have catalog-backed `RelicVisualDef` resources.
- Verify card previews still resolve through existing card visual data.
- Verify card and relic detail panels appear on hover/focus only.
- Verify no click-to-pin behavior was added.
- Verify combat, reward, shop, event, and selected DevTools surfaces use the new system where scoped.
- Verify existing click targets, claim/buy/play/remove/skip/apply behavior, saving, and routing are preserved.
- Verify no gameplay, save schema, reward generation, shop pricing, event effects, map, release, Steam, audio, enemy art, background, or localization changes were added.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Check `ItemVisualPresenter` and `ItemDetailPanel` are small, typed, and presentation-only.
- Check the public API is explicit for card/relic rather than a vague all-purpose item framework.
- Check preview children do not intercept input.
- Check screen changes are limited to presentation wiring.
- Check tests use real catalog resources and stable node names.
- Check generated import files are included only for new relic icon assets.
- Check old card visual paths and fallback behavior remain intact.
- Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before final acceptance.

## Documentation

After implementation acceptance:

- Add a README Phase 2 Progress bullet for reusable item preview and detail presentation.
- Update README Next Plans so relic visuals and first-pass card detail panels are no longer listed as open presentation scope.
- Keep true full-size card art and release expansion as future lanes.

No changelog entry is required unless this later ships with a release branch.

## Acceptance Criteria

- 20 unique relic icon PNGs and one fallback relic icon exist under `assets/presentation/relic_icons/`.
- All 20 default relics have `RelicVisualDef` resources.
- All default relic icon paths load as `Texture2D`.
- `ContentCatalog` loads and validates relic visuals.
- Compact card previews continue to render from card visual data across existing surfaces.
- Compact relic previews render in reward, shop, direct event, and scoped DevTools surfaces.
- Card and relic detail panels appear on hover/focus and hide on exit.
- Detail panels are read-only and do not mutate gameplay or UI state.
- Combat hand card play/drag/target behavior remains unchanged.
- Reward claim/skip/continue behavior remains unchanged.
- Shop buy/remove/refresh/leave behavior remains unchanged.
- Event option apply/reward-routing/map-advance behavior remains unchanged.
- No save schema changes are added.
- Shared Godot checks pass.
- Direct Godot import check exits 0.

## Future Work

- Add true full-size card artwork for detail panels.
- Add richer relic collection or run-summary relic views.
- Add controller-specific focus polish if the project later adds full controller support.
- Add potion or future item kinds only after they exist as real gameplay concepts.
- Add release expansion: zipping, checksums, version bump automation, signing, upload automation, and eventual Steam adapter implementation.
