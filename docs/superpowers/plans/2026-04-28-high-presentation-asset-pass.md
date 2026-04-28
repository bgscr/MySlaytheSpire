# High Presentation Asset Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current high-presentation debug visuals and inspect-only audio hook with project-owned texture/audio assets routed through a presentation asset catalog.

**Architecture:** Add first-party assets under `assets/presentation/`, add `CombatPresentationAssetCatalog` as the only asset lookup surface, and route `CombatPresentationLayer` playback through catalog data. The combat rules and cue resolver remain presentation-data producers only; the layer owns playback and the catalog owns asset selection.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot-loadable PNG/WAV assets, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Before editing code, verify `git branch --show-current` is `main`; stop if it is not.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`:
  - Stage 1 Spec Compliance Review.
  - Stage 2 Code Quality Review only after Stage 1 passes.
- Keep `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` free of presentation imports.
- This plan intentionally overrides the writing-plans default worktree assumption because `AGENTS.md` requires the local `main` workspace.

## Reference Spec

- `docs/superpowers/specs/2026-04-28-high-presentation-asset-pass-design.md`

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

Create:

- `assets/presentation/textures/slash_cyan.png`: cyan-white sword qi texture for default and `sword.strike` slashes.
- `assets/presentation/textures/slash_gold.png`: gold-cyan heavy sword qi texture for later heavy slash mappings.
- `assets/presentation/textures/mist_green.png`: green alchemy mist particle texture for event fallback.
- `assets/presentation/textures/mist_violet.png`: violet-green poison mist particle texture for `alchemy.toxic_pill`.
- `assets/presentation/textures/slow_motion_wash.png`: subtle transparent wash texture for local slow-motion feedback.
- `assets/presentation/audio/slash_light.wav`: short wind-cut audio asset.
- `assets/presentation/audio/alchemy_mist.wav`: short alchemy mist release audio asset.
- `assets/presentation/audio/spirit_impact_heavy.wav`: short heavy spirit impact audio asset for `sword.heaven_cutting_arc`.
- `scripts/presentation/combat_presentation_asset_catalog.gd`: catalog that resolves cue-id/event-type asset data.

Modify:

- `scripts/presentation/combat_presentation_layer.gd`: replace slash and particle debug nodes with asset-backed `TextureRect` nodes; route camera, slow-motion, and audio parameters through the catalog.
- `tests/unit/test_combat_presentation.gd`: add asset catalog tests and update layer playback tests.
- `tests/smoke/test_scene_flow.gd`: verify representative cards trigger asset-backed slash, mist, slow-motion, and audio playback in combat.
- `README.md`: record asset pass completion after final acceptance.
- `docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md`: mark steps complete during execution.

## Task 1: Asset Catalog and Project Assets

**Files:**

- Create: `assets/presentation/textures/slash_cyan.png`
- Create: `assets/presentation/textures/slash_gold.png`
- Create: `assets/presentation/textures/mist_green.png`
- Create: `assets/presentation/textures/mist_violet.png`
- Create: `assets/presentation/textures/slow_motion_wash.png`
- Create: `assets/presentation/audio/slash_light.wav`
- Create: `assets/presentation/audio/alchemy_mist.wav`
- Create: `assets/presentation/audio/spirit_impact_heavy.wav`
- Create: `scripts/presentation/combat_presentation_asset_catalog.gd`
- Modify: `tests/unit/test_combat_presentation.gd`
- Modify: `docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md`

- [x] **Step 1: Verify branch and workspace state**

Run:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
main
```

`git status --short` should show only intentional plan/doc changes before implementation starts.

- [x] **Step 2: Write failing catalog tests**

Modify `tests/unit/test_combat_presentation.gd`.

Add this preload near the other presentation preloads:

```gdscript
const CombatPresentationAssetCatalog := preload("res://scripts/presentation/combat_presentation_asset_catalog.gd")
```

Append these tests before helper functions:

