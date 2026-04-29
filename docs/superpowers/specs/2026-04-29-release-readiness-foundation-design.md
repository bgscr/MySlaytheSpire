# Release Readiness Foundation Design

Date: 2026-04-29

## Goal

Build the first release-readiness foundation for the Godot project: one repeatable quality gate, one Windows artifact path, one release documentation path, and a clean platform boundary for later Steam integration.

This pass should make future release work easy to extend without prematurely wiring real store SDKs, real publishing credentials, or multi-platform automation.

## Current Baseline

The project already has:

- Godot 4.6.2-stable project files.
- A headless test runner at `res://scripts/testing/test_runner.gd`.
- README local test instructions that run the headless test runner.
- A Windows export preset in `export_presets.cfg` with output path `export/MySlaytheSpire.exe`.
- `PlatformService` and `LocalPlatformService` under `scripts/platform/`, which already define a small achievement/stat/language boundary.
- A local-first workflow where tests and import checks are run manually through `rtk proxy powershell`.
- No `.github` workflow directory.
- No changelog, release checklist, release draft template, or scripted artifact wrapper.

The original vertical-slice design said CI and release automation were deferred, but the directory and command structure should preserve a clear future GitHub Actions entry point. The project has now reached that point.

## Scope

Included in this foundation:

- Add a CI workflow that runs the same Godot checks developers run locally:
  - headless test runner.
  - headless import/project load check.
- Add a small local script layer so CI and developers share command names instead of duplicating long Godot command lines.
- Add a Windows export wrapper around the existing export preset.
- Keep the export wrapper future-ready for zipped artifacts, checksums, and multi-platform targets.
- Add release documentation:
  - `CHANGELOG.md` with an initial unreleased section and a first baseline entry.
  - a release process document with local verification, artifact export, and release draft steps.
  - a GitHub release draft template.
- Add a Steam adapter design note that points at the existing `PlatformService` boundary and states what future Steam work should and should not touch.
- Update README with the new release readiness commands and progress status.
- Add tests or script self-checks where they can run without external services.

Excluded from this foundation:

- No real Steamworks SDK integration.
- No GitHub release publishing token or upload workflow.
- No automatic version bumping.
- No signed Windows builds.
- No installer.
- No Steam depot upload.
- No macOS, Linux, or Steam Deck export target.
- No generated art/audio/content changes.
- No rewrite of existing gameplay or platform services.

## Design Principles

This pass should optimize for extension points, not automation theater.

- Local and CI commands should share the same script entry points.
- Scripts should be thin wrappers around Godot, not a custom build system.
- The Windows export should use the existing preset name, so future preset additions do not require changing gameplay code.
- Release notes should live in stable files that humans can edit.
- Future Steam work should plug into `PlatformService`, not scatter Steam calls through gameplay, UI, save, or reward code.
- Missing optional export templates should produce a clear failure message instead of hiding a broken artifact.
- The first CI should be useful even before artifact export is automated in CI.

## Architecture

Release readiness will be organized into four areas.

```text
Developer / CI
  -> tools/ci/run_godot_checks.ps1
       -> Godot headless test runner
       -> Godot headless import check

Developer / Release operator
  -> tools/release/export_windows.ps1
       -> Godot export preset: Windows Desktop
       -> export/MySlaytheSpire.exe
       -> export/artifacts/ manifest-friendly folder

Documentation
  -> CHANGELOG.md
  -> docs/release/release-process.md
  -> docs/release/github-release-template.md

Future platform integration
  -> scripts/platform/platform_service.gd
  -> scripts/platform/local_platform_service.gd
  -> docs/release/steam-adapter.md
```

The CI workflow should call `tools/ci/run_godot_checks.ps1`. The release process document should call the same check script before export. If the test command changes later, it changes in one script and both CI and release docs inherit it.

The Windows export wrapper should use the current `Windows Desktop` export preset. It should create output directories if needed and print the exact artifact path. It may leave zipping and checksums to a later plan, but it must put files in a structure that can accept them.

The Steam adapter work in this pass is documentation and boundary preservation. Future Steam code should implement the existing GDScript `PlatformService` boundary. No gameplay code should learn about Steam APIs in this foundation.

## Proposed Files

Create:

- `.github/workflows/ci.yml`
  - Runs on pull request and manual dispatch.
  - Checks out the repo.
  - Installs or locates Godot through an explicit environment variable strategy documented in the workflow.
  - Runs `tools/ci/run_godot_checks.ps1`.

- `tools/ci/run_godot_checks.ps1`
  - Resolves Godot from `$env:GODOT4` first.
  - Falls back to `C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe` for local Windows developers.
  - Runs the full headless test runner.
  - Runs the headless import check.
  - Exits non-zero on any failed command.

- `tools/release/export_windows.ps1`
  - Resolves Godot the same way as the check script.
  - Creates `export/` and `export/artifacts/`.
  - Runs Godot export using the `Windows Desktop` preset.
  - Verifies `export/MySlaytheSpire.exe` exists.
  - Prints the artifact path.

- `CHANGELOG.md`
  - Adds an `Unreleased` section.
  - Records the current vertical-slice baseline as release-readiness context.

- `docs/release/release-process.md`
  - Documents local checks, Windows export, release draft preparation, and future extension points.

