# 빠나몽 액티브 스킬 — 야생의 포효 (Wild Roar) 포팅 기획서

원본 PingFighter 투기장 영웅 **원숭이왕(monkeyking)** 의
`WildRoar`(`downtown/hero_skills.py:17730`)를 **빠나몽(monkeyring) 링펫의
두 번째 액티브 스킬**로 포팅한다. 수치·연출은 원본 충실 포팅이 기본이고,
트리거 모델과 레벨 스케일(원본에는 레벨 개념 자체가 없음 — §0 D6)만 링펫
컨벤션에 맞춰 의도적으로 분기한다(부록 B).

스킬 정체성: 빠나몽이 대지를 뒤흔드는 포효 충격파를 펼쳐, 접근하는 공을
즉시 **2.6x~3.6x 가속 반사**한다. **가속된 공은 보스가 받아칠 때까지 공속
제한(캡)이 해제**되고, 보스가 받아치는 순간 가속 전 원래 속도로 복원된다
(원본 메인게임 호위무사 경로의 `wild_roar_boosted` 모델 충실).

- 분담: 이 문서는 디자인 노트(신호 계약) + 슬라이스 브리프(백본/스모크/트랩)다.
  GDScript 배선·자산 생성·스모크 검증은 사용자/Codex 측, Claude는 설계와
  적대적 리뷰를 맡는다. (`[[feedback_design_slice_review_division]]`)
- 작성일: 2026-06-12.
- 형제 문서: `docs/lingpet_monkeyring_banana_slice_plan.md` (빠나몽 1번 스킬,
  배선 패턴의 기준 레퍼런스. 그 문서 부록 B에서 "추후 2-스킬 풀 후보"로
  남겨둔 항목이 이 문서다.)
- 원본 보조 레퍼런스: 메인게임 호위무사 적용 경로
  (`game_mechanics/ingame_bodyguard.py` `_BallProxy` :281-307,
  `pingfighter.py:173941` 보스 리턴 복원, `pingfighter.py:165855` 라운드 리셋),
  보스 하수인 근접 대기 경로(`game_mechanics/henchman_system.py:45-52`
  `HENCH_BALL_PROXIMITY_SKILLS = {'wild_roar'}`).

---

## 0. 구현 결정

| # | 결정 | 제안값 |
|---|------|--------|
| D1 | 트리거 | **링펫 오토캐스트 + `can_arm` 공 근접 게이트** (쿨다운 0 + ball_active + 공이 하강 중이고 빠나몽 근접 창 안). 원본 ON_COOLDOWN + `_ball_in_range`(hero_skills.py:17785) 의 등가물. 게이트 기하는 §3 |
| D2 | 윈드업 | **`windup_seconds: 0.0` 명시** (원본 = 발동 순간 즉시 반사, 텔레그래프 없음). 키 생략 금지 — 생략하면 1.0s 폴백 (`lingpet_current_profile.gd:191-192` 트랩). arm → 1프레임 뒤 launch |
| D3 | 쿨타임 | **27.0s** (원본 충실. hero_skills.py:17747). 풀 형제: 바나나 18 / 헤드벗 30 / 하이드로 40 / 버블 25 / 인형의 저주 30 — 27은 자연스러운 자리. 공용 레벨별 쿨다운 감소(0~12%)는 자동 중첩 |
| D4 | 공속캡 해제 | **자폭드론 템플릿** — owner 키 2종(`lingpet_wild_roar_ball_boost_active` / `_restore_speed`) + `speed_limit_disabled` 컨텍스트 채널 + **보스 패들 리턴 시 방향 보존·원속 복원**. 발동 순간부터 보스 리턴(또는 라운드 리셋)까지 캡 해제 유지. 상세 §2 |
| D5 | 반사 수학 | **원본 충실**: 충격파 중심→공 법선 반사 + ±30° 랜덤 지터 + "시전자 골대 방향 금지" 안전 플립 2중 + `speed_pre × boost`. 상세 §3 |
| D6 | 레벨 스케일 | **신설(원본에 레벨 없음 — hero_skills 전체에 skill_level 0건)**: `roar_radius_by_level: [180, 198, 216, 234, 252]` (px, Lv.5 = 원본 SHOCKWAVE_RADIUS 252), `ball_boost_by_level: [2.6, 2.85, 3.1, 3.35, 3.6]` (근접 발동 기준 최대 배율, Lv.5 = 원본 3.6). 거리 기반 변조(가까울수록 강함, 폭 1.0 고정)는 원본 충실 유지 — §3 |
| D7 | 시전 경직 | 발동 후 **ROAR 0.6s** (원본 ROAR_FREEZE_TIME) 동안 컴패니언 위치 오버라이드 + 캐스트 포즈. 원본의 패들 스턴 플래그 대신 banana_slice PREPARE 패턴 재사용 |
| D8 | 보스 CC 없음 | 이 스킬은 보스 AI를 건드리지 않는다 — `get_boss_ai_context()` 채널 불필요(바나나와 다름). 공 가속 + 캡 해제가 효과의 전부 |

D4의 함의: 가속된 공은 비행 중 매 프레임 캡 클램프(26 + 랠리 보너스)를
면제받고, 벽 반사(×0.95 감쇠)를 거쳐도 대부분 유지되며, **보스가 받아치는
프레임에 가속 전 속도로 정확히 복원**된다(방향은 보스 바운스 결과 유지).
보스가 못 받으면 실점 → 라운드 리셋이 플래그를 청소한다.

### 구현 봉인 포인트 4 (리뷰 승인 시 확정, 2026-06-12 — 배선 시 필수 준수)

1. **`can_arm` 하한은 고정 60 금지** — 바디히트 판정 소스(`catch_half_height
   + ball_radius`)와 현재 공속에서 동적 산출 (§3, S2/S13 고속 케이스).
2. **60 백스톱은 스킬 launch 쓰기에서만 검증** — `apply_ball_speed_limits`는
   캡 면제 중 클램프를 통째로 스킵하므로 그 표면에서 단언 금지 (S3/S5).
3. **`monkeyshouting.wav`는 `.wav.import` 사이드카까지 같이 커밋** — 에디터
   raw 디코드가 익스포트 누락을 가린다 (§6.5).
4. **오디오는 const/var/play 외에 셋업 생성 블록(:654 옆)과
   `_get_audio_setup_stream_paths` 프리웜 목록(:949 옆)까지 등록** (§6.5).

---

## 1. 타임라인 (스킬 내부 페이즈)

오토캐스트 arm(§3 게이트 통과 프레임) → windup 0.0s(다음 프레임 즉시) →
`launch()` 프레임에 아래가 **한 프레임 안에서** 일어난다:

| 시점 | 내용 | 원본 근거 |
|------|------|----------|
| launch 프레임 | 충격파 중심 = 컴패니언 중심 (**발사 프레임 고정** — 원본은 매 프레임 패들 추적 :17968-17973, 고정은 의도적 분기 — 부록 B). 공이 Euclidean 거리 1 < dist < radius면 **즉시 반사 + 가속 + 캡 해제 플래그 세트**. 그 외(반경 밖 / dist≤1)는 헛포효(반사 없음, 쿨다운은 소모) | hero_skills.py:17895-17934 (즉시 반사, "프레임 딜레이 없음" 주석; :17903 `dist > 1` 가드) |
| launch 프레임 | 포효 사운드 1회, 풀스크린 플래시(상태값 200, 반사 임팩트 시 255 — **드로우는 min(state, 120) 캡**, 원본 :18091 동일, §7), 스크린 셰이크(반사 시 강 / 헛포효 시 약), 링 6개 + 에너지 스파크 16개 생성, 반사 시 임팩트 파티클 40개 | :17837-17944 |
| ROAR 0.6s | 컴패니언 이동 불가(위치 오버라이드) + 포효 포즈(캐스트 포즈 progress 0→1) | :17879-17886 ROAR_FREEZE_TIME |
| ~1.8s | 링 확장(개당 0.2s) → linger → 페이드, 스파크/파티클 소멸. 전부 끝나면 스킬 종료 (원본 조기 종료 로직 동일: all_faded + 파티클 0) | :17748 duration=1.8, :18015-18017 |

