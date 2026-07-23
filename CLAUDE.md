# CLAUDE.md

This repository now develops the Godot project **디스크하츠 - 링피아** only.
The original Python/Pygame PingFighter codebase is frozen and is kept as a
porting reference.

This file is the standing hidden-knowledge rulebook for work that may need
legacy PingFighter context. Many older sections mention `pingfighter.py`,
Pygame, Python item routes, or original runtime UI paths; treat those sections
as reference material for porting unless they explicitly describe current
Godot behavior. New gameplay, UI, VFX, audio, item, character, boss, save-data,
menu, and runtime work belongs in `godot/` by default.

Procedural setup (how to run, how to build, how to test) is intentionally NOT
listed here -- read the repo state, `AGENTS.md`, or `README.md` when needed.

## 0. Implementation Boundary with `AGENTS.md` and asset / item docs

- `CLAUDE.md` (this file) = Claude-side project standing rules and
  routing. Kept thin on purpose -- detailed playbooks live in the skill
  and doc directories.
- `AGENTS.md` = Godot-first runtime routing, integration, performance, and
  implementation source of truth for Codex/agent work. Legacy Python rules in
  `AGENTS.md` are porting references unless the user explicitly requests
  original PingFighter edits.
- `docs/sprites/boss_sprite_runtime_contract.md` = shared boss-sprite
  runtime vocabulary and state-to-sheet mappings across Python / Godot.
- `docs/sprites/stage1_dalji.md` = compact Stage 1 Dalji per-boss runtime
  sheet contract and Godot key mapping.
- `docs/sprites/legacy_accepted_sheet_archive.md` = old Menhera / Dalji
  accepted-sheet provenance archive, reference-only.
- `.claude/skills/sprite-generation/` = the full boss / character sprite
  sheet pipeline (prompts, nukki, QA).
- `.claude/skills/item-generation/` = the full item-visual pipeline (icon
  prompts, legendary frame rules, equip visuals, icon QA).
- `.claude/skills/ui-hud-generation/` = fullscreen / pillar HUD frame and
  backplate image-generation pipeline (prompting, transparent prep,
  source anchors, and hand-off notes for runtime alignment).
- `.claude/skills/` is the canonical repo skill tree. `.agents/skills/` may
  exist as a Codex loader mirror only; do not edit both trees by hand. Update
  `.claude/skills/` first, then refresh the mirror only if the loader needs it.
- `docs/item_runtime_checklist.md` = source of truth for every code
  location that must be touched when adding, removing, or modifying an
  item (active / passive / legendary / mythic).
- `docs/character_skill_perk_checklist.md` = source of truth for every
  code location and QA checkpoint that must be touched when adding,
  removing, or modifying a runtime character perk, unlock perk, or
  player-skill / 5-orb skill.
- `docs/skill_vfx_workflow.md` = shared Claude / Codex workflow for
  imagegen assets, Live2D-style assets, and modular 2D skill / VFX work.
- `docs/current_development_boundary.md` = one-page summary of the current
  Godot-vs-legacy boundary.
- `docs/agent_operating_posture.md` = shared agent (Claude/Codex) working
  posture — the fable-grade default (reduce output variance by applying the
  full rigor stack to every task). Thin routing here; that doc is the single
  source. Highest-value invariant: SAFE regression-detection validation
  (반증검증 = prove a new smoke FAILS on the buggy code by an **in-place Edit
  toggle / temp patch / fixture only — NEVER `git reset`/`checkout`/`stash`**,
  which would destroy uncommitted WIP in this repo).
- Legacy design / review packets such as `docs/four_poisons_handoff.md`,
  `docs/dual_glitch_clone_replication_handoff.md`,
  `docs/dual_glitch_clone_hp_handoff.md`,
  `docs/commando_firearm_overhaul.md`, `docs/WEAPON_SYSTEM_GUIDE.md`,
  `docs/chaos_spear_visual_review.md`,
  `docs/perk_flight_to_orb_animation_review.md`,
  `docs/logo_intro_handoff.md`, and
  `docs/pingfighter_modularization_plan.md` preserve old PingFighter
  design decisions / review notes. Treat them as parity references and map
  them to Godot owners before implementation.

If the documents conflict:
- Boss-sprite runtime / performance -> `AGENTS.md` wins.
- Boss-sprite runtime state vocabulary / attack-vs-stun key semantics ->
  `docs/sprites/boss_sprite_runtime_contract.md` wins.
- Stage 1 Dalji compact runtime mapping -> `docs/sprites/stage1_dalji.md`
  wins.
- Boss-sprite generation details -> the `sprite-generation` skill wins.
- Item visual / icon details -> the `item-generation` skill wins.
- Fullscreen / pillar HUD frame asset details -> the
  `ui-hud-generation` skill wins.
- Item runtime integration -> `docs/item_runtime_checklist.md` wins.
- Character runtime perk / skill integration ->
  `docs/character_skill_perk_checklist.md` wins.
- Legacy handoff / review packets lose to the current Godot owner module,
  `AGENTS.md`, `docs/godot_port_architecture.md`, and the relevant runtime
  checklist.
- Godot runtime hidden-trap details -> `docs/godot_runtime_traps.md` wins
  over the 3-8 line stubs kept in this file's trap index.
- General Godot runtime / performance / implementation questions not covered
  by a trap or checklist -> `AGENTS.md` wins.
- Everything else (routing, asset-prep rules, coordinate standards, stage
  mapping) -> this file wins.

## 0.1 Claude / Codex Asset Workflow Split

This split is a repo policy, not a tool-local memory. Keep the durable rule in
`CLAUDE.md`, `AGENTS.md`, and `docs/skill_vfx_workflow.md` so either tool sees
the same boundary on a later session.

- Claude leads aesthetic direction: skill-effect concept, mood, palette,
  silhouette, layer recipe, prompt wording, alpha / nukki visual review, and
  the "does this look right" pass.
- Codex leads executable delivery: Codex imagegen or Live2D-style asset
  generation when used, copying accepted assets into `godot/`, `res://` loader
  and prewarm wiring, shader family presets, `GPUParticles2D`,
  `Tween` / `AnimationPlayer`, audio, hitstop, camera shake, flash, lifecycle
  cleanup, and automated / live verification.
- New 2D skill / VFX work defaults to modular VFX layering. Use static texture
  pieces plus runtime composition, prefer shared shader families such as
  `WritheEmberMaterial` presets over one-off inline shader copies, and treat
  the 3-piece recipe as the baseline template rather than a hard limit.
- Claude may finish the art direction, but Godot runtime completion is Codex
  territory. Do not call a skill effect done until Codex has handled coordinate
  space, clip, loader / prewarm, cleanup, and test obligations.

## Fast Reading Map

For current 디스크하츠 - 링피아 work, do not read this file front-to-back as an
implementation checklist. Use it as a routing and hidden-knowledge index:

| Need | Read / follow |
|---|---|
| How to work (default agent posture) | `docs/agent_operating_posture.md` |
| Godot implementation, runtime checks, test commands | `AGENTS.md` |
| Godot runtime hidden traps (BOM, lazy-init, owner-schema, companion motion, boss-paddle skills, ...) | Stub index in this file; FULL text in `docs/godot_runtime_traps.md` |
| Godot port wiring and module boundaries | `docs/godot_port_checklist.md`, then `docs/godot_port_architecture.md` |
| Item runtime work | `docs/item_runtime_checklist.md` |
| Character skill / perk runtime work | `docs/character_skill_perk_checklist.md` |
| Skill / VFX art-to-runtime workflow | `docs/skill_vfx_workflow.md`, then `docs/godot_port_architecture.md` |
| Sprite generation / nukki / sheet QA | `.claude/skills/sprite-generation/` |
| Item visual generation | `.claude/skills/item-generation/` |
| HUD frame generation | `.claude/skills/ui-hud-generation/` |
| Old PingFighter coordinates, stage-number traps, Pygame icon chains | Legacy sections in this file, reference-only |

Sections beginning with `Legacy`, old per-boss history blocks, and references
to `pingfighter.py`, `entities/`, `pygame`, `resource_path()`, or historical
`handoff_codex` files are not default edit instructions. Translate the hidden
trap or parity fact to the current Godot owner before changing code.

**Do not mix skill scopes.** Boss sprite rules do not belong in the
`item-generation` skill, item icon rules do not belong in the
`sprite-generation` skill, and fullscreen HUD frame / pillar backplate
rules do not belong in either of those skills. Use
`ui-hud-generation` for large HUD frame art. Item runtime rules do not
belong in this file or in `AGENTS.md` -- they live in
`docs/item_runtime_checklist.md`. Character runtime perk / skill
code-location checklists also do not belong in `AGENTS.md` -- they live
in `docs/character_skill_perk_checklist.md`, with the companion hidden-
knowledge UI invariants staying in this file.

For future character passive / scaling perk work, treat effective-level
overflow as opt-out rather than opt-in. If `transcendent_crown`,
`sage_ring`, ignition-style buffs, or future perk-level increase effects
can raise a perk above `Lv.5` / `max_level`, assume the perk's real
numeric gameplay behavior should continue scaling unless the design
explicitly says the perk is boolean-only or intentionally hard-capped.
Any exception must be explicit in gameplay code, tooltip wording, and
the runtime checklist notes.

## Post-fix checklist backfill policy

After fixing a bug, regression, UI trap, or integration miss, also decide
whether the failure happened because an important rule was missing from the
repo's standing checklists / hidden-knowledge docs. Automatically backfill
the docs without waiting for a separate user request only when **all** of
the following are true:

- The failure pattern is plausibly repeatable.
- The missing safeguard is not safely re-derivable from reading the code
  alone.
- The issue is not just a typo, one-off data mistake, or other isolated
  accident.
- No existing rule already covers it well enough, or an existing rule needs
  to be strengthened.

Backfill routing:
- Boss-sprite runtime / performance / integration invariant ->
  `AGENTS.md`.
- Item runtime integration invariant ->
  `docs/item_runtime_checklist.md`.
- Character perk / skill runtime invariant ->
  `docs/character_skill_perk_checklist.md`.
- Hidden UI trap, coordinate rule, stage-mapping rule, or resource-loading
  invariant that belongs in standing memory -> FULL text in
  `docs/godot_runtime_traps.md`, plus a 3-8 line stub (same heading +
  pointer) in this file's trap index. See the graduation rule below.
- Asset-generation / pipeline rule -> the relevant `SKILL.md`; for
  fullscreen bottom HUD, pillar HUD, orb collar, active-slot tray, dash
  token frame, or other large HUD frame art, route to
  `.claude/skills/ui-hud-generation/SKILL.md`.

Do **not** backfill:
- Typos.
- One-off data-entry mistakes.
- Simple fix recipes that are adequately explained by the code diff or
  commit message.

When a similar rule already exists, prefer updating / tightening the
existing rule instead of appending a near-duplicate bullet.

If the repeatable bug is easy to misroute (for example, a runtime
tooltip-wrap / bonus-line-budget regression discovered while doing asset
or general integration work), tighten the route note in the first-entry
doc too (`AGENTS.md` or the relevant `SKILL.md`) instead of updating
only this file.

Repeatable legendary / mythic route omissions count as checklist bugs,
not isolated data mistakes. If a fix touched any special reward path,
backfill the runtime checklist and the item-generation hand-off so
future work explicitly audits independent candidate pools and payout
paths such as Nemesis chest, treasure-hunt legendary pools, the
stage-clear gacha builder, `gacha.py` item metadata / display sets, and
crane spawn-vs-reward routing.

Before ending the task, explicitly tell the user in one short line that the
checklist / rulebook was updated and what kind of safeguard was added.

### Backfill graduation rule (size discipline)

`CLAUDE.md` and the memory index are auto-injected into every session --
every line here is a recurring per-session token cost. Standing rules:

- New Godot runtime trap backfills put the FULL text (incident, mechanism,
  standing rules, smoke seals) in `docs/godot_runtime_traps.md` and add only
  a 3-8 line stub (same heading + essence + pointer) to this file's trap
  index. Do not grow a stub back into a narrative -- grow the doc section
  instead.
- Before adding a rule body to this file or `AGENTS.md`, grep the OTHER
  standing file: if the rule already lives there, add a 1-line pointer
  instead of a body copy. Deliberate N-plication (like the Claude / Codex
  workflow split in §0.1) must say so explicitly at each copy.
- When a section in this file exceeds ~15 lines, or its behavior is sealed
  by a named smoke AND covered by an on-demand doc, graduate the detail out
  and leave a stub. Soft ceiling for this file: ~100KB -- when over,
  graduate existing content before appending new content.

## Godot Runtime Hidden-Trap Index (stubs)

Every section below is a 3-8 line STUB of a standing runtime trap. The FULL
text (incident history, mechanisms, standing rules, smoke seals) lives
verbatim in `docs/godot_runtime_traps.md` under the SAME heading -- open
that file before working in an affected area. Per the backfill graduation
rule (see "Post-fix checklist backfill policy" above), new trap backfills
add their full text there and only a stub here.

## Godot ConfigFile UTF-8 BOM Trap

`ConfigFile.load()` silently skips the FIRST section when the file starts
with a UTF-8 BOM (PowerShell `Out-File` / Notepad add it invisibly). If logs
say `load OK` but first-section keys fall back to defaults, suspect BOM
first: read raw bytes, strip the BOM, rewrite without it; keep a `last_good`
recovery path for player-facing settings. Full rule:
`docs/godot_runtime_traps.md`.

## Godot High-Refresh Pacing Trap

The 144Hz divisor-lock display hypothesis is tested and REJECTED -- do not
re-run display-setting matrices. Known-good = 60Hz + 60 FPS + VSync On;
shipped default = Stable Monitor (144Hz -> render 72 / physics 72, single
lever `RENDER_FPS_CAP_STABLE_PREFERRED_MAX := 72`), bootstrap safety cap 48
in `project.godot`. Changing the shipped default requires moving ~7 places
together -- full list + tick-sync / tunneling notes:
`docs/godot_runtime_traps.md`.

## Godot Hot-Path Lazy Init Trap

Never lazy-instantiate modules / textures / caches / overlays from
`_physics_process` / `_process` / `_draw` -- the first call becomes a 100ms+
hitch. Prewarm at discrete moments (boot, loadout-apply, loading frames);
reset / "is it active?" consumers use `registry.get_cached_instance` (the
non-instantiating peek). In staged loading sequences the dep-instantiation
step must run BEFORE dep-consuming steps (match reset), key list
single-sourced from the consumer. Known repeat list (F3 icons, 370ms
match-reset deps cold-instantiation, stage-transition step-order variant,
lingpet skill host, ...): `docs/godot_runtime_traps.md`.

## Godot Missing Reserved-Asset Per-Frame Re-Stat Trap

The resource loader caches SUCCESSES only: a reserved-but-absent asset path
in a per-frame draw path re-stats the filesystem EVERY frame, and the
once-only warning dedup makes it silent. Never wire a not-yet-generated path
into per-frame draw; point it at a placeholder or land the art + a
`file_exists` assert in the same slice. Full rule:
`docs/godot_runtime_traps.md`.

## Godot Threaded Texture Cross-Path Timeout Trap

`ProjectResourceLoader.prewarm_texture_threaded_step()` has one shared
texture slot. A different-path waiter must use its OWN timeout clock and must
not drain the owner's in-flight worker on waiter expiry; otherwise a default
caller behind a large 0/0 live stream can block the frame on somebody else's
sheet. Streamed-asset readiness GATES must wait (return false + failsafe
deadline -> degraded visual), never sync-load as a last-line fallback
(721ms cut-in stall). Full rule + smoke seal: `docs/godot_runtime_traps.md`.

## Godot Animated Polygon Triangulation Trap

Any `draw_colored_polygon()` point set built from animated offsets must be
provably triangulable -- guard fills with `Geometry2D.triangulate_polygon`,
keep outlines / safe fallbacks visible, and treat repeated `Invalid polygon
data` spam as a frame-budget regression. Runtime rule owner: `AGENTS.md`
("Godot Degenerate `draw_colored_polygon` Trap"); details:
`docs/godot_runtime_traps.md`.

## Godot Effect Drawer Static-Frame Trap

Pick ONE timer key per effect family (`timer_frames` XOR `duration_frames`)
across resolver -> tick -> drawer: a drawer reading the key the tickdown
does NOT update renders a frozen frame-0 still for the whole duration
("pop in / pop out" instead of animating) -- if the shared drawer prefers
`duration_frames`, callers ticking `timer_frames` must not set it at all.
Terminal projectile deaths must WHITELIST which reasons get a visible
impact flash (bullet kinds fizzle silently on "expired" / "out_of_bounds";
an fx host anchored to `impact_flashes[0]` amplifies any stray entry).
Full rules: `docs/godot_runtime_traps.md`.

## Godot Negative-Z Backdrop Host vs Ancestor Opaque Fill Trap

Canvas z sorts globally per CanvasLayer: a negative-z host sinks below EVERY
ancestor's z=0 `_draw`, so an ancestor's opaque full-screen fill buries the
whole subtree silently (state smokes stay green -- sign-off needs PIXEL QA).
Positive-z variant: a spawner can drive an ANCESTOR's z above your absolute
child z (plaza z=1200 case). This section also owns the authored-facing
rule: lateral-action sheets face ONE invisible direction -- renderers must
consume the facing flag, mirror via the UV-swapped helper, and spawn
projectiles from the acting limb at the hand-empty frame; letterbox-actor
projectiles need the letterbox band included in their draw cull. Full
rules: `docs/godot_runtime_traps.md`.

## Godot Per-Frame Probability Roll Trap

A `chance_pct` rolled EVERY frame inside a multi-frame window compounds to
near-certainty and erases level scaling -- displayed rates are
per-opportunity by default; gate with a rolled-this-opportunity lock that
clears only when the opportunity ends. Before "fixing" a
displayed-stat-vs-felt gap by buffing power, confirm the stat's INTENDED
SCOPE with the design owner (링펫 방어율 saga). Smokes must assert the real
OUTCOME and step the ball with `ball_vel * delta * 60`. Full rules
(defense-guard scope / speed levers, Maribo wind-up freeze,
interaction-grant caps): `docs/godot_runtime_traps.md`.

## Godot Companion Walk/Idle Ratio Trap (treadmill in place)

A companion "marching in place" is usually a POSITION bug, not an animation
bug -- first prove `_companion_pos` advances (reference: `patrol_dir` parked
at 0 by the defense intercept and never re-seeded). The walk/idle gate must
be driven by ACTUAL drawn movement (never intent constants / hardcoded 1.0),
the walk clock must freeze when `update_lingpet` is skipped, and renderer /
animator thresholds must match (0.01). Three mechanisms + seals:
`docs/godot_runtime_traps.md`.

