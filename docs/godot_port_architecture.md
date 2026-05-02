# Godot Port Architecture

This document records the long-term structure for the Godot port of
PingFighter. The Python version is the behavior reference, not the
architecture template: do not reproduce the `pingfighter.py` monolith in
Godot.

## Core Rules

- Keep `scenes/main.gd` as orchestration only: input routing, scene-level
  lifecycle, top-level draw ordering, and calls into owned modules.
- Before adding or modifying a Godot feature, identify the owning module.
  If no module exists, create the smallest stable module boundary first.
- Port behavior from `pingfighter.py`, but place systems by domain in
  `scripts/`, not by the order they happened to appear in Python.
- Keep a mirror of Godot source under this repository's `godot/` folder
  when the live project is outside the repo. Sync the live Godot project
  after edits and verify it loads.
- Prefer small, explicit dependencies. Module APIs should accept the state
  they need rather than reading unrelated globals from `main.gd`.
- Use `resource_path`-style discipline in spirit: Godot assets should load
  through `res://` paths, with file-load fallback when imported resources
  are not available yet.
- Refactor while porting. A feature is not considered done if it can only
  be implemented by adding another large, unrelated block to `main.gd`.
- New lazy-loaded modules should be registered in
  `scripts/resources/gameplay_module_registry.gd`; do not add one-off
  `*_script`, `_create_*`, and `_get_*_script` boilerplate for every
  module.
- Once a required module is synced into the live Godot project and passes
  headless loading, remove duplicate runtime fallback copies from
  `main.gd` instead of maintaining two implementations of the same system.
- Do not keep `main.gd` mirror variables for module-private state unless
  draw code or scene orchestration still reads them directly. Prefer
  calling the owning module from the narrow helper that needs the value.
- For character-skill parity, audit the full cross-domain chain before
  sign-off. Smasher skills specifically must check dash-state hooks,
  combo grace / consumption, Drive activation, Power-Smashing activation,
  HUD grace display, and boss-counter cleanup together; single-module
  parity is not enough when the original Python feature depended on
  shared globals.

## Mirror Layout

- `godot/project.godot`
  Mirrors the live Godot project settings used by
  `C:\Users\woduq\Documents\pingfighter\project.godot`. The main scene is
  stored as `res://scenes/main.tscn`, not as a UID, so a clean mirror can
  load before Godot has rebuilt its local UID cache.
- `godot/scenes/main.gd`
  Mirrors the live main scene script. It is intentionally a one-line
  shell that extends `res://scripts/core/battle_scene_shell.gd`.
- `godot/scenes/main.tscn`
  Mirrors the live main scene resource and points at `scenes/main.gd`.
- `godot/scripts/`
  Mirrors the live gameplay source modules. These files should stay hash-
  matched with the live project after each sync.
- `godot/assets/`
  Mirrors the live Godot asset files needed by the current Stage 1 port.
  Source PNG / WAV files are committed with their `.import` metadata, but
  `.godot/imported` cache files are not part of the mirror.
- Clean-clone loaders should tolerate missing `.godot/imported` cache
  outputs. For source PNG / WAV assets, load the raw file first through
  the focused resource helper, then fall back to Godot's imported
  `ResourceLoader` path when the raw file is not available.
- `scripts/resources/project_resource_loader.gd` owns that raw-first
  PNG / WAV loading policy. Feature modules should call it instead of
  duplicating `FileAccess` / `ResourceLoader` fallback branches locally.

## Planned Module Map

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
- `scripts/audio/`
  Sound loading, pitch/volume policies, cooldown gates, and event sound
  routing.
- `scripts/resources/`
  Texture/resource path ownership, resource loading fallbacks, shared
  caches, and missing-resource diagnostics.
- `scripts/effects/`
  Generic particles, screen shake requests, wall impacts, and reusable
  draw/update effect components.

## Current Split Status

- `scripts/core/match_score_state.gd`
  Owns match score rules: player/boss score, deuce state, deuce target
  progression, normal win-goal checks, score-result snapshots for the
  scoreboard, and next-serve ownership after a scoring event. `main.gd`
  still owns scoreboard triggering and full game reset side effects.
- `scripts/core/round_flow_state.gd`
  Owns round-flow timing state: serve delay, serve wait timer, current
  serving side, and round-start timestamp for active-item lockouts. The
  scoreboard-to-serve handoff resets the serve wait timer so the serve-flow
  controller can apply player / boss auto-serve delays from zero.
  `main.gd` still owns ball placement, ball velocity construction, scoring
  side effects, and the actual serve/reset orchestration.
- `scripts/items/active_item_runtime.gd`
  Owns the first Godot active-item runtime slice: starter active-slot
  construction, original field-drop timing for the currently ported
  `gauge_charge` / Energy Drink and `grenade` item data, item-spawn portal
  release timing, weighted currently-ported item spawning, animated unknown
  field-icon drawing, field-item motion / pickup routing, pickup feedback,
  grenade windup / projectile / explosion state, F2 debug spawn menu item
  selection, number-key use input, per-item cooldown checks, and the
  original Energy Drink / grenade consumable effects. Broader item pools
  beyond those currently ported items are still future item-domain work.
- `scripts/core/serve_flow_controller.gd`
  Owns serve-wait input and auto-fire timing: Space / left-click player
  serve release, normal player auto-serve delay, tutorial manual-serve
  preservation, and boss auto-serve delay. The battle frame flow delegates
  waiting-serve decisions here instead of treating every serve as the same
  one-second auto-fire path.
- `scripts/core/match_flow_controller.gd`
  Owns score-event and scoreboard-flow orchestration: scoring-side
  handoff to match score state, next-server sync, scoreboard start / finish
  actions, round-set sound trigger, and full-game reset fanout across HUD,
  active-item runtime, skill, dash, and round-flow modules. Ball reset is
  delegated back through the ball round controller, while `main.gd` still
  owns mutable scene fields returned by the controllers.
- `scripts/stages/stage1/stage1_pillar_background.gd`
  Owns the layered Stage 1 pillar background port: base hanji texture,
  texture loading, draw composition, and delegation to focused Stage 1
  pillar layer renderers / ambient state.
- `scripts/stages/stage1/stage1_pillar_ambient_state.gd`
  Owns Stage 1 pillar ambient runtime state: butterflies, wall-impact
  tree shakes, layout snapshots, and ambient update orchestration.
- `scripts/stages/stage1/stage1_pillar_petal_state.gd`
  Owns Stage 1 pillar ambient floating-petal runtime state: layout memory
  for pillar spawn regions, floating petal spawning, motion integration,
  lifetime trimming, and delegation to the tree-drop petal state.
- `scripts/stages/stage1/stage1_pillar_tree_drop_petal_state.gd`
  Owns Stage 1 wall-impact tree-drop petal bursts: tree-rect spawn
  positioning, burst velocity setup, gravity / sway motion integration,
  lifetime trimming, and max-count capping.
- `scripts/stages/stage1/stage1_pillar_layer_renderer.gd`
  Owns the public Stage 1 layered-pillar draw helper API and delegates
  chrome, sprite layers, petals, butterflies, and shared geometry to
  focused Stage 1 modules.
- `scripts/stages/stage1/stage1_pillar_layer_geometry.gd`
  Owns shared Stage 1 pillar geometry helpers: side / tree rects,
  viewport clipping, sheet-region slicing, fit-to-bounds rectangles,
  texture-region blits including horizontal flip, and ellipse points.
- `scripts/stages/stage1/stage1_pillar_chrome_renderer.gd`
  Owns Stage 1 pillar chrome overlays: hanji border lines, gameplay-field
  frame outlines, lower seam line, and animated border shine.
- `scripts/stages/stage1/stage1_pillar_cloud_renderer.gd`
  Owns Stage 1 cloud sprite motion layers: cloud sheet source selection,
  side-pillar placement, drift offsets, alpha, and horizontal flip.
- `scripts/stages/stage1/stage1_pillar_tree_renderer.gd`
  Owns Stage 1 tree sprite placement and wall-impact shake offsets.
- `scripts/stages/stage1/stage1_pillar_petal_renderer.gd`
  Owns Stage 1 floating petals and wall-impact tree-drop petal drawing.
- `scripts/stages/stage1/stage1_pillar_butterfly_renderer.gd`
  Owns Stage 1 butterfly sprite animation, side placement, color rows,
  wing frame selection, and scale.
- `scripts/stages/stage1/stage1_fallback_pillar_renderer.gd`
  Owns the procedural Stage 1 pillar fallback used when the layered
  image-backed background cannot draw: silk panels, border bands,
  gameplay-border fallback chrome, and delegation to the panel ornament /
  frame motif renderers.
- `scripts/stages/stage1/stage1_fallback_panel_ornament_renderer.gd`
  Owns procedural Stage 1 fallback panel ornaments: flowers, branches,
  butterflies, and falling petals drawn over the silk side panels.
