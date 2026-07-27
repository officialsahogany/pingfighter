# 살각시 액티브 스킬 #2 — 인형의 저주 (Doll Curse) 포팅 기획서

원본 PingFighter 아레나 영웅 **연화(maria)** 의 `DollCurse`(`downtown/hero_skills.py:5053`)를
**살각시 수호령의 2번째 액티브 스킬**로 포팅한다. 원본을 그대로 복제하지 않고, 아래
"디자인 변경점"을 적용한 **새 버전**이다.

- 분담: 이 문서는 디자인 노트(신호 계약) + 슬라이스 브리프(백본/스모크/트랩)다.
  GDScript 배선은 사용자가 직접 하고, Claude는 적대적 리뷰를 맡는다.
  (`[[feedback_design_slice_review_division]]`)
- 작성일: 2026-06-10.

---

## 0. 확정된 결정 (사용자 승인)

| # | 결정 | 값 |
|---|------|-----|
| D1 | 인형 위치 | **플레이어(살각시) 쪽 좌우** (살각시/플레이어 중심 ±150px, 화면 하단) |
| D2 | 공-인형 충돌 | **튕김 + 파괴** (하강 공만 위로 튕긴 뒤 그 인형 파괴) |
| D3 | 쿨타임 | 30.0초 |
| D4 | 혼란 모델 | 빛(등대 빔)이 **보스에 닿고 있는 프레임에만** 보스 혼란 |

D1의 함의: 인형은 **시전자(플레이어) 골을 지키는 수호인형**이다. 하강 공을 위로
튕겨 플레이어를 수비하고, 빛은 아래에서 위(보스 밴드)로 쓸어 보스를 혼란시킨다.
공이 인형을 깨면 수비 + 빛 소스를 하나 잃으므로 버프가 자연 감쇠하는 **자기제한**
구조가 한 키트로 맞물린다.

---

## 1. 타임라인 (스킬 내부 페이즈)

플레이어 입력 → (선택) Koyora 캐스트 윈드업 `windup_seconds` → `launch()` 호출 →
아래 3페이즈가 스킬 `update()` 내부에서 진행:

| 페이즈 | 길이 | 빔 | 혼란 | 공-인형 충돌 | 스프라이트 |
|--------|------|-----|------|--------------|------------|
| `EMERGE` 하늘 강하 | 1.0s | 없음 | 없음 | **없음** (안착 전) | 풀바디 인형 프레임 + 위치 보간으로 하강 |
| `ACTIVE` 활성 | 4.0s | 양쪽 등대 빔 스윕 | 빔이 보스에 닿는 프레임만 | **있음** | 목각 인형 16프레임 춤 루프 + 마리오네트 줄 |
| `RETRACT` 하늘 회수 | 1.0s | 없음 | 없음(즉시 해제) | 없음 | 풀바디 인형 프레임 + 위치 보간으로 상승 |

- 명목 총 길이 6.0s. 쿨 30s.
- **조기 종료**: `ACTIVE` 중 양쪽 인형이 모두 파괴되면 더 회수할 인형이 없으므로
  `RETRACT`를 건너뛰고 짧은 파괴 잔효 뒤 종료.
- 한쪽만 파괴되면 살아남은 인형은 계속 빔/충돌을 유지하고, `RETRACT`에서 그 인형만
  다시 하늘 쪽으로 회수된다. (파괴된 인형은 회수되지 않음)
- `windup_seconds`는 Koyora가 손을 드는 캐스트 제스처(0.4~0.6s 권장). `EMERGE` 1s는
  하늘에서 줄에 묶인 인형이 내려오는 별개의 인게임 연출. windup을 0으로 두고
  `EMERGE`를 전체 텔레그래프로 삼아도 됨.

---

## 2. 신호 계약 — 혼란 (status_effect_state 경유)

혼란은 **owner 플래그가 아니라** 중앙 `status_effect_state.gd`로 소스 스코프 적용한다.
이 경로가 자동으로 보스 AI 컨텍스트로 흘러 보스를 랜덤 이동시킨다.

