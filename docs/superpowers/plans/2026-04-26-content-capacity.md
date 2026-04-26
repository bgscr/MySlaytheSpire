# Phase 2 Content Capacity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the content loading, validation, reward generation, encounter generation, and minimal effect support needed before bulk Phase 2 content production.

**Architecture:** The implementation adds a small content layer above existing Godot Resources. `ContentCatalog` owns resource indexing and validation, `RewardGenerator` and `EncounterGenerator` consume the catalog with deterministic `RngService` forks, and combat support remains logic-only with presentation untouched.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resource `.tres`, custom headless test runner, PowerShell local verification.

---

## Scope Check

This plan implements the approved content capacity spec:

- ContentCatalog for cards, characters, enemies, and relics.
- RewardGenerator for card, gold, and relic reward candidates.
- EncounterGenerator for normal, elite, and boss encounters.
- Resource schema metadata for character ownership, pool tags, reward weights, and tiers.
- Minimal new combat effects: `draw_card`, `gain_energy`, `apply_status`, and `gain_gold`.
- Resource consistency tests and deterministic generator tests.

This plan does not bulk-create the full target content volume. It may update existing sample resources with metadata so the new generators have one normal enemy, one elite enemy, one boss, one sword card, one alchemy card, and one common relic to validate against.

## File Structure

Create:

```text
scripts/content/content_catalog.gd
scripts/reward/reward_generator.gd
scripts/run/encounter_generator.gd
tests/unit/test_content_catalog.gd
tests/unit/test_reward_generator.gd
tests/unit/test_encounter_generator.gd
```

Modify:

```text
scripts/data/card_def.gd
scripts/data/enemy_def.gd
scripts/data/relic_def.gd
scripts/combat/combat_state.gd
scripts/combat/effect_executor.gd
scripts/combat/combat_engine.gd
scripts/testing/test_runner.gd
tests/unit/test_resource_schemas.gd
tests/unit/test_combat_engine.gd
resources/cards/sword/strike_sword.tres
resources/cards/alchemy/toxic_pill.tres
resources/enemies/training_puppet.tres
resources/enemies/forest_bandit.tres
resources/enemies/boss_heart_demon.tres
resources/relics/jade_talisman.tres
```

## Command Conventions

Use:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
& $env:GODOT4 --headless --path . --quit
```

Expected final test output:

```text
TESTS PASSED
```

## Review Gates

After each completed Godot feature in this plan:

1. **Spec Compliance Review:** verify files, scripts, resources, test runner entries, and behavior match this plan and `docs/superpowers/specs/2026-04-26-content-capacity-design.md`.
2. **Code Quality Review:** verify GDScript typing, signal/resource usage, node paths, duplication, testability, and maintainability. Classify issues as Critical, Important, or Minor.

Do not proceed from a feature if the spec review finds a missing requirement.

## Task 1: Resource Schema and Combat Effect Capacity

**Files:**

- Modify: `scripts/data/card_def.gd`
- Modify: `scripts/data/enemy_def.gd`
- Modify: `scripts/data/relic_def.gd`
- Modify: `scripts/combat/combat_state.gd`
- Modify: `scripts/combat/effect_executor.gd`
- Modify: `scripts/combat/combat_engine.gd`
- Modify: `tests/unit/test_resource_schemas.gd`
- Modify: `tests/unit/test_combat_engine.gd`

- [ ] **Step 1: Write failing schema metadata tests**

Append these tests and helper to `tests/unit/test_resource_schemas.gd`:

```gdscript
func test_content_schema_exports_pool_metadata() -> bool:
	var card := CardDef.new()
	var enemy := EnemyDef.new()
	var relic := RelicDef.new()
	var passed := _has_property(card, "character_id") \
		and _has_property(card, "pool_tags") \
		and _has_property(card, "reward_weight") \
		and _has_property(enemy, "tier") \
		and _has_property(enemy, "encounter_weight") \
		and _has_property(enemy, "gold_reward_min") \
		and _has_property(enemy, "gold_reward_max") \
		and _has_property(relic, "tier") \
		and _has_property(relic, "reward_weight")
	assert(passed)
	return passed

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.name) == property_name:
			return true
	return false
