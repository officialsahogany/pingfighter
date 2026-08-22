# Godot Runtime Hidden-Trap Ledger

Graduated from the former root-instruction ledger on 2026-07-02. This file is
the FULL standing text of every cross-cutting Godot runtime hidden trap. The
current four-surface contract is: immutable ID/title identity in
`docs/godot_runtime_traps_manifest.tsv`, one-line discovery registry entries in
`CLAUDE.md`, 3-8 line path-scoped essence in
`.claude/rules/godot-runtime-traps.md`, and full incident/mechanism/seal text
here.

Rules for this file:

- `GRT-NNN` IDs and manifest titles are append-only stable identities. Other
  docs, memories, and reviews must link the explicit HTML anchor. Never
  renumber, reuse, swap, or retarget an ID/title pair.
- New trap backfills append the next ID/title to the manifest, add FULL text
  here (incident, mechanism, standing rules, smoke seals), add a 3-8 line
  essence to the path rule, and add one discovery line to `CLAUDE.md`.
  Strengthen an existing section instead of appending a near-duplicate.
- Ownership boundaries come from `AGENTS.md` and the focused owner documents;
  asset-generation details remain in the matching skills.

<a id="grt-001"></a>
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

<a id="grt-002"></a>
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

<a id="grt-003"></a>
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

<a id="grt-004"></a>
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

<a id="grt-005"></a>
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
- The current owner path must not take either the project `_texture_cache` or
  `ResourceLoader.has_cached()` shortcut. Another consumer can fill the project
  cache, and Godot can expose an in-flight texture through the engine cache,
  before the project owner has harvested its terminal result. Returning either
  cached object without `load_threaded_get()` leaves the shared owner attached;
  a later cinematic cleanup then detaches a request that had logically completed
  and can produce an ObjectDB exit warning. Only non-owner paths may use either
  cache shortcut; the owner closes through terminal status + get.
- Default bounds stay short for loading-screen callers; live gameplay callers
  that prefer deferral over hitching must opt into longer or unbounded waits.
  Do not solve a live hitch by widening the global defaults.

Smoke seal: `project_resource_loader_import_preference_smoke.gd` forces an
aged foreign in-flight owner, then asserts a default-bounds waiter does not
expire on its first poll and that even an explicitly expired waiter resolves
its own texture without clearing the foreign owner slot. The Han Miryang
smoke also forces an owner, fills the same project-cache path, and requires the
owner slot to close instead of returning that shortcut. Its windowed threaded
preflight separately observes all eight real texture owners, requires
presentation residency peak 4 and deadline misses 0, and verifies clean
terminal collection before process exit.

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

<a id="grt-006"></a>
## Godot Animated Polygon Triangulation Trap

Any Godot `draw_colored_polygon()` point set built from jitter, sag,
shrink/dissolve, sine waves, or other animated offsets must prove the fill is
triangulable before shipping. Prefer geometry that cannot self-intersect
(bounded angle jitter, nonzero area, stable point order); otherwise guard only
the fill with `Geometry2D.triangulate_polygon(points)` and keep outlines or
safe fallbacks visible. Add a sweep smoke for the builder, and treat repeated
`Invalid polygon data` log lines as a frame-budget regression signal. This GRT
entry is the full cross-cutting rule; owner modules and focused smokes carry
the local geometry limits and sweep ranges.

<a id="grt-007"></a>
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

<a id="grt-008"></a>
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

### ⭐분리 FX 호스트 lifecycle: 호스트를 소유하지 않는 렌더러의 얼리리턴을 상속 못 한다

immediate 드로우는 "안 그리면 사라진다"가 공짜지만, **분리 자식 CanvasItem
호스트는 상태**라 아무도 안 내리면 마지막 프레임이 화면에 그대로 남는다. 그리는
쪽(actor 렌더러)에 본체를 한 장도 안 그리고 빠져나가는 얼리리턴이 여러 개 있으면
(홀로그램 게이트 / 고스트 빙의 / 홀로그램 깜빡임 비트 / 변신 몸체 스와프)
**`draw()` 말미의 sync 는 그 프레임에 도달하지 못하고 유령 실루엣이 남는다.**
"프레임 기록(`_last_drawn_sprite`)을 비웠다"는 방어가 되지 않는다 — 기록을 읽는
코드가 실행되지 않기 때문이다. (2026-08-09 소나기 젖음 오버레이 사례. 같은 파일의
오딘의 눈 호스트 주석이 이미 "얼리리턴 뒤에 두면 스테일 프레임이 남는다"고 적고
있었는데 신규 호스트가 그 교훈을 상속하지 못했다 = 형제 훅 상속 실패 클래스.)

- **정본 = fail-closed 2단.** ①`draw()` 최상단(모든 얼리리턴보다 위)에서 무조건
  `set_active(false)`, ②말미 sync 가 실제로 본체를 그린 프레임만 다시 켠다. 새
  얼리리턴이 추가돼도 자동으로 안전하다. 같은 `_draw()` 안의 false→true 는 화면에
  안 보인다 — `visible` 은 드로우 커맨드가 아니라 **프레임 종료 시점의 노드
  상태**다.
- **`draw()` 자체가 안 도는 경로도 있다.** `battle_playfield_effects_drawer` 는
  `actor_context.is_empty()` / 스테이지 전환에서 `clear_transient_canvas_items()`
  만 부르고 return 한다 → 그 메서드에서도 호스트를 내려야 한다. canvas 인자가
  없으므로 **호스트 노드 참조를 렌더러에 캐시**해야 한다(부모 비교로 씬 교체 시
  자가 무효화).
- **씰은 실 진입점을 관통해야 한다.** `_set_rain_wetness_active(false)` 를 직접
  부르는 레그는 호스트만 검증하는 공허 GREEN 이다 — 실제 숨김 컨텍스트로
  `actor.draw()` 를 태워 얼리리턴을 밟게 하라. 반증검증은 프레임 시작 teardown
  한 줄을 `pass` 로 바꿔 RED 를 확인하는 것.

### ⭐단일 Node2D 배틀 씬에는 "플레이어와 보스 사이" z 슬롯이 없다

플레이어와 보스는 **같은 CanvasItem 의 immediate 커맨드**로 순서대로 나가는데,
자식 호스트는 z 를 어떻게 주든 부모 커맨드 **전체 위(z≥0) 또는 전체 아래(z<0)**
로만 갈 수 있다. 그래서 "뒤에 그려질 레이어에 일부러 가려지는 draw" 위에 분리
호스트 오버레이를 얹으면 **가림 관계가 되살아난다** — 베놈 엣지는 보스보다 먼저
플레이어를 보스 위치에 그려 보스 패들이 하반신을 덮는 것이 연출의 핵심인데, 젖음
오버레이가 그 다리를 보스 위에 실루엣으로 되돌려 놓는다.

- 해법 = 드로우 기록에 **`overlay_safe` 플래그**를 실어(정본 = 공용 funnel
  `_draw_texture_region` 의 인자) 그런 draw 를 오버레이 대상에서 제외한다.
  기록을 통째로 버려 "본체 없음"과 같은 경로(호스트 off + 램프는 계속)로 흘리면
  분기가 하나로 준다.
- ⚠️**가려지는 draw 는 한 종류가 아니다. 전수 조사하라.** 두 생산자가 있다:
  ①**그리는 쪽이 아는 경우**(보스 앵커 베놈 엣지 strike/stationary) → 스프라이트
  렌더러가 기록에 표시; ②**호출 렌더러가 아는 경우**(목말 탑승 — 수호령 본체를
  플레이어 **뒤에** 지연 드로우해 머리·손이 라이더를 덮는 것이 연출) → actor
  렌더러가 컨텍스트로 판정. 찾는 법 = "플레이어 스프라이트보다 **나중에** 캔버스로
  나가면서 플레이어를 덮는 immediate 드로우"를 전부 grep 하라(지연 훅 호출 사이트
  포함). ②는 **드로우 순서 결정과 오버레이 제외가 같은 술어를 봐야** 하므로
  `_is_lingpet_body_deferred()` 처럼 공용 static 으로 올려 드리프트를 막는다.
- 씰에는 **플래그를 되돌리는 대조군 레그**를 반드시 넣어라(플래그 무관하게 항상
  꺼져 있어도 통과하는 공허 GREEN 방지).
- ⚠️**소비자 씰만으로는 생산 배선이 안 잠긴다.** 스텁 기록에 `overlay_safe=false`
  를 꽂아 "오버레이가 꺼지는지"만 보면, 실제 분기의 `false` 인자를 지워도 GREEN
  이다(기본값이 `true` 라 조용히 되살아난다). **실 렌더러 `draw()` 를 그 분기
  컨텍스트로 태워 기록의 플래그 자체를 단언하는 레그**를 따로 둬라. 반증검증 =
  분기의 `false` 인자 하나를 지우고 RED 확인(분기마다 각각).

### ⭐알파 마스크 계약은 불투명 픽스처로 검증되지 않는다

"스프라이트 알파를 마스크로 쓴다"는 계약의 씰 픽스처를 **전면 불투명**으로 채우면
셰이더가 쿼드를 통째로 칠해도 통과한다 — 크기/위치 단언은 마스크 생사와 무직교다.
픽스처를 **투명 여백 + 모서리가 빈 실루엣(십자 등)** 으로 만들고 실 Vulkan 캡처로
①발광 bbox 가 쿼드보다 작고 ②bbox 네 모서리 lit==0 ③lit/bbox 면적비가 1.0 에서
멀다를 단언하라. 이 3개는 프로젝트 stretch 배율과 무관해서 창 크기가 변해도 는다.
반증검증 = 셰이더 최종 알파에서 마스크 항을 빼고 모서리 lit>0 을 확인. 하니스:
`godot/tools/player_rain_wetness_pixel_qa.gd`(창모드, `--headless` 금지).

<a id="grt-009"></a>
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

### 동반 트랩: 도착 정착 데드존 부재 = 제자리 한계 순환 (2026-07-31)

**증상.** "공이 여러 개 발사될 때 보스가 어쩔 줄 몰라하며 좌우로 빠르게
왔다갔다, 제자리에서 부르르 떨듯이 진동한다"(허공환영 리포트).

**기전.** `boss_ai_turn_inertia_resolver._get_target_direction`이 데드존 없이
**부호만** 봤다. 목표 오차가 서브픽셀이어도 방향이 서므로:
정지 → 브레이크 거리 `v²/(2·decel)` = 0 → `_approach_target`이 항상 **가속**
분기 → 한 프레임 변위(`accel × fps_scale²` ≈ 1.2px)로 **오버슛** →
`_brake_through_reversal`(0.82배 약한 제동) → 재가속. 매 프레임 반복 =
**지속 한계 순환**. 실측 peak-to-peak **1.826px**, 목표 오차 **0.05px에서도 동일**
(진폭은 오차가 아니라 `accel`이 결정한다 → 상위 스테이지/리그일수록 커진다).
`_approach_target`의 예측 브레이크는 **큰 변위의 오버슛만** 잡는다 — 종단
케이스는 브레이크 거리가 0이라 구조적으로 못 잡는다.

**왜 특정 상황에서만 보이나.** 순환 자체는 보스가 목표에 **주차돼 있는 내내**
돈다. 평소엔 공이 금방 도착해 주차 창이 짧아 눈에 안 띈다. 허공환영처럼 공이
느리게 올라오면(발사 공속 -40%) 주차 창이 배로 늘어 그대로 보인다. 즉 감속
기능이 **원인이 아니라 노출 조건**이다 — 같은 트랩을 "느려진 공" 쪽에서 찾으면
헛다리를 짚는다.

**수정.** 데드존 = `max(SETTLE_DEADZONE_MIN_PX, accel × fps_scale²)`, 즉 "한
프레임 가속으로 만들어지는 변위보다 오차가 작으면 도착". 상수 하드코딩이 아니라
`accel` 유도라 스테이지/리그 배수를 자동 추종한다. 크기는 공(28.6px)·보스
패들(100px)·미스 임계(69.3px) 대비 작아 방어 정확도에 미치는 영향은
실질적으로 무시 가능한 범위다.

⚠️**씰 설계 교훈 — 허용치와 픽스처가 결함을 감췄다.** 기존
`boss_ai_turn_inertia_resolver_smoke`는 이미 "큰 변위 한계 순환"을 봉인하고
있었지만 (a) 허용치가 `pp < 6.0`이라 1.83px 진동을 통과시켰고, (b) 정착 레그
픽스처가 `target == center`(정확히 일치)라 데드존 없는 분기를 아예 안 밟았다.
**정착/수렴 씰의 픽스처는 목표를 보스 중심과 어긋나게 두고**(서브픽셀 포함),
허용치는 "설계상 허용되는 잔진동"까지 좁혀라. 반증검증은 데드존을 in-place로
0으로 돌려 generic `+0.40 / -0.70 / +0.05px` 3레그 RED(`+1.00px`은 GREEN)와,
실제 허공환영 잠금 분신 → AI 컨텍스트 → 예측기 → `BossAiState.update()` 레그의
보스 진폭 RED(**1.826px**)를 확인했다. 이 통합 레그에서 예측 타깃 안정성 단언은
계속 GREEN이므로, 분신 타깃 교대가 아니라 정착 리졸버가 원인임도 함께 봉인한다.

### 동반 트랩: 표시 실수율 × 미스 임계 = 실효 0% (2026-08-01)

**증상.** "극한 / 초월 난이도가 올라갈수록 쉐도우 백스텝·마샬 킥을 그냥 너무
쉽게 다 막아서, 킥강화 계열 무공을 얻기 전까진 거의 쓸모가 없다."

**기전.** 보스 실수는 확률(`boss_mistake_chance`)과 **오차폭**
(`boss_mistake_error_min/max`)의 곱인데, 리그별 오차폭이 위 표의 **미스 임계보다
작으면 실수가 나도 보스가 그대로 막는다** — 표시상 존재하는 실수율이 실효 0%가
된다. 실측: 극한 오차 40~80px vs 임계 **72.8px**(패들 100×1.07), 초월 오차
0~20px vs 임계 **76.8px**(패들 100×1.15). 즉 초월은 **어떤 실수를 뽑아도 구조적으로
못 뚫는다**. 임계는 `boss_paddle_width/2 + hitbox_padding + ball_size/2`이므로
**리그 패들 배율을 올리면 기존 오차폭이 조용히 무효화된다** — 리그/보스 패들
스케일을 건드릴 때 오차폭을 같이 재검토하지 않으면 난이도가 아니라 *메커니즘*이
사라진다.

**두 번째 기전(같은 사건).** `_roll_approach_decision`은 **상승 접근이 시작될 때
1회만** 돈다(`approach_decision_active` 래치). 그래서 이미 상승 중인 공의 궤도를
다시 쓰는 타격 — 쉐도우 백스텝 → 마샬 킥 연계, 마샬 → 더블 마샬 — 은 **아무
판정도 새로 받지 않았다**. 연계가 길수록 보스가 더 확실히 막는 역설.

**해법(현행).** 전역 실수율을 올리지 말 것 — 그러면 다른 캐릭터의 평범한 공까지
같이 쉬워진다. 대신 **그 무공이 공을 맞힌 1회**에만 도는 별도 판정을 둔다:
- 발행: `viper_skill_runtime.mark_kick_read_event(chained)` — 실제 타격 지점에서만
  (`ViperSkillShadowStepRuntime.apply_hit`,
  `ViperSkillMarshalKickRuntime._apply_charge_hit`). **발동/모션 시작이 아니다.**
- 소비: `boss_ai_prediction_state._observe_kick_read_event` — 이벤트 id 변화에서만
  굴린다(프레임 재굴림 금지 = per-opportunity). 당첨 시 오프셋은 리그별 오차폭이
  아니라 **미스 임계 + 6~10px**로 잡아 기하학적으로 비켜나게 한다.
- 확률: `battle_update_boss_ai_context_builder` 리그 프로파일
  (극한 12% / 초월 8%, 연계 +4%p). **스테이지로 감소시키지 않는다.**

