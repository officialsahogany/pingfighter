# 지시문 W4 — 결과 보상 화면 호버 강조 2종 (빈 슬롯 · 합일 재료)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `a325ffc29`. 락스텝 243/243.
- **격리 워크트리**: `D:\codex_tmp\bosspong_rewardhover_a325` (브랜치
  `codex/fb7-reward-hover-highlight-20260825`).
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기. 워크트리 1개만.
- ⚠**W1(무공 슬롯 상한)과 같은 파일을 건드린다.** W1이 먼저 착지하므로,
  이 트랙은 W1 착지 후 재정렬이 필요할 수 있다. 보고에 명시하라.

## 사용자 요청

> 5. 결과선택화면에서 무공을 마우스 호버 시 하단에 현재 무공의 빈 슬롯이
> 페이드인/페이드아웃 스타일로 강조 (이 무공을 선택하면 여기 슬롯에
> 추가된다는 느낌)
> 6. 무공합일에서 마우스 호버 시 합일에 해당하는 극성 혹은 절세무공 2개가
> 강조 (이 무공들이 조건을 만족해서 이 무공합일을 쓸 수 있다는 느낌)

## 실측 확정 — 새로 만들 게 거의 없다

세 조각이 **이미 이 화면에 다 있다.** 빠진 것은 "호버한 카드 → 어떤 슬롯을
강조할지" **해석기 하나**뿐이다.

- **드로우 오너**: `runtime_perk_overlay_renderer.gd:1677`
  `draw_tower_reward_pick`
- **호버 상태 오너**: `tower_reward_pick_state.gd:35`, `:185~191`
  `reward_hover_mouse_pos`
- **하단 "◆ 현재 무공" 원장 띠는 이미 그려진다**:
  `runtime_perk_overlay_renderer.gd:1795` `_draw_status_panel`,
  레이아웃 `runtime_perk_choice_layout.gd:144` `panel_rect`
- **슬롯 rect 산출점**: `:4233` `_get_status_slot_rect(panel_rect, index, display_slots)`
- **빈 슬롯 판별도 이미 있다**: `_build_status_slot_grid` →
  `character_info_overlay_perk_presenter.gd:814~838`의 `_empty_slot` 플래그
- **펄스 링 선례**: `:3695~3702` 신규 획득 슬롯 강조
  (`acquire_pulse = 0.5+0.5*sin(draw_msec*0.008)` + `draw_rect(slot_rect.grow(4.0), ..., false, 2.0)`)
- ★**페이드 틀 완성품이 있다**: `:4066~4070`
  `training_stat_preview_alpha_at(draw_msec)` (상수 `:144~147`,
  **800ms raised-cosine**). GRT-043 주석과 함께 **엄격 호버 게이트 +
  시그니처 캐시**(`:4012~4036`)로 구현돼 있고 전용 씰
  (`tests/training_card_stat_preview_smoke.gd`)까지 있다.

## ★두 개의 구조적 함정 (반드시 처리)

1. **"첫 빈칸"이 아니다.** 보유 퍽 그리드는 `sort_perks`(level 내림차순 →
   id 오름차순, `character_info_overlay_perk_presenter.gd:778~780`,
   `:1234~1243`)로 정렬된다. 신규 무공은 **정렬 위치에 삽입**되어 뒤 셀이
   밀린다. 정확한 착지 셀을 강조하려면 **"가상 추가 + 재정렬" 시뮬레이션**이
   필요하다. 첫 빈칸에 링을 그리면 거짓말이 된다.
