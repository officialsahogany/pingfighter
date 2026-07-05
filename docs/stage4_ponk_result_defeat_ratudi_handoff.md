# Stage 4 Ponk 결과화면 패배 "라투디" (Live2D) 핸드오프

> ⚠️ **정정 반영(사용자, 완료 후)**: §2의 "가면 OFF 맨 오니얼굴" 초안 디렉션은 **뒤집혔다.**
> 최종 = **금색 오니 가면 ON + 우측 시선**(다른 결과 라투디처럼), **인게임 SD 캐릭터가 레퍼런스**.
> Codex가 이 정정대로 v2 완성:
> `stage4_ponk_result_defeat_masked_right_{live2d_pingpong,click_reaction}_98f_autosprite_v2_realesrgan_animev3_hq1152.png`
> + 29파일 런타임 배선. **Claude 적대리뷰 PASS(코드결함 0, field_payload set() 트랩 회피 확인).**
> 미커밋. 잔여 = 인게임 픽셀 QA(프레이밍·우측시선)·커밋. 아래 §2 맨얼굴 서술은 히스토리로만 읽을 것.

상태: **설계·디렉션·정체성 잠금·파이프라인 아카이브 = Claude 완료 / 실행(Codex imagegen 원화 + AutoSprite + Real-ESRGAN + 런타임 배선) = Codex.**
분담 근거: [[feedback_claude_vs_codex]] · [[feedback_design_slice_review_division]].
이 문서가 단일 소스. 라투디 = "라이브2D" = 결과화면 애니메이션 보스 액터 시트.

---

## 0. 한 줄 목표

스테이지4 결과화면(스테이지 클리어)에서 보스 **퐁크**가, 스테이지1(달지)/2(악어장군)/3(멘헤라)처럼
**패배해서 억울해하는 Live2D 패배 시트(base defeat loop) + 클릭 리액션 시트(click 라투디)** 로
등장하게 만든다. 지금은 이 페어가 없고 임시 pulse 폴백만 있다.

---

## 1. 현재 상태 vs 타깃

**현재 (스테이지4 = pulse 폴백, 패배 아님):**
- 결과화면이 퐁크 **idle** 시트(`stage4_ponk_idle_sheet_imagegen_v1.png`)를 단순히 부드럽게
  맥동(pulse)시키는 폴백으로만 그린다. **패배/억울 포즈가 아니다.**
- 경로: `stage_clear_result_actor_presenter.gd` → `_get_stage_result_fallback_config(4)` →
  `_draw_stage_result_fallback_actor` → `StageClearResultPulseActorDrawHelper.draw_stage4_ponk_result_fallback`.
- 스테이지5(홍련)/6(테트리서)도 같은 pulse/단일시트 폴백 계열(스테이지6은 defeat 시트 단일).

**타깃 (스테이지4 = 스테이지3 패턴, Live2D 패배+클릭):**
- 스테이지2/3처럼 **패배 Live2D 루프 시트 + 클릭 리액션 시트** 2장 페어.
- 경로: presenter의 `draw_defeated_boss()`에 **`current_stage == 4` 분기 신설**
  (스테이지3 `draw_stage3_defeated` 블록을 그대로 본뜬다). pulse 폴백에서 제거.
- 클릭하면 클릭 리액션 시트로 전환됐다가 base 루프로 복귀(스테이지2/3와 동일한
  `StageClearResultClickReactionState` 상태머신 공유).

---

## 2. 디자인 디렉션 (Claude 잠금 — 재론 금지, 그대로 구현)

퐁크 = 스테이지4 보스. **명상하는 오니(鬼) 수도승**. 각성 시 금색 오니 가면 + 발광 눈(몽환포영).
참고: [[project_stage4_ponk_monghwan_poyeong]].

- **각성 해제 = 가면 벗김.** 패배 라투디는 **금색 오니 가면을 벗은 맨 잿빛 오니 얼굴**로 그린다.
  발광 눈 없음. (승리 시트 = 금가면 착용 / 패배 라투디 = 맨 얼굴 → 승패 대비가 자연스럽다.)
  근거: 승리 시트 `stage4_ponk_boss_victory.png`가 금가면+발광, idle 시트가 맨 얼굴.
- **감정 = 억울(자존심 상한 분함).** 멘헤라의 "cute-sad 눈물"과 달리 퐁크는
  **분한 눈물 + 이 악문 송곳니 + 찌푸린 눈썹 + 주먹 불끈** 의 코믹한 sore-loser 분함.
  명상이 깨져 결가부좌가 무너진 채 주저앉은 슬럼프. 부상/피/상처 없음.
