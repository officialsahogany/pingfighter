# Viper 연습모드 튜토리얼 — 슬라이스 플랜 (SSOT)

바이퍼(테스트/주니어리그) 첫 진입 시, **정지된 공을 쉐도우 백스텝으로 맞추고 마샬킥까지
연계 성공해야 본게임에 진입**하는 인터랙티브 연습 모드. 스매셔/코만도 튜토리얼(수동 텍스트
오버레이)과 달리 게임 루프를 스킬 실행에 걸어 잠근다.

- 결정 D1 (2026-07-04 확정): **무한 재시도, 성공 필수, 스킵 없음.** 콤보 실패(타이밍 놓침·
  공 낙하) 시 공을 다시 정지시키고 처음부터. 쉐백→마샬 연계를 실제로 성공해야만 진입.
- 조사 근거: 두 read-only 조사 에이전트(공 흐름 / 바이퍼 스킬 감지)가 통합 지점을 매핑함.
  아래 file:line 앵커는 그 결과.

## 1. 아키텍처 (조사 확정)

### 공을 "정지시키되 스킬로 때릴 수 있게" — 소유형 홀드
- 하드프리즈(stopwatch/`viper_dmk_freeze_active`/`power_state.is_freeze_active`)는
  `ball_update_controller.gd:37-46`에서 바이퍼 패스(`:67`)보다 **먼저 return** → 스킬이 공을
  못 침. **쓰면 안 됨.**
- 소유형 홀드 = `viper_skill_chaos_spear_ball_motion_runtime.gd:45-52` 패턴: 매 프레임
  `ball_pos` 고정 + `ball_vel = ZERO` + `skip_ball_motion_step = true` +
  `ball_active = true` + `player_collision_cooldown >= 6`. 바이퍼 패스(`:67`)가 skip
  단축(`:69/:84/:96`)보다 먼저 돌아서 **정지공이 여전히 히트 가능**하고, 그 사이 점수/바닥
  판정은 우회돼 **공을 잃지 않음**.
- 해제 = skip=false + 실제 `ball_vel` + `ball_impact_boost=1.0` + 소유 토큰 클리어
  (`viper_skill_chaos_spear_ball_motion_runtime.gd:6-12`).

### 라운드 시작 게이트
- 튜토리얼 = 스테이지 50. 공-스폰 인트로/자동서브 이미 꺼짐
  (`stage_ball_spawn_intro_begin_lifecycle.gd:14`, `serve_flow_controller.gd:52`
  `TUTORIAL_STAGE=50`).
- 라운드 홀드 = `round_flow_state.pause_serve_for_intro()` (`:42`, `waiting_for_serve=false`)
  → `serve_flow_controller.gd:22` inert. 성공 시 `prepare_serve_after_intro()` (`:50`)로 서브 재무장.
- **물리는 안 막는다**(`_should_block_battle_physics`에 등록 금지). 막으면 스킬도 멈춰서 콤보 불가.
  그립선택 오버레이처럼 물리를 막는 방식은 여기선 부적합.

### 스킬 콤보 감지
- `viper_skill_runtime` 모듈(registry key `"viper_skill_runtime"`,
  `gameplay_actor_module_catalog.gd:48`). `get_snapshot()` 매프레임 폴링.
- 게이트 상태 전이: `shadow_hit_consumed`(쉐백 명중) 상승엣지 → `marshal_active`(마샬 시전) →
  `marshal_ball_hit`(마샬 연결) 상승엣지 = 성공. `marshal_from_shadow_step_chain`은 스냅샷에
  없음 → 순서 관찰로 연계 강제.
- 정지공(속도 0)도 기하 판정으로 맞고 최소속도(쉐백 10 / 마샬 11)로 발사됨.

### 공 정지 위치
- 게임공간 760×750, 필드중앙 (380,375), 플레이어 baseline y=700. 쉐백 웨이브는 패들에서
  보스 쪽(위)으로 travel. 정지공은 플레이어와 중앙 사이(예 (380, 520~560))가 리치 안정.
  실측 튜닝 필요(라이브 QA).

## 2. 상태 머신 (Slice 1)

```
INACTIVE ──(주니어+바이퍼+그립선택 + 진입)──▶ AWAIT_SHADOW
AWAIT_SHADOW  : 공 정지 홀드 요청. 쉐백 명중(shadow_hit_consumed 상승엣지) ─▶ AWAIT_MARSHAL
AWAIT_MARSHAL : 홀드 해제(쉐백이 공 발사). marshal_ball_hit 상승엣지 ─▶ COMPLETE
              : 타임아웃(마샬 미착지) 또는 공 상실 통지 ─▶ AWAIT_SHADOW (재시도, 재홀드)
COMPLETE      : 홀드 해제 + prepare_serve_after_intro → 본게임
```
- 엣지 감지: `shadow_hit_consumed`/`marshal_ball_hit`는 재캐스트마다 리셋되는 래치이므로,
  각 페이즈 진입 시 baseline 캡처 후 false→true 상승엣지로만 전이(재시도가 잔여 true에
  즉시 재전이하는 것 방지).
