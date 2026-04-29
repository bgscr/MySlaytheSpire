# Developer Tools Foundation and Card Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a debug-only DevTools hub with stable entries for planned tools and a fully usable read-only Card Browser.

**Architecture:** Add a routable `DevToolsScreen` reached from `DebugOverlay`. Keep the first pass self-contained in `scripts/ui/dev_tools_screen.gd`: it loads `ContentCatalog`, renders tool navigation, implements Card Browser filtering/detail helpers, and shows explicit placeholders for deferred tools.

**Tech Stack:** Godot 4.6.2-stable, GDScript, dynamic Control nodes, existing headless test runner, Windows PowerShell through `rtk proxy`.

---

## Project Constraints

- Work directly on local `main`; do not create branches or worktrees.
- Before editing code, verify `git branch --show-current` is `main`; stop if it is not.
- Prefix shell commands with `rtk proxy`.
- Use red/green TDD for behavior changes.
- After each completed Godot feature, run the two-stage review from `AGENTS.md`:
  - Stage 1 Spec Compliance Review.
  - Stage 2 Code Quality Review only after Stage 1 passes.
- DevTools must not mutate run state, save data, or resource files.
- This plan intentionally uses inline execution because subagents were not explicitly requested and this repository requires main-only development.

## Reference Spec

- `docs/superpowers/specs/2026-04-29-dev-tools-foundation-card-browser-design.md`

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

- `scripts/ui/dev_tools_screen.gd`: DevTools hub, Card Browser filters/details, and deferred tool placeholders.
- `scenes/dev/DevToolsScreen.tscn`: routable debug scene.
- `tests/unit/test_dev_tools_screen.gd`: unit coverage for filter, ordering, detail, and placeholder helper behavior.

Modify:

- `scripts/app/scene_router.gd`: add `DEV_TOOLS` scene path.
- `scripts/ui/debug_overlay.gd`: add `DebugDevTools` route button.
- `scripts/testing/test_runner.gd`: register the DevTools unit tests.
- `tests/smoke/test_scene_flow.gd`: add route and UI smoke coverage.
- `README.md`: record completion and update next plans after acceptance.
- `docs/superpowers/plans/2026-04-29-dev-tools-foundation-card-browser.md`: mark steps complete during execution.

## Task 1: Card Browser Script and Helper Tests

**Files:**

- Create: `scripts/ui/dev_tools_screen.gd`
- Create: `tests/unit/test_dev_tools_screen.gd`
- Modify: `scripts/testing/test_runner.gd`
- Modify: `docs/superpowers/plans/2026-04-29-dev-tools-foundation-card-browser.md`

- [x] **Step 1: Verify branch and clean workspace**

Run:

```powershell
rtk proxy git branch --show-current
rtk proxy git status --short
```

Expected:

```text
main
```

`git status --short` should show only this plan file before implementation starts.

- [x] **Step 2: Register the new unit test file**

Modify `scripts/testing/test_runner.gd` and insert this path after `test_content_catalog.gd`:

```gdscript
	"res://tests/unit/test_dev_tools_screen.gd",
```

- [x] **Step 3: Write failing DevTools unit tests**

Create `tests/unit/test_dev_tools_screen.gd`:

```gdscript
extends RefCounted

const DevToolsScreen := preload("res://scripts/ui/dev_tools_screen.gd")

func test_dev_tools_card_browser_loads_all_cards_with_all_filters() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("all", "all", "all")
	var cards := screen.filtered_cards()
	var passed: bool = cards.size() == 40 \
		and cards[0].id == "alchemy.bitter_extract"
	assert(passed)
	return passed

func test_dev_tools_card_browser_filters_with_and_semantics() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("sword", "common", "attack")
	var cards := screen.filtered_cards()
	var ids := _ids(cards)
	var passed: bool = ids.has("sword.strike") \
		and cards.size() == 6 \
		and cards[0].id == "sword.flash_cut" \
		and _all_cards_match(cards, "sword", "common", "attack")
	assert(passed)
	return passed

func test_dev_tools_card_browser_keeps_matching_selection_after_filter_change() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("all", "all", "all")
	screen.select_card("sword.strike")
	screen.set_filters("sword", "common", "attack")
	var passed: bool = screen.selected_card_id == "sword.strike"
	assert(passed)
	return passed

func test_dev_tools_card_browser_selects_first_match_when_selection_is_filtered_out() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("all", "all", "all")
	screen.select_card("alchemy.toxic_pill")
	screen.set_filters("sword", "common", "attack")
	var passed: bool = screen.selected_card_id == "sword.flash_cut"
	assert(passed)
	return passed

func test_dev_tools_card_detail_text_includes_effects_and_presentation_cues() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var card = screen.catalog.get_card("sword.strike")
	var detail := screen.card_detail_text(card)
	var passed: bool = detail.contains("id: sword.strike") \
		and detail.contains("cost: 1") \
		and detail.contains("effect: damage target=enemy amount=6") \
		and detail.contains("cue: cinematic_slash target_mode=played_target")
	assert(passed)
	return passed

func test_dev_tools_exposes_deferred_tool_placeholders() -> bool:
	var screen := DevToolsScreen.new()
	var tool_ids := screen.tool_ids()
	var passed: bool = tool_ids == [
		"card_browser",
		"enemy_sandbox",
		"event_tester",
		"reward_inspector",
		"save_inspector",
	] \
		and screen.placeholder_text("enemy_sandbox").contains("Enemy Sandbox") \
		and screen.placeholder_text("enemy_sandbox").contains("Planned tool")
	assert(passed)
	return passed

func _ids(cards: Array) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(card.id)
	return result

func _all_cards_match(cards: Array, character_id: String, rarity: String, card_type: String) -> bool:
	for card in cards:
		if card.character_id != character_id or card.rarity != rarity or card.card_type != card_type:
			return false
	return true
```

- [x] **Step 4: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because `res://scripts/ui/dev_tools_screen.gd` does not exist.

- [x] **Step 5: Implement `DevToolsScreen`**

Create `scripts/ui/dev_tools_screen.gd`:

```gdscript
extends Control

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")

const TOOL_CARD_BROWSER := "card_browser"
const FILTER_ALL := "all"
const RARITY_ORDER := {"common": 0, "uncommon": 1, "rare": 2}
const TYPE_ORDER := {"attack": 0, "skill": 1, "power": 2}
const TOOL_LABELS := {
	"card_browser": "Card Browser",
	"enemy_sandbox": "Enemy Sandbox",
	"event_tester": "Event Tester",
	"reward_inspector": "Reward Inspector",
	"save_inspector": "Save Inspector",
}

var catalog := ContentCatalog.new()
var active_tool_id := TOOL_CARD_BROWSER
var selected_card_id := ""
var character_filter := FILTER_ALL
var rarity_filter := FILTER_ALL
var card_type_filter := FILTER_ALL
var tool_content: VBoxContainer
var card_list: VBoxContainer
var card_detail_label: Label
var character_filter_button: OptionButton
var rarity_filter_button: OptionButton
var type_filter_button: OptionButton

func _ready() -> void:
	if catalog.cards_by_id.is_empty():
		catalog.load_default()
	_build_layout()
	_show_tool(TOOL_CARD_BROWSER)

func load_default_catalog() -> void:
	catalog.load_default()
	_refresh_selected_card()

func tool_ids() -> Array[String]:
	return [
		"card_browser",
		"enemy_sandbox",
		"event_tester",
		"reward_inspector",
		"save_inspector",
	]

func set_filters(character_id: String, rarity: String, card_type: String) -> void:
	character_filter = character_id
	rarity_filter = rarity
	card_type_filter = card_type
	_refresh_selected_card()
	_refresh_card_browser_if_ready()

func select_card(card_id: String) -> void:
	if catalog.get_card(card_id) == null:
		return
	selected_card_id = card_id
	_refresh_card_browser_if_ready()

func filtered_cards() -> Array[CardDef]:
	var result: Array[CardDef] = []
	for card: CardDef in catalog.cards_by_id.values():
		if _card_matches_filters(card):
			result.append(card)
	result.sort_custom(func(a: CardDef, b: CardDef): return _card_less(a, b))
	return result

func card_detail_text(card: CardDef) -> String:
	if card == null:
		return "No card selected"
	var lines: Array[String] = [
		"id: %s" % card.id,
		"name_key: %s" % card.name_key,
		"description_key: %s" % card.description_key,
		"character: %s" % card.character_id,
		"rarity: %s" % card.rarity,
		"type: %s" % card.card_type,
		"cost: %s" % card.cost,
		"tags: %s" % _join_string_array(card.tags),
		"pool_tags: %s" % _join_string_array(card.pool_tags),
		"reward_weight: %s" % card.reward_weight,
	]
	if card.effects.is_empty():
		lines.append("effects: none")
	else:
		for effect in card.effects:
			lines.append(_effect_text(effect))
	if card.presentation_cues.is_empty():
		lines.append("presentation_cues: none")
	else:
		for cue in card.presentation_cues:
			lines.append(_cue_text(cue))
	return "\n".join(lines)

func placeholder_text(tool_id: String) -> String:
	return "%s\nPlanned tool" % String(TOOL_LABELS.get(tool_id, tool_id))

func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.name = "DevToolsRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.name = "DevToolsTitle"
	title.text = "DevTools"
	root.add_child(title)

	var tool_nav := HBoxContainer.new()
	tool_nav.name = "ToolNav"
	root.add_child(tool_nav)
	for tool_id in tool_ids():
		var button := Button.new()
		button.name = "ToolButton_%s" % tool_id
		button.text = String(TOOL_LABELS.get(tool_id, tool_id))
		var selected_tool_id := tool_id
		button.pressed.connect(func(): _show_tool(selected_tool_id))
		tool_nav.add_child(button)

	tool_content = VBoxContainer.new()
	tool_content.name = "ToolContent"
	root.add_child(tool_content)

func _show_tool(tool_id: String) -> void:
	active_tool_id = tool_id
	_clear_children(tool_content)
	if tool_id == TOOL_CARD_BROWSER:
		_build_card_browser()
	else:
		var placeholder := Label.new()
		placeholder.name = "ToolPlaceholder_%s" % tool_id
		placeholder.text = placeholder_text(tool_id)
		tool_content.add_child(placeholder)

func _build_card_browser() -> void:
	var panel := VBoxContainer.new()
	panel.name = "CardBrowserPanel"
	tool_content.add_child(panel)

	var filters := HBoxContainer.new()
	filters.name = "CardBrowserFilters"
	panel.add_child(filters)
	character_filter_button = _add_filter(filters, "CharacterFilter", ["all", "alchemy", "sword"], character_filter, _on_character_filter_selected)
	rarity_filter_button = _add_filter(filters, "RarityFilter", ["all", "common", "uncommon", "rare"], rarity_filter, _on_rarity_filter_selected)
	type_filter_button = _add_filter(filters, "TypeFilter", ["all", "attack", "skill", "power"], card_type_filter, _on_type_filter_selected)

	var body := HBoxContainer.new()
	body.name = "CardBrowserBody"
	panel.add_child(body)

	card_list = VBoxContainer.new()
	card_list.name = "CardList"
	body.add_child(card_list)

	card_detail_label = Label.new()
	card_detail_label.name = "CardDetailLabel"
	card_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(card_detail_label)

	_refresh_card_browser()

func _add_filter(parent: Node, node_name: String, values: Array[String], selected_value: String, callback: Callable) -> OptionButton:
	var filter := OptionButton.new()
	filter.name = node_name
	for value in values:
		filter.add_item(value)
		if value == selected_value:
			filter.select(filter.get_item_count() - 1)
	filter.item_selected.connect(callback)
	parent.add_child(filter)
	return filter

func _on_character_filter_selected(index: int) -> void:
	set_filters(character_filter_button.get_item_text(index), rarity_filter, card_type_filter)

func _on_rarity_filter_selected(index: int) -> void:
	set_filters(character_filter, rarity_filter_button.get_item_text(index), card_type_filter)

func _on_type_filter_selected(index: int) -> void:
	set_filters(character_filter, rarity_filter, type_filter_button.get_item_text(index))

func _refresh_card_browser_if_ready() -> void:
	if card_list != null and card_detail_label != null:
		_refresh_card_browser()

func _refresh_card_browser() -> void:
	var cards := filtered_cards()
	_clear_children(card_list)
	if cards.is_empty():
		var empty := Label.new()
		empty.name = "NoMatchingCardsLabel"
		empty.text = "No cards match filters"
		card_list.add_child(empty)
		selected_card_id = ""
		card_detail_label.text = card_detail_text(null)
		return
	if selected_card_id.is_empty() or not _card_id_in_cards(selected_card_id, cards):
		selected_card_id = cards[0].id
	for card in cards:
		var button := Button.new()
		button.name = "CardBrowserCard_%s" % card.id.replace(".", "_")
		button.text = "%s | %s | %s | %s | %s" % [card.id, card.character_id, card.rarity, card.card_type, card.cost]
		button.disabled = card.id == selected_card_id
		var selected_id := card.id
		button.pressed.connect(func(): select_card(selected_id))
		card_list.add_child(button)
	card_detail_label.text = card_detail_text(catalog.get_card(selected_card_id))

func _refresh_selected_card() -> void:
	var cards := filtered_cards()
	if cards.is_empty():
		selected_card_id = ""
	elif selected_card_id.is_empty() or not _card_id_in_cards(selected_card_id, cards):
		selected_card_id = cards[0].id

func _card_matches_filters(card: CardDef) -> bool:
	if card == null:
		return false
	if character_filter != FILTER_ALL and card.character_id != character_filter:
		return false
	if rarity_filter != FILTER_ALL and card.rarity != rarity_filter:
		return false
	if card_type_filter != FILTER_ALL and card.card_type != card_type_filter:
		return false
	return true

func _card_less(a: CardDef, b: CardDef) -> bool:
	if a.character_id != b.character_id:
		return a.character_id < b.character_id
	var rarity_a := int(RARITY_ORDER.get(a.rarity, 99))
	var rarity_b := int(RARITY_ORDER.get(b.rarity, 99))
	if rarity_a != rarity_b:
		return rarity_a < rarity_b
	var type_a := int(TYPE_ORDER.get(a.card_type, 99))
	var type_b := int(TYPE_ORDER.get(b.card_type, 99))
	if type_a != type_b:
		return type_a < type_b
	return a.id < b.id

func _card_id_in_cards(card_id: String, cards: Array[CardDef]) -> bool:
	for card in cards:
		if card.id == card_id:
			return true
	return false

func _effect_text(effect: EffectDef) -> String:
	if effect == null:
		return "effect: null"
	var text := "effect: %s target=%s amount=%s" % [effect.effect_type, effect.target, effect.amount]
	if not effect.status_id.is_empty():
		text += " status=%s" % effect.status_id
	return text

func _cue_text(cue: CardPresentationCueDef) -> String:
	if cue == null:
		return "cue: null"
	var text := "cue: %s target_mode=%s amount=%s intensity=%s" % [
		cue.event_type,
		cue.target_mode,
		cue.amount,
		cue.intensity,
	]
	if not cue.cue_id.is_empty():
		text += " cue_id=%s" % cue.cue_id
	if not cue.tags.is_empty():
		text += " tags=%s" % _join_string_array(cue.tags)
	return text

func _join_string_array(values: Array[String]) -> String:
	if values.is_empty():
		return "none"
	return ", ".join(values)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.free()
```

