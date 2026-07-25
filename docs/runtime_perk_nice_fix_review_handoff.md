# RuntimePerk Nice-Fix Review Handoff

Date: 2026-07-09
Branch: `fix/plaza-lingpet-egg-full-roster-test`
Local HEAD while preparing this handoff: `436d6767c`

Purpose: hand the latest RuntimePerk refactor cleanup slice to Claude for
adversarial review before hunk-splitting / commit. This slice closes eight
post-Risk backlog items after the earlier blocker, facade-rename, and
source-contract work:

- Optimus / IO / Commando character alias mapping duplicated in unlock flight
  and showcase helpers.
- Registry `get_instance` policy duplicated in the same unlock flight and
  showcase helpers.
- Result-screen starpoint perk reward data deep-copying the full
  `RuntimePerkState.get_snapshot()` result a second time.
- Runtime-perk update facade allocating helper context / callback maps on
  fully idle frames.
- Runtime-state object / dictionary / callable accessor policy duplicated in
  instant-choice, snapshot-builder, starpoint, gold-award, active-flight, and
  unlock-showcase, level-side-effect, choice-opening, and choice-selection
  runtime-state facades.
- Runtime-state float fallback policy duplicated in unlock-choice and debug
  grant feedback-timer lookup.
- Callback-first registry lookup policy duplicated in choice audio and
  choice-offer modifier mythic-runtime lookup.
- Callback-map invocation policy duplicated across migrated choice/update/
  modal/debug helpers.
- Source-object method calls duplicated in snapshot / starpoint helpers.
- Loose payload normalization duplicated across migrated choice, layout,
  showcase, snapshot, owner-sync, and flow helpers.
- Deferred instant owner-stage fallback duplicated beside
  `RuntimePerkCharacterContext.get_current_stage()`.

## Review Scope

Primary code files:

- `godot/scripts/characters/runtime_perk_character_context.gd`
- `godot/scripts/characters/runtime_perk_deferred_instants.gd`
- `godot/scripts/characters/runtime_perk_registry_lookup.gd`
- `godot/scripts/characters/runtime_perk_runtime_state_access.gd`
- `godot/scripts/characters/runtime_perk_callback_map.gd`
- `godot/scripts/characters/runtime_perk_payload_access.gd`
- `godot/scripts/characters/runtime_perk_active_unlock_flight.gd`
- `godot/scripts/characters/runtime_perk_unlock_showcase.gd`
- `godot/scripts/characters/runtime_perk_instant_choice_flow.gd`
- `godot/scripts/characters/runtime_perk_snapshot_builder.gd`
- `godot/scripts/characters/runtime_perk_starpoint_absorption.gd`
- `godot/scripts/characters/runtime_perk_starpoint_collection_flow.gd`
- `godot/scripts/characters/runtime_perk_gold_award_flow.gd`
- `godot/scripts/characters/runtime_perk_level_side_effects.gd`
- `godot/scripts/characters/runtime_perk_choice_opening.gd`
- `godot/scripts/characters/runtime_perk_choice_selection.gd`
- `godot/scripts/characters/runtime_perk_choice_feedback.gd`
- `godot/scripts/characters/runtime_perk_dynamic_effects.gd`
- `godot/scripts/characters/runtime_perk_choice_open_flow.gd`
- `godot/scripts/characters/runtime_perk_choice_finish_flow.gd`
- `godot/scripts/characters/runtime_perk_choice_apply_flow.gd`
- `godot/scripts/characters/runtime_perk_choice_action_runner.gd`
- `godot/scripts/characters/runtime_perk_choice_completion.gd`
- `godot/scripts/characters/runtime_perk_choice_standard_path.gd`
- `godot/scripts/characters/runtime_perk_unlock_choice_apply.gd`
- `godot/scripts/characters/runtime_perk_unlock_showcase_flow.gd`
- `godot/scripts/characters/runtime_perk_debug_grants.gd`
- `godot/scripts/characters/runtime_perk_unlock_swap_flow.gd`
- `godot/scripts/characters/runtime_perk_choice_confirm_flow.gd`
- `godot/scripts/characters/runtime_perk_update_flow.gd`
- `godot/scripts/characters/runtime_perk_owner_effect_sync.gd`
- `godot/scripts/characters/runtime_perk_owner_projection.gd`
- `godot/scripts/characters/runtime_perk_resume_safety.gd`
- `godot/scripts/characters/runtime_perk_unlock_swap_layout.gd`
- `godot/scripts/core/stage_clear_result_starpoint_perk_reward_data.gd`

