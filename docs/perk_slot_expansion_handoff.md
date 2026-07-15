# 코덱스 핸드오프 — 퍽 슬롯 확장 시스템 (기본 6 → 확장퍽으로 최대 10)

발주: 2026-07-08. 결정: 최대 퍽 슬롯을 **기본 6**으로 낮추고, 오퍼에서 획득하는
**슬롯 확장 퍽**(자신은 슬롯 비소모, 최대슬롯 +1/획득)으로 **최대 10**까지 성장.
⚠️ **이 결정은 3시스템 재설계의 "슬롯 6→8 고정"을 대체**(PERK_SLOT_LIMIT := 8 폐기
→ 동적 한도). 계획서 §확장 재설계("common_expansion → 퍽 슬롯 +1") 실행이기도 함.
Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 설계 (확정)

- **동적 한도**: `유효 한도 = clampi(6 + 확장퍽 레벨, 6, 10)`.
  상수: `BASE_PERK_SLOT_LIMIT := 6`, `MAX_PERK_SLOT_LIMIT := 10`. 기존
  `PERK_SLOT_LIMIT := 8` 상수 제거(참조 전부 동적 함수로 이관).
- **확장 퍽 = `common_expansion`(확장) 재목적화** (계획서 권장 — 기존 id/아이콘/
  로컬 키 재사용):
  - `max_level` 2 → **4** (6+4=10).
  - **슬롯 비소모**: `is_slot_consuming_perk`에서 제외(제외셋 등재) — 슬롯을 안
    먹고 최대치만 올림. **가득 상태에서도 오퍼에 등장**(비소모라 슬롯 예산 필터
    통과) = 가득 막힘의 탈출 밸브(의도된 시너지).
  - descriptions 1~4: "퍽 최대 슬롯 +1 (총 7/8/9/10)" 식으로 누적 표기. detail +
    다국어 7개 언어 갱신(PERK_NAME/PERK_SUMMARY — 문구수정=다국어 동기화 규칙).
  - 레거시 효과(장신구 슬롯, `get_runtime_skill_bonus`=float(level))는 flag OFF
    전용 잔존 — flag ON에서 신규 의미만. 연마 증폭 제외셋(카운트형)에 이미 있음
    확인(있다면 유지).

## 배선

### ① 동적 한도 함수 (`runtime_perk_catalog.gd`)
```
func get_perk_slot_limit(runtime_levels: Dictionary) -> int:
    var expansion_level: int = maxi(0, int(runtime_levels.get("common_expansion", 0)))
    return clampi(BASE_PERK_SLOT_LIMIT + expansion_level, BASE_PERK_SLOT_LIMIT, MAX_PERK_SLOT_LIMIT)
```
- 확장 레벨은 **RAW** 사용(유효레벨 보너스·연마로 슬롯이 늘면 안 됨 — 크라운/현자의
  계약이 최대슬롯을 올리는 사고 방지). 카운트형이라 이미 양쪽 제외셋에 있는지 확인,
  없으면 등재.

### ② 기존 PERK_SLOT_LIMIT 참조 전량 이관
grep 기준(현재 line 11·1452·1456·1463~64·1574·1686 부근 + 이후 추가분):
- `has_open_perk_slot(runtime_levels, registry)` → `count < get_perk_slot_limit(runtime_levels)`
- `get_perk_slot_status(...)` → `"limit": get_perk_slot_limit(...)` (X/6→X/동적 —
  결과화면·오퍼 모달의 "슬롯 X/N" UI가 자동 추종하는지 확인, 하드코딩 "/8" 텍스트
  있으면 함께)
- `_filter_perk_slot_budget`·owned-upgrade 게이트·신화 오퍼 게이트·
  `mythic_perk_grant_helper._has_open_perk_slot`(catalog 경유라 자동) 전부 동적으로.
- 상수 직접 참조가 남지 않게 grep 0건 확인(`PERK_SLOT_LIMIT` 심볼 제거가 가장 확실).

