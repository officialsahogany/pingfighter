# 온라인 1v1 한미량 미러전 MVP — Codex 배선 핸드오프 (rev1, 2026-08-08)

상태: **스펙 확정 · 구현 미착수.** 이 문서가 온라인전 MVP의 정본이다.
조사·리뷰 경위: Claude 4방향 조사 → Codex 읽기 전용 리뷰(조건부 승인, P0 2건
정정) → 사용자 결정 확정. 정정 전 조사 초안의 결론(72Hz 고정 틱, 레거시 위치
릴레이 재사용, "코어 상태 전부 BattleSceneState")은 **폐기**되었으므로 이 문서와
충돌하는 이전 서술은 무시한다.

## 0. 목적 / 1차 범위

원격 상대와의 실시간 1v1 기술 검증. 게임 룰은 현행과 동일, 캐릭터는 한미량
(내부 id `smasher`, 셀렉트 id `ufo_player`) 미러전으로 한정한다.

1차 매치 룰 (사용자 확정):

- 한미량 vs 한미량. **양측 패들 155px + 동일 기본 능력치** (상단이라고 보스
  100px 계열을 재사용하지 않는다).
- 현행 **7점제 · 6:6 듀스 · 목표 상한 10** — 정본은
  `godot/scripts/core/match_score_state.gd` (`WIN_GOAL=7`, `DEUCE_TRIGGER=6`,
  `DEUCE_GOAL_MAX=10`, 사다리 static `resolve_deuce_goal`). 점수 상수를 복사하지
  말고 이 모듈을 읽는다.
- 활성: 이동 · 대시 · **수동 서브**.
- 비활성: 스킬 · 아이템 · 수호령(링펫) · 퍽 · 필드 드랍 · 보상 · 관련 모달 전부.
  입력 스키마에 해당 필드를 **예약해 두는 것은 허용**하되 1차 매치에서 호스트는
  무시한다.
- 상단 표시용 정면(front-facing) 아트는 **합격 조건에서 제외** — 기존 rear 시트
  그대로 상단에 그려도 기술 검증은 통과다.

비범위 (1차에서 하지 않음): 매치메이킹 · 릴레이/NAT 우회 배포 · 재접속/끊김 복구
UX · 모바일(현재 `export_presets.cfg` Android `permissions/internet=false`) ·
스킬 동기화(차기: 호스트 권위 이벤트로 1개씩 추가) · 정면 전투 시트.

## 1. 검증 게이트 3단 (사용자 확정)

| 게이트 | 환경 | 판정 |
|---|---|---|
| 개발 게이트 | 한 PC, 인스턴스 2개 (`127.0.0.1`) | 개발 중 상시 |
| 중간 게이트 | 서로 다른 PC, 동일 LAN 사설 IP | 통과 필수 |
| **원거리 합격** | **서로 다른 인터넷 회선의 두 PC + Tailscale 접속** | **최종 합격 판정** |

- LAN 통과만으로 원거리 검증을 **대신하지 않는다**. 사람과 한 번만 시험할 수
  있다면 원거리 Tailscale을 선택한다.
- Tailscale은 **원거리 기술 시험망**이며 출시망이 아니다. 배포용 연결(noray /
  Steam P2P / Epic EOS)은 차기 결정 — `MultiplayerPeer` 추상화로 이행 가능하나
  각각 시그널링/로비·인증/오케스트레이션 서버가 추가된다는 점을 전제한다.

## 2. 아키텍처 — 호스트 전권위

### 2.1 신규 owner 모듈 (기존 모듈에 인라인 금지)

- `online_match_session` — 매치 상태기계(로비/카운트다운/랠리/득점/듀스/종료),
  peer 역할 배정, 아래 게이트 플래그의 단일 소유자.
- 전송 어댑터 — `ENetMultiplayerPeer`를 감싸는 계층. 연결 수립/해제, 패킷
  직렬화, 시퀀스 관리만 담당. 게임 로직 무지(無知).

### 2.2 데이터 흐름

클라이언트 → 호스트, **입력 의도만** 전송 (위치·결과값 전송 금지):

```
InputFrame {
  tick: int,            # 온라인 시뮬 틱 번호
  move_dir: int,        # -1/0/+1
  dash_edge: bool,
  serve_edge: bool,
  # 예약 (1차 매치에서 호스트 무시):
  skill_edge, item_edge, guardian_edge
}
```

호스트: 양측 패들 이동·충돌·공·점수·서브를 **전부 호스트가 판정**한다.
클라이언트가 보낸 어떤 위치/쿨다운/판정값도 신뢰하지 않는다 (레거시
`pingfighter.py:199343→177738`의 "최종 x 대입" 구조는 **재사용 금지** — 순간이동
·속도 조작이 그대로 통과하는 구조였다).

