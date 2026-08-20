# 변형 보스 공-경로 variant 키 누락 수정 보고서

- 기준 HEAD: `ad0c4ea42854da2d5a8e205f22de57970ac5f9bc`
- 격리 브랜치: `codex/variant-boss-ball-key-p0-ad0c`
- 격리 워크트리: `D:\main\bosspong_perk_cluster_minimal2` (기존 warm 워크트리 재사용)
- 푸시/본 트리 통합: 하지 않음

## S1 — 공 경로 키 복원

- 커밋: `936cbef3a8a4e6da94547ec0b13b76f4bd046516`
- `godot/scripts/ball/ball_update_owner_snapshot.gd:56`에
  `stage_boss_variant`를 추가했다.
- 기본값은 특정 보스가 아닌 `""`이며, `_get_owner_value()` 1회만 호출한다.
- `battle_scene_state.gd:98`의 기존 선언을 재사용했고 owner schema를 중복
  선언하지 않았다.
- 정본 스냅샷의 다른 키나 로직은 바꾸지 않았다.

## S2 — fail-closed 설계 판정

- 커밋: `b5a2dc39767d5b6c98ebcf19dc0cdae248dcd0cf`
- 선택: 호출 순서에 기대지 않는 **명시 variant 검증 + no-op**.
- Stage 2/3 variant proxy는 컨텍스트의 ID가 해당 스테이지의 ported variant일
  때만 `active_variant`를 갱신한다. 키 누락, 빈 값, 오타, 타 스테이지 ID는
  `{}`를 반환하고 직전 유효 `active_variant`를 보존한다.
- 따라서 `update()`가 반드시 먼저 실행됐다는 순서 가정이 없다. 누락 키가
  `normalize_variant()`의 기본값으로 바뀌어 청린귀·연묘 스킬을 실행하는 경로도
  없다.
- 정상 기본 보스는 `cheongringwi`/`yeonmyo`가 명시된 경우 기존 `super`
  경로를 그대로 사용한다.

## S3 — 형제 누락 전수 조사

### 방법

1. `battle_scene_state.gd`의 `DEFAULT_VALUES` literal 308개와 S1 이후
   `ball_update_owner_snapshot.gd` literal 49개를 수집했다.
2. `scripts/ball/**/*.gd`에서 `context`, `ctx`, `_context`, `frame_context` 등
   `*context` 변수의 줄바꿈 포함 `.get()`/`.has()` 호출과
   `_get_vector2(context, "key")` 같은 literal helper read를 수집했다
   (고유 키 194개).
3. `paddle_bounce_boss_post_hit_handler.gd`의 실제 duck-typed 호출과
   `gameplay_stage_module_catalog.gd`의 production 매핑으로 Stage 1~5 직접 보스
   호출 대상을 정하고, Stage 2/3 proxy의 base/variant 자식까지 같은 방식으로
   수집했다(고유 키 96개).
4. 소비 키와 `DEFAULT_VALUES`의 교집합에서 snapshot 키를 뺐다. S1 이후
   17개가 남았다. 단순한 검색 0건을 도달 불가 증거로 사용하지 않았으며,
   실제 owner→snapshot→hit 도달성은 S4 실행 씰이 담당한다.

### 판정표

