# DevTools Event Tester Design

Date: 2026-04-29

## Goal

Turn the Event Tester entry in DevTools into a usable debug tool for applying catalog event options against an isolated test run.

The tool is for development and content validation. It must not write saves, edit resources, route into the normal event flow, or mutate an existing player run.

## Current Baseline

The project already has:

- A routable DevTools screen with stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector.
- A read-only Card Browser backed by `ContentCatalog`.
- A functional Enemy Sandbox that uses transient debug state and avoids `current_run`.
- `EventRunner.apply_event_option()` for HP, gold, card removal, direct card grants, direct relic grants, and pending event rewards.
- `EventScreen` for normal run event resolution, save writes, and map or reward routing.
- Twelve default event resources in `ContentCatalog`.

The missing piece is a no-persistence place to inspect an event, inspect each option's availability, and apply an option to a disposable run state.

## Scope

Included:

- Replace the Event Tester placeholder with a functional panel inside `DevToolsScreen`.
- Let developers choose an event from the default catalog.
- Let developers choose a character from the default catalog.
- Create an isolated test `RunState` from the selected character.
- Use fixed defaults for deterministic testing: full HP, 50 gold, seed `1`, current node id `event_tester_node`, and the selected character's starter deck.
- Show a run summary with character, HP, gold, deck, relics, and pending reward status.
- Show every option for the selected event with availability, unavailable reason, requirements, deltas, direct grants, removals, and generated reward configuration.
- Let developers apply one option to the isolated test run.
- Disable further option application after one option is applied until reset.
- Provide a reset button that rebuilds the isolated test run for the selected event and character.
- Add unit and smoke tests.
- Update README progress and next plans after acceptance.

Excluded:

- No custom HP, gold, seed, deck, relic, or current node editors in this pass.
- No option editing.
- No localization editing.
- No event resource editing.
- No save creation, save deletion, resume behavior, map advancement, or reward screen routing.
- No persisted DevTools preferences.
- No broad visual redesign.

## Architecture

`DevToolsScreen` owns the Event Tester state and builds a disposable `RunState`. It reuses `ContentCatalog` and `EventRunner` directly.

```text
DevToolsScreen
  -> event_tester_config()
  -> create isolated RunState
  -> EventRunner.is_option_available()
  -> EventRunner.unavailable_reason()
  -> EventRunner.apply_event_option(catalog, isolated_run, selected_event, selected_option)
  -> re-render summary and result in DevTools
```

No transient state needs to be stored on `Game` because the tester does not route away from DevTools. `EventScreen` remains the only owner of normal event routing and save behavior.

The isolated run state is never assigned to `app.game.current_run`. It lives only in `DevToolsScreen.event_tester_run`.

## DevTools Behavior

Event Tester state:

- default event: first event id in sorted catalog order.
- default character: `sword` when available.
- default HP: selected character max HP.
- default gold: `50`.
- default seed: `1`.
- default deck: selected character starter deck.
- default current node id: `event_tester_node`.
- option applied flag: `false` until an option is applied.

Stable nodes:

- `EventTesterPanel`
- `EventTesterEventSelect`
- `EventTesterCharacterSelect`
- `EventTesterRunSummaryLabel`
- `EventTesterOptionList`
- `EventTesterOption_<index>`
- `EventTesterResultLabel`
- `EventTesterResetButton`

Event ordering is deterministic by event id. Character ordering matches the existing DevTools character helper behavior: `sword` first when available, then sorted ids.

When event or character selection changes, DevTools rebuilds the isolated test run and clears the result message.

## Option Summary

Each option button displays enough data to validate content quickly:

- option id.
- availability state.
- unavailable reason when blocked.
- `min_hp` and `min_gold` when non-zero.
- `hp_delta` and `gold_delta` when non-zero.
- `remove_card_id` when present.
- direct `grant_card_ids` and `grant_relic_ids` when present.
- `card_reward_count` when non-zero.
- `relic_reward_tier` when present.

Unavailable options are disabled. Available options are disabled after any option is applied until reset.

## Apply Behavior

Applying an option:

- uses `EventRunner.apply_event_option()`.
- mutates only the isolated `event_tester_run`.
- updates the summary immediately.
- sets a result message with the applied option id.
- shows pending reward details when the option creates `current_reward_state`.
- disables all option buttons until reset.

If `apply_event_option()` returns `false`, DevTools shows a failed result message and leaves the isolated run unchanged.

## Safety Rules

Event Tester must not:

- call `save_run()`, `delete_save()`, `FileAccess.open()`, or `ResourceSaver`.
- assign to `app.game.current_run`.
- route to `SceneRouter.EVENT`, `SceneRouter.REWARD`, `SceneRouter.MAP`, or `SceneRouter.SUMMARY`.
- mutate catalog resources.

## Testing Strategy

Unit tests:

- Event Tester exposes deterministic event ids.
- Default config uses the default event, `sword`, starter deck, full HP, 50 gold, and seed `1`.
- Run summary includes character, HP, gold, deck, relics, and pending reward state.
- Option summary includes availability, requirements, deltas, grants, removals, and reward configuration.
- Applying an available option mutates only the isolated test run.
- Reset rebuilds the isolated run and clears the applied state.

Smoke tests:

- Event Tester button shows the real panel instead of a placeholder.
- Applying a default event option updates the result label and does not set `app.game.current_run`.

Manual verification:

- Open DevTools from the debug overlay.
- Switch to Event Tester.
- Change event and character.
- Apply an available option.
- Confirm HP, gold, deck, relic, and pending reward summaries update.
- Press reset and confirm the run returns to defaults.

## Review Requirements

Stage 1: Spec Compliance Review

- Verify Event Tester is no longer a placeholder.
- Verify event and character selections exist.
- Verify the isolated test run uses deterministic defaults.
- Verify option summaries include availability, requirements, deltas, grants, removals, and generated reward configuration.
- Verify applying an option uses `EventRunner.apply_event_option()`.
- Verify applying an option does not mutate `current_run`, write saves, edit resources, or route away from DevTools.
- Verify reset rebuilds the isolated run.

Stage 2: Code Quality Review

- Check GDScript typing for new helpers.
- Check Event Tester helpers are deterministic and testable.
- Check UI node names are stable for smoke tests.
- Check normal Card Browser and Enemy Sandbox behavior remains unchanged.
- Check no event option gameplay logic is duplicated outside `EventRunner`.
- Classify findings as Critical, Important, or Minor.

## Acceptance Criteria

- Event Tester is reachable inside DevTools.
- Developers can choose a catalog event and character.
- The isolated run summary updates from the selected character.
- Developers can apply an available event option to the isolated run.
- Applied option results, including pending rewards, are visible in DevTools.
- Event Tester never writes saves, edits resources, routes into normal flow, or mutates an existing run.
- Existing local tests pass.
- Godot import check exits 0.
