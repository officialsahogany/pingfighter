# 빠나몽 액티브 스킬 — 바나나 슬라이스 (Banana Slice) 포팅 기획서

원본 PingFighter 투기장 영웅 **원숭이왕(monkeyking)** 의
`BananaSlice`(`downtown/hero_skills.py:17330`)를 **빠나몽(monkeyring) 링펫의
액티브 스킬**로 포팅한다. 수치·연출은 원본 충실 포팅이 기본이고, 트리거 모델과
슬립 적용 채널만 Godot 링펫/보스 AI 컨벤션에 맞춰 의도적으로 분기한다(부록 B).

- 분담: 이 문서는 디자인 노트(신호 계약) + 슬라이스 브리프(백본/스모크/트랩) +
  구현 기록이다. Codex가 Godot GDScript 배선, 자산 생성, 스모크 검증까지 수행했고,
  Claude 리뷰 메모는 원래 트랩 계약으로 남긴다.
  (`[[feedback_design_slice_review_division]]`)
- 작성일: 2026-06-11.
- 원본 보조 레퍼런스: 액티브 아이템 바나나(`item_effects/banana.py` — 원본 스스로
  "동일 효과" 패리티를 선언), 인게임 호위무사 모드의 보스 적용 경로
  (`game_mechanics/ingame_bodyguard.py:932`, `pingfighter.py:190920`).

---

## 0. 구현 결정

구현은 전부 "원본 충실 + Godot 인엔진 컨벤션" 기본값으로 확정했다.
밸런스 조정 후보는 기록으로만 남기고, v1 런타임은 아래 값 그대로 동작한다.

| # | 결정 | 제안값 |
|---|------|--------|
| D1 | 트리거 | **링펫 오토캐스트 컨벤션** (쿨다운 0 + ball_active → arm → windup → launch). 원본 ON_BALL_HIT(시전자 패들이 공을 칠 때)은 링펫 시스템에 등가물이 없음 → 의도적 분기 |
| D2 | 쿨타임 | **18.0s** (원본 충실). 풀 형제들(헤드벗 30 / 하이드로 40 / 버블 25 / 인형의 저주 30) 대비 짧지만, 효과가 마일드 CC(슬립)라 v1은 유지 |
| D3 | windup | **0.45s** (풀 형제 헤드벗과 동일). 스킬 내부 `PREPARE` 0.3s(원본 준비동작)는 별도 유지 → 총 텔레그래프 0.75s |
| D4 | 바나나 | **Lv.1~2는 1개, Lv.3부터 2개** (D6 v2). 보스 진영 랜덤 X(벽 마진 40, 상호 ≥120px), 2개일 때 두 번째는 0.15s 시차 발사 — 투척 역학은 원본 충실 |
| D5 | 슬립 채널 | **보스 AI 컨텍스트 제3 슬립 채널** (`lingpet_banana_slice_boss_slip_*`). 기존 두 채널(액티브 아이템 바나나 / 스테이지2 원숭이 바나나)과 같은 `combined_banana_slip_vel` 블록 합류 → AI 추적 완전 억제(early return) + 보스 대시 게이트. 원본 Python은 AI 위에 additive 가산이었지만, Godot의 바나나 판타지는 두 채널 모두 "통제 상실"로 이미 확립됨 → 인엔진 일관성 우선 |
| D6 | 레벨 스케일 | **v2 (2026-06-11 확정)**: `banana_count_by_level: [1, 1, 2, 2, 2]` — Lv.1~2는 1개, **Lv.3부터 2개**. `slip_speed_by_level: [15.0, 16.25, 17.5, 18.75, 20.0]` — 슬립 **초기 속도** 선형 15→20 px/frame, 지속 0.8s 고정 → 총 미끄러짐 360→480px(+33%). 공용 쿨다운/윈드업 감소는 그대로 중첩. 앵커: Lv.1 = 원본 슬립 패리티(15), Lv.5 = 스테이지2 보스 슬립 상수(20)와 동일한 인엔진 상한 |

D5의 함의: 슬립 중 보스는 **이동 의지를 완전히 잃고** 밟은 바나나 쪽으로 미끄러져
지나간다(접근 모멘텀 유지 — 원본 공식, 아래 §2 참조).
보스 대시도 슬립 동안 발동 불가. 세 채널이 동시에 켜지면 합산(additive stack) —
`combined` 블록의 설계 의도 그대로.

---

## 1. 타임라인 (스킬 내부 페이즈)

오토캐스트 arm → 빠나몽 캐스트 윈드업 `windup_seconds`(0.45s, 모션 프리즈 +
캐스트 포즈) → `launch()` → 아래 페이즈가 스킬 `update()` 내부에서 진행:

