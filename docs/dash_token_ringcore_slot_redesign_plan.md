# 대쉬토큰 · 퍽슬롯 · 링코어 슬롯 재설계 (슬라이스 플랜)

Status: DESIGN LOCKED (배선 대기). 2026-07-08 세션 합의.
⚠️ **부분 대체(2026-07-15):** 본 문서의 "슬롯 6→8 고정"은
`docs/perk_slot_expansion_handoff.md`의 **동적 한도(기본 6 + 슬롯 확장 퍽으로
최대 10)**로 대체됐다 — 현행 권위는 `runtime_perk_catalog.gd`의
`get_perk_slot_limit()`과 `perk_slot_limit_smoke`다. 이 문서의 슬롯 상한
수치를 새 배선에 역지시로 쓰지 말 것. 대쉬 증폭 슬롯-비용 스택/링코어
슬롯화 항목은 별도 트랙.
Owner split: 이 문서 = 설계/디렉션(Claude). GDScript 배선 = 사용자/Codex.
Claude = 배선 후 적대적 리뷰 + 반증검증. (feedback_design_slice_review_division)

## 0. 왜 하는가

- 대쉬는 이 게임의 핵심 동사(체감 ~절반). 그런데 대쉬 토큰 **수량 성장 채널이
  `증폭` 퍽 하나(+3 하드캡)뿐**이라, (a) 무지성 필수픽 → 빌드 다양성 붕괴,
  (b) 성장 천장이 런 초중반에 닫힘, (c) 패시브→퍽 전환으로 채널이 오히려 수렴.
- 해결: 증폭을 **슬롯-비용 스택형**으로 리프라이싱 → 대쉬 성장이 "슬롯을 태우는
  빌드 결정"이 되고, 슬롯이 자동 브레이크라 토큰 인플레가 스스로 관리됨.
- 함께: 슬롯 6→8로 대쉬 재설계가 만든 슬롯 압력 상쇄 + 여유. 링코어를 대쉬토큰과
  같은 논리로 슬롯화(비대칭: 강화칩은 무료 유지). 링펫 교감 곡선/티어 정리.

## 1. 확정 결정 (LOCKED)

| # | 항목 | 결정 |
|---|---|---|
| A1 | `증폭` → 이름/아이콘 교체 | 이름 **`대쉬토큰`**, 아이콘 = 붉은 구슬+토큰 (Codex 작화) |
| A2 | 대쉬토큰 메커니즘 | **슬롯당 +1 토큰** (슬롯 비용 = 레벨). 순수 +1 (재충전 감소 없음) |
| A3 | 대쉬토큰 최대 | **3슬롯(+3)**. base 미변경 시 총 **실전 4 / 테스트 5** |
| A4 | base 대쉬토큰 | **건드리지 않음** (실전 1 / 테스트 2 현행). base→2 부활은 별도 백로그 |
| B1 | 퍽 슬롯 상한 | **6 → 8** |
| B2 | 링코어 퍽 | **슬롯 소비**(티어당 1슬롯) |
| B3 | 강화칩 | **유지 + 슬롯 무료** (비대칭 확정, 나중 재검토 여지) |
| C1 | 교감 레벨 요구 포인트 | flat 50 → **+3/레벨** 상승 곡선 (+ 초반 lump 소스 트림, 수치는 측정 후) |
| C2 | 링코어 티어 | **6티어(×5) → 3티어(cap 10/20/30, ×10)**, `MAX_AFFINITY_LEVEL=30` 유지 |
| C3 | 알 스폰 | **무료**(링코어 불요). 교감 레벨업만 링코어 게이트(현행 tier0=cap0) |

파생 결과(의식하고 갈 것): 링코어 슬롯화 + tier0=cap0 → **링펫 교감/보상 트랙에
발 담그려면 최소 슬롯 1개(티어1) buy-in.** 동행체(전투 존재)는 무료, 깊은 육성은
슬롯 투자 = 의도된 무료/투자 티어 분리. 따라서 **티어1(cap10)은 한 런에 확실히
도달 가능**해야 첫 슬롯이 아깝지 않음. 티어3(cap30)만 스트레치.

## 2. 시스템별 설계 + 배선 지점

### A. 대쉬토큰 퍽 (증폭 재설계)

현행 사실:
- base: `battle_scene_config.get_starting_dash_tokens_for_mode` (DEFAULT 1 / JUNIOR 2) — **미변경**.
- 퍽: `runtime_perk_catalog.gd` `dash_amplification` (max_level 3, `+1/+2/+3`).
- 용량 계산: `runtime_perk_state.gd:1929-1934` = `base + get_runtime_skill_bonus("dash_amplification")`
  이며 `get_runtime_skill_bonus("dash_amplification") = float(level)` → 이미 순수 +1/레벨.
  (미러: `mythic_item_stat_bonus_runtime.gd:200-202`).

