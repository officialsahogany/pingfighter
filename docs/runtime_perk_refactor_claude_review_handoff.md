# Runtime Perk Refactor Claude Review Handoff

작성: 2026-07-09 02:42 KST

목적: 지금까지 Codex가 진행한 Godot `RuntimePerkState` 모듈 분리 작업을 Claude에게 리뷰 맡기기 위한 핸드오프다. 이 문서는 커밋 범위 문서가 아니라 리뷰 요청서다. 리뷰할 때는 현재 작업트리를 기준으로 보고, 특히 untracked `runtime_perk_*.gd` 파일까지 포함해야 한다.

## 리뷰 범위

리뷰 대상은 Godot 런타임 perk / starpoint choice 분리 작업이다.

- 핵심 파일: `godot/scripts/characters/runtime_perk_state.gd`
- 새 owner 모듈군: `godot/scripts/characters/runtime_perk_*.gd`
- 대응 smoke: `godot/tests/runtime_perk*_smoke.gd`
- 골드 parity 보강: `godot/tests/ingame_gold_reward_parity_smoke.gd`
- ownership 기록: `docs/godot_module_ownership_ledger.md`
- 상태 스냅샷 문서: `docs/refactor_status_brief.md`, `docs/current_development_boundary.md`

중요: 작업트리가 매우 더럽다. stage, ball, active item, Lingpet, plasma, hologram, stage-clear 등 다른 WIP가 섞여 있다. 리뷰는 runtime perk 분리 표면만 보되, `git diff`만 쓰면 untracked helper 파일을 놓친다. 반드시 `git status --short`로 `?? godot/scripts/characters/runtime_perk_*.gd`와 `?? godot/tests/runtime_perk*_smoke.gd`를 확인해야 한다.

## 현재 수치

- `runtime_perk_state.gd`: 868 lines, 143 top-level `func`
- `godot/scripts/characters/runtime_perk*.gd`: 47 modules
- `godot/tests/runtime_perk*_smoke.gd`: 53 smokes
- 전체 Godot scripts snapshot: `godot/scripts` 1349 `.gd`, `godot/tests` 922 `.gd`, smoke 920

## 리팩토링 의도

`runtime_perk_state.gd`를 완전히 없애는 작업은 아니다. 현재 의도는 다음과 같다.

- `RuntimePerkState`는 public wrapper, live fields, 기존 콜백 이름을 유지한다.
- 정책, payload construction, source-contract로 검증 가능한 결정 로직은 owner helper로 이동한다.
- helper는 가능하면 `*_from_runtime_state(self, ...)` facade를 제공해서 state wrapper가 세부 helper 객체나 live field 조합을 직접 넘기지 않게 한다.
- smoke는 동작 확인과 source-contract 확인을 같이 둔다. 즉, 단순히 pass만 보는 게 아니라 `RuntimePerkState`가 다시 inline policy를 되살리지 못하게 문자열 계약도 둔다.

## 주요 owner 분리면

이미 분리된 주요 책임은 다음 묶음이다.

- context / lookup: `runtime_perk_character_context.gd`, `runtime_perk_registry_lookup.gd`
- modal input / navigation: `runtime_perk_modal_input.gd`, `runtime_perk_gamepad_navigation.gd`
- choice modal: `runtime_perk_choice_opening.gd`, `choice_open_flow`, `choice_selection`, `choice_layout`, `choice_confirm_flow`, `choice_apply_flow`, `choice_finish_flow`, `choice_dispatch`, `choice_action_runner`, `choice_standard_path`, `choice_feedback`, `choice_audio`, `choice_offer_modifiers`, `choice_completion`
- unlock flows: `runtime_perk_active_unlock_flight.gd`, `runtime_perk_unlock_showcase.gd`, `runtime_perk_unlock_showcase_flow.gd`, `runtime_perk_unlock_swap_flow.gd`, `runtime_perk_unlock_swap_layout.gd`, `runtime_perk_unlock_choice_apply.gd`
- state lifecycle / owner sync: `runtime_perk_reset_state.gd`, `runtime_perk_owner_projection.gd`, `runtime_perk_owner_sync_flow.gd`, `runtime_perk_owner_effect_sync.gd`, `runtime_perk_resume_safety.gd`, `runtime_perk_skill_cooldown_pause.gd`
- reward / instant / dynamic: `runtime_perk_gold_awards.gd`, `runtime_perk_gold_award_flow.gd`, `runtime_perk_instant_rewards.gd`, `runtime_perk_instant_choice_flow.gd`, `runtime_perk_level_side_effects.gd`, `runtime_perk_lingpet_rewards.gd`, `runtime_perk_dynamic_effects.gd`
- stat/query: `runtime_perk_effective_levels.gd`, `runtime_perk_effective_stat_query_surface.gd`
- snapshot: `runtime_perk_snapshot_builder.gd`
- starpoint: `runtime_perk_starpoint_absorption.gd`, `runtime_perk_starpoint_collection_flow.gd`

