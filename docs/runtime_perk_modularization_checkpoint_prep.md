# runtime perk modularization checkpoint prep

작성일: 2026-07-08

목적: 현재 워킹트리에 쌓인 다중 WIP 중 `runtime_perk_state` 모듈화 계열을 먼저 체크포인트로 착지시키기 위한 파일 범위와 검증 세트를 고정한다. 이 체크포인트는 순수 모듈화만이 아니라, 같은 헝크에 이미 인터리브된 슬롯/링코어 재설계, P1 연마, 보유 슬롯 퍽 업글 우선순위까지 함께 포함하는 현실적인 checkpoint commit이다.

## 확정 전제

- 이 커밋은 "순수 A 모듈화"가 아니다.
- `runtime_perk_state.gd`와 `runtime_perk_catalog.gd`의 공유 헝크에 A/B/C/D가 섞여 있어 clean hunk split이 비현실적이다.
- 따라서 체크포인트 커밋 메시지는 순수 리팩터처럼 쓰지 않는다.
- P1 연마와 보유 슬롯 퍽 업글 우선순위는 이미 로직 PASS이므로 이 체크포인트에 흡수한다.
- 체크포인트 이후 clean하게 얹을 다음 작업은 `docs/mythic_perk_offer_chance_handoff.md`의 신화퍽 일반 오퍼 1% 배선이다.
- `runtime_perk_catalog.gd`가 참조하는 외부 lingpet API `get_run_ring_core_tier`는 HEAD에 이미 존재하므로 perk-only checkpoint는 로드 가능하다. 단, 링펫 동작 변경 전체를 커버하는 커밋은 아니다.

## Include

### Runtime perk core and extracted modules

```powershell
git add godot/scripts/characters/runtime_perk_*.gd
git add godot/scripts/characters/runtime_perk_*.gd.uid
```

존재하지 않는 `.uid`는 무시한다. Godot 전체 import를 일부러 돌려 사이드카를 생성하지 않는다.

### Runtime perk adjacent touched files

```powershell
git add godot/scripts/characters/mythic_perk_grant_helper.gd
git add godot/scripts/hud/runtime_perk_overlay_renderer.gd
git add godot/scripts/resources/gameplay_actor_module_catalog.gd
```

### Runtime perk and perk regression smokes

```powershell
git add godot/tests/runtime_perk_*_smoke.gd
git add godot/tests/runtime_perk_*_smoke.gd.uid
git add godot/tests/perk_*_smoke.gd
git add godot/tests/perk_*_smoke.gd.uid
```

`perk_*_smoke.gd` includes the already-interleaved perk conversion, slot-limit, polish-amplify, owned-upgrade priority, and dash-token slot overlay seals. In particular, `godot/tests/perk_overlay_dash_token_slot_cells_smoke.gd` is included as part of the slot/dash-token checkpoint surface.

### Boundary include

`godot/tests/soul_burst_dash_boost_free_dash_smoke.gd`는 파일명 글롭에는 걸리지 않지만 전환퍽 회귀 씰이므로 이 checkpoint에 포함한다.

```powershell
git add godot/tests/soul_burst_dash_boost_free_dash_smoke.gd
git add godot/tests/soul_burst_dash_boost_free_dash_smoke.gd.uid
```

`godot/tests/mythic_perk_offer_chance_smoke.gd`도 `mythic_` 접두라 `perk_*` 글롭에
걸리지 않지만, 봉인 대상(신화 1% 오퍼 카탈로그 배선)이 이 checkpoint에 흡수되므로
같이 포함한다. (`mythic_perk_acquisition_cinematic_smoke.gd`는 별도 트랙 — 리졸버/
시네마틱 파일과 함께 체크포인트 밖 자체 커밋.)

```powershell
git add godot/tests/mythic_perk_offer_chance_smoke.gd
git add godot/tests/mythic_perk_offer_chance_smoke.gd.uid
```

### Optional prep record

이 문서를 커밋 기록에 남기려면 포함한다.

```powershell
git add docs/runtime_perk_modularization_checkpoint_prep.md
```

## Exclude

다음은 다른 트랙 WIP로 유지한다.

- `ball_*`, `wall_bounce_*`
- stage3~6 renderer/state work
- non-perk `active_item_*`
- lingpet skill/egg/satiety/ring-core runtime work outside the checked runtime perk bridge
- audio/effects/plasma/hologram/air-blade/stage-clear sequential work
- general docs and handoff docs not needed for this checkpoint
- generated assets/import sidecars from unrelated tracks

