# Godot Foundation Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working Godot 4.6.2 foundation: a Windows-oriented 2D card roguelike shell that can start a seeded run, enter map/combat/reward/summary scenes, save and continue, and run local logic plus smoke tests.

**Architecture:** This plan creates a Godot project with strict boundaries between run state, combat rules, Resource definitions, scene presentation, save/platform services, and developer tools. It implements a minimal vertical slice with sample content, while preserving the extension points required by the approved design spec for later content, high-presentation, Steam, CI, and release plans.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resource definitions, gettext `.po` localization, custom lightweight headless test runner, Windows local export prepared but not automated.

---

## Scope Check

The approved design spec covers a full commercial-direction game prototype: content, combat, map, events, shop, localization, save, platform abstraction, dev tools, tests, presentation, and future publishing. That is too broad for one safe implementation plan.

This plan covers **Phase 1 only**:

- Create the Godot project structure.
- Add core Resource schemas and runtime state classes.
- Add deterministic seed support.
- Add a minimal run loop: menu -> new run -> map -> combat -> reward -> next node -> boss/summary.
- Add save/continue for the current run.
- Add simple sample UI and presentation hooks.
- Add basic developer overlay.
- Add local tests and smoke checks.

Separate follow-up plans should cover:

- Phase 2 content expansion: 2 characters, each 20 cards, 15-20 relics, 10+ enemies, 2 bosses, complete event pool.
- Phase 3 high-presentation pass: art pipeline, generated assets, animation, particles, camera shake, combat timing, audio polish.
- Phase 4 tooling and quality pass: card browser, enemy sandbox, event tester, reward pool inspector, save inspector.
- Phase 5 release readiness: Windows export automation, GitHub Actions, release draft, changelog, versioning, Steamworks adapter.

## File Structure

Create this structure during Phase 1:

```text
.
├── .gitignore
├── project.godot
├── README.md
├── docs/superpowers/specs/2026-04-25-xianxia-card-roguelike-design.md
├── docs/superpowers/plans/2026-04-25-godot-foundation-vertical-slice.md
├── localization/zh_CN.po
├── resources/
│   ├── cards/sword/strike_sword.tres
│   ├── cards/alchemy/toxic_pill.tres
│   ├── characters/sword_cultivator.tres
│   ├── characters/alchemy_cultivator.tres
│   ├── enemies/training_puppet.tres
│   ├── enemies/forest_bandit.tres
│   ├── enemies/boss_heart_demon.tres
│   └── relics/jade_talisman.tres
├── scenes/
│   ├── app/App.tscn
│   ├── menu/MainMenu.tscn
│   ├── map/MapScreen.tscn
│   ├── combat/CombatScreen.tscn
│   ├── reward/RewardScreen.tscn
│   ├── summary/RunSummaryScreen.tscn
│   └── dev/DebugOverlay.tscn
├── scripts/
│   ├── app/app.gd
│   ├── app/scene_router.gd
│   ├── app/game.gd
│   ├── core/rng_service.gd
│   ├── core/game_event.gd
│   ├── core/event_bus.gd
│   ├── data/card_def.gd
│   ├── data/character_def.gd
│   ├── data/enemy_def.gd
│   ├── data/effect_def.gd
│   ├── data/relic_def.gd
│   ├── run/run_state.gd
│   ├── run/map_node_state.gd
│   ├── run/map_generator.gd
│   ├── combat/combatant_state.gd
│   ├── combat/combat_state.gd
│   ├── combat/effect_executor.gd
│   ├── combat/combat_engine.gd
│   ├── reward/reward_state.gd
│   ├── save/save_service.gd
│   ├── platform/platform_service.gd
│   ├── platform/local_platform_service.gd
│   ├── presentation/presentation_event_router.gd
│   ├── ui/main_menu.gd
│   ├── ui/map_screen.gd
│   ├── ui/combat_screen.gd
│   ├── ui/reward_screen.gd
│   ├── ui/run_summary_screen.gd
│   ├── ui/debug_overlay.gd
│   └── testing/test_runner.gd
└── tests/
    ├── unit/test_rng_service.gd
    ├── unit/test_resource_schemas.gd
    ├── unit/test_map_generator.gd
    ├── unit/test_combat_engine.gd
    ├── unit/test_save_service.gd
    └── smoke/test_scene_flow.gd
```

## Command Conventions

Use an environment variable so Windows paths with spaces do not leak into every step:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64.exe"
& $env:GODOT4 --version
```

Expected version output starts with:

```text
4.6.2.stable
```

If Godot is installed elsewhere, set `$env:GODOT4` to that executable path before running the commands below.

## Task 1: Create Godot Project Skeleton

**Files:**

- Create: `.gitignore`
- Create: `README.md`
- Create: `project.godot`
- Create: `scenes/app/App.tscn`
- Create: `scripts/app/app.gd`
- Create: `scripts/app/scene_router.gd`
- Create: `scripts/app/game.gd`

- [x] **Step 1: Write the project metadata and ignore rules**

Create `.gitignore`:

```gitignore
.godot/
.import/
export/
*.translation
*.tmp
*.bak
*.log
```

Create `README.md`:

```markdown
# MySlaytheSpire

东方玄幻 2D 卡牌构筑肉鸽 Windows 客户端。

## Engine

- Godot 4.6.2-stable
- GDScript
- Windows first, Win11 primary

## Local Commands

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```
```

- [x] **Step 2: Create the minimal Godot project file**

Create `project.godot`:

```ini
; Engine configuration file.
; Edit through the Godot editor when possible.
config_version=5

[application]
config/name="MySlaytheSpire"
run/main_scene="res://scenes/app/App.tscn"
config/features=PackedStringArray("4.6")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[internationalization]
locale/translations=PackedStringArray("res://localization/zh_CN.po")

[rendering]
renderer/rendering_method="forward_plus"
```