```
status_effect_state.apply_status(
    "boss", "confusion", REFRESH_FRAMES, {…}, "lingpet_doll_curse")
        → get_boss_ai_context() 가 context["active_item_flare_confusion_active"]=true 세팅
        → boss_ai_state.gd:309 가 _update_confusion_target() 로 보스 랜덤 이동
```

- **접근 경로**: thunder_orb과 동일. `registry`에서
  `status_effect_state` 인스턴스를 꺼낸다 (`lingpet_thunder_orb_skill.gd:366`
  `_get_registry_instance(registry,"status_effect_state")` 참고).
- **소스 키**: 상수 `STATUS_SOURCE := "lingpet_doll_curse"`.
- **켜기**: `ACTIVE` 매 프레임, 좌/우 빔 중 **하나라도** 보스에 닿으면
  `apply_status("boss","confusion", REFRESH_FRAMES≈4, {}, STATUS_SOURCE)`로 갱신.
- **끄기**: 닿지 않는 프레임이면 즉시
  `clear_status("boss","confusion", STATUS_SOURCE)` (소스 스코프 클리어).
  → "빛에 닿고있을때만 혼란"(D4)이 정확히 구현됨.
- `clear_status`의 3번째 인자(source)로 **우리 소스만** 지운다. 보스에 다른 혼란
  소스(예: 플레어 아이템)가 동시에 있어도 건드리지 않는다. (스모크 S2에서 보장)
- 보스 어지러움(dizzy stars) 비주얼은 `get_actor_draw_context()`의
  `status_boss_confusion_active`로 **무료**로 따라온다 — 별도 작업 불필요.

> 트랩: `apply_status`의 `_build_entry`는 `max(이전 remaining, 신규 duration)`이라,
> 켜기만 하고 끄지 않으면 빔이 벗어나도 `REFRESH_FRAMES`만큼 혼란이 잔류한다.
> "닿을 때만"을 칼같이 맞추려면 **안 닿는 프레임에 명시적 `clear_status`** 가 필수다.

---

## 3. 신호 계약 — 등대 빔 기하 + 혼란 적중 (절차적 draw)

빔은 **스프라이트 시트가 아니라 런타임 draw**다 (각도/적중 기하가 매 프레임 변함 —
puppet_grab의 실 draw와 동일 부류, `[[feedback_modular_vfx_3piece_methodology]]`의
"절차적 곡선 VFX"). 한 인형당 빔 1개.

### 빔 상태 (인형별)
```
beam_angle          # 현재 각도(라디안), 화면 위 방향 기준
beam_target_angle   # 목표 각도
beam_sweep_phase    # "slow" 또는 "fast"
beam_sweep_timer    # 현재 스윕 구간 남은 시간
beam_turn_rate      # 현재 구간의 lerp_angle 추적 속도
```
- 스윕 리듬: `slow` 구간은 약 0.75~1.25s 동안 현재 각도 근처를 천천히 배회하고,
  `fast` 구간은 약 0.18~0.34s 동안 위쪽 아크 내 새 목표로 빠르게 꺾인다. 이
  느림→급가속 리듬으로 등대 빔이 긴장감을 만들고, 계속 빠르게 흔들리는 느낌을 피한다.
- 유도 확률: `fast` 구간에 새 목표를 잡는 순간, 레벨별 확률로 보스 중심 방향을
  목표각으로 삼는다. `Lv.1~5 = 35/50/65/80/95%`. 이 확률 롤은 목표 재선정 엣지에서
  한 번만 하고, 빔이 움직이는 매 프레임 재굴림하지 않는다.
- 집중 조사: 유도 성공 직후 다음 `slow` 구간은 보스 방향 주변에 머문다. 레벨이 높을수록
  허용 흔들림이 좁아진다: `Lv.1~5 = ±18/13/9/6/3°`. 그래서 Lv.5는 유도 성공 뒤
  빛이 적을 더 집중적으로 쐬는 느낌이 난다.
- 업워드 스윕 범위 권장: 수직 위(-90°) 기준 **±35°**. `slow` 구간의 미세 배회는
  현재 각도 기준 **±16°** 안에서만 목표를 잡는다.
