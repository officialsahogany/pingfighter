# 지시문 W4-병합 — W1과 시각 QA를 합쳐라 (기능 반려 아님)

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/fb7-reward-hover-highlight-20260825`(워크트리
  `D:\codex_tmp\bosspong_rewardhover_a325`)의 `93847a255` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: ★**기능은 통과다. 반려가 아니다.**
  W4-수정4(`93847a255`)의 출력 스파이 봉인을 관제탑이 확인했다 —
  카운터가 `canvas.draw_rect` **뒤**에 있고 `fade <= 0.0` 조기 반환이 앞에 있다.
  네 번 만에 사슬 전체가 덮였다.
- **이 지시문은 통합 충돌 해소만 요구한다.**

## ★먼저 읽어라 (새 세션이면 필수)

계보:

| | 문서 | 커밋 |
|---|---|---|
| 원 지시문 | `docs/feedback7_reward_hover_highlight_codex_handoff.md` | `a325ffc29`(merge-base) |
| 1차 반려 | `..._fix_codex_handoff.md` | `0ad9b38e9` |
| 2차 반려 | `..._fix2_codex_handoff.md` | `6ef939a28` |
| 3차 반려 | `..._fix3_codex_handoff.md` | `51c5a06f9` |
| 4차 반려 | `..._fix4_codex_handoff.md` | `63859a498` |
| 통과 | — | `93847a255` |
| **지금** | 이 문서 | 병합 |

워크트리는 **이미 존재한다. 새로 만들지 마라.**
본 트리 현재 HEAD 는 `a27fc8913` 이고 **읽기 전용**이다.

---

## 무엇이 충돌하는가

`merge-base` = `a325ffc29`. 그 뒤 **W1(`87e497d77`, 무공 슬롯 상한)이 본 트리에
먼저 착지**해 같은 파일 3개를 바꿨다.

관제탑이 3-way 를 시도한 결과:

| 파일 | 결과 |
|---|---|
| `godot/scripts/characters/runtime_perk_effective_stat_query_surface.gd` | 자동 (HEAD==base) |
| `godot/scripts/hud/runtime_perk_overlay_renderer.gd` | **3-way 자동 병합 성공** |
| `godot/tests/tower_reward_pick_smoke.gd` | 충돌 1건 — **관제탑이 이미 해소 방법 확인**(아래) |
| `godot/tools/run_tower_reward_pick_visual_qa.ps1` | **충돌 2건** |
| `godot/tools/tower_reward_pick_visual_qa.gd` | **충돌 3건** |

### 이미 해소법이 확정된 것 — `tower_reward_pick_smoke.gd`

충돌 덩어리 1건이고 **preload 상수 추가가 같은 자리에서 겹친 것**뿐이다.
**합집합으로 풀면 된다.**

```gdscript
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkState := preload(                          # ← W1
	"res://scripts/characters/runtime_perk_state.gd"
)
const RuntimePerkEffectiveLevels := preload(                # ← W4
	"res://scripts/characters/runtime_perk_effective_levels.gd"
)
const RuntimePerkEffectiveStatQuerySurface := preload(      # ← W4
	"res://scripts/characters/runtime_perk_effective_stat_query_surface.gd"
)
const RuntimePerkOverlayRenderer := preload(
```

관제탑이 이 해소본으로 양쪽 레그 생존을 확인했다 — W1 의 슬롯 상한 단언
(`perk_slot_limit` 2건, `slot_limit_rechecks` 2건)과 W4 의 출력 스파이
(`tower_reward_hover_draw_output`, `G1 output seal` 4건, `zero_fade` 6건,
`query_surface_landing`) 전부 살아 있다.

## ★진짜 작업 — 시각 QA 를 합쳐라

기계적 병합이 안 된다. **`_capture_offer` 시그니처가 양쪽에서 갈렸다.**

- **W1** 이 `blocked_index` 인자를 추가하고 `full_slot_reward_pick.png` 캡처를 넣었다
- **W4** 가 `hover_index` 인자를 추가하고 `hover_new_mugong_destination.png`,
  `hover_fusion_materials.png` 캡처를 넣었다

캡처 수 실측:

| | `_capture_offer` 호출 | ps1 마커 |
|---|---|---|
| base `a325ffc29` | 3 | `captures=3` |
| HEAD (W1 착지 후) | 4 | `captures=4` |
| W4 `93847a255` | 5 | `captures=5` |
| **병합 목표** | **6** | **`captures=6`** |

### 요구

1. **`_capture_offer` 시그니처를 합쳐라** — `blocked_index` 와 `hover_index` 를
   **둘 다** 받게 하고, **모든 호출부가 둘 다 넘기게** 하라.
   ⚠기본값으로 얼버무리지 말고 각 호출이 의도한 값을 명시하라.
   기존 4장은 hover 가 없고, 신규 2장은 blocked 가 없다 — 그 차이가
   호출부에서 읽혀야 한다.
2. **캡처 6장이 전부 나오게 하라.** W1 의 4장 + W4 의 2장.
3. **ps1 마커를 `captures=6` 으로** 맞추고 throw 문구도 그에 맞춰라
   (`"four-capture"` / `"five-capture"` → 6장 표현).
4. ★**실제로 QA 를 돌려 6장이 나오는지 확인하라.** 마커만 고치고 실제 캡처가
   5장이면 그 자체가 결함이다. 캡처 파일 목록을 보고에 인용하라.
5. **6장을 전부 열어 보라.** W1 의 `full_slot_reward_pick.png` 와 W4 의
   cyan 착지 링 / red 재료 링이 **동시에 정상인지** 확인하라.

## 하지 말 것

- **기능을 다시 손대지 마라.** `93847a255` 의 출력 스파이 봉인은 통과했다.
- **본 트리를 병합해 오지 마라.** 필요한 HEAD 쪽 내용은 위에 다 적었다.
  이 워크트리는 `a325ffc29` 기준선 그대로 두고 **W1 이 바꾼 부분만 손으로
  반영**하라. 관제탑이 최종 3-way 를 한다.
  ⚠W1 이 그 세 파일에 한 변경을 보려면:
  `git -C d:\main\bosspong -c safe.directory='*' diff a325ffc29 87e497d77 -- <파일>`

## 씰 요구

1. **기존 씰 전부 GREEN 유지** — 특히 `tower_reward_pick_smoke`(양쪽 레그),
   `perk_status_owned_tooltip_smoke`.
2. **조회 수 단언** `tower_reward_pick_smoke:871`/`:883` 실행 확인.
3. **출력 스파이 반증 재확인** — 두 `draw_rect` 를 각각 지웠을 때, 그리고
   `reward_hover_fade` 를 0 으로 강제했을 때 RED 인지. 병합이 그것을 깨지
   않았음을 보여라.

## 게이트·보고

포커스드 스모크 → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → **시각 QA 6장**.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · **합친 `_capture_offer` 시그니처와 호출부 6개가 각각
넘기는 값** · **실제 캡처 파일 6개 목록** · 6장을 열어 본 소감 ·
씰 종단선 원문 · 반증 출력 · 미해결.
