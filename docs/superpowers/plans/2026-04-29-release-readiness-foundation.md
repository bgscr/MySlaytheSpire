# Release Readiness Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a release-readiness foundation: shared Godot check scripts, a CI entry point, a Windows export wrapper, release docs, changelog, and a documented Steam adapter boundary.

**Architecture:** Keep release automation thin and extensible. Local developers and CI call the same PowerShell scripts; export uses the existing Godot `Windows Desktop` preset; future Steam work stays behind the existing `PlatformService` boundary.

**Tech Stack:** Godot 4.6.2-stable, GDScript, PowerShell 5+/PowerShell Core compatible scripts, GitHub Actions Windows runner, existing headless test runner.

---

## Project Constraints

- Work on branch `codex/release-readiness-foundation` in the existing worktree:
  - `C:/Users/56922/.config/superpowers/worktrees/Slay the Spire 2/release-readiness-foundation`
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- Do not modify gameplay, scenes, content resources, `PlatformService`, or `LocalPlatformService` in this pass.
- Do not add real Steamworks SDK code.
- Do not add release publishing credentials, signing, Steam depot upload, or GitHub release upload.
- After implementation, run the two-stage review from `AGENTS.md`.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-release-readiness-foundation-design.md`

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

The existing `test_malformed_status_intent_advances_without_mutation` test emits a Godot `ERROR` log intentionally. Treat the process exit code and `TESTS PASSED` line as the test result.

Run Windows export wrapper:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/release/export_windows.ps1
```

Expected when Windows export templates are installed:

```text
Windows export complete:
```

Expected if export templates are missing: a non-zero exit with Godot's export-template error. The script must still print the preset and intended artifact path before the failing Godot command.

Run dry-run export wrapper:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/release/export_windows.ps1 -DryRun
```

Expected:

```text
Dry run: Godot export command resolved.
```

Run final Godot import check directly:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Create:

- `tools/common/godot.ps1`: shared Godot resolution and native-command invocation helpers.
- `tools/tests/test_release_scripts.ps1`: lightweight PowerShell tests for release scripts, workflow references, and docs.
- `tools/ci/run_godot_checks.ps1`: shared local/CI Godot quality gate.
- `tools/release/export_windows.ps1`: Windows export wrapper around the existing `Windows Desktop` preset.
- `.github/workflows/ci.yml`: GitHub Actions workflow for Godot checks.
- `CHANGELOG.md`: human-owned release notes.
- `docs/release/release-process.md`: release operator checklist.
- `docs/release/github-release-template.md`: copyable release draft body.
- `docs/release/steam-adapter.md`: future Steam adapter boundary note.

Modify:

- `README.md`: add release commands, progress, and Next Plans update.
- `docs/superpowers/plans/2026-04-29-release-readiness-foundation.md`: mark steps complete while executing.

Do not modify:

- `scripts/platform/platform_service.gd`
- `scripts/platform/local_platform_service.gd`
- gameplay scripts
- scene files
- content resources
- `export_presets.cfg` unless export verification reveals a blocking preset error that must be fixed in a separate reviewed step.

## Task 1: Shared Godot Script Helper

**Files:**

- Create: `tools/tests/test_release_scripts.ps1`
- Create: `tools/common/godot.ps1`

- [x] **Step 1: Verify branch and clean working tree**

Run:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
codex/release-readiness-foundation
```

`git status --short` may show this plan file while it is being executed. Stop and ask the user if the branch is not `codex/release-readiness-foundation`.

- [x] **Step 2: Add failing helper tests**

Create `tools/tests/test_release_scripts.ps1`:

```powershell
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:FailureCount = 0
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$CommonScript = Join-Path $ProjectRoot "tools\common\godot.ps1"

function Add-Failure {
	param([string]$Message)
	$script:FailureCount += 1
	Write-Host "FAIL: $Message"
}

function Assert-True {
	param(
		[bool]$Condition,
		[string]$Message
	)
	if (-not $Condition) {
		Add-Failure $Message
	}
}

function Assert-Equal {
	param(
		[string]$Expected,
		[string]$Actual,
		[string]$Message
	)
	if ($Expected -ne $Actual) {
		Add-Failure "$Message Expected '$Expected' but got '$Actual'."
	}
}

function Assert-ThrowsContaining {
	param(
		[scriptblock]$Script,
		[string]$ExpectedText,
		[string]$Message
	)
	try {
		& $Script
		Add-Failure "$Message Expected an exception containing '$ExpectedText'."
	} catch {
		if ($_.Exception.Message -notlike "*$ExpectedText*") {
			Add-Failure "$Message Exception was '$($_.Exception.Message)'."
		}
	}
}

Assert-True (Test-Path -LiteralPath $CommonScript) "tools/common/godot.ps1 should exist."
. $CommonScript

$originalGodot = $env:GODOT4
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("myslay_release_tests_" + [Guid]::NewGuid().ToString("N"))
try {
	New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
	$tempGodot = Join-Path $tempDir "Godot_v4.6.2-stable_win64_console.exe"
	Set-Content -LiteralPath $tempGodot -Value "" -Encoding ASCII
	$env:GODOT4 = $tempGodot

	$resolved = Resolve-Godot -FallbackPaths @()
	Assert-Equal (Resolve-Path -LiteralPath $tempGodot).Path $resolved "Resolve-Godot should prefer GODOT4."

	$env:GODOT4 = Join-Path $tempDir "missing.exe"
	Assert-ThrowsContaining { Resolve-Godot -FallbackPaths @() } "Set GODOT4" "Resolve-Godot should explain how to configure Godot."
} finally {
	$env:GODOT4 = $originalGodot
	if (Test-Path -LiteralPath $tempDir) {
		Remove-Item -LiteralPath $tempDir -Recurse -Force
	}
}

if ($script:FailureCount -gt 0) {
	throw "Release script tests failed: $script:FailureCount"
}

Write-Host "Release script tests passed."
```

- [x] **Step 3: Run helper tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected: FAIL because `tools/common/godot.ps1` does not exist.

- [x] **Step 4: Implement shared Godot helper**

Create `tools/common/godot.ps1`:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-Godot {
	[CmdletBinding()]
	param(
		[string[]]$FallbackPaths = @("C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe")
	)

	$candidates = @()
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT4)) {
		$candidates += $env:GODOT4
	}
	$candidates += $FallbackPaths

	foreach ($candidate in $candidates) {
		if ([string]::IsNullOrWhiteSpace($candidate)) {
			continue
		}
		if (Test-Path -LiteralPath $candidate) {
			return (Resolve-Path -LiteralPath $candidate).Path
		}
	}

	throw "Godot console binary not found. Set GODOT4 to Godot_v4.6.2-stable_win64_console.exe."
}

function Invoke-GodotCommand {
	[CmdletBinding()]
	param(
		[string[]]$Arguments,
		[string[]]$FallbackPaths = @("C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe")
	)

	$godot = Resolve-Godot -FallbackPaths $FallbackPaths
	Write-Host "Godot: $godot"
	Write-Host "Args: $($Arguments -join ' ')"
	& $godot @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Godot exited with code $LASTEXITCODE."
	}
}
```

- [x] **Step 5: Run helper tests to verify GREEN**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected:

```text
Release script tests passed.
```

- [x] **Step 6: Commit Task 1**

Run:

```powershell
rtk proxy git add tools/common/godot.ps1 tools/tests/test_release_scripts.ps1 docs/superpowers/plans/2026-04-29-release-readiness-foundation.md
rtk proxy git commit -m "build: add shared Godot script helper"
```

## Task 2: Shared Godot Check Script

**Files:**

- Modify: `tools/tests/test_release_scripts.ps1`
- Create: `tools/ci/run_godot_checks.ps1`

- [x] **Step 1: Add failing tests for check script shape**

Append this block before the final failure check in `tools/tests/test_release_scripts.ps1`:

```powershell
function Assert-FileContains {
	param(
		[string]$RelativePath,
		[string]$Needle,
		[string]$Message
	)
	$path = Join-Path $ProjectRoot $RelativePath
	if (-not (Test-Path -LiteralPath $path)) {
		Add-Failure "$Message Missing file: $RelativePath"
		return
	}
	$text = Get-Content -LiteralPath $path -Raw
	Assert-True ($text.Contains($Needle)) $Message
}

