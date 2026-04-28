# High Presentation Polish Hooks Design

Date: 2026-04-28

## Goal

Add the first high-presentation polish hook vertical slice for combat without introducing final art or audio assets. The slice should make the existing presentation event pipeline capable of handling cinematic slash, particle burst, camera impulse, slow motion, and audio cue events through visible or inspectable programmatic placeholders.

This pass should prove the future-facing architecture before the project invests in richer assets. Card presentation data should be explicit when configured, but the system should still provide conservative automatic fallback cues for existing cards.

## Current Baseline

The project already has:

- A complete playable run loop through map, combat, reward, event, shop, save, and summary screens.
- `CombatPresentationEvent`, `CombatPresentationConfig`, `CombatPresentationQueue`, `CombatPresentationDelta`, and `CombatPresentationLayer`.
- `CombatScreen` routing hover, drag, target highlight, floating number, flash, status pulse, and `card_played` events through the presentation queue.
- `DebugOverlay` toggles for general presentation, drag, floating text, flash, target highlight, status pulse, and future cinematic events.
- Core combat rules in `CombatSession`, `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` that do not depend on presentation scripts.

The main gap is that the future event hooks reserved by the high-presentation foundation are not real yet. `cinematic_slash`, `particle_burst`, `camera_impulse`, `slow_motion`, and `audio_cue` are not produced by card play and do not have useful first-pass playback behavior.

## Confirmed Direction

Use a hybrid cue model:

1. `CardDef` gains optional presentation cue resources.
2. Explicit card cues take priority when present.
3. Cards without explicit cues use automatic fallback inference.

This keeps the first implementation small while leaving a clean path for richer card-specific presentation later.

## Scope

Included:

- Add a lightweight `CardPresentationCueDef` resource class.
- Add optional `CardDef.presentation_cues: Array[CardPresentationCueDef]`.
- Add a `CombatPresentationCueResolver` that converts a successful card play plus observed combat deltas into polish events.
- Extend `CombatPresentationConfig` filtering and `DebugOverlay` toggles for:
  - `particle_enabled`
  - `camera_impulse_enabled`
  - `slow_motion_enabled`
  - `audio_cue_enabled`
- Make existing `cinematic_enabled` filter real for `cinematic_slash`.
- Extend `CombatPresentationLayer` with programmatic placeholder playback for:
  - `cinematic_slash`
  - `particle_burst`
  - `camera_impulse`
  - `slow_motion`
  - `audio_cue`
- Wire successful card play in `CombatScreen` to generate polish events through the resolver.
- Add explicit cue data to a small representative set of cards to prove the configured path works.
- Add unit and smoke tests for cue data, resolver behavior, config filtering, layer playback, and combat integration.
- Update README and the implementation plan after acceptance.

Excluded:

- No final card art, enemy art, VFX textures, or generated asset pack.
- No real audio files or audio bus work.
- No global `Engine.time_scale` changes.
- No animation-driven gameplay sequencing.
- No enemy-card-style polish resolver for enemy intents.
- No full per-card presentation migration.
- No formal player settings or persisted presentation preferences.
- No presentation imports in `CombatEngine`, `EffectExecutor`, or `CombatStatusRuntime`.

## Architecture

The polish hook pipeline extends the existing presentation architecture:

```text
Successful card play in CombatScreen
  -> CombatPresentationDelta events_between(before, after)
  -> CombatPresentationCueResolver.resolve_card_play(...)
  -> CombatPresentationEvent polish events
  -> CombatPresentationQueue config filtering
  -> CombatPresentationLayer programmatic placeholder playback
```

`CombatScreen` remains the UI bridge. It knows the played card id, the confirmed target, and the observed state delta. It does not decide detailed presentation rules directly.

`CombatPresentationCueResolver` owns cue selection. It reads card resource data when present and otherwise uses conservative fallback inference.

`CombatPresentationLayer` owns visual and inspectable playback. It must not mutate combat state or block input.

Core combat systems remain presentation-free. The resolver and layer live beside the existing presentation package, not inside combat rule classes.

## Card Presentation Cue Resource

Create `scripts/data/card_presentation_cue_def.gd`:

```gdscript
class_name CardPresentationCueDef
extends Resource

@export var event_type: String = ""
@export_enum("played_target", "source", "player", "none") var target_mode: String = "played_target"
@export var amount: int = 0
@export var intensity: float = 1.0
@export var cue_id: String = ""
@export var tags: Array[String] = []
@export var payload: Dictionary = {}
```

