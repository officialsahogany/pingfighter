extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlayTooltipPresenter := preload("res://scripts/hud/character_info_overlay_tooltip_presenter.gd")
# 하단 능력치 원장은 캐릭터 정보창과 "같은 값 / 같은 그림"이어야 하므로 행 조립기,
# 드로어, 색/스케일 상수를 전부 그쪽에서 그대로 끌어 쓴다. 여기서 상수를 다시
# 타이핑하면 두 화면이 조용히 갈라진다.
const CharacterInfoOverlayState := preload("res://scripts/hud/character_info_overlay_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkEffectiveStatQuerySurface := preload(
	"res://scripts/characters/runtime_perk_effective_stat_query_surface.gd"
)
const RuntimePerkTrainingStatPreview := preload("res://scripts/characters/runtime_perk_training_stat_preview.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const RuntimePerkDescriptionEmphasis := preload("res://scripts/hud/runtime_perk_description_emphasis.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")
const ActiveItemHudSlotIconRenderer := preload("res://scripts/hud/active_item_hud_slot_icon_renderer.gd")
const AngelBlessingRollOverlayHost := preload("res://scripts/hud/angel_blessing_roll_overlay_host.gd")
const MysticDiceOverlayRenderer := preload("res://scripts/hud/mystic_dice_overlay_renderer.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const PerkFusionColdBootCinematic := preload("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")
const RuntimePerkTraditionalChrome := preload("res://scripts/hud/runtime_perk_traditional_chrome.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const TowerAscentTuning := preload("res://scripts/tower_ascent/tower_ascent_tuning.gd")
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerShopNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)

const CARD_RADIUS := 8.0
const PANEL_RADIUS := 8.0
const CHOICE_MODAL_PARTICLE_DRAW_LIMIT := 10
const CHOICE_MODAL_PARTICLE_COMPACT_LIFE_RATIO := 0.68
const CHOICE_FLIGHT_PARTICLE_DRAW_LIMIT := 6
const CHOICE_FLIGHT_SOURCE_RING_COUNT := 1
const CHOICE_FLIGHT_ARRIVAL_RING_COUNT := 1
# Starpoint absorption: small spiral-descent visual that plays after the perk
# modal fully closes. Mirrors the data layout written by
# runtime_perk_state.gd's `_start_starpoint_absorption_effect` /
# `_update_starpoint_absorption_effect`.
const STARPOINT_ABSORPTION_ARRIVAL_ARC_SEGMENTS := 24
# 흡수되는 것은 방금 주운 무혼이므로 필드 드롭과 같은 팔레트를 공유한다.
# 여기서 색을 다시 타이핑하면 리브랜드가 이 표면만 조용히 놓친다.
const STARPOINT_ABSORPTION_GLOW_COLOR := CommonStarpointVisualHost.MUHON_GLOW_COLOR
const STARPOINT_ABSORPTION_CORE_COLOR := CommonStarpointVisualHost.MUHON_CORE_COLOR
const STARPOINT_ABSORPTION_BURST_COLOR := CommonStarpointVisualHost.MUHON_OUTLINE_COLOR
const TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO := 0.22
const TEMP_TOWER_REWARD_ABSORB_LIFT_PX := 30.0
const TOWER_START_NOTICE_OFFSET_Y := 24.0
const TOWER_START_COUNTDOWN_OFFSET_Y := 62.0
const FLIGHT_SOURCE_ARC_SEGMENTS := 10
const FLIGHT_CORE_ARC_SEGMENTS := 8
const FLIGHT_ARRIVAL_ARC_SEGMENTS := 10
const PERK_UNLOCK_SYMBOL_ARC_SEGMENTS := 20
const PERK_FALLBACK_SYMBOL_ARC_SEGMENTS := 24
const CARD_ICON_MEDALLION_WIDTH_RATIO := 0.51
const CARD_ICON_MEDALLION_HEIGHT_RATIO := 0.315
const CARD_ICON_DRAW_SCALE := 1.04
const CARD_ICON_MEDALLION_MIN_SIZE := 34.0
# 메달리온 바깥 그림자 링은 draw_circle(medallion_radius + 5)로 그려진다. 여백
# 계산은 반드시 이 링까지 포함해야 한다.
const CARD_MEDALLION_RADIUS_RATIO := 0.56
const CARD_MEDALLION_RIM_PAD := 5.0
# 이름판 상단 비율. _draw_card의 그리기와 메달리온 밴드 계산이 같은 값을 읽는다.
const CARD_NAMEPLATE_TOP_RATIO := 0.386
const CARD_NAMEPLATE_HEIGHT_RATIO := 0.092
# S3 reuses the two colors that previously painted the entire numeric-effect line
# and the friendly body line. Only their ownership changes: body stays dark ink,
# numeric/time/multiplier segments receive the existing warm-brown accent.
const CARD_DESCRIPTION_BODY_COLOR := Color(50.0 / 255.0, 42.0 / 255.0, 34.0 / 255.0)
const CARD_DESCRIPTION_EMPHASIS_COLOR := Color(96.0 / 255.0, 55.0 / 255.0, 26.0 / 255.0)
# 메달리온이 앉을 수 있는 세로 밴드 = [종이 상단 + 위 여백, 이름판 상단 - 아래 여백].
# 카드 높이 390 -> 316 축소(2026-08-06) 뒤 비율식 반지름(0.315 * h * 0.56 + 5)이
# 밴드보다 커져 바깥 링이 상단 황동 테두리를 파고들고(라이브 1.32배율에서 종이면
# 위로 약 1px) 하단은 이름판에 3px 물렸다. 이제 비율은 "희망 크기"일 뿐이고 실제
# 크기는 밴드가 정한다. 봉인:
# runtime_perk_traditional_choice_ui_smoke._verify_card_medallion_clearance
const CARD_MEDALLION_TOP_CLEARANCE_RATIO := 0.017
const CARD_MEDALLION_TOP_CLEARANCE_MIN := 4.0
const CARD_MEDALLION_TOP_CLEARANCE_MAX := 9.0
const CARD_MEDALLION_BOTTOM_CLEARANCE_RATIO := 0.013
const CARD_MEDALLION_BOTTOM_CLEARANCE_MIN := 3.0
const CARD_MEDALLION_BOTTOM_CLEARANCE_MAX := 7.0
const CARD_SELECTION_TRANSITION_MSEC := 160.0
const CARD_SELECTION_LIFT := 5.0
const CARD_SELECTION_SCALE := 0.028
# "현재 무공" 슬롯의 성급 금박 명패. 폰트는 셀 폭에 비례하는데 명패 높이가 16px
# 리터럴로 고정돼 있어, 셀이 커지면 어두운 글자가 명패 아래 어두운 셀 위로 흘러
# "글자 하단이 잘렸다"로 읽혔다(2026-08-07). 높이는 실제 폰트 메트릭에서 뽑는다.
# 성장 경지가 없는(max_level == 1) 무공 중, 명패에 전용 등급 문구를 실어야 하는
# 계열. 프레젠터가 `_level_text`로 정본 문구를 내려 준다(합일 -> "합일"). 단일
# 습득형의 범용 태그(고유 / 비급 / 절세무공)는 여기 넣지 않는다 -- 그건 TAB
# 정보창의 넓은 셀 계약이고, 이 좁은 명패는 "무엇으로 얻은 칸인가"만 말한다.
const STATUS_BADGE_TAG_TREES := ["fusion"]
const STATUS_BADGE_FONT_RATIO := 0.19
const STATUS_BADGE_MIN_FONT := 9
const STATUS_BADGE_VERTICAL_PADDING := 3.0
const STATUS_BADGE_HORIZONTAL_PADDING := 4.0
const STATUS_BADGE_BOTTOM_MARGIN_RATIO := 0.045
const STATUS_BADGE_BOTTOM_MARGIN_MIN := 4.0
# `_draw_text_centered`가 쓰는 baseline 근사 계수. 박스 안에 글자를 가두는 계산은
# 이 계수를 그대로 되짚어야 draw와 어긋나지 않는다.
const TEXT_CENTER_BASELINE_RATIO := 0.35
const TRADITIONAL_ORNAMENT_ATLAS_PATH := "res://assets/ui/runtime_perk/runtime_perk_inkwash_ornament_atlas_imagegen_v1.png"
const TRADITIONAL_CARD_PAPER_TEXTURE_PATH := "res://assets/ui/runtime_perk/runtime_perk_hanji_card_surface_imagegen_v2.png"
const TITLE_TEXT := "무공 수련!"
const UNLOCK_SHOWCASE_PANEL_TEXTURE_PATH := "res://assets/sprites/hud/runtime_perk_unlock_showcase_panel_imagegen_v1.png"
const UNLOCK_SHOWCASE_PANEL_ASPECT := 1939.0 / 811.0
const UNLOCK_SHOWCASE_PANEL_MIN_WIDTH := 520.0
const UNLOCK_SHOWCASE_PANEL_MAX_WIDTH := 690.0
const UNLOCK_SHOWCASE_PANEL_HORIZONTAL_MARGIN := 84.0
const UNLOCK_SHOWCASE_TITLE_TEXT := "새 초식 습득!"
const UNLOCK_SHOWCASE_PROMPT_TEXT := "아무 키나 눌러 계속"
const TITLE_FONT_SIZE := 44
const TOWER_REWARD_BALANCE_FONT_SIZE := 26.0
const TOWER_REWARD_BALANCE_MIN_FONT_SIZE := 21
const TOWER_REWARD_BALANCE_ICON_FONT_RATIO := 0.92
const TOWER_REWARD_BALANCE_TEXT_GAP_ICON_RATIO := 0.42
const TOWER_REWARD_BALANCE_ROW_HEIGHT_FONT_RATIO := 1.32
const TOWER_REWARD_BALANCE_TITLE_OFFSET := 164.0
const TOWER_REWARD_BALANCE_RIGHT_MARGIN := 18.0
const TOWER_REWARD_BALANCE_OUTLINE_FONT_RATIO := 0.10
const TOWER_REWARD_ACQUISITION_FONT_RATIO := 0.65
const TOWER_REWARD_ACQUISITION_MIN_FONT_SIZE := 14
const TOWER_REWARD_ACQUISITION_TOP_GAP := 2.0
const TOWER_REWARD_ACQUISITION_ROW_HEIGHT_FONT_RATIO := 1.28
const MYTHIC_REVEAL_LIGHTBURST_PATH := "res://assets/sprites/hud/mythic_reveal_lightburst_v1.png"
const MYTHIC_REVEAL_SMOKE_PATH := "res://assets/sprites/hud/mythic_reveal_smoke_v1.png"
const MYTHIC_REVEAL_DURATION := 1.5
const MYTHIC_GOLD_DEEP := Color(1.0, 178.0 / 255.0, 44.0 / 255.0)
const MYTHIC_GOLD_BRIGHT := Color(1.0, 224.0 / 255.0, 120.0 / 255.0)
const MYTHIC_GOLD_HIGHLIGHT := Color(1.0, 247.0 / 255.0, 214.0 / 255.0)
const MYTHIC_GOLD_AMBER := Color(1.0, 150.0 / 255.0, 30.0 / 255.0)
const MYTHIC_ORNAMENT_SPARKLE_COUNT := 7
const MYTHIC_ORNAMENT_COMPACT_SPARKLE_COUNT := 5
const MYTHIC_ORNAMENT_CROWN_MIN_REF := 70.0
const TITLE_SHADOW_DRAW_COUNT := 1
const TEXT_FIT_CACHE_LIMIT := 160
const TEXT_SIZE_CACHE_LIMIT := 160
# 능력치 행 재조립 주기(ms). 모달이 열려 있는 동안 게임플레이는 멈춰 있어
# 수치가 바뀌지 않지만, 어떤 경로로든 값이 갱신되면 늦어도 이 주기 안에는
# 따라잡도록 안전망을 둔다.
const STATS_BAND_REBUILD_INTERVAL_MSEC := 500
const TRAINING_STAT_PREVIEW_BLINK_CYCLE_MSEC := 800
const TRAINING_STAT_PREVIEW_VISIBLE_MSEC := 400
const TRAINING_STAT_PREVIEW_FADE_GAIN := 1.25
const TRAINING_STAT_PREVIEW_FADE_BIAS := 0.125
const TOWER_NODE_HOVER_ICON_SCALE := 1.08
const TOWER_NODE_HOVER_LIFT := 5.0
const TOWER_NODE_OTHER_DIM_ALPHA := 0.10
const TOWER_NODE_HOVER_DETAIL_ROW_LIMIT := 3
const TOWER_NODE_COMPACT_CARD_MAX_ASPECT := 0.70
const TOWER_NODE_COMPACT_CARD_BASE_WIDTH := 216.66667
const TOWER_NODE_COMPACT_CARD_BASE_HEIGHT := 106.0
const TOWER_NODE_DESCRIPTION_ROW_LIMIT := 3
const TOWER_NODE_BONUS_BADGE_ROW_LIMIT := 1

var _fallback_font: Font = null
var _tower_node_compact_font: FontVariation = null
var _tower_node_compact_font_base: Font = null
var _tower_node_compact_font_spacing := -1
var _draw_now_msec := 0
var _draw_time_override_msec := -1
var _title_text_size := Vector2.ZERO
var _title_text_line: TextLine = null
var _title_text_line_font_id := 0
var _title_text_line_font_size := 0
var _title_text_line_language := ""
var _title_text_line_source := ""
var _text_fit_cache: Dictionary = {}
var _text_size_cache: Dictionary = {}
var _text_cache_font_id := 0
var _back_glow_stylebox: StyleBoxFlat = null
# Per-card description wrap cache: rebuilt only when the choice set or card
# width changes (the modal redraws every frame for its animation).
var _card_desc_cache_signature := 0
var _card_desc_cache: Array = []
var _choice_visual_signature := 0
var _choice_visual_index := -1
var _choice_visual_previous_index := -1
var _choice_visual_transition_started_msec := 0
var _tower_reward_slot_session_id := -1
var _tower_reward_slot_keys: Array[String] = []
var _tower_reward_slot_highlight_keys: Array[String] = []
var _tower_reward_hover_preview_signature := 0
var _tower_reward_hover_preview_cache_valid := false
var _tower_reward_hover_preview_model: Dictionary = {}
var _tower_reward_hover_preview_build_count := 0
var _tower_reward_hover_grid_signature := 0
var _tower_reward_hover_grid_cache_valid := false
var _tower_reward_hover_grid_entries: Array = []
var _tower_reward_hover_grid_build_count := 0
var _tower_reward_hover_effective_levels: Object = RuntimePerkEffectiveLevels.new()
var _tower_reward_hover_effective_query_surface: Object = RuntimePerkEffectiveStatQuerySurface.new()
var _tower_reward_hover_landing_projection_count := 0
var _tower_reward_landing_draw_count := 0
var _tower_reward_material_draw_count := 0
var _tower_active_item_icon_renderer: Object = ActiveItemHudSlotIconRenderer.new()
# prewarm_assets가 채우는 디스크리트 프리웜 캐시 — draw 핫패스는 조회만
# 한다(미스 시 절차 폴백, 핫패스 로드 금지 트랩).
var _unlock_showcase_panel_texture: Texture2D = null
var _mythic_reveal_lightburst_texture: Texture2D = null
var _mythic_reveal_smoke_texture: Texture2D = null
var _traditional_ornament_atlas_texture: Texture2D = null
var _traditional_card_paper_texture: Texture2D = null

# 하단 능력치 원장 캐시. 행 조립(build_player_stat_rows)은 레지스트리 모듈을
# 여러 개 훑는 비싼 작업이라 시그니처가 바뀔 때만 다시 만들고, 매 프레임에는
# 프레젠터의 표시 캐시 갱신 + 드로우만 돌린다.
var _stats_character_runtime: Object = PlayerCharacterRuntime.new()
var _training_stat_preview: Object = RuntimePerkTrainingStatPreview.new()
var _training_stat_preview_signature := 0
var _training_stat_preview_model: Dictionary = {}
var _tower_node_hover_layout_signature := 0
var _tower_node_hover_layout_model: Dictionary = {}
var _tower_node_hover_layout_build_count := 0
var _tower_node_feedback_dynamic_layer_draw_count := 0
var _stats_rows: Array = []
var _stats_rows_signature := 0
var _stats_rows_built_msec := 0
var _stats_row_cache: Array = []
var _stats_label_cache: Array[String] = []
var _stats_value_cache: Array[String] = []
var _stats_color_cache: Array[Color] = []
var _stats_value_width_cache: Array[float] = []
var _stats_value_width_text_cache: Array[String] = []
var _stats_value_width_size_cache: Array[int] = []
var _stats_value_width_font_id_cache: Array[int] = []
# 드로어가 행 rect를 append하는 출력 버퍼. 기본 인자([])를 그대로 쓰면 GDScript가
# 기본값 배열 인스턴스를 재사용해 프레임마다 무한히 늘어난다 — 소유 버퍼를 넘기고
# 매 프레임 비운다.
var _stats_hover_row_rects: Array = []
var _stats_hover_data: Dictionary = {}
var _tower_training_stats_rows: Array = []
var _tower_training_stats_row_cache: Array = []
var _tower_training_stats_label_cache: Array[String] = []
var _tower_training_stats_value_cache: Array[String] = []
var _tower_training_stats_color_cache: Array[Color] = []
var _tower_training_stats_value_width_cache: Array[float] = []
var _tower_training_stats_value_width_text_cache: Array[String] = []
var _tower_training_stats_value_width_size_cache: Array[int] = []
var _tower_training_stats_value_width_font_id_cache: Array[int] = []
var _tower_training_stats_hover_row_rects: Array = []
var _tower_training_stats_hover_data: Dictionary = {}
var _tower_training_stats_prepare_count := 0


# 시스템 카드 모달 전용 렌더러(오버레이 소유 — draw 밖 prewarm_assets에서
# 함께 프리웜).
var _mystic_dice_overlay_renderer: Object = MysticDiceOverlayRenderer.new()
var _perk_fusion_overlay_renderer: Object = PerkFusionOverlayRenderer.new()
var _prewarm_assets_step_index := 0
var _prewarm_assets_complete := false


func prewarm_assets() -> void:
	prewarm_traditional_choice_assets()
	if _unlock_showcase_panel_texture == null:
		_unlock_showcase_panel_texture = ProjectResourceLoader.load_texture(
			UNLOCK_SHOWCASE_PANEL_TEXTURE_PATH,
			"Missing unlock showcase panel texture: %s",
			"Failed to load unlock showcase panel texture: %s"
		)
	if _mythic_reveal_lightburst_texture == null:
		_mythic_reveal_lightburst_texture = ProjectResourceLoader.load_texture(
			MYTHIC_REVEAL_LIGHTBURST_PATH,
			"Missing mythic reveal lightburst texture: %s",
			"Failed to load mythic reveal lightburst texture: %s"
		)
	if _mythic_reveal_smoke_texture == null:
		_mythic_reveal_smoke_texture = ProjectResourceLoader.load_texture(
			MYTHIC_REVEAL_SMOKE_PATH,
			"Missing mythic reveal smoke texture: %s",
			"Failed to load mythic reveal smoke texture: %s"
		)
	AngelBlessingRollOverlayHost.prewarm_assets()
	_mystic_dice_overlay_renderer.prewarm_assets()
	_perk_fusion_overlay_renderer.prewarm_assets()
	PerkFusionColdBootCinematic.prewarm_assets()
	var font: Font = _get_font()
	if font == null:
		_prewarm_assets_complete = true
		return
	_prepare_text_caches()
	_get_title_text_line(font)
	_get_title_text_size(font)
	for sample in [
		{"text": TITLE_TEXT, "size": TITLE_FONT_SIZE},
		{"text": UNLOCK_SHOWCASE_TITLE_TEXT, "size": 24},
		{"text": UNLOCK_SHOWCASE_PROMPT_TEXT, "size": 14},
		{"text": "1성", "size": 18},
		{"text": "극성", "size": 18},
		{"text": "극성 +1", "size": 18},
		{"text": "Lv.1", "size": 18},
		{"text": "+1", "size": 11},
		{"text": "A", "size": 12},
		{"text": "G", "size": 20},
		{"text": "...", "size": 12},
	]:
		_get_text_size(font, str(sample.get("text", "")), int(sample.get("size", 14)))
	_get_fitted_text(font, TITLE_TEXT, 18, 12, 180.0)
	_prewarm_assets_complete = true


func prewarm_assets_step() -> bool:
	if _prewarm_assets_complete:
		return true
	match _prewarm_assets_step_index:
		0:
			var ornament_result := ProjectResourceLoader.prewarm_texture_threaded_step(TRADITIONAL_ORNAMENT_ATLAS_PATH)
			if not bool(ornament_result.get("done", false)):
				return false
			_traditional_ornament_atlas_texture = ornament_result.get("texture", null) as Texture2D
		1:
			var paper_result := ProjectResourceLoader.prewarm_texture_threaded_step(TRADITIONAL_CARD_PAPER_TEXTURE_PATH)
			if not bool(paper_result.get("done", false)):
				return false
			_traditional_card_paper_texture = paper_result.get("texture", null) as Texture2D
		2:
			var panel_result := ProjectResourceLoader.prewarm_texture_threaded_step(UNLOCK_SHOWCASE_PANEL_TEXTURE_PATH)
			if not bool(panel_result.get("done", false)):
				return false
			_unlock_showcase_panel_texture = panel_result.get("texture", null) as Texture2D
		3:
			var lightburst_result := ProjectResourceLoader.prewarm_texture_threaded_step(MYTHIC_REVEAL_LIGHTBURST_PATH)
			if not bool(lightburst_result.get("done", false)):
				return false
			_mythic_reveal_lightburst_texture = lightburst_result.get("texture", null) as Texture2D
		4:
			var smoke_result := ProjectResourceLoader.prewarm_texture_threaded_step(MYTHIC_REVEAL_SMOKE_PATH)
			if not bool(smoke_result.get("done", false)):
				return false
			_mythic_reveal_smoke_texture = smoke_result.get("texture", null) as Texture2D
		5:
			if not AngelBlessingRollOverlayHost.prewarm_assets_step():
				return false
		6:
			_mystic_dice_overlay_renderer.prewarm_assets()
		7:
			if not _perk_fusion_overlay_renderer.prewarm_assets_step():
				return false
		8:
			if not PerkFusionColdBootCinematic.prewarm_assets_step():
				return false
		9:
			var font: Font = _get_font()
			if font != null:
				_prepare_text_caches()
				_get_title_text_line(font)
				_get_title_text_size(font)
		_:
			_prewarm_assets_step_index = 0
			_prewarm_assets_complete = true
			return true
	_prewarm_assets_step_index += 1
	return false


func get_prewarm_assets_debug_label() -> String:
	return str({
		0: "traditional_ornament",
		1: "traditional_paper",
		2: "unlock_panel",
		3: "mythic_lightburst",
		4: "mythic_smoke",
		5: "angel_blessing",
		6: "mystic_dice",
		7: "fusion_overlay",
		8: "fusion_cold_boot",
		9: "text_cache",
	}.get(_prewarm_assets_step_index, "done"))


func prewarm_traditional_choice_assets() -> void:
	if _traditional_ornament_atlas_texture == null:
		_traditional_ornament_atlas_texture = ProjectResourceLoader.load_texture(
			TRADITIONAL_ORNAMENT_ATLAS_PATH,
			"Missing traditional perk ornament atlas: %s",
			"Failed to load traditional perk ornament atlas: %s"
		)
	if _traditional_card_paper_texture == null:
		_traditional_card_paper_texture = ProjectResourceLoader.load_texture(
			TRADITIONAL_CARD_PAPER_TEXTURE_PATH,
			"Missing traditional perk card paper texture: %s",
			"Failed to load traditional perk card paper texture: %s"
		)
	if _traditional_ornament_atlas_texture != null:
		_traditional_ornament_atlas_texture.get_size()
	if _traditional_card_paper_texture != null:
		_traditional_card_paper_texture.get_size()


func has_visible_effects(
	runtime_state: Object,
	mythic_item_runtime: Object = null
) -> bool:
	if _runtime_state_has_visible_effects(runtime_state):
		return true
	if mythic_item_runtime != null and mythic_item_runtime.has_method("is_activation_effect_active"):
		if bool(mythic_item_runtime.is_activation_effect_active()):
			return true
	return false


func draw(
	canvas: CanvasItem,
	runtime_state: Object,
	catalog: Object,
	view_size: Vector2,
	icon_renderer: Object = null,
	mythic_item_runtime: Object = null,
	perf_logger: Object = null
) -> void:
	if canvas == null or runtime_state == null or not runtime_state.has_method("is_choice_active"):
		return
	_capture_draw_msec()
	_prepare_text_caches()
	if not bool(runtime_state.is_choice_active()):
		var inactive_start: int = _perf_begin(perf_logger)
		_draw_feedback(canvas, runtime_state, view_size)
		_perf_end(perf_logger, "hud.perk_overlay.feedback", inactive_start)
		inactive_start = _perf_begin(perf_logger)
		_draw_mythic_item_effect(canvas, mythic_item_runtime, view_size)
		_perf_end(perf_logger, "hud.perk_overlay.mythic_effect", inactive_start)
		# Starpoint absorption fires AFTER the modal closes, so the renderer must
		# read its state from the inactive branch as well. Snapshot is cheap when
		# the effect dict is empty (just one Dictionary.get + early return).
		inactive_start = _perf_begin(perf_logger)
		_draw_starpoint_absorption_effect(canvas, runtime_state)
		_perf_end(perf_logger, "hud.perk_overlay.starpoint_absorption", inactive_start)
		return

	var sample_start: int = _perf_begin(perf_logger)
	var snapshot: Dictionary = runtime_state.get_snapshot()
	_perf_end(perf_logger, "hud.perk_overlay.snapshot", sample_start)
	# 퍽 융합 모달(S1~S4): 표준 선택 카드 대신 전용 렌더러가 그린다 —
	# raw choice_active는 유지되므로 이 라우팅이 카드 드로우보다 먼저 오고,
	# 융합 모달 활성 중 일반 카드는 그리지 않는다.
	if runtime_state.has_method("is_perk_fusion_modal_active") and bool(runtime_state.is_perk_fusion_modal_active()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_perk_fusion_overlay_renderer.draw(
			canvas,
			runtime_state.get_perk_fusion_modal_snapshot(),
			catalog,
			view_size,
			icon_renderer
		)
		_perf_end(perf_logger, "hud.perk_overlay.perk_fusion_modal", sample_start)
		return
	# 신비의 주사위 모달(D1~D3): 표준 선택 카드 대신 전용 렌더러가 그린다 —
	# raw choice_active는 유지되므로 이 라우팅이 카드 드로우보다 먼저 온다.
	if runtime_state.has_method("is_mystic_dice_modal_active") and bool(runtime_state.is_mystic_dice_modal_active()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_mystic_dice_overlay_renderer.draw(
			canvas,
			runtime_state.get_mystic_dice_modal_snapshot(),
			runtime_state.get_mystic_dice_snapshot(),
			view_size
		)
		_perf_end(perf_logger, "hud.perk_overlay.mystic_dice_modal", sample_start)
		return
	if runtime_state.has_method("is_unlock_showcase_active") and bool(runtime_state.is_unlock_showcase_active()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_draw_particles(canvas, snapshot)
		_perf_end(perf_logger, "hud.perk_overlay.unlock_showcase_particles", sample_start)
		sample_start = _perf_begin(perf_logger)
		_draw_unlock_showcase(canvas, snapshot, view_size, icon_renderer)
		_perf_end(perf_logger, "hud.perk_overlay.unlock_showcase", sample_start)
		return
	if runtime_state.has_method("has_pending_unlock_swap") and bool(runtime_state.has_pending_unlock_swap()):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 20.0 / 255.0, 0.68))
		sample_start = _perf_begin(perf_logger)
		_draw_particles(canvas, snapshot)
		_perf_end(perf_logger, "hud.perk_overlay.swap_particles", sample_start)
		sample_start = _perf_begin(perf_logger)
		_draw_unlock_swap_dialog(canvas, runtime_state, snapshot, view_size, icon_renderer)
		_perf_end(perf_logger, "hud.perk_overlay.swap_dialog", sample_start)
		sample_start = _perf_begin(perf_logger)
		_draw_feedback(canvas, runtime_state, view_size)
		_perf_end(perf_logger, "hud.perk_overlay.feedback", sample_start)
		return
	var choices: Array = _get_array(snapshot.get("current_choices", []))
	if choices.is_empty():
		return

	var selected_index: int = int(snapshot.get("selected_index", 0))
	sample_start = _perf_begin(perf_logger)
	var layout: Dictionary = runtime_state.build_layout(view_size)
	_perf_end(perf_logger, "hud.perk_overlay.layout", sample_start)

	var animation_time: float = float(snapshot.get("animation_time", 0.0))
	var backdrop_alpha: float = clamp(animation_time / 0.18, 0.0, 1.0)
	RuntimePerkTraditionalChrome.draw_backdrop(canvas, view_size, backdrop_alpha, _traditional_ornament_atlas_texture)
	_draw_training_signage(canvas, view_size, backdrop_alpha)
	sample_start = _perf_begin(perf_logger)
	_draw_particles(canvas, snapshot)
	_perf_end(perf_logger, "hud.perk_overlay.particles", sample_start)
	sample_start = _perf_begin(perf_logger)
	var layout_scale: float = float(layout.get("layout_scale", 1.0))
	_draw_title(canvas, _get_vector2(layout.get("title_pos", Vector2.ZERO)), animation_time, layout_scale)
	_perf_end(perf_logger, "hud.perk_overlay.title", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_mythic_reveal_backdrop(canvas, runtime_state, choices, view_size, animation_time)
	_perf_end(perf_logger, "hud.perk_overlay.mythic_reveal", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_cards(canvas, runtime_state, choices, selected_index, view_size, animation_time, icon_renderer)
	_perf_end(perf_logger, "hud.perk_overlay.cards", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_per_card_descriptions(canvas, runtime_state, choices, selected_index, layout, animation_time)
	_perf_end(perf_logger, "hud.perk_overlay.description", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_status_panel(canvas, runtime_state, snapshot, catalog, _get_rect2(layout.get("panel_rect", Rect2())), icon_renderer, view_size)
	_perf_end(perf_logger, "hud.perk_overlay.status_panel", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stats_band(
		canvas,
		runtime_state,
		snapshot,
		_get_rect2(layout.get("stats_rect", Rect2())),
		view_size,
		icon_renderer,
		null,
		choices,
		runtime_state.get_card_rects(view_size) if runtime_state.has_method("get_card_rects") else []
	)
	_perf_end(perf_logger, "hud.perk_overlay.stats_band", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_pending_hint(canvas, snapshot, _get_vector2(layout.get("hint_pos", Vector2.ZERO)), runtime_state, layout_scale)
	_perf_end(perf_logger, "hud.perk_overlay.pending_hint", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_feedback(canvas, runtime_state, view_size)
	_perf_end(perf_logger, "hud.perk_overlay.feedback", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_mythic_item_effect(canvas, mythic_item_runtime, view_size)
	_perf_end(perf_logger, "hud.perk_overlay.mythic_effect", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_choice_flight_effect(canvas, _get_dict(snapshot.get("choice_flight_effect", {})), icon_renderer)
	_perf_end(perf_logger, "hud.perk_overlay.choice_flight", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_starpoint_absorption_effect(canvas, runtime_state)
	_perf_end(perf_logger, "hud.perk_overlay.starpoint_absorption", sample_start)


func draw_tower_start_card(
	canvas: CanvasItem,
	view_model: Dictionary,
	runtime_state: Object,
	_catalog: Object,
	icon_renderer: Object,
	view_size: Vector2,
	_snapshot: Dictionary,
	mouse_pos: Vector2
) -> void:
	if canvas == null:
		return
	_capture_draw_msec()
	_prepare_text_caches()
	var animation_time := float(view_model.get("animation_time", 0.0))
	var alpha := clampf(
		animation_time / TowerAscentTuning.TEMP_START_CARD_INTRO_ANIM_SEC,
		0.0,
		1.0
	)
	var layout: Dictionary = _get_dict(view_model.get("layout", {}))
	var choices: Array = _get_array(view_model.get("choices", []))
	var rects: Array = _get_array(view_model.get("card_rects", []))
	var selected_index := int(view_model.get("selected_index", 0))
	var layout_scale := float(layout.get("layout_scale", 1.0))
	canvas.draw_rect(
		Rect2(Vector2.ZERO, view_size),
		Color(0.0, 0.0, 0.0, TowerAscentTuning.TEMP_START_CARD_BACKDROP_ALPHA),
		true
	)
	_draw_particles(canvas, _snapshot)
	_draw_title(
		canvas,
		_get_vector2(layout.get("title_pos", Vector2(view_size.x * 0.5, 72.0))),
		animation_time,
		minf(layout_scale, 1.0),
		str(view_model.get("title", ""))
	)
	_sync_choice_visual_selection(choices, selected_index)
	var absorb_elapsed := float(view_model.get("absorb_elapsed_sec", -1.0))
	var absorb_duration := maxf(
		0.001,
		float(view_model.get("absorb_duration_sec", 1.0))
	)
	var absorb_progress := clampf(absorb_elapsed / absorb_duration, 0.0, 1.0)
	var absorption: Dictionary = _get_dict(view_model.get("absorption_effect", {}))
	for index in range(mini(choices.size(), rects.size())):
		if not (choices[index] is Dictionary) or not (rects[index] is Rect2):
			continue
		var choice := choices[index] as Dictionary
		var rect := rects[index] as Rect2
		var selected := index == selected_index
		var was_selected := bool(choice.get("start_card_selected", false))
		if was_selected and absorb_elapsed >= 0.0 and not absorption.is_empty():
			var animated_rect := _build_tower_reward_absorbing_rect(rect, absorption)
			_draw_tower_reward_absorption(canvas, rect, absorption)
			_draw_card(
				canvas,
				choice,
				animated_rect,
				false,
				1.0,
				icon_renderer,
				_choice_visual_blend(index),
				index
			)
			continue
		if was_selected and absorb_elapsed >= 0.0:
			var pulse := sin(absorb_progress * PI)
			canvas.draw_rect(
				rect.grow(4.0 + 8.0 * pulse),
				Color(0.96, 0.76, 0.32, (0.30 + 0.28 * pulse) * alpha),
				false,
				2.0 + pulse
			)
		_draw_card(
			canvas,
			choice,
			rect,
			selected,
			animation_time,
			icon_renderer,
			_choice_visual_blend(index),
			index
		)
		if not bool(choice.get("enabled", true)) and not was_selected:
			canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.46 * alpha), true)
	_draw_per_card_descriptions(
		canvas,
		runtime_state,
		choices,
		selected_index,
		layout,
		animation_time
	)
	var hint_pos := _get_vector2(
		layout.get("hint_pos", Vector2(view_size.x * 0.5, view_size.y - 34.0))
	)
	_draw_text_centered(
		canvas,
		str(view_model.get("status_text", "")),
		hint_pos,
		clampi(int(round(16.0 * layout_scale)), 13, 21),
		Color(0.91, 0.86, 0.72, alpha)
	)
	var notice_text := str(view_model.get("random_autoselect_notice_text", ""))
	if not notice_text.is_empty():
		_draw_text_centered(
			canvas,
			notice_text,
			hint_pos + Vector2(0.0, TOWER_START_NOTICE_OFFSET_Y * layout_scale),
			clampi(int(round(14.0 * layout_scale)), 12, 18),
			Color(0.82, 0.80, 0.72, alpha)
		)
	var countdown_seconds := int(view_model.get("countdown_seconds", 0))
	if countdown_seconds > 0:
		_draw_text_centered(
			canvas,
			str(countdown_seconds),
			hint_pos + Vector2(0.0, TOWER_START_COUNTDOWN_OFFSET_Y * layout_scale),
			clampi(int(round(34.0 * layout_scale)), 26, 42),
			Color(0.96, 0.76, 0.32, alpha)
		)
	_draw_hovered_tower_chosik_tooltip(canvas, view_model, view_size, mouse_pos)


func build_tower_node_card_text_layout(action: Dictionary, rect: Rect2) -> Dictionary:
	_prepare_text_caches()
	var choice := _tower_node_card_choice(action)
	var description := str(choice.get("description", "")).strip_edges()
	if description.is_empty():
		description = str(choice.get("detail", "")).strip_edges()
	# The card rect is already in screen space. An absolute pixel-height gate
	# would flip back to the legacy layout at a large Vulkan viewport, so the
	# compact service-card profile is identified by its scale-invariant aspect.
	var compact_card := (
		rect.size.y / maxf(1.0, rect.size.x)
		<= TOWER_NODE_COMPACT_CARD_MAX_ASPECT
	)
	var compact_scale := (
		maxf(0.01, minf(
			rect.size.x / TOWER_NODE_COMPACT_CARD_BASE_WIDTH,
			rect.size.y / TOWER_NODE_COMPACT_CARD_BASE_HEIGHT
		))
		if compact_card
		else 1.0
	)
	var font_size := (
		clampi(int(round(12.0 * compact_scale)), 11, 18)
		if compact_card
		else clampi(int(round(rect.size.x * 0.056)), 11, 13)
	)
	var text_width := maxf(24.0, rect.size.x - (22.0 if compact_card else 28.0))
	var text_font := (
		_get_tower_node_compact_font(compact_scale)
		if compact_card
		else _get_font()
	)
	var description_wrap := _wrap_text_px_with_budget(
		description,
		font_size,
		text_width,
		TOWER_NODE_DESCRIPTION_ROW_LIMIT,
		text_font
	)
	var description_rows: Array = description_wrap.get("lines", [])
	var unreserved_description_row_count := description_rows.size()
	var unavailable_reason_row_reserved := (
		compact_card
		and not bool(action.get("enabled", true))
		and not str(action.get("unavailable_reason", "")).strip_edges().is_empty()
		and not description_rows.is_empty()
	)
	var unavailable_reason_row_omitted_count := 0
	if unavailable_reason_row_reserved:
		# GRT-021: the unavailable receipt owns the lower compact text lane. Yield
		# one complete description row; vertically clipping the last row can turn
		# its remaining glyphs into a different promise. At the 760px logical size
		# the same sentence may wrap to one extra row, so keep yielding whole rows
		# until the last retained baseline clears the fixed receipt lane.
		while not description_rows.is_empty():
			description_rows.resize(description_rows.size() - 1)
			unavailable_reason_row_omitted_count += 1
			if description_rows.is_empty():
				break
			var last_description_baseline := (
				rect.position.y
				+ 64.0 * compact_scale
				+ float(description_rows.size() - 1) * 12.0 * compact_scale
			)
			var unavailable_reason_center_y := rect.end.y - 31.0 * compact_scale
			if (
				absf(last_description_baseline - unavailable_reason_center_y)
				>= float(font_size)
			):
				break
	var description_row_budget := description_rows.size()
	var strict_text_budget := bool(choice.get("tower_node_strict_text_budget", false))
	var description_hidden_by_budget := (
		strict_text_budget
		and (
			int(description_wrap.get("discarded_line_count", 0)) > 0
			or unavailable_reason_row_reserved
		)
	)
	if description_hidden_by_budget:
		# GRT-021: Spring/Rest presentation sentences are semantic contracts.
		# When the entire sentence cannot fit, omit it instead of drawing a clipped
		# fragment that can be read as a different outcome.
		description_rows = []
	var bonus_badge_text := str(choice.get("bonus_badge_text", "")).strip_edges()
	var bonus_badge_font_size := clampi(int(round(10.0 * compact_scale)), 9, 18)
	var bonus_badge_rows: Array[String] = []
	var bonus_badge_hidden_by_budget := false
	if compact_card and not bonus_badge_text.is_empty():
		while (
			bonus_badge_font_size > 9
			and text_font != null
			and _get_text_size(
				text_font,
				bonus_badge_text,
				bonus_badge_font_size
			).x > text_width
		):
			bonus_badge_font_size -= 1
		var badge_fits_one_row := (
			text_font != null
			and _get_text_size(text_font, bonus_badge_text, bonus_badge_font_size).x <= text_width
		)
		if badge_fits_one_row and TOWER_NODE_BONUS_BADGE_ROW_LIMIT >= 1:
			bonus_badge_rows.append(bonus_badge_text)
		else:
			# GRT-021: the bonus promise is semantic. If the complete Korean copy
			# cannot consume one additional row, omit the entire badge instead of
			# showing an ellipsis that can be mistaken for a different rule.
			bonus_badge_hidden_by_budget = true
	return {
		"choice": choice,
		"compact_card": compact_card,
		"compact_scale": compact_scale,
		"text_font": text_font,
		"description_font_size": font_size,
		"description_rows": description_rows,
		"unreserved_description_row_count": unreserved_description_row_count,
		"description_row_budget": description_row_budget,
		"unavailable_reason_row_reserved": unavailable_reason_row_reserved,
		"unavailable_reason_row_omitted_count": unavailable_reason_row_omitted_count,
		# GRT-021: this is the count of rows actually appended by the same
		# width-aware builder consumed by draw_tower_node_card below.
		"appended_description_row_count": description_rows.size(),
		"source_description_row_count": int(description_wrap.get("source_line_count", 0)),
		"description_hidden_by_budget": description_hidden_by_budget,
		"bonus_badge_text": bonus_badge_text,
		"bonus_badge_font_size": bonus_badge_font_size,
		"bonus_badge_rows": bonus_badge_rows,
		"bonus_badge_visible": bonus_badge_rows.size() == 1,
		"bonus_badge_hidden_by_budget": bonus_badge_hidden_by_budget,
		"appended_bonus_badge_row_count": bonus_badge_rows.size(),
		"appended_text_row_count": description_rows.size() + bonus_badge_rows.size(),
	}


func build_tower_node_hover_detail_layout(
	action: Dictionary,
	rect: Rect2
) -> Dictionary:
	_prepare_text_caches()
	var payload_value: Variant = action.get("payload", {})
	var payload: Dictionary = payload_value as Dictionary if payload_value is Dictionary else {}
	var presentation_value: Variant = payload.get("presentation", {})
	var presentation: Dictionary = (
		(presentation_value as Dictionary).duplicate(true)
		if presentation_value is Dictionary
		else {}
	)
	var choice := _tower_node_card_choice(action)
	var layout_signature := hash([
		action,
		rect.size,
		LanguageSettings.get_language(),
	])
	if (
		layout_signature == _tower_node_hover_layout_signature
		and not _tower_node_hover_layout_model.is_empty()
	):
		return _tower_node_hover_layout_model.duplicate(true)
	_tower_node_hover_layout_signature = layout_signature
	_tower_node_hover_layout_build_count += 1
	var current_text := str(presentation.get("current", "")).strip_edges()
	var result_text := str(presentation.get("result", "")).strip_edges()
	var target_text := str(presentation.get(
		"target",
		choice.get("name", action.get("label", ""))
	)).strip_edges()
	var cost_text := str(action.get("cost_text", "")).strip_edges()
	var reason_text := str(action.get("unavailable_reason", "")).strip_edges()
	var source_rows: Array[String] = []
	if not current_text.is_empty() or not result_text.is_empty():
		source_rows.append(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_HOVER_CURRENT_RESULT,
			{"current": current_text, "result": result_text}
		))
	if not target_text.is_empty() or not cost_text.is_empty():
		source_rows.append(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_HOVER_TARGET_COST,
			{"target": target_text, "cost": cost_text}
		))
	if not reason_text.is_empty():
		source_rows.append(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_HOVER_REJECTION,
			{"reason": reason_text}
		))
	var font_size := clampi(int(round(rect.size.x * 0.050)), 10, 12)
	var rows: Array[String] = []
	var strict_text_budget := bool(presentation.get("strict_text_budget", false))
	var hidden_by_budget := false
	if strict_text_budget:
		var font := _get_font()
		if font != null:
			var complete_rows: Array[String] = []
			for source_row in source_rows:
				for wrapped_row in _wrap_text_px_all(
					font,
					source_row,
					font_size,
					maxf(24.0, rect.size.x - 24.0)
				):
					complete_rows.append(str(wrapped_row))
			if complete_rows.size() <= TOWER_NODE_HOVER_DETAIL_ROW_LIMIT:
				rows = complete_rows
			else:
				hidden_by_budget = true
	else:
		for source_row in source_rows:
			var remaining := TOWER_NODE_HOVER_DETAIL_ROW_LIMIT - rows.size()
			if remaining <= 0:
				break
			var wrapped := _wrap_text_px(
				source_row,
				font_size,
				maxf(24.0, rect.size.x - 24.0),
				remaining
			)
			for wrapped_row in wrapped:
				rows.append(str(wrapped_row))
	_tower_node_hover_layout_model = {
		"rows": rows,
		"font_size": font_size,
		# GRT-021: this is the actual append count after all semantic rows have
		# competed for the shared three-row budget.
		"appended_hover_row_count": rows.size(),
		"source_hover_semantic_row_count": source_rows.size(),
		"hidden_by_budget": hidden_by_budget,
	}
	return _tower_node_hover_layout_model.duplicate(true)


static func tower_node_compact_hover_owns_description_lane(
	compact_card: bool,
	hover_detail_row_count: int
) -> bool:
	# GRT-021 whole-row yield: the compact training card has no reserved bottom
	# hover lane, so while any hover detail row is visible it owns the
	# description grid whole-row instead of overprinting the idle rows.
	return compact_card and hover_detail_row_count > 0


static func tower_node_compact_hover_consumes_badge_lane(
	compact_card: bool,
	hover_detail_row_count: int
) -> bool:
	# A full three-row hover detail spills into the compact footer lane, so a
	# fixed-exception badge yields as a whole for that frame rather than overprinting.
	return compact_card and hover_detail_row_count >= TOWER_NODE_HOVER_DETAIL_ROW_LIMIT


static func tower_node_hover_detail_alpha(
	compact_card: bool,
	hover_blend: float
) -> float:
	# 코덱스 리뷰(8/23): compact 카드는 설명 행이 통째로 양보하므로 상세가
	# 블렌드로 떠오르면 진입 120ms·이탈 90ms 동안 레인이 비어 보인다.
	# 콘텐츠 교체는 원자적으로 — 호버가 살아 있는 동안 상세는 완전 불투명,
	# 하강 페이드는 양보 없는 레거시 프로파일만 유지한다.
	if compact_card:
		return 1.0 if hover_blend > 0.0 else 0.0
	return clampf(hover_blend, 0.0, 1.0)


static func tower_node_hover_detail_row_baseline(
	rect: Rect2,
	compact_card: bool,
	compact_scale: float,
	detail_index: int
) -> float:
	# Compact cards route the hover detail through the scaled description grid;
	# only the tall legacy profile keeps the reserved bottom-anchored 58px lane.
	if compact_card:
		return (
			rect.position.y
			+ 64.0 * compact_scale
			+ float(detail_index) * 12.0 * compact_scale
		)
	return rect.end.y - 58.0 + float(detail_index) * 17.0


static func should_draw_tower_node_bonus_badge(
	text_layout: Dictionary,
	visual_state: Dictionary
) -> bool:
	return (
		bool(text_layout.get("compact_card", false))
		and (text_layout.get("bonus_badge_rows", []) as Array).size() == 1
		and float(visual_state.get("success_progress", -1.0)) < 0.0
		and float(visual_state.get("rejection_progress", -1.0)) < 0.0
	)


func draw_tower_shop_item_cell(
	canvas: CanvasItem,
	choice: Dictionary,
	rect: Rect2,
	selected: bool,
	hovered: bool,
	enabled: bool,
	icon_renderer: Object = null,
	active_item_hud_visuals: Object = null
) -> void:
	if canvas == null or not rect.has_area():
		return
	var rarity := str(choice.get("rarity", "common"))
	var premium := rarity in ["legendary", "mythic"] or bool(choice.get("is_unique", false))
	var fill := Color(0.12, 0.095, 0.075, 0.96)
	var border := Color(0.48, 0.38, 0.24, 0.94)
	if premium:
		fill = Color(0.18, 0.105, 0.055, 0.97)
		border = Color(0.88, 0.61, 0.21, 0.98)
	if hovered:
		fill = fill.lightened(0.18)
		border = Color(1.0, 0.82, 0.40, 1.0)
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, border, false, 2.0 if hovered or selected else 1.0)
	_draw_tower_node_card_icon(
		canvas,
		choice,
		rect.grow(-4.0),
		icon_renderer,
		active_item_hud_visuals
	)
	if not enabled:
		canvas.draw_rect(rect.grow(-1.0), Color(0.12, 0.10, 0.09, 0.48), true)
		canvas.draw_line(
			rect.position + Vector2(6.0, 6.0),
			rect.end - Vector2(6.0, 6.0),
			Color(0.72, 0.28, 0.23, 0.92),
			2.0
		)


func prewarm_tower_shop_cells(
	actions: Array,
	owned_items: Array,
	layout: Dictionary,
	active_item_hud_visuals: Object = null
) -> Dictionary:
	var player_rects: Array[Rect2] = []
	var stock_rects: Array[Rect2] = []
	var player_panel: Rect2 = layout.get("shop_player_panel_rect", Rect2())
	var stock_panel: Rect2 = layout.get("shop_stock_panel_rect", Rect2())
	var cell_size := float(layout.get("shop_cell_size", 0.0))
	var cell_gap := float(layout.get("shop_cell_gap", 0.0))
	var start_offset: Vector2 = layout.get("shop_cell_start_offset", Vector2.ZERO)
	var player_columns := int(layout.get("shop_player_columns", 0))
	var stock_columns := int(layout.get("shop_stock_columns", 0))
	var player_visible_count := mini(
		owned_items.size(),
		int(layout.get("shop_player_visible_count", 0))
	)
	for visible_index in range(player_visible_count):
		var choice_value: Variant = owned_items[visible_index]
		if not (choice_value is Dictionary):
			continue
		player_rects.append(TowerShopNodeModalState.get_shop_cell_rect(
			player_panel,
			visible_index,
			player_columns,
			cell_size,
			cell_gap,
			start_offset
		))
		_prewarm_tower_shop_choice(choice_value as Dictionary, active_item_hud_visuals)
	var stock_visible_index := 0
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		if str(action.get("id", "")) == TowerShopNodeModalState.ACTION_END_WORK:
			continue
		if stock_visible_index >= int(layout.get("shop_stock_visible_count", 0)):
			break
		stock_rects.append(TowerShopNodeModalState.get_shop_cell_rect(
			stock_panel,
			stock_visible_index,
			stock_columns,
			cell_size,
			cell_gap,
			start_offset
		))
		var payload_value: Variant = action.get("payload", {})
		if payload_value is Dictionary:
			var choice_value: Variant = (payload_value as Dictionary).get("choice", {})
			if choice_value is Dictionary:
				_prewarm_tower_shop_choice(
					choice_value as Dictionary,
					active_item_hud_visuals
				)
		stock_visible_index += 1
	return {
		"player_rects": player_rects,
		"stock_rects": stock_rects,
		"player_count": player_rects.size(),
		"stock_count": stock_rects.size(),
	}


func _prewarm_tower_shop_choice(
	choice: Dictionary,
	active_item_hud_visuals: Object
) -> void:
	var item_data_value: Variant = choice.get("item_data", {})
	if item_data_value is Dictionary and not (item_data_value as Dictionary).is_empty():
		_tower_active_item_icon_renderer.prewarm_item_icon(
			item_data_value as Dictionary,
			active_item_hud_visuals
		)


func draw_tower_node_card(
	canvas: CanvasItem,
	action: Dictionary,
	rect: Rect2,
	selected: bool,
	icon_renderer: Object,
	paper_variant: int = 0,
	active_item_hud_visuals: Object = null,
	visual_state: Dictionary = {}
) -> Dictionary:
	if canvas == null or not rect.has_area():
		return {}
	_capture_draw_msec()
	var text_layout := build_tower_node_card_text_layout(action, rect)
	var choice: Dictionary = text_layout.get("choice", {})
	if str(choice.get("presentation_mode", "")) == "hero":
		return _draw_tower_node_hero_card(
			canvas,
			action,
			rect,
			selected,
			icon_renderer,
			paper_variant,
			active_item_hud_visuals,
			visual_state,
			text_layout
		)
	var compact_card := bool(text_layout.get("compact_card", false))
	var compact_scale := float(text_layout.get("compact_scale", 1.0))
	var visual_plan := build_tower_node_card_visual_plan(visual_state)
	var hover_blend := float(visual_plan.get("hover_blend", 0.0))
	var pressed := bool(visual_state.get("pressed", false))
	var rejection_progress := float(visual_state.get("rejection_progress", -1.0))
	var success_progress := float(visual_state.get("success_progress", -1.0))
	var content_offset: Vector2 = visual_plan.get("content_offset", Vector2.ZERO)
	var rejection_shake := content_offset.x
	var enabled := bool(action.get("enabled", true))
	var rarity := str(choice.get("rarity", "common"))
	var premium := (
		bool(choice.get("is_unique", false))
		or rarity in ["legendary", "mythic"]
	)
	var paper_rect := RuntimePerkTraditionalChrome.draw_card_base(
		canvas,
		rect,
		false,
		premium,
		1.0,
		0.5,
		paper_variant,
		_traditional_ornament_atlas_texture,
		_traditional_card_paper_texture
	)
	if selected:
		canvas.draw_rect(rect.grow(-1.0), Color(1.0, 0.86, 0.47, 0.96), false, 3.0)
	if not visual_state.is_empty() and (hover_blend > 0.0 or pressed):
		var node_accent: Color = _get_color(visual_state.get("node_accent", Color(1.0, 0.72, 0.30)))
		var inner_rect := rect.grow(-float(visual_plan.get("border_inset", 4.0)))
		var pointer_strength := maxf(hover_blend, 0.58 if pressed else 0.0)
		canvas.draw_rect(
			Rect2(inner_rect.position + Vector2(2.0, 3.0), inner_rect.size),
			Color(0.06, 0.04, 0.02, 0.22 * pointer_strength),
			false,
			3.0
		)
		canvas.draw_rect(
			inner_rect,
			Color(node_accent, 0.94 * pointer_strength),
			false,
			1.0 + 1.4 * hover_blend
		)
		_tower_node_feedback_dynamic_layer_draw_count += 2

	var icon_color := _get_color(choice.get(
		"icon_color",
		Color(100.0 / 255.0, 150.0 / 255.0, 1.0)
	))
	var icon_center := rect.position + (
		Vector2(25.0, 25.0) * compact_scale if compact_card else Vector2(38.0, 39.0)
	) + content_offset
	var icon_radius := 15.0 * compact_scale if compact_card else 24.0
	canvas.draw_circle(icon_center, icon_radius + 4.0, Color(0.17, 0.12, 0.08, 0.96))
	canvas.draw_circle(icon_center, icon_radius, Color(0.07, 0.10, 0.12, 0.97))
	canvas.draw_arc(icon_center, icon_radius, 0.0, TAU, 28, Color(icon_color, 0.76), 1.6)
	_draw_tower_node_card_icon(
		canvas,
		choice,
		Rect2(
			icon_center
			- Vector2.ONE
			* (13.0 * compact_scale if compact_card else 20.0)
			* float(visual_plan.get("icon_scale", 1.0)),
			Vector2.ONE
			* (26.0 * compact_scale if compact_card else 40.0)
			* float(visual_plan.get("icon_scale", 1.0))
		),
		icon_renderer,
		active_item_hud_visuals
	)

	var nameplate := Rect2(
		Vector2(
			rect.position.x + (48.0 * compact_scale if compact_card else 70.0),
			rect.position.y + (8.0 * compact_scale if compact_card else 14.0)
		) + content_offset,
		Vector2(
			maxf(48.0, rect.size.x - (60.0 * compact_scale if compact_card else 83.0)),
			22.0 * compact_scale if compact_card else 29.0
		)
	)
	RuntimePerkTraditionalChrome.draw_nameplate(
		canvas,
		nameplate,
		selected,
		premium,
		1.0
	)
	var node_accent: Color = _get_color(visual_state.get("node_accent", Color(1.0, 0.72, 0.30)))
	if hover_blend > 0.0:
		canvas.draw_rect(nameplate.grow(-2.0), Color(node_accent, 0.88 * hover_blend), false, 2.0)
		_tower_node_feedback_dynamic_layer_draw_count += 1
	var name := str(choice.get("name", action.get("label", "")))
	_draw_text_centered_fitted(
		canvas,
		name,
		nameplate.get_center() + Vector2(0.0, 1.0),
		clampi(int(round(13.0 * compact_scale)), 11, 22) if compact_card else 15,
		Color(0.94, 0.87, 0.72).lerp(node_accent, 0.76 * hover_blend),
		nameplate.size.x - 12.0,
		clampi(int(round(9.0 * compact_scale)), 9, 16) if compact_card else 10
	)
	var rank_text := _level_text(choice)
	_draw_text_centered_fitted(
		canvas,
		rank_text,
		(
			Vector2(
				rect.position.x + 88.0 * compact_scale + content_offset.x,
				rect.position.y + 45.0 * compact_scale + content_offset.y
			)
			if compact_card
			else Vector2(nameplate.get_center().x, rect.position.y + 58.0 + content_offset.y)
		),
		clampi(int(round(10.0 * compact_scale)), 9, 18) if compact_card else 12,
		_level_color(choice, premium, 1.0),
		80.0 * compact_scale if compact_card else nameplate.size.x - 8.0,
		clampi(int(round(9.0 * compact_scale)), 9, 16) if compact_card else 9
	)
	if compact_card and hover_blend <= 0.0:
		_draw_text_centered_fitted(
			canvas,
			str(action.get("cost_text", "")),
			Vector2(
				rect.end.x - 43.0 * compact_scale + content_offset.x,
				rect.position.y + 45.0 * compact_scale + content_offset.y
			),
			clampi(int(round(10.0 * compact_scale)), 9, 18),
			Color(0.35, 0.22, 0.09) if enabled else Color(0.35, 0.30, 0.26),
			78.0 * compact_scale,
			clampi(int(round(9.0 * compact_scale)), 9, 16)
		)
	canvas.draw_line(
		Vector2(
			paper_rect.position.x + (10.0 * compact_scale if compact_card else 10.0),
			rect.position.y + (54.0 * compact_scale if compact_card else 76.0)
		) + content_offset,
		Vector2(
			paper_rect.end.x - (10.0 * compact_scale if compact_card else 10.0),
			rect.position.y + (54.0 * compact_scale if compact_card else 76.0)
		) + content_offset,
		Color(0.45, 0.34, 0.20, 0.48),
		compact_scale if compact_card else 1.0
	)

	var description_rows: Array = text_layout.get("description_rows", [])
	var description_font_size := int(text_layout.get("description_font_size", 12))
	var text_font_value: Variant = text_layout.get("text_font", null)
	var text_font: Font = text_font_value as Font if text_font_value is Font else _get_font()
	var description_row_step := 12.0 * compact_scale if compact_card else 16.0
	var detail_layout := {}
	var suppress_hover_detail := _tower_node_strict_receipt_owns_detail_area(
		action,
		success_progress,
		rejection_progress
	)
	if hover_blend > 0.0 and not suppress_hover_detail:
		detail_layout = build_tower_node_hover_detail_layout(action, rect)
	var detail_rows: Array = detail_layout.get("rows", [])
	var compact_hover_detail_active := tower_node_compact_hover_owns_description_lane(
		compact_card,
		detail_rows.size()
	)
	if not compact_hover_detail_active:
		for row_index in range(description_rows.size()):
			_draw_text_fitted(
				canvas,
				str(description_rows[row_index]),
				Vector2(
					rect.position.x + (11.0 * compact_scale if compact_card else 14.0),
						rect.position.y
						+ (64.0 * compact_scale if compact_card else 96.0)
						+ float(row_index) * description_row_step
						+ content_offset.y
				),
				description_font_size,
				Color(0.24, 0.19, 0.14, 0.96),
				rect.size.x - (22.0 * compact_scale if compact_card else 28.0),
				clampi(int(round(11.0 * compact_scale)), 11, 16) if compact_card else 10,
				text_font
			)
	var bonus_badge_rows: Array = text_layout.get("bonus_badge_rows", [])
	# The compact rail has one shared footer lane. A success/rejection receipt
	# temporarily owns that lane, so keep a steady fixed-exception badge intact at idle
	# but remove it as a whole while the authoritative receipt is visible
	# (GRT-021). Drawing both makes two complete Korean promises collide.
	var bonus_badge_drawn := (
		should_draw_tower_node_bonus_badge(text_layout, visual_state)
		and not tower_node_compact_hover_consumes_badge_lane(
			compact_card,
			detail_rows.size()
		)
	)
	if bonus_badge_drawn:
		# The old footer baseline sat on the lower brass edge at the live Vulkan
		# scale. An 18-unit bottom inset leaves the complete fourth row above the
		# frame while the 64/10 description grid retains all three budgeted rows.
		var badge_rect := Rect2(
			Vector2(
				rect.position.x + 10.0 * compact_scale,
				rect.end.y - 18.0 * compact_scale
			) + content_offset,
			Vector2(rect.size.x - 20.0 * compact_scale, 11.0 * compact_scale)
		)
		canvas.draw_rect(badge_rect, Color(0.54, 0.31, 0.08, 0.12), true)
		_draw_text_centered(
			canvas,
			str(bonus_badge_rows[0]),
			badge_rect.get_center(),
			int(text_layout.get("bonus_badge_font_size", 10)),
			Color(0.50, 0.22, 0.06, 0.96),
			text_font
		)

	var reason := str(action.get("unavailable_reason", "")).strip_edges()
	if detail_rows.size() > 0:
		var detail_font_size := int(detail_layout.get("font_size", 11))
		if compact_card:
			detail_font_size = mini(detail_font_size, description_font_size)
		for detail_index in range(detail_rows.size()):
			var detail_color := Color(0.30, 0.20, 0.10).lerp(node_accent, 0.35)
			detail_color.a = tower_node_hover_detail_alpha(compact_card, hover_blend)
			_draw_text_fitted(
				canvas,
				str(detail_rows[detail_index]),
				Vector2(
					rect.position.x
						+ (11.0 * compact_scale if compact_card else 12.0)
						+ content_offset.x,
					tower_node_hover_detail_row_baseline(
						rect,
						compact_card,
						compact_scale,
						detail_index
					) + content_offset.y
				),
				detail_font_size,
				detail_color,
				rect.size.x - (22.0 * compact_scale if compact_card else 24.0),
				clampi(int(round(9.0 * compact_scale)), 9, 16) if compact_card else 9,
				text_font if compact_card else null
			)
		_tower_node_feedback_dynamic_layer_draw_count += detail_rows.size()
	if not enabled and hover_blend <= 0.0:
		canvas.draw_rect(rect.grow(-5.0), Color(0.10, 0.09, 0.08, 0.32), true)
		_draw_text_centered_fitted(
			canvas,
			reason,
			Vector2(
				rect.get_center().x,
				rect.end.y - (31.0 * compact_scale if compact_card else 42.0)
			),
			clampi(int(round(11.0 * compact_scale)), 10, 19) if compact_card else 11,
			Color(0.49, 0.12, 0.10),
			rect.size.x - 22.0,
			clampi(int(round(9.0 * compact_scale)), 9, 16) if compact_card else 9
		)
	if hover_blend <= 0.0 and not compact_card:
		_draw_text_centered_fitted(
			canvas,
			str(action.get("cost_text", "")),
			Vector2(rect.get_center().x + content_offset.x, rect.end.y - 17.0 + content_offset.y),
			12,
			Color(0.35, 0.22, 0.09) if enabled else Color(0.35, 0.30, 0.26),
			rect.size.x - 22.0,
			9
		)
	var receipt_message := str(visual_state.get("receipt_message", "")).strip_edges()
	if success_progress >= 0.0:
		_draw_tower_node_success_receipt(
			canvas,
			rect,
			receipt_message,
			success_progress,
			node_accent
		)
	if rejection_progress >= 0.0 and not receipt_message.is_empty():
		canvas.draw_rect(rect.grow(-7.0), Color(0.62, 0.10, 0.08, 0.18 + 0.18 * (1.0 - rejection_progress)), false, 3.0)
		_draw_text_centered_fitted(
			canvas,
			receipt_message,
			Vector2(rect.get_center().x + rejection_shake, rect.end.y - 27.0),
			11,
			Color(0.63, 0.08, 0.06),
			rect.size.x - 22.0,
			9
		)
		_tower_node_feedback_dynamic_layer_draw_count += 2
	var other_dim_amount := clampf(float(visual_state.get("other_dim_amount", 0.0)), 0.0, 0.12)
	if other_dim_amount > 0.0:
		canvas.draw_rect(rect.grow(-2.0), Color(0.03, 0.025, 0.02, other_dim_amount), true)
		_tower_node_feedback_dynamic_layer_draw_count += 1
	text_layout["bonus_badge_drawn"] = bonus_badge_drawn
	text_layout["hover_detail_layout"] = detail_layout
	return text_layout


func _draw_tower_node_hero_card(
	canvas: CanvasItem,
	action: Dictionary,
	rect: Rect2,
	selected: bool,
	icon_renderer: Object,
	paper_variant: int,
	active_item_hud_visuals: Object,
	visual_state: Dictionary,
	text_layout: Dictionary
) -> Dictionary:
	var choice: Dictionary = text_layout.get("choice", {})
	var visual_plan := build_tower_node_card_visual_plan(visual_state)
	var hover_blend := float(visual_plan.get("hover_blend", 0.0))
	var pressed := bool(visual_state.get("pressed", false))
	var rejection_progress := float(visual_state.get("rejection_progress", -1.0))
	var success_progress := float(visual_state.get("success_progress", -1.0))
	var content_offset: Vector2 = visual_plan.get("content_offset", Vector2.ZERO)
	var enabled := bool(action.get("enabled", true))
	var node_accent: Color = _get_color(visual_state.get(
		"node_accent",
		Color(0.24, 0.55, 0.76)
	))
	var paper_rect := RuntimePerkTraditionalChrome.draw_card_base(
		canvas,
		rect,
		false,
		false,
		1.0,
		0.5,
		paper_variant,
		_traditional_ornament_atlas_texture,
		_traditional_card_paper_texture
	)
	if selected:
		canvas.draw_rect(rect.grow(-1.0), Color(1.0, 0.86, 0.47, 0.96), false, 3.0)
	if hover_blend > 0.0 or pressed:
		var pointer_strength := maxf(hover_blend, 0.58 if pressed else 0.0)
		var inner_rect := rect.grow(-float(visual_plan.get("border_inset", 4.0)))
		canvas.draw_rect(
			Rect2(inner_rect.position + Vector2(3.0, 4.0), inner_rect.size),
			Color(0.03, 0.06, 0.10, 0.24 * pointer_strength),
			false,
			4.0
		)
		canvas.draw_rect(
			inner_rect,
			Color(node_accent, 0.94 * pointer_strength),
			false,
			1.0 + 1.6 * hover_blend
		)
		_tower_node_feedback_dynamic_layer_draw_count += 2

	var icon_size := minf(rect.size.x * 0.31, rect.size.y * 0.29)
	var icon_center := Vector2(
		rect.get_center().x,
		rect.position.y + rect.size.y * 0.25
	) + content_offset
	var icon_scale := float(visual_plan.get("icon_scale", 1.0))
	var icon_rect := Rect2(
		icon_center - Vector2.ONE * icon_size * 0.5 * icon_scale,
		Vector2.ONE * icon_size * icon_scale
	)
	canvas.draw_circle(icon_center, icon_size * 0.58, Color(0.14, 0.11, 0.08, 0.96))
	canvas.draw_circle(icon_center, icon_size * 0.52, Color(0.06, 0.10, 0.14, 0.97))
	canvas.draw_arc(
		icon_center,
		icon_size * 0.52,
		0.0,
		TAU,
		36,
		Color(node_accent, 0.76),
		2.0
	)
	_draw_tower_node_card_icon(
		canvas,
		choice,
		icon_rect.grow(-icon_size * 0.10),
		icon_renderer,
		active_item_hud_visuals
	)

	var nameplate := Rect2(
		Vector2(rect.position.x + rect.size.x * 0.12, rect.position.y + rect.size.y * 0.43)
			+ content_offset,
		Vector2(rect.size.x * 0.76, rect.size.y * 0.105)
	)
	RuntimePerkTraditionalChrome.draw_nameplate(canvas, nameplate, selected, false, 1.0)
	if hover_blend > 0.0:
		canvas.draw_rect(nameplate.grow(-2.0), Color(node_accent, 0.88 * hover_blend), false, 2.0)
		_tower_node_feedback_dynamic_layer_draw_count += 1
	_draw_text_centered_fitted(
		canvas,
		str(choice.get("name", action.get("label", ""))),
		nameplate.get_center() + Vector2(0.0, 1.0),
		clampi(int(round(rect.size.x * 0.047)), 16, 26),
		Color(0.94, 0.87, 0.72).lerp(node_accent, 0.76 * hover_blend),
		nameplate.size.x - 18.0,
		13
	)
	_draw_text_centered_fitted(
		canvas,
		_level_text(choice),
		Vector2(rect.get_center().x + content_offset.x, rect.position.y + rect.size.y * 0.59 + content_offset.y),
		clampi(int(round(rect.size.x * 0.035)), 13, 20),
		Color(0.16, 0.31, 0.40) if enabled else Color(0.35, 0.30, 0.26),
		rect.size.x * 0.76,
		11
	)
	canvas.draw_line(
		Vector2(paper_rect.position.x + rect.size.x * 0.10, rect.position.y + rect.size.y * 0.63),
		Vector2(paper_rect.end.x - rect.size.x * 0.10, rect.position.y + rect.size.y * 0.63),
		Color(0.45, 0.34, 0.20, 0.48),
		1.0
	)
	var description_rows: Array = text_layout.get("description_rows", [])
	var description_font_size := clampi(int(text_layout.get("description_font_size", 13)) + 1, 12, 18)
	for row_index in range(description_rows.size()):
		_draw_text_centered_fitted(
			canvas,
			str(description_rows[row_index]),
			Vector2(
				rect.get_center().x + content_offset.x,
				rect.position.y + rect.size.y * 0.69 + float(row_index) * 20.0 + content_offset.y
			),
			description_font_size,
			Color(0.24, 0.19, 0.14, 0.96),
			rect.size.x * 0.82,
			10
		)

	var detail_layout := {}
	var suppress_hover_detail := _tower_node_strict_receipt_owns_detail_area(
		action,
		success_progress,
		rejection_progress
	)
	if hover_blend > 0.0 and not suppress_hover_detail:
		detail_layout = build_tower_node_hover_detail_layout(action, rect)
		var detail_rows: Array = detail_layout.get("rows", [])
		var detail_font_size := int(detail_layout.get("font_size", 11))
		for detail_index in range(detail_rows.size()):
			var detail_color := Color(0.20, 0.26, 0.30).lerp(node_accent, 0.38)
			detail_color.a = hover_blend
			_draw_text_centered_fitted(
				canvas,
				str(detail_rows[detail_index]),
				Vector2(
					rect.get_center().x + content_offset.x,
					rect.end.y - 74.0 + float(detail_index) * 18.0 + content_offset.y
				),
				detail_font_size,
				detail_color,
				rect.size.x - 32.0,
				9
			)
		_tower_node_feedback_dynamic_layer_draw_count += detail_rows.size()
	if not enabled and hover_blend <= 0.0:
		canvas.draw_rect(rect.grow(-7.0), Color(0.07, 0.08, 0.10, 0.30), true)
		_draw_text_centered_fitted(
			canvas,
			str(action.get("unavailable_reason", "")),
			Vector2(rect.get_center().x, rect.end.y - 42.0),
			13,
			Color(0.49, 0.12, 0.10),
			rect.size.x - 36.0,
			10
		)
	if hover_blend <= 0.0:
		_draw_text_centered_fitted(
			canvas,
			str(action.get("cost_text", "")),
			Vector2(rect.get_center().x + content_offset.x, rect.end.y - 18.0 + content_offset.y),
			13,
			Color(0.23, 0.30, 0.36) if enabled else Color(0.35, 0.30, 0.26),
			rect.size.x - 36.0,
			10
		)
	var receipt_message := str(visual_state.get("receipt_message", "")).strip_edges()
	if success_progress >= 0.0:
		_draw_tower_node_success_receipt(
			canvas,
			rect,
			receipt_message,
			success_progress,
			node_accent
		)
	if rejection_progress >= 0.0 and not receipt_message.is_empty():
		canvas.draw_rect(rect.grow(-9.0), Color(0.62, 0.10, 0.08, 0.22), false, 3.0)
		_draw_text_centered_fitted(
			canvas,
			receipt_message,
			Vector2(rect.get_center().x + content_offset.x, rect.end.y - 31.0),
			12,
			Color(0.63, 0.08, 0.06),
			rect.size.x - 36.0,
			9
		)
		_tower_node_feedback_dynamic_layer_draw_count += 2
	var other_dim_amount := clampf(float(visual_state.get("other_dim_amount", 0.0)), 0.0, 0.12)
	if other_dim_amount > 0.0:
		canvas.draw_rect(rect.grow(-2.0), Color(0.03, 0.025, 0.02, other_dim_amount), true)
		_tower_node_feedback_dynamic_layer_draw_count += 1
	text_layout["hover_detail_layout"] = detail_layout
	return text_layout


func _tower_node_strict_receipt_owns_detail_area(
	action: Dictionary,
	success_progress: float,
	rejection_progress: float
) -> bool:
	if success_progress < 0.0 and rejection_progress < 0.0:
		return false
	var payload_value: Variant = action.get("payload", {})
	if not (payload_value is Dictionary):
		return false
	var presentation_value: Variant = (payload_value as Dictionary).get(
		"presentation",
		{}
	)
	return (
		presentation_value is Dictionary
		and bool((presentation_value as Dictionary).get("strict_text_budget", false))
	)


func build_tower_node_card_visual_plan(visual_state: Dictionary) -> Dictionary:
	var hover_blend := clampf(float(visual_state.get("hover_blend", 0.0)), 0.0, 1.0)
	var pressed := bool(visual_state.get("pressed", false))
	var rejection_progress := float(visual_state.get("rejection_progress", -1.0))
	var rejection_shake := 0.0
	if rejection_progress >= 0.0:
		rejection_shake = (
			sin(rejection_progress * TAU * 3.0)
			* 6.0
			* (1.0 - clampf(rejection_progress, 0.0, 1.0))
		)
	return {
		"hover_blend": hover_blend,
		"content_offset": Vector2(
			rejection_shake,
			-TOWER_NODE_HOVER_LIFT * hover_blend + (2.0 if pressed else 0.0)
		),
		"border_inset": 6.0 if pressed else 4.0,
		"icon_scale": lerpf(1.0, TOWER_NODE_HOVER_ICON_SCALE, hover_blend),
	}


func reset_tower_node_feedback_debug_counters() -> void:
	_tower_node_feedback_dynamic_layer_draw_count = 0
	_tower_node_hover_layout_signature = 0
	_tower_node_hover_layout_model.clear()
	_tower_node_hover_layout_build_count = 0


func get_tower_node_feedback_debug_counters() -> Dictionary:
	return {
		"hover_layout_build_count": _tower_node_hover_layout_build_count,
		"dynamic_layer_draw_count": _tower_node_feedback_dynamic_layer_draw_count,
		"training_preview_build_count": int(_training_stat_preview.get("build_count")),
	}


func _draw_tower_node_success_receipt(
	canvas: CanvasItem,
	rect: Rect2,
	message: String,
	progress: float,
	accent: Color
) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	var pulse := sin(safe_progress * PI)
	var alpha := clampf(1.0 - maxf(0.0, safe_progress - 0.74) / 0.26, 0.0, 1.0)
	var center := Vector2(rect.get_center().x, rect.end.y - 47.0)
	canvas.draw_circle(center, 31.0 + 7.0 * pulse, Color(accent, (0.16 + 0.20 * pulse) * alpha))
	canvas.draw_arc(center, 25.0, 0.0, TAU, 28, Color(accent, 0.92 * alpha), 3.0)
	canvas.draw_line(center + Vector2(-10.0, 0.0), center + Vector2(-2.0, 9.0), Color(1.0, 0.94, 0.70, alpha), 4.0, true)
	canvas.draw_line(center + Vector2(-2.0, 9.0), center + Vector2(13.0, -10.0), Color(1.0, 0.94, 0.70, alpha), 4.0, true)
	if not message.is_empty():
		_draw_text_centered_fitted(
			canvas,
			message,
			Vector2(rect.get_center().x, rect.end.y - 17.0),
			11,
			Color(accent, alpha),
			rect.size.x - 18.0,
			9
		)
	_tower_node_feedback_dynamic_layer_draw_count += 5


func _draw_tower_node_card_icon(
	canvas: CanvasItem,
	choice: Dictionary,
	rect: Rect2,
	icon_renderer: Object,
	active_item_hud_visuals: Object
) -> void:
	var content_kind := str(choice.get("card_content_kind", ""))
	var item_data_value: Variant = choice.get("item_data", {})
	if content_kind == "guardian_portrait":
		if (
			icon_renderer != null
			and icon_renderer.has_method("draw_guardian_portrait")
			and bool(icon_renderer.call(
				"draw_guardian_portrait",
				canvas,
				str(choice.get("guardian_pet_id", "")),
				rect,
				1.0,
				true
			))
		):
			return
		_draw_perk_symbol(
			canvas,
			rect,
			_get_color(choice.get("icon_color", Color(0.37, 0.72, 0.66))),
			"guardian",
			str(choice.get("guardian_pet_id", "")),
			1.0
		)
		return
	if (
		content_kind == "active_item"
		and item_data_value is Dictionary
		and not (item_data_value as Dictionary).is_empty()
	):
		_tower_active_item_icon_renderer.draw_icon(
			canvas,
			rect,
			item_data_value as Dictionary,
			1.0,
			active_item_hud_visuals
		)
		return
	if content_kind in ["capsule", "chance_gem"]:
		_draw_tower_supply_symbol(canvas, rect, content_kind, choice)
		return
	_draw_icon(canvas, icon_renderer, choice, rect, 1.0)


func _draw_tower_supply_symbol(
	canvas: CanvasItem,
	rect: Rect2,
	content_kind: String,
	choice: Dictionary
) -> void:
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.34
	var color := _get_color(choice.get("icon_color", Color(0.58, 0.76, 0.92)))
	if content_kind == "chance_gem":
		var gem_points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.82, -radius * 0.18),
			center + Vector2(radius * 0.48, radius),
			center + Vector2(-radius * 0.48, radius),
			center + Vector2(-radius * 0.82, -radius * 0.18),
		])
		canvas.draw_colored_polygon(gem_points, Color(color, 0.90))
		canvas.draw_polyline(gem_points, Color(0.90, 0.96, 1.0), 1.5, true)
		canvas.draw_line(
			center + Vector2(-radius * 0.52, -radius * 0.18),
			center + Vector2(radius * 0.52, -radius * 0.18),
			Color(0.90, 0.96, 1.0, 0.82),
			1.2
		)
		return
	var capsule_rect := Rect2(
		center - Vector2(radius * 0.54, radius),
		Vector2(radius * 1.08, radius * 2.0)
	)
	var capsule_top := Vector2(center.x, capsule_rect.position.y + capsule_rect.size.x * 0.5)
	var capsule_bottom := Vector2(center.x, capsule_rect.end.y - capsule_rect.size.x * 0.5)
	canvas.draw_line(capsule_top, capsule_bottom, Color(0.94, 0.85, 0.62), capsule_rect.size.x + 3.0, true)
	canvas.draw_line(capsule_top, capsule_bottom, Color(color, 0.82), capsule_rect.size.x, true)
	canvas.draw_line(
		Vector2(capsule_rect.position.x, center.y),
		Vector2(capsule_rect.end.x, center.y),
		Color(0.19, 0.12, 0.08, 0.76),
		1.4
	)


func _tower_node_card_choice(action: Dictionary) -> Dictionary:
	var payload_value: Variant = action.get("payload", {})
	if payload_value is Dictionary:
		var choice_value: Variant = (payload_value as Dictionary).get("choice", {})
		if choice_value is Dictionary and not (choice_value as Dictionary).is_empty():
			return (choice_value as Dictionary).duplicate(true)
	return {
		"id": str(action.get("id", "")),
		"name": str(action.get("label", "")),
		"description": "",
		"level_text": "",
	}


func draw_tower_reward_pick(
	canvas: CanvasItem,
	view_model: Dictionary,
	runtime_state: Object,
	catalog: Object,
	icon_renderer: Object,
	view_size: Vector2,
	snapshot: Dictionary,
	mouse_pos: Vector2
) -> void:
	if canvas == null:
		return
	_capture_draw_msec()
	_prepare_text_caches()
	var animation_time := float(view_model.get("animation_time", 0.0))
	var alpha := clampf(animation_time / 0.18, 0.0, 1.0)
	var layout: Dictionary = _get_dict(view_model.get("layout", {}))
	var choices: Array = _get_array(view_model.get("choices", []))
	var rects: Array = _get_array(view_model.get("card_rects", []))
	var reward_hover_preview := _resolve_tower_reward_hover_preview(
		choices,
		rects,
		mouse_pos,
		snapshot
	)
	var absorption_by_slot: Dictionary = _tower_reward_absorption_by_slot(view_model)
	var selected_index := int(view_model.get("selected_index", 0))
	RuntimePerkTraditionalChrome.draw_backdrop(
		canvas,
		view_size,
		alpha,
		_traditional_ornament_atlas_texture
	)
	_draw_particles(canvas, snapshot)
	var font := _get_font()
	var title_pos := _get_vector2(layout.get("title_pos", Vector2(view_size.x * 0.5, 72.0)))
	var layout_scale := float(layout.get("layout_scale", 1.0))
	var reward_title_scale := minf(layout_scale, 1.0)
	title_pos = _fit_tower_reward_title_position(
		title_pos,
		str(view_model.get("title", "")),
		reward_title_scale,
		rects,
		selected_index
	)
	_draw_title(
		canvas,
		title_pos,
		animation_time,
		reward_title_scale,
		str(view_model.get("title", ""))
	)
	var balance_rows := build_tower_reward_balance_rows(
		view_size,
		title_pos,
		reward_title_scale,
		str(view_model.get("balance_text", ""))
	)
	for balance_row in balance_rows:
		_draw_tower_reward_balance_row(canvas, balance_row, alpha)
	var acquisition_rows := build_tower_reward_acquisition_rows(
		view_size,
		balance_rows,
		str(view_model.get("acquisition_text", ""))
	)
	for acquisition_row in acquisition_rows:
		_draw_tower_reward_acquisition_row(canvas, acquisition_row, alpha)
	_sync_choice_visual_selection(choices, selected_index)
	for index in range(mini(choices.size(), rects.size())):
		if not (choices[index] is Dictionary) or not (rects[index] is Rect2):
			continue
		var choice := choices[index] as Dictionary
		var rect := rects[index] as Rect2
		var selected := index == selected_index
		var spent := bool(choice.get("reward_pick_spent", false))
		var absorption: Dictionary = _get_dict(absorption_by_slot.get(index, {}))
		if spent:
			if not absorption.is_empty():
				var animated_rect: Rect2 = _build_tower_reward_absorbing_rect(rect, absorption)
				_draw_tower_reward_absorption(canvas, rect, absorption)
				_draw_card(
					canvas,
					choice,
					animated_rect,
					false,
					1.0,
					icon_renderer,
					_choice_visual_blend(index),
					index
				)
			continue
		_draw_card(
			canvas,
			choice,
			rect,
			selected,
			animation_time,
			icon_renderer,
			_choice_visual_blend(index),
			index
		)
		var strip := Rect2(rect.position + Vector2(0.0, rect.size.y + 3.0), Vector2(rect.size.x, 24.0))
		var enabled := bool(choice.get("reward_pick_enabled", true))
		canvas.draw_rect(strip, Color(0.07, 0.055, 0.04, 0.92 * alpha), true)
		canvas.draw_rect(strip, Color(0.74, 0.55, 0.25, 0.85 * alpha), false, 1.0)
		canvas.draw_string(
			font,
			strip.position + Vector2(0.0, 17.0),
			str(view_model.get("spent_text", "")) if spent else str(choice.get("reward_pick_price_text", "")),
			HORIZONTAL_ALIGNMENT_CENTER,
			strip.size.x,
			13,
			Color(0.62, 0.62, 0.62, alpha) if spent or not enabled else Color(0.96, 0.84, 0.52, alpha)
		)
		if not enabled:
			canvas.draw_rect(rect, Color(0.02, 0.02, 0.025, 0.28 * alpha), true)
	_draw_per_card_descriptions(
		canvas,
		runtime_state,
		choices,
		selected_index,
		layout,
		animation_time
	)
	_draw_status_panel(
		canvas,
		runtime_state,
		snapshot,
		catalog,
		_get_rect2(layout.get("panel_rect", Rect2())),
		icon_renderer,
		view_size,
		mouse_pos,
		int(view_model.get("reward_session_id", -1)),
		reward_hover_preview
	)
	_draw_stats_band(
		canvas,
		runtime_state,
		snapshot,
		_get_rect2(layout.get("stats_rect", Rect2())),
		view_size,
		icon_renderer,
		mouse_pos,
		choices,
		rects
	)
	var continue_rect := _get_rect2(view_model.get("continue_rect", Rect2()))
	canvas.draw_rect(continue_rect, Color(0.34, 0.12, 0.08, 0.96 * alpha), true)
	canvas.draw_rect(continue_rect, Color(0.91, 0.70, 0.31, alpha), false, 2.0)
	canvas.draw_string(
		font,
		continue_rect.position + Vector2(0.0, 28.0),
		str(view_model.get("continue_text", "")),
		HORIZONTAL_ALIGNMENT_CENTER,
		continue_rect.size.x,
		18,
		Color(0.98, 0.92, 0.76, alpha)
	)
	canvas.draw_string(
		font,
		Vector2(36.0, continue_rect.get_center().y + 5.0),
		str(view_model.get("status_text", "")),
		HORIZONTAL_ALIGNMENT_RIGHT,
		maxf(0.0, continue_rect.position.x - 58.0),
		14,
		Color(0.82, 0.80, 0.72, alpha)
	)
	_draw_hovered_tower_chosik_tooltip(canvas, view_model, view_size, mouse_pos)


func _draw_hovered_tower_chosik_tooltip(
	canvas: CanvasItem,
	view_model: Dictionary,
	view_size: Vector2,
	mouse_pos: Vector2
) -> void:
	var tooltip_context := _get_dict(view_model.get("chosik_tooltip_context", {}))
	var tooltip_renderer: Object = tooltip_context.get("renderer", null)
	var registry: Object = tooltip_context.get("registry", null)
	if (
		canvas == null
		or tooltip_renderer == null
		or registry == null
		or not tooltip_renderer.has_method("draw_card_tooltip")
	):
		return
	var choices := _get_array(view_model.get("choices", []))
	var rects := _get_array(view_model.get("card_rects", []))
	var avoid_rects: Array[Rect2] = []
	for value in rects:
		if value is Rect2:
			avoid_rects.append(value as Rect2)
	for index in range(mini(choices.size(), rects.size())):
		if not (choices[index] is Dictionary) or not (rects[index] is Rect2):
			continue
		var choice := choices[index] as Dictionary
		var card_rect := rects[index] as Rect2
		if not card_rect.has_point(mouse_pos):
			continue
		if (
			bool(choice.get("reward_pick_spent", false))
			or bool(choice.get("reward_pick_absorbing", false))
			or bool(choice.get("start_card_absorbing", false))
		):
			return
		tooltip_renderer.call(
			"draw_card_tooltip",
			canvas,
			registry,
			view_size,
			_get_dict(tooltip_context.get("scene_context", {})),
			choice,
			card_rect,
			avoid_rects,
			mouse_pos
		)
		return


func build_tower_reward_balance_rows(
	view_size: Vector2,
	title_pos: Vector2,
	title_scale: float,
	text: String
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var font := _get_font()
	if font == null or text.is_empty() or view_size.x <= 0.0 or view_size.y <= 0.0:
		return rows
	var safe_scale := maxf(0.1, title_scale)
	var font_size := maxi(
		TOWER_REWARD_BALANCE_MIN_FONT_SIZE,
		int(round(TOWER_REWARD_BALANCE_FONT_SIZE * safe_scale))
	)
	var icon_size := float(font_size) * TOWER_REWARD_BALANCE_ICON_FONT_RATIO
	var text_gap := icon_size * TOWER_REWARD_BALANCE_TEXT_GAP_ICON_RATIO
	var row_height := float(font_size) * TOWER_REWARD_BALANCE_ROW_HEIGHT_FONT_RATIO
	var text_size := font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	)
	var row_width := icon_size + text_gap + text_size.x
	var row_rect := Rect2(
		Vector2(
			title_pos.x + TOWER_REWARD_BALANCE_TITLE_OFFSET * safe_scale,
			title_pos.y - row_height * 0.5
		),
		Vector2(row_width, row_height)
	)
	var right_margin := TOWER_REWARD_BALANCE_RIGHT_MARGIN * safe_scale
	if (
		row_rect.position.x < 0.0
		or row_rect.position.y < 0.0
		or row_rect.end.x > view_size.x - right_margin
		or row_rect.end.y > view_size.y
	):
		return rows
	var icon_center := Vector2(
		row_rect.position.x + icon_size * 0.5,
		row_rect.get_center().y
	)
	var text_left := icon_center.x + icon_size * 0.5 + text_gap
	rows.append({
		"rect": row_rect,
		"icon_center": icon_center,
		"icon_size": icon_size,
		"text": text,
		"text_rect": Rect2(
			Vector2(text_left, row_rect.position.y),
			Vector2(maxf(0.0, row_rect.end.x - text_left), row_rect.size.y)
		),
		"font_size": font_size,
	})
	return rows


func _draw_tower_reward_balance_row(
	canvas: CanvasItem,
	row: Dictionary,
	alpha: float
) -> void:
	var rect: Rect2 = row.get("rect", Rect2())
	var icon_center: Vector2 = row.get("icon_center", rect.get_center())
	var icon_size := float(row.get("icon_size", 0.0))
	CommonStarpointVisualHost.draw_muhon_fallback(
		canvas,
		icon_center,
		icon_size * 0.34,
		alpha,
		0.72,
		false,
		0.0
	)
	var text_rect: Rect2 = row.get("text_rect", rect)
	var font_size := int(row.get("font_size", TOWER_REWARD_BALANCE_MIN_FONT_SIZE))
	var font := _get_font()
	if font == null:
		return
	var baseline := Vector2(
		text_rect.position.x,
		text_rect.position.y + (text_rect.size.y - float(font_size)) * 0.5 + font.get_ascent(font_size)
	)
	var outline_size := maxi(
		1,
		int(round(float(font_size) * TOWER_REWARD_BALANCE_OUTLINE_FONT_RATIO))
	)
	canvas.draw_string_outline(
		font,
		baseline,
		str(row.get("text", "")),
		HORIZONTAL_ALIGNMENT_LEFT,
		text_rect.size.x,
		font_size,
		outline_size,
		Color(0.02, 0.015, 0.01, alpha * 0.92)
	)
	canvas.draw_string(
		font,
		baseline,
		str(row.get("text", "")),
		HORIZONTAL_ALIGNMENT_LEFT,
		text_rect.size.x,
		font_size,
		Color(0.96, 0.82, 0.45, alpha)
	)


func build_tower_reward_acquisition_rows(
	view_size: Vector2,
	balance_rows: Array[Dictionary],
	text: String
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var font := _get_font()
	if font == null or text.is_empty() or balance_rows.size() != 1:
		return rows
	var balance_row: Dictionary = balance_rows[0]
	var balance_rect: Rect2 = balance_row.get("rect", Rect2())
	var balance_text_rect: Rect2 = balance_row.get("text_rect", balance_rect)
	var balance_font_size := int(balance_row.get(
		"font_size",
		TOWER_REWARD_BALANCE_MIN_FONT_SIZE
	))
	var font_size := maxi(
		TOWER_REWARD_ACQUISITION_MIN_FONT_SIZE,
		int(round(float(balance_font_size) * TOWER_REWARD_ACQUISITION_FONT_RATIO))
	)
	var row_height := float(font_size) * TOWER_REWARD_ACQUISITION_ROW_HEIGHT_FONT_RATIO
	var text_size := font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	)
	var row_rect := Rect2(
		Vector2(
			balance_text_rect.position.x,
			balance_rect.end.y + TOWER_REWARD_ACQUISITION_TOP_GAP
		),
		Vector2(text_size.x, row_height)
	)
	if (
		row_rect.position.x < 0.0
		or row_rect.position.y < 0.0
		or row_rect.end.x > view_size.x - TOWER_REWARD_BALANCE_RIGHT_MARGIN
		or row_rect.end.y > view_size.y
	):
		return rows
	rows.append({
		"rect": row_rect,
		"text": text,
		"font_size": font_size,
	})
	return rows


func _draw_tower_reward_acquisition_row(
	canvas: CanvasItem,
	row: Dictionary,
	alpha: float
) -> void:
	var font := _get_font()
	if font == null:
		return
	var rect: Rect2 = row.get("rect", Rect2())
	var font_size := int(row.get("font_size", TOWER_REWARD_ACQUISITION_MIN_FONT_SIZE))
	var baseline := Vector2(
		rect.position.x,
		rect.position.y + (rect.size.y - float(font_size)) * 0.5 + font.get_ascent(font_size)
	)
	var text := str(row.get("text", ""))
	canvas.draw_string_outline(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x,
		font_size,
		1,
		Color(0.02, 0.015, 0.01, alpha * 0.88)
	)
	canvas.draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x,
		font_size,
		Color(0.91, 0.76, 0.44, alpha)
	)


func _tower_reward_absorption_by_slot(view_model: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for value in _get_array(view_model.get("purchase_absorption_effects", [])):
		var effect: Dictionary = _get_dict(value)
		var slot_index: int = int(effect.get("slot_index", -1))
		if slot_index >= 0:
			result[slot_index] = effect
	return result


func _fit_tower_reward_title_position(
	title_pos: Vector2,
	title_source: String,
	title_scale: float,
	card_rects: Array,
	selected_index: int
) -> Vector2:
	var font := _get_font()
	if font == null or card_rects.is_empty():
		return title_pos
	var title_font_size := clampi(
		int(round(float(TITLE_FONT_SIZE) * title_scale)),
		34,
		58
	)
	var text_size := _get_title_text_size(font, title_font_size, title_source)
	var plaque_height := maxf(72.0, text_size.y + 34.0 * title_scale)
	var first_drawn_y := INF
	for index in range(card_rects.size()):
		if not (card_rects[index] is Rect2):
			continue
		var rect := card_rects[index] as Rect2
		var drawn_y := rect.position.y
		if index == selected_index:
			drawn_y -= CARD_SELECTION_LIFT + rect.size.y * CARD_SELECTION_SCALE * 0.5
		first_drawn_y = minf(first_drawn_y, drawn_y)
	if not is_finite(first_drawn_y):
		return title_pos
	return Vector2(title_pos.x, minf(title_pos.y, first_drawn_y - plaque_height * 0.5))


func build_tower_acquisition_absorbing_rect(
	source_rect: Rect2,
	effect: Dictionary
) -> Rect2:
	return _build_tower_reward_absorbing_rect(source_rect, effect)


func draw_tower_acquisition_absorption(
	canvas: CanvasItem,
	source_rect: Rect2,
	effect: Dictionary
) -> void:
	_draw_tower_reward_absorption(canvas, source_rect, effect)


func _build_tower_reward_absorbing_rect(source_rect: Rect2, effect: Dictionary) -> Rect2:
	var progress: float = clampf(float(effect.get("progress", 0.0)), 0.0, 1.0)
	var center: Vector2 = _tower_reward_absorption_position(source_rect, effect, progress)
	var scale_factor: float
	if progress < TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO:
		scale_factor = lerpf(1.0, 1.055, _ease_out_cubic(progress / TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO))
	else:
		var flight_t: float = (progress - TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO) / (1.0 - TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO)
		scale_factor = lerpf(1.055, 0.12, _ease_in_out_cubic(flight_t))
	var size: Vector2 = source_rect.size * maxf(0.08, scale_factor)
	return Rect2(center - size * 0.5, size)


func _tower_reward_absorption_position(source_rect: Rect2, effect: Dictionary, progress: float) -> Vector2:
	var source: Vector2 = source_rect.get_center()
	var lifted: Vector2 = source + Vector2(0.0, -TEMP_TOWER_REWARD_ABSORB_LIFT_PX)
	if progress < TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO:
		return source.lerp(lifted, _ease_out_cubic(progress / TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO))
	var flight_t: float = clampf(
		(progress - TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO) / (1.0 - TEMP_TOWER_REWARD_ABSORB_LIFT_RATIO),
		0.0,
		1.0
	)
	var eased: float = _ease_in_out_cubic(flight_t)
	var target: Vector2 = _get_vector2(effect.get("target_pos", Vector2(380.0, 690.0)))
	var side: float = -1.0 if source.x > target.x else 1.0
	var control: Vector2 = (lifted + target) * 0.5 + Vector2(side * 52.0, -66.0)
	var inv: float = 1.0 - eased
	return lifted * inv * inv + control * 2.0 * inv * eased + target * eased * eased


func _draw_tower_reward_absorption(canvas: CanvasItem, source_rect: Rect2, effect: Dictionary) -> void:
	var progress: float = clampf(float(effect.get("progress", 0.0)), 0.0, 1.0)
	var head_pos: Vector2 = _tower_reward_absorption_position(source_rect, effect, progress)
	for trail_index in range(3, 0, -1):
		var trail_progress: float = maxf(0.0, progress - float(trail_index) * 0.045)
		var trail_pos: Vector2 = _tower_reward_absorption_position(source_rect, effect, trail_progress)
		var trail_alpha: float = (1.0 - float(trail_index) * 0.20) * (1.0 - progress * 0.58)
		CommonStarpointVisualHost.draw_muhon_fallback(
			canvas,
			trail_pos,
			maxf(3.0, 8.0 - float(trail_index)),
			trail_alpha,
			0.72,
			false,
			progress * 7.0 - float(trail_index) * 0.7
		)
	CommonStarpointVisualHost.draw_muhon_fallback(
		canvas,
		head_pos,
		lerpf(11.0, 5.0, progress),
		clampf(1.0 - progress * 0.42, 0.0, 1.0),
		1.0,
		false,
		progress * 8.0
	)
	if progress > 0.80:
		var burst_t: float = (progress - 0.80) / 0.20
		var target: Vector2 = _get_vector2(effect.get("target_pos", Vector2(380.0, 690.0)))
		canvas.draw_arc(
			target,
			lerpf(8.0, 42.0, _ease_out_cubic(burst_t)),
			0.0,
			TAU,
			STARPOINT_ABSORPTION_ARRIVAL_ARC_SEGMENTS,
			Color(STARPOINT_ABSORPTION_BURST_COLOR.r, STARPOINT_ABSORPTION_BURST_COLOR.g, STARPOINT_ABSORPTION_BURST_COLOR.b, (1.0 - burst_t) * 0.82),
			maxf(1.0, 3.2 * (1.0 - burst_t))
		)


func _runtime_state_has_visible_effects(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	if runtime_state.has_method("is_choice_active") and bool(runtime_state.is_choice_active()):
		return true
	if runtime_state.has_method("is_choice_flight_active") and bool(runtime_state.is_choice_flight_active()):
		return true
	if runtime_state.has_method("is_starpoint_absorption_active") and bool(runtime_state.is_starpoint_absorption_active()):
		return true
	if runtime_state.has_method("has_feedback") and bool(runtime_state.has_feedback()):
		return true
	if runtime_state.has_method("get_snapshot"):
		var snapshot: Dictionary = _get_dict(runtime_state.get_snapshot())
		if float(snapshot.get("feedback_timer", 0.0)) > 0.0 and str(snapshot.get("feedback_text", "")) != "":
			return true
		var flight_effect: Dictionary = _get_dict(snapshot.get("choice_flight_effect", {}))
		if bool(flight_effect.get("active", false)):
			return true
		var absorption_effect: Dictionary = _get_dict(snapshot.get("starpoint_absorption_effect", {}))
		if bool(absorption_effect.get("active", false)):
			return true
	return false


func _draw_title(
	canvas: CanvasItem,
	center: Vector2,
	animation_time: float,
	layout_scale: float = 1.0,
	title_source: String = TITLE_TEXT
) -> void:
	var font: Font = _get_font()
	if font == null:
		return
	var alpha: float = clamp(animation_time / 0.22, 0.0, 1.0)
	if alpha <= 0.001:
		return
	var title_font_size: int = clampi(int(round(float(TITLE_FONT_SIZE) * layout_scale)), 34, 58)
	var title_line: TextLine = _get_title_text_line(font, title_font_size, title_source)
	if title_line == null:
		return
	var text_size: Vector2 = _get_title_text_size(font, title_font_size, title_source)
	var plaque_size := Vector2(max(300.0, text_size.x + 128.0 * layout_scale), max(72.0, text_size.y + 34.0 * layout_scale))
	var plaque_rect := Rect2(center - plaque_size * 0.5, plaque_size)
	RuntimePerkTraditionalChrome.draw_title_plaque(canvas, plaque_rect, alpha)
	var pos := center - Vector2(text_size.x * 0.5, text_size.y * 0.28)
	var canvas_rid: RID = canvas.get_canvas_item()
	for glow in range(TITLE_SHADOW_DRAW_COUNT, 0, -1):
		title_line.draw(
			canvas_rid,
			pos + Vector2(float(glow), float(glow)) * 0.75,
			Color(1.0, 190.0 / 255.0, 70.0 / 255.0, alpha * 0.24 * float(glow))
		)
	title_line.draw(canvas_rid, pos, Color(230.0 / 255.0, 190.0 / 255.0, 98.0 / 255.0, alpha))


func _draw_training_signage(canvas: CanvasItem, view_size: Vector2, alpha: float) -> void:
	if alpha <= 0.001 or view_size.x < 620.0:
		return
	var plaque_size := Vector2(31.0, min(126.0, view_size.y * 0.19))
	var y: float = max(82.0, view_size.y * 0.20)
	_draw_vertical_plaque(canvas, Rect2(Vector2(18.0, y), plaque_size), "수련", alpha)
	_draw_vertical_plaque(canvas, Rect2(Vector2(view_size.x - plaque_size.x - 18.0, y), plaque_size), "환격전", alpha)


func _draw_vertical_plaque(canvas: CanvasItem, rect: Rect2, text: String, alpha: float) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), Color(0.0, 0.0, 0.0, 0.28 * alpha))
	canvas.draw_rect(rect, Color(20.0 / 255.0, 30.0 / 255.0, 37.0 / 255.0, 0.94 * alpha))
	canvas.draw_rect(rect, Color(151.0 / 255.0, 112.0 / 255.0, 52.0 / 255.0, 0.80 * alpha), false, 1.5)
	var chars: Array[String] = []
	for character: String in LanguageSettings.translate_text(text):
		chars.append(character)
	if chars.is_empty():
		return
	var step: float = min(24.0, (rect.size.y - 16.0) / float(chars.size()))
	var start_y: float = rect.get_center().y - step * float(chars.size() - 1) * 0.5
	for index: int in range(chars.size()):
		_draw_text_centered(
			canvas,
			chars[index],
			Vector2(rect.get_center().x, start_y + float(index) * step),
			14,
			Color(214.0 / 255.0, 181.0 / 255.0, 111.0 / 255.0, alpha)
		)


func _get_title_text_size(
	font: Font,
	font_size: int = TITLE_FONT_SIZE,
	title_source: String = TITLE_TEXT
) -> Vector2:
	if (
		_title_text_size == Vector2.ZERO
		or _title_text_line_font_size != font_size
		or _title_text_line_source != title_source
	):
		var title_line: TextLine = _get_title_text_line(font, font_size, title_source)
		if title_line != null:
			_title_text_size = title_line.get_size()
		else:
			_title_text_size = font.get_string_size(
				LanguageSettings.translate_text(title_source),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size
			)
	return _title_text_size


func _get_title_text_line(
	font: Font,
	font_size: int = TITLE_FONT_SIZE,
	title_source: String = TITLE_TEXT
) -> TextLine:
	if font == null:
		return null
	var font_id: int = font.get_instance_id()
	var language := LanguageSettings.get_language()
	if (
		_title_text_line != null
		and _title_text_line_font_id == font_id
		and _title_text_line_font_size == font_size
		and _title_text_line_language == language
		and _title_text_line_source == title_source
	):
		return _title_text_line
	var title_line := TextLine.new()
	if not title_line.add_string(LanguageSettings.translate_text(title_source), font, font_size):
		return null
	_title_text_line = title_line
	_title_text_line_font_id = font_id
	_title_text_line_font_size = font_size
	_title_text_line_language = language
	_title_text_line_source = title_source
	_title_text_size = title_line.get_size()
	return _title_text_line


func _draw_cards(canvas: CanvasItem, runtime_state: Object, choices: Array, selected_index: int, view_size: Vector2, animation_time: float, icon_renderer: Object) -> void:
	var rects: Array = runtime_state.get_card_rects(view_size)
	_sync_choice_visual_selection(choices, selected_index)
	for index in range(min(choices.size(), rects.size())):
		var choice: Dictionary = _get_dict(choices[index])
		var rect: Rect2 = rects[index]
		var selected: bool = index == selected_index
		_draw_card(canvas, choice, rect, selected, animation_time, icon_renderer, _choice_visual_blend(index), index)


func _sync_choice_visual_selection(choices: Array, selected_index: int) -> void:
	var signature: int = hash(choices)
	if signature != _choice_visual_signature or _choice_visual_index < 0:
		_choice_visual_signature = signature
		_choice_visual_index = selected_index
		_choice_visual_previous_index = -1
		_choice_visual_transition_started_msec = _get_draw_msec() - int(CARD_SELECTION_TRANSITION_MSEC)
		return
	if selected_index == _choice_visual_index:
		return
	_choice_visual_previous_index = _choice_visual_index
	_choice_visual_index = selected_index
	_choice_visual_transition_started_msec = _get_draw_msec()


func _choice_visual_blend(index: int) -> float:
	var elapsed: float = float(_get_draw_msec() - _choice_visual_transition_started_msec)
	var progress: float = clamp(elapsed / CARD_SELECTION_TRANSITION_MSEC, 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	if index == _choice_visual_index:
		return eased
	if index == _choice_visual_previous_index:
		return 1.0 - eased
	return 0.0


# 메달리온(원형 아이콘 판)의 최종 지오메트리 정본. 그리기와 봉인 스모크가 같은
# 함수를 통과해야 "코드상 여백이 있는데 화면은 붙어 있다"가 재발하지 않는다.
static func get_card_medallion_geometry(rect: Rect2) -> Dictionary:
	var paper_top: float = rect.position.y + RuntimePerkTraditionalChrome.CARD_PAPER_INSET
	var nameplate_top: float = rect.position.y + rect.size.y * CARD_NAMEPLATE_TOP_RATIO
	var top_clearance: float = clampf(
		rect.size.y * CARD_MEDALLION_TOP_CLEARANCE_RATIO,
		CARD_MEDALLION_TOP_CLEARANCE_MIN,
		CARD_MEDALLION_TOP_CLEARANCE_MAX
	)
	var bottom_clearance: float = clampf(
		rect.size.y * CARD_MEDALLION_BOTTOM_CLEARANCE_RATIO,
		CARD_MEDALLION_BOTTOM_CLEARANCE_MIN,
		CARD_MEDALLION_BOTTOM_CLEARANCE_MAX
	)
	var band_top: float = paper_top + top_clearance
	var band_bottom: float = max(band_top, nameplate_top - bottom_clearance)
	var band_radius: float = (band_bottom - band_top) * 0.5
	var icon_size: float = min(
		rect.size.x * CARD_ICON_MEDALLION_WIDTH_RATIO,
		rect.size.y * CARD_ICON_MEDALLION_HEIGHT_RATIO
	)
	# 밴드가 비율보다 우선한다 -- 넘치면 테두리/이름판을 파고든다.
	icon_size = min(icon_size, (band_radius - CARD_MEDALLION_RIM_PAD) / CARD_MEDALLION_RADIUS_RATIO)
	icon_size = max(CARD_ICON_MEDALLION_MIN_SIZE, icon_size)
	return {
		"center": Vector2(rect.get_center().x, (band_top + band_bottom) * 0.5),
		"radius": icon_size * CARD_MEDALLION_RADIUS_RATIO,
		"icon_size": icon_size,
		"band_top": band_top,
		"band_bottom": band_bottom,
		"paper_top": paper_top,
		"nameplate_top": nameplate_top,
	}


func _draw_card(canvas: CanvasItem, choice: Dictionary, rect: Rect2, selected: bool, animation_time: float, icon_renderer: Object, selection_blend: float = 0.0, paper_variant: int = 0) -> void:
	# The hit target remains the stable layout rect. Only the painted card lifts and
	# grows, so mouse/keyboard ownership cannot drift during the 160 ms transition.
	var visual_scale: float = 1.0 + CARD_SELECTION_SCALE * selection_blend
	var visual_size: Vector2 = rect.size * visual_scale
	var visual_center: Vector2 = rect.get_center() + Vector2(0.0, -CARD_SELECTION_LIFT * selection_blend)
	rect = Rect2(visual_center - visual_size * 0.5, visual_size)
	var icon_color: Color = _get_color(choice.get("icon_color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0)))
	var is_gold_conversion: bool = bool(choice.get("is_gold_conversion", false))
	if is_gold_conversion:
		# The reward remains legible as gold, but its surrounding engraving uses
		# aged brass instead of the former mobile-game yellow highlight.
		icon_color = Color(148.0 / 255.0, 109.0 / 255.0, 58.0 / 255.0)
	var rarity: String = str(choice.get("rarity", "common"))
	var is_mythic: bool = rarity == "mythic"
	var is_unique: bool = bool(choice.get("is_unique", false)) or rarity == "legendary"
	# 절세무공(mythic)은 레전더리보다 상위 프리미엄 — 골드 배경/테두리/이름을 공유하고,
	# 소유 그리드와 동일한 금빛 오너먼트(뒤 글로우 + 위 프레임)를 선택 카드에도 입힌다.
	var is_premium: bool = is_unique or is_mythic
	var is_dowsing_bonus: bool = bool(choice.get("is_dowsing_goggles_bonus", false))
	var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.006)
	var alpha: float = clamp(animation_time / 0.24, 0.0, 1.0) * lerpf(0.89, 1.0, selection_blend)

	# 금빛 오너먼트 글로우는 카드 배경보다 뒤에 깔린다(bg 이전). 프레임은 함수 말미에.
	if is_mythic:
		_draw_mythic_ornament_glow(canvas, rect, alpha, 0.9)

	if is_dowsing_bonus:
		var jade_glow := Color(104.0 / 255.0, 169.0 / 255.0, 151.0 / 255.0, (0.16 + 0.12 * pulse) * alpha)
		canvas.draw_rect(rect.grow(7.0), jade_glow, false, 2.0)
	_draw_character_outer_glow(canvas, rect, str(choice.get("character_restriction", "")), alpha * 0.42, pulse)

	var paper_rect: Rect2 = RuntimePerkTraditionalChrome.draw_card_base(
		canvas,
		rect,
		selected,
		is_premium,
		alpha,
		pulse,
		paper_variant,
		_traditional_ornament_atlas_texture,
		_traditional_card_paper_texture
	)
	_draw_character_edge(canvas, rect.grow(-3.0), str(choice.get("character_restriction", "")), alpha * 0.46, pulse)

	var medallion: Dictionary = get_card_medallion_geometry(rect)
	var icon_size: float = float(medallion.get("icon_size", 56.0))
	var icon_center: Vector2 = medallion.get("center", rect.get_center())
	var medallion_radius: float = float(medallion.get("radius", icon_size * CARD_MEDALLION_RADIUS_RATIO))
	canvas.draw_circle(icon_center, medallion_radius + CARD_MEDALLION_RIM_PAD, Color(44.0 / 255.0, 31.0 / 255.0, 20.0 / 255.0, 0.94 * alpha))
	canvas.draw_circle(icon_center, medallion_radius + 1.0, Color(17.0 / 255.0, 25.0 / 255.0, 30.0 / 255.0, 0.96 * alpha))
	canvas.draw_arc(icon_center, medallion_radius + 2.0, 0.0, TAU, 32, Color(188.0 / 255.0, 143.0 / 255.0, 66.0 / 255.0, 0.90 * alpha), 2.0)
	canvas.draw_arc(icon_center, medallion_radius - 3.0, 0.0, TAU, 32, Color(icon_color.r, icon_color.g, icon_color.b, 0.48 * alpha), 1.2)
	# Source PNGs already carry transparent breathing room around their ink disc.
	# Fill the medallion with that disc while keeping a narrow dark-metal reveal.
	var icon_draw_size: float = icon_size * CARD_ICON_DRAW_SCALE
	var icon_rect := Rect2(icon_center - Vector2.ONE * icon_draw_size * 0.5, Vector2.ONE * icon_draw_size)
	_draw_icon(canvas, icon_renderer, choice, icon_rect, alpha)
	RuntimePerkTraditionalChrome.draw_medallion_finish(
		canvas,
		icon_center,
		medallion_radius,
		is_gold_conversion,
		alpha
	)

	var nameplate_h: float = clamp(rect.size.y * CARD_NAMEPLATE_HEIGHT_RATIO, 27.0, 38.0)
	var nameplate_y: float = float(medallion.get("nameplate_top", rect.position.y + rect.size.y * CARD_NAMEPLATE_TOP_RATIO))
	var nameplate := Rect2(
		Vector2(paper_rect.position.x + 8.0, nameplate_y),
		Vector2(max(40.0, paper_rect.size.x - 16.0), nameplate_h)
	)
	RuntimePerkTraditionalChrome.draw_nameplate(canvas, nameplate, selected, is_premium, alpha)
	var name := str(choice.get("name", "알 수 없음"))
	var name_color: Color = Color(235.0 / 255.0, 222.0 / 255.0, 188.0 / 255.0, alpha)
	if is_premium:
		name_color = Color(1.0, 218.0 / 255.0, 116.0 / 255.0, alpha)
	var name_size: int = clampi(int(round(rect.size.x * 0.072)), 13, 24)
	_draw_text_centered_fitted(canvas, name, nameplate.get_center() + Vector2(0.0, 1.0), name_size, name_color, nameplate.size.x - 16.0, 11)
	var rank_text := _level_text(choice)
	var rank_size: int = clampi(int(round(rect.size.x * 0.057)), 11, 18)
	var rank_y: float = nameplate.end.y + max(14.0, rect.size.y * 0.045)
	_draw_text_centered(canvas, rank_text, Vector2(rect.get_center().x, rank_y), rank_size, _level_color(choice, is_premium, alpha))
	canvas.draw_line(
		Vector2(paper_rect.position.x + 13.0, rank_y + 12.0),
		Vector2(paper_rect.end.x - 13.0, rank_y + 12.0),
		Color(116.0 / 255.0, 87.0 / 255.0, 50.0 / 255.0, 0.38 * alpha),
		1.0
	)

	if is_dowsing_bonus:
		var bonus_badge := Rect2(rect.position + Vector2(8.0, 8.0), Vector2(30.0, 18.0))
		canvas.draw_rect(bonus_badge, Color(20.0 / 255.0, 52.0 / 255.0, 47.0 / 255.0, 0.94 * alpha))
		canvas.draw_rect(bonus_badge, Color(108.0 / 255.0, 169.0 / 255.0, 151.0 / 255.0, 0.82 * alpha), false, 1.0)
		_draw_text_centered(canvas, "+1", bonus_badge.get_center() + Vector2(0.0, 1.0), 11, Color(205.0 / 255.0, 225.0 / 255.0, 202.0 / 255.0, alpha))

	if _shows_character_unlock_badge(choice):
		var badge_rect := Rect2(Vector2(rect.end.x - 32.0, rect.position.y + 8.0), Vector2(24.0, 18.0))
		canvas.draw_rect(badge_rect, Color(18.0 / 255.0, 32.0 / 255.0, 42.0 / 255.0, 0.92 * alpha))
		canvas.draw_rect(badge_rect, Color(188.0 / 255.0, 143.0 / 255.0, 66.0 / 255.0, 0.82 * alpha), false, 1.0)
		_draw_text_centered(canvas, "A", badge_rect.get_center() + Vector2(0.0, 1.0), 12, Color(236.0 / 255.0, 220.0 / 255.0, 178.0 / 255.0, alpha))

	# 절세무공 금빛 프레임(오너먼트)은 카드 내용 전부 위에 — 소유 그리드와 동일한 프리미엄 표현.
	if is_mythic:
		_draw_mythic_ornament_frame(canvas, rect, alpha, 0.9)


func _draw_unlock_showcase(canvas: CanvasItem, snapshot: Dictionary, view_size: Vector2, icon_renderer: Object) -> void:
	var showcase: Dictionary = _get_dict(snapshot.get("unlock_showcase", {}))
	if not bool(showcase.get("active", false)):
		return
	var font: Font = _get_font()
	if font == null:
		return
	var age: float = float(showcase.get("age", 0.0))
	var alpha: float = clamp(age / 0.18, 0.0, 1.0)
	if alpha <= 0.001:
		return
	var skill_id: String = str(showcase.get("skill_id", ""))
	var skill_data: Dictionary = _get_dict(showcase.get("skill_data", {}))
	var choice: Dictionary = _get_dict(showcase.get("choice", {}))
	var color: Color = _get_color(skill_data.get("color", choice.get("icon_color", Color(90.0 / 255.0, 190.0 / 255.0, 1.0))))
	var skill_name: String = str(skill_data.get("korean", skill_data.get("name", choice.get("name", skill_id))))
	var how_to_use: String = _normalize_keycap_message(str(skill_data.get("how_to_use", "")))
	var motion_hint: String = str(skill_data.get("motion_hint", ""))
	var panel_width: float = min(max(UNLOCK_SHOWCASE_PANEL_MIN_WIDTH, view_size.x - UNLOCK_SHOWCASE_PANEL_HORIZONTAL_MARGIN), UNLOCK_SHOWCASE_PANEL_MAX_WIDTH)
	var panel_height: float = panel_width / UNLOCK_SHOWCASE_PANEL_ASPECT
	var panel_rect := Rect2(
		Vector2(floor((view_size.x - panel_width) * 0.5), floor((view_size.y - panel_height) * 0.5)),
		Vector2(panel_width, panel_height)
	)
	var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.006)
	_draw_unlock_showcase_backplate(canvas, panel_rect, color, alpha, pulse)

	var title_center := panel_rect.position + Vector2(panel_rect.size.x * 0.5, panel_rect.size.y * 0.165)
	_draw_text_centered(canvas, UNLOCK_SHOWCASE_TITLE_TEXT, title_center + Vector2(0.0, 1.0), 25, Color(color.r, color.g * 0.62, color.b, 0.24 * alpha))
	_draw_text_centered(canvas, UNLOCK_SHOWCASE_TITLE_TEXT, title_center, 25, Color(1.0, 235.0 / 255.0, 150.0 / 255.0, alpha))

	var icon_size: float = clamp(panel_rect.size.y * 0.31, 76.0, 92.0)
	var icon_center := panel_rect.position + Vector2(panel_rect.size.x * 0.157, panel_rect.size.y * 0.515)
	var icon_rect := Rect2(icon_center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	canvas.draw_circle(icon_center, icon_size * (0.78 + 0.04 * pulse), Color(color.r, color.g, color.b, 0.14 * alpha))
	canvas.draw_circle(icon_center, icon_size * 0.62, Color(4.0 / 255.0, 7.0 / 255.0, 15.0 / 255.0, 0.82 * alpha))
	canvas.draw_arc(icon_center, icon_size * 0.63, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.66 * alpha), 2.0)
	var icon_choice := choice.duplicate(true)
	icon_choice["id"] = skill_id
	icon_choice["icon_id"] = skill_id
	icon_choice["icon_color"] = color
	_draw_icon(canvas, icon_renderer, icon_choice, icon_rect.grow(-8.0), alpha)

	var text_left: float = panel_rect.position.x + panel_rect.size.x * 0.30
	var text_width: float = max(110.0, panel_rect.end.x - text_left - panel_rect.size.x * 0.075)
	var name_y: float = panel_rect.position.y + panel_rect.size.y * (0.49 if motion_hint != "" else 0.53)
	_draw_text_fitted(canvas, skill_name, Vector2(text_left, name_y), 30, Color(0.97, 0.99, 1.0, alpha), text_width, 18)
	if motion_hint != "":
		_draw_text_fitted(canvas, motion_hint, Vector2(text_left, name_y + 32.0), 15, Color(185.0 / 255.0, 205.0 / 255.0, 230.0 / 255.0, 0.94 * alpha), text_width, 11)

	if how_to_use != "":
		var keycap_y: float = panel_rect.position.y + panel_rect.size.y * 0.735
		var available_width: float = max(120.0, text_width)
		var keycap_font_size: int = TutorialHintKeycapRenderer.fit_font_size(font, how_to_use, available_width, 23, 13)
		TutorialHintKeycapRenderer.draw_centered_line(canvas, font, how_to_use, Vector2(text_left + text_width * 0.5, keycap_y), keycap_font_size, alpha)

	var blink: float = 0.55 + 0.45 * sin(float(_get_draw_msec()) * 0.005)
	_draw_text_centered(
		canvas,
		UNLOCK_SHOWCASE_PROMPT_TEXT,
		Vector2(panel_rect.get_center().x, min(view_size.y - 26.0, panel_rect.end.y + 20.0)),
		14,
		Color(185.0 / 255.0, 200.0 / 255.0, 225.0 / 255.0, (0.58 + 0.34 * blink) * alpha)
	)


func _draw_unlock_showcase_backplate(canvas: CanvasItem, panel_rect: Rect2, color: Color, alpha: float, pulse: float) -> void:
	for grow in [12.0, 6.0]:
		canvas.draw_rect(panel_rect.grow(grow), Color(color.r, color.g, color.b, (0.055 + 0.035 * pulse) * alpha), false, max(1.0, 3.0 - grow * 0.12))
	var texture: Texture2D = _get_unlock_showcase_panel_texture()
	if texture != null:
		canvas.draw_texture_rect(texture, panel_rect, false, Color(1.0, 1.0, 1.0, alpha))
		return
	canvas.draw_rect(panel_rect, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.95 * alpha))
	canvas.draw_rect(panel_rect, Color(color.r, color.g, color.b, 0.76 * alpha), false, 2.4)
	canvas.draw_line(panel_rect.position + Vector2(24.0, panel_rect.size.y * 0.30), Vector2(panel_rect.end.x - 24.0, panel_rect.position.y + panel_rect.size.y * 0.30), Color(color.r, color.g, color.b, 0.34 * alpha), 1.0)




# 조회 전용 게터 3종(draw 핫패스): 로드는 prewarm_assets()가 소유한다.
# 프리웜되지 않은 cold 렌더러(플라자/결과화면 등 별도 인스턴스)에서는
# null을 돌려 절차 폴백이 그려진다 — 첫 표시 프레임 디스크 로드 금지.
func _get_unlock_showcase_panel_texture() -> Texture2D:
	return _unlock_showcase_panel_texture


func _get_mythic_reveal_lightburst_texture() -> Texture2D:
	return _mythic_reveal_lightburst_texture


func _get_mythic_reveal_smoke_texture() -> Texture2D:
	return _mythic_reveal_smoke_texture


func _draw_mythic_reveal_backdrop(
	canvas: CanvasItem,
	_runtime_state: Object,
	choices: Array,
	view_size: Vector2,
	animation_time: float
) -> void:
	if canvas == null or view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	if not _choices_include_mythic(choices):
		return
	var age: float = clampf(animation_time, 0.0, MYTHIC_REVEAL_DURATION)
	var alpha: float = clampf(age / 0.20, 0.0, 1.0) * clampf((MYTHIC_REVEAL_DURATION - age) / 0.72, 0.0, 1.0)
	if alpha <= 0.003:
		return
	var center := view_size * 0.5
	var base_size: float = max(view_size.x, view_size.y)
	var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.004)
	var lightburst: Texture2D = _get_mythic_reveal_lightburst_texture()
	if lightburst != null:
		var light_size := Vector2(base_size * (0.82 + 0.05 * pulse), base_size * (0.54 + 0.03 * pulse))
		canvas.draw_texture_rect(
			lightburst,
			Rect2(center - light_size * 0.5, light_size),
			false,
			Color(1.0, 1.0, 1.0, 0.42 * alpha)
		)
	else:
		canvas.draw_circle(center, base_size * 0.30, Color(1.0, 0.72, 0.18, 0.10 * alpha))
	var smoke: Texture2D = _get_mythic_reveal_smoke_texture()
	if smoke != null:
		var drift := Vector2(sin(float(_get_draw_msec()) * 0.0017) * 18.0, -age * 12.0)
		var smoke_size := Vector2(base_size * 0.94, base_size * 0.50)
		canvas.draw_texture_rect(
			smoke,
			Rect2(center - smoke_size * 0.5 + drift, smoke_size),
			false,
			Color(1.0, 0.92, 0.72, 0.26 * alpha)
		)


func _choices_include_mythic(choices: Array) -> bool:
	for choice in choices:
		if choice is Dictionary and str(choice.get("rarity", "")).to_lower() == "mythic":
			return true
	return false



func _normalize_keycap_message(text: String) -> String:
	var words: Array = []
	for raw_word in text.split(" ", false):
		words.append(_normalize_joined_keycap_token(str(raw_word)))
	return " ".join(words)


func _normalize_joined_keycap_token(token: String) -> String:
	for separator in ["/", "-", "+"]:
		if token.find(separator) < 0:
			continue
		var pieces: PackedStringArray = token.split(separator, false)
		if pieces.size() < 2:
			continue
		var normalized: Array = []
		var all_key_tokens := true
		for piece in pieces:
			var clean_piece: String = str(piece).strip_edges()
			if clean_piece == "" or not TutorialHintKeycapRenderer.KEYCAP_TOKENS.has(clean_piece):
				all_key_tokens = false
				break
			normalized.append(clean_piece)
		if all_key_tokens:
			return (" %s " % separator).join(normalized)
	return token


func _draw_unlock_swap_dialog(canvas: CanvasItem, runtime_state: Object, snapshot: Dictionary, view_size: Vector2, icon_renderer: Object) -> void:
	var swap: Dictionary = _get_dict(snapshot.get("pending_unlock_swap", {}))
	var candidates: Array = _get_array(swap.get("candidates", []))
	if candidates.is_empty():
		return
	var selected_index: int = clampi(int(snapshot.get("unlock_swap_selected_index", 0)), 0, candidates.size() - 1)
	var layout: Dictionary = runtime_state.build_unlock_swap_layout(view_size) if runtime_state.has_method("build_unlock_swap_layout") else {}
	var panel_rect: Rect2 = _get_rect2(layout.get("panel_rect", Rect2(Vector2(view_size.x * 0.5 - 240.0, view_size.y * 0.5 - 140.0), Vector2(480.0, 280.0))))
	canvas.draw_rect(panel_rect, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.95))
	canvas.draw_rect(panel_rect, Color(1.0, 190.0 / 255.0, 80.0 / 255.0, 0.86), false, 2.5)
	canvas.draw_line(panel_rect.position + Vector2(18.0, 88.0), Vector2(panel_rect.end.x - 18.0, panel_rect.position.y + 88.0), Color(1.0, 190.0 / 255.0, 80.0 / 255.0, 0.45), 1.0)

	_draw_text_centered(canvas, "화기 슬롯 교체", _get_vector2(layout.get("title_pos", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 38.0))), 24, Color(1.0, 225.0 / 255.0, 125.0 / 255.0))
	_draw_text_centered(canvas, "새 화기: %s" % str(swap.get("new_name", swap.get("unlocks_skill", ""))), _get_vector2(layout.get("new_skill_pos", panel_rect.position + Vector2(panel_rect.size.x * 0.5, 70.0))), 15, Color(210.0 / 255.0, 225.0 / 255.0, 240.0 / 255.0))

	var rects: Array = runtime_state.get_unlock_swap_option_rects(view_size) if runtime_state.has_method("get_unlock_swap_option_rects") else []
	for index in range(min(candidates.size(), rects.size())):
		var candidate: Dictionary = _get_dict(candidates[index])
		var rect: Rect2 = rects[index]
		var selected: bool = index == selected_index
		var skill_id: String = str(candidate.get("skill_id", ""))
		var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.006)
		if selected:
			for grow in [8.0, 4.0]:
				canvas.draw_rect(rect.grow(grow), Color(1.0, 190.0 / 255.0, 80.0 / 255.0, (0.16 + 0.12 * pulse)), false, max(1.0, 4.0 - grow * 0.25))
		canvas.draw_rect(rect, Color(24.0 / 255.0, 31.0 / 255.0, 46.0 / 255.0, 0.94))
		canvas.draw_rect(rect, Color(1.0, 205.0 / 255.0, 90.0 / 255.0, 0.90 if selected else 0.42), false, 2.0 if selected else 1.2)
		var icon_rect := Rect2(rect.position + Vector2(rect.size.x * 0.5 - 24.0, 16.0), Vector2(48.0, 48.0))
		canvas.draw_rect(icon_rect, Color(10.0 / 255.0, 14.0 / 255.0, 24.0 / 255.0, 0.88))
		if icon_renderer == null or not icon_renderer.has_method("draw_icon") or not bool(icon_renderer.draw_icon(canvas, skill_id, icon_rect.grow(-4.0), 1.0, true)):
			canvas.draw_circle(icon_rect.get_center(), 18.0, Color(0.52, 0.62, 0.50, 0.92))
		_draw_text_fitted(canvas, str(candidate.get("name", skill_id)), rect.position + Vector2(12.0, rect.size.y - 28.0), 14, Color(0.94, 0.97, 1.0), rect.size.x - 24.0, 10)

	_draw_text_centered(canvas, "Enter 선택 / Esc 취소", _get_vector2(layout.get("hint_pos", panel_rect.end - Vector2(panel_rect.size.x * 0.5, 34.0))), 13, Color(170.0 / 255.0, 180.0 / 255.0, 210.0 / 255.0, 0.94))


