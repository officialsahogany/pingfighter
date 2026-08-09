# 2026-08-10 리팩터링 체크포인트 커밋 격리 매니페스트

- 브랜치: `fix/plaza-lingpet-egg-full-roster-test`
- 리팩터링 격리 기준 HEAD: `cd60eee338806b60ec18be5af69161a425f80930`
- Pause 코드 체크포인트 HEAD: `418165578b631845766d550dc6bf4f415eb23b07`
- 작성 목적: 4,892-entry dirty worktree에서 2026-08-09 리팩터링 변경만 안전하게 격리
- 현재 상태: Pause 묶음 독립 커밋 완료. 나머지 세 도메인은 선재 WIP 의존 때문에 보류.
- 검증 인계서: `docs/refactor_session_2026_08_09_claude_review_handoff.md`

## 1. 완료 증거

- headless load: GREEN
- Stage 7 Python asset regression 13건: GREEN
- warning scan: 3,494 scripts, warning 0
- 세션 신규 owner seal: 22/22 GREEN
- 변경 owner 집중 묶음: 19/19 GREEN
- Pause Menu·Runtime Perk 묶음: 16/16 GREEN
- focused 176 전수: 163 PASS / 13 unrelated WIP FAIL
- 리팩터링 기인 회귀: 0건
- 전체 약 1,540개 suite: 미실행

## 2. 격리 원칙

1. `git add -A`, `git add .`, broad directory staging을 사용하지 않는다.
2. `git reset`, `checkout`, `restore`, `stash`, `clean`으로 working tree를 되돌리지 않는다.
3. 새 owner/owner seal은 아래 whole-file allowlist만 허용한다.
4. 기존 tracked facade, consumer smoke, 문서는 반드시 hunk 단위로 재구성한다.
5. staging에는 별도 `GIT_INDEX_FILE`을 사용하고 실제 index를 건드리지 않는다.
6. staged path set과 이 매니페스트를 비교하고, 차이가 하나라도 있으면 commit하지 않는다.
7. 현재 working tree의 GREEN을 staged tree GREEN으로 확대 해석하지 않는다. 격리 tree를 별도로 검증해야 한다.

## 3. Whole-file allowlist: 신규 owner 21개

아래 `.gd`와 같은 경로의 `.gd.uid`를 한 쌍으로 취급한다. 21개 모두 현재 untracked이며 대응 `.uid`가 존재한다.

### Pause Menu owner 9개

- `godot/scripts/hud/pause_menu_audio_controller.gd`
- `godot/scripts/hud/pause_menu_content_catalog.gd`
- `godot/scripts/hud/pause_menu_controls_settings_controller.gd`
- `godot/scripts/hud/pause_menu_display_settings_controller.gd`
- `godot/scripts/hud/pause_menu_input_command_router.gd`
- `godot/scripts/hud/pause_menu_language_settings_controller.gd`
- `godot/scripts/hud/pause_menu_options_renderer.gd`
- `godot/scripts/hud/pause_menu_pointer_command_router.gd`
- `godot/scripts/hud/pause_menu_selection_feedback_renderer.gd`

### Runtime Perk owner 3개

- `godot/scripts/characters/runtime_perk_fusion_runtime_state.gd`
- `godot/scripts/characters/runtime_perk_hyeonmun_charyeok_runtime_state.gd`
- `godot/scripts/characters/runtime_perk_physique_training_runtime_state.gd`

### Plaza owner 1개

- `godot/scripts/plaza/plaza_status_snapshot_builder.gd`

### Lingpet owner 8개

- `godot/scripts/lingpet/lingpet_acquisition_lifecycle_coordinator.gd`
- `godot/scripts/lingpet/lingpet_companion_motion_coordinator.gd`
- `godot/scripts/lingpet/lingpet_companion_player_runtime_resolver.gd`
- `godot/scripts/lingpet/lingpet_guardian_duration_lifecycle_coordinator.gd`
- `godot/scripts/lingpet/lingpet_guardian_enhance_flow_coordinator.gd`
- `godot/scripts/lingpet/lingpet_guardian_enhance_presentation_coordinator.gd`
- `godot/scripts/lingpet/lingpet_overflow_guardian_snapshot_builder.gd`
- `godot/scripts/lingpet/lingpet_rail_card_surface_builder.gd`

## 4. Whole-file allowlist: 신규 owner seal 22개

아래 `.gd`와 대응 `.gd.uid`를 함께 포함한다. 22/22 실행 GREEN이 확인됐다.

