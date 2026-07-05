# Godot Port Architecture

This document records the long-term structure for the Godot project now
officially titled 디스크하츠 - 링피아. The Python PingFighter version is the
behavior reference, not the
architecture template: do not reproduce the `pingfighter.py` monolith in
Godot.

Current development rule: implement new work in `godot/`. The original
Python/Pygame PingFighter files are frozen behavior references for porting
and parity checks only; do not edit them unless the user explicitly asks
for legacy-source work.

## How To Use This File

- `Core Rules`, `Godot VFX Remaster Policy`, `Current Godot Workspace
  Checklist`, and `Godot Port Change Checklist` are current operating rules.
- `Live Godot Layout` and `Planned / Current Module Map` summarize current
  architecture boundaries.
- Date-stamped status and module-count snapshots live in
  `docs/current_development_boundary.md` and
  `docs/refactor_status_brief.md`. Keep this file linked to those snapshots
  instead of copying their counts here.
- `docs/godot_module_ownership_ledger.md` is the running ownership and
  status ledger. Update it when adding or moving modules, but do not treat
  every historical note there as a new rule.
- `Known Smoke Baselines` records accepted non-fatal smoke output. Changes
  to those baselines are regression signals.

Fast path for most tasks:
1. Read `Core Rules`.
2. Read `Godot Port Change Checklist`.
3. Find the owning folder in `Planned / Current Module Map`.
4. Search `docs/godot_module_ownership_ledger.md` for the exact module or
   nearest existing owner.
5. If no owner exists, create the smallest owner module and add one concise
   ledger entry.

Do not append long bug histories or per-feature playbooks here by default.
Put reusable rules in the relevant checklist (`AGENTS.md`,
`docs/item_runtime_checklist.md`, `docs/character_skill_perk_checklist.md`,
or `docs/godot_port_checklist.md`) and keep this file focused on architecture
ownership.

## Core Rules

- Keep `scenes/main.gd` as a one-line entry script that extends the battle
  shell. Scene-level orchestration belongs in focused `scripts/core/`
  modules, with `battle_scene_shell.gd` kept as the thin compatibility
  bridge.
- Before adding or modifying a Godot feature, identify the owning module.
  If no module exists, create the smallest stable module boundary first.
- Port behavior from `pingfighter.py`, but place systems by domain in
  `scripts/`, not by the order they happened to appear in Python.
- Current live Godot project is this repository's `godot/` folder. Open
  `D:\main\bosspong\godot\project.godot` and edit files under `godot/`
  directly. The previous external live project was archived as
  `C:\Users\woduq\Documents\pingfighter_old_20260503_233412`.
- If a future live Godot project is moved outside the repo again, restore
  the mirror workflow: keep source under `godot/`, sync edited files into
  the external project, compare hashes, and headless-load the external
  project before sign-off.
- Prefer small, explicit dependencies. Module APIs should accept the state
  they need rather than reading unrelated globals from the scene shell.
- Use `resource_path`-style discipline in spirit: Godot assets should load
  through `res://` paths, with file-load fallback when imported resources
  are not available yet.
- Refactor while porting. A feature is not considered done if it can only
  be implemented by adding another large, unrelated block to the scene
  shell.
- New lazy-loaded modules should be registered in
  `scripts/resources/gameplay_module_registry.gd`; do not add one-off
  `*_script`, `_create_*`, and `_get_*_script` boilerplate for every
  module.
- Once a required module is in the repo-local Godot project and passes
  headless loading, remove duplicate runtime fallback copies from the
  scene shell instead of maintaining two implementations of the same
  system.
- Do not keep scene-shell mirror variables for module-private state unless
  draw code or scene orchestration still reads them directly. Prefer
  calling the owning module from the narrow helper that needs the value.
- Treat the Godot playfield as the full `760x750` game coordinate space.
  `pillar_width` / `PILLAR_WIDTH` is a legacy in-game HUD-band value, not a
  wall inset. Do not subtract it from playfield width to derive walls,
  center-background bounds, vignettes, item spawn bounds, or paddle clamps.
  Outer pillar art belongs to the viewport/layout pillar scene pass.
- Treat draw-time coordinates as two explicit spaces. Direct playfield
  `canvas.draw_*()` calls run under `battle_scene_drawer.gd`'s transformed
  760x750 playfield, while detached `Node2D` / `ColorRect` /
  `GPUParticles2D` / shader FX hosts are added outside that draw transform
  and must receive viewport-space coordinates:
  `game_offset + (playfield_pos + shake_offset) * render_scale`, with
  sizes scaled by `render_scale`. If a GPU / node-hosted effect appears at
  the top-left, assume a missing layout transform until proven otherwise.
- When optimizing textured draw helpers, preserve the texture-coordinate
  contract. `draw_texture_rect_region()` takes pixel source rects, but
  textured `draw_polygon()` paths must match the surrounding renderer's UV
  convention, usually normalized `0..1` UVs derived from texture size. A
  shared icon helper change must be checked against every item / actor type
  that uses it, not only the item that motivated the optimization.
