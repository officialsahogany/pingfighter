# 프레임 예산 최적화 세션 핸드오프 (2026-06-10~14)

Codex 리뷰용. 이 세션(fable-5 → opus-4.8)이 72FPS 프레임 예산 최적화로 한
작업의 전체 스코프, 커밋, 검증, 그리고 **아직 안 끝난 신규 회귀**를 정리한다.
설계 단일 소스는 `docs/frame_budget_72fps_optimization_design.md`,
진행 메모는 메모리 `project_stage2_stutter_investigation.md` /
`project_stage1_entry_loading_optimization.md`.

## [최신] 2026-07-02~03 세션: 240Hz 랩탑 실측 캠페인 (fable-5 + 사용자 적용)

측정 환경: **RTX 4060 Laptop / 240Hz 모니터 → Stable Monitor 리졸브 렌더
60 / 물리 60** (240÷4, 리졸버 정상 검증). 6/10~14 세션의 데스크톱
RTX 5070 / 144Hz / 72캡과는 머신·캡·로드아웃이 다르므로 더블링% 직접 비교
금지. 측정은 BattlePerf 플래그 3종 + `--log-file` 스탠드얼론 실행(에디터
디버거 파이프 관찰자 효과 없음), 더블링 판정은 60캡 기준 `process.shell.delta`
max ≥ 33.33ms(2틱). 원본 로그는 세션 스크래치패드(휘발)라 수치는 여기 박제.

### 출하된 수정 (전부 워크트리 WIP, 스모크 봉인 + 실측 검증)

상시 비용(합산 ~4ms/frame 회수):
1. 링펫 owner_sync/profile/skill surface 캐시 — owner_sync -27%, skill_effects -30%
2. 스테이지1 공유 보스스킬 레일 게이트 호이스트 — 스테이지≠1 낭비
   1.24ms → 0.003ms (`stage1_pillar_hud_scene_drawer._draw_stage1_boss_skill_hud`)
3. `get_snapshot()` 프레임/리비전 캐시 — 링펫 물리 2.9~3.2 → 0.92ms
4. `LingpetCatalog` active skill id 정적 인덱스 — 레일 `cards_draw`
   0.865 → 0.056ms (보스 카드 miss가 14펫 풀스캔+딥카피 타던 것 제거)
5. 레일 전용 협소 surface `get_rail_card_surface()` — 레일 `context_build`
   0.71 → 0.049ms (거대 스냅샷 빌드가 정보창 열릴 때만으로 강등)
6. 진단 라벨 다수 (stage3/4 post-HUD, rail 서브, egg_phase 4분할,
   round_dep 모듈별, character_info_prewarm 분해)

원샷 로딩 히치:
7. 전환 리셋 전 stage round-deps 스텝 + 키 단일소스
   (`ball_dependency_context.get_stage_round_dep_keys`) — 리셋 256 → 20ms
8. round-dep 스크립트 threaded load (`script_instance_cache.request_threaded_script`)
   — `stage2_pillar_background` 스크립트 포레스트 253 → 0.1ms
9. `character_info_prewarm` — resolve_module threaded(부트는
   `battle_scene_shell` 브리지 필수!) + 텍스트 batch 분할 = 686 → 47.7ms
10. 링펫 획득 컷인 reveal gate 동기 로드 제거(3s failsafe → 정지화 폴백) +
    알 아이템 사용 시점 스트리밍 킥 — 알 사용 184 → 12.8ms, 해피패스 부화
    egg_phase 50.9ms 확인. **단, run5의 679ms 급속부화 레이스는 미재현 —
    egg_phase 4분할 라벨로 감시 중** (재현법: 알 사용 즉시 최속 부화)

### 더블링 스코어보드 (run1 → run5, 동일 세션 내 추이)

| 스테이지 | run1 | run5 | draw 평균 |
|---|---|---|---|
| 1 | 12% | 18.4% | 5.3→5.2ms |
| 2 | 62.4% | 20% | 7.9→5.7ms |
| 3 | 94.7% | **2.8%** | 9.3→5.8ms |
| 4 | 96.8% | 47% | 10.7→6.8ms |
| 5 | 90.5% | 61.8% | 10.2→7.0ms |
| 6 | 미측정 | 79.4% | 7.1ms |

