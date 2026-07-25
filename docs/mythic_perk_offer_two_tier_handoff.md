# 코덱스 핸드오프 — 인게임 신화 오퍼 2티어 (3% 1장 / 1% 잭팟 3장)

발주: 2026-07-08. 직전 슬라이스(신화 1% 단일 예약 — 배선완료·리뷰 PASS·미커밋)의
**델타 확장**. 결정: 인게임 일반 퍽 오퍼에서
- **3% 확률**: 오퍼 카드 중 **1장만** 신화퍽 (기존 단일 레인, 확률 1%→3%)
- **1% 확률**: 오퍼 **3장 전부** 신화퍽 (**잭팟**)

Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 설계 (확정 + 집행 결정)

- **롤 의미론 — 단일 randf 누적 밴드** (시임 결정성 유지):
  ```
  var roll := randf()
  if roll < jackpot_chance:            # 1% — 전 카드 신화
      <잭팟 레인>
  elif roll < jackpot_chance + single_chance:   # +3% — 1장 신화
      <단일 레인 (기존)>
  ```
  총 신화 등장 ≈ 4%/오퍼. 잭팟이 우선(중복 판정 없음).
- **시임 2개** (기존 `mythic_offer_chance` 대체):
  ```
  var mythic_single_offer_chance := 0.03
  var mythic_jackpot_offer_chance := 0.01
  ```
  헬퍼도 2값 반환으로 개정(예 `_get_mythic_offer_chances(runtime_levels) ->
  Dictionary {"single": .., "jackpot": ..}`) — 보물지도 후속(+N%p/Lv)이 여기에 1줄.
  기존 단일 시임/헬퍼는 잔존 금지(이름 교체 — 소스계약 스모크도 함께 갱신).
- **잭팟 구성**: 미보유 신화 셔플 **서로 다른 id** `min(target(≈3), 미보유수)`장을
  예약 티어로. **미보유 < 3이면 있는 만큼만 신화 + 나머지는 일반 풀 셔플로 채움**
  (오퍼는 항상 target장 유지 — 미보유 1이면 사실상 단일 레인과 동일). 미보유 0이면
  두 레인 모두 스킵(기존).
- **골드 카드**: 기존대로 target 밖 항상 append(잭팟이어도 골드는 별도 카드 — 무변경).
- **게이트 동일**: `is_enabled && has_open_perk_slot` — 두 레인 공통(가득이면 0%).
  선택은 1장이므로 슬롯 1개 여유면 잭팟도 유효.
- **링코어/보유업글 상호작용**: 예약 한도 차감식은 기존 그대로
  (`target − mythic_reserved.size() − owned.size()`) — 잭팟이면 신화가 target을
  다 먹어 링코어 예약이 그 오퍼에서 밀림(1% 희귀라 허용, 집행 결정). 보유업글
  예약은 full-slot 게이트라 상호배타(무변경).
- **선택 시**: 기존 apply_choice 경로 + v2 시네마틱 트리거(rarity mythic — 이미
  배선됨, 무변경). 잭팟에서도 1장 선택 → 나머지 신화 카드는 소멸(재롤 없음).

## 배선 (`runtime_perk_catalog.gd` — 기존 주입 블록 개정)

기존 `mythic_reserved` 블록을 2레인으로:
```
var mythic_reserved: Array = []
if PerkConversionFlags.is_enabled() and has_open_perk_slot(runtime_levels, _registry):
    var chances := _get_mythic_offer_chances(runtime_levels)
    var roll := randf()
    var mythic_count := 0
    if roll < float(chances.get("jackpot", 0.0)):
        mythic_count = target_choice_count            # 잭팟 — 전 카드
    elif roll < float(chances.get("jackpot", 0.0)) + float(chances.get("single", 0.0)):
        mythic_count = 1
    if mythic_count > 0:
        mythic_reserved = _build_unowned_mythic_choices(runtime_levels, normalized, mythic_count)
        # 서로 다른 미보유 id를 min(count, 미보유수)장 — 셔플 후 앞에서 절단.
        # 기존 _pick_random_unowned_mythic_perk_id 를 후보-리스트 빌더로 일반화.
```
- 이후 채움 순서·링코어 차감·owned-upgrade 블록은 **무변경**(mythic_reserved가
  1장이든 3장이든 기존 식이 그대로 동작).
- `_build_unowned_mythic_choices`: 기존 픽 헬퍼의 후보 수집(미보유+restriction)을
  재사용해 셔플 후 앞 N장을 `_build_level_choice(0→1)`+localize로 반환.

## 범위 제외
- 보물지도 보너스(후속 — 헬퍼에 1줄 예약만). 상자 3택/보물탐색/시네마틱(무변경).
- 확률 튜닝(3%/1% 확정, 라이브 후 조정). flag OFF(게이트로 자연 제외).

## 스모크 (개정: `mythic_perk_offer_chance_smoke.gd`)
- [ ] jackpot=1.0 강제 → 오퍼 non-gold 카드 **전원 신화 + 서로 다른 id** + target장 유지
- [ ] jackpot=0.0, single=1.0 강제 → 신화 **정확히 1장** (기존 레그 시임 이름만 갱신)
- [ ] jackpot=1.0 + 미보유 2종만 → 신화 2장 + 일반 1장(오퍼 target장 유지)
- [ ] 둘 다 0.0 → 신화 0장 / 슬롯 가득 + 둘 다 1.0 → 0장 / flag OFF → 0장
- [ ] 잭팟 오퍼에서 apply → raw Lv1 (기존 apply 레그 재사용)
- [ ] 소스 계약: 시임 2개 + 누적 밴드 롤 + 채움 순서(기존 어서션 이름 갱신)
- [ ] offer_exposure 기준선: 두 시임 모두 0.0 강제로 갱신(신화 미노출 유지)

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. 잭팟 레인 임시 제거(single만) → "jackpot=1.0 전원 신화" 레그 RED → 복원
2. 잭팟 빌더의 중복 허용(셔플 절단 대신 같은 id 반복) 임시 변경 → "서로 다른 id"
   레그 RED → 복원

## 트랩 노트
- **누적 밴드 순서**: jackpot 밴드가 앞(0~1%), single이 뒤(1~4%) — single 판정에
  jackpot_chance를 더한 상한 사용. 시임 강제 시(jackpot=1.0) single 밴드는 도달
  불가 — 의도(우선순위).
- 잭팟 카드 간 **id 중복 금지**(셔플 후 절단 — 같은 후보 재추첨 금지).
- 기존 시임 `mythic_offer_chance` 참조 잔존 0 확인(소스계약 스모크가 옛 이름을
  참조하면 함께 갱신 — offer_exposure의 `mythic_offer_chance = 0.0`도 2시임으로).
- 핫패스 아님. 커밋: 카탈로그는 체크포인트 흡수(기존 판단 유지), 스모크 개정은
  체크포인트 경계 포함 파일(`mythic_perk_offer_chance_smoke.gd` — prep 문서에 이미
  등재)이라 함께 흡수.

## 완료 보고 형식
(1) 2레인 롤 + 빌더 일반화 지점, (2) 개정 스모크 결과 원문, (3) 반증검증 2건
RED→GREEN, (4) 슬롯가득/flag OFF/미보유 부족 채움 자가확인, (5) 이탈/가정.