- Treat player X bounds as a shared runtime contract, not a movement-only
  detail. If a Godot change writes `player_pos.x`, `player_paddle_width`,
  `player_paddle_height`, or paddle scale, audit every owner-sync path that
  can rewrite those values in the same frame: movement, dash motion,
  active-item sync, runtime-perk sync, mythic/passive equipment sync, match
  flow mergeback, and draw/collision mirror context. Warp Gate deliberately
  allows offscreen wall-riding bounds while active, so a generic
  `0..FIELD_WIDTH - paddle_width` clamp in any of those paths can silently
  undo a previously fixed character-skill behavior. Add or extend a focused
  smoke test such as `godot/tests/warp_gate_port_smoke.gd` when touching
  this contract.
- For character-skill parity, audit the full cross-domain chain before
  sign-off. Smasher skills specifically must check dash-state hooks,
  combo grace / consumption, Drive activation, Power-Smashing activation,
  HUD grace display, and boss-counter cleanup together; single-module
  parity is not enough when the original Python feature depended on
  shared globals.
- For in-game player customization, follow
  `docs/character_customization_direction.md`: character-specific base
  motion sheets stay in place, customization is added through pose-locked
  overlay sheets, and `Skeleton2D` / `Bone2D` / cutout rigging is reserved
  for Live2D-style selection, cutscenes, and portrait animation rather than
  runtime player customization.
- Debug overlays that change live battle state belong to the focused
  overlay picker modules under `scripts/core/`, with input routed through
  `battle_scene_overlay_input_controller.gd`, modal blocking through
  `battle_scene_modal_gate_controller.gd`, and drawing through
  `battle_scene_overlay_frame_controller.gd`. Current examples include
  the F1 character picker, F5 stage picker, and F6 weather picker.
- Treat looped gameplay audio as lifecycle state, not as a fire-and-forget
  cue. Any Godot sound that loops or is driven by a `sync_*` method must
  have a `stop_*` method registered in
  `scripts/audio/gameplay_loop_audio_cleanup.gd`. Score events,
  scoreboard-active frames, serve-wait frames, round restart, ball reset,
  stage debug reset, and full game reset must either stop the loop or pass
  muted audio deps so effect updates cannot immediately re-arm it.
- Treat detached VFX hosts as lifecycle state, not as draw-only output.
  Once a `Node2D` / `Sprite2D` / `ColorRect` / `GPUParticles2D` / shader
  host has been attached to the scene tree, it can remain visible even if
  the owning logical state is cleared. Any owner whose draw fanout is gated
  by `has_visible_effects()` must hide or tear down its host from
  `reset_round()`, score / serve-wait cancellation, stage transition, full
  reset, and explicit skill / item cancel paths. Do not rely on a final
  inactive `draw()` call unless the caller is proven to run after logical
  visibility becomes false.
- Treat stage events and boss skills as having two parallel state surfaces
  during port: the phase / timer scalars AND the runtime spawn arrays that
  the Python reference mutates inside each phase. A Godot event_state
  carrying only `*_progress` / `*_phase` / `*_timer` is a parity gap, not a
  finished port — populated lists like `collapse_debris`, `roof_fragments`,
  `dust_clouds`, `falling_lanterns`, `ground_fires`, `fireballs`,
  `friend_moles_list`, summoned-minion arrays, and per-frame physics
  particle pools carry the visible payload that the renderer needs every
  frame. If the renderer falls back to a hardcoded "hint" pass — small
  fixed-count debris near a single screen point — the dynamic payload was
  silently dropped. Stage 4 temple destruction
  (`stage4_temple_destruction_event.gd` +
  `stage4_playfield_renderer.gd` formerly `_draw_debris_hint()`) is the
  reference reproduction: phase machine and 5-stage progression were
  ported, but the phase 4 payload (collapse_debris 100+, roof_fragments
  50+, dust_clouds 15, falling_lanterns 6, ground_fires N, plus 25-frame
  re-spawn) was missing, and the renderer drew a 10-piece hint inside a
  fixed ±140px box. Audit pattern: list every list / dict the Python
  event mutates per phase, and confirm each has a Godot owner with
  spawn, per-frame update (vx/vy/gravity/rotation/opacity or equivalent),
  spread coordinates that match the Python range, and round / stage /
  game-reset cleanup. Eliminate hint fallbacks once the real payload
  ships — keeping a fixed-position hint behind dynamic spawn produces
  visible coordinate drift between the two systems.
- For stage renderers, ambient and decorative draw passes (lanterns,
  training dummies, incense, censer, props, banners, statues) must gate on
  the relevant `*_destroyed` / `*_collapse_progress` / `*_exploding` state
  when the Python reference removes or transforms them during a
  destruction or transformation event. An unconditional `_draw_ambient_*`
  call is a parity gap whenever the Python reference short-circuits the
  same draw under destruction. Verify by reading the Python `if not
  self.temple_destroyed and not temple_exploding:` guard family and
  mirroring each one in the Godot renderer.

## Godot VFX Remaster Policy

Use this policy whenever a Godot port touches a visible gameplay effect:
character skills, boss skills, active-item use / deploy / impact effects,
passive-item auras / proc effects, legendary / mythic item themes, stage
events, ball effects, contact impacts, shields, fields, projectiles, cast
loops, and persistent auras.

The Python / Pygame implementation is the timing and gameplay reference.
Do not treat its procedural `draw_*` calls as the final Godot rendering
architecture unless the effect is intentionally tiny. A ported effect is
considered visually complete only when it keeps the original gameplay
timing and rebuilds the presentation with Godot-native VFX layers.