func _draw_character_edge(canvas: CanvasItem, rect: Rect2, restriction: String, alpha: float, pulse: float) -> void:
	if restriction == "":
		return
	var theme: Dictionary = _character_edge_theme(restriction, alpha, pulse)
	if theme.is_empty():
		return
	var main: Color = theme.get("main", Color(0.0, 0.0, 0.0, 0.0))
	var accent: Color = theme.get("accent", main)
	var highlight: Color = theme.get("highlight", accent)
	var fast_pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.0108)
	var marker: String = str(theme.get("marker", "energy"))

	# Inner glow band (Python parity: 7-layer inset, brightest near edge fading inward).
	for inset in range(1, 8):
		var band_alpha: float = clamp((0.42 + 0.22 * pulse) - float(inset) * 0.048, 0.0, 1.0) * alpha
		if band_alpha <= 0.003:
			continue
		canvas.draw_rect(rect.grow(-float(inset)), Color(main.r, main.g, main.b, band_alpha), false, 1.0)

	# Pulsing main accent border (stronger than the card's static border).
	var main_alpha: float = (0.65 + 0.25 * pulse) * alpha
	canvas.draw_rect(rect.grow(1.0), Color(accent.r, accent.g, accent.b, main_alpha), false, 2.0)

	# Inner highlight line (close to white at peak pulse).
	var hl_alpha: float = (0.34 + 0.26 * pulse) * alpha
	canvas.draw_rect(rect.grow(-3.0), Color(highlight.r, highlight.g, highlight.b, hl_alpha), false, 1.0)

	var corner_len: float = min(18.0, rect.size.x * 0.16)
	var corner_accent := Color(accent.r, accent.g, accent.b, (0.62 + 0.22 * pulse) * alpha)
	var corner_highlight := Color(highlight.r, highlight.g, highlight.b, (0.48 + 0.24 * pulse) * alpha)
	_draw_character_edge_corners(canvas, rect, corner_accent, corner_highlight, corner_len)

	if marker == "poison":
		_draw_viper_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)
	elif marker == "mecha":
		_draw_optimus_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)
	elif marker == "tactical":
		_draw_soldier_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)
	else:
		_draw_smasher_edge_marks(canvas, rect, main, accent, highlight, alpha, pulse, fast_pulse)