Extend `CardDef`:

```gdscript
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")

@export var presentation_cues: Array[CardPresentationCueDef] = []
```

Cue fields mean:

- `event_type`: presentation event to enqueue, such as `cinematic_slash`.
- `target_mode`: how to choose `event.target_id`.
- `amount`: optional numeric payload for cue-specific playback.
- `intensity`: non-negative strength hint for layer playback.
- `cue_id`: stable cue name for future asset/audio routing.
- `tags`: copied into `CombatPresentationEvent.tags`.
- `payload`: copied into `CombatPresentationEvent.payload`.

The cue resource is intentionally generic. It should not encode combat rules.

## Resolver Rules

Create `scripts/presentation/combat_presentation_cue_resolver.gd`.

The resolver should expose a typed method like:

```gdscript
func resolve_card_play(
	card,
	source_id: String,
	played_target_id: String,
	delta_events: Array
) -> Array[CombatPresentationEvent]
```

Rules:

- If `card == null`, return an empty array.
- If `card.presentation_cues` is not empty, convert those cues directly into events.
- If `card.presentation_cues` is empty, use fallback inference.
- Every generated event sets `card_id = card.id`.
- Configured cue target modes map as:
  - `played_target`: use `played_target_id`
  - `source`: use `source_id`
  - `player`: use `"player"`
  - `none`: leave `target_id` empty
- Cue `cue_id` is copied into `event.payload["cue_id"]` when non-empty.
- Cue `amount`, `intensity`, `tags`, and `payload` are copied without aliasing.

Fallback inference:

- If the card belongs to the `sword` character and is an attack, generate `cinematic_slash`.
- If any card effect has `effect_type == "damage"` and targets an enemy, generate `cinematic_slash`.
- If the card belongs to the `alchemy` character, generate `particle_burst`.
- If any card effect applies `poison`, generate `particle_burst`.
- If any observed delta event is `damage_number`, generate `camera_impulse`.
- Do not infer `slow_motion` in the first pass.
- Do not infer `audio_cue` in the first pass.
- Avoid duplicate event types from fallback inference for one card play.

Fallback event defaults:

- `cinematic_slash`: target the played target, tag as `cinematic`, intensity `1.0`.
- `particle_burst`: target the played target if present, otherwise target the player, intensity `1.0`.
- `camera_impulse`: target `none`, intensity based on the largest damage number with a small clamp.

Automatic fallback applies only after successful player card play. Enemy turns continue to use existing state-delta feedback.

## Presentation Config

Extend `CombatPresentationConfig`:

```gdscript
var particle_enabled := true
var camera_impulse_enabled := true
var slow_motion_enabled := true
var audio_cue_enabled := true
```

Filtering rules:

- If `cinematic_enabled == false`, drop `cinematic_slash` and any event tagged `cinematic`.
- If `particle_enabled == false`, drop `particle_burst`.
- If `camera_impulse_enabled == false`, drop `camera_impulse`.
- If `slow_motion_enabled == false`, drop `slow_motion`.
- If `audio_cue_enabled == false`, drop `audio_cue`.

`DebugOverlay` should expose these as development toggles. They do not persist to saves.

## Presentation Layer Playback

Extend `CombatPresentationLayer.play_event()`:

- `cinematic_slash`: create a short-lived `ColorRect` or thin `Control` line near the target. It should be named predictably, such as `CinematicSlash_0`, and tween opacity out before freeing.
- `particle_burst`: create several small `ColorRect` placeholder particles near the target. They should be named predictably, such as `ParticleBurst_0_0`, and tween outward/fade before freeing.
- `camera_impulse`: briefly offset the layer or configured impulse target and restore its original position through a tween.
- `slow_motion`: record local presentation slow-motion state for a short duration. It must not change `Engine.time_scale` or combat gameplay state.
- `audio_cue`: record the last cue id and increment a cue counter. It must not load or play real audio.

The layer should expose enough read-only state for tests:

```gdscript
var active_slow_motion_scale: float = 1.0
var last_audio_cue_id: String = ""
var audio_cue_count: int = 0
```

If a visible event targets an unbound target, it should be ignored safely.

## CombatScreen Integration

