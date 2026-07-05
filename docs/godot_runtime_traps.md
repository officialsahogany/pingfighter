# Godot Runtime Hidden-Trap Ledger

Graduated verbatim from `CLAUDE.md` on 2026-07-02 under the backfill
graduation rule (see `CLAUDE.md` "Post-fix checklist backfill policy").
This file is the FULL standing text of every cross-cutting Godot runtime
hidden trap; `CLAUDE.md` keeps a 3-8 line stub per trap under the SAME
heading so sessions recognize the trap class and open this file on demand.

Rules for this file:

- Section headings are STABLE ANCHORS. Other docs, memories, and reviews
  reference these traps by heading name (often as "the CLAUDE.md X trap" --
  those references resolve through the CLAUDE.md stub of the same name).
  Do not rename headings casually; if a rename is unavoidable, update the
  CLAUDE.md stub and grep repo + memory for references first.
- New trap backfills: FULL text here (incident, mechanism, standing rules,
  smoke seals), stub in `CLAUDE.md`. Strengthen an existing section instead
  of appending a near-duplicate.
- Ownership boundaries stay as declared in `CLAUDE.md` §0: runtime /
  performance conflicts defer to `AGENTS.md`; asset-generation details
  defer to the skills.

## Godot ConfigFile UTF-8 BOM Trap

Godot `ConfigFile.load()` can silently miss the first section when a settings
file starts with a UTF-8 BOM (`0xEF 0xBB 0xBF`). PowerShell `Out-File`,
Notepad, and some editors may add this BOM while the file still looks normal
in text viewers. If the first section is `[graphics]`, Godot can treat the
BOM as part of the section header, skip those keys, and fall back to defaults
such as windowed mode or Auto / off VSync even though the visible file content
looks correct.

For Godot settings / save-data code using `ConfigFile`, suspect BOM first
when logs show `exists=on` / `load OK` but the first section's keys are
missing. Read raw bytes, strip a leading UTF-8 BOM, then parse the cleaned
text and rewrite the file without BOM. For player-facing settings, keep a
`last_good` backup or equivalent recovery path so schema-only / partial
settings files can be repaired instead of silently reverting to defaults.

## Godot High-Refresh Pacing Trap

The 144Hz divisor-lock display hypothesis has been tested and rejected for the
current Godot 4 + Windows + NVIDIA path. `72_FPS` / `48_FPS` on a 144Hz monitor
looks like a clean 1/2 or 1/3 divisor on paper, but the tested combinations
(`VSync On`, `VSync Off`, and `Auto` / adaptive in exclusive fullscreen) did
not reproduce the smooth 60Hz lock. `VSync On` plus `Engine.max_fps` creates
two pacing layers, while driver-only adaptive present did not make a stable
72Hz half-rate lock either.

For release-quality smoothness, treat `60Hz monitor + 60 FPS + VSync On` as the
known-good display setup. If a high-refresh display needs to feel smoother,
route the work to frame interpolation or heavy-event reduction; do not assume
another display-setting matrix will fix it. Player-facing helpers may recommend
opening Windows display settings, but automatic refresh-rate switching must be
explicit opt-in because it affects the whole desktop.

The shipped project keeps a **48 FPS bootstrap safety cap** in
`godot/project.godot` (`run/max_fps=48`, `physics_ticks_per_second=72`), while
the runtime display default is intentionally **Stable Monitor**:
`RENDER_FPS_CAP_DEFAULT := RENDER_FPS_CAP_STABLE_MONITOR` in
`godot/scripts/core/battle_view_layout.gd`, mirrored in
`godot/scripts/hud/pause_menu_overlay.gd`. Stable Monitor resolves through
`_get_stable_monitor_refresh_rate()` /
`resolve_stable_cap_for_monitor_rate()` so **144Hz -> 72** (promoted
2026-06-11 from 48 after the 72fps budget work passed its clean-run felt
gate — see `docs/frame_budget_72fps_optimization_design.md` §0.2; the
single lever is `RENDER_FPS_CAP_STABLE_PREFERRED_MAX := 72`, divisor table
sealed in `render_fps_cap_settings_smoke.gd`), 120Hz -> 60, and
60Hz -> 60. This keeps the `60Hz + 60 FPS + VSync On` known-good setup intact
on 60Hz displays while giving high-refresh displays a safer default frame
budget than monitor-rate 144 FPS. Runtime options still expose 48 / 60 / 72 /
Unlimited / Monitor as explicit alternatives. No new settings migration was
needed for the promotion: the stored value is the Stable Monitor sentinel,
which re-resolves through the new table on load.

Display settings schema 5 migrates materialized schema <=4
`RENDER_FPS_CAP_MONITOR` defaults to Stable Monitor. This intentionally cleans
up settings files created while the runtime default followed monitor Hz. Before
changing the shipped runtime default again, move all of these together:
`RENDER_FPS_CAP_DEFAULT` in `battle_view_layout.gd`, the mirrored constants and
recommended-settings path in `pause_menu_overlay.gd`, the recommendation copy in
`language_settings_data.gd`, the default / migration assertions in
`render_fps_cap_settings_smoke.gd`, this documentation, and the display-settings
migration. Touch `project.godot` and `project_boot_flow_settings_smoke.gd` only
if the bootstrap safety cap itself changes.

**Stable Monitor default trades physics fidelity for pacing on >120Hz
displays.** `_resolve_physics_ticks_per_second()` syncs the physics tick rate to
the resolved render cap for `RENDER_FPS_CAP_STABLE_MONITOR` /
`RENDER_FPS_CAP_MONITOR` whenever that cap lands in `[30, 120]`, and
`render_fps_cap_settings_smoke.gd` locks this as a contract. After the
2026-06-11 144->72 promotion the shipped Stable Monitor default resolves to
**render 72 / physics 72 on a 144Hz monitor** (a 60Hz display stays 60/60) —
72 IS the project physics default, so the earlier `72 -> 48` physics drop and
its fast-ball **tunneling** risk note for `>120Hz` displays are retired for
144Hz. The tick-sync contract itself still applies to other monitor rates
(e.g. 165Hz -> 55/55, 240Hz -> 60/60), where the resolved tick can sit below
72: the felt risk there remains tunneling through thin collision bands
(paddle edge, holy barrier, brick wall); gameplay speed stays constant only
as long as motion uses the `ball_update_controller` `fps_scale = delta * 60`
path. If tunneling shows up on such a display, the minimal, cleanest
follow-up is to make `STABLE_MONITOR` fall back to the project physics
default (`72`) inside `_resolve_physics_ticks_per_second()` instead of
syncing to the resolved cap, then flip the `render_fps_cap_settings_smoke.gd`
"sync physics to its resolved cap" assert. That single lever is the
documented switch — do not silently re-raise physics anywhere else.

## Godot Hot-Path Lazy Init Trap

Do not lazy-instantiate modules, resources, textures, scene nodes, draw hosts,
or large caches from Godot hot paths (`_physics_process`, `_process`, `_draw`,
or helpers reached from them). A first call that looks cheap can turn into a
100ms+ hitch when it creates a module, loads a texture, builds icon/layout
caches, or instantiates an overlay.

Use one of these instead:
- Create or prewarm before entering the visible / hot state.
- Use cached-only lookups for "is this open / active?" gates.
- Stage heavy work across loading / intro frames.
- Document the path as low-cost lazy only after measurement.

Known repeats of this exact class include F3 mythic-management first icon
creation, score-result texture ensure during draw, desktop mobile-touch first
draw module creation, Stage 1 pillar mythic runtime lookup during draw,
perk-debug overlay first visible draw, the modal-gate physics regression
where closed overlay checks lazy-created modules for a 158ms spike, the
lingpet skill runtime host lazy-creating the active skill module (1034-line
doll curse script + 512px sheet) on its first per-frame update / first arm,
and the match-reset deps build cold-instantiating ALL six stages' state
modules through `registry.get_instance` on a stage-1 match end (370ms
physics stall; the round-restart default deps path hit the same class at
574ms). Reset / cleanup / "is it active?" consumers that only need EXISTING
modules must look up through `registry.get_cached_instance` (the
non-instantiating peek — a never-created module has no state to reset);
reference: `battle_update_stage_runtime_deps_builder` include-all branch,
sealed by `stage_runtime_deps_builder_smoke`'s cold-instantiation guard.
The lingpet fix pattern is prewarming at the discrete loadout-apply / boot
moment (`lingpet_egg_runtime._prewarm_current_skill_runtime`, sealed by
`lingpet_egg_runtime_smoke._verify_loadout_apply_prewarms_active_skill_runtime`);
a new lingpet skill gets the sheet half of this for free only if it
implements `prewarm()` for its heavy textures.

Transition-ordering variant (2026-07-03, stage transition loading): having a
prewarm step in the SAME staged sequence is not enough — the step ORDER must
put dep instantiation before dep consumers. The stage-transition loading work
ran `_reset_match_for_stage_transition` at work step 1 with `current_stage`
already switched, so the reset's `build_deps` cold-instantiated the NEW
stage's round modules (stage4: ponk_skill_state 82.6ms + bird_event 40ms —
224ms loading-frame hitch) three steps BEFORE the stage runtime prewarm at
work step 4, which then found everything warm and looked innocent. The
prewarm key set even contained the modules; order made it a no-op. Fix:
a staged stage-round-deps instantiation step BEFORE the reset step (one
module per frame), with the key list single-sourced from
`ball_dependency_context.get_stage_round_dep_keys(stage)` so the consumer's
dep list and the prewarm list cannot drift apart (drift = this trap's
reappearance for the next new stage). Sealed by
`battle_scene_stage_transition_loading_smoke` (reset step reached ⇒ all
stage dep keys already `get_cached_instance`-non-null, stages 3→4 / 5 / 6).

Second-order variant: per-module staged instantiation is NOT enough when a
single module's first `get_instance` is itself huge — `stage2_pillar_background`
carries a 50+ `preload` const cascade, so its first load compiles the whole
stage script forest (~253ms in ONE loading frame; per-module labels
`step.1.round_dep.<key>` made this attributable). Fix shape (2026-07-03,
verified 253→0.1ms): request the round-dep SCRIPTS via
`ResourceLoader.load_threaded_request` at transition BEGIN
(`script_instance_cache.request_threaded_script` / ready-gated harvest), and
have the deps step wait for script-ready before calling `get_instance` —
instantiation then pays only `new()`. Failure/non-script results degrade to
the old sync `load()` path, so the gate can never hang the transition.
Sealed by `script_instance_cache_threaded_script_smoke` + the transition
loading smoke's no-instance-before-ready assert.

Integration footgun: the BOOT prewarm path resolves modules through
`battle_scene_shell`'s `Callable(self, "_get_module")`, NOT the registry
object — a registry-level threaded-script helper probed via `has_method`
silently no-ops through that Callable, the ready gate opens immediately, and
the sync load stays (run9: `resolve_module_wait` fired 0 times while
`resolve_module` stayed ~513ms). Any registry-level threaded/prewarm helper
must be bridged on the shell too (`battle_scene_shell.request_threaded_script`
/ `is_threaded_script_ready`); verified fix took
`character_info_prewarm.resolve_module` 513 → 0.2ms (run10). Diagnostic rule:
a wait/gate label that NEVER fires while the gated cost persists means the
gate is not engaging — check the getter/bridge path before doubting the
mechanism.

## Godot Missing Reserved-Asset Per-Frame Re-Stat Trap

