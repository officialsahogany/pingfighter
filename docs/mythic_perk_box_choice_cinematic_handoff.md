# 코덱스 핸드오프 — 신화퍽 확정상자 → 신화퍽 3택 셀렉션 → 선택 시 획득 시네마틱

발주: 2026-07-08. **피벗**: 직전 슬라이스(그랜트 시 시네마틱, 배선완료·미커밋)를
"상자 오픈 → 퍽 선택 모달에 **신화퍽만 3장** → 클릭 → 시네마틱"으로 변경.
S5a에서 후속 폴리시로 미뤘던 신화 3택 셀렉션 UI를 당김.
Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 직전 슬라이스 처분 (배선완료분 재사용)

| 산출물 | 처분 |
|---|---|
| v2 시네마틱 텍스트 레인(`reveal_description` 게이트) | **유지** ✓ |
| 퍽 시트 프리웜(cinematic_runtime) | **유지** ✓ |
| 리졸버 item_data 빌더(`_try_start_mythic_perk_acquisition_cinematic` + `_get_runtime_perk_data`/`_get_reveal_description_from_perk_data`/`_texture_path_exists`) | **이사** → `mythic_perk_grant_helper.gd`의 공용 static (`try_start_acquisition_cinematic(perk_id, owner, registry, pickup_position=...)`) |
| 리졸버 `_grant_mythic_perk_reward`의 그랜트-시 트리거 | **제거** (아래 단일 트리거로 대체 — 이중발동 방지, §트리거) |
| 신설 스모크 | **개정** (3택 플로우 기준으로 레그 교체) |

## 새 플로우

1. **상자 롤**: `_roll_mythic_perk_reward` — 열린 슬롯 + 미보유 신화퍽 ≥1이면
   신규 타입 **`REWARD_MYTHIC_PERK_CHOICE`** 반환(사전 perk_id 픽 없음 — 선택으로
   이동). 폴백(슬롯가득/전부보유)은 기존 SP 그대로. guaranteed + 가중치 mythic
   레인 **셋 다** 이 타입(전부 `_roll_mythic_perk_reward` 수렴이라 자동).
2. **그랜트(=초이스 오픈)**: `grant_rewards`의 새 타입 분기 → **신화-only 초이스
   오픈**. 결과화면 SP 초이스 인프라 미러(`stage_clear_result_starpoint_choice_open_data.
   open_deferred_starpoint_choice` 패턴 — 같은 모달·오디오·sync가 결과화면에서
   이미 작동).
3. **선택(클릭)**: 기존 `apply_choice` → 신화퍽 Lv1 그랜트(S5a 검증 경로) →
   **시네마틱 재생**(퍽 애니시트+이름+설명 — 직전 슬라이스 빌더 재사용).

## 배선

### ① 신화-only 초이스 오픈 (`runtime_perk_state.open_mythic_perk_choice` 신설)
```
func open_mythic_perk_choice(count: int, owner: Object, registry: Object, catalog: Object) -> bool:
    후보 = CONVERTED_MYTHIC_PERKS 중 runtime_skill_levels[id]==0 (character_restriction 준수)
    if 후보.is_empty(): return false          # 호출측이 SP 폴백
    후보.shuffle(); 상위 min(count, 후보수)장
    current_choices = 각각 catalog의 choice dict 빌드(level 0→1, localize 경유
        — get_perk_data가 이미 localize_perk_data 경유임을 확인함)
    choice_active = true; pending_skill_choices += 1 (완료 흐름이 감소 — 기존 계약 유지)
    current_choice_context = {"source": "result_box_mythic_choice", "mythic_box_choice": true}
    return true
```
- 3장 미만(미보유 1~2종)이면 있는 만큼. 카드 렌더는 기존 초이스 모달 그대로
  (신화 애니 아이콘은 PERK_SHEET_PATHS로 이미 렌더 가능).
- **골드변환/필러 미포함** — 순수 신화 카드만(이 모달은 보상 소비형).

### ② 리졸버 (`stage_clear_reward_resolver`)
- `REWARD_MYTHIC_PERK_CHOICE` const + `_roll_mythic_perk_reward` 타입 전환.
- `grant_rewards` 분기: 새 타입 → `open_mythic_perk_choice(3, ...)` 성공 시
  요약 카운트(예 `mythic_perk_choice_opened`), 실패(후보0) 시 SP 폴백 그랜트.
- 기존 `REWARD_MYTHIC_PERK` 직접그랜트 분기는 **잔존 호환**으로 유지(pending 보상
  등) — 단 그랜트-시 시네마틱 트리거는 제거(아래 단일 지점이 커버).
- 결과화면 sync: SP 초이스가 쓰는 `sync_box_perk_choice_rewards`가 선택된 퍽을
  상자 보상 표시로 되돌리는지 확인 — 신화 초이스도 같은 sync에 편승(source 키로
  구분 가능). 안 되면 동일 패턴 최소 확장.

