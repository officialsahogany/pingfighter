# Copilot Instructions for 환격전

- **환격전** is the current product name. Its English title is undecided; do
  not invent one. Read `AGENTS.md` for the shared repository contract, and
  preserve `pingfighter`, `DiskHearts`, `Ringpia` / `Lingpia`, package IDs,
  save keys, resource paths, and export filenames as compatibility identifiers.

- Treat `godot/` as the live implementation target. The legacy Python/Pygame
  code is frozen reference material unless the task explicitly asks for a
  legacy edit.
- For Godot gameplay, UI, VFX, audio, item, character, boss, save-data, menu,
  or runtime changes, prefer the existing module owners under `godot/scripts/`
  and keep `godot/scenes/main.gd` as orchestration glue.
- For user-visible Godot UI text, use Korean by default and check existing
  localization/reference text before adding new copy.
- After any `.gd` edit, run `godot/tools/run_headless_load_check.ps1` and
  `godot/tools/run_warning_scan.ps1`. Run focused smoke tests for the touched
  runtime surface.
- Treat performance lifecycle as part of feature work. Avoid expensive texture,
  image, JSON, scene-scan, or cache-building work in `_draw()` / `_process()`
  and first visible battle-frame paths unless it is measured and accepted.
- Route runtime texture loads through the project resource loader helpers
  instead of deciding export-build availability with raw `FileAccess.file_exists`
  checks alone.
- For looped gameplay audio or detached VFX hosts, verify round-boundary and
  reset cleanup paths as part of the fix.
