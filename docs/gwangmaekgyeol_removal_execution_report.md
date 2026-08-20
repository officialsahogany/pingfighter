# 광맥결 삭제 + 기맥 확장 부산물 이전 실행 보고

- 기준 HEAD: `7805939301ed77d1583cbcb986b21756ed21a822`
- 격리 워크트리: `D:\main\bosspong_r4_s5_stageproof`
- 작업 브랜치: `codex/gwangmaekgyeol-removal-20260820`
- 정본: `docs/perk_slot_expansion_to_fusion_byproduct_handoff.md` 통독 완료
- 통합/푸시: 하지 않음

## S1. flag ON 노출 경로 전수 조사

`common_expansion`, `광맥결`, `expansion`을 코드·테스트·`tscn`·`tres`·다국어
카탈로그에 교차 검색했다. 기준 HEAD에는 정본 S3~S5 배선이 이미 존재하지만,
`get_all_perk_data()`를 직접 소비하는 뒤늦은 탑 후보 경로가 일반 오퍼 필터를
우회한다.

| 표면 | 생산 후보 소스 | 기준 HEAD 판정 | S2 작업 |
|---|---|---|---|
| 일반 무공 오퍼 | `runtime_perk_catalog.gd:1812-1827` `_append_pool_choices` | flag ON이면 `:1816-1817`에서 차단 | 유지·부정 레그 |
| 탑 시작 카드 3장 | `tower_start_card_offer_builder.gd:23-76`이 `get_all_perk_data()` 후 `TowerAscentPerkCandidatePolicy` 사용 | 정책에 retired flag-ON id 차단이 없어 **도달 가능** | 중앙 정책에서 차단 |
| 탑 타락승려 카드 | `tower_ascent_fallen_monk_node.gd:262-302`가 같은 중앙 정책 사용 | 시작 카드와 같은 이유로 **도달 가능** | 같은 수정으로 동시 차단 |
| 탑 보상 픽 일반 무공 | `tower_reward_pick_offer_builder.gd:204-229` -> `tower_ascent_training_offer_builder.gd:98-136` -> `runtime_perk_catalog.get_choices()` | 일반 오퍼 차단을 관통하므로 도달 불가 | 명시 씰 추가 |
| 탑 보상 픽 절세 무공 | `tower_reward_pick_offer_builder.gd:149-201`의 `CONVERTED_MYTHIC_PERKS` 전용 풀 | `common_expansion`이 해당 풀에 없어 도달 불가 | 형제 무손상 씰 |
| 디버그 부여 | `runtime_perk_catalog.gd:2055-2072` | flag ON이면 `:2062-2063`에서 차단, flag OFF는 보존 | 유지·부정 레그 |
| 슬롯 한도 | `runtime_perk_catalog.gd:1708-1745` | `meridian_expand` 보유 부산물만 +1, 최대 7. `common_expansion` 레벨은 미사용 | S4 검증 |
| 슬롯 비소모 예외 | `runtime_perk_catalog.gd:1642-1660` | `common_expansion` 전용 예외 없음 | 유지·부정 레그 |
| 복원 | `runtime_perk_state.gd:292-299` | flag ON 직접 복원 호출에서 키 제거. 현재 프로덕션 호출자 0건인 미래 계약 | S5 검증, 라이브 자가 치유 주장 금지 |
| 도감·툴팁·아이콘 | 카탈로그/로케일/아이콘 엔트리는 flag OFF 호환을 위해 남음 | flag ON 신규 획득이 막히면 런타임 보유 기반 UI에는 도달하지 않음 | 에셋·레거시 정의 보존 |

결함의 최소 소유자는 `tower_ascent_perk_candidate_policy.gd`다. 시작 카드와
타락승려가 이 정책을 공유한다. 보상 픽은 다른 후보 소스이므로 별도 실행 씰로
도달 0을 단언한다.

## 기준 HEAD에 이미 존재하는 정본 배선

- `meridian_expand`: general 풀, `runtime_enabled=true`, flag OFF 제외, 전역 중복 제외.
- 슬롯 한도: 기본 6, 최대 7, registry/state 양쪽 `slot_context` 전파.
- flag ON 일반 오퍼·디버그 차단과 비소모 예외 제거.
- 7개 로케일과 미래 복원 방어 훅.

이 항목들은 새 구현으로 가장하지 않고 각 해당 슬라이스에서 생산 씰과
반증검증을 재실행한다.

## 슬라이스 상태

### S1 검증 메모

