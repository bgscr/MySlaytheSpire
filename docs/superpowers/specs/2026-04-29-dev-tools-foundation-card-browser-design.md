# Developer Tools Foundation and Card Browser Design

Date: 2026-04-29

## Goal

Add the first developer tools surface for the project: a unified DevTools screen with stable entrances for the planned tools, plus a fully usable read-only Card Browser.

The intent is to make future content and balance work faster without changing gameplay state, save data, or production player flows.

## Current Baseline

The project already has:

- A debug overlay that appears in debug builds.
- A `SceneRouter` that routes main menu, map, combat, event, reward, shop, and summary scenes.
- A `ContentCatalog` that loads default cards, characters, enemies, relics, and events.
- Forty default cards across `sword` and `alchemy`.
- Data-driven card fields for id, character, type, rarity, cost, tags, effects, and presentation cues.
- Smoke tests that instantiate app scenes through the router.

The project does not yet have a dedicated developer tools screen. Existing debug controls are useful for run state shortcuts, but they do not provide catalog inspection, scenario setup, or save inspection.

## Confirmed Direction

Build a small DevTools foundation now, then fill individual tools in later plans.

This first pass includes:

1. A routable DevTools screen.
2. A DebugOverlay button that opens DevTools.
3. A tab-like internal tool switcher with stable entries for:
   - Card Browser
   - Enemy Sandbox
   - Event Tester
   - Reward Inspector
   - Save Inspector
4. A complete read-only Card Browser.
5. Placeholder panels for the four deferred tools.

This avoids creating a standalone Card Browser island while keeping the first implementation small enough to test and review.

## Scope

Included:

- Add `SceneRouter.DEV_TOOLS`.
- Add `scenes/dev/DevToolsScreen.tscn`.
- Add `scripts/ui/dev_tools_screen.gd`.
- Add a `Debug: Dev Tools` button to `DebugOverlay`.
- Load `ContentCatalog.load_default()` inside DevTools.
- Display all catalog cards in a deterministic list.
- Let developers filter cards by:
  - character: all, sword, alchemy
  - rarity: all, common, uncommon, rare
  - card type: all, attack, skill, power
- Let developers select a card and inspect:
  - id
  - name key
  - description key
  - character id
  - rarity
  - type
  - cost
  - tags
  - pool tags
  - reward weight
  - effects
  - presentation cues
- Provide stable placeholder panels for Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector.
- Add unit tests for Card Browser filtering and detail text helpers.
- Add smoke tests for routing from DebugOverlay to DevTools and inspecting a representative card.
- Update README progress and next plans after acceptance.

Excluded:

- No editing card resources.
- No writing content changes from DevTools.
- No enemy combat simulation in this pass.
- No event option execution tester in this pass.
- No reward roll preview in this pass.
- No save file read/write inspector in this pass.
- No persisted DevTools preferences.
- No release build entry point for DevTools.
- No broad UI skin pass.

## Architecture

The DevTools screen is a debug-only developer scene reached from `DebugOverlay`.

```text
DebugOverlay
  -> SceneRouter.DEV_TOOLS
  -> DevToolsScreen
  -> ContentCatalog.load_default()
  -> tool switcher
     -> Card Browser panel
     -> deferred placeholder panels
```

`DevToolsScreen` owns this first implementation. It is allowed to read catalog data and render developer-facing text, but it must not mutate run state, save data, or resource files.

The Card Browser filtering logic should be small and testable. If the screen grows in later passes, the filter/detail helpers can be extracted into separate classes, but this pass should avoid extra abstraction until there is a second real tool.

## DevTools Hub

The screen should have a predictable node structure for tests and future tool expansion:

- `ToolNav`: horizontal or vertical container for tool buttons.
- `ToolContent`: container that owns the active tool panel.
- `CardBrowserPanel`: the first fully functional panel.
- `ToolPlaceholder_<tool_id>` nodes for deferred tools.

Tool ids:

- `card_browser`
- `enemy_sandbox`
- `event_tester`
- `reward_inspector`
- `save_inspector`

Opening a deferred tool shows a concise placeholder with the tool name and a fixed "Planned tool" status. It should not pretend to be functional.

