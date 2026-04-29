# Enemy Intent Presentation Cues Design

Date: 2026-04-29

## Goal

Add a focused presentation expansion for enemy intents so enemy attacks, blocks, and status intents produce readable polish cues through the existing combat presentation pipeline.

The feature should make enemy turns feel less like silent state mutation while keeping combat rules deterministic and presentation-free.

## Current Baseline

The project already has:

- A playable combat loop with deterministic enemy intent strings such as `attack_6`, `block_4`, `apply_status_poison_2_player`, and `self_status_sword_focus_1`.
- `CombatScreen._run_with_feedback()` capturing before/after combat state, enqueueing card polish cues for successful player card play, and enqueueing state delta presentation events.
- `CombatPresentationDelta` emitting `damage_number`, `block_number`, `status_number`, `combatant_flash`, and `status_badge_pulse`.
- `CombatPresentationCueResolver` for player card polish only.
- `CombatPresentationAssetCatalog` and `CombatPresentationLayer` for asset-backed `cinematic_slash`, `particle_burst`, `camera_impulse`, `slow_motion`, and `audio_cue`.

The current gap is that enemy intents have no intent-shaped polish. Enemy turns can cause numbers and flashes after state changes, but the presentation layer cannot distinguish an enemy attack from a self-block or poison/status intent before or alongside the delta feedback.

## Baseline Readiness Issue

While creating the next worktree, a fresh Godot cache exposed a release-check ordering problem:

- `tools/ci/run_godot_checks.ps1` runs the headless test runner before any explicit editor import.
- Presentation asset tests need imported `.ctex` and `.sample` files under `.godot/imported`.
- Running `Godot --headless --path . --import` once creates the required imported assets.

This feature should include a small prerequisite fix: the shared Godot check script must run an editor import before the test runner. The fix belongs in release tooling, not gameplay or presentation code.

## Confirmed Direction

Use an enemy-intent presentation resolver beside the existing card cue resolver:

1. Keep `CombatSession` and combat rules unchanged.
2. Capture the visible enemy intents before ending the player turn.
3. Let `CombatScreen` pass those intent snapshots plus observed delta events to a new resolver.
4. Reuse existing presentation event types and asset catalog routing.
5. Add only small new cue-id mappings for enemy attack, block, and status intent styles.

This is the smallest useful step before larger presentation work such as full card art, richer combat backgrounds, enemy intent resources, or formal audio mixing.

## Approaches Considered

### Recommended: Resolver From Intent Snapshots

`CombatScreen` records enemy target ids and intent strings before `session.end_player_turn()`. After the action succeeds, it asks a new `CombatPresentationIntentCueResolver` to convert the recorded intents and delta events into polish events.

This is low risk because it observes the same strings the UI already displays and keeps all presentation interpretation outside combat rules.

### Alternative: Emit Presentation Events From `CombatSession`

`CombatSession` could emit events while executing each enemy intent. That would be more direct but would couple combat rules to presentation event classes and violate the current architecture boundary.

### Alternative: Add Enemy Intent Resource Definitions First

Enemy intent resources would eventually be cleaner than encoded strings, but this is larger than needed for the current presentation expansion. It would also mix content schema migration with polish behavior.

## Scope

Included:

- Update the shared Godot check script to import assets before running the test runner.
- Add `scripts/presentation/combat_presentation_intent_cue_resolver.gd`.
- Add enemy cue-id mappings to `CombatPresentationAssetCatalog`.
- Wire `CombatScreen._on_end_turn_pressed()` / `_run_with_feedback()` so only successful enemy turns generate enemy intent polish.
- Generate polish for supported enemy intent strings:
  - `attack_N`
  - `block_N`
  - `apply_status_<status_id>_<amount>_player`
  - `self_status_<status_id>_<amount>`
- Reuse existing presentation event types:
  - Enemy attack: `cinematic_slash` targeting `player`, plus `camera_impulse` when the observed delta includes player damage.
  - Enemy block: `particle_burst` targeting the acting enemy.
  - Enemy status to player: `particle_burst` targeting `player`.
  - Enemy self status: `particle_burst` targeting the acting enemy.
- Add tests for the resolver, asset mappings, CombatScreen integration, config filtering, and the release-check import ordering.
- Update README progress and implementation plan after acceptance.

Excluded:

- No changes to `CombatSession` enemy intent execution rules.
- No new enemy intent resource schema.
- No enemy art, animation timeline, or intent icons.
- No global `Engine.time_scale` changes.
- No persisted presentation settings.
- No new audio files unless a later plan explicitly scopes them.
- No presentation imports in `CombatEngine`, `EffectExecutor`, `CombatStatusRuntime`, or `CombatSession`.

## Architecture