- 보간: 매 프레임 `beam_angle`을 `beam_target_angle`로 `lerp_angle` 이징.
  **매 프레임 완전 랜덤 금지** (지저분 + 적중이 깜빡임).
- 빔 = 원뿔(cone): 원점=인형 머리, 반각 `BEAM_HALF_ANGLE ≈ 7°`,
  길이 `BEAM_LENGTH ≈ 700`(하단 인형 y≈600 → 보스 밴드 y≈45 도달).

### 적중 프리미티브 — **명시**: "boss-center-in-cone"
보스 사각: `boss_pos`(좌상단) + (`boss_paddle_width`/2, `boss_hitbox_height`/2) = 중심.
```
boss_center ∈ 빔 cone  ⇔
    angle(beam_dir, boss_center - doll_origin) ≤ BEAM_HALF_ANGLE
    AND  (boss_center - doll_origin).length() ≤ BEAM_LENGTH
```
- 라디알 CC 트랩(CLAUDE.md "Radial CC hit geometry must name its primitive"):
  프리미티브를 **boss-center-in-cone**으로 못박는다. 넓은 보스를 위해 보스 사각의
  상단 양 코너까지 샘플(center + 2 corner)하는 변형은 허용하되, **그릴 때와 같은**
  cone 기하를 쓴다 (보이는 빔 ≠ 판정 어긋남 금지).
- 적중 회귀(엣지 케이스): 보스가 cone 바로 **바깥**(반각 + ε)일 때 혼란이
  적용되지 **않아야** 한다 → 스모크 S3.

### 혼란 업타임 밸런스 (튜닝 워치)
하단 인형 → 보스까지 ~580px. 반각 7°면 그 거리에서 cone 폭 ≈ 2·580·tan7° ≈ 142px.
빔 2개 스윕이면 보스가 꽤 자주 덮인다. "닿을 때만"이 의미를 가지려면 시작값을
반각 6~8° / 스윕 ±30~40° / 재선정 0.3s 부근으로 두고 인게임에서 체감 튜닝.
빔이 항상 보스에 붙어있으면 반각/스윕속도를 줄인다.

---

## 4. 신호 계약 — 공-인형 충돌 (튕김 + 파괴)

dragon_wing의 비행룡 공 타격과 **동일 패턴** (`lingpet_dragon_wing_skill.gd:470`).
**이 스킬은 공을 소유하지 않는다** — `skip_ball_motion_step`을 절대 세우지 않고,
공을 읽고 `ball_vel`만 덮어쓰는 수동 바운서다. (덕분에 owned-ball floor-miss 트랩
계열 전부 회피)

`ACTIVE` 매 프레임, 살아있는 인형 각각:
```
ball_pos    = owner.ball_pos
ball_vel    = owner.ball_vel          # px/frame 단위! (base 7.65, 캡 ~26)
r           = owner.ball_radius
# AABB 겹침
overlap = abs(ball_pos.x - doll.x) ≤ DOLL_HALF.x + r
      and abs(ball_pos.y - doll.y) ≤ DOLL_HALF.y + r
if overlap and ball_vel.y > 0:        # 하강 공만 (상승=플레이어 샷, 통과)
    ball_vel.y = -abs(ball_vel.y)     # 위로 튕김, 부호만 반전 → 속도 주입 없음
    # (선택) ball_vel.x 에 인형→중앙 반대쪽 살짝 outward
    owner.set("ball_vel", ball_vel)
    destroy(doll)                     # 그 인형만 제거 + 파괴 VFX + SFX
    break                             # 한 번 접촉당 한 인형만
```
- **하강 공만** 상호작용(상승 공 통과): 플레이어가 막 올려친 상승 공이 자기
  수호인형을 깨거나 되튕겨 내려오는 anti-player 동작을 막는다. dragon_wing과 동일
  (`if ball_vel.y <= 0.0: return`). 이건 의도된 설계 — 인형은 **들어오는(하강)**
  공을 막는 가드다.
