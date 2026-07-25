# Godot Stage 8 미노타우로스 (파르테논) 포트 플랜

Python 원본 Stage 9 미노타우로스(Parthenon/그리스 테마)를 Godot **Stage 8** 슬롯으로
포팅한다. Godot 슬롯 = Python 슬롯 − 1 (후기 스테이지 규칙: Python7→Godot6 테트리서,
Python8→Godot7 아카무, **Python9→Godot8 미노타우로스**).

레퍼런스 구현 = **Stage 7 아카무 리고** (`godot/scripts/stages/stage7/`). 모듈 접두사 =
`stage8_minotaur_*`, 에셋 트리 = `res://assets/sprites/bosses/stage8_minotaur/`,
`res://assets/sprites/hud/stage8_minotaur_*`.

관련 근거: [[project_python_stage9_minotaur]] (미완성 스텁 확정) · `docs/stage7_akamu_rigo_port_plan.md`
· `docs/stage6_tetriser_port_plan.md` · `docs/godot_runtime_traps.md`.

---

## 0. 핵심 전제 — "충실한 포팅"이 아니라 "셸 + 정체성 포팅 + 여기서 설계"

테트리서(순수-불변 모듈 존재)·아카무(하드코딩이지만 완성/출시)와 달리 **Python Stage 9
미노타우로스는 미완성 스텁**이다:

- `config/stage_configs.py:144` `special_skill: None` — 보스 스킬 없음.
- 대시 시트·384px 설정·`trigger_dash(force=True)`는 있으나 게이지 충전 대상(3,4,5,6,8)에서
  Stage 9 누락 → **정상 플레이 대시 발동 불가(죽은 배선)**.
- 전용 BGM 없음 → Stage 4 BGM 임시 차용.
- 보스 스프라이트: 백업 4시트(walk/attack/dash/turn·83×92·단면·FLUX 유래) vs repo frozen
  2시트(72×80). idle/victory/defeat/stun **원본 자체가 없음**.

⇒ 이 포트는 **(a) 스테이지 셸·미노타우로스 정체성·파르테논 무대를 이식**하고,
**(b) 보스 전투(스킬/각성/차지)는 신규 설계**한다. `special_skill`과 대시는 원본을 "복원"할지
"신설"할지 **설계 결정 필요**(§7).

---

## 1. 슬롯 결정 — picker ID 9 → ID 8 relabel (확정)

`stage_debug_picker.gd` STAGE_OPTIONS는 현재 7→9로 건너뛰고 ID 8이 비어 있으며 ID 9 =
미노타우로스 placeholder(`implemented = stage_id<=7`). 코드베이스 전체가 연속 번호
(current_stage+1 진행, `_get_stage_offset=stage-1`, 라우터 1..7 next=8,
`DEMO_STAGE_SEQUENCE_END`)를 쓰므로 **ID 9 → ID 8로 relabel**한다. KEY_8은 이미
range(1,10)로 선택되고 KEY_9는 무해한 no-op이 된다. (ID 8 갭 채우고 ID 9 유지 = 중복
placeholder → 비권장.)

---

## 2. 스테이지 디스패치 2층 구조 (반드시 둘 다)

1. **라우터** `stage_runtime_router.gd` `STAGE_MODULES`: stage int → {role: module_key}.
   보스 스테이지는 6 role(actor_renderer, boss_actor_renderer, pillar_scene_drawer,
   stage_background, playfield_renderer, boss_skill_hud_renderer). 스테이지 1~4는 3 role만.
2. **카탈로그** `resources/gameplay_stage_module_catalog.gd` MODULES: module_key → res:// 경로.
   `gameplay_module_registry.get_instance()`가 이 경로로 로드. **키 누락/오타 = 조용한
   unknown-key no-op → 역할이 조용히 사라짐**(폴백 필러 / 초록 박스). 라우터 키 = 카탈로그 키
   바이트 동일 필수.

preload 체인(카탈로그 불필요, 단 파일은 존재해야): `boss_skill_hud_assets`(hud_renderer가
preload), `prebattle_overlay_host`(presentation), `vfx_texture_cache`(playfield_renderer).

**각 새 .gd는 커밋된 `.uid` 형제 필요** — 비헤드리스 Godot import 패스로 .uid/.import 생성해야
문자열-키 레지스트리/preload가 해석됨([[reference_godot_nonheadless_import_materialization]]).

---

## 3. 보스는 self-owned (battle_resources 미등록)

