# High Presentation Asset Pass Design

Date: 2026-04-28

## Goal

Replace the current high-presentation polish placeholders with real project assets and asset routing for the five existing combat polish hooks:

- `cinematic_slash`
- `particle_burst`
- `camera_impulse`
- `slow_motion`
- `audio_cue`

This pass should make the hook pipeline feel like a real asset pipeline rather than a set of hard-coded debug effects. The first asset direction is an eastern fantasy combat feel: clean cyan-white and gold sword qi, green and violet alchemy mist, short wind cuts, spirit impacts, and light metallic accents.

## Current Baseline

The project already has a completed high-presentation hook layer:

- `CardPresentationCueDef` stores optional per-card presentation cues.
- `CardDef.presentation_cues` can hold explicit cue resources.
- `CombatPresentationCueResolver` emits explicit or fallback polish events after successful card play.
- `CombatPresentationConfig` and `DebugOverlay` can toggle each polish category.
- `CombatPresentationLayer` currently plays programmatic placeholders for slash, particles, camera impulse, slow motion, and audio cue state.
- `sword.strike`, `alchemy.toxic_pill`, and `sword.heaven_cutting_arc` prove the explicit cue path.

The gap is that the layer still owns too much hard-coded placeholder behavior. Slash and particle visuals are `ColorRect` nodes, audio cues only update inspectable state, and camera or slow-motion tuning is not routed through data.

## Confirmed Direction

Use a project asset catalog with explicit cue-id routing:

1. Add project-owned texture and audio files under `assets/presentation/`.
2. Add `CombatPresentationAssetCatalog` in the presentation package.
3. Resolve assets by `cue_id` first, then by `event_type` fallback.
4. Keep card resources focused on stable cue ids, not texture paths or playback code.
5. Keep core combat systems presentation-free.

## Scope

Included:

- Add reusable presentation texture assets for sword slash and alchemy mist playback.
- Add reusable presentation audio assets for slash, mist, and heavy spirit impact cues.
- Add `scripts/presentation/combat_presentation_asset_catalog.gd`.
- Route `CombatPresentationLayer` through the asset catalog for slash, particles, camera impulse, slow motion, and audio cue playback parameters.
- Replace primary slash and particle placeholder nodes with asset-backed `TextureRect` nodes.
- Add real `AudioStreamPlayer` playback for `audio_cue` events while keeping `last_audio_cue_id` and `audio_cue_count`.
- Preserve all existing debug toggles and queue filtering behavior.
- Add unit and smoke tests for asset resolution, loadability, layer playback, audio routing, and combat integration.
- Update README and implementation plan after acceptance.

Excluded:

- No full card illustration pass.
- No enemy art or intent animation pass.
- No migration of all card cues.
- No animation-driven gameplay sequencing.
- No global `Engine.time_scale` changes.
- No persisted presentation settings.
- No external audio middleware or formal mixer pass.
- No presentation imports in `CombatEngine`, `EffectExecutor`, or `CombatStatusRuntime`.

## Asset Structure

Create a small first-party asset set:

```text
assets/
  presentation/
    textures/
      slash_cyan.png
      slash_gold.png
      mist_green.png
      mist_violet.png
      slow_motion_wash.png
    audio/
      slash_light.wav
      alchemy_mist.wav
      spirit_impact_heavy.wav
```

The first assets should be simple but real Godot-loadable files. They can be procedurally generated during implementation as long as the final committed files are regular project assets.

Texture intent:

- `slash_cyan.png`: short cyan-white sword qi arc for common sword attacks.
- `slash_gold.png`: wider gold-cyan arc for heavier cinematic slashes.
- `mist_green.png`: soft green alchemy particle dot or plume.
- `mist_violet.png`: violet-green poison mist particle.
- `slow_motion_wash.png`: subtle translucent wash for local slow-motion feedback.

Audio intent:

- `slash_light.wav`: short wind-cut and light metallic edge.
- `alchemy_mist.wav`: short breathy mist release.
- `spirit_impact_heavy.wav`: short low spirit impact for heavy card cues.

## Asset Catalog

Create `scripts/presentation/combat_presentation_asset_catalog.gd`.

The catalog should expose a typed method similar to:

```gdscript
func resolve(event: CombatPresentationEvent) -> Dictionary
```

Resolution rules:

- If `event == null`, return an empty dictionary.
- Read `cue_id` from `event.payload["cue_id"]` when present.
- Resolve by exact `cue_id` first.
- If no exact cue mapping exists, resolve by `event.event_type`.
- Return duplicated dictionaries so callers cannot mutate shared catalog data.
- Unknown events return a safe empty dictionary.
- Registered `texture_path` and `audio_path` values must load successfully.

Initial explicit cue mappings:

| Cue id | Event | Asset behavior |
| --- | --- | --- |
| `sword.strike` | `cinematic_slash` | cyan slash texture, short duration, medium travel |
| `alchemy.toxic_pill` | `particle_burst` | violet-green mist texture, compact burst |
| `sword.heaven_cutting_arc` | `audio_cue` | heavy spirit impact audio |
| `sword.heaven_cutting_arc` | `slow_motion` | stronger local slow-motion settings and subtle wash |