```gdscript
func test_asset_catalog_resolves_exact_cue_before_event_fallback() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var event := CombatPresentationEvent.new("particle_burst")
	event.payload = {"cue_id": "alchemy.toxic_pill"}

	var resolved := catalog.resolve(event)
	var passed: bool = resolved.get("texture_path", "") == "res://assets/presentation/textures/mist_violet.png" \
		and int(resolved.get("particle_count", 0)) == 7 \
		and is_equal_approx(float(resolved.get("radius", 0.0)), 30.0)

	resolved["texture_path"] = "res://mutated.png"
	var resolved_again := catalog.resolve(event)
	passed = passed \
		and resolved_again.get("texture_path", "") == "res://assets/presentation/textures/mist_violet.png"

	assert(passed)
	return passed

func test_asset_catalog_resolves_event_fallbacks_and_unknown_safely() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var slash := catalog.resolve(CombatPresentationEvent.new("cinematic_slash"))
	var camera := catalog.resolve(CombatPresentationEvent.new("camera_impulse"))
	var unknown := catalog.resolve(CombatPresentationEvent.new("unknown_event"))
	var audio := catalog.resolve(CombatPresentationEvent.new("audio_cue"))

	var passed: bool = slash.get("texture_path", "") == "res://assets/presentation/textures/slash_cyan.png" \
		and is_equal_approx(float(camera.get("strength", 0.0)), 4.0) \
		and is_equal_approx(float(camera.get("duration", 0.0)), 0.18) \
		and unknown.is_empty() \
		and audio.is_empty()
	assert(passed)
	return passed

func test_asset_catalog_resolves_heaven_cutting_arc_slow_and_audio_separately() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	var slow := CombatPresentationEvent.new("slow_motion")
	slow.payload = {"cue_id": "sword.heaven_cutting_arc"}
	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "sword.heaven_cutting_arc"}

	var slow_asset := catalog.resolve(slow)
	var audio_asset := catalog.resolve(audio)

	var passed: bool = slow_asset.get("texture_path", "") == "res://assets/presentation/textures/slow_motion_wash.png" \
		and is_equal_approx(float(slow_asset.get("scale", 1.0)), 0.45) \
		and audio_asset.get("audio_path", "") == "res://assets/presentation/audio/spirit_impact_heavy.wav" \
		and not audio_asset.has("texture_path")
	assert(passed)
	return passed

func test_asset_catalog_registered_resources_load() -> bool:
	var catalog := CombatPresentationAssetCatalog.new()
	for path in catalog.resource_paths():
		var resource := load(path)
		if resource == null:
			push_error("Presentation asset failed to load: %s" % path)
			assert(false)
			return false
	assert(true)
	return true
```

- [x] **Step 3: Run catalog tests to verify they fail**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because `res://scripts/presentation/combat_presentation_asset_catalog.gd` does not exist yet, or because the referenced assets do not load yet.

- [x] **Step 4: Generate first-party texture and audio assets**

Run this one-time asset generation command:

```powershell
rtk proxy powershell -NoProfile -Command @'
New-Item -ItemType Directory -Force -Path "assets/presentation/textures" | Out-Null
New-Item -ItemType Directory -Force -Path "assets/presentation/audio" | Out-Null
Add-Type -AssemblyName System.Drawing

function Save-SlashTexture($Path, [System.Drawing.Color]$Core, [System.Drawing.Color]$Glow) {
    $bitmap = New-Object System.Drawing.Bitmap 192, 64
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    for ($i = 0; $i -lt 5; $i++) {
        $alpha = [Math]::Max(28, 110 - ($i * 18))
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($alpha, $Glow.R, $Glow.G, $Glow.B)), (18 - $i * 2)
        $graphics.DrawArc($pen, 12 + $i * 3, 8 + $i, 166 - $i * 6, 46 - $i * 2, 196, 126)
        $pen.Dispose()
    }
    $corePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(235, $Core.R, $Core.G, $Core.B)), 5
    $graphics.DrawArc($corePen, 20, 14, 152, 34, 198, 122)
    $corePen.Dispose()
    $tipBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(210, $Core.R, $Core.G, $Core.B))
    $graphics.FillEllipse($tipBrush, 154, 20, 18, 10)
    $tipBrush.Dispose()
    $graphics.Dispose()
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

function Save-MistTexture($Path, [System.Drawing.Color]$Core, [System.Drawing.Color]$Glow) {
    $bitmap = New-Object System.Drawing.Bitmap 64, 64
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    for ($i = 0; $i -lt 6; $i++) {
        $size = 48 - $i * 6
        $alpha = 48 + $i * 20
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alpha, $Glow.R, $Glow.G, $Glow.B))
        $graphics.FillEllipse($brush, 8 + $i * 3, 8 + $i * 3, $size, $size)
        $brush.Dispose()
    }
    $coreBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, $Core.R, $Core.G, $Core.B))
    $graphics.FillEllipse($coreBrush, 24, 22, 16, 18)
    $coreBrush.Dispose()
    $graphics.Dispose()
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

function Save-WashTexture($Path) {
    $bitmap = New-Object System.Drawing.Bitmap 96, 96
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(92, 172, 232, 255)), 10
    $graphics.DrawEllipse($pen, 12, 12, 72, 72)
    $pen.Dispose()
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(34, 172, 232, 255))
    $graphics.FillEllipse($brush, 20, 20, 56, 56)
    $brush.Dispose()
    $graphics.Dispose()
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

function Save-Wav($Path, [double]$Seconds, [double]$BaseFrequency, [double]$SecondFrequency, [double]$Attack) {
    $sampleRate = 44100
    $sampleCount = [int]($sampleRate * $Seconds)
    $writer = New-Object System.IO.BinaryWriter([System.IO.File]::Open($Path, [System.IO.FileMode]::Create))
    $dataLength = $sampleCount * 2
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int](36 + $dataLength))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $writer.Write([int]16)
    $writer.Write([short]1)
    $writer.Write([short]1)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]($sampleRate * 2))
    $writer.Write([short]2)
    $writer.Write([short]16)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $writer.Write([int]$dataLength)
    for ($i = 0; $i -lt $sampleCount; $i++) {
        $t = $i / $sampleRate
        $fadeIn = [Math]::Min(1.0, $t / $Attack)
        $fadeOut = [Math]::Pow([Math]::Max(0.0, 1.0 - ($t / $Seconds)), 1.8)
        $sample = ([Math]::Sin(2.0 * [Math]::PI * $BaseFrequency * $t) * 0.55) + ([Math]::Sin(2.0 * [Math]::PI * $SecondFrequency * $t) * 0.28)
        $value = [short]([Math]::Max(-0.8, [Math]::Min(0.8, $sample * $fadeIn * $fadeOut)) * 32767)
        $writer.Write($value)
    }
    $writer.Close()
}

Save-SlashTexture "assets/presentation/textures/slash_cyan.png" ([System.Drawing.Color]::FromArgb(226, 250, 255)) ([System.Drawing.Color]::FromArgb(74, 196, 255))
Save-SlashTexture "assets/presentation/textures/slash_gold.png" ([System.Drawing.Color]::FromArgb(255, 246, 196)) ([System.Drawing.Color]::FromArgb(255, 190, 76))
Save-MistTexture "assets/presentation/textures/mist_green.png" ([System.Drawing.Color]::FromArgb(190, 255, 210)) ([System.Drawing.Color]::FromArgb(72, 220, 128))
Save-MistTexture "assets/presentation/textures/mist_violet.png" ([System.Drawing.Color]::FromArgb(220, 196, 255)) ([System.Drawing.Color]::FromArgb(136, 92, 220))
Save-WashTexture "assets/presentation/textures/slow_motion_wash.png"
Save-Wav "assets/presentation/audio/slash_light.wav" 0.18 720.0 1260.0 0.015
Save-Wav "assets/presentation/audio/alchemy_mist.wav" 0.28 260.0 520.0 0.035
Save-Wav "assets/presentation/audio/spirit_impact_heavy.wav" 0.34 96.0 288.0 0.02
'@
```

