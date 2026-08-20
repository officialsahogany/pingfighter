extends RefCounted

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const Stage1PillarStatusOrbContextBuilder := preload("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const DashTokenBoostFxHost := preload("res://scripts/hud/dash_token_boost_fx_host.gd")
const CommandoFirearmHudRainbowFxHost := preload("res://scripts/hud/commando_firearm_hud_rainbow_fx_host.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const RightPillarPortraitRenderer := preload("res://scripts/hud/right_pillar_portrait_renderer.gd")
const PillarOrbStaticLayerCache := preload("res://scripts/hud/pillar_orb_static_layer_cache.gd")

const COMMANDO_FIREARM_SELECTOR_OFFSET := Vector2(28.0, -64.0)
const GOLD_HUD_MIN_SOURCE_SIZE := Vector2(100.0, 40.0)
const GOLD_HUD_TOP_MARGIN := 8.0
const GOLD_HUD_SIDE_MARGIN := 8.0
const GOLD_HUD_PILLAR_GAP := 12.0
const GOLD_HUD_COIN_SIZE := 28.0
const GOLD_HUD_FONT_SIZE := 24
const GOLD_HUD_MIN_FONT_SIZE := 13
const GOLD_HUD_TEXT_GAP := 8.0
const GOLD_HUD_TEXT_RIGHT_PAD := 12.0
const CURRENCY_HUD_TEXT_OUTLINE_SOURCE_SIZE := 2.0
const CURRENCY_HUD_PAIR_GAP := GOLD_HUD_TEXT_GAP
const CURRENCY_HUD_MIN_CONTENT_RATIO := (
	float(GOLD_HUD_MIN_FONT_SIZE) / float(GOLD_HUD_FONT_SIZE)
)
# 프레임(정적 베젤 스택) 아크 세그먼트는 베이크 완료 전 벡터 폴백에서만 쓰인다.
# 프리미엄 화질은 베이크본(해석적 원호 — 세그먼트 수 무관)이 담당하므로, 폴백은
# stage1_dalji_commando_hud_layout_smoke가 봉인한 예산(<=16 / LOD <=12)을 지킨다.
# (프리미엄 리드로우 7e866bac0가 24/16으로 올리며 이 씰을 깨뜨렸던 것의 해소.)
const SENSOR_FRAME_ARC_SEGMENTS := 16
const SENSOR_FRAME_ARC_SEGMENTS_LOD := 12
const SENSOR_PROGRESS_ARC_SEGMENTS := 16
const SENSOR_PROGRESS_ARC_SEGMENTS_LOD := 12
const SENSOR_READY_WAVE_COUNT := 1
const SENSOR_READY_WAVE_SEGMENTS := 12
const SENSOR_READY_WAVE_SEGMENTS_LOD := 8
# 센서 오브 정적 베젤 스택 팔레트 — 베이크 ops(_build_sensor_bezel_ops)와
# 벡터 폴백(_draw_sensor_bezel_vector)이 공유하는 단일 소스.
const SENSOR_COL_BEZEL := Color(0.22, 0.22, 0.27)
const SENSOR_COL_BEZEL_HI := Color(0.42, 0.42, 0.50)
const SENSOR_COL_BEZEL_LO := Color(0.10, 0.10, 0.14)
const SENSOR_COL_EDGE := Color(0.04, 0.04, 0.06)
const SENSOR_COL_GOLD := Color(0.90, 0.77, 0.47)
const SENSOR_COL_PLATINUM := Color(0.82, 0.84, 0.92)
const SENSOR_COL_TEAL := Color(0.34, 0.78, 0.85)
const SENSOR_COL_WELL := Color(0.05, 0.04, 0.09)
const SENSOR_BEZEL_RIVET_COUNT := 6
const SENSOR_BEZEL_RIVET_COUNT_LOD := 4
const BOOST_FX_HOST_NAME := "DashTokenBoostFxHost"
const COMMANDO_FIREARM_RAINBOW_FX_HOST_NAME := "CommandoFirearmHudRainbowFxHost"

var layout_helper: Object = Stage1PillarUiLayout.new()
var status_context_builder: Object = Stage1PillarStatusOrbContextBuilder.new()
var portrait_renderer: Object = RightPillarPortraitRenderer.new()
var _boost_fx_host_pending: Node = null
var _firearm_rainbow_fx_host_pending: Node = null
var _gold_text_size_cache: Dictionary = {}
var _sensor_static_layer_cache: Object = PillarOrbStaticLayerCache.new()


func build_commando_firearm_panel_state(game_offset: Vector2, game_size: Vector2, context: Dictionary) -> Dictionary:
	var renderer: Object = context.get("commando_firearm_selector_renderer", null)
	if renderer == null or not renderer.has_method("build_panel_state"):
		return {}
	var layout: Dictionary = layout_helper.build_layout(game_offset, game_size, context)
	var scale_factor: float = float(layout["scale_factor"])
	var left_center: Vector2 = layout["left_center"]
	var orb_radius: float = float(layout["orb_radius"])
	var skill_orb_renderer: Object = context.get("skill_orb_renderer", null)
	var skill_orb_context: Dictionary = layout_helper.build_skill_orb_context(context, context.get("pillar_drawer", null))
	var horn_renderer: Object = context.get("horn_strawberry_skill_pillar_renderer", null)
	var horn_context: Dictionary = _get_dict(context.get("horn_strawberry_context", {}))
	if _is_horn_strawberry_skill_hud_active(horn_renderer, horn_context):
		return {}
	if _is_odins_eye_skill_hud_active(context.get("odins_eye_skill_pillar_renderer", null), _get_dict(context.get("odins_eye_context", {}))):
		return {}
	var panel_center: Vector2 = _get_commando_firearm_panel_center(
		left_center,
		orb_radius,
		scale_factor,
		skill_orb_renderer,
		skill_orb_context
	)
	return renderer.build_panel_state(panel_center, scale_factor, context)


func draw(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, time_seconds: float, context: Dictionary) -> void:
	if canvas == null:
		return

	var perf_logger: Object = context.get("battle_perf_logger", null)
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var layout: Dictionary = layout_helper.build_layout(game_offset, game_size, context)
	var scale_factor: float = float(layout["scale_factor"])
	var left_center: Vector2 = layout["left_center"]
	var right_center: Vector2 = layout["right_center"]
	var boss_right_top_center: Vector2 = layout["boss_right_top_center"]
	var orb_radius: float = float(layout["orb_radius"])
	var orb_drawer: Object = context.get("pillar_drawer", null)
	var skill_orb_renderer: Object = context.get("skill_orb_renderer", null)
	var horn_strawberry_skill_renderer: Object = context.get("horn_strawberry_skill_pillar_renderer", null)
	var status_orb_renderer: Object = context.get("status_orb_renderer", null)
	var combo_renderer: Object = context.get("combo_renderer", null)
	var commando_firearm_selector_renderer: Object = context.get("commando_firearm_selector_renderer", null)
	var status_context: Dictionary = _build_status_context(context)
	var hud_lod_scale: float = float(status_context.get("hud_lod_scale", 1.0))
	var static_hud_lod := bool(context.get("pillar_hud_static_lod", false))
	_perf_end(perf_logger, "stage1.pillar_ui.layout", sample_start)

	# Reactive portrait boxes ride the empty band between the boss dash orb (top)
	# and the player dash orb (bottom). Drawn BEFORE the orbs so any near-orb
	# overshoot is painted over by the orbs. Expression keys are computed upstream
	# in stage1_pillar_hud_scene_drawer and read from `context`.
	sample_start = _perf_begin(perf_logger)
	portrait_renderer.draw(canvas, layout, time_seconds, context)
	_perf_end(perf_logger, "stage1.pillar_ui.portrait", sample_start)

	sample_start = _perf_begin(perf_logger)
	var skill_orb_context: Dictionary = layout_helper.build_skill_orb_context(context, orb_drawer)
	var horn_strawberry_context: Dictionary = _get_dict(context.get("horn_strawberry_context", {}))
	var horn_strawberry_hud_active: bool = _is_horn_strawberry_skill_hud_active(
		horn_strawberry_skill_renderer,
		horn_strawberry_context
	)
	var odins_eye_skill_renderer: Object = context.get("odins_eye_skill_pillar_renderer", null)
	var odins_eye_context: Dictionary = _get_dict(context.get("odins_eye_context", {}))
	var odins_eye_hud_active: bool = _is_odins_eye_skill_hud_active(odins_eye_skill_renderer, odins_eye_context)
	var active_skill_orb_renderer: Object = skill_orb_renderer
	if horn_strawberry_hud_active:
		active_skill_orb_renderer = horn_strawberry_skill_renderer
		if horn_strawberry_skill_renderer.has_method("build_skill_orb_context"):
			skill_orb_context = horn_strawberry_skill_renderer.build_skill_orb_context(
				horn_strawberry_context,
				float(context.get("special_gauge", 0.0)),
				orb_drawer,
				skill_orb_context
			)
	elif odins_eye_hud_active:
		# 오딘의 눈 변신(페널티 폼): 일반 캐릭터 오브 클러스터를 어둠의 늪
		# 단일 오브로 대체한다(혼딸기 형제 계약 — 혼딸기 변신이 선순위).
		active_skill_orb_renderer = odins_eye_skill_renderer
		if odins_eye_skill_renderer.has_method("build_skill_orb_context"):
			skill_orb_context = odins_eye_skill_renderer.build_skill_orb_context(
				odins_eye_context,
				float(context.get("special_gauge", 0.0)),
				orb_drawer,
				skill_orb_context
			)
	_perf_end(perf_logger, "stage1.pillar_ui.skill_context", sample_start)
	if active_skill_orb_renderer != null:
		sample_start = _perf_begin(perf_logger)
		active_skill_orb_renderer.draw_underlay(canvas, left_center, orb_radius, scale_factor, skill_orb_context)
		_perf_end(perf_logger, "stage1.pillar_ui.skill_underlay", sample_start)

	if status_orb_renderer != null:
		sample_start = _perf_begin(perf_logger)
		status_orb_renderer.draw_gauge_orb(
			canvas,
			left_center,
			orb_radius,
			time_seconds,
			scale_factor,
			status_context_builder.build_gauge_orb_context(status_context, orb_drawer)
		)
		_perf_end(perf_logger, "stage1.pillar_ui.gauge_orb", sample_start)

	if active_skill_orb_renderer != null:
		sample_start = _perf_begin(perf_logger)
		active_skill_orb_renderer.draw_orbs(canvas, left_center, orb_radius, time_seconds, scale_factor, skill_orb_context)
		_perf_end(perf_logger, "stage1.pillar_ui.skill_orbs", sample_start)

	var skill_cluster_bounds := Rect2()
	if active_skill_orb_renderer != null and active_skill_orb_renderer.has_method("get_cluster_bounds"):
		skill_cluster_bounds = active_skill_orb_renderer.get_cluster_bounds(left_center, orb_radius, scale_factor, skill_orb_context)
	# The hatched lingpet's skill card now rides the Dalji boss skill-card rail
	# (composed in stage1_pillar_hud_scene_drawer._build_lingpet_boss_rail_entry),
	# and the battle-slot list HUD is intentionally hidden in the play screen.

	# Boost / sector / half-ready overlays moved to the GPU shader host. Look up
	# (or lazily create) the host once per frame so player + boss dash share the
	# same slot pool, and bracket the dash orb calls with begin/end_frame so any
	# slot the previous frame used gets hidden if its owner stopped drawing.
	var boost_fx_host: Node = _get_or_create_boost_fx_host(canvas)
	if boost_fx_host != null and boost_fx_host.has_method("begin_frame"):
		boost_fx_host.begin_frame()

	if status_orb_renderer != null:
		sample_start = _perf_begin(perf_logger)
		var player_dash_ctx: Dictionary = status_context_builder.build_dash_orb_context(status_context, orb_drawer)
		player_dash_ctx["boost_fx_host"] = boost_fx_host
		status_orb_renderer.draw_dash_orb(
			canvas,
			right_center,
			orb_radius,
			time_seconds,
			scale_factor,
			player_dash_ctx
		)
		_perf_end(perf_logger, "stage1.pillar_ui.player_dash", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_sensor_cooldown_orb(
		canvas,
		right_center,
		orb_radius,
		time_seconds,
		scale_factor,
		_get_dict(context.get("sensor_context", {})),
		hud_lod_scale,
		static_hud_lod
	)
	_perf_end(perf_logger, "stage1.pillar_ui.sensor", sample_start)

	if status_orb_renderer != null and bool(context.get("boss_dash_visible", true)):
		sample_start = _perf_begin(perf_logger)
		var boss_dash_ctx: Dictionary = status_context_builder.build_boss_dash_orb_context(status_context, orb_drawer)
		boss_dash_ctx["boost_fx_host"] = boost_fx_host
		status_orb_renderer.draw_dash_orb(
			canvas,
			boss_right_top_center,
			orb_radius,
			time_seconds,
			scale_factor,
			boss_dash_ctx
		)
		_perf_end(perf_logger, "stage1.pillar_ui.boss_dash", sample_start)

	if boost_fx_host != null and boost_fx_host.has_method("end_frame"):
		boost_fx_host.end_frame()

	if commando_firearm_selector_renderer != null and not horn_strawberry_hud_active and not odins_eye_hud_active:
		sample_start = _perf_begin(perf_logger)
		var firearm_rainbow_fx_host: Node = _get_or_create_firearm_rainbow_fx_host(canvas)
		if firearm_rainbow_fx_host != null and firearm_rainbow_fx_host.has_method("begin_frame"):
			firearm_rainbow_fx_host.begin_frame()
		_draw_commando_firearm_selector(
			canvas,
			commando_firearm_selector_renderer,
			left_center,
			orb_radius,
			scale_factor,
			active_skill_orb_renderer,
			skill_orb_context,
			context,
			firearm_rainbow_fx_host,
			time_seconds
		)
		if firearm_rainbow_fx_host != null and firearm_rainbow_fx_host.has_method("end_frame"):
			firearm_rainbow_fx_host.end_frame()
		_perf_end(perf_logger, "stage1.pillar_ui.commando_selector", sample_start)
	else:
		_hide_firearm_rainbow_fx_host(canvas)

	if combo_renderer != null:
		sample_start = _perf_begin(perf_logger)
		var combo_rect: Rect2 = layout_helper.build_combo_rect(left_center, scale_factor, skill_cluster_bounds)
		combo_renderer.draw_hud(canvas, context.get("combo_state", null), combo_rect, scale_factor)
		_perf_end(perf_logger, "stage1.pillar_ui.combo", sample_start)
	_perf_end(perf_logger, "stage1.pillar_ui.total", total_start)


func _draw_commando_firearm_selector(
	canvas: CanvasItem,
	renderer: Object,
	left_center: Vector2,
	orb_radius: float,
	scale_factor: float,
	skill_orb_renderer: Object,
	skill_orb_context: Dictionary,
	context: Dictionary,
	firearm_rainbow_fx_host: Node = null,
	time_seconds: float = 0.0
) -> void:
	if renderer == null or not renderer.has_method("draw"):
		return
	var panel_center: Vector2 = _get_commando_firearm_panel_center(
		left_center,
		orb_radius,
		scale_factor,
		skill_orb_renderer,
		skill_orb_context
	)
	# Sync the rainbow fx host BEFORE the panel draw so the additive border
	# quad sits underneath the panel art and the panel frame reads cleanly
	# on top of the glow.
	if firearm_rainbow_fx_host != null and firearm_rainbow_fx_host.has_method("sync_panel") and renderer.has_method("build_panel_state"):
		var panel_state: Dictionary = renderer.build_panel_state(panel_center, scale_factor, context)
		if not panel_state.is_empty() and bool(panel_state.get("hud_highlight_active", false)):
			var panel_rect: Rect2 = panel_state.get("rect", Rect2())
			var ratio: float = float(panel_state.get("hud_highlight_ratio", 0.0))
			var highlight_state: Dictionary = panel_state.get("hud_highlight_state", {})
			var weapon_id: String = str(highlight_state.get("weapon_id", panel_state.get("current_weapon_id", "")))
			firearm_rainbow_fx_host.sync_panel(panel_rect, ratio, weapon_id, time_seconds)
	renderer.draw(canvas, panel_center, scale_factor, context)


func build_currency_hud_layout(
	game_offset: Vector2,
	game_size: Vector2,
	context: Dictionary = {}
) -> Dictionary:
	var scale_factor: float = _get_gold_hud_scale(game_size, context)
	var gold_text: String = format_gold_amount(int(context.get("gold_hud_amount", 0)))
	var gold_size: Vector2 = _build_currency_hud_item_size(gold_text, scale_factor)
	var wanted_width: float = max(
		gold_size.x,
		GOLD_HUD_MIN_SOURCE_SIZE.x * scale_factor
	)
	var wanted_height: float = GOLD_HUD_MIN_SOURCE_SIZE.y * scale_factor
	var top_margin: float = GOLD_HUD_TOP_MARGIN * scale_factor
	var side_margin: float = GOLD_HUD_SIDE_MARGIN * scale_factor
	var gap: float = GOLD_HUD_PILLAR_GAP * scale_factor
	if not bool(context.get("tower_muhon_hud_visible", false)):
		var rect_x: float
		if game_offset.x >= wanted_width + gap + side_margin:
			rect_x = game_offset.x - wanted_width - gap
		else:
			var max_inside_width: float = max(64.0 * scale_factor, game_size.x - side_margin * 2.0)
			wanted_width = min(wanted_width, max_inside_width)
			rect_x = game_offset.x + side_margin
		return {
			"gold_rect": Rect2(
				Vector2(rect_x, game_offset.y + top_margin),
				Vector2(wanted_width, wanted_height)
			),
			"muhon_rect": Rect2(),
			"content_scale": scale_factor,
			"pair_fits": true,
		}

	var muhon_text: String = format_gold_amount(int(context.get("tower_muhon_hud_amount", 0)))
	var right_edge: float = game_offset.x - gap
	var available_width: float = max(0.0, right_edge - side_margin)
	var content_scale: float = scale_factor
	var muhon_size: Vector2 = _build_currency_hud_item_size(muhon_text, content_scale)
	var pair_gap: float = CURRENCY_HUD_PAIR_GAP * content_scale
	var total_width: float = gold_size.x + pair_gap + muhon_size.x
	if total_width > available_width and total_width > 0.0:
		content_scale = max(
			scale_factor * CURRENCY_HUD_MIN_CONTENT_RATIO,
			content_scale * available_width / total_width
		)
		gold_size = _build_currency_hud_item_size(gold_text, content_scale)
		muhon_size = _build_currency_hud_item_size(muhon_text, content_scale)
		pair_gap = CURRENCY_HUD_PAIR_GAP * content_scale
		total_width = gold_size.x + pair_gap + muhon_size.x
	var pair_height: float = max(gold_size.y, muhon_size.y)
	var group_x: float = right_edge - total_width
	var group_y: float = game_offset.y + top_margin
	return {
		"gold_rect": Rect2(Vector2(group_x, group_y), Vector2(gold_size.x, pair_height)),
		"muhon_rect": Rect2(
			Vector2(group_x + gold_size.x + pair_gap, group_y),
			Vector2(muhon_size.x, pair_height)
		),
		"content_scale": content_scale,
		"pair_fits": total_width <= available_width + 0.01,
	}


func build_gold_hud_rect(game_offset: Vector2, game_size: Vector2, context: Dictionary = {}) -> Rect2:
	var layout: Dictionary = build_currency_hud_layout(game_offset, game_size, context)
	return layout.get("gold_rect", Rect2())


func build_muhon_hud_rect(game_offset: Vector2, game_size: Vector2, context: Dictionary = {}) -> Rect2:
	var layout: Dictionary = build_currency_hud_layout(game_offset, game_size, context)
	return layout.get("muhon_rect", Rect2())


func _build_currency_hud_item_size(text: String, content_scale: float) -> Vector2:
	var font_size: int = max(1, int(round(float(GOLD_HUD_FONT_SIZE) * content_scale)))
	var text_width: float = _get_gold_text_size(text, font_size).x
	var wanted_width: float = max(
		GOLD_HUD_MIN_SOURCE_SIZE.x * content_scale,
		GOLD_HUD_SIDE_MARGIN * content_scale
			+ GOLD_HUD_COIN_SIZE * content_scale
			+ GOLD_HUD_TEXT_GAP * content_scale
			+ text_width
			+ GOLD_HUD_TEXT_RIGHT_PAD * content_scale
	)
	return Vector2(wanted_width, GOLD_HUD_MIN_SOURCE_SIZE.y * content_scale)


func format_gold_amount(amount: int) -> String:
	var raw := str(maxi(0, amount))
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.substr(raw.length() - 3, 3) + formatted
		raw = raw.substr(0, raw.length() - 3)
	return raw + formatted


func draw_gold_hud(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, context: Dictionary) -> void:
	_draw_gold_hud(canvas, game_offset, game_size, context)
	if bool(context.get("tower_muhon_hud_visible", false)):
		_draw_muhon_hud(canvas, game_offset, game_size, context)


func _draw_gold_hud(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, context: Dictionary) -> void:
	if canvas == null:
		return
	var amount: int = int(context.get("gold_hud_amount", 0))
	var text: String = format_gold_amount(amount)
	var layout: Dictionary = build_currency_hud_layout(game_offset, game_size, context)
	var rect: Rect2 = layout.get("gold_rect", Rect2())
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale_factor: float = float(layout.get("content_scale", _get_gold_hud_scale(game_size, context)))

	var coin_size: float = GOLD_HUD_COIN_SIZE * scale_factor
	var coin_center := Vector2(rect.position.x + GOLD_HUD_SIDE_MARGIN * scale_factor + coin_size * 0.5, rect.get_center().y)
	_draw_gold_coin_icon(canvas, coin_center, coin_size, scale_factor)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_left: float = coin_center.x + coin_size * 0.5 + GOLD_HUD_TEXT_GAP * scale_factor
	var max_text_width: float = max(8.0, rect.end.x - text_left - GOLD_HUD_TEXT_RIGHT_PAD * scale_factor)
	var font_size: int = _fit_gold_font_size(font, text, int(round(float(GOLD_HUD_FONT_SIZE) * scale_factor)), max_text_width)
	var text_size: Vector2 = _get_gold_text_size(text, font_size)
	var baseline := Vector2(
		text_left,
		rect.position.y + (rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	)
	var outline_size: int = max(1, int(round(CURRENCY_HUD_TEXT_OUTLINE_SOURCE_SIZE * scale_factor)))
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_size, Color(0.02, 0.015, 0.01, 0.88))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.86, 0.32, 1.0))


func _draw_muhon_hud(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, context: Dictionary) -> void:
	if canvas == null:
		return
	var amount: int = int(context.get("tower_muhon_hud_amount", 0))
	var text: String = format_gold_amount(amount)
	var layout: Dictionary = build_currency_hud_layout(game_offset, game_size, context)
	var rect: Rect2 = layout.get("muhon_rect", Rect2())
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale_factor: float = float(layout.get("content_scale", _get_gold_hud_scale(game_size, context)))

	var icon_size: float = GOLD_HUD_COIN_SIZE * scale_factor
	var icon_center := Vector2(
		rect.position.x + GOLD_HUD_SIDE_MARGIN * scale_factor + icon_size * 0.5,
		rect.get_center().y + icon_size * 0.04
	)
	CommonStarpointVisualHost.draw_muhon_fallback(
		canvas,
		icon_center,
		icon_size * 0.32,
		1.0,
		0.62,
		false,
		0.0
	)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_left: float = icon_center.x + icon_size * 0.5 + GOLD_HUD_TEXT_GAP * scale_factor
	var max_text_width: float = max(8.0, rect.end.x - text_left - GOLD_HUD_TEXT_RIGHT_PAD * scale_factor)
	var font_size: int = _fit_gold_font_size(font, text, int(round(float(GOLD_HUD_FONT_SIZE) * scale_factor)), max_text_width)
	var text_size: Vector2 = _get_gold_text_size(text, font_size)
	var baseline := Vector2(
		text_left,
		rect.position.y + (rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	)
	var outline_size: int = max(1, int(round(CURRENCY_HUD_TEXT_OUTLINE_SOURCE_SIZE * scale_factor)))
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_size, Color(0.02, 0.01, 0.015, 0.90))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.73, 0.34, 1.0))