func _draw_character_outer_glow(canvas: CanvasItem, rect: Rect2, restriction: String, alpha: float, pulse: float) -> void:
	if restriction == "":
		return
	var theme: Dictionary = _character_edge_theme(restriction, alpha, pulse)
	if theme.is_empty():
		return
	var main: Color = theme.get("main", Color(0.0, 0.0, 0.0, 0.0))
	var sb: StyleBoxFlat = _get_back_glow_stylebox()
	var corner_radius: int = int(clamp(round(rect.size.y * 0.18), 8.0, 16.0))
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	for grow in [8.0, 6.0, 4.0, 2.0]:
		var alpha_byte: float = (50.0 - grow * 5.0) + pulse * 25.0
		var glow_alpha: float = clamp(alpha_byte / 255.0, 0.0, 1.0) * alpha
		if glow_alpha <= 0.003:
			continue
		sb.bg_color = Color(main.r, main.g, main.b, glow_alpha)
		canvas.draw_style_box(sb, rect.grow(grow))


func _get_back_glow_stylebox() -> StyleBoxFlat:
	if _back_glow_stylebox == null:
		_back_glow_stylebox = StyleBoxFlat.new()
		_back_glow_stylebox.anti_aliasing = true
		_back_glow_stylebox.anti_aliasing_size = 1.0
	return _back_glow_stylebox


