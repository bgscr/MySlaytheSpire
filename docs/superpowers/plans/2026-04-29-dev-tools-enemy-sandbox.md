# DevTools Enemy Sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the DevTools Enemy Sandbox entry into a real debug launcher for isolated combat scenarios.

**Architecture:** DevTools builds a transient sandbox config, stores it on `Game`, and routes to `CombatScreen`. `CombatScreen` consumes the config and starts `CombatSession.start_sandbox()` with explicit enemies, leaving normal combat flow unchanged.

**Tech Stack:** Godot 4.6.2-stable, GDScript, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Before editing code, verify `git branch --show-current` is `main`; stop if it is not.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`.
- Enemy Sandbox must not write saves, mutate resources, or mutate an existing run.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-dev-tools-enemy-sandbox-design.md`

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

Modify:

- `scripts/ui/dev_tools_screen.gd`: Enemy Sandbox state helpers, panel UI, launch action.
- `scripts/app/game.gd`: transient debug sandbox config setters.
- `scripts/combat/combat_session.gd`: `start_sandbox()` explicit enemy combat startup.
- `scripts/ui/combat_screen.gd`: consume sandbox config and suppress reward/summary routing for sandbox combat.
- `tests/unit/test_dev_tools_screen.gd`: Enemy Sandbox helper coverage.
- `tests/unit/test_combat_session.gd`: sandbox session coverage.
- `tests/smoke/test_scene_flow.gd`: DevTools-to-combat launch coverage.
- `README.md`: record progress and update next plans after acceptance.
- `docs/superpowers/plans/2026-04-29-dev-tools-enemy-sandbox.md`: mark steps complete during execution.

## Task 1: Sandbox Session Runtime

**Files:**

- Modify: `tests/unit/test_combat_session.gd`
- Modify: `scripts/combat/combat_session.gd`

- [x] **Step 1: Verify branch and clean workspace**

Run:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
main
```

`git status --short` should show only docs created for this plan before implementation starts.

- [x] **Step 2: Add failing sandbox session tests**

Append these tests before helper functions in `tests/unit/test_combat_session.gd`:

```gdscript
func test_sandbox_session_starts_with_explicit_enemies_without_run() -> bool:
	var catalog := _default_catalog()
	var session := CombatSession.new()
	session.start_sandbox(catalog, "alchemy", ["alchemy.toxic_pill"], ["training_puppet", "forest_bandit"], 7)
	var passed: bool = session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.run == null \
		and session.state.player.id == "alchemy" \
		and session.state.player.max_hp == 68 \
		and session.state.enemies.size() == 2 \
		and session.state.enemies[0].id == "training_puppet" \
		and session.state.enemies[1].id == "forest_bandit" \
		and session.get_enemy_intent(0) == "attack_5" \
		and session.state.hand == ["alchemy.toxic_pill"]
	assert(passed)
	return passed

func test_sandbox_session_rejects_missing_enemy() -> bool:
	var catalog := _default_catalog()
	var session := CombatSession.new()
	session.start_sandbox(catalog, "sword", ["sword.strike"], ["missing_enemy"], 1)
	var passed: bool = session.phase == CombatSession.PHASE_INVALID \
		and session.error_text.contains("enemy is missing")
	assert(passed)
	return passed
```

- [x] **Step 3: Run tests to verify RED**

Run the full test command. Expected: FAIL because `CombatSession.start_sandbox()` does not exist.

- [x] **Step 4: Implement `CombatSession.start_sandbox()`**

Add a typed method that resets runtime state, validates catalog, character, deck, and enemy ids, builds player/enemy combatants from catalog data, and calls `_start_player_turn()`.

- [x] **Step 5: Run tests to verify GREEN for Task 1**

Run the full test command. Expected: `TESTS PASSED`.

- [x] **Step 6: Task 1 review gates**

Stage 1:

- `start_sandbox()` exists.
- It starts without `RunState`.
- It uses explicit enemy ids.
- It rejects missing enemies.

Stage 2:

- Runtime reset matches normal combat startup expectations.
- New code is typed and does not alter normal `start()` behavior.

## Task 2: DevTools Enemy Sandbox Panel

**Files:**

- Modify: `tests/unit/test_dev_tools_screen.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [x] **Step 1: Add failing DevTools helper tests**

