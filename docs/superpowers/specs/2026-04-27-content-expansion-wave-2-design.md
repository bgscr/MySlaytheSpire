# Content Expansion Wave 2 Design

Date: 2026-04-27

## Goal

Expand the first playable chapter from a working loop into a denser run by adding more cards, relics, enemies, and events while giving the existing `poison`, `sword_focus`, and `broken_stance` statuses real combat behavior.

This wave should make both starting characters feel more distinct without introducing a heavy status database, new shop systems, new save schema, animation, audio, or release infrastructure.

## Current Baseline

The project currently has:

- 2 characters: `sword` and `alchemy`.
- 30 cards total: 15 sword cards and 15 alchemy cards.
- 9 enemies: 4 normal, 3 elite, and 2 boss.
- 6 relics: 3 common, 2 uncommon, and 1 rare.
- 3 events.
- Complete map flow through combat, event, shop, reward, summary, save, and continue.
- Existing `apply_status` effects that stack arbitrary status ids on `CombatantState.statuses`.
- Existing status ids already present in content: `poison`, `sword_focus`, `broken_stance`, and `elixir_guard`.

The main gap is that most status ids are currently only counters. They can be applied, displayed only indirectly in tests, and saved inside combat state only while a combat is active, but they do not yet affect combat rules.

## Scope

Included:

- Add a lightweight `CombatStatusRuntime` focused on status hooks and future migration to a data-driven `StatusDef` resource.
- Implement runtime behavior for:
  - `poison`
  - `sword_focus`
  - `broken_stance`
- Add 5 new sword cards, bringing sword to 20 cards.
- Add 5 new alchemy cards, bringing alchemy to 20 cards.
- Add 3 new enemies, bringing default enemies to 12.
- Add 6 new relics, bringing default relics to 12.
- Add 3 new events, bringing default events to 6.
- Register all new resources through `ContentCatalog`.
- Add Chinese localization keys for all new card, enemy, relic, and event text.
- Add tests for status runtime behavior, content counts, expected ids, localization validation, reward/encounter/event pool usability, and full scene smoke stability.
- Update README and this wave's implementation plan after acceptance.

Excluded:

- Full `StatusDef` resource database.
- Status icons, rich tooltip UI, animation, audio, VFX, particles, or camera work.
- New card target rules.
- New save schema.
- New shop, reward, map, or event runtime systems beyond adding event resources with current `EventOptionDef` fields.
- Full event state tracking across runs.
- Content wave C: larger event pool and larger relic pool beyond the counts above.
- CI/CD, export, release draft, or Steam adapter work.

## Status Runtime Design

Add `scripts/combat/combat_status_runtime.gd`.

This runtime is the only place where status ids get gameplay rules. The combat session should call it at fixed hooks, and the effect executor should continue to treat `apply_status` as a generic stack operation.

Required public API:

```gdscript
class_name CombatStatusRuntime
extends RefCounted

func modify_damage(state: CombatState, source: CombatantState, target: CombatantState, base_amount: int) -> int
func after_damage(state: CombatState, source: CombatantState, target: CombatantState, final_amount: int, hp_lost: int) -> void
func on_turn_started(combatant: CombatantState, state: CombatState) -> void
func status_text(combatant: CombatantState) -> String
```

The exact implementation can include private helpers, but combat code should interact through these hooks.

### Damage Hook

Normal `damage` effects should run through `CombatStatusRuntime.modify_damage()` before HP/block damage is applied.

Rules:

- Negative damage remains clamped to zero.
- `sword_focus` only applies when `source == state.player`.
- `sword_focus` adds its current layer count to outgoing damage.
- `broken_stance` on the target adds its current layer count to incoming damage.
- These modifiers only apply to explicit `damage` effects, not poison life loss.
- After a damage effect that used either modifier, `after_damage()` reduces only the used `sword_focus` source status and/or `broken_stance` target status by 1 layer and removes the key at 0.

This gives existing sword cards a direct identity:

- `sword_focus` is burst setup.
- `broken_stance` is enemy vulnerability.

### Turn Hook

`CombatSession` should call `on_turn_started()`:

- For the player at the start of each player turn.
- For each living enemy before that enemy acts.

Rules:

- `poison` causes direct HP loss equal to its current layer count.
- Poison life loss ignores block.
- After poison triggers, poison decays by 1 layer and is removed at 0.
- If poison defeats an enemy before its intent, that enemy does not act.
- If poison defeats the player at turn start, the combat is lost.
- If poison defeats the final enemy, combat is won.

This timing is simple, deterministic, and easy to test. It also avoids adding a separate end-of-turn event queue in this wave.

### Status Metadata

This wave should not create `StatusDef` resources, but the runtime should keep metadata in a shape that can migrate later:

```gdscript
const STATUS_METADATA := {
	"poison": {
		"name_key": "status.poison.name",
		"description_key": "status.poison.desc",
	},
	"sword_focus": {
		"name_key": "status.sword_focus.name",
		"description_key": "status.sword_focus.desc",
	},
	"broken_stance": {
		"name_key": "status.broken_stance.name",
		"description_key": "status.broken_stance.desc",
	},
}
```

