# 지시문 Q3-수정 — fail-closed 경로 재수리 (관제탑 검토 회신)

- **발행**: 관제탑 2026-08-25. 대상: 브랜치
  `codex/fb5-arrived-boss-identity-20260825`(워크트리
  `D:\codex_tmp\bosspong_arrival_4755`)의 `0cbaa4aa1` 위 **추가 커밋**.
  기존 커밋 amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: 정체성 통일 코어(권위 단일화·아이콘·별칭·스냅샷 수리)는
  APPROVE — 재작업 금지. 아래 F1·F2만 수리하고 F3~F7 처리.

## [P0] F1 — fail-closed 복귀가 런을 죽인다

- `_finish_tower_boss_route`는 `_finish_vertical_slice` **내부**에서
  실행되어 이미 `_finish_callback`/owner/registry가 해제되고
  `_active=false`인 상태다. 그 뒤 `open_map_overlay`는 재무장을
  건너뛰고 true를 반환 — 열리는 지도는 **관전용**(포인터 선택=표시
  전용, 경로 확정은 셀렉터 볼 충돌 소유)이라 경로 확정도, 콜백
  디스패치도 불가. 전투도 리셋도 경로도 없는 **완전 정지**.
- 수리: 실패 시 플로를 **재무장**해 실제로 조작 가능한 지도/ROUTE_AIM
  상태로 복귀시킬 것(콜백·owner·registry 재바인딩 포함), 또는 재무장이
  불가하면 레거시 리셋으로 안전 착지. "잘못된 전투 안 열림"만으로는
  불충분 — **복귀 후 플레이 가능**이 계약이다.

## [P0] F2 — 좁힌 가드가 '직전 보스 재전투'를 되살린다

- 새 가드는 `encounter.is_empty() AND arrived_node 비어있지 않음 AND
  kind∉COMBAT`일 때만 리셋. 나머지 빈-encounter 종료는 전부
  `_rebuild_arrived_tower_encounter`로 흘러 **현재 서 있는 노드**를
  해석해 전투를 시작한다. `_selected_target_id` 미존재(그래프 스왑
  잔여) 시 `_current_node_id`=직전 노드 → **직전 보스 재전투**(지시문
  금지 불변식이 다른 경로로 부활). `_confirm_run_settlement` 경로도
  같은 구조로 잠재(현재는 arity-0 콜백 덕에 미발현).
- 수리 불변식: **`encounter.is_empty()`이면 어떤 경우에도 전투를
  합성하지 않는다** — 리셋 또는 F1의 재무장 복귀만. `_rebuild`는
  encounter가 비어있지 않은 정상 도착 경로에서만.

## [P1] F3 — 아이콘 해석이 매 프레임 레지스트리 신규 생성+전수 스캔

- `resolve_boss_id_for_node`가 호출마다
  `TowerAscentBossRegistry.new()`. standin 없는 모든 노드(상점·휴식·
  수련·샘터·파계승 등)에서 `get_standin("")`→12층 전수 딥카피 스캔이
  **노드마다·프레임마다** 발생(GRT-032/003, `_draw` 할당 금지 위반).
- 수리: 빈 slot_id/비전투 kind 조기 반환 + 레지스트리 멤버 승격 +
  노드 id별 아이콘 메모이제이션. 씰: 드로우 경로 할당/스캔 부재 단언.

## [P2] 동반 처리

- **F4**: 스냅샷 복원에서 노드 1개 수리 실패가 **런 전체 폐기**로
  이어짐(슬롯 제거/개명 세이브 호환 케이스). 해당 노드만 강등하고
  런은 복원되게.
- **F5**: `_reopen_tower_map_after_failed_transition`의 bool 반환이
  양쪽 호출부에서 버려져 하드 실패가 무음 — 경고 로그 1줄.
- **F6**: `map_icon_boss_id` 오버라이드 제거로 QA 도구의 missing-icon
  프로브가 죽은 필드를 주입 중 — 오버라이드 복원 또는 프로브 재조준.
- **F7**: 폴백 씰이 FailedTransitionFlow 페이크라 F1 소프트락을 보지
  못함 — **실 플로 관통 레그로 교체**하고 "복귀 후 조작 가능"(경로
  확정 또는 리셋 도달)을 단언. F2 반증: 빈 encounter로 종료 시 어떤
  전투도 시작되지 않음 + 직전 노드 재전투 0.
- **캡처 누락**: 지시문이 요구한 "각시탈 노드 도착→각시탈전 개시"
  라이브 캡처 경로가 보고에 없음 — 첨부 필수.

## 게이트·보고

기존 씰 5종 + 개정 폴백/F2 레그(+RED 반증) → `-Paths` 경고 →
헤드리스 로드 → `git diff --check` → 캡처 2장(각시탈 도착→전투,
전환 실패 후 복귀 조작 가능 상태). 보고=추가 커밋 해시·씰 종단선
원문·캡처 경로·F3~F7 각각의 처리 여부·미해결.
