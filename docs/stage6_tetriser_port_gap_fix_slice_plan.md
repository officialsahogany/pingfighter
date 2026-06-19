# Stage 6 테트리서 포팅 갭 수정 슬라이스 (설계 문서)

작성일: 2026-06-18 · **단일 소스**. 이 문서는 설계/신호계약/회귀스모크/트랩 브리프만 담는다.
**GDScript 배선은 사용자(또는 Codex)가 직접** 하고, **Claude는 디자인 + 적대적 리뷰**를 맡는다
(메모리 `feedback_design_slice_review_division`). 런타임 통합/성능 최종권한은 `AGENTS.md`,
포팅 수치 1차 소스는 `docs/stage6_tetriser_port_plan.md` / `game_logic/stage7_tetriser.py`.

---

## 0. 배경 — 2026-06-18 포팅 충실도 감사 결과

12-시스템 적대적 감사 + 직접 코드 대조로, "테트리서 보스가 제대로 완전 포팅됐다"고 보기 어려운
근거가 확정됐다. **수치·발동 골격은 대부분 포팅됐으나, 공이 블록에 닿는 배선 자체가 빠져 충돌
로직 전체가 실게임에서 죽어 있고, 라운드 정리도 미배선이며, 낙하 테트로의 착지 생애주기(폭발/증발)가
빠져 있다.** 현재 블록들은 사실상 *공이 무시하는 시각적 장식*이다.

정상 포팅(유지): 게이지 500/초당25·라운드 persist, 초인(드레인 모델·본체 2.0×·셀 1.7×·0.6s 인트로),
super 면역 스코핑(일반 공만 면역), 반사축 함수, 가드/벽 수치, 중앙 큐브 골격, 레이저 0.8/1.2s,
크리스탈 실드 골격(플레이어 4점·24블록·피격+양옆), 통합 배선(transient cleanup·boss AI·draw·debug
picker·audio·prewarm·**stage-runtime** deps).

---

## 1. 슬라이스 순서 (우선순위 = 의존성 순)

| 슬라이스 | 등급 | 한 줄 | 선행 |
|---|---|---|---|
| **S0** | 🔴 CRITICAL | 신규 스테이지/이벤트 deps 3경로(ball/effects/draw) + wiring smoke + 픽셀 캡처 게이트 | 전 슬라이스 공통 |
| **S1** | 🔴🔴 CRITICAL | 공-deps 배선 → 블록 충돌 부활 | 없음 |
| **S2** | 🔴 HIGH | `reset()` 라이프사이클 배선 → 라운드 누수 차단 | 없음(S1과 독립) |
| **S3** | 🔴 HIGH | 착지 폭발(넉백/스턴) + 1.5초 증발 생애주기 | S1(공 충돌 부활 후 체감 검증 가능) |
| **S4** | 🟠 MEDIUM | 테트리스-feel 통합: 110ms 셀스냅 낙하 / 회전 딜레이·횟수·충돌거부 / 벽 테트로 더미 / 보스중심 스폰+관통 | S1, S3 |
| **S5** | 🟡 MED/LOW | 가드 조립단계 / 레이저 조건 / 큐브 카운트 / 사운드 3종 / 보상·VFX | — |

> **반드시 S1 먼저.** S3~S5의 어떤 충돌·파괴 수정도 S1 없이는 실게임에서 검증 불가
> (스모크가 `resolve_ball_collision`을 직접 호출하므로 통과해도 실게임은 죽어 있음).

---

## S0 — 신규 스테이지/이벤트 배선 게이트 (CRITICAL)

Stage 6 테트리서에서 같은 상태 객체가 세 라이브 경로 중 일부에만 들어가도
"코드는 살아 있는데 실게임에서는 죽은" 상태가 반복됐다. 새 스테이지/이벤트 상태가
공 충돌, 효과 업데이트, 화면 렌더 중 하나라도 건드리면 아래 3경로를 먼저 봉인한다.

- **ball/update deps:** 공 충돌, 반사, 관통, 파괴처럼 ball loop에서 호출되는 경로.
- **effects/update deps:** 보스 스킬, 상태이상, 면역 게이트, round-scope effect update에서 호출되는 경로.
- **draw scene deps:** actor context / playfield renderer에 데이터가 전달되는 화면 경로.

