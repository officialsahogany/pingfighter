# Godot Port Architecture

This document records the long-term structure for the Godot project now
officially titled 환격전. The English product title remains undecided. The Python PingFighter version is the
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
Put reusable detail in the relevant focused checklist or stable GRT entry and
keep this file focused on architecture ownership. Root files keep only concise
routing and non-negotiable safety contracts.

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

### Smasher Void Phantom modular VFX boundary

`smasher_void_phantom_renderer.gd` owns the playfield-local MIX backplate,
the single-pass `WritheEmberMaterial` ADD arc/trail draw, canvas-material
save/restore, the procedural forming-orb/release accents, and production
attachment of the detached host. Its two shared-shader presets are
`smasher_void_phantom_writhe` and
`smasher_void_phantom_writhe_enraged`; do not clone the shader code.

`smasher_void_phantom_fx_host.gd` owns the generated particle piece,
`GPUParticles2D` emission/scale/fade curves, charge/release Tween envelopes,
playfield clipping, the exact
`game_offset + (playfield_pos + shake_offset) * render_scale` projection, and
the finite sync watchdog. It stays process-disabled and must hide plus stop
emission when the owner stops syncing or explicitly deactivates it. The three
source textures live under `assets/sprites/skills/void_phantom_vfx/` and retain
transparent radial margins. Regression guard:
`smasher_void_phantom_vfx_contract_smoke.gd` plus the windowed Vulkan visual QA.

### Guardian Spirit acquisition-cinematic audio boundary

`lingpet_acquisition_audio.gd` owns the cut-in, click deep-bass, and click
crackle-sweep cue specs, their stable eager player-creation order, ordered
item-phase prewarm projection, player cache, and missing-stream recovery. It
preserves the optional-player fallback used when an authored resource is
unavailable, but it must not choose pitch, fallbacks, or playback order.

`game_audio.gd` retains the three established `lingpet_acquire_*_sfx`
properties as compatibility facades, the public cut-in and click-reaction
playback methods, cut-in `0.98..1.02` pitch jitter, deep-bass-before-crackle
playback order, and item-get fallback. It also retains the acquisition owner's
existing position in item-audio setup, prewarm, and global SFX enumeration.
Do not restore acquisition path/gain constants, direct player creation, or
per-cue `_ensure_lingpet_acquire_*()` methods in the facade. Regression guard:
`game_audio_lingpet_acquisition_audio_owner_smoke.gd` plus volume-settings,
Lingpet dispatcher, and egg-runtime smokes.

### Guardian Spirit click-reaction voice audio boundary

`lingpet_click_voice_audio.gd` owns the eleven-pet click-reaction voice
catalog, stable player-creation order, the four existing prewarm stream paths,
pet-id normalization, eager player setup, and missing-stream recovery. Unknown
pet ids remain silent, and the focused owner must not choose playback pitch or
mutate the global SFX bus.

`game_audio.gd` retains the established public `lingpet_*_click_voice_sfx`
properties as compatibility facades, final `randf_range(0.98, 1.02)` playback,
SFX-bus application when lazy recovery returns a replacement, and staged audio
setup orchestration. Do not restore per-pet path/gain constants, an eleven-way
routing ladder, or individual `_ensure_lingpet_*_click_voice_sfx()` methods in
the facade. Regression guard: `game_audio_lingpet_click_voice_owner_smoke.gd`
plus the existing click-voice mapping, volume-settings, Lingpet dispatcher,
egg-runtime, and shared-stream loop-bleed smokes.

### Guardian Spirit combat-cue audio boundary

`lingpet_combat_audio.gd` owns twenty-seven non-click combat-cue specs and
player references: eleven created during item-audio setup, seven during
projectile setup, and nine Ghost Summon / Skeleton Archer / Bone Barrier cues
created in the stage-audio phase. It preserves each phase's creation order,
the existing selective item and stage prewarm sequences, the deliberate lazy
policy for Star Coil movement and all projectile-phase cues, and the two loaded
egg-hit candidate streams. Its stage SFX-bus projection intentionally includes
only the two Ghost Summon players because the seven skeleton/barrier players
were not part of the previous global SFX list. It must not mutate loop flags or
choose pitch/fallbacks.

`game_audio.gd` retains the public `play_lingpet_*`, `stop_lingpet_*`, and
`sync_lingpet_*` methods, per-cue pitch ranges, active-item/item-get/paddle-hit
fallbacks, random egg-hit selection, and loop start/stop policy. `_enable_loop`
remains the only owner of shared-stream duplication before loop mutation; this
keeps the focused Gravity Accel one-shot distinct from the Chaos Spear loop.
Do not restore the twenty-seven path/gain constants, direct player creation, or
player fields in the facade. Regression guard:
`game_audio_lingpet_combat_audio_owner_smoke.gd`, the focused Lingpet skill
smokes, volume settings, loop cleanup, egg runtime, and
`gravity_accel_cast_no_loop_bleed_smoke.gd`.

### Game audio bus/volume/pan boundary

`game_audio_bus_controller.gd` owns the BGM/SFX and Paddle/Wall pan-bus names,
default BGM/SFX volumes, one-time adoption of existing main-menu bus values,
AudioServer bus creation/routing, bus-volume application, panner effect
installation/cache, and the 760-wide source-X-to-pan projection. The two pan
buses remain unity-gain children of SFX; only their `AudioEffectPanner` changes
per hit.

`game_audio.gd` retains compatibility constants and read/write volume/panner
properties, the complete BGM/SFX player projections, public volume APIs, cue
playback and pitch, hit cooldowns, and the event-time choice of source X. Its
private compatibility wrappers delegate engine policy to the controller. Do
not restore direct `AudioServer` calls, raw bus-name constants, panner
construction, or pan geometry in the facade. Regression guard:
`game_audio_bus_controller_owner_smoke.gd`, volume settings, positional pan,
UI SFX, core ball/dash, stage BGM, all focused audio-owner smokes, Stage 7
audio, main-menu/character-select audio, and boot BGM-toggle smokes.

The same owner installs the character-info BGM low-pass once at
`apply_audio_buses_and_volumes()` and only toggles `set_bus_effect_enabled`
afterwards, so no gameplay frame pays a cold `AudioEffect` construction. The
install re-syncs the enable flag to the stored muffle state, which is what
clears a stale filter after a scene rebuild. SFX and the two pan buses never
send into BGM, so UI cues stay unfiltered while the ledger is open. Regression
guard: `character_info_bgm_muffle_smoke.gd` (real GameAudio + real overlay +
real AudioServer bus).

### Stage BGM catalog/audio boundary

`stage_bgm_audio.gd` owns the nine Stage 1-7 BGM specs, authored linear gains,
stable catalog order, Stage 1/2 selection pools, required-stream projection,
and player cache. Its ordered catalog is the single source for the nine setup
slots and audio-step 6 prewarm; the tenth BGM setup slot remains the shared
mute-state restore. The focused owner must not choose a track, consume RNG,
prime/play/stop audio, mutate cached stream loop flags, or own bus volume.

`game_audio.gd` retains path/gain/pool constants and nine read/write player
properties as compatibility facades, owner-stage filtering, staged setup and
progress, generic factory creation, and shared-stream-safe loop duplication.
Bus routing belongs to `game_audio_bus_controller.gd`; playback state belongs
to `stage_bgm_playback_controller.gd`. Do not restore BGM path literals, named
player creation, or the id-to-player/path match tables in the facade.
Regression guard: `game_audio_stage_bgm_audio_owner_smoke.gd`, Stage 1/2 BGM,
Stage 4 prime, volume settings, boot toggle, menu handoff, main-menu audio,
battle initialization/transition, character-select audio, stage-debug reset,
Stage 5/7 runtime audio, boss-health flow, and battle-resource prewarm smokes.

### Stage BGM playback-state boundary

`stage_bgm_playback_controller.gd` owns current/muted track names, remembered
prime gains, the shared mute flag and `BgmMuteState` persistence, Stage 1/2
selection RNG/readiness, fixed-stage routing, silent prime, restart, stop, mute
resume, and invalid-stage failure policy. It receives the BGM catalog and
player ensure/get callables only for each invocation, so it does not retain a
reference cycle back to `game_audio.gd`.

`game_audio.gd` keeps the public `prime_*`, `play_*`, `stop_bgm`, toggle/mute,
and private selector methods plus current/prime/mute/RNG fields as compatibility
facades. Player creation, loop-safe stream duplication, owner-stage setup,
bus volume, and stage-event timing remain outside the playback controller. Do
not restore direct `BgmMuteState`, RNG consumption, player restart, or prime
dictionary mutation in the facade. Regression guard:
`game_audio_stage_bgm_playback_controller_owner_smoke.gd`, stage BGM catalog,
Stage 1/2 selection, Stage 4 prime/map, volume settings, menu handoff,
main-menu/character-select audio, boot BGM toggle, Stage 7 audio/video, battle
initialization/intro/transition, stage-debug reset, Stage 5 runtime, and
boss-health flow smokes.

### Game audio setup-state boundary

`game_audio_setup_controller.gd` owns the seven-group audio setup cursor,
current stream-prewarm group/index and borrowed path list, BGM setup cursor,
synchronous shared-cache checks/loading, the one-new-stream-per-call budget,
92/8 stream-to-BGM progress projection, and completion-state math. The current
group's path list remains cached across loading frames, so progress sampling
does not rebuild the same combined catalog array each frame.

`game_audio.gd` keeps owner-node adoption, the exact seven group path
composition and setup side effects, player creation, loop-safe stream
duplication, BGM id filtering/player creation/mute restore, bus application,
and its public/private compatibility methods. The four historical setup fields
remain getter/setter properties because boot performance labels inspect them,
but their backing state lives only in the controller. Do not restore setup
counter storage or direct setup-stream I/O in the facade. Regression guard:
`game_audio_setup_controller_owner_smoke.gd`, all focused GameAudio owner
smokes, volume/UI/pan, boot-resource prewarm, Stage 1/2/4/7 BGM, gameplay-loop
cleanup, and shared-stream loop-bleed smokes.

### Battle texture-spec store boundary

`battle_texture_spec_store.gd` owns the backing battle-texture cache, texture
spec construction, full-alias completeness and path matching, concrete raw /
imported / optional loader selection, shared cached-texture adoption, and
alias writes. It deliberately operates only when an existing load or prewarm
path asks for a spec, so this split adds no boot, transition, or render hot-path
work.

`battle_resources.gd` keeps the public path aliases, domain-specific spec and
cache-key composition, pseudo-spec cleanup, skill-icon normalization, staged
ordering, and transition/result compatibility facades. Its `_resource_cache`
property exposes the store's same backing `Dictionary`, preserving direct
domain alias population and every existing consumer reference. Do not restore
a second cache or direct `ProjectResourceLoader` calls in the facade.
Regression guard: `battle_texture_spec_store_owner_smoke.gd`, transition and
result prewarm owner/runtime smokes, boot/stage-transition prewarm, large-
texture raw-decode audit, player/boss sprite, result, and continue-screen
smokes.

### Battle transition-texture prewarm boundary

`battle_transition_texture_prewarm_controller.gd` owns the active transition
key, fine-grained step cursor, single threaded texture-request slot, central
export-safe threadability gate, status polling, synchronous failure fallback,
completion handoff, and reset drain. Texture-state/cache/load callbacks are
provided per invocation, so the controller does not retain a reference back to
`battle_resources.gd`.

`battle_resources.gd` keeps context normalization, core/player/boss/skill-icon
spec composition and ordering, step counts, texture cache keys, skill-icon
normalization and temporary icon-map cleanup, plus the public transition
prewarm facade. Do not restore the transition key, step cursor, current spec,
current path, worker-active state, or direct `ResourceLoader` requests in the
facade. The performance contract remains one fine-grained spec step per call;
frame-budgeted warmup can still observe the combined transition/result worker
state without spin-polling. Regression guard:
`battle_transition_texture_prewarm_controller_owner_smoke.gd`, transition
prewarm, boot-resource prewarm, stage-transition loading, large-texture raw
decode audit, Smasher 2.5D override, Blacksmith Thor Shield, Stage 5 visual
shell, result bootstrap, and result-defer smokes.

### Battle result-texture prewarm boundary

`battle_result_texture_prewarm_controller.gd` owns the round-result texture
job queue, one-or-more-frame deferred start, duplicate-path suppression,
threaded request slot, status polling, completion handoff, and blocking drain
used when a newer result request replaces an older one. It receives texture
spec state/cache callbacks per invocation and does not retain a reference back
to `battle_resources.gd`.

`battle_resources.gd` keeps result-spec selection and the public `begin_*`,
`queue_*`, `update_*`,
`has_*`, and combined transition/result in-flight facade. Do not restore result
job, pending-delay, current-path, or worker-active fields in this facade. This
boundary does not add hot-path resource work: score events still defer the
threaded request until the configured later frame, and the frame controller
polls only while work exists. Regression guard:
`battle_result_texture_prewarm_controller_owner_smoke.gd`, result-defer/spec,
transition-prewarm, frame-controller, boot-prewarm, match-score, result
bootstrap, continue-screen, and stage-transition-loading smokes.

### Battle result-prewarm frame scheduling boundary

`battle_result_prewarm_frame_coordinator.gd` owns the frame-side scheduling
policy above the resource workers: the visible-scoreboard delay, safe score-pause
gate, pending game-reset requirement, custom win-goal/player-lead decision,
active result-screen exclusion, work-presence checks, and the two established
BattlePerf samples. It receives the battle owner, module getter, and performance
logger only for the current idle call and retains no runtime references.

`battle_scene_frame_controller.gd` keeps the idle ordering and its public
`RESULT_TEXTURE_PREWARM_SCOREBOARD_MIN_TIMER` compatibility constant, but
delegates the scheduling tick to one composed coordinator. The low-level result
texture job queue remains owned by
`scripts/resources/battle_result_texture_prewarm_controller.gd`, while staged
stage-clear resource preparation remains owned by
`battle_boot_resource_prewarm_controller.gd`. Do not restore scoreboard/result
win policy or direct prewarm calls to the frame controller. Regression guard:
`battle_result_prewarm_frame_coordinator_owner_smoke.gd`,
`battle_scene_frame_controller_draw_order_smoke.gd`, result-defer, and boot
resource prewarm smokes.

### Battle update-prewarm planning boundary

`battle_scene_update_prewarm_plan.gd` owns the pure dependency plan for battle
update warmup: normalized character/stage cache keys, character-specific player
control/effects/match runtime selection, current-stage versus all-stage runtime
selection, and stable nonempty deduplication. Static ordered dependency groups
remain data-only constants in `battle_scene_update_prewarm_key_sets.gd`.

`battle_scene_update_prewarm_driver.gd` keeps the staged execution state,
per-step detail labels, registry lookups, staged asset readiness, context-builder
finalization, BattlePerf adapter, and ball-update prewarm handoff. It asks the
plan owner for a fresh Array when entering each dependency group and does not
retain plan results. Do not restore character/stage key-selection branches or
deduplication to the executor. Regression guard:
`battle_scene_update_prewarm_plan_owner_smoke.gd` and
`update_prewarm_driver_smoke.gd`; the latter proves selected-character/current-
stage filtering and staged asset completion through the real executor.

### Battle stage-transition frame coordination boundary

`battle_stage_transition_frame_coordinator.gd` owns the frame-side transition
driver lookup and active gate, optional idle update, coalesced redraw request,
draw dispatch, black fallback, and the three established BattlePerf samples.
It receives owner, registry, module getter, canvas, viewport size, and logger
only for the current call and retains no driver or runtime reference.

`battle_scene_frame_controller.gd` keeps transition loading as the first idle
and draw priority after mobile-control sync/view-size setup, closes the total
frame sample, and returns when the coordinator consumes the frame. Transition
timeline state, staged preparation, final reveal, actual loading artwork, and
ball-spawn replay remain in `battle_scene_match_event_driver.gd`; physics and
input blocking remain in their focused gate/input owners. Do not restore direct
transition update/draw or driver lookup to the frame controller. Regression
guard: `battle_stage_transition_frame_coordinator_owner_smoke.gd`,
`battle_scene_frame_controller_draw_order_smoke.gd`,
`battle_scene_stage_transition_loading_smoke.gd`, and
`stage_transition_ball_spawn_intro_replay_smoke.gd`.

### Battle defeat-flow resolution boundary

`battle_defeat_flow_resolver.gd` owns scoreboard defeat classification and the
chance-gem branch after a reset-game scoreboard result: save-store count/max
reads, owner-field mirroring, delayed consume callbacks for the continue
screen, legacy immediate-consume screen fallback, missing-screen direct
continue fallback, and zero-gem settlement selection. The driver retains one
resolver instance because the visible continue screen holds its consume
callback until player confirmation.

`battle_scene_match_flow_driver.gd` keeps scoreboard-result ordering,
BattlePerf samples, reset-for-continue execution, and run-ending scene
navigation. It supplies bound continue/exit callbacks to the resolver instead
of letting the resolver own reset or scene changes. Do not restore screen
selection, chance-gem storage access, or owner gem synchronization to the
driver. Regression guard: `battle_defeat_flow_resolver_owner_smoke.gd`, match
flow/applier dependency, chance-gem continue, settlement, and match-event
smokes.

### Battle terminal-overlay idle coordination boundary

`battle_terminal_overlay_idle_coordinator.gd` owns idle update priority for the
stage-clear result, defeat chance-gem continue, and defeat settlement screens.
It preserves the result screen's single runtime-perk overlay tick, lets a
nonblocking continue animation flow into settlement in the same frame, stops
before settlement when the continue screen blocks physics, requests redraws,
and records the four focused BattlePerf samples. It retains no screen, owner,
registry, or module reference.

`battle_scene_frame_controller.gd` keeps this group after grip selection and
before the general overlay frame, closes `process.frame.total`, and returns when
the coordinator consumes the frame. A static `TERMINAL_OVERLAY_IDLE_CONTRACT`
string remains only for existing in-progress source-wiring smokes. Screen state,
timing, and visuals stay in their focused owners. Regression guard:
`battle_terminal_overlay_idle_coordinator_owner_smoke.gd`, stage-clear
runtime-perk single-tick/update-flow smokes, defeat continue/settlement smokes,
and `battle_scene_frame_controller_draw_order_smoke.gd`.

### Battle terminal-overlay draw presenter boundary

`battle_terminal_overlay_draw_presenter.gd` owns result-screen lookup/draw and
the late defeat draw priority of chance-gem continue before settlement. It
preserves the three established BattlePerf labels, receives all draw context for
the current call only, and retains no screen/runtime reference.

`battle_scene_frame_controller.gd` intentionally keeps two delegation points:
the result pass before normal battle drawing, followed by Lingpet acquisition /
overflow overlays, and the defeat pass after skill/Lingpet cut-ins but before the
general overlay frame. `TERMINAL_OVERLAY_DRAW_CONTRACT` retains source-wiring
labels for focused in-progress smokes. Do not merge the two calls in a way that
moves the Lingpet result overlay or changes defeat priority. Regression guard:
`battle_terminal_overlay_draw_presenter_owner_smoke.gd`, defeat continue/
settlement, Lingpet debug/overlay, and frame draw-order smokes.

### Battle spawn-overlay draw coordination boundary

`battle_spawn_overlay_draw_coordinator.gd` owns the normal battle draw followed
by the ball-spawn overlay hook and, while the intro requests it, the restored
pillar-overlay pass. It preserves the three established BattlePerf labels,
checks callback validity without creating a per-draw route collection, and
retains no canvas, owner, registry, intro-frame, or module reference. The
intro-frame controller and its detached FX host still own full-playfield
clipping, overlay state, artwork, and lifecycle.

`battle_scene_frame_controller.gd` keeps this group after the early result pass
and before mobile controls, grip selection, tutorials, and cut-ins. Its static
`SPAWN_OVERLAY_DRAW_CONTRACT` remains only for focused source-wiring smokes. Do
not move clipping or host ownership into this coordinator, and do not restore
the duplicated split/non-split draw branches to the frame controller.
Regression guard: `battle_spawn_overlay_draw_coordinator_owner_smoke.gd`,
`battle_scene_frame_controller_draw_order_smoke.gd`, and the ball-spawn intro
draw/finish/FX lifecycle smokes.

### Battle physics-gate coordination boundary

`battle_physics_gate_coordinator.gd` owns the ordered pre-update gate ladder:
logo, battle initialization, boot warmup, landing start/animation, ball-spawn
intro, stage transition, result screen, defeat continue, defeat settlement,
grip selection, and the general modal gate. It preserves each BattlePerf label,
the grip overlay's zero-delta probe/coalesced redraw, and modal pause-state
enter/leave symmetry. All frame/runtime references are received per physics call
and are not retained; the hot path uses explicit branches rather than a route
collection.

`battle_scene_frame_controller.gd` keeps `physics.frame.total`, performance-
logger/update-driver lookup timing, and normal update-driver dispatch. Its
private `_process_grip_selection_physics_gate()` remains a narrow compatibility
facade for focused direct-call tests, while `PHYSICS_GATE_CONTRACT` retains the
existing source-wiring strings. Do not restore the gate ladder or modal pause
entry/exit policy to the frame controller. Regression guard:
`battle_physics_gate_coordinator_owner_smoke.gd`, frame draw-order/physics,
redraw-coalescing, grip, modal cooldown/audio, and defeat-screen smokes.

### Battle Guardian Spirit interaction-input boundary

`battle_lingpet_interaction_input_router.gd` owns the two top-level Guardian
Spirit input placements around the general overlay ladder. Its early entry
swallows every shell-break event before defeat/result overlays and forwards an
active acquisition cut-in into the existing overlay input ladder. Its later
entry stays after desktop active-item HUD handling and preserves companion
click before E/RT interaction before L/Shift+L slot cycling. The router owns
screen-to-playfield click conversion, module-first runtime lookup with registry
fallback, and the RT press/release latch; accepted actions request redraw and
mark the input handled. It retains no owner, registry, or module reference.

Acquisition/companion state and reactions remain in `lingpet_egg_runtime.gd`;
overlay-local acquisition dismissal and collection-full choice remain in
`battle_lingpet_priority_input_router.gd`; rendering and modal physics remain
with their existing owners. Do not restore Lingpet layout conversion, RT latch
state, or slot-cycle policy to `battle_scene_input_controller.gd`. Regression
guard: `battle_lingpet_interaction_input_router_owner_smoke.gd`, Lingpet egg/
interaction/slot smokes, modal-overlap and acquisition-host smokes, plus the
desktop active-item HUD smoke that seals the adjacent input priority.

### Battle terminal-screen input boundary

`battle_terminal_screen_input_router.gd` owns the post-acquisition terminal
screen ladder: chance-gem continue first, defeat settlement second, and stage-
clear result third. It preserves the chance-gem screen's exceptional
fallthrough when its local handler refuses an event; active settlement and
stage-clear screens still consume and redraw regardless of their local return
value. When a runtime-perk choice is active above the stage-clear scene, the
router forwards the event through the overlay input controller instead of the
result screen. Live viewport size, redraw, and handled-input marking remain
per-call, and no screen or registry reference is retained.

Screen state, local navigation, rewards, revival/settlement effects, and
rendering remain with their existing owners; runtime-perk choice state remains
with its perk/modal owners. Do not restore the three terminal screen handlers
or their priority ladder to `battle_scene_input_controller.gd`. Regression
guard: `battle_terminal_screen_input_router_owner_smoke.gd`, chance-gem
continue, defeat settlement, stage-clear result, runtime-perk, modal-overlap,
and Guardian Spirit priority smokes.

### Battle reward-modal input boundary

`battle_reward_modal_input_router.gd` owns the reward-modal ladder immediately
after general runtime-perk choice input: mythic acquisition cinematic first,
Pandora Legacy selection second, and Angel Blessing third. Every active modal
consumes the event and requests redraw/handled state even when its optional
local handler is absent or returns false, matching the established modal
contract. The router preserves the acquisition handler's event/registry call
shape and forwards owner, registry, and live viewport size to Pandora and
Angel. It receives all references per call and retains none.

Mythic inventory/acquisition/Pandora state remains in `mythic_item_runtime.gd`;
Angel roll and perk state remain in `runtime_perk_state.gd`; presentation,
reward grants, audio, and modal physics remain with their existing owners. Do
not restore reward-modal predicates, fanout, or their three-rung priority to
`battle_scene_input_controller.gd`. Regression guard:
`battle_reward_modal_input_router_owner_smoke.gd`, Angel controller wiring,
modal-overlap, Pandora Legacy, mythic acquisition cinematic, runtime-perk, and
terminal-screen smokes.

### Battle combat-shortcut input boundary

`battle_combat_shortcut_input_router.gd` owns the final normal-battle shortcut
pair after overlays, desktop active-item HUD input, and Guardian Spirit
companion input: manual skill-orb tooltip cycling first, then Commando firearm
switching. It preserves gamepad Back, arrow-space grip Shift aliases and
metadata priority, tooltip-driver refusal fallthrough, Commando reader fanout,
and success-only redraw/handled marking. The router receives owner, registry,
and module access per call and retains none.

Tooltip selection/rendering remains in the tooltip driver/HUD owners; firearm
eligibility, debounce, inventory, audio, and weapon state remain in Commando
owners. Do not restore grip normalization, tooltip-cycle detection, or
Commando switch fanout to `battle_scene_input_controller.gd`. Regression guard:
`battle_combat_shortcut_input_router_owner_smoke.gd`, keyboard/gamepad skill-
orb tooltip cycling, Commando weapon/runtime routing, Guardian Spirit companion,
and desktop active-item HUD smokes.

### Battle system-shortcut input boundary

`battle_system_shortcut_input_router.gd` owns the three topmost battle input
routes before transition/loading gates: F11 fullscreen toggle, B-key BGM toggle,
and right-stick suppression. It also owns the stateful 450ms window that
suppresses synthetic mouse-wheel events immediately following right-stick
motion/click input. Fullscreen preserves owner-window forwarding and redraw;
BGM preserves its no-shell-redraw policy; normal wheel events outside the
window still fall through. The router retains only the suppression deadline,
not owner, module, window, or audio references.

Display-mode application remains in `battle_view_layout.gd`; playback/mute
state remains in `game_audio.gd`; shared gamepad mappings remain in
`gamepad_input.gd`. Do not restore system-shortcut fanout or the wheel deadline
to `battle_scene_input_controller.gd`. Regression guard:
`battle_system_shortcut_input_router_owner_smoke.gd`, fullscreen, audio-volume,
gamepad mapping, Commando weapon, active-item debug-wheel/HUD, and F9 smokes.

### Battle pre-intro stage-input boundary

`battle_pre_intro_stage_input_router.gd` owns the stage-specific input rung
after transition loading and mobile touch but before general intro/warmup
blocking. F9 debug force-clear has first priority: only a battle-ready landing
can force 5:0, create the player-win scoreboard snapshot, and open the result
screen with the live reset/exit callbacks; an already active result consumes
repeat F9 without rewriting state or redrawing. Stage 7 Akamu prebattle input
follows, using module-first lookup with registry fallback. Its active video
always consumes input, while only a locally accepted skip requests redraw.

Score/result state remains in their existing owners, and Stage 7 video timing,
media, cleanup, and local skip policy remain in
`stage7_akamu_prebattle_presentation.gd`. Do not restore F9 score mutation,
scoreboard/result handoff, or Stage 7 presentation dispatch to
`battle_scene_input_controller.gd`. Regression guard:
`battle_pre_intro_stage_input_router_owner_smoke.gd`, F9 stage-clear, Stage 7
prebattle video/live-frame, and system-shortcut smokes.

### Battle priority Lingpet modal-input boundary

`battle_lingpet_priority_input_router.gd` owns the two highest-priority
Guardian Spirit input routes after intro handling: acquisition cut-in dismissal
and collection-full overflow choice. It preserves acquisition-over-overflow
priority, swallows every event while either modal is active, waits for the
cut-in reveal to become dismissable, forwards the live registry for click
audio, resolves the overflow host cache-first with normal registry fallback,
and requests redraw/handled state only when the local action succeeds. The
router receives event, owner, registry, module getter, and live viewport size
per call and retains none of them.

`battle_scene_overlay_input_controller.gd` keeps the router call at the top of
its ladder, before grip selection, tutorial, debug, perk, pause, elixir, and
character-info input. Modal predicates and physics blocking remain in
`battle_scene_modal_gate_controller.gd`; acquisition state remains in
`lingpet_egg_runtime.gd`, and overflow layout/input remains in
`lingpet_overflow_choice_overlay_host.gd`. Do not restore cut-in dismissal or
overflow-host dispatch to the overlay controller. Regression guard:
`battle_lingpet_priority_input_router_owner_smoke.gd`, Lingpet egg runtime,
modal-overlap, direct debug-switch, grip-selection, tooltip-tutorial, and
Lingpet debug-picker smokes.

### Battle guided-overlay input boundary

`battle_guided_overlay_input_router.gd` owns the two guided modal input rungs
immediately below priority Guardian Spirit modals: grip-style selection first,
then the skill-orb tooltip tutorial. Each active overlay swallows the event even
when its local handler returns `false`; redraw and handled-input marking happen
only after a `true` result. The router forwards the live event, owner, registry,
and viewport size per call and retains none.

`battle_scene_overlay_input_controller.gd` keeps this router after the
acquisition/overflow rung and before every debug-menu shortcut. Overlay state,
local hit testing, and rendering remain in the two HUD modules; active
predicates and physics blocking remain in
`battle_scene_modal_gate_controller.gd`. Do not restore the duplicate modal
gates or handler calls to the top-level controller. Regression guard:
`battle_guided_overlay_input_router_owner_smoke.gd`, grip-selection,
skill-tooltip-tutorial, modal-overlap, direct debug-switch, physics-gate, and
redraw-coalescing smokes.

### Battle debug-menu switching boundary

`battle_debug_menu_shortcut_router.gd` owns the F1-F7/F9 key-to-menu mapping,
pressed/non-echo edge filtering, logical/physical keycode compatibility, and
handoff to `battle_debug_menu_switcher.gd`. F8 remains outside this router as
the separate runtime-perk point grant, and F10 remains owned by the exhibition
reset autoload. The overlay controller retains compatibility aliases for the
published debug-key constants but does not dispatch direct menu switches.

`battle_debug_menu_switcher.gd` owns the shared eight-menu catalog and the
direct-switch lifecycle for F1-F7/F9 debug surfaces: selected-menu open-state
lookup, character-info/pause closure, close-all dispatch, same-key close,
menu-specific prewarm before open, active-item/mythic/ball-speed close-method
fallbacks, redraw, and handled-input marking. It receives the battle owner and
module getter only for the current call and retains no runtime/module reference.

`battle_debug_menu_input_router.gd` owns input delivery for the six debug
surfaces that accept menu-local events: character, weather, stage, Lingpet,
mythic management, and runtime-perk picker. It preserves their modal-consume
semantics even when the menu handler returns `false`, requests redraw/handled
state only when the handler returns `true`, and retains no event, owner,
registry, or module reference.

`battle_active_item_debug_input_router.gd` owns the F2 active-item grid event
handoff after the higher-priority modal and debug-menu ladder. It prefers the
current full-event API, preserves the legacy left-click fallback for compatible
runtimes, forwards the live viewport size/owner/registry, and requests redraw
and handled-input state only for a true runtime result. It does not read or
mutate active-slot manual input-edge state, catalog membership, item effects,
or acquisition routes, and retains no live reference.

