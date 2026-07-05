# 오로샤 액티브 스킬 「별똬리」 (star_coil) 슬라이스 계획

> 단일 소스(single source). 이 문서가 별똬리 설계·배선·검증의 진실 원본입니다.
> 디자인/리뷰 = Claude. GDScript 배선 = 사용자/Codex. 자산 아트 디렉션 = Claude(Gemini imagegen).

## 0. 정체성 / 한 줄 요약

- **펫**: 오로샤(orosha) — 별자리 고리뱀(ouroboros 모티프), `motion_style: "patrol"`.
- **코드 id**: `star_coil` (skill_id `orosha_star_coil`, runtime_kind `star_coil`)
- **표시명**: **별똬리**
- **종류**: 패트롤 **액티브 스킬**(쿨타임마다 자동 발동). 솔라볼트/우유발사와 같은 계열 —
  플레이어 입력 트리거 아님, 컴패니언 스킬 컨트롤러가 무장/발동.
- **한 줄**: 별 고리뱀이 가까운 벽을 **굴러 올라가** 상단에서 보스에게 다가가 **휘감아(코일)**
  일정 시간 **둔화**시키고, 둔화가 끝나면 **반대편 벽으로 굴러 내려와** 소멸한다.

이동만 액티브아이템 **스파이더지뢰**식 벽-등반 FSM이고, 골격은 링펫 액티브 스킬 계약을 따른다.

> **개정 2026-06-21**: 별도 투사체를 발사하는 게 **아니라 오로샤 컴패니언 개체 자체**가
> 이 FSM을 따라 직접 이동한다 — 즉 별똬리는 **컴패니언 position-override 스킬**이다. 상세 델타는
> §1.1 개정 노트 참조.

## 1. 확정된 결정 (재론 금지)

| 항목 | 값 | 근거 |
|---|---|---|
| 묶기 처리 | **둔화 디버프 + 코일 VFX (Path A)** | 사용자 확정 2026-06-21. 보스는 계속 움직이되 느려짐. 하드 루트(퍼펫그랩) 아님 |
| 둔화 시간 | Lv1~5 = `[1.5, 2.0, 2.5, 3.0, 3.5]`초 | 사용자 스펙 |
| 둔화 강도 | `0.4` 배수 (60% 감속), 레벨 무관 고정 | 스파이더지뢰 `SPIDER_MINE_SLOW_FACTOR`와 동일. **V3-6 튜닝 대상** |
| 쿨타임 | Lv1~5 = `[40, 35, 30, 30, 30]`초 | Lv1 40·Lv3 30 사용자 스펙. Lv4-5는 30 유지(잠정, V3-6 튜닝 가능) |
| 레벨별 CC 강화 | Lv1~2: bind 중 보스 대시 시 조기 해제 / Lv3~4: bind 중 보스 대시 시작 불가 / Lv5: 대시 불가 + 보스 스킬 쿨타임 정지 | 사용자 확정 2026-06-23. 기존 보스 AI dash gate와 `active_item_boss_skill_cooldown_paused` 경로 재사용 |
| 발동 조건 | 랠리 중(`ball_active`) + 컴패니언 가시 + 쿨타임 종료 | 보스 CC 스킬 — **공 하강 게이트 없음**(솔라볼트와 다름, 우유발사 계열) |
| 등반 벽 | 발동 시점 보스 x에 **가까운 벽** | 짧은 lunge로 CC 명중률↑. 하강은 반대편 벽(스펙) |

## 1.1 개정 노트 (2026-06-21) — 투사체 → 컴패니언 개체 직접 이동 (position-override)

사용자 확정: 별똬리는 **별도 투사체를 발사하지 않는다. 오로샤 컴패니언 개체 자체**가 §3 FSM
(굴러 벽으로 → 등반 → 보스 bind → 반대편 하강)을 따라 **직접 이동**한다. 별똬리는 **컴패니언
position-override 스킬**이다 (헤드벗 / 봄서프라이즈 / 꼭두각시 / 빠나몽 야생포효와 같은 계열).

기존 S1 코드의 ~80%는 재사용 가능 — `_pos` 페이즈 머신 · 둔화 자가치유 · bind · OUTCOME 경로는
그대로. `_pos`의 의미만 "투사체 위치" → "**오로샤 body 위치**"로 바뀐다. 델타:

1. **스킬에 override 표면 2메서드 추가** (bomb_surprise 156-162 선례):
   - `has_companion_position_override() -> bool` = `_phase != PHASE_IDLE`
   - `get_companion_position_override(fallback: Vector2) -> Vector2` = `_pos` (bind 중엔 `_pos == _bind_anchor`).
