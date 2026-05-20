# Current Development Boundary

Current implementation target: Godot **디스크하츠 - 링피아**.

The original Python/Pygame **PingFighter** runtime is frozen. Use it only as
a reference for behavior, timing, balance, text, assets, and parity research
while porting into Godot.

## Default Routing

| Work type | Current target | Reference-only source |
|---|---|---|
| Gameplay / runtime logic | `godot/scripts/` | `pingfighter.py`, old Python modules |
| UI / menus / tooltips | `godot/scripts/ui/` and current Godot owners | Python UI paths in `pingfighter.py`, `start_menu.py`, `option.py` |
| Items / perks / skills | Godot owner modules plus runtime checklists | Python item / perk registries |
| Boss / character sprites | Godot asset tree plus owning renderer / catalog | Python sprite classes and old `items/` / `assets/` paths |
| Audio / VFX | Godot audio owners, FX hosts, shaders, particles | Python sound timing and procedural effects |
| Historical design packets | Map to current Godot owner before coding | `docs/*handoff*.md`, old review docs |

## Verification

After Godot code or runtime asset integration, run from `godot/`:

```powershell
.\tools\run_headless_load_check.ps1
.\tools\run_warning_scan.ps1
```

Add or run focused Godot smoke tests for risky behavior, and do a visible
review for UI, VFX, animation, HUD, or asset changes.

Legacy Python checks such as `python pingfighter.py`, `py_compile`, Pygame
`convert_alpha()`, and PyInstaller packaging are for explicit original
PingFighter source work only.

## Must-Read Files

- `AGENTS.md`: Godot-first implementation and runtime guardrails.
- `CLAUDE.md`: hidden-knowledge traps and asset workflow routing.
- `docs/godot_port_architecture.md`: Godot module boundaries and architecture rules.
- `docs/godot_module_ownership_ledger.md`: cumulative Godot module ownership log.
- `docs/documentation_diet_20260514.md`: summary of the Godot-first
  documentation cleanup and moved legacy archives.
- `docs/godot_port_checklist.md`: porting checklist and anti-hallucination checks.
- `docs/item_runtime_checklist.md`: item runtime integration.
- `docs/character_skill_perk_checklist.md`: character perk / skill integration.
- `docs/character_customization_direction.md`: in-game player skin /
  accessory customization direction, Smasher slot V1, and per-character
  mirror-vs-separate-L/R policy.
- `docs/sprites/boss_sprite_runtime_contract.md`: boss sprite state vocabulary.
- `docs/sprites/stage1_dalji.md`: compact Dalji sprite/runtime mapping.
- `docs/sprites/legacy_accepted_sheet_archive.md`: old Menhera / Dalji
  accepted-sheet provenance, reference-only.

## Rule Of Thumb

If a document says to edit `pingfighter.py`, `items/`, `assets/`, or
`entities/`, first ask: "Is this explicit original PingFighter work?" If the
answer is no, treat that instruction as a legacy anchor and map it to the
current Godot owner instead.
