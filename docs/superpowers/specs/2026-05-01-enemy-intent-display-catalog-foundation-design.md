# Enemy Intent Display Catalog Foundation Design

Date: 2026-05-01

## Goal

Make enemy intent previews readable and data-backed while preserving the current enemy intent execution path.

The current combat screen exposes raw intent strings such as `attack_5`, `block_6`, `apply_status_poison_2_player`, and `self_status_sword_focus_1`. Those strings are useful for a compact prototype, but they are hard to read in combat and are a weak foundation for future intent icons, tooltips, localization, and richer enemy UI.

This pass introduces structured display data for existing intents without changing combat rules.

## Current Baseline

The project already has:

- `EnemyDef.intent_sequence: Array[String]`, loaded from enemy `.tres` resources.
- `CombatSession.get_enemy_intent(enemy_index)`, which returns the current raw intent string.
- `CombatSession._execute_enemy_intent()`, which executes those raw strings.
- `CombatScreen._refresh_enemies()`, which renders enemies as buttons and includes the raw intent in button text.
- `CombatPresentationIntentCueResolver`, which parses intent strings after enemy turns to emit presentation polish cues.
- Default enemies using these intent families:
  - `attack_<amount>`
  - `block_<amount>`
  - `apply_status_<status_id>_<amount>_player`
  - `self_status_<status_id>_<amount>`

The current gap is display: intent information is technically present but not player-readable.

## Confirmed Direction

Use a data-resource display catalog as the next migration slice toward a long-term structured enemy intent catalog.

Long term, enemy intents should become structured data used by combat execution, UI previews, DevTools, localization, and presentation. This pass should not take the full migration yet. Instead:

1. Keep `EnemyDef.intent_sequence` as strings.
2. Keep `CombatSession` execution unchanged.
3. Add data-backed display definitions for current intent categories and statuses.
4. Add a resolver that converts current strings into typed display results.
5. Render enemy intent rows using stable child controls instead of raw button text.

## Approaches Considered

### Recommended Long-Term Destination: Enemy Intent Definition Catalog

The eventual architecture should replace opaque strings with structured intent entries. That would let combat execution and UI share a single typed representation.

This is the right destination, but it is too broad for the next small feature because it would touch enemy resources, combat execution, tests, DevTools assumptions, and possibly save/debug flows.

### Chosen Next Slice: Intent Display Resource Catalog

Add a display-resource catalog and resolver for existing strings. This gives the player a readable UI now and establishes the data shape needed for future migration.

This is the best near-term step because it improves combat clarity while keeping the gameplay path stable.

### Rejected: Button Text Formatting Only

A helper could convert raw strings into text inside `CombatScreen`, but that would leave display semantics embedded in UI code and would be harder to reuse in DevTools, tooltips, and later structured intent migration.

## Scope

Included:

- Add an `EnemyIntentDisplayDef` resource class for intent display metadata.
- Add default display resources for attack, block, poison, broken stance, sword focus, and unknown fallback.
- Load intent display resources through `ContentCatalog`.
- Add validation for required display fields.
- Add an `EnemyIntentDisplayResolver` that parses current raw intent strings into typed display results.
- Render a structured enemy intent row under each enemy entry in `CombatScreen`.
- Preserve targetability for enemy entries.
- Add tests for parsing, catalog coverage, UI row structure, and unchanged enemy behavior.
- Update README progress and Next Plans after acceptance.

Excluded:

- No migration of `EnemyDef.intent_sequence` to structured resources.
- No changes to `CombatSession._execute_enemy_intent()`.
- No new enemy behavior, combat effects, status rules, or AI.
- No final intent icon texture pack.
- No animation, tooltip system, enemy art, or layout overhaul.
- No save, reward, event, shop, map, or release-system changes.
- No changes to card presentation cue data.

## Data Model

Add `scripts/data/enemy_intent_display_def.gd`:

```gdscript
class_name EnemyIntentDisplayDef
extends Resource

@export var id: String = ""
@export_enum("attack", "block", "apply_status", "self_status", "unknown") var intent_kind: String = "unknown"
@export var icon_key: String = ""
@export var label: String = ""
@export var color: Color = Color.WHITE
@export var show_amount: bool = true
@export var show_target: bool = true
```

The first pass can use plain display labels instead of localization keys because the existing combat UI is already mostly direct text. A later localization pass can add label keys or migrate `label` to `label_key`.

Default resource ids:

- `attack`
- `block`
- `status.poison`
- `status.broken_stance`
- `status.sword_focus`
- `unknown`

The `icon_key` is real data even though the first renderer may show it as text. Future texture mapping can use the same key.

## Resolver Behavior

Add `scripts/presentation/enemy_intent_display_resolver.gd`.

The resolver should expose a simple API such as:

```gdscript
func resolve(intent: String, catalog: ContentCatalog) -> Dictionary
```

The returned display dictionary should include:

- `raw_intent`
- `kind`
- `display_id`
- `icon_key`
- `label`
- `amount`
- `status_id`
- `target`
- `color`
- `show_amount`
- `show_target`
- `is_known`

Parsing rules:

- `attack_5` resolves to `attack`, amount `5`, target `player`, display id `attack`.
- `block_6` resolves to `block`, amount `6`, target `self`, display id `block`.
- `apply_status_poison_2_player` resolves to `apply_status`, status `poison`, amount `2`, target `player`, display id `status.poison`.
- `apply_status_broken_stance_2_player` resolves to `apply_status`, status `broken_stance`, amount `2`, target `player`, display id `status.broken_stance`.
- `self_status_sword_focus_1` resolves to `self_status`, status `sword_focus`, amount `1`, target `self`, display id `status.sword_focus`.
- Unknown or malformed strings resolve to the `unknown` display definition and do not crash.

