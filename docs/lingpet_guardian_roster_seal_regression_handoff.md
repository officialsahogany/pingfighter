# 로스터 1마리 개편 검수 지적 핸드오프 (Codex 실행용) — 죽은 씰 레그 8종 + 미봉인 계약

작성 2026-07-29. 대상 커밋 = `b0de78475` (§4 로스터 1마리 개편).
**기능 구현 자체는 검수 승인** — 이 문서는 씰 커버리지 결손만 다룬다.
가드레일·씰 실행 규정 기존과 동일.

## 1. 문제 (Claude 검수 실측)

`b0de78475`가 `_verify_*` 호출 **12개를 제거**하면서 **함수 본문은 파일에
남겼다.** 결과:

- `lingpet_egg_runtime_smoke.gd`에 **죽은 함수 8개** 잔존
  (`_verify_lingpet_battle_slot_model` 69줄 등). 호출이 없어 단언이 한 줄도
  실행되지 않으며, 그 안에는 **이미 삭제된 API 호출**
  (`runtime.cycle_lingpet_slot(...)`, 3024행)과 **삭제된 API의 존재를
  단언하는 줄**(`find("func cycle_lingpet_slot") >= 0`, 3047행)이 들어 있다.
  → 호출을 되살리는 순간 SCRIPT ERROR + RED가 되는 시한폭탄이고,
  `lingpet_one_guardian_roster_smoke:172`의 정반대 단언
  (`find("func cycle_lingpet_slot") < 0`)과 **파일 안에서 모순**한다.
- 씰은 GREEN으로 보이지만 그 레그들은 **공허**다(리포 표준 공허-GREEN 트랩).

죽은 함수 목록 (`lingpet_egg_runtime_smoke.gd`):
`_verify_lingpet_egg_deploys_while_companion_active`,
`_verify_item_egg_hatch_rolls_loadout`,
`_verify_lingpet_egg_overflow_replace_release_choice`,
`_verify_lingpet_egg_overflow_reset_resolves_to_release`,
`_verify_lingpet_battle_slot_model`,
`_verify_lingpet_skill_cooldown_survives_slot_switch`,
`_verify_lingpet_slot_switch_clears_owner_locked_skill_flags`,
`_verify_lingpet_skill_waits_for_switch_transition`

같은 커밋에서 호출이 제거된 다른 파일의 레그도 함께 점검할 것:
`_verify_slot_cycle_directions`,
`_verify_lingpet_cycle_key_avoids_item_number_keys`,
`_verify_duration_owner_pet_switch_refill_and_cap`,
`_verify_main_egg_full_roster_hatch_routes_to_overflow`.

## 2. 처리 계약 — 폐기 / 재조준 분류

각 죽은 레그를 **폐기(본문 삭제)** 또는 **재조준(1마리 계약으로 고쳐
되살림)** 으로 분류하고, 분류 근거를 보고서에 표로 남긴다.
**본문만 남기는 현재 상태는 금지** — 어느 쪽이든 결론을 낸다.

Claude 1차 판단(참고, 최종 판단은 코드 확인 후 Codex가):

| 레그 | 권고 | 근거 |
|---|---|---|
| battle_slot_model / skill_cooldown_survives_slot_switch / slot_switch_clears_owner_locked_skill_flags / skill_waits_for_switch_transition / slot_cycle_directions / cycle_key_avoids_item_number_keys | **폐기** | 3슬롯·순환 전용. 1마리 체제에서 대상 소멸 |
| **egg_deploys_while_companion_active** | **재조준 필수** | "수호령 활성 중에도 알이 필드에 배치된다"는 §4의 **핵심 전제**다. 1마리 개편으로 오히려 더 중요해졌는데 씰이 죽었다 |
| **item_egg_hatch_rolls_loadout** | **재조준 필수** | 부화 로드아웃 롤은 1마리 체제와 무관하게 유효. 죽으면 부화 롤 계약이 무봉인 |
| overflow_replace_release_choice / overflow_reset_resolves_to_release | **재조준** | "교체/방생" → **"교체/흡수"**로 재정의(리셋 기본 동작 포함 — 권고: 취소=흡수) |
| main_egg_full_roster_hatch_routes_to_overflow | **재조준** | 만석 개념이 "보유 1마리"로 바뀌었을 뿐 라우팅 계약은 유효 |
| **duration_owner_pet_switch_refill_and_cap** | **재조준 필수** | §3 참조 |

## 3. 미봉인 계약 — 교체 시 지속시간 유지 (§4-5)

핸드오프 §4-5의 확정 계약("교체 시 **런 공유 지속시간 풀은 유지**, 펫별
강화 버프는 초기화")을 단언하는 씰이 **현재 어디에도 없다**
(`lingpet_one_guardian_roster_smoke` / `duration_pool_owner` /
`duration_round_transition` 전수 확인, Claude 실측). 구 씰
`_verify_duration_owner_pet_switch_refill_and_cap`이 죽으면서 생긴 공백으로
보인다.

- 신규 또는 재조준 씰로 봉인할 것: **교체 실행 → `pool_current`/`pool_max`
  불변**(오버필 포함) + **펫별 reward_counts는 새 펫 기준 초기화** +
  **흡수 실행 시에도 풀 불변**.
- 반증 1회(풀 초기화를 in-place로 주입 → RED).

## 4. 완료 조건

- 죽은 `_verify_*` 본문 0건 (분류표대로 폐기 또는 되살림).
- 되살린 레그는 실제로 `_init`에서 호출되고 GREEN.
- `lingpet_egg_runtime_smoke` 안의 구 API 호출·존재 단언 제거 →
  `one_guardian_roster_smoke`와의 모순 해소.
- §3 지속시간 유지 계약 봉인 + 반증.
- 관련 씰 재실행 GREEN, 기존 기준선 악화 금지.

## 5. 보고 형식

커밋 해시 / 레그별 폐기·재조준 분류표와 근거 / 되살린 레그의 호출 확인 /
씰 원문·반증 / 미결·발견 사항.