`ProjectResourceLoader.load_texture()` / `load_imported_texture()` cache only
SUCCESSES — a path that resolves to no file (a reserved-but-not-yet-generated
asset) is **not negative-cached**. So any per-frame draw/load consumer that
calls the loader with an absent path re-runs `FileAccess.file_exists` +
`_can_load_imported_resource` (another `.import` stat + `ConfigFile.load`) +
`ResourceLoader.exists` **every frame** the consumer is visible. The reference
class is a debug-gated skill whose catalog declares a reserved card/icon path
that has no PNG yet, drawn each frame by a rail-card / icon HUD
(`lingpet_rail_card._load_texture` → `_draw_gauge`): every frame it re-stats and
(pre-fix) emitted a `push_warning` with no dedup, spamming the log.

As of commit `8af96406c`, `_push_path_warning` dedups by `template|path`
(`project_resource_loader._claim_path_warning`), so the warning fires once.
That fixes the log spam **but makes the residual per-frame re-stat SILENT** —
the dedup removes the only signal that a missing asset is being hammered. So:

- Do NOT leave a reserved-but-absent asset path wired into a per-frame draw /
  HUD / icon load path. Generate the real art, or point the path at an existing
  placeholder (e.g. an `unknown_*` asset) until the art lands, so the loader
  caches a success and the per-frame stat stops.
- Do NOT rely on warning spam to notice a missing asset — it now warns once.
  When a debug-gated skill / item reserves art that does not exist yet, audit
  whether anything draws its card/icon every frame.
- A smoke that only string-checks the reserved catalog path passes even when
  the file is absent. If a skill is gated debug-only PENDING art, either ship a
  placeholder + `FileAccess.file_exists` assert, or land the `file_exists`
  assert in the SAME slice as the generated art (a file_exists assert added
  before the art turns the suite red and breaks the pre-push gate).

## Godot Threaded Texture Cross-Path Timeout Trap

**Mixed-type asset path dict → texture prewarm 오디오 누수 (2026-07-03).**
`stage_clear_result_asset_loader.get_result_asset_paths()`류의 "asset paths"
dict는 텍스처와 오디오를 한 dict에 담는다(스테이지1 `dalji_click_voice` =
mp3). 이 dict의 `.values()`를 텍스처 프리웜에 그대로 흘리면, 가드로 쓰던
`ResourceLoader.exists(path, "Texture2D")`의 타입 힌트가 **임포트된 오디오를
걸러주지 못해서** mp3가 스레디드 슬롯을 한 스텝 낭비하고 매 세션 이미지
디코드 ERROR 로그를 남긴다. 텍스처 프리웜 소비자는 확장자 화이트리스트
(`battle_entry_background_prewarm.TEXTURE_PATH_EXTENSIONS`)로 먼저 걸러라.
씰: `battle_entry_background_prewarm_smoke`의 오디오 필터 어서션 + 전 잡
확장자 어서션(반증검증: 필터 무력화 시 mp3 경로가 정확히 RED).

`ProjectResourceLoader.prewarm_texture_threaded_step()` has one shared texture
slot. When caller B requests a different path while caller A still owns that
slot, B is only a waiter; B must not inherit A's start time or poll count. If
the waiter checks timeout against the owner clock, a live gameplay caller can
arrive behind a large 0/0 "never expire" stream after more than the default
1800ms and immediately declare itself expired on its first poll.

The dangerous follow-up is draining the owner's in-flight load on the waiter's
timeout. `_drain_threaded_texture_prewarm()` calls
`ResourceLoader.load_threaded_get()` for non-terminal statuses, so a waiter
behind another path can block the main thread on somebody else's 80-100MB
sheet. The reference discovery was the lingpet panel / click prewarm work:
making live-rally click sheets opt into 0/0 correctly protected their own
stream from sync fallback, but it widened the window where default-bounds
callers behind that stream could expire and drain the foreign owner.

Standing rules:
- Cross-path waiters need their own wait clock keyed by requested path. The
  owner slot's `started_msec` / poll count belongs only to the owner.
- A waiter timeout may resolve the waiter's own path synchronously, or keep
  waiting, but it must not call `_drain_threaded_texture_prewarm()` on the
  foreign owner while the owner is still `IN_PROGRESS`.
- Keep `try_resolve_finished_threaded_prewarm()` for terminal foreign loads:
  finished owners should still be harvested and cached immediately.
- Default bounds stay short for loading-screen callers; live gameplay callers
  that prefer deferral over hitching must opt into longer or unbounded waits.
  Do not solve a live hitch by widening the global defaults.

Smoke seal: `project_resource_loader_import_preference_smoke.gd` forces an
aged foreign in-flight owner, then asserts a default-bounds waiter does not
expire on its first poll and that even an explicitly expired waiter resolves
its own texture without clearing the foreign owner slot.

Readiness-gate corollary (2026-07-03, lingpet acquire cut-in 721ms stall): a
"is the streamed asset ready?" GATE must wait, never load. The reveal-clock
gate `is_pet_cutin_anim_ready()` checked the cache, kicked one threaded step,
then fell back to a synchronous `load_imported_texture()` of the 8192px+
Live2D sheet — blocking the physics tick ~721ms at the exact hatch moment the
gate existed to protect (the item-egg fast path hatches within seconds, so
the calm-wait streaming never finished). Even the size_limit'd IMPORTED sheet
is hundreds of ms when loaded synchronously; the earlier fix that banned the
raw-source decode (~1141ms) was necessary but not sufficient. Standing rules:
a readiness gate returns false and keeps the threaded stream alive; pair it
with a bounded failsafe deadline (current: 3s in
`lingpet_acquire_cutin_state`) that resolves to the intended DEGRADED visual
(static 원화 reveal), not to a blocking load; and kick streaming at the
earliest moment the asset identity is known (lingpet_egg item use resolves
the pet id — stream from there, not from egg placement). Sealed by
`lingpet_acquire_cutin_no_sync_load_smoke.gd`.

## Godot Animated Polygon Triangulation Trap

Any Godot `draw_colored_polygon()` point set built from jitter, sag,
shrink/dissolve, sine waves, or other animated offsets must prove the fill is
triangulable before shipping. Prefer geometry that cannot self-intersect
(bounded angle jitter, nonzero area, stable point order); otherwise guard only
the fill with `Geometry2D.triangulate_polygon(points)` and keep outlines or
safe fallbacks visible. Add a sweep smoke for the builder, and treat repeated
`Invalid polygon data` log lines as a frame-budget regression signal. The full
runtime rule lives in `AGENTS.md` under "Godot Degenerate
`draw_colored_polygon` Trap".

## Godot Effect Drawer Static-Frame Trap

When a Godot effect zone drawer reads its life/elapsed from a different key
than the per-frame tickdown updates, the visual appears for the full duration
as a frozen frame-0 still and then disappears -- the timer is decrementing,
but the drawer is looking at the wrong field. Reference failure: the Commando
fire-support airstrike used `GrenadeExplosionDrawer.draw_zone()`, which reads
`duration_frames` first (fallback `timer_frames`), but
`commando_firearm_impact_flash_resolver` set both `duration_frames` and
`timer_frames` to the same initial value, and `advance_timed_effects()` only
decrements `timer_frames`. The drawer therefore saw a constant elapsed=0 for
the entire airstrike, producing a static "pop in / pop out" instead of the
animated grenade-style blast.

Standing rules for effect zone / impact flash wiring:
- Pick ONE timer key (`timer_frames` OR `duration_frames`) per effect family
  and use it consistently across resolver -> tick -> drawer. Do not duplicate
  the same initial value into both keys "just in case."
- If a shared drawer reads `duration_frames` first with `timer_frames`
  fallback, any caller whose tickdown updates only `timer_frames` must NOT
  set `duration_frames` in the zone dict at all. The fallback chain only
  works if the unwanted-by-this-caller key is absent.
- Add a focused smoke that asserts the impact-flash dict does NOT carry the
  static-only key the drawer would prefer
  (`commando_firearm_impact_flash_resolver_smoke.gd` is the reference: it
  asserts `not fire_support.has("duration_frames")`).
- When porting a grenade-style explosion to a new weapon / item / boss skill,
  verify in-game that the explosion actually animates -- a static frame-0
  render can hide behind correct radius / color / texture metadata and a
  passing tick-decrement smoke.
- Terminal projectile-death dispatch must whitelist which death reasons get a
  visible impact flash. A dispatcher that appends a flash for ANY non-empty
  reason pops the flash at the projectile's quasi-random death position --
  the Commando pistol spread-miss bug is the reference: bullets dying via
  `"expired"` / `"out_of_bounds"` (cross-field spread misses, stage 2
  rock-ricochet deaths) drew the red-orange starburst at random mid-field
  positions. Bullet-kind projectiles must fizzle silently on those reasons,
  while `"expired"` stays a legitimate detonation reason for rocket /
  support / drone / net payloads
  (`commando_firearm_projectile_impact_state._should_spawn_impact_flash`,
  sealed by `commando_firearm_projectile_impact_state_smoke`
  `_verify_bullet_terminal_fizzle_is_silent`). Remember the amplifier: an fx
  host anchored to `impact_flashes[0]`
  (`stage1_commando_firearm_fx_host.gd`) replays a large glow + one-shot
  particle burst at whatever position lands in that array, so auditing only
  the immediate-mode drawer understates how visible a stray flash entry is.

## Godot Negative-Z Backdrop Host vs Ancestor Opaque Fill Trap

Canvas `z_index` is sorted globally within a CanvasLayer, not per-parent. A
"draw behind my parent" host node with negative z (`z_as_relative`) therefore
draws before EVERY z=0 canvas item in the layer — including the screen-root
ancestor's `_draw`. If any ancestor paints an opaque full-screen background
(`draw_rect(view, color, alpha≈1.0)`), the entire negative-z host subtree
(every TextureRect layer, every GPUParticles2D child, regardless of their own
positive relative z) is silently and permanently covered. There is no error,
state smokes still pass (`visible=true`, correct modulate/texture), and the
on-screen result just "looks unchanged", so the burial can ship unnoticed for
weeks. Reference failure: the character-select preview VFX host (z=-20,
designed only against its parent `character_live_preview`'s immediate draw)
was buried by `character_select_screen._draw_background()`'s opaque
full-screen fill the whole time — discovered 2026-06-12 only when the new
chamber backplate "didn't show" despite every state probe reading correct.

Standing rules:
- When adding a negative-z host under a Control whose ANCESTORS also do
  immediate `_draw`, audit every ancestor for full-screen / panel-covering
  opaque fills. The direct parent is not the only cover candidate.
- z alone cannot slot a child between an ancestor's `_draw` and its parent's
  `_draw`: any negative z sinks below the ancestor too, and z=0 rises above
  the parent's own canvas item. The working fixes are (a) cut a hole in the
  ancestor's opaque fill at the host rect (4-strip
  `_draw_rect_excluding_hole` + an explicit "host active" gate like
  `character_live_preview.is_backdrop_host_active()`), or (b) restructure the
  host as a z=0 sibling tree-ordered before the actor renderer.
- A backdrop / VFX host integration is not "done" on state smokes alone. The
  sign-off requires a PIXEL-level check — run the real scene windowed, take a
  viewport screenshot, and confirm the layer actually reads on screen. The
  reference incident had `visible=true`, correct texture, correct modulate,
  and zero visible pixels.
