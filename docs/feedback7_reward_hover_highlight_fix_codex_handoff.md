# 지시문 W4-수정 — [P0] pre-push 등재 씰 파손 + 착지 셀 오지정

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/fb7-reward-hover-highlight-20260825`(워크트리
  `D:\codex_tmp\bosspong_rewardhover_a325`)의 `0ad9b38e9` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT.** 본체 방향은 맞다 — 합일 재료 **전체** 강조, GRT-043
  호버 게이트, 800ms raised-cosine 재사용, 판정 입력을 스냅샷·카드 dict로
  한정한 것(조회 수 단언 `tower_reward_pick_smoke:871`/`:883` GREEN 유지),
  full-slot에서 가짜 빈 슬롯을 안 만드는 것까지 전부 확인했다. 캡처도
  직접 열어 정렬 시뮬레이션이 실제로 동작함을 봤다(착지 링이 첫 빈칸
  index 2가 아니라 index 1에 있고 megingjord 셀이 밀렸다).
  **아래 F1·F2만 닫으면 통합한다.**

## [P0] F1 — pre-push 등재 씰을 새로 RED로 만든다 (실행 확인)

- `godot/tools/run_pre_push_checks.ps1:57`이
  `res://tests/perk_status_owned_tooltip_smoke.gd`를 등재한다.
- 그 씰의 `_test_status_panel_wiring_source`(`:277~278`)는 렌더러 소스에서
  `func _draw_status_panel(` **본문을 추출해 `_build_status_slot_grid(`
  문자열 존재를 단언**한다.
- 이 커밋이 그 호출을 `build_tower_reward_hover_slot_grid(`로 교체하면서
  문자열이 사라졌다.
- 실행 확인: `ERROR: perk_status_owned_tooltip_smoke FAIL: _draw_status_panel
  must assemble the grid via _build_status_slot_grid` /
  `Smoke summary: PASS=0 FAIL=1`. 부모 `a325ffc29`에서는 GREEN
  (함수 본문 추출 대조로 PARENT=True / CHILD=False 확인) → **순수 회귀**.
- ⚠추출 종료 경계도 옮겼다 — 신규 비-static `_resolve_tower_reward_hover_preview`가
  `_collect_perk_slot_keys`보다 앞에 삽입돼 nextfunc 위치가 바뀌었다.

**수리**: `_build_status_slot_grid`를 **단일 진입점으로 유지**하고
`hover_preview`를 선택 인자로 받게 하라.

```
func _build_status_slot_grid(acquired: Array, slot_limit: int,
        hover_preview: Dictionary = {}) -> Array:
```

그러면 `_draw_status_panel` 본문은
`_build_status_slot_grid(acquired, slot_limit_for_grid, reward_hover_preview)`
한 줄로 남아 기존 씰이 그대로 GREEN이 되고 "패널은 공용 조립기를
관통한다"는 씰의 의도도 보존된다.
⚠**씰 문구를 고쳐 통과시키는 것은 단언 약화다. 금지.**

## [P1] F2 — 융합 셀이 있으면 착지 링이 엉뚱한 칸을 가리킨다

지시문 함정 1이 금지한 "거짓말하는 링"이 **다른 경로로 재현**됐다.

- 생산 경로는 `character_info_overlay_perk_presenter.gd:751`에서
  `sort_perks`로 정렬을 **끝낸 뒤**,
  `runtime_perk_overlay_renderer.gd:5112`가 융합 셀의 `entry["id"]`를
  `fusion_1` → `perk_fusion_pair:fusion_1@N|a|b`로 **덮어쓴다.**
- 신규 `build_tower_reward_hover_slot_grid`(`:3934`)는 그 **변형된 배열을
  다시 `sort_perks`로 정렬**하므로 융합 셀의 정렬 키가 달라진다.
- 신규 무공은 항상 `next_level=1`이라 융합 셀(level 1)과 **같은 레벨군**에
  떨어져 **반드시 id 비교로 결정**된다.
