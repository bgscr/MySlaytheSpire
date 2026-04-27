# Reward Claim Loop Design

Date: 2026-04-27

## Goal

Build the first complete post-combat reward claim loop: after winning combat, the player can inspect each reward item, choose to claim or skip it, then continue to save progress and advance the map.

This stage turns reward generation into playable run progression without locking future reward rules into the UI.

## Current Baseline

The project already has the core pieces:

- `RewardGenerator` can generate card rewards, gold rewards, and relic rewards.
- `CombatScreen` routes to `RewardScreen` when `CombatSession` reaches `PHASE_WON`.
- `RewardScreen` currently only shows a label and a continue button.
- `RewardScreen._unlock_next_node(run)` marks the current map node visited, unlocks the next node, or marks the run completed.
- `RunState` already persists `gold`, `deck_ids`, `relic_ids`, `map_nodes`, `current_node_id`, `completed`, and `failed`.
- `SaveService` already round-trips deck, relics, gold, and map progress.

The missing piece is a reward package that can be generated for the current node, shown to the player, selectively applied to `RunState`, then saved when the player continues.

## Product Rules

All reward items are optional choices. This is intentional because future events, relics, ascension rules, or character mechanics may make taking a reward undesirable.

This stage uses these node rules:

| Node type | Card reward | Gold reward | Relic reward |
| --- | --- | --- | --- |
| `combat` | 3-card choice, skippable | normal gold, skippable | none |
| `elite` | 3-card choice with better rarity weights, skippable | elite gold, skippable | 50% chance for uncommon relic, skippable |
| `boss` | 3-card choice preferring rare cards, skippable | boss gold, skippable | guaranteed rare relic, skippable |

Card choices:

- Normal combat rarity weights: common 75, uncommon 20, rare 5.
- Elite rarity weights: common 45, uncommon 40, rare 15.
- Boss card reward prefers rare cards. If the current character has fewer than 3 rare cards, fill from uncommon and then common until there are up to 3 choices.
- Choices must be unique.
- Choices are constrained to the current character card pool.

Relics:

- Elite relic chance is 50%.
- Elite relic tier is `uncommon`.
- Boss relic tier is `rare`.
- If a requested relic tier has no available relic, omit that relic item from the reward package instead of showing an empty reward.

Gold:

- Use the existing tiered gold bounds from `RewardGenerator`: normal 8-14, elite 18-28, boss 40-60.

## Design Decision

Use a focused reward strategy layer, not UI-owned reward rules.

Add a `RewardResolver` responsible for producing the complete reward package for the current node. `RewardScreen` consumes that package, tracks item claim state, applies chosen rewards to `RunState`, and advances the run only when the player explicitly continues.

Why not put rules in `RewardScreen`:

- The UI would mix node rules, rarity weights, RNG context, map progression, and run mutation.
- Future rule changes would require UI edits.

Why not build a full resource-driven reward table now:

- The content set is still small.
- A complete table system would add schema, validation, migration, and authoring work before there is enough variation to justify it.
- A resolver class gives a stable replacement point for a table-driven system later.

The resolver is the extension point. Later features can replace or decorate it for event rewards, relic-modified rewards, node-specific reward bans, or character-specific reward rules without changing the reward screen state machine.

## Architecture

### New File: `scripts/reward/reward_resolver.gd`

Responsibility:

- Read the current run and current map node.
- Generate a deterministic reward package for that node.
- Use `RewardGenerator` for the underlying card, gold, and relic draws.
- Apply node-type strategy:
  - combat: card + gold
  - elite: card + gold + 50% relic chance
  - boss: rare-preferred card + gold + guaranteed rare relic
- Omit empty reward items.

Proposed public API:

```gdscript
class_name RewardResolver
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func resolve(catalog: ContentCatalog, run: RunState) -> Array[Dictionary]:
```

Reward item shape:

```gdscript
{
	"id": "card:node_0",
	"type": "card_choice",
	"card_ids": ["sword.strike", "sword.guard", "sword.flash_cut"],
}
```

```gdscript
{
	"id": "gold:node_0",
	"type": "gold",
	"amount": 12,
}
```

```gdscript
{
	"id": "relic:node_0",
	"type": "relic",
	"relic_id": "moonwell_seed",
	"tier": "uncommon",
}
```

The `id` is deterministic and local to the current node. It supports UI state tracking and future analytics without becoming a save schema yet.

### Existing File: `scripts/reward/reward_generator.gd`

Extend this existing low-level generator with targeted helpers:

- Generate card rewards from rarity weights.
- Generate rare-preferred boss card rewards.
- Optionally pick a relic only when the resolver asks for one.

`RewardGenerator` remains a random draw helper. `RewardResolver` decides which rewards exist.

### Existing File: `scripts/ui/reward_screen.gd`

Responsibility:

