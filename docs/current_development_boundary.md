# Current Development Boundary

Current implementation target: Godot **디스크하츠 - 링피아**.

The original Python/Pygame **PingFighter** runtime is frozen. Use it only as
a reference for behavior, timing, balance, text, assets, and parity research
while porting into Godot.

## Current Refactor Snapshot (2026-07-09)

This is a briefing snapshot, not a permanent completion claim. If it drifts
from the code, update this section and `docs/godot_module_ownership_ledger.md`
together.

- `godot/scenes/main.gd` is still the intended one-line shell extending
  `res://scripts/core/battle_scene_shell.gd`; current gameplay work lives in
  focused `godot/scripts/` owners instead of rebuilding a scene monolith.
- The current worktree has 1349 GDScript modules under `godot/scripts/`.
  The largest active split surfaces are stages, items, characters, core flow,
  HUD, audio, resources, effects, plaza, and Ringpet / Lingpet runtime.
- Ringpet / Lingpet is no longer a single feature blob. Its current modules
  cover affinity state / store / income, ring-core cap rules, hatch and loadout
  projection, language catalog / decoder / rich-text rendering, active-skill
  slot dispatch, per-skill runtime modules, passive helper states, and
  item-egg / feed-bowl subflows. Every current `godot/scripts/lingpet/*.gd`
  file has an explicit ledger entry as of this snapshot.
- Stage routing is module-owned. `stage_runtime_router.gd` routes Stage 5
  Hongryun and Stage 6 Tetriser through explicit actor, boss actor, pillar,
  background, playfield, and boss-skill HUD roles; Stages 1-4 keep their
  current stage-specific actor / pillar / background owners and compose
  additional skill HUDs through those owners.
- Stage 2 boss rendering is sprite-backed, with procedural alligator drawing
  kept as a missing-asset fallback. Stage 4 Ponk has current idle-sheet actor
  rendering plus skill-card HUD, modular magnetic / meditation FX, and a
  result-screen background / idle-sheet fallback actor click pulse, but its
  full dedicated action / result sheet set is still incomplete. Stage 5 Hongryun has
  routed boss actor, layered pillar/background, playfield, boss skill-card
  HUD owners, and a reused victory-sheet result fallback actor / click pulse.
  Stage 6 Tetriser has routed runtime, boss sprite, static pillar
  background, Crystal Shield, playfield, boss skill-card HUD, and reused-sheet
  result boss slot / click pulse; dedicated result Live2D polish remains a
  separate visual gap.

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
- `docs/refactor_status_brief.md`: one-page current Godot refactor status snapshot.
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
