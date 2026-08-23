# 지시문 A — 탑 상점 아이템 게이트·카드 축소 (피드백3 1·2·3항)

- **발행**: 관제탑 2026-08-23. 기준 HEAD `d7d5c5b6b`. CI/pre-push 락스텝 226.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb3_shop_d7d5` (브랜치
  `codex/fb3-shop-gating-20260823`). ⚠워크트리≈10GB. ⚠미추적 자산은
  워크트리에 없다 — 필요물은 커밋으로만 이동.
- **의존/순서**: ⚠지시문 C(수련장 표시 정리)와
  `runtime_perk_overlay_renderer.gd`·`tower_ascent_node_modal_state.gd`·
  pointer/layout 씰이 겹친다. **C 착지 후 착수**(또는 같은 워크트리 순차).
- **금지**: 본 트리 직접 편집·푸시·통합. `reset/checkout/stash/통짜 add` 금지.
  보고 후 대기(통합은 관제탑).

## 1·2항 — 수호령 생산물·알의 상점 제외

원인(실측): `tower_ascent_shop_shelf_builder.gd:16~28`의 regular/premium
선반이 `ActiveItemCatalog.CATALOG_ORDER` 전량을 언락+rarity+캐릭터 제한만으로
거른다. 치즈들은 카탈로그에 `lingpet_generated_only:true` 출처 태그가 이미
있으나(`active_item_catalog.gd:803`, 우유병 포함) **런타임 소비자가 0**이고,
수호령 알 게이트(`lingpet_item_offer_policy.gd:35` can_offer_*)는 캡슐
풀(`tower_ascent_shop_inventory.gd:114`)만 적용된다.

작업:
1. `build_candidate_shelves`에서 후보 append 전 (a)
   `item_data.get("lingpet_generated_only", false)`면 스킵(치즈 3종+우유병
   일괄), (b) `LingpetItemOfferPolicy.can_offer_item(...)` 통과 필수(알·
   심령수). 캡슐 풀 기존 게이트는 무수정.
2. 풀 구성 변경이므로 `INVENTORY_VERSION`(`tower_ascent_shop_inventory.gd:23`)
   문자열 bump로 시드 계약 세대 명시.
3. regular 부족 방어는 기존 `insufficient_regular_candidates` 경로 확인만
   (common+rare 풀 20종+라 3칸 미달 없음 — 씰로 재확인).

## 3항 — 상점 카드 소형 정렬 (원본 감성)

원인: 상점은 기본 `CARD_GRID_RECT` 3x2(카드 216.7x212, aspect 0.978)라
드로어의 대형 프로파일을 타서 설명 몇 줄 아래 큰 빈 공간이 남는다. 원본
정본: 핑파이터 `downtown/building_interior.py:8185` 상점 거래 UI = 42px
정사각 셀·6px 갭·5열 아이콘 그리드+호버 툴팁. Godot 사내 전례:
`plaza_interior_layout.gd:12~19`(SHOP_TRADE_CELL_SIZE 42 등).

작업(1단계 최소 변경 — compact 카드화):
1. `tower_ascent_node_modal_state.gd`에 SHOP 전용 그리드 상수 신설 —
   카드 aspect ≤ 0.70이 되도록(예: 3열x2행 유지+그리드 높이 축소로 카드
   높이 ≤150, 또는 수련 1x6 전례처럼 행 재구성). aspect ≤ 0.70이면
   드로어 compact 프로파일(소형 아이콘·폰트)이 자동 발동
   (`runtime_perk_overlay_renderer.gd:148~151` TOWER_NODE_COMPACT_CARD_*).
2. `_build_layout_flags`(`:759`)에 shop 분기 추가, `build_screen_layout`
   (`:681~705`) 라우팅 — 히트테스트는 같은 플래그 자동 공유(GRT-022).
3. 원본 42px 셀 그리드 완전 재현은 별도 콘텐츠 킷이라 이번 스코프 밖 —
   1단계 결과 캡처를 보고에 첨부해 사용자 미감 판정을 받는다.

## 씰·검증 (락스텝)

- ⚠`tower_ascent_shop_node_smoke`는 **선재 RED**(수련/퍽 WIP 귀속) — 착수
  전 RED 로그를 먼저 확보해 귀속 분리. 재고 6칸·액션 7개·스냅샷
  `var_to_bytes` 정확 일치(`:195`) 봉인 유지 확인.
- `tower_node_modal_pointer_smoke:509~` six-card 레그의 shop 분기를 새 상점
  그리드 상수로 갱신(상단 모서리 판정 유지 — GRT-022 반증은 상단 모서리).
- 신규 레그: (i) 치즈·알이 선반 후보에서 배제됨 + 게이트 off 반전 RED
  반증, (ii) 상점 compact 프로파일 레그(`tower_training_screen_layout_smoke`
  `_verify_bonus_badge_four_row_budget` 전례).
- 게이트: 포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths` →
  `run_headless_load_check.ps1` → `git diff --check` → 상점 모달 Vulkan
  캡처(카드 축소 픽셀 확인).

## 보고 형식

워크트리·커밋 해시 목록·씰 종단선(`All Godot smoke tests passed.` 원문)·
캡처 경로·선재 RED 귀속 로그·미해결 명시.