Stage 6/7 보스처럼 **보스 스프라이트 시트는 `stage8_minotaur_boss_actor_renderer.gd`가
자체 소유**(`SHEET_PATHS` 9키, `ProjectResourceLoader.load_imported_texture`, 4x2 8프레임
슬라이서, 고정 `DRAW_SIZE`, 우선순위 `defeat>victory>stun>dash>attack>walk>idle`).
`battle_resources._get_stage_boss_texture_specs`는 stage6/7을 커버하지 않으므로 **Stage 8도
여기 추가하지 말 것**. victory/defeat/stun을 자체 renderer에 번들하지 않으면 결과화면이
코드네이티브 박스로 폴백된다(조용한 갭).

---

## 4. 에셋 갭 분석

### 보스 스프라이트 (9키 계약: walk_left/right, idle, attack, dash_left/right, victory, defeat, stun)
| 상태 | 소스 | 조치 |
|---|---|---|
| walk, attack, dash | 백업 83×92 4x2 (단면, FLUX 유래) | L/R 분리(별도 시트 or UV-swap 미러) 후 이식. AutoSprite 재생성 권장 |
| turn | 백업 존재 (aux, stage7엔 turn키 없음) | 선택 — 프론트 워크면 hop 폴백 가능 |
| **idle, victory, defeat, stun** | **없음** | **AutoSprite 신규 생성 필수(하드 블로커)** |

혼합 품질 주의: FLUX 유래 기존 시트 + AutoSprite 신규 시트 = "mixed readability class" reject
위험 → 약한 시트를 상향 재생성. 바디사이즈: 백업 83×92 vs repo 72×80 상충 + 문서상
대형-프레임 예외 → Godot `DRAW_SIZE` 하나 확정 + per-boss override 근거 기록.

### 파르테논 배경/필러 (백업 재사용 가능, JPEG→PNG 변환 필요)
`stage9_field.png`(센터 필드), `stage9_pillar_left.jpeg`(좌필러/우=flip),
`stage9_frieze_top/bottom.jpeg`(상/하 프레임), `stage9_outer_pillar_scene.jpeg`(통합 크롬),
`stage9_flame_sheet.jpeg`(횃불 아틀라스). **주의**: stage7 pillar_background는 양옆
레터박스 SIDE rect + 센터 필드만 그리고 **상/하 레터박스 draw 경로가 없다**. 원본
outer-scene은 상/하 프리즈 포함 풀스크린 크롬 → **상/하 스트립 draw 경로 추가 or 프리즈 생략**
결정 필요(§7). 80px 인셋 금지(풀 760×750 캔버스, [[feedback_godot_playfield_letterbox_reality]]).

### BGM
없음(`assets/bgm`는 stage7_akamu_bgm.ogg가 최신). Python은 Stage 4 차용. **차용 vs 신규 트랙 결정**(§7).

---

## 5. Core 크로스커팅 편집 체크리스트 (필수 보일러플레이트)

grep `stage7_akamu` (godot/scripts 75파일)이 미러링할 권위 목록. 필수:

1. `stage_runtime_router.gd` — `STAGE_MODULES[8]` 6-role (키스톤).
2. `resources/gameplay_stage_module_catalog.gd` — stage8_minotaur_* 키 등록 (키스톤).
3. `battle_scene_match_event_driver.gd` — `DEMO_STAGE_SEQUENCE_END: 7→8` (안 하면 stage7 승리가
   stage8로 진행 안 됨, picker로만 도달).
4. `stage_debug_picker.gd` — id 9→8 relabel, `implemented<=8`, footer, prewarm dispatch case 8,
   `STAGE_RESET_MODULE_KEYS`.
5. `battle_update_boss_ai_context_builder.gd` — `current_stage==8` 머지.
6. `battle_draw_scene_context.gd` + `battle_draw_actor_context.gd` — `==8` 상태 주입/머지.
7. `battle_update_stage_runtime_deps_builder.gd` — `_append_stage8_deps`(include_all
   **peek_only=true** + `8:` case). 370ms 콜드-인스턴스 트랩.
8. `battle_effects_update_controller.gd` — `==8` per-frame `state.update(delta,context,deps)` 머지
   (**누락 시 모든 stage8 스킬 타이머/쿨다운/게이지 조용히 동결**).
9. `ball/ball_update_controller.gd` + `ball_dependency_context.gd` — `==8` 충돌/round dep
   (보스가 공 반사 기믹 가질 때만; round dep는 항상).
10. 리셋 3-경로(대칭 필수): `match_reset_controller.reset_stage_state` +
    `stage_clear_result_runtime_context_data.reset_stage8_for_result`(+ handler passthrough) +
    picker `STAGE_RESET_MODULE_KEYS`.
