# 퐁크 각성 스킬 「몽환포영 (夢幻泡影)」 — Slice Plan

**Status:** DESIGN — ready for wiring. Owner split: **사용자/Codex 배선 → Claude 적대리뷰**
(per [[feedback_design_slice_review_division]]). This doc is the SSOT; do not
re-derive rules from memory.

**Concept:** Stage 4 퐁크(가부좌 수도승)가 플레이어 4점 도달 시 **각성**하며 세
번째 스킬이 해금된다. 발동하면 **화면 전체가 4초 동안 물결처럼 일렁이며**
플레이어의 시야를 방해한다 (금강경 "一切有爲法 如夢幻泡影" — 각성한 수도승이
세상을 幻으로 되돌린다). 쿨타임 70초. **순수 렌더 왜곡 — 공/패들 물리 불변.**

**Golden templates:**
- 각성(점수 임계) 트리거 → `stage3_boss_skill_state.gd`
  `_maybe_start_kuromi_awakening()` (score-event 경로).
- 풀스크린 screen-read 셰이더 호스트 → `godot/scripts/effects/defeat_continue_color_restore_fx_host.gd`
  (repo 유일의 BackBufferCopy + `hint_screen_texture` 사례) + 그 스모크
  `godot/tests/defeat_continue_color_restore_fx_host_smoke.gd`.
- 스킬 #3 골격 → `stage4_ponk_skill_state.gd`의 meditation/magnetic 멤버·카드·리셋 패턴.

---

## 0. Decisions locked (2026-07-03, user)

| Question | Decision |
|---|---|
| 스킬명 | **몽환포영 (夢幻泡影)** — display name. 코드 id는 `illusion_ripple` (형제 id가 mechanic-English: `magnetic_field`/`meditation`/`sand_prison`) |
| 각성 트리거 | 매치 누적 **플레이어 4점** 도달 시 **1회 영구 각성** (매치 내) |
| ~~각성 순간~~ | ~~몽환포영 즉시 1회 발동~~ → **R1에서 폐기** (라이브 QA: 실점 순간 조기발동) |
| **R1 각성 연출 (2026-07-04)** | 4점째 라운드에서는 발동 없음. **다음 라운드 시작부터 보스 주변 강렬한 각성 오오라** + 스킬 카드 해금. **서브 발사 후 `ILLUSION_FIRST_CAST_DELAY_FRAMES`(3.0s) 뒤 첫 시전** |
| 이후 발동 | **70초 쿨 자동 재발동** — 굴절 자기장과 같은 auto 방식 (변경 없음) |
| **R2 비주얼 강화 (2026-07-04)** | (a) **각성 버스트**: 첫 stage 2→3 전이(서브 발사, 매치 1회)에 신성한 기운 폭발 VFX 1.5s — §1.5b. (b) **사이키델릭 컬러**: 물결 셰이더에 hue 회전 파동 + RGB 분리 + 채도 호흡 — §1.6. 광과민 안전선: 스트로브 금지, 색/채도 순환 ≤ ~1Hz |
| 지속시간 | 4초 (`240.0` frames, 60-basis, `fps_scale` 감산) |
| 물리 영향 | **없음.** 렌더 레이어 왜곡만. 공/패들/충돌 코드 무접촉 |
| 강도 | 공 궤적 추적이 실제로 어려운 수준, 단 강도/주기는 라이브 튜닝 uniform으로 분리 |
| 게이지 결합 | **없음.** `boss_special_gauge`를 소모/요구하지 않는 쿨타임 단독 스킬 |
| 분담 | 이 문서+스모크 설계=Claude, GDScript 배선=사용자, 적대리뷰=Claude |

---

## 1. Gameplay spec

### Constants (`stage4_ponk_skill_state.gd`에 추가)

```gdscript
const ILLUSION_SKILL_ID := "illusion_ripple"          # display: 몽환포영
const ILLUSION_UNLOCK_PLAYER_SCORE := 4
const ILLUSION_DURATION_FRAMES := 240.0               # 4.0s @ 60-basis
const ILLUSION_COOLDOWN_SEC := 70.0                   # wall-clock seconds
const ILLUSION_FIRST_CAST_DELAY_FRAMES := 180.0       # R1: 서브 후 3.0s 뒤 첫 시전 (튜닝 레버)
```

### State members (R1 개정: pending bool → 각성 스테이지 머신)

```gdscript
var illusion_unlocked := false               # 각성 여부 (매치 내 영구)
var illusion_awaken_stage := 0               # R1 상태머신 (아래) — 매치 내 영구 진행
var illusion_first_cast_delay_frames := 0.0  # stage 3에서 180 → 0 감산
var illusion_active := false
var illusion_timer_frames := 0.0
var illusion_cooldown_seconds := 0.0
```

`illusion_pending_cast`(bool)는 R1에서 **폐기**하고 `illusion_awaken_stage`(int)로
대체한다:

| stage | 의미 | 전이 조건 (update() 안에서 관측) |
|---|---|---|
| 0 | 미각성 | score-event에서 4점 unlock → **1** |
| 1 | 각성 직후 — **서브 페이즈 관측 대기** | `_is_serve_waiting(context) == true` 관측 → **2** (실점 직후의 라이브 잔여 프레임에서는 절대 소비되지 않음 — §4 트랩 3b) |
| 2 | 다음 라운드 서브 대기 (오오라 ON) | `_is_serve_waiting(context) == false` (서브 발사, 볼 라이브) → **3**, `delay = ILLUSION_FIRST_CAST_DELAY_FRAMES` |
| 3 | 시전 카운트다운 (오오라 빌드업) | `delay -= fps_scale` (freeze/serve 중 정지). `delay <= 0` → `_activate_illusion()` → **4**. 단 stage 3 중 다시 `_is_serve_waiting == true`가 되면(카운트다운 중 라운드 종료) → **2**로 복귀, delay 재시작 |
| 4 | 첫 시전 완료 — 이후 70초 auto 재발동 루프 | 종단 상태 (reset()류만 0으로 되돌림) |

