# 링펫 펜들럼 내부 뷰 (다마고치식) — 슬라이스 계획 (단일 소스)

TAB → 캐릭터정보 → **링코어 아이콘 클릭** → "펜들럼 내부" 서브화면. 장착 링펫이
회중시계형 펜들럼 셸 안에서 **걸어다니고**, **말풍선으로 링펫어**를 말한다.
현재 런의 `ring_core_tier`로 **부분 해독**(낮으면 글리프, 높으면 한국어).

이 화면은 해석기 로드맵의 **빠져 있던 S4 호스트(도감/사육 화면)**를 구현한다 —
`docs/lingpet_language_decoder_plan.md` §4.4 cross-ref.

배선 = 사용자/Codex, 설계·아트·적대리뷰 = Claude (`feedback_design_slice_review_division`).

---

## 0. 스코프 / 명칭 락

- 내부 id: `lingpet_pendulum_interior`. 데이터키: 기존 `lingpet.language.*` 재사용 +
  제너럴 풀 `lingpet.language.generic.{emotion}.{n}`.
- **확정 결정(2026-06-24, 사용자):**
  1. **상호작용 = 비주얼 + 자동 대사 (MVP).** 먹이/쓰다듬기/교감 연동은 후속(범위 밖).
     클릭으로 대사 넘김 정도는 허용.
  2. **대사 = 감정별 제너럴 풀(펫 무관).** 펫별 고유 대사 아님 → 모든 장착 펫이
     같은 감정-키 풀에서 말함(당시 maribo 2줄 외에 콘텐츠가 없던 문제를 한 번에 해소).
  3. **아트 = 신규 회중시계형 펜들럼 셸** + 내부 유리창(ui-hud-generation).
- 재론 금지: 위 3개. 펫별 대사/먹이연동/별도노드호스트는 의도적 비채택.

---

## 1. UX 플로우

1. TAB 캐릭터정보 오픈(기존). 링펫 패널의 **링코어 아이콘 hover**(기존
   `_ring_core_row_hover_target()`).
2. **링코어 클릭** → 펜들럼 내부 서브상태 진입(게이트: `state=="companion"` & 펫 장착).
3. 서브상태 표시: 패널 위에 어둡게 + **펜들럼 셸 프레임** + 내부에 **걷는 링펫** +
   **말풍선(링펫어, 부분해독)** + 작은 닫기/ESC 안내.
4. 말풍선: N초마다 새 대사 회전(클릭으로 넘김 가능). 감정별 제너럴 풀에서 선택
   (친밀도 높을수록 따뜻 가중 = optional, MVP는 랜덤 가능).
5. ESC/닫기: 서브상태 종료 → 일반 캐릭터정보 패널 복귀. (일반 패널 ESC = 오버레이
   닫기, 기존 동작 유지 → **ESC는 서브상태면 "나가기" 먼저, 아니면 "오버레이 닫기"**.)

---

## 2. 아키텍처 — char-info 오버레이의 "즉시모드 서브상태" (새 호스트 X)

캐릭터정보 오버레이는 **100% 즉시모드 `_draw()`**(`character_info_overlay_frame_presenter.draw_frame()`).
펜들럼 내부를 **별도 Control/노드 호스트로 띄우면 z-order 매장 함정**(plaza z=1200 사례,
`plaza_character_info_overlay_z_order_smoke`)에 걸린다. 대신 **오버레이의 서브상태**로
같은 draw 패스에서 패널 위에 그려 함정 자체를 회피한다.

- 상태(오버레이 state 모듈에 추가): `pendulum_interior_active: bool`,
  `pendulum_pet_id`, 대사 회전 타이머, 컴패니언 패널-로컬 pos/walk_phase/facing.
- **draw 분기:** `frame_presenter`가 서브상태면 일반 패널 위에(또는 대신) 펜들럼 내부를 그림.
- **input 분기:** `character_info_overlay_input_handler`가 서브상태면 ESC/닫기/클릭(대사넘김)만
  처리하고 나머지 입력 소비. 진입 = 링코어 클릭(`_try_handle_lingpet_unlock_pick_click` 패턴 복사).
- **말풍선:** RichTextLabel 노드 대신 **`build_runs()` 런을 즉시모드 `draw_string`**으로 그림
  (런별 font+color). reveal/build_runs와 런 링코어 기반 decoder level 재사용, **최종 blit만 즉시모드**.
  (단일 `draw_string_cached`는 혼색 불가라 부적합 — 런별 다중 `draw_string`이 정답.)

---

## 3. 3개 레이어

