# 지시문 X4 — [P1] Shift(비전 모디파이어) 홀드가 좌우 이동을 과하게 죽인다

- **발행**: 관제탑 2026-08-26. 대상: 본 트리 `d:\main\bosspong` HEAD `ea3d864bb`
  기준 **격리 워크트리 + 격리 브랜치**. 본 트리 편집·통합·푸시 금지.
- **병행 가능**: W1·W3·W5 및 샘터 지시문(X1~X3)과 **파일이 겹치지 않는다.**
  선행 조건 없이 바로 착수하라.

---

## 관측

> 초식 커맨드를 쓰려고 **a키나 d키로 이동 중에 Shift를 누르면**, 기존 키
> 차단 기능 때문에 이동 중인 무빙이 **끊겨버려서** 이동이 불편해진다.

## 실측 결과 — 증상이 두 겹이다

`Shift` = `vision_modifier`(`godot/project.godot:49`, keycode 4194325 = KEY_SHIFT).
Shift에 걸린 액션은 **이것 하나뿐**이고, `KEY_SHIFT` 직접 폴링은 0건이다.

차단은 **비전초식(Vision Chosik) 입력 독점 계층**이며
`vision_input_exclusive_policy.gd:16~17`의
`modifier_pressed AND has_equipped_vision(skill_config)`로 게이트된다.
**비전초식 미장착이면 Shift는 아무것도 막지 않는다.**

### 게이트 3중 (셋이 서로 독립이다)

| # | 지점 | 하는 일 |
|---|---|---|
| A | `vision_modifier_input_proxy.gd:82`·`:92` | `HOLD_CHANNELS`에 `left_pressed`/`right_pressed` 포함(`:3~17`). 필터 사본에서 `false`/`direction=0.0`으로 덮어씀 |
| B | `battle_scene_actor_update_driver.gd:97~98` → `smasher_player_controller.gd:98~101` | `horizontal_input_locked=true` → 컨트롤러가 **다시** 0으로 덮어씀 |
| C | `battle_scene_actor_update_driver.gd:115~117` | `is_movement_locked()`이면 `player_pos` 하드 동결. **달지만 해당**(`dalji_vision_chosik_state.gd:247~248`) |

원본은 정상적으로 읽고 **사본에서 덮어써서 컨트롤러에 전달한다** — 즉
"읽되 버려진다"가 정답이다. 커맨드 인식은 살아 있다
(`driver:68`이 비전 상태들에게는 **raw 스냅샷**을 준다).

### ★M1 — 홀드 중 정지는 사용자 확정 계약이다 (반증 완료 · 번복하지 마라)

- `docs/feedback5_gaksital_fan_vision_fix2_codex_handoff.md:12~14` —
  "비전초식을 하나라도 장착한 상태에서 `vision_modifier`(Shift)를 홀드하는
  동안, 비전 입력 계층이 전투 입력을 독점한다"
- 같은 문서 `:21` — 차단 범위에 **"방향/이동, 공격, 대시"** 명시
- `docs/feedback5_gaksital_fan_vision_fix_codex_handoff.md:24` —
  "vision_modifier 홀드 중 **수평 입력 잠금 계약은 그대로 유지**"
- 씰: `gaksital_vision_input_exclusivity_smoke.gd:820`이 `left_pressed`/`right_pressed`
  차단을, `:828`이 `direction == 0.0`을 단언

근거는 **청린귀 비전이 `Shift + A → D → A`**(`common_skill_catalog.gd:161`)로
이동키 자체를 커맨드로 소비하기 때문이다
(`cheongringwi_vision_chosik_state.gd:123~128`이 좌우 엣지를 직접 읽는다).
계기는 각시탈 부채가 인덱스 순서 때문에 청린귀 커맨드 중간 Right에서 기생
발동해 기력을 잠식한 **실사고**다(`fix_codex_handoff.md:10~18`).

**★이 계약 자체는 유지한다.**

### ★M3 — 진짜 원인: 릴리스 래치가 이동 채널까지 잡아둔다

**Shift를 떼도 a/d는 물리적으로 뗄 때까지 계속 죽어 있다.**
이게 사용자가 느끼는 "끊김"의 지배적 원인이다.

`vision_modifier_input_proxy.gd:69~87` 추적:

1. Shift 홀드 + a 홀드 → `:69~70` `_suppressed_until_release["left_pressed"] = true` 래치 장전
2. Shift 해제, a는 여전히 홀드 → `:71~77` `must_suppress`가 래치 때문에 여전히
   true → `:82` `left_pressed = false` **유지**
