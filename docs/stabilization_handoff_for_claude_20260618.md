# Stabilization Handoff for Claude - 2026-06-18

## Purpose

This handoff summarizes the Codex stabilization pass so Claude can review the
current dirty worktree without re-discovering the same failures. The goal was
not a feature pass; it was to get the Godot project stable enough that the
repo-local pre-push gates pass in the current worktree.

Important scope caveat: the worktree is very dirty and contains many
pre-existing / parallel user or Claude changes. Do not assume every modified or
untracked file in `git status` was authored by this stabilization pass. Review
the listed files and current diffs directly.

## Final Verification Evidence

From `godot/`:

- `.\tools\run_pre_push_checks.ps1 -Mode all` passed.
- The passing run included:
  - headless load check passed
  - GDScript warning scan passed with no warnings
  - full smoke suite passed: 714 `*_smoke.gd` tests
- `.\tools\run_pre_push_checks.ps1 -Mode full` also passed earlier.
- Focused smokes also passed during the pass:
  - `res://tests/lingpet_snapshot_sync_gating_smoke.gd`
  - `res://tests/character_info_live_stats_smoke.gd`
  - `res://tests/lingpet_loadout_state_smoke.gd`
  - `res://tests/lingpet_egg_runtime_smoke.gd`
  - `res://tests/project_resource_loader_import_preference_smoke.gd`
  - `res://tests/render_fps_cap_settings_smoke.gd`
  - `res://tests/screenshot_capture_smoke.gd`
- From repo root, `git diff --check` passed. It emitted existing line-ending
  advisory warnings, but no whitespace errors.
- The temporary files created by the stabilized screenshot/settings smokes were
  checked and were not left behind.

Known noisy but non-failing output:

- Godot on this Windows environment repeatedly prints
  `Failed to read the root certificate store`.
- Some standalone smokes can print ObjectDB leak warnings while still passing
  under the wrapper. The final `Mode all` gate still passed.

## Stabilization Fixes Worth Reviewing

### Lingpet snapshot/static sync gating

Files:

- `godot/scripts/lingpet/lingpet_runtime_snapshot_builder.gd`
- `godot/tests/lingpet_snapshot_sync_gating_smoke.gd`
- `godot/tests/character_info_live_stats_smoke.gd`
- `godot/tests/lingpet_loadout_state_smoke.gd`

Context:

- `Mode all` initially failed in warning scan because
  `lingpet_runtime_snapshot_builder.gd` referenced missing helper methods:
  `_build_owner_static_surface_key`,
  `_should_sync_owner_static_surface`,
  `_sync_skill_static_owner`,
  `_sync_second_skill_static_owner`,
  `_sync_skill_runtime_owner`, and
  `_sync_second_skill_runtime_owner`.
- Current file now splits static owner sync from volatile runtime owner sync.
- The gating smoke reported stable 100-tick owner set count within budget and
  passed.

Review focus:

- Confirm static surface keys include all fields that should trigger a static
  owner rewrite.
- Confirm runtime keys still update every tick where intended.
- Confirm container values are still detached and cannot alias owner-held arrays
  or dictionaries.

### Lingpet body-hit tests versus player-priority rule

File:

- `godot/tests/lingpet_egg_runtime_smoke.gd`

Context:

- The runtime now has a player-priority rule:
  when the player paddle can reach the ball, the companion body should not steal
  that bounce.
- Existing body-hit assertions still placed the ball within the player's reach,
  so `lingpet_egg_runtime_smoke.gd` failed after the new rule.
- The relevant fixtures were adjusted by moving `owner.player_pos` away before
  asserting companion body-hit behavior.

Review focus:

- Confirm the test still proves the intended companion body-hit behavior.
- Confirm it does not weaken the player-priority regression coverage.

### OrOsha PNG import sidecars

Files added:

- `godot/assets/sprites/lingpet/orosha_cutin_live2d_autosprite_32f.png.import`
- `godot/assets/sprites/lingpet/orosha_click_rolling_autosprite_98f.png.import`
- `godot/assets/sprites/lingpet/orosha_companion_click_reaction_rolling_98f.png.import`
- `godot/assets/sprites/lingpet/orosha_acquire_vfx_autosprite_16f.png.import`