### 3.1 펜들럼 셸 프레임 (아트, Claude)
- 신규 자산: 회중시계형 펜들럼 셸 + 내부 유리창(원/타원 뷰포트). `.claude/skills/ui-hud-generation`.
- **prewarm**: 서브상태 진입(open)에서 텍스처 로드. `_draw` lazy 금지(핫패스 함정).
- 내부 뷰 rect = 링펫이 걷는 영역(좌우 벽 = 왕복 경계). 좌표계: **패널-로컬 → draw_companion
  center 전달 전 변환**(컴패니언 렌더러는 caller 좌표계로 그림).

### 3.2 걷는 링펫
- `LingpetCompanionRenderer.draw_companion(canvas, center, config)` 재사용 — **이미 임의
  캔버스/위치에 그리도록 디커플됨**, 플레이필드 가정 없음.
- config = `lingpet_companion_draw_context_builder.build_config()` 또는 최소 config(텍스처/animator/
  motion_speed_ratio/pose). 텍스처는 `LingpetCurrentProfile.get_visual_texture(visual_key)`.
- **패널-로컬 walk 드라이버:** center.x를 좌↔우 ping-pong, facing=진행방향, center.y=내부 바닥선.
- **motion_speed_ratio = 실제 프레임 dx 기반**(treadmill 함정 — intent 상수/patrol_speed 금지).
  `advance_walk_phase(delta, ratio)`를 오버레이 update 틱마다(animation_time delta) 호출
  (벽시계 아님; 장식이라 soul-clone식 wall-clock 폴백도 허용하나 accumulator 권장).
- **텍스처 cold-start 주의:** 미캐시면 draw silent skip → 장착 펫 walk/idle(+필요시 move_left/right)
  를 진입 prewarm.

### 3.3 해독 말풍선
- 대사 선택: 감정별 제너럴 풀(§4). `decoder_level = min(snapshot.ring_core_tier, 5)`.
- `reveal(line, decoder_level)` → `build_runs(line, decoder_level, translator)` → 런(font_path/color/text).
- **즉시모드 렌더:** 런 순회 → font 로드(캐시) → `draw_string` per run, x 전진. wrap 필요시 폭 측정
  후 줄바꿈(`\n` char-wrap 함정 주의 — 세그먼트 단위라 해당 없음).
- **감정 토큰 = 별 점등**(미해독=숨김/dim, 해독=점등). **S3 미해결 리뷰와 동작 일치**시킬 것
  (`docs/lingpet_language_decoder_plan.md` §6.4 ①). 미해독=Lingpet 글리프(GLYPH_COLOR),
  해독=한국어(DECODED_COLOR).
- 폰트 prewarm: `LingpetLanguageRichText.prewarm_fonts()`.
- **catalog/reveal/build_runs는 매프레임 호출 금지** — 대사 1회 선택 시 **런 배열 캐시**, 매프레임은
  캐시된 런만 draw(`feedback_godot_catalog_const_deepcopy_hotpath`).

---

## 4. 감정별 제너럴 대사 풀 (락: 펫 무관)

- 데이터키: `lingpet.language.generic.{emotion}.{n}`, emotion ∈ `warm/curious/urgent/sad/neutral`.
- 라인 dict 구조 = 기존과 동일: `{id, speaker:"generic", emotion, glyph_text, tokens[{key,glyph,tier1-5,kind}]}`.
- catalog API 추가: `get_generic_lines(emotion) -> Array`, `get_random_generic_line(emotion, rng) -> Dictionary`.
- 선택: MVP=랜덤 emotion → 그 emotion 풀 랜덤 1줄. (optional: 친밀도↑ → warm 가중.)
- 시드 대사(2~3/emotion)는 Claude 작성(언어 설계). 풀 확장 + i18n 키 등록 = 콘텐츠 슬라이스(S5).
- i18n: raw ko 금지 — 안정 키(`lingpet.language.generic.warm.1.tok_*`) (`feedback_godot_localization_copy_sync`).

---

## 5. 재사용 맵 (검증된 코드 앵커)

