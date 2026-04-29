# Enemy Intent Presentation Cues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add enemy intent polish cues for attack, block, and status intents through the existing combat presentation pipeline, and fix shared Godot checks so fresh worktrees import assets before tests.

**Architecture:** Keep combat rules presentation-free. `CombatScreen` captures enemy intent snapshots before end turn, a new `CombatPresentationIntentCueResolver` converts snapshots plus observed delta events into presentation events, and `CombatPresentationAssetCatalog` routes those events to existing project assets.

**Tech Stack:** Godot 4.6.2-stable, GDScript, PowerShell, existing lightweight Godot test runner.

---

## Project Constraints

- Work on branch `codex/enemy-intent-presentation-cues` in:
  - `C:/Users/56922/.config/superpowers/worktrees/Slay the Spire 2/enemy-intent-presentation-cues`
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- Do not stage Godot import-cache noise unless explicitly needed:
  - `assets/presentation/**/*.import` line-ending-only changes from `--import`
  - newly generated `.uid` files not required by this feature
- Do not delete local generated files without explicit user confirmation.
- Do not modify `CombatSession`, `CombatEngine`, `EffectExecutor`, or `CombatStatusRuntime` for presentation behavior.
- Do not add new art, audio, enemy intent resources, persisted settings, or global time scaling.
- After implementation, run the two-stage review required by `AGENTS.md`.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-enemy-intent-presentation-cues-design.md`

## Verification Commands

Run release script tests:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected:

```text
Release script tests passed.
```

Run shared Godot checks:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

The known malformed status intent test emits a Godot `ERROR` log intentionally. Treat the process exit code and `TESTS PASSED` line as the test result.

Run final import check directly:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Create:

- `scripts/presentation/combat_presentation_intent_cue_resolver.gd`: presentation-only resolver for enemy intent strings.

Modify:

- `tools/tests/test_release_scripts.ps1`: add release-check shape tests for `--import` before tests.
- `tools/ci/run_godot_checks.ps1`: import assets before the headless test runner.
- `tests/unit/test_combat_presentation.gd`: resolver and asset catalog tests.
- `tests/smoke/test_scene_flow.gd`: real combat end-turn polish tests.
- `scripts/presentation/combat_presentation_asset_catalog.gd`: enemy cue-id mappings.
- `scripts/ui/combat_screen.gd`: capture enemy intent snapshots and enqueue enemy polish.
- `README.md`: record accepted feature and updated next plans.
- `docs/superpowers/plans/2026-04-29-enemy-intent-presentation-cues.md`: mark steps complete while executing.

Do not modify:

- `scripts/combat/combat_session.gd`
- `scripts/combat/combat_engine.gd`
- `scripts/combat/effect_executor.gd`
- `scripts/combat/combat_status_runtime.gd`
- content resources or scene files

## Task 1: Shared Godot Checks Import Assets Before Tests

**Files:**

- Modify: `tools/tests/test_release_scripts.ps1`
- Modify: `tools/ci/run_godot_checks.ps1`

- [x] **Step 1: Add failing release script shape tests**

In `tools/tests/test_release_scripts.ps1`, add this helper after `Assert-FileContains`:

```powershell
function Assert-FileContainsBefore {
	param(
		[string]$RelativePath,
		[string]$FirstNeedle,
		[string]$SecondNeedle,
		[string]$Message
	)
	$path = Join-Path $ProjectRoot $RelativePath
	if (-not (Test-Path -LiteralPath $path)) {
		Add-Failure "$Message Missing file: $RelativePath"
		return
	}
	$text = Get-Content -LiteralPath $path -Raw
	$firstIndex = $text.IndexOf($FirstNeedle, [System.StringComparison]::Ordinal)
	$secondIndex = $text.IndexOf($SecondNeedle, [System.StringComparison]::Ordinal)
	if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
		Add-Failure "$Message Expected '$FirstNeedle' before '$SecondNeedle'."
	}
}
```

Then add these assertions near the existing `tools\ci\run_godot_checks.ps1` assertions:

```powershell
Assert-FileContains "tools\ci\run_godot_checks.ps1" "--import" "Godot check script should import assets before running tests."
Assert-FileContainsBefore "tools\ci\run_godot_checks.ps1" "--import" "res://scripts/testing/test_runner.gd" "Godot check script should import before the test runner."
```

- [x] **Step 2: Run script tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected: FAIL because `tools/ci/run_godot_checks.ps1` does not contain `--import`.

- [x] **Step 3: Import assets before tests**

In `tools/ci/run_godot_checks.ps1`, insert this block after the project root output and before `Running Godot test runner...`:

```powershell
Write-Host "Importing Godot assets..."
Invoke-GodotCommand -Arguments @(
	"--headless",
	"--path",
	$resolvedProjectRoot,
	"--import"
)
```

- [x] **Step 4: Run script tests to verify GREEN**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected:

```text
Release script tests passed.
```

- [x] **Step 5: Run shared Godot checks**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [x] **Step 6: Commit Task 1**

Run:

```powershell
rtk proxy git add tools/tests/test_release_scripts.ps1 tools/ci/run_godot_checks.ps1 docs/superpowers/plans/2026-04-29-enemy-intent-presentation-cues.md
rtk proxy git commit -m "build: import Godot assets before checks"
```

## Task 2: Enemy Intent Cue Resolver

**Files:**

- Modify: `tests/unit/test_combat_presentation.gd`
- Create: `scripts/presentation/combat_presentation_intent_cue_resolver.gd`

- [x] **Step 1: Register resolver preload in unit tests**

At the top of `tests/unit/test_combat_presentation.gd`, add:

```gdscript
const CombatPresentationIntentCueResolver := preload("res://scripts/presentation/combat_presentation_intent_cue_resolver.gd")
```

- [x] **Step 2: Add failing resolver tests**

Add these tests before `test_asset_catalog_resolves_exact_cue_before_event_fallback()`:

```gdscript
func test_intent_cue_resolver_emits_attack_slash_and_damage_camera() -> bool:
	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "player"
	damage.amount = 6
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "attack_6"},
	], [damage])
	var slash := _first_event(events, "cinematic_slash")
	var impulse := _first_event(events, "camera_impulse")
	var passed: bool = slash != null \
		and slash.source_id == "enemy:0" \
		and slash.target_id == "player" \
		and slash.amount == 6 \
		and slash.payload.get("cue_id") == "enemy.attack" \
		and slash.tags.has("enemy_intent") \
		and slash.tags.has("cinematic") \
		and impulse != null \
		and impulse.target_id == "" \
		and impulse.amount == 6 \
		and impulse.payload.get("cue_id") == "enemy.attack"
	assert(passed)
	return passed