Append tests covering deterministic enemy ids, default config, capped selection, and summary text.

- [x] **Step 2: Run tests to verify RED**

Run the full test command. Expected: FAIL because Enemy Sandbox helpers do not exist.

- [x] **Step 3: Implement Enemy Sandbox helpers and panel**

Update `DevToolsScreen` so `enemy_sandbox` builds `EnemySandboxPanel` with character select, deck summary, enemy toggle buttons, summary label, and launch button.

- [x] **Step 4: Run tests to verify GREEN for Task 2**

Run the full test command. Expected: `TESTS PASSED`.

- [x] **Step 5: Task 2 review gates**

Stage 1:

- Enemy Sandbox is no longer a placeholder.
- Character and enemy helpers work from default catalog.
- Selection is unique, capped at three, and never empty.

Stage 2:

- Helpers are deterministic.
- UI nodes have stable names.
- DevTools still avoids save/resource writes.

## Task 3: Launch Flow Through CombatScreen

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/app/game.gd`
- Modify: `scripts/ui/combat_screen.gd`
- Modify: `scripts/ui/dev_tools_screen.gd`

- [ ] **Step 1: Add failing smoke launch test**

Add a smoke test that opens Enemy Sandbox, presses `EnemySandboxLaunchButton`, and verifies `CombatScreen` starts sandbox combat against `training_puppet` while `app.game.current_run == null`.

- [ ] **Step 2: Run tests to verify RED**

Run the full test command. Expected: FAIL because launch config and CombatScreen sandbox startup do not exist.

- [ ] **Step 3: Add transient sandbox config to `Game`**

Add `debug_combat_sandbox_config`, `set_debug_combat_sandbox_config()`, and `take_debug_combat_sandbox_config()`.

- [ ] **Step 4: Wire DevTools launch and CombatScreen startup**

DevTools writes config then routes to `SceneRouter.COMBAT`. CombatScreen consumes the config, starts sandbox session, marks `is_sandbox`, and skips reward/summary routing when terminal.

- [ ] **Step 5: Run tests to verify GREEN for Task 3**

Run the full test command. Expected: `TESTS PASSED`.

- [ ] **Step 6: Task 3 review gates**

Stage 1:

- Launch routes to `CombatScreen`.
- Sandbox combat has no current run.
- Normal combat still uses `current_run`.

Stage 2:

- Config is copied and cleared.
- Terminal sandbox routing cannot hit reward or summary.

## Task 4: Documentation, Final Verification, and Acceptance

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-dev-tools-enemy-sandbox.md`

- [ ] **Step 1: Verify no persistence/resource writes were added**

Run:

```powershell
rtk proxy rg -n "save_run|delete_save|FileAccess.open|ResourceSaver|store_|current_run\\s*=|deck_ids\\.|gold \\+=" scripts/ui/dev_tools_screen.gd scripts/ui/combat_screen.gd scripts/combat/combat_session.gd scripts/app/game.gd
```

Expected: no new save/resource write path for Enemy Sandbox.

- [ ] **Step 2: Run full local tests**

Run the full test command. Expected: `TESTS PASSED`.

- [ ] **Step 3: Run Godot import check**

Run the import check command. Expected: process exits 0.

- [ ] **Step 4: Update README progress**

Record Enemy Sandbox completion and update Next Plans to leave Event Tester, Reward Inspector, and Save Inspector.

- [ ] **Step 5: Run final two-stage review**

Run Stage 1 Spec Compliance Review, then Stage 2 Code Quality Review only if Stage 1 passes. Fix Critical and Important findings before acceptance.

- [ ] **Step 6: Commit final result**

Commit all accepted changes with:

```powershell
rtk proxy git add .
rtk proxy git commit -m "feat: add dev tools enemy sandbox"
```

## Final Acceptance Criteria

- Enemy Sandbox is reachable inside DevTools.
- Developers can choose a character and one to three catalog enemies.
- The starter deck summary updates with the selected character.
- Launching creates sandbox combat against explicit enemies.
- Sandbox combat never writes saves, resources, or an existing run.
- Existing local tests pass.
- Godot import check exits 0.
