# 수련 노드 카드 풀 수정 완료 보고서

- 작업일: 2026-08-21
- 기준 HEAD: `a8a5c8d45b1a4f32b79b7c1297d9afc005356496`
- 격리 워크트리: `D:\codex_tmp\bosspong_training_pool_fix_a8a5`
- 브랜치: `codex/training-node-card-pool-fix-a8a5`
- 통합/푸시: 하지 않음
- 게이트 차단: `0`

## 완료 결과

- 수련 노드의 생산 경로를 `training` 오퍼로 명시하고, 정확히 6장의 체질 수련 카드만 노출하도록 고쳤다. 무공·초식 카드는 수련 모달에 들어오지 않는다.
- 타락 승려 노드는 기존 계약인 초식 3장 + 무공 3장, 총 6장을 그대로 유지했다.
- 같은 빌더를 사용하던 전투 보상 선택은 `mixed_reward` 오퍼를 명시해 기존 체질 수련 3장 + 무공 3장 계약을 보존했다.
- 저장 데이터의 구형 혼합 수련 오퍼는 `offer_version`과 `offer_kind` 검증에서 탈락시켜, 다음 수련 노드 접근 시 현재 규칙으로 다시 생성한다.
- 수련 실행 경로도 `training_stat:` 액션과 체질 수련 배열만 받도록 닫아, 구형 `training_mugong:` 액션이 실행 경로로 되돌아오지 못하게 했다.
- 방문당 구매 횟수 제한은 다시 넣지 않았다. 무혼과 개별 수련의 저장 한도만 구매를 제한한다.
- 수련 모달 부제를 한국어 포함 7개 로케일에서 순수 체질 수련 문구로 고쳤다. 한국어 문구에는 긴 대시를 사용하지 않았다.
- 기획 문서를 v1.15로 갱신하고, v1.3의 수련장 무공 서가 설명을 폐기된 구식 규칙으로 명시했다.

## 후보 부족 정책

1. 잠금 해제된 비포화 체질 수련 후보를 먼저 가중 추첨한다.
2. 6장을 채우지 못하면 잠금 해제됐지만 저장 한도에 도달한 체질 수련 카드를 비활성 카드로 채운다.
3. 잠금 해제된 서로 다른 체질 수련 후보 자체가 6개 미만이면 중복·잠금 카드·무공으로 보충하지 않고 `insufficient_training_candidates`로 실패 폐쇄한다.

이 정책은 카드 6장 UI 계약을 유지하면서도 실제로 살 수 있는 수련을 우선하고, 카탈로그 구성 오류를 부분 오퍼로 숨기지 않는다.

## 변경 소유자와 씰

- 오퍼 소유자: `godot/scripts/tower_ascent/tower_ascent_training_offer_builder.gd`
- 생산 수련 모달/구매 경로: `godot/scripts/tower_ascent/tower_ascent_flow_economy_progress.gd`
- 보상 선택 호출자: `godot/scripts/tower_ascent/tower_reward_pick_offer_builder.gd`
- 모달 로컬라이제이션: `godot/scripts/tower_ascent/tower_ascent_node_modal_localization.gd`
- 수련 생산 경로 씰: `godot/tests/tower_ascent_training_node_smoke.gd`
- 타락 승려 부정 경로 씰: `godot/tests/tower_ascent_fallen_monk_node_smoke.gd`
- 혼합 보상 회귀 씰: `godot/tests/tower_reward_pick_smoke.gd`
- Vulkan 픽스처/계약: `godot/tools/tower_ascent_phase_c_node_visual_qa.gd`, `godot/tests/tower_ascent_phase_c_node_visual_qa_contract_smoke.gd`

수련 씰은 생산 플로우에서 카드 6장, 무공 0장, 전 카드 체질 수련, 3회 연속 구매와 저장 복원, 저장 한도 비활성화/거절, 무혼 부족 무변경, 후보 5개 실패 폐쇄, 7개 로케일 부제를 확인한다. 기존 타락 승려 씰은 3+3 총 6장을 계속 확인한다.

