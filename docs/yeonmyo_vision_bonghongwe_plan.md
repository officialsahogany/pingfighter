# 연묘 비전 · 봉혼궤 — 비전초식 3번째 구현 계약

스테이지3 환묘 연묘의 보스 스킬 **봉혼궤**(내부 id `curse_chest`)를 플레이어
비전초식으로 이식한다. 기존 2종(달지 연환팽이, 청린귀 지맥진)에 이은 3번째이며,
**보스 AI 상태를 직접 건드리는 첫 비전초식**이다. 앞선 둘은 공 경로 스킬이라
이 문서의 핸드셰이크 계약이 필요 없었다.

정본은 이 문서다. 코드 착수 전 결정은 모두 여기에 기록됐다.

## 0. 라이브 QA 정정 계약 v1.5 (2026-08-12, 최우선)

실제 플레이 결과에 따라 원본 스테이지3 봉혼궤의 **닫힘 → 대시 접촉 개방 → 연기 노출**
메커니즘을 플레이어판에도 유지한다. 이 절은 아래 v1.4 수치·동작 절과 충돌할 경우 항상
우선한다.

- 상자는 포물선으로 날아가 **닫힌 상태**로 착지한다. 착지만으로 가스나 혼란을 발생시키지
  않는다.
- 닫힌 상자는 최대 12초 유지된다. 보스의 대시 이동 선분이 상자 중심 반경 56px에 닿으면
  상자가 열린다. 개방 자체와 혼란 적용은 별개 판정이다.
- 열린 상자는 3초간 연기를 분출하고 2초간 잔향이 사라진다. 이 기간에 보스 중심이 연기
  반경 80px 안에 실제로 들어온 최초 1회에만 혼란 180프레임(3초)을 적용한다.
- 연기 접촉 시 진행 중 대시는 `cancel_dash_without_stun()`으로 끊되 회복 스턴은 붙이지
  않는다. Stage 2 상태 면역 중에는 소비하지 않고, 면역 해제 뒤 연기 안에 있으면 적용한다.
- v1.4의 착지 90프레임 혼란, `base_confusion_pending`, BossAiState 원샷 요청,
  보스 컨텍스트 노출, 드라이버 적용 핸드셰이크는 모두 폐기한다.
- 시각 페이즈는 `throw → closed → open → idle`이다. `throw`는 일정 속도의 지면 투영과
  중력 포물선 높이, 상자 회전·스케일, 이동 그림자를 분리해 무거운 상자를 실제로 던지는
  인상을 만든다. 플레이어와 상자를 잇는 선·밧줄·궤적 테더는 그리지 않는다.
- 열린 뚜껑과 연기 분출이 개방 여부를 명확히 보여야 하며, 닫힌 상자에는 연기를 그리지
  않는다.

## 1. 식별자 (확정 — 개명 금지)

| 종류 | 값 |
| --- | --- |
| 스킬 id | `yeonmyo_vision_bonghongwe` |
| 언락 퍽 id | `unlock_yeonmyo_vision_bonghongwe` |
| 모듈 / state 키 | `yeonmyo_vision_chosik_state` |
| `effect_type` | `yeonmyo_vision_bonghongwe` (스킬 id와 동일 — 비전초식 관례) |
| 표시명 | 연묘 비전 · 봉혼궤 |

⚠️ **에셋 파일명도 이 id를 따른다.** 청린귀는 표시명·아트만 「지맥진」으로 리네임되고
id는 `cheongringwi_vision_dragon_torrent`로 남아, 코드가 `earth_vein_quake` 파일을
참조하면서 `dragon_torrent` 이름의 PNG 3개가 고아로 남았다. 같은 일을 만들지 않는다.
id는 20곳 넘는 하드코딩 키의 소스이고 세이브 호환 식별자다.

## 2. 확정 결정

**공과 상자는 상호작용하지 않는다.** 원본 보스 봉혼궤는 공에 밀리고 흔들리지만
(`curse_nudge_vx`, `curse_wobble_*`), 플레이어판 상자는 보스를 잡는 함정이지 공
장애물이 아니다. → `ball_update_controller` / `ball_frame_motion_controller` /
`ball_motion_event_processor` / `wall_bounce_controller`에 봉혼궤 훅을 추가하지 않는다.
`ball_dependency_context`도 라운드 deps 2곳만 필요하고 update deps는 불필요하다.