호스트 → 클라이언트, 전송 전용 스냅샷:

```
MatchSnapshot {
  tick: int,
  ball_pos, ball_vel, ball_active,
  p_host: {paddle_x, paddle_vel, dash_state},
  p_client: {paddle_x, paddle_vel, dash_state},
  score: {host, client, deuce_mode, deuce_goal},
  serve: {waiting, owner_side, banner_timer},
  match_phase
}
```

- **MatchSnapshot은 신설 스키마다.** 필요한 상태가 한 모듈에 있지 않다:
  공/패들 = `battle_scene_state.gd`, 점수 = `match_score_state.gd`, 서브 =
  `round_flow_state.gd:10` (`waiting_for_serve`/`player_serves`), 대시 = 캐릭터
  상태 객체. 각 정본에서 **취합**해 만들고, 수신 측도 각 정본에 **분배**한다.
- 직렬화는 바이너리(`PackedByteArray` 또는 Godot 기본 직렬화)로. 레거시의
  TCP+JSON 매 프레임 풀 상태 방식은 재사용 금지.

### 2.3 클라이언트 표시 규칙

- **자기 패들: 로컬 예측 + 호스트 스냅샷 보정(reconciliation).** 입력 즉응은
  예측으로 얻는다 (레거시처럼 권위를 클라로 넘겨서 얻지 않는다).
- **공·상대 패들: 스냅샷 보간.** 예측 금지(1차), 오차 누적 시 스냅 보정.
- **Y축 반전은 표시(카메라) 계층 전용.** 시뮬레이션 좌표계는 호스트 기준
  단일 좌표계이며, 클라이언트 화면에서만 자기 패들이 하단에 오도록 반전한다.
  반전 대상: 좌표·속도 y부호·서브권 표시·(차기) 이펙트 방향. 레거시의 반전
  규칙(`pingfighter.py:199392-199419`, 서브 대기 중 공속 0 강제 노하우 포함)은
  **표시 규칙 참고 자료로만** 쓴다.

### 2.4 역할 중립 P2 계층

상단 자리에 `boss_*` 키·모듈을 재사용하지 않는다. `side`/`peer_id` 기반의 역할
중립 상태로 원격 한미량에게 하단과 동일한 몸집(155px)·이동·대시 규칙을 준다.
주입 지점 참고:

- 입력 리더 시임: `battle_update_player_control_deps_builder.gd:44-57`의
  registry 주입 — 원격 측은 "네트워크 수신 InputFrame을 반환하는 리더"로 대체.
- 보스 AI 시임(`battle_scene_actor_update_driver.gd:132`)은 **이번 MVP에서는
  쓰지 않는다** — 보스 경로는 폭 100px·X스칼라 `boss_vel` 등 비대칭 전제가
  박혀 있으므로, P2는 플레이어 이동 규칙의 두 번째 인스턴스로 세운다.

## 3. 시뮬레이션 틱 — 고정 60Hz (P0 계약)

- **온라인 매치 중 시뮬레이션 틱 = 60Hz 고정.**
- 근거: 이 게임의 속도 단위는 px/frame(60fps 기준)이고 물리 경로가
  `fps_scale = delta * 60.0` (`battle_scene_actor_update_driver.gd:29,128`)을
  쓰므로, 60Hz에서 `fps_scale=1.0`으로 단위 체계와 정합한다.
- **렌더/그래픽 설정과 완전 분리한다.** 현재
  `battle_view_layout.gd:491-521 _apply_physics_ticks_for_render_cap`이 그래픽
  설정에 따라 `Engine.physics_ticks_per_second`를 런타임 변경한다
  (SMOOTH=60 / BALANCED=72 / STABLE_MONITOR·MONITOR=모니터 주사율 동기,
  clamp 30~120). 온라인 매치 동안 이 경로가 **온라인 시뮬 틱을 절대 건드리지
  못해야 한다.** 구현 방식(온라인 중 엔진 틱 60 강제+종료 시 복원, 또는 렌더
  틱과 분리된 accumulator 고정 스텝)은 Codex 재량이되, 계약은 아래 씰로
  봉인한다.
- **스냅샷 전송률은 시뮬 틱과 별도 설정**으로 둔다 (제안 기본값 30Hz, 튜닝
  값 — 60Hz 시뮬과 독립적으로 조정 가능해야 함). 입력 전송은 매 시뮬 틱.

## 4. 입력 시임 통합

