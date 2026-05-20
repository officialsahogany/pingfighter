# Stage 5 홍련 보스 스킬 카드 HUD 디자인 spec

작성일: 2026-05-17
연계: [stage5_hongryun_godot_port_plan.md](stage5_hongryun_godot_port_plan.md) §4.6, [godot/scripts/stages/stage5/stage5_hongryun_state.gd](../godot/scripts/stages/stage5/stage5_hongryun_state.gd)

이 문서는 Codex가 `stage5_hongryun_boss_skill_hud_renderer.gd`를 [stage1_dalji_boss_skill_hud_renderer.gd](../godot/scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd) / [stage4_ponk_boss_skill_hud_renderer.gd](../godot/scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd) 패턴으로 fork할 때 직접 참조하는 spec이다. Renderer 코드 작성 단계로 들어가기 전에 이 문서를 먼저 굳혀서 데이터 컨트랙트가 흔들리지 않게 한다.

## 0. 합의된 결정 (변경 시 이 문서부터 갱신)

1. **Dragon orb 시각화: 5칸 슬롯 유지 + 마지막 칸만 fractional fill.**
   - `dragon_orb_count`는 float이지만 `floor(count)`만큼은 완전 충전 슬롯으로, 나머지 `frac = count - floor(count)`는 다음(마지막) 슬롯의 부분 채움으로 표현한다.
   - 부분 채움 방향: 슬롯 하단 → 상단 vertical fill (radial sweep 아님 — 정수 슬롯과 시각적으로 비교하기 쉽도록).
2. **`inferno_ready` 임계는 엄격히 `dragon_orb_count >= DRAGON_ORB_MAX (5.0)`.** drain으로 4.x로 떨어진 후 재충전이 정수 5.0에 도달해야만 ready로 켜진다. fractional drain은 시각화 정보일 뿐 발동 임계 완화 도구가 아니다.
3. **카드 슬롯 = 2개 출고 + 1개 예약.** 출고 시 화염탄/홍련폭염만 보인다. 화염기계 카드는 [stage5_hongryun_fire_machine_event.gd](../godot/scripts/stages/stage5/) 모듈이 추가될 때 같은 스타일로 한 줄만 더해질 수 있도록 슬롯 정책을 미리 박는다.

## 1. 데이터 컨트랙트 — state.gd가 노출하는 dict

`stage5_hongryun_state.get_hud_context()` 리턴 dict의 모양은 다음과 같다 (현재 state.gd 구현과 동일):

```gdscript
{
    "stage5_boss_skill_hud_active": true,
    "stage5_boss_skill_hud_boss_name": "홍련",
    "stage5_boss_skill_hud_status": status,                  # state-wide status
    "stage5_boss_skill_hud_dragon_orb_count": float,         # 0.0 ~ 5.0 (fractional)
    "stage5_boss_skill_hud_dragon_orb_max": 5,
    "stage5_boss_skill_hud_dragon_orb_ready": bool,          # >= 5.0 일 때만 true
    "stage5_boss_skill_hud_inferno_active": bool,
    "stage5_boss_skill_hud_skills": [
        { /* 홍련 화염탄 카드 entry */ },
        { /* 홍련폭염 카드 entry */ },
        # fire_machine 카드는 추후 fire_machine_event가 append한다
    ],
}
```

각 skill entry는 stage1/stage4와 동일한 base shape를 따른다:

```gdscript
{
    "id": String,                # 카드 PNG / 라벨 매핑 키
    "label": String,             # 보스 캐릭터 라벨, 카드 안에는 출력 안 함 (툴팁용)
    "status": String,            # charging / ready / casting / paused / inferno_charge / locked
    "ready": bool,
    "trigger_type": String,      # 표시는 툴팁 only
    "cooldown_remaining": float, # 화염탄 카드에만 의미 있음
    "cooldown_total": float,
    "progress": float,           # 0.0~1.0, fill 비율
    "color": Color,              # side strip / fallback fill 색
    # 홍련폭염 카드 전용 키:
    "gauge": float,              # = dragon_orb_count
    "gauge_max": int,            # = DRAGON_ORB_MAX (5)
}
```

추가 hint 키 정책 — renderer가 entry에 다음 키가 있으면 dragon orb 오버레이를 그린다 (없으면 standard fill bar만):

- `entry["render_kind"] == "dragon_orb_gauge"` — 홍련폭염 카드 식별자. state.gd `_get_inferno_hud_skill()`에 추가 필요.

