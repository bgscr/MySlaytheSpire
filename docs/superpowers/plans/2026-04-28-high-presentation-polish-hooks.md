# High Presentation Polish Hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add programmatic high-presentation polish hooks for successful card play, including explicit card cues, fallback cue inference, config filtering, placeholder playback, and combat integration.

**Architecture:** Extend the existing presentation package rather than core combat rules. `CardDef` gains optional cue resources, `CombatPresentationCueResolver` converts successful card play plus observed state deltas into presentation events, and `CombatPresentationLayer` plays visible or inspectable placeholders while `CombatScreen` remains the bridge.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot Resource `.tres` files, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Before editing, verify `git branch --show-current` is `main`; stop if it is not.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`:
  - Stage 1 Spec Compliance Review.
  - Stage 2 Code Quality Review only after Stage 1 passes.
- Keep `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` free of presentation imports.

## Reference Spec

- `docs/superpowers/specs/2026-04-28-high-presentation-polish-hooks-design.md`

## Verification Commands

Run full tests:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

Run import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Create:

- `scripts/data/card_presentation_cue_def.gd`: typed Resource for per-card presentation cue declarations.
- `scripts/presentation/combat_presentation_cue_resolver.gd`: explicit cue and fallback inference logic.

Modify:

- `scripts/data/card_def.gd`: add optional `presentation_cues`.
- `scripts/presentation/combat_presentation_config.gd`: filter new polish event categories.
- `scripts/presentation/combat_presentation_layer.gd`: play placeholder slash, particle, camera impulse, slow motion, and audio cue events.
- `scripts/ui/debug_overlay.gd`: expose new development toggles.
- `scripts/ui/combat_screen.gd`: pass played target ids into `_run_with_feedback()` and enqueue resolver events.
- `tests/unit/test_resource_schemas.gd`: cue schema coverage.
- `tests/unit/test_combat_presentation.gd`: resolver, config, and layer coverage.
- `tests/smoke/test_scene_flow.gd`: real combat integration coverage.
- `resources/cards/sword/strike_sword.tres`: explicit slash cue.
- `resources/cards/alchemy/toxic_pill.tres`: explicit particle cue.
- `resources/cards/sword/heaven_cutting_arc.tres`: explicit slow-motion and audio cue.
- `README.md`: record completion after final acceptance.
- `docs/superpowers/plans/2026-04-28-high-presentation-polish-hooks.md`: mark steps complete during execution.

## Task 1: Card Cue Schema and Resolver

**Files:**

- Create: `scripts/data/card_presentation_cue_def.gd`
- Create: `scripts/presentation/combat_presentation_cue_resolver.gd`
- Modify: `scripts/data/card_def.gd`
- Modify: `tests/unit/test_resource_schemas.gd`
- Modify: `tests/unit/test_combat_presentation.gd`

- [x] **Step 1: Write failing schema tests**

Modify `tests/unit/test_resource_schemas.gd`.

Add the preload near the other data preloads:

```gdscript
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
```

Append these tests before helper functions:

```gdscript
func test_card_presentation_cue_def_stores_runtime_event_fields() -> bool:
	var cue := CardPresentationCueDef.new()
	cue.event_type = "cinematic_slash"
	cue.target_mode = "played_target"
	cue.amount = 3
	cue.intensity = 1.4
	cue.cue_id = "slash.test"
	cue.tags = ["cinematic"]
	cue.payload = {"color": "gold"}
	var passed: bool = cue.event_type == "cinematic_slash" \
		and cue.target_mode == "played_target" \
		and cue.amount == 3 \
		and is_equal_approx(cue.intensity, 1.4) \
		and cue.cue_id == "slash.test" \
		and cue.tags == ["cinematic"] \
		and cue.payload.get("color") == "gold"
	assert(passed)
	return passed

func test_card_def_exports_presentation_cues() -> bool:
	var cue := CardPresentationCueDef.new()
	cue.event_type = "particle_burst"
	var card := CardDef.new()
	card.id = "alchemy.test"
	card.presentation_cues = [cue]
	var passed: bool = _has_property(card, "presentation_cues") \
		and card.presentation_cues.size() == 1 \
		and card.presentation_cues[0].event_type == "particle_burst"
	assert(passed)
	return passed