필수 검증:
- 각 경로는 실제 deps builder와 팬아웃을 통과하는 wiring smoke로 검증한다. state 단위
  메서드 직접 호출만으로는 통과 처리하지 않는다.
- 반증검증은 대상 `case` 또는 dep 주입 줄을 in-place로 잠깐 제거해서 smoke가 실패하는지
  확인한 뒤 복구한다. 이 dirty worktree에서는 `git reset`/`checkout`/`stash`로 되돌리지 않는다.
- 보이는 기능은 "데이터가 렌더러 입력에 도달"과 "픽셀이 실제로 그려짐"을 분리해서 본다.
  actor context smoke가 그린이어도, 가능한 경우 windowed capture / screenshot harness로
  최종 픽셀을 확인한다.

Stage 6 기준 봉인 예:
- `stage6_tetriser_wiring_smoke.gd`: ball / effects / draw deps 경로를 모두 통과.
- draw deps 누락 반증검증: `stage6_tetriser_state`를 draw deps에서 제거하면
  tetromino / guard / wall / center cube actor context 검증이 실패해야 한다.
- 픽셀 확인: windowed capture에서 낙하 테트로미노, 가드 블록, 양쪽 벽 셀, 중앙 큐브가
  모두 화면에 렌더되는지 확인한다.

---

## S1 — 공-deps 배선 (CRITICAL)

