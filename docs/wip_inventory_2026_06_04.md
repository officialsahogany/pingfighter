# WIP Inventory - 2026-06-04

Snapshot taken after runtime HEAD
`be873f691 godot: route Stage 6 Tetriser pillar background`.

Purpose: classify the current dirty worktree before starting new work. Do not
use `git add .` from this state. Stage one bundle at a time and re-run the
listed focused checks before each commit.

## Snapshot

- Runtime HEAD at capture:
  `be873f691 godot: route Stage 6 Tetriser pillar background`
- Staged changes at capture: none
- File-level inventory from `git diff --name-status` plus
  `git ls-files --others --exclude-standard`:
  - tracked changed files: 238
  - untracked files: 408
  - total file-level WIP entries: 646
- `git status --short` shows fewer lines because some untracked directories are
  collapsed by Git status output.
- Previously observed validation in this thread. Re-run the relevant checks
  before committing any runtime bundle:
  - Stage 6 focused smokes passed:
    `stage6_tetriser_state_smoke`,
    `battle_scene_stage_transition_loading_smoke`,
    `battle_perf_logger_smoke`,
    `stage_actor_transient_cleanup_smoke`,
    `stage_actor_renderer_arity_cache_smoke`
  - `godot/tools/run_headless_load_check.ps1` passed
  - `godot/tools/run_warning_scan.ps1 -ChunkSize 100` passed

## Bundle Map

| Bundle | Count | Status Mix | Risk | Suggested Owner / Meaning |
| --- | ---: | --- | --- | --- |
| Lingpet runtime/assets | 234 | 25 modified, 209 untracked | High | Large lingpet expansion: catalog, loadout/current profile, egg/runtime host, skill scripts, companion/cutin/click assets, lingpet sounds, and lingpet smokes. |
| Viper runtime refactor | 68 | 19 modified, 49 untracked | High | Viper skill runtime split plus cut-in/runtime support files and Viper smoke updates. |
| Shared gameplay / ball / audio / HUD leftovers | 63 | 28 modified, 35 untracked | High | Mixed dependency tail: AI, ball, audio cleanup, runtime perk catalog, skill cut-in host, tooltip tutorial split, loose lingpet smoke files. Needs manual owner audit before commit. |
| Core/loading/prewarm/perf/resources | 55 | 43 modified, 12 untracked | High | Boot/prewarm/loading/perf split work, resource loader changes, language settings data split, local tooling/addon/export config. |
| Active/mythic items | 55 | 39 modified, 16 untracked | High | Active item runtime/effect routing, field item motion/spawn, milk bottle assets, mythic/Ragnarok changes, item smokes. |
| Cross-stage/render/weather/status | 50 | 32 modified, 18 untracked | Medium-High | Stage 1-5 render touch points, weather/status/effects helpers, boss electric stun/electrocution VFX and tests. |
| Smasher drive/ghost/cutin/result | 40 | 8 modified, 4 deleted, 28 untracked | High | Smasher drive/ghost states, cut-in assets/renderers, voice/cutin smokes, plus deleted tracked Smasher result assets. Verify deletes before staging. |
| Commando/firearm/supply | 38 | 24 modified, 14 untracked | Medium-High | Commando firearm/supply runtime, aircraft crash assets, sound assets, and commando smokes. |
| Result screen/assets | 32 | 9 modified, 23 untracked | High | Stage-clear result scene/loader/layout, result scroll asset, Stage 3 Menhera result assets, export-sensitive result smokes. |
| Docs/agent/workflow | 11 | 7 modified, 4 untracked | Medium | AGENTS/docs/skills updates plus `.github` workflow/dependabot/copilot instruction files. Keep separate from runtime code. |

## Recommended Commit Order

1. **Temporary / local cleanup decision**
   - Inspect and either commit intentionally or remove from the staged plan:
     `godot/tests/zz_cutin_downscale_check.gd.uid`, and any purely local
     one-off launch/check files.
   - Do not delete user work blindly; just keep these out of unrelated commits
     until their intent is confirmed.

2. **Overlay/prewarm review follow-ups**
   - Candidate message: `godot: close overlay prewarm follow-up gaps`
   - Likely paths:
     `godot/scripts/core/battle_boot_resource_prewarm_controller.gd`,
     `godot/scripts/core/battle_pso_prewarmer.gd`,
     `godot/scripts/hud/character_info_overlay_lingpet_presenter.gd`,
     `godot/scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd`,
     related character info / prewarm smokes.
   - Reason:
     covers the known post-overlay review items: cutin art prewarm, PSO
     dead-wrapper footgun, and export-safe lingpet art loading if included.
   - Checks:
     `character_info_overlay_prewarm_smoke`,
     `character_info_live_stats_smoke`,
     `battle_boot_resource_prewarm_smoke`,
     headless load, warning scan.

