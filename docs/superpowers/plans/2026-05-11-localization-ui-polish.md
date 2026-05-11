# Localization And UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Chinese-default, Chinese/English switchable localization and near-demo ink-and-jade UI polish across the main flow and debug screens.

**Architecture:** Add a small locale service and shared text/style helpers first, then migrate screens one by one in the approved order. Keep gameplay systems unchanged; UI scripts consume translated text, shared formatting, and focused style helpers.

**Tech Stack:** Godot 4.6.2, GDScript, `.po` translations, programmatic Control scenes, existing Godot test runner, PowerShell CI wrapper.

---

## Scope Check

The approved spec is broad, but it is one coherent UI/i18n subsystem. Keep it as one plan because every screen depends on the same locale service, translation files, text helper, and style helper. Execute screen tasks in order and commit after each task.

## File Structure

Create:

- `scripts/app/localization_service.gd`: current locale, persistence under `user://`, locale switching, and `locale_changed`.
- `scripts/ui/ui_text.gd`: localized formatting helpers for screen labels, content names, statuses, intents, rewards, shop offers, and debug summaries.
- `scripts/ui/ui_style.gd`: small ink-and-jade style helper for panels, labels, buttons, badges, and list rows.
- `tests/unit/test_localization_service.gd`: locale default, persistence, fallback, and signal behavior.
- `tests/unit/test_ui_text.gd`: text helper behavior in Chinese and English.
- `tests/unit/test_ui_style.gd`: theme/style application smoke checks.
- `assets/ui/fonts/NotoSansSC-Regular.ttf`: Chinese-capable font asset with license-safe provenance.
- `localization/en.po`: English translation file.

Modify:

- `project.godot`: register both locale files.
- `scripts/app/game.gd`: instantiate `LocalizationService`.
- `scripts/app/app.gd`: initialize locale service before routing to Main Menu.
- `scripts/content/content_catalog.gd`: validate both locale files and intent label keys.
- `scripts/data/enemy_intent_display_def.gd`: replace `label` with `label_key`.
- `resources/intents/*.tres`: replace raw labels with `label_key`.
- `scripts/presentation/enemy_intent_display_resolver.gd`: translate intent labels.
- `scripts/combat/combat_status_runtime.gd`: use `UiText` or translation-aware status names.
- `scripts/ui/main_menu.gd`: language toggle, localized refresh, styling.
- `scripts/ui/map_screen.gd`: localized route presentation and styling.
- `scripts/ui/combat_screen.gd`: localized summaries, phases, buttons, target labels, and polish.
- `scripts/ui/reward_screen.gd`: localized reward flow and polish.
- `scripts/ui/event_screen.gd`: localized fallback, option composition, unavailable reasons, and polish.
- `scripts/ui/shop_screen.gd`: localized shop offers, actions, removal flow, and polish.
- `scripts/ui/run_summary_screen.gd`: localized win/loss summary and stats.
- `scripts/ui/debug_overlay.gd`: localized debug labels and compact styling.
- `scripts/ui/dev_tools_screen.gd`: localized tool labels, summaries, actions, and grouped panels.
- `scripts/ui/item_visual_presenter.gd`: translated card/relic preview labels.
- `scripts/ui/item_detail_panel.gd`: translated detail title/body labels.
- `scripts/testing/test_runner.gd`: include new test files.
- `tests/unit/test_content_catalog.gd`: validate both locales and intent `label_key`.
- `tests/unit/test_enemy_intent_display.gd`: update expected localized labels.
- `tests/unit/test_combat_status_runtime.gd`: update status name expectations.
- `tests/unit/test_dev_tools_screen.gd`: update debug text expectations.
- `tests/smoke/test_scene_flow.gd`: add bilingual smoke coverage for every screen.
- `README.md`: document completed localization/UI polish phase after implementation.

## Commands

Run full verification with:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1 -ProjectRoot .
```

Expected success output includes:

```text
Godot checks passed.
```

---

### Task 1: Locale Service Foundation

**Files:**
- Create: `scripts/app/localization_service.gd`
- Create: `tests/unit/test_localization_service.gd`
- Modify: `scripts/app/game.gd`
- Modify: `scripts/app/app.gd`
- Modify: `scripts/testing/test_runner.gd`

- [ ] **Step 1: Write failing locale service tests**

Add `res://tests/unit/test_localization_service.gd` to `TEST_FILES` in `scripts/testing/test_runner.gd`, immediately before `test_resource_schemas.gd`.

Create `tests/unit/test_localization_service.gd`:

```gdscript
extends RefCounted

const LocalizationService := preload("res://scripts/app/localization_service.gd")

func test_default_locale_is_chinese() -> bool:
	var service := LocalizationService.new("user://test_locale_default.cfg")
	service.clear_saved_locale()
	service.load_or_default()
	var passed := service.current_locale == "zh_CN" and TranslationServer.get_locale() == "zh_CN"
	service.clear_saved_locale()
	assert(passed)
	return passed

func test_switch_locale_emits_signal_and_persists() -> bool:
	var service := LocalizationService.new("user://test_locale_switch.cfg")
	service.clear_saved_locale()
	var emitted: Array[String] = []
	service.locale_changed.connect(func(locale: String): emitted.append(locale))
	service.load_or_default()
	service.set_locale("en")
	var reloaded := LocalizationService.new("user://test_locale_switch.cfg")
	reloaded.load_or_default()
	var passed := service.current_locale == "en" \
		and reloaded.current_locale == "en" \
		and emitted == ["zh_CN", "en"]
	service.clear_saved_locale()
	assert(passed)
	return passed

func test_unsupported_locale_falls_back_to_chinese() -> bool:
	var service := LocalizationService.new("user://test_locale_fallback.cfg")
	service.clear_saved_locale()
	service.set_locale("ja")
	var passed := service.current_locale == "zh_CN"
	service.clear_saved_locale()
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify the new test fails**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1 -ProjectRoot .
```

Expected: failure mentioning `res://scripts/app/localization_service.gd` cannot load or `LocalizationService` is missing.

- [ ] **Step 3: Implement the locale service**

Create `scripts/app/localization_service.gd`:

```gdscript
class_name LocalizationService
extends RefCounted

signal locale_changed(locale: String)

const LOCALE_ZH_CN := "zh_CN"
const LOCALE_EN := "en"
const SUPPORTED_LOCALES: Array[String] = [LOCALE_ZH_CN, LOCALE_EN]
const DEFAULT_SETTINGS_PATH := "user://locale_settings.cfg"
const SECTION := "locale"
const KEY_CURRENT := "current"

var current_locale := LOCALE_ZH_CN
var settings_path := DEFAULT_SETTINGS_PATH

func _init(path: String = DEFAULT_SETTINGS_PATH) -> void:
	settings_path = path

func load_or_default() -> void:
	var config := ConfigFile.new()
	var loaded_locale := LOCALE_ZH_CN
	if config.load(settings_path) == OK:
		loaded_locale = String(config.get_value(SECTION, KEY_CURRENT, LOCALE_ZH_CN))
	set_locale(loaded_locale)

func set_locale(locale: String) -> void:
	var normalized := _normalized_locale(locale)
	current_locale = normalized
	TranslationServer.set_locale(normalized)
	_save_locale(normalized)
	locale_changed.emit(normalized)

func is_chinese() -> bool:
	return current_locale == LOCALE_ZH_CN

func toggle_locale() -> void:
	set_locale(LOCALE_EN if current_locale == LOCALE_ZH_CN else LOCALE_ZH_CN)

func clear_saved_locale() -> void:
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))

func _normalized_locale(locale: String) -> String:
	return locale if SUPPORTED_LOCALES.has(locale) else LOCALE_ZH_CN

func _save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY_CURRENT, locale)
	config.save(settings_path)
```

- [ ] **Step 4: Wire it into `Game` and `App`**

Modify `scripts/app/game.gd`:

```gdscript
const LocalizationService := preload("res://scripts/app/localization_service.gd")

var localization_service := LocalizationService.new()
```