3. `:86~87` 래치 소거는 **`raw_pressed == false`일 때만** → a를 물리적으로 뗄
   때까지 영구 억제

⚠**GRT-019(엣지 먹힘)가 아니다.** 이동은 엣지가 아니라 pressed(레벨)로
판정한다. **레벨 신호를 물리 해제까지 강제 false로 잡아두는 래치**다.

이 래치의 설계 근거는 **GRT-050**(막힌 게이트는 입력을 버리지 않고 미룬다)
대응이었다(`fix2:36~38`). **그러나 그 논거는 "눌려 있던 버튼이 뒤늦게
`just_pressed`로 새면 안 된다"는 엣지 트리거 스킬 오발동에 관한 것이며,
순수 레벨 신호인 좌우 이동을 물리 해제까지 잡아두는 것은 문서에 별도 근거가
없다.**

### ★M2 — 차단 범위가 과잉이다

비전 4종 중 **이동키를 쓰는 것은 청린귀 하나뿐**이다.

| 초식 | 커맨드 | 좌우 충돌 |
|---|---|---|
| 달지 | `Shift + W` (`:37`) | 없음 |
| 각시탈 | `Shift + 우클릭` (`:102`) | 없음 |
| 청린귀 | `Shift + A → D → A` (`:161`) | **있음** |
| 연묘 | `Shift + S` (`:221`) | 없음 |

그런데 차단은 장착 스킬 종류와 무관하게 **전역**이다.
**달지/각시탈/연묘만 장착한 플레이어도 A/D가 죽는다.**
설계 문서에 근거가 없는 과잉 적용이다.

## 사용자 확정 사양

> **M3와 M2를 둘 다 고친다.**
> - Shift를 뗀 순간 **눌려 있는 a/d로 이동이 즉시 복구**된다.
> - 차단은 **실제로 이동키를 커맨드 재료로 쓰는 비전초식(청린귀)에만** 적용한다.
>   달지·각시탈·연묘만 장착하면 A/D가 아예 안 막힌다.
> - **M1(청린귀 장착 시 홀드 중 정지)은 유지한다.** 8/25 확정 계약 번복 아님.

## 수리 방향

### (1) M3 — 래치 예외 [작다, 씰 무개정]

`vision_modifier_input_proxy.gd`에
`MOVEMENT_LATCH_EXEMPT_CHANNELS = {left_pressed, right_pressed}`를 두고
`:69`의 arm 조건에 예외를 더하라. **약 4~6줄.**

홀드 중 차단은 그대로라 `_verify_all_combat_channels_blocked`와
`dalji_vision_chosik_smoke:278~281` **둘 다 GREEN 유지** = 씰 무개정.
사용자 확정 계약도 위반하지 않는다(계약은 폐기 의미론만 요구한다).

⚠**엣지 트리거 채널의 래치는 절대 건드리지 마라.**
`action_pressed` / `mouse_right_pressed` / `secondary_action_pressed`는
GRT-050 폐기 의미론을 그대로 유지해야 한다.

### (2) M2 — 채널셋을 장착 초식에서 파생 [배선]

`VisionInputExclusivePolicy`에 **skill_id → 차단채널 맵**(약 25줄)을 만들고
프록시에 채널셋 인자를 흘려라(약 20줄) + `actor driver` 배선(약 6줄).

```
dalji        → { up_pressed, ... }        (좌우 제외)
gaksital     → { mouse_right_pressed, ... } (좌우 제외)
cheongringwi → { left_pressed, right_pressed, ... }  ← 유일하게 좌우 포함
yeonmyo      → { down_pressed, ... }      (좌우 제외)
```

여러 개 장착 시 **합집합**이다. 청린귀를 하나라도 끼면 좌우가 막힌다.

⚠**게이트 B도 같이 파생시켜라.** `driver:97~98`의 `horizontal_input_locked`가
게이트 A와 **독립된 두 번째 차단**이다. A만 고치고 B를 놔두면 증상이 그대로다.

### (3) ★파생 채널 조용한 부활 — 반드시 막아라

`vision_modifier_input_proxy.gd:93~94`가
`_exclusive_horizontal_direction(filtered)`로 **필터된** 스냅샷을 읽는다.
좌우를 통과시키면 **`power_smash_direction`과 `blacksmith_swing_direction`이
경고 없이 되살아난다.**
**명시적 0 대입을 넣어라.** 누락하면 스매셔/블랙스미스 방향 커맨드가
홀드 중 발동한다.

