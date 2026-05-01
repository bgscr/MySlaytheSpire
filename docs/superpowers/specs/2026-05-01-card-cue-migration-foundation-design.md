# Card Cue Migration Foundation Design

Date: 2026-05-01

## Goal

Migrate the default card catalog to explicit presentation cues so every playable card declares its combat polish intent in data instead of relying on resolver fallback guesses.

This pass should make future card art, per-card VFX, and audio routing easier without adding new assets, changing combat rules, or expanding the runtime presentation system.

## Current Baseline

The project already has:

- `CardPresentationCueDef` resources with `event_type`, `target_mode`, `cue_id`, `amount`, `intensity`, `tags`, and `payload`.
- `CardDef.presentation_cues`, loaded from `.tres` card resources.
- `CombatPresentationCueResolver`, which uses explicit card cues when present and otherwise falls back to broad rules:
  - sword attacks or enemy-targeted damage emit `cinematic_slash`;
  - alchemy cards or poison status effects emit `particle_burst`;
  - observed damage deltas emit `camera_impulse`.
- `CombatPresentationAssetCatalog`, which resolves by `event_type:cue_id` first and then by event type fallback.
- Reduced-motion profile filtering at the queue/config boundary.
- Existing explicit cues on `sword.strike`, `alchemy.toxic_pill`, and `sword.heaven_cutting_arc`.

The current gap is that most cards still depend on fallback inference. That makes their intended presentation style implicit, makes DevTools card inspection uneven, and leaves future asset work without stable cue ids for each card.

## Confirmed Direction

Use a data migration, not a new runtime abstraction:

1. Keep the current resolver API.
2. Keep fallback behavior as a safety net for tests, prototypes, and future un-migrated cards.
3. Add explicit `presentation_cues` to every default catalog card.
4. Use each card id as its stable cue id, so future catalog entries can override individual cards with `event_type:card.id` mappings.
5. Reuse current event types and existing assets.

This is the smallest useful step before card art, intent icons, richer combat backgrounds, or formal audio mixing.

## Approaches Considered

### Recommended: Resource-First Cue Migration

Add explicit cues directly to the 40 default `.tres` card resources and add tests that enforce cue coverage for catalog cards.

This keeps presentation intent close to card content, improves DevTools immediately, and avoids changing combat rule code.

### Alternative: Expand Resolver Fallback Rules

The resolver could become smarter and infer more styles from effects. That would be faster to code, but it keeps card-specific presentation hidden in logic and makes future art routing less explicit.

### Alternative: Build A New Cue Policy Resource

A separate policy table could map card ids to cue specs. That might be useful later, but it adds another indirection before the card resources themselves have been fully exercised.

## Scope

Included:

- Add explicit `presentation_cues` to every card in the default catalog.
- Preserve existing cue behavior for the three already-migrated cards unless a test explicitly documents a richer cue set.
- Use existing presentation event types only:
  - `cinematic_slash`
  - `particle_burst`
  - `camera_impulse`
  - `slow_motion`
  - `audio_cue`
- Use existing target modes only:
  - `played_target`
  - `player`
  - `source`
  - `none`
- Use card ids as cue ids.
- Add tests that fail while any default catalog card has no explicit cue or any cue is missing a cue id.
- Add resolver tests proving explicit cues are used for migrated damage, block, status, utility, and rare finisher cards.
- Add smoke tests for representative sword and alchemy cards that previously relied on fallback.
- Update README progress and Next Plans after acceptance.

Excluded:

- No new card illustrations.
- No new texture or audio assets.
- No new background art.
- No intent icons or enemy UI widgets.
- No formal audio bus, mixer, or volume controls.
- No persisted presentation settings.
- No changes to combat rules, card effects, enemy intent execution, rewards, saves, events, shops, or map flow.
- No removal of fallback cue resolver behavior.

## Cue Policy

Every default card should have one or more explicit cues. The first pass favors readable, predictable coverage over bespoke animation.

Rules:

- `cue_id` is the card id, for example `sword.flash_cut`.
- `card_id` is copied by the resolver at runtime; card resources do not duplicate it in payload.
- `tags` should include `cinematic` only for `cinematic_slash`.
- Damage cards targeting an enemy get a `cinematic_slash` cue targeting `played_target`.
- Damage cards also get a `camera_impulse` cue targeting `none` unless the card is intentionally low-impact utility.
- Alchemy cards and status-themed cards get `particle_burst` cues.
- Player block, heal, draw, energy, and self-status cards target `player`.
- Enemy status cards target `played_target`.
- Rare finisher-style cards may keep `slow_motion` and `audio_cue` when already present.

The migration should avoid trying to encode exact gameplay results in cue data. Cue amounts can stay `0` unless a card already has a deliberate non-zero presentation amount.

## Card Coverage

The default catalog currently has 40 cards:

- 20 sword cards.
- 20 alchemy cards.

The migration should cover every card returned by `ContentCatalog.load_default()`.

### Sword Style Groups