Modify `scripts/app/app.gd` before `game.router.setup(self)`:

```gdscript
	game.localization_service.load_or_default()
```

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1 -ProjectRoot .
```

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/app/localization_service.gd scripts/app/game.gd scripts/app/app.gd scripts/testing/test_runner.gd tests/unit/test_localization_service.gd
rtk proxy git commit -m "feat: add locale service"
```

---

### Task 2: Locale Files, Project Registration, And Catalog Validation

**Files:**
- Create: `localization/en.po`
- Modify: `project.godot`
- Modify: `scripts/content/content_catalog.gd`
- Modify: `tests/unit/test_content_catalog.gd`

- [ ] **Step 1: Write failing catalog tests for dual locales**

Add tests to `tests/unit/test_content_catalog.gd` near the current locale validation tests:

```gdscript
func test_validation_reports_unreadable_locale_file_once() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	catalog.locale_paths = ["res://localization/missing_zh_CN.po"]
	var errors: Array[String] = catalog.validate()
	var passed: bool = errors.size() == 1 \
		and errors[0].contains("could not open localization file") \
		and errors[0].contains("missing_zh_CN.po")
	assert(passed)
	return passed

func test_default_catalog_validates_chinese_and_english_locale_files() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var errors: Array[String] = catalog.validate()
	var joined := "\n".join(errors)
	var passed := errors.is_empty() and catalog.locale_paths == [
		"res://localization/zh_CN.po",
		"res://localization/en.po",
	]
	if not passed:
		push_error(joined)
	assert(passed)
	return passed

func test_validation_reports_missing_key_per_locale() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	catalog.locale_paths = ["res://localization/zh_CN.po", "res://localization/missing_en.po"]
	var errors: Array[String] = catalog.validate()
	var passed := errors.size() == 1 \
		and errors[0].contains("could not open localization file") \
		and errors[0].contains("missing_en.po")
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify failure**

Run full checks.

Expected: failure because `ContentCatalog.locale_paths` and `localization/en.po` do not exist.

- [ ] **Step 3: Update project translation registration**

Modify `project.godot`:

```ini
[internationalization]
locale/translations=PackedStringArray("res://localization/zh_CN.po", "res://localization/en.po")
```

- [ ] **Step 4: Add English translation file**

Create `localization/en.po` with the same `msgid` set as `localization/zh_CN.po`.

Rules for `msgstr`:

- UI labels use natural English.
- Existing content keys use readable English names/descriptions, not ids.
- If a content key is missing an obvious English description, derive it from the resource effects in `resources/cards/`, `resources/relics/`, and `resources/events/`.
- Keep the file UTF-8.

Required header:

```po
msgid ""
msgstr ""
"Project-Id-Version: MySlaytheSpire\n"
"Language: en\n"
"Content-Type: text/plain; charset=UTF-8\n"
```

- [ ] **Step 5: Teach catalog validation to load multiple locales**

Modify `scripts/content/content_catalog.gd`:

```gdscript
var locale_paths: Array[String] = [
	"res://localization/zh_CN.po",
	"res://localization/en.po",
]
var locale_path := "res://localization/zh_CN.po"
```

Replace the locale part of `validate()`:

```gdscript
	var locale_error_count := errors.size()
	var locale_keys_by_path := _load_all_locale_keys(errors)
	var locales_loaded := errors.size() == locale_error_count
```

Replace the final locale validation call:

```gdscript
	if locales_loaded:
		for path in locale_keys_by_path.keys():
			_validate_locale_keys(locale_keys_by_path[path], path, errors)
```

Change `_validate_locale_keys` signature:

```gdscript
func _validate_locale_keys(locale_keys: Dictionary, locale_label: String, errors: Array[String]) -> void:
```

Change every `_require_locale_key(...)` call in that method to pass `locale_label`.

Replace `_require_locale_key`:

```gdscript
func _require_locale_key(key: String, label: String, locale_keys: Dictionary, locale_label: String, errors: Array[String]) -> void:
	if key.is_empty():
		errors.append("%s is empty for %s" % [label, locale_label])
	elif not locale_keys.has(key):
		errors.append("%s missing localization key %s in %s" % [label, key, locale_label])
```

Add:

```gdscript
func _load_all_locale_keys(errors: Array[String]) -> Dictionary:
	var paths := locale_paths.duplicate()
	if paths.is_empty() and not locale_path.is_empty():
		paths.append(locale_path)
	var result := {}
	for path in paths:
		result[path] = _load_locale_keys(path, errors)
	return result

func _load_locale_keys(path: String, errors: Array[String]) -> Dictionary:
	var keys := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("ContentCatalog could not open localization file: %s" % path)
		return keys
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("msgid \"") and line != "msgid \"\"":
			var key := line.trim_prefix("msgid \"").trim_suffix("\"")
			keys[key] = true
	return keys
```

Remove the old no-argument `_load_locale_keys`.

- [ ] **Step 6: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add project.godot localization/en.po scripts/content/content_catalog.gd tests/unit/test_content_catalog.gd
rtk proxy git commit -m "feat: validate dual locale files"
```

---

### Task 3: Intent And Status Localization

**Files:**
- Modify: `scripts/data/enemy_intent_display_def.gd`
- Modify: `resources/intents/*.tres`
- Modify: `scripts/presentation/enemy_intent_display_resolver.gd`
- Modify: `scripts/combat/combat_status_runtime.gd`
- Modify: `scripts/content/content_catalog.gd`
- Modify: `tests/unit/test_enemy_intent_display.gd`
- Modify: `tests/unit/test_combat_status_runtime.gd`

- [ ] **Step 1: Write failing intent localization tests**

Update `tests/unit/test_enemy_intent_display.gd` expected labels:

```gdscript
TranslationServer.set_locale("zh_CN")
var attack_zh := resolver.resolve("attack_5", catalog)
TranslationServer.set_locale("en")
var attack_en := resolver.resolve("attack_5", catalog)
var passed := attack_zh.get("label") == tr("intent.attack.label") \
	and attack_en.get("label") == "Attack"
```

Add a malformed fallback assertion:

```gdscript
TranslationServer.set_locale("zh_CN")
var unknown := resolver.resolve("wait", catalog)
var passed := unknown.get("label") == tr("intent.unknown.label")
```

- [ ] **Step 2: Run tests and verify failure**

Run full checks.

Expected: failure because intent resources still expose raw `label`.

- [ ] **Step 3: Replace intent display label field**

Modify `scripts/data/enemy_intent_display_def.gd`:

```gdscript
class_name EnemyIntentDisplayDef
extends Resource

@export var id: String = ""
@export_enum("attack", "block", "apply_status", "self_status", "unknown") var intent_kind: String = "unknown"
@export var icon_key: String = ""
@export var label_key: String = ""
@export var color: Color = Color.WHITE
@export var show_amount: bool = true
@export var show_target: bool = true
```

Modify every `resources/intents/*.tres`:

```text
label_key = "intent.attack.label"
```

Use these mappings:

- `attack.tres`: `intent.attack.label`
- `block.tres`: `intent.block.label`
- `status_poison.tres`: `intent.poison.label`
- `status_broken_stance.tres`: `intent.broken_stance.label`
- `status_sword_focus.tres`: `intent.sword_focus.label`
- `unknown.tres`: `intent.unknown.label`

- [ ] **Step 4: Translate resolver output**

Modify `scripts/presentation/enemy_intent_display_resolver.gd` returned dictionary:

```gdscript
		"label": tr(display.label_key),
```

Modify fallback:

```gdscript
		"label": tr("intent.unknown.label"),
```

- [ ] **Step 5: Update catalog validation**

Modify `_validate_enemy_intent_displays` in `scripts/content/content_catalog.gd`:

```gdscript
		if display.label_key.is_empty():
			errors.append("Enemy intent display %s has empty label_key" % display.id)
```

Add locale validation inside `_validate_locale_keys`:

```gdscript
	for display: EnemyIntentDisplayDef in enemy_intent_displays_by_id.values():
		_require_locale_key(display.label_key, "enemy intent display %s label_key" % display.id, locale_keys, locale_label, errors)
```

