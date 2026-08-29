# 지시문 Z14 — 필드 아이템 스폰 예산이 검증용 잠정값(0~1)으로 방치됐다

- **발행**: 관제탑 2026-08-29. 기준선 = 본 트리 HEAD.
- **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.

## 사용자 보고

> 전투 노드 진입 시 초반에 액티브 아이템이 **1회만 스폰되고 그다음 스폰되지
> 않는** 버그.

## ★진범 (관제탑 확정 — 재조사 금지)

`tower_ascent_tuning.gd:21~22`

```gdscript
const TEMP_REGULAR_SPAWN_BUDGET_MIN := 0
const TEMP_REGULAR_SPAWN_BUDGET_MAX := 1
```

`active_item_field_spawn_scheduler._reset_regular_spawn_budget()` 이 버티컬
슬라이스에서 `randi_range(0, 1)` 로 판당 예산을 굴린다 — **노드당 0 또는
1개.** 예산 소진 시 `consume_regular_spawn_due` 가 영구 false.

★**이 값은 밸런스가 아니다.** `docs/tower_ascent_phase_a_report.md:128~129` 가
명시한다 — "판당 총량 owner 와 0-cap 부정 레그 **검증용**", "재굴림·cap 소진
구조를 최소 범위로 **검증용**". 도입 커밋 3360dd863(8/16)이 구조를 정식화하며
넣은 잠정값이 실전 값으로 상향되지 않고 방치된 것이다.

## 요구

1. **실전 예산으로 상향.** 관제탑 제안(사용자 조정 가능 잠정값):
   `MIN := 2`, `MAX := 4`.
   근거: 스폰 간격 20~50초(`SPAWN_DELAY_*`) × 통상 전투 길이에서 자연 상한이
   4~8회이므로 2~4면 "총량 제한 구조"의 의미는 유지하면서 체감 고갈이 없다.
   ⚠**예산 구조 자체(-1 무제한화)를 없애지 마라** — 구조는 8/16의 의도다.
2. **최소 보장**: MIN ≥ 1 이 되면서 "판에 하나도 안 나오는" 케이스가
   사라진다. 0-cap 부정 레그 씰은 `debug_set_regular_spawn_budget_for_test(0)`
   로 유지하라(튜닝값과 분리).
3. `TEMP_` 접두사와 phase A 보고서 표를 실전 값 기준으로 갱신하라.
   ⚠보고서의 "검증용" 행은 이력이므로 지우지 말고 갱신 행을 추가하라.
4. **비버티컬(일반 모드) 무제한(-1) 경로 무변** 확인.

## ★같이 확인만 (수리 금지 — 별개 선재 RED)

스폰 계열 씰에 선재 RED 가 있다. **이번 범위가 아니다** — 재현 사유만
기준선 확인으로 구분 보고하라.
- `active_item_field_spawn_queue_smoke` — legacy queue 포털/럭키코인 레그
- `item_field_spawn_pool_smoke` — "candidates should include active items",
  트레저맵 mythic 파리티
- `active_item_field_spawn_scheduler_smoke` — "effective delay override"

## 씰 요구

1. 새 예산 범위 계약(MIN/MAX 상수와 롤 범위 일치). 0~1 복원 시 RED 반증.
2. **최소 1 보장 씰**: 버티컬에서 예산 0 이 굴려지지 않는다.
3. 소진 구조 씰(기존): debug 예산 0/1 주입 레그로 유지.
4. **CI/pre-push 락스텝** — `comm` 대조 사라진 항목 0.

## 게이트·보고

공통 게이트 동일(로그 사전 복사·-AllowDuringPlay·게임/에디터 종료 금지·
기준선 RED 구분). 보고: 커밋 해시 · 채택 값과 근거 · 선재 RED 3건 구분 ·
씰 종단선과 반증 · 미해결.