func _draw_gold_coin_icon(canvas: CanvasItem, center: Vector2, size: float, scale_factor: float) -> void:
	# Clean flat coin: gold rim, gold face, one subtle inner edge ring and a
	# single soft highlight. No drop shadow / busy crescent so it reads tidy at
	# HUD scale.
	var radius: float = max(4.0, size * 0.5)
	canvas.draw_circle(center, radius, Color(0.78, 0.55, 0.14, 1.0))
	canvas.draw_circle(center, max(1.0, radius - 1.8 * scale_factor), Color(1.0, 0.82, 0.26, 1.0))
	canvas.draw_arc(center, max(1.0, radius - 3.0 * scale_factor), 0.0, TAU, 20, Color(0.80, 0.56, 0.16, 0.45), max(1.0, 1.0 * scale_factor), true)
	canvas.draw_circle(center + Vector2(-radius * 0.26, -radius * 0.30), max(1.0, radius * 0.26), Color(1.0, 0.95, 0.66, 0.55))


func _fit_gold_font_size(font: Font, text: String, base_size: int, max_width: float) -> int:
	var size: int = max(GOLD_HUD_MIN_FONT_SIZE, base_size)
	while size > GOLD_HUD_MIN_FONT_SIZE and _get_gold_text_size(text, size).x > max_width:
		size -= 1
	return size


