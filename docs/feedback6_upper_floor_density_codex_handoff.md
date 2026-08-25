# 지시문 T3 — 2층 이상 노드 밀도 복원 (A안: 층당 3행 7노드)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `e1c6c886d`. CI/pre-push 락스텝 237.
- **격리 워크트리**: `D:\codex_tmp\bosspong_floordensity_e1c6` (브랜치
  `codex/fb6-upper-floor-density-20260825`).
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기.
- ⚠**동시 진행 트랙 충돌**: 별도 세션의 Q3-수정2 커밋(`77cd82acd`)이
  `tower_ascent_flow_*` 7파일과 `tower_ascent_boss_registry.gd`를 만졌고
  통합 대기 중이다. **이 트랙은 `tower_ascent_map_generator.gd`와
  `tower_ascent_tuning.gd`, 그리고 지목된 씰만** 건드려라. flow 계열과
  boss_registry는 손대지 마라.

## 사용자 관측과 확정된 사양

> 1층만 노드가 풍성하고 2·3층을 포함한 나머지 층은 굉장히 짧고 단순하고
> 노드가 빈약함. 1층처럼 풍성하게 해야 함.

관제탑이 실측치를 제시하고 **사용자가 A안을 확정**했다.

| | 현재 | A안(확정) |
| --- | --- | --- |
| 2~8층 행 | 2 | **3** |
| 2~8층 노드 | 3 | **7** |
| 2~8층 레인 | 1 → 2 | **1 → 2 → 4** |
| 지도 총계 | 43노드 27행 | **약 71노드 34행** |
| 런 길이(지나는 행) | 27 | **34 (+26%)** |

**1층은 그대로 둔다.** 9~12층도 이번 스코프 밖이다.

## 실측 (관제탑 프로브 + 독립 반증, 둘 다 헤드리스 200시드 이상)

- 층 번호는 **1-기반 `segment_floor`**이고, 플레이어가 읽는 "N층" 문구가
  실제로 여기서 나온다(`tower_ascent_flow_map_progress.gd:608~610` →
  `tower_ascent_floor_title_catalog.gd:31~32`). 오프바이원 없다.
- **행·노드 수는 시드 완전 무관**(독립 3표본 664시드에서 min==max).
  `_choose_route_lane_count`(`:1448~1458`)와
  `_choose_gatekeeper_lane_count`(`:1461~1471`)가 `_rng`를 아예 쓰지 않는다.
  시드에 따라 변하는 것은 노드 **종류**뿐이다.
- **원인은 세 규칙의 곱**이다.
  1. `_choose_gatekeeper_lane_count`가 **무조건 `return 1`**(`:1471`).
  2. `_choose_route_lane_count`가 `previous_lane_count <= 1`이면
     `ROUTE_CANDIDATE_COUNT`(=2, `:24`)를 반환(`:1456~1457`).
  3. `TowerAscentTuning.TEMP_OPTIONAL_ROWS_PER_FLOOR = 1`
     (`tower_ascent_tuning.gd:28`, 소비 `generator:146`).
  → 폭이 1 → 2 → 1 → 2로만 진동하고 `MAP_LANE_COUNT_MAX = 4`(`:26`)는
  2층 이상에서 **구조적으로 도달 불가**다. 사이 행의 상한 자체는 자유롭다
  (`:1458`이 prev×2를 4까지 허용). 진짜 구속은 **행 예산 1**이다.
- 이 상태를 만든 것은 `f83d231b8`("층 관문을 단일 레인 보스 초크포인트로",
  피드백2 8항, 지도 개편 S9)이다. 지도 총계 74 → 43노드, 2~8층 각 7 → 3.
  **의도 자체는 타당했다** — 그 전에는 멀티레인 관문에서 NPC 레인으로
  빠져나가 층 보스를 통째로 건너뛸 수 있어 층당 보스 보장이 0이었다.
  이번 작업은 **그 보장을 유지하면서** 행 예산만 되돌리는 것이다.
