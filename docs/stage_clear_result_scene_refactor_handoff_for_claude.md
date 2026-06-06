# Stage Clear Result Scene Refactor Handoff for Claude

Date: 2026-06-05
Workspace: `D:\main\bosspong`
Target project: `godot/project.godot`

## Purpose

This handoff summarizes the current Godot refactor work around
`godot/scripts/ui/stage_clear_result_scene.gd` so Claude can review it without
reconstructing the entire session history.

The refactor goal is to keep `stage_clear_result_scene.gd` as orchestration,
draw-order, callbacks, and side-effect glue, while moving stable result-screen
data normalization, state payload construction, input calculations, update
sequencing, and presenter contracts into focused `stage_clear_result_*`
modules.

Do not treat legacy Python/Pygame files as edit targets for this review. They
are reference-only under the repo's Godot-first routing.

## Current Worktree Note

The worktree is broad and dirty. There are unrelated or adjacent changes in
lingpet, blacksmith sprites, ball/core systems, HUD, audio, and tests. For this
review, filter primarily to:

- `godot/scripts/ui/stage_clear_result_scene.gd`
- `godot/scripts/ui/stage_clear_result_*`
- `godot/tests/stage_clear_result_*`
- `docs/godot_module_ownership_ledger.md`
- this handoff file

Many helper modules and smoke tests are currently untracked, so `git diff`
alone will not show the full refactor surface. Use `git status --short` and
`rg --files godot/scripts/ui godot/tests | rg "stage_clear_result"` when
orienting.

Recurring local git warnings seen during the session:

- `safe.directory '%(prefix)\D;C:\Program Files\Git\main\bosspong_legacy_py' not absolute`
- `docs/godot_module_ownership_ledger.md` may report LF-to-CRLF conversion

## Shared Pattern Introduced

`stage_clear_result_scene.gd` now has common helpers for scene field payloads:

- `_apply_scene_field_payload(field_payload: Dictionary) -> void`
- `_get_field_payload_from_apply_result(apply_result: Dictionary) -> Dictionary`

Several helper modules now return scene-facing apply dictionaries with nested
`field_payload` entries. The scene unwraps and applies those fields, then keeps
side effects such as `queue_redraw()`, audio calls, callbacks, and navigation
actions in the scene.

Review point: confirm this generic dynamic `set(StringName(...))` field apply
pattern is acceptable for this codebase. It reduced repetitive scene property
writes, but it also makes field-name mistakes easier to miss without smoke
coverage.

## Completed Refactor Slices

### Config Data State

Files:

- `godot/scripts/ui/stage_clear_result_config_data_state_handler.gd`
- `godot/tests/stage_clear_result_config_data_state_handler_smoke.gd`

What changed:

- Added config-data normalization/apply helpers.
- Added `get_config_data_scene_apply_result()`.
- Scene now applies `player_score`, `boss_score`, `current_stage`,
  `reward_plan`, and `stage_reward_snapshot` through a scene field payload.

### Character Asset State

Files:

- `godot/scripts/ui/stage_clear_result_character_asset_state_handler.gd`
- `godot/tests/stage_clear_result_character_asset_state_handler_smoke.gd`

What changed:

- Moved result-character asset state normalization and cache invalidation into
  the handler.
- Added `get_character_asset_scene_apply_result()`.
- Scene applies selected character type and victory/click-reaction sheet fields
  through field payload.

### Runtime Object State

Files:

- `godot/scripts/ui/stage_clear_result_runtime_object_state_handler.gd`
- `godot/tests/stage_clear_result_runtime_object_state_handler_smoke.gd`

What changed:

- Centralized runtime object keys and validation.
- Added `_valid_object_or_null()` and `get_runtime_object_apply_result()`.
- Scene uses the handler result for runtime object fields such as perk state,
  game audio, callbacks, and item systems.

Review/follow-up:

- `_apply_runtime_object_state()` currently applies this dictionary directly
  with `set(...)`. It could be switched to `_apply_scene_field_payload(...)`
  for consistency.

### Configure Reset State

Files:

- `godot/scripts/ui/stage_clear_result_config_reset_state_handler.gd`
- `godot/tests/stage_clear_result_config_reset_state_handler_smoke.gd`

What changed:

- Moved configure/reset default payload construction into the handler.
- Added `get_config_reset_scene_apply_result()`.
- Scene now resets score/stage/reward state, boxes, scroll state, starpoint
  gates, timers, and actor reaction timers through the field payload helper.

### Standalone Preview Defaults

Files:

- `godot/scripts/ui/stage_clear_result_preview_defaults_handler.gd`
- `godot/tests/stage_clear_result_preview_defaults_handler_smoke.gd`

What changed:

- Moved standalone preview defaults into a focused handler.
- Added `get_standalone_preview_scene_apply_result()`.
- Scene applies preview scores, stage, and reward plan through field payload.

### Asset Apply

Files:

- `godot/scripts/ui/stage_clear_result_asset_apply_handler.gd`
- `godot/tests/stage_clear_result_asset_apply_handler_smoke.gd`

What changed:

- Moved texture path load/apply contract into the asset apply handler.
- Added `get_texture_path_scene_apply_result()`.
- `_load_textures()` now updates loaded path fields through field payload.

### Actor Reaction Timer Update

Files:

- `godot/scripts/ui/stage_clear_result_actor_reaction_update_handler.gd`
- `godot/tests/stage_clear_result_actor_reaction_update_handler_smoke.gd`

What changed:

- Moved actor reaction timer state update/apply contract into the handler.
- Added `get_actor_reaction_timer_apply_result()`.
- Added `get_actor_reaction_timer_scene_apply_result()` mapping:
  `_dalji_base_timer`, `_dalji_click_reaction_timer`,
  `_player_victory_click_reaction_timer`,
  `_stage2_boss_defeat_click_reaction_timer`,
  `_stage3_boss_defeat_click_reaction_timer`, and `_dalji_dialogue_timer`.
- `_apply_actor_reaction_timer_update()` now applies these via field payload.

Latest validation state:

- Focused smokes for this slice passed before the handoff.
- `run_warning_scan.ps1` was started afterward but interrupted by the user.
- Full warning scan and headless load check have not been completed after this
  latest `.gd` edit.

### Scroll Input

Files:

- `godot/scripts/ui/stage_clear_result_scroll_input_handler.gd`
- `godot/tests/stage_clear_result_scroll_input_handler_smoke.gd`

What changed:

- Moved scroll button/hover/drag calculations into the handler.
- Added `get_scroll_state_apply_result()`.
- Scene uses the handler result for scroll button layout and scroll state.

Review/follow-up:

- `_apply_scroll_state_result()` still writes individual scene fields from the
  apply result. Candidate next step: add a scene-field payload wrapper here.

### Box Input

Files:

- `godot/scripts/ui/stage_clear_result_box_input_handler.gd`
- `godot/tests/stage_clear_result_box_input_handler_smoke.gd`

What changed:

- Moved box hover/open click calculations into the handler.
- Added `get_box_state_apply_result()`.
- Scene uses `_apply_box_state_result()` for boxes, hover index, audio, and
  redraw side effects.

Review/follow-up:

- `_apply_box_state_result()` still writes `_boxes` and `_hovered_box_index`
  directly. Candidate next step: add a scene-field payload wrapper while
  keeping audio/redraw side effects in the scene.

### Box Update

Files:

- `godot/scripts/ui/stage_clear_result_box_update_handler.gd`
- `godot/tests/stage_clear_result_box_update_handler_smoke.gd`

What changed:

- Moved per-frame box opening and immediate reward update payloads into the
  handler.
- Added `get_box_update_scene_apply_result()`.
- `_update_boxes()` now applies `_boxes` and `_lid_open_counter` through field
  payload, then keeps redraw and callback side effects in the scene.

### Scroll Update

Files:

- `godot/scripts/ui/stage_clear_result_scroll_update_handler.gd`
- `godot/tests/stage_clear_result_scroll_update_handler_smoke.gd`

What changed:

- Moved scroll phase/timer update sequencing into the handler.
- Added `get_scroll_update_scene_apply_result()`.
- `_update_scroll()` now applies `_scroll_phase` and `_scroll_timer` through
  field payload.

### Actor Presenter

Files:

- `godot/scripts/ui/stage_clear_result_actor_presenter.gd`
- `godot/tests/stage_clear_result_actor_presenter_smoke.gd`

What changed:

- Moved player victory and defeated boss draw orchestration into the presenter.
- Added `get_player_victory_draw_scene_apply_result()`.
- Added `get_defeated_boss_draw_scene_apply_result()`.
- Scene applies click-rect/timer fields from presenter payloads and keeps draw
  sequencing at the scene boundary.

### Actor Click Handler

Files:

- `godot/scripts/ui/stage_clear_result_actor_click_handler.gd`
- `godot/tests/stage_clear_result_actor_click_handler_smoke.gd`

What changed:

- Moved player, Dalji, and boss click-reaction calculations into the handler.
- Added scene-facing helpers:
  `get_click_reaction_scene_apply_result()`,
  `get_player_victory_click_rect_scene_apply_result()`,
  `get_dalji_click_rect_scene_apply_result()`, and
  `get_dalji_click_side_effect_scene_apply_result()`.
- Scene applies click reaction timers/rects through field payload while keeping
  audio, voice, and redraw side effects in the scene.

### Box Data

Files:

- `godot/scripts/ui/stage_clear_result_box_data.gd`
- `godot/tests/stage_clear_result_box_data_smoke.gd`

What changed:

- Added append-resolved-perk reward payload support for starpoint resolved perk
  rewards.

Review/follow-up:

- `append_box_resolved_perk_reward()` in the scene still applies `_boxes` and
  redraw directly. Candidate next step: add a scene-field payload wrapper in
  `StageClearResultBoxData`.

### Other Result-Screen Module Surface

These modules/tests are part of the current result-screen split surface and
should be considered during review, even if a given module was created in an
earlier slice:

- `stage_clear_result_audio_apply_handler.gd`
- `stage_clear_result_box_presenter.gd`
- `stage_clear_result_callback_handler.gd`
- `stage_clear_result_fx_host_update_handler.gd`
- `stage_clear_result_immediate_reward_helper.gd`
- `stage_clear_result_input_router.gd`
- `stage_clear_result_navigation_action_handler.gd`
- `stage_clear_result_runtime_overlay_presenter.gd`
- `stage_clear_result_scroll_presenter.gd`
- `stage_clear_result_viewport_layout.gd`
- Existing draw/data helpers such as `stage_clear_result_*_draw_helper.gd`,
  `stage_clear_result_asset_loader.gd`, `stage_clear_result_font_cache.gd`,
  `stage_clear_result_voice_player.gd`, and related smoke tests.

## Validation Already Run During The Refactor

Focused smoke tests were run repeatedly after each slice. The most recent
reported passed focused set was:

```powershell
cd D:\main\bosspong\godot
.\tools\run_smoke_tests.ps1 -Tests @(
  'res://tests/stage_clear_result_actor_reaction_update_handler_smoke.gd',
  'res://tests/stage_clear_result_scene_click_reaction_smoke.gd',
  'res://tests/stage_clear_result_screen_smoke.gd'
)
```

Important: after the actor reaction scene-field payload edit, the warning scan
was interrupted before completion. Treat full verification as pending.

## Suggested Claude Review Commands

Run these from the repo root first to orient:

```powershell
git status --short
rg --files godot/scripts/ui godot/tests | rg "stage_clear_result"
rg -n "get_.*scene_apply_result|_apply_scene_field_payload|_get_field_payload_from_apply_result" godot/scripts/ui godot/tests
```

Then run focused result-screen smokes:

```powershell
cd D:\main\bosspong\godot
.\tools\run_smoke_tests.ps1 -Tests @(
  'res://tests/stage_clear_result_config_data_state_handler_smoke.gd',
  'res://tests/stage_clear_result_character_asset_state_handler_smoke.gd',
  'res://tests/stage_clear_result_config_reset_state_handler_smoke.gd',
  'res://tests/stage_clear_result_runtime_object_state_handler_smoke.gd',
  'res://tests/stage_clear_result_preview_defaults_handler_smoke.gd',
  'res://tests/stage_clear_result_asset_apply_handler_smoke.gd',
  'res://tests/stage_clear_result_actor_reaction_update_handler_smoke.gd',
  'res://tests/stage_clear_result_actor_click_handler_smoke.gd',
  'res://tests/stage_clear_result_actor_presenter_smoke.gd',
  'res://tests/stage_clear_result_scroll_input_handler_smoke.gd',
  'res://tests/stage_clear_result_box_input_handler_smoke.gd',
  'res://tests/stage_clear_result_box_update_handler_smoke.gd',
  'res://tests/stage_clear_result_scroll_update_handler_smoke.gd',
  'res://tests/stage_clear_result_screen_smoke.gd',
  'res://tests/stage_clear_result_scene_click_reaction_smoke.gd'
)
```

Then run the required Godot sign-off checks:

```powershell
cd D:\main\bosspong\godot
.\tools\run_warning_scan.ps1
.\tools\run_headless_load_check.ps1
```

Optional hygiene check:

```powershell
git diff --check
```

## Review Checklist

- Confirm `stage_clear_result_scene.gd` is still acting as scene/controller
  glue rather than becoming a new monolith under another name.
- Verify every `field_payload` key matches a real scene property name.
- Check that helper modules return deterministic data-only apply contracts and
  do not perform scene side effects.
- Confirm side effects remain in the scene where appropriate: redraw,
  callbacks, audio playback, navigation, and input consumption.
- Review whether `_apply_scene_field_payload()` should remain generic, or
  whether some fields need typed/named apply methods for warning hygiene.
- Check smoke tests cover both value payloads and scene-facing field names.
- Confirm `docs/godot_module_ownership_ledger.md` matches the actual module
  ownership and does not introduce operating rules that belong in architecture
  docs.
- Re-run full warning scan and headless load check because the last warning
  scan was interrupted.

## Known Remaining Direct Apply Sites

These are not necessarily bugs; they are likely next refactor candidates:

- `_apply_runtime_object_state()` in `stage_clear_result_scene.gd`
- `_apply_scroll_state_result()` in `stage_clear_result_scene.gd`
- `_apply_box_state_result()` in `stage_clear_result_scene.gd`
- `append_box_resolved_perk_reward()` in `stage_clear_result_scene.gd`
- Any remaining `apply_result.get(...)` branches that mix field mutation with
  side effects should be reviewed case by case.

Input routing and navigation result handling still intentionally inspect
route/action dictionaries in the scene because the scene owns those side
effects. Claude should still verify the boundary is clean and consistent.

## Sign-Off State

This handoff itself is documentation-only. No Godot `.gd` edits were made while
creating this file.

The result-screen refactor code is not fully signed off after the latest actor
reaction payload slice because `run_warning_scan.ps1` was interrupted and the
final headless load check was not rerun afterward.