- [x] **Step 3: Create the root app scene**

Create `scenes/app/App.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/app/app.gd" id="1_app"]

[node name="App" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_app")
```

- [x] **Step 4: Create the root app scripts**

Create `scripts/app/scene_router.gd`:

```gdscript
class_name SceneRouter
extends Node

const MAIN_MENU := "res://scenes/menu/MainMenu.tscn"
const MAP := "res://scenes/map/MapScreen.tscn"
const COMBAT := "res://scenes/combat/CombatScreen.tscn"
const REWARD := "res://scenes/reward/RewardScreen.tscn"
const SUMMARY := "res://scenes/summary/RunSummaryScreen.tscn"

var host: Control
var current_scene: Node

func setup(scene_host: Control) -> void:
	host = scene_host

func go_to(scene_path: String) -> Node:
	if current_scene:
		current_scene.queue_free()
	var packed := load(scene_path) as PackedScene
	current_scene = packed.instantiate()
	host.add_child(current_scene)
	return current_scene
```

Create `scripts/app/game.gd`:

```gdscript
class_name Game
extends Node

var router := SceneRouter.new()
var current_run
var platform_service
var save_service
```

Create `scripts/app/app.gd`:

```gdscript
extends Control

var game := Game.new()

func _ready() -> void:
	add_child(game)
	game.router.setup(self)
	game.router.go_to(SceneRouter.MAIN_MENU)
```

- [x] **Step 5: Run Godot import check**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected:

```text
Godot Engine v4.6.2.stable...
```

No script parse errors should appear.

- [x] **Step 6: Commit**

```powershell
git add .gitignore README.md project.godot scenes/app/App.tscn scripts/app
git commit -m "chore: create Godot project skeleton"
```

## Task 2: Add Lightweight Test Runner and Deterministic RNG

**Files:**

- Create: `scripts/testing/test_runner.gd`
- Create: `scripts/core/rng_service.gd`
- Create: `tests/unit/test_rng_service.gd`

- [x] **Step 1: Write the failing RNG tests**

Create `tests/unit/test_rng_service.gd`:

```gdscript
extends RefCounted

const RngService := preload("res://scripts/core/rng_service.gd")

func test_same_seed_produces_same_sequence() -> void:
	var a := RngService.new(12345)
	var b := RngService.new(12345)
	assert(a.next_int(1, 100) == b.next_int(1, 100))
	assert(a.next_int(1, 100) == b.next_int(1, 100))
	assert(a.pick(["a", "b", "c"]) == b.pick(["a", "b", "c"]))

func test_fork_is_deterministic_by_label() -> void:
	var root_a := RngService.new(777)
	var root_b := RngService.new(777)
	var map_a := root_a.fork("map")
	var map_b := root_b.fork("map")
	assert(map_a.next_int(0, 999) == map_b.next_int(0, 999))
```

- [x] **Step 2: Add the test runner**

Create `scripts/testing/test_runner.gd`:

```gdscript
extends SceneTree

const TEST_FILES := [
	"res://tests/unit/test_rng_service.gd",
	"res://tests/unit/test_resource_schemas.gd",
	"res://tests/unit/test_map_generator.gd",
	"res://tests/unit/test_combat_engine.gd",
	"res://tests/unit/test_save_service.gd",
	"res://tests/smoke/test_scene_flow.gd",
]

var failures := 0

func _init() -> void:
	for file in TEST_FILES:
		if ResourceLoader.exists(file):
			_run_file(file)
	if failures > 0:
		print("TESTS FAILED: %s" % failures)
		quit(1)
	else:
		print("TESTS PASSED")
		quit(0)

func _run_file(path: String) -> void:
	var script := load(path)
	var instance = script.new()
	for method in instance.get_method_list():
		var method_name := String(method.name)
		if method_name.begins_with("test_"):
			_run_method(instance, method_name, path)

func _run_method(instance, method_name: String, path: String) -> void:
	print("RUN %s:%s" % [path, method_name])
	var result = instance.call(method_name)
	if result is GDScriptFunctionState:
		result = await result.completed
```

- [x] **Step 3: Run tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
SCRIPT ERROR: Parse Error: Could not preload resource file "res://scripts/core/rng_service.gd".
```

- [x] **Step 4: Implement RNG service**

Create `scripts/core/rng_service.gd`:

```gdscript
class_name RngService
extends RefCounted

var seed_value: int
var _rng := RandomNumberGenerator.new()

func _init(initial_seed: int = 1) -> void:
	seed_value = initial_seed
	_rng.seed = initial_seed

func next_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

func next_float() -> float:
	return _rng.randf()

func pick(items: Array):
	assert(items.size() > 0, "Cannot pick from an empty array.")
	return items[next_int(0, items.size() - 1)]

func shuffle_copy(items: Array) -> Array:
	var copy := items.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := next_int(0, i)
		var tmp = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy

func fork(label: String) -> RngService:
	var context := "%s:%s" % [seed_value, label]
	return RngService.new(hash(context))
```

- [x] **Step 5: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
RUN res://tests/unit/test_rng_service.gd:test_same_seed_produces_same_sequence
RUN res://tests/unit/test_rng_service.gd:test_fork_is_deterministic_by_label
TESTS PASSED
```

- [x] **Step 6: Commit**

```powershell
git add scripts/testing/test_runner.gd scripts/core/rng_service.gd tests/unit/test_rng_service.gd
git commit -m "test: add local Godot test runner and seeded rng"
```

## Task 3: Add Core Events and Data Resource Schemas

**Files:**

- Create: `scripts/core/game_event.gd`
- Create: `scripts/core/event_bus.gd`
- Create: `scripts/data/effect_def.gd`
- Create: `scripts/data/card_def.gd`
- Create: `scripts/data/character_def.gd`
- Create: `scripts/data/enemy_def.gd`
- Create: `scripts/data/relic_def.gd`
- Create: `tests/unit/test_resource_schemas.gd`

