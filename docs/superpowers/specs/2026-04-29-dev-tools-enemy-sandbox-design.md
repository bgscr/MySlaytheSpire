# DevTools Enemy Sandbox Design

Date: 2026-04-29

## Goal

Turn the Enemy Sandbox entry in DevTools into a usable debug tool for launching isolated combat scenarios against selected catalog enemies.

The tool is for development and content testing. It must not edit resources, write saves, or mutate an existing player run.

## Current Baseline

The project already has:

- A routable DevTools screen with stable tool entries.
- A read-only Card Browser backed by `ContentCatalog`.
- A `CombatScreen` that starts a `CombatSession` from `app.game.current_run`.
- A `CombatSession` that can run combat from catalog cards, enemies, status effects, relic runtime hooks, and presentation feedback.
- Sixteen default enemies and two default characters in `ContentCatalog`.

The missing piece is a way to bypass map encounter generation and start combat against explicit enemy ids without touching the active run.

## Scope

Included:

- Replace the Enemy Sandbox placeholder with a functional panel inside `DevToolsScreen`.
- Let developers choose a character from the default catalog.
- Use that character's starter deck as the sandbox deck.
- Let developers select one to three enemies from the default catalog.
- Show a deterministic summary of the selected character, deck, enemies, HP, tiers, and intent sequences.
- Launch the selected scenario into `CombatScreen`.
- Start sandbox combat from explicit enemy ids instead of generated map encounters.
- Keep sandbox combat isolated from `current_run`, save files, and resources.
- Keep terminal sandbox combat on `CombatScreen` instead of routing to rewards or run summary.
- Add unit and smoke tests.

Excluded:

- No enemy editing.
- No custom card-by-card deck builder.
- No relic selection.
- No status preloading.
- No reward generation from sandbox wins.
- No save creation, save deletion, or resume behavior.
- No persisted DevTools preferences.
- No broad visual redesign.

## Architecture

Add a transient sandbox configuration to `Game`. DevTools writes the config immediately before routing to `CombatScreen`; `CombatScreen` consumes and clears it during startup.

```text
DevToolsScreen
  -> enemy_sandbox_config()
  -> Game.set_debug_combat_sandbox_config(config)
  -> SceneRouter.COMBAT
  -> CombatScreen.take_debug_combat_sandbox_config()
  -> CombatSession.start_sandbox(catalog, character_id, deck_ids, enemy_ids, seed)
```

`CombatSession.start_sandbox()` builds combat state directly from catalog data. It does not require a `RunState`, does not call `EncounterGenerator`, and leaves `run` as `null`. Existing win/loss methods already guard run writes when `run == null`.

`CombatScreen` owns the distinction between normal combat and sandbox combat. Normal combat keeps the current map/reward/summary routing. Sandbox combat does not route to reward or summary when terminal, so developers can inspect the final state.

## DevTools Behavior

Enemy Sandbox state:

- default character: `sword` when available.
- default enemy: `training_puppet` when available.
- selected enemies: one to three unique ids.
- deck: selected character's `starting_deck_ids`.
- seed: fixed `1` for deterministic starter hand order.

Stable nodes:

- `EnemySandboxPanel`
- `EnemySandboxCharacterSelect`
- `EnemySandboxDeckLabel`
- `EnemySandboxEnemyList`
- `EnemySandboxEnemy_<enemy_id>`
- `EnemySandboxSummaryLabel`
- `EnemySandboxLaunchButton`

Enemy list ordering is deterministic:

1. tier order: normal, elite, boss
2. enemy id

Toggling an enemy removes it when selected. Toggling an unselected enemy adds it only while fewer than three enemies are selected. If filtering or direct helper calls would leave the selection empty, DevTools restores the default enemy.

## Combat Behavior

Sandbox combat starts with:

- player id and max HP from the selected character.
- current HP equal to max HP.
- deck ids from the selected character starter deck.
- one to three explicit enemies with catalog HP and intent sequences.
- energy 3, turn 1, and normal first-turn draw behavior.
- no relic effects unless future scope adds relic selection.

Invalid sandbox input produces `PHASE_INVALID` with an explanatory `error_text`.

## Testing Strategy

Unit tests:

- Enemy Sandbox exposes deterministic enemy ids.
- Default sandbox config uses `sword`, starter deck ids, and `training_puppet`.
- Enemy selection removes duplicates, ignores invalid ids, and caps at three ids.
- Summary text includes character, deck, enemy HP, tier, and intents.
- `CombatSession.start_sandbox()` starts explicit enemies without a run.
- Invalid sandbox combat fails when enemies are missing.

Smoke tests:

- Enemy Sandbox button shows the real panel instead of a placeholder.
- Launching the default sandbox routes to `CombatScreen`.
- Launched combat has `is_sandbox == true`, no `current_run`, and the selected enemy id.

Manual verification:

- Open DevTools from the debug overlay.
- Switch to Enemy Sandbox.
- Toggle one to three enemies.
- Launch and confirm combat starts against those enemies.
- Win or lose the sandbox combat and confirm no reward or summary routing happens.

## Review Requirements

Stage 1: Spec Compliance Review

- Verify Enemy Sandbox is no longer a placeholder.
- Verify character and enemy selections exist.
- Verify selected enemy ids are unique and capped at three.
- Verify launch routes to `CombatScreen`.
- Verify `CombatSession.start_sandbox()` uses explicit enemy ids.
- Verify sandbox combat does not require or mutate `current_run`.
- Verify no save or resource writes are introduced.

Stage 2: Code Quality Review

- Check GDScript typing for new helpers.
- Check sandbox config is consumed and cleared.
- Check normal combat routing remains unchanged.
- Check helper methods are deterministic and testable.
- Check UI node names are stable for smoke tests.
- Classify findings as Critical, Important, or Minor.

## Acceptance Criteria

- Enemy Sandbox is reachable inside DevTools.
- Developers can choose a character and one to three catalog enemies.
- The starter deck summary updates with the selected character.
- Launching creates sandbox combat against explicit enemies.
- Sandbox combat never writes saves, resources, or an existing run.
- Existing local tests pass.
- Godot import check exits 0.