| 필요 | 기존 자산 (그대로/패턴 복사) |
|---|---|
| 링코어 hover | `character_info_overlay_lingpet_presenter.gd` `_ring_core_row_hover_target()` (≈L997) |
| 링코어 rect | ⚠ `_draw_lingpet_ring_core_row()` (≈L964)가 rect를 **로컬 계산만** → `_last_ring_core_rect` 멤버 추가 필요 |
| 클릭 라우팅 | `character_info_overlay_input_handler.gd` L34–39 + `_try_handle_lingpet_unlock_pick_click()` 패턴 |
| 장착 펫 정체성 | `character_info_overlay_lingpet_snapshot_builder.build_panel_snapshot()` → `pet_id`/`ring_core_tier` |
| 걷는 링펫 | `LingpetCompanionRenderer.draw_companion(canvas,center,config)` / `lingpet_companion_draw_context_builder.build_config()` |
| 걷기 클럭 | `LingpetCompanionSpriteAnimator.advance_walk_phase()` / `get_walk_frame()` (accumulator) |
| 해독 | `LingpetDecoder.reveal()` / `decode_pct_for_level()` / 현재 런 `ring_core_tier` |
| 말풍선 런 | `LingpetLanguageRichText.build_runs()` (런별 font/color/text; 즉시모드로 draw_string) |
| 대사 풀 | `lingpet_language_catalog.get_lines_for_speaker()` → 제너럴은 `get_generic_lines(emotion)` 신규 |
| prewarm/게이트 | 오버레이 `prewarm_assets()` (CharacterInfoOverlayPrewarmPresenter), `is_active()` 게이트 |

---

## 6. 트랩 체크리스트 (배선 전 필독)

- **핫패스 lazy init 금지:** 펜들럼 텍스처 + 펫 walk/idle 시트 + 링펫 폰트를 **진입(open)에서 prewarm**.
  `_draw`/`_process`에서 모듈/텍스처/뷰포트 생성 금지(100ms+ 히치).
- **트레드밀(제자리걸음):** motion_speed_ratio = **실제 dx**, `advance_walk_phase`를 틱마다.
  intent 상수/patrol_speed/1.0 하드코딩 금지.
- **z-order:** 서브상태(같은 패스 위에 그림)라 매장 회피 — **단 픽셀 QA(윈도우드 스크린샷) 필수.**
- **감정=별 점등** S3 동작 일치(§3.3).
- **링코어 클릭 게이트:** `state=="companion"` & 펫 장착(ring_core_tier>0)일 때만 진입.
  chip-pip rect와 같은 행 공유 → **클릭 우선순위 충돌 주의**(hover target이 chip 우선).
- **ring_core_rect 미저장:** 현재 로컬 계산만 → `_last_ring_core_rect` 멤버 저장(이전 프레임 rect로 클릭 판정).
- **catalog deep-copy 핫패스:** 대사 선택 시 런 1회 캐시, 매프레임 reveal/build_runs 금지.
- **즉시모드 말풍선:** 런별 다중 `draw_string`(font/color 각각). 단일 `draw_string_cached` 금지(혼색 불가).
- **컴패니언 텍스처 cold-start:** 미캐시 시 silent skip → prewarm 누락 = "링펫 안 보임".

---

## 7. 슬라이스 백본 (배선=사용자/Codex, 각 슬라이스 smoke + 반증검증)

- **S1 — 서브상태 골격 + 게이트 + prewarm 훅.** 링코어 클릭→`pendulum_interior_active=true`,
  ESC 분기(서브상태면 나가기/아니면 오버레이 닫기), 빈 내부 패널 draw, prewarm 훅 호출.
  smoke: 클릭→active / ESC→inactive / 비-companion 무진입 / prewarm 호출됨. 반증=게이트 제거 시 fail.
- **S2 — 걷는 링펫.** draw_companion + 패널-로컬 ping-pong walk 드라이버. smoke: 정적프레임=idle·
  이동프레임=walk(treadmill 가드: 실제 dx=0이면 idle), 좌표변환. 반증=ratio 상수화 시 fail.
- **S3 — 해독 말풍선.** build_runs 즉시모드 + 런 링코어 기반 decoder_level. smoke: level0=글리프·level5=한국어·
  감정=별점등·런 1회 캐시(매프레임 재생성 금지). 반증=레벨 게이트 제거 시 fail.
- **S4 — 펜들럼 셸 아트 + 배치.** prewarm·정렬·**픽셀 QA(스크린샷)**. (아트=Claude.)
- **S5 — 감정별 제너럴 풀 콘텐츠 확장 + i18n 키 등록.** (대사=Claude, 키 등록=배선.)

---

## 8. 검증된 코드 앵커 (2026-06-24, code map)

- 오버레이 즉시모드: `character_info_overlay_frame_presenter.draw_frame()`; 펫 패널
  `CharacterInfoOverlayLingpetPresenter.draw_panel()` → `_draw_lingpet_ring_core_row()`.
- 라이프사이클/일시정지: `character_info_overlay_lifecycle.gd` open/close (skill cooldown pause).
- 컴패니언: `lingpet_companion_renderer.gd:21` draw_companion / `:165` `_draw_companion_sprite` /
  `lingpet_companion_sprite_animator.gd:94` advance_walk_phase / `lingpet_egg_runtime.gd:2767`
  `_get_companion_draw_motion_speed_ratio`(실제 dx).
