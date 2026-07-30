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

Per-stage REGISTRATION variant (2026-07-27, Stage 6 테트리서): the staged
prewarm sequence is opt-in per stage via a `match current_stage` in
`battle_boot_resource_prewarm_controller._get_stage_specific_runtime_prewarm_step_count`,
and an unlisted stage falls through to `return 0` **silently** — no error, no
warning, no label. Stage 6 was never listed (1,2,3,4,5,7 only), so its whole
visual shell loaded cold inside the first live battle draw frame. Live proof
(same session, S1→S7): S6 spike window #1 carried `actors.lookup_renderer`
43.50ms (module cold-instantiation) + `actors.renderer_draw` 51.70ms (seven
768² boss sheets sync-decoded) = `01.actors.total` 95.37ms, plus
`stage6.pillar.tetriser_boss_hud` 156.61ms (four skillcard PNGs) surfacing as
`draw.pillar_overlay.post_hud` 157.19ms — while **Stage 7 did the same class of
work for 27.17ms inside the loading screen** (`stage_runtime_prewarm.step.13`).
Steady state was innocent (S6 `draw.scene.playfield` avg 2.39ms, CHEAPER than
S4 2.67 / S7 2.78; 1 of 103 windows under 60fps), so aggregate/avg triage hides
this entirely — it is a one-frame entry hitch, findable only in spike windows.

Second footgun in the same defect: a parent actor renderer whose
`prewarm_assets_step()` returns `true` without delegating to its children is a
**silent no-op that reads as "already warm"** — registering the stage in the
controller alone would not have fixed it. Both halves must land together:
controller registration AND child delegation
(`playfield` / `boss` / `commando`, Stage 5 pattern).

Standing rule for every NEW stage: add the stage to the controller `match`
(step count + label + run dispatch) and verify the actor renderer delegates.
⚠️ As of this writing **stage 8 is still unregistered** in both
`battle_boot_resource_prewarm_controller` and
`battle_scene_update_prewarm_key_sets` (its actor renderer DOES delegate
correctly, so only the registration half is missing).

Seal shape — three axes together, because any one alone stays GREEN on the bug
(`stage6_visual_shell_prewarm_smoke`): ① controller wiring (stage step count +
per-step labels), ② registry instantiation before first draw (catches the
`lookup_renderer` cold-create half), ③ **uncached synchronous decode count** —
count assets still absent from `ProjectResourceLoader`'s cache after prewarm,
NOT total loader API calls. Pre-existing `battle_boot_resource_prewarm_smoke`
(no S6 wiring) and `stage6_boss_skill_hud_prewarm_smoke` (HUD module in
isolation, never through the controller) were both GREEN throughout the defect
— a per-module prewarm smoke does not seal that the CONTROLLER ever calls it.
Falsification via in-place toggle: `6:` → `return 0` reddens axes ①②③(cards),
actor step → `return true` reddens the boss-sheet axis. Fix commit `df57dfaeb`.

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

Detached-FX-host-node variant (2026-07-23, plasma): a per-effect FX host
NODE (`SmasherPlasmaFxHost` etc.) created from inside a `_draw()` draw path
is a lazy-init hitch even if you move the create from "first cast" to "first
smasher frame" — the `SmasherPlasmaFxHost.new()` + `add_child()` +
`_ready`→`_build_children` (Sprite2D + ShaderMaterial + GPUParticles2D +
ParticleProcessMaterial) still runs synchronously inside immediate-mode
`_draw`. `prewarm_assets()` (textures/shaders) does NOT cover the node/
material/particle construction. Canonical fix = the commando firearm host
pattern: (a) a `prewarm_node_pipeline()` that `_build_children()` on a
throwaway instance at a boot prewarm step then `free()`s it (warms the
node/material/GPU pipeline); (b) the drawer resolves the host via a
`_get_or_create_*` helper that uses `canvas.call_deferred("add_child", host)`
so `_ready`→`_build_children` runs during idle, OFF the `_draw` path — return
`null` on the create frame so the caller skips sync, and sync only once the
host `is_inside_tree()`. Cache the host ref + gate on `is_inside_tree()` so a
canvas rebuild (freed host) re-creates instead of pending-leaking. Keep any
procedural overlay that does NOT need the host (boss-contact distortion)
drawing every frame regardless of host readiness — do not gate it behind the
host-null early return. Seal with a "host must NOT be a synchronous child
after one draw (deferred), present + inactive after one idle frame" leg
(reverse-verify: swap `call_deferred` → immediate `add_child` ⇒ RED).
References: `stage1_commando_firearm_renderer._get_or_create_fx_host`
(shipped precedent), `battle_playfield_effects_drawer._get_or_create_plasma_host`,
sealed by `smasher_plasma_visual_render_smoke` / `smasher_plasma_fx_host_smoke`.

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

## Godot 보스 예측 모델 트랩 ("불규칙하게 흔들면 막기 어렵다"는 거짓)

**증상 / 설계 오판.** "가드하기 어려운 공"을 만들려고 지그재그·랜덤 스캐터·
넓은 횡이동을 넣었는데 체감상 오히려 더 잘 막힌다. 벽력유성(smasher_overdrive)
초기 구현이 정확히 이 경우였다: 12프레임마다 ±28° 대칭 톱니.

**기전.** `boss_ai_prediction_state._predict_x_until_boss_line`은 공의 **그 순간
속도**를 벽반사까지 포함해 보스 라인(`_get_boss_intercept_y` ≈ 84.3)까지 **정확히
적분**하고, 이걸 **매 프레임 다시 돈다**. 즉 보스는 "현재 속도 기준 도착점"을
항상 정확히 안다. 따라서:

- **부드러운 커브**(드라이브 스핀)는 매 프레임 재추적되어 *지연*만 줄 뿐이다.
- **대칭 주기 지그재그**는 평균이 상쇄돼 보스가 중앙에 수렴한다 → 더 쉬워진다.
- **넓은 횡이동**은 벽으로 흘러 0.95 감쇠를 먹고 각도 레일에 걸린다.
  `smasher_power_smash_motion_resolver`의 주석이 이미 명시한다 — 수직 기준 40°를
  넘는 횡궤도는 "벽으로 흘러 속도를 잃고 **막기 쉬워진다**".

**보스의 유일한 맹점 = 미래 가속도.** 예측 모델에 스핀항·중력항·속도장이 전혀
없다. 그래서 회복 불가능한 것은 단 하나, **비행 마지막 ~8~16프레임에 들어오는
단발 역방향 꺾임**이다. `boss_ai_turn_inertia_resolver`가 이유다: `_approach_target`
의 예측 브레이크가 보스를 예측 지점에 **속도 ~0으로 주차**시키고, 방향을 되돌리려
하면 `_brake_through_reversal`이 `decel × 0.82`(≈0.982 px/f²)로만 제동한다.

**설계 기준값(스테이지1 챔피언).** 이 숫자로 판정하라, 인상으로 하지 말고:

| 항목 | 값 |
|---|---|
| 클린 미스 임계 | `\|도착x − 보스중심\| ≥ 69.3px` (패들 100 + 패딩 5×2 vs 공 반지름 14.3) |
| 정지→T프레임 커버 | `9.476·T − 37.5` (T>15.8), 그 아래는 `0.5·1.197·T²` |
| 전속 역주행 손실 | 9.65프레임 동안 45.8px 반대로 더 감 |
| 실효 리드 | `frames_to_intercept − 1` (보스 AI가 공보다 **먼저** 돔) |
| 각도 상한 | 수직 기준 40° (초과 시 벽으로 흘러 역효과) |
| 각도 하한 | `ensure_min_vertical_component` = 수평 기준 25° |

**표준 규칙.**

1. 꺾임 타이밍은 경과 타이머가 아니라 **보스 라인까지 남은 비행 프레임**으로
   판정하라 — `remaining_y / (|vel.y| · boost)`. `ball_vel`은 60fps-프레임당 px라
   이 값이 곧 60fps-프레임 단위이며 `fps_scale`을 곱하면 **안 된다**.
2. 꺾임은 **단발**이어야 한다. 반복 꺾임은 평균이 상쇄돼 위 맹점을 못 쓴다.
3. 꺾임 **전** 구간은 한쪽으로 확신 있게 흘려 보스를 커밋시켜라(기만). 기만이
   없으면 보스가 중앙 부근에 있어 역꺾임 변위가 임계를 못 넘는다.
4. 벽반사 후에는 기만 사이클을 **재무장**하라 — 보스가 새 heading으로 다시
   예측하므로, 이미 소진된 꺾임으로 들어가면 그냥 잡힌다.
5. **속도장(velocity field)** 클래스를 쓰라. `skip_ball_motion_step`(위치 스크립팅)은
   벽/패들/홀리배리어/벽돌/뿔딸기/뼈/트램펄린/역경갑주 검사를 전부 직접 재구현해야
   하고 해제-플래그 생명주기까지 떠안는다.
6. 너무 강해지는 걸 막는 자기균형 레버가 이미 있다: 변위가
   `boss_max_speed × 1.5 × frames_to_contact`를 넘고 ≥80px이며 잔여 ≤18프레임 +
   수직갭 ≤100px이면 **보스 대쉬 구조**가 무장한다(챔피언 30% / 리미트 60% /
   신화 100%). 변위를 이 위로 두면 상위 난이도에 자동으로 카운터가 생긴다.

**씰 규칙.** 상태 모듈 메서드 직접 호출은 공허-GREEN이다. 발동/종료 레그는
`BallMotionEventProcessor.step_motion`을 관통해야 하고, 궤도 레그는 플래그가 아니라
**결과(변위 px)** 를 단언하라 — "역꺾임을 같은 방향 꺾임으로 바꾸면 변위가 임계
아래로 떨어진다"가 반증검증의 정본이다(벽력유성 실측: 역꺾임 148px vs 동방향
36.4px, 임계 69.3px / 커버 38.3px).

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
  `lingpet_companion_defense_state.gd`, NOT the retired `COMPANION_DEFENSE_INTERCEPT_SPEED`
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
  (`lingpet_companion_defense_state`, orchestrated by the motion facade) and the Linkport passive
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
(`lingpet_companion_defense_state._advance_intercept`), and NOTHING
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

## Godot Emergency-Assist Static-Paddle Gate Trap (committed player dash reads as "can't block")

An emergency-assist gate that asks "can the player block this ball?" by testing
the paddle's **current standing span** against the projected contact X is wrong
the moment the player is mid-**dash**. A dash is a committed, script-driven move
(direction + duration are locked at `start()`), so on every frame of the dash
flight the paddle is not yet at the contact X — the gate reads "player cannot
block", the assist fires, and both defenders converge on the same ball.

Reference failure (2026-07-06, re-implemented 2026-07-27 after the WIP-loss
revert): Linkport (`lingpet_ring_dash`) teleported the companion onto a ball the
player had already dashed to cover — user-visible as 이중수비. The gate was
`lingpet_ring_dash_state._player_can_block`, which reads only `player_pos` +
`player_paddle_width` at the current frame.

Mechanism: the assist already computes `frames_to_contact` for its own lookahead
(`vertical_gap / (ball_vel.y * impact_boost)`), so the contact **time** is known —
only the paddle side was left un-projected. Both halves of the prediction must use
the same horizon.

Fix (`lingpet_ring_dash_state._player_dash_projects_block`): project the paddle to
its contact-time position and re-run the span test. Remaining dash travel comes
from the shipped decel curve — `SmasherDashActiveMotionResolver.compute_total_dash_distance`
integrates a countdown to 0, so `total(timer) - total(timer - n)` = distance over
the next `n` frames — capped by `frames_to_contact` (if the ball lands first, the
dash only contributes what it covered by then) and clamped with the same
`0 .. FIELD_WIDTH - paddle_width` bounds the live dash uses. Snapshot source is a
**peek-only** registry lookup in the caller
(`lingpet_egg_runtime._resolve_player_dash_state`, key `smasher_dash_state`).

Standing rules:
- **Do not defer on "a dash is active".** A dash away from the ball, or one whose
  remaining timer cannot reach the contact X, genuinely does not block — deferring
  on those kills the assist. Gate on projected COVERAGE, not on dash activity.
- **Defer without consuming the opportunity.** A per-opportunity roll lock
  (`_rolled_this_descent`, see the Per-Frame Probability Roll Trap) must NOT be
  spent by a deferral: the dash may still whiff, and the descent should keep its
  roll. Structurally this means the gate lives in the target-build step that
  returns empty BEFORE the roll, not after it.
- **The dash-state read is a hot path.** It runs from the per-frame companion
  motion update, so use `get_cached_instance` (peek) with NO `get_instance`
  fallback (Hot-Path Lazy Init Trap), and build the snapshot dict only when
  `is_active()` is already true — otherwise every non-dash frame pays two dict
  allocations for nothing.