### (4) ★드라이브 버퍼 누출 — GRT-050 변종

좌우를 통과시키면 청린귀 `←→←` 커맨드가
`smasher_drive_input_buffer_state`의 `press_frame`을 시딩한다(MAX_AGE 16프레임).
홀드 중에는 `action_pressed`가 여전히 차단이라 발동하지 않지만,
**Shift 해제 직후 4프레임 내 액션키 입력 시 커맨드용 방향 입력이
파워스매싱으로 오발동**할 수 있다.
**막힌 게이트가 입력을 버리지 않고 미룬 전형이다. 가드를 넣어라.**

### (5) 라운드 리셋 경로 [함께 검토]

`_suppressed_until_release`는 `set_discard_latch_enabled_for_test` 외에
**clear 경로가 없다.** 방향키를 누른 채 라운드가 재시작되면 래치가 그대로
넘어간다. M3 착지 시 함께 처리하라.

## 반증 완료 (재조사 금지)

- ✔**(e) 모디파이어 재바인딩은 이 버그에 효과 0.** Shift는 이동키와 물리적으로
  겹치지 않고 Godot `exact_match=false` 기본값이라 `ui_left`도 죽이지 않는다.
  차단은 전적으로 `VisionInputExclusivePolicy.is_active` **정책**이므로 어떤
  키로 바꿔도 동일하게 막힌다. 비용만 발생한다
  (`project.godot` + gaksital 씰 `:313~321` KEY_SHIFT 단언 +
  `common_skill_catalog.gd`의 'Shift' 하드코딩 **28건** = 7언어 × 4스킬).
- ✔**(d) 입력 채널 분리는 이미 구현돼 있다.** `driver:68`이 초식에 raw를,
  `:92`가 컨트롤러에 필터를 준다. 남은 델타는 정책뿐이다.
- ✔**GRT-019 신규 유발 없음.** 3중 방어가 있다 —
  `smasher_input_reader.gd:20~22` 프레임 멱등 캐시,
  `driver:136~143` (frame, owner) 프레임 캐시, 프록시의 저장된
  `_filtered_snapshot` 반환.
  ⚠**단 어떤 신규 소비자도 `prepare_vision_input_frame`을 경유해야 한다.**
  독립 폴링을 하면 즉시 GRT-019 재발이다.
- ✔vision 관련 파일 5종 전부 **CLEAN(커밋됨)**. 착지 커밋은
  `94b7b29ad` → `9e316ed5c` → `ac027d505`.

## ★기저 RED 귀속 (혼동 금지)

`gaksital_vision_input_exclusivity_smoke.gd`는 **HEAD `ea3d864bb`에서 이미
RED 2건**이다(`:739`, `:771`).

**원인은 미커밋 `godot/scripts/characters/smasher_overdrive_state.gd`**
(벽력유성 "홀드 무장" 재설계 WIP, +598/−56)가
`result["activated"] = true`를 제거한 것이다. 실패 레그 둘 다
`SmasherOverdriveState` **발동 양성 레그**이고,
**차단 레그(음성 레그)는 하나도 실패하지 않았다.**

⚠**착지 후 "씰이 RED다"를 이 WIP 탓과 혼동하지 마라.
실패 집합이 정확히 이 2건으로 유지되는지(늘지 않는지) 바이트 대조하라.**

## 씰 요구

1. **M3 신규 레그**: exclusive 홀드(`left_pressed=true`) → 해제 프레임
   (exclusive=false, left 여전히 true)에서
   `get_snapshot()["left_pressed"] == true` 및 `direction != 0` 단언.
2. **M3 무회귀 레그**: 같은 해제 프레임에서 `action_pressed` /
   `mouse_right_pressed` / `secondary_action_pressed`는 **여전히 억제**
   (GRT-050 폐기 의미론 유지). 기존 `_verify_release_discard_until_release`
   (`:718~739`)가 그대로 GREEN이어야 한다.
3. **M3 RED 반증**: 이동 채널 래치 예외를 비운 픽스처 env
   (기존 `DISCARD_LATCH_FIXTURE_ENV` 패턴 `:29` 재사용) →
   해제 프레임 `left_pressed == false` 관측 → RED 확인 → **원상복구**.
