# Repository Guidelines

This repository now develops the Godot project **디스크하츠 - 링피아**
only. The original Python/Pygame PingFighter codebase is frozen and is kept
as a porting reference.

Default every new gameplay, UI, VFX, audio, item, character, boss, save-data,
menu, or runtime request to `godot/`. Use `pingfighter.py` and the original
Python modules only to inspect legacy behavior, timing, balance, text, assets,
or parity details during porting. Do not modify the original Python runtime
unless the user explicitly asks for a legacy-source edit.

`AGENTS.md` covers Godot-first implementation routing, runtime integration,
performance, testing, and repo-specific guardrails for agent-style coding
tools. Legacy Python/Pygame rules in this file are reference-only unless they
are explicitly framed as Godot porting guidance.
`CLAUDE.md` covers hidden-knowledge traps, asset-generation routing,
prompt wording, sprite-sheet composition, and offline background-removal steps.
`docs/sprites/boss_sprite_runtime_contract.md` covers shared boss-sprite runtime vocabulary, state-to-sheet mappings, and cross-runtime naming traps.
`docs/sprites/stage1_dalji.md` covers the compact Stage 1 Dalji per-boss sprite contract and Godot key mapping.
`.claude/skills/ui-hud-generation/SKILL.md` covers generated fullscreen / pillar HUD frame art, including bottom unified HUD frames, orb collars, active-slot trays, transparent prep, and source-anchor handoff notes.
`docs/item_runtime_checklist.md` covers item runtime integration.
`docs/character_skill_perk_checklist.md` covers runtime character perk / skill integration (unlock perks, 5-orb skills, academy/NPC skill-offer flows, effective-level audits, tooltip/UI sync, save/load/reset QA).
`docs/godot_port_checklist.md` covers Godot porting integration rules, including module registry wiring, modal gate connections, runtime performance lifecycle checks, and anti-hallucination checks for method signatures.
`docs/skill_vfx_workflow.md` covers the shared Claude / Codex workflow for
imagegen assets, Live2D-style assets, and modular 2D skill / VFX work.
`docs/current_development_boundary.md` is the one-page summary of the current
Godot-vs-legacy boundary.
`docs/agent_operating_posture.md` covers the shared agent (Claude/Codex)
working posture — the fable-grade default: SAFE regression-detection
validation (in-place Edit toggle / temp patch / fixture only — never
`git reset`/`checkout`/`stash` to revert in this dirty-worktree repo),
root-cause proof over hunch, adversarial self-review, fixed-vs-deferred
reporting with severity tags, options+recommendation at genuine forks,
commit hygiene, and pixel-level QA for visual changes.
Skill source policy: `.claude/skills/` is the canonical repo skill tree.
`.agents/skills/` may exist as a Codex loader mirror only. Do not edit both
trees by hand; update `.claude/skills/` first, then refresh any mirror copy if
the tool loader requires it.
Legacy design / review documents such as `docs/four_poisons_handoff.md`,
`docs/dual_glitch_clone_replication_handoff.md`,
`docs/dual_glitch_clone_hp_handoff.md`,
`docs/commando_firearm_overhaul.md`, `docs/WEAPON_SYSTEM_GUIDE.md`,
`docs/chaos_spear_visual_review.md`,
`docs/perk_flight_to_orb_animation_review.md`,
`docs/logo_intro_handoff.md`, and
`docs/pingfighter_modularization_plan.md` are frozen PingFighter reference
packets. Use them to recover design intent and Python parity anchors, then
map the work to the current Godot owners and checklists before editing.

When the documents overlap:
- Current implementation target -> `godot/` wins.
- Original Python/Pygame PingFighter -> reference-only, used for porting
  comparison unless the user explicitly requests a legacy edit.
- `AGENTS.md` is the source of truth for boss-sprite implementation and runtime rules.
- `CLAUDE.md` is the source of truth for image-generation and asset-prep rules.
- `docs/sprites/boss_sprite_runtime_contract.md` is the source of truth for
  boss-sprite runtime state vocabulary such as attack-vs-stun mappings and
  legacy key meanings.
- `docs/sprites/stage1_dalji.md` is the source of truth for compact Stage 1
  Dalji runtime sheet mapping across Python and Godot.
- `.claude/skills/ui-hud-generation/SKILL.md` is the source of truth for
  generated fullscreen / pillar HUD frame asset rules.
- `docs/item_runtime_checklist.md` is the source of truth for item runtime integration.
- `docs/character_skill_perk_checklist.md` is the source of truth for runtime character perk / skill integration.
- `docs/godot_port_checklist.md` is the source of truth for Godot porting integration and wiring rules.
- `docs/skill_vfx_workflow.md` is the source of truth for Claude / Codex
  art-to-runtime workflow boundaries and the modular VFX handoff checklist.
- `docs/agent_operating_posture.md` is the source of truth for the shared
  agent working posture (verification/adversarial-review discipline,
  decision presentation, commit hygiene). Note the safety constraint on
  regression-detection validation: never use git reset/checkout/stash to
  "revert and check" — toggle the target line in place instead.
- Legacy handoff / review docs are never the current edit target by
  themselves. They lose to the Godot-first routing in this file, the
  relevant runtime checklist, and `docs/godot_port_architecture.md`.
- **CRITICAL**: If the task involves porting a feature from Python to Godot, you MUST read `docs/godot_port_checklist.md` before starting implementation.
- If the task touches generated fullscreen HUD frame art, bottom unified
  HUD frames, orb collars, active-slot trays, pillar backplates, or dash
  token decorative frames, open `.claude/skills/ui-hud-generation/SKILL.md`
  for the asset-generation side and this `AGENTS.md` HUD checklist for
  runtime integration.
- If a task fixes Gemini MCP / asset-generation tooling reliability rather
  than game runtime behavior, route the durable workflow rule to
  `CLAUDE.md` and the relevant `.claude/skills/*/SKILL.md`. Keep the
  actual MCP launch path stable: prefer the repo launcher
  `.claude/gemini_mcp_launcher.mjs` through an absolute `node.exe` path
  over `npx`, keep stdout reserved for MCP JSON-RPC, avoid startup API
  probes that can exceed the `30000ms` client timeout, and verify with
  `initialize`, `listTools`, and one lightweight tool call before
  claiming the tool is recovered.
- If the task touches runtime character perk / skill icons, orb HUD symbols,
  perk cards, academy / NPC perk-offer UI, skill tooltip sync,
  duration / timer HUD sync, or
  gameplay / reward wiring for a character skill (including skill-
  specific gold bonuses), open
  `docs/character_skill_perk_checklist.md` and the related `CLAUDE.md`
  hidden-knowledge section before claiming the work is done.
- If the task touches a passive / enhancer perk that changes an
  existing active skill's runtime behavior, do not stop at the perk
  card or perk-detail text. Re-check the affected orb tooltip /
  active-skill tooltip path too, including any concise runtime synergy /
  bonus-line text the player needs in order to understand the invested
  perk in live play.
- If the task touches runtime tooltip text wrapping, multi-line
  description copy, or bonus-line additions on a character perk / skill
  tooltip, open `docs/character_skill_perk_checklist.md` plus the
  related `CLAUDE.md` hidden-knowledge section and verify the **rendered
  max-invested state**, not just the source string or bonus-line list.
- If the task adds or modifies a passive / scaling character perk that
  can receive effective-level bonus sources (`transcendent_crown`,
  `sage_ring`, ignition-style buffs, or future perk-level increase
  effects), default to letting real runtime stats continue scaling above
  `Lv.5` / `max_level`. Treat hard caps and boolean-only behavior as
  explicit exceptions that must be documented in gameplay code, tooltip
  text, and `docs/character_skill_perk_checklist.md`.
- If the task adds or retunes runtime knockback for a character perk /
  skill, open `docs/character_skill_perk_checklist.md` and default to
  the shipped fire-event knockback path as the gameplay baseline.
  Prefer tuning from the existing fire-style velocity / timer / decay /
  hitstop channels (current reference: Viper `kick_enhance` guard
  knockback) instead of inventing an unrelated ad-hoc knockback system
  unless the design explicitly calls for a different feel.
- If the task touches slot-full perk offers, swap dialogs, or academy /
  NPC active-skill teaching flows, re-check cancel semantics,
  ownership-vs-equipped state, and `perk_id`-vs-`skill_id` cleanup
  mapping in `docs/character_skill_perk_checklist.md` before sign-off.

Claude / Codex asset and VFX workflow split:
- This split is repo policy, not tool-local memory. Keep durable workflow
  rules in `CLAUDE.md`, this file, and `docs/skill_vfx_workflow.md`.
- Claude leads aesthetic direction: skill-effect concept, mood, palette,
  silhouette, layer recipe, prompt wording, alpha / nukki visual review, and
  the final beauty / character-read pass.
- Codex leads executable delivery: Codex imagegen or Live2D-style asset
  generation when used, copying accepted assets into `godot/`, `res://` loader
  and prewarm wiring, shader family presets, `GPUParticles2D`,
  `Tween` / `AnimationPlayer`, audio, hitstop, camera shake, flash, lifecycle
  cleanup, and automated / live verification.
- New 2D skill / VFX work defaults to modular VFX layering: static texture
  pieces plus runtime composition, shared shader-family presets such as
  `WritheEmberMaterial` where applicable, and a 3-piece baseline template that
  may grow when the effect needs more layers. Do not force `TextureRect`, a
  fixed 3-piece count, or one-off inline shader copies when the current host or
  effect shape calls for a different reusable implementation.
- Claude direction is not runtime completion. Codex must still verify
  coordinate space, clip, loader / prewarm, round / score / serve / reset
  cleanup, smoke tests, headless load, warning scan after `.gd` edits, and a
  scaled / windowed live visual check when the VFX is visible.

Godot port routing:
- Default all new implementation prompts in this workspace to the repo-local
  Godot port, even when the user does not explicitly say "Godot port" or
  "porting". Do not modify the Python original for new feature / runtime
  work unless the user explicitly asks for Python, shared source parity docs,
  or a temporary reference-only inspection. Treat `pingfighter.py` as a
  behavior reference for Godot parity, not as the active implementation
  target.
- `docs/godot_port_architecture.md` is the source of truth for Godot port
  module boundaries, refactor rules, and current split status.
- `docs/godot_module_ownership_ledger.md` is the cumulative ownership log for
  already-split Godot modules. Update it when ownership moves, but keep new
  operating rules in `docs/godot_port_architecture.md` or the focused runtime
  checklist.
- Current live Godot project is repo-local at `godot/project.godot`
  (`D:\main\bosspong\godot\project.godot` in the current workspace).
  Treat `godot/` as the editable live project, not as a C-drive mirror.
- The old external live project was archived as
  `C:\Users\woduq\Documents\pingfighter_old_20260503_233412`. Do not sync
  or edit `C:\Users\woduq\Documents\pingfighter` unless the user explicitly
  creates a new external live project and tells you to use it.
- Do not let `scenes/main.gd` become the Godot replacement for the Python
  monolith. Keep it as orchestration / draw-order glue, and move stable
  domains into `scripts/` modules as they are ported.
- Treat `pingfighter.py` as the behavior reference, not the architecture
  reference. Match gameplay, visuals, sound timing, and state semantics,
  but split the Godot implementation by domain.
- When porting visible Godot UI or debug text, use Korean by default.
  Check the Python reference / `localization/ko.json` first, and do not
  leave scaffold English in menu titles, tabs, status text, tooltips,
  roll-option labels, or action hints unless it is an intentional brand /
  identifier / engine term.
- When porting items, character skills, boss actions, stage events,
  rewards, or UI feedback, audit audio as a first-class parity surface.
  Route cues through `scripts/audio/game_audio.gd` or the focused audio
  owner, verify pickup / use / windup / release / hit / status-start /
  loop / expire / cancel timing where applicable, and document intentional
  silent differences.
- For any Godot gameplay sound that loops or is driven by a `sync_*`
  method, treat round-boundary cleanup as part of the feature. Add the
  stop method to `scripts/audio/gameplay_loop_audio_cleanup.gd`, verify
  score-event, scoreboard, serve-wait, round-restart, and game-reset
  paths cannot leave the loop playing or re-arm it, and add / update a
  focused smoke test for that lifecycle.
- For any Godot visible gameplay VFX that uses a detached FX host
  (`Node2D`, `Sprite2D`, `ColorRect`, `GPUParticles2D`, shader quad, or
  similar), treat host lifecycle as separate from logical visibility.
  If `has_visible_effects()` can become `false`, the owning draw fanout may
  stop calling `draw()` and therefore cannot be the only cleanup path.
  `reset_round()`, score / serve-wait cancellation, stage transition, full
  reset, and skill / item cancel paths must directly call `set_active(false)`,
  `tear_down()`, or an owner hide helper for any previously attached host.
  Add / update a focused smoke test that creates an active host, crosses the
  round-boundary path immediately after activation, and verifies the host is
  hidden plus any phase audio is stopped.
