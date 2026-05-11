# Localization And UI Polish Design

Date: 2026-05-11

## Goal

Build a comprehensive screen-by-screen localization and near-demo UI polish pass for the current Godot prototype.

Chinese and English are the only required languages for this phase. Chinese must be the default interface at launch. The main menu must include a visible language toggle labeled `中 / EN`, and changing the language should update visible UI without restarting the game.

The polish target is near-demo quality with an elegant ink-and-jade xianxia direction: readable Chinese typography, restrained painterly panels, jade and gold accents, calm premium composition, and intentional screen hierarchy. This is not a final production art pass, but it should remove the current prototype roughness from every main-flow and debug screen.

## Current Baseline

The project already has:

- A playable flow through Main Menu, Map, Combat, Rewards, Event, Shop, and Run Summary.
- Debug-only surfaces through Debug Overlay and Dev Tools.
- Partial localization through `localization/zh_CN.po`.
- `project.godot` registering only `res://localization/zh_CN.po`.
- Content resources using localization keys for cards, relics, characters, enemies, and events.
- Combat presentation resources for backgrounds, card thumbnails, enemy portraits, relic icons, motion profile toggles, and audio-mix debug sliders.
- UI screens implemented mostly as simple programmatic Godot controls under `scripts/ui/`.

Current gaps:

- Many visible strings are hardcoded in English in UI scripts.
- There is no English translation file.
- Chinese is partial and not enforced as a complete default interface.
- No visible language toggle exists.
- Several player-facing views show internal ids instead of translated names.
- Enemy intent display resources store raw English labels.
- Item detail panels expose technical English labels and ids as primary text.
- Debug Overlay and Dev Tools are mostly English and visually raw.
- Layouts are functional but still prototype-like, with weak hierarchy, sparse composition, and little shared styling.

## Confirmed Direction

Use a "shared foundations, then screen slices" approach.

First add the minimum shared localization and UI-style foundations needed by every screen. Then polish screens in main-flow order. A screen is complete only when localization, visual polish, tests, and smoke coverage are finished together for that screen.

Screen order:

1. Main Menu
2. Map
3. Combat
4. Rewards
5. Event
6. Shop
7. Run Summary
8. Debug Overlay
9. Dev Tools

## Non-Goals

This phase does not include:

- New gameplay rules.
- New card, relic, enemy, event, reward, shop, save, or map mechanics.
- A large UI framework or base-screen inheritance hierarchy.
- A full redesign of project architecture.
- Final bespoke art for every UI element.
- Additional languages beyond `zh_CN` and `en`.
- Persisted player settings beyond the language choice.
- Controller, touch, or Steam-specific localization handling.

## Approaches Considered

### Chosen: Shared Foundations, Then Screen Slices

Add a small localization runtime, an English translation file, shared text formatting helpers, and a compact shared UI style layer. Then finish each screen in order with localization and visual polish together.

This fits the existing project because presentation data is already moving into small resource/resolver layers, while UI scripts remain intentionally direct. It gives every screen consistent language behavior and visual tone without forcing a broad framework.

### Alternative: Pure Screen-By-Screen Direct Edits

Start at Main Menu and polish each script directly, extracting helpers only after duplication appears.

This gives the fastest visible first-screen improvement, but it risks solving localization, styling, language switching, and formatting differently on every screen. That would preserve the kind of roughness this pass is meant to remove.

### Alternative: Full UI Shell Refactor

Create a UI framework with shared base screen classes, a global navigation shell, style managers, transitions, and screen controllers before migrating every screen.

This could produce clean long-term architecture, but it is too heavy for the current prototype and conflicts with the project's simplicity and surgical-change rules.

## Shared Foundations

### Language Runtime

Add a small localization service owned by `Game` or `App`.

Responsibilities:

- Store the current locale.
- Default to `zh_CN` on first launch.
- Load and save the selected locale through a small settings file under `user://`, separate from run saves.
- Support only `zh_CN` and `en` in this phase.
- Switch locale through one method, such as `set_locale(locale: String) -> void`.
- Call the appropriate Godot translation API for runtime locale changes.
- Emit a `locale_changed(locale: String)` signal.
- Reject unsupported or unreadable locale ids by falling back to `zh_CN`.

The main menu owns the visible `中 / EN` toggle, but the service owns the actual locale state so other screens can refresh consistently.

### Translation Files

Keep:

- `localization/zh_CN.po`

Add:

- `localization/en.po`

Register both in `project.godot`.

Translation keys must cover:

- Main menu labels and language toggle.
- Map node types, states, route labels, and empty/fallback states.
- Combat buttons, summaries, pile labels, phases, target labels, intent labels, status labels, and errors.
- Reward title/status/actions/states and reward labels.
- Event fallback states, option composition, availability reasons, and continuation.
- Shop title, gold, offer labels, buy/choose/refresh/leave/sold-out/remove-card flow.
- Run summary win/loss copy, key stat labels, and return action.
- Debug Overlay controls, toggles, and audio labels.
- Dev Tools tool names, filters, empty states, summaries, actions, and inspector labels.
- Shared card, relic, reward, rarity, tier, type, status, target, and boolean labels.

Content resource keys should remain stable where they already exist, such as `card.*.name`, `card.*.desc`, `relic.*.name`, `event.*.title`, and `event.*.body`.

### Localized Text Helpers

Add a small helper focused on repeated UI formatting. It should not become a general UI framework.

Likely responsibilities:

- Format HP, block, energy, turn, gold, draw/discard/exhaust, phase, and reward state strings.
- Format card and relic display names from catalog resources.
- Format card type, rarity, relic tier, node type, status name, target name, and enemy intent labels.
- Compose compact debug summaries with localized labels while preserving ids and technical values as data values.
- Provide a fallback for missing objects that does not expose English by default in Chinese mode.

The helper should be easy to unit-test without loading full scenes.

### Shared UI Style

Add a compact shared style layer for the ink-and-jade direction.

Allowed assets:

- Chinese-capable UI font.
- Shared panel/background treatments.
- Button/icon accents.
- Small badge/icon assets where they improve scanning.
- Screen background or frame textures if they directly support the polish pass.

Implementation should prefer Godot `Theme`, `StyleBox`, and small helper functions over a broad class hierarchy.

Style targets:

- Panel backgrounds.
- Primary and secondary buttons.
- Disabled states.
- Labels and title labels.
- Detail panels.
- List rows.
- Compact badges for status, intent, node type, rarity, and tier.

### Screen Refresh Contract

Each localized screen should implement a local refresh path, such as `_refresh_locale_text()` or a screen-specific render method that is called after `locale_changed`.

Rules:

- Switching language should not mutate gameplay state.
- Dynamic lists may be rebuilt if that is simplest.
- UI controls should keep stable node names used by tests unless a spec section explicitly replaces them.
- Screens should avoid hardcoded English visible text.

## Screen Designs

### Main Menu

Requirements:

- Chinese is visible by default on first launch.
- New Run and Continue use translation keys.
- Continue disabled state has localized copy or a localized disabled treatment.
- Add a visible `中 / EN` toggle.
- Toggling language immediately updates Main Menu text.
- The screen sets the visual tone with ink-and-jade title treatment, primary actions, readable spacing, and a calm first impression.

Acceptance:

- Smoke test verifies Chinese default labels.
- Smoke test toggles to English and verifies labels update.
- No visible hardcoded English remains in Chinese mode except the `EN` part of the language toggle.

### Map

Requirements:

- Replace the rough node list with a cleaner route presentation.
- Localize node type names for combat, elite, boss, event, shop, and reward/fallback.
- Localize node states for visited, unlocked, locked, current, and selectable where displayed.
- Keep the existing map data model and routing behavior.
- Use translated labels and consistent badges instead of raw node type strings as primary UI.

Acceptance:

- Smoke tests verify Chinese and English node labels.
- Existing node routing still works.
- Locked and visited states are visually distinct and localized.