배선:
1. 카탈로그 `dash_amplification`: `name` "증폭"→"대쉬토큰", descriptions/detail 갱신.
   max_level 3 유지(슬롯 3 = +3과 일치). id는 유지 권장(세이브/치환 안정) — 표시만 변경.
2. **슬롯 비용 = 레벨** 특례: `count_owned_slot_perks`(`runtime_perk_catalog.gd:1418-1430`)
   에서 이 퍽만 `count += 1` 대신 `count += level`. 그러면 3개 찍으면 `3/8`.
3. **오퍼 필터 정합**: `_filter_perk_slot_budget`(`:1645`)는 지금 "소유 퍽이면
   가득 차도 계속 오퍼"함. 대쉬토큰은 **다음 레벨이 새 슬롯을 먹으므로**, 남은
   슬롯이 0이면 대쉬토큰 레벨업 오퍼도 막아야 함(예외의 예외). 슬롯 여유 있을 때만 노출.
4. 아이콘: `runtime_perk_icon_renderer.gd`(+ mini/symbol 경로) PNG-first 배선.
   Codex 작화 붉은 구슬 토큰. 별칭(alias) 없으면 단일 id라 단순.
5. HUD 표시 무관(토큰 수량은 이미 dash_snapshot `max_tokens` 경로). 오브 렌더러는
   기존 다중 토큰(테스트=2)을 그려봤으니 5까지 OK.

Seal: `dash_token_slot_cost_smoke.gd`
- 대쉬토큰 3회 획득 → `count_owned_slot_perks == 3`, 토큰 용량 `base+3`.
- 슬롯 꽉 참(=8)일 때 대쉬토큰 추가 레벨 오퍼 **suppress**.
- 반증검증: 구(舊) `+1 flat` count로 되돌리면 첫 assert가 FAIL(인플레이스 토글).

### B. 퍽 슬롯 6→8 + 링코어 슬롯화

현행 사실:
- `PERK_SLOT_LIMIT := 6` (`runtime_perk_catalog.gd:11`).
- `is_slot_consuming_perk`(`:1401-1415`) 면제: gold전환 / instant / unlocks_skill /
  **`is_lingpet_ring_core_upgrade`** / `is_lingpet_affinity_chip` / gated-ids / max_level<=0.
- ⚠️ **링코어는 `runtime_levels`에 안 들어감.** 티어는 affinity state `_run_ring_core_tier`
  (`lingpet_affinity_state.gd`)에 별도 저장. 그래서 `count_owned_slot_perks`(runtime_levels
  순회)가 링코어를 자동으로 세지 못함 — 슬롯화의 **가장 까다로운 지점**.

배선:
1. `PERK_SLOT_LIMIT` 6 → **8**.
2. `is_slot_consuming_perk`: `is_lingpet_ring_core_upgrade` 면제 제거(슬롯 소비).
   **`is_lingpet_affinity_chip` 면제는 유지**(강화칩 무료).
3. **링코어 슬롯 카운트 브리지**: `count_owned_slot_perks`에 **run ring core tier를
   더함**(tier N = N슬롯). affinity state에서 `get_run_ring_core_tier()` 읽어 합산.
   `has_open_perk_slot` / `get_perk_slot_status` 모두 이 합산 값을 씀.
4. **링코어 오퍼 슬롯 게이트**: `_append_lingpet_ring_core_upgrade_choice`가 슬롯
   꽉 차면 오퍼 안 하도록(다음 티어가 새 슬롯 소비). early-reserve 로직
   (`LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER`)이 슬롯 예산 위반하지 않게 정합.
5. 8슬롯 UI: 카운터 텍스트는 `get_perk_slot_status`의 `limit` 동적 → 자동. 오브 배열
   (`runtime_perk_overlay_renderer.gd` 부근)이 6-across 하드코딩이면 wrap/scale 보정.
   (Claude가 배선 슬라이스에서 확인 — 위임 5번.)

Seal: `perk_slot_limit_smoke.gd` 확장
- limit == 8.
- 링코어 tier2 → 슬롯 카운트 2, 강화칩 5칩 → 0, 대쉬토큰 3 → 3. 합산 정확.
- 슬롯 8 꽉 참 시 링코어/대쉬토큰 신규 오퍼 suppress, 소유 일반퍽 레벨업은 유지.
- 반증검증: 링코어 브리지 제거하면 "tier2=2슬롯" assert FAIL.

### C. 링펫 교감 곡선 · 링코어 3티어

현행 사실:
- `REQUIREMENT_BY_CURRENT_LEVEL`(`lingpet_affinity_state.gd:60-64`) = 30칸 전부 50.
- `GAIN_TABLE`(`:135-154`): round_commit 5 / ball_hit 8(감소2) / click 20(비행30) /
  hatch 25 / victory 20 / stage_clear 50 / ring_core_upgrade 50.
