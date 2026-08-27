# 지시문 Y8 — 비전 20% 확률화 + 승리 보상에 초식 편입

- **발행**: 관제탑 2026-08-27. 기준선 = 본 트리 **`dc1849726`**.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- 소유 파일: `godot/scripts/tower_ascent/tower_reward_pick_offer_builder.gd`

## 사용자 확정 결정

1. **비전 초식은 클리어 시 20% 확률로만 드랍**한다. (현재 조건 충족 시 100%)
2. **승리 결과 보상에 무공만이 아니라 초식도 가끔 나타나야 한다.**

---

## 현황 (관제탑 확정 — 재조사 금지)

### 비전은 확률이 아니라 관문 통과제다

`tower_reward_pick_offer_builder.gd:62~70` 에서 **주사위 없이, 가장 먼저**
후보에 올라간다. `rng` 는 그 아래 `supreme` 굴림에만 쓰인다.

여섯 관문을 전부 통과하면 100%, 하나라도 걸리면 0%다.

1. `_owner_boss_identity_matches_slot` 2. `skipped_boss_ids`
3. `burned_vision_boss_ids` 4. `is_owned`
5. `build_vision_choice` 비어 있지 않음 6. `is_content_unlocked`

### 보상 카드에 초식은 구조적으로 없다

오퍼 빌더가 만드는 종류는 다섯뿐이다.

| 종류 | 비용 |
|---|---|
| `mugong` | `TEMP_MUGONG_COST` 2 |
| `fusion` | 3 |
| `dash_amplification` | 3 |
| `vision` | 3 |
| `supreme` | 5 |

`CARD_COUNT := 4`. `reward_pick_kind` 기본값도 `"mugong"` 이다.

★**초식이 무공으로 잘못 라벨링된 것이 아니다.**
`tower_ascent_training_offer_builder.gd` 의 `_build_mugong_choices` 가
`_perk_candidate_policy.is_mugong_candidate(...)` 로 **명시 필터링**하므로
초식 후보는 애초에 풀에 들어오지 않는다.

★**형제 분류기가 이미 있다** —
`tower_ascent_perk_candidate_policy.gd` 의 `is_chosik_candidate`.
시작 카드 빌더(`tower_start_card_offer_builder.gd:60`)가 그것을 쓴다.
**새로 만들지 말고 재사용하라.**

---

## 요구 1 — 비전 20%

1. 여섯 관문을 통과한 뒤 **20% 굴림**을 추가하라. 상수로 빼라
   (`TEMP_VISION_DROP_CHANCE := 0.20` 등). 리터럴 금지.
2. ⚠**`OFFER_VERSION` 을 올려라.** 현재 `"tower_reward_pick_v1"`.
   RNG 소비 순서가 바뀌어 기존 시드의 모든 오퍼가 달라진다. 안 올리면
   저장된 런과 어긋난다.
3. ⚠**굴림 순서를 명확히 하라.** 지금은 비전이 `rng` 를 전혀 안 쓰고
   `supreme` 이 첫 소비자다. 비전 굴림을 앞에 넣으면 supreme 의 값이
   바뀐다. **의도된 변화이나 보고에 명시하라.**
4. **결정성 유지.** 시드는 `hash(resolution_id:boss_slot_id:OFFER_VERSION)` 로
   조우마다 고정이다. 화면을 다시 열어도 같은 결과여야 한다
   (재굴림으로 세이브스커밍이 되면 안 된다). **씰로 증명하라.**
5. **탈락 시 빈자리 처리를 보고하라.** 비전이 떨어지면 카드 4장 중 한 자리가
   비고 기본 풀이 더 채워진다. `supreme_rolled = choices.size() < CARD_COUNT`
   조건에도 영향이 간다. **전후 카드 구성 분포를 표로 내라.**

### ★사용자가 알아야 할 결과 — 반드시 보고에 적어라

각 보스는 한 런에서 한 번만 잡는다. 탈락한 굴림은 기록되지 않지만 재도전
기회도 없다. 따라서 **실질적으로 런당 보스당 20%** 다.
현재 100%에서 5분의 1로 줄어드는 것이며, 비전 수집 체감이 크게 달라진다.
**의도대로인지 확인만 하고 임의로 수치를 바꾸지 마라.**

---

## 요구 2 — 초식을 보상 카드에

1. `is_chosik_candidate` 를 써서 **초식 후보 풀을 만들어라.**
   ⚠**소유자 판정**: `tower_ascent_training_offer_builder` 가 생성 풀을
   소유한다. 거기에 `chosik_choices` 를 형제로 추가할지, 보상 빌더에서
   거를지 판정하고 근거를 보고하라. **`_build_mugong_choices` 의 무공
   필터링을 느슨하게 만들지 마라** — 수련 노드 등 다른 소비자가 있다.
2. **빈도는 상수 하나로 빼라.**
   **관제탑 제안값 = `TEMP_REWARD_CHOSIK_CHANCE := 0.25`**
   (카드 4장 중 한 자리가 초식이 될 확률). "가끔" 의 해석이며
   **사용자 확정 전 잠정값이다.** 착지 시 조정 가능하도록 한 줄로 유지하라.
3. **무공을 전멸시키지 마라.** 초식이 여러 자리를 먹으면 안 된다.
   **최대 1자리**를 기본으로 하고, 그 이상이 필요하면 근거와 함께 제안하라.