이 키는 spec 단계에서 추가하는 것이며, state.gd 구현 시 한 줄 추가하면 renderer가 카드 종류를 분기할 수 있다. (Codex 작업 항목)

## 2. 카드 슬롯 정책

stage4 ponk 패턴을 baseline으로 한다 (stage1의 commando_firearm_panel 회피 로직은 홍련에는 불필요).

| 슬롯 | 카드 id | 출고 여부 | 채우는 owner |
|---|---|---|---|
| 1 | `hongryun_fireball` | 출고 | `stage5_hongryun_state` |
| 2 | `hongryun_inferno` | 출고 | `stage5_hongryun_state` |
| 3 | `hongryun_fire_machine` | 예약 | `stage5_hongryun_fire_machine_event` (TODO) |

**중요**: state.gd의 `get_hud_context()`는 위 2개 entry만 반환하지만, fire_machine_event 모듈이 추가되면 같은 dict의 `stage5_boss_skill_hud_skills` 배열에 3번째 entry를 append할 수 있도록 위치를 비워둔다. Renderer는 entry 수에 무관하게 동작해야 하므로 hardcoded `if entries.size() == 2:` 같은 분기를 넣지 않는다 (stage1 / stage4도 그렇게 안 함).

정렬 우선순위는 stage1/stage4와 동일:
- `casting` (0) → `ready` (1) → 일반 charging/paused (2) → `locked`/`used` (3)
- 같은 우선순위 안에서는 progress 큰 쪽이 위 (stage4 패턴) — 발동 임박한 카드가 시각적으로 위로 올라옴.

## 3. 카드별 상세 spec

### 3.1 홍련 화염탄 (`hongryun_fireball`)

stage1 whip / stage4 magnetic_field와 같은 표준 cooldown 카드 모양.

| 항목 | 값 |
|---|---|
| 라벨 (툴팁) | "홍련 화염탄" |
| 카드 색 (`color`) | `Color(0.95, 0.42, 0.30, 1.0)` — 진한 주홍 (state.gd 기존) |
| 사이드 strip 색 | `Color(0.86, 0.20, 0.18, 0.72)` — stage1 dalji와 동일 톤 (홍련 화염 분위기에 그대로 맞음) |
| Fill ratio | `1.0 - cooldown_remaining / cooldown_total` |
| Active border | casting (보스 throwing windup 중) 시 주황 펄스 |
| Ready border | 쿨다운 0 도달 시 초록 펄스 |
| 카드 텍스처 | `res://assets/sprites/hud/stage5_hongryun_fireball_skillcard_imagegen_v1.png` (TODO: 자산) |
| Fallback texture | `res://assets/sprites/hud/stage5_hongryun_motion_sprites_imagegen_v2.png` (이미 마이그레이션됨, 카드 PNG 도착 전 임시) |
| 트리거 (툴팁) | "자동" |
| 쿨다운 (툴팁) | "쿨타임 3.5 ~ 5.0초" |
| 설명 (툴팁, 2줄 컷) | "홍련이 화염탄을 발사합니다. 맞으면 용 구슬 게이지가 1칸 충전됩니다." |

### 3.2 홍련폭염 (`hongryun_inferno`)

용 구슬 5칸 게이지 카드. **3.1과 다른 점은 카드 PNG 위에 dragon orb 5칸 오버레이가 추가된다는 것**.

| 항목 | 값 |
|---|---|
| 라벨 (툴팁) | "홍련폭염" |
| 카드 색 (`color`) | `Color(1.0, 0.20, 0.20, 1.0)` — 깊은 적색 (state.gd 기존) |
| 사이드 strip 색 | `Color(1.0, 0.32, 0.18, 0.86)` — 화염탄보다 더 강한 적색 (위계 표현) |
| Fill ratio | `dragon_orb_count / DRAGON_ORB_MAX` (fractional 그대로) |
| Render kind | `"dragon_orb_gauge"` (renderer가 오버레이 그리기 위한 식별자) |
| 카드 텍스처 | `res://assets/sprites/hud/stage5_hongryun_inferno_skillcard_imagegen_v1.png` (TODO: 자산) |
| Fallback texture | `res://assets/sprites/hud/stage5_hongryun_dragon_head_sheet_imagegen_v3_16f.png` (이미 마이그레이션됨, 0번 셀 사용) |
| 트리거 (툴팁) | "용 구슬 5칸 충전 후 보스 패들 접촉" |
| 설명 (툴팁, 2줄 컷) | "5번 맞으면 홍련이 공을 휘감아 뱀처럼 돌진시킵니다. 가드 시 진폭이 줄어듭니다." |

