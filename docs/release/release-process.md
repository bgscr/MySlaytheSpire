# Release Process

This project is Windows-first. Release automation starts with local checks and a Windows artifact wrapper, then can grow into signed builds, checksums, and store uploads.

## Local Quality Gate

Run the shared Godot check script before creating release artifacts:

```powershell
./tools/ci/run_godot_checks.ps1
```

This runs:

- `res://scripts/testing/test_runner.gd`
- Godot headless import/project load check

The known malformed status intent test may print an intentional Godot `ERROR` after `TESTS PASSED`.

## Windows Artifact

Build the Windows executable with:

```powershell
./tools/release/export_windows.ps1
```

The wrapper uses the existing Godot export preset:

- Preset: `Windows Desktop`
- Primary artifact: `export/MySlaytheSpire.exe`
- Artifact copy: `export/artifacts/MySlaytheSpire.exe`

If Godot export templates are missing, install Godot 4.6.2 Windows export templates and rerun the command.

## Release Draft

Use `docs/release/github-release-template.md` as the release body.

Before publishing a release:

1. Confirm the working tree is clean.
2. Run `./tools/ci/run_godot_checks.ps1`.
3. Run `./tools/release/export_windows.ps1`.
4. Attach the artifact from `export/artifacts/`.
5. Copy changelog entries from `CHANGELOG.md`.
6. Record known issues and follow-up work.

## Future Extensions

- Zip Windows artifacts.
- Generate checksums.
- Add version bump automation.
- Add signed builds.
- Add release upload automation after token handling is designed.
- Add Linux, macOS, or Steam Deck presets.
- Add Steam depot upload after the Steam adapter implementation exists.
