# Stage 5 홍련 Godot 포팅 기획서

작성일: 2026-05-17

## 0. 결정

원본의 네메시스 스테이지는 현재 Godot 진행 순서에서 제외하고, 원본 홍련 스테이지를 user-facing **Stage 5 홍련**으로 포팅한다.

- 현재 Godot 기준: `current_stage == 5`는 홍련이다.
- `current_stage == 6`은 테트리서다(원본 Python 7 포팅). 별도 기획 `docs/stage6_tetriser_port_plan.md`에서 다루며, 이 홍련 문서는 Stage 6을 구현하지 않는다. (2026-06-03 갱신: 이전 "6 비워 둠" 결정 폐기)
- Python 원본의 `STAGE_HONGLYEON_FIRE = 5`, `stage5`, `animated_bg_stage5`, `Stage5ChineseMarket`는 홍련 동작 참조다.
- Python 원본의 `STAGE_NEMESIS_OCEAN = 6`, `stage6`, `animated_bg_stage6`는 네메시스 참조이며 이번 포팅 범위가 아니다.

## 1. 비목표

- 네메시스 해상전, 전함, 미사일, 인터셉터, 네메시스 상자 보상은 포팅하지 않는다.
- Godot Stage 6에 홍련을 중복 라우팅하지 않는다.
- `scenes/main.gd`나 대형 scene shell 블록에 홍련 전용 로직을 붙이지 않는다.
- Python의 procedural draw 코드를 그대로 베끼지 않는다. 타이밍과 상태 의미만 참조하고, Godot 쪽은 모듈화된 VFX / renderer / state로 재구성한다.

## 2. 자산 명명 정책

Godot에 들어오는 홍련 자산은 모두 `stage5_hongryun_*` 접두사를 사용한다.

예:

- `godot/assets/sprites/hud/stage5_hongryun_center_background_imagegen_v1.png`
- `godot/assets/sprites/hud/stage5_hongryun_dragon_head_sheet_imagegen_v1_16f.png`
- `godot/assets/sprites/stage5/hongryun_boss_walk_left.png`
- `godot/assets/sounds/stage5_hongryun_charge.wav`

Python 원본에 `stage6_hongryeon_*`, `stage6_honglyeon_*`, `honglyeon_*`처럼 남아 있는 파일은 Godot 편입 시 복사 후 rename한다. 모듈 헤더, manifest, 또는 asset note에는 원본 경로를 한 줄로 남긴다.

## 3. 1차 모듈 경계

홍련은 `godot/scripts/stages/stage5/` 아래 새 모듈로 시작한다.

| Owner | 책임 |
|---|---|
| `stage5_hongryun_state.gd` | 홍련탄, 홍련폭염, 용 구슬 게이지, 라운드 / 결과 / 스테이지 이탈 cleanup |
| `stage5_hongryun_boss_skill_hud_renderer.gd` | 카드형 보스 스킬 HUD. Stage 1 달지 / Stage 2 / Stage 3 / Stage 4 패턴 재사용 |
| `stage5_hongryun_boss_actor_renderer.gd` | 홍련 보스 스프라이트, facing, attack / dash / hurt 연출 |
| `stage5_hongryun_playfield_renderer.gd` | 화염탄, 용 구슬, 홍련폭염 궤적, 충돌 / 피격 VFX |
| `stage5_hongryun_pillar_background.gd` | 중국 화염 배경, 필러 장식, 광폭화 배경 상태 |
| `stage5_hongryun_fire_machine_event.gd` | 원본 stage5 fire machine / dragon breath 이벤트의 Godot event state |

등록 대상은 `stage_runtime_router.gd`, `gameplay_stage_module_catalog.gd`, `battle_update_stage_runtime_deps_builder.gd`, `battle_resources.gd`, `game_audio.gd`, `gameplay_loop_audio_cleanup.gd`를 순서대로 확인한다.

## 4. MVP 세로 관통 순서

1. 번호와 진입
   - F5 피커에 `스테이지 5 / 홍련`만 보이게 한다.
   - Stage 6(테트리서)은 별도 기획 `docs/stage6_tetriser_port_plan.md`에서 다룬다. 이 홍련 MVP 단계 작업에는 Stage 6을 포함하지 않는다(비워 두는 게 아니라 별도 트랙).
   - Stage 4 clear 이후 Stage 5로 넘어가는 흐름은 홍련 라우터가 준비된 뒤 연다.

2. 시각 셸
   - 홍련 center background / pillar / boss idle을 먼저 표시한다.
   - 모든 자산은 `stage5_hongryun_*` 이름으로 Godot asset tree에 둔다.
   - stage entry에서 필요한 texture / sheet cache를 prewarm한다.

