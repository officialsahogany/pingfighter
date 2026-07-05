# 포도대장(Pododaejang) Stage 1 보스 포팅 플랜

> 브리프. 런타임 GDScript 배선은 사용자/Codex가 이 문서를 보고 수행하고,
> Claude는 설계·아트 디렉션·적대 리뷰를 맡는다.
> (작업 분담: `feedback_design_slice_review_division`, `feedback_claude_vs_codex`)
>
> 상태: **설계 확정 / 미배선** (2026-06-27 작성)
> 자매 문서: `docs/gaksital_stage1_port_plan.md` (동일 포맷, variant 셀렉터 선례)

---

## 0. 확정된 범위 결정

Stage 1 = 원본 3보스(풍악보이=**달지**, 각시탈, **포도대장**) 중 랜덤 선출.
사용자 결정(2026-06-27): **포도대장을 먼저 풀 포팅해 3보스를 완성한 뒤, 3-way 랜덤 선출을 켠다.**

- **아키텍처**: 기존 `stage1_boss_variant` 얇은 셀렉터를 2-way(`dalji`/`gaksi`)
  → 3-way(`+podo`)로 확장. 신규 시스템 아님, **분기 1개 추가**.
- **스킬 범위**: 포도대장은 달지처럼 **2-스킬 구조**다(아래 §0.1). 두 스킬 모두 포팅한다.
  - **포졸소환**(patrol_guards) = per-round/instant 슬롯 → 달지 `spinning_top` 슬롯 미러.
  - **포승줄**(arrest_rope) = on-boss-hit 슬롯 → 달지 `whip` 슬롯 미러.
- **스프라이트**: 리포 표준대로 **AutoSprite MCP** 시트. 절차적 렌더 아님
  (원본 Python은 절차적이지만 Godot 보스는 시트가 표준 — 달지/각시탈과 동일).
- **선출 시스템**: 포도대장 랜딩 후 마지막 슬라이스에서 3-way 랜덤 켜기(§6 Slice 7).

### 0.0 결정 잠금 (2026-06-27, 사용자 확정)

- **freeze 정책 = 원본대로 freeze 없음.** 포도대장 두 스킬 모두 시전 중 보스 이동을
  멈추지 않는다(원본 보존). 달지 팽이치기의 1초 freeze(commit b6ac325b)는 **달지 특례로
  유지**하고 포도대장엔 적용하지 않는다. → 트랩 13 무효화(freeze 분기 추가 안 함).
- **포졸 아트 = AutoSprite 시트.** 달지/각시탈/보스와 같은 품질선. 절차적 도형은
  **임시 fallback**으로만(아트 미도착 시 placeholder). → §5 (a) 채택.
- **Slice 1 셀렉터 인프라 = Codex 배선·검증 완료** (`podo` 3-way 분기 / 디버그 선택 /
  프리웜 / 콜드인스턴스화 캐시 방어 포함). 다음 = **Slice 2 스프라이트**(Claude 리드).
- **3-way 랜덤 = Slice 7 유지** (포도대장 풀 랜딩 후 켠다).

### 0.1 ★ 핵심 정정 — 포도대장은 스킬 2개다

조사 중 한 에이전트가 `config/stage_configs.py:168 "special_skill": "arrest_rope"`
한 필드만 보고 "포졸소환 미구현"이라 결론냈으나 **틀렸다.** `special_skill`은
보스당 1줄만 적는 **대표 태그**이고(풍악보이도 `"whip"` 한 줄이지만 실제로
팽이치기+상모돌리기 둘 다 보유), 실제 스킬 수와 무관하다. 코드 확정:

| Stage1 보스 | per-round/instant 슬롯 (게이지 150, 20%) | on-boss-hit 슬롯 (게이지 200, 15%) |
|---|---|---|
| 풍악보이=**달지** | 팽이치기 `spinning_top` (L173611) | 상모돌리기 `whip` (whip) |
| **포도대장** | **포졸소환 `patrol_guards`** (L173619) | **포승줄 `arrest_rope`** (L174481, idle 게이트) |
| 각시탈 | 부채바람 `fan_wind` (미포팅, 2차) | 부채던지기 `fan_throw` (포팅됨) |

