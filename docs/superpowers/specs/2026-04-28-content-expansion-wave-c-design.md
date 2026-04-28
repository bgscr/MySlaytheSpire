# Content Expansion Wave C Design

Date: 2026-04-28

## Goal

Expand the playable chapter after Wave 2 with a larger event and relic pool, event rewards, enemy status intents, and clearer compact status presentation while keeping the current run loop stable.

Wave C should make events and enemies feel less like numeric placeholders. It should add meaningful run rewards to event options, let enemies use the existing status runtime, and make combat status text readable enough for development play without starting the high-presentation pass.

## Current Baseline

The project currently has:

- Complete map flow through combat, event, shop, reward, summary, save, and continue.
- 2 characters with 20 card-pool cards each.
- 40 registered cards, 12 enemies, 12 relics, and 6 events.
- `CombatStatusRuntime` rules for `poison`, `sword_focus`, and `broken_stance`.
- `EventDef` and `EventOptionDef` resources where options can require HP/gold and mutate HP/gold.
- `EventRunner` that applies event options directly to `RunState`.
- `RelicRuntime` that handles combat-started, turn-started, and combat-won relic effects.
- Enemy intents represented by strings such as `attack_7` and `block_4`.
- Combat UI status text that appends raw status id counters to player and enemy labels.

The main gaps are:

- Events cannot add cards, remove cards, grant relics, or offer card/relic rewards.
- Enemy intents cannot apply statuses.
- Relic pools and event pools are still small enough to repeat quickly.
- Compact status UI is mechanically useful but difficult to scan.

## Scope

Included:

- Add event option rewards for:
  - direct card grants
  - direct relic grants
  - card removal by id when the run deck contains that card
  - card reward choices generated from the existing `RewardGenerator`
  - relic reward choices generated from the existing `RewardGenerator`
- Add a lightweight pending event reward claim state to `RunState`, saved through `SaveService`, so an event can route to the reward screen before map progression.
- Extend `RewardResolver` and `RewardScreen` enough to consume pending event reward packages without creating a separate event reward screen.
- Add enemy status intents using the existing string intent model:
  - `apply_status_<status_id>_<amount>_player`
  - `self_status_<status_id>_<amount>`
  - keep `attack_N` and `block_N` unchanged.
- Route enemy status intent behavior through the same effect/status execution path used by cards where possible.
- Add 6 events, bringing default events to 12.
- Add 8 relics, bringing default relics to 20.
- Add 4 enemies that exercise status intents, bringing default enemies to 16.
- Improve compact combat status text using status display names and stable ordering from `CombatStatusRuntime.STATUS_METADATA`.
- Register all new resources through `ContentCatalog`.
- Add Chinese localization keys for new event, enemy, relic, and status display text.
- Add unit and smoke tests for event rewards, status intents, pool counts, localization, save/load behavior, and existing flow stability.
- Update README and this wave implementation plan after acceptance.

Excluded:

- No full `StatusDef` resource database.
- No rich tooltip system, icons, animation, audio, VFX, particles, camera work, or generated art.
- No deck mutation UI outside event reward/removal flows.
- No persistent event flags or event history tracking.
- No shop, map generator, or combat reward redesign.
- No enemy AI planner beyond deterministic intent strings.
- No enemy-targeting relic triggers or per-card relic triggers.
- No release/export/CI work.

## Design Choice

Three approaches were considered:

1. Minimal content-only wave.
   - Add more events, enemies, and relics using only existing fields.
   - Lowest risk, but it would not address the README goals for event rewards or enemy status intents.

2. Conservative systems wave.
   - Extend current resource shapes just enough for event rewards and enemy status intents.
   - Reuse `RewardGenerator`, `RewardScreen`, `EffectExecutor`, and `CombatStatusRuntime`.
   - This is the recommended path because it gives new gameplay surface without replacing working systems.

3. Framework wave.
   - Introduce full status definitions, event effect resources, enemy intent resources, richer reward routing, and presentation widgets.
   - More future-proof, but too much surface area for one wave and likely to disturb stable run flow.

Wave C should use approach 2.

## Event Reward Design

`EventOptionDef` should remain one resource per selectable option, but gain optional reward/mutation fields:

```gdscript
@export var grant_card_ids: Array[String] = []
@export var grant_relic_ids: Array[String] = []
@export var remove_card_id: String = ""
@export var card_reward_count: int = 0
@export var relic_reward_tier: String = ""
@export var reward_context: String = ""
```

Existing fields keep their current meaning:

- `min_hp`
- `min_gold`
- `hp_delta`
- `gold_delta`

New behavior:

- `grant_card_ids` appends known catalog cards to `run.deck_ids`.
- `grant_relic_ids` appends known catalog relics to `run.relic_ids` if the relic is not already owned.
- `remove_card_id` removes one matching card from `run.deck_ids`; the option is unavailable if the run does not contain that card.
- `card_reward_count > 0` creates a pending card reward package using `RewardGenerator.generate_card_reward()`.
- `relic_reward_tier` creates a pending relic reward package using `RewardGenerator.generate_relic_reward()`.
- `reward_context` is included in deterministic RNG labels. Empty context falls back to the event id and option id.