- **화면 공간은 제약이 아니다**(확인 완료). 전체화면 지도는 고정 피치
  (`MAP_SCROLL_ROW_PITCH = 160.0 × map_scale`,
  `tower_ascent_flow_renderer.gd:134`, `:935`)로 배치하고 world_rect를 실제
  행 수에서 유도한다(`:977~986`). 밴드 rect도 행이 늘면 늘어나도록 설계돼
  있다(`:1163~1186`). 행이 늘면 스크롤 월드가 길어지고 fit-all 줌 하한이
  내려갈 뿐 뷰포트를 넘치지 않는다. `TEMP_MAP_PATH_DRAW_CALL_BUDGET`
  (`tuning:163`)은 경로 점 전용이고 렌더러가 4회까지 간격을 벌려 대응한다.
- **보스 밀도 레일도 막지 않는다.** `TEMP_GENERATED_BOSS_NODE_MAX_RATIO
  = 0.38`, `TEMP_GENERATED_NPC_PER_BOSS_MIN = 1.65`(`tuning:32~33`)는
  방향이 반대다 — NPC를 늘리면 비율이 내려가고
  `_generated_boss_budget = floor(generated_node_count × 0.38)`
  (`boss_registry:780~805`)이 오히려 커진다. 현재 평균 0.3377(상한 0.38).

## 작업

1. **행 예산 확장**: `tower_ascent_tuning.gd:28`
   `TEMP_OPTIONAL_ROWS_PER_FLOOR := 1` → `2`.
   이것이 A안의 본체다. 관문은 계속 1레인이므로 폭이 1 → 2 → 4 → 1로
   돌아 층당 7노드가 된다.
2. **총 행 수 공식 동기화**: `generator:55~64`의
   `total_rows = 1 + (12-1) × (TEMP_OPTIONAL_ROWS_PER_FLOOR + 1) +
   FLOOR_ONE_EXPANSION_ROW_ROLES.size()`가 상수에서 파생되는지 확인하라.
   리터럴이 박혀 있으면 파생으로 바꿔라(GRT-054: 상수를 올렸는데 파생
   임계값이 리터럴이면 조용히 어긋난다).
3. **1층 무회귀**: `FLOOR_ONE_EXPANSION_ROW_ROLES`(`:37~42`)와
   `if floor_number == 2 and not audition_enabled:` 분기(`:91~145`)는
   건드리지 마라. 1층은 6행 13노드를 그대로 유지해야 한다.
   `MAP_LANE_COUNT_MIN = 3`(`:25`)의 소비자는 저장소 전체에서
   `generator:108`·`:162` 두 곳뿐이고 둘 다 1층 확장 분기 안이다.
4. **초크포인트 계약 유지**: 관문 행은 계속 1레인이어야 한다
   (`_choose_gatekeeper_lane_count`를 건드리지 마라). 층당 보스 보장이
   깨지지 않음을 씰로 증명하라.
5. **보스 간격 계약 확인**: `_count_boss_spacing_violations`(`:956~1004`)는
   두 보스 행 사이에 **완전한 생성 NPC 행**을 요구한다. 행이 하나 늘어도
   이 계약이 계속 성립하는지 확인하라. 4레인 행이 생기면
   `_is_full_generated_npc_row`(`:987~1004`)의 "optional_extra_boss 1명까지
   허용" 우회 규칙과의 상호작용도 함께 볼 것.
6. **검증기 전수 통과**: `_analyze_phase_integrity`의
   forbidden_singleton_row(`:745~759` + `_is_allowed_singleton_row`
   `:939~953`), singleton_previous/next_row_too_narrow(`:762~783`),
   consecutive_single_transition(`:818~838`), 교차 간선 0
   (`_count_crossing_edges` `:1086~1106`), degree_two_ratio ≥ 0.70
   (`tuning:34`, 검사 `:861~866`), 진입행/터미널행 계약(`:731~744`)이
   전부 통과해야 한다. `GENERATION_MAX_ATTEMPTS = 8`(`:27`) 안에 들어야
   하므로 **재시도 횟수 분포도 측정해 보고**하라.
