# Event Node Foundation Design

Date: 2026-04-27

## Goal

Build the first playable event-node flow for the run map. When the player selects an `event` node, the game should route to an event screen, resolve one deterministic event from data resources, let the player choose one available option, apply that option to `RunState`, save progress, and return to the map or summary.

This stage makes event nodes real without implementing shops, pending event resume, complex event state, or a full scripting language for events.

## Current Baseline

The project already has several pieces that make a small event foundation possible:

- `MapGenerator` already creates `event` and `shop` node types.
- `MapScreen` currently routes non-combat nodes to `RewardScreen`.
- `RewardScreen` owns a private `_unlock_next_node(run)` helper that marks the current node visited, unlocks the next node, or completes the run.
- `RunState` already persists hp, gold, deck ids, relic ids, map nodes, current node id, completion, and failure.
- `SaveService` already saves and loads the map and run fields needed by event outcomes.
- `ContentCatalog` already loads and validates resource-driven cards, characters, enemies, relics, and localization keys.

The missing pieces are event resources, event catalog registration, deterministic event selection, option resolution, and a scene that applies one selected option before advancing the run.

## Product Rules

Event nodes provide uncertain run-shaping outcomes. In this first wave, events affect only run-level state:

- Current HP.
- Gold.
- Map progress.

Event options may be conditionally disabled by simple run requirements:

- Minimum current HP.
- Minimum gold.

Option effects are applied once when the option is selected. Selecting an option immediately advances the map node and saves the run. There is no separate event reward screen in this wave.

Current HP must stay between 1 and `max_hp`; event HP loss cannot kill the player in this stage. Gold must never go below 0. Disabled options remain visible so the player can understand why they are unavailable.

## Initial Event Pool

Create three data-defined events. Names and text use localization keys in `localization/zh_CN.po`.

1. `wandering_physician`
   - Option `pay_for_treatment`: requires at least 25 gold, changes gold by -25 and HP by +12.
   - Option `decline`: no effect.
2. `spirit_toll`
   - Option `offer_vitality`: requires at least 7 current HP, changes HP by -6 and gold by +35.
   - Option `walk_away`: no effect.
3. `quiet_shrine`
   - Option `meditate`: changes HP by +6.
   - Option `take_incense_coin`: changes gold by +12.

These events intentionally use only HP and gold. Card, relic, removal, upgrade, and transformation events are follow-up work once the basic event loop is proven.

## Architecture

### New Resource: `scripts/data/event_option_def.gd`

`EventOptionDef` is a small Resource for one selectable event option.

Fields:

```gdscript
class_name EventOptionDef
extends Resource

@export var id: String = ""
@export var label_key: String = ""
@export var description_key: String = ""
@export var min_hp: int = 0
@export var min_gold: int = 0
@export var hp_delta: int = 0
@export var gold_delta: int = 0
```

`hp_delta` and `gold_delta` are signed. Runtime clamps HP and gold after applying them.

### New Resource: `scripts/data/event_def.gd`

`EventDef` describes an event and its options.

Fields:

```gdscript
class_name EventDef
extends Resource

const EventOptionDef := preload("res://scripts/data/event_option_def.gd")

@export var id: String = ""
@export var title_key: String = ""
@export var body_key: String = ""
@export var event_weight: int = 1
@export var options: Array[EventOptionDef] = []
```

The event resource stays data-only. It does not apply effects or know about scenes.

### ContentCatalog Extension

Extend `ContentCatalog` with event support:

- Add `DEFAULT_EVENT_PATHS`.
- Add `events_by_id`.
- Load event resources in `load_default()` and `load_from_paths(...)`.
- Add `get_event(event_id) -> EventDef`.
- Add `get_events() -> Array[EventDef]`.
- Validate event ids, title/body localization keys, option ids, option label keys, and non-empty option arrays.

Keep existing card, enemy, relic, and character behavior compatible. Existing tests should only require small updates to the `load_from_paths(...)` signature if the function receives event paths directly.

### EventResolver

Add `scripts/event/event_resolver.gd`.

Responsibility:

- Read the current `RunState`.
- Confirm the current map node exists and has node type `event`.
- Pick one event deterministically from catalog events by `event_weight`.
- Use `RngService.new(run.seed_value).fork("event:%s" % node.id)`.
- Return the selected `EventDef`, or `null` if no event can be resolved.

The resolver does not apply option effects and does not route scenes.

### EventRunner

Add `scripts/event/event_runner.gd`.

Responsibility:

- Check whether an `EventOptionDef` is selectable for the current run.
- Apply exactly one selected option to `RunState`.
- Clamp `run.current_hp` to `1..run.max_hp`.
- Clamp `run.gold` to `>= 0`.

Public API:

```gdscript
func is_option_available(run: RunState, option: EventOptionDef) -> bool
func unavailable_reason(run: RunState, option: EventOptionDef) -> String
func apply_option(run: RunState, option: EventOptionDef) -> bool
```

`apply_option(...)` returns `false` if the option is unavailable. UI must not mutate the run directly.

### Shared Run Progression

Extract the node-advance behavior from `RewardScreen` into `scripts/run/run_progression.gd`.

Public API:

```gdscript
class_name RunProgression
extends RefCounted

func advance_current_node(run: RunState) -> bool
```