func test_intent_cue_resolver_emits_block_burst_on_actor() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:1", "target_id": "player", "intent": "block_10"},
	], [])
	var burst := _first_event(events, "particle_burst")
	var passed: bool = events.size() == 1 \
		and burst != null \
		and burst.source_id == "enemy:1" \
		and burst.target_id == "enemy:1" \
		and burst.amount == 10 \
		and burst.payload.get("cue_id") == "enemy.block" \
		and burst.tags.has("block")
	assert(passed)
	return passed

func test_intent_cue_resolver_emits_player_status_burst() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "apply_status_poison_2_player"},
	], [])
	var burst := _first_event(events, "particle_burst")
	var passed: bool = events.size() == 1 \
		and burst != null \
		and burst.source_id == "enemy:0" \
		and burst.target_id == "player" \
		and burst.amount == 2 \
		and burst.status_id == "poison" \
		and burst.payload.get("cue_id") == "enemy.status.poison"
	assert(passed)
	return passed

func test_intent_cue_resolver_emits_self_status_burst_and_parses_multi_token_status() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "self_status_broken_stance_1"},
	], [])
	var burst := _first_event(events, "particle_burst")
	var passed: bool = events.size() == 1 \
		and burst != null \
		and burst.source_id == "enemy:0" \
		and burst.target_id == "enemy:0" \
		and burst.amount == 1 \
		and burst.status_id == "broken_stance" \
		and burst.payload.get("cue_id") == "enemy.status.broken_stance" \
		and burst.tags.has("self")
	assert(passed)
	return passed

