# 지시문 X4-수정 — [P1] 좌우를 통과시키자 비이동 커맨드 3건이 되살아났다

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/fb8-vision-movement-latch-20260826`(워크트리
  `D:\codex_tmp\bosspong_vision_latch_ea3d`)의 `1a3c6528a` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT.** M1·M2·M3 핵심 계약은 **정확하고 씰도 튼튼하다**
  (아래 무결 목록). 문제는 범위 초과가 아니라 **범위 미달**이다 —
  좌우를 통과시키면서, 기존 "블랭킷 좌우 차단"이 구조적으로 막아주던
  **비이동 소비자를 전수로 찾지 못했다.** 셋 다 격리 워크트리 런타임 프로브로
  A/B 확정했다.
- ⚠커밋이 스스로 선언한 불변식
  (`vision_modifier_input_proxy.gd:123~124`
  "derived combat directions must stay owned by the Vision layer")이
  **열거하지 못한 세 곳에서 깨진다.** 전부 이 커밋이 만든 회귀다
  (이전에는 좌우가 0이라 죽은 코드였다).

## ★먼저 읽어라 (새 세션이면 필수)

이 문서는 **반려 사유서**다. 원 요구사항은 여기 없다.

1. **원 지시문**: `docs/feedback8_vision_modifier_movement_latch_codex_handoff.md`
   — 아래에서 "M1" "M2" "M3" "지시문 (3)(4)" "씰 요구 11번" 으로 참조하는
   항목의 원문이다.
2. **직전 구현**: `git -C D:\codex_tmp\bosspong_vision_latch_ea3d -c safe.directory='*' show 1a3c6528a`
3. 그 워크트리는 **이미 존재한다. 새로 만들지 마라.** 없으면 관제탑에 보고하라.
4. 기준선은 `ea3d864bb`, 본 트리 현재 HEAD 는 `d5a7404db` 다.
   본 트리는 **읽기 전용**이다.

---

## [P1] F1 — 바이퍼 화랑킥이 Shift 홀드 중 발동한다

`viper_skill_core_flip_runtime.gd:17` `try_ready_activation`의 **첫 절**이
필터된 스냅샷을 읽는 **순수 레벨 판정** `left_pressed AND right_pressed`다.
커밋은 `viper_skill_command_tracker.gd:14~25`에서 **엣지/프레임-나이 경로만**
막았고, 이 레벨 절은 좌우 통과와 함께 되살아난다.

**재현**: 바이퍼 + 달지/각시탈/연묘 중 하나 장착(청린귀 아님) +
화랑킥 준비창(700ms, `viper_skill_contact_runtime.gd:14` 또는
`viper_skill_shadow_step_runtime.gd:72`가 연다) + Shift 홀드 + A·D 동시 →
**화랑킥 발동 + 기력 120 소모.**

런타임 A/B 확정: 동일 픽스처에서 `dalji_only` → `core_flip_attack_active=true`,
`cheongringwi_only` → `attack_active=false`.

**수리**: `try_ready_activation` 진입부에
`if bool(input_snapshot.get("vision_input_exclusive", false)): return {}`를
넣거나, 레벨 절을 커맨드 트래커가 소유하는 결과 dict 경유로 옮겨라.
⚠현재 gaksital 씰의 바이퍼 커버리지는 wall-leap RMB 하나뿐이다(`:535`).

## [P1] F2 — 조작 반전 저주가 Shift 홀드 중 무효화된다

**Shift가 저주 해제 버튼이 된다.**

`battle_scene_actor_update_driver.gd:90~92`가 `deps["input_reader"]`를 비전
프록시로 덮어쓰는데, 그 프록시는 `_get_character_input_reader`(`:288~292`)로
얻은 **raw 레지스트리 리더**를 감싼다. 그래서
`battle_update_player_control_deps_builder.gd:57`이 쌓아 둔
`stage3_curse_control_input_proxy`(`_reverse_horizontal_input`, `:92~101`)를
**통째로 건너뛴다.**

커밋 이전에는 좌우가 0이라 무해했다. **지금은 실효 결함이다.**

런타임 확정: raw `dir=-1` → 저주 프록시 출력 `+1` → 컨트롤러 수신값
`dalji_only=-1`(반전 소실), `cheongringwi_only=0`(차단 유지).

**수리**: 비전 프록시가 통과시키는 이동 채널에 상태/저주 변환을 **다시
태워라** — 프록시를 raw 대신 `status_input_reader` 위에 쌓거나, 드라이버가
리더를 교체할 때 `left`/`right`/`direction`에만 반전을 재적용하라.

**씰**: reverse 상태 + 달지 단독 + Shift 홀드에서 `direction` 부호가 저주
프록시와 **일치**함을 단언.

## [P2] F3 — 뿔딸기 폭탄이 Shift 홀드 중 발동한다

`horn_strawberry_bomb_state.gd:92`. 커밋은 `horn_strawberry_command_listener.gd`
**에만** `vision_input_exclusive` 가드를 넣었고, **같은 필터 스냅샷을 받는**
`bomb_state`(`mythic_item_horn_strawberry_mask_runtime.gd:306`)를 놓쳤다.
함께 넘어가는 `blocked` 인자 `_is_skill_action_blocked`(`:363~373`)는
비전 인지가 없다.

**재현**: 뿔딸기 가면 + 변신 + 비전초식(청린귀 제외) + Shift 홀드 중
A·D 0.5초 유지 → **폭탄 투척 + 기력 400 소모.**
런타임 확정: `fired=true`, `throwing=true`, 기력 900→500.

**수리**: `update_input` 진입부에 가드를 넣고 **`holding`/`hold_timer_sec`를
리셋**해 홀드 누적이 넘어가지 않게 하라(magnum grip 가드와 동일 패턴).

## [P2] F4 — ★구조적 원인: 소비자 전수 씰이 없다

F1·F3이 **같은 원인의 두 증상**이다.

이 커밋은 "스냅샷 단위 보장"(좌우가 0이면 어떤 소비자도 못 읽는다)을
**"소비자별 수동 마커 가드"** 로 바꿨다. 그런데 **소비자 집합을 전수 검사하는
단언이 하나도 없다.** 손으로 5개를 찾아 가드를 붙였고, 최소 3개를 빠뜨렸다.

**수리**: 다음 중 하나를 반드시 세워라.

- **(a) 소스 전수 씰**: `left_pressed`/`right_pressed`/`direction`을 읽는
  프로덕션 소비자를 열거하고, 각각이 `vision_input_exclusive`를 인지하거나
  **명시적 면제 목록**에 등재돼 있음을 단언. 새 소비자가 생기면 RED.
- **(b) 스냅샷 레벨 복원**: 이동 채널을 통과시키되 **비이동 소비자에게는
  여전히 0을 주는** 별도 채널을 만든다. 즉 "이동용 스냅샷"과 "커맨드용
  스냅샷"을 분리해 스냅샷 단위 보장을 되찾는다.

**(b)가 구조적으로 안전하다.** (a)는 다음 소비자가 추가될 때 또 빠진다.
어느 쪽을 택하든 **근거를 보고하라.**

## [P3] F5 — `reset_ball`이 매 득점마다 폐기 래치를 지운다

`battle_scene_ball_update_driver.gd:10~12`의 신규 3줄이 owner/controller null
조기반환보다 **위**에 있어 무조건 실행된다.

지시문 11번은 **라운드 재시작** 시 이월 방지를 요구했는데, 구현은
`reset_ball` 전 경로(**득점·서브 리셋 포함**)에서 `_suppressed_until_release`를
비운다.

액션/RMB를 누른 채 득점이 나고 바로 다음 프레임에 Shift를 떼면, 그 프레임에는
`blocked_while_exclusive`도 false이고 래치도 비어 있어 **눌려 있던 엣지가 한
프레임 샌다**(노출창 약 1/60초).

**수리**: `reset_vision_input_state()`를 라운드 재시작 경로에 한정하거나,
`reset()`이 `_suppressed_until_release`는 **유지**하고 프레임 캐시만
무효화하도록 분리하라.

⚠계층 지적도 함께: 비전 입력 상태 리셋은 액터-드라이버 관심사인데 볼
드라이버의 `reset_ball()` 안에 있다. 라운드 리셋 라이프사이클 훅이 소유하는
편이 맞다. 지금 구조는 "공을 리셋하는 모든 경로 = 비전 래치를 지워야 하는
모든 경로"라는 **암묵 가정**에 의존한다.

## [P3] F6 — 코만도 조향이 홀드 중 수평만 부분 해제된다

`commando_firearm_input_resolver.gd:7`. 청린귀 미장착 로드아웃에서 Shift 홀드
중 `get_suicide_drone_input_vector`가 **좌우는 받고 상하는 못 받는다**
(up/down이 COMMON 차단). `commando_firearm_lingering_net_field_state.gd:291~292`
도 동일.

오발동은 아니지만 **조향이 비대칭**이 되어 체감이 어긋난다.
**의도라면 주석/문서로 고정**하고, 아니면 두 소비자에도 가드를 넣어라.
어느 쪽이든 기록을 남겨라.

## 확인된 무결 (재작업 금지 · 관제탑이 직접 재현)

- **M1 보존 확정.** `vision_input_exclusive_policy.gd:28`이 청린귀에만
  `left_pressed`/`right_pressed`를 얹고 `:58~66`이 장착분을 합집합한다.
  청린귀 단독 홀드 중 `left_pressed=false` / `direction=0.0`,
  실 드라이버 경유 게이트 B `horizontal_input_locked=true`.
  **과잉 제거가 필요한 차단까지 지우지 않았다.**
- **M2 합집합 확정.** 전 조합 표가 도출된다 —
  미장착=통과 / 달지·각시탈·연묘 단독 및 그들끼리 모든 조합=통과 /
  **청린귀 포함 모든 조합=차단.**
- **M3 래치 예외 범위 확정.** `MOVEMENT_LATCH_EXEMPT_CHANNELS`가 정확히
  `{left_pressed, right_pressed}` 뿐이고, `action_pressed` /
  `mouse_right_pressed` / `secondary_action_pressed`는 **GRT-050 폐기 의미론을
  그대로 유지**한다. 엣지까지 풀린 흔적 없음.
- `_verify_release_discard_until_release`는 +28줄 드리프트로 `:723~744`로
  이동했고 **GREEN**이다.
- `COMMON_BLOCKED_HOLD_CHANNELS`(11) + 청린귀 extra(2) = `HOLD_CHANNELS`(13)의
  **정확한 여집합**. 조용히 누락된 채널 없음.
- **게이트 C를 손대지 않은 것이 옳다.** `is_movement_locked()`는 달지 시전
  애니메이션 중 동결이며 Shift 홀드와 무관하다.
- **씰 개정 2건 정상.** `power_smash_direction`/`blacksmith_swing_direction`의
  0 유지 단언이 살아 있다.
- **스코프 위반 없음.** 17파일 전부 비전 입력 계층의 폭발 반경 안이고,
  커맨드 버퍼 5파일 확장도 좌우 통과의 직접 귀결이라 필요했다.
- ✔**기저 RED 주장이 맞다.** 지정 기준선 `ea3d864bb`의 gaksital 실패 집합은
  변경 전후 모두 **빈 집합**이었다. 지시문이 기록한 2 RED는 본 트리 더티
  상태(미커밋 `smasher_overdrive_state.gd`)에만 있었다. **세션 판단이 옳다.**
- ✔`dalji_vision_chosik_smoke`를 pre-push에 넣지 않은 판단도 검증 통과.

## 반증된 지적 (대응 불필요)

- `blocks_horizontal_movement` 프레임당 재구축 — 핫패스 할당 규칙 위반 아님
- `configure()` 죽은 코드 — 프로덕션 도달 불가, 무해
- `CORE_FLIP_INPUT_FRAME_UNSET` 센티널 3중 — 원리적으로 갈라질 수 없음
- `quake_loop=continuous` 문구 — 실행으로 잡힌다

## ★통합 충돌 (관제탑 실측)

| 조합 | 결과 |
|---|---|
| X4 × 현재 HEAD `8f0d884b7` | **무충돌** (트리 `c4b29ac10`) |
| X4 × X1 `8ce16ec88` | **무충돌** (트리 `0ee2075ca`) |
| **X4 × X5 `8ca2f73aa`** | **CONFLICT** — 두 CI 파일 모두 |

X4와 X5가 **같은 꼬리 지점**에 각각 한 줄을 붙인다.

- `.github/workflows/godot-ci.yml` — `@@ -288,6 +288,7 @@`,
  `res://tests/gaksital_vision_input_exclusivity_smoke.gd`(`:290`) 바로 뒤