- For any new or modified Godot stage, HUD, gameplay VFX, item effect,
  character skill, boss action, reward scene, loading transition, or runtime
  renderer, treat performance lifecycle as part of the feature. Identify
  which work is per-frame, first-use, stage-entry, transition-time, or offline
  asset-prep work before sign-off.
- Do not place heavyweight resource preparation in hot `_draw()` / `_process()`
  paths. Avoid runtime `Image.get_image()`, alpha scans, atlas slicing,
  image compositing, `ImageTexture.create_from_image()`, large cache builds,
  large JSON/texture loads, or scene-wide node scans during the first visible
  battle frame unless the cost is explicitly measured and accepted.
- Expensive cache generation must happen through one of these paths:
  offline baked metadata/assets, owner-module prewarm, staged loading work
  spread across multiple frames, or a documented low-cost lazy path. A cache
  that improves steady-state draw time but creates a stage-entry hitch is not
  complete integration.
- Controller-driven FX / loading / result / overlay hosts should default to
  `set_process(false)` and advance from the owning controller sync path.
  Enable a host's own `_process()` only when it truly owns timing independent
  of the controller, and disable it again when inactive or hidden.
- When a change can affect frame time, inspect focused `BattlePerf` output or
  add a smoke / micro-benchmark for the touched path. Check first-entry,
  transition, and steady-state hot paths separately; `draw calls`, `prims`,
  `process_nodes outside_shell`, `physics_nodes outside_shell`, and first-frame
  max values are separate regression surfaces.
- **Physics-tick code must never call the battle shell's `queue_redraw()`
  directly — route through `request_battle_redraw()` (dirty flag).** Godot
  flushes the MessageQueue after EVERY physics tick, and a queued CanvasItem
  redraw executes the full immediate-mode `_draw()` inside that flush. So a
  per-tick `queue_redraw()` looks free at 1 tick/frame, but the moment one
  slow frame starts physics catch-up (up to 8 ticks/frame), the 5–10ms battle
  `_draw` runs once per tick and the frame slows further — a self-sustaining
  frame-drop spiral (reference incident 2026-06-13: commando stage 1, 7–13
  FPS craters; BattlePerf signature is `draw.shell.total` count ≈
  `process.shell` count + `physics.shell` count in the degraded windows, and
  repeated `delta max = 111.1ms` = the 8-tick clamp). The shell flushes the
  flag to at most ONE `queue_redraw()` per rendered frame at the end of
  `_process` (`battle_scene_shell._flush_battle_redraw_request`). New
  physics-side drivers must bind redraw to `request_battle_redraw` (see
  `battle_scene_update_callbacks._build_queue_redraw_callable`,
  `battle_scene_match_event_driver._queue_redraw`); process/idle/input/modal
  code may keep immediate `queue_redraw()`. Do not "fix" the degraded-window
  gap as engine physics cost: the catch-up draws land in the physics monitor
  and BattlePerf can misclassify them as `monitor-physics-lag`. Sealed by
  `battle_redraw_coalescing_smoke.gd` (N physics flow updates → 0 direct
  `queue_redraw`, one flush → exactly 1).
- **Do not apply index-based stride decimation as a render-LOD on SPARSE or
  CHEAP particle effects — it flickers, it does not just thin.** A stride cull
  like `if (i - particle_start) % stride != 0: continue` selects which
  particles to draw by their CURRENT array index. Every frame, particles spawn
  (appended) and expire (compacted out), so each surviving particle's index
  shifts and `particle_start` moves — meaning the SET of drawn particles
  changes frame to frame. On a dense effect (rain ~120, fire 44–72) the churn
  is hidden, but on a sparse one the result is visible blinking/stutter
  ("뚝뚝 끊김"). The shipped 48-FPS-stable default forces `effect_lod_scale =
  0.58` (≤ severe threshold) for EVERY player via
  `BattleRenderQuality.is_fps_cap_lod_active()`, so this LOD is always on in
  the real game, not an edge case. Reference regression (2026-06-06): wind
  (breeze/gust) weather was strided + capped to ~12, rendering ~4 flickering
  ribbons; wind ribbons are one `draw_texture_rect` each (the cheapest weather
  effect), so the decimation bought nothing. Fix: exempt cheap/sparse effects
  from stride (render every particle) and keep the count near-full; reserve
  stride/count LOD for genuinely expensive, dense effects. If a sparse effect
  truly must shed particles under LOD, drop a STABLE subset (cull by a
  per-particle id/seed, or shrink a contiguous newest-window), never by live
  array index. Sealed by `weather_event_render_budget_smoke.gd` (wind stride
  must be 1, wind count must stay continuous).
- When adding or porting a stage boss, convert existing boss skills to the
  Stage 1 Dalji-style skill-card cooldown HUD by default. Inventory all
  boss skills from the Python reference, use themed PNG card art for each
  skill, generate missing card art through imagegen, and expose cooldown /
  ready / trigger metadata for the renderer instead of preserving legacy
  right-side boss skill gauge bars unless a unique HUD is explicitly
  requested.
- When porting a visible gameplay VFX to Godot, treat the Python / Pygame
  effect as a timing and behavior reference, not as the final rendering
  architecture. Default to a Godot-native remaster that preserves original
  windup / release / hit / linger / cleanup timing while rebuilding the
  visible effect through **modular VFX layering**: texture pieces or sprite
  sheets, runtime layer composition, `ShaderMaterial` uniform tuning,
  `GPUParticles2D`, and `Tween` or `AnimationPlayer`. Prefer reusable
  shader families with per-effect uniforms for flow, flicker, distortion,
  `lateral_strength` / tangent-side displacement for writhing branches,
  jitter, chroma, breath alpha, color ramps, and boosted / enraged
  variants. Direct `canvas.draw_*()` copies are acceptable only as temporary parity
  scaffolding, low-cost fallback accents, or clearly documented exceptions.
  Follow `docs/godot_port_architecture.md`'s Godot VFX remaster checklist
  before claiming the ported effect is finished.
- Before adding or modifying a Godot feature, identify the owning module.
  If no owner exists yet, create the smallest stable module boundary first
  and record it in `docs/godot_port_architecture.md`.
- Run the repo-local Godot headless load check from `godot/` with
  `.\tools\run_headless_load_check.ps1` before sign-off. Use this wrapper
  instead of a bare Godot CLI command so parallel editor / headless sessions
  cannot collide on the default Godot log file. The old mirror/live hash sync
  rule applies only if a future live Godot project is moved outside this repo
  again.
- After any Godot `.gd` edit, treat editor warning hygiene as a separate
  verification surface from the basic headless load. Run the repo-local
  GDScript warning scan from `godot/` with
  `.\tools\run_warning_scan.ps1` before sign-off, or explicitly report why
  it could not be run. Resolve warnings by renaming shadowed identifiers,
  adding explicit casts for intended numeric conversions, or prefixing
  intentionally unused parameters / locals with `_`; use `@warning_ignore`
  only on the narrow statement whose warning is intentional.
- For `@tool` Godot UI scripts, remember they can run inside the editor
  before or after normal scene-tree attachment. Guard viewport / window /
  mouse-position / tree-dependent calls with `is_inside_tree()` and null
  checks such as `get_viewport() != null` / `get_window() != null`, and run
  a focused scene load if that script's `_process()`, `_draw()`, or input
  handling changed.

Item work routing:
- If the task adds or modifies an active / passive / legendary / mythic
  item at runtime, open `docs/item_runtime_checklist.md` before
  claiming the work is done.
- If the task ports or modifies an active-item, passive-item, legendary,
  or mythic item visual effect in Godot, apply the same Godot-native VFX
  remaster rule as character skills: preserve Python timing / gameplay
  behavior, but rebuild the final presentation through modular VFX
  layering: texture pieces or sprite sheets, runtime layer composition,
  `ShaderMaterial` uniform tuning, `GPUParticles2D`, and `Tween` or
  `AnimationPlayer` unless a documented low-cost fallback is intentional.
  Use `docs/item_runtime_checklist.md`'s Godot item VFX checklist for the
  item-specific audit.
- If the item work depends on academy / downtown / item-tree runtime
  skills or temporary effective-level bonus sources (spawn odds,
  passive-vs-active share, durations, cooldown-style math, or similar),
  treat that as runtime checklist work too. Audit the gameplay math,
  shared helper path, and any `Lv.6+` dynamic description / tooltip text
  together instead of fixing only one side.
- If a time-bound protection / immunity item reuses an existing shield,
  parry, timer, or HUD/VFX helper, verify the reused helper receives the
  item's real effective total duration, not a hardcoded base duration.
  See `docs/item_runtime_checklist.md` for the full runtime rule.
- If a shared runtime item helper already exists for that behavior
  (`get_effective_*`, shared roll-value helpers, or similar), call that
  helper from item-effect modules instead of recomputing academy bonus +
  raw `runtime_skill_levels.get()` logic or retyping per-level constants
  locally, unless base-only behavior is an explicit documented design.
- If the task also needs a new item icon or a character equip visual,
  open `.claude/skills/item-generation/SKILL.md` too.
- For passive / legendary / mythic items, do not stop at
  `PASSIVE_SLOT_ORDER`; also audit developer-mode `all_items`, normal
  field pickup and intended `unknown_item` routes, shop / crane / gacha /
  treasure-hunt paths, equip-gated effect behavior, reset on death /
  main-menu return, roll / polish / enhancement application, and
  Pandora's passive exclusion list in `legendary_items.py`.
- For new legendary / mythic items, treat each special acquisition path
  as a separate audit surface. Check Nemesis chest pools, treasure-hunt
  legendary pools, the stage-clear gacha candidate builder in
  `pingfighter.py`, `gacha.py` item classification / display sets, crane
  prize pools, and crane reward routing separately. A name appearing in
  one pool does not imply the other routes are wired.
- For any legendary / mythic route that can hand out both passive and
  active items, verify the grant path as well as the candidate pool.
  Passive mythics must not fall through `store_active_item()`, active
  mythics need the intended active grant / rarity path, and stage-clear
  gacha one-time gates must read ownership state rather than current
  equipped-state sync flags.

Sprite workflow mode switch:
- Asset-generation planning now also uses `.claude/sprite_workflow_settings.json`
  with `fast` / `precise` modes.
- Default is `fast`.
- `fast` affects asset-side depth only; it does NOT relax runtime safety
  checks in this file.
- Even in `fast`, do not skip the minimum runtime sanity checks required
  before claiming a sprite integration is done.

## Project Structure & Module Organization
- Current live project: `godot/project.godot`.
- Godot code and assets live under `godot/`; this is the only default
  implementation target for 디스크하츠 - 링피아.
- Legacy Python/Pygame paths are frozen reference material. See
  `## Legacy Python Reference (Frozen)` before using anything outside
  `godot/` as an implementation target.

## Critical Stage Mapping
- Godot live runtime: code `current_stage == 5` is user-facing **Stage 5
  Hongryun / Honglyeon** (`stage5_hongryun_*`, Chinese Fire).
- Godot live runtime: code `current_stage == 6` is not the active Hongryun
  route and is not currently the Nemesis route. Do not target it unless a new
  Stage 6 owner is explicitly introduced.
- Legacy Python docs may describe the original order as Stage 5 Nemesis and
  Stage 6 Honglyeon. Treat that numbering as frozen reference-only porting
  context; do not copy it into Godot runtime routing, tests, or asset names.
- See `docs/stage5_hongryun_godot_port_plan.md` for the current Godot Stage 5
  Hongryun policy before editing stage-specific logic, assets, or event code.

## Godot Playfield / Pillar / Overlay Clip Reality
The legacy Python `CLAUDE.md` "Legacy Python Screen Coordinate Standards"
section describes a `PILLAR_UI_WIDTH = 80` band carved out of game x=0..80 and
680..760 with playable area at x=80..680. **Do not apply that convention to
Godot.** In the live Godot runtime:

- **Playfield = full 760x750 game canvas (game x=0..WIDTH).** Ball physics,
  wall bounces, paddle motion, projectiles, particles, intro FX, and stage
  background all live in the full canvas. `battle_scene_config.gd`'s
  `PILLAR_WIDTH = 80.0` is a legacy in-game HUD band width carried over from
  Python; it is NOT a playfield wall inset. See the comment at
  `battle_scene_config.gd:7-9` and the matching note at
  `battle_playfield_scene_drawer.gd:23-25`.