### 문제
`_process_stage6_tetromino_collision`는 `deps.get("stage6_tetriser_state")`를 읽는데
([ball_update_controller.gd:526](../godot/scripts/ball/ball_update_controller.gd#L526)),
공-업데이트 deps를 만드는 `_append_stage_update_deps`의 `match current_stage`에는
**case 1~5만 있고 6이 없다** ([ball_dependency_context.gd:404-425](../godot/scripts/ball/ball_dependency_context.gd#L404)).
→ 항상 null → 조기 return → 낙하 테트로/가드/벽/**크리스탈 실드**에 공이 통과.
(crystal shield 충돌도 같은 `resolve_ball_collision` 안에 있으므로 동반 사망 —
[stage6_tetriser_state.gd:564](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L564).)

### 신호 계약
- 공-업데이트 deps dict에 **`deps["stage6_tetriser_state"]`** 키가 존재해야 한다.
- 소비처는 `frame_deps.get("stage6_tetriser_state")` (deps는 `_resolve_stage_deps`가 `deps.duplicate()`만
  하므로 상류에 키가 있으면 그대로 전달됨 — [ball_update_controller.gd:642-655](../godot/scripts/ball/ball_update_controller.gd#L642)).

### 배선 지점
1. **주 경로:** [ball_dependency_context.gd:404 `_append_stage_update_deps` `match current_stage`](../godot/scripts/ball/ball_dependency_context.gd#L404)에
   `6:` 케이스 추가 — `deps["stage6_tetriser_state"] = _get_instance(registry, "stage6_tetriser_state")`.
   (stage5의 [424행](../godot/scripts/ball/ball_dependency_context.gd#L424) 패턴 그대로.)
2. **레거시 경로:** `_append_legacy_stage_update_deps`(legacy update deps,
   [ball_dependency_context.gd:6 참조](../godot/scripts/ball/ball_dependency_context.gd#L6))에도 동일 키 추가
   여부 확인 — 레거시 경로가 살아 있으면 누락 시 같은 사망 재현.

### 회귀 스모크 (필수)
- **`stage6_ball_collision_wiring_smoke`** (신규, 권장):
  - 실제 deps 빌더(`ball_update_context`/`ball_dependency_context`)로 stage 6 deps를 만들고
    `frame_deps.has("stage6_tetriser_state")` AND 비-null 을 assert.
  - **반증검증:** case 6를 in-place로 주석 처리(Edit 토글)했을 때 스모크가 **실패**하는지 확인 후 복원
    (`git reset`/`checkout` 금지 — 메모리 `feedback_workflow_mutating_verify_shared_tree`).
- **`stage6_tetriser_state_smoke`에 통합 충돌 케이스 추가**: `ball_update_controller`를 통해(또는 동일
  deps 경로로) 공을 블록에 떨어뜨려 실제로 반사/파괴되는지 assert. 기존 스모크는 `resolve_ball_collision`을
  직접 부르므로 이 배선 갭을 못 잡았음 — **end-to-end 경로**로 한 건 추가가 핵심.

### 트랩 브리프
- `build_update_deps`는 `(registry, character_type, current_stage)` 키로 **캐시**된다
  ([ball_dependency_context.gd:8-21](../godot/scripts/ball/ball_dependency_context.gd#L8)). case 6 추가는
  스테이지가 캐시 키이므로 안전하나, 캐시 유효성은 stage 전환 시 재빌드됨을 확인.
- `_process_stage6_tetromino_collision`의 `current_stage != 6` 가드는 정상 — 손대지 말 것.

---

## S2 — `reset()` 라이프사이클 배선 (HIGH)

### 문제
`stage6_tetriser_state.reset*` 호출부가 **0개**. (stage5_hongryun_state는 4곳.) 라운드 전환(실점) 시
`reset_round`이 안 불려 이전 라운드의 테트로/가드/벽/실드가 다음 라운드에 잔류·누적된다. 스테이지 이탈은
`update()` 내 self-reset이 늦게 커버하지만([stage6_tetriser_state.gd:216-218](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L216)),
라운드·결과 경로는 미커버. 기획서 §9("단일 reset()을 3경로에서") 미이행.

### 신호 계약
- **라운드 deps**에 `stage6_tetriser_state`가 있어야 cleanup 소비처가 읽을 수 있다.
- `reset_round()` = combat-only(게이지 **persist**, 0으로 만들지 않음 —
  [stage6_tetriser_state.gd:176-179](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L176)),
  `reset_for_result()`/`reset()` = 게이지 포함 전체 0. 이 구분 유지가 핵심.

### 배선 지점 (stage5_hongryun_state 미러)
1. **라운드 deps 추가:** `_build_common_round_deps`
   ([ball_dependency_context.gd:173](../godot/scripts/ball/ball_dependency_context.gd#L173)) 및
   `_build_legacy_round_deps`([:166 stage5 행](../godot/scripts/ball/ball_dependency_context.gd#L166))에
   `stage6_tetriser_state` 추가.
2. **라운드 정리:** [ball_round_actor_cleanup.gd:93-94](../godot/scripts/ball/ball_round_actor_cleanup.gd#L93)
   옆에 stage6 `reset_round()` 추가.
3. **실점/스코어 경로:** [match_score_event_controller.gd:458-459](../godot/scripts/core/match_score_event_controller.gd#L458)
   옆에 stage6 `reset_round()` 추가.
4. **결과/게임엔드:** [stage_clear_result_screen.gd:1006-1007](../godot/scripts/core/stage_clear_result_screen.gd#L1006)
   옆에 stage6 `reset_for_result()` 추가.
5. **풀 리셋 리스트:** [match_reset_controller.gd:198](../godot/scripts/core/match_reset_controller.gd#L198)
   리스트에 `"stage6_tetriser_state"` 추가.

### 회귀 스모크
- **`stage6_round_reset_wiring_smoke`**: 테트로/가드/벽을 채운 뒤 round-reset 경로 호출 → 블록 비었고
  **게이지는 유지**됨을 assert. result 경로 → 게이지까지 0 assert.
- **반증검증:** reset_round 호출을 한 줄 주석 처리 시 "블록 잔류"로 스모크가 실패하는지 확인 후 복원.

### 트랩 브리프
- `reset_round`이 게이지를 0으로 만들면 **라운드 간 persist 규칙 위반**(기획 확정사항). combat-only임을 재확인.
- 라운드-cleanup deps는 `owner == null`로 호출될 수 있음(메모리: 보스-패들 스킬 트랩의 owner-less cancel
  사례). stage6 cleanup이 owner를 요구하지 않는지 확인 — 현 `reset_round()`는 인자 없으므로 안전.

---

## S3 — 착지 폭발/넉백/스턴 + 1.5초 증발 생애주기 (HIGH)

### 문제
원본은 낙하 테트로가 바닥/설치블록에 닿으면 **super → `stage7_tetromino_explode()`(넉백+스턴)**,
**일반 → `installed` → `installed_duration_ms` 후 `evaporating`(셀 단위 증기 해체)**
([pingfighter.py:117301-117328](../pingfighter.py#L117301), [:117340-117368](../pingfighter.py#L117340),
[:117882](../pingfighter.py#L117882)). Godot `_update_falling`은 super/일반 구분 없이 전부 `settled`로만
바꾸고 수명·폭발·넉백·스턴이 전무 ([stage6_tetriser_state.gd:494-507](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L494)).

### 신호 계약 (기존 채널 재사용 — 새 채널 발명 금지)
- **넉백:** `movement_state.start_knockback(direction * speed, frames)` — stage1_balloon_event 패턴
  ([stage1_balloon_event.gd:486-487](../godot/scripts/stages/stage1/stage1_balloon_event.gd#L486)),
  반드시 `_is_player_status_immune(deps, context)` 게이트.
- **스턴:** `status_effect_state.apply_status(...)` — paddle_bounce_boss_post_hit_handler 패턴
  ([paddle_bounce_boss_post_hit_handler.gd:290-294](../godot/scripts/ball/paddle_bounce_boss_post_hit_handler.gd#L290)).
- **deps 확인:** stage6 `update()`가 받는 effects-경로 deps에 `movement_state`(player_movement_state)와
  `status_effect_state`가 있는지 확인. stage1_balloon_event가 같은 effects 경로에서 `movement_state`를
  쓰므로 존재 가능성 높음. 없으면 `_append_stage6_deps`(또는 공통 deps)에 추가.

### 배선 지점 + 수치
- [stage6_tetriser_state.gd:494-507 `_update_falling`](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L494):
  `_would_settle` 참 시 — `super`면 **explode**(블록 제거 + 반경 내 플레이어에 넉백/스턴 + 파편/사운드),
  아니면 **installed**(수명 타이머 시작).
- `settled` 상태에 **수명 카운트다운** 추가: 낙하형 `INSTALLED_DURATION_SEC = 1.5`, 벽은 이미 `_wall_life_sec`로
  6초 처리됨(중복 주의). 만료 시 증발(셀 단위 페이드 권장, 최소 일괄 제거).
- 신규 상수: `EXPLOSION_KNOCKBACK`(원본 12.0, super ×2), `EXPLOSION_STUN_S`(0.5 → super 0.9),
  `EXPLOSION_BASE_RADIUS`(원본 80.0) — 원본 [pingfighter.py:37312-37316](../pingfighter.py#L37312).

### 회귀 스모크
- **super 테트로 착지 → explode**: 블록 제거 + 반경 내 더미 플레이어에 넉백/스턴 적용 assert;
  반경 밖이면 미적용(edge-only 케이스).
- **일반 테트로 착지 → installed → 1.5s 경과 → 제거** assert.
- **반증검증:** explode 분기/수명 카운트다운을 토글 제거 시 "영구 settled"로 스모크 실패 확인.
- **체감 게이트(S1 이후):** 인게임에서 super 블록이 실제로 바닥에서 터지고 플레이어를 밀치는지 1회 육안 확인
  (스모크만으로 종결 금지 — 메모리 `feedback_perf_felt_vs_code_metrics` 정신).

### 트랩 브리프
- **단위 매핑 트랩:** 원본 `knockback=12.0`는 px/프레임 계열, Godot `start_knockback`은 speed+frames 시그니처.
  BALLOON_PADDLE_KNOCKBACK_SPEED 등 기존 상수와 **같은 단위 체계**로 환산할 것(원본 숫자 그대로 꽂지 말 것).
  스턴 0.5/0.9s도 status_effect_state가 frames인지 sec인지 확인 후 변환.
- **settled 누적 트랩:** 현재 settled가 영구라 `MAX_ACTIVE_TETROMINOS=14`까지 쌓임. 수명 추가로 자연 해소되나,
  수명-제거가 큐브 재조립 카운트(`_on_tetromino_destroyed`)를 **잘못 증가**시키지 않도록 분리(증발=자연소멸,
  player/dash 파괴만 카운트 — S5의 큐브 카운트 항목과 연동).
- **freeze 중 폭발 금지:** `_is_timing_frozen`/serve-wait 중에는 update가 'paused'로 빠지므로 착지·폭발이
  안 일어남(정상). 폭발 적용 직전 freeze 재확인은 불필요(이미 상류 게이트).

---

## S4 — 테트리스-feel + 스폰/관통 통합 (MEDIUM)

낙하형 테트로의 **셀스냅 낙하**, **낙하 중 회전**, **벽 테트로 더미**는 모두 `_update_falling` /
조립 / 증발 생애주기를 같이 건드린다. 따로 쪼개면 같은 상태 머신을 반복 수정하므로 S4에서 한 번에 묶는다.
서브 직후 관통과 파워스매시 관통도 같은 `resolve_ball_collision`/벽·테트로 셀 충돌면을 건드리므로 이
슬라이스의 회귀 트랩에 포함한다.

### 신호 계약
- **110ms 셀스냅 낙하:** 원본은 `STAGE7_TETRO_STEP_MS = 110`, `STAGE7_TETRO_CELL_SIZE = 20`
  ([pingfighter.py:116297-116298](../pingfighter.py#L116297))이며, `step_accum`이 110ms를 넘을 때마다
  정확히 20px 한 칸씩 내려간다([pingfighter.py:117176-117189](../pingfighter.py#L117176)).
  Godot의 현재 `TETRO_FALL_SPEED * delta` 연속 이동([stage6_tetriser_state.gd:38](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L38),
  [:620](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L620))은 제거하거나 시각 전용으로 격리한다.
  계약: 각 falling mino는 `step_accum`을 보유하고, `delta < 0.110`에서는 y가 움직이지 않으며,
  0.110초마다 `TETRO_CELL_SIZE`만큼만 이동한다. 큰 delta는 while 루프로 여러 칸 처리하되, 각 칸마다
  착지 판정을 해야 한다.
- **회전 파리티:** 원본은 스폰 시 35% 확률로 `rotate_times_remaining`을 1~2회 부여하고,
  조립 후 0.5~1.2초 지연 뒤 200~340ms 간격으로 회전한다
  ([pingfighter.py:117096-117098](../pingfighter.py#L117096),
  [:117168-117171](../pingfighter.py#L117168), [:117233-117282](../pingfighter.py#L117233)).
  회전 결과가 화면 밖/설치셀/벽과 겹치면 거부하고 횟수를 소모하지 않는다. Godot의 현재 0.45초 주기
  확률 회전([stage6_tetriser_state.gd:41](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L41),
  [:614-616](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L614), [:767](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L767))은
  무제한·무딜레이·무충돌검증이라 대체 대상이다.
  주의: `0.35`/`0.40` 확률값은 원본 스폰 롤과 맞지만, 구현 대상은 "0.45초마다 재롤"이 아니라
  "스폰 시 1회 예산 부여 후 딜레이·간격·충돌검증으로 소모" 모델이다.
- **벽 형상/피격 생애주기:** 벽은 80셀 꽉 찬 직사각형이 아니라, 좌우 각 10개 `wall_generated` 테트로 조각을
  4열 그리드에 중력 적층한 더미여야 한다. 조립 중에는 반투명/비충돌, 조립 완료 후 충돌 활성,
  수명 만료 시 조각별 셀단위 증발. 벽 셀 하나가 맞으면 해당 rect를 소유한 조각 전체가 빠른 증발로 전환되고
  그 조각의 모든 셀이 즉시 충돌에서 빠진다([pingfighter.py:116237](../pingfighter.py#L116237)).
  스모크는 "80셀 solid rectangle"이 아니라 "20조각, 빈틈 있는 실루엣, 조각 단위 피격 증발"을 고정한다.
- **보스중심 스폰 + 5모양:** 원본은 `BOSS.centerx`에서 T/L/Z/I/O 5종
  ([pingfighter.py:117052](../pingfighter.py#L117052), [:117058](../pingfighter.py#L117058)).
  Godot는 화면 x 랜덤 + 7종(S/J 추가) ([stage6_tetriser_state.gd:118-161](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L118),
  [:563-565](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L563)). → 스폰 X를 보스 paddle 중심 기준으로,
  `_shape_keys`를 5종으로 제한(S/J 제외).
- **서브 직후 관통:** 원본 `stage7_ball_penetrates_tetromino = (ball_rally_count==0 and last_hit_by in (boss,""))`
  ([pingfighter.py:170496](../pingfighter.py#L170496), [:170505](../pingfighter.py#L170505),
  [:170594](../pingfighter.py#L170594)). Godot `resolve_ball_collision`에 동일 게이트 추가(컨텍스트의
  rally_count/last_hit_by 사용) → 게이트 참이면 충돌 스킵.
- **파워스매시 관통 파괴:** 원본은 파워스매시 중 반사 없이 셀 증발([pingfighter.py:170599](../pingfighter.py#L170599)).
  Godot는 [ball_update_controller.gd:527-529](../godot/scripts/ball/ball_update_controller.gd#L527)가 무조건 충돌 호출.
  → `power_smashing_parabola_active`([:52](../godot/scripts/ball/ball_update_controller.gd#L52)) 시 stage6
  충돌을 "반사 없이 셀 제거" 분기로 라우팅(또는 resolve_ball_collision에 power-smash 플래그 전달). super도 관통
  파괴 대상임(§2.5).

### 회귀 스모크
- **셀스냅 낙하:** `0.109s` 업데이트 후 y 변화 0, 누적 `0.110s`에서 정확히 +20px,
  `0.220s`에서 +40px를 assert. `TETRO_FALL_SPEED * delta` 연속 이동을 in-place로 되살리면 실패해야 한다.
- **회전 딜레이/횟수/거부:** 강제 회전 예정 mino를 만들고 0.5초 전에는 회전 없음, 유효 회전은 1~2회만 발생,
  설치셀/벽/화면밖과 겹치는 회전은 거부되고 `rotate_times_remaining`이 줄지 않음을 assert.
  충돌검증 또는 횟수제한을 토글 제거하면 실패해야 한다.
- **벽 더미:** 결정 seed로 벽을 스폰해 좌우 각 10조각/총 20조각, 조립 중 draw cell은 보이지만 collidable cell은 0,
  조립 후 collidable cell 활성, solid rectangle이 아닌 빈틈 있는 실루엣, 한 셀 피격 시 소유 조각 전체가
  fast-evaporating으로 빠짐을 assert. 단일셀 삭제/80셀 직사각형 구현을 되살리면 실패해야 한다.
- **스폰/관통:** 스폰 X가 보스 centerx±오차 내이고 모양이 5종 집합인지 assert. rally 0 + boss 서브는 테트로/벽 통과,
  플레이어 반격 후에는 충돌. 파워스매시 공은 테트로/벽/super를 반사 없이 제거.

### 체감/픽셀 게이트
- windowed capture 또는 trace harness로 낙하 y 좌표가 프레임마다 미끄러지지 않고 110ms 간격으로 계단식 이동하는지 확인.
- 회전은 셀스냅 낙하 사이에서 90도 단위로만 바뀌고, 설치셀/벽과 겹친 프레임이 없어야 한다.
- 벽은 양쪽 모두 불규칙 테트로 더미 실루엣이어야 하며, 꽉 찬 4열×10행 판처럼 보이면 실패.

### 트랩 브리프
- **연속낙하 잔재 제거:** `TETRO_FALL_SPEED`를 물리 이동에 계속 쓰면 속도와 손맛이 모두 틀어진다. 보존하더라도
  VFX/문서용으로만 분리하고 falling origin 업데이트에는 쓰지 않는다.
- **스킵 충돌 트랩:** 큰 delta에서 한 번에 40px 이상 이동할 수 있으므로 while 스텝마다 `_would_settle`을 검사한다.
  마지막 위치만 검사하면 설치셀을 터널링할 수 있다.
- **S3 생애주기와 결합:** 셀스냅 착지 판정은 S3의 super explode / 일반 installed+1.5s 증발 분기로 그대로 들어가야 한다.
  자연 증발은 큐브 재조립 카운트를 올리지 않는다.
- **라이브 경로 트랩:** 서브/파워스매시 관통은 smoke가 직접 `resolve_ball_collision`에 값을 주입하는 것만으로 끝내지 말고,
  ball deps/update context의 실제 `rally_count`, `last_hit_by`, `power_smashing_parabola_active` 키가 stage6까지 닿는지
  wiring smoke로 봉인한다.

---

## S5 — 디테일/패리티 (MEDIUM/LOW)

- **가드 1000ms 조립/홀로그램 단계** 미포팅(곧장 320ms 슬라이드) — 원본
  [pingfighter.py:115521-115523](../pingfighter.py#L115521). 조립 페이즈 추가.
- **레이저 발사 조건:** Godot는 일반 초인에서 발사, 원본은 광폭화 전용. 광폭화 미포팅 동안의 의도적 분기로
  둘지(현 상태 유지) 명시 결정 — `docs/stage6_tetriser_port_plan.md §2.9`에 결정 기록.
- **중앙 큐브 재조립 카운트:** Godot는 공-반사 파괴도 +1, 원본은 player/dash만
  ([stage6_tetriser_state.gd:877-882](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L877)). 카운트 소스를
  player/dash 한정으로(S3 증발-제거 제외와 함께).
- **사운드 3종:** `bigtetromino`(super 튕김 [pingfighter.py:170584](../pingfighter.py#L170584)),
  `tetrominoshield`(가드 스폰 [:170713](../pingfighter.py#L170713)), `characterlazer`(레이저). Godot엔
  break/wall/super_roar만 ([game_audio.gd:268-270](../godot/scripts/audio/game_audio.gd#L268)). 자산 복사+배선
  (가드 스폰음·super 튕김음·레이저음). super 튕김음은 S1 이후 super 충돌이 살아야 의미 있음.
- **중앙 큐브 폭발 보상/VFX:** 수류탄식 폭발 + 스타 드롭이 TODO
  ([stage6_tetriser_state.gd:865](../godot/scripts/stages/stage6/stage6_tetriser_state.gd#L865)). 원본 golden(3%) +
  `_maybe_drop_star_for_tetro`([pingfighter.py:117090](../pingfighter.py#L117090), [:117336](../pingfighter.py#L117336)).
  **주의: 스타포인트 단위 트랩**(메모리 `project_godot_starpoint_unit_trap`) — 결과화면 placeholder ★수치를
  collect에 직결 금지. 별도 결산 재화/소량 단위로.
- **크리스탈 실드:** 형성 중 게임정지 없음(원본 ~8.5s) + 라운드마다 초기화(원본 라운드 persist) — 의도/복원 결정.

---

## 6. 관통 트랩 / 공통 주의

- **스모크 = end-to-end 경로 포함.** S1의 교훈: state 단위 스모크가 `resolve_ball_collision`을 직접 부르면
  deps 배선 갭을 못 잡는다. 충돌·리셋·생애주기 스모크는 **실제 deps 빌더/업데이트 경로**를 1건씩 통과시킬 것.
- **반증검증 = in-place 토글만.** 수정 전 코드로 스모크가 실패함을 Edit 토글/임시패치로 증명(`git reset`/
  `checkout`/`stash` 금지 — 미커밋 WIP 파괴).
- **gauge persist 불변식.** S2에서 reset_round은 combat-only. 라운드 간 게이지 유지·스테이지 이탈에서만 0.
- **단위 체계.** S3 넉백/스턴은 Godot 채널 단위(speed/frames)로 환산. 원본 px/프레임 숫자 직꽂 금지
  (메모리 `feedback_godot_ball_vel_pxframe_units` 정신).
- **move-together.** 수치 상수 변경 시 카탈로그/HUD/스모크 동기화(메모리 perf 플레이북 #move-together).

## 7. 범위 밖 (백로그)
- 광폭화(enraged) 트리거 매핑(리그 시스템 부재) — 기획서 §2.9 deferred 유지.
- 3D 배경 큐브 melt(1200)/rebuild(1400) **연출**(로직은 2D 큐브로 흡수됨) — 코스메틱.
- 초인 오라 파티클/테트로 파편/EMP 풀룩 — 코스메틱.
- 로딩/결과 화면 이미지·스킬카드 텍스처(현 절차적).