Primary smoke files:

- `godot/tests/runtime_perk_character_context_smoke.gd`
- `godot/tests/runtime_perk_registry_lookup_smoke.gd`
- `godot/tests/runtime_perk_runtime_state_access_smoke.gd`
- `godot/tests/runtime_perk_callback_map_smoke.gd`
- `godot/tests/runtime_perk_payload_access_smoke.gd`
- `godot/tests/runtime_perk_instant_choice_flow_smoke.gd`
- `godot/tests/runtime_perk_snapshot_builder_smoke.gd`
- `godot/tests/runtime_perk_starpoint_absorption_smoke.gd`
- `godot/tests/runtime_perk_starpoint_collection_flow_smoke.gd`
- `godot/tests/runtime_perk_gold_award_flow_smoke.gd`
- `godot/tests/runtime_perk_level_side_effects_smoke.gd`
- `godot/tests/runtime_perk_choice_opening_smoke.gd`
- `godot/tests/runtime_perk_choice_selection_smoke.gd`
- `godot/tests/runtime_perk_choice_feedback_smoke.gd`
- `godot/tests/runtime_perk_dynamic_effects_smoke.gd`
- `godot/tests/runtime_perk_choice_open_flow_smoke.gd`
- `godot/tests/runtime_perk_choice_finish_flow_smoke.gd`
- `godot/tests/runtime_perk_choice_apply_flow_smoke.gd`
- `godot/tests/runtime_perk_unlock_choice_apply_smoke.gd`
- `godot/tests/runtime_perk_unlock_showcase_flow_smoke.gd`
- `godot/tests/runtime_perk_debug_grants_smoke.gd`
- `godot/tests/runtime_perk_unlock_swap_flow_smoke.gd`
- `godot/tests/runtime_perk_choice_confirm_flow_smoke.gd`
- `godot/tests/runtime_perk_update_flow_smoke.gd`
- `godot/tests/runtime_perk_state_facade_contract_smoke.gd`
- `godot/tests/source_contract_function_body_smoke.gd`
- `godot/tests/stage_clear_result_starpoint_choice_handler_smoke.gd`

Docs touched for durable rules:

- `docs/character_skill_perk_checklist.md`
- `docs/runtime_perk_modularization_checkpoint_prep.md`

## Slice Details

### 1. Character Alias Mapping Dedup

`runtime_perk_active_unlock_flight.gd` and
`runtime_perk_unlock_showcase.gd` now preload and instantiate
`RuntimePerkCharacterContext` and `RuntimePerkRegistryLookup`.

They no longer keep local `_get_skill_config_key()` or
`_normalize_character_type()` copies, and they no longer read
`owner.selected_character_type` locally. Both helpers call:

- `_character_context.normalize_character_type(...)`
- `_character_context.get_skill_config_key(...)`
- `_character_context.get_normalized_owner_character_type(...)`
- `_registry_lookup.get_instance(...)`

Important preserved behavior:
`RuntimePerkCharacterContext.get_normalized_owner_character_type()` normalizes
the raw owner `selected_character_type` value while preserving Optimus / IO as
`optimus`. Flight/showcase deliberately do **not** call
`RuntimePerkCharacterContext.get_owner_character_type()`, because that state
compatibility wrapper intentionally maps owner Optimus back to `smasher`.

Seal:

- `runtime_perk_character_context_smoke.gd` asserts active-unlock flight and
  unlock showcase both use `RuntimePerkCharacterContext`.
- It also asserts those two files do not revive local
  `_get_skill_config_key()` or `_normalize_character_type()` functions.
- It asserts those helpers use `get_normalized_owner_character_type()`, do not
  call `get_owner_character_type()`, and do not read `selected_character_type`
  locally.