**S7 극정호신 봉인은 의도다.** 혼란은 `active_item_flare_confusion_active`로 투영되어
보스의 신규 대시 시작 경로 3종을 모두 막는다 — 일반(`boss_ai_state.gd:787`), 스매셔
허공환영 간파(`:869`), S7 극정호신(`:930`). 출하된 플레어 아이템·바이퍼 신경 타격·
링펫 인형 저주가 이미 동일하게 동작하므로 봉혼궤만 예외를 두면 혼란 계약이
스테이지별로 갈라진다. 이 봉인 효과가 기력 200의 근거 일부다.

**stage6 물음표 부재는 별건이다.** 테트리서 렌더러에 상태 오버레이 호출이 없어
S6에서만 혼란 피드백이 사라진다. 봉혼궤 이전부터 있던 공용 렌더러 커버리지 결함이고
기존 혼란원 3종도 같은 사각이므로 별도 티켓으로 분리한다.

**"보장"은 첫 유효 프레임 1회 적용을 뜻한다.** 적용 이후 새로 시작된 상위 스턴·캐스트·
Stage 2 면역까지 무시하고 누적 90회의 혼란 이동을 보장하려면 별도의 타이머 일시정지
계약이 필요하다. 이번 범위에 포함하지 않는다.

## 3. 수치 계약 (v1.4 기록 — v1.5와 충돌하는 항목은 폐기)

| 항목 | 값 |
| --- | --- |
| 기력 소모 | 200 |
| 기본 쿨타임 | 35초 |
| 상자 지속 | 착지 후 12초 |
| 가스 판정 반경 | 80px (보스판 `SMOKE_RADIUS`와 동일) |
| 착지 기본 혼란 | 90프레임 (1.5초) |
| 대시 교차 보너스 혼란 | 180프레임 (3초) |
| 동시 존재 상자 | 1개 (하드 재시전 차단) |

비교 기준 — 달지 120기력/32초(팽이 2개 7초, 공 ×1.50, 첫 벽반사 ×1.30),
청린귀 250기력/40초.

## 4. 동작 계약 (v1.4 기록 — v1.5가 대체)

### 4.1 시전과 착지

플레이어가 상자를 던진다. 상자는 착지 후 12초 유지되고 소멸한다.
착지 시점에 `base_gas_consumed = true`, `base_confusion_pending = true`로 표시만 한다.

### 4.2 착지 기본 혼란 — 예약 적용

착지 즉시 혼란을 걸지 않는다. **보스가 혼란 이동 분기를 실제로 실행할 수 있는 첫
물리 프레임**에 90프레임 혼란을 소비한다.

게이트 술어는 "대시 중이 아님"이 아니다. 정확히는 다음이다.

> `BossAiState._update_motion()`이 모든 상위 우선순위 분기를 통과하고, Stage 2 상태
> 면역이 아니며, 실제 혼란 이동 분기(`:594`)를 실행할 수 있는 첫 물리 프레임.

구현은 **차단 목록을 봉혼궤 상태에 복제하지 말고, 혼란 분기 바로 앞에서 pending을
소비**한다. 그래야 술어가 정의상 항상 정확하다.

- `stage3_yeonmyo_stationary_cast_active`(`:437`)는 `_cancel_dash_for_stationary_cast()`로
  대시·후딜을 지워 **게이트를 강제로 열면서 즉시 반환**한다. 반드시 예약을 소비하지
  않는다. 트리거가 연묘 본인의 스킬이라 주무대에서 재현된다.
- 스톱워치·DMK·꼭두각시·각종 스턴/넉백/슬립/EMP 등 혼란보다 위에서 조기 반환하는
  모든 분기에서도 예약을 유지한다.
- Stage 2 상태 면역 중에도 유지하고, 면역 해제 후 최초 유효 프레임에 적용한다.
- 득점·라운드 종료가 먼저 오면 예약을 폐기한다.
- 예약은 상자 12초 표시가 끝난 뒤에도 현재 랠리 안에서는 유지된다.