func _get_gold_text_size(text: String, font_size: int) -> Vector2:
	var cache_key := "%s|%d" % [text, font_size]
	var cached: Variant = _gold_text_size_cache.get(cache_key, null)
	if cached is Vector2:
		return cached
	var font: Font = ThemeDB.fallback_font
	var text_size := Vector2(float(text.length() * font_size) * 0.58, float(font_size))
	if font != null:
		text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	if _gold_text_size_cache.size() >= 32:
		_gold_text_size_cache.clear()
	_gold_text_size_cache[cache_key] = text_size
	return text_size


func _get_gold_hud_scale(game_size: Vector2, context: Dictionary) -> float:
	var height: float = max(1.0, float(context.get("height", 750.0)))
	return clamp(game_size.y / height, 0.45, 3.0)


func _get_commando_firearm_panel_center(
	left_center: Vector2,
	orb_radius: float,
	scale_factor: float,
	skill_orb_renderer: Object,
	skill_orb_context: Dictionary
) -> Vector2:
	var cluster_bounds := Rect2()
	if skill_orb_renderer != null and skill_orb_renderer.has_method("get_cluster_bounds"):
		cluster_bounds = skill_orb_renderer.get_cluster_bounds(left_center, orb_radius, scale_factor, skill_orb_context)
	var panel_center := left_center + Vector2(28.0, -180.0) * scale_factor
	if cluster_bounds.size.x > 0.0 and cluster_bounds.size.y > 0.0:
		panel_center = Vector2(
			cluster_bounds.position.x + cluster_bounds.size.x * 0.5,
			cluster_bounds.position.y
		) + COMMANDO_FIREARM_SELECTOR_OFFSET * scale_factor
	return panel_center