## 최근 Codex가 더 민 부분

최근 이어서 작업한 작은 slices:

- `runtime_perk_unlock_showcase.gd`
  - `is_active_from_runtime_state()` 추가
  - `RuntimePerkState.is_unlock_showcase_active()`가 direct state dict 대신 facade 호출
- `runtime_perk_starpoint_absorption.gd`
  - `is_active_from_runtime_state()`
  - `start_from_runtime_state()`
  - `update_from_runtime_state()`
  - absorption projection용 flight-layout lookup도 helper 쪽으로 이동
- `runtime_perk_choice_layout.gd`
  - `rebuild_particles_from_runtime_state()` 추가
  - `RuntimePerkState._build_particles()`가 `build_particles + apply_particles_state_update`를 직접 조합하지 않음
- `runtime_perk_gold_award_flow.gd`
  - `calculate_rally_gold_from_runtime_state()` 추가
  - `RuntimePerkState.calculate_rally_gold()`가 pure calculator direct call 대신 facade 호출
  - `ingame_gold_reward_parity_smoke.gd`의 오래된 source-contract를 현재 flow-owner 구조에 맞게 갱신
- `runtime_perk_snapshot_builder.gd`
  - `build_from_runtime_state()` 추가
  - `RuntimePerkState.get_snapshot()`이 `_starpoint_absorption`, `_deferred_instants` helper를 직접 넘기지 않음

## Claude에게 요청할 리뷰 포인트

1. Facade 방향이 실제로 state wrapper를 얇게 만들고 있는지, 아니면 helper가 `runtime_state.get("_private_field")`에 과하게 의존하는 다른 형태의 결합을 만들고 있는지 봐달라.
2. `RuntimePerkState`가 public API / 기존 callback 이름을 지키면서도 정책을 helper로 넘긴 상태가 적절한지 확인해달라.
3. source-contract smoke가 너무 brittle하지 않은지 봐달라. 문자열 검사는 회귀 방지에 유용하지만, helper 이름 변경 같은 무해한 변경까지 막을 수 있다.
4. 골드 경로는 특히 확인이 필요하다. modifier order, Ignition Aura bonus, Gold Digger multiplier, Smasher combo, dash next-rally multiplier, skill-hit generic-rally suppression이 유지되는지 봐달라.
5. snapshot builder 변경을 확인해달라. `build_from_runtime_state()`가 `_starpoint_absorption`, `_deferred_instants`를 조회하는 방식이 안전한지, UI / overlay snapshot consumer를 깨지 않는지 봐달라.
6. unlock-style flows의 cancel / swap semantics가 state 분리 중 약해지지 않았는지 봐달라. 특히 slot-full swap, showcase, active unlock flight, delayed success callback 경로.
7. `RuntimePerkState`에 남은 compatibility wrappers를 유지할지 판단해달라:
   - `_get_catalog`
   - `_get_instance`
   - `_get_skill_config_key`
   - `_get_character_type`
   이 네 개는 아직 여러 helper callback이 쓰는 좁은 compatibility seam이다.
