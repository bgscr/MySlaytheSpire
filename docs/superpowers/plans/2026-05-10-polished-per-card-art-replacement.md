# Polished Per-Card Art Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace shared foundation card thumbnails with 40 unique project-owned PNG thumbnails, one for each default card.

**Architecture:** Keep the existing visual pipeline unchanged: `CardVisualDef` remains the catalog data source, `CombatVisualResolver` resolves thumbnail paths, and existing combat/reward/shop/event UI surfaces render through current code paths. This pass adds PNG assets, repoints existing visual resources, strengthens catalog tests, imports assets, and documents acceptance.

**Tech Stack:** Godot 4.6.2-stable, GDScript, project-owned PNG assets, existing `ContentCatalog`, existing `CombatVisualResolver`, existing custom Godot test runner, PowerShell check wrapper, RTK command proxy, built-in image generation for project-bound raster assets.

---

## Project Constraints

- Work directly on `main` by default, following `AGENTS.md`.
- Prefix shell commands with `rtk`.
- Use red/green TDD for code/test behavior.
- Make surgical asset/data/test changes only.
- Do not modify combat rules, card effects, card costs, card types, reward logic, shop logic, event logic, map flow, save schema, release tooling, Steam work, audio, enemy art, background art, localization, or UI interaction targets.
- Do not add a new art manifest, card widget, deck browser, or UI layout redesign.
- Use the built-in image generation path for the 40 project-bound raster assets unless the user explicitly chooses another path.
- Commit generated PNGs inside `assets/presentation/card_thumbnails/`; do not leave project-referenced art only under `$CODEX_HOME/generated_images`.
- Include new `.import` files if Godot creates them.
- Run the two-stage review from `AGENTS.md` after implementation.

## Reference Spec

- `docs/superpowers/specs/2026-05-10-polished-per-card-art-replacement-design.md`

## Verification Commands

