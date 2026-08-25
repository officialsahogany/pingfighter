# 지시문 W1 — [P1] 무공 슬롯 상한이 보상 화면에서 무시된다

- **발행**: 관제탑 2026-08-25. 기준 HEAD `a325ffc29`. 락스텝 243/243.
- **격리 워크트리**: `D:\codex_tmp\bosspong_slotlimit_a325` (브랜치
  `codex/fb7-perk-slot-limit-20260825`).
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기.
- ⚠D: 여유 공간 부족 — 워크트리 1개만, 작업 후 제거.

## 사용자 관측

> 무공슬롯이 5/6개로 1개 남은 상태에서 승리보상 카드선택화면에서 4개의
> 무공 중 1개를 선택하면 6/6이 되어 더 이상 추가할 수 없어야 하는데,
> 슬롯이 가득 차도 최대 슬롯을 무시하고 무공이 계속 추가됨.

## 실측 확정 (관제탑 프로브)

**진범**: 탑 승리보상 카드선택이 상한을 **오퍼 생성 시점에 1회만, 그것도
후보별 독립 판정으로** 검사하고 **구매 시점에는 전혀 검사하지 않는다.**

1. `runtime_perk_catalog.gd:2142` `_filter_perk_slot_budget`이
   `occupied_slots`를 **루프 바깥에서 한 번** 계산하고 후보마다
   `occupied + extra <= limit`을 **독립 판정**한다. 5/6이면 신규 무공
   6종이 **전부** 통과한다(누적 아님).
2. 그 카드들이 `tower_reward_pick_offer_builder.gd:26` `CARD_COUNT := 4`로
   보드가 되고, `tower_reward_pick_state.gd:78` `start()`에서 **한 번만**
   생성돼 고정된다. 구매로 슬롯이 차도 보드는 재생성되지 않는다.
3. ★`tower_reward_pick_state.gd:372` `_purchase()`가 **인덱스·
   `spent_flags`·무혼 통화만** 검사한다. 슬롯 잔여 검사가 없다.
4. `:422` `_grant_choice()` → `runtime_state.apply_choice()` →
   `runtime_perk_choice_apply_flow.gd:171~281` 전 구간에 슬롯 게이트가
   **한 줄도 없다.**
5. `:264` `reward_pick_enabled`도 "미구매 AND 살 돈 있음"만 본다 —
   가득 차도 카드가 밝게 켜진 채 클릭된다.

→ 5/6 진입 후 4장 전부 구매 가능 → **9/6**. 사용자 관측과 정확히 일치.

**상수는 정상이다.** `BASE_PERK_SLOT_LIMIT := 6`(`:19`),
`MAX_PERK_SLOT_LIMIT := 7`(융합 부산물 `meridian_expand` 보유 시),
표시(N/M)와 강제가 **같은** `get_perk_slot_limit`/`get_perk_slot_status`
(`:1658`/`:1667`)를 읽는다. 표시-강제 불일치는 없다.

**의도된 동작도 이미 확정돼 있다.**
`docs/perk_slot_expansion_to_fusion_byproduct_handoff.md:20~23`에 사용자
확정으로 박혀 있다 — "슬롯 가득 = **신규 퍽 차단**(보유 업그레이드 예약은
그대로 작동, 소프트락 아님). 융합의 2→1 환급이 유일한 슬롯 해방 수단."

## 다른 획득 경로 (전수 조사됨)

| 경로 | 오퍼측 | 적용측 | 판정 |
| --- | --- | --- | --- |
| 전투 중 퍽 선택 모달(3장) | ✅ `:1339` | ❌ | 안전(모달 1회=1장, 오픈마다 재계산) |
| **탑 승리보상(4장)** | ⚠️1회·독립판정 | ❌ | **★진범** |
| **탑 타락한 승려(6장)** | ❌ 술어에 슬롯 항 자체가 없음 | ❌ | **더 심한 구멍** |
| 탑 시작 카드 | ❌ | ❌ | 런 시작=0슬롯이라 실질 무해, 계약은 부재 |
| 신화 퍽 보상 | ✅ | ✅ `mythic_perk_grant_helper.gd:278` | **안전 — 수리 선례** |
| 수련장·수호의 샘터 | n/a(비소모) | n/a | 안전 |
| 달인의 영약 | 보유 퍽만 | ❌ | 부차 위험(아래 4번) |

## 작업

1. ★**적용측 게이트 신설**이 본체다. `mythic_perk_grant_helper.gd:278`을
   선례로 삼아, 슬롯을 소모하는 퍽 적용 직전에 용량을 검사하고 초과면
   거절하라. 게이트는 **한 곳**에 두고 보상 보드·타락한 승려가 모두
   그것을 통과하게 하라.
2. ★**"신규 여부"가 아니라 델타로 판정하라.**
   `runtime_perk_catalog.gd:1596` `get_slot_cost_for_level`에서
   `dash_amplification`은 **레벨당 슬롯을 1칸씩** 먹는다. 따라서 게이트는
   `next_cost - current_cost <= limit - occupied`여야 한다. 레벨업도
   초과할 수 있다.
