# 각시탈 (Gaksital) Stage 1 보스 포팅 — 설계 / 슬라이스 플랜

> 단일 소스(single source of truth). 각시탈을 Godot **환격전**
> 스테이지 1의 **두 번째 보스**로 추가하는 작업의 설계·신호계약·슬라이스·트랩
> 브리프. 런타임 GDScript 배선은 사용자/Codex가 이 문서를 보고 수행하고,
> Claude는 스프라이트 아트 디렉션 + 적대적 리뷰를 담당한다
> (`feedback_design_slice_review_division`, 자산 워크플로 분담).

상태: **슬라이스 1~4(MVP) + 5a/5b(fan_wind 런타임) + 5c(아트 패스) + 카오스
스피어 흡수 배선 완료** (2026-07-03, 미커밋). 5a/5b = 사용자 배선 + Claude
적대리뷰 APPROVE + 반증검증. 5c = 소용돌이 16f AutoSprite 시트 + 스킬카드
PNG 생성·배치·배선. 리뷰 후속(P1/P2): 렌더러 draw()를 플랫 시퀀스로 재구조화
(_draw_fans 분리, fan_wind 렌더가 팬 리스트에 절대 게이트되지 않음 —
구조 씰 포함) + 카오스 흡수 실배선(§2b.4-1c). 게이트(headless load /
warning scan / 스모크 / 반증검증) 전부 GREEN. 잔여 = 인게임 라이브 QA, 커밋.

---

## 0. 확정된 범위 결정 (재론 금지)

사용자 결정 (2026-06-23):

1. **아키텍처 = 얇은 변형 셀렉터.** Python식 풀 보스-로스터 시스템을
   지금 만들지 않는다. 전역 context에 통과시키는 얇은 보스-정체성 키
   **`stage1_boss_variant`** (`"dalji"` | `"gaksi"`)만 도입하고,
   **스테이지 1의 리소스 / 스킬 / HUD / result 모듈만** 그 키로 분기한다.
   - **기본값은 반드시 `"dalji"`.** variant 미지정 / 레거시 세이브 / 기존
     모든 경로는 달지로 100% 동일 동작해야 한다 (회귀 스모크로 봉인).
   - 1차: 디버그(F5 picker)로 `gaksi` 강제 선택 가능.
   - 랜덤 선출 / 메뉴 선택 UI / 풍악보이·포도대장 확장은 **후속 슬라이스**.
     이 키는 나중에 풀 로스터로 키울 수 있는 "씨앗"이지, 지금 로스터를
     만드는 게 아니다.
   - **룰렛 현황(2026-07-04)**: 랜덤 선출 인프라는 배선 완료 —
     `battle_scene_selection_startup_lifecycle.resolve_stage1_boss_variant`가
     비명시(일반) 진입에서 `STAGE1_RANDOM_BOSS_VARIANTS` 풀 추첨, 디버그
     강제선택(`stage1_boss_variant_explicit`)은 룰렛 우회. **사용자 결정:
     각시탈/포도대장이 릴리즈 준비될 때까지 풀 = `["dalji"]` 단독** (스모크
     `battle_scene_selection_startup_lifecycle_smoke`가 달지-only 풀 +
     비명시 진입 48회 전부 달지 + explicit 우회 유지를 봉인, 반증검증 완료).
     재개방 = 풀 상수에 `"gaksi"` / `"podo"` 재추가 + 스모크 단언 갱신.
2. **스킬 범위 = `fan_throw`(부채던지기)만 (MVP).** 달지 팽이(`spinning_top`)
   미러. `fan_wind`(부채바람, 공 포획 소용돌이)는 **2차 슬라이스**
   — owned-ball(`skip_ball_motion_step`) 방출 트랩 영역이라 위험도가 한 단계
   높다. 이번 MVP에 넣지 않는다.

---

## 1. 원본 각시탈 정체성 (포팅 레퍼런스)

출처: `entities/talkwangdae_boss_sprite.py` (절차적 pygame, 코드명
`talkwangdae` = 탈광대, 변형키 `gaksi`), `config/stage_configs.py`
`BOSS_VARIANTS[1]["각시탈"]`, `downtown/boss_dialogues.py` `(1, "각시탈")`.

- **비주얼**: 붉은 **하회탈**(하회 별신굿탈) + **색동저고리**(무지개 줄무늬
  전통 저고리) + **부채**. 과장된 **광대(廣大)** 동작 — 어깨/허리 흔들기,
  너스레, 발놀림.
- **피격 연출**: "탈 벗겨짐" — 피격 시 탈이 들리며 회전(`mask_offset_y`,
  `mask_rotate`) + 넉백. (Godot 포팅에서는 stun 시트로 표현; 탈-벗겨짐을 별도
  연출로 살릴지는 아트 디렉션 단계 판단.)
- **색 팔레트**: 하회탈 붉은색 `(200, 50, 50)`, 부채 천 크림색
  `(220, 200, 160)`, 부채 림 붉은색 `(185, 55, 55)`.
- **스탯**: `BOSS_VARIANTS[1]["각시탈"]` = `**BOSS_CONFIGS[1]`(풍악보이)와
  **완전 동일**, `color`와 `special_skill`만 다름. → Godot에서도 달지의 AI/
  대쉬/난이도 스탯을 그대로 쓰면 된다 (별도 튜닝 불필요한 게 기본).
- **성격/대사** (`(1, "각시탈")`): 장난꾸러기 트릭스터. 전투시작
  "히히히! 자, 놀아보자꾸나~!", 피격 "맞았지롱~!" 류. (Godot에 인게임 보스
  VO 시스템이 아직 없으면 result-click 반응 대사로만 살린다 — §5.4.)

