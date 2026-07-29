extends RefCounted

# Kept under the shipped registry key for compatibility, but this is no longer
# an acquisition-style cut-in. It owns only the compact Guardian Enhancement
# result panel and the small companion reaction sheet drawn inside that panel.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetVisualTextureCache := preload(
	"res://scripts/lingpet/lingpet_visual_texture_cache.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TITLE_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

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
const PANEL_MAX_SIZE := Vector2(468.0, 342.0)

var _visual_cache: Object = LingpetVisualTextureCache.new()
var _result_icon_cache: Dictionary = {}


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
	var base_draw_size := LingpetCatalog.get_visual_layout_value(
		normalized,
		"click_reaction_draw_size" if not idle_fallback else "companion_walk_draw_size",
		96.0
	)
	return {
		"visual_key": visual_key,
		"idle_fallback": idle_fallback,
		"cols": cols,
		"rows": rows,
		"frame_count": frame_count,
		"frame_interval": frame_interval,
		"draw_size": clampf(base_draw_size * 1.18, 90.0, 128.0),
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
	var panel := _build_panel_rect(view_size)
	_draw_backdrop(canvas, view_size, panel)
	_draw_roll_glow(canvas, panel, snapshot)
	_draw_companion(canvas, panel, pet_id, contract, snapshot)
	_draw_copy(canvas, panel, snapshot)


func _build_panel_rect(view_size: Vector2) -> Rect2:
	var size := Vector2(
		minf(PANEL_MAX_SIZE.x, view_size.x - 44.0),
		minf(PANEL_MAX_SIZE.y, view_size.y - 72.0)
	)
	return Rect2((view_size - size) * 0.5, size)


func _draw_backdrop(canvas: CanvasItem, view_size: Vector2, panel: Rect2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.01, 0.025, 0.035, 0.42), true)
	canvas.draw_rect(panel.grow(8.0), Color(0.0, 0.02, 0.025, 0.38), true)
	canvas.draw_rect(panel, Color(0.035, 0.105, 0.105, 0.97), true)
	canvas.draw_rect(panel, Color(0.40, 0.96, 0.75, 0.92), false, 2.5)
	var inner := panel.grow(-8.0)
	canvas.draw_rect(inner, Color(0.16, 0.56, 0.46, 0.34), false, 1.0)


func _draw_roll_glow(canvas: CanvasItem, panel: Rect2, snapshot: Dictionary) -> void:
	var phase := str(snapshot.get("phase", "roll"))
	var progress := float(snapshot.get("roll_progress", 0.0))
	var t := float(Time.get_ticks_msec()) * 0.001
	var center := panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.48)
	var energy := 1.0 - progress * 0.38 if phase == "roll" else 0.48
	for ring_index in range(3):
		var radius := 50.0 + float(ring_index) * 19.0 + sin(t * 6.0 + ring_index) * 4.0
		canvas.draw_arc(
			center,
			radius,
			t * (0.8 + ring_index * 0.18),
			t * (0.8 + ring_index * 0.18) + PI * 1.28,
			36,
			Color(0.34, 1.0, 0.78, energy * (0.38 - ring_index * 0.07)),
			2.0,
			true
		)


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
	var draw_h := float(contract.get("draw_size", 108.0))
	var aspect := cell_size.x / maxf(1.0, cell_size.y)
	var target_size := Vector2(draw_h * aspect, draw_h)
	var center := panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.48)
	var dest := Rect2(center - target_size * 0.5, target_size)
	canvas.draw_texture_rect_region(texture, dest, source, Color.WHITE)


func _draw_copy(canvas: CanvasItem, panel: Rect2, snapshot: Dictionary) -> void:
	var title := "수호령강화"
	_draw_centered_text(canvas, title, panel.position.y + 42.0, panel, 27, Color(0.72, 1.0, 0.88))
	var phase := str(snapshot.get("phase", "roll"))
	if phase == "roll":
		var dots := ".".repeat(1 + int(floor(float(Time.get_ticks_msec()) * 0.005)) % 3)
		_draw_centered_text(canvas, "강화 공명 중%s" % dots, panel.end.y - 54.0, panel, 18, Color(0.70, 0.92, 0.88))
		return
	var banner := Rect2(panel.position + Vector2(34.0, panel.size.y - 78.0), Vector2(panel.size.x - 68.0, 48.0))
	canvas.draw_rect(banner, Color(0.015, 0.16, 0.12, 0.96), true)
	canvas.draw_rect(banner, Color(0.54, 1.0, 0.78, 0.92), false, 2.0)
	var result: Dictionary = snapshot.get("result", {}) as Dictionary
	var detail: Dictionary = result.get("result_detail", {}) as Dictionary
	var icon_rect := Rect2(banner.position + Vector2(9.0, 7.0), Vector2(34.0, 34.0))
	var has_icon := _draw_result_icon(canvas, icon_rect, detail)
	var copy_rect := banner
	if has_icon:
		copy_rect = Rect2(
			Vector2(icon_rect.end.x + 7.0, banner.position.y),
			Vector2(banner.end.x - icon_rect.end.x - 14.0, banner.size.y)
		)
	_draw_centered_text(canvas, str(snapshot.get("feedback_text", "강화 획득")), banner.position.y + 31.0, copy_rect, 19, Color(0.96, 1.0, 0.97))


func _draw_result_icon(canvas: CanvasItem, icon_rect: Rect2, detail: Dictionary) -> bool:
	var icon_path := str(detail.get("icon_texture_path", "")).strip_edges()
	var texture: Texture2D = _result_icon_cache.get(icon_path, null) as Texture2D
	if texture != null:
		var source_size := Vector2(texture.get_width(), texture.get_height())
		var scale := minf(icon_rect.size.x / maxf(1.0, source_size.x), icon_rect.size.y / maxf(1.0, source_size.y))
		var fitted_size := source_size * scale
		var fitted := Rect2(icon_rect.position + (icon_rect.size - fitted_size) * 0.5, fitted_size)
		canvas.draw_texture_rect(texture, fitted, false, Color.WHITE)
		canvas.draw_rect(icon_rect, Color(0.62, 1.0, 0.84, 0.82), false, 1.0)
		return true
	if str(detail.get("kind", "")) != "stat":
		return false
	var center := icon_rect.get_center()
	canvas.draw_circle(center, icon_rect.size.x * 0.44, Color(0.10, 0.34, 0.28, 0.96))
	canvas.draw_arc(center, icon_rect.size.x * 0.38, -PI * 0.78, PI * 0.78, 18, Color(0.62, 1.0, 0.84), 2.0, true)
	canvas.draw_line(center + Vector2(-5.0, 3.0), center + Vector2(0.0, -5.0), Color.WHITE, 2.0, true)
	canvas.draw_line(center + Vector2(0.0, -5.0), center + Vector2(6.0, 4.0), Color.WHITE, 2.0, true)
	return true


func _draw_centered_text(
	canvas: CanvasItem,
	text: String,
	baseline_y: float,
	rect: Rect2,
	font_size: int,
	color: Color
) -> void:
	var dim := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(rect.position.x + (rect.size.x - dim.x) * 0.5, baseline_y)
	canvas.draw_string(TITLE_FONT, pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.03, 0.025, color.a * 0.75))
	canvas.draw_string(TITLE_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