- [x] **Step 1: Write schema tests**

Create `tests/unit/test_resource_schemas.gd`:

```gdscript
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")

func test_card_def_stores_effects_and_localization_keys() -> void:
	var effect := EffectDef.new()
	effect.effect_type = "damage"
	effect.amount = 6
	var card := CardDef.new()
	card.id = "sword.strike"
	card.name_key = "card.sword.strike.name"
	card.description_key = "card.sword.strike.desc"
	card.cost = 1
	card.effects = [effect]
	assert(card.id == "sword.strike")
	assert(card.effects[0].amount == 6)

func test_character_def_has_starting_deck() -> void:
	var character := CharacterDef.new()
	character.id = "sword"
	character.max_hp = 72
	character.starting_deck_ids = ["sword.strike", "sword.guard"]
	assert(character.starting_deck_ids.size() == 2)

func test_enemy_def_has_intent_sequence() -> void:
	var enemy := EnemyDef.new()
	enemy.id = "training_puppet"
	enemy.max_hp = 24
	enemy.intent_sequence = ["attack_5", "block_4"]
	assert(enemy.intent_sequence[0] == "attack_5")
```

- [x] **Step 2: Run schema tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
Could not preload resource file "res://scripts/data/card_def.gd"
```

- [x] **Step 3: Implement core event classes**

Create `scripts/core/game_event.gd`:

```gdscript
class_name GameEvent
extends RefCounted

var type: String
var payload: Dictionary

func _init(event_type: String = "", event_payload: Dictionary = {}) -> void:
	type = event_type
	payload = event_payload
```

Create `scripts/core/event_bus.gd`:

```gdscript
class_name EventBus
extends Node

signal event_emitted(event: GameEvent)

func emit(event_type: String, payload: Dictionary = {}) -> void:
	event_emitted.emit(GameEvent.new(event_type, payload))
```

- [x] **Step 4: Implement Resource schemas**

Create `scripts/data/effect_def.gd`:

```gdscript
class_name EffectDef
extends Resource

@export var effect_type: String = ""
@export var amount: int = 0
@export var status_id: String = ""
@export var target: String = "enemy"
```

Create `scripts/data/card_def.gd`:

```gdscript
class_name CardDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var cost: int = 1
@export_enum("attack", "skill", "power") var card_type: String = "attack"
@export_enum("common", "uncommon", "rare") var rarity: String = "common"
@export var tags: Array[String] = []
@export var effects: Array[EffectDef] = []
```

Create `scripts/data/character_def.gd`:

```gdscript
class_name CharacterDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var max_hp: int = 70
@export var starting_deck_ids: Array[String] = []
@export var card_pool_ids: Array[String] = []
```

Create `scripts/data/enemy_def.gd`:

```gdscript
class_name EnemyDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var max_hp: int = 20
@export var intent_sequence: Array[String] = []
@export var reward_tier: String = "normal"
```

Create `scripts/data/relic_def.gd`:

```gdscript
class_name RelicDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var trigger_event: String = ""
@export var effects: Array[EffectDef] = []
```

- [x] **Step 5: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
RUN res://tests/unit/test_resource_schemas.gd:test_card_def_stores_effects_and_localization_keys
RUN res://tests/unit/test_resource_schemas.gd:test_character_def_has_starting_deck
RUN res://tests/unit/test_resource_schemas.gd:test_enemy_def_has_intent_sequence
TESTS PASSED
```

- [x] **Step 6: Commit**

```powershell
git add scripts/core scripts/data tests/unit/test_resource_schemas.gd
git commit -m "feat: add core events and resource schemas"
```

## Task 4: Add Run State and Seeded Map Generation

**Files:**

- Create: `scripts/run/map_node_state.gd`
- Create: `scripts/run/run_state.gd`
- Create: `scripts/run/map_generator.gd`
- Create: `tests/unit/test_map_generator.gd`

- [x] **Step 1: Write map generation tests**

Create `tests/unit/test_map_generator.gd`:

```gdscript
extends RefCounted

const MapGenerator := preload("res://scripts/run/map_generator.gd")

func test_same_seed_generates_same_map() -> void:
	var first := MapGenerator.new().generate(1234)
	var second := MapGenerator.new().generate(1234)
	assert(first.size() == second.size())
	for i in range(first.size()):
		assert(first[i].node_type == second[i].node_type)
		assert(first[i].layer == second[i].layer)

func test_map_has_boss_at_end() -> void:
	var nodes := MapGenerator.new().generate(9)
	assert(nodes[nodes.size() - 1].node_type == "boss")
```

- [x] **Step 2: Run map tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
Could not preload resource file "res://scripts/run/map_generator.gd"
```

- [x] **Step 3: Implement map and run state classes**

Create `scripts/run/map_node_state.gd`:

```gdscript
class_name MapNodeState
extends RefCounted

var id: String
var layer: int
var node_type: String
var visited := false
var unlocked := false

func _init(node_id: String = "", node_layer: int = 0, type: String = "combat") -> void:
	id = node_id
	layer = node_layer
	node_type = type
```

Create `scripts/run/run_state.gd`:

```gdscript
class_name RunState
extends RefCounted

var version := 1
var seed_value := 1
var character_id := ""
var current_hp := 1
var max_hp := 1
var gold := 0
var deck_ids: Array[String] = []
var relic_ids: Array[String] = []
var map_nodes: Array = []
var current_node_id := ""
var completed := false
var failed := false

func to_dict() -> Dictionary:
	var node_payload := []
	for node in map_nodes:
		node_payload.append({
			"id": node.id,
			"layer": node.layer,
			"node_type": node.node_type,
			"visited": node.visited,
			"unlocked": node.unlocked,
		})
	return {
		"version": version,
		"seed_value": seed_value,
		"character_id": character_id,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck_ids": deck_ids,
		"relic_ids": relic_ids,
		"map_nodes": node_payload,
		"current_node_id": current_node_id,
		"completed": completed,
		"failed": failed,
	}
