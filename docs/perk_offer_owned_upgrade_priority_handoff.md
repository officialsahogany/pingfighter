# 코덱스 핸드오프 — 슬롯 가득 시 보유 슬롯 퍽 업글 우선 노출 (오퍼 희석 수정)

발주: 2026-07-08. 증상: 퍽 슬롯 가득(예 8/8) 상태에서 오퍼가 즉시/골드/링펫으로
희석돼 **보유 슬롯 퍽 업글이 1개씩만** 나와 레벨업이 느림. "보유 퍽 강화만" 라벨이
약속하는 것보다 실제 경험이 희석됨.
Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 근본 원인 (확인됨)

`runtime_perk_catalog.get_choices`:
- `_filter_perk_slot_budget`는 가득 시 **신규 슬롯 퍽만 제거**, 보유 업글
  (current_level>0, extra_slots=0)은 통과 ✓
- 하지만 **링코어만 예약**(`_extract_lingpet_ring_core_reserved_choices`)되고,
  **보유 슬롯 퍽 업글은 예약 없이 셔플 풀**(line ~1325)로 던져져 즉시/강화칩과
  target(≈3)칸을 동등 경쟁 → 1개씩만 노출.

## 결정 (확정)

- **가득 찼을 때만** 보유 슬롯 퍽 업글을 **예약 티어**로 승격. 안 찼을 땐 현행 유지
  (신규 퍽 획득이 우선).
- **다양성 1칸**: `reserve_limit = max(0, target_choice_count - 1)`. target=3이면
  보유 업글 2 + 다양성 1(즉시/링펫/링코어) + 골드(별도).
- **우선순위**: 보유 업글 예약 → 링코어 예약 → 셔플 나머지 → 즉시 필러 → 골드.
  (링코어보다 보유 업글이 먼저 — 불만 직접 해소)
- **최소 보장**(상한 아님): 업글 가능 퍽이 reserve_limit보다 적으면 나머지는 기존대로
  다양성으로 채움. 초과분은 remaining으로 돌려 셔플에서 다양성 칸도 노릴 수 있음.

## 배선 (단일 파일: `runtime_perk_catalog.gd`)

### ① 신설 헬퍼 (`_extract_lingpet_ring_core_reserved_choices` 미러)
```
func _extract_owned_slot_upgrade_reserved_choices(
    choices: Array, runtime_levels: Dictionary, reserve_limit: int
) -> Dictionary:
    var upgrades: Array = []
    var remaining: Array = []
    for value in choices:
        if value is Dictionary:
            var choice: Dictionary = value
            var cid: String = str(choice.get("id", ""))
            var current_level: int = int(runtime_levels.get(cid, choice.get("current_level", 0)))
            if is_slot_consuming_perk(choice) and current_level > 0:
                upgrades.append(choice)
                continue
        remaining.append(value)
    upgrades.shuffle()                              # 오퍼마다 다른 업글 노출
    var limit: int = maxi(0, reserve_limit)
    var reserved: Array = []
    for i in upgrades.size():
        if i < limit:
            reserved.append(upgrades[i])
        else:
            remaining.append(upgrades[i])           # 초과분은 다양성 칸 후보로
    return {"reserved": reserved, "remaining": remaining}
```
- 식별: `is_slot_consuming_perk(choice) && current_level>0`. current_level은 필터와
  동일하게 `runtime_levels`(authoritative) 우선, 없으면 choice의 값.

### ② `get_choices` 주입 (기존 링코어 예약 직전, 현재 ~line 1321~1334)
```
choices = _filter_lingpet_owned_gate(choices, owner)

var owned_upgrade_reserved: Array = []              # NEW
if PerkConversionFlags.is_enabled() and not has_open_perk_slot(runtime_levels, _registry):
    var owned_reserve_limit: int = max(0, target_choice_count - 1)   # 다양성 1칸
    var up_res: Dictionary = _extract_owned_slot_upgrade_reserved_choices(choices, runtime_levels, owned_reserve_limit)
    owned_upgrade_reserved = up_res.get("reserved", []) as Array
    choices = up_res.get("remaining", []) as Array

var ring_core_reservation: Dictionary = _extract_lingpet_ring_core_reserved_choices(
    choices, max(0, target_choice_count - owned_upgrade_reserved.size()))   # 남은 target으로
var reserved_choices: Array = ring_core_reservation.get("reserved", []) as Array
choices = ring_core_reservation.get("remaining", []) as Array
choices.shuffle()
var result: Array = []
for c in owned_upgrade_reserved:                    # 보유 업글 FIRST
    if result.size() >= target_choice_count: break
    result.append(c)
for reserved_choice in reserved_choices:            # 그 다음 링코어
    if result.size() >= target_choice_count: break
    result.append(reserved_choice)
for choice in choices:                              # 셔플 나머지
    if result.size() >= target_choice_count: break
    result.append(choice)
# (이하 즉시 필러 line ~1336, 골드 항상 append line ~1347 — 무변경)
```