### Combat

Requirements:

- Localize player summary, enemy summary, pile labels, phase labels, target labels, action buttons, error text, intent labels, intent targets, and status display names.
- Enemy intent display resources must move from raw `label` strings to `label_key`.
- Existing combat presentation and visual resource pipeline remains intact.
- Combat layout should be polished, not rewritten: clearer player area, enemy area, card row, intent badges, item detail panel, and background framing.
- Reduced-motion settings remain respected.
- Technical ids should not be the primary player-facing names when translated names are available.

Acceptance:

- Unit tests cover status names, intent labels, phase text, target text, and pile text in both languages.
- Smoke tests load combat in both languages.
- Existing combat click/drag/target behavior remains covered.

### Rewards

Requirements:

- Localize reward title, status, continue, skip, claim, resolved states, and no-rewards state.
- Use translated card and relic names in player-facing reward labels.
- Keep card and relic preview behavior.
- Polish reward rows, skip/continue hierarchy, resolved states, and detail previews.

Acceptance:

- Tests verify card, gold, relic, skip, claimed, and skipped states in both languages.
- Smoke tests confirm the reward flow remains routable.

### Event

Requirements:

- Localize fallback event title/body/continue states.
- Localize option labels, descriptions, availability reasons, and option composition.
- Continue using content event translation keys.
- Improve body readability, option rows, disabled option treatment, and item preview placement.

Acceptance:

- Tests verify option text and unavailable reasons in both languages.
- Event reward routing remains unchanged.

### Shop

Requirements:

- Localize title, gold, no-shop state, offer labels, sold out, buy, choose card, remove-card prompt, refresh, leave, and unknown offer fallback.
- Use translated item names where player-facing.
- Preserve price, rarity/tier, card cost, and offer state information.
- Polish shop layout into grouped offer, removal, detail, and action areas.

Acceptance:

- Tests cover card, relic, heal, remove, refresh, sold-out, no-shop, and leave text in both languages.
- Shop purchase, refresh, remove, and leave behavior remains unchanged.

### Run Summary

Requirements:

- Localize win/loss result and return-to-menu action.
- Add near-demo summary composition with result header, key run stats, and a polished close.
- Clear ended runs exactly as before.

Acceptance:

- Smoke tests cover failed and completed summary states.
- Return to menu behavior remains unchanged.

### Debug Overlay

Requirements:

- Localize full HP, gold, map, Dev Tools, presentation toggles, reduced motion, drag play, floating text, hit flash, target highlight, status pulse, cinematic, particles, camera impulse, slow motion, audio cue, and audio volume labels.
- Keep debug-only visibility behavior.
- Make the compact panel look intentional and readable with the shared style.

Acceptance:

- Tests or smoke checks verify representative debug labels in both languages.
- Existing toggle behavior remains unchanged.

### Dev Tools

Requirements:

- Localize tool navigation, filter labels/options, empty states, action buttons, run summaries, reward/event/save inspector labels, and result messages.
- Internal ids remain visible when they are the inspected object or debug value.
- Surrounding labels must be localized, so Chinese mode does not read like an English debug dump.
- Reorganize layouts into grouped panels per tool while keeping existing tool functionality:
  - Card Browser
  - Enemy Sandbox
  - Event Tester
  - Reward Inspector
  - Save Inspector
- Card/relic names should use translations as the primary label, with ids still present for debugging.

Acceptance:

- Tests cover each tool's primary visible state in both languages.
- Existing Dev Tools unit coverage remains passing.
- No tool mutates active saves unless it already did so by design.

## Data Model Updates

### Enemy Intent Display

Current `EnemyIntentDisplayDef` stores `label: String`.

Change to a localization-aware field:

```gdscript
@export var label_key: String = ""
```

Validation should require the key and verify it exists in both locale files.

The resolver should return the translated label or a localized unknown fallback.

### Shared Label Keys

Add shared keys for stable vocabulary:

- `ui.common.*`
- `ui.main_menu.*`
- `ui.map.*`
- `ui.combat.*`
- `ui.reward.*`
- `ui.event.*`
- `ui.shop.*`
- `ui.summary.*`
- `ui.debug.*`
- `ui.dev_tools.*`
- `status.*.name`
- `status.*.desc`
- `intent.*.label`
- `card_type.*`
- `rarity.*`
- `relic_tier.*`
- `node_type.*`
- `target.*`
- `phase.*`
- `bool.true`
- `bool.false`

Implementation may add more specific keys inside these groups, but it should not replace the grouping scheme with unrelated key families.

### Visual Metadata

Existing visual alt labels may stay as debug metadata if not displayed. If any alt or tooltip text becomes visible, it must move to translation keys.

## Testing Strategy

### Catalog Validation

Extend catalog validation to:

- Load both `zh_CN.po` and `en.po`.
- Verify all content localization keys exist in both locales.
- Verify new UI-critical resource keys, such as intent `label_key`, exist in both locales.
- Report missing locale files or missing keys clearly.

### Unit Tests

Add or update tests for:

- Locale service default and switching.
- Text formatting helpers.
- Card and relic display names.
- Status display names.
- Enemy intent labels and targets.
- Representative screen text generation in `zh_CN` and `en`.
- Dev Tools summary formatting that localizes labels while preserving ids.

### Smoke Tests

Add smoke coverage for:

- Main Menu default Chinese.
- Main Menu language toggle to English.
- Map, Combat, Rewards, Event, Shop, and Summary in both locales using existing scene setup helpers or added test setup helpers.
- Debug Overlay and Dev Tools in both locales.

Existing gameplay smoke tests should remain focused on behavior and should not become brittle screenshot tests.

### Visual Verification

For near-demo UI polish, manual or scripted checks should verify:

- 1280x720 layout has no overlapping text.
- Chinese text fits in buttons, labels, panels, cards, detail panels, and tool rows.
- English text fits after toggling language.
- Disabled and selected states are visually distinct.
- Ink-and-jade theme reads as cohesive across main-flow and debug screens.

## Review Gates

After implementation, run two review stages.

### Stage 1: Spec Compliance Review

Verify:

- Every required screen is covered.
- `zh_CN` is default.
- `en.po` exists and is registered.
- The `中 / EN` toggle exists and updates visible UI.
- All planned localization key groups exist.
- Enemy intent labels are localization-aware.
- Screen-specific acceptance criteria are met.
- Debug Overlay and Dev Tools are included.
- No gameplay behavior changed outside the planned UI/i18n surface.

Do not proceed to Stage 2 if any spec requirement is missing.

### Stage 2: Code Quality Review

Verify:

- GDScript variables and functions are typed where consistent with existing code.
- Signal connections are clear and not duplicated on refresh.
- Node names used by tests remain stable or tests are intentionally updated.
- Resource loading is simple and validated.
- Translation keys are stable and grouped.
- Shared helpers remove real duplication without becoming a large framework.
- Changes are surgical and avoid unrelated refactoring.
- Visual style additions are focused and not asset sprawl.

Classify all found issues as Critical, Important, or Minor.

## Implementation Constraints

- Work must happen in a dedicated worktree under `.worktrees/`.
- Use a `codex/` branch.
- Keep changes screen-scoped after the shared foundation lands.
- Prefer small helper APIs over broad inheritance.
- Preserve existing gameplay tests and routing behavior.
- Use project-owned or license-safe assets only.
- Keep Chinese and English translation files in UTF-8.

## Verification Criteria

The phase is complete when:

- Chinese is the default UI on launch.
- The main menu language toggle works.
- Main-flow and debug screens have Chinese and English coverage.
- No visible hardcoded English remains in Chinese mode except technical ids/debug values and the `EN` toggle label.
- The UI has a cohesive ink-and-jade near-demo treatment across all planned screens.
- Local Godot checks pass.
- Stage 1 and Stage 2 reviews pass.
