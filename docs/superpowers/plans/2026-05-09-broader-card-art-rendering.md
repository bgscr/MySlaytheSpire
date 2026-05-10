# Broader Card Art Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render existing catalog-backed card art previews on reward, shop, event, and existing deck-list surfaces without changing gameplay.

**Architecture:** Add a small UI-only `CardVisualPresenter` helper that creates stable frame, thumbnail, and text children for a card id using `CombatVisualResolver`. Reward, shop, and event screens call this helper from their existing render methods while keeping existing buttons as the interaction targets. Existing debug/dev/save deck summaries remain text-only because they currently expose decks through labels, not row containers.

**Tech Stack:** Godot 4.6.2-stable, GDScript, existing `ContentCatalog`, existing `CombatVisualResolver`, project-owned card thumbnail assets, lightweight Godot test runner, PowerShell CI wrapper, RTK command proxy.

---

## Project Constraints

- Work directly on `main` unless the user explicitly asks for a worktree.
- Prefix shell commands with `rtk`.
- Use red/green TDD for behavior changes.
- Make surgical changes only. Do not reformat unrelated code.
- Do not change reward generation, reward application, shop transactions, event resolution, event application, map progression, save data, combat rules, release tooling, card resources, or visual resources.
- Do not create a new deck browser, deck modal, navigation path, card art pipeline, or combat card rendering refactor.
- After implementation, run the two-stage review from `AGENTS.md`.

## Reference Spec

- `docs/superpowers/specs/2026-05-09-broader-card-art-rendering-design.md`

## Verification Commands

Run shared Godot checks:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected final result:

```text
TESTS PASSED
Godot checks passed.
```

The known malformed status intent test emits a Godot `ERROR` log intentionally. Treat the process exit code and `TESTS PASSED` line as the test result.

Run direct import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

## File Structure

Create:

- `scripts/ui/card_visual_presenter.gd`: UI-only helper that renders a compact card visual preview into a supplied parent control.

Modify:

- `tests/unit/test_combat_visuals.gd`: helper tests for node creation, fallback behavior, mouse filtering, and duplicate suffixes.
- `scripts/ui/reward_screen.gd`: render card previews for reward card choices.
- `scripts/ui/shop_screen.gd`: render card previews for card offers and card-removal choices.
- `scripts/ui/event_screen.gd`: render card previews for direct card grant/remove event options.
- `tests/smoke/test_scene_flow.gd`: smoke coverage for reward, shop, removal, event, and pending-event reward previews while preserving existing behavior.
- `README.md`: accepted progress and updated Next Plans.
- `docs/superpowers/plans/2026-05-09-broader-card-art-rendering.md`: mark steps complete while executing.

Do not modify:

- `scripts/combat/*`
- `scripts/reward/*`
- `scripts/shop/shop_runner.gd`
- `scripts/shop/shop_resolver.gd`
- `scripts/event/event_runner.gd`
- `scripts/event/event_resolver.gd`
- `scripts/save/*`
- `scripts/run/*`
- `scripts/content/*`
- `resources/cards/**`
- `resources/visuals/card_visuals/**`
- `assets/presentation/card_thumbnails/**`
- `localization/zh_CN.po`

## Task 1: Card Visual Presenter Helper

**Files:**

- Modify: `tests/unit/test_combat_visuals.gd`
- Create: `scripts/ui/card_visual_presenter.gd`

- [x] **Step 1: Add failing helper preload**

Add this preload near the top of `tests/unit/test_combat_visuals.gd`, after the existing `CombatVisualResolver` preload:

```gdscript
const CardVisualPresenter := preload("res://scripts/ui/card_visual_presenter.gd")
```

- [x] **Step 2: Add failing helper tests**

Add these tests after `test_resolver_falls_back_for_missing_visual_data()` in `tests/unit/test_combat_visuals.gd`:

```gdscript
func test_card_visual_presenter_creates_known_card_preview() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var theme := resolver.resolve_theme("sword", catalog)
	var parent := VBoxContainer.new()
	var root := CardVisualPresenter.add_card_preview(parent, "RewardCard", "0_0", "sword.strike", catalog, theme)
	var frame := parent.get_node_or_null("RewardCardVisual_0_0/RewardCardFrame_0_0") as ColorRect
	var thumbnail := parent.get_node_or_null("RewardCardVisual_0_0/RewardCardThumbnail_0_0") as TextureRect
	var text := parent.get_node_or_null("RewardCardVisual_0_0/RewardCardText_0_0") as Label
	var passed: bool = root != null \
		and root.name == "RewardCardVisual_0_0" \
		and root.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and frame != null \
		and frame.color.a > 0.0 \
		and frame.get_meta("frame_style") == "sword" \
		and thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and thumbnail.get_meta("card_id") == "sword.strike" \
		and thumbnail.get_meta("element_tag") == "blade" \
		and text != null \
		and text.text.contains("sword.strike") \
		and text.text.contains("attack")
	parent.free()
	assert(passed)
	return passed

func test_card_visual_presenter_falls_back_for_missing_card() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var parent := VBoxContainer.new()
	CardVisualPresenter.add_card_preview(parent, "RewardCard", "missing", "missing.card", catalog)
	var thumbnail := parent.get_node_or_null("RewardCardVisual_missing/RewardCardThumbnail_missing") as TextureRect
	var text := parent.get_node_or_null("RewardCardVisual_missing/RewardCardText_missing") as Label
	var passed: bool = thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.get_meta("card_id") == "missing.card" \
		and thumbnail.get_meta("is_known") == false \
		and text != null \
		and text.text == "missing.card (?)"
	parent.free()
	assert(passed)
	return passed

func test_card_visual_presenter_uses_distinct_suffixes_for_duplicate_cards() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var parent := VBoxContainer.new()
	CardVisualPresenter.add_card_preview(parent, "ShopRemoveCard", "0", "sword.strike", catalog)
	CardVisualPresenter.add_card_preview(parent, "ShopRemoveCard", "1", "sword.strike", catalog)
	var first := parent.get_node_or_null("ShopRemoveCardVisual_0/ShopRemoveCardThumbnail_0") as TextureRect
	var second := parent.get_node_or_null("ShopRemoveCardVisual_1/ShopRemoveCardThumbnail_1") as TextureRect
	var passed: bool = first != null \
		and second != null \
		and first != second \
		and first.get_meta("card_id") == "sword.strike" \
		and second.get_meta("card_id") == "sword.strike"
	parent.free()
	assert(passed)
	return passed
```

- [x] **Step 3: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: `TESTS FAILED` or import errors because `res://scripts/ui/card_visual_presenter.gd` does not exist.

- [x] **Step 4: Create the card visual presenter helper**

Create `scripts/ui/card_visual_presenter.gd`:

```gdscript
class_name CardVisualPresenter
extends RefCounted

const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")

static func add_card_preview(
	parent: Control,
	prefix: String,
	suffix: String,
	card_id: String,
	catalog: Object,
	theme: Dictionary = {}
) -> Control:
	var resolver := CombatVisualResolver.new()
	var visual := resolver.resolve_card_visual(card_id, catalog, theme)
	var root := VBoxContainer.new()
	root.name = "%sVisual_%s" % [prefix, suffix]
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(132, 86)
	parent.add_child(root)

	var frame := ColorRect.new()
	frame.name = "%sFrame_%s" % [prefix, suffix]
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(120, 5)
	frame.color = visual.get("accent_color", Color.WHITE)
	frame.set_meta("frame_style", String(visual.get("frame_style", "")))
	root.add_child(frame)

	var thumbnail := TextureRect.new()
	thumbnail.name = "%sThumbnail_%s" % [prefix, suffix]
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.custom_minimum_size = Vector2(120, 52)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path := String(visual.get("thumbnail_path", ""))
	thumbnail.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	thumbnail.set_meta("card_id", String(visual.get("card_id", card_id)))
	thumbnail.set_meta("element_tag", String(visual.get("element_tag", "")))
	thumbnail.set_meta("is_known", bool(visual.get("is_known", false)))
	root.add_child(thumbnail)

	var label := Label.new()
	label.name = "%sText_%s" % [prefix, suffix]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _card_text(card_id, catalog)
	root.add_child(label)

	return root

static func _card_text(card_id: String, catalog: Object) -> String:
	var card = null
	if catalog != null and catalog.has_method("get_card"):
		card = catalog.get_card(card_id)
	if card == null:
		return "%s (?)" % card_id
	return "%s [%s] (%s)" % [card.id, card.card_type, card.cost]
```

- [x] **Step 5: Run tests to verify GREEN for helper**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [x] **Step 6: Commit helper**

Run:

```powershell
rtk git add tests/unit/test_combat_visuals.gd scripts/ui/card_visual_presenter.gd docs/superpowers/plans/2026-05-09-broader-card-art-rendering.md
rtk git commit -m "feat: add card visual presenter"
```