**판정은 매 프레임 레벨 검사다.** 이전/현재 스냅샷 비교나 false 전환 에지를 쓰지 않는다.
S7 극정호신은 후딜이 `SUPERSPEED_DASH_STUN_FRAMES := 1.0`이라 대시 사이클당 열림창이
정확히 1프레임이고, 에지 검출은 그 창을 놓친다.

### 4.3 대시 교차 보너스

보스의 **이전 → 현재 위치 선분**이 상자 판정 반경과 교차하면:

1. `cancel_dash_without_stun()`으로 현재 대시와 후딜을 스턴 없이 종료
2. `base_confusion_pending = false` (기본 예약을 보너스가 흡수)
3. `dash_bonus_consumed = true`
4. 혼란 180프레임을 한 번만 적용

`cancel_dash_without_stun()`은 기존 private `_cancel_dash_for_stationary_cast()`에
위임하는 **공개 래퍼**로 신설한다. `cancel_dash_for_fire_block()`은 0.6초 회복 스턴이
붙으므로 쓰지 않는다. `stage3_yeonmyo_stationary_cast_active` 플래그 자체는 보스 이동을
0으로 묶는 별개 계약이므로 도용하지 않는다.

선분 판정은 **`boss_pos_prev`를 재사용**하고 별도 이전 위치 상태를 만들지 않는다.
`boss_pos_prev`는 `battle_scene_actor_update_driver.gd:129`에서 보스 AI 직전에 기록되고
봉혼궤 update는 `update_player_control`(프레임 순서상 더 앞)에서 읽으므로, 프레임 N+1에
읽는 선분은 (N-1 → N) 구간이다. **한 프레임 뒤처지는 것이 정상이다.** 구간이 연속이라
터널링은 없고, 오히려 이 지연이 보너스 판정을 기본 소비보다 항상 앞세워 경합을 없앤다.

두 소비 플래그는 독립이다. 착지 가스가 대시 보너스 권리를 소비하지 않는다.
상자 하나당 기본 가스와 대시 보너스는 각각 최대 1회.

### 4.4 소비 핸드셰이크

`result` dict에 이벤트 키를 추가하거나 `BattleSceneState.DEFAULT_VALUES`에 전달용 필드를
추가하지 **않는다.** `apply_boss_result`는 `boss_pos` / `boss_vel` 2키만 소비하므로 다른
키는 무에러로 증발하고, owner 경유는 스키마 미선언 시 `owner.set()`이 조용한 no-op이 된다.

| 단계 | 소유자 | 계약 |
| --- | --- | --- |
| 예약 노출 | 봉혼궤 상태 | `get_boss_ai_context()`로 pending bool만 반환 |
| 소비 판정 | `BossAiState` | 혼란 분기 직전 판정, 현재 틱 OR 처리, 원샷 요청 설정 |
| 승인·적용 | 보스 업데이트 드라이버 | 원샷을 읽고 봉혼궤 pending을 원자적으로 내린 뒤 혼란 90프레임 적용 |
| 위치 반영 | 결과 applier | 기존대로 `boss_pos` / `boss_vel`만 |

- 컨텍스트는 `battle_update_boss_ai_context_builder._merge_shared_context()`의 3키 목록에
  배선한다. `_merge_character_context()`는 Viper 전용이다. ⚠️ shared 안에도 `_is_smasher`
  게이트가 있으니 봉혼궤는 **게이트 없이** 넣는다.
- `BossAiState.update()` 시작 시 원샷 멤버를 `false`로 초기화한다.
- 혼란 분기에 실제 도달하고 pending이며 Stage 2 면역이 아닐 때: 로컬
  `consumed_this_update = true`, 원샷 멤버 `true`, 기존 혼란 컨텍스트와 로컬 값을 **OR**하여
  그 틱에 즉시 혼란 이동으로 반환한다. 다음 틱으로 미루면 S7 재대시가 먼저 시작된다.
- 드라이버는 `ai_state.update()` 직후, 날씨 및 결과 적용 **전에** 원샷을 읽는다.
  읽기 API는 `take_*_request() -> bool` 형태로 읽는 동시에 원샷을 내린다.
