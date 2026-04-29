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