- `is_active()` = VFX 잔존 동안 true → `is_launch_blocked` → 재-arm 금지.
- **공의 가속/캡 해제 상태는 `is_active()`와 무관하게 owner 키로 지속**된다
  (원본도 duration은 VFX 윈도우일 뿐, 부스트는 game_state 플래그로 보스
  리턴까지 생존 — hero_skills.py 연구 노트). VFX가 끝나도 공은 가속 상태.
- 충격파 확장 자체는 0.09s(SHOCKWAVE_GROW_TIME)로 매우 빠름 — 반사는
  발동 프레임 즉시이므로 확장은 순수 비주얼.

---

## 2. 신호 계약 — 공속 부스트 + 캡 해제 (자폭드론 템플릿)

owner 키 + 공 파이프라인 채널이다. 바나나의 보스 AI 컨텍스트 채널과는
완전히 다른 계열 — 정확한 선례는 코만도 자폭드론 부스트
(`commando_firearm_suicide_drone_ball_boost_resolver.gd:6-33`).

### 신규 owner 키 (2종, `battle_scene_state.DEFAULT_VALUES` 선언 필수)

```
lingpet_wild_roar_ball_boost_active   : bool    # 가속 비행 중 (캡 면제 게이트)
lingpet_wild_roar_ball_restore_speed  : float   # 가속 전 원래 속력 (px/frame)
```

자폭드론은 `_boosted_speed` 3번째 키도 갖지만 그 키의 소비처는 드론
이펙트 전용이므로 여기서는 2종으로 충분하다. (Owner-Field Schema Trap —
선언 없는 `owner.set`은 조용한 no-op. 스모크 S12가 스키마 게이트 owner로 봉인.)

### 부스트 세트 (스킬 모듈, launch 프레임)

```gdscript
var speed_pre := ball_vel.length()              # 가속 전 속력
var boosted_vel := reflect_dir * speed_pre * boost   # §3 반사 수학
owner.set("ball_vel", boosted_vel)
owner.set("lingpet_wild_roar_ball_boost_active", true)
owner.set("lingpet_wild_roar_ball_restore_speed", speed_pre)
```

- 링펫 update는 `update_ball` **뒤에** 돈다(`battle_frame_flow_controller.gd:79-81`)
  → 이 쓰기는 다음 프레임의 `ball_update_controller.update()` 첫 클램프
  (`apply_ball_speed_limits`, 프레임당 3회 호출)와 만난다. 플래그가 없으면
  **다음 틱에 26으로 즉시 클램프**되므로 캡 면제 배선이 곧 스킬의 생명선이다.

### 캡 면제 4포인트 (`speed_limit_disabled` 채널)

자폭드론 키가 박혀 있는 모든 지점에 wild roar 키를 나란히 추가:

1. `ball_frame_motion_controller.gd:63-67` `_is_speed_limit_disabled` —
   `or bool(scene.get("lingpet_wild_roar_ball_boost_active", false))` 추가.
2. `paddle_bounce_velocity_step.gd:92-96` — 동일 술어 (바운스 클램프를 INF로
   여는 쪽. fire weather 예외는 기존 구조 그대로 둠).
3. `ball_update_controller.gd:701-705` — 동일 술어 (파워스매시 전용 캡 경로).
4. `ball_update_context.gd` — `_apply_lingpet_wild_roar_speed_policy`를
   드론 정책(:138-142) **뒤, 빌드 순서 마지막**에 추가:
   `if active: context["speed_limit_disabled"] = true`.
   **순서 트랩**: mythic 리그 정책(:116)과 fire weather 정책(:125)이
   `speed_limit_disabled = false`를 강제로 쓰고, 드론 정책이 마지막에 true를
   재단언하는 구조다(:21-24 빌드 순서). wild roar 정책도 그 뒤에 와야
   mythic 리그에서 캡 해제가 죽지 않는다.

수용하는 기존 상호작용 (드론과 동일, 의도적):
- **fire weather의 35 상한은 패들 바운스 시점에만 적용** —
  `paddle_bounce_velocity_step.gd:38` `and not fire_weather_active` + :64-65.
  비행 중 클램프는 부스트 플래그가 켜진 동안 **통째로 스킵**되므로
  (`ball_frame_motion_controller.gd:57-58` — fire min-클램프 :82-83은 캡 경로
  내부라 도달 불가) 비행 속도의 유일한 상한은 모듈 백스톱 60이다. 부스트의
  정상 수명에서 다음 패들 접촉 = 보스 리턴(consume)이므로 체감 차이 없음.
  S5에서 "fire 날씨 중 비행 35 클램프"를 단언하지 말 것.
- 벽 반사는 클램프가 없고 ×0.95 감쇠만(`wall_bounce_state.gd:30-36`) —
  부스트 공이 벽을 맞아도 거의 유지(원본도 동일 계열).

### 복원 — 보스 패들 리턴 (원본 pingfighter.py:173941 충실)

`paddle_bounce_boss_post_hit_handler.gd`에 드론 consume(:355-371)을 미러한
`_consume_lingpet_wild_roar_ball_boost(ball_vel, context)` 추가:

```gdscript
if not bool(context.get("lingpet_wild_roar_ball_boost_active", false)):
    return {}
var restore_speed: float = max(0.0, float(context.get("lingpet_wild_roar_ball_restore_speed", 0.0)))
var next_ball_vel: Vector2 = ball_vel
if restore_speed > 0.0 and ball_vel.length() > 0.001:
    next_ball_vel = ball_vel.normalized() * restore_speed   # 방향 보존, 속력만 원복
return {
    "ball_vel": next_ball_vel,
    "lingpet_wild_roar_ball_boost_active": false,
    "lingpet_wild_roar_ball_restore_speed": 0.0,
    "speed_limit_disabled": false,
}
```

- 원본 복원 수학과 동일: `ratio = original / current`를 양 성분에 곱함 =
  **보스 바운스 후 방향은 유지, 속력만 가속 전 값으로** (가속~리턴 사이에
  붙은 랠리 가속분도 함께 버려짐 — 원본 동일, 의도).
- 호출/병합 지점: 드론 consume 호출부(:171-176)와 result 병합(:211-214)
  바로 옆에 나란히.
- **전파 allowlist 4계층** (한 곳이라도 빠지면 키가 조용히 드랍 — 드론 키가
  있는 줄 옆에 그대로 추가):
  1. `paddle_bounce_post_hit_handler.gd:337-355` 보스 분기 allowlist
     (`speed_limit_disabled`는 :333-336에 이미 특례 처리됨)
  2. `paddle_bounce_post_hit_step.gd:95-111`
  3. `paddle_bounce_controller.gd:113-167`
  4. `ball_update_controller.gd:622-627` 프레임 스냅샷 리스트 +
     `ball_update_owner_snapshot.gd:34-36` owner→컨텍스트 리드