- 드라이버는 봉혼궤 상태의 무인자 `consume_base_confusion_pending() -> bool`을 호출한다.
  pending일 때만 `true`를 반환하고 pending을 내린다. 그 반환이 `true`일 때만
  `status_effect_state.apply_status(..., 90, ..., 봉혼궤 소스)`를 호출한다.
- 상태나 상태효과 모듈이 없으면 pending을 내리지 않아 다음 프레임 재시도한다.

**90프레임 값을 91로 올리지 않는다.** 프레임 순서가 `update_player_control`(114) →
`update_active_items`(116) → `update_boss_ai`(117) → `update_ball`(134) →
`update_lingpet`(136) → `update_effects`(137)이라, 보스 AI에서 90을 심으면 같은 프레임 끝의
effects가 89로 깎는다. 현재 틱 1회 + 이후 89회 = 실효 90프레임.

### 4.5 혼란 적용 세부

혼란은 공용 `status_effect_state`의 `STATUS_CONFUSION` @ `TARGET_BOSS`로 적용한다.
그래야 AI 교란(`active_item_flare_confusion_active`)과 물음표 오버레이
(`active_item_boss_confusion_active`)가 함께 붙는다. 전용 표시 플래그를 만들지 않는다.

- 소스 키는 봉혼궤 전용 상수 하나로 고정하고, 착지 가스와 대시 보너스가 **같은 소스 키**를
  공유한다. `_build_entry`의 `max(previous.remaining_frames, duration_frames)` 갱신 때문에
  1.5초 위에 3초를 걸면 정확히 3초가 되고 누적되지 않는다.
- ⚠️ 같은 이유로 **단축은 구조적으로 불가능**하다. 조기 종료가 필요하면
  `clear_status(target, status, source)`뿐이다.
- ⚠️ 봉혼궤 혼란 엔트리에 **`pause_while_ball_inactive`를 켜지 않는다.** 라운드 리셋이
  어차피 전 상태를 비우므로 이득이 없고, 서브 대기·전리품 창에서 예상 못 한 동결만 만든다.
  향후 "누적 90회 보장"을 검토할 때는 `status_effect_state._should_pause_entry_timer()`
  (`:479`)를 확장 지점으로 쓰되, 기존 플래그의 의미를 넓히지 말고 **별도 source opt-in
  필드**를 추가한다.
- ⚠️ 기존 보스용 `stage3_curse_chest_state.gd`를 재사용하지 않는다. 그쪽은 4초 후 폭발하고
  플레이어 진영에 떨어져 조작을 2초 반전시키는 **반대 효과**다.

### 4.6 재시전 하드 차단

동시에 존재 가능한 봉혼궤는 1개다. 상자 표시, 가스 꼬리, 기본 혼란 예약 중 하나라도 살아
있으면 재시전할 수 없다. 쿨다운이 0이어도 활성 페이즈가 끝날 때까지 사용 불가이며, 종료
직후 즉시 준비 상태가 된다. (선례: 청린귀 `_can_listen_for_command`가 `phase != "idle"`로
하드 차단. 달지는 `tops.clear()` 교체 방식 — 봉혼궤는 청린귀 모델을 따른다.)

공존하지 않으므로 `base_gas_consumed` / `dash_bonus_consumed` / `base_confusion_pending`은
스킬 상태 전역 필드로 두고, **새 시전 성공 시에만** 초기화한다.

원기탕·즉시보상·캠프파이어·무지개털장갑은 쿨다운만 변경하고 활성 페이즈를 종료하지 않는다.

### 4.7 정리

`reset_round()`:
- 상자와 가스/VFX 제거
- 세 플래그 초기화
- 봉혼궤 소스의 보스 혼란을 `clear_status()`로 제거
- 관련 오디오 중지
- 쿨다운과 이미 지불한 기력은 **유지**

`reset()`은 `reset_round()`를 포함하고 전체 매치용 상태까지 초기화한다.

⚠️ **현재 `match_reset_controller`의 직접 호출은 no-op이다.** `:175-176`에 기존 두 비전
상태 키가 있지만 match-flow deps 빌더 4종 어디도 이를 공급하지 않는다. 세 비전초식 상태를
`battle_update_match_player_skill_deps_builder.gd`에 명시적으로 연결하거나 죽은 직접 경로를
정리한다. 현재는 후속 `reset_ball` → `ball_round_cleanup`이 덮어서 치명적이지 않다.