The parser should handle status ids containing underscores by using the same final-amount splitting style already used by combat and presentation intent parsing.

## UI Design

`CombatScreen` should stop presenting the raw intent string as the primary enemy intent display.

Each enemy entry should contain stable child nodes:

```text
EnemyButton_0
  EnemySummaryLabel_0
  EnemyIntentRow_0
    IntentIcon_0
    IntentLabel_0
    IntentAmount_0
    IntentTarget_0
```

The first pass can build these controls programmatically inside `combat_screen.gd`, matching the existing scene style.

`EnemySummaryLabel_<index>` displays enemy id, HP, block, and status text. `EnemyIntentRow_<index>` displays the parsed intent. The icon node may be a `Label` with a short stable marker derived from `icon_key`, plus color from `EnemyIntentDisplayDef.color`. It should not require final texture assets.

The enemy entry must remain clickable for card targeting. If a plain `Button` cannot cleanly contain the child row in Godot, use a small button-like container with a stable click target, but preserve the existing `EnemyButton_<index>` node name for tests and presentation target binding.

## Data Flow

```text
EnemyDef.intent_sequence string
  -> CombatSession.get_enemy_intent(enemy_index)
  -> EnemyIntentDisplayResolver.resolve(intent, catalog)
  -> EnemyIntentDisplayDef + parsed amount / target / status
  -> CombatScreen EnemyIntentRow controls
```

Combat execution remains:

```text
EnemyDef.intent_sequence string
  -> CombatSession.get_enemy_intent(enemy_index)
  -> CombatSession._execute_enemy_intent()
```

This separation keeps the first pass display-only.

## Content Catalog

`ContentCatalog` should load default intent display resources from `resources/intents/*.tres`.

It should expose a lookup such as:

```gdscript
func get_enemy_intent_display(display_id: String) -> EnemyIntentDisplayDef
```

Validation should report:

- missing display id;
- missing `intent_kind`;
- missing `icon_key`;
- missing `label`;
- missing `unknown` fallback;
- default enemy intents that cannot resolve to a known display definition, except test-only malformed fixtures.

## Testing Strategy

Unit tests:

- `EnemyIntentDisplayDef` stores display fields.
- `ContentCatalog.load_default()` loads intent display definitions.
- Catalog validation passes with the default intent display catalog.
- Resolver parses attack, block, apply-status, and self-status intents.
- Resolver handles status ids with underscores.
- Resolver falls back to `unknown` for malformed strings.
- Every default enemy intent resolves to a known display definition.

Combat UI smoke tests:

- A sandbox combat with `training_puppet` creates `EnemyIntentRow_0`, `IntentIcon_0`, `IntentLabel_0`, and `IntentAmount_0` for an attack intent.
- A sandbox combat with `stone_grove_guardian` shows a block intent row.
- A sandbox combat with `plague_jade_imp` shows a poison-to-player intent row.
- Enemy targeting still works through the enemy entry.
- Ending the player turn still executes enemy attack, block, and status intents exactly as before.

Boundary tests:

- `CombatSession`, `CombatEngine`, `EffectExecutor`, rewards, events, shops, saves, and map code do not import `EnemyIntentDisplayDef` or `EnemyIntentDisplayResolver`.
- Existing presentation intent cue tests continue to pass.

## Documentation

Update README after acceptance:

- Add a Phase 2 progress bullet for enemy intent display catalog foundation.
- Update Next Plans so intent icons are no longer listed as open first-pass presentation scope, while card art, richer combat backgrounds, and formal audio mixing remain.

No changelog entry is required unless this ships with a release branch.

## Review Requirements

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify enemy intent execution still uses existing strings.
- Verify every default enemy intent has a readable data-backed display.
- Verify malformed intent strings resolve safely to unknown display.
- Verify `CombatScreen` renders stable intent row nodes.
- Verify enemy entries remain targetable.
- Verify no combat rules, save data, rewards, events, shops, map flow, or release tooling changed.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Check the resolver is small, typed where practical, and does not duplicate combat execution logic beyond parsing needed for display.
- Check display resources are minimal and consistent.
- Check UI changes are scoped to enemy entry rendering and stable node names.
- Check tests are focused and do not depend on incidental control ordering beyond named nodes.
- Check no unrelated refactors or formatting churn were included.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

## Acceptance Criteria

- Enemy attack, block, player-status, and self-status intents render as readable structured UI rows.
- Default enemy intents resolve through `EnemyIntentDisplayDef` resources.
- Raw intent strings are no longer the primary combat-screen intent display.
- Current raw string intent sequences remain valid.
- Enemy turn behavior is unchanged.
- Enemy target selection remains functional.
- Unknown or malformed display intents do not crash the UI.
- No core combat execution class imports display resources or the display resolver.
- Shared Godot checks pass.
- Godot import check exits 0.

## Future Work

- Migrate `EnemyDef.intent_sequence` from raw strings to structured intent entries.
- Reuse the typed display resolver in DevTools enemy panels.
- Add localized intent labels.
- Map `icon_key` to real texture assets.
- Add intent tooltips and preview details.
- Merge presentation cue routing with the eventual structured intent data.