- Build a simple reward list UI from resolver output.
- For each reward item, show available actions:
  - Card choice: one button per card plus a skip button.
  - Gold: claim button plus skip button.
  - Relic: claim button plus skip button.
- Track item state as `available`, `claimed`, or `skipped`.
- Disable continue until every reward item has been claimed or skipped.
- On continue:
  - Mark the current map node visited.
  - Unlock the next node or mark the run completed.
  - Save the run once.
  - Route to map or summary.

Reward application:

- Claiming a card appends the selected card id to `run.deck_ids`.
- Claiming gold adds the amount to `run.gold`.
- Claiming a relic appends the relic id to `run.relic_ids`.
- Skipping an item does not mutate `RunState`.
- Once an item is claimed or skipped, its buttons are disabled.

### No Pending Reward Save Schema In This Stage

The chosen save rule is: save once when the player presses continue.

If the player closes the game on the reward screen before continuing, partial reward choices are not persisted. The next loaded run returns to the previous saved state. This avoids adding pending reward data to `RunState` before the game has a broader save/resume policy for in-progress scenes.

## Data Flow

```text
CombatSession wins
  -> CombatScreen routes to RewardScreen
  -> RewardScreen loads default catalog
  -> RewardResolver.resolve(catalog, current_run)
  -> RewardScreen renders reward items
  -> Player claims or skips each item
  -> RewardScreen mutates current RunState for claimed items only
  -> Continue button becomes enabled
  -> RewardScreen marks map progress
  -> SaveService.save_run(current_run)
  -> route to MapScreen or RunSummaryScreen
```

## Extensibility Path

The resolver boundary is intentionally narrow.

Future extensions can happen behind `RewardResolver.resolve(...)`:

- Event nodes can pass a different context or use a different resolver.
- Relics can decorate the reward package before it reaches the UI.
- Certain nodes can suppress gold, cards, or relics.
- Ascension or difficulty rules can adjust rarity weights.
- A future resource-driven reward table can replace the hard-coded strategy while keeping the screen contract unchanged.

If pending reward resume becomes important later, add a `RunState.pending_reward` structure that stores the generated package and item states. The current reward item shape is already serializable dictionaries, so that migration should not require rewriting the UI.

## Testing Strategy

Add focused unit tests for `RewardResolver`:

- Combat nodes generate card choice and gold only.
- Elite nodes generate card choice, gold, and deterministic 50% relic outcomes.
- Boss nodes generate card choice, gold, and guaranteed rare relic.
- Boss card rewards prefer rare cards and fill from lower rarities when rare count is below 3.
- Missing current node returns an empty package.
- Empty relic pools omit relic reward items.

Extend reward generator tests:

- Weighted card rewards are deterministic for the same seed and context.
- Weighted card rewards stay within the current character pool.
- Boss rare-preferred reward uses rare cards first and still returns up to 3 unique choices.

Add reward screen smoke tests:

- Reward screen creates reward item buttons for a combat reward package.
- Continue starts disabled.
- Claiming one card mutates `run.deck_ids` once and resolves the card item.
- Skipping gold leaves `run.gold` unchanged and resolves the gold item.
- Continue saves the run and unlocks the next map node only after all items are resolved.
- Relic claim appends to `run.relic_ids` when a relic item is present.

Run full verification:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd
```

Run import check:

```powershell
& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit
```

## Review Gates

Stage 1: Spec Compliance Review

- Confirm reward generation rules match node type:
  - combat: card + gold only
  - elite: card + gold + 50% uncommon relic chance
  - boss: rare-preferred card + gold + guaranteed rare relic
- Confirm all reward items are skippable.
- Confirm continue is gated until all items are claimed or skipped.
- Confirm saving and map advancement happen once on continue.
- Confirm no pending reward save schema was added in this stage.

Stage 2: Code Quality Review

- Check reward rules live outside `RewardScreen`.
- Check UI state is easy to extend with more reward item types.
- Check reward application is idempotent per item.
- Check deterministic RNG contexts do not make duplicate reward choices.
- Check tests cover unit behavior and smoke-level scene flow.

## Acceptance Criteria

- Winning combat leads to a reward screen with generated rewards for the current node type.
- Combat rewards include card choice and gold, both skippable.
- Elite rewards include card choice, gold, and a deterministic 50% chance to show an uncommon relic, all skippable.
- Boss rewards include rare-preferred card choice, boss gold, and a guaranteed rare relic, all skippable.
- Claiming a card adds exactly one selected card to `RunState.deck_ids`.
- Claiming gold adds exactly the displayed amount to `RunState.gold`.
- Claiming a relic adds exactly one relic id to `RunState.relic_ids`.
- Skipping any item leaves the relevant run field unchanged.
- Continue stays disabled until all reward items are claimed or skipped.
- Pressing continue saves once, marks the current node visited, unlocks the next node or completes the run, and routes correctly.
- Existing saves remain compatible.
- Godot tests pass.
- Godot import check exits 0.