2. **합일은 "2개"가 아니다.** 합일 카드는 `eligible_sources`(재료 후보 퍽
   id 배열)를 **이미 들고 있다**(`perk_fusion_offer_planner.gd:131`, 주입
   `tower_reward_pick_offer_builder.gd:239~254`). 그런데 그건 **후보 전체
   (2개 이상)** 이고, 실제 2개 선택은 합일 모달 안에서 일어난다
   (`perk_fusion_localization.gd:73~78` "최대 경지에 오른 무공 두 개를
   선택하세요"). 사용자 문구의 "2개"는 최소 케이스다.
   → **후보 전체를 강조**하고, 문구/연출로 "이 중 둘을 고른다"는 의미가
   읽히게 하라. 임의로 2개만 고르지 마라.

후보 정의(참고): `perk_fusion_catalog.gd:138~153` `is_candidate` =
보유 + **base_level == max_level(극성)** + 클래스 ∈ {numeric_passive,
boolean_unique, mythic_system(=절세무공)} + slot_cost==1 + 미융합.
후보는 전부 보유 퍽이므로 **하단 원장 셀로 이미 동시에 그려진다.**
매칭 키는 `_get_perk_slot_key(skill)`(=id).

## 작업

### (A) 공통 배관 — 호버 프리뷰 해석기 (신규, 렌더러 소유)

1. `draw_tower_reward_pick` 안에서 기존 `hovered_training_choice`(`:4039`)와
   **같은 방식**으로 `choices` × `card_rects` × `mouse_pos`를 스캔해 호버
   카드를 구한다. **호버 없음이면 즉시 `{}` 반환하고 어떤 조회도 하지
   마라**(GRT-043 — 상시 비용 금지).
2. 결과를 `_training_stat_preview_signature`(`:4017`)와 **동일한 시그니처
   캐시**로 감싸 프레임당 재계산을 막아라.
3. ⚠**새 카탈로그/스냅샷 조회를 추가하면
   `tower_reward_pick_smoke.gd:870`/`:882`가 RED가 된다.** 판정 입력을
   **이미 스냅샷에 실려 오는 것**으로 한정하라: `perk_slot_status`
   (`tower_reward_pick_state.gd:733`)와 카드 dict 필드
   (`current_level`/`next_level`/`reward_pick_kind`/`eligible_sources`).
4. 반환 형태는 **슬롯 인덱스가 아니라 키 집합 + 빈칸 요청 개수**로 하라
   (기존 `:3741` 키 기반 계약과 같은 규율).

### (B) 5번 — 빈 슬롯 강조

5. 빈칸 브랜치가 현재 `:3683~3687`에서 **`continue`로 조기 종료**한다.
   링을 그리려면 그 브랜치를 손봐야 한다.
6. 강조 셀은 **1번 함정대로 "가상 추가 후 재정렬" 결과**의 착지 인덱스로
   구하라. 시뮬레이션 비용은 호버 프레임에만 발생하고 시그니처 캐시로
   덮인다.
7. 연출은 `training_stat_preview_alpha_at`의 **800ms raised-cosine을
   재사용**하라. 새 곡선을 만들지 마라.
8. ⚠슬롯이 **가득 찬 경우**에는 강조할 빈칸이 없다. 그때의 표현을
   정의하라(강조 없음 / 가득 참 표시). W1이 그 상태를 비활성으로 만들
   예정이니 **W1의 표현 계통과 충돌하지 않게** 하라.

### (C) 6번 — 합일 재료 강조

9. 호버한 합일 카드의 `eligible_sources`를 키 집합으로 만들고, 하단 원장
   셀 중 키가 일치하는 **전부**를 같은 페이드로 강조하라.
10. 강조 표현은 5번의 빈칸 링과 **구별되어야 한다**(빈칸=들어갈 자리,
    재료=소모될 자리). 색이나 링 형태로 구분하고 근거를 주석에 남겨라.

## ⚠사문화된 게이트 주의

R1이 결과보상에서 수련 카드를 제거한 뒤, 기존 프리뷰 게이트
(`hovered_training_choice`가 `is_physique_training` 요구, `:4039~4059`)는
**이 화면에서 매칭되는 카드가 0개 = 사실상 사문화**됐다. **틀은 재활용하되
게이트 조건은 새로 써라.**

현행 카드 구성(R1 이후): vision(비전 초식, 슬롯 미소모) / supreme(절세무공·
신화 퍽) / mugong(무공, 신규 또는 레벨업) / fusion(무공 합일).

## 씰

- **호버 게이트 레그**: 호버 없음 프레임에서 해석기가 **한 번도 호출되지
  않음**을 단언(GRT-043). RED 반증: 게이트를 제거하면 호출된다.
- **착지 셀 정확도 레그**: 정렬 때문에 밀리는 픽스처(예: 레벨 높은 신규
  퍽이 중간에 삽입)에서 강조 셀이 **실제 착지 인덱스와 일치**함을 단언.
  RED 반증: "첫 빈칸" 구현으로 되돌리면 불일치.
- **합일 재료 레그**: 후보가 3개 이상인 픽스처에서 **전부** 강조됨을 단언
  (2개만 강조하면 RED).
- **가득 참 레그**: 슬롯 가득 상태에서 정의된 표현이 나옴.
- **기존 락스텝**: `tower_reward_pick_smoke`(특히 `:870`/`:882` 조회 수
  단언), `training_card_stat_preview_smoke`, 퍽 원장 계열 전부 GREEN 유지.
- **픽셀 QA**: 무공 카드 호버 1장 + 합일 카드 호버 1장. 페이드 중간
  프레임이 잡히게 캡처하라.

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 픽셀 QA 2장.
보고=워크트리·커밋 해시·씰 종단선 원문·착지 셀 시뮬레이션 방식·
W1과의 파일 겹침 여부·미해결.
