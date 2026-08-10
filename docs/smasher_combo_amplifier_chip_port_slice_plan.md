# Smasher 콤보증폭칩(`combo_amplifier_chip`) Godot 포팅 — 슬라이스 플랜

**상태(2026-06-28): Slice 1~3 배선 + 적대리뷰 대응(R2) 완료. 신규 스모크 3개 GREEN
+ 반증검증 3건 통과.** 영향받는 기존 스모크 회귀 없음. 잔여 = 인게임 라이브 체감/픽셀
QA, 커밋. (이번엔 Claude가 직접 배선까지 진행 — 사용자 "계속/다음" 지시.)

### 적대리뷰 대응 R2 (2026-06-28)
- **R2-1 (치명적, 수정): 파워스매시 공속 amp가 고정 발사 캡에 막혀 무력화.**
  실측: `BALL_BASE_SPEED=7.65`에서 모든 현실적 incoming(8~26)에 대해 콤보 발사가 Lv0부터
  이미 `POWER_SMASH_MAX_COMBO_LAUNCH_SPEED_MULT`(2.40x=18.389)에 포화 → Lv0==Lv5, 칩의
  파워스매시 속도 증폭이 라이브에서 완전히 죽어 있었음(스모크가 base=20으로 캡을 회피해 못
  잡음 = [`character_skill_perk_checklist.md` §6](character_skill_perk_checklist.md#6-actual-gameplay-effect-wiring)의
  실제 gameplay OUTCOME 계약 위반). Python엔 per-launch 캡이
  없고(전역 60만) 칩의 +225%가 발현되므로, `_clamp_launch_speed`에서 **콤보 발사 천장을
  `×(1+smash_speed_amp)`로 완화**(combo_boosted일 때만, base 무콤보 캡 불변). 전역/파워스매시
  모션 캡(champion 35)이 상한 보장. 스모크를 **BALL_BASE_SPEED 실조건**으로 교체 + 반증검증
  (캡 완화 제거 시 Lv0==Lv5 FAIL 확인).
- **R2-2 (수정): 드라이브/파워스매싱 orb 툴팁에 콤보증폭칩 시너지 라인 추가.**
  `smasher_skill_orb_tooltip_renderer._build_description_with_runtime_bonus`에 drive/power_smashing
  분기 + `_append_combo_amplifier_runtime_bonus` + 7언어 `_format_combo_amplifier_line`,
  `_get_description_max_lines` 버짓 6. live값(드라이브 공속 Lv*90%/커브 min(Lv,3)*5%,
  파워스매시 공속 Lv*45%/부스트유지 min(Lv*10,50)%). 한글만 넣으면 비-한국어 누출이라 7언어 전부.
- **R2-3 (수정): live-wiring 회귀 추가.** `smasher_combo_amplifier_live_wiring_smoke.gd` —
  라우터 `_build_deps`가 runtime_perk_state 전달 + 드라이브 controller가 실 deps에서 칩 읽어
  발현 + 파워스매시 post_hit_handler가 실 deps에서 칩 읽어 발현(전 단계까지 실제 경로 통과).
- **R2-Q (오픈, 무관/기존): 파워스매시 in-flight 각도 캡.**
  `smasher_power_smash_motion_resolver._clamp_lateral_to_angle_ceiling`(x만 줄여 속도도 감소)은
  이번 퍽 이전부터 존재하는 **의도된 wall-arc 설계**(파일 주석 + `docs/power_smash_wall_arc_design.md`:
  40° 초과 시 벽 damping 손실이 더 커서 x 클램프로 각도 유지). 내 변경 아님, 스코프 밖.

**단일 소스(SSOT).** 이 문서가 본 포팅의 권위. 통상 분담은 배선=사용자/Codex,
적대리뷰=Claude (`feedback_design_slice_review_division`).

원본: `pingfighter.py` (frozen 레퍼런스). 대상: `godot/`.
라우팅 근거: `docs/character_skill_perk_checklist.md`(엔드투엔드),
`CLAUDE.md`(히든 UI 인바리언트).

---

## 0. 스코프 / 결론

콤보증폭칩은 **콤보 소모형 드라이브 + 파워스매싱의 콤보 비례 증가율을
추가 증폭**하는 스매셔 전용 패시브 퍽(max Lv.5)이다.

핵심 진단: **베이스 메커니즘이 이미 Godot에 전부 포팅돼 있다.** 증폭칩은
그 위에 `×(1+amp)`로 곱하는 구조라, 베이스가 없었다면 큰 포팅이었겠지만
실제로는 **"증폭값 주입 + deps 배선 + 카탈로그 등록"** 작업이다.

### 0.1 이미 완료된 것 (재작업 금지)

| 항목 | Godot 위치 | 상태 |
|---|---|---|
| 드라이브 콤보 스케일링 베이스 | `smasher_drive_initial_bounce_resolver.gd:38-77` | ✅ |
| 파워스매시 콤보 속도 베이스 | `smasher_power_smash_hit_velocity_resolver.gd:80-85` | ✅ |
| 파워스매시 초기부스트 감쇄 베이스 | `smasher_power_smash_motion_resolver.gd:4,72` (`POWER_SMASH_INITIAL_DECAY_FACTOR=0.89024`) | ✅ |
| 퍽 아이콘 PNG + 렌더러 등록 | `runtime_perk_icon_renderer.gd:44` (path-derived, extension_gear와 동일) | ✅ |
| 고스트샷 소비자 (칩 레벨 read) | `smasher_ghost_shot_state.gd:283-288,455-459` | ⚠️ 카탈로그 미등록이라 항상 0 (dead) |

### 0.2 빠진 것 (이 플랜의 작업)

1. `combo_amplifier_chip` **카탈로그 미등록** → 제공/레벨업/적용 불가.
2. `get_combo_amplifier_chip_bonus()` **헬퍼 부재** (Python 26129-26149).
3. 드라이브 / 파워스매시속도 / 감쇄 **3개 증폭 주입 지점 미배선**.
4. 드라이브·파워스매시 경로에 `runtime_perk_state` **deps 미전달**.
5. **포팅 스모크 부재**.

### 0.3 잠긴 결정 (추천안 채택)

- **D1 — 감쇄 베이스라인 = Option A (Godot 체감 보존).**
  Python lv0 `_decay_factor=1.0`이지만 Godot는 `0.89024`로 이미 리밸런스됨.
  → `decay = 0.89024 * max(0.5, 1.0 - Lv*0.10)`. raw Python(`max(0.5,1-Lv*0.10)`)로
  교체하면 Lv0 감쇄가 현재보다 빨라져 출시된 파워스매시 체감을 회귀시킴.
  비율(-10%/Lv, cap -50%)만 기존 베이스에 곱한다.
- **D2 — 고스트샷 각도 divergence = 이번 범위 밖(문서화만).**
  기존 `smasher_ghost_shot_state.gd:285`는 `angle *= max(0.45, 1-Lv*0.08)`,
  Python은 `40° - Lv*5 (clamp 10°)`. **속도는 일치**(둘 다 `*(1+Lv*0.10)`),
  각도만 다름. 칩 등록 시 이 dead 브랜치가 **live**가 되므로(속도+10%/Lv는
  의도대로 작동, 각도는 살짝 다른 방식으로 좁아짐) §6 후속으로 분리. 본 포팅을
  막지 않음.
- **D3 — base 상수는 Godot 값 유지.** Godot 드라이브/파워스매시 base는 Python과
  다르다(`DRIVE_EFFECT_MULT=0.8` 등 리밸런스). 증폭칩은 **콤보 항에만 `×(1+amp)`**.
  Python base 숫자로 Godot base를 재유도하지 말 것. 패리티 타겟은 **증폭 비율**
  (+90%/Lv 공속, +5%/Lv 커브 Lv3캡, +45%/Lv 스매시, -10%/Lv 감쇄)이지 base 크기 아님.
  (`feedback_godot_boss_knockback_port_parity` 참조: 형제상수 빌려쓰기 금지.)

---

## 1. 패리티 레퍼런스 (Python ↔ Godot)

### 1.1 증폭 비율 (헬퍼)

`get_combo_amplifier_chip_bonus()` (Python `pingfighter.py:26136-26149`):

```
raw_level = get_runtime_skill_level("combo_amplifier_chip")   # 유효레벨(오버플로우 포함)
if raw_level <= 0: return (0,0,0)
drive_speed_amp = raw_level * 0.90        # +90%/Lv,  무캡 (오버플로우 스케일)
smash_speed_amp = raw_level * 0.45        # +45%/Lv,  무캡
drive_curve_amp = min(raw_level,3) * 0.05 # +5%/Lv,   Lv3 하드캡(+15%)
```

### 1.2 드라이브 주입 (Python `167519-167531` ↔ Godot resolver)

Python은 콤보 항과 그 캡 **둘 다** `×(1+amp)`. base 배율(1.015)·base_spin·
base 커브캡(0.48)은 **비증폭**.

| Python 콤보 항 | Godot 등가 (resolver 라인) | 증폭 |
|---|---|---|
| `_speed_per_combo=0.012*(1+ds)`, `_speed_cap=0.072*(1+ds)` | `SMASHER_DRIVE_COMBO_SPEED_PER_COMBO`, `..._SPEED_CAP` → L40-43 `drive_speed_bypass_bonus` | `×(1+drive_speed)` 양쪽 |
| `_spin_per_combo=0.08*(1+dc)`, `_spin_cap=0.48*(1+dc)` | `SMASHER_DRIVE_COMBO_SPIN_PER_COMBO`, `..._SPIN_CAP` → L70-73 `drive_combo_spin_bonus` | `×(1+drive_curve)` 양쪽 |
| `_spin_cap_per_combo=0.06*(1+dc)`, `_spin_cap_max=0.36*(1+dc)` | `SMASHER_DRIVE_COMBO_SPIN_CAP_PER_COMBO`, `..._SPIN_CAP_BONUS_MAX` → L46-49 | `×(1+drive_curve)` 양쪽 |
| base `0.52*MULT` (L46), `SMASHER_DRIVE_COMBO_SPEED_MULT` (L39) | — | **비증폭** |

게이트: `combo_active = combo_count >= combo_min_count(=2)` (resolver L31). 증폭은
`combo_active` 브랜치 안에서만. Python `if _effective_combo >= 2:` 일치.

### 1.3 파워스매시 속도 주입 (Python `186171-186177` ↔ Godot)

```
# Python
_per_combo = 0.04*(1+_amp_smash);  _cap = 0.20*(1+_amp_smash)
_combo_final_bonus = min(combo_consumed * _per_combo, _cap)
ball_vel *= (1.0 + _combo_final_bonus)
```

Godot `hit_velocity_resolver.gd:80-85` — `POWER_SMASH_COMBO_SPEED_PER_COUNT`(L12)와
`POWER_SMASH_COMBO_SPEED_CAP`(L13) **둘 다** `×(1+smash_speed)`. 게이트는 기존
`combo_boosted`(L41, `combo_consumed >= combo_min_count`) 유지.

### 1.4 초기부스트 감쇄 완화 (Python `169222-169225` ↔ Godot) — **D1=Option A**

```
# Python: _decay_factor = max(0.5, 1.0 - _chip_level*0.10)
#         interpolated = boosted - (boosted - target)*progress*_decay_factor
# Godot Option A (체감 보존):
decay = POWER_SMASH_INITIAL_DECAY_FACTOR * max(0.5, 1.0 - chip_level*0.10)
```

`motion_resolver.gd:72`의 상수 `POWER_SMASH_INITIAL_DECAY_FACTOR(=0.89024)` 자리.
감쇄율이 **작아질수록** 초기 부스트 속도에 오래 머물러 폭발 유지. Lv별 ratio:
1→0.90, 2→0.80, 3→0.70, 4→0.60, 5→0.50(cap).

---

## 2. Slice 1 — 카탈로그 엔트리 + 증폭 헬퍼

**파일:** `runtime_perk_catalog.gd`, `runtime_perk_state.gd`. 배선 가장 단순.

### 2.1 카탈로그 엔트리

`runtime_perk_catalog.gd` `SMASHER_PERKS`의 `extension_gear` 직후(현 L426 `},` 다음,
닫는 `}`(L427) 앞)에 추가. Python `21981-21995` 1:1. **설명 문자열은 증폭 비율을
서술**하므로(base 크기 아님) Godot 리밸런스와 무관하게 그대로 포팅:

```gdscript
"combo_amplifier_chip": {
    "name": "콤보증폭칩",
    "max_level": 5,
    "descriptions": {
        1: "콤보 효과 증폭: 드라이브 공속+90%, 커브+5%, 파워스매시 공속+45%, 초기부스트 감쇄 -10%",
        2: "콤보 효과 증폭: 드라이브 공속+180%, 커브+10%, 파워스매시 공속+90%, 초기부스트 감쇄 -20%",
        3: "콤보 효과 증폭: 드라이브 공속+270%, 커브+15%, 파워스매시 공속+135%, 초기부스트 감쇄 -30%",
        4: "콤보 효과 증폭: 드라이브 공속+360%, 커브+15%(캡), 파워스매시 공속+180%, 초기부스트 감쇄 -40%",
        5: "콤보 효과 증폭: 드라이브 공속+450%, 커브+15%(캡), 파워스매시 공속+225%, 초기부스트 감쇄 -50%(캡)",
    },
    "detail": "콤보 소모형 드라이브/파워스매싱의 콤보 비례 증가율을 추가로 증폭합니다. 공속 증폭은 레벨에 따라 계속 증가하지만, 드라이브 커브 증폭은 Lv3에서 캡됩니다(밸런스 보호). 또한 파워스매싱의 초기 부스트 감쇄가 완만해져 폭발력이 더 오래 유지됩니다.",
    "icon_color": Color(1.0, 100.0 / 255.0, 200.0 / 255.0),
    "tree": "smasher",
    "character_restriction": "smasher",
},
```

이 한 줄로 제공(`get_choices` L758) / 레벨업(`runtime_skill_levels`) /
디버그 목록(L848) / 아이콘(이미 배선) 자동 활성. `unlocks_skill` 없음 →
`_filter_unlock_slot_budget`(L993) 영향 없음(extension_gear와 동일).

### 2.2 증폭 헬퍼

`runtime_perk_state.gd`의 `get_runtime_skill_bonus`(L1133) 근처에 추가. GDScript는
튜플 미지원 → Dictionary 반환. **레벨은 `get_runtime_skill_level`(유효레벨)** 사용해야
초월자관/점화 오버플로우가 공속에 반영되고, 커브만 `min(level,3)` 독립 하드캡:

```gdscript
func get_combo_amplifier_chip_bonus() -> Dictionary:
    var level: int = get_runtime_skill_level("combo_amplifier_chip")
    if level <= 0:
        return {"drive_speed": 0.0, "drive_curve": 0.0, "smash_speed": 0.0}
    return {
        "drive_speed": float(level) * 0.90,
        "smash_speed": float(level) * 0.45,
        "drive_curve": float(mini(level, 3)) * 0.05,
    }
```

> 트랩(Owner-Field/오버플로우): 정적 per-level 설명은 Lv5까지만. 아이템/점화로
> Lv6+ 오버플로우 시 설명은 Lv5 문자열 fallback(`_build_level_choice` L981)이지만
> 공속 게임플레이는 계속 스케일(커브는 Lv3캡 유지). opt-out 정책상 허용 — 단
> 라이브 QA에서 Lv6+ 카드 텍스트가 Lv5로 보이는 것 확인.

**Slice 1 검증:** F-key/디버그 퍽 메뉴에 콤보증폭칩 등장 + 아이콘 렌더 +
레벨업 시 `runtime_skill_levels["combo_amplifier_chip"]` 증가.

---

## 3. Slice 2 — 드라이브 증폭 + deps 배선 + 스모크

### 3.1 deps 전달

`paddle_bounce_drive_activation_router.gd._build_deps()`(L74-87 allowlist)에 추가:

```gdscript
"runtime_perk_state": deps.get("runtime_perk_state", null),
```

(상류 `ball_dependency_context.gd`가 이미 `runtime_perk_state` 인스턴스화 — 전달만
누락. allowlist라 명시 추가 필요.)

### 3.2 칩 레벨 read → amp 전달

`smasher_drive_activation_controller.gd` (L43-57). 이미 `deps`·`combo_used` 보유:

```gdscript
var amp_drive_speed: float = 0.0
var amp_drive_curve: float = 0.0
var rps: Object = deps.get("runtime_perk_state", null)
if rps != null and rps.has_method("get_combo_amplifier_chip_bonus"):
    var amp: Dictionary = rps.get_combo_amplifier_chip_bonus()
    amp_drive_speed = float(amp.get("drive_speed", 0.0))
    amp_drive_curve = float(amp.get("drive_curve", 0.0))
# apply_initial_bounce(...)에 amp_drive_speed, amp_drive_curve 인자 추가
```

`smasher_drive_bounce_state.apply_initial_bounce`(thin delegator)와
`smasher_drive_initial_bounce_resolver.apply` 시그니처에 두 인자 thread(default 0.0).

### 3.3 resolver 주입 (§1.2 표대로)

`smasher_drive_initial_bounce_resolver.gd`, `combo_active` 브랜치 안:

```gdscript
# L40-43
drive_speed_bypass_bonus = min(
    float(combo_count) * SMASHER_DRIVE_COMBO_SPEED_PER_COMBO * (1.0 + amp_drive_speed),
    SMASHER_DRIVE_COMBO_SPEED_CAP * (1.0 + amp_drive_speed)
)
# L46-49 (base 0.52*MULT 비증폭, 콤보 항만)
drive_spin_cap = 0.52 * DRIVE_EFFECT_MULT + min(
    float(combo_count) * SMASHER_DRIVE_COMBO_SPIN_CAP_PER_COMBO * (1.0 + amp_drive_curve),
    SMASHER_DRIVE_COMBO_SPIN_CAP_BONUS_MAX * (1.0 + amp_drive_curve)
)
# L70-73
drive_combo_spin_bonus = min(
    float(combo_count) * SMASHER_DRIVE_COMBO_SPIN_PER_COMBO * (1.0 + amp_drive_curve),
    SMASHER_DRIVE_COMBO_SPIN_CAP * (1.0 + amp_drive_curve)
)
```

### 3.4 스모크 — `smasher_combo_amplifier_drive_smoke.gd` (신규)

OUTCOME 단언(arming flag 아님). resolver를 직접 `.new()`해서 `apply()` 호출:
- `_verify_chip_raises_drive_speed`: 동일 콤보(예 5)·동일 입력에서 Lv5 amp의
  `result.speed` > Lv0 `result.speed` (또는 `speed_increase`).
- `_verify_chip_raises_drive_spin`: Lv5의 `result.spin_strength` > Lv0.
- `_verify_lv0_unchanged`: amp 0 → 기존 값 그대로(회귀 가드).
- **반증검증**: §3.3 `×(1+amp)`를 빼면(toggle) Lv5==Lv0이 되어 위 단언 FAIL 확인
  (in-place Edit 토글 — `git reset/checkout/stash` 금지).
- 커브 Lv3캡: Lv3 amp == Lv5 amp의 spin 단언(커브 레인은 Lv3 이상 동일).

---

## 4. Slice 3 — 파워스매시 속도+감쇄 + deps 배선 + 스모크

파워스매시는 **속도(hit 경로)** 와 **감쇄(motion 경로)** 가 별도 콜체인이라 주입
2곳 + 배선 2곳.

### 4.1 속도 (+45%/Lv) — hit 경로

`paddle_bounce_power_hit_handler.apply()`는 **`deps` 인자가 없고 `context`만** 받음
(L9-17). 두 가지 배선 옵션:
- **권장(A): context 주입.** 상류 `paddle_bounce_post_hit_handler`(deps 보유, L430에서
  `deps.runtime_perk_state` 이미 사용)에서 `smash_speed_amp`를 계산해 `context`에 넣음
  (`combo_min_count`/`base_ball_speed`가 이미 context로 도착하는 것과 동일 패턴).
- (B): 핸들러에 `deps` 인자 추가 — 더 침습적.

→ `power_state.apply_hit_velocity` → `velocity_facade.apply_hit_velocity` →
`hit_velocity_resolver.apply`로 `smash_speed_amp`(default 0.0) thread.

`hit_velocity_resolver.gd:80-85`:

```gdscript
if combo_boosted:
    var per_count: float = POWER_SMASH_COMBO_SPEED_PER_COUNT * (1.0 + smash_speed_amp)
    var cap: float = POWER_SMASH_COMBO_SPEED_CAP * (1.0 + smash_speed_amp)
    var combo_final_bonus: float = min(float(combo_consumed) * per_count, cap)
    ball_velocity *= 1.0 + combo_final_bonus
```

### 4.2 감쇄 완화 (-10%/Lv, cap -50%) — motion 경로, **D1=Option A**

`smasher_power_smash_motion_controller.apply_motion(... context, deps)`는 **deps 보유**
(L36) 이지만 `power_state.apply_motion(ball_vel, fps_scale, gravity, boost_duration)`로
**deps를 버림**(L45-50). 여기서 칩 레벨 read 후 thread:

```gdscript
var chip_level: int = 0
var rps: Object = deps.get("runtime_perk_state", null)
if rps != null and rps.has_method("get_runtime_skill_level"):
    chip_level = int(rps.get_runtime_skill_level("combo_amplifier_chip"))
# power_state.apply_motion(...)에 chip_level 인자 추가 → facade → motion_resolver
```

`motion_resolver._apply_initial_boost`(L72):

```gdscript
var decay: float = POWER_SMASH_INITIAL_DECAY_FACTOR * max(0.5, 1.0 - float(chip_level) * 0.10)
var interpolated_speed: float = initial_boosted_speed - (initial_boosted_speed - target_speed) * boost_progress * decay
```

### 4.3 스모크 — `smasher_combo_amplifier_powersmash_smoke.gd` (신규)

- `_verify_chip_raises_launch_speed`: combo_boosted(combo≥2) 발사에서 Lv5 amp의
  발사 공속 > Lv0. **단, `_clamp_launch_speed`(L86-91) 캡에 막히지 않는** combo·base로
  설정(캡에 닿으면 차이가 안 보임 — 작은 combo로 검증).
- `_verify_decay_softens_with_chip`: 동일 `boost_progress`에서 Lv5 `decay`로 보간한
  `interpolated_speed` > Lv0. 즉 부스트가 더 오래 유지됨(OUTCOME).
- `_verify_lv0_baseline_unchanged`: chip 0 → 감쇄=0.89024 그대로(현 체감 회귀 가드).
- **반증검증** 2건: 속도 `×(1+amp)` 제거 → Lv5==Lv0 FAIL; 감쇄 `*max(...)` 제거 →
  Lv5==Lv0 FAIL (in-place 토글).
- 게이트: `combo_consumed < combo_min_count`면 속도 amp 미적용 카운터케이스.

> 단위 트랩(`feedback_godot_ball_vel_pxframe_units`): `ball_vel`은 px/frame. amp는
> 기존 콤보 비율에 곱하는 무차원 배수라 단위 안전. px/sec로 재스케일 금지.

---

## 5. 트랩 / 인바리언트 (재유도 금지)

- **base 비증폭.** 드라이브 base 배율(1.015·`SMASHER_DRIVE_COMBO_SPEED_MULT`),
  base_spin, base 커브캡(0.52*MULT), 파워스매시 base 초기부스트(1.197568/1.263424)는
  증폭 금지. **콤보 항만** `×(1+amp)`.
- **커브 Lv3 하드캡.** `drive_curve = min(level,3)*0.05`. 오버플로우(아이템/점화)가
  레벨을 올려도 커브는 +15% 고정, 공속/스매시는 계속 스케일. 분리 유지.
- **유효레벨 단일 경로.** 모든 read는 `runtime_perk_state.get_runtime_skill_level`
  (effective). raw `runtime_skill_levels.get()` 직접 read 금지
  (`docs/item_runtime_checklist` 레벨 베이시스 규칙).
- **deps allowlist.** 드라이브 라우터 `_build_deps`는 명시 allowlist —
  `runtime_perk_state` 추가 안 하면 controller가 항상 null→amp 0(조용한 dead). 파워스매시
  motion 컨트롤러는 deps 받지만 `power_state.apply_motion`에서 **버리는** 지점이 갭.
- **게이트 = combo_active만.** 드라이브 `combo_count>=combo_min_count`,
  파워스매시 `combo_consumed>=combo_min_count`. 0~1 콤보(하향) 브랜치엔 amp 미적용
  (Python `if >=2` 일치).
- **스모크는 OUTCOME + 반증검증.** arming flag/레벨세팅이 아니라 실제 발사 공속/스핀/
  보간속도를 단언. force-succeed 테스트는 compounding/누락 버그를 가림. 토글은 in-place
  Edit만(`git reset/checkout/stash` 금지 — uncommitted WIP 파괴).
- **schema-gated owner 불필요.** 본 퍽은 owner.set 동기화가 아니라 deps→resolver 직결
  read 경로. (Owner-Field Schema Trap 비해당.)

---

## 6. 후속 / 확인 항목 (본 포팅 비차단)

- **고스트샷 각도 패리티(D2).** 칩 등록 시 `smasher_ghost_shot_state.gd:283-288`
  dead 브랜치가 live화. 속도(+10%/Lv)는 Python 일치, **각도만** Godot
  `*max(0.45,1-Lv*0.08)` vs Python `40°-Lv*5(clamp10°)`. 별도 슬라이스로 정렬 여부
  결정. 라이브에서 고스트샷 산포가 과도/과소면 우선 처리.
- **로컬라이제이션 동기화.** extension_gear가 `localization/{en,ja,ko,zh}.json`에
  퍽 이름/설명 키를 갖는지 확인. 가지면 콤보증폭칩도 4언어 추가
  (`feedback_godot_localization_copy_sync`: grep 0건으로 "번역없음" 단정 금지 —
  숫자 변형까지 확인). 카탈로그 Korean 원문이 그대로 노출되는 구조면 불필요.
- **체크리스트 백필.** `docs/character_skill_perk_checklist.md`에 "enhancer 퍽이
  베이스 스킬의 콤보 항을 증폭할 때 deps allowlist/콜체인 thread 누락 = 조용한 dead"
  가 없으면 한 줄 추가(반복 가능·코드만으로 재유도 불가 → 백필 정책 충족).

---

## 7. 사인오프 체크리스트

- [x] Slice 1: 카탈로그 엔트리(runtime_perk_catalog) + `get_combo_amplifier_chip_bonus()`
  헬퍼(runtime_perk_state). 헬퍼 값/커브 Lv3캡 스모크 검증.
- [x] Slice 2: 라우터 deps + controller read + bounce_state/resolver thread + 3 주입.
  `smasher_combo_amplifier_drive_smoke.gd` GREEN, 반증검증(증폭 무력화 시 speed+spin FAIL) 통과.
- [x] Slice 3: 속도(hit 경로 context-amp) + 감쇄(motion 경로 deps, D1=Option A) 배선.
  `smasher_combo_amplifier_powersmash_smoke.gd` GREEN(속도/감쇄/Lv0 baseline/no-combo),
  반증검증(launch speed + decay 둘 다 FAIL) 통과.
- [x] 영향받는 기존 스모크 회귀 없음: junior_power_smash_tuning / power_smash_angle_cap /
  wall_arc / skill_lock / power_smash_player_return / ghost_shot_motion_skip 전부 GREEN
  (옵셔널 파라미터 추가라 하위호환).
- [x] **로컬라이제이션(필수였음 — 초기 오판 정정).** 카탈로그 한글은
  `get_all_perk_data()`→`LanguageSettings.localize_perk_data()`를 경유하므로,
  미배선 시 6개 비-한국어 언어 전부 한글 누출 → `localization_coverage_smoke` FAIL.
  `language_settings_data.gd`에 형제 `extension_gear`처럼 **13항목**(퍽id→키맵 1 +
  6언어 NAME + 6언어 SUMMARY) 추가 완료. SUMMARY가 모든 레벨 description을 비-한국어에서
  요약으로 collapse(레벨별 번역 불필요). 스모크 GREEN. (트랩: 퍽 번역은 상위
  `localization/*.json`이 아니라 `language_settings_data.gd`에 있음 — 상위 grep 0건이
  "불필요" 오판을 유발. 체크리스트 §2.1 백필 완료.)
- [x] **제 변경 blast radius 110개 스모크 전부 GREEN** (localization 수정 후 재확인).
- [ ] (무관/기존 WIP) `character_info_equipment_anatomy_smoke` FAIL은 브랜치의 진행 중
  character_info 오버레이 리팩토링(파일 ~13 M + drag_controller/discard_confirm 신규)에서
  유래 — 제 변경 파일 집합과 교집합 0. 제 작업 아님, 미수정(타인 WIP).
- [ ] 프리푸시 게이트(전체 스모크): 위 기존 WIP FAIL 때문에 통째 GREEN은 브랜치 오너의 WIP 완료에 의존
- [ ] 라이브 픽셀/체감 QA: Lv1 vs Lv5 드라이브 커브·공속, 파워스매시 폭발 유지 차이,
  디버그 퍽 메뉴 등장 + 아이콘
- [ ] 커밋(이 변경은 광범위 WIP 브랜치에 추가됨 — 선별 스테이징 필요)

> **주의(이제 LIVE):** 칩 카탈로그 등록으로 `smasher_ghost_shot_state.gd:283-288`의
> 그동안 dead였던 칩 소비 브랜치가 활성화됨. 속도(+10%/Lv)는 Python 일치, 각도만
> Godot식(`*max(0.45,1-Lv*0.08)`). §6 D2 후속 결정 대상 — 고스트샷 보유 시 라이브 산포 확인.