**⚠️⚠️목표를 어긋나게 잡는 것만으로는 미스가 보장되지 않는다 — 이게 이 트랩의
본체다.** 보스는 목표를 정한 뒤 *이동*하므로, 판정이 당첨돼도 실제로는 막힐 수
있고 그러면 표시 확률이 또다시 거짓이 된다(원래 결함과 같은 부류). 실측으로
드러난 세 갈래(1512 지오메트리 전수 스윕):

1. **도달 불가.** 보스가 정답 위치에 있고 접촉까지 남은 프레임이 짧으면 잘못된
   목표로 움직여도 히트박스를 못 벗어난다(리드 6프레임 → 100% 차단, 16프레임 →
   100% 미스). → **도달 가능성 게이트**: 못 벗어나면 그 킥은 애초에 '기회'가
   아니다(굴림을 태우지 마라). ⚠️⚠️게이트를 **근사 적분으로 쓰지 마라.** 정지
   상태에서 출발하는 거리 적분은 보스의 **현재 진행 방향과 역전 제동 비용**을
   통째로 빼먹어서, 회피 반대쪽으로 전속 주행 중인 보스를 "즉시 비켜난다"고
   오판한다(재현: y=505.5 / vy=−26 / 보스 −11.15px·f 역주행 → armed 후 차단).
   실제 `BossAiTurnInertiaResolver`로 live `boss_center_x` + `boss_vel_x`에서
   미래를 돌려보고, **공이 히트박스 밴드를 통과하는 전 구간**에서 분리 거리가
   유지되는지 확인하라(진입 프레임만 보면 느린 공이 밴드에 머무는 동안 보스가
   되돌아온다).
   ⚠️⚠️**시뮬레이션은 실 이동 파이프라인 전체를 복제해야 한다.** 리졸버 출력만
   적분하고 그 **뒤에 붙는 후처리**를 빼먹으면 느려진 보스를 "충분히 비켜난다"고
   오판한다. 후처리는 **한 겹이 아니다** — 실경로 순서는
   ① `apply_movement_post_processing`(달지 채찍 제한 + 거미지뢰·플라즈마·베놈·
   바알·별똬리·난쟁이마술·화염병 감속 배율) → ② 위치 전진 + 벽 클램프 →
   ③ **비누 미끄러짐 blend**(`_apply_soap_slip_blend`, AI 결과에 18%만 섞는다).
   ①만 미러링하고 ③을 빠뜨려도 여전히 거짓 약속이 난다(감속 37/45, 비누는 극한
   y=600 v20 기본 배율에서 재현). **정본을 리졸버 static으로 옮기고 양쪽이 같은
   함수를 부르게** 하라 — 복제본을 두면 이 트랩이 그대로 재발한다. 새 후처리를
   추가할 때는 씰의 후처리 축에 **케이스를 같이 등록**해야 한다(리졸버 인자만
   바꾸는 분기 — 스테이지2 속도방어 / 채찍 해제 이동 — 은 보스를 더 빠르게 만드는
   방향이라 거짓 약속이 안 나지만, 그 추론도 축으로 확인해 두었다).
   ⚠️흠칫 창(반응 0.4배 9프레임)도 시뮬레이션에 넣어라 — 필요 리드를 ~4.5프레임
   늘린다. **타이머 소유도 예측 쪽이어야 한다**: `boss_ai_state`가 별도 타이머를
   들면 유지 재검증이 '남은 흠칫'을 몰라 매번 full 9프레임을 가정하고, 흠칫을
   절반 소화한 프레임에서 **살아 있는 래치를 잘못 해제**한다.
2. **안쪽 끌어당김.** 이미 회피 방향으로 magnitude보다 멀리 있는 보스에게 고정
   오프셋 목표를 주면 보스가 공 쪽으로 **되돌아와** 접촉 프레임에 임계선
   72.8px에 0.1px 차이로 걸친다(21/756). → 매 프레임 현재 `boss_center_x`로
   `magnitude = maxf(magnitude, (boss_center_x − arrival_x) × dir)` 재평가.
   회피 **방향도 무작위가 아니라 보스에서 멀어지는 쪽**이어야 한다(무작위면
   반대편 보스가 도착점을 관통한다).
3. **대쉬 관통(2번의 부수 증상).** 대쉬는 목표까지의 스크립트 이동이라 안쪽
   끌어당김이 있으면 도착점을 그대로 통과한다. ⚠️단, 2번을 고치면 **대쉬 억제는
   불필요하다** — 실측으로 확인하고 넣지 마라(토큰/스턴 경제를 건드리는 불필요한
   거동 변경이다).

**⚠️발행 순서 함정.** `_apply_charge_hit`은 후반부에서
`_clear_phantom_kick_chain_window()`로 `marshal_from_shadow_step_chain`을 **지운다**.
이벤트 발행을 그 뒤에 두면 연계 가산이 무에러로 조용히 사라진다(id는 정상 증가해
"배선은 됐다"처럼 보인다). **이벤트/스냅샷 발행은 그 이벤트가 읽는 플래그의
teardown보다 위에, 타격 확정 시점에 둘 것.**

**⚠️이벤트 id는 라운드에서 되감으면 안 된다(ABA).** 소비자는 하강 프레임에서
관측 **전에** 조기 return하므로 되감김을 못 본다 → 다음 라운드 첫 킥이 다시 같은
id가 되어 "이미 본 이벤트"로 오인되고 판정이 통째로 생략된다(보스 서브 라운드에서
재현). **단조 serial**로 두고, 소비자는 id **차이만큼** 굴려라 — 보스가 대쉬/스턴/
프리즈 조기 return에 걸린 동안 들어온 연계 타격들이 하나로 합쳐지면 안 된다.

**⚠️단조 serial만으로는 반쪽이다 — 만료된 pending도 폐기해야 한다.** 킥이 대쉬 중에
들어와 그 상승 구간을 통째로 못 봤으면 기회는 끝난 것이다. 그대로 들고 있으면
**다음 평범한 공**(킥 아님)이 올라올 때 뒤늦게 승인돼 읽기 실패가 걸린다. 하강
전환 / 서브 대기 / 라운드 리셋에서 최신 serial을 **굴림 없이 확인 처리**하라
(`acknowledge_kick_read_events`).
⚠️⚠️**확인 처리는 예측 함수 안이 아니라 조기 return 전부보다 위에 둬야 한다.**
스톱워치 동결 / 스테이지2 이동잠금 / 꼭두각시 / 대쉬 / 스턴은 예측 호출에
**도달하지 않는다** — 예측 안쪽에만 두면 그 프레임들에 들어온 이벤트가 살아남아
상태 해제 후 다음 공에 걸린다(실측 stale_armed=true). 게이트 조건은 "이 프레임에
상승 랠리가 없다". 그리고 이 구멍은 **예측기를 직접 부르는 씰로는 절대 안 잡힌다** —
원인이 생산 측 조기 return이라 `BossAiState.update()`를 관통해야 한다.

**⚠️래치는 매 프레임 재검증해야 한다.** 무장은 '그 순간의 궤도'로 검증되지만
궤도는 **이벤트 없이도 다시 쓰인다**(팬텀 킥, 다른 무공, 벽 반사). 재검증이 없으면
도달 불가로 바뀐 궤도에서도 armed로 남아 그대로 막힌다(후속 y=150~260 × v=20~32
12건 전부 재현). 유지 판정은 무장보다 **완화된 여유**(hysteresis)를 쓰고,
⚠️**남은 리드가 0인 마지막 프레임**은 미래가 없으므로 "지금 비켜나 있는가"로
갈아타라 — 무장과 같은 규칙을 쓰면 모든 성공 케이스가 마지막 한 프레임에서
해제되어 '접촉 시점 armed'가 항상 false가 된다.

**⚠️연계 여부를 단일 불리언으로 싣지 마라.** 밀린 이벤트를 몰아 굴릴 때 최신
플래그 하나를 모든 굴림에 재사용하면 (쉐도우 12% + 마샬 16%)가 **16% 두 번**이
된다(실측 0.294 vs 설계 0.261). 연계 이벤트도 **별도 단조 serial**로 세고 굴림별로
배분하라. 불리언은 두 번째 진실 소스가 되므로 아예 두지 않는 편이 낫다.

**⚠️새 이벤트가 '이미 이긴' 래치를 지우면 안 된다.** 지우면 연계할수록 나빠지는
역설이 되고(플레이어가 딴 우위를 후속 킥이 취소한다), 풀연계 확률도 두 기회의
합집합이 아니라 **마지막 굴림 하나**로 접힌다(실측 0.152). 이미 속은 상태면 회피
기하만 새 궤도에 맞춰 다시 잡고 굴림은 건너뛴다 → 합집합 0.261이 성립한다.

**⚠️같은 기회의 후반부를 새 기회로 세지 마라.** 더블 마샬(팬텀 킥)은 같은
`_apply_charge_hit`을 지나지만 마샬 기회의 후반부다. 발행하면 풀연계가 2회가
아니라 3회 판정을 받아 극한 26% → 37.9%로 부푼다(이 산술은 **위 래치 유지가
전제**다 — 래치를 지우는 모델에서는 성립하지 않는다).

**⚠️확률 0인 리그는 완전 no-op이어야 한다.** 이벤트를 보고 접근 판정을 먼저
리셋한 뒤 확률 0에서 return하면, 호출자가 판정 소실을 보고 **일반 실수를 새로
굴린다** → 주니어/챔피언이 킥마다 7~20% 전역 실수 기회를 덤으로 받는다.

**⚠️목표 클램프.** 보스 목표는 `[play_left + w/2, play_right − w/2]`로 클램프된다.
도착 x가 벽에 붙어 있으면 굴린 방향에 따라 오프셋이 통째로 먹혀 그대로 막힌다 —
클램프 **후** 실제 분리 거리를 보고 방향을 뒤집어라.

**씰.** `boss_kick_read_failure_smoke.gd`. ⭐**목표 x의 분리 거리만 재는 단언은
위 3갈래를 전부 통과시킨다(공허-GREEN)** — outcome 레그는 실제
`BossAiState.update()` → `BallMotionCollisionDetector.check_paddles` 왕복을
관통하고 "armed면 boss_paddle 이벤트 0"을 단언해야 한다.

⭐**스윕 축이 부족하면 반증 토글이 GREEN으로 통과한다** — 이 트랩에서 실제로 세 번
겪었다. (a) `y=700/v=20`만 돌면 보스가 목표까지 여유 있게 도착해 '안쪽 끌어당김'
결함이 임계선 0.1px 차이로 살아남는다 → **(y, 속도) 조합을 넓게**. (b) `boss_vel=0`
으로만 시작하면 '속도 무시 게이트' 결함이 통째로 안 잡힌다 → **보스 초기 속도 축
필수**(정지 / 양방향 전속 / 중간속). (c) 감속 디버프 축이 없으면 '후처리 누락'이
안 잡힌다 → **이동 후처리 배율 축 필수**. 확률 0 대조군(보스가 정상적으로 막는다)이
없으면 "원래 안 막히는 자리였다"로도 통과한다.

⭐**armed 판정 기준을 케이스별로 나눠라.** 궤도가 한 번도 다시 쓰이지 않는 단일 킥
스윕은 **"한 번이라도 armed면 통과"**(강한 계약)로 재야 한다 — '접촉 시점 armed'로
재면 마지막 프레임의 유지 해제가 안전망으로 작동해 단언이 거의 항상 참이 되고,
후처리 누락 같은 결함이 그대로 통과한다(실측). 반대로 궤도가 다시 쓰이는 케이스
(후속 킥)는 정상적인 해제가 있으므로 **'접촉 시점 armed'** 기준이 맞다.

⭐**"이미 이긴 래치 유지" 레그의 후속 확률을 0으로 두지 마라** — 0이면 "판정 없는
리그" 조기 return으로 빠져 래치 유지 분기를 아예 안 밟는다(변별력 0). 0.0001처럼
0이 아니면서 사실상 실패하는 값을 써라. 같은 이유로 만료 레그는 **두 경로(하강 /
리셋)를 각각** 돌아야 한다 — 하나만 돌면 다른 쪽 구멍이 살아남는다.

확률 계약은 단언이 아니라 **측정**으로 봉인한다: 쉐도우 → 마샬 시퀀스를 3000회
돌려 arm 비율이 설계 합집합 0.261 근처인지 본다(래치 삭제 모델이면 0.152, 연계
가산 오배분이면 0.294로 각각 벗어난다).

⚠️**0.261 / 0.190은 조건부 상한이지 실효 득점률이 아니다.** 두 킥이 **모두** 도달
게이트를 통과하고 래치가 접촉까지 유지될 때만 성립한다. 마샬 킥의 기회 인정률을
E라 하면 실효치는 대략 `12% + 88%·E·16%`(극한) / `8% + 92%·E·12%`(초월)이다.
게이트가 요구하는 최소 리드는 **`|ball_vel.y|`** 기준이지 전체 공속이 아니며
(마샬 발사각 20~60°라 전체 15~26이 수직 7.5~24.4로 흩어지고 이후 50프레임 커브로
계속 변한다), 보스 이동력이 스테이지마다 오르므로 **스테이지별로 달라진다**.
계측은 `skill / stage / league / |v| / |vy| / launch_angle / boss_vel_x / eligible /
roll_won / active_at_contact / collision_result`를 함께 남기고, 확률 보정은 한 판이
아니라 여러 판 표본으로 하라.

반증검증 13토글 RED 확인: 도달 게이트 / 속도 인식 / 이동 후처리 / 안쪽 끌어당김
가드 / 0% no-op / 단조 serial / 만료 pending 폐기(하강·리셋·생산 조기 return) /
래치 유지 / 매 프레임 재검증 / 연계 확률 배분 / 팬텀 제외 / pending 누적.

<a id="grt-011"></a>
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

<a id="grt-012"></a>
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

<a id="grt-013"></a>
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

<a id="grt-014"></a>
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
**peek-only** registry lookup in
`lingpet_companion_player_runtime_resolver.resolve_player_dash_state`
(key `smasher_dash_state`); the egg-runtime method is compatibility forwarding
only.

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

<a id="grt-015"></a>
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

<a id="grt-017"></a>
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

<a id="grt-018"></a>
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

### Variant: player-control-ONLY window (ball path frozen, stale `ball_active` still open)

`battle_frame_flow_controller` has a window that runs `update_player_control`
but NOT `update_ball`: the **victory loot phase** (보스 패배 → 상자 드랍;
"공/보스 AI/서브 흐름은 동결하고 플레이어 조작·아이템·이펙트만 태운다"). The
hazard is that **the ball gate does not close by itself there**: a match-ending
score never runs `reset_ball` (`match_scoreboard_flow_controller` calls it only
on `update_start_serve`; the win ladder goes RESET_GAME → loot phase → result
screen), so `owner.ball_active` stays `true` from the final rally all the way
through the loot phase. Every player skill gated on `config["ball_active"]` is
therefore still activatable in a window where its ball-path advance never runs.

Reference failure (2026-08-01): Smasher 회천비륜 (`shield_kiting`). Its
projectile advances ONLY in `update_and_collide()` (ball path), and
`is_movement_locked()` is true for the whole `STATE_WIND_UP`. Pressing the skill
during the chest drop created the wind-up projectile, nothing ever advanced it,
`smasher_player_controller` took its `movement_locked` early return
(`player_speed = 0`, x pinned to `locked_player_x`) forever — "발사가 안 되고
캐릭터가 정지". Worse than cosmetic: the frozen player cannot walk into a box,
so `_all_boxes_done()` never becomes true and the loot phase never finishes =
hard softlock.

Standing rules:
- The ball gate for player skills is closed at the SHARED source:
  `battle_scene_player_control_config_builder` ANDs `owner.ball_active` with
  `not owner.victory_loot_phase_active`. Any NEW frame-flow window that keeps
  `update_player_control` alive while freezing `update_ball` must extend that
  same expression — do not add a per-skill phase check.