- 구체 재현: 융합 1건 보유(`fusion_1`, level 1)뿐인 상태에서 신규 무공
  `item_luck`(level 1) 카드를 호버.
  - 실제 구매 후 순서(변형 전 id): `fusion_1` < `item_luck` →
    **착지 인덱스 1**
  - 호버 프리뷰 순서(변형 후 id): `item_luck` < `perk_fusion_pair:...` →
    **강조 인덱스 0**
  - cyan 링이 다른 셀을 가리키고, 융합 아이콘이 호버 중에만 0→1로 튄다.
- 새 씰 픽스처(alpha_high/zeta_same_rank/omega_low)는 **융합 셀이 없어**
  이 계열을 전혀 덮지 못한다.

**수리**: 재정렬을 **원본 정렬 키**로 하라. 둘 중 택일.
- (a) `_build_acquired_perks_for_snapshot`에서 id 변형 **전** 원본 키를
  `entry["_sort_id"]`로 보존하고, 시뮬레이션은 `_sort_id`(없으면 `id`)를
  쓰는 비교자를 사용.
- (b) 정렬 시뮬레이션을 **presenter 레벨**(변형 전 배열)에서 수행하고
  결과 인덱스만 렌더러로 넘긴다.

**씰**: "융합 셀 1개 + 그 사이에 정렬되는 level-1 신규 무공" 픽스처 레그를
추가하고, **현행 구현으로 되돌리면 RED가 되는지 반증**하라.

## [P2] F3 — 새 씰이 draw 배선을 봉인하지 못한다 (공허 GREEN 위험)

- `_verify_reward_hover_highlight_contract`의 5레그가 전부
  `renderer._resolve_tower_reward_hover_preview(...)` 또는
  `RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(...)`를
  **직접 호출**한다.
- `draw_tower_reward_pick:1699`의 호출, `:1813`의 인자 전달,
  `:3710`/`:3753`의 실제 링 draw 중 **어느 하나를 삭제해도 5레그 전부
  GREEN**을 유지한다.
- ⚠이 저장소는 정확히 그 상황을 막으려고
  `perk_status_owned_tooltip_smoke.gd:272` 함수-본문-추출 소스씰을 두고
  있었는데, 이 커밋은 **새 배선 씰을 하나도 추가하지 않은 채 그 기존
  씰만 깼다.**
- 수리: 같은 패턴의 소스씰을 `tower_reward_pick_smoke`에 추가하라 —
  `draw_tower_reward_pick` 본문에 `_resolve_tower_reward_hover_preview(`,
  `_draw_status_panel` 본문에 `_reward_hover_landing_slot`과
  `reward_hover_material_keys` 존재를 함수 본문 추출로 단언.

## [P2] F4 — 절세무공(supreme) 카드에 착지 강조가 없다

- `hovered_tower_reward_preview_choice`(`:3834`)가 `fusion`·`mugong` 외
  모든 kind에 `{}`를 반환한다.
- 그런데 supreme 카드가 주는 신화 퍽은
  `runtime_perk_catalog.gd:1571 is_slot_consuming_perk` /
  `:1592 get_slot_cost_for_level` 기준으로 **슬롯 1을 소모**하고 실제로
  하단 원장에 셀로 그려진다(캡처의 megingjord 금색 셀).
- 현행 4종 중 슬롯을 먹는 카드는 **mugong·supreme 둘**인데 supreme만
  조용히 빠졌다.
- 수리: supreme을 mugong과 **같은 착지 계산 경로**에 넣어라. 슬롯 소모
  여부는 카드 dict의 `max_level`/`reward_pick_kind`로 판별 가능하며
  **새 조회가 필요 없다**(F5·조회 수 단언과 충돌하지 않는다).
  레벨업 카드는 "기존 슬롯 강조"로 확장하거나, 최소한 "레벨업은 슬롯을
  새로 먹지 않으므로 강조하지 않는다"는 근거 주석과 씰 레그를 남겨라.