- [x] **Step 6: Run tests to verify GREEN for Task 1**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 7: Run Task 1 review gates**

Stage 1 Spec Compliance Review:

- `DevToolsScreen` exists.
- Card Browser loads default catalog cards.
- Character, rarity, and card type filters exist as state and helpers.
- Filters combine with AND semantics.
- Ordering is deterministic.
- Card detail text includes core card fields, effects, and presentation cues.
- Deferred tool ids and placeholder text are explicit.

Stage 2 Code Quality Review:

- Filtering and detail helpers are typed and deterministic.
- UI-building code reuses helper state instead of separate logic.
- `DevToolsScreen` does not mutate run state, saves, or resources.
- Tests inspect raw ids and keys, not translated copy.

- [x] **Step 8: Commit Task 1**

Run:

```powershell
rtk proxy git add scripts/ui/dev_tools_screen.gd tests/unit/test_dev_tools_screen.gd scripts/testing/test_runner.gd docs/superpowers/plans/2026-04-29-dev-tools-foundation-card-browser.md
rtk proxy git commit -m "feat: add dev tools card browser"
```

## Task 2: DevTools Scene Routing and DebugOverlay Entry

**Files:**

- Create: `scenes/dev/DevToolsScreen.tscn`
- Modify: `scripts/app/scene_router.gd`
- Modify: `scripts/ui/debug_overlay.gd`
- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `docs/superpowers/plans/2026-04-29-dev-tools-foundation-card-browser.md`