The preferred production pattern is **modular VFX layering**: texture
pieces or sprite-sheet fragments provide the readable art, runtime node
composition places those pieces in phase-specific z-order, and shader
uniform tuning makes one texture feel alive across several skills or
modes. In handoffs and code reviews, also call this pattern
**texture pieces + runtime composition** or **texture fragments + shader
uniform presets**. Treat one-off procedural drawing as the fallback, not
the visual design center, once this pattern can cover the effect.

### 3-Piece Quick Recipe (canonical starting template)

When a skill / boss / item effect has no special reason to differ, default to a
**3-piece modular set** plus engine-driven motion. The detailed layer contract
below can grow past three layers, but three is the canonical baseline that keeps
every effect on the same quality bar:

| Piece | Role | Character | Runtime host |
|---|---|---|---|
| Backplate | mood / depth / presence | large, slow | `TextureRect` / `Sprite2D` |
| Particle texture | dynamic detail / life | small, many | `GPUParticles2D` |
| Arc / trail segment | rhythm / accent | mid, repeating | `Sprite2D` |

- These three are **static PNGs**; all motion comes from shader + particles +
  tween, never from baked frames. Because they are still textures (not animated
  sheets), they may be produced with Gemini / built-in imagegen -- the
  AutoSprite sprite-sheet requirement does not apply to a single still piece.
  Animated 16-frame skill-effect sheets still follow the AutoSprite rule.
- **Blend-mode intent split:** additive (`blend_add`) for light / glow / energy
  (backplate glow, ember pulses); mix for solid matter (lotus leaf, talisman,
  cracks body). Mixing both reads with depth; all-additive washes out white.
- Margin / nukki: alpha margin + radial mask so corners never keep a square box
  under rotation / scale, and keep the alpha bbox off the canvas edge.

**Reference shader -- "writhing-ember"** (works on any bright + alpha texture,
reused by uniform tuning only). Five stacked techniques: (1) noise UV
displacement (organic writhing), (2) hot<->ember noise flicker, (3)
center->outward energy flow pulse, (4) chromatic aberration (heat haze), (5)
breath alpha. Reuse across skills by swapping color / speed uniforms only:

| Uniform | Normal | Enraged | Effect |
|---|---|---|---|
| `distort_strength` | 0.014 | 0.022 | writhe amplitude |
| `flow_speed` | 1.0 | 1.5 | energy flow rate |
| `pulse_speed` | 1.6 | 2.4 | color flicker rate |
| `breath_amp` | 0.18 | 0.28 | whole-field breath |
| `intensity` | 1.0 | 1.3 | overall brightness |

Same shader, retuned per effect: meditation mandala (`flow_speed=0.4`,
`pulse_speed=0.6`, gold-amethyst), magnetic lattice (`flow_speed=1.5`,
`pulse_speed=2.0`, cyan-violet), one-shot collapse burst (`flow_speed=2.5`,
`breath_amp=0.0`). The reference implementations are the meditation / magnetic
field / chaos-spear cracks effects.

Default layer contract:

- [ ] Preserve original phase timing first: windup, active / release,
      hit-confirm, hitstop, linger, fade, cleanup, cooldown start, audio
      cue timing, and any gameplay state mutation.
- [ ] Break final VFX into reusable runtime layers instead of baking every
      phase into one flat asset: backplate / glyph / field mask, core
      projectile or actor-attached piece, trail, impact burst, residue /
      cracks / scorch, particles, and optional shader quad.
- [ ] Use texture pieces or sprite sheets for the readable silhouette:
      projectile body, aura core, slash shape, shield rim, impact mark,
      field mask, debris, or other identity-defining art.
- [ ] Use `ShaderMaterial` for living motion: glow, dissolve, refraction,
      noise flow, UV drift, rim pulse, color ramp, distortion, or scan
      effects. Shader parameters should be driven from the same phase
      clock that owns gameplay timing.
- [ ] Prefer reusable shader families with per-effect uniforms over
      near-duplicate shader code. Common uniform lanes should include
      `elapsed`, `alpha` / `intensity`, UV flow speed, pulse speed,
      distortion strength, `lateral_strength` / tangent-side displacement,
      jitter strength, chromatic strength, breath amplitude, color ramp /
      tint colors, and enraged / boosted multipliers where useful.
- [ ] Use `GPUParticles2D` for density and variation: sparks, motes,
      embers, smoke, debris, trails, burst dust, absorption streams, or
      ambient field flecks. Prefer node particles over per-frame manual
      particle-array drawing for final VFX unless a low-count deterministic
      shape is required.
- [ ] Use `Tween` for one-shot scale / alpha / pulse / snap timing, and
      `AnimationPlayer` when the effect has repeatable multi-property
      choreography, multiple child nodes, or hand-authored phase keys.
- [ ] Add sound, hitstop, camera shake, flash, and HUD timer hooks where
      the Python reference used them or the effect needs them to read as
      the same gameplay event.
- [ ] Keep `canvas.draw_*()` only for cheap fallback shapes, debug overlays,
      deterministic geometry helpers, or transitional scaffolding. If a
      port ships with direct-draw as the final effect, document why the
      remaster stack is intentionally unnecessary.

Implementation checklist:

- [ ] Identify the owning runtime module and, for layered node effects,
      create a focused FX host under that owner instead of adding a large
      draw block to `battle_scene_shell.gd` or `main.gd`.
- [ ] Load textures through `res://` paths and shared resource helpers.
      Keep generated VFX PNGs versioned under the Godot asset tree and
      retain source / alpha-prep siblings when useful.