- stage 1→2 관측은 scoreboard 모달 중에도 동작한다: scoreboard pause 브랜치는
  `update_effects`를 계속 돌리므로(모달-블록 트랩 문서) ponk `update()`가
  `scoreboard_active=true` 컨텍스트를 보게 되고, `_is_serve_waiting`이 true가 된다.
- 라운드 경계 순서(score-event vs reset_round)에 여전히 무관: 전이가 전부
  update()의 **컨텍스트 관측**으로만 일어나고, `reset_round()`는 stage를 건드리지
  않는다 (아래 reset matrix).

### Timeline (R1)

1. **Unlock:** 플레이어 득점 이벤트에서 `player_score >= 4` →
   `illusion_unlocked = true`, `illusion_awaken_stage = 1`. (update() 컨텍스트의
   `player_score`가 아니라 **score-event 경로** — §4 트랩 1.) **이 라운드(실점
   연출)에서는 아무것도 발동하지 않는다.**
2. **다음 라운드 시작:** stage 1→2 전이 시점부터 보스 각성 오오라 ON (§1.5).
   HUD 카드도 이 시점부터 locked→해금 상태로 노출.
3. **서브 발사 후 3초:** stage 2→3 전이(볼 라이브)에서 delay 카운트다운 시작,
   오오라가 점점 강해지다가(빌드업) `_activate_illusion()`: `active=true`,
   `timer=240`, `cooldown=70`, FX host on.
4. **지속:** `timer_frames -= fps_scale`. 만료 시 `active=false`, FX host off.
5. **자동 재발동:** `_update_skill_cooldowns()`에서 70초 감산(기존 freeze/pause
   게이트 안에서) → `stage == 4 and cooldown <= 0 and not active and not
   _is_serve_waiting` 시 재발동. 게이지 조건은 제외 (D: 게이지 비결합).

### §1.5 각성 오오라 (R1 신규 — actor renderer)

`stage4_ponk_boss_actor_renderer.gd`에 절차적 오오라 패스를 추가한다 (형제 패턴:
meditation이 bob/chi-orbit을 증폭하는 방식과 동일 계열, 이미지 에셋 불필요):

- **읽는 키** (`get_actor_draw_context()`에 이미 노출/추가):
  `stage4_illusion_unlocked`, `stage4_illusion_awaken_stage`,
  `stage4_illusion_first_cast_delay`, `stage4_illusion_active`.
- **상시 각성 오오라** (`awaken_stage >= 2`): 보스 중심 뒤에 몽환 보라
  `Color(0.62, 0.45, 0.85)` 계열 펄스 글로우 링 2~3겹 + 기존 `_draw_chi_orbit`
  반경/알파 증폭(각성 배율). `frame_clock` 기반 sin 펄스, draw_arc/draw_circle
  소량 — 프레임 예산 무해 수준 유지.
- **빌드업** (`awaken_stage == 3`): 강도 = `1.0 - delay/180.0`로 램프 — 서브 후
  오오라가 점점 강렬해지다 시전 순간 피크.
- **시전 플레어** (`illusion_active`): 피크 강도 유지 + 링 회전 가속.
- 채도/레이어를 늘릴 때 파티클 수×수명×레이어 동시 증가 금지 (성능 §; 절차
  글로우는 캐시 불필요한 소량 arc 수준으로).
- **R2 상시 오오라 강화:** stage 2 강도 0.32 → **0.42**, stage 4 상시 0.48 →
  **0.55**. 각성 상태(stage ≥ 2)에 **회전 광선 크라운** 추가: 6줄기 얇은 방사
  광선(draw_line 또는 2px 폴리곤), 길이 `base_radius*1.05 ~ 1.45` 사이 sin 펄스,
  느린 회전(`t*0.3`), 알파 `0.10 + 0.14*flare`, 색 = ILLUSION_AURA_CORE→GOLD lerp.

### §1.5b 각성 버스트 (R2 신규 — "신성한 기운 폭발")

**트리거:** 첫 stage 2→3 전이(서브 발사로 볼 라이브, 각성 리빌 순간). **매치 1회**
— `illusion_awaken_burst_played` 플래그로 재생 1회 고정 (3→2→3 바운스에 재생 금지).

**State (skill state 추가):**
```gdscript
const ILLUSION_AWAKEN_BURST_FRAMES := 90.0     # 1.5s
var illusion_awaken_burst_frames := 0.0        # 재생 중 카운트다운
var illusion_awaken_burst_played := false      # 매치 1회 플래그
```
- 첫 2→3 전이에서 `burst_frames = 90`, `burst_played = true`. update()에서
  `fps_scale` 감산 (timing-frozen 게이트 안).
- draw context 키: `stage4_illusion_awaken_burst`,
  `stage4_illusion_awaken_burst_total`.
- Reset matrix: `reset()`/`reset_for_result()` → 둘 다 클리어.
  `reset_round()` → `burst_frames`만 0 (연출 중단), **`burst_played`는 유지**.

**렌더 레시피 (actor renderer 신규 패스 `_draw_illusion_awaken_burst`, 절차적 —
파티클 노드/이미지 에셋 불필요. 모든 랜덤은 인덱스-시드 결정론적 해시, 흔들리는
pos 시딩 금지 — VFX stable-seed 규칙):**