func _draw_sensor_cooldown_orb(
	canvas: CanvasItem,
	dash_center: Vector2,
	orb_radius: float,
	time_seconds: float,
	scale_factor: float,
	sensor_context: Dictionary,
	hud_lod_scale: float,
	static_hud_lod: bool = false
) -> void:
	if canvas == null or not _is_sensor_orb_visible(sensor_context):
		return
	var lod_active := hud_lod_scale < 0.85
	var frame_arc_segments := SENSOR_FRAME_ARC_SEGMENTS_LOD if lod_active else SENSOR_FRAME_ARC_SEGMENTS
	var progress_arc_segments := SENSOR_PROGRESS_ARC_SEGMENTS_LOD if lod_active else SENSOR_PROGRESS_ARC_SEGMENTS
	var ready_wave_segments := SENSOR_READY_WAVE_SEGMENTS_LOD if lod_active else SENSOR_READY_WAVE_SEGMENTS
	var sf: float = scale_factor
	var radius: float = max(10.0, orb_radius * 0.42)
	var center := dash_center + Vector2(orb_radius * 0.64, -(orb_radius + radius + 18.0 * sf))
	var progress: float = clamp(float(sensor_context.get("cooldown_progress", 0.0)), 0.0, 1.0)
	var ready: bool = bool(sensor_context.get("ready", false)) and bool(sensor_context.get("enabled", true))
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * 6.0)

	# 프리미엄 팔레트: 건메탈 베젤(상단 밝음/하단 어두운 원통 셰이딩) + 골드/청록/
	# 플래티넘 다층 림 + 오브시디언 웰, 정체성 유지용 광택 보라 젬. (프리미엄 HUD
	# 크롬 정합) 정적 스택 색상은 SENSOR_COL_* 클래스 상수(베이크 ops와 공유).
	var col_glow := Color(0.44, 0.32, 1.0)
	var col_gem := Color(0.58, 0.45, 1.0)
	var col_gem_hi := Color(0.86, 0.80, 1.0)

	var bezel_inner: float = radius * 0.64
	var well_radius: float = radius * 0.60

	# 외곽 글로우(타이트 — 베젤 금속감을 죽이지 않도록). 펄스 알파라 동적 유지.
	var glow_alpha: float = (0.14 if ready else 0.07) + 0.05 * pulse
	canvas.draw_circle(center, radius + 5.0 * sf, Color(col_glow.r, col_glow.g, col_glow.b, glow_alpha))

	# 정적 베젤 스택(본체/셰이딩/림/리벳/웰)은 (radius, sf)당 픽셀 불변이라 1회
	# 베이크 후 블릿 1회로 그린다(~15드로 → 1드로). 텍스처 준비 전에는 기존 벡터
	# 경로로 폴백(빌드는 공유 프레임 예산 안에서 백그라운드 진행 — 히치 없음).
	# 베이크본은 풀퀄리티 지오메트리 1벌을 LOD 상태와 무관하게 공용한다: 정적
	# 형상 bake-once는 풀화질이면서 LOD 삭감 즉시드로보다도 싸다(순이익 —
	# docs/severe_lod_visual_restore_slice_plan.md의 bake 원칙).
	var bezel_key: String = _sensor_bezel_cache_key(radius, sf)
	var bezel_texture: Texture2D = _sensor_static_layer_cache.get_texture(bezel_key)
	if bezel_texture == null and not _sensor_static_layer_cache.is_pending(bezel_key):
		bezel_texture = _sensor_static_layer_cache.request_build(bezel_key, _build_sensor_bezel_ops(radius, sf))
	if bezel_texture != null:
		_sensor_static_layer_cache.draw_centered(canvas, bezel_texture, center)
	else:
		_draw_sensor_bezel_vector(canvas, center, radius, sf, frame_arc_segments, lod_active)

	# 쿨다운 진행 아크(2층: 넓은 딤 베이스 + 얇은 브라이트 톱)
	var end_angle: float = -PI * 0.5 + TAU * progress
	if progress > 0.0:
		canvas.draw_arc(center, well_radius - 1.5 * sf, -PI * 0.5, end_angle, progress_arc_segments, Color(col_gem.r, col_gem.g, col_gem.b, 0.30), max(1.0, 3.2 * sf), true)
		canvas.draw_arc(center, well_radius - 1.5 * sf, -PI * 0.5, end_angle, progress_arc_segments, Color(col_gem_hi.r, col_gem_hi.g, col_gem_hi.b, 0.95), max(1.0, 1.3 * sf), true)
		if progress < 1.0:
			# 진행 아크 헤드(코멧) — 채워지는 방향을 또렷하게
			var head := center + Vector2(cos(end_angle), sin(end_angle)) * (well_radius - 1.5 * sf)
			canvas.draw_circle(head, max(1.0, 1.9 * sf), Color(1.0, 1.0, 1.0, 0.9))

	# 광택 센서 젬(항상 lit) — 베이스 → 하단 내부 반사 → 상단 광택 → 스페큘러
	var core_radius: float = well_radius * (0.44 + 0.10 * progress)
	var gem_bright: float = 0.62 + 0.26 * progress + (0.12 * pulse if ready else 0.0)
	canvas.draw_circle(center, core_radius + 2.5 * sf, Color(col_gem.r, col_gem.g, col_gem.b, 0.22 + 0.16 * progress))
	canvas.draw_circle(center, core_radius, Color(col_gem.r, col_gem.g, col_gem.b, clampf(gem_bright, 0.0, 1.0)))
	canvas.draw_arc(center + Vector2(0.0, core_radius * 0.18), core_radius * 0.70, 0.2, PI - 0.2, 10, Color(col_gem_hi.r, col_gem_hi.g, col_gem_hi.b, 0.5), max(1.0, 1.2 * sf), true)
	canvas.draw_circle(center + Vector2(0.0, -core_radius * 0.16), core_radius * 0.48, Color(col_gem_hi.r, col_gem_hi.g, col_gem_hi.b, 0.5))
	var spec := center + Vector2(-core_radius * 0.30, -core_radius * 0.36)
	canvas.draw_circle(spec, max(1.0, core_radius * 0.20), Color(1.0, 1.0, 1.0, 0.88))

	# 레디 상태: 레이더 스윕(회전 스캔) + 확장 링 — "센서" 정체성 강화
	if ready and not static_hud_lod:
		var sweep_a: float = fmod(time_seconds * 1.5, 1.0) * TAU - PI * 0.5
		var sweep_seg: int = 6 if lod_active else 10
		canvas.draw_arc(center, well_radius - 2.0 * sf, sweep_a, sweep_a + 0.7, sweep_seg, Color(col_gem_hi.r, col_gem_hi.g, col_gem_hi.b, 0.5), max(1.0, 1.5 * sf), true)
		var lead := center + Vector2(cos(sweep_a + 0.7), sin(sweep_a + 0.7)) * (well_radius - 2.0 * sf)
		canvas.draw_circle(lead, max(1.0, 1.5 * sf), Color(1.0, 1.0, 1.0, 0.7))
		for wi in range(SENSOR_READY_WAVE_COUNT):
			var wave_phase: float = fmod(time_seconds * 1.8 + float(wi) * 0.5, 1.0)
			var wave_radius: float = radius * (0.9 + 0.45 * wave_phase)
			var wave_alpha: float = 0.2 * (1.0 - wave_phase)
			canvas.draw_arc(center, wave_radius, 0.0, TAU, ready_wave_segments, Color(col_gem_hi.r, col_gem_hi.g, col_gem_hi.b, wave_alpha), max(1.0, 1.4 * sf), true)