플레이어 패들이 부스트 공을 받는 경우(보스 변위 스킬 등 희귀 케이스)는
consume 없이 부스트가 유지된다 — 드론과 동일한 노출이며 수용한다. 부스트
공의 정상 수명은 "위로 발사 → 보스 리턴(복원) 또는 보스 미스(실점 →
라운드 리셋 청소)" 둘뿐이다.

---

## 3. 신호 계약 — 발동 게이트 + 반사 수학

### `can_arm` 게이트 (호스트 `can_arm` 디스패치 :173-182에 행 추가)

`params`에 이미 `owner` / `companion_pos`가 실려 온다
(`lingpet_companion_skill_controller.gd:59-73`이 매 프레임 평가). 게이트:

```
1. companion_pos != Vector2.ZERO                            (dragon_breath 선례)
2. not owner.skip_ball_motion_step                          (owned-ball 스킬 발동 중 금지)
3. ball_vel.y > 0                                           (하강 = 플레이어 쪽 접근)
4. arm_min_gap(동적, 아래) < (companion_y - ball_cy) <= trigger_distance
                                                            (세로 근접 창 — 원본 Y축 분리 판정 + 동적 하한 신설)
5. |ball_cx - companion_x| <= roar_radius                   (X축 충격파 반경 내 — 반사 실패 방지)
```

- **동적 세로 하한 `arm_min_gap` (의도적 분기 — 부록 B)**: 원본은
  하한 0(시전자가 패들 자신이라 패들 충돌과 스킬이 한 몸)이지만, 링펫은
  **컴패니언 바디 히트가 별도 선행 시스템**이다 — `lingpet_egg_runtime`은
  매 프레임 `_resolve_companion_ball_hit`(:198)을 스킬 업데이트(:200)보다
  먼저 해석하고, 바디 히트(`lingpet_companion_body_hit_state.gd:67`)는
  방향 게이트 없이 `dy <= half_height + ball_radius`(빠나몽 캐치 90×54 →
  세로 임계 27 + 공 반경 ~14.3 ≈ **41.3**) 진입 엣지에서 ball_vel을 위로
  재작성한다. **정적 하한은 불충분** — arm 갭 61에서 vy ~26(+랠리 보너스로
  더 커질 수 있음)이면 launch 프레임에 갭이 41.3 아래로 들어가 바디 히트가
  선행한다. 따라서 하한을 **바디히트 임계 + 공속 연동**으로 동적 계산한다:

  ```
  arm_min_gap = catch_half_height + ball_radius            # 바디히트와 같은 소스
              + ball_vel.y * ROAR_ARM_TRAVEL_FACTOR(1.5)   # arm→launch 1틱 이동분
              + ROAR_ARM_MARGIN(6.0)
  # catch_half_height/ball_radius는 바디히트 상태와 동일한 owner/카탈로그
  # 값에서 파생 (ball_size*0.5, catch_height*0.5) — 41.3 하드코딩 금지.
  # vy는 자유 비행 중 불변이라 1틱 예측이 정확; factor 1.5는 물리 틱
  # 55Hz(fps_scale≈1.09)급 저틱 구성까지 커버.
  ```

  base vy 7.65 → ≈ 63, 캡 vy 26 → ≈ 86 — Lv.1 트리거 창(107~164)보다 항상
  아래이므로 창을 잠식하지 않는다. **launch 프레임에 공이 캐치박스에 닿기
  전에 반사가 항상 선행**됨을 기하로 보장(이중 바운스 차단, S13 — 고속 공
  케이스 필수). `suppresses_companion_body_hit` 훅(host :299-306,
  bomb/gatling 등록)은 1차로는 등록하지 않는다(기하 회피 채택) — 라이브
  QA에서 이중 바운스가 그래도 관측되면 windup/ROAR 동안 억제하는 폴백
  레버로 사용.
- **방어 인터셉트(빠나몽 defense_rate 0.16)와의 우선순위**: 공이
  세로 창 `(arm_min_gap, trigger_distance]`에 있으면 roar가 선점하고, 그 아래는
  바디 히트/방어 가드가 폴백이다. 인터셉트가 컴패니언을 하강 공 밑으로
  옮기는 동작은 오히려 X반경/세로 창 충족을 도와 roar 발동을 앞당긴다 —
  충돌이 아니라 시너지로 정의한다. **휘프 후 ROAR 동결 중에도 바디 히트는
  살아 있어**(`_is_companion_body_available_for_hit` :1572-1573) 하강 공을
  노멀 가드 바운스할 수 있다 — 수용하는 정상 동작(펫의 평소 바디 가드).
- **trigger_distance는 사이클당 1회 롤** —
  `randf_range(roar_radius * 0.595, roar_radius * 0.913)` (원본 150~230을
  radius 252 비율로 일반화; Lv.5에서 정확히 150~230 재현). 원본의
  `if self._trigger_distance <= 0: random.uniform(150, 230)`(:17793-17795)
  충실 — 원본도 발동 "확률" 롤이 아니라 이번 사이클의 창 크기를 정하는
  롤이다. 롤 시점 구현: controller는 **쿨다운이 0일 때만** `can_arm`을
  호출하므로, `can_arm` 진입부에서 `_trigger_distance <= 0`이면 1회 롤
  (가드 뒤에서만 randf — 사이클당 1회 보장) → launch 시 0으로 리셋(다음
  사이클 재롤, 원본 :17840 동일). **매 프레임 무가드 재롤 금지** — S2의
  롤 카운터가 봉인 (Per-Frame Probability Roll Trap: 이 롤은 성공 확률이
  아니라 창 크기만 정하므로 컴파운딩 비해당 구조이나, 재롤되면 창이 매
  프레임 흔들려 레벨 스케일이 뭉개진다).
- 게이트가 매 프레임 재평가되므로, 조건 미충족 프레임은 그냥 arm을 미룬다.
  쿨다운은 이미 0이므로 공이 창에 들어오는 순간 발동한다(원본 호위무사
  "공 근접 대기" 모델 — colosseum_arena.py:4850, henchman_system.py:45-52).
- 플레이어-블로커블 게이트는 **넣지 않는다**: 이 스킬은 가드가 아니라
  공격 가속기다(원본 정체성). 플레이어가 칠 공을 가로채는 것도 의도된
  인터셉트다. (마리보 방어율류 "표시 스탯 스코프" 사가와 달리 표시
  확률이 없는 오토캐스트 공격이므로 스코프 혼동 자체가 없음.)

### 반사 수학 (launch 프레임, 원본 :17895-17931 충실)

```
dx, dy = ball_center - companion_center
dist   = sqrt(dx² + dy²)
if dist <= 1 or dist >= roar_radius
   or speed_pre <= 0.001:               →  헛포효 (원본 :17903 `1 < dist < radius`
                                            가드 — dist≤1도 반사·부스트 없는 순수
                                            헛포효. v≈0 퇴화도 휘프: 원본의
                                            :17924-17926 vy반전 폴백은 restore_speed
                                            0인 채 언캡 플래그만 남기는 구멍이라
                                            의도적으로 기각 — 부록 B, 배선 리뷰 v4)
boost  = ball_boost - t × 1.0,  t = (trigger_distance - near) / (far - near)
         (near = radius×0.595, far = radius×0.913 — 가까운 롤일수록 강함,
          폭 1.0은 원본 3.6−2.6 고정. Lv.1: 1.6~2.6, Lv.5: 2.6~3.6)
n      = (dx, dy) / dist                  # 중심→공 법선
r      = v - 2(v·n)n                      # 법선 반사 (|r|=|v|>0 보장됨)
angle  = atan2(r) + randf_range(-0.523, +0.523)   # ±30° 지터, 1회 롤
reflect_dir = (cos(angle), sin(angle))
if reflect_dir.y >= -0.01:                # 안전장치: 위로 + 수평 근접 방지
    reflect_dir = normalize(reflect_dir.x, -|reflect_dir.y| - 0.18)
ball_vel = reflect_dir × min(speed_pre × boost, 60)   # 모듈 측 백스톱
```