- [x] **Step 1: Add failing smoke tests**

Modify `tests/smoke/test_scene_flow.gd`.

Add this preload near the other preloads:

```gdscript
const DevToolsScene := preload("res://scenes/dev/DevToolsScreen.tscn")
```

Append these tests before helper functions:

```gdscript
func test_debug_overlay_routes_to_dev_tools_screen(tree: SceneTree) -> bool:
	var app = _create_app_with_save_service(tree, "user://test_debug_dev_tools_save.json")
	var debug_overlay: Node = app.get_node_or_null("DebugLayer/DebugOverlay")
	var dev_tools_button := _find_node_by_name(debug_overlay, "DebugDevTools") as Button
	if dev_tools_button != null:
		dev_tools_button.pressed.emit()
	var current_scene := app.game.router.current_scene
	var passed: bool = dev_tools_button != null \
		and current_scene != null \
		and current_scene.name == "DevToolsScreen"
	app.free()
	_delete_test_save("user://test_debug_dev_tools_save.json")
	return passed

func test_dev_tools_screen_starts_on_card_browser_and_selects_strike(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	screen.set_filters("sword", "common", "attack")
	screen.select_card("sword.strike")
	var panel := _find_node_by_name(screen, "CardBrowserPanel")
	var detail := _find_node_by_name(screen, "CardDetailLabel") as Label
	var passed: bool = screen.active_tool_id == "card_browser" \
		and panel != null \
		and detail != null \
		and detail.text.contains("id: sword.strike")
	screen.free()
	return passed

func test_dev_tools_deferred_tool_button_shows_planned_placeholder(tree: SceneTree) -> bool:
	var screen := DevToolsScene.instantiate()
	tree.root.add_child(screen)
	var button := _find_node_by_name(screen, "ToolButton_enemy_sandbox") as Button
	if button != null:
		button.pressed.emit()
	var placeholder := _find_node_by_name(screen, "ToolPlaceholder_enemy_sandbox") as Label
	var passed: bool = button != null \
		and screen.active_tool_id == "enemy_sandbox" \
		and placeholder != null \
		and placeholder.text.contains("Planned tool")
	screen.free()
	return passed
```

- [x] **Step 2: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: FAIL because `DevToolsScreen.tscn`, `SceneRouter.DEV_TOOLS`, or `DebugDevTools` does not exist yet.

- [x] **Step 3: Add DevTools scene**

Create `scenes/dev/DevToolsScreen.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/dev_tools_screen.gd" id="1_devtools"]

[node name="DevToolsScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_devtools")
```

- [x] **Step 4: Add route constant**

Modify `scripts/app/scene_router.gd`.

Add after `const SUMMARY`:

```gdscript
const DEV_TOOLS := "res://scenes/dev/DevToolsScreen.tscn"
```

- [x] **Step 5: Add DebugOverlay route button**

Modify `scripts/ui/debug_overlay.gd`.

Add after the Map button:

```gdscript
	var dev_tools := Button.new()
	dev_tools.name = "DebugDevTools"
	dev_tools.text = "Debug: Dev Tools"
	dev_tools.pressed.connect(_go_dev_tools)
	box.add_child(dev_tools)
```

Add this helper after `_go_map()`:

```gdscript
func _go_dev_tools() -> void:
	var app := _get_app()
	if app == null:
		return
	app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
```

- [x] **Step 6: Run tests to verify GREEN for Task 2**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected: `TESTS PASSED`.