- [ ] Slice sprite sheets and cache scaled textures during initialization,
      resource load, resize, or host setup. Do not slice or smoothscale
      large VFX images every frame.
- [ ] Route detached `Node2D`, `ColorRect`, `Sprite2D`, shader quads, and
      `GPUParticles2D` through explicit viewport-space layout:
      `game_offset + (playfield_pos + shake_offset) * render_scale`, with
      sizes multiplied by `render_scale`.
- [ ] Define the layer manifest near the FX host: texture path, blend mode,
      z-order, owning phase(s), fallback behavior, and the shader uniform
      preset used by normal / boosted modes. Keep this close enough to the
      loader that future agents can add a sibling effect without reverse
      engineering the composition.
- [ ] Drive shader uniforms from phase state, not hidden local clocks,
      except for `elapsed` style visual motion. Phase transitions should
      control intensity, alpha, scale, emission, and flow/pulse speed
      through a single state clock or explicit tweens.
- [ ] When a static texture can be animated by shader alone, prefer that
      over generating extra near-identical frames: UV displacement,
      tangent / perpendicular lateral displacement (`lateral_strength`) for
      writhing cracks, lightning, vines, roots, ropes, streams, and curved
      energy branches, noise-driven flicker, outward/inward flow bands,
      chromatic heat haze, breath alpha, dissolve, rim pulse, and
      color-ramp swaps are reusable across boss fields, character skills,
      item fields, impacts, shields, cracks, trails, and auras.
- [ ] Give every persistent or pooled FX host a reset / round-end /
      stage-transition cleanup path. Timed effects must stop particles,
      kill tweens, hide shader quads, and clear stale state on cancel.
- [ ] If the owning renderer is called only while `has_visible_effects()` is
      true, add cleanup outside the draw path too. Round-end, score-event,
      serve-wait, ball reset, stage transition, full reset, character /
      item swap, and explicit cancel paths must call `set_active(false)`,
      `tear_down()`, or the owner's hide helper for any host that may have
      been attached before logical state cleared.
- [ ] Keep a small fallback path that preserves gameplay readability when
      a texture or shader fails to load, but make the remastered path the
      first attempted runtime path.
- [ ] Add or update focused smoke checks for resource loading and lifecycle
      state when feasible. For geometry-sensitive VFX, add a small
      invariant test for the intended curve, alignment, or bounds.

Before sign-off:

- [ ] Confirm the visible effect uses the remaster stack or has a documented
      exception: texture / sprite identity, shader motion, particles, and
      tween or animation timing.
- [ ] Name the modular VFX layers that shipped and the shader uniform
      preset(s) they use. If the effect introduced a broadly reusable
      shader trick, document where future VFX should reuse it instead of
      cloning a one-off variant.
- [ ] Verify the live effect in a scaled/windowed layout, not only headless
      load. Node-hosted VFX must not appear at top-left or drift away from
      the playfield transform.
- [ ] Verify audio, hitstop, camera shake / flash, HUD timers, and cleanup
      against the original timing.
- [ ] Verify alpha bounds / transparent corners for generated textures and
      confirm particles / halos do not clip against sprite-sheet cell edges.
- [ ] For generated PNG VFX pieces, verify the transparent-looking
      checkerboard is not baked into RGB pixels with nonzero alpha. Scan
      alpha-bearing pixels for low-saturation mid-gray checkerboard residue,
      not only transparent corners; additive / tinted materials can make
      faint baked checker pixels highly visible once the layer z-order is
      fixed.
- [ ] Run the repo-local Godot headless load check with
      `.\tools\run_headless_load_check.ps1` after any Godot code or asset
      import changes.

## Current Godot Workspace Checklist

Use this checklist before and after every Godot-port task after the
2026-05-03 workspace switch.

Target selection:

- [ ] Open the live Godot project from
  `D:\main\bosspong\godot\project.godot`.