`status_text()` should produce a compact debug/UI string such as `poison:3 sword_focus:2`. Rich localized status UI is future work.

### Future StatusDef Migration Point

If status count grows past 10 active gameplay statuses, migrate metadata and simple rule configuration into resources:

- `resources/statuses/*.tres`
- `scripts/data/status_def.gd`
- `ContentCatalog.DEFAULT_STATUS_PATHS`

The hook names above should remain stable so future data-driven statuses can be introduced without rewriting `CombatSession`.

## Combat Integration

`EffectExecutor` currently handles `damage` by calling `recipient.take_damage(amount)`.

For Wave 2, damage effects should delegate status-aware damage calculation to `CombatStatusRuntime` when a `CombatState` is available. A simple approach:

- Add `var status_runtime := CombatStatusRuntime.new()` to `EffectExecutor`.
- In `execute_in_state()`, for `damage`:
  - Resolve recipient.
  - Compute modified damage with `status_runtime.modify_damage(state, source, recipient, amount)`.
  - Apply `recipient.take_damage(modified_amount)`.
  - Call `status_runtime.after_damage(state, source, recipient, modified_amount, hp_lost)`.
- Keep plain `execute()` compatible for unit tests by using unmodified damage when no `CombatState` exists.

`CombatSession` should own a `CombatStatusRuntime` instance or use `engine.executor.status_runtime`. It must call turn-start hooks at deterministic points and then re-check terminal phase.

No save migration is required because combat state is not currently persisted mid-combat.

## Content Expansion

### Sword Cards

Add 5 sword cards:

| id | file | type | rarity | cost | effects |
| --- | --- | --- | --- | --- | --- |
| `sword.wind_splitting_step` | `wind_splitting_step.tres` | attack | common | 1 | damage 6 enemy; apply_status 1 broken_stance enemy |
| `sword.clear_mind_guard` | `clear_mind_guard.tres` | skill | common | 1 | block 7 player; apply_status 1 sword_focus player |
| `sword.thread_the_needle` | `thread_the_needle.tres` | attack | uncommon | 1 | damage 8 enemy; draw_card 1 player |
| `sword.echoing_sword_heart` | `echoing_sword_heart.tres` | skill | uncommon | 1 | apply_status 2 sword_focus player; draw_card 1 player |
| `sword.heaven_cutting_arc` | `heaven_cutting_arc.tres` | attack | rare | 2 | damage 18 enemy; apply_status 2 broken_stance enemy |

Design intent:

- Common sword cards make the new status rules visible early.
- Uncommon cards support tempo and setup.
- Rare sword card gives a satisfying payoff without adding a new effect type.

### Alchemy Cards

Add 5 alchemy cards:

| id | file | type | rarity | cost | effects |
| --- | --- | --- | --- | --- | --- |
| `alchemy.coiling_miasma` | `coiling_miasma.tres` | skill | common | 1 | apply_status 3 poison enemy |
| `alchemy.needle_rain` | `needle_rain.tres` | attack | common | 1 | damage 4 enemy; apply_status 2 poison enemy |
| `alchemy.purifying_brew` | `purifying_brew.tres` | skill | uncommon | 1 | heal 4 player; draw_card 1 player |
| `alchemy.cauldron_overflow` | `cauldron_overflow.tres` | skill | uncommon | 2 | apply_status 5 poison enemy; block 5 player |
| `alchemy.golden_core_detox` | `golden_core_detox.tres` | skill | rare | 1 | gain_energy 1 player; draw_card 2 player; heal 3 player |

Design intent:

- Alchemy becomes the poison-and-sustain character.
- No new poison-specific effect is needed; existing `apply_status` becomes meaningful through runtime rules.

### Enemies

Add 3 enemies:

| id | tier | max_hp | intents | reward_tier | gold bounds |
| --- | --- | --- | --- | --- | --- |
| `scarlet_mantis_acolyte` | normal | 28 | `attack_7`, `block_4`, `attack_5` | normal | 9-15 |
| `jade_armor_sentinel` | elite | 54 | `block_10`, `attack_11`, `attack_8` | elite | 20-30 |
| `boss_void_tiger` | boss | 110 | `attack_14`, `block_12`, `attack_18` | boss | 45-65 |

Default composition after Wave 2:

- 5 normal enemies.
- 4 elite enemies.
- 3 boss enemies.

Enemy intent strings remain limited to current supported `attack_N` and `block_N` forms.

### Relics

Add 6 relics:

| id | tier | trigger_event | effects |
| --- | --- | --- | --- |
| `mist_vein_bracelet` | common | `combat_started` | apply_status 1 sword_focus player |
| `verdant_antidote_gourd` | common | `combat_started` | heal 3 player |
| `copper_mantis_hook` | common | `combat_won` | gain_gold 6 player |
| `white_tiger_tally` | uncommon | `turn_started` | block 2 player |
| `nine_smoke_censer` | uncommon | `combat_started` | block 5 player |
| `starforged_meridian` | rare | `combat_started` | gain_energy 1 player; apply_status 2 sword_focus player |