- **px/frame 단위 안전**(`[[feedback_godot_ball_vel_pxframe_units]]`): 바운스는
  기존 속도 **부호만 반전**, 크기 주입 없음 → 폭주 불가능. dragon_wing처럼
  너무 수직이면 살짝 완화하는 클램프만 선택 적용.
- `DOLL_HALF` 시작값 ≈ (24, 32) — 인게임 스프라이트 바디에 맞춰 튜닝.
- 파괴 VFX/SFX는 절차적(작은 파편 poof) + game_audio 훅.

---

## 5. owner 스키마 — **새 키 불필요** (의도적)

puppet_grab과 달리 이 스킬은 **보스 위치를 스크립트하지 않는다**. 따라서:

- `lingpet_doll_curse_active` 같은 owner 플래그를 **만들지 않는다**.
  (보스 프리즈 불필요 → Owner-Field Schema Trap / 보스-프리즈 릴리즈 누수 트랩
  계열 전부 비해당)
- 혼란 → `status_effect_state` (owner 아님).
- 공 바운스 → `owner.set("ball_vel")`. `ball_vel`은 이미 `DEFAULT_VALUES`에 있음.
- Koyora 캐스트 포즈/위치 오버라이드는 호스트 메서드
  (`has_companion_position_override` / `get_companion_cast_pose_progress`)로 처리 —
  owner 스키마 아님.

> 회귀 가드: 코드에 `owner.set(<선언 안 된 키>)`가 **없어야** 한다.
> 있으면 조용히 no-op 되는 스키마 트랩(`[[feedback_godot_dynamic_set_payload_guard]]`).

---

## 6. 라운드/리셋 정리 — **registry 캐시 필수 트랩**

혼란을 `registry`의 status_effect_state로 적용하므로, **`reset()`이 registry 없이**
불릴 때 혼란 소스를 못 지워 다음 라운드로 **누수**된다. thunder_orb이 이미 이 문제를
해결했다 (`lingpet_thunder_orb_skill.gd:85-98`).

- `update()`에서 본 마지막 `registry`를 `_registry`에 캐시.
- `reset()`/`cancel()`에서 `_registry`로
  `clear_status("boss","confusion","lingpet_doll_curse")` 호출 + 인형/빔/타이머 클리어.
- 호스트 리셋 경로(`lingpet_skill_runtime_host._reset_skill`)는 `cancel(owner, registry)`
  를 부르지만, 라운드-엔드 정리 deps는 registry/owner가 비어올 수 있다 → 캐시가
  방어선이다.
- 게임 종료(`show_result`) 경로도 호스트 reset을 타므로, 캐시 클리어가 양쪽을 덮는다.

---

## 7. 코드 배선 슬라이스 (puppet_grab과 동형 13포인트)

신규 파일: `godot/scripts/lingpet/lingpet_doll_curse_skill.gd`
신규 스모크: `godot/tests/lingpet_doll_curse_skill_smoke.gd`
(또는 `lingpet_egg_runtime_smoke.gd`에 `_verify_koyora_doll_curse_skill`로 병합 —
puppet_grab가 후자 패턴)

### 7.1 dispatcher (`lingpet_skill_dispatcher.gd`)
- `const SKILL_KIND_DOLL_CURSE := "doll_curse"`
- `const DOLL_CURSE_SKILL_ID := "koyora_doll_curse"`
- `SUPPORTED_SKILL_KINDS`에 `SKILL_KIND_DOLL_CURSE: true` 추가
- `get_skill_kind()` match에 `DOLL_CURSE_SKILL_ID → SKILL_KIND_DOLL_CURSE`
- `static func is_doll_curse(skill_id)` 헬퍼
- (카탈로그 `runtime_kind:"doll_curse"`가 `get_active_skill_runtime_kind()`로 먼저
  잡히지만, SUPPORTED 맵 게이트 때문에 키 등록은 필수)