## Godot Companion Teleport/Reposition Locomotion Trap (ground pet keeps Y)

Position-scripting skills (teleport / blink / dash / recall) must pick the
target Y by locomotion style: ground (`patrol`) pets keep their lane Y
(X changes only), flight pets may dive freely. The divergence is ~0 at base
paddle height, so regression smokes MUST use a non-base paddle height.
Full rules: `docs/godot_runtime_traps.md`.

## Godot Lingpet Companion Incapacitation Body-Hit Trap (parked ≠ disabled)

A companion parked by a position override stays fully hittable. Any
incapacitation window (self-stun, freeze, knockdown) must route through
`suppresses_companion_body_hit(skill_id)` -- one switch gates BOTH body hit
and anticipatory strike -- and suppress ONLY the incapacitated window, never
the active / charge phase. Full rules: `docs/godot_runtime_traps.md`.

## Godot Owner-Field Schema Trap (runtime stat → character-info panel)

`owner.set(key, ...)` is a SILENT no-op for keys not declared in
`BattleSceneState.DEFAULT_VALUES`, and readers fall back to catalog / base
values that mask the drop. Declare every synced key, test the DIVERGENT
(boosted != base) case through a schema-gated owner, and diff primary vs
second / duplicate sync helpers (a sibling omitting one key pins the panel
at base). Structural seal + slot-sentinel rules:
`docs/godot_runtime_traps.md`.

## Godot Two-Update-Path Context-Flag Trap (effects-path flag read on the ball path)

The effects update path and the ball update path build DIFFERENT context
dicts: an effects-only flag (e.g. `enraged_boss_active`) read from a
ball-path helper silently returns false forever. Capture such flags at
`activate()` time into a member; the regression smoke must use SEPARATE
contexts for the two calls (a shared dict masks the bug). Inverse variant:
a state module ticking `_tick_timers` from BOTH `update_input` and
`update_effects` runs at DOUBLE speed (normal frames call both paths) —
tick on exactly one path and seal with a dual-path frame-drive smoke
(Thor Shield 0.7s→0.35s case). Full rules: `docs/godot_runtime_traps.md`.

## Godot Shared Stateful Input-Reader Edge-Eating Trap (extra get_snapshot() consumer)

An off-controller per-frame consumer of the shared player input reader (horn
strawberry command listener; `update_mythic_items` runs BEFORE
`update_player_control`) consumes stateful `action_just_pressed` /
`just_released` edges, so edge-gated inputs (commando firearm fire) silently
die while the item is merely equipped. Stateful readers' `get_snapshot()` is
now idempotent per physics frame -- new edge-detecting readers and off-path
input samplers must keep that guard. Seal:
`player_input_reader_same_frame_edge_smoke.gd`; full rule:
`docs/godot_runtime_traps.md`.

## Godot Lazy Applied-Key Re-Apply Trap

An "already applied" early-return that sits BEFORE the key recompute makes
key-CONTENT changes invisible -- "include the new input in the key" alone is
a silent no-op; the only levers are explicit invalidation plus folding the
input into downstream value caches. Smokes must drive the REAL apply path
(stale persists -> invalidate -> new value lands). Full rule:
`docs/godot_runtime_traps.md`.

## Godot Stats-Panel Row Budget Trap

`draw_lingpet_stat_rows` silently DROPS rows that overflow the section rect
(sibling of the tooltip shared-line-budget clip trap). When adding a panel
row, assert draw-time capacity via `lingpet_stat_rows_visible_capacity` at
the stacked-layout (<620px) rect, or define which row yields. Full rule:
`docs/godot_runtime_traps.md`.

## Godot Boss Skill Card Rail Commando-Avoidance Trap

`resolve_stack_start_y`'s `avoid_rect` arg is OPTIONAL -- a stage card-rail
renderer that omits `commando_firearm_panel_rect` silently disables Commando
firearm-HUD avoidance and buries that UI under its card stack. Every new
stage renderer must read + forward the rect AND be added to the coverage
smoke's hardcoded path list (prefer the behavioral seal). Full rule:
`docs/godot_runtime_traps.md`.

## Godot Lingpet Second-Active-Slot HUD Parity Trap

Companion active-skill state comes as suffixed pairs (`companion_skill_*`
and `companion_skill_*_1`) -- every HUD / debug / localization consumer must
read BOTH slots, and per-slot "casting" must resolve via that slot's OWN
skill kind (never a shared OR of every module flag, or a slot-1 cast fills
the slot-0 gauge). Smokes need a dual-active snapshot asserting both
directions. Full rules: `docs/godot_runtime_traps.md`.

## Godot Boss-Paddle-Scripting Skill Trap (drag / grab / displace the boss)

Skills that SCRIPT the boss paddle position (puppet-grab class) must keep
six invariants together: boss-AI freeze flag, ball collision preserved with
LIVE-anchor post-hit snap + `boss_collision_cooldown` re-arm,
`DEFAULT_VALUES` declaration, self-healing release that survives an
owner-less `cancel(null)`, round-reset `boss_y` normalization, and home-band
anchors for "below the boss" guards. Reference: Koyora puppet grab + its
smoke. Full invariants: `docs/godot_runtime_traps.md`.

## Godot Boss-Paddle-Range-Restriction Skill Trap (clamp / cage the boss)

Cage / lane / wall skills are NOT the freeze pattern: clamp the final
`boss_pos.x` AFTER normal boss AI output while preserving `boss_vel` (the
boss keeps playing inside the cage). Schema keys, puppet-grab precedence,
owner-less self-heal, and outcome smokes as listed. Full checklist:
`docs/godot_runtime_traps.md`.

## Godot Boss-Paddle-Resizing Skill Trap (shrink / grow the boss paddle)

Never resize `boss_paddle_size` directly -- the render center is
width-coupled, so the boss visibly slides sideways while shrinking. Keep
shared contexts full-size and inject a separate CENTERED scale for collision
(`boss_collision_shrink_scale`) and render (`boss_paddle_shrink_scale`)
reading the same owner flags; smokes must assert geometry OUTCOMES (hit vs
miss), not just flags. Full rules: `docs/godot_runtime_traps.md`.

## Godot Shared HUD Wrapper Prep-Before-Gate Trap (build-then-discard)

A shared per-frame HUD / rail wrapper serving multiple stages must hoist its
cheapest discriminating gate (stage id / active flag) ABOVE the caller-side
prep. A gate living only inside the callee renderer turns `context.duplicate()`
+ `LingpetRailCard.append_entry()` -> lingpet `get_snapshot()` into invisible
build-then-discard cost every frame (0.6~1.3ms/frame, grows with companion
activation; each `append_entry` = one full snapshot build). Seal with a
non-owning-stage call-count smoke. Full rule: `docs/godot_runtime_traps.md`.

## Godot Slot-Indexed HUD State Array-Shift Trap

Array-backed HUD slots compact / reorder, so `slot_index` is not stable item
identity. Acquisition-style effects must distinguish empty -> item from
non-empty -> different-key shifts: the former may pop, the latter should update
the tracked key while suppressing acquisition UI unless an explicit pickup
event says otherwise. Seal replacement + `remove_at` compaction cases. Full
rule: `docs/godot_runtime_traps.md`.

## Godot Per-Frame Catalog Lookup Trap (miss-case full scan)

A catalog / registry helper on a per-frame draw or physics path must be O(1):
the lingpet rail's `is_lingpet_skill()` full-scanned all 14 pets with
`duplicate(true)` per call, and boss cards (guaranteed misses) paid it twice
per card per frame (~0.29ms/card = ~95% of the "draw" cost). Build a one-time
static id index; deep-copy only on hit; attribute cost with per-layer
sub-labels BEFORE designing render-side caches. Full rule:
`docs/godot_runtime_traps.md`.

## Godot draw_polygon Un-Normalized UV Invisible-Quad Trap

`CanvasItem.draw_polygon(points, colors, uvs, texture)` needs NORMALIZED
[0,1] UVs. Feeding an atlas cell's PIXEL `source_rect` straight through
clamps every UV past 1.0 to the sheet's transparent edge texel, so the
whole textured quad renders invisible — no error, pixel-QA only. Sibling
`draw_texture_rect_region()` takes pixel rects and is fine, so one sprite
vanishes while another shows. Normalize by `texture.get_size()`
(uv_min/uv_max), match `points` corner order. Repeats: stage5 홍련
fire-machine dragon head, commando supply-drop crash plane. Full rule +
canonical helpers: `docs/godot_runtime_traps.md`.

## Godot Modal-Block Gate Skips Loop-Audio Maintenance Trap

Force-looped gameplay SFX (dash-delay 후딜, warp gate, magnum grip, plasma,
chaos blackhole, ...) are stopped ONLY by `update_effects`'s per-frame
`sync_*` / `GameplayLoopAudioCleanup.stop_all`. A physics-blocking modal
(character info via TAB, pause, debug pickers) returns from
`battle_scene_frame_controller.process_physics` BEFORE the update driver, so
that stop never fires and the loop drones/repeats for the whole modal
(reference: dash then TAB → 후딜 loops forever). Fix lives at the shared
modal-block gate (`_stop_modal_blocked_gameplay_loop_audio`); new looped SFX
must be in `gameplay_loop_audio_cleanup.gd` `STOP_METHODS`. Seal:
`battle_scene_frame_controller_modal_loop_audio_smoke.gd`. Full rule:
`docs/godot_runtime_traps.md`.

## Godot Per-Tick Float Drain Rail-Residue Trap

A real-tick float drain can strand the stored value on a sub-epsilon
positive residue that `is_equal_approx` write-gating freezes forever —
strict rail comparisons (`> 0`) then misjudge it every tick, so
rail-triggered states (포만도 탈진 KO) silently never fire while display /
slow-curve output still looks correct. Snap an ε-band onto BOTH rails in
the single sanitize helper; seals need residue-injection + real-tick
sequence legs (synthetic exact-0 cases prove nothing). Full rule:
`docs/godot_runtime_traps.md`.

## Godot TextureRect Min-Size Clamp Renders At Native Texture Size Trap

Setting a `TextureRect`'s `.size` SMALLER than its texture AFTER assigning
`.texture` (default `EXPAND_KEEP_SIZE` makes the Control's min size = texture
size) clamps `.size` back UP to native; switching `expand_mode` to
`EXPAND_IGNORE_SIZE` afterward lowers the min but does NOT re-shrink the already
-set size, so it renders at native texture px (overflowing). Code "looks 306" and
state smokes stay GREEN — only live pixel QA catches it. For a centered/rotating/
scaled/ShaderMaterial sprite use `Sprite2D` (position=center, `centered=true`,
`scale = px / max(tex.w, tex.h)`); if `TextureRect` is required, set
`EXPAND_IGNORE_SIZE` BEFORE `.texture`/`.size`. Seal with an on-screen-span assert
that excludes the native width, and keep piecewise VFX motion (envelope/rotation)
C0-continuous at phase boundaries (phase-lock breathing sin to the boundary).
Full rule + seal (angel dice arc): `docs/godot_runtime_traps.md`.

## Godot 전역 물리 보간 오버레이 스폰-글라이드 트랩

전역 `physics_interpolation=true` 환경에서 노드를 (0,0)에 만들고 같은
프레임에 최종 위치로 옮기면 물리 틱이 따라잡을 때까지 이동 경로 중간
(화면 중앙 부근)에 렌더된다 — 로딩 카메오처럼 첫 프레임이 정체되는
구간에선 ~0.5초 유령으로 보인다. 이산 재배치형 정지 오버레이 호스트는
생성 시 `physics_interpolation_mode = OFF` 명시. 씰:
`battle_loading_screen_renderer_smoke`. Full rule:
`docs/godot_runtime_traps.md`.

## Godot 스모크 임의 프로퍼티 대입 조용한 레그-abort 공허 GREEN 트랩

typed 객체에 미선언 프로퍼티 대입/미존재 함수 호출은 SCRIPT ERROR로
**그 레그 함수만** 중단시키고 러너는 계속 돌아 `ok`가 찍힌다 — 어서션이
한 줄도 실행되지 않은 공허 GREEN. 변종: `_expect`의 `quit(1)`은 실행을
멈추지 않아 말미의 무조건 `ok`+`quit(0)`가 종료코드를 덮어씀 —
`_failed` 플래그로 최종 ok를 게이트. 판정 정석은 표준 러너
`run_smoke_tests.ps1` 관통(엔진 `ERROR:`도 실패 승격); 수동 grep이면
`ok / SCRIPT ERROR / ^ERROR` 3필드. SceneTree 스모크 `_init()`은
`call_deferred("_run")`만. 픽스처 튜닝 프로퍼티 대입은 선언 존재 먼저
확인. Full rule: `docs/godot_runtime_traps.md`.

## Godot 퍽 표시 Projection-분기 후처리 탈락 트랩

라이브 스냅샷은 보유 퍽이 있으면 항상 융합 display projection을 실어
오므로 TAB/전투 퍽 표시의 실전 경로는 100% projection 분기다. 일반
분기에만 넣은 표시 후처리(슬롯 셀 확장, 런타임 상태 라인)는 스모크에서만
GREEN이고 실전에서 죽는다 — 공용 헬퍼 관통 + 실 `get_snapshot()` 레그 +
projection 비어있으면 fail-closed 가드 + 씰 CI 락스텝 등재까지가 한 단위.
Full rule: `docs/godot_runtime_traps.md`.

## Godot HUD 상시-가시성 승격 × 프리미엄 절차 드로우 트랩

비용 = 단가 × 유병률: 프리미엄 절차 리드로우(단가↑)와 가시성 게이트 확장
(장착→퍽 보유 등, 유병률↑)이 각각 무해해 보여도 곱이 상시 회귀를 만든다
(센서 오브 0.26ms/frame 사례). 게이트를 넓히면 per-frame 비용 재평가 +
~10드로 사이트 초과 정적 스택은 bake-once; 리스타일이 세그먼트/레이어
상수를 올리면 봉인 budget smoke를 같이 돌려 락스텝 갱신(센서 아크 예산
씰 HEAD RED 사례). 정상 상태 픽셀 불변 HUD 박스는 리테인드 자식
CanvasItem + 상태 키 게이팅. Full rule: `docs/godot_runtime_traps.md`.

## Godot 스크린-공간 FX 호스트 플레이필드 클립 트랩 (구조 GREEN ≠ 픽셀 클립)

스크린-공간 FX 호스트(스타포인트/주사위/플라즈마류)의 노드 자식은 플레이필드
패스의 `draw_set_transform`을 안 물려받아 오브/배경판이 좌/우 레터박스 필러로
샌다(플라즈마 시안 10,882px 사례). 내부 `Control(clip_contents=true)`로 760x750
클립 — ⭐`clip_contents`는 **Sprite2D(Node2D) 자식도** 클립한다(Control 전용
아님; `CLIP_CHILDREN_ONLY` 마스크는 ADD 블렌드를 못 잡음). 호스트가 오브 위치면
클립을 host-local `(game_offset-host_pos)/scale`에 놓고 자식을 `wobble-
clip_local_origin`으로 보정(좌표 계약 불변). **구조 씰(clip_contents/부모/rect)
만으론 공허-GREEN** — 실제 픽셀 클립은 비헤드리스 픽셀 씰(레터박스 lit
clip_ON=0/OFF>0)로만 증명. 프로브는 clear_color 검정+밝은픽셀만+타 호스트
free. Full rule: `docs/godot_runtime_traps.md`.

## Direct Draw Request Routing

When the user asks to "draw" something -- including Korean wording such
as "그려줘" or "그려달라" -- treat that as an imagegen asset-generation
request first. Use the relevant image-generation path / skill and produce
or edit a real bitmap asset before doing runtime wiring.

Do not silently replace a draw request with a procedural drawing branch,
SVG/vector placeholder, CSS shape, or other code-native visual.
Those are acceptable only when the user explicitly asks for a code-drawn
fallback, or when imagegen is blocked and the user accepts a fallback.

After the generated asset is accepted, copy it into the repo asset tree,
wire the PNG-first loader/cache path, and verify that no procedural
fallback or special-case early return bypasses the new file.

## Ringpet Visual Terminology

The shipped player-facing name is `수호령` (`Guardian Spirit`). Keep
`Ringpet` / `Lingpet` in established art prompts and internal compatibility
identifiers when needed for visual continuity and runtime stability; do not
surface those legacy names in UI copy or localized descriptions.

When the user says "링파츠" / "ring parts" for a Ringpet / Lingpet design,
do NOT interpret that as literal circular rings only. In this project,
링파츠 means Lumion-style identity hardware / ornament parts mounted on the
body: chest core plates, shoulder armor pods, forehead gem plates, collar
buckles, limb cuffs, tail modules, ear plates, sockets, gold / cyan inlays,
and magical-mechanical trim. Literal ring, halo, or orbit motifs can be
supporting accents, but they are not the definition of 링파츠.

For new or revised Ringpet concept prompts, first add readable body-mounted
parts on the chest, shoulders, head, limbs, and tail like Lumion's design
language; only add literal rings when they help the silhouette or theme. If a
Ringpet draft reads as "plain creature plus one necklace," strengthen these
mounted parts before adding more floating rings.

## Character Live2D Source Art Backgrounds

For character Live2D source illustrations / 원화 / full-body anchors that will
later need nukki, rigging, sheet generation, or runtime cutout use, the raw
generation must use a perfectly flat solid chroma-key background. Default to
`#ff00ff` magenta; use `#00ff00` green only when magenta conflicts with the
character palette. Do not use black, white, dark studio, scenic, gradient,
checkerboard, or "transparent-looking" backgrounds for production anchors.

The raw chroma-key source is not the final asset. Keep both the raw source
and cleaned alpha PNG, record the key color and cleanup method, and verify
alpha channel, transparent corners, non-edge-touching alpha bbox, and no
magenta / green fringe on dark and light preview backgrounds. The required
checklist is `.claude/skills/sprite-generation/checklists.md` §0.4.

## Character Live2D Idle / Click Dialogue Continuity

Treat every character Live2D click reaction as a complete
`idle neutral -> click / speech -> idle neutral` round trip. Generate it from
the accepted idle anchor, lock crop / stage fit / props, and measure
`idleLast -> clickFirst` plus `clickLast -> idleFirst` separately. Spoken
reactions need several natural mouth shapes across the full audible line,
with a settled mouth before and after speech; runtime voice delay must be
checked against the real audio. The detailed production and acceptance rules
live in `.claude/skills/sprite-generation/SKILL.md` section 2.5 and
`checklists.md` section 0.6.

## Upscale Request Routing

When the user says "upscale", "upscaling", "hires", "업스케일",
"업스케일링", or "real / Real-ESRGAN처럼", treat that as a request for
actual Real-ESRGAN processing on the bitmap asset. This applies to item
icons, HUD assets, boss / character sprites, Live2D-style sheets, runtime
VFX, and animated item / perk sheets.