- **정체성 필수 유지**(§3). 특히 **검보라 장발**은 실루엣 핵심 — 반드시 얼굴을 감싸고
  길게 흘러내리게(짧게/생략 금지).
- **스타일 = 폴리시드 아니메 키아트**(인게임 16비트 픽셀 아님). 스테이지1/2/3 패배 라투디와
  같은 프리미엄 결과화면 일러스트 폴리시. Live2D-friendly 분리 실루엣.

---

## 3. 퐁크 정체성 스펙 (원화 프롬프트용 — 인게임 시트에서 확정)

레퍼런스: `godot/assets/sprites/stage4/stage4_ponk_idle_sheet_imagegen_v1.png`(맨 얼굴),
`stage4_ponk_boss_victory.png`(금가면 각성). 아래를 모두 지킬 것:

| 요소 | 스펙 |
|---|---|
| 피부 | 잿빛(ash-gray) |
| 눈 | **삼안** — 이마에 작은 세로 제3의 눈, 흰 다이아몬드 마크 |
| 눈썹/입 | 두껍고 찌푸린 눈썹, 넓은 송곳니 입 + 아래 짧은 두 엄니(tusks) |
| 머리 | **길고 풍성한 검보라(dark purple-black) 장발**, 가운데 가르마, 양 어깨 아래로 길게 흘러내림 (정체성 핵심) |
| 보관 | 뿔 달린 티아라 — 갈색+금색 곡선 뿔 2개, **빨강 중앙 보석 + 파랑 측면 보석** + 이마 작은 보석 |
| 의상 | 흰색 수도복(한복/기모노풍) + 두꺼운 **금테** + 금색 sash 벨트 |
| 장신구 | 가슴 가로지르는 **금색 염주(mala) 목걸이 겹겹** |
| 손 | 연보라-회색 |
| 가면 | **패배 라투디에서는 OFF (맨 오니 얼굴). 금가면·발광 눈 금지.** |

**포즈(base defeat)**: 결가부좌 무너진 채 바닥에 주저앉음, 한 손 주먹 불끈(무릎 위),
다른 손 바닥 짚음, 어깨 움츠려 앞으로 숙임, 억울한 분한 눈물, 이 악문 송곳니.
**프레이밍**: 풀바디 좌식, 살짝 아래 배치, 뿔/장발/손/도복 hem 주위 넉넉한 여백(애니 여유),
캐릭터가 캔버스 ~70% 점유, 닫힌 실루엣, 크롭 금지. **크로마키 = 순수 초록 #00ff00**
(검보라 머리·연보라 손이 마젠타와 충돌하므로 그린 사용, 멘헤라도 그린).

---

## 4. 참고 후보 원화 (Claude가 Gemini로 뽑은 방향 레퍼런스)

Codex는 **Codex 빌트인 image_gen**으로 원화를 재생성한다(정식 파이프라인 = 멘헤라와 동일한
`built-in image_gen` 경로). 아래 2장은 **방향/구도/표정 레퍼런스**로만 사용:

- `d:/tmp/ponk_result_defeat_ratudi_ref/ponk_defeat_wonhwa_B_longhair_gemini_RECOMMENDED.jpeg`
  → **추천 방향.** 검보라 장발 복원, 삼안·뿔보관·흰금도복·금염주·억울 눈물·결가부좌·주먹+바닥손
  전부 정합. 이 구도/표정을 재현할 것.
- `d:/tmp/ponk_result_defeat_ratudi_ref/ponk_defeat_wonhwa_A_shorthair_gemini.jpeg`
  → 대안(장발 약함, 브루딩 강함). 장발 누락이 정체성 갭이라 B 추천.

**주의**: 위 JPEG는 Gemini 산출물(참고용). 최종 원화는 Codex image_gen 그린 크로마키 소스로
새로 만들고, 멘헤라처럼 `remove_chroma_key.py`로 누끼 → alpha/magenta/meta 버전 생성.

---

## 5. 정확한 에셋 파이프라인 (스테이지3 멘헤라 = 검증된 템플릿, 그대로 복제)