`battle_scene_overlay_input_controller.gd` intentionally keeps the exact key
priority, including the F1-F7/F9 shortcut router before open-menu dispatch and
the separate F8 perk-point grant. It delegates key-driven switches to the
shortcut router and active debug-menu event delivery to the input router.
Pause-open cleanup calls the switcher through
`battle_pause_menu_input_router.gd`. The controller delegates the later F2
active-item grid/click fallback to the active-item router; the F9 read-only
overlay has no menu-local input.
Modal predicates and physics blocking remain in
`battle_scene_modal_gate_controller.gd`; each picker/runtime continues to own
its menu state, rendering, and menu-local input. Do not restore the catalog,
open/close dispatch, prewarm policy, or six-menu event fanout to the input
controller, and do not restore F2 runtime API compatibility policy there.
Regression guard: `battle_debug_menu_shortcut_router_owner_smoke.gd`,
`battle_debug_menu_switcher_owner_smoke.gd`,
`battle_debug_menu_input_router_owner_smoke.gd`,
`battle_active_item_debug_input_router_owner_smoke.gd`, direct-switch,
Lingpet/weather debug-key, pause, modal-overlap, grip-selection, and
tooltip-tutorial input smokes.

### Battle runtime-perk input boundary

`battle_runtime_perk_input_router.gd` owns the two battle-side runtime-perk
input entries: active choice-modal event delivery/consumption and the later F8
debug starpoint grant. Active choices swallow every event while open and only
request redraw/handled state when the runtime state reports success. F8 accepts
logical or physical pressed/non-echo edges, invokes the shell callback, and
preserves redraw/handled behavior even if the optional callback is unavailable.
The router receives all live references per call and retains none.

`battle_scene_overlay_input_controller.gd` preserves both original placement
points: active choice input remains after open debug-menu input and before the
pause menu; F8 remains after pause/character-info shortcuts and before the
final F2 active-item grid path. Runtime perk selection, offer construction,
application, animation guards, UI, save state, and effective-level logic remain
in their existing owners. Do not restore modal lookup, local event dispatch, or
F8 callback policy to the top-level controller. Regression guard:
`battle_runtime_perk_input_router_owner_smoke.gd`, runtime-perk modal,
gamepad-navigation, selection, debug-grant, dispatch, modal-overlap,
debug-shortcut owner, and exhibition-reset smokes.

### Battle character-info input boundary

`battle_character_info_input_router.gd` owns battle-side TAB character-info
input policy: active-overlay event delivery, `consume_input_redraw_request()`
throttling, overlay-frame redraw forwarding with owner fallback, TAB key
recognition, pause-overlay closure, equipped-slot Guardian Spirit prewarm
filtering, current-view-size forwarding, and two-argument/legacy zero-argument
`open()` compatibility. The pause menu's character-info action reuses the same
prewarm/open path without duplicating shortcut cleanup or redraw policy. The
router receives all live objects per call and retains none.

`battle_scene_overlay_input_controller.gd` preserves both original placement
points: active character-info input stays after elixir confirmation, while the
TAB open shortcut stays after pause-open handling. The character-info overlay
continues to own its state, local hit testing, hover caches, and redraw-request
flag; `battle_scene_modal_gate_controller.gd` continues to own the active
predicate. Do not restore prewarm, signature inspection, redraw throttling, or
TAB open policy to the top-level controller. Regression guard:
`battle_character_info_input_router_owner_smoke.gd`, character-info input
redraw, prewarm, cooldown-pause, pause-menu, direct debug-switch, and
modal-overlap smokes.

### Battle pause-menu input boundary

`battle_pause_menu_input_router.gd` owns battle-side pause-menu event policy:
active-menu event delivery and modal consumption, dictionary/boolean handled
result compatibility, `character_info` / `continue` / `exit_to_main` action
dispatch, ESC and gamepad Start recognition, debug-menu close-all before open,
redraw requests, and handled-input marking. Character-info actions reuse
`battle_character_info_input_router.gd`; run-ending exits reuse
`battle_scene_match_flow_driver.gd`. The router receives the current event,
owner, registry, module getter, and viewport size per call and retains none.

`battle_scene_overlay_input_controller.gd` preserves the original placement:
active pause input remains after runtime-perk choice and before elixir input;
the open shortcut remains after active character-info input and before TAB
opening. Pause state/rendering stays in `pause_menu_overlay.gd`, the active
predicate stays in `battle_scene_modal_gate_controller.gd`, and debug-menu
close mechanics stay in `battle_debug_menu_switcher.gd`. Do not restore pause
result parsing, action dispatch, or shortcut cleanup to the top-level
controller. Regression guard: `battle_pause_menu_input_router_owner_smoke.gd`,
pause-menu, character-info cooldown-pause, direct debug-switch, modal-overlap,
character-info owner, debug-switcher owner, and exhibition-reset smokes.

### Battle Elixir cinematic input boundary

`battle_elixir_cinematic_input_router.gd` owns active Elixir of Mastery
cinematic input: modal consumption, keyboard Space/Enter logical and physical
keys, left mouse confirmation, shared gamepad confirmation, runtime confirm
handoff, and success-only redraw/handled marking. The router receives the live
event, owner, and module getter per call and retains none.

`battle_scene_overlay_input_controller.gd` keeps the Elixir router after active
pause input and before active character-info input. Cinematic state, phase
advancement, gameplay effects, drawing, and cleanup remain in the active-item
runtime/effect owners, while the active predicate remains in the modal gate.
The controller no longer keeps confirm-key policy or the uncalled private
weather-cycle compatibility wrapper; weather debug cycling remains with the
weather picker/update driver. Regression guard:
`battle_elixir_cinematic_input_router_owner_smoke.gd`, Elixir of Mastery,
modal-overlap, modal-gate performance, and active-item catalog smokes.

### Battle grip-selection frame coordination boundary

`battle_grip_selection_frame_coordinator.gd` owns the grip overlay's idle
update, redraw forwarding, post-update active gate, active draw dispatch, and
the two focused BattlePerf samples. It receives the owner, registry, module
getter, canvas, and viewport size only for the current call and retains no
overlay or runtime reference. An active overlay still consumes the draw frame
when its optional draw method is absent, matching the previous modal behavior.

`battle_scene_frame_controller.gd` keeps idle placement after ungated Lingpet
flows and draw placement after mobile controls. It closes the total frame
sample and returns when the coordinator reports the overlay active. Physics
opening/blocking remains in `battle_physics_gate_coordinator.gd`, input remains
in `battle_scene_overlay_input_controller.gd`, and the HUD module remains the
owner of selection state and rendering. Regression guard:
`battle_grip_selection_frame_coordinator_owner_smoke.gd`,
`grip_style_selection_overlay_smoke.gd`, redraw-coalescing, physics-gate, and
frame draw-order smokes.

### Battle tutorial idle-coordination boundary

`battle_tutorial_idle_coordinator.gd` owns the fixed idle update order for the
Junior Mika, skill-tooltip, Commando firearm, Viper jetpack, Viper practice,
active-item-use, and character-info tutorial helpers. It preserves Junior Mika's
three-argument update signature, the other helpers' module-getter-aware
four-argument signature, each helper's BattlePerf label, and one redraw request
for every helper that returns `true`. It receives all runtime references only for
the current idle call and allocates no per-frame route Array or Dictionary.

`battle_scene_frame_controller.gd` keeps tutorial updates after scoreboard
visual sync and before result-prewarm scheduling, but delegates the seven-route
fanout to one composed coordinator. Hint-specific visibility and timing remain in
the existing HUD/practice modules, and draw ordering remains in the frame
controller. Do not restore tutorial update keys, signatures, or performance
labels to the frame controller. Regression guard:
`battle_tutorial_idle_coordinator_owner_smoke.gd`, the seven focused tutorial /
practice smokes, and `battle_scene_frame_controller_draw_order_smoke.gd`.

### Battle tutorial draw-coordination boundary

`battle_tutorial_draw_coordinator.gd` owns the fixed display order for the same
seven tutorial/practice helpers, preserves Junior Mika's owner-only draw
signature and the other six helpers' registry-aware signature, and records each
route's BattlePerf sample. It receives all draw context only for the current
call, retains no hint/runtime reference, and creates no per-frame route Array or
Dictionary.

`battle_scene_frame_controller.gd` keeps the tutorial group between grip-overlay
handling and skill cut-ins, and retains only a static `TUTORIAL_DRAW_ROUTE_KEYS`
source-wiring compatibility catalog for existing focused smokes. Actual module
lookup, draw dispatch, signature policy, and performance labels belong to the
coordinator. Hint artwork and visibility remain in the existing HUD/practice
modules. Regression guard: `battle_tutorial_draw_coordinator_owner_smoke.gd`,
the seven focused tutorial/practice smokes, and
`battle_scene_frame_controller_draw_order_smoke.gd`.

### Battle Lingpet ungated-idle coordination boundary

`battle_lingpet_ungated_idle_coordinator.gd` owns the modal-safe idle priority
for shell break, acquisition cut-in, and overflow choice. It preserves the
shell-break-before-cut-in commit order, passes owner/registry to shell breaking,
passes registry to the streamed cut-in reveal, requests one redraw for every
consumed frame, and holds overflow without advancing an unrelated clock. It
retains no owner, registry, runtime, or module-getter reference.

`battle_scene_frame_controller.gd` keeps this group after intro/warmup gates and
before grip selection, closes the total-frame BattlePerf sample, and returns
when the coordinator consumes the frame. It retains only a static
`LINGPET_UNGATED_IDLE_METHODS` source-wiring compatibility catalog for the
in-progress Lingpet runtime smoke. Do not restore direct Lingpet runtime
branching to the frame controller. Regression guard:
`battle_lingpet_ungated_idle_coordinator_owner_smoke.gd`, Lingpet egg/overflow/
debug smokes, and `battle_scene_frame_controller_draw_order_smoke.gd`.

### Battle skill cut-in presenter boundary

`battle_skill_cutin_presenter.gd` owns the full-screen skill cut-in's
Smasher-before-Viper active-state selection, blocking-overlay suppression,
cached host lookup, draw dispatch, and BattlePerf sample. The priority check is
explicit rather than an inline route Array, so the draw hot path creates no
temporary collection. Registry, module getter, canvas, state, and performance
logger are received per draw and are not retained.

`battle_scene_frame_controller.gd` keeps final cut-in group ordering and the
private `_draw_skill_cutin_if_active()` compatibility facade, but delegates its
body to one composed presenter. Skill cut-in state modules still own activation
and timing, while `skill_cutin_overlay_host.gd` owns artwork and prewarm. Do not
restore active-state selection, modal policy, or direct host dispatch to the
frame controller. Regression guard: `battle_skill_cutin_presenter_owner_smoke.gd`,
Smasher/Viper cut-in smokes, Drive/Shield presenter smokes, and
`battle_scene_frame_controller_draw_order_smoke.gd`.

### Battle Drive / Shield cut-in presenter boundary

`battle_drive_cutin_presenter.gd` owns Drive-over-Shield presentation priority,
blocking-overlay suppression, immediate-mode host dispatch, shared particle-host
lookup/deferred creation, particle progress/slide/enraged projection, and the
Drive/Shield/FX-sync BattlePerf samples. It also owns a reusable FX sync
Dictionary, so the draw hot path no longer creates an inline payload every frame.
The presenter retains only its detached FX host, deferred-add latch, and reusable
payload; registry, overlay, skill state, canvas, and performance logger are
received per draw and are not retained.

`battle_scene_frame_controller.gd` keeps final cut-in draw position and the
private `_draw_drive_cutin_if_active()` compatibility facade, but delegates its
body to one composed presenter. `skill_cutin_overlay_host.gd` remains the owner
of cut-in artwork, curves, and boot-time runtime-node prewarm, while
`drive_cutin_fx_host.gd` remains the particle implementation. Do not restore the
FX-host reference, deferred-add state, priority policy, or inline sync Dictionary
to the frame controller. Regression guard:
`battle_drive_cutin_presenter_owner_smoke.gd`, Drive/Shield cut-in and Drive FX
host smokes, and `battle_scene_frame_controller_draw_order_smoke.gd`.

### Battle Lingpet overlay presenter boundary

`battle_lingpet_overlay_presenter.gd` owns cached-first registry lookup with
normal-instantiation fallback, route-active method validation, overlay-host draw
dispatch, and the route's BattlePerf sample. It receives the runtime key,
active-method name, host key, canvas, view size, and performance logger for the
current draw only and retains no runtime or host reference.

`battle_scene_frame_controller.gd` keeps the acquire-cut-in and overflow-choice
draw positions, their private compatibility facades, and the explicit route
keys/labels, but delegates their shared resolution and dispatch policy to one
composed presenter. The Lingpet runtime and the two overlay hosts remain the
owners of state, artwork, input, and timing. Do not duplicate cached-first
fallback or direct host dispatch in the frame controller. Regression guard:
`battle_lingpet_overlay_presenter_owner_smoke.gd`, Lingpet egg/overflow/debug
smokes, the acquire-host resolver smoke, and
`battle_scene_frame_controller_draw_order_smoke.gd`.

### Game UI feedback-audio boundary

`game_ui_feedback_audio.gd` owns the four cached one-shot specs for UI Move,
Confirm, Back, and Perk Select. It preserves their exact eager player creation,
step-0 prewarm, and global SFX-bus head order, plus the player cache. The
focused owner must not choose playback pitch or fallbacks, change bus volume,
or decide when a menu, modal, or reward flow emits a cue.

`game_audio.gd` retains the four path/gain constants as compatibility aliases,
all four read/write player properties, public playback methods and authored
pitch ranges, and the Runtime Perk Select fallback to UI Confirm. Focused UI
owners retain navigation, confirmation, cancellation, and modal event timing.
Do not restore the four path literals or direct UI player creation in the
facade. Regression guard: `game_audio_ui_feedback_audio_owner_smoke.gd`,
`game_audio_ui_sfx_smoke.gd`, volume settings, Pause Menu overlay/navigation
smokes, Runtime Perk choice audio, Stage Clear starpoint choice, and the
neighboring core ball/dash audio-owner smoke.

### Core ball / dash audio boundary

`core_ball_dash_audio.gd` owns twelve cue specs and player references: Paddle
Hit, normal/Pingpong Serve, Wall Hit, Dash/Half Dash, Dash Delay, Dash Charge,
Bust Up, Boost Charging, Soul Burst Dash, and Dash Spirit Delete. It preserves
their exact eager creation, step-0 prewarm, and global SFX-bus order immediately
after the UI cues, plus the player cache. That "after the UI cues" anchor is a
derived count (`game_ui_feedback_audio.get_cue_ids().size()`), never a literal
index — a literal breaks the moment a UI cue is added and the standard runner
then aborts the whole batch. The owner must not configure
positional buses, choose pitch or fallbacks, enforce hit cooldowns, mutate loop
flags, or own round cleanup.

`game_audio.gd` retains the five UI players, all twelve read/write compatibility
properties, public playback/sync/stop methods, Paddle/Wall panning and cooldowns,
Serve/Dash selection and fallback policy, and `_enable_loop(dash_delay_sfx)`.
Dash Delay remains the only loop-enabled stream in this owner: `_enable_loop`
duplicates the path-cached WAV before mutation, and `stop_dash_delay` stays in
`gameplay_loop_audio_cleanup.gd` for score, serve, restart, transition, and full
reset boundaries. Do not restore the twelve path constants or direct player
creation in the facade. Regression guard:
`game_audio_core_ball_dash_audio_owner_smoke.gd`, positional pan and volume
settings smokes, Dash Acceleration/Boost Charging smokes, global loop cleanup,
effects round-boundary cleanup, stage-transition cleanup, and the neighboring
Smasher audio-owner smoke.

### Item / reward feedback-audio boundary

`item_reward_feedback_audio.gd` owns twenty-six primary item, reward, defeat,
perk-fusion, legendary-cinematic, and generic item-action cue specs plus the two
optional Angel Blessing absorb players. It preserves three distinct audio-step
3 setup phases: the original twenty-three players at the head, Legendary After/
Ending after Guardian Spirit item cues, and Timewatch/Throw Before/Throw after
elemental combat cues. Its matching SFX-bus and prewarm projections keep those
same interleavings; the original seventeen-path head projection, two cinematic
paths, and three action paths total twenty-two unique staged entries. The four
Cold Boot cues deliberately remain outside prewarm, the two extra Angel layers
remain at the SFX tail, and every cue in this owner remains a one-shot.

`game_audio.gd` retains path/gain constants as compatibility aliases, all
twenty-six read/write primary player properties, public playback and fallback
methods, authored pitch ranges, the three-player Angel Blessing rotation
cursor, `stop_legendary_after`, and `stop_angel_blessing_audio`. The focused
owner must not choose playback, advance the absorb cursor, stop cinematic
players, mutate stream loop flags, or own round cleanup.
Do not restore direct player creation or inline prewarm/SFX enumeration in the
facade. Regression guard:
`game_audio_item_reward_feedback_audio_owner_smoke.gd`,
`angel_blessing_audio_smoke.gd`, the defeat/result-screen and mythic-acquisition
cinematic smokes, Stopwatch and throwable-item smokes, volume settings, global
loop cleanup, and the neighboring Guardian Spirit/elemental/transformation
audio-owner smokes.

### Projectile-item audio boundary

`projectile_item_audio.gd` owns twenty-four throwable/deployable cue specs and
twenty-three resident players for grenade/fire/flash/smoke, Boomerang,
Shrapnel Armor, banana, soap, Spider Mine, and Bomb Surprise. The separate
Dynamite Fuse spec remains catalog-owned but its short-lived player is created
per use. The owner preserves the exact split setup around Boomerang loop
mutation (nine players before, fourteen after), the sixteen-path step-4
prewarm projection, global SFX-bus order, and player cache.

`game_audio.gd` retains compatibility constant/property facades, every public
play/stop/sync method, pitch/fallback and Bomb Surprise volume policy, dynamic
Dynamite Fuse creation/freeing, and shared-stream-safe loop mutation. Boomerang
and Spider Mine Walk remain the only loop-enabled resident streams in this
owner; their stop methods and the sustained Bomb Surprise urgent-tick stop stay
in `gameplay_loop_audio_cleanup.gd`. The focused owner must not mutate streams,
choose playback, or own cleanup. Regression guard:
`game_audio_projectile_item_audio_owner_smoke.gd`, the grenade/Dynamite/
Boomerang/Spider Mine/banana/soap/Bomb Surprise smokes, volume settings,
effects round-boundary cleanup, global loop cleanup, and the neighboring
Guardian Spirit combat and Stage 3 audio-owner smokes.

### Transformation-item audio boundary

`transformation_item_audio.gd` owns fourteen Horn Strawberry and Odin's Eye
cue specs, exact eager creation order (nine Horn players then five Odin
players), player cache, Horn-only nine-path prewarm, and the legacy split SFX
projection: Horn Change, five Odin cues, then the remaining eight Horn cues.
The five Odin WAVs deliberately remain outside staged prewarm, and all fourteen
players remain cached-stream one-shots.

`game_audio.gd` retains compatibility constant/property facades, every public
playback alias, pitch/fallback policy, `stop_horn_strawberry_eat`, and the two
intentional no-op Horn impact/explosion facades. Transformation runtime owners
retain transform, revival, skill-edge, and round-boundary timing. The focused
audio owner must not choose playback/fallbacks, stop players, mutate streams,
or own gameplay events. Regression guard:
`game_audio_transformation_item_audio_owner_smoke.gd`,
`horn_strawberry_audio_vfx_smoke.gd`, Horn round-boundary/HUD smokes,
`odins_eye_audio_smoke.gd`, Odin catalog/revival/finalize/death-cinematic
smokes, volume settings, and the neighboring projectile-item owner smoke.

### Elemental combat-audio boundary

`elemental_combat_audio.gd` owns ten Ragnarok, electric-shock, Lumion
lightning, and Poseidon cue specs, their exact eager creation and SFX-bus
order, the nine-path step-3 prewarm projection, the three setup-time
mini-spark candidate streams, loop membership metadata, and player cache.
Mini Spark deliberately stays outside explicit staged prewarm because all
three variants are loaded immediately after its resident player is created.

`game_audio.gd` retains compatibility constant/property facades, public
playback/fallback methods, authored pitch and random-stream selection policy,
and guarded shared-stream loop mutation. Ragnarok Shock and Electric Shock
must still pass through `_enable_loop()` only after all ten players exist, and
their public stop facades remain registered in
`gameplay_loop_audio_cleanup.gd`; the focused owner must not mutate streams,
choose playback, consume RNG, or own round cleanup. Regression guard:
`game_audio_elemental_combat_audio_owner_smoke.gd`, Ragnarok Hammer, Poseidon
Trident, Lumion Thunder Orb/Solar Bolt and launch-router smokes, effects audio
round-boundary/global loop cleanup, score/reset/restart controllers, and volume
settings.

### Shared stage-feedback audio boundary

`shared_stage_feedback_audio.gd` owns nine cached one-shot specs for Round Set,
ball-spawn/stage-landing intros, Stage 1 balloon feedback, star collection,
Laurel Leaf Shield, and Trampoline. It preserves the seven-player primary
setup/prewarm/SFX projection immediately after Smasher stage feedback plus the
two-player tail setup after Hongryun hurt-player creation. The tail prewarm
remains after Stage 7 and before Smasher voice candidates, while its SFX
projection remains after Stage 7 and before fan/AK-47/Angel/Hongryun tail
layers.

`game_audio.gd` retains compatibility constants/properties, every public
playback alias, authored pitch/fallback policy, Trampoline's wall-hit fallback,
fixed-pitch intro restart behavior, and `stop_ball_spawn_intro`. Score, intro,
stage-event, perk, reward, and field-collision owners retain event timing. The
focused owner must not choose playback, consume RNG, stop intro audio, mutate
streams, or own lifecycle. Regression guard:
`game_audio_shared_stage_feedback_audio_owner_smoke.gd`, Smasher and Stage 2-7
audio-owner smokes, ball-spawn intro begin/finish/lifecycle smokes, Laurel Leaf
Shield, Trampoline, runtime-perk choice, score event, starpoint choice, volume
settings, and Stage 2 audio-router smokes.

### Stage 1 balloon runtime and interaction boundary

`stage1_balloon_runtime_state.gd` is the retained owner for the live balloon
collection and playfield bounds. It owns frame-scaled translation, post-paddle
drag/cooldown, bob/spin, radius-aware wall reflection, lifetime advancement,
swept path and circle/rectangle geometry, paddle-bounce response, and random
ball deflection. Construction and bounds configuration consume no RNG; the
rare center-contact and deflection branches retain the facade's global-RNG
behavior.

`stage1_balloon_interaction_coordinator.gd` owns every destructive interaction:
Stage 1 gating, first swept ball hit, Whip deflection suppression, Commando
bullet eligibility/result projection, reverse-safe Chaos Spear absorption,
player dash pop, player/boss paddle routing, Cleanse-before-Celestial-Armor
immunity, and knockback. Removal must precede the facade's synchronous pop
feedback; ball deflection and absorbed-result publication must follow it. The
facade retains spawn payload RNG, pop VFX, special-starpoint creation, pop
audio, texture/prewarm and drawing, with writable collection and private math /
interaction compatibility facades only. Regression guard:
`stage1_balloon_gameplay_coordinator_smoke.gd`, payload/render-budget/machine /
starpoint smokes, Commando balloon interaction, Chaos Spear, and Gaksital wind.

### Stage 1 balloon machine-state boundary

`stage1_balloon_machine_state.gd` retains the balloon machine's active flag,
phase/timer, cooldown, door/machine envelopes, shot accumulator/count, and
per-activation count/order/special/angle plan. It owns the original global-RNG
order, initial/reset cooldown roll, activation-frame delay, phase transitions,
door/machine start-edge audio, staged-prewarm request position, multi-shot
catch-up loop, and ordered host callbacks. Construction consumes only the
single cooldown roll historically performed by the facade `_init()`.

`stage1_balloon_event.gd` retains live balloon payload construction, pop audio,
staged texture loading, feedback and rendering. Its writable
machine properties and `_activate` / `_update_machine` / `_set_phase` /
`_deactivate` / `_set_next_cooldown` methods are compatibility facades only;
do not restore mirrored scheduler state or the RNG plan builders. Regression
guard: `stage1_balloon_machine_state_smoke.gd`, balloon render-budget/payload,
boot prewarm, debug-reset, Commando collision, and starpoint lifecycle smokes.

### Stage 1 balloon starpoint-state boundary

`stage1_balloon_starpoint_state.gd` is the retained owner for the balloon
event's starpoint drop and particle collections. It owns bounds configuration,
primary and Star Detector bonus payload order, the original global-RNG calls,
fall/bounce motion, Dowsing attraction, Starlight Tracking claim/delivery,
Stage 1 rectangle-overlap collection, modal-safe in-place compaction, reward /
particle / audio / redraw order, and particle advancement. Construction and
bounds configuration must not consume RNG.

`stage1_balloon_event.gd` retains foreground starpoint rendering, detached
visual-host hide cleanup, and the public `spawn_starpoint_drop` facade. Its writable
`starpoint_drops` / `starpoint_particles` compatibility properties and private
spawn/update methods must delegate to the retained owner without mirrored
arrays. Regression guard: `stage1_balloon_starpoint_state_smoke.gd`, the Stage
1 balloon lifecycle/render-budget and Commando interaction smokes, plus shared
Star Detector, Dowsing, Starlight Tracking, reward, compaction, payload,
motion, overlap, and particle-state smokes.

### Stage 1 boss skill-audio boundary

`stage1_boss_skill_audio.gd` owns the Dalji Whip, Gaksital Fan, and Gaksital
Whipcrack specs plus the two extra Fan players used for overlapping enraged
throws. It preserves the exact eager order (Whip, Fan primary, Fan layers 2/3,
Whipcrack), the three unique prewarm paths, the primary SFX-bus projection near
Smasher, the extra-layer tail projection, and the player cache. The owner must
not choose playback pitch or per-call volume, advance the fan cursor, or own
event timing and cleanup.

`game_audio.gd` retains the established Whip/Fan/Whipcrack properties as
read/write compatibility facades, public playback methods, authored pitch
jitter, dynamic Fan/Whipcrack volume, the three-player fan rotation policy, and
the `stop_whip` facade registered in `gameplay_loop_audio_cleanup.gd`. Do not
restore the three path constants, pool-size constant, direct player creation,
or fan-layer storage in the facade. Regression guard:
`game_audio_stage1_boss_skill_audio_owner_smoke.gd`, the Gaksital Fan Throw/Wind
and Dalji Spinning Top smokes, global loop cleanup, effects round-boundary
cleanup, volume settings, and the neighboring Smasher/Viper owner smokes.

### Blacksmith Thor Shield audio boundary

`blacksmith_thor_shield_audio.gd` owns the Open, Close, Swing, and Block cue
specs, stable eager player-creation and SFX-bus order, and player cache. The
four WAVs deliberately remain outside the explicit skill prewarm projection:
their eager setup is the established load path. They remain cached-stream
one-shots with `LOOP_DISABLED`; the owner must not duplicate/mutate streams,
choose playback pitch, or own Thor Shield phase/collision timing.

`game_audio.gd` retains the four player properties as read/write compatibility
facades and the public `play_thor_shield_*` methods with authored pitch jitter.
`blacksmith_thor_shield_state.gd` remains the sole authority for deploy,
retract, main-swing, block, hit cooldown, and audio event timing; do not move
those calls into the catalog owner or introduce a second tick path. Do not
restore Thor Shield path constants or direct player creation in the facade.
Regression guard: `game_audio_blacksmith_thor_shield_audio_owner_smoke.gd`,
`blacksmith_thor_shield_runtime_smoke.gd`, volume settings, character dependency
builders, and the neighboring Stage 1/Viper audio-owner smokes.

### Mugong-fusion combat audio boundary

`perk_fusion_combat_audio.gd` owns the cross-character Mugong-fusion combat
cue catalog, its stage-feedback setup/prewarm/SFX projection, and player cache.
The first cue is the exact legacy `magicdefense.wav` one-shot used when
`spellbreaker_guard` (`파법호신결`) parries an eligible boss skill, at the
original linear volume 0.5 (`-6.0205999 dB`) and fixed pitch. The owner must not
choose playback timing, mutate the cached stream, or add an activation cue: the
original Magic Barrier activation was silent apart from its speech bubble.

`game_audio.gd` retains the public `play_spellbreaker_guard_parry` facade and
fixed-pitch playback policy. `boss_skill_parry_gate.gd` remains the only
production dispatch point, so one blocked skill emits one cue. Regression
guard: `game_audio_perk_fusion_combat_audio_owner_smoke.gd` and
`perk_fusion_spellbreaker_guard_smoke.gd`.

### Smasher skill-audio boundary

`smasher_skill_audio.gd` owns thirteen base skill-cue specs, four Power/Ghost
Smashing stage-feedback specs, their two phase-stable player-creation and
SFX-bus projections, the matching split prewarm projections, player cache, and
the two four-stream cut-in voice pools. Base cues remain at audio setup step 1;
Power Smash primary paths remain at the start of stage-feedback prewarm, while
the eight voice paths remain after shared stage/skill paths and before Stage 5
hurt prewarm. The owner must not choose playback pitch or voice RNG, mutate
shared stream loop flags, or own event timing and cleanup.

`game_audio.gd` retains the established Smasher player/voice-stream properties
as compatibility facades, every public play/stop/sync method, pitch and random
voice selection, and shared-stream-safe loop enabling for Plasma Charge,
Plasma Shock, Warp Gate, Magnum Grip, and Smasher Wheel. Their stop facades stay
registered in `gameplay_loop_audio_cleanup.gd`; Shield Kiting wind-up keeps its
separate stop-capable cleanup contract. Do not restore Smasher cue path/gain
constants or direct player creation in the facade. Regression guard:
`game_audio_smasher_skill_audio_owner_smoke.gd`, the Plasma/Wheel/Shield Kiting
and Drive/Power Smash smokes, effects round-boundary cleanup, volume settings,
and shared-stream loop-bleed smoke.

### Viper / Chaos Spear skill-audio boundary

`viper_skill_audio.gd` owns the twenty-two Viper and Chaos Spear cue specs,
their stable eager player-creation and global SFX-bus order, player cache, and
the selective twenty-one-path prewarm projection. Marshal Kick deliberately
reuses Shadow Kick's stream and stays out of the prewarm projection; all other
cues retain their previous step-1 position. The owner must not choose playback
pitch or fallbacks, mutate shared stream loop flags, or own event timing and
cleanup.

`game_audio.gd` retains the established Viper/Chaos player properties as
read/write compatibility facades, every public play/stop/sync method, authored
pitch and fallback policy, and shared-stream-safe loop enabling. Only Jetpack
and the Chaos Spear black hole are true loop-enabled streams. Blade Spin,
Dual Glitch wind-up, the three Chaos phases, and those two loops keep public
stop methods registered in `gameplay_loop_audio_cleanup.gd`; this closes the
previous round-boundary gap for a Dual Glitch cancelled during startup. Do not
restore cue path/gain constants or direct Viper/Chaos player creation in the
facade. Regression guard: `game_audio_viper_skill_audio_owner_smoke.gd`, the
focused Viper/Chaos skill smokes, global loop cleanup, volume settings, effects
round-boundary cleanup, and `gravity_accel_cast_no_loop_bleed_smoke.gd`.