Expected: eight files exist under `assets/presentation/`.

- [x] **Step 5: Create the asset catalog**

Create `scripts/presentation/combat_presentation_asset_catalog.gd`:

```gdscript
class_name CombatPresentationAssetCatalog
extends RefCounted

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")

const TEXTURE_SLASH_CYAN := "res://assets/presentation/textures/slash_cyan.png"
const TEXTURE_SLASH_GOLD := "res://assets/presentation/textures/slash_gold.png"
const TEXTURE_MIST_GREEN := "res://assets/presentation/textures/mist_green.png"
const TEXTURE_MIST_VIOLET := "res://assets/presentation/textures/mist_violet.png"
const TEXTURE_SLOW_WASH := "res://assets/presentation/textures/slow_motion_wash.png"
const AUDIO_SLASH_LIGHT := "res://assets/presentation/audio/slash_light.wav"
const AUDIO_ALCHEMY_MIST := "res://assets/presentation/audio/alchemy_mist.wav"
const AUDIO_SPIRIT_IMPACT_HEAVY := "res://assets/presentation/audio/spirit_impact_heavy.wav"

var _cue_assets := {
	"cinematic_slash:sword.strike": {
		"texture_path": TEXTURE_SLASH_CYAN,
		"size": Vector2(118.0, 38.0),
		"travel": Vector2(34.0, -4.0),
		"rotation": -0.45,
		"duration": 0.28,
		"scale_to": Vector2(1.18, 1.05),
		"color": Color(0.92, 0.98, 1.0, 0.95),
	},
	"particle_burst:alchemy.toxic_pill": {
		"texture_path": TEXTURE_MIST_VIOLET,
		"particle_count": 7,
		"radius": 30.0,
		"duration": 0.48,
		"size": Vector2(20.0, 20.0),
		"color": Color(0.82, 0.72, 1.0, 0.92),
	},
	"slow_motion:sword.heaven_cutting_arc": {
		"texture_path": TEXTURE_SLOW_WASH,
		"scale": 0.45,
		"duration": 0.52,
		"size": Vector2(144.0, 144.0),
		"color": Color(0.72, 0.92, 1.0, 0.28),
	},
	"audio_cue:sword.heaven_cutting_arc": {
		"audio_path": AUDIO_SPIRIT_IMPACT_HEAVY,
		"volume_db": -7.0,
	},
}

var _event_assets := {
	"cinematic_slash": {
		"texture_path": TEXTURE_SLASH_CYAN,
		"size": Vector2(104.0, 34.0),
		"travel": Vector2(28.0, -2.0),
		"rotation": -0.55,
		"duration": 0.32,
		"scale_to": Vector2(1.12, 1.0),
		"color": Color(0.9, 0.96, 1.0, 0.9),
	},
	"particle_burst": {
		"texture_path": TEXTURE_MIST_GREEN,
		"particle_count": 6,
		"radius": 26.0,
		"duration": 0.42,
		"size": Vector2(18.0, 18.0),
		"color": Color(0.62, 1.0, 0.72, 0.9),
	},
	"camera_impulse": {
		"strength": 4.0,
		"duration": 0.18,
		"direction": Vector2(1.0, -0.5),
	},
	"slow_motion": {
		"texture_path": TEXTURE_SLOW_WASH,
		"scale": 0.65,
		"duration": 0.35,
		"size": Vector2(120.0, 120.0),
		"color": Color(0.72, 0.92, 1.0, 0.2),
	},
}

func resolve(event: CombatPresentationEvent) -> Dictionary:
	if event == null:
		return {}
	var event_type := String(event.event_type)
	var cue_id := String(event.payload.get("cue_id", ""))
	if not cue_id.is_empty():
		var cue_key := "%s:%s" % [event_type, cue_id]
		if _cue_assets.has(cue_key):
			return _cue_assets[cue_key].duplicate(true)
	if _event_assets.has(event_type):
		return _event_assets[event_type].duplicate(true)
	return {}

func resource_paths() -> Array[String]:
	var paths: Array[String] = []
	for asset in _cue_assets.values():
		_append_asset_paths(paths, asset)
	for asset in _event_assets.values():
		_append_asset_paths(paths, asset)
	for path in [
		TEXTURE_SLASH_GOLD,
		AUDIO_SLASH_LIGHT,
		AUDIO_ALCHEMY_MIST,
	]:
		if not paths.has(path):
			paths.append(path)
	return paths

func _append_asset_paths(paths: Array[String], asset: Dictionary) -> void:
	for key in ["texture_path", "audio_path"]:
		var path := String(asset.get(key, ""))
		if not path.is_empty() and not paths.has(path):
			paths.append(path)
```