Behavior:

- Find `run.current_node_id` in `run.map_nodes`.
- Mark it visited.
- Unlock the next node if one exists.
- Mark `run.completed = true` if the current node is the final node.
- Return `false` if the current node is missing.

Update `RewardScreen` to call this helper so reward, event, and future shop scenes share the same map progression rule.

### EventScreen

Add `scenes/event/EventScreen.tscn` and `scripts/ui/event_screen.gd`.

Responsibility:

- Load the default catalog.
- Resolve the current event through `EventResolver`.
- Render title, body, option descriptions, and one button per option.
- Disable unavailable option buttons and show a short reason.
- On option click:
  - Guard against double-clicks.
  - Call `EventRunner.apply_option(...)`.
  - Call `RunProgression.advance_current_node(...)`.
  - Save the run once through `SaveService`.
  - Route to `SceneRouter.MAP`, or `SceneRouter.SUMMARY` if the run is completed.

If no event is available, show a fallback message and a continue button that only advances the node. This prevents a broken event catalog from soft-locking the run, while catalog validation and tests still treat missing event content as an error.

### Routing

Extend `SceneRouter`:

```gdscript
const EVENT := "res://scenes/event/EventScreen.tscn"
```

Update `MapScreen._enter_node(...)`:

- `combat`, `elite`, and `boss` route to combat.
- `event` routes to event.
- `shop` remains out of scope and should keep using the existing fallback behavior until the shop wave. The preferred fallback for this wave is to route `shop` to `RewardScreen` only because it already safely advances unsupported nodes with no rewards.

## Save Behavior

No pending event schema is added in this wave.

The save boundary is option selection:

```text
Event option selected
  -> apply option to RunState
  -> advance current map node
  -> save RunState once
  -> route to map or summary
```

If the player closes the game while reading an event before choosing an option, no event progress is persisted. Reloading returns to the last saved map state.

## Data Flow

```text
MapScreen enters event node
  -> SceneRouter.EVENT
  -> EventScreen loads ContentCatalog
  -> EventResolver resolves event by seed and node id
  -> EventScreen renders options
  -> Player selects one available option
  -> EventRunner applies hp/gold deltas
  -> RunProgression advances current node
  -> SaveService saves run
  -> SceneRouter routes to map or summary
```

## Testing Strategy

Add focused unit tests:

- `EventDef` and `EventOptionDef` expose the required exported fields.
- `ContentCatalog` loads three default events.
- Catalog validation fails on missing event localization keys or event resources with no options.
- `EventResolver` returns deterministic events for the same seed and node id.
- `EventResolver` returns `null` for non-event nodes or missing current nodes.
- `EventRunner` applies HP and gold deltas once, clamps HP and gold, and rejects unavailable options.
- `RunProgression` advances current nodes and returns `false` for missing nodes.

Add smoke tests:

- An `event` map node routes to `EventScreen`.
- Available event option click mutates `RunState`, saves, marks the event node visited, unlocks the next node, and routes to map.
- Unavailable event option is disabled and does not mutate the run.
- Final event node routes to summary after selection.
- Reward screen still advances and saves through the shared `RunProgression` helper.

Run full verification:

```powershell
rtk proxy C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/testing/test_runner.gd
```

Run import check:

```powershell
rtk proxy C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit
```

## Review Gates

Stage 1: Spec Compliance Review

- Confirm `event` nodes route to `EventScreen`.
- Confirm events are loaded from `.tres` resources through `ContentCatalog`.
- Confirm event selection is deterministic by run seed and node id.
- Confirm options can be disabled by minimum HP or minimum gold.
- Confirm option effects mutate only HP and gold in this wave.
- Confirm current node advancement and save happen after option selection.
- Confirm no pending event save schema is added.
- Confirm shop implementation is not included.

Stage 2: Code Quality Review

- Check event rules live in resolver/runner code, not UI callbacks.
- Check GDScript functions and variables are typed where practical.
- Check `RunProgression` removes duplicated node advancement logic.
- Check event resources are data-only and easy to expand.
- Check scene node names are stable for smoke tests.
- Check no new branches or worktrees were created.
- Classify found issues as Critical, Important, or Minor.

## Acceptance Criteria

- Event resources exist and are registered in `ContentCatalog`.
- `ContentCatalog.validate()` reports no errors for default events.
- Selecting an event node from the map enters an event screen.
- The event screen displays one deterministic event for the current run seed and node id.
- Event options are shown as buttons.
- Options with unmet HP or gold requirements are disabled.
- Selecting an available option applies exactly that option's HP and gold deltas.
- HP is clamped between 1 and max HP.
- Gold is clamped to 0 or higher.
- Selecting an option saves the run once, marks the event node visited, unlocks the next node or completes the run, and routes correctly.
- Reward screen still advances map progress correctly after the shared progression helper is introduced.
- No shop scene or shop item model is added.
- No pending event save schema is added.
- Godot tests pass.
- Godot import check exits 0.

## Follow-Up Work

The next waves can build on this foundation:

- Shop item model and shop scene flow.
- Event card rewards, relic rewards, card removal, upgrade, and transformation.
- Event state persistence for multi-step events.
- Event history tracking to avoid repeating the same event too often.
- Rich event presentation, art, animation, and audio.