# 센서 베젤 정적 스택 캐시 키. 색은 전부 클래스 상수라 키에 넣지 않는다.
# 지오메트리 입력이 (radius, sf)뿐이므로 창 크기당 1엔트리로 수렴한다.
func _sensor_bezel_cache_key(radius: float, sf: float) -> String:
	return "sensor_bezel:v1:r%.2f:s%.3f" % [radius, sf]


# 센서 베젤 정적 스택의 베이크 ops. _draw_sensor_bezel_vector와 지오메트리
# 1:1 대응(원=해석 채움, AA 아크=해석 페더 밴드)이어야 한다 — 한쪽을 바꾸면
# 반드시 다른 쪽도 함께 바꿀 것. 리벳은 풀퀄리티 6개 고정(베이크본은 LOD
# 무관 공용, 즉시 경로의 LOD 4개 삭감보다 시각 우위·비용 동일).
func _build_sensor_bezel_ops(radius: float, sf: float) -> Array:
	var bezel_inner: float = radius * 0.64
	var well_radius: float = radius * 0.60
	var band_mid: float = (radius + bezel_inner) * 0.5
	var band_w: float = radius - bezel_inner
	var ops: Array = []
	ops.append(PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, radius, SENSOR_COL_BEZEL))
	ops.append(PillarOrbStaticLayerCache.make_arc_band_aa(Vector2.ZERO, band_mid, PI, TAU, max(1.0, band_w), Color(SENSOR_COL_BEZEL_HI.r, SENSOR_COL_BEZEL_HI.g, SENSOR_COL_BEZEL_HI.b, 0.9)))
	ops.append(PillarOrbStaticLayerCache.make_arc_band_aa(Vector2.ZERO, band_mid, 0.0, PI, max(1.0, band_w), Color(SENSOR_COL_BEZEL_LO.r, SENSOR_COL_BEZEL_LO.g, SENSOR_COL_BEZEL_LO.b, 0.9)))
	ops.append(PillarOrbStaticLayerCache.make_arc_band_aa(Vector2.ZERO, radius, 0.0, TAU, max(1.0, 1.2 * sf), SENSOR_COL_EDGE))
	ops.append(PillarOrbStaticLayerCache.make_arc_band_aa(Vector2.ZERO, radius - 1.7 * sf, 0.0, TAU, max(1.0, 1.9 * sf), Color(SENSOR_COL_GOLD.r, SENSOR_COL_GOLD.g, SENSOR_COL_GOLD.b, 0.95)))
	ops.append(PillarOrbStaticLayerCache.make_arc_band_aa(Vector2.ZERO, radius - 4.2 * sf, 0.0, TAU, max(1.0, 1.0 * sf), Color(SENSOR_COL_TEAL.r, SENSOR_COL_TEAL.g, SENSOR_COL_TEAL.b, 0.6)))
	ops.append(PillarOrbStaticLayerCache.make_arc_band_aa(Vector2.ZERO, bezel_inner, 0.0, TAU, max(1.0, 1.5 * sf), Color(SENSOR_COL_PLATINUM.r, SENSOR_COL_PLATINUM.g, SENSOR_COL_PLATINUM.b, 0.85)))
	for ri in range(SENSOR_BEZEL_RIVET_COUNT):
		var ra: float = -PI * 0.5 + float(ri) * TAU / float(SENSOR_BEZEL_RIVET_COUNT)
		var rp := Vector2(cos(ra), sin(ra)) * band_mid
		ops.append(PillarOrbStaticLayerCache.make_circle(rp, max(1.4, 2.1 * sf), Color(0.06, 0.06, 0.08, 0.92)))
		ops.append(PillarOrbStaticLayerCache.make_circle(rp, max(0.8, 1.3 * sf), Color(SENSOR_COL_PLATINUM.r, SENSOR_COL_PLATINUM.g, SENSOR_COL_PLATINUM.b, 0.95)))
	ops.append(PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, well_radius, SENSOR_COL_WELL))
	ops.append(PillarOrbStaticLayerCache.make_arc_band_aa(Vector2(0.0, -well_radius * 0.14), well_radius * 0.84, PI, TAU, max(1.0, well_radius * 0.26), Color(0.0, 0.0, 0.0, 0.45)))
	return ops