| 페이즈 | 길이 | 내용 | 비주얼 |
|--------|------|------|--------|
| `PREPARE` | 0.3s | 빠나몽 머리 위로 바나나 상승. 위치 오버라이드로 펫 고정 | 바나나 64px, y −20px·progress 상승, 회전 −15°→+15° |
| `THROW`/비행 | ~0.5s | 바나나 1~2개(레벨, D6) 투척 — 2개일 때 두 번째 0.15s 딜레이. 위로 직선 비행 + 좌우 조준 성분, 좌우 벽 반사 ×0.7 | 64px 회전 스핀(480~900°/s 랜덤 부호), 펫은 순찰 복귀 |
| `LANDED` | 3.0s/개 | 보스 밴드 y=45 착지, x는 30..730 클램프. 보스가 밟으면 슬립 발동 + 그 바나나 소멸 | 72px 15° 기울임 + 노란 경고 타원 그림자. 마지막 1.0s 블링크(12Hz) |
| `SLIP` | 0.8s | 보스 슬립: 15→0 px/frame 선형 감속, 바나나를 향해 미끄러져 통과 | 버스트 파티클 12개 + bananastep.wav |

- 종료 조건(원본과 동일): `PREPARE` 아님 + 투척체 0 + 착지 바나나 0 + 슬립 비활성
  + 잔여 파티클 0 → 스킬 종료. `is_launch_blocked`(=`is_active()`)는 이 전체 동안 true.
- 명목 최장 ≈ 0.3 + 0.5 + 3.0 + 0.8 ≈ 4.6s. 쿨 18s는 launch 시점에 시작하므로
  다음 발동 전에 필드는 항상 비어 있다.
- 비행 중 y < −50 또는 y > 800이면 투척체 폐기(원본 동일).

### 비행 운동 모델 (px/frame, 60fps 기준 — Godot 컨벤션)

원본 px/s 값을 ÷60 변환. 매 프레임 `pos += vel * fps_scale`, `fps_scale = delta * 60`.

```
vel_y = -20.0                                  # 원본 1200 px/s ↑ (보스 방향)
dx    = target_x - start_x
vel_x = sign(dx) * min(abs(dx) / 30.0, 6.0)    # 원본 sign·min(|dx|·2, 360) px/s
# 좌우 벽: x ≤ 10 → x=10, vel_x = +|vel_x|·0.7 ; x ≥ 750 → x=750, vel_x = −|vel_x|·0.7
# 착지: vel_y < 0 이고 y ≤ 45 → 착지 (x를 30..730으로 클램프)
```

- `|dx|/30` 계수는 ~0.5s 비행시간에 맞춰져 |dx| ≤ ~180이면 목표 X 근처에 떨어지고,
  더 먼 목표는 캡(6 px/frame) 때문에 못 미친다. **target_x는 보장이 아니라 조준
  성향**이다 — 원본도 동일. 착지 위치 단언 스모크를 "정확히 target_x"로 짜지 말 것.
- 랜덤 착지 X 생성기(원본 `_generate_random_landing_positions`): margin 40,
  `randi_range(40, 720)`, 기존 후보와 ≥120px 차이를 20회 재시도, 실패 시 그냥 수용.

---

## 2. 신호 계약 — 보스 슬립 (보스 AI 컨텍스트 제3 채널)

owner 키가 아니라 **보스 AI 컨텍스트 dict 채널**이다. 기존 두 바나나 채널과 동형:

```
스킬 모듈 (슬립 상태 보유: slip_timer_sec / slip_direction / slip_active)
  → get_boss_ai_context() -> Dictionary       # 스킬 모듈 메서드
  → lingpet_skill_runtime_host.get_boss_ai_context()   # 신규 위임 (캐시된 멤버만!)
  → lingpet_egg_runtime.get_boss_ai_context()          # 신규 위임
  → battle_update_boss_ai_context_builder._merge_shared_context (:124)
        registry 키 루프 ["active_item_runtime", "mythic_item_runtime"]에
        "lingpet_egg_runtime" 추가 → context.merge(..., true)
  → boss_ai_state.gd:283 combined_banana_slip_vel 블록에 세 번째 += 항 추가
  → boss_ai_state.gd:493 _try_start_boss_dash 게이트에 세 번째 false 항 추가
```

### 컨텍스트 키 (3종)

```
lingpet_banana_slice_boss_slip_active     : bool
lingpet_banana_slice_boss_slip_direction  : float   # −1.0 / +1.0
lingpet_banana_slice_boss_slip_speed      : float   # abs, 모듈 측에서 이미 감속 적용
```