- [ ] Treat repo-relative `godot/` as the editable live project.
- [ ] Confirm every edited Godot path starts with
  `D:\main\bosspong\godot\` or repo-relative `godot/`.
- [ ] Do not edit or sync to `C:\Users\woduq\Documents\pingfighter`; that
  path should remain absent unless the user explicitly creates it again.
- [ ] Use `C:\Users\woduq\Documents\pingfighter_old_20260503_233412` only
  as an archived backup/reference, not as a live target.
- [ ] For requests that say Godot, porting, or GDScript, do not edit
  `pingfighter.py` except as a behavior reference unless the user
  explicitly asks for Python/Pygame source changes.

Verification:

- [ ] Run a repo-local Godot load check after Godot edits:
  `.\tools\run_headless_load_check.ps1`
  from `godot/`. Use the wrapper instead of a bare Godot CLI command so
  parallel editor / headless sessions cannot collide on the default Godot log
  file.
- [ ] Run the repo-local GDScript warning hygiene scan after any `.gd`
  edit:
  `.\tools\run_warning_scan.ps1`
  from `godot/`. This is separate from the basic load check because
  editor/debugger warning counts can stay hidden unless Godot reloads
  scripts under `--debug`.
- [ ] For focused Godot smoke tests, prefer
  `.\tools\run_smoke_tests.ps1 -Tests @('res://tests/<name>_smoke.gd')`
  from `godot/`. The wrapper fails on Godot error log lines as well as
  nonzero exit codes, because the headless CLI can emit `SCRIPT ERROR` /
  `ERROR:` while still returning exit code 0.
- [ ] For `@tool` UI scripts, audit editor lifecycle safety before
  sign-off. `_process()`, `_draw()`, input handlers, prewarmers, and
  helper calls that touch viewport, window, mouse position, theme, or
  child nodes must tolerate editor reload timing with `is_inside_tree()`
  and null guards such as `get_viewport() != null` / `get_window() != null`.
- [ ] If the Godot executable path changes, find the current
  `Godot*_console.exe` and record the new path in the handoff.
- [ ] If an external live project is introduced again, sync edited
  `godot/` files to that project, compare hashes, and run the external
  headless load check before sign-off.

## Godot Port Change Checklist

Use this checklist for every Godot gameplay, UI, stage, item, character,
resource, or runtime refactor change. It is intentionally short so it can
be followed during normal porting work instead of becoming a second
architecture document.

Before editing:

- [ ] Identify the owning domain under `scripts/` (`core`, `ball`,
  `items`, `characters`, `hud`, `stages`, `ai`, `audio`, `resources`, or
  `effects`).
- [ ] If no owner exists, create the smallest stable module boundary first
  instead of adding a new behavior block to `scenes/main.gd` or
  `battle_scene_shell.gd`.
- [ ] Treat `pingfighter.py` as the behavior reference only; do not copy
  its monolithic control flow into the Godot port.
- [ ] If the change ports or modifies visible gameplay VFX, apply the
  Godot VFX Remaster Policy above. Preserve Python timing, but default the
  final presentation to texture / shader / `GPUParticles2D` / `Tween` or
  `AnimationPlayer` instead of a direct procedural draw copy.
- [ ] Check whether the change crosses domains. Character skills, active
  items, score/serve flow, boss reactions, HUD timers, and stage events
  often need a full chain audit rather than a single-module patch.
- [ ] For refactor-only work, choose exactly one lifecycle-sized slice
  before editing. If the candidate split would be paper-thin or mostly
  indirection, stop and record why it is over-splitting instead of moving
  code.
- [ ] For any visible player-facing or debug UI text added during the
  port, use Korean by default. Keep English only for code identifiers,
  file/resource paths, engine/API names, or intentionally branded names.
- [ ] Before writing new UI copy, check the Python reference and
  `localization/ko.json` for existing Korean wording. If no source text
  exists, write concise Korean copy that matches the in-game wording style.
- [ ] For items, skills, boss actions, stage events, rewards, and UI
  feedback, identify the expected Python-side sound cues before coding.
  Audio parity is part of gameplay parity, not a polish-only follow-up.
- [ ] If any cue loops or is controlled by `sync_*`, identify every owner
      that can keep updating after a score: active-item update, character
      effect update, stage background update, mythic / passive runtime, and
      scoreboard / serve-wait flow. Plan the stop path before wiring play.
- [ ] When adding or porting a stage boss, inventory every existing boss
  skill from the Python reference and plan the Godot HUD as Stage 1
  Dalji-style skill-card cooldown cards. Do not keep or add right-side
  boss skill gauge bars unless the design explicitly asks for a unique HUD
  exception.
- [ ] For stage events, boss skills, and any phase-driven gameplay system,
  list every runtime list / dict the Python reference mutates per phase
  (debris, fragments, dust, falling objects, fires, summoned minions,
  projectiles, persistent VFX particles) before claiming the Godot port
  owns the same event. A scalar `*_progress` / `*_phase` / `*_timer` in
  the Godot event_state is not proof of port completeness — populated
  lists carry the visible payload, per-frame physics, and screen-wide
  spread that the renderer cannot reconstruct without them. Also audit
  ambient / decorative draw passes for matching `*_destroyed` /
  `*_exploding` gates, not just the spawn payload itself.

During implementation:

- [ ] Keep `scenes/main.gd` as the one-line shell and keep
  `battle_scene_shell.gd` limited to top-level scene orchestration,
  compatibility API forwarding, and draw/update/input delegation.
- [ ] For lifecycle refactors, preserve the public API at the old owner
  with forwarding wrappers or equivalent facades, and keep behavior,
  ordering, state names, and resource paths unchanged.
- [ ] For payload-factory extraction, compare the new factory against the
  previous inline dictionary at literal granularity: constants, random
  ranges, color alpha, key names, lifetime fields, and RNG call order. Do
  not replace one similar-looking constant with another; give factory
  parameters semantic names such as `initial_sweep_half_angle` versus
  `slow_drift_half_angle`, and make the smoke assert the original
  reference range rather than the newly extracted code.
- [ ] Smoke tests must not call `quit(1)` inside `_expect()` and then fall
  through to a later `quit(0)`. Use the repo-standard `_failures` array,
  print the ok marker only when it is empty, and emit `quit(1)` from the
  final failure branch so both `run_smoke_tests.ps1` and direct
  `godot --headless -s` exit-code workflows catch failures.
- [ ] Register new lazy-loaded modules in the relevant
  `scripts/resources/gameplay_*_module_catalog.gd` catalog so they are
  reachable through `gameplay_module_registry.gd`.
- [ ] Prefer explicit context dictionaries, snapshots, or narrow method
  parameters over reading unrelated owner fields from modules.
- [ ] Load Godot resources through `res://` paths and shared resource
  helpers such as `project_resource_loader.gd`; avoid duplicating ad-hoc
  `FileAccess` / `ResourceLoader` fallback branches.
