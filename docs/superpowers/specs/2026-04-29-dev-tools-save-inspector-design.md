# DevTools Save Inspector Design

Date: 2026-04-29

## Goal

Turn the Save Inspector entry in DevTools into a future-ready read-only save diagnostics panel.

The first implementation should help developers understand the current save file and predict what Main Menu Continue would do, without changing the save, mutating the active run, or routing away from DevTools. The structure should leave clear room for a later save management console with delete, export, copy JSON, and repair actions.

## Current Baseline

The project already has:

- A routable DevTools screen with stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector.
- Functional Card Browser, Enemy Sandbox, Event Tester, and Reward Inspector panels.
- `SaveService` for `save_run()`, `load_run()`, `has_save()`, and `delete_save()`.
- `RunState.to_dict()` with version, seed, character, HP, gold, deck, relics, map nodes, current node id, shop state, reward state, and terminal flags.
- Main Menu Continue logic that loads saves, deletes invalid or terminal saves, resumes pending event rewards to RewardScreen, resumes matching shop state to ShopScreen, and otherwise routes to MapScreen.

The missing piece is a safe DevTools surface that explains save state before a developer presses Continue.

## Scope

Included:

- Replace the Save Inspector placeholder with a real read-only panel inside `DevToolsScreen`.
- Read the configured `app.game.save_service` when DevTools builds or refreshes the Save Inspector.
- Display whether a save exists.
- Display whether the save can be loaded into a valid `RunState`.
- Display terminal flags for completed or failed runs.
- Display the predicted Main Menu Continue result without executing it.
- Show a compact run summary for valid saves: version, seed, character, HP, gold, deck count, relic count, current node id, current node type, completed, failed.
- Show state sections for map, shop, and pending reward information.
- Provide a Reload button that refreshes the read-only snapshot.
- Reserve UI/action structure for future delete, export, copy JSON, and repair actions without enabling them in this pass.
- Add unit and smoke tests.
- Update README progress and next plans after acceptance.

Excluded for this pass:

- No save deletion from DevTools.
- No save writing or repair.
- No JSON export or clipboard copy.
- No opening OS file paths.
- No persisted DevTools preferences.
- No route preview execution.
- No assignment to `Game.current_run`.
- No broad visual redesign.

## Architecture

`DevToolsScreen` owns the Save Inspector UI and converts the current save service state into a read-only snapshot dictionary.

```text
DevToolsScreen
  -> app.game.save_service
  -> has_save()
  -> load_run()
  -> save_inspector_snapshot()
  -> save_inspector_resume_target()
  -> render status, prediction, and run sections
```

The Save Inspector may call `has_save()` and `load_run()`. It must not call `save_run()` or `delete_save()`. It must not assign to `app.game.current_run`, mutate a loaded run, or route scenes.

The snapshot should be data-first so future management actions can reuse the same diagnostics layer without rewriting the UI.

## Snapshot API

Add these public helpers to `DevToolsScreen`:

```gdscript
func refresh_save_inspector() -> void
func save_inspector_snapshot() -> Dictionary
func save_inspector_resume_target() -> String
func save_inspector_status_text() -> String
func save_inspector_summary_text() -> String
func save_inspector_map_text() -> String
func save_inspector_shop_text() -> String
func save_inspector_reward_text() -> String
```

Snapshot fields:

- `has_service`: whether DevTools can reach `app.game.save_service`.
- `has_save`: whether `SaveService.has_save()` reports a save.
- `status`: one of `missing_service`, `no_save`, `invalid`, `terminal`, `active`.
- `resume_target`: one of `none`, `invalid_delete_on_continue`, `terminal_delete_on_continue`, `reward`, `shop`, `map`.
- `reason`: short explanation for the status or resume prediction.
- `run`: the loaded `RunState` for valid saves, or `null`.

The helper names should describe the eventual Save Management Console rather than only this first read-only screen.

## Resume Prediction

Save Inspector predicts the same outcome Main Menu Continue would use, but without executing side effects.

Rules:

- Missing save service: `status = missing_service`, `resume_target = none`.
- No save file: `status = no_save`, `resume_target = none`.
- `load_run()` returns null: `status = invalid`, `resume_target = invalid_delete_on_continue`.
- Loaded run is `failed` or `completed`: `status = terminal`, `resume_target = terminal_delete_on_continue`.
- Loaded run has `current_reward_state.source == "event"`, reward node id matches `current_node_id`, and the current map node is `event`: `status = active`, `resume_target = reward`.
- Loaded run has `current_shop_state.node_id == current_node_id` and the current map node is `shop`: `status = active`, `resume_target = shop`.
- Otherwise valid active saves resume to map: `status = active`, `resume_target = map`.