- `scripts/stages/stage1/stage1_fallback_frame_motif_renderer.gd`
  Owns procedural Stage 1 fallback frame motifs: thunder marks along the
  gameplay border and corner flower ornaments scaled from live field
  geometry.
- `scripts/stages/stage1/stage1_pillar_scene_drawer.gd`
  Owns Stage 1 outer-scene pillar composition: layered/fallback pillar
  background draw selection and delegation to the Stage 1 pillar HUD scene
  drawer. `main.gd` keeps the high-level draw order and passes the
  viewport/game layout snapshot.
- `scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd`
  Owns Stage 1 outer-scene HUD composition ordering and left/right pillar
  HUD context assembly. It delegates top mini-scoreboard and bottom
  active-item slot context assembly to focused scene drawers.
- `scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd`
  Owns Stage 1 scene-facing top mini-scoreboard draw context assembly:
  live score snapshot lookup, deuce flag forwarding, sparkle timing, and
  handoff to the shared scoreboard renderer.
- `scripts/stages/stage1/stage1_active_item_hud_scene_drawer.gd`
  Owns Stage 1 scene-facing active-item HUD draw context assembly: active
  slot list normalization, bottom HUD layout build, round-start timing,
  and handoff to the active-item HUD renderer.
- `scripts/stages/stage1/stage1_actor_renderer.gd`
  Owns the public Stage 1 playfield / actor draw entry point and preserves
  the actor draw order. It delegates court / trail, Smasher, and boss
  drawing to focused Stage 1 renderer modules. `main.gd` still owns
  animation timers and gameplay state.
- `scripts/stages/stage1/stage1_dalji_whip_skill_state.gd`
  Owns the Stage 1 Dalji 상모돌리기 boss-skill port: boss skill gauge gain
  on boss paddle hits, 12% / 200-gauge activation, downward wave ball
  steering, player-hit cancellation, post-spin slowdown state, and the
  draw/AI flags consumed by ball, AI, and Stage 1 boss render modules.
- `scripts/stages/stage1/stage1_context_reader.gd`
  Owns typed reads for Stage 1 renderer dictionaries: Vector2 and Color
  fallback coercion used by playfield, player, boss, and sprite fallback
  renderers. Stage 1 render modules should reuse this helper instead of
  duplicating local `_as_vector2` / `_as_color` bodies.
- `scripts/stages/stage1/stage1_playfield_renderer.gd`
  Owns Stage 1 court background / guide-line drawing and Smasher dash
  afterimages.
- `scripts/stages/stage1/stage1_player_actor_renderer.gd`
  Owns Stage 1 Smasher actor drawing: hover / breath / hit-pose offsets,
  soft shadow placement, visual rect assembly, and delegation to the
  player sprite renderer.
- `scripts/stages/stage1/stage1_player_sprite_renderer.gd`
  Owns Stage 1 Smasher sprite drawing: hit / idle / walk texture
  selection, sprite source-rect selection, and fallback paddle drawing.
- `scripts/stages/stage1/stage1_boss_actor_renderer.gd`
  Owns Stage 1 boss actor drawing: shadow placement, visual-center
  alignment, Dalji walk-left / walk-right / idle / ball-contact attack
  source-rect selection, and fallback paddle drawing. Runtime state
  vocabulary follows `docs/sprites/boss_sprite_runtime_contract.md`; for
  Dalji-specific texture keys, see `docs/sprites/stage1_dalji.md`.
- `scripts/ball/ball_physics.gd`
  Owns the public ball-physics API and league/stage/weather context
  normalization. It delegates serve velocity, speed dampening, rally
  multipliers, impact boost, serve launch boost, boost decay, minimum vertical bounce
  correction, and base speed capping to focused physics policies.
- `scripts/ball/ball_context_reader.gd`
  Owns typed reads for ball-domain dictionaries: Vector2 fallback
  coercion used by ball update, motion, round reset, and paddle-bounce
  helpers. Ball modules should reuse this helper instead of duplicating
  local `_get_vector2` / `_as_vector2` bodies.
- `scripts/ball/ball_speed_policy.gd`
  Owns ball speed policy calculations: serve velocity, junior / rally
  speed multipliers, 50% reduced normal-rally acceleration tuning, dampened multipliers, scaled random multipliers,
  15% lowered base-speed tuning, minimum vertical bounce correction, and
  base speed capping.
- `scripts/ball/ball_impact_boost_policy.gd`
  Owns paddle-hit momentary acceleration policy: speed-dependent impact
  boost shaping, 65% amplified launch burst with angle-fixed boost and
  straight-hit 1.0s decay with 1.02s to 0.82s wide-angle decay tuning,
  vertical-shot decay strengthening, speed-normalized
  boost travel distance with delayed high-speed burst softening, slow rally
  carry-floor ramping, straight high-rally carry-floor clamping with a balanced late-rally floor, 15% raised
  overall boost scale tuning, reduced serve-only launch burst, stage boost caps,
  early-rally boost softening, junior boost scaling,
  decay-rate calculation, and the public boost-policy facade.
- `scripts/ball/ball_impact_angle_boost_policy.gd`
  Owns paddle-hit angle boost lookup. Current tuning intentionally returns
  the straight-hit boost multiplier for every angle, leaving outgoing angle
  to affect decay duration rather than launch boost strength.
- `scripts/ball/ball_impact_decay_policy.gd`
  Owns per-frame impact boost decay after paddle-hit acceleration has been
  applied, honoring the configured decay-rate duration.
- `scripts/ball/ball_intensity.gd`
  Owns ball rally tracking and intensity level progression, while
  delegating color / glow palette rules to the focused palette module.
  `main.gd` now asks this module for draw-time colors / glow / intensity
  directly instead of mirroring those values as scene variables.
- `scripts/ball/ball_intensity_palette.gd`
  Owns ball intensity color policy: level palettes, glow colors, and
  display-level blending between adjacent intensity levels.
- `scripts/ball/ball_effects.gd`
  Owns the public ball effect-state facade and delegates ghost trail and
  intensity particle / trail runtime state to focused modules. `main.gd`
  no longer keeps mirrored effect arrays; draw code reads the owning
  module snapshots at the narrow render call site.
- `scripts/ball/ball_ghost_trail_state.gd`
  Owns ball ghost-trail runtime state: interpolation between ball
  positions, max-length trimming, alpha fade, point age, and trail reset.
- `scripts/ball/ball_intensity_effect_state.gd`
  Owns the public ball intensity effect facade: color fallback selection,
  low-intensity update gating, clear / update fanout, and renderer-facing
  particle / trail accessors.
- `scripts/ball/ball_intensity_particle_state.gd`
  Owns ball intensity particle runtime state: speed-scaled particle spawn,
  low-intensity particle drift, flame / spark decay, and
  intensity-dependent max-particle capping.
- `scripts/ball/ball_intensity_trail_state.gd`
  Owns ball intensity trail runtime state: trail point sampling,
  spacing-based interpolation, trail length capping, alpha fade, and size
  decay.
- `scripts/ball/ball_effects_renderer.gd`
  Owns drawing orchestration for ball ghost trails, intensity effects,
  and energy-explosion particles. `main.gd` still owns draw ordering and
  passes draw-time snapshots from the owning state modules.
- `scripts/ball/ball_intensity_effect_renderer.gd`
  Owns ball intensity effect drawing: intensity trail points, flame /
  spark particles, active ball glow, default display colors, and color
  brightening.
- `scripts/ball/ball_renderer.gd`
  Owns current-ball canvas draw dispatch and delegation to focused ball
  body / status-overlay render helpers. `main.gd` still owns ball
  physics/collision state and passes a compact visual snapshot into the
  renderer.
- `scripts/ball/bomb_ball_renderer.gd`
  Owns bomb-ball body rendering: dark shell, fuse line, blinking fuse
  flame, and shell outline.
- `scripts/ball/ball_status_overlay_renderer.gd`
  Owns current-ball status overlay drawing: poisoned green aura / motes
  and Viper knockback fire aura / embers.
- `scripts/ball/energy_ball_renderer.gd`
  Owns the default energy-ball canvas drawing: glow rings, boost-charge
  rainbow tint, core highlights, and delegation to the orbit and ambient
  energy particle renderers. `ball_renderer.gd` delegates the energy
  visual path here.
- `scripts/ball/energy_ball_orbit_renderer.gd`
  Owns the default energy-ball orbit drawing facade: ring rotation / tilt /
  radius configuration and delegation to the focused orbit-ring renderer.
- `scripts/ball/energy_ball_orbit_ring_renderer.gd`
  Owns one energy-ball orbit ring draw pass: ring point-cloud geometry,
  depth-tinted ring colors, connector lines, and bright orbit glints.
- `scripts/ball/energy_ball_particle_renderer.gd`
  Owns the default energy-ball ambient particle state and drawing:
  particle spawning, life aging, max-particle capping, glow circles, and
  particle reset.
