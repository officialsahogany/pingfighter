# 탑 라이브 2런 피드백 완료 보고 (2026-08-18)

## 1. 판정

- **최종 판정: GREEN**
- `docs/tower_live_feedback_r2_goal.md` §1의 5항목을 모두 구현·검증했다.
- 필수 게이트의 `blocked` / `unverified`는 **0건**이다.
- 구현과 검증은 사용자 소유 Godot 플레이 프로세스가 열린 상태에서 표준
  `-AllowDuringPlay` 래퍼로 수행했고, 모든 래퍼가 `BelowNormal` 우선순위를
  확인했다. 사용자 프로세스는 종료하지 않았다.
- 로컬 커밋만 남겼고 푸시하지 않았다.

## 2. 로그 백업

- 작업 전 백업:
  `D:\codex_backups\tower_live_feedback_r2_20260818_092304`
  - Godot `user://logs`: 5파일 / 22,992,643바이트
  - `godot/logs`: 15파일 / 15,436바이트
  - 저장소 루트 `logs`: 400파일 / 816,722바이트

## 3. 항목별 구현과 커밋

| 항목 | 커밋 | 구현 결과 |
|---|---|---|
| 1. 첫 무혼 획득 프리즈 | `7ae4b42ea` | 첫 픽업 핫패스에서 전체 탑 flow owner를 콜드 생성하던 경로를 확인했다. 스테이지 런타임 프리웜으로 옮기고 픽업은 cached-only로 제한했다. 최종 계측은 prewarm 118µs, 첫 픽업 21µs, 픽업 중 콜드 생성 0회다. |
| 2. 경로 서브 자동 발사 금지 | `e2302054f` | ROUTE_AIM은 동일 프레임 입력 스냅샷의 실제 발사 edge만 소비한다. 30초 무입력 0회와 일반 전투 자동 서브 유지 역레그를 함께 봉인했다. |
| 3. 상단 벽·플레이어 패들 왕복 | `553d59a0a` | 상단 득점 경계를 벽 반사로 바꾸고 공유 `PaddleBounceState`를 재사용했다. 하단 이탈만 수동 재서브로 복귀하며 점수는 변하지 않는다. |
| 3-a. 상단 반사 실렌더 | `51a464e99` | 실제 `main.tscn`·메타 owner·공 스테퍼 경로에서 반사 직후 owner 좌표 `(380.0, 14.3)`, 속도 `(0.0, 8.0)`을 확인하고 두 번째 PNG를 남겼다. |
| 4. 전체화면 성곽 지도 | `8d9713064` | M 지도는 1280×800 viewport 전체를 덮고 1~9층 성곽, 전 노드 그림 슬롯, 상태 표기를 렌더한다. 기존 리소스만 preload하며 미존재 경로 로드는 없다. |
| 5. 인간계·신선계 2페이즈 | `0a4353b9e` | 생성기 `tower_map_v6_two_realms`, 인간계 1~9층과 신선계 10~12층을 별도 full graph로 직렬화했다. 활성 페이즈 인덱스를 런 상태에 추가하고 등정 선택 순간 2번 그래프로 원자 전환한다. MAP_TRANSITION도 전체화면 패스로 승격해 신선계 진입 배너와 이동 마커를 표시한다. |

보고서 커밋은 위 구현·검증 커밋과 분리한다.

## 4. 2페이즈 그래프·스냅샷 계약

- `phases[0]`: `phase_01_human_realm`, 1~9층, 평시 활성 지도.
- `phases[1]`: `phase_02_immortal_realm`, 10~12층, 진엔딩 등정 확정 전 잠금.
- 인간계 지도에는 신선계 실제 노드 9개가 노출되지 않는다. 대신
  `locked_phase_hints`의 `10~12층 신선계 잠김` 표기만 남긴다.
- 9층 첫 클리어·재클리어 판정은 기존 계약 그대로다. 재클리어 선택에서
  `continue`가 확정된 뒤에만 `active_phase_index=1`이 되고 10층 이동이 시작된다.
- 스냅샷은 두 full graph와 `run_progress.active_phase_index`를 함께 저장한다.
  신선계 진입 MAP_TRANSITION에서 export → restore → re-export한 `map_graph`가
  바이트 동일했고, 활성 페이즈 1(0-based)이 유지됐다.