- **감속은 모듈 측에서 계산**해서 speed에 실어 보낸다(스테이지2 패턴 동일):
  `speed = slip_speed * clamp(slip_timer / 0.8, 0.0, 1.0)` — slip_timer는 0.8에서
  0으로 감소하는 초 단위 타이머. `slip_speed`는 레벨별(D6 v2):
  `[15.0, 16.25, 17.5, 18.75, 20.0]` px/frame → 선형 감속으로 총 미끄러짐
  360px(Lv.1) ~ 480px(Lv.5). (원본 = 고정 15/360px. 클램프/벽에서 잘릴 수 있음.)
- **레벨 값 전달**: doll_curse 패턴 — 스킬 로컬 `BANANA_COUNT_BY_LEVEL` /
  `SLIP_SPEED_BY_LEVEL` 상수 테이블을 `launch_context.active_skill_level`로 인덱싱
  하고, launch_context에 평탄화된 `banana_count` / `slip_speed` 키가 오면 그 값을
  우선한다(카탈로그가 진실). **트랩**: 카탈로그 `*_by_level` 평탄화는
  `float()` 캐스팅이라 숫자 배열 전용 — `description_by_level` 같은 문자열
  테이블은 불가(`get_skill_level_value`, catalog:1013). 설명문은 추상 문구 한 장.
- **slip_direction**: **바나나를 향하는 쪽** (보스 중심 기준 — 접근하던 모멘텀이
  유지돼 껍질을 밟고 미끄러져 지나가는 그림). `paddle_cx = boss_pos.x +
  boss_paddle_width/2`, `|paddle_cx − banana_x| < 10`이면 `[-1, 1]` 랜덤, 아니면
  `−1 if paddle_cx > banana_x else +1` (원본 hero_skills.py:17540 충실.
  참고: 액티브 아이템 바나나는 "보스 이동 방향" 기준으로 다름 — 우리는 영웅 스킬 기준.
  초기 기획서 초안은 이 방향을 "반대쪽"으로 잘못 라벨링했었다 — 공식이 진실).
- 슬립은 **하나만 유지**(원본 동일: target_slipping 단일 상태). 슬립 중 두 번째
  바나나를 밟으면 슬립을 새로 갱신(타이머/방향 리셋) — 원본도 트리거마다 덮어씀.
- boss_ai_state의 `+=` 블록은 **early return** → 슬립 프레임 동안 보스 추적/혼란/
  대시 전부 건너뜀. 별도 스턴/프리즈 플래그 불필요.

### 핫패스 게이트 트랩 (중요)

`get_boss_ai_context()`는 **매 프레임** AI 컨텍스트 빌더가 부른다. 위임 체인의
각 단계는 **캐시된 멤버 null 체크만** 해야 한다:

- `lingpet_skill_runtime_host.get_boss_ai_context()`는 `_banana_slice_skill` 멤버가
  **null이면 빈 dict 반환** — `_get_banana_slice_skill()`(lazy 생성기)를 부르면
  스킬을 안 쓰는 프레임에도 모듈을 lazy-instantiate하는 핫패스 트랩
  (CLAUDE.md "Godot Hot-Path Lazy Init Trap"의 modal-gate 158ms 사례와 동형).
- `lingpet_egg_runtime.get_boss_ai_context()`도 `_skill_runtime_host` null 가드 +
  `STATE_COMPANION` 아닐 때 빈 dict.
- 스킬 모듈 측도 비활성이면 `{}` 또는 `{active: false}` 즉시 반환.

---

## 3. 신호 계약 — 착지/밟힘 판정 + 면역

### 적중 프리미티브 — **명시**: "banana-ground-rect × boss-rect AABB"

```
banana_rect = Rect2(banana_x - 40, 45 - 25, 80, 50)        # y 밴드 20..70
boss_rect   = Rect2(boss_pos, Vector2(boss_paddle_width, boss_hitbox_height))
밟힘 ⇔ banana_rect.intersects(boss_rect)                    # 착지 상태에서만
```

- 원본 80×50 바나나 중심 사각(hero_skills.py:17516) 충실. 보스 밴드(y 25..65)와
  세로로 항상 겹치므로 실질 X 판정 — 그래도 프리미티브는 rect-intersect로 못박는다
  (라디알 CC 트랩의 "프리미티브 명명" 규칙 준수, 원형 거리 판정 아님).
- 바나나별 1회 트리거(`slip_triggered` 플래그) 후 그 바나나 즉시 소멸 + 버스트.
- **비행 중 바나나는 무엇과도 충돌하지 않는다**(보스/공/플레이어 통과) — 원본 동일.
- **공 비간섭**: 이 스킬은 `ball_vel`/`ball_pos`/score를 읽지도 쓰지도 않는다
  (순수 CC). `skip_ball_motion_step` 비설정 → owned-ball 트랩 계열 전부 비해당.