- [x] **Step 7: Run Task 2 review gates**

Stage 1 Spec Compliance Review:

- `SceneRouter.DEV_TOOLS` exists and points to the DevTools scene.
- `DebugOverlay` exposes `DebugDevTools`.
- Pressing the debug button routes to `DevToolsScreen`.
- DevTools starts on Card Browser.
- Selecting `sword.strike` updates detail text.
- Enemy Sandbox button shows an explicit planned placeholder.
- DevTools does not require an active run.

Stage 2 Code Quality Review:

- DebugOverlay routing follows existing safe app lookup patterns.
- Scene file is minimal and consistent with existing scene files.
- Smoke tests use stable node names.
- Deferred tool button behavior does not imply working functionality.

- [x] **Step 8: Commit Task 2**

Run:

```powershell
rtk proxy git add scenes/dev/DevToolsScreen.tscn scripts/app/scene_router.gd scripts/ui/debug_overlay.gd tests/smoke/test_scene_flow.gd docs/superpowers/plans/2026-04-29-dev-tools-foundation-card-browser.md
rtk proxy git commit -m "feat: route debug dev tools"
```

## Task 3: Final Acceptance, Documentation, and Reviews

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-04-29-dev-tools-foundation-card-browser.md`

- [x] **Step 1: Run full local tests**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Expected:

```text
TESTS PASSED
```

- [x] **Step 2: Run Godot import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [x] **Step 3: Verify DevTools has no persistence/resource writes**

Run:

```powershell
rtk proxy rg -n "save_run|delete_save|FileAccess.open|ResourceSaver|store_|current_run\\s*=|deck_ids\\.|gold \\+=" scripts/ui/dev_tools_screen.gd
```

Expected: no output.

- [x] **Step 4: Update README Phase 2 progress**

Modify `README.md`.

Append under `## Phase 2 Progress`:

```markdown
- Developer tools foundation: complete; debug builds now include a DevTools hub with stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector, plus a read-only Card Browser for filtering and inspecting catalog cards, effects, and presentation cues.
```

Update `## Next Plans` to:

```markdown
## Next Plans

1. Developer tools: enemy sandbox, event tester, reward inspector, and save inspector.
2. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
3. Presentation expansion: more per-card cue ids, enemy intent polish, card art, richer combat backgrounds, and formal audio mixing.
```

- [x] **Step 5: Mark completed plan steps**

Update completed checkboxes in this plan from `[ ]` to `[x]` after verifying implementation and reviews.

- [x] **Step 6: Run final two-stage review**

Stage 1 Spec Compliance Review:

- `SceneRouter.DEV_TOOLS` exists.
- `DebugOverlay` exposes `DebugDevTools`.
- `DevToolsScreen` has stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector.
- Card Browser loads default catalog cards.
- Filters exist for character, rarity, and card type.
- Filters combine with AND semantics.
- Card details include card fields, effects, and presentation cues.
- Deferred tools are explicit placeholders.
- DevTools does not mutate run state, saves, or resources.

Stage 2 Code Quality Review:

- GDScript typing is clear for DevTools fields and helpers.
- Filter/detail helper code is deterministic and testable.
- Node names are stable for tests.
- DebugOverlay routing follows existing safe app lookup patterns.
- DevTools does not duplicate catalog loading constants.
- Tests do not depend on translated UI copy or fragile visual layout.

Classify findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

- [x] **Step 7: Commit final acceptance docs**

Run:

```powershell
rtk proxy git add README.md docs/superpowers/plans/2026-04-29-dev-tools-foundation-card-browser.md
rtk proxy git commit -m "docs: record dev tools foundation acceptance"
```

## Final Acceptance Criteria

- DevTools is reachable from DebugOverlay in debug builds.
- DevTools presents stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector.
- Card Browser is fully usable as a read-only catalog inspection tool.
- Card filters work by character, rarity, and type.
- Card detail inspection includes effects and presentation cues.
- Deferred tools clearly show planned placeholders.
- No run state, save data, or resource files are mutated by DevTools.
- Existing local tests pass.
- Godot import check exits 0.