- Direct sword damage: slash plus camera impulse.
- Sword damage plus draw or block: slash plus camera impulse.
- Sword broken-stance cards: slash plus status particle on the played target.
- Sword focus or guard cards: player-targeted particle burst.
- Sword energy/draw utility: player-targeted particle burst.
- `sword.heaven_cutting_arc`: preserve its slow-motion and audio cues, and keep or add its attack/status polish in the same explicit cue list.

### Alchemy Style Groups

- Direct alchemy damage: particle burst, and camera impulse when damage is meaningful.
- Poison cards: particle burst targeting the played target.
- Block/heal/guard cards: player-targeted particle burst.
- Draw/energy/refine utility cards: player-targeted particle burst.
- Rare multi-effect alchemy cards: use multiple explicit cues when a card combines utility and heal or damage/status effects.

## Asset Catalog Behavior

This pass does not need new asset files.

`CombatPresentationAssetCatalog` should continue to resolve migrated cards safely:

- If a specific `event_type:card_id` mapping exists, use it.
- If not, use the event-type fallback.
- `audio_cue` should remain unmapped unless a card already has an audio asset mapping.

Adding a small number of explicit mappings is allowed only when it keeps existing representative behavior stable, for example the already-mapped `sword.strike`, `alchemy.toxic_pill`, and `sword.heaven_cutting_arc` cue ids.

## Data Flow

```text
CardDef.presentation_cues in .tres resource
  -> CombatPresentationCueResolver.resolve_card_play(...)
  -> CombatPresentationEvent payload["cue_id"] = card.id
  -> CombatPresentationQueue config / reduced-motion filtering
  -> CombatPresentationAssetCatalog exact mapping or event fallback
  -> CombatPresentationLayer playback
```

The fallback path remains:

```text
CardDef with no presentation_cues
  -> CombatPresentationCueResolver fallback rules
```

The fallback path is no longer expected for default catalog cards after this migration.

## Testing Strategy

Unit tests:

- Default catalog card coverage:
  - every loaded card has at least one explicit presentation cue;
  - every cue has a non-empty event type;
  - every cue has a non-empty cue id;
  - every cue id equals the owning card id;
  - every cue event type is one of the existing supported event types;
  - every cue target mode is one of the existing supported target modes.
- Representative content tests:
  - a sword damage card that previously relied on fallback has slash and camera cues;
  - a sword block or focus card has a player-targeted particle cue;
  - an alchemy poison card has a played-target particle cue;
  - an alchemy utility/heal card has a player-targeted particle cue;
  - `sword.heaven_cutting_arc` keeps slow-motion and audio cues.
- Resolver tests:
  - explicit cues short-circuit fallback for migrated cards;
  - emitted events copy cue id, tags, target mode, intensity, and payload safely;
  - reduced motion filters migrated high-motion cues without blocking gameplay feedback.

Smoke tests:

- Play a migrated sword card that used to rely on fallback and verify the layer creates texture-backed slash feedback.
- Play a migrated alchemy or poison card that used to rely on fallback and verify the layer creates texture-backed particle feedback.
- Play a migrated utility card and verify combat still resolves and the presentation queue/layer receives only scoped polish.

Manual verification:

- Use DevTools Card Browser to inspect several sword and alchemy cards and confirm `presentation_cues` are visible.
- Start a combat and play one migrated sword attack, one migrated alchemy card, and one utility card.
- Toggle reduced motion and confirm high-motion migrated cues are filtered while combat still resolves.

## Documentation

Update README after acceptance:

- Add a Phase 2 progress bullet for card cue migration foundation.
- Update Next Plans so presentation expansion no longer lists full card cue migration as open scope.

No release changelog entry is required unless this work is bundled into a release branch later.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify every default catalog card has explicit presentation cues.
- Verify every migrated cue uses the card id as cue id.
- Verify event types and target modes stay within the existing presentation vocabulary.
- Verify representative damage, block, status, utility, and finisher cards match the cue policy.
- Verify fallback resolver behavior still exists for non-catalog or future cards.
- Verify no new assets, settings, combat rules, or UI systems were added.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Check `.tres` resource edits are minimal and consistent with existing style.
- Check tests are data-driven where useful and do not duplicate all 40 card resources by hand unnecessarily.
- Check cue resources do not alias mutable payload dictionaries in resolver tests.
- Check reduced-motion and existing debug toggles still gate migrated cues through the queue.
- Check no unrelated formatting or content changes were included.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Acceptance Criteria

- All 40 default catalog cards have explicit presentation cues.
- All migrated cues use existing event types and target modes.
- All migrated cue ids are non-empty and equal to the owning card id.
- Representative migrated cards produce presentation events through explicit cues, not fallback inference.
- Existing asset catalog fallbacks safely render migrated cue ids without bespoke mappings for every card.
- Existing representative exact asset mappings still work.
- Reduced-motion filtering still suppresses high-motion migrated cues.
- Existing combat click and drag card play flows remain functional.
- No core combat rule class imports presentation scripts.
- Full local Godot checks pass.
- Godot import check exits 0.

## Future Work

- Add card-specific texture or audio mappings for the migrated cue ids.
- Add card art thumbnails and hand/deck visual treatment.
- Add enemy intent icons and preview widgets.
- Add richer combat backgrounds.
- Add formal audio mixing and independent volume controls.
