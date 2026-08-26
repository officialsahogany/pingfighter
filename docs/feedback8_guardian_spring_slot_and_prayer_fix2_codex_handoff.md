# 지시문 X1-수정2 — [P2] 교체창이 여전히 매 프레임 두 번 그려지고, 살아남은 쪽엔 암막이 없다

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/feedback8-guardian-spring-slot-prayer-20260826`(워크트리
  `D:\codex_tmp\bosspong_feedback8_guardian_x1_0bd1`)의 `031d59beb` 위
  **추가 커밋**. amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: ★**P0 는 완전히 풀렸다.** 관제탑이 **두 레그 모두 독립 재현**했다 —
  팜 커밋 후 같은 `node_id` 에서 `build_actions` 가 **블라인드 첫 픽 카드 정확히
  3장**을 돌려준다(열린 슬롯 · 만석 교체 확정 둘 다).
  씰 3개도 **문구가 아니라 의미가 복구됐다**(`and not visit_action_committed` 를
  되돌려 넣으니 정확히 그 세 파일에서 `FAIL=3`).
  **아래만 닫으면 통합한다.**

## ★먼저 읽어라 (새 세션이면 필수)

1. **원 지시문**: `docs/feedback8_guardian_spring_slot_and_prayer_codex_handoff.md`
2. **1차 반려서**: `docs/feedback8_guardian_spring_slot_and_prayer_fix_codex_handoff.md`
   — "F1"~"F10" 의 출처다.
3. **직전 구현**: `git -C D:\codex_tmp\bosspong_feedback8_guardian_x1_0bd1 -c safe.directory='*' show 031d59beb`
4. 워크트리는 **이미 존재한다. 새로 만들지 마라.**

---

## [P2] H1 — F4 가 반쪽만 처리됐다

커밋은 standalone 호스트의 **암막 `draw_rect` 한 줄만** 지웠다.
**선재 HUD 경로는 여전히 매 프레임 전체를 실행한다.**

### 기전 (관제탑 직접 재현 · 임시 프로브)

만석 팜 커밋 후 `has_pending_unlock_swap()` → `is_choice_active()`
(`runtime_perk_choice_opening.gd:8~9`) → `has_visible_effects()` 가 true 가 된다.
이후 **매 프레임**:

1. `battle_scene_drawer.gd:73` `_draw_hud_overlays` → `:412` `perk_renderer.draw(...)`
   → `runtime_perk_overlay_renderer.gd:463` 이 **전체화면 암막 + `_draw_particles`
   + 5카드 `_draw_unlock_swap_dialog` 전체 + `_draw_feedback`** 을 그린다
2. `battle_scene_drawer.gd:83` `_draw_tower_ascent_fullscreen_map` 이 그 위에
   타워 지도를 칠해 **1번을 통째로 버린다**
3. `battle_scene_frame_controller.gd:529`/`:839` 가 standalone 호스트로
   `_draw_unlock_swap_dialog` 를 **두 번째로** 그린다

즉 **비싼 후보 루프·아이콘 draw·텍스트 레이아웃이 프레임당 두 번** 돈다.
**GRT-043 예산 결함**이다.

### ★부작용 — 지금 교체창에 암막이 없다

경로 1의 암막은 타워 지도에 덮여 사라지고, 경로 3(실제로 보이는 쪽)에서는
이번 커밋이 암막을 **지웠다.** 결과적으로 **스프링 교체창이 암막 없이 뜬다.**

⚠신규 `NO_SECOND_DIM_CORNER_PIXELS=0` QA 가 이것을 못 잡는다 —
그 캡처 캔버스는 `TowerAscentFlowRenderer` + 교체 호스트만 올리고
`battle_scene_drawer._draw_hud_overlays` 를 **아예 안 돈다.**

### 수리 — 소유자를 하나로 정하라

- **(a)** `tower_ascent_flow_owner.has_pending_guardian_spring_chosik_swap()` 이
  true 인 동안 **HUD 경로를 억제**하라(`_draw_hud_overlays` 또는 렌더러 `:463`
  분기에서 조기 반환). standalone 호스트가 소유자가 된다.
- **(b)** standalone 호스트를 버리고 **HUD 경로가 타워 지도 위에** 그리게 하라.

**어느 쪽이든 암막을 명시적으로 복원하라.** 지금은 소유권 결정이 우연에 맡겨져
있고 암막이 그 부수 피해다.

**씰**: 한 프레임에 `_draw_unlock_swap_dialog` 가 **정확히 한 번** 실행됨을 단언하고,
**두 번 그리도록 되돌리면 RED** 가 되는지 반증하라.
⚠QA 캔버스가 `_draw_hud_overlays` 를 타지 않으므로, 이 단언은 **픽셀이 아니라
호출 카운트**로 하라.

## [P3] H2 — F9 (기도 문구 존댓말) 미착수

`tower_ascent_node_modal_localization.gd` 가 **커밋 11파일 목록에 없다.**

- 기준선 `0bd1ee89c:183` = `"기도가 닿아 전능력치가 상승했습니다."` (존댓말)
- `8ce16ec88` 이 `"모든 능력치가 {bonus}%p 상승했다!"` 로 바꿨고 `031d59beb` 는 그대로

같은 카드의 설명문이 존댓말인데 결과 문구만 반말이다.
**저장소 한국어 카피 규칙은 존댓말이다.**

⚠**일본어도 같이 드리프트했다** — `:364` `"上昇した！"` vs 기준선 `"上昇しました。"`.
⚠**반말 문자열이 씰 2곳에 하드코딩됐다**
(`tower_ascent_guardian_spring_node_smoke.gd:491`,
`tower_guardian_spring_slot_and_prayer_smoke.gd:529`).
**같은 커밋에서 함께 고쳐라.**

## [P3] H3 — 미고지 씰 완화가 하나 더 있다

`tower_ascent_guardian_spring_node_smoke.gd:318`.
기준선 `_expect(tabs.is_empty(), "retired sealed guardians must not create display-only character-info tabs")`
가 `sealed` 필터로 완화됐다.

**의미상 타당하다** — 같은 방문에 첫 픽을 커밋하니 owner 가 실제로 활성 수호령을
갖고 패널에 탭이 하나 생기는 게 정상이다. 공허하지도 않다.

**그러나 반려서가 열거한 3개 밖의 씰 변경이고 보고에 없었다.**
필터는 유지하되 `_expect(tabs.size() == 1, ...)` 를 더해 **총 탭 수를 다시
못박고**, 보고에 명시하라.

## [P3] H4 — 선재 씰 하나가 복구가 아니라 삭제됐다

`tower_ascent_guardian_spring_node_smoke.gd:297~298`.
`"later spring visit must restore the run snapshot without rerolling guardian state"`
레그에서 신선한 `later_flow`/`later_owner` 가 기존 `flow`/`owner` 의 **alias 로
대체**됐다.

반증 레인 판정: 원 주장("재롤 회귀를 못 잡는다")은 반증됐으나,
**같은 위치에서 다른 메커니즘의 재현 가능한 커버리지 소실**이 확인됐다.

신선한 인스턴스로 되돌리거나, alias 로 두는 근거를 주석으로 남겨라.

## [P3] H5 — 자동 진행 게이트가 무봉인이다

반려서 수리 항목 2(`_arm_guardian_spring_auto_route` 를 `is_first_pick_pending()`
로 게이트)는 **구현이 옳다.** 그러나 씰이 없다.

반증: `tower_ascent_flow_node_progress.gd:711~712` 와 `:726` 의 게이트를 **둘 다
지워도** 포커스드 5종이 `PASS=5 FAIL=0` 이다.
지금은 더 깊은 `_try_enter_route_aim_from_node_modal:457` 게이트만 봉인돼 있다.

**수리**: 팜 커밋 후 `GUARDIAN_SPRING_AUTO_ROUTE_HOLD_SEC` 를 훨씬 넘겨
`update_selective` 프레임을 돌린 뒤, 단계가 여전히 `NODE_MODAL` 이고 모달
상태문이 `KEY_SPRING_ACTION_UNAVAILABLE` 이 **아님**을 단언하라.

## 확인된 무결 (재작업 금지)

- ★**P0/F1 완전 수리.** 두 레그 독립 재현.
  OPEN 레그: 팜 → `accepted=true applied=true reason=committed` →
  같은 `node_id` 에서 `[first_pick:monkeyring, :koyora, :rabi]`,
  `first_pick_count=3 blind_count=3 total=3`.
  FULLSWAP 레그도 동일.
- ★**씰 3개 의미 복구 확인.** `and not visit_action_committed` 재삽입 시
  정확히 그 세 파일에서 `FAIL=3`.
- **F2 dict 가드 수리 + 봉인**(RED 재현).
- **F3 arity** 병합 트리에서 해소됨.
- **F5 · F6 · F7 · F10 수리됨.**
- **F8 은 반증 레인이 기각**했다(더 이상 재현 안 됨).
- **게이트 전부 GREEN**: 포커스드 5종 `PASS=5 FAIL=0`, 경고 스캔, 헤드리스 로드,
  `git diff --check`, Vulkan QA exit 0.
- **스코프 판정 — 유지 권고.** `_player_facing_node_status` 는 `:432`, `:445`,
  `:590`, `:627`, `:680`, `:774`, `:796` **7곳**에 적용된다(반려서가 2곳이라 한 것은
  관제탑 착오다). 취지에 부합하므로 되돌리지 마라.

## ⚠선재 기저 RED (X1 귀책 아님 · 보고만 하라)

`res://tests/tower_ascent_flow_owner_refactor_smoke.gd` 가 실패한다 —
`"flow runtime coordinator must stay facade-sized"` 및
`"all shared flow dependencies ... must remain eager state fields"`.