Assert-FileContains "tools\ci\run_godot_checks.ps1" "res://scripts/testing/test_runner.gd" "Godot check script should run the test runner."
Assert-FileContains "tools\ci\run_godot_checks.ps1" "--quit" "Godot check script should run the import check."
Assert-FileContains "tools\ci\run_godot_checks.ps1" "Invoke-GodotCommand" "Godot check script should use the shared helper."
```

The final lines of the file should still be:

```powershell
if ($script:FailureCount -gt 0) {
	throw "Release script tests failed: $script:FailureCount"
}

Write-Host "Release script tests passed."
```

- [x] **Step 2: Run script tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected: FAIL because `tools/ci/run_godot_checks.ps1` does not exist.

- [x] **Step 3: Implement shared Godot check script**

Create `tools/ci/run_godot_checks.ps1`:

```powershell
[CmdletBinding()]
param(
	[string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
	$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
	$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
}

. (Join-Path $scriptRoot "..\common\godot.ps1")

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Write-Host "Project root: $resolvedProjectRoot"

Write-Host "Running Godot test runner..."
Invoke-GodotCommand -Arguments @(
	"--headless",
	"--path",
	$resolvedProjectRoot,
	"--script",
	"res://scripts/testing/test_runner.gd"
)

Write-Host "Running Godot import check..."
Invoke-GodotCommand -Arguments @(
	"--headless",
	"--path",
	$resolvedProjectRoot,
	"--quit"
)

Write-Host "Godot checks passed."
```

`ProjectRoot` is resolved in the script body because `$PSScriptRoot` can be empty during parameter-default evaluation in this PowerShell invocation mode.

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

The known `poison_player` error log may appear after `TESTS PASSED`.

- [x] **Step 6: Commit Task 2**

Run:

```powershell
rtk proxy git add tools/ci/run_godot_checks.ps1 tools/tests/test_release_scripts.ps1 docs/superpowers/plans/2026-04-29-release-readiness-foundation.md
rtk proxy git commit -m "build: add shared Godot checks"
```

## Task 3: Windows Export Wrapper

**Files:**

- Modify: `tools/tests/test_release_scripts.ps1`
- Create: `tools/release/export_windows.ps1`

- [x] **Step 1: Add failing tests for export wrapper shape**

Append this block before the final failure check in `tools/tests/test_release_scripts.ps1`:

```powershell
Assert-FileContains "tools\release\export_windows.ps1" "Windows Desktop" "Windows export script should use the existing preset."
Assert-FileContains "tools\release\export_windows.ps1" "export/MySlaytheSpire.exe" "Windows export script should preserve the configured artifact path."
Assert-FileContains "tools\release\export_windows.ps1" "--export-release" "Windows export script should use Godot release export."
Assert-FileContains "tools\release\export_windows.ps1" "-DryRun" "Windows export script should expose a dry-run path for script verification."
```

- [x] **Step 2: Run script tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected: FAIL because `tools/release/export_windows.ps1` does not exist.

- [x] **Step 3: Implement Windows export wrapper**

Create `tools/release/export_windows.ps1`:

```powershell
[CmdletBinding()]
param(
	[string]$ProjectRoot,
	[string]$Preset = "Windows Desktop",
	[string]$ExportPath = "export/MySlaytheSpire.exe",
	[switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
	$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
	$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
}

. (Join-Path $scriptRoot "..\common\godot.ps1")

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$exportDirectory = Join-Path $resolvedProjectRoot "export"
$artifactsDirectory = Join-Path $exportDirectory "artifacts"
$resolvedExportPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedProjectRoot $ExportPath))
$resolvedExportDirectory = [System.IO.Path]::GetFullPath($exportDirectory)
if (-not $resolvedExportDirectory.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
	$resolvedExportDirectory = $resolvedExportDirectory + [System.IO.Path]::DirectorySeparatorChar
}
if (-not $resolvedExportPath.StartsWith($resolvedExportDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
	throw "ExportPath must stay under $resolvedExportDirectory"
}

New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $artifactsDirectory -Force | Out-Null

Write-Host "Project root: $resolvedProjectRoot"
Write-Host "Export preset: $Preset"
Write-Host "Export path: $resolvedExportPath"
Write-Host "Artifacts directory: $artifactsDirectory"

$arguments = @(
	"--headless",
	"--path",
	$resolvedProjectRoot,
	"--export-release",
	$Preset,
	$resolvedExportPath
)

if ($DryRun) {
	$godot = Resolve-Godot
	Write-Host "Dry run: Godot export command resolved."
	Write-Host "Godot: $godot"
	Write-Host "Args: $($arguments -join ' ')"
	return
}

Invoke-GodotCommand -Arguments $arguments

$artifactDeadline = (Get-Date).AddSeconds(30)
while ((-not (Test-Path -LiteralPath $resolvedExportPath)) -and ((Get-Date) -lt $artifactDeadline)) {
	Start-Sleep -Milliseconds 250
}

if (-not (Test-Path -LiteralPath $resolvedExportPath)) {
	throw "Windows export did not produce expected artifact after waiting up to 30 seconds: $resolvedExportPath. Check the export preset output path, export templates, and Godot export logs."
}

$artifactCopy = Join-Path $artifactsDirectory (Split-Path -Leaf $resolvedExportPath)
Copy-Item -LiteralPath $resolvedExportPath -Destination $artifactCopy -Force

Write-Host "Windows export complete:"
Write-Host "Primary artifact: $resolvedExportPath"
Write-Host "Artifact copy: $artifactCopy"
```

`ProjectRoot` is resolved in the script body because `$PSScriptRoot` can be empty during parameter-default evaluation in this PowerShell invocation mode. The wrapper waits briefly for the artifact path because GUI Godot can return before the exported executable is visible on disk.

- [x] **Step 4: Run script tests to verify GREEN**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected:

```text
Release script tests passed.
```

- [x] **Step 5: Run export dry run**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/release/export_windows.ps1 -DryRun
```

Expected:

```text
Dry run: Godot export command resolved.
Export preset: Windows Desktop
Export path:
```

- [x] **Step 6: Run real Windows export**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/release/export_windows.ps1
```

Expected if templates are installed:

```text
Windows export complete:
Primary artifact:
Artifact copy:
```

If this fails because Godot export templates are missing, do not change unrelated code. Confirm that the error clearly says export templates are missing and record the blocker in the final report. The script itself is acceptable only if it prints the preset and artifact path before the Godot failure.

Result: `Windows export complete:` produced both `export/MySlaytheSpire.exe` and `export/artifacts/MySlaytheSpire.exe`.

- [x] **Step 7: Commit Task 3**

Run:

```powershell
rtk proxy git add tools/release/export_windows.ps1 tools/tests/test_release_scripts.ps1 docs/superpowers/plans/2026-04-29-release-readiness-foundation.md
rtk proxy git commit -m "build: add Windows export wrapper"
```

## Task 4: GitHub Actions CI Entry Point

**Files:**

- Modify: `tools/tests/test_release_scripts.ps1`
- Create: `.github/workflows/ci.yml`

- [x] **Step 1: Add failing tests for workflow shape**

Append this block before the final failure check in `tools/tests/test_release_scripts.ps1`:

```powershell
Assert-FileContains ".github\workflows\ci.yml" "tools/ci/run_godot_checks.ps1" "CI workflow should call the shared Godot check script."
Assert-FileContains ".github\workflows\ci.yml" "pull_request" "CI workflow should run on pull requests."
Assert-FileContains ".github\workflows\ci.yml" "workflow_dispatch" "CI workflow should support manual dispatch."
Assert-FileContains ".github\workflows\ci.yml" "GODOT4=" "CI workflow should publish GODOT4 for the shared script."
```

- [x] **Step 2: Run script tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected: FAIL because `.github/workflows/ci.yml` does not exist.

- [x] **Step 3: Implement CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: Godot Checks

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  godot-checks:
    name: Godot checks
    runs-on: windows-latest
    env:
      GODOT_VERSION: 4.6.2-stable
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Godot console
        shell: pwsh
        run: |
          $ErrorActionPreference = "Stop"
          $version = $env:GODOT_VERSION
          $tools = Join-Path $env:RUNNER_TEMP "godot"
          New-Item -ItemType Directory -Path $tools -Force | Out-Null
          $zipName = "Godot_v$($version)_win64_console.exe.zip"
          $zipPath = Join-Path $tools $zipName
          $url = "https://github.com/godotengine/godot/releases/download/$version/$zipName"
          Invoke-WebRequest -Uri $url -OutFile $zipPath
          Expand-Archive -Path $zipPath -DestinationPath $tools -Force
          $godotExe = Get-ChildItem -Path $tools -Filter "Godot_*_win64_console.exe" -Recurse | Select-Object -First 1
          if ($null -eq $godotExe) {
            throw "Godot console executable was not found after extraction."
          }
          "GODOT4=$($godotExe.FullName)" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

      - name: Run Godot checks
        shell: pwsh
        run: ./tools/ci/run_godot_checks.ps1
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

- [x] **Step 5: Commit Task 4**

Run:

```powershell
rtk proxy git add .github/workflows/ci.yml tools/tests/test_release_scripts.ps1 docs/superpowers/plans/2026-04-29-release-readiness-foundation.md
rtk proxy git commit -m "ci: add Godot checks workflow"
```

## Task 5: Release Documentation and Steam Boundary

**Files:**

- Modify: `tools/tests/test_release_scripts.ps1`
- Create: `CHANGELOG.md`
- Create: `docs/release/release-process.md`
- Create: `docs/release/github-release-template.md`
- Create: `docs/release/steam-adapter.md`

- [x] **Step 1: Add failing tests for release docs**

Append this block before the final failure check in `tools/tests/test_release_scripts.ps1`:

```powershell
Assert-FileContains "CHANGELOG.md" "## Unreleased" "Changelog should keep an Unreleased section."
Assert-FileContains "docs\release\release-process.md" "tools/ci/run_godot_checks.ps1" "Release process should call the shared check script."
Assert-FileContains "docs\release\release-process.md" "tools/release/export_windows.ps1" "Release process should call the Windows export wrapper."
Assert-FileContains "docs\release\github-release-template.md" "Artifacts" "GitHub release template should include artifact notes."
Assert-FileContains "docs\release\steam-adapter.md" "PlatformService" "Steam adapter doc should name the platform boundary."
Assert-FileContains "docs\release\steam-adapter.md" "No Steam SDK" "Steam adapter doc should state SDK work is not included yet."
```

- [x] **Step 2: Run script tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected: FAIL because release documentation files do not exist.

- [x] **Step 3: Add changelog**

Create `CHANGELOG.md`:

```markdown
# Changelog

All notable project changes will be recorded here.

## Unreleased

### Added

- Release readiness foundation: shared Godot checks, Windows export wrapper, CI entry point, release checklist, release draft template, and Steam adapter boundary documentation.

## Baseline

### Added

- Godot vertical slice with seeded map flow, combat, rewards, events, shop, save/continue, presentation hooks, project-owned polish assets, and DevTools panels for cards, enemy sandbox, event tester, reward inspector, and save inspector.
```

- [x] **Step 4: Add release process document**

Create `docs/release/release-process.md`:

````markdown
# Release Process

This project is Windows-first. Release automation starts with local checks and a Windows artifact wrapper, then can grow into signed builds, checksums, and store uploads.

## Local Quality Gate

Run the shared Godot check script before creating release artifacts:

```powershell
.\tools\ci\run_godot_checks.ps1
```

This runs:

- `res://scripts/testing/test_runner.gd`
- Godot headless import/project load check

The known malformed status intent test may print an intentional Godot `ERROR` after `TESTS PASSED`.

## Windows Artifact

Build the Windows executable with:

```powershell
.\tools\release\export_windows.ps1
```

The wrapper uses the existing Godot export preset:

- Preset: `Windows Desktop`
- Primary artifact: `export/MySlaytheSpire.exe`
- Artifact copy: `export/artifacts/MySlaytheSpire.exe`

If Godot export templates are missing, install Godot 4.6.2 Windows export templates and rerun the command.

## Release Draft

Use `docs/release/github-release-template.md` as the release body.

Before publishing a release:

1. Confirm the working tree is clean.
2. Run `.\tools\ci\run_godot_checks.ps1`.
3. Run `.\tools\release\export_windows.ps1`.
4. Attach the artifact from `export/artifacts/`.
5. Copy changelog entries from `CHANGELOG.md`.
6. Record known issues and follow-up work.

## Future Extensions

- Zip Windows artifacts.
- Generate checksums.
- Add version bump automation.
- Add signed builds.
- Add release upload automation after token handling is designed.
- Add Linux, macOS, or Steam Deck presets.
- Add Steam depot upload after the Steam adapter implementation exists.
````

- [x] **Step 5: Add GitHub release template**

Create `docs/release/github-release-template.md`:

```markdown
# Release Draft

## Summary

- 

## Artifacts

- Windows executable: attach `export/artifacts/MySlaytheSpire.exe` after running `.\tools\release\export_windows.ps1`.

## Verification

- [ ] `.\tools\ci\run_godot_checks.ps1`
- [ ] `.\tools\release\export_windows.ps1`
- [ ] Manual smoke pass on Windows

## Known Issues

- 

## Follow-up

- 
```

- [x] **Step 6: Add Steam adapter boundary doc**

Create `docs/release/steam-adapter.md`:

```markdown
# Steam Adapter Boundary

No Steam SDK is integrated in this foundation.

Future Steam work should implement the existing platform abstraction instead of adding Steam calls to gameplay, UI, save, reward, event, combat, map, or DevTools code.

## Existing Boundary

- `scripts/platform/platform_service.gd`
- `scripts/platform/local_platform_service.gd`

Current platform capabilities:

- `unlock_achievement(achievement_id: String)`
- `set_stat(stat_id: String, value: int)`
- `get_platform_language() -> String`

## Future Steam Implementation Rules

- Add a Steam-specific implementation of `PlatformService`.
- Keep SDK initialization, callback polling, and shutdown in platform/app setup code.
- Add local fallback behavior for every new platform method before wiring Steam.
- Add tests for the platform interface before using new capabilities in gameplay.
- Keep Steam depot upload and release publishing in release tooling, not gameplay code.

## Explicit Non-Goals For This Foundation

- No Steamworks binary dependency.
- No Steam API calls.
- No depot upload.
- No achievements beyond the existing abstract method.
- No leaderboard or cloud save implementation.
```

- [x] **Step 7: Run docs tests to verify GREEN**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected:

```text
Release script tests passed.
```

- [x] **Step 8: Commit Task 5**

Run:

```powershell
rtk proxy git add CHANGELOG.md docs/release/release-process.md docs/release/github-release-template.md docs/release/steam-adapter.md tools/tests/test_release_scripts.ps1 docs/superpowers/plans/2026-04-29-release-readiness-foundation.md
rtk proxy git commit -m "docs: add release process foundation"
```

## Task 6: README Progress and Final Verification

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-release-readiness-foundation.md`

- [ ] **Step 1: Update README commands**

In `README.md`, replace the `## Local Commands` section with:

````markdown
## Local Commands

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
.\tools\ci\run_godot_checks.ps1
```

Run Windows export:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
.\tools\release\export_windows.ps1
```
````

- [ ] **Step 2: Update README progress and Next Plans**

In `README.md`, add this progress bullet after the DevTools bullets:

```markdown
- Release readiness foundation: complete; local and CI Godot checks now share a PowerShell entry point, Windows export has a wrapper around the existing preset, release notes/checklists/templates are documented, and future Steam work is bounded behind `PlatformService`.
```

Update `## Next Plans` to:

```markdown
## Next Plans

1. Presentation expansion: more per-card cue ids, enemy intent polish, card art, richer combat backgrounds, and formal audio mixing.
2. Release expansion: artifact packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
```

- [ ] **Step 3: Run script tests**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/tests/test_release_scripts.ps1
```

Expected:

```text
Release script tests passed.
```

- [ ] **Step 4: Run shared Godot checks**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [ ] **Step 5: Run Windows export dry run**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/release/export_windows.ps1 -DryRun
```

Expected:

```text
Dry run: Godot export command resolved.
```

- [ ] **Step 6: Run Windows export**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/release/export_windows.ps1
```

Expected if templates are installed:

```text
Windows export complete:
```

If templates are missing, record the exact error and confirm it is clear and actionable.

- [ ] **Step 7: Run direct import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 8: Verify CI workflow has no secrets or publishing permissions**

Run:

```powershell
rtk proxy rg -n "secrets\\.|contents:\\s*write|id-token|actions/(upload|create).*release|softprops/action-gh-release|gh\\s+release|upload-artifact" .github/workflows/ci.yml
```

Expected: no matches.

- [ ] **Step 9: Final two-stage review**

Stage 1 Spec Compliance Review:

- CI workflow exists and routes through `tools/ci/run_godot_checks.ps1`.
- Shared check script runs the Godot test runner and import check.
- Windows export wrapper uses the `Windows Desktop` preset.
- Release docs and changelog exist.
- Steam adapter work is documentation only.
- README progress and Next Plans match shipped scope.

Stage 2 Code Quality Review:

- PowerShell scripts use strict mode, fail fast, and centralize Godot path resolution.
- Scripts do not delete files outside intended output paths.
- CI workflow does not require secrets or publishing permissions.
- Release docs do not claim publishing automation that does not exist.
- Steam expansion remains isolated behind `PlatformService`.

Fix any Critical or Important findings before acceptance.

- [ ] **Step 10: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after each step has been completed and verified.

- [ ] **Step 11: Commit Task 6**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-29-release-readiness-foundation.md
rtk proxy git commit -m "docs: record release readiness acceptance"
```

## Final Acceptance Criteria

- `tools/ci/run_godot_checks.ps1` runs the Godot test runner and import check.
- `.github/workflows/ci.yml` calls the shared check script.
- `tools/release/export_windows.ps1` wraps the existing Windows export preset.
- `tools/release/export_windows.ps1 -DryRun` succeeds.
- Real Windows export either produces `export/MySlaytheSpire.exe` and `export/artifacts/MySlaytheSpire.exe`, or fails with a clear missing-template error.
- `CHANGELOG.md` exists with an `Unreleased` section.
- Release process and GitHub release template docs exist.
- Steam adapter boundary doc exists and adds no SDK dependency.
- README lists release readiness commands and updated progress.
- Existing local tests pass through the shared check script.
- Godot import check exits 0.
