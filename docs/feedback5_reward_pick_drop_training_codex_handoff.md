# 지시문 R1 — 결과보상 카드에서 수련 제외 (초식·무공만)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `66d252511`. CI/pre-push 락스텝 237.
- **격리 워크트리**: `D:\codex_tmp\bosspong_rewardpick_66d2` (브랜치
  `codex/reward-pick-drop-training-20260825`). 진행 중 Q3/Q4/Q6 수정
  트랙과 파일 무겹침 — 병렬 가능.
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 사용자 확정 스펙

스테이지 클리어 결과보상 카드 화면에 현재 **초식·무공·수련** 3종이
등장한다. **수련 카드를 제외**하고 초식·무공만 나오게 한다.

## 실측 (관제탑)

`tower_reward_pick_offer_builder.gd`:
- `CARD_COUNT := 4`, 기본 풀은 `_build_basic_pool`(:214~)이 구성.
- 풀 = 수련 오퍼 빌더의 `stat_choices`(→`reward_pick_kind="training"`)
  + `mugong_choices`(→`"mugong"`) + 조건부 융합 카드 1장(`"fusion"`)
  + 별도 절세무공 승격 카드(`offer_lane="tower_reward_supreme"`).
- `:94` `if choices.size() != CARD_COUNT: return {...}` — **4장을 못
  채우면 오퍼 자체가 실패**한다. 수련을 빼면 풀이 급감하므로 이
  경로가 핵심 리스크다.

## 작업

1. `_build_basic_pool`에서 `stat_choices`(training) 수집을 제거.
   ⚠수련 카드의 비용/표시 경로(`resolve_basic_reward_pick_cost`의
   `kind == "training"` 분기 등)는 **죽은 분기가 되면 정리**하되,
   수련장 노드의 수련 오퍼는 **무관하니 절대 건드리지 말 것**
   (`tower_ascent_training_offer_builder`의 다른 OFFER_KIND 경로).
2. **풀 충족 보장**: 수련 제외 후에도 4장이 안정적으로 차야 한다.
   - 우선안: 수련 오퍼 빌더 호출의 `OFFER_KIND_MIXED_REWARD` 구성을
     무공 위주로 늘려 무공 후보 수를 확보(빌더가 지원하면 카드 수
     인자/구성 상수를 정본에서 조정).
   - 대안(우선안 불가 시): 무공 후보 부족 시 `CARD_COUNT`를 가용
     수만큼 축소(3장/2장)하고 오퍼 실패로 떨어지지 않게 — **오퍼
     실패는 보상 화면 자체를 비우므로 금지**.
   - 어느 쪽이든 128시드 규모로 "4장 충족률"과 "실패 0" 실측 보고.
3. 무공 후보가 고갈되는 후반(전 무공 만렙 등) 시나리오 확인 —
   기존 saturated/fallback 경로가 수련 없이도 성립하는지 점검.
4. 비용 밸런스 메모: 수련 1무혼 카드가 사라져 평균 구매가가 오른다
   (무공 2·융합/절세 상위). 수치 변경은 이번 스코프 밖 — **체감
   판단용으로 실측 평균가만 보고**.

## 씰

- 오퍼 구성 레그: 생성된 카드에 `reward_pick_kind == "training"`가
  0건 + 초식/무공 계열이 존재 단언(실 오퍼 빌더 관통).
- 충족 레그: 128시드에서 카드 수 == CARD_COUNT(또는 축소 정책 채택
  시 정책대로) · 오퍼 실패 0 · 무공 고갈 픽스처에서도 화면이 비지
  않음.
- RED 반증: 수련 수집을 되살린 픽스처가 training 0건 단언에 실패.
- 기존 락스텝 유지: `tower_reward_pick_smoke`,
  `tower_victory_margin_muhon_reward_smoke`(보상 화면 표시 계약),
  수련장 노드 씰 전부 GREEN.
- 픽셀 QA: 결과보상 화면 캡처 1장(수련 카드 부재·4장 구성).

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처. 보고=워크트리·커밋 해시·씰 종단선 원문·
충족률 실측(4장 비율/실패 수)·평균 구매가·캡처 경로·미해결.