- 언어: `lingpet_language_catalog.gd`(라인/토큰/get_lines_for_speaker) / `lingpet_decoder.gd:15` reveal /
  `lingpet_language_rich_text.gd:52` build_runs / 펜들럼 snapshot `ring_core_tier`.
- 폰트: `godot/assets/fonts/LingpetScript-Regular.ttf`(본문 기하) — 말풍선용.
- z-order/모달 선례: `plaza_character_info_overlay_host.gd`, `plaza_character_info_overlay_z_order_smoke.gd`,
  `battle_scene_overlay_input_controller`(모달 우선순위), `pause_menu_overlay.is_active()` 게이트.

---

## 9. Claude 즉시 산출물 (배선과 병렬)

1. **펜들럼 셸 아트** (ui-hud-generation): 회중시계형 셸 + 내부 유리창, 투명 PNG, 소스 앵커 기록.
2. **감정별 제너럴 대사 시드 풀**: warm/curious/urgent/sad/neutral 각 2~3줄(링펫어 + 토큰 tier + i18n 키 + 한국어 뜻),
   샘플 렌더로 부분해독(level1/3/5) 미리보기.

---

## 10. S5a — i18n 키 등록 (F1 닫기) — 배선=사용자/Codex, 설계·번역·리뷰=Claude

**문제(F1):** 펜들럼이 해독 대사/셸 문구를 모듈 내 인라인 `TRANSLATIONS_KO/EN`(+`translate_text(한국어)`)로 처리 →
ja/zh/es/pt/ru에서 한국어 폴백 노출, 그리고 `localization_coverage_smoke`의 no-Hangul 스캔이 못 잡음(키가 TEXT에 없어서).

**방식(확정):** 안정 키 + `LanguageSettings.translate(key, fallback)` (EXACT_TEXT 신규 금지, `[[feedback_godot_localization_copy_sync]]`).
`TEXT = { LANGUAGE_*: { "dotted.key": "..." } }`(`language_settings_data.gd:4503`)의 **7개 언어 블록에 키 직접 추가**.
**pt_BR / ru = EN 복제**(메모리 규칙). 고유명 "Lingpet"은 기존 `lingpet_feed` 컨벤션대로 **음역 안 함(라틴 유지)**.

### 10.1 배선 단계
1. `language_settings_data.gd`의 `TEXT[LANGUAGE_KO/EN/ZH/JA/ES]`에 아래 §10.3 키 블록 추가, `TEXT[LANGUAGE_PT_BR]`·`TEXT[LANGUAGE_RU]`엔 EN 블록 복제.
2. `character_info_overlay_pendulum_interior.gd`:
   - **인라인 `TRANSLATIONS_KO`/`TRANSLATIONS_EN` 상수 삭제**, `_translate_token(key, fallback)` →
     `return LanguageSettings.translate(key, fallback if fallback != "" else key)`.
   - 셸/HUD 문구는 한국어 리터럴 대신 **키로 교체**: `_draw_text`/`_draw_centered_text` 호출부에서
     `"펜듈럼 내부"` → `translate("lingpet.pendulum.title")` 등(§10.3 chrome 키). `translate_text(한국어)` 경로 제거.
   - 해석 캡션: `translate("lingpet.pendulum.decoder_caption") % [ring_core_tier, pct]` (T표시 + 해석률).
3. (선택) maribo 라인 키는 펜들럼이 안 쓰므로 후속 — 제너럴 풀 + chrome만으로 F1 닫힘.

### 10.2 스모크 (반증 가능 봉인)
- `localization_coverage_smoke._verify_runtime_surfaces_have_no_hangul`에 **펜들럼 표면 추가**: 각 비-KO 언어에서
  모든 제너럴 라인을 `build_runs(line, 5, LanguageSettings.translate)` 한 뒤 run text에 Hangul(가-힣) 0건 단언
  + chrome 6키 `translate()` 결과 Hangul 0건. (decoder_level 5 = 전 토큰 해독되어야 비-emotion 텍스트가 다 노출됨.)
- `_verify_translation_map_coverage`에 lingpet 키 셋이 7개 언어 모두 존재(키 누락=한국어 폴백) 단언.
- **반증:** 인라인 dict 복원 시 / 한 언어 키 누락 시 fail. (현 상태에서 추가하면 즉시 RED여야 정상.)
- 트랩: en은 Hangul이 없어 no-Hangul 스캔만으론 "EN 폴백"을 못 잡음 → **키 존재(coverage) 단언을 병행**해야 ja/zh가 EN으로 새는 것도 잡음.