Do not satisfy an upscale request with only runtime draw-scale changes,
Godot import filtering, Lanczos / nearest resize, CSS / UI scale changes,
or a new imagegen redraw. Use `tools/realesrgan/realesrgan-ncnn-vulkan.exe`
with `realesr-animevideov3` and `-s 2` by default unless the user gives a
different scale. For transparent PNGs, upscale RGB separately and recombine
the resized source alpha afterward so corners, holes, and sheet cell
margins stay clean.

The required checklist is `.claude/skills/sprite-generation/checklists.md`
§0.1 "Real-ESRGAN upscale gate"; item-generation and ui-hud-generation both
route their upscale work to that gate.

## Runtime Skill-Effect Sprite Sheets

When the requested bitmap is a gameplay skill effect rather than a static
icon or HUD frame -- for example a boss field, character aura, projectile,
cast loop, impact loop, shield, refraction field, magnetic field, or other
live VFX -- default future asset work to a **16-frame sprite sheet**. The
standard composition is a 4x4 sheet read left-to-right, top-to-bottom as a
smooth loop.

Sprite-sheet generator rule: final runtime skill-effect sheets also follow
the repo-wide AutoSprite MCP requirement. Use Gemini / imagegen only for
still concepts, prompt analysis, or explicit user-approved fallbacks, not as
the final sheet source.

Prompt and asset-prep expectations:
- Ask for exactly 16 equal cells, a stable center / scale / silhouette
  across every frame, and loop continuity from frame 16 back to frame 1.
- Require generous flat chroma-key or transparent margins so no spark,
  ring, glow, halo, trail, or ornament touches a cell edge.
- Keep source and runtime-ready PNGs versioned in the repo asset tree.
- Use shorter 2-frame / 4-frame / 8-frame outputs only when the user asks
  for a rough concept, a tiny icon-only animation, or a deliberately short
  one-shot effect.

Runtime wiring, cache policy, and final load checks remain `AGENTS.md`
responsibilities after the 16-frame sheet is accepted.

## Fullscreen / Pillar HUD Frame Work

Any work involving large HUD frame art -- bottom unified HUD frames,
pillar backplates, orb collars, active-item slot trays, dash-token
decorative frames, or other generated UI chrome -- must use the
**`ui-hud-generation` skill** at `.claude/skills/ui-hud-generation/`.
That skill owns prompt wording, style boundaries, chroma-key / alpha prep,
source-anchor handoff notes, and reject / regenerate checks for HUD frame
assets.

Runtime integration for those assets remains an `AGENTS.md` concern:
PNG-first loading, cache strategy, measured source anchors, actual
fullscreen coordinates, active-slot compatibility, and screenshot /
preview QA must be handled there after the asset is accepted.

When HUD frame work also depends on player skill orbs or dash-token orbs,
remember that those positions are not static decoration. The live layout
uses shared runtime constants for pillar X/Y margins, internal surface
insets, skill-orb radius / gap, dash-token inset, and a special Heavenly
Cape 6-orb dial. The asset-side handoff must say which live layout it was
designed around, and the runtime side must re-check the perk-flight target
animation plus player / boss dash-token alignment after any coordinate
retune.

## Boss Sprite Work

Any work involving boss/character sprite sheets -- creation, regeneration,
walk / attack / dash / turn (facing transition) sheets, background removal
(nukki), or Gemini MCP image generation or editing -- must be handled via
the **`sprite-generation` skill** at `.claude/skills/sprite-generation/`.
That skill owns the full pipeline: prompt templates, identity and scale
lock rules, content-filter bypass vocabulary, the nukki algorithm, and
the reject/regenerate QA checklists.

**If the skill is not auto-triggered, explicitly invoke
`/sprite-generation` before proceeding.** Do not recreate sprite rules
from memory -- always route through the skill so identity and scale lock
stay consistent across bosses.

**Standard sheet set for new bosses / characters:** the
`sprite-generation` skill §17 defines the canonical 7 basic sheets
(walk_left, walk_right, idle, dash, victory, defeat, stun) plus
optional / boss-combat / skill-specific categories. Use that section
as the planning checklist when starting a new boss build. The Stage 1
Dalji buildout is the reference implementation (10 sheets total: basic
7 + attack + turn + 2 skill-specific). Each category has a different
post-processing pattern (per-cell vs single uniform scale, feet
anchored vs preserved) and runtime mapping pattern (direction-based
vs internal-timer vs external-timer) — full matrix in §17.4 / §17.5
of that skill.

Runtime state vocabulary is now centralized in
`docs/sprites/boss_sprite_runtime_contract.md`. Stage 1 Dalji's compact
runtime mapping is in `docs/sprites/stage1_dalji.md`; the detailed
historical notes below remain for provenance and hidden-knowledge
asset decisions until they are gradually split into per-boss files.

Tool-routing note inside that skill:
- **AutoSprite MCP is the required generation source for all new
  sprite-sheet assets.** Boss sheets, character sheets, player movement /
  result sheets, runtime VFX sheets, and animated perk / item sheets must
  start from `mcp__autosprite__*` output unless the user explicitly grants
  a one-off exception. Do not ship a sprite sheet generated only through
  Gemini, FLUX, built-in imagegen, local frame interpolation, runtime
  drawing, or manual recomposition and call it an AutoSprite sheet.
- Deterministic post-processing is still allowed after AutoSprite
  generation: background cleanup, alpha/nukki, frame slicing, edge-touch
  correction, cell layout, scale alignment, preview GIFs, and runtime-sized
  exports. The source animation frames must remain AutoSprite-derived, and
  the handoff must record the AutoSprite source/job plus any expansion or
  mirroring done afterward.
- If AutoSprite is unavailable, stop sprite-sheet production and fix the
  MCP connection or ask the user before using a fallback. A fallback may be
  acceptable for a still icon, mockup, or temporary placeholder, but not for
  a final sprite sheet.
- Gemini MCP may still be used for prompt analysis, reference critique, or
  text planning around sprite work, but not as the final sheet generator.
- **Gemini MCP session-history trap:** a `2048x2048` generation can
  succeed normally, then cause the *next* in-chat request to fail as a
  `many-image request` if that image is still attached in conversation
  history. The practical trigger is the client-side `>2000 px` long-side
  limit, not a prompt failure. For iterative work in the same session,
  default to `1536` or `1024`; reserve `2K` for one-shot generations or a
  fresh session. If a `2048` result must be reused in chat, resize it to
  `<=2000 px` first.
- **Gemini MCP connection stability:** if the MCP server starts timing
  out at `30000ms`, do not treat it as a prompt/model problem. First
  check the local MCP launch path. Prefer the repo launcher
  `.claude/gemini_mcp_launcher.mjs` through a fixed `node.exe` path over
  `npx -y @rlabs-inc/gemini-mcp`, keep `@rlabs-inc/gemini-mcp` installed
  under `mcp/package.json`, skip startup API probe work, and keep stdout
  reserved for MCP JSON-RPC. Verify recovery with `initialize`,
  `listTools`, and one lightweight tool call before resuming asset work.
- **Historical accepted-sheet notes elsewhere in this file may still
  reference FLUX, Gemini, or older AutoSprite usage.** Those entries describe how
  already-shipped sheets were originally produced (e.g. Stage 3 Menhera
  turn / victory FLUX-derived sheets, Stage 1 Dalji attack v2 FLUX
  expansion). Regenerate future sprite sheets through AutoSprite MCP per
  the required source rule above. The historical record stays as-is so
  the provenance of shipped art is auditable.
- **Legacy victory / motion sheets can leak obsolete identity branches.**
  If an old sheet starts pushing outdated hair / ribbon / cap language
  back into Gemini MCP edit sessions, remove it from the generation
  stack and keep it as QA
  comparison only, not as a motion master.

### Sprite Workflow Mode

Before starting a new sprite branch, check:

- `.claude/sprite_workflow_settings.json`

Default:
- `spriteWorkflowMode = "fast"`

Mode policy:
- **fast** = default. Use quick candidate generation, early visual
  judgment, and aggressive rejection. Do NOT jump into deep frame
  expansion, publish-pack work, or runtime wire-up until a candidate
  already looks promising.
- **precise** = promotion mode. Use the full strip QA / frame-expansion /
  publish / nukki / runtime-handoff path when the user explicitly wants
  depth or when the candidate is already near shipping quality.

Utility:
- `tools/set_sprite_workflow_mode.ps1 fast`
- `tools/set_sprite_workflow_mode.ps1 precise`

### Invariants that remain here (do not re-derive from the skill)

- **Canonical reference = walking sheet.** During asset generation,
  `items/[name]_boss_sheet.png` is the staging identity anchor for every
  subsequent sheet of the same boss. Accepted runtime PNGs for the current
  project must still be copied into the repo-local Godot asset tree and
  wired from the owning Godot module. Attack, dash, and turn sheets must
  read as the same character.
- **Keep "canonical identity anchor" separate from "runtime-accepted
  auxiliary sheet."** A turn sheet may be accepted for runtime playback
  while still remaining a non-anchor asset. If that happens, document the
  turn as `runtime-only auxiliary sheet, non-anchor` before handing off to
  Codex. The walking sheet remains the sole identity anchor unless a later
  explicit decision reclassifies another sheet.
- **A regenerated walk sheet does NOT become the new canonical just
  because it exists.** Keep the previous accepted walk sheet as the
  rollback reference until the new walk passes gameplay-scale QA for
  identity, body read, and frontal combat readability.
- **Same boss, same identity across all sheets.** Hair color, hairstyle,
  face, eyes, skin tone, proportions, outfit, and signature accessories
  must not drift between walk / attack / dash / turn.
- **Same boss, same readability class across all sheets.** Do not accept
  a mixed set where one sheet reads obviously cleaner, crisper, pinker,
  or more legible at gameplay size while the others look softer or
  muddier. That is a regenerate problem, not a runtime fix.
- **If one accepted sheet is clearly the quality leader, regenerate the
  weaker sheets upward instead of downgrading the leader.** When victory
  or any other accepted sheet is visibly sharper / cleaner / more
  resolved than the rest of the set, treat that sharper sheet as the
  quality target and regenerate the blurrier sheets to match it. Do NOT
  accept a mixed-quality final set and do NOT solve the mismatch by
  softening the better sheet.
- **Body scale lock (+/-5%).** Head, torso, and pelvis must stay within
  +/-5% of the walking sheet. Express speed with pose, lean, effects, and
  motion lines -- never by resizing the body.
- **Cross-boss size standard: Stage 3 Menhera body class is the
  STANDARD, not just a baseline.** The legacy parity measurement is a
  `176 x 88` target frame canvas (`BOSS_IMG_WIDTH = 160`,
  `BOSS_IMG_HEIGHT = 80`, `+10%` width scaling in `pingfighter.py`).
  Every new petite human / chibi boss must hit that size class in the
  current Godot runtime. Treat `176 x 88` as a visible body-read and
  renderer-metadata reference, not as an instruction to edit Python.
  **Do NOT rely on legacy sprite class default constructor args for
  sizing** -- many class-default values (Menhera `79 x 88`, Tauren
  `83 x 92`, Honglyeon `100 x 88`) are legacy / per-boss tuned and
  would each push a new boss into a different size class if copied.
  In Godot, record the intended canvas / source-rect / stage-scale
  settings in the owning boss renderer or catalog, then verify visible
  body read in-game next to Menhera before considering the integration
  done. Exceptions (large-frame Tauren, vertical Honglyeon, deliberate
  oversized / undersized concept bosses) must be documented per-boss
  with the Godot size override and the design reason recorded both in
  the implementation / handoff note and in the per-boss policy section
  here. Asset-side details in `sprite-generation` skill §4.1 and
  `checklists.md` §10; runtime-side details in `AGENTS.md`.
- **Attack sheets should assume anticipatory runtime triggering by default.**
  For contact-based melee / strike attacks, prompt for a readable prep ->
  impact -> recovery arc, because Codex may start the sheet slightly
  before predicted ball contact rather than only on the exact hit frame.
  Early frames must contain meaningful coil / intent, not dead air.
- **The preferred anticipation style is short and conservative.** The
  goal is to reveal the prep a little before contact, not to start a
  long wind-up so early that the strike visibly happens before the ball
  arrives. If an attack only works when triggered far too early, the
  prep arc is too slow and should be regenerated tighter.
- **Attack prompts should identify the intended impact frame when one
  frame is the clear strike moment.** If the attack has a strongest hit
  frame or a frame that should be held briefly at contact, say so in the
  prompt / QA / hand-off so runtime can align the pre-contact trigger and
  hold timing correctly. If an attack is supposed to snap instantly with
  almost no prep, that must be stated explicitly rather than left for
  Codex to infer.
- **Visible body read, not just canvas size.** Cross-sheet consistency is
  judged by how large the body/face actually read in-game. Attack / dash
  effects may extend outward, but the body and face must not read smaller
  than the accepted walk baseline. Details in the `sprite-generation`
  skill (QA) and `AGENTS.md` (runtime).
- **Front-facing bosses must feel lively through whole-body rhythm.**
  Front-facing lock is fine, but limb-wiggle-only motion is not. Lateral
  / idle life must come from body bob, weight shift, hip / shoulder
  sway, and hair / ribbon / cloth / flame motion. Details in the
  `sprite-generation` skill.
- **Walk-sheet strip gate: inspect the accepted 8 frames side by side
  before handoff.** Do NOT judge a walk candidate only from a stitched
  preview, loop playback, or a vague "gameplay read." If the direct
  `f1..f8` strip still looks like the same pose repeated eight times, or
  like a static idle gallery with only tiny paw / foot shifts, reject and
  regenerate the walk sheet asset-side.
- **Pair-level mirror success is not enough for walk promotion.** A walk
  branch does not pass just because `F1↔F5` mirror discipline landed or
  because sequence-level identity is stable. `F2/F3/F4/F6/F7/F8` must each
  contribute a visibly different walk-slot role (rise / shift / rebound /
  return) at sheet-review scale, not only after runtime inference.
- **Front-biased walk must still read as forward-facing in motion.**
  If the walk sheet makes the boss read as consistently looking left or
  right during stable movement because of hair asymmetry, ribbon
  placement, eye placement, cheek visibility, shoulder exposure, or
  torso angle, reject and regenerate it. "Front-biased" is not a hidden
  3/4 walk.
- **Do not trade frontal readability for liveliness.** A walk sheet that
  is more animated but noticeably more side-facing than the last
  accepted walk sheet is a regression and must be rejected.
- **For front-biased bosses, turn is no longer an angle-rotation brief.**
  If the walk stays frontal, the turn sheet should usually be a short
  characterful direction-change gesture tied to the walk -- head lift,
  shoulder hitch, arm swap, knee lift, hop / pivot accent, ribbon or
  hem rebound, or another boss-specific habit -- not a `+90 -> 0 -> -90`
  profile chart.
- **Apparent turn-face clipping is usually an asset-side QA problem, not
  an automatic runtime crop bug.** When a turn frame looks forehead-cut,
  face-clipped, or vertically squashed in gameplay, compare the raw cell,
  post-inset crop, trimmed frame, and gameplay-size render before handing
  the issue to Codex. If the same clipped-looking read survives before
  runtime fitting, reject / regenerate the art instead of asking for more
  turn-only runtime scaling.
- **Do not keep "solving" a bad turn by shrinking it harder.** Extra
  turn-only downscale can make the frame smaller without fixing the
  clipped-face impression. If the key transition frames still look
  chopped after a conservative fit, the correct hand-off is visible-turn
  disable / hop-only fallback until the turn art is replaced.
- **Do not hand off asset-side facing failures to Codex as runtime work.**
  If the walk no longer reads as forward-facing, the fix is regenerate /
  rollback on the asset side -- not runtime left/right remaps, blind
  sprite flips, or semantic redefinition of travel directions.
- **Turn-hop requests do not require visible turn-sheet playback.** If
  the user wants "walk stays frontal, direction changes get a brief hop,"
  a hop-only runtime transition on top of the frontal walk is acceptable;
  do not force a mismatched turn sheet into gameplay just because a hop
  was requested.
- **No transparent silhouette gaps between side hair and shoulders.**
  Head -> hair -> shoulder -> torso must read as one closed shape;
  background must not show through. Use a rear hair layer behind the
  shoulders if needed. Details in the `sprite-generation` skill.
- **File path convention:**
  - Staging walk:   `items/[name]_boss_sheet.{jpeg,png}`
  - Staging attack: `items/[name]_boss_attack.{jpeg,png}`
  - Staging dash:   `items/[name]_boss_dash.{jpeg,png}`
  - Staging turn:   `items/[name]_boss_turn.{jpeg,png}` (optional aux sheet)
  - Godot runtime assets: `godot/assets/sprites/bosses/[name]/...` or the
    stage owner's established asset folder
  - Godot runtime owner: `godot/scripts/...` stage / boss / renderer module
  - Legacy Python class reference only: `entities/[name]_boss_sprite.py`

### Legacy Accepted-Sheet Archive

The long Menhera / Dalji accepted-sheet archive was moved to
`docs/sprites/legacy_accepted_sheet_archive.md` to keep this routing file
readable. Use that archive only for provenance, identity locks, and legacy
Python/Pygame parity research. For current work, route through the
`sprite-generation` skill, `docs/sprites/boss_sprite_runtime_contract.md`,
`docs/sprites/stage1_dalji.md`, and the owning Godot module.

### Role split (updated 2026-05-14 — implementing-agent end-to-end ownership)

