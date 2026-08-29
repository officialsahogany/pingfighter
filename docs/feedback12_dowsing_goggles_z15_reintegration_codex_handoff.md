# 지시문 Z15-재통합 — 천안결·천기보도 후보를 Z16 신구조 위로 재정착

- **발행**: 관제탑 2026-08-29. **새 기준선 = 본 트리 `71dbf1300`** (Z16 보상픽
  대개편이 이미 착지된 HEAD다). **새 격리 워크트리 + 격리 브랜치.**
- 선행 산출물: 기존 후보 커밋 2개 `414c89d27410169bc0101fee613c4b4c792af603`
  (천안결), `b591c023993f7093da48228d6b5f31d0187a4515`(천기보도).
  **구현 내용 자체는 관제탑 검수 통과다(11개 항목 전부).** 문제는 Z16(보상픽
  v3 대개편)이 먼저 착지하면서 생긴 통합 부채다. 관제탑이 본 트리에서 병합
  가착지 후 게이트를 돌려 아래 부채를 실측했고, 착지를 되돌렸다.

## 작업 1 — 재정착(rebase/cherry-pick)

두 커밋을 새 기준선 위로 올려라. 예상 충돌은
`godot/scripts/tower_ascent/tower_reward_pick_state.gd` 1곳뿐이며, 관제탑이
검증한 해소는 이렇다.

1. `_get_effective_reward_pick_cost`를 Z16이 신설한
   `_is_mugong_replacement_required` 뒤에 **둘 다 보존**으로 배치.
2. 콜사이트 3곳: `build_view_model`의 choice 루프에 live_cost 주입(+가격
   텍스트 갱신), `_purchase`(v3 신형)의 cost 라인, `_get_purchase_disabled_reason`
   의 muhon 비교. 이 병합본은 워닝 스캔·헤드리스 로드 GREEN까지 확인됐다.
3. 새로고침(refresh)·교체(replacement) 경로는 fusion kind가 아니므로 훅
   불필요 — 단 회귀로 단언하라(아래 작업 2-a에 포함).

## 작업 2 — ★통합 부채 2건 수리 (관제탑 실측 RED)

**a. `treasure_map_fusion_cost_smoke.gd` — v3 구매 흐름에서 전면 RED.**
증상: `transaction cost: got -1`(구매가 아예 커밋되지 않음),
`purchase must commit once` 실패, `same-screen ... fusion cost: got 3 expected 2`
(뷰모델 실효비용 미반영). 픽스처가 v2 보상픽 상태를 전제로 구매를 구동해서다.
Z16 v3의 실제 API(변경된 `_purchase` 시그니처, `_purchase_refresh`/교체 분기,
v3 오퍼 구조)에 맞춰 픽스처와 구동부를 재작성하라. **씰의 검증 의도(3/2/0/0
비용·같은 화면 즉시 갱신·FlowEconomyProgress→RunState 실차감·거래 이력)는
그대로 유지한다.** 추가로: 새로고침 카드·교체 경로가 천기보도 할인을 받지
않는 부정 레그를 하나 넣어라.

**b. `tower_reward_pick_smoke.gd`의 천기보도 픽스처 4레그 RED.**
`Treasure Map Lv.N fixture must expose exactly one fusion card`(Lv.0~3) —
v3 오퍼 빌더에서는 융합 카드가 정확히 1장 나온다는 픽스처 전제가 깨진다.
v3 결정론(시드/정책 주입)으로 융합 카드 1장을 보장하는 픽스처로 바꾸거나,
융합 카드가 있는 오퍼를 직접 구성해 단언하라.

## 작업 3 — ★커밋 누락 수습 (반쪽 착지)

구 워크트리(`D:\codex_tmp\bosspong_feedback12_dowsing_goggles_z15_bcd97a3f7`)에
**`godot/tests/dowsing_goggles_port_smoke.gd` 갱신(+6-6)이 워크트리에만 있고
커밋에 빠져 있다.** 그래서 본 트리 병합 시 구 기대값(44.0)과 새 런타임
(45.8=40x1.145)이 충돌했다. 이번 재통합 커밋에 포함하라.

## 알려진 선재 RED (이 작업 탓 아님 — 분리 보고)

본 트리는 **Z15 병합 이전(Z16-only) 상태에서도** 아래가 RED다. 본 트리
런타임에 미커밋 WIP(1.145 폴리시 계열)가 살아 있어 깨끗한 워크트리와 다르다.

- `perk_polish_amplify_smoke` (HEAD판 기대 1.10 계열 vs 본 트리 런타임 1.145)
- `dowsing_goggles_port_smoke` 의 field-spawn pool 노출 레그 계열

네 깨끗한 워크트리에서는 GREEN일 수 있다. 착지 판정 시 관제탑이 선재 원장
으로 분리한다. 네 재정렬 기대값(gold_digger 14x1.145 등)이 **커밋된 카탈로그
정본과 일치**한다는 성질은 유지하라.

## 게이트·보고

- CI/pre-push: 기준선은 **259/259**다. 네 2건 삽입 후 **261/261**, `comm`
  대조로 사라진 항목 0.
- 포커스드 스모크(+반증 재실행) → `run_warning_scan.ps1 -Paths` →
  `run_headless_load_check.ps1` → `git diff --check`.
- ⚠헤드리스/스모크 전 `godot/logs` 통째 복사. 래퍼는 `-AllowDuringPlay`
  선언 + 고유 `--log-file`. **게임·에디터 종료 금지. 본 트리 편집·통합 금지.**
- 보고: 커밋 해시(재정착본) · 부채 2건 수리 종단선 · 누락 파일 포함 확인 ·
  CI 261 대조 · 선재 RED 분리 목록 · 미해결.