func _character_edge_theme(restriction: String, alpha: float = 1.0, pulse: float = 0.5) -> Dictionary:
	match restriction:
		"smasher":
			return {
				"main": Color(0.0, 200.0 / 255.0, 1.0, alpha),
				"accent": Color(120.0 / 255.0, 240.0 / 255.0, 1.0, alpha),
				"highlight": Color(210.0 / 255.0, 1.0, 1.0, alpha),
				"marker": "energy",
				"pulse": pulse,
			}
		"viper":
			return {
				"main": Color(160.0 / 255.0, 0.0, 220.0 / 255.0, alpha),
				"accent": Color(200.0 / 255.0, 80.0 / 255.0, 1.0, alpha),
				"highlight": Color(240.0 / 255.0, 160.0 / 255.0, 1.0, alpha),
				"marker": "poison",
				"pulse": pulse,
			}
		"optimus":
			return {
				"main": Color(1.0, 140.0 / 255.0, 0.0, alpha),
				"accent": Color(1.0, 200.0 / 255.0, 80.0 / 255.0, alpha),
				"highlight": Color(1.0, 230.0 / 255.0, 150.0 / 255.0, alpha),
				"marker": "mecha",
				"pulse": pulse,
			}
		"soldier", "commando":
			return {
				"main": Color(80.0 / 255.0, 200.0 / 255.0, 60.0 / 255.0, alpha),
				"accent": Color(150.0 / 255.0, 240.0 / 255.0, 110.0 / 255.0, alpha),
				"highlight": Color(210.0 / 255.0, 1.0, 190.0 / 255.0, alpha),
				"marker": "tactical",
				"pulse": pulse,
			}
		_:
			return {}


