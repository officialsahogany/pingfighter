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
`plaza_scene.gd` supplies live state and keeps narrow compatibility facades; do not restore
actor/building draw recipes or their projection constants to the scene shell.

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

The corresponding player-facing distance increase is accepted. A real 60 Hz
Vulkan run through the production handler/update route with normal `ui_right`
input first entered the new exit on frame 533 (`8.883s`), versus the old x=1750
counterfactual on frame 408 (`6.800s`). The accepted delta is 125 frames /
`2.083s` (about 30.64%); the probe used no direct-position test hook and
continued through the real 60-frame exit warp callback.

R1 is a retained-ownership bridge, not the final map-fit projection. The live
outer scene still projects through its existing `GAME_SIZE = 760 x 750`
side-scroll fit. At 2020 x 1246 this bridge displays the 360-unit bank at about
598px, upscaling its 512px runtime texture by about 1.17x, so R1 sign-off
requires a real Vulkan sharpness review at that resolution.

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
callback and spawns the plaza. The R1 retained bridge consumes the legacy
one-axis position applicator in production.

R1 Vulkan sign-off used eight A-H captures. It recorded 148,223 nontransparent
GPU-prewarm pixels, 34.938 ms GPU readiness, 8.432 ms spawn-call time, 20.758 ms
from spawn return to first post-draw, 7,459 strength-pair changed pixels, and
7,366 ADD/MIX changed pixels. A 6,144-pixel lifecycle sentinel remained at zero
in degenerate, interior, and exit captures; the capture suite reported zero
failures. Because Godot clamps `SubViewport` to at least `2 x 2`, the degenerate
leg enters the live `PlazaScene` root `_draw()` fallback without calling the
host directly.

### Plaza R2-A candidate-only map boundary

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

### Plaza R2-B candidate runtime and R2-C activation gate

`plaza_map_navigation.gd` compiles candidate walkability from the complete actor
rectangle, binds a digest that rejects later geometry mutation, and owns candidate
movement and portal routing. `plaza_map_minimap_projection_2d.gd` projects the
same 2D world spec into the candidate minimap without duplicating generation.
The navigation and minimap hardening gates are GREEN, including a 2px
uncovered-slit counterproof and exact two-axis building/player/exit/camera
comparisons. This is not a production performance sign-off: each candidate
`move_actor()` validates the whole geometry string/SHA again, and exact body
coverage uses `Geometry2D.clip_polygons()`. Atomic activation requires
steady-p95 evidence at the real owner cadence and a bind-once immutable compiled
owner with a fast occupancy path that preserves the same counterproofs, following
[GRT-032](godot_runtime_traps.md#grt-032)'s setup-time-index/per-frame-O(1)
boundary.

`plaza_r2_map_world_candidate_host.gd` is a separate candidate renderer. It
preflights all state before tree mutation, consumes caller-isolated compiled road
draw records, and keeps actual building and actor CanvasItems as direct Y-sort
siblings with relative zero-z layers. Its focused, mutation, and 2020x1246
Forward Mobile A/B/C Vulkan Y-sort gates are GREEN, including an actual actor
z=1 structural RED counterproof. The actual-tree seal also restores Base=MIX,
Sign/Window=ADD, Probe/Body=null material, local material ownership, white
parent/child modulation, show-behind, and visibility after leaving mutations in
place; the resulting independent audit found zero CRITICAL/HIGH findings. The
host, navigation, and 2D minimap owners have no production `plaza_scene.gd` or
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
reset policy. `runtime_perk_state.gd` orchestrates only the Angel-specific roll,
shared cooldown pause/resume, and owner sync; it must never reuse the whole intro
callback for a mid-stage acquisition because that would flush unrelated deferred
Dimension Gate/full-gauge work. The shared mythic acquisition runtime reports
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
