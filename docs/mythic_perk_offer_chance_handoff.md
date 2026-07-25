# 코덱스 핸드오프 — 신화퍽 일반 오퍼 1% 등장 (열린 슬롯 한정)

발주: 2026-07-08. 요구: 초희귀 신화퍽이 일반 퍽 선택 오퍼에도 **1% 확률**로 등장.
결정: **열린 퍽 슬롯이 있을 때만**(신화는 슬롯 소모). Claude 기획 → Codex 배선 →
Claude 적대 리뷰 → 통과 시 자동커밋.

## 현행 (확인됨)

`_append_converted_perk_choices`는 `CONVERTED_PERKS`(일반 28)만 순회 → 신화퍽 오퍼
**0%**(S2a 제외). `CONVERTED_MYTHIC_PERKS`는 조회/디벅 용도로만 참조. 신화는 상자/보물
채널로만 획득.

## 설계 (확정)

- **오퍼당 1% 롤**(per-opportunity — get_choices는 선택 기회당 1회 호출, per-frame 트랩
  아님). 성공 시 **미보유 신화퍽 1종**을 오퍼의 한 칸으로 예약(뜨면 반드시 보이게).
- **열린 슬롯 한정**: `has_open_perk_slot(runtime_levels, _registry) == true`일 때만.
  가득이면 0%(상자 채널은 유지). 신화 획득 시 슬롯 소모라 슬롯 여유 필수.
- **대상**: 미보유 신화퍽 랜덤(max_level 1이라 보유분 재등장 불가). 12종 전부 보유
  시 스킵. character_restriction 있으면 준수(현재 신화는 무제한이나 방어적 필터).
- **선택 시 획득**: 신화 choice dict(level 0→1)를 기존 `apply_choice` 경로로 → 효과/
  HUD/피드백 정상(신화 효과 배선은 S1c batch5에서 완료). 별도 그랜트 경로 불필요.
- **표시**: 예약 티어로 target 3칸 중 1칸 점유(일반 퍽 1개와 교체). 애니 아이콘 렌더.

## 배선 (`runtime_perk_catalog.gd`)

### ① 상수 + 테스트 시임
```
var mythic_offer_chance := 0.01            # 인스턴스 var — 스모크가 1.0/0.0으로 강제
```
(const 대신 인스턴스 var: 스모크가 randf 없이 결정적으로 검증하도록. 전역 상태 아님.)

**후속 예약(보물지도 재설계)**: 보물지도(downtown_treasure_map)가 이 확률에
+N%p/Lv를 더하는 메타퍽으로 재설계될 예정(별도 슬라이스, 미확정). 확률 판정을
`randf() < mythic_offer_chance` 인라인 대신 **헬퍼 1개**(예:
`_get_mythic_offer_chance(runtime_levels) -> float`, 지금은 `mythic_offer_chance`
그대로 반환)로 빼두면 후속이 그 헬퍼에 보너스 1줄 추가로 끝남. 이번 슬라이스에서
보물지도 보너스를 **구현하지는 말 것**(미확정).

### ② 미보유 신화 랜덤 픽 헬퍼 (신설)
```
func _pick_random_unowned_mythic_perk_id(runtime_levels: Dictionary, character_type: String) -> String:
    var candidates: Array[String] = []
    for mid_value in CONVERTED_MYTHIC_PERKS.keys():
        var mid: String = str(mid_value)
        var m: Dictionary = CONVERTED_MYTHIC_PERKS[mid]
        if int(runtime_levels.get(mid, 0)) > 0:
            continue
        if not _is_perk_allowed_for_character(m, character_type):
            continue
        candidates.append(mid)
    if candidates.is_empty():
        return ""
    candidates.shuffle()
    return candidates[0]
```