- **면역 게이트 없음**: 원본의 magic_immunity는 투기장(영웅전) 전용 시스템.
  Godot 액티브 아이템 바나나도 보스 면역 체크 없이 슬립을 건다 → 인엔진 패리티로
  생략. (스테이지2 보스 status-immune은 넉백 채널에만 걸려 있고 슬립 블록은
  통과한다 — boss_ai_state.gd:264 vs :283 참조.)

---

## 4. owner 스키마 — **새 키 불필요** (의도적)

- 슬립은 §2의 컨텍스트 채널 → owner 키 0개. 기존 두 바나나 채널도 owner 스키마를
  안 쓴다 (`battle_scene_state.DEFAULT_VALUES`에 banana/slip 키가 하나도 없는 게
  의도된 현상태).
- 보스 위치를 스크립트하지 않음(velocity 채널) → puppet_grab류 프리즈/복원/
  reset_ball 정규화 트랩 전부 비해당.
- 빠나몽 캐스트 포즈/고정은 호스트 메서드(`has_companion_position_override` /
  `get_companion_cast_pose_progress`)로 처리 — owner 스키마 아님.

> 회귀 가드: 코드에 `owner.set(<선언 안 된 키>)`가 **없어야** 한다
> (`[[feedback_godot_dynamic_set_payload_guard]]`). 스모크 S8이 소스 텍스트로 봉인.

---

## 5. 라운드/리셋 정리

- `update()`에서 본 마지막 `registry`를 `_registry`에 캐시 (thunder_orb/doll_curse
  패턴 — 라운드-엔드 deps는 owner/registry 없이 올 수 있다).
- `reset()` / `cancel(owner=null, registry=null)`: 투척체/착지 바나나/슬립 상태/
  파티클/PREPARE 전부 클리어. **슬립 상태가 클리어되면 `get_boss_ai_context()`가
  즉시 비활성을 반환**하므로 보스 쪽에 지울 것이 없다(velocity 채널의 장점 —
  status_effect_state 같은 외부 잔류 상태 자체가 없음).
- 사운드는 전부 원샷(throw/step) → `gameplay_loop_audio_cleanup.gd` 등록 불필요.
- 게임 종료/스테이지 전환도 호스트 reset 경로를 타므로 동일하게 정리된다.

---

## 6. 코드 배선 슬라이스 (doll_curse와 동형 + 컨텍스트 채널 4포인트)

신규 파일: `godot/scripts/lingpet/lingpet_banana_slice_skill.gd`
신규 스모크: `godot/tests/lingpet_banana_slice_skill_smoke.gd`

### 6.1 dispatcher (`lingpet_skill_dispatcher.gd`)
- `const SKILL_KIND_BANANA_SLICE := "banana_slice"`
- `const BANANA_SLICE_SKILL_ID := "monkeyring_banana_slice"`
- `SUPPORTED_SKILL_KINDS`에 추가, `get_skill_kind()` match 폴백 arm,
  `static func is_banana_slice(skill_id)` 헬퍼.

### 6.2 host (`lingpet_skill_runtime_host.gd`)
doll_curse가 등장하는 **모든** 지점에 banana_slice 추가:
`BANANA_SLICE_SKILL_PATH` + `_banana_slice_skill` 멤버 + lazy getter,
`reset` / `update`(4-인자 `launch_context` 전달형) / `draw` / `has_visible_effects` /
`prewarm`(`_get_skill_for_kind`) / `is_launch_blocked`(`is_active()`) / `launch` /
`get_launch_origin`(`companion_pos` 그대로) / `has/get_companion_position_override`
(PREPARE 중만 고정) / `get_companion_cast_pose_progress`(PREPARE 0→1) /
`trigger_launch_feedback` / `get_snapshot` / 테스트 접근자.
- **신규**: `get_boss_ai_context() -> Dictionary` — `_banana_slice_skill`이 null이면
  `{}` (lazy getter 호출 금지, §2 핫패스 트랩).
- `trigger_launch_feedback`의 banana_slice 분기는 **의도적 no-op** (주석 명시).
  투척음은 스킬이 PREPARE→THROW 전환 프레임에 직접 낸다(§6.5). launch 시점
  (PREPARE 시작)에 던지는 소리가 나면 0.3s 어긋난다.

### 6.3 egg runtime (`lingpet_egg_runtime.gd`)
- **신규**: `get_boss_ai_context() -> Dictionary` — `STATE_COMPANION`이고
  `_skill_runtime_host != null`일 때만 위임, 아니면 `{}`.
- launch_context 추가 키(D6 v2): `banana_count`, `slip_speed`. 둘 다 카탈로그
  `*_by_level` 평탄화 결과이며, 스킬 모듈은 값이 없을 때 로컬 테이블을 fallback으로 쓴다.