- When a previously-buried backdrop finally shows (or a new backplate lands),
  re-QA the backdrop ART against the foreground figure before trusting old
  "looked fine" reads — and treat new "character asset defect" reports with
  suspicion. Reference: the chamber backplate's dark center-top ceiling band
  read as a black nukki stain behind Io's head the day the burial fix landed
  (2026-06-12), while the sheet alpha, every draw call, and every layer were
  clean. Diagnose by pixel-DIFFING with-character vs without-character
  captures of the same scene: if the "fringe" pixels equal the
  backdrop-only render, the defect is the backdrop art (fix the art, e.g.
  brighten the pocket / extend the beam), not the sprite or the renderer.
- The same incident's second wave: RELIGHTING a backdrop invalidates every
  dark overlay that was tuned against the old dark backdrop. The
  thigh-cutline dissolve shroud (near-black pool, alpha 0.94, tuned the same
  day against the pre-lit room) became a "black fog swallowing the legs"
  stain the moment the bright summon column landed behind it — its bell
  falloff leaves bright floor exposed on both sides, maximizing the
  contrast. When a backdrop gets brighter, re-audit the shrouds / aprons /
  contact shadows drawn over it and re-tint them as shadows OF the lit
  scene (scene hue, moderate alpha), never neutral near-black.

The same burial happens with a POSITIVE-z child when the ancestor's z is set
HIGHER by a SPAWNER/DRIVER elsewhere — not just with negative z. Reference
failure (2026-06-23): the plaza character-info overlay host
(`plaza_scene._ensure_character_info_overlay_host`) used
`z_as_relative=false; z_index=120` (an absolute 120), but the LIVE plaza node is
given `z_index=1200` by `stage_clear_result_screen._spawn_plaza_scene` and the
plaza paints an opaque full-screen `_draw` fill, so within the one CanvasLayer
the host (eff z 120) sorted BELOW the plaza node (eff z 1200) and its z≈1200
siblings (interior view, warp host). The overlay opened on TAB (correctly
freezing `update_plaza` movement at its modal gate) but rendered invisibly —
reading in-game as "TAB does nothing AND movement is stuck." Standing rules:
- A child meant to sit "on top" must not use a fixed ABSOLUTE z that a spawner
  can later exceed on an ANCESTOR. Either ride the parent with
  `z_as_relative=true` + a positive offset (eff z = parent_z + offset, adapts to
  whatever z the driver picks), or use an absolute z above the known driver
  ceiling. The host author usually does NOT set the ancestor's z — grep the
  spawner/driver (here `_spawn_plaza_scene`) for the ancestor z before trusting
  any absolute child z.
- A state/`visible`-boolean smoke does NOT catch this: `is_active()`/`visible`
  are true while the host is buried. Assert EFFECTIVE z under the DRIVEN
  ancestor z (compute `z_index if not z_as_relative else parent_z + z_index`),
  and reproduce the driven condition (set the ancestor z to its live value, e.g.
  1200) — a standalone test where the ancestor defaults to z=0 leaves the child
  on top and silently hides the bug. Reference seal:
  `plaza_character_info_overlay_z_order_smoke.gd` (asserts host eff z > plaza
  root eff z under a forced z=1200, reverse-verified to FAIL on the old absolute
  120).

A sprite sheet with a lateral action (throw, strike, aim, lunge) is authored
facing ONE direction, and that authored facing is invisible in code -- you
must open the PNG to know it. Any runtime that can play the sheet in BOTH
gameplay directions must mirror the draw when the actual action direction
opposes the authored facing, and the projectile / effect spawn point must
come from the acting limb (offset toward the facing direction), not the body
center. Reference failure: the Stage 2 pillar monkey stored `facing_right`
at spawn but `_draw_monkey` never read it, and the banana spawned at body
center -- a right-tree monkey visibly threw toward the letterbox while the
banana flew left into the field from behind its back
(`stage2_monkey_banana_event.gd`).

Standing rules:
- A per-actor facing / direction flag that exists only in the spawn dict is
  a red flag -- grep that the renderer actually consumes it.
- Mirror via the established UV-swapped `draw_polygon` helper
  (texture-size-normalized UVs; see `_draw_flipped_sheet_frame` /
  `lingpet_companion_renderer._draw_flipped_texture_region`), not a
  negative-width Rect2.
- The smoke must assert the OUTCOME pair: the flip decision matches the
  actual travel direction of the spawned projectile, AND the spawn point is
  offset to the facing side of the actor center
  (`stage2_monkey_banana_event_smoke` facing / launch-point block is the
  reference).
- The projectile spawn TIME must match the sheet's hand-empty frame, not a
  round-number delay. If the sheet holds the object in-hand through frame N
  and shows an empty hand from frame N+1, spawn the projectile exactly when
  frame N+1 lands (derive the release constant from the frame mapping, e.g.
  `2.0 / 7.0`, not `0.5`), or the object visibly vanishes between wind-up
  and release.
- If the actor lives in the screen letterbox (pillar tree, outer chrome),
  the projectile's draw cull must include the letterbox band in game
  coordinates (`game_offset.x / render_scale` each side), not just
  `0..WIDTH` plus a small margin -- otherwise the projectile pops into view
  mid-flight at the field edge even though its motion math is correct.

## Godot Per-Frame Probability Roll Trap

A `chance_pct` that is meant as a per-opportunity success rate but is rolled
**every frame** inside a multi-frame gating window does NOT behave like that
percentage. The ball / actor sits inside the qualifying window for `N` frames,
so the felt success rate is the compounded `1 - (1 - p)^N`, which saturates
toward certainty and **washes out level / rarity scaling**. The reference
failure: `lingpet_ring_dash` (링크포트) rolled its `ring_dash_chance_pct`
inside `advance()` every frame the descending ball was in the lower guard band.
With ~9-17 window frames, Lv.1 12% compounded to ~70% and Lv.5 32% to ~99%, so
both passive levels felt identical in play even though the catalog numbers
differ 2.7x.

Standing rules for chance-gated per-frame gameplay effects:
- Decide whether the displayed percentage is **per-opportunity** or
  **per-frame**, and make the code match. The default player-facing intent is
  per-opportunity.
- For per-opportunity semantics, gate the roll with a "already rolled this
  opportunity" lock and clear it only when the opportunity genuinely ends
  (e.g. ball stops descending / new rally / actor leaves the window), NOT every
  frame the gate is briefly false. `lingpet_ring_dash_state._rolled_this_descent`
  + `_update_descent_roll_lock()` (cleared on `ball_vel.y <= 0` or ball
  inactive) is the reference pattern.
- Add a focused smoke that proves a **failed** roll does not re-trigger within
  the same opportunity, and that a fresh opportunity re-arms exactly one roll
  (`lingpet_egg_runtime_smoke._verify_ring_dash_single_roll_per_descent`).
  A success-only test (force_roll = always-succeed) passes either way and hides
  the compounding bug.
- When auditing a new chance-based lingpet passive / item proc / boss-skill
  gate, check the call cadence first: if the roll site is reached from
  `_process` / `_physics_process` / a per-frame `advance()`, assume per-frame
  compounding until proven per-opportunity.
- **Before "fixing" a displayed-stat-vs-felt-behavior gap by buffing power,
  confirm the stat's INTENDED SCOPE with the design owner — the gap is often a
  scope/labeling issue, not a reach deficiency.** Reference saga: `lingpet`
  `defense_rate` ("방어율") armed an intercept correctly but at 155px/s (≈ patrol
  speed) usually could not REACH the predicted ball X, so the displayed 30%
  blocked fewer balls than it implied. The first "fix" assumed defense should
  cover the WHOLE field and raised the speed to 420px/s — which made the lingpet
  sprint across the field and read as a robotic teleport, NOT what the design
  wanted. The actual intent was a **local predictive guard**: the lingpet only
  guards uncatchable balls that fall NEAR it (it is not a field-wide goalkeeper).
  The correct fix was therefore to SCOPE the stat, not buff reach: an eased speed
  (the live lever is now `COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS` in
  `lingpet_companion_motion_state.gd`, NOT the retired `COMPANION_DEFENSE_INTERCEPT_SPEED`
  constant) and arm defense only for balls that match the FULL intent --
  (1) the **player cannot block** the predicted X (`_player_can_block`, mirroring
  `lingpet_ring_dash_state`; guarding a ball the player could make is pointless),
  (2) the predicted X is within a generous **local commit zone**
  (`COMPANION_DEFENSE_LOCAL_ZONE`) of the lingpet, (3) the roll passes. Far /
  player-blockable balls never arm (out of scope, by design). **Crucially, the
  commit is ANTICIPATORY, not "reachable THIS frame".** An earlier iteration gated
  on a tight `reachable_distance = speed*(time_left)*factor` window, so at the slow
  180px/s the guard committed too LATE and a high (even 100%) defense rate still
  whiffed nearby balls — the lingpet only "decided" once the ball was already close
  enough to reach instantly, by which point it usually wasn't. The fix: commit as
  soon as the ball enters the band within the local zone, then anchor to the
  re-predicted landing X and ease toward it EARLY across the whole descent; the slow
  speed itself caps total travel so anchoring/tracking can never become a field
  sprint. The displayed rate is then honest WITHIN the local zone, and the tooltip
  says so ("링펫 근처로 떨어지는 … 미리 예측해 가드"). **2026-06-25 update: the
  guard-speed floor was deliberately raised `+30% → +60%`
  (`COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS = 0.60`, maribo ≈156 → ≈192px/s) by
  design-owner decision after a felt-gap report that defense activation read
  IDENTICAL to patrol.** The saga's caution is about SCOPE (LOCAL + eased motion,
  not a field-wide goalkeeper) and about confirming intent with the design owner
  BEFORE buffing — NOT a hard cap on raw speed. So do not read the older "subtle,
  slightly-above-patrol" wording as an invariant and revert this raise; the single
  lever is `COMPANION_DEFENSE_GUARD_SPEED_MIN_BONUS` and live felt-QA decides its
  value. NOTE: the defense intercept
  (`lingpet_companion_motion_state`) and the Linkport passive
  (`lingpet_ring_dash_state`) are SEPARATE systems with their own gates -- do not
  assume a gate present in one (e.g. `_player_can_block`) exists in the other.
  Also: defense intercept is **PATROL-only** — flight-style companions
  (`sortie_flight` / `free_flight`) skip it in `lingpet_companion_motion_state.update`,
  so `_get_current_defense_rate()` returns 0 for non-patrol pets (override included)
  and the character-info panel hides the 방어율 row when the rate is 0. A new
  flight-style lingpet must keep `defense_rate: 0.0` in the catalog (a nonzero value
  is dead data that only misleads the UI).
- **A displayed chance/rate stat must produce its real gameplay OUTCOME (within
  its intended scope), and the smoke must assert the outcome.** Standing rules:
  (a) write the smoke against the end effect (ball bounced / `ball_vel.y < 0`,
  damage dealt, status applied), not the arming/attempt flag —
  `_verify_maribo_defense_actually_blocks_reachable_ball` asserts a near ball is
  actually bounced; (b) any tuning that gates the follow-through (chase speed vs
  arrival time, projectile speed vs distance) must be checked against the real
  time/space budget; (c) keep an out-of-scope / "does NOT always succeed"
  counter-case so the effect is neither a guaranteed wall nor silently dead —
  `_verify_maribo_defense_rate_intercepts_descending_ball` asserts a far ball does
  NOT arm; (d) **a smoke that hand-advances the ball must mirror the runtime's
  per-frame distance `ball_vel * delta * 60` (`ball_update_controller`
  `fps_scale = delta*60`), NOT raw `ball_vel` per step.** Raw `ball_vel` per step
  (e.g. `ball_y += 12`) descends ~3x too slowly at `delta=0.05`, handing the
  defender an inflated window so the test passes even at a too-slow speed; use
  `ball_y += ball_vel.y * delta * 60`.
