# 코덱스 핸드오프 — 오퍼 페이싱 2건: 대쉬토큰 조기 부스트 + 보유 업글 50% 예약

발주: 2026-07-08. 유저 체감 2건:
1. 대쉬토큰(dash_amplification)이 너무 안 나옴 (핵심 퍽인데 풀 희석 ~6%/오퍼)
2. 슬롯 가득까지 보유 퍽 렙업이 거의 안 나옴 — 가득 차야 렙업 시작

진단: get_choices 풀 50~58장 셔플-앞절단이라 가중치 없음. 보유 업글 예약은
full-slot 게이트뿐(안 가득 구간 보장 0). 링코어 조기부스트(force-include)와 동일
병리. Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 결정 (확정)

- **대쉬토큰 조기 부스트**: force-include 확률 **Lv0 25% / Lv1 12% / Lv2 6%**
  (현재 레벨 인덱스 테이퍼, Lv3=max는 부스트 없음).
- **보유 업글 부분 예약**: 슬롯 **안 가득** + 업글 가능 보유 슬롯 퍽 ≥1이면
  **오퍼당 50% 확률로 1칸** 보유 업글 예약(셔플 로테이션). 가득 시 기존
  확정 `target-1` 예약 무변경.

## 배선 (`runtime_perk_catalog.gd` — 기존 예약 체인 확장)

### 시임 (인스턴스 var — 스모크 강제용)
```
var dash_token_boost_chances: Array = [0.25, 0.12, 0.06]   # index = 현재 레벨 0..2
var owned_upgrade_partial_chance := 0.5
```

### 예약 체인 순서 (확정)
**신화(2티어) → 대쉬토큰 → 보유업글 → 링코어 → 셔플 → 즉시필러 → 골드**

### ① 대쉬토큰 force-include — **풀에서 추출-승격** 방식
```
var dash_token_reserved: Array = []
if PerkConversionFlags.is_enabled():
    var dash_level: int = int(runtime_levels.get("dash_amplification", 0))
    if dash_level >= 0 and dash_level < dash_token_boost_chances.size() \
            and randf() < float(dash_token_boost_chances[dash_level]):
        # choices 풀에서 dash_amplification 카드를 찾아 예약으로 승격(제거+예약).
        # 풀에 없으면(만렙/슬롯필터 제외) 자연 스킵 — 신규 카드 생성 금지.
        dash_token_reserved = _extract_choice_by_id(choices, "dash_amplification")
```
- **추출-승격이 핵심**: 카드는 이미 풀에 존재(COMMON_PERKS, 슬롯 필터 통과분)
  하므로 새로 만들지 않고 승격만 → 슬롯 예산·만렙 제외가 **자동 준수**, 중복
  불가. `_extract_choice_by_id(choices, id) -> Array` 소형 헬퍼 신설(찾으면
  [카드] 반환+choices에서 제거, 없으면 []).

### ② 보유 업글 부분 예약 — 기존 블록 확장
```
var owned_upgrade_reserved: Array = []
if PerkConversionFlags.is_enabled():
    if not has_open_perk_slot(runtime_levels, _registry):
        # 기존: 가득 → 확정 target-1
        (기존 블록 그대로, limit = target_choice_count - 1)
    elif randf() < owned_upgrade_partial_chance:
        # 신규: 안 가득 → 50%로 1칸
        (같은 _extract_owned_slot_upgrade_reserved_choices, limit = 1)
```
- 추출 헬퍼 재사용(셔플 내장 — 로테이션 자동). 후보 0이면 빈 배열(무해).
- dash_amplification Lv1+가 ①에서 이미 승격됐으면 풀에 없어 여기 중복 불가.

### ③ 링코어 한도 차감 확장
```
target_choice_count - mythic_reserved.size() - dash_token_reserved.size() - owned_upgrade_reserved.size()
```
채움 루프에 dash_token_reserved를 신화 다음에 삽입(각 루프 기존 `>= target` break
유지 — 잭팟 시 자연 밀림).

## 범위 제외
- 확률 튜닝 재조정(수치 확정, 라이브 후 조정). 보물지도/신화 레인(무변경).
- 다른 "핵심 퍽" 부스트 일반화(대쉬토큰 단건 — 패턴이 서면 후속에서 목록화 가능).

## 스모크 (개정: `perk_offer_owned_upgrade_priority_smoke.gd` + 레그 추가, 또는 신설)
- [ ] dash 시임 [1.0,1.0,1.0] + Lv0/1/2 각각 → 오퍼에 dash_amplification **정확히
      1장**(중복 없음), Lv3(만렙) → 부스트 무발동(카드 자체 부재)
- [ ] dash 시임 1.0 + 슬롯 가득(카드가 슬롯 필터로 풀에 없음) → dash 부재(추출
      스킵, 크래시 없음)
- [ ] owned 시임 1.0 + 안 가득 + 보유 업글 ≥1 → 예약 1칸(보유 업글이 오퍼에 포함)
- [ ] owned 시임 0.0 + 안 가득 → 부분 예약 미발동(소스/카운팅 레벨 — 셔플 우연
      등장은 허용이므로 예약 경로만 검증)
- [ ] 가득 시 기존 확정 target-1 예약 무변화(기존 레그 유지)
- [ ] 체인 순서 소스계약: 신화 → dash → owned → 링코어 채움 순서 + 링코어 차감식
- [ ] 신화 잭팟(시임 1.0)과 동시 → target 초과 없음(dash/owned 자연 밀림)

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. dash 추출-승격 호출 임시 제거 → "시임 1.0 시 dash 정확히 1장" 레그 RED → 복원
2. owned 부분 예약 limit을 임시 0으로 → "시임 1.0 시 예약 1칸" 레그 RED → 복원

## 트랩 노트
- **추출-승격 원칙**: dash 카드를 새로 빌드하지 말 것(슬롯 예산/만렙/필터 우회
  위험). 풀 부재 = 스킵.
- per-offer 롤 2회 추가(dash·owned) — 신화 롤과 독립(각자 randf, 상호 간섭 없음).
  per-frame 아님.
- 시임은 인스턴스 var(스모크 강제). 옛 owned 블록의 full-slot 게이트 의미론 무변경.
- 커밋: 카탈로그 = 체크포인트 흡수(기존 판단). 스모크 개정은 perk_* 글롭 안.
- 핫패스 아님. UTF-8 BOM 금지, `.agents/skills/` 미러 금지.

## 완료 보고 형식
(1) 시임 2개 + 추출 헬퍼 + 체인 삽입 지점, (2) 개정 스모크 결과 원문, (3) 반증검증
2건 RED→GREEN, (4) 가득-확정예약/잭팟 공존/만렙 스킵 자가확인, (5) 이탈/가정.
