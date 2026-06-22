# 각시탈 (Gaksital) Stage 1 보스 포팅 — 설계 / 슬라이스 플랜

> 단일 소스(single source of truth). 각시탈을 Godot "디스크하츠 - 링피아"
> 스테이지 1의 **두 번째 보스**로 추가하는 작업의 설계·신호계약·슬라이스·트랩
> 브리프. 런타임 GDScript 배선은 사용자/Codex가 이 문서를 보고 수행하고,
> Claude는 스프라이트 아트 디렉션 + 적대적 리뷰를 담당한다
> (`feedback_design_slice_review_division`, 자산 워크플로 분담).

상태: **설계 확정 / 미배선** (2026-06-23 작성)

---

## 0. 확정된 범위 결정 (재론 금지)

사용자 결정 (2026-06-23):

1. **아키텍처 = 얇은 변형 셀렉터.** Python식 풀 보스-로스터 시스템을
   지금 만들지 않는다. 전역 context에 통과시키는 얇은 보스-정체성 키
   **`stage1_boss_variant`** (`"dalji"` | `"gaksi"`)만 도입하고,
   **스테이지 1의 리소스 / 스킬 / HUD / result 모듈만** 그 키로 분기한다.
   - **기본값은 반드시 `"dalji"`.** variant 미지정 / 레거시 세이브 / 기존
     모든 경로는 달지로 100% 동일 동작해야 한다 (회귀 스모크로 봉인).
   - 1차: 디버그(F5 picker)로 `gaksi` 강제 선택 가능.
   - 랜덤 선출 / 메뉴 선택 UI / 풍악보이·포도대장 확장은 **후속 슬라이스**.
     이 키는 나중에 풀 로스터로 키울 수 있는 "씨앗"이지, 지금 로스터를
     만드는 게 아니다.
2. **스킬 범위 = `fan_throw`(부채던지기)만 (MVP).** 달지 팽이(`spinning_top`)
   미러. `fan_wind`(부채바람, 공 포획 소용돌이)는 **2차 슬라이스**
   — owned-ball(`skip_ball_motion_step`) 방출 트랩 영역이라 위험도가 한 단계
   높다. 이번 MVP에 넣지 않는다.

---

## 1. 원본 각시탈 정체성 (포팅 레퍼런스)

출처: `entities/talkwangdae_boss_sprite.py` (절차적 pygame, 코드명
`talkwangdae` = 탈광대, 변형키 `gaksi`), `config/stage_configs.py`
`BOSS_VARIANTS[1]["각시탈"]`, `downtown/boss_dialogues.py` `(1, "각시탈")`.

- **비주얼**: 붉은 **하회탈**(하회 별신굿탈) + **색동저고리**(무지개 줄무늬
  전통 저고리) + **부채**. 과장된 **광대(廣大)** 동작 — 어깨/허리 흔들기,
  너스레, 발놀림.
- **피격 연출**: "탈 벗겨짐" — 피격 시 탈이 들리며 회전(`mask_offset_y`,
  `mask_rotate`) + 넉백. (Godot 포팅에서는 stun 시트로 표현; 탈-벗겨짐을 별도
  연출로 살릴지는 아트 디렉션 단계 판단.)
- **색 팔레트**: 하회탈 붉은색 `(200, 50, 50)`, 부채 천 크림색
  `(220, 200, 160)`, 부채 림 붉은색 `(185, 55, 55)`.
- **스탯**: `BOSS_VARIANTS[1]["각시탈"]` = `**BOSS_CONFIGS[1]`(풍악보이)와
  **완전 동일**, `color`와 `special_skill`만 다름. → Godot에서도 달지의 AI/
  대쉬/난이도 스탯을 그대로 쓰면 된다 (별도 튜닝 불필요한 게 기본).
- **성격/대사** (`(1, "각시탈")`): 장난꾸러기 트릭스터. 전투시작
  "히히히! 자, 놀아보자꾸나~!", 피격 "맞았지롱~!" 류. (Godot에 인게임 보스
  VO 시스템이 아직 없으면 result-click 반응 대사로만 살린다 — §5.4.)

---

## 2. 시그니처 스킬 — `fan_throw` (부채던지기)