## Task 2: Reward Card Choice Previews

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/ui/reward_screen.gd`

- [x] **Step 1: Add failing reward preview assertions**

In `test_reward_screen_claims_card_skips_gold_and_saves_on_continue()` in `tests/smoke/test_scene_flow.gd`, add these locals after `card_button`:

```gdscript
	var preview := _find_node_by_name(reward_screen, "RewardCardVisual_0_0") as VBoxContainer
	var thumbnail := _find_node_by_name(reward_screen, "RewardCardThumbnail_0_0") as TextureRect
	var preview_text := _find_node_by_name(reward_screen, "RewardCardText_0_0") as Label
```

Update the final `passed` expression to include these checks immediately after `deck_claimed`:

```gdscript
		and preview != null \
		and preview.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and preview_text != null \
		and preview_text.text.contains("sword.") \
```

The full `passed` block should become:

```gdscript
	var passed: bool = disabled_before \
		and deck_claimed \
		and preview != null \
		and preview.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and preview_text != null \
		and preview_text.text.contains("sword.") \
		and still_disabled_after_card \
		and enabled_after_all_resolved \
		and disabled_after_continue \
		and run.gold == gold_before \
		and loaded_run != null \
		and loaded_run.deck_ids.size() == run.deck_ids.size() \
		and loaded_run.gold == gold_before \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and routed_scene != reward_screen \
		and app.game.router.current_scene == routed_scene
```

- [x] **Step 2: Add failing pending event reward preview assertions**

In `test_reward_screen_claims_pending_event_reward_then_advances_event()`, add these locals after `claim_card`:

```gdscript
	var preview := _find_node_by_name(reward_screen, "RewardCardVisual_0_0") as VBoxContainer
	var thumbnail := _find_node_by_name(reward_screen, "RewardCardThumbnail_0_0") as TextureRect
```

Update the final `passed` expression to include:

```gdscript
		and preview != null \
		and thumbnail != null \
		and thumbnail.texture != null \
```

The full block should become:

```gdscript
	var passed: bool = claim_card != null \
		and preview != null \
		and thumbnail != null \
		and thumbnail.texture != null \
		and continue_button != null \
		and loaded_run != null \
		and loaded_run.current_reward_state.is_empty() \
		and loaded_run.deck_ids.has("sword.flash_cut") \
		and loaded_run.map_nodes[0].visited \
		and loaded_run.map_nodes[1].unlocked \
		and app.game.router.current_scene != reward_screen
```

- [x] **Step 3: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: `TESTS FAILED` because reward previews are not rendered yet.

- [x] **Step 4: Add presenter preload to reward screen**

Add this preload to `scripts/ui/reward_screen.gd` near the other preloads:

```gdscript
const CardVisualPresenter := preload("res://scripts/ui/card_visual_presenter.gd")
const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
```

- [x] **Step 5: Render card previews inside reward card buttons**

In `_add_reward_actions()` in `scripts/ui/reward_screen.gd`, replace the `"card_choice"` button creation block:

```gdscript
				var button := Button.new()
				button.name = "ClaimCard_%s_%s" % [reward_index, card_index]
				button.text = "Take %s" % _card_text(card_id)
				button.pressed.connect(func(): _claim_card(reward_index, card_index))
				item.add_child(button)
```

with:

```gdscript
				var button := Button.new()
				button.name = "ClaimCard_%s_%s" % [reward_index, card_index]
				button.text = ""
				button.pressed.connect(func(): _claim_card(reward_index, card_index))
				var theme := _visual_theme()
				CardVisualPresenter.add_card_preview(
					button,
					"RewardCard",
					"%s_%s" % [reward_index, card_index],
					card_id,
					catalog,
					theme
				)
				item.add_child(button)
```

Add this helper after `_relic_text()`:

```gdscript
func _visual_theme() -> Dictionary:
	var app = _app()
	if app == null or app.game.current_run == null or catalog == null:
		return {}
	return CombatVisualResolver.new().resolve_theme(app.game.current_run.character_id, catalog)
```

- [x] **Step 6: Run tests to verify GREEN for rewards**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [x] **Step 7: Commit reward previews**

Run:

```powershell
rtk git add tests/smoke/test_scene_flow.gd scripts/ui/reward_screen.gd docs/superpowers/plans/2026-05-09-broader-card-art-rendering.md
rtk git commit -m "feat: render reward card previews"
```

## Task 3: Shop Offer And Remove Choice Previews

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/ui/shop_screen.gd`