- A skill state that (a) can be activated from the player-control path and
  (b) only advances on the ball path must be able to **self-heal**: on a frame
  where its ball gate reads closed, release/clear the live projectile and report
  `movement_locked = false`. The activation gate alone is not enough — a skill
  already winding up when the final point lands carries the lock into the phase.
  Reference: `SmasherShieldKitingState._release_stalled_projectile` (also stops
  the wind-up loop SFX, which is in `gameplay_loop_audio_cleanup.STOP_METHODS`
  and would otherwise drone through the whole phase).
- Movement-locking skills are the softlock class; audit them first when adding a
  new player-control-only phase. Ranking test: "if this lock never releases, can
  the phase still reach its exit condition?"
- Seal shape (`smasher_shield_kiting_victory_loot_freeze_smoke.gd`): unit legs
  (`build_config` / `update_input` called directly) are NOT enough — they stay
  GREEN if the frame-flow wiring itself breaks. The seal must drive the REAL
  chain one frame at a time: `battle_frame_flow_controller.update` (loot branch)
  → `battle_scene_update_callbacks` → `battle_scene_actor_update_driver`
  → real config builder → real `smasher_player_controller` → the skill state.
  Fixture must set `ball_active = true` AND `victory_loot_phase_active = true`
  (assert the stale-true precondition explicitly; a fixture with
  `ball_active = false` proves nothing), hold a movement direction, and assert
  the paddle **actually moved** — a "projectile is empty" assertion alone passes
  vacuously when nothing ran. Needs a live-rally control leg (skill DOES arm and
  DOES pin the paddle) to prove the harness reaches the skill at all.
  Reverse-verified: reverting either the config gate or the release turns the
  integration leg RED, including the "paddle must move" softlock assertion.

<a id="grt-020"></a>
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

<a id="grt-021"></a>
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

**같은 드로어를 다른 화면에서 재사용할 때(2026-08-06 퍽 선택 하단 능력치 띠):**
행이 들어갈 최소 높이를 계산할 때 **드로어의 내부 지오메트리뿐 아니라 그 위에
얹히는 크롬의 안쪽 여백까지** 더해야 한다. `draw_cached_player_stat_rows`는
제목 49 + 행당 최소 19 + 하단 여백 8을 요구하는데, 원장 크롬
(`RuntimePerkTraditionalChrome.draw_stats_ledger`)이 `rect.grow(-11)`을
돌려주므로 실제 최소 띠 높이는 `11*2 + 49 + 19*10 + 8 = 269`다. 크롬 여백을
빼고 248로 잡으면 마지막 행이 조용히 잘린다. 상수는 곱셈으로 유도해 두고
(`STATS_BAND_CHROME_INSET` / `STATS_BAND_HEADER_HEIGHT` /
`STATS_BAND_ROW_MIN_GAP` / `STATS_BAND_FOOTER_PADDING`), 크롬 반환 rect가 그
인셋과 일치하는지 씰에서 대조하라. 판정은 "예약 높이 >= 상수"가 아니라
**드로어가 실제로 append한 행 rect 개수**로 하고(`hover_row_rects.size() == 10`),
최소 미만 rect를 억지로 넘겨 행이 실제로 줄어드는 음성 대조를 함께 둔다 —
없으면 개수 단언이 변별력 0인 공허-GREEN이다. 예산이 모자라면 잘라 그리지
말고 **띠를 통째로 끄고 기존 레이아웃으로 되돌려라**. 씰:
`runtime_perk_choice_stats_band_smoke`.

<a id="grt-022"></a>
## Godot 공유 레이아웃 빌더 요소-추가 트랩 (그린 자리와 클릭 자리가 갈라진다)

**사건 (2026-08-06 — 퍽 선택 화면 하단 능력치 원장 추가).**
`runtime_perk_choice_layout.build_layout()`은 모달 전체를 세로 중앙 정렬한다:
`group_h`(제목간격 + 카드높이 + 패널간격 + 원장높이 + 힌트간격 + 꼬리)로부터
`group_top = (view.y - group_h) / 2`를, 다시 `card_y = group_top + title_to_card`를
얻는다. 그리고 **같은 빌더가 그리기와 입력 히트테스트 양쪽을 먹인다** —
렌더러는 `runtime_state.get_card_rects(view_size)`로 카드를 그리고, 모달 입력
핸들러는 `get_card_index_at(position, view_size)`로 클릭을 잡는데 둘 다
`build_layout`을 통과한다.

여기에 새 요소(능력치 띠)를 넣으면서 `group_h`에는 더했지만 히트테스트 경로에
같은 플래그를 넘기지 않으면, 카드는 위로 올라가 그려지는데 클릭 판정은 예전
좌표에 남는다. 무에러, 스모크 무반응, 플레이어에게는 "카드 위쪽을 눌렀는데 안
먹는다"로만 보인다.

**표준 규칙:**
- 레이아웃 결과에 영향을 주는 새 입력값은 `build_layout` / `get_card_rects` /
  `get_card_index_at` **세 곳 모두**에 같은 인자로 흘려라. 그리고 그 값의
  정본은 한 곳(여기서는 `runtime_state.stats_band_enabled`)에서만 읽는다
  (`stats_band_requested_from_runtime_state`).
- 그 플래그는 **프레임 시작(update)에서 한 번만** 갱신하라. 렌더러가 `draw()`
  시점에 뒤집으면 모달이 열린 첫 프레임의 클릭이 이전 값으로 판정된다. owner /
  registry 유무처럼 컨텍스트에서 오는 값은 `_capture_stats_context(owner, registry)`
  처럼 update 초입에 고정한다.
- ⚠️**반증은 카드 중심점으로 하면 안 된다.** 세로 밀림(사례: 146px)이 카드
  높이의 절반(208px)보다 작으면 중심점은 여전히 옛 rect 안에 들어가 인덱스가
  그대로 맞는다 — 실제로 이 반증이 처음에 GREEN으로 통과했다. **카드 상단
  모서리**(`position.y + 4`)로 재야 어긋남이 드러난다.

**동반 트랩: 치수를 줄이면 그 치수에서 파생된 것들이 같이 내려온다.**
레이아웃 상수는 폰트 크기 / 셀 상한 / 배율의 유일한 파생원인 경우가 많다.
- 퍽 카드의 이름(`rect.size.x * 0.072`) · 성급(`* 0.057`) · 설명
  (`card_width / 16.4`) 폰트가 전부 **카드 폭**에서 나온다 → "카드를 줄이되
  글자 크기는 그대로"는 **폭을 고정하고 높이만** 줄여야 성립한다.
- 무공 원장의 글자 배율 `status_scale = clamp(rect.size.y / 172, ...)`는
  **원장 높이**에서 나온다 → 원장을 226 → 187로 줄이면 제목이 21 → 17px로
  같이 줄어든다. 기준값(172 → 142)을 `_draw_status_panel`과
  `_get_status_counter_rect` 양쪽에서 **함께** 옮겨야 글자가 보존된다.
- 카드를 낮추면 성급 밑줄과 설명 괘선이 붙어 이중선으로 읽힌다
  (`CARD_DESCRIPTION_TOP_RATIO`로 간격 회복).
- 설명 누출은 픽셀이 아니라 **폰트 메트릭으로 headless 판정 가능**하다: 실
  wrap 캐시(`_ensure_card_desc_cache`)에서 줄 수를 뽑고
  `_draw_card_description_block`의 기하(box = rect+(14,3)/−(28,6),
  첫 baseline = box.y + font + 8, 줄간격 font+4, 문단 간격 2)를 재현해
  마지막 줄이 상자 안인지 본다. 비-headless 캡처에만 맡기지 마라(CI에서
  스킵된다). 이 씰의 반증(카드 316 → 296)이 **여유가 8.2px뿐이라는 실제
  결함**을 드러냈다 → 여유는 최소 두 자릿수 px로 잡아라.

**공유 프레젠터를 두 번째 화면에서 재사용할 때:** 값·색·게이지가 원본 화면과
같아야 한다면 상수를 다시 타이핑하지 말고 **원본이 쓰는 상수 소유 스크립트에서
직접 끌어 써라**(`CharacterInfoOverlayState.SPECIAL_GAUGE_MAX` 등). 씰은 "값이
비어 있지 않다"가 아니라 **원본 화면의 실 빌더를 같은 owner+registry로 돌려
라벨·값·색을 한 글자씩 대조**해야 한다 — 레지스트리가 항상 null인 픽스처는
"보너스가 통째로 누락돼 기본값만 표시"되는 회귀를 통과시킨다. 반증은 상수 하나만
바꿔 보면 된다(`BASE_ACTIVE_ITEM_SLOT_COUNT` 3 → 4 ⇒ `0 / 3 != 0 / 4`).
hover 게이팅한 `include_breakdown` 같은 플래그는 **재조립 시그니처에 접어라** —
안 접으면 hover 진입 프레임이 캐시 히트로 넘어가 증감 내역이 영원히 빈 채 굳는다.

<a id="grt-023"></a>
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

<a id="grt-024"></a>
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
- **The same slot-0-only trap repeats wherever a NON-HUD surface describes a
  guardian** — the 수호령 교체 (Replace) comparison card is the reference repeat:
  `lingpet_egg_runtime._get_overflow_current_guardian_snapshot` published only
  `get_active_skill(0)` / `get_passive_skill(0)`, so a guardian whose second
  passive had been unlocked by Guardian Enhancement showed ONE passive on the
  card while the live TAB panel showed two — reading as "replacing loses a
  skill". Iterate `get_active_slot_count()` / `get_passive_slot_count()` and
  publish per-slot arrays (`active_skills` / `passive_skills`); keep the flat
  primary keys only as a legacy fallback for older snapshot producers. The card
  renderer must then derive its row block height from the remaining card space
  (N rows), not from a hardcoded two-block layout.
- **Displayed skill LEVEL must be the EFFECTIVE level, never the stored loadout
  level.** `LingpetCurrentProfile.get_active_skill(slot)` resolves its data at
  `_get_effective_active_skill_level()` = raw + `active_skill_bonus` from
  Guardian Enhancement, while `get_active_skill_level_for_slot(slot)` returns
  the RAW acquisition-time roll. Mixing them publishes Lv.3 next to a
  description and cooldown that are actually Lv.5's — silent, no error, and it
  reads to the player as "this panel shows the pet as it was when I got it".
  The single source of truth is the resolved skill dict's own `"level"` key
  (what `lingpet_runtime_snapshot_builder` already feeds the character-info
  panel). Same rule for passives (`passive_skill_bonus` /
  `second_passive_skill_bonus`).