4. **M3 경계 레그**: 좌우만 눌린 채 해제한 프레임에서
   `should_filter_current_snapshot()`이 false가 되어 `driver:90~96`의
   `deps["dash_input_reader"]` 덮어쓰기가 일어나지 않는 경로를 관통 확인
   (대시 리더 분기가 raw로 되돌아가는 것이 의도대로인지).
5. **M2 씰 개정 2건 (필수)**
   - `gaksital_vision_input_exclusivity_smoke.gd:818~830` —
     `left_pressed`/`right_pressed`/`direction` 단언을 **삭제가 아니라
     '각시탈 단독 장착 시 홀드 중 통과'로 반전 개정**.
     ⚠`power_smash_direction` / `blacksmith_swing_direction`의 **0 유지 단언은
     반드시 남겨라.**
   - `dalji_vision_chosik_smoke.gd:278~281` — 동일 개정.
     ⚠**이 파일은 pre-push 목록에 없고 nightly 전수 레인에만 있다**
     (gaksital 2종만 등재). **focused CI GREEN을 근거로 착지하지 마라.**
6. **M2 신규 레그**: 청린귀 **단독** 장착 시 홀드 중 좌우가 **여전히 차단**됨을
   단언(과잉 제거가 필요한 차단까지 지우지 않았음을 증명).
7. **M2 합집합 레그**: 청린귀 + 달지 동시 장착 시 좌우가 차단됨을 단언.
8. **파생 채널 씰 (필수)**: 좌우 통과 상태에서 `power_smash_direction` /
   `blacksmith_swing_direction`이 **여전히 0**임을 단언.
9. **드라이브 버퍼 누출 씰 (필수)**: 홀드 중 `←→←` 입력 후 해제 직후 4프레임
   내 액션키 입력 시나리오에서 `SmasherDriveInputBufferState.consume_direction()`이
   **0을 반환**함을 단언. **가드를 제거한 RED 반증 동반.**
10. **쿨다운·루프오디오 소유권 레그**: Shift 홀드 전 구간에서 네 초식의
    `cooldown_remaining`이 계속 감소하고 청린귀 `sync_quake_loop` 유지가
    끊기지 않음을 단언.
    ⚠**GRT-016/GRT-034**: 비전 루프를 게이트로 감싸는 구현을 RED로 잡는 레그다.
    **비전 루프 자체는 절대 게이트로 감싸지 마라.**
11. **라운드 리셋 레그**: 방향키를 누른 채 라운드 재시작 시 래치가 넘어가지
    않음을 단언.
12. **CI/pre-push 락스텝**: 신규 스모크를 `godot-ci.yml`과
    `run_pre_push_checks.ps1` **양쪽 동시 등재**(현재 243/243).
    ⚠`dalji_vision_chosik_smoke.gd`를 pre-push에 **등재할지 판단해 보고하라.**
    지금 nightly 전용이라 이 계열 회귀를 pre-push가 못 잡는다.

## 함께 보고할 것 (수리 범위 밖 · 별건 후보)

- **게임패드로는 비전초식을 아예 발동할 수 없다.** `vision_modifier`에
  조이패드 이벤트가 **0개**다(`project.godot:49~53`).
  대조군 `guardian_toggle`은 `:46`에 R3(button_index 8)를 갖고 있으므로
  **바인딩 누락이지 기술적 제약이 아니다.** `gamepad_input.gd`에도 대응
  함수가 없고, 플레이어 문구도 7개 국어 전부 키보드 전용이다.
  ⚠단 스틱 좌우는 `smasher_input_reader.gd:23~24`에서
  `GamepadInput.is_left_pressed()`로 같은 `left_pressed` 채널에 합류하므로,
  **키보드 Shift + 패드 스틱 혼용 시에는 스틱 이동도 똑같이 차단된다.**
  이번 수리가 그 혼용 케이스도 함께 고치는지 확인해 보고하라.

## 게이트·보고

포커스드 스모크(+RED 반증 2건) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
**라이브 체감 확인(청린귀 장착 / 미장착 각 1판)**.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라.**
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 커밋 해시 · 씰 종단선 **원문** · RED 반증 2건 실제 출력 ·
**착지 전후 `gaksital_vision_input_exclusivity_smoke` 실패 집합 바이트 대조** ·
`dalji_vision_chosik_smoke` pre-push 등재 판단 · 게임패드 혼용 케이스 처리 ·
미해결.