- It now also asserts those helpers use `RuntimePerkRegistryLookup`, delegate
  directly through `_registry_lookup.get_instance(...)`, do not keep
  pass-through `_get_character_type()` / `_get_instance()` wrappers, and do
  not inline the `has_method("get_instance")` registry API policy.
- `RuntimePerkRegistryLookup` also owns callback-first lookup through
  `get_instance_from_callable(...)`. Choice audio uses the fallback-to-registry
  path for `game_audio`, while choice-offer modifiers pass `false` to preserve
  callback-only mythic-runtime semantics.
- It also asserts deferred instants route owner-stage reads through
  `RuntimePerkCharacterContext.get_current_stage()` and do not revive a local
  `_get_current_stage()` wrapper.

RED verification:

- Contract was added before production edits.
- `runtime_perk_character_context_smoke.gd` failed for both helpers:
  missing `RuntimePerkCharacterContext`, local skill-config mapping still
  present, local normalization still present.
- Production refactor returned it to GREEN. The later registry-lookup seal was
  added after the shared `RuntimePerkRegistryLookup` owner existed; focused
  smokes confirm active-unlock flight and unlock showcase still resolve
  registry dependencies correctly.

### 2. Result-Screen Snapshot Second Copy Removal

`stage_clear_result_starpoint_perk_reward_data.gd`'s
`get_runtime_perk_snapshot()` now returns the Dictionary produced by
`runtime_perk_state.get_snapshot()` directly instead of:

```gdscript
return (snapshot_value as Dictionary).duplicate(true)
```

Reason: `RuntimePerkState.get_snapshot()` already delegates to
`RuntimePerkSnapshotBuilder`, which deep-copies the nested runtime-perk
snapshot fields. The result-screen helper is a read-only consumer and should
not deep-copy the whole snapshot again.

Seal:

- `stage_clear_result_starpoint_choice_handler_smoke.gd` mutates
  `last_selected_choice` from the returned snapshot and asserts the fake
  runtime state's original choice stays unchanged. This proves mutation safety
  still comes from the runtime snapshot builder copy.
- The same smoke asserts the removed second-copy line is not reintroduced.

RED verification:

- Smoke source-contract was added before the production one-line change.
- It failed only on the second-copy source-contract assertion.
- Removing the duplicate copy returned it to GREEN.

### 3. RuntimePerk Update Idle Fast Path

`runtime_perk_update_flow.gd::update_internal_from_runtime_state()` now returns
early for fully idle frames:

```gdscript
{"accepted": true, "idle": true}
```

The idle gate stays conservative. It refuses the fast path when any of these
are live:

- `feedback_timer > 0`
- `pending_skill_choices > 0`
- `choice_active`
- non-empty `pending_unlock_swap`
- active `choice_flight_effect`
- active `unlock_showcase`
- active `_starpoint_absorption`

This avoids building `build_update_context(...)`, helper lookup arguments, and
`build_state_callbacks(runtime_state)` on true no-op frames, while keeping all
modal / pending / feedback / effect frames on the existing live path.

Seal:

- `runtime_perk_update_flow_smoke.gd` verifies a fully idle runtime-state
  facade call returns accepted idle, does not tick feedback/opening/layout,
  does not append runtime branch events, and emits no perf samples.
- It also verifies `pending_skill_choices = 1` disables the idle fast path and
  still reaches the active-gate branch.
- Source-contract checks require `_is_runtime_state_idle(runtime_state)` in
  the facade and `func _is_runtime_state_idle(` in the helper.

RED verification:

- Smoke was added before production edits.
- It failed because the old facade still ran feedback / active-gate / perf
  branches and returned the inactive-choice rejection instead of accepted idle.
- Adding the idle gate returned it to GREEN.

### 4. Runtime-State Accessor Policy Dedup

`runtime_perk_runtime_state_access.gd` now owns the shared runtime-state facade
access policy for the migrated callers:

- `get_object(runtime_state, key)`
- `get_dict(runtime_state, key)`
- `get_array(runtime_state, key)`
- `get_int(runtime_state, key)`
- `get_float(runtime_state, key)`
- `get_bool(runtime_state, key)`
- `get_string(runtime_state, key)`
- `build_callable(runtime_state, method)`
- `call_dict(source, method, args)`
- `call_int(source, method, args)`
- `call_float(source, method, args)`
- `call_bool(source, method, args)`

`runtime_perk_instant_choice_flow.gd` now uses it for `_instant_rewards`,
`_character_context`, `_deferred_instants`, `_choice_feedback`,
`current_choice_context`, and the runtime-state `_get_instance` callback.
`runtime_perk_snapshot_builder.gd` now uses it for `_starpoint_absorption` and
`_deferred_instants`. `runtime_perk_starpoint_absorption.gd`,
`runtime_perk_starpoint_collection_flow.gd`, and
`runtime_perk_gold_award_flow.gd` now use it for their runtime-state helper
lookups and runtime-state `_get_instance` / `_sync_owner` callbacks.
`runtime_perk_active_unlock_flight.gd` and `runtime_perk_unlock_showcase.gd`
now use it for their runtime-state active-state dictionary queries.
`runtime_perk_level_side_effects.gd`, `runtime_perk_choice_opening.gd`,
`runtime_perk_choice_layout.gd`, `runtime_perk_choice_selection.gd`, and
`runtime_perk_choice_feedback.gd` now use it for runtime-state helper lookups,
layout / selectable inputs, feedback text / timer reads, and callback assembly
used by level side effects, pending-swap checks, selectable gates, and feedback
wrappers.
`runtime_perk_dynamic_effects.gd` and
`runtime_perk_choice_open_flow.gd` now use it for their runtime-state
effective-level / choice-open helper assembly. `runtime_perk_choice_finish_flow.gd`,
`runtime_perk_choice_apply_flow.gd`, `runtime_perk_unlock_choice_apply.gd`, and
`runtime_perk_unlock_showcase_flow.gd` now use it for finish/apply/unlock/
showcase facade helper and state lookups. `runtime_perk_debug_grants.gd`,
`runtime_perk_unlock_swap_flow.gd`, `runtime_perk_choice_confirm_flow.gd`, and
`runtime_perk_update_flow.gd` now use it for the remaining runtime-state
object/dictionary/array plus int / float / bool / string lookups.
`runtime_perk_unlock_swap_layout.gd` uses it for pending-swap layout input.
`runtime_perk_gamepad_navigation.gd` also uses it for the live latch integer
lookup, and `runtime_perk_skill_cooldown_pause.gd` uses it for its stored pause
helper facade. `runtime_perk_resume_safety.gd` uses it for resume-safety and
dynamic-effect helper lookup. `runtime_perk_reset_state.gd` uses it for reset
lifecycle helper and payload lookups. `runtime_perk_snapshot_builder.gd` and
`runtime_perk_starpoint_absorption.gd` now also use the shared source-object
method callers for helper snapshots, deferred-instant queries, Viper bonus
queries, active checks, and flight layout lookup. The remaining local helpers
in those files are domain-specific helpers, not duplicate runtime-state access
or payload-normalization policy.
`runtime_perk_update_flow.gd` no longer keeps the now-dead plain `_get_array()`
or `_get_dict()` wrappers left behind by the shared-accessor migration.
`runtime_perk_lingpet_rewards.gd`, `runtime_perk_choice_audio.gd`,
`runtime_perk_effective_stat_query_surface.gd`, and
`runtime_perk_owner_sync_flow.gd` now use
`build_callable(runtime_state, "_get_instance")`; the effective-stat and
owner-sync paths pass `Callable(self, "_missing_instance")` as the fallback to
preserve their previous valid null-return fallback callable semantics. The
effective-stat query surface also uses shared runtime-state getters for
effective-level helper, runtime levels, item-bonus, and Viper-active inputs,
and routes repeated effective-level float method dispatch through
`RuntimePerkRuntimeStateAccess.call_float(...)`.
`runtime_perk_update_flow.gd` also builds its runtime-state branch callback map
through `RuntimePerkRuntimeStateAccess.build_callable(...)`, sealing direct
`Callable(runtime_state, ...)` reconstruction in that helper.
`runtime_perk_unlock_showcase_flow.gd` follows the same callback-builder path
for finish, owner-sync, and active-query callbacks.
`runtime_perk_starpoint_collection_flow.gd` and
`runtime_perk_dynamic_effects.gd` also route their runtime-state callback maps
through the shared builder.
`runtime_perk_choice_open_flow.gd`, `runtime_perk_choice_confirm_flow.gd`,
`runtime_perk_choice_finish_flow.gd`, `runtime_perk_unlock_swap_flow.gd`, and
`runtime_perk_unlock_choice_apply.gd` now do the same for choice opening,
choice confirm, choice completion, unlock-swap confirm, and active-skill unlock
callback maps. `runtime_perk_debug_grants.gd` also uses the shared builder for
its runtime-state grant callbacks, `runtime_perk_instant_choice_flow.gd` uses
it for spawn-intro deferred apply / owner-sync callbacks, and
`runtime_perk_choice_apply_flow.gd` does the same for defer, feedback, unlock,
and level side-effect callbacks.
Owner sync also no longer keeps local `_get_state_*` / `_call_state_*` helpers; its
projection and owner-effect facades now use the shared getter and typed method
callers, including explicit float fallbacks for cooldown-training sync.
`runtime_perk_unlock_swap_flow.gd` now uses
`build_callable(runtime_state, "_sync_owner")`.