- 모든 값 **px/frame** (`[[feedback_godot_ball_vel_pxframe_units]]`).
  base 7.65 × 3.6 ≈ 27.5(캡 26 초과 — 캡 해제가 Lv.5 기본속도에서도 이미
  유의미), 랠리 성장 속도 ~20 × 3.6 = 72까지 가능. 모듈 측 절대 백스톱
  `ROAR_BOOSTED_SPEED_MAX := 60.0` px/frame을 부스트 쓰기에 클램프로 둔다
  (원본 메인게임의 MAX_BALL_VELOCITY=100 백스톱 등가물, 60fps 한 프레임에
  화면 8%를 넘는 병적 속도 차단). 모션 서브스텝 임계(12 px/frame 초과 시
  분할)가 터널링을 막아주지만 보스 패들 충돌 QA는 §8 S5에서 실측한다.
- 헛포효(공이 발동 프레임에 반경을 벗어남 — windup 0이라도 arm→launch
  1프레임 사이 최대 ~26px 이동)도 원본 동작: 반사 없음, 부스트 플래그
  미설정, VFX/사운드/약셰이크는 재생, 쿨다운 소모(:17943 shake 12 분기).
- 지터/거리 롤은 모두 **트리거 엣지 1회 롤** + 테스트 주입 가능 시드.

---

## 4. owner 스키마 — 신규 키 2종 + 리셋 전파

§2의 2키를 선언하고, 자폭드론 트리오가 있는 **모든 리셋/스냅샷 지점**에
나란히 추가한다:

| 지점 | 파일:라인 (드론 키 위치) |
|------|--------------------------|
| 스키마 선언 | `battle_scene_state.gd:278-280` 옆 |
| 라운드 리셋 | `ball_round_state.gd:72-74` |
| 매치 리셋 | `match_reset_controller.gd:249-251` |
| owner→프레임 컨텍스트 | `ball_update_owner_snapshot.gd:34-36` |
| 프레임 스냅샷 리스트 | `ball_update_controller.gd:622-627` |

- `speed_limit_disabled` 자체는 owner 키가 아니다(매 프레임 파생) —
  영속 상태는 `*_ball_boost_active` 키 쪽. 드론과 동일.
- 이 2키는 **공 파이프라인 키**라서 스냅샷-빌더 동기화 계열 `lingpet_*`
  스탯(방어율 등)과 달리 `ringpet_` 별칭 쌍이 **필요 없다** — 맹목적 별칭
  추가 금지 (드론 트리오도 별칭 없음).
- effects-side 동기화 지점(`battle_scene_effects_update_result_applier.gd:101-111`,
  `battle_update_effects_owner_context_builder.gd:52-54`)은 드론 리졸버가
  이펙트 업데이트 경로에 살기 때문에 필요했던 것 — wild roar의 생산자는
  링펫 `owner.set`, 소비자는 공 파이프라인뿐이므로 **불필요로 판정**한다.
  (배선 시 한 번 더 확인: 이펙트 경로가 이 키를 읽을 일이 없으면 생략.)
- **스킬 모듈은 발사 후 부스트 상태를 소유하지 않는다** (fire-and-forget,
  드론 동일). 라운드-엔드 `cancel(null)`은 owner가 없어 owner 키를 지울 수
  없지만(`바나나 문서 §5의 owner-less cancel 트랩`), 같은 순간
  `ball_round_state` 리셋이 키를 청소하므로 의도적으로 그 경로에 위임한다.
  펫 스위치 중 부스트 비행은 키가 살아서 보스 리턴/라운드 리셋까지 정상
  진행 — 올바른 동작이다.

---

## 5. 라운드/리셋 정리

- 스킬 모듈 자체 상태(페이즈/링/스파크/파티클/거리 롤): `reset()` /
  `cancel(owner=null, registry=null)`에서 전부 클리어. `_registry` 캐시
  (banana :57 패턴) 유지.
- 공 부스트 상태: §4 — `ball_round_state` / `match_reset_controller`가
  owner 키를 리셋(원본 `reset_round`의 pop 등가, pingfighter.py:165855).
  복원 없이 클리어(공이 재서브되므로 — 원본 동일).
- 사운드 원샷 1종(roar) → 루프 오디오 클린업 등록 불필요.
- 시전 경직은 위치 오버라이드 기반이라 외부 스턴 플래그 잔류 없음 —
  원본의 `*_stunned` 누수 안전 해제(:18049-18052) 같은 코드가 필요 없다.

---

## 6. 코드 배선 슬라이스 (banana_slice 동형 + 공속 채널)

신규 파일: `godot/scripts/lingpet/lingpet_wild_roar_skill.gd`
신규 스모크: `godot/tests/lingpet_wild_roar_skill_smoke.gd`

### 6.1 dispatcher (`lingpet_skill_dispatcher.gd`)
- `const SKILL_KIND_WILD_ROAR := "wild_roar"` + `SUPPORTED_SKILL_KINDS` 등록
  (등록 누락 시 카탈로그 runtime_kind가 있어도 :61에서 NONE으로 강등).
- `const WILD_ROAR_SKILL_ID := "monkeyring_wild_roar"` + `get_skill_kind()`
  match 폴백 arm + `static func is_wild_roar(skill_id)` 헬퍼.

### 6.2 host (`lingpet_skill_runtime_host.gd`)
banana_slice가 등장하는 모든 지점(§3 호스트 체크리스트, 바나나 문서 6.2와
동일 표면)에 wild_roar 추가: `WILD_ROAR_SKILL_PATH` 상수(:19 옆) + 멤버
(:35 옆) + lazy getter(:627 옆) + `reset`(:53) + `update` **4-인자
launch_context 전달형**(:87-88 바나나 arm 옆) + `draw`(:108, 캐시 멤버) +
`has_visible_effects`(:127) + `_get_skill_for_kind`(:537-538) +
`is_launch_blocked`(:167-168, `is_active()`) + `launch`(:221-222) +
`get_launch_origin`(:257-258, `companion_pos` 그대로) +
`has/get_companion_position_override`(:275-294, **ROAR 페이즈 동안**) +
`get_companion_cast_pose_progress`(:337-339, ROAR 0→1) + `get_snapshot`
(:403) + 테스트 접근자(:495-504 옆).
- **신규 행**: `can_arm`(:173-182)에 WILD_ROAR 디스패치 — 모듈의
  `can_arm(params)`로 위임 (headbutt :175-176 / dragon_breath :177-178
  선례). 모듈은 로드아웃 적용 시점 프리웜으로 이미 생성돼 있으므로
  핫패스 lazy-init 위험 낮음 — 기존 행 패턴 그대로.
- `trigger_launch_feedback`: **의도적 no-op** (주석 명시). 포효 사운드는
  모듈이 launch 프레임에 직접 낸다(§6.5) — 스냅샷 카운터와 짝 맞춤.
- `get_boss_ai_context`(:378-384)는 **건드리지 않는다** (D8 — 보스 CC 없음).

### 6.3 egg runtime (`lingpet_egg_runtime.gd`)
- `_launch_companion_skill`의 launch_context 하드코딩 키 리스트(:1527-1537)에
  추가: `"roar_radius": float(current_active_skill.get("roar_radius", -1.0))`,
  `"ball_boost": float(current_active_skill.get("ball_boost", -1.0))`.
  −1.0 센티널 = 카탈로그 키 부재 → 모듈 로컬 테이블 폴백 (banana 패턴).
