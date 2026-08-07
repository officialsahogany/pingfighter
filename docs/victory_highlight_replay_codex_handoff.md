# 승리 하이라이트 리플레이 — Codex 핸드오프 (1차 슬라이스)

작성 2026-08-07. 설계 확정 = 사용자 리뷰 2회 반영본.
구현 소유 = Codex. 이 문서가 계약 정본이며, 여기 없는 확장은 2차 슬라이스다.

---

## 0. 목적 / 범위

스테이지 클리어(플레이어 매치 승리) 시, 보스 상자 드랍 **직전**에 그 매치에서
가장 극적인 득점 장면 1~3개를 짧게 재생한다. 클릭/키 1회로 전체 스킵.

```
최종 득점 → 스코어보드(파워로스 진동) → [하이라이트] → 전리품(보스 슬럼프+상자) → 결과화면
                                          ^^^^^^^^^^ 신규
```

**1차 슬라이스 범위**: 플레이어 · 보스 · 공 · 궤적 · 표식.
**2차로 미룸**: 스킬 투사체, 스테이지 기믹, 히트스톱, 카메라 셰이크, 링펫.

### 0.1 기각된 접근 — 원본 화면 캡처

`get_viewport().get_texture().get_image()` 링버퍼는 채택하지 않는다.

- 전투 진입 후 출하 기본값은 Stable Monitor(144Hz 모니터 → 렌더 72 / 물리 72).
  [battle_view_layout.gd:30](../godot/scripts/core/battle_view_layout.gd#L30)의
  `RENDER_FPS_CAP_STABLE_PREFERRED_MAX := 72`가
  [project.godot:16](../godot/project.godot#L16)의 부트 캡 48을 런타임에 덮는다.
- 760×750 RGBA8 = 2.28MB/frame → 1.5초 클립 ≈ **246MB**, 3개면 약 738MB.
- 매 프레임 GPU→CPU 리드백은 파이프라인 스톨. 이 레포는 물리 캐치업 리드로우
  스파이럴 기왕력이 있다.

"불가능"이 아니라 **현재 예산에서 비추천**이며, 대신 아래 스냅샷 리플레이를 쓴다.

---

## 1. 삽입 지점 — 신규 래더 슬롯을 만들지 말 것

승리 래더는 **두 벌**이 존재한다.

- 정규: [battle_scene_match_flow_driver.gd:143](../godot/scripts/core/battle_scene_match_flow_driver.gd#L143)
- 폴백: [match_scoreboard_flow_controller.gd:15](../godot/scripts/core/match_scoreboard_flow_controller.gd#L15)

⚠️ **로직은 한 벌이지만 교체 지점은 2곳이다.** `_try_start_victory_loot_phase`는
함수로 한 번 정의되지만 호출 지점이 둘이다.

- 정규 래더는 `_apply_scoreboard_update_result`에서 **직접 호출**한다
  ([:143](../godot/scripts/core/battle_scene_match_flow_driver.gd#L143)) —
  콜백을 경유하지 않는다.
- 폴백 래더만 `try_start_victory_loot` 콜백 바인딩
  ([:94](../godot/scripts/core/battle_scene_match_flow_driver.gd#L94))을 쓴다.

따라서 `_try_start_victory_presentation` 구현은 **하나로 유지**하되,
**정규 직접 호출과 폴백 바인딩 양쪽을 모두 교체**해야 한다. 한쪽만 바꾸면 그 경로의
승리에서만 하이라이트가 조용히 건너뛰어진다. "단일 인터셉트"가 아니다.

```gdscript
# driver 내부. 콜백 키는 try_start_victory_presentation 으로 개명(폴백 래더 1줄 동반).
func _try_start_victory_presentation(registry, owner, reset_game_callback) -> bool:
    if _try_start_victory_highlight(registry, owner, reset_game_callback):
        return true                 # 하이라이트 종료 콜백이 전리품을 이어받는다
    return _try_start_victory_loot_phase(registry, owner, reset_game_callback)
```

**하이라이트 종료 콜백은 전리품과 동일한 폴백 사다리를 그대로 가져야 한다.**
`_finish_victory_loot_phase`가 `show_stage_clear_result` → `reset_game` 순으로
떨어지는 것과 같이, 하이라이트 종료도 `_try_start_victory_loot_phase` 실패 시
`_show_stage_clear_result` → `reset_game`으로 이어져야 한다. 이걸 빠뜨리면
전리품 시작 실패 시 결과화면에 영영 못 간다(소프트락).

시작 실패(클립 0개, 모듈 부재)는 `false` 반환 → 기존 래더가 그대로 진행.

---

## 2. 모듈 3분할

| 모듈 | 경로 | 책임 |
|---|---|---|
| 기록기 | `res://scripts/core/victory_highlight_recorder.gd` | 링버퍼 샘플링 · 클립 승격 · 극적도 채점 · 선별 |
| 정규화 리졸버 | `res://scripts/core/victory_highlight_actor_resolver.gd` | `actor_context` → `ReplayActorSnapshot` 변환 |
| 재생 상태 | `res://scripts/core/victory_highlight_playback_state.gd` | 타임라인 · 스킵 입력 · 종료 콜백 |
| 전용 렌더러 | `res://scripts/core/victory_highlight_renderer.gd` | 스냅샷만 읽어 그림. registry/deps 접근 금지 |

순서 조정자는 신규 파일 없이 driver의 `_try_start_victory_presentation`이 맡는다.

**라이브 상태를 되감지 않는다.** 재생 중 어떤 런타임 모듈도 과거 값으로
되돌리지 않으며, 렌더러는 저장된 스냅샷 외 아무것도 읽지 않는다.

---

## 3. 정규화 경계 (핵심 계약)

```
stage별 actor_context
        ↓ 실제 build/merge  ← BattleDrawActorContext.build() 최종 반환값
정규화된 ReplayActorSnapshot
(texture / src_rect / dest_rect / flip / tint)
        ↓
전용 하이라이트 렌더러
```

### 3.1 왜 이 경계인가

기록기가 스테이지별 원시 포즈 키를 직접 알면 스테이지가 늘 때마다 기록기가 깨진다.
그리고 [battle_draw_actor_context.gd](../godot/scripts/core/battle_draw_actor_context.gd)에는
같은 이름의 dict가 **두 개** 존재한다 —
[:109](../godot/scripts/core/battle_draw_actor_context.gd#L109) `combined_result_context`
(텍스처 sync용)와 [:818](../godot/scripts/core/battle_draw_actor_context.gd#L818)에서
반환되는 렌더러 대면 `actor_context`. 전리품 페이즈가 앞쪽에만 merge해서 보스가
일반 포즈로 남은 회귀(91bff66ab)가 바로 이 혼동이었다.

**기록기는 `build()`의 최종 반환값만 입력으로 받는다.** 중간 dict 접근 금지.

### 3.2 리졸버 계약

```gdscript
# victory_highlight_actor_resolver.gd
# ⚠️ 반환형 금지 — 매 프레임 중첩 Dictionary를 새로 만들면 "녹화 중 무할당"과
#    정면 충돌한다. 사전 할당된 슬롯에 in-place로 채운다.
static func resolve_into(actor_context: Dictionary, slot: Dictionary) -> bool
# slot 은 링버퍼가 소유한 고정 슬롯. 채우는 필드:
#   slot["player_texture"] : Texture2D   slot["player_src"]  : Rect2
#   slot["player_dest"]    : Rect2       slot["player_flip"] : bool
#   slot["player_modulate"]: Color
#   slot["boss_*"]         : 동일 5필드
# 반환 false = 텍스처 해석 실패 → 그 샘플은 실루엣 폴백으로 표시(슬롯은 재사용).
```

슬롯은 **평면 키**로 잡는다(중첩 dict 금지 — 중첩은 슬롯 재사용 시 내부 dict를
또 만들게 된다).

`actor_context`는 시트 후보를 **여러 키로 동시에** 싣고(`boss_walk_left_sheet`,
`boss_idle_sheet`, `boss_attack_sheet`, `boss_hit_sprite_sheet`, …), 최종 선택은
스테이지 액터 렌더러 안에서 일어난다. 리졸버는 그 선택 로직의 **공용 1벌**이며,
상태 플래그(`boss_is_walking` / `boss_hit_active` / `boss_facing` /
`boss_idle_frame` / `boss_sprite_frame`)와 셀 그리드 상수
(`boss_walk_frame_count` / `boss_walk_grid_cols`)를 읽어 `src_rect`를 만든다.

위치·크기는 이미 최종값이 실려 있다 — `boss_pos`(= `boss_draw_pos`, 파워로스
진동 오프셋 가산 후), `boss_sprite_draw_size`, `boss_visual_center_y_offset`,
`player_pos`, `player_paddle_size`.

**스테이지 탈출구**: 스테이지 렌더러가
`resolve_replay_actor_snapshot(actor_context) -> Dictionary`를 제공하면 그쪽을
우선한다(`has_method` 게이트). 1차 슬라이스는 공용 리졸버만 구현하고 훅은
미구현 — 필요해지는 스테이지가 나오면 2차에서 추가.

⚠️ **커버리지는 검증 대상이다.** 공용 리졸버가 S1~S8 각 보스에서 올바른 시트를
고르는지 Codex가 스테이지별로 확인하고, 실패하는 스테이지는 문서에 기록한 뒤
실루엣 폴백으로 처리한다. "전 스테이지 동작"을 미검증 상태로 주장하지 말 것.

### 3.3 샘플 스키마

⚠️ **스트림이 둘이다.** 드로우 경로 샘플만으로는 물리 이벤트를 정확히 기록할 수
없다 — 한 렌더 프레임 사이에 물리틱이 여러 번 돌면 타격·벽·골이 통째로 누락된다
(렌더 48 / 물리 72 조합에서 실제로 발생).

```
[시각 스트림]  드로우 경로 (build() 반환값 → resolve_into)
  capture_time_sec : float     # ⚠️ 절대 시각. 클립 시작 기준 정규화는 승격 시점에.
  ball_pos         : Vector2
  ball_radius      : float
  player_texture / player_src / player_dest / player_flip / player_modulate
  boss_texture   / boss_src   / boss_dest   / boss_flip   / boss_modulate

[이벤트 스트림]  물리·득점 경로
  capture_time_sec : float     # 같은 시간축
  kind             : int       # player_hit / boss_hit / wall / goal
  pos              : Vector2
```

승격 시 두 스트림을 **같은 시간축으로 결합**하고, 그때 비로소 클립 시작 기준
`t_sec`으로 정규화한다. 링버퍼 안에서는 절대 시각을 유지할 것 — 상대 시각으로
저장하면 evict마다 전 샘플을 다시 써야 한다.

텍스처는 **참조만** 보관한다(복사 없음). 참조 보유는 재생 시점까지 시트가 살아
있음을 보장하는 부수 효과가 있어 바람직하다. 클립은 매치 리셋에서 전량 해제한다.

---

## 4. 기록기

### 4.1 샘플레이트 — 물리틱이 아니라 렌더 프레임

`build()`는 [battle_draw_context.gd:36](../godot/scripts/core/battle_draw_context.gd#L36)
`build_actor_context`를 통해 **드로우 경로**에서 호출된다. 따라서 샘플은 렌더
프레임 레이트로 들어온다(`Engine.physics_ticks_per_second` 아님).

그리고 렌더 캡은 고정이 아니다 — Stable Monitor는 모니터에 따라 60/72/90 등으로
갈리고 사용자가 설정을 바꿀 수도 있다.

⚠️ 그렇다고 "최악값 240Hz"로 잡을 수도 없다. 디스플레이 설정에 Monitor /
Unlimited가 있어 360Hz 이상도 가능하다 — 상한을 하드웨어에 맡기면 안 된다.

**해법: 기록 상한을 두고 시간 게이트로 샘플링한다.**

```
MAX_CAPTURE_HZ  := 120          # 이보다 자주 들어오는 프레임은 건너뛴다
MAX_RECORD_SEC  := 2.0
CAPACITY        := MAX_CAPTURE_HZ * MAX_RECORD_SEC + margin   # 고정, 1회 사전 할당

- 드로우 프레임마다: now - last_capture < 1/MAX_CAPTURE_HZ 면 return (샘플 스킵)
- 링버퍼는 append / pop_front 를 쓰지 않는다 —
  고정 배열 + head / write_index / count 를 이동시키는 순수 인덱스 연산
- evict = head 전진뿐(원소 삭제 없음). 슬롯은 재사용된다.
```

재생 길이는 여전히 타임스탬프 보간이라 캡처 레이트와 무관하게 일정하다.
120Hz 상한은 1.1초 클립에서 132샘플 — 시각적으로 충분하다.

`MAX_RECORD_SEC := 2.0`. 클립 본편은 1.1초 이하지만, "마지막 플레이어 타격"이
그보다 앞설 수 있으므로 여유를 둔다.

**녹화 중 할당 0**이 계약이다. `resolve_into`(§3.2)로 슬롯을 in-place 갱신하고,
승격 시점에만 구간을 복사한다. 이벤트 스트림도 같은 방식의 고정 링이다.

### 4.2 클립 승격

훅 = [match_score_event_controller.gd:11](../godot/scripts/core/match_score_event_controller.gd#L11)
`handle_score_event`의 `scoring_side == "player"` 분기. 득점 판정 자체는
[match_score_state.gd:73](../godot/scripts/core/match_score_state.gd#L73) `score_for`
단일 지점이다.

클립 구간 = **마지막 플레이어 타격 −0.2초 ~ 골 통과 +0.25초(짧은 정지)**.
그 시작점이 버퍼 밖이면 버퍼 선두부터.

⚠️ **골 +0.25초 프레임은 승격 시점에 아직 존재하지 않는다.** 득점 훅은 골이 난
그 프레임에 돌기 때문이다. 미래 샘플을 기다리지 말고 **마지막 샘플을 0.25초 유지하는
합성 홀드**로 정의한다(정지 프레임 + 표식 표시 구간으로도 그 편이 낫다).
"뒤 0.25초를 더 녹화한다"는 설계는 채택하지 않는다 — 득점 직후 프레임은 이미
스코어보드 상태로 넘어가 시각적으로 다른 화면이다.

### 4.3 극적도 지표

일부는 기존 런타임에 있고, 일부는 **기록기가 직접 계산해야 한다**.

| 지표 | 출처 |
|---|---|
| 랠리 길이 | [ball_intensity.gd:124](../godot/scripts/ball/ball_intensity.gd#L124) `get_rally_count()` — 기존 |
| 매치포인트 / 듀스 | `match_score_state.would_score_finish` / `deuce_mode` — 기존 |
| 마지막 타격 주체·기술 태그 | 볼 업데이트 컨텍스트 — 기존 |
| 골 시점 공 속도 | **기록기가 샘플에서 산출**(득점 컨트롤러로 전달되지 않음) |
| 보스 패들 근접 통과 거리 | **기록기가 샘플에서 산출**(어디에도 기록되지 않음) |

공속 단위는 px/frame이다(base 7.65 / 캡 26) — 초당 값으로 오해하지 말 것.

### 4.4 선별 — 종류 분리 (가중치 상위 3개 아님)

1. **최종 결정타** — 매치를 끝낸 골. 무조건 포함(보장 1개).
2. **가장 긴 랠리** — `rally_count` 최대. 임계 미달이면 채택 안 함.
3. **한 자리 경합** — 기술 결정타 / 근접 통과 / 역전 동점골 중 최고 1개.

최종 1~3개 가변. 2·3번은 각자 임계를 넘겨야 채택되므로 평범한 승리에서는 1개만
나온다. 재생 순서는 시간순.

---

## 5. 재생

### 5.1 타임라인

- 클립당 **0.75~1.1초**, 전체 **2.8~3.2초** 상한(전환 포함).
- 클립 사이 짧은 전환(교차 페이드 또는 먹선 와이프) 0.12초.
- 골 통과 후 짧은 정지 후 다음 클립.

### 5.2 프레임 게이트

[battle_frame_flow_controller.gd:31](../godot/scripts/core/battle_frame_flow_controller.gd#L31)의
전리품 분기 **위**에 하이라이트 분기를 추가한다. 전리품보다 더 강하게 동결한다.

```gdscript
# 재생 중: 재생 상태 갱신 + redraw 만.
# update_player_control / update_active_items / update_ball / update_boss_ai /
# update_lingpet / update_effects 전부 호출하지 않는다.
```

전리품과 달리 플레이어 조작도 막는다(스펙: 플레이어·공·보스 AI·액티브 아이템 정지).

deps 등재 필수 — [battle_frame_flow_deps_builder.gd:40](../godot/scripts/core/battle_frame_flow_deps_builder.gd#L40)에
전리품이 등재된 것과 같은 자리. ⚠️ 빠지면 게이트가 **항상 false인 공허**가 된다
(퍽 모달이 정확히 이 함정을 밟은 적 있음 — 스모크는 키를 직접 주입해 GREEN).

### 5.3 그리기

#### 클리핑 — 전용 fx 호스트 필수 (배틀 캔버스 직접 draw 금지)

⛔ **immediate `_draw`는 자동 클리핑되지 않는다.** 게임 좌표계에서
`(game_offset, render_scale)` 캔버스 transform을 쓰는 오버레이는 **반드시**
`clip_contents = true`인 Godot Control 안에서 그려야 한다. 호출 체인 어디서든
`draw_set_transform(IDENTITY)` 리셋이 한 번만 일어나면 이후 draw가 화면 절대
좌표로 떨어져 레터박스 필러로 샌다. 정본 = [AGENTS.md §471](../AGENTS.md#L471).

레퍼런스 구현을 그대로 따를 것 — `stage_ball_spawn_intro_fx_host.gd`가
`_playfield_clip` Control + 드로우 브리지를 소유하고, 대응하는 lifecycle 모듈은
배틀 씬 캔버스에 `_draw_*(canvas)`를 **의도적으로 호출하지 않는다**.

- 클립 Control: position `Vector2.ZERO`, size = GAME_SIZE(760x750),
  `clip_contents = true` (fx-host-local 공간 기준).
- ⚠️ 레거시 80px 필러 인셋(x=80..680)으로 좁히지 말 것 — 실제 플레이 픽셀이
  잘리고 누수도 안 막힌다. 클립은 **풀 게임 캔버스**와 일치해야 한다.
- 호스트는 자체 `_process()`를 두지 않는다. 재생 상태가 갱신을 주도하고,
  **종료 · F9 직행 · 매치 리셋 각각에서 호스트를 명시적으로 숨기고 해제**한다.
  (자체 process를 두면 프레임 게이트 밖에서 계속 돌아 동결 계약이 깨진다.)

#### 레이어 순서

1. **불투명 먹색 재생판** `Rect2(0, 0, 760, 750)`.
2. 궤적 — 적금색, 꼬리로 갈수록 페이드.
3. 액터 스냅샷 2개(`draw_texture_rect_region`).
4. 표식 — 짧은 라벨 + 클립 인덱스 점.

⚠️ **반투명 스크림 + 라이브 액터 존치는 1차에서 채택하지 않는다.** 라이브 액터는
동결된 **현재** 위치에 있고 리플레이 액터는 **과거** 위치에 있어, 반투명이면 둘이
겹쳐 보인다(보스가 둘로 읽힘). 1차는 완전 불투명 재생판으로 라이브 씬을 덮는다.
반투명으로 가려면 **라이브 액터 드로우 억제 계약**을 별도로 추가하고 픽셀 QA를
통과해야 한다 — 시각 검증 전에 "억제 불필요"를 확정하지 말 것.

### 5.4 입력 (스킵)

클릭 또는 아무 키 1회 → **현재 클립이 아니라 전체 하이라이트 스킵** → 즉시 종료
콜백. 재생 시작 직후 ~0.15초는 입력을 먹지 않는다(득점 순간의 잔여 클릭이 바로
스킵시키는 것 방지).

**배선 위치** = [battle_scene_input_controller.gd:37](../godot/scripts/core/battle_scene_input_controller.gd#L37)
`handle_unhandled_input`의 라우터 체인. 순서:

```
_system_shortcut_input_router          (기존 — 전체화면/BGM 토글)
  ↓
[하이라이트 입력]  ← 여기. 재생 중이면 이벤트를 소비하고 return
  ↓
_handle_mobile_touch_input / _pre_intro_stage_input_router / 전투 입력 (기존)
```

시스템 단축키 **다음**, 모바일·전투 입력 **앞**에 넣고 이벤트를 소비한다.
⚠️ **F9(`FORCE_STAGE_CLEAR_KEY`)만 예외로 흘려보낼 것** — F9 핸들러는 체인
아래쪽 `_pre_intro_stage_input_router`에 있어서, 하이라이트가 무조건 소비하면
기존 결과화면 직행 치트가 막힌다.

### 5.5 오디오

- **원본 게임 오디오를 재발화하지 않는다.** 저장된 이벤트로 타격음을 다시
  울리면 라이브 상태와 어긋난 소리가 난다.
- 전용 음향만: 클립 전환 휙 소리 + 결정타 충격음 1회.
- 진입 시 `GameplayLoopAudioCleanup.stop_all` 경유.
  ⚠️ 단, 정상 득점은 이미
  [match_score_event_controller.gd:198](../godot/scripts/core/match_score_event_controller.gd#L198)
  `_play_score_audio` → `_stop_score_audio_loops`에서 루프를 정리한다. 하이라이트가
  할 일은 **그 이후의 재무장 방지**와 재생 전용 음향 정리다. 중복 정리 자체는 무해.
- 파워로스 럼블(stage2 quake 루프)의 종료 엣지는 driver
  [:135](../godot/scripts/core/battle_scene_match_flow_driver.gd#L135)
  `_stop_victory_power_loss_rumble`이 이미 소유 — 하이라이트가 그 앞에 끼어드는
  것이 아니라 뒤에 오므로 순서 영향 없음. 확인만 할 것.

---

## 6. 배선 체크리스트

| # | 파일 | 작업 |
|---|---|---|
| 1 | `scripts/resources/gameplay_core_module_catalog.gd` | 신규 모듈 4개 등록 ([:188](../godot/scripts/resources/gameplay_core_module_catalog.gd#L188) 전리품 항목이 형식 참고) |
| 2 | `scripts/core/battle_scene_state.gd` | `DEFAULT_VALUES`에 `victory_highlight_active: false` 선언 — ⚠️ 미선언 키는 `owner.set()`이 **조용한 no-op** ([:36](../godot/scripts/core/battle_scene_state.gd#L36) 참고) |
| 3 | `scripts/core/battle_frame_flow_deps_builder.gd` | 재생 상태 등재 |
| 4 | `scripts/core/battle_frame_flow_controller.gd` | 전리품 분기 위에 하이라이트 분기 |
| 5 | `scripts/core/battle_scene_match_flow_driver.gd` | `_try_start_victory_presentation` + 종료 콜백 폴백 사다리 |
| 6 | `scripts/core/match_scoreboard_flow_controller.gd` | 콜백 키 개명 1줄 |
| 7 | `scripts/core/match_score_event_controller.gd` | 플레이어 득점 시 클립 승격 훅 |
| 8 | `scripts/core/battle_draw_context.gd` 또는 드로어 | `build()` 반환값을 기록기에 전달(드로우 경로 1회/frame) |
| 9 | `scripts/core/battle_playfield_scene_drawer.gd` + 신규 fx 호스트 | 재생 드로우 훅. ⚠️ 캔버스 직접 draw 금지 — `clip_contents` 호스트 경유(§5.3) |
| 9b | `scripts/core/battle_scene_input_controller.gd` | [:37](../godot/scripts/core/battle_scene_input_controller.gd#L37) 라우터 체인에 스킵 입력 삽입(시스템 단축키 뒤, 모바일/전투 앞). **F9는 통과** |
| 10 | `scripts/core/battle_update_match_state_deps_builder.gd` | 등재 → `match_reset_controller`가 리셋 ([:9](../godot/scripts/core/battle_update_match_state_deps_builder.gd#L9) 참고) |
| 11 | `scripts/core/battle_scene_player_control_config_builder.gd` | 필요 시 `ball_active` 게이트에 하이라이트 플래그 fold ([:68](../godot/scripts/core/battle_scene_player_control_config_builder.gd#L68) 참고) |

**F9 치트**는 전리품을 건너뛰고 결과화면 직행이다(의도된 부스/디버그 동작).
하이라이트도 동일하게 건너뛰어야 한다.

---

## 7. 이 레포 기왕 함정 (전리품 페이즈가 실제로 밟은 것)

1. **렌더러 대면 dict 누락** — §3.1. 씰은 소스 문자열이 아니라 실제 `build()`
   반환값을 관통해야 한다.
2. **deps 빌더 미등재로 게이트가 항상 false** — §5.2. 스모크가 키를 직접 주입하면
   공허 GREEN.
3. **owner 스키마 미선언 `set()` no-op** — §6 #2.
4. **match_reset 미등재** — 활성 하이라이트가 다음 매치 프레임플로우를 하이재킹.
5. **모달 중첩** — 재생 중 신화 시네마틱 / 퍽 선택이 열릴 일은 없어야 하지만
   (하이라이트가 보상보다 앞), 전리품처럼 방어 분기를 넣을지 확인.
6. **스모크 공허 GREEN** — typed 객체에 미선언 프로퍼티 대입은 그 레그 함수만
   중단시키고 러너는 `ok`를 찍는다. 표준 러너 `run_smoke_tests.ps1` 관통 필수.

---

## 8. 씰 (스모크)

**씰은 2벌로 나눈다.** 한 파일에 섞으면 헤드리스 배치가 픽셀 레그 때문에 통째로
불안정해지고, 반대로 픽셀 레그가 구조 레그에 묻혀 SKIP이 PASS로 읽힌다.

| 파일 | 실행 환경 | 범위 |
|---|---|---|
| `tests/victory_highlight_replay_smoke.gd` | 헤드리스(표준 러너 락스텝) | 구조·계약·게이트 (§8.1) |
| `tests/victory_highlight_replay_clip_pixel_qa.gd` | **비헤드리스 전용 래퍼** | 실제 렌더 클립 픽셀 (§8.2) |

⛔ **픽셀 파일 이름은 `*_smoke.gd`가 아니어야 한다.**
[run_smoke_tests.ps1:24](../godot/tools/run_smoke_tests.ps1#L24)는 `-Tests` 인자가
없으면 `tests/*_smoke.gd`를 **글롭으로 전량 자동 수집**하고,
[:44](../godot/tools/run_smoke_tests.ps1#L44)에서 **항상 `--headless`**로 돌린다.
`run_pre_push_checks.ps1` 전체 실행도 같은 글롭을 탄다. 즉 목록 등재 여부와 무관하게
파일명만으로 끌려 들어가므로, `*_smoke.gd` 이름으로 헤드리스 비-0 종료를 하면
**전체 스모크 배치가 항상 RED**가 된다. `_qa.gd` 접미사로 글롭 밖에 둘 것.

전체 라이브 QA(액터 포즈·표식 텍스트·속도·미감)는 씰이 아니라 별도 항목으로 유지.

### 8.1 헤드리스 구조 씰 — 최소 레그

1. **정규화 관통** — 실제 `BattleDrawActorContext.build()` 반환 dict → 리졸버 →
   렌더러 입력까지. 픽스처는 스테이지 픽스처를 실제로 태울 것(소스 단언 금지).
2. **레이트 불변** — 60Hz / 72Hz / 90Hz 샘플 시퀀스를 넣어 재생 길이가 동일함.
3. **링버퍼 시간 evict** — `MAX_RECORD_SEC` 초과분이 빠지고 할당이 늘지 않음.
4. **선별 종류 분리** — 평범한 승리 = 1개(결정타만), 장기랠리+역전 있는 승리 = 3개.
5. **래더 인터셉트 — 두 경로 각각** ⚠️ 정규(직접 호출)와 폴백(콜백 바인딩)을
   **별개 레그로** 태울 것. 한 경로만 통과해도 GREEN이 되면 §1의 결함을 못 잡는다.
   종료 후 전리품 → 전리품 실패 시 결과화면까지 이어지는 폴백 사다리 레그 포함.
6. **2스트림 결합** — 렌더 프레임 사이에 물리 이벤트가 2회 이상 들어간 픽스처에서
   타격/골이 누락되지 않음. ⚠️ 렌더=물리 1:1 픽스처는 이 결함을 못 잡는다.
7. **합성 홀드** — 득점 훅 시점에 미래 샘플이 없어도 골 뒤 0.25초 정지가 생성됨.
8. **무할당** — 랠리 N초 녹화 전후로 링버퍼 배열 크기가 불변이고 슬롯이 재사용됨.
   `MAX_CAPTURE_HZ` 초과 프레임이 스킵되는 것도 함께 단언.
9. **클립 호스트 구조** — 호스트 부모 관계, `clip_contents = true`, rect가 풀 게임
   캔버스(760x750)와 일치, lifecycle(종료·F9·매치리셋에서 숨김/해제).
   ⚠️ 이 레그는 **실제 클립을 증명하지 못한다** — §8.2가 본체다.
10. **F9 통과** — 재생 중 F9가 하이라이트에 소비되지 않고 결과화면 직행에 도달.
11. **프레임 게이트** — 재생 중 `update_ball` / `update_boss_ai` /
    `update_player_control`이 호출되지 않음(콜백 카운트 단언).
12. **스킵** — 1회 입력이 전체를 종료. 진입 직후 0.15초 무시창.
13. **리셋** — 매치 리셋 · 종료 · F9 각각에서 클립·텍스처 참조 전량 해제,
    **fx 호스트 숨김/해제**, `owner` 플래그 false.

### 8.2 비헤드리스 클립 픽셀 씰 — **1차 완료 조건 (필수)**

구조 씰만으로 1차를 넘기지 말 것. 이건 미관 검사가 아니라 이 레포에서 **이미
회귀가 발생한 좌표·클리핑 계약**이다. 선례
[smasher_plasma_clip_letterbox_pixel_smoke.gd:3](../godot/tests/smasher_plasma_clip_letterbox_pixel_smoke.gd#L3)이
"구조 GREEN인데 픽셀 클립은 실패"(`CLIP_CHILDREN` 마스크 사례)를 명시하고 있다.

범위는 **격리 호스트 10여 프레임 렌더**면 충분하다 — 풀매치 캡처 불필요.

**최소 합격 조건**

| # | 조건 |
|---|---|
| 1 | `game_offset != Vector2.ZERO` (0이 아닌 오프셋) |
| 2 | `render_scale != 1.0` (1.0이 아닌 배율) |
| 3 | clip **OFF** 대조군에서 좌·우 레터박스 누출 픽셀 **> 0** (누출 감지 능력 증명) |
| 4 | clip **ON**에서 좌·우 레터박스 누출 픽셀 **== 0** |
| 5 | 플레이필드 **내부**에 실제 하이라이트 픽셀 **> 0** (빈 화면 통과 방지) |
| 6 | 게임 x=0~80 / x=680~760 **내부** 표본도 lit — 레거시 80px 인셋 오적용 반증 |
| 7 | 비헤드리스인데 뷰포트 이미지를 못 얻으면 **fail-closed**(성공 종료 금지) |

조건 3은 대조군이다 — 이게 없으면 "아무것도 안 그려서 0"이 통과한다.
조건 6은 §5.3의 "80px 인셋으로 좁히지 말 것"을 실측으로 봉인한다.

**실행 계약 (러너 글롭과 공존)**

- 파일명 `victory_highlight_replay_clip_pixel_qa.gd` — `*_smoke.gd` 글롭 밖.
- **구조 씰만** 표준 헤드리스 러너와 CI 락스텝에 등재한다.
- 픽셀 QA는 **전용 비헤드리스 실행 래퍼**에서만 돌린다(`--headless` 금지).
- 래퍼의 판정 규약:
  - 명시적 `victory_highlight_replay_clip_pixel_qa: ok` 마커를 **요구**한다.
    마커가 없으면 실패.
  - 캡처 실패(뷰포트 이미지 없음) → **비-0**.
  - 헤드리스 오실행 감지 → **비-0**(마커 출력 금지).
  - **미실행 · 디스플레이 부재를 PASS로 보고하지 않는다.**

⚠️ 선례 파일
[smasher_plasma_clip_letterbox_pixel_smoke.gd:31](../godot/tests/smasher_plasma_clip_letterbox_pixel_smoke.gd#L31)은
헤드리스에서 `skipped` 뒤 `ok`+`quit(0)`을 찍는데, 이는 **자동 글롭과 공존하려는
구조**이지 증명력이 있어서가 아니다. **복사하지 말 것.** 이 문서의 계약은
"글롭 밖 파일명 + 전용 래퍼"로 그 타협 자체를 없앤다.
(기존 플라즈마 씰 정리는 별건으로 남긴다.)

프로브 규약(선례와 동일): `clear_color` 검정 + 밝은 픽셀만 계수 + 다른 FX 호스트
`free`. 좌표 환산은 `get_global_transform_with_canvas()` 경유.

### 8.3 라이브 QA (씰로 대체 불가)

액터 포즈 정합, 표식 텍스트 가독·번역, 재생 속도 체감, 전환 미감, 3클립 시퀀스의
전체 리듬. 스테이지 1 / 5 / 7 각 1판.

**반증검증(SAFE)**: 각 레그가 수정 전 코드에서 RED임을 in-place Edit 토글 /
임시 패치 / 픽스처로 증명한다. ⚠️ `git reset` / `checkout` / `stash` **절대 금지**
— 이 레포는 미커밋 WIP가 대량이라 파괴적이다.

---

## 9. 2차 슬라이스 (이번 범위 아님)

- 스킬 투사체 / 검기 / 오브
- 스테이지 기믹(테트리스 블록, 화염, 모래 등)
- 히트스톱 · 카메라 셰이크 재현
- 링펫 / 수호령
- 스테이지별 `resolve_replay_actor_snapshot` 훅
- 옵션 메뉴 on/off 토글

---

## 10. 결정 상태

**확정**: 순서(하이라이트 → 전리품), 1차 범위, 정규화 경계, 전용 렌더러,
1~3개 가변 + 결정타 보장, 클립 0.75~1.1초 / 전체 2.8~3.2초, 전체 스킵,
전용 오디오, 라이브 되감기 금지.

**2026-08-07 리뷰 반영 확정 5건**: 인터셉트 교체 지점 2곳(§1) · 시각/이벤트
2스트림 + 합성 홀드(§3.3 / §4.2) · `resolve_into` 무할당 계약과
`MAX_CAPTURE_HZ := 120`(§3.2 / §4.1) · `clip_contents` fx 호스트 + 불투명
재생판(§5.3) · 입력 라우터 배선과 F9 통과(§5.4 / §6-9b).

**미결 4건도 확정**:
- **전환** = 1차는 **0.12초 교차 페이드**(먹선 와이프는 2차 재검토).
- **표식** = **localization key**로 만들고 **7개 언어 락스텝**. 하드코딩 한국어
  문자열 금지.
- **팔레트** = [runtime_perk_traditional_chrome.gd](../godot/scripts/hud/runtime_perk_traditional_chrome.gd)의
  `LACQUER_BLACK`([:8](../godot/scripts/hud/runtime_perk_traditional_chrome.gd#L8)) ·
  `SEAL_RED`([:17](../godot/scripts/hud/runtime_perk_traditional_chrome.gd#L17)) ·
  `BRASS_LIGHT`([:11](../godot/scripts/hud/runtime_perk_traditional_chrome.gd#L11))
  **재사용**. 색값 하드코딩 금지 — 리스킨 때 갈린다.
- ⛔ **스테이지별 커버리지 표는 폐기됐다.** 초판에 실렸던
  "S1·S2·S3·S5=실시트 / S4·S6·S7·S8=실루엣" 표는 **측정이 아니라 추정**이었고
  라이브 QA가 **양방향으로 반증**했다(§11.0). 커버리지는 스테이지 단위가 아니라
  **포즈·계약 단위**로만 문서화한다 — §11.1을 정본으로 삼을 것.
  §3.2의 "미검증 상태로 전 스테이지 동작을 주장하지 말 것"이 지켜지지 않은
  사례이므로, 앞으로 커버리지 진술은 **실측 근거와 함께**만 적는다.

---

## 11. 라이브 QA 후 1차 재보정 — **Codex 작업지시 (2026-08-07 확정)**

S1·S5·S7 라이브 QA 결과: **플로우·스킵·페이싱·클립 개수·레터박스·다국어는 전부
통과**. 렌더 보정 2건만 남았고, 그것을 닫으면 1차 완료 + 커밋이다.

구현 소유 = Codex. 리졸버·렌더러·씰·문서를 **한 주체가 함께** 고친다.

### 11.0 관측된 결함 (근거)

| # | 증상 | 근거 |
|---|---|---|
| P1-a | S5에서 홍련 대신 **다른 보스(파란 뿔) 시트** 출력 | `.godot/codex_logs/s5_video/h_10_0.png` |
| P1-b | S5 홍련이 맞게 나와도 **머리만 상단에 걸림** | `.godot/codex_logs/s5_en_single_click_proof/before_click_14.735_n745.png` |
| P1-c | 보스가 제목/부제 침범, 플레이어가 스킵 문구와 겹침 | `.godot/codex_logs/s1_video_postwin/h_29_0.png` |
| 문서 | S7은 실루엣이라 적혔으나 **실제로는 풀컬러 출력** | 라이브 관측 |

**근본 원인 (실측 확인)**

1. `actor_context`가 싣는 보스 그리드 메타데이터는
   **`boss_walk_frame_count` / `boss_walk_grid_cols` 둘뿐**이다. idle·attack·
   dash·quake용 그리드 키는 **존재하지 않는다**.
2. 그럼에도 `victory_highlight_actor_resolver._resolve_boss`는
   `frame_count := 16 / grid_cols := 4 / grid_rows := 4`를 기본값으로 두고
   **`boss_is_walking` 분기에서만** 실제 값으로 덮는다. 나머지 분기는 16/4/4를
   그대로 쓴다 → 4x2 시트에서 `cell_height`가 절반이 되어 셀 상단만 dest 전체로
   늘어난다(= P1-b "머리만").
3. 분기가 고른 시트 키가 null이면 **무검증 `boss_sprite_sheet` 폴백**으로
   떨어진다. 여기에 다른 스테이지 보스가 들어 있으면 그대로 그린다(= P1-a).
   분기 조건 의존이라 **실행마다 달라진다**.
4. `scripts/stages/stage5/`에는 `boss_idle_sheet` / `boss_attack_sheet` 소비가
   **없다** — S5는 초판 표가 주장한 "실시트 해석 대상"이 아니었다.

### 11.1 1차 범위 (확정, 이 밖은 2차)

**리졸버 — A안(계약 있는 것만 해석)**

- **계약이 확인된 `walk`만 실시트로 해석**한다(그리드 메타데이터가 컨텍스트에
  실제로 존재하는 유일한 포즈).
- **비-walk 포즈**(idle · attack/hit · dash · quake_stomp)와 **그리드 메타데이터
  부재**는 전부 **실루엣 폴백**.
- ⛔ **`boss_sprite_sheet` 맹목 폴백 삭제.** 잘못된 보스를 그리는 것은 실루엣보다
  나쁘다. 시트 키가 null이면 `false`를 반환해 실루엣으로 간다.
- 플레이어 측도 같은 원칙을 적용한다 — 그리드 상수를 컨텍스트에서 못 얻는
  분기는 실루엣.

**렌더러 — 콘텐츠 밴드 일괄 변환**

- ⛔ **개별 액터 클램프 금지.** 공·패들·보스의 상대 위치가 깨지면 리플레이의
  의미가 사라진다.
- 760x750 원본 좌표계를 **y=118~678 콘텐츠 밴드**로 **균일 스케일 + 오프셋**
  변환한다(장식선 `_draw_frame`이 이미 그 밴드를 긋고 있으므로 상수를 공유).
- **공 · 궤적 · 패들 · 액터 · 이벤트 표식 전부 동일 변환**을 통과한다.
  하나라도 빠지면 그 요소만 어긋난다.
- 변환은 **draw 시점**에만 적용한다 — 기록기·리졸버·저장된 클립 포맷은 불변.

**문서**

- 스테이지별 커버리지 표 **삭제**(§10에 반영 완료). 대신 **실제 검증된
  포즈/계약 단위**로 기술한다.

### 11.2 씰 (필수 6종)

`victory_highlight_replay_smoke.gd`에 추가:

1. **4x2 비-walk 시트가 실시트로 잘못 해석되지 않음** — 그리드 계약이 없는
   포즈는 실루엣으로 간다(P1-b 봉인).
2. **선택 시트가 null이어도 `boss_sprite_sheet`로 누출되지 않음**(P1-a 봉인).
3. **공·패들·액터 사이 상대 거리 비율이 변환 전후 동일**(균일 변환 봉인 —
   개별 클램프가 들어오면 RED).
4. **모든 콘텐츠가 제목·부제·스킵 문구 대역 밖**에 위치(P1-c 봉인).
5. **S5 오시트 픽스처가 실루엣으로 fail-safe 전환**(다른 보스 텍스처를 주입한
   픽스처로 실증).
6. **S1·S5·S7 실제 Vulkan 재검증** — §8.2 픽셀 QA 재실행 + 라이브 1판.

반증검증은 §8 규약 그대로(in-place 토글 / 임시 패치 / 픽스처. `git reset` 금지).

### 11.3 2차 슬라이스로 명시 — B안

`BattleDrawActorContext`에 **포즈별 그리드 메타데이터를 추가해 정본 계약을
만드는 작업**은 2차다. 1차에서 하지 않는다.

**착수 조건** — 아래를 정본으로 정의할 준비가 됐을 때:

- 포즈별 `frame_count` / `grid_cols` / `grid_rows`
- 원점(anchor)과 스케일 규약
- 시트의 **스테이지 소유권**(공용 `battle_resources` vs 스테이지 렌더러 비공개)

이 셋이 정리되면 비-walk 포즈가 실시트로 승격되고 실루엣 비중이 줄어든다.
스테이지별 `resolve_replay_actor_snapshot` 훅(§3.2)도 이 단계에서 함께 검토한다.

### 11.4 1차 재보정 구현 결과 (2026-08-07)

**구현 완료**

- 리졸버는 `walk` + 양수 그리드 계약이 확인된 경우에만 실시트를 선택한다.
  비-walk, 메타데이터 부재, 선택 시트 부재는 실루엣으로 fail-closed하며
  `boss_sprite_sheet` 맹목 폴백은 제거됐다. 플레이어도 같은 계약 원칙을 따른다.
- 렌더러는 760x750 기록 좌표 전체를 y=118~678 밴드로 한 번만 균일 변환한다.
  공·궤적·액터·이벤트 표식에 개별 클램프는 없다.
- 라이브 S7 최종골에서 공의 기록 좌표가 y=-32까지 나가 부제 대역으로 올라오는
  추가 반증이 확인됐다. 변환 후 각 프리미티브를 따로 자르지 않고, 콘텐츠 레이어
  전체를 y=118~678 `Control.clip_contents` 아래에 두어 상대 기하를 보존한 채 막았다.

**라이브 관측 범위**

- S1: 계약 있는 실시트가 정상 출력됐고 다른 보스/상단 절반 크롭은 재현되지 않았다.
- S5: 계약 없는 비-walk 포즈는 의도대로 실루엣 폴백했다. 다른 보스 누출과 4x4
  오해석은 재현되지 않았다. 현재 단순 직사각형 실루엣의 미감 보강은 2차 우선 후보다.
- S7: 플레이어 실시트 출력은 정상. 음수 Y 최종골 샘플로 공유 콘텐츠 클립의 필요성을
  실증했고 위 배선으로 보정했다.

**검증 계약 보강**

- 비헤드리스 캡처는 0.12초 진입 페이드가 끝난 뒤이며, 단일 픽스처에 적용되는
  타임라인 속도 정규화까지 반영해 실제 골 샘플 시각을 캡처한다.
- 액터 프로브 임계는 풀 알파 기준 `g/b > 0.58`을 유지한다. 약한 0.25 임계는 쓰지 않는다.
- 구조를 그대로 둔 채 콘텐츠 드로우 브리지만 공유 클립 밖으로 우회하는 SAFE
  반증에서 `negative-y goal ball` 픽셀 레그가 RED였고, 정상 배선 복구 후 GREEN이었다.
- 보스 flip은 현재 도달하지 않지만 코만도 무기/권총/공격 플레이어 flip은 도달한다.
  구조 씰은 명시적 그리드 계약이 있는 코만도 픽스처가 `player_flip=true`까지
  유지되는지 확인하고, 픽셀 QA는 좌우 색이 다른 비대칭 시트가 공유 콘텐츠 변환의
  중심을 기준으로 실제 반전되는지 확인한다. flip 고정점에 80px 오프셋을 임시로
  주는 SAFE 반증에서 신규 레그가 RED, 정상 식 복구 후 GREEN이었다.
