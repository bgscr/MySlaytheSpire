# Card Cue Migration Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every default catalog card explicit presentation cues so card polish is data-owned instead of fallback-inferred.

**Architecture:** Keep the current presentation runtime unchanged. Add tests that prove catalog-wide cue coverage, then migrate card `.tres` resources to explicit `CardPresentationCueDef` subresources using card ids as cue ids. Leave resolver fallback intact for future cards and test fixtures.

**Tech Stack:** Godot 4.6.2-stable, GDScript resources, existing lightweight Godot test runner, PowerShell release check wrapper.

---

## Project Constraints

- Work on branch `codex/continue-presentation-expansion`.
- Prefix shell commands with `rtk`.
- Use red/green TDD for behavior changes and resource migrations.
- Make surgical resource edits only. Do not reformat unrelated resource sections.
- Do not add new art, audio, settings persistence, combat rules, event logic, save migration, or UI systems.
- Do not remove `CombatPresentationCueResolver` fallback behavior.
- After implementation, run the two-stage review from `AGENTS.md`.

## Reference Spec

- `docs/superpowers/specs/2026-05-01-card-cue-migration-foundation-design.md`

## Verification Commands

Run shared Godot checks:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected final result:

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

Modify:

- `tests/unit/test_content_catalog.gd`: catalog-wide cue coverage tests.
- `tests/unit/test_combat_presentation.gd`: resolver tests for representative migrated cards.
- `tests/smoke/test_scene_flow.gd`: combat smoke coverage for migrated utility and attack cards.
- `resources/cards/**/*.tres`: add explicit `presentation_cues` to all default catalog cards.
- `README.md`: accepted progress and updated Next Plans.
- `docs/superpowers/plans/2026-05-01-card-cue-migration-foundation.md`: mark steps complete while executing.

Do not modify:

- `scripts/combat/*`
- `scripts/reward/*`
- `scripts/event/*`
- `scripts/shop/*`
- `scripts/save/*`
- `scripts/presentation/combat_presentation_queue.gd`
- `scripts/presentation/combat_presentation_layer.gd`
- `scripts/presentation/combat_presentation_config.gd`
- `scripts/presentation/combat_presentation_asset_catalog.gd` unless a test reveals a representative existing mapping was broken.

## Cue Resource Pattern

For any card resource without cue support, add this ext resource after `2_effect`:

```text
[ext_resource type="Script" path="res://scripts/data/card_presentation_cue_def.gd" id="3_cue"]
```

Increment `load_steps` by the number of new cue subresources plus one when adding the `3_cue` ext resource. For resources that already have `3_cue`, increment only for new cue subresources.

Use subresource names that describe the presentation event:

```text
[sub_resource type="Resource" id="Resource_slash_cue"]
script = ExtResource("3_cue")
event_type = "cinematic_slash"
target_mode = "played_target"
intensity = 1.0
cue_id = "sword.flash_cut"
tags = Array[String](["cinematic"])
```

Common cue snippets:

```text
[sub_resource type="Resource" id="Resource_camera_cue"]
script = ExtResource("3_cue")
event_type = "camera_impulse"
target_mode = "none"
intensity = 1.0
cue_id = "<card id>"
```

```text
[sub_resource type="Resource" id="Resource_player_particle_cue"]
script = ExtResource("3_cue")
event_type = "particle_burst"
target_mode = "player"
intensity = 1.0
cue_id = "<card id>"
```

```text
[sub_resource type="Resource" id="Resource_target_particle_cue"]
script = ExtResource("3_cue")
event_type = "particle_burst"
target_mode = "played_target"
intensity = 1.0
cue_id = "<card id>"
```

Each resource's `[resource]` block must include:

```text
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_slash_cue"), SubResource("Resource_camera_cue")])
```

Use the exact subresource list for the card from the cue matrix below.

## Cue Matrix

### Sword Cards

