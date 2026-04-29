# Reduced Motion Presentation Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a runtime reduced-motion presentation profile that filters high-motion combat polish while preserving readable low-motion feedback.

**Architecture:** Keep the profile at the existing `CombatPresentationConfig.allows(event)` boundary so player card polish and enemy intent polish inherit the same behavior through `CombatPresentationQueue`. `CombatPresentationLayer`, cue resolvers, and combat rule classes stay profile-agnostic.

**Tech Stack:** Godot 4.6.2-stable, GDScript, PowerShell, existing lightweight Godot test runner.

---

## Project Constraints

- Work on branch `codex/reduced-motion-presentation-profiles`.
- Prefix shell commands with `rtk`.
- Use red/green TDD for behavior changes.
- Do not stage Godot import-cache noise unless explicitly needed:
  - `assets/presentation/**/*.import` line-ending-only changes from `--import`
  - newly generated `.uid` files not required by this feature
- Do not delete local generated files without explicit user confirmation.
- Do not modify combat rules for presentation behavior:
  - `scripts/combat/combat_session.gd`
  - `scripts/combat/combat_engine.gd`
  - `scripts/combat/effect_executor.gd`
  - `scripts/combat/combat_status_runtime.gd`
- Do not add new art, audio, settings persistence, save migration, OS preference integration, or global `Engine.time_scale` changes.
- After implementation, run the two-stage review required by `AGENTS.md`.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-reduced-motion-presentation-profiles-design.md`

## Verification Commands

Run shared Godot checks:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected final result:

```text
TESTS PASSED
Godot checks passed.
```

The known malformed status intent test emits a Godot `ERROR` log intentionally. Treat the process exit code and `TESTS PASSED` line as the test result.

Run final import check directly:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Modify:

- `tests/unit/test_combat_presentation.gd`: motion profile unit tests for config and queue filtering.
- `tests/smoke/test_scene_flow.gd`: DebugOverlay profile toggle test and combat smoke coverage.
- `scripts/presentation/combat_presentation_config.gd`: profile constants, typed setter, reduced-motion filtering.
- `scripts/ui/debug_overlay.gd`: reduced-motion debug checkbox.
- `README.md`: accepted progress and updated next plans.
- `docs/superpowers/plans/2026-04-29-reduced-motion-presentation-profiles.md`: mark steps complete while executing.

Do not modify:

- `scripts/presentation/combat_presentation_queue.gd`
- `scripts/presentation/combat_presentation_layer.gd`
- `scripts/presentation/combat_presentation_cue_resolver.gd`
- `scripts/presentation/combat_presentation_intent_cue_resolver.gd`
- `scripts/combat/*`
- content resources or scene files

## Task 1: Write Failing Reduced-Motion Tests

**Files:**

- Modify: `tests/unit/test_combat_presentation.gd`
- Modify: `tests/smoke/test_scene_flow.gd`

- [ ] **Step 1: Add failing config and queue unit tests**

In `tests/unit/test_combat_presentation.gd`, add these tests after `test_config_filters_polish_event_categories()`:

```gdscript
func test_config_defaults_to_full_motion_profile() -> bool:
	var config := CombatPresentationConfig.new()
	var passed: bool = config.motion_profile == CombatPresentationConfig.MOTION_PROFILE_FULL \
		and not config.is_reduced_motion()
	assert(passed)
	return passed

func test_config_set_motion_profile_validates_known_values() -> bool:
	var config := CombatPresentationConfig.new()
	config.set_motion_profile(CombatPresentationConfig.MOTION_PROFILE_REDUCED)
	var reduced_applied := config.motion_profile == CombatPresentationConfig.MOTION_PROFILE_REDUCED \
		and config.is_reduced_motion()
	config.set_motion_profile("unknown_profile")
	var unknown_reset := config.motion_profile == CombatPresentationConfig.MOTION_PROFILE_FULL \
		and not config.is_reduced_motion()
	var passed: bool = reduced_applied and unknown_reset
	assert(passed)
	return passed

func test_reduced_motion_filters_high_motion_events_but_keeps_low_motion_feedback() -> bool:
	var config := CombatPresentationConfig.new()
	config.set_motion_profile(CombatPresentationConfig.MOTION_PROFILE_REDUCED)
	var queue := CombatPresentationQueue.new()
	queue.config = config

	queue.enqueue(CombatPresentationEvent.new("cinematic_slash"))
	var tagged := CombatPresentationEvent.new("card_hovered")
	tagged.tags = ["cinematic"]
	queue.enqueue(tagged)
	queue.enqueue(CombatPresentationEvent.new("particle_burst"))
	queue.enqueue(CombatPresentationEvent.new("camera_impulse"))
	queue.enqueue(CombatPresentationEvent.new("slow_motion"))
	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	queue.enqueue(CombatPresentationEvent.new("block_number"))
	queue.enqueue(CombatPresentationEvent.new("status_number"))
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.enqueue(CombatPresentationEvent.new("status_badge_pulse"))
	queue.enqueue(CombatPresentationEvent.new("target_highlighted"))
	queue.enqueue(CombatPresentationEvent.new("target_unhighlighted"))
	queue.enqueue(CombatPresentationEvent.new("card_hovered"))
	queue.enqueue(CombatPresentationEvent.new("audio_cue"))

	var event_types := _event_types(queue.drain())
	var passed: bool = event_types == [
		"damage_number",
		"block_number",
		"status_number",
		"combatant_flash",
		"status_badge_pulse",
		"target_highlighted",
		"target_unhighlighted",
		"card_hovered",
		"audio_cue",
	]
	assert(passed)
	return passed

func test_reduced_motion_preserves_individual_category_toggles() -> bool:
	var config := CombatPresentationConfig.new()
	config.set_motion_profile(CombatPresentationConfig.MOTION_PROFILE_REDUCED)
	config.floating_text_enabled = false
	config.flash_enabled = false
	config.audio_cue_enabled = false
	var queue := CombatPresentationQueue.new()
	queue.config = config

	queue.enqueue(CombatPresentationEvent.new("damage_number"))
	queue.enqueue(CombatPresentationEvent.new("combatant_flash"))
	queue.enqueue(CombatPresentationEvent.new("audio_cue"))
	queue.enqueue(CombatPresentationEvent.new("target_highlighted"))

	var event_types := _event_types(queue.drain())
	var passed: bool = event_types == ["target_highlighted"]
	assert(passed)
	return passed
```

Add this helper near the existing helper functions at the bottom:

```gdscript
func _event_types(events: Array) -> Array[String]:
	var event_types: Array[String] = []
	for event in events:
		event_types.append(String(event.event_type))
	return event_types
```

- [ ] **Step 2: Add failing DebugOverlay smoke test**

In `tests/smoke/test_scene_flow.gd`, add this test after `test_debug_overlay_updates_polish_presentation_config()`:

```gdscript
func test_debug_overlay_updates_reduced_motion_profile(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_reduced_motion_save.json")
	var debug_overlay: Node = app.get_node_or_null("DebugLayer/DebugOverlay")
	var reduced_toggle := _find_node_by_name(debug_overlay, "DebugPresentationReducedMotion") as CheckBox
	var initially_full := reduced_toggle != null \
		and not reduced_toggle.button_pressed \
		and app.game.presentation_config.motion_profile == "full"
	if reduced_toggle != null:
		reduced_toggle.button_pressed = true
		reduced_toggle.toggled.emit(true)
	var reduced_applied := app.game.presentation_config.motion_profile == "reduced" \
		and app.game.presentation_config.is_reduced_motion()
	if reduced_toggle != null:
		reduced_toggle.button_pressed = false
		reduced_toggle.toggled.emit(false)
	var full_restored := app.game.presentation_config.motion_profile == "full" \
		and not app.game.presentation_config.is_reduced_motion()
	var passed: bool = initially_full and reduced_applied and full_restored
	app.free()
	_delete_test_save("user://test_debug_reduced_motion_save.json")
	return passed
```

- [ ] **Step 3: Add failing combat smoke tests**

In `tests/smoke/test_scene_flow.gd`, add these tests after `test_explicit_slow_motion_and_audio_cues_are_recorded()`:

```gdscript
func test_reduced_motion_filters_card_play_motion_but_keeps_damage_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_reduced_motion_card_feedback_save.json")
	app.game.presentation_config.set_motion_profile("reduced")
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
	var layer_position_before: Vector2 = combat.presentation_layer.position
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()

	var float_text := _find_node_by_name(combat.presentation_layer, "FloatText_0") as Label
	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0")
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0")
	var passed: bool = played \
		and combat.session.state.enemies[0].current_hp < enemy_hp_before \
		and float_text != null \
		and float_text.text.begins_with("-") \
		and slash == null \
		and particle == null \
		and combat.presentation_layer.position == layer_position_before \
		and is_equal_approx(combat.presentation_layer.active_slow_motion_scale, 1.0)
	app.free()
	_delete_test_save("user://test_reduced_motion_card_feedback_save.json")
	return passed

func test_reduced_motion_filters_explicit_slow_motion_but_keeps_audio_cue(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_reduced_motion_slow_audio_save.json")
	app.game.presentation_config.set_motion_profile("reduced")
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
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.heaven_cutting_arc")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()

	var wash := _find_node_by_name(combat.presentation_layer, "SlowMotionWash_0")
	var audio_player := _find_node_by_name(combat.presentation_layer, "PresentationAudioPlayer") as AudioStreamPlayer
	var passed: bool = played \
		and wash == null \
		and is_equal_approx(combat.presentation_layer.active_slow_motion_scale, 1.0) \
		and combat.presentation_layer.last_audio_cue_id == "sword.heaven_cutting_arc" \
		and combat.presentation_layer.audio_cue_count == 1 \
		and audio_player != null \
		and audio_player.stream != null
	app.free()
	_delete_test_save("user://test_reduced_motion_slow_audio_save.json")
	return passed
```

- [ ] **Step 4: Run tests to verify RED**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: `TESTS FAILED` because the motion profile API and `DebugPresentationReducedMotion` do not exist yet.

Do not commit failing tests.

## Task 2: Implement Reduced-Motion Profile

**Files:**

- Modify: `scripts/presentation/combat_presentation_config.gd`
- Modify: `scripts/ui/debug_overlay.gd`

- [ ] **Step 1: Implement motion profile API and filtering**

Modify `scripts/presentation/combat_presentation_config.gd`.

Add constants before the existing vars:

```gdscript
const MOTION_PROFILE_FULL := "full"
const MOTION_PROFILE_REDUCED := "reduced"
```

Add this var after the constants:

```gdscript
var motion_profile := MOTION_PROFILE_FULL
```

Add this reduced-motion check inside `allows(event)` after `var event_type := String(event.event_type)` and before the individual category filters:

```gdscript
	if is_reduced_motion() and _is_high_motion_event(event_type, event):
		return false
```

Add these methods before `_is_floating_text_event()`:

```gdscript
func set_motion_profile(profile: String) -> void:
	if profile == MOTION_PROFILE_REDUCED:
		motion_profile = MOTION_PROFILE_REDUCED
	else:
		motion_profile = MOTION_PROFILE_FULL

func is_reduced_motion() -> bool:
	return motion_profile == MOTION_PROFILE_REDUCED

func _is_high_motion_event(event_type: String, event: Variant) -> bool:
	return event_type == "cinematic_slash" \
		or event_type == "particle_burst" \
		or event_type == "camera_impulse" \
		or event_type == "slow_motion" \
		or event.tags.has("cinematic")
```

Keep the existing individual toggle checks intact.

- [ ] **Step 2: Implement DebugOverlay reduced-motion toggle**

Modify `scripts/ui/debug_overlay.gd`.

Add this preload below `SceneRouterScript`:

```gdscript
const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")
```

In `_ready()`, add this call after `DebugPresentationEnabled` and before the other presentation toggles:

```gdscript
	_add_reduced_motion_toggle(box)
```

Add this helper after `_add_presentation_toggle()`:

```gdscript
func _add_reduced_motion_toggle(box: VBoxContainer) -> void:
	var app := _get_app()
	if app == null or app.game == null or app.game.presentation_config == null:
		return
	var toggle := CheckBox.new()
	toggle.name = "DebugPresentationReducedMotion"
	toggle.text = "Debug: Reduced Motion"
	toggle.button_pressed = app.game.presentation_config.is_reduced_motion()
	toggle.toggled.connect(func(enabled: bool):
		var profile := CombatPresentationConfig.MOTION_PROFILE_REDUCED if enabled else CombatPresentationConfig.MOTION_PROFILE_FULL
		app.game.presentation_config.set_motion_profile(profile)
	)
	box.add_child(toggle)
```

- [ ] **Step 3: Run tests to verify GREEN**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [ ] **Step 4: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- `full` and `reduced` profile constants exist.
- `motion_profile` defaults to `full`.
- unknown profile strings fall back to `full`.
- reduced motion filters `cinematic_slash`, cinematic-tagged events, `particle_burst`, `camera_impulse`, and `slow_motion`.
- reduced motion preserves low-motion events and audio cues when their individual toggles allow them.
- individual category toggles still filter in reduced mode.
- DebugOverlay creates `DebugPresentationReducedMotion`.
- the toggle does not mutate individual category booleans.
- no queue, layer, resolver, or combat rule class changed.

Stage 2 Code Quality Review:

- profile API has typed function parameters and returns.
- profile constants are used instead of repeated strings in runtime implementation.
- high-motion filtering is centralized in one helper.
- debug helper follows the existing `_add_presentation_toggle()` pattern.
- tests cover allowed and rejected categories, debug UI, and real combat presentation.

- [ ] **Step 5: Commit Tasks 1 and 2**

Run:

```powershell
rtk git add scripts/presentation/combat_presentation_config.gd scripts/ui/debug_overlay.gd tests/unit/test_combat_presentation.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-29-reduced-motion-presentation-profiles.md
rtk git commit -m "feat: add reduced motion presentation profile"
```

## Task 3: Documentation, Verification, and Acceptance

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-reduced-motion-presentation-profiles.md`

- [ ] **Step 1: Update README progress**

Add this bullet under `## Phase 2 Progress` after the enemy intent presentation cues bullet:

```markdown
- Reduced-motion presentation profiles: complete; combat presentation now has a runtime full/reduced motion profile that filters high-motion slash, particle, camera impulse, and slow-motion polish while preserving readable low-motion feedback and independent audio-cue control.
```

Update `## Next Plans` to remove reduced-motion profiles from the presentation expansion item:

```markdown
## Next Plans

1. Presentation expansion: full card cue migration, intent icons, card art, richer combat backgrounds, and formal audio mixing.
2. Release expansion: artifact packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
```

- [ ] **Step 2: Run full local verification**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [ ] **Step 3: Run final direct import check**

Run:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 4: Verify presentation boundary**

Run:

```powershell
rtk rg -n "presentation|CombatPresentation|motion_profile|MOTION_PROFILE|reduced" scripts/combat
```

Expected: no output. `rg` may exit 1 when there are no matches; that is acceptable for this boundary check.

- [ ] **Step 5: Run final two-stage review**

Stage 1 Spec Compliance Review:

- `CombatPresentationConfig` has `full` and `reduced` profiles.
- `full` preserves current behavior.
- `reduced` filters only `cinematic_slash`, cinematic-tagged events, `particle_burst`, `camera_impulse`, and `slow_motion`.
- low-motion feedback and audio cues remain allowed when their individual toggles allow them.
- individual toggles remain non-destructive and functional in both profiles.
- DebugOverlay exposes `DebugPresentationReducedMotion`.
- CombatScreen, cue resolvers, and combat rule classes do not contain reduced-motion branching.
- README progress and Next Plans match shipped scope.

If any item fails, fix it before continuing to Stage 2.

Stage 2 Code Quality Review:

- GDScript profile API is typed.
- profile names are centralized constants in runtime code.
- high-motion filtering is deterministic and readable.
- tests cover allowed and rejected categories, debug UI, and real combat presentation.
- no save, settings, platform, resource, or gameplay code was touched.
- no unrelated refactors were included.

Classify all issues as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

- [ ] **Step 6: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [ ] **Step 7: Commit final acceptance docs**

Run:

```powershell
rtk git add README.md docs/superpowers/plans/2026-04-29-reduced-motion-presentation-profiles.md
rtk git commit -m "docs: record reduced motion presentation acceptance"
```

## Final Acceptance Criteria

- Reduced motion is off by default and current presentation behavior remains unchanged in `full`.
- A config can switch to reduced motion at runtime.
- Reduced motion filters slash, cinematic-tagged, particle, camera impulse, and slow-motion events before layer playback.
- Reduced motion preserves damage/block/status numbers, flash, status pulse, target highlight, card hover/drag bookkeeping, and audio cues when their individual toggles allow them.
- DebugOverlay can toggle between full and reduced profiles.
- Existing Godot tests pass.
- Godot import/check exits 0.
- No core combat rule class imports presentation scripts or contains reduced-motion logic.