- **Single-source the motion curve.** Re-typing `DASH_BASE_SPEED` /
  `DASH_DECEL_FRAMES` into the projection lets the predicted travel drift from the
  real dash. Call the shipped resolver.
- Seal: `lingpet_egg_runtime_smoke._verify_ring_dash_defers_to_committed_player_dash`
  — 4 legs (control fires / committed dash defers with 3 asserts / opposite
  direction fires / short remaining timer fires). Reverse-verified by disabling the
  gate in place: exactly the 3 defer asserts go RED, the other 3 legs stay GREEN.
  The **control leg is mandatory** — without it a defer assert also passes on
  geometry that was never an emergency in the first place.
- The smoke's fake registry must expose `get_cached_instance`, or the peek-only
  consumer silently gets nothing and the seal is void-GREEN.

Sibling copies of the same static-paddle predicate, still UNFIXED (documented
candidates, same class): `lingpet_companion_defense_state._player_can_block`
(defense intercept) and `lingpet_solar_bolt_skill._player_can_block` (solar bolt
arm gate). `lingpet_companion_player_block_resolver.can_player_block` is a
different predicate (current ball X, no lookahead) used by raw body-hit and is not
part of this class.

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

**역방향(탈진 → 위치-스크립팅 패시브) 규칙 (2026-07-06, 재발 2026-07-24 WIP
파괴 후).** 포만도 탈진(satiety KO)은 별도 억제 소비처 목록(Slice3a body-hit /
방어율 / 선제타격 / 스킬 arm / 클릭 교감)으로 게이트되는데, 이 목록이
**위치-스크립팅 PASSIVE(별빛추적·링크포트)를 안 덮었다** — passive advance가
탈진 판정보다 먼저 돌며 `companion_active`(= `_state == STATE_COMPANION`)만 받아
KO(누워 자는) 중에도 순간이동/스타포인트 전달/VFX/사운드를 냈다. 표준 규칙:
- **위치-스크립팅 패시브는 탈진을 `companion_active`에 fold하라** —
  `_state == STATE_COMPANION and not is_companion_exhausted()`를 advance/update의
  is_companion 인자로 넘긴다. 패시브 모듈은 탈진을 모른 채 `_is_enabled` false로
  받아 reset이 자가치유 티어다운(별도 early-return보다 이 fold가 transient까지
  정리). 콜사이트가 여러 개면 전부(별빛추적=advance + update_starlight_tracking_
  for_starpoint_drop 2곳).
- 탈진 판정이 advance보다 아래에 있으면 **호이스트**하라(링크포트=
  `_update_companion_motion`이 ring_dash advance 아래에서 companion_exhausted를
  계산 → 위로 끌어올려 fold, 중복 선언 제거).
- 씰은 champion 리그(주니어는 D9 탈진 면제) owner로 탈진 강제(`set_satiety_for_
  tests(0)` + 텔레그래프 창 ~160프레임) 후 패시브를 구동해 억제(클레임/트리거
  없음)를 단언. 반증=fold 제거 시 탈진 중 발동 재현 RED. 씰:
  `lingpet_egg_runtime_smoke._verify_exhaustion_suppresses_starlight_tracking` +
  `_verify_exhaustion_suppresses_linkport`.

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

### Variant: dual-path DOUBLE TICK (same timer decremented by two update paths)

The inverse failure of the context-flag split: a character/skill state module
whose `update_input` (player-control path) AND `update_effects` (effects path)
BOTH call the shared `_tick_timers(delta)` runs every animation/cooldown at
double speed, because `battle_frame_flow_controller` calls
`update_player_control` (line ~63) and `update_effects` (line ~85) in the SAME
physics frame. No error, and state smokes stay GREEN because tests drive the
state object through ONE path only. Reference failure (2026-07-14): Blacksmith
Thor Shield — the nominal 0.70s deploy/retract (`ANIM_SECONDS`, original-parity
constant) actually completed in ~0.35s and the 1.0s swing in ~0.5s, so the
"timing constants match the original" audit conclusion was false at runtime.

Standing rules:
- A state module reachable from BOTH `update_player_control` and
  `update_effects` must tick its timers on exactly ONE path. Prefer the
  player-control path (`update_input`): modal pause branches that run
  `update_effects` alone then freeze the module, matching the original
  Python game's frozen main loop during modals.
- The regression smoke must reproduce the REAL integrated frame flow: one
  simulated physics frame = `update_input(delta)` + `update_effects(...)`
  back-to-back, then assert elapsed-time outcomes (e.g. ~50% open after half
  the nominal duration), not just state flags. Reference seal:
  `blacksmith_thor_shield_runtime_smoke._verify_single_tick_per_dual_path_frame`
  (reverse-verified: re-adding the effects-path tick turns it RED).
- When auditing timing parity against the Python original, verifying the
  constants is NOT enough — verify the effective per-frame advancement under
  the real dual-path frame flow.

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
## Godot TextureRect Min-Size Clamp Renders At Native Texture Size Trap (use Sprite2D for scaled/rotated shader sprites)

Incident (2026-07-12, 천사의 주사위 투척 연출 3-피스 VFX): the dice halo "arc"
layer was a `TextureRect` intended to draw a 768x768 source at ~306px, centered
on the dice, rotating with the tumble under a shared writhe-ember ADD shader. In
code the size was set correctly:

```gdscript
layer.texture = texture              # (a) default expand_mode == EXPAND_KEEP_SIZE
layer.size = Vector2.ONE * 306.0     # (b) intended 306px
layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # (c) later
layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
```

It rendered at the FULL native ~768px, sweeping a giant comet across the whole
760x750 canvas and far outside the modal panel — the single worst break in the
composition. Every state smoke was GREEN (they asserted visibility, preset swap,
rotation advance, above-bridge order — never the on-screen SIZE), and it was
caught only by live windowed pixel QA.

Mechanism: assigning `.texture` (step a) while `expand_mode` is still the default
`EXPAND_KEEP_SIZE` makes the Control's MINIMUM size become the texture size
(768). Setting `.size = 306` (step b) is then clamped UP to the 768 minimum.
Switching `expand_mode = EXPAND_IGNORE_SIZE` afterward (step c) lowers the
minimum to 0 but does NOT re-shrink the already-clamped `size`, so the rect stays
768 and `STRETCH_KEEP_ASPECT_CENTERED` fills that 768 box. The node "looks 306"
in code and is unmeasured by structural smokes.

Standing rules:
- For a centered, rotating, scaled, ShaderMaterial'd sprite, use `Sprite2D`, not
  `TextureRect`. `Sprite2D` has no layout min-size interaction: `position` = the
  center (with `centered = true`), `rotation` rotates about that center, and
  `scale = intended_px / max(texture.get_width(), texture.get_height())` gives an
  exact on-screen size. It composes cleanly with an additive-blend ShaderMaterial
  and a single pass (no `canvas.material` set/restore). Sibling z-order vs a
  `Control` bridge still works (canvas draw order is tree order via `get_index()`
  regardless of Control-vs-Node2D). When a phase scale-pop multiplies the sprite,
  multiply the BASE scale (`base_scale * pop`), never overwrite it with the pop
  factor alone.
- If a `TextureRect` is genuinely required at a size smaller than its texture,
  set `expand_mode = EXPAND_IGNORE_SIZE` BEFORE assigning `.texture`/`.size` so
  the minimum never clamps the size up. Sibling `_build_texture_layer` layers
  (mythic_reveal lightburst/smoke) share this ordering risk — audit them if their
  on-screen size ever looks wrong.
- This class is INVISIBLE to state smokes. Seal it with an on-screen-span assert
  driven from a debug status field: `dice_arc_span_px = max(tex.w, tex.h) *
  abs(sprite.scale.x)`, asserted to sit near the intended size and to EXCLUDE the
  native texture width. Prove it RED by forcing `base_scale = 1.0` (native span).
- Piecewise VFX motion functions (envelope/intensity/rotation derived from
  modal_elapsed) must be C0-continuous at phase boundaries. The same incident's
  review also found `_dice_envelope` stepping 0.66 -> 0.5206 at the
  settle->wait_confirm boundary (2.70s) — a one-frame ADD-arc dim pop because
  rotation was continuous there and did not mask it. Phase-lock the breathing
  band's sin phase to the boundary (`sin((elapsed - boundary) * w)`) so it starts
  at the exact prior value. Seal with a left/right-limit continuity assert at
  each boundary.

Seal: `angel_blessing_overlay_host_smoke.gd` dice on-screen-span leg + envelope
2.70 continuity leg (both reverse-verified RED via toggles). Live pixel QA
harness: `tools/angel_dice_overlay_capture.gd` (non-headless SubViewport, 7
phases). Run windowed: `godot --path godot -s
res://tools/angel_dice_overlay_capture.gd`.

## Godot 스모크 임의 프로퍼티 대입 조용한 레그-abort 공허 GREEN 트랩

**⚠️ 자매 함정 (2026-07-27): 스윕 하네스 자체가 거짓말한다.** 표준 러너
`run_smoke_tests.ps1`은 **첫 실패에서 throw**하므로, 더티 트리(병행 WIP 다수)에서
전체 RED 목록을 보려면 continue-on-failure 스윕을 따로 짜게 된다. 이때 PowerShell
5.1에서 `Start-Process -PassThru`로 실행하고 `-RedirectStandardOutput/Error`를 걸면
**`$p.ExitCode`가 빈 문자열로 나온다**(`WaitForExit()` 무인자 재호출로도 안 채워짐 —
실측). 빈 값은 `-ne 0` 비교에서 참이라 **1390종 전부 FAIL로 집계**됐고, 그대로
보고했으면 "내 변경이 트리를 통째로 깼다"는 정반대 결론이 나올 뻔했다.
정본은 호출 연산자 + `$LASTEXITCODE`(검증됨). 그리고 **스윕 하네스는 반드시
정답을 아는 소표본(통과 2 + 실패 2)으로 먼저 검증한 뒤** 장시간 러닝에 태워라 —
집계 결과가 "전부 통과" 또는 "전부 실패"로 나오면 대상이 아니라 하네스를 먼저 의심할 것.
판정은 3필드(`$LASTEXITCODE` / `^ERROR:`·`SCRIPT ERROR`·`Invalid call` / `: ok` 마커)를
모두 봐야 한다. 실측 정상 기준선(2026-07-27, 더티 트리): 1390종 중 PASS 1355 /
FAIL 35 — 35건은 전부 병행 WIP 트랙(character_info·localization·stage4 ponk·stage7
akamu·runtime_perk 등)이며 플라즈마/셰이더와 무관.

Incident (2026-07-18, 퍽 융합 core 슬라이스): 융합 modal 통합 스모크의
dowsing 레그와 신규 슬롯-환급 레그가 `catalog.dash_token_boost_chances =
[...]` (존재하지 않는 프로퍼티) 대입에서 `SCRIPT ERROR: Invalid assignment
of property or key ...`로 그 지점에서 **함수(레그)만 조용히 abort**됐다.
`_expect` 실패 누적식 스모크는 abort된 레그의 어서션을 하나도 실행하지
못한 채 나머지 레그만 돌고 `ok`를 출력 — 몇 세션 동안 공허 GREEN이었다.
같은 이유로 `perk_offer_owned_upgrade_priority_smoke.gd`(별도 슬라이스)도
겉보기와 다른 지점에서 죽고 있었다.

Mechanism: typed 객체(비-dynamic GDScript 인스턴스)에 대한 미선언 프로퍼티
대입·미존재 함수 호출은 런타임 SCRIPT ERROR를 내고 **현재 스택 프레임만
중단**한다. SceneTree 스모크의 `_init`이 레그를 함수 호출로 나누는 표준
구조에서는 죽은 레그가 조용히 사라지고 러너는 계속 진행한다. `quit(1)
즉시 호출=씰 공허` 트랩의 사촌이지만, 이쪽은 exit code도 stdout도 아닌
stderr에만 흔적이 남는다.

Standing rules:
- 스모크 실행 판정은 `": ok" 존재` 단독으로 하지 말 것. `SCRIPT ERROR`
  grep을 함께 걸어 "OK인데 script error 있음"을 별도 상태로 분류한다
  (이 슬라이스의 회귀 스윕/격리 게이트 러너가 쓰는
  `ok=N script_err=M` 2필드 형식이 표준).
- 스모크 픽스처에서 카탈로그/상태 객체의 튜닝 프로퍼티를 끌 때는 대입
  전에 그 프로퍼티가 실제 선언돼 있는지 확인한다(`var` 선언 grep). 존재
  하지 않으면 그 대입 줄 자체가 레그를 통째로 삼킨다.
