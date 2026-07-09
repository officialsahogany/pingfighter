# Stage 7 아카무 리고 포팅 기획 (Godot)

원본 PingFighter **Python Stage 8 (아카무 리고)** 를 Godot **Stage 7** 정식 슬롯으로
포팅하기 위한 기획서. 핵심 수치는 실제 코드에서 직접 검증했으며 `file:line` +
함수명 앵커로 근거를 남긴다(대형 파일 줄번호는 드리프트하므로 함수/변수명이
1차 앵커). 본 문서는 설계/체크리스트이며, 런타임 통합 세부는 `AGENTS.md` /
`docs/godot_port_architecture.md` 가 최종 권한을 가진다.

**스코프 제외 (사용자 결정, 2026-07-10):** 필러 배경 아트와 인게임 내부(경기장
필드) 그림은 **신규 작화 예정**이므로 원본 아트 포팅 대상에서 제외한다. 단,
아트가 앉을 **런타임 슬롯/훅** (필러 득점 반응, 배경 절차 레이어 후보)은 본
기획의 범위다 — §7 참조.

작성일: 2026-07-10 · 템플릿: `docs/stage6_tetriser_port_plan.md`

---

## 0. 스테이지 번호 결정 (Godot 7 = Python 8)

테트리서 선례(Godot 6 = Python 7)와 동일한 "Godot 슬롯 ≠ Python 슬롯" 패턴.

| 구분 | Godot (신규) | Python (참조) |
|---|---|---|
| current_stage | `7` | `8` |
| 코드/자산 prefix | `stage7_akamu_*` | `stage8_*`, `STAGE8_*` |
| 보스명 | 아카무 리고 (Akamu Rigo) | 아카무 리고 |
| 배경 | (신규 작화 — 범위 외) | `AnimatedBackgroundStage8`, `pillar_ninja.py`, `stage8_field.png` |

원칙:
- Godot 자산/모듈은 `stage7_akamu_*` 로 rename. Python `stage8_*` 파일명을 살아있는
  Godot 이름으로 쓰지 않는다(모듈 헤더/매니페스트에 원본 경로 주석).
  풀네임 `stage7_akamu_rigo_*` 는 경로가 과도하게 길어져 축약형을 표준으로 한다
  (변경하려면 §12 결정 항목).