### 6.4 boss AI 측 (컨텍스트 채널 4포인트)
1. `battle_update_boss_ai_context_builder.gd:124` `_merge_shared_context` 루프 키에
   `"lingpet_egg_runtime"` 추가 (스테이지 불문 — 링펫은 전 스테이지 동작).
2. `boss_ai_state.gd:283` `combined_banana_slip_vel` 블록에 세 번째 `+=` 항:
   ```gdscript
   if bool(context.get("lingpet_banana_slice_boss_slip_active", false)):
       combined_banana_slip_vel += (
           float(context.get("lingpet_banana_slice_boss_slip_direction", 0.0))
           * float(context.get("lingpet_banana_slice_boss_slip_speed", 0.0))
       )
   ```
3. `boss_ai_state.gd:493` `_try_start_boss_dash`에
   `lingpet_banana_slice_boss_slip_active` false 게이트 추가.
4. (배선 검증) FakeRegistry에 lingpet_egg_runtime을 꽂고
   `BattleUpdateBossAiContextBuilder.build_context()`가 키를 실어오는지 스모크 S6.

### 6.5 audio (`game_audio.gd`)
- **신규 메서드 불필요** — `play_banana_throw()`(:2048) / `play_banana_slip()`이
  이미 있고 피치 랜덤까지 내장. 스킬 모듈에서
  `_get_registry_instance(registry, "game_audio")`(doll_curse :1023 패턴)로 꺼내
  `has_method` 가드 후 호출:
  - `play_banana_throw()` — `_execute_throw` 프레임(2개 일괄 투척 시 1회, 원본 동일).
  - `play_banana_slip()` — 밟힘 트리거 프레임.

### 6.6 catalog (`lingpet_catalog.gd`)
monkeyring `active_skill_pool`(:811)에 추가. 기존 placeholder 헤드벗
`monkeyring_headbutt`는 제거하고, F7 피커의 빠나몽 기본 액티브 스킬을
바나나 슬라이스로 교체:
```gdscript
{
    "id": "monkeyring_banana_slice",
    "runtime_kind": "banana_slice",
    "name": "바나나 슬라이스",
    "description": "빠나몽이 배 주머니에서 바나나를 꺼내 보스 진영 바닥에 "
        + "던집니다. 레벨이 오르면 바나나가 두 개로 늘고 더 멀리 미끄러집니다.",
    "cooldown": 18.0,
    "windup_seconds": 0.45,
    "banana_count_by_level": [1, 1, 2, 2, 2],
    "slip_speed_by_level": [15.0, 16.25, 17.5, 18.75, 20.0],
    "card_texture_path": "res://assets/sprites/lingpet/monkeyring_banana_slice_skillcard_imagegen_v1.png",
    "icon_texture_path": "res://assets/sprites/lingpet/monkeyring_banana_slice_skill_icon_imagegen_v1.png",
}
```
- (D6 v2) `_apply_skill_level_values`가 두 키를 레벨 적용 시 `banana_count` /
  `slip_speed`로 평탄화한다 → egg_runtime `_launch_companion_skill`에서
  `beam_homing_chance_pct` 패턴 그대로 launch_context에 전달.
- **설명문은 "두 개" 고정 표기 금지** — Lv.1은 1개를 던지므로 수치를 추상화:
  "바나나를 꺼내 … 레벨이 오르면 바나나가 두 개로 늘고 더 멀리 미끄러집니다" 류.
  (`description_by_level` 불가 — §2 평탄화 float 트랩.)
- 카탈로그 validator(`_validate_active_skill_data` :1272)는 **card 파일 실존을
  필수로** 강제하고, `icon_texture_path`는 선택이지만 **키를 넣는 순간 실존 검사**가
  걸린다(:1283) → 위 엔트리처럼 둘 다 쓰려면 **아트가 카탈로그 배선보다 먼저**
  리포에 들어와야 한다(§7).

### 스킬 클래스 공개 API (호스트가 기대하는 계약 — doll_curse와 동일)
```
reset()
cancel(owner=null, registry=null)
prewarm()                                  # banana.png 텍스처 로드
launch(origin: Vector2, owner=null, launch_context:={}) -> bool
update(delta, owner=null, registry=null, launch_context:={})
draw(canvas, shake_offset:=Vector2.ZERO)
is_active() -> bool
has_visible_effects() -> bool              # 잔여 파티클 포함
get_snapshot() -> Dictionary               # banana_slice_* 접두 키
get_boss_ai_context() -> Dictionary        # §2 슬립 채널 (신규 계약)
# 선택: has/get_companion_position_override (PREPARE 중만),
#   get_companion_cast_pose_progress (PREPARE 0→1, 그 외 -1)
# 테스트 접근자: set_landing_xs_for_tests(), set_slip_direction_roll_for_tests(),
#   get_projectile_count_for_tests(), get_landed_count_for_tests(),
#   get_slip_state_for_tests(), force_land_for_tests() 등
```

