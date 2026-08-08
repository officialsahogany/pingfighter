extends RefCounted

# Kept under the shipped registry key for compatibility, but this is no longer
# an acquisition-style cut-in. It owns only the compact Guardian Enhancement
# result panel and the small companion reaction sheet drawn inside that panel.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionClickReactionDrawSizeResolver := preload(
	"res://scripts/lingpet/lingpet_companion_click_reaction_draw_size_resolver.gd"
)
const LingpetCompanionSpriteAnimator := preload(
	"res://scripts/lingpet/lingpet_companion_sprite_animator.gd"
)
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetGuardianEnhanceCutinState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd"
)
const LingpetVisualTextureCache := preload(
	"res://scripts/lingpet/lingpet_visual_texture_cache.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TITLE_FONT: Font = preload("res://assets/fonts/NanumBrushScript-Regular.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const PANEL_BACKGROUND_PATH := (
	"res://assets/sprites/lingpet/effects/guardian_enhance/"
	+ "guardian_enhance_hanji_ritual_panel_imagegen_v2.png"
)
const PANEL_BACKGROUND: Texture2D = preload(PANEL_BACKGROUND_PATH)

const REACTION_VISUAL_KEY := "companion_click_reaction_anim"
const IDLE_VISUAL_KEY := "companion_idle"
const WALK_VISUAL_KEY := "companion_walk"
const DEFAULT_REACTION_COLS := 14
const DEFAULT_REACTION_ROWS := 7
const DEFAULT_REACTION_FRAMES := 98
const DEFAULT_REACTION_INTERVAL := 0.036
const DEFAULT_IDLE_COLS := 5
const DEFAULT_IDLE_ROWS := 5
const DEFAULT_IDLE_FRAMES := 25
const DEFAULT_IDLE_INTERVAL := 0.10
const PANEL_IMAGE_ASPECT := 1485.0 / 1059.0
const PANEL_MAX_SIZE := Vector2(620.0, 442.0)
const COMPANION_DRAW_SCALE := 1.18
const COMPANION_MAX_PANEL_HEIGHT_RATIO := 0.30
# Measured from the 1485x1059 v2 panel PNG, independently of the handoff estimate:
# a 9 px luminance strip scan plus trimmed annular-contrast fit converges at
# center (743, 499), with the authored primary ink stroke at radius 254 px.
const ENSO_CENTER_NORMALIZED := Vector2(743.0 / 1485.0, 499.0 / 1059.0)
const ENSO_STROKE_RADIUS_HEIGHT_RATIO := 254.0 / 1059.0
const REEL_INTERVAL_START_SECONDS := 0.075
const REEL_INTERVAL_END_SECONDS := 0.20
const GOLD_RIM_COLOR := Color(0.86, 0.72, 0.38, 1.0)
const INK_COLOR := Color(0.12, 0.075, 0.04, 1.0)
const VERMILION_COLOR := Color(0.50, 0.105, 0.065, 1.0)
const PAPER_COLOR := Color(0.93, 0.88, 0.76, 1.0)

var _visual_cache: Object = LingpetVisualTextureCache.new()
var _result_icon_cache: Dictionary = {}
var _reaction_draw_size_resolver: Object = LingpetCompanionClickReactionDrawSizeResolver.new()
var _reaction_draw_size_profile: Object = LingpetCurrentProfile.new()


func prewarm_assets() -> void:
	for pet_id in LingpetCatalog.get_pet_ids():
		for active_skill in LingpetCatalog.get_active_skill_pool(pet_id):
			prewarm_result_icon_path(str(active_skill.get("icon_texture_path", "")))
	for passive_skill in LingpetCatalog.get_passive_skill_pool(LingpetCatalog.DEFAULT_PET_ID):
		prewarm_result_icon_path(str(passive_skill.get("icon_texture_path", "")))


