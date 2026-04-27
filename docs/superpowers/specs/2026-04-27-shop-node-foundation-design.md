# Shop Node Foundation Design

Date: 2026-04-27

## Goal

Build the first complete shop-node loop. When the player selects a `shop` map node, the game should route to a shop screen, show deterministic card, relic, heal, removal, and refresh offers, persist each transaction immediately, and only advance the map when the player leaves the shop.

This wave makes shop nodes real without adding art, animation, discounts, multi-currency economy, card upgrades, card transforms, or a standalone shop content database.

## Current Baseline

The project already has the pieces needed for a bounded shop implementation:

- `MapGenerator` creates `shop` nodes.
- `MapScreen` currently routes unsupported non-combat nodes to `RewardScreen`; `shop` should get its own route.
- `ContentCatalog` loads cards, relics, characters, enemies, events, and localization keys.
- `RewardGenerator` already has deterministic card, gold, and relic helper patterns that a shop resolver can mirror.
- `RunState` persists HP, gold, deck ids, relic ids, map nodes, current node id, completion, and failure.
- `SaveService` serializes and validates `RunState`.
- `RunProgression` advances the current map node for reward and event screens.
- `EventScreen` and `RewardScreen` provide the current pattern for dynamic UI, save boundaries, and route after completion.

The missing pieces are a shop save-state schema, deterministic shop stock generation, transaction validation and application, a shop scene, and a direct `shop` route.

## Product Rules

Each shop node has a deterministic stock generated from the run seed and map node id. The player can buy multiple items before leaving.

Each shop contains:

- 3 card offers from the current character card pool.
- 2 relic offers from the default relic pool, excluding relics the run already owns.
- 1 healing service.
- 1 card-removal service.
- 1 paid refresh action.

Purchases are optional. The player can leave the shop without buying anything.

Every successful transaction saves immediately. This prevents save/reload from undoing purchases or rerolling the shop. Leaving the shop is a separate action that advances the current map node, clears the shop state, saves, and routes to map or summary.

## Pricing

Use fixed prices in this wave so tests and early balance are stable:

| Offer | Price |
| --- | ---: |
| Common card | 40 gold |
| Uncommon card | 60 gold |
| Rare card | 85 gold |
| Common relic | 120 gold |
| Uncommon relic | 160 gold |
| Rare relic | 220 gold |
| Boss relic | 260 gold |
| Heal service | 45 gold |
| Remove service | 75 gold |
| Refresh | 35 gold |

Healing restores `max(8, floor(run.max_hp * 0.2))` HP and clamps to `run.max_hp`. The heal service is unavailable when the player is already at full HP.

Card removal removes exactly one selected card id from `run.deck_ids`. The remove service is unavailable when the deck has one or fewer cards.

## Save-State Schema

Add a `current_shop_state: Dictionary = {}` field to `RunState`.

`RunState.to_dict()` always writes the field. `SaveService.load_run()` should accept saves that do not contain it and default to `{}` so existing local saves remain loadable.

The dictionary shape is:

```gdscript
{
	"node_id": "node_3",
	"refresh_used": false,
	"offers": [
		{
			"id": "card_0",
			"type": "card",
			"item_id": "sword.flash_cut",
			"price": 40,
			"sold": false,
		},
		{
			"id": "relic_0",
			"type": "relic",
			"item_id": "jade_talisman",
			"price": 120,
			"sold": false,
		},
		{
			"id": "heal_0",
			"type": "heal",
			"item_id": "",
			"price": 45,
			"sold": false,
		},
		{
			"id": "remove_0",
			"type": "remove",
			"item_id": "",
			"price": 75,
			"sold": false,
		},
	]
}
```

The shop state is active only when `current_shop_state["node_id"] == run.current_node_id` and the current map node type is `shop`. If the state is missing or belongs to a different node, `ShopResolver` creates a fresh state for the current shop node.

When the player leaves the shop successfully, `current_shop_state` is reset to `{}`.

## ShopResolver

Add `scripts/shop/shop_resolver.gd`.

Responsibilities:

- Confirm the current map node exists and has `node_type == "shop"`.
- Resume `run.current_shop_state` when it matches the current shop node.
- Generate a fresh deterministic shop state when no matching state exists.
- Use `RngService.new(run.seed_value).fork("shop:%s" % node.id)` for initial stock.
- Use `RngService.new(run.seed_value).fork("shop:refresh:%s" % node.id)` for refresh stock.
- Price cards by rarity and relics by tier.
- Exclude already-owned relic ids from generated relic offers.
- Avoid duplicate active card offers and duplicate active relic offers.

