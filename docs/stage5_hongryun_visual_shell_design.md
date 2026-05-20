# Stage 5 홍련 시각 셸 디자인 spec

작성일: 2026-05-17
연계:
- [stage5_hongryun_godot_port_plan.md](stage5_hongryun_godot_port_plan.md) §3, §4.2
- [stage5_hongryun_asset_manifest.md](stage5_hongryun_asset_manifest.md)
- [stage5_hongryun_boss_skill_hud_design.md](stage5_hongryun_boss_skill_hud_design.md)
- [godot/scripts/stages/stage5/stage5_hongryun_state.gd](../godot/scripts/stages/stage5/stage5_hongryun_state.gd)

state.gd가 MVP 본체까지 land했고, fireball/inferno draw context와 배경 hook contract가 굳었다. 이 문서는 그 contract를 시각으로 살리는 4개 owner 모듈의 fork 기준이다.

## 0. 합의된 결정

1. **배경 contract owner = `stage5_hongryun_pillar_background.gd`.** state.gd가 `deps["stage_background"]`로 받는 객체가 곧 pillar_background이며, `trigger_spiral_burst(inferno_active)` / `set_inferno_mode(active)` / `add_fire_impact(x, y)` 3개 메서드를 반드시 구현한다.
2. **임시 stage1 라우팅은 시각 셸 land와 동시에 해제.** 현재 `stage_runtime_router`에서 Stage 5는 stage1 배경/필러를 임시로 타고 있다. 시각 셸 4개 모듈이 도착하면 같은 PR에서 router를 stage5_* owner로 교체한다. 부분 land 금지 (renderer 도착 후에도 router가 stage1을 가리키면 자산이 활성화되지 않음).
3. **fire_machine_event는 이 spec에서 다루지 않는다.** 별도 owner 모듈 + 별도 spec. 이번 시각 셸은 pillar/playfield/boss_actor 3개 모듈만.

## 1. state.gd가 요구하는 contract (변경 금지)

### 1.1 배경 메서드 (pillar_background.gd 구현)

```gdscript
# state.gd line 571~580 호출 패턴
func trigger_spiral_burst(inferno_active: bool) -> void
func set_inferno_mode(active: bool) -> void
func add_fire_impact(x: float, y: float) -> void
```

- `trigger_spiral_burst(inferno_active)`: 화염탄 발사 순간 호출. `inferno_active`가 true면 추가 강도(빈도/크기).
- `set_inferno_mode(active)`: 홍련폭염 시작/종료. **persistent state** — true면 배경 톤이 광폭화 모드로 유지되고, 다음 호출이 false로 들어올 때까지 해제 안 됨.
- `add_fire_impact(x, y)`: 화염탄/inferno 충돌 위치에 즉각적 임팩트 FX. **transient** — 한 프레임 트리거, 자체 lifetime으로 페이드.

### 1.2 actor draw context (playfield_renderer.gd / boss_actor_renderer.gd 소비)

state.gd `get_actor_draw_context()` (line 228~236) 반환 dict:

```gdscript
{
    "stage5_hongryun_fireballs": Array,           # [{pos: Vector2, vel: Vector2, radius: float, age: float}, ...]
    "stage5_hongryun_fireball_impacts": Array,    # [{pos: Vector2, reason: String, scale: float}, ...] — 한 프레임
    "stage5_hongryun_inferno_active": bool,
    "stage5_hongryun_inferno_phase": int,         # 0=idle, 1=charge, 2=trail
    "stage5_hongryun_inferno_trail": Array,       # [Vector2, ...] 최대 30개
    "stage5_hongryun_dragon_orb_count": float,    # 0.0~5.0
}
```

추가 boss AI context (보스 actor renderer가 swing/throw 모션 선택용):

```gdscript
"stage5_hongryun_boss_throwing": bool   # 보스 throwing windup 25프레임 동안 true
```

## 2. 모듈 분리 — 4개 owner