If an event option both mutates the run and creates a pending reward package, direct mutations are applied first. The pending reward is then saved and the app routes to the reward screen. Map progression happens only after the reward screen is continued, matching combat reward behavior.

Direct grants do not route to reward screen; they save, advance the event node, and return to map.

## Pending Event Reward State

Add `RunState.current_reward_state: Dictionary = {}`.

The dictionary should be empty when no reward screen resume is needed. For Wave C it should support:

```gdscript
{
	"source": "event",
	"node_id": "N2_1",
	"event_id": "sealed_sword_tomb",
	"option_id": "claim_blade",
	"rewards": [
		{"id": "event-card:N2_1:claim_blade", "type": "card_choice", "card_ids": ["sword.heaven_cutting_arc", "sword.heart_piercer"]},
		{"id": "event-relic:N2_1:claim_blade", "type": "relic", "relic_id": "mist_vein_bracelet", "tier": "common"}
	]
}
```

This mirrors the shop state precedent:

- serialize in `RunState.to_dict()`
- load and validate in `SaveService`
- clear when the reward flow finishes
- accept legacy saves without the field

The reward screen should prefer `run.current_reward_state` when present and valid. Combat reward generation remains the fallback for combat nodes.

## Reward Screen Integration

`RewardResolver` should gain an event-pending path, not a separate class:

- If `run.current_reward_state.get("source", "") == "event"` and `node_id == run.current_node_id`, return those reward dictionaries.
- Existing combat/elite/boss reward generation remains unchanged.
- Event reward items should use the same claim/skip mechanics as combat rewards.
- Continuing after event rewards should clear `current_reward_state`, advance the current map node through `RunProgression`, save, and route to map or summary.

This avoids a second reward screen and keeps one claim loop for all node rewards.

## Enemy Status Intent Design

Enemy intents stay as deterministic strings, but the parser should accept four forms:

- `attack_N`
- `block_N`
- `apply_status_<status_id>_<amount>_player`
- `self_status_<status_id>_<amount>`

Examples:

- `apply_status_poison_2_player`
- `apply_status_broken_stance_1_player`
- `self_status_sword_focus_1`

Execution rules:

- Enemy status intents happen after turn-start poison checks and before advancing the intent index.
- `apply_status_*_player` applies a generic status stack to the player.
- `self_status_*` applies a generic status stack to the acting enemy.
- Status ids must be non-empty and amount must be positive.
- Unknown or malformed intents should push an error and still advance the enemy intent index, matching current unknown intent behavior.

The implementation may either construct temporary `EffectDef` objects and use `EffectExecutor.execute_in_state()` or use a small helper that mirrors generic `apply_status` behavior. Gameplay status rules must remain in `CombatStatusRuntime`.

## Status Presentation Design

Keep combat UI simple, but replace raw status id text with stable compact labels.

`CombatStatusRuntime` should expose:

```gdscript
func status_display_text(combatant: CombatantState) -> String
```

Rules:

- Only positive status layers are shown.
- Known statuses use `STATUS_METADATA[status_id].name_key`.
- Unknown statuses fall back to their raw id.
- Display order is stable:
  - known statuses in metadata order
  - unknown statuses alphabetically after known statuses
- Format is compact: `Poison 3 | Sword Focus 2`.

`status_text()` may remain for tests/backward compatibility, but UI should use `status_display_text()`.

This is intentionally not the high-presentation pass. No icons, colors, or tooltips are required.

## Content Expansion

Add 6 events:

| id | purpose | notable options |
| --- | --- | --- |
| `forgotten_armory` | choose a direct card or pay HP for a stronger card reward | direct sword/alchemy card grants; card reward choice |
| `jade_debt_collector` | gold pressure event | pay gold to avoid HP loss; remove a basic card; leave |
| `moonlit_ferry` | risk reward | pay HP for relic choice; leave safely |
| `spirit_compact` | relic temptation | gain direct relic for HP cost; refuse |
| `tea_house_rumor` | small heal/info event | heal; pay gold for card reward choice |
| `withered_master` | deck refinement | remove a listed basic card; gain gold with HP cost |

Add 8 relics:

| id | tier | trigger_event | intent |
| --- | --- | --- | --- |
| `paper_lantern_charm` | common | `combat_started` | block 3 player |
| `mothwing_sachet` | common | `turn_started` | heal 1 player |
| `rusted_meridian_ring` | common | `combat_won` | gain_gold 4 player |
| `silk_thread_prayer` | uncommon | `combat_started` | apply_status 1 sword_focus player |
| `black_pill_vial` | uncommon | `combat_started` | apply_status 1 poison player; gain_energy 1 player |
| `cloudstep_sandals` | uncommon | `turn_started` | block 3 player |
| `immortal_peach_core` | rare | `combat_started` | heal 6 player |
| `void_tiger_eye` | rare | `combat_won` | gain_gold 12 player |

