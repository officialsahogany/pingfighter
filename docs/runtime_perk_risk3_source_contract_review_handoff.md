# RuntimePerk Risk #3 Source-Contract Review Handoff

Date: 2026-07-09
Branch: `fix/plaza-lingpet-egg-full-roster-test`
Local base while preparing this handoff: `3835e28c0`

Purpose: hand this RuntimePerk refactor slice to Claude for adversarial review
before committing. The slice closes Risk #3 from the previous review backlog:
source-contract smoke helpers used `source.find("\n\nfunc ")` to end a function
body, so a comment- or annotation-adjacent sibling `func` could be swallowed
into the previous body and produce a false GREEN.

## Review Scope

Primary files:

- `godot/tests/source_contract_function_body.gd`
- `godot/tests/source_contract_function_body.gd.uid`
- `godot/tests/source_contract_function_body_smoke.gd`
- `godot/tests/source_contract_function_body_smoke.gd.uid`
- `godot/tests/*_smoke.gd` files that define `_function_body`,
  `_source_function_body`, or `_extract_function_body`
- `docs/character_skill_perk_checklist.md`
- `docs/runtime_perk_modularization_checkpoint_prep.md`
- `docs/refactor_status_brief.md`
- `docs/current_development_boundary.md`
- `docs/godot_module_ownership_ledger.md`
- `docs/godot_port_architecture.md`

The source-contract smokes now preload the shared extractor and their local
body helpers delegate to `SourceContractFunctionBody.extract(source, signature)`.
The final seal is repo-wide for `*_smoke.gd`, not runtime-perk-only.

The extractor searches for the next top-level `func ` or `static func ` line,
keeps nested class methods inside the current body, and rewinds across leading
blank/comment/annotation lines that belong to the next top-level function. This
prevents the previous function body from swallowing the next function's
source-contract comments or annotations.

## Seal / Counterproof

`source_contract_function_body_smoke.gd` covers:

- comment-adjacent next function: old `\n\nfunc` heuristic swallowed the next
  function and its comments.
- annotation-adjacent `static func`: old heuristic failed to stop at top-level
  static functions.
- target function itself is `static func` and continues to EOF.
- CRLF source text with comment-adjacent next function.
- nested class method: extractor must not treat an indented `func` as a
  top-level boundary.
- all smoke files with local `_function_body()`, `_source_function_body()`, or
  `_extract_function_body()` must delegate to the shared extractor inside the
  helper body.
- smokes must not retain `source.find("\n\nfunc ")`, direct
  `.find("\nfunc ")`, or direct `.find("\nstatic func ")` source-body
  boundary parsing.

RED verification was done in-place: temporarily changed
`source_contract_function_body.gd::extract()` back to
`source.find("\n\nfunc ", start + signature.length())`. The new smoke failed on
the comment-adjacent and `static func` cases. Restoring the shared extractor
returned it to GREEN.

## Verification Already Run

From `godot/`:

- `.\tools\run_smoke_tests.ps1 -Tests @('res://tests/source_contract_function_body_smoke.gd')`
- `.\tools\run_smoke_tests.ps1 -Tests $runtimePerkTests`
  where `$runtimePerkTests` is all `tests/runtime_perk*_smoke.gd` files
  currently in the worktree; 54 total, all GREEN.
- `.\tools\run_smoke_tests.ps1 -Tests @('res://tests/refactor_status_brief_smoke.gd','res://tests/source_contract_function_body_smoke.gd')`
- `.\tools\run_headless_load_check.ps1`
- `.\tools\run_warning_scan.ps1`
- `git diff --check`

`refactor_status_brief_smoke.gd` was failing because the snapshot doc counts
were stale in the current dirty worktree. The slice updates only the guarded
count fields in `docs/refactor_status_brief.md` and
`docs/current_development_boundary.md`; that smoke is GREEN again.

Latest finalization pass, after the follow-up migrations:

- `.\tools\run_smoke_tests.ps1 -Tests @('res://tests/source_contract_function_body_smoke.gd','res://tests/lingpet_egg_runtime_smoke.gd')`
- `.\tools\run_smoke_tests.ps1 -Tests @('res://tests/source_contract_function_body_smoke.gd','res://tests/pause_menu_overlay_smoke.gd','res://tests/active_item_slot_controller_polling_smoke.gd','res://tests/serve_flow_gamepad_input_smoke.gd','res://tests/stage5_hongryun_mvp_runtime_smoke.gd')`
- `.\tools\run_headless_load_check.ps1`
- `.\tools\run_warning_scan.ps1` scanned 2292 scripts with no warnings.
- Scoped `git diff --check` passed for the source-contract helper, smoke,
  checklist, and this handoff doc.
- Static audit: outside `source_contract_function_body.gd` itself, no Godot
  `.gd` file still uses direct `.find("\nfunc ")`,
  `.find("\nstatic func ")`, or `find("\n\nfunc ")` source-body boundary
  parsing.