- **Pillar chrome lives in the screen letterbox, OUTSIDE the game canvas.**
  `battle_view_layout.gd::build_game_layout()` centers the 760x750 game canvas
  inside the view with horizontal margins. The pillar background and ambient
  layers (clouds, trees, butterflies, hanji side regions, etc.) are drawn into
  those margins via `_get_side_rects(view_size, game_offset, game_size)` which
  returns rects in the range `[0, game_offset.x]` (left) and
  `[game_offset.x + game_size.x, view_size.x]` (right). When the user says
  "the spawn animation appears on the left pillar background", they almost
  always mean the screen letterbox, not an in-canvas pillar column.
- **Clipping rule for intro / cinematic / overlay draws.** Any animation that
  is sized in game coordinates and uses the `(game_offset, render_scale)`
  canvas transform must render inside a Godot Control with
  `clip_contents = true` whose rect matches the game canvas in fx-host-local
  space (position `Vector2.ZERO`, size = GAME_SIZE). Drawing directly on the
  battle scene canvas via `canvas.draw_*` is unsafe: a single
  `draw_set_transform(IDENTITY)` reset anywhere in the call chain strips
  `game_offset` from subsequent draws, and those draws then render in screen
  absolute coords — which lands in the letterbox and looks to the user like
  "the animation leaked into the pillar background". `stage_ball_spawn_intro`
  is the reference implementation: `stage_ball_spawn_intro_fx_host.gd` owns a
  `_playfield_clip` Control + `IntroSpawnDrawBridge` that proxies the intro's
  `_draw_spawn(self)`, and `stage_ball_spawn_intro_draw_lifecycle.gd`
  intentionally does NOT call `_draw_spawn(canvas)` on the battle scene
  canvas. New intro / overlay modules should follow the same pattern.
- **Do not clip overlays to the legacy 80px pillar inset.** Shrinking the
  clip to game x=80..680 crops legitimate playfield pixels (where the ball
  actually plays in Godot) and does not stop letterbox leaks anyway. Match
  the clip to the full game canvas; the letterbox protection comes from the
  clip rect matching the canvas, not from carving 80px columns out of it.

When adding any new fullscreen FX, cinematic, perk-flight, or overlay
renderer, check this section before deciding where to attach the draw call.

## Godot Degenerate `draw_colored_polygon` Trap

Any procedurally built polygon whose vertices are animated (jitter, sag,
sine waves, shrink/dissolve envelopes) WILL eventually self-intersect or
collapse onto a collinear/duplicate-point shape, and
`draw_colored_polygon` then fails triangulation with an
"Invalid polygon data" error **every frame** — the backtrace spam itself
costs frame time and can flood the log (218MB in one session). Four
shipped repeats of this exact class: `pillar_liquid_drawer` (charge sector
at radius ~0), trampoline mat (capture sag deeper than the mat thickness),
commando net field (dissolve shrink below the jitter amplitude), and the
deuce mini-scoreboard flame (tongues flattened exactly onto the closing
baseline edge).

Standing rules:
- Before shipping an animated-polygon draw, ask: at the parameter extremes
  (timer 0, full sag, full dissolve, scale 0.2, amplitude max), can the
  ring self-intersect, collapse to zero area, or touch its own closing
  edge? If yes, fix the GEOMETRY (epsilon lift / band-follow bottom /
  degenerate-radius guard) when the shape must stay visible every frame,
  or gate ONLY the fill behind a `Geometry2D.triangulate_polygon(...)`
  pre-check when a one-frame fill skip is invisible (line-based outlines
  keep drawing either way). Do not pick the skip-gate for an effect that
  is degenerate on MOST frames — it reads as flicker.
- Extract the point construction into a pure/static builder and seal it
  with a smoke that sweeps the animation parameters and asserts
  `not Geometry2D.triangulate_polygon(points).is_empty()` — and verify the
  smoke FAILS on the pre-fix geometry before committing. References:
  `active_item_trampoline_smoke._verify_mat_body_polygon_stays_triangulable`,
  `scoreboard_mini_deuce_flame_polygon_smoke`,
  `commando_firearm_runtime_vfx_smoke._verify_net_field_fill_guard_rejects_degenerate_polygon`.
- A burst of "Invalid polygon data" backtraces in a perf log is a
  first-class perf finding, not just noise — treat the error count as a
  regression signal during BattlePerf analysis.

## Build, Test, and Development Commands
- Godot load check: from `godot/`, run `.\tools\run_headless_load_check.ps1`.
- Godot warning scan: from `godot/`, run `.\tools\run_warning_scan.ps1`.
- Focused Godot smoke tests: prefer the repo-local wrappers under
  `godot/tools/` when available.
- Before making a Windows export that touches loading, runtime texture
  loading, Live2D-style sheets, lingpet cut-ins / click reactions, or
  stage-clear result visuals, run the focused export-regression smokes:
  `project_resource_loader_import_preference_smoke`,
  `lingpet_egg_runtime_smoke`, `battle_boot_resource_prewarm_smoke`,
  `stage_clear_result_asset_loader_smoke`,
  `stage_clear_result_scene_click_reaction_smoke`,
  `stage_clear_result_screen_smoke`, and `result_box_open_fx_host_smoke`.
  Then run the exported exe itself at least once with the repo's short
  headless smoke (`--headless --quit-after 3`) before handing off the build.
- Do not use legacy Python run / pytest / compile / PyInstaller commands as
  sign-off for Godot work. They are reference-only workflows.

## Coding Style & Naming Conventions
- Current Godot code: follow the existing GDScript style in `godot/`.
  Use typed variables where the surrounding module does, keep module owners
  small, and route resource loading through existing `res://` helpers.
- For Godot UI, verify font and texture resources through the live scene path.
  Keep visible fallbacks for missing assets instead of silently swallowing load
  failures.
- Export-build texture invariant: never gate runtime PNG / texture loads only
  with `FileAccess.file_exists(path)`. In exported builds, raw source PNG files
  and `.import` metadata may not be visible in the same way as the editor, while
  `ResourceLoader` can still resolve the packed resource. Route runtime visual
  loads through `ProjectResourceLoader.load_texture()` /
  `load_imported_texture()` / `prewarm_texture_threaded_step()` and make those
  helpers fall back through `ResourceLoader.exists/load` for packed resources.
  Optional source-file checks are acceptable for editor-only validation or JSON
  sidecars, but they must not decide that an exported texture is missing.
- Export-build asset STAGING invariant (mirror of the loader rule above): a
  PNG newly copied into `godot/` is not integrated until an import pass has
  generated `<file>.png.import` plus its dest `.ctex` under `.godot/imported/`,
  and the `.import` sidecar is committed with the PNG. A missing sidecar is
  invisible to `run_headless_load_check.ps1`, smokes, and the editor preview
  because the `ProjectResourceLoader` raw-PNG fallback decodes the source file
  directly — but the export build packs imported resources, so the texture can
  silently drop from shipped builds. Reference miss: the character select
  chamber backplate (2026-06-11) passed headless load check, warning scan, and
  three VFX smokes with no sidecar on disk.
  sheets, cut-ins, click reactions, and result-screen visuals must have a
  visible fallback if their texture is unexpectedly null. For result-screen box
  bodies, prefer `draw_texture_rect_region()` with an explicit source rect and
  transform over bespoke polygon UV drawing unless a focused export smoke pins
  the exact polygon behavior. The June 2026 regressions were: lingpet cut-in /
  click art disappeared because exported textures were rejected by raw
  `FileAccess.file_exists(path)` checks, and stage-clear result boxes
  disappeared in builds until their sheets were import-preferred and the draw
  path moved to texture-region rendering with fallback.
- Treat modal-open flags and menu-request flags as one-shot signals; mouse and
  keyboard paths must both clear them consistently after consume / cancel.
- For tooltip wrapping, reuse the current Godot tooltip/layout helper for that
  screen. Use legacy Python `_get_wrapped_tooltip_lines()` only as a parity
  reference during porting.
- When changing options / settings UI, trace the reachable Godot entry points,
  visible Korean labels, and runtime consumer. Legacy Python menus such as
  `start_menu.py` or `option.py` are reference-only unless explicitly porting.
- For new settings, wire one canonical settings key through every supported
  Godot entry path and verify the runtime consumer reads that same key.
- If a visual can come from both an on-disk asset and a procedural fallback,
  attempt the on-disk asset first and use the fallback only when file load
  fails.
- Treat user wording such as "그려줘", "그려달라", "draw this", or "make an
  icon" as an imagegen asset request. Generate or edit a real bitmap asset
  first, then copy the accepted PNG into the Godot asset tree and wire the
  loader/runtime path. Procedural-only drawing is a fallback only when the user
  explicitly asks for it or image generation is blocked.
- When replacing an existing icon or other visual asset, audit special-case
  loader branches for early returns that could bypass the new file even when it
  exists on disk.

## Legacy Python Reference (Frozen)
Use this section only when the user explicitly asks for original PingFighter
edits or when a Godot port needs a behavior comparison.
- Entry point: `pingfighter.py`.
- Old code folders: `core/`, `entities/`, `ai/`, `managers/`, `ui/`,
  `effects/`, and `items/`.
- Old runtime asset folders: `images/`, `fonts/`, `bgm/`, and `sounds/`.
- Old commands: `python pingfighter.py`, `python -m pytest tests/`,
  `python tests/test_framework.py`,
  `py -3 -m py_compile pingfighter.py entities\<sprite>.py`, `black .`,
  `pylint .`, and `pyinstaller -y PingFighter_Windows.spec`.
- Old Python style: Python 3.10+, PEP 8, 4-space indentation, `snake_case`
  functions/modules, `PascalCase` classes, and `UPPER_SNAKE` constants.
- Old Python asset loading: `resource_path(relative)`, `os.path.join`, and
  explicit `encoding="utf-8"` for text I/O.

## Runtime Icon / Skill Visual Integration
- For runtime-drawn perk / skill icons, audit every live ID path that can
  reference the icon (perk id, unlock id, runtime skill id, legacy alias).
  A bespoke branch under one name is not enough if the real HUD path uses a
  different id.
- For unlock-style active skills, do not stop after wiring the equipped
  orb skill id. If the visible perk card uses an `unlock_*` id and the
  live 5-orb HUD uses a different runtime skill id, both IDs must render
  the accepted motif intentionally. The default pattern is: orb HUD uses
  the skill PNG / bespoke symbol, and the unlock perk card uses the same
  motif with the established unlock badge. Verify `perk_id -> skill_id`
  mappings such as `_CHARACTER_UNLOCK_PERKS` before sign-off.
- For PNG-backed perk / skill orb icons, treat alpha cleanup and runtime
  draw size as part of the integration. Verify the PNG has transparent
  corners and a clean alpha bbox before scaling, and confirm the live HUD
  slot does not show a rough generated rim, black halo, or baked square
  edge. If the PNG already includes an orb rim / glow, do not blindly add
  procedural-icon padding such as `size + N`.
- For image-generated perk / skill PNG icons, generation is not integration.
  Copy the selected output into the workspace asset tree, add or audit the
  on-disk PNG loader/cache path, and make sure the live renderer tries that
  PNG before any procedural fallback or early-return branch.
- For Lingpet / Ringpet acquisition or click Live2D asset work, generation is
  not complete until the F7 Lingpet debug route can reach the pet. When adding
  or regenerating `cutin_art`, `cutin_anim`, `cutin_dismiss_anim`,
  `click_reaction_anim`, or `companion_click_reaction_anim`, also audit the
  pet's `lingpet_catalog.gd` entry, debug-enabled / available state, and
  `scripts/core/lingpet_debug_picker.gd` visibility before sign-off so the
  asset can be previewed through the F7 Ringpet debug flow even before normal
  hatch-pool promotion.
- For Lingpet / Ringpet in-game SD companion sheets, the accepted viewpoint is
  player-perspective rear view. A runtime-ready companion set needs three
  5x5 / 25-frame sheets by default: `companion_idle` (rear view, facing
  upfield / away from the player), `companion_move_left`, and
  `companion_move_right`. Left/right movement sheets must be rear three-quarter
  like Maribo, not full side profile: a slight face edge may be visible, but
  the body must read as facing the playfield with clear alternating foot / step
  motion. Do not satisfy this with a front-facing Live2D shrink or only one
  mirrored `companion_walk` sheet when dedicated SD work is requested. Wire the
  catalog / F7 debug route to the accepted directional sheets and keep
  `companion_walk` as the legacy fallback for older pets.