func _draw_character_edge_corners(canvas: CanvasItem, rect: Rect2, accent: Color, highlight: Color, corner_len: float) -> void:
	var left: float = rect.position.x + 5.0
	var right: float = rect.end.x - 5.0
	var top: float = rect.position.y + 5.0
	var bottom: float = rect.end.y - 5.0
	var corners: Array[Dictionary] = [
		{"point": Vector2(left, top), "dir": Vector2(1.0, 1.0)},
		{"point": Vector2(right, top), "dir": Vector2(-1.0, 1.0)},
		{"point": Vector2(left, bottom), "dir": Vector2(1.0, -1.0)},
		{"point": Vector2(right, bottom), "dir": Vector2(-1.0, -1.0)},
	]
	for corner in corners:
		var point: Vector2 = corner.get("point", Vector2.ZERO)
		var dir: Vector2 = corner.get("dir", Vector2.ONE)
		canvas.draw_line(point, point + Vector2(corner_len * dir.x, 0.0), accent, 2.0)
		canvas.draw_line(point, point + Vector2(0.0, corner_len * dir.y), accent, 2.0)
		canvas.draw_line(point, point + Vector2(corner_len * 0.56 * dir.x, 0.0), highlight, 1.0)


func _draw_smasher_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	_pulse: float,
	fast_pulse: float
) -> void:
	# 4-corner lightning sparks (Python: 15-frame cycle, phases 0..9 render with
	# size 4 → 3 → 2 px depending on phase, brightest at phase 0).
	var phase_base: int = int(float(_get_draw_msec()) * 0.06)
	var corners: Array[Vector2] = [
		rect.position + Vector2(6.0, 6.0),
		Vector2(rect.end.x - 7.0, rect.position.y + 6.0),
		Vector2(rect.position.x + 6.0, rect.end.y - 7.0),
		rect.end - Vector2(7.0, 7.0),
	]
	for ci in range(corners.size()):
		var spark_phase: int = (phase_base + ci * 5) % 15
		if spark_phase >= 10:
			continue
		var spark_alpha: float = clamp((220.0 - float(spark_phase) * 18.0) / 255.0, 0.0, 1.0) * alpha
		if spark_alpha <= 0.005:
			continue
		var spark_r: float = 4.0 if spark_phase < 3 else (3.0 if spark_phase < 6 else 2.0)
		if spark_phase < 3:
			canvas.draw_circle(corners[ci], spark_r + 1.0, Color(main.r, main.g, main.b, spark_alpha * 0.5))
		canvas.draw_circle(corners[ci], spark_r, Color(highlight.r, highlight.g, highlight.b, spark_alpha))

	# Top/bottom zig-zag energy lines (Python: 8 segments, jitter 3px).
	var top_y: float = rect.position.y + 2.0
	var bottom_y: float = rect.end.y - 3.0
	var inner_left: float = rect.position.x + 10.0
	var inner_w: float = rect.size.x - 20.0
	var line_alpha: float = clamp((90.0 + 50.0 * fast_pulse) / 255.0, 0.0, 1.0) * alpha
	var energy_color := Color(accent.r, accent.g, accent.b, line_alpha)
	var time_ms: float = float(_get_draw_msec())
	for si in range(8):
		var sx1: float = inner_left + inner_w * float(si) / 8.0
		var sx2: float = inner_left + inner_w * float(si + 1) / 8.0
		var jitter: float = sin(time_ms * 0.024 + float(si) * 1.2) * 3.0
		canvas.draw_line(Vector2(sx1, top_y + jitter), Vector2(sx2, top_y - jitter), energy_color, 1.0)
		canvas.draw_line(Vector2(sx1, bottom_y - jitter), Vector2(sx2, bottom_y + jitter), energy_color, 1.0)

	# Left/right vertical electric lines (Python: 5 segments, jitter 2px, dimmer).
	var inner_top: float = rect.position.y + 10.0
	var inner_h: float = rect.size.y - 20.0
	var side_alpha: float = clamp((70.0 + 40.0 * fast_pulse) / 255.0, 0.0, 1.0) * alpha
	var side_color := Color(main.r, main.g, main.b, side_alpha)
	for si in range(5):
		var sy1: float = inner_top + inner_h * float(si) / 5.0
		var sy2: float = inner_top + inner_h * float(si + 1) / 5.0
		var jitter: float = sin(time_ms * 0.021 + float(si) * 1.8) * 2.0
		canvas.draw_line(Vector2(rect.position.x + 2.0 + jitter, sy1), Vector2(rect.position.x + 2.0 - jitter, sy2), side_color, 1.0)
		canvas.draw_line(Vector2(rect.end.x - 3.0 - jitter, sy1), Vector2(rect.end.x - 3.0 + jitter, sy2), side_color, 1.0)


func _draw_viper_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	_pulse: float,
	_fast_pulse: float
) -> void:
	# 12 poison smoke particles travelling along the perimeter (Python parity).
	var poison_count := 12
	var time_ms: float = float(_get_draw_msec())
	var inset := 4.0
	var inner_w: float = max(1.0, rect.size.x - inset * 2.0)
	var inner_h: float = max(1.0, rect.size.y - inset * 2.0)
	var perim: float = 2.0 * (inner_w + inner_h)
	for pi in range(poison_count):
		var vt: float = fmod(time_ms * 0.0015 + float(pi) * (TAU / float(poison_count)), TAU)
		if vt < 0.0:
			vt += TAU
		var pos_on_perim: float = (vt / TAU) * perim
		var px: float = 0.0
		var py: float = 0.0
		if pos_on_perim < inner_w:
			px = rect.position.x + inset + pos_on_perim
			py = rect.position.y + 3.0
		elif pos_on_perim < inner_w + inner_h:
			px = rect.end.x - inset
			py = rect.position.y + inset + (pos_on_perim - inner_w)
		elif pos_on_perim < 2.0 * inner_w + inner_h:
			px = rect.end.x - inset - (pos_on_perim - inner_w - inner_h)
			py = rect.end.y - inset
		else:
			px = rect.position.x + 3.0
			py = rect.end.y - inset - (pos_on_perim - 2.0 * inner_w - inner_h)
		var p_alpha: float = clamp((160.0 + 70.0 * sin(time_ms * 0.009 + float(pi))) / 255.0, 0.0, 1.0) * alpha
		if p_alpha <= 0.005:
			continue
		var pr: float = 3.0 if pi % 4 == 0 else 2.0
		var pc: Color = highlight if pi % 3 == 0 else accent
		# Soft halo around bigger particles.
		if pr >= 3.0:
			canvas.draw_circle(Vector2(px, py), pr + 2.0, Color(main.r, main.g, main.b, p_alpha * 0.33))
		canvas.draw_circle(Vector2(px, py), pr, Color(pc.r, pc.g, pc.b, p_alpha))

	# 4 corner poison puddles (Python: dim outer pool + bright inner core).
	var v_corners: Array[Vector2] = [
		rect.position + Vector2(6.0, 6.0),
		Vector2(rect.end.x - 7.0, rect.position.y + 6.0),
		Vector2(rect.position.x + 6.0, rect.end.y - 7.0),
		rect.end - Vector2(7.0, 7.0),
	]
	for vi in range(v_corners.size()):
		var va: float = clamp((100.0 + 60.0 * sin(time_ms * 0.0048 + float(vi) * 1.5)) / 255.0, 0.0, 1.0) * alpha
		if va <= 0.005:
			continue
		canvas.draw_circle(v_corners[vi], 4.0, Color(main.r, main.g, main.b, va * 0.5))
		canvas.draw_circle(v_corners[vi], 2.0, Color(accent.r, accent.g, accent.b, va))


func _draw_optimus_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	pulse: float,
	_fast_pulse: float
) -> void:
	# L-shape gear/circuit corner decorations (Python: 4 corners, 2 thick + 2 thin lines each).
	var corner_len: float = 14.0
	var ca: float = clamp((180.0 + 60.0 * pulse) / 255.0, 0.0, 1.0) * alpha
	if ca > 0.005:
		var ax := Color(accent.r, accent.g, accent.b, ca)
		var hx := Color(highlight.r, highlight.g, highlight.b, ca * 0.5)
		var lx: float = rect.position.x
		var rx: float = rect.end.x
		var ty: float = rect.position.y
		var by: float = rect.end.y
		# top-left
		canvas.draw_line(Vector2(lx + 3.0, ty + 6.0), Vector2(lx + 3.0, ty + 6.0 + corner_len), ax, 2.0)
		canvas.draw_line(Vector2(lx + 3.0, ty + 6.0), Vector2(lx + 3.0 + corner_len, ty + 6.0), ax, 2.0)
		canvas.draw_line(Vector2(lx + 5.0, ty + 8.0), Vector2(lx + 5.0, ty + 8.0 + corner_len - 4.0), hx, 1.0)
		canvas.draw_line(Vector2(lx + 5.0, ty + 8.0), Vector2(lx + 5.0 + corner_len - 4.0, ty + 8.0), hx, 1.0)
		# top-right
		canvas.draw_line(Vector2(rx - 4.0, ty + 6.0), Vector2(rx - 4.0, ty + 6.0 + corner_len), ax, 2.0)
		canvas.draw_line(Vector2(rx - 4.0, ty + 6.0), Vector2(rx - 4.0 - corner_len, ty + 6.0), ax, 2.0)
		canvas.draw_line(Vector2(rx - 6.0, ty + 8.0), Vector2(rx - 6.0, ty + 8.0 + corner_len - 4.0), hx, 1.0)
		canvas.draw_line(Vector2(rx - 6.0, ty + 8.0), Vector2(rx - 6.0 - corner_len + 4.0, ty + 8.0), hx, 1.0)
		# bottom-left
		canvas.draw_line(Vector2(lx + 3.0, by - 7.0), Vector2(lx + 3.0, by - 7.0 - corner_len), ax, 2.0)
		canvas.draw_line(Vector2(lx + 3.0, by - 7.0), Vector2(lx + 3.0 + corner_len, by - 7.0), ax, 2.0)
		canvas.draw_line(Vector2(lx + 5.0, by - 9.0), Vector2(lx + 5.0, by - 9.0 - corner_len + 4.0), hx, 1.0)
		canvas.draw_line(Vector2(lx + 5.0, by - 9.0), Vector2(lx + 5.0 + corner_len - 4.0, by - 9.0), hx, 1.0)
		# bottom-right
		canvas.draw_line(Vector2(rx - 4.0, by - 7.0), Vector2(rx - 4.0, by - 7.0 - corner_len), ax, 2.0)
		canvas.draw_line(Vector2(rx - 4.0, by - 7.0), Vector2(rx - 4.0 - corner_len, by - 7.0), ax, 2.0)
		canvas.draw_line(Vector2(rx - 6.0, by - 9.0), Vector2(rx - 6.0, by - 9.0 - corner_len + 4.0), hx, 1.0)
		canvas.draw_line(Vector2(rx - 6.0, by - 9.0), Vector2(rx - 6.0 - corner_len + 4.0, by - 9.0), hx, 1.0)

	# 6 top/bottom circuit dots (Python: pulsing per-dot phase).
	var time_ms: float = float(_get_draw_msec())
	for di in range(6):
		var dx: float = rect.position.x + rect.size.x * float(di + 1) / 7.0
		var dp: float = sin(time_ms * 0.009 + float(di) * 0.9)
		var da: float = clamp((130.0 + 70.0 * dp) / 255.0, 0.0, 1.0) * alpha
		if da <= 0.005:
			continue
		var dr: float = 2.0 if dp > 0.5 else 1.0
		canvas.draw_circle(Vector2(dx, rect.position.y + 4.0), dr, Color(accent.r, accent.g, accent.b, da))
		canvas.draw_circle(Vector2(dx, rect.end.y - 5.0), dr, Color(accent.r, accent.g, accent.b, da))

	# Vertical-sweeping scanline.
	var scan_pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0036)
	var scan_y: float = rect.position.y + 6.0 + (rect.size.y - 12.0) * scan_pulse
	var scan_alpha: float = clamp((40.0 + 25.0 * pulse) / 255.0, 0.0, 1.0) * alpha
	if scan_alpha > 0.004:
		canvas.draw_line(
			Vector2(rect.position.x + 4.0, scan_y),
			Vector2(rect.end.x - 5.0, scan_y),
			Color(main.r, main.g, main.b, scan_alpha),
			1.0
		)


func _draw_soldier_edge_marks(
	canvas: CanvasItem,
	rect: Rect2,
	main: Color,
	accent: Color,
	highlight: Color,
	alpha: float,
	pulse: float,
	fast_pulse: float
) -> void:
	# 4 corner tactical crosses with bright center dot.
	var marker_corners: Array[Vector2] = [
		rect.position + Vector2(9.0, 9.0),
		Vector2(rect.end.x - 10.0, rect.position.y + 9.0),
		Vector2(rect.position.x + 9.0, rect.end.y - 10.0),
		rect.end - Vector2(10.0, 10.0),
	]
	var ma: float = clamp((180.0 + 60.0 * fast_pulse) / 255.0, 0.0, 1.0) * alpha
	if ma > 0.005:
		var marker_color := Color(accent.r, accent.g, accent.b, ma)
		var center_color := Color(highlight.r, highlight.g, highlight.b, ma)
		for mc in marker_corners:
			canvas.draw_line(mc + Vector2(-4.0, 0.0), mc + Vector2(4.0, 0.0), marker_color, 2.0)
			canvas.draw_line(mc + Vector2(0.0, -4.0), mc + Vector2(0.0, 4.0), marker_color, 2.0)
			canvas.draw_circle(mc, 1.4, center_color)

	# Vertical dashed side lines.
	var dash_len: float = 5.0
	var gap: float = 5.0
	var dl_a: float = clamp((100.0 + 50.0 * pulse) / 255.0, 0.0, 1.0) * alpha
	if dl_a <= 0.005:
		return
	var dash_color := Color(main.r, main.g, main.b, dl_a)

	var dy: float = rect.position.y + 16.0
	var dy_end: float = rect.end.y - 16.0
	while dy < dy_end:
		var dy_stop: float = min(dy + dash_len, dy_end)
		canvas.draw_line(Vector2(rect.position.x + 2.0, dy), Vector2(rect.position.x + 2.0, dy_stop), dash_color, 2.0)
		canvas.draw_line(Vector2(rect.end.x - 3.0, dy), Vector2(rect.end.x - 3.0, dy_stop), dash_color, 2.0)
		dy += dash_len + gap

	# Horizontal dashed top/bottom lines (Python parity addition).
	var dx: float = rect.position.x + 16.0
	var dx_end: float = rect.end.x - 16.0
	while dx < dx_end:
		var dx_stop: float = min(dx + dash_len, dx_end)
		canvas.draw_line(Vector2(dx, rect.position.y + 2.0), Vector2(dx_stop, rect.position.y + 2.0), dash_color, 1.0)
		canvas.draw_line(Vector2(dx, rect.end.y - 3.0), Vector2(dx_stop, rect.end.y - 3.0), dash_color, 1.0)
		dx += dash_len + gap


# Soft golden surround halo for mythic perks. MUST be drawn BEHIND the card/cell
# (before its opaque bg) -- drawn on top it would veil the whole interior in an amber
# haze. Fills rounded styleboxes larger than `rect`; the bg then masks the inner portion
# so only the outer bloom ring shows and the interior stays clean.
func _draw_mythic_ornament_glow(canvas: CanvasItem, rect: Rect2, alpha: float, intensity: float = 0.6) -> void:
	if alpha <= 0.003:
		return
	intensity = clampf(intensity, 0.0, 1.0)
	var time_ms: float = float(_get_draw_msec())
	var pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0042)
	var ref: float = min(rect.size.x, rect.size.y)
	var scale_ref: float = clampf(ref / 120.0, 0.42, 1.0)
	var sb: StyleBoxFlat = _get_back_glow_stylebox()
	var corner_radius: int = int(clamp(round(ref * 0.16), 6.0, 18.0))
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	var bloom_base: float = (0.11 + 0.13 * pulse) * (0.58 + 0.42 * intensity)
	for grow in [16.0, 11.0, 7.0, 3.0]:
		var g: float = grow * scale_ref
		var bloom_alpha: float = clampf(bloom_base - g * 0.0048, 0.0, 1.0) * alpha
		if bloom_alpha <= 0.003:
			continue
		sb.bg_color = Color(MYTHIC_GOLD_AMBER.r, MYTHIC_GOLD_AMBER.g, MYTHIC_GOLD_AMBER.b, bloom_alpha)
		canvas.draw_style_box(sb, rect.grow(g))


# Golden FRAME ornament for mythic perks: ornate double frame, corner filigree with gem
# studs, orbiting sparkles, and a crown gem (large surfaces only). Every draw sits ON the
# rect edge or OUTSIDE it, so the card/cell interior is never tinted. Draw this AFTER the
# card bg/icon/text; pair it with _draw_mythic_ornament_glow behind.
func _draw_mythic_ornament_frame(canvas: CanvasItem, rect: Rect2, alpha: float, intensity: float = 0.6) -> void:
	if alpha <= 0.003:
		return
	intensity = clampf(intensity, 0.0, 1.0)
	var time_ms: float = float(_get_draw_msec())
	var pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0042)
	var fast_pulse: float = 0.5 + 0.5 * sin(time_ms * 0.0091)
	var ref: float = min(rect.size.x, rect.size.y)
	var scale_ref: float = clampf(ref / 120.0, 0.42, 1.0)

	# Ornate double frame.
	var outer := rect.grow(2.0 * scale_ref)
	canvas.draw_rect(outer, Color(MYTHIC_GOLD_DEEP.r, MYTHIC_GOLD_DEEP.g, MYTHIC_GOLD_DEEP.b, (0.72 + 0.20 * pulse) * alpha), false, max(1.6, 2.6 * scale_ref))
	canvas.draw_rect(rect.grow(-1.5 * scale_ref), Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, (0.50 + 0.28 * pulse) * alpha), false, max(1.0, 1.4 * scale_ref))

	# Corner filigree brackets + gem studs.
	var corner_len: float = clampf(ref * 0.22, 9.0, 30.0)
	var inset: float = 3.0 * scale_ref
	var lx: float = rect.position.x + inset
	var rx: float = rect.end.x - inset
	var ty: float = rect.position.y + inset
	var by: float = rect.end.y - inset
	var bracket := Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, (0.80 + 0.18 * pulse) * alpha)
	var shine := Color(MYTHIC_GOLD_HIGHLIGHT.r, MYTHIC_GOLD_HIGHLIGHT.g, MYTHIC_GOLD_HIGHLIGHT.b, (0.58 + 0.32 * fast_pulse) * alpha)
	var bracket_w: float = max(1.6, 2.4 * scale_ref)
	var corners: Array = [
		[Vector2(lx, ty), Vector2(1.0, 1.0)],
		[Vector2(rx, ty), Vector2(-1.0, 1.0)],
		[Vector2(lx, by), Vector2(1.0, -1.0)],
		[Vector2(rx, by), Vector2(-1.0, -1.0)],
	]
	var gem_r: float = max(1.8, 2.8 * scale_ref)
	for corner in corners:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		canvas.draw_line(p, p + Vector2(corner_len * d.x, 0.0), bracket, bracket_w)
		canvas.draw_line(p, p + Vector2(0.0, corner_len * d.y), bracket, bracket_w)
		canvas.draw_line(p + Vector2(2.0 * d.x, 2.0 * d.y), p + Vector2(corner_len * 0.58 * d.x, 2.0 * d.y), shine, max(1.0, bracket_w * 0.5))
		canvas.draw_circle(p, gem_r, Color(MYTHIC_GOLD_DEEP.r, MYTHIC_GOLD_DEEP.g, MYTHIC_GOLD_DEEP.b, alpha))
		canvas.draw_circle(p, gem_r * 0.5, shine)

	# Orbiting golden sparkles on a path just outside the frame.
	var sparkle_path := rect.grow(3.5 * scale_ref)
	var count: int = MYTHIC_ORNAMENT_SPARKLE_COUNT if ref >= MYTHIC_ORNAMENT_CROWN_MIN_REF else MYTHIC_ORNAMENT_COMPACT_SPARKLE_COUNT
	var perim: float = 2.0 * (sparkle_path.size.x + sparkle_path.size.y)
	for si in range(count):
		var travel: float = fmod(time_ms * 0.00017 + float(si) / float(count), 1.0) * perim
		var sp: Vector2 = _perimeter_point(sparkle_path, travel)
		var twinkle: float = 0.5 + 0.5 * sin(time_ms * 0.006 + float(si) * 1.7)
		var s_alpha: float = clampf((0.34 + 0.66 * twinkle) * (0.68 + 0.32 * intensity), 0.0, 1.0) * alpha
		if s_alpha <= 0.02:
			continue
		_draw_gold_sparkle(canvas, sp, (2.4 + 1.7 * twinkle) * scale_ref, s_alpha)

	# Crown gem accent (large surfaces only -- skipped on the compact tray cell).
	if ref >= MYTHIC_ORNAMENT_CROWN_MIN_REF:
		var crown_center := Vector2(rect.get_center().x, rect.position.y - 7.0 * scale_ref)
		var gs: float = (5.0 + 0.8 * pulse) * scale_ref
		var gem := PackedVector2Array([
			crown_center + Vector2(0.0, -gs * 1.35),
			crown_center + Vector2(gs, 0.0),
			crown_center + Vector2(0.0, gs * 1.35),
			crown_center + Vector2(-gs, 0.0),
		])
		canvas.draw_circle(crown_center, gs * 2.0, Color(MYTHIC_GOLD_AMBER.r, MYTHIC_GOLD_AMBER.g, MYTHIC_GOLD_AMBER.b, 0.42 * alpha))
		canvas.draw_colored_polygon(gem, Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, alpha))
		canvas.draw_circle(crown_center, gs * 0.42, Color(MYTHIC_GOLD_HIGHLIGHT.r, MYTHIC_GOLD_HIGHLIGHT.g, MYTHIC_GOLD_HIGHLIGHT.b, alpha))


