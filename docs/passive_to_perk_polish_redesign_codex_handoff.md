# 연마 재설계(D6) 코덱스 핸드오프 — item_polish → 퍽 능력치 증폭 (독립 성장축)

기준: `docs/passive_to_perk_conversion_plan.md` D6. 결정 확정 2026-07-08:
**범위 B(전환 일반퍽 + 커먼 퍽), 레벨당 5/10/15/20/25% 곱연산.**
Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

## 배경

`item_polish`(연마)는 COMMON_PERKS 소속 Lv5 퍽, 현재 효과 "패시브 롤옵션 효율
+12~60%" → `get_effective_polish_multiplier()` → `mythic_item_roll_query`가 아이템
롤값에 곱. **패시브가 사라져 flag ON에선 완전 inert.** D6: 삭제가 아니라 "투자한
퍽 전체 능력치를 향상"하는 독립 성장축으로 재설계.

## 설계 (확정)

- **효과(flag ON)**: 투자한 **전환 일반퍽 + 커먼/대쉬 퍽**의 능력치 값을
  **+N% 곱연산 증폭**(Lv1~5 = 5/10/15/20/25%). 유효레벨(초월자의 관/현자의 계약)과
  **독립 축** — 레벨은 값 테이블 입력을, 연마는 그 출력을 곱하므로 두 축이 자연
  곱연산 스택.
- **flag OFF**: 레거시(아이템 롤 효율) 그대로 — 회귀 금지.
- **제외(자동/의도)**: 신화퍽(get_mythic_value 경로, D5 고정옵션), 캐릭터
  전용/unlock/instant/링펫 퍽(별도 축), 연마 자신, 카운트/불리언/비용 키(아래).

## 2개 증폭 초크포인트

### ① 커먼/대쉬 퍽 — `runtime_perk_state.get_runtime_skill_bonus()` 단일점
match 문 값을 var로 받아 **단일 return에서** `* _get_perk_amplify_multiplier(skill_id)`
곱. amplifiable id만 곱, 나머지는 1.0.

- **증폭 대상(13)**: `dash_lightweight`, `dash_module_control`, `dash_jump`,
  `dash_acceleration`, `dash_spirit`, `item_luck`, `item_cooldown_mastery`,
  `item_gauge_mastery`, `item_caffeine`, `common_swiftness`, `common_bulk_up`,
  `common_training`, `perk_boost_charge`.
- **제외**: `item_bag_expansion`·`common_expansion`·`dash_amplification`·
  `perk_laurel_shield`(=`float(level)` 카운트/슬롯/잎), `item_polish`(자신),
  `item_recycle`·`downtown_treasure_map`(경제/드랍율).
- **극성 안전**: 소비자가 `(1 - bonus)`(감속/딜/쿨 감소)로 쓰는 대상은 이미
  `max(0.0, 1.0 - bonus)`로 클램프됨(예 `get_dash_recovery_frames`) — 증폭이
  bonus>1을 만들어도 0으로 안전 수렴. `(1 + bonus)`형은 그대로 강화.

### ② 전환 일반퍽 — 17모듈 로컬 `_get_converted_perk_value` 공용화
현재 17개 `mythic_item_*_runtime.gd`가 각자 로컬
`_get_converted_perk_value(runtime, perk_id, key)`(=level 조회 + `PerkConversionValues.get_value`)
를 둠. `PerkConversionValues.get_value`는 static이라 polish 미접근.

- **신설 공용 래퍼** `runtime_perk_state.get_amplified_converted_value(perk_id, key)`:
  `level = get_converted_perk_effect_level(perk_id)` → `base = PerkConversionValues.get_value(perk_id, key, level)`
  → benefit 키면 `base * _get_perk_amplify_multiplier(perk_id)`, 아니면 base.
- **17모듈 이관**: 각 로컬 `_get_converted_perk_value`가 이 공용 래퍼를 호출하도록
  변경(대부분 기계적, runtime 참조 이미 있음). 로컬 헬퍼 시그니처/호출부 유지 가능.
- **benefit vs 제외 키(극성)** — 연속 benefit-% 키만 증폭. 제외:
  - **비용 키(낮을수록↑)**: `sensor.auto_dash_cooldown_sec`,
    `soul_burst.soul_burst_gauge_cost`, `shrapnel_armor.gauge_cost`.
  - **불리언/고정(max_level1 or 상수)**: `gravitybelt.gravitybelt_instant_movement`,
    `revival.revival_count`, `smartphone.smartphone_auto_use_enabled`,
    `speedgear.speedgear_turn_decel_multiplier`.
  - **정수 카운트**: `sensor.auto_dash_token_count`, `shrapnel_armor.shard_count`,
    `shrapnel_armor.knockback_level`.
  - 나머지 연속 % / range / duration / 확률 키 = 증폭.
- **권장 구현**: 안전을 위해 **명시 allowlist**(증폭할 perk_id+key 쌍 집합)를
  `PerkConversionValues`에 상수로 두고, 목록 외 키는 무조건 비증폭(신규 퍽 키가
  실수로 증폭되는 사고 방지). denylist(위 제외셋만 빼고 전부 증폭)도 허용하나,
  그 경우 "신규 비용/카운트 키 추가 시 제외셋 갱신" 규칙을 주석으로 못박을 것.

## 승수 accessor + 카탈로그 + 게이팅