- `scripts/ball/pingpong_ball_renderer.gd`
  Owns ping-pong ball body rendering: texture draw fallback, procedural
  white ball fallback, and spin angle state reset.
- `scripts/ball/prism_ball_renderer.gd`
  Owns prism-ball body rendering: rainbow orbit point rings, depth tint,
  white core, and highlight.
- `scripts/ball/ball_motion_stepper.gd`
  Owns per-frame ball sweep detection: sub-step movement, left/right wall
  / paddle collision detector delegation, and top/bottom score events.
  The ball update controller owns the reactions to those events.
- `scripts/ball/ball_motion_collision_detector.gd`
  Owns ball motion collision tests used during sweep stepping: left/right
  wall clamping and impact positions plus player / boss paddle hitbox
  overlap snapshots.
- `scripts/ball/ball_update_controller.gd`
  Owns active-ball frame orchestration: freeze-frame handoff, base-speed
  caps, impact-boost decay, Drive spin decay, Power Smashing motion,
  motion-step event processing, scoring event reporting, and ball trail /
  intensity updates. `main.gd` applies only the returned scene snapshot
  and forwards score events to the match flow controller.
- `scripts/ball/ball_frame_motion_controller.gd`
  Owns active-ball frame motion modifiers: Power Smashing freeze handoff,
  base-speed capping, impact-boost decay, Drive spin application, and
  Power Smashing parabola motion mergeback.
- `scripts/ball/ball_motion_event_processor.gd`
  Owns active-ball motion-step event handling: motion-stepper invocation,
  wall / paddle controller dispatch, scene mergeback from bounce results,
  and top / bottom score-event translation.
- `scripts/ball/ball_update_context.gd`
  Owns ball-frame context assembly for active-ball updates, reset config,
  serve config, and delegation to dependency-map builders. It composes
  owner-field snapshots with static gameplay config instead of keeping the
  wide fanout inline.
- `scripts/ball/ball_update_owner_snapshot.gd`
  Owns dynamic owner-field extraction for ball-frame updates: live ball
  state, Drive flags, player / boss positions, timing counters, and hit
  sprite availability flags.
- `scripts/ball/ball_update_static_config.gd`
  Owns static ball update config: court dimensions, ball / paddle sizes,
  Drive / Power Smashing constants, 500 max-gauge constants, speed caps, reset
  config, and serve config including the visual serve-ball radius used to
  keep waiting-serve and launch-frame positions continuous.
- `scripts/ball/ball_dependency_context.gd`
  Owns ball update / round dependency map assembly from the gameplay
  module registry, including Power-Smashing counter knockback access to
  player movement state. This keeps registry key fanout out of the
  ball-frame context snapshot builder.
- `scripts/ball/ball_scene_bridge.gd`
  Owns the stable scene-facing ball bridge API and delegates physics /
  visual runtime state plus Drive-specific handoff to focused scene bridge
  modules. `main.gd` keeps compatibility wrapper methods here.
- `scripts/ball/ball_runtime_scene_bridge.gd`
  Owns scene-facing ball runtime snapshots: external ball physics context
  configuration, league-mode normalization, visual-state snapshots, and
  owner snapshot application.
- `scripts/ball/ball_drive_scene_bridge.gd`
  Owns scene-facing Drive ball state handoff: Drive activation snapshots,
  Drive clear snapshots, Power-Smashing state clear, and Drive input reset.
  The ball scene bridge keeps the stable external API and delegates these
  Drive-specific operations here.
- `scripts/ball/ball_round_state.gd`
  Owns ball round-start snapshots: common ball / spin / Drive runtime
  resets, full ball reset position, serve placement with serve velocity
  from `ball_physics.gd`, serve launch boost, visual-continuity serve
  offsets, and serve collision cooldown fields. The ball round controller
  owns the surrounding reset / serve fanout.
- `scripts/ball/ball_round_controller.gd`
  Owns ball reset / serve orchestration around `ball_round_state`: applying
  reset and serve snapshots through the scene callback, invoking round
  cleanup, triggering serve impact feedback / sound, and returning player /
  boss position and speed fields for `main.gd` to apply.
- `scripts/ball/ball_round_cleanup.gd`
  Owns reset / serve cleanup fanout: Power-Smashing / Drive input state,
  combo state / effects, VFX cleanup delegation, round wait delegation,
  actor round-state delegation, and battle-feedback round-state handoff.
- `scripts/ball/ball_round_effect_cleanup.gd`
  Owns reset / serve visual cleanup: ball VFX, impact VFX, ball renderer
  cache, and rally intensity reset.
- `scripts/ball/ball_round_actor_cleanup.gd`
  Owns reset / serve actor cleanup: round wait state, AI state,
  animation state, Power-Smashing counter knockback state, dash round
  state, and feedback reset token count.
- `scripts/ball/ball_spin_state.gd`
  Owns Drive-ball spin lifecycle: per-frame spin force / decay, Drive ball
  activation speed bump, and Drive state clearing snapshots. `main.gd`
  still applies the returned snapshot and owns skill activation timing.
- `scripts/ball/wall_bounce_state.gd`
  Owns wall-bounce velocity response: impact-speed calculation, left/right
  horizontal reflection, damping, and wall-hit screen-shake values. The
  wall bounce controller consumes this calculation.
- `scripts/ball/wall_bounce_controller.gd`
  Owns wall-bounce reaction fanout: wall-hit sound playback, wall-impact
  VFX spawning, Stage 1 pillar tree-shake triggering, and battle-feedback
  screen shake. `main.gd` applies only the returned ball velocity.
- `scripts/ball/paddle_bounce_state.gd`
  Owns the public shared paddle-bounce velocity facade: initial speed
  lookup and resolved velocity request forwarding. The paddle bounce
  controller consumes this stable API.
- `scripts/ball/paddle_bounce_velocity_resolver.gd`
  Owns shared paddle-bounce velocity orchestration: base / boss hit speed
  multiplier delegation, contact-shape resolver handoff, normal curve
  chance, final speed clamp, and vertical anti-stall guard delegation.
- `scripts/ball/paddle_bounce_contact_shape_resolver.gd`
  Owns paddle-bounce contact-shape selection: boss center-preserve
  correction, Drive contact-shape callback handoff, and normal center /
  mid / smash shaping result normalization.
- `scripts/ball/paddle_bounce_speed_multiplier_resolver.gd`
  Owns paddle-bounce speed multiplier application: base hit multiplier,
  boss hit multiplier, and angle-softened edge-hit boost ordering.
- `scripts/ball/paddle_bounce_vertical_stall_guard.gd`
  Owns paddle-bounce vertical anti-stall correction: tracking near-vertical
  returns, applying small/random escape rotations, and returning the
  updated vertical-bounce counter.
- `scripts/ball/paddle_bounce_velocity_rules.gd`
  Owns low-level shared paddle-bounce velocity rules: dampened multiplier
  lookup, scaled random multiplier lookup, boss center-preserve correction,
  normal center / mid / smash contact shaping, and minimum vertical
  correction.
- `scripts/ball/paddle_bounce_controller.gd`
  Owns paddle-hit orchestration: dynamic impact-boost updates, resolved
  bounce state application, final ball-position snapping, and delegation
  to paddle-hit skill-flow / event helpers. `main.gd` applies only the
  returned scene-state snapshot.
- `scripts/ball/paddle_bounce_player_skill_step.gd`
  Owns the player-only paddle-hit skill step: invoking player skill flow,
  merging skill results into the paddle-bounce frame state, and returning
  normalized power / Drive activation plus speed / angle updates.
- `scripts/ball/paddle_bounce_velocity_step.gd`
  Owns the paddle-hit velocity step: invoking the resolved paddle-bounce
  velocity state, merging the bounce result into frame state, and returning
  the updated ball velocity.
- `scripts/ball/paddle_bounce_post_hit_step.gd`
  Owns the paddle-hit post-hit step: invoking the post-hit handler,
  merging post-hit results into frame state, and returning final ball /
  actor speed values for the result snapshot.
- `scripts/ball/paddle_bounce_frame_state.gd`
  Owns mutable per-hit paddle-bounce frame values: context extraction,
  dynamic impact boost snapshot with outgoing launch-angle handoff,
  acceleration scale lookup, skill-result mergeback, bounce-result mergeback,
  post-hit mergeback, and final
  scene-state snapshot assembly.
- `scripts/ball/paddle_bounce_skill_flow.gd`
  Owns player paddle-hit skill flow around the shared skill router:
  Drive-state clearing, Power Smashing activation attempts, Drive skill
  flow delegation, and normalized skill-result snapshots.
- `scripts/ball/paddle_bounce_drive_skill_flow.gd`
  Owns paddle-hit Drive skill activation result flow: invoking the shared
  skill router and normalizing Drive activation snapshots for mergeback.
- `scripts/ball/paddle_bounce_post_hit_handler.gd`
  Owns paddle-hit post-processing after the velocity is resolved: final
  Power-Smashing hit velocity adjustment, rally feedback, normalized
  post-hit scene snapshots, and delegation to player / boss post-hit
  handlers.
