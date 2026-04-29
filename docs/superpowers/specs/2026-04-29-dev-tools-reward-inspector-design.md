# DevTools Reward Inspector Design

Date: 2026-04-29

## Goal

Turn the Reward Inspector entry in DevTools into a usable no-persistence tool for previewing reward packages and simulating reward claims against an isolated test run.

The tool is for development and balance validation. It must not write saves, edit resources, route into normal reward flow, or mutate an existing player run.

## Current Baseline

The project already has:

- A routable DevTools screen with stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector.
- A read-only Card Browser.
- An Enemy Sandbox that uses transient combat setup and avoids `Game.current_run`.
- An Event Tester that applies event options against an isolated `RunState`.
- `RewardGenerator` for deterministic card, gold, and relic reward draws.
- `RewardResolver.resolve()` for current-node reward packages.
- `RewardScreen` for normal reward claiming, save writes, map advancement, and routing.
- Reward dictionaries for `card_choice`, `gold`, and `relic` items.

The missing piece is a no-persistence place to inspect a generated reward package, click through claim or skip choices, and see how those choices would change a run.

## Scope

Included:

- Replace the Reward Inspector placeholder with a functional panel inside `DevToolsScreen`.
- Let developers choose a character from the default catalog.
- Let developers choose a node type from `combat`, `elite`, and `boss`.
- Let developers set the deterministic seed used by the isolated run.
- Create an isolated test `RunState` from the selected character and node type.
- Generate rewards through `RewardResolver.resolve(catalog, reward_inspector_run)`.
- Show a run summary with character, node type, seed, HP, gold, deck, and relics.
- Show each generated reward with readable card, gold, or relic details.
- Let developers simulate claiming one card from a card reward, claiming gold, claiming a relic, or skipping any reward.
- Track reward item state as `available`, `claimed`, or `skipped`.
- Disable already resolved reward items until reset or a config change.
- Provide a reset button that rebuilds the isolated test run and reward package from the current config.
- Add shared reward application logic so `RewardScreen` and Reward Inspector use one claim implementation.
- Add unit and smoke tests.
- Update README progress and next plans after acceptance.

Excluded:

- No batch seed scanning or statistical reward distribution table in this pass.
- No custom deck, gold, HP, relic, or map editor beyond character, node type, and seed.
- No reward resource editing.
- No save creation, save deletion, resume behavior, map advancement, or normal reward screen routing.
- No persisted DevTools preferences.
- No broad visual redesign.

## Architecture

`DevToolsScreen` owns the Reward Inspector state and builds a disposable `RunState`. It reuses `ContentCatalog`, `RewardResolver`, and a new shared `RewardApplier`.

```text
DevToolsScreen
  -> reward_inspector_config()
  -> create isolated RunState
  -> RewardResolver.resolve(catalog, isolated_run)
  -> render rewards and simulated run state
  -> RewardApplier.apply_* only to isolated_run
```

`RewardScreen` should also use `RewardApplier` for real reward claims. `RewardScreen` remains the only owner of save writes, map advancement, and reward scene routing. The new shared class only applies a selected reward dictionary to a supplied `RunState` and returns whether it succeeded.

The isolated run state is never assigned to `app.game.current_run`. It lives only in `DevToolsScreen.reward_inspector_run`.

## RewardApplier

Add `scripts/reward/reward_applier.gd`.

Responsibility:

- Apply a selected `card_choice` card id to `RunState.deck_ids`.
- Apply a `gold` reward amount to `RunState.gold`.
- Apply a `relic` reward id to `RunState.relic_ids`.
- Reject invalid reward types, invalid card indexes, empty ids, and null runs.
- Avoid duplicate relic ids when applying relic rewards.

Public API:

```gdscript
class_name RewardApplier
extends RefCounted

func claim_card(run: RunState, reward: Dictionary, card_index: int) -> bool
func claim_gold(run: RunState, reward: Dictionary) -> bool
func claim_relic(run: RunState, reward: Dictionary) -> bool
```

This class does not load catalogs, generate rewards, save, advance map state, or route scenes. It only applies a concrete reward dictionary to a concrete run.

## DevTools Behavior

Reward Inspector state:

- default character: `sword` when available.
- default node type: `combat`.
- default seed: `1`.
- default HP: selected character max HP.
- default gold: `0`.
- default deck: selected character starter deck.
- default relics: empty.
- default current node id: `reward_inspector_node`.
- reward states: one state per generated reward item.