The prediction should be implemented locally in DevTools for now, but its behavior must match `MainMenu` tests. If this logic grows later, it can be extracted into a shared resume classifier.

## UI Design

Stable nodes:

- `SaveInspectorPanel`
- `SaveInspectorStatusLabel`
- `SaveInspectorResumeTargetLabel`
- `SaveInspectorRunSummaryLabel`
- `SaveInspectorStateSections`
- `SaveInspectorMapSectionLabel`
- `SaveInspectorShopSectionLabel`
- `SaveInspectorRewardSectionLabel`
- `SaveInspectorActionBar`
- `SaveInspectorReloadButton`
- `SaveInspectorDeleteButton`
- `SaveInspectorExportButton`
- `SaveInspectorCopyJsonButton`
- `SaveInspectorRepairButton`

The future action buttons should be visible as disabled controls with clear labels, or omitted only if tests still enforce the `SaveInspectorActionBar` anchor. They must not perform destructive actions in this pass.

Suggested text:

- Status: `status: active`, `status: no_save`, `status: invalid`, `status: terminal`, or `status: missing_service`.
- Resume target: `continue_target: reward`, `continue_target: shop`, `continue_target: map`, `continue_target: invalid_delete_on_continue`, `continue_target: terminal_delete_on_continue`, or `continue_target: none`.
- Summary: version, seed, character, HP, gold, deck count, relic count, current node id/type, completed, failed.
- Map section: current node plus visited/unlocked counts.
- Shop section: empty, mismatched, or matching node id with offer count and sold count.
- Reward section: empty, mismatched, or matching pending reward count and source.

## Safety Rules

Save Inspector must not:

- call `save_run()` or `delete_save()`.
- call `FileAccess.open()` directly.
- call `ResourceSaver`.
- assign to `app.game.current_run`.
- call `router.go_to()`.
- mutate `RunState`, map nodes, shop state, reward state, catalog resources, or save payloads.

Reload is read-only: it rebuilds the snapshot and updates labels.

## Testing Strategy

Unit tests:

- No save service reports `missing_service`.
- Save service with no save reports `no_save` and `none`.
- Invalid save reports `invalid` and `invalid_delete_on_continue`.
- Completed or failed save reports `terminal` and `terminal_delete_on_continue`.
- Valid normal save reports `active` and `map`.
- Valid shop save reports `active` and `shop`.
- Valid pending event reward save reports `active` and `reward`.
- Summary and section text include the core diagnostic fields.

Smoke tests:

- Save Inspector button shows `SaveInspectorPanel`.
- A real saved run displays status, resume target, and run summary.
- Reload refreshes the displayed snapshot.
- Opening and reloading Save Inspector keeps `app.game.current_run` unchanged.
- Opening and reloading Save Inspector keeps the router on DevTools.
- Opening and reloading Save Inspector does not delete invalid or terminal saves.

Manual verification:

- Open DevTools from DebugOverlay.
- Switch to Save Inspector with no save.
- Create a save through normal flow or tests, then return to Save Inspector.
- Confirm resume prediction matches Main Menu Continue behavior.
- Confirm Reload updates text after the save changes externally.

## Review Requirements

Stage 1: Spec Compliance Review

- Verify Save Inspector is no longer a placeholder.
- Verify snapshot helpers exist.
- Verify status and resume target predictions match the rules above.
- Verify map, shop, and reward sections render.
- Verify Reload is read-only.
- Verify future action structure exists without destructive behavior.
- Verify Save Inspector does not mutate `current_run`, write or delete saves, edit resources, or route away from DevTools.

Stage 2: Code Quality Review

- Check helper functions are typed and deterministic.
- Check loaded `RunState` is treated as read-only.
- Check UI node names are stable for smoke tests.
- Check resume prediction duplication is small and easy to extract later.
- Check no save management action is partially wired to destructive behavior.
- Classify findings as Critical, Important, or Minor.

## Acceptance Criteria

- Save Inspector is reachable inside DevTools.
- Developers can see whether a save service and save file exist.
- Developers can see if a save is invalid, terminal, or active.
- Developers can see the predicted Main Menu Continue target.
- Developers can inspect the run summary, map state, shop state, and pending reward state.
- Reload refreshes the diagnostics without side effects.
- Future save management action structure is present but non-destructive.
- Save Inspector never writes saves, deletes saves, repairs saves, routes into normal flow, or mutates an existing run.
- Existing local tests pass.
- Godot import check exits 0.
