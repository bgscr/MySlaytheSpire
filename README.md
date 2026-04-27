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

## Next Plans

1. Content expansion: two characters, card pools, relics, enemies, bosses, event pool.
2. High-presentation pass: generated assets, animation, particles, camera, audio.
3. Developer tools: card browser, enemy sandbox, event tester, reward inspector, save inspector.
4. Release readiness: CI, artifact export, changelog, release draft, Steam adapter.