- [x] **Step 6: Run catalog tests to verify they pass**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [x] **Step 7: Run Godot import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [x] **Step 8: Run two-stage review for Task 1**

Stage 1 Spec Compliance Review:

- Asset files exist under `assets/presentation/textures/` and `assets/presentation/audio/`.
- `CombatPresentationAssetCatalog` exists.
- Exact event type plus cue id resolves before event fallback.
- Event fallback resolves slash, particles, camera impulse, and slow motion.
- Unknown events return an empty dictionary.
- All registered resource paths load successfully.

Stage 2 Code Quality Review:

- Catalog data stays isolated from combat classes.
- `resolve()` returns duplicated dictionaries.
- Resource paths are centralized constants.
- `resource_paths()` covers every committed asset, including currently unused first-batch audio/gold slash assets.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before committing.

- [x] **Step 9: Commit Task 1**

Run:

```powershell
rtk proxy git add assets/presentation scripts/presentation/combat_presentation_asset_catalog.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md
rtk proxy git commit -m "feat: add presentation asset catalog"
```

## Task 2: Texture-Backed Slash and Particle Playback

**Files:**

- Modify: `scripts/presentation/combat_presentation_layer.gd`
- Modify: `tests/unit/test_combat_presentation.gd`
- Modify: `docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md`

- [x] **Step 1: Update failing layer visual tests**

Modify `tests/unit/test_combat_presentation.gd`.

Replace `test_layer_plays_cinematic_slash_and_particle_placeholders` with:

```gdscript
func test_layer_plays_cinematic_slash_and_particle_assets(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var target := Button.new()
	target.position = Vector2(40, 50)
	layer.bind_target("enemy:0", target)
	layer.add_child(target)

	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.target_id = "enemy:0"
	slash.payload = {"cue_id": "sword.strike"}
	layer.play_event(slash)
	var particle := CombatPresentationEvent.new("particle_burst")
	particle.target_id = "enemy:0"
	particle.payload = {"cue_id": "alchemy.toxic_pill"}
	layer.play_event(particle)

	var slash_node := layer.get_node_or_null("CinematicSlash_0") as TextureRect
	var particle_node := layer.get_node_or_null("ParticleBurst_0_0") as TextureRect
	var passed: bool = slash_node != null \
		and slash_node.texture != null \
		and particle_node != null \
		and particle_node.texture != null \
		and layer.get_node_or_null("CinematicSlash_0") is TextureRect \
		and layer.get_node_or_null("ParticleBurst_0_0") is TextureRect
	layer.free()
	assert(passed)
	return passed
```

Append this fallback test before helper functions:

```gdscript
func test_layer_uses_event_fallback_assets_without_cue_id(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var target := Button.new()
	target.position = Vector2(24, 36)
	layer.bind_target("enemy:0", target)
	layer.add_child(target)

	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.target_id = "enemy:0"
	layer.play_event(slash)

	var slash_node := layer.get_node_or_null("CinematicSlash_0") as TextureRect
	var passed: bool = slash_node != null and slash_node.texture != null
	layer.free()
	assert(passed)
	return passed
```