→ **포도대장의 2-스킬은 이미 완전 포팅된 달지의 2-스킬 머신(`spinning_top`+`whip`,
쿨다운 상태 `stage1_dalji_boss_skill_cooldown_state.gd`)과 슬롯 구조가 1:1.**
달지의 `stage1_dalji_*` 모듈 세트를 포도대장으로 재스킨하는 것이 본 포팅의 골격.

---

## 1. 원본 포도대장 정체성

- **이름/정체**: 포도대장 — 조선 포도청(捕盜廳) 수장. 위엄 있는 관료, 포졸 통솔.
- **색상**: BOSS_COLOR `(100, 70, 40)` 갈색 (`stage_configs.py:167`, `pingfighter.py:39549` 부근).
- **사이즈**: `BOSS_IMG_PODO_WIDTH=96 × HEIGHT=192` (기본 80×160의 **+20%**, `pingfighter.py:61661-63`).
  - 비교: 달지/풍악보이 80×160, 각시탈 92×184. **포도대장이 stage1 3보스 중 가장 큼.**
  - Godot 사이즈 락: 달지 렌더러 메타데이터 기준으로 +20% 캔버스/소스렉트로 기록(§5).
- **모티프(아트 락)**: 검은 **갓**(테 `(15,12,8)`/관 `(25,20,15)`/끈 `(60,45,25)`),
  남색 **관복**(주 `(35,45,75)`/앞면 `(55,68,105)`), 갈색 **허리띠**+버클,
  금색 **흉배(관직 배지)** 십자 문양 `(210,180,60)`, 위엄 표정(찡그린 눈썹/콧수염/턱수염),
  무기 = **포승줄**(밧줄 `(175,145,95)`). 포졸 통솔 정체성.
- **config/스탯**: `stage_configs.py:164-169` — 풍악보이(BOSS_CONFIGS[1]) 스탯 상속
  (accel/decel 0.798, max_speed 6.3175, predict 160, dash 등 달지와 동일). 색/이름만 다름.
- **대사**(`downtown/boss_dialogues.py:320-353`): 사극 말투.
  전투시작 "포도대장이 나섰노라!", 패배 "포도대장이 지다니! 체면이 말이 아니구나!".
  스킬 외침 — 포졸소환 ["포졸들아!","잡아들여라!","에워싸라!"], 포승줄 ["포승줄 포박!","포박이다!","묶어라!"].

---

## 2. 스킬 A — 포졸소환 (patrol_guards) · per-round/instant 슬롯

> 달지 `spinning_top` 슬롯 미러. **신규 요소 = 다중 소환체(포졸 2명)** — 달지/각시탈에 없던 것.

**발동**(`pingfighter.py:173619`): `current_stage==1 && 포도대장 && not active && not used_this_round && gauge>=150`,
그 다음 `random.random() < 0.20`. 발동 시 `gauge -= 150`. **라운드당 1회.**

**소환 사양**(`activate_patrol_guards` L107821-848): 포졸 **2명**.
- 위치 Y: `boss.y + boss.height + 30` (보스 하단 아래 30px).
- 위치 X: 게임영역(140~620px) 1/3·2/3 = **300px, 460px**.
- 초기: `wait_timer=randint(10,30)`, `patrol_speed=uniform(110,180) px/sec`(개체별 랜덤),
  `direction`=guard0 +1 / guard1 −1, `alpha=255`.

**지속**: `patrol_guards_duration = 300` 프레임(5초, L67270). 마지막 30f 페이드아웃(alpha 255→0),
페이드 중 alpha<128이면 충돌 무시.

**순찰**(L107857-915): 대기 끝나면 `target_x=uniform(160,600)` 향해 `patrol_speed*dt` 이동,
도착(±3px) 시 `wait_timer=randint(24,90)` 후 새 목표. 경계 클램프 140~620. (dt = 1/60 × 배속)

**게임플레이 효과(★중요, 단순 장식 아님)** — 공↔포졸 충돌(L107919-955):
- 충돌 반경 `guard_radius=18` + ball_radius → 거리 < `18+ball_r`.
- 충돌 시 **공 속도 크기 유지, 방향만 무작위(0~2π) 반사** — `random_angle` 재설정.
- 포졸은 공 반대방향 `push_vx=cos(angle)*8.0`, `push_timer=10`(매 프레임 ×0.85 감속).
- 충돌 이펙트 + paddle_sound.