```

- [ ] **Step 2: Write failing combat effect tests**

Append these tests to `tests/unit/test_combat_engine.gd`:

```gdscript
func test_stateful_effects_update_combat_state() -> bool:
	var draw := _make_effect("draw_card", 2, "player")
	var energy := _make_effect("gain_energy", 1, "player")
	var gold := _make_effect("gain_gold", 9, "player")
	var effects: Array[EffectDef] = [draw, energy, gold]
	var card := _make_card(effects)
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	state.energy = 0
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	if not engine.has_method("play_card_in_state"):
		assert(false)
		return false
	engine.call("play_card_in_state", card, state, state.player, enemy)
	var passed := state.get("pending_draw_count") == 2 \
		and state.energy == 1 \
		and state.get("gold_delta") == 9
	assert(passed)
	return passed

func test_apply_status_stacks_positive_amounts() -> bool:
	var poison := _make_effect("apply_status", 3, "enemy")
	poison.status_id = "poison"
	var repeat_poison := _make_effect("apply_status", 2, "target")
	repeat_poison.status_id = "poison"
	var ignored := _make_effect("apply_status", 0, "enemy")
	ignored.status_id = "burn"
	var effects: Array[EffectDef] = [poison, repeat_poison, ignored]
	var card := _make_card(effects)
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	if not engine.has_method("play_card_in_state"):
		assert(false)
		return false
	engine.call("play_card_in_state", card, state, state.player, enemy)
	var passed := enemy.statuses.get("poison", 0) == 5 \
		and not enemy.statuses.has("burn")
	assert(passed)
	return passed
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: test output includes failures for missing schema metadata and missing `play_card_in_state`.

- [ ] **Step 4: Implement schema metadata fields**

Update `scripts/data/card_def.gd`:

```gdscript
class_name CardDef
extends Resource

const EffectDef := preload("res://scripts/data/effect_def.gd")

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var cost: int = 1
@export_enum("attack", "skill", "power") var card_type: String = "attack"
@export_enum("common", "uncommon", "rare") var rarity: String = "common"
@export var tags: Array[String] = []
@export var effects: Array[EffectDef] = []
@export var character_id: String = ""
@export var pool_tags: Array[String] = []
@export var reward_weight: int = 100
```

Update `scripts/data/enemy_def.gd`:

```gdscript
class_name EnemyDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var max_hp: int = 20
@export var intent_sequence: Array[String] = []
@export var reward_tier: String = "normal"
@export_enum("normal", "elite", "boss") var tier: String = "normal"
@export var encounter_weight: int = 100
@export var gold_reward_min: int = 8
@export var gold_reward_max: int = 14
```

Update `scripts/data/relic_def.gd`:

```gdscript
class_name RelicDef
extends Resource

const EffectDef := preload("res://scripts/data/effect_def.gd")

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var trigger_event: String = ""
@export var effects: Array[EffectDef] = []
@export_enum("common", "uncommon", "rare", "boss") var tier: String = "common"
@export var reward_weight: int = 100
```

- [ ] **Step 5: Implement stateful combat effects**

Update `scripts/combat/combat_state.gd`:

```gdscript
class_name CombatState
extends RefCounted

const CombatantState := preload("res://scripts/combat/combatant_state.gd")

var turn := 1
var energy := 3
var player: CombatantState
var enemies: Array[CombatantState] = []
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhausted_pile: Array[String] = []
var pending_draw_count := 0
var gold_delta := 0
```

Update `scripts/combat/effect_executor.gd`:

```gdscript
class_name EffectExecutor
extends RefCounted

const EffectDef := preload("res://scripts/data/effect_def.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func execute(effect: EffectDef, source: CombatantState, target: CombatantState) -> void:
	_execute_effect(effect, null, source, target)

func execute_in_state(effect: EffectDef, state: CombatState, source: CombatantState, target: CombatantState) -> void:
	_execute_effect(effect, state, source, target)

func _execute_effect(effect: EffectDef, state: CombatState, source: CombatantState, target: CombatantState) -> void:
	var recipient := _resolve_recipient(effect.target, source, target)
	var amount: int = max(0, effect.amount)
	match effect.effect_type:
		"damage":
			recipient.take_damage(amount)
		"block":
			recipient.gain_block(amount)
		"heal":
			recipient.current_hp = min(recipient.max_hp, recipient.current_hp + amount)
		"draw_card":
			if state != null:
				state.pending_draw_count += amount
		"gain_energy":
			if state != null:
				state.energy += amount
		"apply_status":
			if amount > 0 and not effect.status_id.is_empty():
				recipient.statuses[effect.status_id] = recipient.statuses.get(effect.status_id, 0) + amount
		"gain_gold":
			if state != null:
				state.gold_delta += amount
		_:
			push_error("Unknown effect type: %s" % effect.effect_type)

func _resolve_recipient(effect_target: String, source: CombatantState, target: CombatantState) -> CombatantState:
	match effect_target.to_lower():
		"enemy", "target":
			return target
		"player", "self", "source":
			return source
		_:
			push_error("Unknown effect target: %s" % effect_target)
			return target
```