- 강화칩: `1 + 0.20×칩`, 최대 5칩 = +100% (`:287-288`). ring_core_upgrade 그랜트는 배수 제외.
- 링코어 cap: `LingpetRingCoreRules.get_ring_core_cap_for_tier` = `tier*5`, clamp 30.
  `MAX_RING_CORE_TIER=6`, `MAX_AFFINITY_LEVEL=30`.

배선:
1. **곡선**: `REQUIREMENT_BY_CURRENT_LEVEL` → `50 + 3*idx` (50, 53, 56 … 137).
   L10=77(+54%), 누적 L30 ≈ flat 대비 1.8x. (강화칩 유지가 곡선 가팔라짐을 상쇄.)
2. **초반 lump 트림(측정 후 확정)**: stage_clear 50 / victory 20를 우선 하향,
   grind(ball_hit/round_commit)는 유지. 정확 수치는 income-log 패스(§3)에서.
3. **링코어 3티어**: `LingpetRingCoreRules`
   - `MAX_RING_CORE_TIER` 6 → **3**
   - `get_ring_core_cap_for_tier(tier)` = `clampi(tier*10, 0, 30)` (1→10, 2→20, 3→30).
   - 파급: `LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER`(현 7칸 `[1,1,1,0,0,0,0]`) → 4칸
     (tiers 0-3)으로 리사이즈. affinity state clamp들(`import_run_state`,
     `set_run_ring_core_tier`, `upgrade_run_ring_core_tier`), 플라자
     `RING_CORE_TIER_NAMES`/`RING_CORE_TIER_COSTS` 3티어로 정리.
4. 알 스폰/게이트: **변경 없음**(무료 스폰, tier0=cap0 유지).
5. 강화칩: **변경 없음**(유지).
6. 보상 트랙 매핑(참고): 30레벨 트랙이 3티어와 1:1 (티어1=보상1~10, 티어2=11~20,
   티어3=21~30). "각 링코어 = 다음 10레벨 개방"으로 읽히게 툴팁/표기 정합.

Seal:
- `lingpet_affinity_curve_smoke.gd`: 요구 포인트 L10=77, 누적 L30 = 예상값.
  반증검증: flat 50 배열로 되돌리면 FAIL.
- `lingpet_ring_core_rules` 확장: cap(1)=10,(2)=20,(3)=30, (4↑) clamp 30, tier0=0.

## 3. 튜닝/검증 계획 (배선과 병행)

**핵심 리스크 = 도달 가능성.** 곡선(1.8x 느림) + 링코어 슬롯 비용 + 교감 런-스코프
리셋이 곱해져, 티어2·3 cap이 한 런에 도달 불가하면 "못 오를 천장을 슬롯 주고 산"
trap 픽이 됨.

검증:
1. **income-log 측정**: 대표 런(스테이지1~N)에서 실제 획득 포인트 총량 분포 수집.
2. 곡선 + lump 트림 수치를 이 분포에 맞춰 확정 — 목표:
   - 티어1(cap10) = **거의 확실히 도달**(첫 슬롯 값어치 보장)
   - 티어2(cap20) = **노력하면 도달**
   - 티어3(cap30) = **스트레치**(장기 런/집중 투자)
3. 강화칩이 이 "채우는 속도" 레버 — 트림 후에도 강화칩 스택으로 티어2/3가 현실적으로
   당겨지는지 확인.

이 측정 전에는 곡선 슬로프/GAIN 수치를 **최종 확정하지 않음**(blind 튜닝 금지).

## 4. 적대적 노트 / 남은 판단

- **글로벌 파워 크립**: 비-링펫이 6→8로 전투퍽 +2 → 실전/오버클럭 소폭 쉬워짐.
  폭 작음(+2). 난이도 재점검은 후속 백로그.
- **강화칩 비대칭**: 무료 5칩 스택이 offer 풀을 얼마나 채우는지 관찰. 풀이 지저분해지면
  칩 max 하향 or 슬롯화로 재검토(현재는 "cap=슬롯 메이저 / 획득=무료 마이너"로 정당화).
- **링코어 runtime_levels 부재**(§B ⚠️): 슬롯 카운트 브리지가 이 재설계의 유일한
  구조적 난점. 여기 반증검증 반드시.

## 5. 권장 슬라이스 순서

1. **Slice A** — 대쉬토큰 재설계(rename + 슬롯비용=레벨 + 오퍼 게이트 + 아이콘) + seal.
2. **Slice B** — 슬롯 6→8 + 링코어 슬롯 브리지 + 강화칩 유지 + UI 확인 + seal.
3. **Slice C** — 교감 곡선 + 링코어 3티어(코드) + seal. **수치는 §3 측정 후 확정.**
4. **검증** — income-log 측정 → 곡선/트림 최종화 → 라이브 QA(도달 가능성 체감).

각 슬라이스: 백본 + named smoke + 반증검증(인플레이스 토글, `git reset` 금지).