4. 비용을 정하라. 기존 표에 맞춰 제안하고 근거를 보고하라
   (무공 2 / 융합·활주·비전 3 / 절세 5).

### ★★최우선 위험 — 초식은 오브 슬롯을 소모한다

관제탑 확정 사실: **`unlocks_skill` = 슬롯 미소모는 무공 슬롯 한정이다.
초식 오브 슬롯(5칸)은 실제로 소모한다.**

따라서 **슬롯이 만석일 때의 동선**이 필요하다. 비전은 이미 그 처리를 갖고
있다 — `vision_swap_required` + `get_shared_slot_swap_candidates`
(`_build_vision_choice` 하단).

⚠**같은 패턴이 초식에도 필요한지 판정해서 보고하라.**
**필요하다고 판단되면 임의로 만들지 말고 관제탑 판정을 기다려라.**
샘터 초식 교체창(X1, `guardian_spring_chosik_swap_input_router`)과 동선이
겹칠 수 있다. 두 교체 흐름이 충돌하면 안 된다.

### ★★두 번째 최우선 위험 — Y3 착지 슬롯 프리뷰

**Y3(`9680092b8`)이 방금 보상 호버의 착지 슬롯 프리뷰를 고쳤다.**
호버 시 "내 무공들 바로 오른쪽 빈 칸" 에 하이라이트가 뜬다.

⚠**초식 카드는 무공 슬롯이 아니라 초식 오브 슬롯에 착지한다.**
프리뷰가 무공 슬롯을 전제하고 있으면 **엉뚱한 패널을 강조**한다.

**초식 카드 호버 시 하이라이트가 어디에 뜨는지 실측하고 보고하라.**
잘못 뜨면 그것도 이번 범위다. `runtime_perk_overlay_renderer.gd` 의
`build_tower_reward_hover_slot_grid` 계열을 보라.

---

## 이미 있는 배선 (재구현 금지)

- `tower_card_absorption_target_resolver.gd:52`
  `reward_kind in ["chosik", "vision"]` — **보상 종류로 chosik 을 이미 받는다.**
- `tower_ascent_run_state.gd:325`·`:394`
  `picked_kind in ["chosik", "mugong"]` — 집계가 이미 둘을 함께 취급한다.
- `tower_ascent_settlement_state.gd:139` 정산 화면이 "초식" 행을 이미 센다.

**이 셋이 실제로 보상 경로에서 동작하는지 확인하고 보고하라.**
동작하면 그대로 두고, 안 하면 무엇이 빠졌는지 보고하라.

## 씰 요구

`godot/tests/tower_reward_pick_smoke.gd` (W4·Y3 영역, 812줄+)

1. ★**비전 20% 씰**: 굴림 오버라이드로 경계를 태워라. 0.19 → 등장,
   0.21 → 미등장. **확률 분포를 시드 다수로 재서 20%에 수렴하는지도 보라.**
2. ★**결정성 씰**: 같은 `resolution_id`+`boss_slot_id` 로 두 번 빌드해
   결과가 동일한지. 재굴림이 안 되는 것이 요구사항이다.
3. ★**초식 등장 씰**: 초식 카드가 나오는 시드에서 `reward_pick_kind` 가
   `"chosik"` 인지, **무공 자리가 전멸하지 않는지**.
4. **Y3 무회귀**: 기존 무공 위치 고정 레그가 그대로 GREEN 인지.
   초식 카드 호버 시 하이라이트 위치도 단언하라.
5. **반증**: 비전을 100%로, 초식을 0%로 되돌리면 각각 RED 가 되는지 확인하고
   원상복구하라.
6. **CI/pre-push 락스텝.** ⚠**현재 250/250 이다.** 통째 교체 금지.
   착지 전후 항목 집합을 `comm` 으로 대조해 **사라진 항목 0** 을 증명하라.

## 게이트·보고

포커스드 스모크(+반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
★**픽셀 QA**: 초식 카드가 뜬 보상 화면과 그 호버 하이라이트를 캡처하라.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs` 를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

## 보고

커밋 해시 · `OFFER_VERSION` 갱신 · 비전 굴림 위치와 supreme 영향 ·
**전후 카드 구성 분포표** · 초식 풀 소유자 판정 근거 ·
채택한 빈도·비용과 근거 · **초식 만석 시 교체 필요 여부 판정(구현 말고 판정)** ·
**초식 카드 호버 하이라이트 실측 위치** · 기존 배선 3종 동작 확인 ·
씰 종단선과 반증 · 픽셀 캡처 경로 · 미해결.

## 알려진 선재 RED (이 작업 탓 아님)

- 전체 경고 스캔 RED — 파스 오류 경로 테스트 17 + 도구 2.
- `tower_ascent_flow_owner_refactor_smoke` — 710줄 vs 500줄 예산.
- `tower_ascent_node_modal_shell_smoke` — outgoing candidate 개수 단언.
- ⚠**비전 매핑 공백 4슬롯 미결**: `floor_02_molewang` / `floor_02_arachne` /
  `floor_03_teddy_bear` / `floor_03_alice` 는 `VISION_UNLOCK_BY_BOSS_SLOT` 에
  항목이 없어 **20% 굴림 이전에 이미 0%** 다. 이번 범위 아니다.