### Commando skill-audio boundary

`commando_skill_audio.gd` owns the nineteen primary Commando cue specs, their
stable optional-player creation order, selective prewarm and global SFX-bus
projections, primary player cache, and the three extra players that complete
the four-player AK-47 rapid-fire pool. The existing exceptions are deliberate:
`weapon_change` stays out of the global SFX list, `net_constrict` stays out of
prewarm, and the extra AK-47 layers remain a tail projection. The focused owner
must not choose playback pitch/fallbacks, advance the pool cursor, or mutate
shared stream loop flags.

`game_audio.gd` retains the established `commando_*_sfx` compatibility
properties, public play/stop/sync methods, authored pitch and fallback policy,
the AK-47 rotation cursor, and shared-stream-safe loop enabling for the supply
aircraft, fire-support aircraft, and suicide drone. Despite its historical
name, `supply_radio_loop` is a naturally ending one-shot and must never be
passed to `_enable_loop`; `gameplay_loop_audio_cleanup.gd` still force-stops it
and the three true loops at score/serve/reset boundaries. Do not restore cue
path/gain constants or direct Commando player creation in the facade.
Regression guard: `game_audio_commando_skill_audio_owner_smoke.gd`, the
Commando firearm routing/resolver/dispatcher smokes, supply-drop cleanup,
global loop cleanup, volume settings, and shared-stream loop-bleed smoke.

### Stage 2 battle-cue audio boundary

`stage2_battle_audio.gd` owns Hydro, stonebreak, rock hit/spawn, Quake, boss
cry, and speed-defense start/hit/block specs, their stable eager creation
order, ordered stage prewarm projection, and player cache. Its nine players
remain after shared Stage 1/star feedback and before Stage 3 in setup, prewarm,
and the global SFX list. The owner must not mutate stream loop flags, choose
pitch, or own event timing.

`game_audio.gd` retains the established `stage2_*_sfx` compatibility
properties, eight one-shot public methods and pitch ranges, all three
size-banded stonebreak pitch branches, Quake play/stop/sync, and
`_enable_loop(stage2_quake_sfx)`. `_enable_loop` must continue duplicating the
path-cached WAV before enabling its loop flag. `stage2_audio_router.gd` keeps
actual water/rock/boss/Quake trigger routing, while
`gameplay_loop_audio_cleanup.gd` and the Stage 2 round lifecycle retain hard
stops across score/serve/reset boundaries. Do not restore cue path constants,
direct player creation, or loop mutation in the focused owner. Regression
guard: `game_audio_stage2_battle_audio_owner_smoke.gd`,
`stage2_audio_router_smoke.gd`, `stage2_quake_round_boundary_lifecycle_smoke.gd`,
`stage2_speed_defense_smoke.gd`, `gameplay_loop_audio_cleanup_smoke.gd`, and
`game_audio_volume_settings_smoke.gd`.

### Stage 2 rustle orchestration boundary

`stage2_rustle_state.gd` remains the single retained owner for bush / vine
collections, layout size, independent boss / player previous-center samples,
first-sample validity, proximity mutation, decay, and active checks.
`stage2_rustle_coordinator.gd` owns context interpretation: Stage 2 gating,
layout assurance, paddle-center projection, movement threshold, boss velocity
and player dash overrides, boss bush then vine routing, player bush-only
routing, and final same-frame decay. Non-Stage-2 updates intentionally neither
sample nor decay this retained state.

`stage2_pillar_background.gd` keeps the established update position, snapshot /
renderer projection, and compatibility methods. Side-wall bush-band decisions
remain in `stage2_wall_reaction_coordinator.gd`; do not route player paddle
motion into the boss-vine lane. Regression guard:
`stage2_rustle_coordinator_smoke.gd`, `stage2_rustle_state_smoke.gd`, the Stage 2
router / wall-reaction / ambient smokes, and pillar / center-playfield draw and
render-budget smokes.

### Stage 2 rock interaction boundary

`stage2_rock_interaction_coordinator.gd` owns the four Stage 2 rock-contact
algorithms: swept ball collision / reflection, blade overlap, explosion-radius
overlap, and pistol rectangle-or-swept ricochet. It preserves Stage 2 and
landed-rock gates, ball scene writes before feedback, reverse traversal when a
response may remove rocks, one-hit blade / explosion HP preparation, visual-
radius fallback, and the existing two-bounce pistol consume contract. Pistol
side and payload math remains delegated to `stage2_pistol_rock_bounce_state.gd`.

`stage2_pillar_background.gd` retains the four public compatibility methods and
routes unbound callbacks to `stage2_rock_feedback_coordinator.gd`; do not add a
per-physics `Callable.bind()` allocation. The interaction owner must not absorb
HP decrement, collection removal, rewards, RNG payload creation, shake, VFX,
or audio. Regression guard: `stage2_rock_interaction_coordinator_smoke.gd`,
`stage2_router_smoke.gd`, `stage2_explosion_rock_collision_smoke.gd`,
`stage2_pistol_rock_bounce_state_smoke.gd`,
`stage2_viper_blade_rock_collision_smoke.gd`, and
`stage2_golden_rock_starpoint_smoke.gd`.

### Stage 2 quake orchestration boundary

`stage2_quake_runtime_state.gd` remains the single mutable owner for ordinary
and rage quake timing, repeat cooldown, ball-affecting state, first-write
velocity backup / restore, launch-guard timer, motion RNGs, and the loop-audio
latch. `stage2_quake_coordinator.gd` owns ordinary quake activation and cross-
domain execution: cache the current audio handle, cap new rocks against the
shared eight-rock collection, delegate their construction, schedule the delayed
water cannon only when rocks exist, then publish the warning and loop audio. A
zero-rock request must not reach the spawn factory, whose compatibility clamp
would otherwise manufacture one rock.

The coordinator also owns active timing -> fixed shake -> loop sync order,
cooldown eligibility, ball scene perturbation / speed caps / restore, boss-
launch guard, home-band top-goal backstop, and round cleanup -> loop stop. It
delegates rock construction to `stage2_rock_lifecycle_coordinator.gd` and quake
audio to `stage2_boss_rage_coordinator.gd`, which retains the serve-wait audio
fallback. `stage2_pillar_background.gd` keeps frame-loop position, renderer
projection, retained-state compatibility properties, and thin public facades.
Regression guard: `stage2_quake_coordinator_smoke.gd`, the retained-state and
ball-motion smokes, `stage2_router_smoke.gd`, the round-boundary / audio / rock-
lifecycle / spawn-factory smokes, and the boss-skill-pause smoke.

### Stage 2 boss-rage orchestration boundary

`stage2_boss_rage_state.gd` remains the single mutable owner for crisis
reservation, pending / active lifecycle, stomp windows, final latch, timer,
actor offset, and tint. `stage2_boss_rage_coordinator.gd` owns the cross-domain
execution around those events: pre-rally audio fallback retention, start
warning / shake, per-step cry-before-shake, and the final quake activation ->
crisis wall -> warning -> quake audio -> cry -> shake sequence. It also owns
quake-loop play / stop / sync against the cached fallback, because serve-wait
effect deps intentionally carry `audio = null` after rage activation.

`stage2_pillar_background.gd` keeps the production frame position, public
start / crisis-wall compatibility facades, renderer and snapshot projection,
and ordinary quake compatibility facades delegated to the quake coordinator.
The rage final stomp intentionally activates a visual-only quake directly in
its own ordered sequence. Do not move crisis rock construction into the rage
coordinator: it delegates the count and event timing to
`stage2_rock_lifecycle_coordinator.gd`, which remains authoritative for water-
cannon cancellation, retained insertion, leaf feedback, skill defer, and spawn
audio. Regression guard: `stage2_boss_rage_coordinator_smoke.gd`,
`stage2_boss_rage_state_smoke.gd`, `stage2_router_smoke.gd`,
`stage2_audio_router_smoke.gd`, the crisis-wall and rock-lifecycle smokes, and
the Stage 2 round-boundary / draw / render-budget smokes.

### Stage 2 rock lifecycle boundary

`stage2_rock_lifecycle_coordinator.gd` owns quake and crisis-wall rock
generation around the existing payload factories: shared-RNG consumption,
target-ordered spawn leaf bursts, retained insertion / id advancement,
water-cannon cancellation and post-spawn skill deferral, and spawn audio. It
also owns finite rock-life expiry plus quake drop / landing mutation and leaf
feedback. Preserve the crisis sequence of water reset, cannon cancel, delay
disable, rock creation, skill defer, then audio; changing it can re-arm a
cancelled cast or publish feedback before the skill state is consistent.

`stage2_rock_frame_coordinator.gd` consumes this owner from the production
frame position; the pillar background keeps rendering, collision / reward
entry points, and public compatibility facades. Do not merge generation into
the frame coordinator: lifecycle generation, shared-RNG payload construction,
and crisis cancellation order remain independently sealed. Regression guard:
`stage2_rock_lifecycle_coordinator_smoke.gd`, the three quake / crisis spawn-
factory smokes, `stage2_quake_rock_drop_state_smoke.gd`,
`stage2_rock_runtime_state_smoke.gd`, `stage2_chaos_rock_absorb_state_smoke.gd`,
and `stage2_audio_router_smoke.gd`.

### Stage 2 rock frame orchestration boundary

`stage2_rock_frame_coordinator.gd` owns the reverse per-frame traversal of the
retained rock array. Preserve its branch order: base lifetime / expiry first;
expired Chaos-session flag clearing second; active Chaos pull and destruction
third; ordinary visual timers, quake drop, and quake offset last. Removal stays
inside reverse traversal, and retained fragment motion runs after every rock.

For absorbed destruction, preserve fragment / leaf / golden-starpoint / break-
audio feedback before queueing the absorbed result and before removing the rock.
The coordinator delegates actual lifetime / drop policy to the lifecycle owner,
pull math and result payloads to the Chaos owner, and presentation to the rock-
feedback owner. `stage2_pillar_background.gd` keeps the established frame
position plus thin compatibility methods; it must not restore a second rock
loop. Regression guard: `stage2_rock_frame_coordinator_smoke.gd`, lifecycle,
Chaos state / coordinator, fragment-motion, quake drop / offset, retained-rock,
router, pillar draw / budget, and Chaos Spear smokes.

### Stage 2 Chaos rock absorption boundary

`stage2_chaos_rock_absorb_coordinator.gd` consumes the retained
`stage2_chaos_rock_absorb_state.gd` and owns session advancement, refresh-time
landed-rock activation, parity-stable spin direction, water-target-flash
clearing, immediate water-splash compaction / payload creation, and whole-
frame plus fractional-frame pull stepping. Motion reports destruction but does
not publish the absorbed-rock result by itself.

`stage2_pillar_background.gd` keeps the public Chaos Spear facade; the rock-
frame coordinator owns the cross-domain destruction handoff. Preserve fragment
and leaf emission, golden starpoint callback, break audio, then absorbed-result
publication in that order; publishing first exposes a completed absorption
before its gameplay feedback has run. Regression guard:
`stage2_chaos_rock_absorb_coordinator_smoke.gd`,
`stage2_chaos_rock_absorb_state_smoke.gd`,
`stage2_chaos_absorb_payload_factory_smoke.gd`,
`chaos_spear_stage2_rock_absorb_smoke.gd`,
`stage2_golden_rock_starpoint_smoke.gd`, and
`stage2_water_visual_state_smoke.gd`.

### Stage 2 starpoint retained-state boundary

`stage2_starpoint_runtime_state.gd` is the single retained owner of the live
Stage 2 starpoint drop and pickup-particle arrays. It owns atomic clear with a
prior-state result, runtime-state queries, append operations, drop counts, and
deep drop snapshots. `stage2_pillar_background.gd` exposes compatibility
properties but must not restore parallel arrays.

`stage2_starpoint_coordinator.gd` borrows the shared Stage 2 RNG and owns primary
drop then particle then Star Detector bonus construction, playfield clamping,
motion, Dowsing attraction, Starlight Tracking delivery, player overlap,
modal-safe in-place compaction, reward / particle / audio / redraw side effects,
particle motion, and stage-exit retained-state clear before detached-host hide.
Construction/configuration must not consume the RNG. `stage2_pillar_background.gd`
keeps update position, rendering, and thin public / compatibility facades.
Regression guard: `stage2_starpoint_coordinator_smoke.gd`,
`stage2_starpoint_runtime_state_smoke.gd`,
`stage2_golden_rock_starpoint_smoke.gd`, the shared payload / bonus / motion /
overlap / Dowsing / reward / compaction smokes, the Lingpet runtime smoke, and
the Stage 2 pillar draw / render-budget smokes.

### Stage 2 water-cannon runtime boundary

`stage2_water_cannon_coordinator.gd` borrows the shared Stage 2 RNG and owns
random rock selection, live muzzle / target tracking, target-flash mutation,
idle-delay activation, charge-to-fire feedback, trail payload timing, visual-
state advancement, and ordered fragment resolver-to-applier fanout. Its
configuration must not consume RNG. Preserve the firing-edge sequence of
warning then hydro audio then immediate return; emitting a trail on that same
edge changes both visuals and the shared RNG stream. On later firing frames,
append the trail before publishing completion.

`stage2_pillar_background.gd` keeps the established frame-loop positions,
renderer handoff, public compatibility facades, and completion-only binding of
the starpoint reward callback. It calls the coordinator's impact handoff only
after a completed frame has appended its trail, avoiding a bound `Callable`
allocation on ordinary active frames. Completed impact side effects remain in
`stage2_water_cannon_impact_coordinator.gd`; retained phase / beam values remain
in `stage2_water_cannon_runtime_state.gd`. Regression guard:
`stage2_water_cannon_coordinator_smoke.gd`, the retained-state / impact /
interrupt / fragment resolver / player-hit / water-visual smokes, and the Stage
2 geometry, audio, router, golden-reward, and rock-lifecycle smokes.

### Stage 2 monkey-banana event / renderer boundary

`stage2_monkey_banana_event.gd` owns first/repeat spawn clocks, left/right tree-
path traversal, sit/throw/release/leave transitions, target and burst RNG,
banana flight/landing/burst simulation, player/boss collision and slip policy,
audio, AI context, payload-factory calls, layout mapping, and reset/debug/public
facades. It derives gameplay launch geometry through renderer-owned stable frame/
size projections and lends the live monkey and banana arrays without copying.

`stage2_monkey_banana_renderer.gd` owns staged climb/throw/banana/tree-resource
prewarm, texture-image decompression during loading, left/right alpha-median
tree-path caches, deterministic sheet-frame/UV-flip projection, letterbox-aware
banana culling, procedural fallbacks, landed shadow/body order, and burst drawing.
It receives explicit layout/scale/shake and owns no spawn clocks, targeting,
collision, slip, audio, simulation, payload mutation, RNG, or retained borrowed
array. Do not restore texture/Image/CanvasItem ownership to the event, perform
image scans on first spawn, copy or retain live arrays, crop the letterbox launch
band, or reorder burst priority and landed shadow -> banana passes. Regression
guard: `stage2_monkey_banana_renderer_smoke.gd`, the existing event/payload/
router/dependency/AI/prewarm suites, deterministic frame/cull projection, the
windowed Vulkan pillar/playfield composite, and the layer-order reverse mutation.

### Stage 3 Menhera/Kuromi battle-cue audio boundary

`stage3_battle_audio.gd` owns Tail, Psychoball, Doll Curse, Tears, chest land,
curse explosion, Kuromi awake/stonebreak/tongue/swallow/spit specs, their
stable eager player-creation order, ordered stage prewarm projection, and
player cache. Kuromi stonebreak retains the existing optional-player factory
route; the other ten cues use the standard factory. The owner must not mutate
stream loop flags or choose playback timing. Its players remain between the
Stage 2 cue group and Guardian Spirit stage cues in setup, prewarm, and the
global SFX list.

`game_audio.gd` retains the established `stage3_*_sfx` compatibility
properties, ten one-shot public methods and pitch ranges, Psychoball
play/stop/sync, and `_enable_loop(stage3_psychoball_sfx)`. `_enable_loop` must
continue duplicating the path-cached WAV before enabling its loop flag.
`gameplay_loop_audio_cleanup.gd` retains `stop_stage3_psychoball_loop` for
score/serve/reset boundaries. Bomb Surprise's self-explosion keeps a separate
semantic constant for its intentional reuse of `weakexplosion.wav`; it must
not reach through the Stage 3 catalog. Do not restore Stage 3 path constants,
direct player creation, or loop mutation in the focused owner. Regression
guard: `game_audio_stage3_battle_audio_owner_smoke.gd`,
`stage3_map_port_smoke.gd`, `stage3_psychoball_parity_smoke.gd`,
`stage3_psychoball_state_smoke.gd`, `gameplay_loop_audio_cleanup_smoke.gd`,
and `game_audio_volume_settings_smoke.gd`.

### Stage 4 Ponk battle-cue audio boundary

`stage4_ponk_audio.gd` owns moon shoot, fragment shoot, temple hit, bird kill,
magnetic, meditation, and meditation-after specs, their stable eager creation
order, ordered stage prewarm projection, and player cache. The owner must not
mutate stream loop flags or decide playback timing. Its seven players remain
between the Lingpet stage projection and Hongryun in setup, prewarm, and the
global SFX list.

`game_audio.gd` retains the established `stage4_*_sfx` compatibility
properties, six one-shot public methods and pitch ranges, magnetic
play/stop/sync, and `_enable_loop(stage4_magnetic_sfx)`. `_enable_loop` must
continue duplicating the path-cached WAV before enabling its loop flag so the
shared cached source remains non-looping. `gameplay_loop_audio_cleanup.gd`
retains `stop_stage4_magnetic_loop`, and the Stage 4 runtime/ball cleanup paths
retain their explicit stop calls. Do not move loop mutation into the catalog
owner or remove score/serve/reset cleanup. Regression guard:
`game_audio_stage4_ponk_audio_owner_smoke.gd`, `stage4_map_port_smoke.gd`,
`stage4_ponk_round_boundary_lifecycle_smoke.gd`,
`gameplay_loop_audio_cleanup_smoke.gd`, and
`game_audio_volume_settings_smoke.gd`.

### Stage 5 Hongryun battle-cue audio boundary

`stage5_hongryun_audio.gd` owns the fireball, charge, and inferno-shoot cue
specs plus the three-stream hurt pool. It preserves two distinct lifecycle
positions: primary players are created after Stage 4 and before Stage 6, while
hurt players are created after Stage 7 Akamu and before leaf-shield feedback.
Primary prewarm remains before Akamu; hurt prewarm remains after both Mika
cut-in voice pools at the tail of the stage phase. The global SFX list likewise
keeps primary players in stage order and the hurt pool after layered players.

`game_audio.gd` retains the established `stage5_hongryun_*_sfx` compatibility
properties, public play/stop methods, per-cue pitch ranges, and random
valid-stream hurt selection. Stage 5 state and fire-machine owners retain
fireball volley, inferno charge/release, and collision-hurt timing. Do not
collapse the split owner phases, restore path constants/direct creation, or
move the hurt pool earlier merely because all six assets share one catalog.
Regression guard: `game_audio_stage5_hongryun_audio_owner_smoke.gd`,
`stage5_hongryun_mvp_runtime_smoke.gd`, and
`game_audio_volume_settings_smoke.gd`.

### Stage 6 Tetriser battle-cue audio boundary

`stage6_tetriser_audio.gd` owns the break, wall, super-roar, big-impact,
Crystal Shield, and laser one-shot specs, their stable eager player-creation
order, and player cache. The six cues are created between Hongryun primary and
Akamu players and remain in that position in the global SFX list. Unlike the
neighboring Stage 5 and Stage 7 catalogs, these paths were not present in the
stage prewarm list; this refactor preserves that policy instead of silently
changing battle-loading behavior. All six streams remain non-looping.

`game_audio.gd` retains the established `stage6_tetriser_*_sfx` compatibility
properties, six public playback methods, and their exact pitch ranges. The
Stage 6 combat-feedback owner retains the fixed break/wall/super/big/shield/
laser order, per-frame deduplication, and event flush timing. Do not restore
path constants/direct creation, add these cues to prewarm as part of a
refactor-only change, or route them through loop cleanup. Regression guard:
`game_audio_stage6_tetriser_audio_owner_smoke.gd`,
`stage6_tetriser_combat_feedback_state_smoke.gd`,
`stage6_tetriser_state_smoke.gd`, and `game_audio_volume_settings_smoke.gd`.

### Stage 7 Akamu battle-cue audio boundary

`stage7_akamu_audio.gd` owns the six Akamu one-shot cue specs, their stable
eager player-creation order, ordered stage-phase prewarm projection, and player
cache. The catalog order is shuriken shoot, shuriken hit, cloud landing, wind
aura block, clone spawn, then clone out. All six retain native `0 dB` gain and
must remain non-looping. The owner does not choose playback pitch or trigger
timing.

`game_audio.gd` retains the established `stage7_akamu_*_sfx` properties as
compatibility facades, the six public `play_stage7_akamu_*` methods, and their
existing pitch policies. Stage 7 state owners retain event timing: shuriken
release/contact, cloud landing, every committed aura block, clone cast commit,
and each natural/collision clone exit. Do not restore the six path constants,
direct player creation, or inline prewarm/SFX-bus enumeration in the facade.
Regression guard: `game_audio_stage7_akamu_audio_owner_smoke.gd`,
`stage7_akamu_audio_smoke.gd`, and `game_audio_volume_settings_smoke.gd`.

### Angel Dice runtime boundary

The live Angel Dice mythic perk keeps its logical foundation in
`runtime_perk_angel_blessing_state.gd`; it owns the canonical six-buff roll,
stage dedupe, active result, and HUD-facing multiplier snapshot.
`runtime_perk_angel_blessing_cooldown_capability.gd` owns the character-neutral
`active_cooldown` candidate gate. It fails closed unless the skill config
explicitly declares a non-empty live skill-id list, exposes cooldown plus
runtime/item multiplier APIs, and the state exposes configured trigger,
remaining-ratio, and stored-total APIs. Structural eligibility does not depend
on the current effective multiplier, so a legal zero multiplier cannot erase a
still-live skill family. This
currently leaves Optimus and the Hammer-Shock-less Blacksmith on five candidates;
do not map Angel to Thor Shield debounce or expose Blacksmith merely because its
compatibility state inherits the generic timer shell. The Blacksmith compatibility
config may receive runtime/item multiplier inputs, but remains explicitly
ineligible until its actual release/timer/projectile/HUD contract is ported.
`runtime_perk_angel_blessing_projection.gd` owns pure six-lane numeric
composition, while `runtime_perk_effective_stat_query_surface.gd` is the only
runtime-perk stat query integration seam. Maximum gauge uses the bespoke
`get_angel_blessing_special_gauge_max` final-value facade: do not add a generic
`get_special_gauge_max` runtime-perk method, because TAB starts from the
already-synced owner maximum and would multiply the blessing twice.
`runtime_perk_angel_blessing_gauge_compositor.gd` owns cause-aware owner gauge
math: raw Fuel changes preserve the rounded fill ratio, Angel changes preserve
the absolute current value, and the final result clamps after both causes.
`mythic_item_owner_syncer.gd` is the single maximum-gauge writer and keeps raw
maximum plus Angel multiplier caches separate. Optimus consumes the effective
owner/config maximum throughout its energy path. Its per-physics energy and
manual-charge snapshots publish only the gauge-derived runtime paddle base;
`active_item_paddle_sync.gd` remains the final size compositor for runtime
perk, active-item, and mythic scales, and the active-item update gate refreshes
that composition whenever any mirrored input changes. Junior League's 1.5x
geometry scale stays in the Optimus base lane from bootstrap through config and
controller updates, while direct runtime character switches perform one
immediate shared-compositor sync after base preparation. Horn Strawberry's
speed 8 is a replacement base applied before the shared multiplier chain in
`battle_scene_player_control_config_builder.gd`; the character controllers
suppress their incompatible post-config speed modifiers, while zero-speed hard
locks remain authoritative. Transform skill locks cancel stale Blacksmith shield
and Smasher wheel state without replenishing their resources. TAB consumes the
same weather/status speed sources as player control. Blacksmith cooldown
capability is now evidence-gated while Hammer Shock gameplay remains unported.
`runtime_perk_angel_blessing_stage_lifecycle.gd` owns campaign-context gating,
normalized character capability selection, and successful-roll-only consumer
resynchronization. The authoritative trigger is the existing residual-overlay
completion in `stage_ball_spawn_intro_finish_lifecycle.gd`: deferred Dimension
Gate/full-gauge actions resolve first, then Angel rolls once per positive
non-tutorial campaign stage. Rally restarts retain the active result, the next
stage replaces it atomically, and full reset clears both result and stage history.
`runtime_perk_angel_blessing_acquisition_lifecycle.gd` now owns accepted raw
`0 -> 1` route classification: battle grants reserve the actual current stage,
while stage-result direct/choice grants reserve the next valid campaign intro
without guessing `stage + 1`. `runtime_perk_angel_blessing_modal_flow.gd` owns
the deduplicated current-stage/next-intro queues, acquisition-cinematic wait,
pending reveals, the three-second logical modal, input arming, and boundary
reset policy. `runtime_perk_angel_blessing_runtime_state.gd` orchestrates the
Angel-specific update/input, blockers, current-stage roll/reveal, cinematic
completion, deferred-choice resume/finalize order, shared cooldown/owner-sync
handoffs, audio, and boundary cleanup. `runtime_perk_state.gd` retains the
cross-feature spawn-intro order and the shared callback implementations. The
Angel owner must never reuse the whole intro callback for a mid-stage acquisition
because that would flush unrelated deferred Dimension Gate/full-gauge work. The
shared mythic acquisition runtime reports
only a natural active-to-inactive update edge, and the battle frame rechecks the
live runtime-perk modal after mythic update so no gameplay tick leaks through.
Round/stage cleanup does not forge that natural notification; its Angel queue
boundary explicitly releases only the preserved reservation whose predecessor
cinematic was canceled, while scoreboard/result/shared modal blockers keep it
from opening underneath a higher-priority surface.
`runtime_perk_catalog.gd`, `perk_conversion_values.gd`, and
`mythic_perk_grant_helper.gd` own the public thirteenth converted-mythic
identity, fixed 30% value, jackpot/debug exposure, guaranteed-mythic choice,
and shared acquisition-cinematic payload. `runtime_perk_debug_grants.gd`
short-circuits an unchanged mythic target so an already-owned Angel grant
cannot replay the acquisition cinematic or create new lifecycle work.
`language_settings_data.gd` owns the static Korean-plus-six-locale catalog
name/summary, while `runtime_perk_angel_blessing_localization.gd` owns the
seven-locale dynamic modal, buff, and current-status copy.

Presentation is detached from logical visibility. `runtime_perk_icon_renderer.gd`
owns the static and animated perk art; `angel_blessing_roll_overlay_host.gd`
and `angel_blessing_halo.gdshader` own the clipped 760x750 modular modal and
non-blocking absorption tail. `game_audio.gd` owns the roll one-shot and
three-voice absorption pool. The overlay controller only syncs snapshots,
`battle_pso_prewarmer.gd` and the staged boot prewarm own first-use GPU/resource
preparation, and round/stage/full-reset owners directly hide the detached host
and stop Angel audio even when the normal draw fanout is no longer active.

### Runtime perk fusion state boundary

`runtime_perk_fusion_runtime_state.gd` is the feature-state owner for the
perk-fusion core record state, byproduct transient state, and offer-planner
lifetime. It owns commit/restore/query delegation, catalog-aware limit-break
result context, fail-closed offer planning, production offer injection,
byproduct speed/gold/point-loss calculations, round/full-reset behavior, modal
flow/input/catalog lifetime, candidate construction, and the full S0-S4 modal
transaction. The offer injection owner performs source/candidate/lane
eligibility before consuming gameplay RNG or its deterministic one-shot seam,
and writes an appeared replacement back to runtime choices. The catalog
resolved at modal start remains authoritative through preview and S2 commit;
the owner performs result RNG/build, core commit, common-choice-finish handoff,
preview-cache boundary resets, and direct cold-boot host shutdown. Missing
runtime/common-finish dependencies must fail closed before S2 commit.
`perk_fusion_reverb_vfx_state.gd` is the focused presentation owner for
Reverb's activation flash, capped movement echoes, active wind seal, player
sampling, and visual cleanup. `perk_fusion_byproduct_runtime.gd` triggers and
advances it from the canonical three-second Reverb clock; the shared byproduct
draw fanout renders it after the player actor, while
`battle_scene_runtime_perk_update_driver.gd` requests coalesced battle redraws
through the scene owner for every visible tick.
`runtime_perk_state.gd` remains the public facade and keeps the open-flow
callback position that enforces fusion-before-training order, modal priority,
snapshot/preview presentation composition, the common choice finish
implementation, and the final global gold counter write. Its computed modal
flow/input/catalog and deterministic-offer-seam properties are compatibility
seams, not parallel storage. Keep the match-finished point-loss branch free of `randf()`
evaluation: it only discards pending effects and must not shift later gameplay
RNG. Display catalog/projector lifetime, composite fusion-plus-Dice projection,
live option values, modal preview caching, and display-cache invalidation belong
to `runtime_perk_display_projection_state.gd`, not either gameplay-state owner.
Regression guards: `runtime_perk_fusion_runtime_state_refactor_smoke.gd` and
`runtime_perk_display_projection_state_refactor_smoke.gd`.

### Mystic Dice feature-state boundary

`runtime_perk_mystic_dice_runtime_state.gd` owns Mystic Dice permanent raw and
use-count state, the seven-stat roller, offer-planner lifetime, lazy modal
flow/input, and the detached paddle-effect state/host binding. It owns D0 modal
start, RT-entry latch setup, input/action routing, rerolls, accepted raw commit,
ordinary/mythic consumer synchronization, common choice-finish handoff, and the
pending handoff to the first resumed gameplay physics tick. That tick starts the
full three-second effect without subtracting modal-blocked time.
`runtime_perk_state.gd` keeps the production interception position after fusion
offer postprocessing, modal update/input priority, public APIs, and the common
choice-finish implementation. Finish dependency preflight must complete before
raw commit; missing runtime, owner-sync, or common-finish seams fail closed so
the permanent roll cannot be consumed by a partial transaction. The legacy `_mystic_dice_offer_planner`,
`_mystic_dice_paddle_effect_pending`, `_mystic_dice_modal_flow`, and
`_mystic_dice_modal_input` seams are computed properties backed by the feature
owner, never second storage locations. Round/stage/full reset must continue to
call the public clear/reset facades so detached hosts, modal latches, and pending
starts cannot survive lifecycle boundaries. Regression guard:
`runtime_perk_mystic_dice_runtime_state_refactor_smoke.gd`.

### Angel Blessing feature-state boundary