`RuntimePerkRuntimeStateAccess` now also owns object / string source-method
dispatch for unlock-swap confirm setup, so `runtime_perk_unlock_swap_flow.gd`
does not keep local `_get_catalog_from_runtime_state()` /
`_get_character_type_from_runtime_state()` wrappers.
Unlock-choice apply also uses `call_string(...)` for injected
character-context owner / skill-config lookups and `get_float(..., fallback)`
for feedback timer lookup, so it no longer keeps local
`_get_owner_character_type()`, `_get_skill_config_key()`, or
`_get_level_feedback_timer()` wrappers. Debug grants use the same
`get_float(..., fallback)` path for their facade feedback timer lookup and no
longer keep a local `_get_level_feedback_timer()`.

`runtime_perk_callback_map.gd` now owns shared callback-map invocation policy
for the migrated callback-dictionary helpers:

- `get_callable(callbacks, key)`
- `call_optional(callbacks, key, args)`
- `call_acceptance(callbacks, key, args)`
- `call_strict_acceptance(callbacks, key, args)`
- `call_bool(callbacks, key, args, fallback)`
- `call_int(callbacks, key, args, fallback)`
- `call_void(callbacks, key, args)`
- `call_dict(callbacks, key, args)`
- `call_string(callbacks, key, args, fallback)`
- `call_array(callbacks, key, args)`
- `call_object(callbacks, key, args)`

`runtime_perk_choice_apply_flow.gd`, `runtime_perk_choice_finish_flow.gd`, and
`runtime_perk_choice_confirm_flow.gd` plus `runtime_perk_choice_open_flow.gd`
and `runtime_perk_update_flow.gd` plus
`runtime_perk_starpoint_collection_flow.gd` and
`runtime_perk_dynamic_effects.gd` plus
`runtime_perk_unlock_showcase_flow.gd` and `runtime_perk_modal_input.gd` use
it instead of local `_get_callback()` and `_call_*()` callback-map copies;
`runtime_perk_unlock_swap_flow.gd` uses the shared `get_callable()` lookup for
confirm/showcase handoff callbacks, and
`runtime_perk_unlock_choice_apply.gd` uses shared object / optional /
acceptance callback calls for skill-config lookup, owner sync, pending-swap
state application, and feedback application. `runtime_perk_debug_grants.gd`
uses shared strict-acceptance / optional / owner-sync callback lookups for
debug grant orchestration. `runtime_perk_choice_action_runner.gd` uses shared
strict-acceptance and dictionary callback calls while keeping the action-result
shape local to the runner.
The shared helper now includes `call_int()` and `call_void()` for modal-input
navigation / command callbacks, plus `call_acceptance()` for callbacks whose
non-dictionary result should become `{"accepted": bool(result)}`.
`call_strict_acceptance()` preserves dictionary results exactly and only casts
non-dictionary returns, which keeps debug-grant build/update callbacks
fail-closed when a returned payload omits `accepted`.

