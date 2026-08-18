# ROUTE_AIM owner 메타 접근 교정 완료 보고 (2026-08-18)

## 1. 판정

- **최종 판정: GREEN**
- `docs/tower_route_serve_owner_meta_fix_goal.md` §1의 4항목을 모두 구현·검증했다.
- 필수 게이트의 `blocked` / `unverified`는 **0건**이다.
- 로컬 커밋만 남겼고 푸시하지 않았다.

## 2. 로그 백업과 사전 반증

- 작업 전 백업: `D:\codex_backups\tower_route_serve_owner_meta_fix_20260818_084341`
  - Godot `user://logs`: 5파일 / 20,344,356바이트
  - `godot/logs`: 15파일 / 15,436바이트
  - 저장소 루트 `logs`: 400파일 / 816,722바이트
- 사용자 라이브 로그에서 종료 오류를 재확인했다.
  - `SCRIPT ERROR: Cannot call method 'get_children' on a null value.`
  - `_stop_audio_players:141 → _advance_pending_quit:107 → _process:39`
- 변경 전 기존 스모크는 route serve와 application quit 모두 GREEN이었다(2/2). 즉 두
  라이브 결함을 기존 fixture가 놓치고 있었다.
- 실제 `BattleSceneShell`을 route serve 씰에 연결한 뒤 구 accessor에서 다음 두
  단언이 RED가 됐다.
  - 메타 `player_pos` 이동 쓰기 수용
  - 메타 `ball_active` 유지 후 swept target 전이
- accessor 교정 후 동일 레그가 GREEN이 됐다. 구 var fixture도 함께 유지해 기존
  생산 계약의 역레그를 보존했다.

## 3. 항목별 구현과 커밋

| 항목 | 커밋 | 구현 결과 |
|---|---|---|
| 1. owner 접근자 교정 | `f78ee1f1f` | property-list 캐시·게이트·수집기를 제거하고 읽기는 `BattleSceneOwnerReader`, 쓰기는 bare `owner.set()`으로 통일했다. |
| 2. 라이브 셸 씰 | `7a357d497` | 실제 `BattleSceneShell`의 `_get`/`_set`과 `BattleSceneState`를 물리 게이트 프레임 경로로 관통한다. route 키가 property list에는 없다는 것도 단언한다. |
| 3. 플레이어 위치 Vulkan QA | `835993bf9` | 실제 `main.tscn`·라이브 셸·게임플레이 레지스트리·탑 flow를 사용하는 캡처 도구와 `-AllowDuringPlay` 래퍼를 추가했다. |
| 4. 종료 스팸 교정 | `4d63ac9bf` | 오디오 순회 대기열에서 이미 해제된 엔트리를 cast·역참조 전에 건너뛴다. 유효 오디오는 기존대로 stop·stream 해제된다. |

보고서 커밋은 위 네 구현 커밋과 분리한다.

## 4. GRT-017 owner 스키마 감사

route runtime이 읽거나 쓰는 owner 키 11종을
`BattleSceneState.DEFAULT_VALUES`와 대조했다.

`ball_active`, `ball_impact_boost`, `ball_pos`, `ball_size`, `ball_vel`,
`current_stage`, `gameplay_frame_counter`, `player_paddle_width`, `player_pos`,
`player_speed`, `selected_character_type`

- 미등재 키: **0개**
- `tower_ascent/**`의 `_owner_properties` / `_collect_property_names` 생산 잔재:
  **0개**
- 저장소에 남은 `_collect_property_names`는
  `runtime_perk_state_facade_contract_smoke.gd`의 별도 facade 감사 헬퍼뿐이며 이번
  owner 접근과 무관하다.

## 5. 라이브 렌더 판정

- 실행:
  `godot/tools/run_tower_route_serve_owner_meta_visual_qa.ps1`
- 생산 경로:
  `main.tscn → battle_scene_shell → gameplay registry → tower_ascent_flow_owner →
  tower_ascent_route_serve_runtime → battle scene draw`
- 캡처:
  `godot/.godot/codex_captures/tower_route_serve_owner_meta/route_aim_live_owner.png`
  - SHA-256:
    `3E8AA91D4CCCDDB739BEF63C35DD7FF2D6939CE0A61970F46800017FF356208D`
  - 플레이어: `(353.5, 700.0)` — 초기 하단 위치에서 오른쪽으로 이동
  - 서브 공: `(284.7738, 386.2048)` — `ball_active=true`, ROUTE_AIM 비행 중
- 화면 상단 중앙 인물은 플레이어가 아니라 Stage 4 보스 폰크다. 실제 플레이어
  스매셔는 하단 패들 위치에서 서브 자세로 렌더된다. 따라서 보고된 “상단 플레이어”는
  별도 player-position 결함이 아니며 추가 런타임 수정 대상이 아니다.

## 6. 종료 경로 씰

- 씰은 노드를 오디오 순회 대기열에 넣은 뒤 `free()`하여 라이브 종료 시점과 같은
  해제 엔트리를 만든다.
- 최종 구현은 `Variant` 상태에서 null / `is_instance_valid()`를 먼저 검사하고,
  살아 있는 노드만 `Node`로 cast한다.
- 기존 정상 레그도 유지한다.
  - scene-owned `AudioStreamPlayer` stop + stream 해제
  - root-owned `AudioStreamPlayer` stop + stream 해제
  - 현재 scene 해제와 `_exit_tree()` 실행
  - 중복 `request_quit()` 멱등성
- 최종 헤드리스 종료에서
  `[ApplicationQuitCoordinator] graceful headless shutdown complete`가 출력됐고
  `SCRIPT ERROR`는 없었다.

## 7. 최종 검증 종단선

| 게이트 | 결과 |
|---|---|
| 신규 메타-owner RED 반증 | 구 accessor에서 의도대로 RED 2개 |
| 탑 전체 + 종료 + 입력 스냅샷 + 물리 게이트 | `PASS=38 FAIL=0 TOTAL=38` |
| 수정 GDScript 경고 검사 | `checked 5/5`, 경고 0 |
| 헤드리스 로드 | `Godot headless load check passed.` |
| Vulkan 실제 main scene 캡처 | GREEN, 플레이어 이동·공 비행 좌표와 PNG 확인 |
| 최종 `git diff --check` | GREEN |

Vulkan 러너 말미의 `ObjectDB instances leaked at exit` 한 줄은 기존 windowed QA
프로세스 종료 baseline이며 serious-error 분류에 해당하지 않는다. 이번 결함의
`application_quit_coordinator` SCRIPT ERROR 스팸은 재현되지 않았다.

## 8. 상태 분류

- **fixed**: owner property-list 게이트, 라이브 셸 회귀 공백, 상단/하단 actor 식별,
  종료 중 해제 노드 역참조
- **deferred**: 0건
- **blocked**: 0건
- **unverified**: 0건
