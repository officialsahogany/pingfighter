# 코덱스 핸드오프 — 세린(바이퍼) 신규 초식 「월담야습」 런타임 배선

**이 문서는 실행 체크리스트이며 설계 정본이 아니다.** 충돌 시
`docs/viper_wall_leap_raid_slice_plan.md`의 **현재 리비전(rev6)** 이 우선한다.
해시로 고정하지 않는다 — 스펙이 개정되면 그 문서의 최신본이 정본이다.

---

## 0. 스펙 정본

`docs/viper_wall_leap_raid_slice_plan.md` (**rev6**)

**착수 전 전문을 읽어라.** §2.2(강제귀환·관측점) · §4(런타임 계약) · §5(입력) ·
§6(배선표) · §7(씰 13종) · **§10(참격 연출 확장)** 이 계약이다.
이 문서는 요약이 아니라 진입점이다.

설계는 사용자 확정 완료(§8). 수치·정책을 임의로 바꾸지 마라.

## 1. 범위

**§1~§6은 초기 배선(완료, `b5596b24a`)의 계약이다. 지금 착수할 작업은 §7이다.**
§2~§4는 §7 작업에도 그대로 적용되므로 건너뛰지 마라.

- **포함**: 런타임 배선 + 씰 + 다국어 7언어 + 퍽 획득/교체/취소/저장 경로
- **제외**: 아이콘·컷인·VFX 에셋 **제작**(별도 트랙). 오디오 에셋 제작도 제외(§4.3).

---

## 2. ⚠️ 선행 리뷰에서 P1으로 반려된 10건 — 관례로 추측하면 전부 다시 틀린다

1. **RMB는 `mouse_right_*`가 아니다.** 정본 계약은 `secondary_action_pressed` /
   `_just_pressed` (`smasher_input_reader.gd:52`). 바이퍼 리더에 동일 형태로 신설.
   `get_snapshot()`의 같은-물리-프레임 멱등 계약 유지(에지 소모 트랩).
2. **우클릭에는 이미 소비자가 있다.** 방망깨비 탑승이 맨 우클릭을 쓴다
   (`lingpet_mount_state.gd:6`). 중재기
   `lingpet_egg_runtime._is_right_click_claimed_by_player_skill(:2933)`가
   `smasher_overdrive_state` 하나만 보고 있으니 월담야습도 보게 확장하되,
   벽력유성 선례대로 `is_command_armable()` 단일 술어로 판단(장착·기력·쿨·랠리·
   입력락·대쉬·활성). `get_cached_instance` **peek 전용**(콜드 인스턴스화 = 히치).
3. **바이퍼 LMB는 이미 제트팩이다.** `mouse_left_pressed = primary_pointer_pressed`
   이고 `jetpack_pressed`가 같은 소스 (`viper_input_reader.gd:35,47`). 체류 중에만
   오버라이드하고 귀환 프레임 에지 처리. 오딘의 눈(`:519`)이 같은 에지를 더 먼저
   소비하므로 우선순위 명시.
4. **공 감속에 `ball_vel` 크기를 건드리지 마라.** `get_initial_speed`가 들어오는
   크기를 나가는 크기로 쓰므로(`paddle_bounce_controller.gd:240-242`) 체류 중 보스
   반사가 눌린 채 확정되어 **랠리가 영구히 느려진다.** 이동 스텝 시점 배율 0.5만.
   `bounce()` 복원 계약(perk_resume / 허공환영)은 수명이 달라 재사용 불가.
5. **`ball_vel ≈ 0`은 프리즈 정본이 아니다.** `ball_update_controller.gd:34~49`
   조기반환 5갈래 중 속도를 0으로 만드는 건 스톱워치/퍽재개 하나뿐. 사이코볼
   히트스톱·파워 프리즈·DMK/독영절맥은 속도 유지. 공통 `ball_unavailable` 술어로.