- 기준 HEAD의 집중 스모크 컴파일을 막던 `perk_fusion_cold_boot_cinematic.gd`의 `WritheEmberMaterial` 누락 preload를 생산 소유자에서 명시적으로 보수했다.
- 집중 스모크: `perk_slot_limit_smoke.gd`, `perk_fusion_byproduct_catalog_smoke.gd`, `tower_start_card_smoke.gd`, `tower_reward_pick_smoke.gd` 모두 PASS, 래퍼 종단선 `All Godot smoke tests passed.` 확인.
- 집중 경고 스캔: 보수 파일 1개, GDScript warning 0.
- 전체 headless load는 두 작업 격리 워크트리에 공통인 LFS 포인터/누락 import cache 때문에 실패했다. 첫 오류는 `loading_cameo_dalji_hoop_roll_16f_autosprite_v1.png`가 PNG 대신 LFS 포인터라는 기준 환경 결함이며 S1 변경과 무관하다. 이를 GREEN으로 세탁하지 않고 최종 공통 게이트에서 별도 추적한다.

### S2 flag ON 노출 차단 검증

- `tower_start_card_offer_builder.gd`와 `tower_ascent_fallen_monk_node.gd`가 공유하는 `tower_ascent_perk_candidate_policy.gd`에서 flag ON일 때만 `common_expansion`을 거부한다. flag OFF 레거시 정의와 카탈로그 backing data는 그대로 유지했다.
- 다른 후보 소스를 쓰는 탑 보상 일반 무공은 `tower_ascent_training_offer_builder.gd`에서도 같은 중앙 정책을 통과시켜 방어를 중복 봉인했다.
- `tower_start_card_smoke`는 flag ON 픽스처에 `common_expansion`을 넣어도 3장 모두에서 빠지는 정방향과, flag OFF에서는 3번째 레거시 카드로 계속 나오는 부정 레그를 함께 통과했다.
- `tower_reward_pick_smoke`는 실제 탑 훈련 오퍼가 `common_expansion` 없이 3개 적격 무공을 유지함을 통과했다. 두 씰은 PASS=2, FAIL=0, 종단선 `All Godot smoke tests passed.`였다.

### S3 검증과 반증

- `perk_fusion_byproduct_catalog_smoke`, `perk_fusion_result_builder_smoke`, `perk_fusion_localization_smoke`, `perk_fusion_tooltip_worst_case_smoke`: PASS=4, FAIL=0, 종단선 `All Godot smoke tests passed.`
- `meridian_expand`는 `GENERAL_IDS`에 있고 `RARE_IDS`에 없으며, exact 한국어명 `기맥 확장`, exact detail, `runtime_enabled=true`를 직접 봉인했다. 7개 로케일 이름/detail과 부산물 3개 최악 툴팁도 GREEN이다.
- 반증 #3: `get_contextual_pool()`의 flag-OFF 제외 분기를 임시 해제했을 때 `flag OFF must exclude the inert meridian expansion reward`와 풀 크기 씰이 PASS=0/FAIL=1로 RED. 즉시 원복 후 위 4개 씰이 GREEN으로 복귀했다.

### S4 슬롯 한도·초과 점유 검증과 반증

- 기준 배선은 `BASE_PERK_SLOT_LIMIT=6`, `MAX_PERK_SLOT_LIMIT=7`이고, `get_perk_slot_limit()`는 flag ON에서 `runtime_perk_state.get_perk_fusion_owned_byproduct_ids()`의 `meridian_expand` 보유만 읽는다. flag OFF는 6 고정이다.
- 생산 `get_perk_slot_limit(` 호출은 `has_open_perk_slot`, `get_perk_slot_status`, `_filter_perk_slot_budget` 3곳이며 모두 `slot_context`를 전달한다. 스모크를 제외한 인자 누락 호출은 0건이다.
- `10` 교차 검색에서 운용 상한/임계값 잔존은 0건이다. 남은 `common_expansion`의 `총 10` 문구와 이를 봉인한 rebrand 스모크는 D3가 삭제 금지한 flag-OFF 레거시 정의의 backing compatibility data이며, flag ON 후보에서는 도달하지 않는다.
- 새 9/7 씰이 기준 구현의 결함을 적발했다. `_filter_perk_slot_budget()`가 `occupied_slots + 0 <= limit`도 요구해 초과 점유 시 보유 업그레이드를 잘못 차단했다. `extra_slots == 0`은 유지하고 신규 슬롯 증가만 한도로 막도록 중앙 필터를 고쳤다. 이후 9개 보유는 그대로 유지되고, 신규 `item_recycle`은 차단되며, 보유 `dash_acceleration` 업그레이드는 남는다.
- 반증 #1: 부산물 보너스 반환을 임시 `0`으로 바꾸자 state/registry 한도, 7번째 적용, 신화 게이트 등 17개 단언이 RED. 즉시 원복했다.
- 반증 #2: `get_perk_slot_status()`의 limit 조회에서 `slot_context`를 임시 제거하자 state/registry 전달과 9/7/7/7 상태 5개 단언이 RED. 즉시 원복했다.
- 복원 후 `perk_slot_limit_smoke`, `perk_status_owned_tooltip_smoke`: PASS=2, FAIL=0, 종단선 `All Godot smoke tests passed.`; 두 변경 파일 warning 0.
- 동반 `perk_offer_owned_upgrade_priority_smoke`의 mythic jackpot 2개 단언 실패는 동일 기준 HEAD의 필러 격리 워크트리에서도 재현되는 선행 베이스라인이다. 이번 S4 필터 변경 전부터 존재하며 scoped GREEN과 분리한다.

