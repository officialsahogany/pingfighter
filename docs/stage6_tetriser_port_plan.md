# Stage 6 테트리서 포팅 기획 (Godot)

원본 PingFighter **Python Stage 7 (테트리서)** 를 Godot **Stage 6** 정식 슬롯으로
"그대로 포팅"하기 위한 기획서. 모든 수치는 실제 코드에서 직접 검증했으며
`file:line` 으로 근거를 남긴다. 본 문서는 설계/체크리스트이며, 런타임 통합
세부는 `AGENTS.md` / `docs/godot_port_architecture.md` 가 최종 권한을 가진다.

작성일: 2026-06-03

---

## 0. 스테이지 번호 결정 (Godot 6 = Python 7)

사용자 결정: **Godot 표시/코드 = Stage 6**, 원본 참조 = **Python Stage 7**.
이는 기존 `5=홍련 / Python 6=네메시스 제외` 컨벤션과 동일한 "Godot 슬롯 ≠ Python
슬롯" 패턴이다.

| 구분 | Godot (신규) | Python (참조) |
|---|---|---|
| current_stage | `6` | `7` |
| 코드/자산 prefix | `stage6_tetriser_*` | `stage7_*`, `STAGE7_*` |
| 보스명 | 테트리서 | 테트리서 |
| 배경 | (신규) | `AnimatedBackgroundStage7` / `animated_background_stage7.py` |

원칙:
- Godot 자산은 `stage6_tetriser_*` 로 rename 복사. Python `stage7_*` 파일명을 살아있는
  Godot 자산명으로 쓰지 않는다(모듈 헤더/매니페스트에 원본 경로만 주석으로 남김).
