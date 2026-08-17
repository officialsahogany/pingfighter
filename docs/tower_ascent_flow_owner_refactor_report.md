# 탑 flow owner 분할 리팩토링 완료 보고서

- 기준 지시문: `docs/tower_ascent_flow_owner_refactor_goal.md`
- 착수 HEAD: `13d252dbd546a9725d0c8644080cfde4b83d3418`
- Godot: `4.6.2.stable.official.71f334935`
- 판정: **GREEN — 행동·수치·표면 변화 0, blocked 0건, unverified 0건**
- 푸시: 하지 않음

지시문은 이전 시점의 본체를 2,122줄로 기록했지만 착수 HEAD의 실제
`tower_ascent_flow_owner.gd`는 페이즈 D 반영 뒤 2,425줄이었다. 본 보고서는
착수 HEAD 실측 2,425줄을 비교 기준으로 사용한다.

## 1. 커밋 목록

| 순서 | 커밋 | 내용 |
|---:|---|---|
| 1 | `9b2abf456` | 기존 경로를 1줄 호환 파사드로 고정하고 구현을 `flow_runtime`으로 이동 |
| 2 | `bc48d96b2` | 상수·공유 상태·의존체·리셋 유틸리티를 `flow_state`로 추출 |
| 3 | `1bcbcde08` | 지도 소비·후보·조준 공·이동·멱등 해소를 `flow_map_progress`로 추출 |
| 4 | `7a9e1e32e` | run_state 경제와 상점·수련 거래를 `flow_economy_progress`로 추출 |
| 5 | `357f19e52` | 노드 모달과 파계승·샘터·휴식 위임을 `flow_node_progress`로 추출 |
| 6 | `71bbc642b` | 9층·결산·11층 연전·12층·패배 기록을 `flow_ending_progress`로 추출 |
| 7 | `0d7e774fe` | 스냅샷 왕복과 보상 저널을 `flow_snapshot_progress`로 추출 |
| 8 | `90b1b1a57` | 통합 보스 4종의 도달 불가 튜닝 대역과 낡은 표 주석 제거 |
| 9 | 이 보고서를 포함하는 `봉인(탑): flow owner 분할 계약과 보고` 커밋 | 새 구조 씰, 소유권 원장, 아키텍처 기록, 완료 보고 봉인 |

각 추출 단위는 관련 스모크, 변경 경로 경고 스캔, 헤드리스 로드,
`git diff --check`를 통과한 뒤 독립 로컬 커밋으로 남겼다.

## 2. 최종 소유권과 규모

상속은 저장소의 기존 얇은 진입점 패턴을 사용한다. 모든 의존체는
`flow_state`의 필드 초기화에서 기존과 같은 시점에 생성되며, 하위 행은 바로 위
행을 상속한다.

| 파일 | 줄 | 함수 | 소유권 |
|---|---:|---:|---|
| `tower_ascent_flow_owner.gd` | 1 | 0 | 안정 공개 경로 |
| `tower_ascent_flow_runtime.gd` | 182 | 9 | 시작·입력·선택 갱신·그리기 조정 |
| `tower_ascent_flow_snapshot_progress.gd` | 269 | 5 | 전체 그래프 스냅샷·보상 저널 |
| `tower_ascent_flow_ending_progress.gd` | 415 | 26 | 엔딩·결산·연전·패배 진행 |
| `tower_ascent_flow_node_progress.gd` | 259 | 23 | 노드 모달·서비스 노드 위임 |
| `tower_ascent_flow_economy_progress.gd` | 532 | 30 | run_state·상점·수련 거래 |
| `tower_ascent_flow_map_progress.gd` | 389 | 43 | 지도·경로·조준·이동·해소 |
| `tower_ascent_flow_state.gd` | 294 | 14 | 공유 상수·상태·의존체·리셋 유틸리티 |

공개 `flow_owner`는 권장 500줄보다 작은 1줄 파사드이고 실제 조정층도 182줄이다.
경제 모듈의 532줄은 동일 멱등 거래 경계를 공유하는 상점·수련을 한 오너에
유지한 결과다. 이를 다시 쪼개면 두 기존 소스 씰과 롤백 경계가 갈리므로 이번
행동 보존 목표에서는 한 모듈로 유지했다.

신규 GDScript 8개는 `.gd.uid` 8개를 모두 동반하며 UID는 8/8 고유다.

## 3. 행동 보존 증거

착수 HEAD의 단일 본체와 현재 7개 구현 모듈을 함수 단위로 파싱해 공백 끝만
정규화한 뒤 본문을 직접 비교했다.

- 함수 본문: `old=150 current=150 missing=0 added=0 changed=0`
- 상수·상태 헤더: `identical=True` (`5,992`자 동일)
- 공개 API: 새 `tower_ascent_flow_owner_refactor_smoke`가
  `begin_floor_nine_resolution`, `resolve_gauntlet_victory`,
  `begin_floor_twelve_true_ending`, `resolve_defeat`, `begin_run_settlement`,
  `collect_muhon`, 스냅샷·입력·갱신·그리기 진입점을 실제 인스턴스에서 확인한다.
- 스냅샷: `SNAPSHOT_SCHEMA_VERSION == TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION`
  계약을 유지했고 값은 계속 `7`이다.
- GRT-003/GRT-042: 기존 공유 의존체 18개가 모두 `flow_state` 필드에서 즉시
  생성된다. `update_selective()`와 `draw()` 본문에는 `.new()`가 없으며 생성
  지점은 콜드/가시 프레임 쪽으로 이동하지 않았다.