- Treat user wording such as "upscale", "upscaling", "hires",
  "업스케일", "업스케일링", or "real / Real-ESRGAN처럼" as a real
  Real-ESRGAN asset-processing request across item icons, HUD art, sprites,
  Live2D-style sheets, and runtime VFX. Do not satisfy that request with
  only Godot draw-scale changes, import filtering, Lanczos / nearest resize,
  or an imagegen redraw. Use the local Real-ESRGAN tool
  (`tools/realesrgan/realesrgan-ncnn-vulkan.exe`, default
  `realesr-animevideov3`, `-s 2` unless the user specifies otherwise),
  preserve alpha by upscaling RGB separately from the source alpha, and
  record the tool / model / scale / source paths in the manifest or handoff.
  For sheets, split cells or frames, upscale them consistently, recombine
  the original frame grid, and re-run transparent-corner / edge-touch checks.
- For image-generated runtime skill effects (boss fields, character skill
  auras, projectiles, cast loops, impact loops, refraction / magnetic /
  shield / elemental fields, and similar gameplay VFX), default to a
  **16-frame sprite sheet** unless the user explicitly requests a still
  image, a rough concept, or a deliberately shorter one-shot. The normal
  delivery shape is a 4x4 PNG sheet with a stable center / scale, generous
  transparent or chroma-key-safe margins, and no edge-touching sparks,
  rings, halos, or trails. This rule does not replace the separate
  8-frame instant-trigger perk-icon rule below.
- All final sprite-sheet asset generation must start from AutoSprite MCP
  output. Do not satisfy a requested boss / character / player / runtime
  VFX / animated item or perk sprite sheet with built-in imagegen, Gemini,
  FLUX, procedural drawing, local interpolation, or old anchor-frame
  recomposition unless the user explicitly approves that one-off fallback.
  Deterministic cleanup, slicing, frame-count expansion/reduction, mirroring,
  and runtime-sized exports are allowed only after the source frames are
  AutoSprite-derived.
- For player / character **standing** sheets, treat user wording such as
  "standing", "idle", "가만히 있을 때", or "스탠딩 시트" as the active
  stationary runtime idle sheet unless the user explicitly asks for concept
  art or a result pose. Integration is not complete until the primary idle
  texture key, any fallback idle texture key, frame count, grid rows /
  columns, animation cadence, renderer source-rect logic, smoke-test
  expectations, and sprite runtime checklist all agree. Do not leave an older
  front / back / helmet / costume identity sheet on a fallback path that can
  still win at runtime.
- For character-select click / confirm Live2D-style one-shots, run the
  dedicated `.claude/skills/sprite-generation/checklists.md` `0.6` gate.
  Runtime acceptance must compare the actual idle-to-click render, not only
  raw PNG cells: verify `confirm_intro_trim_rect`, `confirm_intro_stage_scale`,
  `confirm_intro_stage_x_offset_ratio`, `confirm_intro_stage_y_offset_ratio`,
  frame count / rows / columns, `confirm_intro_min_duration`, and voice path /
  delay / volume together. When a 49-frame AutoSprite output is expanded to 98
  or 147 frames, record the hold factor in the manifest / handoff and update
  the focused character-select smoke test so later work does not mistake held
  frames for newly generated motion. For voiced confirm shots, preserve the
  accepted ElevenLabs / TTS preset with source path, runtime path, voice ID,
  model, seed, settings, SHA256, volume, and delay.
- Runtime skill-effect sheet integration must be sheet-first with cached
  source-frame slicing and cached scaled textures. In Godot, keep generated
  VFX PNGs versioned under the Godot asset tree, expose explicit frame-count
  / frame-interval metadata, and use a fallback only when the PNG cannot load.
  Before sign-off, verify transparent corners / alpha bbox, no edge-touch
  frames from postprocess metadata when available, then run the Godot load
  check and warning scan for any `.gd` edits.
- For one-shot / instant-trigger runtime perks (for example `instant_*`
  perks such as full-gauge, dimension-gate, treasure-hunt, or similar
  immediate reward effects), default future icon work to an animated
  8-frame horizontal PNG sheet, not a static-only PNG, unless the user
  explicitly asks for a still icon. Use the accepted static PNG as the
  identity anchor, save a sibling sheet such as
  `items/<perk_id>_perk_icon_sheet.png`, and wire runtime as
  sheet-first -> static PNG fallback -> procedural fallback.
- Instant-trigger perk sheet loaders must follow the PNG-backed perk icon
  runtime rules: load through the owning Godot resource/cache path, slice and
  cache source frames once, cache scaled / state-specific draw resources,
  preserve alpha when dimming inactive states, and avoid per-frame sheet
  slicing or scaling work beyond cached frame selection.
- Before signing off an animated instant-trigger perk icon, verify the
  sheet has transparent corners and a non-edge alpha bbox, check the
  smallest real small-grid read with `Lv.1` and `Lv.5` labels, and run
  the relevant Godot load / warning / focused smoke checks after runtime
  wiring.
- For generated perk PNGs shown in small-grid UIs, clamp the draw size to
  the owning cell. Large-card `scale_multiplier` values must not let the
  icon bleed outside TAB character-info perk cells, academy / NPC offer
  boxes, swap cards, or status-panel grids.
- For PNG-backed perk icons rendered through `draw_skill_icon_mini()`,
  route small-grid draw sizes through the existing per-id clamp/helper
  (currently `_get_small_cell_perk_icon_size()`) or an equivalent per-id
  override before loading / scaling the PNG. PNGs with baked circular
  rims, glow frames, or source padding often need a runtime draw-size
  override in either direction: shrink if the rim crowds labels, enlarge
  if the main motif reads smaller than neighboring icons. Verify both
  `Lv.1` and `Lv.5` labels in the TAB character-info perk tab, not only
  the max-invested preview.
- In the TAB character-info perk tab, use the current `dash_module_control`
  / `모듈제어` icon read as the preferred small-cell size reference:
  substantial enough to feel polished, but still centered inside the cell
  with the bottom level label (`Lv.1`, `Lv.5`, etc.) fully readable. Do
  not chase maximum subject fill if it starts crowding or covering the
  level text.
- When creating or replacing perk icons, classify the icon family before
  drawing: character-exclusive active-skill / unlock perks and character
  passive / enhancer skill perks should keep the established round / orb
  visual language, while basic shared perks may use a freer silhouette or
  object style. In every family, keep the TAB `dash_module_control` /
  `모듈제어` small-cell read as the size reference.
- When dimming or tinting PNG icons for cooldown / inactive states, preserve
  the source alpha so transparent corners stay invisible.
- For panel-embedded perk / skill hover tooltips (TAB character info,
  perk grids, academy-style offer panels, other small-box UI), anchor
  the tooltip to the hovered cell / rect and clamp it inside the owning
  panel or at least the visible viewport. First-row entries must be able
  to flip below, and left / right edge entries must remain fully
  readable instead of clipping off-screen.
- For passive / enhancer perks that modify an existing active skill at
  runtime, treat the target active-skill tooltip as part of the shipped
  feature. If the effect is not obvious from the normal cost / cooldown
  lines alone, surface it in the orb tooltip with concise runtime
  synergy text using the real effective values, and keep that text
  consistent with any existing bonus-line lane for that character.
- When adding runtime synergy / bonus-line text to an orb tooltip, treat
  the tooltip layout as part of the feature too. Audit the real
  rendered-height budget so `how_to_use` / control-hint blocks, effect
  preview panels, and other lower sections do not overlap, clip, or
  become hard to read once invested-state text appears.
- For character skills or buffs with a player-tracked active duration,
  startup / hold timer, or timed persistence window, reuse the
  established right-bottom horizontal timer-gauge stack instead of
  inventing a one-off timer widget. Match the shipped size, stack
  behavior, and cleanup policy unless the user explicitly asks for a
  different HUD treatment. The bottom-most active timer bar must use the
  bottom baseline / stack index `0`; additional timer bars stack upward
  only when lower active timer bars exist. Do not hardcode a higher stack
  slot for a timer that can appear alone.
- For runtime-drawn character skill VFX that are meant to curve or home
  (fan / wave / slash projectiles, snake-like beams, similar procedural
  effects), route the detailed geometry QA through
  `docs/character_skill_perk_checklist.md` and the `CLAUDE.md`
  hidden-knowledge rule. A visual curve is not proven by X steering
  alone; the rendered body and cross-sections must also follow the
  curve.
- For runtime-tinted or cloned sprite / paddle surfaces (glitch clones,
  afterimages, low-HP variants, hit flashes), clip every additive /
  scanline / noise / fade overlay to the visible sprite silhouette. Do
  not let `SRCALPHA` transparent canvas receive the overlay, or a
  rectangular backdrop can appear around the sprite in gameplay.
- For enlarged runtime item-icon presentations (pickup popups, treasure /
  legendary acquisition, showcase cards), do not direct-scale the raw icon
  surface if it contains large transparent padding. Trim to the visible icon
  bounds and re-center it on a clean canvas first, or faint square/rectangular
  icon-box residue can appear during large acquisition effects.
- Judge runtime icon size by perceived subject fill in the smallest real UI
  box that uses it, not by a radius constant or the largest preview card.

## Fullscreen Bottom HUD / Pillar Frame Runtime Checklist
- Asset-generation details for large HUD frame art live in
  `.claude/skills/ui-hud-generation/SKILL.md`; runtime loading,
  placement, caching, and verification live here.
- Treat a generated bottom HUD frame as a real project asset, not a mockup.
  Copy the accepted PNG into the Godot HUD asset tree with a versioned
  filename, preserve the source / alpha-prep sibling when useful, and load the
  runtime PNG through the owning Godot resource/cache path before any
  procedural fallback.
- Do not stack a new generated HUD frame on top of the old frame pieces.
  If the generated asset already contains orb collars, rails, lower fill,
  or active-slot wells, suppress the older procedural / previous-image
  panels and native slot borders for that layer. Old pieces underneath are
  the usual cause of the "overlapped frame" look.
- Use live geometry as the alignment source of truth. Derive orb centers
  from the actual gauge surfaces (`_get_bottom_hud_orb_centers()` or the
  current equivalent) and derive active-slot rects from the same helper /
  renderer path that `draw_left_pillar_ui()` uses. Do not hand-place the
  HUD from screenshot-only coordinates.
- Player skill orb and dash-token orb placement are part of the HUD
  contract, not decoration-only details. When any bottom HUD / pillar
  frame changes touch these areas, audit the shared constants and helpers
  together: `PILLAR_LEFT_ORB_MARGIN_X`, `PILLAR_RIGHT_ORB_MARGIN_X`,
  `PILLAR_BOTTOM_ORB_MARGIN_Y`, `LEFT_PILLAR_ORB_INTERNAL_X_OFFSET`,
  `LEFT_PILLAR_ORB_BOTTOM_INSET`, `DASH_TOKEN_ORB_BOTTOM_INSET`,
  `PLAYER_SKILL_ORB_RADIUS`, `PLAYER_SKILL_ORB_GAUGE_GAP`,
  `_get_player_skill_orbit_radius()`, and `_get_player_skill_slot_angles()`.
  Do not tune screenshot offsets in only one draw path.
- If the skill orb size or gauge-to-skill-orb gap changes, verify the
  cooldown / ready rings scale with the new radius, the 4th / 5th skill
  orb visual gap still reads evenly, and the lowest / leftmost skill orbs
  are not clipped by the left pillar surface. Increase internal surface
  inset / center offsets rather than accepting cropped rings.
- The Heavenly Cape sixth skill orb is a special layout state. Renderers,
  empty-slot target lookup, and perk-flight animations must use runtime
  max-slot getters plus `_get_player_skill_slot_angles()` instead of
  hardcoding five slots. In the 6-slot layout, slot 1 intentionally rotates
  lower / leftward and slot 6 follows slot 5 without pushing into the map.
- Any X/Y symmetry tuning for the bottom gauge orb and player dash-token
  orb must also update dependent paths: tutorial highlights, gold / tooltip
  anchors, replay / capture HUD blits, unified bottom HUD source anchors,
  and the top boss dash-token orb X/Y alignment. The player dash-token orb
  and boss dash-token orb should share the same vertical axis unless a mode
  explicitly opts out.
- Measure source anchors from the PNG and document them beside the loader:
  left / right orb-hole centers, module rects, rail rects, slot-well rect,
  slot pitch, and any vertical anchor. Closed transparent orb holes can be
  measured by alpha connected components after chroma-key removal.
- Do not blindly scale one full-width HUD bitmap when the generated source
  aspect does not match the real fullscreen bottom area. Keep one coherent
  generated source, but it is acceptable to slice rails, lower body, orb
  modules, and slot tray from that same source and stretch only the
  repeatable spans. This preserves the one-piece visual language while
  avoiding orb / slot mismatch.
- Draw order matters for hiding seams: draw long rail / lower-fill spans
  first, draw left / right orb modules over the joins, then draw the slot
  tray / wells over the center if the tray must align to runtime slots.
  Avoid mixing unrelated procedural strips with imagegen strips unless the
  user explicitly accepts a fallback.