출처: `pingfighter.py` `activate_fan_throw()` (L105376), `_launch_fan_throw()`
(L105385), `update_fan_throw()` (L105428), 상태변수 L67273+, 부채 그리기
`_draw_fan_shape()` L105554.

### 2.1 메커니즘 (Python 원본, 단위 px/frame @ 60fps)

> ⚠️ Godot 단위 트랩: 이 엔진의 `ball_vel`/투사체 속도는 **px/frame**
> (`feedback_godot_ball_vel_pxframe_units`: 공속 base 7.65, 캡 ~26). 매프레임
> 이동은 `pos += vel * fps_scale` (`fps_scale = delta * 60`,
> `ball_update_controller`). 아래 숫자는 **그대로** px/frame로 이식 — px/sec로
> 환산하지 말 것.

| 단계 | 값 / 동작 |
|---|---|
| 발동(activate) | windup 30프레임(0.5초) 휘두르기 선딜 → launch |
| launch 위치 | 보스 중심 하단 `(BOSS.centerx, BOSS.y+BOSS.height)` |
| 조준 | 플레이어 방향 정규화 벡터 × speed `5.5` + vx에 `±0.8` 랜덤 jitter |
| 지속 | timer `180`프레임(3초) 또는 게임영역 이탈 시 소멸 |
| 이동(나비 날갯짓) | `speed_mod = 0.6 + 0.5*sin(elapsed*0.25)` (속도 변조 0.1~1.1), `sway = sin(elapsed*0.15)*1.8` (좌우 사행), `x += vx*speed_mod + sway`, `y += vy*speed_mod*1.3` (Y 30% 빠름) |
| 회전 | `spin += 0.3`/frame, 2π 경계마다 부채 사운드 |
| 플레이어 충돌 | `hit_radius 24` + `PLAYER.width//2` 원충돌 |
| 충돌 효과 | 0.3초 스턴(`try_apply_player_stun(0.3, source="stage1_fan_throw")`) + 넉백 `player_knockback_vel = ±12` 랜덤 + 타격이펙트 24프레임 + 대사 "맞았지롱~!" |
| 면역 | **연막(smoke) 안이면 부채공격 면역** ("연막 속에 숨었다!") |
| 광폭화(enraged) | launch 시 base 각도 ±35°로 **추가 부채 2발** 동시 발사 (각자 동일 이동/충돌) |
| 비주얼 | 절차적 부채 폴리곤 (6 ribs, 70° spread, 크림 채움 + 붉은 림) |

### 2.2 Godot 포팅 = 달지 `spinning_top` 거의 1:1 미러

달지 팽이(`stage1_dalji_spinning_top_skill_state.gd`)와 fan_throw는 구조가
사실상 동일하다 (**보스 중심에서 N개 이동 해저드 스폰 → 매프레임 이동 →
플레이어/공 충돌**):

| spinning_top (템플릿) | fan_throw (포팅) |
|---|---|
| `can_activate(context)` → `should_roll_activation(gauge)` → `activate(context, deps)` | 동일 인터페이스 |
| 보스 중심에서 `NORMAL_OFFSETS`/`ENRAGED_OFFSETS`로 N개 top 스폰 (payload factory) | 보스 중심 하단에서 플레이어 조준 1발 + 광폭화 시 ±35° 2발 |
| `update_and_collide(fps_scale, scene, context, deps)` 매프레임 | 동일 — windup 카운트다운 → launch → 나비이동 → 충돌 |
| top↔공 충돌, top↔top 충돌 | 부채↔플레이어 충돌(스턴+넉백), 연막 면역 |
| `get_draw_context()` → 렌더러가 그림 | 동일 — 부채 위치/회전/광폭화 추가발 노출 |
| 쿨다운/HUD는 `stage1_dalji_boss_skill_cooldown_state`가 charge→ready→activate→casting 관리, `TRIGGER_INSTANT` | 동일 — 부채던지기도 `TRIGGER_INSTANT`(충전 완료 시 자동 발동) |