### 10.3 번역 (붙여넣기용 — emotion 토큰은 ✦로 렌더되나 안전상 등록)

제너럴 대사 토큰 (키 = catalog 토큰 `key` 그대로):

| key (suffix of `lingpet.language.generic.*`) | ko | en (=pt,ru) | zh | ja | es |
|---|---|---|---|---|---|
| `warm.1.token.with_you` | 너와 함께 | with you | 与你一起 | きみと一緒に | contigo |
| `warm.1.token.when_here` | 여기 있으면 | here | 在这里时 | ここにいると | aquí |
| `warm.1.token.core` | 코어가 | my core | 我的核心 | コアが | mi núcleo |
| `warm.1.token.warm` | 따뜻해 | is warm | 变暖 | あたたかい | se calienta |
| `warm.1.token.heart` | 온기 | warmth | 暖意 | ぬくもり | calidez |
| `curious.1.token.today` | 오늘 | today | 今天 | きょう | hoy |
| `curious.1.token.ball` | 공은 | the ball | 这颗球 | ボールは | la bola |
| `curious.1.token.what` | 무슨 | has what | 有什么 | どんな | qué |
| `curious.1.token.scent` | 냄새? | scent? | 气味? | におい? | ¿olor? |
| `curious.1.token.spark` | 반짝 | spark | 闪 | きらり | chispa |
| `urgent.1.token.left` | 왼쪽 | left side | 左边 | 左の | izquierda |
| `urgent.1.token.current` | 기류가 | current | 气流 | 気流が | la corriente |
| `urgent.1.token.shaking` | 흔들려 | is shaking | 在晃动 | 揺れてる | tiembla |
| `urgent.1.token.careful` | 조심해! | careful! | 小心! | 気をつけて! | ¡cuidado! |
| `urgent.1.token.flash` | 번쩍 | flash | 闪光 | ピカッ | destello |
| `sad.1.token.dark` | 조금 어두워도 | even in dark | 即使有点暗 | 少し暗くても | aun a oscuras |
| `sad.1.token.your` | 너의 | your | 你的 | きみの | tu |
| `sad.1.token.light` | 빛이 | light | 光 | 光が | luz |
| `sad.1.token.see` | 보여 | is visible | 看得见 | 見える | se ve |
| `sad.1.token.ember` | 불씨 | ember | 余烬 | 燠火 | brasa |
| `neutral.1.token.i` | 나는 | I | 我 | わたしは | yo |
| `neutral.1.token.here` | 여기서 | am here | 在这里 | ここで | aquí |
| `neutral.1.token.small_circle` | 작은 원을 | in small circles | 绕小圈 | 小さな円を | en círculos |
| `neutral.1.token.walk` | 걷고 있어. | walking. | 走着. | 歩いてる。 | caminando. |
| `neutral.1.token.dot` | 점 | dot | 点 | 点 | punto |

펜들럼 chrome 키:

| key | ko | en (=pt,ru) | zh | ja | es |
|---|---|---|---|---|---|
| `lingpet.pendulum.title` | 펜듈럼 내부 | Pendulum Interior | 怀表内部 | ペンデュラム内部 | Interior del Péndulo |
| `lingpet.pendulum.close` | 닫기 | Close | 关闭 | 閉じる | Cerrar |
| `lingpet.pendulum.language_label` | 링펫어 | Lingpet Tongue | Lingpet语 | リンペット語 | Lengua Lingpet |
| `lingpet.pendulum.esc_hint` | ESC로 돌아가기 | Press ESC to return | 按 ESC 返回 | ESCで戻る | ESC para volver |
| `lingpet.pendulum.next_hint` | 클릭하면 다음 말 | Click for next line | 点击看下一句 | クリックで次の言葉 | Clic: siguiente |
| `lingpet.pendulum.decoder_caption` | 링코어 T%d · 해석 %d%% | Ring Core T%d · Decode %d%% | 环核 T%d · 解读 %d%% | リングコア T%d · 解読 %d%% | Ring Core T%d · Descifr. %d%% |

> emotion 토큰(`*.token.heart/spark/flash/ember/dot`)은 §3.3대로 ✦ 별로 렌더 → 위 단어는 build_runs가 별 대신
> 단어를 보일 경우의 폴백일 뿐(현지화되어 한국어 노출 없음). S3 emotion=별 확정 시 이 값들은 표시되지 않음.

---

## 11. 펜들럼 내부 폴리시 (2026-06-25)

### 11.1 어두운 글래스 말풍선
- 풍선 배경은 `Color(0.04, 0.09, 0.12, 0.92)`, 테두리는
  `Color(0.40, 0.82, 0.85, 0.55)`를 사용한다.
