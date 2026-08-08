# 온라인 1v1 MVP 조건부 반려 수정 기록 (2026-08-08)

대상 리뷰: `docs/online_1v1_mvp_wiring_review_2026_08_08.md`

상태: **2차 재리뷰 필수 수정 반영 및 로컬 실행 재검증 완료.** 이 문서는 재리뷰용
변경 대조표이며 LAN/Tailscale 합격 선언이 아니다.

## 1. 필수 findings 대응

| finding | 반영 | 재검증 씰 |
|---|---|---|
| A1 크로스클록 | 호스트 틱과 클라이언트 입력 틱의 직접 비교를 제거했다. 첫 원격 틱은 독립 시계 기준점이며 이후 단조 순서만 판정한다. 틱 점프로 이동량이 늘지 않으므로 리드 상한도 두지 않아 장시간 패킷 공백 뒤 영구 폐기를 막았다. | `online_match_mvp_smoke`: 초기 +767틱 오프셋, 장시간 공백 점프, stale 이동 역행 방지. `online_session_loopback_smoke`: 클라이언트 +180틱 오프셋 실제 ENet 왕복. |
| A6~A9 물리 파리티 | 인라인 각도/가속/캡 계산을 제거했다. `BallUpdateStaticConfig`, `PaddleBounceFrameState`, `PaddleBounceState`의 production resolver group(접촉 형상·각도 가속 감쇠·속도 배율·랜덤 곡선·최소 수직·vertical stall), `PaddleBounceController.apply_rally_speed_cap_progression`을 재사용한다. 서브스텝·공 크기·hitbox padding도 production config에서 읽는다. | `online_match_mvp_smoke`: 60도 config, 12px 서브스텝, 26→36 캡, production stall guard 직접 행동 및 online 경로 spy 관통. |
| A2 틱 잠금 | 세션이 잠금 획득 전 값을 저장한다. layout 경로와 null-layout 폴백 모두 대칭 반납하며 즉시 실패·타임아웃·이탈도 반납한다. layout 잠금 상태는 static으로 바꿔 다른 인스턴스의 그래픽 설정 적용에도 유지된다. | null-layout 72→60→72, begin 실패/타임아웃 unlock 1회, 별도 layout 인스턴스의 SMOOTH/BALANCED/STABLE_MONITOR 및 오프라인 복원 레그. |
| A3 재입장 stale 상태 | 호스트의 새 peer 입장 시 ready/handshake/입력 시계/에지/이벤트/스냅샷/점수·서브·공을 초기화한다. | stale tick 900·READY·4:3 점수를 주입한 뒤 재입장하여 새 handshake/틱 기준/0:0을 단언. |
| A4 타입 컨퓨전 | 고정 wire 스키마의 모든 상·하위 필드에 exact `typeof` 검사를 추가하고 비유한/비정상 수는 패킷 전체 폐기한다. 변환 helper도 타입 검사 후에만 캐스팅한다. 프로토콜 버전은 2로 올렸다. | Dictionary→int, nested Color→score int를 원시 wire로 주입해 빈 decode를 단언. |
| A5 무한 연결 대기 | client connecting 10초, 양측 waiting-ready 30초 제한을 추가했다. 만료 시 transport close, 60Hz 잠금 반납, 표시 가능한 error phase로 진입한다. 로컬 전투가 아직 로딩 중이면 ready 예산을 소비하지 않으며, 끊어진 ENet peer는 재폴링하지 않는다. | 도달 불가 fake client의 timeout/error/close/unlock, 로컬 로딩 전 ready 타임아웃 정지와 로딩 완료 후 bounded timeout을 단언. |

A10 대시 체인은 현 MVP의 `max_tokens=1` 계약상 계속 비활성이다. wire 스키마의
`recovering`/`max_tokens` 불일치는 바로잡았으며 다중 토큰 확장 때 체인 입력을
별도 재검증한다.

## 2. 미검증 P1 목록 대응

- B1~B8: static tick lock, required-owner fail-closed, 입력 hot-path cache peek,
  begin 오류 보존+잠금 반납, direct-main CLI guard, identity transform reset 제거와
  field-bound draw, same-frame input idempotence, countdown snapshot 전송을 반영했다.
