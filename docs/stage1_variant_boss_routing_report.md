# Stage 1 변형 보스 라우팅 완료 보고서

작성일: 2026-08-21
기준 HEAD: `252d6810856016f9287786b79a4f3c7dd13d1bad`
격리 브랜치: `codex/stage1-variant-boss-routing-01a02287`
격리 작업트리: `C:\w\codex_stage1_route_01a02287`

## 결론

Stage 1 일반 캠페인의 의도된 정책은 **달지·각시탈·포도대장 균등 3-way 랜덤 선출**이다. 근거는
`docs/pododaejang_stage1_port_plan.md:14-24`의 사용자 확정 기록과, 포도대장 풀 포팅 뒤
3-way를 여는 Slice 7 계약(`:198-206`)이다.

미등장의 직접 원인은 `set_stage1_boss_variant()` 호출 부재가 아니었다.
`battle_scene_selection_startup_lifecycle.resolve_stage1_boss_variant()`는 이미 일반 진입에서
호출되고 있었지만, 실제 풀 상수는 2026-07-04 안전 잠금으로 `dalji` 하나뿐이었다. Tower는
`tower_ascent_boss_registry.gd:17-19`에 세 보스가 모두 등록되어 있고 `tower_map_seed` 기반
전용 RNG를 쓰므로 기존부터 세 변형이 모두 결정적으로 등장했다.

이번 작업은 일반 캠페인 풀을 `[dalji, gaksi, podo]`로 열고, 그 선행조건이던 포도대장 전투
2스킬·HUD·오디오/효과·리셋·이름·정산 경로를 완성했다. 달지와 각시탈 기존 경로는 그대로
유지했다.

## 판정 근거

- `docs/pododaejang_stage1_port_plan.md:14-15`: 원본 Stage 1은 세 보스 중 랜덤이며,
  포도대장 풀 포팅 뒤 3-way를 켠다는 사용자 결정.
- 같은 문서 `:37-52`: 포도대장은 `포졸소환`과 `포승줄` 두 스킬 구조.
- 같은 문서 `:75-133`: 포졸 2체/5초/공 반사, 포승줄 45f→180f→28f와 연막 회피,
  이동속도 0.5배, 대시 해제 계약.
- `battle_scene_selection_startup_lifecycle.gd:17,124-159`: 일반 캠페인은 이제 세 항목을
  전용 `RandomNumberGenerator`로 한 번만 뽑는다.
- `tower_ascent_boss_registry.gd:17-19,84`: Tower의 세 항목 및 seed 기반 슬롯 결정은 변경하지 않았다.

`docs/pododaejang_stage1_port_plan.md:206-209`에는 한때 2-way였다는 기록도 있지만, 작업 시작
HEAD의 실행 상수는 실제로 `dalji` 단일이었다. 실행 코드와 2026-06-27의 최종 3-way 개방 조건을
우선해 판정했다.

## 구현 결과

### 포도대장 전투

- `stage1_pododaejang_patrol_guards_skill_state.gd`
  - 16초 instant 슬롯, 라운드당 1회.
  - 포졸 2체를 X=300/460, 보스 하단+30에 생성한다.
  - 300f 지속, 마지막 30f 페이드, 110~180px/s 순찰, 160~600 목표를 전용 RNG로 고른다.
  - `18 + ball_radius` 충돌에서 공 속도 크기를 보존하고 방향만 무작위화한다.
  - 충돌 오디오와 두 종류 impact 효과를 실제 ball-motion 소유자에서 호출한다.
- `stage1_pododaejang_arrest_rope_skill_state.gd`
  - 20초 on-boss-hit 슬롯.
  - `throwing 45f → bound 180f → releasing 28f`, 빗나가면 `miss 30f`.
  - 발사 시점 플레이어 위치를 스냅샷하고 X 오차가 플레이어 폭의 0.6 미만일 때 명중한다.
  - 연막이면 먼저 빗나가며, 명중해도 입력/스턴 잠금 없이 이동속도만 0.5배로 낮춘다.
  - 대시 시 즉시 releasing으로 전환한다. 보스 이동 freeze는 넣지 않았다.