### Pause Menu 10개

- `godot/tests/pause_menu_audio_controller_owner_smoke.gd`
- `godot/tests/pause_menu_content_catalog_owner_smoke.gd`
- `godot/tests/pause_menu_controls_settings_controller_owner_smoke.gd`
- `godot/tests/pause_menu_display_settings_controller_owner_smoke.gd`
- `godot/tests/pause_menu_input_command_router_smoke.gd`
- `godot/tests/pause_menu_language_settings_controller_owner_smoke.gd`
- `godot/tests/pause_menu_options_renderer_owner_smoke.gd`
- `godot/tests/pause_menu_overlay_layout_owner_smoke.gd`
- `godot/tests/pause_menu_pointer_command_router_smoke.gd`
- `godot/tests/pause_menu_selection_feedback_renderer_owner_smoke.gd`

### Runtime Perk 3개

- `godot/tests/runtime_perk_fusion_runtime_state_refactor_smoke.gd`
- `godot/tests/runtime_perk_hyeonmun_charyeok_runtime_state_refactor_smoke.gd`
- `godot/tests/runtime_perk_physique_training_runtime_state_refactor_smoke.gd`

### Plaza 1개

- `godot/tests/plaza_status_snapshot_builder_owner_smoke.gd`

### Lingpet 8개

- `godot/tests/lingpet_acquisition_lifecycle_coordinator_owner_smoke.gd`
- `godot/tests/lingpet_companion_motion_coordinator_refactor_smoke.gd`
- `godot/tests/lingpet_companion_player_runtime_resolver_smoke.gd`
- `godot/tests/lingpet_guardian_duration_lifecycle_coordinator_owner_smoke.gd`
- `godot/tests/lingpet_guardian_enhance_flow_coordinator_owner_smoke.gd`
- `godot/tests/lingpet_guardian_enhance_presentation_coordinator_owner_smoke.gd`
- `godot/tests/lingpet_overflow_guardian_snapshot_builder_owner_smoke.gd`
- `godot/tests/lingpet_rail_card_surface_builder_owner_smoke.gd`

## 5. Tracked hunk-only allowlist

아래 파일은 세션이 실제로 편집했지만 HEAD diff 전체를 stage하면 안 된다. 세션 시작 전 WIP가 같은 파일에 존재하거나 HEAD 대비 diff가 세션 변화량보다 훨씬 크다.

### Facade와 기존 runtime surface

- `godot/scripts/hud/pause_menu_overlay.gd`
- `godot/scripts/characters/runtime_perk_state.gd`
- `godot/scripts/plaza/plaza_scene.gd`
- `godot/scripts/lingpet/lingpet_egg_runtime.gd`
- `godot/scripts/lingpet/lingpet_profile_runtime_surface.gd`

### 기존 consumer/integration smoke

- `godot/tests/guardian_enhance_cutin_lifecycle_smoke.gd`
- `godot/tests/guardian_enhance_cutin_visual_contract_smoke.gd`
- `godot/tests/lingpet_acquire_cutin_asset_prewarm_state_smoke.gd`
- `godot/tests/lingpet_acquire_cutin_overlay_host_resolver_smoke.gd`
- `godot/tests/lingpet_audio_dispatcher_smoke.gd`
- `godot/tests/lingpet_egg_runtime_smoke.gd`
- `godot/tests/lingpet_guardian_growth_single_source_smoke.gd`
- `godot/tests/lingpet_one_guardian_item_egg_smoke.gd`
- `godot/tests/lingpet_profile_runtime_surface_smoke.gd`
- `godot/tests/lingpet_rail_card_shared_smoke.gd`
- `godot/tests/lingpet_snapshot_sync_gating_smoke.gd`
- `godot/tests/pause_menu_display_settings_state_smoke.gd`
- `godot/tests/pause_menu_overlay_smoke.gd`
- `godot/tests/plaza_academy_menu_smoke.gd`
- `godot/tests/plaza_lingpet_store_menu_smoke.gd`
- `godot/tests/runtime_perk_fusion_modal_integration_smoke.gd`
- `godot/tests/runtime_perk_fusion_offer_integration_smoke.gd`

`guardian_enhance_cutin_visual_contract_smoke.gd`의 현재 HEAD diff는 이번 세션과 Claude 리뷰 수정으로만 구성된 것을 별도 확인했다. 그래도 tracked-file 원칙상 staged diff를 직접 재검토한다.

