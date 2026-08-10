# Documentation Diet 2026-05-14

Historical note: this cleanup was written while the target label was
**디스크하츠 - 링피아**. The current Godot product is **환격전**; its English
title is undecided, and old names remain compatibility/provenance identifiers.

This note records the documentation cleanup that moved the repository away
from original Python/Pygame PingFighter-as-active-development wording.

## Goal

- Make `godot/` the default target for new gameplay, UI, VFX, audio, item,
  character, boss, save/load, menu, and runtime work.
- Keep original PingFighter files as frozen reference material for porting
  behavior, timing, balance, text, and asset provenance.
- Stop active checklists from reading like instructions to edit
  `pingfighter.py`, `items.py`, `entities/`, or other legacy Python paths.

## Main Moves

- `AGENTS.md` now separates current Godot rules from
  `Legacy Python Reference (Frozen)`.
- `CLAUDE.md` is a routing and hidden-knowledge index, not a full runtime
  checklist.
- Menhera / Dalji accepted-sheet history moved from `CLAUDE.md` to
  `docs/sprites/legacy_accepted_sheet_archive.md`.
- The large Godot module ownership ledger moved from
  `docs/godot_port_architecture.md` to
  `docs/godot_module_ownership_ledger.md`.
- `docs/item_runtime_checklist.md` and
  `docs/character_skill_perk_checklist.md` now start with Godot-first usage
  routes and label embedded Python sections as legacy reference surfaces.
- `.claude/skills/` is the canonical repo skill tree. `.agents/skills/` may
  exist as a Codex loader mirror only.

## Current Reading Order

For new work, read:

1. `docs/current_development_boundary.md`
2. `AGENTS.md`
3. `docs/godot_port_checklist.md` when porting from Python behavior
4. `docs/godot_port_architecture.md` for architecture rules
5. `docs/godot_module_ownership_ledger.md` only to find existing owners
6. the focused runtime checklist for the domain:
   - `docs/item_runtime_checklist.md`
   - `docs/character_skill_perk_checklist.md`
   - `docs/sprites/boss_sprite_runtime_contract.md`
   - `docs/sprites/stage1_dalji.md`

## Rule Of Thumb

If a document tells you to edit a legacy Python path, first ask whether the
user explicitly requested original PingFighter source work. If not, treat that
line as a parity anchor and map the behavior to the current Godot owner.

## Verification Snapshot

Final cleanup pass checked the core docs and repo-local skills for old active
development phrasing such as:

- `PingFighter is a Python`
- `Run: python pingfighter.py`
- `Entry point: pingfighter.py`
- `Current Split Status`
- `Cumulative Module Log`
- `Claude commits`
- `Codex owns`
- `hand off to Codex`

Those strings should not appear as current instructions in the active routing
docs or skills. If they reappear, either label them as legacy reference text or
move the historical content to an archive / ledger file.

`git diff --check` was run against the touched routing docs, runtime
checklists, skill files, and split archive / ledger files.

## Completion Snapshot

As of 2026-05-15, this documentation diet is considered complete for the
original goal:

- Current active development is Godot **환격전** (English title undecided).
- Original Python/Pygame PingFighter is frozen reference material.
- Active routing docs no longer present old Python commands as default
  development workflows.
- Large historical blocks were split into archive / ledger files instead of
  remaining inside active routing guides.
- Remaining legacy references are intentional parity anchors and should stay
  labeled as such.