집중 프리푸시 목록과 CI 목록은 기존 수련/타락 승려 씰을 이미 포함하고 있어 새 파일 추가 없이 그대로 유지했다. 두 리터럴 목록은 `193 / 193`, 순서와 내용이 동일하다.

## 검증 증거

### 집중 스모크

커밋된 최종 코드에서 `-AllowDuringPlay`로 실행했다.

```text
Smoke summary: PASS=5 FAIL=0 TOTAL=5
All Godot smoke tests passed.
```

대상은 수련 노드, 타락 승려 노드, 혼합 보상 선택, Phase C 시각 계약, 노드 모달 셸이다. 기능 OFF와 잘못된 런타임 계약을 검증하는 의도된 경고만 있었고 `SCRIPT ERROR`는 0건이다.

추가로 `localization_coverage_smoke.gd`를 포함한 확장 배치는 범위 내 5개가 통과했으나, 기존 `pistol_enhance` 설명과 여러 아이템·런타임 특전·링펫 번역의 한국어 누출 기준선 때문에 해당 스모크 1개가 실패했다. 이번 변경의 수련 부제 7개 로케일 검증은 전용 생산 경로 씰에서 통과했으며, 이 기존 전역 번역 부채는 본 작업의 차단 요인이 아니다.

### 정적/로드 검증

- touched `.gd` 8개 `run_warning_scan.ps1 -Paths`: `No GDScript warnings found.`
- `run_headless_load_check.ps1`: 정상 종료 및 통과
- `git diff --check`: 통과
- 집중 목록 동기화: `PREPUSH=193 CI=193 SAME=True`

초기 격리 워크트리의 Godot import 캐시가 비어 있어 첫 스모크가 리소스 import 누락으로 실패했지만, 동일 기준 HEAD의 기존 캐시를 격리 워크트리에 복사한 뒤 위 최종 배치와 로드 검증이 통과했다. 코드 회귀가 아니며 최종 증거로 사용하지 않았다.

### Vulkan 캡처

`run_tower_ascent_phase_c_node_visual_qa.ps1`을 통해 Godot 4.6.2, Vulkan 1.4.325, Forward Mobile, NVIDIA GeForce RTX 5070에서 실행했다.

```text
captures=12
live_runs=1
tower_ascent_phase_c_node_visual_qa: ok
Tower Ascent Phase C node visual QA passed.
```

- `training.png`: 2020x1246, 수련 카드 6장, 무공/초식 없음. SHA-256 `3AACE4213689FB3B00842BCED9B6A3AF416DA4011E483D609E0D87566FF45C48`
- `training_three_purchases.png`: 2020x1246, 실제 생산 수련 경로 3회 구매 후 6장 유지, 선택 카드 `Lv.3`, 무혼 27. SHA-256 `876E1881EAB43BDE5644AED6C2FE60FB57DC20288B8DFFA4E3CB86605A419FF8`
- `fallen_monk.png`: 2020x1246, 초식 3장 + 무공 3장. SHA-256 `EF4452E11D10D6E5651AD463559489B9529DBD61625BADFE22E1DCE11F95111D`

캡처 디렉터리: `D:\codex_tmp\bosspong_training_pool_fix_a8a5\godot\.godot\codex_captures\tower_ascent_phase_c`

## 분리 커밋

1. `98a4c8d72e21019e6fb3be398aad9cdcae46584d` `fix(tower): keep training offers training-only`
2. `0d45ba89664f97732b294e371462ded13defdb99` `test(tower): refresh training node visual proof`
3. `dac147f1ce3c6c23ae5d472caa2f0e3b58bda4e3` `docs(tower): retire training Mugong bookshelf`

## 남은 확인 경계

- 사용자 본 트리 라이브 확인: **UNVERIFIED**
- 이유: 지시대로 격리 브랜치에서만 구현·검증했고 사용자 본 트리에 통합하지 않았다.
- 구현, 자동화 검증, 기획 문서 갱신에 남은 차단 항목: **0**
- 다음 동작: 통합 지시를 기다린다.