### Architecture/status 문서

- `docs/current_development_boundary.md`
- `docs/godot_module_ownership_ledger.md`
- `docs/godot_port_architecture.md`
- `docs/godot_runtime_traps.md`
- `docs/refactor_status_brief.md`

이 문서들은 HEAD 대비 수백~수천 줄의 다른 WIP가 섞여 있다. 이번 owner 항목, Plaza explicit-context 정정, fixture teardown 규칙, 최신 수치만 hunk-stage한다.

### CI/pre-push

- `.github/workflows/godot-ci.yml`
- `godot/tools/run_pre_push_checks.ps1`

세션 로그로 확정한 이 리팩터링의 목록 변화만 포함한다.

- Lingpet owner seal 6개: presentation, duration, enhance-flow, acquisition, motion, resolver
- Guardian visual contract 1개
- Pause Menu owner/router 10개
- Plaza owner 1개
- Runtime Perk owner 3개
- Lingpet overflow/rail owner 2개
- retired 존재하지 않는 두 경로를 활성 retirement seal 두 개로 1:1 교체
  - 제거: `runtime_perk_lingpet_ring_core_upgrade_smoke.gd`
  - 제거: `runtime_perk_lingpet_affinity_chip_smoke.gd`
  - 추가: `runtime_perk_choice_dispatch_smoke.gd`
  - 추가: `runtime_perk_choice_apply_flow_smoke.gd`

현재 HEAD 122 → working tree 176 사이의 다른 focused-list 변화는 이 체크포인트에 자동 포함하지 않는다.

## 6. 별도 baseline-stabilization 후보

다음 두 파일은 세션 초 warning scan을 복구했지만 domain owner 추출과는 별도다. 리팩터링 커밋에 섞지 않고 작은 선행 테스트 커밋 후보로 둔다.

- `godot/tests/guardian_spirit_rebrand_smoke.gd`와 대응 `.uid`
- `godot/tests/perk_conversion_values_smoke.gd`의 세션 소유 hunk만

## 7. 명시적 제외 목록

다음은 이번 리팩터링 체크포인트에 포함하지 않는다.

- `godot/tests/character_info_passive_ui_retire_smoke.gd`
  - 편액/active-item strip 별도 WIP의 불변식 재작성
- `godot/tests/settings_ui_neon_skin_smoke.gd`
  - 세션 중 편집됐지만 리팩터링 소유가 아님
- `LEGENDARY_ITEM_TEMPLATE.md`
  - 리팩터링과 무관한 줄바꿈 churn
- `godot/scripts/characters/runtime_perk_angel_blessing_runtime_state.gd`
- `godot/scripts/characters/runtime_perk_mystic_dice_runtime_state.gd`
- 대응 Angel Blessing/Mystic Dice refactor smoke와 `.uid`
- `godot/scripts/lingpet/lingpet_companion_draw_context_builder.gd`
- focused RED A/B/C 13건의 production/test WIP
- `.godot/`, 자동화 로그, capture, 임시 probe

## 8. 권장 커밋 시리즈

한 커밋에 네 domain과 문서를 모두 넣기보다 다음 순서를 권장한다.

1. `test(godot): repair refactor audit baseline smokes`
   - §6의 정확한 hunk만
2. `refactor(pause): extract pause menu policy and rendering owners` — 완료 (`418165578`)
   - Pause owner 9 + seal 10 + overlay/consumer hunk
3. `refactor(perk): extract physique, hyeonmun and fusion runtime owners`
   - Runtime Perk owner 3 + seal 3 + facade/integration hunk
4. `refactor(plaza): project status from an explicit live context`
   - Plaza owner/seal + facade hunk + teardown test hunk
5. `refactor(lingpet): extract snapshot, motion and guardian lifecycle owners`
   - Lingpet owner 8 + seal 8 + facade/surface/consumer hunk
6. `ci(godot): gate extracted refactor owners`
   - 두 focused 목록의 확정된 항목만
7. `docs(godot): record refactor ownership checkpoint`
   - ownership/status hunk + 두 신규 인계 문서

각 커밋은 앞 커밋 위에서 self-contained여야 한다. owner 파일만 먼저 commit해 facade에서 아직 사용하지 않는 dead code 상태를 만들지 않는다. 필요하면 domain별 owner/facade/test를 같은 커밋으로 묶고 baseline test 커밋만 선행한다.

## 9. Alternate-index 안전 절차

실제 명령 실행 전 exact patch를 만든 뒤 다음 절차를 사용한다.

