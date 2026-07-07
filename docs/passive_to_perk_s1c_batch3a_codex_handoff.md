# S1c 배치③a 코덱스 핸드오프 — 발동형/상태군 7종 순수 게이트 전환

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3) §4-A / §7-2.
선행: S1c 배치①② PASS — 확립된 패턴 2개를 그대로 재사용한다:
수치 게터 게이트(OFF=장착+롤 / ON=facade 레벨>0 → `get_value`) +
불리언 효과-활성 게이트 `is_*_effect_active()`(OFF=equipped / ON=레벨>0,
소비자는 effect_active 우선 + equipped 폴백).
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

**주의: 센서(위험감지센서)는 이번 배치가 아니다.** 자동대쉬 토큰 재설계가
섞여 있어 배치③b로 분리됐다. 이번 실행에서 sensor는 한 줄도 건드리지 않는다.

## 합격 조건 (배치①②와 동일)

1. 플래그 OFF(기본)에서 게임 규칙 완전 무변화.
2. 플래그 ON에서 7종의 효과가 퍽 경로로 완전 대체.
3. **기존 발동/상태 메커니즘 무변경** — 확률 롤 지점, 상태머신, 타이머,
   발사체/필드/VFX 로직은 그대로 두고, 그 안에 들어가는 **수치**와
   **활성 조건**만 게이트한다.

## 배치③a 대상 7종

| perk_id | 효과 (발동 구조) | 값 key | 비고 |
|---|---|---|---|
| adversity_armor (역경의힘) | 실점 후 다음 라운드 확률 발동 → 무적벽 | trigger_chance_pct, invincible_duration_sec | 서브 공속 증가 등 고정 부수 효과는 활성 게이트만 타면 유지 |
| shrapnel_armor (파편사출) | 패들 히트 시 확률 발동 → 파편 발사 | trigger_chance_pct, shard_count, knockback_level, gauge_cost | gauge_cost는 reverse 레인 |
| soul_burst (소울버스트) | 토큰 없을 때 게이지 소모 풀대쉬 | soul_burst_gauge_cost | reverse 레인. **기존 씰 `soul_burst_dash_boost_free_dash_smoke.gd` GREEN 유지 필수** (무료대쉬 시 게이지 미소모 트랩) |
| rainbow_fur_glove (무지개장갑) | 히트 시 확률 발동 → 진행 쿨 즉시 감소 | rainbow_glove_trigger_chance_pct, rainbow_glove_cooldown_reduction_pct | |
| venom_mist_gauntlet (독안개) | 화랑킥 감염 → 보스 가드 시 독안개 | mist_trigger_chance_pct, mist_duration_sec | **바이퍼 전용** — 아래 캐릭터 가드 항목 |
| gravitybelt (무중력화) | 즉시 최대속도/즉시 정지 (상시 특성) | gravitybelt_instant_movement [1.0] | max_level 1 — 불리언 게이트만 |
| speedgear (보정제어) | 방향전환 감속 2.5배 (상시 특성) | speedgear_turn_decel_multiplier [2.5] | max_level 1 — 불리언 게이트 + 고정 배수는 값 테이블에서 읽기 |

## 범위 (이번 실행)

1. 7종의 수치 게터 게이트 전환 (①② 패턴).
2. 불리언 효과-활성 게이트 신설·전환:
   - gravitybelt / speedgear: 이동 컨트롤러가 소비하는 특성 조건 →
     `is_*_effect_active()` 전환 (이동 계산식 자체는 무변경)
   - adversity / shrapnel / soul_burst / rainbow_glove / venom_mist: 발동
     진입 조건이 `is_*_equipped` 게이트면 동일 전환
3. **독안개 캐릭터 가드**: 기존 경로의 바이퍼 가드가 어디에 있는지(장착
   제한만인지, 런타임 캐릭터 체크가 별도인지) 확인하고, ON 경로가 **같은
   가드를 공유**하는지 검증. 기존에 런타임 캐릭 체크가 없다면(장착 자체가
   불가능해 불필요했던 구조) ON 경로에서 비-바이퍼가 퍽 레벨>0을 가질 때의
   동작을 확인해 보고 — 방어 가드 추가가 필요해 보이면 **추가하지 말고
   보고만** (오퍼 restriction이 1차 방어선, 정식 결정은 리뷰에서).