- 쿨다운, effects update, boss-hit, ball-motion, player-control multiplier, draw context,
  라운드/매치 reset, debug reset, module catalog, scoped deps와 prewarm을 모두 생산 경로에 연결했다.

### HUD·표시·정산

- 포도대장 전용 카드 2장을 built-in image generation으로 만든 뒤 런타임 규격인 408x120으로
  축소했다. 이미지 생성은 조선 포도청의 갈색/남색 팔레트, 포졸 2체, 포승줄 올가미를 카드의
  주요 판독 요소로 정했다. 텍스트와 게이지는 PNG에 굽지 않고 기존 HUD가 그린다.
- 카드 SHA-256:
  - `포졸소환`: `0babf1b6475edb8c176f353aaa86557cea1444ca7bb4b5bac20288a4d4eb04f3`
  - `포승줄`: `bf36446e31e12d9f13d85550de663cc22d4fb17e527b5c626c59d183fc39a5ce`
- 두 PNG는 source decode뿐 아니라 `.import`를 통한 실제 `Texture2D` 408x120 로드를 스모크로
  봉인했다.
- 상단 스코어보드는 Stage 1에서 `달지` / `각시탈` / `포도대장`을 표시하며, 다국어 카탈로그를
  통과한다. Stage 2 이상 기본 `BOSS` 표시는 보존했다.
- 패배 정산은 `stage_boss_variant`가 아니라 별도 키 `stage1_boss_variant`로 Stage 1 이름을
  계산한다. Stage 1에서 바로 패배할 때뿐 아니라 이후 스테이지 정산의 `cleared_bosses`에도
  실제 Stage 1 보스 이름을 보존한다.

### RNG와 키 경계

- 일반 캠페인 선출은 `stage1_boss_rng` 전용 인스턴스다. 게임플레이 authoritative RNG를
  소비하지 않는다.
- 일반 진입에서 한 번만 뽑고 owner의 `stage1_boss_variant`에 고정하므로 라운드마다 바뀌지 않는다.
- 테스트는 seed `7321`로 48회 추첨해 세 값이 모두 나오며, explicit 선택은 RNG를 우회함을 확인했다.
- Tower는 기존 `tower_map_seed` 결정성을 그대로 유지한다.
- `stage1_boss_variant`와 `stage_boss_variant`는 합치지 않았다. 스코어보드/정산 스모크에는
  Stage 1 키가 `podo`이고 일반 stage 키가 `cheongringwi`인 반증 입력을 넣었다.

## 보스별 생산 경로 확인

| 보스 | 일반 선출 | 전투 스킬·효과 | HUD/오디오 | 상단 이름 | 패배/결과 |
|---|---|---|---|---|---|
| 달지 | seed 경로에서 확인 | 기존 팽이/상모 및 freeze 스모크 통과 | 기존 카드 유지 | `달지` Vulkan 확인 | 기존 result sprite 통과, 정산명 확인 |
| 각시탈 | seed 경로에서 확인 | 부채던지기·부채바람 스모크 통과 | fan/whipcrack 실제 catalog와 3-layer pool 확인 | `각시탈` Vulkan 확인 | victory/defeat sprite 및 정산명 확인 |
| 포도대장 | seed 경로에서 확인 | 포졸 충돌 결과와 포승줄 감속·회피·대시 해제 확인 | 전용 카드 2장, summon/bind/impact 호출 확인 | `포도대장` Vulkan 확인 | victory/defeat sprite 및 현재/클리어 정산명 확인 |

각시탈과 패배 정산의 기존 스모크에는 리팩터 전 문자열을 찾는 낡은 검사 두 곳이 있었다.
실제 소유자인 `stage1_boss_skill_audio.gd`와 `battle_terminal_screen_input_router.gd`의 생산 계약을
검사하도록 갱신했고, 각각 단독 GREEN을 확인했다. 런타임 동작 변경은 아니다.

## 검증 증거