### ③ `get_choices` 주입 (기존 owned-upgrade / ring-core 예약과 같은 구역)
```
# 신화 1% 오퍼 (열린 슬롯 한정) — owned-upgrade 예약보다 먼저
var mythic_reserved: Array = []
if PerkConversionFlags.is_enabled() \
        and has_open_perk_slot(runtime_levels, _registry) \
        and randf() < mythic_offer_chance:
    var mythic_id := _pick_random_unowned_mythic_perk_id(runtime_levels, normalized)
    if mythic_id != "":
        var m_data: Dictionary = CONVERTED_MYTHIC_PERKS[mythic_id]
        var m_choice: Dictionary = _build_level_choice(mythic_id, m_data, 0, 1, str(m_data.get("character_restriction", "")))
        mythic_reserved = [LanguageSettings.localize_perk_data(m_choice)]

# (기존) owned-upgrade 예약은 가득일 때만 활성 → 신화(열린슬롯)와 상호배타
# ring-core 예약 한도에서 mythic + owned 예약 수만큼 차감
var ring_core_reservation := _extract_lingpet_ring_core_reserved_choices(
    choices, maxi(0, target_choice_count - mythic_reserved.size() - owned_upgrade_reserved.size()))
...
# 채움 순서: 신화 → owned-upgrade → ring-core → 셔플 나머지 → 즉시 필러 → 골드
var result: Array = []
for m in mythic_reserved:
    if result.size() >= target_choice_count: break
    result.append(m)
for owned_upgrade_choice in owned_upgrade_reserved: ...   # 기존
for reserved_choice in reserved_choices: ...              # 링코어
for choice in choices: ...                                # 셔플
```
- 신화는 `choices` 풀에 없으므로(일반만 append) 별도 예약 티어로 안전. 중복 없음.
- 신화(열린슬롯) vs owned-upgrade(가득)는 상호배타라 순서 충돌 없음.

## 범위 제외
- 가득 시 신화 등장(결정: 열린슬롯만). 스왑 다이얼로그(비채택).
- 상자/보물 신화 채널(무변경 — 이건 오퍼만 추가).
- 확률 튜닝(1% 확정, 라이브 후 조정 가능). flag OFF(is_enabled 게이트로 제외).

## 스모크 (신설: `mythic_perk_offer_chance_smoke.gd`)
- [ ] `_pick_random_unowned_mythic_perk_id`: 미보유 → 유효 신화 id, 12종 전부 보유 → ""
- [ ] flag ON + 열린 슬롯 + chance=1.0(강제) → 오퍼에 신화 **정확히 1개**, 슬롯 1칸 점유,
      current_level 0(신규)
- [ ] flag ON + **슬롯 가득** + chance=1.0 → 오퍼에 신화 **0개**(열린슬롯 게이트)
- [ ] flag ON + chance=0.0 → 신화 0개(기준선)
- [ ] flag OFF + chance=1.0 → 신화 0개(is_enabled 게이트)
- [ ] 신화 오퍼가 owned-upgrade/ring-core 예약보다 앞(가득 아님 상태라 owned는 어차피
      비활성) — 최소한 신화가 result에 포함되는지
- [ ] (선택) 신화 choice 선택 → apply_choice로 runtime_skill_levels[mythic]=1

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. 신화 예약 주입 블록 임시 제거 → "chance=1.0+열린슬롯 시 신화 1개" 레그 RED → 복원
2. `has_open_perk_slot` 게이트 임시 제거(항상 통과) → "슬롯 가득 시 신화 0개" 레그 RED
   → 복원

## 트랩 노트
- **per-offer 1%**: get_choices가 선택 기회당 1회 호출임을 유지(재호출 시 재롤은 정상 —
  각 기회 독립). per-frame 아님.
- **randf 결정성**: 스모크는 `mythic_offer_chance`를 1.0/0.0으로 강제(seed 의존 금지).
- **슬롯 카운트 브리지**: `has_open_perk_slot`는 링코어 카운트 브리지(진행중 재설계
  §유의점1) 의존 — 같은 함수 소비라 그 브리지가 고쳐지면 자동 정합.
- **엉킴 주의**: get_choices는 진행중 WIP 스택(모듈화·재설계·오퍼-우선순위)과 이미
  겹침 — 이 주입도 그 위에 쌓임. 커밋은 A(모듈화) 착지 후 정리 대상(아래).
- owner set() 스키마 무관(신규 키 없음). UTF-8 BOM 금지, `.agents/skills/` 미러 금지.

## 자동커밋 (통과 시 — 단 엉킴 주의)
- get_choices는 현재 대형 WIP 스택과 인터리브 상태라, **P1·오퍼-우선순위처럼 clean
  atomic 커밋이 막힐 가능성**이 높음. 배선·검증 후 헝크 분리 시도하되, 불가하면
  검증완료·미커밋으로 보고(A 모듈화 착지 후 일괄 정리). 신설 스모크 파일은 단독 커밋 가능.

## 완료 보고 형식
(1) 변경 지점(헬퍼 + get_choices 주입) + 채움 순서, (2) 신설 스모크 결과 원문,
(3) 반증검증 2건 RED→GREEN, (4) 슬롯 가득 0개/flag OFF 0개 자가 확인, (5) 커밋 분리
가능 여부(엉킴 시 미커밋 보고), (6) 이탈/가정.
