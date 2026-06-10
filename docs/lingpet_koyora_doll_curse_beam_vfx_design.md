# 코요라 인형의 저주 — 등대 빔(빛) VFX 업그레이드 설계 노트

[docs/lingpet_koyora_doll_curse_plan.md](lingpet_koyora_doll_curse_plan.md)의 §3(등대 빔)
**비주얼 품질만** 끌어올리는 슬라이스다. 게임플레이(혼란 적중 / 공-인형 충돌 /
페이즈 타임라인)는 **불변**. 대상 함수는 단 하나: `_draw_beams()`
([lingpet_doll_curse_skill.gd:655-678](../godot/scripts/lingpet/lingpet_doll_curse_skill.gd#L655-L678)).

- 분담: 이 문서는 디자인 노트(레이어 레시피 + 신호 계약) + 슬라이스 브리프(백본 /
  스모크 / 트랩)다. GDScript 배선은 사용자가 직접 하고, Claude는 적대적 리뷰를 맡는다.
  (`[[feedback_design_slice_review_division]]`)
- 작성일: 2026-06-10.
- 방법론: 3-피스 모듈러 절차적 VFX(`[[feedback_modular_vfx_3piece_methodology]]`).
  additive 시트가 아니라 알파-스택으로 발광을 위조한다(형제 천둥 오브와 동일 전략,
  [lingpet_thunder_orb_skill.gd:467-473](../godot/scripts/lingpet/lingpet_thunder_orb_skill.gd#L467-L473)).

---

## 0. 현재 상태 진단 (왜 약한가)

| 문제 | 현재 코드 | 결과 |
|---|---|---|
| 발광감 0 | 3레이어, 최대 알파 0.28, 핫코어 없음 | "빛"이 반투명 필름 쐐기로 읽힘 |
| 광원점 없음 | 원점에 램프/플레어 없음 | 빛이 무에서 페이드되어 나옴 |
| 길이 정적 | 단색 사다리꼴, falloff/shimmer 없음 | 각도만 바뀌고 빔 자체는 죽어 있음 |
| 레벨 무반영 | 색·폭 레벨 동일, `beam_homing_focus_active` draw에서 미사용 | 유도/집중 기획이 안 보임 |
| 적중 무반응 | 보스 닿는 접점에 강조 없음 | 스킬의 페이오프(혼란)를 빔이 못 팜 |

---

## 1. 가장 중요한 트랩 — **보이는 빔 = 판정 콘 (HARD)**

기획서 §3.124가 못박은 규칙: *보이는 빔 기하 ≠ 판정 기하 금지*. 판정은
`boss-center-in-cone` (반각 `BEAM_HALF_ANGLE = 7°`, 길이 `BEAM_LENGTH = 700`).

→ **외곽 빔 외피(envelope)는 판정 콘과 정확히 같아야 한다.** 레벨/유도에 따른 "집중"
연출은 외피를 좁혀서 표현하면 **안 된다**(외피<판정이면 보스가 빔 바깥인데 혼란,
외피>판정이면 빔에 닿았는데 혼란 안 됨 — 둘 다 버그). 집중감은 **코어(내부)만**
좁히고 밝히고 희게 해서 표현한다. 외피 폭은 레벨과 무관하게 고정.

현행 버그성 상수: `BEAM_DRAW_END_WIDTH = 82`인데 판정 콘 끝 반폭은
`700·tan(7°) ≈ 86`. 즉 **보이는 빔이 판정보다 살짝 좁다** → 보스가 빔 가시
가장자리 바깥인데도 혼란이 걸릴 수 있는 더 나쁜 방향이다. 외피 끝 반폭을 상수로
박지 말고 판정에서 파생시켜 드리프트를 봉인한다:

```gdscript
const BEAM_OUTER_END_HALF_WIDTH := BEAM_LENGTH * tan(BEAM_HALF_ANGLE)  # ≈ 86
```

(원점 시작폭 8px는 램프 글로우 스프레드용 — 그 거리에서 판정 점-콘과의 오차는
무시 가능하고 램프 헤일로가 덮으므로 코스메틱으로 허용.)

---

## 2. 레이어 레시피 (뒤→앞 순서로 draw)

원점 `origin = _get_doll_beam_origin(doll) + shake_offset`, 방향
`dir = Vector2(cos(beam_angle), sin(beam_angle))`, `perp = Vector2(-dir.y, dir.x)`,
`end_pos = origin + dir * BEAM_LENGTH`. 모든 색은 일반 알파 블렌드(기존 파일·천둥
오브와 동일). 분홍 코요라 무녀 톤 유지.

### 2.1 파생 파라미터 (draw 진입 시 1회 계산)
```
level_t       = clampf((_active_skill_level - 1) / 4.0, 0, 1)     # Lv.1=0 … Lv.5=1
homing        = bool(doll.beam_homing_focus_active)               # 유도 락온 중?
on_boss       = bool(doll.beam_on_boss)                           # 이 빔이 보스 닿는 중? (§3 신호)
pulse         = 0.5 + 0.5 * sin(doll.wobble * 1.7)                # wobble 위상 펄스 (0..1)
core_intensity = clampf(0.55 + 0.30*level_t + (0.22 if homing else 0.0)
                        + (0.18 if on_boss else 0.0) + 0.08*pulse, 0.0, 1.0)
core_col      = Color(1.0, 0.62, 0.84).lerp(Color(1,1,1), 0.35*level_t + (0.20 if homing else 0.0))
```

### 2.2 외피(envelope) — **레벨 불변, 판정과 동일**
| # | 레이어 | 기하(반폭: 시작→끝) | 색 / 알파 |
|---|---|---|---|
| L0 | 외곽 헤이즈 | `8 → BEAM_OUTER_END_HALF_WIDTH(≈86)` | `(1.0, 0.40, 0.66, 0.12)` |
| L0b | 근원 산란(선택) | `8 → 외피의 0.55배`, 길이 `0.45·BEAM_LENGTH`만 | `(1.0, 0.50, 0.74, 0.10)` — 램프 근처 볼류메트릭 농도 |

### 2.3 코어 스택 — **레벨/유도/적중에 반응, 외피보다 좁음(허용)**
| # | 레이어 | 기하(반폭: 시작→끝) | 색 / 알파 |
|---|---|---|---|
| L1 | 중간 글로우 | `5 → 외피·0.34` | `core_col`, `0.16 + 0.10*core_intensity` |
| L2 | 내부 글로우 | `3 → 외피·0.16` | `core_col`, `0.24 + 0.18*core_intensity` |
| L3 | 핫밴드 | `lerp(11,5.5,level_t) 끝 반폭`, 시작 `2.5` | `(1.0,0.92,0.97)`, `lerp(0.45,0.92,core_intensity)` |
| L4 | 화이트 스파인 | `draw_line` 폭 `lerp(3.0,1.6,level_t)` | `Color(1,1,1)`, `lerp(0.50,1.0,core_intensity)` |

> 집중감 = L3/L4가 고레벨일수록 **얇아지고 더 희고 더 밝아진다**. 외피(L0)는 그대로.
> 유도 락온(homing) 시 코어가 한 단계 더 희고 밝아져 "조준됐다"가 읽힌다.

### 2.4 램프(광원점) — origin
```
draw_circle(origin, 18, (1.0,0.45,0.72, 0.10))          # 헤일로 외
draw_circle(origin, 11, (1.0,0.62,0.84, 0.22))          # 헤일로 내
draw_circle(origin, lerp(5,7,pulse), (1,1,1, 0.85))     # 화이트 핫스팟
```

### 2.5 내부 shimmer — 희소 2개 (선택, 생명감)
```
for i in 2:
    t = fposmod(doll.wobble * 0.12 + i * 0.5, 1.0)      # 0..1 origin→end, 결정적
    p = origin + dir * (t * BEAM_LENGTH)
    a = sin(t * PI) * 0.7                                 # 양 끝 페이드
    draw_circle(p, lerp(2.5, 1.0, t), Color(1,1,1, a))
```
**난수 금지** — `wobble` 위상에서 결정적으로 파생(매 프레임 재굴림하면 깜빡임).
개수 2개로 고정, 희소 효과이므로 stride LOD **면제**(`[[feedback_godot_stride_lod_sparse_flicker]]`).

### 2.6 보스 접점 플래시 — `on_boss`일 때만
```
# boss_center를 빔 직선에 투영, [0, BEAM_LENGTH]로 클램프한 지점
proj = clampf((boss_center - origin).dot(dir), 0, BEAM_LENGTH)
hit_pt = origin + dir * proj
draw_circle(hit_pt, lerp(20,26,pulse), (1.0,0.55,0.80, 0.16))
draw_circle(hit_pt, lerp(8,11,pulse),  (1,1,1, 0.40))
```
(`_draw_hit_flash` 모양 재활용. boss_center는 draw에 owner가 없으면 못 구하므로 §3 신호로 받는다.)

---

## 3. 신호 계약 (draw가 읽는 인형-dict 필드)

| 필드 | 출처 | 비고 |
|---|---|---|
| `beam_angle` | 기존 | 변경 없음 |
| `beam_homing_focus_active` | [기존, line 431에서 세팅](../godot/scripts/lingpet/lingpet_doll_curse_skill.gd#L431) | **현재 draw 미사용** → 코어 부스트로 연결 |
| `wobble` | [기존, line 413 갱신](../godot/scripts/lingpet/lingpet_doll_curse_skill.gd#L413) | **현재 빔 draw 미사용** → pulse/shimmer 위상 |
| `_active_skill_level` | 기존 멤버 | `level_t` |
| **`beam_on_boss`** (신규) | `_update_active`에서 인형별 세팅 | 접점 플래시 + 코어 부스트 |
| **`beam_boss_point`** (신규) | `_update_active`에서 인형별 세팅 | 투영된 접점 좌표(draw에 owner 없음) |

`beam_on_boss` / `beam_boss_point` 신규 세팅 위치: 이미 `_update_active`가
`_any_beam_hits_boss(owner)`를 부른다([line 360](../godot/scripts/lingpet/lingpet_doll_curse_skill.gd#L360)).
이걸 **인형별** 루프로 펼쳐서 각 인형의 `beam_on_boss` + `beam_boss_point`를 dict에
기록한다. 혼란 apply/clear 세맨틱은 **그대로**("어느 하나라도 닿으면 혼란"). 즉
적중 판정 로직 변경 없음 — 인형별 결과를 dict에 저장만 추가.

- **owner 스키마 트랩 비해당**: `beam_on_boss`/`beam_boss_point`는 인형 dict 내부
  상태이지 `owner.set()`이 아니다(`[[feedback_godot_dynamic_set_payload_guard]]`).
- **dict 키 초기화**: `_spawn_dolls()`에 `"beam_on_boss": false`,
  `"beam_boss_point": Vector2.ZERO` 추가(`.get` 폴백 의존 금지). `force_beam_angle_for_tests`에도 false로.

---

## 4. 트랩 체크리스트 (이 슬라이스에 실제 해당)

- [ ] **보이는 빔 = 판정 콘(HARD, §1)**: 외피 끝 반폭 = `BEAM_LENGTH*tan(BEAM_HALF_ANGLE)`.
  레벨/유도 집중은 **코어만**. 외피는 레벨 불변. → 스모크 B2/B5가 봉인.
- [ ] **희소 shimmer/접점 stride 면제**(`[[feedback_godot_stride_lod_sparse_flicker]]`):
  개수 적게(≤2 motes), 인덱스-stride 데시메이션 적용 금지.
- [ ] **shimmer 위상 결정적**: `wobble`에서 파생, 매 프레임 `randf()` 금지(깜빡임).
- [ ] **draw 핫패스 alloc 없음**(`Godot Hot-Path Lazy Init Trap`): 텍스처/새 배열 생성
  금지. 기존처럼 `PackedVector2Array` 임시만(레이어 수 만큼, 소량).
- [ ] **시간 VFX 후반 검수**(`[[feedback_godot_immediate_rotation_tumble]]`): pulse/shimmer/
  스윕은 4초 ACTIVE 중후반(t≈2~4s) 인게임으로 확인. t≈0/headless만으로 OK 판정 금지.
- [ ] **additive 쓰면 set/restore 규율**(`[[feedback_godot_draw_set_transform_trap]]`): 1~2번
  핫코어 스택으로 충분하면 additive 불필요. 정 약하면 코어 레이어에만
  `CanvasItemMaterial`(BLEND_ADD)을 `canvas.material` set → draw → restore. `draw_set_transform`
  금지, material 켜둔 채 방치 금지.
- [ ] **게임플레이 불변**: `_point_in_doll_beam` / 혼란 apply·clear / 공-인형 바운스
  / 오디오 변경 없음. 이 슬라이스는 **순수 비주얼 + dict 신호 추가**.

---

## 5. 스모크 브리프 (픽셀이 아니라 **계산된 파라미터**를 단언)

VFX는 픽셀 단언이 어려우므로 draw가 소비하는 파생 파라미터/신호를 헬퍼로 노출해
단언한다. 권장: `_compute_beam_core_intensity(doll)`,
`_get_beam_outer_end_half_width()`, `get_beam_draw_debug_for_tests(doll)` 같은
테스트 접근자.

| ID | 단언 |
|----|------|
| B1 | 동일 wobble에서 `beam_homing_focus_active=true`의 core_intensity > false |
| B2 | 코어 스파인 폭(Lv.5) < 코어 스파인 폭(Lv.1) **그리고** 외피 끝 반폭은 Lv.1==Lv.5 (집중은 코어만) |
| B3 | `beam_on_boss=true` → 접점 플래시 요소 방출(접점 좌표 반환), false → 없음 |
| B4 | PHASE_ACTIVE에서 기록형 가짜 canvas로 draw 호출 시 램프+코어 레이어가 실제로 방출(크래시 없음, draw 호출 수 > 외피만) |
| B5 | **외피==판정 봉인**: 외피 끝 반폭 == `BEAM_LENGTH*tan(BEAM_HALF_ANGLE)` (오차 ≤ 0.5px). 상수 82로 회귀하면 FAIL |
| B6 | `_update_active`가 인형별 `beam_on_boss` 기록: 한쪽만 보스 cone에 넣으면 그 인형만 true, 반대쪽 false |

- B5/B6는 **실패하는 방향으로 먼저** 짜서 가드 검증(외피를 코어처럼 좁히거나
  per-doll 신호를 빠뜨리면 FAIL해야 함).
- 기존 스모크([lingpet_doll_curse_skill_smoke.gd](../godot/tests/lingpet_doll_curse_skill_smoke.gd))의
  혼란/충돌 단언은 **건드리지 않는다**(게임플레이 불변 증명).

---

## 6. 배선 순서 제안 (최소 → 임팩트)

1. §1 외피 상수 파생화(`BEAM_OUTER_END_HALF_WIDTH`) + B5 — 정합 버그부터 봉인.
2. §2.2~2.4 코어 핫스택 + §2.4 화이트 스파인 — "빛처럼" 보이게(가장 큰 체감).
3. §2.4 램프 핫스팟/헤일로 — 광원 앵커.
4. §3 `beam_on_boss`/`beam_boss_point` per-doll 신호 + §2.6 접점 플래시 — 페이오프.
5. §2.1 레벨/유도 코어 변조 + B1/B2 — 레벨 체감.
6. (선택) §2.5 shimmer, §2.2 L0b 근원 산란 — 길이 생명감.

각 스텝 끝에 인게임(중후반 t) 1컷 확인. 배선 후 제가 §4 트랩 + §1 정합 + §5 스모크
관점으로 적대적 리뷰하겠습니다.