- 그 외 변경 없음 — 프리웜(:1193-1203)·쿨다운 틱·arm 흐름은 공용 경로가
  자동으로 처리.

### 6.4 공 파이프라인 (공속 채널 — §2/§4의 전체 목록)
1. `battle_scene_state.gd` DEFAULT_VALUES 2키.
2. 캡 면제 4포인트: `ball_frame_motion_controller.gd:63-67` /
   `paddle_bounce_velocity_step.gd:92-96` / `ball_update_controller.gd:701-705` /
   `ball_update_context.gd` 신규 정책(빌드 순서 **마지막**).
3. 복원 consume: `paddle_bounce_boss_post_hit_handler.gd` (+ :171-176 호출,
   :211-214 병합).
4. allowlist 3계층 + 스냅샷 2지점 (§2 복원 절 표).
5. 리셋 2지점: `ball_round_state.gd` / `match_reset_controller.gd`.

### 6.5 audio (`game_audio.gd`)
- 자산: `sounds/monkeyshouting.wav`(255,840B, 44.1kHz 스테레오, ≈1.45s)를
  `godot/assets/sounds/lingpet/monkeyshouting.wav`로 복사 (링펫 사운드 디렉터리
  컨벤션 — puppet_grab.wav 선례). **복사 후 Godot 임포트 패스를 한 번
  돌리고 `monkeyshouting.wav.import` 사이드카를 함께 커밋**할 것 —
  `ProjectResourceLoader`는 에디터에서 raw 파일을 직접 디코드할 수 있어서
  임포트 누락이 에디터에서는 안 보이다가 익스포트 빌드에서만 터진다
  (`[[feedback_godot_load_texture_raw_bypass]]`의 오디오 형제 트랩).
- `const LINGPET_WILD_ROAR_SOUND_PATH := "res://assets/sounds/lingpet/monkeyshouting.wav"`
  + var + 링펫 SFX 셋업 블록에서 factory
  `create(owner_node, "LingpetWildRoarSfx", PATH, -4.0)` (puppet_grab :654
  옆; 원본 volume 0.7 ≈ −3.1dB, 여유 있게 −4.0 제안) +
  `func play_lingpet_wild_roar(): _play_with_pitch(sfx, randf_range(0.96, 1.04))`.
- **셋업/프리웜 표면 2곳 모두 등록**: 플레이어 생성 블록만으로는 부족하다 —
  `_get_audio_setup_stream_paths(step)`(:857)의 링펫 경로 목록(:949
  `LINGPET_PUPPET_GRAB_CAST_SOUND_PATH` 옆)에도 추가해야 기존 링펫 SFX와
  같은 단계에서 스트림이 프리웜된다.
- 모듈에서 `_get_registry_instance(_registry, "game_audio")` + `has_method`
  가드 후 호출 (banana :609-620 패턴). 헛포효에도 재생(원본: 반사 여부와
  무관하게 포효음 :17888-17893).

### 6.6 catalog (`lingpet_catalog.gd`)
monkeyring `active_skill_pool`(:811)에 **두 번째 엔트리 append** —
바나나 슬라이스가 pool[0] 기본을 유지한다:

```gdscript
{
    "id": "monkeyring_wild_roar",
    "runtime_kind": "wild_roar",
    "name": "야생의 포효",
    "description": "빠나몽이 대지를 뒤흔드는 포효로 충격파를 펼쳐, "
        + "다가오는 공을 폭풍처럼 가속해 반사합니다. 가속된 공은 보스가 "
        + "받아칠 때까지 속도 제한이 풀립니다. 레벨이 오르면 충격파 "
        + "범위와 가속률이 커집니다.",
    "cooldown": 27.0,
    "windup_seconds": 0.0,
    "roar_radius_by_level": [180.0, 198.0, 216.0, 234.0, 252.0],
    "ball_boost_by_level": [2.6, 2.85, 3.1, 3.35, 3.6],
    "card_texture_path": "res://assets/sprites/lingpet/monkeyring_wild_roar_skillcard_imagegen_v1.png",
    "icon_texture_path": "res://assets/sprites/lingpet/monkeyring_wild_roar_skill_icon_imagegen_v1.png",
}
```

- `*_by_level` 평탄화는 카탈로그 측 **제네릭 서픽스 스캔**(:1444-1456)이라
  카탈로그 등록 불필요 — 하드코딩 리스트는 §6.3 launch_context 쪽뿐.
- validator는 card 실존 필수 + icon 키 존재 시 실존 검사(:1282-1287) →
  **아트가 카탈로그 배선보다 먼저** 리포에 들어와야 한다 (banana §7 동일).
- 설명문에 고정 배율 숫자 금지 — 레벨·거리에 따라 변하므로 추상 문구
  (`description_by_level` 불가 — float 평탄화 트랩).
- 멀티 풀 시멘틱: 기존 로드아웃이 이기고, 신규 부화 시
  `pick_skill_loadout`이 풀에서 **균등 랜덤** 선택(:1113-1127), 스테일
  세이브는 pool[0] 폴백(:1019-1028). F7 피커는 Q/E로 두 스킬을 자동
  사이클(피커 측 코드 변경 0) — 빠나몽 부화가 이제 두 스킬 중 하나를
  랜덤으로 받는 것은 기존 시스템 동작이며 의도로 수용.

### 스킬 클래스 공개 API (호스트 계약 — banana와 동일 + can_arm)
```
reset() / cancel(owner=null, registry=null) / prewarm()      # 텍스처 없음 — no-op에 가까움
can_arm(params: Dictionary) -> bool                          # §3 게이트 (신규 계약)
launch(origin, owner=null, launch_context={}) -> bool        # 즉시 반사 + 부스트 세트
update(delta, owner=null, registry=null, launch_context={})  # ROAR 타이머/링/파티클
draw(canvas, shake_offset=Vector2.ZERO)
is_active() / has_visible_effects()
get_snapshot() -> Dictionary                                 # wild_roar_* 접두 키
has/get_companion_position_override()                        # ROAR 0.6s 동안
get_companion_cast_pose_progress()                           # ROAR 0→1, 그 외 -1
# 테스트 접근자: set_trigger_distance_for_tests(), set_jitter_roll_for_tests(),
#   get_phase_for_tests(), get_actual_boost_for_tests(), force_roar_for_tests() 등
```

---

## 7. 자산

| 자산 | 형식 | 비고 |
|------|------|------|
| 충격파 링/존/스파크/파티클/플래시 | **전부 절차적** (`draw_arc`/`draw_circle`/`draw_rect`) | 원본 팔레트 충실: 골드 링 (255,210,60)/(255,250,150) 코어, 존 (255,200,50, α25~45) + 24방위 방사선, 에너지 스파크 골드-오렌지 **5색**(:17873-17876) / 임팩트 파티클 **6색**(:18021-18024). 회전 변환 없음 → draw_set_transform 트랩 비해당 |
| 풀스크린 플래시 | 절차적 rect (255,240,180) — 상태값 200(발동)/255(임팩트), 800/s 감쇠, **드로우 α = min(state, 120)** (원본 :18091 — 상태값과 렌더 캡은 둘 다 의도) | **게임 캔버스 전폭(0..WIDTH)** — 80..680으로 좁히지 말 것 (`[[feedback_godot_playfield_letterbox_reality]]`) |
| 공 글로우 (반사 후) | 절차적 3중 원 — update에서 ball_pos를 멤버에 캐시해 draw에서 사용 | 임팩트 파티클 잔존 동안만 (원본 :18163-18172) |
| 포효 사운드 | **포팅** `sounds/monkeyshouting.wav` → `godot/assets/sounds/lingpet/` | §6.5. 1.45s 원샷 |
| 스킬 카드 | **신규** `monkeyring_wild_roar_skillcard_imagegen_v1.png` | 1720×541 (banana 카드 규격), 매니페스트 JSON 동봉 |
| 스킬 아이콘 | **신규** `monkeyring_wild_roar_skill_icon_imagegen_v1.png` | 1254×1254 (banana 아이콘 규격). 모티프는 원본 아이콘 충실: 포효하는 원숭이 얼굴 + 황금 동심 충격파 링 3중 + 대각 광선 (hero_skill_icons.py:1359-1413 팔레트) |
| 캐스트 포즈 | 기존 `companion_cast` 슬롯 (빠나몽은 현재 walk placeholder 공용) | 전용 포효 시트는 빠나몽 뒷모습 SD 시트 제작 시 후속 |