- 순수 로직(공 물리 무관): `update`가 desired action을 산출 → `wants_ball_hold()`,
  `has_completed()`, `get_message()`. 공 물리 슬라이스가 이걸 소비.

## 3. 슬라이스

| # | 내용 | 위험 | 상태 |
|---|------|------|-----|
| **S1** | 상태머신 + 게이팅 + 감지 + desired-action 인터페이스 | 낮음 | ✅ 봉인(래치 poison 반증×2) |
| S2 | 공 소유형 홀드 훅 — **엣지 관찰 이원화**(HUD 스냅샷 + 공 경로 라이브 멤버가 공유 prev 래치) → 히트 프레임 동일-프레임 해제 | **높음** | ✅ 봉인(관찰 제거/해제 방출 제거 반증×2, 공경로 회귀 7종 GREEN) |
| S3 | 안내 UI(공용 키캡 렌더러, y 0.42, 페이즈별 페이드인·성공까지 유지) | 낮음 | ✅ 봉인 |
| S4 | 라운드 게이트 — active 동안 매프레임 pause 재잠금. **완료 시 서브 불간섭**(마샬 발사공으로 라이브 랠리 진입; prepare 호출 금지=이중서브) | 중간 | ✅ 봉인(게이트 무력화 반증) |
| S5 | 공 상실 인터셉트 — `step_motion` 점수 이벤트와 score_event 반환 사이에서 `notify_ball_lost`(AWAIT_MARSHAL 전용) true면 흡수+공 비활성화(재staging 위임). 완료/홀드/부재 시 절대 미흡수 | **높음** | ✅ 봉인(페이즈 게이트 제거 반증) |
| S6 | frame_controller update/draw + 그립선택/이동·대쉬 안내 viper 포함(D2=yes, 대쉬=쉐백 선행조건) + practice 대쉬완료 게이트 + 중간튜토리얼 게이트 viper 분기 + 7개국어(확립 스킬명) | 낮음 | ✅ 봉인(영향권 스모크 8종 GREEN) |

라이브 QA 미완: 홀드 위치(380,545) 쉐백 리치 실측, 마샬 타임아웃 8s 체감, 안내 겹침/가독성.

## 4. 트랩 (활성 owner 문서 + 본 slice, 필수 준수)

공 소유와 해제의 공통 정본은
[`character_skill_perk_checklist.md`](character_skill_perk_checklist.md)의
`3.1a. Combo / predecessor trigger matrix`와 `7. Persistence and lifecycle`이다.

- `skip_ball_motion_step` 해제는 **모든 exit 경로**(성공/재시도/취소/라운드리셋)에서 false +
  실제 velocity로 복구한다. 누락 시 정지·미히트 공 softlock.
- 홀드 중 패들 겹침 시 명시적 bounce/release를 수행한다.
- 소유공이 자기 바닥/점수 판정할 땐 barrier 체크를 복제한다 — 연습 홀드는 애초에 점수
  경로를 우회하므로 홀드 중엔 무관, but 해제 후 라이브 페이즈(AWAIT_MARSHAL)에서 상실 처리(S5)가 이 경계.
- effects-only 모달 정지창 softlock은 자가치유 토큰 + 라운드경계 정규화
  (`ball_round_state.build_common_snapshot`가 경계마다 skip=false 강제 — 안전망) 준수.
- 홀드는 라운드 경계를 넘어 살아남으면 안 됨(정규화가 지움) → 매프레임 재assert 설계.

## 5. 게이트 연동
- 아이템/캐릭터정보 안내는 캐릭터별 중간튜토리얼 완료를 기다림
  (`_mid_tutorial_module_key`). 바이퍼 = `viper_practice_mode.has_completed()` 를 중간튜토리얼
  완료로 매핑(S6). 스매셔=스킬오브, 코만도=화기.
- 이동/대쉬 안내(`junior_mika_tutorial_hint`)를 바이퍼까지 확장할지는 D2(미정): 연습모드가
  이동/대쉬(대쉬는 쉐백 선행조건)를 포함하므로 별도 이동/대쉬 안내는 생략 가능. 우선 연습모드
  단독으로 진행하고 라이브 QA 후 결정.

## 6. 참조 관련 메모리/문서
- `[[project_junior_tutorial_system]]` — 다캐릭터 튜토리얼 구조.
- `[[project_viper_core_flip_hwarang_parity]]`와 이 문서 §4 — 연계 감지 참조.
- 공-소유 스킬 트랩: `character_skill_perk_checklist.md` §3.1a 및 §7.
