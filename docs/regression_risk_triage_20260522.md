# Regression Risk Triage - 2026-05-22

Current target: Godot `godot/`. Legacy Python/Pygame files are frozen
reference unless explicitly requested.

## Current Sync Snapshot - 2026-05-24

This section was added to make the local triage log usable as cross-agent
evidence instead of relying on chat-only status summaries.

- Current branch: `checkpoint/godot-wip-20260521-070019`.
- Latest code / asset / smoke-fix HEAD before this documentation sync:
  `3315ea4aa godot: move mythic catalog builders into build router`.
- The checkpoint span through that HEAD contains 184 follow-up commits after
  the gamepad input boot baseline. Including `2c31069ba` itself, the span
  contains 185 commits.
- Latest docs-only guardrail sync before this addendum:
  `6622d30a0 docs: update godot port guardrails`.
- Latest docs-only validation sync before this addendum:
  `6a7ec1711 docs: record full smoke teardown signoff`.
- Latest docs-only mythic split sync before this addendum:
  `86531552c docs: record mythic icon hydration helper split`.
- Latest local-artifact ignore sync before this addendum:
  `a41efcb3c chore: ignore local stage2 asset drafts`.
- Latest residual settings hold note before this addendum:
  `2001105b6 docs: record final local settings hide`.
- Latest validated warning scan: `.\tools\run_warning_scan.ps1` from
  `godot/` passed on 2026-05-24 with `1288` scripts scanned and no GDScript
  warnings.
- Current dirty scope before this documentation sync: `git status
  --porcelain=v1 -uall` is clean.
- Final local cleanup action: applied `git update-index --skip-worktree` to
  `.claude/settings.json` and `.claude/sprite_workflow_settings.json`.
  After that local index hide, `git status --porcelain` is clean. To inspect
  or restore visibility, run `git ls-files -v -- .claude/settings.json
  .claude/sprite_workflow_settings.json` and then
  `git update-index --no-skip-worktree -- .claude/settings.json
  .claude/sprite_workflow_settings.json`.
- The split notes below are current through the 110th split. The broad
  smoke addenda below record validation-only asset / smoke fixes, teardown
  cleanup, and the first single uninterrupted 489-script smoke pass after that
  split. The top-level initial snapshot remains historical context from the
  first 2026-05-22 triage pass and should not be read as the current worktree
  size.

Open follow-ups before the next broad sign-off:

- Residual local settings files after the artifact-ignore sync are
  `.claude/settings.json` and `.claude/sprite_workflow_settings.json`.
  They are locally hidden with `skip-worktree`, not committed or reverted.
  `settings.json` contains local allowed-command / personal path / signed URL
  traces, and `sprite_workflow_settings.json` flips the repo default asset
  workflow mode from `fast` to `precise`. Keep both out of gameplay / docs
  refactor commits unless the user explicitly asks to change repo-wide tool
  policy.

Resolved follow-up in the latest pass:

- A single uninterrupted `.\tools\run_smoke_tests.ps1` pass from `godot/`
  completed all `489` smoke scripts and ended with
  `All Godot smoke tests passed.` No `ObjectDB instances leaked at exit`
  warning was observed in that final full pass.
- `da656fe70 godot: clean up smoke test teardown` resolves the known nonfatal
  `ObjectDB instances leaked at exit` cleanup follow-up for
  `boot_flow_bgm_toggle_smoke`, `commando_fullbody_live2d_smoke`,
  `game_audio_volume_settings_smoke`, and
  `main_menu_quit_confirmation_smoke`. The same focused verification set also
  reran `stage5_hongryun_visual_shell_smoke`; all five passed without the
  previous exit leak warning.
- `dbded6d8a godot: clean up main menu flow smoke teardown`,
  `3e1d1e2af godot: harden game audio smoke teardown`,
  `fbcb230d5 godot: clear boot flow smoke audio cache`, and
  `9cc5ce258 godot: clean up stage5 visual smoke teardown` cover the ObjectDB
  cleanup warnings that were still discovered by the single full pass after
  the segmented validation. Each was focused-rerun before the final all-489
  pass.
- Lane-order drift has a review grouping now: the latest traceability pass
  groups the 2026-05-23 split commits by owner lane, so reviewers do not need
  to reconstruct the mixed mythic / stage / Commando sequence from raw commit
  order.
- The feature-commit blocker fixes now have exact current file / line anchors
  below. They are still historically embedded in feature commits, but no
  longer untraceable.

## Broad Smoke Validation Addendum - 2026-05-23

Single full-pass sign-off after the segmented validation:

- `dbded6d8a godot: clean up main menu flow smoke teardown` stops / clears the
  main-menu, start-transition, and character-select audio players before
  freeing their scenes.
- `3e1d1e2af godot: harden game audio smoke teardown` drains all spawned
  `AudioStreamPlayer` children in the game-audio volume smoke.
- `fbcb230d5 godot: clear boot flow smoke audio cache` stops boot-flow BGM,
  clears the stream, frees the scene, and clears `ProjectResourceLoader`
  caches before process exit.
- `9cc5ce258 godot: clean up stage5 visual smoke teardown` moves the Stage 5
  visual-shell smoke out of immediate `_init()` shutdown, awaits staged
  transition prewarm work by frame, resets render-quality / resource caches,
  and gives cleanup frames before `quit()`.
- Focused repeat validation passed after the teardown fixes:
  `stage5_hongryun_visual_shell_smoke` 5x, plus focused reruns for
  `boot_flow_bgm_toggle_smoke`, `commando_fullbody_live2d_smoke`,
  `game_audio_volume_settings_smoke`, `main_menu_flow_smoke`,
  `main_menu_quit_confirmation_smoke`, and
  `stage5_hongryun_visual_shell_smoke`.
- Latest wrapper checks after `.gd` edits:
  `.\tools\run_headless_load_check.ps1` passed, and
  `.\tools\run_warning_scan.ps1` passed with `1279` scripts and no GDScript
  warnings.
- Final broad validation from `godot/`:
  `.\tools\run_smoke_tests.ps1` completed a single uninterrupted `489`-script
  pass with `All Godot smoke tests passed.` and no observed ObjectDB exit
  warning.

Segmented broad validation covered the full sorted 489-script smoke list from
`godot/` after the latest asset and smoke harness fixes:

- The first full run found zero-byte local Godot import cache files for
  `commando_weapon_overlay_net_gun.png` and
  `commando_weapon_overlay_suicide_drone.png`. The source PNGs were valid;
  deleting only the exact stale `.godot/imported` cache files and running
  Godot `--import` regenerated non-empty `.ctex` files. The focused
  `commando_weapon_overlay_smoke` then passed.
- `6902b2055 godot: add import metadata for generated sprites` tracks the
  generated `.import` metadata for the new Fire Support and Spider Mine
  runtime PNGs.
- `fe530a339 godot: add elixir smoke ok marker` fixes
  `elixir_of_mastery_smoke` so the wrapper sees the required
  `elixir_of_mastery_smoke: ok` marker after its internal 34 checks pass.
- `e585e2b32 godot: add horn strawberry mask icons` adds the missing
  `horn_strawberry_mask.png` and 32-frame
  `horn_strawberry_mask_icon_sheet.png` assets plus import metadata. This
  resolves the prewarm warnings in `passive_item_debug_menu_click_add_smoke`.
- `56cbe6365 godot: align dual glitch four poisons smoke` aligns
  `viper_dual_glitch_port_smoke` with the documented Four Poisons Lv.5 Dual
  Glitch duration table: base `900` active frames with `+33%` becomes `1197`
  frames.
- `da656fe70 godot: clean up smoke test teardown` drains or cancels the test
  resources that were still alive at process exit in the previously noted
  ObjectDB leak warnings.
- Focused validation after those fixes passed:
  `commando_weapon_overlay_smoke`, `elixir_of_mastery_smoke`,
  `passive_item_debug_menu_click_add_smoke`, `horn_strawberry_mask_port_smoke`,
  `horn_strawberry_skill_hud_smoke`, `viper_dual_glitch_port_smoke`,
  `viper_nerve_strike_port_smoke`, and `viper_emp_strike_port_smoke`.
- Focused teardown validation after `da656fe70` passed:
  `boot_flow_bgm_toggle_smoke`, `commando_fullbody_live2d_smoke`,
  `game_audio_volume_settings_smoke`, `main_menu_quit_confirmation_smoke`, and
  `stage5_hongryun_visual_shell_smoke`, with no ObjectDB leak warning in the
  wrapper output.
- Segmented broad coverage completed:
  the full run reached `passive_item_debug_menu_click_add_smoke` after passing
  the earlier sorted smoke list; the rerun from
  `passive_item_debug_menu_click_add_smoke` covered the next 177 scripts until
  the Dual Glitch expectation mismatch; and the rerun from
  `viper_dual_glitch_port_smoke` covered the final 17 scripts through
  `weather_event_state_smoke`. This is full-list coverage, but not a single
  uninterrupted all-489 pass.
- Latest wrapper checks after `.gd` edits:
  `.\tools\run_headless_load_check.ps1` passed, and
  `.\tools\run_warning_scan.ps1` passed with `1279` scripts and no GDScript
  warnings.

## Initial Snapshot

- Worktree: `261` modified, `176` untracked.
- Scope split: `godot` 111, `docs` 2, `.claude` 2, legacy / other 322.
- Godot + docs + `AGENTS.md`: 91 tracked files, `+2529/-504`.
- Legacy / other tracked diff, excluding `godot/`, `docs/`, `AGENTS.md`,
  and `.claude/`: 168 files, `+44039/-11171`.
- Godot `.gd` line endings: 1192 files total, 780 contain CRLF.
- Changed Godot `.gd`: 94 files total, 51 contain CRLF.
- Source-string smoke tests: 84 total; 12 changed tests read source text.

## Verified Baseline

- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1191 scripts scanned.
- New / boundary smoke set: 8 passed.
- Modified tracked Godot smoke set: 29 passed.

This is a good compile / smoke baseline, not a full gameplay or BattlePerf
runtime capture. Real frame-time validation still needs an interactive capture.

## Isolation Result

Executed on 2026-05-22 after the initial triage:

- Created safety branch `safety/regression-triage-20260522`.
- Created a binary working-tree patch and status snapshot before stashing.
- Isolated legacy / root changes with stash
  `stash@{0}: legacy-python-and-root-assets-before-godot-stabilization`.
- The root patch/status files were outside the keep-visible pathspec, so they
  are also preserved inside `stash@{0}` rather than the current worktree.
- Visible scope after isolation: `.claude` 2, `docs` 3, `godot` 111,
  legacy / other 0.
- Visible current-scope shortstat: 93 files, `+2658/-514`.

Post-isolation validation:

- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1191 scripts scanned.
- New / boundary smoke set: 8 passed.
- Modified tracked Godot smoke set: 29 passed.

## Godot Change Groups

Keep these together only when the commit message can explain the shared user
impact. Otherwise split into smaller commits.

| Group | Main paths | Risk | Notes |
|---|---|---:|---|
| Pause / menu overlay | `godot/scripts/hud/pause_menu_overlay.gd`, `godot/scripts/ui/main_menu_*`, `godot/scenes/main_menu.tscn` | High | Largest single Godot diff is pause overlay. Needs visual / input review. |
| Stage clear / result | `godot/scripts/ui/stage_clear_result_scene.gd`, reward resolver, result screen tests | High | Result scene and click reactions touch modal-like flow. |
| Mythic / passive items | `godot/scripts/items/mythic_item_runtime.gd`, owner syncer, field/acquisition renderers | High | `mythic_item_runtime.gd` is 6427 lines and should be split before more mythic work. |
| Active item / paddle sync | active item slot/effect/pickup files, related smoke tests | Medium | Smoke coverage is decent; watch stage-transition cooldown and idle sync. |
| Weather / stage VFX | common weather, Stage 4 bird/Ponk, Stage 5 Hongryun | Medium-high | Round-boundary and render-budget smoke passed; still needs visual capture for final sign-off. |
| Input / gamepad | `godot/scripts/core/gamepad_input.gd`, character input readers, gamepad smoke tests | Medium | New core input module; smoke passed. |
| Loading / prewarm | loading screen assets, prewarm controller, `project.godot` rendering setting | Medium | Headless/warning pass; first-entry hitch still needs real capture. |

## First Mythic Split Result

Completed as the first structural follow-up:

- Added `godot/scripts/items/mythic_item_equipment_facade.gd`.
- `mythic_item_runtime.gd` now keeps the public acquire / equip / unequip /
  toggle / discard API but delegates the equipment orchestration to the facade.
- `mythic_item_runtime.gd` line count moved from 6427 to 6235; the new facade
  is 287 lines.
- Fixed Hermes Shoes idle update gating so equipped Hermes can record its first
  movement trail before any trail is already visible.
- Cleaned three smoke-suite blockers discovered during broad validation:
  Gravity Belt / Speedgear icon image checks no longer emit Image.load export
  warnings, and the Molotov ellipse source check accepts the current draw-mesh
  path while still forbidding `draw_set_transform`.
- Scoped the Stage 5 fire-machine source-string guard to the dragon-head
  renderer body so unrelated renderer comments or helpers do not fail the
  smoke test.

Validation after this split:

- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1193 scripts scanned.
- `mythic_item_runtime_idle_update_smoke`: passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 32 passed.

## Second Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_update_gate.gd`.
- `mythic_item_runtime.gd` now keeps the existing private update-gate method
  names but delegates modal / transient / Ragnarok / non-Ragnarok work
  detection plus post-update light-vs-full owner sync selection to the helper.
- `mythic_item_runtime.gd` line count moved from 6235 to 6150; the new update
  gate is 121 lines.

Validation after this split:

- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1194 scripts scanned.
- `mythic_item_runtime_idle_update_smoke`: passed.
- `hermes_shoes_port_smoke`: passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 32 passed.

## Third Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_auto_defense_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the public sensor request API and
  private Smartphone / Sensor helper names but delegates Danger Sensor Belt
  auto-dash request / block checks, Sensor cooldown/effect ticking, and
  Smartphone auto-defense / auto-recovery trigger selection to the helper.
- `mythic_item_runtime.gd` line count moved from 6150 to 5996; the new auto
  defense helper is 261 lines.

Validation after this split:

- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1195 scripts scanned.
- `danger_sensor_belt_port_smoke`: passed.
- `smartphone_port_smoke`: passed.
- `mythic_item_runtime_idle_update_smoke`: passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 34 passed.

## Fourth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_venom_mist_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the Venom Mist public API and private
  helper names but delegates ball poison, mist field spawning, field ticking,
  particle lifecycle, alpha calculation, boss-center reads, and boss special
  gauge drain routing to the helper.
- `mythic_item_runtime.gd` line count moved from 5996 to 5874; the new Venom
  helper is 202 lines.

Validation after this split:

- `venom_mist_gauntlet_port_smoke`: passed.
- `viper_nerve_strike_port_smoke`: passed.
- `mythic_item_runtime_idle_update_smoke`: passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 34 passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1196 scripts scanned.

## Fifth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_rainbow_fur_glove_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the Rainbow Fur Glove public API and
  private helper names but delegates proc handling, player-skill cooldown
  reduction collection/application, player-centered aura placement, particle
  spawning, and aura ticking to the helper.
- `mythic_item_runtime.gd` line count moved from 5874 to 5772; the new
  Rainbow Fur helper is 200 lines.

Validation after this split:

- `rainbow_fur_glove_port_smoke`: passed.
- `mythic_item_runtime_idle_update_smoke`: passed.
- `mythic_item_field_render_budget_smoke`: passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 36 passed after the Stage Clear blocker
  fix below. `render_fps_cap_settings_smoke` passes only outside the
  workspace sandbox because it writes Godot `user://` display settings; the
  other 35 modified tracked smokes pass inside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1197 scripts scanned.

## Stage Clear Smoke Blocker Fix Result

Completed after the fifth mythic split because broad modified-smoke validation
found two Rainbow-unrelated Stage Clear blockers:

- `stage_clear_result_scene.gd` now uses
  `StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT`, so staged prewarm
  reaches the result-box FX prewarm step instead of ending one step early.
- Stage 2 boss result defeat Live2D is included in the result-scene asset path
  map, texture cache fields, interaction status, and scene-ready gate. This
  removes the empty-path missing-asset warning backtraces during result scene
  configuration.

Validation after this fix:

- `stage_clear_result_screen_smoke`: passed.
- `stage_clear_result_scene_click_reaction_smoke`: passed.
- Modified tracked Godot smoke set: 36 passed as 35 in-sandbox smokes plus
  `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1197 scripts scanned.

## Sixth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_adversity_armor_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the Adversity Armor public API and
  private helper names but delegates next-round invincibility queuing,
  round-start activation, one-shot serve-speed bonus consumption, barrier-hit
  feedback, barrier/player particle lifecycle, timer ratio, and ball-collision
  context assembly to the helper.
- `mythic_item_runtime.gd` line count moved from 5772 to 5633; the new
  Adversity Armor helper is 257 lines.

Validation after this split:

- `adversity_armor_port_smoke`: passed.
- `mythic_item_runtime_idle_update_smoke`: passed.
- `mythic_item_field_render_budget_smoke`: passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 36 passed as 35 in-sandbox smokes plus
  `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1198 scripts scanned.

## Seventh Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_shrapnel_armor_runtime.gd`.
- `mythic_item_runtime.gd` now keeps Shrapnel Armor public getters, snapshot /
  owner-sync-visible fields, and the draw wrapper in place, but delegates
  player-hit proc logic, gauge checks / spending, shard burst construction,
  projectile / dust updates, boss collision, stun, knockback, and hit audio
  trigger state to the helper.
- `mythic_item_runtime.gd` line count moved from 5633 to 5421; the new
  Shrapnel Armor helper is 327 lines. The cumulative mythic runtime reduction
  since this triage started is 6427 -> 5421.
- Broad smoke validation also exposed a Stage Clear result compile gap:
  Stage 2 defeated-boss drawing called `_is_stage2_result_boss()` and
  `_draw_stage2_boss_result_sheet_frame()` without local definitions. Added
  the missing guard / sheet-frame wrapper in
  `godot/scripts/ui/stage_clear_result_scene.gd`.

Validation after this split:

- `shrapnel_armor_port_smoke`: passed.
- Focused mythic split set (`shrapnel_armor_port_smoke`,
  `adversity_armor_port_smoke`, `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 36 passed as 35 in-sandbox smokes plus
  `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `stage_clear_result_reward_visual_resolver_smoke`: passed after the Stage
  Clear compile-gap fix.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1199 scripts scanned.

## Eighth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_soul_burst_runtime.gd`.
- `mythic_item_runtime.gd` now keeps Soul Burst public getters, dash consume /
  trigger entry points, actor/snapshot-visible fields, and draw wrappers, but
  delegates gauge-spend activation, zero-token dash replacement effect start,
  dash VFX particle construction, per-frame decay, and runtime clear behavior
  to the helper.
- `mythic_item_runtime.gd` line count moved from 5421 to 5330; the new Soul
  Burst helper is 153 lines. The cumulative mythic runtime reduction since
  this triage started is 6427 -> 5330.

Validation after this split:

- `soul_burst_port_smoke`: passed.
- Focused mythic split set (`soul_burst_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- Mythic runtime direct smoke set: 47 passed.
- Modified tracked Godot smoke set: 38 passed as 37 in-sandbox smokes plus
  `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1202 scripts scanned.

## Ninth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_knee_pads_runtime.gd`.
- Added `godot/tests/knee_pads_port_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the Kick Charger / Knee Pads public
  equipment and player-hit entry points plus snapshot-visible state, but
  delegates half-dash window checks, player-hit gauge charging, Blacksmith
  base-charge resolution, flash particle construction, per-frame effect decay,
  clear behavior, feedback, orb-gauge spin, and routed item audio to the
  helper.
- `mythic_item_runtime.gd` line count moved from 5330 to 5254; the new Knee
  Pads helper is 131 lines. The cumulative mythic runtime reduction since
  this triage started is 6427 -> 5254.

Validation after this split:

- `knee_pads_port_smoke`: passed.
- Focused mythic split set (`knee_pads_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- Mythic runtime direct smoke set: 48 passed.
- Modified tracked Godot smoke set: 38 passed as 37 in-sandbox smokes plus
  `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1204 scripts scanned.

## Tenth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_stat_bonus_runtime.gd`.
- Added `godot/tests/mythic_item_stat_bonus_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the public stat-query API for Speed
  Boots, Speed Gear, Gravity Belt, Bulk-Up Suit, Gold Bar, Dash Gear, and
  Dash Holder, but delegates the movement-speed composition, turn-deceleration
  multiplier, Gravity Belt movement config flags, paddle scale / size math,
  Gold Bar owned-count sale and penalty math, dash-distance / Boost Charging
  rolls, and Dash Holder token-capacity composition to the helper.
- `mythic_item_runtime.gd` line count moved from 5254 to 5244; the new stat
  helper is 160 lines. The cumulative mythic runtime reduction since this
  triage started is 6427 -> 5244.

Validation after this split:

- `mythic_item_stat_bonus_runtime_smoke`: passed.
- Focused stat split set (`mythic_item_stat_bonus_runtime_smoke`,
  `speedgear_port_smoke`, `gravitybelt_port_smoke`, `gold_bar_port_smoke`,
  `hermes_shoes_port_smoke`, `sage_ring_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- Mythic runtime direct smoke set: 49 passed.
- Modified Godot smoke set plus the new stat smoke: 39 passed as 38
  in-sandbox smokes plus `render_fps_cap_settings_smoke` outside the workspace
  sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1206 scripts scanned.

## Eleventh Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_poseidon_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the public Poseidon's Trident API and
  compatibility wrappers used by sensor auto-defense, ball update, snapshot,
  context, draw, and audio paths, but delegates dash-recovery trigger
  detection, gauge/cooldown spend, vortex start/update, particle budgets,
  water trail, capture spiral, release velocity, boss-hit cleanup, cooldown
  charge flash, and runtime clear behavior to the helper.
- `mythic_item_runtime.gd` line count moved from 5244 to 4904; the new
  Poseidon helper is 566 lines. The cumulative mythic runtime reduction since
  this triage started is 6427 -> 4904.

Validation after this split:

- `poseidon_trident_port_smoke`: passed.
- Focused Poseidon split set (`poseidon_trident_port_smoke`,
  `danger_sensor_belt_port_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- Mythic runtime direct smoke set: 49 passed.
- Modified Godot smoke set plus the new stat smoke: 39 passed as 38
  in-sandbox smokes plus `render_fps_cap_settings_smoke` outside the workspace
  sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1207 scripts scanned.

## Twelfth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_ragnarok_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the public Ragnarok Hammer API, existing
  compatibility wrappers, direct state fields used by owner sync and smoke
  tests, draw wrappers, and audio router wrappers, but delegates player-hit
  trigger / gauge spend, stun-ball rally state transitions, boss-hit immune
  checks, stun / knockback timers, shock-loop audio lifecycle, spark particle
  updates, and runtime clear behavior to the helper.
- `mythic_item_runtime.gd` line count moved from 4904 to 4765; the new
  Ragnarok helper is 277 lines. The cumulative mythic runtime reduction since
  this triage started is 6427 -> 4765.

Validation after this split:

- Focused Ragnarok split set (`ragnarok_hammer_port_smoke`,
  `stage2_speed_defense_smoke`, `mythic_item_runtime_idle_update_smoke`,
  `effects_audio_round_boundary_smoke`, `match_reset_controller_smoke`,
  `match_round_restart_controller_smoke`,
  `match_score_event_controller_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- Mythic runtime direct smoke set: 49 passed.
- Modified Godot smoke set plus the stat smoke: 39 passed as 38 in-sandbox
  smokes plus `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1208 scripts scanned.

## Thirteenth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_baal_boots_runtime.gd`.
- `mythic_item_runtime.gd` now keeps Baal's Boots public API, compatibility
  wrappers called by equipment / debug inventory paths, draw glue, and the
  existing weather / effect / combat state owners, but delegates weather
  arming, absorb cinematic begin / finish, sand cleanup / rebuild, gauge
  recovery, round weather effects, projectile hit handling, boss slow /
  knockback application, and Baal-specific color / speed helpers to the new
  helper.
- `mythic_item_runtime.gd` line count moved from 4765 to 4571; the new Baal
  helper is 400 lines. The cumulative mythic runtime reduction since this
  triage started is 6427 -> 4571.

Validation after this split:

- Focused Baal split set (`baal_boots_weather_port_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `active_item_pickup_router_smoke`): passed.
- Mythic runtime direct smoke set: 49 passed.
- Modified Godot smoke set plus the stat smoke: 39 passed as 38 in-sandbox
  smokes plus `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1209 scripts scanned.

## Fourteenth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_celestial_armor_runtime.gd`.
- `mythic_item_runtime.gd` now keeps Celestial Armor public API, context and
  draw glue, and the existing `celestial_armor_state` owner, but delegates
  equipped checks, trigger / gauge roll reads, stun-immunity proc selection,
  paired-proc bypass, gauge spend, player-center resolution, wave start,
  runtime clear, and per-frame state update to the new helper.
- `mythic_item_runtime.gd` line count moved from 4571 to 4511; the new
  Celestial Armor helper is 153 lines. The cumulative mythic runtime
  reduction since this triage started is 6427 -> 4511.

Validation after this split:

- Focused Celestial split set (`celestial_armor_port_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `active_item_pickup_router_smoke`): passed.
- Mythic runtime direct smoke set: 49 passed.
- Modified Godot smoke set plus the stat smoke: 39 passed as 38 in-sandbox
  smokes plus `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `stage_clear_reward_resolver_smoke` was rerun after a transient stale-load
  failure in the modified smoke set and passed before the full modified set
  was rerun.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1210 scripts scanned.

## Fifteenth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_hermes_shoes_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the Hermes Shoes public API, context /
  draw glue, and the existing `hermes_shoes_state` owner, but delegates
  equipped checks, speed roll reads, speed multiplier calculation, runtime /
  round clear, and per-frame player-center / trail update to the new helper.
- `mythic_item_runtime.gd` line count moved from 4511 to 4502; the new
  Hermes Shoes helper is 63 lines. The cumulative mythic runtime reduction
  since this triage started is 6427 -> 4502.
- While rerunning the broad modified smoke set, a result-screen compatibility
  regression surfaced: legacy result plans still use box kind `"mythic"` but
  the UI normalizes that display kind to `"advanced"`. `stage_clear_result_scene.gd`
  now preserves the original `roll_kind` for reward callbacks while keeping the
  normalized display kind for layout / art.

Validation after this split:

- Focused Hermes split set (`hermes_shoes_port_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `player_control_config_builder_smoke`): passed.
- Mythic runtime direct smoke set: 49 passed.
- Modified Godot smoke set plus the stat smoke: 39 passed as 38 in-sandbox
  smokes plus `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `stage_clear_result_scene_click_reaction_smoke` was rerun after the
  result-screen `roll_kind` compatibility fix and passed before the full
  modified set was rerun.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1213 scripts scanned.

## Sixteenth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_heavenly_cape_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the Heavenly Cape public API and existing
  owner/config sync glue, but delegates equipped checks, skill-cooldown roll
  reads, sixth skill-slot bonus, player skill max-slot composition, and player
  skill cooldown multiplier / seconds composition to the new helper.
- `mythic_item_runtime.gd` line count moved from 4502 to 4496; the new
  Heavenly Cape helper is 45 lines. The cumulative mythic runtime reduction
  since this triage started is 6427 -> 4496.

Validation after this split:

- Focused Heavenly Cape split set (`heavenly_cape_port_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `player_control_config_builder_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`): passed.
- Item / mythic direct port smoke set: 40 passed.
- Broad `*_port_smoke` and the full modified Godot smoke set both surfaced an
  unrelated `stage3_map_port_smoke` asset import failure:
  `menhera_boss_attack.png`, `menhera_boss_turn.png`, and
  `menhera_boss_victory.png` fail Godot's WebP decode / imported ctex load.
  The test still prints `stage3_map_port_smoke: ok`, but the wrapper rejects
  the emitted Godot errors. This is a pre-existing Stage 3 asset/import issue,
  not a Heavenly Cape runtime regression.
- Modified Godot smoke set plus the stat smoke passed after excluding only
  `stage3_map_port_smoke`: 44 in-sandbox smokes plus
  `render_fps_cap_settings_smoke` outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1214 scripts scanned.

## Seventeenth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_revival_runtime.gd`.
- `mythic_item_runtime.gd` now keeps Revival's public API and existing
  match-flow / owner-sync hooks, but delegates equipped / available / used
  checks, match-loss trigger consumption, one-time spawn exclusion readout,
  activation effect draw/text, effect update, and runtime clear to the new
  helper while preserving the existing `revival_state` state object.
- `mythic_item_runtime.gd` line count moved from 4496 to 4480; the new
  Revival helper is 63 lines. The cumulative mythic runtime reduction since
  this triage started is 6427 -> 4480.

Validation after this split:

- Focused Revival split set (`revival_port_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `active_item_pickup_router_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`): passed.
- Item / mythic direct port smoke set: 40 passed.
- Modified Godot smoke set plus the stat smoke passed after excluding the
  previously recorded `stage3_map_port_smoke` asset import issue: 44
  in-sandbox smokes plus `render_fps_cap_settings_smoke` outside the
  workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1215 scripts scanned.

## Eighteenth / Nineteenth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_dowsing_runtime.gd`.
- Added `godot/scripts/items/mythic_item_defense_gear_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Dowsing and defense
  gear APIs, but delegates Dowsing Pendulum attraction/context reads, Dowsing
  Goggles bonus-card trigger lifecycle, Spike Boots dash recovery/recharge
  reductions, and Bulletproof Hat / Spiked Helmet stun/knockback resistance
  queries to focused helpers.
- `mythic_item_runtime.gd` line count moved from 4480 to 4460; the new Dowsing
  helper is 63 lines and the new Defense Gear helper is 68 lines. The
  cumulative mythic runtime reduction since this triage started is 6427 -> 4460.

Validation after this split:

- Focused Dowsing split set (`dowsing_goggles_port_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `active_item_pickup_router_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`): passed.
- Combined Dowsing / Defense Gear split set (`dowsing_goggles_port_smoke`,
  `head_defense_items_port_smoke`, `neural_helmet_port_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `active_item_pickup_router_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`): passed.
- Item / mythic direct port smoke set: 40 passed.
- Modified Godot smoke set plus the stat smoke passed after excluding the
  previously recorded `stage3_map_port_smoke` asset import issue: 44
  in-sandbox smokes plus `render_fps_cap_settings_smoke` outside the
  workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: failed on the existing
  `stage_clear_result_scene.gd` `_result_box_sheet_guaranteed_mythic` warning
  after scanning 1217 scripts. The warned variable is part of the already
  modified Stage Clear result scene and is not touched by this item-runtime
  split.

## Twentieth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_capacity_gauge_runtime.gd`.
- Added `godot/tests/mythic_item_capacity_gauge_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Backpack / Charge Bag /
  Battery Pack APIs, but delegates active-item slot capacity composition,
  wall-bounce gauge gain application, AI Pill suppression, per-character wall
  gain base rules, and stage-transition gauge preservation to the focused
  helper.
- `mythic_item_runtime.gd` line count moved from 4460 to 4400; the new
  capacity/gauge helper is 111 lines and the focused smoke is 100 lines. The
  cumulative mythic runtime reduction since this triage started is 6427 -> 4400.

Validation after this split:

- `mythic_item_capacity_gauge_runtime_smoke`: passed.
- Capacity / active-slot / gauge connection set (`mythic_item_capacity_gauge_runtime_smoke`,
  `active_item_bag_expansion_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`, `active_item_pickup_router_smoke`,
  `active_item_slot_controller_cooldown_stage_transition_smoke`,
  `active_item_gauge_runtime_smoke`, `ball_update_driver_callbacks_smoke`):
  passed.
- Item / mythic port smoke set, excluding the previously recorded
  `stage3_map_port_smoke` asset import issue: 43 passed.
- `render_fps_cap_settings_smoke`: passed outside the workspace sandbox.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1219 scripts scanned.

## Twenty-First Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_resource_bonus_runtime.gd`.
- Added `godot/tests/mythic_item_resource_bonus_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Fuel Pouch /
  Bluetooth Ring / Star Detector APIs, but delegates max-special-gauge
  composition, paddle-hit gauge multiplication, and bonus starpoint drop
  chance rolling to the focused helper.
- `mythic_item_runtime.gd` line count moved from 4400 to 4389; the new
  resource-bonus helper is 71 lines and the focused smoke is 83 lines. The
  cumulative mythic runtime reduction since this triage started is 6427 -> 4389.

Validation after this split:

- `mythic_item_resource_bonus_runtime_smoke`: passed.
- Resource-bonus connection set (`mythic_item_resource_bonus_runtime_smoke`,
  `bluetooth_ring_port_smoke`, `star_detector_port_smoke`,
  `stage2_golden_rock_starpoint_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_capacity_gauge_runtime_smoke`,
  `active_item_gauge_runtime_smoke`, `ball_update_driver_callbacks_smoke`):
  passed.
- Item / mythic port smoke set, excluding the previously recorded
  `stage3_map_port_smoke` asset import issue: 44 passed.
- `render_fps_cap_settings_smoke`: passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1223 scripts scanned.

## Twenty-Second Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_cooldown_gear_runtime.gd`.
- Added `godot/tests/mythic_item_cooldown_gear_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Repairman Hammer /
  Cooling Ball / Timer Belt APIs, but delegates Brick Wall width / wall-spawn
  scaling, active-item cooldown reduction composition, and player skill
  cooldown reduction reads to the focused helper.
- `mythic_item_runtime.gd` line count moved from 4389 to 4373; the new
  cooldown-gear helper is 69 lines and the focused smoke is 64 lines. The
  cumulative mythic runtime reduction since this triage started is 6427 -> 4373.
- Warning hygiene also fixed an existing
  `mythic_item_field_effect_renderer.gd` integer-division warning in the
  Poseidon particle budget sampler by making the float calculation and
  `floor` / `int` conversion explicit.

Validation after this split:

- `mythic_item_cooldown_gear_runtime_smoke`: passed.
- Cooldown / Brick / skill connection set (`mythic_item_cooldown_gear_runtime_smoke`,
  `heavenly_cape_port_smoke`, `poseidon_trident_port_smoke`,
  `active_item_brick_wall_geometry_smoke`,
  `active_item_brick_wall_actions_smoke`,
  `active_item_slot_controller_cooldown_stage_transition_smoke`,
  `character_info_live_stats_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- Item / mythic port smoke set, excluding the previously recorded
  `stage3_map_port_smoke` asset import issue: 45 passed.
- `render_fps_cap_settings_smoke`: passed.
- `poseidon_trident_port_smoke` and `mythic_item_field_render_budget_smoke`:
  passed again after the warning-hygiene fix.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1225 scripts scanned.

## Twenty-Third Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_progression_bonus_runtime.gd`.
- Added `godot/tests/mythic_item_progression_bonus_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Sage Ring / Sacred
  Laurel / Transcendent Crown APIs, but delegates item perk-level bonus
  composition, Sage Ring movement/body penalties, Sacred Laurel leaf bonus
  context, and Transcendent Crown skill-bonus context to the focused helper.
- `mythic_item_runtime.gd` line count moved from 4373 to 4353; the new
  progression-bonus helper is 82 lines and the focused smoke is 101 lines.
  The cumulative mythic runtime reduction since this triage started is
  6427 -> 4353.

Validation after this split:

- `mythic_item_progression_bonus_runtime_smoke`: passed.
- Effective-level / progression connection set
  (`mythic_item_progression_bonus_runtime_smoke`, `sage_ring_port_smoke`,
  `sacred_laurel_port_smoke`, `transcendent_crown_port_smoke`,
  `perk_laurel_shield_port_smoke`, `item_polish_perk_port_smoke`,
  `item_alchemy_perk_port_smoke`, `item_caffeine_perk_port_smoke`,
  `dash_acceleration_perk_port_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`): passed.
- Item / mythic port smoke set, excluding the previously recorded
  `stage3_map_port_smoke` asset import issue: 46 passed.
- `render_fps_cap_settings_smoke`: passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1227 scripts scanned.

## Twenty-Fourth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_ai_assist_runtime.gd`.
- Added `godot/tests/mythic_item_ai_assist_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Smartphone /
  Neural Helmet / AI Pill modifier APIs, but delegates Smartphone equipped
  state/count and cooldown clear plus Neural Helmet AI Pill gauge drain,
  spawn multiplier, spawn chance, and direction-key cancel queries to the
  focused helper.
- `mythic_item_runtime.gd` line count moved from 4353 to 4340; the new
  AI-assist helper is 71 lines and the focused smoke is 95 lines. The
  cumulative mythic runtime reduction since this triage started is
  6427 -> 4340.

Validation after this split:

- `mythic_item_ai_assist_runtime_smoke`: passed.
- Smartphone / Neural Helmet / AI Pill connection set (`smartphone_port_smoke`,
  `neural_helmet_port_smoke`, `active_item_effect_interaction_facade_smoke`,
  `active_item_aipill_runtime_smoke`, `active_item_aipill_behavior_smoke`,
  `active_item_aipill_actions_smoke`, `item_field_spawn_pool_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- Item / mythic surrounding smoke set selected by mythic / Smartphone /
  Neural Helmet / AI Pill / field-spawn coverage: 28 passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1229 scripts scanned.

## Twenty-Fifth Mythic Split Result

Completed as the next structural follow-up:

- Extended `godot/scripts/items/mythic_item_resource_bonus_runtime.gd`.
- Extended `godot/tests/mythic_item_resource_bonus_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Gold Digger and
  Lucky Coin APIs, but delegates Gold Digger equipped/count state,
  gauge/gold multiplier math, and Lucky Coin equipped/active state plus
  double-spawn chance rolls to the resource-bonus helper.
- `mythic_item_runtime.gd` line count moved from 4340 to 4329; the
  resource-bonus helper is now 126 lines and its focused smoke is 116
  lines. The cumulative mythic runtime reduction since this triage started
  is 6427 -> 4329.

Validation after this split:

- `mythic_item_resource_bonus_runtime_smoke`: passed.
- Gold Digger / Lucky Coin economy and field-spawn connection set
  (`gold_digger_port_smoke`, `lucky_coin_port_smoke`,
  `active_item_gauge_runtime_smoke`, `active_item_gauge_actions_smoke`,
  `active_item_field_spawn_queue_smoke`, `active_item_pickup_router_smoke`,
  `item_field_spawn_pool_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1229 scripts scanned.

## Twenty-Sixth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_throw_bonus_runtime.gd`.
- Added `godot/tests/mythic_item_throw_bonus_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Reinforced
  Boomerang Gauntlet and Commando Arm APIs, but delegates boomerang launch /
  homing / spawn / knockback / stun bonuses plus Commando Arm throw speed,
  windup, range, smoke-duration, and context math to the focused helper.
- `mythic_item_runtime.gd` line count moved from 4329 to 4268; the new
  throw-bonus helper is 173 lines and the focused smoke is 115 lines. The
  cumulative mythic runtime reduction since this triage started is
  6427 -> 4268.

Validation after this split:

- `mythic_item_throw_bonus_runtime_smoke`: passed.
- Reinforced Boomerang / Commando Arm throw connection set
  (`reinforced_boomerang_gauntlet_port_smoke`, `commando_arm_port_smoke`,
  `active_item_throw_activation_smoke`, `active_item_throw_boomerang_smoke`,
  `item_field_spawn_pool_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1232 scripts scanned.

## Twenty-Seventh Mythic Split Result

Completed as the next structural follow-up:

- Extended `godot/scripts/items/mythic_item_auto_defense_runtime.gd`.
- Added `godot/tests/mythic_item_sensor_auto_defense_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Danger Sensor Belt
  APIs, but delegates sensor equipped/enabled state, cooldown seconds /
  frames / progress, ready checks, context, and runtime / round clear helpers
  to the auto-defense helper that already owns the sensor dash prediction
  behavior.
- `mythic_item_runtime.gd` line count moved from 4268 to 4249; the
  auto-defense helper is now 323 lines and the focused sensor smoke is 75
  lines. The cumulative mythic runtime reduction since this triage started
  is 6427 -> 4249.

Validation after this split:

- `mythic_item_sensor_auto_defense_runtime_smoke`: passed.
- Danger Sensor connection set (`danger_sensor_belt_port_smoke`,
  `item_field_spawn_pool_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1233 scripts scanned.

## Twenty-Eighth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_foul_whistle_runtime.gd`.
- Added `godot/tests/mythic_item_foul_whistle_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Foul Whistle APIs,
  but delegates equipped / active checks, negate chance math, trigger / audio
  dispatch, delayed reset consumption, effect-active query, clear, and update
  flow to the focused helper while preserving `foul_whistle_state.gd` as the
  animation / reset state container.
- `mythic_item_runtime.gd` line count moved from 4249 to 4241; the new Foul
  Whistle helper is 50 lines and the focused smoke is 69 lines. The
  cumulative mythic runtime reduction since this triage started is
  6427 -> 4241.

Validation after this split:

- `mythic_item_foul_whistle_runtime_smoke`: passed.
- Foul Whistle score / delayed reset connection set
  (`foul_whistle_port_smoke`, `item_update_boss_health_reset_smoke`,
  `item_field_spawn_pool_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1236 scripts scanned, after
  adding narrow `unused_private_class_variable` suppressions for existing
  Molotov VFX host-pool fields that are present but not wired yet in
  `active_item_throw_controller.gd` / `active_item_throw_renderer.gd`.

## Twenty-Ninth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_pandora_legacy_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the existing public Pandora's Legacy
  APIs and draw wrappers, but delegates equipped / active checks, trigger
  chance and selection-quality reads, round-win queueing, selection start /
  confirm / cancel, grant routing, timer advancement, and keyboard /
  mouse / gamepad selection input to the focused helper.
- `mythic_item_runtime.gd` line count moved from 4241 to 4143; the new
  Pandora helper is 203 lines. The cumulative mythic runtime reduction since
  this triage started is 6427 -> 4143.

Validation after this split:

- Pandora connection set (`pandora_legacy_port_smoke`,
  `item_field_spawn_pool_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1238 scripts scanned.

## Thirtieth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_field_effect_visibility.gd`.
- Updated `godot/tests/mythic_item_field_render_budget_smoke.gd` so the
  source-level draw-gate check follows the new visibility owner.
- `mythic_item_runtime.gd` now keeps `has_visible_field_effects()` as the
  public draw-gate API, but delegates the actual transient / VFX /
  cinematic visibility checks to the focused helper.
- `mythic_item_runtime.gd` line count moved from 4143 to 4104; the new
  field-effect visibility helper is 47 lines. The cumulative mythic runtime
  reduction since this triage started is 6427 -> 4104.

Validation after this split:

- Field visibility / draw-budget set (`mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_snapshot_builder_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1239 scripts scanned.

## Thirty-First Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_acquisition_cinematic_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the public acquisition cinematic APIs,
  but delegates v2 cinematic script caching, asset prewarm, host creation /
  reuse, start eligibility, target-center resolution, reset, input,
  snapshot, and update forwarding to the focused helper.
- `mythic_item_runtime.gd` line count moved from 4104 to 4048; the new
  acquisition cinematic helper is 110 lines. The cumulative mythic runtime
  reduction since this triage started is 6427 -> 4048.

Validation after this split:

- Acquisition cinematic connection set
  (`mythic_item_acquisition_cinematic_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1240 scripts scanned.

## Thirty-Second Mythic Split Result

Completed as the next structural follow-up:

- Extended `godot/scripts/items/mythic_item_pandora_selection_renderer.gd`.
- `mythic_item_runtime.gd` now keeps the public
  `draw_pandora_legacy_selection()` API, but delegates the selection overlay
  backdrop, title / hint text, card loop, badge / icon / title rendering,
  selected marker, and icon-cache reads to the focused Pandora renderer.
- `mythic_item_runtime.gd` line count moved from 4048 to 3970; the Pandora
  selection renderer is now 188 lines. The cumulative mythic runtime
  reduction since this triage started is 6427 -> 3970.

Validation after this split:

- Pandora overlay / flow set (`pandora_legacy_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`, `match_flow_driver_smoke`):
  passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1240 scripts scanned.

## Thirty-Third Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_activation_effect_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the public activation-effect API and
  the existing private builder wrappers used by focused smoke tests, but
  delegates Megingjord activation reset, active query, start/audio/redraw
  fanout, particle / bolt construction, elapsed timing, and draw forwarding
  to the focused helper.
- `mythic_item_runtime.gd` line count moved from 3970 to 3933; the new
  activation-effect helper is 49 lines. The cumulative mythic runtime
  reduction since this triage started is 6427 -> 3933.

Validation after this split:

- Activation / Megingjord connection set
  (`mythic_item_activation_effect_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `active_item_bag_expansion_smoke`,
  `mythic_item_snapshot_builder_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1241 scripts scanned.

## Thirty-Fourth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_lifecycle_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the public `reset()` and
  `reset_round()` APIs, but delegates the full-runtime and round-boundary
  clear sequencing to the focused lifecycle helper while preserving each
  item-specific `_clear_*` owner.
- `mythic_item_runtime.gd` line count moved from 3933 to 3898; the new
  lifecycle helper is 47 lines. The cumulative mythic runtime reduction
  since this triage started is 6427 -> 3898.

Validation after this split:

- Lifecycle / reset connection set (`mythic_item_runtime_idle_update_smoke`,
  `mythic_item_activation_effect_builder_smoke`, `revival_port_smoke`,
  `foul_whistle_port_smoke`, `baal_boots_weather_port_smoke`,
  `pandora_legacy_port_smoke`, `mythic_item_acquisition_cinematic_smoke`,
  `mythic_item_snapshot_builder_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1243 scripts scanned.

## Thirty-Fifth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_update_runtime.gd`.
- `mythic_item_runtime.gd` now keeps the public `update()` API, but
  delegates idle update handling, modal / transient per-frame update
  sequencing, item update fanout, and post-update owner-sync handoff to the
  focused helper.
- `mythic_item_runtime.gd` line count moved from 3898 to 3870; the new
  update helper is 41 lines. The cumulative mythic runtime reduction since
  this triage started is 6427 -> 3870.

Validation after this split:

- Per-frame update connection set (`mythic_item_runtime_idle_update_smoke`,
  `mythic_item_acquisition_cinematic_smoke`,
  `baal_boots_weather_port_smoke`, `ragnarok_hammer_port_smoke`,
  `poseidon_trident_port_smoke`, `venom_mist_gauntlet_port_smoke`,
  `shrapnel_armor_port_smoke`, `mythic_item_snapshot_builder_smoke`):
  passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1244 scripts scanned.

## Thirty-Sixth Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_perk_choice_runtime.gd`.
- Added `godot/tests/mythic_item_perk_choice_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the public Megingjord / perk-choice
  API, but delegates new-batch counter reset, Dowsing bonus-trigger cleanup,
  `common_refresh` exclusion, max-two extra-pick guard, extra-pick chance
  read, and activation handoff to the focused helper.
- `mythic_item_runtime.gd` line count moved from 3870 to 3853; the new
  perk-choice helper is 39 lines. The cumulative mythic runtime reduction
  since this triage started is 6427 -> 3853.

Validation after this split:

- Perk-choice connection set (`mythic_item_perk_choice_runtime_smoke`,
  `item_polish_perk_port_smoke`, `mythic_item_snapshot_builder_smoke`,
  `stage_clear_reward_resolver_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1247 scripts scanned.

## Thirty-Seventh Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_ownership_runtime.gd`.
- Added `godot/tests/mythic_item_ownership_runtime_smoke.gd`.
- `mythic_item_runtime.gd` now keeps the public ownership / one-time spawn
  skip API, but delegates inventory name scans, owned one-time passive
  filtering, and consumed Revival filtering to the focused helper.
- `mythic_item_runtime.gd` line count moved from 3853 to 3843; the new
  ownership helper is 23 lines. The cumulative mythic runtime reduction
  since this triage started is 6427 -> 3843.

Validation after this split:

- Ownership / spawn-skip connection set (`mythic_item_ownership_runtime_smoke`,
  `treasure_hunt_runtime_smoke`, `item_field_spawn_pool_smoke`,
  `stage_clear_reward_resolver_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1249 scripts scanned.

## Thirty-Eighth Mythic Split Result

Completed as the next structural follow-up:

- `godot/scripts/items/mythic_item_field_effect_renderer.gd` now draws the
  Baal's Boots, Hermes Shoes, Venom Mist, Celestial Armor, Foul Whistle,
  Revival, and Sensor field-effect branches directly from runtime state and
  a compact constants dictionary.
- Removed the matching thin `_draw_*` bridge methods from
  `mythic_item_runtime.gd`; the public `draw_field_effects()` API remains
  unchanged for the playfield drawer.
- `mythic_item_runtime.gd` line count moved from 3843 to 3761. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3761.

Validation after this split:

- Field-effect connection set (`mythic_item_field_render_budget_smoke`,
  `mythic_item_runtime_idle_update_smoke`, `baal_boots_weather_port_smoke`,
  `hermes_shoes_port_smoke`, `celestial_armor_port_smoke`,
  `venom_mist_gauntlet_port_smoke`, `foul_whistle_port_smoke`,
  `revival_port_smoke`, `mythic_item_sensor_auto_defense_runtime_smoke`):
  passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1250 scripts scanned.

## Thirty-Ninth Mythic Split Result

Completed as the next structural follow-up:

- `godot/scripts/items/mythic_item_field_effect_renderer.gd` now draws
  Ragnarok impact rings, electric-stun overlay, and sparks directly from
  runtime state and field-effect constants.
- Removed the matching thin Ragnarok `_draw_*` bridge methods from
  `mythic_item_runtime.gd`, including stale mojibake comments that were
  stranded inside the old electric-stun bridge.
- `mythic_item_runtime.gd` line count moved from 3761 to 3718. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3718.

Validation after this split:

- Ragnarok / field-effect connection set (`mythic_item_field_render_budget_smoke`,
  `ragnarok_hammer_port_smoke`, `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_snapshot_builder_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1250 scripts scanned.

## Fortieth Mythic Split Result

Completed as the next structural follow-up:

- Moved Ragnarok electric-stun color arrays and ring / ellipse draw-budget
  constants from `mythic_item_runtime.gd` to
  `mythic_item_field_effect_renderer.gd`.
- Updated the field render-budget smoke to assert the ellipse budget at the
  renderer owner instead of the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3718 to 3681. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3681.

Validation after this split:

- Ragnarok render constant connection set (`mythic_item_field_render_budget_smoke`,
  `ragnarok_hammer_port_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1250 scripts scanned.

## Forty-First Mythic Split Result

Completed as the next structural follow-up:

- `godot/scripts/items/mythic_item_field_effect_renderer.gd` now draws
  Poseidon water trail, vortex particles, and water-explosion branches
  directly from runtime state.
- Removed the matching Poseidon `_draw_*` bridge methods from
  `mythic_item_runtime.gd`; the renderer keeps the original Python draw-order
  comment at the real draw owner.
- `mythic_item_runtime.gd` line count moved from 3681 to 3644. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3644.

Validation after this split:

- Poseidon / field-effect connection set (`mythic_item_field_render_budget_smoke`,
  `poseidon_trident_port_smoke`, `mythic_item_runtime_idle_update_smoke`):
  passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1250 scripts scanned.

## Forty-Second Mythic Split Result

Completed as the next structural follow-up:

- `godot/scripts/items/mythic_item_field_effect_renderer.gd` now draws
  Rainbow Fur Glove, Adversity Armor, Shrapnel Armor, Knee Pads, and Soul
  Burst field-effect branches directly from runtime state.
- Removed the matching thin `_draw_*` bridge methods from
  `mythic_item_runtime.gd`.
- Updated `adversity_armor_port_smoke` so the timer-stack ownership assertion
  points at the field renderer rather than the removed runtime bridge.
- `mythic_item_runtime.gd` line count moved from 3644 to 3576. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3576.

Validation after this split:

- Remaining field-effect bridge connection set
  (`mythic_item_field_render_budget_smoke`, `rainbow_fur_glove_port_smoke`,
  `adversity_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `knee_pads_port_smoke`, `soul_burst_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1250 scripts scanned.

## Forty-Third Mythic Split Result

Completed as the next structural follow-up:

- Added `godot/scripts/items/mythic_item_helper_registry.gd` as the owner of
  mythic helper initialization order, script-path lookup, and helper
  construction.
- Replaced the inline `HELPER_INIT_ORDER` / `HELPER_SCRIPT_PATHS` blocks in
  `mythic_item_runtime.gd` with a single `HelperRegistry` preload.
- Strengthened `mythic_item_runtime_idle_update_smoke` so it verifies every
  helper in the registry can be initialized through the runtime prewarm path.
- `mythic_item_runtime.gd` line count moved from 3576 to 3447. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3447.

Validation after this split:

- Helper-registry / mythic runtime connection set
  (`mythic_item_runtime_idle_update_smoke`, `pandora_legacy_port_smoke`,
  `mythic_item_field_render_budget_smoke`, `rainbow_fur_glove_port_smoke`,
  `adversity_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `knee_pads_port_smoke`, `soul_burst_port_smoke`,
  `poseidon_trident_port_smoke`, `ragnarok_hammer_port_smoke`,
  `baal_boots_weather_port_smoke`, `celestial_armor_port_smoke`,
  `hermes_shoes_port_smoke`, `foul_whistle_port_smoke`,
  `mythic_item_foul_whistle_runtime_smoke`, `revival_port_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.

## Forty-Fourth Mythic Split Result

Completed as the next structural follow-up:

- Moved Pandora Legacy active-item Korean names and 3-card count ownership
  from `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_pandora_legacy_runtime.gd`.
- Added Pandora runtime helpers for card rect / index lookup and selection
  overlay draw fanout, so the runtime facade no longer passes Pandora
  constants directly to the renderer.
- Strengthened `pandora_legacy_port_smoke` so it verifies Pandora runtime owns
  the active-item name table and card-count constant.
- `mythic_item_runtime.gd` line count moved from 3447 to 3411. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3411.

Validation after this split:

- Pandora connection set (`pandora_legacy_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.

## Forty-Fifth Mythic Split Result

Completed as the next structural follow-up:

- Removed the remaining private Pandora card-index / clear bridge methods from
  `mythic_item_runtime.gd`.
- Updated `mythic_item_pandora_legacy_runtime.gd` so mouse hover/click
  selection resolves card indices through its own `get_card_index_at()` helper.
- Updated `mythic_item_equipment_facade.gd` and
  `mythic_item_lifecycle_runtime.gd` so Pandora selection / reset cleanup
  calls the Pandora runtime helper directly.
- Strengthened `pandora_legacy_port_smoke` so the removed private bridge names
  cannot silently return to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3411 to 3395. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3395.

Validation after this split:

- Pandora / equipment connection set (`pandora_legacy_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_ownership_runtime_smoke`,
  `mythic_item_capacity_gauge_runtime_smoke`,
  `mythic_item_resource_bonus_runtime_smoke`,
  `mythic_item_cooldown_gear_runtime_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`, `gravitybelt_port_smoke`,
  `speedgear_port_smoke`, `gold_bar_port_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.

## Forty-Sixth Mythic Split Result

Completed as the next structural follow-up:

- Moved Megingjord activation effect duration, particle count, and bolt count
  ownership from `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_activation_effect_runtime.gd`.
- Simplified activation effect `is_active`, `start`, `draw`,
  `build_particles`, and `build_bolts` so callers no longer pass the
  Megingjord activation constants through the runtime facade.
- Updated `mythic_item_perk_choice_runtime.gd` to start the activation effect
  through `activation_effect_runtime` directly.
- Strengthened `mythic_item_activation_effect_builder_smoke` so the removed
  activation bridge names and inline constants cannot silently return to
  `mythic_item_runtime.gd`.
- `mythic_item_runtime.gd` line count moved from 3395 to 3374. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3374.

Validation after this split:

- Activation / perk-choice connection set
  (`mythic_item_activation_effect_builder_smoke`,
  `mythic_item_perk_choice_runtime_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_snapshot_builder_smoke`, `item_polish_perk_port_smoke`):
  passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.

## Forty-Seventh Mythic Split Result

Completed as the next structural follow-up:

- Moved snapshot item-id / base-gauge / Venom Mist radius defaults from
  `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_snapshot_builder.gd`.
- Changed `snapshot_builder.build_snapshot()` to own those defaults directly
  instead of receiving `SNAPSHOT_CONSTANTS` from the runtime facade.
- Moved Pandora owner-redraw helper ownership into
  `mythic_item_pandora_legacy_runtime.gd`, removing the runtime-level
  `_queue_owner_redraw()` bridge.
- Strengthened `mythic_item_snapshot_builder_smoke` so the removed snapshot
  constants and redraw bridge cannot silently return to `mythic_item_runtime.gd`.
- `mythic_item_runtime.gd` line count moved from 3374 to 3362. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3362.

Validation after this split:

- Snapshot / Pandora connection set (`mythic_item_snapshot_builder_smoke`,
  `pandora_legacy_port_smoke`, `mythic_item_runtime_idle_update_smoke`):
  passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.

## Forty-Eighth Mythic Split Result

Completed as the next structural follow-up:

- Moved Danger Sensor Belt / Smartphone auto-defense timing and threshold
  constants from `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_auto_defense_runtime.gd`.
- Removed the runtime-level `AUTO_DEFENSE_CONSTANTS` handoff dictionary and
  simplified the helper API so sensor prediction, dash-effect timing,
  Smartphone recovery, Smartphone defense cooldown, trigger margin, and
  player-safety checks use helper-owned constants directly.
- Kept field-effect draw timing tied to the helper by reading
  `AutoDefenseRuntime.SENSOR_AUTO_DASH_EFFECT_FRAMES` from
  `FIELD_EFFECT_CONSTANTS`.
- Strengthened `mythic_item_sensor_auto_defense_runtime_smoke` so
  `AUTO_DEFENSE_CONSTANTS` cannot silently return to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3362 to 3338. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3338.

Validation after this split:

- Sensor / Smartphone connection set
  (`mythic_item_sensor_auto_defense_runtime_smoke`,
  `danger_sensor_belt_port_smoke`, `smartphone_port_smoke`,
  `active_item_smartphone_auto_use_smoke`,
  `mythic_item_ai_assist_runtime_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched Godot files reported only the existing
  `mythic_item_runtime.gd` CRLF-to-LF warning.

## Forty-Ninth Mythic Split Result

Completed as the next structural follow-up:

- Moved Venom Mist field radius, default duration, trigger cap, boss slow
  amount, gauge-drain, Stage 5 Hongryun drain threshold, fade timing, and
  particle caps from `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_venom_mist_runtime.gd`.
- Removed the runtime-level `VENOM_MIST_CONSTANTS` handoff dictionary and
  simplified the Venom Mist helper API so poison consumption, forced boss
  spawn, field start, per-frame update, gauge drain, particle build/update,
  and alpha calculation use helper-owned constants directly.
- Kept runtime context / field-effect radius plumbing tied to the helper by
  reading `VenomMistRuntime.RADIUS`.
- Strengthened `venom_mist_gauntlet_port_smoke` so `VENOM_MIST_CONSTANTS`
  and inline `const VENOM_MIST_*` runtime constants cannot silently return to
  the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3338 to 3320. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3320.

Validation after this split:

- Venom / field-render connection set (`venom_mist_gauntlet_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `viper_venom_edge_strike_port_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched Godot files reported only existing
  CRLF-to-LF warnings on `mythic_item_runtime.gd` and
  `venom_mist_gauntlet_port_smoke.gd`.

## Fiftieth Mythic Split Result

Completed as the next structural follow-up:

- Moved Rainbow Fur Glove trigger cap, cooldown-reduction cap, aura timing,
  particle caps, player-size fallbacks, and aura colors from
  `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_rainbow_fur_glove_runtime.gd`.
- Removed the runtime-level `RAINBOW_FUR_GLOVE_CONSTANTS` handoff dictionary
  and simplified the Rainbow helper API so player-hit proc, clear/reset,
  center resolution, aura start, particle build/update, and runtime update
  use helper-owned constants directly.
- Kept field-effect color plumbing tied to the helper by reading
  `RainbowFurGloveRuntime.COLORS`.
- Strengthened `rainbow_fur_glove_port_smoke` so
  `RAINBOW_FUR_GLOVE_CONSTANTS` and inline runtime cap / aura / color
  constants cannot silently return to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3320 to 3298. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3298.

Validation after this split:

- Rainbow / field-render connection set (`rainbow_fur_glove_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `character_info_skill_cooldown_pause_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched Godot files reported only existing
  CRLF-to-LF warnings on `mythic_item_runtime.gd` and
  `rainbow_fur_glove_port_smoke.gd`.

## Fifty-First Mythic Split Result

Completed as the next structural follow-up:

- Moved Adversity Armor trigger cap, serve-speed bonus, flash timing,
  barrier-y offset, particle caps, field-size fallbacks, and player-size
  fallbacks from `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_adversity_armor_runtime.gd`.
- Removed the runtime-level `ADVERSITY_ARMOR_CONSTANTS` handoff dictionary
  and simplified the Adversity helper API so ball-collision context,
  round-start activation, barrier-hit feedback, barrier y, per-frame update,
  idle / barrier particle spawn, and player-center resolution use helper-owned
  constants directly.
- Kept public trigger / serve-speed queries tied to the helper by reading
  `AdversityArmorRuntime.MAX_TRIGGER_CHANCE_PCT` and
  `AdversityArmorRuntime.DEFAULT_SERVE_SPEED_BONUS_PCT`.
- Strengthened `adversity_armor_port_smoke` so `ADVERSITY_ARMOR_CONSTANTS`
  and inline runtime cap / flash / barrier constants cannot silently return
  to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3298 to 3283. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3283.

Validation after this split:

- Adversity / collision connection set (`adversity_armor_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `active_item_runtime_context_facade_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched Godot files reported only the existing
  `mythic_item_runtime.gd` CRLF-to-LF warning.

## Fifty-Second Mythic Split Result

Completed as the next structural follow-up:

- Moved Kick Charger / Knee Pads flash duration, particle count, and feedback
  shake constants from `mythic_item_runtime.gd` into
  `godot/scripts/items/mythic_item_knee_pads_runtime.gd`.
- Removed the runtime-level `KNEE_PADS_CONSTANTS` handoff dictionary and
  simplified the Knee Pads helper API so half-dash player-hit activation and
  VFX start use helper-owned constants directly.
- Kept field-effect flash timing tied to the helper by reading
  `KneePadsRuntime.FLASH_DURATION_FRAMES`.
- Strengthened `knee_pads_port_smoke` so `KNEE_PADS_CONSTANTS` and inline
  runtime flash / particle / shake constants cannot silently return to the
  runtime facade.
- `mythic_item_runtime.gd` line count moved from 3283 to 3273. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3273.

Validation after this split:

- Kick Charger / field-render connection set (`knee_pads_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `viper_marshal_kick_port_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched Godot files reported only the existing
  `mythic_item_runtime.gd` CRLF-to-LF warning.

## Fifty-Third Mythic Split Result

Completed as the next structural follow-up:

- Moved Soul Burst gauge-cost bounds, dash VFX timing, particle counts,
  wind-trail count, and particle alpha cutoff from `mythic_item_runtime.gd`
  into `godot/scripts/items/mythic_item_soul_burst_runtime.gd`.
- Removed the runtime-level `SOUL_BURST_CONSTANTS` handoff dictionary and
  simplified the Soul Burst helper API so gauge-spend dash activation,
  direct trigger, and effect rebuild use helper-owned constants directly.
- Kept public gauge-cost and field-effect alpha-cutoff queries tied to the
  helper by reading `SoulBurstRuntime.DEFAULT_GAUGE_COST`,
  `SoulBurstRuntime.MIN_GAUGE_COST`,
  `SoulBurstRuntime.MAX_GAUGE_COST`, and
  `SoulBurstRuntime.PARTICLE_ALPHA_CUTOFF`.
- Strengthened `soul_burst_port_smoke` so `SOUL_BURST_CONSTANTS` and inline
  runtime gauge / effect / particle / wind constants cannot silently return
  to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3273 to 3259. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3259.

Validation after this split:

- Soul Burst / dash connection set (`soul_burst_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `dash_snapshot_builder_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched files reported only existing
  line-ending warnings.

## Fifty-Fourth Mythic Split Result

Completed as the next structural follow-up:

- Moved Foul Whistle animation total frames, delayed reset frame, referee
  frame count, and referee frame timing ownership into
  `godot/scripts/items/mythic_item_foul_whistle_runtime.gd`.
- Replaced the runtime-level Foul Whistle field-effect constants with
  `FoulWhistleRuntime.TOTAL_FRAMES`,
  `FoulWhistleRuntime.REFEREE_FRAME_COUNT`, and
  `FoulWhistleRuntime.REFEREE_FRAME_FRAMES` so renderer metadata stays tied
  to the runtime owner.
- Strengthened `foul_whistle_port_smoke` so inline runtime Foul Whistle
  constants cannot silently return to the facade.
- `mythic_item_runtime.gd` line count moved from 3259 to 3257. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3257.

Validation after this split:

- Foul Whistle / field-render connection set (`foul_whistle_port_smoke`,
  `mythic_item_foul_whistle_runtime_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched files reported only existing
  line-ending warnings.

## Fifty-Fifth Mythic Split Result

Completed as the next structural follow-up:

- Moved Hermes Shoes speed cap, movement-trail lifetime, trail cap, movement
  threshold, wing-flap speed, and default player-size fallback ownership into
  `godot/scripts/items/mythic_item_hermes_shoes_runtime.gd`.
- Removed the runtime-level `HERMES_SHOES_CONSTANTS` handoff dictionary and
  simplified the Hermes helper API so speed queries, clear / round-clear, and
  per-frame trail updates use helper-owned constants directly.
- Kept field-effect trail rendering tied to the helper by reading
  `HermesShoesRuntime.TRAIL_LIFE_FRAMES` and
  `HermesShoesRuntime.MOVE_TRAIL_THRESHOLD`.
- Strengthened `hermes_shoes_port_smoke` so `HERMES_SHOES_CONSTANTS` and
  inline runtime speed / trail / movement / wing constants cannot silently
  return to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3257 to 3244. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3244.

Validation after this split:

- Hermes / movement connection set (`hermes_shoes_port_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_runtime_idle_update_smoke`, `speedgear_port_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed on rerun, 1251 scripts scanned.
  The first run surfaced a stale unrelated
  `runtime_perk_overlay_renderer.gd` unused-parameter warning even though the
  current working tree already uses `_pulse`; rerun was clean.
- `git diff --check` for the touched files reported only existing
  line-ending warnings.

## Fifty-Sixth Mythic Split Result

Completed as the next structural follow-up:

- Moved Celestial Armor trigger / gauge caps, wave lifetime, render radius,
  shard / arc counts, paired-proc window, feedback shake, and default
  player / field-size fallbacks into
  `godot/scripts/items/mythic_item_celestial_armor_runtime.gd`.
- Removed the runtime-level `CELESTIAL_ARMOR_CONSTANTS` handoff dictionary
  and simplified the Celestial helper API so trigger chance, gauge cost,
  stun immunity consume, gauge spend, wave start, and player-center
  resolution use helper-owned constants directly.
- Kept field-effect wave rendering tied to the helper by reading
  `CelestialArmorRuntime.WAVE_RADIUS_MAX`,
  `CelestialArmorRuntime.SHARD_COUNT`, and
  `CelestialArmorRuntime.ARC_SEGMENTS`.
- Strengthened `celestial_armor_port_smoke` so
  `CELESTIAL_ARMOR_CONSTANTS` and inline runtime cap / wave / paired-proc /
  shard / arc / feedback constants cannot silently return to the runtime
  facade.
- `mythic_item_runtime.gd` line count moved from 3244 to 3223. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3223.

Validation after this split:

- Celestial / field-render connection set (`celestial_armor_port_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_snapshot_builder_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched files reported only existing
  line-ending warnings.

## Fifty-Seventh Mythic Split Result

Completed as the next structural follow-up:

- Moved Speed Gear turn-deceleration multiplier and Gold Bar sell-price /
  speed-penalty ownership into
  `godot/scripts/items/mythic_item_stat_bonus_runtime.gd`.
- Removed the runtime-level `STAT_BONUS_CONSTANTS` handoff dictionary and
  simplified the stat helper API so turn-deceleration, player-speed
  composition, Gold Bar sell value, total sell value, speed penalty, and
  speed multiplier use helper-owned constants directly.
- Strengthened `mythic_item_stat_bonus_runtime_smoke` so
  `STAT_BONUS_CONSTANTS` and inline Speed Gear / Gold Bar stat constants
  cannot silently return to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3223 to 3215. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3215.

Validation after this split:

- Stat / movement connection set (`mythic_item_stat_bonus_runtime_smoke`,
  `speedgear_port_smoke`, `gold_bar_port_smoke`,
  `gravitybelt_port_smoke`, `mythic_item_snapshot_builder_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched files reported only existing
  line-ending warnings.

## Fifty-Eighth Mythic Split Result

Completed as the next structural follow-up:

- Moved Commando Arm roll item-id and stack-cap ownership out of the mythic
  runtime context handoff and into
  `godot/scripts/items/mythic_item_roll_query.gd`.
- Removed the runtime-level `ITEM_COMMANDO_ARM`,
  `COMMANDO_ARM_MAX_STACKS`, `item_commando_arm`, and
  `commando_arm_max_stacks` handoff path from `CONTEXT_CONSTANTS`.
- Simplified the runtime `_get_commando_arm_roll_sum()` /
  `_get_commando_arm_roll_values()` bridge so the roll-query helper owns the
  stack limit directly instead of receiving the full constants dictionary.
- Strengthened `mythic_item_throw_bonus_runtime_smoke` so Commando Arm's roll
  item id and stack cap cannot silently return to the runtime facade.
- `mythic_item_runtime.gd` line count moved from 3215 to 3211. The cumulative
  mythic runtime reduction since this triage started is 6427 -> 3211.

Validation after this split:

- Commando / throw-bonus connection set (`mythic_item_throw_bonus_runtime_smoke`,
  `commando_arm_port_smoke`, `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`): passed.
- `godot/tools/run_headless_load_check.ps1`: passed.
- `godot/tools/run_warning_scan.ps1`: passed, 1251 scripts scanned.
- `git diff --check` for the touched files reported only existing
  line-ending warnings.

## Legacy / Other Isolation Candidates

These should not be committed together with the Godot stability work.

| Bucket | Main paths | Candidate action | Reason |
|---|---|---|---|
| Legacy runtime mega-diff | `pingfighter.py`, `items.py`, `legendary_items.py`, `backgrounds/`, `pillar_*.py`, `events/`, `ui/`, `downtown/`, `entities/` | Isolate first | Frozen Python reference changed broadly. `pingfighter.py` alone is `+26252/-8997`. |
| Legacy item effects | `item_effects/*.py` plus new `item_effects/*.py` | Isolate first | Could be useful parity notes, but not active Godot runtime. |
| Legacy tests | root `tests/test_*.py` | Isolate with Python runtime | Tests target frozen runtime and should not gate Godot sign-off. |
| Legacy assets | root `items/`, root `assets/`, `sounds/`, `images/ui/hud/`, `gameicon/`, loose images/audio | Review separately | Many generated PNG/WAV files; decide whether any should be copied into `godot/assets/`. |
| Packaging / exhibition | `PingFighter_Windows.spec`, `packaging/`, `WINDOWS_DISTRIBUTION_README.md`, `exhibition/`, pitch/portfolio files | Separate task | Distribution and event material are not runtime regression work. |
| Local config | `.vscode/launch.json`, `settings.json`, `.claude/*` | Usually keep out of runtime commit | May be local workflow state. Commit only if intentionally shared. |
| Current docs | `AGENTS.md`, `docs/item_runtime_checklist.md` | Keep with relevant Godot work if intentional | These are current routing/checklist files, unlike frozen legacy docs. |

## Highest-Risk Legacy Files

Top tracked legacy diffs by changed lines:

- `pingfighter.py`: `+26252/-8997`.
- `ui/stage4_shaolin_temple.py`: `+1600/-256`.
- `backgrounds/animated_background_stage2.py`: `+1035/-311`.
- `entities/stage1_boss_sprite.py`: `+1244/-38`.
- `opening.py`: `+1032/-1`.
- `items.py`: `+683/-92`.
- `legendary_items.py`: `+725/-12`.
- `effects_manager.py`: `+665/-12`.

These are preservation candidates only if the user explicitly wants original
PingFighter work retained. For Godot stabilization, stash or otherwise isolate
them before staging Godot changes.

## Recommended Next Actions

1. Continue the next structural task with `mythic_item_runtime.gd` split:
   move per-mythic state / update / draw behavior into focused runtime owners
   while keeping the compatibility facade thin.
2. Review the visible Godot commit candidates below and stage them in small
   behavior groups.
3. Keep `stash@{0}` untouched until the Godot stability set is committed or a
   separate legacy-retention decision is made.

Do not mass-normalize CRLF yet. First isolate legacy changes, then normalize
only the staged Godot set or update source-string tests to normalize newlines
before comparing source snippets.

## Godot Commit Candidates

Current tracked Godot diff groups by path:

- `tests`: 34 tracked smoke files.
- `core-flow`: 16 tracked files.
- `stages-vfx`: 14 tracked files.
- `character-ball-input`: 10 tracked files.
- `ui-hud`: 9 tracked files.
- `items-runtime`: 10 tracked files plus new mythic helper modules.
- `audio`: 1 tracked file.
- `other-godot`: 2 tracked files.

Suggested commit split after legacy isolation:

1. `core/input/loading baseline`
   - `godot/project.godot`
   - `godot/scripts/core/*`
   - `godot/scripts/characters/*_input_reader.gd`
   - `godot/scripts/core/gamepad_input.gd`
   - matching gamepad / loading / scoreboard-defer smoke tests
2. `active item + mythic sync`
   - `godot/scripts/items/*`
   - item-related smoke tests
   - keep this smaller if `mythic_item_runtime.gd` changes continue growing
3. `pause/menu/result UI`
   - `godot/scripts/hud/pause_menu_overlay.gd`
   - `godot/scripts/ui/*`
   - `godot/scenes/main_menu.tscn`
   - result / menu / pause smoke tests
4. `stage/weather/VFX lifecycle`
   - `godot/scripts/stages/*`
   - `godot/scripts/effects/battle_feedback_state.gd`
   - Stage 2/4/5/weather smoke tests
5. `assets/audio/loading`
   - new `godot/assets/bgm/stage2bgm.wav`
   - new `godot/assets/ui/loading/*`
   - related `.import` files
   - should be reviewed for size/import settings before staging
6. `current routing docs`
   - `AGENTS.md`
   - `docs/item_runtime_checklist.md`
   - this triage note, if keeping it in repo history is desired

## Executed Isolation Commands

Safety snapshot:

```powershell
git branch safety/regression-triage-20260522
git diff --binary > regression-triage-20260522-workingtree.patch
```

Legacy runtime / asset isolation:

```powershell
git stash push -u -m "legacy-python-and-root-assets-before-godot-stabilization" -- `
  ':!godot/**' ':!docs/**' ':!AGENTS.md' ':!.claude/**'
```

Post-isolation validation rerun:

```powershell
cd godot
.\tools\run_headless_load_check.ps1
.\tools\run_warning_scan.ps1
```

The 29 modified tracked smoke tests plus the 8 new/boundary smoke tests were
also rerun and passed.

## Stabilization Pass - 2026-05-23

Started the Godot WIP stabilization pass from branch
`checkpoint/godot-wip-20260521-070019`.

Current visible WIP shape:

- Legacy / root runtime changes remain isolated in
  `stash@{0}: legacy-python-and-root-assets-before-godot-stabilization`.
- Visible working tree is still large: 491 porcelain status entries,
  including 478 under `godot/`.
- First commit-candidate lane selected: `core/input/loading baseline`.
  This lane covers gamepad input / vibration, serve-flow gamepad input,
  character-select and runtime-perk gamepad navigation, loading renderer,
  stage-transition loading, scoreboard update defer, scoreboard update, and
  boot-flow settings.

Validation run on 2026-05-23:

```powershell
cd godot
.\tools\run_smoke_tests.ps1 -Tests @(
  'res://tests/gamepad_input_mapping_smoke.gd',
  'res://tests/gamepad_vibration_feedback_smoke.gd',
  'res://tests/serve_flow_gamepad_input_smoke.gd',
  'res://tests/character_select_gamepad_navigation_smoke.gd',
  'res://tests/runtime_perk_gamepad_navigation_smoke.gd',
  'res://tests/battle_loading_screen_renderer_smoke.gd',
  'res://tests/battle_scene_stage_transition_loading_smoke.gd',
  'res://tests/battle_scene_update_driver_scoreboard_defer_smoke.gd',
  'res://tests/scoreboard_update_driver_smoke.gd',
  'res://tests/project_boot_flow_settings_smoke.gd'
)
```

Result: all 10 smoke tests passed.

Recommended next stabilization lane:

1. Stage / commit the `core/input/loading baseline` lane only after reviewing
   the exact file list and confirming no unrelated item / stage / UI assets
   are pulled into the same commit.
2. Then validate the next lane separately, likely `active item + mythic sync`
   or `pause/menu/result UI`, depending on which user-facing risk should be
   reduced first.

Second lane validation on 2026-05-23:

- Lane: `active item + mythic sync`.
- Initial 49-smoke run found one blocker:
  `pandora_legacy_port_smoke` reported that Pandora Legacy did not expose
  its animated mythic icon-sheet metadata.
- Fix: `godot/scripts/items/mythic_item_catalog.gd` now exports
  `PANDORA_LEGACY_ICON_SHEET_PATH` plus the shared mythic frame metadata
  (`icon_frame_count = 32`, `icon_frame_msec = 33`, fill-slot enabled).
  The existing asset
  `res://assets/sprites/items/pandora_legacy_icon_sheet.png` is `1024x32`,
  matching the smoke expectation for 32 smooth 32px frames.
- Focused retry passed:
  `pandora_legacy_port_smoke`, `rainbow_fur_glove_port_smoke`,
  `soul_burst_port_smoke`, `speedgear_port_smoke`,
  `venom_mist_gauntlet_port_smoke`.
- Full `active item + mythic sync` 49-smoke set was rerun and passed.
- Post-fix baseline also passed:
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

Next recommended lane after this pass: `pause/menu/result UI`, because it is
the next high user-facing risk and overlaps result-scene modal flow, click
reaction, pause overlay, and visible layout behavior.

Third lane validation on 2026-05-23:

- Lane: `pause/menu/result UI`.
- Smoke set: `main_menu_flow_smoke`, `pause_menu_overlay_smoke`,
  `character_info_input_redraw_gate_smoke`,
  `character_info_overlay_prewarm_smoke`,
  `character_info_skill_cooldown_pause_smoke`,
  `commando_firearm_tooltip_smoke`,
  `commando_skill_tooltip_preview_smoke`,
  `runtime_perk_active_unlock_flight_smoke`,
  `runtime_perk_gamepad_navigation_smoke`,
  `viper_skill_tooltip_preview_smoke`,
  `stage_clear_result_asset_loader_smoke`,
  `stage_clear_result_layout_helper_smoke`,
  `stage_clear_result_reward_visual_resolver_smoke`,
  `stage_clear_result_scene_click_reaction_smoke`,
  `stage_clear_result_screen_smoke`,
  `stage_clear_result_summary_builder_smoke`, and
  `stage_clear_reward_resolver_smoke`.
- Result: all 17 smoke tests passed.

Next recommended lane: `stage/weather/VFX lifecycle`, followed by a separate
asset/audio/import review.

Fourth lane validation on 2026-05-23:

- Lane: `stage/weather/VFX lifecycle`.
- Initial reruns found four stabilization blockers:
  - `stage2_pillar_render_budget_smoke` was checking the old
    `skill_orb_renderer` variable name. Runtime now routes the visible skill
    orb through `active_skill_orb_renderer`, so the smoke was updated to match
    the live owner.
  - `stage2_router_smoke` expected at least 4 boss-rage rocks, but
    `stage2_crisis_rock_wall_payload_factory_smoke` documents the current
    Champion wall as 3 rocks and Mythic as 5. The router expectation now
    follows the shared factory contract.
  - `stage3_map_port_smoke` exposed stale / invalid imported `.ctex` files for
    Stage 3 Menhera PNG assets even though the source PNG files were valid.
    `ProjectResourceLoader.load_texture()` now prefers a valid raw source image
    and falls back to imported resources when raw loading is unavailable.
  - The raw-first loader briefly conflicted with already-cached Godot texture
    resources in `stage2_boss_idle_sprite_smoke`. The loader now reuses
    `ResourceLoader`'s cached texture first before registering a raw texture
    for the same `res://` path.
- Focused retries passed for the Stage 2 pillar, Stage 2 rock wall/router,
  Stage 2 idle, and Stage 3 map blockers.
- Resource-loader regression smokes passed after the loader fix:
  `battle_boot_resource_prewarm_smoke`,
  `battle_resources_transition_prewarm_smoke`,
  `stage_clear_result_asset_loader_smoke`,
  `commando_resource_sprite_smoke`, `commando_base_grip_asset_smoke`,
  `optimus_resource_placeholders_smoke`,
  `mythic_item_acquisition_cinematic_smoke`, and
  `active_item_effect_renderer_cache_smoke`.
- Full `stage/weather/VFX lifecycle` 30-smoke set was rerun and passed,
  covering Stage 1 HUD/pillar prewarm, Stage 2 boss/rage/rock/water/Viper
  interactions, Stage 3 map/LOD/render-budget paths, Stage 4 map/playfield/Ponk
  lifecycle, Stage 5 Hongryun MVP/lifecycle/visual-shell checks, and shared
  weather render/state checks.
- Final baseline gates passed:
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

Remaining before commit split:

1. Review the exact file list for each commit lane. Several files contain
   larger pre-existing WIP changes beyond the stabilization fixes above.
2. Keep the stage/audio/import review as a separate pass. The smoke suite
   validates loadability and core lifecycle contracts, but it is not a full
   live visual / audio parity review.
3. Watch the Stage 5 visual-shell smoke for the non-fatal Godot
   `ObjectDB instances leaked at exit` warning seen during the passing run.

## Commit Split Pass - 2026-05-23

Working-tree split shape after the stabilization pass:

- Total visible unique changed paths: 496.
- Tracked modified paths: 269.
- Untracked paths include Godot BGM / sound assets, generated sprites, new
  item / mythic helper modules, new gamepad helper modules, and smoke tests.
- Broad overlap counts by filename / path pattern:
  `core_input_loading` 28, `active_items` 147, `mythic_items` 154,
  `pause_menu_result` 55, `stage_weather_vfx` 118, `commando` 39,
  `ball_match` 27, `assets` 46.

Recommended commit order:

1. `input/boot baseline`
   - Intent: shared gamepad input helper, vibration settings, serve-flow
     gamepad launch, boot / intro skip, character-select gamepad navigation,
     main-menu gamepad handling, runtime-perk gamepad navigation, paddle-hit
     vibration routing, and the corresponding focused smokes.
   - Whole-file candidates:
     `godot/scripts/core/gamepad_input.gd`,
     `godot/scripts/core/gamepad_input.gd.uid`,
     `godot/scripts/core/gamepad_vibration_settings.gd`,
     `godot/scripts/core/gamepad_vibration_settings.gd.uid`,
     `godot/scripts/effects/battle_feedback_state.gd`,
     `godot/scripts/ball/paddle_bounce_rally_feedback_router.gd`,
     `godot/scripts/core/serve_flow_controller.gd`,
     `godot/scripts/core/boot_flow_scene.gd`,
     `godot/scripts/ui/character_select_screen.gd`,
     `godot/scripts/ui/main_menu_scene.gd`,
     `godot/tests/gamepad_input_mapping_smoke.gd`,
     `godot/tests/gamepad_input_mapping_smoke.gd.uid`,
     `godot/tests/gamepad_vibration_feedback_smoke.gd`,
     `godot/tests/gamepad_vibration_feedback_smoke.gd.uid`,
     `godot/tests/serve_flow_gamepad_input_smoke.gd`,
     `godot/tests/serve_flow_gamepad_input_smoke.gd.uid`,
     `godot/tests/character_select_gamepad_navigation_smoke.gd`,
     `godot/tests/character_select_gamepad_navigation_smoke.gd.uid`,
     `godot/tests/runtime_perk_gamepad_navigation_smoke.gd`,
     `godot/tests/runtime_perk_gamepad_navigation_smoke.gd.uid`.
   - Patch-split candidates:
     `godot/scripts/resources/gameplay_core_module_catalog.gd` includes
     registry additions for the new helpers, but the file also carries other
     WIP module entries.
     `godot/scripts/core/battle_scene_overlay_input_controller.gd` includes
     gamepad pause / confirm handling and character-info prewarm changes.
     `godot/scripts/hud/runtime_perk_overlay_renderer.gd` includes gamepad
     navigation plus larger visual / flight changes.
     `godot/scripts/items/active_item_slot_controller.gd` includes gamepad
     selected-slot use, but also slot compaction and stage-transition cooldown
     reset logic that belong with active-item runtime.
     `godot/project.godot` should be included only for the boot-flow main
     scene / input-map portions that actually belong to this commit.
   - Validation already passed:
     `gamepad_input_mapping_smoke`, `gamepad_vibration_feedback_smoke`,
     `serve_flow_gamepad_input_smoke`,
     `character_select_gamepad_navigation_smoke`,
     `runtime_perk_gamepad_navigation_smoke`,
     plus the broader first-lane 10-smoke set.

2. `loading/scoreboard transition`
   - Intent: battle loading renderer, stage-transition loading lifecycle,
     deferred scoreboard result dispatch, and boot-flow settings smoke.
   - Keep Stage 5 loading images with this commit only if the renderer's
     Stage 5 loading path is included.
   - Patch-split risk:
     `battle_scene_match_event_driver.gd` also includes weather cleanup and
     stage audio restart work that may fit better with stage/weather lifecycle.

3. `active item runtime`
   - Intent: active-item modular runtime, slot use / cooldown / lifecycle
     behavior, brick wall / throw / Molotov renderer work, active-item smokes,
     and generated active-item effect assets.

4. `mythic item runtime`
   - Intent: mythic helper modules, ownership / update / field / acquisition
     cinematic split, Horn Strawberry, Pandora Legacy metadata, and mythic
     smokes.

5. `pause/menu/result UI`
   - Intent: pause overlay, character-info overlay, tooltip previews,
     main-menu visible flow, result scene / reward resolver / result assets,
     and focused UI smokes.

6. `stage/weather/VFX lifecycle`
   - Intent: Stage 1-5 boss skill HUD / pillar / playfield / weather lifecycle
     changes, BGM assets, Stage 5 Hongryun visuals, and the 30-smoke
     stage/weather set.

7. `docs/localization/tooling`
   - Intent: AGENTS / checklist / ledger updates, localization text changes,
     `.claude` settings changes, and this triage document. Keep repo operating
     rules separate from runtime code when possible.

Next concrete action:

Build the first `input/boot baseline` commit candidate with patch-level staging
for the shared files above, then rerun the first-lane 10-smoke set plus
`run_headless_load_check.ps1` and `run_warning_scan.ps1` before committing.

Input / boot staged candidate on 2026-05-23:

- Staged candidate currently contains 23 paths:
  `paddle_bounce_rally_feedback_router.gd`,
  `runtime_perk_state.gd` (gamepad latch hunks only),
  `battle_scene_overlay_input_controller.gd`, `boot_flow_scene.gd`,
  `gamepad_input.gd`, `gamepad_vibration_settings.gd`,
  `serve_flow_controller.gd`, `battle_feedback_state.gd`,
  `gameplay_core_module_catalog.gd`, `character_select_screen.gd`,
  `main_menu_scene.gd`, and the corresponding `.uid` / smoke-test files.
- Explicitly not staged in this candidate:
  `project.godot`, `active_item_slot_controller.gd`,
  `runtime_perk_overlay_renderer.gd`, Stage 5 loading images, active-item
  runtime files, mythic runtime files, and stage/weather/VFX files.
- `runtime_perk_state.gd` was staged with `git apply --cached` so the index
  includes only shared gamepad navigation / latch behavior. Its larger
  starpoint absorption and Commando weapon highlight hunks remain unstaged for
  later lanes.
- Staged diff hygiene: `git diff --cached --check` passed.
- Focused validation passed:
  `gamepad_input_mapping_smoke`, `gamepad_vibration_feedback_smoke`,
  `serve_flow_gamepad_input_smoke`,
  `character_select_gamepad_navigation_smoke`,
  `runtime_perk_gamepad_navigation_smoke`, `main_menu_flow_smoke`, and
  `project_boot_flow_settings_smoke`.
- Final baseline gates passed after staging:
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

Next concrete action:

Review the staged diff one last time, then either commit it as
`godot: add gamepad input boot baseline` or, if an even narrower first commit
is desired, unstage `battle_scene_overlay_input_controller.gd` and keep it for
the pause / overlay lane.

Committed first split on 2026-05-23:

- Commit: `2c31069ba godot: add gamepad input boot baseline`.
- Scope: the 23-path staged candidate above.
- Post-commit index state: clean; remaining WIP is unstaged / untracked and
  still needs later lane splits.

Second split on 2026-05-23:

- Commit: `a31f02305 godot: defer scoreboard results to physics update`.
- Scope: `battle_scene_scoreboard_update_driver.gd`,
  `battle_scene_update_driver.gd`, `scoreboard_update_driver_smoke.gd`, and
  new `battle_scene_update_driver_scoreboard_defer_smoke.gd`.
- Rationale: this was split out of `loading/scoreboard transition` because it
  is a small independent safety fix. Scoreboard completion now records a
  pending result during overlay update and dispatches it from physics update,
  avoiding normal frame-flow work in the dispatch frame.
- Validation passed:
  `scoreboard_update_driver_smoke`,
  `battle_scene_update_driver_scoreboard_defer_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

Next lane now becomes `stage transition loading / staged prewarm`.

Third split on 2026-05-23:

- Commit: `569f4bc69 godot: add stage5 loading stained glass`.
- Scope: Stage 5 Hongryun transition loading stained-glass PNG / reveal-mask
  assets, `battle_loading_screen_renderer.gd` Stage 5 texture path support,
  `project_resource_loader.gd` raw-PNG-first texture loading / cache guard
  hardening, and `battle_loading_screen_renderer_smoke.gd` Stage 5 coverage.
- Rationale: this was the cleanest independent slice inside the broader
  loading/prewarm lane. It keeps the visible Stage 5 transition art separate
  from the heavier stage-transition weather/audio cleanup and runtime prewarm
  staging work.
- Validation passed:
  `battle_loading_screen_renderer_smoke`,
  `battle_resources_transition_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

Next lane remains `stage transition loading / staged prewarm`, with likely
sub-splits:

- Stage-transition weather/audio cleanup:
  `battle_scene_match_event_driver.gd` plus
  `battle_scene_stage_transition_loading_smoke.gd`.
- Staged runtime prewarm controller:
  `battle_boot_resource_prewarm_controller.gd`,
  `battle_boot_resource_prewarm_smoke.gd`, and any owner modules whose
  `prewarm_assets_step()` / runtime-node prewarm APIs are required by the
  staged contract.

Fourth split on 2026-05-23:

- Commit: `a5d64bd8e godot: clean stage transition weather audio`.
- Scope: `battle_scene_match_event_driver.gd` and
  `battle_scene_stage_transition_loading_smoke.gd`.
- Rationale: stage-transition loading now clears owner weather flags and
  `weather_event_state` immediately / repeatedly during loading, and splits
  gameplay-loop cleanup, old-BGM stop, and next-stage BGM start into separate
  timed work chunks.
- Validation passed:
  `battle_scene_stage_transition_loading_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

Next sub-split is the heavier staged runtime prewarm controller pass.

Fifth split on 2026-05-23:

- Commit: `cbee457a5 godot: stage runtime prewarm steps`.
- Scope: `battle_boot_resource_prewarm_controller.gd` and
  `battle_boot_resource_prewarm_smoke.gd`.
- Rationale: the controller now treats stage-runtime warmup as measurable
  staged work, prefers `prewarm_assets_step()` / runtime-node prewarm APIs
  when modules expose them, keeps active-item runtime warmup incremental, and
  warms the mythic acquisition cinematic through a guarded method call without
  pulling the full mythic runtime refactor into this split.
- Validation passed:
  `battle_boot_resource_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

The remaining staged-prewarm owner implementations are intentionally left in
their feature lanes: active-item runtime, mythic runtime, weather renderer,
Stage 4/5 renderers, Viper FX hosts, and Monkey Blessing delivery.

Sixth split on 2026-05-23:

- Commit: `8f58b63b0 godot: guard active item slot lifecycle`.
- Scope: active-item slot controller / pickup router / runtime lifecycle,
  update, and use facades, plus focused slot, bag-expansion, lifecycle,
  update, use, and prewarm smokes.
- Rationale: active-item slots now support selected-slot gamepad use / cycling,
  compact blank placeholder entries before pickup, preserve inventory while
  clearing cooldown anchors for stage transitions, and block manual or
  smartphone auto-use during serve wait / spawn-intro gates.
- Validation passed:
  `active_item_slot_controller_polling_smoke`,
  `active_item_slot_controller_cooldown_stage_transition_smoke`,
  `active_item_bag_expansion_smoke`,
  `active_item_runtime_lifecycle_facade_direct_smoke`,
  `active_item_runtime_lifecycle_facade_smoke`,
  `active_item_runtime_update_driver_smoke`,
  `active_item_runtime_use_facade_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1271` scripts scanned, no GDScript
  warnings).

Next active-item sub-splits:

- Active-item prewarm / effect renderer cache, including Brick Wall variant
  sheet art.
- Active-item throw / Molotov VFX host path.
- Active-item paddle-sync idle gate.
- Commando Doping Potion firearm-speed tuning should stay with the Commando
  runtime lane, not the general active-item lifecycle split.

Seventh split on 2026-05-23:

- Commit: `e29fbcef7 godot: add brick wall visual variants`.
- Scope: Brick Wall install / hit metadata, active-item effect renderer brick
  wall variant sheet support, render-facade staged prewarm, the generated
  4x2 wall variant PNG + import metadata, and focused Brick Wall / cache /
  prewarm smokes.
- Rationale: Brick Wall now carries a stable visual variant from installation
  through completion, records impact-seeded crack metadata on hits, draws from
  the PNG variant sheet when available, and keeps the procedural wall as the
  fallback path.
- Validation passed:
  `active_item_brick_wall_hit_runtime_smoke`,
  `active_item_brick_wall_installation_smoke`,
  `active_item_effect_renderer_cache_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Eighth split on 2026-05-23:

- Commit: `958cc63e1 godot: gate idle active item paddle sync`.
- Scope: `active_item_effect_update_driver.gd` plus the new
  `active_item_paddle_sync_idle_gate_smoke`.
- Rationale: active-item paddle owner sync now runs immediately when scale
  state changes or an effect is active, but avoids repeated neutral idle sync
  work on every physics frame.
- Validation passed:
  `active_item_paddle_sync_idle_gate_smoke`,
  `active_item_runtime_update_driver_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Ninth split on 2026-05-23:

- Commit: `e8c26f139 godot: remaster active item throw vfx`.
- Scope: active-item throw controller/helpers/renderer, new Molotov modular
  VFX host, and focused dynamite / grenade-flare / molotov / host smokes.
- Rationale: Molotov fire zones now carry stable zone IDs and age metadata,
  the renderer syncs a capped detached VFX host pool in screen-space using the
  playfield layout transform, grenade feedback preserves Python-parity shake,
  and bottom-launched dynamite survives the first fractional frame before
  landing.
- Validation passed:
  `active_item_throw_dynamite_smoke`,
  `active_item_throw_grenade_flare_smoke`,
  `active_item_throw_molotov_smoke`,
  `active_item_molotov_fx_host_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Tenth split on 2026-05-23:

- Commit: `e1a0755fb godot: tune commando firearm cadence`.
- Scope: Commando firearm / weapon controller cadence, Beretta ammo model,
  Doping Potion firearm-speed context, fixed firearm selector HUD art, tooltip
  copy, Stage 1 firearm FX host particle cleanup, and focused Commando runtime
  smokes.
- Rationale: Beretta now uses the current Godot policy of eight direct rounds
  with reload-skill-only replenishment instead of spare magazine reloads;
  Doping Potion now exposes separate Beretta / AK-47 / bazooka rapid-fire
  values; hooked net fields no longer slow the player and keep their rope
  origin synced to the current muzzle; serve-wait held fire is suppressed until
  release; and the fixed firearm HUD prewarms / renders the new net-gun and
  suicide-drone PNG paths.
- Validation passed:
  `commando_emergency_supply_smoke`,
  `commando_firearm_control_state_smoke`,
  `commando_firearm_fire_result_state_smoke`,
  `commando_firearm_runtime_vfx_smoke`,
  `commando_firearm_selector_renderer_smoke`,
  `commando_firearm_tooltip_smoke`,
  `commando_firearm_value_utils_smoke`,
  `commando_save_load_snapshot_smoke`,
  `commando_supply_drop_item_candidates_smoke`,
  `commando_weapon_controller_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Eleventh split on 2026-05-23:

- Commit: `02413b540 godot: share boss skill card hud helpers`.
- Scope: shared boss skill-card HUD metrics / tooltip helpers, Stage 1-5
  boss skill-card renderer layout alignment, Commando firearm-panel avoidance,
  and focused boss skillcard / stage HUD smokes.
- Rationale: boss skill-card stacks now share one avoidance calculation for the
  Commando firearm panel, Stage 2-4 cards gain localized hover tooltips through
  the shared helper, Stage 5 records the fire-machine tooltip copy, and the
  post-active HUD pass seeds the firearm panel rect before later boss card
  draws.
- Validation passed:
  `boss_skill_card_hud_spec_smoke`,
  `stage1_dalji_commando_hud_layout_smoke`,
  `stage3_map_port_smoke`,
  `stage4_map_port_smoke`,
  `stage5_hongryun_visual_shell_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Twelfth split on 2026-05-23:

- Commit: `159736f26 godot: harden stage2 rock lifecycle`.
- Scope: Stage 2 jungle rock collision / crisis wall payloads, water-cannon
  interruption, quake / starpoint / round-boundary cleanup, Stage 2 render LOD
  budgets, boss idle sheet expression gating, and focused Stage 2 lifecycle
  smokes. The shared round-boundary controller also now clears Stage 5 Hongryun
  FX hosts on score / actor reset paths.
- Rationale: rocks now survive and spawn through the intended crisis-wall
  rules, champion / mythic pressure raises the count, explosions and Commando
  projectiles can resolve rock collisions, water cannon charge is interruptible
  by boss hits, quake audio / detached Stage 2 effects are stopped at score and
  round resets, and Stage 2 background rendering keeps bounded LOD behavior.
- Validation passed:
  `stage2_explosion_rock_collision_smoke`,
  `stage2_water_cannon_interrupt_smoke`,
  `stage2_quake_round_boundary_lifecycle_smoke`,
  `stage2_crisis_rock_wall_payload_factory_smoke`,
  `stage2_pillar_render_budget_smoke`,
  `stage2_center_playfield_draw_smoke`,
  `stage2_boss_idle_sprite_smoke`,
  `stage2_router_smoke`,
  `match_score_event_controller_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Thirteenth split on 2026-05-23:

- Commit: `645518ba0 godot: stabilize hongryun inferno fx`.
- Scope: Stage 5 Hongryun staged asset prewarm, inferno charge / trail / burst
  FX host scaling and teardown, boss-side inferno overlay phase gating,
  fire-machine skill-card Korean label, fireball radius / floor collision
  tuning, and the new round-boundary FX lifecycle smoke.
- Rationale: Hongryun Stage 5 now spreads heavy texture preparation through
  `prewarm_assets_step`, keeps detached inferno FX hosts aligned with
  `render_scale`, tears down the charge host when phase 1 exits or the round
  resets, preserves the intended trail pressure / pillar-crossing feel, and
  verifies score / actor cleanup cannot leave the charge ring or particles
  visible.
- Validation passed:
  `stage5_hongryun_round_boundary_lifecycle_smoke`,
  `stage5_hongryun_mvp_runtime_smoke`,
  `stage5_hongryun_visual_shell_smoke` (passed with a Godot ObjectDB leak
  warning),
  `battle_boot_resource_prewarm_smoke`,
  `match_score_event_controller_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Fourteenth split on 2026-05-23:

- Commit: `5ad1bbf3d godot: tune stage3 render lod`.
- Scope: Stage 3 shared render-quality LOD routing, severe-LOD Kuromi fallback
  draw path, pillar HUD static-LOD context, staged Menhera skill-effect prewarm,
  Stage 3 starpoint drop floor culling, and perf logger Stage 3 / Stage 5 hot
  label surfacing.
- Rationale: Stage 3 no longer relies only on Viper-specific LOD signals;
  Soldier / Smasher runs under 72-FPS or high-refresh render policy now trim the
  same expensive Kuromi, Menhera effect, boss, and pillar HUD work. Prewarm also
  advances effect assets in small chunks instead of monolithically warming the
  whole renderer.
- Validation passed:
  `stage3_kuromi_severe_lod_smoke`,
  `stage3_pillar_hud_lod_smoke`,
  `stage3_shared_render_quality_lod_smoke`,
  `stage3_menhera_effect_render_budget_smoke`,
  `stage3_map_port_smoke`,
  `battle_perf_logger_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings).

Fifteenth split on 2026-05-23:

- Commit: `a2961bede godot: tune stage4 weather rendering`.
- Scope: shared weather event draw visibility / LOD routing, sand terrain
  dissolve and coalesced rendering, Stage 4 bird facing / starpoint cleanup,
  red-moon fragment visual scale and self-rotation, Stage 4 playfield
  render-quality LOD, and staged Ponk FX host runtime prewarm.
- Rationale: inactive or blank-owner weather no longer burns a playfield draw
  sample, generated weather textures prewarm in chunks, sand walls retain a
  dissolving visual after weather ends while collision turns off immediately,
  and Stage 4 decorative particles / moon fragments / Ponk hosts stay within
  the new render-budget checks.
- Validation passed:
  `weather_event_render_budget_smoke`,
  `weather_event_state_smoke`,
  `stage4_bird_event_render_budget_smoke`,
  `stage4_playfield_render_budget_smoke`,
  `stage4_ponk_fx_host_prewarm_smoke`,
  `stage4_ponk_round_boundary_lifecycle_smoke`,
  `stage4_map_port_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1272` scripts scanned, no GDScript
  warnings). The first warning-scan attempt hit an unrelated dirty
  `stage1_balloon_event.gd` parser typo; that working-tree typo was corrected
  before rerunning the required checks.

Sixteenth split on 2026-05-23:

- Commit: `e77d413f0 godot: clean stage1 starpoint lifecycle`.
- Scope: Stage 1 balloon-event starpoint drop cleanup when leaving the stage,
  floor-boundary culling aligned to the spawn clamp, and a focused lifecycle
  smoke for those two edges.
- Rationale: mid-flight Stage 1 starpoint drops and particles should not freeze
  in the event instance during stage transitions and resume later from stale
  positions. The floor cull now matches the same bottom boundary used when
  spawning bonus drops, preventing visible floor-hugging leftovers.
- Validation passed:
  `stage1_balloon_starpoint_lifecycle_smoke`,
  `stage1_balloon_event_render_budget_smoke`,
  `star_detector_port_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1273` scripts scanned, no GDScript
  warnings).

Seventeenth split on 2026-05-23:

- Commit: `e40423f1e Port horn strawberry mask mythic runtime`.
- Scope: Horn Strawberry Mask mythic item runtime modules, command listener,
  field / eat / bomb / horn-charge states, transform cinematic renderer,
  pillar HUD renderer, player skill-lock input proxy, audio assets, mythic
  helper-module split wiring, and focused Horn Strawberry / mythic stat smokes.
- Rationale: Horn Strawberry now has a dedicated Godot runtime path instead of
  being folded into broader item or player-control modules, with audio / VFX /
  round-boundary and HUD surfaces represented by explicit owners.
- Validation note: this entry records the already-landed split observed before
  the BGM follow-up pass. The subsequent pass completed
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` across the post-split project.

Eighteenth split on 2026-05-23:

- Commit: `f2b2592f9 Switch stage BGM assets to ogg`.
- Scope: Stage 2 / 3 / 4 / 5 BGM runtime paths now point at compressed OGG
  assets, Stage 2 BGM cold-start selection ensures both candidate tracks are
  loaded before random choice, and Stage 5 Hongryun now has a direct BGM asset
  load smoke.
- Rationale: the large WAV battle tracks are no longer the default runtime
  BGM assets, while Stage 2's two-track selection remains robust before the
  normal audio setup lifecycle has warmed both players.
- Validation passed:
  `stage2_bgm_smoke`,
  `stage3_map_port_smoke`,
  `stage4_bgm_prime_smoke`,
  `stage4_map_port_smoke`,
  `stage5_hongryun_mvp_runtime_smoke`,
  `game_audio_volume_settings_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1273` scripts scanned, no GDScript
  warnings). Godot still emitted the existing Windows root-certificate message;
  `game_audio_volume_settings_smoke` also printed its existing ObjectDB exit
  warning but passed under the smoke wrapper.

Nineteenth split on 2026-05-23:

- Commit: `cb58a93a8 godot: add commando weapon change cue`.
- Scope: Commando / Soldier firearm switch and reset input now routes through
  `weapon.wav`, rental firearm pickups trigger the same acquisition cue, and
  Commando input reads gamepad supply-hold / right-stick firearm cycle /
  right-stick reset events. Focused smokes cover mouse wheel, middle mouse,
  gamepad cycle / reset, firearm-runtime reset, and rental pickup audio.
- Rationale: firearm selection changes and newly acquired rental weapons now
  have a dedicated feedback cue instead of relying only on generic item pickup
  or supply-drop sounds, while gamepad firearm controls match the existing
  Godot input mapping.
- Validation passed:
  `commando_weapon_switch_smoke`,
  `commando_firearm_audio_routing_smoke`,
  `commando_supply_drop_audio_cleanup_smoke`,
  `gamepad_input_mapping_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1273` scripts scanned, no GDScript
  warnings).

Twentieth split on 2026-05-23:

- Commit: `12d1ae362 Wire gamepad input through character readers`.
- Scope: Smasher and Viper input readers now read shared `GamepadInput`
  movement / primary-action signals, with Smasher's middle-button style reset
  path also accepting the firearm reset input.
- Rationale: non-Commando character readers now consume the same live gamepad
  abstraction as the broader Godot control layer instead of staying keyboard /
  mouse-only at the reader boundary.
- Validation passed:
  `gamepad_input_mapping_smoke`,
  `player_control_deps_builder_smoke`,
  `actor_context_groups_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1274` scripts scanned, no GDScript
  warnings).

Twenty-first split on 2026-05-23:

- Commit: `6970aded2 Add commando firearm HUD drone effects`.
- Scope: Commando firearm HUD now has an AutoSprite suicide-drone hover sheet,
  rainbow acquired-weapon border FX host / shader, suicide-drone control-sheet
  facing from live drone side, explicit hide cleanup when the selector is not
  drawn, and focused selector / pillar HUD / weapon-fire / FX-host lifecycle
  smokes.
- Rationale: the suicide-drone firearm now reads as an active animated HUD
  state instead of a static icon, while acquisition highlights are owned by a
  persistent host that can be warmed, hidden, and lifecycle-tested
  independently.
- Validation passed:
  `commando_firearm_hud_rainbow_fx_host_smoke`,
  `commando_firearm_selector_renderer_smoke`,
  `commando_firearm_pillar_hud_context_smoke`,
  `commando_weapon_fire_sheet_smoke`,
  `stage1_dalji_commando_hud_layout_smoke`,
  `gamepad_input_mapping_smoke`,
  `player_control_deps_builder_smoke`,
  `actor_context_groups_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1274` scripts scanned, no GDScript
  warnings).

Twenty-second split on 2026-05-23:

- Commit: `bf30104ee Add commando skill tooltip previews`.
- Scope: Commando / Soldier skill orb icon coverage now includes
  `emergency_supply`, BattleResources verifies cached texture paths before
  treating a spec as loaded, and Commando skill tooltips get dedicated effect
  previews / control rows for supply drop, emergency reload, and firearm
  skills.
- Rationale: the emergency supply orb now takes the same PNG-first runtime
  path as the other Commando skills, while tooltip previews no longer fall
  back to the Smasher/Viper preview family for Commando-only skill effects.
- Validation passed:
  PNG alpha QA (`1254x1254`, corner alpha `0,0,0,0`, bbox
  `93,64-1160,1152`),
  `commando_skill_tooltip_preview_smoke`,
  `viper_skill_tooltip_preview_smoke`,
  `skill_orb_tooltip_hover_state_perf_smoke`,
  `commando_resource_sprite_smoke`,
  `commando_icon_alias_smoke`,
  `runtime_perk_debug_picker_prewarm_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1274` scripts scanned, no GDScript
  warnings).

Twenty-third split on 2026-05-23:

- Commit: `28858b878 Polish character info perk overlay`.
- Scope: Character-info perk overlay redraw / prewarm behavior was tightened,
  including a focused skill-cooldown pause smoke for hover-driven tooltip
  state.
- Rationale: the character-info panel now keeps perk / skill overlay work
  bounded and validates that tooltip hover state can pause skill cooldown UI
  without causing redraw churn.
- Validation passed:
  `character_info_input_redraw_gate_smoke`,
  `character_info_overlay_prewarm_smoke`,
  `character_info_skill_cooldown_pause_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Twenty-fourth split on 2026-05-23:

- Commit: `de4522bb5 godot: stage active item icon prewarm`.
- Scope: Active item HUD catalog icon prewarm now exposes
  `prewarm_catalog_icons_step()`, batches active / extra / mythic icon loads
  in small chunks, keeps the existing monolithic helper as a compatibility
  wrapper, and releases temporary catalog instances after staged completion.
- Rationale: active / mythic item icon cache building no longer has to happen
  as one loading-frame lump; the boot prewarm controller can spread the work
  across staged loading without changing the eventual icon cache contents.
- Validation passed:
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `active_item_effect_renderer_cache_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Twenty-fifth split on 2026-05-23:

- Commit: `b54691e4e Update pause settings for gamepad and monitor FPS`.
- Scope: Pause / project boot settings now cover gamepad-facing pause-menu
  behavior and monitor FPS cap handling through the focused settings smoke
  surface.
- Rationale: the settings path is now verified as a live Godot runtime
  surface rather than an isolated menu edit, including pause overlay input and
  render FPS cap persistence.
- Validation passed:
  `pause_menu_overlay_smoke`,
  `project_boot_flow_settings_smoke`,
  `render_fps_cap_settings_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Twenty-sixth split on 2026-05-23:

- Commit: `3fe052261 godot: stage monkey blessing delivery prewarm`.
- Scope: Monkey Blessing delivery renderer now exposes staged asset prewarm
  for right / mirrored delivery sheets, keeps the monolithic compatibility
  helper, and the owning state forwards both prewarm entry points.
- Rationale: Monkey Blessing delivery sheet loading can now be spread across
  boot prewarm ticks instead of happening inside the first lazy draw path.
- Validation passed:
  `monkey_blessing_delivery_prewarm_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Twenty-seventh split on 2026-05-23:

- Commit: `52d3c4a02 godot: include hongryun actor in match deps`.
- Scope: Match-stage runtime deps now include
  `stage5_hongryun_actor_renderer`, and the focused deps smoke verifies the
  direct builder plus match-flow facades expose the renderer.
- Rationale: Stage 5 score / round-boundary cleanup paths can now receive the
  Hongryun actor renderer through the normal match-flow dependency surface,
  allowing detached inferno FX hosts to be hidden through `reset_round_fx()`.
- Validation passed:
  `match_stage_runtime_deps_builder_smoke`,
  `stage_runtime_deps_builder_smoke`,
  `match_score_event_controller_smoke`,
  `stage5_hongryun_round_boundary_lifecycle_smoke`,
  `stage5_hongryun_visual_shell_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Twenty-eighth split on 2026-05-23:

- Commit: `a3641582c godot: tighten ball status overlay budget`.
- Scope: Ball status overlay rendering now clears status trails through
  `BallRenderer.clear()`, bounds the fire-weather trail lifetime / render
  count / radius multipliers, avoids stationary trail buildup, and resets
  discontinuous fire-weather trail jumps.
- Rationale: fire-weather ball visuals stay closer to the actual ball radius
  and stop carrying oversized stale trail state across round resets or sudden
  position changes, while the existing Ragnarok overlay budget guard remains
  intact.
- Validation passed:
  `ball_status_overlay_renderer_budget_smoke`,
  `fire_weather_ball_speed_rules_smoke`,
  `weather_event_render_budget_smoke`,
  `ball_render_toggles_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Twenty-ninth split on 2026-05-23:

- Commit: `7ed0b79af godot: include hongryun actor in ball round deps`.
- Scope: Ball round dependency construction now includes
  `stage5_hongryun_actor_renderer` for both the legacy empty-context path and
  the scoped Stage 5 path.
- Rationale: ball reset / serve round-boundary cleanup can now hide Hongryun
  detached inferno FX hosts through the same actor-renderer dependency used by
  match score and result-boundary cleanup.
- Validation passed:
  `ball_round_deps_context_smoke`,
  `ball_dependency_context_scope_smoke`,
  `stage5_hongryun_round_boundary_lifecycle_smoke`,
  `match_score_event_controller_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirtieth split on 2026-05-23:

- Commit: `9321d2683 godot: uncap commando drone ball boost`.
- Scope: Commando suicide-drone ball boost results now publish a shared
  speed-cap override, ball update / frame motion / paddle-bounce velocity
  paths honor the active boost as uncapped, and boss post-hit restoration
  clears the override with the boost state.
- Rationale: the suicide drone's 3x relaunch is a temporary owned ball state,
  not a new steady-state speed cap. The ball can preserve that burst until the
  boss returns it, then normal caps resume.
- Validation passed:
  `commando_firearm_suicide_drone_ball_boost_resolver_smoke`,
  `commando_firearm_runtime_vfx_smoke`,
  `fire_weather_ball_speed_rules_smoke`,
  `rally_speed_cap_progression_smoke`,
  `gamepad_vibration_feedback_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-first split on 2026-05-23:

- Commit: `0e1d39a93 godot: preserve drive hit feedback`.
- Scope: Paddle-bounce post-hit routing now forwards `drive_activated` into
  rally feedback vibration, while the event-router helper keeps the argument
  optional for existing direct callers.
- Rationale: drive paddle hits should keep their stronger feedback identity
  through the post-hit facade instead of being flattened to a normal paddle
  vibration event.
- Validation passed:
  `gamepad_vibration_feedback_smoke`,
  `fire_weather_ball_speed_rules_smoke`,
  `cleanse_port_smoke`,
  `celestial_armor_port_smoke`,
  `shrapnel_armor_port_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-second split on 2026-05-23:

- Commit: `f5bb66681 godot: add laurel shield render LOD`.
- Scope: Laurel Leaf / Sacred Laurel shield rendering now accepts the shared
  battle render-quality effect scale, uses a low-cost polygon leaf path under
  LOD, strides particles under LOD, and keeps the full detailed leaf renderer
  for normal quality.
- Rationale: Laurel shield can remain visually readable at lower render
  quality without carrying the full detailed leaf and particle draw cost on
  every visible frame.
- Validation passed:
  `laurel_leaf_shield_render_budget_smoke`,
  `sacred_laurel_port_smoke`,
  `perk_laurel_shield_port_smoke`,
  `viper_airborne_lod_smoke`,
  `battle_playfield_effects_drawer_character_gate_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-third split on 2026-05-23:

- Commit: `5628d5b14 godot: scale shield kiting projectile visual`.
- Scope: Smasher Shield Kiting projectile rendering now uses an explicit
  `0.70` visual scale across the live shield, trail ghost, glow, panel facets,
  circuit paths, corner nodes, and center core, and exposes the scale through
  the renderer asset-status contract.
- Rationale: the projectile keeps the upgraded procedural pentagon identity
  while reducing its on-field footprint without changing gameplay collision or
  skill timing behavior.
- Validation passed:
  `smasher_shield_kiting_projectile_design_smoke`,
  `smasher_shield_kiting_audio_smoke`,
  `battle_playfield_effects_drawer_character_gate_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-fourth split on 2026-05-23:

- Commit: `97aba167f godot: smooth pillar liquid fill`.
- Scope: Pillar status-orb liquid fill now renders as a bounded sampled
  polygon with smoothed wave-top sampling, calmer animation cadence, explicit
  high-quality / LOD surface steps, polyline wave highlights, and updated HUD
  budget assertions.
- Rationale: the pillar liquid can look smoother on large orbs without
  returning to expensive per-column stair-step drawing, while HUD LOD keeps
  sampling and decorative bands bounded on capped-frame / airborne paths.
- Validation passed:
  `stage1_dalji_commando_hud_layout_smoke`,
  `stage1_pillar_scene_prewarm_smoke`,
  `pillar_status_orb_prewarm_step_smoke`,
  `viper_airborne_lod_smoke`,
  `stage2_pillar_render_budget_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-fifth split on 2026-05-23:

- Commit: `d5156a901 godot: lengthen magnum grip cooldown`.
- Scope: Smasher Magnum Grip now uses a `22.0` second base cooldown in both
  the cooldown map and skill-data tooltip contract, with a focused smoke test
  asserting the config snapshot, tooltip data, orb cooldown map, and live
  activation cooldown all agree.
- Rationale: the magnetic pull's uptime is now lower while player-facing HUD /
  tooltip cooldown data continues to come from the same runtime source as the
  actual activation cooldown.
- Validation passed:
  `smasher_skill_timing_monitor_smoke`,
  `warp_gate_port_smoke`,
  `smasher_wheel_port_smoke`,
  `viper_skill_tooltip_preview_smoke`,
  `mythic_item_cooldown_gear_runtime_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-sixth split on 2026-05-23:

- Commit: `65be9f2f1 godot: let viper blade break stage2 rocks`.
- Scope: Viper Air Blade / Dark Blade projectile advancement now reuses the
  projectile hit rect to resolve Stage 2 rock collisions through either
  `stage_background` or `stage2_pillar_background`, de-duplicating shared
  instances and leaving non-Stage 2 contexts untouched.
- Rationale: Viper's blade projectile can now interact with Stage 2 rock
  hazards through the same normal fragment path used by other rock-destruction
  routes, without changing ball-hit timing or cross-stage behavior.
- Validation passed:
  `stage2_viper_blade_rock_collision_smoke`,
  `viper_blade_rush_port_smoke`,
  `stage2_explosion_rock_collision_smoke`,
  `chaos_spear_stage2_rock_absorb_smoke`,
  `stage2_rock_query_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-seventh split on 2026-05-23:

- Commit: `a3e857d88 godot: preserve and prewarm ignition aura`.
- Scope: Viper Ignition Aura now preserves its active timed buff across normal
  round boundaries, pauses duration consumption during serve-wait / inactive
  ball frames, still clears on explicit hard reset / character reconfigure,
  prewarms its sheet and shared glow caches before first draw, and exposes
  staged FX-host node prewarm for the Viper Chaos Spear / EMP hosts.
- Rationale: Ignition Aura is an intentional cross-round carryover exception,
  but first-use VFX work and detached host setup still need to happen during
  prewarm rather than the first visible battle frame.
- Validation passed:
  `viper_ignition_aura_port_smoke`,
  `chaos_spear_port_smoke`,
  `viper_emp_strike_port_smoke`,
  `viper_airborne_lod_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `effects_audio_round_boundary_smoke`,
  `battle_playfield_effects_drawer_character_gate_smoke`,
  `character_selection_viper_start_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-eighth split on 2026-05-23:

- Commit: `78f3f2dbc godot: restore commando drone stun behavior`.
- Scope: Commando suicide-drone direct boss hits now apply only the original
  short stun with no drift knockback, while the lingering fire zone keeps its
  separate slow tick path.
- Rationale: the drone explosion should freeze the boss briefly on direct hit
  instead of stacking an immediate slow stand-in on top of the later fire-zone
  slow, preserving clearer status semantics for the weapon.
- Validation passed:
  `commando_firearm_runtime_vfx_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Thirty-ninth split on 2026-05-23:

- Commit: `9092e335c godot: add stage1 pillar hud static lod`.
- Scope: Stage 1 pillar HUD now marks capped-frame and high-refresh windows
  with the shared static HUD LOD flag, trims ornamental dash-orb frame layers,
  and uses a bounded sampled liquid-fill fallback so HUD orbs remain visible
  without the full animated wave pass.
- Rationale: Stage 1 should follow the later-stage pillar HUD performance
  lifecycle during expensive frames while preserving a readable orb fill and
  compact frame instead of dropping the visual identity.
- Validation passed:
  `stage1_dalji_commando_hud_layout_smoke`,
  `stage1_pillar_scene_prewarm_smoke`,
  `pillar_status_orb_prewarm_step_smoke`,
  `stage2_pillar_render_budget_smoke`,
  `stage3_pillar_hud_lod_smoke`,
  `viper_airborne_lod_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Fortieth split on 2026-05-23:

- Commit: `05c1eef12 godot: guard mythic item update frame`.
- Scope: Mythic item updates now use the engine physics-frame key for the
  per-tick update guard, with the owner gameplay-frame counter retained only
  as a fallback.
- Rationale: item and mythic update fanouts can run in the same physics tick
  after owner-side frame counters change, so the guard needs a stable tick
  identity to avoid double-updating mythic runtime state.
- Validation passed:
  `item_update_boss_health_reset_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_activation_effect_builder_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-first split on 2026-05-23:

- Commit: `819b96462 godot: reset item cooldowns on stage advance`.
- Scope: Stage-transition preserving reset now clears active-item cooldown
  anchors through `active_item_runtime.reset_for_stage_transition()` or the
  slot-controller fallback, preserves equipped slot identity, and notifies
  mythic item runtime through `on_stage_advance()`.
- Rationale: active item slots should remain equipped across stage advance,
  but stale `last_use_msec` / global cooldown anchors must not block the
  next-stage opening round or newly earned stage-clear rewards.
- Validation passed:
  `match_flow_driver_smoke`,
  `battle_scene_stage_transition_loading_smoke`,
  `active_item_slot_controller_cooldown_stage_transition_smoke`,
  `active_item_runtime_lifecycle_facade_smoke`,
  `active_item_runtime_lifecycle_facade_direct_smoke`,
  `horn_strawberry_round_boundary_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-second split on 2026-05-23:

- Commit: `12ca98dce godot: reset stage5 actor fx on stage reset`.
- Scope: Stage reset now includes `stage5_hongryun_actor_renderer`, and the
  Stage 5 round-boundary lifecycle smoke also verifies that
  `MatchResetController.reset_stage_state()` hides the inferno charge FX host.
- Rationale: Stage 5 Hongryun actor VFX hosts are detached lifecycle state,
  so stage transition / debug reset / full reset must clean them through the
  same stage reset fanout as the state and fire-machine owners.
- Validation passed:
  `stage5_hongryun_round_boundary_lifecycle_smoke`,
  `match_score_event_controller_smoke`,
  `ball_round_deps_context_smoke`,
  `battle_scene_stage_transition_loading_smoke`,
  `stage5_hongryun_mvp_runtime_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-third split on 2026-05-23:

- Commit: `ff83b6e86 godot: add viper blade ball-hit sound`.
- Scope: Viper Air Blade / Dark Blade ball hits now route a dedicated
  `bladetouchball.wav` cue through `viper_skill_audio_router.gd` and
  `game_audio.gd`, with the asset imported under the Godot sound tree.
- Rationale: blade launch and spin already had separate cues; the actual
  ball-contact moment now has its own feedback without changing the existing
  ball-speed, combo, gold, or projectile lifecycle behavior.
- Validation passed:
  `viper_blade_rush_port_smoke`,
  `stage2_viper_blade_rock_collision_smoke`,
  `viper_skill_tooltip_preview_smoke`,
  `game_audio_volume_settings_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-fourth split on 2026-05-23:

- Commit: `40139db4f godot: let gamepad skip stage landing intro`.
- Scope: Stage landing intro input handling now uses the shared
  `GamepadInput.is_intro_skip_event()` path before the keyboard / mouse
  fallback, and the landing background smoke verifies gamepad confirm skip
  finishes the intro while resyncing serve input.
- Rationale: stage-entry cinematic skipping should match boot intro and menu
  gamepad semantics, so controller users can dismiss the landing intro without
  waiting for the full sequence or touching keyboard / mouse.
- Validation passed:
  `stage_landing_intro_background_smoke`,
  `gamepad_input_mapping_smoke`,
  `battle_scene_stage_intro_flow_lifecycle_smoke`,
  `battle_loading_screen_renderer_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-fifth split on 2026-05-23:

- Commit: `8a5e8a0c2 godot: pass weather into playfield draw context`.
- Scope: `BattleDrawPlayfieldSceneContext` now copies owner weather type,
  active flags, and nested weather event context into the shared playfield
  draw dictionary; the weather render budget smoke verifies the context
  builder path directly.
- Rationale: weather rendering and ball draw helpers already consume weather
  fields from the draw context, so stage / owner weather state must survive
  the playfield context split instead of relying on stale module state.
- Validation passed:
  `weather_event_render_budget_smoke`,
  `fire_weather_ball_speed_rules_smoke`,
  `battle_scene_stage_transition_loading_smoke`,
  `commando_boss_health_flow_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-sixth split on 2026-05-23:

- Commit: `9c96be588 godot: enable vram texture compression import`.
- Scope: The repo-local Godot project settings now enable ETC2 / ASTC VRAM
  texture compression import support under the `[rendering]` section.
- Rationale: generated sprite, result, HUD, and VFX assets should have the
  project-level import setting available before the remaining asset-heavy WIP
  is split and reimported.
- Validation passed:
  `.\tools\run_headless_load_check.ps1`.

Forty-seventh split on 2026-05-23:

- Commit: `87be228ae godot: cover commando skill tooltip previews`.
- Scope: The shared skill tooltip preview smoke now covers Commando skill
  metadata, verifies every Commando effect type routes to the Commando
  preview family, checks Supply Drop / Emergency Supply control rows, and
  keeps Emergency Supply copy aligned with full reload behavior.
- Rationale: Commando uses the shared orb tooltip renderer, so preview-family
  dispatch and control-hint coverage need an explicit regression lock beside
  the existing Smasher / Viper assertions.
- Validation passed:
  `viper_skill_tooltip_preview_smoke`,
  `commando_skill_tooltip_preview_smoke`,
  `commando_runtime_routing_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-eighth split on 2026-05-23:

- Commit: `5c209fb7e godot: lock mythic helper constant ownership`.
- Scope: Foul Whistle, Rainbow Fur Glove, and Venom Mist Gauntlet port smokes
  now preload their focused mythic runtime helpers and assert that animation,
  particle, radius, and timing constants stay in those helpers instead of
  returning to the broad `mythic_item_runtime.gd` facade.
- Rationale: the passive mythic runtime split should keep item-specific
  behavior discoverable in focused helpers while the facade only delegates and
  exposes shared snapshots.
- Validation passed:
  `foul_whistle_port_smoke`,
  `rainbow_fur_glove_port_smoke`,
  `venom_mist_gauntlet_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Forty-ninth split on 2026-05-23:

- Commit: `ce43ccfd7 godot: add commando emergency reload cue`.
- Scope: Emergency Supply reloads now prefer a dedicated Commando reload
  cue (`reload.wav`) through `game_audio.gd`, with fallback to the prior
  pistol reload cues. The focused emergency-supply and firearm-audio smokes
  verify the new audio method, asset path, gain, and fallback shape.
- Rationale: Emergency Supply refills every eligible permanent firearm, so
  its success feedback should use a shared reload cue rather than being tied
  to pistol per-round reload audio.
- Validation passed:
  `commando_emergency_supply_smoke`,
  `commando_firearm_audio_routing_smoke`,
  `game_audio_volume_settings_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Fiftieth split on 2026-05-23:

- Commit: `ebe4b380d godot: verify belt icon alpha from loaded textures`.
- Scope: Gravity Belt and Speedgear port smokes now inspect the `Image`
  returned from the Godot-loaded `Texture2D` instead of reloading the source
  PNG path separately before checking transparent corners and alpha bounds.
- Rationale: icon QA should match the actual runtime resource loader and
  import result, so alpha-edge regressions are caught on the texture path the
  equipment UI will use.
- Validation passed:
  `gravitybelt_port_smoke`,
  `speedgear_port_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Fifty-first split on 2026-05-23:

- Commit: `7a3d0ff4f godot: lock more mythic helper constants`.
- Scope: Celestial Armor, Hermes Shoes, and Soul Burst port smokes now preload
  their focused mythic runtime helpers and assert that trigger caps, VFX
  timing, trail limits, gauge costs, and particle constants stay out of the
  broad `mythic_item_runtime.gd` facade.
- Rationale: the passive mythic split should keep item-specific tuning in
  focused helper owners, with the facade delegating rather than accumulating
  per-item constant blocks again.
- Validation passed:
  `celestial_armor_port_smoke`,
  `hermes_shoes_port_smoke`,
  `soul_burst_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Fifty-second split on 2026-05-23:

- Commit: `c484677de godot: lock adversity armor helper contract`.
- Scope: Adversity Armor port smoke now preloads its focused runtime helper,
  asserts that barrier and serve-speed constants stay out of the broad mythic
  facade, and verifies the timer-stack contract at the field-effect renderer
  owner rather than the runtime facade.
- Rationale: Adversity Armor has both gameplay collision state and visible
  timer/VFX state, so the regression lock needs to keep helper ownership and
  renderer timer-gauge routing explicit after the mythic runtime split.
- Validation passed:
  `adversity_armor_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Fifty-third split on 2026-05-23:

- Commit: `04cc78bf2 godot: verify baal sand mound reflection`.
- Scope: Baal's Boots weather port smoke now verifies that sand absorbed
  into the defensive mound rebuilds a collidable mound and reflects an
  incoming boss ball upward through the weather collision API.
- Rationale: the absorb cinematic already restored sand depth, but the
  regression lock also needs to prove the rebuilt mound participates in the
  same gameplay collision path as ordinary sand terrain.
- Validation passed:
  `baal_boots_weather_port_smoke`,
  `weather_event_state_smoke`,
  `weather_event_render_budget_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Fifty-fourth split on 2026-05-23:

- Commit: `b637d9ffa godot: lock pandora legacy icon contract`.
- Scope: Pandora Legacy now has its animated 32-frame mythic icon sheet
  committed under the Godot asset tree, and the port smoke verifies the
  sheet metadata, load size, slot-fill flag, and Pandora-specific runtime
  constant ownership.
- Rationale: Pandora's mythic presentation should be sheet-first like the
  other Godot mythics, while its selection-card constants and Korean active
  item names remain owned by the focused Pandora runtime helper instead of
  drifting back into the broad mythic runtime facade.
- Validation passed:
  `pandora_legacy_port_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1275` scripts scanned, no GDScript
  warnings).

Fifty-fifth split on 2026-05-23:

- Commit: `39ca20e11 godot: route suicide drone through molotov fire zone`.
- Scope: Commando suicide drone residue now routes through the shared
  Molotov fire-zone path instead of maintaining a separate Commando-only
  lingering slow field, and the active-item boss-AI context keeps Molotov
  slow neutral so Smasher plasma and other boss slows no longer multiply
  with a fire-zone obstruction.
- Rationale: fire residue should stay visible / collidable through the
  active-item fire-zone owner, while boss movement slow remains owned by
  explicit slow sources such as spider mines or Smasher plasma. Reusing the
  shared Molotov fire-zone API also avoids double-playing Molotov explosion
  feedback for suicide drone detonations.
- Validation passed:
  `active_item_throw_query_smoke`,
  `active_item_throw_molotov_smoke`,
  `commando_firearm_runtime_vfx_smoke`,
  `commando_arm_port_smoke`,
  `smasher_plasma_parity_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Fifty-sixth split on 2026-05-23:

- Commit: `ceb00915e godot: hide stale starpoint visual hosts`.
- Scope: The shared starpoint drop FX host now tracks active host instances
  and exposes `hide_on_canvas()` / `hide_all_existing_hosts()` cleanup helpers.
  Stage 1 through Stage 4 starpoint draw and stage-exit paths call those
  helpers when drops disappear or a stage is left mid-flight.
- Rationale: starpoint drops render through a detached shader host, so clearing
  logical drop arrays is not enough. Without a direct host cleanup path, stale
  Sprite2D slots can remain visible after round boundaries, stage transitions,
  or empty-drop frames that skip the normal draw fanout.
- Validation passed:
  `common_starpoint_visual_host_smoke`,
  `stage1_balloon_starpoint_lifecycle_smoke`,
  `stage1_balloon_event_render_budget_smoke`,
  `stage2_starpoint_drop_motion_state_smoke`,
  `stage2_starpoint_drop_query_smoke`,
  `stage2_golden_rock_starpoint_smoke`,
  `stage3_map_port_smoke`,
  `stage3_menhera_effect_render_budget_smoke`,
  `stage4_map_port_smoke`,
  `stage4_bird_event_render_budget_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Fifty-seventh split on 2026-05-23:

- Commit: `74bb79772 godot: add commando reload delivery runtime`.
- Scope: Commando Emergency Supply now starts a delayed reload-delivery state
  instead of refilling immediately. The state owns the activation radio cue,
  runs a delivery soldier through staged radio / run / handover / exit phases,
  plays the shared reload cue at handover, settles already-paid pending
  refills on reset, draws through an optional sheet-first renderer with a
  quiet procedural fallback, and is wired through player-control deps, match
  skill deps, effects update / draw fanout, reset fanout, actor module
  catalog registration, and staged boot prewarm.
- Rationale: Emergency Supply now reads as an in-world support action while
  preserving the gameplay spend contract: gauge and cooldown are paid on
  activation, ammo is delivered at the visible handover, and an interrupted
  round does not eat the player's paid refill.
- Validation passed:
  `commando_emergency_supply_smoke`,
  `commando_runtime_routing_smoke`,
  `match_player_skill_deps_builder_smoke`,
  `match_flow_context_groups_smoke`,
  `effects_character_deps_builder_smoke`,
  `effects_deps_builder_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `commando_supply_drop_activation_gate_smoke`,
  `commando_firearm_audio_routing_smoke`,
  `viper_skill_tooltip_preview_smoke`,
  `match_reset_controller_smoke`,
  `update_prewarm_driver_smoke`,
  `battle_playfield_effects_drawer_character_gate_smoke`,
  `effects_update_result_applier_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Fifty-eighth split on 2026-05-23:

- Commit: `d9ca4c2e4 godot: remove viper blade ball touch sfx`.
- Scope: The removed `bladetouchball.wav` asset and import are now fully
  matched by runtime cleanup: `game_audio.gd` no longer creates a missing
  `ViperBladeTouchBallSfx` player, the Viper audio router no longer exposes
  a ball-touch cue helper, and Air Blade / Dark Blade ball-hit motion no
  longer calls that removed cue. The focused Viper blade smoke now locks the
  intended contract: projectile launch audio remains on launch only, while
  ball-hit gameplay, gold, speed caps, follow-up windows, and Stage 2 rock
  collision behavior stay intact.
- Rationale: the dirty worktree had already removed the dedicated wav and
  partial router callsite. Completing the lane avoids missing-asset warnings
  and keeps blade ball hits from depending on a deleted one-shot sound.
- Validation passed:
  `viper_blade_rush_port_smoke`,
  `stage2_viper_blade_rock_collision_smoke`,
  `viper_skill_tooltip_preview_smoke`,
  `game_audio_volume_settings_smoke`,
  `chaos_spear_hit_release_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings). `game_audio_volume_settings_smoke` still emitted an ObjectDB
  leak warning at process exit; it did not fail the smoke run or the warning
  scan.

Fifty-ninth split on 2026-05-23:

- Commit: `b479f5edc godot: smooth pillar gauge liquid fill`.
- Scope: Pillar gauge orbs now smooth the displayed liquid ratio between
  target gauge values, keep the core liquid fill animated even when static
  HUD LOD trims decorative ornament layers, and draw liquid against a tighter
  circular edge with bounded edge-search and surface-highlight work.
- Rationale: gauge liquid is gameplay feedback rather than pure decoration,
  so static HUD LOD should not freeze it. The display-ratio follower also
  removes abrupt jumps while keeping rise / fall response bounded for
  repeated in-battle updates.
- Validation passed:
  `stage1_dalji_commando_hud_layout_smoke`,
  `stage1_pillar_scene_prewarm_smoke`,
  `pillar_status_orb_prewarm_step_smoke`,
  `stage2_pillar_render_budget_smoke`,
  `stage3_pillar_hud_lod_smoke`,
  `viper_airborne_lod_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixtieth split on 2026-05-23:

- Commit: `3998ec141 godot: align commando firearm item text`.
- Scope: Commando / Soldier-facing text now matches the current firearm
  runtime contract: the Beretta unlock perk describes the separate 8-ammo
  permanent firearm with 2x fire rate, improved speed / accuracy, and
  reload-skill-only refill behavior; the Doping Potion localization describes
  pistol / Beretta headshot and legshot odds plus pistol, Beretta, AK-47, and
  bazooka fire-rate coverage. Korean item display name now uses
  `도핑주사기`.
- Rationale: recent Commando firearm runtime work changed Beretta and Doping
  Potion behavior beyond the original pistol-only copy, so catalog and
  localization text needed to stop under-reporting the live effect.
- Validation passed:
  `active_item_catalog_korean_names_smoke`,
  `commando_supply_drop_item_candidates_smoke`,
  `commando_perk_catalog_smoke`,
  `commando_ui_text_audit_smoke`,
  `commando_firearm_runtime_vfx_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-first split on 2026-05-23:

- Commit: `f18fd43f8 godot: absorb starpoints after perk choices`.
- Scope: Runtime perk selection now clears in-flight Stage 1 through Stage 4
  starpoint drop / particle arrays before the mid-round choice modal opens,
  starts a short post-modal absorption effect when the final queued perk choice
  closes, keeps that effect visible through the inactive overlay branch, tracks
  the moving player paddle while the star absorbs, and enriches character-
  restricted perk-card edge rendering with bounded Smasher / Viper / Optimus /
  Soldier marker families. Commando / Soldier firearm unlocks also pulse the
  firearm HUD highlight and play the weapon-change cue when a permanent weapon
  is granted.
- Rationale: collected starpoints should not leave frozen detached drops behind
  the modal, and the choice-to-player feedback should remain visible after the
  modal closes. The firearm unlock cue now matches rental weapon acquisition
  feedback, while the card-edge rendering keeps character-only choices legible
  without adding unbounded draw work.
- Validation passed:
  `runtime_perk_active_unlock_flight_smoke`,
  `runtime_perk_overlay_theme_smoke`,
  `runtime_perk_update_driver_smoke`,
  `common_starpoint_visual_host_smoke`,
  `stage1_balloon_starpoint_lifecycle_smoke`,
  `stage2_starpoint_drop_motion_state_smoke`,
  `stage2_starpoint_drop_query_smoke`,
  `stage2_starpoint_particle_state_smoke`,
  `stage3_map_port_smoke`,
  `stage4_bird_event_render_budget_smoke`,
  `commando_firearm_selector_renderer_smoke`,
  `commando_runtime_routing_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-second split on 2026-05-23:

- Commit: `a47f6dafd godot: add hermes shoes mythic fx host`.
- Scope: Added the missing `mythic_item_hermes_shoes_fx_host.gd` runtime host
  and UID that `mythic_item_field_effect_renderer.gd` already preloads for the
  Hermes Shoes mythic field effect. The host owns the additive under-glow,
  sparkle trail particles, motion accents, fade in / fade out tween, prewarm
  path, and explicit `tear_down()` cleanup.
- Rationale: the renderer had already been split to a detached Hermes Shoes
  host path, but the host file itself was still untracked. Committing it keeps
  fresh checkouts from failing on a missing preload and preserves the intended
  node-hosted VFX lifecycle.
- Validation passed:
  `hermes_shoes_port_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-third split on 2026-05-23:

- Commit: `974ddb226 godot: prewarm mythic acquisition cinematic`.
- Scope: Mythic / legendary acquisition cinematic now exposes a static
  `prewarm_assets()` path, caches generated backdrop / vignette / white-flash
  textures across hosts, calls prewarm from `_ready()`, and accepts gamepad
  confirm input through the shared `GamepadInput` helper. The acquisition
  cinematic smoke now verifies that `prewarm_acquisition_cinematic()` creates
  a hidden attached host and that field pickup startup reuses it.
- Rationale: acquisition reveal should not build large generated textures on
  the first visible pickup frame, and controller users need the same confirm
  path as mouse / keyboard / touch users.
- Validation passed:
  `mythic_item_acquisition_cinematic_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-fourth split on 2026-05-23:

- Commit: `968a1ff4a godot: tighten mythic field smoke coverage`.
- Scope: Mythic activation and field-render smokes now assert the split helper
  contracts instead of old inline runtime methods: activation particles / bolts
  are built through `mythic_item_activation_effect_runtime.gd`, runtime facade
  constants stay out of `mythic_item_runtime.gd`, Poseidon draw caps tolerate
  the current capped strategy, Ragnarok stun draw stays random-free, and
  field-effect visibility routes through the focused helper that includes
  acquisition cinematic state.
- Rationale: the item runtime refactor moved behavior into focused helpers, so
  tests should guard those ownership boundaries and render-budget contracts
  directly rather than relying on removed bridge methods.
- Validation passed:
  `mythic_item_activation_effect_builder_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-fifth split on 2026-05-23:

- Commit: `0e0cf2fd3 godot: add mythic runtime helper smokes`.
- Scope: Added focused mythic helper smoke coverage for capacity / gauge
  items, resource bonus items, cooldown gear, progression bonuses, AI assist
  helpers, throw / Commando Arm bonuses, sensor / auto-defense items, Foul
  Whistle, perk-choice count bonuses, and ownership-vs-equipped one-time skip
  behavior. Each test targets the current split helper / facade surface rather
  than broad scene startup.
- Rationale: the mythic runtime is now heavily helperized. These smokes make
  the helper ownership boundaries reviewable and prevent later cleanups from
  silently reintroducing constants or grant logic into the main runtime facade.
- Validation passed:
  `mythic_item_stat_bonus_runtime_smoke`,
  `mythic_item_capacity_gauge_runtime_smoke`,
  `mythic_item_resource_bonus_runtime_smoke`,
  `mythic_item_cooldown_gear_runtime_smoke`,
  `mythic_item_progression_bonus_runtime_smoke`,
  `mythic_item_ai_assist_runtime_smoke`,
  `mythic_item_throw_bonus_runtime_smoke`,
  `mythic_item_sensor_auto_defense_runtime_smoke`,
  `mythic_item_foul_whistle_runtime_smoke`,
  `mythic_item_perk_choice_runtime_smoke`,
  `mythic_item_ownership_runtime_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-sixth split on 2026-05-23:

- Commit: `0253fa901 godot: update demo stage progression smoke`.
- Scope: Demo stage progression smoke now matches the staged transition
  contract: gameplay loop cleanup happens before old BGM stop / next-stage BGM
  start, and Stage 4 player clear advances into the current Stage 5 Hongryun
  demo loading gate instead of treating Stage 4 as the end of the demo route.
- Rationale: the live Godot stage mapping has Stage 5 Hongryun as the active
  next stage, so the smoke should protect that progression and the multi-chunk
  audio / prewarm ordering.
- Validation passed:
  `demo_stage_progression_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-seventh split on 2026-05-23:

- Commit: `5763b6895 godot: add knee pads port smoke`.
- Scope: Added the focused Knee Pads port smoke plus missing Godot UID files
  for several existing focused smokes. The Knee Pads smoke verifies catalog
  registration, icon load, roll bounds, equip / owner sync, half-dash-only
  activation, Soldier and Blacksmith gauge charge baselines, audio / feedback /
  orb HUD cues, one-charge-per-half-dash gating, VFX particle lifetime, and
  helper constant ownership.
- Rationale: Knee Pads had runtime helper coverage in the codebase but no
  tracked focused acceptance test. The UID additions keep existing smokes from
  remaining as local editor-generated residue.
- Validation passed:
  `knee_pads_port_smoke`,
  `battle_scene_update_driver_scoreboard_defer_smoke`,
  `stage4_ponk_round_boundary_lifecycle_smoke`,
  `stage_actor_renderer_arity_cache_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-eighth split on 2026-05-23:

- Commit: `be3d15b6a godot: add fire support firearm hud icon`.
- Scope: Commando / Soldier firearm selector now treats Fire Support like the
  other PNG-backed firearms: it prewarms the imagegen HUD icon, exposes the
  path in `build_panel_state()`, draws the PNG before the procedural fallback,
  and keeps a weapon-specific draw rect scale / offset. The selector smoke now
  verifies the fire-support HUD icon path, loadability, expected 1024x1024
  dimensions, and transparent corners.
- Rationale: clean checkouts need the accepted Fire Support HUD icon tracked
  alongside the code path that expects it. This keeps the fixed left-pillar
  firearm HUD from falling back to the old procedural silhouette.
- Validation passed:
  `commando_firearm_selector_renderer_smoke`,
  `stage1_dalji_commando_hud_layout_smoke`,
  `battle_boot_resource_prewarm_smoke`,
  `stage5_hongryun_visual_shell_smoke` (focused no-repro pass for the old
  ObjectDB leak note),
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1277` scripts scanned, no GDScript
  warnings).

Sixty-ninth split on 2026-05-23:

- Commit: `418356131 godot: add exhibition reset hotkey`.
- Scope: Added an `ExhibitionResetHandler` autoload that owns F7 as a global
  booth reset key, returns to `main_menu.tscn`, resets the persistent
  `GameSelectionState` stage / league defaults, and clears the one-shot battle
  logo skip flag. The battle overlay input controller no longer binds F7 to
  the player-customization debug overlay, and the customization overlay smoke
  now verifies the debug flag behavior directly instead of relying on the old
  key binding.
- Rationale: exhibition / showcase builds need a single always-on reset key
  that works across menus and battle scenes without racing a debug overlay
  binding.
- Validation passed:
  `exhibition_reset_handler_smoke`,
  `debug_menu_direct_switch_smoke`,
  `player_customization_debug_overlay_smoke`,
  `project_boot_flow_settings_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1279` scripts scanned, no GDScript
  warnings).

Seventieth split on 2026-05-23:

- Commit: `97452a115 godot: add fire support aircraft texture`.
- Scope: Stage 1 Commando firearm renderer now prewarms and draws the
  imagegen Fire Support stealth-aircraft texture for active support calls,
  using the existing procedural aircraft silhouette only as a load-failure
  fallback. The VFX remaster smoke asserts that the aircraft texture is part
  of the prewarmed texture-piece plan.
- Rationale: Fire Support already had runtime support-call and aircraft audio
  lifecycles; this commit promotes the accepted aircraft silhouette PNG into
  the renderer so the visual identity no longer depends on procedural
  placeholder geometry.
- Validation passed:
  `commando_firearm_vfx_texture_remaster_smoke`,
  `commando_firearm_renderer_prewarm_gate_smoke`,
  `commando_firearm_stage1_visual_qa_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1279` scripts scanned, no GDScript
  warnings).

Seventy-first split on 2026-05-23:

- Commit: `0956f6bb8 godot: add spider mine animation sheets`.
- Scope: Spider Mine active-item rendering now uses the accepted crawl,
  deploy, and installed-idle 4x4 PNG sheets before falling back to the old
  icon / procedural legs path. The renderer prewarms all three sheets, exposes
  sheet asset status for smoke coverage, maps `spawn` / `embedding` to deploy,
  `floor` / `wall` to crawl, and `armed` to installed idle, and advances the
  spawn/deploy frames from the item delay timer.
- Rationale: Spider Mine already had direct deploy / crawl / embed / armed
  runtime and loop-audio lifecycle coverage. The new sheets promote its
  visible runtime from a static icon plus procedural legs to accepted animated
  item VFX while keeping a load-failure fallback.
- Validation passed:
  `active_item_throw_spider_mine_smoke`,
  `active_item_throw_activation_smoke`,
  `active_item_throw_query_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `.\tools\run_headless_load_check.ps1`, and
  `.\tools\run_warning_scan.ps1` (`1279` scripts scanned, no GDScript
  warnings).

Seventy-second split on 2026-05-23:

- Commit: `5fd3b6a47 godot: route mythic item audio through router`.
- Scope: Mythic item helpers now call `mythic_item_audio_router.gd` directly
  for cue playback and shared screen-shake feedback instead of bouncing
  through `_play_*` / `_apply_*_feedback` wrappers on
  `mythic_item_runtime.gd`. Horn Strawberry skill-state helpers use the
  router's `play_named()` bridge for their existing named cue calls.
- Rationale: the audio router already owns mythic item cue fallback order and
  loop-stop state. Keeping a second set of one-line bridge methods on the
  runtime facade made the remaining monolith look larger without owning real
  behavior.
- `mythic_item_runtime.gd` line count moved from `3378` to `3239` in this
  code split.
- Validation passed:
  focused mythic / Horn Strawberry set
  (`ragnarok_hammer_port_smoke`, `poseidon_trident_port_smoke`,
  `baal_boots_weather_port_smoke`, `celestial_armor_port_smoke`,
  `rainbow_fur_glove_port_smoke`, `venom_mist_gauntlet_port_smoke`,
  `adversity_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `soul_burst_port_smoke`, `knee_pads_port_smoke`,
  `foul_whistle_port_smoke`, `pandora_legacy_port_smoke`,
  `mythic_item_activation_effect_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`, `horn_strawberry_mask_port_smoke`,
  `horn_strawberry_audio_vfx_smoke`, and
  `horn_strawberry_round_boundary_smoke`), then the broader mythic helper set
  (`active_item_pickup_router_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`,
  `mythic_item_capacity_gauge_runtime_smoke`,
  `mythic_item_resource_bonus_runtime_smoke`,
  `mythic_item_cooldown_gear_runtime_smoke`,
  `mythic_item_progression_bonus_runtime_smoke`,
  `mythic_item_ai_assist_runtime_smoke`,
  `mythic_item_throw_bonus_runtime_smoke`,
  `mythic_item_sensor_auto_defense_runtime_smoke`,
  `mythic_item_foul_whistle_runtime_smoke`,
  `mythic_item_perk_choice_runtime_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1279` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Seventy-third split on 2026-05-23:

- Commit: `edc57ee10 godot: route mythic gauge feedback through helper`.
- Scope: Mythic item helpers now call `mythic_item_gauge_feedback.gd`
  directly for battle gauge flash and orb-gauge spin feedback instead of
  bouncing through `_trigger_gauge_feedback()` /
  `_trigger_orb_gauge_spin()` on `mythic_item_runtime.gd`. The new helper is
  registered through `mythic_item_helper_registry.gd` and currently serves
  Kick Charger, Charge Bag, Celestial Armor, Shrapnel Armor, Baal's Boots,
  and Horn Strawberry Mask feedback paths.
- Rationale: gauge flash / HUD-spin routing is shared visual feedback, not
  item-runtime orchestration. Moving it behind a focused helper removes the
  remaining one-line feedback bridges while keeping each item helper's
  feedback intent explicit.
- `mythic_item_runtime.gd` line count moved from `3239` to `3226` in this
  code split.
- Validation passed:
  focused gauge-feedback item set
  (`knee_pads_port_smoke`, `mythic_item_capacity_gauge_runtime_smoke`,
  `celestial_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `baal_boots_weather_port_smoke`, `horn_strawberry_mask_port_smoke`, and
  `horn_strawberry_skill_hud_smoke`), then the broader mythic helper set
  (`passive_item_debug_menu_click_add_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`,
  `mythic_item_resource_bonus_runtime_smoke`,
  `mythic_item_cooldown_gear_runtime_smoke`,
  `mythic_item_progression_bonus_runtime_smoke`,
  `mythic_item_ai_assist_runtime_smoke`,
  `mythic_item_throw_bonus_runtime_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Seventy-fourth split on 2026-05-23:

- Commit: `d1d759f96 godot: remove mythic clear runtime bridges`.
- Scope: Mythic lifecycle, equipment, debug-roll adjustment, and focused smoke
  tests now call clear/reset owners directly for Ragnarok, Poseidon, Kick
  Charger, Soul Burst, Foul Whistle, Revival Charm, Danger Sensor Belt,
  Smartphone, Venom Mist Gauntlet, Rainbow Fur Glove, Adversity Armor,
  Shrapnel Armor, Celestial Armor, Hermes Shoes, and Horn Strawberry Mask.
  The Baal's Boots clear bridge remains on `mythic_item_runtime.gd` because
  it still supplies `BAAL_BOOTS_CONSTANTS` to the Baal helper.
- Rationale: reset / round-clear ownership already lives in focused helpers.
  Keeping private `_clear_*` bridges on the runtime facade obscured the real
  lifecycle owner and made smoke tests depend on methods that were never part
  of the scene-facing API.
- `mythic_item_runtime.gd` line count moved from `3226` to `3124` in this
  code split.
- Validation passed:
  `passive_item_debug_menu_click_add_smoke`,
  `ragnarok_hammer_port_smoke`, `poseidon_trident_port_smoke`,
  `knee_pads_port_smoke`, `soul_burst_port_smoke`,
  `foul_whistle_port_smoke`, `revival_port_smoke`,
  `danger_sensor_belt_port_smoke`, `smartphone_port_smoke`,
  `venom_mist_gauntlet_port_smoke`, `rainbow_fur_glove_port_smoke`,
  `adversity_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `celestial_armor_port_smoke`, `hermes_shoes_port_smoke`,
  `baal_boots_weather_port_smoke`, `horn_strawberry_mask_port_smoke`,
  `horn_strawberry_round_boundary_smoke`,
  `mythic_item_ai_assist_runtime_smoke`,
  `mythic_item_foul_whistle_runtime_smoke`,
  `mythic_item_sensor_auto_defense_runtime_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_ownership_runtime_smoke`, and
  `mythic_item_field_render_budget_smoke`, plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Seventy-fifth split on 2026-05-23:

- Commit: `16b54b4db godot: drop unused mythic helper bridges`.
- Scope: Removed unused private bridge methods from `mythic_item_runtime.gd`
  for old Poseidon capture helpers, Smartphone subhelpers, Venom Mist
  particle / boss-gauge helper calls, Rainbow Fur Glove particle / cooldown
  helper calls, Adversity / Shrapnel / Celestial Armor helper calls, unused
  Poseidon vortex helper calls, unused Baal visual/combat helper calls, and
  old Ragnarok / Knee Pads / Soul Burst utility bridge calls. No external
  callsites remained for those names.
- Rationale: after the focused helpers started owning their internal work, the
  runtime facade still carried private methods that only re-exported helper
  methods and were no longer referenced. Removing them keeps the facade closer
  to its real scene-facing API.
- `mythic_item_runtime.gd` line count moved from `3124` to `2833` in this
  code split.
- Validation passed:
  `ragnarok_hammer_port_smoke`, `poseidon_trident_port_smoke`,
  `venom_mist_gauntlet_port_smoke`, `rainbow_fur_glove_port_smoke`,
  `adversity_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `celestial_armor_port_smoke`, `hermes_shoes_port_smoke`,
  `baal_boots_weather_port_smoke`, `knee_pads_port_smoke`,
  `soul_burst_port_smoke`, `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`, and
  `mythic_item_snapshot_builder_smoke`, plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Seventy-sixth split on 2026-05-23:

- Commit: `70103509b godot: route mythic roll queries through owner`.
- Scope: Focused mythic helpers now call `mythic_item_roll_query.gd`
  directly for equipped-roll reads, owned/equipped counts, Commando Arm roll
  stacks, and item-roll value reads instead of bouncing through private
  `_get_*` / `_has_*` / `_count_*` bridge methods on
  `mythic_item_runtime.gd`. Revival Charm's consume-equipped behavior moved
  to `mythic_item_ownership_runtime.gd` so the trigger path no longer depends
  on `_consume_equipped_item_name()`.
- Rationale: roll math and ownership mutation already have focused owners.
  Keeping private runtime wrappers made item helpers look coupled to the
  monolith instead of to the actual roll / ownership modules.
- `mythic_item_runtime.gd` line count moved from `2833` to `2778` in this
  code split.
- Validation passed:
  `mythic_item_stat_bonus_runtime_smoke`,
  `mythic_item_resource_bonus_runtime_smoke`,
  `mythic_item_capacity_gauge_runtime_smoke`,
  `mythic_item_cooldown_gear_runtime_smoke`,
  `mythic_item_progression_bonus_runtime_smoke`,
  `mythic_item_ai_assist_runtime_smoke`,
  `mythic_item_throw_bonus_runtime_smoke`,
  `mythic_item_ownership_runtime_smoke`,
  `mythic_item_perk_choice_runtime_smoke`, `revival_port_smoke`,
  `horn_strawberry_mask_port_smoke`, `baal_boots_weather_port_smoke`,
  `celestial_armor_port_smoke`, `ragnarok_hammer_port_smoke`, and
  `poseidon_trident_port_smoke`, plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Seventy-seventh split on 2026-05-23:

- Commit: `21106d14e godot: remove unused mythic owner sync bridges`.
- Scope: `refresh_runtime_perk_scaling()` and
  `mythic_item_roll_query.gd` now call
  `mythic_item_owner_syncer.gd` directly for runtime perk-state reference
  sync. The runtime facade dropped unused private owner-sync detail bridges
  for active-item paddle scale, X clamping, skill-cooldown config sync,
  removed-skill cleanup, dash-token capacity, movement status resistance,
  Gold Digger runtime-perk sync, item perk-level bonus sync, Fuel Pouch gauge
  max, and Boomerang active-slot visuals.
- Rationale: owner synchronization already has a focused module. Keeping
  one-line private detail bridges on `mythic_item_runtime.gd` made roll
  queries and scaling refresh look coupled to the monolith instead of to the
  owner-sync module that owns the actual behavior.
- `mythic_item_runtime.gd` line count moved from `2778` to `2734` in this
  code split.
- Validation passed:
  `mythic_item_stat_bonus_runtime_smoke`,
  `mythic_item_resource_bonus_runtime_smoke`,
  `mythic_item_progression_bonus_runtime_smoke`,
  `mythic_item_ownership_runtime_smoke`,
  `mythic_item_perk_choice_runtime_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `passive_item_debug_menu_click_add_smoke`, and
  `horn_strawberry_mask_port_smoke`, plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Seventy-eighth split on 2026-05-23:

- Commit: `0393ca755 godot: route mythic updates through owners`.
- Scope: `mythic_item_update_runtime.gd` now calls focused update owners
  directly for Smartphone, Kick Charger, Soul Burst, Foul Whistle, Revival
  Charm, Danger Sensor Belt, Venom Mist Gauntlet, Rainbow Fur Glove,
  Celestial Armor, Hermes Shoes, and Horn Strawberry Mask updates instead of
  bouncing through private `_update_*` bridge methods on
  `mythic_item_runtime.gd`. The test-only Foul Whistle frame advance now
  targets `foul_whistle_runtime.update_runtime()` directly, and stale unused
  Ragnarok spark bridge methods were removed from the runtime facade.
- Rationale: the update sequencer already owns the per-frame mythic update
  order. Direct owner calls keep sequencing visible in that module and leave
  only the remaining constant-supplying compatibility wrappers on the runtime
  facade for a later, more careful split.
- `mythic_item_runtime.gd` line count moved from `2734` to `2682` in this
  code split.
- Validation passed:
  focused update / field set
  (`mythic_item_runtime_idle_update_smoke`,
  `mythic_item_foul_whistle_runtime_smoke`, `smartphone_port_smoke`,
  `venom_mist_gauntlet_port_smoke`, `rainbow_fur_glove_port_smoke`,
  `knee_pads_port_smoke`, `soul_burst_port_smoke`,
  `celestial_armor_port_smoke`, `hermes_shoes_port_smoke`,
  `horn_strawberry_mask_port_smoke`, `baal_boots_weather_port_smoke`,
  `ragnarok_hammer_port_smoke`, `poseidon_trident_port_smoke`, and
  `mythic_item_field_render_budget_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Seventy-ninth split on 2026-05-23:

- Commit: `d31bc81b1 godot: route mythic field queries through owners`.
- Scope: Field-effect visibility, field rendering, context building,
  snapshot building, update gating, and owner-sync state writes now read
  Venom Mist alpha, Adversity Armor timer / barrier / visible state,
  Shrapnel Armor visible state, and Ragnarok ball / impact elapsed time
  through the focused owners instead of private getter bridges on
  `mythic_item_runtime.gd`. `mythic_item_ragnarok_runtime.gd` now exposes
  `get_ball_elapsed()` and `get_impact_elapsed()` for these read paths.
- Rationale: these reads are field / snapshot state queries, not scene-facing
  runtime orchestration. Routing them through the helper owners keeps draw
  and sync modules coupled to the actual state owner rather than to private
  facade getters.
- `mythic_item_runtime.gd` line count moved from `2682` to `2654` in this
  code split.
- Validation passed:
  focused field / context set
  (`ragnarok_hammer_port_smoke`, `adversity_armor_port_smoke`,
  `shrapnel_armor_port_smoke`, `venom_mist_gauntlet_port_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_snapshot_builder_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_ownership_runtime_smoke`, `celestial_armor_port_smoke`, and
  `baal_boots_weather_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eightieth split on 2026-05-23:

- Commit: `ffc9bdff7 godot: route mythic update gates through owners`.
- Scope: `mythic_item_update_runtime.gd` now calls
  `mythic_item_update_gate.gd` directly for runtime-work detection and calls
  `poseidon_runtime.poll_idle_dash_trigger()` directly for the idle Poseidon
  path. `mythic_item_poseidon_runtime.gd` now checks transient update work
  through `update_gate` directly, and unused private sensor blocker bridge
  methods were removed from `mythic_item_runtime.gd`.
- Rationale: update-gate decisions and idle Poseidon polling already have
  focused owners. Removing the runtime bridge methods keeps the facade from
  advertising private update helpers that are not scene-facing API.
- `mythic_item_runtime.gd` line count moved from `2654` to `2618` in this
  code split.
- Validation passed:
  focused update-gate set
  (`mythic_item_runtime_idle_update_smoke`, `poseidon_trident_port_smoke`,
  `mythic_item_sensor_auto_defense_runtime_smoke`, `smartphone_port_smoke`,
  `mythic_item_field_render_budget_smoke`, and
  `baal_boots_weather_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-first split on 2026-05-23:

- Commit: `028a0b2de godot: route mythic owner geometry through syncer`.
- Scope: Poseidon Trident and Baal's Boots now read owner player / boss
  centers through `mythic_item_owner_syncer.gd` instead of private
  `_read_owner_player_center()` / `_read_owner_boss_center()` bridge methods
  on `mythic_item_runtime.gd`. The syncer now exposes explicit
  `read_owner_player_center()` and `read_owner_boss_center()` helpers for
  these shared owner-geometry reads.
- Rationale: center reads are owner geometry concerns already adjacent to
  paddle sync / owner state handling, and do not need to be private methods
  on the runtime facade.
- `mythic_item_runtime.gd` line count moved from `2618` to `2605` in this
  code split.
- Validation passed:
  focused geometry set
  (`poseidon_trident_port_smoke`, `baal_boots_weather_port_smoke`,
  `venom_mist_gauntlet_port_smoke`, `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_ownership_runtime_smoke`, and
  `mythic_item_field_render_budget_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notices for `mythic_item_runtime.gd` and
  `mythic_item_baal_boots_runtime.gd`.

Eighty-second split on 2026-05-23:

- Commit: `e11792baf godot: pass baal speed constants to stat bonus owner`.
- Scope: `mythic_item_stat_bonus_runtime.gd` now receives the Baal's Boots
  constants needed for player-speed composition and calls
  `baal_boots_runtime.get_player_speed_multiplier()` directly. The private
  `_get_baal_boots_player_speed_multiplier()` bridge was removed from
  `mythic_item_runtime.gd`.
- Rationale: stat-bonus composition already owns the aggregate player-speed
  multiplier. Passing the one remaining Baal constants dictionary explicitly
  keeps that composition in the stat owner without using a runtime facade
  getter.
- `mythic_item_runtime.gd` line count moved from `2605` to `2601` in this
  code split.
- Validation passed:
  focused speed / stat set
  (`mythic_item_stat_bonus_runtime_smoke`, `baal_boots_weather_port_smoke`,
  `hermes_shoes_port_smoke`, `gold_bar_port_smoke`, and
  `mythic_item_runtime_idle_update_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-third split on 2026-05-23:

- Commit: `ba15e39aa godot: pass mythic update constants to sequencer`.
- Scope: `mythic_item_runtime.gd` now passes Ragnarok, Shrapnel Armor,
  Poseidon, and Baal's Boots constants into `mythic_item_update_runtime.gd`,
  letting the update sequencer call those focused update owners directly.
  Sensor auto-dash now passes Poseidon constants into
  `mythic_item_auto_defense_runtime.gd`, which triggers the Poseidon vortex
  owner directly. The private update and Poseidon-trigger bridge methods were
  removed from the runtime facade.
- Rationale: the update sequencer owns update order, while the focused item
  owners own their constants-sensitive update calls. Passing constants
  explicitly avoids retaining runtime bridge methods just to bind constant
  dictionaries.
- `mythic_item_runtime.gd` line count moved from `2601` to `2586` in this
  code split.
- Validation passed:
  affected mythic update set
  (`mythic_item_runtime_idle_update_smoke`, `ragnarok_hammer_port_smoke`,
  `adversity_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `poseidon_trident_port_smoke`, `baal_boots_weather_port_smoke`,
  `mythic_item_sensor_auto_defense_runtime_smoke`, `smartphone_port_smoke`,
  `mythic_item_field_render_budget_smoke`, and
  `horn_strawberry_mask_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-fourth split on 2026-05-23:

- Commit: `8d9c06e8a godot: pass baal lifecycle constants through item helpers`.
- Scope: Baal's Boots clear / round-clear / weather-arm lifecycle paths now
  receive `BAAL_BOOTS_CONSTANTS` through `mythic_item_lifecycle_runtime.gd`,
  `mythic_item_equipment_facade.gd`, and `mythic_item_debug_inventory.gd`.
  `on_weather_round_start()` now calls the Baal owner directly, and the
  private `_clear_baal_boots_runtime()`, `_clear_baal_boots_round_state()`,
  and `_try_arm_baal_boots_from_weather()` bridges were removed from
  `mythic_item_runtime.gd`.
- Rationale: Baal lifecycle ownership already lives in
  `mythic_item_baal_boots_runtime.gd`. Passing the constants dictionary
  through the lifecycle / equipment / debug helpers removes the last Baal
  constant-supplying clear / arm bridge from the runtime facade.
- `mythic_item_runtime.gd` line count moved from `2586` to `2577` in this
  code split.
- Validation passed:
  focused Baal lifecycle / equipment set
  (`baal_boots_weather_port_smoke`, `mythic_item_ownership_runtime_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`, and
  `poseidon_trident_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-fifth split on 2026-05-23:

- Commit: `afc05b321 godot: route mythic stage immunity through owner`.
- Scope: Ragnarok Hammer and Shrapnel Armor now call
  `mythic_item_stage_immunity.gd` directly for Stage 2 speed-defense boss /
  context immunity checks. The private
  `_is_stage2_speed_defense_context_immune()` and
  `_is_stage2_speed_defense_boss_immune()` bridge methods were removed from
  `mythic_item_runtime.gd`.
- Rationale: Stage 2 speed-defense immunity is a focused stage-immunity
  query owner, not runtime facade behavior. Direct owner calls keep the
  active item and mythic item stage-immunity paths consistent.
- `mythic_item_runtime.gd` line count moved from `2577` to `2569` in this
  code split.
- Validation passed:
  focused stage-immunity set
  (`ragnarok_hammer_port_smoke`, `shrapnel_armor_port_smoke`,
  `stage2_speed_defense_smoke`, `mythic_item_field_render_budget_smoke`, and
  `mythic_item_runtime_idle_update_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-sixth split on 2026-05-23:

- Commit: `3ff03f835 godot: route boomerang pickup bonus through owner`.
- Scope: `mythic_item_equipment_facade.gd` now calls
  `mythic_item_pickup_bonus.gd` directly when granting Reinforced Boomerang
  Gauntlet's immediate Boomerang pickup bonus. The private runtime bridge
  methods for the pickup bonus, bonus-item build, and active-slot-controller
  lookup were removed from `mythic_item_runtime.gd`.
- Rationale: this is an acquisition-side pickup bonus owned by the focused
  pickup helper. Keeping the runtime facade in that path only re-exported
  helper behavior and hid the real owner from the equipment flow.
- `mythic_item_runtime.gd` line count moved from `2569` to `2550` in this
  code split.
- Validation passed:
  focused pickup / equipment set
  (`reinforced_boomerang_gauntlet_port_smoke`,
  `mythic_item_ownership_runtime_smoke`,
  `passive_item_debug_menu_click_add_smoke`, and
  `mythic_item_runtime_idle_update_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-seventh split on 2026-05-23:

- Commit: `b0d7d0e2b godot: route mythic roll metadata through owner`.
- Scope: `mythic_item_equipment_facade.gd` now calls
  `roll_query.has_acquired_quality_identity()` and
  `roll_query.copy_acquired_quality_identity()` directly for acquired quality
  preservation, while `mythic_item_debug_inventory.gd` now calls
  `roll_query.find_roll_option()` directly for roll-editor adjustments. The
  private `_has_acquired_quality_identity()`,
  `_copy_acquired_quality_identity()`, and `_find_roll_option()` bridge
  methods were removed from `mythic_item_runtime.gd`.
- Rationale: acquired quality identity and roll-option lookup are roll
  metadata responsibilities owned by `mythic_item_roll_query.gd`, not the
  runtime facade.
- Runtime facade size: `mythic_item_runtime.gd` moved from `2550` lines to
  `2538` lines.
- Validation: focused mythic / debug / Baal smoke coverage
  (`mythic_item_ownership_runtime_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `mythic_item_perk_choice_runtime_smoke`,
  `baal_boots_weather_port_smoke`, and
  `mythic_item_runtime_idle_update_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-eighth split on 2026-05-23:

- Commit: `83b76a318 godot: route mythic equipment indexing through owner`.
- Scope: equipment, debug, ownership, Revival consume, and owner-sync paths now
  call `mythic_item_equipment_index.gd` directly for inventory / equipped
  index lookup, equipped-item rebuilds, slot canonicalization, slot resolution,
  and accessory-slot enablement. The equipment facade also calls
  `roll_query.apply_roll_overrides()` directly for roll override application,
  and runtime public entry points pass `CONTEXT_CONSTANTS` into the focused
  equipment / Revival helpers. The private `_rebuild_equipped_items()`,
  `_is_single_equipment_item()`, `_find_inventory_index_by_name()`,
  `_find_equipped_inventory_index_by_name()`,
  `_find_equipped_inventory_index_by_slot()`,
  `_resolve_equipment_slot_key()`, `_canonical_equipment_slot_key()`,
  `_apply_roll_overrides()`, and `_is_equipment_slot_enabled()` bridges were
  removed from `mythic_item_runtime.gd`.
- Rationale: inventory / equipment slot indexing is owned by
  `mythic_item_equipment_index.gd`; the runtime facade should keep the public
  item API, not private index and slot-key re-exports.
- Runtime facade size: `mythic_item_runtime.gd` moved from `2538` lines to
  `2497` lines.
- Validation: focused mythic / debug / equipment / Revival coverage
  (`mythic_item_ownership_runtime_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `mythic_item_perk_choice_runtime_smoke`,
  `character_info_equipment_anatomy_smoke`, `revival_port_smoke`, and
  `mythic_item_runtime_idle_update_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Eighty-ninth split on 2026-05-23:

- Commit: `46c3cd1bd godot: route mythic owner sync details through owner`.
- Scope: `mythic_item_update_gate.gd` now calls
  `owner_syncer.sync_transient_owner_state()` and
  `owner_syncer.sync_ragnarok_transient_owner_state()` directly after update
  work, while Horn Strawberry Mask's transform / eat-growth paddle-scale
  refresh now calls `owner_syncer.sync_bulkup_paddle_scale()` directly with
  `CONTEXT_CONSTANTS`. The private `_sync_transient_owner_state()`,
  `_sync_ragnarok_transient_owner_state()`, and `_sync_bulkup_paddle_scale()`
  bridges were removed from `mythic_item_runtime.gd`.
- Rationale: transient owner-state writes and Bulk-Up paddle-scale sync are
  owner-syncer detail methods. Keeping one-line private runtime bridges only
  obscured the real owner without adding public API value.
- Runtime facade size: `mythic_item_runtime.gd` moved from `2497` lines to
  `2486` lines.
- Validation: focused update-gate / Horn Strawberry / Ragnarok / field-render
  coverage (`mythic_item_runtime_idle_update_smoke`,
  `horn_strawberry_mask_port_smoke`,
  `horn_strawberry_round_boundary_smoke`,
  `horn_strawberry_audio_vfx_smoke`,
  `horn_strawberry_skill_hud_smoke`, `ragnarok_hammer_port_smoke`, and
  `mythic_item_field_render_budget_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Ninetieth split on 2026-05-23:

- Commit: `36f1652ff godot: move mythic polish multiplier into roll query`.
- Scope: `mythic_item_roll_query.gd` now owns polish multiplier lookup while
  composing item roll values, including the Transcendent Crown base-polish
  exception. The private `_get_polish_multiplier()` bridge was removed from
  `mythic_item_runtime.gd`.
- Rationale: polish scaling is part of the roll-value composition path and
  should stay with roll-query ownership rather than being re-exported through
  the runtime facade.
- Runtime facade size: `mythic_item_runtime.gd` moved from `2486` lines to
  `2477` lines.
- Validation: focused polish / roll scaling coverage
  (`item_polish_perk_port_smoke`, `dowsing_goggles_port_smoke`,
  `rainbow_fur_glove_port_smoke`, `shrapnel_armor_port_smoke`,
  `transcendent_crown_port_smoke`, and `mythic_item_ownership_runtime_smoke`),
  plus `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1280` scripts scanned, no GDScript
  warnings). `git diff --check` reported only the existing line-ending
  notice for `mythic_item_runtime.gd`.

Ninety-first split on 2026-05-23:

- Commit: `e05f78aa7 godot: split mythic catalog roll helpers`.
- Scope: added `mythic_item_catalog_rolls.gd` for mythic/passive catalog roll
  defaults, random roll generation, rolled-option decoration, roll-field
  synchronization, default roll lookup, and passive quality prefix assignment.
  `mythic_item_catalog.gd` keeps the existing public catalog API and delegates
  those roll helpers to the new owner.
- Rationale: roll generation / synchronization is a distinct catalog subdomain
  and can move without changing the public `MythicItemCatalog` constants or
  caller-facing methods that HUD, reward, pickup, and smoke-test paths use.
- Catalog facade size: `mythic_item_catalog.gd` moved from `2485` lines to
  `2418` lines; the new roll helper is `98` lines.
- Validation: focused catalog / roll / quality coverage
  (`passive_item_quality_prefix_smoke`, `item_polish_perk_port_smoke`,
  `item_field_spawn_pool_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1281` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-second split on 2026-05-23:

- Commit: `74bb06378 godot: split mythic catalog list helpers`.
- Scope: added `mythic_item_catalog_lists.gd` for debug-item and field-spawn
  item list construction. `mythic_item_catalog.gd` keeps the public
  `get_debug_items()` and `get_field_spawn_items()` API while delegating list
  assembly to the new helper.
- Rationale: debug / field-spawn list construction is distinct from item data
  definitions and roll synchronization, so it can move without changing
  external `MythicItemCatalog` constants or caller-facing methods.
- Catalog facade size: `mythic_item_catalog.gd` moved from `2418` lines to
  `2407` lines; the new list helper is `23` lines.
- Validation: focused list / field-spawn / pickup / reward coverage
  (`item_field_spawn_pool_smoke`, `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1282` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-third split on 2026-05-23:

- Commit: `a69a2cd0b godot: split mythic catalog presentation helpers`.
- Scope: added `mythic_item_catalog_presentation.gd` for display-name lookup,
  passive / mythic quality-prefix formatting, and quality color lookup.
  `mythic_item_catalog.gd` keeps the existing public presentation API while
  delegating the `PassiveItemQuality` calls to the new helper.
- Rationale: display / quality presentation is a separate catalog subdomain
  from item definitions, list construction, and roll synchronization.
- Catalog facade size: `mythic_item_catalog.gd` remains `2407` lines after
  replacing the direct preload with the helper field; the new presentation
  helper is `16` lines.
- Validation: focused presentation / quality / reward / pickup coverage
  (`passive_item_quality_prefix_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_pickup_router_smoke`,
  `mythic_item_acquisition_cinematic_smoke`, and
  `active_item_hud_visuals_prewarm_step_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1283` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-fourth split on 2026-05-24:

- Commit: `066b0de36 godot: move mythic catalog roll options into helper`.
- Scope: moved the 42 mythic / passive roll-option source arrays and
  item-name lookup table from `mythic_item_catalog.gd` into
  `mythic_item_catalog_rolls.gd`. Item builder dictionaries now hydrate their
  `"roll_options"` through the public `get_roll_options(item_name)` path
  instead of duplicating roll-option arrays directly.
- Rationale: roll-option definitions are part of the roll catalog subdomain,
  not the item-definition facade. Routing builder hydration through the public
  lookup also leaves one source of truth for default rolls, randomized rolls,
  rolled-option decoration, and tooltip / reward presentation data.
- Catalog facade size: `mythic_item_catalog.gd` moved from `2407` lines to
  `1542` lines; `mythic_item_catalog_rolls.gd` moved from `98` lines to
  `919` lines while absorbing the option source arrays.
- Validation: focused catalog / roll / field-spawn / item-specific mythic
  coverage (`passive_item_quality_prefix_smoke`,
  `item_polish_perk_port_smoke`, `item_field_spawn_pool_smoke`,
  `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `mythic_item_ownership_runtime_smoke`, `pandora_legacy_port_smoke`,
  `horn_strawberry_mask_port_smoke`, `baal_boots_weather_port_smoke`, and
  `commando_arm_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1283` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-fifth split on 2026-05-24:

- Commit: `ea8703205 godot: reuse mythic field order for debug catalog items`.
- Scope: removed the duplicate `DEBUG_ITEM_ORDER` list from
  `mythic_item_catalog.gd`; `get_debug_items()` now uses the public
  `FIELD_SPAWN_ORDER` list that already carried the same item order.
- Rationale: the debug catalog had drift-prone list duplication while the
  live field-spawn order remains the external order source used by HUD,
  pickup, reward, and prewarm paths.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1542` lines to
  `1491` lines.
- Validation: focused debug / field-spawn / pickup / reward coverage
  (`passive_item_debug_menu_click_add_smoke`,
  `item_field_spawn_pool_smoke`, `active_item_pickup_router_smoke`,
  `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1283` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-sixth split on 2026-05-24:

- Commit: `0e3fcda43 godot: split mythic catalog fixed options`.
- Scope: added `mythic_item_catalog_fixed_options.gd` for fixed-option source
  arrays and item-name lookup. Catalog item builders now call
  `get_fixed_options(item_name)` for Speed Gear, Gravity Belt, Revival Charm,
  Gold Bar, Sage Ring, Reinforced Boomerang Gauntlet, and Dash Holder instead
  of duplicating fixed-option arrays directly.
- Rationale: fixed display options are a catalog presentation subdomain and
  should not sit beside field-spawn constants in the item-definition facade.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1491` lines to
  `1434` lines; the new fixed-options helper is `81` lines.
- Validation: focused fixed-option item coverage (`speedgear_port_smoke`,
  `gravitybelt_port_smoke`, `revival_port_smoke`, `gold_bar_port_smoke`,
  `reinforced_boomerang_gauntlet_port_smoke`, and
  `sage_ring_port_smoke`) plus catalog / pickup / reward coverage
  (`active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1284` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-seventh split on 2026-05-24:

- Commit: `89fdc810f godot: split mythic catalog build router`.
- Scope: added `mythic_item_catalog_build_router.gd` for item-name to builder
  dispatch. `mythic_item_catalog.gd` keeps the public `build_item_by_name()`
  API and delegates the route selection while retaining the existing item
  builder functions for now.
- Rationale: build dispatch is separate from item definitions. Moving the
  match table out first shrinks the facade without rewriting the item data
  dictionaries or changing the caller-facing catalog API.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1434` lines to
  `1337` lines; the new build router is `63` lines.
- Validation: focused catalog / build / reward coverage
  (`passive_item_quality_prefix_smoke`,
  `passive_item_debug_menu_click_add_smoke`, `item_field_spawn_pool_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `mythic_item_ownership_runtime_smoke`, `pandora_legacy_port_smoke`, and
  `elixir_of_mastery_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1285` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-eighth split on 2026-05-24:

- Commit: `0700de9d9 godot: move mythic field order into list helper`.
- Scope: moved the `FIELD_SPAWN_ORDER` source array into
  `mythic_item_catalog_lists.gd` while preserving
  `MythicItemCatalog.FIELD_SPAWN_ORDER` as the public alias used by HUD,
  pickup, reward, and prewarm callers.
- Rationale: list ordering belongs with the list-construction helper, and the
  catalog facade should expose the stable public constant without carrying the
  full item-order array inline.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1337` lines to
  `1288` lines; `mythic_item_catalog_lists.gd` now owns the 48-item order
  source.
- Validation: focused field-spawn / debug / pickup / prewarm coverage
  (`item_field_spawn_pool_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_effect_renderer_cache_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1285` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Ninety-ninth split on 2026-05-24:

- Commit: `8431d06d6 godot: move remaining mythic fixed options into helper`.
- Scope: moved the remaining inline fixed-option arrays for Heavenly Cape and
  Horn Strawberry Mask into `mythic_item_catalog_fixed_options.gd`.
  `mythic_item_catalog.gd` now hydrates every `fixed_options` field through
  `get_fixed_options(item_name)`.
- Rationale: fixed-option text now has one owner, so item builders no longer
  mix item identity data with fixed display-option source arrays.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1288` lines to
  `1283` lines; `mythic_item_catalog_fixed_options.gd` now owns all fixed
  option source arrays.
- Validation: focused fixed-option item coverage
  (`heavenly_cape_port_smoke` and `horn_strawberry_mask_port_smoke`) plus
  catalog / reward / pickup coverage (`passive_item_quality_prefix_smoke`,
  `stage_clear_reward_resolver_smoke`, `active_item_pickup_router_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1285` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

Hundredth split on 2026-05-24:

- Commit: `eef657bed godot: split mythic icon metadata helper`.
- Scope: added `mythic_item_catalog_icon_metadata.gd` for the shared mythic
  animated-icon metadata cluster. The mythic item builders now call
  `with_mythic_icon_sheet(item_data, icon_sheet_path)` instead of repeating
  the six `"icon_sheet_path"` / frame-count / frame-msec / inset / fill-slot /
  slot-pad fields in each item dictionary.
- Rationale: animated mythic icon metadata is a catalog presentation data
  concern shared by the 32-frame mythic icon sheets. Centralizing it keeps the
  item builders focused on item identity, chance, rolls, and descriptions
  while preserving the public item-data shape consumed by HUD, cinematic,
  prewarm, reward, and smoke-test paths.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1283` lines to
  `1217` lines; the new icon metadata helper is `14` lines.
- Validation: focused mythic icon / field-spawn / reward / prewarm coverage
  (`active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`, `item_field_spawn_pool_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `stage_clear_reward_resolver_smoke`, `pandora_legacy_port_smoke`,
  `ragnarok_hammer_port_smoke`, `hermes_shoes_port_smoke`,
  `poseidon_trident_port_smoke`, `sacred_laurel_port_smoke`,
  `transcendent_crown_port_smoke`, `heavenly_cape_port_smoke`,
  `horn_strawberry_mask_port_smoke`, `celestial_armor_port_smoke`,
  `baal_boots_weather_port_smoke`, and
  `active_item_effect_renderer_cache_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1286` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

101st split on 2026-05-24:

- Commit: `510af6c39 godot: move mythic icon paths into metadata helper`.
- Scope: moved catalog icon-path and mythic icon-sheet path source data into
  `mythic_item_catalog_icon_metadata.gd`. The catalog facade keeps the two
  public icon-path aliases used by existing smokes
  (`COMMANDO_ARM_ICON_PATH` and `REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH`),
  but item builders now hydrate `"icon_path"` through `get_icon_path(item_name)`
  and mythic sheets through `get_icon_sheet_path(item_name)`.
- Rationale: icon source paths are part of the catalog icon metadata surface,
  not the item-definition body. Keeping lookup data with the animated-icon
  metadata helper avoids another long literal block in
  `mythic_item_catalog.gd` while preserving the public item-data dictionaries
  consumed by pickup, reward, debug, prewarm, HUD, and cinematic paths.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1217` lines to
  `1167` lines; `mythic_item_catalog_icon_metadata.gd` moved from `14` lines
  to `91` lines while absorbing the path lookup tables.
- Validation: focused icon / field-spawn / reward / pickup / prewarm coverage
  (`passive_item_quality_prefix_smoke`, `item_field_spawn_pool_smoke`,
  `passive_item_debug_menu_click_add_smoke`, `active_item_pickup_router_smoke`,
  `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_effect_renderer_cache_smoke`, `commando_arm_port_smoke`,
  `reinforced_boomerang_gauntlet_port_smoke`, `pandora_legacy_port_smoke`,
  `heavenly_cape_port_smoke`, `horn_strawberry_mask_port_smoke`,
  `baal_boots_weather_port_smoke`, and `celestial_armor_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1286` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

102nd split on 2026-05-24:

- Commit: `5863a6f9a godot: split mythic field chance metadata`.
- Scope: added `mythic_item_catalog_spawn_metadata.gd` for item-name field
  spawn chance lookup. `mythic_item_catalog.gd` item builders now hydrate their
  `"chance"` field through `get_field_chance(item_name)` instead of carrying
  `*_FIELD_CHANCE` constants inline.
- Rationale: field-spawn chances are catalog spawn metadata, not item
  identity definitions. Moving them beside the spawn/list helpers leaves the
  item builders focused on item identity, slots, roll fields, icons, and text
  while preserving the public item-data shape used by field spawn, debug,
  pickup, reward, prewarm, Pandora choice weighting, and treasure routes.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1167` lines to
  `1125` lines; the new spawn metadata helper is `56` lines.
- Validation: focused spawn / reward / pickup / prewarm coverage
  (`item_field_spawn_pool_smoke`, `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_effect_renderer_cache_smoke`, `pandora_legacy_port_smoke`,
  `treasure_hunt_runtime_smoke`, `treasure_map_perk_port_smoke`,
  `commando_arm_port_smoke`, `reinforced_boomerang_gauntlet_port_smoke`,
  `baal_boots_weather_port_smoke`, and `celestial_armor_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1287` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

103rd split on 2026-05-24:

- Commit: `c147a276c godot: share mythic catalog base item metadata`.
- Scope: added `mythic_item_catalog_base_metadata.gd` for the common
  item-data base-field cluster used by selected static/no-roll catalog
  builders. Speed Gear, Gravity Belt, Revival Charm, Gold Bar, Smartphone,
  Dash Holder, and Elixir of Mastery now hydrate `"name"`, `"type"`,
  `"rarity"`, `"effect"`, `"slot"`, `"icon_path"`, and `"chance"` through
  `with_item_base(...)` instead of repeating those fields inline.
- Rationale: these base fields are structural catalog metadata. Pulling the
  repeated cluster behind one helper keeps the affected builders focused on
  item-specific display text, fixed options, color, sell/consumable flags, and
  descriptions while preserving the public item-data dictionary shape consumed
  by pickup, reward, debug, prewarm, HUD, ownership, and active-mythic paths.
- Catalog facade size: `mythic_item_catalog.gd` moved from `1125` lines to
  `944` lines; the new base metadata helper is `20` lines.
- Validation: focused base-field / item-runtime coverage
  (`speedgear_port_smoke`, `gravitybelt_port_smoke`, `revival_port_smoke`,
  `gold_bar_port_smoke`, `smartphone_port_smoke`,
  `active_item_smartphone_auto_use_smoke`, `elixir_of_mastery_smoke`,
  `item_field_spawn_pool_smoke`, `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_effect_renderer_cache_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1288` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

104th split on 2026-05-24:

- Commit: `81a70856d godot: centralize static mythic item roll fields`.
- Scope: extended `mythic_item_catalog_base_metadata.gd` with
  `with_static_item_base(...)`. The same static/no-roll builders from the
  base metadata split now receive empty `"rolls"`, empty `"roll_options"`,
  empty `"rolled_options"`, and optional `"fixed_options"` from the helper
  instead of repeating those fields inline.
- Rationale: static item roll metadata is part of the same common catalog
  boilerplate as name/type/slot/chance hydration for these builders. Keeping
  it in one helper preserves the public item-data dictionaries while leaving
  the builder body to show only item-specific text, color, and special flags.
- Catalog facade size: `mythic_item_catalog.gd` moved from `944` lines to
  `918` lines; the base metadata helper moved from `20` lines to `36` lines.
- Validation: focused static-field / item-runtime coverage
  (`speedgear_port_smoke`, `gravitybelt_port_smoke`, `revival_port_smoke`,
  `gold_bar_port_smoke`, `smartphone_port_smoke`,
  `active_item_smartphone_auto_use_smoke`, `elixir_of_mastery_smoke`,
  `item_field_spawn_pool_smoke`, `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_effect_renderer_cache_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`, and
  `mythic_item_ownership_runtime_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1288` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

105th split on 2026-05-24:

- Commit: `3a57a96d0 godot: share rolled mythic item catalog fields`.
- Scope: extended `mythic_item_catalog_base_metadata.gd` with
  `with_rolled_item_base(...)` and moved the repeated base-field plus default
  roll-option hydration for Speed Boots, Danger Sensor Belt, Spike Boots,
  Dowsing Pendulum, Dowsing Goggles, Backpack, Charge Bag, and Battery Pack
  out of the catalog builder bodies.
- Rationale: rolled passive builders were still repeating the same
  name/type/slot/icon/chance and `build_default_rolls` /
  `get_roll_options` / `build_rolled_options` cluster. Centralizing that
  cluster keeps roll hydration in one helper while leaving each builder focused
  on player-facing text and color.
- Catalog facade size: `mythic_item_catalog.gd` moved from `918` lines to
  `830` lines; the base metadata helper moved from `36` lines to `67` lines.
- Validation: focused rolled-passive / reward / prewarm coverage
  (`danger_sensor_belt_port_smoke`,
  `mythic_item_sensor_auto_defense_runtime_smoke`,
  `dowsing_goggles_port_smoke`, `active_item_field_item_motion_smoke`,
  `mythic_item_capacity_gauge_runtime_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`, `item_polish_perk_port_smoke`,
  `hermes_shoes_port_smoke`, `speedgear_port_smoke`,
  `gold_bar_port_smoke`, `item_field_spawn_pool_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_effect_renderer_cache_smoke`, `pandora_legacy_port_smoke`,
  `treasure_hunt_runtime_smoke`, and `treasure_map_perk_port_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1288` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

106th split on 2026-05-24:

- Commit: `3ed396578 godot: apply rolled mythic field helper to passive catalog`.
- Scope: applied the existing `with_rolled_item_base(...)` helper to the next
  passive catalog builder group: Repairman Hammer, Gold Digger, Lucky Coin,
  Adversity Armor, Shrapnel Armor, Cooling Ball, Timer Belt, Fuel Pouch,
  Bluetooth Ring, Star Detector, Foul Whistle, Neural Helmet, and Venom Mist
  Gauntlet.
- Rationale: this group used the same standard passive metadata and default
  roll hydration cluster as the first rolled split. Reusing the helper removes
  the duplicate catalog boilerplate while preserving item-specific
  descriptions, colors, and runtime-facing roll dictionaries.
- Catalog facade size: `mythic_item_catalog.gd` moved from `830` lines to
  `687` lines; the base metadata helper stayed at `67` lines.
- Validation: focused passive item / reward / prewarm coverage
  (`mythic_item_cooldown_gear_runtime_smoke`, `gold_digger_port_smoke`,
  `lucky_coin_port_smoke`, `mythic_item_resource_bonus_runtime_smoke`,
  `bluetooth_ring_port_smoke`, `adversity_armor_port_smoke`,
  `shrapnel_armor_port_smoke`, `foul_whistle_port_smoke`,
  `mythic_item_foul_whistle_runtime_smoke`, `neural_helmet_port_smoke`,
  `mythic_item_ai_assist_runtime_smoke`, `venom_mist_gauntlet_port_smoke`,
  `arm_equipment_slots_port_smoke`, `passive_item_quality_prefix_smoke`,
  `heavenly_cape_port_smoke`, `item_field_spawn_pool_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`, and
  `active_item_effect_renderer_cache_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1288` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

107th split on 2026-05-24:

- Commit: `e5e3bfc66 godot: apply rolled helper to remaining passive catalog items`.
- Scope: applied `with_rolled_item_base(...)` to the remaining standard
  passive catalog builders that do not need fixed-option metadata: Commando
  Arm, Rainbow Fur Glove, Knee Pads, Dash Gear, Soul Burst, Bulk-Up Suit,
  Bulletproof Hat, and Spiked Helmet.
- Rationale: after the earlier rolled helper splits, these builders were the
  remaining passive definitions still carrying the repeated default roll
  cluster inline. The helper keeps the catalog data shape stable while making
  item-specific text and color the only visible builder body.
- Catalog facade size: `mythic_item_catalog.gd` moved from `687` lines to
  `599` lines; the base metadata helper stayed at `67` lines.
- Validation: focused passive item / render-budget / reward / prewarm coverage
  (`commando_arm_port_smoke`, `rainbow_fur_glove_port_smoke`,
  `knee_pads_port_smoke`, `soul_burst_port_smoke`,
  `mythic_item_stat_bonus_runtime_smoke`, `head_defense_items_port_smoke`,
  `neural_helmet_port_smoke`, `arm_equipment_slots_port_smoke`,
  `mythic_item_field_render_budget_smoke`, `item_field_spawn_pool_smoke`,
  `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`, and
  `active_item_effect_renderer_cache_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1288` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

108th split on 2026-05-24:

- Commit: `638ab5c07 godot: apply rolled helper to fixed passive catalog items`.
- Scope: applied `with_rolled_item_base(..., include_fixed_options = true)`
  to the fixed-option passive builders for Sage Ring and Reinforced Boomerang
  Gauntlet.
- Rationale: these two builders use the same rolled passive metadata cluster
  plus fixed-option hydration. Routing both through the helper keeps their
  public item-data dictionaries intact while removing another small repeated
  field block from the catalog facade.
- Catalog facade size: `mythic_item_catalog.gd` moved from `599` lines to
  `575` lines; the base metadata helper stayed at `67` lines.
- Validation: focused fixed-passive / reward / prewarm coverage
  (`sage_ring_port_smoke`, `mythic_item_progression_bonus_runtime_smoke`,
  `transcendent_crown_port_smoke`,
  `reinforced_boomerang_gauntlet_port_smoke`,
  `mythic_item_throw_bonus_runtime_smoke`, `arm_equipment_slots_port_smoke`,
  `item_polish_perk_port_smoke`, `passive_item_quality_prefix_smoke`,
  `item_field_spawn_pool_smoke`, `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`, and
  `active_item_effect_renderer_cache_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1288` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

109th split on 2026-05-24:

- Commit: `87a437223 godot: share mythic icon catalog item hydration`.
- Scope: added the catalog-local `_with_mythic_icon_item(...)` compose helper
  and routed the 32-frame mythic icon-sheet builders through it: Pandora's
  Legacy, Megingjord, Ragnarok Hammer, Hermes Shoes, Poseidon's Trident,
  Sacred Laurel, Transcendent Crown, Heavenly Cape, Horn Strawberry Mask,
  Celestial Armor, and Baal's Boots.
- Rationale: these builders repeated the same mythic base fields, default roll
  hydration, and icon-sheet wrapping. The new helper composes
  `with_rolled_item_base(...)` with `with_mythic_icon_sheet(...)` so the item
  builders keep only display text, description, color, and fixed-option intent.
- Catalog facade size: `mythic_item_catalog.gd` moved from `575` lines to
  `470` lines; the base metadata and icon metadata helpers stayed unchanged.
- Validation: focused mythic icon / reward / prewarm coverage
  (`pandora_legacy_port_smoke`, `item_polish_perk_port_smoke`,
  `mythic_item_perk_choice_runtime_smoke`, `ragnarok_hammer_port_smoke`,
  `hermes_shoes_port_smoke`, `poseidon_trident_port_smoke`,
  `sacred_laurel_port_smoke`, `transcendent_crown_port_smoke`,
  `heavenly_cape_port_smoke`, `horn_strawberry_mask_port_smoke`,
  `celestial_armor_port_smoke`, `baal_boots_weather_port_smoke`,
  `item_field_spawn_pool_smoke`, `passive_item_debug_menu_click_add_smoke`,
  `active_item_pickup_router_smoke`, `stage_clear_reward_resolver_smoke`,
  `treasure_hunt_runtime_smoke`, `treasure_map_perk_port_smoke`,
  `active_item_hud_visuals_prewarm_step_smoke`,
  `active_item_runtime_prewarm_smoke`, and
  `active_item_effect_renderer_cache_smoke`), plus
  `.\tools\run_headless_load_check.ps1` and
  `.\tools\run_warning_scan.ps1` (`1288` scripts scanned, no GDScript
  warnings). `git diff --check` passed.

110th split on 2026-05-24:

- Commit: `3315ea4aa godot: move mythic catalog builders into build router`.
- Scope: moved the catalog-local `_build_*` item dictionary builders and the
  mythic icon compose helper into `mythic_item_catalog_build_router.gd`. The
  public `mythic_item_catalog.gd` file now stays as a facade for catalog
  lookup, presentation, list, fixed-option, icon, spawn chance, and roll APIs.
- Rationale: after the base/static/rolled/icon metadata splits, the remaining
  catalog bulk was item-definition construction. Keeping dispatch and builder
  bodies together in the build-router owner reduces the public catalog facade
  to orchestration while preserving the same public `build_item_by_name()`
  item-data dictionaries.
- Catalog facade size: `mythic_item_catalog.gd` moved from `470` lines to
  `103` lines; `mythic_item_catalog_build_router.gd` moved from `55` lines to
  `430` lines.
- Validation: `.\tools\run_headless_load_check.ps1` passed. Focused catalog
  usage coverage selected by direct `MythicItemCatalog` / build/list/roll API
  references ran `49` smoke scripts and passed, including active item prewarm /
  pickup / reward smokes and every direct passive / mythic item port smoke
  matched by that query. `.\tools\run_warning_scan.ps1` passed with `1288`
  scripts scanned and no GDScript warnings. `git diff --check` passed.

111th split on 2026-05-24:

- Commit: `1b42b5a9f godot: split mythic catalog roll definitions`.
- Scope: added `mythic_item_catalog_roll_definitions.gd` for the mythic /
  passive roll-option source arrays and item-name lookup table. The existing
  `mythic_item_catalog_rolls.gd` helper now keeps roll defaults, random roll
  generation, rolled-option decoration, roll-field synchronization, default
  roll lookup, and passive quality prefix assignment while delegating option
  lookup to the definition owner.
- Rationale: after the item-builder split, `mythic_item_catalog_rolls.gd`
  was mostly static data. Moving the option definitions into a data-only owner
  keeps the public catalog roll helper small and preserves the same
  `get_roll_options(item_name)` duplicate-return contract for builders,
  reward flows, debug inventory, and tooltip/UI consumers.
- Roll helper size: `mythic_item_catalog_rolls.gd` moved from `920` lines to
  `104` lines; the new `mythic_item_catalog_roll_definitions.gd` file is
  `821` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused catalog / roll coverage selected by direct catalog, roll,
  `sync_roll_fields`, `roll_options`, and `rolled_options` references ran
  `51` smoke scripts and passed, including every direct passive / mythic item
  port smoke matched by that query. `.\tools\run_warning_scan.ps1` passed with
  `1289` scripts scanned and no GDScript warnings.

112th split on 2026-05-24:

- Commit: `c425f92e1 godot: split Ragnarok mythic field renderer`.
- Scope: added `mythic_item_ragnarok_field_renderer.gd` for Ragnarok Hammer
  impact-ring, electric-stun overlay, stun-aura, and spark drawing. The shared
  `mythic_item_field_effect_renderer.gd` now preloads that owner and keeps
  runtime-state visibility fanout, perf labels, public render-budget constants,
  and render-budget status reporting.
- Rationale: Ragnarok's field draw path was a self-contained visual branch
  with its own deterministic electric sampling, color ramps, ellipse point
  helper, and spark cap. Moving it to a focused renderer reduces the shared
  mythic field renderer without changing the public `draw_field_effects(...)`
  path or the existing budget-status API.
- Renderer size: `mythic_item_field_effect_renderer.gd` moved from `1365`
  lines to `1185` lines; the new
  `mythic_item_ragnarok_field_renderer.gd` file is `215` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. A focused 6-smoke set covering mythic field render budgets,
  Ragnarok Hammer runtime, and round-boundary audio cleanup passed. A broader
  source-selected field-renderer / Ragnarok set ran `14` smoke scripts and
  passed. `.\tools\run_warning_scan.ps1` passed with `1290` scripts scanned
  and no GDScript warnings.

113th split on 2026-05-24:

- Commit: `6f5aef901 godot: split Poseidon mythic field renderer`.
- Scope: added `mythic_item_poseidon_field_renderer.gd` for Poseidon Trident
  water trail, vortex particle, and water-explosion drawing. The shared
  `mythic_item_field_effect_renderer.gd` keeps Poseidon visibility fanout,
  perf labeling, public render-budget constants, and render-budget status
  reporting while passing those budgets into the focused renderer.
- Rationale: Poseidon's draw path is a self-contained visual branch with a
  separate water-trail cap, vortex-particle stride budget, charge-flash
  explosion cap, and trail-arc budget. Moving the branch keeps the shared
  field-effect renderer focused on orchestration without changing the public
  `draw_field_effects(...)` entry point.
- Renderer size: `mythic_item_field_effect_renderer.gd` moved from `1185`
  lines to `1067` lines; the new
  `mythic_item_poseidon_field_renderer.gd` file is `170` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Source-selected Poseidon / field-renderer coverage ran `9` smoke
  scripts and passed, including `poseidon_trident_port_smoke` and the mythic
  field render-budget smoke. `.\tools\run_warning_scan.ps1` passed with
  `1291` scripts scanned and no GDScript warnings.

114th split on 2026-05-24:

- Commit: `402ede2ba godot: split Horn Strawberry mythic field renderer`.
- Scope: added `mythic_item_horn_strawberry_field_renderer.gd` for Horn
  Strawberry transform cinematic visibility/draw plus stem projectile,
  field-barrier, horn-charge, bomb, explosion, and paint drawing. The shared
  `mythic_item_field_effect_renderer.gd` now keeps Horn Strawberry visibility
  fanout, perf labeling, and public render-budget constants while passing the
  item contexts and budgets into the focused renderer.
- Rationale: Horn Strawberry's field draw branch was independent from the
  other mythic effects and already consumed compact runtime contexts. Moving
  it keeps the shared field-effect renderer focused on orchestration without
  changing the public `draw_field_effects(...)` entry point or transform
  cinematic visibility behavior.
- Renderer size: `mythic_item_field_effect_renderer.gd` moved from `1067`
  lines to `908` lines; the new
  `mythic_item_horn_strawberry_field_renderer.gd` file is `207` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Source-selected Horn Strawberry / field-renderer coverage ran `7`
  smoke scripts and passed, including audio/VFX, mask port, round-boundary,
  skill-HUD, Stage 1 pillar prewarm, and mythic field render-budget smokes.
  `.\tools\run_warning_scan.ps1` passed with `1292` scripts scanned and no
  GDScript warnings.

115th split on 2026-05-24:

- Commit: `bdcf1ce7d godot: split armor mythic field renderer`.
- Scope: added `mythic_item_armor_field_renderer.gd` for Adversity Armor
  barrier/timer/particle drawing and Shrapnel Armor flash, shard, trail, dust,
  and boss-impact drawing. The shared `mythic_item_field_effect_renderer.gd`
  keeps armor visibility fanout, perf labels, public render-budget constants,
  and render-budget status reporting while passing those budgets into the
  focused renderer.
- Rationale: the armor draw branches were self-contained visual code using
  compact runtime contexts and budget constants. Moving them keeps the shared
  mythic field renderer focused on effect orchestration while preserving the
  same public `draw_field_effects(...)` path and right-bottom timer-stack
  behavior for Adversity Armor.
- Renderer size: `mythic_item_field_effect_renderer.gd` moved from `908`
  lines to `725` lines; the new `mythic_item_armor_field_renderer.gd` file is
  `257` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused armor / field-renderer coverage ran `5` smoke scripts and
  passed: `adversity_armor_port_smoke`, `shrapnel_armor_port_smoke`,
  `mythic_item_field_render_budget_smoke`, `head_defense_items_port_smoke`,
  and `arm_equipment_slots_port_smoke`. `.\tools\run_warning_scan.ps1` passed
  with `1293` scripts scanned and no GDScript warnings.

116th split on 2026-05-24:

- Commit: `762c60ecb godot: split momentum mythic field renderer`.
- Scope: added `mythic_item_momentum_field_renderer.gd` for Knee Pads flash
  rings/rays/particles and Soul Burst wind trails, shockwaves, ellipse arcs,
  and dash particles. The shared `mythic_item_field_effect_renderer.gd` keeps
  visibility fanout, perf labels, and public render-budget constants while
  passing the compact runtime state and budgets into the focused renderer.
- Rationale: Knee Pads and Soul Burst are short-lived momentum visuals with
  self-contained procedural drawing and shared recent-entry budget behavior.
  Moving them keeps the shared mythic field renderer focused on orchestration
  without changing the public `draw_field_effects(...)` entry point.
- Renderer size: `mythic_item_field_effect_renderer.gd` moved from `725`
  lines to `608` lines; the new `mythic_item_momentum_field_renderer.gd` file
  is `155` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Source-selected momentum / field-renderer coverage ran `6` smoke
  scripts and passed: `adversity_armor_port_smoke`,
  `baal_boots_weather_port_smoke`, `knee_pads_port_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_runtime_idle_update_smoke`, and `soul_burst_port_smoke`.
  `.\tools\run_warning_scan.ps1` passed with `1294` scripts scanned and no
  GDScript warnings.

117th split on 2026-05-24:

- Commit: `88ac8fa13 godot: split aura mythic field renderer`.
- Scope: added `mythic_item_aura_field_renderer.gd` for Celestial Armor wave
  arcs/shards, Venom Mist fog/field particles, and Rainbow Fur Glove aura
  rings/rays/particles. The shared `mythic_item_field_effect_renderer.gd`
  keeps visibility fanout, perf labels, and public render-budget constants
  while passing aura state, color arrays, and render budgets into the focused
  renderer.
- Rationale: these aura-style field visuals are independent procedural draw
  branches with compact runtime state. Moving them reduces the shared mythic
  field renderer to orchestration plus helper-host management, while preserving
  the public `draw_field_effects(...)` entry point and render-budget status
  contract.
- Renderer size: `mythic_item_field_effect_renderer.gd` moved from `608`
  lines to `437` lines; the new `mythic_item_aura_field_renderer.gd` file is
  `187` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Source-selected aura / field-renderer coverage ran `9` smoke scripts
  and passed, including `celestial_armor_port_smoke`,
  `venom_mist_gauntlet_port_smoke`, `rainbow_fur_glove_port_smoke`,
  `viper_nerve_strike_port_smoke`, and `mythic_item_field_render_budget_smoke`.
  `.\tools\run_warning_scan.ps1` passed with `1295` scripts scanned and no
  GDScript warnings.

118th split on 2026-05-24:

- Commit: `95f47540f godot: split Hermes mythic field renderer`.
- Scope: added `mythic_item_hermes_field_renderer.gd` for Hermes Shoes FX host
  lookup/creation, deferred host attachment, cached canvas ownership, and
  `sync_state(...)` forwarding. The shared `mythic_item_field_effect_renderer.gd`
  keeps Hermes visibility fanout and perf labeling while delegating host
  lifecycle details to the focused renderer.
- Rationale: Hermes Shoes was the last field branch whose host-management
  state lived directly in the shared renderer. Moving it keeps host lifecycle
  ownership next to the Hermes FX host preload and leaves the shared field
  renderer focused on draw orchestration.
- Renderer size: `mythic_item_field_effect_renderer.gd` moved from `437`
  lines to `380` lines; the new `mythic_item_hermes_field_renderer.gd` file
  is `68` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Hermes / field-renderer coverage ran `3` smoke scripts and
  passed: `adversity_armor_port_smoke`, `hermes_shoes_port_smoke`, and
  `mythic_item_field_render_budget_smoke`. `.\tools\run_warning_scan.ps1`
  passed with `1296` scripts scanned and no GDScript warnings.

119th split on 2026-05-24:

- Commit: `ab7a74035 godot: split active throw slip renderer`.
- Scope: added `active_item_throw_slip_renderer.gd` for Banana and Soap
  projectile sprites, landed warning/puddle draws, burst particles, foam
  trails, texture fallback drawing, and the shared trail-thinning helper used
  by those slip items. The shared `active_item_throw_renderer.gd` keeps the
  public draw signature, perf labels, generic windup/throw icon cache, and
  dispatch order while delegating slip visuals to the focused renderer.
- Rationale: Banana and Soap draw branches share the same slip-item visual
  shape and were independent from grenade / flare / molotov / boomerang /
  spider-mine rendering. Moving them lowers active throw renderer size without
  changing runtime state ownership in the throw controller.
- Renderer size: `active_item_throw_renderer.gd` moved from `2244` lines to
  `2022` lines; the new `active_item_throw_slip_renderer.gd` file is `379`
  lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Banana / Soap / throw-renderer coverage ran `7` smoke
  scripts and passed: `active_item_throw_banana_smoke`,
  `active_item_throw_soap_smoke`, `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`, and
  `active_item_runtime_render_facade_direct_smoke`.
  `.\tools\run_warning_scan.ps1` passed with `1297` scripts scanned and no
  GDScript warnings.

120th split on 2026-05-24:

- Commit: `8d1b74f3a godot: split active throw boomerang renderer`.
- Scope: added `active_item_throw_boomerang_renderer.gd` for normal and
  metal Boomerang projectile texture draws, return / gauntlet aura rings,
  trail glow, break particles, texture fallback drawing, and asset prewarm.
  The shared `active_item_throw_renderer.gd` keeps the public draw signature,
  perf labels, generic windup / throw icon cache, and dispatch order while
  delegating Boomerang projectile visuals to the focused renderer.
- Rationale: Boomerang rendering has its own trail, metal-gauntlet texture,
  return-phase glow, and fallback shape, but does not need to own throw
  controller state. Moving it trims the active throw renderer after the
  Banana / Soap split and keeps future Boomerang visual tuning localized.
- Renderer size: `active_item_throw_renderer.gd` moved from `2022` lines to
  `1950` lines; the new `active_item_throw_boomerang_renderer.gd` file is
  `172` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Boomerang / throw-renderer coverage ran `9` smoke scripts
  and passed: `active_item_throw_boomerang_smoke`,
  `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`,
  `reinforced_boomerang_gauntlet_port_smoke`,
  `mythic_item_throw_bonus_runtime_smoke`, and `commando_arm_port_smoke`.
  `.\tools\run_warning_scan.ps1` passed with `1298` scripts scanned and no
  GDScript warnings.

121st split on 2026-05-24:

- Commit: `58bf1cc28 godot: split active throw spider mine renderer`.
- Scope: added `active_item_throw_spider_mine_renderer.gd` for Spider Mine
  icon / sheet asset prewarm, sheet-state selection, spawn / crawl / install
  frame source rects, body / leg / beacon drawing, explosion drawing, break
  particles, and windup fallback drawing. The shared
  `active_item_throw_renderer.gd` keeps public compatibility wrappers and
  texture aliases used by existing smoke tests and prewarm checks, while
  delegating live Spider Mine drawing to the focused renderer.
- Rationale: Spider Mine had the largest remaining self-contained throw
  renderer branch: multiple sprite sheets, state-to-frame math, procedural
  fallback legs, armed beacon logic, and explosion particles. Moving it keeps
  future mine visual tuning local without changing throw controller state or
  public render facade contracts.
- Renderer size: `active_item_throw_renderer.gd` moved from `1950` lines to
  `1711` lines; the new `active_item_throw_spider_mine_renderer.gd` file is
  `367` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Spider Mine / throw-renderer coverage ran `8` smoke scripts
  and passed: `active_item_throw_spider_mine_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`, and
  `commando_arm_port_smoke`. `.\tools\run_warning_scan.ps1` passed with
  `1299` scripts scanned and no GDScript warnings.

122nd split on 2026-05-24:

- Commit: `af5877bef godot: split active throw dynamite renderer`.
- Scope: added `active_item_throw_dynamite_renderer.gd` for Dynamite
  projectile trails / sprites, placed Dynamite countdown badges, warning
  pulses, fuse flames, explosion shockwaves, smoke clouds, sparks, fire
  particles, fallback bundle drawing, and asset prewarm. The shared
  `active_item_throw_renderer.gd` keeps the public draw signature, perf
  labels, generic windup / throw icon cache, and dispatch order while
  delegating Dynamite visuals to the focused renderer.
- Rationale: Dynamite rendering is a cohesive branch with its own placed-item
  countdown HUD, fuse timing, projectile icon, and layered explosion VFX.
  Moving it reduces the active throw renderer without touching throw
  controller explosion state, audio, or round-end detonation behavior.
- Renderer size: `active_item_throw_renderer.gd` moved from `1711` lines to
  `1477` lines; the new `active_item_throw_dynamite_renderer.gd` file is
  `320` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Dynamite / throw-renderer coverage ran `8` smoke scripts
  and passed: `active_item_throw_dynamite_smoke`,
  `active_item_runtime_use_facade_smoke`,
  `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`, and
  `commando_arm_port_smoke`. `.\tools\run_warning_scan.ps1` passed with
  `1300` scripts scanned and no GDScript warnings.

123rd split on 2026-05-24:

- Commit: `b1bcd4275 godot: split active throw tear gas renderer`.
- Scope: added `active_item_throw_tear_gas_renderer.gd` for Tear Gas
  projectile sprites / arming countdowns, smoke-zone haze, shared particle
  draw budget, cached puff texture generation, smoke tone / seed helpers,
  fallback canister drawing, and Tear Gas asset prewarm. The shared
  `active_item_throw_renderer.gd` keeps the public draw signature, perf
  labels, generic windup / throw icon cache, renderer fallback constants, and
  dispatch order while delegating live Tear Gas visuals to the focused
  renderer.
- Rationale: Tear Gas was the largest remaining canvas-draw branch in the
  active throw renderer and had its own procedural puff texture, haze mesh,
  smoke-particle budget, and arming countdown presentation. Moving it
  localizes future smoke tuning while preserving controller state, cooldown
  pause behavior, and render-facade contracts.
- Renderer size: `active_item_throw_renderer.gd` moved from `1477` lines to
  `1078` lines; the new `active_item_throw_tear_gas_renderer.gd` file is
  `420` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Tear Gas / throw-renderer coverage ran `9` smoke scripts
  and passed: `active_item_throw_tear_gas_smoke`,
  `active_item_tear_gas_tuning_smoke`,
  `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`,
  `active_item_boss_skill_cooldown_pause_smoke`, and
  `commando_arm_port_smoke`. `.\tools\run_warning_scan.ps1` passed with
  `1301` scripts scanned and no GDScript warnings.

124th split on 2026-05-24:

- Commit: `b27c3ccfd godot: split active throw molotov renderer`.
- Scope: added `active_item_throw_molotov_renderer.gd` for Molotov
  projectile sprites, hot-core throw trails, fire-zone host-pool syncing,
  detached FX host playfield projection, fallback flame ellipses, per-flame
  ember drawing, fallback bottle drawing, icon texture loading, and Molotov
  asset prewarm. The shared `active_item_throw_renderer.gd` keeps the public
  draw signature, perf labels, generic windup pose / throw icon cache, and
  dispatch order while delegating live Molotov visuals to the focused
  renderer.
- Rationale: Molotov was the last large VFX-heavy active-throw branch still
  embedded in the shared renderer, and it owned both direct canvas fallback
  geometry and detached `Node2D` fire-zone hosts. Moving it localizes the
  playfield-to-screen projection trap and keeps future Molotov fire tuning out
  of the throw render facade.
- Renderer size: `active_item_throw_renderer.gd` moved from `1078` lines to
  `618` lines; the new `active_item_throw_molotov_renderer.gd` file is `470`
  lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Molotov / throw-renderer / PSO-prewarm coverage ran `10`
  smoke scripts and passed: `active_item_throw_molotov_smoke`,
  `active_item_molotov_fx_host_smoke`, `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`, `commando_arm_port_smoke`,
  `commando_firearm_runtime_vfx_smoke`, and `battle_pso_prewarmer_smoke`.
  `.\tools\run_warning_scan.ps1` passed with `1302` scripts scanned and no
  GDScript warnings.

125th split on 2026-05-24:

- Commit: `5760849d7 godot: split active throw flare renderer`.
- Scope: added `active_item_throw_flare_renderer.gd` for Flare projectile
  sprites, trail drawing, arrived countdown blink, flare flash / confuse zone
  drawing, flash / glow render budgets, fallback flare dot drawing, icon
  texture loading, and Flare asset prewarm. The shared
  `active_item_throw_renderer.gd` keeps the public draw signature, perf
  labels, generic windup pose / throw icon cache, and dispatch order while
  delegating live Flare visuals to the focused renderer.
- Rationale: Flare rendering is a small but cohesive branch with its own
  projectile, arrived warning, and screen-flash / glow zone budget. Moving it
  keeps the active throw render facade closer to draw-order orchestration and
  leaves future Flare visual tuning in one focused owner.
- Renderer size: `active_item_throw_renderer.gd` moved from `618` lines to
  `546` lines; the new `active_item_throw_flare_renderer.gd` file is `164`
  lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Flare / Grenade-Flare / throw-renderer coverage ran `10`
  smoke scripts and passed: `active_item_throw_flare_budget_smoke`,
  `active_item_throw_grenade_flare_smoke`,
  `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_explosion_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`,
  `active_item_runtime_prewarm_smoke`, and `commando_arm_port_smoke`.
  `.\tools\run_warning_scan.ps1` passed with `1303` scripts scanned and no
  GDScript warnings.

126th split on 2026-05-24:

- Commit: `d0fb13474 godot: split active throw grenade renderer`.
- Scope: added `active_item_throw_grenade_renderer.gd` for Grenade projectile
  sprites, trail drawing, explosion-zone dispatch through the shared
  `GrenadeExplosionDrawer`, fallback grenade dot drawing, icon texture loading,
  and Grenade asset prewarm. The shared `active_item_throw_renderer.gd` keeps
  the public draw signature, perf labels, generic windup pose / throw icon
  cache, and dispatch order while delegating live Grenade projectile and
  explosion visuals to the focused renderer.
- Rationale: Grenade was the baseline active-throw branch still embedded in
  the render facade after Molotov / Flare were split. Moving it leaves the
  facade responsible for ordering and compatibility only, while keeping
  projectile-trail budget checks and explosion drawer delegation close to the
  Grenade visual owner.
- Renderer size: `active_item_throw_renderer.gd` moved from `546` lines to
  `489` lines; the new `active_item_throw_grenade_renderer.gd` file is `131`
  lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused Grenade / Flare / throw-renderer / Commando coverage ran
  `11` smoke scripts and passed: `active_item_throw_grenade_flare_smoke`,
  `active_item_throw_activation_smoke`,
  `active_item_throw_renderer_budget_smoke`,
  `active_item_throw_explosion_budget_smoke`,
  `active_item_throw_rotated_texture_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`,
  `active_item_runtime_prewarm_smoke`, `commando_firearm_runtime_vfx_smoke`,
  `stage2_explosion_rock_collision_smoke`, and `commando_arm_port_smoke`.
  `.\tools\run_warning_scan.ps1` passed with `1304` scripts scanned and no
  GDScript warnings.

127th split on 2026-05-24:

- Commit: `64f3844ff godot: split active item brick wall renderer`.
- Scope: added `active_item_brick_wall_effect_renderer.gd` for Brick Wall
  wall drawing, installed-variant sheet loading, crack path generation, crack
  chips, install gauge, hammer cue, dust / fragment particles, and Brick Wall
  asset prewarm. The shared `active_item_effect_renderer.gd` keeps the field
  effect draw order, perf labels, pickup popups, timer gauges, icon lookup
  caches, and compatibility wrappers while delegating Brick Wall field visuals
  to the focused renderer.
- Rationale: Brick Wall was the largest self-contained branch remaining in
  the broad active-item effect renderer, and its wall texture / crack / install
  gauge logic already had focused cache coverage. Moving it keeps future Brick
  Wall visual tuning out of the shared active consumable renderer.
- Renderer size: `active_item_effect_renderer.gd` moved from `1603` lines to
  `1253` lines; the new `active_item_brick_wall_effect_renderer.gd` file is
  `410` lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused active-item effect / Brick Wall coverage ran `9` smoke
  scripts and passed: `active_item_effect_renderer_cache_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`,
  `active_item_brick_wall_actions_smoke`,
  `active_item_brick_wall_hit_runtime_smoke`,
  `active_item_brick_wall_hit_resolver_smoke`,
  `active_item_brick_wall_particles_smoke`, and
  `active_item_effect_update_driver_smoke`. `.\tools\run_warning_scan.ps1`
  passed with `1305` scripts scanned and no GDScript warnings.

128th split on 2026-05-24:

- Commit: `5d45c1532 godot: split active item timer gauge renderer`.
- Scope: added `active_item_timer_gauge_renderer.gd` for Magnet Field, Holy
  Barrier, Dash Boost, Vitamin Pill, Strange Vial, and Long Boost timer
  gauges; right-bottom timer-stack positioning; timer icon loading / prewarm;
  and the Magnet Field icon fallback. The shared
  `active_item_effect_renderer.gd` keeps field-effect draw ordering, perf
  labels, pickup popups, pickup icon lookup, and compatibility icon wrappers
  while delegating duration bars to the focused renderer.
- Rationale: the active-item effect renderer still owned a large block of
  mostly self-contained bottom-right timer gauge code after the Brick Wall
  split. Moving that block isolates duration-bar visual tuning from field VFX
  and pickup rendering, and keeps the cache smoke enforcing the new owner.
- Renderer size: `active_item_effect_renderer.gd` moved from `1253` lines to
  `799` lines; the new `active_item_timer_gauge_renderer.gd` file is `512`
  lines.
- Validation: `git diff --check` passed. `.\tools\run_headless_load_check.ps1`
  passed. Focused active-item effect / facade coverage ran `5` smoke scripts
  and passed: `active_item_effect_renderer_cache_smoke`,
  `active_item_runtime_prewarm_smoke`,
  `active_item_runtime_render_facade_smoke`,
  `active_item_runtime_render_facade_direct_smoke`, and
  `active_item_effect_update_driver_smoke`. `.\tools\run_warning_scan.ps1`
  passed with `1306` scripts scanned and no GDScript warnings.

129th follow-up on 2026-05-24:

- Commit: `f0be618b2 godot: align Hermes shoes fx host layout`.
- Scope: updated the focused Hermes Shoes field renderer to compute
  `battle_view_layout` screen-space `game_offset` / `render_scale` before
  syncing the detached FX host. The host now scales with the playfield,
  renders above the custom-drawn background, uses screen-space GPU particles,
  and adds cached sparkle wake sprites so active movement remains visible in
  letterboxed layouts.
- Rationale: Hermes Shoes already lived in a detached Node2D FX host, so raw
  playfield coordinates could be misaligned or visually hidden when the game
  canvas was centered in the window. This follow-up makes Hermes match the
  item / stage FX host layout contract: screen-space position plus explicit
  `render_scale`.
- Validation: `git diff --check` passed for the Hermes code/test slice.
  `.\tools\run_headless_load_check.ps1` passed. Focused Hermes / mythic /
  overlay coverage ran `4` smoke scripts and passed:
  `hermes_shoes_fx_host_smoke`, `hermes_shoes_port_smoke`,
  `mythic_item_field_render_budget_smoke`, and
  `runtime_perk_overlay_theme_smoke`. Horn Strawberry follow-up smokes also
  passed after concurrent tree changes:
  `horn_strawberry_audio_vfx_smoke`, `horn_strawberry_mask_port_smoke`,
  `horn_strawberry_skill_hud_smoke`, and
  `mythic_item_field_render_budget_smoke`. `.\tools\run_warning_scan.ps1`
  passed with `1309` scripts scanned and no GDScript warnings.

130th follow-up on 2026-05-24:

- Commit: `668a1ad3d godot: remaster horn strawberry transform visuals`.
- Scope: added `horn_strawberry_paddle_renderer.gd` for the transformed
  strawberry player body, feet, seeds, leaves, horns, eating / hold / movement
  animation, and mini transform silhouette reuse. Added
  `horn_strawberry_timer_gauge_renderer.gd` for the right-bottom shared timer
  stack during the timed transform. The playfield drawer now forwards the
  player draw context through mythic field effects so the transform cinematic
  can start from the real paddle position, and Stage 1 player rendering swaps
  the normal paddle / Commando overlays for the transformed strawberry body.
- VFX note: this pass is a Godot-native procedural remaster, but it remains
  direct `canvas.draw_*` rendering intentionally. The transformed player body,
  transform rings, landing shock rings, and timer gauge are deterministic
  geometry tied to the existing playfield draw pass; no detached FX host or
  per-frame texture generation was introduced.
- Validation: `git diff --check` passed for the Horn Strawberry code / asset
  slice. `.\tools\run_headless_load_check.ps1` passed. Focused Horn /
  mythic / actor coverage ran `7` smoke scripts and passed:
  `horn_strawberry_audio_vfx_smoke`,
  `horn_strawberry_mask_port_smoke`,
  `horn_strawberry_skill_hud_smoke`,
  `horn_strawberry_round_boundary_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `stage1_actor_render_budget_smoke`, and
  `player_sprite_body_motion_policy_smoke`. `.\tools\run_warning_scan.ps1`
  passed with `1309` scripts scanned and no GDScript warnings.

131st follow-up batch on 2026-05-24:

- Commits: `6653db98f godot: tune commando fire support strike`,
  `e6e062175 godot: retarget commando fire support to wall missiles`.
- Scope: first tuned the Commando fire-support call toward faster aircraft,
  fewer support rounds, curved aircraft movement, and shaped shell rendering;
  then retargeted the support rounds into upward opponent-wall missiles with
  explicit wall-impact metadata and geometry rules that avoid premature
  direct-hit resolution.
- Validation: focused Commando support coverage passed:
  `commando_firearm_runtime_vfx_smoke`,
  `commando_firearm_support_call_resolver_smoke`,
  `commando_firearm_support_projectile_resolver_smoke`,
  `commando_firearm_hit_geometry_smoke`, and
  `commando_firearm_support_aircraft_geometry_smoke`.

132nd follow-up on 2026-05-24:

- Commit: `b0c24c91b godot: stop starpoint updates after perk choice`.
- Scope: Stage 1, Stage 2, Stage 3, and Stage 4 starpoint collection loops now
  stop same-frame iteration when `runtime_perk_state.collect_star_points()`
  opens a choice modal or clears the drop arrays. The new compaction smoke
  covers all four stage owners, and the Stage 2 golden-rock smoke now models
  the runtime boolean as "choice opened" instead of "point collected".
- Validation: focused starpoint coverage passed:
  `starpoint_collection_compaction_smoke`,
  `stage1_balloon_starpoint_lifecycle_smoke`,
  `stage2_golden_rock_starpoint_smoke`, `stage3_map_port_smoke`, and
  `stage4_map_port_smoke`.

133rd follow-up on 2026-05-24:

- Commit: `62c81fdcd godot: restore runtime perk card back glow`.
- Scope: runtime perk choice cards now use cached rounded filled back-glow
  layers instead of outline-only halos, preserving the per-character theme
  color while keeping per-frame allocations out of the draw path.
- Validation: `runtime_perk_overlay_theme_smoke` and
  `runtime_perk_active_unlock_flight_smoke` passed.

134th follow-up on 2026-05-24:

- Commit: `a88af204e godot: tighten active throw item feedback`.
- Scope: Molotov fire zones seed their push timer so a freshly triggered fire
  zone can obstruct boss movement on the first update. Spider Mine rendering
  now exposes wall-angle metadata through the throw renderer facade and
  rotates sheet, icon fallback, fallback body, and beacon placement for left /
  right wall states.
- Validation: focused active-throw coverage passed:
  `active_item_throw_molotov_smoke`, `active_item_molotov_fx_host_smoke`,
  `active_item_throw_spider_mine_smoke`,
  `active_item_throw_rotated_texture_smoke`, and
  `active_item_throw_renderer_budget_smoke`.

135th metadata follow-up on 2026-05-24:

- Commit: `599c4e1a7 godot: add item script uid metadata`.
- Scope: added the generated `.gd.uid` metadata for the newly split active
  item renderer modules, mythic field renderers, mythic catalog shards, and
  active item timer gauge renderer so Godot script references stay stable.

136th follow-up on 2026-05-24:

- Commit: `b79c14d26 godot: route Pandora choice icons through project loader`.
- Scope: Pandora Legacy selection cards now load choice icon textures through
  `ProjectResourceLoader.load_texture(...)` instead of direct
  `ResourceLoader.load()`, keeping passive / mythic choice icons on the same
  raw-first resource path as the rest of the Godot item UI.
- Validation: focused item icon / Pandora coverage passed:
  `pandora_legacy_port_smoke`, `gravitybelt_port_smoke`,
  `revival_port_smoke`, `danger_sensor_belt_port_smoke`, and
  `speedgear_port_smoke`.

137th follow-up on 2026-05-24:

- Commit: `8aff5c9a7 godot: keep Molotov fire zones blocking`.
- Scope: Molotov fire zones now obstruct boss center crossing on every update
  while keeping push / shake feedback throttled to the existing feedback
  cadence. The new smoke case verifies crossing is blocked between feedback
  ticks without spamming shake state.
- Validation: focused active-item coverage passed:
  `active_item_throw_molotov_smoke`.

138th follow-up on 2026-05-24:

- Commit:
  `a4ffb9361 godot: add fire support aircraft motion trails`.
- Scope: Stage 1 Commando fire-support rendering now gives support aircraft
  a shadow, motion trails, and ghost silhouette passes, and gives opponent-wall
  support missiles smoke tails plus launch-flash feedback while preserving the
  existing direct-draw fallback layer.
- Validation: focused Commando visual coverage passed:
  `commando_firearm_support_aircraft_geometry_smoke` and
  `commando_firearm_stage1_visual_qa_smoke`.

139th follow-up on 2026-05-24:

- Commit: `95e026a14 godot: add Yachaman Soul revival form`.
- Scope: added the Yachaman Soul mythic/passive item to the Godot catalog,
  field-spawn metadata, roll options, icon asset, runtime helper, state
  machine, gather / burst VFX, transformed player-body renderer, owner-sync
  context, score-event cancellation, post-animation round reset, and skill /
  control lock integration. A later `ReadAllLines` recount measured
  `mythic_item_runtime.gd` at 2540 lines after this commit, with the Yachaman
  runtime, state, effect renderer, and paddle renderer owned by focused helper
  files.
- Validation: focused Yachaman / item coverage passed:
  `yachaman_soul_port_smoke`, `active_item_throw_molotov_smoke`, and
  `item_field_spawn_pool_smoke`. After adding transformed input-lock coverage,
  `yachaman_soul_port_smoke` passed again.

140th follow-up on 2026-05-24:

- Commit: `2c450e9c1 godot: move Shrapnel Armor constants into helper`.
- Scope: Shrapnel Armor's trigger cap, shard cap, gauge cap, shard lifetime,
  trail count, dust cap, flash timer, boss stun / knockback timers, and
  playfield fallbacks now live in
  `mythic_item_shrapnel_armor_runtime.gd`. `mythic_item_runtime.gd` preloads
  the helper only for public cap / field-render metadata reads, and
  `mythic_item_update_runtime.gd` no longer receives a Shrapnel constants
  dictionary. `shrapnel_armor_port_smoke` now guards against the constants
  returning to the runtime facade.
- Runtime facade size: `mythic_item_runtime.gd` moved from 2540 lines to
  2514 lines by `ReadAllLines` count.
- Validation: focused Shrapnel / mythic coverage passed:
  `shrapnel_armor_port_smoke`, `mythic_item_runtime_idle_update_smoke`,
  `mythic_item_field_render_budget_smoke`,
  `mythic_item_snapshot_builder_smoke`, and `adversity_armor_port_smoke`.

141st follow-up on 2026-05-24:

- Commit: `601c686a6 godot: draw Commando fire support bombs with texture`.
- Scope: Stage 1 Commando fire-support projectiles now prewarm and draw the
  512x256 imagegen bomb projectile texture
  `commando_fire_support_bomb_projectile_imagegen_v1.png` through the
  existing playfield polygon projection path. The texture-remaster report now
  exposes `support_bomb_projectile`, and the procedural shell remains as the
  fallback when the PNG cannot load.
- Asset note: source PNG SHA256
  `BDD4A264490391666A6513F397D8BE126274182621EE40321863BC2DD7FA4265`.
- Validation: focused Commando coverage passed:
  `commando_firearm_vfx_texture_remaster_smoke`,
  `commando_firearm_stage1_visual_qa_smoke`,
  `commando_firearm_support_aircraft_geometry_smoke`,
  `commando_firearm_runtime_vfx_smoke`,
  `commando_firearm_support_call_resolver_smoke`,
  `commando_firearm_support_projectile_resolver_smoke`,
  `commando_firearm_hit_geometry_smoke`, and
  `commando_firearm_audio_resolver_smoke`.

142nd follow-up on 2026-05-24:

- Commit: `8be753e50 godot: add Yachaman bomb spin skill`.
- Scope: Yachaman Soul's transformed form now has a direction-plus-action
  bomb spin that detaches the helmet, moves the transformed body, loads a
  bomb state onto the ball on helmet collision, renders the bomb ball through
  the shared ball draw context, consumes the loaded bomb on boss hit, applies
  boss stun / knockback / screen shake, plays throw / explosion fallback
  cues, and draws detached helmet / return / explosion VFX through the
  focused Yachaman helpers. The actor renderer now passes Yachaman context so
  the transformed body can show the exposed-head state while the helmet is
  away.
- Validation: focused Yachaman / shared collision coverage passed:
  `yachaman_soul_port_smoke`, `horn_strawberry_mask_port_smoke`,
  `ball_render_toggles_smoke`, `fire_weather_ball_speed_rules_smoke`,
  `mythic_item_field_render_budget_smoke`, and
  `mythic_item_snapshot_builder_smoke`.

143rd follow-up on 2026-05-24:

- Commit: `f0e9e6442 godot: tune Commando fire support to two bombs`.
- Scope: Commando Fire Support now uses a fixed two-bomb strike instead of
  the previous 2-3 bomb range. The runtime constant and support-call smoke
  expectations now agree on the smaller strike size.
- Validation: focused Commando support coverage passed:
  `commando_firearm_runtime_vfx_smoke`,
  `commando_firearm_support_call_resolver_smoke`,
  `commando_firearm_support_projectile_resolver_smoke`, and
  `commando_firearm_support_aircraft_geometry_smoke`.

144th follow-up on 2026-05-24:

- Commit: `8d7d56a08 godot: log focused BattlePerf spike windows`.
- Scope: `BattlePerf` now emits a focused spike-window line when draw-shell,
  battle-scene, playfield, active-item, mythic, context, or selected HUD /
  actor labels cross tuned thresholds. The summary includes trigger labels,
  hottest focused samples, selected focus samples, and counters so stage /
  item / HUD hitches can be triaged without reading the full detail stream.
- Validation: `battle_perf_logger_smoke` passed, and the repo-wide
  `run_warning_scan.ps1` checked 1315 scripts with no GDScript warnings.

145th follow-up on 2026-05-24:

- Commit: `36021674e godot: draw fire support ammo as bombs`.
- Scope: the Commando left-pillar firearm selector now prewarms the accepted
  Fire Support bomb projectile PNG for ammo pips, exposes the ammo icon path
  in the panel state, and renders Fire Support ammunition as compact bomb
  icons with a procedural fallback instead of generic compact bullets.
- Validation: `commando_firearm_selector_renderer_smoke` passed, including
  prewarm and panel-state coverage for the Fire Support bomb ammo icon.

146th follow-up on 2026-05-24:

- Commit: `df4a14571 godot: split BattlePerf spike window reporter`.
- Scope: split the focused BattlePerf spike-window formatter out of
  `battle_perf_logger.gd` into `battle_perf_spike_window_reporter.gd`. The
  main logger still owns sampling, counters, interval gating, and log
  emission; the new helper owns pure threshold checks, trigger summaries,
  max-hot sorting, focus sorting, and counter-summary attachment. This reduced
  `battle_perf_logger.gd` from 1355 to 1164 lines while preserving the same
  smoke-visible spike-window string contract.
- Validation: `battle_perf_logger_smoke` passed. `run_warning_scan.ps1`
  scanned 1316 scripts with no GDScript warnings; the wrapper still printed
  the known nonfatal Windows root certificate store message from Godot.

147th follow-up on 2026-05-24:

- Commit: `6a1cd92eb godot: split BattlePerf process node reporter`.
- Scope: split BattlePerf's process / physics node scan and label formatting
  out of `battle_perf_logger.gd` into
  `battle_perf_process_node_reporter.gd`. The logger now keeps only scene
  owner storage and summary routing, while the new pure helper owns owner-vs-
  root scan scope, script callback detection, active / inactive callback
  counts, stale loading-host suppression, outside-shell labels, and the
  process-node summary string. This reduced `battle_perf_logger.gd` from
  1164 to 983 lines.
- Validation: `battle_perf_logger_smoke` passed. `run_warning_scan.ps1`
  scanned 1317 scripts with no GDScript warnings; the wrapper still printed
  the known nonfatal Windows root certificate store message from Godot.

148th follow-up on 2026-05-24:

- Commit: `127f2739e godot: draw fire support ammo as radios`.
- Scope: Commando Fire Support ammo pips now use a dedicated 512x512
  imagegen radio-call icon under `assets/sprites/hud/` instead of reusing the
  large projectile bomb texture. The selector prewarms the new PNG, exposes
  `fire_support_radio_ammo_icon_path`, draws two radio-call markers in the HUD
  tray, and keeps a compact procedural radio fallback.
- Validation: `commando_firearm_selector_renderer_smoke` passed, including
  prewarm, panel-state, display-slot, and PNG alpha/dimension coverage.

149th follow-up on 2026-05-24:

- Commit: `46bb8898a godot: tighten Commando fire support pass`.
- Scope: Commando Fire Support now runs a sharper strike pass: the aircraft
  speed is doubled, the drop-arm window is shortened to 42 frames, the
  two-bomb interval is shortened to 18 frames, and the Stage 1 renderer draws
  the stealth aircraft at the tuned compact size while exposing that size in
  the texture-remaster plan.
- Validation: focused Commando coverage passed:
  `commando_firearm_runtime_vfx_smoke`,
  `commando_firearm_support_call_resolver_smoke`, and
  `commando_firearm_vfx_texture_remaster_smoke`. The repo-wide
  `run_warning_scan.ps1` scanned 1318 scripts with no GDScript warnings, and
  `run_headless_load_check.ps1` passed; both wrappers still printed the known
  nonfatal Windows root certificate store message from Godot.

150th follow-up on 2026-05-24:

- Commit: `d4dba21a7 godot: stabilize full pillar gauge fill`.
- Scope: the left pillar gauge orb now snaps its smoothed display ratio to
  exactly full at the near-full threshold, and the shared liquid drawer uses a
  stable non-animated circular fill for full / near-full ratios so the full
  gauge cannot show a thin animated gap. The new smoke locks the snap behavior
  and threshold split.
- Validation: `pillar_gauge_orb_stability_smoke` passed. The same post-change
  repo-wide warning scan and headless load check passed as recorded above.

151st follow-up on 2026-05-24:

- Commit: `44dabe6e0 godot: split Commando Stage 2 rock interactions`.
- Scope: moved Commando firearm Stage 2 rock routing out of
  `commando_firearm_runtime.gd` into
  `commando_firearm_stage2_rock_interaction_resolver.gd`. The helper owns
  Stage 2 rock target discovery across deps / registry / stage router,
  duplicate suppression, bazooka / Fire Support explosion rock-break context,
  and Commando pistol rock-bounce payload merging. The runtime keeps the
  projectile update loop, weapon checks, impact effects, audio, and result
  handoff, dropping the old local target-gathering helpers.
- Validation: `commando_firearm_stage2_rock_interaction_resolver_smoke` and
  `stage2_explosion_rock_collision_smoke` passed. `run_warning_scan.ps1`
  scanned 1320 scripts with no GDScript warnings, and
  `run_headless_load_check.ps1` passed; both wrappers still printed the known
  nonfatal Windows root certificate store message from Godot.

152nd follow-up on 2026-05-24:

- Commit: `acd4f9f78 godot: split Commando firearm audio dispatch`.
- Scope: split Commando firearm audio dispatch mechanics out of
  `commando_firearm_runtime.gd` into
  `commando_firearm_audio_dispatcher.gd`. The existing audio resolver keeps
  pure cue-name lookup; the new dispatcher owns audio / game_audio dependency
  lookup, specific cue priority, generic fire / impact fallback calls,
  per-round pistol reload cue repetition, and suicide-drone loop stop
  dispatch. The runtime keeps gameplay timing, fire-support radio suppression,
  support-aircraft active flags, and the small compatibility wrappers.
- Validation: `commando_firearm_audio_dispatcher_smoke`,
  `commando_firearm_audio_routing_smoke`, and
  `commando_firearm_audio_resolver_smoke` passed. `run_warning_scan.ps1`
  scanned 1322 scripts with no GDScript warnings, and
  `run_headless_load_check.ps1` passed; both wrappers still printed the known
  nonfatal Windows root certificate store message from Godot.

153rd follow-up on 2026-05-24:

- Commit: `19d8bdf47 godot: drop Commando fire flame build bridges`.
- Scope: removed the first thin Commando lingering fire-flame bridge cluster
  from `commando_firearm_runtime.gd`. Runtime fire-zone seeding now calls
  `commando_firearm_lingering_fire_flame_state.gd` directly, and
  `commando_firearm_value_utils_smoke` verifies the deterministic count,
  geometry, ring, size, lifetime, phase, and builder helpers against the
  owner module instead of private runtime wrappers.
- Validation: focused Commando coverage passed:
  `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke`. `run_headless_load_check.ps1` passed.
  `run_warning_scan.ps1` was executed and scanned 1322 scripts, but the wrapper
  failed on pre-existing horn-strawberry WIP warnings outside this Commando
  lane: integer division in
  `scripts/items/horn_strawberry_field_state.gd:235` and a local `seed`
  shadowing the built-in function in
  `scripts/items/mythic_item_horn_strawberry_field_renderer.gd:120`.

154th follow-up on 2026-05-24:

- Commit: `81d16aa33 godot: refine Horn Strawberry mask skills`.
- Scope: tuned Horn Strawberry Mask's Godot skill feel and visibility:
  transform / detransform events now pause the mythic runtime, transformed
  state keeps field-effect draw work alive, strawberry field barriers anchor
  from the paddle center and carry seeded berry-surface visual points, horn
  charge targets the boss-width lane while only locking controls during charge
  / impact, and strawberry bombs use deterministic hopping motion without
  gravity drift. Stage 1 transformed-player draw now receives horn-charge
  offset, and the Horn Strawberry field renderer draws vine / berry barriers,
  breakup fragments, and berry charge trails.
- Validation: focused Horn Strawberry / field / Stage 1 coverage passed:
  `horn_strawberry_mask_port_smoke`, `horn_strawberry_skill_hud_smoke`,
  `mythic_item_field_render_budget_smoke`, `stage1_actor_render_budget_smoke`,
  and `player_sprite_body_motion_policy_smoke`. `run_warning_scan.ps1`
  scanned 1322 scripts with no GDScript warnings, and
  `run_headless_load_check.ps1` passed; both wrappers still printed the known
  nonfatal Windows root certificate store message from Godot.

155th follow-up on 2026-05-24:

- Commit: `d172c3558 godot: drop Viper visibility read bridges`.
- Scope: removed four private visibility/read bridges from
  `viper_skill_runtime.gd`: Ignition Aura ratio, Dual Glitch remaining frames,
  Venom Edge strike frame, and Nerve Strike freeze frames. The runtime draw
  path plus `viper_skill_context_builder.gd`,
  `viper_skill_snapshot_builder.gd`, and
  `viper_skill_timer_gauge_renderer.gd` now read the already-split
  `viper_skill_visibility_query.gd` owner directly. The Ignition Aura smoke
  now guards that these runtime bridge names do not return.
- Validation: focused Viper coverage passed:
  `viper_ignition_aura_port_smoke`, `viper_dual_glitch_port_smoke`,
  `viper_venom_edge_strike_port_smoke`, and
  `viper_nerve_strike_port_smoke`. `run_warning_scan.ps1` scanned 1322
  scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed; both wrappers still printed the known nonfatal Windows root
  certificate store message from Godot.

156th follow-up on 2026-05-24:

- Commit: `69673e6e1 godot: add Horn Strawberry dedicated audio cues`.
- Scope: added the missing Godot sound assets / imports for Horn Strawberry's
  horn charge, field build, field break, and build-break cues, then routed the
  transform, eat, stem fire / hit, field, horn, and bomb-trigger paths through
  dedicated `GameAudio` players and gains. The mythic audio router now has an
  explicit eat-loop stop and field-break route; horn impact and bomb explosion
  remain intentional no-extra-cue methods instead of falling back to unrelated
  Power Smash / grenade sounds. The Horn Strawberry audio/VFX smoke now checks
  file loadability, player-factory setup, fallback removal, eat-stop, field
  break, and no-extra-cue impact / explosion behavior.
- Validation: focused Horn Strawberry coverage passed:
  `horn_strawberry_audio_vfx_smoke`, `horn_strawberry_mask_port_smoke`,
  `horn_strawberry_skill_hud_smoke`, and
  `horn_strawberry_round_boundary_smoke`. `run_warning_scan.ps1` scanned 1322
  scripts with no GDScript warnings, and `run_headless_load_check.ps1` passed;
  both wrappers still printed the known nonfatal Windows root certificate store
  message from Godot.

157th follow-up on 2026-05-24:

- Commit: `03655400c godot: give Commando fire support two radios`.
- Scope: aligned Commando Fire Support's runtime ammo model with the existing
  two-marker radio HUD: `commando_weapon_controller.gd` now exposes two
  fire-support radio calls, one call consumes exactly one radio, the first use
  stays fire-capable with one call remaining, and the tooltip / selector smoke
  coverage now checks `호출권 2/2` plus the `2 -> 1 -> 0` depletion path.
- Validation: focused Commando coverage passed:
  `commando_weapon_controller_smoke`,
  `commando_firearm_runtime_vfx_smoke`,
  `commando_firearm_selector_renderer_smoke`, and
  `commando_firearm_tooltip_smoke`. `run_warning_scan.ps1` scanned 1322
  scripts with no GDScript warnings, and `run_headless_load_check.ps1` passed;
  both wrappers still printed the known nonfatal Windows root certificate store
  message from Godot.

158th follow-up on 2026-05-24:

- Commit: `5d6dd31b1 godot: drop Commando fire flame drift bridges`.
- Scope: removed the next lingering fire-zone flame bridge cluster from
  `commando_firearm_runtime.gd`: drift motion, current / unclamped drift
  offsets, drift wave / rise steps, offset clamps / bounds, current /
  unclamped drift sizes, size decay, and drift-size clamps now stay owned by
  `commando_firearm_lingering_fire_flame_state.gd`. The value-utils smoke now
  calls that owner directly and guards that the removed runtime bridge names
  do not return.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed; both wrappers still printed the known nonfatal Windows root
  certificate store message from Godot.

159th follow-up on 2026-05-24:

- Commit: `b4d5523b1 godot: drop Commando fire flame reset bridges`.
- Scope: removed the lingering fire-zone flame reset / frame bridge cluster
  from `commando_firearm_runtime.gd`: current / next lifetime and phase reads,
  phase-step math, reset predicates, effect-id reads, reset angle / radius /
  size / lifetime helpers, reset-value mutation, motion / frame-value writes,
  single-flame advance, batch advance, and indexed reads now stay owned by
  `commando_firearm_lingering_fire_flame_state.gd`. The value-utils smoke now
  calls that owner directly for those reset / frame paths and guards that the
  removed runtime bridge names do not return.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed; both wrappers still printed the known nonfatal Windows root
  certificate store message from Godot.

160th follow-up on 2026-05-24:

- Commit: `84c1cca95 godot: drop Commando fire flame frame bridges`.
- Scope: removed the final lingering fire-zone flame reader / seed / frame
  bridge trio from `commando_firearm_runtime.gd`. The runtime's
  `_update_lingering_fire_flames()` side-effect hook now calls
  `commando_firearm_lingering_fire_flame_state.gd` directly, while the
  value-utils smoke verifies `get_flames`, `should_seed_flames`, and
  `get_flames_for_frame` against the owner module and guards that the removed
  runtime bridge names do not return.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed; both wrappers still printed the known nonfatal Windows root
  certificate store message from Godot.

161st follow-up on 2026-05-24:

- Commit: `5b749f535 godot: drop Commando net field clamp bridges`.
- Scope: removed the lingering net-field boss-clamp calculation bridge cluster
  from `commando_firearm_runtime.gd`: field / boss geometry reads, clamp width
  and size math, clamp rect origin, boss x / position clamping, emit
  predicates, and clamp-result payload construction now stay owned by
  `commando_firearm_lingering_net_field_state.gd`. The runtime keeps
  `_apply_net_field_boss_clamp()` as the side-effect boundary, while the
  value-utils smoke calls the owner directly for deterministic clamp geometry
  and guards that the removed runtime bridge names do not return.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed; both wrappers still printed the known nonfatal Windows root
  certificate store message from Godot.

162nd follow-up on 2026-05-24:

- Commit: `96fadb0c9 godot: remaster Commando fire support airstrike blast`.
- Scope: upgraded Commando Fire Support's grenade explosion presentation
  without changing the normal active-item Grenade budget. Fire-support impact
  flashes now carry an `airstrike` explosion style plus texture / smoke /
  spark budget metadata, `GrenadeExplosionDrawer` prewarms cached impact
  flare / shockwave textures and draws layered glow, burst, shockwave,
  smoke-column, and foreground spark passes only for fire-support blasts, and
  the Stage 1 Commando firearm renderer reports the new airstrike visual
  family / texture-layer count.
- Validation: focused coverage passed:
  `active_item_throw_explosion_budget_smoke`,
  `commando_firearm_impact_flash_resolver_smoke`,
  `commando_firearm_runtime_vfx_smoke`,
  `commando_firearm_vfx_texture_remaster_smoke`, and
  `battle_scene_frame_controller_draw_order_smoke`. `run_warning_scan.ps1`
  scanned 1322 scripts with no GDScript warnings, and
  `run_headless_load_check.ps1` passed.

163rd follow-up on 2026-05-24:

- Commit: `7cefeafbe godot: move BattlePerf draw logging after shell sample`.
- Scope: moved the `BattlePerf.maybe_log()` call out of
  `battle_scene_frame_controller.gd` and into `battle_scene_shell.gd` after
  `draw.shell.total` has closed. The frame controller still records draw pass
  samples, but log formatting / printing no longer inflates `draw.frame.total`
  or `draw.shell.total`. The draw-order smoke now asserts that the frame
  controller does not call the log printer and that the shell invokes it only
  after the shell sample closes.
- Validation: focused coverage passed:
  `battle_scene_frame_controller_draw_order_smoke` plus the same Commando /
  active-item VFX smoke set listed in the 162nd follow-up. `run_warning_scan.ps1`
  scanned 1322 scripts with no GDScript warnings, and
  `run_headless_load_check.ps1` passed.

164th follow-up on 2026-05-24:

- Commit: `cd327456e godot: drop Commando net field setup bridges`.
- Scope: removed the lingering net-field setup bridge cluster from
  `commando_firearm_runtime.gd`: lifecycle field mutation, rope snap duration,
  origin fallback, player slow multiplier, profile / geometry field
  application, deploy-x / net-rect / initial-constrict math, deterministic net
  shape seed / scale / point / generation, default / net lingering positions,
  desired height, and height-limit helpers now stay owned by
  `commando_firearm_lingering_net_field_state.gd`. The runtime keeps the live
  side-effect boundaries for active lingering-effect setup, spawn position /
  height resolution, boss clamping, and constrict updates, while the
  value-utils smoke calls the owner directly and guards the removed runtime
  bridge names.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed.

165th follow-up on 2026-05-24:

- Commit: `38914c10c godot: expose mythic field perf counters`.
- Scope: BattlePerf now exposes an enabled-state reader for draw helpers,
  surfaces Stage 2 actor sub-pass labels and `30.mythic_item_field` in focused
  spike/gap summaries, and the mythic field renderer records per-family
  `mythic.visible.*` counters only when the logger is active. Horn Strawberry
  field rendering now avoids eager sub-context reads unless the transform or
  child state is visible, while detailed field samples still use the existing
  begin/finish sample path.
- Validation: `battle_perf_logger_smoke`,
  `mythic_item_field_render_budget_smoke`, and `adversity_armor_port_smoke`
  passed. `run_warning_scan.ps1` scanned 1322 scripts with no GDScript
  warnings, and `run_headless_load_check.ps1` passed.

166th follow-up on 2026-05-24:

- Commit: `38e021313 godot: drop Commando lingering status setup bridges`.
- Scope: removed the lingering status setup bridge cluster from
  `commando_firearm_runtime.gd`: profile id / duration / interval reads,
  initial cooldown, profile slow-multiplier guard / read / application,
  profile base-field application, status-field apply guard, and the
  top-level status-field mutation wrapper now stay owned by
  `commando_firearm_lingering_status_state.gd`. Runtime spawning calls the
  status owner directly while keeping the later live status application,
  `apply_status(...)` side effect, and cooldown reset sequence in runtime.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed.

167th follow-up on 2026-05-24:

- Commit: `0bc1a7313 godot: scatter Commando fire support bomb targets`.
- Scope: Commando Fire Support bomb targets now use deterministic seeded x
  scatter within 200px of the marked point instead of the old fixed offset
  list. `commando_firearm_support_call_resolver.gd` owns the scatter range
  and per-bomb x-offset helper, runtime passes the support-call id into target
  selection, and the support-call / runtime VFX smokes assert the range and
  independent sequential bomb targets.
- Validation: `commando_firearm_support_call_resolver_smoke`,
  `commando_firearm_runtime_vfx_smoke`, and
  `commando_firearm_vfx_texture_remaster_smoke` passed. `run_warning_scan.ps1`
  scanned 1322 scripts with no GDScript warnings, and
  `run_headless_load_check.ps1` passed.

168th follow-up on 2026-05-24:

- Commit: `24e9c5cc8 godot: drop Commando lingering status application bridges`.
- Scope: removed the lingering status application / cooldown bridge cluster
  from `commando_firearm_runtime.gd`: status id / state / application reads,
  application validity predicates, ready-to-apply gates, status target /
  duration / source reads, status-data building, slow-multiplier inclusion,
  cooldown get / next / set / advance / reset helpers, and cooldown-ready
  predicates now stay owned by `commando_firearm_lingering_status_state.gd`.
  Runtime keeps only the live side-effect flow around
  `_apply_lingering_effect_status()`, `_apply_lingering_status_application()`,
  `_apply_ready_lingering_status()`, and `_apply_lingering_status_to_boss()`.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed.

169th follow-up on 2026-05-24:

- Commit: `323e74282 godot: drop Commando lingering status rect bridges`.
- Scope: removed the remaining lingering status rect / overlap bridge cluster
  from `commando_firearm_runtime.gd`: effect rect position / size / width /
  height, boss rect position / size / width / height, rect intersection, and
  effect-hits-boss helpers now stay owned by
  `commando_firearm_lingering_status_state.gd`. The value-utils smoke calls
  the owner directly and guards the removed runtime bridge names.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed.

170th follow-up on 2026-05-24:

- Commit: `a76d068a2 godot: drop Commando hit geometry result bridges`.
- Scope: removed the Commando hit-result geometry bridge cluster from
  `commando_firearm_runtime.gd`: result-hit-profile lookup, knockback velocity,
  and knockback direction helpers now stay owned by
  `commando_firearm_hit_geometry.gd`. Runtime hit application calls the owner
  directly while keeping status application, AI knockback side effects, damage
  queueing, and weapon-specific result mutation in runtime.
- Validation: `commando_firearm_value_utils_smoke`,
  `commando_firearm_runtime_vfx_smoke`, and
  `commando_firearm_boss_damage_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed.

171st follow-up on 2026-05-24:

- Commit: `e0b85d825 godot: drop Commando support aircraft geometry bridges`.
- Scope: removed the private Fire Support aircraft geometry bridge pair from
  `commando_firearm_runtime.gd`. Public collision query and ball-collision
  routing now call `commando_firearm_support_aircraft_geometry.gd` directly for
  aircraft collision rect construction and ball path intersection, while
  runtime keeps support-call state, aircraft audio lifecycle, and the public
  `get_fire_support_aircraft_collision_rect(...)` API.
- Validation: `commando_firearm_value_utils_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed.

172nd follow-up on 2026-05-24:

- Commit: `f7a40a33f godot: drop Commando support call setup bridges`.
- Scope: removed the Fire Support support-call setup bridge cluster from
  `commando_firearm_runtime.gd`: call payload construction, marker-flash
  construction, delay-frame reads, bomb-count reads, seed reads, and
  bomb-target selection now call `commando_firearm_support_call_resolver.gd`
  directly from the runtime owner. Runtime keeps support-call array mutation,
  radio / aircraft audio side effects, projectile spawning, and the
  `_advance_support_call()` lifecycle boundary.
- Validation: `commando_firearm_support_call_resolver_smoke` and
  `commando_firearm_runtime_vfx_smoke` passed. `run_warning_scan.ps1` scanned
  1322 scripts with no GDScript warnings, and `run_headless_load_check.ps1`
  passed.

## Review Lane Grouping / Blocker Traceability - 2026-05-23

This pass closes the review-only follow-up that the cleanup sprint commits
were correct but not easy to read by lane. The raw chronological order still
contains mixed mythic / stage / Commando work, but the review grouping below
is the intended way to audit the current checkpoint.

Lane grouping for recent follow-up commits:

- Boot / loading / input / menu lane:
  `a31f02305`, `569f4bc69`, `a5d64bd8`, `cbee457a5`,
  `12d1ae362`, `b54691e4e`, `40139db4f`, `2a1e45c3e`,
  `381e7c9a5`, `418356131`.
- Active item / item VFX / item runtime lane:
  `8f58b63b0`, `e29fbcef7`, `958cc63e1`, `e8c26f139`,
  `de4522bb5`, `3fe052261`, `819b96462`, `39ca20e11`,
  `625c95631`, `0956f6bb8`.
- Mythic / legendary item lane:
  `e40423f1e`, `05c1eef12`, `5c209fb7e`, `7a3d0ff4f`,
  `c484677de`, `04cc78bf2`, `b637d9ffa`, `a47f6dafd`,
  `974ddb226`, `968a1ff4a`, `0e0cf2fd3`.
- Character / Commando / perk / HUD lane:
  `e1a0755fb`, `cb58a93a8`, `6970aded2`, `bf30104ee`,
  `28858b878`, `9321d2683`, `0e1d39a93`, `d5156a901`,
  `ff83b6e86`, `87be228ae`, `ce43ccfd7`, `74bb79772`,
  `3998ec141`, `f18fd43f8`, `be3d15b6a`, `97452a115`.
- Stage / weather / render lifecycle lane:
  `02413b540`, `159736f26`, `645518ba0`, `5ad1bbf3d`,
  `a2961bede`, `e77d413f0`, `52d3c4a02`, `a3641582c`,
  `7ed0b79af`, `97aba167f`, `5628d5b14`, `65be9f2f1`,
  `9092e335c`, `8a5e8a0c2`, `12ca98dce`, `0253fa901`,
  `5763b6895`.
- Audio / asset / packaging-support lane:
  `f2b2592f9`, `9c96be588`, `ebe4b380d`, `4c6ccc209`,
  `a41efcb3c`.
- Docs / traceability lane:
  `4c6ccc209`, `ca09326a4`, `fcf2842c0`, `b4e929515`,
  `1e40d31bf`, `8f026acfb`, `6d50dfd9e`, `c8e28a1ca`,
  `3d3e888f4`, `b8813e55e`, `cdc0637db`, `01ba8bc48`,
  `9ab791a84`, `6622d30a0`, `689bc2790`, `7a432139f`,
  `2001105b6`, `8460db122`, `ccebdcc70`.

Current line anchors for the four blocker fixes that landed inside feature
commits rather than standalone `fix` commits:

- Pandora Legacy animated mythic icon metadata:
  `godot/scripts/items/mythic_item_catalog.gd:49` defines
  `PANDORA_LEGACY_ICON_SHEET_PATH`; `:2151-2155` wires the sheet path,
  frame count, frame msec, source inset, and fill-slot metadata into the
  catalog entry.
- Raw PNG loader / cache-collision hardening:
  `godot/scripts/resources/project_resource_loader.gd:15-28` checks the
  existing ResourceLoader cache first, then loads a valid raw source image via
  `Image.load_from_file()` / `ImageTexture.create_from_image()` and avoids
  assigning `resource_path` when Godot already has a cached imported resource
  for that path.
- Stage 2 pillar HUD renderer name drift:
  `godot/tests/stage2_pillar_render_budget_smoke.gd:235-238` now rejects the
  old `skill_orb_renderer` conditional and requires the live
  `active_skill_orb_renderer` path.
- Stage 2 boss-rage defensive rock wall count:
  `godot/tests/stage2_router_smoke.gd:472-477` now asserts the current
  `>= 3` rock-wall contract and still verifies quake feedback, water-cannon
  delay, and rock-spawn audio.