점수 이벤트에는 **스테이지 게이트가 없는** 비전초식 라운드 정리 훅을 추가한다.
`match_score_event_controller`의 `_clear_stageN_round_boundary_fx` 패밀리와 같은 자리에 둔다.
`reset_ball` 호출 여부에 의존하지 않고, 하이라이트·전리품·결과창 진입 전에 실행한다.
(매치 종료 득점은 `reset_ball`을 거치지 않는다 —
`battle_scene_player_control_config_builder.gd:60-65` 주석 참조. 신규 시전은 `ball_active`
게이트로 이미 봉쇄되므로 소프트락이 아니라 위생 항목이다.)

## 5. 등재 체크리스트

3번째 비전초식을 추가할 때 손대야 하는 하드코딩 지점 전수다. 전부 별도 리터럴이라
**부분 누락이 기본값이고 대부분 무에러**다.

### 5.1 카탈로그 · 획득

**`characters/common_skill_catalog.gd` — 20곳.** const 5종(`:8`, `:13`), 다국어 카피 딕셔너리
7개 언어(`:21`, `:87`), 카피 접근자(`:351`, `:357`), `get_skill_data` 분기(`:207`, `:229`),
언락 퍽 정의 분기(`:273`, `:294`), match 체인 6개(`:363` `is_common_skill` / `:370`
`is_common_unlock` / `:377` / `:384` 스킬id→언락id / `:395` 언락id→스킬id), 쿨감 대상 배열
(`:406`), 그리고 `:414` / `:422` 코스트 / `:430` 색상 / `:438` 쿨다운 맵.
⚠️ `:363` 누락 시 5개 캐릭터 전부에서 장착·코스트·쿨다운 조회가 실패한다(최고 위험).
⚠️ `:229` / `:294` 누락 시 **영혼소환술 데이터가 조용히 반환**된다.
⚠️ `:422` 누락 시 코스트 0 → 무제한 시전. `:438` 누락 시 쿨다운 0.

**`characters/runtime_perk_catalog.gd`** — `:1420` 언락 퍽 주입, `:1643` F4 디버그 엔트리
(`get_unlock_perk_data` → id 세팅 → `debug_group = "vision"` → append).

**`core/victory_loot_phase_state.gd`** — `:36` 상자 시트 경로 const, `:38` 언락id→시트 매핑,
`:493` `if _current_stage == 3:` 분기.
⚠️ `:103`의 `DALJI_VISION_OFFER_CHANCE`는 참조 0건인 죽은 별칭이다. **형제 상수를 만들지
말고** 그 줄은 정리 대상으로 둔다.
⚠️ 상자 시트 PNG는 같은 슬라이스에 랜딩한다. 경로만 예약하고 파일이 없으면 매 프레임
재-stat 트랩에 걸린다.

### 5.2 상태 · 입력 · 수명주기

- `resources/gameplay_actor_module_catalog.gd:76` — 모듈 키 + 스크립트 경로 + label
- `core/battle_update_player_control_deps_builder.gd:89` — deps 공급 (게이트 없이)
- `core/battle_scene_actor_update_driver.gd:39` — `vision_entries` 배열에 3번째 항목
  (⚠️ 누락 시 스킬이 영원히 update되지 않아 발동 자체가 불가)
- `core/battle_scene_update_prewarm_key_sets.gd:48` **및** `:92` — 두 키셋 모두
  (⚠️ 48만 고치고 92를 빠뜨리는 것이 전형적 반쪽 등재)
- `core/match_reset_controller.gd:175`
- `core/battle_update_match_player_skill_deps_builder.gd` — 위 4.7의 no-op 수선
- `ball/ball_dependency_context.gd:204` **및** `:250` — 라운드 deps 2곳
  (⚠️ `_build_legacy_round_deps`가 공통 블록을 호출하지 않고 자체 나열하므로 이중 동기화)
- `ball/ball_round_cleanup.gd:56` — `reset_round()` 호출 3줄
- `core/battle_scene_update_prewarm_driver.gd:294` — **조건부.** 봉혼궤가
  `prewarm_assets_step()`을 구현할 때만