`elapsed = (90 - burst_frames) / 60.0` (0 ~ 1.5s) 기준:
- **플래시 코어** (t < 0.35s): 백금-보라 `Color(0.97, 0.90, 1.0)` draw_circle,
  radius `lerp(40, 140, ease_out)`, alpha `0.85 * (1 - t/0.35)^1.5`.
- **충격파 링 3겹**: `ring_t = clamp((elapsed - i*0.12) / 0.7)`, radius
  `lerp(24, 210, 1-(1-ring_t)^2)`, width `lerp(6, 1.5)`, alpha `(1-ring_t)*0.65`,
  색 ILLUSION_AURA→GOLD를 i로 lerp.
- **신성 광선 10줄기**: angle `i*TAU/10 + elapsed*0.4`, length
  `(90 + 70*sin(elapsed*3+i)^2) * (1 - elapsed/1.5)`, alpha `(1-elapsed/1.5)*0.5`,
  색 gold-white → violet lerp.
- **상승 모트 14개**: `pos = center + (hash01(i)*80-40, -elapsed*(30+hash01(i*7)*40))`,
  radius 2~4px, alpha `(1-elapsed/1.5)*0.7`. 시드는 **인덱스만** 사용.
- 프리미티브 총 ~30개/프레임 × 1.5s — 예산 무해. 셰이크/히트스톱은 이번 슬라이스
  제외 (원하면 후속에서 기존 셰이크 채널로).

### §1.6 사이키델릭 컬러 셰이더 (R2 — ripple FX host 확장)

기존 UV 왜곡 위에 3단 컬러 레이어 추가. 전부 `strength` 엔벨로프에 종속(4초
ease-in/out 동승). **새 uniform + 기본값 (전부 host DEFAULT_* 상수 + 컨텍스트
오버라이드 키 `stage4_illusion_hue_amp` 등 — 라이브 튜닝 레버):**

| uniform | 기본 | 의미 |
|---|---|---|
| `hue_wave_amp` | 0.9 (rad ≈ 51°) | hue 회전 최대각 |
| `hue_wave_freq` | 5.0 | hue 파동 공간 주파수 |
| `hue_time_speed` | 0.9 | hue 파동 시간 속도 (≤ ~1Hz 체감) |
| `chroma_offset_px` | 3.5 | RGB 분리 오프셋 (view_size_px 정규화) |
| `saturation_boost` | 0.25 | 채도 호흡 진폭 (sin t*0.8) |

**fragment 골격 (기존 px_offset 계산 이후):**
```glsl
vec2 base_uv = uv + px_offset / max(view_size_px, vec2(1.0));
// 1) chromatic aberration — 파동 방향으로 R/B 분리
vec2 ca = normalize(px_offset + vec2(1e-4)) * (chroma_offset_px * strength)
          / max(view_size_px, vec2(1.0));
float r = texture(screen_tex, clamp(base_uv + ca, vec2(0.0), vec2(1.0))).r;
vec4 gs = texture(screen_tex, clamp(base_uv, vec2(0.0), vec2(1.0)));
float b = texture(screen_tex, clamp(base_uv - ca, vec2(0.0), vec2(1.0))).b;
vec3 col = vec3(r, gs.g, b);
// 2) 공간-시간 hue 회전 파동 (무지개 패치가 흐름)
float hue = hue_wave_amp * strength
    * sin(uv.x * hue_wave_freq + t * hue_time_speed)
    * cos(uv.y * hue_wave_freq * 0.8 - t * hue_time_speed * 0.7);
const vec3 k = vec3(0.57735);
float ch = cos(hue); float sh = sin(hue);
col = col * ch + cross(k, col) * sh + k * dot(k, col) * (1.0 - ch);  // grey축 Rodrigues 회전
// 3) 채도 호흡
float sat = 1.0 + saturation_boost * strength * (0.5 + 0.5 * sin(t * 0.8));
vec3 grey = vec3(dot(col, vec3(0.299, 0.587, 0.114)));
col = grey + (col - grey) * sat;
COLOR = vec4(col, gs.a);
```
- 텍스처 샘플 1→3회: 4초 창 한정 풀스크린 3샘플 — 예산 허용.
- **안전 가드 (하드 규칙):** 스트로브성 휘도 플래시 금지. `hue_time_speed`,
  채도 sin 주기를 ~1Hz 이하로 유지. 튜닝으로 올리더라도 3Hz 초과 금지.
- 프리웜: 셰이더 코드가 바뀌므로 PSO 프리웜은 기존 등록으로 자동 커버(동일 host
  인스턴스). 프리웜 sync dict에 새 uniform 키를 넣을 필요는 없음(uniform 값은
  PSO 불변) — 단 프리웜 스모크의 소스-grep 단언이 깨지지 않는지 확인.
5. **HUD:** 3번째 스킬 카드. unlock 전 `status="locked"` + trigger 문구
   "플레이어 4점 시 각성". unlock 후 charging/ready/casting (형제 카드 필드 계약
   그대로: `id/name/short_label/trigger/trigger_type/status/ready/active/progress/
   remaining/total/cooldown_*/duration_*/color/description`). Fallback 카드 색:
   몽환 보라 계열 `Color(0.62, 0.45, 0.85)` (아트는 S4).

### Reset matrix (⚠️ 핵심 계약)

| Path | `unlocked` | `awaken_stage` / `delay` | `active`/`timer` | `cooldown` | FX host |
|---|---|---|---|---|---|
| `reset()` (풀 리셋, match_reset) | **clear** | 0 / 0 | clear | clear | stop |
| `reset_round()` (라운드 경계) | **KEEP** | **KEEP** (stage 유지; stage 3 복귀는 update()의 serve 관측이 담당) | clear | keep | stop |
| `reset_for_result()` (**신설**, S3) | clear | 0 / 0 | clear | clear | stop |