6. **강제귀환 관측점은 두 곳이다.** 공 패스 조기반환 직전(A)만으로는 사이코볼을
   **영구히 못 본다** — `:34` 통과 후 `step_motion()` 내부
   `paddle_bounce_boss_post_hit_handler:67` →
   `stage3_boss_skill_state.register_boss_hit:98`에서 켜지고, 다음 프레임
   `battle_frame_flow_controller:80`이 `update_ball`을 통째로 스킵한다.
   **`step_motion()` 직후(B)** 추가 필수.
7. **B의 술어는 라이브 `deps`/state를 읽어라.** 업데이트 시작 시점 `frame_context`
   복사본을 읽으면 B가 A와 똑같이 장님이 된다. 기존 판정도 그 형태
   (`ball_update_controller._is_stage3_psychoball_hitstop_active:172`).
8. **무충돌 게이트는 기본 패들 rect 하나만.**
   `ball_motion_collision_detector._resolve_player_collision_result(:118)`은
   기본 rect(`:121`) → 토르 방패(`:127`) → **쌍영분신 클론**(`:137`) 순.
   함수 전체를 막으면 같은 캐릭터(바이퍼) 초식인 분신 가드가 죽는다.
   바닥 세이브(홀리베리어 등)는 건드리지 않으면 그대로 산다 — 넓게 막지 마라.
9. **"플레이어가 막을 수 있나" 소비자는 두 곳이다.** 링크포트 디스패치
   (`lingpet_ring_dash_state.gd:200`)와 수호령 몸통 접촉
   (`lingpet_egg_runtime.gd:3048`). 공통 `player_guard_available=false` 계약으로
   함께 읽어라. 한쪽만 고치면 "발동은 했는데 안 튕김".
   ⚠️`player_pos` 가짜 이동으로 우회 금지(렌더·HUD 앵커 오염).
10. **스턴/넉백은 패들 타구 경로가 아니다.** 체류 중 패들이 무충돌이라 덮어쓸
    일반 넉백 자체가 없다. `status_effect_state.apply_status("boss","stun",...)` +
    `commando_firearm_hit_result_state._apply_runtime_stun_result(:256)` 패턴.
    명중 판정은 **보스 중심점 X 거리**(rect 접촉 아님).

---

## 3. 저장소 표준 규율 (위반 시 반려)

- **`git reset` / `checkout` / `stash` 절대 금지.** 이 저장소는 미커밋 WIP이 정본이며
  과거 stash로 611파일이 날아간 사고가 있다. 회귀 검증은 **in-place Edit 토글 /
  임시 패치 / 픽스처**로만.
- 판정은 표준 러너 `godot/tools/run_smoke_tests.ps1` 관통(엔진 `ERROR:` /
  `Invalid call`도 실패 승격). 씰은 **CI focused 목록에 등재**하라 — 미등재는
  구조적 미검출이다.
- 유닛에서 `update()`를 직접 부르는 씰은 공허-GREEN이다 — 실제 게이트/라우터 관통.
- `owner.set(key, ...)`은 `BattleSceneState.DEFAULT_VALUES` 미선언 키에 **무성 no-op**.
  동기 키 전량 선언.
- 다국어는 **7언어**. 영어는 `viper_skill_config.gd` 영문 맵, 나머지 5개어는
  `language_settings_data.gd`. 영어만 넣고 끝내는 누락이 이 저장소에서 반복된다.
- 참조: `AGENTS.md`, `docs/character_skill_perk_checklist.md`
  §3.1/§3.3/§4.2~4.3/§7, `docs/godot_runtime_traps.md`

---

## 4. 완료 게이트

### 4.1. 반증검증의 정의

**기능 부재 상태의 최초 RED나 누락 메서드 오류는 TDD 착수 증거일 뿐,
반증검증으로 세지 않는다.** 각 씰은 GREEN 완성 후 해당 계약 **하나만**
in-place 토글 / 임시 패치로 깨뜨려 예상 RED를 재현하고, 원복·재실행하여
GREEN 복귀를 확인한다. 씰 11종 각각에 대해 이 증거를 보고하라.

### 4.2. 검증 순서