3. **구매 게이트**: `tower_reward_pick_state.gd:372` `_purchase()`에
   슬롯 잔여 검사를 추가하고, `:264` `reward_pick_enabled`에도 용량 항을
   넣어 **가득 찬 카드가 비활성으로 보이게** 하라. 비활성 표현 계통은
   이미 있다(`runtime_perk_overlay_renderer.gd:1773`, `:4055`의 "돈 부족"
   회색 처리) — 새 표현을 발명하지 말고 그 계통에 사유만 추가하라.
4. **오퍼측 누적 판정**: `_filter_perk_slot_budget`이 후보를 독립 판정하는
   것 자체는 오퍼 단계에선 합리적이다(어느 하나만 살 수도 있으므로).
   다만 보드가 고정된다는 점을 감안해, **구매마다 남은 카드의 활성
   상태를 재평가**하는 것이 3번의 목적이다. 오퍼 필터를 누적으로 바꾸면
   "살 수 있었던 카드가 아예 안 나오는" 역효과가 나므로 **바꾸지 마라.**
5. **타락한 승려**(`tower_ascent_fallen_monk_node.gd:296`, `:523`):
   `tower_ascent_perk_candidate_policy.gd:28` `is_mugong_candidate`에
   슬롯 항이 없고 적용측도 직행이라 구멍이 더 넓다. 1번의 공용 게이트로
   같이 막고, 오퍼측에도 용량 항을 추가하라.
6. **달인의 영약**: 보유 퍽 레벨업만 하지만 `dash_amplification` 때문에
   초과 가능하다. 2번의 델타 판정으로 자동 커버되는지 확인하고, 안 되면
   같은 게이트를 태워라.

## ⚠씰 상태 — `perk_slot_limit_smoke`는 지금 이 계약을 전혀 지키지 않는다

이 씰은 CI·pre-push 등재인데 **RED이고, 그 RED는 이 버그와 무관하다.**
게다가 **상한 단언들이 공허 GREEN**이다(GRT-031/040 계열).

- **원인 A (11건)**: `TOWER_ASCENT_VERTICAL_SLICE=0`으로 돌리면 사라진다.
  `512aed0ce`(8/22, 탑 등정을 기본 진행으로)가
  `DEFAULT_VERTICAL_SLICE_ENABLED`를 true로 뒤집었고,
  `tower_ascent_unlock_filter.gd:22`가 registry 없거나
  `tower_ascent_unlock_store`가 없으면 **fail-closed(false)** 다.
  씰 픽스처가 registry=null / store 없는 FakeRegistry를 쓰므로
  `get_choices()`가 **빈 배열**을 반환한다.
- **원인 B (10건, 플래그 OFF에서도 잔존)**: 씰의 융합 픽스처
  `_build_meridian_expanded_state`가 `item_luck: 5`를 쓰는데,
  `6cf178b55`(8/22, 무공 5성→3성)가 `item_luck.max_level`을 3으로 낮췄다.
  `perk_fusion_catalog.gd:151` `is_candidate`가 `base_level != max_level`이면
  탈락시켜 `commit_perk_fusion`이 `{}`를 반환 → 기맥확장 레그 연쇄 RED.
- ★**공허 GREEN**: "with six occupied slots, new slot-consuming perks should
  be filtered out"과 "9/7 overoccupied state must block a new slot-consuming
  perk" 둘 다 **빈 배열이라 무조건 통과**한다.

7. **씰 두 원인을 먼저 고쳐라.** 픽스처에 `tower_ascent_unlock_store`를
   주입하고 `item_luck` 레벨을 3으로 맞춰라. 그래야 상한 단언이 실제로
   돌기 시작한다. **단언을 지우지 마라** — 직전 라운드에 그 방식으로 반려된
   사례가 있다.

## 씰

- **핵심 재현 레그**: 5/6 상태에서 보상 보드 4장을 **순서대로 전부 구매
  시도** → 1장만 성사되고 나머지 3장은 거절되며 최종이 6/6임을 단언.
  RED 반증: 게이트를 되돌리면 9/6이 된다.
- **델타 레그**: `dash_amplification` 레벨업이 남은 슬롯보다 크면 거절.
- **비활성 표시 레그**: 가득 찬 상태에서 남은 카드의 `reward_pick_enabled`가
  false이고 사유가 "돈 부족"이 아니라 슬롯임을 단언.
- **타락한 승려 레그**: 6장 보드에서 같은 계약이 성립.
- **소프트락 아님 레그**: 가득 찬 상태에서도 **보유 퍽 레벨업 카드와 융합
  카드는 여전히 구매 가능**(정본 계약).
- `perk_slot_limit_smoke` 두 원인 수리 후 GREEN + 상한 단언이 **빈 배열이
  아닌 실 후보**로 돌아감을 종단선으로 증명.

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 픽셀 QA(가득 찬 보상 화면 1장, 비활성 표현 확인).
보고=워크트리·커밋 해시·씰 종단선 원문·경로별 게이트 적용 표·미해결.