- `reset_round()`가 unlocked를 지우면 "1회 영구 각성"이 깨진다.
- `reset_round()`가 awaken_stage를 지우면 **각성 진행이 자기 탄생 경계에서 즉사**
  한다 (4점째 득점 = 라운드 경계 = reset_round 발화 시점과 동일 프레임 계열).
  §4 트랩 3. stage 3→2 복귀도 reset_round가 아니라 update()의 serve 관측으로만
  일어나야 순서-무관이 유지된다.

---

## 2. Architecture map (실측 2026-07-03; line은 드리프트 가능 — 심볼로 앵커)

| Hook | File : anchor |
|---|---|
| 스킬 상태 본체 (스킬 #3 추가 위치) | `godot/scripts/stages/stage4/stage4_ponk_skill_state.gd` — 멤버 ~L51-96, `update()` L230, `_update_skill_cooldowns()` L595, `_can_auto_activate_magnetic` L601, `reset()` L166, `reset_round()` L204 |
| 쿨 freeze/pause 게이트 | 같은 파일 `_is_timing_frozen` L1197 (`stopwatch_freeze_active`/`perk_resume_freeze_active`), `_is_boss_skill_cooldown_paused` L1201 (`active_item_boss_skill_cooldown_paused`/tear gas) — **기존 게이트 랩 안에 illusion 쿨 감산을 넣기만 하면 자동 준수** |
| HUD 카드 배열 | 같은 파일 `get_skill_card_hud_context()` L422 — `_build_illusion_skill_card()` append. HUD 렌더러는 **무수정으로 3번째 카드 렌더** (locked 지원: `stage4_ponk_boss_skill_hud_renderer.gd` L145) |
| draw-context 키 | `get_actor_draw_context()` L432 — `stage4_illusion_active` 등 노출 (+ `stage4_ponk_awakened` — S4 액터 연출용) |
| 점수 이벤트 배선 | `godot/scripts/core/match_score_event_controller.gd` — stage3 디스패치 ~L417-418, stage4_map_state ~L424-426. **권장: `stage4_map_state.handle_score_event` (L60)가 deps로 이미 들고 있는 ponk state에 forward** (컨트롤러 신규 배선 불필요) |
| ponk update 구동처 | `stage4_map_state.gd` L40-41 (`ponk_skill_state.update(delta, event_context, deps)`) |
| 라운드 경계 리셋 콜사이트 | `ball_round_actor_cleanup.gd` L100-102, `match_score_event_controller._clear_stage4_round_boundary_fx()` L439-444 |
| 풀 리셋 콜사이트 | `match_reset_controller.gd` reset 리스트 L198 (`stage4_ponk_skill_state`) |
| result 클린업 (**갭**, S3) | `stage_clear_result_runtime_context_handler.gd` `reset_stage_for_result()` L55-57 — 현재 **stage5/6만**. `_reset_stage4_for_result` 신설 |
| FX host 프리웜 체인 | `stage4_ponk_skill_state.gd` `prewarm_assets_step()` L113-134, `prewarm_runtime_hosts_step(canvas)` L142, `_get_or_create_*_fx_host` L931/L1019 패턴 (`call_deferred("add_child")`) |
| screen-read PSO 프리웜 | `battle_pso_prewarmer.gd` L23 부근 — color-restore screen-read 경로 옆에 ripple 셰이더 추가 |
| 스킬 카드 아트 lookup | `stage4_ponk_boss_skill_hud_renderer.gd` `_get_skill_texture_paths` L207 (S4; 없으면 fallback gauge) |

**모듈 카탈로그 신규 등록 불필요** — 스킬 #3은 기존 `stage4_ponk_skill_state`
내부이고, FX host는 state가 직접 preload/생성한다 (magnetic/meditation 동일).

---

## 3. Slices

### S0 — State backbone + 각성 게이트 + HUD 카드
- 상수/멤버(§1) 추가. `handle_score_event(scoring_side, score_result, deps)` 신설:
  `int(score_result.get("player_score", 0)) >= ILLUSION_UNLOCK_PLAYER_SCORE` →
  unlock + pending. (kuromi `_maybe_start_kuromi_awakening` idiom.)
- `stage4_map_state.handle_score_event`에서 ponk state로 forward.
- `_build_illusion_skill_card()` + `get_skill_card_hud_context()` append +
  `get_actor_draw_context()` 키.
- `reset()` / `reset_round()` — **reset matrix(§1) 그대로.**
- Smokes: #1, #2, #6, #8 (§5).

### S1 — 발동/지속/쿨/자동 재발동
- `_activate_illusion()` (pending 소비 경로 + auto-refire 경로 공용).
- `update()` 안: pending 소비 → 발동; active tick(`fps_scale` 감산) → 만료.
- `_update_skill_cooldowns()`에 illusion 쿨 감산 추가 (기존 게이트 랩 내부).
- auto-refire: `_can_auto_activate_magnetic()` 게이트 미러 (게이지 조건 제외).
- Smokes: #3, #4.

### S2 — 풀스크린 리플 FX host + 셰이더 + 프리웜
- 신규 `godot/scripts/stages/stage4/stage4_ponk_illusion_ripple_fx_host.gd`,
  `defeat_continue_color_restore_fx_host.gd`를 골격 복사:
  - Node2D + BackBufferCopy(`COPY_MODE_VIEWPORT`) + ColorRect(view_size) +
    ShaderMaterial. `z_as_relative=false`, `const Z_INDEX := 1272`
    (플레이필드 크롬 위, defeat color-restore 1280 아래 — 문서화된 임의값).
  - `sync_state(state, enabled)` + `ACTIVE_SYNC_GRACE_MSEC` 자동 타임아웃 유지
    (**모달 self-heal** — §4 트랩 4).
  - `static build_pipeline_status()` (uses_screen_texture / back_buffer_copy /
    z_index 보고) — 스모크 #7이 이걸 봉인.
  - static material template + duplicate per-instance (`_get_material_template`).
- 셰이더 (인라인 `_shader_code()`, color-restore 방식):
  ```glsl
  uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
  uniform float strength;        // 0..1 — host가 per-frame sync (엔벨로프)
  uniform float intensity_px;    // 피크 왜곡 px (기본 12.0, 라이브 튜닝 레버)
  uniform float wave_freq_a;     // 기본 9.0
  uniform float wave_freq_b;     // 기본 17.0  (두 주파수 합성으로 '물결이 막 침')
  uniform float wave_speed;      // 기본 2.2
  // offset = (sin(uv.y*fa + T*s) + 0.6*sin(uv.x*fb - T*s*1.3), ...) 2축 합성
  // * intensity_px / viewport_px * strength → SCREEN_UV에 가산 후 샘플
  ```
  - 엔벨로프는 **host가 계산**해 `strength`로 주입: ease-in 0.4s → full →
    ease-out 0.6s (4초 창 내). 셰이더는 stateless 유지.
  - (선택, S4) 미세 chromatic offset — 몽환감. 기본은 순수 UV 왜곡.
- state 통합: preload const + `prewarm_assets_step()` 체인 +
  `prewarm_runtime_hosts_step()` + `_get_or_create_illusion_fx_host()` +
  `draw()`에서 `sync_state({strength, view_size_px, ...}, illusion_active)`.
- `battle_pso_prewarmer.gd`에 screen-read 셰이더 등록 (**첫 발동 히치 방지** —
  §4 트랩 5).
- Smokes: #7 + **픽셀 QA 필수** (§6).

### S2b — R1 개정: 상태머신 전환 + 각성 오오라 (2026-07-04 신규)
- `illusion_pending_cast` → `illusion_awaken_stage` 상태머신 전환 (§1 표).
  `_can_activate_illusion`의 pending 소비 경로 제거, stage 전이 로직으로 대체.
- `get_actor_draw_context()`에 `stage4_illusion_awaken_stage`,
  `stage4_illusion_first_cast_delay` 키 추가 (`stage4_illusion_pending_cast` 제거).
- `stage4_ponk_boss_actor_renderer.gd` 각성 오오라 패스 (§1.5): 상시 오오라 /
  빌드업 램프 / 시전 플레어.
- reset matrix R1 갱신 (stage 보존/클리어).
- Smokes: #1 보강, #2 재작성, #2b 신규 (§5). 오오라는 **픽셀 QA** (상태 스모크로
  가시성 증명 불가 — 트랩 7과 동일 계열).

