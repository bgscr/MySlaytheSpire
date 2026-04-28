# MySlaytheSpire

东方玄幻 2D 卡牌构筑肉鸽 Windows 客户端。

## Engine

- Godot 4.6.2-stable
- GDScript
- Windows first, Win11 primary

## Local Commands

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
& $env:GODOT4 --headless --path . --script res://scripts/testing/test_runner.gd
```

## Phase 1 Status

- Godot project skeleton: complete
- Seeded run map: complete
- Minimal combat engine: complete
- Save/continue: complete
- Sample scene flow: complete
- Debug overlay: complete
- Local tests: complete (`TESTS PASSED`)
- Import check: complete; Godot exits 0 with no exit-time ObjectDB/resource cleanup warnings
- Manual editor smoke: complete
- Windows export preset: complete; `export/MySlaytheSpire.exe` generated after installing Godot 4.6.2 Windows export templates

## Phase 2 Progress

- Content capacity foundation: complete
- Content catalog: complete
- Reward generator: complete
- Encounter generator: complete
- Resource consistency tests: complete
- Minimal extended combat effects: complete
- Dual starter card pools: complete; sword and alchemy each have 9 catalog cards
- Multi-enemy encounter foundation: complete; combat, elite, and boss nodes now generate deterministic primary/support enemy groups
- Combat session targeting loop: complete; map encounters now create multi-enemy combat sessions with real hand, energy, target selection, enemy turns, and win/loss routing
- Content expansion wave 1: complete; sword and alchemy each have 15 cards, default encounters have 4 normal / 3 elite / 2 boss enemies, and relic rewards draw from 6 registered relics
- Relic trigger runtime: complete; owned relics now react to combat start, player turn start, and combat win events through an event-shaped runtime
- Reward claim loop: complete; combat rewards now generate card, gold, and relic choices that can be claimed or skipped before map advancement
- Event node foundation: complete; map event nodes now resolve data-driven events with selectable HP/gold options, save, and advance run progress
- Shop node foundation: complete; map shop nodes now offer transaction-saved cards, relics, healing, removal, and one paid refresh before map advancement
- Content expansion wave 2: complete; poison, sword focus, and broken stance now have combat behavior, sword and alchemy each have 20 cards, default content has 12 enemies, 12 relics, and 6 events.
- Content expansion wave C: complete; events can grant cards, relics, card removal, and pending reward choices, enemies can use status intents, combat shows compact status names, and default content has 16 enemies, 20 relics, and 12 events.
- High-presentation foundation: complete; combat now routes feedback through a presentation event queue, supports mouse drag play with click fallback, and shows programmatic hover, target highlight, floating number, flash, and status pulse feedback.

## Next Plans

1. High-presentation polish: generated assets, sword-qi trails, medicine mist, camera impulse, slow motion, particles, and audio cues.
2. Developer tools: card browser, enemy sandbox, event tester, reward inspector, save inspector.
3. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
