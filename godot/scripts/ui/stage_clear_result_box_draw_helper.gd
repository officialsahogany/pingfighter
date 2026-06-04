extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultRewardFloatDrawHelper := preload("res://scripts/ui/stage_clear_result_reward_float_draw_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultShapeHelper := preload("res://scripts/ui/stage_clear_result_shape_helper.gd")

const RESULT_BOX_SHEET_FRAME_COUNT := 16
const RESULT_BOX_SHEET_GRID_COLS := 4
const RESULT_BOX_SHEET_CELL_SIZE := Vector2(256.0, 256.0)
const RESULT_BOX_COMMON_SAFE_LAST_FRAME := 12
const RESULT_BOX_MYTHIC_SAFE_LAST_FRAME := RESULT_BOX_SHEET_FRAME_COUNT - 1
const RESULT_BOX_FRAME_ASSET_GUARD_SCALE := 0.90
const RESULT_BOX_FRAME_DRAW_SIZE := 100.0 / RESULT_BOX_FRAME_ASSET_GUARD_SCALE


static func get_result_box_sheet_texture_for_kind(
	kind: String,
	common_sheet: Texture2D,
	mythic_sheet: Texture2D,
	guaranteed_mythic_sheet: Texture2D
) -> Texture2D:
	if StageClearResultBoxData.is_guaranteed_mythic_box_kind(kind):
		return guaranteed_mythic_sheet
	if StageClearResultBoxData.is_advanced_box_kind(kind):
		return mythic_sheet
	return common_sheet


static func build_floating_result_box_draw_context(
	box: Dictionary,
	hovered: bool,
	scale: float,
	timer_value: float,
	scroll_phase: String,
	scroll_timer: float,
	scroll_unfurl_duration: float,
	float_amplitude: float,
	float_speed: float,
	opening_shake_amplitude: float,
	shadow_offset_y: float,
	hover_grow: float,
	box_base_size: Vector2,
	reward_hover_offset: float,
	common_sheet: Texture2D,
	mythic_sheet: Texture2D,
	guaranteed_mythic_sheet: Texture2D,
	reward_icon_cache: Dictionary
) -> Dictionary:
	var kind: String = str(box.get("kind", StageClearResultBoxData.BOX_KIND_NORMAL))
	return {
		"hovered": hovered,
		"scale": scale,
		"timer": timer_value,
		"scroll_phase": scroll_phase,
		"scroll_timer": scroll_timer,
		"scroll_unfurl_duration": scroll_unfurl_duration,
		"float_amplitude": float_amplitude,
		"float_speed": float_speed,
		"opening_shake_amplitude": opening_shake_amplitude,
		"shadow_offset_y": shadow_offset_y,
		"hover_grow": hover_grow,
		"box_base_size": box_base_size,
		"frame_draw_size": RESULT_BOX_FRAME_DRAW_SIZE,
		"frame_count": RESULT_BOX_SHEET_FRAME_COUNT,
		"common_safe_last_frame": RESULT_BOX_COMMON_SAFE_LAST_FRAME,
		"mythic_safe_last_frame": RESULT_BOX_MYTHIC_SAFE_LAST_FRAME,
		"sheet_grid_cols": RESULT_BOX_SHEET_GRID_COLS,
		"sheet_cell_size": RESULT_BOX_SHEET_CELL_SIZE,
		"reward_hover_offset": reward_hover_offset,
		"texture": get_result_box_sheet_texture_for_kind(kind, common_sheet, mythic_sheet, guaranteed_mythic_sheet),
		"reward_icon_cache": reward_icon_cache,
	}


static func draw_floating_result_box(
	canvas: CanvasItem,
	box: Dictionary,
	draw_context: Dictionary
) -> void:
	if canvas == null:
		return
	var scale: float = float(draw_context.get("scale", 1.0))
	var timer_value: float = float(draw_context.get("timer", 0.0))
	var global_alpha: float = StageClearResultScrollState.get_box_global_alpha(
		str(draw_context.get("scroll_phase", "hidden")),
		float(draw_context.get("scroll_timer", 0.0)),
		float(draw_context.get("scroll_unfurl_duration", 1.0))
	)
	if global_alpha <= 0.02:
		return

	var kind: String = str(box.get("kind", StageClearResultBoxData.BOX_KIND_NORMAL))
	var is_mythic: bool = StageClearResultBoxData.is_mythic_visual_box_kind(kind)
	var state: String = str(box.get("state", "idle"))
	var open_progress: float = float(box.get("open_progress", 0.0))

	var rotation_base: float = float(box.get("rotation_base", 0.0))
	var rotation_jitter: float = float(box.get("rotation_jitter", 0.05))
	var phase: float = float(box.get("phase", 0.0))
	var box_rotation: float = rotation_base + sin(timer_value * 0.9 + phase * 0.7) * rotation_jitter

	var shake_offset := Vector2.ZERO
	if state == "opening" and open_progress < 0.55:
		var shake_intensity: float = 1.0 - open_progress / 0.55
		var shake_t: float = timer_value * 30.0
		shake_offset = Vector2(
			sin(shake_t) * float(draw_context.get("opening_shake_amplitude", 0.0)) * shake_intensity * scale,
			cos(shake_t * 1.3) * 1.2 * shake_intensity * scale
		)

	var draw_center: Vector2 = StageClearResultLayoutHelper.get_box_draw_center(
		box,
		scale,
		timer_value,
		float(draw_context.get("float_amplitude", 0.0)),
		float(draw_context.get("float_speed", 0.0))
	) + shake_offset

	var hovered: bool = draw_context.get("hovered", false) == true
	var hover_active: bool = hovered and state == "idle"
	var hover_pulse: float = 0.0
	if hover_active:
		hover_pulse = sin(timer_value * 4.0 + phase) * 0.5 + 0.5

	var hover_grow: float = float(draw_context.get("hover_grow", 1.0))
	var grow: float = 1.0
	if hover_active:
		grow = hover_grow + hover_pulse * 0.022

	var box_base_size: Vector2 = draw_context.get("box_base_size", Vector2(120.0, 84.0))
	var body_hx: float = box_base_size.x * scale * grow * 0.5
	var body_hy: float = box_base_size.y * scale * grow * 0.5
	var frame_draw_size: float = float(draw_context.get("frame_draw_size", 160.0)) * scale * grow
	var hx: float = frame_draw_size * 0.5
	var hy: float = frame_draw_size * 0.5

	StageClearResultShapeHelper.draw_filled_ellipse(
		canvas,
		Vector2(draw_center.x, draw_center.y + body_hy + float(draw_context.get("shadow_offset_y", 0.0)) * scale),
		body_hx * 0.95,
		body_hy * 0.20,
		Color(0.0, 0.0, 0.0, 0.40 * global_alpha),
		24
	)

	if hover_active:
		StageClearResultShapeHelper.draw_box_hover_glow(canvas, draw_center, body_hx, body_hy, scale, is_mythic, global_alpha, hover_pulse)

	var frame_index: int = StageClearResultLayoutHelper.get_result_box_frame_index(
		state,
		open_progress,
		is_mythic,
		int(draw_context.get("frame_count", 1)),
		int(draw_context.get("common_safe_last_frame", 0)),
		int(draw_context.get("mythic_safe_last_frame", 0))
	)

	var texture: Texture2D = draw_context.get("texture", null) as Texture2D
	if not draw_result_box_sheet_frame(
		canvas,
		texture,
		draw_center,
		frame_index,
		int(draw_context.get("sheet_grid_cols", 1)),
		draw_context.get("sheet_cell_size", Vector2.ONE),
		frame_draw_size,
		box_rotation,
		global_alpha
	):
		draw_result_box_fallback(canvas, draw_center, hx, hy, box_rotation, scale, is_mythic, global_alpha, state, open_progress)

	if hover_active:
		StageClearResultShapeHelper.draw_box_hover_sparkles(canvas, draw_center, body_hx, body_hy, scale, is_mythic, global_alpha, phase, timer_value)

	if state == "opened":
		var reward_icon_cache_value: Variant = draw_context.get("reward_icon_cache", {})
		var reward_icon_cache: Dictionary = reward_icon_cache_value if reward_icon_cache_value is Dictionary else {}
		StageClearResultRewardFloatDrawHelper.draw_reward_label(
			canvas,
			box,
			draw_center,
			body_hy,
			scale,
			global_alpha,
			timer_value,
			float(draw_context.get("reward_hover_offset", 0.0)),
			reward_icon_cache
		)


static func draw_result_box_sheet_frame(
	canvas: CanvasItem,
	texture: Texture2D,
	draw_center: Vector2,
	frame_index: int,
	grid_cols: int,
	cell_size: Vector2,
	frame_draw_size: float,
	box_rotation: float,
	global_alpha: float
) -> bool:
	if canvas == null or texture == null:
		return false
	if grid_cols <= 0 or cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return false
	if frame_draw_size <= 0.0 or global_alpha <= 0.001:
		return false
	var col: int = frame_index % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame_index / grid_cols)
	var half_size: float = frame_draw_size * 0.5
	var source_rect := Rect2(
		Vector2(float(col) * cell_size.x, float(row) * cell_size.y),
		cell_size
	)
	canvas.draw_set_transform(draw_center, box_rotation, Vector2.ONE)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(Vector2(-half_size, -half_size), Vector2(frame_draw_size, frame_draw_size)),
		source_rect,
		Color(1.0, 1.0, 1.0, global_alpha),
		false,
		true
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func draw_result_box_fallback(
	canvas: CanvasItem,
	draw_center: Vector2,
	half_x: float,
	half_y: float,
	box_rotation: float,
	draw_scale: float,
	is_mythic: bool,
	global_alpha: float,
	state: String,
	open_progress: float
) -> void:
	if canvas == null:
		return
	var base_color := Color(0.90, 0.44, 1.0, global_alpha) if is_mythic else Color(0.32, 0.82, 1.0, global_alpha)
	var body_fill := Color(base_color.r * 0.45, base_color.g * 0.45, base_color.b * 0.55, 0.78 * global_alpha)
	var lid_fill := Color(base_color.r, base_color.g, base_color.b, 0.66 * global_alpha)
	var rim_color := Color(1.0, 0.90, 0.45, 0.92 * global_alpha) if is_mythic else Color(0.75, 1.0, 1.0, 0.86 * global_alpha)
	var open_lift: float = 0.0
	if state == "opening" or state == "opened":
		open_lift = StageClearResultClickReactionState.smooth01(open_progress) * half_y * 0.42
	canvas.draw_set_transform(draw_center, box_rotation, Vector2.ONE)
	var body_rect := Rect2(Vector2(-half_x * 0.68, -half_y * 0.05), Vector2(half_x * 1.36, half_y * 1.02))
	var lid_rect := Rect2(Vector2(-half_x * 0.76, -half_y * 0.58 - open_lift), Vector2(half_x * 1.52, half_y * 0.46))
	canvas.draw_rect(body_rect, body_fill)
	canvas.draw_rect(body_rect, rim_color, false, max(1.5, 2.3 * draw_scale))
	canvas.draw_rect(lid_rect, lid_fill)
	canvas.draw_rect(lid_rect, rim_color, false, max(1.5, 2.2 * draw_scale))
	canvas.draw_line(
		Vector2(-half_x * 0.56, body_rect.position.y + body_rect.size.y * 0.35),
		Vector2(half_x * 0.56, body_rect.position.y + body_rect.size.y * 0.35),
		Color(1.0, 1.0, 1.0, 0.18 * global_alpha),
		max(1.0, 1.5 * draw_scale)
	)
	canvas.draw_circle(Vector2.ZERO, max(3.0, 6.0 * draw_scale), rim_color)
	canvas.draw_circle(Vector2.ZERO, max(1.4, 2.8 * draw_scale), Color(1.0, 1.0, 1.0, 0.78 * global_alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
