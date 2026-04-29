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
if (-not (Test-Path -LiteralPath $CommonScript)) {
	throw "Release script tests failed: $script:FailureCount"
}
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

	$env:GODOT4 = $tempDir
	Assert-ThrowsContaining { Resolve-Godot -FallbackPaths @() } "Set GODOT4" "Resolve-Godot should reject a directory path."

	$successCommand = Join-Path $tempDir "godot_success.cmd"
	$successOutput = Join-Path $tempDir "success_args.txt"
	Set-Content -LiteralPath $successCommand -Value @(
		"@echo off",
		"echo %* > ""$successOutput""",
		"exit /b 0"
	) -Encoding ASCII
	$env:GODOT4 = $successCommand
	Invoke-GodotCommand -Arguments @("--headless", "--quit") -FallbackPaths @()
	Assert-True (Test-Path -LiteralPath $successOutput) "Invoke-GodotCommand should run the resolved command."
	Assert-Equal "--headless --quit " ((Get-Content -LiteralPath $successOutput -Raw).TrimEnd("`r", "`n")) "Invoke-GodotCommand should pass arguments to the command."

	$scriptSuccessCommand = Join-Path $tempDir "godot_script_success.ps1"
	$scriptSuccessOutput = Join-Path $tempDir "script_success_args.txt"
	Set-Content -LiteralPath $scriptSuccessCommand -Value @(
		"Set-Content -LiteralPath '$scriptSuccessOutput' -Value (`$args -join ' ') -Encoding ASCII"
	) -Encoding ASCII
	$env:GODOT4 = $scriptSuccessCommand
	Remove-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
	Invoke-GodotCommand -Arguments @("--headless", "--script") -FallbackPaths @()
	Assert-True (Test-Path -LiteralPath $scriptSuccessOutput) "Invoke-GodotCommand should allow successful commands that do not set LASTEXITCODE."
	Assert-Equal "--headless --script" ((Get-Content -LiteralPath $scriptSuccessOutput -Raw).TrimEnd("`r", "`n")) "Invoke-GodotCommand should pass arguments to script commands."

	$scriptStaleOutput = Join-Path $tempDir "script_stale_args.txt"
	Set-Content -LiteralPath $scriptSuccessCommand -Value @(
		"Set-Content -LiteralPath '$scriptStaleOutput' -Value (`$args -join ' ') -Encoding ASCII"
	) -Encoding ASCII
	$global:LASTEXITCODE = 9
	Invoke-GodotCommand -Arguments @("--headless", "--quit") -FallbackPaths @()
	Assert-True (Test-Path -LiteralPath $scriptStaleOutput) "Invoke-GodotCommand should ignore stale nonzero LASTEXITCODE after successful script commands."
	Assert-Equal "--headless --quit" ((Get-Content -LiteralPath $scriptStaleOutput -Raw).TrimEnd("`r", "`n")) "Invoke-GodotCommand should pass arguments when LASTEXITCODE is stale."

	$failureCommand = Join-Path $tempDir "godot_failure.cmd"
	Set-Content -LiteralPath $failureCommand -Value @(
		"@echo off",
		"exit /b 7"
	) -Encoding ASCII
	$env:GODOT4 = $failureCommand
	Assert-ThrowsContaining { Invoke-GodotCommand -Arguments @("--bad") -FallbackPaths @() } "Godot exited with code 7" "Invoke-GodotCommand should throw when Godot exits nonzero."
} finally {
	$env:GODOT4 = $originalGodot
	if (Test-Path -LiteralPath $tempDir) {
		Remove-Item -LiteralPath $tempDir -Recurse -Force
	}
}

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
Assert-FileContains "tools\release\export_windows.ps1" "Windows Desktop" "Windows export script should use the existing preset."
Assert-FileContains "tools\release\export_windows.ps1" "export/MySlaytheSpire.exe" "Windows export script should preserve the configured artifact path."
Assert-FileContains "tools\release\export_windows.ps1" "--export-release" "Windows export script should use Godot release export."
Assert-FileContains "tools\release\export_windows.ps1" "-DryRun" "Windows export script should expose a dry-run path for script verification."
Assert-ThrowsContaining {
	& (Join-Path $ProjectRoot "tools\release\export_windows.ps1") -ExportPath "..\outside\game.exe" -DryRun
} "ExportPath must stay under" "Windows export script should reject paths outside export directory."
Assert-FileContains ".github\workflows\ci.yml" "tools/ci/run_godot_checks.ps1" "CI workflow should call the shared Godot check script."
Assert-FileContains ".github\workflows\ci.yml" "pull_request" "CI workflow should run on pull requests."
Assert-FileContains ".github\workflows\ci.yml" "workflow_dispatch" "CI workflow should support manual dispatch."
Assert-FileContains ".github\workflows\ci.yml" "GODOT4=" "CI workflow should publish GODOT4 for the shared script."
Assert-FileContains "CHANGELOG.md" "## Unreleased" "Changelog should keep an Unreleased section."
Assert-FileContains "docs\release\release-process.md" "tools/ci/run_godot_checks.ps1" "Release process should call the shared check script."
Assert-FileContains "docs\release\release-process.md" "tools/release/export_windows.ps1" "Release process should call the Windows export wrapper."
Assert-FileContains "docs\release\github-release-template.md" "Artifacts" "GitHub release template should include artifact notes."
Assert-FileContains "docs\release\steam-adapter.md" "PlatformService" "Steam adapter doc should name the platform boundary."
Assert-FileContains "docs\release\steam-adapter.md" "No Steam SDK" "Steam adapter doc should state SDK work is not included yet."

if ($script:FailureCount -gt 0) {
	throw "Release script tests failed: $script:FailureCount"
}

Write-Host "Release script tests passed."