- Active-item icons must be aligned to the generated slot wells, not to
  the old panel. When the imagegen frame includes wells, call the slot UI
  in panel-suppressed mode and nudge icon content only as needed so icons,
  cooldown overlays, selection flash, and slot numbers stay inside the
  wells.
- Fill the lower empty apron intentionally. If the user asks for the
  bottom to feel "full," use lower-body / rail regions from the accepted
  HUD source rather than simply stretching the old frame downward or
  layering a second base underneath.
- Cache scaled HUD regions by `(source_rect, target_size)` and clear that
  cache from the shared surface-cache reset path. Do not slice or
  `smoothscale()` large HUD regions every frame.
- Before sign-off, verify: alpha bbox and transparent corners for the
  final PNG, Godot resource import/load, the repo-local Godot load check,
  warning scan if `.gd` changed, and one fullscreen preview or screenshot
  at the reported aspect ratio. Check
  that both orb fills sit inside their collars, active items do not pierce
  the slot frame, the player paddle is not covered, no old frame overlaps
  are visible, and the lower apron is filled without clipping off-screen.

### Layered Imagegen Pillar Background Runtime Checklist
- New or redesigned stage pillar backgrounds should default to the
  imagegen layered-sprite structure used by Stage 1, not a pure
  code-drawn / procedural illustration. Procedural drawing may remain
  only as a fallback for missing assets or tiny overlay accents.
- Treat PingFighter's world premise as a full-immersion virtual reality.
  Even when each stage has a different historical, fantasy, arena, nature,
  or sci-fi theme, the final pillar background should include a restrained
  common layer of cyberpunk / parallel-universe language: holographic seams,
  neon circuitry, dimensional rifts, data-glitch accents, virtual scan
  lines, or similar motifs. These accents should support the stage theme,
  not replace it or turn every stage into the same neon scene.
- Prefer the restrained, readable direction established by the Stage 2
  minimal jungle pillar background. New pillar backgrounds should protect
  gameplay readability and pursue visual simplicity / negative space
  before decorative density: avoid overfilled, overly bright, or overly
  ornate scenes that compete with the ball, paddles, boss, HUD, or active
  gameplay effects. Theme detail is welcome, but it should sit mostly in
  quiet silhouettes, sparse foreground sprites, thin frame language, and
  low-contrast accents rather than filling every pillar area.
- Split the art into intentional runtime layers: a static base PNG, one
  or more transparent foreground / motion sprite sheets, and optional
  event-reactive sprites such as trees, banners, clouds, lanterns, water,
  smoke, or debris. The base PNG should omit any object that needs to move
  independently.
- Save accepted assets under the Godot HUD / stage asset tree with versioned
  names. Keep chroma-key `_source.png` siblings for generated transparent
  sprites when useful, and load every runtime PNG through the owning Godot
  resource/cache path.
- Load, slice, trim, and cache imagegen sprite sheets once at module /
  background initialization time. Scale layer sprites only during init or
  `resize()`, never inside per-frame `update()` or `draw()`.
- If the user asks for an outer picture-frame border around the central
  gameplay field, treat it as pillar / background chrome rather than a
  center-field overlay. Draw it from the pillar background renderer, clip
  the live central gameplay rect out of the blit, and keep the central
  field alpha-empty. The frame should visually wrap the field from the
  outside, with left / right posts in the side pillars and top / bottom
  rails in the available top / bottom pillar bands when those bands exist.
- For picture-frame borders, do not preserve the source aspect ratio if it
  pushes the top or bottom rail off-screen. Use live geometry as the
  authority: scale X and Y independently, or slice stretchable rails from
  the same source, so all four sides read as one surrounding frame at the
  current aspect ratio.
- Draw order should stay explicit: static base first, slow ambient sprite
  layers next, event-reactive sprite layers over them, then foreground
  particles / butterflies / gameplay border highlights. If the base omits
  a tree or other object, the sprite layer must draw in the idle state too,
  not only while shaking or reacting.
- Clip moving layer draws to their owning pillar region. Left, right, and
  bottom pillar art must remain visually harmonious as one background set,
  and motion should not bleed into the transparent playfield.
- Use the existing pillar cache policy deliberately. Ambient loops such as
  clouds should use the periodic pillar refresh path, while short gameplay
  reactions such as wall-impact tree shake, butterfly absorption, or
  similar event sprites should force refresh only while active.
- Before sign-off on a layered pillar background, verify transparent
  corners / alpha bbox for every sprite sheet, Godot resource import/load,
  the repo-local Godot load check, warning scan if `.gd` changed, a static
  preview, a motion preview, an event-reactive preview, and one targeted
  draw-time sanity check if new large translucent layers were added. For
  picture-frame borders, also sample or inspect that the central gameplay
  rect remains alpha-empty while the intended side / top / bottom pillar
  regions contain visible frame pixels.

## Boss Sprite Workflow
- Asset-generation details belong in `CLAUDE.md`
- Future boss / character / player sprite sheets must be generated from
  AutoSprite MCP output before runtime integration. If a sheet was produced
  by another route, treat it as a temporary concept/placeholder unless the
  user explicitly approved that exception.
- Runtime integration belongs in the current Godot owner module under
  `godot/`. Legacy Python references in this section describe prior
  PingFighter wiring patterns to inspect during porting, not default edit
  targets.
- Shared state-to-sheet vocabulary lives in
  `docs/sprites/boss_sprite_runtime_contract.md`; check it before adding
  new runtime keys or porting sheets to Godot.
- Per-boss compact runtime contracts live under `docs/sprites/`, starting
  with `docs/sprites/stage1_dalji.md`.
- Expected Godot asset pattern: keep accepted runtime PNGs under the relevant
  Godot asset tree, with explicit sheet grid / frame-count / cadence metadata
  near the consuming renderer or catalog.
- Legacy Python asset pattern, for reference during ports:
  `items/[name]_boss_sheet.{png,jpeg}`,
  `items/[name]_boss_attack.{png,jpeg}`,
  `items/[name]_boss_dash.{png,jpeg}`, and
  `items/[name]_boss_turn.{png,jpeg}`.
- Expected Godot code pattern:
  - identify the stage / boss / renderer owner module first
  - add resource loading and cache/prewarm metadata through that owner
  - wire reset / round-boundary cleanup explicitly
  - wire attack, dash, cast, stun, victory, defeat, and optional facing
    transition states through Godot draw/update contexts
  - add or update a focused Godot smoke when the state mapping is risky
- Legacy Python code pattern, for reference only:
  sprite class in `entities/[name]_boss_sprite.py`, import/init/reset wiring
  in `pingfighter.py`, stage render branch in `pingfighter.py`, attack/dash
  trigger wiring in gameplay logic, and optional turn selection in sprite
  update logic.
- When walk, attack, dash, and optional turn sheets exist for the same boss, treat them as one animation set with one body-size reference
- Dash or attack effects may extend outward, but the body silhouette should stay stable across sheets
- Judge cross-sheet consistency by **visible body read** (head height, face size, torso silhouette in-game), not only raw canvas / frame size -- action sheets that are technically the same size but read visibly smaller due to outward effects, flame halos, or trails have failed the scale check
- Effects, trails, and motion lines must not cause the character's body or face to read smaller than the walk baseline at gameplay scale
- If attack or dash integration makes the perceived body / face class drift below the walk baseline, prefer a small runtime upscale on the action sheets over accepting a shrunk body read
- A turn sheet is an optional support sheet for brief facing changes only; it is not the default replacement for the main walking cycle
- Unless the design explicitly adopts multi-angle walking, normal movement should continue using the main walk sheet and the turn sheet should appear only during short left/right facing transitions
- For front-biased / front-facing walk bosses, the default turn design is NOT a body-angle rotation chart. Turn should stay visually tied to the frontal walk and express the direction change through a short characterful accent: chin lift, head tilt, shoulder hitch, arm pose swap, one-knee lift, small hop / pivot, ribbon / skirt rebound, or another signature habit that fits the boss
- Turn should read like a brief transition gesture that connects left-travel walk back into right-travel walk (and vice versa), not like the boss is spinning to show side-profile angles to the camera
- Stage 1 Dalji is the current per-boss exception: her accepted v7 walk is direction-aware off-frontal, so `assets/dalji_boss_turn.png` is intentionally an 8-frame angle-rotation auxiliary from right-facing to left-facing. Runtime may use only a short, target-biased slice from the 4x2 row-major sequence (`F4-F8` for right-to-left, `F5-F1` for left-to-right) so the boss does not visibly travel one way while staring the other way. Stable travel must still use the walk sheet rather than the turn sheet.
- If a turn sheet is accepted for runtime playback under an explicit policy despite small cosmetic divergence, document it as a **runtime-only auxiliary non-anchor** sheet. The walking sheet remains the sole identity anchor for future regeneration unless explicitly reclassified later
- For front-biased or front-facing walk sheets, "front-biased" means the boss still reads as facing the player during stable movement. It does NOT mean a hidden 3/4 walk that consistently reads as looking left or right in-game
- A front-biased walk fails QA if hair mass, ribbon placement, hat tilt, eye placement, cheek visibility, shoulder exposure, torso angle, or other asymmetry makes stable movement read as "the boss is looking to one side" instead of "the boss is facing forward"
- If a regenerated walk sheet reads more side-facing than the last accepted walk sheet, reject it even if animation energy improved. Liveliness is not allowed to trade away frontal combat readability
- Recommended runtime priority when a turn sheet exists: `dash > attack > turn-transition > walk > idle`
- Runtime may play only a short transition slice of the turn sheet if that keeps the direction-change accent readable. The turn sheet exists to bridge walk-to-walk with characterful motion, not to force a full visible spin
- If a turn frame looks face-clipped, forehead-cut, or "cropped" in gameplay, compare the raw cell, post-inset crop, trimmed frame, and gameplay-size render before changing runtime scale. If the same clipped-looking read already exists before runtime fitting, it is an asset-side failure, not a runtime crop bug
- Do NOT keep stacking stronger turn-only downscale just to hide a clipped-looking peak transition pose. If the key turn frames still read chopped after a conservative fit, reject the turn art and prefer disabling visible turn playback until the art is regenerated
- If the turn sheet still reads as a different character, breaks the frontal walk connection, or feels like unrelated acting pasted on top of the walk, prefer disabling turn playback entirely and keep normal lateral travel on the walk sheet until art is fixed
- Do NOT paper over an asset-side frontal-read failure with runtime facing remaps, blind left/right flipping, or by silently redefining which travel direction uses which frame set. If the accepted walk no longer reads as a forward-facing walk, roll back to the previous accepted walk sheet and regenerate the art
- For bosses whose design goal is "walk stays frontal, direction changes get a small hop / pivot accent," a hop-only runtime transition without visible turn-frame playback is an acceptable fallback when the turn sheet is mismatched
- Victory sheets must read as an actual win / celebration sequence at gameplay scale. If a replacement victory sheet preserves identity but still reads like a walk loop, turn extension, or flat idle posing, treat that as an asset-side failure and regenerate instead of shipping it as-is
- Treat `hit` naming as ambiguous in sprite runtimes. A legacy key such as
  `boss_hit_sprite_sheet` may mean "the boss hit the ball" rather than "the
  boss got hit"; do not map ball-contact animation keys to stun sheets. Use
  explicit attack and stun keys/states where possible, and verify the mapping
  against `docs/sprites/boss_sprite_runtime_contract.md`.