s4~5 잔여 더블링은 1틱 스킵 위주로 성질 변화(run1은 40~60ms 스톨 지배).

### 남은 백로그 (우선순위 순)

1. **스테이지 4~6 플레이필드/필러 draw 본편** — 액터 ~4.8ms + 필러 씬
   ~1.8ms, 설계서 S1/S2급 정적 캐싱 영역. 스테이지 6(테트리서)이 79.4%로
   현재 최악 + 첫 진입 원샷(전환 step result 리소스 714.8ms,
   `stage6.pillar.tetriser_boss_hud` 첫 드로 154.9ms) 미조사.
2. 721ms 컷인 급속부화 레이스 감시/재현 (라벨 심어짐).
3. **60Hz 모니터 + VSync On 릴리즈 기준 검증 런 미실시** (이번 세션은 전부
   240Hz→60캡 + vsync off).
4. character_info_prewarm 잔여 47.5ms 배치(runtime_perk 텍스트) 축소 —
   수용 범위라 저우선.

### 이번 세션이 백필한 트랩 (docs/godot_runtime_traps.md)

- Shared HUD Wrapper Prep-Before-Gate Trap (build-then-discard)
- Per-Frame Catalog Lookup Trap (miss-case full scan + deep copies)
- Hot-Path Lazy Init Trap에 전환 스텝 순서 변형 + threaded script fix shape
  + 부트 shell 브리지 footgun 추가
- Threaded Texture trap에 readiness-gate corollary (게이트는 기다려야지
  동기 로드 금지) 추가

## 0. 브랜치/커밋 상태 (먼저 읽을 것)

- 현재 브랜치: `feature/plaza-hub-s4-s6b5`. 아래 4개 최적화 커밋은 **전부 이
  브랜치 history에 포함**되며 HEAD의 조상이다(스트랜드 아님). 그 **위에**
  plaza/lingpet/lumion 신규 커밋(`f241f66b0`…`a40485c33`)이 쌓여 `git log -5`
  상단엔 안 보인다 — `git show <hash>`로 직접 리뷰.
- checkpoint 브랜치 HEAD 유동 트랩 주의: 이 repo는 외부 세션이 브랜치/HEAD를
  세션 중 전진시킨다. 리뷰/체리픽 전 `git branch --contains <hash>`로 위치 재확인.

## 1. 출하된 최적화 커밋 (리뷰 대상, 신→구)

### `e5e9316c6` — commando firearm fx host 발사프레임 딥카피 제거
- 파일: `godot/scripts/stages/stage1/stage1_commando_firearm_renderer.gd` (+9),
  `godot/tests/commando_firearm_renderer_fx_host_lifecycle_smoke.gd` (+69)
- 변경: `_sync_fx_host`가 매 발사 프레임 `draw_items.duplicate(true)`로 전 VFX
  배열(투사체/탄피/머즐/임팩트/잔류)을 딥카피 → impact_flashes 한 키만 grenade
  필터본으로 교체하려는 목적. fx host는 draw_items에 read-only(sync_state가
  자체 `duplicate(false)`, anchor 엔트리도 복사 후 수정)임을 코드로 확인 →
  얕은 `duplicate(false)`로 강등.
- 대상 비용: `actors.stage2.commando_firearm` draw 0.65/1.30ms (솔저 최대 단일
  actor draw 항목). 솔저 발사 중에만 발생(비발사 프레임은 기존 게이트로 빠짐).
- **리뷰 포커스**: 얕은 카피로 충분한지 = fx host가 공유 배열을 mutate 안 하는지
  재확인(`stage1_commando_firearm_fx_host.gd` `_get_anchor`/`_apply_state`/`_draw`
  전부 read-only). 스모크에 격리 가드 추가(필터본 전달 + 원본 불변), mutating
  no-copy로 revert 시 실패 검증 완료.

### `798754ba1` — F1: mythic 라운드 시작 풀싱크 슬림화
- 파일: `mythic_item_runtime.gd` (+7), `mythic_item_adversity_armor_runtime.gd`
  (+11), `AGENTS.md` (+19), `mythic_round_start_sync_smoke.gd` (신규 +169)