- [ ] If the change edits render helpers, `draw_set_transform`,
      textured `draw_polygon()`, `draw_texture_rect_region()`, or a
      `Node2D` / `GPUParticles2D` / shader FX host, write down which
      coordinate space the helper consumes: playfield-local, viewport, or
      texture UV. Convert at the boundary instead of mixing spaces inside
      the draw loop.
- [ ] For remastered VFX hosts, drive shader parameters, particle emission,
      sprite frames, tweens / animations, and fallback draw visibility from
      one authoritative phase clock so original timing does not fork across
      multiple local timers.
- [ ] Route new or ported sound cues through `scripts/audio/game_audio.gd`
  or a focused audio owner module. Check pickup / acquire, use / cast,
  windup, release, impact, status start, loop, expire, cancel, failure, and
  cooldown feedback as applicable.
- [ ] For any new or modified looped gameplay sound, add its stop method to
      `scripts/audio/gameplay_loop_audio_cleanup.gd`. Do not rely only on
      the normal update loop to stop it, because active-item updates pause
      during scoreboards while some effect / background updates can still
      run.
- [ ] If the loop is synced from an effect or stage background that still
      updates during scoreboard display, gate the sync with the shared
      round-boundary audio policy or pass muted audio deps so a just-stopped
      loop cannot restart before the next serve.
- [ ] For boss skill-card cooldown HUDs, expose skill dictionaries with
  Korean labels, trigger type, ready state, remaining / total cooldown, and
  progress. Use themed PNG card art for each boss skill, generate missing
  card art through imagegen, load / cache / prewarm the textures, and keep
  procedural/text-only cards as a missing-asset fallback only.
- [ ] Treat Stage 1 Dalji's runtime skill-card metrics as the official
  Godot boss skill-card size contract. All stage boss skill-card HUD
  renderers should use `scripts/stages/common/boss_skill_card_hud_spec.gd`:
  base pillar width `80`, card base size `33.6x9.0`, minimum card rect
  `24x10`, gap `2`, right margin `3`, and left-pillar Y margin `5`. Source
  PNGs may have different pixel dimensions, but the final rendered `Rect2`
  should resolve through this shared Dalji-size spec unless a documented
  unique HUD exception is requested.
- [ ] Localize every visible UI surface touched by the port: menu titles,
  tab labels, button/action hints, empty-state text, status strings,
  tooltips, roll-option labels, debug panels, and acquisition/equip
  feedback. Do not leave temporary English text in Godot just because the
  implementation was copied from a scaffold.
- [ ] If a large existing module must be extended, keep the change local
  and record the next split candidate in the module ownership ledger when it
  reveals a stable ownership boundary.

Before sign-off:

- [ ] Update the module ownership ledger when adding a module, moving ownership,
  deleting duplicate fallback code, or changing a domain boundary.
- [ ] Run the focused Godot load / smoke check available for the touched
  area. Use `.\tools\run_headless_load_check.ps1` for the baseline load
  check. If the local Godot executable is unavailable, say so in the handoff.
- [ ] Run `.\tools\run_warning_scan.ps1` from `godot/` after `.gd`
  changes and treat new GDScript warnings as failures. Prefer real fixes:
  rename `material` / `call` / `scale` / `name` / `seed` / `ease` style
  shadowed identifiers, cast deliberate numeric conversions, and prefix
  intentionally unused compatibility parameters with `_`. Use
  `@warning_ignore` only for a narrow, intentional statement and never as a
  blanket file-level cleanup.
- [ ] If a touched script is `@tool`, run a focused scene or script load
  that exercises editor-time lifecycle enough to catch missing viewport /
  window / tree guards. A normal runtime smoke test is not enough for
  `@tool` `_process()` / `_draw()` paths.
- [ ] For refactor-only work, stop after the focused tests / load check
  pass and summarize the single lifecycle slice moved. Do not bundle the
  next split into the same change.
- [ ] Verify audible feedback for every newly ported gameplay trigger that
  had a Python sound or clearly needs one in Godot. If a trigger is
  intentionally silent, document that decision in the handoff.
- [ ] For any looped Godot gameplay audio touched by the change, force a
      score / scoreboard while the loop is active, then verify the loop is
      silent through scoreboard, serve wait, round restart, and game reset.
      Add or update a focused smoke test such as the round-boundary audio
      smoke when the lifecycle is code-owned.
- [ ] For any detached VFX host touched by the change, force a score /
      scoreboard or serve-wait transition immediately after activation and
      verify the host is hidden even when the logical state already reports
      no visible effects. Add or update a focused smoke test for this when
      the host lifecycle is code-owned.
- [ ] Do a visible-text pass on the touched Godot UI/debug path and confirm
  newly added strings are Korean. Mention any intentional English strings
  in the handoff.
- [ ] For visual-renderer or VFX-host changes, do at least one live visual
      check or screenshot review in a non-trivial layout (windowed scaled
      view, fullscreen, or any view where `game_offset` / `render_scale` is
      not the implicit identity). `--check-only` and headless load only
      prove syntax/resource load; they do not prove UVs, transforms, or
      GPU-node positions.
- [ ] For newly ported or retuned stage-boss skills, verify the skill-card
      cooldown timing and auto / manual trigger behavior with a focused
      smoke test or equivalent runtime probe, including ready-state display
      and round-reset behavior.