### ③ 스모크 픽스처 갱신
- `perk_slot_limit_smoke`·offer 스모크들의 슬롯 채움 픽스처가 8 하드코딩/상수 참조
  → 동적 한도 기준으로(확장 0 = 6). SLOT_FILLER_IDS 수량 확인.

## 범위 제외
- 확장퍽 등장 가중치 부스트(일반 풀 확률 그대로 — 필요 시 dash 패턴 후속).
- 슬롯 소모 경계(D2) 자체 변경·링코어/대쉬토큰 슬롯 비용(무변경 — 한도만 동적).
- flag OFF(레거시 장비 체제 — 장신구 의미 잔존, 신규 한도 로직은 flag ON 게이트
  필요: UI(캐릭터 정보·퍽 오버레이)는 flag와 무관하게 슬롯 상태를 조회하므로 "자연 격리"가 아니다 — `get_perk_slot_limit()` 자체가 OFF=6을 반환해 중앙 격리하고, 확장 퍽 비소모 예외도 flag ON에만 적용한다).

## 스모크 (개정: `perk_slot_limit_smoke.gd` + 필요 레그)
- [x] 확장 0 → 한도 6: 슬롯 퍽 6개 보유 시 가득(신규 차단, 보유업글 예약 작동) *(perk_slot_limit_smoke 씰)*
- [x] 확장 Lv1 → 한도 7: 6개 보유가 가득 아님(신규 노출), 7개째 획득 가능 *(perk_slot_limit_smoke 씰)*
- [x] 확장 Lv4 → 한도 10, Lv4 초과 불가(max_level), 한도 10 클램프 *(perk_slot_limit_smoke 씰)*
- [x] **가득(한도 6, 6개 보유) 상태에서 확장퍽이 오퍼에 등장 가능**(비소모 통과) *(perk_slot_limit_smoke 씰)*
      + 획득 시 한도 7로 즉시 반영(같은 runtime_levels 재조회)
- [x] 확장퍽 자신은 `is_slot_consuming_perk` false + count_owned_slot_perks 미포함 *(perk_slot_limit_smoke 씰)*
- [x] 확장 레벨은 RAW(크라운/현자의 계약 보유 시에도 한도 불변) *(perk_slot_limit_smoke 씰)*
- [x] 신화 오퍼/그랜트 슬롯 게이트가 동적 한도 추종(한도 7·보유 6 → 신화 등장 가능) *(perk_slot_limit_smoke 씰)*
- [x] UI 슬롯 상태(get_perk_slot_status)가 X/동적 한도 반환 *(perk_slot_limit_smoke 씰)*

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. `get_perk_slot_limit`를 상수 6 고정으로 임시 변경 → "확장 Lv1=한도 7" 레그 RED
   → 복원
2. `is_slot_consuming_perk`의 확장 제외 임시 해제 → "확장퍽 비소모/가득 시 등장"
   레그 RED → 복원

## 트랩 노트
- **RAW 레벨 필수**(①): 유효레벨/연마 경유 시 크라운이 최대슬롯 +2 하는 사고.
- **상수 잔존 금지**: PERK_SLOT_LIMIT 심볼 제거 후 grep 0건 — 남으면 일부 경로만
  8로 판정하는 이중 한도 버그.
- 하드코딩 "/8"·"슬롯 8" UI 텍스트/로컬 문자열 grep(6언어 포함).
- 진행중 3시스템 재설계 문서(`docs/dash_token_ringcore_slot_redesign_plan.md`)의
  "슬롯 6→8" 항목에 대체 결정 주석 1줄(문서 정합).
- 커밋: 카탈로그/스모크 = 체크포인트 흡수(기존 판단 유지).
- 핫패스 아님(오퍼/그랜트 시점). UTF-8 BOM 금지, `.agents/skills/` 미러 금지.

## 완료 보고 형식
(1) 동적 한도 함수 + 참조 이관 전량(grep 0건 증빙), (2) 확장퍽 재목적화(카탈로그+
비소모+다국어), (3) 개정 스모크 결과 원문, (4) 반증검증 2건 RED→GREEN, (5) UI X/N
동적 확인, (6) 이탈/가정.
