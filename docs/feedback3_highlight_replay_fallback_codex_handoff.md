# 지시문 G — 하이라이트 리플레이 임시 장면 (피드백3 13항)

- **발행**: 관제탑 2026-08-23. 기준 HEAD `d7d5c5b6b`. CI/pre-push 락스텝 226.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb3_replay_d7d5` (브랜치
  `codex/fb3-highlight-fallback-20260823`). 병렬 안전.
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.
- ⚠"합성 폴백 존치"는 핸드오프 §12.4의 기록된 설계 결정(GRT-053) — 과제는
  **폴백 제거가 아니라 폴백 빈도 축소**다.

## 실측 진단

임시 장면 = 상태 레인 합성 재생(절차 공+직선 궤적+실루엣) — 프레임
레인(760x750 블릿, 72Hz readback, 링 144슬롯/2s, 클립당 최대 108프레임)이
페이로드를 못 붙인 클립의 fail-closed 폴백. 원인 후보(확신도순):

- **[A·확인된 설계 경로] 3연속 캡처 실패 시 전량 파기** —
  `victory_highlight_frame_capture_state.gd`
  CONSECUTIVE_CAPTURE_FAILURE_THRESHOLD=3(:25). `_fail_runtime`이 링과
  **이미 승격된 프레임 클립까지 전부 폐기** → 그 매치 리플레이 전체가
  합성. 실패 노출은 매치 길이 비례라 듀스·연장전에서 확률 최대(사용자
  스크린샷이 연장전 직후 — 정합). crop_sync_failure는 창 최소화/이동으로
  루트 뷰포트 rect 퇴화 시 즉시 3연속.
- **[B·구조 공백(추정)] 동일-스테이지 재대전 프리웜 스킵** — 재생
  종료/리셋마다 `release_all()`이 블릿 뷰포트 파괴(_ready=false), 부활은
  스테이지 프리웜 체인뿐인데
  `stage_runtime_resources_prewarmed_for_stage==current_stage`면 체인
  통째 스킵(`battle_boot_resource_prewarm_controller.gd:337`) → 그 매치
  캡처 0건, 전 클립 합성. F9 재시작·탑 동일 층 재진입이 재현 후보.
- [C·저확률] in_flight(캡 2) 고착·첫 득점이 링 적재 전.

## 작업

1. **진단 선행(수정 전 원인 확정)**: 연장전 1판 + 동일 스테이지 재대전
   1판을 각각 관측 — 로그 `victory_highlight_frame_capture_fallback`
   (reason·phase)이 있으면 A, 로그 없이 합성이면 B. 디버그 인자
   `--victory-highlight-frame-capture-debug` 활용. 결과를 보고에 명시.
2. **A 완화**: `_fail_runtime`에서 `_clear_frame_storage()` 대신 **이미
   승격된 `_frame_clips_by_id`는 보존**하고 신규 캡처만 중단(보존 상한은
   MAX_RETAINED_CLIP_COUNT=3으로 이미 캡). 추가로 crop_sync_failure 중
   '뷰포트 퇴화'(visible rect≤0·텍스처 null)는 파이프라인 결함이
   아니므로 실패 카운트 없이 skip-and-retry로 분리(GRT-011 계열 — r10-4
   커밋이 같은 교훈 기록).
3. **B 봉합**(1에서 확정 시): frame lane 부활을 스테이지 프리웜 게이트와
   분리 — 매치 시작점에서 `is_available()==false`면 prewarm_step 재구동
   보장(스테이지 동일 여부 무관). ⚠GRT-003/042: 재구축은 전투 첫
   프레임이 아니라 로딩/리셋 시점. ⚠재부활 시 `_frame_capture_state`
   재부착(:1253)도 동반. ⚠F10 계약(`221e3503a`): release/teardown의
   '트리 부착 시 항상 queue_free()' — free()로 되돌리면 재진입 프리즈
   재발.
4. **관측성**: 재생 시작 시 클립별 페이로드 유무 + 마지막 fallback
   reason 릴리스 로그 1줄(향후 사용자 보고 대조용).

## 씰

- (i) 동일-스테이지 재대전 시퀀스 RED 반증 재현 → GREEN 전환 레그,
  (ii) 런타임 임계 폐기 후 기승격 클립 보존 레그
  (`failure_recovery_smoke` 확장), (iii) 뷰포트 퇴화 skip-and-retry 레그.
- victory_highlight 3씰: CI `godot-ci.yml:152~154`·pre-push `:156~158`
  락스텝 — 신설·개명 시 두 목록 동시.
- ⚠선재 RED: `victory_highlight_replay_smoke`의 softlock 단언은 r10-4
  이후 선재 RED로 귀속되어 있음 — 이번 건에 오귀속 금지.
- ⚠성능 계약(§14.9 무할당·마감 GREEN): 보존 로직의 메모리 상한
  (LOGICAL_MAX_BYTE_COUNT) 재검토.

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 실 승리 1판 캡처(실녹화 재생 확인). 보고=원인 판정
(A/B/C, 로그 증거)·워크트리·커밋 해시·씰 종단선 원문·미해결.