### 7.2 host (`lingpet_skill_runtime_host.gd`)
puppet_grab가 등장하는 **모든** 지점에 doll_curse 추가:
`_doll_curse_skill` 멤버 + `DOLL_CURSE_SKILL_PATH` + lazy getter
`_get_doll_curse_skill()`, 그리고 `reset` / `update`(launch_context 전달) / `draw` /
`has_visible_effects` / `prewarm`(`_get_skill_for_kind` 경유) / `is_launch_blocked`
(`is_active()`) / `launch` / `get_launch_origin` / `trigger_launch_feedback` /
`get_snapshot` / `_get_skill_for_kind` + 테스트 접근자.
- `get_launch_origin`: `companion_pos`(인형 중심 좌표가 아니라 살각시 위치) 반환.
  좌/우 인형 위치는 스킬 내부에서 origin 중심 ±150으로 계산.

### 7.3 catalog (`lingpet_catalog.gd`)
Koyora `active_skill_pool`(`:669`)에 2번째 엔트리 추가:
```gdscript
{
    "id": "koyora_doll_curse",
    "runtime_kind": "doll_curse",
    "name": "인형의 저주",
    "description": "살각시가 양쪽에 줄에 묶인 목각 저주 인형을 내려보낸다. 인형이 "
        + "등대처럼 빛을 휘저으며, 그 빛은 Lv.1~5에 따라 35~95% 확률로 보스를 유도하고 "
        + "고레벨일수록 더 집중적으로 비춘다. 빛에 닿는 동안 보스가 혼란에 빠진다. "
        + "하강하는 공을 위로 튕겨 막지만, 공에 맞은 인형은 부서진다. 지속 후 "
        + "남은 인형은 다시 하늘로 회수된다.",
    "cooldown": 30.0,
    "windup_seconds": 0.5,
    "beam_homing_chance_pct_by_level": [35.0, 50.0, 65.0, 80.0, 95.0],
    "card_texture_path": "res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3.png",
    "icon_texture_path": "<신규 인형의저주 아이콘 또는 임시 재사용>",
}
```

### 7.4 status 접근
`registry.get_instance("status_effect_state")` (thunder_orb 패턴). `_registry` 캐시(§6).

### 7.5 audio (`game_audio.gd`)
발동음은 원본 Stage3 포팅 자산 `dollcurse.wav`를 재사용한다. `game_audio.gd`에는
`play_lingpet_doll_curse()`를 노출하고 내부적으로 `stage3_dollcurse_sfx`를 재생한다.
없으면 `play_stage3_dollcurse()` → `play_active_item()` 순서로 폴백.

### 스킬 클래스 공개 API (호스트가 기대하는 계약)
```
reset()
cancel(owner=null, registry=null)
prewarm()
launch(origin: Vector2, owner=null, launch_context:={}) -> bool
update(delta, owner, registry=null, launch_context:={})
draw(canvas, shake_offset:=Vector2.ZERO)
is_active() -> bool
has_visible_effects() -> bool
get_snapshot() -> Dictionary
# 선택(살각시 캐스트 연출): has_companion_position_override(),
#   get_companion_position_override(fallback), get_companion_cast_pose_progress()
# 테스트 접근자: get_confusion_apply_count_for_tests(),
#   get_doll_destroyed_count_for_tests(), get_phase_for_tests() 등
```

---

## 8. 스프라이트 자산

| 자산 | 형식 | 비고 |
|------|------|------|
| 저주 인형 목각 춤 시트 | 기존 accepted AutoSprite 시트 기반 4x4 16프레임 파생 자산 | `koyora_doll_curse_wooden_marionette_dance.png`. 모든 셀이 풀바디 목각 인형이며 ACTIVE는 **0~15 전체를 춤 루프**로 사용 |
| 인형 ACTIVE idle | 위 시트 0~15 프레임 + 절차적 wobble | 4초 ACTIVE 동안 목각 관절 인형이 춤추듯 팔/다리를 흔든다 |
| 마리오네트 줄/조종 막대 | **절차적 draw** | 시트에 굽지 않고 런타임에서 살아있는 인형별로 줄 4가닥 + 작은 조종 막대 draw |
| 등대 빔 | **절차적 draw** | 시트 아님 (각도/적중 매 프레임 변함) |
| 인형 파괴 잔효 | **절차적** poof/파편 | 시트 아님 |