```

- [x] **Step 2: Write failing resolver tests**

Modify `tests/unit/test_combat_presentation.gd`.

Add these preloads near the top:

```gdscript
const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const CombatPresentationCueResolver := preload("res://scripts/presentation/combat_presentation_cue_resolver.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
```

Append these tests before helper functions:

```gdscript
func test_cue_resolver_converts_explicit_card_cues_without_aliasing() -> bool:
	var cue := CardPresentationCueDef.new()
	cue.event_type = "cinematic_slash"
	cue.target_mode = "played_target"
	cue.amount = 2
	cue.intensity = 1.25
	cue.cue_id = "slash.explicit"
	cue.tags = ["cinematic"]
	cue.payload = {"points": [Vector2(1, 2)]}
	var card := CardDef.new()
	card.id = "sword.explicit"
	card.presentation_cues = [cue]

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [])
	cue.tags.append("mutated")
	cue.payload["points"].append(Vector2(3, 4))
	var event := events[0] if events.size() > 0 else null
	var points: Array = event.payload.get("points", []) if event != null else []
	var passed: bool = events.size() == 1 \
		and event.event_type == "cinematic_slash" \
		and event.card_id == "sword.explicit" \
		and event.target_id == "enemy:0" \
		and event.amount == 2 \
		and is_equal_approx(event.intensity, 1.25) \
		and event.tags == ["cinematic"] \
		and event.payload.get("cue_id") == "slash.explicit" \
		and points.size() == 1
	assert(passed)
	return passed

func test_cue_resolver_maps_target_modes() -> bool:
	var card := CardDef.new()
	card.id = "mode.test"
	card.presentation_cues = [
		_cue("particle_burst", "played_target"),
		_cue("camera_impulse", "source"),
		_cue("slow_motion", "player"),
		_cue("audio_cue", "none"),
	]
	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:1", [])
	var passed: bool = events.size() == 4 \
		and events[0].target_id == "enemy:1" \
		and events[1].target_id == "player" \
		and events[2].target_id == "player" \
		and events[3].target_id == ""
	assert(passed)
	return passed

func test_cue_resolver_fallback_emits_sword_slash_and_damage_camera() -> bool:
	var card := CardDef.new()
	card.id = "sword.fallback"
	card.character_id = "sword"
	card.card_type = "attack"
	var damage_effect := EffectDef.new()
	damage_effect.effect_type = "damage"
	damage_effect.amount = 6
	damage_effect.target = "enemy"
	card.effects = [damage_effect]
	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "enemy:0"
	damage.amount = 6

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [damage])
	var passed: bool = _has_event(events, "cinematic_slash", "enemy:0", 0, "") \
		and _has_event(events, "camera_impulse", "", 0, "") \
		and _event_count(events, "cinematic_slash") == 1 \
		and _event_count(events, "camera_impulse") == 1
	assert(passed)
	return passed

func test_cue_resolver_fallback_emits_alchemy_and_poison_particles() -> bool:
	var card := CardDef.new()
	card.id = "alchemy.poison_test"
	card.character_id = "alchemy"
	var poison_effect := EffectDef.new()
	poison_effect.effect_type = "apply_status"
	poison_effect.status_id = "poison"
	poison_effect.amount = 2
	poison_effect.target = "enemy"
	card.effects = [poison_effect]

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [])
	var passed: bool = _has_event(events, "particle_burst", "enemy:0", 0, "") \
		and _event_count(events, "particle_burst") == 1
	assert(passed)
	return passed

func test_cue_resolver_does_not_infer_slow_motion_or_audio() -> bool:
	var card := CardDef.new()
	card.id = "sword.no_audio"
	card.character_id = "sword"
	card.card_type = "attack"
	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [])
	var passed: bool = _event_count(events, "slow_motion") == 0 \
		and _event_count(events, "audio_cue") == 0
	assert(passed)
	return passed
```

Add these helpers near the existing `_has_event()` helper:

```gdscript
func _cue(event_type: String, target_mode: String) -> CardPresentationCueDef:
	var cue := CardPresentationCueDef.new()
	cue.event_type = event_type
	cue.target_mode = target_mode
	return cue

