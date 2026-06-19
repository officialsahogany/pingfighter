extends RefCounted

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const Stage1PillarStatusOrbContextBuilder := preload("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const DashTokenBoostFxHost := preload("res://scripts/hud/dash_token_boost_fx_host.gd")
const CommandoFirearmHudRainbowFxHost := preload("res://scripts/hud/commando_firearm_hud_rainbow_fx_host.gd")

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
const SENSOR_FRAME_ARC_SEGMENTS := 16
const SENSOR_FRAME_ARC_SEGMENTS_LOD := 12
const SENSOR_PROGRESS_ARC_SEGMENTS := 16
const SENSOR_PROGRESS_ARC_SEGMENTS_LOD := 12
const SENSOR_READY_WAVE_COUNT := 1
const SENSOR_READY_WAVE_SEGMENTS := 12
const SENSOR_READY_WAVE_SEGMENTS_LOD := 8
const BOOST_FX_HOST_NAME := "DashTokenBoostFxHost"
const COMMANDO_FIREARM_RAINBOW_FX_HOST_NAME := "CommandoFirearmHudRainbowFxHost"

var layout_helper: Object = Stage1PillarUiLayout.new()
var status_context_builder: Object = Stage1PillarStatusOrbContextBuilder.new()
var _boost_fx_host_pending: Node = null
var _firearm_rainbow_fx_host_pending: Node = null
var _gold_text_size_cache: Dictionary = {}


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

	sample_start = _perf_begin(perf_logger)
	var skill_orb_context: Dictionary = layout_helper.build_skill_orb_context(context, orb_drawer)
	var horn_strawberry_context: Dictionary = _get_dict(context.get("horn_strawberry_context", {}))
	var horn_strawberry_hud_active: bool = _is_horn_strawberry_skill_hud_active(
		horn_strawberry_skill_renderer,
		horn_strawberry_context
	)
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

	if commando_firearm_selector_renderer != null and not horn_strawberry_hud_active:
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


func build_gold_hud_rect(game_offset: Vector2, game_size: Vector2, context: Dictionary = {}) -> Rect2:
	var scale_factor: float = _get_gold_hud_scale(game_size, context)
	var text: String = format_gold_amount(int(context.get("gold_hud_amount", 0)))
	var font_size: int = max(1, int(round(float(GOLD_HUD_FONT_SIZE) * scale_factor)))
	var text_width: float = _get_gold_text_size(text, font_size).x
	var coin_size: float = GOLD_HUD_COIN_SIZE * scale_factor
	var min_size: Vector2 = GOLD_HUD_MIN_SOURCE_SIZE * scale_factor
	var wanted_width: float = max(
		min_size.x,
		GOLD_HUD_SIDE_MARGIN * scale_factor + coin_size + GOLD_HUD_TEXT_GAP * scale_factor + text_width + GOLD_HUD_TEXT_RIGHT_PAD * scale_factor
	)
	var wanted_height: float = min_size.y
	var top_margin: float = GOLD_HUD_TOP_MARGIN * scale_factor
	var side_margin: float = GOLD_HUD_SIDE_MARGIN * scale_factor
	var gap: float = GOLD_HUD_PILLAR_GAP * scale_factor
	var rect_x: float
	if game_offset.x >= wanted_width + gap + side_margin:
		rect_x = game_offset.x - wanted_width - gap
	else:
		var max_inside_width: float = max(64.0 * scale_factor, game_size.x - side_margin * 2.0)
		wanted_width = min(wanted_width, max_inside_width)
		rect_x = game_offset.x + side_margin
	return Rect2(Vector2(rect_x, game_offset.y + top_margin), Vector2(wanted_width, wanted_height))


func format_gold_amount(amount: int) -> String:
	var raw := str(maxi(0, amount))
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.substr(raw.length() - 3, 3) + formatted
		raw = raw.substr(0, raw.length() - 3)
	return raw + formatted


func draw_gold_hud(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, context: Dictionary) -> void:
	_draw_gold_hud(canvas, game_offset, game_size, context)


func _draw_gold_hud(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, context: Dictionary) -> void:
	if canvas == null:
		return
	var amount: int = int(context.get("gold_hud_amount", 0))
	var text: String = format_gold_amount(amount)
	var rect: Rect2 = build_gold_hud_rect(game_offset, game_size, context)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale_factor: float = _get_gold_hud_scale(game_size, context)
	canvas.draw_rect(rect, Color(0.05, 0.045, 0.035, 0.62), true)
	canvas.draw_rect(rect, Color(0.62, 0.48, 0.20, 0.55), false, max(1.0, scale_factor))

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
	var text_shadow_offset := Vector2(0.0, max(1.0, 1.0 * scale_factor))
	canvas.draw_string(font, baseline + text_shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.30))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.86, 0.32, 1.0))


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
	if canvas == null or sensor_context.is_empty() or not bool(sensor_context.get("equipped", false)):
		return
	var lod_active := hud_lod_scale < 0.85
	var frame_arc_segments := SENSOR_FRAME_ARC_SEGMENTS_LOD if lod_active else SENSOR_FRAME_ARC_SEGMENTS
	var progress_arc_segments := SENSOR_PROGRESS_ARC_SEGMENTS_LOD if lod_active else SENSOR_PROGRESS_ARC_SEGMENTS
	var ready_wave_segments := SENSOR_READY_WAVE_SEGMENTS_LOD if lod_active else SENSOR_READY_WAVE_SEGMENTS
	var radius: float = max(10.0, orb_radius * 0.42)
	var center := dash_center + Vector2(orb_radius * 0.64, -(orb_radius + radius + 18.0 * scale_factor))
	var progress: float = clamp(float(sensor_context.get("cooldown_progress", 0.0)), 0.0, 1.0)
	var ready: bool = bool(sensor_context.get("ready", false)) and bool(sensor_context.get("enabled", true))
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * 7.0)
	var base_alpha: float = 0.74 if ready else 0.52
	var glow_alpha: float = 0.12 + 0.08 * pulse if ready else 0.08

	canvas.draw_circle(center, radius + 7.0 * scale_factor, Color(105.0 / 255.0, 70.0 / 255.0, 1.0, glow_alpha))
	canvas.draw_circle(center, radius, Color(18.0 / 255.0, 12.0 / 255.0, 34.0 / 255.0, 0.92))
	canvas.draw_arc(center, radius, 0.0, TAU, frame_arc_segments, Color(95.0 / 255.0, 68.0 / 255.0, 150.0 / 255.0, 0.82), max(1.0, 2.0 * scale_factor), true)

	var end_angle: float = -PI * 0.5 + TAU * progress
	if progress > 0.0:
		canvas.draw_arc(center, radius + 1.0 * scale_factor, -PI * 0.5, end_angle, progress_arc_segments, Color(180.0 / 255.0, 150.0 / 255.0, 1.0, base_alpha), max(1.0, 3.0 * scale_factor), true)
	var core_radius: float = radius * (0.30 + 0.22 * progress)
	canvas.draw_circle(center, core_radius + 4.0 * scale_factor, Color(130.0 / 255.0, 96.0 / 255.0, 1.0, 0.16 + 0.12 * progress))
	canvas.draw_circle(center, core_radius, Color(210.0 / 255.0, 196.0 / 255.0, 1.0, 0.62 + 0.20 * progress))

	for i in range(3):
		var angle: float = -PI * 0.5 + float(i - 1) * 0.72
		var ray_start := center + Vector2(cos(angle), sin(angle)) * (radius * 0.26)
		var ray_end := center + Vector2(cos(angle), sin(angle)) * (radius * 0.72)
		canvas.draw_line(ray_start, ray_end, Color(120.0 / 255.0, 94.0 / 255.0, 1.0, 0.55), max(1.0, 1.4 * scale_factor), true)

	if ready and not static_hud_lod:
		for i in range(SENSOR_READY_WAVE_COUNT):
			var wave_phase: float = fmod(time_seconds * 1.8 + float(i) * 0.5, 1.0)
			var wave_radius: float = radius * (0.82 + 0.58 * wave_phase)
			var wave_alpha: float = 0.22 * (1.0 - wave_phase)
			canvas.draw_arc(center, wave_radius, 0.0, TAU, ready_wave_segments, Color(196.0 / 255.0, 172.0 / 255.0, 1.0, wave_alpha), max(1.0, 1.5 * scale_factor), true)


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