- **An EMPTY slot must never be faked, and its two meanings must not be collapsed.**
  A hatch skill roll is `randi_range(0, 3)` where **0 means that slot stays empty**
  (~25% per slot), and the rolled preview loadout is exactly what a confirmed
  replacement keeps — so on a decision screen both classic fallbacks are lies:
  `LingpetCatalog.get_passive_skill(pet_id, "")` never returns `{}` (it falls back
  to the shared pool's FIRST passive), and an extra "no active id → use the catalog
  default loadout" guard throws away that guardian's real passives too. The second
  one is especially easy to add by accident because it looks defensive:
  `LingpetLoadoutState.get_loadout()` ALREADY returns `build_default_loadout()` when
  the pet has no stored entry, so any further default substitution can only ever fire
  on a REAL loadout. Publish the empty array and render an explicit "없음" row. Keep
  "arrays present but empty" (roll known → none) distinct from "no per-slot arrays at
  all" (legacy flat producer → passive genuinely not decided yet → pending copy).
- **Skill NAMES need `translate_text()`, not just descriptions.** The catalog stores
  Korean names and `LanguageSettingsData` carries their 6 non-Korean forms, so a
  surface that translates only the description ships a half-Korean title in every
  non-Korean UI. Pet display names are NOT in those tables (proper nouns) — do not
  add them speculatively.
- The regression smoke must drive the REAL enhancement path
  (`apply_guardian_enhancement_candidate` with `active_skill` / `passive_skill`
  / `second_passive_unlock`) and assert the comparison snapshot equals the LIVE
  profile — a fixture whose raw and effective levels happen to match proves
  nothing. Two fixture traps: (a) `LingpetCurrentProfile` hands back its own
  cache dicts and `_invalidate_metadata_cache()` `.clear()`s them IN PLACE, so
  an oracle captured before the hatch flow must be `duplicate(true)`d, or it
  silently empties; (b) hatch skill rolls use `randi_range(0, 3)` where 0 means
  "that slot stays empty", so any assertion about the INCOMING guardian's
  rolled skills is RNG-flaky unless the fixture pins a preview loadout (mirror
  it onto the owner loadout keys too — the commit path re-reads them via
  `sync_from_owner`). Reference:
  `lingpet_main_egg_overflow_smoke._verify_comparison_shows_live_guardian_state`.

<a id="grt-025"></a>
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

<a id="grt-028"></a>
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

<a id="grt-030"></a>
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

<a id="grt-032"></a>
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

<a id="grt-026"></a>
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

<a id="grt-027"></a>
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

<a id="grt-019"></a>
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


<a id="grt-033"></a>
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


<a id="grt-034"></a>
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

<a id="grt-037"></a>
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
<a id="grt-038"></a>
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

<a id="grt-040"></a>
## Godot 스모크 임의 프로퍼티 대입 조용한 레그-abort 공허 GREEN 트랩

**⚠️ 자매 함정 (2026-08-03): "실패할 수 없는 어서션"으로 신규 공용 게이트를 봉인한다.**
공용 게이트(파법호신결 `boss_skill_parry_gate`)를 N개 스테이지 소유자에 배선한 뒤,
씰이 `_expect(Stage2BossSkillState != null, "…게이트와 함께 컴파일되어야")` 형태로만
남으면 **파일이 파싱되는 한 무조건 참**이라 배선 자체를 한 줄도 증명하지 못한다
(실측: S2~S5 4개 스테이지 레그 전부가 이 형태 → 게이트를 `if false and …`로 끊어도
원래 GREEN 유지). 형제 변종은 **호출 사이트를 `source.contains("hook(a, b, c)")`로
확인**하는 것 — 호출문 텍스트를 남긴 채 `if false:` 뒤로 옮기면 그대로 통과한다
(주석까지 계수하는 소스-단언 규칙과 같은 뿌리). 판정 기준 = 어서션마다
"이게 실패하려면 코드가 어떻게 망가져야 하나"를 답할 수 있어야 하고, 답이
"파일이 안 열려야 한다"거나 "문자열이 지워져야 한다"면 그 레그는 공허다.
정본 형태 = **소유자를 실제로 생성해 진짜 진입 함수를 호출**하고(필요하면 협력자만
Fake), 게이트 ON/OFF **양방향**(패리 시 활성화 side-effect 부재 + 미패리 시 존재)을
같이 단언한다. ⚠️생성자 인자를 가진 소유자(`Stage4PonkRuntimeCoordinator`는 6인자)는
`preload != null` 레그에서 **영원히 안 드러난다** — `.new()`를 부르는 순간에야 파스
에러로 튀어나온다. 반증은 in-place Edit 토글(`if false and …`)로, 씰의 CI 락스텝
등재(`godot/tools/run_pre_push_checks.ps1` + `.github/workflows/godot-ci.yml` **양쪽**)
까지가 한 단위다.

**⚠️ 자매 함정 (2026-08-01): 임시 RefCounted에 만든 `Callable`은 즉시 죽는다.**
`Callable(self, "_update_player_control")`는 대상 객체를 **약참조**한다. 통합
스모크에서 콜백 테이블을 `BattleSceneUpdateCallbacks.new().build_frame_callbacks(...)`
처럼 **임시 객체로** 만들면 그 줄이 끝나는 순간 빌더가 해제되고, 반환된 Callable이
전부 `is_valid() == false`가 된다. `battle_frame_flow_controller._call_delta`는
invalid Callable을 **조용히 건너뛰므로** 프레임 흐름이 통째로 no-op이 되고,
"투사체가 비어 있다" 같은 부재-단언은 전부 공허 통과한다(실측: 8프레임을 돌렸는데
입력 리더 호출 0회). 규칙 = 콜백 빌더를 **살아 있는 지역/멤버 변수로 보관**하고,
통합 레그에는 (a) `is_valid()` 단언과 (b) "무언가 실제로 일어났다"는 **양성 대조군**
(예: 패들이 실제로 이동, 스킬이 실제로 발동)을 반드시 함께 둔다. 부재-단언만 있는
통합 씰은 배선이 죽어도 GREEN이다.

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

<a id="grt-041"></a>
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

<a id="grt-031"></a>
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

### 거울상 변종: 생산자가 나중에 사라진 소비자 (플래그가 콘텐츠 계열을 통째로 제거)

Incident (2026-08-01): 천기보도(`downtown_treasure_map`)의 "신화 확률 +750%,
패시브 드랍 +15%"가 라이브에서 **완전 무효**. 배율/보너스 배선 자체는 멀쩡했다 —
`PerkConversionFlags`(부팅 시 항상 ON)가 `active_item_field_spawn_pool.
build_spawn_candidates`에서 passive/mythic 템플릿을 전부 스킵해
`mythic_sum == 0` / `passive_sum == 0`이 되고, `get_spawn_group_target_shares`의
`... if sum > 0.0 else 0.0` 빈-그룹 가드가 두 target을 0으로 접었다. 배율이 0에
곱해진다. 에러 없음, 기존 씰 전부 GREEN(레거시 flag-OFF 경로만 봤으므로).

반쪽-랜딩의 **거울상**이다: 표시가 앞서 나간 게 아니라, 표시가 옳던 시점 이후에
**생산자가 제거**됐다. 표준 규칙:

- **콘텐츠 계열을 통째로 끄는 플래그를 켤 때는 그 계열을 스케일하는 소비자를
  역추적하라.** grep 대상은 플래그 이름이 아니라 **제거되는 그룹 키**
  (`"passive"` / `"mythic"` 스폰 그룹, 보상 타입 상수)다. 플래그 파일만 grep하면
  소비자는 플래그를 모르므로 한 건도 안 잡힌다.
- **`x if sum > 0 else 0` 형태의 빈-그룹 가드는 스케일러의 무덤이다.** 그 가드
  아래의 모든 배율/보너스는 그룹이 비는 순간 조용히 0이 된다. 이런 가드를 쓰는
  함수에 배율을 넘기는 소비자는 "그룹이 살아있는가"를 별도로 단언해야 한다.
- **레거시 flag-OFF 파리티 씰은 프로덕션 증거가 아니다.** 천기보도의 기존 씰
  (`treasure_map_perk_port_smoke`)은 flag 기본값 OFF에서 필드 스폰 share만
  검사해 계속 GREEN이었지만, 실제 배포 경로(보상 상자)는 한 줄도 안 지나갔다.
  플래그로 갈리는 시스템의 씰은 **ON 레그를 명시적으로 켜서** 돌려야 한다.
- **죽은 옵션은 표기부터 정정하고, 대체 레인은 설계 결정으로 올려라.** 이미 0을
  반환하는 옵션을 임의의 다른 수치로 바꾸는 건 버그 수정이 아니라 밸런스 변경이다.
- 씰=`treasure_map_perk_port_smoke`(설명문 '패시브' 금지 단언 + flag ON을 강제한
  Lv.0 대조군 vs Lv.5 4레그 — **같은 roll에서 보상 타입이 갈려야** 통과).
  반증검증=배율 인자 미전달로 되돌리면 Lv.5 레그 2개 RED, 대조군 2개는 GREEN 유지.

<a id="grt-039"></a>
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

<a id="grt-043"></a>
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
   리테인드 HUD를 화면 수명 때문에 가릴 때는 **draw 호출만 건너뛰면 안 된다.**
   호스트가 지난 draw command를 계속 보유하므로 부착 호스트와 deferred pending
   호스트의 `visible`을 함께 끄고, 호스트 `_draw`/테스트 위임과 즉시 draw 폴백도
   같은 게이트로 조기 반환한다. 로딩 전환과 화면 모달처럼 숨김 이유가 둘 이상이면
   마지막 요청 하나로 덮지 말고 AND로 합성해 한 이유가 먼저 풀려도 노출되지 않게 한다.

**씰.** `scoreboard_top_mini_retained_host_smoke.gd`(redraw 게이트/키
커버리지/애니 창/폴백/위임 + pending 숨김/NODE_MODAL/전투·비탑 복귀/다중 이유
합성 — 게이트 무력화 토글로 RED 반증 확인),
`stage1_pillar_sensor_orb_bezel_bake_smoke.gd`(핫패스 소스-프리미티브 예산
draw_arc 5/draw_circle 7 + 베이크 ops 지오메트리 21op 계약 + 베이크 수렴 —
핫패스 프리미티브 추가 토글로 RED 반증 확인). 폴백이 correctness-identical
이라 픽셀 패리티 씰은 봉인력이 없으므로(플레이북 규율), 라이브 재측정의
라벨 us/prims가 런타임 직교 카운터다. 커밋 817b76b24.

<a id="grt-045"></a>
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

<a id="grt-046"></a>
## Godot Fragment-Clip 캔버스-단위 vs 프레임버퍼-픽셀 트랩

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

**⚠️ 재발 (2026-08-09, 로딩 먹연 아지랑이) — "전체화면만 구도가 위로 뜬다".**
`loading_ink_haze_host`가 `_protection_y`(도움말 보호선) / 페더 / 웨이브 /
`haze_rise_span_px` / `haze_origin_ramp_px`를 **캔버스 단위 그대로** 올렸다.
종단선이 항상 같은 **절대 프레임버퍼 y(1114.5px)** 에 고정되므로 화면이 클수록
비율상 위로 올라간다: 창 1684px→**66%**, 전체화면 2160px→**51.6%**(Δ14.6%p).
증상은 "전체화면 아지랑이가 위에 있다" + **두 모드 모두** 먹연 하단과 도움말
사이에 없어야 할 검정 띠. **기본 창(2020x1246)에선 배율 1.0이라 완전히
안 보인다** — 그래서 저작·QA를 통과했다. 진단 순서: ①`screen_px` 비교 대상
uniform을 전수 나열 ②각각 "캔버스인가 프레임버퍼인가" 표기 ③창 크기 2종의
**절대 px**이 같은지 확인(같으면 미변환 확정). ⚠️증상 보정(전체화면 한정
오프셋 비율)은 오답이다 — 배율은 전체화면 여부가 아니라 **창 크기**의 함수라
확대된 창에서도 어긋나고, 텍스처 샘플만 밀면 종단선·페더·램프는 그대로다.
현재 screen-clip 소비자는 플라즈마 FX 호스트와 이 로딩 호스트 **2곳뿐**이니,
새 소비자를 만들면 변환 헬퍼를 반드시 통과시켜라.
씰은 `content_scale_size`를 절반으로 낮춰 **배율 != 1**을 강제한 뒤 업로드값이
환산값과 같고 **캔버스 원값과는 다름**을 함께 단언한다(배율 1.0 레그만 있으면
항등이라 공허 GREEN). 씰: `loading_ink_haze_host_smoke.
_verify_screen_space_unit_contract`.

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


<a id="grt-048"></a>
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

<a id="grt-044"></a>
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

<a id="grt-042"></a>
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

<a id="grt-049"></a>
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

<a id="grt-016"></a>
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


<a id="grt-047"></a>
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

<a id="grt-010"></a>
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

<a id="grt-051"></a>
## Typed 배열에 조건식 리터럴을 대입하는 draw-time 런타임 트랩

**사고 (재발 확인 2026-07-30).** Godot 4.6에서 아래처럼 조건식 양쪽에 untyped 배열
리터럴을 쓰고 그 결과를 `Array[float]`에 바로 대입하면 파서와 정적 경고는 통과해도
실행 시 타입 오류가 난다.

```gdscript
var offsets: Array[float] = [-26.0, 26.0] if count >= 2 else [22.0]
```

오류가 난 대입 지점에서 함수 실행도 중단된다. `void_phantom_split` 툴팁에서는 준비
구간의 미니 캐릭터 뒤 비행 구간에서 이 오류가 발생해, 그 아래의 보스 가드·환영·실제
공이 모두 그려지지 않는 반쪽 프리뷰가 되었다. 반복 draw의 오류 로그 폭주는 확인된
사실이지만, 이것만으로 게임의 영구 정지 원인 전부를 입증했다고 과단정하지 않는다.

이 계열은 강타 프리뷰의 `Array[Color]`, 허공환영 게임플레이의 `Array[float]`, 같은
초식의 툴팁 프리뷰에서 반복되었다. 안전한 기본형은 명시적 typed 배열을 먼저 만든 뒤
`append()`하는 것이다. 조건식 피연산자 자체가 이미 typed 변수인 경우에는 안전하므로
형태만 보고 일괄 치환하지 않는다.

```gdscript
var offsets: Array[float] = []
if count >= 2:
	offsets.append(-26.0)
	offsets.append(26.0)
else:
	offsets.append(22.0)
```

**봉인 규칙.** 헬퍼 반환값만 직접 검사하면 실제 renderer 호출부를 버그 형태로 되돌려도
GREEN이므로 draw-time 계약을 봉인하지 못한다. `CanvasItem` 렌더러는 트리에 붙인
`Node2D`/`Control`의 실제 `_draw()` 안에서 공개 `draw()` 경로를 호출해야 한다. 또한
시간·phase로 분기되는 프리뷰는 문제의 후반 분기에 진입할 때까지 redraw를 계속해야 한다.
표준 smoke runner가 이 실제 경로의 `SCRIPT ERROR`를 실패로 승격시키는지, 헬퍼는 둔 채
production 대입부만 결함 형태로 되돌리는 in-place 반증검증으로 확인한다. 현행 씰은
`smasher_void_phantom_smoke.gd`의 `VoidPhantomTooltipPreviewProbe`다.


<a id="grt-052"></a>
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

<a id="grt-055"></a>
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

**⚠️ `pygame.draw.*`는 알파 블렌딩을 하지 않는다 — 겹쳐 그리기 포팅의 함정.**
원본 증발 파티클은 SRCALPHA 표면에 반경 s / 2s/3 / s/3 원을 큰 것부터 그리는데,
pygame draw는 픽셀을 **덮어쓰므로** 최종 알파가 누적이 아니라 바깥 a / 중간 a/2 /
중심 a/3 — **가운데가 옅은 속 빈 기포**다. 같은 원 3겹을 Godot 캔버스에 그대로
겹쳐 그리면 source-over로 중심이 `1-(1-a)(1-a/2)(1-a/3)` ≈ 0.854까지 차올라
**밝게 채워진 구체**로 뒤집힌다(원본 중심 0.235). 반경·입력 알파만 보는 씰은
이걸 못 잡는다. 해법은 비중첩 원환이거나 **알파 밴드를 미리 구운 캐시 텍스처
1장**(`vapor_particle_texture_cache.gd`) — 후자가 파티클당 드로우도 3 -> 1이다.
씰은 (a) 구운 텍스처의 알파 프로파일 실측 + "중심 < 바깥" 방향 단언, (b) 캐시를
`reset_for_test()` 후 실 `_draw()`를 돌려 **소비 여부**까지 확인(프로파일만 보면
렌더러가 그 텍스처를 안 쓰고 3겹으로 되돌아가도 GREEN)으로 두 겹이 필요하다.

**⚠️ 수량 상한은 원본에 없다 — "1회 최대 버스트"로 잡으면 연속 발동이 잘린다.**
원본 파티클 리스트는 무상한인데 포팅이 상한 + `pop_front`를 두면, 상한을 1회
최대치 근처(80)로 잡아도 레이저 2개를 연달아 막는 순간 앞 버스트가 산 채로
지워진다(60+60 중 40 소실). 상한은 **도달 가능한 동시 버스트 수** 기준으로 잡고,
씰에 최대 버스트 + 연속 2버스트 레그를 넣는다. 성능 절충으로 낮게 유지한다면
"원본 복원"이 아니라 명시적 차이로 코드 주석과 문서에 남긴다.

현행 씰: `godot/tests/smasher_dash_spirit_laser_geometry_smoke.gd`
(Y 절대위치 + 바닥선 포함 판정 + 타원 레이어 계약 + 파티클 알파 프로파일·캐시
소비·최대/연속 버스트 + 트리 부착 `_draw()` 관통).


<a id="grt-053"></a>
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

**변종 사고 (2026-08-05, 천뢰격 무콤보 페널티 — 반대 방향 함정).** 유저 리포트
"콤보를 모아 쏘나 그냥 쏘나 공속이 같다"를 조사하다, 원본 무콤보 페널티
(`actual_boost *= 0.75`)가 `POWER_SMASH_NO_COMBO_BOOST_MULT := 1.0`으로 평탄화된
것을 발견하고 "항등원 상수 = 포팅 회귀"로 판정해 0.75를 복원했다(a6005e829).
그러나 그 평탄화는 **체크리스트에 기록된 2026-06-11 Option C 설계 결정**(무콤보
스매시도 쓸 만하게 유지, "do not restore parity ... without a new design decision"
— `docs/character_skill_perk_checklist.md` §3.2)이었고 리뷰에서 반려됐다. git
이력·원본 대조·수치 분석까지 하고도 **설계 결정 기록 문서를 대조하지 않아**
파리티 논리가 정반대 결론을 냈다. felt-gap 리포트("차이가 안 느껴진다")는 차이를
복원하라는 뜻이지 **어느 쪽을 움직일지(콤보 상향 vs 무콤보 하향)의 설계 결정을
내포하지 않는다.** 진단 사실 자체는 유효했다: 순항(target_speed)은 콤보 유무
동일했고, 콤보 보너스(+6.6% 캡)는 발사 캡(2.14x/2.40x)에 양쪽이 함께 포화해
0.5초 버스트의 캡 비율 차(+12%)만 체감에 남았다(콤보증폭칩 R2 캡 마스킹과
같은 메커니즘). 후속: 설계 오너가 **콤보 상향**을 새 결정으로 채택(2026-08-05)
— 콤보 보너스가 순항에도 반영되고 콤보 발사 천장이 (1+base bonus)로 완화됐다.
정본은 체크리스트 §3.2의 2026-08-05 amendment.

**표준 규칙.**
- 파리티 판정은 **공식 비교로 끝내지 마라.** 원본에서 그 함수를 호출하는 사이트를
  전부 grep하고, 포팅이 그것을 공통 경로로 올렸는지(= 원본에 없는 분기에서도
  실행되는지) 확인한다. 한쪽에만 있는 호출은 "없는 기능"이지 "다른 값"이 아니다.
- 미실행 경로에 수식을 대입한 값을 **파리티 근거로 인용하지 마라.** 그 경로가
  실제로 실행되는지 먼저 증명한다.
- 원본이 중간값을 정수화/양자화하는 지점(`int()`, `//`, `round()`)은 **연산
  순서까지** 옮긴다. Godot 쪽 입력이 실수로 바뀌어 있으면 특히 어긋난다.
- 수량/밀도 상수를 복원할 때는 **상한·풀 크기·렌더 컷오프를 같이** 올린다.
- 항등원(×1.0 / +0)으로 평탄화된 파리티 상수를 발견하면 "미포팅 회귀"로 단정하기
  전에 **기록된 설계 결정을 먼저 대조**하라 — 캐릭터 스킬 체크리스트의 "recorded
  design decision" 항목, `docs/` 디자인 노트, 핸드오프 패킷. 기록이 있으면 복원은
  새 설계 결정(사용자 승인) 없이 금지, 기록이 없을 때만 파리티 회귀 후보다.
- felt-gap 리포트는 방향 결정이 아니다: 차이-계약(콤보/레벨/버프 유무)이 체감되지
  않는다는 보고에서 "원본 파리티 복원(=한쪽 너프)"을 자율 선택하지 마라. 캡 포화
  등 무감각 메커니즘 진단까지만 하고, 상향/하향 선택지는 설계 오너에게 올린다.
- 씰은 "미발동 경로가 정말 미발동인지"(하프대쉬 생성 0)와 "버프 상태의 값"을
  각각 레그로 둔다. 기본 상태 1레그만 두면 셋 다 통과시킨다.

현행 씰: `godot/tests/smasher_dash_spirit_laser_geometry_smoke.gd`
(하프대쉬 미생성 / 비천보 Lv.1·Lv.5 길이 / 파티클 수량·상한·3겹 원 계약).
천뢰격 무콤보 중화(Option C)는
`junior_power_smash_tuning_smoke._verify_power_smash_combo_gate_uses_real_combo_for_launch_cap`
+ 체크리스트 §3.2가 정본.

<a id="grt-054"></a>
## Godot 룰 상수 파생-임계값 리터럴 트랩 (승리 점수를 올리면 보상이 조용히 전멸한다)

**사고 (2026-07-31, 5점제 -> 7점제 개편).** `match_score_state.WIN_GOAL`을 5에서
7로 올리는 작업에서, 상수 두 개(`WIN_GOAL`, `DEUCE_TRIGGER`)만 바꾸면 끝나는
것처럼 보였다. 실제로는 **승리 점수에서 파생된 임계값이 리터럴로 굳어 있는
소비자**가 게임 전역에 흩어져 있었고, 그중 하나는 판정을 통째로 뒤집었다.

- **보상 전멸 (치명).** `stage_clear_result_reward_plan_builder.get_reward_box_count`
  의 듀스 판정이 `if winning_score > 5: return 1`이었다. 5점제에서 이 리터럴은
  "정규 승리 점수"를 뜻했지만, 승리 점수가 7이 되는 순간 **모든 정규 승리(7:x)가
  `> 5`를 만족**해 전 스테이지 클리어가 듀스 취급(상자 1개)으로 접히고, 압승 3개 /
  일반 2개 경로가 영구히 도달 불가가 된다. 에러도 경고도 없고, 기존 씰은 5:0 /
  5:2 같은 **개편 전 좌표만** 단언하고 있어 그대로 GREEN이었다.
- **사다리 사본.** 듀스 목표 진행이 정본(`match_score_state`) 말고
  `match_score_event_controller._would_score_finish` 폴백에 `if player_score == 5
  and boss_score == 5: deuce_goal = 7`로 한 벌 더 복제돼 있었다. 정본만 고치면
  매치포인트 예고와 실제 종료가 갈린다.
- **HUD 발동선 리터럴.** `scoreboard_top_mini_renderer`의 듀스 폴백이
  `player_score >= 4 and boss_score >= 4`라 7점제에서 4:4에 듀스 연출이 뜬다.
- **보스 각성 임계값 9개가 전부 절대 점수.** 물대포 해금 3 / 격노 4 / 고압 5
  (S2), 쿠로미 각성 2 (S3), 맵 파괴 3 · 환영 해금 4 (S4), 크리스탈 실드 4 (S6),
  아카무 각성 3 (S7), 미노타우로스 각성 3 (S8). 승리 점수만 올리면 각성 시점의
  **매치 대비 비중**이 조용히 앞당겨져 각성 보스와 싸우는 구간만 길어진다.
  특히 S2 고압 티어(격노 다음으로 높은 압박)는 5점제에서 `player_score 5` =
  **듀스에서만 도달 가능한 특수 상태**였는데, 7점제에서 5를 그대로 두면 5·6점이
  평범한 중후반이라 최고 압박이 상시화된다 — 값을 안 건드렸는데 난이도가 바뀐다.
- **폴백 기본값 분열.** `snapshot.get("win_goal", 5)` 형태의 기본값이 6곳
  (`defeat_settlement_screen` x2, `battle_defeat_flow_resolver`,
  `battle_playfield_overlay_drawer`, `scoreboard_state` x3)에 있어, 상태가 없는
  경로만 구 룰로 판정하는 국소 분열을 만든다.

**메커니즘.** 리터럴 `5`가 코드에 두 가지 서로 다른 의미로 쓰였다: (a) "정규 승리
점수"라는 **파생값**, (b) "각성 시점"이라는 **독립 튜닝값**. 둘이 같은 숫자로
보이는 동안은 구분이 필요 없지만, 기준 룰이 움직이는 순간 (a)는 따라와야 하고
(b)는 비례 재보정 판단이 필요하다. 리터럴은 이 구분을 지워 버린다.

**표준 규칙.**
- 승리 점수/듀스 발동선에서 **파생되는** 임계값은 리터럴 금지. 반드시
  `MatchScoreState.WIN_GOAL` / `DEUCE_TRIGGER` / `DEUCE_GOAL_BASE`를 읽어라.
  특히 `> N`처럼 **부등호로 "정규 범위 밖"을 표현하는 판정**은 기준값이 오르면
  참/거짓이 통째로 뒤집히므로 최우선 대상이다.
- 듀스 사다리는 **한 벌만** 존재해야 한다. 정본은
  `match_score_state.resolve_deuce_goal(tied_score)`(static)이고, 스냅샷만 가진
  폴백 경로도 사본을 만들지 말고 이 static을 부른다.
- **독립 튜닝값(보스 각성 등)은 자동 파생하지 말고 비례 재보정을 명시 결정**하라.
  각 상수 옆에 "매치 대비 몇 %"를 주석으로 남겨야 다음 룰 변경 때 판단이 재현된다.
  "듀스에서만 도달 가능"처럼 **다른 상수와의 관계**가 설계인 경우 그 관계를 주석에
  적어라(고압 티어 = WIN_GOAL과 동일).
- 씰 픽스처의 점수 좌표를 **개편 전 절대값으로 하드코딩하지 마라.** 그 씰은 룰이
  바뀌어도 GREEN을 유지하며 회귀를 못 잡는다. 최소 한 레그는
  `for losing in range(0, WIN_GOAL): assert 정규 승리는 듀스 티어가 아니다`처럼
  **룰 상수로 생성한 전 구간 불변식**이어야 한다.
- 판정은 정적 분석이 아니라 반증으로: 리터럴을 되돌리는 in-place 토글로 새 씰이
  실제 RED가 되는지 확인한다(`git reset`/`stash` 금지 — 이 레포는 WIP가 산다).

현행 씰: `godot/tests/match_score_state_ladder_smoke.gd`
(사다리 계단 6:6->8 / 7:7->9 / 8:8->10, 상한 서든데스, `would_score_finish`와
실제 채점의 전 구간 대조, `force_score` 사다리 역산, 이벤트 컨트롤러 폴백 대조),
`godot/tests/stage_clear_result_reward_plan_builder_smoke.gd`
(`_verify_regular_win_is_never_treated_as_deuce` = 정규 승리 전 구간 불변식).

### 보강 (2026-07-31 리뷰 반려에서 추가로 드러난 은신처)

위 규칙을 적용하고도 리뷰에서 4건이 더 나왔다. 리터럴은 "값이 쓰이는 곳"보다
**"값이 계약으로 박제된 곳"**에 더 잘 숨는다. 다음 4종을 별도로 훑어라.

- **소스 텍스트 단언.** 구조 씰이 `router_source.contains("FORCE_STAGE_CLEAR_
  PLAYER_SCORE := 5")`처럼 **선언문 문자열째로** 박제한다. 코드 grep으로 값을
  고쳐도 이 계약은 안 잡히고, 고치는 순간 씰이 RED가 된다. 소유권을 봉인하되
  값은 파생식으로 단언하라(`:= MatchScoreState.WIN_GOAL`을 contains).
- **같은 폴백의 두 번째 사본.** 듀스 폴백 `>= 4`가 `scoreboard_top_mini_renderer`
  뿐 아니라 **`scoreboard_renderer`(리테인드 호스트 경로)에도** 있었다. 이쪽은
  결과가 `is_deuce` -> redraw 플래그/상태 키로 흘러서, 듀스 표시는 안 뜨는데
  평범한 4:4·5:5에서 **매 프레임 재드로**만 발생한다(픽셀상 무증상 성능 회귀).
  한 리터럴을 고쳤으면 같은 식을 **전 렌더 계층에서** 재검색하라.
- **디버그/치트 경로의 파생 점수.** F9 강제 클리어가 `5:0`을 주입하면 7점제에선
  매치가 끝나지 않는다. 치트·디버그 경로도 승리 조건을 만족시켜야 하는 소비자다.
- **죽은 중복 상수.** `WATER_CANNON_UNLOCK_ROUND_WINS := 3`처럼 소비자 0인
  파리티 잔재가 새 기준(4)과 충돌하는 이중 계약으로 남는다. 같은 개념을 두 상수로
  두면 다음 개편 때 한쪽만 갱신된다 — 동기화가 아니라 **제거**가 정답이다.

**씰 작성 규칙 (추가).** 회귀 씰의 마지막 상태를 바꾸는 레그는 **뒤에** 붙여라.
발동선 폴백 레그를 `render_to`가 "마지막 저장 인자"를 검증하는 지점 **앞에**
끼워 넣었다가 그 단언을 깨뜨렸다. 리테인드 호스트류는 누적 상태를 검증하므로
레그 순서 자체가 계약이다.

**연쇄 오진 주의.** 이 슬라이스에서 `match_score_event_controller_smoke`가
행(hang)처럼 보였는데, 실제로는 `79413220e refactor(godot): retire guardian
affinity growth`가 컨트롤러의 링펫 위임 훅을 지우고 **씰만 남겨** 빈 배열
`score_results[0]`을 읽던 선재 RED였다(모듈은 죽고 씰이 산 고아쌍의 역방향).
러너는 첫 실패에서 멈추므로 이 한 건이 배치 전체를 가려 "미검증"을 "GREEN"으로
착각하게 만든다 — **배치가 중간에 죽으면 그 뒤 항목을 통과로 세지 마라.**

<a id="grt-059"></a>
## Godot 스프라이트 셀 여백 × 패들 배율 트랩 (캐릭터가 벽에 못 닿는다)

**증상.** "패들이 커질수록 캐릭터가 왼쪽/오른쪽 끝까지 못 가고 보이지 않는 사각
패들에 막힌 것처럼 보인다." 물리 클램프는 정상이다 —
`player_movement_state.update_horizontal` 의
`clamp(player_pos.x, play_left, play_right - paddle_width)` 는 패들 rect 를 정확히
벽에 붙인다. 어긋나는 건 **그림**이다.

**메커니즘.** 플레이어 스프라이트는 160x160 셀을 물리 패들 rect(기본 155x50)
중앙에 정렬해 그리고(`stage1_player_actor_renderer` 의 `player_visual_rect`),
셀 안에서 몸통은 좌우 투명 여백을 끼고 있다. 그리고 셀도 패들도 **같은**
`player_paddle_scale = paddle_width / 155` 로 커진다. 따라서 패들이 벽에 완전히
붙었을 때 남는 틈은

    gap = (셀 여백 px - 2.5) x 배율        (2.5 = (160-155)/2)

로 **배율에 정비례**한다. 셀 여백은 시트마다 크게 다르다(실측: 스매셔 걷기 29px,
옵티머스 유휴 34px, 코만도 유휴 52px, 바이퍼 유휴 49~57px) → 기본 패들에서도
26.5~55px, 2배 패들에서는 53~110px 가 벌어진다. 즉 **아트가 헐렁한 캐릭터일수록
증상이 심하고**, 코드만 읽어서는 알 수 없다(알파 실측이 필요하다).

**표준 해법 = 시각 전용 벽 슬라이드.** 물리 패들과 공 판정은 손대지 말 것.
`player_sprite_wall_slide.gd` 가 벽 근처에서 스프라이트 draw rect 만 벽쪽으로
민다. 램프는 `offset = gap * (1 - d/span)^2`, `span = clamp(gap*5, 150px, 이동
반폭)` — 2제곱이라 램프 진입 시점의 속도 변화가 0이고 보정이 벽 직전에 몰린다.
중앙부 오프셋은 정확히 0이라 패들 중앙 대비 어긋남이 없다.

- ⚠️**클램프 완화(패들이 벽 밖으로 나가게)는 게이트웨이 밸런스 변경**이다. 그림과
  판정은 계속 일치하지만 화면 밖 패들 폭이 낭비되어 "끝까지 붙기"가 손해인
  포지션이 된다(현재는 최적 코너 수비). 사용자 승인 없이 고르지 말 것.
- ⚠️**패들 히트박스를 몸통 폭으로 좁히는 것**은 방어 폭 -34%급 밸런스 변경이다.

**여백 데이터는 오프라인 표, 값은 시트당 1개 "벽 앵커".** 런타임 알파 스캔은 시트
압축 해제를 부르므로 `tools/measure_player_sprite_body_insets.py` 가
`godot/scripts/resources/player_sprite_body_insets.gd` 를 생성한다. 앵커는 그 시트
전 프레임의 **raw bbox 최소 여백**이며, 더 느슨할 수도 프레임별일 수도 없다.

- ⚠️**더 느슨하면 필러를 덮어쓴다.** 전투 드로우 순서는 `_draw_pillar_scene ->
  _draw_transformed_playfield_scene -> post-playfield pillar HUD`
  (`battle_scene_drawer.draw`)이고 `draw_set_transform` 은 **클립이 아니다** →
  벽 밖으로 밀린 플레이어 픽셀은 필러 배경 **위에** 그려져 그대로 보인다.
  ⭐"필러 크롬이 나중에 덮어준다"는 **거짓** — `draw_pillar_overlay` 로 배경을
  다시 그리는 경로는 공 스폰 오버레이 split-pass 전용이다
  (`battle_spawn_overlay_draw_coordinator`). 그래서 측정 기준은 가시성 임계값이
  아니라 **alpha>0**(0이 아닌 모든 알파)이다 — 임계값을 두면 "아무도 크기를 안 본
  누출"을 조용히 허가하게 된다. 엄밀 기준 비용은 라이브 유휴/이동 시트에서 0px,
  전체 최대 3px(76장 중 26장 영향, 중앙값 2px).
- ⭐**프레임별로는 더 좁아도 된다 — 그게 전 프레임 접촉의 유일한 방법이다.** 각
  프레임 자기 bbox 를 쓰므로 누출은 구조적으로 0이고, 비용은 "가장자리가 고정되고
  **몸이 움직이는 것**"이며 크기는 프레임간 인셋 차와 같다(출하 시트 중앙값 11px,
  최대 33px). 작으면 안 보이고 커지면 지터로 읽히므로 생성기가 인접 프레임(루프
  포함) 최대 이동량이 `MAX_PER_FRAME_MOTION_PX`(6) 이내인 시트에만 프레임별
  앵커를 싣는다 — 76장 중 33장. 벽에서 실제로 뜨는 시트 14장 중 11장이 여기 들어가
  잔여 0이 된다.