| 모듈 | 책임 | 라우터 role |
|---|---|---|
| `stage5_hongryun_pillar_background.gd` | 좌/우 필러, 광폭화 배경 톤, 배경 contract 3개, spiral burst FX, transient fire_impact FX | `stage_background` |
| `stage5_hongryun_playfield_renderer.gd` | 중앙 배경(3-layer cyber base), 화염탄 sprite, inferno trail 뱀 궤적, impact VFX dispatch | `playfield_renderer` |
| `stage5_hongryun_boss_actor_renderer.gd` | 홍련 보스 sheet (walk/attack/dash/turn), 상태별 sheet 선택, dragon_head_16f를 inferno phase 2 동안 보스 머리 위 오버레이 | `boss_actor_renderer` |
| `stage5_hongryun_pillar_scene_drawer.gd` | 필러 안쪽 chrome (lantern/vase/snake_pot/cyber_snake 배치). 라우터 `pillar_scene_drawer` role | `pillar_scene_drawer` |

배경과 pillar_scene_drawer 분리 이유: stage4도 같은 분리(`stage4_pillar_background` + `stage4_pillar_scene_drawer`)를 쓰며, 배경 layer는 자주 prewarm/캐시되고 scene_drawer는 필러 안의 인테리어 chrome을 그린다. 홍련은 항아리/등불/뱀이 chrome 영역이라 분리가 깔끔하다.

## 3. 자산 → 모듈 분배

37개 마이그레이션 자산을 4개 모듈에 분배. 자산 경로는 `godot/assets/sprites/hud/` 또는 `godot/assets/sprites/stage5/` 기준 (manifest와 동일).

### 3.1 `pillar_background.gd`가 owning

| 파일 | 용도 |
|---|---|
| `stage5_hongryun_layered_cyber_base_imagegen_v3.png` | 전체 배경 base layer (가장 깊은 cyber 적색 배경) |
| `stage5_hongryun_center_background_imagegen_v1.png` | 광폭화 모드 진입 시 swap-in 배경 (더 강한 적색 + dragon silhouette) |

`set_inferno_mode(true)` → 배경을 v3 base + `center_background` 오버레이로 lerp (0.4초 cross-fade).
`set_inferno_mode(false)` → v3 base만 (cross-fade out).

### 3.2 `pillar_scene_drawer.gd`가 owning

| 파일 | 용도 | 배치 |
|---|---|---|
| `stage5_hongryun_vase_lantern_sprites_imagegen_v2.png` | 등불 아틀라스 (4x4 또는 wide) | 좌/우 필러 안쪽 상단 2~3개 (stage4 `LANTERN_SPECS` 패턴) |
| `stage5_hongryun_snake_pot_imagegen_v1.png` | 뱀 항아리 메인 | 좌/우 필러 안쪽 중앙, 큰 사이즈 1개씩 |
| `stage5_hongryun_snake_pot_wallmount_v2.png` | 벽걸이 변형 | 필러 안쪽 상단/하단 보조 1개씩 |
| `stage5_hongryun_snake_pot_lotus_pulse_sheet_v1.png` | 항아리 연꽃 펄스 (16f 또는 4x4) | 광폭화 모드 진입 시에만 펄스 애니메이션 시작 |
| `stage5_hongryun_cyber_snake_sheet_imagegen_v2.png` | 사이버 뱀 (16-frame) | 광폭화 모드 진입 시에만 등장, 필러 안쪽에서 항아리를 따라 슬금슬금 |
| `stage5_hongryun_motion_sprites_imagegen_v2.png` | 일반 모션 ambient 아틀라스 | 필러 chrome 보조 (작은 파티클/연기 등) |

`*_source.png` suffix 파일은 **원본 백업**으로 마이그레이션됨 — runtime에서 사용 금지. `_imagegen_v?` 최신 버전 또는 `_v2` 명시 버전만 owner 모듈에 import.

### 3.3 `playfield_renderer.gd`가 owning

| 파일 | 용도 |
|---|---|
| `stage5_hongryun_motion_sprites_imagegen_v1.png` | 화염탄 sprite atlas (state.gd `stage5_hongryun_fireballs` 그릴 때 frame 선택) |
| `stage5_hongryun_layered_cyber_base_imagegen_v1.png` | inferno trail snake 궤적의 머리 / 꼬리 텍스처 (텍스처 조각으로 사용) |
| `stage5_hongryun_layered_cyber_base_imagegen_v2.png` | inferno trail 중간 노드 텍스처 |

화염탄 sprite는 4x4 그리드를 가정하고 `floor(age * 16) % 16`으로 frame 인덱스 계산. age는 state.gd가 dict에 박아 보냄.

inferno trail은 `stage5_hongryun_inferno_trail` 30개 Vector2를 선분으로 잇고, 각 노드 위에 적색 글로우 + age-based scale. 머리(=trail의 마지막 점)는 가장 크고 밝게.

