# 탑 시작 카드 구현 보고서

- 작업 기준: `docs/tower_starting_card_goal.md`, `docs/tower_starting_card_urgent_amendment.md`
- 격리 기준 HEAD: `0569bc56c`
- 본 트리 통합 전 HEAD: `f7baabe7a`
- 구현·검증 커밋 종단 HEAD: `2e3f33e76`
- 판정: **GREEN** — S0~S5 구현·집중 검증 완료, 시작 카드 범위 `blocked=0`, `unverified=0`
- 푸시: 하지 않음
- 신규 시각·음원 에셋: 0개

## 1. 구현 결과

탑 플래그 ON이고 캐릭터 선택에서 발급한 일회성 토큰이 있을 때만, 프롤로그보다 먼저 시작 카드 화면이 한 번 열린다. 총 후보가 3장 미만이면 화면을 열지 않고 기존 프롤로그·랜딩으로 진행한다. 플래그 OFF, 디버그 직행, 재진입에서는 카드가 자동으로 열리지 않는다.

오퍼는 `run_id + character_id + offer_version`에서 파생한 전용 `RandomNumberGenerator`로 결정된다. 전역 게임플레이 RNG를 소비하지 않고, 카탈로그는 `get_all_perk_data()` 한 번으로 수집한다. 구성 계약은 다음과 같이 고정했다.

| 후보 상태 | 결과 |
|---|---|
| 초식 2장 이상 | 초식 1~2장 + 나머지 무공, 임시 확률 50% |
| 초식 1장 | 초식 1장 + 무공 2장 |
| 초식 0장 | 무공 3장 |
| 전체 후보 3장 미만 | 화면 생략 |

고정 시드 씰에서 초식 1장과 2장 결과를 각각 재현하며, 대장장이 레그는 다른 캐릭터 초식을 받지 않고 무공 3장을 받는다. 절세·즉시형·체질 수련·타 캐릭터 전용·잠긴 항목과 `max_level < 2` 무공은 후보에서 제외한다.

무공은 새 공개 진입점 `RuntimePerkState.apply_choice_at_target_level()`을 통해 실제 레벨 2로 한 번에 적용한다. 기존 `apply_choice()`의 1레벨 상승 동작은 바꾸지 않았다. 획득 피드백과 천사의 축복 수락 훅은 각각 한 번만 발화하며, `apply_choice()` 두 번 호출 경로가 아님을 부정 레그로 봉인했다.

화면은 불투명 검은 배경, 무료 3장 카드, 현재 무공과 플레이어 능력치 띠를 사용한다. 가격·잔액·계속 버튼·재추첨은 없다. 한국어 기본과 기존 7개 언어 경로를 사용하며 엠대시는 추가하지 않았다. 선택 결과는 `run_progress.start_card`의 `consumed`, `picked_perk_id`, `picked_kind`, `offer_ids`에 저장되고 첫 `prepare_vertical_slice_combat`를 지나도 유지된다. 키가 없는 구 스냅샷은 재등장을 막기 위해 소비 완료로 읽는다.

## 2. 커밋 매핑

격리 워크트리에서 각 슬라이스를 검증한 뒤 본 트리에는 패치를 exact-path로 재적용했다. 공유 파일의 기존 사용자 WIP는 비스테이징 상태로 보존했다.

| 슬라이스 | 격리 커밋 | 본 트리 커밋 | 내용 |
|---|---|---|---|
| S0 | `e0d0503cc` | `3e037516f` | 시작 카드·파계승 공용 후보 정책, 파계승 무공 해금 필터 잠복 결함 수리 |
| S1 | `1d188f4ae` | `74aa2f19e` | 결정론 오퍼 빌더와 헤드리스 상태 모듈 |
| S1 긴급 개정 | `dfe7d44ea` | `656532fff` | 1~2 초식 혼합, 무공 실제 2성, 단일 부작용 진입점과 대장장이 3무공 씰 |
| S2 | `1ee66c599` | `25e75a8fa` | 실 `BattleSceneShell` 생명주기 6곳과 일회성 진입 토큰 배선 |
| S3 | `37543c548` | `63bc50ff5` | 시작 카드 렌더러, 7언어 카피, Vulkan QA 러너 |
| S4 | `c7ad7191a` | `e206b060c` | `run_progress.start_card` 원장과 첫 prepare 관통 |
| S5 | `3adbdf34c` | `2e3f33e76` | 실 셸·3캐릭터 라이브 QA, CI/pre-push 락스텝 |

