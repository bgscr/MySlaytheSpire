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
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
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