**신호 계약 (fan_throw skill state, RefCounted):**
- `reset()` / `reset_round()` — 활성/투사체/타이머 전부 초기화.
- `can_activate(context) -> bool` — `current_stage==1 and stage1_boss_variant=="gaksi" and not active`.
- `should_roll_activation(gauge, context) -> bool` — gauge ≥ COST and can_activate.
- `activate(context, deps) -> bool` — windup 시작(30f), 위치/조준은 launch 시점에 라이브 재계산(보스/플레이어 위치는 launch 프레임 기준).
- `update_and_collide(fps_scale, scene, context, deps) -> Dictionary` — windup 틱 → launch → 나비이동 → 영역 컬링 → 플레이어 충돌(연막 면역 우선) → 스턴+넉백 반환. 광폭화 추가발 동일 처리.
- `get_draw_context() -> Dictionary` — `stage1_fan_throw_active`, 부채 [(x,y,spin)] 리스트(메인+광폭화), windup 진행률, 타격이펙트 위치/잔여.
- `is_active() -> bool`.

**충돌 = 순수 거리 원충돌** (`feedback`의 radial CC 트랩: 비주얼이 닿았다고
판정하지 말고 중심거리 명시). `hit_radius 24 + player_half_width`.

**스턴/넉백**: Godot 플레이어 스턴 시스템 + 넉백 채널을 **단위 1:1**로 사용
(`feedback_godot_boss_knockback_port_parity`: power는 Python @60fps ↔ Godot
`*fps_scale` 1:1, 형제 상수 빌려쓰기 금지). 넉백 ±12 px/frame 그대로.

---

## 3. 아키텍처 — `stage1_boss_variant` 변형 셀렉터

### 3.1 키 시드 + 전파

- **시드**: `game_selection_state.gd`에 `stage1_boss_variant: String = "dalji"`
  추가 (기본 dalji). 디버그 picker가 `"gaksi"`로 세팅 가능(§3.4).
- **전파**: `current_stage`가 흐르는 전역 battle context dict에 같이 실어
  내려보낸다. 컨슈머는 `context.get("stage1_boss_variant", "dalji")`로 읽되
  **누락 시 항상 dalji**.
- **Owner-field 스키마 트랩** (`feedback_godot_dynamic_set_payload_guard`,
  CLAUDE.md "Owner-Field Schema Trap"): 만약 이 키를 `owner.set(...)`로
  실어 다른 모듈이 `owner.get(...)`으로 읽게 한다면, 반드시
  `BattleSceneState.DEFAULT_VALUES`에 `stage1_boss_variant` 키를 선언할 것.
  안 그러면 set이 조용히 no-op 되고 컨슈머는 fallback(dalji)만 본다.
  context dict 직통 전파면 이 트랩은 회피되지만, owner 경유면 필수.

### 3.2 분기 터치포인트 (확인된 앵커)

리소스/스킬/HUD/result만 분기. 라우터(`stage_runtime_router.gd`)는 스테이지
번호 기반이라 그대로 둔다 (워크플로 C 확인).