## 3. 임시 튜닝 표

모든 미확정값은 `tower_ascent_tuning.gd` 한 곳에만 뒀다.

| 상수 | 값 |
|---|---:|
| `TEMP_START_CARD_TOTAL_COUNT` | 3 |
| `TEMP_START_CARD_MIN_CHOSIK_COUNT` | 1 |
| `TEMP_START_CARD_MAX_CHOSIK_COUNT` | 2 |
| `TEMP_START_CARD_TWO_CHOSIK_CHANCE` | 0.50 |
| `TEMP_START_CARD_MUGONG_START_LEVEL` | 2 |
| `TEMP_START_CARD_PICK_LIMIT` | 1 |
| `TEMP_START_CARD_MIN_TOTAL_CANDIDATES` | 3 |
| `TEMP_START_CARD_OFFER_VERSION` | 1 |
| `TEMP_START_CARD_FOOTER_RESERVE_PX` | 0.0 |
| `TEMP_START_CARD_BACKDROP_ALPHA` | 1.0 |
| `TEMP_START_CARD_INTRO_ANIM_SEC` | 0.28초 |
| `TEMP_START_CARD_ABSORB_DURATION_SEC` | 0.78초 |
| `TEMP_START_CARD_FAILSAFE_TIMEOUT_SEC` | 20.0초 |
| `TEMP_START_CARD_COLD_BUILD_BUDGET_MS` | 8.0ms |

## 4. 검증 증거

### 집중 자동 검증

- 본 트리 집중 스모크: **8/8 PASS**, 종단선 `All Godot smoke tests passed.`, exit 0
  - `tower_start_card_smoke`
  - `tower_ascent_run_state_smoke`
  - `tower_ascent_vertical_slice_smoke`
  - `tower_ascent_snapshot_recovery_smoke`
  - `runtime_perk_traditional_choice_ui_smoke`
  - `runtime_perk_choice_stats_band_smoke`
  - `tower_reward_pick_smoke`
  - `stage1_han_miryang_prologue_smoke`
- 변경 GDScript 집중 경고 스캔: **26/26**, 경고 0, exit 0
- 헤드리스 로드: graceful shutdown 종단선 확인, 누수·SCRIPT ERROR 0, exit 0
- 구현 커밋 범위 `git diff --check`: PASS
- CI/pre-push 정적 리터럴 목록: **206 대 206**, 차집합 0, `tower_start_card_smoke` 양쪽 등재

봉인한 핵심 부정·역방향 레그는 플래그 OFF의 6개 셸 접점 완전 우회, 토큰 없는 직행, 후보 3장 미만 생략, 기존 `apply_choice()` 1레벨 동작 보존, 2성 지급 시 획득 피드백·천사의 축복 각 1회, 첫 prepare 뒤 결과 생존이다.

### RED 반증

- 렌더러의 능력치 띠 직접 호출을 동적 호출로 임시 변경했을 때 `tower_start_card_smoke`가 `start-card renderer must reuse _draw_stats_band(`로 RED가 됐다. 원복 후 관련 4종 GREEN.
- 첫 prepare의 `start_card` 이관을 임시 제거했을 때 `tower_ascent_vertical_slice_smoke`가 사전 원장 보존과 첫 승리 스냅샷 직렬화 두 단언에서 RED가 됐다. 원복 후 관련 4종 GREEN.