- [x] **Step 1: Add failing shop offer preview assertions**

In `test_shop_screen_buy_card_saves_immediately()` in `tests/smoke/test_scene_flow.gd`, add these locals after `card_button`:

```gdscript
	var offer_preview := _find_node_by_name(shop_screen, "ShopOfferCardVisual_card_0") as VBoxContainer
	var offer_thumbnail := _find_node_by_name(shop_screen, "ShopOfferCardThumbnail_card_0") as TextureRect
```

Update the final `passed` expression to include:

```gdscript
		and offer_preview != null \
		and offer_preview.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and offer_thumbnail != null \
		and offer_thumbnail.texture != null \
```

The full block should become:

```gdscript
	var passed: bool = card_button != null \
		and offer_preview != null \
		and offer_preview.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and offer_thumbnail != null \
		and offer_thumbnail.texture != null \
		and loaded_run != null \
		and loaded_run.deck_ids.size() == deck_size_before + 1 \
		and not loaded_run.current_shop_state.is_empty() \
		and _has_sold_offer(loaded_run.current_shop_state, "card")
```

- [x] **Step 2: Add failing shop removal preview assertions**

In `test_shop_screen_remove_card_and_heal_services_sell_out()` in `tests/smoke/test_scene_flow.gd`, add these locals after `remove_card`:

```gdscript
	var remove_preview := _find_node_by_name(app.game.router.current_scene, "ShopRemoveCardVisual_0") as VBoxContainer
	var remove_thumbnail := _find_node_by_name(app.game.router.current_scene, "ShopRemoveCardThumbnail_0") as TextureRect
```

Update the final `passed` expression to include:

```gdscript
		and remove_preview != null \
		and remove_thumbnail != null \
		and remove_thumbnail.texture != null \
```

The full block should become:

```gdscript
	var passed: bool = loaded_run != null \
		and remove_preview != null \
		and remove_thumbnail != null \
		and remove_thumbnail.texture != null \
		and loaded_run.current_hp > 40 \
		and loaded_run.deck_ids.size() == 2 \
		and _offer_sold(loaded_run.current_shop_state, "heal_0") \
		and _offer_sold(loaded_run.current_shop_state, "remove_0")
```

- [x] **Step 3: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: `TESTS FAILED` because shop card previews are not rendered yet.

- [x] **Step 4: Add presenter preloads to shop screen**

Add these preloads to `scripts/ui/shop_screen.gd` near the other preloads:

```gdscript
const CardVisualPresenter := preload("res://scripts/ui/card_visual_presenter.gd")
const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
```

- [x] **Step 5: Render card previews for card offers**

In `_add_offer_row()` in `scripts/ui/shop_screen.gd`, after this block:

```gdscript
	var label := Label.new()
	label.text = _offer_label(offer)
	item.add_child(label)
```

add:

```gdscript
	if String(offer.get("type", "")) == "card":
		CardVisualPresenter.add_card_preview(
			item,
			"ShopOfferCard",
			offer_id,
			String(offer.get("item_id", "")),
			catalog,
			_visual_theme()
		)
```

- [x] **Step 6: Render card previews for remove choices**

In `_render_removal_choices()` in `scripts/ui/shop_screen.gd`, replace the remove card button block:

```gdscript
		var button := Button.new()
		button.name = "RemoveCard_%s" % i
		button.text = card_id
		button.pressed.connect(func(): _on_remove_card_pressed(card_id))
		removal_container.add_child(button)
```

with:

```gdscript
		var button := Button.new()
		button.name = "RemoveCard_%s" % i
		button.text = ""
		CardVisualPresenter.add_card_preview(
			button,
			"ShopRemoveCard",
			str(i),
			card_id,
			catalog,
			_visual_theme()
		)
		button.pressed.connect(func(): _on_remove_card_pressed(card_id))
		removal_container.add_child(button)
```

Add this helper after `_first_removable_card()`:

```gdscript
func _visual_theme() -> Dictionary:
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or catalog == null:
		return {}
	return CombatVisualResolver.new().resolve_theme(run.character_id, catalog)
```

- [x] **Step 7: Run tests to verify GREEN for shop**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [x] **Step 8: Commit shop previews**

Run:

```powershell
rtk git add tests/smoke/test_scene_flow.gd scripts/ui/shop_screen.gd docs/superpowers/plans/2026-05-09-broader-card-art-rendering.md
rtk git commit -m "feat: render shop card previews"
```

## Task 4: Event Direct Card Preview Rendering