3. 홍련탄
   - Python 기준 round 시작 2.5초 후 활성, 3.5~5초 쿨다운, 기본 1발 / 40% 확률 2~3발을 참조한다.
   - 공 정지, serve wait, stopwatch, result 진입에서 투사체와 audio loop가 남지 않게 한다.

4. 용 구슬 게이지
   - 최대 5칸, 홍련탄 피격으로 충전, 독안개 장갑류 drain 참조는 별도 아이템 포팅 때 연결한다.
   - 보스 카드 HUD와 별도로, live gameplay에서 읽히는 작은 게이지로 먼저 구현한다.

5. 홍련폭염
   - 1.4초 charge (원본 1.0초에서 cinematic VFX 강도와 맞춰 +0.4s, 2026-05-18 결정), snake trail, release explosion, `hongcharge.wav` / `hongshoot.wav` 타이밍을 참조한다.
   - `flame_trail_active`류 ball-physics hijack은 `stage5_hongryun_state.gd` 안에 가둔다.
   - VFX는 texture pieces / sheet / shader / particles 조합으로 리마스터한다.

6. 보스 스킬 카드 HUD
   - 새 HUD 구조를 만들지 않는다.
   - `stage1/stage1_dalji_boss_skill_hud_renderer.gd`, `stage2/stage2_boss_skill_hud_renderer.gd`, `stage3/stage3_boss_skill_hud_renderer.gd`, `stage4/stage4_ponk_boss_skill_hud_renderer.gd`를 레퍼런스로 fork한다.
   - 카드 렌더러에는 홍련 보스 스킬인 홍련탄과 홍련폭염만 제공한다.
   - 화염기계 / 용숨결은 Stage 1 풍선기계처럼 맵 이벤트이므로 보스 스킬 카드에 넣지 않는다.

7. 화염기계 / 용숨결 이벤트
   - `events/stage5_event_integration.py`, `events/stage5_fire_machine_event.py`를 timing / spawn payload 참조로 사용한다.
   - phase scalar만 옮기지 말고 fire zone, dragon head, flame particles, hazard payload를 state / renderer가 실제로 소비하게 한다.

## 5. 리셋 규칙

홍련은 원본에서 `show_result()` 누락으로 다음 게임 Stage 1에 상태가 새던 전력이 있다. Godot 포트는 처음부터 한 함수로 묶는다.

`stage5_hongryun_state.gd`는 최소한 아래를 같은 cleanup 경로에서 정리한다.

- 홍련탄 배열 / 투사체 host
- `boss_throwing`에 해당하는 windup / release 상태
- 홍련폭염 active / charge / trail / explosion 상태
- `hongryun_hit_count`, `hongryun_ready`
- 홍련 전용 ball hold / ball physics override
- loop / sync audio와 detached VFX host

호출해야 하는 곳:

- round-end / score event 이후 serve-wait 진입
- result / game-end 진입
- stage transition / debug stage switch / full reset

## 6. QA 기준

- 2026-05-18 결정: Godot Stage 5 포팅 버전은 라운드 전환 시 홍련 dragon orb 게이지를 1칸 감소시키지 않는다. `reset_round()`는 전투 투사체 / ball hijack / inferno active 상태만 정리하고 `dragon_orb_count` 및 full gauge의 `inferno_ready`는 보존한다.
- F5 피커: Stage 5는 홍련. (홍련 MVP 시점에는 6번 비노출이었으나, 현재 Stage 6은 테트리서로 채워질 예정 — 피커 7→6 재라벨은 `docs/stage6_tetriser_port_plan.md` §4에서 처리. 이 홍련 문서의 수용 기준은 "Stage 5가 홍련 owner만 호출"까지다.)
- 라우팅: `stage_runtime_router.gd`가 Stage 5 홍련 owner만 호출하고 네메시스 owner를 호출하지 않아야 한다.
- 자산: Godot live path에는 `stage5_hongryun_*` 이름을 사용하고, Python `stage6_*` 이름이 runtime path에 남지 않아야 한다.
- 전환: Stage 4 -> Stage 5 진입, Stage 5 result, debug switch out, 새 게임 Stage 1 시작에서 홍련탄 / 홍련폭염 상태가 남지 않아야 한다.
- 성능: stage entry prewarm, first visible battle frame, steady-state projectile update를 분리해서 확인한다.
- 검증: `.gd` 수정 후 `godot/tools/run_headless_load_check.ps1`와 `godot/tools/run_warning_scan.ps1`를 실행한다.