---

## 2. 시그니처 스킬 — `fan_throw` (부채던지기)

출처: `pingfighter.py` `activate_fan_throw()` (L105376), `_launch_fan_throw()`
(L105385), `update_fan_throw()` (L105428), 상태변수 L67273+, 부채 그리기
`_draw_fan_shape()` L105554.

### 2.1 메커니즘 (Python 원본, 단위 px/frame @ 60fps)

> ⚠️ Godot 단위 트랩: 이 엔진의 `ball_vel`/투사체 속도는 **px/frame**
> (`feedback_godot_ball_vel_pxframe_units`: 공속 base 7.65, 캡 ~26). 매프레임
> 이동은 `pos += vel * fps_scale` (`fps_scale = delta * 60`,
> `ball_update_controller`). 아래 숫자는 **그대로** px/frame로 이식 — px/sec로
> 환산하지 말 것.

| 단계 | 값 / 동작 |
|---|---|
| 발동(activate) | windup 30프레임(0.5초) 휘두르기 선딜 → launch |
| launch 위치 | 보스 중심 하단 `(BOSS.centerx, BOSS.y+BOSS.height)` |
| 조준 | 플레이어 방향 정규화 벡터 × speed `5.5` + vx에 `±0.8` 랜덤 jitter |
| 지속 | timer `180`프레임(3초) 또는 게임영역 이탈 시 소멸 |
| 이동(나비 날갯짓) | `speed_mod = 0.6 + 0.5*sin(elapsed*0.25)` (속도 변조 0.1~1.1), `sway = sin(elapsed*0.15)*1.8` (좌우 사행), `x += vx*speed_mod + sway`, `y += vy*speed_mod*1.3` (Y 30% 빠름) |
| 회전 | `spin += 0.3`/frame, 2π 경계마다 부채 사운드 |
| 플레이어 충돌 | `hit_radius 24` + `PLAYER.width//2` 원충돌 |
| 충돌 효과 | 0.3초 스턴(`try_apply_player_stun(0.3, source="stage1_fan_throw")`) + 넉백 `player_knockback_vel = ±12` 랜덤 + 타격이펙트 24프레임 + 대사 "맞았지롱~!" |
| 면역 | **연막(smoke) 안이면 부채공격 면역** ("연막 속에 숨었다!") |
| 광폭화(enraged) | launch 시 base 각도 ±35°로 **추가 부채 2발** 동시 발사 (각자 동일 이동/충돌) |
| 비주얼 | 절차적 부채 폴리곤 (6 ribs, 70° spread, 크림 채움 + 붉은 림) |

### 2.2 Godot 포팅 = 달지 `spinning_top` 거의 1:1 미러

달지 팽이(`stage1_dalji_spinning_top_skill_state.gd`)와 fan_throw는 구조가
사실상 동일하다 (**보스 중심에서 N개 이동 해저드 스폰 → 매프레임 이동 →
플레이어/공 충돌**):

| spinning_top (템플릿) | fan_throw (포팅) |
|---|---|
| `can_activate(context)` → `should_roll_activation(gauge)` → `activate(context, deps)` | 동일 인터페이스 |
| 보스 중심에서 `NORMAL_OFFSETS`/`ENRAGED_OFFSETS`로 N개 top 스폰 (payload factory) | 보스 중심 하단에서 플레이어 조준 1발 + 광폭화 시 ±35° 2발 |
| `update_and_collide(fps_scale, scene, context, deps)` 매프레임 | 동일 — windup 카운트다운 → launch → 나비이동 → 충돌 |
| top↔공 충돌, top↔top 충돌 | 부채↔플레이어 충돌(스턴+넉백), 연막 면역 |
| `get_draw_context()` → 렌더러가 그림 | 동일 — 부채 위치/회전/광폭화 추가발 노출 |
| 쿨다운/HUD는 `stage1_dalji_boss_skill_cooldown_state`가 charge→ready→activate→casting 관리, `TRIGGER_INSTANT` | 동일 — 부채던지기도 `TRIGGER_INSTANT`(충전 완료 시 자동 발동) |

**신호 계약 (fan_throw skill state, RefCounted):**
- `reset()` / `reset_round()` — 활성/투사체/타이머 전부 초기화.
- `can_activate(context) -> bool` — `current_stage==1 and stage1_boss_variant=="gaksi" and not active`.
- `should_roll_activation(gauge, context) -> bool` — gauge ≥ COST and can_activate.
- `activate(context, deps) -> bool` — windup 시작(30f), 위치/조준은 launch 시점에 라이브 재계산(보스/플레이어 위치는 launch 프레임 기준).
- `update_and_collide(fps_scale, scene, context, deps) -> Dictionary` — windup 틱 → launch → 나비이동 → 영역 컬링 → 플레이어 충돌(연막 면역 우선) → 스턴+넉백 반환. 광폭화 추가발 동일 처리.
- `get_draw_context() -> Dictionary` — `stage1_fan_throw_active`, 부채 [(x,y,spin)] 리스트(메인+광폭화), windup 진행률, 타격이펙트 위치/잔여.
- `is_active() -> bool`.

**충돌 = 순수 거리 원충돌** (`feedback`의 radial CC 트랩: 비주얼이 닿았다고
판정하지 말고 중심거리 명시). `hit_radius 24 + player_half_width`.

**스턴/넉백**: Godot 플레이어 스턴 시스템 + 넉백 채널을 **단위 1:1**로 사용
(`feedback_godot_boss_knockback_port_parity`: power는 Python @60fps ↔ Godot
`*fps_scale` 1:1, 형제 상수 빌려쓰기 금지). 넉백 ±12 px/frame 그대로.