func prewarm_result_icon_path(icon_path: String) -> bool:
	var normalized := icon_path.strip_edges()
	if normalized == "":
		return true
	if _result_icon_cache.has(normalized):
		return _result_icon_cache.get(normalized) is Texture2D
	var texture: Texture2D = ProjectResourceLoader.load_texture(
		normalized,
		"",
		"Failed to prewarm Guardian Enhancement result icon: %s"
	)
	_result_icon_cache[normalized] = texture
	return texture != null


func has_cached_result_icon(icon_path: String) -> bool:
	return _result_icon_cache.get(icon_path.strip_edges(), null) is Texture2D


func prewarm_pet_assets_step(
	pet_id: String,
	allow_sync_fallback: bool = false,
	_perf_logger: Object = null,
	_perf_label_prefix: String = ""
) -> bool:
	var contract := get_animation_contract(pet_id)
	var visual_key := str(contract.get("visual_key", ""))
	if visual_key == "":
		return true
	if allow_sync_fallback:
		return _visual_cache.get_texture(pet_id, visual_key, null) != null
	return bool(_visual_cache.prewarm_pet_key_threaded_step(pet_id, visual_key, 2, 1))


func is_pet_panel_anim_ready(pet_id: String) -> bool:
	var contract := get_animation_contract(pet_id)
	var visual_key := str(contract.get("visual_key", ""))
	if visual_key == "":
		return true
	return _visual_cache.get_cached_texture(pet_id, visual_key, null) != null


# Compatibility surface consumed by the existing resolver/prewarm coordinator.
func is_pet_cutin_anim_ready(pet_id: String) -> bool:
	return is_pet_panel_anim_ready(pet_id)


static func resolve_panel_companion_draw_height(authored_height: float, panel_height: float) -> float:
	return minf(
		maxf(0.0, authored_height),
		maxf(0.0, panel_height) * COMPANION_MAX_PANEL_HEIGHT_RATIO
	)


static func resolve_presentation_layout(snapshot: Dictionary) -> Dictionary:
	var phase := str(snapshot.get("phase", LingpetGuardianEnhanceCutinState.PHASE_INTRO))
	var progress := clampf(float(snapshot.get("phase_progress", 0.0)), 0.0, 1.0)
	var phase_elapsed := maxf(
		0.0,
		float(snapshot.get(
			"phase_elapsed",
			progress * LingpetGuardianEnhanceCutinState.STAMP_SECONDS
		))
	)
	var panel_alpha := 1.0
	var panel_scale := 1.0
	var veil_alpha := 0.72
	match phase:
		LingpetGuardianEnhanceCutinState.PHASE_INTRO:
			var eased := _ease_out_cubic(progress)
			panel_alpha = eased
			panel_scale = lerpf(0.94, 1.0, eased)
			veil_alpha = 0.72 * eased
		LingpetGuardianEnhanceCutinState.PHASE_STAMP:
			var overshoot_progress := clampf(phase_elapsed / 0.14, 0.0, 1.0)
			panel_scale = lerpf(1.03, 1.0, _ease_out_cubic(overshoot_progress))
			if phase_elapsed <= 0.10:
				veil_alpha = lerpf(0.72, 0.80, clampf(phase_elapsed / 0.10, 0.0, 1.0))
			else:
				veil_alpha = lerpf(
					0.80,
					0.72,
					clampf((phase_elapsed - 0.10) / 0.12, 0.0, 1.0)
				)
		LingpetGuardianEnhanceCutinState.PHASE_OUTRO:
			panel_alpha = 1.0 - progress
			panel_scale = lerpf(1.0, 0.97, progress)
			veil_alpha = 0.72 * (1.0 - progress)
	return {
		"panel_alpha": clampf(panel_alpha, 0.0, 1.0),
		"panel_scale": panel_scale,
		"veil_alpha": clampf(veil_alpha, 0.0, 0.80),
	}