- ⚠️**시간 기반 프레임 시트**(플라잉킥: `Time.get_ticks_msec()`)에 프레임별 앵커가
  실리면 draw 와 씰 단언 사이에 프레임이 바뀌어 **플레이크**가 된다. 씰은 그런
  시트가 시트 앵커를 쓰는 상태임을 못 박아야 한다.
- ⚠️**"바디만 골라내는" 열 밀도 필터로 앵커를 키우려는 시도는 실패한다.** 높이가
  충분한 소품(대장장이 망치 머리)은 바디로 분류되고, 얇은 꼬리만 걸러도 (1)의
  누출 제약을 넘는 순간 필러로 샌다.
- ⚠️⚠️**플레이필드 클립은 이 잔여를 못 줄인다.** 클립은 앵커가 raw bbox 보다
  느슨해도 안 새게 해줄 뿐이고, 잔여는 프레임별 편차라 클립과 무관하다. 그리고
  즉시모드 플레이어 드로우에 클립을 넣는 것 자체가 **드로우 순서와 충돌**한다 —
  `Control(clip_contents)` 자식은 부모 `_draw()` 뒤에 통째로 렌더되므로 보스/링펫
  사이 레이어에 못 낀다. 남는 길은 draw 콜마다 dest/source rect 를 잘라내는
  소프트 클립인데 회전·셰이더 합성 경로가 안 잘린다.