---

## 2b. 2차 스킬 — `fan_wind` (부채바람, 공 포획 소용돌이)

출처: `pingfighter.py` `activate_fan_wind()` (L107560), `update_fan_wind()`
(L107586), `check_fan_wind_effect()` (L107664), `draw_fan_wind_effect()`
(L107687), 상태변수 L67602+, 트리거 L173963(보스 공 타격 핸들러), 카오스
스피어 흡수 상호작용 L6260.

> ⚠️ 이 스킬은 CLAUDE.md **owned-ball(`skip_ball_motion_step`) 트랩의 정면
> 대상**이다. §2b.4의 체크리스트 매핑을 배선 전에 전부 읽을 것. 숫자는 전부
> **px/frame** — §2의 단위 트랩 동일 적용.

### 2b.1 메커니즘 (Python 원본, px/frame @ 60fps)

| 단계 | 값 / 동작 |
|---|---|
| 트리거(원본) | **보스가 공을 쳐낸 프레임**에 게이지≥150 & 20% 롤 & 라운드당 1회(`fan_wind_used_this_round`). 발동 대사 3종 랜덤: "소용돌이!" / "빨려들어라~!" / "회오리바람!" (90f) |
| 충전(charging) | 60f(1초) 부채질 선딜. 소용돌이 성장 `growth_scale = 0→1`. 충전 중 소용돌이 이동 없음 |
| 소용돌이 스폰 위치 | `x = 보스중심x + rand(-30, 30)`, `y = 보스 bottom + 10` (발동 시점 고정, launch 재계산 없음 — fan_throw와 다름) |
| 활성(active) | timer `240f`(4초). 충전 완료 시 active 전환, scale 1.0 고정 |
| 소용돌이 이동 | `y += 0.6`/f (하강), `x += drift_vx`. drift_vx 초기 `±1.2` 균등, `25~55f`마다 `±1.5`로 재추첨. X 클램프 `[110, 650]` 도달 시 부호 반사 |
| 만료 | `timer <= 0` 또는 `y > 720` (240f×0.6=144px 하강 한계라 y-조건은 실질 도달 불가 failsafe — 삭제하지 말고 유지) |
| 포획 체크(공 경로) | active && !captured && `dist(공중심, 소용돌이) < 42` → 포획. `capture_radius = max(dist, 8)`, `capture_angle = atan2(dy,dx)`, `ball_vel = (0,0)` |
| 포획 상태(60f) | 공이 소용돌이 궤도 공전: progress<0.6 → `radius *= 0.96`/f (min 3), 이후 → `radius *= 1.06`/f (max 55). `spin_speed = 0.25 + progress*0.35` rad/f. **공 위치 = 소용돌이중심 + polar(angle, radius) 직접 기록, vel 0 유지** |
| 포획 해제(60f 경과) | `angle = uniform(0, 2π)`, `speed = uniform(12, 16)`, `vy = abs(vy)` 하향 강제 → 일반 물리 복귀 |
| 만료 시 포획 중이면 | `angle = uniform(-0.8π, -0.2π)`, `speed = 13`, `vy = abs(sin)*13` 하향 → 일반 물리 복귀 |
| 카오스 스피어 흡수 | 바이퍼 카오스 스피어 앱소브 펄스가 charging/active 소용돌이를 **흡수** — 펄스 VFX + 오브젝트 골드 지급 + fan_wind 상태 전체 클리어 (L6260-6269) |
| 면역/대상 | **플레이어 직접 효과 없음** (fan_throw의 스턴/연막면역과 무관). 공만 건드린다 |
| 비주얼 | 충전: 보스 위치에서 부채질 스윙+잔상+바람줄기(보스→소용돌이). 본체: 바람구름 8원 + 나선 8겹 + 밝은 코어 + 알갱이 노이즈 (절차) |

### 2b.2 Godot 매핑 결정 (권장안 — 배선 전 사용자 확정)

- **D-FW1 트리거 = whip(상모돌리기) 패턴 미러 (권장).** 쿨다운 상태에
  `SKILL_FAN_WIND` 카드 추가, `TRIGGER_ON_BOSS_HIT`, 쿨다운 `1200f` 제안
  (whip 1320f / fan_throw 960f 사이). ready 상태에서 다음 보스 공 타격 시
  `consume_on_hit("fan_wind")` 발동. Python의 게이지150+20%롤+라운드1회는
  "랠리당 대략 1회, 보스 히트 타이밍"의 구현이었고, 쿨다운+온히트가 같은
  체감을 재현한다 — **20% 롤과 `used_this_round` 플래그는 폐지** (의도
  분기로 기록). 대안: ready 중 보스히트당 20% 롤 유지(체감 지터만 추가됨,
  비권장).
- **D-FW2 로밍 클램프 = Python 값 `[110, 650]` 유지 (권장).** 이것은 화면
  클립이 아니라 **해저드 로밍 밴드**다 — 플레이필드-레터박스 규칙(§AGENTS
  "Playfield / Pillar / Overlay Clip Reality")의 클립 금지 대상이 아니고,
  아이템 스폰 밴드(80..680)와 같은 부류. 원본 게임플레이 도달 범위 패리티
  우선. 대안: 풀캔버스 `[30, 730]`.
- **D-FW3 소용돌이 비주얼 = AutoSprite 16f 루프 시트 + 절차 액센트 (권장).**
  CLAUDE.md "Runtime Skill-Effect Sprite Sheets" 기본(4×4 16f 루프)을 소용돌이
  본체에 적용, 충전 부채질/바람줄기는 절차 라인 액센트(3-피스 방법론). 대안:
  Python 절차 나선 풀 포팅(바람구름+나선 8겹 — draw 비용 주의, 매프레임
  polyline 8겹).