1. **구현 전** 전수 스모크 기준선 기록(선행 RED 목록 포함)
2. 구현
3. **구현 후** 동일 러너 재실행 → 신규 RED 0 확인, 선행 RED는 별건으로 구분
4. `godot/`에서 순차 실행:
   - `.\tools\run_warning_scan.ps1`
   - `.\tools\run_headless_load_check.ps1`
   - `git diff --check`
5. **창 모드 실기 확인**(별도 수행, 헤드리스로 대체 불가):
   데스크톱 RMB/LMB 입력, 진입·귀환 이동 트윈, 충돌 및 바닥 세이브, HUD/툴팁

### 4.3. 오디오

에셋 **제작은 제외**. 다만 진입 / 참격 / 폭발 / 강제귀환 각각에 재사용할 적합한
**기존 큐가 있는지 감사**하고, 연결하지 않으면 **의도적 무음** 또는 **후속 에셋
미결**로 명시하라. 루프 큐를 쓰면 `gameplay_loop_audio_cleanup.gd` `STOP_METHODS`
등재와 **라운드 경계 정리까지 포함**한다(모달 블록 게이트가 루프를 안 끊는 트랩).

### 4.4. 모듈 경계

신규 owner가 필요하면 **최소 모듈 경계를 먼저 정하고**
`docs/godot_port_architecture.md`에 기록한다. 입력·공 이동 핫패스에서는
**콜드 인스턴스화 / 리소스 로드 / 전체 노드 탐색 금지**.

### 4.5. 커밋 자립성

작업트리 GREEN과 커밋 자립성을 **별도로** 검증한다. 최종 해시의 tree에
신규 런타임 · 테스트 · CI 목록 · 다국어 · 문서 변경이 **모두** 포함됐는지 확인하라
(모듈은 살고 위임 배선만 죽은 고아쌍이 이 저장소의 알려진 실패 형태다).

- 혼합 파일은 헝크 분리. **소유권을 증명할 수 없으면 억지로 커밋하지 말고
  미커밋 잔여로 보고**하라.
- 공유 인덱스 오염을 피하도록 **임시 인덱스**(`GIT_INDEX_FILE`) 또는 조율된
  스테이징을 쓴다.
- 로컬 커밋만. **push 금지.**

### 4.6. 플레이스홀더 아이콘 예외

플레이스홀더 아이콘은 이번 작업의 **사용자 승인 예외**다. 레지스트리와
`unlock_wall_leap_raid` 별칭이 **첫 글자 폴백 없이 같은 플레이스홀더로 귀결**되는
것까지만 승인하며, **아트 완료로 보고하지 마라.**

---

## 5. 네가 정해서 보고할 것 (스펙 §9 잔여)

- 진입 / 귀환 트윈 시간 · 궤적 (권고 0.18~0.25초, 담을 넘는 포물선)
- 보스 AI 예측에 이동배율 0.5를 먹일지 (권고: 먹인다 — 구현에서 적용 완료)
- 모바일 / 게임패드 우클릭 대체 입력 — 막히면 미결로 보고하고 데스크톱만 완성

## 6. 산출물

1. 배선 완료 + 씰 11종 GREEN + **각 씰의 §4.1 규격 반증 RED 증거**
2. 전수 스모크 기준선 / 사후 결과 대조 (신규 RED 0)
3. `run_warning_scan` / `run_headless_load_check` / `git diff --check` 결과
4. 창 모드 실기 확인 결과 (§4.2-5 항목별)
5. 스코프 격리 커밋 + 해시, 또는 소유권 미증명 시 미커밋 잔여 보고
6. §5 결정사항과 미결 잔여

---

## 7. 추가 작업 — 참격 연출 확장 (rev6, 2026-08-01)

초기 구현(`b5596b24a`) 이후 사용자가 확정한 추가 배선이다. **정본은 rev4가 아니라
현재 `docs/viper_wall_leap_raid_slice_plan.md` rev6 §10**이다. 전문을 읽고 시작하라.

### 7.1. 요약