- 신규 스프라이트 **시트** 없음 → AutoSprite 의무 비해당 (카드/아이콘은
  스틸 — imagegen 허용). 텍스처 로드가 아예 없으므로 `prewarm()`은 모듈
  생성 자체가 프리웜 (로드아웃 적용 시 `_prewarm_current_skill_runtime`이
  커버 — 핫패스 lazy-init 트랩 §9).
- 스크린 셰이크: `battle_feedback_state.max_screen_shake` — 반사 시
  0.085/1.4(원본 20px/0.5s급), 헛포효 0.045/0.9(원본 12px/0.4s급).
  bomb_surprise(0.080/1.40) 스케일 기준, QA에서 체감 튜닝.

---

## 8. 스모크 브리프 (효과의 **결과**를 단언)

공 수동 전진은 `vel * delta * 60`으로 런타임과 동일하게
(`[[feedback_godot_ball_vel_pxframe_units]]`). 실패 방향 먼저 작성해 가드 검증.

| ID | 단언 |
|----|------|
| S1 | 카탈로그/디스패처/호스트 형태: `validate_catalog(true)` 통과, `runtime_kind` 해석, `is_wild_roar`, F7 풀 2행 노출. `lingpet_egg_runtime_smoke.gd` kind/디스패처/호스트 소스 행 추가 포함 |
| S2 | **arm 게이트**: 공 상승 중 → false. 하강 + 세로 창 밖(위) → false. 하강 + 세로 갭 ≤ arm_min_gap → false (**base vy와 캡 vy 26 두 케이스** — 동적 하한이 공속에 연동되는지). 하강 + 창 안 + X반경 내 → true. `skip_ball_motion_step=true` → false. trigger_distance가 쿨다운 사이클당 **정확히 1회** 롤(롤 카운터 단언 — 매 프레임 재롤 회귀 가드) |
| S3 | **반사 결과**: 거리/지터 롤 핀 후 launch → `ball_vel.length() == speed_pre × 기대 boost`(허용오차), `ball_vel.y < 0`(위로), owner 키 2종 세트(`boost_active=true`, `restore_speed==speed_pre`). **60 백스톱은 여기서 단언**: speed_pre를 크게 핀해 product > 60 → `ball_vel.length() == 60`(백스톱 클램프는 모듈의 launch 쓰기 책임 — 캡 면제 중인 프레임 클램프는 이를 집행할 수 없음) |
| S4 | **헛포효 카운터 케이스**: launch 프레임에 공이 반경 밖 **또는 dist≤1 또는 v≈0** → 반사 없음 + 부스트 키 미설정 + 쿨다운 소모 + VFX 활성(is_active) + 약셰이크 호출 (배선 리뷰 v4: v≈0도 휘프로 확정) |
| S5 | **캡 해제 생존**: 진짜 `ball_frame_motion_controller.apply_ball_speed_limits` 구동 — 플래그 on이면 부스트 속도(예: 40) **무변경 유지**, 플래그 off 대조군이면 26으로 클램프(실패 방향 검증). 주의: 캡 면제 중에는 클램프 자체가 통째로 스킵되므로 이 표면에서 60 백스톱을 단언하지 말 것 — 백스톱은 S3(모듈 launch 쓰기) 소관 |
| S6 | **보스 리턴 복원**: 부스트 컨텍스트로 진짜 `paddle_bounce_boss_post_hit_handler.apply()` → `ball_vel.length() == restore_speed`(방향은 바운스 결과 유지), 키 2종 클리어, `speed_limit_disabled=false` 포함. allowlist 전파: `paddle_bounce_controller` 최종 result까지 키 생존 단언 |
| S7 | **라운드 리셋 누수 가드**: 부스트 세트 후 `ball_round_state` 리셋 → 키 2종 디폴트 복귀 (다음 라운드 무한 캡해제 누수 — 이 스킬 최악의 회귀 클래스) |
| S8 | **소스 텍스트 가드**: 모듈의 `owner.set` 대상이 선언 키(ball_vel + 신규 2종)뿐, `skip_ball_motion_step` 미설정, 발동 **성패를 좌우하는** 확률 롤 없음(거리 롤은 `_trigger_distance <= 0` 가드 내부 1곳뿐 — 창 크기만 결정, S2 카운터가 동적 봉인), 호스트 `get_boss_ai_context`에 wild_roar 미등장(D8) |
| S9 | **오디오**: FakeAudio — 반사 launch 1회 + 헛포효 launch에도 1회(원본 충실), update 중 0회 |
| S10 | **경직/포즈**: launch 후 0.6s 동안 위치 오버라이드 true + 캐스트 포즈 progress 단조 증가, 0.6s 후 해제. `is_launch_blocked` 동안 재-arm 금지 |
| S11 | **레벨 스케일**: Lv.1 → radius 180 + boost(근접 롤) 2.6 / Lv.5 → radius 252 + boost 3.6. 카탈로그 평탄화 단언: `get_active_skill("monkeyring", "monkeyring_wild_roar", 1).roar_radius == 180.0`, lv5 `ball_boost == 3.6`. launch_context 미전달(−1.0) 시 모듈 로컬 테이블 폴백 |
| S12 | **스키마 게이트 owner 왕복**: 진짜 `BattleSceneState` 위임 owner로 부스트 키 round-trip (plain-dict FakeOwner만으로는 Owner-Field Schema Trap을 못 잡음 — `character_info_live_stats_smoke` 선례) |
| S13 | **바디히트 단일 바운스**: arm 직후 1틱 전진(공 이동 `vy*delta*60`) → launch 프레임에 공이 바디히트 임계(`half_height + ball_radius` ≈ 41.3) **위**에 있고 반사 1회만 발생(바디 히트 선행 없음 — 동적 하한의 기하 보장 검증). **고속 케이스 필수**: vy = 캡(26 + 랠리 보너스)로도 단언 — 정적 하한 60이 뚫렸던 바로 그 케이스. 카운터: 세로 갭 ≤ arm_min_gap 진입 공은 arm되지 않고 바디 히트/방어 가드가 정상 처리. 휘프 후 ROAR 동결 중 하강 공의 바디 가드 바운스는 **허용 동작**으로 단언 |

---

## 9. 트랩 체크리스트 (이 스킬에 실제 해당)