- **신설** `runtime_perk_state._get_perk_amplify_multiplier(id)`:
  flag OFF → 1.0(증폭 없음). flag ON → `id`가 amplifiable면
  `1.0 + item_polish_level * 0.05`(Lv1~5=1.05~1.25), 아니면 1.0.
  - 레벨 = `runtime_skill_levels.get("item_polish")` **RAW**(연마 자신은 유효레벨
    보너스 비대상이 자연스러움 — 필요 시 제외셋 등재). 재귀 없음(연마는 전환
    퍽/커먼 퍽 값만 곱하지 자기 값을 안 읽음).
- **카탈로그** `item_polish` descriptions: flag 체계 라이브이므로 **증폭 문구로 교체**
  ("투자한 아이템·기본 퍽 능력치 +5/10/15/20/25%"). 레거시 문구는 flag OFF 전용이나
  라이브가 ON이므로 신문구가 유저 노출. detail도 갱신.
- **레거시 보존**: `get_effective_polish_multiplier`/`get_base_polish_multiplier`
  (아이템 롤 곱)는 **그대로** — flag OFF에서 살아있음. 신규 증폭은 별도 accessor.
- **다국어**: item_polish name/summary는 이미 있음. **증폭 문구로 바뀌므로 퍽 경로
  로컬(PERK_NAME/PERK_SUMMARY 7개 언어) 갱신**(문구 수정=다국어 동기화 규칙).

## 슬라이스 분할 (권장)
- **P1**: 초크포인트① + accessor + 카탈로그/다국어 + flag 게이팅 + 스모크 + 반증.
  (단일점, 저위험 — 먼저 커밋)
- **P2**: 초크포인트②(공용 래퍼 + 17모듈 이관 + benefit allowlist) + 스모크 + 반증.
  각 슬라이스 독립 리뷰/커밋. 한 슬라이스로 묶어도 되나 P2가 크므로 분리 권장.

## 범위 제외
- 신화퍽 증폭(D5). 캐릭터 전용/unlock/instant/링펫 퍽. 연마 자신.
- 비용/불리언/카운트 키. flag OFF 레거시 경로(아이템 롤 곱).
- 밸런스 재튜닝(수치는 확정값 5~25%, 라이브 후 조정 가능).

## 스모크 (신설: `godot/tests/perk_polish_amplify_smoke.gd`)
- [ ] flag ON: 연마 Lv3 → 커먼 퍽(예 `common_swiftness` bonus)이 정확히 ×1.15
- [ ] flag ON: 연마 Lv5 → 전환 퍽 benefit 키(예 `star_detector.star_bonus_pct`
      또는 실소비자 스탯)가 ×1.25, cost 키(`soul_burst_gauge_cost`)는 불변
- [ ] flag ON: 제외 id(`item_bag_expansion` 카운트, `item_polish` 자신,
      신화 `sacred_laurel.leaf_count`) 증폭 안 됨
- [ ] flag ON: 유효레벨(초월자의 관)과 연마가 독립 곱연산 스택(레벨↑ × 연마↑)
- [ ] flag ON: 연마 Lv0 → 모든 값 ×1.0(무증폭)
- [ ] flag OFF: item_polish 레거시 아이템 롤 곱(`get_effective_polish_multiplier`)
      12~60% 그대로, 신규 증폭 미적용(회귀)

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)
1. `_get_perk_amplify_multiplier`를 항상 1.0 반환하도록 임시 고정 → "연마 Lv3
   커먼퍽 ×1.15" 레그 RED → 복원
2. benefit allowlist에서 한 cost 키 제외를 임시 해제(cost도 증폭되게) → "cost 키
   불변" 레그 RED → 복원
3. flag 게이팅 제거(flag OFF에서도 증폭) → "flag OFF 레거시 그대로" 레그 RED → 복원

## 트랩 노트
- **자기재귀 없음 확인**: 연마 승수는 전환/커먼 퍽 값에만 곱하고 item_polish 자체
  값(`get_runtime_skill_bonus("item_polish")` = 레거시 롤 보너스)엔 안 곱해야 함
  (amplifiable 셋에서 item_polish 제외 필수).
- **이중 증폭 금지**: 커먼 퍽은 get_runtime_skill_bonus, 전환 퍽은 get_value 경로로
  disjoint. 한 퍽이 두 경로를 안 타는지 확인(perk_laurel_shield=커먼,
  sacred_laurel=신화 별개).
- **극성 클램프**: `(1-bonus)` 소비자는 기존 max(0,…) 클램프 의존 — 증폭으로
  bonus>1 되어도 안전하나, 신규 소비자 추가 시 클램프 누락 주의.
- **owner set() 스키마 트랩**: 신규 owner 동기화 키 필요 시 중단·보고(현재는
  기존 게터 경로 재사용이라 불필요 예상). UTF-8 BOM 금지, `.agents/skills/` 미러
  수동 편집 금지.
- **핫패스**: get_runtime_skill_bonus/get_value는 매프레임 다수 호출 — 승수 계산은
  O(1)(레벨*상수 + 셋 lookup) 유지, 딕셔너리 deep-copy/스캔 금지.

## 자동커밋 (통과 시)
- 스코프 헝크분리(blanket 금지). runtime_perk_state.gd의 무관 resume-safety 램프
  헌크 **제외**. language_settings_data.gd의 hologram_disk 등 무관 WIP 제외. 로컬만.

## 완료 보고 형식
(1) 변경 파일 + 2초크포인트 주입 지점 + accessor, (2) amplifiable/제외 셋 + benefit
allowlist, (3) 신설 스모크 결과 원문, (4) 반증검증 3건 RED→GREEN, (5) flag OFF 회귀
무변화 + 자기재귀/이중증폭 없음 자가확인, (6) 이탈/가정.
