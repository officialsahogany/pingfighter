# 지시문 W4-수정2 — [P1] 착지 링이 여전히 거짓말한다 (effective-level 키) + 배선 무봉인 2구멍

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/fb7-reward-hover-highlight-20260825`(워크트리
  `D:\codex_tmp\bosspong_rewardhover_a325`)의 `6ef939a28` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT.** F1·F2·F4·F5는 **실행으로 확인했다**(아래 무결 목록).
  그러나 **F2가 절반만 닫혔다** — id 키는 보존했는데 **정렬 1차 키인 level은
  여전히 원본 키가 아니다.** W4-수정에서 반려한 "거짓말하는 링"이 **세 번째
  경로로 재현**된다. 아래 F7·F8만 닫으면 통합한다.

## ⚠착수 전 위생 (관제탑 실측)

1. **워크트리 재스냅샷 필수.** 리뷰 중 이 워크트리가 09:04·09:19에 커밋과
   다른 내용(부모 계열)으로 바뀌었다가 되돌아온 것이 관측됐고, 미추적 파일
   `godot/tools/zz_tmp_grid_cache_probe.gd`가 생겼다 사라졌다.
   **관제탑이 종료 시점에 직접 확인한 결과 `6ef939a28`에서 clean이다**
   (`git -C <W> -c safe.directory='*' status --porcelain` 무출력).
   착수 전 **본인도 같은 명령으로 재확인**하고 결과를 보고에 인용하라.
2. `git -C <경로> -c safe.directory='*' ...` 형태를 반드시 써라.
   dubious ownership이면 출력이 비어 "clean"으로 오판된다.

---

## [P1] F7 — 착지 링이 effective-level 보너스에서 여전히 엉뚱한 칸을 가리킨다

**W4-수정 F2가 절반만 닫혔다.**

- `_sort_id`로 **id 키**는 보존했다. 확인했다 — `renderer:5169~5172`가 융합
  변형(`entry["id"] = draw_id`, `:5174~5175`) **앞에서** 캡처하고 멱등이다.
  `sort_tower_reward_hover_perks`(`:3955~3967`)가
  `CharacterInfoOverlayPerkPresenter.sort_perks`(`presenter:1234~1243`)를
  키별로 미러링한다(level desc → id asc → `_slot_cell_index` asc).
  라이브 레그 `landing_index=1` 출력도 직접 재현했다.
- **그런데 정렬 1차 키는 `level`이다.** 착지 의사엔트리는 카드의 **base
  `next_level`** 을 쓰는데(`renderer:3898` `landing_key_levels[perk_key]`),
  실제 원장 엔트리는 **effective level = base + `item_perk_level_bonus`** 로
  정렬된다.
- 즉 **effective-level 보너스를 주는 아이템을 장착한 순간, 착지 의사엔트리와
  실제 원장 엔트리가 서로 다른 레벨군에 떨어진다.** id 키를 아무리 정확히
  맞춰도 1차 키에서 이미 갈리므로 링이 다른 칸을 가리킨다.
- 이건 지시문 함정 1이 금지한 "거짓말하는 링"의 **세 번째 변종**이다.
  (1차 = 융합 셀 id 변형, 2차 = 재정렬 키 불일치, 3차 = 레벨 키 불일치)

**수리**: 착지 의사엔트리의 level을 **원장이 실제로 정렬에 쓰는 값과 같은
식으로 산출하라.** base `next_level`이 아니라 그 위에 동일한
`item_perk_level_bonus` 적용 결과를 써야 한다.

⚠**새 조회를 늘리지 마라.** 조회 수 단언
(`tower_reward_pick_smoke:871`/`:883`)이 여전히 살아 있다.
보너스 값은 이미 스냅샷 `perk_slot_status` 또는 기존 acquired 엔트리에서
파생 가능한지 먼저 확인하라. 불가피하게 조회가 늘면 **그 사실과 대안을
보고하고 관제탑 판정을 기다려라.**

**씰**: `item_perk_level_bonus`가 0이 아닌 픽스처에서
"착지 인덱스 == 실제 구매 후 인덱스"를 단언하는 레그를 추가하고,
**보너스를 반영하지 않는 구현으로 되돌리면 RED가 되는지 반증**하라.
⚠기존 F2 픽스처(융합 1건 + level-1 신규 무공)는 보너스가 0이라 이 계열을
전혀 덮지 못한다.

## [P1] F8 — 배선 무봉인 2구멍 (한 줄 삭제로 기능 전멸, 전 씰 GREEN)

세션이 F3에 소스씰을 추가한 것은 확인했고 새 추출기
(`tower_reward_pick_smoke.gd:1592~1602`)가 `static func` 경계를 올바로
처리하는 것도 확인했다. **그러나 지시문 F3이 지목한 세 자리 중 두 곳이
그대로 뚫려 있다.**

### F8-a — `_draw_status_panel` 호출의 인자 전달 (`renderer:1819`)

- `reward_hover_preview` **인자 하나만 지우면** `_draw_status_panel:3616`의
  기본값 `{}`가 먹어 **호버 기능이 통째로 죽는다.**
- 그런데 전 씰이 GREEN을 유지한다. `perk_status_owned_tooltip_smoke:278`은
  `_build_status_slot_grid(` 문자열만 요구하고, 신규 소스씰은
  `draw_tower_reward_pick` 본문의 `_resolve_tower_reward_hover_preview(`
  존재(`:1704`에서 여전히 대입됨)와 `_draw_status_panel` 본문의
  `_reward_hover_landing_slot`/`reward_hover_material_keys` 존재만 본다.
  행동 5레그는 전부 헬퍼를 직접 호출한다.
- 유일한 간접 방어는 `:1704` 지역변수가 미사용이 되며 뜨는
  GDScript `UNUSED_VARIABLE` 경고뿐 — **씰이 아니라 경고 스캔 의존이다.**
- ⚠**실제로 재현됐다.** 리뷰 중 `:1819` 인자 삭제 변이가 적용된 상태에서도
  스모크가 통과하는 것이 관측됐다.
- **수리**: `draw_tower_reward_pick` 본문 추출 결과에서 `_draw_status_panel(`
  이후 구간을 다시 잘라, **`reward_hover_preview` 식별자가 그 인자 목록 안에
  존재함**을 단언하는 레그를 추가하라.

### F8-b — 합일 재료 링 씰이 선언 줄로 통과 (`renderer:3690` vs `:3759~3760`)

- 재료 링 씰이 `:3690`의 **선언/대입 줄**로 통과한다.
  **실제 소비부(`:3759~3760`)를 통째로 지워도 GREEN**이다.
- **수리**: 선언이 아니라 **소비 지점**을 단언하라. 소비부를 지웠을 때 RED가
  되는지 **반증으로 증명**하라.

⚠**두 구멍 모두 반증(해당 줄 삭제 → RED → 원상복구)을 실제로 실행하고
그 출력을 보고에 인용하라.** 소스 문자열 검색으로 "넣었다"고 주장하는 것은
증거가 아니다.

## [P2] F9 — 새로 넣은 주석이 사실과 반대다 (활주구슬)

이 커밋이 `renderer:3847~3848`에 넣은 주석:

> `Existing-perk upgrades reuse their owned cell. Only a level-zero Mugong or supreme card creates a new slot destination.`

**`dash_amplification`(활주구슬)에 대해 거짓이다.**

- `runtime_perk_catalog.gd:109~110` 한국어 주석이
  **"각 구슬이 슬롯 한 칸을 따로 차지하는 카운트형 무공"** 이라고 명시한다.
- `get_slot_cost_for_level`(`:1596~1600`)이 `dash_amplification`에 한해
  `normalized_level`을 **그대로 반환**한다 → Lv.1→2 구매 시 비용이 1→2로
  올라 **빈 셀 하나가 실제로 소모된다.**
- 도달 가능하다: `runtime_perk_catalog.gd:1367~1371`이
  `dash_token_boost_chances[dash_level]`을 레벨 무관하게 굴리고,
  `_extract_owned_slot_upgrade_reserved_choices`(`:2181~2183`)가
  `dash_amplification`만 명시적으로 remaining에 남겨 풀에서 빼지 않으며,
  `tower_reward_pick_offer_builder.gd:237`이 이를 `reward_pick_kind="mugong"`
  으로 실어 나른다.
- 호버하면 `hovered_tower_reward_preview_choice:3849`의 `current_level > 0`
  게이트에서 `{}`가 반환되어 착지 링이 전혀 안 뜬다.

**하이라이트 공백 자체는 부모 `0ad9b38e9`의 기저**이므로 확장은 선택이다.
**그러나 틀린 주석은 이 커밋이 새로 넣은 것이므로 반드시 고쳐라.**

- **최소(필수)**: 주석을 "활주구슬만 예외이며 별도 처리한다"로 정정 +
  활주구슬 Lv.1→2 호버 픽스처 레그를 `tower_reward_pick_smoke`에 추가.
- **권장**: 게이트를 '레벨이 0인가'가 아니라 **'슬롯 비용이 증가하는가'** 로
  바꿔라 —
  `get_slot_cost_for_level(choice, next_level) > get_slot_cost_for_level(choice, current_level)`
  일 때 `landing_key_levels`를 채우고 `empty_slot_requests`를 그 차이만큼
  올린다(활주구슬은 항상 1). ⚠**`:3838`과 `:3869` 두 곳 모두** 고쳐야 한다.
- ⚠참고: `tests/dash_token_slot_cost_smoke.gd`는 이 워크트리에서 **선재
  RED**다(미추적 아이콘 `assets/sprites/perks/dash_amplification_perk_icon.png`
  부재 + `대쉬토큰`→`활주구슬` 개명 표기 드리프트 + 오퍼 필터 레그 2건).
  이 커밋이 건드리지 않은 파일들이라 회귀가 아니다. **원인 규명은 범위 밖이다.**
  다만 F9가 근거로 쓰는 `get_slot_cost_for_level` 레그(`:96~99`)는 실패
  목록에 없어 통과함을 확인했다.

## [P3] F10 — 항진 단언 2건 + 캐시 무효화 레그 부재

세 건 다 씰 강도 문제다. **F7·F8 수리와 같은 커밋에 접어라.**

1. `_expect(cached_landing_grid == landing_grid, ...)`는 **항진 단언**이다 —
   `_build_status_slot_grid`가 멤버 Array를 **참조로 반환**하므로 두 변수가
   같은 객체를 가리킨다. 내용 비교가 아니라 **재조립 카운트**를 단언하라.
2. F2 씰의 "반증" 레그 `fusion_landing_index != 0`은 **바로 위 `== 1`이 이미
   함의**하므로 반증력이 0이다. 실제 반증은 소스 토글로만 가능했다.
   위 F7의 반증 레그로 대체하라.
3. 캐시 씰에 **'히트' 레그만 있고 '무효화(미스)' 레그가 하나도 없다.**
   시그니처에서 `hash(acquired)`와 `slot_limit`를 **지워도 전 스위트가
   GREEN**을 유지한다. 최소 두 레그를 추가하라 —
   (a) acquired 원소 **개수는 같은데 내용만** 바뀐 경우(레벨업, 융합 2→1 치환),
   (b) `slot_limit`이 런 중에 늘어난 경우.
4. `acquired.duplicate(true)` → `duplicate()` 얕은 복사 변경 자체는
   현재 무해함을 확인했다(`build_slot_grid_entries`(`presenter:814~838`)는
   엔트리를 변형하지 않고 draw 루프(`:3708~3761`)는 읽기 전용).
   ⚠**다만 캐시가 프레임을 넘어 살아남는 지금 조합에서는 반환 그리드가
   호출자의 live entry dict를 별칭한다.** 방어 주석을 남기거나 얕은 복사를
   되돌려라. 판단을 보고하라.

## 확인된 무결 (재작업 금지 · 관제탑이 실행으로 확인)

- **F1 완전히 닫힘.** `perk_status_owned_tooltip_smoke: ok` /
  `Smoke summary: PASS=1 FAIL=0 TOTAL=1` / `All Godot smoke tests passed.`
  EXITCODE=0. `renderer:3684`가 실제 3인자 호출.
  ★**추출 경계도 재현 확인** — 씰의 `_extract_function_source`가 `"\nfunc "`를
  찾아 `static func`를 경계로 못 잡아 약 17줄 넘겨 읽지만, 구간을 반으로 잘라
  각각 검사한 결과 **진짜 본문(3607~3772)에 `_build_status_slot_grid(`가 있고
  삼켜진 static func 구간(3773~3789)에는 없다.** 경계 이동으로 인한 거짓
  통과가 **아니다.**
- **씰 약화 없음.** `git diff a325ffc29 6ef939a28 -- perk_status_owned_tooltip_smoke.gd`
  = **0줄**(두 커밋 모두 대조). 커밋이 건드린 파일은 정확히 2개.
- **시그니처·호출자 전원 유효.**
  `_build_status_slot_grid(acquired, slot_limit, hover_preview := {})` @4568.
  호출자: `renderer:3684`(3인자), `perk_status_owned_tooltip_smoke:153`(2인자,
  기본값 사용 — 선택 인자가 지켜야 했던 바로 그 호출),
  `tower_reward_pick_smoke:1030`/`:1042`/`:1066`(3인자).
- **F2 id 키 부분은 정확하다**(위 F7 참조). 라이브 레그
  `tower_reward_hover_fusion_landing: original=fusion_1 new=item_luck landing_index=1`
  재현 확인.
- **F4 supreme은 픽스처 전용이 아니다.** `_append_choice`
  (`tower_reward_pick_offer_builder.gd:291`)가 `reward_pick_kind`를 kind
  인자에서 세우고 `:82`에서 `"supreme"`로 호출된다.
  `tower_reward_pick_smoke:566`이 이미 생산 경로가 `"supreme"`를 낸다고 단언.
  `_build_supreme_choice`가 `current_level=0`/`next_level=1`(`:210~211`) 설정 +
  미보유 퍽으로 필터(`:194`).
- **F5 캐시는 실재한다.** `hover_preview.is_empty()`이면 시그니처 계산 전에
  조기 반환하므로 **비호버 프레임은 비용 0**이다.
  재조립 카운트 씰(`tower_reward_pick_smoke:1063~1072`)은 진짜 캐시 씰이고
  GREEN으로 실행됐다.
- **F6 지연은 승인**된다. W1 소유를 명시한 근거 주석(`renderer:3874~3875`)이
  지시문이 허용한 형태다.

## ★통합 충돌 — 세션 주장이 틀렸다 (관제탑 실측)

`git merge-tree --write-tree --messages ddd9cde18 6ef939a28` → **exit 1**

| 파일 | 결과 |
|---|---|
| `godot/tests/tower_reward_pick_smoke.gd` | Auto-merge **CLEAN** |
| `godot/tools/run_tower_reward_pick_visual_qa.ps1` | **CONFLICT (content)** |
| `godot/tools/tower_reward_pick_visual_qa.gd` | **CONFLICT (content)** |

충돌 영역 4개: `captures=4` vs `captures=5` 마커, 4장 vs 5장 throw 문구,
`_capture_offer` 시그니처.

세션 보고의 **"겹치지만 W5 실제 변경 hunk는 영역이 다르다"** 는 W1에 대해
**3파일 중 2파일에서 성립하지 않는다.**
**통합은 관제탑이 한다. 이 워크트리에서 W1을 병합하려 하지 마라.**

⚠`runtime_perk_overlay_renderer.gd`는 **W5 `77efc52f9`와도 겹친다.**

## 게이트·보고

⚠**W4-수정 보고에서 미실행이었던 게이트를 이번엔 반드시 통과시켜라.**
지난 보고는 샌드박스 권한 분류기 거부로 아래가 전부 미실행이었다.

- `perk_status_owned_tooltip_smoke` + `tower_reward_pick_smoke` 포커스드 실행
- **`run_warning_scan.ps1 -Paths <touched>`**
- **`run_headless_load_check.ps1`**
- **`git diff --check`**
- **비헤드리스 픽셀 QA** — 실제 창에서 cyan `grow(+5.0)` 2.5px 착지 링과
  red `grow(-3.0)` 3.0px 재료 링이 원장 셀 위에 보이는지.
  ⚠**자동 씰이 이 자리를 못 막는다는 것이 F8-b로 확인됐다. 눈으로 봐야 한다.**

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라.**
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

**보고에 반드시 포함**: 추가 커밋 해시 · 착수 전 워크트리 재스냅샷 결과 원문 ·
씰 종단선 **원문** · **F7 effective-level 픽스처 레그 결과** ·
**F8-a·F8-b 반증(줄 삭제 → RED → 복구) 실제 출력** ·
F9 게이트 수정 방식(최소/권장 중 무엇) · F10-4 얕은 복사 판단 ·
조회 수 단언 유지 여부 · 미해결.