| 분류 | snapshot 비포함 키 | 판정과 근거 |
|---|---|---|
| 이번 P0에서 수정 | `stage_boss_variant` | S1 전 유일한 변형 보스 식별 누락. `battle_scene_state.gd:98`에 선언되고 Stage 2/3 hit target이 소비한다. S1에서 복원했다. |
| late builder 공급 — 무해 | `ball_size`, `boss_hitbox_height`, `boss_paddle_width`, `special_gauge_max` | `ball_update_context.gd:82-115`가 static config와 owner 값을 합쳐 실제 update context에 싣는다. `special_gauge_max`는 소비되는 `gauge_max`로 투영된다. |
| 프레임 파생 — 무해 | `ball_pos_prev`, `ball_interp_last_physics_usec`, `ball_render_interpolation_enabled` | 앞의 두 값은 `ball_render_interpolation.gd:11-19`가 매 physics step 시작에 현재 위치/시각으로 다시 만든다. interpolation enabled는 production writer가 없는 기본 `true`이며 draw owner context가 별도로 읽는다. |
| draw/런타임 별도 공급 — 무해 | `ball_visual_type`, `bomb_ball_loaded`, `boost_charging_active`, `poisoned_ball_overlay_active`, `viper_knockback_overlay_active` | `battle_draw_playfield_scene_context.gd`/`battle_draw_ball_context.gd`가 owner·dash snapshot에서 draw context를 만들며, Viper 값은 `ball_update_controller.gd:741-765`의 runtime collision-context merge도 공급한다. owner update snapshot의 책임이 아니다. |
| 별도 형제 결함 — 이번 범위 밖 | `trampoline_launch_speed_cap`, `trampoline_launch_speed_cap_frames` | `ball_motion_event_processor.gd:388-400` 주석과 구현이 frame-boundary TTL 보존을 요구하지만 owner snapshot에는 없다. 보스 발동 구조 결함과 무관하므로 이 P0에 섞지 않았다. 별도 수정/씰이 필요하다. |
| 별도 형제 결함 — 이번 범위 밖 | `player_paddle_width`, `player_paddle_height` | update builder는 동적 값을 `player_paddle_size`에는 싣지만 scalar에는 싣지 않는다. `ball_motion_event_processor.gd:731-739`의 Spellbreaker 중심점 계산은 scalar 기본값을 직접 읽는다. 변형 보스 발동과 무관하므로 별도 수정 대상이다. |
| 별도 순서 위험 — 이번 범위 밖 | `ball_interp_reset_requested` | `stage_ball_spawn_intro.gd:748`에 owner writer가 있고 controller는 `ball_update_controller.gd:796`에서 읽지만 snapshot은 싣지 않는다. 실제 손실 여부는 process/physics/draw 순서 실행 검증이 필요하다. 이번 P0에서 임의 수정하지 않았다. |

직접 보스 호출 대상 조인에서는 위 공통 geometry/default 항목 외에 추가
보스 식별·스킬 제어 키 누락이 나오지 않았다. 이 결론은 static 0건만으로
완료 처리하지 않고 S4의 production-path 실행 결과와 함께 사용한다.

## S4 — owner snapshot 관통 공통 씰

- 커밋: `570f5dae636d86e50d0ef5575c41a5178c8a13c8`
- 신규 씰: `godot/tests/variant_boss_ball_path_snapshot_smoke.gd`
- 모든 양성 컨텍스트는 `FakeOwner`에 `current_stage`와
  `stage_boss_variant`를 세팅한 뒤 실제
  `BallUpdateOwnerSnapshot.new().build(owner)`로 만든다. 반환 컨텍스트를 손으로
  보강하지 않는다.
- `EXPECTED_LEG_COUNT = 8`이며 실제 8개 레그를 실행한다.

| 레그 | 실행 결과 단언 |
|---|---|
| 두더지왕 첫 히트 | 실제 `register_boss_hit` 뒤 공 속도 ×0.8, spin 0.55, actor draw context의 회전발톱 active. 첫 히트 즉시 발동. |
| 두더지왕 게이지 | 회전발톱 spending만 cooldown으로 막은 독립 상태에서 첫 히트 뒤 실제 gauge 60, result gain 60. |
| 아라크네 | hit 뒤 actor draw context에 실제 거미줄 투사체 생성. |
| 테디베어 | 고정 seed를 탐색·고정하고 hit 뒤 실제 솜뭉치 투척 windup 비율 > 0. |
| 엘리스 | hit 뒤 실제 mirror active 및 mirror cooldown > 0. |
| Stage 2 키 누락 | snapshot 복제본에서 키를 지우면 result `{}`, gauge 불변, 직전 Molewang 유지. |
| Stage 3 키 누락 | snapshot 복제본에서 키를 지우면 result `{}`, gauge 불변, 직전 Alice 유지. |
| 기본 보스 무손상 | 명시 `cheongringwi`가 base hit 경로를 실행해 launch guard와 기존 result shape를 만든다. |

네 변형 양성 레그는 모두 `update → hit → get_snapshot/get_actor_draw_context`
순서를 지나며 hit 뒤 `active_variant`가 유지되는 것도 함께 단언한다. 스킬 발동
판정은 boolean trigger 플래그만 보지 않고 속도·스핀·투사체·windup·mirror
상태의 실제 결과를 본다.

### 반증 RED

S1의 snapshot 키 한 줄만 작업 트리에서 임시 제거하고 같은 씰을 실행했다.

