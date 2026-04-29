[CmdletBinding()]
param(
	[string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
	$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
}

. (Join-Path $scriptRoot "..\common\godot.ps1")

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Write-Host "Project root: $resolvedProjectRoot"

$originalGodot = $env:GODOT4
if (-not [string]::IsNullOrWhiteSpace($env:GODOT4)) {
	$godotDirectory = Split-Path -Parent $env:GODOT4
	$godotFile = Split-Path -Leaf $env:GODOT4
	$consoleGodot = Join-Path $godotDirectory ($godotFile -replace "_win64\.exe$", "_win64_console.exe")
	if (($godotFile -like "*_win64.exe") -and (Test-Path -LiteralPath $consoleGodot -PathType Leaf)) {
		$env:GODOT4 = $consoleGodot
	}
}

Write-Host "Running Godot import check..."
try {
	$global:LASTEXITCODE = 0
	Invoke-GodotCommand -Arguments @(
		"--headless",
		"--path",
		$resolvedProjectRoot,
		"--import",
		"--quit"
	)

	Write-Host "Running Godot test runner..."
	$global:LASTEXITCODE = 0
	Invoke-GodotCommand -Arguments @(
		"--headless",
		"--path",
		$resolvedProjectRoot,
		"--script",
		"res://scripts/testing/test_runner.gd"
	)

	Write-Host "Godot checks passed."
} finally {
	$env:GODOT4 = $originalGodot
}