impact VFX (`stage5_hongryun_fireball_impacts`)는 `reason` 키에 따라:
- `"player"`: 빨간 폭발 ring + 작은 spark
- `"floor"`: 작은 splash + 짧은 잔불
- `"inferno_player"`: 큰 폭발 + 검은 연기 (scale=1.7)

### 3.4 `boss_actor_renderer.gd`가 owning

| 파일 | 용도 |
|---|---|
| `stage5_hongryun_boss_sheet.png` | walk 시트 (8프레임). 보스 idle/walk 기본 |
| `stage5_hongryun_boss_attack.png` | attack 시트. `stage5_hongryun_boss_throwing == true` 동안 25프레임 |
| `stage5_hongryun_boss_dash.png` | dash 시트. `boss_dash_active` (공용 키, 보스 AI가 set) |
| `stage5_hongryun_boss_turn.png` | turn 시트 (선택). facing change 짧은 transition (200ms) |
| `stage5_hongryun_dragon_head_sheet_imagegen_v3_16f.png` | **inferno phase 2 동안만** 보스 머리 위 16-frame 용 머리 오버레이 |

state별 sheet 선택 로직 (stage4 `_draw_body_sheet` 패턴):

```gdscript
if boss_throwing_windup_active:
    sheet = attack_sheet
    frame = floor(throw_progress * ATTACK_FRAMES) clamped
elif boss_dash_active:
    sheet = dash_sheet
elif turn_transition_active:
    sheet = turn_sheet
else:
    sheet = walk_sheet  # 또는 boss_pos 이동량 == 0 이면 walk sheet의 idle frame
```

`throw_progress = 1.0 - boss_throwing_windup_timer / BOSS_THROW_WINDUP_FRAMES` (state.gd에서 0~25 카운트다운).

dragon_head_16f는 `inferno_active && inferno_phase == 2`일 때만 활성. 보스 actor 위 약 `-40px Y` 오프셋, 보스 X 따라가기, `floor(inferno_trail_elapsed_sec * 12) % 16`으로 frame loop.

## 4. Inferno 모드 시각 변화

`set_inferno_mode(true)` 호출 시 pillar_background가 즉시 다음을 시작:

| 요소 | 변화 |
|---|---|
| 중앙 배경 | v3 base + center_background_v1 오버레이로 0.4초 cross-fade (alpha 0→0.85) |
| 배경 색 modulate | 기본 `Color(1, 1, 1, 1)` → `Color(1.0, 0.55, 0.55, 1.0)` 0.3초 lerp |
| 필러 chrome | `cyber_snake_sheet_v2` 16f 등장 (필러당 1마리, 항아리 옆) |
| 필러 항아리 | `snake_pot_lotus_pulse_sheet_v1` 펄스 시작 (12fps) |
| Spiral burst | trigger_spiral_burst 호출 시 burst 강도 1.6x |
| Vignette | 화면 가장자리 0.5초 안에 적색 vignette alpha 0.3 |

`set_inferno_mode(false)` (inferno 종료 시) — 위 모든 변화를 0.7초 동안 역방향 lerp. **persistent state 누수 방지** — pillar_background.gd 측에 `var inferno_mode_active := false` 단일 플래그 + `reset()` 진입점에서 강제 false로 클리어.

## 5. 시각적 위계 정책

홍련 스테이지는 화면에 동시에 보이는 적색 요소가 많아 위계가 무너지기 쉽다. 다음 우선순위로 채도/밝기를 차등 적용:

| 위계 | 요소 | 채도 / 밝기 (HSV S, V) |
|---|---|---|
| 1 (가장 강함) | inferno trail 머리, inferno 모드 vignette | S 0.95, V 1.0 |
| 2 | 화염탄, dragon_head_16f, dragon orb 5칸 ready 펄스 | S 0.85, V 0.92 |
| 3 | 광폭화 모드 배경 톤, snake_pot lotus pulse | S 0.70, V 0.78 |
| 4 (배경) | base 배경, 필러 chrome 기본 상태 | S 0.55, V 0.62 |

새 요소 추가 시 이 표를 확인해 같은 위계 내에서만 변형하고, 위계 간 침범은 금지. 예: 화염탄(2)이 inferno trail 머리(1)보다 밝게 튀면 안 됨.