2. **호스트 arm 추가**: `lingpet_skill_runtime_host.has_companion_position_override`(~407)
   + `get_companion_position_override`(~427) match에 `STAR_COIL` 추가. → egg_runtime
   `_apply_active_companion_skill_position_override()`(~2605)가 매 프레임 `_companion_pos`를
   스킬 pos로 덮어쓴다. `is_launch_blocked`(~2538)도 자동으로 override를 active 취급(재무장 차단).
3. **스킬 draw에서 별도 orb 제거**: 오로샤 스프라이트(컴패니언 렌더러가 `_companion_pos`에 그림)가
   곧 굴러가는 별고리 본체. `_draw_projectile`(별도 orb) 삭제, **코일 VFX(bind)** + 스파크/트레일만 유지.
4. **롤 애니메이션 (수정안 확정 2026-06-21)**: 오로샤 롤 후프는 `companion_roll_angle`로 회전되며
   walk/idle 비율과 **무관**하게 렌더된다(`lingpet_companion_renderer` `_get_distance_roll_texture_state`).
   버그는 `_advance_companion_distance_roll(moved_dx)`가 **x-이동량만** 받아(egg_runtime ~2730) 수직 등반 시
   x≈0 → coast로 굴림 정지하는 것 하나뿐. **수정 = 호출처(2730) 인자를 `_signed_roll_distance(moved)`(경로 거리,
   수직은 관성 부호)로 교체. walk/idle 비율(2729)은 x-only 그대로 유지(starlight 수직-점프-idle 트랩 보존).**
   `_advance_companion_distance_roll`는 `companion_distance_roll_enabled`로 early-return하므로 비롤링 펫엔 no-op
   = 회귀 0. 봉인: lingpet_egg_runtime_smoke에서 수직 전진 시 `get_companion_roll_angle_for_tests()` 변화 단언
   (반증: x-only 코드면 불변) + 수평 불변 + starlight idle 유지. 벽별 손방향은 선택 폴리시(스킬이 wall_side
   힌트 노출 시 부호 반전). **✅ 배선 완료(2026-06-21)**: egg_runtime `_advance_companion_draw_anim` call site
   → `_signed_roll_distance(moved)`(수직=관성부호 path distance, 수평=moved.x 불변). 봉인 star_coil smoke
   `_verify_roll_uses_path_distance`(수직→roll 전진, 수평→moved.x). warning0.
5. **패트롤 복귀**: `_ground_y = clamp(_origin.y, 96, …)` = **발동 시점 높이(패트롤 밴드)**라, 하강은 반대편
   벽을 따라 그 높이까지 내려와 종료 → 패트롤이 거의 같은 밴드에서 재개(복귀 점프 작음). patrol_dir 0
   재시드 트랩(Companion Walk/Idle Ratio Trap)만 확인.  ※구현 확정 2026-06-21: ground_y는 바닥(724)이 아님.
6. **게임플레이 트레이드오프**: 스킬 동안(굴림+등반+bind 1.5~3.5s+크로스+하강 ≈ 수 초) 오로샤가
   **패트롤/디펜스 자리를 비운다**. "개체가 직접 이동"의 본질적 결과 — 수용 권장.

이 개정으로 무효/변경되는 항목: §4의 "레터박스 cull" 항목은 **무효**(컴패니언은 정상 플레이필드
렌더러가 그림). §5의 투사체 자체 스프라이트는 오로샤 본체로 대체. §7 배선에 위 1·2·3 추가. §8 스모크는
override 메서드(스킬 중 `has=true`, pos가 FSM 추종) + 호스트 arm을 단언하도록 보강.

## 2. 신호 계약 (signal contract)

### 2.1 스킬 모듈 공개 API (`lingpet_star_coil_skill.gd`, `extends RefCounted`)

솔라볼트/우유발사와 동일한 10-함수 계약:

```
func prewarm() -> void                 # 무거운 텍스처 있으면 여기서 preload+cache (코일 시트 등)
func reset() -> void                   # 로컬 상태 0으로(타이머/페이즈/투사체). owner 불필요
func can_arm(params: Dictionary) -> bool
func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool
func update(delta: float, owner: Object, registry: Object = null, launch_context: Dictionary = {}) -> void
func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void
func is_active() -> bool
func is_projectile_active() -> bool
func has_visible_effects() -> bool
func get_snapshot() -> Dictionary       # HUD 표시 전용(read-only). 권위 상태는 모듈 내부 var
```

### 2.2 `launch_context` (egg_runtime가 매 프레임 전달, 이미 존재 — 변경 불필요)