```

Create `scripts/run/map_generator.gd`:

```gdscript
class_name MapGenerator
extends RefCounted

const RngService := preload("res://scripts/core/rng_service.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")

func generate(seed_value: int) -> Array:
	var rng := RngService.new(seed_value).fork("map")
	var nodes: Array = []
	var node_types := ["combat", "combat", "event", "shop", "elite"]
	for layer in range(0, 6):
		var node_type := "combat" if layer == 0 else rng.pick(node_types)
		var node := MapNodeState.new("node_%s" % layer, layer, node_type)
		node.unlocked = layer == 0
		nodes.append(node)
	nodes.append(MapNodeState.new("boss_0", 6, "boss"))
	return nodes
```

- [x] **Step 4: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
RUN res://tests/unit/test_map_generator.gd:test_same_seed_generates_same_map
RUN res://tests/unit/test_map_generator.gd:test_map_has_boss_at_end
TESTS PASSED
```

- [x] **Step 5: Commit**

```powershell
git add scripts/run tests/unit/test_map_generator.gd
git commit -m "feat: add seeded run map generation"
```

## Task 5: Add Minimal Combat Engine

**Files:**

- Create: `scripts/combat/combatant_state.gd`
- Create: `scripts/combat/combat_state.gd`
- Create: `scripts/combat/effect_executor.gd`
- Create: `scripts/combat/combat_engine.gd`
- Create: `tests/unit/test_combat_engine.gd`

- [x] **Step 1: Write combat tests**

Create `tests/unit/test_combat_engine.gd`:

```gdscript
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const CombatEngine := preload("res://scripts/combat/combat_engine.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func test_damage_card_reduces_enemy_hp() -> void:
	var damage := EffectDef.new()
	damage.effect_type = "damage"
	damage.amount = 6
	var card := CardDef.new()
	card.id = "sword.strike"
	card.cost = 1
	card.effects = [damage]
	var player := CombatantState.new("player", 50)
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	engine.play_card(card, player, enemy)
	assert(enemy.current_hp == 14)

func test_block_prevents_damage() -> void:
	var player := CombatantState.new("player", 50)
	player.block = 4
	player.take_damage(6)
	assert(player.current_hp == 48)
	assert(player.block == 0)
```

- [x] **Step 2: Run combat tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
Could not preload resource file "res://scripts/combat/combat_engine.gd"
```

- [x] **Step 3: Implement combatant and combat state**

Create `scripts/combat/combatant_state.gd`:

```gdscript
class_name CombatantState
extends RefCounted

var id: String
var max_hp: int
var current_hp: int
var block := 0
var statuses := {}

func _init(combatant_id: String = "", hp: int = 1) -> void:
	id = combatant_id
	max_hp = hp
	current_hp = hp

func take_damage(amount: int) -> int:
	var prevented := min(block, amount)
	block -= prevented
	var remaining := amount - prevented
	current_hp = max(0, current_hp - remaining)
	return remaining

func gain_block(amount: int) -> void:
	block += amount

func is_defeated() -> bool:
	return current_hp <= 0
```

Create `scripts/combat/combat_state.gd`:

```gdscript
class_name CombatState
extends RefCounted

var turn := 1
var energy := 3
var player: CombatantState
var enemies: Array[CombatantState] = []
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhausted_pile: Array[String] = []
```

- [x] **Step 4: Implement effect execution**

Create `scripts/combat/effect_executor.gd`:

```gdscript
class_name EffectExecutor
extends RefCounted

func execute(effect: EffectDef, source: CombatantState, target: CombatantState) -> void:
	match effect.effect_type:
		"damage":
			target.take_damage(effect.amount)
		"block":
			source.gain_block(effect.amount)
		"heal":
			source.current_hp = min(source.max_hp, source.current_hp + effect.amount)
		_:
			push_error("Unknown effect type: %s" % effect.effect_type)
```

Create `scripts/combat/combat_engine.gd`:

```gdscript
class_name CombatEngine
extends RefCounted

const EffectExecutor := preload("res://scripts/combat/effect_executor.gd")

var executor := EffectExecutor.new()

func play_card(card: CardDef, source: CombatantState, target: CombatantState) -> void:
	for effect in card.effects:
		executor.execute(effect, source, target)

func end_turn(state: CombatState) -> void:
	state.turn += 1
	state.energy = 3
	state.player.block = 0
```

- [x] **Step 5: Run combat tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
RUN res://tests/unit/test_combat_engine.gd:test_damage_card_reduces_enemy_hp
RUN res://tests/unit/test_combat_engine.gd:test_block_prevents_damage
TESTS PASSED
```

- [x] **Step 6: Commit**

```powershell
git add scripts/combat tests/unit/test_combat_engine.gd
git commit -m "feat: add minimal combat engine"
```

## Task 6: Add Save Service and Local Platform Service

**Files:**

- Create: `scripts/save/save_service.gd`
- Create: `scripts/platform/platform_service.gd`
- Create: `scripts/platform/local_platform_service.gd`
- Create: `tests/unit/test_save_service.gd`

- [x] **Step 1: Write save round-trip test**

Create `tests/unit/test_save_service.gd`:

```gdscript
extends RefCounted

const SaveService := preload("res://scripts/save/save_service.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_save_round_trip_preserves_run_state() -> void:
	var run := RunState.new()
	run.seed_value = 42
	run.character_id = "sword"
	run.current_hp = 55
	run.max_hp = 72
	run.gold = 99
	run.deck_ids = ["sword.strike"]
	var service := SaveService.new("user://test_run_save.json")
	service.save_run(run)
	var loaded := service.load_run()
	assert(loaded.seed_value == 42)
	assert(loaded.character_id == "sword")
	assert(loaded.deck_ids[0] == "sword.strike")
	service.delete_save()
```