Update `scripts/combat/combat_engine.gd`:

```gdscript
class_name CombatEngine
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const EffectExecutor := preload("res://scripts/combat/effect_executor.gd")

var executor := EffectExecutor.new()

func play_card(card: CardDef, source: CombatantState, target: CombatantState) -> void:
	for effect in card.effects:
		executor.execute(effect, source, target)

func play_card_in_state(card: CardDef, state: CombatState, source: CombatantState, target: CombatantState) -> void:
	for effect in card.effects:
		executor.execute_in_state(effect, state, source, target)

func end_turn(state: CombatState) -> void:
	state.turn += 1
	state.energy = 3
	state.player.block = 0
```

- [ ] **Step 6: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all existing tests and the new Task 1 tests pass.

- [ ] **Step 7: Run Task 1 review gates**

Spec review checklist:

- `CardDef`, `EnemyDef`, `RelicDef` contain all planned metadata fields.
- `CombatState` contains `pending_draw_count` and `gold_delta`.
- `CombatEngine.play_card` remains compatible with existing tests.
- `CombatEngine.play_card_in_state` handles stateful effects.

Code quality checklist:

- New functions are typed.
- Effect target resolution remains centralized.
- Non-positive effect amounts do not mutate combat state.

- [ ] **Step 8: Commit Task 1**

```powershell
git add scripts/data scripts/combat tests/unit/test_resource_schemas.gd tests/unit/test_combat_engine.gd
git commit -m "feat: extend content schemas and combat effects"
```

## Task 2: ContentCatalog Loading and Queries

**Files:**

- Create: `scripts/content/content_catalog.gd`
- Create: `tests/unit/test_content_catalog.gd`
- Modify: `scripts/testing/test_runner.gd`
- Modify: `resources/enemies/boss_heart_demon.tres`

- [ ] **Step 1: Write failing ContentCatalog tests**

Create `tests/unit/test_content_catalog.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")

func test_default_catalog_loads_existing_resources() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var passed := catalog.get_card("sword.strike") != null \
		and catalog.get_card("alchemy.toxic_pill") != null \
		and catalog.get_character("sword") != null \
		and catalog.get_character("alchemy") != null \
		and catalog.get_enemy("training_puppet") != null \
		and catalog.get_enemy("boss_heart_demon") != null \
		and catalog.get_relic("jade_talisman") != null
	assert(passed)
	return passed

func test_catalog_queries_cards_by_character_and_rarity() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var sword_cards := catalog.get_cards_for_character("sword")
	var alchemy_cards := catalog.get_cards_for_character("alchemy")
	var sword_common := catalog.get_cards_by_rarity("sword", "common")
	var passed := _ids(sword_cards).has("sword.strike") \
		and not _ids(sword_cards).has("alchemy.toxic_pill") \
		and _ids(alchemy_cards).has("alchemy.toxic_pill") \
		and _ids(sword_common).has("sword.strike")
	assert(passed)
	return passed

func test_catalog_queries_enemies_and_relics_by_tier() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var normal_enemies := catalog.get_enemies_by_tier("normal")
	var boss_enemies := catalog.get_enemies_by_tier("boss")
	var common_relics := catalog.get_relics_by_tier("common")
	var passed := _ids(normal_enemies).has("training_puppet") \
		and _ids(boss_enemies).has("boss_heart_demon") \
		and _ids(common_relics).has("jade_talisman")
	assert(passed)
	return passed

func test_catalog_rejects_wrong_resource_type_for_card_paths() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_from_paths(
		["res://resources/characters/sword_cultivator.tres"],
		[],
		[],
		[]
	)
	var passed := catalog.cards_by_id.is_empty() \
		and catalog.get_card("sword") == null \
		and catalog.get_character("sword") == null \
		and catalog.load_errors.size() == 1 \
		and catalog.load_errors[0].contains("expected CardDef")
	assert(passed)
	return passed

func test_enemy_tier_query_uses_enemy_tier_metadata() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var boss := catalog.get_enemy("boss_heart_demon")
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var passed := boss != null \
		and boss.tier == "boss" \
		and boss.reward_tier == "boss" \
		and boss_ids.has("boss_heart_demon")
	assert(passed)
	return passed

func test_enemy_tier_query_ignores_reward_tier_metadata() -> bool:
	var catalog := ContentCatalog.new()
	var enemy := EnemyDef.new()
	enemy.id = "test.reward_boss_normal_tier"
	enemy.tier = "normal"
	enemy.reward_tier = "boss"
	catalog.enemies_by_id[enemy.id] = enemy
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var passed := normal_ids.has(enemy.id) and not boss_ids.has(enemy.id)
	assert(passed)
	return passed

func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids
```