### ③ 시네마틱 트리거 — **apply_choice 성공 경로 단일 지점**
- `apply_choice`(또는 모듈화된 apply 완료 흐름)에서 **choice `rarity=="mythic"` &&
  그랜트 성공** 시 `MythicPerkGrantHelper.try_start_acquisition_cinematic(perk_id,
  owner, registry)` 호출. registry/owner null이면 조용히 스킵.
- **이중발동 금지가 이 설계의 핵심**: `MythicPerkGrantHelper.grant_reward`(직접
  그랜트)도 내부적으로 apply_choice를 경유하므로, 리졸버 그랜트-시 트리거를
  남겨두면 직접그랜트 경로에서 2회 재생됨 → 반드시 제거하고 apply 지점 하나만.
- **의도된 파급(보고만, 막지 말 것)**: 이 단일 지점은 ①보물탐색 신화퍽(전투 중,
  helper.grant_reward→apply_choice) ②향후 신화 1% 오퍼 선택 ③F1 디벅 신화 그랜트
  에도 시네마틱을 재생 — 구 신화아이템 필드픽업 시네마틱과 패리티(전투 중 pause는
  기존 mythic pause 분기 재사용, 신규 pause 분기 추가 금지). 사용자 QA 항목으로 명시.

### ④ 슬롯 가드
- 상자 롤 시점 `has_open_perk_slot` 체크(기존) 유지. 오픈 시점 재확인 1회(같은
  결과화면에서 SP 초이스로 슬롯 퍽이 새로 찼을 수 있음) — 가득이면 SP 폴백.
- 신화 3택 모달 자체는 슬롯 1개만 소모(선택 1장) — S7 카운트에 자동 반영.

## 범위 제외
- 신화 1% 오퍼(별개 미배선 슬라이스 — `docs/mythic_perk_offer_chance_handoff.md`).
  단 ③의 트리거가 미래에 그 선택도 자동 커버.
- 3택 리롤/스킵 버튼, 신화 카드 전용 스타일링(기존 카드 UI 그대로 — 폴리시 후속).
- flag OFF(신화 아이템 경로 무변경 — v2 텍스트 레인 additive 게이트 유지).

## 스모크 (개정: `mythic_perk_acquisition_cinematic_smoke.gd`)
- [ ] flag ON + 상자 mythic 롤 → `REWARD_MYTHIC_PERK_CHOICE` 타입
- [ ] 그랜트 → choice_active true + current_choices 전원 rarity=="mythic" + 미보유만
      + ≤3장 + 골드/필러 0
- [ ] 선택(apply) → runtime_skill_levels[선택 id]==1 + **cinematic active** +
      스냅샷 name=퍽 이름
- [ ] 슬롯가득/전부보유 → SP 폴백(초이스 미오픈·시네마틱 미발동)
- [ ] **이중발동 방지**: helper.grant_reward 직접그랜트 1회 → 시네마틱 시작 호출
      **정확히 1회**(카운팅 더블/스파이로 검증)
- [ ] 미보유 1종뿐 → 1장 초이스 정상
- [ ] 아이템 경로 회귀(reveal_description 없는 item_data → 텍스트 레인 비활성) 유지
- [ ] flag OFF 무변경

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. 신화-only 필터 임시 제거(일반 퍽도 후보) → "전원 mythic" 레그 RED → 복원
2. apply 지점 시네마틱 트리거 임시 제거 → "선택 시 cinematic active" 레그 RED → 복원
3. 리졸버 그랜트-시 트리거를 임시 복원(이중화) → "정확히 1회" 레그 RED → 복원

## 트랩 노트
- **이중발동**(③) — 이 슬라이스 최대 리스크. 트리거는 apply 단일 지점, 리졸버
  그랜트-시 트리거 제거 필수.
- pending_skill_choices 계약: 신화 초이스도 +1/완료 -1 대칭 유지(모달 닫힘 흐름
  재사용) — 비대칭이면 SP 초이스가 영영 안 열리거나 유령 모달.
- 초이스 오픈은 결과화면 한정 아님(state는 공용) — 단 이번 호출자는 리졸버(결과
  화면)뿐. 전투 중 오픈은 미지원 경로로 남김(문제 없음).
- 모달 중 결과화면 입력/박스 오픈 차단은 기존 SP 초이스와 동일 흐름에 편승 —
  `is_runtime_perk_choice_active` 게이트 재사용 확인.
- 핫패스 아님. owner set() 스키마 무관. UTF-8 BOM 금지, `.agents/skills/` 미러 금지.
- **커밋**: 리졸버/state/catalog 모두 WIP 스택과 인터리브 가능 — 분리 불가 시
  검증완료·미커밋 보고(체크포인트 흡수). 신설/개정 스모크는 단독 커밋 가능.

## 완료 보고 형식
(1) 변경 지점(오픈 API + 리졸버 분기 + apply 트리거 + 헬퍼 이사 + 리졸버 트리거
제거), (2) 개정 스모크 결과 원문, (3) 반증검증 3건 RED→GREEN, (4) 이중발동 1회
검증 + SP폴백 + flag OFF 자가확인, (5) 결과화면 실플레이 캡처(3택 모달 + 선택 후
시네마틱), (6) 이탈/가정(특히 보물탐색/디벅 시네마틱 파급 확인 결과).