**보스 자신**: 시전 중 **이동 멈춤 없음**(원본). → §7 트랩의 "freeze 정책 결정" 참조.

**리셋**(L76128-131 round, L32614-617 stage, +181637/182922/184093/187041):
`patrol_guards_active=False`, `patrol_guards_timer=0`, `patrol_guards=[]`, `patrol_guards_used_this_round=False`.

**포졸 비주얼**(L107958-108038): 32×44 절차적 도형(남색 관복+갓+곤봉+피부톤). Godot은
AutoSprite 작은 포졸 시트 또는 달지/각시탈처럼 절차적 — **아트 디렉션 결정 필요(§5)**.

---

## 3. 스킬 B — 포승줄 (arrest_rope) · on-boss-hit 슬롯

> 달지 `whip` 슬롯 미러. **신규 요소 = 플레이어 이동속도 디버프 채널 + 상태머신 비주얼.**

**발동**(`pingfighter.py:174480-493`): **보스가 공을 맞춘 시점**, `gauge>=200 && 포도대장 && phase=="idle"`,
그 다음 `random.random() <= 0.15`. 발동 시 `gauge -= 200`. **라운드당 제한 없음**(per-round 플래그 X).

**상태머신**(`activate_arrest_rope`/`update_arrest_rope` L104541-948):
`idle → throwing(45f) → [명중] bound(180f) → releasing(28f) → idle` / `[빗나감] miss(30f) → idle`.

| 단계 | 프레임 | 내용 |
|---|---|---|
| throwing | 45f (0.75s) | 보스 하단 `(boss.centerx, boss.y+boss.height)` → **발사 시점 플레이어 위치**로 직진. easeOutQuad `1-(1-t)²`. |
| bound | 180f (3s) | 명중 시. 플레이어 속도 디버프 유지. |
| releasing | 28f | 줄 끊김 연출. |
| miss | 30f | 빗나감/연막 회피. |

**명중 판정**(L104594-605): X거리 `abs(target_x − player_cx) < PLAYER.width*0.6 = 60px`(절댓값).
**연막 면역**: `is_player_in_smoke()` True → miss("연막 속에 숨었다!").

**명중 효과**(L95300-301): `arrest_rope_active` True인 동안 **플레이어 이동속도 ×0.5**(곱셈, 180f).
스턴/입력잠금 **없음** — 순수 감속. 플레이어는 입력·타격 가능.

**보스 자신**: 시전 중 **이동 멈춤 없음**(원본, L175410-415에 포승줄 조건 없음).

**리셋**(L181631-633 gameover, L182916-918 stage, +184087/187035):
`arrest_rope_active=False`, `arrest_rope_timer=0`, `arrest_rope_phase="idle"`.

**비주얼**(L104650-948): 갈색 밧줄(`(140,110,65)`/`(175,145,95)`/`(200,175,125)`), throwing 14세그+올가미 코일,
bound 16세그+글로우+X자 매듭+남은시간 호(반경35px), miss 처짐, releasing 끊김 반동. → AutoSprite/절차 결정(§5).

**단위 주의**: 위 px/frame, 60fps 기준. Godot 포팅은 `fps_scale = delta*60` 경로 사용
(`feedback_godot_ball_vel_pxframe_units`). px/sec로 환산 금지.

---

## 4. 아키텍처 — variant 분기 터치포인트 (2-way → 3-way)

`stage1_boss_variant`에 `"podo"` 추가. 각시탈(`gaksi`) 배선과 **동일 패턴으로 분기 1개씩** 추가.
달지 모듈을 미러링한 `stage1_pododaejang_*` 세트를 만든다.