### S2c — R2 비주얼 강화: 각성 버스트 + 사이키델릭 컬러 (2026-07-04 신규)
- skill state: `ILLUSION_AWAKEN_BURST_FRAMES`/`burst_frames`/`burst_played` +
  첫 2→3 전이 arm + tick + draw 키 + reset matrix (§1.5b).
- actor renderer: `_draw_illusion_awaken_burst` 패스 (§1.5b 레시피) + 상시 오오라
  강화 상수(0.42/0.55) + 광선 크라운 (§1.5 R2 항목).
- ripple FX host: §1.6 uniform 5종 + fragment 3단 컬러 레이어 + 컨텍스트
  오버라이드 키. 기존 `_calculate_envelope_strength`/sync 계약 불변.
- Smokes: #2c 신규 + #7 확장 (§5). 버스트/컬러 모두 **픽셀 QA 필수**.

### S2d — 오오라 3-피스 모듈러 승격 (2026-07-04 신규, 사용자 지시 "원형 선뿐이라 단순")

절차 arc 오오라를 리포 표준 **3-피스 모듈러 VFX**(정적 텍스처 + 셰이더 + 파티클 +
Tween)로 승격한다. 기존 절차 패스는 **텍스처 로드 실패 폴백**으로 강등 (PNG-first).

**에셋 (✅ Claude 생성·배치 완료 2026-07-04, Gemini still — 허용 경로):**

| Piece | Path (`res://assets/sprites/stage4/effects/`) | 크기 | QA |
|---|---|---|---|
| ① 백플레이트 — 법륜 만다라 성운 (연꽃 코어+스포크+골드 필리그리) | `stage4_ponk_awaken_aura_backplate_imagegen_v1.png` | 512² | 코너 0 / bbox (16,15,495,498) 비접촉 |
| ② 파티클 모트 — 연꽃잎 광채 (골드 글린트 팁) | `stage4_ponk_awaken_aura_mote_imagegen_v1.png` | 256² | 코너 0 / bbox 비접촉 |
| ③ 호 리본 — 초승달 광호 (보라→골드, 페더 테일) | `stage4_ponk_awaken_aura_arc_imagegen_v1.png` | 512² | 코너 0 / bbox 비접촉 |

셋 다 순흑 배경 생성 → **휘도(max-channel)→알파 베이크 + 라디얼 마스크 + noise
floor 7 컷** (포털 컷인과 동일 파이프라인). **전부 빛 = ADD 블렌드** — 실체(MIX)
피스 없음이 의도.

**신규 FX host — `stage4_ponk_awaken_aura_fx_host.gd`** (magnetic FX host 골격
미러: preload const / prewarm_assets_step 체인 **4번째** / prewarm_runtime_hosts_step
**4번째** / `_get_or_create_awaken_aura_fx_host` / state draw()에서 sync). z/좌표
배치는 **magnetic FX host의 기존 관행을 그대로 미러** — 자체 z 발명 금지.