## 범위 제외
- 안 찬 상태의 오퍼(현행 유지). flag OFF(퍽 슬롯 개념 없음 — is_enabled 게이트로 자연 제외).
- 골드/즉시 필러/링코어 예약 자체 로직(무변경, 예약 한도만 target-owned로 축소).
- 진행중 3시스템 재설계(대쉬토큰/슬롯6→8/링코어 슬롯화)는 별개 — 이 수정은
  기존 `has_open_perk_slot`/`count_owned_slot_perks`를 그대로 소비.

## 스모크 (신설: `perk_offer_owned_upgrade_priority_smoke.gd`)
- [ ] flag ON + 슬롯 가득 + 업글 가능 보유 슬롯 퍽 ≥3 + target 3 → 결과에 보유 슬롯
      퍽 업글(current_level>0) **≥2**, 다양성(즉시/링펫) **≤1**, 골드 1
- [ ] flag ON + 슬롯 가득 + 업글 여러 회 호출 → 노출되는 업글 id가 **회마다 변동**
      (shuffle 검증 — seed 고정 후 서로 다른 조합 확인, 또는 전체 업글이 여러 회에
      걸쳐 등장)
- [ ] flag ON + 슬롯 **안 참** → 보유 업글 예약 **미적용**(신규 슬롯 퍽도 정상 노출)
- [ ] flag ON + 슬롯 가득 + 업글 가능 퍽 0(전부 만렙) → 예약 0, 크래시 없음, 오퍼는
      기존대로 다양성
- [ ] 링코어 예약이 보유 업글 **뒤에** 여전히 작동(우선순위 + 남은 target)
- [ ] flag OFF → 이 경로 미진입(is_enabled 게이트)

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. `_extract_owned_slot_upgrade_reserved_choices` 호출을 임시 제거(예약 스킵) →
   "슬롯 가득 시 업글 ≥2" 레그 RED → 복원
2. 게이트를 `not has_open_perk_slot` 무시하고 항상 예약으로 임시 변경 → "슬롯 안 참
   시 신규 퍽 정상 노출" 레그 RED → 복원

## 트랩 노트
- **링코어 카운트 브리지**: `has_open_perk_slot`/`count_owned_slot_perks`는 링코어를
  `_run_ring_core_tier` 별도 저장 이슈가 있음(진행중 재설계 §유의점1). 이 수정은
  같은 함수를 소비하므로 그 브리지가 고쳐지면 자동 정합. 현재 8/8은 정상 감지되니
  즉시 유효. 스모크는 `has_open_perk_slot`가 false를 반환하도록 셋업(가득 상태 강제).
- **예약 한도 배분**: 링코어 예약을 `target - owned_reserved.size()`로 줄여야 총
  target 초과 안 됨(안 줄이면 링코어가 target을 다 먹어 보유 업글이 밀릴 수 있음).
- **current_level 소스**: 필터와 동일하게 runtime_levels 우선(choice의 stale
  current_level 방지).
- **핫패스 아님**: get_choices는 오퍼당 1회. shuffle는 게임 RNG(허용).
- **merge 표면**: get_choices는 진행중 재설계와 겹칠 수 있음 — 이 수정은 예약 블록
  추가라 국소적. owner set() 스키마 트랩 무관(신규 owner 키 없음). UTF-8 BOM 금지,
  `.agents/skills/` 미러 수동편집 금지.

## 자동커밋 (통과 시)
- 스코프 헝크분리: runtime_perk_catalog.gd의 **이 예약 블록 + 신설 헬퍼만**. 같은
  파일의 무관 WIP(슬롯비용/링펫/unlock 예산 등 진행중 재설계 헌크)는 **제외**. 신설
  스모크 포함. 로컬만(push 금지).

## 완료 보고 형식
(1) 변경 지점(헬퍼 + get_choices 주입) + 우선순위 순서, (2) 신설 스모크 결과 원문,
(3) 반증검증 2건 RED→GREEN, (4) 슬롯 안 참/링코어 예약/골드 무변화 자가 확인,
(5) 이탈/가정.
