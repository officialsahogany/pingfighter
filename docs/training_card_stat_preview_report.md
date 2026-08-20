# 수련 카드 능력치 증가 프리뷰 완료 보고

## 작업 기준

- 기준 본 트리 HEAD: `6c674ccb6`
- 격리 브랜치: `codex/tower-training-node-card-ui-40375`
- 작업 방식: 기존 온기 있는 격리 워크트리를 재사용했고, 본 트리에 통합하거나 푸시하지 않았다.

## S1 판정

### 적용 화면

| 화면 | 하단 능력치 띠 | 판정 |
|---|---:|---|
| 일반 무공·수련 선택 | 있음 | 프리뷰 적용 |
| 탑 보상 픽 | 있음 | 프리뷰 적용 |
| 수련장·파계승 노드 모달 | 없음 | 제외. 띠를 새로 붙이지 않음 |
| 시작 카드 | 사용자 확정으로 제거됨 | 제외. 하단 패널을 되살리지 않음 |

수련장·파계승 노드 모달은 `tower_ascent_flow_renderer.gd`의
`_draw_node_modal`이 카드 그리드와 잔액·상태 문구만 그리며 `_draw_stats_band`를
호출하지 않는다. 시작 카드 드로어도 능력치 띠 호출이 없고 시작 카드 상태가
`stats_rect`를 제거한다.

### 띠의 단위

`character_info_overlay_stats_presenter.gd`의 `_draw_stat_gauge_bar`는 좌우 끝점
사이를 `lerpf`로 보간해 채우는 **연속 막대**다. 끝 장식은 있지만 이산 칸은 없다.
따라서 기존 띠를 이산화하지 않고, 현재 채움 끝점부터 한 단계 적용 뒤 끝점까지의
연속 증가 구간만 겹쳐서 나타났다 사라지게 한다.

### 수납술·조식심법 판정

- 수납술은 `source_perk_id`가 비어 있지만 실제 슬롯 증가는
  `runtime_perk_effective_stat_query_surface.gd`의
  `get_active_item_slot_capacity`가 `active_item_slot_bonus`를 읽는 별도 경로로
  존재한다. 다만 슬롯 행은 `simple_stat_row`라 연속 막대가 없으므로 이번
  증가 구간 프리뷰 대상에서 제외한다.
- 조식심법은 `source_perk_id=common_training`이며 실제 초식 쿨타임 소비 경로도
  존재한다. 그러나 현재 10행 능력치 띠에는 초식 쿨타임 행이 없다. 지시문의
  “프리뷰 계층만 추가” 및 띠 대개조 금지 범위에 따라 시각 프리뷰에서는 제외한다.
- 나머지 9종은 기존 연속 막대 행에 대응하므로 적용 대상이다.

### 증가량·시계 판정

- 다음 한 단계의 상태는 실제 수련 적용이 쓰는 `PhysiqueTrainingState.commit`을
  격리된 투영 상태에 그대로 호출해 만든다. 별도 증가 수식을 만들지 않는다.
- 투영 상태는 실제 능력치 소비 경로와 기존 능력치 행 조립기를 다시 통과한다.
  따라서 수련 숙련 배수와 Lv.5 초과 유효 레벨도 동일 경로에서 반영한다.
- 카드 모달은 물리 진행이 멈출 수 있으므로 깜빡임은 렌더러가 이미 쓰는
  `Time.get_ticks_msec()` 벽시계를 사용한다. 연출 난수는 사용하지 않는다.

## 구현 및 검증

### S2. 실제 적용 경로를 재사용한 투영

- `runtime_perk_training_stat_preview.gd`가 프리뷰 가능한 수련 9종을 기존 능력치
  행에 대응시킨다. 현재 행과 투영 행은 모두
  `CharacterInfoOverlayStatsPresenter.build_player_stat_rows`로 조립한다.
- `runtime_perk_physique_training_runtime_state.gd`는 실 상태의 스냅샷을 새
  `PhysiqueTrainingState`에 복원한 뒤, 실제 적용과 같은
  `PhysiqueTrainingState.commit`을 한 번 호출한다. 투영 중에는 기존 보너스 조회
  경계를 잠깐 재사용하고 즉시 복구하므로 실 수련 상태와 오너 게이지를 바꾸지 않는다.
- 태허심법의 최대 게이지는 실제 동기화 함수와 프리뷰가 모두
  `MythicItemOwnerSyncer.build_fuel_pouch_gauge_projection`을 사용한다. 프리뷰
  전용 최대 게이지 수식은 없다.

### S3. 깜빡임과 캐시

- 일반 선택 화면과 탑 보상 픽 화면이 같은 오버레이 렌더러에서 카드 실 rect와
  선택지를 능력치 띠에 전달한다. 포인터가 가리키는 유효 수련 카드만 현재 끝점과
  투영 끝점 사이의 청록 구간을 그린다.
- 주기는 800ms, 표시 구간은 앞 400ms다. 벽시계만 사용하며 게임플레이 RNG를
  소비하지 않는다.
