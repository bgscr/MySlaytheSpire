# Audio Mixing Foundation Design

## Goal

Add a small developer-facing audio mixing foundation for the current presentation audio cue pipeline.

The first slice should make audio routing and volume control real enough to test and tune, without adding a player options menu, persisted settings, new gameplay behavior, music playback, or final audio production work.

## Current Baseline

Combat presentation can already emit `audio_cue` events. `CombatPresentationAssetCatalog` maps selected cue ids to WAV assets and per-cue `volume_db` values, and `CombatPresentationLayer` creates a `PresentationAudioPlayer` when a mapped cue plays.

The current gap is that the audio player is created directly with no formal bus routing. There is no project-level mixer contract for master, music, SFX, or UI audio, and debug controls can only enable or disable audio cues rather than tune levels.

## Confirmed Direction

Use a runtime mixer foundation:

- Developer/debug-facing only.
- Standard bus layout: `Master`, `Music`, `SFX`, and `UI`.
- Debug overlay sliders for all four buses.
- Combat presentation audio routes through `SFX`.
- Volumes are in-memory only for this pass.
- No player-facing options screen.
- No saved audio preferences.
- No music playback yet.
- No Steam, export, release, save schema, combat rules, content, or localization changes.

## Scope

Implement a small audio mix config/runtime helper that owns the bus contract and volume application.

The implementation should:

- Ensure the `Master`, `Music`, `SFX`, and `UI` buses exist at runtime.
- Store normalized volume values between `0.0` and `1.0`.
- Convert normalized volume values to Godot bus dB values.
- Apply bus volume changes through `AudioServer`.
- Clamp invalid volume inputs safely.
- Route `CombatPresentationLayer` audio cue playback to the `SFX` bus.
- Add four debug overlay sliders: Master, Music, SFX, and UI.
- Keep the existing audio cue enable toggle intact.
- Update README progress and Next Plans after acceptance.

## Non-Goals

- No player options menu.
- No persisted settings or save-file changes.
- No music track player.
- No new UI sound events.
- No final sound design pass.
- No replacement of existing WAV assets.
- No changes to `CombatSession`, `CombatEngine`, reward, shop, event, map, save, or release systems.
- No autoloads unless the implementation plan proves they are necessary.

## Approaches Considered

### Runtime Mixer Foundation

Add a small audio mix helper/config, initialize the bus contract at app startup, route combat audio to `SFX`, and expose debug sliders for all four buses.

This is the chosen approach because it creates the correct foundation while keeping scope tight.

### Presentation-Only SFX Patch

Only set the presentation audio player to the `SFX` bus and expose an SFX slider.

This is too narrow. It would leave the future mixer contract undefined and make the next audio pass redesign work that can be solved cleanly now.

### Full Settings Foundation

Add buses, sliders, a player-facing options menu, and persisted preferences.

This is too broad for the current goal. It would pull menu flow and preference storage into a pass that only needs developer-facing audio tuning.

## Architecture

Create a small audio mixer unit at `scripts/presentation/audio_mix_config.gd`.

The unit should have one responsibility: keep the runtime audio bus layout and volume values coherent.

Suggested shape:

- Constants for `Master`, `Music`, `SFX`, and `UI`.
- Default normalized volumes of `1.0` for all buses.
- A method that ensures all required buses exist.
- A method that sets one bus volume by normalized value.
- A method that applies all current volumes.
- A dB conversion helper.
- Read helpers for tests and debug UI.

`Game` should own one audio mix instance, mirroring the current `presentation_config` ownership pattern. `App` should initialize and apply it once during startup after creating `Game`.

`CombatPresentationLayer` should continue owning presentation playback, but `_presentation_audio_player()` should assign `bus = "SFX"` when creating the player. Core combat rules must remain audio-free.

## Bus Behavior

The bus names are stable public constants for project code:

- `Master`
- `Music`
- `SFX`
- `UI`

`Master` should use Godot's existing master bus. The mixer should ensure the child buses exist and should not duplicate them if they already exist.

The implementation should be conservative about bus ordering. A simple order of Master, Music, SFX, UI is enough as long as repeated initialization is idempotent and tests can verify that each named bus resolves through `AudioServer`.

## Volume Behavior

Volumes should be represented as normalized floats:

- `1.0`: full volume.
- `0.5`: reduced volume.
- `0.0`: muted.

