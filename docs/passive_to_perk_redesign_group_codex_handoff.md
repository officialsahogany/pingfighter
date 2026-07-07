# 재설계군 4종 코덱스 핸드오프 — 금괴 삭제 / 현자의 계약·통찰 일반퍽 / 대월계수 신화퍽

기준: `docs/passive_to_perk_conversion_plan.md` §4-D (결정 확정 2026-07-08).
발주: 2026-07-08. Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

이 슬라이스는 **R1(배선)** 만 담당한다. 아이콘(현자의 계약/통찰 정적 2종 +
대월계수 애니 1종)은 **R2(Claude imagegen)** 후속 — R1은 프로시저 폴백으로 동작하면
합격이다. 값/카탈로그는 기존 26 일반퍽 + 11 신화퍽 전환과 **완전히 동일한 패턴**을
따른다. 참조 시블링: `transcendent_crown`(신화퍽, 유효레벨 보너스 생산+자기제외).

플래그 규약(불변): 컴파일 기본 OFF, 부팅(`boot_flow_scene._ready`)에서 ON = Path B.
flag OFF = 레거시 아이템 체제(현자의 반지/신성 월계수/다우징 고글/금괴 아이템 그대로,
회귀 금지). flag ON = 아래 퍽 경로.

---

## 1) 금괴 `gold_bar` → 삭제 (필드 골드 픽업 흡수)

**퍽/액티브 미신설.** 패시브 아이템이라 S2b가 flag ON에서 필드/판도라/상점/가챠
배출을 이미 폐쇄 → 획득 불가 상태여야 함. 이번 작업은 **봉인 + 문서 정리**만.