Seal:

- `runtime_perk_runtime_state_access_smoke.gd` verifies null / missing /
  wrong-type behavior for object, dictionary, array, and callable access.
  The callable check covers the optional fallback callable path, and typed
  method-call checks cover dictionary deep copies plus int / float / bool
  fallback behavior.
- It also asserts instant-choice flow, snapshot builder, starpoint absorption,
  starpoint collection flow, gold award flow, active-unlock flight, and unlock
  showcase plus level-side-effect, choice-opening, choice-selection,
  choice-layout, dynamic-effects, choice-open-flow, choice-completion,
  choice-finish-flow, choice-standard-path,
  choice-apply-flow, unlock-choice-apply, unlock-showcase-flow, debug-grants,
  unlock-swap-flow / layout,
  choice-confirm-flow, update-flow, skill-cooldown-pause, resume-safety, and
  reset-state preload
  `RuntimePerkRuntimeStateAccess`.
- It blocks local `_get_runtime_state_object()`,
  `_get_runtime_state_dict()`, `_get_runtime_state_array()`,
  `_get_runtime_state_int()`, `_get_runtime_state_float()`,
  `_get_runtime_state_bool()`, `_get_runtime_state_string()`, and
  `_build_runtime_state_get_instance()` copies in the migrated files.
- It also blocks direct `runtime_state.get(...)` in active-unlock flight,
  unlock showcase, starpoint absorption, starpoint collection flow, gold award
  flow / payload helper, reset state, unlock swap flow, debug grants, choice opening, open flow, layout / selection / feedback, choice completion, choice
  finish flow, choice standard path, effective-level state application,
  dynamic-effect facades, effective-stat query surface, and unlock-swap layout
  once those helpers have moved their live reads to the shared accessor.
- It also blocks the migrated Lingpet reward / choice-audio get-instance
  builders and unlock-swap sync-owner builder from reappearing locally.
- It also blocks owner-sync `_get_state_*` / `_call_state_*` helper copies from
  reappearing after the owner-sync runtime-state facade migration.
- It blocks effective-stat query surface direct `runtime_state.get(...)` reads
  and local runtime-state object accessor copies.
- `runtime_perk_skill_cooldown_pause_smoke.gd` and
  `runtime_perk_registry_lookup_smoke.gd` also block local skill-cooldown pause
  runtime-state / registry lookup helpers from reappearing.
- `runtime_perk_resume_safety_release_smoke.gd` plus the shared runtime-state
  and registry lookup smokes block resume-safety local runtime-state / registry
  lookup helpers from reappearing.
- `runtime_perk_reset_state_smoke.gd` plus the shared runtime-state smoke block
  reset-state local runtime-state object / dict lookup helpers and direct
  `runtime_state.get(...)` reads from reappearing.
- `runtime_perk_callback_map_smoke.gd` verifies callback lookup,
  optional-dictionary accepted-key injection, acceptance vs strict-acceptance
  semantics, dict invalid-result rejection, and bool / int / void / string /
  array / object casting and fallback behavior. Its source contract blocks
  local callback-map helper copies from reappearing in choice apply, choice
  finish, choice confirm, choice open, update flow, starpoint collection flow,
  dynamic effects, unlock showcase flow, modal input, unlock swap flow,
  unlock choice apply, debug grants, or choice action runner.

RED verification:

- Source-contract checks were added before production edits.
- They failed while the migrated files still carried local runtime-state access
  helpers.
- Migrating those files to `RuntimePerkRuntimeStateAccess` returned the
  focused smoke set to GREEN.

### 5. Payload Access Policy Dedup

`runtime_perk_payload_access.gd` now owns shared loose-payload access policy for
the migrated runtime-perk helpers:

- `as_dict(value)`
- `copy_dict(value)`
- `as_array(value)`
- `copy_array(value)`
- `as_vector2(value, fallback)`
- `as_color(value, fallback)`
- `as_rect2(value, fallback)`
- `get_value(source, key, fallback)`
- `get_string(source, key, fallback)`