- 새 레그를 추가했는데 기대한 실패가 안 나오면, 반증 토글 전에 먼저
  풀 출력에서 해당 레그 이름이 backtrace에 있는지(=abort 여부) 본다.

Incident 확장 (2026-07-19, 콜드부트 CB4b v3): 판정을 `ok` + `SCRIPT
ERROR` 2필드로만 하면 **엔진 ERROR 클래스를 놓친다**. 콜드부트 스모크가
SceneTree `_init()` 안에서 `root.add_child()` 직후 노드를 사용했는데,
`_init` 시점엔 방금 붙인 노드도 `is_inside_tree()==false`라
`get_viewport_rect()` 계열이 `ERROR: Condition "!is_inside_tree()"`를
6회 뿜었다. 직접 실행은 exit 0 + ok + SCRIPT ERROR 0이어서 3개 리뷰
라운드를 통과했지만, 표준 러너 `godot/tools/run_smoke_tests.ps1`의
serious-error 게이트는 exit 0이어도 이를 실패로 승격한다(코덱스가 잡음).

Standing rules(확장):
- 스모크 판정의 정석은 **표준 러너 관통**이다(`run_smoke_tests.ps1
  -Tests @(...)`) — ok 마커+exit code+SCRIPT ERROR+엔진 `ERROR:` 라인
  +옵트인 leak 게이트를 한 번에 건다. 수동 grep 판정을 쓸 땐 최소
  `ok / SCRIPT ERROR / ^ERROR` 3필드.
- SceneTree 스모크의 `_init()`은 `call_deferred("_run")`만 수행하고
  실검증은 트리 진입 후 `_run()`에서 시작한다(캡처 하니스와 동일 패턴).

Incident 확장 (2026-07-22, dalji result 스모크 attack 교체): `_expect`가
실패 시 `push_error + quit(1)`를 부르는 조기-종료식 스모크도 공허 GREEN을
낸다 — SceneTree의 `quit()`는 요청일 뿐 현재 프레임 실행을 멈추지 않으므로
나머지 코드가 끝까지 달려 마지막의 **무조건 `print(ok)` + `quit(0)`가
종료코드를 덮어쓴다**. 실패 레그 10개가 stderr에 ERROR로 찍히는데 stdout엔
ok, exit는 0이었다(표준 러너의 `^ERROR` 승격만이 방어선). Standing rule:
`quit(1)`식 `_expect`를 쓰는 스모크는 `_failed` 플래그를 함께 세우고 최종
ok 출력을 `if _failed: quit(1); return`으로 게이트한다. 수정 시 반증검증
(기대값 토글 → exit 1 + ok 미출력 확인) 필수. 참조 수정:
`stage1_dalji_result_sprite_smoke.gd` (커밋 cbd3c47f8).
  `_init`에서 `root.add_child` 직후 노드의 viewport/tree 의존 경로를
  호출하면 위 엔진 ERROR가 조용히 쌓인다.

Seal: 회귀 스윕 러너의 `OK_WITH_SCRIPT_ERROR` 분류가 이 클래스를 잡는다.
융합 modal/integration 스모크는 문제 대입 제거 후 전 레그 실주행 GREEN.

## Godot 퍽 표시 Projection-분기 후처리 탈락 트랩 (라이브=항상 projection)

Incident (2026-07-21): 대쉬토큰 퍽이 링코어와 달리 슬롯 셀을 차지하지
않고 Lv 배지만 오른다는 유저 리포트. 원인은
`character_info_overlay_perk_presenter.build_acquired_perks`의 이중 빌드
경로 — 스냅샷에 융합 display projection이 실려 오면 projection 분기로
조기 반환하는데, **라이브 스냅샷은 보유 퍽이 1개라도 있으면 항상
projection이 비어있지 않다**(`perk_fusion_display_projection.build`가
융합 여부와 무관하게 모든 보유 퍽을 엔트리화). 그래서 TAB 그리드와
전투 "현재 퍽" 상태 패널의 실전 경로는 100% projection 분기인데, 그
분기가 일반(레벨 dict) 분기의 후처리를 잃은 채 퍽당 1엔트리만
append했다. 같은 자리에서 두 건이 동시 발견됨:

1. **슬롯 비용 확장 탈락** — `_slot_cost`/`_is_slot_cell` N셀 확장/배지
   억제/`_slot_free_cell` 마킹이 없어 대쉬토큰 Lv.N이 배지 셀 1개로
   붕괴(그리드 셀 수 ≠ 슬롯 카운터; 카운터 `get_perk_slot_status`는
   정확했고 표시만 어긋남).
2. **런타임 상태 라인 탈락** — `_apply_runtime_status_lines`(천사의
   주사위 라이브 상태 라인) 미호출. 이 계약의 씰
   `angel_blessing_status_tooltip_smoke`는 CI/pre-push 미등재라
   **조용히 RED로 잔존**했다(랜딩 커밋 7f4e52262 시점엔 인라인 처리라
   GREEN → projection 분기 추출 커밋에서 탈락 → 아무도 모름).

표준 규칙:

- 퍽 표시 경로(일반 분기)에 후처리를 추가/수정하면 **projection 분기
  (`build_acquired_perks_from_projection`)에도 같은 후처리를 공용 헬퍼
  관통으로 반영**해야 한다. 라이브는 항상 projection 분기라, 일반
  분기 전용 개선은 스모크에서만 보이고 실전에서 죽는다. 슬롯 셀
  확장의 공용 헬퍼는 `append_presented_perk_with_slot_cells`(두 분기
  모두 이 헬퍼를 지나는 것이 계약 — prewarm 스모크 소스씰이 봉인).
- 퍽 표시 스모크 픽스처는 `snapshot={}`/null 만으로는 실경로를 봉인하지
  못한다. **실 `runtime_perk_state.get_snapshot()` 레그 + "projection
  엔트리가 비어있지 않다" fail-closed 가드**를 함께 넣어라(스냅샷
  형태가 바뀌어 projection이 빠지면 레그가 공허해지는 것을 차단).
  참조 씰: `perk_overlay_dash_token_slot_cells_smoke`
  `_run_projection_snapshot_legs`(presenter 4 + overlay fold 2 assert,
  반증검증 6-assert RED 실증).
- 씰 신설은 CI(`godot-ci.yml`)/pre-push(`run_pre_push_checks.ps1`)
  락스텝 등재까지가 한 단위 — 미등재 씰은 후속 리팩토링 때 조용히
  RED로 남는다(angel 사례).
- 장착 해금퍽 숨김 lookup 미관통도 같은 클래스의 **확정 회귀**였다
  (projection 상시라 "잠재"란 없다 — 그 분기에서 빠진 후처리는 전부
  실전 버그다). 수정: lookup을 projection 분기 전에 생성해 빌더까지
  관통, 씰=prewarm 스모크 실 스냅샷 양방향(장착→숨김/빈 목록→표시).

## Godot 반쪽-랜딩 슬라이스 트랩 (표시가 없는 브리지를 근거로 댄다)

Incident (2026-07-27): TAB "무공" 패널 헤더가 `슬롯 6/6`인데 셀은 **8개**.
원인은 링코어 티어 셀. 링코어는 슬롯 **비소모**가 랜딩 계약인데
(`RuntimePerkCatalog.is_slot_consuming_perk`가 `is_lingpet_ring_core_upgrade`
+ `LINGPET_GATED_CHOICE_IDS`로 **두 번** 면제, `count_owned_slot_perks`는
`runtime_skill_levels`만 훑는데 티어는 `LingpetAffinityState._run_ring_core_tier`
에 살아 **구조적으로 보이지도 않음**), 표시 쪽만
`_build_ring_core_display_entries`가 티어당 셀 1개를 예산 목록에 append하고
있었다. 셀에 `_slot_free_cell`이 없어 `build_slot_grid_entries`의 예산 배열로
들어갔고, 이 헬퍼는 **패딩만 하고 절단은 안 한다** → 6퍽+티어2 = 8셀. 한도
미달일 땐 같은 셀이 빈 슬롯 패딩을 **잡아먹어** "4/6인데 빈칸 0"이 됐다.

핵심은 코드 주석이 **거짓 근거**를 댔다는 것이다: `(Slice B slot bridge)` —
그 브리지는 어떤 커밋에도 존재한 적이 없다(`git log -S` 전 ref 확인). 설계는
`docs/dash_token_ringcore_slot_redesign_plan.md` §2.B에 LOCKED로 있었지만
**배선 대기** 상태였고, 표시 절반만 복원 커밋 `0848d4480`으로 들어왔다.

표준 규칙:

- **"설계 LOCKED / 배선 대기" 슬라이스의 표시 절반만 랜딩하지 마라.** 계산
  절반이 없으면 UI가 존재하지 않는 계약을 주장한다. 반쪽만 넣어야 한다면
  계산 쪽이 먼저다(표시는 없어도 거짓말을 안 한다).
- **코드 주석/툴팁의 "이 값은 X를 소비한다" 주장은 근거가 아니다.** 소비
  주장을 보면 반드시 카운터 실경로(`count_owned_slot_perks` 류)와 그 계약
  씰(`perk_slot_limit_smoke`)을 대조하라. 이 사례에선 툴팁 문구
  "무공 슬롯 1칸을 사용합니다"까지 플레이어에게 거짓을 말하고 있었다.
- **비소모 엔트리는 예산 배열이 아니라 free 레인으로 보내라.** 규범 패턴은
  `append_presented_perk_with_slot_cells`(cost<=0 → `_slot_free_cell` → 패딩
  **뒤** append). 이 헬퍼를 우회해 직접 append하면 자동으로 예산 셀이 된다.
- **반쪽 랜딩은 죽은 파편을 남긴다 — 같이 훑어라.** 이 슬라이스는
  `plaza_transaction_message_formatter`의 `perk_slots_full`
  ("무공 슬롯이 가득 차 링코어를 강화할 수 없습니다") 문구를 **생산자 0**인
  채로 남겼고, 그 문구를 검사하는 스모크는 공허 GREEN이다.
- **표시-수량 씰의 픽스처는 예산을 가득 채워라.** 기존 씰은 1퍽 픽스처로
  `size()==6`만 봐서 패딩 잠식만 관찰했고, 6/6 오버플로로는 **절대 실패할 수
  없었다**. 씰=`character_info_passive_ui_retire_smoke` 링코어 셀 금지 레그
  (6퍽 예산 → 정확히 6셀 + `_ring_core_cell` 0 + 재도입 트립와이어 4종:
  빌더 arity 2 / `_get_run_ring_core_tier_for_grid` 부재 / core·support
  소스락). 반증검증=티어2 강제 주입 시 7 assert RED("got 8" 실증).

## Godot 전역 물리 보간 오버레이 스폰-글라이드 트랩 (spawn-frame reposition glide)

`project.godot`가 `physics/common/physics_interpolation=true`를 켜 두었기
때문에, 노드를 (0,0)에 생성하고 **같은 프레임에** 최종 위치(예: 화면
우하단)로 이동시키면 물리 틱이 따라잡을 때까지 그 이동 경로의 중간
지점(화면 중앙 부근)에 렌더된다. 정지형 오버레이(로딩 카메오, 모달
장식, HUD 호스트)처럼 "이산 시점에만 재배치되는" 노드가 이 아티팩트에
특히 취약하다 — 로딩 화면처럼 워밍업으로 첫 프레임들이 정체되는 구간
에서는 그 중간-경로 유령이 ~0.5초씩 화면에 남는다.

발견 경위 (2026-07-21, 미니멀 로딩 카메오): 전투 진입 첫 로딩에서 달지
굴렁쇠 실루엣이 화면 중앙 부근에 잠깐 떠 있다가 우하단으로 "미끄러져"
들어가는 증상. 원인은 좌표 계산이 아니라 전역 물리 보간이 스폰 프레임의
(0,0)→우하단 재배치를 보간한 것.

표준 규칙:

- 이산 시점에만 재배치되는 정지형 오버레이 노드(로딩/모달/HUD 호스트와
  그 자식 스프라이트)는 생성 시
  `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF`
  를 명시적으로 설정한다 (자식은 INHERIT로 함께 꺼진다).
- 대안(텔레포트 노드에 `reset_physics_interpolation()` 호출)도 있지만,
  매 재배치 지점마다 호출해야 하므로 정지형 오버레이는 모드 OFF가
  누락에 강하다.
- 증상 시그니처: "생성 직후 UI 요소가 화면 중앙에서 목표 위치로
  미끄러진다 / 첫 프레임에 엉뚱한 곳에 보인다". 좌표 수식을 의심하기
  전에 전역 물리 보간부터 확인할 것.
- 씰: `battle_loading_screen_renderer_smoke.gd`
  `_verify_cameo_host_disables_physics_interpolation`.