func test_intent_cue_resolver_ignores_unknown_and_malformed_intents() -> bool:
	var events := CombatPresentationIntentCueResolver.new().resolve_enemy_turn([
		{"source_id": "enemy:0", "target_id": "player", "intent": "attack_bad"},
		{"source_id": "enemy:1", "target_id": "player", "intent": "apply_status_poison_player"},
		{"source_id": "enemy:2", "target_id": "player", "intent": "wait"},
	], [])
	var passed: bool = events.is_empty()
	assert(passed)
	return passed
```

Add this helper near `_event_count()`:

```gdscript
func _first_event(events: Array, event_type: String):
	for event in events:
		if event.event_type == event_type:
			return event
	return null
```

- [x] **Step 3: Run presentation unit tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because `combat_presentation_intent_cue_resolver.gd` does not exist.

- [x] **Step 4: Implement resolver**

Create `scripts/presentation/combat_presentation_intent_cue_resolver.gd`:

```gdscript
class_name CombatPresentationIntentCueResolver
extends RefCounted

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")

const ATTACK_CUE_ID := "enemy.attack"
const BLOCK_CUE_ID := "enemy.block"

func resolve_enemy_turn(
	intent_snapshots: Array[Dictionary],
	delta_events: Array[CombatPresentationEvent]
) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if intent_snapshots.is_empty():
		return events
	var max_player_damage := _max_player_damage(delta_events)
	for snapshot in intent_snapshots:
		var source_id := String(snapshot.get("source_id", ""))
		var intent := String(snapshot.get("intent", ""))
		if source_id.is_empty() or intent.is_empty():
			continue
		if intent.begins_with("attack_"):
			_append_attack_events(events, source_id, intent, max_player_damage)
		elif intent.begins_with("block_"):
			_append_block_event(events, source_id, intent)
		elif intent.begins_with("apply_status_"):
			_append_player_status_event(events, source_id, intent.trim_prefix("apply_status_"))
		elif intent.begins_with("self_status_"):
			_append_self_status_event(events, source_id, intent.trim_prefix("self_status_"))
	return events

func _append_attack_events(
	events: Array[CombatPresentationEvent],
	source_id: String,
	intent: String,
	max_player_damage: int
) -> void:
	var amount := _parse_positive_int(intent.trim_prefix("attack_"))
	if amount <= 0:
		return
	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.source_id = source_id
	slash.target_id = "player"
	slash.amount = amount
	slash.intensity = clampf(float(amount) / 8.0, 0.75, 1.8)
	slash.tags = ["enemy_intent", "cinematic"]
	slash.payload = {"cue_id": ATTACK_CUE_ID}
	events.append(slash)
	if max_player_damage > 0:
		var impulse := CombatPresentationEvent.new("camera_impulse")
		impulse.source_id = source_id
		impulse.amount = max_player_damage
		impulse.intensity = clampf(float(max_player_damage) / 8.0, 0.5, 2.0)
		impulse.tags = ["enemy_intent"]
		impulse.payload = {"cue_id": ATTACK_CUE_ID}
		events.append(impulse)

func _append_block_event(events: Array[CombatPresentationEvent], source_id: String, intent: String) -> void:
	var amount := _parse_positive_int(intent.trim_prefix("block_"))
	if amount <= 0:
		return
	var burst := CombatPresentationEvent.new("particle_burst")
	burst.source_id = source_id
	burst.target_id = source_id
	burst.amount = amount
	burst.intensity = clampf(float(amount) / 8.0, 0.6, 1.5)
	burst.tags = ["enemy_intent", "block"]
	burst.payload = {"cue_id": BLOCK_CUE_ID}
	events.append(burst)

