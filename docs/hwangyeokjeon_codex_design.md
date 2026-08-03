# 환격전 도감(코덱스) 설계 노트

상태: 설계 (Claude). 구현·테스트 = Codex. 이 문서가 단일 소스.
분담: 설계·트랩 브리프·적대 리뷰 = Claude / GDScript 배선 = Codex
([[feedback_design_slice_review_division]]). 같은 파일 동시수정 금지.

목적: 런 바깥 메타 진행의 첫 축. **수호령 / 요괴(보스) / 신물(신화 아이템)**
3권 도감을 영속 기록으로 만들고, 메인메뉴에서 열람하게 한다.
2026-08-03 도파민 감사 C버킷("도감은 현행 균등 가중치 + 런 한정 소유 계약을
유지한 채 별도 설계 가능") 결론을 실행하는 슬라이스다.

---

## 0. 제1 규칙 — 도감은 **표시 전용 기록**이다 (봉인 계약 보존)

도감은 어떤 게임플레이 값도 바꾸지 않는다. v1에서 절대 금지:

1. **부화 가중치 개입 금지.** `lingpet_catalog.gd`의 `hatch_weight: 1.0` × 14
   균등 계약과 그 씰(`tests/lingpet_egg_runtime_smoke.gd:1046-1071`
   `_verify_lingpet_catalog_random_hatch_scaffold`)을 건드리지 않는다.
   도감 기록 유무가 부화 후보/가중치에 흘러들어가면 안 된다.
2. **런 한정 소유 계약 보존.** 수호령 소유는 런 스코프다
   (`lingpet_save_store.gd:141 _is_volatile_run_snapshot`, 씰
   `lingpet_egg_runtime_smoke.gd:3785-3894`). 도감은 "만난 적 있다/몇 번
   부화시켰다"라는 **이력**만 영속화하고, 소유·로스터·슬롯 상태는 절대
   저장하지 않는다.
3. **은퇴 어휘 재도입 금지.** `tests/lingpet_permanent_collection_surface_smoke.gd`가
   교감/친밀도 계열 어휘 재도입을 금지한다. 도감 UI 카피·필드명·i18n 키에
   친밀도/교감/포만도/먹이/펫 레벨 어휘를 쓰지 않는다.
4. **완성 보상 없음(v1).** 컬렉션 달성 보상은 경제 결정이라 감사 C버킷
   (리그 보상 차등·상자 테이블)과 함께 별도 설계한다. v1은 열람+집계까지만.
5. **UI 노출 명칭은 `수호령`.** Ringpet/Lingpet은 내부 식별자로만
   (CLAUDE.md "Ringpet Visual Terminology").

---

## 1. 범위

### v1 포함
- 도감 3권(탭): **수호령**(14) / **요괴**(보스 10) / **신물**(신화 아이템 49+α).
- 영속 저장 `user://codex_save.cfg` (신규 스토어, plaza 패턴 복제).
- 커밋 훅 3계열: 부화 확정 / 보스 조우·격파 확정 / 신화 획득 확정.
- 메인메뉴 진입(설정 오버레이와 같은 즉시-draw 오버레이 패턴).
- 미발견 실루엣 + `???`, 발견 시 상세(일러스트/기록/스킬/울음소리 재생).
- 수호령 플레이버 텍스트의 **링펫어 부분 해독 표시**(해석기 레벨 연동 —
  해석기의 첫 실소비자).
- 탭별 수집 카운트 + 전체 달성률 표시.
- i18n 7언어 `codex.*` 키.

### v1 제외 (후속)
- 무공(퍽) 도감 — 96종, 런 내 UI가 이미 상세해서 우선순위 낮음.
- 완성 보상/칭호 — 경제·업적 설계와 함께.
- 광장 건물형 도감 진입(서고/기록소) — 메인메뉴 진입 검증 후.
- 일시정지 메뉴 진입 — 전투 모달 게이트/루프 오디오 트랩 검토가 따로 필요.
- 보스 패턴(스킬) 개별 해금 — 요괴 상세는 v1에서 고정 소개문만.

---

## 2. 데이터 모델 / 영속 저장

### 2.1 파일·모듈 구성 (plaza 2파일 분리 패턴 복제)

```
godot/scripts/codex/codex_save_config_codec.gd   # 스키마·encode/decode·sanitize
godot/scripts/codex/codex_save_store.gd          # 런타임 상태·load/save/clear·기록 API
godot/scripts/codex/codex_boss_keys.gd           # 보스 정본 키 + 표시명 해석
godot/scripts/codex/codex_overlay.gd             # 풀스크린 즉시-draw 오버레이
godot/scripts/codex/codex_overlay_card_renderer.gd  # (필요 시) 카드/그리드 드로어 분리
```

- 저장 경로 `user://codex_save.cfg` + `user://codex_save.last_good.cfg`.
- **BOM/복구 패턴은 `plaza_save_store.gd`를 그대로 복제**: `_load_config_file()`의
  EF BB BF 스트립 → 파스 브레이크 사전검사 → `last_good` 복구 → 마이그레이션 시
  즉시 재기록. (Godot ConfigFile UTF-8 BOM 트랩 준수.)
- 코덱은 `SAVE_SCHEMA_VERSION := 1`, `encode/decode` 대칭 쌍,
  `read_schema_version()` 레거시 폴백, `sanitize_*` static — plaza 코덱 관례 동일.
- `set_save_path()` 오버라이드 필수(테스트/캡처 오염 방지 —
  `battle_scene_selection_startup_lifecycle.gd:80-84` 선례: 비-Node owner면 `""`).
- `scripts/resources/gameplay_core_module_catalog.gd`에 레지스트리 키
  `codex_save_store` 등록 (plaza_save_store 선례 L124).

### 2.2 섹션 스키마 (v1)

집합형 기록은 선술집 완료 장부 관례(`_write_int_section`/`load_int_section`)를 쓴다.

```
[meta]              schema_version = 1
[lingpet_hatches]   <pet_id> = int        # 부화 누계. >0 = 발견
[boss_encounters]   <boss_key> = int      # 전투 시작 누계. >0 = 실루엣 해금
[boss_defeats]      <boss_key> = int      # 격파 누계. >0 = 완전 해금
[boss_best_league]  <boss_key> = int      # 격파 시 최고 리그 (0 주니어 … 3 신화)
[mythic_acquires]   <item_name> = int     # 획득 누계. >0 = 발견
```

- 타임스탬프(첫 발견 일시)는 v1 제외 — 스키마 v2 여지로 남긴다.
- 모든 기록 API는 선술집 관례대로 **전제조건 검사 직후 단일 지점에서
  `save()`까지 원자적으로** 수행하고 `{changed, reason, ...}` 요약 Dictionary를
  반환한다. 이벤트 시점 즉시 커밋(런 종료 대기 금지 — 크래시 세이프).
- 디스크 쓰기 예산: 파일은 1KB 미만이고 커밋 시점이 전부 세리머니 프레임
  (부화 컷인·매치 종료·획득 시네마틱)이라 즉시 `save()`가 기본. 프로파일에서
  히치가 잡히면 그때 `call_deferred` 지연 쓰기로 전환한다(선최적화 금지).

### 2.3 보스 정본 키 (`codex_boss_keys.gd`)

표시명 정본이 현재 3곳+에 흩어져 있고(`scoreboard_overlay_header_renderer.gd:7-20`,
`serve_wait_indicator_renderer.gd:14`, `defeat_settlement_screen.gd:12-19` —
후자는 "폰크" 오탈자로 이미 발산) 스테이지별 `const BOSS_NAME`도 따로 있다.
도감이 새 단일 정본을 세운다:

| boss_key | 표시명(ko) | 해석 규칙 |
|---|---|---|
| `stage1_dalji` | 달지 | stage 1 + variant `dalji` |
| `stage1_gaksital` | 각시탈 | stage 1 + variant `gaksi` |
| `stage1_pododaejang` | 포도대장 | stage 1 + variant `podo` |
| `stage2_cheongringwi` | 청린귀 | stage 2 |
| `stage3_hwanmyo` | 환묘 연묘 | stage 3 |
| `stage4_ponk` | 퐁크 | stage 4 |
| `stage5_hongryun` | 홍련 | stage 5 |
| `stage6_tetriser` | 테트리서 | stage 6 |
| `stage7_akamu` | 아카무 리고 | stage 7 |
| `stage8_minotaur` | 미노타우로스 | stage 8 |

- API: `resolve_boss_key(stage_id, stage1_boss_variant) -> String`,
  `get_display_name(boss_key)`(내부에서 `LanguageSettings.translate_text`
  통과 — 헤더 렌더러와 같은 다국어 경로), `get_portrait_path(boss_key)`
  (`battle_boss_sprite_paths.gd` 상수 위임), `get_boss_keys() -> Array`.
- variant 문자열 정규화는 `game_selection_state._normalize_stage1_boss_variant()`
  와 같은 값 집합을 쓴다(`dalji`/`gaksi`/`podo`).
- **권장 후속(별도 커밋):** 흩어진 `STAGE_BOSS_NAMES` 소비자들을 이 모듈로
  수렴 + `defeat_settlement_screen.gd`의 "폰크" 오탈자 수정. v1 필수는 아님.
- 스테이지 3의 멘헤라/쿠로미 각성을 별도 2엔트리로 쪼갤지는 §8 결정 대기 —
  v1 기본은 1엔트리.

---

## 3. 기록 커밋 훅

### 3.1 수호령 부화 (발견 = 부화 확정 시)

부화 확정 경로는 3갈래가 전부 `lingpet_egg_runtime.gd`에 있다:

| 경로 | 커밋 지점 |
|---|---|
| 일반 부화 | `_finish_regular_hatch()` (≈L2686, `add_pet_to_next_empty_slot` 직후) |
| 오버플로 교체 부화 | `_finish_overflow_hatch_commit()` (≈L2742) |
| 아이템알 흡수 | `_perform_item_egg_absorb()` (≈L2763) |

- **선호 구현: 단일 초크포인트.** 세 경로가 모두
  `lingpet_collection_state.record_collected_pet(owner, pet_id)`(L194)를
  경유하는지 먼저 확인하고, 경유한다면 그 직후 한 곳에서
  `codex_save_store.record_lingpet_hatch(pet_id, source)`를 호출한다.
  경유하지 않는 경로가 있으면 세 지점에 명시 호출(구현 시 검증 항목 V1).
- `source`: `"battle"` 기본, F7 `lingpet_debug_picker` 지급은 `"debug"`(§5).
- 방생(absorb-only)은 부화가 아니므로 기록하지 않는다 — 단,
  아이템알 흡수 라우터가 `record_collected_pet`을 부르는 경우 그 의미
  (수집 이력)와 도감 의미(부화 이력)가 같은지 구현 시 확인(V2).

### 3.2 요괴 조우 / 격파

- **조우**: 전투 시작에서 보스 정체가 확정되는 프레임에 1회.
  `battle_scene_selection_startup_lifecycle.resolve_stage1_boss_variant()`
  (L109-122) 결과가 owner에 반영된 뒤의 매치 시작 지점에서
  `record_boss_encounter(boss_key, source)`. 라운드 재시작·컨티뉴로
  중복 발화하지 않도록 **매치(스테이지 진입)당 1회 가드**를 스토어가 아니라
  호출부 세션 플래그로 잡는다(스토어는 누계만 증가).
- **격파**: `battle_scene_match_flow_driver.gd`의 승리 확정선 —
  `_try_start_victory_loot_phase()`(L238) 진입부의
  `player_points > boss_points` 판정(L251)이 참이 되는 그 지점, 전리품
  페이즈/결과화면 분기보다 **위**에서 `record_boss_defeat(boss_key,
  league_index, source)`. 리그는 현재 선택 리그를 인덱스화해 최고값 갱신.
- **`defeat_settlement_screen`의 `range(1, stage_id)` 추론을 절대 재사용하지
  않는다** — 그것은 "도달했으니 클리어했겠지"라는 표시용 추론이고 실제 격파
  기록이 아니다. 도감은 승리 확정선에서만 커밋한다.

### 3.3 신물 획득

- **선호 구현: `mythic_item_runtime.acquire_item()` 성공 반환 지점 단일
  초크포인트.** 현재 확인된 획득 경로 3갈래 —
  `stage_clear_reward_resolver._grant_equipment_reward()`(L352→L361,
  `inventory_index >= 0` 확인 후), 승리 전리품 상자
  (`victory_loot_phase_state.gd:424-426`), 무공 경유
  (`mythic_perk_grant_helper.gd:225`) — 가 전부 acquire_item으로 수렴하는지
  확인하고(V3), 수렴하면 그 안에서 `record_mythic_acquire(item_name, source)`.
  수렴하지 않는 경로(필드 스폰 직접 픽업 등)가 있으면 그 지점에 명시 호출.
- 대상 id 집합: `mythic_item_catalog_lists.FIELD_SPAWN_ORDER` 49종 +
  별도 레인 `elixir_of_mastery`(대성영단). 도감 총계는 이 합집합으로 계산 —
  카탈로그에 있으나 스폰 불가한 id가 더 있는지 구현 시 확인(V4).

---

## 4. 화면 설계 (`codex_overlay.gd`)

### 4.1 구조·진입

- **패턴 A(RefCounted 즉시-draw 오버레이)** — `defeat_settlement_screen.gd` /
  `pause_menu_overlay.gd` 계열. `show(owner, registry)` / `is_active()` /
  `update(delta)` / `handle_input(event, ...) -> {"handled": bool}` /
  `draw(canvas, view_size)` / `reset()`.
- 메인메뉴 통합은 **설정(MENU) 오버레이 5종 세트를 그대로 복제**:
  `main_menu_scene.gd`의 `_setup_settings_overlay()`(L792) /
  `_open_main_menu_settings()`(L821) / `_draw_settings_overlay()`(L832) /
  `_sync_settings_overlay_layer()`(L843) / `_is_settings_overlay_active()`(L861)
  대응물 + `_process`·`_input` 분기 + `_exit_tree` 정리.
- `main_menu.tscn` `ButtonStack`에 `CodexButton` 추가, 기존
  `StyleBoxFlat_btn_*` 서브리소스 재사용, `_setup_utility_button()` 경유 —
  **가시성/포커스 정책은 MENU(설정) 버튼과 완전 동일하게** 따른다.
  ⚠️ 메인메뉴는 터치-투-스타트 화면이라 `_gui_input()`(L284-293)이 아무
  클릭이나 START로 흡수하고, 버튼 비가시성 계약을
  `tests/main_menu_quit_confirmation_smoke.gd:43`이 봉인한다. 도감 버튼은
  MENU 버튼이 노출되는 것과 같은 조건·같은 경로로만 노출하고, 해당 스모크를
  락스텝 갱신한다.

### 4.2 레이아웃

- 외곽: `hwangyeokjeon/scroll_frame_9p.png`(`SCROLL_FRAME_SLICE
  Vector4(138,154,138,154)`) 한지 두루마리 프레임. 팔레트는
  `character_select_screen.gd:47-62`의 `CHROME_*` 상수(먹흑 바탕 + 옥빛
  악센트 + `CHROME_GOLD` 금니)를 재사용.
- 9패치 드로어는 **`defeat_continue_ui_renderer._draw_nine_patch_texture`
  (static, L243)** 재사용. (3곳 복제 정리는 별도 백로그 — v1에서 4번째 복제를
  만들지 말고 static 호출로.)
- 헤더: 화면 제목 + 탭 3개(수호령/요괴/신물) + 탭별 `발견 n / 전체 N` +
  전체 달성률 %. 탭 전환 = 좌우 방향키/LB·RB/클릭.
- 본문: 좌측 **카드 그리드**(`roster_card_idle_9p` / 선택 시
  `roster_card_selected_9p`), 우측 **상세 패널**(`premium_panel_frame.gd`
  `KIND_SECTION`).
- 미발견 카드: 실루엣(스프라이트를 먹흑 단색 modulate) + 이름 자리 `???`.
  요괴는 조우만 한 상태(격파 0)면 실루엣 + 표시명 공개, 격파 후 완전 공개.
- 입력: `gamepad_input.is_confirm_event / is_cancel_event`, 처리 후
  `set_input_as_handled()`. ESC/취소 = 닫기.

### 4.3 상세 패널 내용

| 권 | 내용 |
|---|---|
| 수호령 | 일러스트(정지 UI Live2D 재생 — `character_info_overlay_lingpet_presenter.draw_panel_live2d_art`(L535) 재사용), 표시명(`LingpetCatalog.get_display_name`), 액티브 스킬 풀(`get_active_skill_pool`) + 공용 패시브 6종 안내, **부화 누계**, 울음소리 재생 버튼, **링펫어 플레이버 1줄**(§4.4) |
| 요괴 | 초상화(`codex_boss_keys.get_portrait_path` → `battle_boss_sprite_paths` 상수), 표시명, 등장 스테이지, 소개문(신규 i18n 카피), **조우/격파 누계 + 최고 격파 리그**(리그 스워시 `league_swash_*.png` 재사용) |
| 신물 | 아이콘(`MythicItemCatalog.get_icon_path` / 시트 애니는 `MYTHIC_ICON_SHEET_PATHS` + 32프레임 관례), 표시명/설명(`get_display_name` + `LanguageSettings` 신화 설명 경로), **획득 누계** |

- 울음소리: `game_audio.play_lingpet_click_reaction(pet_id)`(L2478).
  ⚠️ `lingpet_click_voice_audio.VOICE_SPECS`에 없는 펫은 **무음**이므로
  `get_spec(pet_id)` 부재 시 버튼을 회색 처리(무반응 버튼 금지).
- 신물 아이콘 시트 애니메이션은 상세 패널 1개에서만 재생(그리드는 정지
  프레임) — draw 예산 보호.

### 4.4 링펫어 플레이버 (해석기 첫 실소비자)

- 각 수호령 상세에 링펫어 대사 1줄을 노출하고, 해독 정도는
  `plaza_save_store.get_decoder_level()`(plaza_save `[progression]
  decoder_level`, 스테이지 클리어로 1~5 자동 상승)을 따른다.
- 렌더: `lingpet_decoder.reveal(line, level)` →
  `lingpet_language_rich_text.build_runs(line, level, translator)`의 run
  배열을 받아 **즉시-draw로 직접 그린다**(런별 `get_lingpet_font()` /
  `get_body_font()` + `GLYPH_COLOR`/`DECODED_COLOR`).
  `apply_runs_to_label`(RichTextLabel 경유)은 노드형이라 v1 오버레이에선
  쓰지 않는다.
- 대사 소스: `lingpet_language_catalog.get_lines_for_speaker(pet_id)`가 있는
  펫은 그 첫 줄, 없는 펫은 `get_random_generic_line(emotion, rng)`을 **펫
  id 해시 시드로 고정 선택**(열 때마다 바뀌지 않게; `Math.random` 계열 비결정
  선택 금지).

### 4.5 성능·트랩 브리프 (배선 시 준수)

1. **프리웜**: 텍스처(실루엣 포함)·폰트(`prewarm_fonts()`)·9패치는 `show()`
   에서 1회. draw/update 안 lazy 생성 금지(Hot-Path Lazy Init 트랩).
2. **부재 에셋 per-frame re-stat 금지**: 초상화/아이콘 경로는 `show()`에서
   `file_exists` 확인 후 없으면 플레이스홀더 텍스처로 치환해 캐시. per-frame
   draw에서 미존재 경로 재시도 금지(Missing Reserved-Asset 트랩).
3. 즉시-draw 안 `canvas.material` 스왑은 no-op — 블렌드 전환 연출 금지.
4. `draw_set_transform` 연속 회전 금지, typed 배열 조건식 리터럴 금지.
5. 메인메뉴는 전투 모달 게이트 밖이라 루프 오디오 트랩 무관 — 단 후속으로
   일시정지 진입을 추가하면 `_stop_modal_blocked_gameplay_loop_audio` 계열
   검토가 선행돼야 한다(§1 범위 제외 사유).
6. 스크롤이 필요한 그리드(신물 49+)는 페이지네이션 우선(스크롤 클리핑
   구현보다 페이지 전환이 싸고 패드 친화적).

---

## 5. 디버그 기록 오염 방지

현행 코드에는 "디버그 경유" 마커가 없다(`stage_debug_picker._apply_selected_stage`
L221-233은 마커를 남기지 않음). v1 정책:

- 모든 기록 API에 `source: String` 인자(`"battle"` / `"debug"`).
  `source == "debug"`는 스토어가 **no-op + `{changed:false,
  reason:"debug_source"}`** 반환.
- `lingpet_debug_picker.gd`(F7 즉시 지급) 경유 지급은 `"debug"`로 호출.
- `stage_debug_picker._apply_selected_stage()`와
  `battle_debug_menu_switcher` 적용 시점에 owner 세션 플래그
  `codex_debug_tainted = true` 신설(BattleSceneState `DEFAULT_VALUES` 선언
  필수 — Owner-Field Schema 트랩). 플래그가 선 매치의 보스 조우/격파는
  `"debug"`로 강등. 플래그는 정식 재진입(캐릭터 선택부터 시작)에서 해제.
- 신화 아이템 디버그 스폰(2키 메뉴류) 경유도 동일 강등 — acquire_item 초크
  포인트에서 플래그를 읽는다.

---

## 6. i18n

- `language_settings_data.gd`의 `TEXT` 사전 **7언어 블록 각각에 동일 키**:
  `codex.title`, `codex.tab.guardian`, `codex.tab.yokai`, `codex.tab.relic`,
  `codex.undiscovered`(`???`), `codex.count_format`, `codex.completion`,
  `codex.detail.hatch_count`, `codex.detail.encounter_count`,
  `codex.detail.defeat_count`, `codex.detail.best_league`,
  `codex.detail.play_cry`, `codex.boss_intro.<boss_key>` (10종),
  `main_menu.codex`.
- 호출부는 전부 `LanguageSettings.translate("codex.*")`. 보스/아이템/수호령
  표시명은 기존 다국어 경로(`translate_text`, `ITEM_DISPLAY_*`,
  `localize_*`) 재사용 — 이름 사전을 새로 만들지 않는다.
- 회귀 봉인은 `tests/language_settings_smoke.gd` 패턴(7언어 키 동등성).

---

## 7. 씰(스모크) 계획

표준 러너 `run_smoke_tests.ps1` 관통 + `_failed` 게이트(공허-GREEN 트랩 준수).
신규 3본 + 락스텝 1본:

1. `codex_save_store_smoke.gd`
   - BOM 주입 파일 로드 → 첫 섹션 생존 / `last_good` 복구 왕복 / 마이그레이션.
   - 기록 API 누계 증가·`source:"debug"` no-op·`set_save_path` 격리.
   - 보스 최고 리그가 낮은 리그 격파로 **하향되지 않음**.
2. `codex_commit_hooks_smoke.gd` — **실경로 관통**(유닛 직호출 공허-GREEN 금지):
   - 실제 부화 시퀀스(알 타격→`advance_hatch_break`→커밋)를 몰아 부화 기록 단언
     — 기존 `lingpet_egg_runtime_smoke` 픽스처 재사용.
   - 승리 확정선 관통으로 격파 기록 + 리그 인덱스 단언, **패배 레그에서 기록
     0 단언**(대조군).
   - 신화 획득 실경로(리워드 리졸버 경유)로 획득 기록 단언.
   - 반증검증: 커밋 훅 한 줄을 in-place 토글로 죽였을 때 RED가 되는지 확인
     (git reset/checkout/stash 금지 — Edit 토글만).
3. `codex_overlay_smoke.gd`
   - 열기/닫기·탭 전환·`{"handled"}` 계약.
   - 미발견 엔트리에서 표시명이 **어떤 draw 경로로도 새지 않음**(???
     마스킹) — 상태 단언 + 문자열 단언.
   - 탭 카운트가 스토어 기록과 일치.
4. `main_menu_quit_confirmation_smoke.gd` 락스텝 갱신(버튼 추가로 인한
   가시성 계약 변화 반영).
- 최종 사인오프에 **윈도우드 픽셀 QA 1회** 포함(실루엣 modulate·9패치·링펫어
  폰트 혼합 렌더는 상태 스모크로 증명 불가 — TextureRect/클립 계열 트랩 전례).

---

## 8. 결정 대기 (사용자)

| # | 질문 | 권장 기본값 |
|---|---|---|
| 1 | 화면 명칭 — 「도감」 그대로 vs 환격전 톤 고유명(예: 봉령록·영수록·기록서). 리브랜딩 표기는 사용자 소유라 카피 확정 필요 | UI 버튼 「도감」, 화면 제목만 고유명 후보 검토 |
| 2 | 스테이지 3을 환묘 연묘 1엔트리로 둘지, 멘헤라/쿠로미(각성) 2엔트리로 쪼갤지 | v1은 1엔트리 |
| 3 | 신물 도감에 시네마틱 재감상 버튼(획득 시네마틱 리플레이)을 넣을지 | v2로 보류 |
| 4 | 도감 진행을 「새 플레이스루」류 초기화에서 리셋할지 | **리셋 안 함**(계정 영속) |

## 9. 구현 시 검증 항목 (배선 담당 체크리스트)

- V1: 부화 3경로가 전부 `record_collected_pet`을 경유하는지 — 경유하지 않으면
  3지점 명시 호출로 전환.
- V2: 아이템알 흡수 라우터의 `record_collected_pet` 호출 의미가 "부화"와
  동일한지(방생/absorb-only가 섞여 들어오지 않는지).
- V3: 신화 획득 3경로가 전부 `mythic_item_runtime.acquire_item` 성공 경로로
  수렴하는지 — 필드 스폰 직접 픽업 경로 존재 여부 포함.
- V4: 신물 도감 총계 대상 id 합집합(FIELD_SPAWN_ORDER 49 + elixir_of_mastery
  + 그 외 스폰 불가 카탈로그 id 유무).
- V5: 조우 기록의 매치당 1회 가드가 컨티뉴(기회의 보석) 재시작에서 중복
  발화하지 않는지.
- V6: `codex_debug_tainted`를 `BattleSceneState.DEFAULT_VALUES`에 선언했는지
  (미선언 `owner.set` = 조용한 no-op).
