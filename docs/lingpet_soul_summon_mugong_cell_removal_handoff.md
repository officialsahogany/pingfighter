# 영혼소환술 무공 셀 제거 핸드오프 (Codex 실행용)

작성 2026-08-01. 사용자 라이브 지적: **영혼소환술은 초식인데 TAB 캐릭터
정보창의 "무공" 섹션에도 비급 셀로 중복 표시된다.** 장착 초식 섹션에 이미
있으므로 무공 섹션 표시는 불필요하다.

## 1. 원인 (설계 지시 오해 — Claude 소관)

사용자 원 지시(라이브 QA 3차)는 **"영혼소환술은 캐릭터정보창에 무공 슬롯을
차지하지 않음"**이었는데, 내가 이를 **"표시는 하되 슬롯 예산만 소모하지
않는다"**로 해석해 `_slot_free_cell` 패턴(비소모 셀)으로 지시했다.
코덱스는 지시대로 구현했으므로 구현 결함이 아니라 **지시 오해**다.

현재 동작:
- `character_info_overlay_perk_presenter.gd:152` —
  `should_hide_equipped_unlock_perk()`가 `character_info_slot_free`가 true면
  **`false`를 반환해 숨김을 면제**한다(주석: "keeps a visible, slot-free
  record in the TAB Mugong collection even while its combat Chosik orb is
  equipped").
- `:541` `slot_cost <= 0` → `_slot_free_cell = true`
- `:552` `build_slot_grid_entries()`가 free 엔트리를 슬롯 그리드 **패딩 뒤에
  append** → 스크린샷의 "슬롯 0/6 + 오른쪽 비급 셀".

## 2. 변경 계약

- **TAB 캐릭터정보창 "무공" 섹션에서 영혼소환술 셀을 제거**한다.
  가장 좁은 수정은 `should_hide_equipped_unlock_perk()`의
  `character_info_slot_free` 면제 분기를 없애 **일반 unlock 퍽과 같은
  중복 억제**(장착 시 숨김)를 받게 하는 것이다. 구현 방식은 재량이되
  **다른 unlock 퍽의 기존 동작을 바꾸지 말 것.**
- **유지되는 것** (제거 대상 아님):
  - **장착 초식 섹션의 영혼소환술** — 실제 장착 상태 표시(스크린샷 3번째 칸).
  - **무공 선택 화면(퍽 카드)의 비급 아이콘·중립 옥색 책** — 이건 *획득
    경로*의 표현이고 캐릭터정보창과 무관하다. 랜덤화 핸드오프
    (`lingpet_soul_summon_offer_randomize_handoff.md`)와도 독립.
  - **전투 초식구슬 5칸 중 1칸 점유** — 밸런스 계약이라 불변.
- ⚠️ **슬롯 카운터는 지금도 정상**(0/6)이므로 카운터 로직은 건드리지 말 것.
  이번 변경은 **표시 제거**만이다.
- `_slot_free_cell` / `build_slot_grid_entries()`의 free-entry 경로가 이
  변경으로 **소비자 0**이 되는지 확인하고, 0이면 죽은 코드 처리 방침을
  보고할 것(다른 소비자가 있으면 그대로 둔다).

## 3. 씰

- **소유권 씰 수정**: `soul_summon_art_skill_contract_smoke` 등에
  "무공 그리드에 비소모 셀로 존재"를 단언하는 레그가 있으면 **반전**한다 —
  장착 상태에서 **무공 엔트리 부재**를 단언.
- **회귀 (반드시 GREEN 유지)**:
  - 장착 초식 섹션에 영혼소환술이 계속 표시된다.
  - 무공 슬롯 카운터가 여전히 영혼소환술을 세지 않는다(예산 가득 픽스처).
  - 다른 unlock 퍽의 표시·중복 억제 동작 불변.
- 반증 1회(면제 분기를 되살리면 "무공 엔트리 부재" 단언이 RED).
- **Vulkan 픽셀 QA 1장**: 영혼소환술 장착 상태의 TAB — 무공 섹션이
  `0/6` 빈 그리드만 보이고 비급 셀이 없어야 한다.

## 4. 문서 갱신

`docs/lingpet_guardian_live_qa_round3_handoff.md` §2의 "`_slot_free_cell`
패턴으로 비소모 셀 표시" 문구를 **"무공 섹션 미표시"**로 정정하고, 사유
(2026-08-01 사용자 지적 · 지시 오해 정정)를 남길 것.

## 5. 보고 형식

커밋 해시 / 택한 수정 지점 / `_slot_free_cell` 소비자 잔존 여부 / 씰 원문·
반증 / 픽셀 캡처 경로 / 미결·발견 사항.