---

## 7. 자산

| 자산 | 형식 | 비고 |
|------|------|------|
| 바나나 투척체/착지체 | **기존 PNG 재사용** `res://assets/sprites/items/banana.png` | 액티브 아이템·스테이지2와 공유. 비행 51.2px(2026-06-12 −20% 튜닝, 액티브 아이템 바나나와 동시 적용) / 착지 72px(15° 고정 기울임) |
| 회전 드로잉 | **절차적** — 회전 쿼드 `draw_polygon` + **텍스처 크기 정규화 UV** | `active_item_throw_slip_renderer._draw_rotated_texture_region`(:268) 패턴 복사. `[[feedback_godot_draw_polygon_uv_normalized]]` — 픽셀 UV 그대로 넘기면 투명 텍셀만 샘플됨 |
| 경고 그림자 | 절차적 타원 (노랑, alpha ≈ 0.31) | 착지 바나나 아래 60×10 |
| 버스트 파티클 | 절차적 12개 | 팔레트 (255,225,50)/(227,189,52)/(198,156,41)/(255,255,200)/(139,90,43), 속도 180~480 px/s 방사 + vy −180 바이어스, 중력 1200 px/s², 수명 0.33~0.67s |
| 스킬 카드 | **신규** `monkeyring_banana_slice_skillcard_imagegen_v1.png` | Codex 합성 생성. 헤드벗 카드와 동일 규격/스타일 라인 |
| 스킬 아이콘 | **신규** `monkeyring_banana_slice_skill_icon_imagegen_v1.png` | Codex 합성 생성. 알파 코너/비엣지 bbox QA |
| 캐스트 포즈 | 기존 `companion_cast` placeholder | 빠나몽 전용 투척 시트는 후속(뒷모습 SD 시트 자체가 미제작). 제작 시 Directional Sheet Facing Trap 규칙 적용 |
| 사운드 | **기존 재사용** `throwingbanana.wav` / `bananastep.wav` | `game_audio.play_banana_throw()` / `play_banana_slip()` 래퍼까지 이미 존재 |

- 신규 스프라이트 **시트** 없음 → AutoSprite 의무 비해당(카드/아이콘은 스틸이라
  imagegen 허용). 바나나 PNG는 `prewarm()`에서 `ProjectResourceLoader.load_texture`로
  캐시 — `_draw`에서 lazy 로드 금지.
- 블링크: 착지 타이머 < 1.0s에서 `int(timer * 12) % 2 == 0`이면 draw skip(원본 동일).
  타이머 키는 **하나**(`land_timer_sec`)만 쓴다 (Effect Drawer Static-Frame Trap).

---

## 8. 스모크 브리프 (효과의 **결과**를 단언)

보스/공 수동 전진은 `vel * delta * 60`으로 런타임과 동일하게
(`[[feedback_godot_ball_vel_pxframe_units]]`). 실패하는 방향으로 먼저 짜서 가드 검증.

| ID | 단언 |
|----|------|
| S1 | 카탈로그/디스패처/호스트 형태: validator 통과, `runtime_kind` 해석, F7 풀 노출. `lingpet_egg_runtime_smoke.gd`의 kind/디스패처/호스트-lazy 행 추가 포함 |
| S2 | launch → `PREPARE` 0.3s 동안 투척체 0 → 만료 프레임에 **정확히 2개** 생성, 두 번째는 0.15s 딜레이 동안 비활성(미드로), 착지 목표 X 상호 ≥120px·범위 40..720 (`set_landing_xs_for_tests`로 고정) |
| S3 | 비행 결과: `vel_y = −20` px/frame, 벽 접촉 시 반사 ×0.7, `y ≤ 45`에서 착지 전환 + x 30..730 클램프, y < −50 폐기 |
| S4 | 착지 3.0s 만료 → 트리거 없이 소멸, 슬립 **미발동** (out-of-scope 카운터 케이스) |
| S5 | **밟힘 → 슬립 결과**: 보스 rect를 바나나 위로 → `get_boss_ai_context()`가 active + speed 15→0 선형(0.4s 시점 ≈ 7.5) + direction이 바나나를 향하는 쪽(원본 공식). 같은 바나나 재트리거 없음(1회성). `|paddle_cx − banana_x| < 10` 랜덤 분기는 롤 주입으로 고정 |
| S6 | **보스 AI 통합**: 컨텍스트 키를 실은 진짜 `BossAiState.update()` → `boss_pos.x` 실변위 + 반환 `boss_vel == 슬립 속도`(early return 증명: 공을 반대쪽에 둬도 추적 안 함) + 슬립 중 대시 게이트 false. FakeRegistry로 `BattleUpdateBossAiContextBuilder.build_context()`가 키를 병합하는지 포함 |
| S7 | **누수 가드**: 슬립 중 `cancel(null)` → 바나나/슬립 전부 클리어, `get_boss_ai_context()` 즉시 비활성, 다음 라운드 깨끗 |
| S8 | **소스 텍스트 가드**: `ball_vel`/`ball_pos` 비참조, `skip_ball_motion_step` 미설정, `owner.set(` 미선언 키 없음, 호스트 `get_boss_ai_context`가 lazy getter 아닌 캐시 멤버 참조 |
| S9 | **오디오 타이밍**: FakeAudio — PREPARE 중 throw 0회, 투척 프레임에 1회(바나나 2개여도 1회), 밟힘에 slip 1회 |
| S10 | 윈드업 모션 프리즈 + `is_launch_blocked` true 동안 재-arm 안 됨 (착지 바나나 잔존 중 오토캐스트 재발동 금지) |
| S11 | **레벨 스케일 (D6 v2)**: Lv.1 launch → 투척체 **정확히 1개** + 슬립 시작 속도 15.0. Lv.2 → 1개(경계). Lv.3 → 2개(경계). Lv.5 → 2개 + 슬립 시작 속도 20.0. 카탈로그 평탄화 단언: `get_active_skill("monkeyring", "", 1).banana_count == 1` / lv5 `slip_speed == 20.0`. 기존 2개-단언 케이스(S2 등)는 launch_context에 `active_skill_level: 3+` 명시 필수 — 레벨 미전달 디폴트는 Lv.1(1개) |