#### Dragon orb 5칸 오버레이 (홍련폭염 카드 only)

스펙:

- 위치: 카드 **하단 안쪽**, side strip(왼쪽 빨간 띠)을 침범하지 않도록 left padding `side_w + 1.0 * scale_factor`.
- 슬롯 5개를 가로로 등간격 배치. 각 슬롯은 작은 다이아몬드 또는 원형 dot (지름 약 `card_h * 0.28`).
- 슬롯 간 gap: `1.0 * scale_factor`.
- 전체 오버레이 가로폭은 카드 가로의 60~70% 정도, 우측 정렬 (side strip 회피).
- 슬롯 상태별 시각:
  | 슬롯 상태 | 시각 |
  |---|---|
  | 빈 슬롯 (`i >= ceil(count)`) | 어두운 윤곽선만, alpha 0.45, 내부 어두운 적색 |
  | 완전 충전 슬롯 (`i < floor(count)`) | 진한 적색 fill + 살짝 outer glow (`Color(1.0, 0.32, 0.20, 1.0)`) |
  | 부분 채움 슬롯 (`floor(count) <= i < ceil(count)`) | 하단부터 `frac` 비율로 vertical fill, 윗부분은 빈 슬롯 스타일 |
  | `inferno_ready` (5/5) 도달 | 5칸 모두 pulsate (`0.7 + 0.3 * sin(time * 4.5)`), border glow 추가 |
- `inferno_active` 동안에는 5칸이 빠르게 비워지는 흡수 애니메이션 (renderer 측에서 별도 timer로 처리, state.gd가 즉시 `dragon_orb_count = 0`으로 깎는 것과 별개의 시각 효과).

### 3.3 화염기계 카드 (`hongryun_fire_machine`) — 예약 슬롯

state.gd가 출고 시점에 만들지 않는다. `stage5_hongryun_fire_machine_event` 모듈이 추가될 때 같은 dict shape로 entry를 append한다. Renderer는 entry가 있을 때만 그린다.

미래 예상 spec (참고용):

- 라벨: "화염기계" 또는 "용숨결"
- 색: `Color(0.85, 0.55, 0.20, 1.0)` — 황금 화염 (홍련의 다른 두 카드와 시각 위계 구분)
- 트리거: "이벤트 발동" (필러에서 자동 트리거)
- 진행률: 이벤트 cooldown / windup

## 4. Status 문자열 ↔ 시각 매핑

state.gd가 entry `status`로 내보내는 문자열을 renderer가 어떻게 해석하는지 표:

| state.gd `status` | Fill | Border | 비고 |
|---|---|---|---|
| `"charging"` | progress 비율 | 어두운 회갈색 (`Color(0.28, 0.23, 0.17, 0.70)`) | 기본 상태 |
| `"paused"` | 동결 (lerp 진행 안 함) | 더 어두운 회색 (`Color(0.24, 0.22, 0.20, 0.62)`) | serve-wait 중 |
| `"ready"` | 100% | 초록 펄스 (`Color(0.48, 1.0, 0.64, 0.70+pulse)`) | 화염탄 cooldown 0 또는 홍련폭염 inferno_ready |
| `"casting"` | 100% | 주황 펄스 (`Color(1.0, 0.84, 0.26, 0.88+pulse)`) | 화염탄 발사 windup, 홍련폭염 trail phase |
| `"inferno_charge"` | 100% + 위에 wedge | 적색 빠른 펄스 (`Color(1.0, 0.30, 0.20, 0.95)`, freq 8Hz) | **홍련폭염 전용**, 1.4초 charge 동안만 |
| `"locked"` | 0%, 카드 어두움 | 회색 (`Color(0.36, 0.34, 0.32, 0.62)`) | 화염기계가 미해금 상태일 때만 (현재 미사용) |

### `inferno_charge` 1.4초 시각 피드백 — 카드 위 카운트다운 wedge

- 카드 우측 상단에 작은 부채꼴 (radius `card_h * 0.45`).
- `progress = inferno_charge_timer / INFERNO_CHARGE_SEC` (1.0 → 0.0).
- 시계 반대 방향으로 줄어들면서 fill (`Color(1.0, 0.92, 0.40, 0.90)`).
- 동시에 dragon orb 5칸은 안쪽으로 빨려 들어가는 듯한 효과 (slot 위치 → 카드 중앙으로 lerp + alpha 페이드).
- 1초 후 `inferno_active && phase == 2`로 전환되면 wedge 사라지고 큰 flash 한 번 (`grow(4.0 * scale_factor)` 적색 ring 0.2초).