- B9: 온라인 씰 3종을 `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1`의 실제 목록에 등재했다.
- B10~B13: MVP 스모크 본문을 deferred `_run()`으로 이동했다. production frame
  controller의 온라인/OFF 양방향 feature-gate 레그, 18틱 보정 수렴 레그, 원시
  extra-field wire 거부 뒤 합법 패킷 수용 레그를 추가했다.
- B14~B15: input collector/renderer owner를 ledger에 추가하고 60Hz 잠금 owner를
  session으로 정정했다.

## 3. 편승 반영한 P2

- 중요 이벤트가 reliable/unreliable 채널 재정렬로 늦게 도착해도 event serial은
  stale snapshot state와 별도로 소비한다.
- disconnected/error phase에서는 권위 시뮬레이션을 진행하지 않는다.
- 대시 snapshot wire의 `recovering`/`max_tokens`를 송수신 양쪽에 일치시켰다.
- 로비 IP 검증, 중복 전환/ESC 경합 방지, 취소 시 온라인 전용 logo-skip 해제를
  추가했다.
- 정상 오프라인 battle에서는 pending 요청 autoload를 최초 한 번만 확인한다.
- 메인 메뉴 온라인 진입에 키보드 `O`, 게임패드 `Y` 경로와 화면 힌트를 추가했다.

## 4. 2차 재리뷰 F1/F2 대응

| finding | 반영 | 재검증 씰 |
|---|---|---|
| F1 상단 클라이언트 좌우 반전 | 상단 충돌을 production 하단 패들의 로컬 좌표계로 Y 미러링해 해석한 뒤 결과 Y만 월드 좌표로 되돌린다. 기본 바운스 각도뿐 아니라 resolver 내부의 랜덤 접촉 회전과 stall 보정까지 같은 로컬 규칙을 통과하므로, 양쪽 모두 패들 오른쪽은 화면 오른쪽·왼쪽은 화면 왼쪽으로 나간다. | 동일 RNG seed에서 상·하단의 오른쪽/왼쪽 끝 타구를 각각 실행하고 X 부호 일치와 정규화 속도의 완전한 Y 대칭을 단언한다. |
| F2 각도 가속 리듀서 누락 | `PaddleBounceFrameState.build()`가 산출하는 production `accel_scale`을 `PaddleBounceState.resolve_velocity()`에 그대로 전달한다. 20°→60°에서 1.0→0.45로 줄어드는 기존 각도 감쇠가 온라인에도 적용된다. | speed-multiplier spy로 60° 끝 타구가 production frame의 감쇠된 `accel_scale`을 정확히 전달하며 무감쇠 rally multiplier보다 작은지 단언한다. |

## 5. 실행 재검증 기록

사용자 플레이 인스턴스 종료 뒤 2026-08-08에 재검증했다.

- 온라인 집중 스모크 3종: **PASS** — `online_match_mvp_smoke`,
  `online_enet_loopback_smoke`, `online_session_loopback_smoke`.
- repo headless load: **PASS** — graceful headless shutdown 확인.
- GDScript warning scan: **대상 범위 PASS / 전체 스캔 기준선 실패**. 온라인 소스
  7개, 온라인 테스트 3개, Vulkan QA 도구 1개는 모두 무경고다. 전체 3417개
  스캔은 기존 `guardian_spirit_rebrand_smoke.gd`의 삭제된 Lingpet 상수 2개와
  `perk_conversion_values_smoke.gd`의 미선언 `level`/`index` 파싱 오류에서
  실패했으며 온라인 변경과 무관하다.
- production `main.tscn` Vulkan capture: **PASS** — Vulkan 1.4.325 Forward Mobile,
  NVIDIA RTX 5070에서 localhost 호스트/클라이언트가 수동 서브 후 랠리에
  진입했고 `test_artifacts/online_match_live_visual_qa.png`를 생성했다. 최종 실행은
  ENet/runtime error가 없었고 온라인 구간에서 `ptick=60`, 렌더 cap 72가 함께
  기록됐다. 냉간 prewarm 경고와 종료 시 ObjectDB leak 경고는 남았으므로 이
  캡처를 leak-clean 증거로 쓰지는 않으며 별도 추적한다.
- LAN / 서로 다른 회선 Tailscale / RTT·손실·지터: 미실행(재리뷰 이후 실기 게이트)