레퍼런스 파일(모두 `godot/assets/sprites/stage3/`):
- 원화: `menhera_result_defeat_original_art_imagegen_v1_{source_chromakey,alpha,magenta}.png` + `_meta.json`
- base 루프: `menhera_result_defeat_live2d_pingpong_98f_autosprite_v1_realesrgan_animev3_hq1152.png` + `_pipeline-meta.json`
- 클릭: `menhera_result_defeat_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1152.png` + `_pipeline-meta.json`
- 달지 매니페스트: `godot/assets/sprites/stage1/dalji/..._manifest.json`

**단계 (base defeat + click 각각):**

1. **원화(키아트)** — Codex 빌트인 image_gen. §3 스펙, 그린 #00ff00 크로마키, 폴리시드 아니메
   (픽셀 아님), ~70% 점유, Live2D 분리 실루엣.
2. **크로마키 제거** — `~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py`
   (auto_key=border, soft_matte, despill). → `_source_chromakey.png` / `_alpha.png` /
   `_magenta.png` + `_meta.json`(canvas_size, alpha_bbox, transparent_corner_alpha 0, prompt 기록).
3. **AutoSprite** — `create_asset`(magenta 소스 업로드) + `animate_asset`. quality `legendary`,
   `remove_bg: "ultra"`. 49프레임 7×7 512px 시트 반환.
   - **base defeat (looping=true)** 애니 프롬프트 예:
     `"Defeated result-screen idle loop: sitting slumped cross-legged, indignant teary, subtle breathing, tiny trembling frustrated scowl with gritted fangs, long dark hair strands gently sway. Keep pose fixed, no standing, seamless."`
   - **click reaction (looping=false)** 애니 프롬프트 예:
     `"Click upset reaction: seated defeated pose, indignant flinch/outburst — fangs bare wider, third eye twitches, fists clench and tense, long hair bounces, frustrated tears shake, then settle back. No standing."`
4. **49f→98f 핑퐁** — deterministic reverse `0..48,48..0` (멘헤라 `temporal_layout`).
5. **알파-블리드 → Real-ESRGAN** — `tools/realesrgan/realesrgan-ncnn-vulkan.exe`,
   model `realesr-animevideov3`, scale 4(멘헤라 파이프라인 실측; ★그러나 [[reference_lingpet_cutin_procedural_crisp]]
   경고 = x4 과업스케일 소프트함 주의. 멘헤라 시트는 512→x4→hq1152 다운샘플로 소스셀 512라 결과 OK.
   퐁크도 소스셀 512로 맞추면 동일. 애니메 컷인처럼 원래 큰 셀을 x4하는 게 아니라, 512 소스를 리팩하는
   경로라 안전). unsharp(radius 1.0, percent 55, threshold 3).
6. **hq1152 리팩** — 최종 그리드 14열×7행 = 98프레임, 셀 1152px. base는 content_scale 1.0,
   **click은 content_scale 0.92**(후반 프레임이 셀 우측 엣지에 닿아 edge-safe 필요 — 멘헤라 클릭과 동일).
   최종 시트 16128×8064. alpha_clip 15. Real-ESRGAN 후 hot-magenta fringe 제거
   (`alpha>0 and rgb=(>245,<15,>245) → alpha 0`).
7. **런타임 임포트 정책** — `.import`에 `process/size_limit=12544` → imported 셀 896px
   (멘헤라와 동일, GPU 업로드 절감). 로더 = `ProjectResourceLoader.load_imported_texture`.
8. **QC** — corner_alpha 0, edge_touch 프레임 0, visible_magenta 0, dark/light 프리뷰 PNG 생성,
   `_pipeline-meta.json` 기록(autosprite job_id·프롬프트·postprocess·sha256).

**파일명/경로 (신규, `godot/assets/sprites/stage4/`):**
- 원화: `stage4_ponk_result_defeat_original_art_imagegen_v1_{source_chromakey,alpha,magenta}.png` + `_meta.json`
- base 루프: `stage4_ponk_result_defeat_live2d_pingpong_98f_autosprite_v1_realesrgan_animev3_hq1152.png`
- 클릭: `stage4_ponk_result_defeat_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1152.png`
- 각 시트에 `.qc.json` + `_pipeline-meta.json` + `_{dark,light}_preview.png`

**AutoSprite 필수 소스 규칙**: 최종 시트는 반드시 AutoSprite 산출 프레임 기반
([[feedback_imagegen_gemini_not_flux]]: 시트=AutoSprite). 원화 still만 image_gen.

---

## 6. 런타임 배선 델타 (스테이지4를 스테이지3처럼)