### S5 방어 훅·라이브 씰

- `runtime_perk_state.gd:292-299`의 방어 훅은 flag ON 직접 복원에서 `runtime_skill_levels["common_expansion"]`을 지우고 제거 여부를 반환한다. flag OFF에서는 같은 키와 레벨을 보존한다.
- 생산 스크립트에서 `restore_perk_fusion_snapshot(` 호출자는 **0건**이다. 현재 호출은 테스트뿐이므로 이 결과는 미래 복원 계약이며, 라이브 세이브 자가 치유 완료를 주장하지 않는다.
- 기존 실전 `BattleSceneShell` 기반 2020x1246 Vulkan QA를 세 run-id `gwangmaekgyeol-live-seed-101`, `-202`, `-303`으로 실행했다. 세 번 모두 생산 시작 카드 오퍼에 `common_expansion`이 없었고 선택·런 진행 반영까지 통과했다.
- 같은 라이브 QA에서 실제 `RuntimePerkState.commit_perk_fusion()` 생산 facade를 디버그 부산물 결과로 실행했다. `meridian_expand` 보유와 슬롯 한도 7을 확인했다. 종단 표식은 `retired_expansion_absent_cases=3`, `meridian_expand_fusion=ok`, `tower_start_card_visual_qa: ok`였다.
- 캡처는 `godot/.godot/codex_captures/tower_start_card/`의 3개 PNG이며, 시작 카드 화면을 직접 확인했다. 대표 캡처의 세 카드는 `빙혼비격 비급`, `태허심법`, `개광결`로 광맥결이 없었다.

### 최종 공통 게이트

- 집중 스모크 8개: 시작 카드, 탑 보상 픽, 부산물 카탈로그, 결과 빌더, 7로케일, 최악 툴팁, 슬롯 한도, 보유 툴팁 모두 PASS=8, FAIL=0. 종단선 `All Godot smoke tests passed.`와 `SCRIPT ERROR` 0건을 확인했다.
- 변경 GDScript 8개 집중 경고 스캔: warning 0.
- 전체 headless load: `[ApplicationQuitCoordinator] graceful headless shutdown complete` 뒤 `Godot headless load check passed.`
- 재사용 워크트리의 LFS 포인터 문제는 새 워크트리를 만들거나 import를 돌리지 않고 해결했다. 로그가 요구한 LFS 객체만 공용 객체 저장소에서 OID/SHA-256 일치 확인 후 물질화하고, import 캐시는 동일 소스 SHA-256을 가진 기존 웜 워크트리에서만 복사했다. 추적 diff는 생기지 않았다.
- 신규·개정 집중 씰 `tower_start_card_smoke.gd`, `tower_reward_pick_smoke.gd`, `perk_fusion_byproduct_catalog_smoke.gd`, `perk_slot_limit_smoke.gd`는 CI와 pre-push 두 리터럴 목록에 모두 존재한다.
- `git diff --check` 통과. 반증검증 임시 토글 잔존 0건. blocked 0, unverified 0.

| 슬라이스 | 상태 | 커밋 | 검증 |
|---|---|---|---|
| S1 노출 경로 조사 | 완료 | `80702fd60` | 교차 검색과 생산 호출 경로 추적 |
| S2 flag ON 노출 차단 | 완료 | `be9704cd7` | 시작 카드·타락승 공용 정책과 별도 보상 후보 소스 봉인 PASS |
| S3 `meridian_expand` | 완료 | `d74f3b57c` | exact 이름/detail·runtime 활성·general 포함·rare 제외·7로케일·최악 툴팁 봉인 |
| S4 슬롯 한도 이전 | 완료 | `29ca430e0` | 6→7 부산물 한도·state/registry 전달·9/7 초과 점유 유지와 신규 차단 봉인 |
| S5 방어 훅 + 씰 | 완료 | 현재 S5 커밋 | flag ON/OFF 복원 계약, 생산 호출자 0건, 라이브 3시드, 실제 융합 facade 봉인 |