- `docs/release/github-release-template.md`
  - Provides a copyable release draft body with sections for summary, artifacts, verification, known issues, and follow-up.

- `docs/release/steam-adapter.md`
  - Documents the future adapter boundary.
  - Names `PlatformService` as the interface to implement.
  - States that Steam SDK code must stay outside combat, map, reward, event, save, and DevTools code.

Modify:

- `README.md`
  - Add release readiness commands.
  - Record release readiness foundation progress once implemented.
  - Update Next Plans after acceptance.

Do not modify in this pass:

- `scripts/platform/platform_service.gd`
- `scripts/platform/local_platform_service.gd`
- gameplay scripts
- scene files
- content resources
- export preset values unless the implementation plan finds a broken export field that blocks the wrapper

## CI Design

The first workflow is a quality gate, not a full publishing system.

Triggers:

- `pull_request`
- `workflow_dispatch`

Jobs:

- `godot-checks`
  - Runs on a Windows runner because the project is Windows-first and the existing commands are PowerShell-oriented.
  - Uses a single environment variable, `GODOT4`, to point to the Godot console binary.
  - Runs `tools/ci/run_godot_checks.ps1`.

The workflow should avoid hard-coded secrets and release permissions. Artifact upload can be added later after the local export wrapper has proven stable.

If CI cannot install Godot in the first implementation without adding a risky third-party action, the implementation plan should prefer a documented `GODOT4` setup path and make the workflow structure ready for the installation step. The goal is a maintainable CI entry point, not a fragile green badge.

## Export Design

The Windows export wrapper should be intentionally small:

1. Resolve Godot.
2. Ensure output directories exist.
3. Run the `Windows Desktop` preset.
4. Confirm `export/MySlaytheSpire.exe` exists.
5. Print a short artifact summary.

The script should not edit project settings, modify export presets, sign binaries, or delete previous artifacts outside the known `export/` path.

Future export extensions should fit naturally:

- `tools/release/export_windows.ps1 -Configuration release`
- `tools/release/package_windows.ps1`
- `tools/release/write_checksums.ps1`
- `tools/release/export_all.ps1`
- additional Godot export presets for Linux or Steam Deck

## Release Documentation Design

`CHANGELOG.md` should be human-owned and simple. It should use an `Unreleased` section so future feature plans can add entries without inventing a release process each time.

`docs/release/release-process.md` should be the operator checklist:

- verify clean working tree.
- run Godot checks.
- run Windows export.
- confirm artifact path.
- draft release notes from the template.
- record known issues.

`docs/release/github-release-template.md` should be copyable into GitHub releases. It should not claim there is a published artifact until the release operator has attached one.

## Steam Adapter Boundary

The project already has a platform abstraction:

- `PlatformService`
- `LocalPlatformService`

This foundation should preserve that boundary. Future Steam work should add a Steam implementation of the platform service and wire it through app setup, while keeping gameplay logic dependent only on the abstract methods.

Future Steam adapter requirements:

- Achievements go through `unlock_achievement`.
- Stats go through `set_stat`.
- Language goes through `get_platform_language`.
- Any new Steam capability must first be added to `PlatformService` with a local implementation and tests.
- Steam SDK initialization, shutdown, callbacks, and depot/upload concerns stay outside gameplay systems.

This pass should not create a fake Steam implementation. A design document is enough because there is no real SDK dependency yet.

## Testing Strategy

The implementation plan should use TDD for scripts where practical:

- Add a lightweight script self-test or dry-run mode if a wrapper has logic beyond invoking Godot.
- Verify Godot checks by running `tools/ci/run_godot_checks.ps1`.
- Verify import check remains part of the shared script.
- Verify export wrapper either:
  - produces `export/MySlaytheSpire.exe`, or
  - fails clearly when export templates are missing.

Documentation verification:

- Check README commands match actual script paths.
- Check release docs mention the same artifact path as `export_presets.cfg`.
- Check no release doc claims Steamworks is integrated.

CI verification:

- Validate workflow YAML is present and references the shared check script.
- If CI cannot be executed locally, the implementation plan should still run the script it calls.

## Review Requirements

Stage 1: Spec Compliance Review

- Verify CI workflow exists and routes through the shared check script.
- Verify local check script runs test runner and import check.
- Verify Windows export wrapper uses the current export preset.
- Verify release docs and changelog exist.
- Verify Steam adapter work is boundary documentation only.
- Verify README progress and Next Plans match shipped scope.

Stage 2: Code Quality Review

- Scripts are small, typed where PowerShell supports it, and fail fast.
- Paths are centralized enough to change Godot location or artifact output later.
- No script deletes files outside the intended export directory.
- Workflow does not require secrets.
- Release docs do not overpromise automation that does not exist.
- Future Steam expansion remains isolated behind `PlatformService`.

## Acceptance Criteria

- A developer can run one local release-readiness check script and get the existing Godot test runner plus import check.
- CI has a first workflow entry point for the same checks.
- A developer can run one Windows export wrapper and either get `export/MySlaytheSpire.exe` or a clear actionable failure.
- The release process has a documented checklist and release draft template.
- `CHANGELOG.md` exists and has a usable `Unreleased` section.
- Steam adapter expectations are documented without adding Steam SDK dependencies.
- README lists the new release readiness commands.
- Existing local tests still pass.
- Godot import check exits 0.