3. **Core loading / prewarm / language split**
   - Candidate message: `godot: split boot prewarm and language helpers`
   - Keep this separate because `language_settings.gd` has a very large diff and
     new data/helper files are present.
   - Checks:
     `battle_boot_resource_prewarm_smoke`,
     `battle_loading_screen_renderer_smoke`,
     `battle_pso_prewarmer_smoke`,
     `update_prewarm_driver_smoke`,
     `language_settings_smoke`,
     headless load, warning scan.

4. **Lingpet runtime/assets**
   - Split this further; do not make a single 234-file commit unless absolutely
     necessary.
   - Suggested sub-bundles:
     - catalog/loadout/current-profile runtime state
     - companion/cutin/click art imports and manifests
     - individual skill runtime files: bomb surprise, bubble trap, dragon
       breath, gatling burst, milk production, thunder orb
     - lingpet sounds and skill tests
   - Checks:
     relevant `lingpet_*_smoke` tests, `character_info_live_stats_smoke`,
     `lingpet_egg_runtime_smoke`, headless load, warning scan.

5. **Viper runtime refactor**
   - Candidate message: `godot: split Viper skill runtime modules`
   - Verify all new `viper_skill_*_runtime.gd` files are intentionally wired.
   - Checks:
     all `viper_*_port_smoke` tests, `viper_marshal_render_budget_smoke`,
     headless load, warning scan.

6. **Smasher drive / ghost / cut-in**
   - Candidate message: `godot: add Smasher drive and ghost cut-in runtime`
   - First verify the four deleted tracked Smasher result assets have intended
     replacements or should be restored.
   - Checks:
     `smasher_drive_cutin_smoke`,
     `smasher_drive_cutin_fx_host_smoke`,
     `smasher_ghost_possession_state_smoke`,
     `smasher_ghost_possession_integration_smoke`,
     `smasher_power_smash_cutin_smoke`,
     result screen export-sensitive smokes if asset deletes remain.

7. **Active/mythic item runtime**
   - Candidate message: `godot: wire active item runtime polish`
   - Use `docs/item_runtime_checklist.md` before staging.
   - Checks:
     active-item smoke set, `item_field_spawn_pool_smoke`,
     `ragnarok_hammer_port_smoke`,
     `mythic_item_acquisition_cinematic_smoke`,
     export-sensitive result/resource loader smokes if visual assets changed.

8. **Commando firearm/supply**
   - Candidate message: `godot: polish Commando firearm and supply runtime`
   - Checks:
     commando firearm/supply smoke set, audio cleanup smoke, headless load,
     warning scan.

9. **Result screen/assets**
    - Candidate message: `godot: update stage clear result assets`
    - Export-sensitive. Keep separate from gameplay runtime.
    - Checks:
      `stage_clear_result_asset_loader_smoke`,
      `stage_clear_result_layout_helper_smoke`,
      `stage_clear_result_scene_click_reaction_smoke`,
      `stage_clear_result_scroll_state_smoke`,
      `project_resource_loader_import_preference_smoke`,
      headless load, warning scan.

10. **Cross-stage render/weather/status**
    - Candidate message: `godot: consolidate shared stage render helpers`
    - Stage after feature-specific commits so failures can be traced.
    - Checks:
      stage render budget smokes, weather smokes, status effect smokes,
      boss electrocution/electric stun smokes, headless load, warning scan.

11. **Docs / workflow**
    - Candidate message: `docs: update Godot workflow and skill guardrails`
    - Keep `.github` workflow/dependabot/copilot files in a separate commit from
      runtime code.
    - Checks:
      text review plus any CI workflow syntax checks available locally.

## Immediate Risk Notes

- The largest current risk is not Stage 6; it is cross-bundle mixing. Several
  modified core files may be dependencies of lingpet, Viper, Smasher, item, and
  result work at the same time.
- The Smasher bundle includes tracked deletes. Do not stage that bundle until
  the replacement result assets are confirmed.
- The lingpet bundle contains hundreds of generated/imported files. Prefer
  asset-manifest-driven staging over broad directory staging.
- The `.github` additions are workflow changes. They should not ride along with
  Godot runtime commits.
- Git reports many line-ending normalization warnings while diffing. Treat line
  ending churn as a separate review surface before committing broad files.
