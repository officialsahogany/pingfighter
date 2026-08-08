# 온라인 1v1 MVP 배선 리뷰 결과 (2026-08-08, Claude 적대 검증 리뷰)

대상: 미커밋 배선 27파일 (+3,296/-55). 계약 정본
`docs/online_1v1_hanmiryang_mirror_mvp_codex_handoff.md` 대비 준수 리뷰.
방법: 7영역 병렬 리뷰(발견 57건) → P0/P1 상위 10건 개별 적대 검증
(CONFIRMED 9 / PARTIAL 1). 검증 상한 초과로 미검증 P1 16건은 §B에 목록.

## 판정: 조건부 반려 — 수정 후 재검증 필요

구조 자체(호스트 전권위·sanitize 화이트리스트·에지 단조 트래커·wire 필드
순서·메인스레드 동기)는 검증에서 클린 판정을 받았다. 그러나 **P0 1건(원거리
실기에서 재현 유력한 소프트락)** 과 **랠리 물리 파리티 위반군(계약 §0 "룰
동일" 위배)**, **씰 미등재/공허-GREEN 위험**이 확정되어 이 상태로 LAN/Tailscale
게이트 판정에 들어가면 안 된다.

## A. 적대 검증 확정 결함 (수정 필수)

### A1. [P0] 크로스클록 틱 비교 → 클라 입력 영구 폐기·서브 소프트락
`online_match_session.gd:386` — 클라 `input_tick`(클라 battle-init부터 계수,
:155)과 호스트 `simulation_tick`(호스트 battle-init부터 계수, :244)은 어떤
핸드셰이크로도 동기화되지 않는 **서로 다른 시계**인데 386행 리드 검증이 직접
비교한다. 트랜스포트/핸드셰이크는 `online_match_runtime.gd:19-23`이 battle-init
게이트 없이 로딩 중에도 구동하므로, **클라이언트가 호스트보다 ~1초(60틱) 이상
먼저 battle-init되면**(머신 간 로딩 비대칭 — 이 저장소의 전투씬 로딩은 수 초
단위·머신 의존) 오프셋이 상수로 고정되어 이후 모든 클라 입력이 폐기된다 →
클라 패들 동결 + 클라 서브 차례(`online_match_simulation.gd:71-81`, serve_edge
원격 공급·타임아웃 폴백 없음)에서 serve_wait 소프트락. 부수: ack_input_tick=0
고정 → 클라가 매 스냅샷 240프레임 이력 재시뮬.
수정 방향: 카운트다운 시작(양측 공통 이벤트)에서 틱 기준 동기화(양측 리셋
또는 호스트 틱 기준 발급). 씰 공백 동반 수정 — `online_session_loopback_smoke`
는 오프셋≈0 락스텝만 돌리고, `online_match_mvp_smoke.gd:269-281`은 이 거부를
정상으로 단언한다(합법적 초기 오프셋 레그 신설 필요).

### A2. [P1] 60Hz 잠금 획득/반납 비대칭 (leak 시 싱글이 60에 고착)
`online_match_session.gd:595` — 획득은 view_layout null이면
`Engine.physics_ticks_per_second = 60` 직접 대입 폴백이 있는데, `stop()`(:83-85)
반납은 layout 경유 단일 경로뿐(폴백·이전 값 저장 없음).
`runtime._ensure_started`(:95) null 가드는 `_view_layout`을 제외. 정상 런에서는
미발동인 방어-경로 결함. 수정: 획득 시 이전 틱 저장 → stop() 대칭 폴백 복원.

### A3. [P1] 상대 이탈 후 재입장 시 stale 상태 미리셋
`online_match_session.gd:314` — 트랜스포트는 재입장을 허용하는데
`_on_transport_peer_joined` host 분기가 phase만 바꾸고
`_remote_ready`/`_last_remote_*_tick`/`_latest_remote_input`을 리셋하지 않음 →
(a) 구 피어의 ready 잔존값으로 새 클라 READY 없이 카운트다운 재시작, (b) 새
클라(틱 1부터)의 입력이 구 피어의 큰 틱 트래커(:400)에 막혀 전부 거부.

### A4. [P1] 프로토콜 타입 컨퓨전 → 원격 크래시(DoS)
`online_match_protocol.gd:398`(+:70,:88-89) — `bytes_to_var` 복원값의 원소 타입
검사가 없어 Dictionary/Array/Vector*/Color/Packed* 를 `int()/float()/bool()`에
넣으면 SCRIPT ERROR로 디코드 체인이 중단된다. `_safe_float` 자체가 `float(value)`
에서 죽어 방어 도달 불가. 수정: `typeof()` 화이트리스트 후 변환, 불일치 시
패킷 폐기(fail-closed).

### A5. [P1] 클라 최초 연결 실패 무한 대기
`online_enet_transport.gd:51` — `get_connection_status()`를 아무도 폴링하지
않고 세션에 connecting/waiting_* 타임아웃이 전무. raw ENet이라
connection_failed 통지 부재 + `start_client()`는 도달 불가 주소에도 OK 반환 →
잘못된 IP 참가 시 "연결 중" 무한 대기, 로비 복구 경로 없음(§B의
session.gd:121 건과 동일 뿌리).

### A6~A9. [P1] 랠리 물리 파리티 위반군 — 계약 §0 "게임 룰은 현행과 동일" 위배
전부 `online_match_simulation.gd`가 싱글 정본 모듈을 조합하지 않고 인라인
재구현한 데서 발생. **수정 방향 공통: 싱글 정본 리졸버 재사용으로 교체**
(`paddle_bounce_velocity_resolver`, `paddle_bounce_speed_multiplier_resolver`,
`paddle_bounce_vertical_stall_guard`, 랠리 캡 progression).

- **A6 (:209) 바운스 각도 산식 상이**: 싱글은 수직 벡터 회전(최대 60°,
  `MAX_BOUNCE_ANGLE`), 온라인은 sin→x·y=±1 정규화(최대 ≈40.9°) + 랜덤
  커브(±35°/±20°)·contact_shape 전부 생략 — 가장자리 타구가 ~19° 더 수직.
- **A7 (:219) 랠리 캡 progression 부재**: 싱글은 타격당 +0.5, 26→최대 36
  (`_apply_rally_speed_cap_progression`); 온라인은 26 고정 캡 — 긴 랠리 체감
  상이.
- **A8 (:211) 가속 상수 리터럴 사본**: 1.024/1.084/0.8/0.35/0.2×2가
  `paddle_bounce_speed_multiplier_resolver.gd:5-9`의 사본(0.2 두 개는 서로 다른
  파생값이라 상수 참조만으로도 불충분 — 리졸버 함수 재사용이 정답). 대조 씰
  없음 → 리밸런스 시 온라인만 무에러로 어긋남.
- **A9 (:30) 수직 스톨 가드 미배선**: `vertical_bounce_count`가 선언·리셋만
  존재. hit_pos=0 정중앙 타구는 정확히 (0,±1)이 되고 커브/스톨 가드(±3°/±15°)
  전부 없음 → vel.x==0이면 벽 반사도 없어 수직 왕복 고착 가능. 저장소는 스톨
  무승부 재서브를 제거했으므로(round_restart 제거 결정) 온라인의 유일한 방어선
  이 스톨 가드다 — 필수.

### A10. [P1→잠복] 대시 체인 에지 드랍 — 현 계약 범위에서는 무해
`online_paddle_state.gd:41` — 대시 중 도착한 dash_edge를 버리고 체인 판정을
안 하지만, 1차 매치는 퍽/아이템 OFF + max_tokens=1 하드락이라 관측 가능한
행동 차이 없음(PARTIAL 판정). 스킬/퍽 확장 시 재방문 필수 — 잠복 결함으로
기록만.

## B. 미검증 P1 (검증 상한 초과 — 수정 전 코드 재확인 필요)

1. `battle_view_layout.gd:56` — 잠금 플래그가 인스턴스 변수인데 클래스의 다른
   조율 상태는 static → 다른 인스턴스 경유 apply는 잠금을 못 봄.
2. `online_match_runtime.gd:95` — `_ensure_started`가 view_layout/renderer null
   미검사 → fail-open (A2와 동일 뿌리).
3. `battle_scene_input_controller.gd:96` — 싱글 중에도 unhandled input마다
   온라인 모듈을 **인스턴스화 게터**로 fetch — 핫패스 peek(get_cached_instance)
   규칙 저촉.
4. `online_match_session.gd:72` — begin() 실패 시 online_match_active=true·60Hz
   잠금 잔존, runtime은 반환값 무시.
5. `game_selection_state.gd:28` — CLI 인자만으로 pending 온라인 요청 arm →
   메뉴 경유 일반 싱글 전투가 온라인 모드로 하이재킹될 수 있음.
6. `online_match_renderer.gd:25` — `draw_set_transform` 후 IDENTITY 리셋 =
   저장소 금지 패턴(트랩 봉인됨).
7. `online_match_input_collector.gd:14` — 물리 프레임당 get_snapshot 멱등성
   가드 없음(에지 이중 소비 트랩 — 기존 리더 계약 위반).
8. `online_match_renderer.gd:79` — 클라 카운트다운이 3초 내내 "0.0"
   (countdown_remaining이 스냅샷 스키마에 없음).
9. `.github/workflows/godot-ci.yml:51` — **온라인 씰 3종이 CI·pre-push 양쪽
   미등재** → 기본 파이프라인에서 영구 미실행.
10. `online_match_mvp_smoke.gd:87` — 14개 레그 전부 `_init()` 직접 실행(표준:
    `call_deferred("_run")`만) → 레그 중간 SCRIPT ERROR 시 공허-GREEN.
11. `online_match_mvp_smoke.gd:302` — 계약 §6-⑤ 게이트 씰 실체(아이템 스폰·퍽
    모달·수호령 no-op + OFF 레그) 부재.
12. `online_match_mvp_smoke.gd:253` — §6-⑥ 수렴 레그 부분 구현(지연 주입 수렴
    없음).
13. `online_session_loopback_smoke.gd:62` — 악성 패킷 레그 변별력 0
    (화이트리스트 제거해도 GREEN — tick 게이트가 먼저 폐기).
14. `docs/godot_module_ownership_ledger.md:10834` — 신규 8모듈 중
    input_collector·renderer 2개 미등재.
15. `docs/godot_module_ownership_ledger.md:10845` — 틱 잠금 소유자가 문서
    3곳에서 runtime으로 오기(실제=session).
16. `online_match_session.gd:121` — A5와 동일 뿌리(타임아웃 부재) 중복 등재.

## C. P2 (33건 요약 — 전문은 리뷰 로그)

- 시뮬 파리티 소계: 각도 리듀서 생략(:213), 접촉 형상 규칙 생략(:208), 스냅샷
  폴백 리터럴 8/7(:100), 대시 recharge 300/토큰 상한 리터럴(:141), 고정틱 내
  벽시계+시드 없는 RNG(재현성, :145), 득점 이벤트 source_x가 항상 중앙(:241).
- 세션/전송: noteworthy 스냅샷 채널 재정렬 시 이벤트 유실 가능(:434),
  disconnected 중 시뮬 계속 → 부재 상대에 득점·finished 승격(:254),
  KIND_DISCONNECT 송신자 없음(:378), sanitize↔wire 스키마 필드 불일치
  (recovering/max_tokens, protocol :345).
- 런타임/상태: 플래그 OFF 싱글에서 매 프레임 ×3 pending 요청 노드 조회
  (frame_controller :443), 요청 소비가 모듈 검증보다 먼저(fail-open, runtime
  :86), owner.set() 미선언 키 no-op 위험(runtime :110),
  skip_battle_logo_once 미복원(:137), 로비가 선택 상태 덮어쓰고 미복원(:74).
- UI/입력: IP 형식 검증 부재(:44), 로비 한국어 문구 하드코딩 다수(다국어
  미배선 — 목록화됨), OnlineButton 게임패드/키보드 라우팅 누락(main_menu
  :893), ESC가 disable 게이트 우회(:28), serve_edge가 화면 전역 좌클릭(:19),
  ui_* 내장 액션 폴링이라 싱글 키셋과 어긋날 수 있음(collector :15).
- 렌더/씰: get_render_state 매 프레임 전체 스냅샷 재구축+딥카피(renderer :29),
  고정 틱 씰 STABLE_MONITOR 복원 레그 없음+매직 -2(:215), 물리 바이패스 역방향
  레그 없음(:284), Y반전 씰이 렌더러 소비까지 미관통(:184), visual QA 전역
  워치독 없음(tools :19), 핸드오프 §5 문구와 구현 방식 서술 불일치(§8 정정
  필요), 런북 버튼 라벨 `참가`↔`IP로 참가` 불일치.

## D. "선행 검증 통과" 재평가

localhost 왕복·랠리 진입·헤드리스 로드·Vulkan 캡처 통과는 유효하나, (1) 씰
3종이 CI/pre-push 미등재(B9), (2) mvp_smoke가 공허-GREEN 취약 구조(B10), (3)
변별력 0 레그(B13), (4) A1을 정상 동작으로 단언하는 레그 존재 — 이므로 현
GREEN은 계약 §6 씰 충족의 증거로 인정하지 않는다. 수정 후 표준 러너 관통 +
등재까지가 한 단위.

## E. 권장 수정 순서

1. A1(P0 크로스클록) + 관련 씰 레그 신설 — 원거리 게이트 전 필수.
2. A6~A9 물리 파리티 — 정본 리졸버 재사용으로 일괄 교체(개별 수치 패치 금지).
3. A2~A5 + B1~B8 수명주기/방어 경로.
4. B9~B13 씰 구조/등재 — CI 락스텝 포함.
5. C는 수정 슬라이스에 편승 가능한 것만(문서 정정 B14~15·§8 포함).

---

## F. 2차 재리뷰 판정 (2026-08-08, 수정 22파일 검증)

대조표 `online_1v1_mvp_wiring_review_resolution_2026_08_08.md`의 주장을 코드로
검증. 판정 37항목: **RESOLVED 33 / REGRESSION 1 / NOT_RESOLVED 1 / PARTIAL 2.**
A1(P0)은 확정 해소 — 크로스클록 비교 제거·단조-only·틱 무관 이동량·ack 보존을
코드와 씰(오프셋 777/180 레그, 수정 전 코드에서 RED였을 구성) 양쪽으로 확인.
A2~A5·A7~A9·B1~B13·오프라인 회귀 5종도 해소 확인.

### F1. [P1·REGRESSION] 클라 수평 조작 거울 반전 — A6 수정이 유발한 신규 결함
`online_match_simulation.gd:254` — 상단(클라) 패들 반사에
`outgoing_direction=+1`을 그대로 넘겨 production 회전식
`Vector2(0,+1).rotated(hit_pos·60°)`가 `x=−sin` — **패들 우측 접촉이 월드
좌측으로 발사**된다. 세션 뷰 미러는 Y만 반전이라 클라 체감이 "우측으로 맞추면
좌상향"으로 호스트와 좌우 반전 — 계약 §0 미러 대칭 위반, 실플레이에서 즉시
체감. 수정: 상단 패들은 회전각 부호 반전(또는 상단 결과 x 반전)으로 양측
`x부호 = hit_pos 부호` 유지 + 양측 대칭 씰 레그.

### F2. [P1] 각도 가속 리듀서 미반영 (원 C 항목 재승격)
`online_match_simulation.gd:258` — accel_scale에 싱글의
`_get_angle_accel_multiplier`(20°→60°에서 1.0→0.45)가 빠져 가장자리 타구 가속
초과분이 싱글 대비 최대 약 2.2배. 공속 억제 3대 레버(캡·감쇠·각도 리듀서) 중
하나가 통째로 누락 — frame_state 재사용 또는 동일 곱 추가.

### F3. PARTIAL 2건
- 오프라인 전투 per-frame 자동로드 조회: runtime 층은 1회화됐으나
  `battle_scene_frame_controller.gd:434-455`가 음성 결과를 캐시하지 않아 매
  프레임 ×3 조회 잔존 — `_get_online_match_runtime`에 1회성 음성 캐시.
- 로비 선택 상태 복원: 취소 경로는 해소, 매치 진입 후 복원 경로 부재(경미).

### F4. 신규 P2 (11건 요약)
static 잠금의 비-ESC 이탈 leak 회복 경로 부재(:511)·null-layout 폴백 static
미설정(production 도달 불가)·finished 후 peer_left가 승패 표시 파괴(:690)·
스냅샷당 1이벤트 슬롯 유실+채널 추월(:576)·CLI bare 상대경로 가드 과엄격
(:48)·feature-gate 씰=단일 카운터 relabel(:575)·155.0 자기참조 단언+기하
리터럴 4파일 사본(:374)·입력 게이트 순서 씰이 private 직접 호출(:602)·죽은
플래그 `_remote_input_clock_initialized`·장시간 공백 중 stale move_dir 활주·
`battle_view_layout.gd` 창 지오메트리 개편 혼입(온라인 무관 WIP).

### F5. 커밋 헝크 분리 경고 2건
- `paddle_bounce_controller.gd` diff에 허공환영(스매셔) 선행 WIP 헝크 동거
  (`_restore_void_phantom_suppressed_speed`) — 온라인 슬라이스에 편승 금지.
- `battle_view_layout.gd` diff에 온라인 무관 창 지오메트리 개편 혼입 — 동일.

### F6. 잔여 게이트
F1·F2 수정 → 플레이 모드 종료 후 스모크 3종+헤드리스+경고+Vulkan 실행(현재
전부 미실행 — 정적 검증만 완료) → localhost/LAN/Tailscale 실기.