11. `match_score_event_controller.gd` — score-carry/excitement/round-clear (보스가 점수 반응 시).
12. Prewarm: `battle_boot_resource_prewarm_controller.gd`(STAGE8 키+step fn),
    `battle_scene_update_prewarm_key_sets.gd`(+ driver),
    `battle_pso_prewarmer.gd`(필드-텍스처 step), `battle_loading_screen_renderer.gd`(로딩 아트).
13. `audio/game_audio.gd` — STAGE8 BGM const + stream-path map + player setup +
    play/prime_stage_bgm(8).

**조건부(미노타우로스가 해당 기믹 가질 때만)**: `boss_ai_state.gd`(scripted-position 키),
`battle_frame_flow_controller/deps_builder`(awakening/freeze), prebattle 4파일
(`intro_flow_lifecycle`, `modal_gate_controller`, `intro_frame_controller`, `teardown_lifecycle`).
Python 미노타우로스는 스텁이므로 첫 패스엔 대부분 불필요.

기존 하드코딩-리스트 스모크도 편집(신규 파일만으론 부족): `refactor_status_brief_smoke.gd`
STAGE_ROUTE_EXPECTATIONS, `lingpet_rail_card_shared_smoke.gd`,
`active_item_boss_skill_cooldown_pause_smoke.gd`, `boss_skill_card_hud_spec_smoke.gd`,
shrink-scale seal `_verify_bespoke_stage_renderers_consume_shrink`.

---

## 6. 슬라이스 계획 (repo 컨벤션 6+2, 미완성 레퍼런스 반영)

각 슬라이스 DONE 공통(비협상): (a) 실제 deps builder/update 경로를 end-to-end 구동하는
`*_smoke.gd`(상태 메서드 직접호출 금지), (b) 반증검증(인플레이스 Edit 토글로 RED→복원→GREEN,
git reset/checkout/stash 금지), (c) `*_visual_smoke.gd` 실 draw + 윈도우드 픽셀 QA
1280×720/1920×1080, (d) run_warning_scan 0 / headless load PASS / git diff --check PASS,
(e) 기존 하드코딩 스테이지-리스트 스모크 갱신.

- **Slice 1 — 부팅 가능한 셸 + 3-경로 deps 게이트** — ✅ **코어 완료(2026-07-12, 검증됨)**.
  - 새 모듈 9종: `godot/scripts/stages/stage8/stage8_minotaur_{state, actor_renderer,
    boss_actor_renderer, playfield_renderer, pillar_background, pillar_scene_drawer,
    boss_skill_hud_renderer, boss_skill_hud_assets, vfx_texture_cache}.gd` (stage7 계약 보존
    thin 클론, 코드네이티브 플레이스홀더 렌더, reserved-asset 경로 미배선/ResourceLoader.exists 가드).
  - Core 배선 14파일: 라우터 STAGE_MODULES[8], 카탈로그 7키, DEMO_END 7→8, picker(relabel 9→8·
    implemented≤8·footer·prewarm 분기+`_prewarm_stage8_selected_modules`·RESET 키), deps builder
    (_append_stage8_deps: include-all peek + case), effects update(==8 state.update 머지),
    boss AI ctx(==8), draw scene/actor ctx(==8), 리셋 3경로(match_reset + reset_stage8_for_result +
    handler passthrough), ball_dependency_context 4곳, playfield effects drawer [1..8].
  - 씰: `stage8_minotaur_wiring_smoke.gd`(effects/ball/include-all 3경로 present + 비-8 omission +
    라이프사이클 계약) — 반증검증 RED(case-8 제거)→복원 GREEN. 기존 스모크 갱신:
    `stage_actor_transient_cleanup_smoke`(FakeRouter/registry stage8), `refactor_status_brief_smoke`
    STAGE_ROUTE_EXPECTATIONS[8].
  - 검증: parse 23파일 OK, import .uid×9, **headless load check PASS**, **warning scan 0경고(2589)**,
    기능 스모크 8종 PASS. (`refactor_status_brief_smoke`는 문서-카운트 부킹만 RED = 외래 WIP 문서 drift,
    route 체크 green, 미수정.)
  - **픽셀 QA 완료**: `stage8_minotaur_slice1_visual_smoke.gd`(윈도우드 SubViewport→PNG) — 아쿠아마린
    필드 풀캔버스(인셋 없음) + 센터 스타디움 마커 + 파르테논 기둥(레터박스) + 미노타우로스 코드네이티브
    실루엣(뿔·붉은 눈) 렌더 육안 확인. headless 스위트 안전(픽셀 캡처 skip).
  - 의도적 defer(아트 대기): boot-prewarm/PSO/loading 스테인드글라스, update-prewarm-keyset+driver — Slice 3~4에서.