| Card id | Cue subresources |
| --- | --- |
| `sword.strike` | `Resource_slash_cue`, `Resource_camera_cue` |
| `sword.guard` | `Resource_player_particle_cue` |
| `sword.flash_cut` | `Resource_slash_cue`, `Resource_camera_cue` |
| `sword.qi_surge` | `Resource_player_particle_cue` |
| `sword.break_stance` | `Resource_slash_cue`, `Resource_target_particle_cue`, `Resource_camera_cue` |
| `sword.cloud_step` | `Resource_player_particle_cue` |
| `sword.focused_slash` | `Resource_slash_cue`, `Resource_camera_cue` |
| `sword.sword_resonance` | `Resource_player_particle_cue` |
| `sword.horizon_arc` | `Resource_slash_cue`, `Resource_player_particle_cue`, `Resource_camera_cue` |
| `sword.iron_wind_cut` | `Resource_slash_cue`, `Resource_player_particle_cue`, `Resource_camera_cue` |
| `sword.rising_arc` | `Resource_slash_cue`, `Resource_camera_cue` |
| `sword.guardian_stance` | `Resource_player_particle_cue` |
| `sword.meridian_flash` | `Resource_player_particle_cue` |
| `sword.heart_piercer` | `Resource_slash_cue`, `Resource_target_particle_cue`, `Resource_camera_cue` |
| `sword.unbroken_focus` | `Resource_player_particle_cue` |
| `sword.wind_splitting_step` | `Resource_slash_cue`, `Resource_target_particle_cue`, `Resource_camera_cue` |
| `sword.clear_mind_guard` | `Resource_player_particle_cue` |
| `sword.thread_the_needle` | `Resource_slash_cue`, `Resource_camera_cue` |
| `sword.echoing_sword_heart` | `Resource_player_particle_cue` |
| `sword.heaven_cutting_arc` | `Resource_slash_cue`, `Resource_target_particle_cue`, `Resource_camera_cue`, existing `Resource_slow_cue`, existing `Resource_audio_cue` |

### Alchemy Cards

| Card id | Cue subresources |
| --- | --- |
| `alchemy.toxic_pill` | `Resource_target_particle_cue`, `Resource_camera_cue` |
| `alchemy.healing_draught` | `Resource_player_particle_cue` |
| `alchemy.poison_mist` | `Resource_target_particle_cue` |
| `alchemy.inner_fire_pill` | `Resource_player_particle_cue` |
| `alchemy.cauldron_burst` | `Resource_target_particle_cue`, `Resource_player_particle_cue`, `Resource_camera_cue` |
| `alchemy.calming_powder` | `Resource_player_particle_cue` |
| `alchemy.toxin_needle` | `Resource_target_particle_cue`, `Resource_camera_cue` |
| `alchemy.spirit_distill` | `Resource_player_particle_cue` |
| `alchemy.cinnabar_seal` | `Resource_player_particle_cue` |
| `alchemy.bitter_extract` | `Resource_target_particle_cue`, `Resource_camera_cue` |
| `alchemy.smoke_screen` | `Resource_player_particle_cue`, `Resource_target_particle_cue` |
| `alchemy.quick_simmer` | `Resource_player_particle_cue` |
| `alchemy.white_jade_paste` | `Resource_player_particle_cue` |
| `alchemy.mercury_bloom` | `Resource_target_particle_cue`, `Resource_camera_cue` |
| `alchemy.ninefold_refine` | `Resource_player_particle_cue` |
| `alchemy.coiling_miasma` | `Resource_target_particle_cue` |
| `alchemy.needle_rain` | `Resource_target_particle_cue`, `Resource_camera_cue` |
| `alchemy.purifying_brew` | `Resource_player_particle_cue` |
| `alchemy.cauldron_overflow` | `Resource_target_particle_cue`, `Resource_player_particle_cue` |
| `alchemy.golden_core_detox` | `Resource_player_particle_cue` |

## Task 1: Catalog Coverage Tests

**Files:**

- Modify: `tests/unit/test_content_catalog.gd`

- [x] **Step 1: Add failing catalog cue coverage test**

Add this test after `test_representative_cards_load_explicit_presentation_cues()`:

```gdscript
func test_default_catalog_cards_have_explicit_presentation_cues() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var allowed_event_types := [
		"cinematic_slash",
		"particle_burst",
		"camera_impulse",
		"slow_motion",
		"audio_cue",
	]
	var allowed_target_modes := [
		"played_target",
		"source",
		"player",
		"none",
	]
	for card in catalog.cards_by_id.values():
		var typed_card := card as CardDef
		if typed_card == null:
			push_error("Catalog card is not CardDef: %s" % str(card))
			assert(false)
			return false
		if typed_card.presentation_cues.is_empty():
			push_error("Card has no explicit presentation cues: %s" % typed_card.id)
			assert(false)
			return false
		for cue in typed_card.presentation_cues:
			if cue == null:
				push_error("Card has null presentation cue: %s" % typed_card.id)
				assert(false)
				return false
			if not allowed_event_types.has(cue.event_type):
				push_error("Card has unsupported cue event type: %s %s" % [typed_card.id, cue.event_type])
				assert(false)
				return false
			if not allowed_target_modes.has(cue.target_mode):
				push_error("Card has unsupported cue target mode: %s %s" % [typed_card.id, cue.target_mode])
				assert(false)
				return false
			if cue.cue_id != typed_card.id:
				push_error("Card cue id should equal card id: %s cue=%s" % [typed_card.id, cue.cue_id])
				assert(false)
				return false
	assert(true)
	return true
```