- 발동 대사 3종("소용돌이!"/"빨려들어라~!"/"회오리바람!")은 기존 각시탈
  대사 경로가 있으면 그 경로로, 없으면 이번 슬라이스에서 보스 스피치를
  포팅하지 않고 **대사 생략을 명시 기록** (트랩 §6-9 다국어 동기화가 조건).

### 2b.3 신호 계약 — `stage1_gaksital_fan_wind_skill_state.gd` (RefCounted)

상수(전부 px/frame): `CHARGE_FRAMES 60`, `DURATION_FRAMES 240`,
`SPAWN_X_JITTER 30`, `SPAWN_Y_OFFSET 10`, `DESCENT_PER_FRAME 0.6`,
`DRIFT_INIT_MAX 1.2`, `DRIFT_REROLL_MAX 1.5`, `DRIFT_REROLL_MIN_FRAMES 25`,
`DRIFT_REROLL_MAX_FRAMES 55`, `ROAM_LEFT 110.0`, `ROAM_RIGHT 650.0`,
`CAPTURE_RADIUS 42.0`, `CAPTURE_DURATION_FRAMES 60`, `ORBIT_SHRINK 0.96`,
`ORBIT_GROW 1.06`, `ORBIT_MIN 3.0`, `ORBIT_MAX 55.0`, `SPIN_BASE 0.25`,
`SPIN_GAIN 0.35`, `RELEASE_SPEED_MIN 12.0`, `RELEASE_SPEED_MAX 16.0`,
`EXPIRE_RELEASE_SPEED 13.0`, `FAILSAFE_Y 720.0`.

- `reset()` / `reset_round()` — charging/active/captured/타이머 전부 초기화.
  **포획 중 teardown이면 반환할 공 상태가 없으므로**, 라운드 경계는
  `ball_round_state.build_common_snapshot`의 skip 정규화 레이어(§2b.4-1d)가
  공을 회수한다 — reset 자체가 ball을 만지지 않는다.
- `can_activate(context) -> bool` — stage1 + gaksi + not charging/active.
- `try_consume_boss_hit(context, deps) -> bool` — 보스 공 타격 시 호출
  (whip `register_boss_hit` 미러). 쿨다운 `consume_on_hit("fan_wind")` 성공
  시 charging 시작 + 소용돌이 위치 시드(보스 위치는 이 프레임 기준).
- `update_and_collide(fps_scale, scene, context, deps) -> Dictionary` —
  **ball path 전용 틱** (§2b.4-2). charging 카운트다운 → active 이동/만료 →
  포획 체크(공 위치는 scene에서) → 포획 궤도 갱신 → 해제. 반환 dict:
  `skip_ball_motion_step`(포획 중 true / 해제 프레임 false),
  `ball_pos`(포획 중 궤도 위치), `ball_vel`(해제 시 실속도), 만료/흡수 정리.
- `notify_absorbed_by_chaos_spear(context, deps) -> Dictionary` — 카오스
  스피어 흡수 훅. 상태 클리어 + **포획 중이었으면 해제 속도 반환**(§2b.4-5).
- `get_draw_context() -> Dictionary` — `stage1_fan_wind_active` /
  `stage1_fan_wind_charging`, 소용돌이 (x, y), `growth_scale`, captured 여부,
  공전 각도(비주얼 동기용).
- `is_active()` / `is_ball_captured()`.

### 2b.4 owned-ball 트랩 체크리스트 매핑 (배선 전 필독, CLAUDE.md 대응)

1. **모든 해제 경로에서 `skip_ball_motion_step=false` + 실속도.** 해제
   경로 인벤토리 — 이 4개가 전부다:
   - (a) 포획 60f 만료 → `uniform(0,2π)` × `uniform(12,16)`, vy 하향.
   - (b) 소용돌이 만료(timer/failsafe) 중 포획 → `uniform(-0.8π,-0.2π)`
     × 13, vy 하향.
   - (c) 카오스 스피어 흡수 → (b)와 동일 해제 처리 후 클리어. **Python은
     여기서 captured만 클리어하고 공 속도를 방치**했다(카오스 스피어가 공을
     소유 중인 상황만 있어 은폐된 원본 결함) — Godot에서는 카오스 스피어가
     공을 소유하지 않은 채 흡수가 일어날 수 있으면 반드시 해제 속도를 줘야
     한다. **배선 완료(2026-07-03, 5c 후속)**: fan_wind 상태에
     `absorb_chaos_spear_objects(center, pull_radius)` 구현 —
     active/charging + 반경 내면 상태 클리어 후
     `[{position, strength 1.15, color}]` 반환(Python L6260의 1.15 펄스
     스케일 패리티). 컬렉터
     `viper_skill_chaos_spear_ball_motion_runtime._collect_absorbed_objects`의
     absorb_key 리스트에 `stage1_gaksital_fan_wind_skill_state` 추가 완료.
     **captured 폴 스킵 가드 포함** — absorb 폴은 카오스의
     apply_motion(ball path :67, fan_wind 틱 :68보다 앞)에서 불리므로,
     포획 공의 해제 dict를 scene에 적용할 소비자가 그 시점엔 없다. 공을 문
     소용돌이는 자연 해제 후 다음 폴에서 흡수된다. 씰: fan_wind 스모크의
     프로토콜 3단언(흡수 클리어 / 반경밖 생존 / captured 스킵) + 컬렉터
     실경로 단언 — 반증검증은 컬렉터 미배선 상태 선실행으로 정확히 그
     단언만 RED임을 확인 후 배선. 의도 분기 기록: 거리 게이트는 Godot
     컬렉터 프로토콜(pull_radius 175)을 따른다(Python은 무조건 스윕).
   - (d) 라운드/컨텍스트 teardown — ball path 밖에서 일어날 수 있다.
     `ball_round_state.build_common_snapshot`이 라운드 경계에서
     `skip_ball_motion_step=false`로 정규화하는 기존 레이어가 회수한다
     (chaos spear 트랩의 라운드 정규화 레이어, 이미 구현·봉인됨). 스모크로
     이 커버리지를 fan_wind 케이스에 대해 재봉인할 것.