| # | 모듈 | 현재 | 포도대장 추가 |
|---|---|---|---|
| C1 | `game_selection_state.gd` L12-13 | `DALJI`/`GAKSI` 상수 | `STAGE1_BOSS_VARIANT_PODO := "podo"` + `_normalize_*` 분기 |
| C2 | `battle_scene_selection_startup_lifecycle.gd` L93-96 | `gaksi` 정규화 | `podo`/`pododaejang` → `podo` |
| C3 | `gameplay_stage_module_catalog.gd` L40-67 | dalji/gaksi 모듈 등록 | `stage1_pododaejang_{patrol_guards,arrest_rope}_skill_state`, `_boss_skill_cooldown_state`, `_boss_skill_hud_renderer`, `_hud_assets`, 렌더러 |
| C4 | `ball_dependency_context.gd` L284-292,417-431 | `if variant=="gaksi"` round/update deps | `elif variant=="podo"` 동일 패턴 deps |
| C5 | `effects/battle_effects_update_controller.gd` L42-50 | gaksital cooldown_state.update | podo cooldown_state.update 분기 |
| C6 | `ball_frame_motion_controller.gd` + `ball_update_controller.gd` | `apply_stage1_gaksital_fan_throw` | `apply_stage1_pododaejang_arrest_rope` (on-hit) + patrol_guards 충돌 |
| C7 | `ball_round_actor_cleanup.gd` L76-82 | gaksital reset_round | podo 두 스킬 + 포졸 리스트 reset_round |
| C8 | `stage1_pillar_hud_scene_drawer.gd` L298-372 | gaksi HUD 분기 | podo HUD 분기 |
| C9 | `stage1_boss_actor_renderer.gd` L207-292,444-446 | gaksital 시트 선택/variant 게이트 | podo 시트 선택 + `_is_pododaejang_variant` |
| C10 | `battle_draw_actor_context.gd` / `battle_draw_scene_context.gd` | gaksi draw context | podo 포졸+포승줄 draw context |
| C11 | `battle_boot_resource_prewarm_controller.gd` L520-521,1284-87 | variant별 prewarm 키 | podo 시트/HUD prewarm 키 묶음 |
| C12 | `battle_resources.gd` / `battle_boss_sprite_paths.gd` | 보스 시트 경로 상수 | `PODODAEJANG_BOSS_*` 경로 + 텍스처 스펙(둘 다 동기화, `reference_godot_texture_spec_loader_sync`) |
| C13 | `match_reset_controller.gd` L186-187 | gaksital reset 키 | podo 모듈 키 추가 |
| C14 | `stage_clear_result_*` (scene/asset_loader) | dalji/gaksi result | podo defeat/victory + 클릭 보이스 |
| C15 | `stage_debug_picker.gd` L6-19,388-389 | "1-A dalji"/"1-B gaksi" | "1-C 포도대장"(`variant="podo"`) |
| C16 | `language_settings_data.gd` (다국어) | "각시탈" 등 매핑 | "포도대장" 다국어 5종 (`feedback_godot_localization_copy_sync`) |

---

## 5. 스프라이트 자산 범위 (AutoSprite MCP) — ✅ 납품 완료

`sprite-generation` 스킬 경유, AutoSprite 캐릭터 파이프라인. **납품 실제 내역**(매니페스트
`godot/assets/sprites/stage1/pododaejang/pododaejang_sprite_set_manifest.json`이 SSOT):

- **납품 7시트**: walk(16f·정면 단일) / idle / dash / victory / **attack(포승줄 채찍 캐스트)** /
  defeat / stun. 전부 **정면(front-facing) read**, removeBg ultra, pro.
- **walk = 단일 정면 시트**(L/R 페어 아님). AutoSprite `walk`(사이드스크롤러)는 후반 측면 프로필로
  새서 **리젝**했고, `iso_walk_down`(정면)이 캐논 앵커. 정면이라 좌/우 양방향에 그대로 사용 — 런타임 단순.
- **그리드 권위(★)**: walk=4×4(16f), 나머지=3×3(8f, 마지막 셀 비어있음). repo 표준 4×2 아님 —
  per-sheet (cols,rows)로 슬라이스(`feedback_godot_atlas_grid_authority`).
- **사이즈 락**: 바디 리드 = 달지 +~20%(stage1 3보스 중 최대). 셀의 ~50% 채움. 인게임 달지 옆 비교 QA.
- **정체성 락**: 갓 + 남색 관복 + 금 흉배(학) + 갈색 허리띠 + 포승줄 + 위엄 수염. 7시트 일관 확인됨.
- **포졸(소환체)**: 결정대로 **(a) AutoSprite 시트** 채택 — 정면 patrol walk 8f, 곤봉 든 하급 포졸
  (수장과 명확 구분). `godot/assets/sprites/stage1/pojol/`.
