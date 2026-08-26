# 지시문 X4-수정2 — [P2] 같은 프레임에 스냅샷을 두 번 만들어 폐기 래치가 새어나간다

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/fb8-vision-movement-latch-20260826`(워크트리
  `D:\codex_tmp\bosspong_vision_latch_ea3d`)의 `60ba17525` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **거의 다 왔다.** (b) 채널 분리는 **옳은 구조 선택**이었고
  반려서가 지목한 F1~F6 이 **전부 실질 수리됐다**(아래 무결 목록 — 재작업 금지).
  **아래 한 건만 닫으면 통합한다.**

## ★먼저 읽어라 (새 세션이면 필수)

1. **원 지시문**: `docs/feedback8_vision_modifier_movement_latch_codex_handoff.md`
2. **1차 반려서**: `docs/feedback8_vision_modifier_movement_latch_fix_codex_handoff.md`
   — "M1" "M2" "F1"~"F6" 의 출처다.
3. **직전 구현**: `git -C D:\codex_tmp\bosspong_vision_latch_ea3d -c safe.directory='*' show 60ba17525`
4. 워크트리는 **이미 존재한다. 새로 만들지 마라.**
5. 본 트리 현재 HEAD 는 `3e1ef2998` 이고 **읽기 전용**이다.

---

## [P2] G1 — `_refresh_cached_status_movement_transform` 가 같은 프레임에 두 번 빌드한다

`battle_scene_actor_update_driver.gd:245` 부근.

### 기전 (격리 워크트리 프로브로 재현 확정)

1. `battle_frame_flow_controller.gd:51`/`:113` 이 `update_mythic_items` 를
   **`update_player_control`(`:60`/`:126`)보다 먼저** 돌린다.
2. **뿔딸기 가면**(`mythic_item_horn_strawberry_mask_runtime.gd:414`) 또는
   **오딘의 눈 페널티**(`mythic_item_odins_eye_runtime.gd:374`/`:525`)가 활성이면,
   신화 런타임이 **3인자** `get_vision_aware_input_reader` 로 비전 프레임 캐시를
   **먼저** 만든다 → `transform_snapshot` 없는 raw 리더 →
   `status_movement_transform_applied=false`.
3. 이어서 `update_player_control` 이 그 캐시를 만나
   `_refresh_cached_status_movement_transform` 를 부르고,
   **같은 프레임에 `configure_snapshot` 을 두 번째로 호출한다.**
4. ★**빌드 #1 이 이미 래치된 채널을 drain 했고**, 물리 해제 프레임이라
   `raw_pressed` 가 false 이므로 **`_suppressed_until_release` 를 지워버렸다.**
5. 빌드 #2 는 **빈 래치**를 만나고 exclusive 도 false 라 **아무것도 억제하지 않는다.**

### 실측 (각시탈 비전 장착 · N-1 프레임에 Shift + mouse_right/action/secondary_action 홀드 · N 프레임에 전부 물리 해제)

| 경로 | `combat_input_filtered` | `action_just_released` | `secondary_action_just_pressed` |
|---|---|---|---|
| `DRIVER_ONLY`(대조군) | true | false | false |
| **`MYTHIC_FIRST`** | **false** | **true** | **true** |

`secondary_action_just_pressed` 는 **스매셔 RMB 코드 엣지**로,
`gaksital_vision_input_exclusivity_smoke._verify_release_discard_until_release`
가 **바로 그것이 폐기됨을 증명하려고 존재하는** 채널이다.
**홀드하고 있던 전투 커맨드가 Shift 해제 프레임에 발동한다.**

그리고 `combat_input_filtered=false` 가 되면 `update_player_control` 이
**그 프레임에 프록시를 아예 설치하지 않는다**(`:98~104`).

### 기존 씰이 못 잡는 이유

**모든 릴리스-래치 레그가 프레임당 `configure_snapshot` 을 정확히 한 번만
호출한다.** 두 번 호출하는 경로가 씰에 없다.

### 수리 (택일 · 근거 보고)

- **(a) 두 번째 진입점을 없앤다.** 프레임 캐시 생성 시점에 상태 변환을
  샘플링하도록, 모든 호출자가 **상태 리더를 이미 아는 단일 오너**를 경유하게
  하라. 구조적으로 깨끗하다.
- **(b) 같은 프레임 재구성을 멱등으로 만든다.** 프레임 시작 시 래치 상태를
  스냅샷해 두고, **그 프레임의 첫 `configure` 만** `_suppressed_until_release`
  를 변형·삭제하게 하라. 이후 재빌드는 **같은 `drained_channels` 집합을
  재생**한다.

⚠**어느 쪽이든 씰을 반드시 추가하라**: 한 프레임에 `configure` 를 **두 번**
호출하는(신화-우선 순서) 레그에서 `action_just_released` /
`secondary_action_just_pressed` 가 **폐기 유지**되고
`combat_input_filtered` 가 **true 유지**됨을 단언하라.
**되돌리면 RED 가 되는지 반증**하고 원상복구하라.

## [P3] G2 — 재구성 경로에 `skill_config == null` 폴백이 없다

빌드 경로에는 있는데 `_refresh_cached_status_movement_transform` 에는 없다.
`null` 이 들어오면 blocked 채널이 **빈 dict** 가 되고 레거시 폴백이
**13채널 전부**를 차단한다.

⚠**리뷰 반증 레인 두 곳이 이 지적을 "본 트리에 그 함수가 없다"며 기각했는데,
그것은 본 트리를 본 착오다.** 이 함수는 `60ba17525` 가 새로 만든 것이다.
**본인이 워크트리에서 직접 확인하고 판정하라.** 도달 불가면 그 근거를 대라.

## [P3] G3 — `stage3_curse_control_input_proxy.get_snapshot()` 이 호출당 깊은 복사 2회

물리 경로 할당이 늘었다. 줄일 수 있으면 줄이고, 못 줄이면 근거 주석을 남겨라.

## 확인된 무결 (재작업 금지 · 관제탑이 직접 재현)

- ★**M1 완전 보존.** 16개 부분집합 전수를 실 컨트롤러로 재구성한 결과,
  **청린귀를 포함한 모든 로드아웃**이 `horizontal_input_locked=true`,
  `movement_left_pressed=false`, `movement_direction=0.0`, 패들 `dx=0.0`.
  **채널 분리가 청린귀 차단을 누출시키지 않았다.**
- ★**M2 전 조합 표 검증됨.** 미장착 = 통과(`dx=-10`) / 달지·각시탈·연묘 단독 및
  그들끼리 모든 조합 = 통과(커맨드 레인은 0) / **청린귀 포함 = 전부 차단(`dx=0.0`)**.
- **F1·F2·F3 RED 반증 3종 전부 재현됨**(게이지 500→380, 방향 +1 소실, 500→100).
- **F2 상태 변환이 실 드라이버 양 레그에서 정확하다.** 저주 반전은
  이동 레인이 `+1.0` 으로 **일치**하고 커맨드 레인은 0 유지. 기절도 정상.
  raw 리더는 여전히 **프레임당 1회** 샘플링.
- **F5 라이프사이클 분리 정확.** `reset_ball` 은 더 이상 지우지 않고
  `match_round_restart_controller.gd:11` 이 신규 콜백으로 지운다.
  레지스트리가 배틀 씬 소유라 래치가 배틀을 넘지 않는다.
- **F6 비대칭 제거 확인.** 달지 단독 + A+D+W 홀드에서 자폭드론 `(0.0, 0.0)`,
  잔류 그물 `0`.
- ★**`movement_*` 레인이 과다 소비되지 않는다.** 저장소 전체에서 프로덕션
  소비자는 `smasher_player_controller.gd:97~109` **하나뿐**이고, 하류 사용처가
  전부 이동 경로다(드라이브 버퍼는 비독점 분기, 휠, 대시, `movement_state`).
  **커맨드 소비자는 새 레인을 읽지 않는다.**
- ★**옵티머스 수동 충전 이동 잠금이 무력화되지 않았다.**
  `optimus_config['horizontal_input_locked']=true` 가
  `smasher_player_controller.gd:110~113` 에서 이동 레인 값에도 적용된다.
- **GRT-050 면제 채널 불변.** `action_pressed`/`mouse_right_pressed`/
  `secondary_action_pressed` 는 폐기 의미론 유지, 기존 RED 픽스처 2종도 정상 RED.
- **테스트 전용 탈출구가 안전 기본값.** 프로덕션은
  `constants['vision_exclusive_guard_enabled']` 를 쓰지 않고 기본이 true.
- ✔**세션의 주변 RED 귀속 판정이 둘 다 옳다.**
  Viper RED = 격리 워크트리 임포트 캐시가 10/8049 뿐이라 나는 **환경 아티팩트**
  (같은 씰이 본 트리에선 GREEN). Horn RED = 커밋을 포함하지 않는 본 트리
  `3e1ef2998` 에서 **바이트 동일한 단일 실패**로 재현되는 **선재 결함**.
  **회귀 아니다.**
- **스코프 위반 0.** 13파일 전부 F1~F6 로 추적되고 드라이버 +78줄에 이물질 없음.
- **씰은 약화가 아니라 강화**(`_expect` 82→87, 143→146, 43→64).
- **CI/pre-push 244/244 `exact_sequence=true`.**

## 반증된 지적 (대응 불필요)

- 바이퍼 blade-motion 이 `movement_*` 로 안 옮겨졌다 — 관측 가능한 실패 0
- 이동측 전수 씰 부재 — 도달 불가
- 오딘의 눈 잔상 `movement_intent` — 전제가 성립 안 함
- F2 변환이 볼·패들접촉 경로에 실린다 — "무단 게임플레이 변경" 프레이밍 반증

## ★통합 충돌 (관제탑 실측)

| 조합 | 결과 |
|---|---|
| X4-수정 × 현재 HEAD `3e1ef2998` | **무충돌** (트리 `7049a4ac5`) |
| X4-수정 × X1-수정 `031d59beb` | **무충돌** (트리 `fb7bbd244`) |
| X4-수정 × X2 `c425881d3` | **무충돌** (트리 `2dc9c92ce`) |
| **X4-수정 × X5-수정 `779fa0d2d`** | **CONFLICT** — 두 CI 파일 모두 |

3-way 스테이지 엔트리:
`.github/workflows/godot-ci.yml`(base `0c880eb3e` / X4 `ddaad0913` / X5 `9a92b383b`),
`godot/tools/run_pre_push_checks.ps1`(base `623591727` / X4 `f82005ca9` / X5 `be225ca49`).

원인은 **같은 꼬리 지점 동시 추가**다 —
X4 = `res://tests/vision_modifier_movement_latch_smoke.gd`,
X5 = `res://tests/yangui_hoechun_wave_contract_smoke.gd`.

**통합은 관제탑이 한다. 이 워크트리에서 X5 를 병합하려 하지 마라.**
⚠**X5-수정이 먼저 착지할 예정이다.** 그래서 통합 시 X4 의 꼬리 삽입이
X5 항목 뒤로 밀린다 — 관제탑이 처리하니 신경 쓰지 마라.

## 게이트·보고

포커스드 스모크(+G1 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check`.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · **G1 을 (a)로 갔는지 (b)로 갔는지와 근거** ·
**신화-우선 순서 레그의 종단선과 RED 반증 출력** · G2 판정 · 미해결.