- 디버그 피커의 `{"id": 8, "name": "스테이지 8", "desc": "아카무 리고"}` 엔트리를
  **id 7 로 재라벨** ([stage_debug_picker.gd:15](../godot/scripts/core/stage_debug_picker.gd#L15),
  현재 6→8로 7번이 공백). 9~12 placeholder(미노타우로스/최종 관문/4천왕/진엔딩)는
  미구현 슬롯 그대로 유지(테트리서 §12 결정과 동일한 최소 변경 방침).
- Godot에 stage7/akamu 스캐폴딩·자산·모듈은 현재 **0개**(완전 신규). 유일한 기존
  흔적: 피커 id 8 엔트리 + `language_settings_data.gd` 보스명 번역 4개 언어
  (en `Akamu Rigo` / zh `阿卡姆·里戈` / ja `アカム・リゴ` / es `Akamu Rigo`).

> ⚠ **테마 표기 정리:** 아카무 리고의 정식 테마는 **닌자 저택 / 그림자(shadow_dojo)**
> 다 (`SPEC_PINGFIGHTER.md:62`, `config/planet_configs.py` "그림자 행성",
> `generate_stage8_ninja.py`). 레거시 `ko.json:2566` / `ui/space_map.py` 의 서브타이틀
> **"심해 : 어둠의 끝"은 미정리 잔재**이므로 Godot 신규 문구/아트 브리프에 가져오지
> 말 것. 신규 작화 무드 기준: 어두운 일본 전통 닌자 저택, 오동나무/갈색 톤 + 붉은
> 악센트 + 등불 주황빛 + 그림자 보라 `(90,60,130)`.

---

## 1. 보스 정체성

- 보스명: **아카무 리고** — 그림자 닌자. 탑뷰 복면 닌자(검정 닌자복 + 빨간 복면 띠 +
  왼손 표창 + 오른손 탁구채 + 등 칼집) 컨셉이 `create_stage8_boss.py` /
  `generate_boss_stage8.py` 에 일관 기록.
- 테마색: `(60, 80, 120)` (BOSS_CONFIGS), 외침 말풍선 `(90, 60, 130)` 그림자 보라
  (`BOSS_STAGE_SHOUT_COLORS[8]`, pingfighter.py:39556 부근).
- AI 스탯 (`BOSS_CONFIGS[8]`, [config/stage_configs.py:130](../config/stage_configs.py#L130), 직접 검증):
  `max_speed 9.4`(최상급) / `accel·decel 1.11` / `instant_stop 1.131` /
  `predict_distance 120` / `fail_error 180`(전 보스 최저 = 가장 정확) /
  `skill_power 0.35` / `dash_cooldown_range (26.0, 38.0)` / `dash_max_distance 372` /
  `special_skill None`(스킬은 pingfighter.py 하드코딩). 난이도 배율
  `STAGE_DIFFICULTY_MULTIPLIERS[8] = 2.35`(7=2.2보다 상향).
- 체력형 보스 아님. 표준 라운드 점수제 `win_goal = 5`, 듀스는 범용
  `check_deuce_system()` 사용. **고유 규칙: 플레이어 3라운드 선취 시 초각성**(§2.F).
- 보스 이미지 크기 기준 `BOSS_IMG_STAGE8_WIDTH/HEIGHT = 110×96`(폴백/분신 rect 기준).
- 리그: 스킬 스테이트 머신이 `handle_boss()` 프롤로그(리그 분기 **이전**)에 있어
  주니어/챔피언/신화 전 리그에서 동일 동작. 리그 차이는 기본 추적 AI와 대시 쿨타임
  배율(champion/mythic 0.4)뿐. `handle_boss_pro()` 는 디스패치 미연결 데드코드.

---

## 2. 핵심 전투 시스템 (코드 검증 수치)

상수 블록: [pingfighter.py:63402-63521](../pingfighter.py#L63402-L63521) (직접 확인).
스킬 6종 + 초각성 오오라, 전부 공유 게이지 `boss_special_gauge`(최대 500) 구동.

### 2.0 게이지 수급 — 패들 히트 기반 (테트리서의 시간 충전과 다름)

`handle_ball()` 보스 패들 반사 분기 [pingfighter.py:173771-173784](../pingfighter.py#L173771-L173784) (직접 검증):

| 상황 | 획득량 |
|---|---|
| 일반 패들 반사 | **+80** |
| 초각성(`stage8_awakened`) 후 반사 | **+90** |
| 극정호신 중 반사 | **+20** (수급 감소 유지) |
| 초각성 바람 오오라로 공 차단 | **+90** (`check_wind_aura_ball_collision`) |
| 상한 | 500 |
| 🔴 라운드 전환 이월 | **×0.7 (30% 감소, `int()` 버림)** + `boss_special_ready/waiting` 해제 — 전량 유지 아님. `go_to_next_round()` [pingfighter.py:76315-76322](../pingfighter.py#L76315) (직접 검증, 코덱스 리뷰 교정) |

### 2.A 그림자분신 (Shadow Clone)

`_spawn_stage8_shadows` / `update_stage8_shadow_clones` [pingfighter.py:119375](../pingfighter.py#L119375), [:119821](../pingfighter.py#L119821)

| 항목 | 값 | 근거 |
|---|---|---|
| 트리거① | 패들 피격 시 게이지 ≥100 & 미시전 & 분신 없음 & 비-극정호신 → **25% 확률** | `handle_ball` [:173802-173813](../pingfighter.py#L173802) |
| 트리거② | 초각성 오오라 차단 시 **30% 확률** (쿨·게이지 무시) | `check_wind_aura_ball_collision` [:119166](../pingfighter.py#L119166) |
| 시전 | **500ms** 정지 시전(보스 위치 고정) | `STAGE8_SHADOW_CAST_MS = 500` |
| 게이지 차감 | **시전 완료 시점에 -100 (1회)** — 트리거 시점엔 미차감 | `update_stage8_shadow_clones` "if gauge>=100: -=100" (직접 검증) |
| 분신 수 | 일반 **2개**(offset ±90) / 초각성 **4개**(±60, ±120) | `_spawn_stage8_shadows` offsets (직접 검증) |
| 등장 위치 | 시전 위치 기준 `Y_OFFSET = -150`(위쪽), 600ms 벌어지며 등장 | `STAGE8_SHADOW_Y_OFFSET`, `EMERGE_MS = 600` |
| 이동 | `vx = ±random(7.5~12.0)` 좌우 벽 반사, 속도 클램프 15.0 | `update_stage8_shadow_clones` |
| 공 상호작용 | 분신 rect(110×96)와 공 충돌 시 `calculate_bounce(rect)` → **추가 보스 패들처럼 반사**, 분신 즉시 소멸(0.7s 소멸 애니) | `STAGE8_SHADOW_DEATH_MS = 700` |
| 수명 / 쿨다운 | **10000ms** / **8000ms** | `DURATION_MS`, `COOLDOWN_MS` |
| 본체 무적 | 시전 중 + 시전완료 후 600ms 버퍼 동안 공 판정 무시 | `STAGE8_SHADOW_INVULN_BUFFER_MS = 600`, intangible 블록 [:173655-173673](../pingfighter.py#L173655) (직접 검증) |
| SFX | 소환 `sounds/kurokake.wav` / 소멸 `sounds/kurokakeout.wav` | `_spawn_stage8_shadows` / 수명만료 분기 (직접 검증) |

### 2.B 표창 던지기 (Shuriken)

`_spawn_stage8_shuriken` / `update_stage8_shurikens` [pingfighter.py:119416](../pingfighter.py#L119416), [:119930](../pingfighter.py#L119930)

| 항목 | 값 | 근거 |
|---|---|---|
| 트리거 | `handle_ball` 스케줄러: 게이지 ≥30 & 쿨다운 경과 & 비-그림자/비-극정호신 | [:174881-174900](../pingfighter.py#L174881) |
| 시전 / 코스트 | **300ms** 정지 / **게이지 -30** | `STAGE8_SHURIKEN_CAST_MS`, `COST` |
| 발사체 | 플레이어 중심 조준 1발, 속도 **20.0 px/frame**, rect 18×10 | `STAGE8_SHURIKEN_SPEED` (직접 검증) |
| 쿨다운 | random(**8000~25000ms**) | `MIN/MAX_COOLDOWN_MS` |
| 초각성 보너스 | 본 발사 0.2초 뒤 추가 1발 예약(예약분은 재예약 안 함) | `stage8_shuriken_pending`, `from_pending` 가드 (직접 검증) |
| 피격: 슬로우 | `player_slow_timer = 120`프레임(2초), `factor = 0.2`(80% 감속), `current_speed` 즉시 ×0.2 | `SLOW_FRAMES / SLOW_FACTOR` (직접 검증) |
| 피격: 게이지 드레인 | 0.5초(30프레임)마다 -15 × 4회 = **총 -60** (플레이어 special_gauge) | `GAUGE_TICK_FRAMES/AMOUNT` (직접 검증) |
| 면역① 연막 | `is_player_in_smoke()` → 표창이 연막에 **흡수**(사운드/이펙트 없이 소멸) | [:119950](../pingfighter.py#L119950) (직접 검증) |
| 면역② 클렌즈 | `is_cleanse_immune()` → **슬로우 + 게이지 드레인 모두 차단** (드레인 세팅이 비면역 분기 안에 있음), 혈흔 파티클은 재생 | `update_stage8_shurikens` (직접 검증) |
| SFX | 발사 `pyochangshoot.wav` / 명중 `pyochanghit.wav` | `SOUND_SHURIKEN_SHOOT/HIT` |

### 2.C 구름장막 (Cloud Veil)

`_start_stage8_cloud` / `update_stage8_cloud` [pingfighter.py:119451](../pingfighter.py#L119451), [:119991](../pingfighter.py#L119991)

| 항목 | 값 | 근거 |
|---|---|---|
| 트리거① | 패들 피격 시 게이지 ≥120 & 쿨다운 경과 & 비-극정호신 → **35% 확률**, 게이지 **-120 즉시 차감** | `handle_ball` [:173814-173823](../pingfighter.py#L173814) (직접 검증) |
| 트리거② | 초각성 오오라 차단 시 **30% 확률** (쿨·게이지 무시) | [:119164](../pingfighter.py#L119164) |
| 시퀀스 | 보스가 **화면 중앙 X로 즉시 스냅** → `pre`(400ms 정지+오로라) → `down`(≈317ms 하강, `PLAYER.centery - 40`까지) → 구름 폭발 → `up`(상승) → +180ms 추가 무적 | `_start_stage8_cloud` `BOSS.centerx = WIDTH//2` (직접 검증), `PRECAST_MS=400`, `DASH_MS=220`(down은 ×1.44) |
| 구름 지속 | 표시 **5000ms** + 페이드 **3000ms**, 퍼짐 280ms, rect 235×56 | `CLOUD_VISIBLE_MS`, `fade_ms`, `EXPAND_MS` |
| 효과 성격 | **시야 차폐 연출 전용** — 공/플레이어 직접 효과 없음 | `update_stage8_cloud` |
| 무적 | `pre/down/up` 전 구간 + invuln 버퍼: `boss_hitbox_expanded = Rect(-9999,-9999,0,0)` 로 공 완전 관통 | intangible 블록 (직접 검증) |
| 쿨다운 | random(**10000~20000ms**) | `MIN/MAX_COOLDOWN_MS` |
| 초각성 | 착지 후 머무름 연장(`stage8_cloud_midstay_end_ms`) | 상수 블록 주석 |
| SFX | `ninjacloud.wav` (`SOUND_NINJA_CLOUD`), 연막 계열 `smokebomb.wav` | `sound_effects.py` |

### 2.D 영체탈주 (Stun/Net Escape)

`_try/_start/_update_stage8_stun_escape` [pingfighter.py:119637](../pingfighter.py#L119637), [:119663](../pingfighter.py#L119663), [:119748](../pingfighter.py#L119748)

| 항목 | 값 | 근거 |
|---|---|---|
| 트리거 | 보스 스턴(`boss_stunned_timer>0`) 또는 코만도 그물덫총 포획(`_is_stage8_net_trapped`) | `handle_boss` [:178162-178165](../pingfighter.py#L178162) |
| 조건 | 게이지 ≥**30**, **40% 확률**(1회 시도, `attempted` 플래그), 스턴은 지연 0ms / 그물은 **300ms 지연** | `STUN_ESCAPE_COST=30`, `STUN_ESCAPE_DELAY_MS=0`, `NET_ESCAPE_DELAY_MS=300` (직접 검증) |
| 효과 | `boss_stunned_timer=0`, `boss_knockback_vel=0`, 그물 해제, 측면 **500ms ease-out 대시**(최대 260px) | `_start_stage8_stun_escape` |
| 연출 | 홀로그램 허수아비(페이드 400ms) + 잔상 5개(60ms 간격, alpha 255→80) | `STUN_HOLOGRAM_FADE_MS=400` |
| 무적 | 대시 중 `boss_hitbox_expanded = Rect(-9999)` 공 관통 | intangible 블록 (직접 검증) |
| 상호작용 | 극정호신 중이면 영체탈주 대신 극정호신 유지 | [:178160 부근](../pingfighter.py#L178160) |

### 2.E 극정호신 (Superspeed — 초각성 전용 궁극기)

`_start/_end_stage8_superspeed` / `_stage8_superspeed_dash` [pingfighter.py:119544](../pingfighter.py#L119544), [:119521](../pingfighter.py#L119521), [:119571](../pingfighter.py#L119571)

| 항목 | 값 | 근거 |
|---|---|---|
| 발동 | **초각성 상태에서만**, 게이지 ≥**250** & 쿨다운 경과 & 비-영체탈주 → **자동 발동**, 게이지 -250 | `handle_boss` [:178146-178153](../pingfighter.py#L178146) (직접 검증) |
| 지속 / 쿨다운 | **10000ms** / **25000ms** | `SUPERSPEED_DURATION_MS`, `COOLDOWN_MS` |
| 발동 연출 | 350ms 프리즈 + 1500ms 텍스트, 다른 스킬(그림자/표창/구름) 강제 중단 | `FREEZE_MS=350`, `TEXT_MS=1500` |
| 효과 | 대시 쿨타임 0(`boss_dash_cooldown_until_ms = 0`) — 매 프레임 벽반사 예측으로 공 낙하 X까지 **속도 40 대시** 반복 | `_stage8_superspeed_dash` (직접 검증) |
| 대시 후 경직 | `max(1, int(0.03*FPS))` ≈ 1프레임 (사실상 무경직) | `DASH_STUN_FRAMES` |
| 연출 | 환영 분신 5개(페이드 800ms/딜레이 60ms) + 어둠 파티클(max 200) + 이동 잔상(max 30, 2프레임 간격) | `AFTERIMAGE_*`, `DARK_PARTICLE_MAX`, `TRAIL_*` |
| 수급 페널티 | 극정호신 중 패들 반사 +20으로 감소 | §2.0 |
| 긴급대시 | `_boss_try_emergency_dash` 게이지 비용 50 → 극정호신 중 **무료 + 거리 제한 해제** | [:175171](../pingfighter.py#L175171) |

### 2.F 초각성 (Awakening) + 바람 오오라

`handle_boss` 프롤로그 + `check_wind_aura_ball_collision` [pingfighter.py:178119-178144](../pingfighter.py#L178119), [:119098](../pingfighter.py#L119098) (직접 검증)

| 항목 | 값 |
|---|---|
| 트리거 | `round_wins >= 3 or player_score >= 3` 최초 도달 → **3000ms 프리즈 인트로** → `stage8_awakened = True` + `show_speech("초각성!")` + wind burst(800ms, 파티클 48) |
| 효과① | 그림자분신 2→**4개** |
| 효과② | 표창 +**1발**(0.2s 뒤) |
| 효과③ | **바람 오오라**: 보스 중심 반경 **90px** 내 플레이어 공(마지막 타자가 boss가 아닌 공)을 **하향 반사** — `ball_vel[1] = abs(ball_vel[1]) * 1.1`, 수평 ±2 랜덤 [:191424-191426](../pingfighter.py#L191424). 히트당 게이지 +90, **30% 확률 구름 / 30% 확률 그림자 즉시 발동(쿨·게이지 무시, 독립 롤)**. 히트 쿨다운 300ms |
| 오오라 내구 | **5회** 차단 시 소진 → **10000ms** 재충전 (`WIND_AURA_RECHARGE_MS`) |
| 효과④ | 극정호신 사용 가능화 |
| 지속성 | 한번 각성하면 라운드 간 **유지** (0-0 새 게임에서만 리셋) |
| SFX | 오오라 차단 `ninjashield.wav` (`SOUND_NINJA_SHIELD`) |

### 2.G 보스 무적(intangible) 판정 통합 — 직접 검증

`handle_ball` 충돌 게이트 [pingfighter.py:173655-173680](../pingfighter.py#L173655):

- 그림자 시전 중 OR `cast_start + 500 + 600ms` 이전 → `stage8_shadow_intangible`
  (충돌 조건식에서 제외).
- 구름 `pre/down/up` OR invuln 버퍼 → hitbox 를 `Rect(-9999,-9999,0,0)` 로 대체.
- 영체탈주 활성 → 동일하게 hitbox 대체.

Godot 포팅 시 이 세 창(window)은 **하나의 `is_boss_ball_intangible()` 판정으로
통합**해 ball 충돌 경로와 렌더러(반투명 연출)가 같은 소스를 읽게 한다.

---

## 3. 공 상호작용 요약 — 소유/하이재킹 없음 (테트리서와 동급으로 안전)

- **`ball_vel` 을 0으로 만들거나 공을 hold/하이재킹하는 스킬 없음.**
  `skip_ball_motion_step` 류 소유 금지 유지(테트리서 §12-3과 동일).
- 공을 **수정**하는 요소는 2개뿐: ① 그림자분신 = 추가 패들 반사(`calculate_bounce`,
  실패 폴백 `ball_vel[1] = abs`), ② 바람 오오라 = 하향 반사.
- 보스 위치를 **스크립팅**하는 스킬 2개: 구름장막(중앙 스냅 + 하강/상승), 영체탈주
  (측면 대시) → §6-6 보스 패들 스크립팅 트랩 적용 대상.
- 표창은 공 무영향 — 순수 플레이어 디버프 발사체.

---

## 4. Godot 모듈 설계 (Stage 5 홍련 / Stage 6 테트리서 패턴 미러)

신규 디렉토리: `godot/scripts/stages/stage7/`

| 파일 | 역할 |
|---|---|
| `stage7_akamu_state.gd` | **단일 소유자.** 게이지 수급 + per-frame `update(delta, context, effect_deps)`(§5 #5), 6스킬 스테이트 머신(그림자/표창/구름/영체탈주/극정호신/초각성+오오라), intangible 통합 판정, `get_boss_ai_context()`, `get_actor_draw_context()`, `reset_round()`(awakened 유지·게이지 ×0.7·transient 무조건 정리) / `reset()`(전체 초기화) / `reset_for_result()` (§9). |
| `stage7_akamu_playfield_renderer.gd` | 분신/표창/구름/오오라/잔상/홀로그램/어둠 파티클 전투 VFX. |
| `stage7_akamu_boss_actor_renderer.gd` | 보스 스프라이트 상태머신(우선순위 §7), 초각성 오오라 링, `boss_paddle_shrink_scale` 소비(§6-5), `draw_boss_status_overlays()` 호출. |
| `stage7_akamu_actor_renderer.gd` | 메인 draw 엔트리(플레이어/커맨도 공용 렌더 + 보스/플레이필드 오케스트레이션). |
| `stage7_akamu_pillar_background.gd` | **신규 작화 대기 슬롯** — 1차는 단색/그라디언트 placeholder, 정적 imagegen cover-fit 구조(stage6 최종형)로 골격만. 득점 반응 훅 인터페이스 유지(§7). |
| `stage7_akamu_pillar_scene_drawer.gd` | 배경 + 공용 필러 HUD + post-playfield 보스 스킬 카드 HUD. |
| `stage7_akamu_boss_skill_hud_renderer.gd` | 보스 스킬 카드 HUD — 게이지 + 그림자/표창/구름/극정호신 상태(§8). |

규칙:
- 상태 정리는 단일 `reset()` — 라운드엔드 / result(게임엔드) / 스테이지 이탈
  3경로에서 동일 메서드 호출(홍련 정리 패턴). **원본과 달리 무조건 리셋**(§9).
- 초각성(`awakened`)만 라운드 간 온전 persist. 게이지는 라운드 간 **×0.7 이월**
  (§2.0, 전량 유지 아님). 따라서 state는 `reset_round()`(라운드: awakened 유지 +
  게이지 ×0.7 + transient 정리)와 `reset()`(스테이지 이탈/게임엔드: 전부 초기화)을
  분리 노출한다(테트리서 `should_reset_transient_on_round_reset` 구분과 동일 패턴,
  ball round cleanup 이 `reset_round()` 를 호출 — §5 #9).
- 보스 이동속도는 Godot이 stage 번호로 자동 산출
  (`_get_boss_stage_speed_multiplier`, `battle_update_boss_ai_context_builder.gd:359-361`,
  `1.0 + min(offset*0.03, 0.50)`) — 원본 `max_speed 9.4 / fail_error 180` 체감은
  포팅 후 실플레이로 튜닝(§12).

---

## 5. 통합 체크리스트 (파일별)

stage6 배선을 미러. "case 6" 옆에 "case 7" 추가가 기본 패턴.

| # | 파일 | 작업 |
|---|---|---|
| 1 | `gameplay_stage_module_catalog.gd` | stage7 모듈 7종 path/label 등록 (stage6은 :436-463) |
| 2 | `stage_runtime_router.gd` | `STAGE_MODULES`에 `7:` role 매핑 추가 (:34-41 패턴) |
| 3 | `battle_update_stage_runtime_deps_builder.gd` | `_append_stage7_deps()` + include-all(:26) + match case(:50) |
| 4 | `battle_update_boss_ai_context_builder.gd` | `current_stage == 7` → `stage7_akamu_state.get_boss_ai_context()` merge (:178-181 패턴) |
| 5 | `battle_effects_update_controller.gd` | 🔴 `current_stage == 7` → `stage7_akamu_state.update(delta, context, effect_deps)` **per-frame tick 호출** + `_merge_score_context`(초각성 3점 판정용) ([battle_effects_update_controller.gd:93-102](../godot/scripts/effects/battle_effects_update_controller.gd#L93) stage6 패턴). **누락 시 표창 이동 / 구름 phase / 오오라 재충전 / 극정호신·쿨다운 타이머가 전부 정지** — 코덱스 리뷰 교정 |
| 6 | `battle_draw_scene_context.gd` | scene deps에 `stage7_akamu_state` 추가 (:81, :152) |
| 7 | `battle_draw_actor_context.gd` | `current_stage == 7` → `get_actor_draw_context()` merge (:106-109) |
| 8 | `ball_update_controller.gd` | `_process_stage7_akamu_collision()` — 분신 반사 + 오오라 반사 + intangible 게이트 위임 (stage6 :132, :533-539 패턴) |
| 9 | `ball_dependency_context.gd` + `ball_round_actor_cleanup.gd` | 🔴 **볼 경로 round deps 배선** — `get_stage_round_dep_keys()` match에 case 7 → `stage7_akamu_state` 추가 ([ball_dependency_context.gd:122](../godot/scripts/ball/ball_dependency_context.gd#L122) 패턴; #8의 충돌 처리가 이 deps에서 state를 꺼내므로 누락 시 분신/오오라 충돌이 실전에서 사일런트 미스) + `ball_round_actor_cleanup.gd`에 `stage7_akamu_state.reset_round()` 호출 ([:104](../godot/scripts/ball/ball_round_actor_cleanup.gd#L104) stage6 패턴; §4/§9의 `reset_round()`/`reset()` 분리 전제) — 코덱스 리뷰 교정 |
| 10 | `stage_debug_picker.gd` | STAGE_OPTIONS **8→7 재라벨**(:15) + `STAGE_RESET_MODULE_KEYS` stage7 추가(:52-56) + implemented 게이트 `<= 6`→`<= 7`(:186) + prewarm case 7(:309) + `_prewarm_stage7_selected_modules()` + foot 텍스트(:180) |
| 11 | `match_reset_controller.gd` | 리셋 키 리스트에 `stage7_akamu_state` 추가 (:205) |
| 12 | `match_score_event_controller.gd` | `_clear_stage7_round_boundary_fx()` (:66-67, :429-434 패턴) |
| 13 | `battle_playfield_effects_drawer.gd:644` | 🔴 하드코딩 `for stage in [1,2,3,4,5,6]` → **7 추가** (누락 시 비활성 transient 정리 사일런트 미스) |
| 14 | `battle_scene_update_prewarm_key_sets.gd` | `STAGE7_RUNTIME_PREWARM_KEYS` const (:156-160 패턴) |
| 15 | `battle_scene_update_prewarm_driver.gd` | include-all(:429) + match case 7(:442-443) |
| 16 | `battle_boot_resource_prewarm_controller.gd` | stage7 모듈/자산 부팅 prewarm (핫패스 lazy-init 트랩 회피) |
| 17 | `battle_scene_match_event_driver.gd:12` | `DEMO_STAGE_SEQUENCE_END := 6` → **7** |
| 18 | `battle_loading_screen_renderer.gd` | stage7 로딩 텍스처 경로(:21, :340-379) + `[1..6].has(...)` → 7 추가(:384) |
| 19 | `game_audio.gd` | `STAGE7_BGM_PATH/GAIN` + 플레이어 var + `_create_bgm_player` + `play/prime_stage_bgm` case 7 + 스킬 SFX 7종 로드/배선(§7) |
| 20 | 스테이지 클리어 result 플로우 (~10파일) | `stage6_boss_defeat` prefix 미러: `stage_clear_result_asset_loader.gd` / `_scene.gd` / `_actor_presenter.gd` / `_actor_click_handler.gd` / `_actor_reaction_update_handler.gd` / `_config_scene_handler.gd` / `_config_reset_state_handler.gd` / `_fallback_actor_scene_context_builder.gd` / `_layout_helper.gd`(`get_stage7_result_draw_rect`) / `stage_clear_result_scene_shell_prewarm_state.gd:91` / `stage_clear_result_runtime_context_data.gd`(+handler) `reset_stage7_for_result()` |
| 21 | `language_settings_data.gd` | 스킬명 신규 문자열(그림자분신/표창/구름장막/영체탈주/극정호신/초각성 — HUD 카드/디버그 노출분) 4개 언어 |
| 22 | 테스트/스모크 | §10 — 신규 stage7 스모크 + 기존 하드코딩 리스트/카운트/라우팅 assert 갱신 |

> 모든 신규 모듈은 사용 전 카탈로그 등록 필수. 스모크는 `godot/tests/*_smoke.gd`
> 글롭 자동 수집이므로 파일 생성만으로 러너 등록 완료.

---

## 6. 크로스컷팅 소비자 계약 (신규 스테이지 의무 — CLAUDE.md 트랩 인덱스 매핑)

1. **최루탄 보스 스킬 쿨다운 정지** (`active_item_boss_skill_cooldown_paused`):
   `stage7_akamu_state` 가 이 키를 소비해 **표창 스케줄러 / 그림자·구름 확률 트리거 /
   극정호신 쿨다운·발동 / 게이지 수급을 정지**하고, 인플라이트 표창·분신·구름은
   유지. + `draw_boss_status_overlays()` 호출 + `active_item_boss_skill_cooldown_pause_smoke.gd`
   행동 레그 추가(스테이지6 레그 3종 옆).
2. **커맨도 회피 rect**: 스킬 카드 HUD 렌더러가 `commando_firearm_panel_rect` 를 읽어
   `resolve_stack_start_y` 에 전달 + `boss_skill_card_hud_spec_smoke` 경로 리스트/행동 seal 추가.
3. **보스 슬로우 티어**: 신규 보스 슬로우 소스는 없음(아카무는 슬로우를 거는 쪽) —
   기존 플레이어발 슬로우(leg_shot 류)가 stage7 보스에도 걸리는지 공용 경로 확인만.
4. **플레이어 상태 면역 게이트**: 표창 슬로우+게이지 드레인은 적용 **전**
   `_is_player_status_immune` / cleanse 면역(`is_cleanse_immune` 대응: Smasher 클렌즈,
   부동갑주 full-CC)을 확인. 원본 검증 결과 **면역이면 슬로우와 드레인이 함께
   차단**되고 혈흔 연출만 남음 — 이 whole-hit 묶음을 유지(부동갑주 트랩의 "wave만
   나오고 효과는 들어감" 클래스 방지). 넉백 없음 → knockback 훅은 미적용.
   연막(연막탄/테크니컬조끼) 흡수는 해당 아이템의 Godot 포팅 여부에 따라 컨텍스트
   키(`player_in_smoke` 류)로 소비 — 미포팅이면 키만 예약(§12).
5. **`boss_paddle_shrink_scale`**: stage7 보스 렌더러는 자체 const draw size에 스케일을
   직접 곱한다(stage3 "안 작아짐" 버그 클래스). 충돌은 `boss_collision_shrink_scale`.
   Seal `_verify_bespoke_stage_renderers_consume_shrink` 에 stage7 추가.
6. **보스 패들 스크립팅 트랩** (구름장막 중앙 스냅+하강, 영체탈주 측면 대시):
   6대 불변식 — 보스 AI freeze 플래그 / (이 스킬들은 공 충돌을 **의도적으로 제거**하므로
   post-hit 스냅 대신 intangible 계약 문서화) / `DEFAULT_VALUES` 키 선언 /
   owner-less `cancel(null)` 에도 사는 self-healing 릴리즈 / **라운드 리셋 `boss_y`
   정규화**(구름 하강 중 라운드가 끝나도 보스가 홈 밴드로 복귀) / 홈 밴드 앵커.
   특히 구름 dash 중 라운드 종료 → 보스가 플레이어 옆에 남는 leak 스모크 필수.
7. **오오라/분신 own-serve 가드** (궤도 실드 트랩 매핑): 원본은 `last_hit_by == "boss"`
   공만 제외하는 **소유권 가드**인데, fresh serve 는 소유권이 비어 트랩 문서상
   양방향 모호. Godot 포팅 시 소유권 가드에 **방향 가드 추가**: 오오라는 보스 골을
   지키므로 상향 이동(`ball_vel.y < 0`) 공만 반사 대상, 하향(보스 서브 진행 방향)
   공은 조기 리턴. 분신 반사도 동일 검토. 스모크: "보스 서브 통과 + 플레이어 타구
   반사" 양방향 leg.
8. **공유 HUD wrapper prep-before-gate**: stage7 전용 카드 레일이 공용 래퍼를 거치면
   stage id 게이트를 caller 쪽에 유지(비소유 스테이지 call-count 스모크).
9. **스테이지 클리어 result box**: §5-18 배선 + `stage_clear_result_sequential_box_open_smoke` 정합.

---

## 7. 자산 (스코프 구분 포함)

### 7.1 범위 제외 — 신규 작화 예정 (사용자 결정)

| 원본 | 내용 | 포팅 취급 |
|---|---|---|
| `stage8_field.png` + `generate_stage8_ninja.py` | 인게임 경기장 필드 아트(다다미/장지문/등불) | ❌ 아트 미포팅. `stage7_akamu_pillar_background`/필드 배경은 placeholder → 신규 아트 landing 슬롯만 준비 |
| `pillar_ninja.py` (`NinjaPillarBackground`) | 필러 배경(대나무 숲/초승달/쇼지/등불/벚꽃) | ❌ 아트 미포팅. 단 **득점 반응 훅 `trigger_excitement(level)` 인터페이스는 유지** — 신규 배경 모듈이 나중에 소비 |
| `backgrounds/animated_background_stage8.py` | 인게임 오버레이(연기/족자/창빛/벚꽃/먼지/수리검/닌자 그림자/스타디움 펄스) | ❌ 아트 미포팅. **게임플레이 결합 없음 확인됨**(보스 상태/점수 미참조 — 순수 연출). 회전 수리검 + 가로지르는 닌자 그림자 절차 레이어는 신규 작화 시 재현 후보로 브리프에 기록 |

신규 작화 무드 브리프(§0 테마 표기 정리 참조): 닌자 저택 / 그림자 보라 / 등불
주황 — "심해" 문구 금지.

### 7.2 포팅 대상 오디오

| 원본 | Godot 대상 | 용도 |
|---|---|---|
| `bgm/stage8bgm.wav` | `godot/assets/bgm/stage7_akamu_bgm.ogg` (ffmpeg 변환) | 스테이지 BGM (단일 트랙 — 페이즈 전환곡 없음, 초각성 시에도 원본은 BGM 유지) |
| `sounds/pyochangshoot.wav` | `stage7_akamu_shuriken_shoot.wav` | 표창 발사 |
| `sounds/pyochanghit.wav` | `stage7_akamu_shuriken_hit.wav` | 표창 명중 |
| `sounds/ninjacloud.wav` | `stage7_akamu_cloud.wav` | 구름장막 |
| `sounds/ninjashield.wav` | `stage7_akamu_aura_block.wav` | 바람 오오라 차단 |
| `sounds/kurokake.wav` | `stage7_akamu_clone_spawn.wav` | 분신 소환 (직접 검증 — 조사 1차에 누락됐던 항목) |
| `sounds/kurokakeout.wav` | `stage7_akamu_clone_out.wav` | 분신 소멸 |
| `sounds/smokebomb.wav` | (공용 기존 자산 확인 후 재사용) | 연막 계열 |

`game_audio.gd` 배선은 stage6 패턴(`STAGE6_BGM_PATH` :357 / SFX :333-338 / 플레이어
var :627-632) 미러.

### 7.3 보스 스프라이트

원본 시트 세트 (`entities/stage8_boss_sprite.py`, 기준 프레임 271×518):

| 원본 | 구성 | 상태 |
|---|---|---|
| `assets/stage8walking.png` | 2행×4열 (1행 우 / 2행 좌) | 사용 중 |
| `assets/stage8dash.png` | 3행 중 마지막 행 4프레임(우2+좌2) | 사용 중 |
| `assets/stage8movechange3.png` | 하단 행 3번째 프레임(정면) 1장만 | 사용 중 (턴/정지) |
| `assets/stage8defeat.png` | 하단 행 4프레임, 비루프 | 사용 중 |
| `assets/stage8win.png` | 하단 행 4프레임, 루프 | 사용 중 |
| `assets/stage9hit2.png` | 상단 행 4프레임 | ⚠ 히트 시트가 **stage9 파일을 차용** (`stage8hit.png` 은 미사용) |
| `assets/stage8hit.png`, `stage8movechange2.png`, `stage8walking_backup.png` | — | 미사용 레거시, 포팅 제외 |

상태 우선순위(원본): 패배 > 승리 > 히트 > 대시 > 턴 > 걷기/정지. Godot stage6
컨벤션은 AutoSprite 7종 세트(idle/walk/attack/dash/victory/defeat/stun, 3열 8프레임
256px 그리드, `DRAW_SIZE 128×128`) — 원본 세트에는 idle/stun 이 없고 attack≈hit.
**시트 소스 결정은 §12-1** (재사용 vs AutoSprite 신규 생성). 신규 생성 시
`/sprite-generation` 스킬 §17 기본 7종 세트 규칙 + `godot/assets/sprites/bosses/stage7_akamu/`
경로. result defeat 시트는 in-battle defeat 시트 공유(stage6 컨벤션).

### 7.4 기타 (결정 필요)

- `stagevideo/stage8.mp4` 인트로 비디오 — 다른 스테이지 인트로 정책과 정합(§12-4,
  테트리서도 미결).
- `chat/stage8.png` / `chat/stage8angry.png` JRPG 대화 초상화 + 전투 전 3줄 대화
  ("여기까지 온 것도 용케…" / "시끄러 이 망할 요상한 닌자녀석" / "너도 멘헤라걸
  곁으로 보내주지") — Godot에 JRPG 대화 시스템이 없으므로 §12-5. 멘헤라걸(Stage 3)
  스토리 연결 대사라 보존 가치 있음.
- 인게임 speech("그림자분신!"/"표창!!"/"구름장막!"/"영체탈주!"/"초각성!")는 Godot
  보스 말풍선 경로가 있으면 배선, 없으면 스킬 카드 HUD 상태 표시로 대체.

---

## 8. 보스 게이지바 → 보스 스킬 카드 HUD 변환

원본 우측 세로 게이지바 `draw_stage8_boss_gauge_bar()` ([pingfighter.py:118685](../pingfighter.py#L118685),
수리검/연막 테마, 게이지 350+ 글로우)를 **그대로 가져오지 않는다**. 공유
`BossSkillCardHudSpec` (`scripts/stages/common/boss_skill_card_hud_spec.gd`) 기반
카드 HUD로 변환:

- 카드 후보: 게이지(공유) + 그림자분신(쿨다운/활성 수) + 표창(쿨다운) +
  구름장막(쿨다운/지속) + 극정호신(초각성 후 노출, 쿨다운/지속).
- 초각성/오오라는 카드보다 보스 본체 오버레이(오오라 링 + 내구 5핍)가 적합 —
  카드 4장 + 본체 오버레이 구성 권장(§12-6).
- 커맨도 회피 rect 계약(§6-2) 필수.
- lingpet 카드 위임 계약: pillar scene drawer 는 공유 헬퍼로
  `stage7_akamu_boss_skill_hud_skills` / `_active` 레일 키를 append 하고, HUD
  렌더러는 lingpet 카드를 공유 헬퍼에 위임한다 —
  `lingpet_rail_card_shared_smoke._verify_all_stage_rails_wire_shared_helper` 가
  스테이지별로 하드코딩 검사(§10-7).

---

## 9. 크로스라운드 / 게임엔드 누수 트랩 (원본 자체가 오염원 — 필수 교정)

원본 리셋 감사 결과 (직접 검증 [pingfighter.py:165755-165786](../pingfighter.py#L165755) 포함):

- 🔴 **원본 `reset_round()` 는 `if current_stage != 8:` 일 때만** 그림자/표창 전이
  상태를 초기화한다. 즉 **정작 Stage 8 진행 중 라운드 전환에서는 스킬 상태를
  리셋하지 않는다**(else 분기는 승/패 스프라이트 플래그만 리셋).
- 🔴 `stage8_shuriken_pending`, `stage8_cloud_*` 는 **어떤 라운드-리셋 경로에도 없음**
  (구름은 `update_stage8_cloud` 가 스테이지≠8일 때만 클리어).
- 극정호신/영체탈주 상태는 `handle_boss` 가 스테이지≠8일 때만 클리어.
- `show_result()` 에 Stage 8 전용 정리 없음. `main()` 재진입도 명시 재초기화 없음.
- 초각성/오오라/대화 플래그는 `go_to_next_round()` 0-0 조건에서만 리셋
  (`stage8_awakened` persist 는 **의도된 디자인** — 유지).

**Godot 포팅 규칙:** 단일 `stage7_akamu_state.reset()` 을 라운드엔드 / result /
스테이지 이탈 3경로에서 호출하고, 원본과 달리 **transient(분신·표창·pending·구름·
영체탈주·극정호신 연출) 전부 무조건 정리**한다. persist 구분:

| 구분 | 라운드 리셋 (`reset_round()`) | 스테이지 이탈/게임엔드 (`reset()`) |
|---|---|---|
| `awakened` + 오오라 내구/재충전 | **유지** (원본 디자인) | 초기화 |
| `boss_special_gauge` | 🔴 **×0.7 이월 (30% 감소, `int()` 버림)** + ready/waiting 해제 — 전량 유지 아님. `go_to_next_round()` [pingfighter.py:76315-76322](../pingfighter.py#L76315) (직접 검증, 코덱스 리뷰 교정) | 초기화 |
| 분신/표창(+pending)/구름/영체탈주/극정호신/잔상/파티클/무적 창 | **초기화** (원본 버그 교정) | 초기화 |
| 쿨다운 타이머(그림자/표창/구름/극정호신) | 초기화 권장(§12-7) | 초기화 |

원본 잔존 동작(라운드 넘어 분신 유지)을 "충실 포팅"으로 보존할지는 §12-7 — 기본
방침은 리포 표준(누수 = 버그)에 따라 정리한다.

---

## 10. 테스트 / 스모크 계획

신규 (`godot/tests/`, 글롭 자동 수집):

1. `stage7_akamu_state_smoke.gd` — 게이지 수급(80/90/20/오오라90/상한500), 트리거
   게이트(그림자 100·25%/구름 120·35%/표창 30/극정호신 250·초각성 전용/영체탈주
   30·40%), 분신 게이지 차감이 **시전 완료 시점 1회**인지, 초각성 3점 트리거 →
   3s 인트로 → 분신 4/표창 2, 오오라 5히트 소진→10s 재충전, intangible 3창,
   **`reset_round()` = transient 무조건 정리 + awakened 유지 + 게이지 ×0.7 이월 /
   `reset()` = 전부 초기화** 구분(§9 반증 leg 포함 — 예: 게이지 400 → 라운드
   리셋 후 280 assert).
2. `stage7_akamu_wiring_smoke.gd` — 라우터/카탈로그/deps/draw context/prewarm 정합.
3. 오오라·분신 **방향 가드 스모크**(§6-7): 보스 서브 하향공 통과 / 플레이어 상향공
   반사 양방향.
4. 구름장막 **보스 위치 정규화 스모크**(§6-6): 하강 중 라운드 리셋 → 보스 홈 밴드 복귀.
5. 표창 면역 스모크: 클렌즈 면역 시 슬로우+드레인 **동시** 차단(whole-hit).
6. 크로스컷 레그 추가: `active_item_boss_skill_cooldown_pause_smoke.gd`(stage7 leg),
   `boss_skill_card_hud_spec_smoke.gd`(커맨도 회피), shrink-scale seal.
7. 기존 assert / 하드코딩 리스트 스모크 갱신 (코덱스 리뷰 교정 — "신규 파일
   생성"만으로는 부족, 기존 스모크가 스테이지 리스트를 하드코딩 검사함):
   - `stage_runtime_deps_builder_smoke.gd` (:50 등 deps 카운트/키),
   - `stage_clear_result_runtime_context_handler_smoke.gd` (result reset 스코핑),
   - `battle_scene_stage_transition_loading_smoke.gd` (전환 로딩 seal),
   - [refactor_status_brief_smoke.gd:58](../godot/tests/refactor_status_brief_smoke.gd#L58)
     `STAGE_ROUTE_EXPECTATIONS`(현재 5·6 하드코딩)에 stage7 6-role 엔트리 추가,
   - [lingpet_rail_card_shared_smoke.gd:430](../godot/tests/lingpet_rail_card_shared_smoke.gd#L430)
     `_verify_all_stage_rails_wire_shared_helper` stages 배열에 stage7
     drawer/renderer/`stage7_akamu_boss_skill_hud_skills`/`_active` 키 추가 —
     이 계약대로 stage7 HUD 렌더러는 lingpet 카드를 공유 헬퍼로 위임해야 한다(§8).

게이트: `run_smoke_tests.ps1` + `run_warning_scan.ps1` + `run_headless_load_check.ps1`
+ Stage 7 직접 런타임 QA(테트리서 5c 게이트와 동일 수준).

---

## 11. 개발 순서 (슬라이스 제안)

1. **스캐폴딩**: 피커 8→7 재라벨, `DEMO_STAGE_SEQUENCE_END=7`, 라우터/카탈로그/deps/
   prewarm/transient(§5 #11) 배선 + 빈 모듈 7종 + wiring 스모크.
2. **손맛 코어**: 게이지 수급 + 표창(스케줄러/발사체/플레이어 슬로우·드레인/면역) +
   보스 히트 애니 트리거.
3. **분신/무적**: 그림자분신(시전/스폰/이동/공 반사/소멸) + intangible 통합 판정 +
   방향 가드.
4. **기동기**: 구름장막(중앙 스냅/하강/폭발/상승/무적/위치 정규화) + 영체탈주
   (스턴·그물 카운터/홀로그램/잔상).
5. **초각성/궁극기**: 3점 트리거 + 프리즈 인트로 + 바람 오오라(반사/내구/재충전/
   즉발 트리거) + 극정호신(예측 대시/잔상/파티클/쿨다운).
6. **마감**: 보스 스킬 카드 HUD + 오디오(BGM ogg + SFX 7종) + 보스 스프라이트
   (§12-1 결정 후) + result 플로우(§5-18) + 로딩 화면 + 전체 스모크/QA 게이트.
7. **후속(별도)**: 신규 필러/필드 아트 landing, 인트로 비디오/대화 연출(§12-4/5).

---

## 12. 결정 필요 항목 (구현 착수 전 확인)

1. **보스 스프라이트 소스**: (a) 원본 시트 재사용(271×518, hit 은 stage9 차용 +
   idle/stun 부재 — bespoke 매핑 필요) vs (b) AutoSprite 7종 신규 생성(stage6 컨벤션
   정합, 리포 표준). **권장: (b)** — 원본은 아이덴티티 앵커/QA 비교용으로 보존.
2. **prefix 확정**: `stage7_akamu_*`(본 문서 표준) vs `stage7_akamu_rigo_*`.
3. **극정호신 밸런스**: 원본은 10초간 사실상 완봉(예측 대시 무경직·무료 긴급대시).
   원본 충실이 기본값이나, 체감 과잉 시 밸런스 변경은 **명시 기록** 후 조정(테트리서
   §2.4 벽 좌표와 동일 원칙 — 임의 재결정 금지).
4. **인트로 비디오** `stage8.mp4` 포팅 여부(스테이지 공통 정책 미결, 테트리서와 공통 결정).
5. **전투 전 JRPG 대화**(초상화 2종 + 3줄) — Godot 대화 시스템 부재. 컷인/배너로
   대체할지, 스토리 연출 백로그로 미룰지.
6. **HUD 카드 구성**: 카드 4장(게이지+그림자/표창/구름/극정호신) + 오오라 본체
   오버레이 권장안 승인.
7. **라운드 간 transient 정리**: 원본은 분신/표창이 라운드를 넘어 잔존(§9 — 리셋
   경로 부재로 버그로 판정). 기본 방침 = 무조건 정리. 원본 잔존을 "사양"으로 보존할
   지만 확인.
8. **연막/클렌즈 면역 키 매핑**: 연막탄·테크니컬조끼 Godot 포팅 여부 확인 후 표창
   면역 컨텍스트 키 확정(미포팅이면 키 예약 + dormant).

---

## 13. 권한/참조 우선순위

- 런타임 통합/성능: `AGENTS.md`.
- 모듈 경계/소유권: `docs/godot_module_ownership_ledger.md`, `docs/godot_port_architecture.md`.
- 스테이지 번호 정책/트랩 스텁: `CLAUDE.md` (풀텍스트 `docs/godot_runtime_traps.md`).
- 선례: `docs/stage6_tetriser_port_plan.md` (구조/게이트/슬라이스 기준).
- 원본 1차 소스: `pingfighter.py` 상수 블록 [63402-63521](../pingfighter.py#L63402) +
  스킬 함수군(`_spawn_stage8_*` / `update_stage8_*` / `check_wind_aura_ball_collision`) +
  `handle_boss` 프롤로그 + `entities/stage8_boss_sprite.py` +
  [config/stage_configs.py:130](../config/stage_configs.py#L130).
  (테트리서의 `game_logic/stage7_tetriser.py` 같은 순수 불변식 모듈은 stage8 에
  **없음** — 전부 pingfighter.py 하드코딩.)