- `scripts/ball/paddle_bounce_player_post_hit_handler.gd`
  Owns player paddle-hit post-processing: ball snap to the player paddle,
  Power-Smashing freeze-pose lock, temporary player / boss freeze speeds,
  player hit animation, combo registration, and gauge gain handoff through
  the event router.
- `scripts/ball/paddle_bounce_boss_post_hit_handler.gd`
  Owns boss paddle-hit post-processing: ball snap to the boss hitbox,
  Drive boss-counter mergeback, Power-Smashing boss-counter cleanup /
  knockback side-effect handoff, and boss hit animation handoff.
- `scripts/ball/paddle_bounce_power_hit_handler.gd`
  Owns paddle-hit Power Smashing handoff: hit-velocity resolver call,
  Power-Smashing trail spawn, and original blue-white activation burst
  particles.
- `scripts/ball/paddle_bounce_skill_router.gd`
  Owns paddle-hit skill routing: Power-Smashing activation request
  assembly, Drive activation router delegation, and Drive-state clearing
  snapshots used when Drive is countered or superseded by Power Smashing.
  The paddle bounce controller consumes its returned activation snapshots.
- `scripts/ball/paddle_bounce_drive_activation_router.gd`
  Owns paddle-hit Drive activation request assembly: Drive activation
  context, focused dependency dictionary, and controller invocation.
- `scripts/ball/paddle_bounce_event_router.gd`
  Owns paddle-hit side-effect fanout: combo-aware gauge gain, dash /
  dash-recovery gauge-gain blocking, Drive boss counter decay,
  Power-Smashing counter speed reset plus combo knockback trigger, actor
  hit animations, and delegation to rally feedback side effects. The
  paddle bounce controller calls this after resolving the core bounce.
- `scripts/ball/paddle_bounce_rally_feedback_router.gd`
  Owns paddle-hit rally feedback side effects: intensity hit registration,
  energy explosion / paddle particles, screen shake, and
  non-Power-Smashing paddle-hit sound.
- `scripts/effects/impact_effects.gd`
  Owns the public generic impact-effect state API used by the rally loop
  and delegates paddle-hit, wall-impact, and energy / Drive spark storage
  to focused effect-state modules.
- `scripts/effects/impact_paddle_effect_state.gd`
  Owns paddle-hit particles and their player / boss color palette.
- `scripts/effects/impact_wall_effect_state.gd`
  Owns wall-impact flash timing, wall-impact position, and wall-impact
  particles.
- `scripts/effects/impact_energy_effect_state.gd`
  Owns energy explosions and Drive spark particles shared by ball and
  skill feedback paths.
- `scripts/effects/battle_feedback_state.gd`
  Owns scene-level battle feedback timers: screen shake, gauge-gain flash,
  dash-token flash, and dash-token divider animation.
  Gameplay branches still trigger these events, while the battle effects
  update controller advances the timers and draw-time render modules read
  the values.
- `scripts/effects/battle_effects_update_controller.gd`
  Owns per-frame battle-effect fanout: battle feedback timers, audio tick,
  Drive text timer decay, Power Smashing text / VFX update, combo timer
  update, Stage 1 background update, gauge / dash orb spin sync, actor
  animation update, and impact-particle update. `main.gd` applies only
  the returned Drive text timer value. Top mini-scoreboard visual sparkle
  is intentionally advanced from the idle-process scene update driver so
  the display can redraw at monitor refresh instead of physics tick rate.
- `scripts/effects/impact_effects_renderer.gd`
  Owns generic impact canvas drawing: paddle-hit particles, wall-impact
  flash, and wall-impact particles. `main.gd` still owns draw ordering and
  passes the impact state object to the renderer.
- `scripts/audio/game_audio.gd`
  Owns battle sound setup and playback: paddle / wall hit cooldowns,
  serve and ping-pong serve sounds, dash and half-dash sounds, Drive /
  Power Smashing sounds, launch sound, round-set sound, pitch randomization, and audio-player factory
  delegation.
- `scripts/audio/game_audio_player_factory.gd`
  Owns AudioStreamPlayer creation for battle sounds: bus / volume setup,
  resource loading, WAV fallback loading, missing-resource warnings, and
  parent attachment.
- `scripts/core/battle_scene_bootstrap.gd`
  Owns battle-scene startup wiring: initial player / boss placement,
  audio setup, battle texture loading, Smasher skill icon extraction,
  and initial ball-physics context configuration through the shared
  registry cache. The lifecycle module applies the returned startup
  snapshot and then enters the normal reset / serve flow.
- `scripts/core/battle_scene_shell.gd`
  Owns the thin Node2D shell inherited by `scenes/main.gd`: registry
  creation, dynamic scene-state `_get` / `_set`, Godot callback bridges,
  and public compatibility wrapper names. The shell delegates startup,
  update, draw, and public ball API behavior to registered modules.
- `scripts/core/battle_scene_lifecycle.gd`
  Owns Godot scene startup lifecycle: random setup, canvas texture policy,
  window layout configuration, bootstrap snapshot application, and initial
  ball reset / ball-update prewarm through the update driver.
- `scripts/core/battle_scene_config.gd`
  Owns the scene-size and startup configuration constants for the Godot
  battle scene. Lifecycle and drawer modules read this config through the
  registry so `main.gd` no longer carries gameplay-surface constants.
- `scripts/core/battle_scene_owner_reader.gd`
  Owns shared scene-owner value reads for core context builders and scene
  snapshot appliers: null-safe property lookup plus typed Vector2,
  Dictionary, and Array fallback helpers. Core modules should delegate to
  this reader instead of duplicating owner property access logic.
- `scripts/core/battle_context_reader.gd`
  Owns shared dictionary value reads for core draw/context modules:
  Dictionary fallback coercion and typed Vector2 lookup from context
  snapshots. Core draw modules should reuse this helper instead of
  duplicating local `_get_dict` / `_get_vector2` bodies.
- `scripts/core/battle_scene_api.gd`
  Owns compatibility-facing scene API calls that external tests or tools
  may invoke on `main.gd`, such as ball physics context, ball visual state,
  and Drive-ball activation. The scene shell keeps the public wrapper names and
  delegates the behavior here.
- `scripts/core/battle_scene_state.gd`
  Owns mutable scene field defaults for the Godot battle shell. The scene shell
  uses a small `_get` / `_set` property bridge so modules can continue to
  read and write scene properties without keeping dozens of direct state
  variable declarations in the scene script.
- `scripts/core/battle_frame_flow_controller.gd`
  Owns per-physics-frame battle flow branching: scoreboard-lock updates,
  Power Smashing freeze updates, player / active-item / boss updates,
  serve-wait advancement, active-ball updates, effect updates, and redraw
  requests. The scene update driver supplies callbacks for the actual
  scene-level operations.
- `scripts/core/battle_scene_drawer.gd`
  Owns the scene draw-frame orchestration: viewport background, pillar
  draw pass delegation, transformed playfield draw pass setup, and
  delegation into the focused playfield drawer.
- `scripts/core/battle_scene_pillar_draw_pass.gd`
  Owns the outer pillar scene draw pass bridge: pillar draw-context
  assembly, top mini-score sparkle timing handoff, and delegation into
  the Stage 1 pillar scene drawer.
- `scripts/core/battle_playfield_scene_drawer.gd`
  Owns the transformed playfield draw pass facade: actor / ball / effect /
  combo / banner ordering and delegation to focused playfield draw helpers.
  The scene drawer keeps viewport and pillar composition.
- `scripts/core/battle_playfield_ball_drawer.gd`
  Owns playfield ball draw dispatch inside the transformed playfield pass:
  active ball effect draw context handoff, current ball draw snapshot
  lookup, renderer dispatch, and draw-position fallback helpers.
- `scripts/core/battle_playfield_effects_drawer.gd`
  Owns playfield actor / effect draw helpers inside the transformed pass:
  actor draw handoff, Power Smashing effect handoff, impact / combo effect
  drawing, and inner wall vignette drawing.
- `scripts/core/battle_playfield_overlay_drawer.gd`
  Owns playfield overlay draw helpers inside the transformed pass: skill
  feedback banners, serve-wait indicator dispatch, and scoreboard overlay
  dispatch.
- `scripts/core/battle_scene_update_driver.gd`
  Owns scene update-frame orchestration around the existing flow
  controller: flow dependency lookup, callback binding, callback cleanup,
  scoreboard overlay idle-process updates, top mini-scoreboard visual
  refresh requests, lifecycle reset-ball entry point, and startup prewarm
  for ball-update modules that would otherwise lazy-load on first serve.
- `scripts/core/battle_scene_update_callbacks.gd`
  Owns scene update callbacks for player / active items / boss / ball /
  effects-driver, score events, scoreboard updates, serve/reset requests,
  and delegation to actor, item, ball, effects, and match-flow scene
  drivers.
