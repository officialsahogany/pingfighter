# DiskHearts - Lingpia

This repository now develops the repo-local Godot project **디스크하츠 - 링피아**.

The original Python/Pygame **PingFighter** codebase is frozen. Keep it only as
a behavior, timing, balance, text, and asset reference when porting features
into Godot. Do not edit `pingfighter.py` or the old Python runtime unless a
task explicitly asks for original PingFighter source work.

## Current Project

- Live project: `godot/project.godot`
- Main implementation tree: `godot/scripts/`
- Runtime assets: `godot/assets/`
- Current routing guide: `AGENTS.md`
- Hidden-knowledge / asset workflow guide: `CLAUDE.md`
- Godot architecture map: `docs/godot_port_architecture.md`
- Godot module ownership ledger: `docs/godot_module_ownership_ledger.md`
- Godot port checklist: `docs/godot_port_checklist.md`
- One-page boundary summary: `docs/current_development_boundary.md`
- Documentation cleanup note: `docs/documentation_diet_20260514.md`

## Verification

Run these from `godot/` after Godot code or asset integration work:

```powershell
.\tools\run_headless_load_check.ps1
.\tools\run_warning_scan.ps1
```

Use focused Godot smoke tests or an in-game visual check for the feature you
touched. Legacy Python commands such as `python pingfighter.py` are reference
workflows only.

## Legacy Reference

The old Python/Pygame files and historical docs remain useful for parity
research. Legacy design / review packets under `docs/` should be mapped to
the current Godot owner module, renderer, audio owner, save/load path, and
smoke test before implementation.

Large legacy archives are split out of the active guides:
- `docs/sprites/legacy_accepted_sheet_archive.md`: Menhera / Dalji accepted
  sprite-sheet provenance.
- `docs/godot_module_ownership_ledger.md`: cumulative Godot module ownership
  and port log, not a rulebook.