Important constraint:

Relic effects currently target only the player because `RelicRuntime` executes relic effects with player as both source and target. This wave must not pretend relics can apply status to enemies. Enemy-targeting relics belong to a future relic-event payload wave.

Default composition after Wave 2:

- 6 common relics.
- 4 uncommon relics.
- 2 rare relics.

### Events

Add 3 events using only current `EventOptionDef` fields:

| id | theme | options |
| --- | --- | --- |
| `sealed_sword_tomb` | sword cultivation shrine | pay HP for gold; meditate for HP loss and no gold; leave |
| `alchemist_market` | risky medicine vendor | pay gold to heal; taste free medicine for HP gain and gold loss 0; leave |
| `spirit_beast_tracks` | wilderness choice | chase for gold with HP cost; hide for small heal; leave |

Events should stay simple because event state, deck mutation, relic rewards, and card rewards from events are not supported yet.

## Content Registration

Add all new resources to:

- `ContentCatalog.DEFAULT_CARD_PATHS`
- `ContentCatalog.DEFAULT_ENEMY_PATHS`
- `ContentCatalog.DEFAULT_RELIC_PATHS`
- `ContentCatalog.DEFAULT_EVENT_PATHS`
- character `card_pool_ids`
- `localization/zh_CN.po`

Starting decks must not change.

## UI Behavior

Combat UI may append compact status text to the player and enemy labels, using `CombatStatusRuntime.status_text()`.

This wave does not require icons, tooltips, colors, animations, or localized status rendering.

## Testing Strategy

Add unit tests for:

- `CombatStatusRuntime` damage modifiers.
- `poison` turn-start direct HP loss and decay.
- `poison` killing an enemy before its intent.
- `sword_focus` increasing outgoing player damage and decaying.
- `broken_stance` increasing incoming damage and decaying.
- `EffectExecutor` still stacking arbitrary statuses through `apply_status`.
- Default catalog loading 40 cards, 12 enemies, 12 relics, and 6 events.
- Sword and alchemy each having exactly 20 character-pool cards.
- New expected card ids are present and character-isolated.
- New enemy tier composition is 5 normal / 4 elite / 3 boss.
- New relic tier composition is 6 common / 4 uncommon / 2 rare.
- Event pool includes all 6 event ids and validates no empty-option events.
- Reward generator still draws character-scoped cards and populated relic tiers.
- Encounter generator works with expanded normal, elite, and boss pools.

Add smoke coverage only if scene flow changes are required. This design should not require new scenes.

Run before acceptance:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

## Review Gates

After implementation, run the project-required two-stage review.

Stage 1: Spec Compliance Review

- Verify `CombatStatusRuntime` is the only place with gameplay status rules.
- Verify poison, sword focus, and broken stance behaviors match this spec.
- Verify all new resources exist, are registered, localized, and load through `ContentCatalog`.
- Verify default counts: 40 cards, 12 enemies, 12 relics, 6 events.
- Verify sword/alchemy have 20 cards each and starting decks are unchanged.
- Verify no full `StatusDef`, new save schema, presentation, shop, reward, or map systems were added.
- Verify C-scope future event/relic expansion is documented but not implemented.

Stage 2: Code Quality Review

- Check GDScript typing and clear helper boundaries.
- Check status hooks are narrow and deterministic.
- Check status rules are not duplicated in UI, resources, or session code.
- Check resource formatting and catalog ordering remain consistent.
- Check localization keys are non-empty and not duplicated incorrectly.
- Classify any issues as Critical, Important, or Minor.

## Future Work

Record C-scope work for later:

- Larger event pool beyond 6 events.
- Larger relic pool beyond 12 relics.
- Event rewards that can add cards, remove cards, grant relics, or apply persistent run flags.
- Enemy intents that can apply statuses.
- Relic event payloads that can target enemies or react to card events.
- Full `StatusDef` resources with localized names, descriptions, icon keys, stack display rules, and hook configuration.
- Status icons and rich combat UI.
- High-presentation combat feedback for poison ticks, sword focus bursts, and broken stance hits.

## Acceptance Criteria

- `poison` deals direct HP loss at turn start, ignores block, decays by 1, and can win or lose combat.
- `sword_focus` increases player outgoing damage by its layer count and decays after modifying a damage effect.
- `broken_stance` increases target incoming damage by its layer count and decays after modifying a damage effect.
- Status gameplay rules live in `CombatStatusRuntime`.
- `apply_status` remains a generic stack operation.
- Default catalog loads 40 cards, 12 enemies, 12 relics, and 6 events.
- Sword and alchemy each have exactly 20 cards in their character pools.
- Starting decks are unchanged.
- New cards, enemies, relics, and events have required localization keys.
- Catalog validation returns no errors.
- Reward, encounter, event, shop, save, and combat smoke flows still pass.
- Godot tests pass.
- Godot import check exits 0.