Explicit untracked `.gd` excludes:

```text
godot/scripts/characters/smasher_plasma_fx_host.gd
godot/scripts/items/active_item_hologram_disk_runtime.gd
godot/scripts/core/battle_scene_api.gd
godot/tests/active_item_hologram_disk_smoke.gd
godot/tests/character_swap_texture_reload_smoke.gd
godot/tests/smasher_plasma_charge_size_speed_smoke.gd
godot/tests/smasher_plasma_fx_host_smoke.gd
godot/tests/smasher_plasma_visual_render_smoke.gd
godot/tests/stage_clear_result_sequential_box_open_smoke.gd
godot/tests/viper_air_blade_venom_edge_fallback_smoke.gd
```

`docs/passive_to_perk_*.md` handoff documents are excluded from the checkpoint commit. They are planning artifacts, not runtime code needed to stabilize this checkpoint.

## Verification Set

Run before commit:

```powershell
cd godot

$runtimePerkTests = @(
  'res://tests/runtime_perk_active_unlock_flight_smoke.gd',
  'res://tests/runtime_perk_character_context_smoke.gd',
  'res://tests/runtime_perk_choice_action_runner_smoke.gd',
  'res://tests/runtime_perk_choice_audio_smoke.gd',
  'res://tests/runtime_perk_choice_completion_smoke.gd',
  'res://tests/runtime_perk_choice_dispatch_smoke.gd',
  'res://tests/runtime_perk_choice_feedback_smoke.gd',
  'res://tests/runtime_perk_choice_layout_smoke.gd',
  'res://tests/runtime_perk_choice_offer_modifiers_smoke.gd',
  'res://tests/runtime_perk_choice_opening_smoke.gd',
  'res://tests/runtime_perk_choice_selection_smoke.gd',
  'res://tests/runtime_perk_choice_standard_path_smoke.gd',
  'res://tests/runtime_perk_debug_grants_smoke.gd',
  'res://tests/runtime_perk_deferred_instants_smoke.gd',
  'res://tests/runtime_perk_effective_stat_queries_smoke.gd',
  'res://tests/runtime_perk_gamepad_navigation_helper_smoke.gd',
  'res://tests/runtime_perk_instant_rewards_smoke.gd',
  'res://tests/runtime_perk_level_side_effects_smoke.gd',
  'res://tests/runtime_perk_owner_effect_sync_smoke.gd',
  'res://tests/runtime_perk_owner_projection_smoke.gd',
  'res://tests/runtime_perk_reset_state_smoke.gd',
  'res://tests/runtime_perk_resume_safety_release_smoke.gd',
  'res://tests/runtime_perk_snapshot_builder_smoke.gd',
  'res://tests/runtime_perk_starpoint_absorption_smoke.gd',
  'res://tests/runtime_perk_unlock_showcase_smoke.gd',
  'res://tests/runtime_perk_unlock_swap_flow_smoke.gd',
  'res://tests/runtime_perk_unlock_swap_layout_smoke.gd'
)

.\tools\run_smoke_tests.ps1 -Tests $runtimePerkTests
.\tools\run_smoke_tests.ps1 -Tests res://tests/runtime_perk_lingpet_ring_core_upgrade_smoke.gd,res://tests/runtime_perk_lingpet_affinity_chip_smoke.gd,res://tests/perk_slot_limit_smoke.gd,res://tests/perk_polish_amplify_smoke.gd,res://tests/perk_offer_owned_upgrade_priority_smoke.gd,res://tests/perk_overlay_dash_token_slot_cells_smoke.gd,res://tests/soul_burst_dash_boost_free_dash_smoke.gd,res://tests/mythic_perk_offer_chance_smoke.gd
.\tools\run_warning_scan.ps1
.\tools\run_headless_load_check.ps1
```

Known note: `perk_slot_limit_smoke` may print an ObjectDB leak warning under headless, while the smoke runner still passes. Treat runner exit status as authoritative unless a new failure line appears.

## Staging Audit

After staging, verify cached files do not include unrelated non-perk work:

```powershell
git diff --cached --name-only
git status --cached --short
```

Reject the staging set if it includes the explicit excludes above, unrelated stage/ball/active-item/lingpet-skill assets, or broad docs.

Suggested commit message:

```text
chore: runtime perk modularization checkpoint
```

If the message body is used, mention that the checkpoint includes the already-verified slot/ring-core, P1 polish, and owned-upgrade offer priority hooks because the shared hunks are intentionally landed together.