- 기존 디버그 피커의 `{"id": 7, "name": "스테이지 7", "desc": "테트리서"}`
  ([stage_debug_picker.gd:11](../godot/scripts/core/stage_debug_picker.gd#L11))
  엔트리를 **id 6** 으로 재라벨한다(현재 5→7로 6번이 비어 있음).
- 8~12 placeholder(아카무 리고 / 미노타우로스 / 최종 관문 / 4천왕 / 진엔딩)는 모두
  미구현 슬롯이므로 이번 작업 범위 밖. 로드맵 재번호는 별도 결정 → **§13 결정 필요 항목**.

> **클린 포팅 소스 우선:** `game_logic/stage7_tetriser.py` (119줄)는 순수 불변식
> 레이어(게이지 충전 조건, 라운드 리셋 정책, 반사축 선택, 벽 스펙)다. Godot
> `stage6_tetriser_state.gd` 의 1차 포팅 기준으로 이 모듈을 그대로 옮긴다.

---

## 1. 보스 정체성

- 보스명: **테트리서** / 궁극기 형태 **초인테트리서** (`STAGE7_SUPER_NAME` [pingfighter.py:37311](../pingfighter.py#L37311)).
- 컬러: 밝은 청색 계열, AI 스탯(accel/decel/max_speed/instant_stop)은
  `config/stage_configs.py` 의 stage7 엔트리 기준 — **포팅 시 해당 파일에서 정확값 확정** 후
  Godot boss catalog/AI 컨텍스트에 기록.
- 보스 본체는 측면 이동 시 기울기 연출(`stage7_lean_value` / `stage7_prev_x`
  [pingfighter.py:37287-37288](../pingfighter.py#L37287-L37288)).

---

## 2. 핵심 전투 시스템 (코드 검증 수치)

### 2.1 보스 게이지

`update_stage7_gauge_charge()` [pingfighter.py:115453-115510](../pingfighter.py#L115453-L115510)

| 항목 | 값 | 근거 |
|---|---|---|
| 최대치 | **500** | [115492-115493](../pingfighter.py#L115492-L115493) |
| 충전율 | `elapsed_ms * 0.025` = **초당 25** | [115497](../pingfighter.py#L115497) |
| UI 정지(TAB/ESC) 중 | 충전 정지 | `_is_stage7_ui_paused()` [115464](../pingfighter.py#L115464) |
| 스탑워치(시간정지) 중 | 충전 정지 | `should_charge_gauge()` [stage7_tetriser.py:40-41](../game_logic/stage7_tetriser.py#L40-L41) |
| 초인 발동 중(비광폭) | 충전 정지, 드레인만 | [115469-115474](../pingfighter.py#L115469-L115474) |
| 광폭화(enraged) 중 | 초인 중에도 충전 계속 | [115471](../pingfighter.py#L115471) |
| 라운드 간 | **persist** | `stage7_persistent_boss_gauge` [115447-115448](../pingfighter.py#L115447-L115448) |

### 2.2 낙하 테트로미노 (낙하 ㅗ 블록)

| 항목 | 값 | 근거 |
|---|---|---|
| 발동 간격 | **5~10초** 랜덤 | `STAGE7_TETRO_MIN/MAX_INTERVAL_MS = 5000/10000` [37300-37301](../pingfighter.py#L37300-L37301) |
| 게이지 소모 | **30** | `STAGE7_TETRO_GAUGE_COST` [37302](../pingfighter.py#L37302) |
| 모양 | T / L / Z / I / O (랜덤 회전 0/90/180/270) | — |
| 셀 크기 | 20px (초인 시 셀 1.7× = 34px) | `STAGE7_TETRO_SUPER_SCALE = 1.7` [37314](../pingfighter.py#L37314) |
| 조립 애니메이션 | 1000ms (4셀, 250ms 간격 등장 + 각 200ms 이동) | — |
| 낙하 속도 | ~110ms / step | — |
| 낙하 중 드리프트 | ~40% 확률 ±1~2셀 수평 이동 | — |
| 낙하 중 회전 | ~35% 확률 1~2회 | — |
| 연속 추가 발사 | 최대 6회 예약(`stage7_tetro_followup_remaining`) | [37305](../pingfighter.py#L37305) |

### 2.3 가드 블록

| 항목 | 값 | 근거 |
|---|---|---|
| 발동 간격 | **7~15초** 랜덤 | `STAGE7_GUARD_MIN/MAX_INTERVAL_MS = 7000/15000` [37294-37295](../pingfighter.py#L37294-L37295) |
| 게이지 소모 | 1개 50 / 2개 100 | — |
| 셀 | 20px, **4×1 가로 바** | `STAGE7_GUARD_CELL_SIZE = 20`, `_create_stage7_guard_block` 4셀 [115513](../pingfighter.py#L115513), [115536](../pingfighter.py#L115536) |
| 최대 개수 | **4개** 동시 | — |
| 조립 | 1000ms (홀로그램 → 이동 320ms) | `STAGE7_GUARD_ASSEMBLY_TOTAL_MS = 1000` [115521](../pingfighter.py#L115521) |
| 배치 | 보스 위에서 좌우 측면으로 슬라이드 | `STAGE7_GUARD_SPAWN_OFFSET_X = 90` [115515](../pingfighter.py#L115515) |

### 2.4 테트로 벽 (대량 소환)

`get_tetro_wall_spawn_spec_legacy()` [stage7_tetriser.py:106-119](../game_logic/stage7_tetriser.py#L106-L119)

| 항목 | 값 | 근거 |
|---|---|---|
| 발동 간격 | **30초** | `interval_sec: 30.0` / `STAGE7_TETRO_WALL_INTERVAL_MS = 30000` [37356](../pingfighter.py#L37356) |
| 게이지 소모 | **50** | `skill_cost: 50` [37357](../pingfighter.py#L37357) |
| 측면당 조각 | **10개** (좌+우 벽) | `pieces_per_side: 10` [stage7_tetriser.py:116](../game_logic/stage7_tetriser.py#L116) |
| 타일 | 20px, **cols=4** (grid_w = 80px) | `tile: 20, cols: 4` [stage7_tetriser.py:114-115](../game_logic/stage7_tetriser.py#L114-L115) |
| 좌벽 origin_x | **0** | `_spawn_tetro_wall_for_side(..., 0, ...)` |
| 우벽 origin_x | **WIDTH - grid_w** (= 680) | `_spawn_tetro_wall_for_side(..., WIDTH - grid_w, ...)` [pingfighter.py:116137 부근](../pingfighter.py#L116137) |

> ⚠ **좌표 — "그대로 포팅" 기준 먼저 고정:** 원본은 좌벽을 게임 `x=0`, 우벽을 `x=WIDTH-grid_w`(=680)에
> 세운다(`cols=4`, grid_w=80px). 이는 Python `PILLAR_UI_WIDTH=80`에 맞춰 튜닝된 값
> ([stage7_tetriser.py:110](../game_logic/stage7_tetriser.py#L110)). **그대로 포팅이면 Godot에서도
> 벽을 게임 x=0..80 / 680..760 에 세우는 것이 원본 충실 기준이다.**
>
> 단 주의: Godot 플레이필드는 풀 760px이고 x=0..80 / 680..760은 **레터박스가 아니라 실제 경기장
> 좌우 끝**이다(메모리: 플레이필드=풀 캔버스). 즉 원본 그대로 포팅해도 좌표는 유효하다. 만약 폭/위치를
> 바꾸려면 그것은 좌표 수정이 아니라 **명시적 밸런스 변경**으로 기록해야 한다(임의 "재결정" 금지).
> 참고: 모듈식 수렴 스펙 `get_tetro_wall_spawn_spec()`는 tile=24/cols=5지만 런타임은
> `_legacy()`(tile=20/cols=4)를 쓴다 ([stage7_tetriser.py:97-103](../game_logic/stage7_tetriser.py#L97-L103)).

### 2.5 블록 충돌 / 파괴

- **반사축 선택:** 직전 프레임 위치 기준 — 좌우 진입이면 수평('h'), 상하 진입이면
  수직('v'), 애매하면 겹침량 비교. `choose_reflection_axis()`
  [stage7_tetriser.py:56-78](../game_logic/stage7_tetriser.py#L56-L78). Godot 포팅 시 이
  순수 함수를 그대로 옮긴다.
- **서브 직후 관통:** 보스 서브 후 플레이어가 아직 반격하지 않은 상태
  (`stage7_ball_penetrates_tetromino`)에서는 테트로/벽을 공이 관통한다 [pingfighter.py:170594](../pingfighter.py#L170594).

#### 파괴 매트릭스 (🔴 일반 공 vs 나머지를 반드시 분리 — 코덱스 리뷰 교정)

| 충돌 원인 | 일반 테트로 | **초인(super) 테트로** | 근거 |
|---|---|---|---|
| **일반 공 반사** (`by_ball`) | 파괴(증발) | **파괴 안 됨 — 공만 튕기고 `SOUND_BIGTETROMINO` 재생, 계속 낙하** | [pingfighter.py:170580-170585](../pingfighter.py#L170580-L170585) |
| **대시** (`by_dash`) | 파괴 | 파괴 (가드 없음) | [54283](../pingfighter.py#L54283), [55465](../pingfighter.py#L55465), [88179](../pingfighter.py#L88179) |
| **무기/발사체** (해머쇼크 등, `by_dash`) | 파괴 | 파괴 (가드 없음) | [54283](../pingfighter.py#L54283) |
| **연막 폭발** (`by_smoke`) | 파괴 | 파괴 | `destroy_stage7_tetrominoes_in_smoke` [103587](../pingfighter.py#L103587) |
| **중앙 큐브 폭발** (`by_smoke`) | 파괴 | 파괴 | [116446](../pingfighter.py#L116446) |
| **초인 광선** (`by_smoke`) | 파괴 | 파괴 | [116754](../pingfighter.py#L116754) |
| **파워스매시 포물선** (벽) | 셀 즉시 제거(관통) | 동일 | [170599-170611](../pingfighter.py#L170599-L170611) |

> **핵심:** "초인 테트로 면역"은 **오직 일반 공 반사 경로 한정**이다. 대시·무기·연막·큐브폭발·레이저는
> super 가드 없이 전부 파괴한다(`by_dash`/`by_smoke` 경로). Godot에서 super 충돌 분기를
> normal-ball 경로에만 넣고, 나머지 파괴 경로에는 넣지 않도록 주의. 회귀 스모크 권장:
> "super 테트로 + 일반 공 → 파괴 안 됨 / 사운드만", "super 테트로 + 대시 → 파괴".

- **파편 VFX + 사운드:** `tetrisbreak.wav`(일반 파괴), super 공 충돌 시 `bigtetromino.wav`(튕김).

### 2.6 초인테트리서 (궁극기)

`update_stage7_super_state()` [pingfighter.py:118329-118448](../pingfighter.py#L118329-L118448)

| 항목 | 값 | 근거 |
|---|---|---|
| 발동 조건 | `boss_special_gauge >= 500` | [118391](../pingfighter.py#L118391) |
| 지속(일반) | 발동 후 **초당 25 드레인 → 0이면 종료** (≈20초) | [118419-118426](../pingfighter.py#L118419-L118426) |
| 보스 **본체** 스케일(일반) | **2.0×** | [118393](../pingfighter.py#L118393) |
| 보스 **본체** 스케일(광폭) | **1.4×** | [118362](../pingfighter.py#L118362) |
| 테트로 **셀** 스케일 | 1.7× (= 34px) | `STAGE7_TETRO_SUPER_SCALE` [37314](../pingfighter.py#L37314) |
| 폭발 넉백 | 12.0 (초인 시 ×2) | `STAGE7_TETRO_EXPLOSION_KNOCKBACK = 12.0` [37312](../pingfighter.py#L37312) |
| 스턴 | 일반 0.5s → 초인 0.9s | [37313-37315](../pingfighter.py#L37313-L37315) |
| 발동 연출 | 0.6초 포효 포즈(제자리 고정) | `stage7_super_intro_until_ms` [37330](../pingfighter.py#L37330) |
| 충전 정책 | 비광폭: 충전 정지 / 광폭: 충전 계속·드레인 없음 | [115469-115474](../pingfighter.py#L115469-L115474) |

> 🔴 **표기 vs 실동작 불일치 (그대로 포팅 시 코드 동작 우선):**
> `STAGE7_SUPER_DURATION_MS = 15000` ([37310](../pingfighter.py#L37310)) 상수는 **정의만
> 되어 있고 실제 드레인 로직에서 사용되지 않는다(사문화)**. 실제 지속은 게이지 500을
> 초당 25로 드레인 = **약 20초**다. "15초"는 표기일 뿐이므로 Godot에서는 게이지 드레인
> 모델을 진실로 삼고, HUD/문구도 드레인 기반으로 맞춘다.
>
> 🔴 **스케일 혼동 주의:** 보스 **본체** 2.0×(광폭 1.4×) ≠ 테트로 **셀** 1.7×. 별개 값이다.

### 2.7 초인 광선 (폭발 큐브 파괴용)

`STAGE7_TETRO_LASER_*` [pingfighter.py:37337-37339](../pingfighter.py#L37337-L37339)

| 항목 | 값 | 근거 |
|---|---|---|
| 충전 | 800ms | `STAGE7_TETRO_LASER_CHARGE_MS = 800` [37337](../pingfighter.py#L37337) |
| **광선 빔** 지속 | 1200ms | `STAGE7_TETRO_LASER_DURATION_MS = 1200` [37338](../pingfighter.py#L37338) |
| 쿨다운 | 3000ms (광폭화 모드에서만) | [37339](../pingfighter.py#L37339) |

광선 발사 시 두 가지가 동시에 일어난다(아래 §2.8 참고): (a) 3D 배경 큐브
`animated_bg_stage7.trigger_laser_melt()` 호출, (b) 모든 테트로미노 즉시 `by_smoke=True`로 제거
[pingfighter.py:116746-116754](../pingfighter.py#L116746-L116754). **광선 빔 지속(1200ms)과 큐브 melt는 별개 타이머다.**

### 2.8 큐브 시스템 — 🔴 두 개의 분리된 큐브 (코덱스 리뷰 교정)

원본에는 **이름이 같지만 별개인 큐브가 둘** 있다. 포팅 시 논리 제거와 비주얼 melt/hide/rebuild를
별도 타이머로 옮겨야 어긋나지 않는다.

**(A) 2D 논리 큐브** — `stage7_center_cube_state` (pingfighter가 직접 그림)
[pingfighter.py:116306-116480](../pingfighter.py#L116306-L116480)

- 3×3 색맞추기(루빅풍 6색), 화면 중앙 원형 서클(반지름 90) 내부.
  `STAGE7_CUBE_RADIUS = 90`, `STAGE7_CUBE_GRID_SIZE = 3` [116317-116318](../pingfighter.py#L116317-L116318).
- 공이 원 내부 **진입 시마다** 무작위 회전/섞기. 자발 정답 유도 `passes_to_solve = random 10~14` [116359](../pingfighter.py#L116359).
- 9칸 색 일치 → `STAGE7_CUBE_SOLVE_DELAY_MS = 1000` 후 폭발 → 모든 테트로미노 `by_smoke=True` 증발
  + grenade-style explosion(`source="center_cube"`) + 별 스폰 [116430-116448](../pingfighter.py#L116430-L116448).
- 폭발 후 **재조립** 모드: 테트로가 공/대쉬로 사라질 때(`reason in ("player","dash")`)마다 +1,
  **5개 도달 시 새 큐브 재활성** `_stage7_init_center_cube()` [116457-116470](../pingfighter.py#L116457-L116470).
- 광선 경로(`by_laser=True`): 폭발 대신 **2D melt 플래그** + 테트로 즉시 제거.
  자체 melt 표시용 `STAGE7_CUBE_MELT_DURATION_MS = 1000` [116321](../pingfighter.py#L116321), [116414-116428](../pingfighter.py#L116414-L116428).

**(B) 3D 배경 큐브** — `AnimatedBackgroundStage7` (`backgrounds/animated_background_stage7.py`)

- 배경 모듈이 그리는 회전 3D 큐브. 광선이 실제로 호출하는 대상은 **이쪽**:
  `animated_bg_stage7.is_cube_active()` → `trigger_laser_melt()` [pingfighter.py:116746-116748](../pingfighter.py#L116746-L116748).
- **레이저 melt 총시간 = 1200ms** `_laser_melt_total_ms = 1200`, **재조립 연출 = 1400ms**
  `_rebuild_total_ms = 1400` [animated_background_stage7.py:143-146](../backgrounds/animated_background_stage7.py#L143-L146).
- melt 진행도 API: `is_melting()`, `get_melt_progress()` (녹을수록 회전 가속·최대 60% 축소)
  [animated_background_stage7.py:224-262](../backgrounds/animated_background_stage7.py#L224-L262).

**포팅 분리 원칙:** ① 테트로미노 **논리 제거**(즉시, `by_smoke`)와 ② **비주얼 melt/hide/rebuild**
(2D 큐브 1000ms / 3D 배경 큐브 1200ms melt + 1400ms rebuild / 광선 빔 1200ms)를 각각 다른 타이머로
구현한다. Godot에서 배경 큐브를 별도 렌더 모듈로 둘지, 논리 큐브에 흡수할지는 §3 설계에서 결정하되
타이밍 상수는 위 값을 그대로 유지한다.

### 2.9 광폭화(enraged_boss_active) 분기 — 별도 명시

원본은 `enraged_boss_active and current_stage == 7` 일 때 다른 동작을 함
[pingfighter.py:115461](../pingfighter.py#L115461), [118359-118366](../pingfighter.py#L118359-L118366):
- **항상 초인테트리서** 상태(즉시 발동), 드레인 없음.
- 게이지는 0에서 천천히 다시 충전(초인 중에도 충전 계속).
- 본체 스케일 1.4×, 광선 쿨다운(3000ms) 사용.
- 테트로 간격 단축(`PINGFIGHTER_TETRO_TEST` 디버그 외에는 광폭화 별도 단축 여부 확인 필요).

Godot 광폭화 트리거가 무엇과 연결되는지(난이도/리그/디버그)는 포팅 시 매핑 확정.

---

## 3. Godot 모듈 설계 (Stage 5 홍련 패턴 미러)

신규 디렉토리: `godot/scripts/stages/stage6/`

| 파일 | 역할 |
|---|---|
| `stage6_tetriser_state.gd` | **단일 소유자.** 게이지, 낙하 테트로, 가드, 벽, 초인, 광선, 중앙 큐브, 충돌/파괴 API, `get_boss_ai_context()`, `reset()`. `game_logic/stage7_tetriser.py` 불변식 이식. |
| `stage6_tetriser_playfield_renderer.gd` | 블록/벽/파편/EMP/광선/중앙 큐브 전투 VFX. |
| `stage6_tetriser_boss_actor_renderer.gd` | 테트리서 보스 스프라이트, 이동 기울기, 초인 스케일/포효 포즈. |
| `stage6_tetriser_actor_renderer.gd` | 플레이어/공통 액터 렌더(스테이지 톤). |
| `stage6_tetriser_pillar_background.gd` | 정적 imagegen 분위기 배경, 중앙 플레이필드 음영/경계. |
| `stage6_tetriser_pillar_scene_drawer.gd` | 정적 배경 + 공용 필러 HUD + 보스 스킬 카드 HUD 호출. |
| `stage6_tetriser_boss_skill_hud_renderer.gd` | 보스 스킬 카드 HUD (게이지 + 낙하/가드/벽/초인 상태). |

규칙:
- 크로스라운드/게임엔드 상태 정리는 **단일 `reset()` 한 곳**에서 — 라운드엔드 / result(게임엔드) /
  스테이지 이탈 3경로에서 같은 메서드 호출(홍련 정리 패턴, `CLAUDE.md` 보스 이벤트 누수 규칙).
- 게이지는 라운드 간 persist이므로 `reset()`이 "라운드 리셋"과 "스테이지 이탈"을 구분해야
  한다(`should_reset_transient_on_round_reset` [stage7_tetriser.py:45-53](../game_logic/stage7_tetriser.py#L45-L53)).

---

## 4. 통합 체크리스트 (파일별)

| # | 파일 | 작업 |
|---|---|---|
| 1 | `stage_runtime_router.gd` | stage 6 role 매핑 추가(actor/boss_actor/playfield/pillar_background/pillar_scene_drawer/boss_skill_hud) |
| 2 | `gameplay_stage_module_catalog.gd` | 위 7개 모듈 path/label 등록 |
| 3 | `battle_update_stage_runtime_deps_builder.gd` | `_append_stage6_deps()` 추가 + match case 6 + include_all_stages |
| 4 | `battle_update_boss_ai_context_builder.gd` | `current_stage == 6` → `stage6_tetriser_state.get_boss_ai_context()` merge |
| 5 | `stage_debug_picker.gd` | STAGE_OPTIONS 7→6 재라벨([:11](../godot/scripts/core/stage_debug_picker.gd#L11)); STAGE_RESET_MODULE_KEYS에 stage6 모듈 추가([:24](../godot/scripts/core/stage_debug_picker.gd#L24)); implemented 게이트 `<= 5` → `<= 6`; prewarm case 6 |
| 6 | `battle_scene_match_event_driver.gd` | `DEMO_STAGE_SEQUENCE_END := 5` → `6` ([:11](../godot/scripts/core/battle_scene_match_event_driver.gd#L11)) |
| 7 | `game_audio.gd` | stage6 BGM 경로/게인 + `play_stage_bgm`/`prime_stage_bgm` case 6 |
| 8 | `battle_loading_screen_renderer.gd` | stage6 로딩 화면 자산 경로/텍스처(필요 시) |
| 9 | `battle_boot_resource_prewarm_controller.gd` | stage6 모듈/자산 prewarm (lazy-init 핫패스 트랩 회피) |
| 10 | `battle_draw_scene_context.gd` | `_append_stage_scene_deps()`에 stage 6 분기 — 테트로/벽/큐브/광선 draw deps 추가 ([:33,:42](../godot/scripts/core/battle_draw_scene_context.gd#L33)) |
| 11 | `battle_draw_actor_context.gd` | `if current_stage == 6:` 블록 추가 — `stage6_tetriser_state.get_actor_draw_context()` merge (stage5 패턴 [:92-98](../godot/scripts/core/battle_draw_actor_context.gd#L92)) |
| 12 | `battle_playfield_effects_drawer.gd` | 🔴 `_clear_inactive_stage_actor_transients()`의 하드코딩 `for stage in [1,2,3,4,5]` → **6 추가** ([:522](../godot/scripts/core/battle_playfield_effects_drawer.gd#L522)). 누락 시 비활성 transient 정리 사일런트 미스 |
| 13 | `battle_scene_update_prewarm_driver.gd` | `STAGE6_RUNTIME_PREWARM_KEYS` const 추가 + stage→key 라우팅 (stage1/2 패턴 [:126-141](../godot/scripts/core/battle_scene_update_prewarm_driver.gd#L126)) |
| 14 | 테스트/스모크 | 스테이지 카운트/라우팅 assert 업데이트, stage6 state reset 스모크, 반사축/벽스펙 유닛 스모크, **super 테트로 충돌 매트릭스 스모크**(§2.5) |

> 모든 신규 모듈은 사용 전에 카탈로그 등록 필수. boss AI context는 state가
> `get_boss_ai_context()` 를 노출해야 merge됨(홍련 동일). draw scene deps(#10), actor draw
> context merge(#11), transient cleanup 리스트(#12), prewarm key 라우팅(#13)은 stage 1~5에는 이미
> 있으나 6에는 빠지기 쉬운 접점 — 코덱스 리뷰로 추가됨.

---

## 5. 자산

원본 → Godot rename(`stage6_tetriser_*`) 복사 후 import:

| 원본 | Godot 대상(예시) | 용도 |
|---|---|---|
| `bgm/stage7bgm.wav` | `stage6_tetriser_bgm.ogg` | 스테이지 BGM |
| `sounds/tetrisbreak.wav` | `stage6_tetriser_break.wav` | 테트로 파괴 |
| `sounds/tetriswall.wav` | `stage6_tetriser_wall.wav` | 벽/가드 스폰 |
| `sounds/bigtetromino.wav` | `stage6_tetriser_big.wav` | 대형/초인 테트로 |
| `sounds/tetrominoshield.wav` | `stage6_tetriser_shield.wav` | 가드 블록 |
| `sounds/characterlazer.wav` | `stage6_tetriser_laser.wav` | 초인 광선 |
| `sounds/cry.wav` (SOUND_CRY) | (공용 포효) | 초인 발동 포효 |
| `stagevideo/stage7.mp4` | `stage6_tetriser_intro.*` | 인트로(사용 시) |

> 사운드 실사용 여부(`bigtetromino`/`tetrominoshield`)는 첫 조사에서 "로드는 되나 활성
> 호출 미확정"으로 나옴 → 포팅 시 호출부 확인. 미사용이면 복사 보류.

보스 스프라이트/스킬 카드/로딩 이미지가 부족하면 **AutoSprite MCP**로 신규 생성
(`/sprite-generation` 라우팅). 최종 경로는 `stage6_tetriser_*` 로 통일.

---

## 6. 좌표 / 플레이필드 주의

- Godot 플레이필드 = **풀 760×750 캔버스** (game x=0..WIDTH). 벽/장애물은 인게임 좌표로
  배치하고, 필러/레터박스 배경에 그리지 않는다.
- 벽 좌표: 원본 좌 `x=0` / 우 `x=WIDTH-grid_w`(=680), cols=4(80px). Godot에서도 **원본 좌우 끝 배치를
  유지**한다(레터박스가 아니라 실제 경기장 끝). 폭/위치를 바꾸려면 **밸런스 변경으로 별도 기록**(임의 재결정 금지). (§2.4)
- 중앙 큐브 위치 `(WIDTH//2, HEIGHT//2)` 는 Godot 플레이필드 중앙으로 매핑.

---

## 7. 보스 게이지바 → 보스 스킬 카드 HUD 변환

원본의 오른쪽 세로 게이지바(`draw_stage7_boss_gauge_bar`, `draw_stage7_super_bar`)를
**그대로 가져오지 않는다**. 규칙대로 Godot 달지식 보스 스킬 카드 HUD
(`stage6_tetriser_boss_skill_hud_renderer.gd`)로 변환: 게이지 + 낙하/가드/벽/초인 상태를
카드로 표현. 참고로 원본 `draw_stage7_super_bar()` 는 이미 비활성(return) 상태
[pingfighter.py:118451-118453](../pingfighter.py#L118451-L118453).

---

## 8. 개발 순서 (진행 상태 — 2026-06-04)

1. ✅ **스캐폴딩:** 라우팅/피커(7→6)/전환 종료치(`DEMO_STAGE_SEQUENCE_END=6`) + 빈 모듈 7종. (`08d22c810`)
2. ✅ **손맛 코어:** 게이지 + 낙하 테트로미노(2a) + 공 충돌/반사축/파괴(2b). (`616e60fdd` `686045b9c`)
3. ✅ **구조물:** 가드 블록(3a) + 테트로 벽(3b) + 대시/연막/폭발 파괴 API(3c). (`e6db8206f` `3815acc31` `30f563952`)
4. ✅ **궁극기/큐브:** 초인테트리서 드레인 모델(4a) + 중앙 큐브 3×3/10~14패스/재조립5(4b) + 광선·EMP(4c). (`c7caec816` `009876e3c` `0627dfb34`)
5. **마감 (완료):**
   - ✅ 보스 스킬 카드 HUD (5a, 게이지+4스킬, 공유 `BossSkillCardHudSpec`, 현재
     `stage6_tetriser_*_skillcard_imagegen_v1.png` 텍스처 사용). (`9cad7db7a`)
   - ✅ 오디오 (5b): **BGM** `stage7bgm.wav → stage6_tetriser_bgm.ogg`(ffmpeg) + game_audio 배선(`ff05afa7f`);
     **효과음 3종** `stage6_tetriser_{break,wall,super_roar}.wav` + 이벤트 배선(파괴=break/벽=wall/초인=cry);
     **prewarm 키** `STAGE6_RUNTIME_PREWARM_KEYS` 등록. (`2c7910bbf`)
   - ✅ **5c 완료:** `character_info_overlay.gd` 리팩터 컴파일 복구 후 전체 warning scan/headless load,
     Stage 6/perf smoke, 그리고 Stage 6 직접 런타임 QA까지 통과.
   - ✅ **보스 스프라이트 (2026-06-04, `94d6a4fd6`):** AutoSprite 16-bit 픽셀아트 7종 시트
     (idle/walk/attack/dash/victory/defeat/stun, 3열 8프레임 256px 그리드)를
     `godot/assets/sprites/bosses/stage6_tetriser/`에 커밋, `stage6_tetriser_boss_actor_renderer.gd`를
     placeholder 패들 → 우선순위 상태머신(§17.6: defeat>victory>stun>dash>attack>walk>idle)으로 교체.
     초인 super_scale/aura 유지. 격리 warning scan/상태 smoke/headless load/런타임 7종 로드 검증 통과.
   - ✅ **배경/맵 (2026-06-04, `b74449a51`):** `stage6_tetriser_pillar_background.gd`를
     단색 placeholder → Python `AnimatedBackgroundStage7` 절차적 충실 포팅으로 교체
     (토치 글로우 4 + 스윕 라이트 밴드 + 광점 12 + 청보라 아레나 테두리). 중앙 큐브는
     playfield_renderer가 게임플레이로 그리므로 배경에서는 제외(중복 방지). 좌표는
     stage5 형제 컨벤션, LOD 포함. 격리 warning scan/상태 smoke/headless load 통과.
   - ✅ **필러 테트리스 데코 (2026-06-04, `f7ce4cb35`):** `stage6_tetriser_pillar_tetris.gd`로
     좌/우 레터박스 여백에 자동 플레이 테트리스 2판(낙하/회전/라인클리어/무지개/NEXT 프리뷰).
     Python `TetrisGame`/`TetriserPillarBackground` 동작 포팅. 원본은 화면 내 80px 필러였지만
     Godot 풀-캔버스 규칙상 레터박스 여백에 배치(HUD 크롬 뒤 백드롭). 격리 scan/로직 기능검증/
     상태 smoke/headless load 통과.
   - ✅ **필러 정적 배경 리디자인 (2026-06-26):** live Tetris well 데코는 스킬카드/대시구슬 HUD와
     정보량이 충돌하므로 제거. `stage6_tetriser_pillar_background.gd`가
     `stage6_tetriser_pillar_bg_imagegen_v1.png`를 cover-fit으로 그리는 Stage 3식 정적 분위기
     배경으로 전환했고, `stage6_tetriser_pillar_tetris.gd` 런타임 모듈은 삭제. 기존 보스 스킬카드
     HUD와 공용 필러 HUD는 foreground로 유지.
   - ✅ **크리스탈 실드 보스 스킬 (2026-06-05):** `stage6_tetriser_crystal_shield_state.gd`로
     `pillar_tetriser.py`의 `CrystalShieldSystem` 핵심 동작을 포팅. 플레이어 4점에서 예약, 다음
     serve-wait에 24개 궤도 실드 형성, 형성 중 freeze flag 노출(`skip_ball_motion_step`은 유지 false),
     플레이어 공 충돌 시 맞은 블록+양옆 블록 증발, 라운드/스테이지 리셋 정리 smoke 통과.
   - ⏳ **후속:** 로딩/결과 화면 이미지. 테트리서 보스 스킬카드 텍스처는
     `godot/assets/sprites/hud/stage6_tetriser_*_skillcard_imagegen_v1.png`로 배치 완료.

> ✅ **5c 최종 게이트 완료 (2026-06-04):** `run_headless_load_check.ps1`, `run_warning_scan.ps1 -ChunkSize 100`,
> Stage 6 smoke 9종, perf smoke, 직접 Stage 6 런타임 캡처/serve 확인 통과.
>
> ✅ **최신 HEAD 재검증 (2026-06-05, `a046c8f7c`):** dragon-breath/molotov FX 재사용(`aaa1ccd65`)과
> Stage 6 필러 중복 cabinet 제거(`a046c8f7c`) 이후 Stage 6/라우팅/prewarm/perf smoke 12종,
> F5 direct-switch smoke, `run_warning_scan.ps1`, `run_headless_load_check.ps1`,
> Windows Release export 및 exported exe `--headless --quit-after 3` 통과.

---

## 9. 크로스라운드 / 게임엔드 누수 트랩 (필수)

`CLAUDE.md` 규칙: 보스 소유 globals는 `go_to_next_round()`(라운드)와 `show_result()`
(게임엔드) **양쪽**에서 정리해야 한다. Godot 포팅은 단일 `stage6_tetriser_state.reset()`
를 라운드엔드/result/스테이지이탈 3경로에서 호출. 정리 대상:
- 게이지(라운드 간 persist이므로 스테이지 이탈에서만 0), 낙하 테트로, 가드, 좌/우 벽,
  초인 상태/스케일/파티클, 광선, 중앙 큐브, 테트로 파편.

---

## 10. 표기/실동작 불일치 & 포팅 함정 요약 (그대로 포팅 = 코드 우선)

1. **초인 지속:** 표기상 "15초"(`STAGE7_SUPER_DURATION_MS`)지만 사문화 상수.
   실제 = 게이지 500 / 25초당 드레인 ≈ **20초**. → 드레인 모델로 포팅.
2. **스케일:** 본체 2.0×(광폭 1.4×) vs 셀 1.7× 별개.
3. **벽 좌표:** 원본은 좌 `x=0` / 우 `x=WIDTH-grid_w`(=680), cols=4(80px). Godot 풀캔버스에서도
   그대로가 충실 포팅(= 경기장 좌우 끝). 변경 시 **밸런스 변경으로 명시**(임의 재결정 금지). (§2.4)
4. **super 테트로 면역은 일반 공 반사 한정** — 대시/무기/연막/큐브폭발/레이저는 super도 파괴. (§2.5)
5. **큐브 2개 분리** — 2D 논리 큐브(melt 1000ms) vs 3D 배경 큐브(melt 1200ms / rebuild 1400ms).
   논리 제거와 비주얼 타이머를 따로 구현. (§2.8)

---

## 11. 권한/참조 우선순위

- 런타임 통합/성능: `AGENTS.md`.
- 모듈 경계/소유권: `docs/godot_module_ownership_ledger.md`, `docs/godot_port_architecture.md`.
- 스테이지 번호 정책: `CLAUDE.md` (Godot 슬롯 ≠ Python 슬롯, 자산 rename).
- 순수 게임플레이 불변식 1차 소스: `game_logic/stage7_tetriser.py`.

---

## 12. 결정 필요 항목 (구현 착수 전 확인 권장)

1. **피커/로드맵 재번호:** 테트리서를 id 6으로 옮기면 기존 8~12 placeholder(아카무 리고/
   미노타우로스/최종 관문/4천왕/진엔딩)를 그대로 둘지(7번 공백 허용), 전체 시프트할지.
   → 권장: 미구현 placeholder는 그대로 두고 테트리서만 6으로(최소 변경).
2. **광폭화(enraged) 트리거:** Godot에서 무엇이 `enraged_boss_active` 에 대응하는지
   (난이도/리그/디버그). 미정 시 일반 모드만 1차 포팅하고 광폭화는 후속.
3. **공 물리 하이재킹 없음 확인:** 원본은 per-frame 공 업데이트 하이재킹 없이 표준
   물리(블록 충돌만). Godot에서도 `skip_ball_motion_step` 류 소유 금지 유지.
4. **인트로 비디오 사용 여부:** `stage7.mp4` 포팅 여부(다른 스테이지 인트로 정책과 정합).

---

## 13. 충돌 문서 갱신 상태 (Stage 6 = 테트리서 결정 반영)

"6번 슬롯 비활성" 전제로 쓰인 기존 문서들의 충돌을 제거한 현황.

**✅ 완료 (2026-06-03)**
- 메모리 `project_godot_stage_numbering.md` — 제목·표·적용 규칙을 6=테트리서로 갱신.
- `docs/stage5_hongryun_godot_port_plan.md` line 10 / 53 / 106 — "Stage 6 비워 둠/선택 불가"
  → "Stage 6=테트리서, 별도 기획에서 다룸"으로 교정 (line 17 "홍련 중복 라우팅 금지"는 유효해 유지).
- `docs/refactor_status_brief.md` — 옛 Stage 6 부재 / 계획 전용 상태를 제거하고,
  현재는 Stage 6 Tetriser runtime present + loading/result art pending으로 브리핑 갱신.
- 역사 기록: 당시 root stage-order 표에서 차단성 문구 "비활성 / 선택 불가"를
  제거하고 Godot 6=Python 7(테트리서) 매핑 행을 추가했다. 현재 정본은
  `AGENTS.md`의 current stage rule과 `current_development_boundary.md`다.
- (2026-06-04) `docs/godot_module_ownership_ledger.md` — stage6_tetriser_* 모듈 7종 + 접점
  owner 등록, 상태 "Stage 6 complete through 5c / follow-up assets pending".

**유지(충돌 아님)**
- `docs/stage5_hongryun_asset_manifest.md`의 `stage6_*` 항목 = 레거시 Python(stage6=홍련) 소스
  파일명 → Godot `stage5_hongryun_*` rename 매핑. 자산 출처 기록이므로 그대로 둔다.
- `docs/핑파이터_기본가이드.html` "Stage 6 - 홍련" = 동결된 레거시 Python 게임 가이드(출처용 유지).