Add the test file to `scripts/testing/test_runner.gd` after `test_resource_schemas.gd`:

```gdscript
"res://tests/unit/test_content_catalog.gd",
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: loading `res://scripts/content/content_catalog.gd` fails because the file does not exist yet.

- [ ] **Step 3: Implement ContentCatalog**

Create `scripts/content/content_catalog.gd`:

```gdscript
class_name ContentCatalog
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")

const DEFAULT_CARD_PATHS: Array[String] = [
	"res://resources/cards/sword/strike_sword.tres",
	"res://resources/cards/alchemy/toxic_pill.tres",
]

const DEFAULT_CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/sword_cultivator.tres",
	"res://resources/characters/alchemy_cultivator.tres",
]

const DEFAULT_ENEMY_PATHS: Array[String] = [
	"res://resources/enemies/training_puppet.tres",
	"res://resources/enemies/forest_bandit.tres",
	"res://resources/enemies/boss_heart_demon.tres",
]

const DEFAULT_RELIC_PATHS: Array[String] = [
	"res://resources/relics/jade_talisman.tres",
]

var cards_by_id: Dictionary = {}
var characters_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var relics_by_id: Dictionary = {}
var load_errors: Array[String] = []

func load_default() -> void:
	load_from_paths(DEFAULT_CARD_PATHS, DEFAULT_CHARACTER_PATHS, DEFAULT_ENEMY_PATHS, DEFAULT_RELIC_PATHS)

func load_from_paths(
	card_paths: Array[String],
	character_paths: Array[String],
	enemy_paths: Array[String],
	relic_paths: Array[String]
) -> void:
	clear()
	_load_cards(card_paths)
	_load_characters(character_paths)
	_load_enemies(enemy_paths)
	_load_relics(relic_paths)

func clear() -> void:
	cards_by_id.clear()
	characters_by_id.clear()
	enemies_by_id.clear()
	relics_by_id.clear()
	load_errors.clear()

func get_card(card_id: String) -> CardDef:
	return cards_by_id.get(card_id) as CardDef

func get_character(character_id: String) -> CharacterDef:
	return characters_by_id.get(character_id) as CharacterDef

func get_enemy(enemy_id: String) -> EnemyDef:
	return enemies_by_id.get(enemy_id) as EnemyDef

func get_relic(relic_id: String) -> RelicDef:
	return relics_by_id.get(relic_id) as RelicDef

func get_cards_for_character(character_id: String) -> Array[CardDef]:
	var result: Array[CardDef] = []
	var character := get_character(character_id)
	for card in cards_by_id.values():
		if card.character_id == character_id:
			result.append(card)
		elif character != null and character.card_pool_ids.has(card.id):
			result.append(card)
	return result

func get_cards_by_rarity(character_id: String, rarity: String) -> Array[CardDef]:
	var result: Array[CardDef] = []
	for card in get_cards_for_character(character_id):
		if card.rarity == rarity:
			result.append(card)
	return result

func get_enemies_by_tier(tier: String) -> Array[EnemyDef]:
	var result: Array[EnemyDef] = []
	for enemy: EnemyDef in enemies_by_id.values():
		if enemy.tier == tier:
			result.append(enemy)
	return result

func get_relics_by_tier(tier: String) -> Array[RelicDef]:
	var result: Array[RelicDef] = []
	for relic in relics_by_id.values():
		if relic.tier == tier:
			result.append(relic)
	return result

func _load_cards(paths: Array[String]) -> void:
	for path in paths:
		var card := load(path) as CardDef
		if card == null:
			_record_load_error("ContentCatalog expected CardDef resource: %s" % path)
			continue
		if card.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		cards_by_id[card.id] = card

func _load_characters(paths: Array[String]) -> void:
	for path in paths:
		var character := load(path) as CharacterDef
		if character == null:
			_record_load_error("ContentCatalog expected CharacterDef resource: %s" % path)
			continue
		if character.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		characters_by_id[character.id] = character

func _load_enemies(paths: Array[String]) -> void:
	for path in paths:
		var enemy := load(path) as EnemyDef
		if enemy == null:
			_record_load_error("ContentCatalog expected EnemyDef resource: %s" % path)
			continue
		if enemy.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		enemies_by_id[enemy.id] = enemy

func _load_relics(paths: Array[String]) -> void:
	for path in paths:
		var relic := load(path) as RelicDef
		if relic == null:
			_record_load_error("ContentCatalog expected RelicDef resource: %s" % path)
			continue
		if relic.id.is_empty():
			_record_load_error("ContentCatalog resource has empty id: %s" % path)
			continue
		relics_by_id[relic.id] = relic

func _record_load_error(message: String) -> void:
	load_errors.append(message)
```

