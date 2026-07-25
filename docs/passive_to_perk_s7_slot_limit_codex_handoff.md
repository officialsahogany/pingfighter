# S7 코덱스 핸드오프 — 뱀서식 퍽 슬롯 6개 제한

기준 문서: `docs/passive_to_perk_conversion_plan.md` D1(슬롯 6개)·D2(슬롯 소모 경계).
발주: 2026-07-08. Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 설계 (확정)

- **고정 6 퍽 슬롯.** 뱀서(VS)식 = 슬롯 확장 없음(VS 무기/패시브 슬롯이 고정).
  common_expansion 재슬롯화 등 확장 메커니즘은 이번 범위 아님(§6 별도 결정).
- **VS식 오퍼 게이팅**: 슬롯 소모 퍽을 6개 보유하면, 이후 퍽 선택지는 **이미
  보유한 슬롯 퍽의 레벨업만** 제시(신규 슬롯 퍽 미제시). 스왑 다이얼로그 없음.
- **슬롯 소모 경계(D2)**:
  - 소모: 일반퍽(COMMON_PERKS·캐릭터 non-unlock 퍽·CONVERTED_PERKS 26) +
    신화퍽(CONVERTED_MYTHIC_PERKS 11)
  - 비소모: `unlocks_skill != ""`(unlock_* — 기존 5구슬 UNLOCK_SLOT_BUDGET 별도) /
    `is_instant`(instant 퍽) / 링펫(`is_lingpet_affinity_chip` /
    `is_lingpet_ring_core_upgrade`) / `is_gold_conversion`(골드변환)

## 합격 조건

1. 슬롯 소모 퍽 보유 < 6: 기존과 동일(신규 슬롯 퍽 제시됨).
2. 슬롯 소모 퍽 보유 == 6: 오퍼에 신규 슬롯 퍽 0건, 보유 슬롯 퍽 레벨업 + 비소모
   퍽(instant/unlock/lingpet/gold)만.
3. 비소모 퍽은 6슬롯과 무관하게 항상 로직대로.
4. 슬롯 현황 UI(X/6)가 퍽 선택 화면 + TAB 퍽 패널에 표시.
5. 플래그 OFF에서도 안전(플래그 ON이 개편 라이브 상태 — 슬롯 제한은 개편 체제의
   일부이므로 플래그 ON에서 활성; OFF 동작은 기존 아이템 체제라 슬롯 무관.
   구현 시 슬롯 필터를 flag ON에서만 적용할지, 항상 적용할지는 아래 노트 참조).

## 핵심 신설: 슬롯 소모 판정 + 카운트

- 공용 판정 `is_slot_consuming_perk(perk_data) -> bool`:
  ```
  if unlocks_skill != "": return false
  if is_instant: return false
  if is_lingpet_affinity_chip or is_lingpet_ring_core_upgrade: return false
  if is_gold_conversion: return false
  return true
  ```
- 보유 슬롯 카운트 `count_owned_slot_perks(runtime_levels) -> int`:
  runtime_skill_levels에서 level>0이고 `is_slot_consuming_perk(get_perk_data(id))`
  인 distinct perk_id 수. (unlock/instant/lingpet/gold는 카운트 제외.)
- 상수 `PERK_SLOT_LIMIT := 6`.

## 경로별 처리

### ① 퍽 오퍼 게이팅 (`runtime_perk_catalog.get_choices`)
- `_filter_unlock_slot_budget`와 동일 패턴의 **`_filter_perk_slot_budget`** 신설,
  `get_choices` 체인에 추가(unlock 필터 근처).
- 로직: `count_owned_slot_perks >= PERK_SLOT_LIMIT`이면, choices에서 **슬롯 소모
  퍽 중 미보유(level 0)** 항목 제거. 보유 슬롯 퍽(레벨업)·비소모 퍽은 유지.
- 이미 6 초과인 런(S7 이전 획득)도 필터가 자연히 신규만 차단(제거 아님).

### ② 신화퍽 그랜트 (S5a `mythic_perk_grant_helper`)
- 신화퍽도 슬롯 소모이므로, 상자/보물 신화퍽 그랜트 시 **슬롯이 가득 차 있으면
  (신규 신화퍽이 7번째가 됨) 신화퍽 지급 대신 스타포인트 폴백**.
