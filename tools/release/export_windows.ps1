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

# Run with -DryRun to verify command resolution without invoking export.
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