2. **구조 면역 패턴 = ghost shot 형 (ball-path-only 틱).** 상태머신 틱과
   해제 소비가 전부 ball path(`ball_frame_motion_controller`)에서 일어나면
   update_effects-only 모달 퍼즈 중 만료→pending 유실 클래스(카오스 스피어
   블랙홀 사고)가 **구조적으로 불가능**하다. fan_throw처럼
   `apply_stage1_gaksital_fan_wind()`를 ball path에 배선하고, **effects
   경로에서 이 상태를 틱하지 말 것.** 쿨다운 충전(effects 경로)과 스킬
   상태머신(ball 경로)은 분리 유지.
3. **패들 접촉 보존 의무 — 비적용 근거 기록.** 포획 궤도의 도달 범위는
   y ≈ 스폰(≈75) + 하강(≤144) ± 궤도(≤55) ≈ 최대 274 — 플레이어 패들
   밴드(≥630)에 물리적으로 도달 불가. 보스 패들 겹침(궤도 상단)은 Python과
   동일하게 무상호작용(해제가 항상 하향 발사라 자연 이탈). 이 근거를 코드
   주석 한 줄로 기록.
4. **배리어/바닥 체크 복제 의무 — 비적용 근거 기록.** fan_wind는 스스로
   floor/score를 해소하지 않는다(만료 = 해제 후 일반 물리 복귀, 홍련 인페르노와
   다름). 홀리배리어/브릭월 복제 불필요 — 근거를 코드 주석으로.
5. **동시 소유자 존중.** 포획 체크는 **`skip_ball_motion_step`이 이미 true면
   no-op** (고스트샷 텔레포트/카오스 블랙홀/포세이돈 등 선점 소유 절대 탈취
   금지 — stage5 인페르노의 소유권 덮어쓰기 사례 참조). 재확인: 소용돌이는
   공을 잡을 뿐 공-소유 스킬들의 릴리즈를 방해하지 않는다.
6. **freeze-actor 스냅샷 감사 — 양방향.** fan_wind는 원속도 스냅샷을 만들지
   않는다(해제 속도는 신규 생성) → 자기 방향은 면역. 반대 방향(타 액터가
   포획 중 `ball_vel` 스냅샷)은 기존 near-zero 폴백 가드들이 커버 — 신규
   가드 불필요, 감사 결과만 기록.

### 2b.5 봉인 스모크 (OUTCOME 기준) + 반증검증

공/투사체 전진은 반드시 `vel * delta * 60` (raw vel 금지). 반증검증은
**in-place Edit 토글만** — `git reset`/`checkout`/`stash` 절대 금지.

1. 충전→활성: 보스히트 소비 → 60f 후 active, growth_scale 0→1.
2. 포획: 공을 반경 42 안으로 스텝 → captured + `skip_ball_motion_step=true`
   + 공 위치가 궤도를 따라 실제로 움직임(프레임 간 위치 변화 단언).
3. 해제(60f): skip=false + `speed ∈ [12,16]` + `vy > 0` + **다음 프레임부터
   일반 모션으로 공이 실제 전진**(플래그가 아니라 위치 변화 단언).
4. 만료 해제: timer 소진 시 포획 중이던 공이 skip=false + speed 13 + vy>0.
5. 라운드 경계 회수: 포획 중 라운드 리셋 → `build_common_snapshot` 결과
   skip=false + fan_wind 상태 클리어(정지공 소프트락 없음).
6. 선점 소유 존중: skip이 이미 true인 프레임에 반경 진입 → 포획 no-op.
7. dalji/fan_throw 회귀: variant "dalji"에서 fan_wind 키가 scene/deps/draw에
   일절 등장하지 않음 + 기존 gaksi fan_throw 스모크 GREEN 유지.
8. **반증검증**: (3)의 해제 skip=false 라인을 in-place 토글로 죽이면 스모크
   3·5가 FAIL하는지 확인(정지공 재현) 후 원복.

---

## 3. 아키텍처 — `stage1_boss_variant` 변형 셀렉터

### 3.1 키 시드 + 전파

- **시드**: `game_selection_state.gd`에 `stage1_boss_variant: String = "dalji"`
  추가 (기본 dalji). 디버그 picker가 `"gaksi"`로 세팅 가능(§3.4).
- **전파**: `current_stage`가 흐르는 전역 battle context dict에 같이 실어
  내려보낸다. 컨슈머는 `context.get("stage1_boss_variant", "dalji")`로 읽되
  **누락 시 항상 dalji**.
- **Owner-field 스키마 트랩** (`feedback_godot_dynamic_set_payload_guard`,
  CLAUDE.md "Owner-Field Schema Trap"): 만약 이 키를 `owner.set(...)`로
  실어 다른 모듈이 `owner.get(...)`으로 읽게 한다면, 반드시
  `BattleSceneState.DEFAULT_VALUES`에 `stage1_boss_variant` 키를 선언할 것.
  안 그러면 set이 조용히 no-op 되고 컨슈머는 fallback(dalji)만 본다.
  context dict 직통 전파면 이 트랩은 회피되지만, owner 경유면 필수.