The enemy intent pipeline mirrors the player card polish pipeline but has its own resolver:

```text
CombatScreen captures enemy intents before end turn
  -> session.end_player_turn()
  -> CombatPresentationDelta events_between(before, after)
  -> CombatPresentationIntentCueResolver.resolve_enemy_turn(...)
  -> CombatPresentationEvent polish events
  -> CombatPresentationQueue config filtering
  -> CombatPresentationLayer asset-backed playback
```

`CombatScreen` remains the UI bridge because it already owns target ids (`player`, `enemy:0`, `enemy:1`) and presentation queue access.

`CombatPresentationIntentCueResolver` owns intent interpretation for presentation only. It parses the existing deterministic strings but does not validate or execute combat behavior.

`CombatPresentationLayer` should not need new playback primitives in this pass. It already supports slash, particles, and camera impulse.

## Intent Snapshot

Use a simple dictionary shape local to `CombatScreen` and tests:

```gdscript
{
	"source_id": "enemy:0",
	"target_id": "player",
	"intent": "attack_6",
}
```

Rules:

- Capture snapshots immediately before `session.end_player_turn()`.
- Exclude defeated enemies.
- Use the same enemy index target ids already bound in `CombatPresentationLayer`.
- Keep the original intent string even if the enemy later advances its intent index.
- If the action fails, discard the snapshots and enqueue no enemy polish.

## Resolver API

Create `scripts/presentation/combat_presentation_intent_cue_resolver.gd`:

```gdscript
class_name CombatPresentationIntentCueResolver
extends RefCounted

func resolve_enemy_turn(
	intent_snapshots: Array[Dictionary],
	delta_events: Array[CombatPresentationEvent]
) -> Array[CombatPresentationEvent]:
```

The resolver returns an empty array when snapshots are empty.

Every generated event should:

- Set `source_id` from the snapshot.
- Set `target_id` according to the intent category.
- Set `payload["cue_id"]` to a stable enemy cue id.
- Copy no mutable inputs by reference.
- Remain deterministic for the same snapshots and delta events.

## Resolver Rules

### Attack Intents

For `attack_N`:

- Emit `cinematic_slash`.
- `source_id`: acting enemy target id.
- `target_id`: `player`.
- `amount`: parsed attack amount.
- `intensity`: clamp parsed amount divided by 8.0 between `0.75` and `1.8`.
- `tags`: include `enemy_intent` and `cinematic`.
- `payload["cue_id"]`: `enemy.attack`.

If the observed delta events include a `damage_number` targeting `player`, also emit `camera_impulse`:

- `target_id`: empty.
- `amount`: largest observed player damage.
- `intensity`: clamp damage divided by 8.0 between `0.5` and `2.0`.
- `tags`: include `enemy_intent`.
- `payload["cue_id"]`: `enemy.attack`.

### Block Intents

For `block_N`:

- Emit `particle_burst`.
- `source_id`: acting enemy target id.
- `target_id`: acting enemy target id.
- `amount`: parsed block amount.
- `intensity`: clamp parsed amount divided by 8.0 between `0.6` and `1.5`.
- `tags`: include `enemy_intent` and `block`.
- `payload["cue_id"]`: `enemy.block`.

### Status Intents Targeting Player

For `apply_status_<status_id>_<amount>_player`:

- Emit `particle_burst`.
- `source_id`: acting enemy target id.
- `target_id`: `player`.
- `amount`: parsed status amount.
- `status_id`: parsed status id.
- `intensity`: clamp amount divided by 3.0 between `0.7` and `1.5`.
- `tags`: include `enemy_intent` and `status`.
- `payload["cue_id"]`: `enemy.status.<status_id>`.

The parser should support multi-token status ids such as `broken_stance`.

### Self Status Intents

For `self_status_<status_id>_<amount>`:

- Emit `particle_burst`.
- `source_id`: acting enemy target id.
- `target_id`: acting enemy target id.
- `amount`: parsed status amount.
- `status_id`: parsed status id.
- `intensity`: clamp amount divided by 3.0 between `0.7` and `1.5`.
- `tags`: include `enemy_intent`, `status`, and `self`.
- `payload["cue_id"]`: `enemy.status.<status_id>`.

### Unknown Or Malformed Intents

Unknown or malformed intents should return no polish event and should not push errors. Combat validation already belongs to `CombatSession`; presentation should stay quiet and conservative.

## Asset Catalog Additions

Add cue-id mappings using existing assets:

| Event key | Asset behavior |
| --- | --- |
| `cinematic_slash:enemy.attack` | gold slash texture, short enemy attack travel, slightly warmer color |
| `camera_impulse:enemy.attack` | stronger impulse than default, short duration |
| `particle_burst:enemy.block` | green mist texture, compact defensive burst |
| `particle_burst:enemy.status.poison` | violet mist texture |
| `particle_burst:enemy.status.broken_stance` | gold or cyan slash texture used as a sharp stance-break burst |
| `particle_burst:enemy.status.sword_focus` | cyan slash texture used as a focused self-buff burst |

Unknown status ids should fall back to the existing `particle_burst` event mapping.

## CombatScreen Integration

`CombatScreen` should add:

- A `presentation_intent_resolver` field.
- A helper that captures current enemy intent snapshots.
- A way for `_run_with_feedback()` to accept optional enemy intent snapshots.

`_on_end_turn_pressed()` should:

1. Capture enemy intent snapshots.
2. Call `_run_with_feedback(func(): return session.end_player_turn(), "", "", snapshots)`.
3. Refresh as it does today.

`_run_with_feedback()` should:

1. Capture before state.
2. Execute the action.
3. Build delta events.
4. Enqueue player card polish only when `played_card_id` is present.
5. Enqueue enemy intent polish only when enemy snapshots are present and the action succeeded.
6. Enqueue delta events.

Enemy intent polish should be enqueued before delta events so players see the intent-shaped cue before the resulting numbers and flashes in the queue order.

## Testing Strategy

Release script tests:

- `tools/tests/test_release_scripts.ps1` should assert `tools/ci/run_godot_checks.ps1` contains `--import`.
- A shape test should assert `--import` appears before `res://scripts/testing/test_runner.gd`.

Unit tests:

- `CombatPresentationIntentCueResolver` emits attack slash and damage-based camera impulse.
- It emits block burst targeting the acting enemy.
- It emits player status burst for `apply_status_poison_2_player`.
- It emits self status burst for `self_status_sword_focus_1`.
- It parses multi-token status ids such as `broken_stance`.
- It ignores malformed or unknown intents without errors.
- `CombatPresentationAssetCatalog` resolves the new enemy cue ids and falls back for unknown status ids.
- `CombatPresentationConfig` existing toggles suppress reused event types, especially cinematic, particle, and camera impulse.

Smoke tests:

- Pressing End Turn against an attacking enemy enqueues or plays an enemy attack slash and camera impulse while preserving existing damage feedback.
- Pressing End Turn against a blocking enemy enqueues or plays an enemy block particle burst.
- Pressing End Turn against a status-intent enemy enqueues or plays a status particle burst.
- Disabling cinematic or particle polish filters the corresponding enemy intent cues while combat still resolves.

Manual verification:

- Start a run or Enemy Sandbox combat.
- End the turn against an attacking enemy and observe an attack-shaped slash toward the player.
- End the turn against a blocking or status enemy and observe a compact burst near the correct target.
- Disable polish toggles in `DebugOverlay` and verify enemy intent cues stop without blocking combat.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify shared Godot checks import assets before running tests.
- Verify `CombatPresentationIntentCueResolver` exists and is separate from card cue resolution.
- Verify attack, block, player status, and self status intent strings generate the specified events.
- Verify malformed or unknown intents generate no presentation errors.
- Verify asset catalog mappings exist for the new enemy cue ids.
- Verify `CombatScreen` captures intent snapshots before end turn and only emits enemy polish on successful actions.
- Verify enemy intent polish is enqueued before delta events.
- Verify no combat rule class imports presentation scripts.
- Verify no new art/audio/mixer/settings systems were added.

Stage 2: Code Quality Review

- Check GDScript typing for resolver methods and helper functions.
- Check parser logic is deterministic, small, and does not duplicate combat execution rules.
- Check event payloads, tags, and dictionaries are not aliased.
- Check CombatScreen integration keeps player card polish and enemy intent polish paths readable.
- Check tests use real combat flows where possible and avoid arbitrary timing.
- Check release-check script tests would fail if `--import` is removed or reordered after tests.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Acceptance Criteria

- Fresh worktrees and CI can run shared Godot checks after importing assets first.
- Enemy attack intents can produce slash and camera impulse polish.
- Enemy block intents can produce defensive particle polish.
- Enemy player-status and self-status intents can produce status particle polish.
- Existing presentation toggles filter the reused event categories.
- Existing damage, block, status number, flash, and pulse feedback remains intact.
- Existing click and drag player card play flows remain functional.
- No core combat rule class depends on presentation scripts.
- Full local tests pass through the shared check script.
- Godot import check exits 0.

## Future Work

- Replace string intent parsing with enemy intent resources.
- Add intent icons or preview widgets to enemy buttons.
- Add enemy-specific VFX and audio assets.
- Add reduced-motion presentation profiles.
- Add richer combat backgrounds and formal audio mixing.