- [x] **Step 2: Run layer visual tests to verify they fail**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because `CombatPresentationLayer` still creates `ColorRect` nodes for slash and particles.

- [x] **Step 3: Add the asset catalog to the layer**

Modify `scripts/presentation/combat_presentation_layer.gd`.

Add this preload near the top:

```gdscript
const CombatPresentationAssetCatalog := preload("res://scripts/presentation/combat_presentation_asset_catalog.gd")
```

Add this field near the other presentation state:

```gdscript
var asset_catalog := CombatPresentationAssetCatalog.new()
```

Remove these old color constants:

```gdscript
const SLASH_COLOR := Color(0.9, 0.96, 1.0, 0.9)
const PARTICLE_COLOR := Color(0.46, 0.92, 0.66, 0.85)
```

- [x] **Step 4: Replace slash playback with texture-backed playback**

Replace `_show_cinematic_slash()` in `scripts/presentation/combat_presentation_layer.gd`:

```gdscript
func _show_cinematic_slash(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var asset := asset_catalog.resolve(event)
	var texture := _load_texture(asset)
	if texture == null:
		return
	var slash := TextureRect.new()
	slash.name = "CinematicSlash_%s" % _slash_index
	_slash_index += 1
	slash.texture = texture
	slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slash.stretch_mode = TextureRect.STRETCH_SCALE
	slash.size = asset.get("size", Vector2(104.0, 34.0))
	slash.pivot_offset = slash.size * 0.5
	slash.rotation = float(asset.get("rotation", -0.55))
	slash.modulate = asset.get("color", Color.WHITE)
	slash.position = _target_position(event.target_id) + Vector2(-24.0, -22.0)
	add_child(slash)

	var duration := float(asset.get("duration", SLASH_DURATION))
	var travel := asset.get("travel", Vector2(28.0, -2.0)) as Vector2
	var scale_to := asset.get("scale_to", Vector2(1.12, 1.0)) as Vector2
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "position", slash.position + travel, duration)
	tween.tween_property(slash, "scale", scale_to, duration)
	tween.tween_property(slash, "modulate:a", 0.0, duration)
	tween.finished.connect(slash.queue_free)
```

- [x] **Step 5: Replace particle playback with texture-backed playback**

Replace `_show_particle_burst()` in `scripts/presentation/combat_presentation_layer.gd`:

```gdscript
func _show_particle_burst(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var asset := asset_catalog.resolve(event)
	var texture := _load_texture(asset)
	if texture == null:
		return
	var burst_index := _particle_burst_index
	_particle_burst_index += 1
	var origin := _target_position(event.target_id) + Vector2(12.0, -10.0)
	var particle_count := maxi(1, int(asset.get("particle_count", 6)))
	var particle_size := asset.get("size", Vector2(18.0, 18.0)) as Vector2
	var radius := float(asset.get("radius", 26.0))
	var duration := float(asset.get("duration", PARTICLE_DURATION))
	var color := asset.get("color", Color.WHITE) as Color
	for particle_index in range(particle_count):
		var particle := TextureRect.new()
		particle.name = "ParticleBurst_%s_%s" % [burst_index, particle_index]
		particle.texture = texture
		particle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		particle.stretch_mode = TextureRect.STRETCH_SCALE
		particle.size = particle_size
		particle.pivot_offset = particle.size * 0.5
		particle.modulate = color
		particle.position = origin
		add_child(particle)
		var angle := TAU * float(particle_index) / float(particle_count)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", origin + offset, duration)
		tween.tween_property(particle, "scale", Vector2(0.6, 0.6), duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.finished.connect(particle.queue_free)
```

Add this helper below `_target_position()`:

```gdscript
func _load_texture(asset: Dictionary) -> Texture2D:
	var path := String(asset.get("texture_path", ""))
	if path.is_empty():
		return null
	return load(path) as Texture2D
```

- [x] **Step 6: Run visual layer tests to verify they pass**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [x] **Step 7: Run two-stage review for Task 2**

Stage 1 Spec Compliance Review:

- `cinematic_slash` creates `TextureRect` nodes with real textures.
- `particle_burst` creates `TextureRect` nodes with real textures.
- Cue-id-specific slash and particle assets resolve through the catalog.
- Event fallback assets work when no cue id is present.
- Missing targets or missing textures are ignored safely.

Stage 2 Code Quality Review:

- Layer asks the catalog for data and does not hard-code resource paths.
- Texture loading is centralized in `_load_texture()`.
- Temporary visual node names remain predictable.
- Tween cleanup still frees temporary nodes.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before committing.