- 미보유 신화퍽 픽 전에 슬롯 여유 확인: `count_owned_slot_perks < PERK_SLOT_LIMIT`
  일 때만 신규 신화퍽 지급, 아니면 스타포인트(1~3). (신화퍽은 max_level 1이라
  레벨업 없음 → 가득 차면 무조건 SP.)

### ③ 슬롯 현황 UI
- 퍽 선택 모달 + TAB 퍽 패널에 **"슬롯 X/6"** 표시(보유 슬롯 퍽 수 / 6).
- 6/6이면 "슬롯 가득 참 — 보유 퍽 강화만 제시" 류의 짧은 안내(기존 UI 톤 준수).
- 슬롯을 차지한 퍽 목록/그리드가 이미 있으면 그 위에 카운터만 얹는 방향. 신규
  위젯보다 기존 퍽 표시 경로 재사용.

## 범위 제외

- 슬롯 확장 메커니즘(common_expansion → 퍽슬롯+1 등, §6 재설계 — 별도 결정)
- 스왑/교체 다이얼로그(VS식은 스왑 없음)
- unlock 5구슬 예산 변경(기존 UNLOCK_SLOT_BUDGET 그대로)
- 세이브 마이그레이션(S5 별도)
- 슬롯 수 6 외 튜닝(D1 확정치)

## 스모크 (신설: `godot/tests/perk_slot_limit_smoke.gd`)

- [ ] 보유 슬롯 퍽 5개 → get_choices에 신규 슬롯 퍽 제시됨
- [ ] 보유 슬롯 퍽 6개 → 신규 슬롯 퍽 0건, 보유 슬롯 퍽 레벨업은 제시
- [ ] 6개 상태에서도 instant/unlock(예산 내)/lingpet/gold 퍽은 정상 제시
- [ ] `is_slot_consuming_perk`: 일반퍽·신화퍽 true / unlock_*·instant·lingpet·gold
      false (대표 각 1개 이상)
- [ ] count: unlock/instant/lingpet 보유는 슬롯 카운트에 미포함
- [ ] 신화퍽 그랜트: 슬롯 5개→신규 신화퍽 지급 / 6개→스타포인트 폴백
- [ ] (있으면) 슬롯 카운터 UI 데이터가 X/6 정확
- [ ] 반증검증: 필터 게이트 임시 제거 시 "6개에서 신규 미제시" 레그 RED

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. `_filter_perk_slot_budget` 호출을 임시 제거 → "6개 보유 시 신규 슬롯 퍽
   미제시" 레그 RED → 복원
2. `is_slot_consuming_perk`가 unlock_*도 true 반환하게 임시 변경 → "unlock은 슬롯
   카운트 미포함" 레그 RED → 복원

## 트랩 노트

- 슬롯 카운트는 **distinct perk_id**(중복 방지). 레벨업은 슬롯 추가 소모 아님.
- CONVERTED_MYTHIC_PERKS는 get_choices 미노출(S2a) — 오퍼 게이팅 대상은 아니나
  **카운트에는 포함**(보유 신화퍽이 슬롯 차지). 신화퍽 그랜트 경로가 슬롯을
  존중해야 함(②).
- flag OFF: 개편 전 아이템 체제라 "퍽 슬롯" 개념이 라이브 아님. 슬롯 필터는
  flag ON에서만 의미 — `PerkConversionFlags.is_enabled()` 게이트 안에 두거나,
  카운트가 0이라 자연 무영향인지 확인(전환 퍽 미보유 시 무해). 기존 퍽 스모크
  회귀 없게.
- 기존 `_filter_unlock_slot_budget`와 순서/상호작용 확인(둘 다 필터 — 슬롯
  필터가 unlock을 잘못 제거하지 않게, unlock은 비소모).
- 핫패스 아님(오퍼 생성은 선택 시 1회). owner set() 스키마 트랩 주의(신규 owner
  키 필요 시 중단·보고). UTF-8 BOM 금지, `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 슬롯 판정/카운트/필터 지점, (2) get_choices 게이팅 + 신화퍽
그랜트 슬롯 존중 배선, (3) 슬롯 UI(X/6) 표시 + 스크린샷, (4) 신설 스모크 결과
원문, (5) 반증검증 2건 RED→GREEN, (6) flag OFF/기존 퍽 회귀 무변화 자가 확인,
(7) 이탈/가정.