## [P3] F5 — 시뮬레이션이 시그니처 캐시 밖이다

- `_draw_status_panel:3679`가 `build_tower_reward_hover_slot_grid`를
  **프레임마다 무조건** 호출한다. 호버 중이면 `:3910`
  `acquired.duplicate(true)`(엔트리마다 descriptions·색·툴팁 라인을 품은
  무거운 dict)와 `:3934` `sort_custom`(매 프레임 람다 할당)이 돈다.
- `_tower_reward_hover_preview_signature` 캐시는 `:3862`의 **경량 모델만**
  덮는다. 지시문 (B)6의 "시뮬레이션 비용은 시그니처 캐시로 덮인다"는
  **성립하지 않는다.**
- 수리: `grid_entries`도 (hover_preview 시그니처, acquired 시그니처) 키로
  캐싱하거나, 시뮬레이션 결과를 **착지 인덱스 하나로 줄여** 캐시하고
  draw는 인덱스만 읽게 하라. 씰에 "동일 호버 입력 연속 프레임에서 그리드
  재조립 카운트가 증가하지 않음" 레그를 추가하라.

## [P3] F6 — 슬롯이 가득 차면 호버 피드백이 완전히 없다

- `slot_full`일 때 `empty_slot_requests=0` / `landing_key_levels={}`이라
  `reward_hover_fade`는 계산되지만 그릴 대상이 없어 **화면 변화가 0**이다.
  플레이어는 "강조가 안 뜨는 것"과 "고장난 것"을 구분할 수 없다.
- 주석은 W1이 disabled 표현을 소유한다고 선언하지만 **W1은 아직 미착지**다.
- 수리: W1 착지 이후 통합을 전제로 하거나, 그 전까지는 기존 원장
  "가득 참" 힌트(`get_full_slot_hint`, `:3665`)를 호버 시 페이드로 한 번
  강조하는 최소 표현을 넣어라. 어느 쪽이든 **W1 선행 의존을 보고에
  명시적 차단 조건으로** 기록하라.

## 확인된 무결 (재작업 금지)

- 합일 `eligible_sources` **전체** 강조(3-소스 픽스처 + 캡처 확인).
  주입점은 `perk_fusion_offer_planner.gd:131`이며 `_build_basic_pool`이
  그대로 실어 나른다.
- GRT-043 호버 게이트(호버 없음 프레임에서 스냅샷 접근 전 `{}` 반환).
- 판정 입력이 스냅샷 `perk_slot_status` + 카드 dict로 한정 —
  `get_snapshot()`·`get_perk_slot_status()` 신규 호출 0.
  조회 수 단언 `:871`/`:883` GREEN 유지 확인.
- 800ms raised-cosine 재사용(새 곡선·상수 없음).
- 표현 구분: landing `grow(+5.0)` 2.5px cyan / material `grow(-3.0)` 3.0px
  red / 기존 acquire pulse `grow(+4.0)` 2.0px gold(비어있지 않은 셀 전용,
  landing과 공존 불가).

## 통합 메모

⚠**W1(`ddd9cde18`)과 3파일이 겹친다**: `tests/tower_reward_pick_smoke.gd`,
`tools/run_tower_reward_pick_visual_qa.ps1`, `tools/tower_reward_pick_visual_qa.gd`.
세션이 제시한 병합 지침(캡처 6장 통합, `_capture_offer`의 blocked-index/
hover-index 인자 병합)은 타당하다. 생산 렌더러 파일은 W1과 겹치지 않는다.
⚠`runtime_perk_overlay_renderer.gd`는 **W5(`77efc52f9`)와도 겹친다.**

## 게이트·보고

`perk_status_owned_tooltip_smoke` 포함 포커스드 스모크(+RED 반증) →
`-Paths` 경고 → 헤드리스 로드 → `git diff --check` → 픽셀 QA.
보고=추가 커밋 해시·씰 종단선 원문·**F2 융합 픽스처 레그 결과**·
supreme 착지 처리 방식·미해결.