| # | 파일 / 앵커 | 현재 (dalji 고정) | 각시탈 분기 |
|---|---|---|---|
| R1 | `battle_resources.gd:1100` `_get_stage1_boss_texture_specs()` | DALJI_* 시트 경로 | variant=="gaksi"면 GAKSITAL_* 경로 |
| R2 | `battle_boss_sprite_paths.gd:5-14` | DALJI_BOSS_* 14상수 | GAKSITAL_BOSS_* 상수 추가 |
| R3 | `battle_resources.gd:546-547` result prewarm specs | DALJI victory/defeat | variant 분기 |
| S1 | `gameplay_stage_module_catalog.gd:40` | dalji whip/spinning_top/cooldown 모듈 등록 | gaksital fan_throw + cooldown 모듈 등록 |
| S2 | `battle_update_stage_runtime_deps_builder.gd:43-47` `_append_stage1_deps` | dalji 스킬 deps 키 | variant=="gaksi"면 gaksital 모듈을 deps에 |
| S3 | `ball_dependency_context.gd:154/282/395/411` | dalji spinning_top deps | variant 분기 (동일 패턴) |
| S4 | `ball_frame_motion_controller.gd:252-255` | `deps.get("stage1_dalji_spinning_top_skill_state")` `update_and_collide` | gaksital fan_throw도 `update_and_collide` 호출 |
| S5 | `battle_draw_actor_context.gd:49-70` `if current_stage==1` | dalji whip/spinning_top draw context | gaksital fan_throw draw context |
| S6 | `battle_draw_scene_context.gd:59/113` | dalji spinning_top deps | variant 분기 |
| S7 | `ball_round_actor_cleanup.gd:68` | dalji spinning_top 라운드 정리 | gaksital 정리 |
| S8 | `match_reset_controller.gd:184` | dalji spinning_top 리셋 목록 | gaksital 추가 |
| H1 | `stage1_dalji_boss_skill_cooldown_state.gd` | "달지" + 팽이치기/상모돌리기 HUD | gaksital cooldown state: "각시탈" + 부채던지기 |
| H2 | `stage1_dalji_boss_skill_hud_assets.gd:3-4` | dalji 스킬카드 PNG | gaksital 부채던지기 스킬카드 |
| P1 | `battle_pso_prewarmer.gd:215,850-880` | dalji victory/defeat prewarm | variant 분기 |
| P2 | `battle_scene_update_prewarm_key_sets.gd:130` + `stage_debug_picker.gd:56` | dalji 모듈 prewarm 키 | gaksital 키 추가 |
| U1 | `stage1_boss_actor_renderer.gd:9-45` | dalji 렌더 계약(셀/프레임/캔버스) | gaksital 시트 그리드 계약 (시트 차원에 맞게) |
| RS1 | `stage_clear_result_asset_loader.gd` + `stage_clear_result_scene.gd:40-42,70-107,384-385,969-990` | dalji defeat/click "건들지마" 하드코딩 | gaksital defeat 시트 + 클릭 반응 (§5.4) |
| N1 | `defeat_settlement_screen.gd:10-17` `STAGE_BOSS_NAMES` | `1: "달지"` | variant 기반 보스명 |
| D1 | `stage_debug_picker.gd:6-18` STAGE_OPTIONS | 스테이지1=달지 | 1-A 달지 / 1-B 각시탈 (§3.4) |

> **권장 모듈 전략**: 달지 모듈을 건드려 내부 분기시키지 말고, **병렬
> 모듈**(`stage1_gaksital_fan_throw_skill_state.gd`,
> `stage1_gaksital_boss_skill_cooldown_state.gd`)을 만들고 위 컨슈머에서
> variant 게이트로 dalji 모듈 vs gaksital 모듈을 고른다. `variant=="dalji"`일
> 때 달지 경로는 **바이트 동일**해야 한다(아래 트랩 §6 회귀 봉인).

### 3.3 콜드-인스턴스화 트랩 (성능)

`battle_update_stage_runtime_deps_builder.gd:10-16` 주석이 경고하는 대로,
all-stages 리셋 경로는 **peek-only**(`get_cached_instance`)여야 한다 — 절대
gaksital 모듈을 콜드 인스턴스화하지 말 것 (370ms 물리 스톨 전례,
`project_physics_catchup_redraw_spiral` / CLAUDE.md "Hot-Path Lazy Init").
gaksital 병렬 모듈도 동일하게 peek 경로를 타야 한다.

### 3.4 디버그 선택 (1차)

`stage_debug_picker.gd` STAGE_OPTIONS에 스테이지1 하위 선택(달지/각시탈) 추가,
선택 시 `game_selection_state.stage1_boss_variant` 세팅 + 해당 variant의
prewarm 키 묶음 선택. 1차는 이 디버그 강제선택만 지원; 랜덤/메뉴는 후속.

---

## 4. 스프라이트 자산 제작 범위 (AutoSprite, Claude 디렉션)

> **AutoSprite MCP가 최종 시트의 필수 생성원** (CLAUDE.md / sprite-generation
> 스킬 §17). 절차적 Python 각시탈은 **비주얼 레퍼런스만**, 시트 소스 아님.
> Gemini/imagegen은 컨셉/프롬프트 분석/사용자 승인 폴백에만.

### 4.1 필요 시트 (달지 동급 표준 — 달지 자산 기준)

달지 실제 보유 자산(`godot/assets/sprites/stage1/dalji/`)을 미러:

| 시트 | 달지 기준 | 각시탈 |
|---|---|---|
| walk_left / walk_right | 분리 16f fullkeypose (1376×1536, 4×4, 셀 344×384), **런타임 미러 금지** | 동일 분리 좌/우 16f (각시탈도 광대 측면 보행) |
| idle | 1536×1024, 4×2, 셀 384×512, 8f 호흡 | 동일 (광대 너스레 idle) |
| attack (ball-contact hit) | 8f 루프 | 동일 (부채로 공 쳐내기) |
| dash | 단발 | 동일 |
| stun | 단발/루프 | 동일 (탈 벗겨짐 모티프 가능) |
| victory / defeat | result 시트 8f / live2d cutscene | 동일 |
| **fan_throw (스킬)** | (달지의 paengi_top_whip 32f 자리) | **부채던지기 전용 시트** — 휘두르기 선딜→발사 아크 |

> ⚠️ 시트별 그리드/프레임/셀 차원은 자산마다 다르다
> (`feedback_godot_atlas_grid_authority`: 멀티셀 atlas는 자산별 (cols,rows)
> 상수 필수, 공유 4×4 가정 금지). 각 각시탈 시트의 grid를 manifest에 기록하고
> `stage1_boss_actor_renderer`(또는 gaksital 전용 렌더러)의 셀 상수를 그에 맞춤.

### 4.2 정체성 락 + 사이즈 락

- **바디 사이즈 락**: Menhera 176×88 바디 클래스 = 표준. 각시탈도 게임 내에서
  달지/멘헤라 옆에서 같은 바디-리드(±5%). 캔버스 숫자(달지 96×112 draw)는
  렌더러 계약으로 맞추되 **인게임 가시 바디 리드**로 최종 판정
  (sprite-generation QA).
- **정체성 락(모든 시트 동일)**: 붉은 하회탈, 색동저고리 줄무늬 배치, 부채,
  광대 비율. walk 시트가 정체성 앵커.
- **프론트 바이어스 보행**: 정면감 유지(달지처럼 분리 좌/우 시트, 미러 금지).

### 4.3 부채(fan) 투사체 VFX