- [ ] **Step 3.5: Update boss sample enemy tier metadata**

Modify `resources/enemies/boss_heart_demon.tres`:

```ini
tier = "boss"
gold_reward_min = 40
gold_reward_max = 60
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all tests pass.

- [ ] **Step 5: Run Task 2 review gates**

Spec review checklist:

- Catalog indexes all existing sample resources.
- Catalog query methods match the spec names.
- Test runner includes `test_content_catalog.gd`.
- Wrong resource types are rejected without polluting unrelated indexes.
- Boss enemy tier query uses `EnemyDef.tier`, not `reward_tier` fallback.

Code quality checklist:

- Catalog has no random generation responsibility.
- Resource path lists are explicit constants.
- Existing `.tres` resources remain loadable.

- [ ] **Step 6: Commit Task 2**

```powershell
git add scripts/content/content_catalog.gd tests/unit/test_content_catalog.gd scripts/testing/test_runner.gd
git commit -m "feat: add content catalog"
```

## Task 3: Catalog Validation

**Files:**

- Modify: `scripts/content/content_catalog.gd`
- Modify: `tests/unit/test_content_catalog.gd`

- [ ] **Step 1: Write failing validation tests**

Append to `tests/unit/test_content_catalog.gd`:

```gdscript
func test_default_catalog_validation_passes() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var errors: Array[String] = catalog.validate()
	var passed: bool = errors.is_empty()
	if not passed:
		push_error("Catalog validation errors: %s" % str(errors))
	assert(passed)
	return passed

func test_validation_reports_unreadable_locale_file_once() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	catalog.locale_path = "res://localization/missing_zh_CN.po"
	var errors: Array[String] = catalog.validate()
	var passed: bool = errors.size() == 1 \
		and errors[0].contains("could not open localization file") \
		and errors[0].contains("missing_zh_CN.po")
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: failure because `ContentCatalog.validate` is not implemented.

- [ ] **Step 3: Implement catalog validation**

Add to `scripts/content/content_catalog.gd`:

```gdscript
var locale_path := "res://localization/zh_CN.po"

func validate() -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	var locale_error_count := errors.size()
	var locale_keys := _load_locale_keys(errors)
	var locale_loaded := errors.size() == locale_error_count
	_validate_ids("card", cards_by_id, errors)
	_validate_ids("character", characters_by_id, errors)
	_validate_ids("enemy", enemies_by_id, errors)
	_validate_ids("relic", relics_by_id, errors)
	_validate_character_card_refs(errors)
	if locale_loaded:
		_validate_locale_keys(locale_keys, errors)
	return errors

func _validate_ids(resource_type: String, resources: Dictionary, errors: Array[String]) -> void:
	for id in resources.keys():
		if String(id).is_empty():
			errors.append("%s has empty id" % resource_type)

func _validate_character_card_refs(errors: Array[String]) -> void:
	for character in characters_by_id.values():
		for card_id in character.starting_deck_ids:
			if not cards_by_id.has(card_id):
				errors.append("Character %s starting deck references missing card %s" % [character.id, card_id])
		for card_id in character.card_pool_ids:
			if not cards_by_id.has(card_id):
				errors.append("Character %s card pool references missing card %s" % [character.id, card_id])

func _validate_locale_keys(locale_keys: Dictionary, errors: Array[String]) -> void:
	for card in cards_by_id.values():
		_require_locale_key(card.name_key, "card %s name_key" % card.id, locale_keys, errors)
		_require_locale_key(card.description_key, "card %s description_key" % card.id, locale_keys, errors)
	for character in characters_by_id.values():
		_require_locale_key(character.name_key, "character %s name_key" % character.id, locale_keys, errors)
	for enemy in enemies_by_id.values():
		_require_locale_key(enemy.name_key, "enemy %s name_key" % enemy.id, locale_keys, errors)
	for relic in relics_by_id.values():
		_require_locale_key(relic.name_key, "relic %s name_key" % relic.id, locale_keys, errors)
		_require_locale_key(relic.description_key, "relic %s description_key" % relic.id, locale_keys, errors)

func _require_locale_key(key: String, label: String, locale_keys: Dictionary, errors: Array[String]) -> void:
	if key.is_empty():
		errors.append("%s is empty" % label)
	elif not locale_keys.has(key):
		errors.append("%s missing localization key %s" % [label, key])

func _load_locale_keys(errors: Array[String]) -> Dictionary:
	var keys := {}
	var file := FileAccess.open(locale_path, FileAccess.READ)
	if file == null:
		errors.append("ContentCatalog could not open localization file: %s" % locale_path)
		return keys
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("msgid \"") and line != "msgid \"\"":
			var key := line.trim_prefix("msgid \"").trim_suffix("\"")
			keys[key] = true
	return keys
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all tests pass.

- [ ] **Step 5: Run Task 3 review gates**

Spec review checklist:

- Validation checks ids, character card references, and localization keys.
- Validation includes existing `load_errors`.
- Validation returns an array of strings and does not throw for valid defaults.

Code quality checklist:

- Validation helpers are small and named by responsibility.
- `.po` parsing is limited to `msgid` keys and does not manipulate gameplay state.

- [ ] **Step 6: Commit Task 3**

```powershell
git add scripts/content/content_catalog.gd tests/unit/test_content_catalog.gd
git commit -m "test: validate content catalog resources"
```

## Task 4: RewardGenerator

**Files:**

- Create: `scripts/reward/reward_generator.gd`
- Create: `tests/unit/test_reward_generator.gd`
- Modify: `scripts/testing/test_runner.gd`

- [ ] **Step 1: Write failing RewardGenerator tests**

Create `tests/unit/test_reward_generator.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const RewardGenerator := preload("res://scripts/reward/reward_generator.gd")

func test_card_rewards_are_deterministic_for_same_seed_and_context() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var first := generator.generate_card_reward(catalog, 77, "sword", "node_1")
	var second := generator.generate_card_reward(catalog, 77, "sword", "node_1")
	var passed := first == second and first.get("card_ids", []).has("sword.strike")
	assert(passed)
	return passed

func test_card_rewards_use_character_pool() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 77, "alchemy", "node_1")
	var ids: Array = reward.get("card_ids", [])
	var passed := ids.has("alchemy.toxic_pill") and not ids.has("sword.strike")
	assert(passed)
	return passed

func test_gold_rewards_are_deterministic_and_tiered() -> bool:
	var generator := RewardGenerator.new()
	var normal := generator.generate_gold_reward(77, "node_1", "normal")
	var normal_again := generator.generate_gold_reward(77, "node_1", "normal")
	var elite := generator.generate_gold_reward(77, "node_1", "elite")
	var passed := normal == normal_again \
		and normal.get("amount", 0) >= 8 \
		and normal.get("amount", 0) <= 14 \
		and elite.get("amount", 0) >= 18 \
		and elite.get("amount", 0) <= 28
	assert(passed)
	return passed

func test_relic_rewards_are_deterministic() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var first := generator.generate_relic_reward(catalog, 99, "node_2", "common")
	var second := generator.generate_relic_reward(catalog, 99, "node_2", "common")
	var passed := first == second and first.get("relic_id") == "jade_talisman"
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog
```

Add the test file to `scripts/testing/test_runner.gd` after `test_content_catalog.gd`:

```gdscript
"res://tests/unit/test_reward_generator.gd",
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: loading `res://scripts/reward/reward_generator.gd` fails because the file does not exist yet.

- [ ] **Step 3: Implement RewardGenerator**

Create `scripts/reward/reward_generator.gd`:

```gdscript
class_name RewardGenerator
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

func generate_card_reward(catalog: ContentCatalog, seed_value: int, character_id: String, context_key: String, count: int = 3) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:card:%s" % context_key)
	var pool := catalog.get_cards_for_character(character_id)
	var shuffled := rng.shuffle_copy(pool)
	var card_ids: Array[String] = []
	for card in shuffled:
		if card_ids.size() >= count:
			break
		card_ids.append(card.id)
	return {
		"type": "card",
		"character_id": character_id,
		"card_ids": card_ids,
	}

func generate_gold_reward(seed_value: int, context_key: String, tier: String) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:gold:%s" % context_key)
	var bounds := _gold_bounds_for_tier(tier)
	return {
		"type": "gold",
		"tier": tier,
		"amount": rng.next_int(bounds.x, bounds.y),
	}

func generate_relic_reward(catalog: ContentCatalog, seed_value: int, context_key: String, tier: String) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:relic:%s" % context_key)
	var relics := catalog.get_relics_by_tier(tier)
	if relics.is_empty():
		return {
			"type": "relic",
			"tier": tier,
			"relic_id": "",
		}
	var relic = rng.pick(relics)
	return {
		"type": "relic",
		"tier": tier,
		"relic_id": relic.id,
	}

func _gold_bounds_for_tier(tier: String) -> Vector2i:
	match tier:
		"elite":
			return Vector2i(18, 28)
		"boss":
			return Vector2i(40, 60)
		_:
			return Vector2i(8, 14)
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all tests pass.

- [ ] **Step 5: Run Task 4 review gates**

Spec review checklist:

- Generator uses `RngService` forks.
- Card reward returns only character pool cards.
- Gold reward ranges match the plan.
- Relic reward handles empty pools without crashing.

Code quality checklist:

- Generator returns plain Dictionaries.
- Generator does not mutate RunState or resources.
- Random labels include reward type and context key.

- [ ] **Step 6: Commit Task 4**

```powershell
git add scripts/reward/reward_generator.gd tests/unit/test_reward_generator.gd scripts/testing/test_runner.gd
git commit -m "feat: add deterministic reward generator"
```

## Task 5: EncounterGenerator and Sample Resource Metadata

**Files:**

- Create: `scripts/run/encounter_generator.gd`
- Create: `tests/unit/test_encounter_generator.gd`
- Modify: `scripts/testing/test_runner.gd`
- Modify: `resources/cards/sword/strike_sword.tres`
- Modify: `resources/cards/alchemy/toxic_pill.tres`
- Modify: `resources/enemies/training_puppet.tres`
- Modify: `resources/enemies/forest_bandit.tres`
- Modify: `resources/enemies/boss_heart_demon.tres`
- Modify: `resources/relics/jade_talisman.tres`

- [ ] **Step 1: Write failing EncounterGenerator tests**

Create `tests/unit/test_encounter_generator.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EncounterGenerator := preload("res://scripts/run/encounter_generator.gd")

func test_combat_node_generates_normal_enemy() -> bool:
	var encounter := EncounterGenerator.new().generate(_catalog(), 12, "node_1", "combat")
	var passed := encounter == ["training_puppet"]
	assert(passed)
	return passed

func test_elite_node_generates_elite_enemy() -> bool:
	var encounter := EncounterGenerator.new().generate(_catalog(), 12, "node_2", "elite")
	var passed := encounter == ["forest_bandit"]
	assert(passed)
	return passed

func test_boss_node_generates_boss_enemy() -> bool:
	var encounter := EncounterGenerator.new().generate(_catalog(), 12, "boss_0", "boss")
	var passed := encounter == ["boss_heart_demon"]
	assert(passed)
	return passed

func test_encounters_are_deterministic_for_same_seed_and_node() -> bool:
	var generator := EncounterGenerator.new()
	var first := generator.generate(_catalog(), 123, "node_3", "combat")
	var second := generator.generate(_catalog(), 123, "node_3", "combat")
	var passed := first == second
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog
```

Add the test file to `scripts/testing/test_runner.gd` after `test_reward_generator.gd`:

```gdscript
"res://tests/unit/test_encounter_generator.gd",
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: loading `res://scripts/run/encounter_generator.gd` fails because the file does not exist yet.

- [ ] **Step 3: Implement EncounterGenerator**

Create `scripts/run/encounter_generator.gd`:

```gdscript
class_name EncounterGenerator
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

func generate(catalog: ContentCatalog, seed_value: int, node_id: String, node_type: String) -> Array[String]:
	var tier := _tier_for_node_type(node_type)
	var pool := catalog.get_enemies_by_tier(tier)
	if pool.is_empty():
		return []
	var rng = RngService.new(seed_value).fork("encounter:%s" % node_id)
	var enemy = rng.pick(pool)
	return [enemy.id]

func _tier_for_node_type(node_type: String) -> String:
	match node_type:
		"elite":
			return "elite"
		"boss":
			return "boss"
		_:
			return "normal"
```

- [ ] **Step 4: Update sample resource metadata**

Set `character_id = "sword"` in `resources/cards/sword/strike_sword.tres` under `[resource]`.

Set `character_id = "alchemy"` in `resources/cards/alchemy/toxic_pill.tres` under `[resource]`.

Set `tier = "normal"`, `encounter_weight = 100`, `gold_reward_min = 8`, and `gold_reward_max = 14` in `resources/enemies/training_puppet.tres`.

Set `tier = "elite"`, `encounter_weight = 100`, `gold_reward_min = 18`, and `gold_reward_max = 28` in `resources/enemies/forest_bandit.tres`.

Set `tier = "boss"`, `encounter_weight = 100`, `gold_reward_min = 40`, and `gold_reward_max = 60` in `resources/enemies/boss_heart_demon.tres`.

Set `tier = "common"` and `reward_weight = 100` in `resources/relics/jade_talisman.tres`.

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```powershell
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

Expected: all tests pass.

- [ ] **Step 6: Run Godot import check**

Run:

```powershell
& $env:GODOT4 --headless --path . --quit
```

Expected: exit code 0 with no missing resource or parse errors.

- [ ] **Step 7: Run Task 5 review gates**

Spec review checklist:

- Combat, elite, and boss node types map to the correct tiers.
- Encounter results are enemy id arrays.
- Sample resources expose metadata needed by catalog and generators.

Code quality checklist:

- Generator has no scene/UI dependency.
- Empty enemy pools return `[]`.
- Random labels include node id.

- [ ] **Step 8: Commit Task 5**

```powershell
git add scripts/run/encounter_generator.gd tests/unit/test_encounter_generator.gd scripts/testing/test_runner.gd resources/cards resources/enemies resources/relics
git commit -m "feat: add deterministic encounter generator"
```

## Task 6: Final Acceptance and Documentation

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-26-content-capacity.md`

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

Expected: exit code 0 with no parse errors and no missing resources.

- [ ] **Step 3: Update README Phase 2 status**

Append under `## Next Plans` or add a `## Phase 2 Progress` section:

```markdown
## Phase 2 Progress

- Content capacity foundation: complete
- Content catalog: complete
- Reward generator: complete
- Encounter generator: complete
- Resource consistency tests: complete
- Minimal extended combat effects: complete
```

- [ ] **Step 4: Run final two-stage review**

Spec compliance review:

- Compare implementation against this plan and `docs/superpowers/specs/2026-04-26-content-capacity-design.md`.
- Verify all planned files exist.
- Verify `scripts/testing/test_runner.gd` includes the new unit tests.
- Verify no unplanned scene, autoload, input map, or platform changes were introduced.

Code quality review:

- Check GDScript typing and method signatures.
- Check resource loading paths and null handling.
- Check deterministic RNG labels.
- Check validation errors are readable.
- Check no duplicate responsibilities across catalog/generators/combat.

- [ ] **Step 5: Commit final docs**

```powershell
git add README.md docs/superpowers/plans/2026-04-26-content-capacity.md
git commit -m "docs: record content capacity acceptance"
```

## Self-Review Checklist

Before considering this plan complete, verify:

- Every new behavior has a failing test before implementation.
- Every new test file is included in `scripts/testing/test_runner.gd`.
- ContentCatalog owns indexing and validation only.
- RewardGenerator and EncounterGenerator return plain data and do not mutate run/combat state.
- Existing Phase 1 scene flow remains unchanged.
- Godot tests and import check pass after implementation.
- The plan does not require files outside the repository.

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-04-26-content-capacity.md`.

Recommended execution: continue in the current `main` workspace with TDD task-by-task. If subagents are used for implementation or review, they must use `gpt-5.5` with `xhigh` reasoning, per `AGENTS.md`.