## 6. 좌/우 필러 비대칭 정책

stage1~4는 모두 좌/우 필러가 대칭이지만, 홍련은 항아리/뱀 chrome을 좌우 살짝 비대칭으로 둬서 "중국 화염 시장" 분위기를 강화한다 (원본 Stage5ChineseMarket 의도).

- **공통**: 등불 2개, 항아리 1개씩.
- **좌측 추가**: wallmount snake_pot 1개 (상단)
- **우측 추가**: 작은 motion_sprites 입자 더 많이 (lantern 사이 spark)
- **광폭화 모드**: 좌/우 cyber_snake 1마리씩 (양쪽 대칭 등장)

대칭/비대칭 결정을 pillar_scene_drawer.gd 안의 `LEFT_PILLAR_SPECS` / `RIGHT_PILLAR_SPECS` 두 const 배열로 분리해서 명시.

## 7. Codex fork 체크리스트

### 7.1 `stage5_hongryun_pillar_background.gd`

1. `stage4_pillar_background.gd`를 베이스로 fork (stage4 패턴이 외부 contract owner로서 가장 가까움).
2. 텍스처 const 4개 변경 (§3.1).
3. `Stage4MoonEvent` 참조 제거 (inferno mode는 자체 플래그로 처리).
4. 외부 contract 3개 구현:
   - `trigger_spiral_burst(inferno_active: bool)` — burst FX 1회 큐잉 (강도는 inferno_active로 분기).
   - `set_inferno_mode(active: bool)` — `inferno_mode_active` 플래그 set + cross-fade timer 시작.
   - `add_fire_impact(x: float, y: float)` — `wall_shake_accents` 패턴 그대로 transient list에 push, draw에서 일정 시간 후 자동 제거.
5. `reset()` 진입점에서 `inferno_mode_active = false`, transient list 모두 클리어 (state.gd `reset()`이 호출되면 같은 cleanup 보장).
6. `update(delta, context, deps)` — cross-fade timer / burst pool / impact list lifetime 진행.
7. `draw()` — base layer → inferno overlay (alpha) → spiral burst FX → vignette 순.

### 7.2 `stage5_hongryun_pillar_scene_drawer.gd`

1. 기존 stage4 pillar_scene_drawer를 참조 (필러 안쪽 chrome 패턴).
2. `LEFT_PILLAR_SPECS` / `RIGHT_PILLAR_SPECS` const 배열 정의 (§6).
3. 텍스처 const 6개 (§3.2).
4. `draw(canvas, view_size, game_offset, game_size, _field_width)` — 좌/우 필러 안쪽 element 그리기. `inferno_mode_active`는 deps의 pillar_background에서 가져오기.
5. cyber_snake / lotus_pulse 애니메이션 frame은 `Time.get_ticks_msec()` 기반 (state 의존 없음 — 순수 시각).

### 7.3 `stage5_hongryun_playfield_renderer.gd`

1. `stage4_playfield_renderer.gd` 베이스 fork.
2. 중앙 배경 layer 제거 (홍련은 pillar_background가 풀스크린 배경 owner — playfield는 중앙 element만).
3. actor_draw_context에서 3개 array 읽어 그리기:
   - fireballs → sprite atlas로 그리기 (frame = age 기반)
   - inferno_trail → 30개 점을 적색 글로우 폴리라인으로 연결
   - fireball_impacts → reason별 VFX dispatch (`player` / `floor` / `inferno_player`)
4. inferno_phase가 1(charge)일 때 ball 주변 강한 적색 헤일로 + jitter dust.
5. inferno_phase가 2(trail)일 때는 trail 자체가 ball을 따라가므로 별도 ball 강조 불필요.

### 7.4 `stage5_hongryun_boss_actor_renderer.gd`

1. `stage4_ponk_boss_actor_renderer.gd` 베이스 fork.
2. SHEET_PATH 4개 (walk/attack/dash/turn) + DRAGON_HEAD_PATH 1개 (16f) const.
3. state별 sheet 선택 로직 (§3.4).
4. `boss_throwing_windup_active`인 동안에는 attack sheet의 frame을 `throw_progress`로 진행.
5. dragon_head_16f는 inferno phase 2일 때만 위에 그리고, 보스 facing에 따라 좌우 flip.
6. fallback은 stage4처럼 단색 paddle. sprite sheet 도착 전이라도 동작.