- ⚠️**발/몸통 밴드 앵커도 답이 아니다.** 하단 25% 밴드로 재면 유휴는 안정되지만
  (바이퍼 유휴 12→1px) 이동·질주는 다리가 흔들려 **악화**된다(5→27px, 23→60px).
- 결과: 예산을 넘는 시트만 시트 앵커를 쓰고 잔여를 받아들인다. 생성 표
  `SHEET_RESIDUAL_PX` / `SHEET_MOTION_PX` 가 진단값(바이퍼 유휴 잔여12/이동10,
  대장장이 질주 23/18, 스매셔 25D 유휴 30/30). 이 3장을 더 줄이려면 런타임이
  아니라 **아트 재크롭**이다.

- ⭐**새 플레이어 시트를 추가/교체/재크롭하면 생성기를 다시 돌려라.** 표에 없는
  텍스처는 `Vector2.ZERO` = 보정 없음으로 **조용히** 떨어진다(무증상 드리프트).
- ⚠️커버리지 씰을 "대표 시트 N장 + 표 크기 하한"으로 쓰면 **공허하다** — 새 시트가
  생겨도 기존 항목이 그대로면 GREEN이다. 생성기는 `SOURCE_SCRIPTS` 와
  `SKIPPED_SHEETS` 를 같이 내보내고, 씰은 소스 스크립트에서 res:// PNG를 전수
  추출해 **표 ∪ SKIPPED 와 차집합이 0인지** 대조해야 한다. 소스 스크립트 목록
  자체도 `battle_*_sprite_paths.gd` 디렉터리 스캔과 대조해 낡지 않았는지 본다.
- ⚠️**여백 0 시트를 "보정 불필요"로 스킵하면 거기가 뚫린다.** 셀(160)이 패들(155)
  보다 넓어 그림 rect 는 **항상** 벽 밖으로 `2.5px x 배율` 나간다. 셀 가장자리까지
  그림이 찬 시트(바이퍼 플라잉킥)는 슬라이드가 0일 뿐 **클램프 대상**이다.
  런타임은 "미등재"와 "유효한 0"을 서로 다른 값으로 구분해야 한다
  (`UNKNOWN_INSET` vs `Vector2.ZERO`) — 한 값으로 뭉치면 정확히 그 시트가
  무방비로 필러를 침범한다.
- ⚠️**SKIPPED 를 생성기가 자동으로 채우면 그건 면책 목록이다.** 측정 실패를 전부
  흘려보내면 "지원 안 하는 격자로 만든 새 바디 시트"가 재생성 후에도 보정 0인 채
  GREEN이 된다. 생성기는 사람이 사유를 적은 `EXPECTED_SKIPS` 허용목록에 없는
  측정 실패에 대해 **비정상 종료**해야 하고, 씰은 (a) 사유가 자동 생성 문구가
  아닌지 (b) SKIPPED 항목이 실제로는 측정 가능한 바디 시트가 아닌지 본다.
  ⭐**stale 허용목록도 비정상 종료해야 한다.** 예약 경로가 한번 측정 가능해진 뒤
  허용목록만 남으면, 나중에 그 경로가 깨졌을 때 다시 자동 면책된다. NOTE 출력 후
  성공 종료는 그 통로를 열어둔다.

- 몸에 붙는 부속(접지 그림자, 바이퍼 제트팩 노즐, 대쉬 잔상)도 **같은 오프셋을
  태워야** 캐릭터에서 떨어져 남지 않는다. `player_visual_rect` 를 물려받는
  장식(퍽 파츠·소켓 글로우·커스터마이즈 오버레이)은 자동으로 따라온다.
- 스프라이트를 보스 위치에 그리는 분기(바이퍼 베놈 엣지 도착/참격)는 **보정
  제외** — 안 그러면 장식 레이어만 엉뚱하게 밀린다.
- ⚠️⚠️**회전은 축정렬 인셋으로 못 막는다.** `_draw_rotated_texture_region` 은
  **rect 중심 기준**으로 돌리므로, 회전 후 실제 opaque 픽셀은 축정렬 인셋 바깥으로
  나간다(바이퍼 투척 시트 30°에서 1배 33px / 2배 66px 실측). 내용 박스를 중심 기준
  회전시킨 **AABB** 로 판정해야 하고, 그러려면 가로뿐 아니라 **세로 여백**도
  필요하다(회전이 세로 크기를 가로 도달거리로 바꾸므로). 회전 소스는 투척 포즈
  (`active_item_throw_windup_angle_degrees`, 30°~-20°)와
  `viper_skill_context_builder` 의 코어 플립·블레이드 두 갈래다 — 투척은
  `sprite_context` 에 **나중에** 얹히므로 클램프 쪽에서 같은 조건으로 재구성해야
  한다.
- ⚠️⚠️**시간 기반 프레임 시트는 앵커 조회와 draw 가 다른 프레임을 고른다.** 호버 /
  벽비행 / 플라잉킥 등 9개 region 헬퍼가 `Time.get_ticks_msec()` 를 호출 시점마다
  읽는데, `resolve_current_sprite()`(앵커 조회)와 `draw()` 는 별도 호출이라 70/80/
  100ms 경계를 사이에 두면 서로 다른 셀을 고른다 → 그 차이만큼 새거나 뜬다(벽비행
  1배 2px / 2배 4px). 프레임당 한 번 샘플한 `player_sprite_sample_msec` 를
  컨텍스트에 실어 두 호출이 같은 값을 보게 하라. 씰은 "샘플을 고정하면 조회가
  불변" + "샘플을 바꾸면 프레임이 따라온다"(값이 실제로 소비되는 대조군) 두 방향을
  모두 단언해야 한다.
- ⚠️**슬라이드 계산 뒤에 얹히는 x 변형이 벽 경계를 다시 깬다.** 벽 슬라이드는
  draw size가 확정되는 시점에 계산되는데, 그 아래에서 타격 런지(`player_hit_side`
  × 14px)와 듀얼 글리치 startup 흔들림(±3px)이 최종 rect에 더해진다 → 벽에서
  바깥쪽 타격이 앵커를 14px 밀어낸다. **최종 합성 rect에 `clamp_body_inside_walls`
  를 걸어라**(글리치 흔들림 적용 **뒤**). 안쪽 런지는 작가 모션이므로 건드리지
  않는 한쪽 클램프여야 하고, 화면 셰이크는 벽도 같이 흔드니 판정에서 뺀다.

**씰 주의 (공허 GREEN 2종).**
1. 오프셋을 **계산만 하고 draw rect 에 안 더해도** "오프셋 값" 단언은 통과한다.
   렌더러가 기록한 **최종 rect**(`last_player_visual_rect`)로 "그림 모서리가
   벽선에 닿는가"를 단언해야 합성 한 줄 누락이 잡힌다.
2. 헬퍼를 직접 부르는 레그만 두면 draw 경로를 안 탄다. 씰은 공개 `draw()` 를
   관통해야 하는데, 렌더러는 실제 `_draw()` 안에서만 캔버스를 그릴 수 있으므로
   `canvas.draw` 시그널 + `queue_redraw()` 로 몰아라(헤드리스에서도 발화한다).
   ⚠️**GDScript 람다는 값 캡처**다 — 콜백에 넘길 컨텍스트를 지역 변수 재대입으로
   바꾸면 콜백은 옛 값을 계속 본다. 반드시 멤버를 통해 넘겨라.
3. 대조군 필수: 보정을 끈 상태에서 틈이 배율에 **비례해 커지는지**(1.0/1.5/2.0배)
   먼저 단언하라. 안 그러면 픽스처가 무효인데도 "틈 0" 레그가 통과한다.
4. **자기순환 주의.** 라이브 레그가 기대 인셋을 생성 표에서 읽어오면 표가 통째로
   틀려도 통과한다(렌더러와 단언이 같은 값을 쓰므로). 최소 1~2장은 실제 PNG
   픽셀에서 앵커를 **독립 재측정**해 표와 대조하라 — 생성기 회귀와 표 손편집이
   여기서만 잡힌다. `texture.get_image()` 결과는 `is_compressed()` 이면
   `decompress()` 가 필요하다.
5. 타격 레그는 런지가 실제로 0이 아님을 **중앙부 대조군**으로 먼저 증명하라.
   런지가 0이면 타격 레그는 유휴 레그와 동일해져 클램프를 전혀 검증하지 못한다
   (`player_hit_timer == duration` 일 때가 progress 0 = 최대 런지).
6. **좌/우는 별개 생산 경로다.** 이동 레그를 좌측 벽에서만 돌리고 "매트릭스 완비"로
   보고하지 마라. 그리고 방향 슬롯을 **한쪽만** 채우면(`player_walk_left_texture`
   만) 렌더러가 `player_walk_direction` 을 무시해도 같은 텍스처가 나와 레그가
   공허해진다 — 좌/우 시트를 **둘 다** 싣고, 인셋 차이가 1px 수준이라 변별력이
   없으므로 `resolve_current_sprite()` 가 **방향에 맞는 텍스처를 골랐는지**를
   직접 단언하라(방향 상수를 한쪽으로 고정하는 반증 토글로 확인).

---

<a id="grt-056"></a>
## Godot 바닥밀착 패들 지면 VFX 트랩 (회전한 쿼드는 클램프를 뚫는다)

**사고 (2026-08-02, 스매셔 경신보).** 발동/지속 VFX가 "허접하다"는 신고. 원인은
튜닝이 아니라 접근이었다. 전체가 `draw_line` + `draw_arc` + 범용 링 텍스처, 즉
**절차적 프리미티브가 주역**이었고 — 이건 월담야습에서 이미 한 번 반려된 패턴이다
([[Godot `draw_line`에는 라인 캡이 없다]] · [[Godot VFX 리브랜드 발광 예산 트랩]]).
구체 증상 6가지:

1. 8갈래 균열이 `TAU*(i+0.12)/8` **45° 등간격** — `sin(i*2.17)*0.28`(최대 16°)
   흔들기로는 격자가 안 깨져 자전거 바퀴살로 읽힌다. "바퀴살처럼 안 보이게
   조정했다"는 자기보고를 **캡처가 반증했다.**
2. 균열이 등폭 2세그먼트 폴리라인 + `width+3.0` 언더글로우 → 버트캡 사각 막대.
   균열은 뿌리가 굵고 끝이 뾰족해야 균열로 읽힌다.
3. 지속 알파가 0.13 / 0.16 / 0.27, 호가 0.25→0.16 — 어두운 플레이필드에서
   **긁힌 자국** 수준.
4. 전부 아웃라인이라 **질량 0**. 채워진 덩어리·연기·흙먼지가 한 겹도 없다.
5. 화면 바닥에 반쯤 잘림(아래 참조).
6. 컨셉 부재 — 경공(輕身步)인데 초록 SF 충격파. 기 흐름·발밑 잔영·도포 자락·
   흙먼지 같은 무협 어휘가 0.

### 지면 VFX 배치 규칙 (이 저장소의 카메라 전제)

플레이어 패들 **밑면은 750 바닥에 딱 붙어 있다.** 즉 "발밑"에 그릴 지면이
**존재하지 않는다.** 그래서 지면 계열(보법진 · 균열 · 흙먼지)은:

- **넓고 납작하게** 눕힌다(aspect 0.30 전후). 세로로 세우면 무조건 잘린다.
- 중심을 `min(anchor_y, FIELD_BOTTOM_Y - height*0.5)` 로 들어 올려 바닥선에서
  끝나게 한다.
- ⭐**`height` 에는 회전을 반영한 실제 세로 폭을 넣어라**
  (`|w·sin θ| + |h·cos θ|`). 축정렬 `size.y` 로 재면 **기울어진 쿼드가 클램프를
  통째로 뚫는다** — 235x70 납작 타원을 46° 돌리면 세로 폭이 70 → 217 로 3배가
  되어 바닥 아래로 하관이 잘려 나간다. 코드만 보면 클램프가 걸려 있어 정상으로
  보이고, **라이브 픽셀 캡처로만 잡힌다.**
- 지면에 **누워 있는** 진/디스크는 애초에 쿼드를 돌리지 마라. 회전은 **UV 로만**
  걸어라(`draw_polygon` 의 uv 4점을 (0.5,0.5) 기준 회전). 텍스처 마진이 완전
  투명이면 [0,1] 밖으로 도는 코너는 투명 에지 텍셀을 물어 사각 박스도 안 남는다.
  단 링 외접원이 UV 정사각 안에 들어와야 하므로 알파 bbox 는 ~0.86 이하로 유지.

### 씰

- 라이브 픽셀 씰에서 **최하단 행(749)의 lit 픽셀 수 == 0** 을 단언한다. 클램프를
  풀면 0 → 96 으로 튄다(실측). ⚠️흩날리는 **불티/충격환은 바닥선을 지나가는 게
  정상**이라 발동 프레임은 소수 점을 면제하고(<60) 균열 몸통이 만드는 수백 px
  띠와 변별한다.
- 질량 담당(흙먼지)은 **jade 카운터에 안 잡힌다** — 옥빛이 아니라 중성-온기 톤이라
  `r/g ≈ 0.96`, 기류(0.55)·보법진(0.42)·균열(0.62)과 깨끗이 갈린다. 별도
  `r ≈ g and b < g` 카운터로 세고, 레이어를 빼면 581 → 2 로 떨어져 변별된다.
- ⚠️먹빛 획이 섞인 아트는 **한 겹만으로는 발광이 죽는다.** 밝은 획만 살려 올리는
  **한 겹을 덧대라**(본체 + 블룸).
- 프리웜 사다리(`match _prewarm_step_index`)에 **번호 구멍**이 생기면 그 인덱스가
  `_:` 로 떨어져 **남은 단계 전부를 조용히 건너뛰고** `true` 를 반환한다 — 뒤쪽
  캐시가 핫패스에서 지연 생성된다. 완료까지의 **스텝 수**를 단언해 막아라.

### ⭐동반 발견: immediate `_draw()` 안의 `canvas.material` 스왑은 no-op다

`var prev = canvas.material; canvas.material = mat; canvas.draw_*(...);
canvas.material = prev` — 이 "1패스 머터리얼 스왑"은 **공용 캔버스에 immediate
로 그릴 때 커맨드 단위로 적용되지 않는다.** 머터리얼은 **CanvasItem 단위
속성**이라 마지막 대입만 남고, 결과적으로 전 커맨드가 캔버스 원래 머터리얼로
그려진다.

**증명 (2026-08-02).** 경신보 라이트 레이어의 `LIGHT_BLEND_MODE` 를 ADD ↔ MIX 로
뒤집고 같은 픽셀 씰을 돌렸더니 `jade=9261 / dust=581 / rupture=10275` 가 **세 지표
모두 자릿수까지 동일**했다. 머터리얼 기계를 통째로 걷어낸 뒤에도 같은 수치가
나왔다 = 처음부터 죽은 배선이었다.

- ⚠️**"레포에 같은 패턴이 여러 군데 있다"는 근거가 안 된다.** 동작하는 사례
  (`viper_wall_leap_blast_fx_host.gd`)는 레이어가 **각자 머터리얼을 가진 `Sprite2D`
  자식**이라 동작하는 것이지, 스왑이 먹어서가 아니다. 자식 CanvasItem 이 아닌
  immediate 드로우 사이트의 스왑은 전부 의심하라.
- 진짜 가산이 필요하면 **자기 머터리얼을 가진 자식 CanvasItem 호스트**를 써야
  하고, 배틀 씬은 CanvasLayer 없는 단일 Node2D 라 자식 z-슬롯 제약을 같이 풀어야
  한다(게임플레이 뒤 or 캐릭터 앞만 가능).