`runtime_perk_angel_blessing_runtime_state.gd` owns the core blessing state,
character cooldown-capability selector, stage lifecycle, modal flow, and
acquisition lifecycle. It exposes the shared perk/policy vocabulary and owns
core roll/query, capability, stage-intro, accepted-choice,
acquisition-cinematic-finished, and core-reset delegation. It also owns the
complete acquisition transaction: snapshot/work queries, per-frame update and
input routing, higher-priority blocker ordering, current-stage roll/reveal,
cinematic-wait release, deferred-choice resume/finalization, Angel audio
handoff, and round/stage cleanup. In particular, scoreboard release must reopen
a banked ordinary runtime choice before starting a ready Angel reveal. The
public `runtime_perk_state.gd` facade retains cross-feature spawn-intro ordering,
public API/input priority, and the shared choice/cooldown/owner-sync callback
implementations invoked by the owner. Because reset/effective-stat/acquisition helpers use
`RuntimePerkRuntimeStateAccess`, `_angel_blessing_state` and
`_angel_blessing_modal_flow` remain computed owner-backed properties; they are
compatibility lookup seams, never independent storage. Regression guard:
`runtime_perk_angel_blessing_runtime_state_refactor_smoke.gd`.

### Runtime perk choice-pipeline lifetime boundary

`runtime_perk_choice_pipeline_state.gd` owns construction and stable lifetime
for the nine common choice helpers: selection, completion, dispatch, action
runner, standard path, open flow, apply flow, confirm flow, and finish flow.
It does not absorb live perk fields or general cross-feature transaction
ordering. The owner-held finish flow is the narrow exception: it owns the last
committed Mystic Dice/Fusion revisions and rejects duplicate D3/S4 finish calls
before common choice state, next-choice generation, Megingjord/Dowsing, or
close/ramp callbacks can be consumed twice.
`runtime_perk_state.gd` remains the public orchestration facade and keeps the
established `_choice_*` call sites. Those names are writable computed
properties backed by the pipeline owner because production flow helpers use
`RuntimePerkRuntimeStateAccess` string lookup and focused tests replace helpers
through direct assignment or `Object.set()`. Source-contract type aliases may
remain on the facade, but constructors and mutable helper storage belong only
to the owner. Regression guard:
`runtime_perk_choice_pipeline_state_refactor_smoke.gd`.

### Runtime perk unlock-pipeline lifetime boundary

`runtime_perk_unlock_pipeline_state.gd` owns construction and stable lifetime
for active-unlock flight, the unlock-showcase controller and flow, unlock-swap
layout and flow, and unlock-choice application. The live
`choice_flight_effect`, `unlock_showcase`, and pending-swap payloads remain on
`runtime_perk_state.gd`, as do public input/update/reset wrappers and transaction
ordering. The established helper names remain writable computed owner-backed
properties because reset, confirm/open/showcase helpers use runtime-state string
lookup and focused tests replace flight/showcase helpers directly. Source type
aliases may remain on the facade for constants and source contracts; helper
construction and mutable storage belong only to the owner. Regression guard:
`runtime_perk_unlock_pipeline_state_refactor_smoke.gd`.

### Mythic acquisition cinematic boundary

`mythic_item_acquisition_cinematic_v2.gd` is the orchestration host. It owns
public prewarm/reset/trigger/input/snapshot APIs, localization, item-texture
loading, audio side effects, viewport placement, particle lifecycle cleanup,
and applying projected values to live nodes. It must not regain fixed node
constructors, phase-clock transitions, procedural rasterization, sparse-beam
geometry, overlay geometry, or reveal-layout formulas.

- `mythic_item_acquisition_timeline_state.gd` owns phase clocks, click arming,
  one-shot absorption, delayed after-cue stop, cancellation, and natural
  completion events.
- `mythic_item_acquisition_presentation_factory.gd` owns the fixed 13-node
  presentation manifest, shader/material recipes, particle recipes, and reveal
  text controls.
- `mythic_item_acquisition_visual_envelope.gd` owns allocation-free phase
  scalar projection; it returns no per-frame dictionaries.
- `mythic_item_acquisition_light_beam_state.gd` and
  `mythic_item_acquisition_light_beam_renderer.gd` split seeded sparse-beam
  lifetime from exact geometry. Every live sparse beam renders; index-stride
  culling is forbidden.
- `mythic_item_acquisition_overlay_renderer.gd` owns overscan, white-out, and
  paddle-impact geometry. Lazy texture resolution and draw ordering remain in
  the host.
- `mythic_item_acquisition_reveal_presenter.gd` owns deterministic icon-frame,
  fit, and reveal-text layout math using injected time. Localization and
  resource loading remain in the host.
- The icon backdrop, vignette, and white-flash rasters ship as lossless baked
  PNGs. `tools/bake_mythic_acquisition_raster_textures.gd` owns offline pixel
  generation; runtime code must not recreate `Image` buffers or upload new
  `ImageTexture` objects.

### Pause menu overlay boundary

`pause_menu_overlay.gd` remains the public orchestration and compatibility
surface. It owns input-command side effects, pointer-hover orchestration,
localized option-render snapshot projection, localization refresh,
selection-feedback triggers/advancement, display transaction triggers, and
public helper APIs used by the battle overlay controller and smoke fixtures. Its
public state properties proxy focused owners rather than duplicating mutable
values.

- `pause_menu_session_state.gd` owns activation/options modes, opening and dial
  clocks, selected main entry, and slider-drag lifetime.
- `pause_menu_options_navigation_policy.gd` owns tab/device order, focus counts,
  wrapping/clamping, and selection-feedback scopes;
  `pause_menu_options_navigation_state.gd` owns the live tab/focus/device tuple.
- `pause_menu_input_command_router.gd` owns pressed/echo gating and all
  keyboard/gamepad event-to-command interpretation for main, sound, display,
  controls, and language scopes. It is side-effect free: the facade executes
  commands so audio, state transitions, and external settings calls remain at
  the orchestration boundary.
- `pause_menu_pointer_command_router.gd` owns mouse press/release, right-click,
  main-row, tab, slider drag, display, controls, and language hit-to-command
  interpretation. It consumes `pause_menu_overlay_layout.gd` plus the rendered
  select-chevron geometry and remains side-effect free; hover animation updates
  and command execution remain in the facade.
- `pause_menu_audio_controller.gd` owns `game_audio` discovery, UI move/confirm/
  back cue dispatch, BGM/SFX fallback reads, clamped writes, focused adjustment,
  and slider-rect value projection. The facade retains compatibility wrappers
  and decides when each audio operation occurs.
- `pause_menu_content_catalog.gd` owns stable main action identifiers,
  localized main entries, options back/close labels, and the exact tab/device/
  focus-to-readout-description mapping. The facade retains `_text`, `_get_*`
  compatibility wrappers and assembles the final options render snapshot.
- `pause_menu_controls_settings_controller.gd` owns saved vibration sync,
  clamped adjustment/persistence, default restoration, localized vibration
  labels, and keyboard/joypad mapping-row projection. Device selection and
  focus clamping remain in `pause_menu_options_navigation_state.gd`; the
  facade retains compatibility properties and wrappers.
- `pause_menu_language_settings_controller.gd` owns saved-language sync,
  canonical language ordering/focus mapping, cycle/wrap selection, persistence,
  native-name projection, and owner text-refresh notification. The pointer
  router reuses its canonical focus mapping; the facade retains compatibility
  wrappers and localized render-snapshot assembly.
- `pause_menu_selection_feedback_state.gd` owns slide/pop clocks, from/to
  indices, hover de-duplication, and scalar animation projection;
  `pause_menu_selection_feedback_renderer.gd` owns main/options focus-rect
  routing, slide interpolation, pop scaling, flash panel, and focus-frame draw.
  The facade retains begin/reset/advance triggers and compatibility wrappers.
- `pause_menu_display_settings_state.gd` owns display-mode normalization and all
  local display preference transitions/baselines;
  `pause_menu_display_settings_controller.gd` owns `battle_view_layout`
  discovery, live display/FPS/VSync application, persistence, refresh-rate
  lookup, labels/recommendations, and the explicit 60 Hz fallback. The facade
  retains compatibility wrappers but must not regain those system calls.
- `pause_menu_main_renderer.gd` owns editorial main-surface asset prewarm,
  opening projections, compass/background geometry, selected-bar geometry, and
  main-entry text rendering. The host retains compatibility draw wrappers, but
  must not regain those rendering formulas.
- `pause_menu_overlay_layout.gd` owns all pure main/options geometry used by
  both drawing and hit testing. `pause_menu_overlay.gd` retains its public
  `_get_*` compatibility methods, but every geometry method delegates to the
  layout owner so input and presentation cannot drift onto separate formulas.
- `pause_menu_options_renderer.gd` owns the options palette, option-window and
  display/controls/language tab composition, plus pure header, tab/icon,
  slider, mode-pill, setting-row, toggle, button, readout, panel, neon-line,
  and focus-frame drawing. It consumes a facade-projected dictionary containing
  resolved labels and values and must not call registries or language/settings
  singletons. The facade keeps its established `_draw_*` compatibility methods
  plus feedback/readout layer ordering, but delegates presentation here.

### Display settings persistence boundary

`battle_view_layout.gd` owns OS/window application, settings paths, raw-byte
UTF-8 BOM cleanup, `ConfigFile` load/save, last-good backup recovery, runtime
FPS/VSync/physics-tick application, and diagnostic summaries.
`display_settings_config_codec.gd` owns the filesystem-independent payload
schema: defaults, missing-key completion, schema migration, graphics payload
copying, and display/FPS/VSync normalization. Keep filesystem APIs out of the
codec and keep schema transition formulas out of the layout host.

### Plaza save persistence boundary

`plaza_save_store.gd` owns the live plaza economy/progression state, user save
path, parent-directory creation, raw-byte/BOM parsing, corrupt-file rejection,
last-good backup recovery, save/load summaries, and transaction APIs.
`plaza_save_config_codec.gd` owns the filesystem-independent `ConfigFile`
payload schema, encode/decode, legacy schema version reads, quest/map/stage
section projection, and gold/AP/gem/decoder sanitization. The store may expose
compatibility facades, but must not duplicate field-by-field serialization.

### Plaza transaction-message boundary

`plaza_transaction_message_formatter.gd` owns facility-specific player-facing
success/failure messages and shop item-name localization for plaza transaction
summaries. `plaza_scene.gd` keeps the seven `_format_*_transaction_message`
methods only as compatibility facades; message branches and localization logic
must not be duplicated back into the scene shell.

### Plaza transition-state boundary

`plaza_transition_state.gd` is the single owner of building enter/return and
plaza warp arrival/exit phase, timer, target/actor snapshots, progress, and
fade/lift envelopes. `plaza_scene.gd` may orchestrate completed transitions,
FX-host synchronization, and the delayed plaza-exit callback, but must not keep
mirrored transition fields or duplicate their timing math.

### Plaza menu-session and transaction-summary boundary

`plaza_building_menu_session_state.gd` owns the open building identity,
title/subtitle/action list, last feedback message, and one-AP-per-visit state.
`plaza_transaction_summary_store.gd` owns deep-copied facility result summaries
and their menu-close/new-visit clearing policy. All seven transaction paths in
`plaza_scene.gd` must share `_apply_facility_transaction_outcome`; do not
restore per-facility summary fields or duplicate AP/message/save finalization.

### Plaza menu catalog and minimap boundary

`plaza_building_menu_catalog.gd` owns base menu title/subtitle/action specs and
NPC display names; runtime-dependent academy, Lingpet Store, and tavern actions
remain scene orchestration inputs to the menu session. `plaza_minimap_projection.gd`
owns world-to-track mapping, camera/player/exit/building marker projection, icon
separation, and facility colors. `plaza_minimap_renderer.gd` owns the complete
minimap draw recipe. Keep minimap geometry and emblem draw branches out of the
scene shell.

### Plaza actor and building rendering boundary

`plaza_actor_visual_projection.gd` owns player walk/facing/frame selection,
sheet/destination geometry, and Lingpet follow/frame projection.
`plaza_actor_renderer.gd` owns player/Lingpet texture selection, sprite drawing,
placeholder drawing, and contact shadows. `plaza_building_renderer.gd` owns
building world-rect fallback, viewport culling, deterministic flicker, baseline
shadow drawing, and the retained base/sign/window CanvasItem children with their
owned MIX/ADD materials. Its immediate `draw()` entrypoint is compatibility-only;
the production building path is owned by `plaza_map_world_host.gd`.
`plaza_scene.gd` supplies live state and keeps narrow compatibility facades; do
not restore actor/building draw recipes or their projection constants to the
scene shell.

### Plaza background rendering boundary

`plaza_background_projection.gd` owns parallax offsets, world-tile starts,
VR-strata block geometry, deterministic flicker, and smoothing math.
`plaza_background_renderer.gd` owns the full sky/far-sky fallback, cloud,
midground wall, ground strip, emissive decoration, underground, and exit-zone
draw recipe. The production call is made by `plaza_map_world_host.gd` from the
state supplied by `plaza_scene.gd`; do not restore background constants,
texture-world culling, or layer-specific draw methods to the scene shell.

### Plaza retained map-world host boundary

`plaza_scene.gd` owns attachment and orchestration of the production retained
world host. The outer map uses the loader-owned fixed `2400 x 1500` logical
world, while building interiors and trade UI retain their independent
`760 x 750` contract. On every controller-owned rendered frame, the scene
samples one `ticks_msec` value and synchronizes the host with
`render_size = plaza_scene.size`; engine viewport size is not a substitute.
The scene also fails the host closed through the actual interior-open,
plaza-exit, scene-handler free, and tree-exit routes.

The outer size is an intentional R1 compatibility promotion from the previous
`MAP_SIZE = 1900 x 750`, not a retained-renderer-only refactor. It moves the
exit from `Rect2(1750, 596, 120, 92)` to `Rect2(2250, 596, 120, 92)` and raises
the one-axis camera's right clamp from `1140` to `1640`. Existing
`stage_map_seeds[stage_id]` values and the seed/save schema are preserved, but
the legacy position applicator consumes world width, so a preserved seed gets
one intentional coordinate-layout shift at the update boundary. Thereafter the
fixed-width cache/input contract reproduces the same positions for the same
stage and seed. Building-type selection remains seed-derived and does not
consume world width. R1 still keeps `GROUND_Y = 666` and one-axis movement;
vertical traversal of the 1500-unit map world is not active.

The corresponding player-facing distance increase is accepted, not hidden as
an implementation detail. A real 60 Hz Vulkan run through the production
handler/update route with normal `ui_right` input first entered the new exit on
frame 533 (`8.883s`), versus the old x=1750 counterfactual on frame 408
(`6.800s`). The accepted delta is 125 frames / `2.083s` (about 30.64%); the
probe used no direct-position test hook and continued through the real 60-frame
exit warp callback.

R1 is a retained-ownership bridge, not the final map-fit projection. The live
outer scene still projects through its existing `GAME_SIZE = 760 x 750`
side-scroll fit; `map_safe_rect` fitting of the full `2400 x 1500` world belongs
to R2. At 2020 x 1246 this bridge displays the 360-unit bank at about 598px,
upscaling its 512px runtime texture by about 1.17x, so R1 sign-off requires a
real Vulkan sharpness review at that resolution.

`plaza_map_world_host.gd` owns the opaque map fill, background-renderer call,
retained building children, relative `z_index = -1`, and fail-closed retained
visibility. `plaza_asset_loader.gd` owns the active seven Hwangyeok manifests,
fixed map size, deterministic building specs, and resource state for the 21
retained layer textures. Production prewarm delegates directly from the scene
through the host and building renderer to that loader state. GPU readiness is
not inferred from resource cache state: `battle_pso_prewarmer.gd` renders the
actual retained host and all seven-by-three layers inside an independent
`512 x 512` `SubViewport`, then seals 21 current `Texture2D` instance IDs and
two `RenderingServer.frame_post_draw` flushes. Identity drift invalidates the
seal.

The live result-screen `BUTTON_PLAZA` route produces `ACTION_ENTER_PLAZA`, not
a notice action. Plaza entry composes resource and GPU readiness; an incomplete
attempt returns explicit `false`, and callback scene glue retains the callable
for a later click rather than consuming it. Only a completed attempt clears the
callback and spawns the plaza. The R1 retained bridge is complete and still
consumes the legacy one-axis position applicator in production.

R1 Vulkan sign-off used eight A-H captures. It recorded 148,223 nontransparent
GPU-prewarm pixels, 34.938 ms GPU readiness, 8.432 ms spawn-call time, 20.758 ms
from spawn return to first post-draw, 7,459 strength-pair changed pixels, and
7,366 ADD/MIX changed pixels. A 6,144-pixel lifecycle sentinel remained at zero
in degenerate, interior, and exit captures; the capture suite reported zero
failures. Because Godot clamps `SubViewport`
to at least `2 x 2`, the degenerate leg enters the live `PlazaScene` root
`_draw()` fallback without calling the host directly.

### Plaza R2 candidate-only map boundary

`plaza_map_projection.gd` owns the pure fixed-world/safe-rect projection candidate.
`plaza_map_layout_generator.gd` owns deterministic candidate construction and
validation for road topology, plots, buildings, semantic decoration, blocked
geometry, walkable corridors, interaction portals, labels, and its canonical
layout fingerprint. R2-A/P1 structural QA is GREEN across 56 building subsets
and seeds 5/6/7 (168 rosters), including geometry and consumed-field
counterproofs. These owners do not replace `plaza_world_geometry.gd` or the
production one-axis applicator until the later atomic promotion.
The generator is currently a cohesive 2,745-line pure owner, not an automatic
size-only refactor target. Its independent `skeleton`, `plots`, `assignment`,
and `decor` RNG streams define the future split seams. Any later owner split
must preserve those salts, the canonical fingerprint, the 168-roster outputs,
and the existing mutation counterproofs exactly.

