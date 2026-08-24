# 지시문 S1 — 샘터 개편 1단계: 알 교환/흡수 UI 복원 + 봉인 로스터 은퇴

- **발행**: 관제탑 2026-08-24. 기준 HEAD `63f8cb8f4`. CI/pre-push 락스텝 229.
- **격리 워크트리**: `D:\codex_tmp\bosspong_spring_s1_63f8` (브랜치
  `codex/guardian-spring-rework-20260824`). S1→S2→S3 **같은 워크트리 순차**
  (파일 겹침: spring node·egg runtime·modal state). 커밋은 단계별 분리.
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.
- **⚠WIP 지뢰**: 본 트리 `lingpet_egg_runtime.gd`는 목린/마운트 WIP(M)가
  얽혀 있으나 tower_sealed 분기와는 무접촉 실측 — 워크트리(HEAD) 기준
  수정 후 통합 충돌은 관제탑이 해소. `lingpet_overflow_choice_overlay_host.gd`
  의 미커밋 1줄(N성 표기)은 건드리지 말 것.

## 배경 (실측 확정)

커밋 ff2668292가 탑 런 중 알 부화를 교환/흡수 오버플로 UI 대신 샘터
봉인 로스터로 우회시켰다(tower_sealed). 사용자 판정: **원래 UI로 복원**,
봉인 로스터(샘터 교체/흡수의 재고)는 후속 단계에서 새 시스템(엘리트
상점)으로 대체되므로 은퇴한다.

## 작업

1. tower_sealed 조기 반환 3사이트 중화: `lingpet_egg_runtime.gd`
   `_finish_regular_hatch`/`_begin_overflow_hatch`의
   `_record_guardian_discovery_at_reveal` → tower_sealed 분기(:2516~2520·
   :2544~2548)와 아이템 알 경로(:608~610 consume_ready_absorb 취소).
   권장 지점=`tower_ascent_flow_node_progress.record_guardian_identity_reveal`
   이 런 중에도 tower_sealed:false를 반환하게(코덱스 도감 기록은 유지) —
   호출부 3곳 개별 수술보다 정본 한 곳이 안전.
2. 복원 결과: 탑 런 중 로스터 만석 부화 → 기존 교환/흡수 선택 UI
   (`lingpet_overflow_choice_state` 경로)가 그대로 열림. 이 경로는 비탑
   컨텍스트에서 현재도 살아 있어 재배선 불요 — 관통 확인만.
3. 봉인 로스터 은퇴: `_finish_tower_sealed_hatch`·
   `activate_tower_sealed_guardian`·`absorb_tower_sealed_guardian`와 spring
   node의 OP_SWAP/OP_ABSORB(`_apply_swap`:644·`_apply_absorb`:682) 및
   해당 카드 빌드를 제거. ⚠spring 노드 자체(영혼소환술 습득·강화)는
   S2가 개편하므로 이번 단계는 **swap/absorb 소거만** — 최소 diff.
4. 세이브/정산 정리: guardian_state 스키마의 `sealed_guardians` —
   export는 빈 배열 유지(하위 호환), restore는 구 세이브의 잔존 봉인
   수호령을 조용히 폐기(도감 기록 유지)하는 마이그레이션 1줄. 정산
   `sealed_guardians` 행 집계(`tower_ascent_settlement_state.gd:144~147`)
   는 활성 수호령만 세도록 축소.
5. `guardian_egg_access_policy`(영혼소환술 보유 게이트)는 **불변** —
   이번 복원과 무관.

## 씰 (기존 3단언 개정 필수)

- `tower_ascent_guardian_spring_node_smoke.gd`: 봉인 라우팅 단언(:269)·
  실 리빌 진입 단언(:378)·소스텍스트 단언(:411)을 새 계약(런 중에도
  오버플로 UI 경로 유지)으로 개정. swap/absorb 레그 제거.
- 신규 레그: 탑 런 활성+로스터 만석 픽스처에서 실제 부화 경로 관통 →
  오버플로 선택 상태가 열림(begin_main_overflow 도달) 단언 + 비탑
  컨텍스트 동작 불변 음성 레그. 아이템 알 경로 형제 레그.
- 구 세이브(sealed_guardians 비어있지 않음) restore 마이그레이션 레그.
- 게이트: 포커스드 스모크(+복원 전 RED 반증) → `-Paths` 경고 →
  헤드리스 로드 → `git diff --check`.

## 보고

워크트리·커밋 해시·씰 종단선 원문·개정 단언 목록·미해결. S1 GREEN 후
같은 세션에서 S2 착수.