- **Lingpet companion test trap: Maribo's auto-cast skill wind-up FREEZES
  companion motion.** `windup_active` is passed as `freeze_motion` to
  `lingpet_companion_motion_state.update`, so during the ~1s Hydro Sphere wind-up
  the companion cannot patrol or run a defense intercept. A multi-frame companion
  motion smoke must first let the initial cast actually LAUNCH (needs an active
  ball parked away from the lane) so the skill enters its 40s cooldown; otherwise
  the wind-up re-arms and the companion stays frozen through the scenario.
- **Interaction-grant variant: a player-driven reward grant (pet click rapport,
  future companion petting / feeding rewards) needs BOTH the per-opportunity
  edge lock AND round/battle caps owned by the battle lifecycle — global,
  pet-id-agnostic, surviving pet switch / re-hatch.** The edge lock alone
  leaves an AFK re-trigger loop (~one grant per animation cycle), and per-pet
  cap counters re-arm on pet switch. Reference: lingpet 교감 click grant —
  start()-edge-only award in `try_begin_companion_click_reaction` (the
  already-active replay branch must not grant) + battle-global caps in
  `lingpet_affinity_state` (round 2 / battle 5), sealed by
  `lingpet_affinity_state_smoke`'s same-round pet-switch cases.

## Godot Companion Walk/Idle Ratio Trap (treadmill in place)

**ROOT-CAUSE WARNING — a stationary "marching in place" companion is usually a
POSITION-stuck bug, not an animation bug. Chase the motion first.** The lingpet
"제자리걸음" saga: the companion appeared to march in place; several animation-side
fixes (the mechanisms below) only changed WHETHER the stuck pet showed a walk or
an idle frame — they never made it move. The real cause was that the defense
intercept parks `patrol_dir = 0` when it arrives at the guard point
(`lingpet_companion_motion_state._advance_defense_intercept`), and NOTHING
restores it once the guard clears: `clear_defense_intercept` does not touch
`patrol_dir`, a flip is `-1 * 0 = 0`, and a heading-less pet can never reach a
lane edge to be re-aimed — so `next_x = pos.x + 0 * speed = pos.x` froze the pet
in place until a round reset re-`initialize`d it ("게임 진행하다보면 풀린다").
With the INTENDED `motion_speed_ratio` still > 0 this read as a walk treadmill;
after the actual-movement gate (Mechanism C) it read as a frozen idle — SAME
bug. Fix: re-seed `patrol_dir` to ±1 in the patrol movement section whenever it
is zero (that section only runs once the defense guard is inactive). Sealed by
`lingpet_egg_runtime_smoke._verify_patrol_dir_recovers_after_defense_park`
(reverse-verified: the pet stays frozen without the re-seed). Lesson: when a
companion "walks in place", first prove whether `_companion_pos` actually
advances frame-to-frame; if not, the animation gate is downstream of the real
(motion) bug. Any code that zeroes `patrol_dir` mid-game (defense park, future
grab/displace skills) must restore a heading on release.

`lingpet_companion_motion_state.motion_speed_ratio` is the companion
renderer's walk/idle GATE and walk-anim speed
(`lingpet_companion_renderer` picks the walk sheet when ratio > 0.01;
`get_walk_frame` then cycles on WALL-CLOCK time). Any motion-state /
override writer must therefore write the ACTUAL per-frame movement speed
into it, never an intent / capability constant — a positive ratio on a
stationary companion renders as full-speed walking in place, ships
silently (no error, state smokes pass), and only shows in live play.
Reference failure: the defense intercept set the ratio from the 225px/s
guard-speed cap for the whole intercept-active window, but the
anticipatory guard ARRIVES EARLY BY DESIGN and parks at the predicted
landing X — so the parked guard treadmilled at max walk FPS. Fix = track
the real step speed (`defense_intercept_step_speed`, 0 in the
arrived-hold branch; `patrol_speed` alone is NOT enough — it retains the
last chase speed on arrival), sealed by `lingpet_egg_runtime_smoke.
_verify_maribo_defense_hold_stops_walk_animation` (verified to FAIL
against the constant-ratio code).

This trap has THREE distinct mechanisms; the defense-hold above is only
one. The other two were the dominant cause in live play and are now fixed
together:

- **Mechanism A — skipped `update_lingpet` + wall-clock anim.** Every
  early-return pause branch in `battle_frame_flow_controller.update()`
  (Smasher power-smash freeze ~1.65s, mythic acquisition cinematic,
  scoreboard fade-in, stage3 kuromi / psychoball hitstop) skips the
  `update_lingpet` callback while still calling `queue_redraw`. The
  companion is still drawn with its STALE `motion_speed_ratio` (> 0.01 if
  it was mid-walk), and the walk frame used raw `Time.get_ticks_msec()`,
  so it kept cycling — marching in place — while the frozen pet never
  moved. Fix: drive the walk frame from an accumulator
  (`LingpetCompanionSpriteAnimator.walk_phase`, advanced by
  `advance_walk_phase()` which is called only inside the `update_lingpet`
  tick) instead of wall-clock. A skipped tick freezes the phase → a still
  frame, not a march. The wall-clock path stays as a fallback for any
  animator instance that never calls `advance_walk_phase` (the soul-clone
  has its OWN animator). Sealed by
  `_verify_walk_animation_freezes_when_update_skipped`.
- **Mechanism B — position-override forces draw ratio 1.0.**
  `lingpet_egg_runtime._get_companion_draw_motion_speed_ratio()` hardcoded
  `1.0` for the skill-host and starlight-tracking override branches,
  regardless of whether the override actually MOVED the pet. The starlight
  pickup-hold (~1s, common on ground pets like maribo that have
  `lingpet_starlight_tracking`) and skill holds (doll-curse cast, headbutt
  repeat-wait) park the pet → walked in place. Fix: the override branches
  return a real **horizontal** movement ratio (`_companion_override_move_ratio`,
  computed each tick in `_advance_companion_draw_anim` from the x-delta of
  `_companion_pos`). A held override → 0 → idle; a moving one → walk. Use
  x-delta, NOT vector length: the walk sheet is side-view locomotion, so a
  pure vertical hop (the starlight pickup jump arc keeps x fixed) must read
  as idle. Sealed by `_verify_starlight_pickup_hold_reads_idle`.
- **Mechanism C — PATROL/defense path used INTENDED speed, not real movement.**
  Mechanism B fixed only the override branches; the patrol/free-flight branch of
  `_get_companion_draw_motion_speed_ratio()` still returned
  `motion_speed_ratio` (the motion state's INTENDED speed, derived from
  `patrol_speed` / defense step speed). That intended ratio can stay > 0.01 on a
  frame where the drawn position does NOT actually advance — defense intercept
  arriving at a lane-clamped target, a zero/negative-delta tick recomputing
  `_speed_ratio(patrol_speed)`, sub-tolerance re-anchoring — so a stationary
  patrol pet (nekuring: patrol + `defense_rate` 0.14, no starlight) marched in
  place. Fix: the patrol/free-flight branch now ALSO returns
  `_companion_override_move_ratio` (real per-frame x-travel), so a genuinely
  static companion reads idle no matter WHICH path left the intended ratio
  positive. The seed frame (just adopted, `_companion_draw_pos_prev == ZERO`)
  falls back to the intended ratio for that one frame so the first visible frame
  isn't a spurious idle. Sealed by `_verify_patrol_static_frame_reads_idle`
  (a zero-delta tick: intended ratio positive, position unchanged → draw idle).
- **Threshold parity.** `LingpetCompanionSpriteAnimator.get_walk_frame` idled
  only at `ratio <= 0.0`, but the renderer's "moving" gate is `ratio > 0.01`. A
  ratio in (0, 0.01] therefore made the renderer pick the IDLE texture while
  `get_walk_frame` still CYCLED it — the idle sheet marched in place. Both now
  use `MOVING_RATIO_THRESHOLD = 0.01`; keep them in lockstep.

Standing rule: the companion walk/idle gate must be driven by ACTUAL drawn
movement (or 0 when held), for EVERY non-flight path (overrides AND patrol/
defense) — never by an intent / capability constant (`motion_speed_ratio`,
guard-speed cap, hardcoded 1.0) that can diverge from real displacement. The
walk-frame CLOCK must freeze whenever the companion's own update tick is
skipped, and the renderer's "moving" threshold and the animator's idle
threshold must match. When adding a new pause branch that skips
`update_lingpet`, a new override / skill that parks the companion, or any new
`motion_speed_ratio` writer, re-audit all of these mechanisms.

## Godot Companion Teleport/Reposition Locomotion Trap (ground pet keeps Y)