`CombatScreen._run_with_feedback()` should:

1. Capture the pre-action state.
2. Execute the gameplay action.
3. Build delta events from the observed state change.
4. Enqueue the existing `card_played` event when a card was played.
5. Ask `CombatPresentationCueResolver` for polish events when a card was played.
6. Enqueue delta and polish events through the existing queue.

The function should avoid duplicating combat rules. It should pass only card data, source id, played target id, and observed delta events into the resolver.

For click play and drag play, the confirmed enemy or player target should be passed into `_run_with_feedback()` so resolver events can target the right control.

## Representative Explicit Cues

Only a small set of card resources needs explicit cue data in this pass:

- `resources/cards/sword/strike_sword.tres`: explicit `cinematic_slash`.
- One alchemy poison/status card: explicit `particle_burst`.
- One rare or high-impact card: explicit `slow_motion` and `audio_cue`.

All other cards should continue to work through fallback inference or no polish cue.

## Testing Strategy

Unit tests:

- `CardDef.presentation_cues` stores cue resources and duplicates cleanly through loaded resources.
- `CombatPresentationCueResolver` converts explicit cues into presentation events.
- The resolver sets target ids according to `target_mode`.
- The resolver fallback emits sword slash, alchemy particle, poison particle, and damage camera impulse.
- The resolver does not infer slow motion or audio cues.
- `CombatPresentationConfig` filters each new event category.
- `CombatPresentationLayer` creates slash and particle placeholder nodes for bound targets.
- `CombatPresentationLayer` restores camera impulse target position after tween completion.
- `CombatPresentationLayer` records slow-motion and audio-cue state without changing global time scale.

Smoke tests:

- A real combat card play can enqueue and play at least one polish feedback event.
- Disabling `cinematic_enabled` prevents slash feedback while leaving card play functional.
- Existing click and drag play flows continue to work.

Manual verification:

- Start a run and enter combat.
- Play a sword attack and see slash placeholder feedback plus existing damage feedback.
- Play an alchemy/status card and see particle placeholder feedback when applicable.
- Disable cinematic or particle toggles in `DebugOverlay` and verify those effects stop.
- Verify gameplay input does not wait for polish playback to finish.

## Review Requirements

After the implementation feature is complete, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify `CardPresentationCueDef`, `CardDef.presentation_cues`, and `CombatPresentationCueResolver` exist.
- Verify explicit cue configuration takes priority over fallback inference.
- Verify fallback inference generates the specified events and does not infer slow motion or audio cues.
- Verify `CombatPresentationConfig` and `DebugOverlay` expose all new toggles.
- Verify `CombatPresentationLayer` handles slash, particle, camera impulse, slow motion, and audio cue events.
- Verify card play integration works for click and drag paths.
- Verify `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` do not import presentation scripts.
- Verify no real assets, global time scaling, persisted settings, or enemy polish resolver were added.

Stage 2: Code Quality Review

- Check GDScript typing for cue definitions, resolver methods, layer state, and config fields.
- Check cue event construction copies arrays and dictionaries safely.
- Check fallback inference is deterministic and small.
- Check `CombatScreen` integration does not duplicate gameplay rules.
- Check layer temporary nodes are named predictably and clean themselves up.
- Check tests do not rely on frame timing beyond explicit tween stepping.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Acceptance Criteria

- Cards can define optional presentation cues through resources.
- Cards without presentation cues can still receive conservative automatic polish events.
- Successful player card play can generate `cinematic_slash`, `particle_burst`, and `camera_impulse` where appropriate.
- Explicit cue resources can trigger `slow_motion` and `audio_cue`.
- `CombatPresentationConfig` and `DebugOverlay` can disable each new event category.
- `CombatPresentationLayer` plays visible slash and particle placeholders, restores camera impulse offset, and records slow-motion/audio-cue state.
- No core combat rule class depends on presentation scripts.
- Existing click and drag card play flows remain functional.
- Existing local tests pass.
- Godot import check exits 0.

## Future Work

- Replace placeholder slash and particles with generated or authored asset profiles.
- Add real audio routing for `audio_cue`.
- Add reduced-motion-aware presentation profiles.
- Add enemy intent polish cues once enemy intent resources exist.
- Add richer card-specific cue migration across the full card catalog.
- Add camera shake or hit-stop that is still isolated from gameplay determinism.