- 투영 모델은 선택지·수련 상태 서명으로 캐시한다. 호버가 없으면 투영 빌드가
  0회이고, 깜빡임 프레임마다 다시 계산하지 않으며, 호버 해제 즉시 빈 모델로
  복귀한다.
- 시작 카드와 수련장·파계승 노드 모달에는 능력치 띠나 프리뷰 호출을 추가하지
  않았다.

### S4. 씰

`training_card_stat_preview_smoke.gd`가 다음을 고정한다.

- 대상 9종 각각에서 프리뷰를 먼저 계산하고 실제 `apply_choice`를 한 번 수행한 뒤,
  투영 행의 표시값과 연속 채움 비율이 실제 적용 뒤 행과 일치한다.
- 수련 숙련 유효 Lv.7(기본 Lv.5 + 보너스 Lv.2)의 2.4배 경로를 사용한다.
- 프리뷰 계산 전후 실 수련 스냅샷과 오너 게이지 폭·최대치가 변하지 않는다.
- 자세 능력치가 생산 경로의 100% 클램프에 도달하면 증가 구간을 내지 않는다.
  이것은 수련 횟수의 유한 상한이 아니다. 체질 수련의 기존 `max_count=-1`
  무제한 누적 계약은 그대로다.
- 무호버 0회 빌드, 호버 1회 빌드, 반복 깜빡임 캐시 재사용, 호버 해제 즉시 복귀,
  100/500/900ms 표시·숨김·반복을 각각 확인한다.
- 일반 선택과 탑 보상 픽의 실제 카드 rect 배선, 시작 카드와 노드 모달의 비배선,
  연속 `lerpf` 게이지, 비난수 증가 구간 드로우를 소스 계약으로 확인한다.

## 렌더 증거

- 실제 일반 선택 오버레이를 사용한 Vulkan Forward Mobile, 2020x1246,
  NVIDIA GeForce RTX 5070 캡처를 수행했다.
- 무호버, 호버-숨김, 호버-표시, 100% 포화 호버와 표시/숨김 병합 스트립을
  저장했다. 표시와 숨김의 증가 구간 변경 픽셀은 276개다.
- 무호버와 호버-숨김의 전체 이미지 SHA-256이 모두
  `C8BBE3C7DDFF7C13625A36BCAB12A94789416D13E65158F4CCDF8BDAB6F201F9`로
  같고, 포화 카드의 능력치 띠 비교 변경 픽셀은 0개다.
- 병합 스트립 SHA-256:
  `F23510E2662A9826D5A4C775FCB8E49C4EFB3D9B00248AC7B8DC13BC9C9871E0`.
- 증거 디렉터리:
  `godot/.godot/codex_artifacts/training_card_stat_preview/`.

격리 워크트리의 운영 렌더러·Vulkan 픽셀 경로까지는 검증했다. 사용자가 전진한
본 트리에서 직접 마우스를 움직여 보는 라이브 체감 확인은 지시대로 **unverified**로
남긴다.

## 검증 결과

- 핵심 묶음 5개: `PASS=5 FAIL=0 TOTAL=5`,
  `All Godot smoke tests passed.`
  - 신규 프리뷰 씰
  - 기존 일반 능력치 띠 씰
  - 탑 보상 픽 씰
  - 시작 카드 비회귀 씰
  - `variant_boss_ball_path_snapshot_smoke`
- 변경 GDScript 8개 집중 경고 스캔: 경고 0건.
- 헤드리스 로드: `Godot headless load check passed.`
- CI/pre-push 집중 목록: 양쪽 모두 190개이며 신규 씰과 변형 보스 씰을 함께
  유지한다.
- 전체 `full` 게이트는 범위 밖 기준선 RED로 중단됐다. 첫 누락 리소스는 여러
  웜 워크트리와 SHA-256이 같은 캐시를, 두 번째는 현재 소스 MD5와 기존 import
  메타데이터의 목적 MD5가 모두 맞는 캐시를 격리 `.godot`에만 보충했다. 이후
  기존 테스트의 구형 호출·제거된 오디오 상수 등에서 전체 경고 스캔이 실패했다.
- 경고 스캔을 제외하고 190개를 끝까지 실행한 `light` 게이트 결과는
  `PASS=168 FAIL=22 TOTAL=190`이다. 실패 22개는 통계 출처의 구형 인자 수,
  누락된 asset sidecar, 기존 perk offer·mythic reveal·링펫·벽도약 등의 범위 밖
  기준선이며 신규 프리뷰 씰과 변형 보스 씰은 GREEN이다.
- 작업 범위 blocked: 0건. 본 트리 라이브 체감 unverified: 1건.

로그는 같은 증거 디렉터리의 `focused_smokes.log`,
`focused_warning_scan.log`, `headless_load_check.log`,
`training_card_stat_preview_visual_qa.log`에 보존했다.

## 커밋

1. `3eb00551a` `docs(tower): decide training stat preview scope`
2. `644d09b72` `feat(tower): project training card stat gains`
3. `d08f09e7c` `feat(tower): blink projected training stat segment`

S4 씰·Vulkan 도구·본 보고서는 이 보고서가 포함된 마지막 커밋으로 닫는다.
통합과 푸시는 하지 않고 보고 뒤 대기한다.
