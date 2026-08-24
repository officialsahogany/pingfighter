# 지시문 Q5 — 하이라이트 캡처 레인 자기치유 (피드백5 2항)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `902312d3e`. CI/pre-push 락스텝 236.
- **격리 워크트리**: `D:\codex_tmp\bosspong_hilane_9023` (브랜치
  `codex/fb5-highlight-lane-revival-20260825`).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 원인 (관제탑 프로브 실측 확정)

승리 하이라이트가 가끔 재현버전(합성)으로 재생되는 잔존 버그의 진범:

1. **[유력] 패배-이어하기 리매치 = 캡처 레인 미소생**:
   `reset_for_continue`(flow_driver:569) → match_reset →
   `victory_highlight_recorder.reset()` → `release_all()`이 블릿
   뷰포트·프레임 저장소·_ready를 전부 해체하는데, 소생 API
   (`prewarm_victory_highlight_frame_lane_step`)의 호출자는 부트
   워밍업 step17과 스테이지 전환 로딩 step5 **둘뿐** — 이어하기는 둘
   다 안 탐. 그 판의 승리는 캡처 0장이라 항상 재현 렌더러 선택.
   "가끔씩" = 이어하기한 판. (bc94237c3의 same-stage 호이스트는 스텝
   호출 전제라 이 경로는 수리 범위 밖이었음.)
2. **[중간] 최종 골 RETRY 기아**(bc94237c3 회귀): 골 arm이
   RETRY(뷰포트 퇴화) 시 재큐만 하고 재시도 드라이버가 없어, 매치
   종결로 캡처가 멎으면 큐드 골이 영구 잔존 → 피니셔 미승격.
3. [저] 3연속 실패 fail-closed 이후 골 state 낙하 + 진단 공백
   (미가동 시 fallback_reason 미기록 → 로그가 none).

## 작업

1. **자기치유 드라이버**: 매치 라이브 프레임 틱(서브/라운드 준비
   플로우)에서 `frame_capture.is_available()==false`면
   `prewarm_victory_highlight_frame_lane_step` 프레임당 1회 호출 —
   available이면 즉시 true라 상시 비용 ≈0. 이어하기·F10 리셋·미래의
   신규 진입점(GRT-058 계열)까지 일괄 치유. 전환 로딩 머신 승격안은
   비권장.
2. **큐드 골 재시도**: `_on_frame_post_draw`에서 큐드 골 잔존+pending
   0+in-flight 0이면 재-arm, RETRY 누적 N(예: 30프레임) 초과 시 구
   의미론대로 `_recover_goal_descriptor`로 링 승격 종결.
3. **진단**: attach 0건+not _ready면
   `fallback_reason="frame_lane_not_prewarmed"` 기록 —
   playback_payloads 로그에서 none과 미가동 구분.

## 씰

- 이어하기 소생 씰(신규·RED-first): 실 recorder+frame_capture 가동 →
  실 reset 경로 → 소생 드라이버 관통 → N스텝 내 available·이후 골
  frame 부착 단언. 반증=드라이버 제거 시 전 클립 state+재현 렌더러.
- RETRY 기아 씰(신규·현행 RED): 링 적재→골 요청→뷰포트 퇴화 강제→
  수리 후 큐드 골 소멸+링 승격 1클립 단언.
- 진단 레그: 미가동 픽스처의 fallback_reason ==
  frame_lane_not_prewarmed.
- 기존 락스텝: victory_highlight_frame_product_smoke 등 하이라이트
  씰 GREEN 유지. 신규 씰 CI/pre-push 양 목록 등재.
- 게이트: 포커스드 스모크 → `-Paths` 경고 → 헤드리스 로드 → diff →
  라이브 1판(패배→이어하기→승리) 녹화 하이라이트 확인 보고.

## 보고

워크트리·커밋 해시·씰 종단선 원문·라이브 확인 결과·미해결.