- **Slice 2 — 보스 스프라이트 런타임** (하이브리드: 임시 FLUX 이식 → AutoSprite 교체, 2026-07-13 결정).
  - ✅ **Step A 임시 FLUX 이식 완료**: 백업 tauren walk(1672×940)/attack·dash(1536×768) PNG를 검은배경
    누끼(corner-color flood-fill TOL 12, 아웃라인 (10,8,8) 보존) + 셀별 L/R 미러(§13.1.1) → 9키
    `res://assets/sprites/bosses/stage8_minotaur/stage8_minotaur_boss_*.png`. idle/victory/defeat/stun은
    walk 누끼 임시 재사용(플레이스홀더 박스 방지). import→prewarm→**윈도우드 픽셀 QA**: 진짜 미노타우로스
    스프라이트가 어두운 필드 위 깨끗한 누끼로 렌더 확인. **provenance=FLUX(임시), 최종=AutoSprite.**
  - ✅ **Step B AutoSprite 전체 재생성 완료**(2026-07-13, ~40크레딧): 백업 누끼 프레임 1장을 참조로
    AutoSprite 캐릭터 `Minotaur Stage8 Boss v1`(id `cmri1qbsn004719u2mlxup6fl`) 업로드(무료) →
    sidescroller 애니 생성 idle/walk/attack/run(=dash)/custom(victory·defeat·stun), 각 256×256·8프레임·
    3열 turbo·removeBg ultra. AutoSprite 3열 → **4×2 재배치**(프레임순서 보존, `stage8_autosprite_finalize.py`)
    + walk/dash 셀별 L/R 미러(§13.1.1) → 9키 PNG 선적 교체(임시 FLUX 전량 대체 = FLUX+AutoSprite 혼합 없음).
    **QA**: 7시트 어두운배경 몽타주(정체성 일관·front-biased 워크·모션 정확), idle 곤봉 누락 1건 재생성으로
    수정(곤봉 포함, 세트 일치), **인게임 렌더**(AutoSprite 미노타우로스 깨끗한 누끼·적정 스케일). DRAW_SIZE
    128×142. **provenance**: character `cmri1qbsn004719u2mlxup6fl`; sheets idle`cmri2968j` walk`cmri21rsf`
    attack`cmri20jqg` dash`cmri21ozx` victory`cmri216t4` defeat`cmri20w6h` stun`cmri222sc`.
  - ⏳ 잔여(폴리시): 퍼-포즈 라이브 QA(walk/attack/victory/defeat/stun 인게임 구동), §17.4 feet-anchor
    정규화 여부 판단(포즈 간 바디 바운스 시), walk_left/dash_left 네이티브 생성 여부(현재 곤봉 반대어깨 미러).
- **Slice 3 — 파르테논 필러/배경** — ✅ **코어 완료(2026-07-13)**.
  - 실제 레터박스 geometry 확정: 뷰 2020×1246, 게임캔버스 ~1161×1146, **side 마진 ~430px(넉넉)**,
    상/하 ~50px(얇음) → side-heavy. `battle_view_layout.build_game_layout`가 진실.
  - 에셋 변환: `stage9_field.png`(대리석 그리스 코트) → `res://assets/sprites/hud/
    stage8_minotaur_center_field_imagegen_v1.png`(1152²); `stage9_outer_pillar_scene.jpeg`(좌+우
    이오니아 기둥+횃불+크롬 통합) → `stage8_minotaur_pillar_base_imagegen_v1.png`(1440²). `stage8_
    parthenon_convert.py`.
  - 배선: `_draw_side_base`에 base_texture cover-crop 분기 + `_draw_cover_texture_in_rects` 헬퍼
    (BASE를 뷰 전체 cover-fit 후 side rect 영역만 샘플 → 좌/우 기둥이 좌/우 마진에, 검은 센터는
    미출력 필드영역으로). field_texture는 기존 `_draw_field_base` 분기가 이미 사용. prewarm은 기존
    ResourceLoader.exists 가드 스텝머신이 처리.
  - 비주얼 스모크 실 side-heavy 레이아웃(1440×888)+pillar prewarm+필드/기둥/보스 픽셀 씰. **인게임
    렌더 QA**: 아쿠아마린 이오니아 기둥+금 횃불(양옆)+대리석 그리스 코트 바닥(중앙)+센터마커+미노타우로스.
  - ⏳ 폴리시: 기둥-필드 사이 얇은 검은 recess 타이트닝, 상/하 프리즈 밴드(선택), motion/reactive
    아틀라스(score-reactive props, 현재 code-native 폴백), PSO 프리웜 스텝.