- **freeze 정책**: §0.0 결정대로 **freeze 없음**(시트에 별도 freeze 포즈 불필요).
- **포승줄 밧줄 VFX**: attack 시트가 채찍 호를 담고 있음. 런타임 추가 밧줄 곡선이 필요하면 모듈러
  VFX(`feedback_modular_vfx_3piece_methodology`)로 보강 — 단 1차 배선은 attack 시트로 충분.
- result 시트: 포도대장 victory/defeat + 클릭 컷신/보이스(달지 result 패턴).

---

## 6. 슬라이스 분해

| Slice | 내용 | 검증 |
|---|---|---|
| **1. 셀렉터 인프라** ✅ **Codex 완료** | `stage1_boss_variant`에 `podo` 3-way 분기(C1·C2·C4·C9·C15). 포도대장 모듈 **없이** dalji/gaksi 불변 증명. | 회귀 스모크: dalji/gaksi 무변화. 반증검증. |
| **2. 스프라이트** ✅ **자산 생성·배치 완료 (Claude/AutoSprite)** | 포도대장 보스 **7시트**(walk 16f·idle·dash·victory·attack(포승줄)·defeat·stun, 전부 정면·정체성락·ultra누끼) + **포졸** patrol walk 8시트. repo 배치: `godot/assets/sprites/stage1/pododaejang/` + `.../pojol/`, 매니페스트 `pododaejang_sprite_set_manifest.json`. ⏳ **Codex 잔여**: `godot --import`로 `.import` 생성(export-safe)·경로 상수 C12·prewarm C11·렌더러 시트매핑 C9·draw context C10. | 시트 QA 합격(정면/정체성/누끼). 인게임 바디 리드 vs 달지 + 픽셀 QA = Codex 배선 후. |
| **3. 포승줄(arrest_rope)** | on-hit 스킬 — 달지 `whip` 미러. 상태머신 + **플레이어 속도 ×0.5 디버프 채널** + 연막 면역. C5·C6·C7. | OUTCOME 스모크: 명중 시 **플레이어 실제 감속**(속도 0.5배 확인), 빗나감/연막 미적용. 반증검증. |
| **4. 포졸소환(patrol_guards)** | per-round 스킬 — 달지 `spinning_top` 미러. **포졸 2체 소환+순찰+공 무작위반사**. C6·C7·C10. | OUTCOME 스모크: 공이 포졸 충돌 시 **실제 방향 무작위반사**(속도 유지), per-round 1회 게이트. 반증검증. |
| **5. HUD/쿨다운** | `stage1_pododaejang_boss_skill_cooldown_state`(2슬롯: patrol_guards instant + arrest_rope on-hit) — **달지 쿨다운 상태 직접 미러**. HUD 렌더러/에셋(갈색 카드). C5·C8. | HUD 스모크(카드 2개, 보스명 "포도대장", 갈색). |
| **6. result/정리** | 포도대장 defeat/victory + 클릭 보이스. 다국어(C16). 리셋 경로(C7·C13). | result 스모크 + 다국어 coverage. |
| **7. 3-way 랜덤 선출** | 스테이지 진입 시 `[dalji,gaksi,podo].pick_random()` → `set_stage1_boss_variant`. 진입 1회 확정/스테이지 유지/리그 무관. 디버그 강제선택 우선. | 선출 스모크: 진입 1회 롤·라운드 불변·디버그 우선·시드 처리. |

> 2026-07-04 note: live Stage 1 now uses an interim 2-way random entry pool
> (`dalji`, `gaksi`) in `battle_scene_selection_startup_lifecycle.gd`.
> `podo` remains debug-selectable through F5 but stays out of normal roulette
> until this Slice 7 is completed with Pododaejang runtime skills.

---

## 7. 트랩 브리프 (배선 전 필독)

1. **기본 dalji/gaksi 불변** — Slice 1에서 회귀 스모크로 봉인. 반증검증 필수.
2. **px/frame 단위** — 포승줄 45/180/28f, 포졸 300f/110~180px/sec(소환만 sec), 공반사 px/frame.
   `fps_scale=delta*60` 경로. px/sec 환산 금지(`feedback_godot_ball_vel_pxframe_units`).