- [x] **Step 8: Commit Task 2**

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_layer.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md
rtk proxy git commit -m "feat: play presentation texture assets"
```

## Task 3: Catalog-Driven Camera, Slow Motion, and Audio Playback

**Files:**

- Modify: `scripts/presentation/combat_presentation_layer.gd`
- Modify: `tests/unit/test_combat_presentation.gd`
- Modify: `docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md`

- [ ] **Step 1: Update failing camera, slow-motion, and audio tests**

Modify `tests/unit/test_combat_presentation.gd`.

Replace `test_layer_camera_impulse_restores_position` with:

```gdscript
func test_layer_camera_impulse_uses_catalog_and_restores_position(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	layer.position = Vector2(12, 18)
	var impulse := CombatPresentationEvent.new("camera_impulse")
	impulse.intensity = 1.5
	layer.play_event(impulse)
	var moved := layer.position == Vector2(18.0, 15.0)
	_finish_processed_tweens(tree)
	var restored := layer.position == Vector2(12, 18)
	var passed: bool = moved and restored
	layer.free()
	assert(passed)
	return passed
```

Replace `test_layer_records_slow_motion_and_audio_cue_without_global_timescale` with:

```gdscript
func test_layer_plays_slow_motion_wash_and_audio_stream_without_global_timescale(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)
	var original_time_scale := Engine.time_scale

	var slow := CombatPresentationEvent.new("slow_motion")
	slow.intensity = 0.5
	slow.payload = {"cue_id": "sword.heaven_cutting_arc"}
	layer.play_event(slow)

	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "sword.heaven_cutting_arc"}
	layer.play_event(audio)

	var wash := layer.get_node_or_null("SlowMotionWash_0") as TextureRect
	var player := layer.get_node_or_null("PresentationAudioPlayer") as AudioStreamPlayer
	var passed: bool = is_equal_approx(layer.active_slow_motion_scale, 0.45) \
		and wash != null \
		and wash.texture != null \
		and player != null \
		and player.stream != null \
		and layer.last_audio_cue_id == "sword.heaven_cutting_arc" \
		and layer.audio_cue_count == 1 \
		and is_equal_approx(Engine.time_scale, original_time_scale)
	layer.free()
	assert(passed)
	return passed
```

Append this no-audio fallback test before helper functions:

```gdscript
func test_layer_records_unmapped_audio_cue_without_stream(tree: SceneTree) -> bool:
	var layer := CombatPresentationLayer.new()
	tree.root.add_child(layer)

	var audio := CombatPresentationEvent.new("audio_cue")
	audio.payload = {"cue_id": "unmapped.cue"}
	layer.play_event(audio)

	var player := layer.get_node_or_null("PresentationAudioPlayer") as AudioStreamPlayer
	var passed: bool = layer.last_audio_cue_id == "unmapped.cue" \
		and layer.audio_cue_count == 1 \
		and player == null
	layer.free()
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because camera duration/direction, slow-motion wash, and audio streams are not catalog-driven yet.

- [ ] **Step 3: Add slow-motion state fields**

Modify `scripts/presentation/combat_presentation_layer.gd`.

Add these fields near `_camera_base_position`:

```gdscript
var _slow_motion_wash_index := 0
var _audio_player: AudioStreamPlayer
```

- [ ] **Step 4: Replace camera impulse with catalog-driven parameters**

Replace `_play_camera_impulse()` in `scripts/presentation/combat_presentation_layer.gd`:

```gdscript
func _play_camera_impulse(event: CombatPresentationEvent) -> void:
	var asset := asset_catalog.resolve(event)
	_camera_base_position = position
	var strength := float(asset.get("strength", 4.0)) * maxf(0.25, event.intensity)
	var direction := asset.get("direction", Vector2(1.0, -0.5)) as Vector2
	position = _camera_base_position + direction * strength
	var tween := create_tween()
	tween.tween_property(
		self,
		"position",
		_camera_base_position,
		float(asset.get("duration", CAMERA_IMPULSE_DURATION))
	)
```

- [ ] **Step 5: Replace slow-motion playback with catalog-driven local state and wash texture**

Replace `_record_slow_motion()` in `scripts/presentation/combat_presentation_layer.gd`:

```gdscript
func _record_slow_motion(event: CombatPresentationEvent) -> void:
	var asset := asset_catalog.resolve(event)
	active_slow_motion_scale = clampf(float(asset.get("scale", event.intensity)), 0.1, 1.0)
	var duration := float(asset.get("duration", SLOW_MOTION_DURATION))
	_show_slow_motion_wash(asset, duration)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func(): active_slow_motion_scale = 1.0)
```

Add this helper below `_show_particle_burst()`:

```gdscript
func _show_slow_motion_wash(asset: Dictionary, duration: float) -> void:
	var texture := _load_texture(asset)
	if texture == null:
		return
	var wash := TextureRect.new()
	wash.name = "SlowMotionWash_%s" % _slow_motion_wash_index
	_slow_motion_wash_index += 1
	wash.texture = texture
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.size = asset.get("size", Vector2(120.0, 120.0))
	wash.pivot_offset = wash.size * 0.5
	wash.modulate = asset.get("color", Color(0.72, 0.92, 1.0, 0.2))
	wash.position = _slow_motion_wash_position(wash.size)
	add_child(wash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wash, "scale", Vector2(1.18, 1.18), duration)
	tween.tween_property(wash, "modulate:a", 0.0, duration)
	tween.finished.connect(wash.queue_free)

func _slow_motion_wash_position(wash_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return Vector2.ZERO
	return viewport_size * 0.5 - global_position - wash_size * 0.5
```