원본은 절차적 부채 폴리곤(`_draw_fan_shape`). 달지 팽이/채찍도 시트+절차
혼합. 부채 투사체는 **(a) 작은 부채 스프라이트/시트를 회전 draw** 또는
**(b) 절차적 폴리곤 포팅** 중 택. 권장: 부채 정체성이 중요하므로 **작은 부채
시트 1장**(또는 16프레임 스킬-이펙트 시트, CLAUDE.md "Runtime Skill-Effect
Sprite Sheets" 기본 권장)을 회전/사행 모션으로 합성. 모듈러 VFX 3-피스
방법론 적용 가능(`feedback_modular_vfx_3piece_methodology`).

### 4.4 워크플로 모드

`.claude/sprite_workflow_settings.json` 기본 `fast` — 후보 빠른 생성/조기
판단/적극 기각. 유망 후보 확정 후에만 프레임 확장/누끼/런타임 핸드오프
(`precise`).

---

## 5. 슬라이스 분해

### 슬라이스 1 — 변형 셀렉터 골격 (보스 없이 dalji 무변화 증명)
- `stage1_boss_variant` 키 시드(`game_selection_state`) + context 전파.
- 모든 §3.2 컨슈머에 variant 게이트 자리만 마련(아직 gaksital 모듈 없음,
  분기 양쪽이 dalji).
- **봉인 스모크**: variant 미지정/“dalji”에서 달지 경로 바이트 동일 + 모든
  deps/draw/cleanup 키가 기존과 동일(회귀 가드). **반증검증**: variant 게이트를
  일부러 깨면 스모크 FAIL.

### 슬라이스 2 — 각시탈 스프라이트 시트 (AutoSprite, Claude)
- §4 시트 풀세트 생성 → QA(정체성/사이즈/프론트 바이어스/누끼) → 런타임 export
  → `godot/assets/sprites/stage1/gaksital/`.
- R2 경로 상수 + U1 렌더러 그리드 계약 + R1/R3 텍스처 스펙 배선.
- **게이트**: 인게임 달지/멘헤라 옆 바디-리드 픽셀 QA.

### 슬라이스 3 — fan_throw 스킬 상태 + 쿨다운/HUD
- `stage1_gaksital_fan_throw_skill_state.gd` (spinning_top 미러, §2 메커니즘).
- `stage1_gaksital_boss_skill_cooldown_state.gd` ("각시탈" + 부채던지기,
  `TRIGGER_INSTANT`).
- S1~S8 + H1/H2 배선 (variant 게이트).
- 부채 투사체 렌더(§4.3) + get_draw_context → 액터 렌더러.
- **봉인 스모크 (OUTCOME)**: (a) 발동→0.5초 windup→발사, (b) 플레이어 충돌 시
  실제 스턴+넉백이 적용되는지(arming 플래그 아님, 실효과), (c) 연막 면역,
  (d) 광폭화 시 추가 2발, (e) 영역 이탈/timer 소멸 정리, (f) px/frame 단위
  검증(스모크가 공/투사체를 `vel*delta*60`로 전진 — raw vel 금지,
  `feedback_godot_ball_vel_pxframe_units`). **반증검증**: 수정 전(미배선) 코드에서
  스턴 미적용 스모크가 FAIL함을 확인.

### 슬라이스 4 — result / 패배결산 / 디버그선택 / 정리
- RS1 result 화면 각시탈 defeat 시트 + 클릭 반응 대사(트릭스터 톤, "건들지마"
  대체).
- N1 패배결산 보스명 variant 분기.
- D1 디버그 picker 스테이지1 하위선택.
- 후속(별도): 랜덤/메뉴 선출, fan_wind 2차 스킬.

---

## 6. 트랩 브리프 (배선 전 필독)

1. **기본 dalji 불변 (최우선).** variant 누락/“dalji”에서 달지 경로는
   바이트 동일. 회귀 스모크가 봉인. variant 게이트를 추가하되 dalji 분기는
   기존 코드 그대로.
2. **px/frame 단위.** fan_throw speed 5.5 / 넉백 ±12은 px/frame. 매프레임
   `*fps_scale`. px/sec 환산 금지. 스모크 전진도 `vel*delta*60`.
   (`feedback_godot_ball_vel_pxframe_units`, `feedback_godot_boss_knockback_port_parity`)
3. **radial CC = 중심거리 명시.** 부채 충돌은 비주얼 닿음이 아니라
   `hit_radius 24 + player_half_width` 원충돌. (CLAUDE.md radial CC 트랩)
4. **콜드 인스턴스화 금지.** all-stages 리셋/peek 경로에서 gaksital 모듈을
   생성하지 말 것 — `get_cached_instance` peek. (370ms 스톨 전례)
5. **owner-field 스키마.** variant를 owner 경유로 전달하면
   `BattleSceneState.DEFAULT_VALUES`에 키 선언 필수(no-op 트랩).
6. **atlas grid authority.** 각시탈 시트별 (cols,rows) 상수 + manifest 기록.
   공유 4×4 가정 금지 (런타임 에러 없이 스프라이트 깨짐).
7. **OUTCOME 스모크.** "발동했다"가 아니라 "스턴/넉백이 실제로 적용됐다"를
   단언. 성공-only 테스트는 컴파운딩/미스 버그를 숨김.
8. **연막 면역 우선순위.** 충돌 시 연막 체크가 스턴보다 먼저 (Python 순서).
9. **다국어 동기화.** 각시탈 보스명/대사 등 플레이어 노출 문구는
   language_settings_data 다국어 동기화 + localization_coverage 봉인
   (`feedback_godot_localization_copy_sync`). 보스명은 음역 고정.
10. **fan_wind는 이번 범위 아님.** 공 포획 소용돌이는 owned-ball
    `skip_ball_motion_step` 방출 트랩(라운드/모달 경계 self-heal) 영역 —
    2차 슬라이스에서 CLAUDE.md owned-ball 체크리스트 전부 타야 함.

---

## 7. 분담

- **Claude**: 이 설계 문서 + 슬라이스 2 스프라이트(AutoSprite 생성·QA·아트
  디렉션·누끼·런타임 export) + 슬라이스 1/3/4 GDScript 적대적 리뷰.
- **사용자 / Codex**: 슬라이스 1/3/4 GDScript 런타임 배선 + 스모크 작성 +
  반증검증 + 인게임 라이브 QA.
- 자산 워크플로 분담(CLAUDE.md §0.1) + `feedback_design_slice_review_division`
  준수.