- `core/battle_update_effects_character_deps_builder.gd:36` — **조건부.** 볼/플레이어컨트롤
  경로 밖에서도 매 프레임 전진할 상태가 있을 때만 (청린귀 단독 등재는 `publish_screen_shake`
  소유 차이로 인한 정상 비대칭)

`ball_dependency_context.gd:88`(update deps)와 볼 훅 4파일은 §2 결정에 따라 **추가하지 않는다.**

### 5.3 HUD · 아이콘 · 툴팁

- `hud/runtime_perk_icon_renderer.gd:176` (스킬 오브 아이콘) **및** `:218` (unlock 비급 표지) —
  별도 딕셔너리 2개. `:241` `UNLOCK_ALIASES`는 전용 비급 표지를 만들면 손대지 않는다
- `resources/battle_skill_icon_paths.gd:5` / `:23` / `:41` — 캐릭터별 3벌
- `hud/smasher_skill_orb_slot_renderer.gd` — id const + 아이콘 preload 쌍, `:126` if 체인
- `hud/smasher_skill_orb_symbol_renderer.gd:22` — 절차적 심볼 elif 체인
- `hud/smasher_skill_orb_tooltip_renderer.gd:19` — `COMMON_CONTROL_ROWS`
  (⚠️ 여기 없으면 스매셔 전용 표로 떨어져 세린/호란 장착 시 입력 행이 사라진다.
  마지막 행은 `["accent", "발동"]`으로 닫는다)
- `hud/skill_orb_tooltip_effect_preview_renderer.gd` — `VISION_EFFECT_PREVIEW_TYPES`에 항목 추가
  **및** `_draw_vision_effect_preview` match에 draw 분기 추가.
  ⚠️ set에만 넣고 draw 분기를 빠뜨리면 `push_error`로 씰이 RED가 된다(의도된 가드)
- `stages/stage1/stage1_pillar_hud_scene_drawer.gd:14` — `VISION_STATE_KEYS`
  (추가만 하면 쿨다운/ready 퍼블리시가 전 스테이지에 자동 반영)

### 5.4 쿨다운 외부 간섭

봉혼궤 상태는 다음 3개를 **이름 그대로** 선언한다. 각 본문은 쿨다운 필드 하나만 수정하고
상자·가스·세 플래그·활성 페이즈는 절대 건드리지 않는다.

- `reset_cooldowns()`
- `advance_cooldowns_by_msec(bonus_msec, _time_now = -1)`
- `reduce_all_cooldowns_by_fraction(fraction, _time_now = -1)`

⚠️ **`reset_cooldowns()` 선언 누락은 무에러 데이터 파괴다.**
`items/active_item_regeneration_potion_runtime.gd:44-45`의 `elif has_method("reset")` 폴백이
대신 걸려 활성 페이즈를 통째로 파괴한다. 나머지 3경로는 `has_method` 실패 시 조용한 no-op이라
이 결함은 원기탕 경로에서만 재현되는 비대칭이다.

등재 4곳: `items/active_item_regeneration_potion_runtime.gd:3`,
`characters/runtime_perk_instant_rewards.gd:3`, `items/active_item_campfire_runtime.gd:20`,
`items/mythic_item_rainbow_fur_glove_runtime.gd:140`.

### 5.5 씰 · CI · 에셋 · 문서

기존 씰 갱신: `tests/runtime_perk_debug_picker_tabs_smoke.gd:64`(3번째 항목) `:70`(타 탭
미중복), `tests/active_item_campfire_smoke.gd:11` `:312`,
`tests/active_item_regeneration_potion_runtime_smoke.gd:5` `:174` `:189`,
`tests/actor_update_result_applier_smoke.gd:300`,
`tests/runtime_perk_instant_rewards_smoke.gd:6` `:180` `:201`,
`tests/rainbow_fur_glove_port_smoke.gd:61` `:73` `:95` `:124` `:180`(기대값 4→5) `:189`.

CI 포커스 목록 **2벌 동시** 등재: `.github/workflows/godot-ci.yml`,
`godot/tools/run_pre_push_checks.ps1`. 주석에 락스텝이 명시되어 있고 별개 리터럴 사본이다.