이동은 `smasher_input_reader.get_snapshot()` dict 경유라 리더 교체로 충분하지만,
아래는 리더 밖에서 `Input`을 직접 읽으므로 온라인 매치에서는 단일 InputFrame
경유로 통합해야 한다:

- 서브: `serve_flow_controller.gd:99` 마우스 직접 폴링 → `serve_edge`로.
- vision_modifier: `battle_scene_actor_update_driver.gd:52` — 판정에 영향 없는
  로컬 시각 옵션이면 로컬 유지 가능, 판정 영향이 있으면 InputFrame 경유.
- 액티브 아이템 슬롯 키(`active_item_effect_update_driver.gd`): 1차 비활성이라
  게이트로 차단하면 됨.

참고: 프로젝트 액션맵은 `guardian_toggle`/`vision_modifier` 2개뿐
(`project.godot:41-53`)이라 원격 입력을 `Input.parse_input_event()` 합성으로
주입하는 방식은 불가 — 스냅샷/InputFrame 치환이 유일 경로다.

## 5. 싱글플레이 전제 기능 차단 게이트

`online_match_active` 플래그를 config 빌더 한 곳에서 닫는다 (CLAUDE.md
"Two-Update-Path Context-Flag Trap"의 `victory_loot_phase_active` 선례 준수 —
게이트를 각 기능에 흩뿌리지 말 것). 차단 대상: 필드 아이템 스폰, 수호령 소환·
교감, 퍽 선택 모달, 신화 획득 시네마틱, 승리 전리품 페이즈, 하이라이트
리플레이, 스테이지 보스 이벤트류. 로컬 전용 pause 분기
(`battle_frame_flow_controller.gd`의 update_effects-only 분기들)가 온라인 중
시뮬을 멈추지 않는지 같이 감사한다.

## 6. 씰(스모크) 목록 — 전부 표준 러너 관통

1. **고정 틱 씰 (P0)**: 온라인 매치 활성 상태에서 그래픽 설정을
   SMOOTH(60)/BALANCED(72)/STABLE_MONITOR 각각으로 변경해도 온라인 시뮬 틱이
   60으로 유지됨을 단언. 반증 레그: 온라인 비활성 시에는 기존
   `_apply_physics_ticks_for_render_cap` 동작이 그대로임(회귀 방지).
2. **권위 씰**: 클라이언트가 조작된 위치/판정값을 실어 보내도 호스트 상태가
   입력 의도 외에는 불변임을 단언 (InputFrame 외 필드 무시).
3. **스냅샷 왕복 씰**: MatchSnapshot 직렬화→역직렬화→분배 후 각 정본 모듈
   (score/round_flow/ball) 값 일치. 듀스 구간(6:6→7:7) 레그 포함.
4. **Y반전 표시 씰**: 클라이언트 시점에서 자기 패들이 하단, 서브권 표시가
   자기 기준으로 반전됨. 시뮬 좌표는 미반전임을 함께 단언.
5. **게이트 씰**: `online_match_active` 중 아이템 스폰/퍽 모달/수호령 진입이
   전부 no-op. flag OFF 레그로 싱글플레이 불변 확인.
6. **예측·보정 씰**: 인위적 스냅샷 지연 주입 시 자기 패들이 보정으로 수렴하고
   텔레포트성 스냅이 임계 이하임을 단언.

라이브 검증: 게이트 3단(§1) + **RTT 매트릭스** — 20/50/100ms 및 손실·지터
조건(clumsy 등 네트워크 에뮬레이터)에서 체감 측정. "국내 RTT면 롤백 불요"는
미검증 가설이므로 이 측정 결과로 롤백/지연보상 도입 여부를 재평가한다.
Tailscale은 직접 연결 실패 시 릴레이(DERP) 폴백으로 지연이 변할 수 있으니
세션 전 연결 유형을 확인·기록한다.

## 7. 레거시 `network/` 재사용 판단표

| 항목 | 판단 |
|---|---|
| Y반전 대칭 규칙 세부(서브권·속도 부호·서브 대기 공속 0) | 표시 규칙 참고 |
| 스킬 VFX = 발동 1회 이벤트 + 수신측 로컬 재생 | 차기 스킬 동기화에 채택 |
| IP 히스토리/로비 상태기계 UX | 참고 |
| 클라 최종 위치 전송·호스트 대입 (위치 릴레이) | **금지** |
| TCP + JSON + 매 프레임 풀 상태 전송 | **금지** |
| 미완 스캐폴딩(사운드 동기/재접속/끊김 UI) | 참고하지 않고 신설계 |

레거시는 "도달 가능한 프로토타입"이지 검증된 구현이 아니다(온라인 E2E 증거
없음). 코드 이식이 아니라 설계 아이디어 재사용만 한다.