## Card Browser Behavior

The Card Browser loads the default catalog once when the screen enters the tree.

Initial state:

- active tool: Card Browser
- character filter: all
- rarity filter: all
- type filter: all
- selected card: first card in the filtered deterministic list

Card list ordering:

1. character id
2. rarity order: common, uncommon, rare
3. card type order: attack, skill, power
4. card id

Filtering rules:

- `"all"` means the filter does not restrict that dimension.
- Filters combine with AND semantics.
- If filters produce no cards, the card list shows a stable "No cards match filters" label and the detail panel shows "No card selected".
- Changing filters selects the first card in the new filtered list when the previous selected card no longer matches.
- Changing filters keeps the current selection when it still matches.

Detail text should be readable in a debug context and intentionally expose raw ids and localization keys instead of translated final player copy. This is a content inspection tool, not player UI.

Effect rows should include:

- effect type
- target
- amount
- status id when present
- block/status/draw/energy fields when present through existing `EffectDef` fields

Presentation cue rows should include:

- event type
- target mode
- amount
- intensity
- cue id
- tags

## DebugOverlay Integration

`DebugOverlay` should add a `Debug: Dev Tools` button in debug builds.

The button routes through `app.game.router.go_to(SceneRouterScript.DEV_TOOLS)`.

If no app or router exists, the button handler should return safely, matching existing debug overlay behavior.

## Testing Strategy

Unit tests:

- DevTools filter helper returns all 40 cards with all filters disabled.
- Filtering by sword, common, and attack combines with AND semantics.
- Card ordering is deterministic.
- Detail text for `sword.strike` includes id, cost, effect summary, and presentation cue summary.
- Placeholder metadata exposes all deferred tool ids.

Smoke tests:

- DebugOverlay has a `DebugDevTools` button.
- Pressing the button routes to `DevToolsScreen`.
- DevTools starts on Card Browser.
- Selecting `sword.strike` updates the detail panel with the card id.
- Switching to Enemy Sandbox shows the planned placeholder.

Manual verification:

- Start the project in a debug build.
- Open DevTools from DebugOverlay.
- Filter sword common attacks and confirm the list narrows.
- Select a card and inspect effects and presentation cues.
- Switch to each deferred tool and confirm the placeholder is explicit.
- Return to Map from DebugOverlay to confirm normal debug navigation still works.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify `SceneRouter.DEV_TOOLS` exists.
- Verify `DebugOverlay` exposes `DebugDevTools`.
- Verify `DevToolsScreen` has stable entries for all five planned tools.
- Verify Card Browser loads default catalog cards.
- Verify filters exist for character, rarity, and card type.
- Verify filters combine with AND semantics.
- Verify card details include card fields, effects, and presentation cues.
- Verify deferred tools are explicit placeholders.
- Verify DevTools does not mutate run state, saves, or resources.

Stage 2: Code Quality Review

- Check GDScript typing for DevTools fields and helpers.
- Check filter/detail helper code is deterministic and testable.
- Check node names are stable for tests.
- Check DebugOverlay routing follows existing safe app lookup patterns.
- Check DevTools does not duplicate catalog loading constants.
- Check tests do not depend on translated UI copy or fragile visual layout.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Acceptance Criteria

- DevTools is reachable from DebugOverlay in debug builds.
- DevTools presents stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector.
- Card Browser is fully usable as a read-only catalog inspection tool.
- Card filters work by character, rarity, and type.
- Card detail inspection includes effects and presentation cues.
- Deferred tools clearly show planned placeholders.
- No run state, save data, or resource files are mutated by DevTools.
- Existing local tests pass.
- Godot import check exits 0.

## Future Work

- Implement Enemy Sandbox as the next tool: select enemies, choose a player deck, and start isolated combat scenarios.
- Implement Event Tester for resolving and applying event options against generated test run states.
- Implement Reward Inspector for previewing reward rolls by node type, seed, character, and relic state.
- Implement Save Inspector for reading current save state and validating resume routing.
- Add richer search and sorting once Card Browser usage shows which queries are most common.