4. 우회 경로 전수 감사 (①②와 동일): 7종 각각 게터/효과-활성 헬퍼를 거치지
   않는 장착·롤 직독 소비자를 grep, 전환 vs 유지(UI/스냅샷/S3 영역) 분류 보고.
5. 스모크 신설 + values_smoke 갱신 (아래).

## 범위 제외 (하지 말 것)

- **sensor(③b), 윤회·반칙호루라기·스마트폰(④), 신화 12종(⑤)**
- 발동 확률 롤 방식 변경 (per-opportunity 락 등 기존 구조 유지 —
  CLAUDE.md per-frame 확률 롤 트랩의 기존 처리를 신뢰하고 건드리지 않음)
- 무적벽/파편/독안개의 상태머신·VFX·충돌 로직 리팩터링
- 획득 경로(S2), UI(S3), 마이그레이션(S5), 라이브 플래그 ON

## 스모크

### 신설: `godot/tests/perk_conversion_gate_batch3a_smoke.gd`
- [ ] OFF-parity: 7종 (장착+롤 픽스처 → 게이트 전과 동일)
- [ ] ON Lv1/Lv5 수치 (1레벨 static 2종은 활성 시 고정값 — speedgear 2.5)
- [ ] ON 레벨0 / item-only: 비활성 (수치 + 불리언 양쪽)
- [ ] ON item+perk: 완전 대체
- [ ] 불리언 양방향: ON+퍽만 → 특성 활성 / OFF+장착 → 기존대로
      (gravitybelt·speedgear는 이동 아웃컴 값으로 검증 — 플래그가 아니라
      실제 가속/감속 결과)
- [ ] 독안개 캐릭터 가드: 기존 가드 구조에 맞춘 레그 (③-3 확인 결과 반영)
- [ ] 실 발동 소비자 레그 최소 각 1개: 역경 발동 파라미터가 무적벽 상태에
      들어가는 경로, 파편 발사 파라미터, 소울버스트 게이지 소모량,
      무지개장갑 쿨 감소 적용량
- [ ] 플래그 시작/종료 OFF 복원

### 기존 씰 의도적 갱신: `perk_conversion_values_smoke.gd`
parity fixture에서 **adversity_armor 제거** → 배치③a 스모크로 이관.
**sensor는 유지** (③b까지의 마지막 안전망). 보고서에 명시.

### 회귀 유지
- `soul_burst_dash_boost_free_dash_smoke.gd` **반드시 GREEN** (OFF 경로 증거)
- 배치①② 씰 + catalog/values 스모크 GREEN
- 7종 관련 기존 포트/아이템 스모크 (역경·파편·독안개·gravitybelt·speedgear
  계열 — 발견되는 것 전부) GREEN
- 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. gravitybelt 불리언 게이트의 ON 분기를 임시로 equipped 조회로 되돌림 →
   "ON+퍽만 → 특성 활성" 레그 RED → 복원
2. adversity_armor trigger_chance의 OFF 분기를 퍽 경로로 강제 →
   OFF-parity RED → 복원

## 트랩 노트

- 발동 확률 수치가 여러 소비처(발동 롤·툴팁·디버그 표시)에 갈라져 있으면
  전부 게이트 게터로 수렴 — 롤 지점과 표시가 다른 소스를 읽는 순간 "표시
  확률 ≠ 체감" 사가가 재발한다.
- 역경의힘: 발동 시점(실점)과 효과 시점(다음 라운드)이 다르다 — 수치를
  발동 시점에 캡처하는지 효과 시점에 재조회하는지 기존 구조를 확인하고
  **그대로 유지** (캡처/재조회 방식 변경 금지).
- soul_burst 게이지 소모는 cost-waiver 트랩(무료대쉬 플래그)과 얽혀 있다 —
  소모 분기 로직은 절대 재배치하지 말고 소모 "수치"만 게이트.
- 핫패스 딥카피 금지, 신규 owner 키 필요 시 중단·보고, UTF-8 BOM 금지,
  `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 아이템별 게이트 지점 목록, (2) 우회 경로 감사 결과(전환 vs
유지 분류), (3) 독안개 캐릭터 가드 구조 확인 결과, (4) 신설 스모크 결과
원문 + values_smoke 갱신 내역, (5) 반증검증 2건 RED→GREEN 증적,
(6) OFF 무변화 자가 확인 진술, (7) 이탈/가정.