| 레이어 | 노드 | 모션 (엔진) | 셰이더 |
|---|---|---|---|
| 백플레이트 | Sprite2D, ADD | 노드 rotation 느린 회전(+0.10 rad/s) + Tween/sin 호흡 스케일 | **`mythic_writhe.gdshader` 재사용** — uniform만: `cool_color`=ILLUSION_AURA, `hot_color`=CORE(0.94,0.74,1.0), `ember_color`=GOLD, `distort_strength` 0.006(만다라 문양 보존 low), `breath_amp` 0.12, **`core_dim_strength` 0.55 / `core_dim_radius` 0.30** — 중앙 컷아웃으로 보스 얼굴 겹침 방지 |
| 호 리본 ×2~3 | Sprite2D, ADD | 노드 rotation 각기 다른 속도/방향 (+0.55 / −0.38 / +0.24 rad/s), 스케일 0.85/1.0/1.15 | `mythic_arc_flow.gdshader` 재사용, 같은 3색 uniform |
| 모트 | GPUParticles2D, ADD | ring emission(반경 ~70), 상승 드리프트, scale/alpha 커브 페이드 | — |
| 엔벨로프 | Tween | 개시 0.5s(스케일 0.7→1.0 오버슈트+페이드인) / 종료 0.4s 페이드아웃; phase intensity는 per-frame lerp 스무딩 | — |

**강도 매핑 (intensity 소스 = 기존 `_get_illusion_awaken_aura_intensity` 값 재사용):**

| intensity | 백플레이트 α/scale | 아크 | 모트 rate |
|---|---|---|---|
| 0.42 (stage 2) | 0.35 / 0.92 | 2개 | ~6/s |
| 0.34→1.0 (stage 3 빌드업) | ramp | 속도 +ramp | ramp→14/s |
| 1.0 (casting 플레어) | 0.80 / 1.12 | 3개 활성 | ~18/s |
| 0.55 (stage 4 상시) | 0.45 / 1.0 | 2개 | ~8/s |

**Enraged 별도 튜닝 테이블**: `hot_color`→적색 lerp 0.35 + 회전/flow 속도 +15%
(색만 바꾸고 구조 재사용 — writhing-ember 방법론 그대로).

**회귀 가드 (배선 전 필독):**
- `draw_set_transform`+IDENTITY 리셋 금지 — 회전은 전부 **노드 rotation**,
  셰이더는 material set/restore 1패스 (연속회전 텀블 함정 포함: 10초+ 방치 QA).
- FX host가 외부 캔버스 자식이면 world-pos =
  `game_offset + (playfield_pos+shake)*render_scale` — magnetic host의 기존 좌표
  헬퍼 미러.
- 평면 스프라이트에 3D 라이팅 흉내 금지 — ADD 글로우 레이어까지만.
- **texture spec/loader 동기화 함정**: 새 텍스처 3장을 프리웜 리스트에 안 태우면
  런타임 null. state prewarm 체인 + 부트 리소스 프리웜 + (ADD 머티리얼/파티클)
  PSO 프리웜 등록까지 한 세트.
- 절차 폴백 강등 후에도 `_draw_illusion_awaken_aura`는 로드 실패 시 살아있어야
  함 (file_exists/텍스처 null 분기).
- 비헤드리스 QA 실행이 신규 PNG의 `.import`를 실체화함 — 첫 실행 전 스모크가
  텍스처 로드를 단언하면 import 순서에 유의.

**S2d 리뷰 각주 (2026-07-04):** ① enraged 플래그는 draw 컨텍스트에 없다 —
`_is_enraged`를 draw 경로에서 라이브로 읽으면 영원히 false (Two-Update-Path 트랩).
마그네틱 패턴대로 update()에서 `illusion_aura_enraged` per-tick 캡처 →
`stage4_illusion_aura_enraged` draw 키 → fx context가 그 키를 읽을 것.
② intensity 커브가 state와 renderer 폴백에 이중 존재 — 튜닝 시 양쪽 동기.
③ 종료 페이드아웃(0.4s)은 즉시-숨김으로 배선됨 — 라이브 QA에서 뚝 꺼짐 거슬리면 복원.

**Smokes (S2d):**
| # | Test | Asserts | 반증 |
|---|---|---|---|
| 9 | awaken aura fx host 구조 | prewarm 체인 4단계 완주, 텍스처 3장 로드 상태 키, 백플레이트/아크 Sprite2D + GPUParticles2D 존재, ADD 블렌드, intensity sync에 α/rate 반응, inactive 시 hidden+emitting off | 텍스처 경로 오타 토글 → 폴백 분기 검증 |
| 10 | 픽셀 QA (non-headless, 필수) | intensity 0 vs 0.55 vs 1.0 캡처 delta + 절차 폴백 대비 시각 확인 | — |

### S3 — result 클린업 봉인 (표준 트랩 백필)
- state에 `reset_for_result()` 신설 (reset matrix 마지막 행).
- `stage_clear_result_runtime_context_handler.gd`:
  `_reset_stage4_for_result(registry, stage_id)` 신설 + `reset_stage_for_result()`
  에서 호출 (stage5/6 미러).
- Smoke: #5.

### S4 — Polish (별도 승인 후)
- 스킬 카드 아트 (`_get_skill_texture_paths`에 id 등록).
- 발동 SFX — **one-shot 권장** (`ponkmeditation.wav` 형제 톤). 루프 SFX로 갈 경우
  `gameplay_loop_audio_cleanup.gd` `STOP_METHODS` 등록 필수 (모달-블록 루프오디오
  트랩).
