# Reduced Motion Presentation Profiles Design

Date: 2026-04-29

## Goal

Add a small reduced-motion profile to the combat presentation pipeline so players and testers can keep readable combat feedback while suppressing high-motion polish such as camera impulse, slow-motion wash, slash travel, and particle bursts.

This pass should make the existing presentation system more accessible without changing combat rules, save data, or final art/audio scope.

## Current Baseline

The project already has:

- `CombatPresentationConfig` with default-on booleans for presentation categories such as floating text, flash, target highlight, status pulse, cinematic slash, particles, camera impulse, slow motion, and audio cues.
- `CombatPresentationQueue` calling `config.allows(event)` before storing copied events.
- `CombatPresentationLayer` playback for floating text, color flash, status pulse, target highlight, card lift, slash textures, particle textures, local camera impulse, local slow-motion state, and audio cues.
- `DebugOverlay` checkboxes for individual presentation feature toggles in debug builds.
- Player card and enemy intent polish that reuse the same queue, config, asset catalog, and layer.

The current gap is that motion-sensitive users must manually disable several low-level toggles. There is no single profile that preserves low-motion feedback while blocking motion-heavy effects across both player-card and enemy-intent polish.

## Confirmed Direction

Use a profile field on `CombatPresentationConfig` and keep it presentation-only:

1. Add a default `full` motion profile that preserves current behavior.
2. Add a `reduced` motion profile that filters high-motion presentation events at the queue/config boundary.
3. Keep existing individual toggles as development controls.
4. Expose a simple debug-only reduced-motion checkbox.
5. Do not persist the profile or introduce a full settings screen in this pass.

This is the smallest useful accessibility step before larger presentation work such as intent icons, card art, richer combat backgrounds, persisted options, or formal audio mixing.

## Approaches Considered

### Recommended: Config-Level Profile Filtering

`CombatPresentationConfig` owns a `motion_profile` string and applies profile rules inside `allows(event)`. The queue already consults this method, so both player-card cues and enemy-intent cues inherit reduced-motion behavior without changes to resolvers or combat flow.

This is low risk because it uses the existing filtering point and keeps high-motion decisions out of `CombatScreen`.

### Alternative: Disable Individual Toggles From DebugOverlay

The debug UI could set `cinematic_enabled`, `particle_enabled`, `camera_impulse_enabled`, and `slow_motion_enabled` directly when reduced motion is checked. That is easy, but it makes the profile destructive: switching back to full would need to guess which manual toggles to restore.

### Alternative: Layer-Level No-Op Playback

`CombatPresentationLayer` could receive high-motion events and decide not to play them. That keeps queue history unchanged but wastes work, makes tests less direct, and leaves each layer playback path responsible for accessibility rules.

## Scope

Included:

- Add motion profile constants and a typed setter to `CombatPresentationConfig`.
- Keep `full` as the default profile.
- Add a `reduced` profile that blocks high-motion event types:
  - `cinematic_slash`
  - events tagged `cinematic`
  - `particle_burst`
  - `camera_impulse`
  - `slow_motion`
- Keep low-motion feedback allowed under `reduced` when its existing individual toggle is enabled:
  - `damage_number`
  - `block_number`
  - `status_number`
  - `combatant_flash`
  - `status_badge_pulse`
  - `target_highlighted`
  - `target_unhighlighted`
  - card hover/drag bookkeeping events
  - `audio_cue`
- Add a debug-only reduced-motion checkbox to `DebugOverlay`.
- Add unit tests for profile validation and queue filtering.
- Add smoke coverage proving combat can still play a card under reduced motion while high-motion nodes/state are absent.
- Update README progress and Next Plans after acceptance.

Excluded:

- No persisted settings, settings screen, save migration, or OS accessibility preference integration.
- No changes to combat rules, card effects, enemy intent execution, rewards, saves, events, or shops.
- No new assets, generated art, audio files, or audio bus mixing.
- No global `Engine.time_scale` changes.
- No replacement icons, static substitute VFX, or richer reduced-motion art pass.
- No presentation imports in `CombatEngine`, `EffectExecutor`, `CombatStatusRuntime`, or `CombatSession`.

## Architecture

The profile belongs at the same boundary as existing presentation toggles:

```text
CombatScreen / cue resolvers produce CombatPresentationEvent
  -> CombatPresentationQueue.enqueue(event)
  -> CombatPresentationConfig.allows(event)
  -> high-motion events dropped when motion_profile == "reduced"
  -> CombatPresentationLayer plays remaining low-motion events
```

`CombatPresentationConfig` remains a `RefCounted` object owned by `Game`. Runtime scenes read and mutate the shared instance through debug-only controls, just like the existing presentation toggles.

`CombatPresentationQueue` should not need new profile-specific logic. It continues to ask config whether an event is allowed.

`CombatPresentationLayer` should not need to know why an event was filtered. Layer behavior remains focused on playback of events it receives.

## Profile API

Extend `scripts/presentation/combat_presentation_config.gd`:

```gdscript
const MOTION_PROFILE_FULL := "full"
const MOTION_PROFILE_REDUCED := "reduced"

var motion_profile := MOTION_PROFILE_FULL

func set_motion_profile(profile: String) -> void:
	if profile == MOTION_PROFILE_REDUCED:
		motion_profile = MOTION_PROFILE_REDUCED
	else:
		motion_profile = MOTION_PROFILE_FULL

func is_reduced_motion() -> bool:
	return motion_profile == MOTION_PROFILE_REDUCED
```

Rules:

- Unknown profile strings fall back to `full`.
- `full` must preserve current default behavior.
- `reduced` is non-destructive. It must not mutate the individual category booleans.
- Individual toggles still apply in both profiles. For example, `audio_cue_enabled = false` drops audio cues in both `full` and `reduced`.

## Reduced-Motion Filtering

`allows(event)` should reject high-motion events when `is_reduced_motion()` is true.

High-motion events are:

- `cinematic_slash`
- any event with tag `cinematic`
- `particle_burst`
- `camera_impulse`
- `slow_motion`

Low-motion events are not blocked by the profile itself. They still respect their existing category toggles:

- Floating text can be disabled with `floating_text_enabled`.
- Flash can be disabled with `flash_enabled`.
- Status pulse can be disabled with `status_pulse_enabled`.
- Target highlight can be disabled with `target_highlight_enabled`.
- Drag events can be disabled with `drag_enabled`.
- Audio cues can be disabled with `audio_cue_enabled`.

This rule intentionally keeps audio cues under reduced motion. Audio can be controlled independently through the existing audio cue toggle until a formal audio mixing plan exists.

## Debug Overlay

Add a debug-only checkbox to `scripts/ui/debug_overlay.gd`:

- Node name: `DebugPresentationReducedMotion`
- Text: `Debug: Reduced Motion`
- Initial checked state: `app.game.presentation_config.is_reduced_motion()`
- On toggle:
  - checked -> `set_motion_profile("reduced")`
  - unchecked -> `set_motion_profile("full")`

The checkbox should sit near the existing presentation toggles. It is a developer/tester control, not a shipped settings menu.

## Testing

Add unit tests in `tests/unit/test_combat_presentation.gd`:

- Default config uses `full`.
- `set_motion_profile("reduced")` stores reduced.
- unknown profile strings reset to `full`.
- reduced motion filters `cinematic_slash`, cinematic-tagged events, `particle_burst`, `camera_impulse`, and `slow_motion`.
- reduced motion still allows floating text, flash, status pulse, target highlight, card hover, and audio cue events when their individual toggles are enabled.
- existing individual toggles still filter events in both profiles.

Add smoke coverage in `tests/smoke/test_scene_flow.gd`:

- Configure reduced motion before a combat screen.
- Play a card or end the turn through an existing test helper path that would normally produce high-motion polish.
- Process the presentation queue.
- Verify gameplay still succeeds.
- Verify no high-motion layer artifacts/state are produced, such as `CinematicSlash_0`, `ParticleBurst_0_0`, camera displacement, or `active_slow_motion_scale < 1.0`.
- Verify low-motion feedback such as damage/block/status numbers can still appear when expected.

Add debug overlay smoke coverage using the existing debug overlay helper path:

- The `DebugPresentationReducedMotion` checkbox exists in debug builds.
- Toggling it changes `app.game.presentation_config.motion_profile`.

## Documentation

Update README after acceptance:

- Add a Phase 2 progress bullet for reduced-motion presentation profiles.
- Update Next Plans so presentation expansion no longer lists reduced-motion profiles as open scope.

No changelog entry is required unless this work is bundled into a release branch later.

## Review Gates

Stage 1: Spec Compliance Review

- `CombatPresentationConfig` has `full` and `reduced` profiles.
- `full` preserves current behavior.
- `reduced` filters only the scoped high-motion event categories.
- Existing individual toggles remain functional and are not destructively changed by profile switching.
- DebugOverlay exposes a reduced-motion checkbox.
- CombatScreen, cue resolvers, and combat rule classes do not gain reduced-motion branching.
- README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- GDScript uses typed function parameters and return values for the profile API.
- Profile names are centralized constants, not scattered string literals.
- Filtering is deterministic and easy to read.
- Tests cover both allowed and rejected event categories.
- No duplicated high-motion lists appear across unrelated files unless needed for test clarity.
- No save, settings, platform, or gameplay code is touched.

## Acceptance Criteria

- Reduced motion is off by default and current presentation tests still pass.
- A config can switch to reduced motion at runtime.
- Reduced motion blocks slash, cinematic-tagged, particle, camera impulse, and slow-motion events before they reach the presentation layer.
- Reduced motion preserves essential low-motion feedback and independent audio-cue control.
- The debug overlay can toggle between full and reduced profiles.
- Existing Godot tests pass.
- Godot import/check script exits 0.
- No core combat rule class imports presentation scripts.

## Future Work

- Persist reduced-motion preference through a real settings screen.
- Add OS accessibility preference detection if Godot/platform support is appropriate.
- Add static substitute icons or lower-motion VFX for reduced mode.
- Add intent icons and richer card art that respect profile rules.
- Add formal audio mixing and independent volume controls.
