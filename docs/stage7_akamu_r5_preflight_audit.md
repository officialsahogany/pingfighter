# 아카무 3건 착수 전 실사 감사 (2026-08-19)

- 대상: 사용자 요구 3건. (1) 그림자분신 60% 황금 변형 + 무혼 드랍,
  (2) 초각성 보호막 공 반사 배선, (3) 각성 후 궁극기 발동 타이밍.
- 방법: 원본 Python 파리티 · 포팅본 배선 지점 · 황금 분신 설계 3영역 병렬 실사
  → 종합.

## 0. 핵심 정정 — 요구 3번

**원본에도 초각성과 궁극기 사이에 시간 게이트가 없다.** 실사 3본 교차 확인
결과, 원본은 초각성 완료 처리와 궁극기 게이트를 같은 함수 같은 틱에 연속
배치한다. 게이트는 게이지 250과 사용 후 쿨다운 25초뿐이고, 유일한 유예는
초각성 연출 프리즈 3.0초다. 포팅본의 게이트 수식과 게이지 경제(80/90/20,
상한 500, 이월 0.7)까지 원본과 1:1이다.

따라서 "포팅본만 즉시 발동한다"는 게이트 이식 오류가 아니다. 체감 차이의
원인 후보는 둘이다.

1. **각성 시점 게이지 잔량**. 원본은 5점제 3점, 포팅본은 7점제 4점에서
   각성한다. 경기 비중으로는 앞당겨졌지만(0.600 → 0.571) **절대 랠리 수는
   늘어난다.** 게이지는 랠리 수를 따르므로 각성 순간 게이지가 원본보다 높을
   수 있고, 그러면 각성 직후 250 도달 확률이 올라간다. 점수 룰 개편의 파생
   효과이며 GRT-054 계열이다.
2. **프리즈 컨텍스트 유실(R21)**. 프레임 흐름 컨트롤러가 각성 동결 함수를
   인자 없이 호출해, 동결 중 보스 스킬 쿨다운 정지 판정이 항상 거짓이 된다.
   최루탄이나 별똬리로 쿨다운을 얼려도 각성 직후 궁극기가 그대로 터진다.
   이것은 포팅본에만 있는 **실제 결함**이다.

그래서 착지 순서는 R21 복구와 게이지 계측이 먼저이고, 신설 유예 상수는
사용자가 원본 이탈을 승인할 때만 넣는다. 값은 발명하지 않는다.

## 0-a. 요구 2번은 확정 결함

`resolve_wind_aura_collision`의 프로덕션 호출자가 0건이라는 정적 확인에 더해,
사용자가 라이브에서 "보호막과 공의 타격 판정이 없다"를 독립 확인했다.
전용 사운드 함수는 이미 존재한다. 배선만 빠졌다.

---

### 1. 착지 순서와 근거

전체를 5단계로 쪼갠다. 순서의 기준은 두 가지다. 하나는 "게이지 경제를 바꾸는 변경은 게이지 기반 판정을 계측하기 전에 넣지 않는다", 다른 하나는 "RED 베이스라인을 고정하기 전에는 어떤 씰도 증거로 쓰지 않는다".

**L0. 씰 등재와 RED 베이스라인 고정 (행동 변경 0)**
`stage7_akamu_slice5_smoke.gd`와 `ball_boss_skill_pause_context_smoke.gd`를 `.github/workflows/godot-ci.yml`과 `godot/tools/run_pre_push_checks.ps1`의 `$focusedSmoke` 배열에 **동시** 등재한다. 두 목록 락스텝은 pre-push 스크립트 :50이 명시한 계약이다. 동시에 현재 실패 건수(slice5 어서션 30건, pause context 5건, SCRIPT ERROR 0건)를 커밋 메시지에 숫자로 박아 베이스라인으로 삼는다.
근거: 이 영역이 지금까지 방치된 유일한 이유가 4종 전부 미등재라는 점이다. 베이스라인 숫자가 없으면 이후 단계에서 "몇 건 줄었나"를 증거로 쓸 수 없고, 그러면 slice5는 R02/R20/R23 때문에 끝까지 RED로 남아 어느 단계도 GREEN 증명을 못 한다.

**L1. 항목 3-a. 각성 프리즈 컨텍스트 포워딩 복구 (R21)**
`battle_frame_flow_controller.gd:81`의 인자 없는 `advance_gameplay_freeze(delta)`를 고치고, `battle_frame_flow_deps_builder`에 `_build_stage7_akamu_freeze_context()`를 복원한다.
근거: 사용자 요구 3번에 대해 **지금 존재하는 유일한 정당한 억제 장치**가 이것이다. 원본에도 시간 게이트는 없지만, 보스 스킬 쿨다운 일시정지 게이트는 원본과 포팅본 양쪽에 설계상 존재하며 포팅본에서만 죽어 있다. 이걸 고치지 않은 채 새 유예 상수를 심으면 결함 위에 우회로를 얹는 꼴이 된다. 또한 볼 경로를 전혀 건드리지 않는 가장 작은 변경이라 L2의 회귀 원인에서 사전 배제된다.