3. **포졸 공-무작위반사 = owned-ball 인접 영역** — 공 속도 크기 유지+각도만 변경. `ball_vel` 직접
   조작이므로 폭주 방지(속도 상한 유지), 스킵 플래그 없이 충돌 응답만. 포세이돈식 스티어링 참고.
4. **확률 cadence — per-frame 컴파운딩 주의**(`Godot Per-Frame Probability Roll Trap`):
   원본은 per-round 플래그(포졸) / on-hit(포승줄)로 게이팅 → **per-frame 롤 아님**. Godot 포팅도
   달지 쿨다운 상태(프레임 쿨 + instant/on-hit)로 게이팅하고 매프레임 `random` 롤 금지.
5. **radial/거리 CC 프리미티브 명시** — 포승줄 명중 = X거리 60px(절댓값), 포졸 충돌 = 중심거리 `18+ball_r`.
   Rect 오버랩으로 슬쩍 바꾸지 말 것. 엣지 케이스 스모크.
6. **owner-field 스키마** — variant/스킬 플래그는 **context dict 직통**(달지/각시탈 패턴), `owner.set()` 경유 X.
   만약 owner 경유 필요 시 `BattleSceneState.DEFAULT_VALUES` 키 선언 필수(`feedback_godot_dynamic_set_payload_guard`).
7. **콜드 인스턴스화 금지** — all-stages 리셋/“active?” 조회는 `get_cached_instance`(peek). 포졸/포승줄 모듈
   매치리셋서 콜드 생성 금지(`reference_godot_prewarm_split`, deps builder 트랩).
8. **텍스처 스펙/로더 동기화** — `PODODAEJANG_BOSS_*`는 direct loader + `_texture_spec` **둘 다** 추가
   (`reference_godot_texture_spec_loader_sync`). 누락 시 프리웜 null.
9. **atlas grid authority** — 포졸/보스 시트별 `(cols,rows)` 상수 필수, `SHEET_COLS=4` 가정 금지
   (`feedback_godot_atlas_grid_authority`). zoom-render QA.
10. **OUTCOME 스모크** — "발동" 플래그가 아니라 **실제 효과**를 단언: 포승줄=플레이어 속도 0.5배 적용,
    포졸=공 실제 무작위반사(속도 유지). 핸드-어드밴스 스모크는 `ball_vel*delta*60` 미러.
11. **연막 면역 우선순위** — 포승줄 충돌 체크 **전에** `is_player_in_smoke` 확인.
12. **다국어 동기화** — "포도대장" + 스킬명("포승줄","포졸소환") 5개국. 숫자/문구 변형까지 grep+coverage 봉인.
13. **★ freeze 정책 결정 필요** — **원본 포도대장은 시전 중 보스 이동을 멈추지 않는다.** 단 우리는
    최근 달지 팽이치기에 1초 제자리고정을 **추가**했다(원본엔 없던 것, commit b6ac325b). 일관성 위해
    포도대장 스킬에도 freeze를 넣을지는 **디자인 결정** — 기본은 원본대로 freeze 없음, 사용자 지시 시
    `stage1_dalji_spinning_top_freeze_active` 패턴(boss_ai_state 분기) 미러.
14. **포승줄 디버프 채널** — 플레이어 이동속도 ×0.5는 기존 슬로우/디버프 채널을 재사용해야 함(포도대장
    전용 ad-hoc 곱셈 금지). 기존 플레이어 속도 멀티플라이어 경로 확인 후 거기에 연결.

---

## 8. 분담

- **Claude**: 본 설계 문서, 아트 디렉션(스프라이트 프롬프트/정체성 락/포승줄 VFX 레시피),
  적대 리뷰(엣지·반증검증 재현·OUTCOME 단언 확인), 픽셀 QA.
- **사용자 / Codex**: Slice 1·3·4·5·6·7 GDScript 런타임 배선 + 스모크 작성 + 인게임 검증.
- **AutoSprite**: Slice 2 시트 생성(`sprite-generation` 스킬 경유).

각 슬라이스 완료 시 Claude 적대 리뷰 → 헌크 분리 커밋(`reference-noninteractive-hunk-split`,
현재 작업 트리에 스타코일 WIP 공존하므로 분리 필수).