---

## 9. 트랩 체크리스트 (이 스킬에 실제 해당)

- [x] **핫패스 lazy-init**: `get_boss_ai_context()` 위임 체인은 캐시 멤버만 (§2). 스모크 S8 소스 가드.
- [x] **UV 정규화**: 회전 쿼드 draw_polygon에 픽셀 UV 금지 (`[[feedback_godot_draw_polygon_uv_normalized]]`).
- [x] **시트 타이머 한 키**: 착지 블링크는 `land_timer_sec` 단일 키 파생 (static-frame trap).
- [x] **px/frame 단위**: 모든 운동 상수 px/frame, 적용은 `* fps_scale`. 스모크도 동일.
- [x] **owner 새 키 없음**: 슬립=컨텍스트 채널. `owner.set(미선언 키)` 금지.
- [x] **확률 롤 스코프**: 슬립 방향 랜덤(±1)은 트리거 엣지 1회 롤 — per-frame 아님 (Linkport 트랩 비해당 구조이나 명시).
- [x] **registry 캐시 리셋**: `_registry` 캐시 + owner-less `cancel(null)` 정리 (S7).
- [x] **대시 게이트**: 슬립 중 보스 대시 발동 금지 — 기존 두 채널과 동일 (S6).
- [x] **재-arm 금지**: `is_launch_blocked = is_active()` — 필드에 바나나 남은 채 재발동 방지 (S10).
- [x] **투척음 타이밍**: launch(PREPARE 시작)가 아니라 실제 투척 프레임 (S9).
- [x] **공 비소유**: `skip_ball_motion_step` 비설정, ball 비참조 (S8).

> 적대적 리뷰 완료 (2026-06-11): 배선 사슬(스킬 → host:378 캐시 멤버 →
> egg_runtime:272 → builder:127 → boss_ai_state:294 합류 + :502 대시 게이트),
> 디스패처/호스트 전 지점, 카탈로그 교체, 스테일 세이브 폴백(미지 skill_id →
> pool[0], catalog:1024), 수치 원본 충실성 전부 확인. 리뷰 중 적용한 수정 3건:
> (1) 착지 그림자 타원이 매 프레임 새 `ArrayMesh`를 만들던 핫패스 할당을 인스턴스
> 캐시로 교체(`_ellipse_mesh`), (2) 스모크에 실비행→착지(S3)·만료 카운터(S4)·
> 비중심 방향 분기(S5) 봉인 케이스 추가, (3) 이 문서 초안의 슬립 방향 라벨 오기
> 정정("반대쪽" → 바나나를 향해 미끄러져 통과 — 코드/원본 공식이 처음부터 정답).
> 수정 후 포커스드 스모크 + 워닝 스캔 재통과.

> 적대적 리뷰 v2 — 레벨 스케일 D6 v2 (2026-06-11): 카탈로그 by_level 2키 + 추상
> 설명문, egg_runtime launch_context의 -1.0 센티널 전달(:1499-1500), 스킬 측
> 양수-only 오버라이드 + 로컬 테이블 폴백(클램프 1..5 / count 1..4 / speed ≥0,
> `_get_banana_count_for_context` 계열), `get_boss_ai_context`의 인스턴스 속도
> 참조 전환, 스모크 레벨 핀(기존 2개-단언 케이스 전부 `active_skill_level: 3`) +
> 경계 케이스(Lv.2=1개/Lv.3=2개) + Lv.5 슬립 20 단언까지 전부 계약대로 확인.
> 수정 요구 0건, 포커스드 스모크 독립 재실행 통과.

