# Rally Intensity Director — 설계 노트 (합의용 / pre-wiring)

> 목적: `ball_intensity`를 "공-렌더 로컬 값"에서 **전투 전역 연출 디렉터**로 승격한다.
> 새 대형 컷신 없이, 이미 있는 intensity 훅을 디렉터로 올려 랠리·듀스·링펫 연출을
> 하나의 신호 버스로 묶는 게 1차 목표다.
>
> 상태: **데이터 백본 Slice 1–4 완료, Stage 1 필러/배경 Slice 5 완료,
> 미니 스코어보드 stakes Slice 6 완료.**
> `rally_tier`는 `exchange_count` 기준으로 고정했고, `stakes`는 `set_stakes()` 주입으로
> `ball_intensity`에 캐시한다. 다음 단계는 링펫 공명, 다른 스테이지 배경,
> 셰이크 stakes bump 같은 가시 구독자 확장이다.

---

## 결정 로그 / 구현 상태

| Slice | 상태 | 결정 |
|---|---|---|
| 1. 순수 가산 백본 | 완료 | `register_contact(actor, side, tags)` 추가. `register_hit()`/`get_last_hit_by()`/`rally_count` 의미는 레거시 호환 유지. `contact_count`는 총접촉, `exchange_count`는 side 변화만 카운트. |
| 2. 링펫 이음새 | 완료 | 컴패니언 가드는 `register_contact("lingpet", "player", {"source": "companion_guard"})`로 등록. 링펫은 player side에 기여하고 actor만 `lingpet`으로 분리. |
| 3. 첫 구독자 | 완료 | 셰이크는 raw intensity 기반 좁은 bounded lerp. 오디오는 base `play_paddle_hit()` 유지 + `did_rally_tier_advance()` 엣지에서만 tier 악센트. tier 엣지는 `ball_intensity`가 소유한다. |
| 4. stakes 백본 | 완료 | `match_score_state`에서 `deuce_mode`, `would_score_finish("player")`, `is_player_in_danger()`를 읽어 `ball_intensity.set_stakes()`로 주입. `theater_intensity = display + tier*0.08 + stakes_bonus` 후 1.0 클램프. |
| 5. Stage 1 필러/배경 크레셴도 | 완료 | `stage1_pillar_scene_drawer`가 registry에서 `ball_intensity`를 로컬 fetch해 `display_intensity`/`rally_tier` snapshot만 전달. `theater_intensity`/stakes는 읽지 않는다. Stage 1 배경은 기존 mood alpha, border shine alpha, cloud/tree offset만 미세 변조하고, director 부재 시 완전 no-op. |
| 6. 미니 스코어보드 stakes | 완료 | `stage1_top_mini_scoreboard_scene_drawer`가 `match_score_state.would_score_finish("player")` / `is_player_in_danger()`로 stakes를 파생해 top-mini 렌더 체인에 optional 인자로 전달. `player_can_win`은 normal/deuce 양쪽에서 gold 기회 악센트, `boss_can_win`은 red 위험 보조 악센트로 분리. 4-2 같은 normal match point도 deuce 게이트 밖에서 연출된다. |

### 보류 / 다음 소비처

- 링펫/스킬 접촉에서 tier 엣지가 발생하면 현재 오디오 악센트는 라우터 경로에서만 소비된다.
  시각 tier/theater는 정상 상승한다. "엣지를 감지된 곳에서 소비"하는 정책은 추후 별도 슬라이스로 판단한다.
- 셰이크의 stakes bump는 보류했다. 현재 셰이크는 raw intensity 좁은 밴드만 읽는다.
- 필러/배경은 Stage 1에서만 첫 구독자가 붙었다. Stage 2–6 배경은 아직 `display_intensity` /
  `rally_tier`를 읽지 않는다.
- 미니 스코어보드는 stakes를 읽는다. rally_tier 보조 떨림은 아직 붙이지 않았다.
- 링펫 공명은 아직 `last_hit_actor` / `rally_tier` / `theater_intensity`를 읽는 가시 구독자가 아니다.