## Godot HUD 상시-가시성 승격 × 프리미엄 절차 드로우 트랩 (봉인 예산 락스텝)

**사건 (2026-07-23).** "복구작업+리브랜딩 후 프레임드랍 재발" 신고의 라이브
triage에서 스테이지2 인배틀 74창 중 41창이 60fps 미만, 공용 필러 HUD 체인
(`stage1.pillar.ui_total`)이 6월 캐싱 완료 기준 0.78ms → 1.54ms로 2배 회귀.
상위 성장분의 두 축이 이 트랩 클래스였다:

- `stage1.pillar_ui.sensor` ~0.26ms/frame: 위험감지센서 오브 "프리미엄
  리드로우"(7e866bac0)가 베젤/림/리벳/웰 ~15드로 사이트의 절차 드로우를
  추가했고, 별도 커밋(e43fe13cf)이 가시성 게이트를 "장착 시"에서 "퍽
  보유 시"로 넓혔다. 패시브→퍽 대개편 이후 퍽은 사실상 상시 보유이므로,
  "가끔 그리던 장식"이 **상시 per-frame 비용으로 조용히 승격**됐다.
- `stage1.pillar.top_mini_scoreboard` ~0.37ms/frame: 정상 상태에서 픽셀
  불변인 미니 스코어보드(크롬 + 7세그 숫자 + 콜론, ~50 프리미티브)를 매
  프레임 즉시 드로우로 재발행 + 프레임마다 digit-height while 루프.

**메커니즘.** 두 커밋이 각각은 무해해 보인다: 프리미엄 리드로우는 "그리던
것을 예쁘게", 게이트 확장은 "사라진 오브 복원"(정당한 버그픽스). 그러나
비용 = 단가 × 유병률이라 두 커밋의 곱이 상시 회귀를 만든다. 유병률을 바꾸는
커밋(가시성 게이트 확장, 장착→보유 승격, 이벤트→상시 전환)은 draw 코드를
한 줄도 안 바꾸므로 perf 리뷰 대상으로 인식되지 않는 게 함정의 본체다.

**표준 규칙.**

1. HUD 요소의 **가시성 게이트를 넓히는 수정**(장착→퍽 보유, 조건부→상시,
   스테이지 한정→전 스테이지)은 그 요소의 per-frame 드로우 비용을 상시
   비용으로 재평가하고, 절차 드로우가 ~10드로 사이트를 넘으면 정적 스택
   bake-once(`pillar_orb_static_layer_cache` 계열)를 같은 슬라이스에서
   검토한다.
2. **프리미엄 절차 리드로우**는 프레임 불변 레이어(베젤/림/리벳/크롬)와
   동적 레이어(펄스/진행 아크/젬)를 처음부터 분리 설계한다. 정적 스택은
   베이크(해석적 원호 = 세그먼트 무관 풀화질), 동적만 즉시 드로우.
3. **봉인 예산 락스텝**: 시각 리스타일이 대상 렌더러의 세그먼트/레이어
   상수를 올릴 때, 그 상수를 봉인한 budget smoke를 반드시 같이 돌리고
   함께 갱신한다. 실사건: 프리미엄 리드로우가
   `stage1_dalji_commando_hud_layout_smoke`의 센서 아크 예산(<=16/<=12)을
   24/16으로 깨뜨린 채 커밋돼 그 씰이 HEAD에서 계속 RED였다(perf
   슬라이스에서 발견·해소 — 화질은 베이크가 담당, 폴백은 예산 복귀).
4. 정상 상태 픽셀 불변인 HUD 박스(미니 스코어보드류)는 **리테인드 자식
   CanvasItem 호스트 + 상태 키 게이팅**이 최저비용 수단이다: 드로우를 기존
   렌더러에 위임(픽셀 동일)하고 키 변화/애니메이션 창에만 queue_redraw.
   키는 렌더 출력에 영향을 주는 전 입력을 커버(Lazy Applied-Key Re-Apply
   Trap 동족), 애니 창 종료 시 정착 redraw 1회, 호스트는
   `physics_interpolation_mode = OFF`(스폰-글라이드 트랩), 비-노드 캔버스
   (스모크)와 부착 전 프레임은 즉시 경로 폴백. **pending 강참조는 씬
   teardown 뒤 freed 인스턴스로 남을 수 있다**(호스트가 그 씬의 마지막
   HUD 프레임에 만들어진 경우) — freed 참조는 `is` 타입 검사조차
   "previously freed instance" 에러를 내므로 `is_instance_valid`를 반드시
   타입/메서드 검사보다 먼저 태우고 스테일 참조는 그 자리에서 null 청소
   한다(라이브 재발 사례 → 씰 레그
   `_verify_stale_freed_pending_host_recovers`, 버그 순서 토글로 RED 반증).

**씰.** `scoreboard_top_mini_retained_host_smoke.gd`(redraw 게이트/키
커버리지/애니 창/폴백/위임 — 게이트 무력화 토글로 RED 반증 확인),
`stage1_pillar_sensor_orb_bezel_bake_smoke.gd`(핫패스 소스-프리미티브 예산
draw_arc 5/draw_circle 7 + 베이크 ops 지오메트리 21op 계약 + 베이크 수렴 —
핫패스 프리미티브 추가 토글로 RED 반증 확인). 폴백이 correctness-identical
이라 픽셀 패리티 씰은 봉인력이 없으므로(플레이북 규율), 라이브 재측정의
라벨 us/prims가 런타임 직교 카운터다. 커밋 817b76b24.

## Godot 스크린-공간 FX 호스트 플레이필드 클립 트랩 (구조 GREEN ≠ 픽셀 클립)

**사건 (2026-07-23).** 스매셔 플라즈마 FX 호스트(`smasher_plasma_fx_host.gd`,
Node2D)를 배틀 캔버스에 직접 `add_child`로 붙였다. 드로어가 오브를 스크린
좌표(`game_offset + playfield_pos*render_scale`)로 배치하는데, 호스트는 캔버스의
노드 자식이라 플레이필드 패스의 `draw_set_transform`을 물려받지 않고 화면 전체에
그린다 — 오브 배경판 반경(radius×2.8)이 `game_offset` 밖 좌/우 레터박스 필러까지
새어나갔다(x=0, offset=190, scale=1.18 실렌더에서 시안 10,882px). 상태 스모크는
좌표(host.position)만 검사해 이 침범을 놓쳤다(픽셀 QA 필요).

**메커니즘 / 함정 3겹.**
1. **`Control.clip_contents=true`의 구조 상태만으로 Node2D/Sprite2D 픽셀 클립을
   보장하지 마라.** 초기 플라즈마 호스트에서는 픽셀 씰이 통과했지만, 한령탄의
   MIX 실체 + ADD 광원 + GPUParticles2D 6-layer 구성으로 교체한 뒤 Godot 4.6.2의
   OpenGL/Vulkan 양쪽에서 `clip_contents==true`, 부모 관계, 월드 rect가 모두
   정상인데도 각 Sprite2D가 레터박스에 그대로 그려졌다. 같은 API가 다른 호스트
   구성에서 먹는다는 선례를 이 호스트의 픽셀 증거로 대신할 수 없다.
2. **`clip_children=CLIP_CHILDREN_ONLY` 마스크 방식은 ADD 블렌드 Sprite2D를
   완전히 못 잡는다.** 마스크 rect를 draw해도 레터박스에 픽셀이 남았다(5716
   잔류). 반드시 `clip_contents`를 써라.
3. **구조 씰만으론 공허-GREEN.** `clip_contents==true` + 레이어 부모 검사 +
   클립 월드 rect 검사가 전부 GREEN인데 실제 픽셀은 안 잘리는 케이스를 겪었다
   (마스크 방식). 클립 효능은 **비헤드리스 픽셀 씰**로만 증명된다.
4. **안전 폴백은 화면 좌표 fragment clip이다.** `screen_clip_canvas_material.gd`는
   MIX/ADD 실체·파티클용 재질을 제공하고, `writhe_ember_material.gd`는 동일한
   opt-in screen-clip uniforms를 가진다. `SCREEN_UV / SCREEN_PIXEL_SIZE`로 viewport
   pixel을 복원해 `game_offset .. game_offset + GAME_SIZE*render_scale` 밖 fragment를
   버린다. 기본값은 비활성이므로 다른 WritheEmber 소비자는 변하지 않는다.

**호스트가 오브 위치일 때의 클립 배치.** 좌표 계약(host.position = 오브 스크린
좌표)을 보존하려면 클립을 host-local `clip_local_origin = (clip_position_screen -
host.position) / render_scale`에 놓고 size=GAME_SIZE(760x750, render_scale 무관
상수), 자식 레이어는 전부 `.position = wobble - clip_local_origin`으로 보정한다.
그러면 자식 월드 = host.position + scale*wobble(오브 위치 불변), 클립 월드 rect =
game_offset .. game_offset + 760x750*scale(정확한 플레이필드). 드로어는
`fx_state["clip_position"] = game_offset`만 실어 보낸다. clip_position이 없으면
(스모크/폴백) 클립을 끄고(clip_contents=false) 오브를 host 원점 기준 그대로 그린다
— 호스트가 오브 위치인데 클립을 host-local ZERO에 두면 오브 좌/상단 절반이 잘린다.

**표준 규칙.**
- 스크린-공간 FX 호스트(스타포인트/주사위/플라즈마류)가 오브/파티클을 그리면
  플레이필드 클립을 반드시 확인하라 — 노드 자식은 draw_set_transform을 안
  물려받아 레터박스로 샌다. 내부 Control(clip_contents=true)을 구조 경계로
  유지하되, 해당 실제 레이어 조합의 픽셀 씰이 실패하면 화면 좌표 fragment clip을
  모든 MIX/ADD/particle 재질에 함께 적용한다.
- **클립은 구조 씰 + 비헤드리스 픽셀 씰 2단으로 봉인.** 구조 씰(clip_contents/
  부모/월드rect)은 헤드리스 CI용, 픽셀 씰은 오브를 왼쪽 가장자리에 두고 렌더해
  레터박스 lit 픽셀이 clip_ON=0 / OFF>0인지 실측(디스플레이 있을 때만; 헤드리스
  스킵+ok 마커). 씰: `smasher_plasma_playfield_clip_smoke`(구조) +
  `smasher_plasma_clip_letterbox_pixel_smoke`(비헤드리스 실픽셀).
- **픽셀 프로브 오염 주의.** ①배경 회색이면 배경 픽셀이 카운트를 압도 →
  `RenderingServer.set_default_clear_color(검정)` + 밝은(플라즈마) 픽셀만 카운트.
  ②다른 활성 호스트가 트리에 남아 bleed → 격리 측정 전 free/set_active(false).
  ③단일 호스트로 OFF→ON 순차 측정이 매번 free/생성 반복보다 안정.

커밋 90ec14c06. 초기 씰 반증: clip_contents=false 토글 시 레터박스 9794px RED.
한령탄 교체 후 재반증(2026-07-26): 구조 clip ON인데도 OpenGL 4,420px / Vulkan
4,118px RED, 화면 좌표 재질 clip 적용 후 양 렌더러 모두 0px GREEN.

### ⚠️ 결정적 후속 함정 (2026-07-27): fragment clip의 단위 공간

`SCREEN_UV / SCREEN_PIXEL_SIZE`는 **프레임버퍼(실제 렌더타깃) 픽셀**을 준다.
반면 업로드하는 rect(`game_offset`, `GAME_SIZE * render_scale`)는
`battle_view_layout`이 `get_viewport_rect().size`에서 뽑은 **캔버스(2D 논리)
단위**다. `project.godot`가 `window/stretch/mode="canvas_items"` +
`aspect="expand"`라 창 크기가 기준 해상도(2020x1246)와 다른 순간 두 공간은
스트레치 배율만큼 어긋난다 — 실측: 창 2560x1440 → 뷰포트 rect 2215x1246, 배율
1.1557 / 창 1280x800 → rect 2020x1262, 배율 0.6337. **창이 기준 해상도와 정확히
같을 때만 우연히 일치**한다.

변환 없이 올리면 `clip_max`가 배율만큼 작아져 **플레이필드 하단/우측 밴드가
통째로 discard**된다. 한령탄 리브랜드에서 이 한 줄이 사용자 증상 2개를 동시에
만들었다: 차징 오브는 패들 바로 위(게임 y≈680) = 잘리는 밴드 한복판이라
**"차징(W 홀드) 이펙트가 안 보임"**, 투사체는 밴드를 벗어나는 높이에서 갑자기
나타나 **"발사 투사체가 잘려보임"**. 실측: 배율 1.1558에서 차징 오브 가시 면적이
정상 대비 **22%**(13,976 / 기대 63,026 px).