### 스모크

- 핵심 Stage 1 묶음: `PASS=13 FAIL=0 TOTAL=13`
  - 신규 생산경로 스모크, 일반 선출, scoped deps, runtime deps, boot/HUD prewarm, debug reset,
    각시탈 두 스킬·스프라이트, 포도대장 스프라이트, 달지 freeze/result 포함.
  - 종단: `All Godot smoke tests passed.`
- 최종 역방향 묶음: `PASS=3 FAIL=0 TOTAL=3`
  - `stage1_variant_boss_routing_smoke`
  - `defeat_settlement_screen_smoke`
  - `tower_boss_routing_smoke`
  - 종단: `All Godot smoke tests passed.`
- 신규 스모크를 focused CI와 pre-push 목록에 동시에 추가했다(195→196). 하네스 검증:
  `agent harness verification: ok`.

### 경고·로드·diff

- touched GDScript 38개 경고 스캔: `Godot warning scan passed with no GDScript warnings.`
- 마지막 이름/정산 변경 4개 focused 재스캔도 0 warning.
- headless load: `[ApplicationQuitCoordinator] graceful headless shutdown complete` 및
  `Godot headless load check passed.`
- `git diff --check`: 통과.
- import 검증: exit 0, `SCRIPT ERROR|ERROR:` 0건. 기존 사운드 UID 중복 warning 1건은 이 변경과
  무관한 baseline이다.

### Vulkan 1280x750

실제 `BattleResources`, `Stage1ActorRenderer`, 각 변형의 스킬 state/HUD renderer,
`ScoreboardOverlayHeaderRenderer`를 사용한 windowed Vulkan Forward Mobile 캡처다.

| 보스 | 판독 결과 | SHA-256 |
|---|---|---|
| 달지 | 이름 `달지`, 달지 전투/카드, 기존 화면 유지 | `8be2e1859ca9c048357bbadf1e974a296cb684c1a1267440cafa93f37829f3e4` |
| 각시탈 | 이름 `각시탈`, 각시탈 바디·부채 및 카드 | `75570ce065fc38540a7d9603d5f4e41901f78a30ca0805573525c4896a07b3fe` |
| 포도대장 | 이름 `포도대장`, 포도대장 바디·포졸 2체·포승줄 및 카드 2장 | `97c70770d76a534a88fe0bc797591fa55f9c4523d0be1e17840b0d30a2f434cc` |

캡처 위치:
`godot/.godot/codex_captures/stage1_variant_boss_routing/stage1_{dalji,gaksi,podo}_combat.png`

## 커밋과 랜딩 경계

- `5f22bc9be` `feat(stage1): complete Pododaejang combat runtime`
- `53c1b8900` `fix(stage1): route all campaign boss variants`
- 이 보고서는 별도 문서 커밋으로 둔다.

사용자 메인 트리는 기준 HEAD와 같지만 아래 파일에 미커밋 스코어보드 재설계 WIP가 있다.

- `godot/scripts/hud/scoreboard_overlay_header_renderer.gd`
- `godot/scripts/hud/scoreboard_overlay_renderer.gd`

그 WIP 자체가 이미 세 Stage 1 이름 resolver를 포함한다. 따라서 `53c1b8900`을 랜딩할 때 두 파일은
자동 덮어쓰기하지 말고, 사용자 WIP의 동등한 resolver를 유지한 채 draw-context 전달 계약만
확인해야 한다. 이번 작업에서는 메인 트리를 수정·stage·stash·통합하지 않았다.

## 상태

- fixed: 일반 캠페인 3-way 선출, 포도대장 완전 전투/HUD/효과, 세 이름과 정산.
- preserved: Tower seed 결정성, 달지/각시탈 기존 전투, 두 variant 키 분리.
- blocked: **0건**.
- unverified: 사용자 메인 트리의 실제 새 플레이 세션. 요청대로 사용자 본 트리 확인은 하지 않았다.
- integration/push: 수행하지 않음. 격리 브랜치에서 명시적 랜딩 지시를 기다린다.