핵심 = presenter의 pulse 폴백에서 스테이지4를 빼고, **Live2D defeat+click 분기**를 신설.
스테이지3(`draw_stage3_defeated`) 경로를 1:1로 본뜬다.

### 6.1 에셋 로더 `stage_clear_result_asset_loader.gd`
- 신규 상수: `STAGE4_PONK_BOSS_DEFEAT_LIVE2D_SHEET_PATH`,
  `STAGE4_PONK_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH`(위 파일명).
- `TEXTURE_KEYS`에 `stage4_ponk_boss_defeat_live2d_sheet`,
  `stage4_ponk_boss_defeat_click_reaction_sheet` 추가 + `PREWARM_ASSET_STEP_COUNT` 증가.
- `IMPORT_PREFERRED_TEXTURE_KEYS`(둘 다 true) + `TEXTURE_MESSAGES` 추가.
- `get_default_result_asset_path_config()` + `get_result_asset_paths()`의 `stage_id == 4` 분기에서
  기존 `stage4_ponk_result_sheet`(pulse) 대신(또는 함께 폴백으로) 신규 2키를 세팅.
  → **폴백 정책**: 신규 defeat 시트가 있으면 Live2D 경로. 시트 null이면 기존 pulse idle 시트로
  안전 폴백 유지 권장(스테이지3은 폴백 없이 {} 반환이지만, 회귀 안전상 pulse 폴백 남겨도 됨 — Codex 판단).

### 6.2 presenter `stage_clear_result_actor_presenter.gd`
- `draw_defeated_boss()`에 **`current_stage == 4` 분기 신설**(스테이지3 블록 복제):
  `draw_stage4_ponk_defeated(...)` 호출, `get_boss_defeat_reaction_state(timer, stage4 click_timer, stage4 base_frame)`
  + `BOSS_DEFEAT_LIVE2D_GRID_COLS/CELL_SIZE` + alpha 0.98.
- `_get_stage_result_fallback_config()`의 `4:` 케이스는 제거(또는 시트-null 폴백으로만 남김).
- `get_defeated_boss_draw_context()`에 stage4 live2d 시트/클릭 파라미터 추가(이미 있는
  `stage4_ponk_result_*` 키 자리를 live2d 페어로 확장).

### 6.3 draw 헬퍼 `stage_clear_result_actor_draw_helper.gd` + `stage_clear_result_live2d_actor_draw_helper.gd`
- `draw_stage4_ponk_defeated(...)` 추가(스테이지3 `draw_stage3_defeated` 복제; 내부에서
  `StageClearResultLayoutHelper.get_stage4_boss_result_draw_rect` 사용 + `draw_reaction_sheet`).
- 클릭 판정: `get_boss_defeat_click_attempt(stage_id, ...)`가 현재 stage_id==3만 rect 특수화 →
  **stage_id==4 rect 분기 추가**.

### 6.4 레이아웃 `stage_clear_result_layout_helper.gd`
- `get_stage4_boss_result_draw_rect(view_size, scale)` 추가. 퐁크는 좌식 와이드 실루엣이므로
  스테이지3 rect를 출발점으로 하되, 좌식 캐릭터가 화면에 자연스럽게 앉도록 인게임 픽셀 QA로 미세조정.

### 6.5 클릭 핸들러 / 리액션 업데이트
- `stage_clear_result_actor_click_handler.gd` + `stage_clear_result_actor_reaction_update_handler.gd`가
  스테이지2/3 boss-defeat 클릭·리액션 타이머를 다루는 방식으로 **스테이지4도 boss-defeat 계열로 라우팅**.
  현재 스테이지4는 fallback actor 클릭 경로(`stage4_ponk_result_click_*`)를 탄다 → boss-defeat 경로로 이동.
- 필드 스키마: presenter의 `_stage4_ponk_result_click_rect` 등 기존 필드 재사용 가능하나,
  boss-defeat 계열 타이머 필드(`stage4_boss_defeat_click_reaction_timer`,
  `stage4_boss_defeat_click_transition_base_frame`)로 정리 권장. ★신규 owner 필드는
  `BattleSceneState.DEFAULT_VALUES` 선언 필수([[feedback_godot_dynamic_set_payload_guard]] /
  Owner-Field Schema 트랩 — set()이 조용히 no-op).