- [ ] For visible gameplay VFX ports, list which layers shipped
      (texture / sprite sheet, shader, `GPUParticles2D`, `Tween` or
      `AnimationPlayer`) and document any intentional direct-draw-only
      exception as remaining visual or scope risk.
- [ ] For active-item changes, run the Godot active-item parity checklist
  in `docs/item_runtime_checklist.md` Section 1.7: catalog -> router ->
  controller state mutation -> update/reset -> getter -> runtime draw
  fanout -> renderer call -> audio. Do not sign off an item whose slot
  consumes before the intended world object / projectile / field is
  visible or intentionally pending.
- [ ] For contact-based player / boss attack animations with pre-contact
  wind-up, verify the trigger is gated by strike-lane proximity as well
  as time-to-contact. Test slow, fast, diagonal miss, mid-field, near-field,
  and real-contact approaches; the fallback hit trigger must continue the
  same swing instead of restarting a second attack.
- [ ] For directional left / right contact-attack sheets, select the sheet
  from the real ball contact X relative to paddle / boss center: left of
  center -> left sheet, right of center -> right sheet. Do not let walk
  direction, actor velocity, last facing, or anticipation prediction
  override the actual collision-side result.
- [ ] For round-result victory / defeat poses, drive player and boss result
  flags from the active scoreboard window's real `last_scoring_side`.
  Player scoring should show player victory plus boss defeat; boss scoring
  should show player defeat plus boss victory. This must work on every
  scored round, including tied-score transitions and non-final rounds; do
  not gate normal round-result poses on `pending_game_reset`.
- [ ] If a result pose sheet changes frame count or packing grid, update the
  context frame count, grid columns, playback cadence, and focused smoke-test
  texture size together so the animation fits the scoreboard window.
- [ ] If a player / boss sprite state is replaced, trace every runtime key for
  that state before sign-off: primary sheet key, fallback texture key, legacy
  alias, resource prewarm/cache entry, update-context availability flag,
  draw-context frame/grid metadata, renderer direct-read branch, and smoke-test
  expected size. The old asset must not remain reachable through a fallback
  unless that fallback is intentional and documented.
- [ ] Run the repo-local Godot headless load check from the workspace
  checklist (`.\tools\run_headless_load_check.ps1`). If the live Godot
  project is moved outside this repo again, sync the mirror files, run the
  live headless load check, and compare hashes for edited files.
- [ ] Document any remaining visual-only or parity risk in the handoff
  instead of treating an unverified port slice as complete.

## Live Godot Layout

- `godot/project.godot`
  The current live Godot project settings. The main scene is stored as
  `res://scenes/boot_flow.tscn`, not as a UID, so a clean checkout can load
  before Godot has rebuilt its local UID cache.
- `godot/scenes/boot_flow.tscn`
  The app-root flow scene. It owns the top-level boot sequence from
  the penguin logo into character select, then hands the chosen character and
  starting stage to the battle scene.
- `godot/scenes/main.gd`
  The main scene script. It is intentionally a one-line shell that extends
  `res://scripts/core/battle_scene_shell.gd`.
- `godot/scenes/main.tscn`
  The main scene resource and points at `scenes/main.gd`.
- `godot/scenes/character_select.tscn`
  The character-select UI scene used by the app-root boot flow. Running
  this scene directly still stores the picked character in
  `GameSelectionState` and hands off to `main.tscn`.
- `godot/scripts/`
  The live gameplay source modules.
- `godot/assets/`
  The live Godot asset files needed by the current port. Source PNG / WAV /
  MP3 files are committed with their `.import` metadata, but
  `.godot/imported` cache files are not part of source control.
- Clean-clone loaders should tolerate missing `.godot/imported` cache
  outputs. For source PNG / WAV / MP3 / OGG assets, load the raw file
  first through the focused resource helper, then fall back to Godot's imported
  `ResourceLoader` path when the raw file is not available.
- `scripts/resources/project_resource_loader.gd` owns that raw-first
  PNG / WAV / MP3 / OGG loading policy. Feature modules should call it
  instead of duplicating `FileAccess` / `ResourceLoader` fallback branches
  locally.

## Planned / Current Module Map

This map names the stable owner folders. For current script counts, stage
status, character status, and Ringpet / Lingpet split status, use
`docs/refactor_status_brief.md`; for the Godot-vs-legacy implementation
boundary, use `docs/current_development_boundary.md`.

- `scripts/core/`
  Match-level rules, score state, round flow, scene orchestration helpers,
  and shared gameplay configuration that does not belong to one actor.
- `scripts/stages/`
  Stage backgrounds, stage-specific ambience, stage hazards, and
  event-reactive pillar effects.
- `scripts/ball/`
  Ball kinematics, rally speed scaling, hit acceleration, curve/spin,
  serve setup, intensity state, and ball VFX helpers.
- `scripts/hud/`
  Bottom pillar HUD, gauge orb, dash token orb, skill orb cluster,
  active-item slots, scoreboards, and tooltip/surface helpers.
- `scripts/characters/`
  Player character state, equipped skills, combo systems, cooldowns,
  gauge costs, actor animation state, and character-specific VFX.
- `scripts/ai/`
  Opponent movement, prediction, mistake windows, difficulty profiles, and
  boss-specific decision state.
- `scripts/items/`
  Active/passive item state, cooldowns, acquisition routing, and item
  runtime effects.