```powershell
$checkpointIndex = Join-Path $env:TEMP 'bosspong-refactor-checkpoint.index'
$env:GIT_INDEX_FILE = $checkpointIndex
git read-tree HEAD

# whole-file allowlist와 검토 완료된 hunk patch만 index에 적용
# git add -- <explicit-new-file-list>
# git apply --cached -- <reviewed-domain-patch>

git diff --cached --name-status
git diff --cached --check
git diff --cached --stat
```

주의:

- 위 예시는 절차 문서이며 아직 실행하지 않았다.
- `$checkpointIndex`는 실제 실행 때 새 임시 경로를 사용한다.
- 실제 index와 working tree를 변경하지 않은 채 staged tree를 검토한다.
- staged path set이 allowlist와 정확히 같아야 한다.
- commit 전에는 staged tree 기반 isolated validation 방법을 별도로 확정한다.

## 10. 현재 판정

- whole-file 신규 경계: 확정
- Pause tracked 경계: 전체 diff가 세션 소유임을 로그 대조로 확인
- Runtime Perk·Plaza·Lingpet tracked 경계: provenance 확보, patch 재구성 필요
- 별도 WIP 제외: 확정
- 지금 즉시 broad commit 가능: 아니오
- 다음 작업: Pause 독립 커밋을 먼저 확정한 뒤 나머지 domain별 tracked hunk patch 재구성

## 11. 세션 패치 provenance 재대조

2026-08-10에 authoritative Codex session JSONL의 `apply_patch` 본문을 복원하고,
현재 `git diff -U0`의 추가·삭제 행과 파일별로 대조했다. 단순히 "세션이 파일을
건드렸다"는 수준이 아니라 현재 HEAD diff의 각 변경 행이 세션 패치의 실제
추가·삭제 행에 존재하는지 확인했다.

### Pause 결과

- `pause_menu_overlay.gd`: 현재 `+511/-1386`, 21개 diff hunk 전부 세션 패치로 설명됨
- 처음 미대조로 표시된 추가 2행·삭제 2행은 동일한 두 함수 선언이었다.
  Git이 주변 함수 이동을 삭제+추가로 정렬한 결과이며 내용 변화는 0이다.
- `pause_menu_display_settings_state_smoke.gd`: 1/1 hunk 설명됨
- `pause_menu_overlay_smoke.gd`: 2/2 hunk 설명됨
- 결론: 위 세 tracked 파일은 hunk 분리 없이 현재 파일 diff 전체를 Pause 묶음에 포함해도 된다.

### 다른 도메인 결과

- `lingpet_profile_runtime_surface.gd`와 다수의 작은 consumer smoke는 현재 diff 전체가
  세션 패치로 설명된다.
- `runtime_perk_state.gd`, `plaza_scene.gd`, `lingpet_egg_runtime.gd`는 세션 외 WIP 행이
  실제로 남아 있다. 특히 앞의 두 파일은 대부분의 hunk가 혼합되어 whole-file stage가 불가하다.
- CI/pre-push 두 목록과 대형 architecture/status 문서도 세션 외 항목이 같은 hunk에
  섞여 있으므로 현재 파일 전체를 포함하면 안 된다.
- 행 집합 대조는 경계 판정 자료이지 곧바로 patch 생성기가 아니다. 혼합 파일은
  self-contained dependency까지 확인한 수동 patch 재구성이 여전히 필요하다.

## 12. Pause 첫 커밋 후보 격리 검증

실제 `.git/index`를 건드리지 않고 임시 `GIT_INDEX_FILE`을 `HEAD`로 초기화한 뒤,
Pause 경로만 올려 검증했다.

- tracked 3개
  - `godot/scripts/hud/pause_menu_overlay.gd`
  - `godot/tests/pause_menu_display_settings_state_smoke.gd`
  - `godot/tests/pause_menu_overlay_smoke.gd`
- 신규 owner 9개 + 대응 UID 9개
- 신규 owner seal 10개 + 대응 UID 10개
- 합계: 41경로
- allowlist 밖 미추적 GDScript 의존성: 0
- staged 경로: 41/41, 누락 0, 초과 0
- `git diff --cached --check`: GREEN
- `git write-tree`: GREEN
- 검증 tree: `abb549854cd65c8584cb50743596379cea9c529c`
- 실제 `.git/index` SHA-256: 검증 전후 동일
- staged stat: 41 files, 3,555 insertions, 1,392 deletions