### 6.6 프리웜 / 임포트
- `battle_boot_resource_prewarm_controller.gd` / `stage_clear_result_scene_shell_prewarm_state.gd` /
  `battle_scene_update_prewarm_key_sets.gd`에서 스테이지4 결과 프리웜 키셋에 신규 2시트 반영
  (16128×8064 대형 시트 = VRAM 비압축 업로드 비용 있음, [[project_godot_stage_transition_freeze]] 참고 —
  size_limit 12544 imported 경로로 프리웜).
- `.import`: 두 시트 `process/size_limit=12544`.

### 6.7 참조 무결성 체크(완결성)
스테이지4 결과 액터를 다루는 모든 소비자 확인(누락 시 스테일):
`stage_clear_result_scene.gd`, `stage_clear_result_actor_draw_scene_handler.gd`,
`stage_clear_result_config_scene_handler.gd`, `stage_clear_result_update_scene_handler.gd`,
`stage_clear_result_fallback_actor_scene_context_builder.gd` vs
`stage_clear_result_live2d_boss_scene_context_builder.gd`(스테이지4를 fallback→live2d 빌더로 이동),
`stage_clear_result_fallback_actor_status_builder.gd` vs `stage_clear_result_live2d_boss_status_builder.gd`.

---

## 7. QA 게이트

- **원화**: 그린 크로마키 corner alpha 0, 누끼 후 검보라 장발/금테/삼안/염주 엣지 살아있는지
  (누끼 stop-and-ask, 스킬 §11.5). alpha bbox 엣지 비접촉.
- **시트**: 98프레임 corner_alpha 0, edge_touch 0, visible_magenta 0, dark+light 프리뷰에서
  정체성/억울 표정 읽힘. base=seamless 루프, click=발끈 후 settle.
- **★인게임 픽셀 QA(필수, 상태 스모크 불충분)**: 실제 스테이지4 클리어 결과화면에서
  (a) 퐁크가 억울 패배 포즈로 등장, (b) 클릭 시 리액션 전환→복귀, (c) 좌식 실루엣이 배경/스크롤
  패널과 자연스럽게 앉음, (d) 프레이밍/스케일이 스테이지3 대비 이질감 없음. 윈도우드 캡처.
  라이브 경로 확인 = [[reference_godot_live_path]](실행 인스턴스 --path).
- **스모크**: `stage_clear_result_*_smoke.gd` 계열에 스테이지4 live2d defeat+click 분기
  단언 추가(스테이지3 스모크 케이스 복제). fallback→live2d 라우팅, click rect 분기,
  owner 필드 스키마 선언, 프리웜 키 포함.
- **반증검증(SAFE, in-place 토글)**: 신규 스모크가 버그 코드에서 FAIL함을 in-place Edit
  토글로 증명(예: stage4 live2d 분기 제거하면 pulse 폴백으로 떨어져 defeat 시트 미사용 FAIL).
  ★`git reset/checkout/stash` 금지(WIP 파괴) — [[feedback_workflow_mutating_verify_shared_tree]].

---

## 8. 커밋/백필 노트

- 커밋 스코프: 신규 스테이지4 result 에셋(원화 3버전 + 시트 2 + 프리뷰/qc/meta) + 런타임 배선 델타.
  현재 워킹트리에 링펫/UI 광범위 WIP 얽힘 — 비대화형 헌크 분리 필요 시
  [[reference_noninteractive_hunk_split]].
- 백필 판단: 이건 신규 에셋+배선(반복 트랩 아님)이라 표준 체크리스트 백필 불요.
  단, "결과화면 스테이지가 pulse 폴백 vs Live2D defeat+click 두 계열로 갈리고, 신규 스테이지는
  fallback→live2d 빌더/스테이터스/클릭라우팅을 함께 옮겨야 함"이 반복 가능하면
  `docs/` 결과화면 노트에 1줄 추가 고려.

---

## 부록: 왜 Codex인가
- 정식 result 라투디 원화 = Codex 빌트인 image_gen 경로(멘헤라 `_meta.json` `generator: built-in image_gen`).
- Codex 크로마키 스킬(`~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py`) 보유.
- AutoSprite MCP + Real-ESRGAN + 대규모 GDScript 배선 = Codex 실행 담당([[feedback_claude_vs_codex]]).
- Claude 잔여 역할: 최종 원화/시트/인게임 픽셀 **적대적 리뷰**(정체성 드리프트·억울 표정·좌식 프레이밍·
  fallback→live2d 라우팅 누락 감사).
