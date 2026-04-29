# MySlaytheSpire

东方玄幻 2D 卡牌构筑肉鸽 Windows 客户端。

## Engine

- Godot 4.6.2-stable
- GDScript
- Windows first, Win11 primary

## Local Commands

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
.\tools\ci\run_godot_checks.ps1
```

Run Windows export:

```powershell
$env:GODOT4="C:\Tools\Godot\Godot_v4.6.2-stable_win64_console.exe"
.\tools\release\export_windows.ps1
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
- High-presentation polish hooks: complete; successful card play can now emit explicit or inferred polish events for slash, particle, camera impulse, slow-motion, and audio-cue placeholders without coupling presentation to combat rules.
- High-presentation asset pass: complete; combat polish hooks now resolve project-owned texture/audio assets through a cue-id asset catalog for slash, mist, camera impulse, local slow-motion, and audio cue playback.
- Developer tools foundation: complete; debug builds now include a DevTools hub with stable entries for Card Browser, Enemy Sandbox, Event Tester, Reward Inspector, and Save Inspector, plus a read-only Card Browser for filtering and inspecting catalog cards, effects, and presentation cues.
- Enemy Sandbox: complete; DevTools can now choose a character, select one to three catalog enemies, preview the starter deck and enemy intents, and launch isolated sandbox combat without touching saves or the active run.
- Developer tools event tester: complete; DevTools can now apply catalog event options against an isolated test run without writing saves, routing away, or mutating the active run.
- Developer tools reward inspector: complete; DevTools can now preview generated reward packages and simulate card, gold, relic, and skip choices against an isolated run without touching saves or the active run.
- Developer tools save inspector: complete; DevTools can now diagnose save presence, validity, terminal state, map/shop/reward resume targets, and run state sections without writing, deleting, repairing, routing, or mutating the active run.
- Release readiness foundation: complete; local and CI Godot checks now share a PowerShell entry point, Windows export has a wrapper around the existing preset, release notes/checklists/templates are documented, and future Steam work is bounded behind `PlatformService`.
- Enemy intent presentation cues: complete; enemy attack, block, and status intents now route presentation-only polish cues through the existing queue and asset catalog, while shared Godot checks import assets before running tests in fresh worktrees.

## Next Plans

1. Presentation expansion: full card cue migration, intent icons, card art, richer combat backgrounds, reduced-motion profiles, and formal audio mixing.
2. Release expansion: artifact packaging, checksums, version bump automation, signed builds, and eventual Steam adapter implementation.