- [ ] **Step 6: Add status and intent keys to both locales**

Add these keys to `zh_CN.po` and `en.po`:

```po
msgid "intent.attack.label"
msgstr "Attack"

msgid "intent.block.label"
msgstr "Block"

msgid "intent.poison.label"
msgstr "Poison"

msgid "intent.broken_stance.label"
msgstr "Broken Stance"

msgid "intent.sword_focus.label"
msgstr "Sword Focus"

msgid "intent.unknown.label"
msgstr "Unknown"
```

Use Chinese translations in `zh_CN.po`. Add or verify:

```po
msgid "status.poison.name"
msgstr "Poison"

msgid "status.sword_focus.name"
msgstr "Sword Focus"

msgid "status.broken_stance.name"
msgstr "Broken Stance"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 7: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/data/enemy_intent_display_def.gd resources/intents scripts/presentation/enemy_intent_display_resolver.gd scripts/combat/combat_status_runtime.gd scripts/content/content_catalog.gd tests/unit/test_enemy_intent_display.gd tests/unit/test_combat_status_runtime.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize intent and status labels"
```

---

### Task 4: Shared Text Formatting Helper

**Files:**
- Create: `scripts/ui/ui_text.gd`
- Create: `tests/unit/test_ui_text.gd`
- Modify: `scripts/testing/test_runner.gd`

- [ ] **Step 1: Write failing text helper tests**

Add `res://tests/unit/test_ui_text.gd` to `scripts/testing/test_runner.gd` after `test_localization_service.gd`.

Create `tests/unit/test_ui_text.gd`:

```gdscript
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")

func test_formats_card_and_relic_names_in_english() -> bool:
	TranslationServer.set_locale("en")
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var passed := UiText.card_name(catalog, "sword.strike") == tr("card.sword.strike.name") \
		and UiText.relic_name(catalog, "jade_talisman") == tr("relic.jade_talisman.name")
	assert(passed)
	return passed

func test_formats_combat_summary_labels() -> bool:
	TranslationServer.set_locale("en")
	var player := {"id": "sword", "hp": 60, "max_hp": 72, "block": 5, "energy": 2, "turn": 3}
	var text := UiText.player_summary(player)
	var passed := text.contains("HP 60/72") \
		and text.contains("Block 5") \
		and text.contains("Energy 2") \
		and text.contains("Turn 3")
	assert(passed)
	return passed

func test_debug_labels_preserve_ids_as_values() -> bool:
	TranslationServer.set_locale("en")
	var text := UiText.key_value("character", "sword")
	var passed := text == "Character: sword"
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify failure**

Run full checks.

Expected: failure because `scripts/ui/ui_text.gd` is missing.

- [ ] **Step 3: Implement the helper**

Create `scripts/ui/ui_text.gd`:

```gdscript
class_name UiText
extends RefCounted

static func label(key: String) -> String:
	return tr(key)

static func key_value(label_key: String, value: Variant) -> String:
	return "%s: %s" % [tr("ui.label.%s" % label_key), str(value)]

static func card_name(catalog: Object, card_id: String) -> String:
	var card = catalog.get_card(card_id) if catalog != null and catalog.has_method("get_card") else null
	if card == null:
		return tr("ui.common.unknown_card")
	return tr(card.name_key)

static func card_detail(catalog: Object, card_id: String) -> String:
	var card = catalog.get_card(card_id) if catalog != null and catalog.has_method("get_card") else null
	if card == null:
		return "%s\n%s" % [tr("ui.common.unknown_card"), key_value("id", card_id)]
	return "%s\n%s\n%s\n%s" % [
		key_value("type", tr("card_type.%s" % card.card_type)),
		key_value("rarity", tr("rarity.%s" % card.rarity)),
		key_value("cost", card.cost),
		tr(card.description_key),
	]

static func relic_name(catalog: Object, relic_id: String) -> String:
	var relic = catalog.get_relic(relic_id) if catalog != null and catalog.has_method("get_relic") else null
	if relic == null:
		return tr("ui.common.unknown_relic")
	return tr(relic.name_key)

static func relic_detail(catalog: Object, relic_id: String) -> String:
	var relic = catalog.get_relic(relic_id) if catalog != null and catalog.has_method("get_relic") else null
	if relic == null:
		return "%s\n%s" % [tr("ui.common.unknown_relic"), key_value("id", relic_id)]
	return "%s\n%s" % [
		key_value("tier", tr("relic_tier.%s" % relic.tier)),
		tr(relic.description_key),
	]

static func player_summary(values: Dictionary) -> String:
	return "%s %s/%s  %s %s  %s %s  %s %s" % [
		tr("ui.label.hp"),
		int(values.get("hp", 0)),
		int(values.get("max_hp", 0)),
		tr("ui.label.block"),
		int(values.get("block", 0)),
		tr("ui.label.energy"),
		int(values.get("energy", 0)),
		tr("ui.label.turn"),
		int(values.get("turn", 0)),
	]

static func enemy_summary(catalog: Object, enemy_id: String, hp: int, max_hp: int, block: int) -> String:
	var enemy = catalog.get_enemy(enemy_id) if catalog != null and catalog.has_method("get_enemy") else null
	var name := tr(enemy.name_key) if enemy != null else enemy_id
	return "%s  %s %s/%s  %s %s" % [
		name,
		tr("ui.label.hp"),
		hp,
		max_hp,
		tr("ui.label.block"),
		block,
	]

static func pile_summary(draw_count: int, discard_count: int, exhaust_count: int, phase: String) -> String:
	return "%s %s | %s %s | %s %s | %s %s" % [
		tr("ui.combat.draw"),
		draw_count,
		tr("ui.combat.discard"),
		discard_count,
		tr("ui.combat.exhaust"),
		exhaust_count,
		tr("ui.combat.phase"),
		tr("phase.%s" % phase),
	]

static func bool_text(value: bool) -> String:
	return tr("bool.true") if value else tr("bool.false")
```

- [ ] **Step 4: Add required common keys**

Add matching keys to both locale files:

```po
msgid "ui.label.id"
msgstr "ID"

msgid "ui.label.hp"
msgstr "HP"

msgid "ui.label.block"
msgstr "Block"

msgid "ui.label.energy"
msgstr "Energy"

msgid "ui.label.turn"
msgstr "Turn"

msgid "ui.label.type"
msgstr "Type"

msgid "ui.label.rarity"
msgstr "Rarity"

msgid "ui.label.cost"
msgstr "Cost"

msgid "ui.label.tier"
msgstr "Tier"

msgid "ui.label.character"
msgstr "Character"

msgid "ui.common.unknown_card"
msgstr "Unknown card"

msgid "ui.common.unknown_relic"
msgstr "Unknown relic"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 5: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/ui_text.gd scripts/testing/test_runner.gd tests/unit/test_ui_text.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: add localized ui text helper"
```

---

### Task 5: Shared Ink-And-Jade Style Helper

**Files:**
- Create: `scripts/ui/ui_style.gd`
- Create: `tests/unit/test_ui_style.gd`
- Add: `assets/ui/fonts/NotoSansSC-Regular.ttf`
- Modify: `scripts/testing/test_runner.gd`

- [ ] **Step 1: Add failing style tests**

Add `res://tests/unit/test_ui_style.gd` to the test runner after `test_ui_text.gd`.

Create `tests/unit/test_ui_style.gd`:

```gdscript
extends RefCounted

const UiStyle := preload("res://scripts/ui/ui_style.gd")

func test_style_applies_panel_and_button_metadata() -> bool:
	var panel := PanelContainer.new()
	var button := Button.new()
	UiStyle.apply_panel(panel)
	UiStyle.apply_primary_button(button)
	var passed := panel.get_meta("ui_style") == "ink_jade_panel" \
		and button.get_meta("ui_style") == "ink_jade_primary_button" \
		and button.custom_minimum_size.x >= 120.0
	panel.free()
	button.free()
	assert(passed)
	return passed

func test_badge_has_stable_size_and_text() -> bool:
	var badge := UiStyle.badge("node_type.combat")
	var passed := badge.text == tr("node_type.combat") \
		and badge.custom_minimum_size.x >= 72.0
	badge.free()
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify failure**

Run full checks.

Expected: failure because `scripts/ui/ui_style.gd` is missing.

- [ ] **Step 3: Add font asset**

Add a license-safe Chinese-capable font file at:

```text
assets/ui/fonts/NotoSansSC-Regular.ttf
```

Run the Godot import step through the full check command so `.import` metadata is generated.

- [ ] **Step 4: Implement style helper**

Create `scripts/ui/ui_style.gd`:

```gdscript
class_name UiStyle
extends RefCounted

const PANEL_COLOR := Color(0.08, 0.13, 0.11, 0.86)
const PANEL_BORDER := Color(0.48, 0.74, 0.62, 1.0)
const BUTTON_COLOR := Color(0.13, 0.28, 0.22, 1.0)
const BUTTON_HOVER := Color(0.18, 0.38, 0.30, 1.0)
const BUTTON_DISABLED := Color(0.12, 0.14, 0.13, 0.72)
const TEXT_COLOR := Color(0.92, 0.88, 0.76, 1.0)
const GOLD := Color(0.86, 0.70, 0.36, 1.0)

static func apply_panel(panel: Control) -> void:
	panel.set_meta("ui_style", "ink_jade_panel")
	panel.add_theme_stylebox_override("panel", _stylebox(PANEL_COLOR, PANEL_BORDER, 2, 8))

static func apply_primary_button(button: Button) -> void:
	button.set_meta("ui_style", "ink_jade_primary_button")
	button.custom_minimum_size = Vector2(120, 36)
	button.add_theme_stylebox_override("normal", _stylebox(BUTTON_COLOR, PANEL_BORDER, 1, 6))
	button.add_theme_stylebox_override("hover", _stylebox(BUTTON_HOVER, GOLD, 1, 6))
	button.add_theme_stylebox_override("disabled", _stylebox(BUTTON_DISABLED, Color(0.24, 0.30, 0.27, 1), 1, 6))
	button.add_theme_color_override("font_color", TEXT_COLOR)

static func apply_secondary_button(button: Button) -> void:
	apply_primary_button(button)
	button.set_meta("ui_style", "ink_jade_secondary_button")
	button.custom_minimum_size = Vector2(96, 32)

static func apply_title(label: Label) -> void:
	label.set_meta("ui_style", "ink_jade_title")
	label.add_theme_color_override("font_color", GOLD)