- **Slice 4 — BGM + 로딩 + 결과**. BGM 결정 배선 + 로딩 아트(스테인드글라스) + 결과 플로우
  (victory/defeat 시트 공유).
- **Slice 5 — 보스 게임플레이 설계(여기서 완성)**. 시그니처 메커니즘 신규 설계
  (고어 차지=패들 스크립팅 6불변, or 대지강타 지진, or 미궁 레인 제한, or 각성). 보스스킬-카드 HUD는
  이 슬라이스(shared `BossSkillCardHudSpec.draw_skillcard_gauge_fill` cover-crop). tear-gas 쿨다운
  debuff 키 소비 필수.
- **Slice 6 — 폴리시/QA 게이트**. BattlePerf(<60fps 0%), 첫진입 100ms 히치 체크, 스킬-카드 squish 씰.

---

## 7. 설계 결정 (2026-07-12 확정)

1. **보스 전투 시그니처 = 대지 강타(지진)** — ✅ 지금 설계. 미노타우로스 착지/스톰프 →
   충격파 지진 해저드 + 화면 흔들림. `stage8_minotaur_state`가 지진 게이지/발동/충격파를
   소유. 상세 설계는 §7.1.
2. **스프라이트 = 백업 4시트 이식 + 누락 4종 AutoSprite** — ✅. 백업 walk/attack/dash를
   L/R 분리 이식, idle/victory/defeat/stun만 AutoSprite 신규. 혼합 품질 시 약한 시트 상향.
3. **BGM = Stage 4 차용(임시)** — 기본값(원본과 동일). 신규 트랙은 후속.
4. **필러 크롬 = 파르테논 풀 크롬(상/하 프리즈 포함)** — 기본값(무대 정체성). Slice 3에서
   side-only 폴백 여부 재검토.

### 7.1 대지 강타(지진) 시그니처 설계 스케치 (Slice 5)

- **발동**: 보스 지진 게이지 충전(랠리/피격) → 임계 시 미노타우로스가 착지-스톰프 모션(attack
  시트 재활용 or 신규) → 바닥 충격파.
- **해저드**: 지면 균열 충격파가 좌우로 퍼지며 플레이어 패들 제어/이동에 페널티(스턴 짧게 or
  이동 슬로우 or 넉백) — 정확한 CC는 밸런스 결정. 스크린 셰이크 + 파편 VFX.
- **트랩 준수**: (a) tear-gas `active_item_boss_skill_cooldown_paused` 소비 필수, (b) 스킬-카드
  HUD는 shared `BossSkillCardHudSpec.draw_skillcard_gauge_fill` cover-crop, (c) per-frame
  확률 롤 금지(기회당 lock), (d) CC는 px/frame→Godot 단위 변환·프레임/초 확인, (e) 리셋 3-경로.
- **패들-스크립팅 아님**: 지진은 보스 위치를 스크립팅하지 않음(제자리 스톰프) → 6불변 패들-스크립팅
  트랩은 해당 없음. 단 스톰프 순간 보스 y 고정/모션은 authored, boss_ai freeze 짧게 필요할 수 있음.

---

## 8. 리스크 (godot_runtime_traps 트랩 매핑)

- 조용한 unknown-key no-op(라우터⊄카탈로그) → 역할 소멸.
- Hot-Path Lazy Init 370ms(include_all peek_only) / 첫프레임 히치(boot prewarm 동반).
- Reserved-asset per-frame re-stat(미생성 경로를 draw/prewarm에 배선 금지 — 플레이스홀더 or 같은 슬라이스에 아트+file_exists).
- 리셋 3-경로 누락 → 보스스킬/소환체/VFX 스테일 누수(홍련/friend_moles 클래스).
- effects `==8` per-frame 누락 → 스킬 타이머 조용히 동결.
- tear-gas debuff 키 미소비 → active-item 무시(Stage 6 테트리서 사건).
- 스킬-카드 stretch squish(shared cover-crop 헬퍼 경유).
- boss_paddle_shrink_scale를 stage8 자체 draw size에 소비(난쟁이마술 클래스).
- 보스-패들-스크립팅 6불변(라운드 boss_y 정규화 누락 → 라운드종료 시 보스 플레이어 옆 고착).
- 미완성 레퍼런스 → 스킬/AI 스펙 미정, state 모듈은 설계 태스크.