- 그 전까지는 **전부 MIX 로 합성된다는 전제로 알파/명도를 맞추고**, 계약 문구도
  거기에 맞춰라. status dict 에 `blend_mode: "add"` 를 실어 두면 스모크는 GREEN
  인데 화면은 MIX인 **거짓 계약**이 된다.
- 씰은 소스 단언(`canvas.material =` 부재) + 합성 계약 상수로 건다.

<a id="grt-036"></a>
## Godot 벤더 WAV 컨테이너 결함 트랩 (임포트는 되는데 매 로드마다 경고 → 러너 RED)

상용 사운드 라이브러리(Epidemic Sound 등)에서 받은 WAV 는 오디오 자체는
멀쩡해도 컨테이너가 더러운 경우가 흔하다. 확인된 결함 2종:

1. **RIFF 총크기 필드 과대 선언** — 헤더가 선언한 총 바이트가 실제 파일보다
   크다(허공환영 발사 블라스트: 선언 1,266,616 vs 실제 1,263,176). Godot 은
   임포트/로드는 해 주지만 `File size ... is smaller than the expected size`
   WARNING 을 **스트림을 로드할 때마다**(임포트, 프리웜, load_audio_stream 씰)
   반복해서 뿜고, 표준 러너 `run_smoke_tests.ps1` 는 엔진 WARNING/ERROR 를
   실패로 승격하므로 **관련 스모크 배치가 통째로 RED** 가 된다.
2. **거대 트레일링 메타데이터 청크** — `data` 뒤에 붙는 1MB급 `ID3 `(앨범아트),
   `bext`/`iXML`/`SMED` 등. 재생엔 무의미한 저장소 비대.

표준 조치는 **러너 억제가 아니라 에셋 인테이크 시점의 컨테이너 수리**다:
청크를 파싱해(`fmt `/`bext`/`data` 유지) `data` 청크 끝에서 파일을 자르고
RIFF 크기 필드를 `실제 파일길이 − 8` 로 재기록한다(오디오 바이트 무손실).
PowerShell .NET 바이트 편집이면 충분하다 — 허공환영 발사 WAV 수리가 참조
사례(1.26MB → 226KB, 경고 소멸). 새 WAV 를 에셋 트리에 넣을 때는 헤더를
파싱해 RIFF 총크기와 실제 크기가 일치하는지 먼저 보고, 편입 직후
`--headless --import` 1회 + 관련 오디오 오너 스모크(스트림 로드 씰 포함)로
경고 부재까지 확인한다. ⚠️PS 5.1 에서 `godot --import 2>&1` 은 첫 stderr
줄이 NativeCommandError 로 승격돼 임포트 프로세스가 **중간에 죽는다** —
리다이렉션 없이 실행하라.

<a id="grt-058"></a>
## Godot 물리차단 모달 개폐 계약 트랩 (새 진입점은 형제 모달의 훅을 상속하지 않는다)

**사건 (2026-08-07, 신비의 주사위 → 액티브 아이템 전환).** 퍽 선택 카드였던
신비의 주사위를 액티브 아이템으로 옮기면서, 아이템 사용 시 같은 모달을 여는
새 진입점 `begin_active_item_modal_from_runtime_state`를 추가했다. 모달 자체는
`is_choice_active()`에 OR로 물려 물리 차단·입력 라우팅·오버레이 드로·승리
전리품 페이즈 보류를 전부 정상 상속했다. 그런데 **개폐 훅 두 개를 상속하지
못했다.**

형제 모달 두 개는 열 때·닫을 때 같은 쌍을 부른다:
- 퍽 선택: `runtime_perk_choice_open_flow.gd` → `_pause_skill_cooldowns_for_choice`,
  `runtime_perk_choice_finish_flow.gd` → `_resume_skill_cooldowns_for_choice`
  + `_try_arm_resume_safety`
- 천사의 축복: `runtime_perk_angel_blessing_runtime_state.gd` 214 / 390~391 동일 쌍

아이템 경로는 둘 다 호출하지 않았고, 결과는 두 가지다.

1. **쿨다운 실시간 누수(익스플로잇).** `battle_scene_skill_tooltip_driver.
   pause_skill_cooldowns`는 캐릭터 스킬 쿨다운뿐 아니라 **액티브 아이템
   쿨다운까지** 멈춘다(`_pause_active_item_cooldowns`). 물리는 모달 게이트가
   막지만 아이템 쿨다운 기준선은 벽시계(`Time.get_ticks_msec()`,
   `active_item_slot_controller._try_use_slot`)다. 굴림 연출 + 리롤 2회 + 7행
   판독이면 기본 액티브 쿨다운 7000ms를 쉽게 넘겨, 모달을 여는 것만으로 다른
   아이템·스킬 쿨다운이 공짜로 리셋된다.
2. **회피 불가 실점.** `runtime_perk_resume_safety.try_arm`은 프리즈 10프레임
   + 60프레임 속도 복원 + 프리즈 중 실점 차단을 건다. 퍽 모달은 득점·스타포인트
   같은 통제된 순간에만 열리지만 **아이템은 랠리 임의 프레임에 쓸 수 있다** —
   공이 바닥 직전일 때 열고 몇 초 뒤 커밋하면 풀속도로 즉시 재개된다.

**표준 규칙.** 물리를 차단하는 모달을 여는 **새 진입점**을 추가할 때는,
그 모달이 이미 존재하더라도 형제 진입점의 개폐 훅을 전수 대조하라. 모달
활성 플래그를 `is_choice_active()`에 OR로 다는 것은 **차단·라우팅만** 상속시키고
**개폐 부수효과는 상속시키지 않는다**. 최소 점검 항목:
- 열 때 `_pause_skill_cooldowns_for_choice(owner, registry)` (벽시계 쿨다운 정지)
- 닫을 때 `_resume_skill_cooldowns_for_choice()` + `_try_arm_resume_safety(owner, registry)`
- 비정상 teardown 경로에서 pause 가 새지 않는지(새-런 리셋 파사드가 이미
  resume 을 선행 호출하는지 확인). pause 헬퍼는 owner/registry 를 자기 안에
  보관하므로 resume 은 인자를 받지 않고, 미무장 상태에서는 양쪽 다 no-op 이다.
- `has_method` 게이트 뒤 동적 호출이면 **인자수를 실 시그니처와 대조**
  (pause 2 / resume 0 / arm 2) — 파서가 검증하지 못한다.

**씰.** 호출 카운트만 세는 Fake 씰은 공허-GREEN 위험이 있다. 실물
`RuntimePerkResumeSafety`를 물려 **결과로** 단언하라(커밋 후 `ball_vel ==
Vector2.ZERO`, `perk_resume_score_blocking == true`, 원속 기억). 실경로 pause 는
레지스트리에 `battle_scene_skill_tooltip_driver` 페이크를 세워야 실제로 걸린다
— 안 세우면 `pause()`가 조용히 조기 반환해 또 공허-GREEN 이다. 봉인:
`mystic_dice_active_item_smoke.gd`.

⚠️동반: 트리 밖 `Node` 픽스처에 `queue_free()`를 쓰면 SceneTree 프레임을
기다리다 `quit()`이 먼저 나가 노드와 그 스크립트 리소스가 남고, 표준 러너가
`ObjectDB instances leaked` / `resources still in use`를 실패로 승격한다
(씰은 `ok`를 찍는데 러너는 RED). `free()`를 쓰고, `_run()` 말미에
`await process_frame` 한 번을 둬라.

⚠️서비스 레지스트리 픽스처는 노드 정리와 별도다. `FakeRegistry.instances`가
`RefCounted` 런타임을 소유하고 그 런타임이 표시/스킬 컨텍스트로 registry를 다시
보관하면, 로컬 변수가 스코프를 벗어나도 `registry ↔ runtime` 순환이 남는다.
실제 `battle_scene_teardown_lifecycle`가 `registry.clear_all()`을 호출하는 것처럼
가짜 레지스트리에도 `clear_all()`을 두고 픽스처 종료 전에 호출하라. `reset()`이나
프레임 대기만으로 이 소유권 순환을 덮지 말고 `expect-zero-object-leaks`로 봉인한다.

### 동반 트랩: 쿨다운만 멈추는 것으로는 부족하다 — 벽시계 **발동창**도 멈춰야 한다

**사건 (2026-08-08, 풍운천선무).** 초식 발동 중 스타포인트를 먹어 퍽을 고르고
나오면 모션이 이미 끝나 있었다. 발동창은 `end_msec = start_msec +
DURATION_MSEC(1200)`(컷인 시 +1650) **벽시계** 앵커인데, 모달은 물리 프레임만
막고 벽시계는 못 막는다 → 고르는 몇 초 사이에 창이 지나가고 모달이 닫히는
프레임에 `_expire_if_needed`가 즉시 만료시킨다. `pause_skill_cooldowns`는
이름 그대로 **쿨다운 앵커만** 민다(`smasher_skill_state.cooldowns`) — 발동창·
입력창·예약 시각은 별개다.

**표준 규칙.** 모달 개폐 팬아웃은 `battle_scene_skill_tooltip_driver`의
`_pause_runtime_perk_modal_time` / `_resume_runtime_perk_modal_time` 한 곳이고,
등재는 **양쪽**이 필요하다: (a) 드라이버의 `RUNTIME_PERK_MODAL_TIME_STATE_KEYS`에
레지스트리 키, (b) 그 상태에 `pause_runtime_perk_modal_time` /
`resume_runtime_perk_modal_time`. **둘 중 하나만 하면 `has_method` 게이트가
조용히 no-op** 이다(리프만 있고 호출자가 없어 기능 전체가 죽어 있던 것이 이
사건의 실제 상태였다). 공용 헬퍼 = `runtime_perk_modal_time_shift.gd`.

- ⚠️**시각(anchor)만 밀고 길이(duration)는 절대 밀지 마라.** `windup_msec` /
  `cooldown_msec` / `switch_debounce_msec` / `duration_msec` 를 같이 밀면
  지속시간이 모달 길이만큼 늘어난다. 그래서 dict 키 목록은 "`_msec`로 끝나는
  전부"가 아니라 **명시 화이트리스트**다.
- ⚠️**시드는 앵커가 아니다.** `smasher_ghost_shot_state.start_msec` 는
  `_seeded_rng(start_msec + ...)` 의 시드라 밀면 순간이동 패턴이 비행 도중
  바뀐다. 소비처를 grep 해 "경과 비교"에 쓰이는지 확인하고 고를 것.
- ⚠️**델타 앵커를 빼먹으면 재개 첫 프레임이 튄다.** `last_update_msec` 처럼
  `now - anchor` 로 이동량을 만드는 값은 만료 앵커와 함께 밀어야 한다
  (실드카이팅 방패가 모달 길이만큼 순간이동).
- ⚠️**읽기가 상태를 바꾸는 질의**는 정지 중 얼어붙은 시각으로 답해야 한다.
  `viper_skill_runtime._is_core_flip_ready_window_active` 는 만료 시
  `core_flip_ready_msec = 0` 을 써버리는데, 모달 중에도 HUD 스냅샷이 실시간으로
  묻기 때문에 그대로 두면 화랑킥 창이 **영구 삭제**된다.
- **모듈 조회는 비-생성 peek(`get_cached_instance`)만.** `get_instance` 를 쓰면
  아직 안 쓴 캐릭터·아이템 모듈까지 모달 여는 프레임에 콜드 생성된다. 인스턴스가
  없다 = 밀어야 할 살아있는 타이머도 없다.
- 라운드 리셋 경로에서 정지 마커를 반드시 버릴 것(앵커가 지워진 뒤 남은 마커는
  새 라운드 상태를 엉뚱하게 민다).

**기록된 설계 결정 (2026-08-08 사용자 확정).** 커맨드 버퍼(`smasher_wheel`
A→W→D 600ms, 바이퍼 `dual_glitch` / `chaos`)도 **같이 민다** = "모달은 게임
시간상 없던 일". 비자발적 중단으로 의도한 입력을 잃지 않는 쪽을 택했다.
트레이드오프는 인지하고 있다: `A`/`D`가 평소 이동키라, 모달 직후 남은 창
(최대 600ms) 안에 이동하려고 누르면 늦은 발동이 날 수 있다. **되돌리려는
시도 전에 이 항목을 먼저 볼 것** — felt-gap 리포트는 방향 결정이 아니다.

**씰.** `runtime_perk_modal_wall_clock_pause_smoke.gd`. 리프를 직접 부르는
레그만으로는 **최상위 배선이 무방비**다(팬아웃 호출 한 줄이 빠져도 GREEN) —
실제 진입점 `pause_skill_cooldowns` / `resume_skill_cooldowns` 관통 레그와,
`collect_star_points → choose_selected` 실경로 레그를 함께 둘 것. 실경로 레그는
스모크가 수 초를 기다릴 수 없으므로 모달을 연 뒤 정지 마커를 되감아 긴 모달을
재현하고 `end_msec` 증가분을 단언한다. 페이크 레지스트리는 `get_cached_instance`
만 노출해 peek 분기를 강제하고, `get_instance` 호출 키를 기록해 콜드 생성으로
새지 않는지 본다.

<a id="grt-050"></a>
## Godot 커맨드-버퍼 스킬 활성화 게이트 트랩 (막힌 게이트는 입력을 버리지 않고 미룬다)

**증상.** "스킬을 분명 일찍 눌렀는데 **늦게** 터진다" — 눌린 적 없는 게 아니라
게이트가 열리는 프레임에 지연 발동한다. 리포트 원본(2026-08-08): 한미량 흡인장
(`magnum_grip`)으로 공을 끌어오는 중 A-W-D 를 입력했더니 풍운천선무
(`smasher_wheel`)가 **공이 패들에 맞고 난 뒤에** 발동했다.

**기전.** `smasher_wheel_state.update_input` 의 순서가
`_update_command_buffer()` → `_can_activate()` 조기 return →
`_consume_command_direction()` 이다. 게이트(`_is_input_blocked`)가 닫혀 있으면
**소비 전에** 빠져나가므로 A-W-D 시퀀스는 버퍼에 그대로 살아남고
(`COMMAND_WINDOW_MSEC` 600 / 트림은 그 3배), 게이트가 열리는 첫 프레임에
소비된다. 흡인장의 해제 조건은 `apply_ball_motion` 의
`_player_intersects_ball` = **공이 패들에 닿는 순간**이라, 지연 발동 시점이
정확히 "타격 직후"로 고정됐다. 무에러·기존 씰 전부 GREEN.

**표준 규칙.**
- 커맨드-버퍼 스킬에 활성화 게이트를 걸 때는 **버릴 것인가 미룰 것인가**를
  명시하라. "미룸"이 기본값이 되면, 게이트 해제 조건이 곧 발동 타이밍이 된다 —
  게이트 소유자의 해제 시점이 플레이어가 의도한 타이밍과 다르면 그건 버그다.
  버려야 하면 게이트 분기에서 `command_buffer.clear()` 까지 해라(활성 중 분기는
  이미 그렇게 한다).
- 콤보 **시동기** 성격의 스킬은 후속기의 발동 게이트에 올리지 마라. 시동기가
  후속기를 막으면 콤보가 구조적으로 성립할 수 없다.
- 원본 `pingfighter.py` 에 같은 게이트가 있어도(여기선 `wheel_start_blocked` 에
  `magnum_grip_active` 포함) 그건 파리티 근거일 뿐 정합성 근거가 아니다.
  체감 리포트가 오면 파리티가 아니라 **설계 의도**를 먼저 물어라.