실측: `tower_ascent_flow_runtime.gd` = **710줄** vs 씰의 **500줄 예산**(`:60`).

**X1 이 만든 것이 아니다.** 다만 X1 이 그 파일에 줄을 더했으므로
**이번 커밋이 예산을 얼마나 밀었는지 보고하라.** 수리는 별건이다.

## 통합 충돌 (관제탑 실측)

| 조합 | 결과 |
|---|---|
| X1-수정 × 당시 HEAD `3e1ef2998` | **무충돌** |
| X1-수정 × X4-수정 `60ba17525` | **무충돌** (트리 `fb7bbd244`) |
| X1-수정 × X2 `c425881d3` | 텍스트 무충돌 · **F3 arity 해소 확인됨** |

⚠**본 트리 HEAD 는 이미 `c4bcc2429` 로 더 갔다**(X5 착지 + CI 복구).
CI 삽입 위치는 여전히 **샘터 블록 중간**이라 X4·X5 꼬리와 겹치지 않는다.

## 게이트·보고

포커스드 스모크(+H1·H5 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → **픽셀 QA**.

⚠**H1 수리 후 반드시 눈으로 확인하라**: 교체창에 **암막이 있는지**.
⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · **H1 소유자를 (a)로 정했는지 (b)로 정했는지와 근거** ·
암막 복원 캡처 확인 · H2 다국어 4개 + 씰 2곳 동반 수정 · H3·H4·H5 처리 ·
`tower_ascent_flow_runtime.gd` 줄 수 · 미해결.