Because `sword.heaven_cutting_arc` uses the same cue id for both slow motion and audio, the catalog key should include both event type and cue id internally. Event-type fallback covers cards without explicit asset mapping.

Initial event fallback mappings:

| Event type | Fallback behavior |
| --- | --- |
| `cinematic_slash` | cyan slash texture |
| `particle_burst` | green mist texture |
| `camera_impulse` | default strength, direction, duration |
| `slow_motion` | default local scale, duration, optional wash |
| `audio_cue` | no fallback audio unless a cue id maps to one |

## Presentation Layer Playback

`CombatPresentationLayer` should own playback, not asset selection.

### Cinematic Slash

- Query the asset catalog for texture, color, size, rotation, travel, scale, and duration.
- Create a `TextureRect` named predictably, such as `CinematicSlash_0`.
- Position near the bound target.
- Tween position, scale, and alpha.
- Free the node after playback.
- If no texture is available or the target is missing, ignore safely.

### Particle Burst

- Query texture, particle count, radius, duration, color, and size.
- Create `TextureRect` particles named predictably, such as `ParticleBurst_0_0`.
- Use deterministic radial placement for tests.
- Tween particles outward and fade them.
- If no texture is available or the target is missing, ignore safely.

### Camera Impulse

- Query strength, duration, and optional direction.
- Offset only the presentation layer or its configured impulse target.
- Restore the original position through a tween.
- Do not introduce a global camera dependency in this pass.

### Slow Motion

- Query local presentation scale, duration, and optional wash texture.
- Set `active_slow_motion_scale` locally.
- Optionally show a subtle `TextureRect` or transparent overlay named predictably, such as `SlowMotionWash_0`.
- Restore `active_slow_motion_scale` to `1.0` after the duration.
- Do not mutate `Engine.time_scale`.

### Audio Cue

- Query audio stream path by event type plus cue id.
- Use an `AudioStreamPlayer` child to play the loaded stream.
- Keep `last_audio_cue_id` and `audio_cue_count` for tests and debug visibility.
- If no mapped stream exists, record the cue state but skip playback safely.

## Data Flow

```text
CardPresentationCueDef.cue_id
  -> CombatPresentationEvent.payload["cue_id"]
  -> CombatPresentationAssetCatalog.resolve(event)
  -> CombatPresentationLayer creates texture/audio-backed playback
```

The queue and config filtering stay unchanged:

```text
CombatPresentationCueResolver
  -> CombatPresentationQueue config filtering
  -> CombatPresentationLayer asset-backed playback
```

## Tests

Add unit coverage for the catalog:

- Exact cue-id plus event-type mapping wins over event fallback.
- Event fallback works when no cue id is present.
- Unknown events return an empty dictionary.
- Returned dictionaries do not alias catalog data.
- Every registered texture and audio path loads successfully.

Add unit coverage for the layer:

- `cinematic_slash` creates a `TextureRect`, not a `ColorRect`.
- `particle_burst` creates multiple `TextureRect` particles.
- `audio_cue` creates or reuses an `AudioStreamPlayer`, records cue id, and increments count.
- `camera_impulse` restores layer position using catalog timing.
- `slow_motion` restores local scale and does not change `Engine.time_scale`.

Add smoke coverage:

- `sword.strike` plays an asset-backed slash through real combat card play.
- `alchemy.toxic_pill` plays asset-backed mist particles through real combat card play.
- `sword.heaven_cutting_arc` routes slow-motion and audio cue assets through real combat card play.
- Existing debug toggles still suppress the corresponding events before playback.

## Acceptance Criteria

- Project-owned texture and audio assets exist under `assets/presentation/`.
- `CombatPresentationAssetCatalog` resolves assets by cue id first and event type second.
- `CombatPresentationLayer` uses texture-backed slash and particle playback.
- `audio_cue` can play a real Godot audio stream when a cue mapping exists.
- Camera impulse and slow-motion tuning come from catalog data.
- Existing inspectable presentation state remains available for tests.
- Existing presentation config toggles still work.
- Existing combat click and drag play flows remain functional.
- No core combat rule class imports presentation scripts.
- Full local tests pass.
- Godot import check exits 0.

## Review Plan

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify asset files exist at the agreed paths.
- Verify catalog cue-id and event-type fallback behavior.
- Verify slash and particle playback use textures.
- Verify audio cue playback uses real audio streams.
- Verify camera and slow-motion parameters come from catalog data.
- Verify representative card cues still trigger through combat.
- Verify config toggles still gate events.
- Verify no excluded systems were added.

Stage 2: Code Quality Review

- Check typed GDScript structure and narrow presentation boundaries.
- Check catalog data is copied safely.
- Check resource loading is centralized and safe.
- Check layer playback helpers remain small and testable.
- Check temporary nodes are predictably named and self-cleaning.
- Check tests avoid arbitrary timing and use deterministic tween stepping.

Critical and Important findings must be fixed before acceptance.

## Next Step

After this spec is reviewed and approved, create an implementation plan with `superpowers:writing-plans` before editing code.