**동반 트랩 — 공 조종 스킬 2개를 겹치게 허용하면 인계 지점이 필수다.**
게이트를 풀어 두 스킬이 동시에 살 수 있게 되면, 볼 파이프라인 **호출 순서**가
결과를 정한다: `ball_update_controller` 에서 `apply_magnum_grip` 은 :115,
천선무 자체 충돌 `apply_smasher_wheel_collision` 은 :171 — 흡인장이 **먼저**
돈다. 천선무가 공을 쳐낸 뒤에도 흡인장이 살아 있으면 60짜리 반격을 매 프레임
패들 쪽으로 되끈다. 흡인장의 자체 해제는 **패딩 없는** 패들 rect 교차인데
천선무 충돌 rect 는 `hitbox_padding` 을 먹으므로, 천선무가 먼저 먹은 프레임에는
아직 안 풀린다 → 명시적 인계가 없으면 반드시 샌다.
- 인계는 **정본 한 곳**에 둬라. `consume_ball_hit` 은 두 진입점
  (`resolve_ball_collision` / `paddle_bounce_post_hit_handler`)이 모두 지나므로
  거기가 정본이다(`_release_magnum_grip_on_hit`).
- 인계 순서는 기존 정상 경로와 **같게**:
  `paddle_bounce_player_post_hit_handler` 는 `consume_release_hit_speed_cap()`
  → `deactivate()` 다. `consume` 을 빼고 `deactivate` 만 하면
  `get_pending_release_hit_speed_cap()` 이 45 를 계속 돌려줘 랠리 내내 전역
  속도 캡 바닥이 45 로 남는다(캡은 `max()` 합성이라 조용히 샌다).

**씰.** `smasher_wheel_magnum_grip_combo_smoke.gd`.
- 발동 레그: 흡인장 `is_active()` 인 상태에서 A-W-D 3프레임 → **완성 프레임에**
  `activated` + `is_active()` + 기력 240 소모. 발동만으로 흡인장이 꺼지지 않는
  것(= 타격까지 계속 끌어당김)도 같이 단언.
- 인계 레그는 **플래그가 아니라 속도 결과**로: `consume_ball_hit` 뒤
  `BallFrameMotionController.apply_magnum_grip` 을 실제로 돌려 `ball_vel` 불변.
  ⚠️공은 패들 rect **위**에 띄워라 — 겹치면 흡인장이 자기해제로 통과해 버려
  인계를 안 재는 공허-GREEN 이 된다.
- **대조군 레그 필수**: 인계 안 된 흡인장이 같은 호출에서 실제로 `ball_vel.y` 를
  키우는(되끄는) 것까지 단언해야 위 "불변" 단언에 변별력이 생긴다.

<a id="grt-035"></a>
## Godot 공유 큐 목록 삽입 × 형제 씰 절대-인덱스 트랩 (배치가 첫 실패에서 끊긴다)

**사건.** 캐릭터 정보창 TAB 효과음을 붙이면서 `game_ui_feedback_audio.gd` 의
`CUE_IDS` 에 5번째 큐(`character_info_toggle`)를 **맨 뒤에** 추가했다. 이 목록은
`setup()` / `get_sfx_bus_players()` / `get_prewarm_stream_paths()` 세 곳이 순회하고,
`GameAudio._setup_core_ball_sfx()` 는 `game_ui_feedback_audio.setup()` →
`core_ball_dash_audio.setup()` 순서라 UI 큐가 항상 머리에 온다. 그래서 큐가 하나
늘자 `PaddleHitSfx` 의 인덱스가 4 → 5 로 밀렸다.

문제는 형제 씰 `game_audio_core_ball_dash_audio_owner_smoke.gd` 가 그 오프셋을
**절대값으로 굳혀** 두었다는 것이다 — `setup_start == 4`,
`names[setup_start - 1] == "UiPerkSelectSfx"`, `prewarm_start == 4`,
`sfx_players.find(players[0]) == sfx_players.find(audio.ui_perk_select_sfx) + 1`.
네 줄이 동시에 실패했다.

**진짜 피해는 그 씰 하나가 아니다.** `godot/tools/run_smoke_tests.ps1` 은
`$ErrorActionPreference = "Stop"` + 실패 시 `throw` 라서 **첫 실패에서 foreach 가
끊긴다**. 파일명 정렬상
`game_audio_core_ball_dash_audio_owner_smoke.gd` <
`game_audio_ui_feedback_audio_owner_smoke.gd` / `game_audio_ui_sfx_smoke.gd`
이므로, 새 기능의 SFX 버스 라우팅·프리웜 등재를 봉인하는 두 씰을 포함해
**알파벳순 뒤쪽 수백 개가 단 한 번도 실행되지 않았다**. 로컬 pre-push 게이트
(`run_pre_push_checks.ps1` 의 인자 없는 전체 글롭)도 같은 지점에서 죽는다.
작업자는 "관련 스모크 통과"를 보고했지만, 그 근거 중 일부는 애초에 돌지 않았다.

**표준 규칙.**
- 공유 큐/스펙/슬롯 **목록에 항목을 추가하면**, 그 목록을 순회하는 소비자
  (`setup` / `get_*_players` / `get_prewarm_*`)의 산출 **순서에 의존하는 형제
  씰을 전수 grep** 하라. 검색 키는 플래그가 아니라 **밀리는 심볼**
  (`PaddleHitSfx`, `ui_perk_select_sfx` 등)이다.
- 씰의 순서 앵커는 **실계산**으로 잡아라. `== 4` 가 아니라
  `== audio.game_ui_feedback_audio.get_cue_ids().size()`, 이웃 이름도
  `"UiPerkSelectSfx"` 리터럴이 아니라 `get_spec(ui_ids[-1])["player_name"]`.
  절대 인덱스는 "순서 계약"이 아니라 "현재 개수"를 굳힌 것이라 계약을 지키지
  못한다.
- 다만 앵커를 상대화한 뒤에는 **변별력이 남았는지 반증검증**하라 —
  `_setup_core_ball_sfx()` 의 UI/코어 setup 두 줄을 in-place 로 뒤집어 RED 가
  뜨는지 확인한다(뒤집힌 상태로 GREEN 이면 앵커가 항등식이 된 것이다).
- **배치가 죽으면 뒤 항목을 통과로 세지 마라.** 러너 출력은 마지막
  `All Godot smoke tests passed.` 한 줄까지 확인해야 하고, 그게 없으면
  "N개 통과"가 아니라 "첫 실패 지점까지만 실행"이다. (룰 상수 파생-임계값
  트랩에도 같은 문장이 있다 — 이 트랩은 그 원인 유형 하나를 특정한 것이다.)
- 절대 인덱스를 쓰는 씰이 이 저장소에 또 있는지 의심되면
  `rg -n "== [0-9]+, \"" godot/tests` 로 훑고, 그 숫자가 **다른 목록의 길이에서
  파생된 값**이면 실계산으로 바꿔라.

**동반 규칙 (같은 슬라이스에서 나온 것).** 공유 오버레이의 **개폐 부수효과**는
호스트별 라우터가 아니라 오버레이 정본(`CharacterInfoOverlay.open()`)이 소유해야
한다. 전투 TAB 라우터에만 열기 큐를 달았더니 광장 TAB 과 일시정지 메뉴 진입은
무음인데 닫기 소리만 나는 비대칭이 됐다(닫기 큐는 공용 입력 핸들러에 있었기
때문). 반대로 **닫기** 큐는 입력 종류를 구분해야 하므로(TAB 만, ESC·폐기 확인
취소·드래그 취소·닫히는 중 반복 TAB 은 무음) 입력 핸들러가 계속 소유한다.
⚠️그 무음 계약의 씰은 **부정 레그**가 없으면 공허-GREEN 이다 — 씰이 `KEY_TAB`
이벤트만 만들면 `is_tab` 가드와 하위 모달 조기 return 두 개를 통째로 지워도
배치가 전부 GREEN 으로 남는다. 반드시 ESC 이벤트, `_discard_confirm` 활성
픽스처, `_drag_active` 상태 각각에서 **큐 카운트 불변 + 그 취소가 실제로
일어났음**을 함께 단언하라.

<a id="grt-029"></a>
## Godot 공유 파티클 배열 꼬리-윈도우 렌더 컷 × 스폰 순서 트랩

**사건 (2026-08-09, 벽력타 마찰 방전).** 벽력타 발동 VFX 를 공유
`energy_explosion_particles` 배열에 새로 얹으면서 "중요한 것부터 쌓는다"는
직관대로 코어 플래시 → 뇌전 가닥 → 스파크 순으로 append 했다. 유닛 단언은 전부
통과하고 일반 화면에서도 멀쩡했지만, severe LOD 프레임에서 **정체성인 뇌전이
통째로 사라졌다.**

**메커니즘.** `ball_effects_renderer._draw_energy_explosion_particles` 는 배열
앞에서가 아니라 **뒤에서** `render_limit` 개만 그린다:

```gdscript
var particle_start: int = max(0, particles.size() - render_limit)
for particle_index in range(particle_start, particles.size()):
```

즉 **배열 앞쪽 = 먼저 잘리는 자리**다. 캡 초과분을 `pop_front` 로 버리는
`_trim_energy_particles` 도 같은 방향이라, 한 번의 스폰 안에서
**먼저 append 한 것이 렌더 컷과 캡 컷 양쪽에서 먼저 죽는다.** 예산은
`_scaled_limit(MAX_RENDERED_ENERGY_PARTICLES=22, lod_scale, 9)` 이고 severe LOD
에서 `SEVERE_LOD_ENERGY_PARTICLE_LIMIT=7` 로 조인다 — 22칸일 땐 한 벌이 딱
들어가서 **증상이 안 보이고**, 7칸에서만 드러난다.

**표준 규칙.**
- 공유 파티클 배열에 한 효과의 여러 레이어를 쌓을 땐 **스폰 순서 = 생존
  우선순위**로 잡아라. 버려도 되는 잔량(스파크) 먼저, 정체성 레이어(번개 가닥,
  코어 플래시) 나중. 드로우 순서도 같은 방향이라 정체성이 위에 얹히는
  부수효과까지 맞아떨어진다.
- 씰은 **severe LOD 예산으로** 판정하라. 풀 예산은 효과 한 벌 크기와 같아
  변별력이 0이고, 순서를 뒤집어도 GREEN 이 나온다(실측: 22칸에서는 잘못된
  순서도 통과, 7칸에서 5/5 가 윈도우 밖으로 밀림). 레그에
  `particles.size() > render_limit` 사전조건을 박아 두면 나중에 예산/스폰량이
  바뀌어 다시 변별력 0이 되는 것을 잡는다.
- 예산 상수는 씰에 리터럴로 굳히지 말고 렌더러 const 를 읽어라
  (`BallEffectsRenderer.SEVERE_LOD_ENERGY_PARTICLE_LIMIT`).

**동반 트랩: 정지형 타입은 공유 update 이동 분기에서 빼야 한다.**
`impact_energy_effect_state.update()` 는 `type != "burst"` 인 모든 파티클을
이동 대상으로 보고 `p["vel"]` 을 **직접 인덱싱**한다. 접점 고정형 신규 타입
(`bolt`)은 `vel` 키가 없으므로 그 분기에 들어가는 순간
`Invalid access to property or key 'vel'` 로 그 프레임 update 가 죽는다. 새
정지형 타입은 반드시 그 조건에 등재하고, 씰은 **실 `effects.update(delta)`
틱을 관통**해 (a) 죽지 않고 (b) 위치가 안 움직이고 (c) 수명 뒤 정리되는지를
보라 — dict 를 직접 만드는 유닛 단언은 이 계약을 못 건드린다.

**반증검증 (둘 다 실측).** 이동 분기에서 `bolt` 제외를 빼면 예측한 그
`Invalid access ... 'vel'` 로 러너 RED. 스폰 순서를 스파크 마지막으로 뒤집으면
`뇌전 가닥 5개 중 5개가 렌더 윈도우(뒤 7칸) 밖으로 밀렸다` 로 RED.
씰: `smasher_drive_friction_arc_smoke.gd`.

<a id="grt-057"></a>
## Godot 페인티드 크롬 뒤 평면 헤일로 rect 트랩 (그림틀 투명 여백이 상자를 드러낸다)

**사건 (2026-08-09).** 캐릭터 선택 화면에서 "캐릭터 초상화 뒤에 사각형 파란색
박스 같은 게 보인다" 신고. 진범 = `character_select_screen._draw_character_card_
horizontal` 의 `draw_rect(rect.grow(6.0), Color(CHROME_GLOW…, 0.10))` 선택 헤일로.
이 드로는 카드가 **불투명 라운드 글래스 패널**이던 시절엔 카드 본체에 덮여
바깥 6px 링으로만 보였다. 환격전 리스킨이 그 자리를 **페인티드 9-patch 편액**
(`roster_card_selected_9p.png`)으로 바꾸면서, 아트의 투명 여백을 통해 헤일로가
그대로 드러나 하드엣지 청록 상자가 됐다.

**메커니즘.** 소스 845×389 의 알파 인셋 프로파일은 중앙 열 기준 상단 32 / 하단
10px 투명이지만, 유기적 테이퍼 때문에 좌우 끝 열은 top_inset 181 / bottom_inset
251 까지 벌어진다. 여기에 9-patch 압축(`vertical_scale = min(1, target.h /
(source_top + source_bottom))` = 130/184 = 0.707)이 겹쳐, 목표 rect 안에서도
투명 비율이 크다. 즉 `rect` 는 아트가 실제로 칠하는 영역보다 훨씬 넓고, 그
차집합 전체가 평면 필을 노출한다.

**같은 결함이 한 화면에 3곳 동시.** 로스터 카드(가로 `grow(6)` / 세로 `grow(8)`),
확정 CTA `_draw_button`(`grow(5)`, `select_button` 9-patch), 리그 탭
`_draw_league_button`(`grow(7)`, `league_*` 브러시 스와시). 하나를 고쳤으면
**같은 화면의 형제 콜사이트를 전수 조사**하라 — 크롬 아트 교체 슬라이스는 배경
드로를 콜사이트마다 따로 남기기 때문에 한 곳만 고치면 나머지가 그대로 남는다.
(반례로 `skill_socket` 은 여백 없는 정사각 텍스처라 무해했다 — "9-patch 를
쓰니까 전부 범인"이 아니라 **알파 인셋이 있는 것만** 범인이다.)

**표준 규칙.**
- 투명 여백을 가진 페인티드 텍스처 **뒤에 평면 rect 헤일로를 두지 마라.**
  평면 필은 그 텍스처가 없을 때의 **폴백 분기 안으로** 옮겨라(폴백은 불투명
  필/스타일박스라 원래 계약이 그대로 유지된다).
- 상태 표현은 실루엣을 따르는 수단으로: (a) 상태별 아트 스왑(idle/selected 시트),
  (b) `modulate` 리프트(호버 `Color(1.06, 1.06, 1.04)`), (c) 아트 **안쪽** 악센트
  (선택 화살표, 인장 글리프, 브러시 마크, 라벨 밝기).
- 새 크롬 PNG 를 배선할 때는 소스의 **알파 인셋 프로파일**(열/행별 첫 `alpha>32`)
  을 먼저 재고, 그 rect 뒤에 이미 있던 드로를 전수 재감사하라.

**판정은 픽셀로만 된다.** 드로 전용 결함이라 상태 스모크는 전부 GREEN 이다
(`character_select_info_panel_layout_smoke`, `..._preview_vfx_host_clip_smoke`
모두 통과한 채로 버그가 살아 있었다). 비헤드리스 실씬 캡처
(`godot/tools/character_select_slice_a_capture.gd`) 후 **헤일로 마진 픽셀 vs 박스
바깥 대조 픽셀**의 델타를 재라. 이 건의 실측: 카드 마진 `(26,37,38)` vs 대조
`(12,17,20)` → 델타 `(14,19,16)`, 예측 `CHROME_GLOW(0.61,0.82,0.72) × 255 × 0.10 =
(15.6,20.9,18.4)` 와 일치해 범인이 수치로 확정됐다. 수정 후 마진은 대조값
`(9,16,19)/(12,18,22)` 로 수렴(= 헤일로 기여 0). 인상 대신 이 델타 대조를 쓸 것.

**봉인 상태.** 자동 씰 없음 — SubViewport 렌더가 필요해 표준(헤드리스) 러너에
못 올린다. 회귀 판정은 위 캡처 하네스 재실행 + 델타 대조가 정본.