- **Current implementing agent + sprite-generation skill:** sheet generation,
  prompt design, nukki, offline PNG preparation, repo asset-tree commit under
  the current Godot asset path (`godot/assets/sprites/...` or the stage
  owner's established folder), Godot owner-module wiring under
  `godot/scripts/...`, loader caching, runtime scaling, performance audit,
  in-game QA, and **final apply**.
- **Legacy Python paths** such as `assets/`, `items/`, `pingfighter.py`, and
  `entities/[name]_boss_sprite.py` are provenance / parity references unless
  the user explicitly asks for original PingFighter source work.
- **`AGENTS.md`:** current Godot-first runtime guardrails and verification
  policy. Read it before promotion to avoid breaking an existing invariant.

Historical "Codex hand-off" notes elsewhere in this file (per-boss policy
sections, `.tmp/.../handoff_codex.md` references, etc.) describe how shipped
sheets were originally promoted under the prior process. They stay as-is for
auditability. Future sheet work follows the implementing-agent end-to-end
model above.

---

## Item Work (Godot-first; legacy Python paths are reference-only)

Any work on **item visuals** (active / passive / legendary / mythic
icons, character paddle-part equip overlays, item mood / theme art)
must be handled via the **`item-generation` skill** at
`.claude/skills/item-generation/`. That skill owns the full visual
pipeline: per-tier prompt templates, legendary frame stack routing
(see `LEGENDARY_ITEM_TEMPLATE.md`), `empty_legendary` conventions,
equip-visual prompts, mood / glow / particle rules, and the icon
reject/regenerate QA checklist.

Any work on **item runtime integration** must be handled via
**`docs/item_runtime_checklist.md`**. That document is the single
source of truth for Godot item runtime wiring and for legacy Python
reference paths to inspect during ports.
Legacy Python examples in this section (`items.py`, `pingfighter.py`,
`legendary_items.py`, `gacha.py`, `downtown/`, etc.) are reference-only
unless the user explicitly asks for original PingFighter edits.
The same routing applies when the bug is "item runtime scaling uses the
wrong level basis / wrong per-level constant" or "`Lv.6+` description
text dropped one of a perk's effects." Those are runtime item-
integration bugs, not asset-work bugs.

**If a skill or doc is not auto-triggered, explicitly invoke it
before proceeding.** Do not recreate item rules from memory -- always
route through the skill (for visuals) or the checklist (for runtime)
so new items land cleanly.

### Role split

- **`item-generation` skill:** icon generation, legendary frame stack
  decisions, equip-visual assets, mood / palette / particle theme,
  icon QA. Does NOT own any runtime code location.
- **`docs/item_runtime_checklist.md`:** every Godot runtime location and
  every legacy reference path that must be audited when an item is added,
  removed, ported, or modified. It covers current Godot item owners plus
  legacy references such as `items.py`, `pingfighter.py`,
  `legendary_items.py`, `gacha.py`, `downtown/`,
  `item_state_manager.py`, equip-visual registry, and the Pandora
  exclusion list. Does NOT own visual asset decisions.
- **This file (`CLAUDE.md`):** thin routing rule (this section).

### Invariants that remain here (do not re-derive from the checklist)

These are the rules most likely to cause silent, hard-to-trace bugs
if re-derived from memory. Keep them in mind even while the full
checklist is open.

- **Item runtime does not live in asset skills.** Current item runtime
  belongs in Godot owner modules and `docs/item_runtime_checklist.md`;
  `AGENTS.md` provides top-level Godot-first routing.
- **Legendaries are always passive, never active.** They must be in
  `store_active_item()`'s passive-filter list or they misroute on
  pickup.
- **Duplicate-allowed passive / legendary: `skip_append = True` is
  forbidden.** First acquire activates; every acquire (first and
  later) rolls and falls through to inventory append. Setting
  `skip_append = True` on a duplicate silently loses the pickup.
- **"Duplicates allowed" is path-specific, not global.** Field drops,
  Pandora / treasure routes, shop / crane pools, and stage-clear gacha
  can intentionally diverge. Do not summarize an item loosely as
  "duplicate-allowed" unless you verified which acquisition paths
  actually repeat after first obtain.
- **`PASSIVE_SLOT_ORDER` is not the only hardcoded list.** The
  developer-mode `all_items` block in `pingfighter.py` instantiates
  a SEPARATE hardcoded list of item dicts. You must update both, or
  the dev-mode 2-key menu will hide the new item.
- **`gacha.py` pool labels are not the full gacha path.** The actual
  stage-clear gacha candidates are built separately in `pingfighter.py`
  via `available_items.append(...)`. Updating the passive-name pool
  alone does not make the item pullable in-game.
- **Pandora Legacy keeps its own `passive_names` exclusion set in
  `legendary_items.py`.** Every new passive / legendary must be added
  there too, or Pandora can spawn them as actives.
- **Character-info UI keeps separate name / description maps.** A new
  item is not fully integrated until `get_item_name_korean()` and
  `get_item_description()` can render it cleanly in inventory, shop,
  tooltips, and dev mode.
- **Passive effects are equip-gated.** A passive sitting only in the
  inventory should not grant gameplay benefits. The live effect path,
  equip visual, and any roll / polish / enhancement sync should turn on
  only while the item is actually equipped, and must shut off on
  unequip or reset.
- **Runtime-skill-driven item behavior must use one canonical helper
  path.** If item gameplay depends on academy / downtown / item-tree
  runtime skills, keep gameplay math, tooltip text, and any preview /
  debug readout on the same level basis and helper path
  (`get_runtime_skill_level()`, `get_runtime_skill_bonus()`, or a
  dedicated `get_effective_*` helper). Do not let one path read raw
  `runtime_skill_levels.get()` while another path uses effective-level
  helpers unless base-only behavior is an explicit design choice.
- **Per-level constants for item runtime skill scaling should not be
  re-typed ad hoc in effect modules.** If a perk is defined as `+30% /
  level`, `+3% / level`, or similar, prefer the shared helper / source
  table over hand-coding another constant in each consumer. Otherwise
  gameplay, tooltip, and balance data can silently drift.
- **Multi-effect item perks need full `Lv.6+` description coverage.**
  When one runtime perk changes more than one item-facing number, the
  dynamic description path above the base cap must keep all scaling
  lanes visible. A fallback that only mentions the first effect is an
  incomplete integration, even if the gameplay math is correct.
- **A written icon file is not "done" until runtime precedence is
  verified.** If `items.py`, `pingfighter.py`, or another loader has a
  special-case icon branch, procedural fallback, or cache
  (`ITEM_ICONS`, `icon_cache`, etc.), verify that the named PNG is the
  path actually winning at runtime instead of being silently bypassed by
  an earlier return.
- **Online / multiplayer passive classification is separate.** The
  `_passive_names` sync set in `pingfighter.py` must also include new
  passive items, or they can be misclassified as actives in synced
  state.
- **Gameplay body-part family and visual overlay slot are different
  systems.** `ITEM_SLOT_BASE_MAP` / `PASSIVE_SLOT_ORDER` decide
  equip-family logic, while `item_parts_registry.ITEM_SLOT_MAP` and
  `CharacterSkin.parts` decide visual overlay slots. If two wearable
  families can co-equip (for example top + belt), they must not share
  the same visual slot unless the overwrite is explicitly intended.
- **Economy integration is split across separate hardcoded values.**
  `items.py` carries per-item `sell_price`, while
  `downtown/building_interior.py` carries the shop `base_price`.
  A new passive / legendary is not economically integrated until both
  are set to a sensible value relative to comparable items.
- **If an item or perk reduces player-skill cooldowns, the HUD must
  display the reduced final cooldown too.** The left-side 5-orb orb
  countdown text, cooldown wedge timing, and skill tooltip cooldown
  line must read from the same final effective cooldown path as the
  runtime logic. Do not leave display code on raw
  `skill_data["cooldown"]` while gameplay uses a reduced value.
- **Every legendary roll-option stat read must pass
  `apply_polish=True` AND `enhancement_bonus_pct=...`** through
  `get_legendary_roll_value()`. Missing either one means the polish
  perk or enhancement buff is invisible at runtime even though the
  number displays in the tooltip.
- **Changing a passive roll range is not just `PASSIVE_OPTION_RANGES`.**
  When a passive's min/max changes, also sync every fallback/default
  path that can still supply the stat when `rolled_options` are absent:
  module-level default globals, `_reset_roll_bonuses_to_default()`,
  and any per-item effect-module default/reset value. Otherwise legacy
  saves or pre-roll fallback paths can keep using out-of-range numbers
  even though the item card shows the new range.
- **Fixed option lines should stay visually plain.** If an item has a
  guaranteed option alongside rolled data, the option tooltip should
  present it in the same understated style used by `dashholder`.
  Do not add a special `(고정)` suffix unless the user explicitly asks
  for that wording.
- **Do not overwrite `items/unknown_item.png` or `empty_legendary*`
  placeholders.** The unknown asset is the fallback; `empty_legendary*`
  are blank developer-mode grid slots whose layout the UI depends on.
- **Character-transformation / revival items must force the paddle
  to land on transform finalize.** Items that replace the player's
  character kit on activation -- Yachaman Soul (passive, revival on
  score loss), Odin's Eye (legendary, revival on score loss), Horn
  Strawberry Mask (passive, command-triggered transform) -- each
  gate the Viper jetpack update block off via
  `is_yachaman_transformed()`, `is_odins_eye_transformed()`, or
  `_viper_original_skills_blocked` (Horn Strawberry). If a Viper is
  mid-jetpack when the transform finalizes, `_viper_jetpack_offset_y`
  stays negative and the jetpack block that normally writes
  `PLAYER.bottom` no longer runs -- the transformed form walks in
  mid-air. On the exact frame the transform becomes authoritative
  (animation-done for revival items, `TRANSFORM_EVENT -> TRANSFORMED`
  edge for command-triggered transforms), call
  `_reset_viper_jetpack_state()` (Viper only) and
  `apply_equipment_paddle_modifiers()` so the paddle snaps to the
  floor baseline under the transformed scale. If the transform also
  repositions the ball (e.g. `BALL.centery = PLAYER.top - 20`), do
  the landing reset BEFORE the ball reposition. Full code-location
  checklist lives in `docs/item_runtime_checklist.md` §7.
- **Chained revival transforms must release the prior form's active
  state when a later revival takes over.** Yachaman Soul (passive)
  and Odin's Eye (legendary) both revive on score loss, and Odin's
  Eye is checked first in the loss handler. If Odin's Eye revives
  while Yachaman is already active, Odin's success branch returns
  before the Yachaman block runs, so `yachaman_active` and
  bomb-spin visuals stay True. When the Odin's Eye form then dies,
  only `odins_eye.reset_for_new_round()` runs in the death-anim
  complete block, so `yachaman_active` leaks into the next round
  and the player re-appears as Yachaman instead of the original
  character. Fix in two places: (a) at Odin's Eye revival takeover
  (regular + deuce branches), inline clear `yachaman_active = False`
  and `reset_bomb_spin()` immediately after `start_revival_animation`;
  (b) at Odin's Eye death-anim complete, call
  `yachaman_soul.reset_for_new_round()` alongside the odin reset so
  `*_used_this_round` flags are cleanly re-initialized. Full
  checklist in `docs/item_runtime_checklist.md` §7.7.
- **Freeze actors that zero `ball_vel` must be aware of each other's
  snapshot paths.** If actor A is mid-freeze and has `ball_vel ==
  [0, 0]`, any actor B that does `snapshot = ball_vel.copy()` during
  its own activation will persist zero as the "original" speed, and
  its recovery ramp / restore path will leave the ball permanently
  stopped. Current freeze actors that zero or hold `ball_vel`:
  `yachaman_soul`, `odins_eye`, `horn_strawberry_mask` transform,
  `smartphone`, `stopwatch`, viper DMK wall-dive freeze, and the perk
  selection resume safety timer (`_perk_resume_original_ball_vel`).
  Two safe patterns: (a) defer actor B's activation so it cannot fire
  while actor A is zeroing `ball_vel` -- the perk safety timer does
  this by only arming after the last queued perk choice, so chained
  perk picks do not corrupt each other; (b) make actor B prefer an
  upstream actor's saved original when its own read shows near-zero
  -- `stopwatch` falls back to `_perk_resume_original_ball_vel` if it
  activates mid-freeze. When adding a new freeze actor, audit BOTH
  directions: "does my snapshot survive an existing freeze being
  active?" and "does every existing freeze actor's snapshot survive
  mine?"
- **Freeze actors that zero `ball_vel` must also extend the existing
  physics collision / hold guards, not only flag their own state.**
  When an activation zeros `ball_vel` while the ball's position
  already overlaps the player paddle (common for mid-rally modals
  such as perk pick, since the hook fires whatever frame the modal
  closes), the next frame's regular collision path will reflect the
  stationary ball upward and effectively cancel the freeze after a
  couple of frames. Stopwatch gates four separate physics spots on
  `stopwatch_active and stopwatch_timer > 0`: main player-paddle
  collision, `handle_ball()` hold branch, smartphone / floor-bounce /
  score handlers, and the backup paddle-collision path. Any new
  freeze actor (perk-resume safety, future modal-pause freezes) must
  extend each of those guards with its own "in freeze" predicate, or
  the ball will jump out of the freeze on pre-existing overlap.
  Setting a short one-shot `player_collision_cooldown` at activation
  also helps cover the initial overlap edge before the per-frame
  guards take effect.
- **Godot ball-owning skills must clear `skip_ball_motion_step` on every
  release path.** If a skill hides, captures, teleports, or manually
  advances the ball by returning `skip_ball_motion_step=true` and often
  `ball_vel = Vector2.ZERO`, then every resume / release / final-fire /
  cancel path must explicitly return `skip_ball_motion_step=false` plus a
  real resumed velocity where play should continue. This applies even when
  the skill remains active after a short teleport. The Ghost Shot regression
  is the reference failure: a performance teleport and final fire restored
  position / velocity but left the shared skip flag stuck, so the ball
  appeared stopped. In the Godot renderer, the true -> false transition also
  drives `ball_render_interpolation.gd`'s one-frame interpolation reset, so a
  missing release now risks both frozen motion and visible high-refresh
  rubber-banding. Keep a focused Godot smoke like
  `smasher_ghost_shot_motion_skip_smoke.gd` for any character skill that
  owns this flag.
- **Godot ball-owning skills must preserve intentional paddle contact while
  `skip_ball_motion_step` is true.** The shared skip flag bypasses normal
  `BallMotionCollisionDetector` / paddle-bounce processing, so cleanup is
  not enough. If an owned-ball phase can visually overlap the player or boss
  paddle, add a release / bounce path that reuses or mirrors the normal
  paddle context (`hitbox_padding`, `player_collision_cooldown`, mirror /
  clone rects, dash / jetpack / warp / stopwatch recovery context, expanded
  paddle hitboxes). Smoke-test descending overlap, horizontal slide / hover
  at the paddle Y-band, and upward overlap after freeze / recovery. The
  Hongryun Inferno guard regression is the reference failure: the inferno
  owned the ball and skipped normal motion, while its local collision was too
  narrow, so the ball visibly slid along the player Y-band without a paddle
  hit.
- **The same `skip_ball_motion_step` bypass also disables every
  floor-level / mid-field interception that normally lives inside
  `step_motion()` — not just paddle bounce.** When an owned-ball phase
  skips motion, it also skips `BallMotionCollisionDetector.check_holy_barrier`,
  `check_horn_strawberry_field`, brick-wall, laurel-leaf-shield, and mythic
  adversity-armor checks. So a floor-invincibility active item can be silently
  ignored and the player loses through an "invincible" floor. The Hongryun
  Inferno × Holy Barrier (홀리베리어) loss is the reference failure: the
  inferno trail owned the ball and resolved its own floor-miss
  (`_try_resolve_stage5_hongryun_floor_miss`) without ever consulting the
  active holy barrier, so the ball punched through the invincible floor.
  Standing rule: any owned-ball skill that resolves its OWN floor/score
  outcome while `skip_ball_motion_step` is true must first replicate the
  relevant `step_motion()` barrier checks (geometry from the same
  `holy_barrier_y` / `holy_barrier_height` / field-width context keys),
  reflect + release to normal physics on a hit, and call the same runtime
  notifier (`active_item_runtime.notify_holy_barrier_hit`, etc.). Mirror the
  existing paddle-guard ordering: player guard → floor-save barrier → loss.
  Do NOT gate the barrier catch on instantaneous `ball_vel.y > 0`; an owned
  ball oscillates, so use geometric band intersection and `-abs(ball_vel.y)`
  for the upward reflection, or a single wobble-up frame at the band bottom
  leaks straight into the floor-miss. The reference guard +
  `resolve_inferno_holy_barrier` release live in
  `ball_update_controller._try_release_stage5_hongryun_holy_barrier`, sealed
  by `stage5_hongryun_holy_barrier_motion_skip_smoke.gd`. Audit the same hole
  for horn-strawberry field and brick wall when porting future owned-ball
  boss skills.
- **Owned-ball release handoffs must survive the update_effects-only pause
  windows.** `battle_frame_flow_controller` has modal pause branches (mythic
  acquisition cinematic / baal boots / pandora selection / horn strawberry via
  `mythic_item_runtime.should_pause_game`, scoreboard active, stage3 kuromi
  awakening, psychoball hitstop) that keep calling `update_effects` every
  frame while skipping `update_ball`. A skill state machine ticked from the
  effects path can therefore expire, queue its pending release, AND have a
  later fade/reset wipe that pending token — all while the only
  `skip_ball_motion_step=false` consumer (the ball-motion path) is paused.
  The wiped release leaves the shared skip flag stuck true forever: frozen
  un-hittable ball, no collision, no scoring, permanent softlock. Reference
  failure: Chaos Spear blackhole × mythic acquisition cinematic (blackhole
  180f + fade 25.2f ≈ 3.4s completes behind the cinematic; the fade-end reset
  wiped `chaos_release_pending`, `needs_ball_motion_update()` then gated the
  motion pass shut, and the paddle rescue was dead behind its
  `chaos_state == "blackhole"` gate). Fix pattern = two layers. (1)
  Self-healing ownership token (`chaos_ball_motion_owned`): set when the
  skill emits skip=true from the ball path, added to the motion-pass
  necessity gate, consumed on the next ball pass; the heal fires only when
  the scene flag is actually still true. The token survives ONLY the
  fade-end natural reset that wipes an unconsumed pending release
  (clear_command=false AND pending armed — the pause-wipe case, where the
  skill is provably the sole flag owner); every explicit round/context reset
  (clear_command=true, even if a pending release was armed moments earlier)
  and every early-hit release drops the token, so the heal can
  never stomp a fresh serve or another concurrent owner's hold (Poseidon
  capture / stage5 inferno — stage5's hijack also overwrites the flag BEFORE
  the viper motion pass each frame, so a broadly-surviving token would steal
  its hold). (2) Round normalize layer:
  `ball_round_state.build_common_snapshot` resets
  `skip_ball_motion_step = false` in every round reset/serve snapshot — no
  hold may legitimately survive a round boundary, and owned-ball teardowns
  can happen without their ball-path release ever running (this also covers
  the poseidon `clear_runtime` latent leak class). Sealed by
  `chaos_spear_hit_release_smoke._test_mythic_pause_expiry_self_heals_motion_skip`
  + `_test_self_heal_noop_when_flag_already_released`
  + `_test_round_reset_scopes_ownership_and_normalizes_skip`. When auditing a new
  owned-ball skill against this trap, check the structurally-immune sibling
  patterns first: (a) the state machine ticks only on the ball path (Smasher
  ghost shot) or only on a driver that pauses together with the ball
  (`update_lingpet` is skipped by every pause branch); (b) the release is
  computed AND applied to the owner inside the same effects tick via the
  effects result applier (Commando bowling trap, stage3 kuromi spit, stage5
  hongryun); (c) the pending-release token survives until consumed and is
  never wiped by an FX/timer cleanup (stage4 ponk meditation). A skill that
  matches none of these needs the ownership-flag self-heal.
