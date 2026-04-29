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