- 헤더/해석 캡션만 시안 계열로 맞추고, 본문은
  `LingpetLanguageRichText.build_runs()`가 제공하는 시안 글리프·밝은 해독문·금색
  감정 시일을 그대로 그린다. 밝은 크림 배경용 색 오버라이드는 두지 않는다.

### 11.2 펫 추적 풍선과 꼬리
- 컴패니언 draw에서 계산한 실제 중심을 저장하고 풍선 x를 그 중심 기준으로
  이동시킨다. 풍선 rect는 유리창 안쪽 14px 범위로 clamp한다.
- 꼬리는 선이 아니라 채운 삼각형이다. 밑변은 풍선 하단에서 펫 x에 맞추고,
  꼭짓점은 `pet.y - radius - 4px`로 두어 보행 중에도 화자가 명확해야 한다.
- `_speech_rect`는 매 draw 갱신된 최종 rect를 클릭 히트테스트에 사용한다.

### 11.3 셸 도킹 닫기 버튼
- 외부의 `닫기` 직사각 라벨을 제거하고, 셸 상단 우측 금테에 작은 원형 X 버튼을
  정규화 앵커로 도킹한다.
- 마우스를 올리면 내부 틸 광과 금색 테두리/X가 밝아진다. 별도 hover 상태를
  만들지 않고 프레임 프레젠터의 현재 마우스 좌표를 draw에 전달한다.
- 클릭 rect는 원의 지름을 감싸는 26px 정사각형으로 매 draw 갱신한다. ESC 닫기
  동작은 기존 서브상태 계약을 유지한다.

### 11.4 검증 계약
- interior smoke는 좌우 펫 위치에 따라 풍선이 실제 이동하는지, 유리창 내접 범위를
  지키는지, 꼬리 꼭짓점이 펫 머리를 가리키고 삼각분할 가능한지, 원형 닫기 앵커와
  draw 후 동적 클릭 rect가 유효한지를 단언한다.
- visual smoke는 실제 SubViewport 캡처에서 셸·유리창·보행 밴드 외에 어두운 풍선과
  도킹 닫기 버튼 픽셀도 비어 있지 않은지 확인한다. 비주얼 변경 시 GUI 캡처를
  다시 열어 본문 대비, 꼬리 연결, 셸 도킹 위치를 눈으로 검수한다.

---

## 12. 해석률 권위 변경 (2026-06-25)

### 12.1 현재 권위
- 펜들럼의 해석률은 영구 `plaza_save_store.decoder_level`이 아니라 **현재 런의
  `ring_core_tier`**가 정한다.
- 매핑은 `min(ring_core_tier, 5) * 20%`이다.
  - T1 = 20%, T2 = 40%, T3 = 60%, T4 = 80%, T5/T6 = 100%.
- 표시용 티어는 T6까지 보존하고, 해독용 `decoder_level`만 5로 cap한다.
- T0은 기존 진입 게이트(`state=="companion"`, 펫 장착, `ring_core_tier > 0`)가
  막는다.

### 12.2 런 리셋
- `ring_core_tier`는 런 단위 값이다. 새 게임/새 런에서 0으로 돌아가며, 펜들럼은
  열릴 때마다 오버레이 snapshot의 현재 값을 다시 읽는다.
- 따라서 추가적인 펜들럼 전용 리셋 훅을 만들지 않는다. 기존 링코어 런 상태
  리셋이 곧 해석률 리셋이다.

### 12.3 캡션
- `lingpet.pendulum.decoder_caption`은 `"링코어 T%d · 해석 %d%%"` 형태로 표시한다.
- 포맷 인자는 `[ring_core_tier, decode_pct]`이다. 예: T1이면 `링코어 T1 · 해석 20%`.

### 12.4 영구 decoder_level의 운명
- 영구 `decoder_level` 시스템은 제거하지 않고 **휴면 보존**한다.
- 펜들럼은 런 단위 앰비언트 채터라 링코어 티어를 따른다. 영구 `decoder_level`은
  향후 도감/로어/창세 서록류의 영구 해금 트랙에 재사용할 수 있다.
- 미래 작업자가 펜들럼을 다시 `plaza_save_store.get_decoder_level()`에 묶으면
  현재 설계 회귀다.

### 12.5 검증 계약
- interior smoke는 save decoder를 일부러 max로 둔 상태에서 T1 펜들럼이
  `decoder_level == 1`, `20%`를 표시하고 save decoder를 읽지 않는다고 단언한다.
- T5는 100%, T6은 표시 `T6` + 해독 cap 100%를 단언한다.
- source trap은 펜들럼 모듈에 `plaza_save_store` / `.get_decoder_level(` 경로가
  되살아나면 실패해야 한다.