state.gd 측은 이 새 `"inferno_charge"` status 문자열을 `_get_inferno_hud_skill()`에 추가해야 한다. 현재 코드는 `inferno_active`이면 모두 `"casting"`을 리턴하는데, `inferno_phase == 1`일 때는 `"inferno_charge"`로 갈라야 한다. (Codex 작업 항목)

## 5. 카드 배치 (placement)

stage4 ponk 배치를 그대로 fork한다:

- 위치: 오른쪽 필러 안쪽, 세로 stack, 수직 중앙 정렬.
- 카드 사이즈는 `BossSkillCardHudSpec.get_card_metrics(pillar_w)` 결과 그대로.
- `card_x = max(1.0, pillar_w - card_w - margin_x)`.
- stage1의 `_resolve_stack_start_y()`의 commando_firearm_panel 회피 분기는 홍련에서 **불필요** (스매셔 커맨더 화기 패널은 홍련 스테이지에서 보이지 않음). 그냥 `start_y = game_offset.y + max(margin_y, floor((game_size.y - total_h) * 0.5))`로 충분.
- 카드 2개일 때와 3개일 때 모두 수직 중앙 정렬 — entry 수에 따라 자동으로 적응됨.

## 6. 색상 토큰 — 한곳에 모음

renderer 상단에 const로 박는 것을 권장:

```gdscript
const FIREBALL_CARD_COLOR := Color(0.95, 0.42, 0.30, 1.0)
const FIREBALL_SIDE_STRIP := Color(0.86, 0.20, 0.18, 0.72)
const INFERNO_CARD_COLOR := Color(1.0, 0.20, 0.20, 1.0)
const INFERNO_SIDE_STRIP := Color(1.0, 0.32, 0.18, 0.86)
const DRAGON_ORB_FILL := Color(1.0, 0.32, 0.20, 1.0)
const DRAGON_ORB_EMPTY := Color(0.45, 0.15, 0.12, 0.45)
const DRAGON_ORB_READY_PULSE_FREQ := 4.5
const INFERNO_CHARGE_WEDGE := Color(1.0, 0.92, 0.40, 0.90)
const INFERNO_CHARGE_PULSE_FREQ := 8.0
const STATUS_READY_BORDER := Color(0.48, 1.0, 0.64, 0.70)
const STATUS_CASTING_BORDER := Color(1.0, 0.84, 0.26, 0.88)
const STATUS_INFERNO_CHARGE_BORDER := Color(1.0, 0.30, 0.20, 0.95)
const STATUS_CHARGING_BORDER := Color(0.28, 0.23, 0.17, 0.70)
const STATUS_LOCKED_BORDER := Color(0.36, 0.34, 0.32, 0.62)
```

state.gd에 박힌 현재 `color` 값들은 spec과 동일하므로 따로 갱신 불필요.

## 7. 자산 요청 (sprite-generation / ui-hud-generation 스킬 또는 imagegen)

이 spec 단독으로 renderer를 fork할 수 있도록 fallback texture 두 개는 이미 마이그레이션된 자산을 재활용하지만, 최종 출고용으로 다음 2개 PNG를 생성한다:

| 파일 | 용도 | 권장 generator |
|---|---|---|
| `godot/assets/sprites/hud/stage5_hongryun_fireball_skillcard_imagegen_v1.png` | 홍련 화염탄 카드 배경 | imagegen (홍련의 손에서 작은 화염탄이 발사되는 wide aspect) |
| `godot/assets/sprites/hud/stage5_hongryun_inferno_skillcard_imagegen_v1.png` | 홍련폭염 카드 배경 | imagegen (휘감기는 적색 뱀 트레일 + 폭발 코어, wide aspect) |

스타일 baseline:
- 카드 비율은 stage1 dalji whip/spinning_top PNG와 동일한 wide aspect.
- 배경은 카드 일러스트만, frame / border / status badge / orb dot은 절대 굽지 않음 (renderer가 다 그림).
- 좌측 약 4~6% 마진은 비워둠 (renderer의 side strip이 덮음).
- 알파 채널은 카드 전체 직사각형으로 완전 불투명.

자산이 도착하기 전이라도 fallback texture로 renderer는 동작한다 — stage4 ponk magnetic_field가 이미 같은 fallback 전략을 쓰고 있음.

## 8. Codex fork 체크리스트 (`stage5_hongryun_boss_skill_hud_renderer.gd`)