# Classic 8-point gold twinkle: soft halo, crossed rays, bright core. Convex-only
# draws (circles + lines) so there is no concave-polygon triangulation risk.
func _draw_gold_sparkle(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	canvas.draw_circle(center, size * 1.7, Color(MYTHIC_GOLD_AMBER.r, MYTHIC_GOLD_AMBER.g, MYTHIC_GOLD_AMBER.b, alpha * 0.32))
	var ray := Color(MYTHIC_GOLD_HIGHLIGHT.r, MYTHIC_GOLD_HIGHLIGHT.g, MYTHIC_GOLD_HIGHLIGHT.b, alpha)
	var diag_ray := Color(MYTHIC_GOLD_BRIGHT.r, MYTHIC_GOLD_BRIGHT.g, MYTHIC_GOLD_BRIGHT.b, alpha * 0.72)
	canvas.draw_line(center - Vector2(size, 0.0), center + Vector2(size, 0.0), ray, 1.3)
	canvas.draw_line(center - Vector2(0.0, size), center + Vector2(0.0, size), ray, 1.3)
	var diag: float = size * 0.52
	canvas.draw_line(center - Vector2(diag, diag), center + Vector2(diag, diag), diag_ray, 0.9)
	canvas.draw_line(center - Vector2(diag, -diag), center + Vector2(diag, -diag), diag_ray, 0.9)
	canvas.draw_circle(center, max(1.0, size * 0.34), ray)


# Walk the perimeter of `r` by `dist` pixels (clockwise from the top-left corner).
func _perimeter_point(r: Rect2, dist: float) -> Vector2:
	var w: float = max(1.0, r.size.x)
	var h: float = max(1.0, r.size.y)
	var d: float = fposmod(dist, 2.0 * (w + h))
	if d < w:
		return Vector2(r.position.x + d, r.position.y)
	d -= w
	if d < h:
		return Vector2(r.end.x, r.position.y + d)
	d -= h
	if d < w:
		return Vector2(r.end.x - d, r.end.y)
	d -= w
	return Vector2(r.position.x, r.end.y - d)


# Per-card description columns (2026-07-09 request): instead of one shared panel
# that only shows the selected/hovered perk, every perk's description is laid out
# at once in a column directly under its own card. The selected card's column is
# brighter. Wrapped lines are cached and only recomputed when the choice set or
# card width changes (the modal redraws every frame for its animation).
func _draw_per_card_descriptions(canvas: CanvasItem, runtime_state: Object, choices: Array, selected_index: int, layout: Dictionary, animation_time: float) -> void:
	if choices.is_empty():
		return
	var alpha: float = clamp(animation_time / 0.3, 0.0, 1.0)
	if alpha <= 0.001:
		return
	var card_size: Vector2 = _get_vector2(layout.get("card_size", Vector2(250.0, 126.0)))
	var cards_start: Vector2 = _get_vector2(layout.get("cards_start", Vector2.ZERO))
	var card_gap: float = float(layout.get("card_gap", 16.0))
	var desc_rect: Rect2 = _get_rect2(layout.get("desc_rect", Rect2()))
	if card_size.x <= 0.0 or desc_rect.size.y <= 0.0:
		return
	_ensure_card_desc_cache(choices, card_size.x, runtime_state, desc_rect.size.y)
	for i in range(min(choices.size(), _card_desc_cache.size())):
		var choice: Dictionary = _get_dict(choices[i])
		if bool(choice.get("reward_pick_spent", false)) or bool(choice.get("start_card_absorbing", false)):
			continue
		var col_x: float = cards_start.x + float(i) * (card_size.x + card_gap)
		var block := Rect2(Vector2(col_x, desc_rect.position.y), Vector2(card_size.x, desc_rect.size.y))
		_draw_card_description_block(canvas, choice, _get_dict(_card_desc_cache[i]), block, i == selected_index, alpha)


func _draw_card_description_block(canvas: CanvasItem, choice: Dictionary, cached: Dictionary, rect: Rect2, selected: bool, alpha: float) -> void:
	var icon_color: Color = _get_color(choice.get("icon_color", Color.WHITE))
	var accent_lines: Array = _get_array(cached.get("accent_lines", []))
	var body_lines: Array = _get_array(cached.get("body_lines", []))
	var accent_segment_lines: Array = _get_array(cached.get("accent_segment_lines", []))
	var body_segment_lines: Array = _get_array(cached.get("body_segment_lines", []))
	var font_size: int = int(cached.get("font_size", 14))
	var line_h: float = float(font_size + 4)
	var box := Rect2(rect.position + Vector2(14.0, 3.0), rect.size - Vector2(28.0, 6.0))
	if selected:
		canvas.draw_rect(box, Color(188.0 / 255.0, 143.0 / 255.0, 66.0 / 255.0, 0.055 * alpha))
	var rule_color := Color(94.0 / 255.0, 70.0 / 255.0, 42.0 / 255.0, (0.56 if selected else 0.34) * alpha)
	canvas.draw_line(box.position, Vector2(box.end.x, box.position.y), rule_color, 1.0)
	var seal_center := box.position + Vector2(4.0, 7.0)
	canvas.draw_circle(seal_center, 2.3, Color(icon_color.r, icon_color.g, icon_color.b, 0.60 * alpha))

	var text_x: float = box.position.x + 8.0
	var y: float = box.position.y + float(font_size) + 8.0

	var body_color := Color(CARD_DESCRIPTION_BODY_COLOR.r, CARD_DESCRIPTION_BODY_COLOR.g, CARD_DESCRIPTION_BODY_COLOR.b, 0.96 * alpha)
	var emphasis_color := Color(CARD_DESCRIPTION_EMPHASIS_COLOR.r, CARD_DESCRIPTION_EMPHASIS_COLOR.g, CARD_DESCRIPTION_EMPHASIS_COLOR.b, alpha)
	for line_index in range(accent_lines.size()):
		var segments: Array = (
			_get_array(accent_segment_lines[line_index])
			if line_index < accent_segment_lines.size()
			else RuntimePerkDescriptionEmphasis.split_segments(str(accent_lines[line_index]))
		)
		_draw_card_description_segments(canvas, segments, Vector2(text_x, y), font_size, body_color, emphasis_color)
		y += line_h

	if not body_lines.is_empty():
		if not accent_lines.is_empty():
			y += 2.0
		for line_index in range(body_lines.size()):
			var segments: Array = (
				_get_array(body_segment_lines[line_index])
				if line_index < body_segment_lines.size()
				else RuntimePerkDescriptionEmphasis.split_segments(str(body_lines[line_index]))
			)
			_draw_card_description_segments(canvas, segments, Vector2(text_x, y), font_size, body_color, emphasis_color)
			y += line_h


func _draw_card_description_segments(
	canvas: CanvasItem,
	segments: Array,
	baseline: Vector2,
	font_size: int,
	body_color: Color,
	emphasis_color: Color
) -> void:
	var font := _get_font()
	if font == null:
		return
	var x := baseline.x
	for segment_value in segments:
		if not (segment_value is Dictionary):
			continue
		var segment := segment_value as Dictionary
		var text := str(segment.get("text", ""))
		if text == "":
			continue
		var color := emphasis_color if bool(segment.get("emphasized", false)) else body_color
		canvas.draw_string(font, Vector2(x, baseline.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
		x += _get_text_size(font, text, font_size).x


# Rebuilds the wrapped description lines only when the choice set or card width
# changes; the per-frame draw path then just blits the cached lines.
#
# Layout intent (2026-07-09 readability pass): the card already shows the name and
	# the 경지/비급/즉시/골드 tag, so the description column does NOT repeat them. It shows
# at most two tiers:
#  - accent = the numeric effect (`description`), highlighted, ONLY for scaling perks
	#    where the number is the point (성급-tagged). Unlock/instant/gold perks skip it
#    because their `description` just restates the card name ("빙혼비격 초식 비급").
#  - body = the friendly `detail` sentence. Falls back to `description` when `detail`
#    is absent or collapses to the same text (the non-Korean locale summary case).
func _ensure_card_desc_cache(
	choices: Array,
	card_width: float,
	runtime_state: Object = null,
	description_height: float = -1.0
) -> void:
	var signature: int = hash([
		hash(choices),
		int(round(card_width)),
		int(round(description_height)),
		_perk_polish_cache_signature(runtime_state),
	])
	if signature == _card_desc_cache_signature and not _card_desc_cache.is_empty():
		return
	_card_desc_cache_signature = signature
	_card_desc_cache = []
	var inner_width: float = max(20.0, card_width - 44.0)
	var compact_many_cards: bool = choices.size() >= 5 and card_width < 160.0
	# S2 keeps the normal 18px target, but a single exhaustive mechanics card
	# (사독귀일) needs the established compact-card 10px floor to retain every row.
	# The catalog seal records which entries reach this floor across all locales.
	var minimum_font_size := 10
	var description_font_size: int = clampi(int(round(card_width / 16.4)), minimum_font_size, 18)
	var legacy_body_line_limit := 2 if compact_many_cards else 3
	for choice_value in choices:
		var choice: Dictionary = _get_dict(choice_value)
		var description := str(choice.get("description", ""))
		description = LanguageSettings.translate_text(description)
		description = RuntimePerkOverflowDescriptions.append_polish_delta(
			description,
			str(choice.get("id", "")),
			int(choice.get("next_level", choice.get("level", 1))),
			runtime_state
		)
		var detail := LanguageSettings.translate_text(str(choice.get("detail", "")))
		var has_distinct_detail: bool = detail != "" and detail.strip_edges() != description.strip_edges()
		# Training has no Mugong level by contract, but its repeatable stat delta is
		# still the primary card information and must retain the numeric accent.
		var is_scaling: bool = _is_scaling_perk_choice(choice) or bool(choice.get("is_physique_training", false))
		var accent_text := ""
		var body_text := ""
		if is_scaling and has_distinct_detail:
			accent_text = description
			body_text = detail
		elif has_distinct_detail:
			body_text = detail
		else:
			body_text = description
		var fitted: Dictionary = _fit_card_description_text(
			accent_text,
			body_text,
			description_font_size,
			minimum_font_size,
			inner_width,
			description_height,
			legacy_body_line_limit
		)
		var accent_wrap: Dictionary = fitted.get("accent_wrap", _empty_wrap_result())
		var body_wrap: Dictionary = fitted.get("body_wrap", _empty_wrap_result())
		_card_desc_cache.append({
			"font_size": int(fitted.get("font_size", description_font_size)),
			"accent_lines": accent_wrap.get("lines", []),
			"body_lines": body_wrap.get("lines", []),
			"accent_segment_lines": RuntimePerkDescriptionEmphasis.split_lines(accent_wrap.get("lines", [])),
			"body_segment_lines": RuntimePerkDescriptionEmphasis.split_lines(body_wrap.get("lines", [])),
			"source_line_count": int(accent_wrap.get("source_line_count", 0)) + int(body_wrap.get("source_line_count", 0)),
			"appended_line_count": int(accent_wrap.get("appended_line_count", 0)) + int(body_wrap.get("appended_line_count", 0)),
			"discarded_line_count": int(accent_wrap.get("discarded_line_count", 0)) + int(body_wrap.get("discarded_line_count", 0)),
			"discarded_character_count": int(accent_wrap.get("discarded_character_count", 0)) + int(body_wrap.get("discarded_character_count", 0)),
			"required_text_height": float(fitted.get("required_text_height", 0.0)),
			"available_text_height": float(fitted.get("available_text_height", 0.0)),
			"fits_height": bool(fitted.get("fits_height", true)),
		})


func _fit_card_description_text(
	accent_text: String,
	body_text: String,
	preferred_font_size: int,
	minimum_font_size: int,
	inner_width: float,
	description_height: float,
	legacy_body_line_limit: int
) -> Dictionary:
	# Direct helper callers predating S2 do not know the layout rect. Preserve their
	# explicit max-line contract; the production start/reward path always passes it.
	if description_height <= 0.0:
		var legacy_accent := _wrap_text_px_with_budget(accent_text, preferred_font_size, inner_width, 2) if accent_text != "" else _empty_wrap_result()
		var legacy_body := _wrap_text_px_with_budget(body_text, preferred_font_size, inner_width, legacy_body_line_limit)
		return {
			"font_size": preferred_font_size,
			"accent_wrap": legacy_accent,
			"body_wrap": legacy_body,
			"required_text_height": _description_text_height(preferred_font_size, legacy_accent, legacy_body),
			"available_text_height": INF,
			"fits_height": true,
		}
	var available_text_height := maxf(0.0, description_height - 6.0)
	for candidate_font_size in range(preferred_font_size, minimum_font_size - 1, -1):
		var accent_wrap := _wrap_text_px_with_budget(accent_text, candidate_font_size, inner_width, 10000) if accent_text != "" else _empty_wrap_result()
		var body_wrap := _wrap_text_px_with_budget(body_text, candidate_font_size, inner_width, 10000)
		var required_text_height := _description_text_height(candidate_font_size, accent_wrap, body_wrap)
		if required_text_height <= available_text_height:
			return {
				"font_size": candidate_font_size,
				"accent_wrap": accent_wrap,
				"body_wrap": body_wrap,
				"required_text_height": required_text_height,
				"available_text_height": available_text_height,
				"fits_height": true,
			}
	# Keep the full wrapped copy in the cache even when authored text cannot fit at
	# the readability floor. The structural seal will fail on fits_height instead
	# of allowing a silent ellipsis to turn the layout RED into a visual GREEN.
	var floor_accent := _wrap_text_px_with_budget(accent_text, minimum_font_size, inner_width, 10000) if accent_text != "" else _empty_wrap_result()
	var floor_body := _wrap_text_px_with_budget(body_text, minimum_font_size, inner_width, 10000)
	return {
		"font_size": minimum_font_size,
		"accent_wrap": floor_accent,
		"body_wrap": floor_body,
		"required_text_height": _description_text_height(minimum_font_size, floor_accent, floor_body),
		"available_text_height": available_text_height,
		"fits_height": false,
	}


func _description_text_height(font_size: int, accent_wrap: Dictionary, body_wrap: Dictionary) -> float:
	var accent_count := int(accent_wrap.get("appended_line_count", 0))
	var body_count := int(body_wrap.get("appended_line_count", 0))
	if accent_count + body_count <= 0:
		return 0.0
	return (
		float(font_size + 8)
		+ float(accent_count + body_count) * float(font_size + 4)
		+ (2.0 if accent_count > 0 and body_count > 0 else 0.0)
	)


func _perk_polish_cache_signature(runtime_state: Object) -> int:
	if runtime_state == null:
		return 0
	if runtime_state.has_method("get_perk_amplify_multiplier"):
		return int(round(float(runtime_state.call("get_perk_amplify_multiplier", "common_swiftness")) * 10000.0))
	if runtime_state.has_method("_get_perk_amplify_multiplier"):
		return int(round(float(runtime_state.call("_get_perk_amplify_multiplier", "common_swiftness")) * 10000.0))
	return 0


# Width-aware word wrap (the plain _wrap_text is char-count based and would overflow
# the narrow per-card columns). Measures with the cached font metrics.
func _wrap_text_px(text: String, font_size: int, max_px: float, max_lines: int) -> Array:
	return _wrap_text_px_with_budget(text, font_size, max_px, max_lines).get("lines", [])


# GRT-021: description rows used to disappear silently at max_lines. Keep the
# production result and its source/appended/discarded counts together so seals
# can assert the rows that the drawer will actually receive.
func _wrap_text_px_with_budget(
	text: String,
	font_size: int,
	max_px: float,
	max_lines: int,
	font_override: Font = null
) -> Dictionary:
	var font: Font = font_override if font_override != null else _get_font()
	if font == null or text == "" or max_lines <= 0 or max_px <= 4.0:
		return _empty_wrap_result()
	var source_lines: Array = _wrap_text_px_all(font, text, font_size, max_px)
	var appended_lines: Array = source_lines.slice(0, mini(max_lines, source_lines.size()))
	var discarded_line_count: int = maxi(0, source_lines.size() - appended_lines.size())
	var discarded_character_count := 0
	if discarded_line_count > 0:
		for line_index in range(appended_lines.size(), source_lines.size()):
			discarded_character_count += str(source_lines[line_index]).length()
		if not appended_lines.is_empty():
			var unclipped_last := str(appended_lines[appended_lines.size() - 1])
			var clipped_last := _append_clip_ellipsis(font, unclipped_last, font_size, max_px)
			discarded_character_count += maxi(0, unclipped_last.length() - maxi(0, clipped_last.length() - 3))
			appended_lines[appended_lines.size() - 1] = clipped_last
	return {
		"lines": appended_lines,
		"source_line_count": source_lines.size(),
		"appended_line_count": appended_lines.size(),
		"discarded_line_count": discarded_line_count,
		"discarded_character_count": discarded_character_count,
	}


func _empty_wrap_result() -> Dictionary:
	return {
		"lines": [],
		"source_line_count": 0,
		"appended_line_count": 0,
		"discarded_line_count": 0,
		"discarded_character_count": 0,
	}


func _wrap_text_px_all(font: Font, text: String, font_size: int, max_px: float) -> Array:
	var lines: Array = []
	var normalized_text := text.replace("\r\n", "\n").replace("\r", "\n")
	for paragraph_value in normalized_text.split("\n", true):
		var paragraph := str(paragraph_value)
		if paragraph == "":
			lines.append("")
			continue
		lines.append_array(_wrap_text_px_paragraph(font, paragraph, font_size, max_px))
	return lines


func _wrap_text_px_paragraph(font: Font, text: String, font_size: int, max_px: float) -> Array:
	var lines: Array = []
	var current := ""
	for word in text.split(" ", false):
		# A single token wider than the column -- a long word, or a space-less CJK run
		# (Korean/Japanese/Chinese text often has no break spaces at all) -- must be split
		# at the character level, or it overflows the card. Flush the pending line first.
		if _get_text_size(font, word, font_size).x > max_px:
			if current != "":
				lines.append(current)
				current = ""
			for ch in word:
				if current != "" and _get_text_size(font, current + ch, font_size).x > max_px:
					lines.append(current)
					current = ch
				else:
					current += ch
			continue
		var trial: String = word if current == "" else current + " " + word
		if current != "" and _get_text_size(font, trial, font_size).x > max_px:
			lines.append(current)
			current = word
		else:
			current = trial
	if current != "":
		lines.append(current)
	return lines


# 줄 예산을 넘겨 버려진 텍스트가 있으면 마지막 줄에 잘림 표시를 붙인다.
# 표시가 없으면 "좌우로 움직이는 속도가" 처럼 서술어 앞에서 끊긴 조각이
# 완결된 문장처럼 읽히고, 5장 압축 카드에서는 문장 하나가 통째로 사라진 것도
# 화면상 구분되지 않는다(러너는 줄 수만 세므로 씰도 이를 통과시킨다).
func _append_clip_ellipsis(font: Font, line: String, font_size: int, max_px: float) -> String:
	var suffix := "..."
	var trimmed := line.strip_edges(false, true)
	while trimmed != "" and _get_text_size(font, trimmed + suffix, font_size).x > max_px:
		trimmed = trimmed.substr(0, trimmed.length() - 1).strip_edges(false, true)
	if trimmed == "":
		return suffix
	return trimmed + suffix


func _draw_status_panel(
	canvas: CanvasItem,
	runtime_state: Object,
	snapshot: Dictionary,
	catalog: Object,
	rect: Rect2,
	icon_renderer: Object,
	view_size: Vector2 = Vector2.ZERO,
	mouse_pos_override: Variant = null,
	reward_session_id: int = -1,
	reward_hover_preview: Dictionary = {}
) -> void:
	RuntimePerkTraditionalChrome.draw_status_ledger(canvas, rect)

	var levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	var gold: int = int(snapshot.get("gold_from_perks", 0))
	# 배율 기준값은 RuntimePerkChoiceLayout의 원장 기준 높이(142)와 짝이다 --
	# 한쪽만 옮기면 원장 글자 크기가 통째로 달라진다.
	var status_scale: float = clamp(rect.size.y / 142.0, 0.72, 1.32)
	var status_font_size: int = clampi(int(round(13.0 * status_scale)), 11, 17)

	_draw_text(canvas, "◆ 현재 무공", rect.position + Vector2(17.0 * status_scale, 28.0 * status_scale), clampi(int(round(16.0 * status_scale)), 13, 21), Color(220.0 / 255.0, 185.0 / 255.0, 105.0 / 255.0))
	var counter_rect: Rect2 = _get_status_counter_rect(rect)
	RuntimePerkTraditionalChrome.draw_status_counter_board(canvas, counter_rect)
	var counter_x: float = counter_rect.end.x - 10.0 * status_scale
	var counter_step: float = counter_rect.size.y / 4.0
	_draw_text_right(canvas, "선택 대기: %d" % pending, Vector2(counter_x, counter_rect.position.y + counter_step), status_font_size, Color(214.0 / 255.0, 209.0 / 255.0, 185.0 / 255.0))
	_draw_text_right(canvas, "무공 골드: %d" % gold, Vector2(counter_x, counter_rect.position.y + counter_step * 2.0), status_font_size, Color(229.0 / 255.0, 192.0 / 255.0, 107.0 / 255.0))

	var slot_status: Dictionary = _get_dict(snapshot.get("perk_slot_status", {}))
	if (
		slot_status.is_empty()
		and not bool(snapshot.get("perk_slot_status_cached", false))
		and catalog != null
		and catalog.has_method("get_perk_slot_status")
	):
		# 융합 슬롯 환급 반영: runtime_state 자체를 slot context로 관통.
		slot_status = _get_dict(catalog.get_perk_slot_status(levels, runtime_state))
	if not slot_status.is_empty():
		var slot_count: int = int(slot_status.get("count", 0))
		var slot_limit: int = int(slot_status.get("limit", 0))
		if slot_limit > 0:
			var slot_color := Color(151.0 / 255.0, 190.0 / 255.0, 170.0 / 255.0, 0.95)
			if slot_count >= slot_limit:
				slot_color = Color(205.0 / 255.0, 145.0 / 255.0, 82.0 / 255.0, 0.98)
			_draw_text_right(canvas, "슬롯 %d/%d" % [slot_count, slot_limit], Vector2(counter_x, counter_rect.position.y + counter_step * 3.0), status_font_size, slot_color)
			if slot_count >= slot_limit:
				_draw_text_right(canvas, get_full_slot_hint(), Vector2(counter_x, counter_rect.end.y - 7.0), max(9, status_font_size - 2), Color(218.0 / 255.0, 177.0 / 255.0, 111.0 / 255.0, 0.90))

	# Owned perks EXCLUDE active-skill unlocks (fold 후처리에서 제외); they
	# live in the 5-orb skill HUD and do not consume a perk slot. 실경로 fold:
	# 스냅샷의 융합 projection을 소비하는 4인자 빌더가 정본 — 융합 소스 퍽은
	# 개별 아이콘으로 재등장하지 않고 재료쌍 합성 셀 하나로 접힌다.
	var acquired: Array = _build_acquired_perks_for_snapshot(levels, catalog, runtime_state, snapshot)
	var reward_highlight_keys: Array[String] = []
	if reward_session_id >= 0:
		var current_slot_keys := _collect_perk_slot_keys(acquired)
		if reward_session_id != _tower_reward_slot_session_id:
			_tower_reward_slot_session_id = reward_session_id
			_tower_reward_slot_keys = current_slot_keys.duplicate()
			_tower_reward_slot_highlight_keys.clear()
		elif current_slot_keys != _tower_reward_slot_keys:
			_tower_reward_slot_highlight_keys.assign(
				resolve_tower_reward_slot_highlight_keys(
					_tower_reward_slot_keys,
					current_slot_keys
				)
			)
			_tower_reward_slot_keys = current_slot_keys.duplicate()
		reward_highlight_keys = _tower_reward_slot_highlight_keys
	# Full perk-slot grid like the character-info panel (2026-07-09 request): one cell per
	# perk-slot-limit, owned perks filled, the rest drawn as empty slots. 빈칸 산정은
	# acquired.size()가 아니라 프레젠터 공용 조립기를 관통한다 — 슬롯 비소모
	# 퍽(_slot_free_cell)이 빈칸을 잠식하면 카운터(5/7)와 그리드 빈칸 수가
	# 어긋난다(코덱스 v1 P1).
	var slot_limit_for_grid: int = max(1, int(slot_status.get("limit", 6)))
	var grid_entries: Array = _build_status_slot_grid(
		acquired,
		slot_limit_for_grid,
		reward_hover_preview
	)
	var display_slots: int = max(1, grid_entries.size())
	var reward_hover_material_keys: Dictionary = _get_dict(
		reward_hover_preview.get("material_keys", {})
	)
	var reward_hover_fade := (
		training_stat_preview_alpha_at(_get_draw_msec())
		if not reward_hover_preview.is_empty()
		else 0.0
	)

	var mouse_pos: Vector2 = Vector2(-1.0, -1.0)
	if mouse_pos_override is Vector2:
		mouse_pos = mouse_pos_override as Vector2
	elif runtime_state != null and runtime_state.has_method("get_status_hover_mouse_pos"):
		mouse_pos = runtime_state.get_status_hover_mouse_pos()
	var hovered_skill: Dictionary = {}
	var hovered_icon_rect := Rect2()
	var hovered_skill_key := ""

	for idx in range(display_slots):
		var slot_rect: Rect2 = _get_status_slot_rect(rect, idx, display_slots)
		var skill: Dictionary = _get_dict(grid_entries[idx])
		if bool(skill.get("_empty_slot", false)):
			# Empty slot: a recessed talisman board and seal, not a modern plus button.
			RuntimePerkTraditionalChrome.draw_talisman_slot(canvas, slot_rect, false, Color.WHITE)
			RuntimePerkTraditionalChrome.draw_empty_seal(canvas, slot_rect.get_center(), min(slot_rect.size.x, slot_rect.size.y) * 0.22)
			if bool(skill.get("_reward_hover_landing_slot", false)):
				_draw_tower_reward_landing_preview(canvas, slot_rect, reward_hover_fade)
			continue
		var is_mythic: bool = str(skill.get("rarity", "")).to_lower() == "mythic"
		var skill_key := _get_perk_slot_key(skill)
		if slot_rect.has_point(mouse_pos):
			hovered_skill = skill
			hovered_icon_rect = slot_rect
			hovered_skill_key = skill_key
		var color: Color = _get_color(skill.get("icon_color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0)))
		if reward_highlight_keys.has(skill_key):
			var acquire_pulse := 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.008)
			canvas.draw_rect(
				slot_rect.grow(4.0),
				Color(0.96, 0.72, 0.28, 0.48 + 0.24 * acquire_pulse),
				false,
				2.0
			)
		# Mythic: soft gold halo BEHIND the cell only; the interior keeps the normal dark
		# cell so the gold reads as a surround, not a hazy tint (2026-07-09 feedback).
		if is_mythic:
			_draw_mythic_ornament_glow(canvas, slot_rect, 1.0, 0.72)
		var slot_inner: Rect2 = RuntimePerkTraditionalChrome.draw_talisman_slot(canvas, slot_rect, true, color)
		var icon_size: float = min(slot_inner.size.x, slot_inner.size.y * 0.66)
		var icon_rect := Rect2(
			Vector2(slot_inner.get_center().x - icon_size * 0.5, slot_inner.position.y + 2.0),
			Vector2.ONE * icon_size
		)
		_draw_icon(canvas, icon_renderer, skill, icon_rect, 1.0)
		var badge_text: String = get_status_badge_text(skill)
		if badge_text != "":
			var badge: Dictionary = get_status_badge_geometry(slot_rect, badge_text)
			var badge_rect: Rect2 = badge.get("rect", Rect2())
			canvas.draw_rect(badge_rect.grow(1.0), Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.92))
			canvas.draw_rect(badge_rect, Color(188.0 / 255.0, 143.0 / 255.0, 66.0 / 255.0, 0.96))
			_draw_text_centered(
				canvas,
				badge_text,
				badge.get("text_center", badge_rect.get_center()),
				int(badge.get("font_size", 9)),
				Color(42.0 / 255.0, 30.0 / 255.0, 0.0)
			)
		if is_mythic:
			_draw_mythic_ornament_frame(canvas, slot_rect, 1.0, 0.72)
		if reward_hover_material_keys.has(skill_key):
			_draw_tower_reward_material_preview(canvas, slot_rect, reward_hover_fade)

	# Owned-perk hover tooltip (2026-07-09 request): mirrors the character-info perk
	# tooltip -- left = friendly detail, right = "능력치" numeric breakdown. Drawn last
	# so it sits on top of the status row.
	if (
		not hovered_skill.is_empty()
		and _get_perk_slot_key(hovered_skill) == hovered_skill_key
		and view_size.x > 0.0
	):
		_draw_perk_status_tooltip(canvas, hovered_skill, hovered_icon_rect, view_size, runtime_state, icon_renderer)


static func resolve_tower_reward_slot_highlight_keys(
	previous_keys: Array,
	current_keys: Array
) -> Array:
	var previous_set: Dictionary = {}
	for key_value: Variant in previous_keys:
		var key := str(key_value)
		if not key.is_empty():
			previous_set[key] = true
	var result: Array = []
	for key_value: Variant in current_keys:
		var key := str(key_value)
		if not key.is_empty() and not previous_set.has(key) and not result.has(key):
			result.append(key)
	return result


func _resolve_tower_reward_hover_preview(
	choices: Array,
	card_rects: Array,
	mouse_pos: Vector2,
	snapshot: Dictionary
) -> Dictionary:
	var hovered_choice: Dictionary = hovered_tower_reward_preview_choice(
		choices,
		card_rects,
		mouse_pos
	)
	# GRT-043: an idle reward board must stop before even reading the cached slot
	# snapshot. The previous model may remain cached, but it is never drawn after
	# the pointer leaves an eligible card.
	if hovered_choice.is_empty():
		return {}
	var slot_status: Dictionary = _get_dict(snapshot.get("perk_slot_status", {}))
	# Hash the cheap snapshot inputs first. The effective-level projection belongs
	# strictly behind this cache gate, not on every fade-only redraw.
	var signature := hash([
		hovered_choice,
		slot_status,
		_get_dict(snapshot.get("runtime_skill_levels", {})),
		_get_dict(snapshot.get("effective_runtime_skill_levels", {})),
		maxi(0, int(snapshot.get("item_perk_level_bonus", 0))),
		bool(snapshot.get("viper_ignition_aura_active", false)),
	])
	if (
		not _tower_reward_hover_preview_cache_valid
		or signature != _tower_reward_hover_preview_signature
	):
		var landing_level := _resolve_tower_reward_hover_landing_level(
			hovered_choice,
			snapshot
		)
		_tower_reward_hover_preview_cache_valid = true
		_tower_reward_hover_preview_signature = signature
		_tower_reward_hover_preview_build_count += 1
		_tower_reward_hover_preview_model = build_tower_reward_hover_preview(
			hovered_choice,
			slot_status,
			landing_level
		)
	return _tower_reward_hover_preview_model


func _resolve_tower_reward_hover_landing_level(
	hovered_choice: Dictionary,
	snapshot: Dictionary
) -> int:
	var perk_id := str(hovered_choice.get("id", "")).strip_edges()
	var current_level := int(hovered_choice.get("current_level", 0))
	var next_level := int(hovered_choice.get("next_level", current_level + 1))
	if perk_id.is_empty() or next_level <= current_level:
		return next_level
	# Reuse the same pure effective-level projection as the purchased ledger. The
	# reward snapshot already owns every input, so hover adds no catalog/runtime
	# lookup to the draw path.
	var projected_base_levels: Dictionary = _get_dict(
		snapshot.get("runtime_skill_levels", {})
	).duplicate(true)
	projected_base_levels[perk_id] = next_level
	_tower_reward_hover_landing_projection_count += 1
	return maxi(
		0,
		int(_tower_reward_hover_effective_query_surface.project_runtime_skill_level_from_snapshot(
			_tower_reward_hover_effective_levels,
			_get_dict(snapshot.get("runtime_skill_levels", {})),
			_get_dict(snapshot.get("effective_runtime_skill_levels", {})),
			projected_base_levels,
			maxi(0, int(snapshot.get("item_perk_level_bonus", 0))),
			bool(snapshot.get("viper_ignition_aura_active", false)),
			perk_id
		))
	)


static func _tower_reward_hover_slot_cost_increase(choice: Dictionary) -> int:
	var current_level := int(choice.get("current_level", 0))
	var next_level := int(choice.get("next_level", current_level + 1))
	if next_level <= current_level:
		return 0
	return maxi(
		0,
		RuntimePerkCatalog.get_slot_cost_for_level(choice, next_level)
		- RuntimePerkCatalog.get_slot_cost_for_level(choice, current_level)
	)


static func hovered_tower_reward_preview_choice(
	choices: Array,
	card_rects: Array,
	mouse_pos: Vector2
) -> Dictionary:
	for index in range(mini(choices.size(), card_rects.size())):
		var choice_value: Variant = choices[index]
		var rect_value: Variant = card_rects[index]
		if not (choice_value is Dictionary) or not (rect_value is Rect2):
			continue
		if not (rect_value as Rect2).has_point(mouse_pos):
			continue
		var choice := choice_value as Dictionary
		if (
			bool(choice.get("reward_pick_spent", false))
			or not bool(choice.get("reward_pick_enabled", true))
		):
			return {}
		var reward_kind := str(choice.get("reward_pick_kind", ""))
		if reward_kind == "fusion":
			return choice
		if reward_kind != "mugong" and reward_kind != "supreme":
			return {}
		# Most owned upgrades reuse their cells. dash_amplification is the explicit
		# count-per-slot exception, so the hover gate follows canonical slot-cost
		# growth instead of assuming every current_level > 0 choice is slot-neutral.
		if _tower_reward_hover_slot_cost_increase(choice) <= 0:
			return {}
		return choice
	return {}


static func build_tower_reward_hover_preview(
	hovered_choice: Dictionary,
	perk_slot_status: Dictionary,
	landing_level: int = -1
) -> Dictionary:
	var material_keys: Dictionary = {}
	var landing_key_levels: Dictionary = {}
	var reward_kind := str(hovered_choice.get("reward_pick_kind", ""))
	if reward_kind == "fusion":
		var source_value: Variant = hovered_choice.get("eligible_sources", [])
		if source_value is Array:
			for source_id_value: Variant in source_value as Array:
				var source_id := str(source_id_value)
				if not source_id.is_empty():
					material_keys[source_id] = true
		return {
			"material_keys": material_keys,
			"landing_key_levels": landing_key_levels,
			"empty_slot_requests": 0,
			"slot_full": false,
		}
	if reward_kind != "mugong" and reward_kind != "supreme":
		return {}
	var current_level := int(hovered_choice.get("current_level", 0))
	var next_level := int(hovered_choice.get("next_level", current_level + 1))
	var perk_id := str(hovered_choice.get("id", ""))
	var slot_cost_increase := _tower_reward_hover_slot_cost_increase(hovered_choice)
	if perk_id.is_empty() or slot_cost_increase <= 0:
		return {}
	var slot_limit := int(perk_slot_status.get("limit", 0))
	var slot_count := int(perk_slot_status.get("count", 0))
	var slot_full := bool(perk_slot_status.get("is_full", false))
	if slot_limit > 0 and slot_count + slot_cost_increase > slot_limit:
		slot_full = true
	if slot_limit <= 0:
		return {}
	if slot_full:
		# W1 owns the disabled/full explanation. This preview deliberately adds no
		# second warning treatment and leaves the existing ledger hint untouched.
		return {
			"material_keys": material_keys,
			"landing_key_levels": landing_key_levels,
			"empty_slot_requests": 0,
			"slot_full": true,
		}
	landing_key_levels[perk_id] = next_level if landing_level < 0 else landing_level
	return {
		"material_keys": material_keys,
		"landing_key_levels": landing_key_levels,
		"empty_slot_requests": slot_cost_increase,
		"slot_full": false,
	}


static func build_tower_reward_hover_slot_grid(
	acquired: Array,
	slot_limit: int,
	hover_preview: Dictionary
) -> Array:
	var request_count := maxi(0, int(hover_preview.get("empty_slot_requests", 0)))
	var landing_value: Variant = hover_preview.get("landing_key_levels", {})
	if request_count <= 0 or not (landing_value is Dictionary):
		return CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(
			acquired,
			maxi(1, slot_limit)
		)
	var landing_key_levels := landing_value as Dictionary
	# The production interpreter emits one landing identity whose request_count
	# may span multiple cells (dash_amplification). Multiple identities have no
	# defined allocation contract, so fail closed instead of letting the first
	# sorted key starve every later key.
	if landing_key_levels.size() != 1:
		return CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(
			acquired,
			maxi(1, slot_limit)
		)
	var existing_keys: Dictionary = {}
	# This cache survives draw frames, so it must not retain aliases to the
	# caller's live acquired-entry dictionaries. The preview also updates matching
	# cells to their post-purchase level before canonical sorting.
	var preview_acquired: Array = acquired.duplicate(true)
	for entry_value: Variant in acquired:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var entry_key := str(entry.get("_sort_id", entry.get("id", entry.get("skill_id", ""))))
		if not entry_key.is_empty():
			existing_keys[entry_key] = int(existing_keys.get(entry_key, 0)) + 1
	var landing_keys: Array = landing_key_levels.keys()
	landing_keys.sort()
	var inserted_count := 0
	for key_value: Variant in landing_keys:
		if inserted_count >= request_count:
			break
		var landing_key := str(key_value)
		if landing_key.is_empty():
			continue
		var projected_level := int(landing_key_levels.get(key_value, 1))
		var existing_count := int(existing_keys.get(landing_key, 0))
		var matching_cell_index := 0
		for preview_entry_value: Variant in preview_acquired:
			if not (preview_entry_value is Dictionary):
				continue
			var preview_entry := preview_entry_value as Dictionary
			var preview_key := str(
				preview_entry.get("_sort_id", preview_entry.get("id", preview_entry.get("skill_id", "")))
			)
			if preview_key != landing_key:
				continue
			preview_entry["level"] = projected_level
			preview_entry["_slot_cell_index"] = matching_cell_index
			matching_cell_index += 1
		while inserted_count < request_count:
			preview_acquired.append({
				"id": landing_key,
				"_sort_id": landing_key,
				"level": projected_level,
				"_slot_cell_index": existing_count + inserted_count,
				"_empty_slot": true,
				"_reward_hover_landing_slot": true,
			})
			inserted_count += 1
	preview_acquired.sort_custom(sort_tower_reward_hover_perks)
	return CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(
		preview_acquired,
		maxi(1, slot_limit)
	)


static func sort_tower_reward_hover_perks(a: Dictionary, b: Dictionary) -> bool:
	var a_level := int(a.get("level", 0))
	var b_level := int(b.get("level", 0))
	if a_level != b_level:
		return a_level > b_level
	# Fusion cells replace their production identity with a composite draw key
	# after the presenter has already sorted them. Preserve and compare the
	# pre-transform identity so hover order matches the real post-purchase order.
	var a_id := str(a.get("_sort_id", a.get("id", "")))
	var b_id := str(b.get("_sort_id", b.get("id", "")))
	if a_id != b_id:
		return a_id < b_id
	return int(a.get("_slot_cell_index", 0)) < int(b.get("_slot_cell_index", 0))


func get_tower_reward_hover_preview_build_count_for_tests() -> int:
	return _tower_reward_hover_preview_build_count


func get_tower_reward_hover_grid_build_count_for_tests() -> int:
	return _tower_reward_hover_grid_build_count


func get_tower_reward_hover_landing_projection_count_for_tests() -> int:
	return _tower_reward_hover_landing_projection_count


func get_tower_reward_landing_draw_count_for_tests() -> int:
	return _tower_reward_landing_draw_count


func get_tower_reward_material_draw_count_for_tests() -> int:
	return _tower_reward_material_draw_count


func _draw_tower_reward_landing_preview(
	canvas: Object,
	slot_rect: Rect2,
	fade: float
) -> void:
	if fade <= 0.0:
		return
	# Cyan outside ring = the destination that will receive the new Mugong.
	canvas.draw_rect(
		slot_rect.grow(5.0),
		Color(0.22, 0.88, 1.0, 0.92 * fade),
		false,
		2.5
	)
	_tower_reward_landing_draw_count += 1


func _draw_tower_reward_material_preview(
	canvas: Object,
	slot_rect: Rect2,
	fade: float
) -> void:
	if fade <= 0.0:
		return
	# Red inset ring = an owned source that can be consumed. It is deliberately
	# inside the cell, unlike the destination ring, so the two meanings survive
	# desaturation as well as color differences.
	canvas.draw_rect(
		slot_rect.grow(-3.0),
		Color(1.0, 0.32, 0.46, 0.94 * fade),
		false,
		3.0
	)
	_tower_reward_material_draw_count += 1


func _collect_perk_slot_keys(acquired: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in acquired:
		var skill := _get_dict(value)
		var key := _get_perk_slot_key(skill)
		if not key.is_empty():
			result.append(key)
	return result


func _get_perk_slot_key(skill: Dictionary) -> String:
	return str(skill.get("id", skill.get("skill_id", "")))


# 수련장 능력치 패널은 캐릭터 정보창의 10행 정본을 이벤트 시점에만 복제한다.
# 모달 열기와 성공한 수련 직후에 이 함수를 호출하고, draw는 아래의 표시 캐시만
# 읽는다(GRT-017/GRT-028). 따라서 같은 프레임에 값이 갱신되면서도 대기 프레임에는
# 레지스트리 조회나 행 조립이 없다.
func prepare_tower_training_stats_panel(owner: Object, registry: Object) -> Dictionary:
	if owner == null or registry == null:
		return {"prepared": false, "row_count": 0}
	var runtime_state: Object = null
	if registry.has_method("get_cached_instance"):
		var cached_value: Variant = registry.call("get_cached_instance", "runtime_perk_state")
		if cached_value is Object:
			runtime_state = cached_value as Object
	if runtime_state == null and registry.has_method("get_instance"):
		var instance_value: Variant = registry.call("get_instance", "runtime_perk_state")
		if instance_value is Object:
			runtime_state = instance_value as Object
	_tower_training_stats_rows = CharacterInfoOverlayStatsPresenter.build_player_stat_rows(
		owner,
		registry,
		_stats_character_runtime,
		runtime_state,
		null,
		null,
		"",
		[],
		-1,
		null,
		CharacterInfoOverlayState.SPECIAL_GAUGE_MAX,
		CharacterInfoOverlayState.PLAYER_BASE_PADDLE_WIDTH,
		CharacterInfoOverlayState.BASE_ACTIVE_ITEM_SLOT_COUNT,
		CharacterInfoOverlayState.STAT_BUFF_COLOR,
		CharacterInfoOverlayState.STAT_DEBUFF_COLOR,
		true
	)
	CharacterInfoOverlayStatsPresenter.refresh_player_stat_cache(
		_tower_training_stats_rows,
		CharacterInfoOverlayState.STAT_ROW_COUNT,
		true,
		_tower_training_stats_row_cache,
		_tower_training_stats_label_cache,
		_tower_training_stats_value_cache,
		_tower_training_stats_color_cache,
		_tower_training_stats_value_width_cache,
		_tower_training_stats_value_width_text_cache,
		_tower_training_stats_value_width_size_cache,
		_tower_training_stats_value_width_font_id_cache
	)
	_tower_training_stats_prepare_count += 1
	return {
		"prepared": not _tower_training_stats_rows.is_empty(),
		"row_count": _tower_training_stats_rows.size(),
		"prepare_count": _tower_training_stats_prepare_count,
	}


func draw_tower_training_stats_panel(
	canvas: CanvasItem,
	rect: Rect2,
	mouse_pos: Vector2,
	view_size: Vector2,
	icon_renderer: Object = null,
	tooltip_overlay: Object = null
) -> Dictionary:
	if canvas == null or not rect.has_area() or _tower_training_stats_rows.is_empty():
		return {"drawn": false, "visible_row_count": 0}
	var font := _get_font()
	if font == null:
		return {"drawn": false, "visible_row_count": 0}
	var inner := RuntimePerkTraditionalChrome.draw_training_stats_ledger(canvas, rect)
	var row_count := mini(
		CharacterInfoOverlayState.STAT_ROW_COUNT,
		_tower_training_stats_rows.size()
	)
	var visible_capacity := CharacterInfoOverlayStatsPresenter.player_stat_rows_visible_capacity(
		inner,
		row_count
	)
	# Canonical order is also the character-info priority order. If a future
	# viewport cannot hold all rows, draw only the highest-priority prefix with a
	# freshly derived row budget; never enter the presenter's clipping branch.
	var draw_row_count := mini(row_count, visible_capacity)
	_tower_training_stats_hover_row_rects.clear()
	_tower_training_stats_hover_data.clear()
	CharacterInfoOverlayStatsPresenter.draw_cached_player_stat_rows(
		canvas,
		font,
		"플레이어 능력치",
		inner,
		draw_row_count,
		_tower_training_stats_label_cache,
		_tower_training_stats_value_cache,
		_tower_training_stats_color_cache,
		_tower_training_stats_value_width_cache,
		_tower_training_stats_value_width_text_cache,
		_tower_training_stats_value_width_size_cache,
		_tower_training_stats_value_width_font_id_cache,
		CharacterInfoOverlayState.ACCENT_BLUE,
		CharacterInfoOverlayState.TEXT_DIM,
		CharacterInfoOverlayState.OVERLAY_GRID_EMPTY_TEXT,
		CharacterInfoOverlayState.UI_TEXT_SCALE,
		mouse_pos,
		_tower_training_stats_hover_data,
		_tower_training_stats_hover_row_rects
	)
	if (
		not _tower_training_stats_hover_data.is_empty()
		and view_size.x > 0.0
		and tooltip_overlay != null
		and tooltip_overlay.has_method("_draw_tooltip")
	):
		tooltip_overlay._draw_tooltip(
			canvas,
			_tower_training_stats_hover_data,
			mouse_pos,
			view_size,
			font,
			icon_renderer
		)
	return {
		"drawn": true,
		"visible_row_count": draw_row_count,
		"compacted_by_priority": draw_row_count < row_count,
	}


func get_tower_training_stats_snapshot_for_tests() -> Dictionary:
	return {
		"prepare_count": _tower_training_stats_prepare_count,
		"row_count": _tower_training_stats_rows.size(),
		"labels": _tower_training_stats_label_cache.duplicate(),
		"values": _tower_training_stats_value_cache.duplicate(),
		"colors": _tower_training_stats_color_cache.duplicate(),
	}


static func tower_training_stats_visible_capacity(rect: Rect2) -> int:
	var inner := rect.grow(-11.0)
	return CharacterInfoOverlayStatsPresenter.player_stat_rows_visible_capacity(
		inner,
		CharacterInfoOverlayState.STAT_ROW_COUNT
	)


# 하단 능력치 원장(2026-08-06 요청): "어디가 부족한지 보고 수련/무공을 고를 수
# 있게" 캐릭터 정보창의 플레이어 능력치 10행을 퍽 선택 화면 하단에 그대로 싣는다.
# 행 조립기와 드로어는 캐릭터 정보창과 같은 프레젠터를 관통한다 -- 여기서 값을
# 다시 계산하면 두 화면이 갈라진다.
func _draw_stats_band(
	canvas: CanvasItem,
	runtime_state: Object,
	snapshot: Dictionary,
	rect: Rect2,
	view_size: Vector2 = Vector2.ZERO,
	icon_renderer: Object = null,
	mouse_pos_override: Variant = null,
	preview_choices: Array = [],
	preview_card_rects: Array = []
) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if runtime_state == null or not runtime_state.has_method("get_stats_context_registry"):
		return
	var registry: Object = runtime_state.get_stats_context_registry()
	var owner: Object = runtime_state.get_stats_context_owner()
	if registry == null or owner == null:
		return
	var font: Font = _get_font()
	if font == null:
		return
	# 모달 입력 핸들러가 매 motion마다 갱신하는 원시 포인터 -- 무공 슬롯 hover와
	# 같은 소스다.
	var mouse_pos: Vector2 = Vector2(-1.0, -1.0)
	if mouse_pos_override is Vector2:
		mouse_pos = mouse_pos_override as Vector2
	elif runtime_state.has_method("get_status_hover_mouse_pos"):
		mouse_pos = runtime_state.get_status_hover_mouse_pos()
	var hovering: bool = rect.has_point(mouse_pos)
	_refresh_stats_rows(owner, registry, snapshot, hovering)
	if _stats_rows.is_empty():
		return
	var inner: Rect2 = RuntimePerkTraditionalChrome.draw_stats_ledger(canvas, rect)
	_stats_hover_row_rects.clear()
	# _fill_hover_data는 hover된 행이 있을 때만 dict를 덮어쓴다 -- 직접 비우지
	# 않으면 마우스가 띠 밖으로 나가도 지난 프레임 툴팁이 계속 뜬다.
	_stats_hover_data.clear()
	CharacterInfoOverlayStatsPresenter.draw_cached_player_stat_rows(
		canvas,
		font,
		"플레이어 능력치",
		inner,
		CharacterInfoOverlayState.STAT_ROW_COUNT,
		_stats_label_cache,
		_stats_value_cache,
		_stats_color_cache,
		_stats_value_width_cache,
		_stats_value_width_text_cache,
		_stats_value_width_size_cache,
		_stats_value_width_font_id_cache,
		CharacterInfoOverlayState.ACCENT_BLUE,
		CharacterInfoOverlayState.TEXT_DIM,
		CharacterInfoOverlayState.OVERLAY_GRID_EMPTY_TEXT,
		CharacterInfoOverlayState.UI_TEXT_SCALE,
		mouse_pos,
		_stats_hover_data,
		_stats_hover_row_rects
	)
	var training_preview: Dictionary = _resolve_training_stat_preview(
		runtime_state,
		snapshot,
		owner,
		registry,
		preview_choices,
		preview_card_rects,
		mouse_pos
	)
	if bool(training_preview.get("visible", false)):
		CharacterInfoOverlayStatsPresenter.draw_player_stat_preview_segment(
			canvas,
			inner,
			CharacterInfoOverlayState.STAT_ROW_COUNT,
			int(training_preview.get("row_index", -1)),
			float(training_preview.get("current_fill_ratio", -1.0)),
			float(training_preview.get("projected_fill_ratio", -1.0)),
			CharacterInfoOverlayState.UI_TEXT_SCALE,
			training_stat_preview_alpha_at(_get_draw_msec())
		)
	if not _stats_hover_data.is_empty() and view_size.x > 0.0:
		_draw_stats_row_tooltip(canvas, registry, font, mouse_pos, view_size, icon_renderer)


func _resolve_training_stat_preview(
	runtime_state: Object,
	snapshot: Dictionary,
	owner: Object,
	registry: Object,
	choices: Array,
	card_rects: Array,
	mouse_pos: Vector2
) -> Dictionary:
	var hovered_choice: Dictionary = hovered_training_choice(choices, card_rects, mouse_pos)
	# GRT-043: the expensive production-row projection is strictly hover-gated.
	# Retaining a previous cached model is harmless; it is never drawn after the
	# pointer leaves the card.
	if hovered_choice.is_empty():
		return {}
	var signature := hash([
		hovered_choice,
		snapshot.get("runtime_skill_levels", {}),
		snapshot.get("item_perk_level_bonus", 0),
		snapshot.get("physique_training", {}),
		snapshot.get("reward_pick_spent_flags", []),
		_stats_rows_signature,
		owner.get_instance_id() if owner != null else 0,
		registry.get_instance_id() if registry != null else 0,
	])
	if signature != _training_stat_preview_signature:
		_training_stat_preview_signature = signature
		_training_stat_preview_model = _training_stat_preview.build_preview(
			runtime_state,
			hovered_choice,
			owner,
			registry,
			_stats_character_runtime
		)
	return _training_stat_preview_model


static func hovered_training_choice(
	choices: Array,
	card_rects: Array,
	mouse_pos: Vector2
) -> Dictionary:
	for index in range(mini(choices.size(), card_rects.size())):
		var choice_value: Variant = choices[index]
		var rect_value: Variant = card_rects[index]
		if not (choice_value is Dictionary) or not (rect_value is Rect2):
			continue
		if not (rect_value as Rect2).has_point(mouse_pos):
			continue
		var choice := choice_value as Dictionary
		if (
			not bool(choice.get("is_physique_training", false))
			or bool(choice.get("reward_pick_spent", false))
			or not bool(choice.get("reward_pick_enabled", true))
		):
			return {}
		return choice
	return {}


# The projected segment fades in and out on a raised cosine instead of hard
# toggling. The curve is stretched past both rails and clamped so the segment
# still rests at full and at zero for a short beat, which reads as "appears and
# disappears" without the strobe of a square wave.
static func training_stat_preview_alpha_at(draw_msec: int) -> float:
	var cycle: int = maxi(1, TRAINING_STAT_PREVIEW_BLINK_CYCLE_MSEC)
	var phase: float = float(posmod(draw_msec, cycle)) / float(cycle)
	var raised: float = 0.5 + 0.5 * cos(TAU * phase)
	return clampf(raised * TRAINING_STAT_PREVIEW_FADE_GAIN - TRAINING_STAT_PREVIEW_FADE_BIAS, 0.0, 1.0)


static func is_training_stat_preview_visible_at(draw_msec: int) -> bool:
	return training_stat_preview_alpha_at(draw_msec) > 0.5


func set_training_stat_preview_draw_msec_for_tests(draw_msec: int) -> void:
	_draw_time_override_msec = draw_msec


func get_training_stat_preview_build_count_for_tests() -> int:
	return int(_training_stat_preview.build_count)


# 능력치 행 hover 툴팁(설명 + 원인별 증감). 캐릭터 정보창의 툴팁 드로어를 그대로
# 빌려 쓴다 -- 같은 hover_data 계약이라 배선만 하면 두 화면이 픽셀까지 같은
# 툴팁을 그린다. 여기서 별도 드로어를 새로 쓰면 정보창과 서서히 갈라진다.
# 모듈 해석은 hover 프레임에서만 한다: 마우스를 올리지 않으면 조회 자체가 없고,
# 배틀/광장에서는 이미 살아 있는 인스턴스라 캐시 히트로 끝난다.
func _draw_stats_row_tooltip(
	canvas: CanvasItem,
	registry: Object,
	font: Font,
	mouse_pos: Vector2,
	view_size: Vector2,
	icon_renderer: Object
) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var info_overlay: Object = null
	if registry.has_method("get_cached_instance"):
		info_overlay = registry.get_cached_instance("character_info_overlay")
	if info_overlay == null:
		info_overlay = registry.get_instance("character_info_overlay")
	if info_overlay == null or not info_overlay.has_method("_draw_tooltip"):
		return
	info_overlay._draw_tooltip(canvas, _stats_hover_data, mouse_pos, view_size, font, icon_renderer)


# 표시 캐시(아이콘/게이지/툴팁 정적 배열)는 캐릭터 정보창과 공유되므로 매 프레임
# 다시 실어 준다 -- 조립만 시그니처 기반으로 건너뛴다.
func _refresh_stats_rows(owner: Object, registry: Object, snapshot: Dictionary, include_breakdown: bool = false) -> void:
	# include_breakdown은 시그니처의 일부다 -- 빼면 hover 진입 프레임이 캐시
	# 히트로 넘어가 증감 내역이 영원히 비어 있는 채로 굳는다(Lazy Applied-Key
	# Re-Apply Trap과 같은 형태).
	var signature: int = hash([
		snapshot.get("runtime_skill_levels", {}),
		snapshot.get("physique_training", {}),
		snapshot.get("reward_pick_spent_flags", []),
		snapshot.get("pending_skill_choices", 0),
		hash(snapshot.get("current_choices", [])),
		include_breakdown,
	])
	var now_msec: int = _get_draw_msec()
	if (
		_stats_rows.is_empty()
		or signature != _stats_rows_signature
		or now_msec - _stats_rows_built_msec > STATS_BAND_REBUILD_INTERVAL_MSEC
	):
		_stats_rows_signature = signature
		_stats_rows_built_msec = now_msec
		# 소스별 증감 내역은 hover 툴팁 전용이라 마우스가 띠 위에 있을 때만
		# 조립한다(캐릭터 정보창의 hover 게이팅과 같은 이유).
		_stats_rows = CharacterInfoOverlayStatsPresenter.build_player_stat_rows(
			owner,
			registry,
			_stats_character_runtime,
			null,
			null,
			null,
			"",
			[],
			-1,
			null,
			CharacterInfoOverlayState.SPECIAL_GAUGE_MAX,
			CharacterInfoOverlayState.PLAYER_BASE_PADDLE_WIDTH,
			CharacterInfoOverlayState.BASE_ACTIVE_ITEM_SLOT_COUNT,
			CharacterInfoOverlayState.STAT_BUFF_COLOR,
			CharacterInfoOverlayState.STAT_DEBUFF_COLOR,
			include_breakdown
		)
	if _stats_rows.is_empty():
		return
	CharacterInfoOverlayStatsPresenter.refresh_player_stat_cache(
		_stats_rows,
		CharacterInfoOverlayState.STAT_ROW_COUNT,
		false,
		_stats_row_cache,
		_stats_label_cache,
		_stats_value_cache,
		_stats_color_cache,
		_stats_value_width_cache,
		_stats_value_width_text_cache,
		_stats_value_width_size_cache,
		_stats_value_width_font_id_cache
	)


# 성급 금박 명패 문구의 정본.
# - 일반 슬롯 셀(다중 점유)은 셀 개수가 곧 수량이라 명패 없음. 명시적 분류
#   태그가 있는 카운트형 무공은 가짜 성급을 막기 위해 태그를 유지한다.
# - 합일처럼 전용 등급 문구를 가진 계열은 프레젠터가 내려 준 `_level_text`를
#   그대로 쓴다. 여기서 "합일"을 다시 타이핑하면 다국어가 갈라진다.
# - 나머지는 성장 경지(1성 ~ 극성)만. 단일 습득형은 명패를 그리지 않는다.
func get_status_badge_text(skill: Dictionary) -> String:
	if str(skill.get("rank_tag", "")).strip_edges() != "":
		return LanguageSettings.format_mugong_rank(skill, int(skill.get("level", 1)))
	if bool(skill.get("is_slot_cell", false)) or bool(skill.get("_is_slot_cell", false)):
		return ""
	if STATUS_BADGE_TAG_TREES.has(str(skill.get("tree", ""))):
		return str(skill.get("_level_text", "")).strip_edges()
	if int(skill.get("max_level", 1)) <= 1:
		return ""
	return LanguageSettings.format_mugong_level(
		mini(int(skill.get("level", 1)), int(skill.get("max_level", 1))),
		int(skill.get("max_level", 1))
	)


# 성급 금박 명패의 지오메트리 정본 -- 그리기와 봉인 스모크가 같은 함수를 통과한다.
# 명패 높이는 폰트 메트릭(ascent + descent)에서 파생되고, 글자 중심은 잉크 기준으로
# 보정해 넘긴다. `_draw_text_centered`가 baseline = center.y + h * 0.35라는 근사를
# 쓰기 때문에, 박스 중심을 그대로 넘기면 폰트가 커질수록 글자가 아래로 밀린다.
func get_status_badge_geometry(slot_rect: Rect2, badge_text: String) -> Dictionary:
	var font_size: int = max(STATUS_BADGE_MIN_FONT, int(round(slot_rect.size.x * STATUS_BADGE_FONT_RATIO)))
	var metrics: Dictionary = _get_boxed_text_metrics(badge_text, font_size)
	var line_height: float = float(metrics.get("line_height", float(font_size)))
	var badge_h: float = line_height + STATUS_BADGE_VERTICAL_PADDING * 2.0
	var badge_w: float = float(metrics.get("width", 0.0)) + STATUS_BADGE_HORIZONTAL_PADDING * 2.0
	var badge_bottom: float = slot_rect.end.y - max(
		STATUS_BADGE_BOTTOM_MARGIN_MIN,
		slot_rect.size.y * STATUS_BADGE_BOTTOM_MARGIN_RATIO
	)
	var rect := Rect2(
		Vector2(slot_rect.get_center().x - badge_w * 0.5, badge_bottom - badge_h),
		Vector2(badge_w, badge_h)
	)
	return {
		"rect": rect,
		"font_size": font_size,
		"line_height": line_height,
		"text_center": Vector2(rect.get_center().x, rect.get_center().y - float(metrics.get("ink_offset", 0.0))),
	}


# 번역 후 실측한 폭/줄높이와, `_draw_text_centered`의 baseline 근사가 만드는
# "잉크 중심 - 박스 중심" 어긋남을 함께 돌려준다.
func _get_boxed_text_metrics(text: String, font_size: int) -> Dictionary:
	var font: Font = _get_font()
	if font == null:
		return {"width": 0.0, "line_height": float(font_size), "ink_offset": 0.0}
	var translated: String = LanguageSettings.translate_text(text)
	var measured: Vector2 = _get_text_size(font, translated, font_size)
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	return {
		"width": measured.x,
		"line_height": max(measured.y, ascent + descent),
		"ink_offset": measured.y * TEXT_CENTER_BASELINE_RATIO - (ascent - descent) * 0.5,
	}


func _get_status_slot_rect(panel_rect: Rect2, index: int, display_slots: int) -> Rect2:
	var safe_slots: int = max(1, display_slots)
	var icons_left: float = panel_rect.position.x + 18.0
	var counter_width: float = clamp(panel_rect.size.x * 0.20, 136.0, 246.0)
	var counter_col_left: float = panel_rect.end.x - counter_width
	var avail_w: float = max(60.0, counter_col_left - icons_left - 8.0)
	var minimum_gap: float = clamp(panel_rect.size.x * 0.009, 6.0, 10.0)
	var fit_width: float = (avail_w - minimum_gap * float(max(0, safe_slots - 1))) / float(safe_slots)
	# 셀 상한 116 -> 96 (2026-08-06 "퍽 슬롯도 좀더 작게"). 원장 높이가 함께
	# 내려갔으므로 높이 비율은 0.60 -> 0.62로 올려 셀이 원장 안에서 갖는 비중을
	# 유지한다.
	var slot_width_limit: float = minf(96.0, panel_rect.size.y * 0.62)
	var slot_width: float = clamp(fit_width, 34.0, slot_width_limit)
	var gap: float = minimum_gap
	if safe_slots > 1:
		gap = clamp((avail_w - slot_width * float(safe_slots)) / float(safe_slots - 1), minimum_gap, 34.0)
	var row_width: float = slot_width * float(safe_slots) + gap * float(max(0, safe_slots - 1))
	var row_left: float = icons_left + max(0.0, (avail_w - row_width) * 0.5)
	var row_offset: float = clamp(panel_rect.size.y * 0.235, 40.0, 54.0)
	var slot_height: float = clamp(min(panel_rect.size.y - row_offset - 18.0, slot_width * 1.24), 34.0, 124.0)
	var row_y: float = panel_rect.position.y + row_offset
	return Rect2(
		Vector2(row_left + float(index) * (slot_width + gap), row_y),
		Vector2(slot_width, slot_height)
	)


func _get_status_counter_rect(panel_rect: Rect2) -> Rect2:
	var scale: float = clamp(panel_rect.size.y / 142.0, 0.72, 1.32)
	var width: float = clamp(panel_rect.size.x * 0.20 - 16.0, 120.0, 228.0)
	var height: float = clamp(panel_rect.size.y - 30.0 * scale, 86.0, 150.0)
	return Rect2(
		Vector2(panel_rect.end.x - width - 12.0 * scale, panel_rect.position.y + 14.0 * scale),
		Vector2(width, height)
	)


func _perk_stats_for_level(skill: Dictionary, runtime_state: Object = null) -> String:
	var descriptions: Dictionary = _get_dict(skill.get("descriptions", {}))
	if descriptions.is_empty():
		return ""
	var level: int = int(skill.get("level", 1))
	# Effective level may exceed the base cap (transcendent_crown / sage_ring):
	# resolve_stats_text generates the Lv.6+ stat line from the runtime scaling
	# patterns (Korean), falling back to the highest defined level description
	# for unregistered perks and non-Korean locales.
	var stats: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		str(skill.get("id", "")),
		descriptions,
		level,
		runtime_state
	)
	stats = RuntimePerkOverflowDescriptions.append_polish_status(
		stats,
		str(skill.get("id", "")),
		runtime_state
	)
	if stats != "":
		return stats
	var max_level: int = int(skill.get("max_level", 1))
	return str(descriptions.get(max_level, ""))


# Comma-split the numeric stat string into right-panel lines. Returns [] (single
# panel) when the stats are empty or identical to the friendly detail -- the
# non-Korean locale collapse where localize_perk_data rewrites both to one summary.
func _perk_stat_lines(stats: String, detail: String) -> Array:
	var trimmed_stats := stats.strip_edges()
	if trimmed_stats == "" or trimmed_stats == detail.strip_edges():
		return []
	var out: Array = []
	for piece in trimmed_stats.split(",", false):
		var text: String = str(piece).strip_edges()
		if text != "":
			out.append(text)
	return out


# 슬롯 그리드 조립(코덱스 v1 P1): 슬롯 비소모 퍽(_slot_free_cell)은 빈칸
# 산정에서 제외하고 그리드 뒤에 별도 표시한다 — 프레젠터 공용 조립기 재사용
# (acquired.size() 기준 빈칸 계산은 5/7+비소모 1에서 빈칸 1로 어긋난다).
func _build_status_slot_grid(
	acquired: Array,
	slot_limit: int,
	hover_preview: Dictionary = {}
) -> Array:
	var normalized_slot_limit: int = max(1, slot_limit)
	if hover_preview.is_empty():
		return CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(
			acquired,
			normalized_slot_limit
		)
	var signature := hash([
		hash(hover_preview),
		hash(acquired),
		normalized_slot_limit,
	])
	if (
		not _tower_reward_hover_grid_cache_valid
		or signature != _tower_reward_hover_grid_signature
	):
		_tower_reward_hover_grid_cache_valid = true
		_tower_reward_hover_grid_signature = signature
		_tower_reward_hover_grid_build_count += 1
		_tower_reward_hover_grid_entries = build_tower_reward_hover_slot_grid(
			acquired,
			normalized_slot_limit,
			hover_preview
		)
	return _tower_reward_hover_grid_entries


# 우측 능력치 패널 엔트리(코덱스 v1 P2): 일반 퍽은 descriptions[level]
# (overflow 연동) 콤마 분해, 융합/주사위 projection 엔트리는 descriptions
# 사전 없이 단수 description(태그 스탯 라인)으로 오므로 공용 파서
# build_perk_stat_entries로 라우팅해 색·취소선 메타데이터를 보존한다.
func _perk_status_tooltip_stat_entries(skill: Dictionary, runtime_state: Object = null) -> Array:
	var stats := _perk_stats_for_level(skill, runtime_state)
	if stats == "":
		stats = str(skill.get("description", ""))
	return CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(stats, str(skill.get("detail", "")))


func _draw_perk_status_tooltip(
	canvas: CanvasItem,
	skill: Dictionary,
	anchor_rect: Rect2,
	view_size: Vector2,
	runtime_state: Object = null,
	icon_renderer_override: Object = null
) -> void:
	var name := str(skill.get("name", ""))
	var detail := str(skill.get("detail", ""))
	var stats := _perk_stats_for_level(skill, runtime_state)
	var stat_entries: Array = _perk_status_tooltip_stat_entries(skill, runtime_state)
	var left_body: String = detail if detail != "" else stats
	var accent: Color = _get_color(skill.get("icon_color", Color(0.55, 0.72, 1.0)))
	# 단일/카운트형 무공은 성장 경지 대신 "절세무공"/"고유" 태그를 쓴다. 융합/주사위
	# projection 엔트리는 자기 라벨(_level_text: "융합" 등)을
	# 이미 실어 오므로 그것을 우선한다.
	var level_text := str(skill.get("_level_text", ""))
	if level_text == "":
		level_text = LanguageSettings.format_mugong_rank(skill, int(skill.get("level", 1)))
	var fusion_sections: Array = skill.get("fusion_sections", []) as Array
	if str(skill.get("tree", "")) == "fusion" and fusion_sections.size() == 3:
		CharacterInfoOverlayTooltipPresenter.draw_fusion_tooltip(
			canvas,
			{
				"anchor_rect": anchor_rect,
				"tooltip_kind": "fusion",
			},
			anchor_rect.get_center(),
			view_size,
			_get_font(),
			accent,
			name,
			level_text,
			fusion_sections,
			Color(0.86, 0.91, 0.98),
			Color(12.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.97),
			Callable(self, "_draw_status_fusion_text"),
			Callable(self, "_wrap_status_fusion_text"),
			Callable(self, "_status_fusion_subtitle_color"),
			Callable(self, "_draw_status_fusion_icon").bind(icon_renderer_override)
		)
		return

	var pad := 12.0
	var gap := 10.0
	var line_h := 20.0
	var left_w := 300.0
	var body_lines: Array = _wrap_text_px(left_body, 15, left_w - pad * 2.0, 6)
	var left_h: float = 20.0 + 22.0 + (19.0 if level_text != "" else 2.0) + float(body_lines.size()) * line_h + 8.0

	var has_right: bool = not stat_entries.is_empty()
	var right_w := 214.0
	var right_rows: Array = []
	if has_right:
		for entry_value in stat_entries:
			var entry: Dictionary = _get_dict(entry_value)
			var entry_color: Color = _get_color(entry.get("color", Color(0.72, 0.86, 1.0)))
			var entry_strike: bool = bool(entry.get("strikethrough", false))
			for wrapped in _wrap_text_px(str(entry.get("text", "")), 14, right_w - pad * 2.0, 2):
				right_rows.append({
					"text": str(wrapped),
					"color": entry_color,
					"strikethrough": entry_strike,
				})
	var right_h: float = 20.0 + 24.0 + float(right_rows.size()) * line_h + 8.0

	var total_w: float = left_w + (gap + right_w if has_right else 0.0)
	var total_h: float = max(left_h, right_h if has_right else 0.0)

	# Prefer above the icon (the status row sits at the screen bottom); fall below only
	# if there is no room, then clamp inside the view.
	var px: float = anchor_rect.position.x - 6.0
	var py: float = anchor_rect.position.y - total_h - 12.0
	if py < 8.0:
		py = anchor_rect.end.y + 12.0
	px = clamp(px, 8.0, max(8.0, view_size.x - total_w - 8.0))
	py = clamp(py, 8.0, max(8.0, view_size.y - total_h - 8.0))

	# Left panel: name, level, friendly detail.
	var left_rect := Rect2(Vector2(px, py), Vector2(left_w, left_h))
	canvas.draw_rect(left_rect, Color(12.0 / 255.0, 16.0 / 255.0, 28.0 / 255.0, 0.97))
	canvas.draw_rect(left_rect, Color(accent.r, accent.g, accent.b, 0.85), false, 2.0)
	var tx: float = px + pad
	var ty: float = py + 24.0
	_draw_text(canvas, name, Vector2(tx, ty), 16, Color(1.0, 1.0, 1.0))
	ty += 22.0
	if level_text != "":
		_draw_text(canvas, level_text, Vector2(tx, ty), 13, Color(1.0, 0.84, 0.5))
		ty += 19.0
	else:
		ty += 2.0
	for line in body_lines:
		_draw_text(canvas, str(line), Vector2(tx, ty), 15, Color(0.86, 0.91, 0.98))
		ty += line_h

	if not has_right:
		return

	# Right panel: "능력치" numeric breakdown.
	var rx: float = px + left_w + gap
	var right_rect := Rect2(Vector2(rx, py), Vector2(right_w, right_h))
	canvas.draw_rect(right_rect, Color(18.0 / 255.0, 22.0 / 255.0, 40.0 / 255.0, 0.97))
	canvas.draw_rect(right_rect, Color(1.0, 140.0 / 255.0, 70.0 / 255.0, 0.85), false, 2.0)
	_draw_text(canvas, "능력치", Vector2(rx + pad, py + 24.0), 14, Color(1.0, 215.0 / 255.0, 85.0 / 255.0))
	var ry: float = py + 24.0 + 22.0
	for row_value in right_rows:
		var row: Dictionary = _get_dict(row_value)
		var row_color: Color = _get_color(row.get("color", Color(0.72, 0.86, 1.0)))
		var row_text := str(row.get("text", ""))
		_draw_text(canvas, row_text, Vector2(rx + pad, ry), 14, row_color)
		if bool(row.get("strikethrough", false)):
			# 융합 삭제 옵션 취소선(TAB 툴팁과 동일 메타 보존).
			var strike_w: float = _get_text_size(_get_font(), row_text, 14).x
			canvas.draw_line(Vector2(rx + pad, ry - 4.0), Vector2(rx + pad + strike_w, ry - 4.0), Color(row_color.r, row_color.g, row_color.b, 0.85), 1.2)
		ry += line_h


func _draw_status_fusion_text(
	canvas: CanvasItem,
	_font: Font,
	text: String,
	baseline_x: float,
	baseline_y: float,
	size: int,
	color: Color
) -> void:
	_draw_text(canvas, text, Vector2(baseline_x, baseline_y), size, color)


func _wrap_status_fusion_text(
	_font: Font,
	text: String,
	size: int,
	max_width: float,
	max_lines: int
) -> Array:
	var result: Array = []
	for paragraph_value: Variant in text.split("\n"):
		var remaining := max_lines - result.size()
		if remaining <= 0:
			break
		result.append_array(_wrap_text_px(str(paragraph_value), size, max_width, remaining))
	return result


func _status_fusion_subtitle_color(color: Color) -> Color:
	return Color(color.r, color.g, color.b, 0.95)


func _draw_status_fusion_icon(
	canvas: CanvasItem,
	icon_id: String,
	rect: Rect2,
	icon_renderer_override: Object
) -> bool:
	if icon_renderer_override == null or not icon_renderer_override.has_method("draw_icon"):
		return false
	return bool(icon_renderer_override.draw_icon(canvas, icon_id, rect, 1.0, true))


func _draw_pending_hint(canvas: CanvasItem, snapshot: Dictionary, pos: Vector2, runtime_state: Object, layout_scale: float = 1.0) -> void:
	var selectable: bool = runtime_state.has_method("is_selectable") and bool(runtime_state.is_selectable())
	var text := "마우스 클릭 또는 ← → / Enter 로 선택"
	if not selectable:
		text = "선택지를 불러오는 중"
	var hint_font_size: int = clampi(int(round(13.0 * layout_scale)), 11, 17)
	var font: Font = _get_font()
	if font != null:
		var text_size: Vector2 = _get_text_size(font, LanguageSettings.translate_text(text), hint_font_size)
		var hint_rect := Rect2(pos - Vector2(text_size.x * 0.5 + 42.0 * layout_scale, 19.0 * layout_scale), Vector2(text_size.x + 84.0 * layout_scale, 34.0 * layout_scale))
		RuntimePerkTraditionalChrome.draw_hint_ribbon(canvas, hint_rect)
	_draw_text_centered(canvas, text, pos, hint_font_size, Color(218.0 / 255.0, 214.0 / 255.0, 193.0 / 255.0, 0.96))
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	if pending > 1:
		_draw_text_centered(canvas, "추가 %d개" % (pending - 1), pos + Vector2(0.0, -22.0 * layout_scale), max(10, hint_font_size - 1), Color(220.0 / 255.0, 185.0 / 255.0, 105.0 / 255.0, 0.95))


func _draw_feedback(canvas: CanvasItem, runtime_state: Object, view_size: Vector2) -> void:
	if runtime_state == null or not runtime_state.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = runtime_state.get_snapshot()
	var timer: float = float(snapshot.get("feedback_timer", 0.0))
	var text: String = str(snapshot.get("feedback_text", ""))
	if timer <= 0.0 or text == "":
		return
	var alpha: float = clamp(timer, 0.0, 1.0)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.20 - (1.0 - alpha) * 16.0)
	var font: Font = _get_font()
	if font == null:
		return
	var size := 18
	var text_size: Vector2 = _get_text_size(font, text, size)
	var bg := Rect2(center - Vector2(text_size.x * 0.5 + 16.0, 22.0), Vector2(text_size.x + 32.0, 34.0))
	canvas.draw_rect(bg, Color(12.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.72 * alpha))
	canvas.draw_rect(bg, Color(1.0, 215.0 / 255.0, 90.0 / 255.0, 0.58 * alpha), false, 1.0)
	canvas.draw_string(font, center - Vector2(text_size.x * 0.5, -5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(1.0, 230.0 / 255.0, 130.0 / 255.0, alpha))


func _draw_mythic_item_effect(canvas: CanvasItem, mythic_item_runtime: Object, view_size: Vector2) -> void:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("draw_activation_effect"):
		mythic_item_runtime.draw_activation_effect(canvas, view_size)


func _draw_particles(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var particles: Array = _get_array(snapshot.get("particles", []))
	var particle_start: int = _recent_start(particles, CHOICE_MODAL_PARTICLE_DRAW_LIMIT)
	for particle_index in range(particle_start, particles.size()):
		var particle_value: Variant = particles[particle_index]
		var particle: Dictionary = _get_dict(particle_value)
		var pos: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		if pos == Vector2.ZERO:
			continue
		var age: float = float(particle.get("age", 0.0))
		var life_ratio: float = clamp(1.0 - age / 1.45, 0.0, 1.0)
		if life_ratio <= 0.0:
			continue
		var color: Color = _get_color(particle.get("color", Color.WHITE))
		var size: float = float(particle.get("size", 3.0))
		if life_ratio >= CHOICE_MODAL_PARTICLE_COMPACT_LIFE_RATIO:
			canvas.draw_circle(pos, size * (1.0 + 0.4 * life_ratio), Color(color.r, color.g, color.b, 0.18 * life_ratio))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.76 * life_ratio))


func _draw_choice_flight_effect(canvas: CanvasItem, effect: Dictionary, icon_renderer: Object) -> void:
	if not bool(effect.get("active", false)):
		return
	var age: float = max(0.0, float(effect.get("age", 0.0)))
	var duration: float = max(0.001, float(effect.get("duration", 1.86)))
	var progress: float = clamp(age / duration, 0.0, 1.0)
	var source: Vector2 = _get_vector2(effect.get("source_pos", Vector2.ZERO))
	var target: Vector2 = _get_vector2(effect.get("target_pos", Vector2.ZERO))
	if source == Vector2.ZERO or target == Vector2.ZERO:
		return
	var color: Color = _get_color(effect.get("icon_color", Color(0.45, 0.75, 1.0)))
	var pulse: float = 0.5 + 0.5 * sin(float(_get_draw_msec()) * 0.018)
	_draw_choice_flight_source_card_fade(canvas, _get_rect2(effect.get("source_rect", Rect2())), color, progress)
	_draw_choice_flight_source_burst(canvas, source, color, progress, pulse)
	_draw_choice_flight_particles(canvas, source, target, effect, color, age)
	_draw_choice_flight_core(canvas, source, target, effect, icon_renderer, color, age, duration, pulse)
	_draw_choice_flight_arrival(canvas, target, color, progress, pulse)


func _draw_choice_flight_source_card_fade(canvas: CanvasItem, source_rect: Rect2, color: Color, progress: float) -> void:
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var alpha: float = clamp(progress * 3.0, 0.0, 1.0)
	canvas.draw_rect(source_rect.grow(3.0), Color(color.r, color.g, color.b, 0.22 * alpha), false, 2.0)
	canvas.draw_rect(source_rect, Color(4.0 / 255.0, 8.0 / 255.0, 18.0 / 255.0, 0.46 * alpha))


func _draw_choice_flight_source_burst(canvas: CanvasItem, source: Vector2, color: Color, progress: float, pulse: float) -> void:
	var alpha: float = clamp(1.0 - progress * 3.2, 0.0, 1.0)
	if alpha <= 0.0:
		return
	for ring in range(CHOICE_FLIGHT_SOURCE_RING_COUNT):
		var ring_t: float = clamp(progress * 3.0 - float(ring) * 0.18, 0.0, 1.0)
		if ring_t <= 0.0:
			continue
		var radius: float = lerpf(14.0 + float(ring) * 8.0, 74.0 + float(ring) * 12.0, _ease_out_cubic(ring_t))
		canvas.draw_arc(source, radius, 0.0, TAU, FLIGHT_SOURCE_ARC_SEGMENTS, Color(color.r, color.g, color.b, alpha * (0.32 - float(ring) * 0.07)), 2.2)
	canvas.draw_circle(source, 24.0 + pulse * 8.0, Color(color.r, color.g, color.b, alpha * 0.18))


func _draw_choice_flight_particles(canvas: CanvasItem, source: Vector2, target: Vector2, effect: Dictionary, base_color: Color, age: float) -> void:
	var particles: Array = _get_array(effect.get("particles", []))
	var particle_start: int = _recent_start(particles, CHOICE_FLIGHT_PARTICLE_DRAW_LIMIT)
	for particle_index in range(particle_start, particles.size()):
		var value: Variant = particles[particle_index]
		var particle: Dictionary = _get_dict(value)
		var delay: float = float(particle.get("delay", 0.0))
		var duration: float = max(0.001, float(particle.get("duration", 0.75)))
		var t: float = clamp((age - delay) / duration, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var eased: float = _ease_in_out_cubic(t)
		var arc: float = float(particle.get("arc", 64.0))
		var side_offset: float = float(particle.get("side_offset", 0.0)) * float(particle.get("side", 1.0))
		var pos: Vector2 = _choice_flight_bezier(source, target, eased, arc, side_offset)
		var prev_pos: Vector2 = _choice_flight_bezier(source, target, clamp(eased - 0.035, 0.0, 1.0), arc, side_offset)
		var fade: float = sin(t * PI)
		var color: Color = _get_color(particle.get("color", base_color))
		var size: float = float(particle.get("size", 3.0)) * (0.75 + 0.45 * fade)
		canvas.draw_line(prev_pos, pos, Color(color.r, color.g, color.b, 0.32 * fade), max(1.0, size * 0.65))
		canvas.draw_circle(pos, size * 2.3, Color(color.r, color.g, color.b, 0.11 * fade))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.78 * fade))


func _draw_choice_flight_core(
	canvas: CanvasItem,
	source: Vector2,
	target: Vector2,
	effect: Dictionary,
	icon_renderer: Object,
	color: Color,
	age: float,
	duration: float,
	pulse: float
) -> void:
	var core_t: float = clamp((age - 0.10) / max(0.001, duration * 0.76), 0.0, 1.0)
	var eased: float = _ease_out_cubic(core_t)
	var pos: Vector2 = _choice_flight_bezier(source, target, eased, 104.0, 0.0)
	var alpha: float = clamp(sin(clamp(core_t, 0.0, 1.0) * PI) * 1.25, 0.0, 1.0)
	if core_t >= 0.96:
		alpha *= clamp(1.0 - (core_t - 0.96) / 0.04, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var size: float = lerpf(62.0, 34.0, eased) * (1.0 + 0.05 * pulse)
	var rect := Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size))
	canvas.draw_circle(pos, size * 0.72, Color(color.r, color.g, color.b, 0.24 * alpha))
	canvas.draw_arc(pos, size * 0.58, -PI * 0.35 + age * 5.0, PI * 1.55 + age * 5.0, FLIGHT_CORE_ARC_SEGMENTS, Color(1.0, 1.0, 1.0, 0.55 * alpha), 2.2)
	var icon_choice: Dictionary = _get_dict(effect.get("choice", {})).duplicate(true)
	var skill_id: String = str(effect.get("skill_id", ""))
	if skill_id != "":
		icon_choice["id"] = skill_id
	_draw_icon(canvas, icon_renderer, icon_choice, rect.grow(-6.0), alpha)