### 3.2 분기 터치포인트 (확인된 앵커)

리소스/스킬/HUD/result만 분기. 라우터(`stage_runtime_router.gd`)는 스테이지
번호 기반이라 그대로 둔다 (워크플로 C 확인).

| # | 파일 / 앵커 | 현재 (dalji 고정) | 각시탈 분기 |
|---|---|---|---|
| R1 | `battle_resources.gd:1100` `_get_stage1_boss_texture_specs()` | DALJI_* 시트 경로 | variant=="gaksi"면 GAKSITAL_* 경로 |
| R2 | `battle_boss_sprite_paths.gd:5-14` | DALJI_BOSS_* 14상수 | GAKSITAL_BOSS_* 상수 추가 |
| R3 | `battle_resources.gd:546-547` result prewarm specs | DALJI victory/defeat | variant 분기 |
| S1 | `gameplay_stage_module_catalog.gd:40` | dalji whip/spinning_top/cooldown 모듈 등록 | gaksital fan_throw + cooldown 모듈 등록 |
| S2 | `battle_update_stage_runtime_deps_builder.gd:43-47` `_append_stage1_deps` | dalji 스킬 deps 키 | variant=="gaksi"면 gaksital 모듈을 deps에 |
| S3 | `ball_dependency_context.gd:154/282/395/411` | dalji spinning_top deps | variant 분기 (동일 패턴) |
| S4 | `ball_frame_motion_controller.gd:252-255` | `deps.get("stage1_dalji_spinning_top_skill_state")` `update_and_collide` | gaksital fan_throw도 `update_and_collide` 호출 |
| S5 | `battle_draw_actor_context.gd:49-70` `if current_stage==1` | dalji whip/spinning_top draw context | gaksital fan_throw draw context |
| S6 | `battle_draw_scene_context.gd:59/113` | dalji spinning_top deps | variant 분기 |
| S7 | `ball_round_actor_cleanup.gd:68` | dalji spinning_top 라운드 정리 | gaksital 정리 |
| S8 | `match_reset_controller.gd:184` | dalji spinning_top 리셋 목록 | gaksital 추가 |
| H1 | `stage1_dalji_boss_skill_cooldown_state.gd` | "달지" + 팽이치기/상모돌리기 HUD | gaksital cooldown state: "각시탈" + 부채던지기 |
| H2 | `stage1_dalji_boss_skill_hud_assets.gd:3-4` | dalji 스킬카드 PNG | gaksital 부채던지기 스킬카드 |
| P1 | `battle_pso_prewarmer.gd:215,850-880` | dalji victory/defeat prewarm | variant 분기 |
| P2 | `battle_scene_update_prewarm_key_sets.gd:130` + `stage_debug_picker.gd:56` | dalji 모듈 prewarm 키 | gaksital 키 추가 |
| U1 | `stage1_boss_actor_renderer.gd:9-45` | dalji 렌더 계약(셀/프레임/캔버스) | gaksital 시트 그리드 계약 (시트 차원에 맞게) |
| RS1 | `stage_clear_result_asset_loader.gd` + `stage_clear_result_scene.gd:40-42,70-107,384-385,969-990` | dalji defeat/click "건들지마" 하드코딩 | gaksital defeat 시트 + 클릭 반응 (§5.4) |
| N1 | `defeat_settlement_screen.gd:10-17` `STAGE_BOSS_NAMES` | `1: "달지"` | variant 기반 보스명 |
| D1 | `stage_debug_picker.gd:6-18` STAGE_OPTIONS | 스테이지1=달지 | 1-A 달지 / 1-B 각시탈 (§3.4) |

> **권장 모듈 전략**: 달지 모듈을 건드려 내부 분기시키지 말고, **병렬
> 모듈**(`stage1_gaksital_fan_throw_skill_state.gd`,
> `stage1_gaksital_boss_skill_cooldown_state.gd`)을 만들고 위 컨슈머에서
> variant 게이트로 dalji 모듈 vs gaksital 모듈을 고른다. `variant=="dalji"`일
> 때 달지 경로는 **바이트 동일**해야 한다(아래 트랩 §6 회귀 봉인).

### 3.3 콜드-인스턴스화 트랩 (성능)

`battle_update_stage_runtime_deps_builder.gd:10-16` 주석이 경고하는 대로,
all-stages 리셋 경로는 **peek-only**(`get_cached_instance`)여야 한다 — 절대
gaksital 모듈을 콜드 인스턴스화하지 말 것 (370ms 물리 스톨 전례,
`project_physics_catchup_redraw_spiral` / CLAUDE.md "Hot-Path Lazy Init").
gaksital 병렬 모듈도 동일하게 peek 경로를 타야 한다.

### 3.4 디버그 선택 (1차)

`stage_debug_picker.gd` STAGE_OPTIONS에 스테이지1 하위 선택(달지/각시탈) 추가,
선택 시 `game_selection_state.stage1_boss_variant` 세팅 + 해당 variant의
prewarm 키 묶음 선택. 1차는 이 디버그 강제선택만 지원; 랜덤/메뉴는 후속.

---

## 4. 스프라이트 자산 제작 범위 (AutoSprite, Claude 디렉션)

> **AutoSprite MCP가 최종 시트의 필수 생성원** (CLAUDE.md / sprite-generation
> 스킬 §17). 절차적 Python 각시탈은 **비주얼 레퍼런스만**, 시트 소스 아님.
> Gemini/imagegen은 컨셉/프롬프트 분석/사용자 승인 폴백에만.