- [x] **Step 2: Strengthen representative cue coverage**

Replace the body of `test_representative_cards_load_explicit_presentation_cues()` with:

```gdscript
func test_representative_cards_load_explicit_presentation_cues() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var strike := catalog.get_card("sword.strike")
	var flash := catalog.get_card("sword.flash_cut")
	var guard := catalog.get_card("sword.guard")
	var poison := catalog.get_card("alchemy.poison_mist")
	var quick := catalog.get_card("alchemy.quick_simmer")
	var heaven := catalog.get_card("sword.heaven_cutting_arc")
	var passed: bool = strike != null \
		and flash != null \
		and guard != null \
		and poison != null \
		and quick != null \
		and heaven != null \
		and _has_card_cue(strike, "cinematic_slash") \
		and _has_card_cue(strike, "camera_impulse") \
		and _has_card_cue(flash, "cinematic_slash") \
		and _has_card_cue(flash, "camera_impulse") \
		and _has_card_cue(guard, "particle_burst") \
		and _has_card_cue(poison, "particle_burst") \
		and _has_card_cue(quick, "particle_burst") \
		and _has_card_cue(heaven, "cinematic_slash") \
		and _has_card_cue(heaven, "particle_burst") \
		and _has_card_cue(heaven, "camera_impulse") \
		and _has_card_cue(heaven, "slow_motion") \
		and _has_card_cue(heaven, "audio_cue")
	assert(passed)
	return passed
```

- [x] **Step 3: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: `TESTS FAILED` because most default catalog cards have no explicit `presentation_cues`, and `sword.strike` / `alchemy.toxic_pill` do not yet include the richer representative cues expected by this plan.

Do not commit failing tests.

## Task 2: Resolver Tests For Migrated Card Cues

**Files:**

- Modify: `tests/unit/test_combat_presentation.gd`

- [x] **Step 1: Add ContentCatalog preload**

Add this near the existing preloads:

```gdscript
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
```

- [x] **Step 2: Add failing resolver test for card cue ids**

Add this test after `test_cue_resolver_does_not_infer_slow_motion_or_audio()`:

```gdscript
func test_resolver_uses_migrated_catalog_cues_with_card_cue_ids() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var card := catalog.get_card("sword.flash_cut")
	var damage := CombatPresentationEvent.new("damage_number")
	damage.target_id = "enemy:0"
	damage.amount = 4

	var events := CombatPresentationCueResolver.new().resolve_card_play(card, "player", "enemy:0", [damage])
	var slash := _first_event(events, "cinematic_slash")
	var camera := _first_event(events, "camera_impulse")
	var passed: bool = slash != null \
		and slash.payload.get("cue_id") == "sword.flash_cut" \
		and slash.target_id == "enemy:0" \
		and slash.tags.has("cinematic") \
		and camera != null \
		and camera.payload.get("cue_id") == "sword.flash_cut" \
		and camera.target_id == ""
	assert(passed)
	return passed
```

- [x] **Step 3: Add failing resolver test for utility/status cues**

Add this test after the previous new test:

```gdscript
func test_resolver_uses_migrated_utility_and_status_cues() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var guard := catalog.get_card("sword.guard")
	var poison := catalog.get_card("alchemy.poison_mist")
	var guard_events := CombatPresentationCueResolver.new().resolve_card_play(guard, "player", "", [])
	var poison_events := CombatPresentationCueResolver.new().resolve_card_play(poison, "player", "enemy:0", [])
	var guard_particle := _first_event(guard_events, "particle_burst")
	var poison_particle := _first_event(poison_events, "particle_burst")
	var passed: bool = guard_particle != null \
		and guard_particle.payload.get("cue_id") == "sword.guard" \
		and guard_particle.target_id == "player" \
		and poison_particle != null \
		and poison_particle.payload.get("cue_id") == "alchemy.poison_mist" \
		and poison_particle.target_id == "enemy:0"
	assert(passed)
	return passed
```

- [x] **Step 4: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: `TESTS FAILED` because `sword.flash_cut`, `sword.guard`, and `alchemy.poison_mist` have no explicit card cue ids yet.

Do not commit failing tests.

## Task 3: Migrate Sword Card Resources

**Files:**

- Modify: `resources/cards/sword/*.tres`
- Modify: `docs/superpowers/plans/2026-05-01-card-cue-migration-foundation.md`