### 7.5 라우터 / 카탈로그 등록

1. `stage_runtime_router.gd` STAGE_MODULES[5]에 4개 role 모두 매핑:
   ```gdscript
   5: {
       "actor_renderer": "stage5_hongryun_actor_renderer",  # 기존 임시 또는 새로 마련
       "boss_actor_renderer": "stage5_hongryun_boss_actor_renderer",
       "pillar_scene_drawer": "stage5_hongryun_pillar_scene_drawer",
       "stage_background": "stage5_hongryun_pillar_background",
       "playfield_renderer": "stage5_hongryun_playfield_renderer",
       "boss_skill_hud_renderer": "stage5_hongryun_boss_skill_hud_renderer",
   }
   ```
2. `gameplay_stage_module_catalog.gd` / `battle_resources.gd` / draw scene context / prewarm — stage4 등록 패턴 mirror.
3. 임시 stage1 라우팅 제거 확인.
4. 검증: `run_smoke_tests.ps1` + `run_headless_load_check.ps1` + `run_warning_scan.ps1`.

## 8. QA 시나리오 (시각 측면)

- Stage 5 진입: 좌/우 필러에 항아리/등불/뱀 chrome 정상 표시. 광폭화 표시 없음. 배경 적색 톤 약함.
- 화염탄 발사: 보스 attack sheet 25프레임 재생, spiral burst FX 한 번, 화염탄 sprite가 보스 → 플레이어로 이동.
- 화염탄 플레이어 hit: 적색 폭발 ring + dragon orb 1칸 차오름 (HUD).
- dragon orb 5칸 완충: 홍련폭염 카드 ready 펄스 (HUD spec).
- 보스 패들 충돌 → inferno phase 1 (charge 1.4초, 원본 1.0초에서 cinematic +0.4s): `set_inferno_mode(true)` 호출됨 → 배경 cross-fade 적색, 필러 cyber_snake 등장, lotus pulse 시작, vignette in.
- inferno phase 2 (trail): 보스 머리 위 dragon_head_16f 등장, 공이 trail을 그리며 뱀처럼 이동.
- inferno 종료 (hit 또는 safety timeout): `set_inferno_mode(false)` → 0.7초 lerp out, dragon_head_16f 사라짐.
- 라운드 종료: state.gd `reset_round()` → pillar_background `reset()` 호출 → transient 큐 + inferno mode 모두 클리어.
- 결과 화면 → 다음 게임 Stage 1 진입: 홍련 chrome 흔적 없음 (메모리의 `flame_trail_active` 누수 트랩 차단 확인).

## 9. fallback 정책

자산 PNG는 모두 마이그레이션 완료 상태이므로 별도 fallback 필요 없음. 단:

- 보스 sheet 4개가 동시에 누락된 경우에만 stage4처럼 단색 paddle fallback. 한 sheet만 누락 시 해당 state는 walk sheet로 대체.
- dragon_head_16f가 누락된 경우 inferno phase 2에서 보스 위에 단순 적색 헤일로만 표시.
- pillar_scene_drawer 텍스처 일부 누락 시: 누락된 element만 skip, 나머지는 정상 표시.

## 10. 후속 작업 (이 spec 이후)

이 시각 셸이 land된 후 자연스러운 다음:

1. **카드 일러스트 PNG 2개 생성** (화염탄/홍련폭염 카드) — `ui-hud-generation` 스킬. 시각 셸이 land되면 보스 actor 톤과 매칭해서 카드 일러스트 prompt 잡기 쉬워짐.
2. **`stage5_hongryun_fire_machine_event.gd` 모듈** — 화염기계/용숨결 이벤트. 별도 spec 필요. 데이터는 위 4개 owner와 같은 deps에 추가 등록.
3. **인게임 플레이테스트** — Stage 5 진입 → 화염탄 5회 hit → inferno 발동 → 클리어/패배 → 결과 화면 → 다음 게임 Stage 1 진입까지 1회 통과. 시각/오디오/cleanup 누수 모두 같이 확인.
4. **boss actor sheet 사이즈 비교** — 메모리의 "Cross-boss size standard: Stage 3 Menhera body class is STANDARD" 규칙에 따라 인게임에서 멘헤라와 홍련을 같은 화면에 띄워 비교(개발 메뉴) 후 사이즈 override 필요 여부 결정.