---

## 13. S5b — 감정별 대사 풀 확장 (2026-06-25) — 배선=사용자/Codex, 대사·번역·리뷰=Claude

감정별 1줄 → **2줄**(각 emotion에 `.2` 추가, 신규 5줄). 구조/tier 규칙은 §4 그대로
(라인당 5토큰 tier 1~5, emotion 토큰 tier5 glyph `*`=✦, speaker `generic`).

### 13.1 catalog 추가 (`lingpet_language_catalog.gd`)
`LINE_IDS` + `GENERIC_LINE_IDS_BY_EMOTION`(각 emotion 배열에 `.2` 추가) + `LINES`에 아래 5개:

```gdscript
LINE_GENERIC_WARM_2: { "id": LINE_GENERIC_WARM_2, "speaker": "generic", "emotion": "warm",
  "glyph_text": "mio kora vela lumi *", "tokens": [
    {"key": "lingpet.language.generic.warm.2.token.together", "glyph": "mio", "tier": 1, "kind": "root"},
    {"key": "lingpet.language.generic.warm.2.token.core", "glyph": "kora", "tier": 2, "kind": "noun"},
    {"key": "lingpet.language.generic.warm.2.token.sings", "glyph": "vela", "tier": 3, "kind": "verb"},
    {"key": "lingpet.language.generic.warm.2.token.warmly", "glyph": "lumi", "tier": 4, "kind": "emotion_word"},
    {"key": "lingpet.language.generic.warm.2.token.seal", "glyph": "*", "tier": 5, "kind": "emotion"}]},
LINE_GENERIC_CURIOUS_2: { "id": LINE_GENERIC_CURIOUS_2, "speaker": "generic", "emotion": "curious",
  "glyph_text": "ira tu dei waka *", "tokens": [
    {"key": "lingpet.language.generic.curious.2.token.that", "glyph": "ira", "tier": 1, "kind": "root"},
    {"key": "lingpet.language.generic.curious.2.token.light", "glyph": "tu", "tier": 2, "kind": "noun"},
    {"key": "lingpet.language.generic.curious.2.token.where", "glyph": "dei", "tier": 3, "kind": "question"},
    {"key": "lingpet.language.generic.curious.2.token.goes", "glyph": "waka", "tier": 4, "kind": "verb"},
    {"key": "lingpet.language.generic.curious.2.token.seal", "glyph": "*", "tier": 5, "kind": "emotion"}]},
LINE_GENERIC_URGENT_2: { "id": LINE_GENERIC_URGENT_2, "speaker": "generic", "emotion": "urgent",
  "glyph_text": "vora sena daka piri *", "tokens": [
    {"key": "lingpet.language.generic.urgent.2.token.above", "glyph": "vora", "tier": 1, "kind": "direction"},
    {"key": "lingpet.language.generic.urgent.2.token.something", "glyph": "sena", "tier": 2, "kind": "noun"},
    {"key": "lingpet.language.generic.urgent.2.token.falls", "glyph": "daka", "tier": 3, "kind": "verb"},
    {"key": "lingpet.language.generic.urgent.2.token.dodge", "glyph": "piri", "tier": 4, "kind": "warning"},
    {"key": "lingpet.language.generic.urgent.2.token.seal", "glyph": "*", "tier": 5, "kind": "emotion"}]},
LINE_GENERIC_SAD_2: { "id": LINE_GENERIC_SAD_2, "speaker": "generic", "emotion": "sad",
  "glyph_text": "siku ari voma hila *", "tokens": [
    {"key": "lingpet.language.generic.sad.2.token.quiet", "glyph": "siku", "tier": 1, "kind": "mood"},
    {"key": "lingpet.language.generic.sad.2.token.your", "glyph": "ari", "tier": 2, "kind": "root"},
    {"key": "lingpet.language.generic.sad.2.token.voice", "glyph": "voma", "tier": 3, "kind": "noun"},
    {"key": "lingpet.language.generic.sad.2.token.hear", "glyph": "hila", "tier": 4, "kind": "verb"},
    {"key": "lingpet.language.generic.sad.2.token.seal", "glyph": "*", "tier": 5, "kind": "emotion"}]},
LINE_GENERIC_NEUTRAL_2: { "id": LINE_GENERIC_NEUTRAL_2, "speaker": "generic", "emotion": "neutral",
  "glyph_text": "tomo ena mela moru *", "tokens": [
    {"key": "lingpet.language.generic.neutral.2.token.today", "glyph": "tomo", "tier": 1, "kind": "time"},
    {"key": "lingpet.language.generic.neutral.2.token.spot", "glyph": "ena", "tier": 2, "kind": "place"},
    {"key": "lingpet.language.generic.neutral.2.token.same", "glyph": "mela", "tier": 3, "kind": "shape"},
    {"key": "lingpet.language.generic.neutral.2.token.circle", "glyph": "moru", "tier": 4, "kind": "shape"},
    {"key": "lingpet.language.generic.neutral.2.token.seal", "glyph": "*", "tier": 5, "kind": "emotion"}]},
```
> 새 어근: vela(노래), ira(저), vora(위), piri(피해), siku(조용), voma(소리), mela(같은). 나머지는 기존 재사용.
> 한국어 읽기: warm.2 "함께 코어가 따뜻이 노래해 ✦" / curious.2 "저 빛은 어디로 가? ✦" /
> urgent.2 "위에서 뭔가 떨어져, 피해! ✦" / sad.2 "조용해도 너의 소리는 들려 ✦" / neutral.2 "오늘도 같은 자리, 같은 원 ✦".

