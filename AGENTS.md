# Repository Guidelines — 환격전

This repository develops the repo-local Godot project **환격전**. The English
product title is undecided; do not invent one. The Python/Pygame PingFighter
runtime is frozen and is used only for parity research unless the user explicitly
requests a legacy-source edit.

Established names such as `pingfighter`, `DiskHearts`, `Ringpia` / `Lingpia`,
package IDs, CLI flags, environment variables, save keys, resource paths, and
export filenames are compatibility identifiers. Do not rename them during
player-facing rebranding. In particular, preserve `godot/project.godot`
`config/name="pingfighter"` until a tested `user://` migration exists.

## Work posture

- Assume the worktree contains valuable dirty and untracked WIP. Inspect scoped
  status/diff before editing. Preserve unrelated changes.
- Never use `git reset`, `git checkout`, `git clean`, `git stash`, broad restore,
  or broad staging as a validation shortcut. Use in-place toggles, fixtures, or
  temporary patches for RED counterproofs.
- Use `apply_patch` for edits. Never overwrite a whole dirty file when a focused
  hunk can do the job.
- Diagnose before fixing; prove the production owner/call path and test the
  reverse or negative leg. Distinguish fixed, deferred, blocked, and unverified.
- An interactive game process is not a reason to delay implementation or asset
  promotion or routine validation. Continue safe edits and run the repository
  smoke, warning, load, and windowed QA wrappers concurrently; they must declare
  `-AllowDuringPlay`, run at verified BelowNormal priority, use unique log paths,
  and restore caller priority in `finally`. Never terminate the user's game or
  editor for automation.
- Do not commit, push, rotate credentials, or rewrite history unless the user
  authorizes that external-state change.

## Routing and authority

- New gameplay, UI, VFX, audio, item, character, boss, save, menu, and runtime
  work defaults to `godot/`. `pingfighter.py` is behavior reference, not the
  architecture or default edit target.
- Before any Python-to-Godot port, read `docs/godot_port_checklist.md`.
- Architecture and owner boundaries: `docs/godot_port_architecture.md` and
  `docs/godot_module_ownership_ledger.md`.
- Cross-cutting runtime incidents and standing seals:
  `docs/godot_runtime_traps.md` via stable `GRT-NNN` anchors.
- Shared work discipline: `docs/agent_operating_posture.md`.
- Item runtime: `docs/item_runtime_checklist.md`.
- Character skill/perk runtime: `docs/character_skill_perk_checklist.md`.
- Boss sprite runtime vocabulary: `docs/sprites/boss_sprite_runtime_contract.md`
  and the focused boss document.
- Art-to-runtime VFX: `docs/skill_vfx_workflow.md`.
- Generated HUD chrome: `.claude/skills/ui-hud-generation/SKILL.md` plus the
  runtime owner/checklist. Item art and boss/character sheets route to their
  matching skills.

## Build, test, and commit gates

1. Identify the production owner and all affected consumers before editing.
2. Run focused production-path smokes, including a negative/reverse leg. A helper
   or final `ok` alone is not proof; require the wrapper exit and terminal line.
3. From `godot/`, run `./tools/run_headless_load_check.ps1`.
4. After every `.gd` edit, run `./tools/run_warning_scan.ps1`; use its `-Paths`
   focused mode for touched-file proof and keep full-scan baseline failures
   separate.
5. Run `git diff --check`. For visible work, also inspect a real windowed/Vulkan
   render or pixel capture at the acceptance resolution.
6. Re-snapshot HEAD, index, and scoped diff immediately before staging. Stage
   only exact paths/hunks; never use broad `git add -A` in this repository.

Current CI/pre-push lists must remain lockstep. The nightly lane is the full
`*_smoke.gd` suite; focused CI is not evidence that nightly completed.

## Core Godot compatibility and stage rules

- Live project: `godot/project.godot`; do not sync to an old C-drive mirror.
- Current Godot Stage 5 is Hongryun/Honglyeon. Current Godot Stage 6 is Tetriser
  (ported from Python Stage 7). Original Python Stage 6 Nemesis remains excluded.
- The Godot playfield is the full 760x750 game canvas. Pillar chrome is outside
  it in the screen letterbox; never apply the legacy Python 80px playfield inset.
- Game-coordinate overlays must use a playfield-sized clipping host. Screen-space
  fragment clips must convert canvas units to framebuffer pixels before upload.

## Runtime safety rules

- Keep `scenes/main.gd` orchestration-only. Create or use the smallest stable
  owner module and record ownership moves in the architecture/ledger.
- Do not allocate, scan images, slice atlases, build large caches, or sync-load
  resources in `_draw`, `_process`, `_physics_process`, or the first visible
  battle frame. Prewarm during boot/loading/stage entry and measure cold entry.
- Physics code must call `request_battle_redraw()`; never call the shell's
  `queue_redraw()` directly. Catch-up ticks otherwise multiply full draws.
- Never use live-array index stride as LOD for sparse particles. Use stable IDs
  or a stable contiguous window; cheap sparse effects should render continuously.
- Presentation randomness must not advance authoritative gameplay RNG. Use
  independent `RandomNumberGenerator` instances and differential seed tests.
- Detached FX/audio hosts need explicit score/serve/reset/cancel cleanup even
  when logical visibility becomes false.