- For projectile-casting bosses, the actual projectile launch event must trigger the matching cast / attack animation. Do NOT restrict attack-animation triggers to ball-hit timing alone when the boss also has explicit projectile-launch events -- cast timing and attack timing must be wired separately
- For contact-based strike sheets (chops, punches, hammer hits, paddle-hit attacks), the default runtime trigger model should be anticipatory / pre-contact rather than pure ball-hit-only. If the sheet has visible prep before impact, start it slightly before predicted contact so the prep frames are seen and the impact frame lands at or near the actual hit; keep a ball-hit fallback when prediction can miss
- Directional left / right contact-attack sheets must select side from the actual ball contact X relative to the paddle / boss center. Ball left of center plays the left attack sheet; ball right of center plays the right attack sheet. Do not select attack side from walk direction, actor velocity, last facing, or pre-contact prediction alone
- The good default is a SHORT, conservative pre-contact lead window, not an early cinematic wind-up. If anticipatory triggering makes the swing visibly fire before the ball arrives, narrow the lead window or start from a later frame; do not keep widening anticipation just to show more prep
- Anticipatory contact attacks must never trigger from time-to-contact alone. Gate them with spatial proximity to the paddle / boss hitbox as well as approach direction, and reject any implementation where a fast ball can start the swing from mid-field or while clearly outside the strike lane
- **Cross-boss size standard: Stage 3 Menhera body class is the STANDARD, not a soft baseline.** Every new petite human / chibi boss must hit that size class at Godot integration time. Legacy reference numbers from `pingfighter.py`: Menhera used a `176 x 88` target frame canvas derived from `BOSS_IMG_WIDTH=160`, `BOSS_IMG_HEIGHT=80`, and `+10%` width scaling. Treat those numbers as parity measurements for the Godot renderer's canvas / source-rect / stage-scale settings, not as an instruction to edit or call `pingfighter.py`. The visible body in-game must read at the same gameplay-size class as Menhera in side-by-side comparison.
- **Do NOT rely on legacy sprite class default constructor args for size.** Several frozen Python classes shipped per-boss tuned defaults — Menhera class default `79 x 88`, Tauren `83 x 92`, Honglyeon `100 x 88` — that would each silently push a new boss into a different size class if copied. In Godot, set the consuming renderer/catalog metadata explicitly so the intended canvas, source rect, stage scale, and body read are visible in the owning module.
- Size-class exceptions (large-frame Tauren, vertical Honglyeon, deliberate oversized / undersized concept bosses) must record the explicit Godot canvas / scale target and the design reason both in `CLAUDE.md` (under that boss's per-boss policy section) and in the handoff / implementation note that introduced the override. Never let a size override slip in implicitly via copied legacy defaults.
- Runtime integration for a new petite human / chibi boss must NOT rescale it to a size that drifts noticeably from Menhera's body class without explicit design intent. After install, run a side-by-side gameplay-size comparison vs Menhera (head height, face size, torso silhouette) and reject the integration as not done if the new boss reads materially smaller or larger.
- Small in-game readability baked into the source sheet should be preserved during integration; do not layer downscaling, blurring, or extra transforms that erase the readability achieved at the asset stage

## Legacy Sprite Class Reference Pattern
This section describes the frozen Python/Pygame sprite class pattern. Use it
only as a porting reference when mapping old boss behavior into Godot.
`entities/tauren_boss_sprite.py` is the legacy reference implementation for
boss sprite classes.
- Use a `FRAME_INSET` constant (value `14` is the known-good recommendation) to exclude grid lines, cell borders, and label bleed from each source cell.
- After inset, call `_trim_to_visible_bounds()` to compute a tight bounding box and strip transparent margin.
- Apply `_scale_to_target()` to resize to the target in-game size while preserving aspect ratio.
- Store each motion in its own frame buffer: `_frames_right` for walk, `_attack_frames_right` for attack, `_dash_frames_right` for dash, `_turn_frames_right` for the optional turn sheet. Do NOT reuse one buffer across motions.
- Expose `trigger_attack()` that plays the attack sheet once and returns to idle/walk state. Mirror this pattern for dash and turn triggers when those sheets are present.
- The scale factor MUST be derived from the walking sheet and reused across attack / dash / turn. The "no per-sheet rescale" rule in the following section is the rationale.
- In-class JPEG cleanup is a runtime safety net only; it does not replace the offline PNG nukki pipeline owned by the `sprite-generation` skill.

## Godot Sprite Runtime Performance Rules
- Treat large 2K sprite sheets as source assets, not hot-path data.
- Prefer offline-prepared PNG assets imported into Godot over JPEG fallback
  whenever possible. Runtime JPEG cleanup is a legacy safety net only.
- Expensive preprocessing such as trim, halo cleanup, outline generation,
  source-rect detection, and downscaling should happen before runtime or once
  during a controlled load/prewarm path.
- Never do heavy sprite-sheet preprocessing inside per-frame update or draw
  code.
- Avoid rebuilding large sprite resources, `ImageTexture`s, materials, or FX
  hosts repeatedly across rounds or state transitions unless strictly needed.
- If sprite initialization is expensive, prefer lazy-load, prewarm, and
  one-time caching over repeated reconstruction.
- Cache common source rects, animation frame metadata, scaled textures, and
  material variants when reused.
- **Never `.duplicate(true)` a large `const` catalog/data dict inside a
  per-frame read-only getter.** GDScript `Dictionary.duplicate(true)` is not
  free, and a companion/boss draw+update loop hits these getters dozens of
  times per frame, so cost = entry size × call frequency multiply into a real
  hitch as the data grows (the 2026-06 lingpet frame-drop regression:
  `LingpetCatalog.get_entry()` deep-copied the `PETS` entry on every
  `get_visual_path` / `get_visual_layout_value` / `get_stat` /
  `get_display_name` / `get_active_skill_pool` call, and `get_active_skill()`
  rebuilt the whole common passive pool twice per call — invisible until the
  catalog doubled to 8 multi-skill pets). Keep the PUBLIC accessor deep-copying
  for mutating external callers, but route non-mutating hot getters through a
  shared non-copying `_get_entry_ref()`; when only one pool entry is needed,
  look it up in the `const` directly and apply level once instead of building +
  discarding the whole pool. Safe because Godot 4 locks `const` containers
  read-only (an accidental mutate throws instead of silently corrupting) and
  hot getters return scalars or already-`.duplicate()`d skill dicts. Verify with
  warning-scan + headless-load + a DETERMINISTIC smoke (ref vs deep-copy must
  yield identical values). This is a DIFFERENT class from the hot-path
  lazy-init trap (that one is first-call construction; this one is steady-state
  per-frame copying).
- **Round / event-boundary hooks must not re-run a full owner sync "just in
  case".** A runtime's `on_round_start`-style hook that ends with the full
  multi-hundred-key owner sync (`mythic_item_owner_syncer.sync_owner` = 254
  `owner.set` attempts, ~1.5ms) re-pays that cost on EVERY round restart even
  when the hook changed nothing. Reference failure (2026-06-10): mythic
  `on_round_start` ran it TWICE per restart (unequipped adversity-armor branch
  + trailing sync) — `physics.reset_ball.mythic_round_start` 3.0~3.5ms, a
  guaranteed frame doubling on the round-resume frame at 72 FPS. The full sync
  belongs at equip / unequip / stage-advance / load time, where the mutating
  call sites already run it. An event hook should (a) full-sync only when the
  hook actually changed owner-visible state (gate like the adversity-armor
  unequipped branch), and (b) otherwise run only the change-gated transient
  pass (`sync_transient_owner_state`) as a drift net. Note the schema reality:
  direct keys missing from `battle_scene_state.DEFAULT_VALUES` were silent
  no-ops anyway — the real propagation channel is the schema-listed
  `mythic_item_state` dict, which the transient pass updates. Seal the budget
  with a set-attempt-counting schema-gated owner smoke
  (`mythic_round_start_sync_smoke.gd` is the reference; it fails at 254
  attempts when the full sync is restored).
- **Bounded threaded texture prewarm — keep the DEFAULT hard bound short.**
  `ProjectResourceLoader.prewarm_texture_threaded_step()` shares ONE threaded
  load slot and is polled once per frame by a caller that blocks its visible
  progress bar on `done == true`. Every shipped caller runs behind a loading /
  stage-transition / acquisition-cinematic screen (boot warmup steps, the
  stage-transition work loop, stage-clear result assets, mythic / lingpet
  cut-ins). There, a threaded load that gets STUCK in a non-terminal status
  freezes the bar at whatever plateau that step maps to — the reported Stage 1
  boot 48% (`finish_resources` → stage1 pillar bg), 81% (`stage_runtime_resources`),
  86% (`stage_clear_result_assets`), and the Stage 2 transition 92%
  (`STAGE_TRANSITION_LOADING_PRE_COMPLETE_PROGRESS`) freezes were all this. A
  sub-2s sync fallback (`load_texture`) is INVISIBLE behind that same screen,
  so a short bound + fast sync recovery is correct for the loading path.
  Therefore `THREADED_TEXTURE_PREWARM_MAX_MSEC` / `_MAX_POLLS` MUST stay short
  (currently 1800ms / 240). Raising the DEFAULT to "keep slow-but-progressing
  loads threaded longer" (a 30s experiment) silently regresses EVERY
  loading-screen caller back into multi-minute plateaus — it trades the
  invisible main-thread hitch for a very visible bar freeze. The long
  keep-threaded behavior is OPT-IN per caller via an explicit larger
  `max_msec` / `max_polls` (only justified for a genuine live-gameplay caller
  that would rather defer art than hitch). The regression is sealed by a
  numeric assertion in `project_resource_loader_import_preference_smoke.gd`
  (`MAX_MSEC <= 3000` / `MAX_POLLS <= 600`); do not loosen it. Cross-path
  callers HARVEST a finished foreign load (store + clear + retry) instead of
  waiting for expiry, and the boot budgeted warmup additionally calls
  `try_resolve_finished_threaded_prewarm()` once per frame BEFORE batching —
  without that, a slot orphaned by the menu-idle
  `battle_entry_background_prewarm` (scene changed mid-load) holds the
  in-flight gate true and throttles the whole loading batch to one step per
  frame even though the worker already finished. Keep both the harvest branch
  and the per-frame resolve when touching the slot (sealed by
  `battle_entry_background_prewarm_smoke.gd`). A genuinely
  oversized source sheet (e.g. a 12k×6k+ Real-ESRGAN result Live2D sheet) is a
  SEPARATE problem — downscale / compress the asset, do not widen the timeout
  to mask the slow upload. The symptom is a single ~0.5–1.5s main-thread FREEZE
  the first time the sheet uploads to VRAM (the GPU upload of a ~500–800MB
  uncompressed texture cannot be backgrounded in Godot, so it stalls one frame
  wherever it first lands — e.g. the demo `stage_transition_loading.step.5`
  stage-clear-result prewarm froze 1510ms uploading the 15488×12672 / 16128×8064
  hq1408/hq1152 result sheets). The fix is to import these big result/cutscene
  Live2D sheets at DISPLAY-MATCHED size via `process/size_limit` in the `.import`
  (the stage-clear result screen only draws the actor at ~760px, so 1408/1152px
  source cells are ~2–9x oversampled; 2026-06 capped them to 896px cells via
  `size_limit=9856`/`12544`). When you change the imported cell size you MUST
  also: (a) keep the runtime per-cell slice constants
  (`PLAYER_VICTORY_CELL_SIZE` etc. in `stage_clear_result_scene.gd`) equal to
  the new imported cell px, and (b) keep any source-cell-pixel offsets (e.g. the
  victory click-rect in `stage_clear_result_layout_helper.gd`) expressed against
  the original authored source resolution (or scaled with the cell size) so the
  on-screen geometry does not move. Source PNGs stay untouched — `size_limit`
  only shrinks the imported texture, so there is no visible quality loss at the
  display size. Trap when verifying: the open editor caches `.import` in memory
  and re-reverts headless reimports of changed sheets, so chain `--import` +
  the texture-loading smoke (or restart the editor) to read a consistent state.
- **Frame-budgeted batching of a one-step-per-frame loading loop must YIELD on
  the shared threaded prewarm slot and on the PSO prewarmer node.** The boot
  warmup loop used to advance exactly one (sub)step per process frame, so
  ~2,100 mostly sub-millisecond step invocations paced Stage 1 entry loading at
  wall-clock frame rate (~30s at 72 FPS for ~11s of measured work). The fix is
  `battle_boot_warmup_controller.run_boot_warmup_steps_budgeted()`: pack
  synchronous substeps into one frame under a time budget + per-frame step cap.
  When batching ANY other step loop on this pattern (e.g. the stage-transition
  work loop), two waits must stay one-call-per-frame or they break: (1) the
  shared `prewarm_texture_threaded_step` slot — its STALE/MAX bounded-fallback
  counters assume ~1 poll per frame, so same-frame spin-polling hits
  `MAX_POLLS` (240) early and silently demotes a healthy threaded sheet load to
  a synchronous main-thread fallback (gate on
  `ProjectResourceLoader.has_threaded_prewarm_in_flight()`); (2) a live
  `BattlePsoPrewarmer` node — GPU pipeline warmup advances per RENDERED frame,
  not per call, so batching its wait just busy-spins. The shared slot is NOT
  the only threaded state: `battle_resources` owns its own transition/result
  threaded slots via direct `ResourceLoader.load_threaded_request` (exposed as
  `battle_resources.is_threaded_prewarm_in_flight()`), and missing that gate
  made the budgeted loop spin-poll boot step 02 from 172 to 7,469 calls on a
  real Stage 1 entry. Before batching a loop, grep its steps for EVERY
  module-owned `load_threaded_request` slot and add each to the yield gate.
  Also bound unknown wait-poll steps with a max-steps-per-frame cap. Sealed by
  the budgeted verifies in `battle_boot_resource_prewarm_smoke.gd`.
- **`size_limit` is BYPASSED by `ProjectResourceLoader.load_texture()` — it
  decodes the RAW source PNG first.** `load_texture()` (project_resource_loader.gd)
  tries the in-memory `_texture_cache`, then `Image.load_from_file(raw_png)`
  BEFORE the imported `.ctex`, so a caller that `load_texture()`s a big sheet on
  a cache miss decodes the full-size source and ignores `process/size_limit`
  entirely. The stage-clear result `size_limit` fix only worked because the
  transition prewarm (`prewarm_texture_threaded_step`, which uses the IMPORTED
  threaded path) populated the cache first, so the later `load_texture()` hit the
  cache. With NO prewarm, the first draw decodes raw and the freeze stays — this
  was the lingpet acquire cut-in 1141ms freeze (8192×8192 `maribo_cutin_anim`
  loaded by `load_texture` on the first reveal draw). Fix for a `load_texture`
  caller of a big sheet: (1) `process/size_limit` on the `.import`; (2) switch
  the load to `ProjectResourceLoader.load_imported_texture()` so it reads the
  size-limited `.ctex`, not the raw source; (3) for the heaviest sheets, DON'T
  sync-load on the first visible draw — stream them via a per-frame threaded
  prewarm (`prewarm_texture_threaded_step(..., prefer_imported_fallback=true)`)
  during an intro/loading window and draw a small fallback (e.g. a static art) of
  the same subject until the streamed sheet lands in cache. The cut-in
  (`lingpet_acquire_cutin_overlay_host.gd`) does all three: 13 cut-in sheets
  capped to 768px cells, `load_imported_texture`, and `prewarm_pet_assets_step`
  stepped each `draw()` frame while the static `cutin_art` covers the ~0.1s.
  Sibling still open: the companion click-reaction sheets
  (`*_click_live2d_pingpong_98f.png`, 14336×7168 / 16128×8064, `size_limit=0`)
  are the same class and will freeze on first click until given the same fix.
- Particle/effect cost is multiplicative: particle count x lifetime x layer
  count x translucent radius. Small-looking increases across multiple axes can
  still add visible frame cost.
- Legacy Pygame `Surface`, `pygame.transform`, and `pygame.gfxdraw` guidance is
  reference-only. When porting it, translate the intent into Godot resource
  caching, shader/particle reuse, and explicit host lifecycle cleanup.
- New Godot sprite integrations must not independently trim-and-rescale walk,
  attack, dash, and turn sheets in ways that change perceived body size.
- Use the walking sheet as the scale reference for attack, dash, and turn when cross-sheet body size must remain consistent
- Do not let a turn sheet hijack normal walking unless multi-angle walking is the explicit approved design goal
- If a generated sheet is too large or noisy for runtime comfort, export a runtime-ready version instead of pushing cleanup cost into startup
- When a boss package adds multiple large motion sheets (walk + attack + dash + turn), review the aggregate load cost as well as per-frame cost; stage-entry hitch can regress even when animation playback is cheap
- Before blaming a new sprite for stage slowdown, also inspect stage-specific background and event systems; Stage 5 and Stage 6 already have animated backgrounds and continuous event updates
- **Atlas sheet grid authority**: when a renderer reads cells from a multi-cell
  PNG via `draw_texture_rect_region` / `texture_rect_region` slicing, the
  `(cols, rows)` grid MUST be defined per-asset, not via a single shared
  `SHEET_COLS / SHEET_ROWS` constant that all assets reuse. Real migrated
  atlases vary widely — vase/lantern PNGs may be 2x1 mirror pairs, lotus pulse
  sheets may be 8x1 horizontal strips, dragon-head 16f sheets are 16x1, motion
  ambient atlases may be 3x2, and other sheets may be 4x4 or 4x2. Slicing a
  2x1 mirror asset as 4x4 produces a square fragment surrounded by smaller
  fragments of unrelated cells, which in-game reads as a "box with sticks
  inside" overlay rather than the intended sprite. Pattern for new owners:
  declare per-asset `<NAME>_COLS`, `<NAME>_ROWS`, `<NAME>_FRAMES` constants,
  pass them into the shared `_draw_sheet_frame(... cols, rows)` helper, and
  modulo every frame index by the per-asset frame count (not by a global
  16-cell assumption). When a new atlas asset is added or migrated, the
  asset-side manifest must record the grid explicitly so renderer constants
  cannot drift again. The Stage 5 홍련 left-pillar wallmount regression is the
  reference failure (2026-05-18). Verification: zoom-render every animated
  atlas frame at runtime size and compare against the source PNG before
  shipping; a single mismatched grid silently corrupts every frame in that
  sheet without throwing an error.

## Stage Integration Checklist
- Confirm the real stage-to-code-stage mapping first
- Verify Godot asset filenames, `res://` paths, importer state, and owning
  loader/cache metadata
- When replacing a player / boss sprite state, audit every key that can
  render the same state: primary sheet key, fallback texture key, legacy alias,
  prewarm/cache key, renderer direct-read key, update-context flag, draw-context
  grid metadata, and smoke-test expectation. Do not leave the old asset wired
  through a fallback unless that fallback is explicit and documented. Known
  traps include `player_idle_back_sheet` vs `player_idle_sprite_texture` and
  `boss_attack_sheet` vs `boss_hit_sprite_sheet`.
- Add import/init/reset wiring safely in the owning Godot module
- Verify render branch size, offsets, and facing logic
- Verify attack trigger timing aligns with the gameplay event. For contact-based strike sheets with visible prep, prefer an anticipatory / pre-contact trigger so prep frames are visible and the impact frame lands at or near ball-hit instead of a beat late
- Verify attack and stun sheet mappings as separate runtime states. In
  particular, `boss_hit_sprite_sheet`-style legacy names must be audited so
  ball-contact paths select attack sheets and real stun/electrocution paths
  select stun sheets.
- Electrocution/shock is a SHARED, source-agnostic symptom with TWO shared
  layers — do not hand-roll bespoke arcs per skill. The original sold "감전"
  through the boss body convulsing + flashing cyan-white; rich arc/spark
  overlays around a still, full-colour boss read as decoration, not
  electrocution. The two shared layers, both driven per-frame by every stage
  boss actor renderer (`stage1`–`stage5`):
  1. BODY layer — `scripts/status/boss_electric_stun_visual.gd`: high-frequency
     sprite tremble + cyan-white tint applied to the boss sprite.
  2. FIELD layer — `scripts/effects/boss_electrocution_field_fx_host.gd`: a
     BODY-CONFORMING electrocution host — a BOX-emission hot spark shower over
     the body box + procedural discrete-tick crackle bolts jumping across the
     body + white-hot contact flashes + a faint underglow + Tween envelope, all
     additive. Deliberately NOT a centred energy ring / concentric-halo / orbiting
     arc — that composition reads as "magic", not "sparks searing the body" (user
     feedback 2026-06-04). Driven by the static
     `drive_from_context(canvas, boss_center, context)` one-call driver. CRITICAL:
     the host parents to the boss renderer's canvas, whose playfield mapping is
     applied via `draw_set_transform()` inside `_draw()` — which child NODES do
     NOT inherit. So the host BAKES `game_offset + (playfield_center) * render_scale`
     with `scale = render_scale` itself (read from `context`), then renders its
     own `_draw()` + children in local space. Do NOT feed raw playfield coords
     assuming inheritance (the `CommonStarpointVisualHost` "canvas coords" pattern
     is NOT a safe template here) — skipping the bake detaches the field to the
     top-left letterbox corner (this exact regression has recurred;
     `boss_electrocution_field_fx_host_smoke.gd` pins
     `host.position == game_offset + center * render_scale` to seal it).
  Any new electric/shock stun must light up BOTH layers by setting
  `ragnarok_hammer_electric_stun_active`, or by applying a central stun status
  with `electric_stun: true` (which `status_effect_state` propagates to
  `boss_electric_stun_active`) — drawing your own arcs is an incomplete,
  off-identity electrocution. Keep `suppress_stun_stars: true` on electric
  stuns so the generic spinning stun-stars do not double up with the field.
  The legacy immediate-draw arcs (`draw_ragnarok_electric_stun_overlay`,
  Lumion `_draw_boss_electric_stun`) are retired/uncalled but kept as fallback
  references.
- When porting a projectile-blast skill (Lumion thunder orb is the reference),
  match the original's CC PHASE and GEOMETRY, not just its radius/duration: the
  Horus thunder orb judges the stun ONLY after the 0.2s explosion animation
  finishes (not at explosion start, not per-frame) and uses pure boss-CENTER
  distance <= radius (NOT a circle-vs-rect overlap — a boss merely clipping the
  blast edge must not be stunned; see the radial-CC geometry rule). Pin both
  with smoke (`lingpet_thunder_orb_skill_smoke.gd`: no-stun-during-explosion +
  edge-only-center-outside).
- A lingpet/RefCounted skill that owns a looping sound or a shared status source
  must clean BOTH up on its `reset()`, not only lower an internal flag. The host
  reset path (`lingpet_skill_runtime_host.reset()` → `skill.reset()`) is
  registry-LESS, so cache the last registry from `update()` and, when `reset()`
  runs mid-effect, call `sync_*_loop(false)` + `clear_status(...)` through it —
  otherwise a round / pet transition leaks the audio loop and the status source.
- For projectile-casting bosses, also verify the projectile-launch event triggers the matching cast / attack animation (not just ball-hit); cast timing and attack timing are checked as separate integration paths
- If an anticipatory attack trigger is used, verify the ball-hit fallback does not double-fire, repeated approaches reset cleanly, and the chosen lead window still preserves the intended front-to-impact read
- If an anticipatory attack trigger is used, verify the lead window is conservative enough that the visible downswing / chop does not complete before contact. "Prep becomes visible" is good; "attack whiffs early in empty air" is a fail
- If an anticipatory attack trigger is used, QA both slow and fast ball approaches with the ball at mid-field, near-field, diagonal miss, and real contact positions. The wind-up may begin before contact only when the ball is already in the relevant strike lane; normal collision fallback must continue the same attack instead of restarting a second swing
- If left / right attack sheets exist for a contact animation, verify side selection with hits just left and just right of paddle center. The real collision contact offset must override walking direction and any earlier anticipation-side guess before rendering the final sheet
- Verify dash trigger timing at actual dash start timing
- Verify walk, attack, dash, and optional turn body size consistency by **perceived body read at gameplay scale**, not just raw frame size -- action sheets should not feel visibly smaller than the walk baseline in-game
- Verify the accepted walk still reads as facing the player during stable left and right travel. If stable movement reads as consistently looking left or right, reject the walk sheet asset-side instead of compensating in runtime logic
- Verify the direct walk `f1..f8` strip has real slot separation before runtime promotion. If the accepted frames still look like the same pose repeated with only tiny paw / foot offsets, treat that as an asset-side walk failure even if a stitched preview or live loop vaguely reads as movement
- Do not promote a walk candidate just because `F1↔F5` mirror discipline landed or because the loop is technically animating. Intermediate slots must still read as distinct rise / shift / rebound / return beats at sheet-review scale
- Verify effects, trails, and motion lines do not visually compress the character's body / face class below the walk baseline
- Verify turn frames appear only on actual facing changes and do not replace stable walking by accident
- When deriving boss facing from per-frame movement deltas, use a stable
  direction threshold / debounce separate from the lower "is moving"
  threshold so tiny position jitter does not make the boss flick between
  left and right or repeatedly restart turn/facing transitions.
- For front-biased bosses, verify turn playback preserves the same frontal combat read as walk and comes across as a brief characterful transition gesture rather than a visible profile-spin or multi-angle showcase
- Verify walk-to-turn-to-walk recovery is brief and readable when turn support is enabled
- If a replacement turn sheet uses a different grid layout than the previous asset (for example `8x1` -> `4x2`), update the loader grid constants and explicit frame-order mapping before swapping files. Do NOT drop a new sheet onto an old slicer and assume row-major intent matches automatically
- If a turn frame looks face-clipped or forehead-cut, inspect the raw cell -> inset crop -> trimmed frame -> gameplay-size render path before applying more runtime scaling. Do not assume a runtime crop bug just because the in-game frame looks chopped
- Verify the runtime-selected key turn frames preserve the same face / forehead read as walk at gameplay size and do not look visually chopped even when the frame technically fits inside the canvas
- If a turn sheet or turn subset looks materially different from walk in body read, palette, outline weight, hair silhouette, or face scale, disable turn playback rather than shipping visibly mismatched facing transitions
- If the previous accepted walk sheet was more front-readable than the new candidate, restore the older walk sheet until a better regeneration passes QA. Do not permanently promote a weaker frontal-read walk just because it is newer
- If the turn sheet is authored with a short usable transition slice instead of the full source sequence, document the accepted usable frames and verify the runtime selection matches that slice exactly
- If a turn sheet is accepted as runtime-only non-anchor, verify that the handoff and repo notes explicitly preserve the walking sheet as the sole regeneration anchor before enabling any runtime migration work
- If a victory sheet exists or was replaced, verify the played sequence reads like a real celebration at gameplay scale (rise / peak / hold or equivalent) rather than like calm walk / turn leftovers
- For round-result victory / defeat poses, verify the scoreboard window uses
  the real `last_scoring_side`, not score comparison alone and not
  `pending_game_reset`. Player scoring should show the player victory pose
  plus boss defeat; boss scoring should show the player defeat pose plus boss
  victory. This must happen on every scored round, including tied-score
  transitions and non-final rounds.
- When changing a player or boss result sheet's frame count or packing grid,
  update the runtime frame count, grid columns, playback cadence, and focused
  smoke-test texture size together. The result animation must fit inside the
  round-score scoreboard window instead of silently truncating.
- If stage-specific event/background/effect code was touched, verify that effect path itself (smoke / fire / background / laser / etc.) rather than assuming the sprite class is the only possible regression source
- If particle count, lifetime, layer count, or translucent blob size increased, run one targeted effect benchmark or live FPS sanity check in addition to the normal sprite-load smoke test
- Run syntax checks and at least one headless sprite-load smoke test
- Perform one real in-game visual check before calling the task done

## Testing Guidelines
- Use `pytest` and `unittest` as already present in the repo
- Add `tests/test_<feature>.py` for new logic when feasible
- For graphics-dependent checks, prefer headless runs with `SDL_VIDEODRIVER=dummy`
- For player / boss sprite replacements, include a focused smoke assertion for
  both the primary texture key and any fallback / legacy key that can render the
  same state. The test should prove texture size, frame count, grid rows /
  columns, and draw-context priority all match the accepted sheet.
- For regenerated icons or other asset replacements that have a runtime fallback, do one live sanity check that the written PNG is what actually appears in-game; a stale cache or early procedural-return is a known regression pattern
- For Godot sprite replacements, after import and headless load, restart any
  already-running editor/play session before visual sign-off when the previous
  run may have cached the old imported texture.
- For new or changed character perk / skill icons, do at least one live check
  in every relevant UI family: perk-choice card, smallest perk grid /
  academy-style offer panel, and orb HUD / tooltip path when applicable.
  Verify no alias route falls back to the wrong branch and the main motif does
  not read materially smaller than neighboring icons.
  In the TAB character-info perk tab, compare small-cell sizing against
  `dash_module_control` / `모듈제어` and verify the bottom level label
  remains readable.
- For unlock-style skill icons, include both the unlock card / offer path
  and the equipped orb HUD path in that check. A PNG appearing correctly
  in the 5-orb slot does not prove the `unlock_*` perk card, academy /
  NPC offer panel, or swap dialog is using the same motif.
- For grid-based perk / skill hover tooltips inside panels or modals, do
  at least one live check on first-row, last-row, left-edge, and
  right-edge entries with a long description. Verify the tooltip flips /
  clamps correctly and does not get cut off by the panel top, panel
  sides, or screen bounds.
- For new or changed character active skills, verify the skill-specific
  gold-reward policy is explicit: either add an intentional reward sized
  consistently with comparable skills or document that the skill is
  intentionally no-gold. If the skill grants gold, confirm the payout is
  wired to the real hit / absorb / consume event and does not double-pay
  alongside generic rally gold or alternate fallback paths.
- For passive / enhancer perks that modify an existing active skill, do
  at least one live check on the affected orb tooltip / active-skill
  tooltip with the perk both uninvested and invested. Verify the target
  tooltip exposes the intended runtime synergy text, uses the real
  effective values, and still behaves sanely when multiple enhancers
  compete for the same limited tooltip bonus-line space.
- For new or changed character perk / skill knockback, do at least one
  live check that launch direction, decay, wall behavior, and any short
  hitstop / release feel still match the intended fire-event baseline
  or the explicitly documented exception. Do not sign off on knockback
  work from tooltip text alone.
- If that tooltip gained runtime synergy / bonus-line text, verify the
  invested-state layout still leaves the control hint / `how_to_use`
  block and any effect-preview panel fully readable. No overlap,
  clipping, or text-hidden-behind-panel regression is acceptable.
- For new or changed duration / timer-type character skills or buffs, do
  at least one live check that the shared right-bottom horizontal timer
  bar appears on the bottom baseline when it is the only active timer,
  uses the real effective duration, stacks sanely upward with other
  active bars, and clears on timeout / cancel / reset / menu return.
- For runtime clones, afterimages, or damaged-state sprite copies built from
  tinted textures, shader materials, or glitched duplicates, do one live check
  in the weakest / faded / critical state and verify transparent margins stay
  invisible. No full rectangular box, tint sheet, or scanline canvas should
  appear around the sprite.
- For new or changed item icons that appear in enlarged acquisition /
  showcase effects, do one live check in that enlarged presentation too.
  Verify the icon does not reveal a faint square padding box or oversized
  transparent margin that was invisible in the small HUD.
- For new or changed downtown / interior / NPC modal flows, do one live check that text actually renders with the shipped repo font path, not just a silent fallback-free code path
- For nested confirmation -> menu flows, do one live check that the opened modal does not capture the previous dialog as a dimmed background ghost
- For menu flows opened by both mouse and keyboard, test confirm / cancel / ESC in both input paths so stale open flags cannot reopen the menu or double-trigger an action
- For settings / options changes, do one live check from every supported entry path (for example `start_menu.py` main-menu settings, pause/options, `option.py`, and any dedicated settings UI that is still reachable). Verify the value persists, reopens with the saved state, and changes the real runtime behavior rather than only the local widget state
- For visit-scoped NPC offers (academy-style), verify same-visit reroll / repurchase / reswap is blocked after success and that re-entry resets only at the intended boundary
- If a helper module spends or grants gold / AP / other visit currency, verify the final value persists back to the manager / shared player state after the modal closes
- For new boss-sprite integrations, do at least:
  - repo-local Godot headless load check
  - GDScript warning scan if `.gd` changed
  - focused Godot resource / scene load for the owning renderer or catalog
  - one visual gameplay sanity check
  - for regenerated walk sheets, one direct `f1..f8` side-by-side strip review before runtime sign-off
  - for front-biased walks, one check that left travel and right travel both still read as forward-facing rather than as persistent side-looking poses
  - if a turn sheet exists, one check that stable movement still uses walk and only facing changes show turn frames
  - if turn QA is disputed, one raw cell / inset / trimmed / gameplay-size comparison before blaming runtime crop or adding more turn-only downscale
  - if turn loader layout changed, one local playback pass with visible turn playback temporarily enabled before restoring the intended shipping default
  - one quick check for stage-entry hitching or obvious FPS regression
  - if stage-specific effects changed, one targeted headless update/draw loop or micro-benchmark for the touched effect path

## Windows Compatibility
- Current Godot work: do not assume case-sensitive paths, keep `res://`
  references stable, and use repo-local Godot tool wrappers from `godot/`.
- Legacy Python/PyInstaller notes below are reference-only for original
  PingFighter packaging investigations: use `os.path.join`,
  `resource_path()`, PyInstaller `--add-data "src;dest"`, and watch for MP3
  decoder issues where `PINGF_BGM_EXT=ogg` may be needed.

## Commit & Pull Request Guidelines
- Commit format: `feat|fix|docs|style|refactor|test|chore: short summary`
- PRs should include:
  - summary
  - change list
  - screenshots for visual changes
  - related issue or context when available

## Manus Agent Session State (2026-05-11) — Historical Snapshot

> **⚠ Historical snapshot, not live status.** This section was written on
> 2026-05-11. File counts, stage status, and character status below are
> frozen at that date and must not be used as the current progress brief.
> For the current refactoring state, see `docs/refactor_status_brief.md`.

This section is maintained by the Manus agent. It records the porting
status as of 2026-05-11 so the provenance of early decisions is auditable.

### Live Godot Project Snapshot

- **Location**: `D:\main\bosspong\godot\` (repo-local, this is the editable live project)
- **Engine**: Godot 4.6, OpenGL Compatibility renderer
- **Main scene**: `scenes/boot_flow.tscn` → character select → `scenes/main.tscn`
- **Viewport**: 2020×1246, canvas_items stretch + expand
- **Autoloads**: `GameSelectionState` (`scripts/core/game_selection_state.gd`),
  `ScreenshotCapture` (`scripts/core/screenshot_capture.gd`)
- **Architecture**: `main.gd` is a one-line shell extending `battle_scene_shell.gd`;
  all battle logic lives in lazy-loaded domain modules under `scripts/`.

### Script File Counts (as of 2026-05-11)

| Folder | .gd files | Domain |
|---|---|---|
| `scripts/core/` | 123 | Match flow, scene orchestration, context builders |
| `scripts/characters/` | 108 | Smasher, Viper, Commando + perks/skills |
| `scripts/items/` | 107 | Active/passive/legendary/mythic item runtimes |
| `scripts/hud/` | 65 | Pillar HUD, gauge orbs, scoreboard, tooltips |
| `scripts/ball/` | 67 | Ball physics, speed policy, VFX, collision |
| `scripts/stages/` | 70 | Stage 1–4 backgrounds, bosses, events |
| `scripts/effects/` | 12 | Particles, screen shake, impact VFX |
| `scripts/audio/` | 3 | Sound loading, loop cleanup |
| `scripts/resources/` | 15 | Texture/resource loader, module registry |
| `scripts/ai/` | 3 | Boss AI |
| `scripts/status/` | 3 | Slow/stun/confusion/reverse/burn states |
| `scripts/ui/` | 6 | UI utilities |
| **Total** | **582** | |

Smoke tests: **299** `.gd` files under `godot/tests/`.

### Stage Porting Status

| Stage | Boss | Status | Notes |
|---|---|---|---|
| Stage 1 | 달지 (Dalji) | ✅ Substantially complete | Playfield renderer, boss actor, 상모돌리기/spinning-top skills, balloon event, pillar HUD, skill-card HUD |
| Stage 2 | 몽키 (Monkey) | ✅ Basic complete | Playfield renderer, boss actor, boss skill HUD, banana event, pillar scene |
| Stage 3 | 멘헤라 (Menhera) | ✅ Basic complete | Playfield renderer, boss actor, skill effect renderer, curse/control-reverse |
| Stage 4 | 퐁크 (Ponk) | ✅ Basic complete | Playfield renderer, boss actor, meditation FX host, magnetic FX, temple destruction event, bird/brazier events |
| Stage 5+ | 홍련/네메시스 etc. | ⬜ Not yet ported | F5 debug picker has slots up to stage 10; stage router falls back gracefully |

### Character Porting Status

| Character | Status | Key systems implemented |
|---|---|---|
| Smasher | ✅ Core complete | Dash, Drive, Power Smash, Ghost Shot, Wheel, Plasma, Warp Gate, Shield Kiting, Magnum Grip, full Combo system |
| Viper | ✅ Basic complete | Skill runtime, Jetpack, EMP, Chaos Spear FX host, Shadow Step, etc. |
| Commando | ✅ Basic complete | Firearm runtime, support aircraft, suicide drone, supply drop, weapon controller |

### Item System Status

Core active items complete: Brick Wall, Stopwatch, Magnet Field, Holy Barrier,
Giant Potion, Vitamin Pill, Strange Vial, Regeneration Potion, and more.
Passive/legendary/mythic item runtimes implemented as separate modules.

### Dev Tools

- `tools/run_headless_load_check.ps1` — headless load verification (run before sign-off)
- `tools/run_smoke_tests.ps1` — runs all 299 smoke tests
- `tools/run_warning_scan.ps1` — GDScript warning scan (run after any `.gd` edit)
- `tools/build_windows.ps1` — Windows export build

### Key Architecture Reminders (Manus)

- Always default new implementation to the Godot port (`godot/`), not Python.
- `pingfighter.py` is behavior reference only — do not modify for new features.
- Module registry pattern: use `gameplay_module_registry.gd` for lazy-loaded modules.
- Korean UI by default; check `localization/ko.json` before writing any visible text.
- After any `.gd` edit: run headless load check + warning scan before sign-off.
- Stage mapping rule: in the current Godot runtime, code `current_stage == 5`
  is user-facing Stage 5 Hongryun / Honglyeon (`stage5_hongryun_*`). Legacy
  Python numbering that refers to Stage 6 Honglyeon or Stage 5 Nemesis is
  reference-only and must not drive Godot routing.