Stable nodes:

- `RewardInspectorPanel`
- `RewardInspectorCharacterSelect`
- `RewardInspectorNodeTypeSelect`
- `RewardInspectorSeedSpinBox`
- `RewardInspectorRunSummaryLabel`
- `RewardInspectorRewardList`
- `RewardInspectorReward_<index>`
- `RewardInspectorRewardLabel_<index>`
- `RewardInspectorClaimCard_<reward_index>_<card_index>`
- `RewardInspectorClaimGold_<reward_index>`
- `RewardInspectorClaimRelic_<reward_index>`
- `RewardInspectorSkip_<reward_index>`
- `RewardInspectorResetButton`

Character ordering matches the existing DevTools character helper behavior: `sword` first when available, then sorted ids.

When character, node type, or seed changes, DevTools rebuilds the isolated test run, regenerates the reward package, and clears claim states.

## Reward Text

Each reward row displays enough data to validate content quickly:

- reward id.
- reward type.
- card choice ids and readable card summaries.
- gold amount and tier when present.
- relic id and tier when present.
- item state.

The run summary updates after each simulated claim or skip:

- card claims add the selected card id to the displayed deck.
- gold claims update displayed gold.
- relic claims update displayed relics.
- skipped rewards do not mutate the isolated run.

## Safety Rules

Reward Inspector must not:

- call `save_run()`, `delete_save()`, `FileAccess.open()`, or `ResourceSaver`.
- assign to `app.game.current_run`.
- route to `SceneRouter.REWARD`, `SceneRouter.MAP`, `SceneRouter.SUMMARY`, or any normal run flow.
- call `RunProgression.advance_current_node()`.
- mutate catalog resources.

`RewardScreen` may continue to save and route as normal, but only outside the Reward Inspector path.

## Testing Strategy

Unit tests:

- `RewardApplier` claims a selected card into a run deck and rejects invalid card indexes.
- `RewardApplier` claims gold into run gold.
- `RewardApplier` claims relics without duplicating an existing relic id.
- Reward Inspector default config uses `sword`, `combat`, seed `1`, and an isolated node.
- Reward Inspector generated rewards match `RewardResolver` for combat and boss nodes.
- Reward Inspector claim simulation mutates only `reward_inspector_run`.
- Reward Inspector reset rebuilds the isolated run and clears reward states.

Smoke tests:

- Reward Inspector button shows the real panel instead of a placeholder.
- Claiming a default card reward updates the summary and keeps `app.game.current_run` null.
- Switching seed or node type refreshes the reward list in place.

Manual verification:

- Open DevTools from the debug overlay.
- Switch to Reward Inspector.
- Change character, node type, and seed.
- Claim a card, claim or skip gold, and reset.
- Confirm the isolated run summary changes while the active game run and route remain untouched.

## Review Requirements

Stage 1: Spec Compliance Review

- Verify Reward Inspector is no longer a placeholder.
- Verify character, node type, and seed controls exist.
- Verify the isolated test run uses deterministic defaults.
- Verify rewards are generated through `RewardResolver`.
- Verify card, gold, relic, and skip actions update only the isolated run and reward state.
- Verify reset rebuilds the isolated run and reward package.
- Verify `RewardScreen` uses shared reward application logic for claims.
- Verify Reward Inspector does not mutate `current_run`, write saves, edit resources, advance map state, or route away from DevTools.

Stage 2: Code Quality Review

- Check new helpers are typed.
- Check reward application rules live in `RewardApplier`, not duplicated across UI scripts.
- Check Reward Inspector helpers are deterministic and testable.
- Check UI node names are stable for smoke tests.
- Check normal Card Browser, Enemy Sandbox, Event Tester, and RewardScreen behavior remains unchanged.
- Classify findings as Critical, Important, or Minor.

## Acceptance Criteria

- Reward Inspector is reachable inside DevTools.
- Developers can choose a catalog character, node type, and seed.
- The isolated run summary updates from the selected character and seed.
- Developers can preview rewards generated by `RewardResolver`.
- Developers can simulate claiming card, gold, and relic rewards against the isolated run.
- Developers can skip any reward item.
- Resolved reward items are disabled until reset or config change.
- Reward Inspector never writes saves, edits resources, routes into normal flow, advances map state, or mutates an existing run.
- `RewardScreen` and Reward Inspector use shared reward application logic.
- Existing local tests pass.
- Godot import check exits 0.