- [ ] **Owner-Field Schema Trap**: 신규 키 2종 `DEFAULT_VALUES` 선언 필수 — 미선언 `owner.set`은 조용한 no-op (S12).
- [ ] **allowlist 4계층 드랍**: 보스 post-hit result 키는 handler→step→controller 각 층 allowlist에 없으면 조용히 소실 (S6).
- [ ] **컨텍스트 정책 빌드 순서**: mythic/weather가 `speed_limit_disabled=false`를 강제 → wild roar 정책은 **마지막** (§2).
- [ ] **윈드업 키 생략 = 1.0s 폴백**: `"windup_seconds": 0.0` 명시 (D2).
- [ ] **확률 롤 스코프**: 거리 롤 = 사이클당 1회, 지터 = 발동 1회. `can_arm`은 결정적 기하 (S2, S8).
- [ ] **px/frame 단위**: 반사/부스트/백스톱 전부 px/frame, 스모크 공 전진 `vel*delta*60` (S3, S5).
- [ ] **핫패스 lazy-init**: 모듈 생성은 로드아웃 프리웜이 커버, 텍스처 0장. `can_arm` 디스패치는 기존 행 패턴.
- [ ] **owner-less cancel**: 부스트 owner 키는 모듈이 아니라 라운드 리셋이 청소 — fire-and-forget 명시 (§4, S7).
- [ ] **재-arm 금지**: `is_launch_blocked = is_active()` (S10).
- [ ] **바디히트/방어 인터셉트 인터플레이**: egg_runtime은 바디히트(:198)를 스킬 업데이트(:200)보다 먼저 해석 + 바디히트 임계 `half_height + ball_radius`(빠나몽 ≈41.3) + defense_rate 0.16. **동적** arm 하한(임계 + vy×1.5 + 마진)이 launch 프레임 반사 선행을 기하로 보장 — 정적 60은 캡 공속에서 뚫림 (S13 고속 케이스). `suppresses_companion_body_hit`은 QA 폴백 레버.
- [ ] **풀스크린 플래시 클립**: 게임 캔버스 전폭, 80..680 축소 금지 (§7).
- [ ] **fire weather 상호작용**: 35 상한은 패들 바운스 시점에만, 비행 중엔 캡 경로 통째 스킵 — 드론과 동일 수용 (§2).
- [ ] **공 글로우 draw 데이터**: draw()에 owner가 없으므로 ball_pos는 update에서 멤버 캐시 (§7).
- [ ] **로컬라이즈**: 링펫 스킬 카탈로그 명/설명은 현행 9+ 스킬 전부 한국어-only 컨벤션(`language_settings_data.gd` 0건) — 이 슬라이스도 동일 적용. 단, EN/JP/CN UI에서 원문 노출되는 **기존 전 스킬 공통 백로그**임을 기록 (`[[feedback_godot_localization_copy_sync]]` — 신규 한 건만 번역하는 비일관 대신 일괄 백로그).

> 적대적 리뷰 완료 (2026-06-12, 3렌즈: 원본 충실성 / Godot 배선 / 트랩·설계
> 구멍): 캡 면제 4포인트·consume/병합·allowlist 4계층·스냅샷/리셋 지점·프레임
> 순서(update_ball → update_lingpet, 같은 프레임 내 ball_vel 클로버 없음 —
> effects result applier는 result.has() 게이트 고정 키 리스트라 비간섭)·
> 카탈로그/디스패처/F7/오디오 팩토리·원본 수치 전부 코드로 재검증 통과.
> 리뷰로 적용한 수정 6건: (1) dist≤1 = 순수 헛포효(원본 :17903 `dist > 1`
> 가드 — vy 반전+부스트 폴백은 in-range 내부 r_len==0 분기였음, §3/S3/S4
> 정정), (2) 거리 롤 사이트를 `_trigger_distance <= 0` 가드 1곳으로 못박고
> S8 소스 가드 문구와의 모순 해소, (3) **바디히트/방어 인터셉트 인터플레이
> 결정 추가** — arm 세로 하한 60 신설 + S13 봉인(리뷰 최대 발견), (4) 스키마
> 선언 앵커 :236-238 → :278-280 + ringpet_ 별칭 불필요 명시, (5) fire weather
> 35 상한은 바운스 시점 한정으로 정정, (6) 충격파 중심 고정을 의도적 분기로
> 부록 B 등재 + 임팩트 파티클 6색 정정. S5/S6 스모크 실행 선례 확인:
> `commando_firearm_suicide_drone_ball_boost_resolver_smoke.gd`가
> `apply_ball_speed_limits`를 직접 구동한다.