- `scripts/core/battle_scene_effects_update_driver.gd`
  Owns scene-facing effect update callbacks for the frame flow: invoking
  the battle effects update controller and applying returned effect fields
  such as Drive text timer state back to the owner.
- `scripts/core/battle_scene_match_flow_driver.gd`
  Owns scene-facing match-flow callbacks for score events, scoreboard
  updates, game reset callbacks, match-flow dependency lookup, and owner
  field application after reset, including active-item slot refreshes.
- `scripts/core/battle_scene_actor_update_driver.gd`
  Owns scene-facing actor update callbacks for the frame flow: Smasher
  player-control updates, boss AI updates, and applying the returned
  actor position / speed snapshots to the owner.
- `scripts/core/battle_scene_ball_update_driver.gd`
  Owns scene-facing ball callbacks for the frame flow: ball reset,
  serve-ball fanout, active-ball updates, Drive-state callback bridging,
  score-event forwarding, and returned ball snapshot application
  delegation.
- `scripts/core/battle_scene_ball_snapshot_applier.gd`
  Owns applying returned ball/reset snapshots to the scene owner, including
  reset-specific player / boss position and speed fallback handling.
- `scripts/core/battle_view_layout.gd`
  Owns battle window / viewport geometry: common 1080p-style window
  target scaling, game-surface render scale, centered game offset, and
  scaled game-size calculation. `main.gd` uses this layout snapshot for
  draw-order orchestration instead of carrying viewport math inline.
- `scripts/core/battle_draw_context.gd`
  Owns the public draw-time context builder API used by the scene drawer.
  It preserves the existing snapshot method names and delegates Stage 1
  pillar / scene, actor, ball, and banner dictionaries to focused context
  builders.
- `scripts/core/battle_draw_scene_context.gd`
  Owns the draw-time scene-context facade: playfield snapshot delegation,
  pillar-scene snapshot delegation, and shared draw dependencies.
- `scripts/core/battle_draw_playfield_scene_context.gd`
  Owns draw-time playfield scene snapshots: dash snapshots, actor / ball
  base positions, ball visual flags, paddle constants, and banner timing
  constants.
- `scripts/core/battle_draw_pillar_context.gd`
  Owns draw-time Stage 1 pillar scene snapshots: viewport/game layout,
  owner battle texture / skill icon maps, active-item slots, gauge values,
  and pillar renderer state dependencies.
- `scripts/core/battle_draw_actor_context.gd`
  Owns Stage 1 actor draw snapshots: animation-state draw data, dash
  status, player / boss positions, paddle sizes, and player / boss sprite
  texture references.
- `scripts/core/battle_draw_ball_context.gd`
  Owns ball draw snapshots: ball effect trails / particles, current
  intensity colors, serve-wait draw placement, current ball renderer flags,
  ball texture references, and Power Smashing draw flags.
- `scripts/core/battle_draw_banner_context.gd`
  Owns skill-feedback banner draw snapshots for dash, Drive text, and
  Power Smashing text timing.
- `scripts/core/battle_update_context.gd`
  Owns the public non-ball frame-update context facade and delegates
  player / boss, battle-effect, and match-flow dependency snapshots to
  focused context builders. The scene update driver keeps frame-order
  orchestration and applies returned scene values.
- `scripts/core/battle_update_actor_context.gd`
  Owns non-ball actor update context assembly: Smasher player-control
  config / dependencies and boss-AI owner snapshots.
- `scripts/core/battle_update_effects_context.gd`
  Owns generic battle-effect update context assembly: dash snapshots,
  ball / gauge / sprite presence fields, and battle-effect dependencies.
- `scripts/core/battle_update_match_flow_context.gd`
  Owns match-flow dependency map assembly for score, round, scoreboard,
  audio, HUD, active-item runtime, skill, Drive-input, and dash state
  modules.
- `scripts/resources/battle_resources.gd`
  Owns battle texture paths and loading: player / boss sprites, ball
  texture, orb / HUD frame textures, Smasher skill icon textures, and
  missing-resource warnings through the shared project resource loader.
  The scene bootstrap loads this map, while `main.gd` keeps the loaded
  texture dictionary and resolves draw-module texture keys through that
  shared resource map. Boss texture keys must keep attack and stun
  semantics separate; `boss_hit_sprite_sheet` is a legacy ball-contact
  attack alias, not a stun key.
- `scripts/resources/project_resource_loader.gd`
  Owns clean-clone-safe resource loading helpers: raw source PNG and WAV
  files are loaded directly when present, while imported Godot resources
  remain the fallback path. Texture, HUD, stage, and audio modules should
  reuse this helper instead of duplicating loader branches.
- `scripts/resources/gameplay_module_registry.gd`
  Owns the public lazy-loaded gameplay module lookup API. It delegates the
  stable module key catalog to `gameplay_module_catalog.gd` and delegates
  script / instance caching to `script_instance_cache.gd`, while `main.gd`
  asks for modules by stable keys instead of keeping path constants and
  one-line getter functions for each renderer / state helper.
- `scripts/resources/gameplay_module_catalog.gd`
  Owns the stable gameplay module catalog facade. It delegates module keys,
  `res://` script paths, and diagnostic labels to focused domain catalogs
  such as `gameplay_core_module_catalog.gd`,
  `gameplay_stage_module_catalog.gd`, `gameplay_hud_module_catalog.gd`,
  `gameplay_ball_module_catalog.gd`,
  `gameplay_actor_module_catalog.gd`,
  `gameplay_item_module_catalog.gd`,
  `gameplay_effect_audio_module_catalog.gd`, and
  `gameplay_resource_module_catalog.gd`. New Godot module owners should be
  added to the matching domain catalog instead of growing the registry
  logic or the facade.
- `scripts/resources/gameplay_item_module_catalog.gd`
  Owns item-domain gameplay module keys. Active-item runtime modules should
  register here so the facade and registry do not grow item-specific path
  knowledge.
- `scripts/resources/script_instance_cache.gd`
  Owns shared lazy script / instance caching for optional RefCounted
  modules. The gameplay module registry uses this cache instead of letting
  `main.gd` carry duplicate per-module script-cache boilerplate.
- `scripts/hud/orb_hud_state.gd`
  Owns the gauge-orb and dash-token frame spin state: trigger timing,
  cooldown gates, value/charge change detection, and eased spin-angle
  calculation. `main.gd` now calls this state module directly from the
  trigger, update, and draw call sites; texture loading and draw placement
  still stay in scene / renderer orchestration.
- `scripts/hud/pillar_orb_drawer.gd`
  Owns the public shared pillar / orb draw-helper API used by HUD and
  Stage 1 renderers. It preserves existing helper names and delegates
  geometry, chrome, liquid, and vignette drawing to focused helpers.
- `scripts/hud/pillar_shape_helper.gd`
  Owns shared shape / easing primitives: ellipse point generation, sector
  point generation, soft ellipse shadows, cubic ease-out, and sine
  ease-in-out.
- `scripts/hud/pillar_orb_chrome_drawer.gd`
  Owns reusable orb chrome drawing: generated frame texture sizing /
  rotation, fallback metal orb frame, glass highlights, and centered orb
  text.
- `scripts/hud/pillar_liquid_drawer.gd`
  Owns reusable orb liquid drawing: circular wave fill, highlight bands,
  bubbles, and dash-token sector charging liquid.
- `scripts/hud/pillar_stage1_vignette_drawer.gd`
  Owns Stage 1 inner side vignette drawing and the left / right pillar
  vignette pair helper.
- `scripts/hud/pillar_status_orb_renderer.gd`
  Owns the public status-orb draw API for the left gauge orb and right
  dash-token orb. It preserves the Stage 1 pillar UI entry points and
  delegates the visual bodies to focused orb renderers.
- `scripts/hud/pillar_gauge_orb_renderer.gd`
  Owns left gauge-orb drawing: blue outer glows, fallback frame, glass
  interior, gain flash rings, rotating frame texture, centered gauge
  label, and liquid-fill renderer delegation.
- `scripts/hud/pillar_gauge_orb_fill_renderer.gd`
  Owns left gauge-orb liquid-fill drawing: fill palette selection, liquid
  surface handoff, and inner fill glow.
- `scripts/hud/pillar_dash_orb_renderer.gd`
  Owns right dash-token orb drawing: red outer glows, fallback frame,
  glass interior, rotating frame texture, centered token label, the HALF
  marker, body renderer delegation, and delegation to the dash-token fill
  renderer.
- `scripts/hud/pillar_dash_orb_body_renderer.gd`
  Owns right dash-token orb body drawing: red outer glows, fallback frame,
  interior background, ambient particles, and token-count core glow.
- `scripts/hud/pillar_dash_token_renderer.gd`
  Owns the public right dash-token draw facade and delegates token fills
  and dash flash effects to focused renderers.