- 변경: `on_round_start`가 매 라운드 재시작마다 254키 owner 풀싱크를 **2회**
  (비장착 adversity 분기 + 말미) 실행 → 실측 3.0~3.5ms/재개프레임 = 72FPS에서
  확정 더블링. 비장착 분기는 owner-가시 상태 실변경 시에만 풀싱크, 말미는
  change-gated `sync_transient_owner_state`(drift net)로 교체. adversity 발동
  분기는 자체 풀싱크 유지(드물게, 의도).
- 안전성: adversity 직접 owner 키는 `battle_scene_state.DEFAULT_VALUES` 스키마에
  없어 실게임에서 원래 silent no-op이었고, 실 전파 채널은 스키마에 있는
  `mythic_item_state` dict(=transient 싱크가 갱신).
- 검증: QA 합격(루틴 라운드 0.4~1.1ms, 갱신 후 실측). 스모크가 set-attempt 카운팅
  schema-gated owner로 4계약 봉인, **revert 시 254 attempts로 실패 확인**.
- **리뷰 포커스**: 라운드 경계에서 바뀌는 owner 키가 transient 싱크에 다 포함되는지.
  `AGENTS.md`에 "이벤트 경계 훅 풀싱크 금지" 규칙 백필됨.

### `38b980583` — round-restart / reset-ball perf 계측
- 파일: `battle_scene_match_event_driver.gd` (+14), `battle_scene_match_flow_driver.gd` (+8)
- 변경: 무계측이던 라운드 재시작 체인에 서브 라벨 추가(`physics.round_restart.*`,
  `physics.reset_ball.{ball_driver,boss_health,mythic_round_start,weather_round_start}`).
  이 라벨이 F1의 3.0~3.5ms 주범(mythic_round_start)을 귀속시킴. 순수 계측, 동작 불변.

### `f3627a17e` — 스테이지1 진입 로딩 36초→9초 (별 워크스트림, 이 세션이 커밋만)
- 파일: `battle_boot_warmup_controller.gd`, `battle_scene_shell.gd`,
  `project_resource_loader.gd`, `battle_resources.gd`, `character_select_screen.gd`,
  신규 `battle_entry_background_prewarm.gd` (+157), 스모크 2종, `AGENTS.md` (+35)
- 변경: budgeted warmup(프레임당 1스텝 → 24ms 예산 배칭) + 캐릭선택 유휴
  백그라운드 프리웜. 실측 워밍업 2,143→~205프레임.
- **리뷰 포커스**: budgeted 루프의 yield 가드 3개(공유 스레디드 슬롯 /
  battle_resources 자체 슬롯 / PSO 노드) — 누락 시 spin-poll로 MAX_POLLS 조기
  도달→동기 폴백 강등(실측 step02 172→7,469 스핀 사례). `AGENTS.md`에 백필됨.
  단일 소스: 메모리 `project_stage1_entry_loading_optimization.md`.

## 2. 검증 상태 요약

전 커밋: 파스(--check-only) + 해당 스모크 + 워닝스캔 청크 클린. 반증검증(revert로
스모크 실패 확인) F1·commando 완료. **인게임 felt-QA**: F1 합격(사용자), 로딩 합격
(사용자). commando는 zero-behavior-change(딥/얕은 카피 동작 동일, 스모크로 증명)라
별도 felt-QA 불요.

## 3. ★ 미해결 신규 회귀 (다음 세션 1순위 — Codex 진단 환영)

plaza/ringcode/lumion(천둥낙뢰) 신규 커밋(`f241f66b0`…`a40485c33`) 이후 프레임드랍
재발. 측정: `godot.log` 2026-06-14 11:06, **stage1 viper 140 윈도우**.

