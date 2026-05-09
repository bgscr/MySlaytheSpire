# Broader Card Art Rendering Design

Date: 2026-05-09

## Goal

Propagate the existing data-backed card visual system beyond combat so reward, shop, event, and existing deck-list surfaces can show compact card art previews without changing gameplay.

The project already has `CardVisualDef` resources for all 40 default cards, a `CombatVisualResolver` that resolves card thumbnails and fallback data, and combat hand cards that render thumbnail slots. This phase should reuse that foundation on existing non-combat surfaces.

This is a rendering propagation pass. It is not a polished per-card art replacement pass and does not add a new deck browser or navigation flow.

## Current Baseline

The project already has:

- `CardVisualDef` resources for all default catalog cards.
- `ContentCatalog.get_card_visual()` and visual validation.
- `CombatVisualResolver.resolve_card_visual()`.
- Combat hand card thumbnail rendering with stable `CardThumbnail_<index>`, `CardFrame_<index>`, and `CardText_<index>` nodes.
- Reward screen card choice buttons.
- Shop screen card offers and card-removal choices.
- Event screen options that can grant cards, remove cards, or route to pending reward choices.
- DevTools and save inspector text summaries that already list deck ids.

Current gaps:

- Reward card choices are text-only.
- Shop card offers are text-only.
- Shop card-removal choices are text-only.
- Event options expose card grants/removals through text but do not render card previews.
- Existing deck summaries list card ids rather than compact visual rows.

## Confirmed Direction

Use a small shared UI helper for card previews on existing surfaces only.

Add a focused `CardVisualPresenter` helper that builds compact visual children for a supplied card id. Reward, shop, event, and existing deck-list surfaces can call the helper while preserving their existing buttons, labels, state transitions, save behavior, and routing.

Do not create a new player-facing deck browser in this phase.

## Scope

Included:

- Add a small UI-only `CardVisualPresenter` helper.
- Render card previews for reward screen card choices.
- Render card previews for shop card offers.
- Render card previews for shop card-removal choices.
- Render card previews for event options that directly grant cards or remove a card.
- Render compact card previews on existing deck-list-style surfaces only when those surfaces already have a real container that can hold children.
- Keep pending event card rewards flowing through the reward screen and use the reward screen previews there.
- Add tests for helper behavior, stable node names, fallback visuals, and unchanged interactions.
- Update README progress and Next Plans after acceptance.

Excluded:

- No new deck browser scene, deck modal, map navigation, or global deck-view feature.
- No polished per-card art replacement.
- No new card visual resources, card resources, reward contents, shop contents, or event contents.
- No reward, shop, event, map, combat, save, or release logic changes.
- No relic art, enemy art, background art, animation, formal audio mixing, or audio controls.
- No localization changes.
- No combat card rendering refactor.

## Approaches Considered

### Chosen: Small Shared Card Preview Helper

Add `scripts/ui/card_visual_presenter.gd` as a focused UI helper. It builds the repeated frame, thumbnail, and text children for a card id using the existing catalog and resolver.

This keeps the change small while avoiding duplicated visual-building code across reward, shop, event, and deck-summary surfaces.

### Alternative: Screen-Local Rendering

Each screen could build its own `TextureRect`, `ColorRect`, and label. This would be fast initially, but it would repeat the combat card visual pattern in several places and make future preview adjustments more brittle.

### Alternative: Full Reusable Card Widget

A full `CardPreview` control could own layout, state, interaction, and future tooltip behavior. That may be useful later, but it is too much abstraction for this rendering propagation pass.

## Card Visual Presenter

Add `scripts/ui/card_visual_presenter.gd`.

Recommended API:

```gdscript
class_name CardVisualPresenter
extends RefCounted

static func add_card_preview(
	parent: Control,
	prefix: String,
	suffix: String,
	card_id: String,
	catalog: Object,
	theme: Dictionary = {}
) -> Control
```

The helper should:

- Resolve card visual data through `CombatVisualResolver.resolve_card_visual(card_id, catalog, theme)`.
- Look up `ContentCatalog.get_card(card_id)` when available for text.
- Add a compact root control under `parent`.
- Add a frame, thumbnail, and text label as children.
- Use stable node names based on the supplied prefix and suffix.
- Set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on preview children.
- Return the preview root so callers can place it or inspect it in tests.
- Fall back safely when `catalog` is null, the card is missing, or visual data is missing.

Expected node shape for a reward card choice:

```text
RewardCardVisual_0_0
  RewardCardFrame_0_0
  RewardCardThumbnail_0_0
  RewardCardText_0_0
```

Expected surface prefixes:

- `RewardCard`
- `ShopOfferCard`
- `ShopRemoveCard`
- `EventOptionCard`
- `DeckSummaryCard` only for existing deck-list surfaces that already render child rows

The helper should not connect signals or mutate any run state.

## Surface Behavior

### Reward Screen

For each `card_choice` reward item, keep the existing `ClaimCard_<reward_index>_<card_index>` button as the claim target. Add a card preview inside or immediately under that button so the card choice has art, frame color, and compact card text.

Requirements:

- Claiming a card still adds the selected card to the run deck.
- Skipping, reward state refresh, continue gating, saving, and routing stay unchanged.
- Claimed or skipped reward rows may drop action previews after rerendering, matching the current action removal behavior.

### Shop Screen

For each unsold card offer, show a card preview near the offer text and buy button.

Requirements:

- `BuyOffer_<offer_id>` remains the buy target.
- Sold card offers can show either the preview plus sold state or the existing sold-only text, as long as unsold card offers are visually represented before purchase.
- Relic, heal, and remove service offers stay text-only except for remove choices.
- Buying, refresh, save behavior, and leaving the shop stay unchanged.