**Files:**

- Modify: `tests/smoke/test_scene_flow.gd`
- Modify: `scripts/ui/event_screen.gd`

- [x] **Step 1: Add a helper that finds an event seed with direct card previews**

Add this helper near `_seed_for_event_with_unavailable_option()` in `tests/smoke/test_scene_flow.gd`:

```gdscript
func _seed_for_event_with_card_preview_option() -> int:
	var catalog := ContentCatalogScript.new()
	catalog.load_default()
	for seed_value in range(1, 200):
		var run := _reward_run("event", true)
		run.seed_value = seed_value
		var event = EventResolverScript.new().resolve(catalog, run)
		if event == null:
			continue
		for option in event.options:
			if not option.grant_card_ids.is_empty() or not option.remove_card_id.is_empty():
				return seed_value
	return 1
```

- [x] **Step 2: Add failing event preview test**

Add this smoke test after `test_event_screen_disables_unavailable_option()`:

```gdscript
func test_event_screen_renders_direct_card_option_previews(tree: SceneTree) -> bool:
	var save_path := "user://test_event_card_preview_save.json"
	var app = _create_app_with_save_service(tree, save_path)
	var run := _reward_run("event", true)
	run.seed_value = _seed_for_event_with_card_preview_option()
	run.current_hp = 40
	run.max_hp = 40
	run.gold = 50
	app.game.current_run = run
	var event_screen = app.game.router.go_to(SceneRouterScript.EVENT)
	var preview := _find_node_by_prefix(event_screen, "EventOptionCardVisual_") as VBoxContainer
	var thumbnail := _find_node_by_prefix(event_screen, "EventOptionCardThumbnail_") as TextureRect
	var option_button := _find_node_by_prefix(event_screen, "EventOption_") as Button
	var loaded_before = app.game.save_service.load_run()
	if option_button != null and not option_button.disabled:
		option_button.pressed.emit()
	var passed: bool = preview != null \
		and preview.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and thumbnail != null \
		and thumbnail.texture != null \
		and loaded_before == null \
		and app.game.router.current_scene != null
	app.free()
	_delete_test_save(save_path)
	return passed
```

- [x] **Step 3: Add prefix finder helper**

Add this helper after `_find_node_by_text()` in `tests/smoke/test_scene_flow.gd`:

```gdscript
func _find_node_by_prefix(root: Node, prefix: String) -> Node:
	if root == null:
		return null
	if root.name.begins_with(prefix):
		return root
	for child in root.get_children():
		var found := _find_node_by_prefix(child, prefix)
		if found != null:
			return found
	return null
```

- [x] **Step 4: Run tests to verify RED**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected: `TESTS FAILED` because event option card previews are not rendered yet.

- [x] **Step 5: Add presenter preloads to event screen**

Add these preloads to `scripts/ui/event_screen.gd` near the other preloads:

```gdscript
const CardVisualPresenter := preload("res://scripts/ui/card_visual_presenter.gd")
const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
```

- [x] **Step 6: Render direct card previews under event options**

In `_add_option_button(index: int)` in `scripts/ui/event_screen.gd`, after:

```gdscript
	option_container.add_child(button)
```

add:

```gdscript
	_add_option_card_previews(index)
```

Then add these helpers after `_add_option_button()`:

```gdscript
func _add_option_card_previews(index: int) -> void:
	if current_event == null or index < 0 or index >= current_event.options.size():
		return
	var option = current_event.options[index]
	var row := HBoxContainer.new()
	row.name = "EventOptionCardPreviewRow_%s" % index
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_count := 0
	for card_id in option.grant_card_ids:
		CardVisualPresenter.add_card_preview(
			row,
			"EventOptionCard",
			"%s_%s" % [index, preview_count],
			card_id,
			catalog,
			_visual_theme()
		)
		preview_count += 1
	if not option.remove_card_id.is_empty():
		CardVisualPresenter.add_card_preview(
			row,
			"EventOptionCard",
			"%s_%s" % [index, preview_count],
			option.remove_card_id,
			catalog,
			_visual_theme()
		)
		preview_count += 1
	if preview_count == 0:
		row.free()
		return
	option_container.add_child(row)

func _visual_theme() -> Dictionary:
	var app = _app()
	var run = app.game.current_run if app != null else null
	if run == null or catalog == null:
		return {}
	return CombatVisualResolver.new().resolve_theme(run.character_id, catalog)
```

- [x] **Step 7: Run tests to verify GREEN for events**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [x] **Step 8: Commit event previews**