# 센서 베젤 정적 스택 벡터 폴백(베이크 완료 전) — 이 슬라이스 이전의 즉시
# 드로우와 지오메트리/LOD 동작 동일(정확성-동일 폴백).
func _draw_sensor_bezel_vector(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	sf: float,
	frame_arc_segments: int,
	lod_active: bool
) -> void:
	var bezel_inner: float = radius * 0.64
	var well_radius: float = radius * 0.60
	var band_mid: float = (radius + bezel_inner) * 0.5
	var band_w: float = radius - bezel_inner

	# 건메탈 베젤 본체 + 밴드 상/하 셰이딩(원통형 브러시드 금속)
	canvas.draw_circle(center, radius, SENSOR_COL_BEZEL)
	canvas.draw_arc(center, band_mid, PI, TAU, frame_arc_segments, Color(SENSOR_COL_BEZEL_HI.r, SENSOR_COL_BEZEL_HI.g, SENSOR_COL_BEZEL_HI.b, 0.9), max(1.0, band_w), true)
	canvas.draw_arc(center, band_mid, 0.0, PI, frame_arc_segments, Color(SENSOR_COL_BEZEL_LO.r, SENSOR_COL_BEZEL_LO.g, SENSOR_COL_BEZEL_LO.b, 0.9), max(1.0, band_w), true)

	# 림 스택: 외곽 다크 엣지 → 골드 → 청록 헤어라인 → 내측 플래티넘
	canvas.draw_arc(center, radius, 0.0, TAU, frame_arc_segments, SENSOR_COL_EDGE, max(1.0, 1.2 * sf), true)
	canvas.draw_arc(center, radius - 1.7 * sf, 0.0, TAU, frame_arc_segments, Color(SENSOR_COL_GOLD.r, SENSOR_COL_GOLD.g, SENSOR_COL_GOLD.b, 0.95), max(1.0, 1.9 * sf), true)
	canvas.draw_arc(center, radius - 4.2 * sf, 0.0, TAU, frame_arc_segments, Color(SENSOR_COL_TEAL.r, SENSOR_COL_TEAL.g, SENSOR_COL_TEAL.b, 0.6), max(1.0, 1.0 * sf), true)
	canvas.draw_arc(center, bezel_inner, 0.0, TAU, frame_arc_segments, Color(SENSOR_COL_PLATINUM.r, SENSOR_COL_PLATINUM.g, SENSOR_COL_PLATINUM.b, 0.85), max(1.0, 1.5 * sf), true)

	# 베젤 리벳(볼트) — 다크 소켓 + 플래티넘 헤드
	var rivet_count: int = SENSOR_BEZEL_RIVET_COUNT_LOD if lod_active else SENSOR_BEZEL_RIVET_COUNT
	for ri in range(rivet_count):
		var ra: float = -PI * 0.5 + float(ri) * TAU / float(rivet_count)
		var rp := center + Vector2(cos(ra), sin(ra)) * band_mid
		canvas.draw_circle(rp, max(1.4, 2.1 * sf), Color(0.06, 0.06, 0.08, 0.92))
		canvas.draw_circle(rp, max(0.8, 1.3 * sf), Color(SENSOR_COL_PLATINUM.r, SENSOR_COL_PLATINUM.g, SENSOR_COL_PLATINUM.b, 0.95))

	# 오브시디언 웰 + 상단 인너 섀도우(깊이감)
	canvas.draw_circle(center, well_radius, SENSOR_COL_WELL)
	canvas.draw_arc(center + Vector2(0.0, -well_radius * 0.14), well_radius * 0.84, PI, TAU, frame_arc_segments, Color(0.0, 0.0, 0.0, 0.45), max(1.0, well_radius * 0.26), true)