- `scripts/hud/pillar_dash_token_fill_renderer.gd`
  Owns right dash-token fill drawing: single / multi-token fills,
  charge liquid, and divider renderer delegation.
- `scripts/hud/pillar_dash_token_divider_renderer.gd`
  Owns right dash-token divider drawing: token-sector divider rays, divider
  tips, divider animation easing, and divider center chrome.
- `scripts/hud/pillar_dash_token_flash_renderer.gd`
  Owns right dash-token flash drawing: flash rings, expanding arc, and
  burst particles.
- `scripts/hud/smasher_skill_orb_renderer.gd`
  Owns the public Smasher skill-orb HUD API plus cluster slot geometry.
  It preserves `draw_underlay()` / `draw_orbs()` for Stage 1 pillar draw
  ordering and delegates the visual bodies to focused renderers.
- `scripts/hud/smasher_skill_orb_underlay_renderer.gd`
  Owns Smasher skill-orb cluster underlay drawing: generated full cluster
  frame placement, fallback socket rails, connector strokes, socket frame
  texture placement, and fallback socket chrome.
- `scripts/hud/smasher_skill_orb_slot_renderer.gd`
  Owns Smasher skill-orb slot orchestration: equipped / empty slot loops,
  skill readiness checks, PNG skill icon blits, and delegation to socket /
  cooldown / fallback-symbol renderers. `main.gd` still owns skill tables,
  gauge values, and draw ordering.
- `scripts/hud/smasher_skill_orb_socket_renderer.gd`
  Owns Smasher skill-orb socket chrome: empty / filled socket circles,
  activation flash glow, and ready-ring sweep arcs.
- `scripts/hud/smasher_skill_orb_cooldown_renderer.gd`
  Owns Smasher skill-orb cooldown overlays: dark socket cover, remaining
  cooldown sector fill, fallback sector-point construction, and cooldown
  progress arc.
- `scripts/hud/smasher_skill_orb_symbol_renderer.gd`
  Owns fallback Smasher skill-orb symbols when no PNG icon is available:
  Drive star spokes, Power Smashing burst spokes, and generic orb dots.
- `scripts/hud/stage1_pillar_ui_renderer.gd`
  Owns Stage 1 pillar HUD composition draw ordering: Smasher skill-orb
  underlay/orbs, status-orb renderer calls, and combo-HUD draw handoff.
  `main.gd` still gathers live gameplay snapshots and passes them into
  this renderer.
- `scripts/hud/stage1_pillar_ui_layout.gd`
  Owns Stage 1 pillar HUD placement and draw-context assembly: gauge /
  dash orb centers, common orb radius, skill-orb config snapshot shaping,
  and combo-HUD anchor rect.
- `scripts/hud/stage1_pillar_status_orb_context_builder.gd`
  Owns Stage 1 status-orb draw-context assembly: left gauge-orb values,
  dash-token snapshot shaping, flash timers, rotating frame textures, and
  shared fallback frame width.
- `scripts/hud/scoreboard_state.gd`
  Owns scoreboard overlay timing, scoreboard animation frame state, pending
  game-reset handoff, and top mini-scoreboard sparkle timing. It is the
  single source for overlay draw-time status; the round-end overlay uses the
  Python scoreboard's 15-frame fade-in and 90-frame hold cadence, with
  continuous idle-process frame values for high-refresh LED pulse animation
  while physics-frame gameplay remains paused. Top mini-scoreboard sparkle
  timers are also stepped from idle process so score flashes and deuce
  pulses redraw smoothly on high-refresh displays. `main.gd` still owns
  match score rules and sound playback.
- `scripts/hud/scoreboard_renderer.gd`
  Owns the public scoreboard draw API and delegates visual bodies to
  focused scoreboard helpers. The scene drawer decides when to draw it and
  passes score/state snapshots in.
- `scripts/hud/serve_wait_indicator_renderer.gd`
  Owns the serve-wait playfield indicator port: Player / Boss Serve labels,
  accent lines, manual / auto-serve helper text, boss Preparing / Ready
  status text, and tutorial-stage suppression. The playfield overlay drawer
  invokes this renderer while `round_flow_state` is waiting for serve.
- `scripts/hud/scoreboard_led_digits.gd`
  Owns the public reusable scoreboard LED number API: high-refresh
  seven-segment score-number drawing and multi-digit width calculation.
  The round-end overlay uses this reduced draw-call path instead of
  repainting a full dot matrix every render frame.
- `scripts/hud/scoreboard_led_digit_patterns.gd`
  Owns reusable scoreboard LED numeric dot patterns for digits 0-9,
  retained for dot-matrix fallback/reference work.
- `scripts/hud/scoreboard_led_dot_renderer.gd`
  Owns one-dot scoreboard LED rendering: a reduced lit glow stack, bright
  dot body, dim/off dots, and any future dot-matrix fallback draw-call
  budget.
- `scripts/hud/scoreboard_overlay_renderer.gd`
  Owns the full-screen score overlay canvas drawing: overlay layout,
  full-board frame placement, inner screen, footer target text, and
  delegation to the overlay frame / header / score-panel renderers.
- `scripts/hud/scoreboard_overlay_frame_renderer.gd`
  Owns the full-screen score overlay frame chrome: metal frame bands,
  bevel lines, drop shadow, corner bolts, and frame color helpers.
- `scripts/hud/scoreboard_overlay_header_renderer.gd`
  Owns the full-screen score overlay header: header panel chrome, player /
  boss logo orbs, glow halos, and PLAYER / BOSS labels.
- `scripts/hud/scoreboard_overlay_score_panel_renderer.gd`
  Owns the full-screen score overlay score panel: score-area split, LED
  score placement, continuous score glow / pulse timing, and VS plate
  drawing.
- `scripts/hud/scoreboard_top_mini_renderer.gd`
  Owns the top mini-scoreboard canvas entry point, geometry, sparkle
  timing normalization, deuce-mode selection, and delegation to normal /
  deuce mini-scoreboard renderers. `scoreboard_renderer.gd` keeps the
  compatibility entry point and delegates the visual body here.
- `scripts/hud/scoreboard_top_mini_normal_renderer.gd`
  Owns the top mini-scoreboard normal variant orchestration: chrome
  background, normal mini score text, and post-text sparkle delegation.
- `scripts/hud/scoreboard_top_mini_normal_chrome_renderer.gd`
  Owns the top mini-scoreboard normal chrome layer: glow margins,
  gradient panel, border chrome, and delegation to the normal decoration
  renderer.
- `scripts/hud/scoreboard_top_mini_normal_decoration_renderer.gd`
  Owns the top mini-scoreboard normal decoration layer: score diamonds,
  sweep sparkles, and corner starbursts.
- `scripts/hud/scoreboard_top_mini_deuce_renderer.gd`
  Owns the top mini-scoreboard deuce variant text layer: DEUCE label,
  pulsing score text, deuce score jitter / glow, and delegation to the
  deuce effect renderer.
- `scripts/hud/scoreboard_top_mini_deuce_effect_renderer.gd`
  Owns the top mini-scoreboard deuce fire effect layer: glow margins, fire
  gradient panel, flame tongues, and ember renderer delegation.
- `scripts/hud/scoreboard_top_mini_deuce_ember_renderer.gd`
  Owns the top mini-scoreboard deuce ember particles: particle phase,
  drifting position, size / alpha decay, and ember color ramp.
- `scripts/hud/scoreboard_top_mini_text_renderer.gd`
  Owns reusable top mini-scoreboard score text rendering: centered text
  baseline, glow layers, shadow pass, alpha application, and shared
  normal / deuce score text styling support.
- `scripts/hud/active_item_hud_state.gd`
  Owns active-item HUD slot state that is independent from drawing:
  selected slot index, cooldown completion flash timing, active-item
  cooldown ratios, and early-round throw-lock countdown calculation. It is
  the single source for those runtime status values; `main.gd` should only
  request a status snapshot for drawing. `main.gd` still owns slot layout,
  icon loading, and draw primitives.
- `scripts/hud/active_item_hud_layout.gd`
  Owns active-item HUD geometry for the bottom pillar: main slot tray,
  overflow tray, slot rects, responsive scale, and visible-slot clipping.
  `main.gd` passes the generated rects into the active-item HUD renderer.
- `scripts/hud/active_item_hud_visuals.gd`
  Owns active-item HUD icon texture caching/loading and item color
  normalization. The active-item HUD renderer consumes these values;
  `main.gd` should not duplicate item texture/color parsing.
- `scripts/hud/active_item_hud_renderer.gd`
  Owns the public active-item HUD draw API and delegates slot-panel,
  cooldown-frame, per-slot visual bodies, and slot-context normalization
  to focused helpers. `main.gd` still owns when to draw it and passes
  layout/state/visual modules into the renderer.
- `scripts/hud/active_item_hud_slot_context_builder.gd`
  Owns active-item slot draw context normalization: selected index,
  round-start elapsed time, item dictionary lookup, and per-slot cooldown /
  throw-lock status fallback.
