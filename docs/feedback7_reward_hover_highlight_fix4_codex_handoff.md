# 지시문 W4-수정4 — [P1] 카운터가 `draw_rect` 앞에 있어 눈에 보이는 출력 전체를 지워도 GREEN이다

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/fb7-reward-hover-highlight-20260825`(워크트리
  `D:\codex_tmp\bosspong_rewardhover_a325`)의 `63859a498` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT (네 번째).** F11 전수 반증은 **진짜다** — 관제탑이 8건
  삭제→RED를 **직접 재현**했고 요구한 셋(cyan 링 호출·red 링 호출·인자 전달)이
  전부 포함됐다. F12·F13·F14·F15 도 실질 수리됐고 **F12 에 P0 스코프 위험은 없다**
  (순수 additive · 의미 검증 통과).
- **그런데 9번째를 찾으라고 한 항목에서 셋이 나왔고, 전부 사슬의 마지막 링크다.**

## ★먼저 읽어라 (새 세션이면 필수)

계보와 항목 번호 출처:

| | 문서 | 커밋 |
|---|---|---|
| 원 지시문 | `docs/feedback7_reward_hover_highlight_codex_handoff.md` | `a325ffc29` |
| 1차 반려 | `docs/feedback7_reward_hover_highlight_fix_codex_handoff.md` | `0ad9b38e9` |
| 2차 반려 | `docs/feedback7_reward_hover_highlight_fix2_codex_handoff.md` | `6ef939a28` |
| 3차 반려 | `docs/feedback7_reward_hover_highlight_fix3_codex_handoff.md` | `51c5a06f9` |
| **지금** | 이 문서 | `63859a498` |

`git -C D:\codex_tmp\bosspong_rewardhover_a325 -c safe.directory='*' show 63859a498`
워크트리는 **이미 존재한다. 새로 만들지 마라.**

---

## ★같은 결함이 네 번째다 — 패턴을 보라

| 반려 | 무봉인이었던 자리 |
|---|---|
| 1차 F3 | `_draw_status_panel` 호출의 인자 전달 |
| 2차 F8-b | 합일 재료 링의 **소비부** |
| 3차 F11 | cyan 착지 링의 **draw 호출** |
| **4차** | **`canvas.draw_rect` 자체 · `reward_hover_fade` 계산** |

매번 **지목된 자리를 정확히 봉인하고, 그 바로 다음 링크를 놓친다.**
이번에도 8곳을 열거했는데 **카운터를 실제 픽셀 출력보다 한 칸 앞에 두었다.**

## [P1] G1 — 두 링 카운터가 `canvas.draw_rect` **앞에서** 증가한다

착지 링과 재료 링 모두, 카운터를 올린 **뒤에** `canvas.draw_rect` 를 부른다.
그래서 **두 `draw_rect` 를 지워도 카운터는 그대로 오르고 전 스위트가 GREEN**이다.

**즉 호버 기능의 눈에 보이는 출력 전체를 삭제해도 통과한다.**

관제탑이 **두 가지 독립 변형으로 두 번 재현**했다.

**수리**: 카운터를 **`draw_rect` 호출 뒤로** 옮기거나,
더 나은 형태로 **실제 캔버스 draw 호출을 관측하는 스파이**를 쓰라
(테스트 캔버스가 `draw_rect` 호출을 기록하게 하고 그 기록을 단언).
전자는 또 한 칸 앞뒤 문제를 남기고, **후자가 이 계열을 끝낸다.**

## [P1] G2 — `reward_hover_fade` 계산이 무봉인이다

`reward_hover_fade` 를 **0으로 강제하면 두 링이 모두 죽는데** 스위트가 GREEN이다.
이것도 사슬의 링크인데 8곳 열거에 없다.

**수리**: fade 값이 0이면 링이 안 그려짐을 관측하는 레그를 추가하고,
fade 계산을 0으로 강제했을 때 **RED 가 되는지 반증**하라.

## ★수리 방향 — 자리 세기를 그만두라

세 번 연속 "N곳 열거 → 각각 봉인 → N+1번째 발견"이 반복됐다.
**열거로는 끝나지 않는다.**

**요구**: 봉인의 기준을 **"배선 지점 개수"에서 "관측된 픽셀 출력"으로 바꿔라.**

- 테스트 캔버스가 `draw_rect` / `draw_texture_rect` 등 **실제 draw 호출을 기록**하게 하고,
- 호버 상태에서 **cyan 링과 red 링에 해당하는 draw 호출이 기대한 rect·색으로
  실제 발행되는지** 단언하라.
- 그러면 중간 사슬의 **어느 링크를 끊어도** 최종 출력이 사라지므로 자동으로 RED다.

⚠이 형태로 가면 G1·G2 가 동시에 닫히고, **다섯 번째 링크가 나올 여지가 없다.**
다른 방식을 택하려면 **왜 그것이 사슬 전체를 덮는지 근거를 대라.**

## 확인된 무결 (재작업 금지 · 관제탑이 직접 재현)

- **F11 8곳 삭제→RED 전부 재현됨.** 요구한 셋(cyan 링 호출 `(5)`, red 링 호출 `(8)`,
  `_draw_status_panel` 인자 전달 `(2)`) 포함.
- **F12 진짜로 닫혔고 P0 스코프 위험 없다.**
  `runtime_perk_effective_stat_query_surface.gd` 의 +42줄은 **순수 additive 메서드**이고
  기존 소비자의 반환값을 바꾸지 않는다. 의미도 검증 통과.
  종단선 `pure=2 hover=3 ledger=3` 재현됨.
- **F13 / F14 / F15 실질 수리됨.**
- **조회 수 단언 유지.**
- **스코프 깨끗.** 3파일 +349/−7.

## ★통합 충돌 (관제탑 실측 · 앞선 안내 정정)

⚠**이제 본 트리 HEAD 와 충돌한다.** W1 이 착지하면서 생겼다.

`git merge-tree --write-tree 3e1ef2998 63859a498` → **CONFLICT 3파일**:

- `godot/tests/tower_reward_pick_smoke.gd`
- `godot/tools/run_tower_reward_pick_visual_qa.ps1`
- `godot/tools/tower_reward_pick_visual_qa.gd`

`godot/scripts/hud/runtime_perk_overlay_renderer.gd` 는 auto-merge 된다.

원인은 양쪽이 merge-base 이후 같은 파일을 움직인 것이다(W1 이 캡처 수와
`_capture_offer` 시그니처를 바꿨다).

**통합은 관제탑이 한다. 이 워크트리에서 본 트리를 병합하려 하지 마라.**
⚠단 **본 트리 HEAD 는 이미 `c4bcc2429` 로 더 갔다**(W1·W5·W3·X5 착지).
다음 제출 때 관제탑이 3-way 로 해소한다.

## 씰 요구

1. **★G1·G2 를 닫는 출력 관측 씰(필수)** — 위 수리 방향 참조.
2. **반증(필수)**: 두 `draw_rect` 를 **각각** 지웠을 때, 그리고 `reward_hover_fade`
   를 0으로 강제했을 때 **RED 가 되는지** 실제로 확인하고 **원상복구**하라.
   출력을 보고에 인용하라.
3. 기존 8곳 반증 레그는 **그대로 유지**하라(중복이 아니라 심층 방어다).
4. 조회 수 단언 `tower_reward_pick_smoke:871`/`:883` 실행 확인.

## 게이트·보고

포커스드 스모크(+G1·G2 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → **비헤드리스 픽셀 QA**.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · **채택한 봉인 형태와 그것이 사슬 전체를 덮는 근거** ·
G1·G2 반증 실제 출력 · 씰 종단선 **원문** · 미해결.