- **더블링 94.3%(132/140), shell-over-budget 135/140** — 이전 stage1 11~20% 대비 폭증.
- **✅ [해결·커밋 `24de004fa`, Codex 진단] 상시 회귀 `physics.callback.mythic_items`
  0.67→3.04ms (123/140 윈도우).** 근본원인은 per-item 가격이나 last-pushed 미스가
  **아니라**, 계측 커밋 `11f0a86bc`가 perf_logger back-compat arg-count 체크를
  **uncached `get_method_list()` 스캔으로 매 mythic 틱 실행**한 것. fix = 캐시된
  `_get_method_argument_count`로 라우팅 + uncached 헬퍼 제거(active-item 경로와 동일).
  가드 스모크 `item_update_boss_health_reset_smoke`. 벤치 첫 2389us→캐시 22.2us.
  (lumion이 mythic 아닌 lingpet 스킬인데 mythic_items가 뛴 게 단서였음 — 비용이
  per-item이 아니라 update 디스패치 리플렉션이었던 것.)
- `physics.callback.lingpet` 1.18ms(123/140, worst 17.6ms): owner_sync 0.43 +
  skill_effects 0.21 + companion_motion 0.15 + ball_hit 0.13 + strike_arm 0.12.
- **아티팩트(주범 아님, 혼동 주의)**: `draw.overlay.lingpet_debug` max 129.9ms는
  **13/140 윈도우뿐 = 디버그 피커 열어둔 측정 아티팩트** + 첫-열기 lazy-init
  스파이크(실버그지만 별건). `begin_ball_spawn` 129ms는 1/140 = 라운드시작
  일회성 lazy-init. `character_info` 17/140 = TAB 모달.
- **진단 방법론(메모리 `feedback_pingfighter_fps_audit_order.md` 0단계)**:
  유병률 집계(present-in-X/N) + 비용×유병률 정렬(peak max 아님) + 아티팩트
  분류표. "3ms×88%프레임 > 129ms×9%프레임."

## 4. 블로커 / 보류

- **트램펄린 묶음 미커밋(active_item_* 12 + ball_motion_* + trampoline 신규 + game_audio)**:
  Codex 리뷰 통과(스모크/워닝스캔/headless 전부). **커밋 시 언트랙드 8파일 반드시
  동반**(`active_item_effect_controller.gd:14`→trampoline_runtime,
  `active_item_effect_renderer.gd:6`→trampoline_renderer, `active_item_catalog.gd:29`
  →trampoline.png preload; 누락 시 로드 실패). 부수: `lingpet_koyora_doll_curse_beam_vfx_design.md`
  가 삭제된 헬퍼 `_any_beam_hits_boss(owner)` 잔존(doc-only). 이 묶음 커밋 전엔
  `physics.callback.effects`(엉킴) 경로 손대지 말 것.
- **stage2 soldier 스파이크**: commando(완료) 외 나머지는 fresh 측정 필요
  (워크플로 에이전트의 "stage2_pillar_background 11ms" attribution이 실측 0.3ms와
  모순 → 폐기). stage2 필러 HUD 크롬 1.23ms는 S1/S2 미커버(캐싱 후보, med-risk).

## 5. Codex 리뷰 체크리스트 (제안)

1. `e5e9316c6` 얕은 카피 안전성: `stage1_commando_firearm_fx_host.gd`가 sync_state로
   받은 draw_items 배열을 진짜 read-only로만 쓰는지(현재 확인됨, 재검).
2. `798754ba1` F1: 라운드 경계 변경 owner 키가 `sync_transient_owner_state` 커버리지에
   다 들어가는지(누락 시 한 라운드 stale 패널). `mythic_item_owner_syncer.sync_transient_owner_state`
   vs `sync_owner` 키 delta 감사.
3. ✅ [해결 `24de004fa`] stage1 viper `mythic_items` 3ms 회귀 — uncached
   `get_method_list()` per-tick 스캔(계측 커밋 `11f0a86bc` 도입), 캐시 헬퍼로 수정.
   §3 참조. (재측정으로 mythic_items 회복 확인은 권장.)
4. 트램펄린 묶음 커밋 스코프(언트랙드 8파일 동반) 확인.

## 6. 측정 재현

`godot/`에 `battle_perf_log.flag`(+선택 `battle_perf_detail.flag`,
`battle_perf_samples.flag`) 생성 후 플레이. 로그:
`%APPDATA%\Godot\app_userdata\pingfighter\logs\godot.log`. 분석은 일회용 distiller
(PowerShell Select-String로 `[BattlePerf-Samples]` 라벨 유병률/avg/max 집계).
진단 끝나면 `.flag` 정리.