func _append_player_status_event(
	events: Array[CombatPresentationEvent],
	source_id: String,
	payload: String
) -> void:
	var parsed := _parse_status_payload(payload, true)
	if parsed.is_empty():
		return
	var burst := _status_burst(source_id, "player", parsed)
	events.append(burst)

func _append_self_status_event(
	events: Array[CombatPresentationEvent],
	source_id: String,
	payload: String
) -> void:
	var parsed := _parse_status_payload(payload, false)
	if parsed.is_empty():
		return
	var burst := _status_burst(source_id, source_id, parsed)
	burst.tags.append("self")
	events.append(burst)

func _status_burst(source_id: String, target_id: String, parsed: Dictionary) -> CombatPresentationEvent:
	var status_id := String(parsed.get("status_id", ""))
	var amount := int(parsed.get("amount", 0))
	var burst := CombatPresentationEvent.new("particle_burst")
	burst.source_id = source_id
	burst.target_id = target_id
	burst.amount = amount
	burst.status_id = status_id
	burst.intensity = clampf(float(amount) / 3.0, 0.7, 1.5)
	burst.tags = ["enemy_intent", "status"]
	burst.payload = {"cue_id": "enemy.status.%s" % status_id}
	return burst

func _parse_status_payload(payload: String, requires_player_target: bool) -> Dictionary:
	var parts := payload.split("_")
	var amount_index := parts.size() - 1
	if requires_player_target:
		if parts.size() < 3 or String(parts[parts.size() - 1]) != "player":
			return {}
		amount_index = parts.size() - 2
	if amount_index <= 0:
		return {}
	var amount := _parse_positive_int(String(parts[amount_index]))
	if amount <= 0:
		return {}
	var status_id := _join_status_parts(parts, amount_index)
	if status_id.is_empty():
		return {}
	return {
		"status_id": status_id,
		"amount": amount,
	}

func _join_status_parts(parts: PackedStringArray, end_exclusive: int) -> String:
	var status_parts: Array[String] = []
	for index in range(end_exclusive):
		status_parts.append(String(parts[index]))
	return "_".join(status_parts)

func _parse_positive_int(text: String) -> int:
	if not text.is_valid_int():
		return -1
	return int(text)

func _max_player_damage(delta_events: Array[CombatPresentationEvent]) -> int:
	var max_damage := 0
	for event in delta_events:
		if event == null:
			continue
		if event.event_type == "damage_number" and event.target_id == "player":
			max_damage = max(max_damage, int(event.amount))
	return max_damage
```

- [x] **Step 5: Run presentation unit tests to verify GREEN for resolver**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: the new resolver tests pass. Other feature tests may still fail until later tasks if they reference asset mappings or integration not implemented yet.

- [ ] **Step 6: Commit Task 2**

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_intent_cue_resolver.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-29-enemy-intent-presentation-cues.md
rtk proxy git commit -m "feat: add enemy intent cue resolver"
```

## Task 3: Enemy Cue Asset Catalog Mappings

**Files:**

- Modify: `tests/unit/test_combat_presentation.gd`
- Modify: `scripts/presentation/combat_presentation_asset_catalog.gd`

- [ ] **Step 1: Add failing asset catalog tests**

Add these tests before `test_asset_catalog_registered_resources_load()`:

```gdscript
func test_asset_catalog_resolves_enemy_intent_cues() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var attack := CombatPresentationEvent.new("cinematic_slash")
	attack.payload = {"cue_id": "enemy.attack"}
	var attack_impulse := CombatPresentationEvent.new("camera_impulse")
	attack_impulse.payload = {"cue_id": "enemy.attack"}
	var block := CombatPresentationEvent.new("particle_burst")
	block.payload = {"cue_id": "enemy.block"}
	var poison := CombatPresentationEvent.new("particle_burst")
	poison.payload = {"cue_id": "enemy.status.poison"}
	var broken := CombatPresentationEvent.new("particle_burst")
	broken.payload = {"cue_id": "enemy.status.broken_stance"}
	var focus := CombatPresentationEvent.new("particle_burst")
	focus.payload = {"cue_id": "enemy.status.sword_focus"}

	var attack_asset := catalog.resolve(attack)
	var impulse_asset := catalog.resolve(attack_impulse)
	var block_asset := catalog.resolve(block)
	var poison_asset := catalog.resolve(poison)
	var broken_asset := catalog.resolve(broken)
	var focus_asset := catalog.resolve(focus)

	var passed: bool = attack_asset.get("texture_path", "") == "res://assets/presentation/textures/slash_gold.png" \
		and float(impulse_asset.get("strength", 0.0)) > 4.0 \
		and block_asset.get("texture_path", "") == "res://assets/presentation/textures/mist_green.png" \
		and poison_asset.get("texture_path", "") == "res://assets/presentation/textures/mist_violet.png" \
		and not broken_asset.is_empty() \
		and not focus_asset.is_empty()
	assert(passed)
	return passed

func test_asset_catalog_unknown_enemy_status_uses_particle_fallback() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var event := CombatPresentationEvent.new("particle_burst")
	event.payload = {"cue_id": "enemy.status.unknown"}
	var asset := catalog.resolve(event)
	var passed: bool = asset.get("texture_path", "") == "res://assets/presentation/textures/mist_green.png" \
		and int(asset.get("particle_count", 0)) == 6
	assert(passed)
	return passed
```

- [ ] **Step 2: Run presentation unit tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because enemy cue-id mappings are missing.

- [ ] **Step 3: Add enemy cue mappings**

In `scripts/presentation/combat_presentation_asset_catalog.gd`, add these entries to `_cue_assets`:

```gdscript
	"cinematic_slash:enemy.attack": {
		"texture_path": TEXTURE_SLASH_GOLD,
		"size": Vector2(122.0, 40.0),
		"travel": Vector2(-28.0, 6.0),
		"rotation": 0.45,
		"duration": 0.24,
		"scale_to": Vector2(1.14, 1.04),
		"color": Color(1.0, 0.86, 0.58, 0.95),
	},
	"camera_impulse:enemy.attack": {
		"strength": 5.5,
		"duration": 0.16,
		"direction": Vector2(-1.0, 0.45),
	},
	"particle_burst:enemy.block": {
		"texture_path": TEXTURE_MIST_GREEN,
		"particle_count": 5,
		"radius": 22.0,
		"duration": 0.36,
		"size": Vector2(18.0, 18.0),
		"color": Color(0.7, 1.0, 0.78, 0.9),
	},
	"particle_burst:enemy.status.poison": {
		"texture_path": TEXTURE_MIST_VIOLET,
		"particle_count": 7,
		"radius": 28.0,
		"duration": 0.44,
		"size": Vector2(20.0, 20.0),
		"color": Color(0.78, 0.65, 1.0, 0.92),
	},
	"particle_burst:enemy.status.broken_stance": {
		"texture_path": TEXTURE_SLASH_GOLD,
		"particle_count": 4,
		"radius": 24.0,
		"duration": 0.32,
		"size": Vector2(22.0, 12.0),
		"color": Color(1.0, 0.82, 0.48, 0.9),
	},
	"particle_burst:enemy.status.sword_focus": {
		"texture_path": TEXTURE_SLASH_CYAN,
		"particle_count": 4,
		"radius": 20.0,
		"duration": 0.34,
		"size": Vector2(20.0, 12.0),
		"color": Color(0.76, 0.95, 1.0, 0.9),
	},
```

- [ ] **Step 4: Run presentation unit tests to verify GREEN for mappings**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: the new asset catalog tests pass.

- [ ] **Step 5: Commit Task 3**

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_asset_catalog.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-29-enemy-intent-presentation-cues.md
rtk proxy git commit -m "feat: map enemy intent presentation assets"
```

## Task 4: CombatScreen Enemy Turn Integration

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/ui/combat_screen.gd`