- Static audit: every smoke helper named `_function_body()`,
  `_source_function_body()`, or `_extract_function_body()` delegates inside
  the helper body to `SourceContractFunctionBody.extract`.

Latest baseline check after the adjacent stale-doc cleanup:

- `.\tools\run_headless_load_check.ps1`: passed.
- `.\tools\run_warning_scan.ps1`: scanned 2292 scripts with no warnings.
- `.\tools\run_smoke_tests.ps1 -Tests @('res://tests/refactor_status_brief_smoke.gd')`: passed.
- Static audit: current source-of-truth docs
  (`docs/godot_module_ownership_ledger.md`, `docs/godot_port_architecture.md`,
  `docs/current_development_boundary.md`, and `docs/refactor_status_brief.md`)
  no longer reference the deleted `treasure_hunt_runtime`,
  `treasure_map_perk_port_smoke`, `revival_port_smoke`,
  `speedgear_port_smoke`, `mythic_item_revival_runtime`, `revival_state.gd`,
  `Speed Gear`, or `Revival Charm` current surfaces.
- The staged deletion set for revival / speedgear / treasure-map assets,
  runtimes, and smokes was preserved as-is; no stage / commit operation was
  performed by this slice.

## Out Of Scope / Existing WIP

Do not treat these as part of this Risk #3 slice:

- The staged deletion set for revival / speedgear / treasure-map assets,
  runtimes, and smokes. Those were already staged before this slice.
- Unstaged treasure/removal and passive-to-perk WIP.
- `runtime_perk_resume_safety_release_smoke.gd` appears as an added file in
  the current diff because it is part of the broader uncommitted runtime-perk
  refactor WIP. This handoff is concerned only with the source-contract
  extractor / smoke-helper migration and the adjacent current-owner doc cleanup.
- `docs/passive_to_perk_conversion_plan.md` still contains historical design
  table entries for `revival`, `speedgear`, and treasure-map / hunt
  conversion work. Those are planning records, not current owner claims, and
  were intentionally left to the passive-to-perk stream.

The non-runtime source-contract migration started as follow-up test-only
slices after the initial runtime-perk seal, but it is now intentionally part of
this final review packet. At the current handoff state, every smoke-local body
helper delegates to the shared extractor, and the old newline-function
heuristics are banned across all smokes.

Follow-up note: the non-runtime blank-line boundary cleanup was later done as
a narrow test-only slice. `source_contract_function_body_smoke.gd` now scans
all `*_smoke.gd` files for `source.find("\n\nfunc ")`, and the remaining
blank-line heuristic users were migrated to `SourceContractFunctionBody`:
`active_item_throw_molotov_smoke.gd`, `chaos_spear_draw_transform_smoke.gd`,
`commando_firearm_audio_routing_smoke.gd`,
`horn_strawberry_audio_vfx_smoke.gd`, `ingame_gold_reward_parity_smoke.gd`,
and `viper_ignition_aura_port_smoke.gd`.

Second follow-up note: the same shared extractor migration was extended to the
render-budget / LOD smoke batch that already used local `_function_body()`
wrappers, including active-item throw / field renderer, stage render budget,
weather budget, scoreboard overlay budget, and severe-LOD guard smokes.

Final follow-up note: the last broad test batch was migrated too. The seal now
checks every `*_smoke.gd` file, not just `runtime_perk*`, so any future local
`_function_body()` helper must delegate to `SourceContractFunctionBody.extract`.
The seal was then widened again for existing alias helpers
(`_source_function_body()` / `_extract_function_body()`), and those helpers now
delegate to the same shared extractor as well. The final guard checks the
helper body itself, so a file-level `SourceContractFunctionBody` mention cannot
produce a false GREEN while a local helper still uses its own boundary parser.
It also bans direct inline `.find("\nfunc ")` / `.find("\nstatic func ")`
source-body boundary parsing in smokes; the remaining inline users in
`lingpet_egg_runtime_smoke.gd` were migrated to the shared `_function_body()`
wrapper.

## Review Questions

1. Is `_next_top_level_function_start()` robust enough for current GDScript
   source-contract smoke usage, especially `func`, `static func`, annotations,
   comments, and nested class methods?
2. Does `_rewind_leading_source_contract_lines()` correctly exclude comments /
   annotations attached to the next function without trimming real trailing
   assertions from the current function?
3. Is the repo-wide smoke seal scope appropriate now that all remaining
   `_function_body()` helpers delegate to the shared extractor?
4. Are the refactor status count updates acceptable in this slice, given they
   only restore the existing `refactor_status_brief_smoke` guard?
5. Is the adjacent owner-doc cleanup acceptable to keep in the same review
   packet, or should it be hunk-split as a separate documentation-only commit?