static func resolve_reel_icon_path(snapshot: Dictionary) -> String:
	var result: Dictionary = snapshot.get("result", {}) as Dictionary
	var result_detail: Dictionary = result.get("result_detail", {}) as Dictionary
	var result_icon_path := str(result_detail.get("icon_texture_path", "")).strip_edges()
	var raw_icons: Variant = snapshot.get("display_candidate_icons", [])
	var icons: Array[String] = []
	if raw_icons is Array:
		for raw_icon_path in raw_icons as Array:
			icons.append(str(raw_icon_path).strip_edges())
	var phase := str(snapshot.get("phase", ""))
	var roll_progress := clampf(float(snapshot.get("roll_progress", 0.0)), 0.0, 1.0)
	if phase != LingpetGuardianEnhanceCutinState.PHASE_ROLL or roll_progress >= 1.0:
		return result_icon_path
	if icons.size() <= 1:
		return result_icon_path if result_icon_path != "" else (icons[0] if not icons.is_empty() else "")
	var elapsed := clampf(
		float(snapshot.get("phase_elapsed", 0.0)),
		0.0,
		LingpetGuardianEnhanceCutinState.ROLL_SECONDS
	)
	var cursor := 0.0
	var reel_step := 0
	while cursor < elapsed and reel_step < 64:
		var cursor_progress := clampf(
			cursor / LingpetGuardianEnhanceCutinState.ROLL_SECONDS,
			0.0,
			1.0
		)
		cursor += lerpf(
			REEL_INTERVAL_START_SECONDS,
			REEL_INTERVAL_END_SECONDS,
			_ease_out_cubic(cursor_progress)
		)
		if cursor <= elapsed:
			reel_step += 1
	return icons[reel_step % icons.size()]


func get_animation_contract(pet_id: String) -> Dictionary:
	var normalized := pet_id.strip_edges().to_lower()
	var visual_key := REACTION_VISUAL_KEY
	var idle_fallback := false
	if LingpetCatalog.get_visual_path(normalized, visual_key) == "":
		idle_fallback = true
		visual_key = IDLE_VISUAL_KEY
		if LingpetCatalog.get_visual_path(normalized, visual_key) == "":
			visual_key = WALK_VISUAL_KEY
	var cols_default := DEFAULT_IDLE_COLS if idle_fallback else DEFAULT_REACTION_COLS
	var rows_default := DEFAULT_IDLE_ROWS if idle_fallback else DEFAULT_REACTION_ROWS
	var frames_default := DEFAULT_IDLE_FRAMES if idle_fallback else DEFAULT_REACTION_FRAMES
	var interval_default := DEFAULT_IDLE_INTERVAL if idle_fallback else DEFAULT_REACTION_INTERVAL
	var layout_prefix := visual_key if idle_fallback else "companion_click_reaction"
	var cols := maxi(1, int(LingpetCatalog.get_visual_layout_value(
		normalized, "%s_cols" % layout_prefix, float(cols_default)
	)))
	var rows := maxi(1, int(LingpetCatalog.get_visual_layout_value(
		normalized, "%s_rows" % layout_prefix, float(rows_default)
	)))
	var frame_count := clampi(int(LingpetCatalog.get_visual_layout_value(
		normalized, "%s_frame_count" % layout_prefix, float(frames_default)
	)), 1, cols * rows)
	var frame_interval := maxf(0.001, LingpetCatalog.get_visual_layout_value(
		normalized, "%s_frame_interval" % layout_prefix, interval_default
	))
	_reaction_draw_size_profile.set_pet_id(normalized)
	var base_draw_size: Vector2 = _reaction_draw_size_resolver.resolve(
		_reaction_draw_size_profile,
		float(LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.y)
	)
	return {
		"visual_key": visual_key,
		"idle_fallback": idle_fallback,
		"cols": cols,
		"rows": rows,
		"frame_count": frame_count,
		"frame_interval": frame_interval,
		"draw_size": base_draw_size.y * COMPANION_DRAW_SCALE,
	}