- [ ] **Step 1: Add failing smoke tests for enemy end-turn polish**

Add these tests after `test_explicit_slow_motion_and_audio_cues_are_recorded()`:

```gdscript
func test_combat_screen_end_turn_triggers_enemy_attack_polish(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_attack_polish_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["training_puppet"],
		"seed_value": 101,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var hp_before: int = combat.session.state.player.current_hp
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0") as TextureRect
	var passed: bool = end_turn != null \
		and combat.session.state.player.current_hp < hp_before \
		and slash != null \
		and slash.texture != null
	app.free()
	_delete_test_save("user://test_enemy_attack_polish_save.json")
	return passed

func test_combat_screen_end_turn_triggers_enemy_block_polish(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_block_polish_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["stone_grove_guardian"],
		"seed_value": 102,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = end_turn != null \
		and combat.session.state.enemies[0].block > 0 \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_enemy_block_polish_save.json")
	return passed

func test_combat_screen_end_turn_triggers_enemy_status_polish(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_status_polish_save.json")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["plague_jade_imp"],
		"seed_value": 103,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = end_turn != null \
		and int(combat.session.state.player.statuses.get("poison", 0)) > 0 \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_enemy_status_polish_save.json")
	return passed

func test_enemy_intent_polish_respects_particle_toggle(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_enemy_particle_toggle_save.json")
	app.game.presentation_config.particle_enabled = false
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.guard"],
		"enemy_ids": ["stone_grove_guardian"],
		"seed_value": 104,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.guard")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var end_turn := _find_node_by_name(combat, "EndTurnButton") as Button
	if end_turn != null:
		end_turn.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0")
	var passed: bool = end_turn != null \
		and combat.session.state.enemies[0].block > 0 \
		and particle == null
	app.free()
	_delete_test_save("user://test_enemy_particle_toggle_save.json")
	return passed
```

- [ ] **Step 2: Run smoke tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because End Turn does not generate enemy intent polish yet.

- [ ] **Step 3: Add intent resolver to CombatScreen**

At the top of `scripts/ui/combat_screen.gd`, add:

```gdscript
const CombatPresentationIntentCueResolver := preload("res://scripts/presentation/combat_presentation_intent_cue_resolver.gd")
```

Near the existing presentation fields, add:

```gdscript
var presentation_intent_resolver := CombatPresentationIntentCueResolver.new()
```

- [ ] **Step 4: Capture enemy intent snapshots before end turn**

Add this helper near `_on_end_turn_pressed()`:

```gdscript
func _capture_enemy_intent_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if session == null:
		return snapshots
	for enemy_index in range(session.state.enemies.size()):
		var enemy = session.state.enemies[enemy_index]
		if enemy == null or enemy.is_defeated():
			continue
		var source_id := "enemy:%s" % enemy_index
		var intent := session.get_enemy_intent(enemy_index)
		if intent.is_empty():
			continue
		snapshots.append({
			"source_id": source_id,
			"target_id": "player",
			"intent": intent,
		})
	return snapshots
```

Replace `_on_end_turn_pressed()` with:

```gdscript
func _on_end_turn_pressed() -> void:
	var intent_snapshots := _capture_enemy_intent_snapshots()
	_run_with_feedback(func(): return session.end_player_turn(), "", "", intent_snapshots)
	_refresh()
```

- [ ] **Step 5: Enqueue enemy intent polish before delta events**

Change `_run_with_feedback()` signature to:

```gdscript
func _run_with_feedback(
	action: Callable,
	played_card_id: String = "",
	played_target_id: String = "",
	enemy_intent_snapshots: Array[Dictionary] = []
) -> bool:
```

Inside the `if succeeded:` block, after player card polish and before the `for event in delta_events:` loop, add:

```gdscript
		if not enemy_intent_snapshots.is_empty():
			for event in presentation_intent_resolver.resolve_enemy_turn(enemy_intent_snapshots, delta_events):
				presentation_queue.enqueue(event)
```

The resulting order should be:

1. Player `card_played` and card polish, when applicable.
2. Enemy intent polish, when snapshots are present.
3. Delta events.

- [ ] **Step 6: Run full tests to verify GREEN**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [ ] **Step 7: Commit Task 4**

Run:

```powershell
rtk proxy git add scripts/ui/combat_screen.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-29-enemy-intent-presentation-cues.md
rtk proxy git commit -m "feat: route enemy intent presentation cues"
```

## Task 5: Acceptance Docs, Review, and Final Verification

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-enemy-intent-presentation-cues.md`

- [ ] **Step 1: Update README progress**

In `README.md`, add this Phase 2 progress bullet after the release readiness foundation bullet:

```markdown
- Enemy intent presentation cues: complete; enemy attack, block, and status intents now route presentation-only polish cues through the existing queue and asset catalog, while shared Godot checks import assets before running tests in fresh worktrees.
```

Update `## Next Plans` to:

```markdown
## Next Plans

1. Presentation expansion: full card cue migration, intent icons, card art, richer combat backgrounds, reduced-motion profiles, and formal audio mixing.
2. Release expansion: artifact packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
```

- [ ] **Step 2: Run release script tests**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected:

```text
Release script tests passed.
```

- [ ] **Step 3: Run shared Godot checks**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [ ] **Step 4: Run direct import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 5: Verify presentation boundary**

Run:

```powershell
rtk proxy rg -n "presentation|CombatPresentation" scripts/combat scripts/data/enemy_def.gd scripts/data/effect_def.gd
```

Expected: no matches in `scripts/combat`, `enemy_def.gd`, or `effect_def.gd`.

- [ ] **Step 6: Verify no new assets were added**

Run:

```powershell
rtk proxy git status --short
rtk proxy git diff --name-only -- assets/presentation resources scenes
```

Expected: no intentional new files under `assets/presentation`, `resources`, or `scenes` for this feature. Ignore existing Godot import-cache line-ending noise unless a real content diff appears.

- [ ] **Step 7: Run Stage 1 Spec Compliance Review**

Verify:

- Shared Godot checks import assets before running tests.
- `CombatPresentationIntentCueResolver` exists and is separate from card cue resolution.
- Attack, block, player status, and self status intent strings generate the specified events.
- Malformed or unknown intents generate no presentation errors.
- Asset catalog mappings exist for the new enemy cue ids.
- `CombatScreen` captures intent snapshots before end turn and only emits enemy polish on successful actions.
- Enemy intent polish is enqueued before delta events.
- No combat rule class imports presentation scripts.
- No new art/audio/mixer/settings systems were added.

Stop and fix any missing requirement before continuing.

- [ ] **Step 8: Run Stage 2 Code Quality Review**

Classify any findings as Critical, Important, or Minor. Check:

- GDScript typing for resolver methods and helper functions.
- Parser logic is deterministic, small, and does not duplicate combat execution rules.
- Event payloads, tags, and dictionaries are not aliased.
- CombatScreen integration keeps player card polish and enemy intent polish paths readable.
- Tests use real combat flows where possible and avoid arbitrary timing.
- Release-check script tests would fail if `--import` is removed or reordered after tests.

Fix all Critical and Important findings before acceptance.

- [ ] **Step 9: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after each step has been completed and verified.

- [ ] **Step 10: Commit final acceptance docs**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-29-enemy-intent-presentation-cues.md
rtk proxy git commit -m "docs: record enemy intent presentation acceptance"
```

## Final Acceptance Criteria

- Fresh worktrees and CI can run shared Godot checks after importing assets first.
- Enemy attack intents can produce slash and camera impulse polish.
- Enemy block intents can produce defensive particle polish.
- Enemy player-status and self-status intents can produce status particle polish.
- Existing presentation toggles filter the reused event categories.
- Existing damage, block, status number, flash, and pulse feedback remains intact.
- Existing click and drag player card play flows remain functional.
- No core combat rule class depends on presentation scripts.
- Full local tests pass through the shared check script.
- Godot import check exits 0.