- [x] **Step 2: Run save tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
Could not preload resource file "res://scripts/save/save_service.gd"
```

- [x] **Step 3: Implement save service**

Create `scripts/save/save_service.gd`:

```gdscript
class_name SaveService
extends RefCounted

const RunState := preload("res://scripts/run/run_state.gd")

var save_path := "user://run_save.json"

func _init(path: String = "user://run_save.json") -> void:
	save_path = path

func save_run(run: RunState) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(run.to_dict()))

func load_run() -> RunState:
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return null
	var run := RunState.new()
	run.seed_value = parsed.get("seed_value", 1)
	run.character_id = parsed.get("character_id", "")
	run.current_hp = parsed.get("current_hp", 1)
	run.max_hp = parsed.get("max_hp", 1)
	run.gold = parsed.get("gold", 0)
	run.deck_ids.assign(parsed.get("deck_ids", []))
	run.relic_ids.assign(parsed.get("relic_ids", []))
	run.current_node_id = parsed.get("current_node_id", "")
	run.completed = parsed.get("completed", false)
	run.failed = parsed.get("failed", false)
	return run

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
```

- [x] **Step 4: Implement platform abstraction**

Create `scripts/platform/platform_service.gd`:

```gdscript
class_name PlatformService
extends RefCounted

func unlock_achievement(_achievement_id: String) -> void:
	pass

func set_stat(_stat_id: String, _value: int) -> void:
	pass

func get_platform_language() -> String:
	return "zh_CN"
```

Create `scripts/platform/local_platform_service.gd`:

```gdscript
class_name LocalPlatformService
extends PlatformService

var achievements := {}
var stats := {}

func unlock_achievement(achievement_id: String) -> void:
	achievements[achievement_id] = true

func set_stat(stat_id: String, value: int) -> void:
	stats[stat_id] = value
```

- [x] **Step 5: Run save tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
RUN res://tests/unit/test_save_service.gd:test_save_round_trip_preserves_run_state
TESTS PASSED
```

- [x] **Step 6: Commit**

```powershell
git add scripts/save scripts/platform tests/unit/test_save_service.gd
git commit -m "feat: add run save and local platform services"
```

## Task 7: Add Sample Content Resources and Localization

**Files:**

- Create: `localization/zh_CN.po`
- Create: `resources/cards/sword/strike_sword.tres`
- Create: `resources/cards/alchemy/toxic_pill.tres`
- Create: `resources/characters/sword_cultivator.tres`
- Create: `resources/characters/alchemy_cultivator.tres`
- Create: `resources/enemies/training_puppet.tres`
- Create: `resources/enemies/forest_bandit.tres`
- Create: `resources/enemies/boss_heart_demon.tres`
- Create: `resources/relics/jade_talisman.tres`

- [x] **Step 1: Add Chinese gettext entries**

Create `localization/zh_CN.po`:

```po
msgid ""
msgstr ""
"Project-Id-Version: MySlaytheSpire\n"
"Language: zh_CN\n"
"Content-Type: text/plain; charset=UTF-8\n"

msgid "ui.new_run"
msgstr "新局"

msgid "ui.continue"
msgstr "继续"

msgid "ui.end_turn"
msgstr "结束回合"

msgid "character.sword.name"
msgstr "剑修"

msgid "character.alchemy.name"
msgstr "丹修"

msgid "card.sword.strike.name"
msgstr "试剑"

msgid "card.sword.strike.desc"
msgstr "造成 6 点伤害。"

msgid "card.alchemy.toxic_pill.name"
msgstr "淬毒丹"

msgid "card.alchemy.toxic_pill.desc"
msgstr "造成 4 点伤害。"

msgid "enemy.training_puppet.name"
msgstr "试炼木人"

msgid "enemy.forest_bandit.name"
msgstr "山道劫修"

msgid "enemy.boss_heart_demon.name"
msgstr "心魔化身"

msgid "relic.jade_talisman.name"
msgstr "温玉护符"

msgid "relic.jade_talisman.desc"
msgstr "战斗开始时获得 3 点护体。"
```

- [x] **Step 2: Create sample `.tres` resources through the Godot editor**

Use the Godot editor to create each Resource with the script shown in its file path. Set these values:

`resources/cards/sword/strike_sword.tres`:

```text
script: res://scripts/data/card_def.gd
id: sword.strike
name_key: card.sword.strike.name
description_key: card.sword.strike.desc
cost: 1
card_type: attack
rarity: common
effects: one EffectDef with effect_type=damage, amount=6, target=enemy
```

`resources/cards/alchemy/toxic_pill.tres`:

```text
script: res://scripts/data/card_def.gd
id: alchemy.toxic_pill
name_key: card.alchemy.toxic_pill.name
description_key: card.alchemy.toxic_pill.desc
cost: 1
card_type: attack
rarity: common
effects: one EffectDef with effect_type=damage, amount=4, target=enemy
```

`resources/characters/sword_cultivator.tres`:

```text
script: res://scripts/data/character_def.gd
id: sword
name_key: character.sword.name
max_hp: 72
starting_deck_ids: sword.strike, sword.strike, sword.strike
card_pool_ids: sword.strike
```

`resources/characters/alchemy_cultivator.tres`:

```text
script: res://scripts/data/character_def.gd
id: alchemy
name_key: character.alchemy.name
max_hp: 68
starting_deck_ids: alchemy.toxic_pill, alchemy.toxic_pill, alchemy.toxic_pill
card_pool_ids: alchemy.toxic_pill
```

`resources/enemies/training_puppet.tres`:

```text
script: res://scripts/data/enemy_def.gd
id: training_puppet
name_key: enemy.training_puppet.name
max_hp: 20
intent_sequence: attack_5
reward_tier: normal
```

`resources/enemies/forest_bandit.tres`:

```text
script: res://scripts/data/enemy_def.gd
id: forest_bandit
name_key: enemy.forest_bandit.name
max_hp: 28
intent_sequence: attack_6, block_4
reward_tier: normal
```

`resources/enemies/boss_heart_demon.tres`:

```text
script: res://scripts/data/enemy_def.gd
id: boss_heart_demon
name_key: enemy.boss_heart_demon.name
max_hp: 80
intent_sequence: attack_10, block_8, attack_14
reward_tier: boss
```

`resources/relics/jade_talisman.tres`:

```text
script: res://scripts/data/relic_def.gd
id: jade_talisman
name_key: relic.jade_talisman.name
description_key: relic.jade_talisman.desc
trigger_event: combat_started
effects: one EffectDef with effect_type=block, amount=3, target=player
```

- [x] **Step 3: Verify resources load**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected:

```text
Godot Engine v4.6.2.stable...
```

No "Failed loading resource" messages should appear.

Verification note: Task 7 resources and `localization/zh_CN.po` load and validate cleanly. The full app import still reports the pre-existing missing `res://scenes/menu/MainMenu.tscn` from Task 8 only.

- [x] **Step 4: Commit**

```powershell
git add localization resources project.godot
git commit -m "feat: add sample localized game content"
```

## Task 8: Add Menu, Map, Combat, Reward, and Summary Scene Flow

**Files:**

- Create: `scenes/menu/MainMenu.tscn`
- Create: `scenes/map/MapScreen.tscn`
- Create: `scenes/combat/CombatScreen.tscn`
- Create: `scenes/reward/RewardScreen.tscn`
- Create: `scenes/summary/RunSummaryScreen.tscn`
- Create: `scripts/ui/main_menu.gd`
- Create: `scripts/ui/map_screen.gd`
- Create: `scripts/ui/combat_screen.gd`
- Create: `scripts/ui/reward_screen.gd`
- Create: `scripts/ui/run_summary_screen.gd`

- [x] **Step 1: Add main menu scene and script**

Create `scripts/ui/main_menu.gd`:

```gdscript
extends Control

func _ready() -> void:
	var new_run := Button.new()
	new_run.text = tr("ui.new_run")
	new_run.pressed.connect(_on_new_run_pressed)
	add_child(new_run)

	var continue_run := Button.new()
	continue_run.text = tr("ui.continue")
	continue_run.position.y = 48
	continue_run.pressed.connect(_on_continue_pressed)
	add_child(continue_run)

func _on_new_run_pressed() -> void:
	var app := get_tree().root.get_node("App")
	app.game.current_run = _create_minimal_run("sword", 12345)
	app.game.router.go_to(SceneRouter.MAP)

func _on_continue_pressed() -> void:
	var app := get_tree().root.get_node("App")
	if app.game.save_service and app.game.save_service.has_save():
		app.game.current_run = app.game.save_service.load_run()
		app.game.router.go_to(SceneRouter.MAP)

func _create_minimal_run(character_id: String, seed_value: int):
	var RunState := preload("res://scripts/run/run_state.gd")
	var MapGenerator := preload("res://scripts/run/map_generator.gd")
	var run := RunState.new()
	run.seed_value = seed_value
	run.character_id = character_id
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike", "sword.strike", "sword.strike"]
	run.map_nodes = MapGenerator.new().generate(seed_value)
	return run
```

Create `scenes/menu/MainMenu.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_menu"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_menu")
```

- [x] **Step 2: Initialize services in app**

Modify `scripts/app/app.gd`:

```gdscript
extends Control

const SaveService := preload("res://scripts/save/save_service.gd")
const LocalPlatformService := preload("res://scripts/platform/local_platform_service.gd")

var game := Game.new()

func _ready() -> void:
	add_child(game)
	game.save_service = SaveService.new()
	game.platform_service = LocalPlatformService.new()
	game.router.setup(self)
	game.router.go_to(SceneRouter.MAIN_MENU)
```

- [x] **Step 3: Add sample map flow**

Create `scripts/ui/map_screen.gd`:

```gdscript
extends Control

func _ready() -> void:
	var label := Label.new()
	label.text = "路线地图"
	add_child(label)

	var app := get_tree().root.get_node("App")
	var y := 48
	for node in app.game.current_run.map_nodes:
		var button := Button.new()
		button.text = "%s: %s" % [node.id, node.node_type]
		button.position.y = y
		button.disabled = not node.unlocked
		button.pressed.connect(func(): _enter_node(node))
		add_child(button)
		y += 40

func _enter_node(node) -> void:
	var app := get_tree().root.get_node("App")
	app.game.current_run.current_node_id = node.id
	if node.node_type == "boss" or node.node_type == "combat" or node.node_type == "elite":
		app.game.router.go_to(SceneRouter.COMBAT)
	else:
		app.game.router.go_to(SceneRouter.REWARD)
```

Create `scenes/map/MapScreen.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/map_screen.gd" id="1_map"]

[node name="MapScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_map")
```

- [x] **Step 4: Add sample combat flow**

Create `scripts/ui/combat_screen.gd`:

```gdscript
extends Control

func _ready() -> void:
	var label := Label.new()
	label.text = "战斗"
	add_child(label)

	var win := Button.new()
	win.text = "模拟胜利"
	win.position.y = 48
	win.pressed.connect(_on_win_pressed)
	add_child(win)

	var lose := Button.new()
	lose.text = "模拟失败"
	lose.position.y = 96
	lose.pressed.connect(_on_lose_pressed)
	add_child(lose)

func _on_win_pressed() -> void:
	var app := get_tree().root.get_node("App")
	app.game.router.go_to(SceneRouter.REWARD)

func _on_lose_pressed() -> void:
	var app := get_tree().root.get_node("App")
	app.game.current_run.failed = true
	app.game.router.go_to(SceneRouter.SUMMARY)
```