- [ ] **Step 6: Replace audio cue recording with real AudioStreamPlayer playback**

Replace `_record_audio_cue()` in `scripts/presentation/combat_presentation_layer.gd`:

```gdscript
func _record_audio_cue(event: CombatPresentationEvent) -> void:
	last_audio_cue_id = String(event.payload.get("cue_id", event.text))
	audio_cue_count += 1
	var asset := asset_catalog.resolve(event)
	var path := String(asset.get("audio_path", ""))
	if path.is_empty():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := _presentation_audio_player()
	player.stream = stream
	player.volume_db = float(asset.get("volume_db", -8.0))
	player.play()
```

Add this helper below `_record_audio_cue()`:

```gdscript
func _presentation_audio_player() -> AudioStreamPlayer:
	if _audio_player != null and is_instance_valid(_audio_player):
		return _audio_player
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "PresentationAudioPlayer"
	add_child(_audio_player)
	return _audio_player
```

- [ ] **Step 7: Run tests to verify they pass**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 8: Run two-stage review for Task 3**

Stage 1 Spec Compliance Review:

- `camera_impulse` strength, direction, and duration come from catalog data.
- `slow_motion` scale and duration come from catalog data.
- `slow_motion` can create a texture-backed wash node.
- `audio_cue` can load and play a real `AudioStream`.
- Unmapped audio cues remain safe and still update inspectable state.
- `Engine.time_scale` remains unchanged.

Stage 2 Code Quality Review:

- Audio player creation is lazy and reusable.
- Local slow-motion state cleanup is deterministic.
- Resource loading stays inside presentation layer helpers.
- Camera impulse still restores original layer position.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before committing.

- [ ] **Step 9: Commit Task 3**

Run:

```powershell
rtk proxy git add scripts/presentation/combat_presentation_layer.gd tests/unit/test_combat_presentation.gd docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md
rtk proxy git commit -m "feat: route polish playback through assets"
```

## Task 4: Combat Integration Smoke Coverage

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md`

- [ ] **Step 1: Update slash smoke test to assert texture asset playback**

Modify `tests/smoke/test_scene_flow.gd`.

In `test_combat_screen_click_play_triggers_slash_polish_feedback`, replace:

```gdscript
var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0")
var passed: bool = first_card != null and enemy_button != null and slash != null
```

with:

```gdscript
var slash := _find_node_by_name(combat.presentation_layer, "CinematicSlash_0") as TextureRect
var passed: bool = first_card != null \
	and enemy_button != null \
	and slash != null \
	and slash.texture != null