이 검증은 커밋 후보의 경로 격리와 정적 무결성을 증명한다. 런타임 측 증거는
최종 검증 라운드의 Pause 신규 seal 10/10 GREEN과 Pause Menu·Runtime Perk 묶음
16/16 GREEN이다. 다만 alternate-index tree 자체를 별도 checkout해 Godot를 다시
실행한 것은 아니므로, 실제 커밋 직전에는 동일 path set을 실제 index에 올린 뒤
staged diff를 재확인해야 한다.

### 현재 권고 순서

1. Pause 41경로를 첫 독립 커밋으로 확정한다.
2. Runtime Perk·Plaza·Lingpet는 현재 facade 전체를 stage하지 않는다.
3. 세 도메인은 HEAD 위에서 적용 가능한 최소 facade patch를 재구성하고 각각
   새 owner/owner seal과 dependency closure를 묶어 alternate-index 검증한다.
4. CI/pre-push와 문서는 네 도메인 커밋이 확정된 뒤 마지막에 exact hunk로 올린다.

## 13. 실제 Pause 커밋 결과

alternate-index 검증과 동일한 41경로만 실제 빈 index에 올려 다시 대조한 뒤
다음 커밋을 만들었다.

- commit: `418165578b631845766d550dc6bf4f415eb23b07`
- subject: `refactor(pause): extract pause menu policy and rendering owners`
- parent: `cd60eee338806b60ec18be5af69161a425f80930`
- commit path set: 41개
- allowlist 누락: 0
- allowlist 초과: 0
- `git diff --cached --check`: exit 0
- commit 후 staged path: 0
- commit 후 Pause 대상 working-tree dirty path: 0

커밋 직후 별도 Godot 재실행은 하지 않았다. 당시 repo-local Godot editor 1개와
별도 headless load 프로세스 2개가 이미 실행 중이어서 병렬 검증 충돌을 피했다.
런타임 근거는 커밋 직전과 내용이 같은 working tree에서 확보한 Pause 신규 seal
10/10 GREEN 및 Pause Menu·Runtime Perk 묶음 16/16 GREEN이다.

## 14. 나머지 도메인의 독립 커밋 blocker

세션 로그의 성공한 `apply_patch`를 역순 복원해 각 facade의 세션 시작 전 blob을
만들고, `base=세션 시작 전`, `ours=현재 HEAD`, `theirs=현재 working tree`로
3-way merge 가능성을 검사했다. working tree 파일은 이 과정에서 수정하지 않았다.

| facade | 성공 패치 역복원 | 세션 시작 전 = HEAD | HEAD 3-way 결과 |
|---|---:|---:|---:|
| `runtime_perk_state.gd` | 7 patches / 26 hunks | 아니오 | content conflict |
| `plaza_scene.gd` | 2 patches / 4 hunks | 아니오 | content conflict |
| `lingpet_egg_runtime.gd` | 42 patches / 115 hunks | 아니오 | content conflict |

Runtime Perk와 Lingpet 역복원에는 context가 없는 순수 삭제 hunk가 각각 3개 있어
완전 자동 역복원도 3곳씩 불가능했다. Plaza는 역복원 실패 0인데도 HEAD와의
3-way merge가 충돌했다. 따라서 세 도메인의 blocker는 단순 도구 문제가 아니라
세션 리팩터링이 이미 진행 중이던 facade WIP 위에서 작성됐다는 구조적 의존이다.

추가 dependency 확인:

- Runtime Perk 현재 facade는 HEAD에 없는 GDScript 9개를 preload한다. 이 중 이번
  owner 3개 외 6개는 choice/chosik/display/unlock 및 Angel Blessing/Mystic Dice
  별도 WIP다.
- Plaza 현재 facade는 이번 builder 외에도 HEAD에 없는
  `plaza_shop_transactions.gd`에 의존한다.
- Lingpet의 HEAD 밖 preload 8개는 이번 owner 8개로 닫히지만, 같은 facade 안의
  선재 WIP와 refactor delta가 충돌하므로 자동 독립 커밋은 불가하다.

결론: 다음 안전 단계는 세 도메인을 임의로 hunk-stage하는 것이 아니다. 각 선재
WIP owner가 먼저 자신의 기반 커밋을 확정하거나, 그 변경까지 명시적으로 같은
체크포인트 범위에 편입한다는 결정이 필요하다. 그 전까지 새 owner와 seal은
working tree에 보존하고 커밋하지 않는다.