- **Godot boss-side strong knockback handlers must signal
  `suppress_paddle_hit_knockback` on the same frame.** `boss_ai_state.start_paddle_hit_knockback`
  takes `replace_current=true` from every caller, so the regular paddle hit
  knockback applied by `paddle_bounce_event_router._apply_paddle_hit_knockback`
  during `register_rally_feedback` will OVERWRITE any stronger knockback
  queued earlier in the same frame from `paddle_bounce_boss_post_hit_handler`.
  Any post-hit handler that calls `start_paddle_hit_knockback` with a
  special / fire-style velocity (kick guard, bowling trap guard, future
  shoulder slam / charge perks, etc.) must return a consumed-flag in its
  result dict, the boss-post-hit handler must propagate that flag, and
  `paddle_bounce_post_hit_handler` must set `context["suppress_paddle_hit_knockback"] = true`
  before `register_rally_feedback` runs. The Viper kick_enhance Lv3+
  knockback ball regression is the reference failure: the visual overlay
  rendered (~57 px/frame queued) but the regular paddle knockback (~13 px/frame)
  immediately overwrote it because the suppress flag wasn't wired, so the
  player saw the special ball but felt only the regular knockback.
  `commando_bowling_trap_guard_hit` is the canonical correct precedent.
- **Wall-clock active-item cooldowns leak through internal-event-loop
  modals.** Active item slot cooldowns are checked against
  `pygame.time.get_ticks() - last_item_use_time` (and per-item
  `item["last_use"]`), so they advance in real time. Modals such as
  `show_runtime_skill_choices()` and `show_stage_clear_choices()` run
  their own `local_clock.tick(60)` loop that pauses the main game loop
  but NOT wall clock, so any cooldown that was mid-recharge when the
  modal opens silently ticks down (or fully expires) while the player
  is picking a perk. Frame-counter cooldowns (`dash_cooldown -= 1` etc)
  pause naturally because they live inside the main loop; wall-clock
  anchors do not. Fix is at the modal call site: capture
  `pygame.time.get_ticks()` before the modal call and call
  `_shift_active_item_cooldowns_after_modal_pause(open_ms)` after it
  returns so the anchors shift forward by the modal's duration. Any
  new internal-event-loop modal (perk choice, stage-clear choice,
  future pause overlays) must do the same shift, and any new
  wall-clock-anchored cooldown system (Optimus-style `until` timestamps,
  per-item `last_use`, etc.) must either be added to that helper or
  freeze through an equivalent shift.
- **Boss-skill / boss-event state cleanup must happen in `show_result()`,
  not only in `go_to_next_round()`.** The score-loss handler in
  `pingfighter.py` only calls `go_to_next_round()` for ongoing rounds.
  When `check_deuce_system()` returns `boss_win` (or `player_win`), the
  branch runs `show_result(False)` (or `show_result(True)`) and
  `return`s WITHOUT calling `go_to_next_round()`. So any boss-owned
  globals that persist visible / physical state across rounds must be
  reset BOTH in `go_to_next_round()` (per-round path) AND in
  `show_result()` (game-end path). Otherwise the global stays alive
  after the game ends and the next new game inherits stale state even
  though the player is back on Stage 1. Two failure classes seen so
  far: (a) **ball-physics hijack** — legacy Honglyeon / current Godot Stage 5 홍련폭염
  (`flame_trail_active` + `flame_trail_*` + `fireballs` +
  `boss_throwing` + `hongryun_hit_count` + `hongryun_ready` +
  `animated_bg_stage5.set_inferno_mode(False)`) where the global
  hijacks per-frame ball updates; (b) **summoned-entity / event
  state leak** — Stage 2 두더지왕 친구두더지 (`friend_moles_pending` +
  `friend_moles_active` + `friend_moles_triggered` +
  `friend_moles_round_count` + `friend_moles_list` +
  `friend_moles_dirt_particles` + `friend_moles_*_timer` +
  `friend_moles_all_golden` + `friend_moles_spawn_total_count`) where
  leftover minions / dirt particles render in the next session as soon
  as the player re-enters that stage, because the renderer
  (`draw_friend_moles()` in the Stage 2 branch) does not gate on
  boss name. The same trap applies to any future boss skill or
  boss-summoned hazard that appends to `_stage6_ball_last_hold_reasons`,
  sets `ball_vel = [0, 0]` for a charged release, routes per-frame
  ball updates through its own branch, or maintains a list of
  spawned minions / projectiles / persistent VFX that survives across
  rounds via globals (whip / psycho / curse_chest / cotton_* are
  already handled in `show_result()` — use that pattern). Audit by
  comparing the `flame_trail`/`hongryun`/`friend_moles`-style reset
  block in `go_to_next_round()` against the same variable's reset in
  `show_result()`; any boss-skill or boss-event reset present in only
  one path is a latent leak. Stage-init resets in `main()` that are
  gated on `current_stage == N and current_boss_name == "X"` do NOT
  count as a substitute, because at game-start `current_stage` is 1
  and the gate is False.

  Godot Honglyeon ports must start from a single owner cleanup method
  (for example `stage5_hongryun_state.reset()` / `clear_all()`) and call
  that same method from round-end, result / game-end, and stage-leave
  paths. Do not split `flame_trail_active`, `fireballs`,
  `boss_throwing`, `hongryun_hit_count`, or `hongryun_ready` cleanup
  across separate call sites.

Full per-tier checklists, hardcoded-list audits, and the smoke test
live in `docs/item_runtime_checklist.md`.

### Default assumptions for new item requests

When the user asks to add a new item and provides only the item's
specification (name / body part / description / roll option / theme),
do NOT stop to ask routine follow-up questions unless the request is
truly ambiguous in a way that would materially change gameplay design.

Default assumptions:

- A new item request means **end-to-end work** by default:
  visual asset creation, runtime registration, acquisition-path wiring,
  UI / inventory / developer-mode sync, reset handling, and verification.
- New item names default to **snake_case** in code, even if the user
  provides a Korean display name only.
- If the user does not specify an unlock condition, default to
  **unlocked by default** (`unlocked_items["name"] = True`).
- Ordinary active and passive items default to **no duplicate farming**.
  Only add the item to `PASSIVE_DUPLICATE_ALLOWED` when the design
  explicitly calls for duplicate roll-farming.
- If duplicate farming is explicitly enabled, verify it **per
  acquisition path** before reporting it as done. Field drops,
  Pandora / treasure routes, and stage-clear gacha may intentionally
  behave differently.
- A passive item with a valid body-part slot should default to the
  established behavior: on acquire, if that body-part slot is empty,
  the item should auto-equip into that slot.
- If the user asks for item addition, assume the matching item visual
  should also be created unless the user explicitly says runtime only.
- If the user asks to regenerate or replace an item icon, assume the
  follow-up includes one runtime sanity check that the new file path is
  the asset actually being loaded, not just that the PNG was written to
  disk.
- "Skill cooldown reduction" defaults to **player skill-system cooldowns**,
  not active-item cooldowns, unless the user explicitly says otherwise.
  Active-item cooldown reduction is treated as a separate category.
- "Skill cooldown reduction" (`스킬 쿨타임 감소`) defaults to the
  cooldowns of the **left-side 5-orb player skill HUD** for **all five
  playable characters**: Smasher, Viper, Soldier / Commando,
  Blacksmith / Baltor, and Optimus.
- This includes both **base skills** and **skills unlocked through
  character-exclusive perks** (`unlock_*` style additions).
- This does **not** include active-item cooldowns unless the user
  explicitly says item cooldown / active cooldown.
- Do not forget Optimus: its cooldown path uses a different
  until-timestamp mechanic and may not appear in the same reduction
  chain as the other four characters.
- If an item or perk changes those cooldowns, assume the **HUD display
  must change with it**: orb countdown text, cooldown wedge timing,
  and skill tooltip cooldown text should all show the final effective
  cooldown, not the base data value.
- If an item belongs to an existing body-part family (head / top / arm /
  belt / knee / shoes / back / accessory), follow that family without
  asking for confirmation. If the slot family does not exist yet,
  extend the existing system in the most consistent minimal way and
  report the assumption afterward.
- If an item needs an equip visual, assume the runtime hand-off must
  name both the **gameplay body-part family** and the **visual overlay
  slot**. They are often related but not interchangeable.
- Prefer existing repo patterns over asking the user to choose between
  multiple routine implementation variants.

Only ask a clarifying question when one unanswered choice would create
a genuinely different gameplay identity, balance target, or system scope.
Otherwise, make the most conservative repo-consistent assumption and continue.

---

## Character Skill / Perk Work (Godot-first; legacy Python paths are reference-only)

Any work on **runtime character perks / skills** -- adding or modifying
character-exclusive perks, unlock-style perks such as `unlock_*`,
player-skill / 5-orb HUD entries, active-skill tooltip text, effective-
level behavior under `transcendent_crown` or `sage_ring`, cooldown HUD
sync, duration / timer HUD sync, skill-specific gold bonus policy, or
save/load/reset handling for character skill state -- must be
handled via **`docs/character_skill_perk_checklist.md`**.

That checklist is the single source of truth for the code locations and
verification path required to land runtime character skill work cleanly.
Legacy Python names in the sections below (`draw_skill_icon_mini()`,
`pingfighter.py`, old perk pools, and old tooltip functions) are hidden-
knowledge references for porting and parity. Current implementation belongs
under `godot/` unless the user explicitly asks for original PingFighter edits.

Companion-rule split:

- **`docs/character_skill_perk_checklist.md`:** end-to-end runtime
  integration checklist for character perks / skills, including unlock /
  equip flow, 5-orb slot behavior, academy / NPC offer flows, actual
  gameplay effect wiring, skill-gold reward wiring,
  tooltip sync, duration-bar HUD sync, effective-level QA, save/load,
  and reset.
- **This file (`CLAUDE.md`):** hidden-knowledge rules that are easy to
  miss while following the checklist, especially the `draw_skill_icon_mini()`
  trap, the seven perk / skill text render paths, and the final-cooldown
  HUD rule.
- **`AGENTS.md`:** top-level Godot-first routing and shared guardrails.

**If the checklist is not already open, explicitly open it before
proceeding.** Do not recreate character perk / skill integration rules
from memory.

### Hidden-knowledge rules for academy / NPC perk-offer UI

These are easy to miss even when the runtime checklist is open:

- **Visit-scoped offer caching needs both `offered` and `consumed`
  state.** Caching only the proposed perk blocks free rerolls, but it
  does NOT stop the same visit from purchasing / swapping a second time
  after success. Same-visit post-success state should become
  "already taught / exhausted" until the manager resets the visit cache
  on re-entry.
- **`ownership` and `equipped` are different concepts for unlock-style
  active skills.** Any academy / NPC "show an unowned skill" flow must
  filter against "ever unlocked / owned", not merely "currently not
  equipped", or old swapped-out skills can reappear as false-new offers.
- **Canceled slot-full swap must be a true no-op.** If taking an
  unlock-style perk can open a swap dialog, do not write
  `runtime_skill_levels`, unlock flags, ownership registries, or weapon
  inventory before the dialog returns a successful swap result. Cancel
  should leave the player's state untouched.
- **Nested interior modals must refresh the background after the launcher
  dialog closes.** If a confirm dialog opens a second modal and that
  second modal snapshots the old frame, the first dialog can remain as a
  dim ghost behind the new UI. Redraw the interior first, then open /
  snapshot the child modal.
- **Mouse and keyboard menu paths often diverge on flag clearing.** If a
  flow uses `open_*_requested` or similar one-shot signals, audit both
  click handlers and key handlers. A fix only in the keyboard path is not
  enough.
- **Settings screens can have multiple live entry points.** Before handing
  a settings / options task to Codex, confirm which screen the player
  actually reaches (`start_menu.py` main-menu settings, `option.py`,
  pause options, helper settings UI, etc.). A patch to an unused or
  dormant settings screen is not a valid accept state.
- **Use the visible UI strings to find the live screen.** When a report is
  "the BGM/SFX/settings screen still does not show X," search for the
  actual on-screen labels / tab names (`BGM 볼륨`, `효과음 볼륨`,
  `사운드`, `설정`) and trace the reachable call path instead of assuming
  a legacy `option.py`-style module is the active menu.
- **Silent font/resource failure can make the whole dialog look blank.** A
  helper that catches render/load exceptions and returns `None` without a
  visible fallback can hide a bad font path entirely. For current Godot Korean
  UI, verify the actual `res://` font/resource path and keep a visible
  fallback before trusting the dialog. Legacy Python used `resource_path()`.
- **Repo font reality beats guessed subpaths.** Verify the actual font asset in
  the current Godot project or legacy repo before choosing a path. Do not
  assume a `fonts/` subpath exists just because another module used one.
- **When helper modules mutate `pingfighter.downtown_gold`, manager-side
  player state must be resynced after the modal closes.** Otherwise the
  next manager tick or exit path can overwrite the spent / gained value.
- **New active skills should not silently inherit "no gold" as the
  default.** If a skill creates a distinct owned reward moment -- ball
  hit, boss hit, object absorb, sustained field tick, release burst, or
  similar -- decide an explicit gold policy. The normal default is an
  intentional reward sized against comparable same-character skills;
  zero-gold should be an explicit design choice, not an omission.
- **Skill gold belongs on the real owned event path, not the animation
  start.** Wire the reward where the skill actually hits / absorbs /
  consumes, and audit all alternate branches that can reach the same
  result so the reward is neither skipped nor double-paid.
- **Skill gold can silently stack with generic rally gold if the local
  duplicate-prevention path is missed.** When adding or modifying a
  skill-owned gold bonus, also inspect the generic rally-gold path and
  any character-local same-frame guard / hit-consume flags so one skill
  event cannot pay twice through primary + fallback logic.