- 액터 각성 연출: `stage4_ponk_boss_actor_renderer`가 `stage4_ponk_awakened`
  읽어 chi-orbit/bob 증폭 (meditation 증폭 패턴 미러).
- 강도/주기 라이브 튜닝 (`intensity_px`/`wave_freq_*`/`wave_speed`).

---

## 4. Traps (배선 전 필독)

1. **`player_score`가 퐁크 update() 컨텍스트에 없다.**
   `battle_effects_update_controller._merge_score_context()`는 stage2/3/5/6에만
   호출되고 stage4는 빠져 있다. `context.get("player_score")`는 항상 0.
   → **score-event 경로로만 트리거** (kuromi 패턴). update()에서 점수를 읽는
   구현은 조용히 영원-잠금(never unlock)이 된다.
2. **result 화면 클린업 갭.** `reset_stage_for_result()`는 stage5/6만 처리한다.
   S3 없이는 각성 물결이 켜진 채 매치가 끝나면 **풀스크린 왜곡이 결과 화면까지
   샌다** ("show_result에도 리셋" 표준 트랩의 stage4 인스턴스).
3. **각성 발동 vs 라운드 경계 클리어 순서 경합.** 4점째 득점 = score event =
   `reset_round()` 콜사이트들과 같은 경계. `handle_score_event`에서 즉시
   `illusion_active=true`로 켜면 직후 boundary FX clear가 물결을 지울 수 있다
   (디스패치 순서는 보장 없음). → **관측-기반 defer가 유일한 순서-무관 설계**:
   handle_score_event는 unlock+stage=1만 세팅, 전이는 전부 update()의 컨텍스트
   관측. `reset_round()`는 stage를 **보존**해야 한다 (reset matrix).
3b. **실점 직후 라이브 윈도우 조기발동 (라이브 QA 실증, 2026-07-04).** 실점
   순간부터 scoreboard/serve 플래그가 켜지기까지 몇 프레임은
   `_is_serve_waiting()`이 false다 — pending 소비 게이트가 serve-waiting 하나뿐인
   초판 배선은 이 창에서 즉시 발동해 "보스가 실점하자마자 물결"이 됐다.
   `not _is_serve_waiting`은 "볼이 라이브다"의 증거로 쓰면 안 되고, **서브 페이즈
   진입(true)을 한 번 관측한 뒤의 false 전이**만 새 라운드의 라이브 증거다.
   R1 상태머신 stage 1→2→3이 그 봉인이다. 회귀 스모크는 반드시 "unlock 직후
   라이브 컨텍스트 update → 발동 금지"를 직접 재현할 것 (§5 #2).
   *잔여 엣지 (S2b 리뷰, 보류 결정):* 카운트다운/70초 쿨이 정확히 실점 직후 잔여
   라이브 프레임 안에서 0에 도달하면 득점 연출 중 발동 가능. 시각 전용 +
   reset_round 자가 치유 + magnetic auto와 동일 클래스(형제 공유)라 보류.
   재발/체감 보고 시 진짜 "라운드 라이브" 신호 도입으로 재설계.
4. **모달 중 sync 정지 → grace 타임아웃 self-heal 유지.** TAB/일시정지류
   physics-blocking 모달은 update driver 앞에서 return하므로 sync_state 호출이
   끊긴다. color-restore의 `ACTIVE_SYNC_GRACE_MSEC` 자동 숨김 패턴을 제거하지 말
   것 — 이게 모달 중 물결 잔존을 self-heal한다. (반대로 mythic 시네마틱류
   update_effects-유지 pause에서는 타이머가 계속 흘러 만료되는데, 이 스킬은 공
   소유가 없어 **구조적으로 무해** — skip_ball_motion_step 무접촉.)
5. **첫 발동 셰이더 컴파일 히치 (Hot-Path Lazy Init).** screen-read 셰이더의
   PSO를 부트 프리웜에 안 태우면 4점 각성 순간(가장 극적인 순간)에 100ms+ 히치.
   `battle_pso_prewarmer` 등록 + state prewarm 체인 필수.
6. **게이지 비결합.** illusion이 `boss_special_gauge`를 읽거나 소모하면 안 됨
   (D 확정). magnetic 게이트 미러 시 게이지 조건을 빼는 것을 리뷰에서 확인.
7. **픽셀 QA 없이는 통과 아님.** z-order/BackBufferCopy류는 상태 스모크가 전부
   GREEN이어도 화면에서 안 보이거나(z 침몰) 엉뚱한 레이어를 덮을 수 있다
   (negative-z/ancestor-fill 트랩 가족). §6의 윈도우드 캡처가 사인오프 조건.
8. **풀스크린 오버레이 rect는 컨텍스트 키 폴백으로 사이징하면 안 된다 (라이브
   QA 실증, 2026-07-04 "왼쪽 절반만 물결").** 플레이필드 draw 컨텍스트에는
   `view_size`가 없다 — `battle_playfield_effects_drawer._build_node_fx_layout`은
   `game_offset`/`render_scale`만 주입하므로, view_size 폴백 체인이 `game_size`
   (플레이필드 스크린 크기)로 조용히 강등되어 리플 rect가 윈도우 좌상단부터
   플레이필드-폭만 덮었다. 풀스크린 오버레이는
   `canvas.get_viewport_rect().size`(엔진 진실)로 사이징하고 컨텍스트 키는
   폴백으로만. 회귀 스모크는 **view_size 없는 컨텍스트**(라이브 재현)로 draw를
   구동해야 한다 — 픽셀 probe의 수동 view_size 주입이 이 버그를 가렸다.

---

## 5. Smoke design — `godot/tests/stage4_ponk_illusion_ripple_smoke.gd`