**표준 규칙: 캔버스→프레임버퍼 변환 후 업로드하라.**
`get_viewport().get_final_transform() * get_canvas_transform()`을 rect 양 끝점과
feather 폭에 적용한다(`smasher_plasma_fx_host._canvas_to_framebuffer_transform()`).
`get_canvas_transform()`이 CanvasLayer/카메라 변환을, 뷰포트 final transform이
스트레치 배율을 담는다. 트리 밖이면 항등으로 폴백.

**⚠️ 같이 나온 함정: canvas_item fragment의 `COLOR`는 이미 텍스처가 곱해져 있다.**
클립 재질이 `vec4 source = texture(TEXTURE, UV); COLOR = source * COLOR;`로 써 있었는데,
Godot canvas_item `fragment()` 진입 시점의 `COLOR`는 이미
`texture(TEXTURE, UV) * modulate`다 — 그래서 저 한 줄이 **texture²**을 만든다.
픽셀 실측(텍스처 RGBA(.5,.5,.5,.5), modulate 1.0, 검정 배경 blend_mix):
무개입 셰이더 **0.247** / 재샘플 셰이더 **0.063**(= 0.247²). 알파가 제곱되니
먹선·반투명 꼬리·소프트 헤일로가 의도보다 어둡고 얇아진다. 클립처럼 **색을 바꿀
의도가 없는 재질은 절대 재샘플링하지 말고** 필요한 항(`COLOR.a *= clip_fade`)만
건드려라. UV를 왜곡해 다시 샘플하는 셰이더(writhe-ember)는 재샘플이 목적이라
해당 없음 — 다만 그런 셰이더도 `COLOR.rgb`를 다시 곱하면 같은 이중 곱이 되므로
의도인지 확인할 것.
⚠️ 이 버그를 고치면 **모든 레이어가 밝아지므로 알파 튜닝과 픽셀 씰 판별대를 함께
재보정**해야 한다(실측: 최소 차징 lit 판별대가 325↔739 → 484↔1003으로 이동).

**클립 씰은 반드시 양방향이어야 한다 — 단방향 씰은 증상을 PASS 조건으로
인코딩한다.** 기존 레터박스 픽셀 씰은 "밖에 0px"만 봤는데, 과잉 클립(오브가 통째로
사라짐)은 그 조건을 **더 잘** 만족한다. 그래서 이 회귀가 씰을 GREEN으로 통과했다.
같은 렌더에서 ①의도한 rect **안쪽**에 lit 픽셀이 있다(과잉 클립 검출) ②밖에는
0px(누출 검출)를 함께 단언하고, ③**스트레치 배율 != 1**에서 돌려라.
임계 매직넘버 대신 **스트레치 불변 비율**을 쓰면 튜닝에 안 깨진다: 기준(배율 1.0)과
확대(배율 s)에서 같은 오브를 그려 `lit_s ≈ lit_1 * s²`인지 본다
(정상 62,956 vs 기대 62,989 GREEN / 버그 13,976 vs 63,026 RED).

**⚠️ 스모크 `_init()`의 `get_root().size = ...`는 조용히 무시된다.** 창 오버라이드가
나중에 덮어써서, VIEW=(960,900)을 넣어도 런타임은 (2020,1246) 스트레치 1.0으로
돈다(실측). 캔버스 단위로 적은 프로브 좌표가 그 덕에 "우연히" 맞아 씰이 GREEN처럼
보인다 — 즉 이 픽셀 씰들은 **스트레치 != 1을 한 번도 안 태웠다**. 리사이즈는 프레임
진행 뒤에 하고 `get_final_transform()`으로 실제 배율을 읽어 단언하라(헤드리스는
64x64 더미 창이라 배율 단언에서 제외).

**하드 discard는 하드-에지 아트를 면도날로 자른다.** 경계 밖은 discard를 유지하되
안쪽 feather 밴드(현 34 playfield px)에서 알파를 smoothstep으로 0까지 램프하면
레터박스 무누출 씰은 그대로 두고 절단만 페이드로 바뀐다. 판별식 = 경계 직전 4행
평균 휘도 / 안쪽(feather 밖) 4행 평균: 하드컷이면 **경계 쪽이 더 밝다**(실측 2.63),
feather면 0.05 수준. 소프트 폴오프 아트(구 플라즈마 라디얼 글로우)는 경계에서 이미
0에 가까워 절단이 안 보였고, 캔버스 끝까지 밀도가 있는 먹선 아트로 바뀌자 같은
클립이 갑자기 눈에 띄었다 — **클립 규칙을 안 건드려도 아트 교체만으로 발현한다.**

씰: `smasher_hanryeongtan_charge_visibility_pixel_smoke`(레그 D = 스트레치
불변 비율 + 밖 0px, 레그 C = feather 판별식, 레그 A-2 = feather 유니폼이 전
레이어에 실렸는지). 반증검증: 변환 제거 / `CLIP_FEATHER_PX=0` 각각 RED 확인.


## Godot Duck-Typed `has_method`-Gated Dynamic-Call Arity Trap (caller-path seal, not direct-runtime seal)

**증상.** 런타임 크래시 `Invalid call to function 'X' in base 'RefCounted
(Y.gd)'. Expected N argument(s).` — 특정 이벤트 분기(예: 역경의갑주 배리어
바닥 인터셉트)가 실제로 발동하는 프레임에만 터진다.

**메커니즘.** `deps.get("mythic_item_runtime", null)` 처럼 `Object` 타입으로
보관된 덕타이핑 런타임을 `if rt != null and rt.has_method("X"):` 로 게이트해
`rt.X(...)` 를 호출하면, 대상이 정적 타입(named class)이 아니라 `Object` 이므로
**GDScript 파서는 인자수를 검증하지 못한다**. 인자를 몇 개 넘기든 파스는
통과하고, 그 분기가 런타임에 실제로 실행될 때 비로소 "Expected N argument(s)"
로 크래시한다. `_draw_skill_icon_mini` elif-chain 트랩의 "미존재 분기=파스 통과,
런타임에만 드러남" 구조와 동형이지만, 여기서는 skill_id 레벨이 아니라 **동적
호출 인자수 레벨**이다.

**실사례(2026-07).** `ball_motion_event_processor._process_adversity_armor` 가
`notify_adversity_armor_barrier_hit(impact_pos, ball_vel, deps, built)` 로 **4번째
`built` 인자**를 넘겼는데, 대상 함수(`mythic_item_runtime.gd`) 계약은 3인자
(`impact_pos, ball_vel, deps=…`). `built` 은 형제 배리어 처리기
(`_process_horn_strawberry_field`·`_process_lingpet_bone_barrier` — 이들의 대상은
실제로 `built` 을 받는다)에서 **복붙된 잔재**였다. 과거 HEAD 파스 손상 복구
(커밋 cb25f9432 "built 미선언 복구")가 `var built := …` **선언만 추가해 파스
에러를 없앤 탓에** 근본 결함(잉여 4번째 인자)이 가려진 채로 릴리스됐다 — 선언은
파스를 통과시키지만 크래시는 그대로 남는다.

**표준 규칙.**
- **덕타이핑 `has_method` 게이트 호출을 추가/수정하면, 대상 함수의 실제 시그니처
  인자수를 눈으로 대조하라.** 파서가 안 잡아준다. 특히 형제 처리기에서 호출문을
  복붙할 때 대상 함수마다 `built`/`registry`/`deps` 유무가 갈릴 수 있으니
  인자 목록을 그대로 옮기지 말 것.
- **봉인은 "런타임 함수를 직접 3인자로 부르는" 레그로는 부족하다.** 그건 계약
  준수만 증명하고 **caller-side 인자수 회귀는 놓친다**(이 결함이 새어나간 이유).
  실제 caller 경로(`_process_adversity_armor` 등)를 관통하는 레그를 추가하고,
  가능하면 게이트 안쪽까지 도달했음(예: 배리어 파티클 spawn, 반사 방향 y<0)을
  어서션으로 확인해 no-op/조기 return 이 아님을 증명하라.
- **판정은 표준 러너 `run_smoke_tests.ps1` 관통.** SCRIPT ERROR("Invalid call")는
  그 레그만 abort시키고 러너는 계속 돌아 `ok` 를 찍는 공허-GREEN이 되지만, 표준
  러너는 엔진 `Invalid call`/`SCRIPT ERROR` 를 실패로 승격(exit 1)한다. 수동
  grep 판정은 이 크래시를 놓칠 수 있다.