- **Combo-window skills need a predecessor trigger matrix, not a single
  happy-path cast test.** If a skill can be opened by prior hits,
  follow-up windows, return-motion handoffs, cancels, or multiple named
  predecessor skills, list every predecessor and verify opener event,
  input priority, window lifetime, consumption, expiry, and focused smoke
  coverage. Viper Dark Blade is the reference trap: Air Blade coverage
  alone does not prove Shadow Step, Marshal Kick, Phantom Kick, and
  Hwarang/Core Flip hit paths are wired. For Dark Blade follow-ups, audit
  both update paths: the Air Blade phase-2 branch and the `blade_dark_mode`
  phase-2 branch in `viper_skill_blade_motion_runtime.gd`; wiring only the
  Air Blade side misses Dark Blade -> Venom Edge and predecessor routes that
  converge through `blade_dark_mode`. The matrix must also include
  window-INVALIDATION events, not just openers: if the original clears a
  stale chain window when a NEW predecessor cast starts ("이번 킥으로
  공을 맞춰야만 오픈" — pingfighter.py marshal/phantom start clears
  `_viper_dark_blade_window` + core-flip handoff), a port that wires only
  the open sites leaves stale windows alive through the new cast,
  especially when a keep-alive flag like `marshal_active` holds the
  window open. Reference fix: `viper_skill_marshal_kick_runtime.start_kick`
  stale-window clear + `viper_marshal_kick_port_smoke.gd`
  `_test_new_kick_start_clears_stale_dark_blade_window` (asserts the
  cleared window does NOT fire on the chain key pre-hit, and THIS kick's
  hit re-opens it). A SECOND invalidation class is WHIFF / timeout on the
  OPENER itself: if the opener arms a long-lived FALLBACK hit path whose
  success opens the chain (shadow_step arms a ~5s paddle-hit window
  `shadow_kick_ready` that, on hit, schedules the Marshal Kick chain), the
  original DISARMS that fallback the instant the opener's short strike buff
  expires WITHOUT a hit (pingfighter.py:106225 —
  `_viper_phantom_strike_timer <= 0 and not _viper_ss_hit_consumed ->
  _viper_ss_kick_ready = False`, comment "헛방질 시 패들 히트 경로도 차단
  (마샬킥 카운터 오활성화 방지)"). A port that wires only the ARM site leaves
  the fallback live for the whole timeout, so an unrelated later paddle bounce
  fires the opener hit and falsely opens the chain — user-visible as "쉐도우
  백스텝이 헛발질했는데 몇 초 뒤 공에 맞으면 마샬킥 연계가 열린다". Reference
  fix: `viper_skill_shadow_step_runtime._update_phantom_strike` whiff-clear
  (mirrors the Python line above) + `viper_shadow_step_port_smoke.gd`
  `_test_whiff_does_not_open_marshal_via_paddle_hit` (reverse-verified to FAIL
  on the un-cleared code). The regression smoke MUST reproduce the whiff (opener
  misses — only tick the strike buff to expiry, never run the wave/hologram/
  immediate hit) and then prove a later paddle bounce neither consumes an opener
  hit nor schedules the chain; a happy-path "opener hits -> chain opens" test
  passes even with the bug present.
- **Transparent-canvas overlay trap on copied runtime surfaces is real.**
  If a glitch clone, afterimage, low-HP variant, or other runtime copy is
  built from `base_surface.copy()` plus `BLEND_RGB_ADD` /
  `BLEND_RGBA_ADD`, any tint / noise / scanline / fade overlay applied to
  the whole canvas can light up the fully transparent margin and render as
  a visible rectangular box in gameplay. Mask or clip each overlay to the
  visible sprite silhouette before blitting, and live-check the weakest /
  faded state in-game instead of trusting the normal full-opacity state.
- **Large acquisition/showcase icon scaling can reveal box residue even when
  the HUD looks fine.** A raw icon with too much transparent padding or a
  faint leftover background can look acceptable at 24 px HUD scale but turn
  into a square/rectangular ghost when enlarged in pickup, treasure, or
  legendary-acquisition effects. For icons intended to appear in big reveal
  UIs, trim to visible bounds, re-center on a clean transparent canvas, and
  QA the enlarged acquisition presentation rather than trusting the small HUD
  alone.
- **In-game pause modals should default to a frozen `SCREEN.copy()`
  snapshot as their background, not a live stage re-render.** The
  helper `_render_stage_background_for_overlay()` looks like it
  renders the current gameplay frame, but it actually draws only
  the stage background plus paddles and ball. Field items, projectiles,
  particles, HUD timers, pillars, and many stage-specific effect
  layers are NOT rendered by it, so a modal that opens against a
  "live" background will briefly look like a stripped-down copy of
  the scene -- the player sees a one-frame "different screen" flash
  as the previously-visible content disappears. `show_runtime_skill_choices()`
  takes a `live_background` parameter for this reason, and the
  mid-gameplay starpoint trigger passes `live_background=False`
  so the captured snapshot is used. Live background mode is only
  appropriate right after a sequence that was already rendering the
  live stage (e.g. victory / stage-clear effects in
  `show_*_victory_effect()`). When adding a new pause modal or
  overlay that can trigger mid-round, default to the snapshot path.

### Hidden-knowledge rules for orb-slot / stage-transition integration

These came out of the Commando firearm overhaul and apply to any future
character that joins the 5-orb system or gains multi-path skill
acquisition. They are easy to miss even when
`docs/character_skill_perk_checklist.md` is open.

- **When a new character (or a new unlock skill) joins the 5-orb system,
  the cooldown-reduction scope expands with it.** `transcendent_crown`,
  `sage_ring`, and any generic cooldown-reduction perk / effect that
  applies to character orb skills must also apply to the newly
  orb-registered skills. Orb wedge fill, remaining-time text, and tooltip
  cooldown text must all read the final effective cooldown after
  reductions, not the raw constant. Optimus uses an `until`-timestamp
  path, so audit it separately even when the other characters share a
  common reduction chain.
- **Active-skill enhancers need target-tooltip sync, not just perk-card
  text.** If an invested passive changes another orb skill's prep,
  duration, projectile size, hidden damage / speed multiplier, clone HP,
  super armor, combo scaling, or similar runtime-only behavior, the
  target orb tooltip should expose that change in a concise synergy lane
  using live effective values. Updating only the perk choice card or the
  perk detail panel is not enough once the player is in a match.
- **Character knockback should start from the shipped fire-event
  baseline, not a brand-new ad-hoc path.** If a perk / skill adds boss
  or player knockback -- especially guard reactions, special-ball
  follow-up knockback, or hit-confirm knockback bonuses -- prefer the
  existing fire-event velocity / timer / decay / hitstop channels as the
  gameplay baseline and tune multipliers from there. Viper
  `kick_enhance` guard knockback is the current reference pattern. If a
  design truly needs a different feel, document that exception in
  gameplay code, tooltip text, and the runtime checklist notes instead
  of silently forking a parallel knockback system.
- **Radial CC hit geometry must name its primitive, not inherit the
  prettiest overlap helper.** Commando bazooka, grenade-style fire
  support, and suicide drone boss CC use boss-center distance in the
  Python reference. In Godot, do not let a visual blast circle touching
  the boss rect edge become a stun / slow / knockback hit unless the
  design explicitly calls for rect overlap. Add an edge-only regression
  case whenever a radial status path is added or ported.
- **Duration-type orb skills need shared timer-bar HUD sync, not only
  gameplay state.** If a character skill or buff gives the player a
  meaningful active-duration, startup-hold, or timed-persistence window
  to track, default to the existing right-bottom horizontal timer-gauge
  stack used by shipped duration bars. Match the established size, stack
  behavior, and cleanup semantics instead of inventing a bespoke timer
  widget unless the user explicitly asks for different UX.
- **Procedural curved VFX need rotated cross-sections, not only shifted
  centers.** For runtime-drawn fan / wave / slash projectiles that are
  meant to read as homing or snake-curved, moving only each point's X
  center while leaving Y and the cross-section horizontal still reads as
  a vertical projectile sliding sideways. Build a centerline from tail
  to head and rotate each slice / arc cross-section along that curve's
  tangent. For a rightward bend, the right arc corner should land lower
  on screen and the left arc corner higher; add a small geometry test for
  that invariant when this class of helper is touched.
- **`reset_round()` and the real stage-transition hook are not
  interchangeable.** `reset_round()` fires every lost-point round.
  Resets that should only happen on stage boundaries -- rental /
  temporary holdings cleanup, permanent-resource ammo refill,
  once-per-stage flag clear -- must be attached to the actual
  stage-advance path (`current_stage += 1`, `current_stage = stage_num`,
  or the stage-start hook), never to `reset_round()`. Otherwise they
  silently re-fire on every lost point.
- **`*_SKILL_ICONS_DATA` is a metadata table, not the visible-order
  truth.** `SOLDIER_SKILL_ICONS_DATA`, `SMASHER_SKILL_ICONS_DATA`, and
  `VIPER_SKILL_ICONS_DATA` describe orb-capable skill metadata; the
  actually visible orb lineup and slot order are driven by
  `_*_equipped_skills`. Renderers that iterate over `*_SKILL_ICONS_DATA`
  directly, or trust `len(*_SKILL_ICONS_DATA)` as the slot count, break
  the moment the character gains dynamic equip / unequip / swap flow.
- **5-orb "slot full" checks must count shared-slot occupancy, not only
  one skill category.** If a character mixes multiple shared-slot skill
  types (for example permanent firearms plus a passive orb like
  `soldier_pistol_perk`), the fullness test must count every skill that
  occupies the shared slots. Counting only one subtype silently reopens
  perk-choice offers that no longer fit in the orb budget.
- **Skill icon registries carry runtime slot semantics, not only art
  metadata.** Every entry in `_SMASHER_ORB_ICON_REGISTRY`,
  `_VIPER_ORB_ICON_REGISTRY`, `_OPTIMUS_SKILL_ICON_REGISTRY`,
  `BLACKSMITH_SKILL_ICON_REGISTRY`, and `_SOLDIER_ORB_ICON_REGISTRY`
  must declare `slot_occupancy`, `cooldown_reduction_eligible`, and
  `cleanup_policy`. Keep the current matrix unless a design explicitly
  changes the runtime model:

  | Registry family | `slot_occupancy` | `cooldown_reduction_eligible` | `cleanup_policy` |
  |-----------------|------------------|-------------------------------|------------------|
  | Smasher active / unlock orbs | `active_orb` | `True` | `perk_id_lookup` |
  | Viper active / unlock orbs | `active_orb` | `True` | `perk_id_lookup` |
  | Optimus framed skill-card icons | `active_orb` | `False` | `perk_id_lookup` |
  | Baltor / Blacksmith active icons, including `hammer_shock` | `active_orb` | `True` | `perk_id_lookup` |
  | Soldier `supply_drop`, `emergency_supply` | `base_fixed` | `True` | `base_only` |
  | Soldier permanent firearm shared slots | `shared_slot` | `True` | `shared_swap` |
  | Soldier `commando_pistol` from `soldier_pistol_perk` | `passive_orb` | `True` | `perk_id_lookup` |

  `slot_occupancy` tells slot-full and overflow logic which budget owns
  the skill. `cooldown_reduction_eligible` records whether generic
  player-skill cooldown reduction should apply; Optimus is the current
  opt-out because its skills use a separate timestamp-style trigger
  path. `cleanup_policy` records which removal path is allowed: base
  skills are never removed, shared Soldier slots must flow through shared
  swap cleanup, and normal active / unlock aliases must derive the old
  perk id from `_CHARACTER_UNLOCK_PERKS`.
- **Soldier permanent firearms have both an orb cooldown and an item
  instance cooldown.** When `net_gun`, `bowling_trap`, `bazooka`, or
  `ak47` is used as a permanent shared-slot skill, sync the live item
  instance through `_apply_soldier_firearm_cooldown_frames()` before the
  `can_fire()` / `can_install()` gate. Otherwise the HUD can show the
  reduced orb cooldown as ready while the item instance still rejects the
  click on its raw cooldown timer.
- **Soldier `shared_swap` cleanup must use `_perform_skill_swap_cleanup()`.**
  Heavenly-cape overflow, academy swap, and any future shared-slot removal
  cannot just pop the equipped skill or `runtime_skill_levels[skill_id]`.
  The cleanup path must derive the owning perk id from
  `_CHARACTER_UNLOCK_PERKS["soldier"]` and clear runtime level, unlock
  flag, weapon ownership, and controller inventory together.
- **A once-per-stage active flag must be persisted across save/load
  within the same stage.** Cooldown wedges alone do not guarantee
  "once per stage"; loading a save after using such a skill must
  restore the spent / disabled state until the next real stage
  transition, and stage-advance must clear it.

---

## Legacy Stage Order Reference + Current Godot Decision

This section records two separate facts that must not be collapsed:

1. The frozen Python/Pygame source has a historical Stage 5 / Stage 6
   naming mismatch.
2. The current Godot porting decision is to exclude original Nemesis for
   now and make original Honglyeon the user-facing Godot Stage 5.

Current Godot rule:

- `current_stage == 5` is **Stage 5 Honglyeon / 홍련**.
- Original Nemesis / ocean / battleship content is excluded from the
  current stage sequence unless the user explicitly reopens it.
- Do not add a new Stage 6 **Honglyeon** route in Godot (Honglyeon stays at
  Stage 5). The stage-order decision for slot 6 has now been made
  (2026-06-03): **Godot Stage 6 = 테트리서 / Tetriser**, a port of Python
  Stage 7 (`current_stage == 7`, `stage7_*`, `AnimatedBackgroundStage7`).
  See `docs/stage6_tetriser_port_plan.md`. This **supersedes** the earlier
  "Stage 6 stays absent / unselectable" rule — Stage 6 is now an active
  Tetriser slot, not an empty one.
- When copying legacy Honglyeon assets into Godot, rename them to
  `stage5_hongryun_*` (for example under `godot/assets/...`). Do not keep
  Python `stage6_hongryeon_*` filenames as live Godot asset names. Leave
  the old source path in the module header, manifest, or asset note.

Frozen Python reference mapping:

| Python code ID | Legacy code names | Theme / boss | Current Godot use |
|---|---|---|---|
| `STAGE_HONGLYEON_FIRE = 5` | `stage5`, `animated_bg_stage5`, `Stage5ChineseMarket` | Honglyeon / Chinese fire | Port to user-facing Godot Stage 5 |
| `STAGE_NEMESIS_OCEAN = 6` | `stage6`, `animated_bg_stage6`, `AnimatedBackgroundStage6` | Nemesis / ocean / battleship | Excluded / reference-only |
| Python `current_stage == 7` | `stage7_*`, `STAGE7_*`, `AnimatedBackgroundStage7` | 테트리서 / Tetriser | **Port to user-facing Godot Stage 6** (`docs/stage6_tetriser_port_plan.md`) |

Note: Godot slot ≠ Python slot for both rows — Python 6 (Nemesis) is excluded,
while Python 7 (Tetriser) becomes Godot Stage 6.

Historical Python docs or UI may still say "Stage 5 = Nemesis" and
"Stage 6 = Honglyeon". Treat that wording as legacy-only. For current
Godot work, user-facing "Stage 5" means Honglyeon unless the user
explicitly asks for the old Nemesis slot.

---

## Legacy Python Screen Coordinate Standards

This section records the original Python/Pygame coordinate conventions. Current
Godot work should follow the Godot playfield / viewport layout helpers and
owner modules; use these numbers only as parity references during ports.

**Do NOT carry the legacy `PILLAR_UI_WIDTH = 80` band into Godot as a
playfield inset.** In the Godot runtime, the playfield is the FULL 760x750
game canvas (game x=0..WIDTH), and pillar chrome is drawn OUTSIDE the game
canvas in the screen letterbox margins. Anyone clipping an intro / overlay /
cinematic to game x=80..680 in Godot is cropping real playfield pixels and is
applying a Python-only rule. The full Godot-side rule (including the safe
intro / overlay clip routing pattern) lives in `AGENTS.md` under
"Godot Playfield / Pillar / Overlay Clip Reality". Read that section before
shrinking any clip below the full game canvas.

All items, skills, projectiles, and effects must follow this coordinate
contract. Key point: the game physics area is the **full screen 0 to WIDTH**.
Pillars are only UI overlays, not physical boundaries.

```
+------------------------ 760px (WIDTH) ------------------------+
|         Physics area: 0 - 760 (ball, paddle, projectiles)    |
|                                                              |
|   +- pillar -+                             +- pillar -+      |
|   | 0 - 79   |    UI overlay drawn on top  | 680-759  |      |
|   | 80px     |    item spawn center: 380px | 80px     |      |
|   +----------+                             +----------+      |
|                                                              |
|  Ball bounces at: BALL.left <= 0 and BALL.right >= WIDTH     |
+--------------------------------------------------------------+
```

### Screen size constants (see `config/constants.py`)

| Constant                     | Value | Meaning |
|------------------------------|-------|---------|
| `WIDTH` / `INTERNAL_WIDTH`   | 760px | Physics area width (ball, paddle, effects all in this range) |
| `HEIGHT` / `INTERNAL_HEIGHT` | 750px | Screen height |
| `PILLAR_UI_WIDTH`            | 80px  | Each pillar UI overlay width (NOT a physics boundary) |
| `GAME_AREA_OFFSET_X`         | 80px  | Pillar offset (for UI placement only) |
| `GAME_PLAY_WIDTH`            | 600px | Pillar-excluded center width (for UI placement / item spawn) |

### Which width to use

| Work type                      | Width to use         | Range     | Why |
|--------------------------------|----------------------|-----------|-----|
| Effects / barriers / walls     | `WIDTH` (760)        | 0 - 760   | Ball travels full width |
| Ball bounce / paddle motion    | `WIDTH` (760)        | 0 - 760   | Physics boundary = full screen |
| Item spawn                     | `GAME_PLAY_WIDTH` (600) | 80 - 680 | Do not spawn behind pillars |
| UI element placement           | `GAME_PLAY_WIDTH` (600) | 80 - 680 | Avoid pillar overlap |
| Boss / paddle center X         | `WIDTH // 2` (380)   | -         | Center relative to full screen |

```python
# Wrong: barrier / effect uses GAME_PLAY_WIDTH -> leaves 80px gap on left
barrier_left = GAME_AREA_OFFSET_X
barrier_width = GAME_PLAY_WIDTH

# Right: barrier / effect uses full screen width
barrier_left = 0
barrier_width = WIDTH

# Right: item spawn stays within pillar-excluded area
spawn_x = GAME_AREA_OFFSET_X + random(0, GAME_PLAY_WIDTH)  # 80 - 680
```

### Y coordinate reference

| Object                   | Y       | Notes |
|--------------------------|---------|-------|
| Boss paddle              | 25      | Top 25px of screen |
| Boss hitbox bottom       | ~65     | BOSS_Y(25) + BOSS_HEIGHT(40) |
| Boss side region         | 0 - 120 | Top area where the boss acts |
| Center line              | 375     | HEIGHT / 2 |
| Player paddle            | 710     | HEIGHT(750) - 40 |
| Player side region       | 630 - 750 | Bottom area where the player acts |

### Side classification (projectiles, items)

| Side         | Y range       |
|--------------|---------------|
| Boss side    | Y < 120       |
| Neutral      | 120 <= Y < 630 |
| Player side  | Y >= 630      |

---

## Legacy Python Resource Loading and Korean Text

This section records frozen Python/Pygame resource-loading and Korean text
traps. For current Godot work, use `res://` paths, Godot font resources, and
the current Godot UI renderers; use the Python notes below only when porting
or comparing legacy behavior.

- **Legacy Python rule:** load assets via `resource_path(relative)`. Never
  hardcode absolute paths. Use `os.path.join` for path construction. This is
  what made old PyInstaller builds work on both Windows and macOS.
- Legacy Python Korean text rendered with `pygame.freetype` +
  `fonts/NanumSquareB.ttf`.
  The default pygame font does not cover Hangul.
- Open text files with `encoding="utf-8"`.
- **Decorative unicode symbols (`✦ ✧ ✺ ♛` 등)은 한국어 폰트 스택에서
  tofu 박스(`□`)로 렌더될 수 있다.** `malgungothic` /
  `NanumSquareB` 모두 BMP 기호 영역 커버리지가 들쭉날쭉해서,
  글리프가 없으면 `font.render()`가 소리 없이 네모 박스를 그린다.
  축하 배너 / 리빌 텍스트 / 타이틀 장식 등에 unicode 심볼을 넣기 전에
  실제 인게임에서 확인하거나, `pygame.draw.polygon()` 같은 도형
  그리기로 직접 장식을 만들어라. `★` (U+2605)는 대체로 안전하지만
  이것도 인게임 QA 후 확정할 것. 엘릭서 오브 마스터리 축하 배너의
  `✦` (U+2726)이 이 실패 패턴에 걸린 대표 사례다.
- **`pygame.font.Font.render(text, antialias, (r, g, b, a))`의 알파
  채널은 무시된다.** 색 튜플의 4번째 값은 텍스트 렌더 단계에서 쓰이지
  않으므로, `font.render(..., (r, g, b, blink))`처럼 써도 결과
  서페이스는 풀 알파에 가깝게 나온다. 페이드 / 블링크 / 펄스가 필요하면
  렌더 후 `surf.set_alpha(value)`를 쓰거나 `SRCALPHA` 서페이스에
  먼저 그린 뒤 블릿해라. 색 튜플의 알파 값에 의존해 텍스트를 깜빡이게
  만들려고 하지 말 것.
- **툴팁 설명문의 `\n`은 char-by-char wrap 루프가 자동으로 처리하지
  않는다.** `pygame.freetype` / `pygame.font` 모두 `\n`을 0폭 혹은
  소리 없이 무시하는 글리프로 렌더하기 때문에, `for char in description:`
  형태로 단순 문자 단위 width 측정을 하면 여러 문장이 한 줄로 flatten되어
  엉뚱한 지점에서 wrap된다 (증상: 한 문장 끝과 다음 문장 시작이 붙어
  보이거나, 뒤 문장이 앞 문장 중간에 섞여 나오는 것처럼 읽힘 -- 에어
  블레이드 `발사합니다.\n검기에` 사례가 대표). 새 툴팁에서 설명문을
  문자 단위로 wrap해야 한다면 공용 헬퍼
  `_get_wrapped_tooltip_lines(text, font, max_width, max_lines=...)`
  (pingfighter.py)를 써라. 이 헬퍼는 먼저 `\n`으로 segment를 쪼갠 뒤
  각 segment를 wrap하며, `pygame.font` / `pygame.freetype` 양쪽
  폭 측정 경로를 모두 지원한다. 직접 `for char in description:` 루프를
  새로 작성하지 말 것. 회귀 방지 테스트는
  `tests/test_tooltip_wrap.py`에 있다.

---

## Legacy Python Perk Icon Rendering (hidden elif chains)

This section explains the old Python/Pygame icon trap. For current Godot work,
map these alias and fallback issues to Godot renderers such as
`runtime_perk_icon_renderer.gd` and the relevant skill-orb renderer. Do not
edit `pingfighter.py` unless the user explicitly requests legacy-source work.

### The elif-chain trap

`draw_skill_icon_mini()` in `pingfighter.py` is a multi-thousand-line
hardcoded elif chain on `skill_id`. **New perks do not auto-render.** A
perk without an elif branch falls through to `else` and shows only the
first letter of the skill name -- which reads as a broken icon in QA.

This applies to both:
- General perks (entries in `VIPER_EXCLUSIVE_SKILLS`, e.g. `jetpack_enhance`).
- **Skill-unlock perks** with `unlock_*` prefix (e.g. `unlock_magnum_grip`,
  `unlock_plasma`, `unlock_recovery_skill`, `unlock_cleanse`,
  `unlock_ghost_shot`, `unlock_nerve_strike`, `unlock_dive_strike`). These
  live in a separate dict and are easy to forget.

Fix: add a `_MINI_SKILL_ICON_REGISTRY` entry when the icon can reuse an
existing PNG / orb-symbol path; otherwise add the bespoke elif branch
immediately above the final `else:` in `draw_skill_icon_mini()`. For
Smasher / Viper orb-backed skills, put the runtime skill id in the
character orb registry (`_SMASHER_ORB_ICON_REGISTRY` or
`_VIPER_ORB_ICON_REGISTRY`) first, then point both the runtime mini icon
and any unlock / alias mini icon at that shared entry. For Commando /
Soldier orb-backed skills, put the runtime skill id in
`_SOLDIER_ORB_ICON_REGISTRY` first, then point runtime mini icons and
unlock / perk aliases through `_CHARACTER_UNLOCK_PERKS["soldier"]`; if a
Soldier entry uses the Soldier-specific procedural renderer instead of
the generic shared symbol renderer, mark it with
`symbol_renderer: "soldier"`. For Optimus
framed skill-card icons, put the skill id in
`_OPTIMUS_SKILL_ICON_REGISTRY` and let `draw_optimus_skill_icon()`
dispatch through that registry before its legacy procedural fallback.
For Baltor / Blacksmith active icons that intentionally render through a
bespoke HUD path, put the skill id in `BLACKSMITH_SKILL_ICON_REGISTRY`
with `family: "blacksmith_bespoke"` so coverage can distinguish the
intentional exception from a missing shared renderer.
In all cases, audit
every live id alias that can reach the icon. A perk can use one id in the
perk pool and a different id in the real 5-orb HUD or unlock flow
(`double_marshal_kick` vs `phantom_kick` is the canonical failure mode).
The same alias trap applies to swap cleanup: when a removed orb skill maps
back to a different perk id, derive the old `perk_id` from the unlock map
before clearing `runtime_skill_levels` or ownership state.

For PNG-backed player-skill / 5-orb icons, the alias audit must include
the unlock card as well as the equipped orb. If the accepted art is saved
as a runtime skill PNG such as `smasher_ghost_shot_skill_orb.png`, then
`ghost_shot` and its perk-card alias `unlock_ghost_shot` must both hit an
intentional branch. The usual pattern is: `_draw_skill_icon_symbol()` and
the runtime skill id use the PNG directly; `draw_skill_icon_mini()` uses
the same PNG for the `unlock_*` id and overlays the established unlock
badge. Do not leave the `unlock_*` branch on older procedural art after
replacing the live orb icon.

```python
elif skill_id == "new_perk_id":
    ...  # pygame.draw a polished icon
elif skill_id in ("legacy_new_perk", "runtime_new_perk"):
    ...  # same bespoke icon for all live ids
elif skill_id == "unlock_new_skill":
    ...  # pygame.draw + a "+" unlock badge
else:
    symbol = skill.get("name", "?")[0]  # fallback -- means the branch is missing
```

Quality rule:
- The new branch should draw a **polished bespoke icon**, not just a
  temporary letter, flat circle, or debug placeholder. Match the visual
  richness and readability of the strongest existing perk icons at the
  actual in-game size.
- When the perk also appears in the 5-orb HUD, treat
  `_draw_skill_icon_symbol()` as a second quality pass rather than an
  optional afterthought.

### The "branch exists but still fails QA" trap

A perk icon can have the correct `elif` branch and still be wrong in-game:

- The **main subject can read too small** relative to the icon box even
  though the branch technically renders.
- One UI path can call the branch under a **different live id alias**
  than the one you tested.
- A large perk-choice card can look fine while the same icon still reads
  tiny in a 32 px perk grid, academy offer slot, or other small-box UI.

Sign-off rule:
- Audit the icon at the **smallest real box size** that uses it, not only
  the largest preview card.
- Compare against neighboring shipped icons; if the main motif reads
  materially smaller, it fails even if the canvas is "occupied" by glow,
  rings, or ghost layers.
- Audit both `draw_skill_icon_mini()` and `_draw_skill_icon_symbol()` under
  the actual runtime ids used by perk acquisition, unlock, and HUD metadata.
- For unlock-style active skills, explicitly test the `unlock_*` perk id
  and the equipped skill id as separate inputs. A successful HUD orb check
  does not prove the perk-choice card, academy / NPC offer, TAB / ESC grid,
  or swap dialog is showing the same accepted motif.
- For on-disk PNG orb icons, inspect the alpha channel as part of QA:
  corners should be truly transparent, the visible alpha bounds should
  not touch the canvas edge, and no baked square, dark fringe, or rough
  generated rim should appear after downscaling into the live orb HUD.
- PNG orbs that already contain their own circular frame / glow, or have
  extra source padding around the motif, may need a per-id draw-size
  override rather than the default procedural-symbol size. Do not assume
  `size + N` scaling is safe: shrink if the rim crowds labels, enlarge if
  the main motif reads smaller than adjacent shipped icons, then compare
  the final HUD / grid read again.
- For imagegen-created perk / skill PNGs, the generated image is only the
  source asset. It is not complete until the selected file is copied into
  the repo, the PNG loader/cache path is wired, and the runtime branch
  attempts that PNG before any procedural fallback or special-case early
  return.
- For large PNG-backed perk / skill icons, the loader/cache path must cache
  the decoded source image separately from scaled `(size, active)` outputs.
  Choice-card hover / selection animation can request many nearby sizes;
  that path must not reload a 512px+ / 1254px+ PNG from disk for every size.
  The source-cache capacity must cover the real number of icons that can be
  visible at once, or a TAB / academy-style grid can still evict and reload
  icons every frame.
- If a PNG-backed perk icon is rendered through `draw_skill_icon_mini()`,
  audit every callsite with custom `scale_multiplier` values. Large choice
  cards may intentionally upscale the icon, but 32 px TAB character-info
  perk cells, academy / NPC offer boxes, swap dialogs, and status grids need
  label-safe sizing. A slight intentional bleed like existing energetic icons
  is acceptable, but the icon must not cover bottom level text such as
  `Lv.5`, and that level text must remain readable at the smallest real box
  size.
- Repo pattern: small-grid PNG-backed perk icon sizing should go through
  `_get_small_cell_perk_icon_size()` or an equivalent per-id clamp before
  the PNG is loaded / scaled. Do not reuse a procedural-symbol size blindly
  for imagegen PNGs with baked circular rims, glow frames, or source
  padding. Use the first real grid screenshot / preview to tune the per-id
  multiplier up or down; alpha-clean and PNG-first wiring can still pass
  while the icon's subject-fill reads too small. Check `Lv.1` as well as
  `Lv.5`; `Lv.1` often exposes overlap first because the label sits low
  in the cell.
- In the TAB character-info perk tab, use the current `dash_module_control`
  / `모듈제어` icon as the small-cell size reference. The target read is
  polished and confidently filled, but still leaves the bottom level label
  (`Lv.1`, `Lv.5`, etc.) unobstructed. If a new icon looks larger than that
  reference in the live panel, reduce the PNG draw size / padding or the
  callsite `scale_multiplier` instead of accepting label overlap.
- Before designing a new runtime perk icon, classify its visual family:
  character-exclusive active-skill / unlock perk, character passive /
  enhancer skill perk, or basic shared perk. Character-exclusive active
  and passive/enhancer skill perks should preserve the established round /
  orb-style language; basic shared perks may use freer item / symbol
  silhouettes. Do not let the family choice override the TAB
  `dash_module_control` / `모듈제어` small-cell size reference.

### Instant-trigger perk icon animation rule

For one-shot / instant-trigger runtime perks (`instant_*` ids and similar
immediate reward effects), the default asset request is now an animated
8-frame horizontal PNG sheet unless the user explicitly asks for a static
icon only.

Asset-side rule:
- Preserve the accepted static PNG as the identity anchor. Animate charge,
  glow, sweep, sparkle, portal, reward, or item-spill motion around that
  motif instead of redesigning the perk from scratch.
- Save the deliverable as a sibling sheet named
  `items/<perk_id>_perk_icon_sheet.png`, with 8 equal square frames in one
  horizontal row. Keep the static `items/<perk_id>_perk_icon.png` as the
  fallback source.
- Keep generous transparent padding; animated glow or rotation must not
  touch frame edges or bake in a square background.

Runtime handoff rule:
- The renderer must try the sheet first, then the static PNG, then the
  existing procedural fallback. A generated sheet is incomplete until that
  precedence is wired in the current runtime icon helper. In legacy Python
  this was `draw_skill_icon_mini()`.
- Use one-time sheet slicing plus cached scaled `(size, active, frame)`
  surfaces. Do not slice or rescale the full sheet in the hot path.
- Sign-off must include alpha-corner / alpha-bbox validation, smallest
  real-grid label checks (`Lv.1` and `Lv.5`), Godot resource import/load,
  and the relevant focused smoke or visible UI review. Use legacy
  `py_compile` / Pygame `convert_alpha()` checks only for explicit original
  PingFighter source work.

### New-perk registration checklist

| # | Step |
|---|------|
| 1 | Add to `VIPER_EXCLUSIVE_SKILLS` (name, max_level, descriptions, detail, icon_color) |
| 2 | Handle level-up in `apply_runtime_skill_effect()` |
| 3 | **Add `_MINI_SKILL_ICON_REGISTRY` entry or bespoke `draw_skill_icon_mini()` elif -- required, or icon breaks** |
| 4 | **Audit every live id alias (`perk_id`, unlock id, runtime skill id, legacy id) so all relevant UIs hit the intended branch** |
| 5 | **Check perceived subject-fill size in the smallest real icon box, not only the large choice card** |
| 6 | For imagegen / PNG-backed icons, wire repo asset -> PNG loader/cache -> PNG-first renderer, with procedural fallback only after load failure |
| 7 | Clamp PNG draw size in 32 px / small-grid UI callsites so `scale_multiplier` cannot hide level text such as `Lv.1` / `Lv.5`; use the TAB `dash_module_control` / `모듈제어` icon as the preferred small-cell size reference |
| 7b | For one-shot / instant-trigger perks (`instant_*` or similar immediate effects), produce and wire an 8-frame horizontal PNG sheet as the default visual, with static PNG fallback |
| 7c | Classify the icon family first: character-exclusive active / unlock and passive / enhancer skill perks use the round / orb-style language; basic shared perks may use freer silhouettes |
| 8 | Apply the actual gameplay effect via `runtime_skill_levels.get("perk_id", 0)` |
| 9 | Add `global` declarations in every function that mutates perk-related globals |

### General perk vs skill-type perk (5-orb slot)

Perks have two kinds, registered differently:

| Kind                     | Defined in                                       | HUD                              | Cooldown |
|--------------------------|--------------------------------------------------|----------------------------------|----------|
| General (passive boost)  | `VIPER_EXCLUSIVE_SKILLS`                         | `draw_viper_perk_icons()` (small icon beside orbs) | none |
| Skill-type (5-orb slot)  | `VIPER_EXCLUSIVE_SKILLS` **and** `VIPER_SKILL_ICONS_DATA` | `draw_viper_skill_icons()` (5-orb slot) | `cooldown` field |

Any perk with a cooldown or activation condition MUST be registered as
skill-type. Skill-type perks require entries in `_viper_skill_unlocked`,
`_viper_skill_cooldowns`, `_viper_skill_activation_times`,
`_viper_skill_was_active`, plus `unlock_viper_skill()` +
`equip_viper_skill()` plumbing in `apply_runtime_skill_effect()`.

```python
# apply_runtime_skill_effect() -- skill-type unlock + equip pattern
if choice_id == "new_skill_perk":
    unlock_viper_skill("new_skill_perk")
    equip_result = equip_viper_skill("new_skill_perk")
    if not equip_result:
        removed = _show_viper_skill_swap_dialog("new_skill_perk")
        if not removed:
            return False
        swap_viper_skill(removed, "new_skill_perk")
    # Cancel must be a true no-op; only persist ownership / levels after success.
    runtime_skill_levels["new_skill_perk"] = 1
    return True
```

For a general-perk HUD icon:

```python
_new_perk_lv = get_runtime_skill_level("new_perk_id")
if _new_perk_lv > 0:
    viper_perks.append({
        "name": "new_perk_id",
        "color": (R, G, B),
        "cost": 0,
        "symbol": "XX",
        "always_active": True,
    })
```

### HUD 5-orb rendering goes through TWO functions

```
_viper_equipped_skills
  -> match in VIPER_SKILL_ICONS_DATA
    -> _draw_skill_icon_symbol()   (HUD-only polished symbol)
      -> fallback: draw_skill_icon_mini()
```

| Function | Role |
|----------|------|
| `draw_skill_icon_mini()` | Generic icon for perk choice UI, TAB info, etc. |
| `_draw_skill_icon_symbol()` | HUD 5-orb only -- polished symbol |

Adding the `_MINI_SKILL_ICON_REGISTRY` entry or bespoke
`draw_skill_icon_mini()` elif keeps the HUD from breaking (there is a
fallback call inside `_draw_skill_icon_symbol()`). For a polished
HUD-specific icon, add a dedicated branch in `_draw_skill_icon_symbol()`
too.

Do not assume the same id reaches both functions. If the unlock perk id,
perk-pool id, and equipped-skill / orb-HUD id differ, `_draw_skill_icon_symbol()`
must still cover the actual equipped-skill name that lands in
`*_SKILL_ICONS_DATA`.

Tooltip-missing checkpoints: entry exists in `VIPER_SKILL_ICONS_DATA`
(name, korean, cost, description), `_viper_skill_icon_rects` updated every
frame, `is_viper_skill_unlocked()` returns True on hover.

Tooltip-format rule:
- New skill / perk tooltip copy should follow the surrounding UI's
  existing format and tone instead of inventing a new prose style.
- For active-skill / orb tooltips, preserve the established field order:
  header, state tag, cost / cooldown, description, then input / usage
  guidance.
- If a passive / enhancer perk changes another active skill's runtime
  behavior, do not leave the target orb tooltip static unless the
  changing information is already made obvious elsewhere. Surface the
  affected runtime-only modifiers in the target skill tooltip using
  concise synergy text with live effective values.
- If runtime synergy / bonus-line text changes the tooltip's vertical
  content size, do not keep a stale fixed-height layout. Recompute the
  tooltip height / section anchors from the real rendered content so the
  `how_to_use` block, control hint, and effect-preview panel remain
  fully readable in the invested state too.
- If an active-skill / orb tooltip family already ships an effect-
  preview panel, treat that panel as required content rather than
  decorative chrome. A new skill or new `effect_type` / preview key must
  either reuse a genuinely matching existing preview path or add a new
  renderer branch; do not ship a framed "effect preview" box that ends
  up visually empty.
- A populated effect-preview panel still fails QA if the scene is not
  panel-contained. Apply a panel-local clip / subsurface or equivalent
  containment so slashes, halos, particles, and clone afterimages cannot
  bleed above / below the preview box into description copy, synergy
  lines, or control hints.
- Do not let new preview branches regress into low-effort placeholders
  when neighboring shipped previews are scene-based. If the existing bar
  is character silhouette + timing cue + visible result, match that same
  visual class instead of filling the box with a couple of generic
  circles or lines.
- When preview scenes include a rendered character body, compare the
  character's visible body class against neighboring shipped previews in
  the same tooltip family. Do not let one character read materially
  larger than peers just because its cached pose surface uses a looser
  fit box; normalize the preview body scale unless a larger body is the
  explicit design intent.
- For procedurally rendered characters used inside tooltip previews,
  prefer cached neutral preview poses / surfaces and keep preview
  generation isolated from live combat animation timers. Hovering a
  tooltip should not inherit whatever slash / hit / kick timer happened
  to be active in gameplay at that moment.
- Effect-preview keycap helpers (`_draw_smasher_skill_keycap` and the
  shared `_draw_input_keycap_row` / `_draw_input_keycap_with_hold_badge`
  / `_draw_input_keycap_with_combo_badge` helpers) carry an explicit
  allowed-letter elif chain and silently render an empty keycap box for
  any unsupported letter -- the box draws unconditionally before the
  letter dispatch, so a missing branch manifests as a blank keycap in
  the preview, not as a runtime error. When adding a new effect-preview
  branch (or a new character / new skill) that needs a keycap for a key
  not already in the helper's allowed set (currently W / A / D / S),
  extend the elif chain first and QA both the small grid and the live
  tooltip render to confirm the glyph reads. This is the same trap
  pattern as `draw_skill_icon_mini()`'s elif chain, but at the keycap
  letter level rather than the skill_id level.
- Effect-preview keycap displays should follow the established Smasher
  rhythm: visible only during the prep / input window of the animation
  cycle, then hidden during the actual effect playback. Always-on
  keycaps make the preview read as a static instruction overlay rather
  than a "press -> effect" replay. New character preview branches
  should reuse the time-gated dispatcher (`_draw_viper_skill_input_overlay`
  with `_VIPER_INPUT_CYCLE_MS` / `_VIPER_INPUT_VISIBLE_RATIO` for
  `hold` / `combo` / `plus` kinds, and the keys-with-blank-gap pattern
  for `sequence` kinds) rather than calling the keycap helpers directly
  without a visibility window.
- If a skill gains a player-visible timed active state, audit the shared
  duration-bar HUD path and the tooltip together. The timer bar, active
  state, and any duration text should all read from the same effective
  runtime duration source and share the same teardown policy.
- If a character already has a dedicated orb-tooltip bonus-line lane
  for one invested enhancer, treat that as a UI contract for future
  enhancers in the same family. New enhancers should join the shared
  helper / bonus-line path rather than creating one-off special cases
  that make only one passive look "smart" in the orb HUD.
- When multiple enhancers can affect the same orb tooltip, merge them
  into a bounded shared line budget and define a stable priority /
  compression rule. Do not keep appending ad hoc extra text until the
  tooltip layout breaks or the old bonus lane silently disappears.
- **Shared-budget clip trap: a single bonus line that wraps to N visual
  lines at max-invested consumes N slots of the shared budget by itself.**
  The Viper orb tooltip shares a 2-line budget through
  `_render_runtime_bonus_lines(..., max_lines=2)`, and an existing
  `검기 증폭: ...` line already wraps to 2 visual lines at Lv.5 --
  so simply appending a new `검기 증폭 Lv3+: 공 유도 ...` line silently
  disappears even though the list contains it. Before appending a new
  synergy line to a shared-budget tooltip, measure the wrapped-line
  count of every existing line at the fully invested state. If the
  budget is already saturated, prefer folding the new information into
  the existing line (same perk family) or raising / compressing the
  shared budget deliberately. Do not "verify by reading the list" --
  verify by rendering the max-invested state and confirming every
  intended line is actually visible.
- A tooltip that looks correct in the uninvested state is not enough.
  QA the fully invested / max-visible bonus-line state too, because the
  most common regression is lower tooltip sections becoming partially
  hidden after new synergy text is added.
- TAB character-info perk tooltips and similar grid-hover tooltips are a
  separate failure class from orb tooltips. Do not rely on raw
  mouse-relative placement alone: use the hovered cell / rect and the
  owning panel bounds, wrap long text, and clamp / flip the tooltip so
  first-row entries can open below and edge entries stay fully visible.

---

## Legacy Python Perk/Skill UI Text Audit -- seven render paths

This section records the old Python UI surfaces that could drift. Current
Godot work must map the same audit idea to the relevant Godot overlays,
tooltip renderers, academy/NPC panels, character-info panels, and debug menus.

When changing perk level display, name, or tooltip text, fix **all seven**
render paths below. Fixing one leaves stale text in the other six.

| # | Screen | Function |
|---|--------|----------|
| 1 | Perk choice card (in-game) | `show_runtime_skill_choices()` |
| 2 | Stage clear perk choice | `show_stage_clear_choices()` |
| 3 | Stage clear overlay | `draw_stage_choice_overlay()` |
| 4 | Perk status screen (ESC menu) | `show_perk_status()` -> `draw_level_gauge()` |
| 5 | TAB character info perk tab | `draw_character_info_panel()` perk grid |
| 6 | Perk status tooltip | `draw_tooltip()` / `draw_skill_tooltip_mini()` |
| 7 | Victory screen perk tooltip | `show_victory_screen()` `hovered_tooltip` |

Why the duplication: each screen composes its own `f"Lv.{level}"` instead
of sharing a renderer. Also check data-passing helpers like
`get_acquired_skills()` for the fields downstream branches expect.

Layout trap to remember: screen `#5` (TAB character info perk grid) and
screen `#6` (`draw_tooltip()` / `draw_skill_tooltip_mini()`) often share
data but not placement code. Fixing the text without auditing the
grid-hover clamp / flip behavior still leaves first-row and edge-column
tooltips vulnerable to clipping.

Quick audit before calling the work done:

```bash
grep -n 'Lv\.' pingfighter.py | grep -i 'render\|text\|line'
grep -n 'name_line\|tooltip_name\|perk_name.*Lv' pingfighter.py
grep -n 'character_restriction' pingfighter.py | grep -v '#\|print\|CLAUDE'
```

### 5-orb active-skill tooltip standard format

Per-character orb tooltips (`_draw_smasher_skill_tooltip()` /
`_draw_viper_skill_tooltip()` / `_draw_soldier_skill_tooltip()`) follow a
fixed contract. Honor it when adding or modifying any 5-orb active skill,
otherwise the orb tooltip drifts away from the rest of the family.

- **Skill data fields owned by the orb tooltip path:**
  - `description` (3-line max) — effect + brief flavor / story + optional
    constraint. **Do NOT recap input keys** (the control hint box owns
    that) and **do NOT recap cooldown** (the header row owns that).
  - `how_to_use` — single plain sentence used by the *non-orb* tooltip
    paths (ESC perk status `draw_tooltip()`, TAB info perk grid,
    Soldier/Commando `_draw_skill_tooltip_mini()`). Must be a complete
    sentence, never contain `\n` (those paths render with a single
    `font.render()` call, not the wrap-aware helper, so newlines render
    as zero-width tofu — see the `\n` trap in §Resource Loading).
  - `motion_hint` — single short line describing what the skill **looks
    like** in motion (visual / motion verb), rendered as a dim row under
    the input rows. **Not a stat summary.** Never bake in numbers that a
    perk can change (durations modified by `extension_gear`, gauge costs
    modified by future scaling perks, etc.). For fixed numbers, prefer
    descriptive verbs anyway — `motion_hint` is a glance, not a spec.
- **Control hint rows** (`_get_<character>_control_hint_rows()`):
  - Hold ONLY input visualization (key boxes, mouse icon, accent /
    text / dim tokens that label the input pattern). Pure-prose dim
    rows describing outcome belong in `motion_hint`, not here.
  - The last input row ends with `("accent", "발동")` (or the activation
    word folded into the existing accent — e.g. `"홀드 후 손 떼면 발동"`,
    `"좌회전 발동"`). Skip this only when an alt-input row already carries
    the activation word, since duplicating "발동" in adjacent rows reads
    awkwardly.
  - When the trigger context text is too long for one row at the
    tooltip width (~260px usable for viper/smasher), split into a
    text-only row 1 + keys-bearing row 2 (current `marshal_kick`,
    `dark_blade`, `nerve_strike`, `core_flip` pattern). Keep keys with
    a connector word like `"사용 후"` / `"착지 전"` / `"타격 후"`, not
    bare keys on their own line.
- **Layout function signature contract:**
  - `_get_<character>_tooltip_control_layout(skill_name, how_to_use,
    motion_hint, font, max_width)` returns
    `(rows, fallback_lines, box_height)`. When structured rows exist,
    the layout appends `motion_hint` as wrapped dim rows below them.
    The `how_to_use` parameter is only consumed when no structured rows
    exist (legacy fallback). Always pass `motion_hint` from
    `skill_data.get("motion_hint", "")`.
- **`_get_smasher_tooltip_height()` takes `skill_name`, not `how_to_use`.**
  Earlier versions special-cased `how_to_use in ("drive",
  "power_smashing")` for compact height. That coupled tooltip height to
  a magic-string sentinel inside `how_to_use`; the current path passes
  `skill_name` instead so `how_to_use` can be a normal sentence.
- **Perk-affected numbers must be abstracted in `description`.** When a
  perk like `extension_gear` multiplies a duration / cost / radius (see
  `_get_smasher_extension_gear_effective_level()` consumers), the
  description should read `"일정 기간"` / `"일정 범위"` rather than the
  raw constant. Fixed constants (e.g. `RECOVERY_SPEED_BOOST_PERCENT = 0.30`,
  `SMASHER_WHEEL_DURATION_MS = 1200` — confirmed not multiplied) stay as
  literal numbers. When in doubt, grep for the constant being multiplied
  by an `_ext_gear_mult` / `_get_*_effective_level()` factor.

Reference implementations (current canonical pattern):

- Viper `marshal_kick`: long trigger context split into 2 rows, ends in
  `("accent", "발동")`, motion_hint `"벽점프 후 공 쪽으로 돌진"`.
- Viper `phantom_kick` description: chain constraint
  (`"쉐도우 백스텝 연계 시 공중 백스텝만 가능."`) lives in description
  line 3, not in motion_hint or control rows — rule-of-thumb is that
  hard activation prerequisites belong in description, while
  motion_hint stays purely visual.
- Smasher `recovery`: motion_hint `"녹색 빛으로 후딜 제거 + 가속"`
  (no `+30%` because the duration above it is perk-affected and the
  amount doesn't belong in a glance summary anyway).
- Smasher `warp_gate`: description leads with `"일정 기간"` because
  `WARP_GATE_DURATION_MS` is multiplied by `extension_gear`.

---

## Legacy / Porting Reference: Boss Slow Debuff Kinematics

Boss slow effects (leg_shot, spider_mine, plasma, venom_mist_gauntlet,
arena oil/tentacle, fire zone, etc.) are applied in a single shared
helper `_apply_common_boss_slow_effects()` used by every boss AI
function (`handle_boss`, `handle_boss_mythic`, `handle_boss_junior`,
`handle_boss_pro`, `handle_boss_champion`).

- **Per-frame pinning is intentional, not a double-application bug.**
  The helper multiplies `boss_current_speed *= slow_multiplier` every
  frame in addition to reducing `accel` / `max_speed` / `decel`. Every
  frame the AI re-accelerates `boss_current_speed` via `enhanced_accel`,
  then this multiply pins it back down. That pinning is what produces
  the "뚝 느려지는" feel during acceleration, deceleration, and
  direction changes -- not only when the boss is at peak velocity.
- **Do NOT "fix" this as a perceived double-count.** Replacing the
  per-frame multiply with a one-shot clamp (`if boss_current_speed >
  max_speed: boss_current_speed = max_speed`) is mathematically a
  no-op once the first frame clamps, and regresses the debuff feel: it
  only bites at peak speed, and is effectively zero during mid-speed
  accel / decel / turn. Commit `89836d86` (2026-02-07) removed the
  multiply under exactly this misdiagnosis, and the follow-up soft
  clamp in `ab929ca9` did not restore the feel -- only the restored
  per-frame multiply does.
- **If the slow feels too strong, tune `slow_amount` values instead of
  changing the kinematic model.** Change the magnitudes
  (`LEG_SHOT_SPEED_REDUCTION`, `SPIDER_MINE_SLOW_FACTOR`,
  `_boss_slow_amount` in `venom_mist_gauntlet.py`, arena
  `top_paddle_slow_amount`), not the application mode.
- **Do not mix the two slow-value conventions.** `*_SPEED_REDUCTION` /
  `*_SLOW_FACTOR` are direct multipliers (`0.3` means 70% slower), but
  `*_slow_amount` is subtracted inside the helper (`slow_multiplier *=
  (1.0 - slow_amount)`), so `0.7` means 70% slower and `0.3` means only
  30% slower.
- **Godot boss slow uses named tier multipliers for new sources.** Prefer
  `res://scripts/status/boss_slow_tiers.gd`: `WEAK = 0.70` (30% slow),
  `MEDIUM = 0.55` (45% slow), and `STRONG = 0.40` (60% slow). These are
  direct movement multipliers; lower means stronger. Keep special
  overcap / legacy-parity values as documented raw exceptions rather than
  silently redefining a tier.
- **When adding a new boss slow source, add it inside
  `_apply_common_boss_slow_effects()` and nowhere else.** Copy-pasting
  a per-handler slow block is how this system drifted in the first
  place (plasma + venom_mist were added only to `handle_boss()` and
  silently never applied in league AI before the unification). Every
  AI path must share the same helper. Also extend
  `tests/test_boss_slow_kinematics.py` with a case for the new source
  -- that test is the sealing mechanism that prevents the helper from
  silently regressing to clamp-only or losing a source again.
- **Arena-only boss state (stun, steam barrier freeze, paddle shrink,
  confusion) still lives in `handle_boss()` prologue,** because it can
  `return` early and must run before the slow helper. The helper
  itself stays purely kinematic.

## Legacy / Porting Reference: Player Dash Effect Path Unification

`pingfighter.py` does NOT have a single `start_dash()` function. Player
dash execution is duplicated across at least 5 nearly-identical inline
blocks: general left dash, general right dash, post-stun consecutive
left, post-stun consecutive right, and the half-dash early-trigger
path (plus soul burst variants). Each block independently re-derives
token consumption (right-to-left), `_next_charge_idx` (left-to-right),
cooldown timer, and any per-effect post-processing. The vestigial
`_execute_dash()` helper in the file is defined but never called --
do NOT trust it as the live path.

This duplication caused the boost charging silent-divergence bug
(2026-04-30): the general dash path applied "90% cooldown discount"
while the post-stun consecutive path applied "instant token refund,"
and the tooltip claimed "instant token charge." Because consecutive
dash is allowed after only 200ms (line 3980 `CONSECUTIVE_DASH_START_DELAY_MS`)
while the discounted timer ran ~30 frames (~500ms), the second dash
overwrote `_charging_state` to a different slot before the first
dash's boost benefit landed -- the player paid for the perk and got
nothing visible or numeric on the general path.

Standing rules:

- **A new effect that touches dash token consumption, cooldown, or
  refund must route through a shared helper, not be copy-pasted into
  each block.** The boost charging fix introduced
  `arm_/has_/consume_/reset_/try_arm_boost_charging_pending_dash_refund()`
  helpers (line 51738~51781) as the canonical pattern. Any future
  dash-affecting perk / item / legendary effect that fires "next dash
  is free / cheaper / different" should follow the same arm-on-event
  / consume-in-execution / reset-on-round-end shape.
- **Effects whose payoff window is shorter than the consecutive-dash
  re-trigger window (200ms) WILL be invisibly clobbered** if they
  store state in `_charging_state` or per-slot timers without
  pending-flag protection. Prefer pending-flag designs over
  charge-state mutations for "next dash"-class effects.
- **The pending flag must be honored by every dash entry gate, not
  only the one being added.** The boost charging fix had to update
  every `current_charges > 0` / `rolling_charges > 0` /
  `_early_rolling_charges > 0` predicate to also accept
  `has_boost_charging_pending_dash_refund()`. Grep the predicate
  family before declaring the integration done.
- **Reset on round end, game end, main-menu return, and any
  state-reinit path.** The fix added `reset_*` calls at 6 sites
  (88429, 183020, 197793, 198226, 200711, 203716). A new pending-
  flag effect must mirror the same coverage, or the flag leaks
  across rounds / sessions and produces a free dash at the worst
  possible time.
- **The "free dash" path must NOT re-roll the same proc, or the
  effect chains infinitely.** The boost charging fix relies on the
  fact that `try_arm_*` is gated inside `if _next_charge_idx >= 0:`
  -- a free dash consumed the pending flag instead of a token, so
  no slot becomes empty, so the charging block (and the `try_arm_*`
  call inside it) is skipped. Future "next dash" effects must build
  in equivalent re-roll suppression.
- **When auditing dash effect work, list all entry points before
  editing.** The five inline blocks today are: general left
  (line ~110476), general right (line ~110768), post-stun left
  (line ~109308), post-stun right (line ~109520), half-dash early
  trigger (line ~108830-ish), plus soul burst dash variants. Line
  numbers drift; the reliable anchor is searching for `_next_charge_idx`
  and `token_states[idx] = False` together.
- **Tooltip text must match the unified behavior.** The detail string
  in `apply_runtime_skill_effect()` / `VIPER_EXCLUSIVE_SKILLS` /
  related perk dicts is the player-facing contract; if the runtime
  pattern changes from "instant refund" to "next dash free" or
  similar, the tooltip is part of the integration, not a
  documentation cleanup task to defer.

## Legacy Python Graphics & Effects Performance

This section is mainly about Python/Pygame hot paths. For current Godot work,
apply the same intent through Godot resource caching, texture reuse, node/host
lifecycle cleanup, shader/particle cost checks, and the repo-local Godot smoke
tools.

Rendering pipeline today:
- **Windowed:** `pygame.SCALED` + GPU 2x upscale. No per-frame CPU scaling.
- **Fullscreen:** CPU software scaling, fast enough via DWM bypass.

### Usually cheap, but only while staying in-family

| Action | Why |
|--------|-----|
| Vary colors / alpha on an existing effect | Does not change object count or allocation pattern |
| Add detail to cached backgrounds | Drawn from cached layers |
| Improve fidelity with pooled / cached surfaces | Reuse beats recompute |
| Add modest direct-draw accents | Safe when particle count, lifetime, layer count, and radius stay close to the existing effect |

Not free: multiplying particle count, particle lifetime, layer count, and
translucent radius at the same time. Those factors multiply each other.

### Still watch for (CPU + pygame territory)

| Pattern | Why bad | Fix |
|---------|---------|-----|
| `pygame.Surface(..., SRCALPHA)` inside a loop | Per-frame allocation -- biggest killer | Surface pool or `gfxdraw` |
| `pygame.transform.rotate/scale` per frame | CPU-heavy | Cache results, key by angle/size |
| Particle count x lifetime x layer count growth | Each change looks small alone, but total draw volume explodes | Keep one axis flat or benchmark/cache |
| Large soft smoke / aura blobs redrawn every frame | High alpha overdraw plus repeated circle/ellipse work | Cache blob surfaces by size/color/alpha bucket and blit |
| Thousands of `pygame.draw` / `gfxdraw` calls | Volume matters even when per-call is cheap | Reduce count, collapse layers, or batch with cached surfaces |
| Full-screen `Surface.fill()` spam | 760*750*4 = 2.3MB cleared every time | Clear only the dirty region |
| Wide SRCALPHA blending | Alpha blending is CPU-expensive | Minimize transparent surfaces |

### Effect authoring pattern

```python
# Wrong: per-frame Surface + rotate
def update_particle(self):
    surf = pygame.Surface((20, 20), pygame.SRCALPHA)
    surf = pygame.transform.rotate(surf, self.angle)
    screen.blit(surf, self.pos)

# Right: gfxdraw direct for small/simple particles
def update_particle(self):
    pygame.gfxdraw.filled_circle(
        screen, int(self.x), int(self.y), self.radius, self.color
    )

# Right: surface pool + cached rotation
class ParticlePool:
    def __init__(self):
        self.cached = {}

    def get_rotated(self, base, angle):
        key = int(angle) % 360
        if key not in self.cached:
            self.cached[key] = pygame.transform.rotate(base, key)
        return self.cached[key]
```

One-liner: do not create a new `pygame.Surface` or call
`pygame.transform.rotate/scale` per frame per particle. Use `gfxdraw`
for small/simple shapes, and switch to cached blob surfaces or a surface
pool once an effect becomes layered smoke, aura, or other large soft
alpha work.

---

## Legacy Git Rollback Notes (PROHIBITED IN THIS REPO — provenance only)

**DO NOT ROLL BACK WITH GIT STATE COMMANDS IN THIS REPO.** This repo
intentionally keeps a dirty worktree full of uncommitted WIP, and the
standing rule (§0 and `docs/agent_operating_posture.md`) is: never
`git reset` / `git checkout` / `git stash` to revert or verify — a
stash/reset here destroys live WIP. For regression checks, toggle the
target line in place (Edit / temp patch / fixture) instead. If an actual
rollback is ever unavoidable, it is an explicit user decision, not an
agent procedure.

The runnable legacy-era recipe that used to live in this section (a
stash-then-hard-reset sequence, checkout-based single-file spot reverts,
and a "safe rollback" command table) was removed on 2026-07-02: every step
of it is on this repo's prohibited list, and out-of-context grep / RAG hits
on those command lines read as endorsements. Read-only history inspection
(`git log`, `git show`, `git reflog`) remains fine.

Legacy parity fact kept for provenance: `pingfighter.py` and its sibling
modules (`start_menu.py`, `items.py`, etc.) must land on the same version
together. Spot-reverting one file without the rest breaks imports and
state.

---

## Repository info

- Remote: `https://github.com/officialsahogany/pingfighter.git`
- Working branch at start of this doc: `feature/refactor-ui`