`plaza_map_navigation.gd` compiles candidate walkability from the complete actor
rectangle, binds a digest that rejects later geometry mutation, and owns candidate movement and
portal routing. `plaza_map_minimap_projection_2d.gd` projects the same 2D world
spec into the candidate minimap without duplicating generation. The navigation
and minimap hardening gates are GREEN, including a 2px uncovered-slit
counterproof and exact two-axis building/player/exit/camera comparisons. This is
not a production performance sign-off: each candidate `move_actor()` validates
the whole geometry string/SHA again, and exact body coverage uses
`Geometry2D.clip_polygons()`. Atomic activation requires steady-p95 evidence at
the real owner cadence and a bind-once immutable compiled owner with a fast
occupancy path that preserves the same counterproofs, following
[GRT-032](godot_runtime_traps.md#grt-032)'s setup-time-index/per-frame-O(1)
boundary.

`plaza_r2_map_world_candidate_host.gd` is a separate candidate renderer. It
preflights all state before tree mutation, consumes caller-isolated compiled road
draw records, and keeps actual building and actor CanvasItems as direct Y-sort
siblings with relative zero-z layers. Its focused, mutation, and 2020x1246
Forward Mobile A/B/C Vulkan Y-sort gates are GREEN, including an actual actor
z=1 structural RED counterproof. The actual-tree seal also restores Base=MIX,
Sign/Window=ADD, Probe/Body=null material, local material ownership, white
parent/child modulation, show-behind and visibility after leaving mutations in
place; the resulting independent audit found zero CRITICAL/HIGH findings. The host,
navigation, and 2D minimap owners have no production `plaza_scene.gd` or
`project.godot` reference. Do not route live state to them piecemeal.

R2-C actor activation must add the active Guardian Spirit as another direct
Y-sort sibling; the candidate's single actor item proves only the player. The
current live plaza follower targets fixed `GROUND_Y` and linearly interpolates
there, so it must not be reused as 2D locomotion. Player and companion feet must
consume the same compiled walkable/blocker domain. Scripted recall or teleport
also remains subject to [GRT-013](godot_runtime_traps.md#grt-013), adapted to the
2D coordinate contract: a ground/patrol companion's full-body destination is
projected onto the compiled walkable union, so a cross-lane recall may change
both X and Y. Teleport endpoints and every interpolated/tracked sample must stay
walkable and outside blockers; only flight companions may use free Y outside the
ground set. Literal `keep Y/change X only` porting is forbidden under
[GRT-052](godot_runtime_traps.md#grt-052) and
[GRT-053](godot_runtime_traps.md#grt-053). Both motion-style outcomes, a naive
X-only outside-corridor counterproof, companion blocker/portal routing, actual
player/companion occlusion crossings, and interior/exit cleanup are required
before the atomic production promotion.

The seed-5 semantic candidate board proves structure and decor-role distribution,
not final art. Its code-drawn road/plot surfaces and workspace-only decor remain
RED for production; final ground/road art approval plus an atomic owner/camera/
input/minimap activation and real production Vulkan regression are still required.

### Plaza R3 production 2D map boundary

This boundary supersedes the production-status wording in the historical R1/R2
sections above. Commit `b85847e4e` atomically retired the active R1 side-scroll
exterior and connected the R3 2D map; R1 remains compatibility and regression
material, never a quiet fallback when R3 activation fails.

`plaza_r3_production_entry_host.gd` owns the opaque finite-progress loading
surface, stalled-prewarm failure, and the single reveal boundary that tears
down R1, applies the plaza reward state, activates R3, and removes loading.
`plaza_r3_lifecycle_prewarm_candidate.gd` retains its compatibility filename
but now owns the production stage/seed compiled-cache lifecycle, resource/GPU
prewarm, interior hide/return, and scene teardown. A ready state may be revealed
only after in-bounds GPU submission and both post-draw flushes.

`plaza_r3_exterior_runtime_candidate.gd` likewise retains its compatibility
filename while owning the production player/Guardian cadence, two-axis camera,
portal hit, minimap, and compiled-navigation instance. It composes
`plaza_r3_exterior_retained_host.gd`, `plaza_r3_minimap_canvas.gd`,
`plaza_r3_minimap_projection.gd`, `plaza_r3_navigation_binding.gd`,
`plaza_map_navigation_compiled.gd`, and `plaza_map_guardian_locomotion.gd`.
Buildings, player, and Guardian are direct siblings of one Y-sort root; the
approved plot pads replace a building-shadow layer, while actors retain small
contact shadows.

`plaza_map_road_skeleton_r3.gd` and
`plaza_r3_environment_layout_compiler.gd` own the authoritative road-first
layout and approved environment draw plan. `plaza_scene.gd` remains the plaza
orchestrator for rewards, interior/economy routes, and transition calls, but it
must not rebuild R3 geometry, navigation, minimap, or retained draw records.

R3-E exit cleanup constructs `plaza_map_navigation_compiled.gd` instances
directly from validated bound state. Do not restore a static factory which
creates and returns a temporary RefCounted: under Godot 4.6 that pattern can
leave a zero-reference ObjectDB instance during language shutdown even after
scene-owned nodes, resources, and RIDs are released.

### Plaza flow-gate and world-geometry boundary

`plaza_flow_gate_policy.gd` owns the update/input priority between runtime-perk
and character-info overlays, plaza warp, building transition, interior menu,
and normal street flow, including whether street simulation must stop.
`plaza_scene.gd` dispatches the selected owner and exposes it in status, but
must not restore separate update and input condition chains.

`plaza_world_geometry.gd` owns fitted game rectangles, render scale, player
normalization, camera targeting, world/local/screen conversion, and building
interaction/click hit order. The scene may retain narrow compatibility facades
that supply live camera/player/viewport state, but must not duplicate these
formulas or hit-test loops.

### Plaza public-status snapshot boundary

`plaza_status_snapshot_builder.gd` owns the complete public `get_status()`
schema consumed by Plaza controllers and focused smokes: flow/menu/transition
state, nested interior and character-info snapshots, transaction summaries,
runtime-perk choice metadata, progression counters, minimap state, and geometry.
`plaza_scene.gd` captures one explicit required-key context through direct
references to its live fields and methods; the builder validates that context
before projecting the public schema. Do not pass the scene object to the
builder and recover private fields/methods by string via `get()`, `has_method()`,
or `callv()`: a rename must fail visibly instead of degrading to null/zero.
Do not restore the field-by-field public status dictionary to the scene shell
or introduce a second status schema in a controller.

### Plaza interior-view ownership boundary

`plaza_interior_view.gd` is the only building-interior presentation and input
owner. `plaza_scene.gd` may build its live data, forward localized input,
synchronize transaction results, and close/free the view. While a menu session
is open, the scene must recreate a missing view before update/input continues;
do not restore the obsolete scene-local menu/NPC renderer, menu geometry, or
keyboard/mouse action-row fallback.

Inside the view, object hover/selection, shop-click animation, trade feedback,
trade interaction coordination, and icon caching each have one typed
`RefCounted` owner in `scripts/plaza/`. The view composes those owners and draws
their snapshots; it must not restore parallel scalar/dictionary mirrors. Shared
trade item identity, display text, icon-path, and inventory projection belong to
`plaza_trade_item_presentation.gd`, including the snapshots assembled by
`plaza_scene.gd`.

`plaza_shop_click_animation_state.gd` owns the active click clock/geometry and
the deep-copied pending spec. At the duration boundary it atomically moves that
payload into a one-shot completed slot. The view may resolve the live spec for
drawing, but completion must consume the state-owned payload; it must not keep a
parallel pending dictionary or reconstruct the action target after reset.

`plaza_trade_interaction_controller.gd` is the single coordinator for trade
hover, row scroll, drag pointer/payload lifetime, cross-panel trade, same-panel
reorder, equipped-item sale confirmation/cancel, and callback dispatch. It owns
the corresponding state/decision/dispatcher collaborators. The view supplies
current inventories and local/game coordinates, requests redraw after returned
state changes, and reclamps against the latest inventories after callbacks; it
must not restore the prior parallel trade methods or direct state fields.

`plaza_interior_view_data.gd` owns normalized/copied payload state for building
identity, text, textures, accent, save snapshot, and player/shop inventories.
`plaza_interior_layout.gd` owns interior rectangles, trade-grid geometry,
object hit order, object specs, and scroll/drop projection. The live view may
keep constant aliases and narrow helper facades, but must not duplicate literal
geometry, grid math, payload-copy loops, or mutable payload fields.
`plaza_shop_strewn_visual_spec.gd` owns strewn-item draw sizes, colors,
animation metadata, and sprite-sheet frame rectangles; the view supplies its
live accent and performs drawing only.

`plaza_interior_chrome_projection.gd` owns the non-trade title/gold/exit bar,
normal and top-view NPC fit geometry, fallback NPC figure, shopkeeper speech
bubble, and selected-object action-panel snapshots. Its paired
`plaza_interior_chrome_renderer.gd` owns the corresponding concrete
`CanvasItem` draw recipe and reuses `plaza_interior_draw_primitives.gd` for
text and buttons. The view resolves live textures/data and preserves draw
order; it must not restore those geometry, copy, or drawing formulas locally.

`plaza_interior_room_renderer.gd` owns the complete room-background layer:
backdrop cover-cropping, procedural fallback bands/floor, building-specific
neon sign, wall props, room clutter, and the no-backdrop table/clutter pass.
The view supplies live size/time/building/accent/texture inputs only; it must
not restore duplicate background helpers or the procedural neon catalog.

`plaza_interior_object_renderer.gd` owns standard, featured, and strewn object
drawing, texture/fallback icons and props, hover/flare rings, and trade labels.
`plaza_coin_trade_aura_renderer.gd` owns aura/burst texture-material drawing
and must restore the caller's `CanvasItem.material`; the typed FX state still
owns its snapshots. `plaza_shop_click_fx_renderer.gd` owns click rings,
sparkles, animated-sheet selection, and frame drawing. The view keeps hover,
selection, click-clock, Tween/particle lifecycle, texture lookup, and action /
trade orchestration, and passes typed resources directly without per-frame
Callable or render-context allocation.

`plaza_interior_input_policy.gd` owns key/mouse event classification and the
priority between trade confirmation, trade modal, object panel, shortcuts, and
normal object interaction. `plaza_interior_view.gd` converts coordinates and
executes the selected action, but must not restore a parallel event-type and
button/key condition chain.

`plaza_coin_trade_fx_state.gd` owns the coin-trade pulse/burst envelope values,
particle-process defaults, particle visibility/material projection, animation
gate, and aura-layer geometry/color/intensity projection.
`plaza_coin_trade_fx_runtime_host.gd` owns the tree-bound pulse/burst Tweens,
`GPUParticles2D`, particle-process material, additive/Writhe material caches,
prewarm, per-frame particle application, and exit cleanup. It is
controller-driven with its own `_process()` disabled. The view supplies only
live building/trade/coin hover/flare inputs, consumes aura/material outputs, and
must call `tear_down()` on exit rather than retain parallel FX nodes or clocks.

`plaza_trade_ui_projection.gd` owns trade-modal root geometry, panel/cell and
scrollbar snapshots, edge-clamped tooltip placement/content, drag-ghost
geometry, feedback alpha/position, and equipped-item sale-confirm presentation.
`plaza_trade_item_presentation.gd` remains the shared owner of item identity,
name/description/roll copy, icon paths, semantic color, equipped state, and
panel-specific price. `plaza_trade_ui_renderer.gd` owns the concrete trade
`CanvasItem` draw calls and consumes the typed icon cache directly, while
`plaza_interior_draw_primitives.gd` owns shared shadow text, text wrapping, and
button drawing. `plaza_trade_ui_presenter.gd` owns live root/panel/feedback/
confirm/tooltip/drag snapshot assembly, renderer call order, scale-to-game hover
conversion, and the confirmation early-return that suppresses lower layers.
The view supplies current inventories, feedback state, controller, cache, and
scale through one draw call; it must not rebuild presentation formulas, layer
order, or trade draw recipes locally.

### Plaza shop inventory and trade-summary boundary

`plaza_shop_inventory_state.gd` is the only mutable owner of rolled shop stock,
stock-id lookup, removal, reorder, and sold-item relisting.
`plaza_shop_transactions.gd` owns shop/player action decoding, passive and
active runtime grants, wallet/AP validation and commit, failed-purchase grant
rollback, successful-sale relisting, and shop/player reorder synchronization.
The purchase order remains grant first, payment second, stock removal last; a
failed payment must remove the provisional passive inventory item or active-slot
item and leave shop stock intact. `plaza_shop_trade_summary.gd` owns
purchase/sale result shapes, wallet fallback, and wallet-summary merge/copy
policy. `plaza_scene.gd` retains the shop-building/action gate, current visit-AP
input, trade audio, shared facility finalization/message refresh, and copied
snapshot exposure only. Do not restore a parallel `_shop_inventory` array or
move runtime transaction policy back into the scene.

### Lingpet companion active-skill tick boundary

`lingpet_companion_skill_controller.gd` owns the complete active-slot tick:
slot enumeration through `lingpet_skill_runtime_surface.gd`, lazy ball-context
reads, idle-skip gating/counters, update-context construction, arm/launch
decisions, strike-request forwarding, and final skill position-owner
resolution. It composes `lingpet_companion_skill_effect_update_gate.gd` and
`lingpet_companion_skill_update_context_builder.gd`; those instances must not
move back into the egg runtime.

`lingpet_egg_runtime.gd::_update_companion_skill_effects` remains the narrow
integration seam. It supplies current tick state and host methods for
patrol initialization, concrete skill launch, and strike animation, then
applies the controller's final position override. Position-changing callbacks
return the current companion position so later slots in the same tick observe
the same event order as the former inline production loop. Stable dependency
objects are configured once during runtime construction; the physics hot hook
passes scalars and the integration host directly and returns `Vector2`, without
allocating a dependency dictionary, result dictionary, or lambdas per tick.
Regression guard:
`lingpet_companion_skill_runtime_coordinator_smoke.gd` plus the main
`lingpet_egg_runtime_smoke.gd` wind-up/launch scenarios.

### Lingpet active-skill launch-feedback boundary

`lingpet_skill_launch_feedback_router.gd` owns the immediate launch cue policy
for every supported active-skill kind: dedicated cue selection, exact fallback
priority, the Dragon Breath/Wing low-volume arguments, deliberately silent
host branches whose cues fire later from concrete runtimes, and cached-before-
instance `game_audio` lookup. Its fallback helper uses fixed `StringName`
parameters instead of constructing a method-name Array on each launch.

`lingpet_skill_runtime_host.gd::trigger_launch_feedback()` remains the public
facade and passes the unchanged skill id and registry to the router. The host
retains module construction, update/draw/visibility, launch success, snapshots,
and skill lifecycle; concrete modules retain delayed fire/hit/outro cues at
their authored event frames. Do not restore per-skill audio helpers or registry
lookup in the host, and do not move runtime-timed cues into this immediate
router. Regression guard: `lingpet_skill_launch_feedback_router_smoke.gd`, the
individual skill smokes that call the facade, and `lingpet_egg_runtime_smoke.gd`.

### Lingpet active-skill companion-surface boundary

`lingpet_skill_companion_surface_router.gd` owns allocation-free policy exposed
to the companion controller and renderer: exact per-kind launch-origin offsets,
position-override eligibility and forwarding, body-hit/body-draw suppression,
Headbutt strike-request consumption, cast-pose progress, and supported-runtime
windup visibility. It receives scalar kind/id values plus an already-created
skill reference; it must not lazily construct modules, retain the host, or
build per-query dependency/result containers.

`lingpet_skill_runtime_host.gd` remains the public facade. It resolves the
current kind, peeks the existing module, and forwards both without changing
module lifetime. The host retains `get_active_position_override_owner()` so
first-active-slot priority and the established Dictionary payload stay at the
cross-slot boundary. Do not move module construction or that slot-selection
payload into the router, and do not restore per-kind companion policy matches
in the host. Regression guard:
`lingpet_skill_companion_surface_router_smoke.gd`, the focused active-skill
smokes, `lingpet_companion_skill_visual_resolver_smoke.gd`, and
`lingpet_egg_runtime_smoke.gd`.

### Lingpet Headbutt renderer boundary

`lingpet_headbutt_renderer.gd` owns stateless procedural rendering for the
shared Lunabi/Onimaru Headbutt runtime: Mega-charge gathering, normal and fiery
dash trails, exact ground crack -> slam dust/debris -> generic hit -> Mega burst
-> hot spark layer order, miss impact/text, and self-stun stars. It receives
runtime-owned positions, normalized timer progress, elapsed animation clocks,
slam radius, target, and hit+miss seed plus the borrowed typed trail. It owns no
RNG, wall clock, gameplay state, audio, status, collision, or retained payload.

`lingpet_headbutt_skill.gd` retains launch/update/collision, combo and return
state, audio/shake/status/knockback effects, snapshots, render fanout order, and
the deterministic gameplay hash. It passes the unshaken impact position
separately from the shaken draw position so screen shake never re-seeds cracks,
debris, or sparks. Do not restore CanvasItem recipes to the skill, mirror
gameplay fields in the renderer, or replace the allocation-free scalar/borrowed-
array boundary with a per-frame Dictionary. Regression guard:
`lingpet_headbutt_renderer_smoke.gd`, `lingpet_headbutt_skill_smoke.gd`, the
Lingpet runtime/surface smokes, and windowed pre/post pixel-hash parity.

### Lingpet Skeleton Archer renderer boundary

`lingpet_skeleton_archer_renderer.gd` owns stateless procedural rendering for
Nekuring's Skeleton Archer: particles, dying-fragment dissolution, live normal
and golden spirit bodies, emerge layers, bow/aim poses, soul motes, and normal
or golden arrows. Its public draw entry preserves the existing particles ->
dying archers -> live archers -> arrows order and iterates the borrowed typed
collections directly.

`lingpet_skeleton_archer_skill.gd` retains summon caps, patrol/aim/fire timing,
level/golden/bonus rolls, arrow and returned-ball collision, boss status and
knockback, audio, collection lifecycle, and snapshots. Emerge/death duration
and the current level-scaled arrow draw time cross the boundary as explicit
scalars; the renderer owns no RNG, wall clock, gameplay state, collision, or
retained collection. Do not restore CanvasItem recipes to the skill, mirror
collections in the renderer, copy arrays per frame, or change the established
layer order. Regression guard: `lingpet_skeleton_archer_renderer_smoke.gd`,
`lingpet_skeleton_archer_skill_smoke.gd`, the windowed visual-render smoke, and
pre/post composite pixel-hash parity.

### Lingpet Puppet Grab renderer boundary

`lingpet_puppet_grab_renderer.gd` owns Koyora Puppet Control's stateless
presentation: extending/missing/live strings, elastic severed halves and fray
bundles, hand, pull-tension lines, CHU/CUT/MISS copy, sparkles, and hearts. It
receives explicit phase clocks and positions plus borrowed fray/particle
collections. Pull-tension jitter is a pure projection of animation time and
shot count within the original three-line 20..40px envelope; repeated redraws
at an unchanged runtime clock must not consume global RNG or change pixels.

`lingpet_puppet_grab_skill.gd` retains snapshot lock-on and MISS/retry policy,
boss ownership, pull/kiss/return timing, ball/rope cut geometry, deterministic
cut-fray payload construction, audio, companion cast pose, payload lifecycle,
snapshots, and exact render fanout order. Compatibility geometry queries
delegate to the renderer without duplicating formulas. Do not restore
CanvasItem recipes or draw-time RNG to the skill, retain gameplay state in the
renderer, copy borrowed arrays per draw, or let a wall clock drive tension
jitter. Regression guard: `lingpet_puppet_grab_renderer_smoke.gd`, Rope Cut
and payload smokes, the full Lingpet runtime/surface suite, exact non-PULLING
pixel parity, and repeated-redraw PULLING hash stability.

### Lingpet Dragon Breath renderer boundary

`lingpet_dragon_breath_renderer.gd` owns Red Dragon Dragon Breath's stateless
jet, muzzle glow, live ember/tongue cloud, deterministic rare warm mote, and
hit-flash composition. It receives the runtime-owned breath-active flag,
`_elapsed`, origin/direction, hit-flash clock, material instances, and the
borrowed typed particle array. The rare mote remains a 5%-of-life visual but
projects its roll, offset, and size from particle phase/wob/index plus a
quantized runtime frame; repeated redraws at the same runtime clock must not
consume global RNG or change pixels.

`lingpet_dragon_breath_skill.gd` retains companion-origin tracking, heat-cone
ball reflection and its gameplay speed/angle RNG, particle/fire-zone lifecycle,
boss slow/push/barrier policy, Molotov payload conversion and detached-host
cleanup, audio, materials/prewarm, and snapshots. It forwards `_elapsed` to the
focused renderer and to the shared Molotov renderer's backward-compatible
optional explicit-time argument. Do not restore CanvasItem recipes, wall-clock
reads, or presentation RNG to the skill/renderer, copy the borrowed particles,
or remove the Molotov renderer's default time fallback used by existing active-
item callers. Regression guard: `lingpet_dragon_breath_renderer_smoke.gd`, the
runtime/payload/VFX and Lingpet surface suites, windowed repeated-redraw pixel
stability, and the detached-host cleanup checks.

### Lingpet Doll Curse renderer boundary

`lingpet_doll_curse_renderer.gd` owns Koyora Doll Curse's stateless marionette
strings/control bar, five-layer beam cone, origin/shimmer/contact accents,
wooden dance-sheet frames and procedural fallback, destroy debris, and hit
flash. It receives explicit phase clocks, skill level, gameplay-derived beam
length/base/outer width and doll half-size plus the borrowed typed doll and
debris arrays. It owns no gameplay state, RNG, wall clock, audio, collision,
status, texture loading, or retained collection.

`lingpet_doll_curse_skill.gd` retains emerge/active/retract movement, beam
sweep/homing rolls and focus policy, shared hit-cone geometry, per-doll boss
contact, confusion apply/clear, ball collision/bounce, destroy-particle
lifecycle, companion pose, audio, texture prewarm, and snapshots. Its draw
facade preserves rigging -> beams -> dolls -> debris -> hit-flash order without
copying arrays; legacy sheet-frame and beam-debug test queries delegate to the
renderer. Do not restore CanvasItem recipes to the skill, move homing/contact
RNG or status/collision policy into the renderer, duplicate the borrowed arrays,
or hardcode a visual beam endpoint independent of
`BEAM_LENGTH * tan(BEAM_HALF_ANGLE)`. Regression guard:
`lingpet_doll_curse_renderer_smoke.gd`, the existing runtime/payload and
Lingpet surface suites, exact pre/post windowed pixel hash, and the fanout
reverse-mutation check.

### Lingpet Thunder Orb renderer boundary

`lingpet_thunder_orb_renderer.gd` owns Lumion Thunder Orb's stateless borrowed
trail and energy-mote drawing, orb body/pulse/crackle, explosion web/rings and
particle rendering, mini-spark flashes, and deterministic redraw-only crackle
projection. It receives runtime `_elapsed`, a stable visual seed, live payload
arrays, and gameplay-derived positions/radii; it owns no gameplay state, wall
clock, RNG stream, audio, collision, status, or retained collection.

`lingpet_thunder_orb_skill.gd` retains projectile travel/deceleration, update-
side energy-particle creation and simulation RNG, explosion and mini-spark
gameplay state, boss hit geometry, source-scoped electric stun, loop-audio
cleanup, payload lifecycle, and snapshots. The shared
`boss_electrocution_field_host.gd` remains the sole on-boss electrocution visual
owner; the obsolete local stun-draw fallback was removed. Do not restore Canvas
recipes, `Time.get_ticks_msec()`, or redraw-time RNG to the skill, copy borrowed
arrays, move gameplay simulation RNG into the renderer, or duplicate the shared
boss electrocution host. Regression guard:
`lingpet_thunder_orb_renderer_smoke.gd`, the runtime/payload and Lingpet surface
suites, repeated-redraw windowed pixel stability, and the deterministic-helper
reverse-mutation check.

### Lingpet Dragon Wing renderer boundary

`lingpet_dragon_wing_renderer.gd` owns Farukiras / Red Dragon Dragon Wing's
stateless composition of warm wind streaks, vortex body/arcs/embers, borrowed
ball-swirl and dragon trails, flying-dragon sheet plus procedural fallback,
directional hit flash, additive material, and render-resource prewarm. It
receives runtime `_elapsed`, the gameplay-derived swirl envelope/geometry, live
typed arrays, and the flying-dragon dictionary; it retains only reusable render
resources and no gameplay state, wall clock, RNG stream, audio, collision, or
payload collection.

`lingpet_dragon_wing_skill.gd` retains the wind-field duration, vortex steering
and guardable ball-speed policy, wind/reversal and particle-spawn RNG, live
particle/trail advancement, flying-dragon motion and collision boost, hit
feedback audio, and snapshots. Its facade lends existing collections without
copying and forwards `_elapsed`; the renderer preserves swirl field -> ball
trail -> wind particles -> dragon trail -> flying dragon -> hit flash order.
Do not restore CanvasItem recipes, render-resource fields, or wall-clock reads
to the skill, move gameplay RNG/collision into the renderer, copy the borrowed
payloads, or replace the explicit runtime clock with redraw cadence. Regression
guard: `lingpet_dragon_wing_renderer_smoke.gd`, the runtime/payload and Lingpet
surface suites, exact stable-layer hash, repeated-redraw windowed stability, and
the wall-clock reverse-mutation check.

### Lingpet Ghost Summon renderer boundary

`lingpet_ghost_summon_renderer.gd` owns Rabi Ghost Summon's stateless normal and
teleport particle passes, launch flash, dying/roaming/eating/teleport ghost
states, Banshee glyph/shadow primitives, and deterministic dying-spark
projection. It receives the live typed particle, teleport-particle, dying-ghost,
and ghost arrays plus explicit lifecycle durations; it owns no gameplay state,
RNG stream, wall clock, audio, ball ownership, collision, or retained payload.

`lingpet_ghost_summon_skill.gd` retains emergence and roaming motion, ball-eat
capture and hidden hold, consecutive-catch timing, teleport target selection,
level-scaled release policy, owner interpolation reset, audio routing, payload
advancement, snapshots, and all update-side gameplay/particle RNG. Its facade
lends collections without copying and preserves normal particles -> teleport
particles -> launch flash -> dying ghosts -> live ghosts order. Do not restore
CanvasItem recipes or redraw-time RNG to the skill, move capture/teleport/audio
policy into the renderer, copy borrowed arrays, or replace deterministic dying-
spark projection with redraw cadence. Regression guard:
`lingpet_ghost_summon_renderer_smoke.gd`, the runtime/payload and Lingpet/audio
surface suites, exact stable-layer hash, repeated-redraw windowed stability,
direct PNG region checks, and the RNG reverse-mutation check.

### Lingpet Bubble Trap renderer boundary

`lingpet_bubble_trap_renderer.gd` owns Maribo Bubble Trap's stateless capture-
bubble pulse, normal/rainbow projectile and borrowed trail composition, rainbow
shimmer, burst flash, deterministic inner-bubble detail, and borrowed particle
pass. It receives the skill's explicit `_visual_elapsed`, capture/burst clocks
and geometry, immutable render constants, and live projectile/particle arrays;
it owns no gameplay state, wall clock, RNG stream, audio, collision, status, or
retained payload.

`lingpet_bubble_trap_skill.gd` retains level-scaled speed/count/duration,
independent extra-shot and lead-rainbow rolls, projectile wobble/movement and
ball/boss collision, capture movement ownership, boss-stun refresh/cleanup,
ball/expiry pop, hydro audio, payload advancement, update-side burst-particle
RNG, and snapshots. Its facade lends both arrays without copying and preserves
capture -> projectiles -> burst -> particles order. Do not restore CanvasItem
recipes or `Time.get_ticks` reads to the skill, move collision/status/audio or
payload spawning into the renderer, retain borrowed arrays, or clock animation
from redraw cadence. Regression guard: `lingpet_bubble_trap_renderer_smoke.gd`,
the runtime/payload and Lingpet surface suites, exact stable-layer hash,
repeated-redraw windowed stability, and the wall-clock reverse-mutation check.

### Lingpet Solar Bolt renderer boundary

`lingpet_solar_bolt_renderer.gd` owns Lumion Solar Bolt's stateless full-field
flash, layered gold main bolt and lavender branches/fork glows, seeded explosion
flash/core/rings/radial arcs, shifted polyline projection, and borrowed spark
pass. It receives runtime `_elapsed`, live typed effect/particle arrays, field
geometry, and explicit lifetime/alpha constants. The original 85%-visible bolt
flicker is projected from runtime time plus the effect's strike seed, so repeated
draws of unchanged state are identical. The renderer owns no gameplay state,
global RNG stream, wall clock, audio, collision, or retained payload.

`lingpet_solar_bolt_skill.gd` retains defensive arm prediction, first-strike
reflection and speed lock, level-scaled delayed refire rolls/one-shot retarget,
strike-time fractal lightning path RNG, ball-intensity/audio/shake feedback,
effect and spark lifecycle advancement, and snapshots. Its facade lends both
arrays without copying and preserves screen flash -> effects -> particles order.
Do not restore CanvasItem recipes or draw-side `randf()` to the skill, move
arm/refire/collision/audio/path generation into the renderer, retain borrowed
arrays, or clock flicker from redraw cadence. Regression guard:
`lingpet_solar_bolt_renderer_smoke.gd`, the Solar Bolt and Lingpet/audio surface
suites, exact visible and stable-layer hashes, repeated-redraw windowed
stability, and the draw-RNG reverse-mutation check.

### Lingpet Sand Prison renderer boundary

`lingpet_sand_prison_renderer.gd` owns Rahoset Sand Prison's stateless cage
walls/floor/corners, deterministic wall grain, glow and decorative bars,
borrowed ambient/body-particle passes, and MISS text. It receives phase flags
and clocks, cage geometry, wash direction, runtime `_anim_time`, and the two
live typed particle arrays. Grain motion is projected on the original 18 Hz
cadence from runtime time plus stable seeds. The renderer owns no gameplay
state, global RNG stream, wall clock, audio, collision, boss ownership, or
retained payload.

`lingpet_sand_prison_skill.gd` retains creation/miss/imprison/dissolve/retry
phase progression, level-scaled retry policy, cage-width rolls, boss clamp
owner fields, companion cast-pose override, audio hooks, particle spawning and
advancement, all update-side RNG, and snapshots. Its facade lends both arrays
without copying and preserves ambient particles -> cage -> body particles ->
MISS text order. Do not restore CanvasItem recipes or redraw-side RNG to the
skill, move retry/clamp/audio/particle simulation into the renderer, retain
borrowed arrays, or clock grain motion from redraw cadence. Regression guard:
`lingpet_sand_prison_renderer_smoke.gd`, the original runtime/visual and Lingpet
surface suites, exact creating/missing/particles-only windowed hashes, and the
draw-RNG reverse-mutation check.

### Lingpet Gatling Burst renderer boundary

`lingpet_gatling_burst_renderer.gd` owns Volty Gatling Burst's transform-sheet
load/prewarm cache and stateless tank chassis, aimed cannon/muzzle flash, mount
bar, bullet/tracer trail, hit-particle, shell-casing, and smoke recipes. It
receives explicit phase flags/progress, gameplay-aligned tank center, aim/recoil/
flash scalars, transform frame, and four live typed arrays. The renderer owns no
phase state, projectile motion, RNG stream, wall clock, collision/status/audio,
or retained payload collection.

`lingpet_gatling_burst_skill.gd` retains mount/fire/dismount timing, aim and
spread rolls, muzzle-aligned projectile spawning, bullet movement/collision,
AK-style stun/knockback status payloads, transform/fire/hit feedback, loop-audio
cleanup, particle spawning/advancement, and snapshots. Its facade lends all
four arrays without copying and preserves smoke -> bullets -> hit particles ->
casings -> tank order. Do not restore CanvasItem recipes or render-resource
loading to the skill, move collision/status/audio/payload simulation into the
renderer, retain borrowed arrays, or reorder the passes. Regression guard:
`lingpet_gatling_burst_renderer_smoke.gd`, the original runtime/payload and
Lingpet/audio-loop surface suites, exact firing/mounting/residual windowed
hashes, and the layer-order reverse-mutation check.

### Lingpet Star Coil renderer boundary

`lingpet_star_coil_renderer.gd` owns Orosha Star Coil's stateless motion-trail
circles, spark glow/regular-star/white-core passes, and the safe alternating-
radius polygon projection. It receives only explicit trail visibility, shake
offset, and the live typed trail/spark arrays. The renderer owns no phase,
movement, bind/status state, RNG stream, wall clock, audio, or retained payload
collection.

`lingpet_star_coil_skill.gd` retains wall selection, roll/climb/lunge/bind/
cross/descend progression, boss slow/dash-block/skill-cooldown ownership and
self-healing writes, companion position override, movement/bind audio, spark
emission and deterministic payload creation/advancement, and snapshots. Its
facade lends both arrays without copying, suppresses only the trail during idle
and bind, and preserves trail -> sparks order. Do not restore CanvasItem or star
polygon recipes to the skill, move phase/status/audio or spark simulation into
the renderer, retain borrowed arrays, or reorder the passes. Regression guard:
`lingpet_star_coil_renderer_smoke.gd`, the original skill/draw-performance and
Lingpet/status/audio surface suites, exact moving/sparks-only/trail-only hashes,
safe vertex projection, and the layer-order reverse-mutation check.

### Lingpet Bone Barrier renderer boundary

`lingpet_bone_barrier_renderer.gd` owns Nekuring Bone Barrier's stateless
assembly-bone projection, completed ivory body/joints/marrow/cracks/spikes/
poison wisps, shatter shockwave/fragments, particles, bone-segment recipe, and
palette. It receives explicit gameplay build/death durations plus the live typed
barrier, dying-barrier, and particle arrays. The renderer owns no placement or
bonus RNG, build/break state, collision/reflect policy, audio, round lifecycle,
wall clock, or retained payload collection.

`lingpet_bone_barrier_skill.gd` retains level-scaled width and bonus rolls,
placement/spacing and active-cap policy, install/build timing, ball-collision
context and reflection notification, shatter/particle simulation, round-
persistent barriers, audio, and snapshots. Its facade lends all three arrays
without copying and preserves particles -> dying barriers -> live barriers
order; the public build-progress helper remains a compatibility facade over the
renderer projection. Do not restore CanvasItem/palette recipes to the skill,
move collision/RNG/audio/lifecycle into the renderer, retain borrowed arrays,
or reorder the passes. Regression guard: `lingpet_bone_barrier_renderer_smoke.gd`,
the original runtime/visual and Lingpet/audio/performance surface suites, exact
mixed/dying/top windowed hashes, and the layer-order reverse-mutation check.

### Lingpet Soul Clone renderer boundary

`lingpet_soul_clone_renderer.gd` owns Rabi Soul Clone's imported walk-texture
cache, spirit-particle circles, breathing aura, two afterimages, animator-region
projection, horizontal texture-region flip, and procedural fallback. It receives
explicit active/elapsed/duration state, one facade-sampled visual-clock value,
and the live typed clone and particle arrays. The renderer owns no target or
particle RNG, movement, collision/reflection, particle advancement, lifecycle,
snapshot state, audio, wall-clock read, or retained payload collection.

`lingpet_soul_clone_skill.gd` retains level-scaled clone count and duration,
seed/target/ambient/burst rolls, body-hit and sprite-animator advancement,
free-flight motion, paddle-style ball reflection, particle simulation, active
lifecycle, and snapshots. Its facade samples the visual clock once, lends both
arrays without copying, and preserves particles -> active guard -> clones order.
Do not restore texture/CanvasItem recipes to the skill, move RNG/motion/hit/
simulation/lifecycle into the renderer, let the renderer sample wall time, retain
borrowed arrays, or reorder/duplicate the particle pass. Regression guard:
`lingpet_soul_clone_renderer_smoke.gd`, the original skill/payload and adjacent
Lingpet host/UI suites, fixed-clock phase projection, the deterministic windowed
fixture hash, and the strengthened layer-order reverse-mutation check.

### Lingpet Banana Slice renderer boundary

`lingpet_banana_slice_renderer.gd` owns Monkeyring Banana Slice's imported
banana-texture cache, prewarmed 24-segment filled-ellipse mesh, prepare banana,
projectile trail/rotated texture region, landed shadow/blink/banana, burst-
particle pass, and pure rotated-quad projection. It receives explicit prepare
visibility/progress/position plus the live typed projectile, landed-banana, and
particle arrays. The renderer owns no throw/flight/landing/collision/slip state,
RNG, payload creation/advancement, audio, boss-AI context, companion pose,
snapshot state, wall clock, or retained live collection.

`lingpet_banana_slice_skill.gd` retains level-scaled count/slip duration/speed,
prepare and staged throw timing, landing-x and centered-slip rolls, projectile
movement/bounce/trail advancement, landed-banana collision/expiry, boss-slip
decay/context, burst-particle spawning/simulation, audio, companion pose, and
snapshots. Its facade computes the gameplay-owned prepare position, lends all
three arrays without copying, and preserves prepare -> projectiles -> landed ->
particles order; the texture-loaded snapshot reads the renderer cache through a
compatibility method. Do not restore texture/mesh/CanvasItem recipes to the
skill, move gameplay/RNG/audio/context/simulation into the renderer, retain or
copy the borrowed arrays, or reorder/duplicate passes. Regression guard:
`lingpet_banana_slice_renderer_smoke.gd`, the original skill/payload and adjacent
Lingpet/Monkeyring/audio/host suites, deterministic rotated-quad projection, the
windowed composite fixture hash, and the layer-order reverse-mutation check.

### Lingpet Moon Orbit renderer boundary

`lingpet_moon_orbit_renderer.gd` owns Draft Bat Moon Orbit's projectile trail/
core/glow, orbit-field fill and two outlines, three moving crescent arcs, burst
and ambient particle circles, wall-impact burst, and pure validated ellipse-
point projection. It receives one facade-sampled visual time, explicit gameplay
radii/durations/seed/positions/velocities, and the live typed trail and particle
arrays. The renderer owns no projectile/field/particle lifecycle, wall routing,
collision ellipse, slow status, payload generation/advancement, snapshot state,
wall-clock read, RNG, audio, or retained live collection.

`lingpet_moon_orbit_skill.gd` retains projectile movement and precise wall-hit
travel-time split, trail advancement, field placement/timing and deterministic
seed, burst/ambient particle spawning and simulation, boss-vs-ellipse overlap,
slow-status publication, and snapshots. Its facade samples visual time once,
lends both arrays without copying, and preserves orbit -> particles -> burst ->
projectile order. Do not restore CanvasItem/ellipse/crescent recipes to the skill,
move gameplay/status/simulation into the renderer, let the renderer read wall
time, retain/copy borrowed arrays, or reorder/duplicate passes. Regression guard:
`lingpet_moon_orbit_renderer_smoke.gd`, the original skill/payload and adjacent
Lingpet/rail/host suites, deterministic safe ellipse projection, the windowed
composite fixture hash, and the layer-order reverse-mutation check.

### Lingpet Wild Roar renderer boundary

`lingpet_wild_roar_renderer.gd` owns Monkeyring Wild Roar's full-game-canvas
flash, growing base disc, deterministic six-ring delayed projection, alternating
cyan secondary arcs, rotating spokes, generated-particle circles, and reflected-
ball glow/streak. It receives explicit field size, VFX time/radius/flash caps,
reflection presentation state, and the borrowed typed particle array. The
renderer owns no arm gate, trigger/jitter/spark/impact RNG, reflection/boost,
payload creation/advancement, owner cleanup, audio/shake, companion pose,
snapshot state, wall clock, or retained live collection.

`lingpet_wild_roar_skill.gd` retains proximity and travel-gap arm policy, level-
scaled radius/boost, trigger-distance and reflection-jitter rolls, reflection/
minimum-upward/boost math, owner boost publication and cleanup, roar/impact
particle RNG and simulation, audio/shake, companion pose, and snapshots. Its
facade lends the particle array without copying and preserves flash -> roar zone
-> particles -> reflected-ball glow order. Do not restore CanvasItem/ring/spoke
recipes to the skill, move any RNG/gameplay/feedback/owner state into the
renderer, retain/copy particles, or reorder/duplicate passes. Regression guard:
`lingpet_wild_roar_renderer_smoke.gd`, the original skill and adjacent arm/
coordinator/context/Monkeyring/audio/host suites, deterministic ring projection,
the windowed composite fixture hash, and the layer-order reverse-mutation check.

### Lingpet Hydro Sphere renderer boundary

`lingpet_hydro_sphere_renderer.gd` owns Maribo Hydro Sphere's procedural puddle-
texture cache prewarm, projectile trail/core/outline/glow, surface/caustic/foam
puddle layers, splash rings, droplet texture blits, and allocation-free `Vector4`
puddle projection. It receives one facade-sampled visual time, explicit gameplay
positions/velocities/radii/durations/seed, and the borrowed typed trail and live
particle arrays. The renderer owns no projectile/puddle/particle lifecycle, wall
routing, boss collision ellipse, slow status, payload generation/advancement,
snapshot state, wall clock, RNG, or retained live collection.

`lingpet_hydro_sphere_skill.gd` retains projectile movement and precise wall-hit
travel-time split, trail advancement, puddle placement/timing and deterministic
seed, splash/ambient particle spawning and simulation, boss-vs-ellipse overlap,
slow-status publication, and snapshots. Its facade samples visual time once,
lends both arrays without copying, and preserves puddle -> particles -> splash ->
projectile order. Do not restore texture-cache/CanvasItem recipes to the skill,
move gameplay/status/simulation into the renderer, let the renderer read wall
time, retain/copy borrowed arrays, or reorder/duplicate passes. Regression guard:
`lingpet_hydro_sphere_renderer_smoke.gd`, the payload/egg/host and adjacent
Lingpet suites, deterministic safe projection, the windowed composite fixture
hash, and the layer-order reverse-mutation check.

### Lingpet Afterglow Leak renderer boundary

`lingpet_afterglow_leak_renderer.gd` owns the shared passive's procedural fluid-
texture cache prewarm, hit-origin emission flash, settled glow/body/caustic pool,
landed splats, creeping tongues, jet/splash/ambient/wisp presentation, absorb
flash, and allocation-free `Vector4` pool projection. It receives one facade-
sampled visual time, explicit fallback timings/radius, and borrowed typed residue
plus live particle arrays. The renderer owns no residue/absorption/gauge
lifecycle, floor deposits, particle payload creation/advancement, RNG, feedback,
snapshot state, wall clock, or retained live collection.

`lingpet_afterglow_leak_state.gd` retains hit-to-residue creation, seep/lifetime
cleanup, proximity absorption and gauge ticks, spray/splash/ambient/wisp RNG,
landing splat lifecycle, particle simulation, feedback, and snapshots. Its facade
lends both arrays without copying and preserves residues -> particles -> absorb-
flash order. Do not restore texture-cache/CanvasItem recipes to the state, move
gameplay/RNG/simulation into the renderer, let the renderer read wall time,
retain/copy borrowed arrays, or reorder/duplicate passes. Regression guard:
`lingpet_afterglow_leak_renderer_smoke.gd`, the payload/egg/loadout/profile/
snapshot suites, deterministic pool projection, the windowed composite fixture
hash, and the layer-order reverse-mutation check.

### Treasure Hunt reward / renderer boundary

`treasure_hunt_runtime.gd` owns the instant Treasure Hunt phase timeline,
mining-hit audio cadence, pending owner/registry handoff, reward RNG and chance
math, owned-one-time filtering, mythic/perk/passive/starpoint grants, localized
result/feedback payloads, and public reset/query/prewarm/draw facades. The draw
facade samples `Time.get_ticks_msec()` exactly once, advances the runtime phase,
projects mining progress from that same sample, and lends `last_result` without
copying it.

`treasure_hunt_renderer.gd` owns mining-sheet prewarm, item-icon caching, the
perk-icon presenter, cave wash, mining sheet and low-cost procedural fallback,
progress bar, reward/empty-result layers, glow, symbol, and centered text. The
short modal presentation deliberately remains a deterministic CanvasItem recipe;
it receives explicit phase/start/current timing and owns no reward RNG, pool,
grant, audio, pending runtime object, or result lifecycle. Do not restore render
resources or `canvas.draw_*` calls to the reward owner, let the renderer read wall
time, copy/retain the live result payload, or reorder backdrop -> cave -> content
and cave -> actor -> label -> progress passes. Regression guard:
`treasure_hunt_renderer_smoke.gd`, the existing Treasure Hunt/Treasure Map/item-
conversion and modal-gate suites, fixed-timestamp projection, two windowed Vulkan
captures for mining/result, and the layer-order reverse-mutation check.

### Stage 4 brazier-monk runtime / renderer boundary

`stage4_brazier_monk_event.gd` owns normal and smoke-grenade monk spawning,
return/collapse lifecycle, per-state movement and swing clocks, staff trigger and
ball-deflection policy, shared gameplay RNG, hit/explosion payload creation and
simulation, full actor-context export, and public status/reset/query facades. It
selects context overrides or its live collections, samples a wall-clock fallback
only when no runtime visual time exists, and lends the three arrays without copy.

`stage4_brazier_monk_renderer.gd` owns the three temple-ghost texture caches,
walk/attack frame selection, hover projection, transform-preserving UV flip,
procedural actor/staff fallback, hit effects, death particles, and newest-window
24/56 render caps. It receives explicit visual time and owns no monk lifecycle,
staff collision, payload generation/advancement, RNG, or retained collection.
Do not restore texture/CanvasItem recipes to the event, move gameplay mutations
into the renderer, let it read wall time, crop the logical actor context, reset
the playfield transform for sprite flips, or reorder hit -> death -> monk passes.
Regression guard: `stage4_brazier_monk_renderer_smoke.gd`, the existing render-
budget/payload/map/draw-context suites, deterministic frame/budget projection,
the windowed Vulkan composite hash, and the layer-order reverse-mutation check.

### Smasher Cleanse state / renderer boundary

`smasher_cleanse_state.gd` owns status-gated W / Up activation, gauge and shared-
cooldown spend, status cleanup, cast/counter/immunity clocks, `extension_gear`
duration scaling, cleanse audio, cast-ring and particle payload simulation/RNG,
status/skill-orb queries, and round/game reset. Its draw facade samples wall time
exactly once, forwards effective immunity and player geometry, and lends the two
typed live arrays without copying.

`smasher_cleanse_renderer.gd` owns staged flare/shockwave-cache prewarm, cast
flash/rings/particles, immunity-shield projection, and the established index-0
shared right-bottom timer-stack recipe. It receives explicit visual time and
owns no status mutation, activation/cooldown policy, effective-level math,
simulation, RNG, or retained collection. Do not restore CanvasItem/texture-cache
recipes to the state, move gameplay into the renderer, let rendering read wall
time, retain/copy the live arrays, or reorder cast -> shield -> timer passes.
Regression guard: `smasher_cleanse_renderer_smoke.gd`, the existing Cleanse,
status/immunity, dependency-context, stage-interaction, audio, and prewarm suites,
fixed-time shield projection, two windowed Vulkan cast/shield captures, and the
layer-order reverse-mutation check.

### Smasher Recovery state / renderer boundary

`smasher_recovery_state.gd` owns status-free W / Up activation during dash
recovery, dash-delay cleanup, gauge/shared-cooldown spend, recovery audio and
feedback, cast-ring/burst plus moving-trail payload creation/simulation/RNG,
5-second speed boost, `extension_gear` duration scaling, movement/speed queries,
and round/game reset. Its draw facade samples wall time once and lends all three
typed live arrays without copying.

`smasher_recovery_renderer.gd` owns staged texture/flare/shockwave prewarm, the
sustained 경신보 presentation, the moving light-trail, the activation burst,
deterministic cast/active/timer projections, and the established index-0 shared
right-bottom timer-stack recipe. It receives explicit visual time and owns no
activation, cooldown, dash cleanup, effective-level math, audio, simulation, RNG,
or retained collection.

경신보 is a **four-piece authored VFX set** under
`assets/sprites/characters/smasher/gyeongsinbo/` — 보법진 step sigil, 흙먼지 dust
bloom, 기류 qi trail, 지면 균열 ground crack. The runtime only drives envelope,
spin, scroll, and tint. **Do not reintroduce procedural primitives as the lead layer** — the prior
revision was rejected as 허접 for exactly that reason: `draw_line` has no caps so
uniform-width rays read as square bars, and evenly divided rays read as wheel
spokes no matter how much angular jitter is layered on
(`docs/godot_runtime_traps.md` — "Godot `draw_line`에는 라인 캡이 없다", "VFX 리브랜드
발광 예산 트랩").

Geometry rule: the Smasher paddle sits flush with the 750px floor, so there is no
room to draw beneath it. Every ground-plane piece is wide and flat and is anchored
through `get_ground_layout_for_tests(anchor_y, height)`, which lifts the centre so
the piece ends on `FIELD_BOTTOM_Y`. The height passed in must be the **rotated**
extent (`_rotated_extent_y`) — measuring an axis-aligned `size.y` on a tilted quad
lets a flat ellipse stand up diagonally and hang past the floor line. The step
sigil therefore spins through **UV rotation** (`_draw_spun_ground_quad`), never
quad rotation, so it stays a flat ground disc.

All four pieces composite **MIX**, and the alpha/brightness of each layer is
tuned on that assumption. This renderer draws immediate-mode onto the shared
battle canvas, where the "swap `canvas.material`, draw, restore" one-pass trick
does **not** work: material is a CanvasItem-level property, so only the last
assignment survives and every command renders with the canvas's original
material. Measured 2026-08-02 — flipping the light layers between ADD and MIX
left jade=9261 / dust=581 / rupture=10275 identical to the digit. Real additive
compositing needs a child CanvasItem host that owns its own material (the
pattern `viper_wall_leap_blast_fx_host.gd` uses, which works because its layers
are `Sprite2D` children), and that is gated on the battle-scene z-slot
constraint. `smasher_recovery_renderer_smoke.gd` fails the build if
`canvas.material =` reappears in this renderer.

Do not restore CanvasItem/texture-cache recipes to the state, move gameplay
mutation into rendering, read wall time inside the renderer, retain/copy live
arrays, or reorder sustained aura -> trail -> cast burst -> timer. Regression
guard: `smasher_recovery_renderer_smoke.gd` (authored-piece pipeline status,
prewarm-ladder step count, dead-material guard, ground-layout clamp, absence of
the procedural spoke fan),
`smasher_gyeongsinbo_active_vfx_visual_qa.gd` (windowed Vulkan composite asserting
jade readability, dust mass, and floor-line containment), the existing
Recovery/rebrand/speed/dependency/prewarm/timer-stack suites, and the layer-order
reverse mutation.

### Smasher Warp Gate state / presentation boundary

`smasher_warp_gate_state.gd` owns S / Down hold activation, gauge/shared-
cooldown spend, `extension_gear` duration scaling, pause/resume clocks, offscreen
movement and free wall-wrap policy, mirrored collision/actor context, portal
payload spawning/expiry, loop-audio sync, feedback, and round/game reset. Its
draw facade samples wall time exactly once and lends the typed live portal array
without copying; reset, pause, and the inactive-empty update path directly ask
the presentation owner to hide any retained host.

`smasher_warp_gate_presentation.gd` owns staged flare/shockwave/FX-host prewarm,
existing-child adoption, deferred attachment deduplication, direct host hiding,
game-to-screen node-FX projection, active/burst portal presentation, the complete
procedural fallback, and the established index-0 shared right-bottom timer-stack
recipe. It receives explicit visual time/phase/geometry and owns no activation,
cooldown, duration scaling, wrapping, payload mutation, audio, feedback, or RNG.
Do not restore host fields, render resources, or CanvasItem recipes to the state;
let presentation read wall time; retain/copy the borrowed portals; create a host
from update; or reorder host sync -> wall fallback -> timer -> burst fallback.
Regression guard: `smasher_warp_gate_presentation_smoke.gd`, the existing Warp
Gate/FX-host/prewarm/dependency/audio suites, actual-host reset/pause cleanup,
fixed projection, host/fallback Vulkan captures, and the layer-order reverse
mutation.

### Smasher Plasma state / renderer boundary

`smasher_plasma_state.gd` owns W / Up hold charging and short-charge refund,
gauge drain, charge-scaled cooldown, homing wave motion, boss overlap/gauge
drain/shared slow, Hongryun orb-gauge handoff, contact-distortion state, charge/
trail/wave payload spawning and simulation/RNG, audio sync, modular-host state
projection, and round/game reset. The full and contact-only draw facades each
sample wall time exactly once and lend all three typed live arrays without copy.

`smasher_plasma_renderer.gd` owns the established eight-step flare/shockwave/
modular-host/node-pipeline prewarm plus the legacy immediate-mode charge field,
wave/trail/particle fallback, and boss-contact overlay. It receives explicit
visual time, geometry, and state and owns no charging, gauge/cooldown, homing,
boss mutation, slow policy, audio, simulation, RNG, or retained collection. Do
not restore render caches or CanvasItem recipes to the state, let rendering read
wall time, retain/copy borrowed arrays, or reorder charge -> wave -> contact.
Regression guard: `smasher_plasma_renderer_smoke.gd`, the existing Plasma
parity/charge/FX-host/live-wiring/prewarm/dependency/audio suites, deterministic
charge projection, repeated Vulkan fallback capture, and the layer-order reverse
mutation.

### Laurel Leaf Shield state / renderer boundary

`laurel_leaf_shield_state.gd` owns effective perk plus Sacred Laurel leaf count,
orbit clock and player center, back-side collision, leaf consumption and 30-
second regeneration, upward random-speed reflection, break-particle creation/
simulation, audio/flash feedback, snapshots, runtime sync, and reset. Its draw
facade forwards collision-matched orbit geometry and lends the live leaf and
particle arrays without copying.

`laurel_leaf_shield_renderer.gd` owns orbit depth projection/sorting, full and
severe-LOD leaf silhouettes, pygame-parity ellipse/line/arc recipes, particle
stride/presentation, and triangulation guards for procedural fills. The serrated
type-3 leaf must be built as separate tip-to-stem and stem-to-tip edges; the old
single sweep self-intersected and emitted `Invalid polygon data` during full-
quality drawing. Do not restore CanvasItem/LOD recipes to the state, move
collision/regeneration/RNG into rendering, retain/copy borrowed arrays, reorder
leaves -> hit particles, or submit a procedural fill without a non-empty
`Geometry2D.triangulate_polygon` result. Regression guard:
`laurel_leaf_shield_renderer_smoke.gd`, the render-budget and Laurel/Sacred-
Laurel/runtime-owner suites, deterministic orbit projection, full/severe Vulkan
captures, the polygon error-log check, and the layer-order reverse mutation.

### Lingpet acquisition lifecycle coordinator boundary

`lingpet_acquisition_lifecycle_coordinator.gd` owns the cross-owner acquisition
sequence: shell-break pending branch selection, staged break advancement, hatch
flash and burst hold, deferred regular/overflow commit, per-pet cut-in prewarm
and animation-readiness gating, reveal/dismiss timing, acquisition/click audio,
and post-close overflow routing. The focused egg, cut-in state, asset-prewarm,
overlay-host resolver, item-egg lifecycle, and overflow-choice modules retain
their own state and policy; this coordinator orders them without rebuilding a
per-frame dependency dictionary.

`lingpet_egg_runtime.gd` retains the public compatibility API, current pet id,
and the final regular/overflow hatch side effects. The coordinator reaches
those remaining commit/snapshot/sync surfaces only through `WeakRef`, so it
must not retain strong self Callables. Do not restore pending hatch-kind/burst
timers, readiness checks, dismiss pacing/audio, or post-close overflow routing
to the facade. Regression guard:
`lingpet_acquisition_lifecycle_coordinator_owner_smoke.gd`, the Lingpet egg-
runtime, main-egg overflow, one-Guardian item-egg, acquire-cutin prewarm/
resolver/no-sync-load, ungated-idle, and egg-phase performance smokes.

### Lingpet Guardian duration lifecycle coordinator boundary

`lingpet_guardian_duration_lifecycle_coordinator.gd` owns the cross-owner
Guardian uptime lifecycle: active elapsed time and the six-second manual-stow
gate, recovery-gated resummon, summon/stow transition start and completion,
duration drain/warning dispatch, stage and replacement refill ordering, forced
expiry, and the exact skill/passive/VFX/mount/guard teardown sequence. Duration
pool math remains in `lingpet_duration_runtime_state.gd`; transition clock and
presentation state remain in `lingpet_guardian_transition_state.gd`. The
Nekuring deployment-preservation exception is admitted only by duration expiry.

`lingpet_egg_runtime.gd` keeps the public duration/toggle APIs plus legacy
internal field properties, all projecting through one canonical coordinator.
The coordinator retains the facade only through `WeakRef`, so it must not store
strong self Callables or rebuild per-tick dependency dictionaries. Do not
restore transition/audio/cleanup ordering to the facade. Regression guard:
`lingpet_guardian_duration_lifecycle_coordinator_owner_smoke.gd`, Guardian
toggle/stow/transition smokes, duration pool/round-transition and Spirit Water
smokes, Mokrin/mount cleanup paths, item-egg replacement, and the Lingpet egg-
runtime integration smoke.

### Lingpet Guardian Enhancement flow coordinator boundary

`lingpet_guardian_enhance_flow_coordinator.gd` owns the cross-owner gameplay
flow from an eligible Guardian to an applied enhancement: current/owned-pet
resolution, reward-context configuration, offer and live-candidate assembly,
weighted roll dispatch and last-moment revalidation, run-state application,
unlock-triggered loadout refresh, before/after result detail, fallback overfill,
runtime snapshot/owner synchronization, and the final presentation handoff.
The focused offer engine retains reservation/cooldown/localization policy;
`lingpet_guardian_enhance_applier.gd` retains weighted selection mechanics;
run data remains in `lingpet_guardian_run_state.gd`; and presentation remains
in the coordinator below.

`lingpet_egg_runtime.gd` keeps compatibility methods but must not regain the
applier/detail/buff-store imports, roll RNG, candidate loops, application
fanout, or detail-copy logic. The flow owner is configured once and reaches the
few remaining facade side effects through `WeakRef`, avoiding a retained
self-Callable cycle. Regression guard:
`lingpet_guardian_enhance_flow_coordinator_owner_smoke.gd`, Guardian
Enhancement offer/buff/cutin/modal smokes, single-growth-source, unlock/loadout,
duration transition, snapshot-sync, overflow absorption, and the Lingpet egg-
runtime integration smoke.

### Lingpet Guardian Enhancement presentation coordinator boundary

`lingpet_guardian_enhance_presentation_coordinator.gd` owns the applied-result
presentation lifecycle after Guardian Enhancement gameplay has committed: reel
icon cache filtering, trigger-source labeling and offer reservation commit,
result retention, cut-in state start/advance/cancel, animation and result-icon
prewarm, modal cooldown pause/resume safety, and loop-audio shutdown. The
five-phase clock remains in `lingpet_guardian_enhance_cutin_state.gd`; cache-
only host lookup and animation contracts remain in
`lingpet_guardian_enhance_cutin_overlay_host_resolver.gd`.

`lingpet_egg_runtime.gd` retains the public enhancement APIs and delegates the
presentation calls through one coordinator configured at construction. It must
not regain cut-in/prewarm/host-resolver fields, modal owner/registry storage,
runtime-perk pause/resume lookup, or direct enhancement-loop audio cleanup.
Regression guard:
`lingpet_guardian_enhance_presentation_coordinator_owner_smoke.gd`, Guardian
Enhancement cut-in/modal/buff smokes, single-growth-source smokes, round reset,
and the Lingpet egg-runtime integration smoke.

### Lingpet companion-motion coordinator boundary

`lingpet_companion_motion_coordinator.gd` owns the per-physics-tick priority
between mount, active-skill position ownership, Ring Dash, Starlight Tracking,
and ordinary patrol/free/sortie motion. It owns the canonical live position and
facing values, mount-time defense/click-reaction retirement, Ring Dash
release/resume plus immediate VFX/audio, and final motion-state synchronization.
Stable owners plus one weak facade reference are configured once during
`lingpet_egg_runtime.gd` construction; the coordinator must not retain bound
facade Callables, and the hot `update()` path must not build a dependency/result
Dictionary or a new Callable. Cached-only Smasher/Viper arbitration lives in
`lingpet_companion_player_runtime_resolver.gd`, including right-click claim,
active-dash snapshot, and player-guard availability. It must never fall back to
`get_instance()` from the physics tick.

`lingpet_egg_runtime.gd::_update_companion_motion()` remains a narrow facade
that passes only the current tick values. Its `_companion_pos` and
`_companion_facing_left` compatibility properties project directly through the
coordinator so save/restore, skill launch, draw, and focused fixtures retain one
canonical position. Patrol physics and its snapshot state remain in
`lingpet_companion_motion_state.gd`; feature-specific state stays in the mount,
Ring Dash, and Starlight owners. Do not restore cross-feature priority or
duplicate position/facing storage to the egg runtime. Regression guard:
`lingpet_companion_motion_coordinator_refactor_smoke.gd` (including runtime
facade release / zero-leak), `lingpet_companion_player_runtime_resolver_smoke.gd`,
mount runtime/saddle smokes, defense-owner and save/restore smokes, plus the
Lingpet egg-runtime outcome scenarios.

### Lingpet companion-defense state boundary

`lingpet_companion_defense_state.gd` owns all mutable predictive-guard fields,
the player-blockable and local-zone eligibility gates, shared-seed roll cadence,
re-predicted landing target, eased chase/arrival speed, actual per-tick step
speed, and guard-aura ramp. The motion host and battle owner are received only
for the current tick and are never retained; the patrol hot path allocates no
Dictionary, Array, or lambda for this delegation.

`lingpet_companion_motion_state.gd` keeps patrol/free-flight/sortie-flight
orchestration, shared position/direction/seed state, save/runtime snapshot keys,
and the established seven defense-field properties plus reset/clear and static
tuning methods as compatibility facades. Do not restore defense storage,
prediction, player reach policy, chase integration, or aura timing in the
motion facade. Flight styles continue to bypass defense entirely, and patrol
still re-seeds a zero direction only after the guard releases. Regression guard:
`lingpet_companion_defense_state_owner_smoke.gd`, the full
`lingpet_egg_runtime_smoke.gd` outcome suite, Solar Bolt reflection, satiety
freeze, snapshot-sync gating, and affinity hit-tag resolver smokes.

### Lingpet satiety runtime-state boundary

`lingpet_satiety_runtime_state.gd` owns the current league-exemption latch,
active/bench satiety progression call sequence, Light Eater and generic passive
drain-reduction aggregation with the 60% cap, exhaustion telegraph enablement,
KO/speed/ratio projection, and the combined snapshot-invalidation signal. It
retains no owner, collection, profile, or affinity-state reference between
ticks and adds no per-tick wrapper Dictionary or Array.

`lingpet_affinity_state.gd` remains the raw per-pet satiety/exhaustion data and
curve owner. `lingpet_egg_runtime.gd` keeps public satiety APIs, snapshot and
combat-gate call sites, and the exact latch -> battle-slot/passive reads -> KO
exemption recheck -> mutation order as narrow facades. Do not restore the
exemption backing field, passive reduction loop, or direct
`advance_satiety*()` calls in the egg facade. Regression guard:
`lingpet_satiety_runtime_state_owner_smoke.gd`, satiety/affinity/egg-runtime,
feed, save/restore, character-info satiety, companion defense/body/skill, and
snapshot-sync smokes.

### Lingpet overflow Guardian snapshot boundary

`lingpet_overflow_guardian_snapshot_builder.gd` owns current-versus-replacement
Guardian comparison projection: catalog and effective-profile reads, shared
skill/stat schema, exact empty-slot fidelity, pending-roll semantics, and
deep-copy caches. It borrows collection, loadout, Guardian-run, and hatch-roll
state only for the current call and retains none of those owners.

`lingpet_egg_runtime.gd` keeps the public `get_overflow_choice_snapshot()`
facade, asks `lingpet_overflow_choice_state.gd` for the base modal payload, and
invalidates the replacement projection when a preview loadout is rolled. Do
not restore comparison cache fields, catalog lookups, effective-level profile
assembly, or skill-entry schema construction to the egg runtime. Regression
guard: `lingpet_overflow_guardian_snapshot_builder_owner_smoke.gd`, main/item
egg overflow, one-Guardian roster, loadout-state, and profile-runtime-surface
smokes.

### Lingpet profile-derived player-stat boundary

`lingpet_profile_runtime_surface.gd` owns derived Guardian contributions to
player-hit gauge gain, player movement-speed multiplier, and character-info
stat-source rows. Multi-passive rows accumulate additive percentages from one
original base, gauge rows preserve the production `floor()` step after each
cumulative percentage, and inactive or unsupported queries fail closed.

`lingpet_egg_runtime.gd` retains the public `get_gauge_gain_per_hit()`,
`get_player_speed_multiplier()`, and `get_player_stat_breakdown()` compatibility
APIs, but supplies only the current profile and summoned-state gate. Do not
restore passive iteration, tooltip row dictionaries, cumulative percentage
math, or derived stat formulas to the egg runtime. Regression guard:
`lingpet_profile_runtime_surface_smoke.gd`, including its real-runtime Tailwind
and Resonance facade legs, plus snapshot-sync and one-Guardian roster smokes.

### Lingpet rail-card surface boundary

`lingpet_rail_card_surface_builder.gd` owns the narrow rail-card projection and
its two cache lifecycles: same-process/physics-frame reuse, static card identity,
per-slot static metadata, dynamic cooldown/windup state, per-skill runtime
snapshot merge, empty-slot defaults, and the shared two-slot interaction-permit
projection. Its static identity must include permit model, availability, and
active state so mount toggles cannot serve a stale card.

`lingpet_egg_runtime.gd` retains public `get_rail_card_surface()` and build-count
test facades, passes live profile/slot/skill owners only for the current call,
and reuses the builder's permit projection in the full runtime snapshot. Runtime
snapshot invalidation must also invalidate the rail frame cache, but the egg
runtime must not regain rail cache fields or card-schema merge helpers. Debug
forced pet activation must replace the real one-Guardian slot through
`lingpet_collection_state.gd`; changing `_pet_id` while leaving the owner slot
on the previous Guardian is invalid. Regression guard:
`lingpet_rail_card_surface_builder_owner_smoke.gd`, mount-saddle gate, shared
rail-card, permit-branch, snapshot-sync gating, debug-picker, and one-Guardian
overflow smokes.

### Battle modal-pause runtime-state boundary

`battle_modal_pause_runtime_state.gd` owns the persistent active-item cooldown
pause latch and the gameplay-loop audio cleanup required while a physics-blocking
modal is open. It retries the pause when the active-item runtime was unavailable,
pauses and resumes cooldowns exactly once per block interval, and stops gameplay
loops on every blocked physics tick so no loop can survive a modal that bypasses
the normal update driver. The state retains no owner, registry, module getter,
runtime, or audio reference between calls.

`battle_scene_frame_controller.gd` keeps the modal-gate position in the physics
ordering and delegates only `enter_modal_block()` / `leave_modal_block()` to its
single composed state object. Do not restore the cooldown-pause latch or direct
`GameplayLoopAudioCleanup` policy to the frame controller. Regression guard:
`battle_modal_pause_runtime_state_owner_smoke.gd`,
`active_item_cooldown_modal_pause_smoke.gd`, and
`battle_scene_frame_controller_modal_loop_audio_smoke.gd`.

### Character-info opening-transition boundary

`character_info_overlay_opening_fx_presenter.gd` owns the stateless 1.5-second
TAB ledger opening projection: backdrop dim, deterministic back/front cloud
composition, gold motes, and the center-anchored scroll-unfurl scale envelope.
`character_info_overlay_lifecycle.gd` remains the phase-clock owner. Player
TAB/ESC close requests reverse the same projection over 0.9 seconds, keep the
modal/cooldown pause alive while the ledger folds, and finalize cleanup only at
zero progress; non-input system cleanup retains immediate-close semantics.
`character_info_overlay_core.gd` prewarms the shared cloud texture and blocks
mouse/drag affordances until either transition settles.

`character_info_overlay_core.open()` also owns the two shared open-time audio
effects — the paper-scroll cue and BGM muffle ON — so every host (battle TAB
shortcut, plaza TAB, pause-menu entry) inherits them; host routers must not
replay the cue themselves. The muffle clears only when the overlay actually
reaches `active == false`, which is the folded frame for input closes and the
immediate return for system cleanup. The close cue is the asymmetric half: it
stays in `character_info_overlay_input_handler._handle_key` because it must
fire for TAB only, and must stay silent for ESC, discard-confirm cancel, drag
cancel, and repeated TAB during the same fold.
Do not add per-draw RNG, lazy texture loads, or an independently processing FX
host to this transition. Regression guard: `character_info_opening_cloud_smoke.gd`
(including the three silent-path legs), `character_info_bgm_muffle_smoke.gd`,
`battle_character_info_input_router_owner_smoke.gd`,
character-info input-redraw/prewarm smokes, and the windowed redesign capture.

### Character-info Lingpet presentation boundary

`character_info_overlay_lingpet_presenter.gd` remains the draw and compatibility
facade. It owns CanvasItem calls, texture lookup, hover publication, slot-tab
interaction, live panel composition, and forwarding the established public
helpers used by character-info consumers.

- `character_info_overlay_lingpet_vitality_projection.gd` owns runtime satiety
  merge, affinity/satiety strip state, layout, color, meter width, and hover
  zones.
- `character_info_overlay_lingpet_card_specs.gd` owns localized companion names,
  active/passive card specs, unlock-option filtering, and unlock candidate copy.
- `character_info_overlay_lingpet_stats_projection.gd` owns stat rows, row-budget
  policy, and cache hashes/payloads.
- `character_info_overlay_lingpet_ring_core_projection.gd` owns Ring Core/chip
  row geometry, labels, hover arbitration, tooltip specs, icon inset, and stable
  pip geometry.

These projection modules stay free of CanvasItem drawing and filesystem I/O;
runtime gameplay values continue to originate from the existing snapshot
builder and owners.

### Stage 6 Tetriser falling-tetromino boundary

`stage6_tetriser_tetromino_state.gd` owns the shared-RNG 5-10 second spawn
timer, five-shape falling pool, shape rotation/golden/motion rolls, assembly,
110ms snapped fall, drift/rotation budgets, installed-wall settling geometry,
1.5-second settled lifetime, cell-by-cell evaporation, super-cell scaling and
landing removal, solid-cell queries, and copied draw/debug snapshots. It is
constructed immediately after the host randomizes the shared
`RandomNumberGenerator`, before guard/wall/cube owners, preserving the original
spawn→guard→wall→cube RNG order.

Cross-domain effects stay coordinated by `stage6_tetriser_state.gd`: boss-gauge
debit and cube rebuild credit remain in the host; player stun/knockback/immunity
delegate to the player-explosion applier, golden-starpoint payloads delegate to
the starpoint owner, and debris, EMP, and sounds delegate to the combat-feedback
owner.
Lifecycle callbacks must run
synchronously at the mutation point; deferring a golden super-landing event
until after later blocks update would reorder shared RNG consumption. Do not
restore `_tetrominoes`, spawn-timer mirrors, shape catalogs, or fall/rotation
functions in the host.

### Stage 6 Tetriser obstacle-interaction boundary

`stage6_tetriser_obstacle_interaction.gd` owns the complete obstacle contact
policy while the focused tetromino, guard, and wall owners retain their state.
Ball collisions must preserve tetromino→guard→wall priority. Boss-serve balls
penetrate tetrominoes and walls but not guard bars; power smash destroys without
reflecting; a normal ball only bounces from a super tetromino. All other valid
contacts use the legacy entry-axis choice, minimum reflection speeds, and the
same Stage 6 `RandomNumberGenerator` for X jitter.

The same owner performs ordered dash/smoke/explosion sweeps and preserves each
item-zone gate and reason. Guard extraction occurs before its synchronous host
callback, matching the old mutation-before-debris/sound order. Host callbacks
synchronously coordinate the starpoint and combat-feedback owners plus cube-
rebuild progress. Do not move collision priority, reflection math, or attack-sweep
geometry back into `stage6_tetriser_state.gd`, and do not replace the shared RNG
with an independently seeded generator.

### Stage 6 Tetriser starpoint-drop boundary

`stage6_tetriser_starpoint_state.gd` owns the Stage 6 drop array and its full
lifecycle: payload construction, golden-block `star_dropped` one-shot mutation,
cell-center placement, movement/bounds/lifetime, Dowsing Pendulum attraction,
player overlap, runtime-perk reward collection and redraw, stage-leave/reset
cleanup, and copied draw/debug snapshots. It receives the same
`RandomNumberGenerator` instance as the tetromino/guard/wall/cube owners and its
constructor must not consume it; spawn calls remain synchronous at the original
combat event so later random rolls keep their order.

`stage6_tetriser_event_coordinator.gd` decides when a destroyed golden obstacle
or central-cube explosion creates a drop, but delegates the payload and all later
state changes to the owner. The host preserves the frame call point. Do not
restore `_starpoint_drops`, payload-building, motion, overlap, collection, or
draw-copy logic in the host.

### Stage 6 Tetriser combat-feedback boundary

`stage6_tetriser_combat_feedback_state.gd` owns all short-lived combat feedback
state: grouped debris rectangles and their 0.35-second lifetime, EMP ripples and
their 0.6-second lifetime, copied renderer snapshots, and the six frame-scoped
sound requests. Repeated cues deduplicate within a frame and flush in the
existing break→wall→super→big→shield→laser order. A flush consumes pending cues
even when `deps.audio` or an individual method is absent, preserving the old
one-frame request contract.

`stage6_tetriser_event_coordinator.gd` determines synchronous event reaction
order at the host's existing frame call points. Round, result, and stage-leave
cleanup plus the frame-end flush remain in the host; wrong-stage detection includes
feedback-only state so debris or an unflushed cue cannot survive and replay on a
later Stage 6 entry. Do not restore `_debris`, `_emp_ripples`, per-cue boolean
fields, lifetime/draw builders, or audio flush logic in the host.

### Stage 6 Tetriser player-explosion boundary

`stage6_tetriser_player_explosion_applier.gd` owns the stateless player response
to a landed tetromino explosion. Preserve this exact order: compute the player
center and scaled radius, return when outside, check Smasher cleanse immunity,
offer Celestial Armor consumption, apply the cleansable stun, then start the
stun-coupled knockback. A hit exactly on the radius remains valid; an out-of-
range hit must not consume armor, and cleanse immunity must short-circuit before
the mythic runtime lookup.

The contract remains an 80px base radius scaled by `cell_size / 20`, 30 normal
or 54 super stun frames, 12 normal or 24 super horizontal knockback, an 18-frame
window, and 0.88 decay. A player left of the center moves left; equal X follows
the existing rightward branch. `stage6_tetriser_event_coordinator.gd` owns only
the synchronous landing reaction and must not restore explosion constants,
immunity lookup, status, or movement calls.

### Stage 6 Tetriser event-coordination boundary

`stage6_tetriser_event_coordinator.gd` owns synchronous cross-owner reactions
for tetromino evaporation/landing/destruction, guard/wall removal, central-cube
explosion, and super-laser fire. Preserve the observable order inside each
event: live obstacle visitation and shared-RNG starpoint attempts first, then
debris/EMP, sound requests, player explosion, and cube rebuild/melt transitions
at their existing positions. The rejected wall-removal path intentionally keeps
its pre-validation starpoint attempt because changing it would change RNG order.

The coordinator receives existing focused owners after all shared-RNG owners are
constructed. It must not create or reseed an RNG, advance delta on its own, own
the public gauge/status, reset round state, or move its host call points. The
host keeps lifecycle→cube→laser→feedback→starpoint→sound-flush frame order and
the collision facade; it must not restore per-event side-effect helpers.

### Stage 6 Tetriser central-cube boundary

`stage6_tetriser_cube_state.gd` owns the complete logical central-cube
lifecycle: the shared-RNG 3×3 grid and 10-14 pass target, ball entry-edge
counting, one-second solve delay, one-shot explosion event, player/dash-only
five-destroy rebuild, laser-melt transition, delta-driven spin/melt clocks, and
the copied renderer/debug snapshot. It receives the same
`RandomNumberGenerator` instance as `stage6_tetriser_state.gd`; do not replace
it with an independently seeded RNG or change initialization order, because
that would perturb the stage's existing random sequence.

`stage6_tetriser_state.gd` remains the integration host and forwards the frame
call point. The event coordinator forwards ball position and qualifying
tetromino-destroy reasons, consumes the one-shot solve event, clears
tetrominoes/walls, asks the starpoint owner for the center drop, and asks the
feedback owner for debris/EMP/sound requests. Laser event consumption also
stays in the coordinator while the actual melt/rebuild transition delegates to
the cube owner. Do not restore `_cube`, spin, or melt-timer mirrors in the host.

### Stage 6 Tetriser guard-bar boundary

`stage6_tetriser_guard_state.gd` owns the guard bars' shared-RNG cooldown,
single/pair spawn and side balancing, assembly→slide→active motion, active-cell
collision lookup/removal, attack-sweep extraction, and copied draw/debug
snapshots. It receives the same `RandomNumberGenerator` instance as the Stage 6
host. Construction and full-match rearm order must remain between the falling
tetromino timer and the wall/cube setup so the existing stage RNG sequence does
not drift. Round clear removes bars but preserves the armed cooldown.

`stage6_tetriser_state.gd` keeps the public `boss_gauge` compatibility surface
and subtracts the exact cost returned by the guard owner. The obstacle-
interaction owner consumes guard collision/removal and attack extraction;
  the event coordinator routes debris and break-sound events to the feedback
  owner. Do not
restore `_guard_blocks`, guard transition functions, or host-side guard timer
mirrors.

### Stage 6 Tetriser edge-wall boundary

`stage6_tetriser_wall_state.gd` owns the fixed wall cooldown, shared-RNG
left/right tetromino-piece generation, assembly→installed→evaporating state,
six-second natural lifetime, hit-fast cell evaporation, installed collision and
attack queries, settling collision geometry, and copied draw/debug snapshots.
It receives the Stage 6 host's `RandomNumberGenerator` plus the canonical
tetromino shape/color catalogs; generation must preserve shape→rotation→column→
golden-roll order for every piece.

The wall owner returns gauge cost and debris/transfer payloads rather than
performing cross-domain effects. `stage6_tetriser_state.gd` retains public
  `boss_gauge`; the event coordinator owns starpoint/feedback reactions, while the obstacle-
interaction owner consumes wall collision and attack queries.
Round clear removes pieces but preserves the cooldown; full match reset rearms
it in the existing spawn→guard→wall→cube order. Do not restore `_wall_blocks`,
wall transition functions, or wall timer mirrors in the host.

### Stage 6 Tetriser super/laser boundary

`stage6_tetriser_super_state.gd` owns the 초인테트리서 activation threshold,
25-per-second drain/deactivation, 0.6-second intro, body-scale interpolation,
and the super-scoped one-shot laser's idle→charging→firing cycle. Its update
result deliberately distinguishes whether a frame started active from whether
it activated during that frame: the activation frame retains `charging` status,
while the final drain-to-zero frame retains `super`, matching the existing host
order.

The owner returns activation and laser-fire events and a copied renderer
snapshot. `stage6_tetriser_state.gd` retains the public `boss_gauge` and status
surfaces, 1.7× super-tetromino spawn integration, and activation sound. The
event coordinator owns laser sound, cube melt, tetromino/wall clear, and
EMP/debris order. Do not restore host-side super-active/scale/intro or laser
state/timer/fired mirrors.

### Shared actor customization-context boundary

`battle_draw_actor_customization_context.gd` owns the two existing draw-time
customization projections. Texture projection deep-copies caller entries,
adds only loaded `Texture2D` resources from the battle cache, and preserves
caller priority. Slot projection deep-copies caller slots, injects missing
Optimus defaults, delegates owned perk-part sockets to
`runtime_perk_visual_part_catalog.gd`, and adds the Smasher debug paddle only
as a final eligible fallback.

`battle_draw_actor_context.gd` retains character normalization, animation and
actor snapshot assembly, and publishes the returned texture/slot dictionaries
under the established public keys. Keep the owner's two direct projection
methods instead of returning an outer wrapper dictionary; the draw path must
not gain an extra payload allocation. Do not restore Optimus/perk/debug slot
recipes or texture-cache filtering in the facade. Regression guard:
`battle_draw_actor_customization_context_smoke.gd`,
`optimus_actor_context_smoke.gd`, `player_socket_part_overlay_smoke.gd`, and
`player_customization_debug_overlay_smoke.gd`.

### Shared actor Commando-context boundary

`battle_draw_actor_commando_context.gd` owns Commando-specific draw projection:
B2 animation/frame selection, anchor-table lookup and override resolution,
authored weapon-fire sheet/frame/facing policy, supply/reload/fire-support
radio-motion detection and radio frame timing, plus the dormant legacy weapon
overlay calibration table. It owns the `commando_weapon_anchor_table.gd`
instance and its animation constants.

`battle_draw_actor_context.gd` retains character normalization and final public
actor-context key assembly. It calls the focused owner directly and must not
recreate Commando helper methods, anchor-table lifetime, or overlay calibration
locally. Keep this boundary allocation-neutral: do not add a per-frame wrapper
dictionary or merge pass. Regression guard:
`battle_draw_actor_commando_context_smoke.gd` plus the existing Commando attack,
weapon-fire, B2 renderer, overlay, radio-call, resource-sprite, and anchor-table
smokes.

### Shared actor stage-context boundary

`battle_draw_actor_stage_context.gd` owns Stage 1-8 actor-source capture and
last-writer merge precedence. `capture_sources()` runs where the facade
previously read those sources: Stage 1 keeps Dalji/Gaksital skill and cooldown
ordering plus wall-flash projection; Stage 2 keeps background-before-skill;
Stage 4 keeps the five live map dependencies before wall flash; Stage 5 keeps
the optional `has_actor_draw_context()` fire-machine gate; Stages 3 and 6-8
retain their direct focused-state reads.

`merge_into()` mutates the established actor result after boss-dash context and
before active-item, mythic-item, and status contexts. It borrows source
dictionaries without copying or wrapping them, then releases its references so
large stage payloads do not remain pinned for another frame. Do not restore
stage-specific locals, wall-flash builders, or stage merge branches in
`battle_draw_actor_context.gd`, and do not replace this with a returned wrapper
dictionary. Regression guard: `battle_draw_actor_stage_context_smoke.gd` plus
the Stage 1 sprite/result, Stage 2 defense/playfield, Stage 4 map, Stage 5 visual
shell, Stage 6 state, Stage 7 slice, and status-effect integration smokes.

### Stage 6 Tetriser actor / boss-AI context boundary

`stage6_tetriser_context_builder.gd` owns the stable public key maps for actor
draw and boss-AI context. Actor projection preserves the existing base Stage 6
snapshots → super presentation → Crystal Shield presentation merge order; AI
projection preserves base gauge/tetromino/super values → Crystal Shield merge.
Later dictionaries keep last-writer priority through `merge(..., true)`.

Focused state owners still decide whether each returned array or dictionary is
a defensive copy or a borrowed snapshot. The context builder must not add a
second deep copy in the draw fanout. `stage6_tetriser_state.gd` retains the
public `get_actor_draw_context()` and `get_boss_ai_context()` facades but must
not restore key assembly or merge policy.

### Stage 6 Tetriser HUD-state projection boundary

`stage6_tetriser_hud_state_builder.gd` owns the pure boss-skill card projection:
the tetromino→guard→wall→super order, display metadata, timer-based progress for
the three automatic cost skills, gauge-gated ready/paused state, estimated
`next_activation_remaining`, and gauge-based super progress/casting state. It
must return fresh dictionaries and arrays so renderer or test mutation cannot
alter later snapshots.

`stage6_tetriser_state.gd` retains the public gauge/status and the actual
cooldown owners. Its `get_hud_context()` facade passes current gauge, gauge max,
charge rate, status, and focused timer/super owners directly to the builder.
Do not move gauge charging, gauge debit, timer lifecycle, or round-persistence
rules into this presentation owner, and do not restore `_build_hud_skills`,
cost-card math, super-card math, or HUD-only name/cost aliases in the host.

### Shared weather ice-motion boundary

`weather_ice_motion_state.gd` owns mutable player/boss ice motion: the player
dash timer gate, 25-pixel slide start, 0.96 decay, active-warp continuation
versus wall stopping, boss dash release, boss slide, and the normal 0.35 blend
plus 0.975 friction. It mutates the caller's existing motion result and returns
only whether a slide started, so the hot path creates no replacement result
containers.

`weather_event_state.gd` remains the public weather facade and retains weather
activation, runtime-registry lookup, dash cancellation, warp wrapping, and
particle payload dispatch. Reset the focused owner on weather reset/start/end,
and clear its relevant player or boss half whenever weather is inactive or not
ice. Particle emission remains behind the focused owner's start signal and at
the established position before later sand/wind processing. Do not restore the
raw ice-motion fields or duplicate its movement math in the facade.

### Stage 3 playfield rendering boundary

`stage3_playfield_renderer.gd` remains the CanvasItem-facing composition
facade for the Menhera court. It owns draw order, render-quality decisions,
performance labels, and compatibility wrappers used by stage consumers.

- `stage3_playfield_presentation_state.gd` owns the animation clock, emotional
  phase, floating-heart simulation, and stadium electric-spark burst state.
- `stage3_ellipse_geometry_cache.gd` owns unit, transformed, and closed-outline
  ellipse point caches and their bounded eviction policy.
- `stage3_playfield_texture_cache.gd` owns checker/border texture generation,
  image raster helpers, phase colors, and texture cache limits.

Keep state transitions and image/geometry cache construction out of the draw
facade. The facade may expose compatibility properties, but they must delegate
to these owners rather than recreate mutable mirror state.

### Stage 3 Menhera-tail starpoint boundary

`stage3_starpoint_state.gd` owns the Stage 3 drop and pickup-particle arrays,
payload generation, Star Detector bonus recursion/caps, per-frame motion,
Dowsing attraction, Lingpet Starlight Tracking, player overlap, reward/audio/
redraw dispatch, modal-safe compaction, visual-host cleanup, and actor draw
snapshots. It borrows the `stage3_boss_skill_state.gd` RNG and must not consume
it during construction. Preserve the established spawn order: tail position
rolls, base drop payload, base particles, then detector-bonus offset/payload/
particles.

`stage3_boss_skill_state.gd` remains the public skill-runtime facade.
`stage3_boss_skill_update_coordinator.gd` owns tail-hit frame placement,
Starpoint advancement, and the stage update/leave sequence, while
`stage3_boss_skill_handoff_coordinator.gd` owns impact/Starpoint/audio fanout.
Public context methods stay in the host and actor/snapshot composition belongs
to `stage3_boss_skill_context_builder.gd`. Do not restore drop or particle array
mirrors, lifecycle helpers, frame fanout, or payload RNG calls in the host.
Default draw fanout borrows owner arrays; diagnostic snapshots request deep
copies, so new context plumbing must not add an unconditional copy.

### Stage 3 Kuromi ball-eating boundary

`stage3_kuromi_eating_state.gd` owns Kuromi's ball-eating mutable lifecycle:
eligible center-overlap/chance entry, existing motion/Chaos Spear ownership
deferral, 20/40/50/120/180/190-frame phase transitions, spit-SFX lead timing,
ball hide/release output, Chaos Spear release callback, mouth particles, spit
trail, cooldown/reset, and actor draw projection. It borrows the boss-skill
host's RNG and must not consume it during construction. Preserve release RNG
order: locked-or-rolled angle, spit speed, 25 mouth particles, then the host's
normal prism burst.

`stage3_boss_skill_update_coordinator.gd` retains the exact cross-skill update
position, and `stage3_boss_skill_handoff_coordinator.gd` performs normal-prism
construction because that burst shares the same RNG and prism array as tail
hits. The owner exposes a one-shot prism request that the update coordinator
must consume immediately after eating update and before tail/psychoball update.
Public `kuromi_eating_*`, tongue, mouth, and spit-trail properties remain thin
owner-backed compatibility accessors. Do not restore raw eating fields or phase
helpers in the facade, and do not move awakening/fracture or tail scheduling
into the eating owner.

### Stage 3 Psychoball state boundary

`stage3_psychoball_state.gd` owns the Psychoball mutable lifecycle: 70-second
cooldown and boss-hit eligibility, normal/enraged duration, 0.12-second
hitstop, ball curve/rare teleport result writes, live tear-gas smoke-zone
resolution and neutralization, afterimage trails, neutralize particles,
loop-audio start/stop/sync, screen-shake feedback, round-effect cleanup, and
borrowed-or-copied actor projection. It borrows the boss-skill host RNG and
must not consume it during construction. Preserve active-update RNG order:
curve multiplier, teleport roll, then optional teleport coordinates; smoke
neutralization consumes only the payload-factory particle sequence.

`stage3_boss_skill_state.gd` remains the public facade. Its compatibility
properties delegate to the owner; boss-hit activation still resets the shared
boss gauge/red intensity there before owner audio/shake feedback is emitted.
`stage3_boss_skill_update_coordinator.gd` must preserve the early-hitstop return
before other skill updates, the normal Psychoball update after Kuromi/tail
updates, and the neutralize-particle tick before prism updates. Round-effect reset clears active
state without resetting the cooldown, while full reset restores 70 seconds.
Do not restore smoke queries, motion, particle payload construction, or raw
Psychoball state in the facade.

### Stage 3 Kuromi Tail Whip state boundary

`stage3_tail_whip_state.gd` owns Tail Whip targeting, 5-10-second cooldown,
one-second attack clock, two-second curve-after-hit, ball redirection/speed cap,
hit window, capped burst payload lifecycle, reset policy, and actor projection.
It borrows the Stage 3 RNG without construction-time consumption and calls
`stage3_tail_whip_geometry.gd` for the live 24-point curve and bounded collision
query; the geometry owner must not regress to a test-only helper or duplicate
implementation in the facade.

The owner returns one synchronous hit event after consuming only the tail-burst
seed. `stage3_boss_skill_update_coordinator.gd` must pass that event to
`stage3_boss_skill_handoff_coordinator.gd` immediately before Psychoball update,
in this order: strong-prism count/payload, impact effect, starpoint spawn, then
tail audio. This preserves the shared-RNG sequence
`tail burst -> strong prism -> starpoint`; do not defer the event or move the
burst payload back into the facade. Public `tail_*` properties remain thin
owner-backed compatibility accessors, while the facade retains shared prism,
starpoint, impact, and audio surfaces while the update coordinator retains
cross-skill frame ordering.

### Stage 3 Menhera Curse Chest state boundary

`stage3_curse_chest_state.gd` owns the Curse Chest mutable lifecycle: 35-second
cooldown, half-second windup, parabolic throw and landing, closed-chest lifetime
plus nudge/wobble response, dash-open transition, capped three-per-frame smoke,
two-second player-control reversal, timeout explosion particles and 120-pixel
falloff knockback through the shared Cleanse/Celestial Armor gates, one-shot
audio, effect/full reset policy, and borrowed-or-copied actor projection. It
borrows the Stage 3 RNG without construction-time consumption. Preserve RNG
order at activation (target x then y), while open (three smoke payloads per
frame), and on timeout (the authored 15-particle explosion payload).

`stage3_boss_skill_state.gd` remains the public facade, while
`stage3_boss_skill_update_coordinator.gd` owns update order. The facade's
`curse_*` compatibility properties delegate to the focused owner,
`stage3_boss_skill_scheduler.gd` retains activation priority, and
`stage3_curse_control_input_proxy.gd` continues to consume the facade's public
reverse query. Round-effect reset must clear live phase/smoke/explosion/reverse
state without resetting the cooldown or dormant target/position/timer fields;
full reset restores the 35-second cooldown. Do not restore raw Curse Chest
fields, phase helpers, or payload construction in the facade.

### Stage 3 Menhera Tear Shower state boundary

`stage3_tear_shower_state.gd` owns the Tear Shower mutable lifecycle: 25-second
cooldown, automatic normal/enraged activation, 400-frame duration, falling and
offscreen-recycle motion, reverse-order player collision/removal, per-hit audio,
source-scoped 130-frame slow stacking from `0.8` down to the `0.2` cap, Cleanse
immunity, effect/full reset policy, and borrowed-or-copied actor projection. It
borrows the Stage 3 RNG without construction-time consumption. Preserve RNG
order at activation (count, then each payload's y/x/speed) and recycle
(x, y, then speed); multiple same-frame hits must stack in reverse array order.

`stage3_boss_skill_state.gd` remains the public facade, while
`stage3_boss_skill_update_coordinator.gd` owns update order. The facade's
`tears_*` compatibility properties delegate to the focused owner, while
`stage3_boss_skill_scheduler.gd` keeps activation ahead of Curse Chest when both
cooldowns become ready. Round-effect reset clears the live shower while
preserving cooldown; full reset restores 25 seconds. Do not restore raw Tear
Shower fields, motion/slow helpers, or falling-tear payload construction in the
facade.

### Stage 3 Kuromi awakening state boundary

`stage3_kuromi_awakening_state.gd` owns the score-3 statue-awakening lifecycle:
eligibility and one-shot start, three-second timer/progress, progressive screen
shake, final fracture burst shake, awake/stonebreak audio, petrified/awakening/
awakened flags, forced-awake transition, round/full reset policy, and borrowed-
or-copied actor projection. It borrows the Stage 3 RNG without construction-time
consumption and constructs `stage3_kuromi_fracture_particles.gd` before the host
constructs its Starpoint owner, preserving the established shared-RNG owner
order.

`stage3_kuromi_fracture_particles.gd` remains the focused bounded particle
subsystem: pending spawn budget, fragment payload RNG, motion/decay, z-sort,
cap, and pending/live clear semantics. The awakening owner must call its update
before other Stage 3 skill updates even while awakening is inactive so live
fragments continue draining. Round reset preserves awakening flags/timer and
live fragments while clearing pending spawn; full reset restores the petrified
initial state and clears all fragments. The facade retains public compatibility
properties and `is_kuromi_awakening_active()` / `force_kuromi_awake()` wrappers,
not raw timer, feedback, audio, or fracture-helper ownership.

### Stage 3 Prism burst state boundary

`stage3_prism_burst_state.gd` owns the shared rainbow Prism-particle array,
normal 18-particle spawn, strong Tail-hit 18-22 count roll, payload generation,
frame-rate-scaled motion/gravity/damping/sparkle/life, in-place expiry
compaction, 60-particle newest-window cap, reset, and borrowed-or-deep-copied
actor projection. It borrows the Stage 3 RNG without construction-time
consumption. Preserve normal RNG as payload-only and strong RNG as count roll
then payload; cap trimming must not consume RNG.

`stage3_boss_skill_update_coordinator.gd` retains handoff placement and
`stage3_boss_skill_handoff_coordinator.gd` retains consumer order. A Tail hit
must remain `tail burst -> strong Prism -> impact -> starpoint -> audio`, and
the Kuromi eating owner's one-shot request must be consumed immediately into a
normal Prism burst before Tail/Psychoball updates continue. Public
`prism_particles` remains a thin owner-backed compatibility property. Do not
restore raw Prism arrays, payload calls, motion, compaction, or cap helpers in
the facade.

### Stage 3 boss-skill scheduler boundary

`stage3_boss_skill_scheduler.gd` owns the draw-free policy shared across the
focused Stage 3 skill owners: canonical pause-key precedence with the legacy
tear-gas fallback, exact Psychoball -> Tear Shower -> Curse Chest -> Tail Whip
-> Kuromi eating cooldown fanout, awakened/not-overdrive Tail cooldown gating,
serve/ball/awakening/overdrive activation guards, one-writer Tear Shower ->
Curse Chest -> Tail Whip activation priority, and public status priority.

The scheduler does not own clocks, RNG, payloads, reset state, audio, or draw
contexts. `stage3_boss_skill_update_coordinator.gd` must call it at the existing frame
positions: no cooldown/activation work during the Psychoball hitstop early
return, cooldown update before skill-owner updates, activation after Prism
update, and status resolution after Psychoball audio sync. Tail activation must
read `Time.get_ticks_msec()` only after Tail is selected. Keep public facade
fields and compatibility setters routed to the individual skill owners.

### Stage 3 boss-skill HUD state builder boundary

`stage3_boss_skill_hud_state_builder.gd` owns the pure public HUD payload: the
eight top-level Stage 3 HUD keys, Korean Menhera name, disabled legacy wand
gauge flag, clamped compatibility-gauge progress, fixed Tear Shower -> Curse
Chest -> Psychoball card order, labels/colors, casting/ready/charging rules,
cooldown progress, and auto-vs-hit trigger metadata. Every build must return
fresh card dictionaries and a fresh array because the renderer sorts its local
entries in place.

`stage3_boss_skill_state.gd::get_hud_context()` remains the compatibility facade
and passes the live host status/gauge plus the three focused skill owners. The
builder must not mutate those owners or absorb clocks, activation, RNG, reset,
render sorting, tooltip, texture loading, or CanvasItem work. Those stay with
the state owners and `stage3_boss_skill_hud_renderer.gd`.

### Stage 3 boss-skill context builder boundary

`stage3_boss_skill_context_builder.gd` owns read-only actor and diagnostic
projection. It stores the eight focused owner references once, normalizes the
base gauge/ready/red keys, and preserves merge order exactly: Prism, Kuromi
awakening, Tear Shower, Curse Chest, Psychoball, Tail Whip, Kuromi eating, then
Starpoint. Later owners retain overwrite precedence.

The facade must construct this builder after `_starpoint_state` is created so
owner identity is valid without changing shared-RNG construction order. Normal
actor fanout forwards `copy_arrays=false`; diagnostic snapshots fan out with
`true` and append only the established status/gauge/ready and five cooldown/
hitstop fields. The builder must not allocate an owner list per frame, mutate an
owner, deep-copy borrowed mode itself, or absorb runtime/reset/draw behavior.

### Stage 3 boss-skill lifecycle boundary

`stage3_boss_skill_lifecycle.gd` owns the ordered reset fanout across Tear
Shower, Curse Chest, Psychoball, Tail Whip, Kuromi eating, Kuromi awakening,
Prism, and Starpoint. It stores the eight owner references once after
Starpoint construction, owns no mutable frame state or RNG, and preserves the
existing effect-clear order exactly.

Full reset restores Psychoball/Tear/Curse initial cooldowns, `charging` status,
zero gauge/redness, the fixed five-second Tail initial cooldown, and petrified
Kuromi. Round reset clears the same live effects but preserves the three skill
cooldowns, current status, and awakening flags/live fracture state; it rerolls
Tail only after effect cleanup so shared-RNG consumption stays in place.
`stage3_boss_skill_state.gd` retains the public `reset()` / `reset_round()`
facades. `stage3_boss_skill_update_coordinator.gd` owns stage-leave ordering:
detect Starpoint runtime state, invoke the full host reset, then hide detached
Starpoint visual hosts. Do not collapse the two reset policies or move detached-
host cleanup into the lifecycle coordinator.

### Stage 3 boss-skill compatibility surface boundary

`stage3_boss_skill_compatibility_surface.gd` is the inherited static property
surface for 67 legacy fields spanning Tear Shower, Curse Chest, Psychoball,
Tail Whip, Kuromi awakening/eating, and Prism. Every getter/setter must route to
the exact focused owner instance; the surface must not introduce mirrored
values, dynamic `_get()`/`_set()` lookup, frame work, RNG, lifecycle, or
cross-skill policy. Inheritance must preserve the RefCounted runtime type,
static property names/types, and `get_property_list()` visibility.

`stage3_boss_skill_state.gd` still constructs the seven owners in the existing
Tears -> Curse -> Psychoball -> Tail -> awakening -> eating -> Prism order,
then seeds the shared RNG and constructs Starpoint as before. The facade owns
construction and public methods; frame coordination belongs to the update
coordinator. Compatibility inheritance is not a reason to add new proxy
properties when a focused query/snapshot can serve a new consumer.

### Stage 3 boss-skill handoff coordinator boundary

`stage3_boss_skill_handoff_coordinator.gd` owns only synchronous cross-owner
producer-consumer fanout. A non-empty Tail event must dispatch strong Prism,
unit energy impact, Starpoint spawn, then tail audio in that exact order. Prism
must precede Starpoint because both consume the shared Stage 3 RNG. Missing
impact/audio sinks remain optional and must not suppress Prism or Starpoint;
invalid event positions retain the zero-vector fallback.

Kuromi eating retains its own release state and one-shot request. The update
coordinator calls the handoff coordinator to consume that request immediately
after eating update and before Tail update; the handoff coordinator spawns one
normal Prism only when the request is a `Vector2`. The handoff coordinator owns no clocks, producer
state, result mutation, activation policy, rendering, or lifecycle reset. Keep
these two handoffs at their established frame positions and do not absorb the
Tail/Kuromi state machines into this owner.

### Stage 3 boss-skill update coordinator boundary

`stage3_boss_skill_update_coordinator.gd` owns the complete draw-free per-frame
order after owner construction: off-stage Starpoint-state detection, full host
reset and detached-host cleanup; delta clamping to 0.05 seconds; external
forced-awake handling; awakening, Tail-burst, and Starpoint early ticks; the
Psychoball hitstop short circuit; scheduler cooldown and activation positions;
Tear, Curse, Kuromi, Tail, Psychoball, and Prism advancement; handoff call
positions; boss-red decay; Psychoball audio sync; and final status publication.

It stores only injected focused-owner/coordinator references and the injected
stage id. It must not retain the host, own skill clocks/payloads/RNG, render,
reset focused state directly, or absorb scheduler/handoff policy. The public
host passes itself only for status/red publication and the established reset
facade, so no RefCounted cycle is introduced. Preserve normal, hitstop, paused,
and stage-leave branches exactly; `stage3_boss_skill_update_coordinator_smoke.gd`
guards their call order and clamped timing.

### Stage 3 boss-skill constant ownership boundary

`stage3_boss_skill_state.gd` owns only `STAGE_ID`, `BOSS_GAUGE_MAX`, and
`BOSS_GAUGE_GAIN_ON_HIT`. These describe the facade's route and public gauge
policy. Timing, geometry, collision, payload, particle-budget, and lifecycle
constants belong to the focused state owner that implements that behavior.

Consumers and tests must preload that focused owner and reference its constant
directly. Do not add facade-level aliases for convenience or build another
constant wrapper: re-exporting creates a second ownership surface that can
drift while hiding the real dependency. The exact three-name facade boundary
is guarded by `stage3_boss_skill_constant_ownership_smoke.gd`.

### Stage 4 Ponk illusion-ripple state boundary

`stage4_ponk_illusion_state.gd` owns the illusion-ripple mutable lifecycle:
four-point permanent unlock, awaken stages 0-4, serve-wait ceremony, first-cast
countdown, one-shot awaken burst, active duration, automatic cooldown, reset
policy, enraged aura state/intensity, and actor/debug projection. It is a
draw-free `RefCounted` owner and must not allocate or control FX nodes.

`stage4_ponk_runtime_coordinator.gd` retains the exact update order around
cooldowns, illusion ceremony/activation, magnetic field/projectile, meditation,
and the same-tick illusion-duration skip.
`stage4_ponk_presentation_coordinator.gd` retains fallback decisions and draw
order;
`stage4_ponk_fallback_fx_renderer.gd` owns procedural fallback drawing,
`stage4_ponk_fx_context_builder.gd` builds host-facing payloads, and
`stage4_ponk_fx_host_coordinator.gd` owns magnetic,
meditation, illusion-ripple, and awaken-aura runtime-host lifecycle. Existing
public illusion properties are owner-backed compatibility accessors, not
mutable mirrors. Do not restore raw illusion fields or ceremony/activation
helpers in the facade, and do not move cross-skill activation priority into the
illusion owner.

### Stage 4 Ponk magnetic-field state boundary

`stage4_ponk_magnetic_field_state.gd` owns refraction-field cooldown,
activation, normal/enraged radius and duration, live center, curve-angle and
velocity math, 2.2x base-speed cap, one-shot release-speed restoration, reset
policy, and actor/debug projection. It is a draw-free, RNG-free `RefCounted`
owner and must not control audio, projectile state, scene annotations, or FX
nodes.

`stage4_ponk_ball_interaction_coordinator.gd` owns base-speed lookup, scene
dictionary writes, and meditation control/release -> magnetic release -> active
curvature sequencing. `stage4_ponk_runtime_coordinator.gd` retains gauge/audio
activation side effects, cross-skill update priority, field-expiry-to-projectile
spawn, and same-tick projectile motion before meditation. Round reset
deliberately preserves dormant radius/enraged/center/release-floor fields; stage
leave clears only the active flag. Public field properties are owner-backed
accessors, not mutable mirrors.

### Stage 4 Ponk magnetic-projectile state boundary

`stage4_ponk_magnetic_projectile_state.gd` owns the post-field projectile's
mutable gameplay state: spawn/reset, normal/enraged horizontal homing, vertical
motion and contact multiplier, elapsed/velocity tracking, player-rect overlap,
floor exit, fade capture/decay, and actor/debug projection. It consumes no RNG
and owns no status, audio, or node-backed FX side effects.

`stage4_ponk_runtime_coordinator.gd` retains field-to-projectile orchestration
and calls projectile update at the established point before meditation;
`stage4_ponk_presentation_coordinator.gd` owns magnetic fallback decisions.
`stage4_ponk_ball_interaction_coordinator.gd` owns player
geometry, overlap order, immunity checks, shared slow-status application, scene
annotations, and collision-time audio stop. The fallback renderer owns
procedural drawing, the FX context builder owns host payload projection, and the
FX coordinator owns detached-host sync/cleanup. Public projectile properties
remain owner-backed compatibility accessors rather than mutable mirrors. Do not
restore raw projectile fields, motion/fade helpers, collision policy, or
projectile-only overlap geometry in the host.

### Stage 4 Ponk meditation state boundary

`stage4_ponk_meditation_state.gd` owns meditation's mutable lifecycle: orbit
position, trail/particle/circle payload mutation, cooldown, one-shot ball
handoff, detached release-FX state, reset policy, and actor/debug projection. It
borrows the Stage 4 RNG without consuming it during construction or activation.
On the final active frame, preserve this exact RNG order: particle spawn gate,
optional particle payload, release bonus, speed factor, then release angle.
Activation deliberately accepts separate live boss and circle centers; do not
collapse the authored circle center onto later orbit updates.

`stage4_ponk_ball_interaction_coordinator.gd` retains base-ball-speed lookup
after the final particle roll plus speed-cap/spin/release scene flags and the
meditation-before-magnetic handoff order. `stage4_ponk_runtime_coordinator.gd`
retains activation/release audio timing and cross-skill update order;
`stage4_ponk_presentation_coordinator.gd` retains meditation fallback
decisions. The fallback renderer owns procedural drawing, the FX context builder
owns host payload projection, and the FX coordinator owns runtime-host prewarm,
sync, and cleanup.
Public meditation properties are owner-backed compatibility accessors rather
than mirrors. Round reset preserves
dormant angle/ball position, while stage leave clears only active visual
transients and preserves the legacy pending/cooldown fields; do not homogenize
those policies without an explicit behavior change.

### Stage 4 Ponk ball-interaction coordinator boundary

`stage4_ponk_ball_interaction_coordinator.gd` owns the two order-sensitive
public gameplay paths behind the skill facade: meditation ball control and
release, magnetic release and curvature, and magnetic-projectile/player
collision. Preserve the exact motion order: active meditation control returns
immediately; otherwise consume meditation release, consume magnetic release,
then apply active curvature and the 2.2x base-speed cap. Preserve collision
order: stage/active gate, player overlap, immunity block with fade/audio stop,
then shared cleansable slow status and contact-speed/counter annotations.

The coordinator also owns boss/player center and player-rect normalization,
minimum-rally/base-speed dependency precedence, shared freeze gates, cleanse
immunity lookup, and collision-time magnetic-loop cleanup. It is stateless and
owns no RNG, mutable skill clocks, frame advancement, nodes, assets, drawing,
activation audio, or field-to-projectile spawning. `stage4_ponk_skill_state.gd`
must keep its public `apply_ball_motion` and `resolve_ball_collision` signatures
as thin delegates, while the runtime coordinator composes the geometry/speed/
freeze helpers. Do not split the three-step ball handoff across independent
callers or move mutable fields out of the focused state owners.

### Stage 4 Ponk runtime coordinator boundary

`stage4_ponk_runtime_coordinator.gd` owns Ponk's shared gauge/ready scalars and
effect clock plus all cross-owner runtime flow: score unlock delegation,
boss-hit meditation activation, forced activation, cooldown/pause/freeze
policy, magnetic -> same-tick projectile -> meditation -> illusion update order,
audio play/stop/sync dispatch, and round/stage/full-reset orchestration. Preserve
the same-tick illusion activation skip and field-expiry projectile motion; do
not collapse either into independent owner updates.

Reset semantics are intentionally mixed. Full reset clears gauge/clock and all
progress; round reset preserves gauge/clock and illusion unlock while restoring
skill cooldowns; stage leave clears only authored transients and preserves the
legacy magnetic/meditation pending-release and cooldown fields. Stage leave must
also directly stop every detached host, including meditation, after its visual
transients are cleared. The coordinator may invoke the FX-host and ball-
interaction coordinators but owns no Nodes, RNG, rendering, payload arrays, or
focused skill-state clocks. `stage4_ponk_skill_state.gd` keeps its public method
signatures and shared scalar properties as thin delegates/accessors.

### Stage 4 Ponk presentation coordinator boundary

`stage4_ponk_presentation_coordinator.gd` owns presentation-only orchestration:
the fixed fallback-texture -> magnetic-host -> meditation-host -> illusion-host
-> awaken-aura-host static asset-prewarm sequence, draw-clock synchronization,
pipeline/attachment status aggregation, and exact magnetic field -> projectile
-> meditation -> awaken aura -> illusion draw fanout. It also owns host-active
gates and the creation-frame fallback decision while a deferred FX host is not
yet attached.

The coordinator borrows the one live runtime coordinator, four focused state
owners, FX context builder, replaceable fallback renderer, and FX-host
coordinator. It must not mirror gameplay state, own RNG, advance skill updates,
or participate in reset policy. `stage4_ponk_skill_state.gd` retains public
draw/prewarm/status signatures and established private diagnostic methods only
as thin delegates. Preserve shared collaborator identity: runtime cleanup and
presentation sync must continue addressing the exact same FX-host coordinator.

### Stage 4 Ponk skill-card projection boundary

`stage4_ponk_skill_card_state_builder.gd` owns the read-only three-card HUD
projection: magnetic-field, meditation, then illusion-ripple order; Korean
display copy; trigger metadata; active/ready/charging/locked status; normalized
cooldown and first-awaken countdown progress; seconds-facing remaining/total
values; and fresh Dictionary allocation per call. It reads the three focused
runtime state owners but must not mutate their clocks or activation state.

`stage4_ponk_skill_state.gd` retains the public `get_skill_card_hud_context`
facade, supplies its clamped meditation trigger chance, and owns no card-only
IDs, strings, or progress helpers. The renderer remains a separate consumer;
do not move texture/cache/layout work into the pure builder, and do not restore
parallel card projection in the host.

### Stage 4 Ponk FX-host lifecycle boundary

`stage4_ponk_fx_host_coordinator.gd` owns the four detached FX-node references,
existing-child adoption, duplicate-safe deferred `add_child`, per-host runtime
node prewarm, fixed magnetic -> meditation -> illusion-ripple -> awaken-aura
staged prewarm order, capability/runtime-asset gates, active sync, awaken-aura
global cleanup registration, and immediate deactivation. Invalid/null canvases
complete staged prewarm without allocating hosts, and completed prewarm remains
idempotent.

Preserve the first-frame fallback contract: a newly created host is prewarmed
and synced before its deferred attachment, but coordinator sync returns `false`
until `get_parent()` is non-null. `stage4_ponk_runtime_coordinator.gd` invokes
round/stage/full-reset deactivation, while
`stage4_ponk_presentation_coordinator.gd` keeps modular-host static prewarm
sequencing, fallback decisions, and cross-effect draw order. The skill facade
keeps public compatibility accessors. `stage4_ponk_fx_context_builder.gd`
supplies the payload passed to each sync, while
`stage4_ponk_fallback_fx_renderer.gd` draws the creation-frame fallback. Do not
move draw/projection responsibilities into the coordinator or change deferred
attach to immediate attach without an explicit rendering-behavior change.

### Stage 4 Ponk FX-context projection boundary

`stage4_ponk_fx_context_builder.gd` owns the exact host-facing Dictionary shape
for magnetic field/projectile, meditation/release, illusion ripple, and awaken
aura. It resolves owner defaults against live draw-context overrides, applies
the established progress/time/radius clamps, normalizes `Vector2i`, derives
render scale and illusion view size, selects the magnetic sheet frame, switches
meditation release trails/ball position, and computes aura center/intensity.

The builder is node-free, RNG-free, audio-free, draw-free, and must not mutate
gameplay clocks. Each top-level payload is fresh, but meditation trail arrays
remain borrowed exactly as before to avoid per-draw copies. The skill facade
retains thin `_build_*_fx_context` delegates for compatibility; do not restore
parallel payload math there or move host attach/sync/cleanup into this builder.

### Stage 4 Ponk procedural fallback renderer boundary

`stage4_ponk_fallback_fx_renderer.gd` owns the retained magnetic sheet cache and
status plus the draw-only magnetic-field, projectile/fade, and meditation
recipes. Preserve exact circle/sheet/ring/core order, atlas cell selection,
clock-driven phases, shake application, fade alpha, payload filtering, radius
floors, and borrowed meditation arrays. A missing sheet keeps the existing
procedural circle in the same layer slot.

`stage4_ponk_presentation_coordinator.gd` retains the host-handled gates and cross-effect
magnetic -> meditation -> awaken-aura -> illusion order. A newly created host
is still unattached for its first sync, so the presentation coordinator must
call this renderer on that frame. The renderer owns no gameplay mutation, RNG, audio, FX-host
lifecycle, or fallback decision; do not move the fanout into it or let it
activate/deactivate modular hosts.

### Stage 4 star-bird starpoint-state boundary

`stage4_bird_starpoint_state.gd` retains the star-bird event's drop and particle
collections and owns crow-drop clamping, Star Detector bonus fanout, the exact
shared-RNG payload/offset order, newest-window caps, bounded motion, Dowsing,
Starlight Tracking, circular player-paddle overlap, modal-safe in-place
compaction, reward -> collection-particle -> audio -> redraw order, and particle
advancement. Construction borrows the bird facade's existing RNG without
consuming it.

`stage4_bird_event.gd` retains bird spawn timing/motion, gold dust, catch and
explosion flow, rendering, visual-host cleanup, and actor/debug projection.
Its public starpoint arrays and private compatibility methods are owner-backed
accessors/delegates, not mirrored state. Do not restore starpoint payload,
collection, or particle mutation to the bird facade; do not give the focused
owner an independent RNG or rendering/host lifecycle.

### Main-menu ambient boundary

`main_menu_ambient.gd` remains the `Control` draw facade for color drift, sky
lights/silhouettes, dust, title glint/gate-seam accents, and vignette composition.

- `main_menu_ambient_state.gd` owns seeded particle/light/silhouette simulation
  and its deterministic RNG order. The host clears that runtime payload and
  releases the state owner directly on tree exit.
- `main_menu_ambient_projection.gd` owns source/screen projection, clipping,
  sweep/fade/hash math, and offline mask classification rules.
- `main_menu_ambient_mask_data.gd` plus
  `assets/ui/main_menu/main_menu_ambient_masks.res` own the validated baked
  Hangul-title/gate-seam masks.
- `assets/ui/main_menu/main_menu_ambient_vignette.res` owns the baked vignette
  raster. The two `tools/bake_main_menu_ambient_*.gd` scripts are offline-only
  regeneration paths.

Do not restore runtime source-image readback, pixel classification, vignette
rasterization, or texture upload in the menu's `_ready()`/draw path. The host
may copy baked byte arrays once and should keep its own `_process()` disabled
while the intro reveal owns timing.

### Main-menu shell boundary

### Mugong numeric-progression boundary

`runtime_perk_progression.gd` is the canonical numeric owner for the 37
authored five-level Mugong: each perk maps to named lanes with authored values,
overflow policy, milestone levels, and polarity. Runtime, converted-perk,
tooltip, and overflow-description consumers must query this owner instead of
rebuilding level arithmetic. The index is built once at script load; hot-path
reads are O(1), return scalar values or stable authored-array references, and
must not add applied-value caches or per-query deep copies. The distinct
`kick_enhance` authored/runtime lanes and `item_polish` general/mythic lanes are
intentional compatibility records pending separate design decisions.

`runtime_perk_catalog.gd` remains the registration and player-facing authored
description owner. `runtime_perk_progression_equivalence_smoke.gd` seals all 37
catalog entries and every numeric lane through effective Lv.12, including the
live fusion-display projection path and a deliberately corrupted in-memory RED
fixture. `runtime_perk_effective_levels.gd`, `perk_conversion_values.gd`,
`runtime_perk_overflow_descriptions.gd`, and character/item consumers are
projections of the numeric owner, not competing sources.

### Angel Dice runtime boundary

`main_menu_scene.gd` remains the title-screen orchestration host. It owns scene
nodes, input/navigation, reveal/settings/quit routing, transition tweens and
drawing, character-select prewarm polling, and the final scene change.

- `main_menu_start_transition_state.gd` owns only the deterministic one-second
  transition clock, normalized progress, and one-shot completion edge.
- `main_menu_gate_transition_projection.gd` owns draw-free gate-opening panel,
  spirit-light beam, and whitewash geometry/envelopes. The scene remains the
  drawing/audio/navigation owner.
- `main_menu_touch_start_prompt.gd` owns the prompt label/control, pulse clock,
  localized input-neutral copy, centered fill anchors, and faded-ribbon drawing.
- `main_menu_audio_controller.gd` owns menu BGM/start-SFX players, boot-player
  adoption, mute state, stream release, and settings-adapter lifetime.
- `main_menu_audio_stream_policy.gd` owns bus/default-volume setup and creates a
  private looping stream duplicate. Neither the boot flow nor menu may mutate
  `ProjectResourceLoader`'s path-cached `AudioStream` instance.
- `main_menu_audio_settings.gd` and `main_menu_settings_registry.gd` provide the
  narrow AudioServer and dependency-registry adapters required by the shared
  pause/settings overlay.

`boot_flow_scene.gd` keeps logo/loading/progress/navigation ownership and uses
the same audio controller for early BGM preloading. Both boot and menu must
drain any in-flight `character_select_prewarm.gd` threaded request before the
owning scene is destroyed because Godot exposes no cancellation API. They must
also release their scene-local `RefCounted` state/controller collaborators in
`_exit_tree()`; relying on final ObjectDB shutdown leaves zero-reference
instances behind when the application quits on the live main-menu scene.

### Application shutdown boundary

`application_quit_coordinator.gd` is the process-lifetime owner for final
application exit. The main-menu quit action and `NOTIFICATION_WM_CLOSE_REQUEST`
route through `request_quit()`; the headless load wrapper uses the same path by
passing a frame-count user argument. The coordinator disables SceneTree's
automatic window-close acceptance, stops and detaches streams from all
`AudioStreamPlayer`, `AudioStreamPlayer2D`, and `AudioStreamPlayer3D` nodes,
frees the current scene while the engine is still alive, clears loader caches,
and waits for the audio mix thread plus zero-reference owners to retire before
calling `SceneTree.quit()`.

Scene changes are a distinct shutdown race: `change_scene_to_file()` can leave
`current_scene == null` for a deferred gap and install the incoming scene after
the quit request. The coordinator must keep the tree advancing, watch that gap,
and restart its quiet window whenever a late scene or audio player appears. Do
not pause the tree during this drain; doing so strands the engine's deferred
scene-change object. The final delay is implemented as a node process state
machine, not an `await` coroutine that could itself still own a RefCounted
function state at engine shutdown.

Detached loading-cameo hosts follow the same terminal rule.
`loading_cameo_host.gd::tear_down()` releases sprite textures/materials, label
font ownership, and RNG state; boot and battle loading owners remove and
synchronously `free()` the host. `remove_child()` plus `queue_free()` is not a
safe final-shutdown contract because the last message-queue flush can race
ObjectDB cleanup.

`run_headless_load_check.ps1` requires the graceful-shutdown marker and now
fails on any `ObjectDB instances leaked` warning. Its later engine-level
`--quit-after` remains only a bounded hang fallback and cannot satisfy a green
run by itself. `application_quit_coordinator_smoke.gd` seals early scene/audio
release; `battle_loading_screen_renderer_smoke.gd` seals synchronous detached
cameo-host destruction.

### Character-select presentation boundary

`character_select_screen.gd` remains the `Control` orchestration facade. It
owns scene-tree setup/teardown, input and selection routing, drawing, texture
lookup, compatibility methods, battle handoff, and applying values to the live
preview and confirm-flash overlay.

- `character_select_layout.gd` owns draw-free responsive card/action/info-panel
  geometry, text wrapping, badge measurement, and lore-row projection.
- `character_select_confirm_intro_state.gd` owns the confirm one-shot clock,
  pending scene path, exit-flash hold/edge, and immutable flash payload.
- `character_select_skill_preview_resolver.gd` owns runtime-id normalization,
  lazy skill-config selection, icon-path-to-skill mapping, and tooltip metadata
  formatting. Character skill data remains in the existing character configs.
- `character_select_audio_controller.gd` owns the BGM and two voice players,
  mute/loop state, delayed voice playback, and synchronous teardown.

`character_live_preview.gd` remains the `@tool` texture-loading, animation,
first-use trim scheduling, VFX-host, and CanvasItem drawing owner.
`character_live_preview_sheet_geometry.gd` owns only trim metadata parsing,
alpha-bound sampling, source/target projection, fit, and scale math. Runtime
texture readback must stay outside draw/process hot paths and under the existing
first-use lifecycle in the host.

The cumulative module ownership log was moved to
`docs/godot_module_ownership_ledger.md` to keep this architecture guide
focused on current rules and module boundaries.

When adding a module, moving ownership, deleting duplicate fallback code, or
changing a domain boundary, update that ledger with one concise entry. Do not
append long bug histories or per-feature playbooks here.

## Known Smoke Baselines

Non-fatal warnings that the Godot wrappers do NOT count as failures, but that
should be recognized so future refactors do not chase them as regressions.
`godot/tools/godot_output_classifier.ps1` owns the shared line classifier used
by smoke, headless-load, warning-scan, and focused QA wrappers. It rejects
line-start severity markers `SCRIPT ERROR`, `ERROR:`, and `FATAL:`. Diagnostic
words such as `Parse Error`, `Invalid call`, or `GDScript backtrace` in ordinary
output are not standalone failure markers; real engine failures still surface
through a severity line, nonzero exit, or missing smoke `ok` marker. The sole
ignored severity line is the exact Windows headless environment message
`ERROR: Failed to read the root certificate store.`; merely containing that
phrase does not exempt another error. Leak-sensitive QA remains a separate
predicate so the certificate exception cannot suppress ObjectDB/RID leaks.

### Cleared: standard headless-load intermittent shutdown leak

- Baseline: the uncoordinated 1,200-frame boot-to-main-menu load emitted
  `ObjectDB instances leaked at exit` in 2 of 5 sequential runs. Verbose quiet
  probes showed a zero-reference generic `RefCounted`; a 600-frame adversarial
  probe at the boot/menu transition also exposed a late `AudioStreamWAV` and
  `AudioStreamPlaybackWAV` pair.
- Root causes: final `SceneTree.quit()` overlapped scene/resource teardown;
  `change_scene_to_file()` could install a new menu and start BGM during the
  shutdown drain; and `LoadingCameoHost` was detached then only queued for a
  later free.
- Current contract: `ApplicationQuitCoordinator` repeatedly drains late
  scenes/audio through a quiet window, while the cameo host tears down and
  frees synchronously. The transition-boundary probe passed 8/8 and the
  standard 1,200-frame wrapper passed 5/5 after the fix.
- Regression gate: the standard wrapper must observe the graceful marker and
  fail on any ObjectDB leak warning. Do not make it verbose merely to alter
  shutdown timing or suppress this race.

### Cleared: Plaza academy and Lingpet-store fixture registry leaks

- `plaza_academy_menu_smoke.gd` previously printed `ok` and then retained 77
  resources because its `FakeRegistry.instances` owned `RuntimePerkState` while
  the live stats context pointed back to that registry. Frame draining and
  `RuntimePerkState.reset()` did not break the ownership cycle.
- `plaza_lingpet_store_menu_smoke.gd` had the same missing production teardown
  contract and could intermittently retain renderer RIDs plus Lingpet resources.
- Both fixtures now synchronously free their scene/owner, call the fake
  registry's `clear_all()` just like `battle_scene_teardown_lifecycle`, and opt
  into `expect-zero-object-leaks`. Keep registry teardown separate from scene
  node and resource-cache cleanup.

### Cleared: `character_selection_viper_start_smoke.gd` ObjectDB leak baseline

- The historical four-generic-`RefCounted` signature below no longer
  reproduces on the current character-select teardown. The latest verbose run
  instead identified one `AudioStreamWAV` plus its
  `AudioStreamPlaybackWAV`.
- This pair was not a confirm-intro shader/cache leak. The menu-flow contract
  intentionally keeps `/root/PreloadedMenuBgmPlayer` alive from boot through
  character select and stage loading, then releases it from
  `battle_scene_stage_intro_flow_lifecycle.start_battle_bgm()`.
- The smoke quit before that production handoff. Its cleanup now calls
  `MainMenuAudioController.release_preloaded_bgm_player()`, waits for the audio
  mix thread to retire playback, uses the public prewarm drain API, and opts
  into the smoke runner's zero-ObjectDB-leak gate.
- `character_select_audio_controller_smoke.gd` and
  `menu_flow_bgm_handoff_smoke.gd` remain the focused controller-level
  zero-leak contract for adoption, scene teardown continuity, and final
  battle-BGM release. `character_select_terminal_handoff_smoke.gd` seals the
  same ownership transition through the real character-select scene.
- `character_selection_viper_start_smoke.gd` now uses that zero-leak cleanup
  and mirrors `mika_hwangyeok_upperbody_live2d_smoke.gd` for the accepted Han
  Miryang v25 idle/confirm asset, 64-frame 8x8 action, shared trim, compensated
  scale/offset, voice delay, and return-blend contract.

Historical investigation record, now superseded:

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
- Historical status: this was once tracked as a non-blocking baseline, but the
  current typed audio evidence and terminal-handoff fix supersede it.
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

### Smasher 풍운천선무 cloud FX boundary

`smasher_wheel_state.gd` keeps the compatibility id, input/gameplay clock,
contact burst serial and coordinates, layout conversion, and all round/reset
cleanup. `smasher_wheel_cloud_fx_host.gd` owns only the controller-driven
modular presentation: a prewarmed static ink-cloud texture, orbit sprites,
continuous swirl particles, contact-scatter particles, and small procedural
accents. The host must remain self-process-free and must be hidden directly by
the state when the effect expires or is reset; draw visibility is not a cleanup
owner. `battle_playfield_effects_drawer.gd` supplies the live game offset and
render scale without changing the stable `smasher_wheel` save/runtime routes.

### Defeat continue projection and presentation boundary

`defeat_chance_gems_continue_screen.gd` retains chance-gem counts, input,
consume/continue callbacks, audiovisual side effects, and the public modal
contract. `defeat_continue_cinematic_state.gd` owns the PRESENT/CONSUMING
phase, confirm clock, consumed-count handoff, one-shot consume/shatter/reset
event flags, reset-frame peak-white clamp, revival-update gate, and fadeback
completion policy. It emits allocation-free integer event bits; the screen
alone executes gameplay callbacks and audio side effects.
`defeat_continue_transition_controller.gd` owns attachment, scalar
sync, and direct reset cleanup for the detached shatter/color-restore hosts,
plus the registry protocol bridge for starting, updating, drawing, stopping,
and physics-gating the revival beat. It is caller-clocked and creates hosts
only during explicit bind, never from draw.
`defeat_continue_visual_projection.gd` owns the draw-free confirm/shatter/
whiteout envelopes, gem count/index projection, button/gem geometry,
source-sheet cells, fit/cover rectangles, scaling, and easing. Static backdrop
coverage, vignette bands, entry reveal overlays, cached boss-victory texture
selection, portal figure drawing, and the full-screen whiteout/fringe overlay
live in
`defeat_continue_scene_renderer.gd`. The constant foreground divine ambience
is delegated separately to
`defeat_continue_ambient_renderer.gd`, which owns the bounded mote/ray counts,
portal breath projection, and CanvasItem drawing for the portal glow, fixed fan
light shafts, and motes. `defeat_continue_gem_renderer.gd` owns the reusable
allocation-free gem presentation state plus rail, slot, shatter-sheet handoff,
pre-shatter charge/cracks, chroma split, impact ring/shards/beams, and cached
gem texture projection. `defeat_continue_ui_renderer.gd` owns title ornaments,
status copy, last-chance guide copy, and confirm-button drawing without
per-frame segment dictionaries. The screen supplies its ambient/reveal clock,
while the cinematic state supplies confirm-time projections and derived impact
scalars; none of the renderers may start an independent process loop.
Battle/reset policy stays in the screen while the transition controller owns
direct cleanup of the detached visual hosts it manages.

## Verification Rule

For each Godot refactor:

1. Confirm the target is the repo-local live project at `godot/`.
2. Run the Godot headless load check from the workspace checklist.
3. If an external live project is introduced again, sync from `godot/`,
   compare edited-file hashes, and headless-load that external project.
4. Record any unverified visual-only risk in the handoff.

### Shared minimal loading cameo boundary

`loading_cameo_catalog.gd` owns the black-screen layout, translated tip band,
prewarmed cameo registry, and silhouette material shared by boot and battle
loading. `loading_cameo_host.gd` owns the fixed-per-session random pick,
animation frame projection, layered glow, and literal English loading copy.
`boot_flow_scene.gd` retains character-select prewarm/navigation ownership;
`battle_loading_screen_renderer.gd` retains warmup snapshots, completion hold,
stage-transition reuse, and the Stage 7 Akamu video exemption. Neither caller
may load or reroll cameo assets from a draw hot path.

## 2026-08-01 Viper Wall-Leap Night Raid boundary

`scripts/characters/viper_skill_wall_leap_runtime.gd` owns the complete
IDLE/infiltrate/fuse/return state machine, branch costs, tween position,
combat-center checks, shared status commits, and normalized reset. The Viper
runtime facade only routes input and publishes actor/ball/AI contexts. Ball
motion owns displacement-only slowdown and the two live unavailable-state
observations; collision detection gates only the base player paddle. Lingpet
RMB arbitration and guardian availability consume the cached facade contract
without instantiating Viper modules from their hot paths.

## 2026-08-02 Smasher Byeokryeok Yuseong post-cutin meteor boundary

`smasher_overdrive_state.gd` owns the full-cutin active-to-inactive edge,
60fps-equivalent descent/impact/linger clock, player-ground anchor, activation
serial, and reset policy. `smasher_overdrive_meteor_presentation.gd` owns staged
texture/node prewarm, game-to-screen projection, the full 760x750 playfield clip,
and direct detached-host cleanup. `smasher_overdrive_meteor_fx_host.gd` owns the
reused three-piece texture composition, controller-driven sprites/particles,
and low-cost beam/crack accents; it never advances an independent process loop.
`battle_effects_update_controller.gd` must update the shared power cut-in before
the overdrive state so the meteor cannot appear before the final cut-in frame,
while `battle_playfield_effects_drawer.gd` only routes the resulting snapshot.
Boss-guard trajectory cleanup preserves an already armed post-cutin meteor;
round/reset cleanup clears it and hides the host directly.

## Physique Training runtime boundary

The `physique_training_catalog/state/offer_planner` trio owns definitions,
run-lifetime accumulation, caps, metrics, and conditional offer selection.
`runtime_perk_physique_training_runtime_state.gd` owns those three lifetimes as
one feature boundary plus the probe-only bonus override, final-consumer
saturation judgement, dedicated choice commit and owner/mythic refresh, and the
60% offer replacement transaction. Its final probes must continue through
`ActiveItemCooldownComposer`, `SmasherDashState`, `CooldownFloorPolicy`, and the
registry-provided mythic runtime; intermediate runtime-perk getters are not a
valid saturation substitute. Fusion skips and all ineligible/no-replaceable
paths must return before metrics or RNG consumption, while a failed appearance
roll must not consume selection/replacement RNG. `runtime_perk_state.gd`
retains public/save facades and writable computed compatibility properties for
the catalog, state, and planner; those properties must never become parallel
storage.
`runtime_perk_choice_open_flow.gd` sequences fusion, Dowsing marking, Mystic
Dice, then Physique Training before ready-state layout. Runtime stat consumers
must read training only through `runtime_perk_effective_stat_query_surface.gd`;
they must not add `physique_*` IDs to Mugong levels, fusion candidates, polish
amplification, or round-reset ownership.

## Hyeonmun Charyeok runtime boundary

`runtime_perk_hyeonmun_charyeok_state.gd` remains the canonical 5% proc,
level-bonus, refresh-not-stack, duration, expiry, and snapshot state machine;
`runtime_perk_hyeonmun_charyeok_renderer.gd` remains the shared timer-stack
presentation owner. `runtime_perk_hyeonmun_charyeok_runtime_state.gd` owns both
lifetimes and the cross-owner transaction: raw invested-level lookup,
activation/refresh, gameplay-time update, round/full-reset state, Transcendent
Crown composition, canonical `item_perk_level_bonus` publication, and cached
consumer refresh after both activation and removal. It receives runtime/owner/
registry references per call and retains none. `runtime_perk_state.gd` keeps the
public paddle-hit/update/reset/snapshot/draw facade plus writable computed
state/renderer compatibility properties; those properties must not become
parallel storage. The Hyeonmun compatibility ID `sage_ring` stays self-exempt
from the temporary effective-level bonus.

## 2026-08-07 Victory highlight replay boundary

`victory_highlight_recorder.gd` owns the allocation-free 120Hz-capped visual
ring, the independent physics-event ring, time eviction, goal clip promotion,
and finisher/long-rally/clutch selection. It may consume only the final
renderer-facing `BattleDrawActorContext.build()` dictionary. The
`victory_highlight_actor_resolver.gd` normalizes that dictionary into flat,
reusable snapshot slots; stages whose private renderer textures are not in the
shared actor context intentionally fall back to silhouettes in slice 1.

`victory_highlight_playback_state.gd` owns the 2.8-3.2 second timeline,
0.12-second crossfade, skip guard, loop-audio cleanup, full-760x750 clipped FX
host, and direct finish/F9/reset teardown. Its host never processes itself.
`victory_highlight_renderer.gd` is a pure snapshot consumer and must not read
the registry or live battle state. `battle_scene_match_flow_driver.gd` remains
the sequence authority for highlight -> victory loot -> result -> reset, while
the frame-flow and input controllers own the gameplay freeze and routed skip.

The optional product frame lane is split between
`victory_highlight_frame_capture_state.gd` (380x375/30Hz root-game blit,
async CPU ring, bounded online clip retention, failure/epoch cleanup) and
`victory_highlight_frame_renderer.gd` (one prewarmed ImageTexture updated at
30fps). The snapshot recorder continues to record and promote every goal in
parallel. Renderer choice remains centralized in
`victory_highlight_playback_state.gd::start()` and any incomplete/failed frame
selection falls back as one unit to the existing snapshot renderer.

## 2026-08-08 Online 1v1 Han Miryang MVP boundary

`scripts/network/online_match_session.gd` is the sole online-match activity,
role, handshake, phase, snapshot interpolation, and client reconciliation
owner. `online_enet_transport.gd` and `online_match_protocol.gd` own transport
and wire-format concerns only; neither may decide gameplay results.
`online_match_simulation.gd` composes the existing score, round-flow, ball
physics, `BallUpdateStaticConfig`, `PaddleBounceFrameState`, `PaddleBounceState`
resolver group, and the public
`PaddleBounceController.apply_rally_speed_cap_progression` owner into
the host-authoritative simulation. It must not copy bounce-angle, hit-speed,
vertical-stall, substep, or rally-cap policy literals. `online_paddle_state.gd`
supplies two role-neutral 155px player-rule paddles.

`online_match_runtime.gd` is the battle-shell bridge and central feature gate:
after activation it bypasses the normal single-player update/draw route and
uses only the online renderer/input/session stack. A pending online request
with any required owner missing enters a visible fail-closed error instead of
falling through to single-player. `online_match_session.gd`
acquires and symmetrically releases the view layout's fixed 60Hz simulation-tick
lock. The normal battle modules remain unchanged
and regain control after teardown. `battle_scene_input_controller.gd` consumes
online events before legacy item/Lingpet/perk/modal/combat routes, while leaving
the Input singleton state available to the one-per-tick online collector.
Y-axis mirroring belongs only to session presentation projection; simulation
and snapshots stay in host coordinates.

## 2026-08-16 Tower-ascent vertical-slice boundary

The default-off `tower_ascent_flow_owner.gd` remains the sole stable public
facade for the generated 12-floor flow. It inherits an eager, behavior-preserving
owner chain: `tower_ascent_flow_runtime.gd` coordinates lifecycle/input/update/
draw; `tower_ascent_flow_snapshot_progress.gd` owns full-graph snapshots and
pending-reward journals; `tower_ascent_flow_ending_progress.gd` owns ending,
settlement, gauntlet, and defeat progression; `tower_ascent_flow_node_progress.gd`
owns node-modal routing; `tower_ascent_flow_economy_progress.gd` owns run economy
and shop/training transactions; `tower_ascent_flow_map_progress.gd` owns graph,
route, selector-ball, movement, and idempotent resolution state; and
`tower_ascent_flow_state.gd` eagerly constructs shared dependencies and owns
reset utilities. Public signatures and `SNAPSHOT_SCHEMA_VERSION` remain on the
facade through inheritance. `update_selective()` and `draw()` must not become
lazy construction sites under GRT-003/GRT-042.

`tower_ascent_map_generator.gd` owns versioned map-seed determinism without
advancing gameplay RNG; `tower_ascent_boss_registry.gd` owns floor pools and
direct routing for ported variants while the tuning stand-in table retains only
unported shell slots. The renderer consumes generated state without recreating
policy.
`battle_scene_match_flow_driver.gd` may enter the flow
only after victory loot finishes and resumes the unchanged legacy result flow
when the slice completes or cannot start. The central physics gate keeps normal
combat frozen while calling only `update_selective()`; input and the playfield
drawer are routing/consumer surfaces and must not recreate run-map policy.