| # | Test | Asserts | 반증검증 (in-place Edit 토글, **git 명령 금지**) |
|---|---|---|---|
| 1 | `_test_locked_before_four_points` | score 1~3점 이벤트 → `illusion_unlocked==false`, 카드 `status=="locked"`. **+ 미각성+쿨0 상태에서 update() → 절대 auto-fire 금지** (리뷰 Finding 1) | unlock 게이트 상수를 3으로 토글 → FAIL 확인 후 원복 |
| 2 | `_test_awaken_staged_next_round_cast` (R1 재작성) | (a) 4점 이벤트 직후 **라이브 컨텍스트**로 update 수 회 → `active==false` (트랩 3b 재현 봉인); (b) `reset_round()` → stage 유지; (c) serve-waiting 컨텍스트 update → stage 2; (d) 라이브 컨텍스트 update → stage 3, delay=180; (e) 180프레임 상당 tick → `active==true`, `timer==240`, `cooldown==70` | (a)의 stage-1 게이트를 제거(=초판 배선으로 되돌림) → 실점 직후 발동 FAIL 재현; `reset_round()`에 stage=0 한 줄 추가 → FAIL (트랩 3 봉인) |
| 2b | `_test_delay_interrupted_by_round_end` (R1 신규) | stage 3 카운트다운 중 serve-waiting 컨텍스트 관측 → stage 2 복귀; 다음 라이브 전이에서 delay 재시작(180) | delay를 라운드 넘어 이월하는 토글 → FAIL |
| 2c | `_test_awaken_burst_once_per_match` (R2 신규) | 첫 2→3 전이에서 `burst_frames==90`+`burst_played==true`; tick으로 감산; **3→2→3 바운스에서 재-arm 금지**; `reset_round()`는 frames만 0/played 유지; `reset()`/`reset_for_result()`는 둘 다 클리어 | `burst_played` 게이트 제거 → 바운스 재생 FAIL |
| 3 | `_test_duration_expiry_then_cooldown_refire` | active에서 240프레임 상당 tick → `active==false`; 70초 상당 감산 → 자동 재발동 (stage 4 경유) | 재발동 게이트에서 `unlocked` 조건 제거 → 미각성 상태 재발동 FAIL |
| 4 | `_test_cooldown_freeze_and_pause_gates` | `stopwatch_freeze_active` 컨텍스트에서 쿨 불변; `active_item_boss_skill_cooldown_paused`에서도 불변 | illusion 감산을 게이트 랩 **밖**으로 이동 → FAIL |
| 5 | `_test_reset_for_result_stops_ripple` | active 상태에서 `reset_for_result()` → active/pending/unlocked clear + FX host inactive; 핸들러 레벨: stage4 라우팅 시 state의 reset_for_result 호출됨 | `_reset_stage4_for_result` 브랜치 주석 → FAIL (트랩 2 봉인) |
| 6 | `_test_full_reset_clears_unlock` | unlocked에서 `reset()` → locked + pending/쿨 clear | — |
| 7 | `_test_fx_host_pipeline_status` | `build_pipeline_status()`: `uses_screen_texture==true`, `uses_back_buffer_copy==true`, `z_index==1272`; `sync_state(active=false)` 후 hidden | defeat_continue_color_restore_fx_host_smoke.gd 미러 |
| 7b | 컬러-단독 픽셀 probe (R2 신규, non-headless) | `intensity_px=0` + `hue_wave_amp` 고값 + `strength=1`로 sync → 체커보드 delta > 임계 (**UV 왜곡 없이 컬러 레이어 단독으로 픽셀이 변함을 증명** — 왜곡 delta에 묻힌 hue no-op 회귀 방지). 버스트 패스도 aura probe 방식의 direct-call 픽셀 probe 추가 | hue 회전 적용 라인 무력화 → FAIL |
| 8 | `_test_skill_card_contract` | 카드 배열 길이 3; illusion 카드에 형제 계약 키 전원 존재; unlock 후 status 전이 locked→charging/ready | — |

- 반증검증은 전부 **in-place Edit 토글**로만 (이 리포에서 `git reset/checkout/
  stash` 절대 금지 — 표준 posture).
- 볼 스텝이 필요한 케이스는 `ball_vel * delta * 60` 규약 준수 (이 스킬은 공
  무접촉이라 대부분 불필요).

---

## 6. Verification gates (사인오프 조건)

1. 신규 스모크 8케이스 GREEN + 반증 토글 4건 각각 FAIL 재현 후 원복.
2. 기존 스모크 회귀: `stage4_map_port_smoke.gd`,
   `defeat_continue_color_restore_fx_host_smoke.gd`, ponk 관련 기존 스모크 GREEN.
3. **픽셀 QA (필수, 트랩 7):** 윈도우드 캡처로 (a) 각성 순간 물결 가시 확인,
   (b) 4초 엔벨로프 in/out, (c) 만료 후 잔존 없음, (d) TAB 모달 열고 grace
   타임아웃 뒤 물결 숨김, (e) 결과 화면 진입 시 물결 없음.
4. 프레임 예산: 발동 4초 창에서 BattlePerf로 screen-read 비용 확인
   (BackBufferCopy는 active+grace 동안만; idle 시 0 비용이어야 함).
5. 각성 순간 히치 없음 (PSO 프리웜 검증 — 부트 후 첫 발동에서 프레임 스파이크
   부재).

---

## 7. Out of scope (이번 슬라이스에서 안 함)

- 몽환포영의 물리적 효과(공 속도/궤적 변경) — 없음이 디자인.
- 각성 컷인/시네마틱 — S4 이후 별도 논의.
- Python 원본 백포트 — Godot 신규 스킬 (원본에 없음).