- **AutoSprite MCP 필수**(인형 시트). `sprite-generation` 스킬 경유. Gemini/FLUX는 최종
  시트 생성기 아님.
- 정체성: Koyora 인형극 무녀(puppet miko) 테마 — 보스 기준 뒤태의 목각 마리오네트,
  얼굴/빔/줄은 시트에 굽지 않는다. 줄과 조종 막대는 런타임 오버레이. 레퍼런스:
  `puppet_miko_ringpet_cutin_art_imagegen_v3.png`.
- 자산 provenance: 새 목각 춤 시트는 수락된 AutoSprite 시트
  `koyora_doll_curse_rear_emerge_retract.png` / `cmq703k0j002k1kos71i32zqg`를
  기반으로 한 deterministic restyle + pose expansion이다. 이 세션의 AutoSprite MCP는
  provenance 조회와 기존 asset spritesheet 조회만 노출했고 fresh asset generation은
  노출하지 않았으므로, 새 시트를 fresh AutoSprite 산출물이라고 기록하지 않는다.
- 시트 타이머 트랩(CLAUDE.md "Effect Drawer Static-Frame Trap"): 프레임 진행을
  페이즈 타이머 **한 키**에서 파생. ACTIVE는 0~15 전체 루프, EMERGE는 0~3,
  RETRACT는 12~15를 사용하고, 입/퇴장 방향은 `spawn_pos`↔`target_pos` 위치 보간으로 표현.

---

## 9. 스모크 브리프 (효과의 **결과**를 단언)

`[[feedback_godot_ball_vel_pxframe_units]]` + Owner-Field Schema Trap에 따라 **스키마
게이트 owner**(또는 `ball_vel`을 위임하는 FakeOwner)를 쓰고, 공 수동 전진은
`ball_y += ball_vel.y * delta * 60`로 런타임과 동일하게.

| ID | 단언 |
|----|------|
| S1 | `EMERGE`(첫 1.0s): 혼란 소스 **없음**, 빔 없음, 공-인형 충돌 없음 |
| S2 | **소스 스코프**: 빔이 보스 덮음 → `lingpet_doll_curse` 혼란 소스 존재. 미리 깐 다른 소스("flare_x") 혼란은 우리 clear 후에도 **생존** |
| S3 | **닿을 때만 + 엣지**: 빔을 보스에 강제 → 혼란 적용. 빔을 보스 cone 바깥(반각+ε)으로 → 다음 프레임 혼란 **해제** |
| S4 | **한 인형만 파괴 + 튕김**: 하강 공을 좌측 인형에 겹침 → 좌측 파괴, 우측 생존, `ball_vel.y < 0`(위로 튕김) |
| S5 | **양쪽 파괴 → 조기 종료**: 양 인형 파괴 후 `RETRACT` 건너뛰고 종료 |
| S6 | `RETRACT`: 생존 인형만 하늘 쪽으로 회수, 깔끔 종료 |
| S7 | **누수 가드**: `reset()`(registry 캐시 경로) 후 혼란 소스/인형/빔 전부 정리. 다음 라운드 깨끗 |
| S8 | **상승 공 통과**: 상승 공(`ball_vel.y<0`)이 인형에 겹쳐도 파괴/튕김 없음 |

- 실패하는 방향으로 먼저 짜서 가드 검증 (S2/S3는 소스 스코프·엣지가 깨졌을 때 FAIL하는지 확인).

---

## 10. 트랩 체크리스트 (이 스킬에 실제 해당)

- [x] **라디알 CC 프리미티브 명시**: boss-center-in-cone, 엣지 회귀(S3). 보이는 빔=판정 기하 동일.
  (엣지 ε 회귀는 `_verify_beam_cone_edge_epsilon_regression` — 반각 6° 안쪽 적용 /
  8° 바깥 해제, 반각을 17°로 깨면 FAIL하는 것까지 확인)