Run shared Godot checks:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1
```

Expected final result:

```text
Godot checks passed.
TESTS PASSED
```

The known malformed status intent test emits a Godot `ERROR` log intentionally. Treat the process exit code and `TESTS PASSED` line as the test result.

Run direct import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Create 40 PNG assets:

- `assets/presentation/card_thumbnails/alchemy_bitter_extract.png`
- `assets/presentation/card_thumbnails/alchemy_calming_powder.png`
- `assets/presentation/card_thumbnails/alchemy_cauldron_burst.png`
- `assets/presentation/card_thumbnails/alchemy_cauldron_overflow.png`
- `assets/presentation/card_thumbnails/alchemy_cinnabar_seal.png`
- `assets/presentation/card_thumbnails/alchemy_coiling_miasma.png`
- `assets/presentation/card_thumbnails/alchemy_golden_core_detox.png`
- `assets/presentation/card_thumbnails/alchemy_healing_draught.png`
- `assets/presentation/card_thumbnails/alchemy_inner_fire_pill.png`
- `assets/presentation/card_thumbnails/alchemy_mercury_bloom.png`
- `assets/presentation/card_thumbnails/alchemy_needle_rain.png`
- `assets/presentation/card_thumbnails/alchemy_ninefold_refine.png`
- `assets/presentation/card_thumbnails/alchemy_poison_mist.png`
- `assets/presentation/card_thumbnails/alchemy_purifying_brew.png`
- `assets/presentation/card_thumbnails/alchemy_quick_simmer.png`
- `assets/presentation/card_thumbnails/alchemy_smoke_screen.png`
- `assets/presentation/card_thumbnails/alchemy_spirit_distill.png`
- `assets/presentation/card_thumbnails/alchemy_toxic_pill.png`
- `assets/presentation/card_thumbnails/alchemy_toxin_needle.png`
- `assets/presentation/card_thumbnails/alchemy_white_jade_paste.png`
- `assets/presentation/card_thumbnails/sword_break_stance.png`
- `assets/presentation/card_thumbnails/sword_clear_mind_guard.png`
- `assets/presentation/card_thumbnails/sword_cloud_step.png`
- `assets/presentation/card_thumbnails/sword_echoing_sword_heart.png`
- `assets/presentation/card_thumbnails/sword_flash_cut.png`
- `assets/presentation/card_thumbnails/sword_focused_slash.png`
- `assets/presentation/card_thumbnails/sword_guard.png`
- `assets/presentation/card_thumbnails/sword_guardian_stance.png`
- `assets/presentation/card_thumbnails/sword_heart_piercer.png`
- `assets/presentation/card_thumbnails/sword_heaven_cutting_arc.png`
- `assets/presentation/card_thumbnails/sword_horizon_arc.png`
- `assets/presentation/card_thumbnails/sword_iron_wind_cut.png`
- `assets/presentation/card_thumbnails/sword_meridian_flash.png`
- `assets/presentation/card_thumbnails/sword_qi_surge.png`
- `assets/presentation/card_thumbnails/sword_rising_arc.png`
- `assets/presentation/card_thumbnails/sword_strike.png`
- `assets/presentation/card_thumbnails/sword_sword_resonance.png`
- `assets/presentation/card_thumbnails/sword_thread_the_needle.png`
- `assets/presentation/card_thumbnails/sword_unbroken_focus.png`
- `assets/presentation/card_thumbnails/sword_wind_splitting_step.png`

Modify:

- `resources/visuals/card_visuals/*.tres`: update only `thumbnail_path` and `thumbnail_alt_label`.
- `tests/unit/test_content_catalog.gd`: update representative expectations and add unique polished-path coverage.
- `tests/unit/test_combat_visuals.gd`: update resolver expectations for representative card visual.
- `README.md`: document accepted progress after final review.
- `docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md`: mark steps complete during execution.

Generated by Godot import:

- `assets/presentation/card_thumbnails/<new-card-thumbnail>.png.import` for the 40 new PNGs, if Godot creates them.

Do not modify:

- `scripts/combat/**`
- `scripts/ui/**`
- `scripts/reward/**`
- `scripts/shop/**`
- `scripts/event/**`
- `scripts/run/**`
- `scripts/save/**`
- `scripts/presentation/**`
- `scripts/content/content_catalog.gd`
- `scripts/data/card_visual_def.gd`
- `resources/cards/**`
- `resources/enemies/**`
- `resources/visuals/enemy_visuals/**`
- `resources/visuals/backgrounds/**`
- `localization/zh_CN.po`
- `tools/**`
- `docs/release/**`

## Task 1: Test Guardrails For Polished Card Paths

**Files:**

- Modify: `tests/unit/test_content_catalog.gd`
- Modify: `tests/unit/test_combat_visuals.gd`
- Modify: `docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md`

- [x] **Step 1: Update representative catalog expectations**

In `tests/unit/test_content_catalog.gd`, update `test_default_catalog_loads_visual_theme_resources()` so the `passed` expression expects specific polished card filenames and labels.

Replace:

```gdscript
		and sword_visual.thumbnail_path.ends_with("sword_attack.png") \
		and alchemy_visual != null \
		and alchemy_visual.thumbnail_path.ends_with("alchemy_attack_status.png") \
```

with:

```gdscript
		and sword_visual.thumbnail_path.ends_with("sword_strike.png") \
		and sword_visual.thumbnail_alt_label == "Sword strike thumbnail" \
		and alchemy_visual != null \
		and alchemy_visual.thumbnail_path.ends_with("alchemy_toxic_pill.png") \
		and alchemy_visual.thumbnail_alt_label == "Alchemy toxic pill thumbnail" \
```

- [x] **Step 2: Add unique polished thumbnail path test**

In `tests/unit/test_content_catalog.gd`, add this test after `test_default_catalog_visual_texture_paths_load()`:

```gdscript
func test_default_catalog_card_visuals_use_unique_polished_thumbnail_paths() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	if catalog.cards_by_id.size() != 40:
		push_error("Expected 40 default cards before checking polished thumbnails, got %d" % catalog.cards_by_id.size())
		assert(false)
		return false
	var old_shared_thumbnail_files: Array[String] = [
		"sword_attack.png",
		"sword_skill.png",
		"sword_power.png",
		"alchemy_attack_status.png",
		"alchemy_skill.png",
		"alchemy_power.png",
	]
	var seen_paths := {}
	for card_id_key in catalog.cards_by_id.keys():
		var card_id := String(card_id_key)
		var visual: CardVisualDef = catalog.get_card_visual(card_id)
		if visual == null:
			push_error("Missing card visual for %s" % card_id)
			assert(false)
			return false
		var expected_file := "%s.png" % card_id.replace(".", "_")
		var actual_file := visual.thumbnail_path.get_file()
		if actual_file != expected_file:
			push_error("Card visual %s uses %s instead of %s" % [card_id, actual_file, expected_file])
			assert(false)
			return false
		if seen_paths.has(visual.thumbnail_path):
			push_error("Duplicate card thumbnail path: %s" % visual.thumbnail_path)
			assert(false)
			return false
		if old_shared_thumbnail_files.has(actual_file):
			push_error("Card visual %s still uses shared foundation thumbnail %s" % [card_id, actual_file])
			assert(false)
			return false
		seen_paths[visual.thumbnail_path] = true
	var passed: bool = seen_paths.size() == catalog.cards_by_id.size()
	if not passed:
		push_error("Expected %d unique polished thumbnail paths, got %d" % [catalog.cards_by_id.size(), seen_paths.size()])
	assert(passed)
	return passed
```

- [x] **Step 3: Update representative resolver expectations**

In `tests/unit/test_combat_visuals.gd`, update `test_resolver_resolves_card_visual_with_theme_fallback()`.

Replace:

```gdscript
		and String(visual.get("thumbnail_path", "")).ends_with("sword_attack.png") \
		and visual.get("frame_style") == "sword" \
		and visual.get("element_tag") == "blade" \
		and visual.get("thumbnail_alt_label") == "Sword attack thumbnail" \
```

with:

```gdscript
		and String(visual.get("thumbnail_path", "")).ends_with("sword_strike.png") \
		and visual.get("frame_style") == "sword" \
		and visual.get("element_tag") == "blade" \
		and visual.get("thumbnail_alt_label") == "Sword strike thumbnail" \
```

- [x] **Step 4: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1
```

Expected: non-zero exit or `TESTS FAILED` because current resources still point to shared thumbnail files such as `sword_attack.png` and `alchemy_attack_status.png`.

- [x] **Step 5: Keep failing guardrails uncommitted**

Do not commit the failing guardrails yet. They should remain as local uncommitted test changes until the assets and `CardVisualDef` resources make them pass.

Run:

```powershell
rtk git status --short
```

Expected output includes modified test files and this plan file, but no staged changes.

## Task 2: Generate And Normalize 40 Card Thumbnail PNGs

**Files:**

- Create: 40 `assets/presentation/card_thumbnails/*.png` files listed in File Structure.
- Create temporarily, do not commit: `tmp/card_art_sources/*.png`
- Modify: `docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md`

- [x] **Step 1: Create temporary source directory**

Run:

```powershell
rtk powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path 'tmp\card_art_sources' | Out-Null"
```

- [x] **Step 2: Generate source art with the built-in image generation tool**

Use the built-in image generation path. The execution may either generate one image per card or generate unlabeled 5x4 character atlases and crop the tiles row-major. Save or copy the selected generated output into `tmp/card_art_sources/`:

```text
tmp/card_art_sources/<filename>.png
```

For the implemented pass, the selected generated files were copied as:

```text
tmp/card_art_sources/sword_atlas.png
tmp/card_art_sources/alchemy_atlas.png
```

Use this shared prompt prefix for generated card art or atlas tiles:

```text
Use case: stylized-concept
Asset type: 128x96 Godot card thumbnail source art
Style/medium: hybrid painterly xianxia game thumbnail, painterly backdrop with a bold central emblem or action silhouette, high contrast, readable at small UI size
Composition/framing: landscape 4:3 composition, centered subject, strong silhouette, generous edge padding, no border
Lighting/mood: dramatic magical rim light, polished fantasy game asset, clean focal contrast
Constraints: no text, no letters, no numbers, no logo, no watermark, no card frame, no UI chrome, no border, regular opaque rectangular artwork
Avoid: photorealism, blurry subject, cluttered tiny details, repeated generic symbols
```

Append the card-specific subject line from this table:

```text
alchemy_bitter_extract.png: Subject: dark jade vial pouring bitter green extract, poison vapor curling around a sharp alchemical sigil.
alchemy_calming_powder.png: Subject: pale calming powder scattering from a small ceramic jar, soft jade motes settling over a tranquil circle.
alchemy_cauldron_burst.png: Subject: bronze cauldron erupting with gold and green elixir flame, bold upward burst silhouette.
alchemy_cauldron_overflow.png: Subject: overflowing cauldron spilling luminous poison mist and protective jade foam.
alchemy_cinnabar_seal.png: Subject: red cinnabar talisman seal over a glowing pill furnace, defensive square charm silhouette.
alchemy_coiling_miasma.png: Subject: coiling violet-green miasma serpent around a small alchemy crucible.
alchemy_golden_core_detox.png: Subject: golden core pearl cleansing black poison wisps, radiant circular detox motif.
alchemy_healing_draught.png: Subject: glowing healing draught bottle with warm gold liquid and white jade sparkles.
alchemy_inner_fire_pill.png: Subject: blazing red-gold pill igniting inner fire inside a small refining circle.
alchemy_mercury_bloom.png: Subject: silver mercury flower blooming from toxic liquid, reflective petals with green aura.
alchemy_needle_rain.png: Subject: fan of fine acupuncture needles raining diagonally through jade mist.
alchemy_ninefold_refine.png: Subject: nine nested refining rings around a luminous elixir pill, precise alchemical geometry.
alchemy_poison_mist.png: Subject: dense poison mist cloud rolling from a cracked green flask, bold vapor silhouette.
alchemy_purifying_brew.png: Subject: clear purifying brew swirling in a porcelain cup, white-gold cleansing spiral.
alchemy_quick_simmer.png: Subject: small fast-simmering cauldron with quick rising bubbles and lively jade sparks.
alchemy_smoke_screen.png: Subject: thick smoke screen blooming from an alchemy pellet, obscuring silhouettes in violet haze.
alchemy_spirit_distill.png: Subject: translucent spirit essence distilling drop by drop into a glass vial, blue-green glow.
alchemy_toxic_pill.png: Subject: black-green toxic pill cracked with neon poison veins, ominous circular silhouette.
alchemy_toxin_needle.png: Subject: single poison-coated needle gleaming with green droplet, sharp diagonal composition.
alchemy_white_jade_paste.png: Subject: white jade medicinal paste in an open lacquer box, soft healing glow and jade dust.
sword_break_stance.png: Subject: fractured sword stance silhouette, broken stone floor and sharp red-cyan crack lines.
sword_clear_mind_guard.png: Subject: calm defensive sword guard with clear blue mind halo and quiet shield-like arc.
sword_cloud_step.png: Subject: swift cloud-step footprint and trailing sword cloak through white-blue mist.
sword_echoing_sword_heart.png: Subject: luminous sword-heart core echoing concentric blade waves in the chest of a spirit silhouette.
sword_flash_cut.png: Subject: instant flash cut slash, bright white-cyan blade streak across dark air.
sword_focused_slash.png: Subject: concentrated narrow sword slash with gold focus point and clean blade trail.
sword_guard.png: Subject: crossed sword guard stance forming a protective cyan-gold barrier.
sword_guardian_stance.png: Subject: immovable guardian stance with vertical sword planted before a glowing shield aura.
sword_heart_piercer.png: Subject: piercing sword thrust aimed at a red heart-shaped weak point, precise dramatic silhouette.
sword_heaven_cutting_arc.png: Subject: enormous heaven-cutting crescent sword arc slicing through clouds, gold-cyan radiance.
sword_horizon_arc.png: Subject: wide horizontal sword arc sweeping across a distant misty horizon.
sword_iron_wind_cut.png: Subject: iron-gray wind blade cutting through swirling air, sturdy metallic energy.
sword_meridian_flash.png: Subject: bright meridian channels flashing along a sword blade, fast golden energy lines.
sword_qi_surge.png: Subject: upward surge of qi around a sheathed sword, blue-white energy plume.
sword_rising_arc.png: Subject: rising sword arc lifting from low stance to sky, clean upward crescent.
sword_strike.png: Subject: direct sword strike with simple bold blade impact spark, iconic starter attack.
sword_sword_resonance.png: Subject: two resonating swords vibrating with matching cyan-gold soundwave arcs.
sword_thread_the_needle.png: Subject: needle-thin sword thrust threading through a narrow golden ring target.
sword_unbroken_focus.png: Subject: unbroken focus meditation with sword hovering before a steady blue-gold halo.
sword_wind_splitting_step.png: Subject: fast stepping swordsman silhouette splitting wind into sharp cyan ribbons.
```

- [x] **Step 3: Normalize generated sources to 128x96 project thumbnails**

After all generated source images exist in `tmp/card_art_sources/`, normalize the final project assets to `128x96`.

For one-image-per-card sources, use this crop-and-resize command:

```powershell
rtk powershell -NoProfile -Command @'
Add-Type -AssemblyName System.Drawing
$srcDir = "tmp\card_art_sources"
$outDir = "assets\presentation\card_thumbnails"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Get-ChildItem $srcDir -Filter *.png | ForEach-Object {
	$img = [System.Drawing.Image]::FromFile($_.FullName)
	try {
		$targetRatio = 4.0 / 3.0
		$cropW = $img.Width
		$cropH = [int]($img.Width / $targetRatio)
		if ($cropH -gt $img.Height) {
			$cropH = $img.Height
			$cropW = [int]($img.Height * $targetRatio)
		}
		$cropX = [int](($img.Width - $cropW) / 2)
		$cropY = [int](($img.Height - $cropH) / 2)
		$bmp = New-Object System.Drawing.Bitmap 128, 96
		$graphics = [System.Drawing.Graphics]::FromImage($bmp)
		try {
			$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
			$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
			$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
			$destRect = New-Object System.Drawing.Rectangle 0, 0, 128, 96
			$graphics.DrawImage($img, $destRect, $cropX, $cropY, $cropW, $cropH, [System.Drawing.GraphicsUnit]::Pixel)
			$outPath = Join-Path $outDir $_.Name
			$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
		}
		finally {
			$graphics.Dispose()
			$bmp.Dispose()
		}
	}
	finally {
		$img.Dispose()
	}
}
'@
```

For the implemented atlas pass, `tmp/export_card_thumbnails.ps1` cropped `tmp/card_art_sources/sword_atlas.png` and `tmp/card_art_sources/alchemy_atlas.png` into the same 40 output filenames under `assets/presentation/card_thumbnails/`.

- [x] **Step 4: Verify all expected PNGs exist and have 128x96 dimensions**

Run:

```powershell
rtk powershell -NoProfile -Command @'
Add-Type -AssemblyName System.Drawing
$expected = @(
	"alchemy_bitter_extract.png","alchemy_calming_powder.png","alchemy_cauldron_burst.png","alchemy_cauldron_overflow.png","alchemy_cinnabar_seal.png",
	"alchemy_coiling_miasma.png","alchemy_golden_core_detox.png","alchemy_healing_draught.png","alchemy_inner_fire_pill.png","alchemy_mercury_bloom.png",
	"alchemy_needle_rain.png","alchemy_ninefold_refine.png","alchemy_poison_mist.png","alchemy_purifying_brew.png","alchemy_quick_simmer.png",
	"alchemy_smoke_screen.png","alchemy_spirit_distill.png","alchemy_toxic_pill.png","alchemy_toxin_needle.png","alchemy_white_jade_paste.png",
	"sword_break_stance.png","sword_clear_mind_guard.png","sword_cloud_step.png","sword_echoing_sword_heart.png","sword_flash_cut.png",
	"sword_focused_slash.png","sword_guard.png","sword_guardian_stance.png","sword_heart_piercer.png","sword_heaven_cutting_arc.png",
	"sword_horizon_arc.png","sword_iron_wind_cut.png","sword_meridian_flash.png","sword_qi_surge.png","sword_rising_arc.png",
	"sword_strike.png","sword_sword_resonance.png","sword_thread_the_needle.png","sword_unbroken_focus.png","sword_wind_splitting_step.png"
)
foreach ($name in $expected) {
	$path = Join-Path "assets\presentation\card_thumbnails" $name
	if (-not (Test-Path $path)) {
		throw "Missing thumbnail $path"
	}
	$img = [System.Drawing.Image]::FromFile((Resolve-Path $path))
	try {
		if ($img.Width -ne 128 -or $img.Height -ne 96) {
			throw "$name has $($img.Width)x$($img.Height), expected 128x96"
		}
	}
	finally {
		$img.Dispose()
	}
}
"Verified 40 polished card thumbnails at 128x96."
'@
```

Expected output includes:

```text
Verified 40 polished card thumbnails at 128x96.
```

- [x] **Step 5: Commit generated normalized PNGs**

Run:

```powershell
rtk git add assets/presentation/card_thumbnails/*.png docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md
rtk git commit -m "art: add polished card thumbnails"
```

Do not add or commit `tmp/card_art_sources/`.

## Task 3: Repoint Card Visual Resources

**Files:**

- Modify: `resources/visuals/card_visuals/*.tres`
- Modify: `docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md`

- [x] **Step 1: Mechanically update visual resource thumbnail paths and labels**

Run this bulk mechanical rewrite:

```powershell
rtk powershell -NoProfile -Command @'
Get-ChildItem "resources\visuals\card_visuals" -Filter *.tres | ForEach-Object {
	$stem = $_.BaseName
	$path = "res://assets/presentation/card_thumbnails/$stem.png"
	$words = $stem -replace "_", " "
	$label = $words.Substring(0, 1).ToUpperInvariant() + $words.Substring(1) + " thumbnail"
	$text = Get-Content -Raw -Path $_.FullName
	$text = [regex]::Replace($text, 'thumbnail_path = "res://assets/presentation/card_thumbnails/[^"]+"', "thumbnail_path = `"$path`"")
	$text = [regex]::Replace($text, 'thumbnail_alt_label = "[^"]+"', "thumbnail_alt_label = `"$label`"")
	Set-Content -Path $_.FullName -Value $text -NoNewline
}
'@
```

- [x] **Step 2: Inspect representative resource diff**

Run:

```powershell
rtk git diff -- resources/visuals/card_visuals/sword_strike.tres resources/visuals/card_visuals/alchemy_toxic_pill.tres
```

Expected representative changes:

```diff
-thumbnail_path = "res://assets/presentation/card_thumbnails/sword_attack.png"
+thumbnail_path = "res://assets/presentation/card_thumbnails/sword_strike.png"
-thumbnail_alt_label = "Sword attack thumbnail"
+thumbnail_alt_label = "Sword strike thumbnail"
```

and:

```diff
-thumbnail_path = "res://assets/presentation/card_thumbnails/alchemy_attack_status.png"
+thumbnail_path = "res://assets/presentation/card_thumbnails/alchemy_toxic_pill.png"
-thumbnail_alt_label = "Alchemy attack thumbnail"
+thumbnail_alt_label = "Alchemy toxic pill thumbnail"
```

- [x] **Step 3: Run tests to verify GREEN for catalog/resource changes**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1
```

Expected:

```text
Godot checks passed.
TESTS PASSED
```

This run should also create `.import` files for new PNGs if they were missing.

- [x] **Step 4: Verify boundary before committing resources**

Run:

```powershell
rtk git diff --name-only -- scripts resources/cards resources/enemies resources/events resources/relics resources/visuals/enemy_visuals resources/visuals/backgrounds localization tools docs/release
```

Expected: no output. If output includes files from these disallowed areas, stop and inspect before continuing.

Run:

```powershell
rtk git diff -- resources/visuals/card_visuals
```

Expected: diffs only change `thumbnail_path` and `thumbnail_alt_label`.

- [x] **Step 5: Commit tests, repointed resources, and generated import files**

Run:

```powershell
rtk git add tests/unit/test_content_catalog.gd tests/unit/test_combat_visuals.gd resources/visuals/card_visuals/*.tres docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md
rtk git add assets/presentation/card_thumbnails/alchemy_bitter_extract.png.import assets/presentation/card_thumbnails/alchemy_calming_powder.png.import assets/presentation/card_thumbnails/alchemy_cauldron_burst.png.import assets/presentation/card_thumbnails/alchemy_cauldron_overflow.png.import assets/presentation/card_thumbnails/alchemy_cinnabar_seal.png.import
rtk git add assets/presentation/card_thumbnails/alchemy_coiling_miasma.png.import assets/presentation/card_thumbnails/alchemy_golden_core_detox.png.import assets/presentation/card_thumbnails/alchemy_healing_draught.png.import assets/presentation/card_thumbnails/alchemy_inner_fire_pill.png.import assets/presentation/card_thumbnails/alchemy_mercury_bloom.png.import
rtk git add assets/presentation/card_thumbnails/alchemy_needle_rain.png.import assets/presentation/card_thumbnails/alchemy_ninefold_refine.png.import assets/presentation/card_thumbnails/alchemy_poison_mist.png.import assets/presentation/card_thumbnails/alchemy_purifying_brew.png.import assets/presentation/card_thumbnails/alchemy_quick_simmer.png.import
rtk git add assets/presentation/card_thumbnails/alchemy_smoke_screen.png.import assets/presentation/card_thumbnails/alchemy_spirit_distill.png.import assets/presentation/card_thumbnails/alchemy_toxic_pill.png.import assets/presentation/card_thumbnails/alchemy_toxin_needle.png.import assets/presentation/card_thumbnails/alchemy_white_jade_paste.png.import
rtk git add assets/presentation/card_thumbnails/sword_break_stance.png.import assets/presentation/card_thumbnails/sword_clear_mind_guard.png.import assets/presentation/card_thumbnails/sword_cloud_step.png.import assets/presentation/card_thumbnails/sword_echoing_sword_heart.png.import assets/presentation/card_thumbnails/sword_flash_cut.png.import
rtk git add assets/presentation/card_thumbnails/sword_focused_slash.png.import assets/presentation/card_thumbnails/sword_guard.png.import assets/presentation/card_thumbnails/sword_guardian_stance.png.import assets/presentation/card_thumbnails/sword_heart_piercer.png.import assets/presentation/card_thumbnails/sword_heaven_cutting_arc.png.import
rtk git add assets/presentation/card_thumbnails/sword_horizon_arc.png.import assets/presentation/card_thumbnails/sword_iron_wind_cut.png.import assets/presentation/card_thumbnails/sword_meridian_flash.png.import assets/presentation/card_thumbnails/sword_qi_surge.png.import assets/presentation/card_thumbnails/sword_rising_arc.png.import
rtk git add assets/presentation/card_thumbnails/sword_strike.png.import assets/presentation/card_thumbnails/sword_sword_resonance.png.import assets/presentation/card_thumbnails/sword_thread_the_needle.png.import assets/presentation/card_thumbnails/sword_unbroken_focus.png.import assets/presentation/card_thumbnails/sword_wind_splitting_step.png.import
rtk git commit -m "feat: point card visuals to polished thumbnails"
```

If no `.png.import` files were generated for the new assets, omit those `git add` lines. Do not add existing shared thumbnail `.import` files unless their content changed for a feature reason.

## Task 4: Boundary Verification And README Acceptance

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md`

- [x] **Step 1: Verify no disallowed gameplay or UI code changed across the feature commits**

Run:

```powershell
rtk git diff --name-only HEAD~2..HEAD -- scripts resources/cards resources/enemies resources/events resources/relics resources/visuals/enemy_visuals resources/visuals/backgrounds localization tools docs/release
```

Expected: no output. If output includes files from the disallowed areas, stop and inspect before continuing.

- [x] **Step 2: Verify card visual resource changes are limited to thumbnail fields across the feature commits**

Run:

```powershell
rtk git diff HEAD~2..HEAD -- resources/visuals/card_visuals
```

Expected: diffs only change `thumbnail_path` and `thumbnail_alt_label`.

- [x] **Step 3: Verify old shared thumbnails remain available but unused by default card visuals**

Run:

```powershell
rtk rg -n "sword_attack.png|sword_skill.png|sword_power.png|alchemy_attack_status.png|alchemy_skill.png|alchemy_power.png" resources/visuals/card_visuals tests/unit
```

Expected: no matches in `resources/visuals/card_visuals`. Test files may mention these filenames only in the guardrail list.

- [x] **Step 4: Run direct import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [x] **Step 5: Update README progress**

In `README.md`, add this bullet under `## Phase 2 Progress` after the audio mixing foundation bullet:

```markdown
- Polished per-card art replacement: complete; all 40 default cards now point to unique project-owned thumbnail art while combat, reward, shop, and event previews continue using the existing visual pipeline.
```

Update `## Next Plans` to:

```markdown
## Next Plans

1. Presentation expansion: full-size card artwork, card detail panels, relic visuals, and other optional polish.
2. Release expansion: artifact packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
```

- [x] **Step 6: Run shared Godot checks**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1
```

Expected:

```text
Godot checks passed.
TESTS PASSED
```

- [x] **Step 7: Commit README acceptance**

Run:

```powershell
rtk git add README.md docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md
rtk git commit -m "docs: record polished card art acceptance"
```

## Task 5: Required Two-Stage Review

**Files:**

- Modify: `docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md`

- [ ] **Step 1: Run Stage 1 Spec Compliance Review**

Review against `docs/superpowers/specs/2026-05-10-polished-per-card-art-replacement-design.md`.

Required findings:

- All 40 default cards have unique project-owned PNG thumbnails.
- Each `CardVisualDef` points to its matching card-specific thumbnail.
- Every thumbnail path loads through Godot.
- No default card visual still points to the old shared foundation thumbnails.
- Missing-card fallback still points to `fallback_card.png`.
- Combat, reward, shop, shop removal, and event preview surfaces still render through existing paths.
- No gameplay, save schema, card effect, reward, event, shop, map, release, Steam, audio, enemy art, background, or localization changes were added.
- README progress and Next Plans match shipped scope.

If any item fails, fix it before Stage 2.

- [ ] **Step 2: Run Stage 2 Code Quality Review**

Review the implementation for:

- Changes are asset/data focused and do not add unnecessary abstractions.
- Tests are focused on catalog coverage, path uniqueness, texture loading, and fallback behavior.
- Resource updates are surgical and avoid unrelated formatting churn.
- Generated import files are included only for the new PNG assets.
- Old shared foundation thumbnails were not removed.
- Temporary generated source files under `tmp/card_art_sources/` were not committed.

Classify found issues as Critical, Important, or Minor. Fix Critical and Important issues before final acceptance. Minor issues can remain only if they do not violate the spec or project protocol.

- [ ] **Step 3: Run final shared Godot checks**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1
```

Expected:

```text
Godot checks passed.
TESTS PASSED
```

- [ ] **Step 4: Run final direct import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 5: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after each step has been completed and verified.

- [ ] **Step 6: Commit final review bookkeeping if needed**

If Task 5 only changes this plan file, run:

```powershell
rtk git add docs/superpowers/plans/2026-05-10-polished-per-card-art-replacement.md
rtk git commit -m "docs: complete polished card art review"
```

If all checkboxes were already committed in prior task commits, skip this commit.

## Final Acceptance Criteria

- 40 unique card-specific PNG thumbnails exist under `assets/presentation/card_thumbnails/`.
- All 40 default `CardVisualDef` resources point to card-specific thumbnail paths.
- Each default card visual has a specific thumbnail alt label.
- All default card thumbnail paths load as `Texture2D`.
- No default card visual uses the old shared foundation thumbnail paths.
- Missing-card fallback still resolves to `fallback_card.png`.
- Combat hand cards, reward choices, shop card offers, shop remove choices, and direct-card event previews continue rendering through existing UI paths.
- No gameplay, save, card effect, reward, shop, event, map, release, Steam, audio, enemy art, background, or localization behavior changes are added.
- Shared Godot checks pass.
- Direct Godot import check exits 0.