- `scripts/plaza/`
  Plaza shell runtime: accepted plaza asset manifests, staged prewarm,
  side-scroll street rendering, S4.5 parallax layer assets, S1 sidewalk ground
  reuse, player X-walk/X-camera state, per-instance CPU emissive flicker,
  building menu shells, `plaza_save_store.gd` persistent gold/AP/bank/shop
  wallet ledger, first-pass bank menu transactions, first-pass active-item shop
  transactions, first-pass active-slot blacksmith enhancement attempts,
  first-pass active-item capsule gacha pulls, first-pass Lingpet Store
  resonance-egg purchases via `lingpet_egg_runtime` (plaza pays and opens the
  egg; the lingpet runtime owns hatch/ownership/slot state), and EXIT callback
  handoff from the result screen.
- `scripts/audio/`
  Sound loading, pitch/volume policies, cooldown gates, and event sound
  routing.
- `scripts/resources/`
  Texture/resource path ownership, resource loading fallbacks, shared
  caches, and missing-resource diagnostics.
- `scripts/effects/`
  Generic particles, screen shake requests, wall impacts, and reusable
  draw/update effect components.

## Module Ownership Ledger

The cumulative module ownership log was moved to
`docs/godot_module_ownership_ledger.md` to keep this architecture guide
focused on current rules and module boundaries.

When adding a module, moving ownership, deleting duplicate fallback code, or
changing a domain boundary, update that ledger with one concise entry. Do not
append long bug histories or per-feature playbooks here.

## Known Smoke Baselines

Non-fatal warnings that the smoke runner does NOT count as failures, but
that should be recognized so future refactors do not chase them as
regressions. The smoke runner's failure pattern at
`godot/tools/run_smoke_tests.ps1` matches `SCRIPT ERROR | ERROR: | FATAL: |
Parse Error | Compile Error | Failed to load script | Invalid call`, which
intentionally excludes these.

### `character_selection_viper_start_smoke.gd` ObjectDB leak (4 RefCounted)

- Symptom: at engine exit, `WARNING: ObjectDB instances leaked at exit`,
  with `--verbose` revealing 4 leaked `RefCounted` instances all at
  `Reference count: 0`.
- Composition: scene `_ready()` baseline 1 leak, +1 per confirm intro
  (smasher / commando / viper) → total 4.
- Root cause: not a clear application-level cleanup miss. Survived every
  explicit teardown attempt in the smoke (ShaderMaterial / Shader nulling
  on the confirm-intro exit-flash overlay, BGM `AudioStreamPlayer` `stop`
  + `stream = null` + `free()`, `LivePreview` `one_shot_finished` signal
  disconnect, `ProjectResourceLoader.clear_caches()`, multiple
  `await process_frame` yields). Synchronous `screen.free()` does
  eliminate the leak but causes an access-violation crash inside Godot's
  shutdown cleanup, so it is not a viable workaround. Pattern smells like
  a Godot 4.6 headless shutdown ordering issue between the Control tree,
  shader-resource RIDs, and `ResourceCache` / static-Dictionary
  RefCounted caches.
- Status: tracked as known baseline. Not a blocker for character-select,
  stage-2 split, or other ongoing refactors.
- Re-investigate when: working on character selection, confirm intro,
  texture cache lifetime, or shader-material cleanup. If the count drifts
  away from 4 (more or fewer) during unrelated work, treat the change as
  a regression signal and bisect from there.

### Cleared: passive-item PNG export warnings

- Former symptom: `WARNING: Loaded resource as image file, this will not work on
  export: 'res://...'. Instead, import the image file as an Image
  resource and load it normally as a resource.` (origin
  `core/io/image.cpp:2756`).
- Affected paths in the current full sweep (4 total occurrences, 1 each):
  - `res://assets/sprites/items/gravitybelt.png` — emitted by
    `tests/gravitybelt_port_smoke.gd`
  - `res://assets/sprites/items/revival.png` — emitted by
    `tests/revival_port_smoke.gd`
  - `res://assets/sprites/items/sensor.png` — emitted by
    `tests/danger_sensor_belt_port_smoke.gd`
  - `res://assets/sprites/items/speedgear.png` — emitted by
    `tests/speedgear_port_smoke.gd`
- Former root cause: each affected smoke (or the runtime path it exercises)
  resolves the PNG with a generic `load()` that falls through to
  `Image.load()` because the PNG lacks a `.import` artifact. The legacy
  in-engine image loader works in editor and headless smoke runs but is
  blocked in exported builds.
- Status on 2026-05-24: cleared. `tests/gravitybelt_port_smoke.gd`,
  `tests/revival_port_smoke.gd`, `tests/danger_sensor_belt_port_smoke.gd`,
  and `tests/speedgear_port_smoke.gd` now load those icon paths through
  `ProjectResourceLoader.load_texture(...)`; the four-smoke sweep passed
  without the export warning.
- Regression rule: if this warning shape reappears for item PNGs, route the
  new path through `ProjectResourceLoader.load_texture()` instead of generic
  `load(res://*.png)`.

## Verification Rule

For each Godot refactor:

1. Confirm the target is the repo-local live project at `godot/`.
2. Run the Godot headless load check from the workspace checklist.
3. If an external live project is introduced again, sync from `godot/`,
   compare edited-file hashes, and headless-load that external project.
4. Record any unverified visual-only risk in the handoff.