```

- [ ] **Step 2: Add alchemy mist smoke test**

Append this test after `test_combat_screen_cinematic_disabled_filters_slash_but_plays_card`:

```gdscript
func test_combat_screen_click_play_triggers_particle_asset_feedback(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_particle_asset_save.json")
	var run := RunStateScript.new()
	run.seed_value = 12345
	run.character_id = "alchemy"
	run.max_hp = 68
	run.current_hp = 68
	run.deck_ids = ["alchemy.toxic_pill"]
	run.current_node_id = "node_0"
	var node := preload("res://scripts/run/map_node_state.gd").new("node_0", 0, "combat")
	node.unlocked = true
	run.map_nodes = [node]
	app.game.current_run = run

	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	combat.session.state.hand.clear()
	combat.session.state.hand.append("alchemy.toxic_pill")
	combat.session.state.draw_pile.clear()
	combat._refresh()
	var first_card := _find_node_by_name(combat, "CardButton_0") as Button
	if first_card != null:
		first_card.pressed.emit()
	var enemy_button := _find_node_by_name(combat, "EnemyButton_0") as Button
	if enemy_button != null:
		enemy_button.pressed.emit()
	combat.presentation_layer.process_queue()
	var particle := _find_node_by_name(combat.presentation_layer, "ParticleBurst_0_0") as TextureRect
	var passed: bool = first_card != null \
		and enemy_button != null \
		and particle != null \
		and particle.texture != null
	app.free()
	_delete_test_save("user://test_combat_particle_asset_save.json")
	return passed
```

- [ ] **Step 3: Update slow/audio smoke test to assert asset-backed playback**

In `test_explicit_slow_motion_and_audio_cues_are_recorded`, replace:

```gdscript
var passed: bool = played \
	and combat.presentation_layer.active_slow_motion_scale < 1.0 \
	and combat.presentation_layer.last_audio_cue_id == "sword.heaven_cutting_arc"
```

with:

```gdscript
var wash := _find_node_by_name(combat.presentation_layer, "SlowMotionWash_0") as TextureRect
var audio_player := _find_node_by_name(combat.presentation_layer, "PresentationAudioPlayer") as AudioStreamPlayer
var passed: bool = played \
	and combat.presentation_layer.active_slow_motion_scale < 1.0 \
	and combat.presentation_layer.last_audio_cue_id == "sword.heaven_cutting_arc" \
	and wash != null \
	and wash.texture != null \
	and audio_player != null \
	and audio_player.stream != null
```

- [ ] **Step 4: Run smoke tests to verify they pass**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 5: Run two-stage review for Task 4**

Stage 1 Spec Compliance Review:

- `sword.strike` triggers asset-backed slash through real combat card play.
- `alchemy.toxic_pill` triggers asset-backed mist particles through real combat card play.
- `sword.heaven_cutting_arc` triggers slow-motion wash and audio stream through real combat card play.
- Existing cinematic-disabled smoke coverage still filters slash and still plays the card.

Stage 2 Code Quality Review:

- Smoke tests use existing helper style and deterministic scene setup.
- Tests inspect presentation nodes without depending on real-time audio output.
- No production code changes were required for smoke-only assertions.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before committing.

- [ ] **Step 6: Commit Task 4**

Run:

```powershell
rtk proxy git add tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md
rtk proxy git commit -m "test: verify asset-backed polish in combat"
```

## Task 5: Final Acceptance, Documentation, and Reviews

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md`

- [ ] **Step 1: Run full local tests**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [ ] **Step 2: Run Godot import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 3: Verify core combat classes remain presentation-free**

Run:

```powershell
rtk proxy rg -n "presentation|CombatPresentation|assets/presentation" scripts/combat scripts/relic scripts/data/effect_def.gd
```

Expected: no output from core combat rule files. Existing data classes may mention presentation only in `scripts/data/card_def.gd` and `scripts/data/card_presentation_cue_def.gd`, which are outside the command above.

- [ ] **Step 4: Update README Phase 2 progress**

Modify `README.md`.

Append under `## Phase 2 Progress`:

```markdown
- High-presentation asset pass: complete; combat polish hooks now resolve project-owned texture/audio assets through a cue-id asset catalog for slash, mist, camera impulse, local slow-motion, and audio cue playback.
```

Update `## Next Plans` to:

```markdown
## Next Plans

1. Developer tools: card browser, enemy sandbox, event tester, reward inspector, save inspector.
2. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
3. Presentation expansion: more per-card cue ids, enemy intent polish, card art, richer combat backgrounds, and formal audio mixing.
```

- [ ] **Step 5: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [ ] **Step 6: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Project-owned texture and audio assets exist under `assets/presentation/`.
- `CombatPresentationAssetCatalog` resolves assets by cue id first and event type second.
- `CombatPresentationLayer` uses texture-backed slash and particle playback.
- `audio_cue` can load and play a real Godot audio stream when a cue mapping exists.
- Camera impulse and slow-motion tuning come from catalog data.
- Existing inspectable presentation state remains available for tests.
- Existing presentation config toggles still work.
- Existing combat click and drag play flows remain functional.
- `CombatEngine`, `EffectExecutor`, and `CombatStatusRuntime` do not import presentation scripts.
- No full card art, enemy art, global time scaling, persisted settings, external audio middleware, or all-card cue migration was added.

Stage 2 Code Quality Review:

- GDScript typing is clear for catalog, layer helpers, tests, and asset state.
- Catalog dictionaries are duplicated before returning.
- Resource paths are centralized.
- Layer helpers are small and playback-specific.
- Temporary nodes are predictably named and self-cleaning.
- Tests use explicit tween stepping where timing matters and do not depend on audible output.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

- [ ] **Step 7: Commit final acceptance docs**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-28-high-presentation-asset-pass.md
rtk proxy git commit -m "docs: record high presentation asset pass acceptance"
```

## Final Acceptance Criteria

- Project-owned texture and audio assets exist under `assets/presentation/`.
- `CombatPresentationAssetCatalog` resolves assets by cue id first and event type second.
- `CombatPresentationLayer` uses texture-backed slash and particle playback.
- `audio_cue` can play a real Godot audio stream when a cue mapping exists.
- Camera impulse and slow-motion tuning come from catalog data.
- Existing inspectable presentation state remains available for tests.
- Existing presentation config toggles still work.
- Existing combat click and drag play flows remain functional.
- No core combat rule class imports presentation scripts.
- Existing local tests pass.
- Godot import check exits 0.

## Execution Handoff

After this plan is accepted, choose one execution mode:

1. **Inline Execution:** execute tasks in this session with `superpowers:executing-plans`, staying on local `main` and running the review gates after each completed Godot feature. This is recommended for this project because `AGENTS.md` requires main-only development.
2. **Subagent-Driven:** only if the user explicitly authorizes subagents and confirms they will operate directly in the local `main` workspace without worktrees or branches. If used, dispatch one fresh subagent per task and keep the same review gates.