Relic effects remain player-targeted because enemy-targeted relic payloads are explicitly future work.

Add 4 enemies:

| id | tier | max_hp | intents | reward_tier | gold bounds |
| --- | --- | --- | --- | --- | --- |
| `plague_jade_imp` | normal | 24 | `apply_status_poison_2_player`, `attack_5`, `block_4` | normal | 10-16 |
| `iron_oath_duelist` | normal | 34 | `self_status_sword_focus_1`, `attack_7`, `attack_9` | normal | 11-18 |
| `miasma_cauldron_elder` | elite | 62 | `apply_status_poison_3_player`, `block_12`, `attack_12` | elite | 24-34 |
| `boss_sword_ghost` | boss | 125 | `self_status_sword_focus_2`, `apply_status_broken_stance_2_player`, `attack_20` | boss | 55-75 |

Default composition after Wave C:

- 7 normal enemies.
- 5 elite enemies.
- 4 boss enemies.
- 20 relics.
- 12 events.

No new cards are required in Wave C. Event card grants should use existing catalog cards so the wave focuses on event and enemy systems.

## Content Registration

Add all new resources to:

- `ContentCatalog.DEFAULT_ENEMY_PATHS`
- `ContentCatalog.DEFAULT_RELIC_PATHS`
- `ContentCatalog.DEFAULT_EVENT_PATHS`
- `localization/zh_CN.po`

Do not change character card pools or starting decks in this wave.

## Save and Compatibility

`SaveService` must:

- Save `current_reward_state`.
- Load valid `current_reward_state` dictionaries.
- Reject malformed reward state reward lists.
- Accept legacy saves without reward state.

No version bump is required because the new field is optional and legacy saves are accepted.

## Testing Strategy

Add unit tests for:

- Event option direct card grants.
- Event option direct relic grants and duplicate relic rejection.
- Event option card removal availability and mutation.
- Event option card reward package creation with deterministic items.
- Event option relic reward package creation with deterministic item.
- Pending event reward state serialization and legacy load compatibility.
- Reward resolver preferring valid pending event reward state.
- Reward screen claiming pending event rewards and advancing the event node.
- Enemy status intents applying poison/broken stance to the player.
- Enemy self status intents applying sword focus to the acting enemy.
- Malformed status intents advancing intent index without mutation.
- `CombatStatusRuntime.status_display_text()` stable ordering and known-name display.
- Default catalog counts: 40 cards, 16 enemies, 20 relics, 12 events.
- Event pool usability with non-empty options and valid reward references.
- Relic pool tier composition and populated reward tiers.

Run before acceptance:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

## Review Gates

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify event options support direct card grants, direct relic grants, one-card removal, generated card reward choices, and generated relic reward choices.
- Verify pending event rewards save, load, resume, clear, and route through the reward screen.
- Verify combat rewards still work unchanged.
- Verify enemy status intents apply statuses through generic status stacking and do not duplicate gameplay status rules.
- Verify compact status UI uses `status_display_text()` and remains simple.
- Verify all new enemies, relics, and events exist, are registered, localized, and load through `ContentCatalog`.
- Verify default counts: 40 cards, 16 enemies, 20 relics, 12 events.
- Verify no `StatusDef`, rich presentation system, event history system, new shop/map system, or release infrastructure was added.

Stage 2: Code Quality Review

- Check GDScript typing for new fields, functions, and dictionaries.
- Check event reward state validation is narrow and testable.
- Check reward screen branching remains readable and does not duplicate claim logic.
- Check enemy intent parsing is isolated and deterministic.
- Check status rules remain centralized in `CombatStatusRuntime`.
- Check resource formatting and catalog ordering remain consistent.
- Check localization keys are non-empty and not duplicated incorrectly.
- Classify all findings as Critical, Important, or Minor.

## Future Work

- Full `StatusDef` resources once active status rules exceed the lightweight runtime.
- Rich status UI with icons, localized descriptions, and tooltips.
- Event history flags and one-time event consequences.
- Event rewards that add rare boss relics or character-specific scripted cards.
- Enemy AI intent resources with explicit action arrays.
- Enemy-targeting relic event payloads and card-play relic triggers.
- High-presentation combat feedback for poison ticks, status application, and relic triggers.

## Acceptance Criteria

- Event options can grant cards, grant relics, remove a card, or create pending card/relic reward choices.
- Pending event rewards route through the existing reward screen and advance the event node only after completion.
- Save/load preserves pending event reward state and accepts legacy saves.
- Enemy status intents can apply statuses to the player or acting enemy.
- Status gameplay rules remain in `CombatStatusRuntime`.
- Combat UI shows compact known status names rather than raw id-only text.
- Default catalog loads 40 cards, 16 enemies, 20 relics, and 12 events.
- New events, enemies, and relics have required localization keys.
- Catalog validation returns no errors.
- Reward, event, shop, save, and combat smoke flows pass.
- Godot tests pass.
- Godot import check exits 0.