읽어 쓸 키: `ball_active(bool)`, `companion_pos(Vector2)`, `companion_visible(bool)`,
`owner(BattleSceneState)`, `boss_pos(Vector2)`, `boss_vel(float, px/frame)`,
`boss_paddle_width(float)`, `boss_hitbox_height(float)`, `active_skill_level(int 1..5)`,
`companion_state(str)`, `switch_transition_active(bool)`, `windup_seconds(float)`.

> 단위 불변식: **모든 속도는 px/frame** (ball_vel 단위). px/sec 아님. 변위 = `speed * delta * 60`.
> 참조: [[godot-ball-vel-pxframe-units]].

### 2.3 owner 스키마 추가 (둔화 / 대시 차단 / 쿨타임 정지 전달 경로) — **필수**

보스 둔화는 코드베이스 표준인 **context-flag 둔화 경로**(스파이더지뢰/plasma/venom_mist와 동일)를 탄다.
`status_effect_state`(우유발사 STUN 경로)가 아니라 `boss_ai_state._get_active_item_slow_multiplier()`가
읽는 컨텍스트 플래그다.

`godot/scripts/core/battle_scene_state.gd` `DEFAULT_VALUES`에 **4 키 선언**:

```
"lingpet_star_coil_boss_slow_active": false,    # bool
"lingpet_star_coil_boss_slow_multiplier": 1.0,  # float (활성 시 0.4 기록)
"lingpet_star_coil_block_boss_dash": false,     # bool (Lv3+ bind 중 true)
"lingpet_star_coil_freeze_boss_skill_cd": false,# bool (Lv5 bind 중 true)
```

> [[Owner-Field Schema Trap]] — DEFAULT_VALUES에 없는 키는 `owner.set()`이 **조용히 no-op**.
> 이 키들은 보스 AI / effects 컨텍스트가 소비할 뿐 캐릭터-인포 패널 스탯이 아니므로 `ringpet_` 페어는 불필요(단일 키).

흐름:
1. 스킬이 **bind 중 매 프레임** slow 2키 + 레벨별 CC 키를 live 기록한다.
   **set-once 엣지 금지** — 매 프레임 라이브 상태로 기록(자가치유, §6 트랩 참조).
2. Lv1~2: bind 중 `boss_ai_state.boss_dash_active`가 true가 되면 기존 release 경로로 조기 해제
   (`slow=false`, dash block=false, cooldown freeze=false, 반대편 하강).
3. Lv3~4: `lingpet_star_coil_block_boss_dash=true`를 boss_ai 컨텍스트로 전달하고
   `boss_ai_state._try_start_boss_dash()`가 false를 반환한다.
4. Lv5: Lv3+ 대시 차단에 더해 `lingpet_star_coil_freeze_boss_skill_cd=true`를 effects context로 전달하고
   `battle_effects_update_controller`가 기존 `active_item_boss_skill_cooldown_paused`에 OR-merge한다.
5. `godot/scripts/core/battle_update_boss_ai_context_builder.gd`: owner에서 slow 2키 + dash-block 키를 읽어
   boss_ai 컨텍스트 dict에 머지(`lingpet_puppet_grab_active` 머지하는 라인 근처, ~line 102).
6. `godot/scripts/ai/boss_ai_state.gd` `_get_active_item_slow_multiplier(context)` (~line 1095)에 분기 추가:
   ```
   if bool(context.get("lingpet_star_coil_boss_slow_active", false)):
       multiplier *= clampf(float(context.get("lingpet_star_coil_boss_slow_multiplier", 1.0)), 0.05, 1.0)
   ```
   (기존 둔화와 **곱연산** 누적. 클램프 `[0.05, 1.0]` 유지.)

### 2.4 보스 충돌은 건드리지 않는다

Path A는 보스 위치를 스크립트하지 않으므로 **보스 패들-스크립팅 트랩 6대 불변식이 적용되지 않는다.**
`ball_motion_collision_detector` / 라운드리셋 `boss_y` / post-hit snap 모두 무관 — 보스는 움직이지 않게
'고정'된 게 아니라 그냥 느려질 뿐. (이게 Path A를 고른 핵심 이득.)

## 3. 수명주기 FSM (페이즈 머신)

스파이더지뢰의 dict 기반 FSM을 스킬 모듈 내부에 두고, `bind`/`cross`/`descend` 페이즈를 추가한다.
모든 모션은 `move_towards(pos, target, speed_px_per_frame * fps_scale)` (Hermite, 도착 시 true).