func _draw_choice_flight_arrival(canvas: CanvasItem, target: Vector2, color: Color, progress: float, pulse: float) -> void:
	var arrival: float = clamp((progress - 0.56) / 0.44, 0.0, 1.0)
	if arrival <= 0.0:
		return
	var settle: float = _ease_out_cubic(arrival)
	for ring in range(CHOICE_FLIGHT_ARRIVAL_RING_COUNT):
		var local_t: float = clamp(arrival - float(ring) * 0.12, 0.0, 1.0)
		if local_t <= 0.0:
			continue
		var radius: float = lerpf(88.0 + float(ring) * 12.0, 22.0 + float(ring) * 5.0, _ease_out_cubic(local_t))
		var alpha: float = (1.0 - local_t) * 0.34 + 0.12
		canvas.draw_arc(target, radius, 0.0, TAU, FLIGHT_ARRIVAL_ARC_SEGMENTS, Color(color.r, color.g, color.b, alpha * (1.0 - float(ring) * 0.18)), 2.4)
	var core_radius: float = lerpf(4.0, 19.0 + pulse * 2.0, settle)
	canvas.draw_circle(target, core_radius * 1.85, Color(color.r, color.g, color.b, 0.16 * settle))
	canvas.draw_circle(target, core_radius, Color(color.r, color.g, color.b, 0.58 * settle))
	canvas.draw_circle(target, max(2.0, core_radius * 0.38), Color(1.0, 1.0, 1.0, 0.78 * settle))