# 센서 대쉬토큰 오브 가시성 판정 (단일 소스). 퍽-인지 "active" 플래그를 우선하고,
# 구(舊) 스냅샷 호환을 위해 없으면 "equipped"로 폴백한다. 패시브→퍽 전환 후에도
# 센서 퍽을 획득하면(active=true) 오브가 계속 렌더되도록 보장한다.
func _is_sensor_orb_visible(sensor_context: Dictionary) -> bool:
	if sensor_context.is_empty():
		return false
	return bool(sensor_context.get("active", sensor_context.get("equipped", false)))


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _is_horn_strawberry_skill_hud_active(horn_renderer: Object, horn_context: Dictionary) -> bool:
	if horn_renderer == null:
		return false
	if horn_renderer.has_method("is_active"):
		return bool(horn_renderer.is_active(horn_context))
	return bool(horn_context.get("transformed", false))


func _is_odins_eye_skill_hud_active(odins_renderer: Object, odins_context: Dictionary) -> bool:
	if odins_renderer == null:
		return false
	if odins_renderer.has_method("is_active"):
		return bool(odins_renderer.is_active(odins_context))
	return bool(odins_context.get("transformed", false))


func _build_status_context(context: Dictionary) -> Dictionary:
	var lod_scale: float = _get_hud_lod_scale(context)
	if lod_scale >= 0.99:
		return context
	var status_context: Dictionary = context.duplicate()
	status_context["hud_lod_scale"] = lod_scale
	return status_context