## 0. 제1 규칙 — `register_hit`에 링펫을 그냥 추가하지 말 것 (actor / side 분리)

`get_last_hit_by()`의 **라이브 소비처는 전부 리터럴 `"player"` / `"boss"`를 기대**한다.
링펫을 `register_hit("lingpet")`로 넣으면 `last_hit_by`가 `"lingpet"`이 되어 이 판정들이
조용히 비틀린다. 확인된 소비처:

| 파일 | 라인 | 기대 | `"lingpet"` 주입 시 |
|---|---|---|---|
| `scripts/characters/commando_supply_drop_state.gd` | 1662 | `== "" or == "player"` | **player 크레딧 false로 뒤집힘** |
| `scripts/stages/stage6/stage6_tetriser_crystal_shield_state.gd` | 301 | `== "" or == "player"` | **동일 — 방패 판정 뒤집힘** |
| `scripts/stages/stage2/stage2_pillar_background.gd` | 2306 | `== "boss"` | side만 맞으면 정상 |
| `scripts/ball/ball_frame_motion_controller.gd` | 333 | `!= "boss"` | side만 맞으면 정상 |
| `scripts/stages/stage4/stage4_pillar_background.gd` | 540 | `"player"/"boss"` | side만 맞으면 정상 |

writer 측도 이미 3곳이 `register_hit("player"/"boss")`를 직접 호출한다:
`paddle_bounce_rally_feedback_router.gd:21`, `smasher_shield_kiting_state.gd:471`,
`smasher_wheel_state.gd:439`. → **레거시 시그니처는 반드시 유지**한다.

### 결론

- `get_last_hit_by()` = **side**("player"/"boss")를 계속 반환한다 (= `get_last_hit_side()`의 별칭).
- 링펫 접촉은 **side="player"**로 들어간다 → 위 5곳이 그대로 동작하고,
  "링펫 세이브 = 플레이어 크레딧"이 의도대로 성립한다.
- 링펫의 고유 정체성은 **`get_last_hit_actor()`("lingpet")**로만 따로 살린다.
  크레셴도/공명 연출만 actor를 읽고, 기존 스테이지 판정은 side를 읽는다.

```gdscript
# 링펫 컴패니언 가드 세이브는 이렇게 들어간다:
ball_intensity.register_contact("lingpet", "player", {"source": "companion_guard"})
# → last_hit_side == "player"  (기존 판정 유지)
# → last_hit_actor == "lingpet" (공명 연출만 사용)
```

---

## 1. API 계약

### 1.1 기존(레거시) — 의미 불변

```gdscript
register_hit("player")          # = register_contact("player", "player")
register_hit("boss")            # = register_contact("boss",   "boss")
get_last_hit_by() -> String     # side 반환 ("player"/"boss") — 기존 의미 유지
```

### 1.2 신규 — 확장

```gdscript
register_contact(actor_id: String, side: String, tags: Dictionary = {}) -> void

get_last_hit_actor() -> String          # "player" / "boss" / "lingpet" / 스킬 액터
get_last_hit_side()  -> String          # "player" / "boss"  (== get_last_hit_by)

get_rally_contact_count()  -> int       # 모든 접촉 1씩 (링펫 포함)
get_rally_exchange_count() -> int       # side가 바뀐 횟수 (= 현재 rally_count 의미)

get_rally_tier()           -> int       # 0..5, 비포화 (아래 §2.3)
get_display_intensity()    -> float     # 0..1 평활 정전값 (아래 §2.2)
get_raw_contact_intensity()-> float     # 0..1 순간값 (아래 §2.1)
get_theater_intensity()    -> float     # 0..1 연출 합성값 (아래 §2.5)
get_stakes()               -> Dictionary# 점수 축 (아래 §2.4)
```

### 1.3 카운터 증가 규칙 (중요 — 미묘한 정확성)