Inputs below `0.0` clamp to `0.0`. Inputs above `1.0` clamp to `1.0`.

The dB conversion must be deterministic and testable. `1.0` converts to `0.0 dB`. `0.0` converts to `-80.0 dB` rather than negative infinity so tests and runtime behavior are stable. Values between `0.0` and `1.0` use Godot's standard logarithmic `linear_to_db(value)` conversion.

## Debug Overlay

Add four debug sliders below the existing presentation audio cue toggle:

- Master volume
- Music volume
- SFX volume
- UI volume

Each slider should:

- Be visible only through the existing debug overlay path.
- Use stable node names for smoke tests.
- Show a clear debug label.
- Update the in-memory audio mix config immediately.
- Leave the audio cue enable toggle behavior unchanged.

No player-facing settings screen or persistence should be added.

## Data Flow

Startup:

```text
App._ready()
  -> Game creates audio mix config
  -> audio mix ensures buses
  -> audio mix applies default volumes
```

Debug tuning:

```text
DebugOverlay slider changed
  -> Game.audio_mix_config.set_bus_volume(...)
  -> AudioServer receives updated bus dB
```

Combat audio cue:

```text
CombatPresentationLayer receives audio_cue event
  -> CombatPresentationAssetCatalog resolves WAV and cue volume_db
  -> PresentationAudioPlayer is created on SFX bus
  -> stream plays with existing per-cue volume_db
  -> final output is affected by SFX and Master bus volumes
```

## Error Handling

If a requested bus is missing, the mixer should create it.

If a bus cannot be found after initialization, setting that bus volume should be a safe no-op rather than crashing combat or debug UI.

Volume setters should clamp invalid values. Missing or unmapped audio cue assets should keep the current no-op behavior.

Repeated startup initialization should not create duplicate buses.

## Testing Strategy

Add focused unit tests for the audio mix unit:

- Required bus names are ensured.
- Repeated bus initialization is idempotent.
- Volume values clamp to the `0.0` to `1.0` range.
- `1.0` maps to `0.0 dB`.
- `0.0` maps to the selected quiet floor.
- Midrange values use the expected logarithmic conversion.

Update presentation tests:

- `PresentationAudioPlayer` is created on the `SFX` bus.
- Existing audio cue playback still records cue id and count.
- Unmapped audio cues still do not create an audio player.

Update debug overlay smoke tests:

- All four volume sliders exist.
- Moving each slider updates the corresponding in-memory config value.
- Existing audio cue enable toggle still works.

Final verification remains the shared Godot check script.

## Review Requirements

Stage 1: Spec Compliance Review

- Verify `Master`, `Music`, `SFX`, and `UI` buses are ensured.
- Verify debug overlay exposes all four requested sliders.
- Verify combat presentation audio routes to `SFX`.
- Verify volumes are in-memory only.
- Verify no player options menu, persistence, save schema, music player, release tooling, Steam work, or gameplay changes were added.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Verify audio mix logic is small, typed, and focused.
- Verify audio code stays out of combat rules.
- Verify bus initialization is idempotent.
- Verify dB conversion is deterministic and tested.
- Verify debug overlay changes follow existing patterns and avoid unrelated refactoring.
- Verify tests cover the behavior without relying on brittle global state where avoidable.

## Documentation

After implementation acceptance:

- Add a README Phase 2 Progress bullet for audio mixing foundation.
- Update Next Plans so formal audio mixing is no longer listed as open presentation scope.
- No changelog entry is required unless this is later shipped with a release branch.

## Acceptance Criteria

- Runtime ensures `Master`, `Music`, `SFX`, and `UI` buses exist.
- Audio mix config stores and applies normalized in-memory volumes for all four buses.
- Debug overlay provides working sliders for all four buses.
- Combat presentation audio cue playback routes to `SFX`.
- Existing audio cue enable toggle still works.
- Missing or unmapped audio cue assets remain safe no-ops.
- No player-facing options menu or persisted audio settings are added.
- No combat rules, save schema, content, release, Steam, or gameplay behavior changes are added.
- Shared Godot checks pass.

## Future Work

- Add player-facing audio settings.
- Persist audio preferences.
- Add music playback through the `Music` bus.
- Route future UI sound events through the `UI` bus.
- Expand sound design and cue asset coverage.
- Add release-time audio QA notes if needed.