- `godot/tools/run_pre_push_checks.ps1` — `@@ -291,7 +291,8 @@`,
  배열 마지막 원소에 **쉼표를 붙이는 mutation 동반**
  (`$focusedSmoke`는 trailing comma 없는 PowerShell 배열이다)

**통합은 관제탑이 한다. 이 워크트리에서 X5를 병합하려 하지 마라.**

## 씰 요구

1. **F1·F2·F3 각각 신규 레그** + **RED 반증**(가드를 되돌리면 발동/반전 소실이
   재현되는지) 후 원상복구.
2. **★F4 전수 씰(필수)** — 위 (a) 또는 (b). 이것이 없으면 같은 결함이 다음
   소비자에서 또 난다.
3. **F5 레그**: 득점 리셋에서는 래치가 유지되고 라운드 재시작에서만 지워지는지.
4. 기존 씰 GREEN 유지: `vision_modifier_movement_latch_smoke`,
   `gaksital_vision_input_exclusivity_smoke`, `dalji_vision_chosik_smoke`.
5. **CI/pre-push 락스텝** 정렬 후 diff 대조.

## 게이트·보고

포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check`.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · **F4를 (a)로 갔는지 (b)로 갔는지와 근거** ·
씰 종단선 **원문** · F1·F2·F3 RED 반증 실제 출력 · F6 판단 · 미해결.