- [x] **Step 1: Add or update `3_cue` ext resources**

For each sword card in the cue matrix, ensure this ext resource exists:

```text
[ext_resource type="Script" path="res://scripts/data/card_presentation_cue_def.gd" id="3_cue"]
```

If a card already has `3_cue`, keep the existing id and style.

- [x] **Step 2: Add sword cue subresources**

For every sword card, add the subresources listed in the sword cue matrix.

Use these exact event fields:

```text
Resource_slash_cue:
event_type = "cinematic_slash"
target_mode = "played_target"
intensity = 1.0
cue_id = "<card id>"
tags = Array[String](["cinematic"])

Resource_camera_cue:
event_type = "camera_impulse"
target_mode = "none"
intensity = 1.0
cue_id = "<card id>"

Resource_player_particle_cue:
event_type = "particle_burst"
target_mode = "player"
intensity = 1.0
cue_id = "<card id>"

Resource_target_particle_cue:
event_type = "particle_burst"
target_mode = "played_target"
intensity = 1.0
cue_id = "<card id>"
```

For `sword.heaven_cutting_arc`, update the existing slow-motion and audio cue ids to remain `sword.heaven_cutting_arc`, then include all five cue subresources in `presentation_cues`.

- [x] **Step 3: Update sword `presentation_cues` arrays**

For each sword card, set `presentation_cues` to the exact subresource list from the cue matrix.

Example for `resources/cards/sword/flash_cut.tres`:

```text
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_slash_cue"), SubResource("Resource_camera_cue")])
```

Example for `resources/cards/sword/break_stance.tres`:

```text
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_slash_cue"), SubResource("Resource_target_particle_cue"), SubResource("Resource_camera_cue")])
```

- [x] **Step 4: Run tests to verify partial GREEN for sword coverage**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: tests still fail because alchemy cards are not migrated yet. The resolver tests for `sword.flash_cut` and `sword.guard` should pass.

Do not commit partial feature unless only alchemy coverage remains failing.

## Task 4: Migrate Alchemy Card Resources

**Files:**

- Modify: `resources/cards/alchemy/*.tres`
- Modify: `docs/superpowers/plans/2026-05-01-card-cue-migration-foundation.md`

- [x] **Step 1: Add or update `3_cue` ext resources**

For each alchemy card in the cue matrix, ensure this ext resource exists:

```text
[ext_resource type="Script" path="res://scripts/data/card_presentation_cue_def.gd" id="3_cue"]
```

If a card already has `3_cue`, keep the existing id and style.

- [x] **Step 2: Add alchemy cue subresources**

For every alchemy card, add the subresources listed in the alchemy cue matrix.

Use the same exact event fields from Task 3. Alchemy cards should primarily use:

```text
Resource_target_particle_cue:
event_type = "particle_burst"
target_mode = "played_target"
intensity = 1.0
cue_id = "<card id>"

Resource_player_particle_cue:
event_type = "particle_burst"
target_mode = "player"
intensity = 1.0
cue_id = "<card id>"

Resource_camera_cue:
event_type = "camera_impulse"
target_mode = "none"
intensity = 1.0
cue_id = "<card id>"
```

- [x] **Step 3: Update alchemy `presentation_cues` arrays**

For each alchemy card, set `presentation_cues` to the exact subresource list from the cue matrix.

Example for `resources/cards/alchemy/quick_simmer.tres`:

```text
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_player_particle_cue")])
```

Example for `resources/cards/alchemy/cauldron_burst.tres`:

```text
presentation_cues = Array[ExtResource("3_cue")]([SubResource("Resource_target_particle_cue"), SubResource("Resource_player_particle_cue"), SubResource("Resource_camera_cue")])
```

- [x] **Step 4: Run tests to verify GREEN**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [x] **Step 5: Run Task 3-4 review gates**

Stage 1 Spec Compliance Review:

- Every default catalog sword and alchemy card has at least one explicit cue.
- Every cue id equals the owning card id.
- Event types are limited to `cinematic_slash`, `particle_burst`, `camera_impulse`, `slow_motion`, and `audio_cue`.
- Target modes are limited to `played_target`, `player`, `source`, and `none`.
- `sword.heaven_cutting_arc` still has slow-motion and audio cues.
- No new assets or combat rule changes were added.

Stage 2 Code Quality Review:

- `.tres` edits are minimal and consistent.
- Cue subresource names match the cue matrix.
- Existing exact asset mappings still resolve.
- Fallback resolver behavior still exists for non-catalog cards.

- [x] **Step 6: Commit migrated resources and tests**

Run:

```powershell
rtk git add tests/unit/test_content_catalog.gd tests/unit/test_combat_presentation.gd resources/cards/sword/*.tres resources/cards/alchemy/*.tres docs/superpowers/plans/2026-05-01-card-cue-migration-foundation.md
rtk git commit -m "feat: migrate default cards to explicit presentation cues"
```

## Task 5: Smoke Coverage, Documentation, and Acceptance

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-05-01-card-cue-migration-foundation.md`

- [ ] **Step 1: Add migrated utility card smoke test**

Add this test after `test_combat_screen_click_play_triggers_particle_asset_feedback()`:

```gdscript
func test_migrated_utility_card_triggers_explicit_particle_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_migrated_utility_card_feedback_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "alchemy"
	run.max_hp = 68
	run.current_hp = 68
	run.deck_ids = ["alchemy.quick_simmer"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("alchemy.quick_simmer")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var played: bool = combat.try_play_dragged_card(0, "player", -1)
	combat.presentation_layer.process_queue()

	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = played \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_migrated_utility_card_feedback_save.json")
	return passed
```

- [ ] **Step 2: Add migrated sword card smoke test**

Add this test after the utility smoke test:

```gdscript
func test_migrated_sword_card_uses_explicit_slash_and_camera_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_migrated_sword_card_feedback_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.flash_cut"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("sword.flash_cut")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var layer_position_before: Vector2 = combat.presentation_layer.position
	var played: bool = combat.try_play_dragged_card(0, "enemy", 0)
	combat.presentation_layer.process_queue()

	var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0") as TextureRect
	var passed: bool = played \
		and slash != null \
		and slash.texture != null \
		and combat.presentation_layer.position != layer_position_before
	app.free()
	_delete_test_save("user://test_migrated_sword_card_feedback_save.json")
	return passed
```

- [ ] **Step 3: Run smoke tests with full Godot checks**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [ ] **Step 4: Run final direct import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 5: Verify combat boundary**

Run:

```powershell
rtk rg -n "presentation_cues|CombatPresentation|cue_id" scripts/combat scripts/reward scripts/event scripts/shop scripts/save
```

Expected: no output. `rg` may exit 1 when there are no matches; that is acceptable for this boundary check.

- [ ] **Step 6: Update README progress**

Add this bullet under `## Phase 2 Progress` after the reduced-motion bullet:

```markdown
- Card cue migration foundation: complete; all default catalog cards now declare explicit presentation cues with stable card-id cue ids, while resolver fallback remains available for future content and prototypes.
```

Update `## Next Plans` to remove full card cue migration from the first presentation item:

```markdown
## Next Plans

1. Presentation expansion: intent icons, card art, richer combat backgrounds, and formal audio mixing.
2. Release expansion: artifact packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
```

- [ ] **Step 7: Run final two-stage review**

Stage 1 Spec Compliance Review:

- All 40 default catalog cards have explicit cues.
- All cue ids are non-empty and equal the owning card id.
- Representative migrated cards produce explicit cue events.
- Existing asset fallback renders unmapped migrated cue ids safely.
- Reduced-motion filtering still applies to migrated slash, particle, camera, and slow-motion events.
- Resolver fallback remains available for cards without cues.
- No combat rule, save, reward, event, shop, or settings code was modified.
- README progress and Next Plans match shipped scope.

Stage 2 Code Quality Review:

- Resource edits are minimal and style-consistent.
- Tests are focused and fail for the intended missing-cue reasons.
- Smoke tests use real combat flows and stable node names.
- No new runtime abstraction was introduced.
- No unrelated refactors or formatting churn were included.

Classify all issues as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

- [ ] **Step 8: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after each step has been completed and verified.

- [ ] **Step 9: Commit final smoke/docs acceptance**

Run:

```powershell
rtk git add tests/smoke/test_scene_flow.gd README.md docs/superpowers/plans/2026-05-01-card-cue-migration-foundation.md
rtk git commit -m "docs: record card cue migration acceptance"
```

## Final Acceptance Criteria

- All 40 default catalog cards have at least one explicit presentation cue.
- Every default catalog cue uses the owning card id as `cue_id`.
- Migrated cues use only existing event types and target modes.
- Representative migrated cards resolve through explicit cues rather than fallback inference.
- Existing exact asset mappings still work.
- Event-type asset fallbacks safely render migrated card cue ids without bespoke mappings for every card.
- Reduced-motion filtering still suppresses high-motion migrated cues.
- Existing click and drag combat card play flows remain functional.
- No core combat, reward, event, shop, or save class depends on presentation scripts.
- Shared Godot checks pass.
- Godot import check exits 0.