### 4.1 필요 시트 (달지 동급 표준 — 달지 자산 기준)

달지 실제 보유 자산(`godot/assets/sprites/stage1/dalji/`)을 미러:

| 시트 | 달지 기준 | 각시탈 |
|---|---|---|
| walk_left / walk_right | 분리 16f fullkeypose (1376×1536, 4×4, 셀 344×384), **런타임 미러 금지** | 동일 분리 좌/우 16f (각시탈도 광대 측면 보행) |
| idle | 1536×1024, 4×2, 셀 384×512, 8f 호흡 | 동일 (광대 너스레 idle) |
| attack (ball-contact hit) | 8f 루프 | 동일 (부채로 공 쳐내기) |
| dash | 단발 | 동일 |
| stun | 단발/루프 | 동일 (탈 벗겨짐 모티프 가능) |
| victory / defeat | result 시트 8f / live2d cutscene | 동일 |
| **fan_throw (스킬)** | (달지의 paengi_top_whip 32f 자리) | **부채던지기 전용 시트** — 휘두르기 선딜→발사 아크 |

> ⚠️ 시트별 그리드/프레임/셀 차원은 자산마다 다르다
> (`feedback_godot_atlas_grid_authority`: 멀티셀 atlas는 자산별 (cols,rows)
> 상수 필수, 공유 4×4 가정 금지). 각 각시탈 시트의 grid를 manifest에 기록하고
> `stage1_boss_actor_renderer`(또는 gaksital 전용 렌더러)의 셀 상수를 그에 맞춤.

### 4.2 정체성 락 + 사이즈 락

- **바디 사이즈 락**: Menhera 176×88 바디 클래스 = 표준. 각시탈도 게임 내에서
  달지/멘헤라 옆에서 같은 바디-리드(±5%). 캔버스 숫자(달지 96×112 draw)는
  렌더러 계약으로 맞추되 **인게임 가시 바디 리드**로 최종 판정
  (sprite-generation QA).
- **정체성 락(모든 시트 동일)**: 붉은 하회탈, 색동저고리 줄무늬 배치, 부채,
  광대 비율. walk 시트가 정체성 앵커.
- **프론트 바이어스 보행**: 정면감 유지(달지처럼 분리 좌/우 시트, 미러 금지).

### 4.3 부채(fan) 투사체 VFX