- **반증 정석.** 잉여 인자를 in-place로 재주입 → 표준 러너 RED("Expected N
  argument(s)" + caller 파일/라인 backtrace) 확인 → 되돌려 GREEN. `git
  reset`/`stash` 금지.

**씰.** `adversity_armor_port_smoke.gd`
`_verify_event_processor_barrier_hit_caller_path` — `BallMotionEventProcessor.
new()._process_adversity_armor()` 를 실제 caller 경로로 구동하고 배리어 파티클
spawn + 상향 반사(y<0)까지 확인. 기존 `_verify_runtime_flow` 레그는 런타임
함수를 직접 3인자로 불러 이 caller-side 회귀를 못 잡았다.

## Godot Fullscreen Screen-Read Overlay Context-Fallback Sizing Trap

**사건 (2026-07-05, 재발 2026-07-24 WIP 파괴 후).** 풀스크린 스크린-리드
오버레이(BackBufferCopy `COPY_MODE_VIEWPORT` + `hint_screen_texture` SCREEN_UV,
예: 스테이지4 퐁크 몽환포영 물결·`defeat_continue_color_restore_fx_host`)의 rect
크기를 draw 컨텍스트에서 뽑을 때, **라이브 플레이필드 컨텍스트는 view_size를 안
싣는다** — `battle_playfield_effects_drawer`는 game_offset/game_size/render_scale
만 주입한다. 그래서 `context.get("view_size", ...)` 폴백이 game_size(스케일된
플레이필드, 윈도우보다 작음)로 저하되고, ColorRect가 position ZERO(윈도우 0,0)
+ size=game_size로 그려져 **화면 좌측/부분만 덮는다**("반쪽 화면"). 상태 스모크는
view_size_px를 수동 주입해 이 저하를 가려 GREEN을 유지한다.

**메커니즘.** 크기의 정본은 draw 컨텍스트 dict가 아니라 **엔진 뷰포트**다. 노드가
윈도우 전체를 덮어야 하는 스크린-리드 오버레이는 `canvas.get_viewport_rect().size`
를 **PRIMARY** 소스로 써야 한다(context view_size/game_size/width는 폴백만).

**표준 규칙.**
- 풀스크린 스크린-리드 오버레이의 rect 크기는 `canvas.get_viewport_rect().size`
  를 정본으로 — context 크기 키는 폴백. `defeat_continue_color_restore_fx_host`
  가 형제 클래스(같은 반쪽 위험).
- ⚠️`get_viewport_rect()`는 트리 밖에서 `Condition "!is_inside_tree()" is true`
  ERROR를 뱉는다(표준 러너가 실패로 승격) — 반드시
  `if canvas != null and canvas.is_inside_tree():` 가드. 컨텍스트 빌더로 canvas를
  스레딩할 땐 트레일링 `canvas: CanvasItem = null` 기본값으로 기존 콜러/테스트
  호환.
- **씰은 반쪽을 가리지 않는 레그로.** view_size를 뺀 라이브-형태 컨텍스트 + 작은
  game_size(760x750)로 build하고 결과 view_size_px == `canvas.get_viewport_rect().
  size` AND != game_size를 단언. 트리가 필요하므로 async 스모크(_run + await
  process_frame)에서, canvas를 `get_root().add_child` 후 프레임 대기. 반증=canvas
  PRIMARY 분기 토글 시 game_size로 저하 → RED. 씰:
  `stage4_ponk_illusion_ripple_smoke._test_illusion_full_viewport_without_view_size_context`.

## Godot 프리웜 경량-값-위해 무거운-모듈 콜드생성 트랩 (전환 프레임 1초+ 스톨)

**사건 (2026-07-24).** 프레임드랍 재발 조사의 로딩/전환 히치 추적에서
`stage_runtime_prewarm.step.12.stage1_pillar_scene`가 **단일 프레임
1237ms**(fps=2)로 확인. `_get_module` 콜드 fetch에 임계(>=60ms) 경고 계측을
심고 라이브 1판(전환 포함)으로 정체를 특정: `[PrewarmColdInstantiate] module
'stage_clear_result_screen' first-fetch 1237.2ms`. 원인 = 필러 HUD 프리웜이
**광장 골드 숫자 하나를 데우려고 stage_clear_result_screen 모듈을 통째로 첫
인스턴스화**했고, 그 결과화면의 스크립트 트리(플라자 씬/가챠/결과 렌더 등
대형 preload 다수) 콜드 로드+컴파일이 1.2초였다.

**메커니즘.** 무거운 모듈이 소유한 값(여기선 광장 골드)을 프리웜/워밍
단계에서 읽으려고 그 모듈을 강제 인스턴스화하면, 값 자체는 싼데 **모듈
생성 비용이 전환 프레임에 통째로 얹힌다**(Hot-Path Lazy Init Trap의
프리웜 변종 — 스톨을 없애는 게 아니라 프리웜 프레임으로 옮김). 특히
그 값이 **별도의 경량 리더(여기선 PlazaSaveStore, 세이브 파일 직접 read)로도
동일하게 얻어지는데** 무거운 모듈이 그 경량 리더에 단순 위임만 하는
중간자일 때 낭비가 크다.

**표준 규칙.**

1. 프리웜/캐시-워밍이 어떤 값을 필요로 할 때, 그 값의 **가장 경량인 소스**를
   직접 읽어라. 무거운 소유 모듈을 값 하나 때문에 인스턴스화하지 말 것 —
   그 모듈이 값을 경량 리더에 위임만 한다면 특히.
2. 실제로 그 무거운 모듈이 나중에(그 모듈의 자연 필요 시점 = 여기선 스테이지
   클리어) 생성되며 authoritative 값으로 덮으면, 프리웜의 경량 읽기는
   correctness-identical 워밍이 된다. draw/consume 경로는 non-instantiating
   peek(`allow_lazy_create=false` / `get_cached_instance`)를 유지해 강제
   생성을 막을 것.
3. 값 소스가 세이브 파일이면 프로덕션 기본 경로 == 무거운 모듈이 쓰는 경로임을
   확인(커스텀 경로가 테스트 전용인지 grep). 테스트 오염 방지를 위해 프리웜
   경로에 세이브 경로 오버라이드 테스트 훅을 두라.
4. 진단 기법: 스텝형 프리웜(모듈당 1프레임)에서 단일 프레임 1초+ 스톨은
   **한 모듈의 콜드 생성**이다. 라벨이 모듈명을 안 찍으면 로더 헬퍼
   (`_get_module` 등)에 임계-게이트 push_warning(모듈 키 + ms)을 심어 라이브
   1판으로 범인을 특정하라. 이 계측은 존치해 프리웜 콜드-스톨 회귀 트립와이어로
   쓸 수 있다(프리웜 전용 경로라 오버헤드 무시).

**씰.** `stage1_pillar_prewarm_gold_no_result_screen_smoke.gd`(프리웜
gold-warm이 무거운 모듈을 module_getter로 요청 0회 + 골드 캐시가 세이브
파일 실값으로 warm — 옛 코드 토글로 RED 반증). 커밋 7cb4c905d.

## Godot Ball-Path Owner-Snapshot Stat-Refund Trap (owner.set mid-collision → refunded at frame end)

**Incident (2026-07-24).** 부동갑주(celestial_armor)의 넉백 커버 복원 중, 갑주가
소모하는 기력(`owner.special_gauge`)이 볼-패스 히트(stage4 달 파편, stage1 각시탈
부채)에서 **매번 환불**되는 것을 코드 리뷰가 잡아냈다. 갑주는 정상적으로 owner를
차감하는데도 프레임이 끝나면 다시 원복돼, 아이템이 사실상 **공짜로 발동**했다.

**메커니즘 — 프레임당 게이지 저장소가 셋으로 갈린다.**
- `ball_update_controller._build_frame_context(context)`는 `context.duplicate()`로
  `frame_context`를 만들고, 별도로 `_build_scene_snapshot(context)`가 `scene`을
  만든다. **`scene`과 `frame_context`는 다른 dict**이며, 둘 다 프레임 시작 시점의
  `context["special_gauge"]`(= owner에서 읽은 값)로 각각 시드된다.
- 갑주 게이트(`try_block_player_*` → `try_consume_celestial_armor_immunity` →
  `consume_gauge`)는 콜사이트가 넘긴 `context`(= `frame_context`)에만 미러하고
  `owner.set("special_gauge", next)`만 한다 — **`scene`엔 손대지 않는다.**
- 프레임 끝: `ball_update_controller`가 `{"snapshot": scene}`를 반환하고,
  `battle_scene_ball_snapshot_applier.apply_snapshot(owner, scene)`가 scene의
  **모든 키를 무조건** `owner.set(key, scene[key])`로 되쓴다. scene엔 stale한
  프레임-시작 `special_gauge`가 들어 있으므로 갑주 차감이 그대로 **덮여 환불**된다.
- 달 파편은 더 나쁘다: `scene.get("special_gauge")`(stale 100)에서 자기 -2만 빼
  98을 쓴다 → owner=98(정답 78: 100 - 20갑주 - 2파편). 부채/풍선/물파편처럼 scene
  게이지를 아예 안 쓰는 사이트는 owner가 프레임-시작 100으로 100% 원복된다.

**표준 규칙.**
- **볼-패스 충돌 핸들러(`scene` 파라미터가 있는 함수)**에서 owner 스탯을 차감하는
  런타임 효과는, 그 차감을 **스냅샷되는 바로 그 `scene` dict에 반영**해야 한다.
  방법 (a) 사이트 자체 델타를 합성할 때 stale한 `scene`이 아니라 **포스트-게이트
  `context`(= frame_context, 미러된 값)를 FIRST로 읽어라**(달 파편:
  `context.get("special_gauge", scene.get(...))`). 방법 (b) 게이트 proc 직후
  명시적으로 `scene["special_gauge"] = float(context.get("special_gauge",
  scene.get("special_gauge", 0.0)))`(각시탈 whole-hit 블록). 클렌즈는 기력을 안
  쓰므로 armor proc 브랜치에서만 동기화하라.
- **이펙트-패스/void-업데이트 사이트는 자동 교정된다** — `weather_event_state`
  (우박), `stage2_pillar_background`(물파편, `update()->void`),
  `stage1_balloon_event._resolve_paddle_interactions`(패들 넉백)는 **공유 context**를
  게이트에 넘기고, 그 context가 곧 프레임엔드 sync의 소스(effects 컨트롤러
  `next_special_gauge = context.get("special_gauge")` 또는 직접 owner)이므로 미러가
  살아남는다. 이들은 고치지 마라(불필요·리스크). 갈림 기준: **함수에 `scene`
  파라미터가 있으면 볼-패스(환불 위험), `context`만 있으면 이펙트-패스(자기 교정).**
- **유닛 스모크는 공허-GREEN**이다: 헬퍼에 dict를 직접 넘겨 직후 owner/context를
  단언하면 중간 mutation만 보고 프레임엔드 snapshot 왕복을 안 탄다. 봉인은 **실제
  `scene` → `BattleSceneBallSnapshotApplier.apply_snapshot` 왕복**을 태워 owner가
  풀 코스트만큼 떨어졌는지(달 78, 부채 80) 단언하고, 옛 stale-read 코드로 RED
  반증(98/100)까지 해야 한다.

**씰.** `stage4_moon_celestial_armor_gauge_smoke.gd`(달 파편 refund+cleanse 왕복),
`stage1_gaksital_fan_throw_smoke.gd`의 `_verify_fan_throw_celestial_armor_gauge_survives_snapshot`
(부채 whole-hit 왕복). 둘 다 read-order/scene-sync 토글로 RED 반증 완료.

## Godot 링펫 스킬 idle-업데이트 게이트 "보이는 것 ≠ 살아있는 것" 트랩 (VISIBLE vs LIVE)

**Incident (2026-07-07 최초 수정 → 7월 WIP 대량소실로 유실 → 2026-07-27 재랜딩 + 클래스
전수 감사).** 빠나몽 바나나슬라이스에서 보스가 바나나를 **2개 연속 밟으면** 슬립이
영구 지속돼 한쪽 벽으로 계속 밀리며 구석에 고착, 라운드가 끝날 때까지 회복 불가.

**메커니즘 — 틱 게이트는 "보이는 상태", 소비자는 "살아있는 상태"를 본다.**
- `lingpet_companion_skill_effect_update_gate.can_skip_idle()`은 `windup` 없고
  `has_visible_effects_for_skill()` false이며 `skill_state.cooldown > 0`이면 그 슬롯을
  `continue`로 건너뛴다 → `lingpet_skill_runtime_host.update()` 자체가 호출되지 않는다.
  repo 전역에서 `skill_runtime_host.update(`의 라이브 호출자는 **컴패니언 슬롯 틱
  루프 하나뿐**이므로 우회 틱 경로가 없다(그 루프의 소유 모듈은 이관 중이다 —
  `lingpet_egg_runtime` → `lingpet_companion_skill_controller`. 어느 트리든
  게이트 뒤에 있다는 사실은 같으니, 씰은 특정 소유 모듈을 못 박지 말 것).
- 반면 소비자는 게이트 밖에서 매 프레임 폴링된다:
  `battle_update_boss_ai_context_builder._merge_shared_context`가
  `lingpet_egg_runtime.get_boss_ai_context()`를 무조건 merge하고, 이는
  `lingpet_skill_runtime_surface`(state==COMPANION만 확인) → host → 스킬로 그대로 통과.
- 바나나슬라이스의 `has_visible_effects()`는 phase/projectile/landed/particle만 봤고
  `_slip_timer`가 빠져 있었다. 마지막 바나나 소모 후 남는 건 버스트 파티클(수명
  0.33~0.67s)뿐인데 Lv3~5 슬립은 0.65/0.72/0.80s → **파티클이 슬립보다 먼저 죽는
  구간**에서 update가 끊기고 `_slip_timer`가 잔여값에 영구 동결.
  `boss_ai_state`의 슬립 분기(`combined_banana_slip_vel`)는 감쇠 없는 고정 속도로
  매 프레임 `boss_pos.x`를 밀고 **early return** → 정상 AI가 아예 안 돈다.
- 바나나 1개(Lv1~2)는 슬립 0.45/0.55s라 파티클이 더 오래 살아 대부분 안 걸린다 —
  유저 증언 "2개 연속일 때"의 정확한 원인.

**표준 규칙.**
- **`has_visible_effects()`(그릴 게 있나)와 "업데이트가 더 필요한가"는 다른 질문이다.**
  게이트는 둘 다 봐야 한다. 게이트는 호스트의 **스킬별 생존 술어**
  `needs_runtime_update_for_skill(skill_id)`를 함께 조회한다. 새 스킬은 **거기에**
  자기 생존 술어를 등록해야 자동으로 안전하다.
- ⚠️ **`is_launch_blocked()`를 생존 소스로 재사용하지 마라.** 그것은 "재시전을 막고
  있나"라는 **재시전 정책** 질문이고, nest-allowed 스킬(skeleton_archer /
  bone_barrier — 스폰된 엔티티가 아직 살아 있어도 재시전은 허용)에서 **의도적으로
  false를 반환**한다. 거기에 등재하면 게이트는 그대로 `update()`를 끊는데 **에러가
  나지 않으므로** 조용히 죽는다. shipped 게이트 코드 주석이 이 재사용을 명시적으로
  금지하고 있다(`lingpet_companion_skill_effect_update_gate.gd`).
- 그럼에도 **스킬 자신의 `has_visible_effects()`에 비-시각 라이브 상태를 접는 형제
  관용구는 유지**하라(방어 이중화): dwarf_magic `_needs_owner_sync`, sand_prison
  `_owns_clamp`, star_coil `_needs_owner_slow_sync`, banana_slice `_slip_timer`.
- 소유 플래그(`_owns_boss`, `_owns_clamp`)와 pending 자기-스케줄(`_scheduled_refires`,
  `_shots_launched < _shot_count_target`)은 **반드시 `is_active()`에 포함**하라.
- **유닛 스모크는 공허-GREEN이다.** 스킬 모듈의 `update()`를 매 프레임 직접 부르는
  기존 레그는 게이트를 통째로 우회하므로 이 클래스를 절대 못 잡는다. 씰은
  **실제 게이트(`can_skip_idle`) + 실제 `LingpetCompanionSkillState`(캐스트 쿨다운
  스탬프) + 호스트를 관통**해야 하고, 라운드 리셋을 건너선 안 된다(리셋이 증거를
  지운다). 반드시 in-place Edit 토글로 RED 반증검증할 것.

**같은 클래스 전수 감사(2026-07-27, 6렌즈 × 적대검증 25에이전트) 결과.**
- 확정·수정: banana_slice `_slip_timer`(보스 고착), solar_bolt
  `_scheduled_refires`/`_refire_timer` — Lv3+ 후속 낙뢰가 약 93% 확률로 동결되어
  **조용히 폐기**(라운드 리셋이 지움)되고, 22초 랠리를 넘길 때만 "유령 낙뢰 +
  재시전 지연"으로 보인다.
- 구조는 같으나 **수치상 도달 불가**: bubble_trap `is_shot_sequence_active()` —
  버스트 파티클 수명 최대 ≈0.61s가 발사 간격 0.6s를 덮어 구멍이 열리지 않는다
  (게이트 수정으로 덮이지만, RED를 만들 수 없으므로 전용 씰을 두지 않았다.
  실측 없이 정적 분석만으로 "확정"하지 말 것 — 이 건이 그 반례다).
- 반증됨: 로드아웃 재조정으로 스킬이 슬롯에서 이탈해 컨텍스트만 남는다는 가설군
  (4건) — `lingpet_affinity_context_coordinator.configure()`가 보상 지급 **전에**
  현재 장착 액티브를 `active_present_id`로 pin하므로 언락 랜덤 재해결이 장착
  스킬을 뒤바꾸지 못한다. puppet_grab `_owns_boss` 굶주림 — 라이브 teardown 경로가
  전부 real owner를 실어 `cancel(null)` 파킹이 도달 불가(방어 가드로만 반영).
- 모달/일시정지 축은 **대칭**이다: `battle_frame_flow_controller`의 모든 조기 return
  분기와 `battle_physics_gate_coordinator`는 `update_boss_ai`와 `update_lingpet`을
  둘 다 건너뛴다. 이 축은 재조사하지 마라.

**씰.** `lingpet_companion_skill_effect_update_gate_smoke._verify_invisible_but_live_skill_keeps_updating`
(구조), `lingpet_banana_slice_skill_smoke._verify_two_step_slip_expires_under_idle_update_gate`
(2연속 밟기 → 게이트 관통 600프레임 → 슬립 컨텍스트 소멸; 토글 시 554/600프레임 고착으로 RED),
`lingpet_solar_bolt_skill_smoke._verify_pending_refire_survives_idle_update_gate`
(예약된 후속 낙뢰가 게이트 뒤에서 발사; 토글 시 RED). 셋 다 반증검증 완료.


## Godot VFX 리브랜드 발광 예산 트랩 (ADD × 어두운 아트 = 더할 빛이 없다)

**사건 (2026-07-27).** 스매셔 플라즈마를 한령탄(먹/혼령 컨셉)으로 리브랜드하며
텍스처 4장을 교체했다. 레이어 구성·블렌드 배정·알파 상수는 "같은 자리"에 그대로
뒀는데 차징 오브가 사실상 안 보이게 됐다. 원인은 코드가 아니라 **아트의 휘도
분포와 블렌드 의도의 불일치**다.

**메커니즘 3겹.**
1. **ADD 블렌드는 텍스처가 어두우면 더할 빛이 없다.** canvas `blend_add`는
   `dst += src.rgb * src.a`이므로 목탄 먹선(거의 검정)은 알파를 아무리 올려도
   화면을 못 밝힌다. 게다가 `writhe_ember`는 절차적 에너지를 per-fragment
   `brightness`로 게이트하므로(밝은 곳에서만 flow/flicker가 산다) 어두운 아트에서는
   셰이더 연출까지 함께 죽는다.
2. **MIX 저알파 어두운 레이어는 어두운 배경 위에서 "더 어둡게"만 만든다.**
   밝은 픽셀 카운트에 기여가 0이고, 스테이지 배경이 어두울수록 무가시에 가깝다.
3. **속 빈 원환(annulus) 텍스처는 중심에 빛을 하나도 안 놓는다.** 교체 전
   backplate는 가운데가 찬 라디얼 글로우라 중심부에 발광의 38%가 있었는데, 새
   먹안개/봉인 원환은 r<0.30 구간 기여가 **0.0%**다. 구체의 "덩어리" 인상은 중심
   발광이 만든다 — 원환 2장으로는 절대 복구되지 않는다.

실측(반경 26 = 차징 시작, 검정 배경 위 배경 대비 강한 lit 픽셀): 리브랜드 직후
**325px** vs 수정 후 **739px**. 파동(반경 130)에서도 밝은 픽셀이 구 플라즈마의
약 절반이었다. 프록시로 계산한 ADD 발광 예산은 intensity 0에서 약 4.4배 감소.

**표준 규칙.**
- **VFX 리브랜드에서 "레이어 수·블렌드·알파를 그대로 뒀다"는 안전 근거가 아니다.**
  아트의 휘도/알파 분포가 바뀌면 같은 상수가 완전히 다른 결과를 낸다. 밝은 아트 →
  어두운/먹 아트 교체는 **발광 정체성을 별도 레이어로 다시 공급**해야 한다
  (한령탄: 가운데가 찬 청백 라디얼 `_cold_halo`, ADD, HALO_DIAM_MULT 2.70 —
  `ImpactFlareTextureCache.get_glow_texture()` 재사용. 부수 효과로 소프트 폴오프라
  플레이필드 경계에서 자연 감쇠 = 클립 절단이 안 보인다).
- **어두운 아트는 실루엣/질감 담당, 밝은 레이어는 발광 담당으로 역할을 분리**하고,
  저차징 구간에서는 어두운 MIX 비중을 낮춰 발광을 덮지 않게 한다
  (base+slope로 조절 — `clamp(..., 0, CAP)`의 CAP만 올리는 건 대개 무효다.
  리브랜드 WIP의 CAP 4개는 base+slope가 도달 못 해 전부 死문이었다).
- **차징류 스킬은 `intensity`에 시각 하한을 둬라.** 게임플레이 `charge_size`는 0에서
  시작해 3초에 걸쳐 1.0이 되는데 그 값을 그대로 알파/셰이더 세기로 쓰면 첫 1초가
  통째로 안 보인다. 반경은 raw `charge_size`로 유지해 차징량 피드백을 남긴다
  (`SmasherPlasmaState.CHARGE_MIN_VISUAL_INTENSITY`, 파동 쪽 `maxf(0.6, ...)` 선례).
- **`Sprite2D.centered=true` + `_size_sprite(전체 캔버스 → 한 변)` 조합은 텍스처의
  가시 질량이 캔버스 중앙에 있다고 가정한다.** 한령탄 core는 밝은 머리 무게중심이
  캔버스 중심보다 38.5/384 위에 있어 밝은 구체가 실제 투사체 좌표 위로 떴다. 또
  가시 폭이 캔버스의 52.9%뿐이라 같은 배수로도 실제 구체가 훨씬 작게 읽힌다 —
  **DIAM_MULT를 재사용하기 전에 새 텍스처의 fill 비율과 무게중심을 실측**하라
  (측정 스크립트로 alpha bbox / mean premultiplied luminance / 밝은 머리 중심을 뽑는다).
- **판정은 픽셀 카운트로.** "레이어가 visible=true", "셰이더 준비됨" 같은 구조
  어서션은 이 클래스를 전혀 못 잡는다. 배경 대비 **강한** 임계(합 델타 0.45 수준)로
  세라 — 약한 임계(0.09)는 먹 얼룩도 통과시켜 버그 상태와 정상 상태가 같은 값을
  낸다(실측 680 vs 726 = 판별 불가 → 325 vs 739로 분리됨).

씰: `smasher_hanryeongtan_charge_visibility_pixel_smoke`(레그 A-1 = 세기 하한을
**하드 리터럴**로 단언 — 상수 자신과 비교하면 상수를 0으로 낮춰도 GREEN이 되는
자기참조 어서션이 된다(반증검증에서 실제로 걸렸다), 레그 B = 최소 차징 lit 픽셀
판별대 325↔739 사이 550). 반증검증: 헤일로 제거 + 하한 0 + 구 배수/알파 복원으로
RED 확인.

## Godot 회복 램프 플레이어 재개입 트랩 (해제는 구조적으로 한 프레임 늦다)

**Incident (2026-07-07 / 2026-07-27, 두 번에 나눠 드러남).** 스타포인트 퍽 선택
모달을 닫고 복귀한 직후 파워스매싱(천뢰격) / 드라이브(벽력타)로 받아치면 "스킬
공이 느려져 무용지물"이라는 테스터 신고. 원인은 `runtime_perk_resume_safety.gd`의
리줌 안전장치(freeze 10f + recovery 60f)가 **하강 중인 공의 `ball_vel` 크기를 매
프레임 `원속 × 비율`(하한 0.30)로 덮어쓰는데** 플레이어 재개입 해제 경로가 없던 것.

1차 수정(2026-07-07)은 `update()` 앞머리에 **상승 즉시 해제**(`ball_vel.y < -0.01`
→ `reset()` + return, 외부 속도 원문 보존)를 넣어 "발사된 뒤 램프가 스킬 속도를
짓누르는" 절반을 막았다(반증 재현: 스매시 `(6,-38)` → `(0.55,-3.46)`).

**2차(2026-07-27) — 남아 있던 입력-측 절반.** 램프는 `update_ball`보다 먼저 돈다
(`battle_frame_flow_controller`: `update_runtime_perk_resume`(:79) → `update_ball`(:97)).
그런데 해제 조건이 "공이 위로 움직일 때"라서 **타격 프레임에는 공이 아직 하강
중이다**: 램프가 먼저 입력 속도를 눌러놓고 → 같은 프레임의 패들 바운스가 그 값을
소비해 발사가 확정되고 → **다음 프레임에야** 해제가 걸린다. 즉 "쳤으면 해제"는
구조적으로 한 프레임 늦어 입력 절반을 원리적으로 못 고친다. 결과(실측):

| 항목 | 정상 | 모달 직후 | 차이 |
|---|---|---|---|
| 천뢰격 발사 크기(amp 0) | 16.52 | 16.52 | **동일**(발사 캡 포화로 가려짐) |
| 천뢰격 순항 속도 | 24.45 | 18.32 | **-25%** |
| `original_speed`(보스 카운터 복원 시드) | 16.52 | 9.68 | **-41%** |
| 콤보증폭칩 발사 크기(amp 0.45) | 26.66 | 21.95 | **-18%** |

`9.68`은 공유 패들 반사의 min-rally 바닥(`paddle_bounce_velocity_step` →
`ball_speed_policy`)이다 — 램프가 0.30까지 눌러도 반사가 바닥까지만 올려준다.
발사 **첫 프레임**은 캡 포화로 같아 보이므로 "발사가 느리다"는 신고를 발사 크기만
보고 재현하려 하면 재현에 실패한다. 진짜로 갈리는 값은 `set_target_speed` /
`set_original_speed` 시딩이고, 체감은 **발사 직후 뻗지 않는 것**이다.

**표준 규칙.**
- 공유 `ball_vel` **크기**를 매 프레임 덮어쓰는 회복/감속 램프를 만들면, 그 값을
  읽는 소비자는 램프 수명을 넘겨 오염된다(스킬 target/original 시딩, 보스 카운터
  복원, 랠리 골드, 보스 AI 예측 등). "해제 술어"만으로는 부족하다.
- **플레이어가 실제로 받아친 그 타격의 입력 공속은 램프 이전 원속으로 복원하라.**
  현재 구현은 `paddle_bounce_controller.bounce()`의 단일 incoming 읽기 지점에서
  `is_player`일 때만 `perk_resume_original_ball_vel`(램프가 이미 paddle context까지
  싣고 있다)로 **크기만** 되돌린다. 방향은 확정된 반사 결과이므로 건드리지 않고,
  `max` 의미론(현재보다 느린 저장값은 no-op)이라 오버슈트가 불가능하다.
  램프 자체의 teardown은 기존 상승-즉시-해제가 다음 프레임에 그대로 처리한다.
- 안전장치의 목적(모달 직후 반응시간 확보)은 훼손하지 않는다 — 프리즈·득점 차단·
  충돌 쿨다운·램프 비행 속도는 전부 그대로다. 바뀌는 건 "플레이어가 성공적으로
  받아친 그 한 번의 계산"뿐이다.
- 보스 반사(`is_player == false`)에는 적용 금지. 램프는 하강 공에만 무장하므로
  보스 접촉은 애초에 램프 구간에 오지 않고, 넓히면 다른 소유자의 감속을 훔친다.
- 스톱워치처럼 **의도된 감속**은 이 복원의 대상이 아니다. 램프는 스톱워치 활성 시
  arm을 포기하고 진행 중이면 `reset()`하며, 스톱워치 인계
  (`consume_velocity_for_stopwatch`) 후에는 키가 `Vector2.ZERO`라 자동 no-op이 된다.

**동반 결함 — 프리즈 충돌 쿨다운 부풀림.** `try_arm`은 `player_collision_cooldown`을
`FREEZE_FRAMES + 4`(=14)로 강제하지만, 프리즈 동안 `ball_update_controller`가 쿨다운
감소보다 **먼저 조기 반환**하므로 한 프레임도 줄지 않는다 → 실제 차단이 프리즈 10 +
14 ≈ **24프레임**으로 부풀고, 뒷구간(공은 다시 움직이는데 패들만 못 닿는 창)은
득점 차단도 없다(`perk_resume_score_blocking`은 프리즈 프레임에만 참인데 그 프레임엔
`step_motion`이 아예 안 돈다). 프리즈 종료 시 `min(cooldown, 4.0)`으로 정규화한다.

**씰.** `perk_resume_player_bounce_speed_restore_smoke.gd` — 대조군(모달 없음) vs
억제군(램프 활성)이 **수치적으로 동일**해야 한다는 형태로 8레그: 발사 벡터 / 순항
속도(초기부스트 0.5s 창을 넘겨 `apply_motion` 40프레임) / `original_speed` 동치,
실 프로듀서(`RuntimePerkResumeSafety.get_context()`) 컨텍스트를
`duplicate()+merge(scene)` 모양으로 관통시키는 키-생존 레그, 콤보증폭칩 레그,
키 부재 no-op, 오버슈트 금지, 스톱워치 ZERO no-op, 보스 반사 미적용, 프리즈 종료
쿨다운 정규화. ⚠️주의 3가지:
- `paddle_bounce_velocity_resolver`가 **랜덤 커브 회전**을 굴리므로 대조 비교 전에
  `seed()`를 고정하지 않으면 씰이 흔들린다.
- 파워스매시를 실제로 발동시키지 않으면(`power_activation_controller` 미주입)
  `power_activated=false`로 히트 리졸버가 통째로 스킵돼 **공허-GREEN**이 된다
  (`original_speed`/순항 단언이 0 vs 0으로 통과).
- 발사 크기만 단언하는 레그는 amp 0에서 캡 포화로 **변별력이 없다** — 시딩 값이나
  순항 결과를 함께 단언해야 한다.
반증검증: 복원 헬퍼를 in-place로 `return ball_vel` 토글 → 5단언 RED, 쿨다운
정규화 토글 → 1단언 RED(14.00) 확인. (⚠️`git reset`/`checkout`/`stash` 금지)


## Godot 패들-상대 오프셋 상수 1:1 포팅 트랩 (원본 패들은 바닥에서 24px 떠 있다)

**사고 (2026-07-31, 잔영호법 `dash_spirit` 레이저).** 원본은
`create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, ...)` → `start_y =
player_y + 30`이고, Godot 포팅도 `PLAYER_BACK_LASER_Y_OFFSET := 30.0`으로
"패들 중심 +30"을 그대로 옮겼다. 공식은 동일한데 결과는 24px 어긋난다 —
**두 런타임의 패들 바닥선이 다르기 때문**이다.

| | 원본(Python, 챔피언) | Godot |
|---|---|---|
| 패들 바닥 | `HEIGHT(750) - PLAYER_FLOOR_OFFSET(40) + PLAYER_FLOOR_BONUS_BY_MODE(16)` = **726** | `height - paddle_height` = 700 → 바닥 **750** |
| centery | 701 | 725 |
| 레이저 y | 731 (바닥선 19px 위) | 755 (바닥선 5px 아래) |

즉 **원본 패들은 바닥에서 24px 떠 있고, Godot 패들은 바닥에 딱 붙는다**
(`PLAYER_FLOOR_OFFSET` / 리그별 floor 보너스는 Godot에 포팅되지 않았다 —
`godot/` 트리 grep 0건). 그래서 패들 기준 오프셋을 리터럴로 옮기면 그 이펙트만
바닥선 아래로 깔린다. 증상은 "안 보인다"가 아니라 "너무 아래에 있다"라서
상태 스모크로는 절대 안 잡히고, 실제로도 픽셀을 보기 전엔 코드가 맞아 보인다.

**⚠️ 확대 패들: 중심 기준 오프셋으로 "24px 흡수"하면 2차 회귀.** 1차 수정이
`PLAYER_BACK_LASER_Y_OFFSET := 6.0`(= 패들 중심 +6)이었는데, 기본 155x50에서만
맞고 확대 패들에서 다시 깨졌다. 원본 `_compute_player_floor_bottom()`은 확대 시
`PLAYER_VISUAL_OVERHANG * (scale − 1)`만큼 **바닥선도 같이 내린다**. 오버행
`(DEFAULT_SIZE(100) − PADDLE_BASE_HEIGHT(50)) // 2 = 25`가 기본 패들 반높이와
정확히 같아서 `bottom − H/2`가 상쇄되고 **`PLAYER.centery`는 스케일과 무관하게
701로 고정**된다 → 원본 레이저는 항상 화면 절대 y=731 = 바닥−19.
반면 Godot은 패들 크기가 바뀔 때마다 `player_pos.y = 750 − height`로 **하단만**
재앵커하므로 중심이 위로 올라간다. 실측: 주니어 1.5배 원본 732.5 / Godot(중심+6)
718.5 = 14px 위, 벌크업 1.2배 원본 731 / Godot 726 = 5px 위.

**표준 규칙.**
- 파이썬 이펙트를 포팅할 때 `PLAYER.centery` / `PLAYER.bottom` / `PLAYER.top`
  기준 상수를 그대로 옮기지 마라. 먼저 그 이펙트의 **바닥선 대비 절대 Y**를
  계산하고, Godot에서는 그 절대값을 **패들 하단 기준**으로 재앵커한다.
  잔영호법은 `player_center.y + 30` → `player_pos.y + player_size.y − 19`
  (= 하단−19 = 731, 전 스케일 불변).
- **중심 기준 오프셋은 금지**다. 원본 오버행 보정과 Godot 하단 재앵커는 스케일
  응답이 반대라, 중심 기준으로 맞추면 기본 크기에서만 맞는다.
- 리그 보너스가 다른 난이도(주니어 18 / 신화 20 / 리미트·기본 0)에서는 원본도
  ±2~16px 흔들리므로(주니어는 732.5), 파리티 기준은 **챔피언(16)**으로 잡고 그
  사실을 씰 메시지에 남긴다.
- 씰은 상수 비교가 아니라 **결과**를 단언하고, **반드시 확대 패들 레그를 포함**
  한다: 실제 스폰 경로(`try_spawn_from_dash`)로 기본 1.0 / 주니어 1.5 / 벌크업
  1.2를 띄워 절대 Y 고정 + 하단 기준 앵커 + `y + 최외곽 글로우 반높이 <= HEIGHT`.
  기본 크기 레그만 두면 이 회귀를 통과시킨다(1차 씰이 실제로 놓쳤다).
  기대값을 검증 대상 모듈 상수에서 되읽으면 항진식이 되니 파이썬 원본 숫자를
  씰에 박아라.

## Godot `draw_line`에는 라인 캡이 없다 — pygame `draw.ellipse` 실루엣 포팅 트랩

**사고 (2026-07-31, 같은 잔영호법 레이저).** 원본
`ui/hud_display.draw_dash_spirit_lasers()`는 docstring부터 "매우 얇고 긴
타원형"이고 글로우 5겹 / 메인 / 코어 **전부 `pygame.draw.ellipse`**다. 포팅은
같은 두께(`LASER_WIDTH + 2 = 10px`)의 `canvas.draw_line(...)`으로 옮겼는데,
Godot `draw_line`/`draw_polyline`은 **라인 캡 옵션이 없어 무조건 직각(버트)
캡**으로 끝난다. `antialiased = true`는 가장자리만 부드럽게 할 뿐 끝을 둥글게
만들지 않는다. 결과는 "디자인이 다르다 / 사각형 느낌"이라는 사용자 신고.

각짐을 증폭시킨 동반 요인 3개도 같이 본다.
- 글로우가 2겹(12/16px)으로 축소 — 원본은 5겹, 최대 30px. 딱딱한 직사각
  실루엣을 가려주던 렌즈형 후광이 사라졌다.
- 코어가 **전체 길이**로 그려짐 — 원본 코어는 `ellipse_width - 10`, 즉 양 끝
  10px 인셋이라 끝단이 테이퍼된다.
- 원본이 계산만 하고 **그리지 않는** `electric_segments` 지그재그를 포팅이
  실제로 렌더 → 없던 "전기 막대" 인상이 추가됐다.

**표준 규칙.**
- pygame `draw.ellipse` / `draw.circle` 기반 실루엣은 `draw_line`으로 옮기지
  마라. 채워진 타원 폴리곤(`draw_colored_polygon` + 단위 타원 점 캐시,
  `ball_renderer._build_ellipse_points` 관용구)을 겹쳐 그린다. 원본
  `pygame.draw.ellipse`도 안티에일리어싱이 없으므로 폴리곤 쪽이 오히려 파리티다.
- 원본이 계산만 하고 렌더하지 않는 필드가 있으면 **포팅도 그리지 않는다**. 옮길
  땐 원본 draw 함수 본문에서 그 필드가 실제로 소비되는지 grep으로 확인하라.
- 실루엣 씰은 레이어 계약(글로우 겹수·최외곽 반높이·메인 반높이·코어 인셋)으로
  잡고, 기대값은 파이썬 원본 리터럴을 박는다. 구조 씰만으로는 캡 모양을 증명하지
  못하므로 **끝단 확대 픽셀 캡처**를 함께 남긴다.

현행 씰: `godot/tests/smasher_dash_spirit_laser_geometry_smoke.gd`
(Y 절대위치 + 바닥선 포함 판정 + 타원 레이어 계약 + 트리 부착 `_draw()` 관통).


## Godot 포팅 파리티 판정 트랩 (수식이 같아도 "그 경로에서 호출되는가"가 다르다)

**사고 (2026-07-31, 잔영호법 3차).** 레이저 길이 공식이 원본과 완전히 같아서
"파리티 이상 없음"으로 판정했는데, 실제로는 **원본에 없는 동작이 추가**돼
있었다. 원본 `create_dash_spirit_laser`는 **풀대쉬 5개 사이트에만** 있고
하프대쉬 발동 블록(`half_dash_activated` → `on_player_dash_for_tutorial
(is_half_dash=True)`)은 `rolling_timer`만 세팅한다 — 즉 **하프대쉬는 잔영호법을
아예 굴리지 않는다**. Godot은 공통 `_start_dash`에서 `is_half`와 무관하게
생성해 원본에 없던 하프대쉬 레이저(154px)를 만들었다. 조사문의 "하프대쉬
154px 파리티"는 **수식에 11프레임을 대입한 가상값**이었을 뿐이다.

같은 슬라이스에서 나온 형제 결함 2개도 전부 "수식은 같은데 주변이 다른" 형태다.
- **정수화 시점**: 원본은 `set_roll("rolling_timer", int(boost))`로 지속프레임을
  먼저 정수화한 뒤 `×14`를 쓴다. Godot 지속프레임은 실수(비천보 Lv.5 = 20.25)라
  그대로 곱하면 283 vs 원본 280 — 공식이 같아도 결과가 어긋난다.
- **상한이 원본 수량을 잘라먹음**: 증발 파티클 수량을 원본
  `min(60, max(30, len//5))`(210px → 42개)에서 `clampi(len/17, 6, 12)`(12개)로
  줄여 놓고 총량 상한도 32/28로 잡아 두면, 수량 공식만 복원해도 `pop_front`가
  **같은 버스트의 앞부분**을 즉시 지운다. 수량과 상한은 한 세트로 본다.

**표준 규칙.**
- 파리티 판정은 **공식 비교로 끝내지 마라.** 원본에서 그 함수를 호출하는 사이트를
  전부 grep하고, 포팅이 그것을 공통 경로로 올렸는지(= 원본에 없는 분기에서도
  실행되는지) 확인한다. 한쪽에만 있는 호출은 "없는 기능"이지 "다른 값"이 아니다.
- 미실행 경로에 수식을 대입한 값을 **파리티 근거로 인용하지 마라.** 그 경로가
  실제로 실행되는지 먼저 증명한다.
- 원본이 중간값을 정수화/양자화하는 지점(`int()`, `//`, `round()`)은 **연산
  순서까지** 옮긴다. Godot 쪽 입력이 실수로 바뀌어 있으면 특히 어긋난다.
- 수량/밀도 상수를 복원할 때는 **상한·풀 크기·렌더 컷오프를 같이** 올린다.
- 씰은 "미발동 경로가 정말 미발동인지"(하프대쉬 생성 0)와 "버프 상태의 값"을
  각각 레그로 둔다. 기본 상태 1레그만 두면 셋 다 통과시킨다.

현행 씰: `godot/tests/smasher_dash_spirit_laser_geometry_smoke.gd`
(하프대쉬 미생성 / 비천보 Lv.1·Lv.5 길이 / 파티클 수량·상한·3겹 원 계약).