1. [stage4_ponk_boss_skill_hud_renderer.gd](../godot/scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd)를 베이스로 복제. `current_stage == 4` → `5`로, `stage4_ponk_*` 키 → `stage5_boss_skill_hud_*`로 일괄 rename.
2. `_get_skill_texture_paths(skill_id)`에 hongryun_fireball / hongryun_inferno 경로 추가 (§3.1 / §3.2 표).
3. `_draw_card()`에서 `entry.get("render_kind", "")`를 읽어 `"dragon_orb_gauge"`이면 dragon orb 5칸 오버레이 함수 호출 (`_draw_dragon_orb_overlay(canvas, rect, gauge, gauge_max, time_seconds, scale_factor)`).
4. `_draw_dragon_orb_overlay()` 신규 구현 — §3.2 sub-section의 슬롯/페인트 규칙 그대로.
5. status 매핑에 `"inferno_charge"` / `"paused"` 추가 — `_draw_card()` border 분기에 §4 표대로 두 줄 추가.
6. `inferno_charge` 분기에서는 추가로 카운트다운 wedge 그리기 (`_draw_inferno_charge_wedge(canvas, rect, charge_progress, scale_factor)`). `charge_progress`는 entry에 새 키 `inferno_charge_progress` (0.0~1.0)로 받는다. (state.gd에서 phase==1일 때 채워 보내야 함 — Codex가 같이 추가.)
7. stage1 dalji renderer의 툴팁 패턴을 가져와 `_draw_skill_tooltip`을 동일 구조로 추가 (§3.1 / §3.2의 라벨/트리거/쿨다운/설명 텍스트 사용). stage4는 툴팁이 없지만, 홍련의 두 카드는 게임 시스템 설명이 필요하므로 stage1 패턴이 더 적절.
8. `prewarm_assets()`에서 `hongryun_fireball`, `hongryun_inferno` 두 texture를 preload.
9. `stage_runtime_router.gd` STAGE_MODULES[5]에 `"boss_skill_hud_renderer": "stage5_hongryun_boss_skill_hud_renderer"` 추가.
10. Catalog / battle resources / draw scene context에 등록 (stage4 패턴 그대로 mirror).
11. 검증: `run_smoke_tests.ps1` + `run_headless_load_check.ps1` + `run_warning_scan.ps1`.

## 9. state.gd 측 후속 변경 (이 spec과 짝지어 같이 land)

renderer fork와 함께 [stage5_hongryun_state.gd](../godot/scripts/stages/stage5/stage5_hongryun_state.gd)에 3가지 변경 필요:

1. `_get_inferno_hud_skill()`에 `"render_kind": "dragon_orb_gauge"` 키 추가.
2. `_get_inferno_hud_skill()` status 분기에 `inferno_phase == 1` → `"inferno_charge"` 추가 (현재는 모두 `"casting"`).
3. `_get_inferno_hud_skill()`에 `"inferno_charge_progress": (inferno_charge_timer / INFERNO_CHARGE_SEC)` 키 추가 (charge phase 동안만 유효).

이 3줄은 코드-문서 정합성 작업이라 Codex 측에서 renderer 만들 때 같이 처리하는 게 자연스럽다.

## 10. QA 시나리오 (renderer 작성 후)

- Stage 5 진입 직후 (round 1, 2.5초 grace): 두 카드 모두 `charging`, dragon orb 0/5, 화염탄 cooldown 채워지는 중.
- 화염탄 첫 발사: 화염탄 카드가 `casting` → `charging`으로 깜빡임. dragon orb는 변화 없음 (피격 시에만 증가).
- 플레이어가 화염탄 5번 맞음: dragon orb가 1→5로 차오르고, 마지막 5번째 충전 시 홍련폭염 카드가 `ready` (초록 펄스).
- Smasher plasma drain으로 4.3 → 4.0 → 3.7 단계 감소: 마지막 슬롯이 부분 채움 → 빈 슬롯으로 단계적으로 줄어든다. `inferno_ready`는 자동으로 `false` (이미 state.gd 동작).
- 보스 패들 충돌로 inferno 발동: 카드가 `inferno_charge`로 전환, 1.4초 카운트다운 wedge가 사라지면서 `casting`으로 → trail 단계.
- 라운드 종료: Godot 포팅 버전에서는 dragon orb가 줄어들지 않고 그대로 보존된다. 5/5라면 `ready` 상태도 유지된다.
- 결과 화면: state.gd `reset_for_result()` → 카드 보이지 않음 (HUD 비활성).
- 다음 게임 Stage 1 진입: 홍련 카드 흔적 없음.
