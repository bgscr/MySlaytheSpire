# Visual Theme System Design

Date: 2026-05-02

## Goal

Build a reusable combat visual theme system that introduces card art thumbnails and combat background presentation without changing gameplay.

The project already has data-owned combat presentation cues and enemy intent display metadata. This phase extends that direction to broader visual identity: cards should have catalog-backed thumbnail metadata, combat should render a data-backed backdrop, and sword/alchemy runs should be able to present distinct visual themes.

This is a heavier visual-system pass, but the first implementation should still be staged and verifiable.

## Current Baseline

The project already has:

- `CardDef` resources for 40 default catalog cards.
- `CharacterDef` resources for sword and alchemy characters.
- `ContentCatalog` loading cards, characters, enemies, relics, events, and enemy intent displays.
- `CardPresentationCueDef` resources embedded in default card resources.
- `CombatPresentationAssetCatalog` for cue-driven textures and audio.
- `CombatScreen`, which renders combat UI programmatically.
- `CombatPresentationLayer`, which plays presentation effects above the combat UI.
- Stable combat smoke tests for card click, drag, targeting, presentation effects, and enemy intent display rows.

Current gaps:

- Cards have presentation cues but no card-thumbnail visual metadata.
- Combat has presentation effects but no data-backed background layer.
- Character identity exists in content, but there is no visual theme resource tying cards and backgrounds together.
- Existing card button rendering is text-first and has no visual thumbnail slot.

## Confirmed Direction

Use a full visual theme system rather than a one-off texture lookup.

The system should add explicit visual metadata resources for:

1. Card thumbnails.
2. Combat backgrounds.
3. Character visual themes.

The first pass should prove the full resource and rendering path while allowing many cards to share a smaller pool of foundation thumbnail textures. It does not need 40 bespoke polished illustrations.

## Scope

Included:

- Add `CardVisualDef` resources for default catalog cards.
- Add `CombatBackgroundDef` resources for combat backdrop metadata.
- Add `VisualThemeDef` resources for character visual identity.
- Load visual resources through `ContentCatalog`.
- Validate visual references, required fields, fallback resources, and texture paths.
- Add a `CombatVisualResolver` that chooses card visuals, character themes, and combat backgrounds.
- Render a combat background layer behind existing combat controls.
- Render card thumbnail child nodes inside existing hand card buttons.
- Keep existing `CardButton_<index>` nodes clickable and draggable.
- Add first-batch project-owned visual texture assets under `assets/presentation/`.
- Add tests for schemas, catalog coverage, resolver fallback, combat background rendering, card thumbnail rendering, and unchanged card interaction.
- Update README progress and Next Plans after acceptance.

Excluded:

- No combat rule changes.
- No card effect, reward, event, shop, map, save, or release tooling changes.
- No enemy art or animated enemy sprites.
- No final full-card frame redesign.
- No deck, reward, shop, event, or map card-art rendering.
- No runtime procedural art generation.
- No localization changes.
- No formal audio mixing or volume controls.
- No external art pipeline integration.

## Approaches Considered

### Chosen: Full Visual Theme System

Add data resources for card visuals, combat backgrounds, and character themes. Use a resolver to select the right presentation data for combat UI.

This is the best fit because the user explicitly chose the heavier direction and because it matches the project's recent migration pattern: presentation data moves into resources first, then UI consumes resolved display dictionaries.

### Lighter Alternative: UI-Only Texture Mapping

Keep `CardDef` unchanged and add a presentation-side card-id-to-texture dictionary.

This would be faster, but it would repeat the fallback-map pattern and make future theme work harder.

### Narrow Alternative: First-Batch Art Slots Only

Add thumbnail fields directly to cards and one default background.

This would be simple, but it would not establish a reusable visual theme layer for character identity or encounter presentation.

## Data Model

Add `scripts/data/card_visual_def.gd`:

```gdscript
class_name CardVisualDef
extends Resource

@export var id: String = ""
@export var card_id: String = ""
@export var thumbnail_path: String = ""
@export var frame_style: String = ""
@export var accent_color: Color = Color.WHITE
@export var element_tag: String = ""
@export var thumbnail_alt_label: String = ""
```

The `id` should match the card id for default catalog cards. `thumbnail_alt_label` is an inspectable label for tests and future accessibility/tooltips; it is not a localization system.

Add `scripts/data/combat_background_def.gd`:

```gdscript
class_name CombatBackgroundDef
extends Resource

@export var id: String = ""
@export var texture_path: String = ""
@export var environment_tag: String = ""
@export_enum("normal", "elite", "boss", "any") var encounter_tier: String = "any"
@export var accent_color: Color = Color.WHITE
@export_range(0.0, 1.0, 0.01) var dim_opacity: float = 0.35
```

Add `scripts/data/visual_theme_def.gd`:

```gdscript
class_name VisualThemeDef
extends Resource

@export var id: String = ""
@export var character_id: String = ""
@export var default_background_id: String = ""
@export var card_frame_style: String = ""
@export var card_accent_color: Color = Color.WHITE
@export var background_accent_color: Color = Color.WHITE
```

Default themes:

- `sword`
- `alchemy`

Default backgrounds:

- `default_combat`
- `sword_training_ground`
- `alchemy_mist_grove`

The first implementation should use exactly these three background definitions.

## Asset Strategy

Add first-batch project-owned textures under:

- `assets/presentation/card_thumbnails/`
- `assets/presentation/backgrounds/`

The first implementation should not require 40 unique illustrations. It should require 40 `CardVisualDef` resources, but those resources may share a smaller pool of thumbnail textures grouped by character, card type, or element tag.

Initial thumbnail pool:

- sword attack
- sword skill
- sword power
- alchemy attack/status
- alchemy skill
- alchemy power
- fallback card

Initial background pool:

- default combat
- sword training ground
- alchemy mist grove

Textures should be committed as regular Godot-imported assets. Tests should verify texture paths load through Godot rather than relying only on file existence.

## Content Catalog

`ContentCatalog` should load default visual resources from `resources/visuals/`.

Add dictionaries:

```gdscript
var card_visuals_by_card_id: Dictionary = {}
var combat_backgrounds_by_id: Dictionary = {}
var visual_themes_by_character_id: Dictionary = {}
```

Add getters:

```gdscript
func get_card_visual(card_id: String) -> CardVisualDef
func get_combat_background(background_id: String) -> CombatBackgroundDef
func get_visual_theme(character_id: String) -> VisualThemeDef
```

Validation should report:

- missing default visual theme for each default character;
- missing default card visual for each default catalog card;
- visual resources with empty ids;
- card visuals referencing missing cards;
- themes referencing missing characters;
- themes referencing missing default backgrounds;
- missing `default_combat` background;
- empty texture paths;
- texture paths that do not load as `Texture2D`;
- empty frame style where a theme or card visual is expected to style a card.

## Resolver

Add `scripts/presentation/combat_visual_resolver.gd`.

Recommended API:

```gdscript
func resolve_theme(character_id: String, catalog: ContentCatalog) -> Dictionary
func resolve_card_visual(card_id: String, catalog: ContentCatalog, theme: Dictionary = {}) -> Dictionary
func resolve_combat_background(character_id: String, catalog: ContentCatalog) -> Dictionary
```

Resolved card visual dictionaries should include:

- `card_id`
- `thumbnail_path`
- `frame_style`
- `accent_color`
- `element_tag`
- `thumbnail_alt_label`
- `is_known`

Resolved background dictionaries should include:

- `background_id`
- `texture_path`
- `environment_tag`
- `accent_color`
- `dim_opacity`
- `is_known`

Fallback rules:

- If a card visual is missing, use a safe fallback thumbnail dictionary and mark `is_known = false`.
- If a theme is missing, use neutral colors and `default_combat`.
- If a background is missing, use `default_combat`.
- The resolver should not crash if catalog data is incomplete.

## UI Design

`CombatScreen` should keep existing high-level node names and interaction behavior.

Add stable background nodes:

```text
CombatBackgroundLayer
  CombatBackgroundTexture
  CombatBackgroundDimmer
```

The background layer should be behind combat controls and below `PresentationLayer`. The dimmer should preserve readability of existing labels and buttons.

Update each hand card button to contain stable visual children:

```text
CardButton_0
  CardVisualRoot_0
    CardThumbnail_0
    CardFrame_0
    CardText_0
```

Requirements:

- `CardButton_<index>` remains the click and drag target.
- Visual children ignore mouse input.
- Existing card identity, type, and cost text remains visible.
- Thumbnail texture comes from `CardVisualDef`.
- Accent/frame color comes from card visual first, then theme fallback.
- The card button remains functional in click and drag tests.

No full production combat layout redesign is included. This phase adds visual layers and thumbnail slots to the existing programmatic combat UI.

## Data Flow

Card thumbnail flow:

```text
CardDef.id
  -> ContentCatalog.get_card_visual(card_id)
  -> CombatVisualResolver.resolve_card_visual(card_id, catalog, theme)
  -> CombatScreen CardThumbnail_<index>
```