> 배선 리뷰 v4 — 구현 검수 합격 (2026-06-12, 배선=사용자/Codex): 4관문 전부
> 통과(① 동적 arm_min_gap 계약 일치 + gap61/vy26 차단 스모크, ② 진짜
> BattleSceneState 왕복, ③ 고속 공 기하 봉인, ④ wav/png/.import 7자산 실존 +
> 스모크 단언), 공속 채널 전 지점(면제 3 + 정책 마지막 순서 + consume +
> allowlist 3계층 + 스냅샷 2 + 스키마/리셋 2) 누락 0, 오디오 4표면 + 스모크
> 독립 재실행 통과. **구현이 기획서보다 안전한 분기 3건을 채택**하고 문서를
> 구현에 맞춤: (1) v≈0 퇴화 = 순수 휘프(부스트 키 미설정 — restore_speed 0인
> 채 언캡되는 원본 구멍 회피; §3 폴백 절 폐기), (2) 반사 안전 플립 = 순수
> 미러 대신 상향 바이어스(reflect_dir.y ≥ -0.01이면 -0.18 가산 정규화 —
> 수평 근접 60px/frame 공 방지), (3) 모듈 cancel(owner)/host.reset(owner)가
> 비행 중 부스트 키도 클리어(펫 스위치 고아 부스트 방지 — "fire-and-forget
> 유지" 절보다 보수적, 라운드 리셋 위임은 owner-less 경로 한정). 잔여 권고
> 씰 4건은 §10-7 참조.

> 적대적 리뷰 v3 — 사용자 코드 리뷰 5건 반영 (2026-06-12): (1) **[major]
> 정적 arm 하한 60 기각** — 바디히트 트리거는
> `dy <= half_height + ball_radius`(`lingpet_companion_body_hit_state.gd:67`,
> 빠나몽 ≈41.3)라 갭 61 + vy 26이면 launch 프레임에 바디히트가 선행한다.
> 동적 하한(임계 + vy×1.5 + 마진 6, 임계는 바디히트와 동일 소스에서 파생)
> 으로 교체 + S2/S13에 캡 공속 케이스 추가. (2) 60 백스톱 단언 표면 정정 —
> 캡 면제 중 `apply_ball_speed_limits`는 클램프를 통째로 스킵하므로
> 백스톱은 모듈 launch 쓰기 소관(S3로 이동, S5는 무변경 통과만). (3) 사운드
> 자산에 임포트 패스 + `.wav.import` 사이드카 커밋 요건 추가(에디터 raw
> 디코드가 익스포트 누락을 가림). (4) 오디오 셋업 표면 2곳 명시 — factory
> 생성 블록(:654 옆) + `_get_audio_setup_stream_paths`(:857)의 링펫 경로
> 목록(:949). (5) 플래시 알파 "충돌" 해명 — 원본부터 상태값 200/255 +
> 드로우 min(state,120) 캡의 2단 구조(:18091), 양쪽 표기를 통일.

---

## 10. 완료 결정 / 오픈 항목

1. **쿨타임** — 원본 충실 27s.
2. **레벨 테이블** — D6: radius [180..252] + boost [2.6..3.6], 거리 변조 폭 1.0 유지.
3. **카드/아이콘 아트** — `monkeyring_wild_roar_skillcard_imagegen_v1.png` /
   `monkeyring_wild_roar_skill_icon_imagegen_v1.png` + 매니페스트를 리포에
   추가한 **뒤** 카탈로그 배선 (validator 실존 검사).
4. **사운드 포팅** — `monkeyshouting.wav` → `godot/assets/sounds/lingpet/` +
   임포트 패스 실행 후 `.wav.import` 사이드카 동반 커밋 + 셋업/프리웜
   표면 2곳 등록 (§6.5).
5. **셰이크 체감 튜닝** — 0.085/1.4(반사), 0.045/0.9(헛포효)는 제안값, 인게임 QA에서 확정.
6. **부스트 백스톱 60 px/frame** — 제안값. 보스 패들 충돌 실측 QA(S5 + 라이브)에서 터널링 없으면 유지.
7. ~~잔여 권고 씰 4건~~ → **전부 봉인 완료 (2026-06-12, 리뷰 v4 후속)**:
   (a) 라운드 리셋 — `_verify_round_reset_clears_wild_roar_boost`
   (common + reset 스냅샷 양쪽), (b) allowlist 체인 — 진짜
   `PaddleBounceController.bounce()` 보스 경로로 4키 생존 + consumed +
   `speed_limit_disabled` 클리어 단언
   (`_verify_allowlist_chain_preserves_wild_roar_consume`), (c) 클램프
   표면 — off→26 / on→60 유지 / 클리어 후 재클램프 3단 대조
   (`_verify_apply_ball_speed_limits_on_off`), (d) 롤 1회 — 같은 사이클
   can_arm 2회 동일 롤 + launch 후 다음 사이클 새 롤 소비
   (`_verify_trigger_distance_roll_is_per_cycle`). 검수자 독립 재실행 통과.
8. **라이브 QA 항목**: 바디히트-스킬 통합 단일 바운스(스모크는 기하 수준만
   봉인), 셰이크 체감(0.065/2.2 vs 0.025/0.85), 60px/frame 보스 패들 터널링.
9. **선택**: 카탈로그 설명문에 "보스가 받아칠 때까지 속도 제한 해제" 문구
   추가 여부 (현재 설명은 반경/배율만 언급).

---

## 부록 A — 수치 빠른참조 (원본 → Godot)

| 항목 | 원본 (hero_skills.py:17733-17748) | Godot 포팅값 |
|------|------|------|
| 충격파 반경 | 252 px 고정 | **레벨별 180~252** (D6) |
| 확장 시간 | 0.09s | 동일 (비주얼 전용) |
| 공속 배율 | 2.6x~3.6x (랜덤 발동거리 기반) | **레벨별 최대 2.6~3.6**, 거리 변조 폭 1.0 동일 |
| 발동 거리 롤 | 150~230 px, 사이클당 1회 | radius×0.595 ~ radius×0.913, 사이클당 1회 (Lv.5 = 150~230 재현) |
| 발동 판정 | 접근 중 + 0 < Y거리 ≤ 롤값 + X거리 ≤ 반경 | 동일하되 **동적 세로 하한 신설** (하강 vy>0 기준, §3·부록 B) |
| 반사 | 법선 반사 + ±30° 지터 + 골대 방향 금지 2중 안전장치 | 동일 |
| 반사 시점 | 발동 프레임 즉시 | 동일 (windup 0.0) |
| 캡 해제 | 메인게임: 직접 vel 쓰기 + 100 백스톱, 보스 리턴까지 생존 | `speed_limit_disabled` 채널 + 60 백스톱 |
| 속도 복원 | 보스 리턴 시 방향 보존·원속 복원 + 플래그 클리어 (pingfighter.py:173941) | `paddle_bounce_boss_post_hit_handler` consume 동일 수학 |
| 시전 경직 | 0.6s 스턴 + 포효 포즈 | 0.6s 위치 오버라이드 + 캐스트 포즈 |
| 쿨타임 | 27s (+투기장 글로벌 5s 별도) | 27s (글로벌 인터벌 없음 — 링펫 단일 스킬) |
| VFX 수명 | duration 1.8s, 조기 종료(링 페이드 + 파티클 0) | 동일 |
| 셰이크 | 12/0.4s 헛포효, 20/0.5s 반사 | 0.045/0.9, 0.085/1.4 (max_screen_shake) |
| 사운드 | monkeyshouting.wav vol 0.7, 반사 여부 무관 재생 | 동일 wav 포팅, −4dB, 피치 0.96~1.04 |

## 부록 B — 원본 대비 의도적 분기

| 항목 | 원본 WildRoar | 이 포팅 |
|------|---------------|---------|
| 트리거 | ON_COOLDOWN + 0.5s 폴링 + 스타일 RNG(0.5~0.85) + 영웅 글로벌 5s 인터벌 + `_ball_in_range` | **링펫 오토캐스트 + `can_arm` 결정적 근접 게이트** (RNG 발동 확률 없음 — 창에 들어오면 무조건 발동) |
| arm 세로 하한 | 0 (시전자 = 패들 자신, 패들 충돌과 스킬이 일체) | **동적 하한 신설** — 바디히트 임계(≈41.3) + vy×1.5 + 마진. 링펫 바디히트(스킬보다 선행 해석)와의 이중 바운스를 기하로 차단 (§3, S13) |
| v≈0 퇴화 | vy 반전 × boost + `wild_roar_boosted` 세트 (:17924-17926) | **순수 휘프로 기각** — restore_speed 0인 채 언캡 플래그만 남는 원본 구멍 회피 (배선 리뷰 v4) |
| 반사 안전 플립 | `sin(angle)>0 → angle=-angle` + 최종 vy 반전 (수평 근접 허용) | **상향 바이어스** — `reflect_dir.y ≥ -0.01`이면 `-0.18` 가산 정규화. 수평 근접 60px/frame 공의 무한 벽핑퐁 방지 |
| 발사 후 부스트 소유 | (등가물 없음 — 시전자가 게임 자체) | cancel(owner)/host.reset(owner)는 부스트 키도 클리어(펫 스위치 고아 부스트 방지). owner-less 라운드 정리만 `ball_round_state` 리셋에 위임 |
| 충격파 VFX 중심 | 매 프레임 시전 패들 추적 (:17968-17973) | **발사 프레임 고정** — ROAR 0.6s간 컴패니언이 어차피 고정, 잔여 링은 빠른 페이드라 분리 체감 미미. 반사 판정은 원본도 발동 순간 중심 |
| 레벨 | 없음 (고정 상수) | **Lv.1~5 radius/boost 테이블** (사용자 요구 사양) |
| 시전자 | 영웅 패들 자신 (상/하단) | 빠나몽 컴패니언 (플레이어 진영) → 반사는 항상 위(보스) 방향 |
| 경직 표현 | game_state 스턴 플래그 | 컴패니언 위치 오버라이드 + 캐스트 포즈 (외부 플래그 없음) |
| 캡 해제 메커니즘 | 메인게임 암묵(직접 쓰기가 클램프를 그냥 통과, 백스톱 100) / 투기장은 다음 패들 충돌서 18.75 클램프로 암살 | **명시적 `speed_limit_disabled` 채널** (자폭드론 인엔진 컨벤션) — 메인게임 모델 채택, 투기장 모델 기각 |
| 플레이어 재타격 시 | (도달 불가 경로) | 부스트 유지 — 드론 패리티로 수용 |
| 마법 면역/패링 | magic_immunity 체크 (투기장 전용) | 생략 — banana와 동일 인엔진 패리티 |
| 사운드 로드 | pygame mixer lazy 로드 | `game_audio` 래퍼 + 팩토리 등록 |