### 13.2 i18n (TEXT 7언어 — pt_BR/ru=en, emotion seal은 ✦지만 안전상 등록)

| key suffix (`lingpet.language.generic.*`) | ko | en (=pt,ru) | zh | ja | es |
|---|---|---|---|---|---|
| `warm.2.token.together` | 함께 | together | 一起 | 一緒に | juntos |
| `warm.2.token.core` | 코어가 | my core | 核心 | コアが | mi núcleo |
| `warm.2.token.sings` | 노래해 | sings | 歌唱 | 歌う | canta |
| `warm.2.token.warmly` | 따뜻이 | warmly | 温暖地 | あたたかく | cálidamente |
| `warm.2.token.seal` | 온기 | warmth | 暖意 | ぬくもり | calidez |
| `curious.2.token.that` | 저 | that | 那 | あの | aquel |
| `curious.2.token.light` | 빛은 | the light | 那光 | あの光は | la luz |
| `curious.2.token.where` | 어디로 | where to | 去哪 | どこへ | a dónde |
| `curious.2.token.goes` | 가? | goes? | 去? | 行く? | ¿va? |
| `curious.2.token.seal` | 반짝 | spark | 闪 | きらり | chispa |
| `urgent.2.token.above` | 위에서 | above | 上方 | 上から | arriba |
| `urgent.2.token.something` | 뭔가 | something | 有东西 | 何かが | algo |
| `urgent.2.token.falls` | 떨어져 | falls | 掉下来 | 落ちる | cae |
| `urgent.2.token.dodge` | 피해! | dodge! | 快躲! | 避けて! | ¡esquiva! |
| `urgent.2.token.seal` | 번쩍 | flash | 闪光 | ピカッ | destello |
| `sad.2.token.quiet` | 조용해도 | even if quiet | 即使安静 | 静かでも | aun en silencio |
| `sad.2.token.your` | 너의 | your | 你的 | きみの | tu |
| `sad.2.token.voice` | 소리는 | voice | 声音 | 声は | voz |
| `sad.2.token.hear` | 들려 | I hear | 听得见 | 聞こえる | oigo |
| `sad.2.token.seal` | 불씨 | ember | 余烬 | 燠火 | brasa |
| `neutral.2.token.today` | 오늘도 | today too | 今天也 | 今日も | hoy también |
| `neutral.2.token.spot` | 같은 자리 | same spot | 同一处 | 同じ場所 | mismo lugar |
| `neutral.2.token.same` | 같은 | same | 一样 | 同じ | mismo |
| `neutral.2.token.circle` | 원 | circle | 圈 | 円 | círculo |
| `neutral.2.token.seal` | 점 | dot | 点 | 点 | punto |

### 13.3 스모크 (신규 불필요 — 기존이 자동 커버)
- `localization_coverage_smoke`는 `get_generic_lines("")`를 순회하므로 신규 5줄의 25키를
  **비-KO no-Hangul + 키존재**로 자동 검사. `lingpet_reveal_smoke`/`lingpet_rich_text_smoke`는
  `get_line_ids()` 순회라 tier 게이트/감정 시일도 자동 커버.
- **배선 순서 트랩:** catalog에 라인을 먼저 추가하고 TEXT 키를 안 넣으면 coverage smoke가
  **RED**(키 누락) — 정상. catalog + TEXT를 같은 슬라이스에서 함께 넣어야 GREEN.
- 트랩: `.2` 네임스페이스라 `.1`과 키 충돌 없음 / emotion seal glyph는 `*` 통일(F5) 유지 /
  pt_BR·ru는 EN 복제.