func _get_hud_lod_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


# Look up the boost FX host by stable name on the canvas's parent node. If it
# doesn't exist yet, create one and defer the add_child so the new node lands on
# the next idle frame. We keep `_boost_fx_host_pending` as a strong reference
# only during the gap between creation and parent attach so subsequent draws
# within the same frame don't keep instantiating duplicate hosts.
func _get_or_create_boost_fx_host(canvas: CanvasItem) -> Node:
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(BOOST_FX_HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_boost_fx_host_pending = null
		return existing
	if _boost_fx_host_pending != null and is_instance_valid(_boost_fx_host_pending) and not _boost_fx_host_pending.is_queued_for_deletion():
		return _boost_fx_host_pending
	var host: Node = DashTokenBoostFxHost.new()
	host.name = BOOST_FX_HOST_NAME
	_boost_fx_host_pending = host
	parent.call_deferred("add_child", host)
	return host


# Same lazy-attach pattern as the boost fx host: look up the rainbow border
# host by stable name on the canvas's parent, create one if missing, and keep
# a pending strong ref between creation and the deferred add_child so a second
# call in the same frame doesn't spawn a duplicate host.
func _get_or_create_firearm_rainbow_fx_host(canvas: CanvasItem) -> Node:
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(COMMANDO_FIREARM_RAINBOW_FX_HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_firearm_rainbow_fx_host_pending = null
		return existing
	if _firearm_rainbow_fx_host_pending != null and is_instance_valid(_firearm_rainbow_fx_host_pending) and not _firearm_rainbow_fx_host_pending.is_queued_for_deletion():
		return _firearm_rainbow_fx_host_pending
	var host: Node = CommandoFirearmHudRainbowFxHost.new()
	host.name = COMMANDO_FIREARM_RAINBOW_FX_HOST_NAME
	_firearm_rainbow_fx_host_pending = host
	parent.call_deferred("add_child", host)
	return host


func _hide_firearm_rainbow_fx_host(canvas: CanvasItem) -> void:
	var host: Node = null
	if canvas is Node:
		var parent: Node = canvas as Node
		host = parent.get_node_or_null(COMMANDO_FIREARM_RAINBOW_FX_HOST_NAME)
	if host == null and _firearm_rainbow_fx_host_pending != null and is_instance_valid(_firearm_rainbow_fx_host_pending):
		host = _firearm_rainbow_fx_host_pending
	if host != null and is_instance_valid(host) and not host.is_queued_for_deletion() and host.has_method("set_active"):
		host.set_active(false)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