Create `scenes/combat/CombatScreen.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/combat_screen.gd" id="1_combat"]

[node name="CombatScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_combat")
```

- [x] **Step 5: Add reward and summary screens**

Create `scripts/ui/reward_screen.gd`:

```gdscript
extends Control

func _ready() -> void:
	var label := Label.new()
	label.text = "奖励"
	add_child(label)

	var next := Button.new()
	next.text = "继续"
	next.position.y = 48
	next.pressed.connect(_on_next_pressed)
	add_child(next)

func _on_next_pressed() -> void:
	var app := get_tree().root.get_node("App")
	_unlock_next_node(app.game.current_run)
	app.game.save_service.save_run(app.game.current_run)
	if app.game.current_run.completed:
		app.game.router.go_to(SceneRouter.SUMMARY)
	else:
		app.game.router.go_to(SceneRouter.MAP)

func _unlock_next_node(run) -> void:
	var current_index := 0
	for i in range(run.map_nodes.size()):
		if run.map_nodes[i].id == run.current_node_id:
			current_index = i
			run.map_nodes[i].visited = true
			break
	if current_index + 1 < run.map_nodes.size():
		run.map_nodes[current_index + 1].unlocked = true
	else:
		run.completed = true
```

Create `scripts/ui/run_summary_screen.gd`:

```gdscript
extends Control

func _ready() -> void:
	var app := get_tree().root.get_node("App")
	var label := Label.new()
	label.text = "失败结算" if app.game.current_run.failed else "通关结算"
	add_child(label)

	var menu := Button.new()
	menu.text = "返回主菜单"
	menu.position.y = 48
	menu.pressed.connect(func(): app.game.router.go_to(SceneRouter.MAIN_MENU))
	add_child(menu)
```

Create matching `.tscn` files with the same pattern as `MapScreen.tscn`, using script ids `1_reward` and `1_summary`.

- [x] **Step 6: Run import check**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected: no parse errors.

Verification note: Task 8 scenes and scripts import through `& $env:GODOT4 --headless --path . --quit` with exit code 0. No parse errors or missing MainMenu errors appear; Godot still prints exit-time ObjectDB/resource cleanup warnings.

- [x] **Step 7: Commit**

```powershell
git add scenes scripts/ui scripts/app/app.gd
git commit -m "feat: add sample run scene flow"
```

## Task 9: Add Developer Debug Overlay and Presentation Event Router

**Files:**

- Create: `scenes/dev/DebugOverlay.tscn`
- Create: `scripts/ui/debug_overlay.gd`
- Create: `scripts/presentation/presentation_event_router.gd`
- Modify: `scenes/app/App.tscn`
- Modify: `scripts/app/app.gd`

- [x] **Step 1: Add presentation event router**

Create `scripts/presentation/presentation_event_router.gd`:

```gdscript
class_name PresentationEventRouter
extends Node

var camera_shake_enabled := true
var particles_enabled := true
var slow_motion_enabled := true

func handle_event(event: GameEvent) -> void:
	match event.type:
		"card_played":
			print("Presentation card_played: %s" % event.payload)
		"damage_dealt":
			print("Presentation damage_dealt: %s" % event.payload)
```

- [x] **Step 2: Add debug overlay script**

Create `scripts/ui/debug_overlay.gd`:

```gdscript
extends PanelContainer

func _ready() -> void:
	visible = OS.is_debug_build()
	var box := VBoxContainer.new()
	add_child(box)

	var heal := Button.new()
	heal.text = "Debug: Full HP"
	heal.pressed.connect(_full_hp)
	box.add_child(heal)

	var gold := Button.new()
	gold.text = "Debug: +100 Gold"
	gold.pressed.connect(_add_gold)
	box.add_child(gold)

	var map := Button.new()
	map.text = "Debug: Map"
	map.pressed.connect(_go_map)
	box.add_child(map)

func _full_hp() -> void:
	var app := get_tree().root.get_node("App")
	if app.game.current_run:
		app.game.current_run.current_hp = app.game.current_run.max_hp

func _add_gold() -> void:
	var app := get_tree().root.get_node("App")
	if app.game.current_run:
		app.game.current_run.gold += 100

func _go_map() -> void:
	var app := get_tree().root.get_node("App")
	if app.game.current_run:
		app.game.router.go_to(SceneRouter.MAP)
```

Create `scenes/dev/DebugOverlay.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/debug_overlay.gd" id="1_debug"]

[node name="DebugOverlay" type="PanelContainer"]
offset_right = 220.0
offset_bottom = 160.0
script = ExtResource("1_debug")
```

- [x] **Step 3: Add overlay to app at runtime**

Modify `scripts/app/app.gd`:

```gdscript
extends Control

const SaveService := preload("res://scripts/save/save_service.gd")
const LocalPlatformService := preload("res://scripts/platform/local_platform_service.gd")
const DebugOverlayScene := preload("res://scenes/dev/DebugOverlay.tscn")

var game := Game.new()

func _ready() -> void:
	add_child(game)
	game.save_service = SaveService.new()
	game.platform_service = LocalPlatformService.new()
	game.router.setup(self)
	game.router.go_to(SceneRouter.MAIN_MENU)
	add_child(DebugOverlayScene.instantiate())
```

- [x] **Step 4: Run import check**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected: no parse errors.

Verification note: Task 9 imports cleanly through `& $env:GODOT4 --headless --path . --quit` with exit code 0 and no parse errors. The existing exit-time ObjectDB/resource cleanup warning still appears. The existing test suite also passes through `& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd`.

- [x] **Step 5: Commit**