원본은 절차적 부채 폴리곤(`_draw_fan_shape`). 달지 팽이/채찍도 시트+절차
혼합. 부채 투사체는 **(a) 작은 부채 스프라이트/시트를 회전 draw** 또는
**(b) 절차적 폴리곤 포팅** 중 택. 권장: 부채 정체성이 중요하므로 **작은 부채
시트 1장**(또는 16프레임 스킬-이펙트 시트, CLAUDE.md "Runtime Skill-Effect
Sprite Sheets" 기본 권장)을 회전/사행 모션으로 합성. 모듈러 VFX 3-피스
방법론 적용 가능(`feedback_modular_vfx_3piece_methodology`).

### 4.4 워크플로 모드

`.claude/sprite_workflow_settings.json` 기본 `fast` — 후보 빠른 생성/조기
판단/적극 기각. 유망 후보 확정 후에만 프레임 확장/누끼/런타임 핸드오프
(`precise`).

---

## 5. 슬라이스 분해

### 슬라이스 1 — 변형 셀렉터 골격 (보스 없이 dalji 무변화 증명)
- `stage1_boss_variant` 키 시드(`game_selection_state`) + context 전파.
- 모든 §3.2 컨슈머에 variant 게이트 자리만 마련(아직 gaksital 모듈 없음,
  분기 양쪽이 dalji).
- **봉인 스모크**: variant 미지정/“dalji”에서 달지 경로 바이트 동일 + 모든
  deps/draw/cleanup 키가 기존과 동일(회귀 가드). **반증검증**: variant 게이트를
  일부러 깨면 스모크 FAIL.

### 슬라이스 2 — 각시탈 스프라이트 시트 (AutoSprite, Claude)
- §4 시트 풀세트 생성 → QA(정체성/사이즈/프론트 바이어스/누끼) → 런타임 export
  → `godot/assets/sprites/stage1/gaksital/`.
- R2 경로 상수 + U1 렌더러 그리드 계약 + R1/R3 텍스처 스펙 배선.
- **게이트**: 인게임 달지/멘헤라 옆 바디-리드 픽셀 QA.

### 슬라이스 3 — fan_throw 스킬 상태 + 쿨다운/HUD
- `stage1_gaksital_fan_throw_skill_state.gd` (spinning_top 미러, §2 메커니즘).
- `stage1_gaksital_boss_skill_cooldown_state.gd` ("각시탈" + 부채던지기,
  `TRIGGER_INSTANT`).
- S1~S8 + H1/H2 배선 (variant 게이트).
- 부채 투사체 렌더(§4.3) + get_draw_context → 액터 렌더러.
- **봉인 스모크 (OUTCOME)**: (a) 발동→0.5초 windup→발사, (b) 플레이어 충돌 시
  실제 스턴+넉백이 적용되는지(arming 플래그 아님, 실효과), (c) 연막 면역,
  (d) 광폭화 시 추가 2발, (e) 영역 이탈/timer 소멸 정리, (f) px/frame 단위
  검증(스모크가 공/투사체를 `vel*delta*60`로 전진 — raw vel 금지,
  `feedback_godot_ball_vel_pxframe_units`). **반증검증**: 수정 전(미배선) 코드에서
  스턴 미적용 스모크가 FAIL함을 확인.

### 슬라이스 4 — result / 패배결산 / 디버그선택 / 정리
- RS1 result 화면 각시탈 defeat 시트 + 클릭 반응 대사(트릭스터 톤, "건들지마"
  대체).
- N1 패배결산 보스명 variant 분기.
- D1 디버그 picker 스테이지1 하위선택.
- 후속(별도): 랜덤/메뉴 선출(포도대장 플랜 Slice7로 통합), fan_wind 2차
  스킬(슬라이스 5).

### 슬라이스 5 — `fan_wind` 부채바람 (2차, §2b 설계)

> 착수 전제: D-FW1~3 사용자 확정. 배선자는 §2b.4 owned-ball 체크리스트를
> 코드 리뷰 기준으로 삼는다.

- **5a — 스킬 상태 본체 + 공 포획/해제** (위험도 최고 구간):
  `stage1_gaksital_fan_wind_skill_state.gd` (§2b.3 계약) + ball path 배선
  (`ball_frame_motion_controller`에 `apply_stage1_gaksital_fan_wind` —
  fan_throw 미러, S3/S4 동일 사이트) + 정리(S7 `ball_round_actor_cleanup`,
  S8 `match_reset_controller`) + deps(S2 `_append_stage1_deps`,
  `ball_dependency_context`) + §2b.5 스모크 1~8 전부.
- **5b — 트리거 + 쿨다운 카드 + HUD**: 쿨다운 상태에 `SKILL_FAN_WIND`
  추가(whip 미러, `TRIGGER_ON_BOSS_HIT`, 1200f), 보스히트 트리거를
  `paddle_bounce_boss_post_hit_handler.gd`(whip `register_boss_hit` 사이트
  :55 옆)에 variant 게이트로 배선, HUD 스킬카드 2번째 슬롯
  (`stage1_gaksital_boss_skill_hud_assets` 카드 PNG 포함).
- **5c — 비주얼 + 대사**: D-FW3 소용돌이 시트(AutoSprite 16f, Claude 제작)
  + 충전 부채질/바람줄기 절차 액센트 + draw context → 렌더러
  (`stage1_gaksital_fan_throw_renderer` 확장 또는 전용 렌더러) + 발동 대사
  다국어 동기(§2b.2 마지막 항).
- **게이트**: §2b.5 스모크 GREEN + dalji/fan_throw 회귀 GREEN + 반증검증
  기록 + 인게임 라이브 QA(포획→해제 체감, 소용돌이 하강 리드).

---

## 6. 트랩 브리프 (배선 전 필독)

1. **기본 dalji 불변 (최우선).** variant 누락/“dalji”에서 달지 경로는
   바이트 동일. 회귀 스모크가 봉인. variant 게이트를 추가하되 dalji 분기는
   기존 코드 그대로.
2. **px/frame 단위.** fan_throw speed 5.5 / 넉백 ±12은 px/frame. 매프레임
   `*fps_scale`. px/sec 환산 금지. 스모크 전진도 `vel*delta*60`.
   (`feedback_godot_ball_vel_pxframe_units`, `feedback_godot_boss_knockback_port_parity`)
3. **radial CC = 중심거리 명시.** 부채 충돌은 비주얼 닿음이 아니라
   `hit_radius 24 + player_half_width` 원충돌. (CLAUDE.md radial CC 트랩)
4. **콜드 인스턴스화 금지.** all-stages 리셋/peek 경로에서 gaksital 모듈을
   생성하지 말 것 — `get_cached_instance` peek. (370ms 스톨 전례)
5. **owner-field 스키마.** variant를 owner 경유로 전달하면
   `BattleSceneState.DEFAULT_VALUES`에 키 선언 필수(no-op 트랩).
6. **atlas grid authority.** 각시탈 시트별 (cols,rows) 상수 + manifest 기록.
   공유 4×4 가정 금지 (런타임 에러 없이 스프라이트 깨짐).
7. **OUTCOME 스모크.** "발동했다"가 아니라 "스턴/넉백이 실제로 적용됐다"를
   단언. 성공-only 테스트는 컴파운딩/미스 버그를 숨김.
8. **연막 면역 우선순위.** 충돌 시 연막 체크가 스턴보다 먼저 (Python 순서).
9. **다국어 동기화.** 각시탈 보스명/대사 등 플레이어 노출 문구는
   language_settings_data 다국어 동기화 + localization_coverage 봉인
   (`feedback_godot_localization_copy_sync`). 보스명은 음역 고정.
10. **fan_wind = owned-ball 트랩 정면 대상.** 설계·체크리스트 매핑은 §2b
    (특히 §2b.4 — 해제 경로 4개 인벤토리, ball-path-only 틱 구조 면역,
    선점 소유 존중, 카오스 스피어 흡수 시 공 방치라는 Python 원본 결함의
    수정). MVP(fan_throw)에는 이 트랩이 없다 — 부채는 공을 소유하지 않는다.

---

## 7. 분담

- **Claude**: 이 설계 문서 + 슬라이스 2 스프라이트(AutoSprite 생성·QA·아트
  디렉션·누끼·런타임 export) + 슬라이스 1/3/4 GDScript 적대적 리뷰.
- **사용자 / Codex**: 슬라이스 1/3/4 GDScript 런타임 배선 + 스모크 작성 +
  반증검증 + 인게임 라이브 QA.
- 자산 워크플로 분담([Skill VFX Tool Boundary](skill_vfx_workflow.md#tool-boundary)) +
  `feedback_design_slice_review_division`
  준수.