- For looping or `sync_*` audio, register the stop method in
  `gameplay_loop_audio_cleanup.gd` and test score, scoreboard, serve wait, round
  restart, reset, and cancel.
- Cached `AudioStream` objects are shared by path. Duplicate a stream before
  mutating loop flags or other per-player state.
- Preserve update ownership: online/offline early returns must not skip required
  audio/effect cooldown ticks or tick them twice.

## Gameplay, UI, and asset integration

- Korean is the default player-facing language. Check current catalogs and
  localization before adding labels, tooltips, or names.
- Effective-level perks normally scale above Lv.5 when bonus sources apply.
  Any hard cap is an explicit gameplay/UI/documentation exception.
- Item and skill work must audit registration, acquisition/offer routes, grant
  routing, equipped-vs-owned state, persistence/reset, tooltip/HUD, VFX, audio,
  and focused production tests; the owner checklist defines the full matrix.
- Visible VFX defaults to modular Godot layers, reusable shaders, particles, and
  explicit lifecycle cleanup. Python visuals are timing/behavior references.
- Large prewarmed sheets should use VRAM-compressed imports or a documented size
  limit. Threaded disk loading does not eliminate first GPU-upload stalls.
- `@tool` scripts must guard tree/viewport/window access with `is_inside_tree()`
  and null checks.

## Boss Sprite Workflow

- Generate and prepare boss/character sheets through
  `.claude/skills/sprite-generation/SKILL.md`, then integrate against the boss
  runtime contract. Keep motion buffers separate and reuse walking-sheet scale.

## Runtime Performance Rules

- Treat large sheets as offline-prepared, VRAM-compressed source assets. Never
  do trim, alpha cleanup, atlas slicing, or downscaling in a hot path; prewarm
  through the owning loader and measure cold entry as well as steady state.

## Atlas sheet grid authority

- Declare `(cols, rows, frames)` per asset from the accepted source contract or
  manifest. Never infer a shared grid from image dimensions; zoom-render every
  cell at runtime size before promotion.

## Stage Integration Checklist

- Confirm current Godot stage mapping, owner, `res://` path/import state, every
  render key/fallback, cleanup boundary, and focused stage route. Boss slows
  default to `WEAK=0.70`, `MEDIUM=0.55`, `STRONG=0.40` in
  `scripts/status/boss_slow_tiers.gd`; lower is stronger, and raw exceptions
  require explicit parity documentation.

## Testing Guidelines

- Use the repository Godot wrappers and require their real exit/terminal line.
  Pair focused smokes with headless load, `.gd` warning scan, diff check, and a
  real render for visible work; legacy Python checks cannot sign off Godot.
- Interactive (windowed, non-editor) play does not block routine validation.
  Standard smoke, warning, headless-load, and windowed QA wrappers explicitly
  declare `-AllowDuringPlay`; the shared guard verifies BelowNormal priority and
  every wrapper restores its caller priority in `finally`. Each concurrent Godot
  process must use a PID/timestamp-unique `--log-file`; never reuse or delete the
  live game's log. A wrapper without the explicit declaration still fails
  closed and must be repaired or replaced with an operation-specific wrapper,
  not bypassed with an inherited environment variable. Performance causality
  experiments that require an uncontended fresh process remain a separate
  evidence gate; continue all other validation while that measurement is deferred.
- Asset-promotion and reimport chains must not ask the user to close the
  editor. Replace source/runtime files with the editor open, let the editor
  reimport them on its next window focus (owner-driven import; no `.godot`
  cache conflict), and poll for the materialized reimport before continuing
  to headless smokes instead of asking the user to relay progress. Never run
  headless `--import`, or any import-materializing headless pass, while the
  editor is open. Do not ask the user to close a non-editor game merely to
  begin or continue work: prefer versioned replacement files so the running
  session may keep its already-loaded resources, complete the source/config
  switch, and note that a fresh play session is required to observe it. Ask for
  closure only when an exact in-place lock has no safe versioned alternative.
  Do not halt routine smoke, warning, load, or Vulkan capture validation merely
  because another play session is active.

## Skills and mirrors

- `.claude/skills/` is the canonical repository skill tree.
- `.agents/skills/` is a Codex loader mirror only. Do not hand-edit both trees.
  Its tracking/sync policy is intentionally deferred until current sprite-skill
  WIP is settled; no CI check may silently skip an absent ignored mirror.
- Sprite workflow defaults to `fast`; this changes asset-side depth only and
  never relaxes runtime safety or verification.

## Credential safety

- Never store tokens, bearer headers, signed URLs, or API keys in tracked or
  ignored project config; use environment references or a user-local helper.
- Secret scans must print only paths/redacted findings. Never echo the value.
- Provider revocation/rotation comes first: local removal or history rewriting
  cannot invalidate an exposed credential. Never ask the user to paste new keys.

## Harness maintenance

- Follow `docs/agent_harness_maintenance.md` for backfill, compaction, archive,
  workflow-trigger, and verifier changes.
- Root `AGENTS.md` must stay within Codex's 32KiB default project-doc budget.
- Keep durable detail in owner docs, stable GRT ledger entries, and focused
  skills/rules; root files are routing and non-negotiable safety contracts.
- Run `tools/verify_agent_harness.ps1` after changing harness files.
- Exact pre-compaction payloads are preserved under
  `docs/agent_harness_archive/`; their sizes and hashes are pinned by the
  verifier. They are inactive provenance, not current instructions.