- `scripts/hud/active_item_hud_panel_renderer.gd`
  Owns active-item HUD tray panel drawing and the shared group cooldown
  frame around all visible item slots.
- `scripts/hud/active_item_hud_slot_renderer.gd`
  Owns active-item HUD per-slot drawing: slot backgrounds, item icons,
  status overlays, selection borders, and slot numbers. It delegates icon
  bodies and status overlay details to focused slot helpers.
- `scripts/hud/active_item_hud_slot_icon_renderer.gd`
  Owns active-item HUD slot icon drawing: PNG-backed item texture draw,
  procedural fallback gem, visual-module icon lookup, and item-color
  fallback.
- `scripts/hud/active_item_hud_slot_status_renderer.gd`
  Owns active-item HUD slot status overlays: cooldown darkening, ready
  flashes, throw-lock countdown panels, and countdown text centering.
- `scripts/characters/smasher_combo_state.gd`
  Owns the public Smasher combo runtime facade: hit registration, combo
  reset / effect clearing, gauge-gain helpers, renderer-facing accessors,
  and delegation to the combo progress / effect runtime states. `main.gd`
  still owns skill-specific interactions.
- `scripts/characters/smasher_combo_progress_state.gd`
  Owns Smasher combo progression state: combo count, legacy dash grace window,
  combo gauge smoothing, effective combo selection, and renderer-facing
  combo timing / threshold constants.
- `scripts/characters/smasher_combo_effect_state.gd`
  Owns Smasher combo effect runtime state: active timer, display
  position, displayed combo count, effect duration, and the particle
  state used by the combo burst renderers.
- `scripts/characters/smasher_combo_rules.gd`
  Owns Smasher combo presentation / reward rules: combo colors,
  high-combo glow colors, gauge bonus percentage, and combo-aware gauge
  gain scaling.
- `scripts/characters/smasher_combo_particle_state.gd`
  Owns Smasher combo effect particle runtime state: particle spawning,
  per-frame motion / damping, life trimming, and max-particle capping.
- `scripts/characters/smasher_combo_renderer.gd`
  Owns Smasher combo draw orchestration and delegates combo particles,
  active burst effects, and HUD gauge drawing to focused renderers.
  `main.gd` still decides when to draw it and passes the combo state
  snapshot in.
- `scripts/characters/smasher_combo_particle_renderer.gd`
  Owns Smasher combo particle drawing: glow circles, star particles,
  high-combo cross glints, alpha fade, and shake-offset application.
- `scripts/characters/smasher_combo_burst_renderer.gd`
  Owns active Smasher combo burst drawing: starburst body, shake jitter,
  and delegation to the combo burst accent / text renderers.
- `scripts/characters/smasher_combo_burst_accent_renderer.gd`
  Owns active Smasher combo burst accent drawing: rays, slashes, rings,
  and high-combo rainbow orbit accents.
- `scripts/characters/smasher_combo_burst_text_renderer.gd`
  Owns active Smasher combo burst text drawing: outlined COMBO label
  layers, high-combo white glints, font baseline alignment, and alpha
  fade.
- `scripts/characters/smasher_combo_gauge_renderer.gd`
  Owns the Smasher combo gauge HUD under the left pillar skill cluster:
  anchored bar geometry, milestone ticks, max-combo pulse, grace fade
  behavior, and delegation to the gauge fill / text renderers.
- `scripts/characters/smasher_combo_gauge_fill_renderer.gd`
  Owns Smasher combo gauge fill drawing: filled gradient shade, wave
  highlight, bubbles, and sparkle particles inside the active fill.
- `scripts/characters/smasher_combo_gauge_text_renderer.gd`
  Owns Smasher combo gauge text drawing: outlined combo count,
  COMBO label, and GRACE label placement.
- `scripts/characters/smasher_skill_state.gd`
  Owns Smasher skill runtime HUD state: cooldown dictionaries,
  configured cooldown triggering / ratio calculation, ready-transition
  tracking, and activation flash timing. `main.gd` still owns skill
  cost/color tables, icon drawing, and activation side effects.
- `scripts/characters/smasher_input_reader.gd`
  Owns raw Smasher gameplay input polling for horizontal movement, dash
  key state, Drive action state, and exclusive Power Smashing direction.
  `main.gd` still owns gameplay routing and passes the snapshot into dash,
  movement, and skill activation modules.
- `scripts/characters/smasher_player_controller.gd`
  Owns Smasher player-control orchestration for the active rally loop:
  input snapshot consumption, drive input frame updates, horizontal
  movement application, and delegation to the dash controller. `main.gd`
  now calls this controller once per physics tick and applies the returned
  player position, speed, and gameplay frame counter.
- `scripts/characters/smasher_player_dash_controller.gd`
  Owns Smasher player-control dash orchestration: dash start / chain side
  effects, half/full dash selection, dash-to-skill combo grace start /
  effect clearing, dash-token HUD spin, dash audio / shake feedback,
  dash-position update forwarding, and
  recharge flash feedback.
- `scripts/characters/smasher_drive_input_state.gd`
  Owns the public Smasher drive input facade: frame input updates,
  buffered direction consumption, cooldown updates, and delegation to the
  buffer / frame-cooldown states. `main.gd` still owns raw input polling
  and drive ball activation behavior.
- `scripts/characters/smasher_drive_input_buffer_state.gd`
  Owns Smasher drive input buffering: directional/action press-frame
  tracking, last-pressed edge detection, stale input expiry, and buffered
  Drive direction consumption.
- `scripts/characters/smasher_drive_frame_cooldown_state.gd`
  Owns Smasher Drive / Power Smashing frame-cooldown lockout timers,
  cooldown decay, trigger clamping, and blocked-state reporting.
- `scripts/characters/smasher_drive_activation_controller.gd`
  Owns the player-paddle Drive activation sequence: activation eligibility,
  buffered direction consumption, combo-aware initial Drive bounce request,
  activation result assembly, and delegation to the activation feedback
  controller. `main.gd` still applies the returned ball / Drive scene fields
  before resolving final paddle bounce velocity.
- `scripts/characters/smasher_drive_activation_feedback_controller.gd`
  Owns Drive activation side effects: combo consumption, frame /
  configured cooldown triggers, gauge-orb spin, Drive particles, and
  Drive sound.
- `scripts/characters/smasher_drive_bounce_state.gd`
  Owns the public Smasher Drive bounce facade: initial Drive bounce
  requests and contact-shape requests. It delegates the initial bounce and
  center/smash contact math to focused resolvers.
- `scripts/characters/smasher_drive_initial_bounce_resolver.gd`
  Owns Smasher Drive initial bounce calculation: no-combo / combo speed
  multipliers, Godot-side combo balance scaling, combo bypass bonus, curve angle shaping, spin strength,
  Drive particle count, and combo-consumption / text-duration outputs.
- `scripts/characters/smasher_drive_contact_shape_resolver.gd`
  Owns Smasher Drive contact-shape bonuses during paddle resolution:
  center-hit speed / moderated spin bonus, smash-edge speed bonus, and smash-angle
  jitter.
- `scripts/characters/smasher_drive_counter_state.gd`
  Owns the boss-counter reaction against an active Drive ball: first boss
  contact detection, retained spin, softened Drive speed-increase reduction,
  and higher counter speed caps. `main.gd` still owns when the boss paddle
  collision invokes the counter calculation.
- `scripts/characters/smasher_power_smash_state.gd`
  Owns the public Smasher Power Smashing state API and delegates runtime
  field storage, velocity / motion calculation, and VFX state to focused
  modules. `main.gd` no longer mirrors those runtime fields as scene
  variables; activation and motion controllers consume this facade, while
  internal hit-velocity and motion resolvers receive the runtime state
  directly instead of duplicate pass-through accessors.
- `scripts/characters/smasher_power_smash_velocity_facade.gd`
  Owns the Power Smashing velocity facade: hit-velocity resolver
  invocation, active parabola motion resolver invocation, and passing the
  shared runtime state into both resolver paths.
- `scripts/characters/smasher_power_smash_runtime_state.gd`
  Owns the public Power Smashing runtime-field API and delegation to the
  lifecycle, speed marker, and text timer states.
- `scripts/characters/smasher_power_smash_lifecycle_state.gd`
  Owns Power Smashing lifecycle orchestration: activation eligibility,
  freeze-to-parabola transition, and delegation to freeze / parabola
  state modules.
- `scripts/characters/smasher_power_smash_activation_rules.gd`
  Owns pure Power Smashing activation checks: serve / active-ball gates,
  gauge cost, active freeze / parabola lockouts, frame cooldown block, and
  skill cooldown availability.
- `scripts/characters/smasher_power_smash_parabola_state.gd`
  Owns Power Smashing parabola fields: activity, elapsed time, curve
  direction / strength, consumed combo count, and motion stepping.