- 스키마는 7에서 8로 올렸다. 구 스키마 7의 단일 페이즈 스냅샷은 좌표·잠금
  소유권을 추측해 변환하지 않고
  `reset_legacy_single_phase` 정책으로 **명시적 새 런 시작**을 요구한다. 복구는
  fail-closed이며 조용한 오독이 없다.

## 5. 렌더 판정

| 캡처 | 판정 | 크기 | SHA-256 |
|---|---|---:|---|
| `godot/.godot/codex_captures/tower_map_overlay/map_overlay_human_realm.png` | GREEN. 레터박스 포함 전체화면, 1층 아래→9층 꼭대기, 현재·완료·소멸과 신선계 잠금 암시가 읽힌다. | 1280×800 | `10B4024BC77E42B972C926890F2190364535E125D9FB4163D78CA36EDDD00B1D` |
| `godot/.godot/codex_captures/tower_map_overlay/map_overlay_immortal_realm.png` | GREEN. 실제 9층 등정 선택 경로의 MAP_TRANSITION이며 10~12층만 표시한다. 구름·절벽·암석 TEMP 톤, `신선계 진입` 배너, 하단 이동 마커가 확인된다. | 1280×800 | `BC36D2C404446CD13CBE9B65BF0F502365B84672DE741E68C523663D783704F1` |
| `godot/.godot/codex_captures/tower_route_serve_owner_meta/route_aim_top_wall_bounce.png` | GREEN. 실제 전투 씬 ROUTE_AIM에서 두 표적과 플레이어가 유지되고, 생산 물리 경로가 반사 직후 owner 좌표·속도를 같은 프레임에 게시한다. | 3072×1670 | `E9779CE7944E5B67A5F2DFCBACEC5E0F61A8258144D65AB35636D0CCA9D64D20` |

- 지도 캡처는 `BattleSceneDrawer`의 screen-space 생산 패스를 관통한다.
- 신선계 캡처는 read-only M fixture가 아니라 실제 `ENDING_CHOICE → continue →
  MAP_TRANSITION` 경로다.
- ROUTE_AIM 러너 말미의 `ObjectDB instances leaked at exit`는 기존 windowed QA
  종료 baseline이며 serious-error 분류가 아니다. 래퍼는 exit 0과 `ok` 종단선을
  확인했다.

## 6. 최종 검증 종단선

| 게이트 | 결과 |
|---|---|
| 탑 전체 스모크 | `PASS=36 FAIL=0 TOTAL=36`, `All Godot smoke tests passed.` |
| 생산 인접·아이템 씰 | 8/8 GREEN: 부트 프리웜, 물리 게이트, 같은 프레임 입력 edge, 일반 서브, 패들 피드백, 필드 스폰 풀, 픽업 라우터, 액티브 프리웜 |
| 수정 GDScript 경고 검사 | `checked 22/22`, 경고 0 |
| ROUTE_AIM 캡처 도구 경고 검사 | `checked 1/1`, 경고 0 |
| 헤드리스 로드 | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, `Godot headless load check passed.` |
| Vulkan 렌더 | 인간계 / 신선계 / 상단 벽 반사 3장 GREEN |
| 플래그 OFF | `tower_ascent_phase_a_off_path_smoke`와 수직 슬라이스의 레거시 결과화면 역레그 GREEN |
| `run_tower_mode.ps1` | PowerShell 파스 성공, 현 Godot 실행 파일·`project.godot` 경로 존재, 프로세스 한정 `TOWER_ASCENT_VERTICAL_SLICE=1`과 `--path` 실행 계약 확인 |
| 최종 `git diff --check` | GREEN |

생산 인접 배터리 첫 호출에서 존재하지 않는
`active_item_field_spawn_pool_smoke.gd`를 잘못 지정한 운영 오타가 1회 있었다.
정본 파일명 `item_field_spawn_pool_smoke.gd`를 확인해 재실행했고 GREEN이다. 코드
실패나 baseline RED로 집계하지 않았다.

## 7. 상태 분류

- **fixed**: 첫 무혼 콜드 생성, ROUTE_AIM 자동 서브, 상단 즉시 리셋,
  플레이어 패들 왕복 부재, 플레이필드 한정 지도, 단일 12층 그래프,
  페이즈 비인지 스냅샷·지도 이동
- **deferred**: 0건. 신규 비트맵 지도 아트는 목표에서 명시한 후속 아트 트랙이며
  이번 완료의 미구현 항목이 아니다.
- **blocked**: 0건
- **unverified**: 0건