Run:

```powershell
rtk git add tests/smoke/test_scene_flow.gd scripts/ui/event_screen.gd docs/superpowers/plans/2026-05-09-broader-card-art-rendering.md
rtk git commit -m "feat: render event card previews"
```

## Task 5: Deck Surface Boundary And Documentation

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-05-09-broader-card-art-rendering.md`

- [ ] **Step 1: Verify existing deck-list surfaces have no child-row deck container**

Run:

```powershell
rtk rg -n "DeckList|DeckContainer|DeckRow|deck row|deck_ids|deck:" scripts/ui scenes tests/smoke tests/unit
```

Expected: output includes existing `deck_ids` and text-summary references, but no existing player-facing `DeckList`, `DeckContainer`, or `DeckRow` container dedicated to deck entries. Do not add a deck browser or convert label-only summaries in this phase.

- [ ] **Step 2: Verify no disallowed logic imports**

Run:

```powershell
rtk rg -n "CardVisualPresenter|card_visual_presenter" scripts/combat scripts/reward scripts/shop/shop_runner.gd scripts/shop/shop_resolver.gd scripts/event/event_runner.gd scripts/event/event_resolver.gd scripts/save scripts/run scripts/content tools resources
```

Expected: no output. `rg` may exit 1 when there are no matches; that is acceptable.

- [ ] **Step 3: Verify no card resources or visual resources changed**

Run:

```powershell
rtk git diff --name-only HEAD -- resources/cards resources/visuals/card_visuals assets/presentation/card_thumbnails
```

Expected: no output.

- [ ] **Step 4: Update README progress**

Add this bullet under `## Phase 2 Progress` after the enemy art foundation bullet:

```markdown
- Broader card art rendering: complete; reward choices, shop card offers, shop removal choices, and direct card-grant/removal event options now render catalog-backed card previews outside combat.
```

Update `## Next Plans` to:

```markdown
## Next Plans

1. Presentation expansion: formal audio mixing and polished per-card art replacement.
2. Release expansion: artifact packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
```

- [ ] **Step 5: Run shared Godot checks**

Run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File tools/ci/run_godot_checks.ps1
```

Expected:

```text
TESTS PASSED
Godot checks passed.
```

- [ ] **Step 6: Run direct import check**

Run:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

Expected: process exits 0.

- [ ] **Step 7: Run final two-stage review**

Stage 1 Spec Compliance Review:

- Reward card choices render data-backed card previews.
- Shop card offers render data-backed card previews.
- Shop remove choices render data-backed card previews and preserve duplicate-card index behavior.
- Event direct grant/remove card options render data-backed previews.
- Pending event card rewards render on the reward screen.
- Current deck summaries remain text-only because they are label-only surfaces, and no deck browser/modal/navigation was added.
- No gameplay, save schema, content, card visual resource, combat, release, or localization changes were added.
- Reward, shop, event, save, and routing behavior remains unchanged.
- README progress and Next Plans match shipped scope.

If any item fails, fix it before continuing to Stage 2.

Stage 2 Code Quality Review:

- `CardVisualPresenter` is small, typed, UI-only, and focused.
- The helper uses existing `CombatVisualResolver` fallback behavior.
- Visual children use `mouse_filter = Control.MOUSE_FILTER_IGNORE`.
- Screen changes are scoped to rendering and stable node naming.
- Tests use real catalog resources and stable node names.
- No unrelated refactors or formatting churn were included.

Classify all findings as Critical, Important, or Minor. Fix Critical and Important issues before acceptance.

- [ ] **Step 8: Commit acceptance docs**

Run:

```powershell
rtk git add README.md docs/superpowers/plans/2026-05-09-broader-card-art-rendering.md
rtk git commit -m "docs: record broader card art rendering acceptance"
```

## Final Acceptance Criteria

- Reward card choices render card previews from catalog-backed visual data.
- Shop card offers render card previews from catalog-backed visual data.
- Shop card-removal choices render card previews while preserving indexed duplicate choices.
- Event options with direct card grant/remove effects render compact card previews.
- Pending event card rewards render through reward screen card previews.
- Existing label-only deck summaries remain text-only and no new deck navigation is added.
- Missing card or visual data falls back safely.
- Existing reward, shop, event, save, routing, and combat behavior remains unchanged.
- No new card resources, card visual resources, save schema, deck browser, or polished art pipeline is added.
- Shared Godot checks pass.
- Direct Godot import check exits 0.