Card offers can include cards already present in the deck. This keeps the first shop simple and matches roguelike shop expectations where buying another copy is valid.

If the relic pool has fewer than two eligible relics, generate as many relic offers as possible. Do not create placeholder relic offers with empty ids.

## ShopRunner

Add `scripts/shop/shop_runner.gd`.

Responsibilities:

- Check offer availability.
- Apply a card purchase by subtracting gold, adding the card id to `run.deck_ids`, and marking the offer sold.
- Apply a relic purchase by subtracting gold, adding the relic id to `run.relic_ids`, and marking the offer sold.
- Apply healing by subtracting gold, increasing `run.current_hp`, clamping to max HP, and marking the offer sold.
- Apply card removal by subtracting gold, removing one selected card id from `run.deck_ids`, and marking the offer sold.
- Apply refresh by subtracting gold, setting `refresh_used = true`, and rerolling only unsold card and relic offers.

The runner returns `false` without mutation if:

- The shop state is missing or does not match the current node.
- The offer id is missing.
- The offer is already sold.
- The run does not have enough gold.
- The item id is empty for a card or relic purchase.
- The relic is already owned.
- Healing is requested at full HP.
- Removal is requested with a deck size of one or fewer.
- Removal is requested for a card id that is not in the deck.
- Refresh is already used.

The runner does not save and does not route scenes. `ShopScreen` owns save calls after successful transactions.

## Refresh Behavior

Each shop allows one paid refresh.

Refresh rerolls unsold card and relic offers only. Sold offers remain sold and visible as sold out. Heal and removal services do not refresh.

The refresh result should be deterministic for the same run seed, node id, current sold offers, and current owned relics. Refreshed active card offers must not duplicate each other. Refreshed active relic offers must not duplicate each other or any already-owned relic.

## ShopScreen

Add `scenes/shop/ShopScreen.tscn` and `scripts/ui/shop_screen.gd`.

Responsibilities:

- Load `ContentCatalog`.
- Resolve or create the current shop state through `ShopResolver`.
- If a fresh shop state was created, assign it to `run.current_shop_state` and save once so closing the game after entering the shop resumes the same stock.
- Render stable node names for smoke tests:
  - `ShopGoldLabel`
  - `ShopOfferContainer`
  - `ShopOffer_<offer_id>`
  - `BuyOffer_<offer_id>`
  - `RefreshButton`
  - `LeaveShopButton`
  - `RemoveCard_<index>`
- Show card/relic labels using existing ids and metadata, not art.
- Disable unavailable purchase buttons while keeping them visible.
- Show sold offers as sold out.
- For the removal service, show deck card buttons only after the remove offer is selected.
- After each successful transaction:
  - Save the run immediately.
  - Re-render the shop.
- On leave:
  - Guard against double-clicks.
  - Advance the current node through `RunProgression`.
  - Clear `run.current_shop_state`.
  - Save the run.
  - Route to `SceneRouter.MAP`, or `SceneRouter.SUMMARY` if the run is completed.

If no valid shop can be resolved, show a fallback message and a leave button that advances the node. Catalog validation and tests should still treat missing content as an error.

## Routing And Continue

Extend `SceneRouter`:

```gdscript
const SHOP := "res://scenes/shop/ShopScreen.tscn"
```

Update `MapScreen._enter_node(...)`:

- `combat`, `elite`, and `boss` route to combat.
- `event` routes to event.
- `shop` routes to shop.
- Unknown node types keep the existing safe fallback to reward.

Update continue behavior so an in-progress shop resumes correctly:

- If a loaded run has a non-empty `current_shop_state` whose `node_id` is the current node and that node is a `shop`, route directly to `SceneRouter.SHOP`.
- Otherwise continue to `SceneRouter.MAP`.

## Data Flow

```text
MapScreen enters shop node
  -> SceneRouter.SHOP
  -> ShopScreen loads ContentCatalog
  -> ShopResolver resumes or creates current_shop_state
  -> ShopScreen renders offers and services
  -> Player buys, removes, heals, or refreshes
  -> ShopRunner mutates RunState and shop state
  -> ShopScreen saves immediately and re-renders
  -> Player leaves shop
  -> RunProgression advances current node
  -> current_shop_state clears
  -> SaveService saves run
  -> SceneRouter routes to map or summary
```

## Testing Strategy

Add unit tests:

- `RunState.to_dict()` includes `current_shop_state`.
- `SaveService` round-trips `current_shop_state`.
- `SaveService` accepts older saves without `current_shop_state` and defaults to `{}`.
- `SaveService` rejects invalid `current_shop_state` types.
- `ShopResolver` returns deterministic stock for the same seed and node id.
- `ShopResolver` returns an empty state or `null` for non-shop nodes and missing current nodes.
- `ShopResolver` resumes matching saved shop state.
- `ShopResolver` generates 3 card offers, up to 2 relic offers, heal, and remove offers.
- `ShopRunner` buys card and relic offers, subtracts gold, and marks offers sold.
- `ShopRunner` rejects insufficient-gold and sold-out purchases without mutation.
- `ShopRunner` heals with clamping and rejects full-HP healing.
- `ShopRunner` removes one selected card and rejects missing cards.
- `ShopRunner` refreshes once, subtracts gold, preserves sold offers, and rejects a second refresh.
- `ShopRunner` rejects relic purchases for already-owned relic ids.

Add smoke tests:

- A `shop` map node routes to `ShopScreen`.
- Entering a shop creates and saves deterministic `current_shop_state`.
- Buying a card saves immediately and persists after reloading.
- Buying a relic saves immediately and persists after reloading.
- Heal and removal services become sold out after use.
- Refresh can be used once and then becomes disabled.
- Continue from the main menu resumes an in-progress shop.
- Leaving the shop clears `current_shop_state`, marks the shop node visited, unlocks the next node or completes the run, saves, and routes correctly.

Run full verification:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/testing/test_runner.gd"
```

Run import check:

```powershell
rtk proxy powershell -NoProfile -Command "& 'C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit"
```

## Review Gates

Stage 1: Spec Compliance Review

- Confirm shop nodes route to `ShopScreen`.
- Confirm shop stock is deterministic by run seed and node id.
- Confirm shop state is saved on entry and after every successful transaction.
- Confirm card, relic, heal, removal, and refresh interactions exist.
- Confirm refresh is paid, one-use, and affects only unsold card/relic offers.
- Confirm sold-out offers persist across save/load.
- Confirm leaving the shop advances through `RunProgression`, clears shop state, saves, and routes correctly.
- Confirm continue resumes an in-progress shop.
- Confirm no art, animation, discounts, multi-currency economy, card upgrades, or card transforms are added.

Stage 2: Code Quality Review

- Check shop rules live in resolver/runner code, not UI callbacks.
- Check GDScript functions and variables are typed where practical.
- Check save validation is explicit and backward compatible for older saves without shop state.
- Check transaction methods avoid partial mutation on failure.
- Check UI node names are stable for smoke tests.
- Check map advancement logic is not duplicated.
- Classify found issues as Critical, Important, or Minor.

## Acceptance Criteria

- `shop` nodes enter `ShopScreen`.
- Shops show deterministic card, relic, heal, removal, and refresh options.
- Card offers come from the current character pool.
- Relic offers exclude already-owned relics.
- Prices follow the fixed table in this spec.
- Unaffordable, sold-out, invalid, full-HP heal, and impossible-removal actions are disabled or rejected without mutation.
- Successful card purchase adds exactly that card id to the deck.
- Successful relic purchase adds exactly that relic id to owned relics.
- Successful healing clamps current HP to max HP.
- Successful removal removes exactly one selected card id from the deck.
- Successful refresh costs gold, can happen once, rerolls only unsold card/relic offers, and preserves service offers.
- Entering a shop and each successful transaction saves `current_shop_state`.
- Save/load preserves sold-out state, refresh state, deck, relics, HP, and gold.
- Continue from main menu resumes an in-progress shop.
- Leaving the shop clears `current_shop_state`, advances map progress, saves, and routes to map or summary.
- Reward and event flows still advance correctly.
- Godot tests pass.
- Godot import check exits 0.

## Out Of Scope

- Shop art, shopkeeper UI, audio, VFX, animation, and camera work.
- Discounts, coupons, memberships, dynamic pricing, or ascension modifiers.
- Multiple refreshes.
- Card upgrades, card transforms, card duplication, or card reward packages in shops.
- A dedicated shop content `.tres` database.
- Mid-shop route history beyond `current_shop_state`.
- Any change to combat reward generation.

## Follow-Up Work

- Presentation pass for a richer shop layout and item art.
- Price tuning after more playtesting.
- Shop-specific relics or discounts.
- Upgrade, transform, and duplication services.
- Developer tool for inspecting deterministic shop inventory by seed and node id.