The migrated set no longer keeps local `_get_dict()`, `_get_array()`,
`_get_vector2()`, `_get_color()`, `_get_rect2()`, `_safe_owner_get()`,
`_duplicate_dict_property()`, or `_duplicate_array_property()` copies. Current coverage includes active-unlock
flight, choice action runner, choice apply flow, choice completion, choice
confirm flow, choice finish flow, choice layout, choice offer modifiers, choice
opening, choice selection, choice standard path, debug
grants, owner-effect sync, owner projection, resume safety, snapshot builder,
starpoint absorption, unlock showcase, unlock-showcase flow, unlock-swap flow,
and unlock-swap layout.

Important preserved behavior:

- `copy_dict()` and `copy_array()` deep-copy nested payloads, preserving the
  old snapshot / selected-choice mutation boundary.
- `as_dict()` and `as_array()` preserve the old "return the live payload when
  type matches, otherwise empty" behavior used by flow helpers.
- `as_vector2()` preserves explicit fallback vectors for layout / cinematic
  positions.
- `as_color()` and `as_rect2()` preserve the old Color.WHITE / empty-Rect2
  fallback behavior used by active-unlock flight and unlock showcase.
- `get_value()` and `get_string()` preserve null-source and missing-property
  fallbacks for owner/runtime string properties.

Seal:

- `runtime_perk_payload_access_smoke.gd` verifies dictionary / array deep-copy
  behavior, loose dictionary / array / Vector2 casting, object property lookup,
  null fallback, and string casting.
- Its source contract requires every migrated helper to preload
  `RuntimePerkPayloadAccess` and blocks local payload helper copies from being
  reintroduced.
- It also checks representative method use per file, including dict, array,
  Vector2, owner-property, deep-copy dict/array, and string access.

RED verification:

- Source-contract checks were added before the final production migrations.
- They failed while migrated helpers still carried local payload fallback
  functions.
- Moving the remaining helpers to `RuntimePerkPayloadAccess` returned the
  focused smoke set and the full runtime-perk smoke set to GREEN.

## Verification Already Run

From `godot/`:

- Focused Optimus / showcase set:
  `runtime_perk_character_context_smoke`,
  `runtime_perk_registry_lookup_smoke`,
  `runtime_perk_active_unlock_flight_smoke`,
  `runtime_perk_unlock_showcase_smoke`,
  `runtime_perk_unlock_showcase_flow_smoke`
- Focused result-screen snapshot set:
  `stage_clear_result_starpoint_choice_handler_smoke`,
  `stage_clear_result_screen_smoke`,
  `stage_clear_result_box_data_smoke`,
  `runtime_perk_snapshot_builder_smoke`
- Focused runtime-state access set:
  `runtime_perk_runtime_state_access_smoke`,
  `runtime_perk_instant_choice_flow_smoke`,
  `runtime_perk_snapshot_builder_smoke`,
  `runtime_perk_starpoint_absorption_smoke`,
  `runtime_perk_starpoint_collection_flow_smoke`,
  `runtime_perk_gold_award_flow_smoke`,
  `runtime_perk_active_unlock_flight_smoke`,
  `runtime_perk_unlock_showcase_smoke`,
  `runtime_perk_level_side_effects_smoke`,
  `runtime_perk_choice_opening_smoke`,
  `runtime_perk_choice_selection_smoke`,
  `runtime_perk_choice_feedback_smoke`,
  `runtime_perk_dynamic_effects_smoke`,
  `runtime_perk_choice_open_flow_smoke`,
  `runtime_perk_choice_finish_flow_smoke`,
  `runtime_perk_choice_apply_flow_smoke`,
  `runtime_perk_unlock_choice_apply_smoke`,
  `runtime_perk_unlock_showcase_flow_smoke`,
  `runtime_perk_debug_grants_smoke`,
  `runtime_perk_unlock_swap_flow_smoke`,
  `runtime_perk_choice_confirm_flow_smoke`,
  `runtime_perk_update_flow_smoke`,
  `runtime_perk_owner_sync_flow_smoke`,
  `runtime_perk_choice_action_runner_smoke`,
  `runtime_perk_callback_map_smoke`,
  `runtime_perk_state_facade_contract_smoke`