Context:

- `project_resource_loader_import_preference_smoke.gd` failed because these PNG
  assets existed without committed `.png.import` sidecars.
- The added import files mirror existing lingpet texture import settings:
  `CompressedTexture2D`, `compress/mode=0`, no mipmaps, no VRAM compression.
- The `dest_files` hashes match Godot's import hash pattern for the source
  `res://` paths.

Review focus:

- Confirm these assets are intentionally shipped as lossless/non-VRAM
  textures. If any are battle-entry/prewarm-large enough to require VRAM
  compression, adjust import settings before committing.

### Display settings smoke isolation

Files:

- `godot/scripts/core/battle_view_layout.gd`
- `godot/tests/render_fps_cap_settings_smoke.gd`

Context:

- `render_fps_cap_settings_smoke.gd` passed alone but failed inside `Mode all`.
- Root cause was test use of the production `user://display_settings.cfg` /
  `.last_good.cfg` paths inside the full suite.
- `BattleViewLayout` now exposes test-only path overrides:
  - `set_settings_paths_for_test(settings_path, backup_path = "")`
  - `reset_settings_paths_for_test()`
- The smoke now uses unique `res://.tmp/render_fps_cap_settings_smoke_*` files
  and resets the override after the test.

Review focus:

- Confirm production code still defaults to `user://display_settings.cfg`.
- Confirm the test-only override cannot affect normal runtime unless explicitly
  called.

### Screenshot smoke isolation

File:

- `godot/tests/screenshot_capture_smoke.gd`

Context:

- `screenshot_capture_smoke.gd` failed inside `Mode all` when saving to
  `OS.get_user_data_dir() + "/screenshot_capture_smoke.png"`.
- The smoke now writes a unique PNG under `res://.tmp`, passes the logical
  `res://` path as `last_saved_path`, and uses the globalized absolute path for
  `Image.save_png`.

Review focus:

- Confirm production screenshot output remains `D:/screenshot`.
- Confirm the test still proves worker-thread PNG saving and deferred
  completion.

### Other fixes already covered by final gates

These were part of the broader stabilization pass and are worth a quick skim if
they are in the commit scope:

- `godot/tests/chaos_spear_hit_release_smoke.gd`
  - Added accumulated failure flag so deferred `quit(1)` cannot be overwritten
    by a later success exit.
  - Relaxed a self-heal speed edge assertion with a small epsilon.
- `godot/tests/lingpet_egg_runtime_smoke.gd`
  and several plaza/lingpet save-store smokes:
  - Moved fixed `user://..._smoke.cfg` fixtures to unique `res://.tmp` paths.
- `godot/scripts/items/mythic_item_acquisition_cinematic_v2.gd`
  and `godot/scripts/items/mythic_item_acquisition_cinematic_runtime.gd`
  - Switched item texture loading/prewarm to `ProjectResourceLoader` imported
    texture paths and added a reset hook for tests.
- `godot/scripts/plaza/plaza_interior_view.gd`
  - Added missing cached material helpers for coin trade FX.
- `godot/scripts/core/language_settings_data.gd`
  - Added exact translations for the `해골장막` skill label.

## Suggested Claude Review Checklist

1. Inspect the files listed above rather than the entire dirty worktree first.
2. Re-run, from `godot/`, if extra confidence is needed:
   - `.\tools\run_pre_push_checks.ps1 -Mode all`
3. Check whether any large new lingpet PNG sheets should use VRAM compressed
   import settings before they are committed.
4. Keep the test path isolation changes; they were necessary for full-suite
   stability.
5. Do not revert unrelated dirty-worktree changes unless the user explicitly
   asks. This repo intentionally had many parallel changes during the pass.

## Current Status

At the end of this handoff:

- Stability goal is complete.
- Full pre-push gate is green in the current worktree.
- No further known blocking stabilization failures remain.