- 결과: `Smoke summary: PASS=0 FAIL=1 TOTAL=1`, process exit 1.
- 네 변형 모두 `owner snapshot must carry stage_boss_variant=...`와 실제 스킬
  결과 미발생 단언이 RED였다.
- `apply_patch`로 한 줄을 즉시 복원했다. 복원 뒤 worktree blob과 S1 commit
  blob이 모두 `c0bef4ab822427f4dd2ed040b644ff73cb2c41f2`로 일치했다.
- 같은 씰 재실행 결과: `PASS=1 FAIL=0`,
  `All Godot smoke tests passed.`

이 반증으로 snapshot 키가 다시 빠지면 CI의 양성 4변형 레그가 RED가 됨을
실행으로 확인했다.

## 최종 검증

- S1: `stage2_molewang_boss_port_smoke` GREEN,
  touched-file warning scan GREEN, headless load GREEN, `git diff --check` GREEN.
- S2: 기존 보스 포팅 smoke 4개 `PASS=4 FAIL=0`, 두 proxy warning scan
  GREEN, headless load GREEN, `git diff --check` GREEN.
- S3: 보고서의 조인 잔여 키 17개 완전성 체크 GREEN, 포팅 smoke 4개 GREEN,
  관련 GDScript warning scan GREEN, headless load GREEN.
- S4 최종 성공 배치:
  - 신규 공통 씰
  - 기존 포팅 smoke 4개
  - `stage1_gaksital_fan_wind_smoke`
  - `stage7_akamu_slice1_smoke` (공 ball controller/dependency path)
  - `perk_fusion_ball_event_hooks_smoke` (실 owner snapshot의 다른 consumer)
  - 결과: `PASS=8 FAIL=0 TOTAL=8`, `All Godot smoke tests passed.`,
    `SCRIPT ERROR` 0건.
- touched GDScript 4개 warning scan: 0건.
- headless load: `[ApplicationQuitCoordinator] graceful headless shutdown complete`,
  GREEN.
- CI/pre-push focused literal 목록: 각각 186개, 차집합 0/0. 신규 씰은 양쪽
  목록에 각각 1회 등재. `run_pre_push_checks.ps1` parse error 0건.
- `git diff --check`: GREEN.
- 기준 HEAD 대비 보호 경로
  `docs/stage3_variant_transform_reset_fix_goal.md`,
  `docs/stage3_variant_skillcard_art_goal.md` diff: 0건.
- warm 워크트리의 누락 fontdata는 원본 폰트와 `.import` 설정 SHA-256이 모두
  같은 기존 격리 캐시에서 누락 파일만 복사했다. editor import는 실행하지
  않았다.

### 성공 근거에서 분리한 별도 RED

- `ball_boss_skill_pause_context_smoke`: 이번 키와 무관한 tear-gas alias/canonical
  pause 단언 2건 RED.
- `stage4_map_port_smoke`: 격리 warm 캐시의 Stage 4/skill icon `.ctex` 누락과
  기존 의존 스크립트 오류로 RED. 소스 수정이나 importer 실행 없이 중단했다.
- `stage7_akamu_slice2_smoke`: 이번 변경 경로와 무관한 slow speed/gauge
  owner 단언 6건 RED.
- 위 셋은 필수 포팅 4종 및 신규 씰의 GREEN과 섞지 않았고, 이 작업에서
  고치거나 성공으로 표기하지 않았다.

## 라이브/Vulkan 상태

지시문에 따라 본 트리의 실제 전투 확인은 사용자가 수행한다. 다음 네 항목은
구조 씰로 대체해 GREEN이라 쓰지 않았으며 **unverified**다.

1. 2020×1246 두더지왕 전투 회전발톱 발동 프레임
2. 2020×1246 엘리스 스킬 발동 프레임
3. 2020×1246 테디베어 자기 스킬(연묘 아님) 발동 프레임
4. 2020×1246 기본 보스(연묘 또는 청린귀) 무손상 프레임

## 최종 상태

- S1/S2/S3/S4: 구현 및 구조 검증 완료.
- 반증 RED: 확인 후 완전 복원.
- 필수 기존 포팅 smoke 4개: GREEN 유지.
- 구조 게이트 blocked: **0건**.
- 라이브 항목 unverified: **4건** (지시문이 사용자 본 트리 확인으로 지정).
- 푸시: 하지 않음.
- 본 트리 통합: 하지 않음. 보고 후 격리 브랜치에서 대기.