### Shop Removal Choices

When the user chooses a remove service, each `RemoveCard_<index>` choice should render a preview for that deck card.

Requirements:

- Duplicate card ids remain distinct by index.
- Pressing `RemoveCard_<index>` removes the selected card id through the existing shop runner path.
- The one-card-minimum and affordability rules stay unchanged.

### Event Screen

For each event option, render compact previews for direct card grants and direct card removals:

- `grant_card_ids`
- `remove_card_id`

Options that create pending card rewards through `card_reward_count` should remain text-only on the event screen because the actual choices are generated and displayed on the reward screen.

Requirements:

- `EventOption_<index>` remains the option target.
- Availability text and disabled state stay unchanged.
- Applying options, saving, reward routing, and map advancement stay unchanged.

### Existing Deck-List Surfaces

This phase adds deck-list previews only where an existing UI surface already renders deck entries as child rows. It must not create new navigation, a new deck modal, or a new deck browser.

Current debug/dev/save summaries that expose the deck only through a single text label remain text-only for this phase.

## Data Flow

```text
card_id
  -> ContentCatalog.get_card(card_id)
  -> CombatVisualResolver.resolve_theme(run.character_id, catalog)
  -> CombatVisualResolver.resolve_card_visual(card_id, catalog, theme)
  -> CardVisualPresenter.add_card_preview(...)
  -> Existing screen button or container renders compact card preview children
```

Theme selection should use the active run character id when a run is available. If no run is available, callers can pass an empty theme and allow resolver fallback behavior.

## Error Handling

- Missing card id: render fallback thumbnail and text using the raw card id.
- Missing visual resource: use existing resolver fallback thumbnail.
- Missing texture path: render with no texture rather than crashing.
- Missing catalog: render fallback text and fallback visual data.
- Duplicate deck card ids: suffix node names with the deck index so nodes remain unique.

The UI should not push errors for expected fallback paths. Catalog validation already owns default-card visual coverage.

## Testing Strategy

Unit tests:

- `CardVisualPresenter` creates root, frame, thumbnail, and text nodes for a known card.
- The thumbnail loads through the existing card visual resource path.
- Visual children ignore mouse input.
- A missing card id renders fallback visual data and raw id text.
- Duplicate card ids can render with distinct suffixes.

Smoke tests:

- Reward screen renders card previews for card choices and still claims/skips/continues.
- Shop screen renders card previews for unsold card offers and still buys/saves.
- Shop removal choices render card previews and still remove the selected indexed card.
- Event screen renders direct grant/remove card previews and still applies options.
- Pending event card rewards route to the reward screen and render reward card previews there.
- Existing text-only deck summaries remain acceptable when there is no suitable container.

Boundary checks:

- No reward, shop, event, combat, save, map, run, release, or content logic class imports `CardVisualPresenter`.
- No new card resources or card visual resources are added.
- No save schema changes.

## Implementation Stages

1. Add `CardVisualPresenter`.
   Verify helper unit tests fail first, then pass.

2. Render reward card previews.
   Verify card choice previews and existing reward claim/skip/continue behavior.

3. Render shop card offer and remove-choice previews.
   Verify buy, refresh, remove, save, and leave behavior remains unchanged.

4. Render event direct card grant/remove previews.
   Verify option availability, apply behavior, pending reward routing, and map advancement.

5. Verify existing deck-list surfaces.
   Add previews only if a child-row deck container already exists; otherwise leave current text summaries unchanged and document that no new deck view was added.

6. Update README and run project review.
   Verify shared Godot checks, boundary checks, spec compliance review, and code quality review.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify reward card choices render data-backed card previews.
- Verify shop card offers render data-backed card previews.
- Verify shop remove choices render data-backed card previews and preserve duplicate-card index behavior.
- Verify event direct grant/remove card options render data-backed previews.
- Verify pending event card rewards render on the reward screen.
- Verify no new deck browser, deck modal, navigation, gameplay, save schema, or content changes were added.
- Verify reward, shop, event, save, and routing behavior remains unchanged.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Check `CardVisualPresenter` is small, typed, UI-only, and focused.
- Check the helper uses existing `CombatVisualResolver` fallback behavior.
- Check visual children do not intercept button input.
- Check screen changes are scoped to rendering and stable node naming.
- Check tests use real catalog resources and stable node names.
- Check no unrelated refactors or formatting churn were included.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Documentation

Update README after acceptance:

- Add a Phase 2 progress bullet for broader card art rendering.
- Update Next Plans so broader card-art rendering in rewards, shop, events, and existing deck-list surfaces is no longer listed as open scope.
- Keep formal audio mixing and polished per-card art replacement in future presentation expansion.
- Keep release expansion unchanged.

No changelog entry is required unless this is later shipped with a release branch.

## Acceptance Criteria

- Reward card choices render card previews from catalog-backed visual data.
- Shop card offers render card previews from catalog-backed visual data.
- Shop card-removal choices render card previews while preserving indexed duplicate choices.
- Event options with direct card grant/remove effects render compact card previews.
- Pending event card rewards render through reward screen card previews.
- Existing deck-list surfaces are either upgraded where structurally suitable or explicitly left text-only without adding new navigation.
- Missing card or visual data falls back safely.
- Existing reward, shop, event, save, routing, and combat behavior remains unchanged.
- No new card resources, card visual resources, save schema, deck browser, or polished art pipeline is added.
- Shared Godot checks pass.

## Future Work

- Replace foundation card thumbnails with polished per-card art.
- Add a dedicated player-facing deck browser or deck modal.
- Add tooltip/detail panels for visual card previews.
- Add relic visuals to reward and shop surfaces.
- Add formal audio mixing, volume controls, and audio bus settings.