구조 동치 로그:
`D:\codex_tmp\tower_ascent_flow_refactor_final_20260818\structural_equivalence.log`
(`SHA-256 A1A8F94411494C21F9D7F737EC5DFA8EC69480961FB16D7049AA147889D14271`).

## 4. 기존 씰 개정 감사

기존 단언·기대값·픽스처는 바꾸지 않았다. 허용된 모듈 참조 갱신은 정확히
두 곳뿐이다.

- `tower_ascent_shop_node_smoke.gd`: 소스 계약 읽기 경로를
  `tower_ascent_flow_owner.gd`에서 `tower_ascent_flow_economy_progress.gd`로 변경.
- `tower_ascent_training_node_smoke.gd`: 같은 경로 변경.

두 파일의 나머지 diff는 0줄이다. 신규
`tower_ascent_flow_owner_refactor_smoke.gd`는 파사드 규모, 상속 사슬, 공개 API,
스키마, eager 생성, 핫 경로 비생성을 추가로 봉인한다.

## 5. 통합 보스 사문 정리

`TEMP_BOSS_STANDIN_BY_SLOT`에서 다음 도달 불가 4키를 제거했다.

- `floor_02_molewang`
- `floor_02_arachne`
- `floor_03_teddy_bear`
- `floor_03_alice`

네 슬롯은 `tower_ascent_boss_registry.gd`의 `STATUS_PORTED` 항목이 stage,
boss_id, variant를 직접 소유하고 `get_standin()`에서 튜닝 표보다 먼저 반환한다.
튜닝 표는 23개에서 남은 shell 19개로 줄었다. 보스 레지스트리·12층 지도·지도
생성 스모크가 모두 GREEN이므로 제거는 무해하다.

## 6. 최종 게이트

- 타워 전 스모크 31종 + 기존 소비자 8종: `PASS=39 FAIL=0 TOTAL=39`.
- 필수 종단선: `All Godot smoke tests passed.`
- 변경 GDScript 집중 경고 스캔: `12/12`, 경고 0건.
- 헤드리스 로드: graceful shutdown marker와
  `Godot headless load check passed.` 확인.
- 플래그 OFF: `tower_ascent_phase_a_off_path_smoke`와 기존 소비자 묶음 GREEN.
- 모든 실행은 사용자 게임 PID 31688을 유지한 채 `-AllowDuringPlay`,
  BelowNormal 검증, 고유 로그, `finally` 우선순위 복구 계약으로 수행했다.

| 로그 | SHA-256 |
|---|---|
| `smoke_39.log` | `06E01D3C6958A4F3D3803638334C34650D04681ABF9F813B97E31677921B32AE` |
| `warning_12.log` | `92ED50DD97A0439D55BE96068694606F17571B6493BACC4AF5031C58DDB3D1CF` |
| `headless.log` | `6DEC872B6BFF96FBE13592D299917798F6B4C124B4E32212619D7C1BA5C43277` |

로그 경로: `D:\codex_tmp\tower_ascent_flow_refactor_final_20260818`.

## 7. Vulkan 렌더 불변

NVIDIA GeForce RTX 5070, Vulkan Forward Mobile에서 세 래퍼를 모두 재실행했다.

- 수직 슬라이스: 3장, GREEN.
- 페이즈 C 노드: 6장, GREEN.
- 페이즈 D: 6장, GREEN.
- 기존 캡처 15장 중 14장은 SHA-256이 그대로였다.
- Phase B `node_modal.png` 한 장은 페이즈 C 실기능 이전의 오래된 산출물이어서
  현재 수호의 샘터 표면으로 갱신됐다. 현재 결과를 연속 재캡처하자 3/3 해시가
  완전히 같았고(`DIFFERENCES=0`), 새 `node_modal.png`를 직접 열어 겹침·클리핑·
  가독성 문제 없음으로 판정했다. 구현 함수 본문 150/150 동치와 함께 리팩토링
  렌더 변화가 아님을 확인했다.

Vulkan 로그 SHA-256:

- `vulkan_slice.log` / 반복 로그:
  `0B4E4A48F2C05BDA0E8DA046F203A6252A7B715D45CD8D0C0807039F1D2075B1`
- `vulkan_phase_c.log`:
  `F2FBD6013EF69F53E4334665E6FED07FF79FD4CA8936001DC6C1F67DF9080D58`
- `vulkan_phase_d.log`:
  `82EBA52DE919B71630EFAA897AE1FE179AB0050EB062BCC98CF3FC13AEE39C41`

## 8. fixed / deferred / blocked / unverified

### fixed

- 2,425줄 단일 flow owner를 공개 1줄 파사드와 7개 안정 구현 오너로 분할.
- 공개 API·함수 본문·상수·상태·스냅샷 스키마·생성 시점 보존.
- 통합 보스 4종의 도달 불가 튜닝 대역과 낡은 주석 제거.
- 소유권 원장과 아키텍처 문서 갱신.

### deferred

- 없음. 페이즈 E와 신규 콘텐츠 작업은 이 행동 보존 리팩토링의 원래 비범위다.

### blocked

- 없음.

### unverified

- 없음.

기존 대규모 비관련 WIP는 수정·스테이징하지 않았다. 이미 더티였던
`godot_module_ownership_ledger.md`와 `godot_port_architecture.md`는 탑 소유권
헝크만 별도 인덱스 패치로 커밋하고 나머지 작업 상태를 그대로 보존한다.