func draw(canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
	if canvas == null or runtime == null or view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	if not runtime.has_method("is_guardian_enhance_cutin_active") or not bool(runtime.is_guardian_enhance_cutin_active()):
		return
	var snapshot: Dictionary = runtime.get_guardian_enhance_cutin_snapshot()
	var pet_id := str(snapshot.get("pet_id", ""))
	var contract: Dictionary = snapshot.get("animation_contract", {}) as Dictionary
	if contract.is_empty():
		contract = get_animation_contract(pet_id)
	var presentation := resolve_presentation_layout(snapshot)
	var panel := _scale_rect_from_center(
		_build_panel_rect(view_size),
		float(presentation.get("panel_scale", 1.0))
	)
	var draw_snapshot := snapshot.duplicate(true)
	draw_snapshot["presentation_alpha"] = float(presentation.get("panel_alpha", 1.0))
	_draw_backdrop(
		canvas,
		view_size,
		panel,
		float(presentation.get("veil_alpha", 0.72)),
		float(presentation.get("panel_alpha", 1.0))
	)
	_draw_roll_glow(canvas, panel, draw_snapshot)
	_draw_companion(canvas, panel, pet_id, contract, draw_snapshot)
	_draw_copy(canvas, panel, draw_snapshot)


func _build_panel_rect(view_size: Vector2) -> Rect2:
	var available := Vector2(
		maxf(1.0, minf(PANEL_MAX_SIZE.x, view_size.x - 36.0)),
		maxf(1.0, minf(PANEL_MAX_SIZE.y, view_size.y - 56.0))
	)
	var size := Vector2(available.x, available.x / PANEL_IMAGE_ASPECT)
	if size.y > available.y:
		size = Vector2(available.y * PANEL_IMAGE_ASPECT, available.y)
	return Rect2((view_size - size) * 0.5, size)


func _draw_backdrop(
	canvas: CanvasItem,
	view_size: Vector2,
	panel: Rect2,
	veil_alpha: float,
	panel_alpha: float
) -> void:
	canvas.draw_rect(
		Rect2(Vector2.ZERO, view_size),
		Color(0.008, 0.009, 0.01, veil_alpha),
		true
	)
	for shadow_step in range(4, 0, -1):
		canvas.draw_rect(
			panel.grow(float(shadow_step) * 3.0),
			Color(0.0, 0.0, 0.0, panel_alpha * 0.045 * float(5 - shadow_step)),
			true
		)
	canvas.draw_texture_rect(PANEL_BACKGROUND, panel, false, Color(1.0, 1.0, 1.0, panel_alpha))


func _draw_roll_glow(canvas: CanvasItem, panel: Rect2, snapshot: Dictionary) -> void:
	var phase := str(snapshot.get("phase", LingpetGuardianEnhanceCutinState.PHASE_INTRO))
	var panel_alpha := clampf(float(snapshot.get("presentation_alpha", 1.0)), 0.0, 1.0)
	var center := panel.position + panel.size * ENSO_CENTER_NORMALIZED
	var enso_radius := panel.size.y * ENSO_STROKE_RADIUS_HEIGHT_RATIO
	if phase == LingpetGuardianEnhanceCutinState.PHASE_ROLL:
		var roll_progress := clampf(float(snapshot.get("roll_progress", 0.0)), 0.0, 1.0)
		var eased_progress := _ease_out_cubic(roll_progress)
		var start_angle := -PI * 0.5
		var visible_angle := TAU * eased_progress
		for segment_index in range(6):
			var segment_start_offset := TAU * float(segment_index) / 6.0
			if segment_start_offset >= visible_angle:
				break
			var segment_end_offset := minf(
				TAU * float(segment_index + 1) / 6.0,
				visible_angle
			)
			var width_progress := (segment_start_offset + segment_end_offset) * 0.5 / TAU
			canvas.draw_arc(
				center,
				enso_radius,
				start_angle + segment_start_offset,
				start_angle + segment_end_offset,
				12,
				_with_alpha(
					INK_COLOR,
					panel_alpha * lerpf(0.55, 0.72, roll_progress)
				),
				lerpf(4.5, 2.5, width_progress),
				true
			)
		if visible_angle > 0.001:
			var tip_angle := start_angle + visible_angle
			canvas.draw_circle(
				center + Vector2(cos(tip_angle), sin(tip_angle)) * enso_radius,
				3.2,
				_with_alpha(INK_COLOR, panel_alpha * 0.62)
			)
		if roll_progress > 0.60:
			var converge_progress := clampf((roll_progress - 0.60) / 0.40, 0.0, 1.0)
			for stroke_index in range(6):
				var angle := TAU * float(stroke_index) / 6.0 - PI * 0.5
				var outer := center + Vector2(cos(angle), sin(angle)) * enso_radius * 0.82
				var stroke_length := panel.size.y * lerpf(0.06, 0.01, converge_progress)
				canvas.draw_line(
					outer,
					outer - Vector2(cos(angle), sin(angle)) * stroke_length,
					_with_alpha(INK_COLOR, panel_alpha * 0.20 * (1.0 - converge_progress)),
					1.6,
					true
				)
	elif phase in [
		LingpetGuardianEnhanceCutinState.PHASE_STAMP,
		LingpetGuardianEnhanceCutinState.PHASE_REACTION,
		LingpetGuardianEnhanceCutinState.PHASE_OUTRO,
	]:
		canvas.draw_arc(
			center,
			enso_radius,
			-PI * 0.5,
			PI * 1.5,
			72,
			_with_alpha(INK_COLOR, panel_alpha * 0.30),
			2.5,
			true
		)
	if phase == LingpetGuardianEnhanceCutinState.PHASE_STAMP:
		_draw_stamp_impact(canvas, panel, center, snapshot, panel_alpha)


func _draw_stamp_impact(
	canvas: CanvasItem,
	panel: Rect2,
	center: Vector2,
	snapshot: Dictionary,
	panel_alpha: float
) -> void:
	var progress := clampf(float(snapshot.get("phase_progress", 0.0)), 0.0, 1.0)
	var eased := _ease_out_cubic(progress)
	canvas.draw_arc(
		center,
		panel.size.y * lerpf(0.18, 0.42, eased),
		0.0,
		TAU,
		72,
		_with_alpha(INK_COLOR, panel_alpha * 0.34 * (1.0 - progress)),
		lerpf(3.0, 10.0, progress),
		true
	)
	var flare_progress := clampf(
		float(snapshot.get("phase_elapsed", 0.0)) / 0.18,
		0.0,
		1.0
	)
	var flare_width := lerpf(6.0, 0.0, flare_progress)
	if flare_width <= 0.01:
		return
	var flare_color := _with_alpha(
		GOLD_RIM_COLOR,
		panel_alpha * 0.55 * (1.0 - flare_progress)
	)
	var offset := flare_width * 0.5 + 1.0
	canvas.draw_line(panel.position + Vector2(0.0, -offset), panel.end - Vector2(0.0, panel.size.y + offset), flare_color, flare_width, true)
	canvas.draw_line(panel.end + Vector2(0.0, offset), panel.position + Vector2(panel.size.x, panel.size.y + offset), flare_color, flare_width, true)
	canvas.draw_line(panel.position + Vector2(-offset, 0.0), panel.end - Vector2(panel.size.x + offset, 0.0), flare_color, flare_width, true)
	canvas.draw_line(panel.end + Vector2(offset, 0.0), panel.position + Vector2(panel.size.x + offset, panel.size.y), flare_color, flare_width, true)


func _draw_companion(
	canvas: CanvasItem,
	panel: Rect2,
	pet_id: String,
	contract: Dictionary,
	snapshot: Dictionary
) -> void:
	var visual_key := str(contract.get("visual_key", ""))
	var texture: Texture2D = _visual_cache.get_cached_texture(pet_id, visual_key, null)
	if texture == null:
		return
	var cols := maxi(1, int(contract.get("cols", DEFAULT_REACTION_COLS)))
	var rows := maxi(1, int(contract.get("rows", DEFAULT_REACTION_ROWS)))
	var frame_count := clampi(int(contract.get("frame_count", cols * rows)), 1, cols * rows)
	var frame := clampi(int(snapshot.get("animation_frame", 0)), 0, frame_count - 1)
	var cell_size := Vector2(float(texture.get_width()) / float(cols), float(texture.get_height()) / float(rows))
	var source := Rect2(Vector2(float(frame % cols), float(frame / cols)) * cell_size, cell_size)
	var draw_h := resolve_panel_companion_draw_height(
		float(contract.get("draw_size", 108.0)),
		panel.size.y
	)
	var aspect := cell_size.x / maxf(1.0, cell_size.y)
	var target_size := Vector2(draw_h * aspect, draw_h)
	var center := panel.position + panel.size * ENSO_CENTER_NORMALIZED
	var dest := Rect2(center - target_size * 0.5, target_size)
	canvas.draw_texture_rect_region(
		texture,
		dest,
		source,
		Color(1.0, 1.0, 1.0, clampf(float(snapshot.get("presentation_alpha", 1.0)), 0.0, 1.0))
	)


func _draw_copy(canvas: CanvasItem, panel: Rect2, snapshot: Dictionary) -> void:
	var panel_alpha := clampf(float(snapshot.get("presentation_alpha", 1.0)), 0.0, 1.0)
	var title := "수호령 강화"
	var title_size := int(clampf(panel.size.x * 0.060, 27.0, 37.0))
	_draw_centered_text(
		canvas,
		title,
		panel.position.y + panel.size.y * 0.145,
		panel,
		title_size,
		_with_alpha(PAPER_COLOR, panel_alpha),
		TITLE_FONT,
		Color(0.0, 0.0, 0.0, panel_alpha * 0.78)
	)
	var result: Dictionary = snapshot.get("result", {}) as Dictionary
	var source_label := str(result.get("trigger_source_label", "")).strip_edges()
	if source_label != "":
		_draw_centered_text(
			canvas,
			source_label,
			panel.position.y + panel.size.y * 0.195,
			panel,
			12,
			Color(0.42, 0.075, 0.045, panel_alpha * 0.92),
			BODY_FONT,
			Color(PAPER_COLOR.r, PAPER_COLOR.g, PAPER_COLOR.b, panel_alpha * 0.66)
		)
	var phase := str(snapshot.get("phase", "roll"))
	var copy_rect := Rect2(
		panel.position + Vector2(panel.size.x * 0.29, panel.size.y * 0.742),
		Vector2(panel.size.x * 0.51, panel.size.y * 0.17)
	)
	var result_baseline := panel.position.y + panel.size.y * 0.842
	if phase == "intro" or phase == "roll":
		var roll_progress := float(snapshot.get("roll_progress", 0.0))
		var dots := "·".repeat(1 + mini(2, int(floor(roll_progress * 6.0))))
		if phase == "roll":
			var reel_icon_path := resolve_reel_icon_path(snapshot)
			var reel_detail := (
				{"kind": "stat"}
				if reel_icon_path == ""
				else {"icon_texture_path": reel_icon_path}
			)
			var reel_icon_size := panel.size.y * 0.112
			var reel_icon_center := panel.position + Vector2(
				panel.size.x * 0.235,
				panel.size.y * 0.815
			)
			_draw_result_icon(
				canvas,
				Rect2(
					reel_icon_center - Vector2.ONE * reel_icon_size * 0.5,
					Vector2.ONE * reel_icon_size
				),
				reel_detail,
				panel_alpha * 0.75 * clampf(roll_progress / 0.18, 0.0, 1.0)
			)
		_draw_centered_text(
			canvas,
			"강화 공명 중 %s" % dots,
			result_baseline,
			copy_rect,
			19,
			_with_alpha(INK_COLOR, panel_alpha),
			BODY_FONT,
			Color(PAPER_COLOR.r, PAPER_COLOR.g, PAPER_COLOR.b, panel_alpha * 0.72)
		)
		return
	var detail: Dictionary = result.get("result_detail", {}) as Dictionary
	var icon_size := panel.size.y * 0.112
	var icon_center := panel.position + Vector2(panel.size.x * 0.235, panel.size.y * 0.815)
	var icon_rect := Rect2(icon_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	var stamp_scale := 1.0
	var reveal_progress := 1.0
	var baseline_offset := 0.0
	var accent_color := VERMILION_COLOR
	if phase == LingpetGuardianEnhanceCutinState.PHASE_STAMP:
		var stamp_elapsed := maxf(0.0, float(snapshot.get("phase_elapsed", 0.0)))
		stamp_scale = lerpf(1.6, 1.0, _ease_in_cubic(clampf(stamp_elapsed / 0.10, 0.0, 1.0)))
		reveal_progress = _ease_out_cubic(clampf(stamp_elapsed / 0.08, 0.0, 1.0))
		baseline_offset = 4.0 * (1.0 - reveal_progress)
		var pulse := sin(PI * clampf(stamp_elapsed / 0.12, 0.0, 1.0))
		accent_color = VERMILION_COLOR.lerp(Color(0.72, 0.20, 0.12, 1.0), pulse)
	_draw_result_icon(canvas, icon_rect, detail, panel_alpha, true, stamp_scale)
	_draw_result_feedback(
		canvas,
		str(snapshot.get("feedback_text", "강화 획득")),
		result_baseline + baseline_offset,
		copy_rect,
		panel_alpha * reveal_progress,
		accent_color
	)


func _draw_result_icon(
	canvas: CanvasItem,
	icon_rect: Rect2,
	detail: Dictionary,
	alpha: float = 1.0,
	draw_stamp: bool = false,
	stamp_scale: float = 1.0
) -> bool:
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	if draw_stamp:
		_draw_stamp_background(canvas, icon_rect, safe_alpha, stamp_scale)
	var icon_path := str(detail.get("icon_texture_path", "")).strip_edges()
	var texture: Texture2D = _result_icon_cache.get(icon_path, null) as Texture2D
	if texture != null:
		var inset_ratio := 0.21 if draw_stamp else 0.12
		var inset_rect := icon_rect.grow(-icon_rect.size.x * inset_ratio)
		var source_size := Vector2(texture.get_width(), texture.get_height())
		var scale := minf(inset_rect.size.x / maxf(1.0, source_size.x), inset_rect.size.y / maxf(1.0, source_size.y))
		var fitted_size := source_size * scale
		var fitted := Rect2(inset_rect.position + (inset_rect.size - fitted_size) * 0.5, fitted_size)
		if not draw_stamp:
			canvas.draw_circle(
				icon_rect.get_center(),
				icon_rect.size.x * 0.43,
				Color(0.91, 0.85, 0.71, safe_alpha * 0.44)
			)
		canvas.draw_texture_rect(texture, fitted, false, Color(1.0, 1.0, 1.0, safe_alpha))
		return true
	if str(detail.get("kind", "")) != "stat":
		return false
	var center := icon_rect.get_center()
	if not draw_stamp:
		canvas.draw_circle(center, icon_rect.size.x * 0.42, Color(0.89, 0.82, 0.68, safe_alpha * 0.58))
	canvas.draw_arc(center, icon_rect.size.x * 0.37, -PI * 0.78, PI * 0.78, 20, _with_alpha(INK_COLOR, safe_alpha), 2.2, true)
	canvas.draw_line(center + Vector2(-6.0, 4.0), center + Vector2(0.0, -6.0), _with_alpha(VERMILION_COLOR, safe_alpha), 2.5, true)
	canvas.draw_line(center + Vector2(0.0, -6.0), center + Vector2(7.0, 4.0), _with_alpha(VERMILION_COLOR, safe_alpha), 2.5, true)
	return true


func _draw_stamp_background(
	canvas: CanvasItem,
	icon_rect: Rect2,
	alpha: float,
	stamp_scale: float
) -> void:
	var center := icon_rect.get_center()
	var radius := icon_rect.size.x * 0.43 * maxf(0.0, stamp_scale)
	canvas.draw_circle(center, radius, _with_alpha(VERMILION_COLOR, alpha * 0.88))
	var rough_edge := PackedVector2Array()
	for point_index in range(49):
		var angle := TAU * float(point_index) / 48.0
		var rough_radius := radius + sin(angle * 12.0) * 1.2
		rough_edge.append(center + Vector2(cos(angle), sin(angle)) * rough_radius)
	canvas.draw_polyline(rough_edge, _with_alpha(VERMILION_COLOR, alpha), 2.0, true)
	var inner_square_size := Vector2.ONE * radius * 0.92
	canvas.draw_rect(
		Rect2(center - inner_square_size * 0.5, inner_square_size),
		Color(PAPER_COLOR.r, PAPER_COLOR.g, PAPER_COLOR.b, alpha * 0.82),
		false,
		2.0,
		true
	)


func _draw_result_feedback(
	canvas: CanvasItem,
	text: String,
	baseline_y: float,
	rect: Rect2,
	alpha: float = 1.0,
	accent_color: Color = VERMILION_COLOR
) -> void:
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	var font_size := _fit_font_size(text, rect.size.x, 22, 13)
	var accent_index := text.rfind(" +")
	if accent_index < 0:
		accent_index = text.find(" → ")
	if accent_index < 0 and text.ends_with(" 해금"):
		accent_index = text.rfind(" 해금")
	if accent_index <= 0:
		_draw_centered_text(
			canvas,
			text,
			baseline_y,
			rect,
			font_size,
			_with_alpha(INK_COLOR, safe_alpha),
			BODY_FONT,
			Color(PAPER_COLOR.r, PAPER_COLOR.g, PAPER_COLOR.b, safe_alpha * 0.76)
		)
		return
	var prefix := text.substr(0, accent_index)
	var accent := text.substr(accent_index)
	var prefix_size := BODY_FONT.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var accent_size := BODY_FONT.get_string_size(accent, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var start_x := rect.position.x + (rect.size.x - prefix_size.x - accent_size.x) * 0.5
	_draw_text_segment(
		canvas,
		prefix,
		Vector2(start_x, baseline_y),
		font_size,
		_with_alpha(INK_COLOR, safe_alpha)
	)
	_draw_text_segment(
		canvas,
		accent,
		Vector2(start_x + prefix_size.x, baseline_y),
		font_size,
		_with_alpha(accent_color, safe_alpha)
	)


func _fit_font_size(text: String, max_width: float, preferred: int, minimum: int) -> int:
	var font_size := preferred
	while font_size > minimum and BODY_FONT.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x > max_width:
		font_size -= 1
	return font_size


func _draw_text_segment(
	canvas: CanvasItem,
	text: String,
	position: Vector2,
	font_size: int,
	color: Color
) -> void:
	var paper_outline := Color(PAPER_COLOR.r, PAPER_COLOR.g, PAPER_COLOR.b, color.a * 0.74)
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]:
		canvas.draw_string(BODY_FONT, position + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, paper_outline)
	canvas.draw_string(BODY_FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered_text(
	canvas: CanvasItem,
	text: String,
	baseline_y: float,
	rect: Rect2,
	font_size: int,
	color: Color,
	font: Font = BODY_FONT,
	shadow_color: Color = Color(0.0, 0.0, 0.0, 0.60)
) -> void:
	var dim := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := Vector2(rect.position.x + (rect.size.x - dim.x) * 0.5, baseline_y)
	canvas.draw_string(font, pos + Vector2(1.2, 1.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


static func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse


static func _ease_in_cubic(value: float) -> float:
	var safe_value := clampf(value, 0.0, 1.0)
	return safe_value * safe_value * safe_value


static func _scale_rect_from_center(rect: Rect2, scale: float) -> Rect2:
	var safe_scale := maxf(0.0, scale)
	var scaled_size := rect.size * safe_scale
	return Rect2(rect.get_center() - scaled_size * 0.5, scaled_size)


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(alpha, 0.0, 1.0))