- `contact_count` : `register_contact` 호출마다 **무조건 +1** (링펫 포함).
- `exchange_count`: **side가 바뀔 때만 +1**. (actor가 아니라 side 기준)
  - 예: `player → lingpet(side=player) → boss` = 접촉 3, **교환 1**.
  - 같은 편 연속 터치(플레이어→링펫)는 "한 쪽이 잡고 있는" 상태 → 교환 아님.
    보스로 넘긴 순간이 1교환. 이게 "긴 랠리"의 드라마에 맞는 셈법.

---

## 2. 신호 정의

### 2.1 `raw_intensity` — 순간 접촉 팝 전용
- 현재 `calculate(ball_vel)`의 즉시값 (speed_level/5 + rally_bonus).
- 용도: **히트 펄스, 접촉광, 아주 짧은 셰이크.** 한 프레임 임팩트.
- 평활 없음. 매 접촉마다 튄다.

### 2.2 `display_intensity` — 평활 정전(canonical) 신호
- 현재 `display_level`(0..5)을 0..1로 정규화. `INTENSITY_TRANSITION_SPEED`로 평활.
- 용도: **공 색/글로우, 필러 반응, 배경 호흡, HUD 압박감.** 부드럽게 차오르는 값.
- **모든 "분위기" 구독자는 raw가 아니라 이 값을 공유한다** (현재 raw/smoothed 혼용 정리).

### 2.3 `rally_tier` — 비포화 장기 랠리 신호 (크레셴도의 핵심)
- **현재 천장 문제:** `ball_intensity.gd:49` `rally_bonus = min(rally_count*0.1, 0.5)`
  → 5교환에서 포화. 30타 = 5타. 지금 값으로는 긴 랠리를 **표현 자체가 불가능**.
- `display_intensity`(0..1, 공 색 보호용)는 그대로 두고, **별도 비포화 tier를 뺀다.**
- 기본 산식은 **`exchange_count` 기반**으로 고정한다. `contact_count`는 총 접촉 수
  분석과 미세 접촉 악센트용 보조 신호로만 쓰고, 장기 랠리 tier 산정에는 쓰지 않는다.
  이유는 "긴 랠리"의 드라마가 같은 편 저글링 접촉 수보다 실제 주고받은 볼리 수에 더
  가깝기 때문이다.

  | tier | exchange_count |
  |---|---|
  | 0 | 0–4 |
  | 1 | 5–9 |
  | 2 | 10–14 |
  | 3 | 15–24 |
  | 4 | 25–34 |
  | 5 | 35+ |

- 용도: **"게임 세계가 알아차린 상태."** 필러/배경 단계 상승, BGM 레이어, 링펫 공명 강도.
- 링펫이 side="player"로 들어오면 `player→lingpet→boss`도 정상 1교환으로 카운트되어
  컴패니언 랠리가 자연히 tier에 기여한다.

### 2.4 `stakes` — 점수 축 (rally와 직교)
`match_score_state.gd`에서 산출 (detection은 이미 존재, 연출 언어만 부재):

```gdscript
{
  "deuce_mode":     match_score_state.deuce_mode,
  "player_can_win": match_score_state.would_score_finish("player"),  # 기회(어드밴티지)
  "boss_can_win":   match_score_state.is_player_in_danger(),         # 위험(이미 danger-glow 구동)
}
```
- 파생 단계: `normal < deuce < (player_can_win XOR boss_can_win) < (둘 다 true: 최대 긴장)`.
- `player_can_win`/`boss_can_win`은 **별 enum이 아니라 둘 다 살린다** —
  렌더러가 "기회 글로우" vs "위험 글로우"를 구분해야 하므로. 6-6(goal 7)처럼 둘 다 true면 최고조.

### 2.5 `theater_intensity` — 연출 합성값
- 대략 `display_intensity + rally_tier bump + stakes bump`를 0..1로 합성.
- **구독자별 상한**을 둔다 (전역 단일값을 그대로 쓰지 않음):
  - 셰이크: 합성값을 받되 **아주 좁은 폭**으로 클램프 (조작 좌표 감각 보호).
  - BGM: **히스테리시스** (tier 경계에서 떨지 않게, 올라갈 때/내려갈 때 임계 분리).
  - 필러/배경: 부드러운 ease, 급변 금지.