8. `docs/godot_module_ownership_ledger.md`가 실제 owner 책임과 맞는지, 과장되었거나 빠진 책임이 있는지 봐달라.

## 검증 결과

최신 상태 기준으로 Codex가 실행했고 통과한 검증:

```powershell
cd godot

.\tools\run_smoke_tests.ps1 -Tests @('res://tests/runtime_perk_snapshot_builder_smoke.gd')

$tests = Get-ChildItem -Path tests -Filter 'runtime_perk*_smoke.gd' |
  Sort-Object Name |
  ForEach-Object { 'res://tests/' + $_.Name }
"runtime_perk_smoke_count=$($tests.Count)"
.\tools\run_smoke_tests.ps1 -Tests $tests

.\tools\run_headless_load_check.ps1
.\tools\run_warning_scan.ps1
```

Observed:

- `runtime_perk_snapshot_builder_smoke`: passed
- full `runtime_perk*_smoke.gd`: 53 passed
- headless load check: passed
- warning scan: scanned 2285 scripts, no GDScript warnings

Earlier in the same pass after the gold facade change:

```powershell
.\tools\run_smoke_tests.ps1 -Tests @(
  'res://tests/ingame_gold_reward_parity_smoke.gd',
  'res://tests/runtime_perk_choice_action_runner_smoke.gd'
)
```

Observed:

- `ingame_gold_reward_parity_smoke`: passed
- `runtime_perk_choice_action_runner_smoke`: passed

## Suggested Review Commands

Use these from repo root unless noted:

```powershell
git status --short -- godot\scripts\characters godot\tests docs\godot_module_ownership_ledger.md docs\refactor_status_brief.md docs\current_development_boundary.md

rg -n "func get_snapshot|build_from_runtime_state|calculate_rally_gold_from_runtime_state|rebuild_particles_from_runtime_state|is_active_from_runtime_state|start_from_runtime_state|update_from_runtime_state" godot\scripts\characters godot\tests

git diff --check -- godot\scripts\characters\runtime_perk_state.gd godot\scripts\characters\runtime_perk_*.gd godot\tests\runtime_perk*_smoke.gd godot\tests\ingame_gold_reward_parity_smoke.gd docs\godot_module_ownership_ledger.md

rg -n "[ \t]+$" godot\scripts\characters\runtime_perk_state.gd godot\scripts\characters\runtime_perk_*.gd godot\tests\runtime_perk*_smoke.gd godot\tests\ingame_gold_reward_parity_smoke.gd docs\godot_module_ownership_ledger.md
```

Godot verification from `godot/`:

```powershell
$tests = Get-ChildItem -Path tests -Filter 'runtime_perk*_smoke.gd' |
  Sort-Object Name |
  ForEach-Object { 'res://tests/' + $_.Name }
.\tools\run_smoke_tests.ps1 -Tests $tests
.\tools\run_smoke_tests.ps1 -Tests @('res://tests/ingame_gold_reward_parity_smoke.gd')
.\tools\run_headless_load_check.ps1
.\tools\run_warning_scan.ps1
```

## Known Caveats

- This is not a clean branch. Many unrelated modified/untracked files exist.
- Many extracted `runtime_perk_*.gd` helpers are still untracked in git status. A normal `git diff` does not show their contents.
- The current refactor is not "complete"; it is a modularization checkpoint. `RuntimePerkState` still owns live fields and wrapper names by design.
- Source-contract tests are intentionally strict. If Claude recommends loosening them, keep at least one behavioral smoke per moved responsibility.
- `docs/runtime_perk_modularization_checkpoint_prep.md` is staging/commit guidance, not this review handoff. Use this document for review focus.

## Suggested Review Output Shape

Claude should return:

- Blockers: behavior regressions or broken ownership boundaries
- Risks: brittle tests, over-coupling, missing smoke coverage
- Nice-to-fix: naming/organization polish
- Keep-as-is: wrappers or facades that are intentionally compatibility seams
- Suggested next slice: one small, testable refactor step after this checkpoint