7. ⚠**보스 콘텐츠는 늘리지 마라.** 4~8층은 보스 슬롯 2개가 같은 보스로
   접혀(`tuning:213~233` × `canonical_encounter_key` `boss_registry:171~178`)
   추가 보스가 구조적으로 불가능하다(458회 굴림 전부
   `unique_pool_exhausted`). 이번 A안은 **NPC 노드로 폭을 넓히는 것**이며,
   그 자체가 보스 예산을 키워 부작용이 없다. 4~8층 보스 변형 추가는
   별건으로 보류됐다.

## 씰

⚠**GRT-035**: 공유 씰 목록에 항목을 삽입하면 형제 절대-인덱스 씰이
깨진다. 씰 목록을 건드릴 경우 CI(`.github/workflows/godot-ci.yml`)와
pre-push(`godot/tools/run_pre_push_checks.ps1`) **양쪽을 락스텝**으로
갱신하고, 형제 인덱스 단언을 재확인하라.

절대 수치를 단언하는 기존 씰 5종이 전부 갱신 대상이다.

- `tests/tower_ascent_12_floor_map_smoke.gd`
- `tests/tower_ascent_floor_one_expansion_contract_smoke.gd`
  (**1층 단언은 변하지 않아야 한다** — 변한다면 3번을 어긴 것이다)
- `tests/tower_ascent_map_topology_smoke.gd`
- `tests/tower_optional_extra_boss_distribution_smoke.gd`
- `tests/tower_boss_routing_smoke.gd`

추가할 레그:

- **밀도 레그(핵심)**: 200시드 이상에서 층별 행/노드가
  1층 6행 13노드, **2~8층 각 3행 7노드**, 9층 1행 1노드로 고정
  (min == max)임을 단언.
- **레인 시그니처 레그**: 2~8층 레인이 `[1, 2, 4]`(진행 방향 기준)임을
  단언. 4레인이 실제로 나오는지가 A안의 성패다.
- **도달성·보장 레그**: 전 시드에서 입구 → 터미널 도달 가능, 층당 보스
  조우 보장 1 이상, 관문 우회 경로 0.
- **생성 실패 0 레그**: 200시드에서 `generate_tower`가 빈 dict를 반환하지
  않을 것. 재시도 횟수 분포도 함께 기록.
- **RED 반증**: `TEMP_OPTIONAL_ROWS_PER_FLOOR`를 1로 되돌린 픽스처에서
  밀도·레인 시그니처 단언이 실패할 것.
- **1층 무회귀 반증**: 1층 노드/행/선택 보스 2개가 변하지 않음을 단언.
- **픽셀 QA**: 전체화면 지도 캡처 1장. 2·3층 밴드에 4갈래 경로행이
  실제로 보이고, 화면 밖으로 잘리지 않아야 한다.

⚠**오디션 구성 확인**: `export_presets.cfg:42~48`의 Windows Desktop
프리셋이 `custom_features="tower_audition"`을 켜고 있어 내보낸 빌드는
다른 지도(7층)를 쓴다. 이 구성에서도 **생성 실패율이 현재보다 나빠지지
않는지**만 측정해 보고하라. (현재 오디션 구성에 16.5% 생성 실패가 이미
있는 것은 **별건으로 보류**된 사안이니 이번 트랙에서 고치려 하지 마라.)

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처. 보고=워크트리·커밋 해시·씰 종단선 원문·
층별 실측표(행/노드/레인, 200시드 min·max)·재시도 횟수 분포·
오디션 구성 실패율 전후 비교·캡처 경로·미해결.