1. **페이싱** — 체류 중 좌 이동 → 좌 시트, 우 이동 → 우 시트(평소 이동과 동일).
   무입력 프레임은 마지막 페이싱 **래치**(정면 리셋 금지).
2. **스윙 시트** — 참격 시 `VIPER_PLAYER_ATTACK_LEFT/RIGHT_SHEET_PATH` 재생.
3. **검기 투사체** — 스윙 임팩트 프레임에 `air_blade/` 자산으로 검기를 전방 발사.
4. **검기가 판정 주체** — 기존 "전방 110px 즉시 판정"을 **폐기**하고 검기 비행
   최대 360px 스윕 판정으로 대체.
5. **귀환은 검기 소멸 후** — 기존 "참격 즉시 귀환"을 대체.

### 7.2. 새 에셋을 만들지 마라 — 전부 이미 있다

| 필요 | 기존 경로 |
|---|---|
| 좌/우 이동 시트 | `battle_viper_sprite_paths.gd` `VIPER_PLAYER_WALK_LEFT/RIGHT_SHEET_PATH` |
| 스윙 시트 | 같은 파일 `VIPER_PLAYER_ATTACK_LEFT/RIGHT_SHEET_PATH` |
| 스윙 프레임 규격 | `viper_skill_runtime.gd:132~134` (160x160 / 4열 / 8프레임) |
| 검기 VFX | `assets/sprites/characters/viper/air_blade/` (trail · slash_burst · silhouette · charge_glyph) |
| 여백 앵커 | `player_sprite_body_insets.gd` (left_attack 실측치 등재 완료) |

⚠️**좌/우 시트가 모두 실재하므로 UV 스왑 미러링을 쓰지 마라.** 미러 헬퍼는 한쪽
시트만 있을 때의 규칙이다.

### 7.3. 깨지는 기존 계약 — 반드시 같이 고쳐라

- **씰 5 `wall_leap_slash_facing_smoke` 재작성.** 110/111 경계 단언과 "즉시 귀환"
  단언이 rev6에서 무효다. 페이싱 전방/후방 계약만 남기고, 사거리·귀환은 씰 12로.
- **`SLASH_RANGE_X = 110.0` 상수 폐기 또는 검기 사거리로 대체.** 소비자 0인 죽은
  상수로 남기지 마라(파생-임계값 리터럴 트랩).
- **§4.5 리셋 3경로**에 검기 투사체 · 스윙 클럭 · 페이싱 래치를 추가.
- **§2.2 기력 표**에 "SLASH/BLADE_FLIGHT 커밋 후 강제귀환 = 60 환불 없음" 행 추가됨.

### 7.4. 새 씰

- **씰 12 `wall_leap_blade_projectile_smoke`** — (a) 임팩트 전 무판정 (b) 전방만
  (c) **스윕 판정 = 터널링 방지** (d) 360/361 경계 (e) 1회 명중 후 소멸
  (f) 소멸 프레임에 RETURN (g) BLADE_FLIGHT 중 강제귀환 시 검기 정리 + 60 환불 없음
- **씰 13 `wall_leap_facing_smoke`** — 좌/우 입력별 시트, 무입력 래치, 스윙·검기
  방향 일치

⚠️(c) 스윕 레그가 없으면 프레임당 14px 터널링이 GREEN으로 남는다. 필수다.

### 7.5. 그 외

- **프리웜 등재** — 참격 시트 2장 + air_blade 텍스처. 스윙 임팩트 프레임의 콜드
  로드는 그 프레임 통째로 히치가 된다.
- **드로 컬** — 검기는 보스 Y 레인을 수평으로 길게 이동한다. 컬 박스를 캐릭터
  주변으로 좁게 잡으면 중간에 사라진다.
- **§4(완료 게이트)는 그대로 적용**된다 — 반증검증 규격, 기준선/사후 대조,
  warning_scan · headless_load_check · `git diff --check`, 창 모드 실기 확인.
- 튜닝(스윙 프레임 속도·임팩트 프레임·검기 속도)은 §10 권고값에서 시작해 실기
  확인 후 확정하고 보고하라.