Any lingpet skill / passive that SCRIPTS a companion's position (teleport, blink,
dash, recall, vacuum, future reposition skills) must respect the pet's
locomotion style when choosing the target Y. **Ground (`patrol`) lingpets cannot
move into the air**, so a position override for a patrol pet must keep the pet's
current ground-lane Y and only change X. Flight pets (`sortie_flight` /
`free_flight`) may move freely in Y. Reference failure: Linkport
(`lingpet_ring_dash`) teleported a descending-ball interceptor to the player
guard-center Y (`_resolve_player_guard_center_y`) for ALL pets. For a patrol pet
that Y differs from its patrol lane Y by `guard_y - patrol_lane_y`, which is
**paddle-height dependent**: ≈0px at the 50px base paddle (so state smokes that
use the base paddle never caught it) but a clearly visible upward pop once a
paddle-height perk/item raises the paddle (≈15px at 75, ≈38px at 120). The pet
appeared to jump up into the air to hit the ball. Fix: pass the motion style into
the position-scripting state and branch the target Y — `current_companion_pos.y`
for ground pets, the guard-center dive only for flight pets
(`lingpet_ring_dash_state.advance`'s `motion_style` arg →
`_build_target_data`'s `is_ground_pet`).

Standing rules:
- A companion position override's target Y must be chosen by locomotion style,
  not a single field-wide anchor (guard line, ball Y, player center). Ground =
  keep current lane Y; flight = free.
- The regression smoke MUST use a **non-base paddle height** (the divergence is
  ~0 at the 50px base, so a base-paddle test passes even with the bug) and assert
  the OUTCOME pair: ground pet Y stays on its lane (only X teleports) AND a flight
  pet still dives to the guard line. Reference:
  `lingpet_egg_runtime_smoke._verify_ring_dash_ground_pet_keeps_y_on_teleport`
  (paddle 75; reverse-verified to FAIL on the old guard-dive code) plus the flight
  guard-Y assert added to `_verify_ring_dash_passive`.

## Godot Lingpet Companion Incapacitation Body-Hit Trap (parked ≠ disabled)

A lingpet skill phase that INCAPACITATES the companion (self-stun, freeze,
knockdown, recoil-hold) by parking it via a position override does NOT stop the
companion from bouncing the ball or firing an anticipatory strike. Body-hit
availability (`lingpet_companion_body_presence_resolver.is_available_for_hit`)
returns true for ANY active position override, and the strike anticipator +
the ball-body-hit path (`lingpet_egg_runtime` ~L1996,
`lingpet_companion_strike_anticipator`) both gate ONLY on
`skill_runtime_surface.is_companion_body_hit_suppressed` →
`skill_runtime_host.suppresses_companion_body_hit(skill_id)`. So a parked-but-
overridden companion stays fully hittable unless the skill is explicitly added
to that suppress switch for the incapacitated window. Reference failure: Onimaru
뿔박치기 self-stun (`lingpet_headbutt_skill`) parked the pet with stun stars but
it kept receiving the ball, contradicting the arena HornCharge porting intent
(`downtown/hero_skills.py` PHASE_STUN stuns the caster too).

Standing rules:
- Any companion skill with an incapacitation window must expose
  `suppresses_companion_body_hit()` returning true ONLY during that window, and
  the host's `suppresses_companion_body_hit(skill_id)` match must route the
  skill kind to it (the headbutt case is the reference). One switch gates BOTH
  body hit and anticipatory strike — do not try to suppress them separately.
- Suppress ONLY the incapacitated window, not the whole skill: an active
  dash / charge phase where the pet is meant to be a live attacker must stay
  hittable (Onimaru suppresses during self-stun but NOT during the charge).
- The smoke must assert the OUTCOME across phases: NOT suppressed during the
  active/charge phase, suppressed during the incapacitation, and resumed after
  it clears, AND drive the runtime HOST (not just the skill object) so a missing
  `SKILL_KIND_*` case in `suppresses_companion_body_hit` is caught
  (`lingpet_headbutt_skill_smoke` self-stun + host-routing block is the
  reference).

## Godot Owner-Field Schema Trap (runtime stat → character-info panel)

The battle `owner` (`battle_scene_shell`) routes `owner.set(key, value)` /
`owner.get(key)` through `battle_scene_state` `set_value` / `get_value`, which
**only store / return keys present in `BattleSceneState.DEFAULT_VALUES`**. A
`set()` to a key NOT in that schema is a **silent no-op** (no error), and a
`get()` returns null → callers fall back to their default. So any per-frame
runtime value you sync onto the owner for another system to read (e.g. the
character-info panel) is **silently dropped unless the key is declared in
`DEFAULT_VALUES`**.

Reference failure: the F7 lingpet defense-rate override didn't show in the
character-info panel. `lingpet_runtime_snapshot_builder.sync_owner` wrote
`owner.set("lingpet_companion_defense_rate", _get_current_defense_rate())` every
frame, but `lingpet_companion_defense_rate` was missing from `DEFAULT_VALUES`, so
the write no-opped and `character_info_overlay_lingpet_snapshot_builder` fell back
to `LingpetCatalog.get_stat(..., "defense_rate")` (the catalog/base value). The
base equals the catalog value, so the panel "looked right" until an override made
the live value diverge from the catalog. Fix = declare the key (and its `ringpet_`
pair) in `DEFAULT_VALUES`.

Standing rules:
- When a runtime stat must appear in the character-info panel (or any cross-module
  owner read), confirm the owner key is in `battle_scene_state.DEFAULT_VALUES`.
  If it is not, the sync silently no-ops and the reader uses its fallback.
- A panel/stat that reads `owner.<key>` with a **catalog/base fallback** can mask
  this bug whenever the live value happens to equal the base. Test the DIVERGENT
  case (a runtime override / buff that differs from the catalog value).
- Smokes must use a **schema-gated owner** (delegating to `BattleSceneState`, like
  `battle_scene_shell`) to catch this — a plain dict `FakeOwner` that stores any
  key will pass even when the real schema would drop the write. Reference:
  `character_info_live_stats_smoke._verify_defense_override_reaches_panel_through_schema_gated_owner`
  (verified to FAIL when the schema key is removed).
- This trap repeated at scale (2026-06-12): 17 of the snapshot sync's keys
  (`hit_gauge_gain`, `patrol_speed_*`, `catch_*`, passive bonus pcts, slot
  mirrors) were missing from `DEFAULT_VALUES`, so 교감 기동/게이지 강화 and
  passive stat boosts applied in gameplay but the TAB panel kept showing the
  catalog base. The structural seal is now
  `character_info_live_stats_smoke._verify_snapshot_sync_keys_are_schema_declared`,
  which scans every `_set_pair(owner, ...)` / `owner.set(...)` key literal in
  `lingpet_runtime_snapshot_builder.gd` against `DEFAULT_VALUES` — new sync
  keys fail the smoke until declared. Also remember the pair fallback masks
  single-key omissions: the panel reads `lingpet_*` then `ringpet_*`, so a
  value-level test alone can pass while one of the pair is dropped.
- Slot-index style mirrors need a **negative sentinel default** (`-1`), and the
  owner-read helper must treat negatives as "not synced yet"
  (`lingpet_collection_state.get_active_slot_index_from_owner`); a `0` default
  would force slot 0 over the runtime's internal index on a fresh battle state.
- **Declared-but-never-written-by-the-runtime-sync sub-variant (sibling omits
  the write).** The key can be in `DEFAULT_VALUES` (so `set()` is NOT a no-op)
  and STILL be wrong because the per-frame runtime owner-sync helper never
  writes the LIVE/boosted value onto it — the panel then falls back to a
  DIFFERENT, staler writer (e.g. the stored-loadout base value). This bites
  "second-slot" / duplicated fields whose PRIMARY sibling writes the key but
  the SECOND helper omits it. Reference failure (2026-07-02): the TAB 2nd
  active skill card was pinned at `Lv.1` while 교감 raised its real level
  everywhere else — `lingpet_runtime_snapshot_builder._sync_second_skill_static_owner`
  wrote the 2nd skill's id/name/max/cooldown but OMITTED
  `lingpet_second_active_skill_level`, whereas its primary sibling
  `_sync_skill_static_owner` DOES write `lingpet_active_skill_level`. The only
  other writer (`lingpet_loadout_state.sync_owner`) wrote the loadout BASE
  level (1), so the panel (which reads the owner key at
  `character_info_overlay_lingpet_snapshot_builder.gd` `companion_skill_level_1`)
  never moved. Fix = thread the effective `skill_level` into the second-skill
  static sync AND into the static-surface cache key
  (`_build_owner_static_surface_key`), so a **level-only** change (id/name/max
  unchanged) still re-syncs. Standing rules: (a) when a runtime value has a
  "primary" and a "second/duplicate" owner-sync helper, diff the two — any key
  the primary writes and the second omits is a latent stuck-at-base bug; (b) a
  panel test that MANUALLY `owner.set(key, ...)` then reads the panel does NOT
  catch this — it never exercises the runtime SYNC write. The seal must drive
  the real runtime owner-sync (`LingpetEggRuntime.update(owner)`) with a
  DIVERGENT (boosted ≠ base) value and assert both the owner key AND the panel
  carry the boosted value, reverse-verified to FAIL when the `_set_pair` line
  is removed (`character_info_live_stats_smoke._verify_second_active_affinity_level_reaches_panel_through_schema_gated_owner`).

## Godot Two-Update-Path Context-Flag Trap (effects-path flag read on the ball path)

A boss/character skill whose lifecycle is split across the **effects update
path** (`activate()` / cooldown, reached via `battle_effects_update_controller`,
context built by `battle_update_effects_owner_context_builder`) and the **ball
update path** (`update_and_collide()`, reached via
`ball_frame_motion_controller`, context built by `ball_update_owner_snapshot`)
must sample any **effects-only context flag at `activate()` time** into a member
var. The two paths build DIFFERENT context dicts: a flag like
`enraged_boss_active` is populated only by the effects-context builder; the
ball-path context does NOT carry it, so reading it from a ball-path helper
silently returns the default (`false`) and the gated behavior is dead — no
error, state smokes green. Reference failure: gaksital `fan_throw`'s enraged
±35° extra-fan spread read `enraged_boss_active` inside `_launch_fans` (ball
path) and could never fire; the dalji `spinning_top` template reads it inside
`activate()` (effects path) and works. Fix = capture the flag at `activate()`
(`enraged_launch = bool(context.get("enraged_boss_active", false))`) and have
the deferred ball-path launch read the member, mirroring dalji.

Standing rules:
- For a deferred-launch skill (activate sets a windup, the actual spawn runs
  later on the ball path), audit EVERY context flag the launch reads and
  confirm the ball-path context actually carries it; if it is an effects-only
  flag, capture it at activate() time.
- The regression smoke must use SEPARATE contexts: the flag present in the
  context passed to `activate()`, and ABSENT from the context passed to
  `update_and_collide()` (mirroring the real effects-vs-ball split). A single
  shared context dict fed to both calls masks the bug (the gaksital enraged
  smoke originally did exactly this). Reverse-verify it FAILS on the
  ball-path-read code.

## Godot Lazy Applied-Key Re-Apply Trap

A lazy apply gate that early-returns on "already applied" BEFORE recomputing
its key makes key-CONTENT changes invisible: if an input folded into the key
changes while the stored key string is still non-empty, the gate returns
before the key is ever rebuilt, so "include the new input in the key" alone
is a silent no-op. Reference failure class: `lingpet_egg_runtime.
_apply_current_loadout` early-returns on `_applied_loadout_key != ""` before
`_build_loadout_key` runs — an affinity level-up that only changed key
contents would never re-apply. The only working lever is explicit
invalidation (`_invalidate_current_loadout_cache()` on every level-up) plus
folding the changing input into the downstream value caches
(`lingpet_current_profile` skill-dict cache keys). Standing rules:
- For any applied-key / dirty-key lazy gate, audit WHERE the early-return
  sits relative to the key recompute before claiming "the key includes X".
- The regression smoke must drive the REAL apply path: change the input
  WITHOUT invalidation and assert the stale value persists, then invalidate
  and assert the new value lands (lingpet_egg_runtime_smoke affinity
  synthesis case is the reference).

## Godot Stats-Panel Row Budget Trap

`character_info_overlay_stats_presenter.draw_lingpet_stat_rows` silently
DROPS rows that overflow the section rect (line gap floors at 16px, rows
past the rect bottom break out of the draw loop). A new stat row can pass
every data-model assert (`rows.size() >= N`) while the drawn panel silently
loses its last row in the vertical stacked layout (<620px inner width).
This is the sibling of the tooltip shared-line-budget clip trap. When adding
a panel row, assert DRAW-TIME capacity at the stacked-layout rect via
`lingpet_stat_rows_visible_capacity` (reference:
`character_info_live_stats_smoke`'s 교감-row capacity assert), or define
which row yields when the rect cannot fit.

## Godot Boss Skill Card Rail Commando-Avoidance Trap

Every stage's left-pillar boss-skill card rail shares
`BossSkillCardHudSpec.resolve_stack_start_y`, whose `avoid_rect` argument
(the live `commando_firearm_panel_rect`) is OPTIONAL and defaults to
`Rect2()` — so a stage renderer that calls it WITHOUT passing `avoid_rect`
silently disables Commando firearm-HUD avoidance: the card stack stays
vertically centered and overlaps the Commando (soldier) firearm cluster
instead of shifting above it. No error; only visible when playing Commando
on that stage, and worst on the stage with the MOST cards. Reference
failure: Stage 6 Tetriser (`stage6_tetriser_boss_skill_hud_renderer`,
ported later from Python Stage 7) never read `commando_firearm_panel_rect`
nor passed `avoid_rect`, so its rail — 4 boss skills + the hatched lingpet
card = 5 cards, the largest rail in the game — buried the firearm UI. The
shared drawer (`stage1_pillar_hud_scene_drawer`, used by ALL stages) always
seeds `context["commando_firearm_panel_rect"]`, and every stage HUD context
carries it (Stages 4/5/6 via `context.duplicate(true)`), so the rect is
already available — the only missing wiring is the renderer reading it and
forwarding it as the 8th `resolve_stack_start_y` arg.

Standing rules:
- Any new stage boss-skill card rail renderer MUST read
  `commando_firearm_panel_rect` from its context and pass it as `avoid_rect`,
  exactly like Stages 1-5. Do not rely on the default-empty `avoid_rect`.
- The coverage smoke `boss_skill_card_hud_spec_smoke._verify_stage_renderers_use_commando_avoidance`
  is a hardcoded per-stage path list — ADD the new stage's renderer path to it
  (a new stage is silently uncovered otherwise). Prefer the BEHAVIORAL seal
  `_verify_stage6_layout_avoids_commando_panel` (build_card_layout with an
  overlapping panel rect must shift the stack up above the panel; reverse-verified
  to FAIL when `avoid_rect` is dropped) over a source-string check alone.

## Godot Lingpet Second-Active-Slot HUD Parity Trap

A lingpet can have TWO active skills (slot 0 + a second unlocked active slot),
and the runtime snapshot exposes EACH slot's live state under a **suffixed key
pair**: primary as `companion_skill_*` and the second slot as
`companion_skill_*_1` (`companion_skill_id_1`, `_name_1`, `_cooldown_1`,
`_cooldown_duration_1`, `_ready_1`, `_flash_ratio_1`, `_winding_up_1`,
`_card_path_1`, `_description_1` — produced by
`lingpet_companion_skill_state.get_snapshot(..., "_1")` merged in
`lingpet_runtime_snapshot_builder._build_second_skill_state_snapshot`). There
are TWO parallel HUD consumers of this state and BOTH must read both slots:
the TAB character-info panel (`character_info_overlay_lingpet_presenter.get_skill_specs`)
and the in-battle boss-skill-card rail (`lingpet_rail_card`). The reported bug:
the rail's `build_entry` only read the un-suffixed `companion_skill_id`, so a
lingpet with a second unlocked active (e.g. 모락모랑/rabi = soul_clone +
ghost_summon) showed BOTH cards in the TAB panel but only ONE card on the
battle rail. Fix = `lingpet_rail_card.build_entries()` emits one entry per live
active slot ("" and "_1"); `append_entry` appends all of them.

Standing rules:
- Any HUD / debug / localization surface that reads companion active-skill
  state must handle BOTH slots (un-suffixed AND `_1`), not just the primary.
  Reading only `companion_skill_id` silently drops the second active card with
  no error and passing state smokes.
- **Per-slot casting must be attributed to the slot's OWN skill kind, not a
  shared global OR of every skill's "active" flag.** The rail's `draw_card`
  sets `fill_ratio = 1.0` whenever `status == "casting"`, so if a slot-1 cast
  flags the slot-0 card as casting, the charging slot-0 gauge visibly JUMPS to
  full. The per-effect module flags (`soul_clone_active`, `ghost_summon_active`,
  `hydro_sphere_projectile_active`, …) come from the skill host snapshot keyed
  by KIND (un-suffixed), while each slot's wind-up flag is suffixed
  (`companion_skill_winding_up<suffix>`). Resolve casting per entry via
  `LingpetSkillDispatcher.get_skill_kind(skill_id)` → that kind's flags + the
  suffixed wind-up (`lingpet_rail_card._is_skill_casting`). The two slots always
  run distinct kinds (`would_share_module` collapses to one slot when they'd
  share a module), so kind attribution is unambiguous.
- The regression smoke must assert the OUTCOME pair on a DUAL-active snapshot:
  (a) `build_entries` / `append_entry` emit TWO lingpet cards with each slot's
  own id + cooldown, and (b) casting independence in BOTH directions (slot-1
  casting leaves slot-0 "charging", and the mirror). A single-slot snapshot
  passes even with the bug. Reference:
  `lingpet_rail_card_shared_smoke._verify_build_entries_second_active_slot` /
  `_verify_append_entry_appends_both_active_slots` (reverse-verified to FAIL on
  both the primary-only build and the shared-global-OR casting).

## Godot Boss-Paddle-Scripting Skill Trap (drag / grab / displace the boss)

Any skill that **scripts the boss paddle position** instead of nudging it
(lingpet 꼭두각시 조종 / Koyora puppet grab, future pull / grab / vacuum /
displace ports) must keep these invariants together, or the effect looks broken:

1. **Freeze the boss AI** so it stops re-deriving `boss_pos` from the ball.
   `boss_ai_state.update()` overwrites a bare `owner.set("boss_pos", …)` every
   frame (the headbutt skill only survives because it rides the decaying
   `start_paddle_hit_knockback` channel). For a precise drag-and-exact-return,
   add a context freeze flag that mirrors `viper_dmk_freeze_active` — boss AI
   returns `{boss_pos, boss_vel: 0}` unchanged — and have the skill write
   `owner.boss_pos = scripted_target` every active frame (ordering-independent;
   the freeze is a no-op on position). Reference: `lingpet_puppet_grab_active`
   in `boss_ai_state.gd` + `battle_update_boss_ai_context_builder.gd`.
2. **Preserve the boss's BALL collision while it is displaced.** 2026-06-09
   design decision: match the original Python behavior 100%. The puppet skill
   only scripts the boss paddle position; if that displaced paddle overlaps a
   rising ball, `ball_motion_collision_detector` should still emit
   `EVENT_BOSS_PADDLE`. Do not gate boss collision on
   `lingpet_puppet_grab_active`; that flag is for AI freeze, schema, and cleanup
   only. Historical reversal note: older guidance said to skip this collision
   to keep the goal "open"; that guidance is obsolete. The shipped intent is
   that a dragged boss can still physically bounce a rising ball from its
   displaced position, even when that looks like defending from the wrong side.
   Corollary (2026-06-11 fix): the boss-hit BOUNCE response must anchor to the
   LIVE paddle too. `paddle_bounce_boss_post_hit_handler._snap_boss_hit_ball_pos`
   used to snap the ball's y to the static `boss_y` constant (`BOSS_Y = 25`),
   so with a displaced boss the collision fired correctly but the post-hit
   snap teleported the ball back to the top of the screen on contact. The snap
   now reads the live `context.boss_pos.y` (static `boss_y` only as fallback).
   Any post-hit logic anchored to the boss paddle (ball snap, effect spawn,
   cooldown bands) must use the live `boss_pos`, never `BOSS_Y` / `boss_y`.
   Second corollary (2026-06-11): a boss paddle hit must re-arm
   `boss_collision_cooldown` (Python parity: `pingfighter.py` 174199,
   `BOSS_COLLISION_COOLDOWN_FRAMES = 10`). The Godot port originally relied on
   the `ball_vel.y < 0` gate alone, which is enough for a top-parked boss but
   lets a displaced boss (kiss point just above the player band) ping-pong the
   ball boss<->player every couple of frames. The cooldown is set in
   `paddle_bounce_boss_post_hit_handler` and must be propagated through every
   bounce-result allowlist layer (`paddle_bounce_post_hit_handler` →
   `paddle_bounce_post_hit_step` → `paddle_bounce_controller`) or the scene
   merge silently drops it.
6. **"Below the boss" repositioning hacks must not follow a displaced boss.**
   Stage-side guards that re-place the ball "just under the boss" as a proxy
   for "just under the top goal band" (stage2 quake
   `resolve_quake_boss_backstop`, `stage2_quake_ball_motion_state.apply_boss_launch_guard`)
   must cap their anchor at the HOME band — `min(boss_pos.y, context.boss_y)` —
   or a puppeted mid-field boss makes them teleport the ball from the goal
   line into the player's floor band (stealing a goal / forcing a loss). When
   porting any future "keep the ball below/above an actor" guard, ask whether
   the actor can be displaced by a scripting skill and pick the intent anchor
   (home band) explicitly.
3. **Declare the flag in `battle_scene_state.DEFAULT_VALUES`** (see the
   Owner-Field Schema Trap above) or every `owner.set(flag, true)` silently
   no-ops and neither consumer ever sees it.
4. **Release via a self-healing ownership flag, NOT via `cancel(owner)`.** The
   round-end cleanup path (`ball_round_actor_cleanup.reset_actor_round_state` →
   `lingpet_egg_runtime.reset_round` → host `cancel`) runs with **`owner == null`**
   — the round-cleanup deps (`ball_dependency_context._build_common_round_deps`)
   carry no `owner`, and those deps are cached, so threading owner in is invasive.
   A `cancel(owner)` that depends on the owner being passed therefore **cannot
   clear the freeze flag on round end**, so the stuck `*_grab_active` flag freezes
   the boss into the next round (at whatever `boss_pos` it lands on — it can't move
   or defend). Fix: keep an `_owns_boss` ownership flag that **survives an
   owner-less `cancel()`**, and finish the release (restore boss to the captured
   origin + clear the flag) on the next `update()` that does have the owner (the
   host dispatches `update()` every frame while the pet is equipped). Reference:
   `lingpet_puppet_grab_skill._release` + the deferred-release branch at the top of
   `update()`.
5. **Displaced `boss_pos.y` must be reset at the round-reset layer too.** This was
   a latent asymmetry: `ball_round_controller.reset_ball` reset the player paddle's
   y (`player_y`) but NOT the boss paddle's y — it only re-centered boss **x** and
   kept the current y. Nothing else touched boss y (the boss AI manages x only), so
   a skill that drags the boss DOWN left the dragged y surviving the reset. Fixed by
   adding `boss_y` to `ball_update_static_config.build_reset_config` and restoring
   `boss_pos.y = config.boss_y` in `reset_ball`. Lesson: any skill that moves an
   actor field the round-reset path does not already normalize (here, boss y) must
   either restore it itself on release OR get the reset path to normalize it — and
   `reset_ball` only normalizes the fields it explicitly lists.

## Godot Shared HUD Wrapper Prep-Before-Gate Trap (build-then-discard per frame)

Incident (2026-07-02, 240Hz BattlePerf run, viper + Koyora): on stages 2~5 the
shared `draw_active_item_hud(include_stage1_boss_skill_hud=true)` path spent
0.60→1.27ms per frame under the `stage1.pillar.boss_skill_hud` label WITHOUT
drawing anything. The stage gate (`current_stage != 1 → return`) sat only on
the FIRST LINE of the renderer's `draw()`
(`stage1_dalji_boss_skill_hud_renderer.gd` / gaksital sibling), so the
caller-side wrapper (`stage1_pillar_hud_scene_drawer._draw_stage1_boss_skill_hud`)
still executed its full per-frame prep on every other stage:
`context.duplicate()`, dalji cooldown `get_hud_context()` merge, and
`LingpetRailCard.append_entry()` → `lingpet_egg_runtime.get_snapshot()` (two
skill-slot surfaces + profile surface + full snapshot dict) — all discarded by
the callee gate. The waste was invisible to every state smoke and to visual QA
(nothing on screen changed), and it GREW across a run: cheap while the lingpet
was unhatched (`append_entry` early-outs empty — 0.37ms on stage1), ~1.2ms+
once the companion was active. It was misread at first as "boss skill card
rail grows with card count"; the actual driver was the lingpet snapshot build.

Compounding factor: every stage's OWN boss-skill rail also calls
`LingpetRailCard.append_entry()` per frame (stage2/3/4/5/6 pillar scene
drawers), so on stages ≠ 1 the lingpet snapshot was built TWICE per frame —
one build thrown away.

Standing rules:

- Any shared per-frame HUD / rail wrapper that serves multiple stages (or
  multiple owners) must hoist its cheapest discriminating gate — stage id,
  active flag, companion-active, visibility — to the TOP of the caller-side
  wrapper, BEFORE `context.duplicate()` / merge / snapshot / entry builds.
  Keep the renderer-internal gate as a defense layer, never as the only gate.
- Treat each `LingpetRailCard.append_entry()` call as one full lingpet
  `get_snapshot()` build per frame. N rails alive in one frame = N snapshot
  builds. Before adding a new rail / consumer, either reuse a per-frame cached
  snapshot or prove only the live stage's rail calls it.
- Seal with a call-count smoke on the non-owning stage (snapshot 0 calls,
  renderer draw 0 calls) and reverse-verify by toggling the hoisted gate in
  place (Edit toggle — never git). Reference seal:
  `stage1_dalji_commando_hud_layout_smoke.gd` (stage2 context → snapshot 0 /
  draw 0; stage1 context → snapshot 1 / draw 1).
- Perf-label hygiene is what made this findable: keep `stageN.pillar.*` label
  parity when adding a stage post-HUD path (stage3/4 post-HUD labels
  backfilled 2026-07-02), and treat a label that stays EXPENSIVE on a stage
  where its owner draws nothing as a build-then-discard suspect, not as
  render cost.
- Fix reference: hoisted `current_stage != 1` early return in
  `stage1_pillar_hud_scene_drawer._draw_stage1_boss_skill_hud` (2026-07-02);
  renderer-side guards kept.

## Godot Slot-Indexed HUD State Array-Shift Trap

Incident (2026-07-05, active-item HUD prominence slice): pickup-pop state was
keyed by `slot_index` and retriggered whenever the observed item key changed.
That looked reasonable for field pickups, but active-item use removes
consumables with `active_item_slots.remove_at(slot_index)`, compacting every
later slot one index left. A slot-indexed observer then sees slot 0 change from
banana to soap and slot 1 change from soap to wall, and falsely plays the
"newly acquired" pop on the shifted items even though the player only used an
item. This dilutes any HUD signal whose semantic is acquisition / new arrival.

Standing rules:

- For array-backed HUD slots, `slot_index` is a layout address, NOT stable item
  identity. Treat non-empty -> different-key at the same index as a possible
  shift / swap / replacement unless a separate acquisition event says
  otherwise.
- Acquisition-style HUD effects should trigger only on empty -> non-empty
  transitions (or on an explicit stored-slot pickup event). Empty observation
  may erase the per-slot entry; an item observed after that can start a fresh
  pop. A non-empty key change should update the tracked key while suppressing
  / expiring the acquisition envelope.
- If an effect really means "slot contents changed" rather than "new pickup",
  name it that way and test it separately; do not reuse pickup / acquisition
  language for shifts.
- Audit sibling slot-index dictionaries (`cooldown_complete_flash`, selection
  flash, ready pop, tutorial nudges) whenever the owning array can compact via
  `remove_at`, reorder, drag/drop, or swap. The key question is whether the
  effect follows the slot address or the item identity.
- Seal with both replacement and compaction cases. Reference:
  `active_item_hud_ready_state_smoke.gd` asserts in-place replacement and
  `[banana, soap, wall] -> use banana -> [soap, wall]` compaction do NOT
  retrigger `pickup_pop_pulse`, while empty -> item still does. Reverse-verified
  by restoring key-change-starts-pop behavior and watching the smoke fail.

## Godot Per-Frame Catalog Lookup Trap (miss-case full scan + deep copies)

Incident (2026-07-03, 240Hz rail diagnostic run): boss skill card rails cost
~0.29ms PER CARD per frame while emitting only ~5 cheap canvas commands. The
cost was `LingpetRailCard.is_lingpet_skill()` →
`LingpetCatalog.get_active_skill_entry()`, which scanned ALL 14 pets and
deep-copied (`duplicate(true)`) every pet's skill-pool dicts on EVERY call
(`_normalize_skill_pool`). Non-lingpet ids — every boss card — are guaranteed
misses, so they always paid the FULL scan, and the check ran twice per card
(draw-loop branch + `_draw_card` internal recheck): ~6 full scans ≈ 120 deep
copies per frame, on EVERY stage's rail (stage1 dalji, stage2, stage3, stage4
ponk, stage5 hongryun). The nearly-approved fix was a card static-layer
texture cache; per-layer sub-labels showed the "expensive draw" was ~95%
catalog scan and ~5% raster, so the right fix was a one-time static id index.

Standing rules:

- A catalog / registry helper called from a per-frame draw or physics path
  must be O(1) per call: build a static index once from the const catalog
  (`_active_skill_id_index`), answer membership via `has_active_skill_entry()`,
  and deep-copy only on a HIT whose result the caller may mutate.
- Miss-case cost is the trap core: "is this id one of ours?" asked about
  ANOTHER system's ids (boss cards on a shared rail) pays the scan on 100% of
  calls. When a shared rail / registry mixes entry families, audit the miss
  path's cost, not just the hit path's.
- Helpers that `duplicate(true)` catalog dicts per call are acceptable in
  setup / acquire / level-up paths, NOT in per-frame paths. Grep a new
  draw-path helper for `duplicate(true)` and hidden O(N) loops before
  accepting it.
- Before designing a render-side cache for an expensive-looking draw label,
  attribute the cost with per-layer sub-labels first (context_build /
  cards_draw / text / tooltip split). In this incident the planned
  static-layer cache would have recovered almost nothing.
- Seal: index-vs-scan equivalence, copy-on-hit, and non-lingpet miss-path
  contract in `lingpet_rail_card_shared_smoke.gd`.

The smoke must assert the OUTCOME across phases (boss stays put → dragged down →
pinned at the kiss point → restored to the exact origin) AND that the owner flag
is true while held and false after release, a mid-grab `cancel(owner)` cleanup
case, a **round-end leak regression** that calls `cancel(null)` mid-grab and
proves the next `update(owner)` clears the flag, AND a regression that runs the
real `BallRoundController.reset_ball()` after a drag and proves boss y returns to
`BOSS_Y`, AND a collision regression proving a puppeted boss paddle still returns
`EVENT_BOSS_PADDLE` for a rising overlap, AND an OUTCOME regression that runs
`paddle_bounce_boss_post_hit_handler.apply()` with a displaced `boss_pos` and
asserts the ball snaps below the DISPLACED paddle (no static-top teleport).
Keep the source guard too:
`ball_motion_collision_detector.gd` must not branch on
`lingpet_puppet_grab_active`. Reference:
`lingpet_egg_runtime_smoke._verify_koyora_puppet_grab_skill`.
Koyora Puppet Control is no longer pure-CC: by design it may read
`ball_active` / `ball_pos` / `ball_pos_prev` / `ball_size` so the live ball can
cut the puppet strings during PULLING / KISSING. It still must not read
`ball_vel`, move the ball, change score, or apply damage; the smoke asserts
those boundaries.

## Godot Boss-Paddle-Range-Restriction Skill Trap (clamp / cage the boss)

Do NOT reuse the Puppet Grab freeze pattern for a skill that only restricts the
boss's allowed x range while the boss should still play. Rahoset 모래감옥 /
Sand Prison is the reference: during CREATE the boss is fully free to dodge; on
capture the skill writes only `lingpet_sand_prison_clamp_active`,
`lingpet_sand_prison_cage_left`, and `lingpet_sand_prison_cage_right`. Boss AI
then computes its normal movement first (dash, knockback, ball tracking,
molotov barrier, etc.) and applies a final x clamp in
`boss_ai_state._apply_lingpet_sand_prison_clamp`. It must preserve
`boss_vel`; killing velocity makes the cage feel like a freeze and breaks the
"boss still bounces the ball inside the cage" design.

Checklist for future cage / lane / wall skills:
- Add owner schema keys in `battle_scene_state.DEFAULT_VALUES`, propagate them
  through `battle_update_boss_ai_context_builder`, and normalize them in
  `ball_round_state.build_common_snapshot`.
- Clamp final `boss_pos.x` after normal AI output, never early-return from
  `boss_ai_state.update()` unless the design truly scripts the boss position.
- Guard against stale overlap with fully scripted skills:
  `lingpet_puppet_grab_active` remains authoritative over cage clamps.
- Use an ownership flag that survives `cancel(null)` and self-heals on the next
  `update(owner)`; round cleanup often has no owner.
- Smoke the outcome, not just source strings: escape MISS, per-opportunity
  retry rolls, ownerless cancel recovery, round-reset defaults, and a boss-AI
  clamp assertion proving velocity is preserved.

## Godot Boss-Paddle-Resizing Skill Trap (shrink / grow the boss paddle)

Any skill that RESIZES the boss paddle (lingpet 난쟁이마술 / Dwarf Magic shrink,
future giant-boss / grow effects) is a DIFFERENT class from the position-scripting
trap above — and the boss render center is COUPLED to the paddle width, so the
naive fix silently slides the boss sideways:

- The boss sprite is centered on `boss_pos.x + boss_paddle_size.x * 0.5`
  (`stage*_boss_actor_renderer`, fed by `battle_draw_actor_context`), and the
  ball↔boss collision rect is `Rect2(boss_pos, boss_paddle_size)`
  (`ball_motion_collision_detector.check_paddles`, fed by
  `ball_update_context._apply_boss_paddle_owner_state`). So if you shrink
  `boss_paddle_size.x` directly, the render center ALSO drifts left by
  `width*(1-scale)/2` — the boss visually walks toward its left edge while
  shrinking. No error; only visible in-game.
- Correct pattern (Dwarf Magic reference): keep `boss_paddle_size` FULL in the
  shared contexts (so the center never moves) and inject the resize as a SEPARATE
  scale, applied CENTERED on the unchanged boss center:
  - Collision: emit `boss_collision_shrink_scale` from
    `_apply_boss_paddle_owner_state`; the detector re-centers the hit rect
    (`center_x = boss_pos.x + boss_paddle_size.x*0.5`, `eff_w = w*scale`,
    `left = center_x - eff_w/2`) and reports the shrunk `paddle_x` / `paddle_w`.
  - Render: emit `boss_paddle_shrink_scale` from
    `battle_draw_playfield_scene_context`; `battle_draw_actor_context` multiplies
    `boss_sprite_draw_size` (NOT `boss_paddle_size`) by it.
  - Both scales read the SAME owner flags
    (`lingpet_dwarf_magic_shrink_active` / `_scale`).
- The boss AI clamp keeps the FULL width (the boss occupies its full slot; the
  original couples the size debuff with a MOVE-SLOW instead — wire that through
  `boss_ai_state._get_active_item_slow_multiplier` like star_coil, NOT through a
  narrower clamp).
- Owner flags follow the boss-affecting wiring class: declare every key in
  `battle_scene_state.DEFAULT_VALUES` (Owner-Field Schema Trap), normalize them in
  `ball_round_state.build_common_snapshot` (no resize survives a round), and
  self-heal on an owner-less `cancel()`/`reset()` (round-end deps carry no owner),
  exactly like the star_coil boss-slow flags.
- The regression smoke must assert the OUTCOME, not just the flag: an outer-half
  ball that HITS the full paddle must MISS the centered-shrunk paddle (catch area
  actually shrank), reverse-verified against scale 1.0. State smokes pass even if
  the center drifts — geometry checks are what catch it. Reference:
  `lingpet_dwarf_magic_skill_smoke._verify_collision_detector_uses_centered_shrink`
  + `_verify_draw_context_uses_centered_shrink`.

## Godot Shared Stateful Input-Reader Edge-Eating Trap (extra get_snapshot() consumer)

Incident (2026-07-03): equipping 뿔딸기변신가면 (Horn Strawberry Mask, mythic)
silently disabled ALL commando firearm fire (left click / space / X) — even
before any transform. Mechanism: the mask's transform command listener samples
the SHARED per-character input reader every frame while merely equipped
(`mythic_item_horn_strawberry_mask_runtime.update` → `_get_input_snapshot` →
`registry.get_instance("commando_input_reader").get_snapshot()`), and
`battle_frame_flow_controller` runs `update_mythic_items` BEFORE
`update_player_control`. `smasher_input_reader.get_snapshot()` (base of the
commando reader) computed `action_just_pressed` / `action_just_released` /
`mouse_middle_just_pressed` from member edge state (`_last_action_pressed`),
so the mask's earlier call CONSUMED the press edge; the player controller's
later call read `action_just_pressed = false` forever. Commando firearm fire
is edge-gated (`commando_firearm_pistol_input_state` rejects when
`action_just_pressed` is false; ak47 / ammo weapons / suicide drone likewise),
so no firearm could ever fire. No error, no warning; movement and hold-based
inputs (supply drop) kept working, which made it read as a "firearm bug"
instead of an input bug. The viper reader was structurally immune (stateless,
no just_* fields) — that asymmetry is why only some characters broke.

Fix + standing rules:
- `get_snapshot()` on stateful edge-detecting readers (`smasher_input_reader`,
  its `commando_input_reader` subclass, and `blacksmith_input_reader`) is now
  IDEMPOTENT WITHIN ONE PHYSICS FRAME: the first call per
  `Engine.get_physics_frames()` key computes and caches the snapshot; later
  same-frame calls return a duplicate of the cached dict (callers may mutate
  their copy safely). Cross-frame edge semantics are unchanged.
- Any NEW input reader that computes just-pressed / just-released fields from
  member state MUST include the same same-frame guard (`_get_snapshot_frame_key`
  override point exists for deterministic smokes).
- Any NEW off-controller consumer that samples player input per frame (mythic
  command listeners, future gesture/command detectors, replay recorders) must
  either go through the idempotent `get_snapshot()` or read raw levels only —
  never re-derive edges from the shared reader's member state.
- Frame-order context: `battle_frame_flow_controller` order is update_weather →
  update_mythic_items → update_player_control → update_active_items → ... →
  update_effects. Anything sampling input in the mythic/weather slots runs
  BEFORE the player controller and will win any stateful edge race.
- Smoke seal: `player_input_reader_same_frame_edge_smoke.gd` — asserts the
  second same-frame consumer still sees `action_just_pressed` /
  `action_just_released`, the edge stays one-shot across frames, a consumer
  mutating its snapshot copy cannot corrupt later consumers, and the blacksmith
  mirror. Reverse-verified: fails on the unguarded reader at exactly the
  "second same-frame consumer" assertions.


## Godot draw_polygon Un-Normalized UV Invisible-Quad Trap

`CanvasItem.draw_polygon(points, colors, uvs, texture)` expects `uvs` in
NORMALIZED [0,1] texture space. Passing an atlas cell's PIXEL `source_rect`
(`.position` / `.end`, values in the hundreds/thousands) straight through as
UVs pushes every coordinate far past 1.0, and Godot's default canvas UV clamp
then samples only the sheet's edge texel — normally the transparent margin —
so the ENTIRE textured quad renders invisible. No runtime error, no warning;
only pixel QA catches it. (The sibling `draw_texture_rect_region()` /
`draw_texture_rect()` APIs take pixel rects directly and are NOT affected —
which is why one sprite in a module can be visible while another vanishes.)

Confirmed occurrences:
- Stage 5 홍련 fire-machine dragon head: `stage5_hongryun_playfield_renderer`
  `_draw_rotated_texture_region` fed pixel UVs → the whole flamethrower dragon
  head was invisible while the procedural lotus core drew fine (the inferno
  boss-head overlay went through `stage5_hongryun_boss_actor_renderer`, which
  normalizes, so the SAME dragon read correctly on the boss path — two
  renderers, one bug).
- Commando 물자보급 (supply drop) crashing plane (2026-07-03):
  `commando_supply_drop_state._draw_texture_region_rotated` fed pixel UVs, so
  the burning crash sprite was fully transparent during the shoot-down descent
  (the flying plane used `draw_texture_rect_region` and was visible; only the
  faint glow/ring/particle aura showed at the crash, which read as "plane
  motion not visible while crashing").

Standing rules:
- Any NEW rotated / region texture-quad helper built on `draw_polygon` MUST
  normalize: `uv_min = source_rect.position / texture.get_size()`,
  `uv_max = source_rect.end / texture.get_size()`. Guard against a zero-size
  texture (`get_size()` <= 0 → return) before dividing.
- Corner order of `uvs` must match the `points` build order exactly
  (TL, TR, BR, BL is the repo convention).
- Canonical normalized reference helpers to copy from:
  `player_customization_overlay_renderer._draw_rotated_texture_region`,
  `stage5_hongryun_boss_actor_renderer`, and
  `character_info_overlay_lingpet_presenter` (aurora).
- This class of bug is invisible to state/headless smokes — it is a DRAW-path
  defect. Seal the surrounding behavior with a smoke where you can (crash
  lifecycle, shake, knockback) but sign the sprite visibility off with an
  in-game / windowed pixel-QA pass, not a green smoke.
- Related: [[feedback_godot_draw_polygon_uv_normalized]] memory,
  `## Godot Negative-Z Backdrop Host vs Ancestor Opaque Fill Trap` (also a
  pixel-QA-only draw defect), atlas grid-authority trap.


## Godot Modal-Block Gate Skips Loop-Audio Maintenance Trap

Gameplay loop-audio players (`_enable_loop`-force-looped SFX: dash-delay
후딜, warp gate, magnum grip, plasma charge/shock, chaos blackhole, stage
ambient loops, ... — the full set is `gameplay_loop_audio_cleanup.gd`
`STOP_METHODS`) have exactly ONE keep-alive/stop authority:
`battle_effects_update_controller.update()`, which every frame calls
`audio.sync_dash_delay(...)` / the other `sync_*` calls, and
`GameplayLoopAudioCleanup.stop_all(audio)` when `not loop_audio_allowed`.
A force-looped player only stops when that per-frame sync sends `false`.

The trap: a physics-blocking modal returns from
`battle_scene_frame_controller.process_physics` at the
`_should_block_battle_physics` gate BEFORE `update_driver.update()` runs, so
the entire update chain — `battle_frame_flow_controller.update` →
`update_effects` → the loop sync — is skipped for the whole time the modal
is open. Whatever loop was playing the instant the modal opened keeps
looping forever until the modal closes. The physics-blocking modals are the
full `battle_scene_modal_gate_controller` set: character info (TAB), pause
menu (ESC), every debug picker, mythic management, pandora, defeat
settlement, grip selection, elixir/lingpet cinematics, etc.

Reference failure (2026-07-03): dash then press TAB. The dash-delay 후딜
sound is force-looped in `game_audio._enable_loop(dash_delay_sfx)` (note the
WAV `.import` says `loop_mode=0` — the loop is applied at runtime on a
duplicated stream, so the file looks non-looping). Dash recovery
(`dash_stun_timer > 0`) is still active when TAB opens; physics freezes so
recovery never ends, and update_effects never fires `sync_dash_delay(false)`
— the loop drones/repeats for the whole panel.

Why other pauses do NOT hit it: the "soft" pause branches inside
`battle_frame_flow_controller` (scoreboard, mythic acquisition pause,
stage3 kuromi awakening, power freeze, psychoball hitstop) each still call
`update_effects`, which runs the loop sync / `stop_all`. Only the
`process_physics` modal-block early-return skips the update driver
wholesale.

Fix (shipped): `battle_scene_frame_controller.process_physics` calls
`_stop_modal_blocked_gameplay_loop_audio(module_getter)` in the modal-block
branch (next to `_pause_modal_active_item_cooldowns`), which runs
`GameplayLoopAudioCleanup.stop_all(game_audio)`. No matching "resume" is
needed: when physics resumes, `update_effects` re-syncs any still-active
loop on the first live frame (a recovery still in progress simply resumes
its sound). Sealed by
`battle_scene_frame_controller_modal_loop_audio_smoke.gd` (drives
`process_physics` through the modal-block gate; asserts the loop stop fires
when blocked and does NOT fire during non-blocking play).

Standing rules:
- Any NEW physics-blocking modal added to
  `battle_scene_modal_gate_controller._should_block_battle_physics` inherits
  this loop-audio stop automatically (the fix lives at the shared gate, not
  per-modal) — but confirm the modal actually routes through that gate and
  not a bespoke early-return elsewhere.
- Any NEW force-looped gameplay SFX MUST be added to
  `gameplay_loop_audio_cleanup.gd` `STOP_METHODS`, or it will drone through
  every modal (and through the `not loop_audio_allowed` scoreboard / serve /
  ball-inactive stop path) even though its own `sync_*` is wired.
- Do NOT try to fix this by keeping loops alive across the pause; a paused
  game should be silent of gameplay loops (BGM is intentionally excluded
  from `STOP_METHODS` and keeps playing).
- Related: `## Godot Hot-Path Lazy Init Trap` (also about which update path
  runs when), `## Godot Two-Update-Path Context-Flag Trap` (effects-path vs
  ball-path divergence).

## Godot Per-Tick Float Drain Rail-Residue Trap (is_equal_approx write-gating)

Incident (2026-07-04, lingpet satiety/포만도): pets at "0%" satiety never
exhausted in live play — the KO telegraph timer reset every tick — while
every smoke stayed GREEN. Root cause: a real-tick (1/60s ≈ 0.0167) drain
sequence landed the stored satiety on a sub-epsilon positive float residue
(~2e-10). `set_satiety`'s `is_equal_approx(before, next)` write gate then
judged "residue ≈ 0.0 = unchanged" and SKIPPED the 0.0 write, freezing the
residue forever. Every strict-comparison consumer downstream
(`current_satiety > SATIETY_MIN` in `advance_satiety_exhaustion`) treated
the gauge as "still above the rail" every tick, so the exhaustion timer
never accumulated. Displays rounded the residue to "0%", and the slow
curve applied its 0.6 floor — so drain, display, and slowdown all LOOKED
correct while the rail-triggered state (KO) was silently unreachable.

Why smokes missed it: every seal drove the rail with a synthetic exact
value (`set_satiety(0.0)`) or one large-delta drain step whose clamp hits
the rail exactly. The residue only appears in long real-tick sequences —
a live-only failure class.

Standing rules:
- Any per-tick float resource with rail-triggered behavior (drain to 0 →
  KO, fill to max → block) must SNAP a sub-epsilon band onto both rails in
  its single sanitize helper (`_sanitize_satiety_value` pattern:
  `< ε → MIN`, `> MAX - ε → MAX`, ε gameplay-invisible e.g. 0.001).
  Snapping in sanitize fixes reads AND writes at once, so even a frozen
  stored residue reads as the rail.
- Never combine `is_equal_approx` write-gating with strict rail
  comparisons (`> MIN`, `< MAX`) on the same stored float: the gate can
  freeze a value the comparison considers off-rail forever.
- Regression seal must include (a) a direct sub-epsilon residue injection
  (e.g. `set(2e-10)` → assert reads exactly 0 and the rail behavior fires)
  and (b) a real-tick sequence leg (hundreds of 1/60 steps) asserting the
  exact-rail landing — synthetic-exact-0 cases alone prove nothing about
  this class. Reference seal:
  `lingpet_satiety_state_smoke._verify_float_residue_cannot_block_exhaustion`
  (reverse-verified: disabling the snap reproduces the live bug).
- When a live report contradicts GREEN smokes, instrument the REAL decision
  branch (log which branch executed, with raw stored values at full float
  precision) before theorizing — this bug was invisible at %.3f and %.9f
  display precision and only the branch logger exposed "reset(satiety>0)"
  with a printed value of 0.000000000.