---

## 3. 구독자 맵

| 구독자 | 읽는 신호 | 비고 |
|---|---|---|
| 공 렌더 (색/글로우) | `raw_intensity`, `display_intensity` | 현행 유지 |
| 히트 펄스 | `raw_intensity` | 현행 유지 |
| 셰이크 | `raw_intensity` + `stakes` | **현재 상수 → 좁은 폭으로 연결** (router:44) |
| 오디오 | `rally_tier` 임계 / 레이어 | **현재 단발 → tier threshold/layer** (매 히트 피치 난사 금지) |
| 미니 스코어보드 | `stakes` 주, `rally_tier` 보조 떨림 | 듀스/매치포인트 연출 언어 |
| 필러 / 배경 | `display_intensity`, `rally_tier` | parallax/vignette/호흡 (카메라 줌 금지) |
| 링펫 | `last_hit_actor`, `rally_tier`, `theater_intensity` | 공명선/오라 |

---

## 4. 승격에 필요한 구조 수정 3개 (배선 전 선행)

1. **rally-5 천장 해제** — `rally_bonus` 포화는 두되, `rally_tier`를 비포화로 분리(§2.3).
   `display_intensity`(공 색)는 0..1 유지해 색 번짐 방지.
2. **raw vs smoothed 단일화** — 분위기 구독자는 `display_intensity` 하나로 통일.
   `raw`는 순간 contact pop 전용으로 한정 (현재 `calculate()` 직접 호출이 5곳에 흩어져 있음:
   `ball_update_controller:669`, `battle_draw_ball_context:23`, `paddle_bounce_event_router:312`,
   `paddle_bounce_rally_feedback_router:22`, `ball_round_controller:89`).
3. **셰이크·오디오에 intensity 연결** — `paddle_bounce_rally_feedback_router.gd:44-49`의
   상수 셰이크 / 단발 사운드를 §3 계약대로 교체. (가장 싼 윈, 단 셰이크 폭은 좁게)

### 링펫 이음새
`lingpet_companion_body_hit_state.gd:153 _play_paddle_hit`는 현재 자기 오디오만 울리고
`ball_intensity`에 **등록을 전혀 안 한다.** 여기에 `register_contact("lingpet","player",…)`를
추가하면 컴패니언 세이브가 랠리 tier에 기여하고, #4(공명)가 #1(크레셴도) 위에 자연스럽게 얹힌다.

---

## 5. 스모크 가드 (배선 시 함께)

- `get_last_hit_by()` / `get_last_hit_side()`가 링펫 접촉 후에도 `"player"`를 반환하는지
  (commando supply drop / stage6 crystal shield 회귀 방지).
- 같은 편 연속 접촉은 `contact_count`를 올리지만 `exchange_count`와 `rally_tier`는 올리지 않는지.
- 35교환 랠리에서 `rally_tier == 5`, 5교환에서 `display_intensity`는 포화하지만 `rally_tier`는 계속 오름.
- 듀스 6-6(goal 7)에서 `stakes.player_can_win && stakes.boss_can_win` 둘 다 true.
- 셰이크 폭이 상한 클램프를 넘지 않음 (조작 스트레스 회귀 방지).

---

## 6. 연출 보완 원칙 (디렉터 외 합의 사항)

- **카메라 줌/이동 금지.** vignette / 필러·배경 parallax / 공 주변 국소 왜곡 / HUD 압박으로만.
- **세계관 비주얼은 글리치 단일 문법 금지.** 스테이지별 "데이터가 어떻게 변조되는가" 문법표 선행
  (홍련=화염 데이터, 달지/조선풍=문양·부적·한지 데이터, 링펫=공명 프로토콜 …).
- **보스 격파는 일괄 디졸브 금지.** 보스별 감정 포즈 ~0.7s 후 데이터 해체, 해체 중 표정/실루엣 유지.