```
ROLL_TO_WALL  : 스폰(컴패니언 근처) → 바닥을 굴러 가까운 벽 wall_x로 (roll speed ~11 px/frame)
CLIMB         : 벽을 따라 상단 corner_y까지 등반 (climb speed ~8.4 px/frame). 스프라이트 90° 회전
LUNGE         : 상단 밴드를 따라 보스 현재 x로 수평 추적(라이브, 결정론적). 접촉 시 BIND.
                실패세이프: LUNGE_TIMEOUT_FRAMES(~90) 내 미접촉이면 현위치에서 BIND(무한 추적 금지)
BIND          : 보스를 코일로 휘감음. bind_timer = SLOW_DURATION_BY_LEVEL[lvl]*60.
                매 프레임 slow 플래그 ON + 코일 VFX(WIND→HOLD), 보스 라이브 draw 중심에 앵커.
                bind_timer<=0 이면 RELEASE.
CROSS         : 코일 풀림(UNWIND). 반대편 벽 opposite_wall_x로 상단을 가로질러 이동.
DESCEND       : 반대편 벽을 따라 바닥까지 굴러 내려감(하강 속도, 등반과 달라도 됨). 스프라이트 회전.
DONE          : 바닥 도달 → 투사체 retire. is_active() → false.
```

- **LUNGE의 라이브 추적은 트랩 아님**: 이건 ROLL 확률 굴림도, 공 스타일 homing 재타겟도 아니라
  의도된 CC 전달. [[Per-Frame Probability Roll Trap]]은 *확률 굴림*에만 해당. 다만 무한 추적 방지용
  타임아웃 실패세이프는 필수.
- `ball_active == false`(라운드 종료/서브 대기)면 진행 중 페이즈는 안전 retire(스트레이 상태 쓰기 금지).

## 4. 기하 / 좌표 (px/frame, 풀캔버스)

스파이더지뢰 상수 차용(`active_item_throw_controller.gd`):

- 필드: `FIELD_WIDTH = 760`, `FIELD_HEIGHT = 750` — **풀 캔버스 x∈[0..760]. 80..680 인셋 금지.**
  [[godot-playfield-letterbox-reality]].
- `wall_x` 좌측 = `size*0.5 + WALL_OFFSET(18)` ≈ 31px, 우측 = `760 - 31` ≈ 729px.
- `corner_y` = 보스 상단 밴드 근처(`max(boss_pos.y + size*0.5 + 12, ...)`).
- **레터박스 draw cull**: 투사체가 벽 가장자리(x≈31/729)에 그려지므로 draw cull 밴드에
  `game_offset.x / render_scale` 좌우를 포함해야 화면 밖에서 튀어나오는 팝인이 없다.
  [[FX host child world-pos 변환식]]: 외부 캔버스 자식은
  `game_offset + (playfield_pos + shake) * render_scale`, 사이즈 `* render_scale`.
- **벽 선택은 발동 시점 보스 x로 1회 결정**, 등반 중 재평가 안 함(스파이더지뢰와 동일한 락). 하강 벽 = 반대편.

## 5. BIND 비주얼 — AutoSprite 본체 모션으로 확정 (2026-06-21)

**BIND 비주얼은 절차적 코일 VFX가 아니라 오로샤 본체가 직접 보스를 휘감는 AutoSprite 시트.**
(사용자 정정: "따로 이펙트 그리는 게 아니라 오로샤가 직접 묶는 모션".)

- **자산**: `res://assets/sprites/lingpet/orosha_star_coil_bind_autosprite_16f.png`
  (4×4, **16프레임 루프**, 512px 셀, 투명 ready, `_manifest.json` 동봉). AutoSprite char
  `cmqjc18a4008d81qp4rffcey5`(Orosha Front Clean v1) → custom constrict 모션. **v2 채택**
  (머리가 중심으로 파고들어 조였다 풂 = 바인딩; v1 rear+roar 기각).
- **배선(=user/Codex, Claude 리뷰)**: 컴패니언 렌더러가 BIND 페이즈 동안 이 시트를
  `_companion_pos`(=보스 중심)에 **시간구동 루프**로 그림(cast/strike/distance_roll 브랜치 패턴,
  스냅샷 `star_coil_bind_active` 게이트). 카탈로그 visuals/visual_layout에 시트 경로 + 그리드 추가.
  로더/프리웜은 lingpet visual 로더 경로(2048px, size_limit 인지).
