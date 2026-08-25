# 지시문 Q3-수정2 — F4 초크포인트 무력화·F6 미처리·F3 과잉 클리어

- **발행**: 관제탑 2026-08-25. 대상: 브랜치
  `codex/fb5-arrived-boss-identity-20260825`의 `866a6c73b` 위 **추가
  커밋**. amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: F1 재무장·F2 불변식·F5·F7은 APPROVE(재작업 금지).
  아래 3건만 수리하면 통합한다.

## [P1] F4 — 강등이 단일 레인 관문을 막아 런을 불가능하게 만든다

- 실측: 모든 층 관문은 **단일 레인 초크포인트**(피드백2 8항 확정,
  `map_generator._choose_gatekeeper_lane_count` = 1). 그런데 강등이
  아무 노드에나 `route_disabled`를 붙이고,
  `route_candidate_policy.filter_available_indexed`가 그것을 후보에서
  제거 → 관문 직전 행의 **가용 표적 0** → ROUTE_AIM인데 맞힐 대상이
  없는 소프트락(F1이 없애려던 바로 그 계열). 세션 스모크 출력이
  `node=floor_03_gatekeeper` 강등을 실제로 찍고 있다.
  ※`restore_snapshot`에 생산 호출자가 아직 없어 **잠재**지만, F4가
  존재하는 이유인 세이브 호환 시나리오에서 정확히 발생한다.
- 수리: **관문/초크포인트는 절대 route_disabled 금지** — 해당 층의
  살아있는 슬롯으로 재시드하거나 NPC 노드로 전환. 추가로
  `_enter_route_aim`에 **가용 표적 0 가드**(정의된 착지: 레거시 리셋
  또는 재시드)를 둔다.
- 씰: 강등 후에도 입구→터미널 도달 가능 단언(전 시드/강등 케이스),
  가용 표적 0 픽스처에서 정의된 착지 도달 + RED 반증.
- P3: 강등의 `skipped` 플래그가 원장(`mark_boss_skipped`)과 어긋난다
  — 노드 플래그만 세우고 원장은 그대로. 의미 통일 또는 플래그 제거.

## [P2] F6 — 지시 대상이 아닌 파일을 고쳤다

- 지시문이 지목한 것은 **QA 도구**의 프로브
  (`tools/tower_ascent_map_overlay_visual_qa.gd:279`가 여전히
  `node["map_icon_boss_id"]`를 주입 — 그 필드의 권위 읽기는 기저
  커밋에서 제거됨). 실제로 고친 것은 그 필드를 쓰지도 않던 **씰의
  missing_node**였다.
- 결과: `-MissingIconProbe` 실행이 실제 보스 아이콘을 그려놓고
  파일명만 MISSING_ICON으로 저장 — 공허 증거(GRT-040).
- 수리: QA 도구 프로브를 **실 standin 해석 경로**로 재조준(존재하지
  않는 슬롯/보스 id를 주입해 폴백 라벨이 실제로 그려지게) 하거나,
  프로브를 삭제하고 폴백 씰을 헤드리스로 대체.

## [P2] F3 — 리셋 훅이 텍스처 캐시까지 비워 `_draw`에서 동기 로드

- `flow_state` 리셋 → 렌더러 → `map_iconography.clear_cache()`가
  노드 메모뿐 아니라 `_texture_by_path`·`_load_attempt_by_path`까지
  비운다. `_reset_runtime_state`는 **전투 재진입마다** 도는데, 이후
  텍스처가 `_draw_map_node`/`_draw_fullscreen_map_node` 안에서
  `ResourceLoader.load`로 다시 당겨진다(AGENTS: `_draw` 동기 로드
  금지).
- 수리: 리셋 지점에서는 **노드 메모만** 무효화
  (`invalidate_boss_node_cache()`), 텍스처 캐시는 유지(경로가
  콘텐츠 주소라 스테일 불가).
- P3: 빠른 경로가 combat 노드당 프레임마다 `strip_edges()` 2회
  할당 — 가능하면 제거. 씰이 리터럴 grep이라 헬퍼 경유 재도입을
  못 잡는다는 점도 보완 권장.

## 게이트·보고

기존 씰 5종 + F4 도달성/가용표적 레그(+RED 반증) + F6 폴백 증거
재확보 → `-Paths` 경고 → 헤드리스 로드 → `git diff --check`.
⚠이 워크트리는 임포트 캐시 부족으로 tower 계열 16종이 환경 RED다 —
**기저 대조로 귀속 분리**해 보고(코드 회귀 아님을 명시).
보고=추가 커밋 해시·씰 종단선·F4 재시드 방식·F6 재조준 결과·미해결.