- [ ] `perk_conversion_values.gd`의 주석(현재 line 56~57 "S0 D-결정 대기: gold_bar,
      sage_ring, sacred_laurel, dowsing_goggles are intentionally absent...")을
      갱신: gold_bar = **삭제 확정(퍽/보상 매핑 없음, flag ON 배출 폐쇄로 소멸)**,
      나머지 3종은 아래에서 등록됨을 반영.
- [ ] `CONVERSION_SOURCE_TO_PERK` / `DELETED_ITEM_COMPENSATION`에 gold_bar **추가
      금지**(보상 매핑 없음 — 순수 삭제).
- [ ] **씰**: flag ON에서 gold_bar가 어떤 획득 경로에도 나타나지 않음(필드 스폰
      풀 / 판도라 풀 / 상점 풀 / 스테이지클리어 상자·가챠 / 보물). 이미 폐쇄돼
      있으면 어서션만; 만약 한 경로라도 새면 그 경로만 닫는다.
- gold_bar 효과 게터(`mythic_item_stat_bonus_runtime.get_gold_bar_*`)는 **변경
      불필요** — flag ON에선 count=0이라 자연히 중립(속도배율 1.0). 코드 삭제 금지
      (flag OFF 레거시 경로 보존).

---

## 2) 현자의 반지 `sage_ring` → 일반퍽 '현자의 계약' (id=sage_ring, max_level 3)

리스크-리턴 슬롯소모 일반퍽. **투자 퍽 유효레벨을 올리는 대신 몸이 작고 느려진다.**

### 카탈로그 (`runtime_perk_catalog.gd` CONVERTED_PERKS)
```
"sage_ring": {
    "name": "현자의 계약",
    "max_level": 3,
    "descriptions": {
        1: "전 퍽 유효레벨 +1 / 이동속도 -8%, 패들 -6%",
        2: "전 퍽 유효레벨 +2 / 이동속도 -16%, 패들 -12%",
        3: "전 퍽 유효레벨 +3 / 이동속도 -24%, 패들 -18%",
    },
    "detail": "투자한 퍽들의 유효레벨을 올리는 대신 몸이 작고 느려집니다.",
    "icon_color": Color(0.62, 0.45, 0.85),
    "tree": "common",
    "effective_level_exempt": true,   # 순환참조 가드(아래 §순환참조)
    "conversion_source": "sage_ring",
},
```

### 값 테이블 (`perk_conversion_values.gd` CONVERTED_PERK_VALUES)
```
"sage_ring": {
    "perk_level_bonus": [1.0, 2.0, 3.0],
    "sage_speed_penalty_pct": [8.0, 16.0, 24.0],
    "sage_body_penalty_pct": [6.0, 12.0, 18.0],
},
```
`CONVERSION_SOURCE_TO_PERK`에 `"sage_ring": "sage_ring"` 추가.

### 효과 게이팅 (`mythic_item_progression_bonus_runtime.gd`)
`transcendent_crown` 패턴을 그대로 미러(이미 flag 분기 있음, line 74~101 참조).
세 게터에 flag ON 분기 추가 — **모두 sage_ring의 RAW 퍽 레벨** 기준:

- `get_sage_ring_perk_level_bonus`: flag ON → RAW 레벨>0이면
  `int(PerkConversionValues.get_value("sage_ring", "perk_level_bonus", raw_level))`,
  아니면 0.
- `get_sage_ring_speed_penalty_pct`: flag ON → `get_value("sage_ring",
  "sage_speed_penalty_pct", raw_level)` (0이면 페널티 없음).
- `get_sage_ring_body_penalty_pct`: flag ON → `get_value("sage_ring",
  "sage_body_penalty_pct", raw_level)`.

RAW 레벨 = `runtime.get` 경로가 아니라 **원시 퍽 레벨**(재귀 방지). 크라운이
`_get_converted_crown_level`로 `get_converted_perk_effect_level`을 쓰는 것과 달리,
**sage는 자기 자신의 EFFECT 레벨을 읽으면 안 됨**(자기 유효레벨은 자기 보너스를
포함 → 무한 재귀). `runtime_skill_levels.get("sage_ring", 0)`를 직접 읽는 헬퍼를
쓰거나, runtime에 raw-level 접근자가 있으면 그것을 사용. 확인해서 raw를 보장할 것.

### 순환참조 가드 (반드시 성립 — 씰 대상)
1. **현자의 계약은 자기 보너스를 자기에게 주지 않는다.** `effective_level_exempt:
   true` → `get_converted_perk_effect_level("sage_ring")`는 raw(클램프)만 반환.
   추가로 `get_runtime_skill_level` 경로도 sage를 제외해야 하면
   `VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS`(runtime_perk_state.gd line 67)에
   `"sage_ring": true` 추가(크라운은 효과가 고정이라 미등재였지만, sage는 레벨
   스케일이라 표시 일관성 위해 등재 권장). **판단은 씰로**: 아래 레그가 GREEN이면 OK.
2. **초월자의 관도 현자의 계약을 버프하지 않는다.** (1)의 exempt로 자동 충족
   (exempt는 크라운 보너스도 무시).
3. **현자의 계약은 다른 비exempt 일반퍽은 버프한다.** (`get_total_item_perk_level_bonus`
   = sage_perk_bonus + crown_bonus → 일반퍽에 적용, 기존 배선 그대로).
4. **신화퍽(exempt)은 현자의 계약 보너스를 받지 않는다.** (기존 exempt 규칙).

### 오퍼 / 슬롯
- CONVERTED_PERKS 등재로 일반 오퍼(`get_choices`)에 자동 노출.
- S7 슬롯: `is_slot_consuming_perk`가 unlocks_skill=""·non-instant·non-lingpet·
  non-gold이므로 자동으로 **슬롯 소모**. 별도 작업 없음.

---

## 3) 신성 월계수 `sacred_laurel` → 신화퍽 '대월계수' (id=sacred_laurel, max_level 1)

월계수잎 실드 **8잎 고정** 신화퍽. 월계수잎 일반퍽(1~5)과 기전 동일·고정 고수치.
D5 단일고정, 유효레벨 보너스 제외.

### 카탈로그 (`runtime_perk_catalog.gd` CONVERTED_MYTHIC_PERKS)
```
"sacred_laurel": {
    "name": "대월계수",
    "max_level": 1,
    "descriptions": {1: "월계수잎 방패 8장 (플레이어 골문 방어)"},
    "detail": "성스러운 월계수가 골문 앞에 8장의 잎 방패를 세웁니다.",
    "icon_color": Color(0.78, 0.85, 0.42),
    "tree": "mythic",
    "rarity": "mythic",
    "effective_level_exempt": true,
    "conversion_source": "sacred_laurel",
},
```

### 값 (`perk_conversion_values.gd` CONVERTED_MYTHIC_VALUES)
```
"sacred_laurel": {
    "leaf_count": 8.0,
},
```
`CONVERSION_SOURCE_TO_PERK`에 `"sacred_laurel": "sacred_laurel"` 추가.

### 효과 게이팅 (`mythic_item_progression_bonus_runtime.gd`)
`get_sacred_laurel_leaf_bonus`에 flag ON 분기(크라운 `get_transcendent_crown_skill_bonus`
패턴 미러):
- flag ON → 퍽 레벨>0이면 `int(round(PerkConversionValues.get_mythic_value(
  "sacred_laurel", "leaf_count")))` (=8), 아니면 0.
- 퍽 레벨 판정은 `get_converted_perk_effect_level("sacred_laurel")`(exempt라 raw
  클램프) 또는 `_get_converted_*_level` 스타일 헬퍼로.

### 신화 채널 (`mythic_perk_grant_helper.gd`)
- `MYTHIC_PERK_IDS` 배열에 `"sacred_laurel"` **추가** (11 → 12). 이로써 상자/보물
  신화퍽 랜덤 그랜트 후보에 편입, S7 슬롯 가드(6개 가득 시 SP 폴백)도 자동 적용.

### 오퍼 / 슬롯
- CONVERTED_MYTHIC_PERKS는 일반 오퍼 **제외**(S2a 유지) — 상자/보물 채널로만.
- S7 슬롯: 신화퍽도 `is_slot_consuming_perk` true → **슬롯 소모**(카운트 포함). 자동.

---

## 4) 다우징 고글 `dowsing_goggles` → 일반퍽 '통찰' (id=dowsing_goggles, max_level 3)

퍽 선택 시 확률로 선택지 카드 **+1장**. 확률이 레벨로 상승. 메긴교르드(선택 **횟수**)와
축 구분.

### 카탈로그 (`runtime_perk_catalog.gd` CONVERTED_PERKS)
```
"dowsing_goggles": {
    "name": "통찰",
    "max_level": 3,
    "descriptions": {
        1: "퍽 선택 시 40% 확률로 선택지 카드 +1장",
        2: "퍽 선택 시 70% 확률로 선택지 카드 +1장",
        3: "퍽 선택 시 100% 확률로 선택지 카드 +1장",
    },
    "detail": "미래를 내다보아 더 많은 퍽 선택지를 드러냅니다.",
    "icon_color": Color(0.35, 0.80, 0.85),
    "tree": "common",
    "conversion_source": "dowsing_goggles",
},
```

### 값 (`perk_conversion_values.gd` CONVERTED_PERK_VALUES)
```
"dowsing_goggles": {
    "bonus_perk_chance": [40.0, 70.0, 100.0],
},
```
`CONVERSION_SOURCE_TO_PERK`에 `"dowsing_goggles": "dowsing_goggles"` 추가.

### 효과 게이팅 (`mythic_item_dowsing_runtime.gd`)
`get_pendulum_range`의 flag 분기(line 18~23)와 동일 패턴. `get_goggles_bonus_perk_chance_pct`에
flag ON 분기 추가:
- flag ON → `_get_converted_perk_value(runtime, ITEM_DOWSING_GOGGLES,
  "bonus_perk_chance")` (이미 존재하는 헬퍼 line 71~77 재사용 — 퍽 레벨×값테이블).
- flag OFF → 기존 `roll_query.get_equipped_roll_value(...)` 그대로.
- `get_runtime_perk_choice_count_bonus`의 선택기회당 1롤 게이트
  (`dowsing_goggles_bonus_triggered`)는 **그대로** — per-frame 확률 트랩 아님(선택
  기회당 1회 롤). 변경 불필요.

### 오퍼 / 슬롯
- CONVERTED_PERKS 등재로 일반 오퍼 자동 노출. S7 슬롯 소모 자동.

---

## 5) 다국어 (3종 신규 퍽)

- 현자의 계약 / 통찰 / 대월계수의 name·summary를 **퍽 경로**
  (`language_settings_data.gd`의 기존 전환-퍽 로컬 맵)에 등록. `localize_item_data`는
  아이템 전용이라 사용 금지.
- 기존 26 일반퍽 + 11 신화퍽이 등재된 **동일 언어셋 전부**에 3종 추가(grep 0건으로
  "번역 없음" 단정 금지 — 로컬 카피 싱크 규칙). 자동번역 불확실 시 항목별 TODO 마커.
- 로컬 커버리지 씰이 있으면 3종 포함되게 확장.

---

## 범위 제외
- 아이콘 생성/배선(R2 Claude imagegen — 정적 2 + 애니 1). R1은 프로시저 폴백 허용.
- 월계수잎 일반퍽 상한 변경(신성 월계수는 신화퍽 신설로 결정 — 일반퍽 무변경).
- 세이브 마이그레이션(런 빌드 비영속 확인 완료 → **드롭**).
- 밸런스 튜닝(수치는 1차값 — 라이브 후 조정 가능).
- flag OFF 경로(레거시 아이템 그대로).

## 스모크 (신설: `godot/tests/perk_conversion_redesign_group_smoke.gd`)
- [ ] flag ON: gold_bar가 필드/판도라/상점/상자·가챠/보물 어디에도 배출 안 됨
- [ ] flag ON: 현자의 계약 Lv1/2/3 → 이속·패들 페널티가 [8,16,24]/[6,12,18]% 반영
- [ ] flag ON: 현자의 계약 Lv3 + 비exempt 일반퍽(예: 별탐지기 Lv1) →
      `get_converted_perk_effect_level("star_detector") == 4`(1+3 버프됨)
- [ ] **순환참조**: 현자의 계약 Lv3 + 초월자의 관 보유 →
      `get_converted_perk_effect_level("sage_ring") == 3`(raw, 자기·크라운 보너스
      미포함). NOT 3+2+3
- [ ] flag ON: 대월계수 보유(Lv1) → `get_sacred_laurel_leaf_bonus == 8`, 미보유 → 0
- [ ] flag ON: 대월계수가 `MYTHIC_PERK_IDS`에 포함 → 신화 채널 그랜트 후보로 픽 가능
- [ ] flag ON: 대월계수는 일반 오퍼(`get_choices`) 미노출
- [ ] flag ON: 통찰 Lv1/2/3 → `get_goggles_bonus_perk_chance_pct` = 40/70/100
- [ ] flag ON: 통찰·현자의 계약이 일반 오퍼에 노출 + 슬롯 소모(6 카운트 포함)
- [ ] flag OFF 회귀: 4종 모두 레거시 아이템 효과 그대로(sage 롤 페널티, laurel 롤
      leaf, dowsing 롤 확률, gold_bar 판매/속도페널티)

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. `sage_ring`의 `effective_level_exempt`를 임시 제거(또는 제외셋 미등재) → "현자의
   계약 자기 보너스 미포함(==3)" 레그 RED → 복원
2. `MYTHIC_PERK_IDS`에서 `sacred_laurel` 임시 제거 → "대월계수 신화 채널 픽 가능"
   레그 RED → 복원
3. 통찰 효과 게이터의 flag ON 분기를 임시로 flag OFF 값으로 고정 → "통찰
   Lv3=100%" 레그 RED → 복원

## 트랩 노트
- **자기재귀**: sage 보너스/페널티는 반드시 RAW 레벨. `get_converted_perk_effect_level`
  (effective) 사용 금지. crown이 effective를 쓰는 건 crown 효과가 레벨무관 고정값이라
  안전한 것 — sage는 레벨 스케일이라 다름.
- `effective_level_exempt`는 오직 `_is_effective_level_exempt`만 읽음(신화 프록시로
  오용하는 코드 없음 확인) — 일반퍽에 붙여도 오퍼/표시 무영향.
- **owner set() 스키마 트랩**: 신규 owner 동기화 키가 필요하면 중단·보고(현재는
  기존 sage/laurel/dowsing 게터 경로 재사용이라 신규 키 불필요 예상).
- 스타포인트 단위 트랩: 대월계수 슬롯가득 폴백 SP는 기존 헬퍼(★1~3 클램프) 그대로.
- 핫패스 아님(오퍼/보상은 이벤트당 1회). 다우징 확률은 선택기회당 1롤(트랩 아님).
- UTF-8 BOM 금지. `.agents/skills/` 미러 수동 편집 금지.

## 자동커밋 (통과 시)
- 스코프: 이 4결정 관련 헌크만 헝크분리 커밋(blanket 금지). runtime_perk_state.gd에
  기존 resume-safety 램프 등 **무관 WIP 헌크가 있으면 제외**. 로컬만(push 금지).
- `.import`/.uid 없는 신규 .gd는 .gd만 커밋(전체 import는 타 트랙 pending .import
  실체화 위험).

## 완료 보고 형식
(1) 변경 파일 + 4결정별 배선 지점, (2) 순환참조 가드 3규칙 배선 + 씰 결과,
(3) 신화 채널 대월계수 편입 + 슬롯 카운트 확인, (4) 신설 스모크 결과 원문,
(5) 반증검증 3건 RED→GREEN, (6) flag OFF 회귀 무변화 자가 확인, (7) 이탈/가정.