```powershell
git add scenes/dev scripts/ui/debug_overlay.gd scripts/presentation scripts/app/app.gd
git commit -m "feat: add debug overlay and presentation hooks"
```

## Task 10: Add Scene Flow Smoke Test

**Files:**

- Create: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/testing/test_runner.gd`

- [x] **Step 1: Write smoke test**

Create `tests/smoke/test_scene_flow.gd`:

```gdscript
extends RefCounted

const AppScene := preload("res://scenes/app/App.tscn")

func test_app_scene_instantiates() -> bool:
	var app := AppScene.instantiate()
	var passed := app != null
	assert(passed)
	if app != null:
		app.free()
	return passed
```

- [x] **Step 2: Run smoke test**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
RUN res://tests/smoke/test_scene_flow.gd:test_app_scene_instantiates
TESTS PASSED
```

Verification: observed the runner execute `RUN res://tests/smoke/test_scene_flow.gd:test_app_scene_instantiates`; the runner path already existed in `scripts/testing/test_runner.gd`, so no runner edit was needed.

- [x] **Step 3: Run Godot scene open check**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected: no scene load or parse errors.

Verification: Godot opened the project headlessly with no scene load or parse errors. Known exit-time cleanup warnings were not treated as Task 10 failures.

- [x] **Step 4: Commit**

```powershell
git add tests/smoke/test_scene_flow.gd scripts/testing/test_runner.gd docs/superpowers/plans/2026-04-25-godot-foundation-vertical-slice.md
git commit -m "test: add scene flow smoke coverage"
```

## Task 11: Prepare Windows Local Export Settings

**Files:**

- Create: `export_presets.cfg`
- Create directory: `export/`

- [x] **Step 1: Create Windows export preset**

Create `export_presets.cfg`:

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="export/MySlaytheSpire.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=true
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version="0.1.0.0"
application/product_version="0.1.0.0"
application/company_name=""
application/product_name="MySlaytheSpire"
application/file_description="东方玄幻卡牌肉鸽"
application/copyright=""
application/trademarks=""
```

- [x] **Step 2: Verify export preset is visible to Godot**

Run:

```powershell
& $env:GODOT4 --headless --path . --export-debug "Windows Desktop" export/MySlaytheSpire.exe
```

Expected:

```text
Exporting project...
```

If export templates are missing, install Godot 4.6.2 export templates in the editor, rerun the command, and do not change project code.

Verification note: preset exists and is recognized by Godot, but export is blocked by missing local Godot 4.6.2 Windows export templates. Command exit code was 0 and output was:

```text
WARNING: Missing .uid file for path "res://scripts/platform/local_platform_service.gd". The file was re-created from cache.
   at: _process_file_system (editor/file_system/editor_file_system.cpp:1363)
WARNING: Missing .uid file for path "res://scripts/platform/platform_service.gd". The file was re-created from cache.
   at: _process_file_system (editor/file_system/editor_file_system.cpp:1363)
WARNING: Missing .uid file for path "res://scripts/save/save_service.gd". The file was re-created from cache.
   at: _process_file_system (editor/file_system/editor_file_system.cpp:1363)
WARNING: Missing .uid file for path "res://tests/unit/test_save_service.gd". The file was re-created from cache.
   at: _process_file_system (editor/file_system/editor_file_system.cpp:1363)
ERROR: Cannot export project with preset "Windows Desktop" due to configuration errors:
指定路径不存在导出模板：
C:/Users/56922/AppData/Roaming/Godot/export_templates/4.6.2.stable/windows_debug_x86_64.exe
指定路径不存在导出模板：
C:/Users/56922/AppData/Roaming/Godot/export_templates/4.6.2.stable/windows_release_x86_64.exe

   at: _fs_changed (editor/editor_node.cpp:1332)
ERROR: Project export for preset "Windows Desktop" failed.
   at: _fs_changed (editor/editor_node.cpp:1348)
```

- [x] **Step 3: Commit**

```powershell
git add export_presets.cfg docs/superpowers/plans/2026-04-25-godot-foundation-vertical-slice.md
git commit -m "chore: add Windows export preset"
```

## Task 12: Phase 1 Acceptance Pass

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Run all local tests**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 2: Run project import check**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected: no parse errors, no missing resources.

- [ ] **Step 3: Run the game manually in editor**

Run:

```powershell
& $env:GODOT4 --path .
```

Manual acceptance:

- Main menu opens.
- New run enters map.
- First unlocked map node enters combat.
- Simulated victory enters reward.
- Reward returns to map and unlocks next node.
- Boss node eventually reaches summary.
- Simulated failure reaches summary.
- Debug overlay appears in debug build.
- Continuing a saved run returns to map.

- [ ] **Step 4: Update README with Phase 1 status**

Modify `README.md`:

```markdown
## Phase 1 Status

- Godot project skeleton: complete
- Seeded run map: complete
- Minimal combat engine: complete
- Save/continue: complete
- Sample scene flow: complete
- Debug overlay: complete
- Local tests: complete
- Windows export preset: prepared

## Next Plans

1. Content expansion: two characters, card pools, relics, enemies, bosses, event pool.
2. High-presentation pass: generated assets, animation, particles, camera, audio.
3. Developer tools: card browser, enemy sandbox, event tester, reward inspector, save inspector.
4. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
```

- [ ] **Step 5: Commit**

```powershell
git add README.md
git commit -m "docs: record phase 1 acceptance status"
```

## Self-Review Checklist

Before considering this plan complete, verify:

- Every task produces working, testable software or a committed project artifact.
- No task requires final art, final audio, Steamworks, CI, or full content volume.
- The minimal vertical slice still exercises menu, map, combat, reward, summary, save, seed, tests, and export preset.
- The plan preserves future extension points from the approved spec.
- The plan does not require editing files outside the repository.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-25-godot-foundation-vertical-slice.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