func _event_count(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if event.event_type == event_type:
			count += 1
	return count
```

- [x] **Step 3: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures loading missing `card_presentation_cue_def.gd` and `combat_presentation_cue_resolver.gd`.

- [x] **Step 4: Implement cue schema**

Create `scripts/data/card_presentation_cue_def.gd`:

```gdscript
class_name CardPresentationCueDef
extends Resource

@export var event_type: String = ""
@export_enum("played_target", "source", "player", "none") var target_mode: String = "played_target"
@export var amount: int = 0
@export var intensity: float = 1.0
@export var cue_id: String = ""
@export var tags: Array[String] = []
@export var payload: Dictionary = {}
```

Modify `scripts/data/card_def.gd`.

Add after the existing `EffectDef` preload:

```gdscript
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
```

Add after `@export var effects`:

```gdscript
@export var presentation_cues: Array[CardPresentationCueDef] = []
```

- [x] **Step 5: Implement cue resolver**

Create `scripts/presentation/combat_presentation_cue_resolver.gd`:

```gdscript
class_name CombatPresentationCueResolver
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")

const CAMERA_INTENSITY_PER_DAMAGE := 0.08
const CAMERA_INTENSITY_MIN := 0.4
const CAMERA_INTENSITY_MAX := 1.8

func resolve_card_play(
	card: CardDef,
	source_id: String,
	played_target_id: String,
	delta_events: Array
) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if card == null:
		return events
	if not card.presentation_cues.is_empty():
		for cue in card.presentation_cues:
			var typed_cue := cue as CardPresentationCueDef
			if typed_cue == null or typed_cue.event_type.is_empty():
				continue
			events.append(_event_from_cue(card, typed_cue, source_id, played_target_id))
		return events
	return _fallback_events(card, source_id, played_target_id, delta_events)

func _event_from_cue(
	card: CardDef,
	cue: CardPresentationCueDef,
	source_id: String,
	played_target_id: String
) -> CombatPresentationEvent:
	var event := CombatPresentationEvent.new(cue.event_type)
	event.card_id = card.id
	event.source_id = source_id
	event.target_id = _target_for_mode(cue.target_mode, source_id, played_target_id)
	event.amount = cue.amount
	event.intensity = cue.intensity
	event.tags = cue.tags.duplicate()
	event.payload = cue.payload.duplicate(true)
	if not cue.cue_id.is_empty():
		event.payload["cue_id"] = cue.cue_id
	return event

func _target_for_mode(target_mode: String, source_id: String, played_target_id: String) -> String:
	match target_mode:
		"played_target":
			return played_target_id
		"source":
			return source_id
		"player":
			return "player"
		"none":
			return ""
	return played_target_id

func _fallback_events(
	card: CardDef,
	source_id: String,
	played_target_id: String,
	delta_events: Array
) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if _should_emit_slash(card):
		var slash := CombatPresentationEvent.new("cinematic_slash")
		slash.card_id = card.id
		slash.source_id = source_id
		slash.target_id = played_target_id
		slash.intensity = 1.0
		slash.tags = ["cinematic"]
		events.append(slash)
	if _should_emit_particle(card):
		var particle := CombatPresentationEvent.new("particle_burst")
		particle.card_id = card.id
		particle.source_id = source_id
		particle.target_id = played_target_id if not played_target_id.is_empty() else "player"
		particle.intensity = 1.0
		events.append(particle)
	var max_damage := _max_damage_amount(delta_events)
	if max_damage > 0:
		var impulse := CombatPresentationEvent.new("camera_impulse")
		impulse.card_id = card.id
		impulse.source_id = source_id
		impulse.intensity = clampf(
			float(max_damage) * CAMERA_INTENSITY_PER_DAMAGE,
			CAMERA_INTENSITY_MIN,
			CAMERA_INTENSITY_MAX
		)
		events.append(impulse)
	return events

func _should_emit_slash(card: CardDef) -> bool:
	if card.character_id == "sword" and card.card_type == "attack":
		return true
	for effect in card.effects:
		var typed_effect := effect as EffectDef
		if typed_effect == null:
			continue
		if typed_effect.effect_type == "damage" and _targets_enemy(typed_effect.target):
			return true
	return false

func _should_emit_particle(card: CardDef) -> bool:
	if card.character_id == "alchemy":
		return true
	for effect in card.effects:
		var typed_effect := effect as EffectDef
		if typed_effect == null:
			continue
		if typed_effect.effect_type == "apply_status" and typed_effect.status_id == "poison":
			return true
	return false

func _targets_enemy(target: String) -> bool:
	var normalized := target.to_lower()
	return normalized == "enemy" or normalized == "target"

func _max_damage_amount(delta_events: Array) -> int:
	var max_damage := 0
	for event in delta_events:
		if event == null:
			continue
		if event.event_type == "damage_number":
			max_damage = max(max_damage, int(event.amount))
	return max_damage
```

- [x] **Step 6: Run tests to verify GREEN for Task 1**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 7: Run Task 1 review gates**

Stage 1 Spec Compliance Review:

- `CardPresentationCueDef` exists and has all spec fields.
- `CardDef.presentation_cues` exists and is optional.
- `CombatPresentationCueResolver` converts explicit cues before fallback inference.
- Fallback emits slash, particle, and camera impulse only under the specified conditions.
- Fallback does not infer slow motion or audio cue.
- No core combat rule file imports presentation cue resolver.

Stage 2 Code Quality Review:

- Resolver methods are typed.
- Cue `tags` and `payload` are duplicated.
- Fallback inference is deterministic and does not duplicate event types.
- Resolver has no scene-tree dependency.

- [x] **Step 8: Commit Task 1**

Run:

```powershell
rtk proxy git add scripts/data/card_presentation_cue_def.gd scripts/data/card_def.gd scripts/presentation/combat_presentation_cue_resolver.gd tests/unit/test_resource_schemas.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-28-high-presentation-polish-hooks.md
rtk proxy git commit -m "feat: add card presentation cue resolver"
```

## Task 2: Config Filtering and Presentation Layer Playback

**Files:**

- Modify: `scripts/presentation/combat_presentation_config.gd`
- Modify: `scripts/presentation/combat_presentation_layer.gd`
- Modify: `scripts/ui/debug_overlay.gd`
- Modify: `tests/unit/test_combat_presentation.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [x] **Step 1: Add failing config and layer tests**

Append to `tests/unit/test_combat_presentation.gd`:

```gdscript
func test_config_filters_polish_event_categories() -> bool:
	var config := CombatPresentationConfig.new()
	config.cinematic_enabled = false
	config.particle_enabled = false
	config.camera_impulse_enabled = false
	config.slow_motion_enabled = false
	config.audio_cue_enabled = false

	var queue := CombatPresentationQueue.new()
	queue.config = config
	queue.enqueue(CombatPresentationEvent.new("cinematic_slash"))
	queue.enqueue(CombatPresentationEvent.new("particle_burst"))
	queue.enqueue(CombatPresentationEvent.new("camera_impulse"))
	queue.enqueue(CombatPresentationEvent.new("slow_motion"))
	queue.enqueue(CombatPresentationEvent.new("audio_cue"))
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))

	var drained := queue.drain()
	var passed: bool = drained.size() == 1 and drained[0].event_type == "card_hovered"
	assert(passed)
	return passed

func test_layer_plays_cinematic_slash_and_particle_placeholders(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var target := Button.new()
	target.position = Vector2(40, 50)
	layer.bind_target("enemy:0", target)
	layer.add_child(target)

	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.target_id = "enemy:0"
	layer.play_event(slash)
	var particle := CombatPresentationEvent.new("particle_burst")
	particle.target_id = "enemy:0"
	layer.play_event(particle)

	var slash_node := layer.get_node_or_null("CinematicSlash_0")
	var particle_node := layer.get_node_or_null("ParticleBurst_0_0")
	var passed: bool = slash_node != null and particle_node != null
	layer.free()
	assert(passed)
	return passed

func test_layer_camera_impulse_restores_position(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	layer.position = Vector2(12, 18)
	var impulse := CombatPresentationEvent.new("camera_impulse")
	impulse.intensity = 1.0
	layer.play_event(impulse)
	var moved := layer.position != Vector2(12, 18)
	_finish_processed_tweens(tree)
	var restored := layer.position == Vector2(12, 18)
	var passed: bool = moved and restored
	layer.free()
	assert(passed)
	return passed

func test_layer_records_slow_motion_and_audio_cue_without_global_timescale(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var original_time_scale := Engine.time_scale

	var slow := CombatPresentationEvent.new("slow_motion")
	slow.intensity = 0.5
	layer.play_event(slow)

	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "slash.heavy"}
	layer.play_event(audio)

	var passed: bool = is_equal_approx(layer.active_slow_motion_scale, 0.5) \
		and layer.last_audio_cue_id == "slash.heavy" \
		and layer.audio_cue_count == 1 \
		and is_equal_approx(Engine.time_scale, original_time_scale)
	layer.free()
	assert(passed)
	return passed
```

Append to `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_debug_overlay_updates_polish_presentation_config(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_polish_config_save.json")
	var debug_overlay: Node = app.get_node_or_null("DebugLayer/DebugOverlay")
	var particle_toggle := _find_node_by_name(debug_overlay, "DebugPresentationParticles") as CheckBox
	var camera_toggle := _find_node_by_name(debug_overlay, "DebugPresentationCameraImpulse") as CheckBox
	var slow_toggle := _find_node_by_name(debug_overlay, "DebugPresentationSlowMotion") as CheckBox
	var audio_toggle := _find_node_by_name(debug_overlay, "DebugPresentationAudioCue") as CheckBox
	if particle_toggle != null:
		particle_toggle.button_pressed = false
		particle_toggle.toggled.emit(false)
	if camera_toggle != null:
		camera_toggle.button_pressed = false
		camera_toggle.toggled.emit(false)
	if slow_toggle != null:
		slow_toggle.button_pressed = false
		slow_toggle.toggled.emit(false)
	if audio_toggle != null:
		audio_toggle.button_pressed = false
		audio_toggle.toggled.emit(false)
	var passed: bool = particle_toggle != null \
		and camera_toggle != null \
		and slow_toggle != null \
		and audio_toggle != null \
		and app.game.presentation_config.particle_enabled == false \
		and app.game.presentation_config.camera_impulse_enabled == false \
		and app.game.presentation_config.slow_motion_enabled == false \
		and app.game.presentation_config.audio_cue_enabled == false
	app.free()
	_delete_test_save("user://test_debug_polish_config_save.json")
	return passed
```

- [x] **Step 2: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures for missing config fields, missing placeholder playback nodes, and missing debug toggle nodes.

- [x] **Step 3: Implement config filtering**

Modify `scripts/presentation/combat_presentation_config.gd`.

Change the existing cinematic field to default on:

```gdscript
var cinematic_enabled := true
```

Add fields after `cinematic_enabled`:

```gdscript
var particle_enabled := true
var camera_impulse_enabled := true
var slow_motion_enabled := true
var audio_cue_enabled := true
```

In `allows(event)`, add after the drag check:

```gdscript
	if not cinematic_enabled and (event_type == "cinematic_slash" or event.tags.has("cinematic")):
		return false
	if not particle_enabled and event_type == "particle_burst":
		return false
	if not camera_impulse_enabled and event_type == "camera_impulse":
		return false
	if not slow_motion_enabled and event_type == "slow_motion":
		return false
	if not audio_cue_enabled and event_type == "audio_cue":
		return false
```

Remove or replace the older final cinematic-only check so `cinematic_slash` is filtered even when it has no tag.

- [x] **Step 4: Implement layer playback placeholders**

Modify `scripts/presentation/combat_presentation_layer.gd`.

Add constants after the existing colors:

```gdscript
const SLASH_DURATION := 0.32
const PARTICLE_DURATION := 0.42
const CAMERA_IMPULSE_DURATION := 0.18
const SLOW_MOTION_DURATION := 0.35
const SLASH_COLOR := Color(0.9, 0.96, 1.0, 0.9)
const PARTICLE_COLOR := Color(0.46, 0.92, 0.66, 0.85)
```

Add fields after `_float_index`:

```gdscript
var active_slow_motion_scale: float = 1.0
var last_audio_cue_id: String = ""
var audio_cue_count: int = 0
var _slash_index := 0
var _particle_burst_index := 0
var _camera_base_position := Vector2.ZERO
```

Extend `play_event(event)`:

```gdscript
		"cinematic_slash":
			_show_cinematic_slash(event)
		"particle_burst":
			_show_particle_burst(event)
		"camera_impulse":
			_play_camera_impulse(event)
		"slow_motion":
			_record_slow_motion(event)
		"audio_cue":
			_record_audio_cue(event)
```

Add helpers:

```gdscript
func _show_cinematic_slash(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var slash := ColorRect.new()
	slash.name = "CinematicSlash_%s" % _slash_index
	_slash_index += 1
	slash.color = SLASH_COLOR
	slash.size = Vector2(74.0, 4.0)
	slash.pivot_offset = slash.size * 0.5
	slash.rotation = -0.55
	slash.position = _target_position(event.target_id) + Vector2(-20.0, -18.0)
	add_child(slash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "position:x", slash.position.x + 28.0, SLASH_DURATION)
	tween.tween_property(slash, "modulate:a", 0.0, SLASH_DURATION)
	tween.finished.connect(slash.queue_free)

func _show_particle_burst(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var burst_index := _particle_burst_index
	_particle_burst_index += 1
	var origin := _target_position(event.target_id) + Vector2(12.0, -10.0)
	for particle_index in range(5):
		var particle := ColorRect.new()
		particle.name = "ParticleBurst_%s_%s" % [burst_index, particle_index]
		particle.color = PARTICLE_COLOR
		particle.size = Vector2(5.0, 5.0)
		particle.position = origin
		add_child(particle)
		var angle := TAU * float(particle_index) / 5.0
		var offset := Vector2(cos(angle), sin(angle)) * 24.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", origin + offset, PARTICLE_DURATION)
		tween.tween_property(particle, "modulate:a", 0.0, PARTICLE_DURATION)
		tween.finished.connect(particle.queue_free)

func _play_camera_impulse(event: CombatPresentationEvent) -> void:
	_camera_base_position = position
	var strength := 4.0 * maxf(0.25, event.intensity)
	position = _camera_base_position + Vector2(strength, -strength * 0.5)
	var tween := create_tween()
	tween.tween_property(self, "position", _camera_base_position, CAMERA_IMPULSE_DURATION)

func _record_slow_motion(event: CombatPresentationEvent) -> void:
	active_slow_motion_scale = clampf(event.intensity, 0.1, 1.0)
	var tween := create_tween()
	tween.tween_interval(SLOW_MOTION_DURATION)
	tween.tween_callback(func(): active_slow_motion_scale = 1.0)

func _record_audio_cue(event: CombatPresentationEvent) -> void:
	last_audio_cue_id = String(event.payload.get("cue_id", event.text))
	audio_cue_count += 1
```

- [x] **Step 5: Add DebugOverlay toggles**

Modify `scripts/ui/debug_overlay.gd`.

Add after `DebugPresentationCinematic`:

```gdscript
	_add_presentation_toggle(box, "DebugPresentationParticles", "Particles", "particle_enabled")
	_add_presentation_toggle(box, "DebugPresentationCameraImpulse", "Camera Impulse", "camera_impulse_enabled")
	_add_presentation_toggle(box, "DebugPresentationSlowMotion", "Slow Motion", "slow_motion_enabled")
	_add_presentation_toggle(box, "DebugPresentationAudioCue", "Audio Cue", "audio_cue_enabled")
```

- [x] **Step 6: Run tests to verify GREEN for Task 2**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 7: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- New config fields exist and filter each event type.
- DebugOverlay exposes all new toggles.
- Layer handles `cinematic_slash`, `particle_burst`, `camera_impulse`, `slow_motion`, and `audio_cue`.
- Layer does not change `Engine.time_scale`.
- Visible events safely ignore missing targets.

Stage 2 Code Quality Review:

- Temporary nodes are predictably named and self-cleaning.
- Tween tests use explicit `_finish_processed_tweens`.
- Camera impulse restores original layer position.
- Audio cue state is inspectable without real audio dependencies.

- [x] **Step 8: Commit Task 2**

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_config.gd scripts/presentation/combat_presentation_layer.gd scripts/ui/debug_overlay.gd tests/unit/test_combat_presentation.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-28-high-presentation-polish-hooks.md
rtk proxy git commit -m "feat: play polish presentation placeholders"
```

## Task 3: CombatScreen Card Play Integration

**Files:**

- Modify: `scripts/ui/combat_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [x] **Step 1: Add failing combat integration smoke tests**

Append to `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_combat_screen_click_play_triggers_slash_polish_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_slash_polish_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	combat.presentation_layer.process_queue()
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0")
	var passed: bool = first_card != null and enemy_button != null and slash != null
	app.free()
	_delete_test_save("user://test_combat_slash_polish_save.json")
	return passed

func test_combat_screen_cinematic_disabled_filters_slash_but_plays_card(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_cinematic_disabled_save.json")
	app.game.presentation_config.cinematic_enabled = false
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.strike")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var enemy_hp_before: int = combat.session.state.enemies[0].current_hp
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0")
	var passed: bool = played \
		and combat.session.state.enemies[0].current_hp < enemy_hp_before \
		and slash == null
	app.free()
	_delete_test_save("user://test_combat_cinematic_disabled_save.json")
	return passed
```

- [x] **Step 2: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failure because card play does not yet enqueue resolver polish events.

- [x] **Step 3: Wire resolver into CombatScreen**

Modify `scripts/ui/combat_screen.gd`.

Add preload:

```gdscript
const CombatPresentationCueResolver := preload("res://scripts/presentation/combat_presentation_cue_resolver.gd")
```

Add field after `presentation_delta`:

```gdscript
var presentation_cue_resolver := CombatPresentationCueResolver.new()
```

Replace `_run_with_feedback(action: Callable, played_card_id: String = "")` with:

```gdscript
func _run_with_feedback(action: Callable, played_card_id: String = "", played_target_id: String = "") -> bool:
	var before := presentation_delta.capture_state(session.state)
	var played_card = session.catalog.get_card(played_card_id) if not played_card_id.is_empty() else null
	var succeeded := bool(action.call())
	if succeeded:
		var delta_events := presentation_delta.events_between(before, session.state)
		if not played_card_id.is_empty():
			var played_event := CombatPresentationEvent.new("card_played")
			played_event.card_id = played_card_id
			played_event.source_id = "player"
			played_event.target_id = played_target_id
			presentation_queue.enqueue(played_event)
			for event in presentation_cue_resolver.resolve_card_play(
				played_card,
				"player",
				played_target_id,
				delta_events
			):
				presentation_queue.enqueue(event)
		for event in delta_events:
			presentation_queue.enqueue(event)
	return succeeded
```

Update `try_play_dragged_card()`:

```gdscript
			return _run_with_feedback(enemy_action, card_id, "enemy:%s" % enemy_index)
```

and:

```gdscript
			return _run_with_feedback(player_action, card_id, "player")
```

and:

```gdscript
			return _run_with_feedback(upward_action, card_id, "player")
```

Update `_on_enemy_pressed(enemy_index)`:

```gdscript
	_run_with_feedback(action, card_id, "enemy:%s" % enemy_index)
```

Update `_on_player_target_pressed()`:

```gdscript
	_run_with_feedback(action, card_id, "player")
```

Leave `_on_end_turn_pressed()` targetless:

```gdscript
	_run_with_feedback(func(): return session.end_player_turn())
```

- [x] **Step 4: Run tests to verify GREEN for Task 3**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 5: Run Task 3 review gates**

Stage 1 Spec Compliance Review:

- Successful click card play can create slash polish feedback.
- Successful drag card play still works and respects `cinematic_enabled`.
- Enemy turn feedback still uses delta events only.
- `_run_with_feedback()` passes card data, source id, target id, and delta events to resolver.
- No gameplay rule file imports the resolver.

Stage 2 Code Quality Review:

- `played_card` is captured before action clears pending selection.
- Target id strings match bound presentation targets.
- Existing delta feedback remains enqueued.
- Integration does not duplicate card legality checks.

- [x] **Step 6: Commit Task 3**

Run:

```powershell
rtk proxy git add scripts/ui/combat_screen.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-28-high-presentation-polish-hooks.md
rtk proxy git commit -m "feat: trigger polish cues from card play"
```

## Task 4: Representative Explicit Card Cue Resources

**Files:**

- Modify: `resources/cards/sword/strike_sword.tres`
- Modify: `resources/cards/alchemy/toxic_pill.tres`
- Modify: `resources/cards/sword/heaven_cutting_arc.tres`
- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [x] **Step 1: Add failing catalog and smoke tests for explicit cues**

Append to `tests/unit/test_content_catalog.gd`:

```gdscript
func test_representative_cards_load_explicit_presentation_cues() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var strike := catalog.get_card("sword.strike")
	var toxic := catalog.get_card("alchemy.toxic_pill")
	var heaven := catalog.get_card("sword.heaven_cutting_arc")
	var passed: bool = strike != null \
		and toxic != null \
		and heaven != null \
		and strike.presentation_cues.size() == 1 \
		and strike.presentation_cues[0].event_type == "cinematic_slash" \
		and toxic.presentation_cues.size() == 1 \
		and toxic.presentation_cues[0].event_type == "particle_burst" \
		and heaven.presentation_cues.size() == 2 \
		and _has_card_cue(heaven, "slow_motion") \
		and _has_card_cue(heaven, "audio_cue")
	assert(passed)
	return passed
```

Add helper near the existing helpers:

```gdscript
func _has_card_cue(card: CardDef, event_type: String) -> bool:
	for cue in card.presentation_cues:
		if cue != null and cue.event_type == event_type:
			return true
	return false
```

Append to `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_explicit_slow_motion_and_audio_cues_are_recorded(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_explicit_slow_audio_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.heaven_cutting_arc"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.energy = 3
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.heaven_cutting_arc")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()
	var passed: bool = played \
		and combat.presentation_layer.active_slow_motion_scale < 1.0 \
		and combat.presentation_layer.last_audio_cue_id == "sword.heaven_cutting_arc"
	app.free()
	_delete_test_save("user://test_explicit_slow_audio_save.json")
	return passed
```

- [x] **Step 2: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: failures because representative resources do not yet define explicit cues.

- [x] **Step 3: Add explicit cue resources to sword strike**

Modify `resources/cards/sword/strike_sword.tres`.

Change header to load the cue script:

```ini
[gd_resource type="Resource" script_class="CardDef" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]
[ext_resource type="Script" path="res://scripts/data/card_presentation_cue_def.gd" id="3_cue"]
```

Add before `[resource]`:

```ini
[sub_resource type="Resource" id="Resource_slash_cue"]
script = ExtResource("3_cue")
event_type = "cinematic_slash"
target_mode = "played_target"
intensity = 1.0
cue_id = "sword.strike"
tags = Array[String](["cinematic"])
```

Add in `[resource]` after `effects`:

```ini
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_slash_cue")])
```

- [x] **Step 4: Add explicit cue resources to toxic pill**

Modify `resources/cards/alchemy/toxic_pill.tres`.

Change header and ext resources:

```ini
[gd_resource type="Resource" script_class="CardDef" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]
[ext_resource type="Script" path="res://scripts/data/card_presentation_cue_def.gd" id="3_cue"]
```

Add before `[resource]`:

```ini
[sub_resource type="Resource" id="Resource_particle_cue"]
script = ExtResource("3_cue")
event_type = "particle_burst"
target_mode = "played_target"
intensity = 1.0
cue_id = "alchemy.toxic_pill"
```

Add in `[resource]` after `effects`:

```ini
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_particle_cue")])
```

- [x] **Step 5: Add explicit slow-motion and audio cues to Heaven Cutting Arc**

Modify `resources/cards/sword/heaven_cutting_arc.tres`.

Change header and ext resources:

```ini
[gd_resource type="Resource" script_class="CardDef" load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/data/card_def.gd" id="1_card"]
[ext_resource type="Script" path="res://scripts/data/effect_def.gd" id="2_effect"]
[ext_resource type="Script" path="res://scripts/data/card_presentation_cue_def.gd" id="3_cue"]
```

Add before `[resource]`:

```ini
[sub_resource type="Resource" id="Resource_slow_cue"]
script = ExtResource("3_cue")
event_type = "slow_motion"
target_mode = "none"
intensity = 0.55
cue_id = "sword.heaven_cutting_arc"

[sub_resource type="Resource" id="Resource_audio_cue"]
script = ExtResource("3_cue")
event_type = "audio_cue"
target_mode = "none"
intensity = 1.0
cue_id = "sword.heaven_cutting_arc"
```

Add in `[resource]` after `effects`:

```ini
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_slow_cue"), SubResource("Resource_audio_cue")])
```

- [x] **Step 6: Run tests to verify GREEN for Task 4**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 7: Run Godot import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [x] **Step 8: Run Task 4 review gates**

Stage 1 Spec Compliance Review:

- Exactly the representative explicit cue resources exist.
- `sword.strike` has an explicit `cinematic_slash` cue.
- `alchemy.toxic_pill` has an explicit `particle_burst` cue.
- `sword.heaven_cutting_arc` has explicit `slow_motion` and `audio_cue` cues.
- No full catalog migration was performed.
- Resources load through `ContentCatalog`.

Stage 2 Code Quality Review:

- `.tres` load steps match ext resources and subresources.
- Cue ids are stable card ids.
- Cue tags are only used where filtering needs them.
- Explicit cue resources do not encode gameplay effects.

- [x] **Step 9: Commit Task 4**

Run:

```powershell
rtk proxy git add resources/cards/sword/strike_sword.tres resources/cards/alchemy/toxic_pill.tres resources/cards/sword/heaven_cutting_arc.tres tests/unit/test_content_catalog.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-28-high-presentation-polish-hooks.md
rtk proxy git commit -m "feat: add representative card polish cues"
```

## Task 5: Final Acceptance, Documentation, and Reviews

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-28-high-presentation-polish-hooks.md`

- [ ] **Step 1: Run all local tests**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 2: Run Godot import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 3: Update README Phase 2 progress**

Append under `## Phase 2 Progress`:

```markdown
- High-presentation polish hooks: complete; successful card play can now emit explicit or inferred polish events for slash, particle, camera impulse, slow-motion, and audio-cue placeholders without coupling presentation to combat rules.
```

Update `## Next Plans` to:

```markdown
## Next Plans

1. High-presentation asset pass: generated assets, richer sword-qi trails, medicine mist, camera tuning, and real audio routing.
2. Developer tools: card browser, enemy sandbox, event tester, reward inspector, save inspector.
3. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
```

- [ ] **Step 4: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [ ] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- `CardPresentationCueDef`, `CardDef.presentation_cues`, and `CombatPresentationCueResolver` exist.
- Explicit cue configuration takes priority over fallback inference.
- Fallback inference generates sword slash, alchemy/poison particles, and damage camera impulse.
- Fallback inference does not generate slow motion or audio cue.
- `CombatPresentationConfig` and `DebugOverlay` expose all new toggles.
- `CombatPresentationLayer` handles slash, particle, camera impulse, slow motion, and audio cue events.
- Successful click and drag card play can trigger polish events.
- `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` do not import presentation scripts.
- No real assets, global time scaling, persisted settings, enemy polish resolver, or full cue migration was added.

Stage 2 Code Quality Review:

- GDScript typing is clear for cue resources, resolver, config, and layer helpers.
- Cue event construction copies arrays and dictionaries safely.
- Fallback inference is deterministic and small.
- `CombatScreen` integration does not duplicate gameplay rules.
- Temporary layer nodes are predictably named and self-cleaning.
- Tests use explicit tween stepping and do not rely on arbitrary frame timing.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

- [ ] **Step 6: Commit acceptance docs**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-28-high-presentation-polish-hooks.md
rtk proxy git commit -m "docs: record high presentation polish hook acceptance"
```

## Final Acceptance Criteria

- Cards can define optional presentation cues through resources.
- Cards without presentation cues can still receive conservative automatic polish events.
- Successful player card play can generate `cinematic_slash`, `particle_burst`, and `camera_impulse` where appropriate.
- Explicit cue resources can trigger `slow_motion` and `audio_cue`.
- `CombatPresentationConfig` and `DebugOverlay` can disable each new event category.
- `CombatPresentationLayer` plays visible slash and particle placeholders, restores camera impulse offset, and records slow-motion/audio-cue state.
- No core combat rule class depends on presentation scripts.
- Existing click and drag card play flows remain functional.
- Existing local tests pass.
- Godot import check exits 0.

## Execution Handoff

After this plan is accepted, choose one execution mode:

1. **Subagent-Driven:** only if the user explicitly authorizes subagents. If used, dispatch one fresh subagent per task and keep all work on local `main`; do not create branches or worktrees.
2. **Inline Execution:** execute tasks in this session with `superpowers:executing-plans`, staying on local `main` and running the review gates after each completed Godot feature.