**L2. 항목 2. 바람 오오라 충돌 배선 (R03)**
스테퍼 서브스텝에 오오라 판정과 분신 예약을 넣고, step_context 포워딩 2키와 이벤트 핸들러를 복원한다. 같은 커밋에서 `docs/stage7_akamu_rigo_port_plan.md:257`(§5 #8)을 정정한다.
근거: L1보다 뒤인 이유는 오오라 블록이 **보스 게이지 +90을 새로 공급**하기 때문이다. 게이지 곡선을 바꾸는 변경을 L1(억제 게이트 복구)보다 먼저 넣으면 항목 3의 원인 분리가 불가능해진다. L3보다 앞인 이유는 오오라가 항목 3 계측의 정상 조건이기 때문이다. 현재는 +90 수급과 30% 무료 시전이 통째로 빠진 비정상 게이지 곡선이라, 지금 계측한 숫자는 폐기값이 된다.

**L3. 항목 3-b. 각성 시점 게이지 잔량 계측 (코드 변경 없음, 계측 전용)**
각성 완료 프레임의 `boss_special_gauge` 값과 그 직후 궁극기 발동까지의 실경과 시간을 라이브 3판 기록한다.
근거: 실사 결론은 "포팅본 게이트 수식은 원본과 1:1이고, 즉시 발동은 원본도 동일"이다. 따라서 체감 차이의 원인은 게이트가 아니라 각성 시점 게이지 잔량 분포다. 이 숫자 없이 유예 상수를 넣는 것은 증상 덮기이며, 게이트 수식에 손대는 수정은 파리티 역행이라 금지다.

**L4. 항목 1. 황금 그림자분신 + 무혼 캐리어 신설**
분신 dict의 golden 필드, 드랍 캐리어 파일 1개, 훅 4곳, 채널 키 1개, 드로 함수 1개.
근거: 구현 자체는 L1~L3과 독립이라 언제든 넣을 수 있으나, **밸런스 상수를 확정할 수 있는 시점은 L2 이후뿐**이다. 오오라 복구가 30% 무료 분신 시전을 되살려 분신 세트 스폰 빈도를 올리므로, L2 이전에 측정한 `TEMP_GOLDEN_CLONE_CHANCE`는 즉시 폐기값이 된다. 배선 착지 자체를 앞당기고 싶다면 상수를 확정하지 않은 채 L2 앞에 넣어도 되지만, 그 경우 튜닝 커밋이 L2 뒤에 반드시 한 번 더 온다.

**L5. 항목 3-c. 신설 유예 상수 (사용자 확답 시에만)**
L3 계측 결과를 보고 사용자가 원본 이탈을 승인하면, `stage7_akamu_superspeed_state.gd`에 유예를 넣는다.
근거: 원본에 근거가 없으므로 파리티 복원이 아니라 신설 기획이다. 승인 없이는 착지하지 않는다.

---

### 2. 항목별 구현 계약

#### S1. 황금 그림자분신 60% + 무혼 드랍

**S1-a. 황금 플래그 (해석 A. 개체 단위 60%)**

굴림 지점은 `godot/scripts/stages/stage7/stage7_akamu_clone_state.gd`의 `spawn_entities()`(:210-251), `for offset in offsets:` 루프(:225) 내부, 엔티티 dict 리터럴(:231-251) **단 한 곳**이다. 필드명은 `"golden"`.

RNG 스트림 배치 규칙을 못박는다. 황금 굴림은 해당 엔티티 블록의 **마지막** rng 소비여야 한다. 즉 기존 `rng.randf_range(...)`(:238-241)와 `rng.randi_range(...)`(:242)를 모두 소비한 **뒤**에 굴린다. 이렇게 하면 첫 엔티티의 이동 파라미터가 불변으로 유지되어 시드 고정 씰의 재기준선 범위가 최소화된다. `godot/tests/stage7_akamu_slice3_smoke.gd:143(73001), :176(73002), :203(73003), :233(73004)`의 기대값은 같은 커밋에서 락스텝 갱신한다.

굴림에 쓰는 RNG는 권위 RNG인 `stage7_akamu_state.gd:86 _rng`다. 황금 여부는 보상을 결정하므로 프레젠테이션 RNG로 분리하면 안 된다(AGENTS.md 프레젠테이션 랜덤 규칙의 반대편 사례).

MAX_ENTITIES 8 상한(:216-227)에서 황금이 조용히 잘리는 문제는 사용자 확답 항목이다. 확답 전 기본값은 "특별 취급 없음"으로 두고, 잘림이 실제로 일어나는지 씰 레그로 관측만 한다.

**S1-b. 드랍 스폰 훅**

지점은 `godot/scripts/stages/stage7/stage7_akamu_state.gd`의 `resolve_ball_collision()` 안, :862 `_apply_clone_ball_reflection` 이후 **:864 `begin_dying()` 호출 직전**이다. `begin_dying`은 엔티티를 배열에서 제거하지 않으므로 직후에 읽어도 되지만, GRT-030 회피를 위해 **인덱스로 배열을 다시 훑는 시점을 최소화**한다. 즉 :860에서 이미 확보한 `clone_rect`와 같은 프레임의 엔티티 참조에서 golden을 읽고, 배열을 재조회하지 않는다.

수명 만료 경로(`stage7_akamu_clone_state.gd:272-276`)에는 **훅을 넣지 않는다**. 넣으면 플레이어 개입 없이 10초마다 자동 수급되는 공짜 파밍이 된다.

이중 스폰 방지는 구조적으로 이미 성립한다. `query_ball_collision`(:337-357)이 dying 엔티티를 제외하므로 같은 분신이 두 번 히트되지 않는다. 그래도 반증 레그로 명시 확인한다.

**S1-c. 무혼 캐리어**

신규 파일 `godot/scripts/stages/stage7/stage7_akamu_starpoint_state.gd`(`extends RefCounted`, 약 140줄). 정본 복제 대상은 `godot/scripts/stages/stage6/stage6_tetriser_starpoint_state.gd`이며 상수(:17-25)를 그대로 이식한다. DROP_SIZE 12.0, DROP_LIFETIME 600.0 레거시 프레임, DROP_ACCELERATION 0.25, DROP_MAX_FALL_SPEED 12.0, DROP_BOUNCE_DAMPING 0.7. 이 값들은 이식이지 신규가 아니므로 TEMP를 붙이지 않는다.

카탈로그 등록은 불필요하다. `stage7_akamu_state.gd` 상단에서 preload하고 `_rng`를 넘겨 직접 소유한다(스테이지 6과 동일 방식).

훅 4곳.
- 소유: `stage7_akamu_state.gd` 멤버 선언.
- 업데이트: `update()`(:638) 안. 배치 위치는 사용자 확답 항목이며, 확답 전 기본값은 스테이지 5 규약(서브 대기 중에도 낙하 지속)에 맞춰 타이밍 프리즈 반환(:650)보다 **앞**이다. `:681 if not skill_cooldown_paused:` 블록 안에는 절대 넣지 않는다. 넣으면 보스 스킬 쿨다운 일시정지 때마다 드랍이 정지한다.
- 정리: `reset()`(:535) 또는 `clear_round_transients()`(:557). 어디에 넣느냐가 곧 라운드 경계 정책이므로 확답 항목이다. 양쪽 모두에 `CommonStarpointVisualHost.hide_all_existing_hosts()`를 동반한다.
- 존재 감지: `_has_runtime_state()`(:967-978)에 `or _starpoint_state.has_drops()` 추가.

deps 신규 0개. `starpoint_collection_reward_policy.gd:4-18`이 요구하는 `runtime_perk_state`, `runtime_perk_catalog`, `context["owner"]`, `context["registry"]`, `selected_character_type`는 `battle_effects_update_controller.gd:15-18`이 만드는 공유 deps에 이미 실려 있고 스테이지 5·6·7이 같은 묶음을 받는다.

수령 실패 시 드랍을 살려두는 fail-loud 규약을 그대로 따른다(`stage6_tetriser_starpoint_state.gd:119-126` 주석). 살려둬야 배선 누락을 씰이 잡는다.

**S1-d. 드로**

채널: `stage7_akamu_context_builder.gd:101`의 `"stage7_akamu_clones"` 옆에 `"stage7_akamu_starpoint_drops"` 추가. `build_actor_draw_context()` 시그니처와 호출부(`stage7_akamu_state.gd:907-923`)를 동반 수정한다.

드로 함수: `stage7_akamu_playfield_renderer.gd`에 `_draw_starpoint_drops()` 신설. 정본은 `stage5_hongryun_playfield_renderer.gd:603-644`다.

★좌표 변환 계약. GPU 슬롯 경로(`host.sync_drop`)에만 `pos = game_offset + (playfield_pos + shake_offset) * render_scale`, `size = size * render_scale`를 적용한다. CPU 폴백(`CommonStarpointVisualHost.draw_muhon_fallback`)에는 **변환하지 않은 playfield 원좌표**를 넘긴다. 폴백은 호출 캔버스에 직접 그리므로 이미 playfield transform 안이다. 이 반쪽만 맞추면 부팅 프레임과 헤드리스에서만 좌표가 틀어지는 잠복 결함이 된다. `game_offset` 키가 stage7 컨텍스트에 실려 오는 것은 확인됐다(`stage7_akamu_pillar_scene_drawer.gd:69` 외).

**S1-e. 황금 시각 구분**

`stage7_akamu_playfield_renderer.gd:213-224 _draw_clone()`이 `clone.get("golden", false)`로 분기해 `_draw_clone_sprite()`(:288-353)에 **틴트 색 인자 1개**를 넘긴다. 기본 틴트는 `SHADOW_CLONE_TINT`(:66, 150/150/180), 황금은 `TEMP_GOLDEN_CLONE_TINT`.

금지 사항. 프레임 스펙 dict(`_ghost_frame_spec`, :78/:125)를 분신마다 `duplicate()`하지 않는다. 프레임당 1회 해석 규약이 깨지고 per-frame 할당이 된다. `canvas.material` 스왑으로 ADD 전환을 시도하지 않는다(GRT-056. 즉시 `_draw`에서 no-op). 신규 텍스처를 만들지 않는다.

곱연산 틴트만으로는 황금이 어두운 갈색으로 읽히므로(GRT-047), **밝은 코어 재공급**을 동반한다. `stage7_akamu_vfx_texture_cache.gd`의 기존 베이크 텍스처(`KEY_FLAT_DISC`, `KEY_AURA_GLOW_STACK`, `KEY_THIN_RING`)를 황금 modulate로 분신 **뒤에** 깐다. 사용 패턴은 같은 파일 :562-570, :587-594, :699-706에 이미 있고 전부 `draw_texture_rect(texture, rect, false, modulate)` 형태라 신규 에셋 0장이다.

동반 수정 2곳. 소멸 글리치 색 `CLONE_GLITCH_COLORS`(:67-71, 시안·마젠타·옐로)의 황금 대체 배열, 그리고 코드 네이티브 폴백(:226-273, `CLONE_COLOR` :14)의 황금 분기. 후자를 빼면 프리웜 전 로딩 프레임에서만 보라색으로 보인다.

#### S2. 초각성 보호막 공 반사 배선

**S2-a. 스테퍼 서브스텝**

`godot/scripts/ball/ball_motion_stepper.gd`.
- :5-8 상수 블록에 `const EVENT_STAGE7_WIND_AURA := "stage7_wind_aura"` 추가.
- 서브스텝 루프(:24-88)에서 **:61 `check_paddles` 직전**에 두 개를 순서대로 넣는다.
  1. 분신 예약 질의. `stage7_akamu_state.query_clone_ball_collision(prev_substep_pos, ball_pos, ball_vel, context)`가 히트하면 `{"event": EVENT_NONE, "ball_pos": ball_pos, "stage7_akamu_clone_collision_reserved": true}`로 조기 return한다. 스윕을 그 지점에서 끊고 기존 post-motion 분신 처리가 같은 프레임에 해소하게 둔다.
  2. `_check_stage7_wind_aura(ball_pos, ball_vel, ball_size, context)`. 비어있지 않으면 `{"event": EVENT_STAGE7_WIND_AURA, "ball_pos": ..., "ball_vel": ...}` 즉시 return.

순서 근거. 반경 90 오오라는 보스 패들을 감싸므로 패들이 먼저 잡으면 오오라는 영원히 발동하지 않는다. 분신은 오오라 안쪽에 있으므로 분신이 오오라보다 먼저다. 기하 검산은 씰이 이미 못박고 있다(boss_center (380,45), 오오라 하단 y=135, step_move (0,-12)에서 y=132에 최초 히트, 씰 요구 `ball_pos.y > 75.0`).

**S2-b. 인자 조달**

`godot/scripts/ball/ball_motion_event_processor.gd`의 `_build_step_context()`(:106-165)에 2키 추가.
```
step_context["stage7_akamu_state"] = deps.get("stage7_akamu_state", context.get("stage7_akamu_state", null))
step_context["stage7_akamu_audio"] = deps.get("audio", context.get("stage7_akamu_audio", null))
```
context 폴백은 필수다. 씰이 스테퍼를 직접 호출할 때 motion_context에 두 키를 넣는 형태를 쓴다(`slice5_smoke.gd:278-284`). deps 쪽 `stage7_akamu_state`는 `ball_dependency_context.gd:161, :229, :492`에서 이미 공급된다.

리졸버는 보스 기하를 인자가 아니라 context에서 스스로 뽑으므로(`stage7_akamu_state.gd:757-759`), 넘길 context는 step_context 그 자체여야 한다.

**S2-c. 이벤트 처리부**

같은 파일 `step_motion`(:23-86) 분기 체인(:45-79)에 `elif event == "stage7_wind_aura": _process_stage7_wind_aura(step_result, scene, context, deps)` 추가. 핸들러는 `scene["ball_pos"]`와 `scene["ball_vel"]`을 step_result에서 반영한다. 선례는 `_process_holy_barrier`(:213-)와 `_process_sand_terrain`(:89-104)이다.

★핸들러에서 오디오를 재생하지 않는다. 오오라 블록음은 `stage7_akamu_state.gd:780-781`이 리졸버 내부에서 이미 울린다. 중복 재생하면 씰의 "정확히 1회" 계약(`slice5_smoke.gd:303`)이 깨진다.

**S2-d. 반사식 (원본 1:1, 변경 금지)**

각도 반사가 아니다. `vel.y < 0`일 때만 `vel.y = abs(vel.y) * 1.1`, `vel.x += rand(-2.0, +2.0)` px/레거시프레임. 위치 밀어내기 없음. 재진입은 `HIT_COOLDOWN_SEC = 0.30` 상태 기반 디바운스로만 막는다. 포팅본 `stage7_akamu_awakening_state.gd:188-191`이 이미 이 식이므로 손대지 않는다.

수치 상수는 전부 이미 원본과 1:1이다(반경 90, 내구 5, 재충전 10초, 게이지 +90, 무료 시전 30% 2회). **상수는 한 글자도 건드리지 않고 호출 경로만 복원한다.**

**S2-e. 문서 정정**

`docs/stage7_akamu_rigo_port_plan.md:257`(§5 #8)이 지목하는 `ball_update_controller._process_stage7_akamu_collision()`은 구판 서술이다. 같은 커밋에서 정정하고 post-motion 블록에는 분신 처리만 남긴다. 두 지점에 중복 배선하면 한 물리 프레임에 오오라가 2회 발동하거나 0.30초 디바운스에 가려 무증상 이중 게이지 수급이 생긴다.

**S2-f. 오디오**

신규 작업 0이다. `game_audio.gd:3703 play_stage7_akamu_wind_aura_block()`, `assets/sounds/stage7_akamu_aura_block.wav`(63,588 B, 임포트 산출물 확인), 호출부 `stage7_akamu_state.gd:780-781`이 전부 완비다. step_context에 `stage7_akamu_audio`만 실으면 자동으로 울린다.
★이 SFX는 신화 아이템 양의회춘 반사음의 1순위 폴백으로 공유된다(`mythic_item_audio_router.gd:145-146`). 아카무 사정으로 볼륨이나 피치를 바꾸면 양의회춘이 동반 변경된다. 건드리지 않는다.

#### S3. 각성에서 궁극기까지의 유예

**★전제 정정 먼저.** 원본에는 초각성과 궁극기 사이의 시간 게이트가 존재하지 않는다. 3본 교차 확인 완료다. 게이트는 게이지 250과 사용 후 쿨다운 25초뿐이고, 유일한 유예는 초각성 연출 프리즈 3.000초다. 원본은 초각성 완료 처리(`pingfighter.py:178133-178143`)와 극정호신 게이트(:178144)를 **같은 함수 같은 틱**에 연속 배치한다. 포팅본도 동일하며 게이지 경제(80/90/20, MAX 500, carry 0.7)까지 1:1이다. 따라서 "포팅본만 즉시 발동한다"는 게이트 수식의 문제가 아니다.

**S3-a. R21 프리즈 컨텍스트 복구 (파리티 정당, 즉시 착수)**

`battle_frame_flow_controller.gd:81`을 `advance_gameplay_freeze(delta, deps.get("stage7_akamu_freeze_context", {}), deps)`로 고치고, `battle_frame_flow_deps_builder`에 소실된 `_build_stage7_akamu_freeze_context(...)`를 복원해 deps에 싣는다.

현재 빈 dict가 들어가므로 두 가지가 죽어 있다. 하나, `is_context_boss_skill_cooldown_paused`(`stage7_akamu_timing_policy.gd:22-28`)가 `lingpet_star_coil_freeze_boss_skill_cd`와 `active_item_boss_skill_cooldown_paused`를 절대 읽지 못한다. 즉 최루탄이나 별똬리로 보스 스킬 쿨다운을 얼려도 각성 직후 궁극기가 그대로 터진다. 둘, 각성 완료 프레임의 보스 기하가 폴백으로 떨어져 오오라 중심이 어긋난다(S2와 직결).

복구 문서 T03이 지목한 `frame_flow_deps_builder_smoke`의 stage7 레그도 함께 신설한다. 씰 복원까지가 한 단위다.

**S3-b. 게이지 잔량 계측 (L3)**

각성 완료 프레임의 `boss_special_gauge` 값과, 각성 완료부터 실제 궁극기 발동까지의 실경과 시간을 라이브 3판 기록한다. 확인할 가설 두 가지.
- (a) 7점제 개편으로 각성 임계가 4점으로 밀리면서 그때까지 누적 게이지가 원본(3/5점)보다 높아졌는가.
- (b) 소모처(분신 100, 구름 120, 표창 30, 영체탈주 30, 대쉬 50)의 실제 발동 빈도가 원본보다 낮아 게이지가 덜 빠지는가.

S2 착지 후에 계측해야 한다. 오오라 방어 +90 수급과 30% 무료 시전(구름·분신 각각)이 양방향으로 게이지 곡선을 바꾸기 때문이다.

**S3-c. 신설 유예 (사용자 확답 시에만)**

소유자는 `stage7_akamu_awakening_state.gd`가 아니라 `stage7_akamu_superspeed_state.gd`다. `try_start()`(:116-156)가 이미 `cooldown_remaining_sec > 0.0` 게이트(:127)를 갖고 있으므로, `complete_awakening` 직후 `set_cooldown_remaining(TEMP_STAGE7_AWAKENING_ULTIMATE_DELAY_SEC)`(:108-110)를 호출하는 것이 기존 게이트를 재사용하는 최소 변경이다.

`_complete_awakening`(`stage7_akamu_state.gd:631-635`)의 인라인 조건절에 리터럴을 새로 심는 것은 금지다(GRT-054 파생 임계값 리터럴 트랩 재발).

이 변경은 **원본 이탈**이며 파리티 문서에 신설임을 명시해야 한다. 값은 발명하지 않는다. 사용자 확답 항목이다.

---

### 3. 신규 TEMP 상수

전부 신설값이며 원본 근거가 없다. 튜닝은 이 상수 하나만 고치면 되도록 단일 정본을 둔다(GRT-054 회피).

| 상수명 | 소유 파일 | 초기 제안값 | 성격 |
|---|---|---|---|
| `TEMP_GOLDEN_CLONE_CHANCE` | `stage7_akamu_clone_state.gd` | `0.60` | 개체 단위 황금 굴림 확률. 보스 피격 드랍 병용 시 0.40 이하 재조정 필요 |
| `TEMP_GOLDEN_CLONE_MUHON_DROPS` | `stage7_akamu_clone_state.gd` | `1` | 황금 분신 1기 처치당 드랍 개수 |
| `TEMP_GOLDEN_CLONE_TINT` | `stage7_akamu_playfield_renderer.gd` | `Color(1.0, 0.82, 0.32)` | 곱연산 틴트 |
| `TEMP_GOLDEN_CLONE_GLOW_ALPHA` | `stage7_akamu_playfield_renderer.gd` | `0.35` | 베이크 텍스처 언더레이 밝기. GRT-047 대응 밝은 코어 |
| `TEMP_GOLDEN_CLONE_GLOW_RADIUS_SCALE` | `stage7_akamu_playfield_renderer.gd` | `1.15` | 분신 SIZE 대비 언더레이 반경 배율 |
| `TEMP_GOLDEN_CLONE_GLITCH_COLORS` | `stage7_akamu_playfield_renderer.gd` | 금·백금 3색 배열 | 소멸 글리치 대체 팔레트 |
| `TEMP_STAGE7_ULTIMATE_COOLDOWN_SEC` | `stage7_akamu_superspeed_state.gd` | `50.0` | 해금 시 초기 쿨다운 + 재사용 쿨다운. 원본 25초에서 신설 이탈 |

캐리어 드랍 물리 상수(DROP_SIZE 12.0 등)는 스테이지 6에서 **이식**하는 값이므로 TEMP를 붙이지 않는다. 오오라 상수는 전부 원본 1:1이므로 신규 상수가 없다.

---

### 4. 씰 계약

**공통 규칙 3가지.**
- 레그 구성은 항상 긍정 레그와 반증 레그를 짝으로 세운다. 반증 레그는 격리된 세팅에서 돌리고, 센티넬로 레그 도달을 확인한다(공허 GREEN 방지).
- 씰 실행 판정은 어서션 카운트와 함께 `SCRIPT ERROR` 및 `Invalid call` 라인 수를 반드시 0으로 확인한다(GRT-040. 레그 중단은 기능 부재와 구별 불가하다).
- 무작위 시드를 쓰는 레그는 시드를 고정한다. 무작위 시드는 낮은 확률로 false-GREEN을 만든다.

**L0 (씰 등재)**
- 레그: CI yml과 pre-push 배열 양쪽에 2종이 존재하는지 문자열 대조.
- 반증: 한쪽에서만 제거한 상태로 락스텝 검증기를 돌려 RED가 나는지 확인. 안 나면 검증기 자체가 결함이다.
- 증거: 등재 후 첫 실행에서 slice5 30건, pause context 5건이 그대로 재현되는지(베이스라인 고정).

**S3-a (R21)**
- 대상 씰: `stage7_akamu_slice5_smoke.gd:232-267`, 신설 `frame_flow_deps_builder_smoke` stage7 레그.
- 긍정 레그: `deps["stage7_akamu_freeze_context"]`에 `active_item_boss_skill_cooldown_paused = true`를 실은 상태로 각성 완료 → 궁극기 미발동, 게이지 250 그대로 보존(현재 RED 문구 "expected 250.00000, got 0.00000"이 그대로 판정 지표).
- 반증 레그: 같은 컨텍스트에서 플래그를 false로 → 궁극기 즉시 발동. 이 레그가 GREEN이어야 게이트가 항상 막는 게 아님이 증명된다.
- 반증 레그 2: `battle_frame_flow_controller.gd:81`을 인자 없는 원래 호출로 되돌린 임시 패치에서 긍정 레그가 다시 RED가 되는지. 되지 않으면 씰이 그 지점을 보고 있지 않은 것이다.
- 증거: slice5 실패 건수가 30건에서 최소 4건 감소.

**S2 (오오라)**
- 대상 씰: `stage7_akamu_slice5_smoke.gd`(서브스텝 :270-370, 분신 우선권 :373-399, 프레임플로우 각성 :160-229), `ball_boss_skill_pause_context_smoke.gd`(:36-56, :114-135).
- 레그 1 (스윕 판정): `BallMotionStepper.step`이 `event == "stage7_wind_aura"` 반환, `ball_pos.y > 75.0`.
- 레그 2 (분신 우선권): 오오라 안쪽에 분신이 있을 때 `event == "none"` + `stage7_akamu_clone_collision_reserved == true`. 즉 오오라가 발동하지 **않아야** 한다.
- 레그 3 (스냅샷 왕복): `step_motion` 후 `scene.ball_vel.y > 0.0`. 이것이 GRT-049 대응 레그다.
- 레그 4 (오디오 1회): 서브스텝 반사가 블록 큐를 정확히 1회 발행.
- 레그 5 (디바운스, 신설): 공을 반경 90 안에 머물게 두고 여러 서브스텝·여러 프레임을 진행시켜, 재타격 간격이 0.30초 미만으로 좁혀지지 않는지 계측. 원본은 렌더 프레임당 1회 평가였고 포팅본은 물리 서브스텝이므로 평가 빈도가 다르다(GRT-053). `hit_cooldown_remaining_sec`가 `advance_runtime`에서만 감소하므로 같은 프레임 재진입은 이론상 안전하지만, 이론이 아니라 계측으로 봉인한다.
- 레그 6 (소유권 가드 반증): 보스 소유 공, 서브 대기 중, `ball_vel.y >= 0`(하강 중) 세 조건 각각에서 오오라가 발동하지 않는지 3개 독립 레그.
- 레그 7 (소진·재충전): 5회 타격 후 depleted, 10초 후 재충전, depleted 중에는 판정도 렌더도 없음.
- 반증: `_build_step_context`의 2키 포워딩을 임시로 제거한 상태에서 레그 1과 3이 RED가 되는지. GREEN이면 씰이 폴백 경로를 보고 있는 것이다.
- 증거: slice5 실패 건수 추가 감소 + pause context 5건 중 3건 해소(나머지 2건은 선재 RED로 분리 보고).

**S1 (황금 + 무혼)**
- 레그 1 (굴림 1회성): 시드 고정 후 `spawn_entities` 1회 호출 → golden 벡터 캡처 → `update_entities`를 300프레임 돌린 뒤 golden 벡터가 문자 단위로 동일. **이것이 퍼프레임 굴림 반증의 정본 레그다.**
- 레그 2 (결정성): 동일 시드 2회 실행에서 golden 벡터 동일, 다른 시드에서는 달라짐. 후자가 없으면 굴림이 아예 안 걸린 것을 못 잡는다.
- 레그 3 (스트림 배치): 첫 엔티티의 `velocity_x`와 `motion_noise_state`가 황금 굴림 도입 전후로 동일. 마지막 소비 규칙을 봉인한다.
- 레그 4 (드랍 스폰 조건): 황금 분신이 공에 맞으면 드랍 1개, 일반 분신이 맞으면 0개, 황금 분신이 **수명 만료**로 사라지면 0개. 세 번째가 공짜 파밍 반증이다.
- 레그 5 (이중 스폰): 같은 분신에 대해 연속 두 프레임 충돌을 시도해 드랍이 1개를 넘지 않는지. dying 제외 가드에 의존하지 말고 관측한다.
- 레그 6 (수령): `runtime_perk_state`가 실린 deps에서 수거 시 무혼 +1, deps가 비면 드랍이 **살아남는다**(fail-loud 규약).
- 레그 7 (바닥 소멸): `pos.y > play_height - size`에서 수령 없이 소멸.
- 레그 8 (프리즈 양방향): 게임플레이 프리즈 중 드랍 낙하 정지 여부와 해제 후 재개. 확정된 정책에 맞춰 양방향으로 못박는다.
- 레그 9 (라운드 경계 양방향): 득점 시 미수거 드랍의 소멸 또는 보존. 확답 정책대로.
- 레그 10 (좌표 변환): GPU 슬롯 경로에 넘어간 pos가 `game_offset + (playfield_pos + shake) * render_scale`와 일치하고, 폴백 경로에 넘어간 pos는 **변환되지 않은 원좌표**임을 각각 단언. 반쪽 랜딩(GRT-031) 방지.
- 레그 11 (호스트 잔상): 드랍 배열이 비워질 때 `hide_all_existing_hosts()` 호출.
- 레그 12 (존재 감지): 드랍만 남은 상태에서 `_has_runtime_state()`가 true.
- 픽셀 QA(구조 씰로 대체 불가): 비헤드리스 Vulkan 캡처로 (a) 드랍이 분신이 죽은 자리에서 나오는지, (b) 황금 분신이 일반 분신 대비 **강한 임계 픽셀 카운트** delta를 갖는지. 약한 임계로 판정하지 않는다(GRT-047 처방).
- 락스텝: `stage7_akamu_slice3_smoke.gd`의 시드 4개 기대값을 같은 커밋에서 갱신.

**S3-c (유예, 조건부)**
- 긍정 레그: 각성 완료 후 유예 초 동안 궁극기 미발동, 게이지 250 보존.
- 반증 레그: 유예 경과 직후 발동. 그리고 `TEMP_..._DELAY_SEC = 0.0`에서 기존(원본 파리티) 즉시 발동이 그대로 재현. 이 레그가 GREEN이어야 원복 경로가 살아 있음이 증명된다.
- 반증 레그 2: 유예 중 보스 스킬 쿨다운 일시정지가 걸리면 유예가 **추가로 연장되지 않고** 기존 게이트와 중복 계산되지 않는지. `set_cooldown_remaining` 재사용의 부작용 지점이다.

---

### 5. 함정 예방

**★60% 굴림 퍼프레임 방지 계약 (GRT-011)**

1. 굴림 지점은 `stage7_akamu_clone_state.gd:231-251` 엔티티 dict 리터럴 **단 하나**다. 다른 곳에서 황금 여부를 재계산하는 코드를 작성하지 않는다.
2. 결과는 엔티티 dict의 `"golden"` 필드에 **영속**된다. 매 프레임 읽기만 한다.
3. 금지 호출 지점 목록을 명시한다. `update_entities()`, `_draw_clone()`, `_draw_clone_sprite()`, `query_ball_collision()`, `resolve_ball_collision()`, 드랍 스폰 훅, 캐리어의 `update()`. 이 7곳 중 어디에서도 `randf`를 호출하지 않는다.
4. 그렙 가드를 리뷰 항목으로 넣는다. `stage7_akamu_playfield_renderer.gd`의 분신·드랍 드로 경로와 `stage7_akamu_starpoint_state.gd`의 드로 리스트 경로에 `randf`/`randi`/`randomize` 0건.
5. 씰 레그 1(300프레임 후 golden 벡터 불변)이 이 계약의 실행 가능한 봉인이다.
6. 같은 원칙을 S2의 30% 무료 시전에도 적용한다. 그 굴림은 프레임 단위가 아니라 **오오라 블록 이벤트 단위**이며, 그 이벤트 자체가 `HIT_COOLDOWN_SEC = 0.30` 디바운스 뒤에 있다. 공을 반경 안에 세워두고 0.30초당 최대 1회 굴림임을 계측 레그로 확인한다.

**GRT-049 볼패스 소유자 스냅샷 환불**
판정 결과는 "해당 없음 + 조건부"다. `boss_special_gauge`는 `_gauge_state.value`(레지스트리 인스턴스 필드)이고 `BallUpdateOwnerSnapshot.build()` 키 목록에도 `battle_scene_state.gd`에도 없다. 무혼 수령은 `runtime_perk_state.collect_star_points()` 직접 호출이고 드랍 배열은 stage7 캐리어 소유다. 따라서 게이지와 무혼 때문에 `scene` 미러링을 추가할 필요는 없다.
반대로 **반사 결과 `ball_pos`와 `ball_vel`은 스냅샷 왕복 키**다. 반드시 `scene[...]`에 쓴다. `owner.set(...)`이나 `context[...]`에 쓰면 프레임 끝에 조용히 환불된다. 이것이 S2-c 핸들러가 반드시 존재해야 하는 진짜 이유다.
드랍 스폰 훅에서 `scene`이나 owner 스탯 필드를 건드리면 그 순간 GRT-049에 걸린다. 건드리지 않는다.

**GRT-047 발광 예산 / GRT-056 머티리얼 스왑**
분신 렌더러는 셰이더도 머티리얼도 쓰지 않는 순수 즉시 `_draw` 경로다(파일 전체에 `material`/`BLEND_MODE` 0건). 곱연산 틴트는 원본 픽셀보다 절대 밝아지지 않으므로 황금 틴트만으로는 어두운 갈색으로 읽힌다. 처방은 기존 베이크 텍스처를 황금 modulate로 **뒤에 까는 밝은 코어 재공급**이다. `canvas.material` 스왑으로 ADD를 시도하면 no-op이고, 별도 CanvasItem을 세우면 GRT-045(스크린 공간 FX 호스트 플레이필드 클립)와 GRT-008(음수 z 대 조상 불투명 채움)까지 동반된다. modulate 교체 + 베이크 오버레이가 유일하게 값싼 정답 경로다.

**GRT-004 미존재 에셋 퍼프레임 재-stat**
신규 에셋 0장이 이 작업의 계약이다. 오오라 블록음은 이미 임포트 산출물까지 확인됐고, 황금 분신은 기존 베이크 텍스처를 재사용하며, 무혼 드랍은 전 스테이지 공용 `CommonStarpointVisualHost`를 쓴다. `preload` 경로를 새로 추가할 일이 있으면 반드시 실재 파일이어야 하고, 런타임 `load` 폴백을 드로 경로에 두지 않는다.

**GRT-030 슬롯 인덱스 배열 시프트**
세 지점이 위험하다.
- `spawn_entities`의 MAX_ENTITIES 상한 처리(:216-227)가 dying 항목을 **제거**하므로 그 시점에 살아있던 모든 인덱스가 무효화된다.
- `update_entities`(:261-270)가 death 완료 항목을 제거하며 인덱스를 민다.
- `resolve_ball_collision`의 `clone_index`는 그 프레임 그 순간에만 유효하다.
계약. 프레임을 넘겨 보관해야 하는 식별자는 인덱스가 아니라 엔티티 dict의 `id` 필드를 쓴다. golden 플래그는 `begin_dying` 호출 **전**에 같은 프레임의 참조에서 읽고, 배열을 재조회하지 않는다. 드랍 캐리어는 분신 인덱스를 일절 보관하지 않는다.

**GRT-053 호출 경로 파리티**
원본은 오오라 판정을 드로 루프 3곳에서 프레임당 1회 돌린다. 포팅본은 물리 서브스텝으로 옮긴다. 수식이 같아도 호출 경로가 다르면 파리티가 깨지므로, 평가 빈도 차이가 0.30초 디바운스에 흡수되는지를 씰 레그 5로 확인한다. 반대로 원본 구조를 그대로 베껴 렌더가 `ball_vel`을 쓰게 하면 GRT-018과 GRT-049에 정면으로 걸린다.

**GRT-054 파생 임계값 리터럴**
황금 확률, 유예 초, 드랍 개수 전부 상수 단일 정본으로 두고 조건절에 리터럴을 심지 않는다. 특히 `_complete_awakening`(:631-635) 인라인 조건절.

**GRT-040 공허 GREEN / 레그 abort**
slice5는 이 작업 종료 시점에도 R02/R20/R23 때문에 RED로 남는다. 따라서 판정 지표는 "GREEN"이 아니라 "실패 건수 감소 + SCRIPT ERROR 0". 각 단계마다 감소분을 숫자로 보고한다.

**GRT-041 CI 락스텝**
CI 포커스 목록과 pre-push `$focusedSmoke` 배열을 항상 함께 수정한다. 한쪽만 고치는 커밋은 반려.

**GRT-045 구조 GREEN 대 픽셀**
드랍 좌표 변환과 황금 시각 구분은 구조 스모크로 판정하지 않는다. 비헤드리스 캡처가 필수 게이트다.

**WIP 소실 사건 재발 방지**
R03·R21 복구 소스는 stash에서 **읽기 전용 추출만** 허용된다. `git stash apply`와 `git stash pop`은 절대 금지다. `git reset`, `checkout`, `clean`, 광범위 `git add -A`도 금지다.

---

### 6. 사용자 확답 필요

**A. 항목 3의 실체 (최우선)**
원본에 초각성과 궁극기 사이의 시간 게이트는 존재하지 않는다. 3본 교차 확인 완료다. 사용자가 기억하는 "일정 시간"은 게이지가 250까지 차오르는 데 걸리는 창발적 지연으로 보인다. 선택지 3가지.
- A1. R21 게이트 복구 + 게이지 계측만으로 마무리한다(파리티 유지).
- A2. 계측 후 각성 시점 게이지가 원본보다 높다고 확인되면 각성 임계 4점 재조정 등 게이지 곡선 쪽을 손본다.
- A3. 원본 이탈을 승인하고 신설 유예 상수를 넣는다. **이 경우 유예 초를 지정해 주셔야 한다. 발명하지 않는다.**

**B. 황금 확률 해석과 초기값**
개체 단위 60%(해석 A)를 권고한다. 세트당 1기 해석(B2)은 판당 약 3.7개로 목표 7~9에 구조적으로 미달이고, 확률을 100%로 올려도 6.2로 미달이다. 해석 A의 추정치는 판당 약 10.4개로 목표를 약간 상회한다. 초기값 0.60으로 갈지, 목표 중앙에 맞춰 0.45~0.50으로 시작할지.

**C. 보스 피격 확률 드랍 병용 여부**
각성 전 구간(0~3점)은 분신 세트가 2기뿐이라 수급이 얇다. 스테이지 5식 보스 피격 롤(double 0.007 / single 0.018)을 병용하면 판당 약 4.4개가 추가로 깔린다. 병용 시 합계가 목표를 크게 넘으므로 황금 확률을 0.40 이하로 내려야 한다. 병용할지 여부.

**D. 라운드 경계 미수거 무혼 정책**
스테이지 5는 득점마다 소멸시킨다(`reset_round` → `_clear_combat_state`). 스테이지 7도 소멸시킬지, 라운드를 넘겨 보존할지. 훅 지점이 `clear_round_transients()` 대 `reset()`으로 갈린다.

**E. 서브 대기 중 드랍 낙하 지속 여부**
스테이지 5는 서브 대기 중에도 굴린다(득점 직후 낙하 중이던 무혼이 동결되지 않게). 스테이지 7도 동일하게 갈지.

**F. 수거 판정 형태**
원형(스테이지 5·6) 대 사각(스테이지 1·3·4). 스테이지 7 기본값은 원형을 권고한다.

**G. 부가 시스템 포함 여부**
파티클, 별점 다우징(`starpoint_dowsing_attraction`), 수호령 별빛 회수 브릿지(`lingpet_starlight_tracking_bridge`). 포함하지 않으면 해당 아이템과 수호령 스킬이 스테이지 7에서만 무효가 된다.

**H. MAX_ENTITIES 8 상한에서 황금 우선 보존 여부**
각성 4기 세트가 dying 잔재와 겹치면 일부가 생성되지 않는다. 황금을 잘림 대상에서 제외할지, 특별 취급 없이 둘지.

**I. 드랍 스폰 좌표**
분신 몸통 중앙(`clone_rect.get_center()`) 대 공 접촉점(`contact_point`). 스테이지 5는 ball_pos 기준 산포를 쓴다.

**J. 황금 소멸 글리치 팔레트 교체 승인**
현재 시안·마젠타·옐로는 황금 분신에서 정체성이 깨진다. 금·백금 계열 대체를 제안한다.

**K. 각성 트리거의 서브 대기 게이트**
포팅본은 원본에 없는 `waiting_for_serve`/`ball_active` 게이트를 각성 트리거에 걸고 있다(`stage7_akamu_awakening_state.gd:88-91`). 원본은 서브 대기 중에도 초각성이 예약·완료된다. 의도된 설계 결정으로 문서화할지, 원본대로 되돌릴지.

---

### 7. 후속으로 미룰 것

1. **궁극기 대쉬 AI 복구 (R02/R20/R23).** slice5 RED 30건 중 후반 10여 건과 별도 씰 `stage7_akamu_superspeed_dash_parity_smoke` RED 19건이 여기 속한다. `boss_ai_state.gd`의 `STAGE7_SUPERSPEED_*` 상수 8개와 함수 8개, `try_commit_common_boss_dash` 호출자, `_clear_motion_impulses_for_scripted_control`이 통째로 소실된 상태다. 이번 3항목과 파일은 겹치지만 도메인이 다르므로 별 트랙으로 뺀다. 다만 slice5가 이번 작업으로 GREEN이 되지 않는 이유가 바로 이것임을 커밋 메시지에 남긴다.
2. **`ball_boss_skill_pause_context_smoke.gd:77-84`의 선재 RED 2건.** `active_item_runtime.get_ball_collision_context()` 직접 검증이며 오오라와 무관하다. 티어가스 pause 플래그 생산자는 살아 있으므로 별건 조사 대상이다.
3. **스테이지 8 미노타우로스 무혼 캐리어 부재.** 무혼 경로 0건인 스테이지는 7과 8뿐이다. 스테이지 7 캐리어가 서면 같은 패턴으로 8도 필요해진다.
4. **아카무 비전초식 등재 시 무혼 전환 분기와의 상호작용.** `runtime_perk_starpoint_collection_flow.gd:131-136`이 예약된 보스 비전초식 오퍼가 있으면 무혼 전환을 끈다. 아카무 비전초식이 나중에 들어오면 여기서 충돌한다.
5. **나이틀리 사각지대 전수 감사.** 이번에 등재하는 2종 외에도 CI·pre-push 어디에도 없는 런타임 슬라이스 씰이 더 있을 가능성이 높다. 30건 RED가 방치된 구조적 원인이므로 별도 감사가 필요하다.
6. **각성 임계 4점(7점제 재보정)의 밸런스 검증.** 원본 3/5 = 0.60에서 4/7 = 0.571로 앞당겨졌다. 항목 3의 체감 원인 후보 (a)이며, L3 계측 결과에 따라 재조정 대상이 될 수 있다.
7. **오오라 복구 후 무료 시전 빈도 상승의 밸런스 QA.** 원본 버그(`global` 누락으로 죽은 분신 분기)를 포팅본이 의도적으로 살려 두었으므로, 배선 후 무료 시전이 구름 30% 단독에서 구름 30% + 분신 30%로 올라간다. 이는 파리티 이탈이 아니라 기록된 의도이지만, 라이브 체감 QA를 동반해야 한다.
8. **황금 분신 전용 사운드.** 이번 범위에서는 신규 에셋 0장을 계약으로 잡았다. 황금 스폰음이나 처치음이 필요하다는 판단이 서면 별 슬라이스로 뺀다.