static func apply_body_label(label: Label) -> void:
	label.set_meta("ui_style", "ink_jade_body")
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func badge(text_key: String) -> Label:
	var label := Label.new()
	label.name = "Badge"
	label.text = tr(text_key)
	label.custom_minimum_size = Vector2(72, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.set_meta("ui_style", "ink_jade_badge")
	return label

static func _stylebox(color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
```

- [ ] **Step 5: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/ui_style.gd scripts/testing/test_runner.gd tests/unit/test_ui_style.gd assets/ui/fonts localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: add ink jade ui style helper"
```

---

### Task 6: Main Menu Slice

**Files:**
- Modify: `scripts/ui/main_menu.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing smoke tests**

Add to `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_main_menu_defaults_to_chinese_and_toggles_english(tree: SceneTree) -> bool:
	var save_path := "user://test_main_menu_locale_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	app.game.localization_service.clear_saved_locale()
	app.game.localization_service.load_or_default()
	var main_menu = app.game.router.go_to(SceneRouterScript.MAIN_MENU)
	var new_run := _find_node_by_name(main_menu, "NewRunButton") as Button
	var toggle := _find_node_by_name(main_menu, "LanguageToggleButton") as Button
	var chinese_ok := new_run != null and new_run.text == tr("ui.new_run")
	if toggle != null:
		toggle.pressed.emit()
	var english_ok := new_run != null and new_run.text == "New Run"
	var passed := chinese_ok and english_ok and toggle != null
	app.game.localization_service.clear_saved_locale()
	app.free()
	_delete_test_save(save_path)
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify failure**

Run full checks.

Expected: failure because `LanguageToggleButton` does not exist.

- [ ] **Step 3: Add locale keys**

Add to both locale files:

```po
msgid "ui.main_menu.title"
msgstr "Slay the Spire 2"

msgid "ui.main_menu.continue_disabled"
msgstr "No save available"

msgid "ui.language_toggle"
msgstr "中 / EN"
```

Use Chinese title/copy in `zh_CN.po`; keep the toggle literal as `中 / EN`.

- [ ] **Step 4: Implement localized menu**

Modify `scripts/ui/main_menu.gd`:

```gdscript
const UiStyle := preload("res://scripts/ui/ui_style.gd")

var title_label: Label
var new_run_button: Button
var language_toggle: Button
var current_app

func _ready() -> void:
	current_app = get_tree().root.get_node("App")
	_build_layout()
	if current_app.game.localization_service != null:
		current_app.game.localization_service.locale_changed.connect(func(_locale: String): _refresh_locale_text())
	_refresh_continue_button(current_app)
	_refresh_locale_text()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "MainMenuTitle"
	UiStyle.apply_title(title_label)
	add_child(title_label)

	new_run_button = Button.new()
	new_run_button.name = "NewRunButton"
	new_run_button.position.y = 72
	UiStyle.apply_primary_button(new_run_button)
	new_run_button.pressed.connect(_on_new_run_pressed)
	add_child(new_run_button)

	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.position.y = 120
	UiStyle.apply_secondary_button(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

	language_toggle = Button.new()
	language_toggle.name = "LanguageToggleButton"
	language_toggle.position = Vector2(220, 8)
	UiStyle.apply_secondary_button(language_toggle)
	language_toggle.pressed.connect(_on_language_toggle_pressed)
	add_child(language_toggle)

func _refresh_locale_text() -> void:
	title_label.text = tr("ui.main_menu.title")
	new_run_button.text = tr("ui.new_run")
	continue_button.text = tr("ui.continue")
	continue_button.tooltip_text = tr("ui.main_menu.continue_disabled") if continue_button.disabled else ""
	language_toggle.text = tr("ui.language_toggle")

func _on_language_toggle_pressed() -> void:
	var app = get_tree().root.get_node("App")
	app.game.localization_service.toggle_locale()
```

Keep existing `_on_new_run_pressed`, `_on_continue_pressed`, `_load_continuable_run`, `_refresh_continue_button`, `_should_resume_reward`, `_should_resume_shop`, and `_create_minimal_run` behavior.

- [ ] **Step 5: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/main_menu.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize main menu"
```

---

### Task 7: Map Screen Slice

**Files:**
- Modify: `scripts/ui/map_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing map smoke test**

Add to `tests/smoke/test_scene_flow.gd`:

```gdscript
func test_map_screen_localizes_node_types(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_map_locale_save.json")
	app.game.localization_service.set_locale("en")
	app.game.current_run = _test_run_with_nodes(["combat", "event", "shop"])
	var map = app.game.router.go_to(SceneRouterScript.MAP)
	var title := _find_node_by_name(map, "MapTitle") as Label
	var first_node := _find_node_by_name(map, "MapNodeButton_node_0") as Button
	var passed := title != null and title.text == "Route Map" \
		and first_node != null and first_node.text.contains("Combat")
	app.free()
	_delete_test_save("user://test_map_locale_save.json")
	assert(passed)
	return passed
```

Add helper:

```gdscript
func _test_run_with_nodes(types: Array[String]):
	var run := RunStateScript.new()
	run.seed_value = 9
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 72
	run.deck_ids = ["sword.strike", "sword.strike", "sword.strike"]
	for i in range(types.size()):
		var node := MapNodeStateScript.new("node_%s" % i, i, types[i])
		node.unlocked = i == 0
		run.map_nodes.append(node)
	return run
```

- [ ] **Step 2: Run tests and verify failure**

Run full checks.

Expected: failure because `MapTitle` and localized node labels are missing.

- [ ] **Step 3: Add map keys**

Add keys:

```po
msgid "ui.map.title"
msgstr "Route Map"

msgid "ui.map.node_label"
msgstr "{id}: {type} ({state})"

msgid "ui.map.state_unlocked"
msgstr "Available"

msgid "ui.map.state_locked"
msgstr "Locked"

msgid "ui.map.state_visited"
msgstr "Visited"

msgid "node_type.combat"
msgstr "Combat"

msgid "node_type.elite"
msgstr "Elite"

msgid "node_type.boss"
msgstr "Boss"

msgid "node_type.event"
msgstr "Event"

msgid "node_type.shop"
msgstr "Shop"

msgid "node_type.reward"
msgstr "Reward"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 4: Implement localized map rendering**

Modify `scripts/ui/map_screen.gd`:

```gdscript
const UiStyle := preload("res://scripts/ui/ui_style.gd")

var title_label: Label
var node_container: VBoxContainer

func _ready() -> void:
	var app = get_tree().root.get_node("App")
	if app.game.localization_service != null:
		app.game.localization_service.locale_changed.connect(func(_locale: String): _render())
	_build_layout()
	_render()

func _build_layout() -> void:
	title_label = Label.new()
	title_label.name = "MapTitle"
	UiStyle.apply_title(title_label)
	add_child(title_label)
	node_container = VBoxContainer.new()
	node_container.name = "MapNodeContainer"
	node_container.position = Vector2(16, 56)
	add_child(node_container)

func _render() -> void:
	title_label.text = tr("ui.map.title")
	_clear_children(node_container)
	var app = get_tree().root.get_node("App")
	for node in app.game.current_run.map_nodes:
		var button := Button.new()
		button.name = "MapNodeButton_%s" % node.id
		button.text = "%s: %s (%s)" % [node.id, tr("node_type.%s" % node.node_type), _node_state_text(node)]
		button.disabled = node.visited or not node.unlocked
		UiStyle.apply_secondary_button(button)
		button.pressed.connect(func(): _enter_node(node))
		node_container.add_child(button)

func _node_state_text(node) -> String:
	if node.visited:
		return tr("ui.map.state_visited")
	if node.unlocked:
		return tr("ui.map.state_unlocked")
	return tr("ui.map.state_locked")

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
```

Keep existing `_enter_node`.

- [ ] **Step 5: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/map_screen.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize map screen"
```

---

### Task 8: Combat Screen Slice

**Files:**
- Modify: `scripts/ui/combat_screen.gd`
- Modify: `scripts/ui/item_visual_presenter.gd`
- Modify: `scripts/ui/item_detail_panel.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `tests/unit/test_combat_visuals.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing combat localization assertions**

Update existing combat intent smoke expectations in `tests/smoke/test_scene_flow.gd` so English mode still expects `Attack`/`Player`, then add Chinese mode:

```gdscript
func test_combat_screen_localizes_player_summary_and_intent(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_combat_locale_save.json")
	app.game.localization_service.set_locale("en")
	app.game.set_debug_combat_sandbox_config({
		"character_id": "sword",
		"deck_ids": ["sword.strike"],
		"enemy_ids": ["training_puppet"],
		"seed_value": 201,
	})
	var combat = app.game.router.go_to(SceneRouterScript.COMBAT)
	var status := _find_node_by_name(combat, "PlayerStatus") as Label
	var pile := _find_node_by_name(combat, "PileStatus") as Label
	var target := _find_node_by_name(combat, "IntentTarget_0") as Label
	var passed := status != null and status.text.contains("HP") \
		and pile != null and pile.text.contains("Draw") \
		and target != null and target.text == "Player"
	app.free()
	_delete_test_save("user://test_combat_locale_save.json")
	assert(passed)
	return passed
```

- [ ] **Step 2: Run tests and verify failure**

Run full checks.

Expected: failure where old hardcoded strings do not use helper output consistently.

- [ ] **Step 3: Add combat keys**

Add keys:

```po
msgid "ui.combat.confirm_player_target"
msgstr "Confirm Player Target"

msgid "ui.combat.cancel"
msgstr "Cancel"

msgid "ui.combat.end_turn"
msgstr "End Turn"

msgid "ui.combat.draw"
msgstr "Draw"

msgid "ui.combat.discard"
msgstr "Discard"

msgid "ui.combat.exhaust"
msgstr "Exhaust"

msgid "ui.combat.phase"
msgstr "Phase"

msgid "ui.combat.no_player"
msgstr "No player"

msgid "target.player"
msgstr "Player"

msgid "target.self"
msgstr "Self"

msgid "phase.player_turn"
msgstr "Player Turn"

msgid "phase.selecting_enemy_target"
msgstr "Selecting Target"

msgid "phase.confirming_player_target"
msgstr "Confirming Player Target"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 4: Localize combat controls and summaries**

Modify imports:

```gdscript
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
```

Set button text through `_refresh_locale_text()`:

```gdscript
func _refresh_locale_text() -> void:
	player_target_button.text = tr("ui.combat.confirm_player_target")
	cancel_button.text = tr("ui.combat.cancel")
	end_turn_button.text = tr("ui.combat.end_turn")
```

Call `_refresh_locale_text()` from `_build_layout()` and connect locale signal in `_ready()`.

Replace `_player_status_text()` body:

```gdscript
	if session.state.player == null:
		return tr("ui.combat.no_player")
	var text := UiText.player_summary({
		"id": session.state.player.id,
		"hp": session.state.player.current_hp,
		"max_hp": session.state.player.max_hp,
		"block": session.state.player.block,
		"energy": session.state.energy,
		"turn": session.state.turn,
	})
```

Replace `pile_label.text` assignment:

```gdscript
	pile_label.text = UiText.pile_summary(
		session.state.draw_pile.size(),
		session.state.discard_pile.size(),
		session.state.exhausted_pile.size(),
		session.phase
	)
```

Replace `_enemy_summary_text`:

```gdscript
	var text := UiText.enemy_summary(session.catalog, enemy.id, enemy.current_hp, enemy.max_hp, enemy.block)
```

Replace `_intent_target_text`:

```gdscript
	match target:
		"player":
			return tr("target.player")
		"self":
			return tr("target.self")
	return target.capitalize()
```

- [ ] **Step 5: Localize card/relic previews and details**

Modify `scripts/ui/item_visual_presenter.gd` to preload `UiText` and use:

```gdscript
	return "%s  %s %s" % [UiText.card_name(catalog, card_id), tr("ui.label.cost"), card.cost]
```

Modify relic text:

```gdscript
	return "%s  %s" % [UiText.relic_name(catalog, relic_id), tr("relic_tier.%s" % relic.tier)]
```

Modify `scripts/ui/item_detail_panel.gd`:

```gdscript
const UiText := preload("res://scripts/ui/ui_text.gd")

var active_catalog: Object

func show_card(card_id: String, catalog: Object, theme: Dictionary = {}) -> void:
	active_catalog = catalog
	var card = catalog.get_card(card_id) if catalog != null and catalog.has_method("get_card") else null
	var visual := CombatVisualResolver.new().resolve_card_visual(card_id, catalog, theme)
	_show_common("card", card_id, _card_title(card_id, card), String(visual.get("thumbnail_path", "")), _card_body(card_id, card))

func show_relic(relic_id: String, catalog: Object) -> void:
	active_catalog = catalog
	var relic = catalog.get_relic(relic_id) if catalog != null and catalog.has_method("get_relic") else null
	var visual := ItemVisualPresenter._resolve_relic_visual(relic_id, catalog)
	_show_common("relic", relic_id, _relic_title(relic_id, relic), String(visual.get("icon_path", "")), _relic_body(relic_id, relic))

func _card_title(card_id: String, card) -> String:
	return UiText.card_name(active_catalog, card_id) if card != null else "%s (?)" % card_id

func _relic_title(relic_id: String, relic) -> String:
	return UiText.relic_name(active_catalog, relic_id) if relic != null else "%s (?)" % relic_id

func _card_body(card_id: String, card) -> String:
	return UiText.card_detail(active_catalog, card_id)

func _relic_body(relic_id: String, relic) -> String:
	return UiText.relic_detail(active_catalog, relic_id)
```

- [ ] **Step 6: Apply restrained style**

Apply `UiStyle.apply_body_label` to status and pile labels, `UiStyle.apply_secondary_button` to combat buttons, and keep existing node names.

- [ ] **Step 7: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/combat_screen.gd scripts/ui/item_visual_presenter.gd scripts/ui/item_detail_panel.gd tests/smoke/test_scene_flow.gd tests/unit/test_combat_visuals.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize combat screen"
```

---

### Task 9: Rewards Screen Slice

**Files:**
- Modify: `scripts/ui/reward_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing reward smoke test**

Add:

```gdscript
func test_reward_screen_localizes_empty_state(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_reward_locale_save.json")
	app.game.localization_service.set_locale("en")
	app.game.current_run = _test_run_with_nodes(["combat"])
	var reward = app.game.router.go_to(SceneRouterScript.REWARD)
	var title := _find_node_by_name(reward, "RewardTitle") as Label
	var status := _find_node_by_name(reward, "RewardStatus") as Label
	var passed := title != null and title.text == "Rewards" \
		and status != null and status.text.contains("No rewards")
	app.free()
	_delete_test_save("user://test_reward_locale_save.json")
	assert(passed)
	return passed
```

- [ ] **Step 2: Add reward keys**

Add:

```po
msgid "ui.reward.title"
msgstr "Rewards"

msgid "ui.reward.no_rewards"
msgstr "No rewards"

msgid "ui.reward.no_rewards_available"
msgstr "No rewards available"

msgid "ui.reward.resolve_prompt"
msgstr "Claim or skip each reward"

msgid "ui.reward.resolved"
msgstr "Rewards resolved"

msgid "ui.reward.choose_one_card"
msgstr "Choose one card"

msgid "ui.reward.take_gold"
msgstr "Take {amount} gold"

msgid "ui.reward.gold_label"
msgstr "Gold: {amount}"

msgid "ui.reward.relic_label"
msgstr "Relic: {name}"

msgid "ui.reward.skip"
msgstr "Skip"

msgid "ui.reward.state_claimed"
msgstr "Claimed"

msgid "ui.reward.state_skipped"
msgstr "Skipped"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 3: Implement localized rewards**

Preload helpers:

```gdscript
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
```

Replace fixed text assignments:

```gdscript
title_label.text = tr("ui.reward.title")
continue_button.text = tr("ui.continue")
no_rewards.text = tr("ui.reward.no_rewards")
gold_button.text = tr("ui.reward.take_gold").format({"amount": int(reward.get("amount", 0))})
button.text = tr("ui.reward.skip")
```

Replace `_reward_label_text`:

```gdscript
func _reward_label_text(reward: Dictionary) -> String:
	match String(reward.get("type", "")):
		"card_choice":
			return tr("ui.reward.choose_one_card")
		"gold":
			return tr("ui.reward.gold_label").format({"amount": int(reward.get("amount", 0))})
		"relic":
			return tr("ui.reward.relic_label").format({"name": UiText.relic_name(catalog, String(reward.get("relic_id", "")))})
	return tr("ui.common.unknown_reward")
```

Style title, status, reward buttons, and continue button with `UiStyle`.

- [ ] **Step 4: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/reward_screen.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize reward screen"
```

---

### Task 10: Event Screen Slice

**Files:**
- Modify: `scripts/ui/event_screen.gd`
- Modify: `scripts/event/event_runner.gd`
- Modify: `tests/unit/test_event_runner.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing event localization test**

Add to `tests/unit/test_event_runner.gd`:

```gdscript
func test_unavailable_reason_uses_locale_key() -> bool:
	var option := EventOptionDef.new()
	option.min_gold = 99
	var run := RunState.new()
	run.gold = 1
	var reason := EventRunner.new().unavailable_reason(run, option)
	var passed := reason == "ui.event.need_gold"
	assert(passed)
	return passed
```

- [ ] **Step 2: Add event keys**

Add:

```po
msgid "ui.event.fallback_title"
msgstr "Event"

msgid "ui.event.no_event"
msgstr "No event available"

msgid "ui.event.need_hp"
msgstr "Need more HP"

msgid "ui.event.need_gold"
msgstr "Need more gold"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 3: Return reason keys from runner**

Modify `scripts/event/event_runner.gd` unavailable reasons to return keys:

```gdscript
if run.current_hp < option.min_hp:
	return "ui.event.need_hp"
if run.gold < option.min_gold:
	return "ui.event.need_gold"
return ""
```

- [ ] **Step 4: Localize event screen composition**

In `scripts/ui/event_screen.gd`, replace fallback text:

```gdscript
title_label.text = tr("ui.event.fallback_title")
body_label.text = tr("ui.event.no_event")
button.text = tr("ui.continue")
```

Replace unavailable display:

```gdscript
if not reason.is_empty():
	button.text = "%s (%s)" % [button.text, tr(reason)]
```

Apply `UiStyle` to title, body, option buttons, and preview rows.

- [ ] **Step 5: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/event_screen.gd scripts/event/event_runner.gd tests/unit/test_event_runner.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize event screen"
```

---

### Task 11: Shop Screen Slice

**Files:**
- Modify: `scripts/ui/shop_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing shop smoke test**

Add:

```gdscript
func test_shop_screen_localizes_actions(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_shop_locale_save.json")
	app.game.localization_service.set_locale("en")
	app.game.current_run = _test_run_with_nodes(["shop"])
	app.game.current_run.current_node_id = "node_0"
	var shop = app.game.router.go_to(SceneRouterScript.SHOP)
	var title := _find_node_by_name(shop, "ShopTitle") as Label
	var leave := _find_node_by_name(shop, "LeaveShopButton") as Button
	var refresh := _find_node_by_name(shop, "RefreshButton") as Button
	var passed := title != null and title.text == "Shop" \
		and leave != null and leave.text == "Leave" \
		and refresh != null and refresh.text.contains("Refresh")
	app.free()
	_delete_test_save("user://test_shop_locale_save.json")
	assert(passed)
	return passed
```

- [ ] **Step 2: Add shop keys**

Add:

```po
msgid "ui.shop.title"
msgstr "Shop"

msgid "ui.shop.gold"
msgstr "Gold: {amount}"

msgid "ui.shop.no_shop"
msgstr "No shop available"

msgid "ui.shop.card_offer"
msgstr "Card: {name} [{rarity}] ({cost}) - {price} gold"

msgid "ui.shop.relic_offer"
msgstr "Relic: {name} [{tier}] - {price} gold"

msgid "ui.shop.heal_offer"
msgstr "Heal - {price} gold"

msgid "ui.shop.remove_offer"
msgstr "Remove a card - {price} gold"

msgid "ui.shop.unknown_offer"
msgstr "Unknown offer"

msgid "ui.shop.sold_out"
msgstr "Sold out"

msgid "ui.shop.buy"
msgstr "Buy"

msgid "ui.shop.choose_card"
msgstr "Choose card"

msgid "ui.shop.choose_remove_card"
msgstr "Choose a card to remove"

msgid "ui.shop.refresh"
msgstr "Refresh ({price} gold)"

msgid "ui.shop.leave"
msgstr "Leave"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 3: Implement localized shop labels**

Preload:

```gdscript
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
```

Replace assignments:

```gdscript
title_label.text = tr("ui.shop.title")
gold_label.text = tr("ui.shop.gold").format({"amount": run.gold})
status_label.text = tr("ui.shop.no_shop")
sold_label.text = tr("ui.shop.sold_out")
label.text = tr("ui.shop.choose_remove_card")
refresh_button.text = tr("ui.shop.refresh").format({"price": ShopResolver.REFRESH_PRICE})
leave_button.text = tr("ui.shop.leave")
```

Replace `_offer_label`:

```gdscript
func _offer_label(offer: Dictionary) -> String:
	var offer_type := String(offer.get("type", ""))
	var item_id := String(offer.get("item_id", ""))
	var price := int(offer.get("price", 0))
	match offer_type:
		"card":
			var card = catalog.get_card(item_id)
			if card != null:
				return tr("ui.shop.card_offer").format({
					"name": UiText.card_name(catalog, item_id),
					"rarity": tr("rarity.%s" % card.rarity),
					"cost": card.cost,
					"price": price,
				})
		"relic":
			var relic = catalog.get_relic(item_id)
			if relic != null:
				return tr("ui.shop.relic_offer").format({
					"name": UiText.relic_name(catalog, item_id),
					"tier": tr("relic_tier.%s" % relic.tier),
					"price": price,
				})
		"heal":
			return tr("ui.shop.heal_offer").format({"price": price})
		"remove":
			return tr("ui.shop.remove_offer").format({"price": price})
	return tr("ui.shop.unknown_offer")
```

Replace `_buy_button_text`:

```gdscript
return tr("ui.shop.choose_card") if String(offer.get("type", "")) == "remove" else tr("ui.shop.buy")
```

Apply `UiStyle` to panels, offer buttons, refresh, and leave.

- [ ] **Step 4: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/shop_screen.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize shop screen"
```

---

### Task 12: Run Summary Slice

**Files:**
- Modify: `scripts/ui/run_summary_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing summary smoke test**

Update existing summary tests to check label text in English:

```gdscript
func test_completed_run_summary_localizes_result(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_summary_locale_save.json")
	app.game.localization_service.set_locale("en")
	var run := RunStateScript.new()
	run.completed = true
	app.game.current_run = run
	var summary = app.game.router.go_to(SceneRouterScript.SUMMARY)
	var title := _find_node_by_name(summary, "RunSummaryTitle") as Label
	var passed := title != null and title.text == "Victory Summary"
	app.free()
	_delete_test_save("user://test_summary_locale_save.json")
	assert(passed)
	return passed
```

- [ ] **Step 2: Add summary keys**

Add:

```po
msgid "ui.summary.victory"
msgstr "Victory Summary"

msgid "ui.summary.defeat"
msgstr "Defeat Summary"

msgid "ui.summary.return_menu"
msgstr "Return to Main Menu"

msgid "ui.summary.stats"
msgstr "Run complete"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 3: Implement summary layout**

Modify `scripts/ui/run_summary_screen.gd`:

```gdscript
const UiStyle := preload("res://scripts/ui/ui_style.gd")

func _ready() -> void:
	var app = get_tree().root.get_node("App")
	var run = app.game.current_run
	var run_failed: bool = run != null and run.failed
	var label := Label.new()
	label.name = "RunSummaryTitle"
	label.text = tr("ui.summary.defeat") if run_failed else tr("ui.summary.victory")
	UiStyle.apply_title(label)
	add_child(label)
	var stats := Label.new()
	stats.name = "RunSummaryStats"
	stats.text = tr("ui.summary.stats")
	stats.position.y = 32
	UiStyle.apply_body_label(stats)
	add_child(stats)
	_clear_ended_run(app)
	var menu := Button.new()
	menu.name = "RunSummaryMenuButton"
	menu.text = tr("ui.summary.return_menu")
	menu.position.y = 80
	UiStyle.apply_primary_button(menu)
	menu.pressed.connect(func(): app.game.router.go_to(SceneRouterScript.MAIN_MENU))
	add_child(menu)
```

- [ ] **Step 4: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/run_summary_screen.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize run summary"
```

---

### Task 13: Debug Overlay Slice

**Files:**
- Modify: `scripts/ui/debug_overlay.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing debug overlay test**

Add:

```gdscript
func test_debug_overlay_localizes_controls() -> bool:
	TranslationServer.set_locale("en")
	var debug_overlay := DebugOverlayScene.instantiate() as Control
	debug_overlay._ready()
	var heal := _find_node_by_name(debug_overlay, "DebugFullHp") as Button
	var dev_tools := _find_node_by_name(debug_overlay, "DebugDevTools") as Button
	var passed := heal != null and heal.text == "Debug: Full HP" \
		and dev_tools != null and dev_tools.text == "Debug: Dev Tools"
	debug_overlay.free()
	assert(passed)
	return passed
```

- [ ] **Step 2: Add debug keys**

Add keys for every visible debug label:

```po
msgid "ui.debug.prefix"
msgstr "Debug: {label}"

msgid "ui.debug.full_hp"
msgstr "Full HP"

msgid "ui.debug.gold_100"
msgstr "+100 Gold"

msgid "ui.debug.map"
msgstr "Map"

msgid "ui.debug.dev_tools"
msgstr "Dev Tools"

msgid "ui.debug.presentation"
msgstr "Presentation"

msgid "ui.debug.reduced_motion"
msgstr "Reduced Motion"

msgid "ui.debug.drag_play"
msgstr "Drag Play"

msgid "ui.debug.float_text"
msgstr "Float Text"

msgid "ui.debug.hit_flash"
msgstr "Hit Flash"

msgid "ui.debug.target_highlight"
msgstr "Target Highlight"

msgid "ui.debug.status_pulse"
msgstr "Status Pulse"

msgid "ui.debug.future_cinematic"
msgstr "Future Cinematic"

msgid "ui.debug.particles"
msgstr "Particles"

msgid "ui.debug.camera_impulse"
msgstr "Camera Impulse"

msgid "ui.debug.slow_motion"
msgstr "Slow Motion"

msgid "ui.debug.audio_cue"
msgstr "Audio Cue"

msgid "ui.debug.master_volume"
msgstr "Master Volume"

msgid "ui.debug.music_volume"
msgstr "Music Volume"

msgid "ui.debug.sfx_volume"
msgstr "SFX Volume"

msgid "ui.debug.ui_volume"
msgstr "UI Volume"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 3: Implement localized debug labels**

Add helper in `debug_overlay.gd`:

```gdscript
func _debug_text(key: String) -> String:
	return tr("ui.debug.prefix").format({"label": tr(key)})
```

Replace button labels:

```gdscript
heal.name = "DebugFullHp"
heal.text = _debug_text("ui.debug.full_hp")
gold.text = _debug_text("ui.debug.gold_100")
map.text = _debug_text("ui.debug.map")
dev_tools.text = _debug_text("ui.debug.dev_tools")
```

Update `_add_presentation_toggle` calls to pass translation keys instead of English labels:

```gdscript
_add_presentation_toggle(box, "DebugPresentationEnabled", "ui.debug.presentation", "enabled")
```

Inside `_add_presentation_toggle`:

```gdscript
toggle.text = _debug_text(label)
```

Inside `_add_audio_volume_slider`:

```gdscript
label_node.text = _debug_text(label)
```

Apply `UiStyle.apply_panel(self)` and `UiStyle.apply_secondary_button` to buttons.

- [ ] **Step 4: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/debug_overlay.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize debug overlay"
```

---

### Task 14: Dev Tools Slice

**Files:**
- Modify: `scripts/ui/dev_tools_screen.gd`
- Modify: `tests/unit/test_dev_tools_screen.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `localization/zh_CN.po`
- Modify: `localization/en.po`

- [ ] **Step 1: Write failing Dev Tools localization tests**

Update `tests/unit/test_dev_tools_screen.gd`:

```gdscript
func test_dev_tools_tool_labels_localize() -> bool:
	TranslationServer.set_locale("en")
	var screen := DevToolsScreen.new()
	var passed := screen.tool_label("card_browser") == "Card Browser" \
		and screen.tool_label("save_inspector") == "Save Inspector"
	screen.free()
	assert(passed)
	return passed

func test_dev_tools_summaries_localize_labels_and_preserve_ids() -> bool:
	TranslationServer.set_locale("en")
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_enemy_sandbox_character("alchemy")
	var summary := screen.enemy_sandbox_summary_text()
	var passed := summary.contains("Character: alchemy") \
		and summary.contains("Deck:")
	screen.free()
	assert(passed)
	return passed
```

- [ ] **Step 2: Add Dev Tools keys**

Add keys:

```po
msgid "ui.dev_tools.title"
msgstr "Dev Tools"

msgid "ui.dev_tools.card_browser"
msgstr "Card Browser"

msgid "ui.dev_tools.enemy_sandbox"
msgstr "Enemy Sandbox"

msgid "ui.dev_tools.event_tester"
msgstr "Event Tester"

msgid "ui.dev_tools.reward_inspector"
msgstr "Reward Inspector"

msgid "ui.dev_tools.save_inspector"
msgstr "Save Inspector"

msgid "ui.dev_tools.no_cards"
msgstr "No cards match filters"

msgid "ui.dev_tools.no_card_selected"
msgstr "No card selected"

msgid "ui.dev_tools.launch_sandbox"
msgstr "Launch Sandbox"

msgid "ui.dev_tools.starter_deck"
msgstr "Starter deck: {deck}"

msgid "ui.dev_tools.reset_test_run"
msgstr "Reset Test Run"

msgid "ui.dev_tools.no_event"
msgstr "No event available"

msgid "ui.dev_tools.reset_reward_run"
msgstr "Reset Reward Run"

msgid "ui.dev_tools.no_rewards"
msgstr "No rewards"

msgid "ui.dev_tools.reload"
msgstr "Reload"

msgid "ui.dev_tools.delete"
msgstr "Delete"

msgid "ui.dev_tools.export"
msgstr "Export"

msgid "ui.dev_tools.copy_json"
msgstr "Copy JSON"

msgid "ui.dev_tools.repair"
msgstr "Repair"
```

Also add labels used in summaries:

```po
msgid "ui.label.deck"
msgstr "Deck"

msgid "ui.label.enemy"
msgstr "Enemy"

msgid "ui.label.event"
msgstr "Event"

msgid "ui.label.gold"
msgstr "Gold"

msgid "ui.label.relics"
msgstr "Relics"

msgid "ui.label.pending_rewards"
msgstr "Pending rewards"

msgid "ui.label.status"
msgstr "Status"

msgid "ui.label.reason"
msgstr "Reason"
```

Use Chinese translations in `zh_CN.po`.

- [ ] **Step 3: Add tool label helper**

Modify `scripts/ui/dev_tools_screen.gd`:

```gdscript
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")

const TOOL_LABEL_KEYS := {
	"card_browser": "ui.dev_tools.card_browser",
	"enemy_sandbox": "ui.dev_tools.enemy_sandbox",
	"event_tester": "ui.dev_tools.event_tester",
	"reward_inspector": "ui.dev_tools.reward_inspector",
	"save_inspector": "ui.dev_tools.save_inspector",
}

func tool_label(tool_id: String) -> String:
	return tr(String(TOOL_LABEL_KEYS.get(tool_id, tool_id)))
```

Replace `TOOL_LABELS` display reads with `tool_label(tool_id)`.

- [ ] **Step 4: Localize visible tool UI**

Replace key text assignments:

```gdscript
title.text = tr("ui.dev_tools.title")
empty.text = tr("ui.dev_tools.no_cards")
card_detail_label.text = card_detail_text(null)
launch.text = tr("ui.dev_tools.launch_sandbox")
enemy_sandbox_deck_label.text = tr("ui.dev_tools.starter_deck").format({"deck": _join_string_array(deck_ids)})
reset.text = tr("ui.dev_tools.reset_test_run")
empty.text = tr("ui.dev_tools.no_event")
reset.text = tr("ui.dev_tools.reset_reward_run")
empty.text = tr("ui.dev_tools.no_rewards")
reload.text = tr("ui.dev_tools.reload")
```

Replace `_disabled_save_inspector_action` call labels with translation keys:

```gdscript
action_bar.add_child(_disabled_save_inspector_action("SaveInspectorDeleteButton", "ui.dev_tools.delete"))
```

Inside `_disabled_save_inspector_action`:

```gdscript
button.text = tr(label)
```

- [ ] **Step 5: Localize summary helpers while preserving ids**

Use `UiText.key_value` in:

- `card_detail_text`
- `enemy_sandbox_summary_text`
- `event_tester_run_summary_text`
- `event_tester_option_text`
- `reward_inspector_run_summary_text`
- `reward_inspector_reward_text`
- `save_inspector_status_text`
- `save_inspector_summary_text`
- `save_inspector_map_text`
- `save_inspector_shop_text`
- `save_inspector_reward_text`

Example:

```gdscript
var lines: Array[String] = [
	UiText.key_value("character", String(config.get("character_id", ""))),
	UiText.key_value("deck", _join_string_array(config.get("deck_ids", []))),
]
```

- [ ] **Step 6: Apply grouped panel styling**

Apply `UiStyle.apply_panel` to each tool panel container and `UiStyle.apply_secondary_button` to tool nav/action buttons. Keep all existing node names.

- [ ] **Step 7: Run tests and commit**

Run full checks.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add scripts/ui/dev_tools_screen.gd tests/unit/test_dev_tools_screen.gd tests/smoke/test_scene_flow.gd localization/zh_CN.po localization/en.po
rtk proxy git commit -m "feat: localize dev tools"
```

---

### Task 15: Cross-Screen Visual Fit And Final Review

**Files:**
- Modify: `README.md`
- Modify: screen files only if review finds overlap, missing text, or styling bugs

- [ ] **Step 1: Run full verification**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ci\run_godot_checks.ps1 -ProjectRoot .
```

Expected: `Godot checks passed.`

- [ ] **Step 2: Run hardcoded English scan**

Run:

```powershell
rtk rg -n '"[A-Z][A-Za-z ,:()|+\-/]{2,}"' scripts/ui scripts/presentation scripts/combat
```

Expected: remaining matches are technical ids, debug data values, node names, resource paths, test-only strings, or intentionally localized key names. Every player-visible English literal in UI code is replaced by `tr(...)` or `UiText`.

- [ ] **Step 3: Run Stage 1 spec compliance review**

Check this compliance list and fix misses before continuing:

- `zh_CN` is default on first launch.
- `en.po` exists and is registered.
- Main Menu has `LanguageToggleButton` with `中 / EN`.
- Main Menu, Map, Combat, Rewards, Event, Shop, Run Summary, Debug Overlay, and Dev Tools all have Chinese/English tests or smoke checks.
- Enemy intent resources use `label_key`.
- Card/relic/detail panels display translated names as primary labels.
- Debug screens are included.
- No gameplay behavior is changed outside UI/i18n.

- [ ] **Step 4: Run Stage 2 code quality review**

Check and fix:

- Signal connections are not duplicated after refresh.
- UI helpers stay focused; no broad UI framework appeared.
- Node names used by tests remain stable.
- Translation key groups match the spec.
- GDScript typing follows local style.
- New assets are focused and license-safe.
- Screen styling is cohesive and does not overlap at 1280x720.

- [ ] **Step 5: Update README**

Add to Phase 2 Progress:

```markdown
- Localization and near-demo UI polish foundation: complete; Chinese is the default interface, Main Menu exposes a `中 / EN` toggle, Chinese/English translations cover main-flow and debug screens, and shared ink-and-jade UI styling now applies across screens.
```

Update Next Plans by removing this item if it appears as future work.

- [ ] **Step 6: Final verification and commit**

Run full checks again.

Expected: `Godot checks passed.`

Commit:

```bash
rtk proxy git add README.md scripts tests localization project.godot resources/intents assets/ui
rtk proxy git commit -m "docs: record localization ui polish completion"
```

---

## Handoff Notes

- Keep each task in a separate commit.
- Do not change gameplay behavior to satisfy UI tests.
- Do not create feature branches inside the primary repo; continue in `.worktrees/localization-ui-polish-roadmap`.
- If a screen needs larger layout work than planned, finish localization first inside that screen, then polish within the same task.
- If a test exposes mojibake only in PowerShell output, verify the actual file is UTF-8 and the Godot UI renders correctly before changing translations.