func _choice_flight_bezier(source: Vector2, target: Vector2, t: float, arc: float, side_offset: float) -> Vector2:
	var direction: Vector2 = target - source
	var normal := Vector2.ZERO
	if direction.length() > 0.001:
		normal = Vector2(-direction.y, direction.x).normalized()
	var control: Vector2 = (source + target) * 0.5 + Vector2(0.0, -arc) + normal * side_offset
	var inv: float = 1.0 - t
	return source * inv * inv + control * 2.0 * inv * t + target * t * t


# Starpoint absorption visual. Reads `starpoint_absorption_effect` straight off
# the runtime state's snapshot (rather than recomputing here) because the state
# is responsible for translating playfield -> screen each frame so the target
# tracks the moving paddle. Effect phases:
#   [0.00, 0.85]  star spirals from above-the-head source down into the player
#                 body with a sparkle trail and ease-in acceleration
#   [0.85, 1.00]  arrival burst ring + central flash, alpha fading out
func _draw_starpoint_absorption_effect(canvas: CanvasItem, runtime_state: Object) -> void:
	if canvas == null or runtime_state == null:
		return
	if not runtime_state.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = _get_dict(runtime_state.get_snapshot())
	var effect: Dictionary = _get_dict(snapshot.get("starpoint_absorption_effect", {}))
	if not bool(effect.get("active", false)):
		return
	var age: float = float(effect.get("age", 0.0))
	var duration: float = max(0.001, float(effect.get("duration", 0.7)))
	var progress: float = clamp(age / duration, 0.0, 1.0)
	var source: Vector2 = _get_vector2(effect.get("source_pos", Vector2.ZERO))
	var target: Vector2 = _get_vector2(effect.get("target_pos", Vector2.ZERO))
	if source == Vector2.ZERO or target == Vector2.ZERO:
		# Update hasn't translated the playfield position yet (first frame after
		# trigger before update tick fires, or owner / view_size missing). Skip
		# rendering until coords resolve so we don't draw a star at (0,0).
		return
	var screen_scale: float = max(0.1, float(effect.get("screen_scale", 1.0)))
	var flight_progress: float = clamp(progress / 0.85, 0.0, 1.0)
	# Ease-in acceleration so the star "drops" into the body rather than
	# coasting at constant velocity. Pow(2.0) gives a clean parabolic feel.
	var eased: float = pow(flight_progress, 2.0)
	var center: Vector2 = source.lerp(target, eased)
	# Spiral offset shrinks to zero on arrival. Negative orbit dir for visual
	# rotation feel; radius scales with screen scale so a zoomed-out viewport
	# doesn't drown the spiral.
	var spiral_angle: float = age * 7.0
	var spiral_radius: float = 22.0 * screen_scale * (1.0 - flight_progress)
	var head_pos: Vector2 = center + Vector2(cos(spiral_angle), sin(spiral_angle)) * spiral_radius
	# --- Sparkle trail (deterministic from particles list) ---
	var particles: Array = _get_array(effect.get("particles", []))
	_draw_starpoint_absorption_trail(canvas, source, target, particles, age, flight_progress, screen_scale)
	# --- Main star + outer glow (during flight phase) ---
	if flight_progress < 1.0:
		var star_size: float = (15.0 - flight_progress * 5.0) * screen_scale
		var head_alpha: float = clampf(1.0 - flight_progress * 0.35, 0.0, 1.0)
		# 흡수되는 것은 방금 주운 무혼이므로 필드 드롭과 같은 합성을 그대로 쓴다.
		# 여기서 실루엣을 따로 만들면 같은 보상이 두 모습으로 갈라진다.
		CommonStarpointVisualHost.draw_muhon_fallback(canvas, head_pos, star_size, head_alpha, 1.0, false, age * 6.0)
	# --- Arrival burst (last 15% of effect) ---
	if progress > 0.85:
		var burst_t: float = clamp((progress - 0.85) / 0.15, 0.0, 1.0)
		var burst_radius: float = lerpf(8.0 * screen_scale, 46.0 * screen_scale, _ease_out_cubic(burst_t))
		var burst_alpha: float = (1.0 - burst_t) * 0.85
		canvas.draw_arc(
			target,
			burst_radius,
			0.0,
			TAU,
			STARPOINT_ABSORPTION_ARRIVAL_ARC_SEGMENTS,
			Color(STARPOINT_ABSORPTION_BURST_COLOR.r, STARPOINT_ABSORPTION_BURST_COLOR.g, STARPOINT_ABSORPTION_BURST_COLOR.b, burst_alpha),
			max(1.6, 3.4 * screen_scale * (1.0 - burst_t))
		)
		# Soft inner flash that collapses inward as the burst expands.
		var flash_alpha: float = (1.0 - burst_t) * 0.55
		canvas.draw_circle(target, 18.0 * screen_scale * (1.0 - burst_t * 0.4), Color(STARPOINT_ABSORPTION_CORE_COLOR.r, STARPOINT_ABSORPTION_CORE_COLOR.g, STARPOINT_ABSORPTION_CORE_COLOR.b, flash_alpha))


func _draw_starpoint_absorption_trail(
	canvas: CanvasItem,
	source: Vector2,
	target: Vector2,
	particles: Array,
	age: float,
	flight_progress: float,
	screen_scale: float
) -> void:
	if particles.is_empty():
		return
	# Each particle lags behind the main star by a fixed phase offset so the
	# overall trail looks like a comet tail. Particles ALSO orbit the descending
	# centerline so the trail has a swirling, magical feel rather than a flat
	# line.
	for particle_value in particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var phase: float = float(particle.get("phase", 0.0))
		var radius_seed: float = float(particle.get("radius_seed", 0.5))
		var twinkle_seed: float = float(particle.get("twinkle_seed", 0.5))
		var orbit_dir: float = float(particle.get("orbit_dir", 1.0))
		var lag: float = (radius_seed + 0.15) * 0.18  # 0.027..0.207
		var local_progress: float = clamp(flight_progress - lag, 0.0, 1.0)
		if local_progress <= 0.0:
			continue
		var local_eased: float = pow(local_progress, 2.0)
		var spine: Vector2 = source.lerp(target, local_eased)
		var orbit_angle: float = phase + age * 5.5 * orbit_dir
		var orbit_radius: float = (8.0 + radius_seed * 12.0) * screen_scale * (1.0 - local_progress * 0.7)
		var pos: Vector2 = spine + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
		var twinkle: float = 0.55 + 0.45 * sin(age * 6.0 + twinkle_seed * TAU)
		var size: float = max(1.2, (2.6 - local_progress * 1.2) * screen_scale)
		var alpha: float = clampf((1.0 - local_progress) * 0.85 * twinkle, 0.0, 1.0)
		canvas.draw_circle(pos, size * 2.4, Color(STARPOINT_ABSORPTION_GLOW_COLOR.r, STARPOINT_ABSORPTION_GLOW_COLOR.g, STARPOINT_ABSORPTION_GLOW_COLOR.b, alpha * 0.35))
		canvas.draw_circle(pos, size, Color(STARPOINT_ABSORPTION_CORE_COLOR.r, STARPOINT_ABSORPTION_CORE_COLOR.g, STARPOINT_ABSORPTION_CORE_COLOR.b, alpha))


func _recent_start(values: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return values.size()
	return max(0, values.size() - render_limit)


func _ease_out_cubic(t: float) -> float:
	var inv: float = 1.0 - clamp(t, 0.0, 1.0)
	return 1.0 - inv * inv * inv


func _ease_in_out_cubic(t: float) -> float:
	var clamped: float = clamp(t, 0.0, 1.0)
	if clamped < 0.5:
		return 4.0 * clamped * clamped * clamped
	var f: float = -2.0 * clamped + 2.0
	return 1.0 - f * f * f * 0.5


func _draw_icon(canvas: CanvasItem, icon_renderer: Object, skill: Dictionary, rect: Rect2, alpha: float) -> void:
	var skill_id: String = str(skill.get("icon_id", skill.get("id", "")))
	if icon_renderer != null and icon_renderer.has_method("draw_icon"):
		if bool(icon_renderer.draw_icon(canvas, skill_id, rect, alpha, true)):
			return
	_draw_perk_symbol(canvas, rect, _get_color(skill.get("icon_color", Color.WHITE)), str(skill.get("tree", "")), skill_id, alpha)


func _draw_perk_symbol(canvas: CanvasItem, rect: Rect2, color: Color, tree: String, skill_id: String, alpha: float) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = min(rect.size.x, rect.size.y) * 0.36
	var c := Color(color.r, color.g, color.b, alpha)
	var hi := Color(1.0, 1.0, 1.0, 0.82 * alpha)
	if skill_id == "convert_to_gold":
		canvas.draw_circle(center, radius, Color(1.0, 200.0 / 255.0, 40.0 / 255.0, 0.95 * alpha))
		_draw_text_centered(canvas, "G", center + Vector2(0.0, 2.0), int(radius * 1.35), Color(70.0 / 255.0, 42.0 / 255.0, 0.0, alpha))
	elif skill_id == "mystic_dice":
		# 절차 팔자윷 폴백: PNG 로드가 실패해도 미색 몸체·옻칠 캡·적색
		# 매듭의 3가락 다발로 읽히게 한다. 액티브 아이콘과 같은 실루엣이다.
		var yut_body := Color(0.94, 0.82, 0.56, alpha)
		var yut_cap := Color(0.24, 0.09, 0.035, alpha)
		var yut_outline := Color(0.035, 0.02, 0.012, alpha)
		var yut_cord := Color(0.86, 0.12, 0.09, alpha)
		for yut_spec: Array in [
			[Vector2(-0.54, 0.58), Vector2(0.38, -0.58)],
			[Vector2(-0.34, -0.62), Vector2(0.52, 0.55)],
			[Vector2(-0.64, 0.02), Vector2(0.62, -0.05)],
		]:
			var start_offset: Vector2 = yut_spec[0]
			var finish_offset: Vector2 = yut_spec[1]
			var start: Vector2 = center + start_offset * radius
			var finish: Vector2 = center + finish_offset * radius
			canvas.draw_line(start, finish, yut_outline, maxf(3.8, radius * 0.36), true)
			canvas.draw_line(start, finish, yut_body, maxf(2.4, radius * 0.22), true)
			canvas.draw_circle(start, maxf(1.5, radius * 0.13), yut_cap)
			canvas.draw_circle(finish, maxf(1.5, radius * 0.13), yut_cap)
		canvas.draw_circle(center, maxf(1.7, radius * 0.16), yut_cord)
	elif tree.find("unlock") >= 0:
		canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.36 * alpha))
		canvas.draw_arc(center, radius, -PI * 0.75, PI * 0.75, PERK_UNLOCK_SYMBOL_ARC_SEGMENTS, c, 3.0)
		canvas.draw_line(center + Vector2(-radius * 0.45, 0.0), center + Vector2(radius * 0.45, 0.0), hi, 2.0)
		canvas.draw_line(center + Vector2(0.0, -radius * 0.45), center + Vector2(0.0, radius * 0.45), hi, 2.0)
	elif tree == "dash":
		var points: PackedVector2Array = [
			center + Vector2(-radius * 0.8, radius * 0.5),
			center + Vector2(-radius * 0.1, -radius * 0.8),
			center + Vector2(radius * 0.05, -radius * 0.15),
			center + Vector2(radius * 0.8, -radius * 0.35),
			center + Vector2(radius * 0.05, radius * 0.8),
			center + Vector2(-radius * 0.08, radius * 0.15),
		]
		canvas.draw_colored_polygon(points, c)
		canvas.draw_polyline(points, hi, 1.2, true)
	elif tree == "item":
		canvas.draw_rect(Rect2(center - Vector2(radius * 0.75, radius * 0.52), Vector2(radius * 1.5, radius * 1.05)), Color(c.r, c.g, c.b, 0.72 * alpha))
		canvas.draw_line(center + Vector2(-radius * 0.55, -radius * 0.62), center + Vector2(radius * 0.55, -radius * 0.62), hi, 2.0)
		canvas.draw_line(center + Vector2(0.0, -radius * 0.75), center + Vector2(0.0, radius * 0.55), hi, 1.4)
	else:
		canvas.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.36 * alpha))
		canvas.draw_arc(center, radius, 0.0, TAU, PERK_FALLBACK_SYMBOL_ARC_SEGMENTS, c, 2.4)
		canvas.draw_circle(center, radius * 0.36, hi)


# 런타임 선택 상태 패널이 스냅샷의 접힌 융합 projection을 그대로 소비한다
# (TAB presenter와 같은 fold — 융합 소스 퍽을 개별 셀로 재드로우하지 않고
# 재료쌍 합성 아이콘 키 하나로 라우팅).
func _build_acquired_perks_for_snapshot(levels: Dictionary, catalog: Object, runtime_state: Object, snapshot: Dictionary) -> Array:
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		levels,
		catalog,
		runtime_state,
		snapshot
	)
	# 상태 패널의 아이콘 라우팅은 엔트리 id를 그대로 아이콘 키로 쓴다 —
	# 융합 셀은 재료쌍 합성 키(리비전 포함)로 승격한다(TAB은 id=fusion_id와
	# _draw_id를 분리 유지하는 것과 대비되는 소비자별 계약).
	var filtered: Array = []
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			filtered.append(entry_value)
			continue
		var entry: Dictionary = entry_value as Dictionary
		# 오버레이 "현재 퍽" 계약: 액티브 스킬 해금 퍽(unlocks_skill)은 5-orb
		# 스킬 HUD 소유라 무조건 제외한다 — TAB 프레젠터의 "장착된 해금만
		# 숨김"(equipped lookup) 계약과 다른 소비자별 규칙.
		if str(entry.get("unlocks_skill", "")).strip_edges() != "":
			continue
		# The presenter has already applied the canonical level-desc/id-asc order.
		# Keep that original identity before the status consumer swaps a fusion id
		# for its composite icon key; hover insertion must sort against this value.
		var sort_id := str(entry.get("_sort_id", entry.get("id", "")))
		if not sort_id.is_empty():
			entry["_sort_id"] = sort_id
		var draw_id := str(entry.get("_draw_id", ""))
		if draw_id.begins_with("perk_fusion_pair:"):
			entry["id"] = draw_id
		# 오버레이 상태 패널 계약(dash-token 슬롯 셀 스모크): 셀 플래그를
		# 평면 키(is_slot_cell)로 미러한다 — TAB 프레젠터는 _프리픽스 내부
		# 키(_is_slot_cell)를 쓰는 소비자별 계약.
		if bool(entry.get("_is_slot_cell", false)):
			entry["is_slot_cell"] = true
			entry["slot_cell_index"] = int(entry.get("_slot_cell_index", 0))
			entry["slot_cell_total"] = int(entry.get("_slot_cell_total", 1))
		filtered.append(entry)
	return filtered


# 레거시 3인자 진입점: snapshot 없는 호출을 정본 4인자 fold로 위임한다
# (별도 자체 빌더를 유지하면 projection 미인지 dead 경로가 재발한다).
func _build_acquired_perks(levels: Dictionary, catalog: Object, runtime_state: Object = null) -> Array:
	return _build_acquired_perks_for_snapshot(levels, catalog, runtime_state, {})


func _level_text(choice: Dictionary) -> String:
	var override := str(choice.get("level_text", ""))
	if override != "":
		return override
	if bool(choice.get("is_physique_training", false)):
		return LanguageSettings.translate_text("기초 수련")
	if bool(choice.get("is_gold_conversion", false)):
		return LanguageSettings.translate_text("골드")
	if bool(choice.get("is_instant", false)):
		return LanguageSettings.translate_text("즉시")
	# 호란 화기는 무공 비급이 아니라 노획·개조 병기의 밀조도다(병렬 갈래 계약).
	if bool(choice.get("is_weapon_unlock", false)):
		return LanguageSettings.translate_text("밀조도")
	if bool(choice.get("is_skill_manual", false)):
		return LanguageSettings.translate_text("비급")
	if _shows_character_unlock_badge(choice):
		return LanguageSettings.translate_text("비급")
	# 1회성 무공은 경지 대신 태그 — mythic 레어리티는 "절세무공",
	# 그 외는 "고유". 선택 카드와 획득 패널이 같은
	# 라우팅(LanguageSettings)을 쓴다.
	return LanguageSettings.format_mugong_rank(choice, int(choice.get("next_level", 1)))


func _long_level_text(choice: Dictionary) -> String:
	var override := str(choice.get("long_level_text", ""))
	if override != "":
		return override
	if bool(choice.get("is_physique_training", false)):
		return "  (%s)" % LanguageSettings.translate_text("기초 수련")
	if bool(choice.get("is_gold_conversion", false)):
		return "  (500골드)"
	if bool(choice.get("is_instant", false)):
		return "  (즉시 효과)"
	if bool(choice.get("is_weapon_unlock", false)):
		return "  (%s)" % LanguageSettings.translate_text("화기 밀조도")
	if bool(choice.get("is_skill_manual", false)):
		return "  (%s)" % LanguageSettings.translate_text("초식 비급")
	if _shows_character_unlock_badge(choice):
		return "  (%s)" % LanguageSettings.translate_text("초식 비급")
	if str(choice.get("rank_tag", "")).strip_edges() != "":
		return "  (%s)" % _level_text(choice)
	if not _is_scaling_perk_choice(choice):
		return "  (%s)" % _level_text(choice)
	return "  (%s)" % LanguageSettings.format_mugong_level_transition(
		int(choice.get("current_level", 0)),
		int(choice.get("next_level", 1)),
		int(choice.get("max_level", 1))
	)


func _is_scaling_perk_choice(choice: Dictionary) -> bool:
	return (
		int(choice.get("max_level", 1)) > 1
		and not bool(choice.get("is_gold_conversion", false))
		and not bool(choice.get("is_instant", false))
		and not bool(choice.get("is_skill_manual", false))
		and not _shows_character_unlock_badge(choice)
	)


func _shows_character_unlock_badge(choice: Dictionary) -> bool:
	return int(choice.get("max_level", 1)) <= 1 and str(choice.get("character_restriction", "")) != ""


func _level_color(choice: Dictionary, unique: bool, alpha: float) -> Color:
	if unique:
		return Color(105.0 / 255.0, 67.0 / 255.0, 18.0 / 255.0, alpha)
	if bool(choice.get("is_gold_conversion", false)):
		return Color(92.0 / 255.0, 68.0 / 255.0, 22.0 / 255.0, alpha)
	if bool(choice.get("is_instant", false)):
		return Color(38.0 / 255.0, 100.0 / 255.0, 82.0 / 255.0, alpha)
	# Warm parchment needs a dark ink rank. The previous yellow 1성/2성 sat too
	# close to the hanji luminance and disappeared during play.
	return Color(76.0 / 255.0, 50.0 / 255.0, 28.0 / 255.0, alpha)


func _wrap_text(text: String, max_chars: int, max_lines: int) -> Array:
	var lines: Array = []
	var remaining := text.strip_edges()
	while remaining.length() > max_chars and lines.size() < max_lines:
		lines.append(remaining.substr(0, max_chars))
		remaining = remaining.substr(max_chars).strip_edges()
	if remaining != "" and lines.size() < max_lines:
		lines.append(remaining)
	return lines


static func get_full_slot_hint() -> String:
	# 가득 시 실제 규칙은 '새 슬롯-소모 퍽만 제외'다: flag ON에서는 보유
	# 강화에 더해 비소모 후보(슬롯 확장·해금·즉시·골드·수호령)가 전부 계속
	# 나온다 — 특정 부류만 콕 집는 문구는 실제 후보와 다시 어긋난다.
	if PerkConversionFlags.is_enabled():
		return LanguageSettings.translate_text("강화·비소모 퍽만")
	return LanguageSettings.translate_text("보유 퍽 강화만")


func _draw_text(canvas: CanvasItem, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	text = LanguageSettings.translate_text(text)
	var font: Font = _get_font()
	if font == null or text == "":
		return
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_text_fitted(
	canvas: CanvasItem,
	text: String,
	baseline: Vector2,
	font_size: int,
	color: Color,
	max_width: float,
	min_font_size: int = 10,
	font_override: Font = null
) -> void:
	text = LanguageSettings.translate_text(text)
	var font: Font = font_override if font_override != null else _get_font()
	if font == null or text == "" or max_width <= 0.0:
		return
	var fit: Dictionary = _get_fitted_text(font, text, font_size, min_font_size, max_width)
	var fitted_text: String = str(fit.get("text", ""))
	var fitted_size: int = int(fit.get("font_size", font_size))
	if fitted_text == "":
		return
	canvas.draw_string(font, baseline, fitted_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size, color)


func _draw_text_centered_fitted(
	canvas: CanvasItem,
	text: String,
	center: Vector2,
	font_size: int,
	color: Color,
	max_width: float,
	min_font_size: int = 10
) -> void:
	text = LanguageSettings.translate_text(text)
	var font: Font = _get_font()
	if font == null or text == "" or max_width <= 0.0:
		return
	var fit: Dictionary = _get_fitted_text(font, text, font_size, min_font_size, max_width)
	var fitted_text: String = str(fit.get("text", ""))
	var fitted_size: int = int(fit.get("font_size", font_size))
	var measured: Vector2 = _get_text_size(font, fitted_text, fitted_size)
	canvas.draw_string(font, center - Vector2(measured.x * 0.5, -measured.y * 0.35), fitted_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size, color)


func _draw_text_right(canvas: CanvasItem, text: String, right_baseline: Vector2, font_size: int, color: Color) -> void:
	text = LanguageSettings.translate_text(text)
	var font: Font = _get_font()
	if font == null or text == "":
		return
	var measured: Vector2 = _get_text_size(font, text, font_size)
	canvas.draw_string(font, right_baseline - Vector2(measured.x, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_fitted_text(font: Font, text: String, font_size: int, min_font_size: int, max_width: float) -> Dictionary:
	var cache_key: String = "%d|%d|%d|%d|%s" % [
		font.get_instance_id(),
		font_size,
		min_font_size,
		int(ceil(max_width)),
		text,
	]
	if _text_fit_cache.has(cache_key):
		var cached_fit: Variant = _text_fit_cache[cache_key]
		if cached_fit is Dictionary:
			return cached_fit
	var fitted_size: int = font_size
	while fitted_size > min_font_size and _get_text_size(font, text, fitted_size).x > max_width:
		fitted_size -= 1
	var fitted_text: String = text
	if _get_text_size(font, fitted_text, fitted_size).x > max_width:
		fitted_text = _ellipsize_to_width(font, text, max_width, fitted_size)
	var fit := {
		"text": fitted_text,
		"font_size": fitted_size,
	}
	_store_limited_cache(_text_fit_cache, cache_key, fit, TEXT_FIT_CACHE_LIMIT)
	return fit


func _ellipsize_to_width(font: Font, text: String, max_width: float, font_size: int) -> String:
	var suffix := "..."
	if _get_text_size(font, suffix, font_size).x > max_width:
		return ""
	var output := text
	while output.length() > 0:
		var candidate := output + suffix
		if _get_text_size(font, candidate, font_size).x <= max_width:
			return candidate
		output = output.substr(0, output.length() - 1)
	return suffix


func _draw_text_centered(
	canvas: CanvasItem,
	text: String,
	center: Vector2,
	font_size: int,
	color: Color,
	font_override: Font = null
) -> void:
	text = LanguageSettings.translate_text(text)
	var font: Font = font_override if font_override != null else _get_font()
	if font == null or text == "":
		return
	var size: Vector2 = _get_text_size(font, text, font_size)
	canvas.draw_string(font, center - Vector2(size.x * 0.5, -size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _prepare_text_caches() -> void:
	var font: Font = _get_font()
	var font_id := 0
	if font != null:
		font_id = font.get_instance_id()
	if _text_cache_font_id == font_id:
		return
	_text_cache_font_id = font_id
	_text_fit_cache.clear()
	_text_size_cache.clear()


func _get_tower_node_compact_font(compact_scale: float) -> Font:
	var base := _get_font()
	if base == null:
		return base
	# At the rail's 8-10px Korean size the fallback font can let adjacent
	# syllable boxes touch. Keep the adjustment scoped to compact tower cards;
	# wider cards and every other HUD surface retain the canonical font metrics.
	var spacing := maxi(1, int(round(compact_scale)))
	if (
		_tower_node_compact_font == null
		or _tower_node_compact_font_base != base
		or _tower_node_compact_font_spacing != spacing
	):
		var variation := FontVariation.new()
		variation.base_font = base
		variation.set_spacing(TextServer.SPACING_GLYPH, spacing)
		_tower_node_compact_font = variation
		_tower_node_compact_font_base = base
		_tower_node_compact_font_spacing = spacing
	return _tower_node_compact_font


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key: String = "%d|%d|%s" % [font.get_instance_id(), font_size, text]
	if _text_size_cache.has(cache_key):
		var cached_size: Variant = _text_size_cache[cache_key]
		if cached_size is Vector2:
			return cached_size
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_store_limited_cache(_text_size_cache, cache_key, size, TEXT_SIZE_CACHE_LIMIT)
	return size


func _store_limited_cache(cache: Dictionary, key: String, value: Variant, limit: int) -> void:
	if limit <= 0:
		return
	if not cache.has(key) and cache.size() >= limit:
		var keys: Array = cache.keys()
		if not keys.is_empty():
			cache.erase(keys[0])
	cache[key] = value


func _get_font() -> Font:
	if _fallback_font == null:
		_fallback_font = ThemeDB.fallback_font
	return _fallback_font


func _capture_draw_msec() -> void:
	_draw_now_msec = (
		_draw_time_override_msec
		if _draw_time_override_msec >= 0
		else Time.get_ticks_msec()
	)


func _get_draw_msec() -> int:
	if _draw_time_override_msec >= 0:
		return _draw_time_override_msec
	if _draw_now_msec <= 0:
		return Time.get_ticks_msec()
	return _draw_now_msec


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