- [x] **ball_vel px/frame**: 바운스는 부호 반전만, 크기 주입 금지. 스모크 owner도 px/frame.
  (최소 수직속도 플로어 `-BALL_SPEED_MIN*0.5`는 dragon_wing보다 보수적인 유계 완화로 수용)
- [x] **skip_ball_motion_step 미설정**: 공 비소유 수동 바운서. owned-ball floor-miss 트랩 비해당.
- [x] **owner 새 키 없음**: 보스 비스크립트. `owner.set(미선언 키)` 없음. (`ball_vel` 단일 지점)
- [x] **status 소스 스코프 clear**: `clear_status(...,"lingpet_doll_curse")`만. 전체 confusion clear 금지(다른 소스 클로버).
- [x] **registry 캐시 리셋**(§6): thunder_orb 패턴. 안 하면 혼란 라운드 누수.
- [x] **혼란 "닿을 때만"**: 안 닿는 프레임 명시적 clear (apply max-remaining 잔류 주의).
- [x] **시트 타이머 한 키**: 페이즈별 프레임 진행을 페이즈 타이머에서 파생. 현재
  목각 춤 빌드는 ACTIVE가 0~15 전체 루프를 돌고, EMERGE/RETRACT는 각자의 짧은
  풀바디 밴드만 사용해야 함.

> 적대적 리뷰 완료 (2026-06-10): 위 8항목 전부 코드/스모크로 봉인 확인.
> 데드 함수 `_any_beam_hits_boss` 삭제. §11의 F7 2-액티브 선택 경로는
> `lingpet_debug_picker._cycle_active_skill` 범용 구현으로 해소 확인.

---

## 11. 미해결 배선 질문 (블로커 아님, 배선 시 확인)

- **2개 액티브 풀 선택 UI**: 현재 각 펫은 액티브 1개라 `get_active_skill()`이 `[0]`
  디폴트. Koyora가 2개가 되면 어느 걸 장착/발동할지 선택 경로가 필요하다. Koyora는
  지금 `enabled:false, debug_enabled:true`(F7 디버그 전용)이므로 우선순위는 낮지만,
  F7 디버그 피커/로드아웃에서 skill_id로 특정 스킬을 고르도록 확인할 것
  (`get_active_skill(pet_id, "koyora_doll_curse")` 경로는 이미 존재).
- **윈드업 vs EMERGE**: `windup_seconds`(살각시 손드는 제스처)와 `EMERGE`(1s 하늘 강하)의
  중복 연출 톤 — 인게임에서 둘 합이 너무 길면 windup→0.

---

## 부록 A — 좌표 빠른참조 (Godot 760×750)

- 보스 밴드: `boss_pos.y ≈ 25`, 높이 `boss_hitbox_height ≈ 40` → y 25~65, 중심 ≈ (380, 45).
- 플레이어 패들: y ≈ 710. 플레이어 영역 y ≥ 630.
- 인형 권장: y ≈ 600~640, x = 380 ± 150 → 좌 ≈ 230, 우 ≈ 530.
- 빔 길이: 인형(y≈620) → 보스(y≈45) ≈ 575px → `BEAM_LENGTH ≈ 700` 여유.

## 부록 B — 원본 대비 변경점

| 항목 | 원본 DollCurse | 이 포팅 |
|------|----------------|---------|
| 발동 | 즉시 인형 등장 | **1s 하늘에서 줄에 묶인 인형 강하** |
| 혼란 | 즉시 4s 조작반전 | **빔이 보스에 닿는 프레임만** 보스 랜덤이동(혼란) |
| 빔 | 없음 | **등대식 스윕 빔 + Lv.1~5 유도 확률 35~95% / 집중각 ±18~3°** (신규) |
| 종료 | 인형 소멸 | **1s 하늘 쪽으로 인형 회수** |
| 공-인형 | 수호인형이 공 무한 반사 | **하강 공 튕김 + 그 인형 파괴**(자기제한) |
| 쿨 | 18s | **30s** |
| 대상 | 아레나 상대 영웅 | **살각시 수호령 → 보스** |