- Focused source-object method caller set:
  `runtime_perk_runtime_state_access_smoke`,
  `runtime_perk_snapshot_builder_smoke`,
  `runtime_perk_starpoint_absorption_smoke`,
  `runtime_perk_state_facade_contract_smoke`
- Focused payload-access set:
  `runtime_perk_payload_access_smoke`,
  `runtime_perk_choice_completion_smoke`,
  `runtime_perk_choice_action_runner_smoke`,
  `runtime_perk_owner_projection_smoke`,
  `runtime_perk_choice_standard_path_smoke`,
  `runtime_perk_debug_grants_smoke`,
  `runtime_perk_choice_open_flow_smoke`,
  `runtime_perk_choice_apply_flow_smoke`,
  `runtime_perk_unlock_swap_flow_smoke`,
  `runtime_perk_snapshot_builder_smoke`,
  `runtime_perk_choice_finish_flow_smoke`,
  `runtime_perk_choice_confirm_flow_smoke`,
  `runtime_perk_owner_sync_flow_smoke`
- All `tests/stage_clear_result*_smoke.gd`: 77 total, all GREEN.
- All `tests/runtime_perk*_smoke.gd`: 57 total, all GREEN.
- `source_contract_function_body_smoke.gd`: GREEN.
- `.\tools\run_headless_load_check.ps1`: passed.
- `.\tools\run_warning_scan.ps1`: latest pass scanned 2298 scripts, no
  warnings.
- `git diff --check` for the scoped files: passed.

## Out Of Scope / Existing WIP To Ignore

The worktree is intentionally dirty. Do not treat these as part of this
nice-fix review slice:

- Staged deletion set for revival / speedgear / treasure-map assets, runtimes,
  and smokes.
- Unstaged treasure-removal / passive-to-perk WIP.
- `docs/character_skill_perk_checklist.md` already has an unrelated
  treasure-hunt removal hunk in the current worktree.
- `stage_clear_result_starpoint_choice_handler_smoke.gd` has an existing
  active mythic-choice tracking hunk in the current diff. This handoff's
  result-screen snapshot concern is the runtime-perk snapshot reader
  second-copy removal and its seal.
- Broad unrelated WIP under ball, active items, Lingpet, plasma, character-info
  overlay, stage-result files outside the listed scope, and stage renderer
  tracks.

## Review Questions

1. Does the character-context refactor preserve the intended Optimus owner
   behavior by routing flight/showcase through
   `get_normalized_owner_character_type()` and avoiding
   `get_owner_character_type()`?
2. Is moving flight/showcase registry access through
   `RuntimePerkRegistryLookup` behavior-preserving for null registry, empty
   keys, and registries without `get_instance`?
3. Is relying on `RuntimePerkState.get_snapshot()` as the only deep-copy
   boundary safe for the result-screen starpoint reward helper?
4. Is the idle fast-path predicate conservative enough, especially around
   pending choices, pending swap, flight/showcase landing, and starpoint
   absorption?
5. Are the new source-contract seals too stringly, or appropriate for this
   refactor checkpoint?
6. Do `RuntimePerkCallbackMap.call_acceptance()` and
   `call_strict_acceptance()` preserve the intended difference between
   optional callbacks that default dictionary payloads to accepted and
   debug/action callbacks that should fail closed unless the payload says so?
7. Are `RuntimePerkRuntimeStateAccess.call_dict/call_int/call_bool`
   appropriate as the shared boundary for source-object method calls, including
   the deep-copy default on dictionary results?
8. Is `RuntimePerkPayloadAccess` scoped narrowly enough, especially the
   distinction between live `as_dict/as_array` payload use and deep-copy
   `copy_dict/copy_array` snapshot boundaries?
9. Is the listed implementation/doc scoped set, plus this handoff doc, safe
   to hunk-split commit separately from the staged treasure / revival /
   speedgear deletion stream?