---

## 10. 완료 결정

1. **쿨타임** — 원본 충실 18s로 확정.
2. **레벨 테이블** — ~~v1은 스킬 전용 테이블 없음~~ → **v2 (2026-06-11):
   D6 v2로 확정.** `banana_count_by_level: [1, 1, 2, 2, 2]` +
   `slip_speed_by_level: [15.0, 16.25, 17.5, 18.75, 20.0]`, 공용 감소 중첩 유지.
3. **카드/아이콘 아트** — `monkeyring_banana_slice_skillcard_imagegen_v1.png`,
   `monkeyring_banana_slice_skill_icon_imagegen_v1.png`를 리포에 추가.
4. **헤드벗 placeholder 처리** — `monkeyring_headbutt`는 빠나몽 풀에서 제거하고
   `monkeyring_banana_slice`가 기본 액티브 스킬을 맡는다.

---

## 부록 A — 수치 빠른참조 (원본 → Godot)

| 항목 | 원본 (hero_skills.py:17333) | Godot 포팅값 |
|------|------|------|
| 투척 속도 | 1200 px/s | vel_y = −20 px/frame |
| 좌우 조준 | sign·min(\|dx\|·2, 360) px/s | sign·min(\|dx\|/30, 6) px/frame |
| 벽 반사 | ×0.7 (x 10/750) | 동일 |
| 스핀 | 480~900°/s 랜덤 부호 | 동일 (°/s 유지, 드로잉 전용) |
| 준비 | 0.3s, 바나나 −20px 상승, −15°→+15° | `PREPARE` 동일 + windup 0.45s 선행 |
| 바나나 수 | 2 (0.15s 시차) | **레벨별 1~2개** ([1,1,2,2,2], D6 v2) — 2개일 때 0.15s 시차 동일 |
| 착지 Y | 45 (보스 밴드 중심) | 동일 (boss y 25..65) |
| 착지 X 클램프 | 30..730 | 동일 |
| 착지 유지 | 3.0s, 마지막 1.0s 12Hz 블링크 | 동일 |
| 밟힘 판정 | Rect(x−40, y−25, 80, 50) × 패들 | Rect2 intersect 동일 |
| 슬립 | 0.8s, 15→0 px/frame 선형, 총 ≈360px | 0.8s 고정, **초기 속도 레벨별 15→20** ([15.0,16.25,17.5,18.75,20.0], D6 v2) → 총 360~480px |
| 슬립 방향 | 바나나 쪽(접근 모멘텀 유지), \|차\|<10이면 랜덤 | 동일 |
| 쿨타임 | 18s (투기장 글로벌 5s 인터벌 별도) | 18s 확정 (D2) |
| 사운드 | throwingbanana / bananastep | 동일 wav + 기존 game_audio 래퍼 |
| 드로잉 크기 | 비행 64 / 착지 72 | 비행 **51.2**(−20% 튜닝, 액티브 아이템 바나나 `BANANA_DRAW_SIZE`와 동시 적용) / 착지 72 동일 |

## 부록 B — 원본 대비 의도적 분기

| 항목 | 원본 BananaSlice | 이 포팅 |
|------|------------------|---------|
| 트리거 | ON_BALL_HIT (시전자 패들 공 타격 시) + 5s 영웅 글로벌 인터벌 | **링펫 오토캐스트** (쿨다운 + ball_active → windup → launch) |
| 슬립 적용 | 보스 AI 위에 **additive 가산** (AI 계속 동작) | **AI 완전 억제** early-return 채널 — Godot 기존 바나나 2채널과 동일한 "통제 상실" 판타지 |
| 화면 흔들림 | 슬립 트리거 시 shake 5 / 0.2s | **생략** — Godot 바나나 2채널 모두 슬립 셰이크 없음(인엔진 컨벤션). 원하면 폴리시 레버로 후속 |
| 면역 | magic_immunity 체크(투기장 전용) + 패링 이펙트 | **생략** — 액티브 아이템 바나나와 인엔진 패리티 |
| 시전자 | 영웅 패들(상/하단 모두 가능) | 빠나몽 컴패니언(플레이어 진영 고정) → 보스만 타겟 |
| 두 번째 스킬 | 야생의 포효(WildRoar) 동봉 | **별도 기획서로 진행** — `docs/lingpet_monkeyring_wild_roar_slice_plan.md` (2026-06-12) |
| 사운드 로드 | pygame mixer 직접 로드 | 기존 `game_audio` 래퍼 재사용 |