- **스킬 변경**: `lingpet_star_coil_skill._draw_bind_coil` 절차적 타원 코일 **제거**. 스파크만 선택적 유지.
- **그리드 기록 필수**([[godot-atlas-grid-authority]]): cols 4 / rows 4 / 16f — 공유 SHEET_COLS 가정 금지.
- 컬러: 오로샤 정체성(인디고/골드 별자리) 그대로.
- (벽 이동 구간 롤 스프라이트는 §1.1 #4 distance_roll 경로가 담당 — bind 시트와 별개 시스템.)
- 상세 배선 todo는 매니페스트 `wiring_todo` 블록 참조.

**✅ 배선 완료 (2026-06-21, Claude)**: 카탈로그 visuals `companion_star_coil_bind` + visual_layout 그리드
(cols4/rows4/16f/draw_size150) · `lingpet_companion_draw_context_builder` bind config 키 + 호스트
`get_companion_bind_sheet_state(skill_id)`(peek, lazy-create 안 함) · `lingpet_companion_renderer`
`_resolve_companion_sprite_state` BIND 브랜치(casting 다음, **distance_roll보다 우선** → 롤 휠과
이중 draw 없음) + `_draw_bind_sheet_region`(4×4 셀 시간구동, frame=`int(_bind_elapsed*14)%16`) ·
스킬 `_draw_bind_coil`/`_draw_ellipse_outline`/COIL consts **제거** + `star_coil_bind_frame` 스냅샷.
검증: warning0 · headless ok · star_coil smoke(렌더러 bind>roll 우선, 호스트 bind state, bind frame).
잔여: 라이브 픽셀 QA(draw_size 150 튜닝, 보스 인카이클 확인) + bind 텍스처 프리웜(현 빌더 lazy load).

**BIND 아트 이터레이션 → v4 확정(2026-06-22)**: v1 roar / v2 링조임 / v3 링+안쪽접힘("가운데 촉수") 모두
거부됨. 사용자 레퍼런스 = 몸 전체가 코일 다발로 칭칭 감긴 형태. AutoSprite custom은 베이스 링 실루엣을 유지하는
경향이라, **generate_pose로 'Bind Coil Stack' 신규 포즈(pose cmqol5ae7)를 먼저 뽑아** 링을 완전히 풀어 수평
코일 다발로 재변형한 뒤, first=last 포즈로 미세 squeeze 애니(spritesheet cmqol8jx2) 생성 → 셰이프 일치.
같은 4×4/16f 경로라 PNG만 교체(코드 0). 매니페스트에 전체 출처/대안(v1~v3) 기록. 교훈: 대(大)변형은
custom 프롬프트로 우기지 말고 generate_pose 선행.

## 6. 트랩 브리프 (배선 전 필독)

1. **둔화 플래그 자가치유 (round-end leak 방지)** — 라운드 종료 정리는 `cancel(owner=null)`로 불릴 수 있어
   owner 플래그를 그 시점에 못 지운다. 해법: 플래그를 **bind_timer로부터 매 프레임 라이브 기록**
   (`active = bind_timer > 0`). `reset()`은 `bind_timer=0`만(owner 불필요), 다음 `update(owner)`가
   자동으로 `false` 기록 → 자가치유. set-once-on-edge 쓰면 stuck 둔화가 다음 라운드로 샌다.
   (퍼펫그랩식 deferred-release 불필요 — Path A의 이득.)
2. **단위 px/frame** — 등반/굴림/lunge 속도 전부 px/frame. 스모크는 `speed * delta * 60`로 전진시킬 것.
3. **owner 스키마** — §2.3 두 키를 DEFAULT_VALUES에 선언 안 하면 set() 조용히 no-op → 둔화 영영 안 걸림.
4. **레터박스 cull** — §4. 벽 가장자리 투사체의 draw cull에 letterbox 밴드 포함.
5. **공 하강 게이트 없음** — 솔라볼트 `can_arm`을 복붙하면 공 하강/플레이어-블록 예측 게이트가 따라온다.
   별똬리는 보스 CC라 그 게이트 제거(우유발사 계열). 랠리 라이브(`ball_active`)만 게이트.
6. **카탈로그 검증 = 자산 선행** — `card_texture_path`/`icon_texture_path` 파일이 **실재해야**
   카탈로그 검증 통과(`texture_resource_exists`). 자산(S0)이 카탈로그 배선(S2)보다 먼저거나, 임시
   placeholder 경유. [[feedback-icon-runtime-precedence]] 정신: 쓴 PNG가 실제 로드 경로인지 확인.
7. **단일-풀 unlock** — 오로샤는 스킬 1종 → `active_skill_pool` 1-엔트리. `candidates[0]` 자동선택은
   ≥2개 필요하므로 **`resolve_single_unlock(orosha, "active", "orosha_star_coil")`** 경로(밀쿠링 선례).
   안 그러면 unlock이 pending 영구 고착.
8. **LUNGE 타임아웃 실패세이프** — 보스가 끝까지 못 닿으면 무한 추적. 타임아웃 후 현위치 BIND 또는 retire.

## 7. 배선 체크리스트 (파일별)

| # | 파일 | 변경 |
|---|---|---|
| 1 | `godot/scripts/lingpet/lingpet_star_coil_skill.gd` (**신규**) | §2.1 10-함수 + §3 FSM + §6 자가치유 플래그 + 테스트 훅(`set_force_*`) |
| 2 | `lingpet_skill_dispatcher.gd` | `SKILL_KIND_STAR_COIL := "star_coil"`, `STAR_COIL_SKILL_ID := "orosha_star_coil"`, SUPPORTED 등록, `get_skill_kind()` + `is_*` 매치 암 |
| 3 | `lingpet_skill_runtime_host.gd` | `_star_coil_skill` 멤버 + `_get_star_coil_skill()` lazy + reset/update/draw/has_visible_effects/is_launch_blocked/can_arm/launch/get_launch_origin/trigger_launch_feedback/get_snapshot/_merge_snapshot 매치 암 (솔라볼트 패턴 복제) |
| 4 | `lingpet_catalog.gd` (오로샤 ~line 1107) | `active_skill: []` 제거 → `active_skill_pool: [{id, runtime_kind:"star_coil", name:"별똬리", description, cooldown:40.0, cooldown_by_level:[40,35,30,30,30], windup_seconds:0.3, slow_duration_by_level:[1.5,2.0,2.5,3.0,3.5], slow_multiplier:0.4, card_texture_path, icon_texture_path, motion_hint, how_to_use}]` |
| 5 | `battle_scene_state.gd` `DEFAULT_VALUES` | §2.3 두 키 선언 |
| 6 | `battle_update_boss_ai_context_builder.gd` | owner 두 키 → 컨텍스트 머지 |
| 7 | `boss_ai_state.gd` `_get_active_item_slow_multiplier()` | §2.3 둔화 분기 추가 |
| 8 | `lingpet_egg_runtime.gd` | `launch_context` 이미 전달(변경 없음). reconcile 단일-풀 `resolve_single_unlock` 경로 확인(§6-7) |
| 9 | `lingpet_rail_card.gd` + `character_info_overlay_lingpet_*` | 스냅샷 `star_coil_*` 키 + 쿨타임/둔화 표시(effective cooldown) |
| 10 | `game_audio.gd` | ✅ BIND 스퀴시 SE 배선 완료 (아래 노트) |
| 11 | 카탈로그 플래그 | 잠정 `enabled:false` + `debug_enabled:true`(F7 QA). 프로덕션 사인오프 시 `enabled:true` + `debug_enabled:false`(밀쿠링/루미온 선례) |

**✅ BIND 사운드 배선 완료 (2026-06-22)**: 별똬리가 보스를 **휘감는(BIND) 동안** 젖은 스퀴시
SE 재생. 자산 `res://assets/sounds/lingpet/orosha_star_coil_bind.wav`(ESM Blood&Gore
"Juicy Wet Squish" 출처, 스테레오 44.1k/16-bit). **볼륨 마스터링(2026-06-22 잘 안 들림 수정)**:
원본은 RMS ~-33 dBFS의 조용한 sparse 무빙 폴리(피크는 -1 dBFS라 player gain만으론 +1 dB가 한계)
+ 뒤쪽 트레일 청크 오독 주의. 해법 = 소스를 **소프트클립 메이크업 게인(tanh drive 2.8)으로
바디를 ~-30→~-21 dBFS RMS 끌어올리고 0.45~4.05s로 트림(~3.6s)** → bind 창(1.5~3.5s)에 들리는
스퀴시가 안착. pristine 백업 `d:\tmp\orosha_star_coil_bind_pristine.wav`(되돌리려면 Downloads
원본 재복사). `game_audio.gd`에 path/gain
(`LINGPET_STAR_COIL_BIND_*`, **-2.0dB**) + `lingpet_star_coil_bind_sfx` 플레이어(`_setup_item_command_sfx`,
prewarm step3, stop-all 리스트) + `play_lingpet_star_coil_bind()`(피치지터 0.97~1.03,
스트림 실패시 `play_active_item` 폴백) + `stop_lingpet_star_coil_bind()`.
**의미론 = BIND 시작 시 one-shot 재생, BIND 해제/retire/cancel 시 정지** — 소스(~6.5s)가
bind 창(1.5~3.5s)보다 길어서 정지하지 않으면 squish가 롤-어웨이까지 끌림. 스킬 모듈은
`registry`를 `update → _update_lunge/_update_bind/_retire`로 통과시켜 `_begin_bind`에서
`_start_bind_audio`(play), 해제 3경로에서 `_stop_bind_audio`(stop). `_bind_audio_active`
플래그로 프레임당 재생 금지 + 단일 정지 보장. registry=null 안전(헤드리스/스모크). 봉인 =
`lingpet_star_coil_skill_smoke._verify_bind_plays_and_stops_audio`(녹음 game_audio 더블로
play==1·해제 stop==1·retire stop·cancel stop OUTCOME, 반증검증: play/stop 비활성화 시 FAIL 확인).

## 8. 스모크 봉인 세트 (OUTCOME 기반)

`godot/tests/lingpet_star_coil_skill_smoke.gd` (FakeOwner=스키마 게이트 owner, FakeRegistry, seed 고정):

- **S1 arm 게이트**: 랠리 라이브+컴패니언 가시+쿨다운0 → `can_arm` true. `ball_active=false`면 false.
  공 하강 게이트가 **없음**을 단언(상승 공이어도 arm 가능).
- **S2 등반→접촉**: launch 후 `speed*delta*60`로 프레임 전진. 보스 rect 접촉 시 BIND 진입.
- **S3 둔화 OUTCOME(핵심)**: BIND 동안 `owner.lingpet_star_coil_boss_slow_active == true` +
  multiplier==0.4. **boss_ai_state를 실제로 통과시켜 `boss_vel`이 실제로 0.4배로 줄어드는지** 단언
  (attempt 플래그가 아니라 결과). 스키마-게이트 owner 필수(plain dict면 트랩 못 잡음).
- **S4 레벨 스케일**: Lv1 bind_timer≈90프레임(1.5s), Lv5≈210프레임(3.5s).
- **S5 해제 자가치유**: bind_timer 만료 후 다음 `update(owner)`에서 플래그 `false`.
  그리고 **bind 중 `cancel(null)`(라운드정리) 후 다음 `update(owner)`가 플래그를 false로** 돌리는 회귀.
- **S6 반대벽 하강**: RELEASE 후 CROSS→DESCEND가 **반대편** wall_x로 가고 바닥에서 retire.
- **S7 쿨타임**: 발동 후 `cooldown_by_level[lvl-1]`초 만큼 재무장 차단.
- **S8 보스 충돌 무관**: 둔화 중에도 보스가 상승 공을 정상 바운스(둔화 플래그가 충돌을 게이트하지 않음).
- **반증검증**: 각 핵심 단언(특히 S3·S5)은 **수정 전 코드(분기 제거/플래그 set-once)로 FAIL**함을
  in-place Edit 토글로 먼저 확인 후 봉인. `git reset/checkout/stash` 금지(WIP 파괴).

`lingpet_egg_runtime_smoke.gd`에는 loadout-apply가 별똬리 런타임을 prewarm하는지(텍스처 있으면) +
patrol 정적 프레임이 idle로 읽히는지(별똬리가 컴패니언 위치를 옮기지 않음, S11) 보강.

## 9. 자산 deliverable (S0, Claude 아트디렉션 + Gemini imagegen)

- 스킬 카드: `res://assets/sprites/lingpet/orosha_star_coil_skillcard_imagegen_v1.png`
  (~300px 폭, **불투명 풀씬** — 인디고 밤하늘 + 골드 별자리, 보스를 휘감는 고리뱀)
- 스킬 아이콘: `res://assets/sprites/lingpet/orosha_star_coil_skill_icon_imagegen_v1.png`
  (HUD 오브용. **불투명 검정-bg = 링펫 스킬 아이콘 컨벤션** — 솔라볼트/우유발사 선례)
- imagegen은 **Gemini**(generate-image), FLUX 금지. [[imagegen-gemini-not-flux]].
- (옵션) 코일 16프레임 시트는 런타임 VFX면 AutoSprite 경유.

## 10. 슬라이스 백본 (작업 순서)

- **S0** 자산: 카드 + 아이콘 imagegen(Claude 디렉션) — 카탈로그 검증 선행 의존성.
- **S1** 스킬 모듈 `lingpet_star_coil_skill.gd`: §3 FSM + §6 자가치유 둔화 + 스냅샷 + 테스트 훅.
- **S2** 등록: 디스패처 + 호스트 + 카탈로그 풀 + DEFAULT_VALUES + boss_ai 둔화 분기 + 컨텍스트 빌더.
- **S3** unlock/loadout: `resolve_single_unlock` reconcile 확인 + enabled/debug 플래그(잠정 debug).
- **S4** HUD/툴팁: rail card 스냅샷 + 캐릭터-인포 패널 + effective 쿨타임 표시.
- **S5** 스모크 봉인 §8 + 반증검증.
- **S6** 라이브 QA(등반/명중/둔화 체감/반대벽 하강/라운드리셋 정리) → 커밋(무관 WIP 분리).

## 10.1 롤 스프레이 VFX 업그레이드 (2026-06-22, Claude)

§1.1 #3에서 "유지"하기로 한 스파크를 **굴러가는 동안 몸에서 튀는 알록달록 별 파티클**로 업그레이드.
`lingpet_star_coil_skill.gd` 내부 self-contained 변경(호스트/렌더러 무관, 순수 가산):

- **연속 방출**: 기존 스파크는 launch/bind/cross/descend 순간 버스트뿐 → 이동 페이즈
  (roll/climb/lunge/cross/descend) 동안 `_emit_roll_stars`가 몸 위치(`_pos`)에서 매 프레임 별을 뿜음
  (`ROLL_STAR_RATE=48/sec`, accumulator로 프레임레이트 정규화, 진행 반대방향 trail bias + 약한 위쪽 fling). BIND 제외.
- **별 모양**: `_draw_star` = 정다각 N-점 별(외/내 반지름 교차·각도순 → 항상 단순 폴리곤 →
  `draw_colored_polygon` 삼각분할 안전, [[Animated Polygon Triangulation Trap]]; glow halo가 안전 폴백).
  작은 별=4점 sparkle/큰 별=5점. spin·중력 arc·드래그(`pow(0.90, delta*60)` 프레임레이트 정규화).
- **색**: `STAR_COLORS` 7색(gold/pink/cyan/violet/mint/peach/ice). violet+gold=오로샤 정체성, 나머지=색감 변화.
- **크기**: size roll 제곱으로 대부분 작고 가끔 큰 별("크고 작은"). `SPARK_MAX 42→56`. 결정론 유지(`_seeded_unit`+monotonic seed).
- **봉인**: `lingpet_star_coil_skill_smoke._verify_continuous_star_emission_while_rolling`
  (60프레임 후 롤 중 spark_count≥10 — launch 버스트만으론 다 소멸; emission 비활성 토글로 반증검증 FAIL 확인). warning0·headless ok.
- **잔여(라이브 QA)**: rate/size/팔레트 밸런스/spawn 반경(현 몸 중심 1~7px) 체감 튜닝.

## 10.2 롤 이동 사운드 (starmoving 루프, 2026-06-23)

별똬리가 **이동/등반/런지/크로스/하강(=모든 moving 페이즈)** 동안 `starmoving.wav` 루프 재생. bind는
자체 squish가 있어 제외. bind 오디오 패턴을 거울삼아 배선:

- **자산**: `res://assets/sounds/starmoving.wav`(루트, lingpet 하위 아님) + `.import` 생성됨.
- **game_audio**: `LINGPET_STAR_COIL_MOVE_SOUND_PATH`/`_GAIN_DB(-6.0)` + `lingpet_star_coil_move_sfx`
  + `player_factory.create` 후 **`_enable_loop`**(jetpack 선례) + `play_/stop_lingpet_star_coil_move`
  (이미 재생중이면 no restart) + teardown 배열 등록.
- **스킬**(`lingpet_star_coil_skill`): `_move_audio_active` 플래그 + `_start/_stop_move_audio`,
  `_is_rolling_phase`면 start(멱등)·아니면 stop, IDLE 조기리턴/`_retire`/`cancel`에서도 stop(자가치유).
- **봉인**: `lingpet_star_coil_skill_smoke._verify_move_audio_loops_during_travel`(연속 롤서 **정확히 1회 시작**·
  주행중 stop0·bind서 stop1·중도 공소실 retire stop1). 반증검증: 멱등 가드 제거 시 "1회 시작" FAIL 확인.
  warning0·headless·import ok.
- **잔여(라이브 QA)**: gain(-6.0) 체감, 루프 이음새(starmoving.wav.asd는 Audacity 소스).

## 11. 잔여 / V3-6 튜닝

- 둔화 강도 0.4, 쿨타임 Lv4-5(현 30), lunge/등반/하강 속도, LUNGE 타임아웃 — 스테이지 후 income 튜닝과 함께.
- 프로덕션 사인오프 시 `enabled:true` 플립(현 debug 게이트).
- 등반 벽 선택 기준(현 보스-근접) — 컴패니언-근접으로 바꿀지 라이브 체감 후 결정.
