# Steam Adapter Boundary

No Steam SDK is integrated in this foundation.

Future Steam work should implement the existing platform abstraction instead of adding Steam calls to gameplay, UI, save, reward, event, combat, map, or DevTools code.

## Existing Boundary

- `scripts/platform/platform_service.gd`
- `scripts/platform/local_platform_service.gd`

Current platform capabilities:

- `unlock_achievement(achievement_id: String)`
- `set_stat(stat_id: String, value: int)`
- `get_platform_language() -> String`

## Future Steam Implementation Rules

- Add a Steam-specific implementation of `PlatformService`.
- Keep SDK initialization, callback polling, and shutdown in platform/app setup code.
- Add local fallback behavior for every new platform method before wiring Steam.
- Add tests for the platform interface before using new capabilities in gameplay.
- Keep Steam depot upload and release publishing in release tooling, not gameplay code.

## Explicit Non-Goals For This Foundation

- No Steamworks binary dependency.
- No Steam API calls.
- No depot upload.
- No achievements beyond the existing abstract method.
- No leaderboard or cloud save implementation.