두 반증은 스테이징하지 않았고 최종 트리에 남지 않는다.

### Vulkan·라이브·콜드 진입

실 `BattleSceneShell`과 탑 플로 오너로 2020×1246 Vulkan 캡처 3장을 다시 생성하고 직접 검수했다.

| 캡처 | SHA-256 | 판정 |
|---|---|---|
| `.godot/codex_captures/tower_start_card/start_card_three_choices.png` | `16CE5D8B1655678AAC4DB01F20F14EBF6AE1EE04EBD24CF8224271265C014B95` | 불투명 검정, 3장, 가격 없음, 1초식+2무공 |
| `.godot/codex_captures/tower_start_card/start_card_selected.png` | `9604F58E19C8920D4239E19308F2980A74D2A67529DBFABE4D9DE1C20B0D1E63` | 선택 무공 실제 2성, 나머지 카드 감광, 클리핑 없음 |
| `.godot/codex_captures/tower_start_card/start_card_prologue_handoff.png` | `93A2513FCFF7D96E39A756D8FE8A8F793E97814785A3ADC1453302CAD8019DCD` | 한미량 프롤로그 정상 인계 |

- 실 진입 3캐릭터: 스매셔, 바이퍼, 대장장이 **3/3 PASS**
- 프롤로그 있음: 스매셔 → 한미량 프롤로그 정상
- 프롤로그 없음: 바이퍼·대장장이 → 정상 랜딩
- 콜드 오퍼 빌드: 스매셔 1.566ms, 바이퍼 0.804ms, 대장장이 0.544ms
- 예산: 8.000ms, 세 경로 모두 통과
- Vulkan 러너 종단선: `captures=3`, `live_cases=3`, `cold_build_ms=...`, `ok`, exit 0

## 5. 전체 기준선 분리

본 트리 `run_pre_push_checks.ps1 -Mode light`는 207종 중 **194 PASS / 13 FAIL**로 전체 GREEN은 아니었다. 시작 카드·탑 관련 테스트는 전부 PASS이며, 13건은 이번 변경과 무관한 기존 WIP 영역이다. 격리 베이스에서 관측한 22 RED보다 9건 줄었고 시작 카드 신규·악화 RED는 0건이다.

후속 소유 트랙으로 이관한 13건:

- `character_info_stat_source_attribution_smoke`
- `ingame_paddle_term_ban_smoke`
- `perk_offer_owned_upgrade_priority_smoke`
- `mythic_reveal_backdrop_smoke`
- `project_resource_loader_import_preference_smoke`
- `match_player_skill_deps_builder_smoke`
- `stage7_akamu_prebattle_video_smoke`
- `stage7_akamu_result_scene_smoke`
- `plaza_hwangyeok_building_r1_production_smoke`
- `lingpet_overflow_guardian_snapshot_builder_owner_smoke`
- `lingpet_egg_runtime_smoke`
- `player_socket_glow_smoke`
- `player_socket_part_overlay_smoke`

## 6. 안전·백업·종단 상태

- 검증 로그 선행 백업: `C:\Users\woduq\.codex\backups\tower_start_card_logs_20260819_124151` (415파일, 832,158바이트, 집계 SHA-256 `F8E51B825CBD2EA3A8516C5DBD32D44B7691796022A00AD9E76854F39C8C88C7`)
- 통합 전 겹침 파일 백업: `C:\Users\woduq\.codex\backups\tower_start_card_integration_20260819_141502` (6파일, 원본과 복사본 해시 일치)
- 본 트리 인덱스: 비어 있음
- 사용자 WIP: 보존, 시작 카드 커밋에 포함하지 않음
- 푸시: 하지 않음

| 분류 | 결과 |
|---|---|
| fixed | S0~S5와 긴급 개정 전건 |
| deferred | 전체 회귀의 무관 기준선 RED 13건, 각 소유 트랙 |
| blocked | 0 |
| unverified | 0 |

시작 카드 범위의 완료 조건을 충족한다.