- `scripts/characters/smasher_power_smash_freeze_state.gd`
  Owns Power Smashing freeze fields: freeze activity, freeze timer, ball
  pose lock, locked ball position, and freeze duration completion.
- `scripts/characters/smasher_power_smash_speed_state.gd`
  Owns Power Smashing speed markers: original speed capture, target /
  boosted speed values, initial-boost active flag, and initial-boost
  timeout clearing.
- `scripts/characters/smasher_power_smash_text_state.gd`
  Owns Power Smashing banner text timing: reset semantics, activation
  duration setup, per-frame countdown, and renderer-facing timer access.
- `scripts/characters/smasher_power_smash_hit_velocity_resolver.gd`
  Owns Power Smashing initial hit-velocity math: original-speed capture,
  moderated dampened speed boost, no-combo penalties, combo speed bonus, initial
  boosted-speed setup, and delegation to the hit-direction resolver.
- `scripts/characters/smasher_power_smash_hit_direction_resolver.gd`
  Owns Power Smashing initial hit direction shaping: side launch turn
  minimums, straight launch paddle-offset correction, and moderated dampened
  direction multipliers.
- `scripts/characters/smasher_power_smash_motion_resolver.gd`
  Owns Power Smashing active-ball motion math after launch: initial boost
  interpolation, horizontal arc force, lift / pull phases, and per-frame
  curve chaos.
- `scripts/characters/smasher_power_smash_effects_state.gd`
  Owns the Smasher Power Smashing VFX facade: trail / particle clear,
  original-style blue electric hit bursts, active-parabola ambient spawning,
  per-frame update fanout, and public VFX accessors. Storage and decay live
  in focused VFX states.
- `scripts/characters/smasher_power_smash_trail_state.gd`
  Owns Power Smashing trail snapshots: original 8px spawn spacing,
  ball-size trail snapshots, max-trail trimming, fast alpha-style trail
  life decay, and renderer-facing trail access.
- `scripts/characters/smasher_power_smash_particle_state.gd`
  Owns Power Smashing particles: original blue-white radial burst spawning,
  moving ambient energy / spark spawning, lifetime / velocity decay,
  light gravity, max-particle trimming, and renderer-facing particle access.
- `scripts/characters/smasher_power_smash_activation_controller.gd`
  Owns Power Smashing activation orchestration: action-input eligibility,
  moderated directional arc selection, combo consumption, gauge spend, activation
  begin request, and delegation to the activation feedback controller.
  `main.gd` still applies the returned scene gauge value; later freeze /
  parabola progression lives in the motion controller.
- `scripts/characters/smasher_power_smash_activation_feedback_controller.gd`
  Owns Power Smashing activation side effects: configured cooldown trigger,
  frame-cooldown trigger, gauge-orb spin, Drive-state clearing callbacks,
  and activation sound. Hit bursts live in the paddle-hit handler and launch
  shake lives in the motion controller to match the original timing split.
- `scripts/characters/smasher_power_smash_motion_controller.gd`
  Owns Power Smashing post-activation progression: freeze-pose locking,
  freeze launch sound, combo-tier launch shake, and parabola motion stepping.
  `main.gd` applies only the returned ball snapshot.
- `scripts/characters/smasher_skill_feedback_renderer.gd`
  Owns Smasher skill feedback drawing: dash status text, Drive / Power
  Smashing timing monitors, center banners, and the feedback draw facade.
  `main.gd` still owns skill activation, sound playback, and draw ordering.
- `scripts/characters/smasher_skill_timing_monitor_renderer.gd`
  Owns the original Smasher Drive / Power-Smashing pre-hit timing monitor:
  yellow early Drive ring, red close-range SMASHING ring, ball / paddle
  approach checks, gauge-cost color selection, pulse ring, and label draw.
- `scripts/characters/smasher_power_smash_feedback_effect_renderer.gd`
  Owns Power Smashing trail / particle canvas rendering from the runtime
  trail and particle snapshots, including original-style blue linked
  lightning trails, white energy cores, glow shells, and spark streaks.
- `scripts/characters/actor_animation_state.gd`
  Owns the public actor animation state API and combines player / boss
  draw snapshots. The battle effects update controller passes texture
  availability and movement state, while `main.gd` forwards the animation
  snapshot to the Stage 1 actor renderer.
- `scripts/characters/player_actor_animation_state.gd`
  Owns Smasher animation timers and frame state: idle / walk frames, hit
  pose timing, hit side, hit-frame easing, and player animation clock.
- `scripts/characters/boss_actor_animation_state.gd`
  Owns boss animation timers and frame state: Dalji walk frame, facing,
  idle frame, anticipated ball-contact attack timing plus exact-contact
  fallback protection, and default boss frame timing constants.
- `scripts/characters/smasher_dash_state.gd`
  Owns the Smasher dash facade: dash-key release state, input-facing
  start/chain gates, and coordination between dash motion and dash-token
  recharge state. `main.gd` still owns raw input polling, sound playback,
  combo-grace triggers, screen shake, and applying the returned player
  position.
- `scripts/characters/smasher_dash_motion_state.gd`
  Owns Smasher dash motion state: full/half dash timers, recovery lockout,
  consecutive-dash elapsed-frame timing, start / chain eligibility, and
  returned player-position update. Active movement and recovery timing are
  delegated to the motion update resolver.
- `scripts/characters/smasher_dash_motion_update_resolver.gd`
  Owns Smasher dash motion update math: inactive recovery timer ticking,
  active-motion resolver delegation, state mergeback, and dash end state
  cleanup.
- `scripts/characters/smasher_dash_active_motion_resolver.gd`
  Owns active Smasher dash movement math: dash deceleration speed,
  horizontal clamp, end detection, elapsed-frame delta, and half-dash
  recovery multiplier application.
- `scripts/characters/smasher_dash_token_state.gd`
  Owns Smasher dash token state: max token count, current token charges,
  recharge countdown, full-dash token consumption, recharge completion,
  and consecutive-dash count reset.
- `scripts/characters/player_movement_state.gd`
  Owns Smasher's non-dash horizontal movement calculation: acceleration,
  minimum walk speed, deceleration, Power-Smashing boss-counter knockback
  decay, and clamp to the playfield. `main.gd` still owns raw input polling
  and dash/skill input routing.
- `scripts/characters/smasher_skill_config.gd`
  Owns Smasher skill data tables: equipped skill slots, gauge costs,
  skill colors, and cooldown seconds. `main.gd` still owns skill
  activation behavior and passes this snapshot into HUD renderers.
- `scripts/ai/boss_ai_state.gd`
  Owns the current boss movement AI slice: prediction-state delegation,
  approaching-ball urgency detection, latest ball impact-boost snapshot
  handoff, Power-Smashing combo reaction multiplier handoff, turn-inertia
  velocity delegation, and horizontal position updates. `main.gd` still owns
  boss position/velocity as gameplay state and applies the AI result each
  physics tick.
- `scripts/ai/boss_ai_turn_inertia_resolver.gd`
  Owns boss horizontal velocity math: acceleration/deceleration,
  sticky turn-around inertia that slides on the old direction with reduced
  reversal braking, approaching-ball brake recovery, restrained opposite acceleration release,
  speed clamping, and the current
  Stage 1 / Dalji champion-league movement profile.
- `scripts/ai/boss_ai_prediction_state.gd`
  Owns boss ball-position prediction: champion-league speed-based prediction
  frames, impact-boost / decay-aware boss-line arrival simulation,
  side-wall reflection prediction, boss-center target clamping, random
  prediction error, Power-Smashing combo focus mistake reduction, temporary
  fail windows, and fail-timer reset.
- `scenes/main.gd`
  Is now only a one-line entry script that extends
  `res://scripts/core/battle_scene_shell.gd`.
- `scripts/core/battle_scene_shell.gd`
  Owns the thin Node2D shell inherited by `scenes/main.gd`: registry
  construction, scene-state property forwarding, the public compatibility
  API, and the top-level `_ready`, `_physics_process`, and `_draw`
  delegation points. Player-control orchestration now lives in the Smasher
  controller, startup wiring lives in the battle-scene bootstrap, viewport
  geometry lives in the battle view-layout module, match / scoreboard flow
  lives in the match-flow controller, ball reset / serve fanout lives in
  the ball round controller, active-ball frame orchestration lives in the
  ball update controller, paddle-hit orchestration lives in the paddle
  bounce controller, per-frame effect fanout lives in the battle effects
  update controller, Power Smashing post-activation motion lives in the
  Smasher motion controller, and lazy-loaded module metadata lives in the
  gameplay module registry instead of scene-level path constants and
  per-module getter functions. Future ports should keep peeling stable
  systems into the module map above instead of growing this shell.

## Verification Rule

For each Godot refactor:

1. Sync mirrored source from `godot/` into the live Godot project.
2. Run the Godot headless load check for the live project.
3. Check that the edited mirror and live files have matching hashes.
4. Record any unverified visual-only risk in the handoff.