Theme and background flow:

```text
RunState.character_id / CombatSession player id
  -> ContentCatalog.get_visual_theme(character_id)
  -> CombatVisualResolver.resolve_combat_background(character_id, catalog)
  -> CombatScreen CombatBackgroundTexture
```

Presentation effects continue to flow through:

```text
CombatPresentationQueue
  -> CombatPresentationLayer
```

The presentation layer should remain visually above the background.

## Testing Strategy

Unit tests:

- `CardVisualDef` stores card id, texture path, frame style, accent color, element tag, and alt label.
- `CombatBackgroundDef` stores texture path, environment tag, tier metadata, accent color, and dim opacity.
- `VisualThemeDef` stores character id, default background id, frame style, and colors.
- `ContentCatalog.load_default()` loads visual themes, backgrounds, and card visuals.
- Every default catalog card has a card visual.
- Every default character has a visual theme.
- Default visual texture paths load as `Texture2D`.
- Catalog validation reports invalid visual references and missing fallback background.
- `CombatVisualResolver` resolves sword and alchemy themes distinctly.
- Resolver falls back safely for missing card visual, theme, or background.

Combat smoke tests:

- A sword sandbox combat creates `CombatBackgroundTexture`.
- An alchemy sandbox combat creates a background using alchemy theme/background data.
- Hand card buttons create `CardThumbnail_<index>`, `CardFrame_<index>`, and `CardText_<index>`.
- Card click play still works with visual child controls.
- Card drag play still works with visual child controls.
- Existing presentation VFX nodes still appear above the background after a representative card play.

Boundary checks:

- `CombatSession`, `CombatEngine`, `EffectExecutor`, rewards, events, shops, saves, and map code do not import visual theme resources or the visual resolver.
- Existing enemy intent display and presentation cue tests continue to pass.

## Implementation Stages

1. Add visual schema resources.
   Verify schema tests fail first, then pass.

2. Add catalog loading and validation.
   Verify default visual catalog coverage passes.

3. Add first-batch texture assets and visual `.tres` resources.
   Verify Godot import check and texture load tests pass.

4. Add `CombatVisualResolver`.
   Verify resolver tests cover theme, background, card visual selection, and fallback.

5. Render combat background and card thumbnail nodes.
   Verify smoke tests check stable nodes and existing click/drag behavior.

6. Update README and run project review.
   Verify shared Godot checks, direct import check, spec compliance review, and code quality review.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify all default cards have catalog-backed visual metadata.
- Verify all default characters have visual themes.
- Verify combat renders a data-backed background.
- Verify hand cards render thumbnail nodes.
- Verify sword and alchemy have distinct theme data.
- Verify missing visual data falls back safely.
- Verify card click, drag, targeting, enemy intents, and presentation cues still work.
- Verify no combat rules, save data, rewards, events, shops, map flow, release tooling, or audio mixing changed.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Check resource classes are data-only and focused.
- Check resolver owns fallback behavior instead of scattering it through UI code.
- Check `CombatScreen` changes are scoped to rendering background and card visuals.
- Check visual children do not intercept card button input.
- Check tests use stable node names and real catalog resources.
- Check asset paths are validated through Godot loading.
- Check no unrelated refactors or formatting churn were included.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Documentation

Update README after acceptance:

- Add a Phase 2 progress bullet for the visual theme system.
- Update Next Plans so card art thumbnails and combat background presentation are no longer listed as open first-pass presentation scope.
- Keep formal audio mixing in Next Plans.
- Keep release expansion unchanged.

No changelog entry is required unless this is later shipped with a release branch.

## Acceptance Criteria

- All 40 default catalog cards have catalog-backed visual metadata.
- All default characters have visual themes.
- Combat renders a data-backed background layer.
- Hand cards render data-backed thumbnail nodes.
- Sword and alchemy present distinct visual identity through theme data.
- Missing visual data falls back safely and is reported by catalog validation.
- Existing combat click, drag, targeting, enemy intents, and presentation cues remain functional.
- No core combat execution class imports visual resources or the visual resolver.
- Shared Godot checks pass.
- Direct Godot import check exits 0.

## Future Work

- Replace foundation thumbnails with polished per-card art.
- Extend visual rendering to rewards, shop, event rewards, deck views, and map previews.
- Add enemy art and animated enemy presentation.
- Add encounter/environment mapping beyond character defaults.
- Add formal audio mixing, volume controls, and audio bus settings.
- Add localization-backed visual labels if the UI begins surfacing thumbnail labels directly.