에셋 3계열 + `.import`: 스킬 오브 아이콘(`assets/sprites/skills/`), unlock 비급 표지
(`assets/sprites/perks/`), 전리품 상자 시트(`assets/sprites/result_boxes/`).

`docs/godot_module_ownership_ledger.md`의 `common boss Vision Chosik` 절에 모듈 항목 추가.

### 5.6 넣으면 안 되는 곳

`characters/runtime_perk_unlock_swap_flow.gd:442`와
`characters/runtime_perk_catalog.gd:1710`(`_append_soul_summon_choice`)은 영혼소환술 전용
레인이다. 봉혼궤를 넣으면 오퍼 풀이 오염된다.

## 6. 씰 요건

봉혼궤 전용 씰:

1. 대시/후딜 중 착지 — 혼란 시간이 줄지 않고 예약됨
2. 연묘 stationary cast 중 — 요청 없음, 해제 후 최초 유효 프레임에 요청
3. S7 후딜 종료 다음 프레임 — 90프레임 적용 후 재대시 차단, 같은 틱 혼란 이동
4. Stage 2 상태 면역 — 면역 중 유지, 해제 후 1회 적용
5. 예약 중 대시 교차 — 무스턴 취소 1회, 180프레임 적용 1회, 기본 예약 흡수
6. 실물 `BossAiState`에서 원샷 요청이 정확히 한 번만 `true`
7. 드라이버 처리 후 봉혼궤 pending이 `false`, 다음 프레임 재갱신 없음
8. 쿨다운 강제 초기화(원기탕) 후에도 기존 상자가 있으면 재시전 차단
9. 원기탕 4종 × 활성/비활성 페이즈 — 쿨다운은 변하고 활성 페이즈 필드는 불변
10. 실제 일반 득점과 매치 종료 득점 경로 모두 상자·예약·소스 혼란 제거
11. `boss_pos_prev` 재사용 — 별도 이전 위치 상태를 만들지 않음

⚠️ **씰은 실물 `BossAiState`를 쓴다.** `get_dash_token_snapshot()`은 매 프레임 재사용되는
공유 참조라, 실물을 쓰면 잘못된 에지 검출이 항상 RED로 잡힌다. 공허-GREEN 벡터는 **매 호출
새 Dictionary를 반환하는 Fake**다(`tests/stage1_pillar_scene_prewarm_smoke.gd:37`의
`FakeBossAiState`). Fake 주입 금지.

⚠️ 스냅샷을 보관하지 않는다. 즉시 읽고 버리며, 에지 검출이 필요하면 스킬 자체의 bool 필드로
한다. `boss_ai_state.gd:122-125` 주석의 소비자 목록에 봉혼궤를 추가한다.

## 7. 후속 · 별건

- (2026-08-09 구현 검증에서 추가) 오딘의눈 즉사 득점 경로는
  `battle_scene_item_update_driver._build_odins_eye_death_score_deps`가 자체 deps를
  만들어 비전초식 키가 없다 — 그 경로에서만 §4.7 득점 훅이 무해한 no-op이 되고,
  매치 종료 득점과 겹치는 극단 케이스에서 상자 연출이 결과 화면까지 남을 수 있다
  (위생 수준). 후속으로 그 deps에 키를 추가하거나 허용 예외로 기록.
- (동일) `match_score_event_controller_smoke`의 봉혼궤 레그는 `FakeYeonmyoVisionState`
  주입이라 **훅 호출**은 봉인하지만 **deps 빌더가 키를 공급하는지**는 봉인하지 않는다.
  `battle_update_match_player_skill_deps_builder`에서 키가 빠져도 그 씰은 GREEN이다.
  실 빌더 관통 레그 또는 소스 단언을 후속으로 추가.
- stage6 테트리서 보스 상태 오버레이 부재 (§2)
- `victory_loot_phase_state.gd:103` 죽은 별칭 정리
- 청린귀 id ↔ 에셋 파일명 불일치 + 고아 PNG 3개
- `battle_scene_actor_update_driver.gd:105` `vision_special_gauge_override` 덮어쓰기
  (저우선순위, 봉혼궤 차단 사유 아님)
- 향후 "누적 90회 혼란 이동 보장" 검토 시 `_should_pause_entry_timer()` 확장 (§4.5)
