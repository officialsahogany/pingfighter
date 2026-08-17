extends RefCounted

const SkillOrbTooltipPreviewDrawPrimitives := preload("res://scripts/hud/skill_orb_tooltip_preview_draw_primitives.gd")

const SMASHER_EFFECT_PREVIEW_TYPES := {
	"drive_curve": true,
	"smash_orange": true,
	"thunder_strike": true,
	"projectile_cyan": true,
	"heal_green": true,
	"cleanse_light": true,
	"shield_kiting_arc": true,
	"magnetic_pull_blue": true,
	"ghost_purple": true,
	"portal_purple": true,
	"wheel_spin": true,
	"overdrive_meteor_break": true,
	"void_phantom_split": true,
}
const VIPER_EFFECT_PREVIEW_TYPES := {
	"shadow_teleport": true,
	"slash_purple": true,
	"stun_purple": true,
	"dive_impact": true,
	"wall_dive_purple": true,
	"slash_dark": true,
	"chaos_vortex": true,
	"core_flip_arc": true,
	"glitch_clone": true,
	"ignition_burst": true,
	"wall_leap_raid": true,
}
const ODINS_EYE_EFFECT_PREVIEW_TYPES := {
	"odins_eye_dark_swamp": true,
}
const COMMANDO_EFFECT_PREVIEW_TYPES := {
	"supply_green": true,
	"emergency_red": true,
	"firearm_pistol": true,
	"firearm_bazooka": true,
	"firearm_ak47": true,
	"firearm_net": true,
	"firearm_support": true,
	"firearm_trap": true,
	"firearm_drone": true,
}
const VISION_EFFECT_PREVIEW_TYPES := {
	"dalji_vision_chain_top": true,
	"cheongringwi_vision_dragon_torrent": true,
	"yeonmyo_vision_bonghongwe": true,
}
const VIPER_EFFECT_INPUT_OVERLAY := {
	"shadow_teleport": ["combo", "S"],
	"slash_purple": ["hold", "W"],
	"stun_purple": ["combo", "W"],
	"dive_impact": ["hold", "S"],
	"wall_dive_purple": ["combo", "S"],
	"slash_dark": ["combo", "W"],
	"chaos_vortex": ["sequence", "A,W,D"],
	"core_flip_arc": ["plus", "A,D"],
	"glitch_clone": ["sequence", "A,D,A,D"],
	"ignition_burst": ["hold", "W"],
	"wall_leap_raid": ["sequence", "RMB,LMB,RMB"],
}
const VIPER_INPUT_CYCLE_MS := 2400.0
const VIPER_INPUT_VISIBLE_RATIO := 0.45

var _draw_primitives: Object = SkillOrbTooltipPreviewDrawPrimitives.new()

func draw(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color, progress: float) -> void:
	_draw_effect_preview(canvas, rect, effect_type, color, progress)


func get_effect_preview_family(effect_type: String) -> String:
	return _get_effect_preview_family(effect_type)

func _draw_effect_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color, _progress: float) -> void:
	var preview_family: String = _get_effect_preview_family(effect_type)
	if preview_family == "viper":
		_draw_viper_effect_preview(canvas, rect, effect_type, color)
		return
	if preview_family == "commando":
		_draw_commando_effect_preview(canvas, rect, effect_type, color)
		return
	if preview_family == "odins_eye":
		_draw_odins_dark_swamp_preview(canvas, rect, color)
		return
	if preview_family == "vision":
		_draw_vision_effect_preview(canvas, rect, effect_type, color)
		return
	if effect_type == "drive_curve":
		_draw_drive_curve_preview(canvas, rect, color)
	elif effect_type == "smash_orange":
		_draw_smasher_heavy_strike_preview(canvas, rect, color, false)
	elif effect_type == "thunder_strike":
		_draw_smasher_heavy_strike_preview(canvas, rect, color, true)
	elif effect_type == "projectile_cyan":
		_draw_projectile_cyan_preview(canvas, rect, color)
	elif effect_type == "heal_green":
		_draw_heal_green_preview(canvas, rect, color)
	elif effect_type == "cleanse_light":
		_draw_cleanse_light_preview(canvas, rect, color)
	elif effect_type == "shield_kiting_arc":
		_draw_shield_kiting_preview(canvas, rect, color)
	elif effect_type == "magnetic_pull_blue":
		_draw_magnetic_pull_preview(canvas, rect, color)
	elif effect_type == "ghost_purple":
		_draw_ghost_purple_preview(canvas, rect, color)
	elif effect_type == "portal_purple":
		_draw_portal_purple_preview(canvas, rect, color)
	elif effect_type == "wheel_spin":
		_draw_wheel_spin_preview(canvas, rect, color)
	elif effect_type == "overdrive_meteor_break":
		_draw_overdrive_meteor_break_preview(canvas, rect, color)
	elif effect_type == "void_phantom_split":
		_draw_void_phantom_split_preview(canvas, rect, color)
	else:
		_draw_drive_curve_preview(canvas, rect, color)


func _get_effect_preview_family(effect_type: String) -> String:
	if VIPER_EFFECT_PREVIEW_TYPES.has(effect_type):
		return "viper"
	if ODINS_EYE_EFFECT_PREVIEW_TYPES.has(effect_type):
		return "odins_eye"
	if COMMANDO_EFFECT_PREVIEW_TYPES.has(effect_type):
		return "commando"
	if VISION_EFFECT_PREVIEW_TYPES.has(effect_type):
		return "vision"
	if SMASHER_EFFECT_PREVIEW_TYPES.has(effect_type):
		return "smasher"
	return "fallback"


func _draw_vision_effect_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color) -> void:
	match effect_type:
		"dalji_vision_chain_top":
			_draw_dalji_vision_chain_top_preview(canvas, rect, color)
		"cheongringwi_vision_dragon_torrent":
			_draw_cheongringwi_vision_dragon_torrent_preview(canvas, rect, color)
		"yeonmyo_vision_bonghongwe":
			_draw_yeonmyo_vision_bonghongwe_preview(canvas, rect, color)
		_:
			push_error("Missing Vision Chosik tooltip preview branch: %s" % effect_type)
			_draw_drive_curve_preview(canvas, rect, color)


func _draw_viper_effect_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color) -> void:
	match effect_type:
		"shadow_teleport":
			_draw_viper_shadow_teleport_preview(canvas, rect, color)
		"slash_purple":
			_draw_viper_blade_preview(canvas, rect, color, false)
		"stun_purple":
			_draw_viper_stun_preview(canvas, rect, color)
		"dive_impact":
			_draw_viper_dive_impact_preview(canvas, rect, color)
		"wall_dive_purple":
			_draw_viper_wall_dive_preview(canvas, rect, color)
		"slash_dark":
			_draw_viper_blade_preview(canvas, rect, color, true)
		"chaos_vortex":
			_draw_viper_chaos_vortex_preview(canvas, rect, color)
		"core_flip_arc":
			_draw_viper_core_flip_preview(canvas, rect, color)
		"glitch_clone":
			_draw_viper_glitch_clone_preview(canvas, rect, color)
		"ignition_burst":
			_draw_viper_ignition_preview(canvas, rect, color)
		"wall_leap_raid":
			_draw_viper_wall_leap_raid_preview(canvas, rect, color)
		_:
			_draw_viper_shadow_teleport_preview(canvas, rect, color)
	_draw_viper_input_overlay(canvas, rect, effect_type, color, Time.get_ticks_msec())


func _draw_preview_paddle(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	var rect := Rect2(center + Vector2(-18.0, -3.0), Vector2(36.0, 6.0))
	canvas.draw_rect(rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.38), true)
	canvas.draw_rect(rect, Color(color.r, color.g, color.b, 0.92), true)


func _draw_curve_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var points := PackedVector2Array()
	for i in range(18):
		var t: float = float(i) / 17.0
		var pos: Vector2 = start.lerp(end, t) + Vector2(0.0, sin(t * PI) * -22.0)
		points.append(pos)
	canvas.draw_polyline(points, Color(color.r, color.g, color.b, 0.65), 2.0)
	var ball_pos: Vector2 = start.lerp(end, progress) + Vector2(0.0, sin(progress * PI) * -22.0)
	canvas.draw_circle(ball_pos, 5.0, Color.WHITE)
	canvas.draw_circle(ball_pos, 7.0, Color(color.r, color.g, color.b, 0.35))


func _draw_smash_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	for i in range(4):
		var offset := Vector2(0.0, float(i - 1) * 5.0)
		canvas.draw_line(start + offset, end + offset * 0.25, Color(color.r, color.g, color.b, 0.18 + float(i) * 0.12), 2.0 + float(i))
	var ball_pos: Vector2 = start.lerp(end, progress)
	canvas.draw_circle(ball_pos, 5.0 + sin(progress * PI) * 2.0, Color.WHITE)
	canvas.draw_circle(end, 14.0 * progress, Color(color.r, color.g, color.b, 0.18 * (1.0 - progress)))


func _draw_projectile_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var ball_pos: Vector2 = start.lerp(end, progress)
	for i in range(5):
		var t: float = max(0.0, progress - float(i) * 0.07)
		var trail_pos: Vector2 = start.lerp(end, t)
		canvas.draw_circle(trail_pos, max(1.0, 6.0 - float(i)), Color(color.r, color.g, color.b, max(0.08, 0.34 - float(i) * 0.05)))
	canvas.draw_circle(ball_pos, 8.0, Color(color.r, color.g, color.b, 0.75))
	canvas.draw_circle(ball_pos, 4.0, Color.WHITE)
	canvas.draw_arc(end, 18.0, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.36), 2.0)


func _draw_recovery_preview(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	for i in range(4):
		var shift: float = (float(i) * 12.0 + progress * 36.0)
		var alpha: float = max(0.0, 0.42 - float(i) * 0.08)
		canvas.draw_line(center + Vector2(-26.0 - shift * 0.2, -16.0 + float(i) * 6.0), center + Vector2(16.0 - shift * 0.2, -16.0 + float(i) * 6.0), Color(color.r, color.g, color.b, alpha), 3.0)
	canvas.draw_circle(center + Vector2(sin(progress * TAU) * 5.0, -10.0), 16.0, Color(color.r, color.g, color.b, 0.18))
	canvas.draw_arc(center + Vector2(0.0, -10.0), 18.0 + progress * 8.0, 0.0, TAU * 0.78, 28, Color(color.r, color.g, color.b, 0.75), 2.0)


func _draw_cleanse_preview(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	for i in range(3):
		var radius: float = 14.0 + float(i) * 10.0 + progress * 12.0
		canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, max(0.06, 0.34 - float(i) * 0.08)), 2.0)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var p0: Vector2 = center + Vector2(cos(angle), sin(angle)) * 8.0
		var p1: Vector2 = center + Vector2(cos(angle), sin(angle)) * 30.0
		canvas.draw_line(p0, p1, Color.WHITE, 1.5)


func _draw_shield_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var arc_mid: Vector2 = start.lerp(end, progress) + Vector2(0.0, -sin(progress * PI) * 24.0)
	canvas.draw_arc(start, 20.0, -PI * 0.72, PI * 0.12, 18, Color(color.r, color.g, color.b, 0.68), 3.0)
	_draw_curve_preview(canvas, start, end, color, progress)
	canvas.draw_arc(arc_mid, 10.0, -PI * 0.85, PI * 0.85, 18, Color.WHITE, 2.0)
	canvas.draw_arc(arc_mid, 13.0, -PI * 0.85, PI * 0.85, 18, Color(color.r, color.g, color.b, 0.64), 2.0)


func _draw_magnetic_preview(canvas: CanvasItem, start: Vector2, ball: Vector2, color: Color, progress: float) -> void:
	var current_ball: Vector2 = ball.lerp(start + Vector2(20.0, -4.0), progress)
	for i in range(3):
		canvas.draw_arc(start, 24.0 + float(i) * 12.0, -PI * 0.25, PI * 0.25, 18, Color(color.r, color.g, color.b, 0.34 - float(i) * 0.08), 2.0)
	canvas.draw_line(current_ball, start, Color(color.r, color.g, color.b, 0.46), 1.5)
	canvas.draw_circle(current_ball, 6.0, Color.WHITE)


func _draw_ghost_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var t: float = float(i) / 19.0
		points.append(start.lerp(end, t) + Vector2(0.0, sin(t * TAU * 1.6 + progress * TAU) * 12.0))
	canvas.draw_polyline(points, Color(color.r, color.g, color.b, 0.68), 2.0)
	var ball_pos: Vector2 = start.lerp(end, progress) + Vector2(0.0, sin(progress * TAU * 1.6 + progress * TAU) * 12.0)
	canvas.draw_circle(ball_pos, 5.0, Color.WHITE)
	for i in range(3):
		var ghost_pos: Vector2 = ball_pos - Vector2(18.0 + float(i) * 9.0, -6.0 + float(i) * 3.0)
		canvas.draw_circle(ghost_pos, 6.0 - float(i), Color(color.r, color.g, color.b, 0.24))


func _draw_portal_preview(canvas: CanvasItem, inner: Rect2, color: Color, progress: float) -> void:
	var left := Vector2(inner.position.x + 28.0, inner.position.y + inner.size.y * 0.45)
	var right := Vector2(inner.end.x - 28.0, inner.position.y + inner.size.y * 0.45)
	for center in [left, right]:
		canvas.draw_arc(center, 17.0 + sin(progress * TAU) * 3.0, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.76), 3.0)
		canvas.draw_arc(center, 9.0, 0.0, TAU, 24, Color.WHITE, 1.5)
	var ball_pos: Vector2 = left.lerp(right, progress)
	canvas.draw_circle(ball_pos, 5.0, Color.WHITE)


func _draw_wheel_preview(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, progress: float) -> void:
	for i in range(4):
		var angle: float = progress * TAU * 2.0 + float(i) * PI * 0.5
		canvas.draw_line(start, start + Vector2(cos(angle), sin(angle)) * 24.0, Color(color.r, color.g, color.b, 0.75), 3.0)
	canvas.draw_arc(start, 29.0, progress * TAU, progress * TAU + PI * 1.35, 28, Color(color.r, color.g, color.b, 0.46), 3.0)
	_draw_curve_preview(canvas, start + Vector2(22.0, -2.0), end, color, progress)


func _draw_projectile_cyan_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var block := 4.0
	if local_progress < 0.35:
		var phase: float = local_progress / 0.35
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": block, "paddle_lift": phase * 0.6})
		var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
		if not paddle.is_empty():
			var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
			var p_radius: float = float(paddle.get("radius", 6.0))
			var charge := p_center + Vector2(0.0, -p_radius - 6.0)
			var core_r: float = max(1.0, 2.0 + phase * 5.0)
			for ring_idx in range(3):
				var ring_r: float = core_r + float(3 - ring_idx) * 2.0
				var ring_alpha: float = max(40.0 / 255.0, (90.0 - float(ring_idx) * 25.0) * phase / 255.0)
				canvas.draw_arc(charge, ring_r, 0.0, TAU, 36, _draw_primitives.alpha(color, ring_alpha), 1.0)
			canvas.draw_circle(charge, core_r, color)
			canvas.draw_circle(charge + Vector2(-1.0, -1.0), max(1.0, core_r * 0.5), Color(220.0 / 255.0, 250.0 / 255.0, 1.0))
			for spark_idx in range(6):
				var spark_angle: float = TAU * float(spark_idx) / 6.0 + float(time_ms) * 0.004
				var spark_dist: float = max(2.0, 14.0 - phase * 12.0)
				var spark_pos: Vector2 = charge + Vector2(cos(spark_angle), sin(spark_angle)) * spark_dist
				var spark_alpha: float = max(60.0, 180.0 * (1.0 - phase) + 120.0 * phase) / 255.0
				canvas.draw_circle(spark_pos, 2.0, _draw_primitives.alpha(color, spark_alpha))
	elif local_progress < 0.55:
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": block, "paddle_lift": 0.6})
		var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
		if not paddle.is_empty():
			var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
			var p_radius: float = float(paddle.get("radius", 6.0))
			var charge := p_center + Vector2(0.0, -p_radius - 6.0)
			var pulse: float = 1.0 + 0.18 * sin(float(time_ms) * 0.025)
			var core_r: float = max(2.0, 7.0 * pulse)
			for ring_idx in range(4):
				canvas.draw_arc(charge, core_r + float(ring_idx) * 3.0, 0.0, TAU, 36, _draw_primitives.alpha(color, max(30.0, 130.0 - float(ring_idx) * 26.0) / 255.0), 1.0)
			canvas.draw_circle(charge, core_r, color)
			canvas.draw_circle(charge + Vector2(-1.0, -1.0), 3.0, Color(235.0 / 255.0, 1.0, 1.0))
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 2.0 * block), "W")
	else:
		var phase: float = (local_progress - 0.55) / 0.45
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {
			"block": block,
			"swing_ratio": min(1.0, phase * 1.8),
			"paddle_lift": max(0.0, 0.6 - phase),
		})
		var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var start := p_center + Vector2(0.0, -p_radius - 4.0)
		var end_y: float = preview_top + 6.0
		@warning_ignore("shadowed_global_identifier")
		var ease: float = 1.0 - pow(1.0 - phase, 2.5)
		var ball_pos := Vector2(start.x + sin(phase * TAU) * 5.0, start.y + (end_y - start.y) * ease)
		for trail_idx in range(8):
			var t: float = max(0.0, ease - float(trail_idx) * 0.1)
			if t <= 0.0:
				continue
			var trail_pos := Vector2(start.x + sin(t * TAU) * 5.0, start.y + (end_y - start.y) * t)
			canvas.draw_circle(trail_pos, max(2.0, 6.0 - float(trail_idx) * 0.5), _draw_primitives.alpha(color, max(40.0, 200.0 - float(trail_idx) * 22.0) / 255.0))
		canvas.draw_arc(ball_pos, 12.0, 0.0, TAU, 36, _draw_primitives.alpha(color, max(30.0, 120.0 * (1.0 - phase * 0.6)) / 255.0), 1.0)
		canvas.draw_arc(ball_pos, 18.0, 0.0, TAU, 36, _draw_primitives.alpha(color, max(20.0, 90.0 * (1.0 - phase * 0.6)) / 255.0), 1.0)
		_draw_preview_ball(canvas, ball_pos, 6.0, [Color(0.0, 200.0 / 255.0, 1.0), Color(140.0 / 255.0, 235.0 / 255.0, 1.0), Color(235.0 / 255.0, 1.0, 1.0)], color)


func _draw_heal_green_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var floor_y: float = preview_bottom - 2.0
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), Color(60.0 / 255.0, 110.0 / 255.0, 80.0 / 255.0, 50.0 / 255.0), 2.0)
	if local_progress < 0.30:
		var phase: float = local_progress / 0.30
		var char_x: float = center_x - 12.0
		_draw_smasher_mini_character(canvas, char_x, char_y, {"block": 4.0, "head_offset_y": (1.0 - phase) * 2.0})
		for arrow_idx in range(2):
			var arrow_x: float = char_x - 14.0 - float(arrow_idx) * 6.0
			var arrow_alpha: float = max(40.0, 140.0 - float(arrow_idx) * 50.0) / 255.0
			var arrow_color := Color(180.0 / 255.0, 180.0 / 255.0, 180.0 / 255.0, arrow_alpha)
			canvas.draw_line(Vector2(arrow_x, char_y - 14.0), Vector2(arrow_x - 6.0, char_y - 14.0), arrow_color, 2.0)
			canvas.draw_line(Vector2(arrow_x - 6.0, char_y - 14.0), Vector2(arrow_x - 3.0, char_y - 17.0), arrow_color, 1.0)
			canvas.draw_line(Vector2(arrow_x - 6.0, char_y - 14.0), Vector2(arrow_x - 3.0, char_y - 11.0), arrow_color, 1.0)
	elif local_progress < 0.55:
		var phase: float = (local_progress - 0.30) / 0.25
		var char_x: float = center_x - 12.0
		_draw_smasher_mini_character(canvas, char_x, char_y, {"block": 4.0})
		var burst := Vector2(char_x, char_y - 2.0)
		for ring_idx in range(3):
			var ring_r: float = 8.0 + phase * 18.0 + float(ring_idx) * 4.0
			var ring_alpha: float = max(0.0, 180.0 * (1.0 - phase) - float(ring_idx) * 30.0) / 255.0
			if ring_alpha > 0.0:
				canvas.draw_arc(burst, ring_r, 0.0, TAU, 36, _draw_primitives.alpha(color, ring_alpha), 2.0)
		for p_idx in range(8):
			var p_angle: float = TAU * float(p_idx) / 8.0 + float(time_ms) * 0.003
			var p_dist: float = 12.0 + phase * 18.0
			var p_pos := burst + Vector2(cos(p_angle) * p_dist, sin(p_angle) * p_dist * 0.5 - phase * 12.0)
			canvas.draw_circle(p_pos, 3.0, _draw_primitives.alpha(color, max(60.0, 220.0 * (1.0 - phase * 0.5)) / 255.0))
		var cross_size: float = 6.0 + phase * 4.0
		var cross_alpha: float = max(120.0, 255.0 * (1.0 - phase * 0.4)) / 255.0
		canvas.draw_line(burst + Vector2(0.0, -cross_size - 6.0), burst + Vector2(0.0, cross_size - 6.0), _draw_primitives.alpha(color, cross_alpha), 3.0)
		canvas.draw_line(burst + Vector2(-cross_size, -6.0), burst + Vector2(cross_size, -6.0), _draw_primitives.alpha(color, cross_alpha), 3.0)
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 8.0), "W")
	else:
		var phase: float = (local_progress - 0.55) / 0.45
		@warning_ignore("shadowed_global_identifier")
		var ease: float = 1.0 - pow(1.0 - phase, 2.0)
		var start_x: float = center_x - 12.0
		var end_x: float = center_x + 60.0
		var char_x: float = start_x + (end_x - start_x) * ease
		for ghost_idx in range(4):
			var t: float = max(0.0, ease - float(ghost_idx + 1) * 0.10)
			if t <= 0.0:
				continue
			var gx: float = start_x + (end_x - start_x) * t
			_draw_smasher_mini_character(canvas, gx, char_y + 1.0, {"block": 4.0, "show_shield": false, "alpha": max(40.0, 130.0 - float(ghost_idx) * 28.0) / 255.0, "tint": color})
		_draw_smasher_mini_character(canvas, char_x, char_y, {"block": 4.0})
		for line_idx in range(5):
			var line_t: float = max(0.0, ease - float(line_idx) * 0.08)
			if line_t <= 0.0:
				continue
			var lx: float = start_x + (end_x - start_x) * line_t
			var ly: float = char_y - 6.0 - float(line_idx) * 5.0
			canvas.draw_line(Vector2(lx - 12.0 - float(line_idx) * 3.0, ly), Vector2(lx, ly), _draw_primitives.alpha(color, max(40.0, 200.0 - float(line_idx) * 32.0) / 255.0), 2.0)
		_draw_primitives.draw_ellipse(canvas, Rect2(Vector2(char_x - 12.0, char_y - 4.0), Vector2(24.0, 6.0)), _draw_primitives.alpha(color, max(30.0, 120.0 * (1.0 - phase * 0.5)) / 255.0), true)


func _draw_cleanse_light_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	if local_progress < 0.35:
		var wobble: float = sin(float(time_ms) * 0.012) * 1.5
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "head_offset_y": wobble})
		var star_cy: float = float(anchors.get("helmet_top", char_y - 28.0)) - 2.0
		for star_idx in range(4):
			var ang: float = TAU * float(star_idx) / 4.0 + float(time_ms) * 0.005
			var star_pos := Vector2(center_x + cos(ang) * 14.0, star_cy + sin(ang) * 4.0)
			_draw_mini_star_gd(canvas, star_pos, 3.0, Color(1.0, 240.0 / 255.0, 120.0 / 255.0) if star_idx % 2 == 0 else Color(200.0 / 255.0, 200.0 / 255.0, 1.0))
		for arc_idx in range(2):
			canvas.draw_arc(Vector2(center_x, star_cy), 14.0 + float(arc_idx) * 3.0, 0.0, TAU, 36, Color(200.0 / 255.0, 200.0 / 255.0, 1.0, max(40.0, 100.0 - float(arc_idx) * 30.0) / 255.0), 1.0)
	elif local_progress < 0.55:
		var phase: float = (local_progress - 0.35) / 0.20
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var burst := Vector2(center_x, char_y - 10.0)
		var burst_r: float = 10.0 + phase * 36.0
		for ring_idx in range(4):
			var rr: float = burst_r - float(ring_idx) * 6.0
			if rr <= 0.0:
				continue
			canvas.draw_arc(burst, rr, 0.0, TAU, 36, _draw_primitives.alpha(color, max(30.0, 220.0 * (1.0 - phase * 0.4) - float(ring_idx) * 30.0) / 255.0), 2.0)
		for i in range(10):
			var ang: float = TAU * float(i) / 10.0 + float(time_ms) * 0.004
			canvas.draw_line(burst + Vector2(cos(ang), sin(ang)) * 8.0, burst + Vector2(cos(ang), sin(ang)) * (8.0 + phase * 32.0), Color(1.0, 1.0, 220.0 / 255.0, max(80.0, 255.0 * (1.0 - phase * 0.6)) / 255.0), 2.0)
		canvas.draw_circle(burst, max(2.0, 8.0 - phase * 4.0), Color(1.0, 1.0, 240.0 / 255.0))
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 8.0), "W")
	else:
		var phase: float = (local_progress - 0.55) / 0.45
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var aura := Vector2(center_x, char_y - 8.0)
		var aura_pulse: float = 1.0 + 0.08 * sin(float(time_ms) * 0.012)
		for ring_idx in range(3):
			var rx: float = (22.0 + float(ring_idx) * 4.0) * aura_pulse
			var ry: float = (28.0 + float(ring_idx) * 5.0) * aura_pulse
			_draw_primitives.draw_ellipse(canvas, Rect2(Vector2(aura.x - rx, aura.y - ry), Vector2(rx * 2.0, ry * 2.0)), _draw_primitives.alpha(color, max(30.0, 140.0 - float(ring_idx) * 38.0) / 255.0), false, 2.0)
		for star_idx in range(5):
			var ang: float = TAU * float(star_idx) / 5.0 + float(time_ms) * 0.002
			_draw_mini_star_gd(canvas, aura + Vector2(cos(ang) * 24.0, sin(ang) * 28.0 - phase * 6.0), 2.0, Color(1.0, 245.0 / 255.0, 200.0 / 255.0))


func _draw_shield_kiting_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2600) / 2600.0
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var wind_up_ratio: float = min(1.0, local_progress / max(0.001, 320.0 / 2600.0))
	var player := Vector2(preview_left + 48.0, preview_bottom - 10.0)
	var ball := Vector2(preview_right - 42.0, preview_top + 16.0)
	var shield_r := 12.0
	var floor_y: float = preview_bottom - 2.0
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), Color(90.0 / 255.0, 110.0 / 255.0, 145.0 / 255.0, 45.0 / 255.0), 2.0)
	_draw_primitives.draw_round_rect(canvas, Rect2(player + Vector2(-10.0, -18.0), Vector2(20.0, 22.0)), Color(78.0 / 255.0, 112.0 / 255.0, 168.0 / 255.0, 90.0 / 255.0), 5.0)
	_draw_primitives.draw_round_rect(canvas, Rect2(player + Vector2(4.0, -18.0), Vector2(7.0, 22.0)), Color(190.0 / 255.0, 220.0 / 255.0, 1.0, 120.0 / 255.0), 4.0)
	var shield_pos: Vector2
	if local_progress < 0.2:
		shield_pos = player + Vector2(16.0 - (1.0 - wind_up_ratio) * 8.0, -18.0 - sin(wind_up_ratio * PI) * 3.0)
		for ring_idx in range(2):
			canvas.draw_arc(shield_pos, shield_r + float(ring_idx) * 5.0 + wind_up_ratio * 6.0, 0.0, TAU, 36, _draw_primitives.alpha(color, max(30.0, 120.0 - float(ring_idx) * 28.0) / 255.0), 1.0)
	else:
		var travel_t: float = clamp((local_progress - 0.2) / 0.8, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - travel_t, 3.0)
		shield_pos = (player + Vector2(16.0, -18.0)).lerp(ball, eased) + Vector2(0.0, -sin(travel_t * PI) * 26.0)
		var trail_pts: Array[Vector2] = []
		for step in range(7):
			var t_step: float = max(0.0, travel_t - float(step) * 0.08)
			var e_step: float = 1.0 - pow(1.0 - t_step, 3.0)
			trail_pts.append((player + Vector2(16.0, -18.0)).lerp(ball, e_step) + Vector2(0.0, -sin(t_step * PI) * 26.0))
		for idx in range(trail_pts.size() - 1):
			canvas.draw_line(trail_pts[idx], trail_pts[idx + 1], _draw_primitives.alpha(color, max(30.0, 160.0 - float(idx) * 18.0) / 255.0), max(1.0, 3.0 - float(idx) * 0.4))
		if travel_t > 0.55:
			var return_progress: float = (travel_t - 0.55) / 0.45
			canvas.draw_arc(player + Vector2(0.0, -16.0), 18.0 + return_progress * 12.0, deg_to_rad(240.0), deg_to_rad(345.0), 24, Color(210.0 / 255.0, 240.0 / 255.0, 1.0), 2.0)
	_draw_primitives.draw_preview_pentagon(canvas, shield_pos, shield_r, -90.0 + local_progress * 360.0, _draw_primitives.alpha(color, 200.0 / 255.0), Color(210.0 / 255.0, 245.0 / 255.0, 1.0), 2.0)
	_draw_primitives.draw_preview_pentagon(canvas, shield_pos, shield_r * 0.45, -90.0, Color.WHITE, Color.WHITE, 0.0)
	_draw_preview_ball(canvas, ball, 6.0, [Color(110.0 / 255.0, 150.0 / 255.0, 1.0), Color(175.0 / 255.0, 220.0 / 255.0, 1.0), Color(1.0, 250.0 / 255.0, 1.0)])
	if local_progress > 0.45:
		canvas.draw_arc(ball, 14.0, 0.0, TAU, 36, Color(1.0, 240.0 / 255.0, 220.0 / 255.0, max(50.0, 120.0 + 90.0 * sin(local_progress * TAU)) / 255.0), 2.0)
		canvas.draw_line(ball + Vector2(-16.0, 8.0), ball + Vector2(12.0, -10.0), Color.WHITE, 2.0)


func _draw_drive_curve_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle_progress: float = float(time_ms % 3000) / 3000.0
	var is_left_cycle: bool = cycle_progress < 0.5
	var local_progress: float = fposmod(cycle_progress, 0.5) * 2.0
	var curve_direction: float = -1.0 if is_left_cycle else 1.0
	var key_text: String = "A" if is_left_cycle else "D"
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var char_top: float = char_y - 18.0
	var ball_radius := 6.0
	if local_progress < 0.3:
		var phase: float = local_progress / 0.3
		var ball_y: float = preview_top - 5.0 + (char_top - 8.0 - (preview_top - 5.0)) * phase
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(curve_direction)})
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), ball_radius)
		if phase > 0.4:
			canvas.draw_arc(Vector2(center_x, ball_y), 14.0 * (1.0 + 0.1 * sin(float(time_ms) * 0.015)), 0.0, TAU, 36, Color(0.36, 0.66, 1.0), 1.6)
	elif local_progress < 0.5:
		var ball_y: float = char_top - 8.0
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(curve_direction)})
		canvas.draw_arc(Vector2(center_x, ball_y), 15.0 * (1.0 + 0.15 * sin(float(time_ms) * 0.02)), 0.0, TAU, 36, Color(0.48, 0.34, 1.0), 1.8)
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), ball_radius)
		_draw_preview_keycap(canvas, Vector2(center_x - 55.0, char_y - 8.0), key_text)
	else:
		var phase: float = (local_progress - 0.5) / 0.5
		var ease_phase: float = 1.0 - pow(1.0 - phase, 2.5)
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(curve_direction), "swing_ratio": min(1.0, phase * 2.0)})
		var start_y: float = char_top - 8.0
		var end_y: float = preview_top + 5.0
		var curve_amount: float = 40.0 * sin(ease_phase * PI)
		var ball_pos := Vector2(center_x + curve_direction * curve_amount, start_y + (end_y - start_y) * ease_phase)
		for i in range(12):
			var t: float = max(0.0, ease_phase - float(i) * 0.07)
			if t <= 0.0:
				continue
			var trail_pos := Vector2(center_x + curve_direction * 40.0 * sin(t * PI), start_y + (end_y - start_y) * t)
			var trail_mix: float = clampf(float(i) / 11.0, 0.0, 1.0)
			var trail_color: Color = Color(0.26, 0.66, 1.0, 0.88).lerp(Color(0.42, 0.22, 1.0, 0.18), trail_mix)
			canvas.draw_circle(trail_pos, max(1.2, ball_radius - float(i) * 0.42), trail_color)
		canvas.draw_circle(ball_pos, ball_radius + 4.0, Color(0.18, 0.42, 1.0, 0.38))
		canvas.draw_circle(ball_pos, ball_radius + 1.5, Color(0.42, 0.76, 1.0, 0.74))
		canvas.draw_circle(ball_pos, ball_radius - 1.0, Color.WHITE)
		canvas.draw_circle(ball_pos + Vector2(-1.0, -1.0), 2.0, Color(1.0, 1.0, 230.0 / 255.0))
		var tangent := Vector2(curve_direction * cos(ease_phase * PI) * 0.72, -1.0).normalized()
		_draw_preview_drive_lightning_lashes(canvas, ball_pos, tangent, time_ms)


# 벽력유성: 기만 활강 → 늦은 역방향 급전. 프리뷰가 팔아야 하는 정보는 "공이
# 한쪽으로 가는 걸 보스가 믿고 자리잡았다가, 코앞에서 반대로 꺾여 못 막는다"
# 딱 하나다. 그래서 보스 가드 라인 위에 보스 미니 패들을 그려 기만 지점까지
# 따라가게 하고, 급전 이후엔 따라가지 못하는 것을 보여준다.
func _draw_overdrive_meteor_break_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle: float = float(time_ms % 3200) / 3200.0
	var is_left_cycle: bool = cycle < 0.5
	var local: float = fposmod(cycle, 0.5) * 2.0
	# 방향키 = 최종 낙하 지점. 기만은 그 반대쪽으로 흐른다.
	var land_dir: float = -1.0 if is_left_cycle else 1.0
	var bait_dir: float = -land_dir
	var key_text: String = "A" if is_left_cycle else "D"

	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var char_top: float = char_y - 18.0
	var guard_y: float = preview_top + 6.0
	var launch_y: float = char_top - 8.0
	var ball_radius := 5.5
	var bait_x: float = center_x + bait_dir * 44.0
	var land_x: float = center_x + land_dir * 46.0
	# 급전은 비행의 마지막 구간에서만 일어난다(늦은 단발 역꺾임).
	var break_t := 0.68

	# 보스 가드 라인.
	canvas.draw_line(
		Vector2(center_x - 96.0, guard_y),
		Vector2(center_x + 96.0, guard_y),
		Color(1.0, 1.0, 1.0, 0.10),
		1.0
	)

	if local < 0.26:
		# 준비: 우클릭 홀드 + 방향키. 입력 창에서만 노출(스매셔 리듬).
		var phase: float = local / 0.26
		var ball_y: float = preview_top - 5.0 + (launch_y - (preview_top - 5.0)) * phase
		_draw_overdrive_preview_boss(canvas, center_x, guard_y, 0.0)
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(land_dir)})
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), ball_radius)
		if phase > 0.35:
			_draw_preview_keycap(canvas, Vector2(center_x - 58.0, char_y - 8.0), key_text)
			_draw_preview_plus(canvas, Vector2(center_x - 42.0, char_y - 8.0))
			_draw_preview_mouse(canvas, Vector2(center_x - 28.0, char_y - 8.0), false)
		return

	var flight: float = clampf((local - 0.26) / 0.74, 0.0, 1.0)
	_draw_smasher_mini_character(
		canvas,
		center_x,
		char_y,
		{"block": 4.0, "direction": int(land_dir), "swing_ratio": minf(1.0, flight * 3.0)}
	)

	# 트레일: 같은 궤도식을 샘플링해 꼬리를 남긴다.
	for i in range(14):
		var t: float = flight - float(i) * 0.055
		if t <= 0.0:
			continue
		var p: Vector2 = _overdrive_preview_point(t, break_t, center_x, bait_x, land_x, launch_y, guard_y)
		var mix: float = clampf(float(i) / 13.0, 0.0, 1.0)
		var trail_color: Color = Color(0.55, 0.92, 1.0, 0.85).lerp(Color(0.18, 0.45, 0.85, 0.12), mix)
		canvas.draw_circle(p, maxf(1.1, ball_radius - float(i) * 0.36), trail_color)

	var ball_pos: Vector2 = _overdrive_preview_point(flight, break_t, center_x, bait_x, land_x, launch_y, guard_y)
	# 보스는 기만 지점을 믿고 따라간다: 급전 전까지만 추적하고 그 뒤엔 굳는다
	# (역방향 브레이크 페널티 = 되돌아오지 못함).
	var boss_track: float = minf(flight, break_t)
	var boss_x: float = _overdrive_preview_point(
		boss_track, break_t, center_x, bait_x, land_x, launch_y, guard_y
	).x
	_draw_overdrive_preview_boss(canvas, boss_x, guard_y, clampf((flight - break_t) / 0.2, 0.0, 1.0))

	# 급전 순간의 임팩트 링.
	if flight >= break_t and flight < break_t + 0.22:
		var burst: float = (flight - break_t) / 0.22
		var burst_pos: Vector2 = _overdrive_preview_point(
			break_t, break_t, center_x, bait_x, land_x, launch_y, guard_y
		)
		canvas.draw_arc(
			burst_pos,
			4.0 + burst * 22.0,
			0.0,
			TAU,
			24,
			Color(0.55, 0.92, 1.0, (1.0 - burst) * 0.8),
			1.8
		)

	canvas.draw_circle(ball_pos, ball_radius + 4.0, Color(0.18, 0.52, 1.0, 0.34))
	canvas.draw_circle(ball_pos, ball_radius + 1.5, Color(0.45, 0.85, 1.0, 0.76))
	canvas.draw_circle(ball_pos, ball_radius - 1.0, Color.WHITE)


# 발사점 -> 기만점 -> (급전) -> 낙하점. break_t 이전은 기만 쪽으로 부드럽게
# 흐르고, 이후는 반대편으로 직선 급전한다.
func _overdrive_preview_point(
	t: float,
	break_t: float,
	center_x: float,
	bait_x: float,
	land_x: float,
	launch_y: float,
	guard_y: float
) -> Vector2:
	var clamped: float = clampf(t, 0.0, 1.0)
	var y: float = launch_y + (guard_y - launch_y) * clamped
	if clamped <= break_t:
		var glide: float = clamped / maxf(0.0001, break_t)
		# ease-out: 기만 구간은 초반에 크게 흘러 보스가 확신하게 만든다.
		var eased: float = 1.0 - pow(1.0 - glide, 2.0)
		return Vector2(center_x + (bait_x - center_x) * eased, y)
	var snap: float = (clamped - break_t) / maxf(0.0001, 1.0 - break_t)
	return Vector2(bait_x + (land_x - bait_x) * snap, y)


func _draw_overdrive_preview_boss(canvas: CanvasItem, cx: float, guard_y: float, miss_ratio: float) -> void:
	var half_w := 15.0
	var body := Rect2(Vector2(cx - half_w, guard_y - 6.0), Vector2(half_w * 2.0, 5.0))
	# 놓치는 중이면 붉게 물들여 "못 따라감"을 읽히게 한다.
	var base := Color(0.72, 0.78, 0.88, 0.85)
	var missed := Color(1.0, 0.45, 0.42, 0.9)
	_draw_primitives.draw_round_rect(canvas, body, base.lerp(missed, clampf(miss_ratio, 0.0, 1.0)), 2.0)


func _draw_preview_drive_lightning_lashes(canvas: CanvasItem, center: Vector2, direction: Vector2, time_ms: int) -> void:
	var backward: Vector2 = -direction
	var normal := Vector2(-direction.y, direction.x)
	for lash_index in range(2):
		var side: float = -1.0 if lash_index == 0 else 1.0
		var points := PackedVector2Array()
		for segment_index in range(5):
			var segment_t: float = float(segment_index) / 4.0
			var jitter: float = sin(float(time_ms) * 0.018 + float(lash_index) * 4.2 + float(segment_index) * 2.8) * 2.2 * sin(segment_t * PI)
			points.append(center + backward * (3.0 + segment_t * 20.0) + normal * (side * sin(segment_t * PI) * 3.0 + jitter))
		canvas.draw_polyline(points, Color(0.22, 0.12, 0.72, 0.66), 2.4, true)
		canvas.draw_polyline(points, Color(0.90, 0.98, 1.0, 0.92), 0.8, true)
	canvas.draw_line(center - normal * 3.0, center + normal * 3.0, Color(1.0, 0.78, 0.24, 0.80), 1.0, true)


func _draw_smasher_heavy_strike_preview(canvas: CanvasItem, rect: Rect2, _color: Color, thunder: bool) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle_progress: float = float(time_ms % 4500) / 4500.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var motion_type := "straight"
	var smash_direction := 0
	var key_text := ""
	var local_progress: float
	if cycle_progress < 0.333:
		motion_type = "left"
		smash_direction = -1
		key_text = "A"
		local_progress = cycle_progress / 0.333
	elif cycle_progress < 0.666:
		motion_type = "right"
		smash_direction = 1
		key_text = "D"
		local_progress = (cycle_progress - 0.333) / 0.333
	else:
		local_progress = (cycle_progress - 0.666) / 0.334
	var char_y: float = preview_bottom - 2.0
	var char_top: float = char_y - 18.0
	if local_progress < 0.3:
		var phase: float = local_progress / 0.3
		var ball_y: float = preview_top - 5.0 + (char_top - 8.0 - (preview_top - 5.0)) * phase
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": smash_direction})
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), 6.0)
		if phase > 0.4:
			var charge_color: Color = Color(0.32, 0.88, 1.0) if thunder else Color(1.0, 80.0 / 255.0, 80.0 / 255.0)
			canvas.draw_arc(Vector2(center_x, ball_y), 14.0 * (1.0 + 0.1 * sin(float(time_ms) * 0.015)), 0.0, TAU, 36, charge_color, 2.0)
	elif local_progress < 0.5:
		var ball_y: float = char_top - 8.0
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": smash_direction})
		var charge_color: Color = Color(0.32, 0.88, 1.0) if thunder else Color(1.0, 80.0 / 255.0, 80.0 / 255.0)
		canvas.draw_arc(Vector2(center_x, ball_y), 15.0 * (1.0 + 0.15 * sin(float(time_ms) * 0.02)), 0.0, TAU, 36, charge_color, 2.0)
		_draw_blue_energy_ball(canvas, Vector2(center_x, ball_y), 6.0)
		var keycap_x: float = center_x - 55.0
		var keycap_y: float = char_y - 8.0
		if motion_type != "straight":
			_draw_preview_keycap(canvas, Vector2(keycap_x, keycap_y), key_text)
			_draw_preview_plus(canvas, Vector2(keycap_x + 13.0, keycap_y))
			_draw_preview_mouse(canvas, Vector2(keycap_x + 23.0, keycap_y), true)
		else:
			_draw_preview_mouse(canvas, Vector2(keycap_x, keycap_y), true)
	else:
		var phase: float = (local_progress - 0.5) / 0.5
		var ease_phase: float = 1.0 - pow(1.0 - phase, 2.2)
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": smash_direction, "swing_ratio": min(1.0, phase * 2.0)})
		var start := Vector2(center_x, char_top - 8.0)
		var end := Vector2(center_x + float(smash_direction) * 54.0, preview_top + 5.0)
		if motion_type == "straight":
			end.x = center_x
		var ball_pos: Vector2 = start.lerp(end, ease_phase)
		for i in range(8):
			var t: float = max(0.0, ease_phase - float(i) * 0.1)
			if t <= 0.0:
				continue
			var trail_pos: Vector2 = start.lerp(end, t)
			var trail_color: Color
			if thunder:
				trail_color = Color(0.22 + float(i) * 0.025, 0.82 + float(i) * 0.015, 1.0)
			else:
				trail_color = Color(1.0, max(40.0, 150.0 - float(i) * 15.0) / 255.0, max(20.0, 60.0 - float(i) * 6.0) / 255.0)
			canvas.draw_circle(trail_pos, max(2.0, 6.0 - float(i) * 0.6), trail_color)
		if phase < 0.6:
			for i in range(4):
				var line_t: float = max(0.0, ease_phase - float(i) * 0.12 - 0.05)
				if line_t <= 0.0:
					continue
				var line_pos: Vector2 = start.lerp(end, line_t)
				var dir_vec: Vector2 = (end - start).normalized()
				var speed_line_color: Color = Color(0.90, 0.99, 1.0) if thunder else Color(1.0, 200.0 / 255.0, 100.0 / 255.0)
				if motion_type == "straight":
					canvas.draw_line(line_pos, line_pos + Vector2(0.0, 12.0 * (1.0 - float(i) * 0.2)), speed_line_color, 1.0)
				else:
					canvas.draw_line(line_pos, line_pos - dir_vec * (12.0 * (1.0 - float(i) * 0.2)), speed_line_color, 1.0)
		var ball_palette: Array[Color] = [
			Color(1.0, 80.0 / 255.0, 40.0 / 255.0),
			Color(1.0, 180.0 / 255.0, 70.0 / 255.0),
			Color(1.0, 245.0 / 255.0, 190.0 / 255.0),
		]
		if thunder:
			ball_palette = [
				Color(0.08, 0.32, 1.0),
				Color(0.26, 0.86, 1.0),
				Color(0.92, 0.99, 1.0),
			]
		var ball_highlight: Color = Color(1.0, 0.84, 0.30) if thunder else Color(1.0, 220.0 / 255.0, 120.0 / 255.0)
		_draw_preview_ball(canvas, ball_pos, 6.0, ball_palette, ball_highlight)
		if thunder:
			_draw_preview_thunder_corona(canvas, ball_pos, time_ms, phase)
		if phase < 0.25:
			var impact_color: Color = Color(0.32, 0.88, 1.0) if thunder else Color(1.0, 140.0 / 255.0, 70.0 / 255.0)
			canvas.draw_arc(start, 12.0 + phase * 35.0, 0.0, TAU, 36, impact_color, 2.0)


func _draw_preview_thunder_corona(canvas: CanvasItem, center: Vector2, time_ms: int, phase: float) -> void:
	for branch_index in range(5):
		var angle: float = TAU * float(branch_index) / 5.0 + float(time_ms) * 0.0012
		var direction := Vector2(cos(angle), sin(angle))
		var perpendicular := Vector2(-direction.y, direction.x)
		var points := PackedVector2Array([center])
		for point_index in range(1, 4):
			var point_t: float = float(point_index) / 3.0
			var jitter: float = sin(float(time_ms) * 0.012 + float(branch_index) * 3.7 + float(point_index) * 4.9) * 3.0 * sin(point_t * PI)
			points.append(center + direction * lerpf(4.0, 18.0 + phase * 5.0, point_t) + perpendicular * jitter)
		canvas.draw_polyline(points, Color(0.08, 0.30, 1.0, 0.62), 3.0, true)
		canvas.draw_polyline(points, Color(0.92, 0.99, 1.0, 0.92), 1.0, true)


func _draw_magnetic_pull_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3000) / 3000.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var ball_top_y: float = preview_top + 8.0
	if local_progress < 0.30:
		var phase: float = local_progress / 0.30
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		for ring_idx in range(3):
			canvas.draw_arc(p_center, p_radius * 1.6 + float(ring_idx) * 6.0 + phase * 14.0, 0.0, TAU, 36, _draw_primitives.alpha(color, max(40.0, 180.0 * (1.0 - phase * 0.4) - float(ring_idx) * 35.0) / 255.0), 1.0)
		for spark_idx in range(8):
			var ang: float = TAU * float(spark_idx) / 8.0 + float(time_ms) * 0.005
			var sd: float = p_radius * 1.2 + sin(float(time_ms) * 0.01 + float(spark_idx)) * 3.0
			canvas.draw_circle(p_center + Vector2(cos(ang), sin(ang)) * sd, 2.0, _draw_primitives.alpha(color, 200.0 / 255.0))
		_draw_preview_ball(canvas, Vector2(center_x, ball_top_y), 6.0, [color, Color(180.0 / 255.0, 230.0 / 255.0, 1.0), Color.WHITE], Color(1.0, 240.0 / 255.0, 180.0 / 255.0))
		_draw_preview_keycap(canvas, Vector2(center_x - 60.0, char_y - 8.0), "A")
		_draw_preview_keycap(canvas, Vector2(center_x - 36.0, char_y - 8.0), "D")
		_draw_preview_plus(canvas, Vector2(center_x - 48.0, char_y - 8.0))
	elif local_progress < 0.85:
		var phase: float = (local_progress - 0.30) / 0.55
		@warning_ignore("shadowed_global_identifier")
		var ease: float = pow(phase, 1.5)
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var target := p_center + Vector2(0.0, -p_radius - 4.0)
		var ball_pos := Vector2(center_x + sin(phase * PI * 3.0) * (12.0 - phase * 10.0), ball_top_y + (target.y - ball_top_y) * ease)
		_draw_preview_keycap(canvas, Vector2(center_x - 12.0, float(metrics["top"]) + 14.0), "A")
		_draw_preview_keycap(canvas, Vector2(center_x + 12.0, float(metrics["top"]) + 14.0), "D")
		_draw_preview_plus(canvas, Vector2(center_x, float(metrics["top"]) + 14.0))
		for line_idx in range(5):
			var la: float = TAU * float(line_idx) / 5.0 + float(time_ms) * 0.006
			var start := p_center + Vector2(cos(la), sin(la)) * (p_radius + 2.0)
			var finish := ball_pos + Vector2(cos(la + PI), sin(la + PI)) * 6.0
			_draw_bezier_polyline(canvas, start, finish, 6.0, _draw_primitives.alpha(color, max(60.0, 160.0 * (1.0 - phase * 0.4)) / 255.0), 2.0)
		for trail_idx in range(6):
			var t_t: float = max(0.0, ease - float(trail_idx) * 0.1)
			if t_t <= 0.0:
				continue
			var tx: float = center_x + sin(phase * PI * 3.0 - float(trail_idx) * 0.3) * (12.0 - t_t * 10.0)
			var ty: float = ball_top_y + (target.y - ball_top_y) * t_t
			canvas.draw_circle(Vector2(tx, ty), max(2.0, 5.0 - float(trail_idx)), _draw_primitives.alpha(color, max(40.0, 180.0 - float(trail_idx) * 28.0) / 255.0))
		_draw_preview_ball(canvas, ball_pos, 6.0, [color, Color(180.0 / 255.0, 230.0 / 255.0, 1.0), Color.WHITE], Color(1.0, 240.0 / 255.0, 180.0 / 255.0))
	else:
		var phase: float = (local_progress - 0.85) / 0.15
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
		var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var burst := p_center + Vector2(0.0, -p_radius - 4.0)
		canvas.draw_arc(burst, p_radius * 1.4 + phase * 18.0, 0.0, TAU, 36, _draw_primitives.alpha(color, max(60.0, 220.0 * (1.0 - phase)) / 255.0), 2.0)
		for spark_idx in range(8):
			var ang: float = TAU * float(spark_idx) / 8.0
			canvas.draw_line(burst, burst + Vector2(cos(ang), sin(ang)) * ((p_radius * 1.4 + phase * 18.0) * 0.7), _draw_primitives.alpha(color, max(80.0, 220.0 * (1.0 - phase * 0.7)) / 255.0), 2.0)


func _draw_ghost_purple_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3500) / 3500.0
	@warning_ignore("integer_division")
	var cycle_dir: float = -1.0 if int(time_ms / 3500) % 2 == 0 else 1.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	if local_progress < 0.30:
		var phase: float = local_progress / 0.30
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "paddle_lift": phase * 0.5})
		_draw_ghost_charge(canvas, anchors, color, phase, time_ms)
	elif local_progress < 0.50:
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "paddle_lift": 0.5})
		_draw_ghost_charge(canvas, anchors, color, 1.0, time_ms)
		var keycap := Vector2(center_x - 64.0, char_y - 8.0)
		_draw_preview_keycap(canvas, keycap, "A" if cycle_dir < 0.0 else "D")
		_draw_preview_plus(canvas, keycap + Vector2(13.0, 0.0))
		_draw_preview_mouse(canvas, keycap + Vector2(23.0, 0.0), true)
	else:
		var phase: float = (local_progress - 0.50) / 0.50
		var anchors: Dictionary = _draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "direction": int(cycle_dir), "swing_ratio": min(1.0, phase * 1.6)})
		var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
		var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
		var p_radius: float = float(paddle.get("radius", 6.0))
		var start := p_center + Vector2(0.0, -p_radius - 4.0)
		var end_y: float = preview_top + 6.0
		@warning_ignore("shadowed_global_identifier")
		var ease: float = 1.0 - pow(1.0 - phase, 2.5)
		var ball_pos := Vector2(start.x + sin(phase * PI * 5.0) * 18.0 * cycle_dir * ease, start.y + (end_y - start.y) * ease)
		for trail_idx in range(10):
			var t: float = max(0.0, ease - float(trail_idx) * 0.08)
			if t <= 0.0:
				continue
			var trail_pos := Vector2(start.x + sin(phase * PI * 5.0 - float(trail_idx) * 0.4) * 18.0 * cycle_dir * t, start.y + (end_y - start.y) * t)
			canvas.draw_circle(trail_pos, max(2.0, 6.0 - float(trail_idx) * 0.5), _draw_primitives.alpha(color, max(40.0, 200.0 - float(trail_idx) * 18.0) / 255.0))
		var ghost_t: float = max(0.0, ease - 0.18)
		if ghost_t > 0.0:
			var ghost_pos := Vector2(start.x + sin(phase * PI * 5.0 - 0.9) * 18.0 * cycle_dir * ghost_t, start.y + (end_y - start.y) * ghost_t)
			_draw_small_ghost(canvas, ghost_pos, color, time_ms)
		_draw_preview_ball(canvas, ball_pos, 6.0, [color, Color(180.0 / 255.0, 110.0 / 255.0, 1.0), Color(235.0 / 255.0, 200.0 / 255.0, 1.0)], color)


# 허공환영: ↓+좌클릭 입력 창 → 타구 → 실제 공 1 + 좌우 환영 2가 함께 상승 →
# 보스가 환영을 가드(빗나감). 입력 키캡은 스매셔 리듬대로 준비 구간에만 뜬다.
func _draw_void_phantom_split_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3600) / 3600.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var guard_y: float = preview_top + 10.0
	var real_color := Color(235.0 / 255.0, 200.0 / 255.0, 1.0)

	if local_progress < 0.32:
		var prep: float = local_progress / 0.32
		_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0, "paddle_lift": prep * 0.4})
		var keycap := Vector2(center_x - 30.0, char_y - 26.0)
		_draw_preview_keycap(canvas, keycap, "S")
		_draw_preview_plus(canvas, keycap + Vector2(13.0, 0.0))
		_draw_preview_mouse(canvas, keycap + Vector2(23.0, 0.0), true)
		_draw_overdrive_preview_boss(canvas, center_x, guard_y, 0.0)
		return

	var phase: float = (local_progress - 0.32) / 0.68
	@warning_ignore("shadowed_global_identifier")
	var ease: float = 1.0 - pow(1.0 - phase, 2.2)
	var anchors: Dictionary = _draw_smasher_mini_character(
		canvas,
		center_x,
		char_y,
		{"block": 4.0, "swing_ratio": min(1.0, phase * 2.0)}
	)
	var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
	var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2(center_x, char_y - 18.0))
	var start := p_center + Vector2(0.0, -float(paddle.get("radius", 6.0)) - 4.0)
	var end_y: float = guard_y - 2.0
	var rise: float = start.y + (end_y - start.y) * ease

	# 실전처럼 환영 2개가 항상 좌우로, 기존 프리뷰보다 더 넓게 갈라진다.
	var phantom_offsets: Array[float] = _build_void_phantom_offsets()
	var phantom_positions: Array[Vector2] = []
	for offset in phantom_offsets:
		phantom_positions.append(Vector2(start.x + offset * ease, rise))
	var real_pos := Vector2(start.x, rise)

	# 보스는 환영 하나를 진짜로 착각해 그쪽을 막는다 — 실제 공은 그대로 통과.
	var guard_x: float = phantom_positions[0].x if not phantom_positions.is_empty() else real_pos.x
	_draw_overdrive_preview_boss(canvas, guard_x, guard_y, clampf((ease - 0.55) / 0.45, 0.0, 1.0))

	for phantom_pos in phantom_positions:
		canvas.draw_arc(phantom_pos, 8.0, 0.0, TAU, 24, _draw_primitives.alpha(color, 0.45), 1.5)
		_draw_preview_ball(
			canvas,
			phantom_pos,
			5.5,
			[
				_draw_primitives.alpha(color, 0.55),
				_draw_primitives.alpha(real_color, 0.55),
				_draw_primitives.alpha(Color.WHITE, 0.55),
			],
			_draw_primitives.alpha(color, 0.55)
		)
	_draw_preview_ball(canvas, real_pos, 6.0, [color, real_color, Color.WHITE], real_color)


# Godot 4.6은 조건식의 untyped 배열 리터럴을 Array[float]에 직접 대입하면
# draw 프레임마다 런타임 타입 오류를 낸다. 명시적 append로 typed 배열을 만든다.
func _build_void_phantom_offsets() -> Array[float]:
	var offsets: Array[float] = []
	offsets.append(-34.0)
	offsets.append(34.0)
	return offsets


func _draw_portal_purple_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3500) / 3500.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var char_y: float = preview_bottom - 2.0
	var portal_left := Vector2(preview_left + 14.0, char_y - 10.0)
	var portal_right := Vector2(preview_right - 14.0, char_y - 10.0)
	canvas.draw_line(Vector2(preview_left + 4.0, preview_top + 6.0), Vector2(preview_left + 4.0, preview_bottom - 4.0), Color(140.0 / 255.0, 110.0 / 255.0, 180.0 / 255.0, 60.0 / 255.0), 2.0)
	canvas.draw_line(Vector2(preview_right - 4.0, preview_top + 6.0), Vector2(preview_right - 4.0, preview_bottom - 4.0), Color(140.0 / 255.0, 110.0 / 255.0, 180.0 / 255.0, 60.0 / 255.0), 2.0)
	for side_idx in range(2):
		var portal: Vector2 = portal_left if side_idx == 0 else portal_right
		for ring_idx in range(3):
			var rx: float = 12.0 - float(ring_idx) * 3.0
			var ry: float = 18.0 - float(ring_idx) * 4.0
			_draw_primitives.draw_ellipse(canvas, Rect2(portal - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), _draw_primitives.alpha(color, max(80.0, 220.0 - float(ring_idx) * 50.0) / 255.0), false, 2.0)
		for swirl_idx in range(5):
			var spin_dir: float = 1.0 if side_idx == 0 else -1.0
			var ang: float = TAU * float(swirl_idx) / 5.0 + float(time_ms) * 0.006 * spin_dir
			canvas.draw_circle(portal + Vector2(cos(ang) * 8.0, sin(ang) * 12.0), 2.0, Color(1.0, 220.0 / 255.0, 1.0))
	_draw_smasher_mini_character(canvas, center_x, char_y, {"block": 4.0})
	@warning_ignore("integer_division")
	_draw_preview_keycap_row(canvas, Vector2(center_x, preview_top + 14.0), ["A", "W", "D"], "arrow", int(time_ms / 600) % 3, color)
	var ball_pos: Vector2
	var ball_alpha := 1.0
	var ball_visible := true
	if local_progress < 0.40:
		var phase: float = local_progress / 0.40
		ball_pos = Vector2(center_x + phase * (portal_right.x - center_x), portal_right.y - 2.0)
	elif local_progress < 0.50:
		var phase: float = (local_progress - 0.40) / 0.10
		ball_pos = portal_right + Vector2(0.0, -2.0)
		ball_alpha = max(0.0, 1.0 - phase)
		ball_visible = ball_alpha > 0.0
		canvas.draw_arc(portal_right, 14.0 + phase * 8.0, 0.0, TAU, 36, _draw_primitives.alpha(color, 0.70 * (1.0 - phase)), 2.0)
	elif local_progress < 0.60:
		var phase: float = (local_progress - 0.50) / 0.10
		ball_pos = portal_left + Vector2(0.0, -2.0)
		ball_alpha = min(1.0, phase)
		canvas.draw_arc(portal_left, 14.0 + phase * 8.0, 0.0, TAU, 36, _draw_primitives.alpha(color, 0.70 * (1.0 - phase)), 2.0)
	else:
		var phase: float = (local_progress - 0.60) / 0.40
		ball_pos = Vector2(portal_left.x + phase * (center_x - portal_left.x), portal_left.y - 2.0)
	if ball_visible:
		_draw_preview_ball(canvas, ball_pos, 6.0, [_draw_primitives.alpha(color, ball_alpha), _draw_primitives.alpha(Color(235.0 / 255.0, 200.0 / 255.0, 1.0), ball_alpha), _draw_primitives.alpha(Color.WHITE, ball_alpha)], _draw_primitives.alpha(Color(235.0 / 255.0, 200.0 / 255.0, 1.0), ball_alpha))


func _draw_dalji_vision_chain_top_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var progress: float = float(time_ms % 2600) / 2600.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var player_center := Vector2(center_x, preview_bottom - 6.0)
	var boss_center := Vector2(center_x, preview_top + 10.0)
	canvas.draw_rect(Rect2(boss_center + Vector2(-22.0, -3.0), Vector2(44.0, 6.0)), Color(0.91, 0.72, 0.28, 0.82), true)
	canvas.draw_rect(Rect2(player_center + Vector2(-24.0, -4.0), Vector2(48.0, 8.0)), Color(color.r, color.g, color.b, 0.72), true)
	var rise_ratio: float = clampf(progress / 0.55, 0.0, 1.0)
	var top_positions: Array[Vector2] = []
	for side: float in [-1.0, 1.0]:
		var start: Vector2 = player_center + Vector2(side * 12.0, -8.0)
		var end: Vector2 = Vector2(center_x + side * 60.0, preview_top + 42.0)
		var top_pos: Vector2 = start.lerp(end, rise_ratio) + Vector2(side * sin(rise_ratio * PI) * 12.0, -sin(rise_ratio * PI) * 10.0)
		top_positions.append(top_pos)
		canvas.draw_line(top_pos, top_pos + Vector2(-side * 18.0, 18.0), Color(color.r, color.g, color.b, 0.34), 3.0, true)
		var spin: float = progress * TAU * 8.0 * side
		canvas.draw_arc(top_pos, 9.0, spin, spin + PI * 1.55, 18, Color(0.95, 0.76, 0.31, 0.96), 2.4, true)
		canvas.draw_circle(top_pos, 3.2, Color(0.64, 1.0, 0.94, 0.96))
	var capture_center: Vector2 = top_positions[1]
	var ball_start := Vector2(preview_left + 28.0, preview_top + 48.0)
	var ball_pos := ball_start
	if progress < 0.55:
		ball_pos = ball_start.lerp(capture_center, rise_ratio)
	elif progress < 0.68:
		var coil: float = (progress - 0.55) / 0.13
		ball_pos = capture_center + Vector2(cos(coil * TAU), sin(coil * TAU)) * 11.0
		canvas.draw_arc(capture_center, 15.0 + sin(coil * PI) * 3.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.75), 2.0, true)
	else:
		var release: float = (progress - 0.68) / 0.32
		ball_pos = capture_center.lerp(boss_center, release)
		for trail_index in range(5):
			var trail_t: float = maxf(0.0, release - float(trail_index) * 0.08)
			canvas.draw_circle(capture_center.lerp(boss_center, trail_t), maxf(1.4, 5.0 - float(trail_index) * 0.7), Color(color.r, color.g, color.b, maxf(0.08, 0.38 - float(trail_index) * 0.06)))
	_draw_preview_ball(canvas, ball_pos, 5.5, [color, Color(0.72, 1.0, 0.94), Color.WHITE])
	_draw_preview_keycap_row(canvas, Vector2(preview_right - 58.0, preview_bottom - 12.0), ["A", "D", "A"], "arrow", min(2, int(progress * 4.5)), color)


func _draw_cheongringwi_vision_dragon_torrent_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle: float = float(time_ms % 2400) / 2400.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var quake_offset := Vector2(sin(cycle * TAU * 19.0), cos(cycle * TAU * 23.0)) * (2.4 * (1.0 - cycle))
	var boss_center := Vector2(center_x, preview_top + 10.0) + quake_offset
	var player_center := Vector2(center_x, preview_bottom - 6.0) + quake_offset
	canvas.draw_rect(Rect2(boss_center + Vector2(-22.0, -3.0), Vector2(44.0, 6.0)), Color(0.32, 0.27, 0.12, 0.90), true)
	canvas.draw_rect(Rect2(player_center + Vector2(-24.0, -4.0), Vector2(48.0, 8.0)), Color(color.r, color.g, color.b, 0.74), true)
	for wave_index in range(3):
		var wave_y := lerpf(preview_top + 26.0, preview_bottom - 20.0, float(wave_index) / 2.0)
		var wave_points := PackedVector2Array()
		for point_index in range(9):
			var point_ratio := float(point_index) / 8.0
			wave_points.append(Vector2(lerpf(preview_left + 10.0, preview_right - 10.0, point_ratio), wave_y + sin(cycle * TAU * 8.0 + float(point_index)) * 2.0) + quake_offset)
		canvas.draw_polyline(wave_points, Color(0.70, 0.92, 0.30, 0.18), 1.4, true)
	for rock_index in range(4):
		var local_progress := fposmod(cycle * 1.42 - float(rock_index) * 0.19, 1.0)
		var rock_x := lerpf(preview_left + 26.0, preview_right - 26.0, float(rock_index) / 3.0)
		var landing_y := preview_bottom - 28.0 - float(rock_index % 2) * 22.0
		var rock_y := lerpf(preview_top - 18.0, landing_y, 1.0 - pow(1.0 - local_progress, 3.0))
		var rock_center := Vector2(rock_x, rock_y) + quake_offset
		var rock_radius := 6.5 + float(rock_index % 2) * 1.5
		var rock_points := PackedVector2Array()
		for point_index in range(7):
			var angle := TAU * float(point_index) / 7.0
			var jag := 0.82 + 0.18 * sin(float(point_index) * 4.7 + float(rock_index))
			rock_points.append(rock_center + Vector2.from_angle(angle) * rock_radius * jag)
		canvas.draw_colored_polygon(rock_points, Color(0.48, 0.34, 0.15, 0.96))
		rock_points.append(rock_points[0])
		canvas.draw_polyline(rock_points, Color(0.94, 0.76, 0.28, 0.86), 1.2, true)
		canvas.draw_circle(Vector2(rock_x, landing_y + rock_radius * 0.6) + quake_offset, rock_radius * (0.18 + local_progress * 0.30), Color(0.04, 0.03, 0.01, 0.22))
	_draw_preview_keycap_row(canvas, Vector2(preview_right - 58.0, preview_bottom - 12.0), ["D", "A", "D"], "arrow", min(2, int(cycle * 4.5)), color)


func _draw_yeonmyo_vision_bonghongwe_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle := float(time_ms % 2600) / 2600.0
	var left := float(metrics["left"])
	var right := float(metrics["right"])
	var top := float(metrics["top"])
	var bottom := float(metrics["bottom"])
	var boss_y := top + 13.0
	var chest_center := Vector2(lerpf(left + 42.0, right - 42.0, 0.52), top + 43.0)
	var dash_x := lerpf(left + 12.0, right - 12.0, cycle)
	canvas.draw_rect(Rect2(Vector2(dash_x - 21.0, boss_y - 3.0), Vector2(42.0, 6.0)), Color(0.72, 0.58, 0.82, 0.86), true)
	for trail_index in range(4):
		var trail_x := dash_x - float(trail_index + 1) * 12.0
		canvas.draw_line(Vector2(trail_x, boss_y), Vector2(trail_x + 8.0, boss_y), Color(color.r, color.g, color.b, 0.34), 2.0)
	canvas.draw_circle(chest_center, 30.0, Color(color.r, color.g, color.b, 0.10))
	canvas.draw_arc(chest_center, 30.0, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.34), 1.5, true)
	var body := Rect2(chest_center + Vector2(-17.0, -8.0), Vector2(34.0, 22.0))
	canvas.draw_rect(body, Color(0.18, 0.06, 0.24, 0.96), true)
	canvas.draw_rect(body, color, false, 2.0)
	canvas.draw_rect(Rect2(chest_center + Vector2(-19.0, -14.0), Vector2(38.0, 9.0)), Color(0.34, 0.10, 0.43, 1.0), true)
	canvas.draw_circle(chest_center + Vector2(0.0, 3.0), 3.0, Color(1.0, 0.78, 0.28, 1.0))
	canvas.draw_rect(Rect2(Vector2(left + 24.0, bottom - 8.0), Vector2(right - left - 48.0, 5.0)), Color(0.25, 0.18, 0.30, 0.75), true)
	_draw_preview_keycap_row(canvas, Vector2(right - 37.0, bottom - 13.0), ["S"], "plus", 0, color)


func _draw_wheel_spin_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2400) / 2400.0
	var direction: float = -1.0 if local_progress < 0.5 else 1.0
	var phase: float = fposmod(local_progress, 0.5) * 2.0
	var eased: float = 0.5 - 0.5 * cos(phase * PI)
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var floor_y: float = preview_bottom - 4.0
	var start_x: float = center_x - direction * 56.0
	var end_x: float = center_x + direction * 56.0
	var char_x: float = start_x + (end_x - start_x) * eased
	canvas.draw_line(Vector2(preview_left + 12.0, floor_y), Vector2(preview_right - 12.0, floor_y), Color(0.30, 0.42, 0.58, 0.24), 2.0)
	for stripe_idx in range(4):
		var stripe_y: float = preview_top + 14.0 + float(stripe_idx) * 16.0
		var stripe_offset: float = fposmod(phase * 40.0 + float(stripe_idx) * 9.0, 24.0)
		canvas.draw_line(Vector2(preview_left + stripe_offset, stripe_y), Vector2(preview_right - 8.0, stripe_y - direction * 2.0), Color(0.66, 0.84, 1.0, (30.0 + float(stripe_idx) * 8.0) / 255.0), 1.0)
	for trail_idx in range(5):
		var trail_t: float = max(0.0, eased - float(trail_idx) * 0.10)
		var tx: float = start_x + (end_x - start_x) * trail_t
		var cloud_alpha: float = max(18.0, 138.0 - float(trail_idx) * 22.0) / 255.0
		var cloud_center := Vector2(tx, floor_y - 34.0 + sin(phase * TAU + float(trail_idx)) * 3.0)
		canvas.draw_circle(cloud_center + Vector2(-10.0, 1.0), max(3.0, 9.0 - float(trail_idx) * 0.7), Color(0.72, 0.84, 0.98, cloud_alpha * 0.72))
		canvas.draw_circle(cloud_center, max(4.0, 12.0 - float(trail_idx) * 0.8), Color(0.92, 0.96, 1.0, cloud_alpha))
		canvas.draw_circle(cloud_center + Vector2(11.0, 2.0), max(3.0, 8.0 - float(trail_idx) * 0.6), Color(0.78, 0.88, 1.0, cloud_alpha * 0.78))
	var spin: float = phase * TAU * 3.0 * direction
	for ring_idx in range(3):
		var rx: float = 28.0 + float(ring_idx) * 7.0
		var ry: float = 16.0 + float(ring_idx) * 4.0
		var ring_center := Vector2(char_x, floor_y - 44.0)
		_draw_primitives.draw_ellipse_arc(canvas, Rect2(ring_center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), spin + float(ring_idx) * 0.8, spin + float(ring_idx) * 0.8 + deg_to_rad(235.0), Color(0.78, 0.90, 1.0, max(70.0, 184.0 - float(ring_idx) * 38.0) / 255.0), max(2.0, 4.0 - float(ring_idx)))
	_draw_smasher_mini_character(canvas, char_x, floor_y + 1.0, {"block": 4.0, "direction": int(direction), "swing_ratio": 0.6, "rotation": -spin * 0.28, "rotation_center": Vector2(char_x, floor_y - 28.0)})
	var hit_t: float = clamp((phase - 0.38) / 0.62, 0.0, 1.0)
	var ball_start := Vector2(char_x + direction * 18.0, floor_y - 30.0)
	var ball_end := Vector2(center_x + direction * 42.0, preview_top + 8.0)
	var ball_pos: Vector2 = ball_start.lerp(ball_end, hit_t)
	for trail_idx in range(7):
		var t: float = max(0.0, hit_t - float(trail_idx) * 0.08)
		if t <= 0.0:
			continue
		canvas.draw_circle(ball_start.lerp(ball_end, t), max(2.0, 6.0 - float(trail_idx) * 0.5), Color(0.70, 0.88, 1.0, max(40.0, 170.0 - float(trail_idx) * 18.0) / 255.0))
	_draw_preview_ball(canvas, ball_pos, 6.0, [Color(0.28, 0.58, 0.92), Color(0.72, 0.90, 1.0), Color.WHITE])
	_draw_preview_keycap_row(canvas, Vector2(center_x, preview_top + 14.0), ["A" if direction < 0.0 else "D", "A" if direction < 0.0 else "D", "A" if direction < 0.0 else "D"], "arrow", min(2, int(phase * 3.0)), color)


func _draw_viper_shadow_teleport_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2200) / 2200.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var start_x: float = center_x + 56.0
	var end_x: float = center_x - 48.0
	var char_y: float = preview_bottom - 4.0
	var teleport_t: float = min(1.0, local_progress / 0.58)
	var teleport_ease: float = 1.0 - pow(1.0 - teleport_t, 2.0)
	var current_x: float = lerp(start_x, end_x, teleport_ease)
	var current_y: float = char_y - sin(teleport_ease * PI) * 7.0
	for portal_idx in range(2):
		var portal_x: float = start_x if portal_idx == 0 else end_x
		var ring_phase: float = local_progress if portal_idx == 0 else fposmod(local_progress + 0.35, 1.0)
		for ring_idx in range(3):
			var ring_r: float = 10.0 + float(ring_idx) * 6.0 + sin((ring_phase + float(ring_idx) * 0.12) * TAU) * 2.0
			canvas.draw_arc(Vector2(portal_x, char_y - 6.0), ring_r, 0.0, TAU, 36, _draw_primitives.color8(120, 60, 220, max(30.0, 120.0 - float(ring_idx) * 28.0)), 2.0)
	for block_idx in range(10):
		var t: float = float(block_idx) / 9.0
		var px: float = lerp(start_x, end_x, t)
		@warning_ignore("integer_division")
		var noise: float = sin(float(time_ms / 32 + block_idx * 17)) * 10.0
		var py: float = char_y - 18.0 + noise
		var block_w: float = 6.0 + float(block_idx % 3) * 3.0
		var block_h: float = 2.0 + float(block_idx % 2)
		var block_color: Color = _draw_primitives.color8(110, 255, 205, 62) if block_idx % 2 == 0 else _draw_primitives.color8(185, 90, 255, 62)
		canvas.draw_rect(Rect2(Vector2(px - block_w * 0.5, py), Vector2(block_w, block_h)), block_color, true)
	for ghost_idx in range(4):
		var ghost_t: float = max(0.0, teleport_ease - float(ghost_idx) * 0.14)
		var ghost_x: float = lerp(start_x, end_x, ghost_t)
		var ghost_y: float = char_y - sin(ghost_t * PI) * 6.0
		var ghost_tint: Color = _draw_primitives.color8(120, 255, 205) if ghost_idx % 2 == 0 else _draw_primitives.color8(185, 90, 255)
		_draw_viper_mini_character(canvas, ghost_x, ghost_y, {"pose": "kick_left", "direction": -1, "alpha": max(0.15, (150.0 - float(ghost_idx) * 28.0) / 255.0), "tint": ghost_tint})
	_draw_viper_mini_character(canvas, current_x, current_y, {"pose": "kick_left", "direction": -1})
	if local_progress > 0.62:
		_draw_viper_mini_character(canvas, start_x, char_y - 1.0, {"pose": "kick_left", "direction": -1, "alpha": 96.0 / 255.0, "tint": _draw_primitives.color8(190, 90, 255)})
	var ball_pos := Vector2(center_x + 16.0, preview_top + 21.0 + sin(local_progress * TAU * 2.0) * 2.0)
	_draw_preview_ball(canvas, ball_pos, 6.0)
	if local_progress > 0.58:
		var hit_ring: float = 8.0 + (local_progress - 0.58) / 0.42 * 18.0
		canvas.draw_arc(ball_pos, hit_ring, 0.0, TAU, 36, _draw_primitives.color8(180, 90, 255, 170), 2.0)
		canvas.draw_line(ball_pos + Vector2(-16.0, 7.0), ball_pos + Vector2(18.0, -6.0), _draw_primitives.color8(210, 200, 255), 2.0)
		canvas.draw_line(ball_pos + Vector2(-12.0, -9.0), ball_pos + Vector2(10.0, 9.0), _draw_primitives.color8(120, 255, 205), 1.0)


func _draw_viper_blade_preview(canvas: CanvasItem, rect: Rect2, _color: Color, dark_mode: bool) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle_ms: int = 2500 if dark_mode else 2400
	var local_progress: float = float(time_ms % cycle_ms) / float(cycle_ms)
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var caster_x: float = center_x - 2.0 if dark_mode else center_x - 4.0
	var caster_y: float = preview_bottom - 18.0 - sin(local_progress * TAU) * 2.0
	var glow_color: Color = _draw_primitives.color8(165, 24, 32) if dark_mode else _draw_primitives.color8(186, 98, 255)
	_draw_viper_mini_character(canvas, caster_x + 2.0, caster_y + 1.0, {"alpha": 165.0 / 255.0, "tint": glow_color})
	_draw_viper_mini_character(canvas, caster_x, caster_y)
	var halo_center := Vector2(caster_x, caster_y - 14.0)
	if dark_mode:
		var halo_r: float = 18.0 + 4.0 * sin(local_progress * TAU * 2.0)
		canvas.draw_circle(halo_center, halo_r, _draw_primitives.color8(90, 8, 14, 55))
		canvas.draw_circle(halo_center, max(8.0, halo_r - 7.0), _draw_primitives.color8(185, 34, 42, 80))
	else:
		var flame_base_y: float = caster_y + 4.0
		for flame_idx in range(3):
			var flame_h: float = 12.0 + float(flame_idx) * 4.0 + sin(local_progress * TAU * 2.0 + float(flame_idx)) * 2.0
			var flame_w: float = 10.0 + float(flame_idx) * 3.0
			var flame_points := PackedVector2Array([
				Vector2(caster_x - flame_w * 0.5, flame_base_y + float(flame_idx) * 3.0),
				Vector2(caster_x, flame_base_y - flame_h),
				Vector2(caster_x + flame_w * 0.5, flame_base_y + float(flame_idx) * 3.0),
			])
			canvas.draw_colored_polygon(flame_points, _draw_primitives.color8(110 + flame_idx * 40, 50 + flame_idx * 25, 180 + flame_idx * 18, 92 - flame_idx * 18))
		var charge_t: float = min(1.0, local_progress / 0.34)
		for ring_idx in range(2):
			canvas.draw_arc(halo_center - Vector2(0.0, 8.0), 9.0 + float(ring_idx) * 7.0 + charge_t * 10.0, 0.0, TAU, 36, _draw_primitives.color8(196, 110, 255, max(26.0, 110.0 - float(ring_idx) * 34.0)), 1.0)
	var wave_t: float = clamp((local_progress - (0.12 if dark_mode else 0.18)) / (0.88 if dark_mode else 0.82), 0.0, 1.0)
	var wave_tip_y: float = caster_y - (16.0 if dark_mode else 18.0) - wave_t * (38.0 if dark_mode else 34.0)
	var wave_tip_x: float = center_x + 10.0 if dark_mode else center_x + 8.0 + sin(local_progress * TAU) * 2.0
	_draw_viper_blade_wave(canvas, Vector2(wave_tip_x, wave_tip_y), wave_t, dark_mode)
	var ball_pos := Vector2(center_x + 16.0 if dark_mode else center_x + 14.0, preview_top + 16.0 if dark_mode else preview_top + 15.0)
	var glow_colors: Array = [_draw_primitives.color8(80, 8, 18), _draw_primitives.color8(185, 42, 52), _draw_primitives.color8(255, 196, 170)] if dark_mode else []
	_draw_preview_ball(canvas, ball_pos, 6.0, glow_colors, _draw_primitives.color8(255, 242, 225) if dark_mode else Color.WHITE)
	if wave_t > 0.52:
		var ring_radius: float = 12.0 + (wave_t - 0.52) / 0.48 * 12.0
		var ring_color: Color = _draw_primitives.color8(235, 62, 60, 190) if dark_mode else _draw_primitives.color8(210, 170, 255, 180)
		canvas.draw_arc(ball_pos, ring_radius, 0.0, TAU, 36, ring_color, 2.0)
		for spark_idx in range(6 if not dark_mode else 0):
			var spark_angle: float = float(spark_idx) / 6.0 * TAU + local_progress * PI
			var spark_len: float = 10.0 + float(spark_idx)
			canvas.draw_line(ball_pos, ball_pos + Vector2(cos(spark_angle), sin(spark_angle)) * spark_len, _draw_primitives.color8(250, 238, 255), 1.0)


func _draw_viper_stun_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2500) / 2500.0
	var center_x: float = float(metrics["center_x"])
	var preview_bottom: float = float(metrics["bottom"])
	var start_x: float = center_x - 92.0
	var strike_x: float = center_x + 48.0
	var return_x: float = center_x - 56.0
	var target_x: float = center_x + 22.0
	var target_base_y: float = preview_bottom - 6.0
	var stun_phase: float = max(0.0, (local_progress - 0.34) / 0.66)
	_draw_viper_target_dummy(canvas, Vector2(target_x, target_base_y), _draw_primitives.color8(190, 90, 255), stun_phase)
	var char_x: float
	var char_y: float
	var pose := "fly_right"
	var direction := 1
	if local_progress < 0.38:
		var move_t: float = local_progress / 0.38
		var move_ease: float = 1.0 - pow(1.0 - move_t, 2.0)
		char_x = lerp(start_x, strike_x, move_ease)
		char_y = preview_bottom - 8.0 - sin(move_t * PI) * 12.0
		for ghost_idx in range(4):
			var ghost_t: float = max(0.0, move_ease - float(ghost_idx) * 0.12)
			_draw_viper_mini_character(canvas, lerp(start_x, strike_x, ghost_t), preview_bottom - 8.0 - sin(ghost_t * PI) * 12.0, {"pose": pose, "direction": direction, "alpha": max(0.13, (125.0 - float(ghost_idx) * 24.0) / 255.0), "tint": _draw_primitives.color8(186, 98, 255)})
	elif local_progress < 0.74:
		char_x = strike_x
		char_y = preview_bottom - 12.0
		for slash_idx in range(3):
			var slash_offset: float = float(slash_idx) * 3.0
			var slash_color: Color = [_draw_primitives.color8(255, 215, 250, 210), _draw_primitives.color8(186, 98, 255, 168), _draw_primitives.color8(120, 255, 205, 126)][slash_idx]
			canvas.draw_line(Vector2(target_x - 18.0 - slash_offset, target_base_y - 44.0 + slash_offset), Vector2(target_x + 20.0 + slash_offset, target_base_y - 6.0 - slash_offset), slash_color, max(1.0, 3.0 - float(slash_idx)))
			canvas.draw_line(Vector2(target_x + 18.0 + slash_offset, target_base_y - 44.0 + slash_offset), Vector2(target_x - 20.0 - slash_offset, target_base_y - 4.0 - slash_offset), _draw_primitives.alpha(slash_color, 0.85), max(1.0, 2.0 - float(slash_idx) * 0.4))
	else:
		var return_t: float = (local_progress - 0.74) / 0.26
		var return_ease: float = return_t * return_t * (3.0 - 2.0 * return_t)
		pose = "kick_left"
		direction = -1
		char_x = lerp(strike_x, return_x, return_ease)
		char_y = preview_bottom - 8.0 - sin((1.0 - return_t) * PI) * 6.0
		for ghost_idx in range(4):
			var ghost_t: float = max(0.0, return_ease - float(ghost_idx) * 0.12)
			_draw_viper_mini_character(canvas, lerp(strike_x, return_x, ghost_t), preview_bottom - 8.0 - sin((1.0 - ghost_t) * PI) * 6.0, {"pose": pose, "direction": direction, "alpha": max(0.11, (120.0 - float(ghost_idx) * 22.0) / 255.0), "tint": _draw_primitives.color8(120, 255, 205)})
	_draw_viper_mini_character(canvas, char_x, char_y, {"pose": pose, "direction": direction})


func _draw_viper_dive_impact_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2300) / 2300.0
	var center_x: float = float(metrics["center_x"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var impact_x: float = center_x
	var air_start_y: float = preview_top + 18.0
	var ground_y: float = preview_bottom - 6.0
	var ball_pos := Vector2(center_x + 20.0, preview_top + 18.0)
	_draw_preview_ball(canvas, ball_pos, 6.0, [_draw_primitives.color8(110, 110, 255), _draw_primitives.color8(170, 180, 255), _draw_primitives.color8(255, 245, 255)])
	if local_progress < 0.5:
		var dive_t: float = local_progress / 0.5
		var dive_ease: float = dive_t * dive_t * (3.0 - 2.0 * dive_t)
		var char_y: float = lerp(air_start_y, ground_y, dive_ease)
		_draw_viper_mini_character(canvas, impact_x, char_y, {"pose": "fly_down"})
		for line_idx in range(4):
			var lx: float = impact_x - 18.0 + float(line_idx) * 12.0
			canvas.draw_line(Vector2(lx, char_y - 36.0 + float(line_idx) * 3.0), Vector2(lx, char_y - 8.0 + float(line_idx) * 6.0), _draw_primitives.color8(200, 160, 255, 90), 1.0)
		for flame_idx in range(3):
			var flame_h: float = 16.0 + float(flame_idx) * 4.0 + dive_t * 7.0
			var flame_w: float = 10.0 + float(flame_idx) * 4.0
			var flame_points := PackedVector2Array([
				Vector2(impact_x - flame_w * 0.5, char_y + 3.0 + float(flame_idx) * 2.0),
				Vector2(impact_x, char_y + flame_h),
				Vector2(impact_x + flame_w * 0.5, char_y + 3.0 + float(flame_idx) * 2.0),
			])
			canvas.draw_colored_polygon(flame_points, _draw_primitives.color8(255, 142 + flame_idx * 20, 78 + flame_idx * 25, 92 - flame_idx * 18))
	else:
		_draw_viper_mini_character(canvas, impact_x, ground_y + 1.0)
		var burst_t: float = (local_progress - 0.5) / 0.5
		var ring_radius: float = 18.0 + burst_t * 34.0
		var ring_alpha: float = max(24.0, 180.0 - burst_t * 120.0)
		canvas.draw_arc(Vector2(impact_x, ground_y - 2.0), ring_radius, 0.0, TAU, 36, _draw_primitives.color8(255, 175, 88, ring_alpha), 3.0)
		canvas.draw_arc(Vector2(impact_x, ground_y - 2.0), max(10.0, ring_radius - 9.0), 0.0, TAU, 36, _draw_primitives.color8(190, 130, 255, max(20.0, ring_alpha - 36.0)), 1.0)
		for shock_idx in range(5):
			var offset: float = 8.0 + float(shock_idx) * 10.0
			var y_line: float = ground_y + 4.0 + float(shock_idx) * 2.0
			canvas.draw_line(Vector2(impact_x - offset, y_line), Vector2(impact_x + offset, y_line), _draw_primitives.color8(255, 185, 112, max(18.0, 110.0 - float(shock_idx) * 18.0)), max(1.0, 3.0 - float(shock_idx) * 0.45))
		for smoke in [[-28.0, -2.0, 10.0], [-12.0, -9.0, 13.0], [14.0, -6.0, 12.0], [30.0, 0.0, 9.0]]:
			var puff_alpha: float = max(24.0, 95.0 - burst_t * 36.0)
			canvas.draw_circle(Vector2(impact_x + float(smoke[0]), ground_y + float(smoke[1])), float(smoke[2]), _draw_primitives.color8(115, 126, 150, puff_alpha))
			canvas.draw_circle(Vector2(impact_x + float(smoke[0]) - 2.0, ground_y + float(smoke[1]) - 2.0), max(2.0, float(smoke[2]) - 4.0), _draw_primitives.color8(215, 230, 255, max(10.0, puff_alpha - 30.0)))
		canvas.draw_arc(ball_pos, 9.0 + burst_t * 10.0, 0.0, TAU, 36, _draw_primitives.color8(190, 150, 255, 140), 2.0)


func _draw_viper_core_flip_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle_progress: float = float(time_ms % 3200) / 3200.0
	@warning_ignore("integer_division")
	var start_from_left: bool = int(time_ms / 3200) % 2 == 0
	var dash_dir: float = 1.0 if start_from_left else -1.0
	var center_x: float = float(metrics["center_x"])
	var center_y: float = float(metrics["center_y"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var floor_y: float = preview_bottom - 6.0
	var wall_left_x: float = preview_left + 18.0
	var wall_right_x: float = preview_right - 18.0
	var ball_pos := Vector2(center_x + dash_dir * 8.0, preview_top + 16.0)
	_draw_preview_ball(canvas, ball_pos, 6.0, [_draw_primitives.color8(92, 110, 255), _draw_primitives.color8(188, 126, 255), _draw_primitives.color8(255, 240, 255)])
	for wx in [wall_left_x, wall_right_x]:
		canvas.draw_line(Vector2(wx, preview_top + 6.0), Vector2(wx, preview_bottom - 2.0), _draw_primitives.color8(255, 150, 220, 115), 2.0)
		for mark_idx in range(3):
			var my: float = preview_top + 20.0 + float(mark_idx) * 16.0
			canvas.draw_line(Vector2(wx - 8.0, my), Vector2(wx + 8.0, my + 5.0), _draw_primitives.color8(255, 180, 235, 115), 1.0)
	var activation := Vector2(center_x, floor_y - 8.0)
	canvas.draw_arc(activation, 14.0 + sin(cycle_progress * TAU * 2.0) * 2.0, 0.0, TAU, 36, _draw_primitives.color8(255, 138, 208, 95), 2.0)
	for arrow_sign in [-1.0, 1.0]:
		var arrow_y: float = floor_y - 18.0
		var tail_x: float = center_x + arrow_sign * 34.0
		var tip_x: float = center_x + arrow_sign * 10.0
		canvas.draw_line(Vector2(tail_x, arrow_y), Vector2(tip_x, arrow_y), _draw_primitives.color8(255, 220, 242, 150), 2.0)
		var head := PackedVector2Array([
			Vector2(tip_x, arrow_y),
			Vector2(tip_x + arrow_sign * 5.0, arrow_y - 4.0),
			Vector2(tip_x + arrow_sign * 5.0, arrow_y + 4.0),
		])
		canvas.draw_colored_polygon(head, _draw_primitives.color8(255, 220, 242, 170))
	if cycle_progress < 0.22:
		var dash_t: float = cycle_progress / 0.22
		var dash_ease: float = 1.0 - pow(1.0 - dash_t, 2.0)
		var start_x: float = center_x - dash_dir * 86.0
		var char_x: float = lerp(start_x, center_x, dash_ease)
		var char_y: float = floor_y - sin(dash_t * PI) * 10.0
		for ghost_idx in range(4):
			var ghost_t: float = max(0.0, dash_ease - float(ghost_idx) * 0.16)
			_draw_viper_mini_character(canvas, lerp(start_x, center_x, ghost_t), floor_y - sin(ghost_t * PI) * 10.0, {"pose": "fly_right" if dash_dir > 0.0 else "fly_left", "direction": int(dash_dir), "alpha": max(0.12, (122.0 - float(ghost_idx) * 24.0) / 255.0), "tint": _draw_primitives.color8(255, 120, 210)})
		_draw_viper_mini_character(canvas, char_x, char_y, {"pose": "fly_right" if dash_dir > 0.0 else "fly_left", "direction": int(dash_dir)})
	elif cycle_progress < 0.74:
		var climb_t: float = (cycle_progress - 0.22) / 0.52
		var path: Array = [
			Vector2(center_x, floor_y - 4.0),
			Vector2(wall_left_x if start_from_left else wall_right_x, floor_y - 10.0),
			Vector2(wall_right_x if start_from_left else wall_left_x, center_y + 6.0),
			Vector2(wall_left_x if start_from_left else wall_right_x, preview_top + 28.0),
		]
		for idx in range(path.size() - 1):
			canvas.draw_line(path[idx], path[idx + 1], _draw_primitives.color8(255, 148, 220, 58), 1.0)
		var path_pos: float = climb_t * float(path.size() - 1)
		var path_idx: int = min(path.size() - 2, int(path_pos))
		var seg_t: float = path_pos - float(path_idx)
		var seg_ease: float = seg_t * seg_t * (3.0 - 2.0 * seg_t)
		var pos: Vector2 = (path[path_idx] as Vector2).lerp(path[path_idx + 1], seg_ease)
		var current_wall_left: bool = pos.x < center_x
		var tether_x: float = wall_left_x if current_wall_left else wall_right_x
		canvas.draw_line(Vector2(tether_x, pos.y - 8.0), Vector2(pos.x, pos.y - 22.0), _draw_primitives.color8(255, 200, 238, 145), 2.0)
		_draw_viper_mini_character(canvas, pos.x, pos.y, {"pose": "wall_left" if current_wall_left else "wall_right", "direction": -1 if current_wall_left else 1})
	else:
		var kick_t: float = (cycle_progress - 0.74) / 0.26
		var kick_ease: float = 1.0 - pow(1.0 - kick_t, 2.3)
		var start := Vector2(wall_left_x if start_from_left else wall_right_x, preview_top + 28.0)
		var finish := Vector2(ball_pos.x + dash_dir * 4.0, ball_pos.y + 20.0)
		var char_pos: Vector2 = start.lerp(finish, kick_ease)
		for ghost_idx in range(4):
			var ghost_t: float = max(0.0, kick_ease - float(ghost_idx) * 0.16)
			var ghost_pos: Vector2 = start.lerp(finish, ghost_t)
			_draw_viper_mini_character(canvas, ghost_pos.x, ghost_pos.y, {"pose": "fly_right" if dash_dir > 0.0 else "fly_left", "direction": int(dash_dir), "alpha": max(0.11, (128.0 - float(ghost_idx) * 24.0) / 255.0), "tint": _draw_primitives.color8(255, 118, 210)})
		_draw_viper_mini_character(canvas, char_pos.x, char_pos.y, {"pose": "fly_right" if dash_dir > 0.0 else "fly_left", "direction": int(dash_dir)})
		canvas.draw_arc(ball_pos, 14.0 + kick_t * 12.0, 0.0, TAU, 36, _draw_primitives.color8(255, 190, 236, 180), 2.0)
		canvas.draw_line(ball_pos, Vector2(ball_pos.x - dash_dir * 48.0, preview_top + 8.0), _draw_primitives.color8(255, 240, 248), 2.0)


func _draw_viper_wall_dive_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var cycle_progress: float = float(time_ms % 2600) / 2600.0
	var is_left_wall: bool = cycle_progress < 0.5
	var local_progress: float = fposmod(cycle_progress, 0.5) * 2.0
	var center_x: float = float(metrics["center_x"])
	var center_y: float = float(metrics["center_y"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var wall_x: float = preview_left + 14.0 if is_left_wall else preview_right - 14.0
	var wall_side: float = -1.0 if is_left_wall else 1.0
	var ball_pos := Vector2(center_x, center_y + 4.0)
	_draw_preview_ball(canvas, ball_pos, 6.0, [_draw_primitives.color8(80, 120, 255), _draw_primitives.color8(142, 180, 255), _draw_primitives.color8(255, 245, 255)])
	canvas.draw_line(Vector2(wall_x, preview_top + 8.0), Vector2(wall_x, preview_bottom - 4.0), _draw_primitives.color8(95, 88, 136, 160), 3.0)
	for mark_idx in range(3):
		var my: float = preview_top + 20.0 + float(mark_idx) * 16.0
		canvas.draw_line(Vector2(wall_x, my), Vector2(wall_x - wall_side * 12.0, my + 6.0), _draw_primitives.color8(185, 98, 255, 130), 1.0)
	if local_progress < 0.36:
		var char_y: float = preview_bottom - 7.0 - sin(local_progress * PI) * 5.0
		_draw_viper_mini_character(canvas, wall_x - wall_side * 10.0, char_y, {"pose": "wall_left" if is_left_wall else "wall_right", "direction": int(wall_side)})
		canvas.draw_arc(Vector2(wall_x - wall_side * 12.0, char_y - 18.0), 10.0 + local_progress * 15.0, 0.0, TAU, 36, _draw_primitives.color8(190, 98, 255, 110), 2.0)
	elif local_progress < 0.86:
		var move_t: float = (local_progress - 0.36) / 0.50
		var move_ease: float = move_t * move_t * (3.0 - 2.0 * move_t)
		var start_x: float = wall_x - wall_side * 10.0
		var end_x: float = ball_pos.x + wall_side * 6.0
		var char_x: float = lerp(start_x, end_x, move_ease)
		var char_y: float = preview_bottom - 8.0 - sin(move_t * PI) * 26.0
		for ghost_idx in range(4):
			var ghost_t: float = max(0.0, move_ease - float(ghost_idx) * 0.14)
			_draw_viper_mini_character(canvas, lerp(start_x, end_x, ghost_t), preview_bottom - 8.0 - sin(ghost_t * PI) * 26.0, {"pose": "fly_right" if is_left_wall else "fly_left", "direction": int(wall_side), "alpha": max(0.11, (126.0 - float(ghost_idx) * 24.0) / 255.0), "tint": _draw_primitives.color8(185, 98, 255)})
		_draw_viper_mini_character(canvas, char_x, char_y, {"pose": "fly_right" if is_left_wall else "fly_left", "direction": int(wall_side)})
	else:
		var exit_dir: float = -wall_side
		_draw_viper_mini_character(canvas, ball_pos.x + wall_side * 8.0, center_y + 18.0, {"pose": "fly_right" if is_left_wall else "fly_left", "direction": int(wall_side)})
		_draw_viper_mini_character(canvas, ball_pos.x + exit_dir * 20.0, center_y + 10.0, {"pose": "fly_left" if is_left_wall else "fly_right", "direction": int(exit_dir), "alpha": 92.0 / 255.0, "tint": _draw_primitives.color8(185, 98, 255)})
		var burst_r: float = 14.0 + (local_progress - 0.86) / 0.14 * 16.0
		canvas.draw_arc(ball_pos, burst_r, 0.0, TAU, 36, _draw_primitives.color8(210, 176, 255, 175), 2.0)
		canvas.draw_line(ball_pos, Vector2(ball_pos.x + exit_dir * 54.0, preview_top + 10.0), _draw_primitives.color8(255, 230, 255), 2.0)
		canvas.draw_line(ball_pos + Vector2(4.0, 4.0), Vector2(ball_pos.x + exit_dir * 42.0, preview_top + 18.0), _draw_primitives.color8(185, 98, 255), 1.0)


func _draw_viper_chaos_vortex_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2800) / 2800.0
	var center_x: float = float(metrics["center_x"])
	var center_y: float = float(metrics["center_y"])
	var _preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var vortex := Vector2(center_x, center_y - 6.0)
	for ring_idx in range(5):
		var r: float = 16.0 + float(ring_idx) * 7.0 + sin(local_progress * TAU + float(ring_idx)) * 2.0
		var start_angle: float = local_progress * TAU * (1.0 + float(ring_idx) * 0.12) + float(ring_idx) * 0.55
		canvas.draw_arc(vortex, r, start_angle, start_angle + PI * 1.45, 42, _draw_primitives.color8(96 + ring_idx * 20, 42 + ring_idx * 12, 210 + ring_idx * 8, max(40.0, 150.0 - float(ring_idx) * 20.0)), max(1.0, 4.0 - float(ring_idx) * 0.45))
	canvas.draw_circle(vortex, 13.0, _draw_primitives.color8(14, 6, 28, 220))
	canvas.draw_circle(vortex, 7.0 + sin(local_progress * TAU * 2.0) * 2.0, _draw_primitives.color8(72, 26, 130, 180))
	for orb_idx in range(4):
		var angle: float = local_progress * TAU + float(orb_idx) * PI * 0.5
		var orbit_r: float = 42.0 - float(orb_idx % 2) * 9.0
		var pos := vortex + Vector2(cos(angle) * orbit_r, sin(angle) * orbit_r * 0.52)
		_draw_preview_ball(canvas, pos, 4.0, [_draw_primitives.color8(100, 84, 255), _draw_primitives.color8(210, 170, 255)])
		canvas.draw_line(pos, vortex, _draw_primitives.color8(160, 120, 255, 52), 1.0)
	_draw_viper_mini_character(canvas, center_x - 58.0, preview_bottom - 6.0, {"pose": "idle", "direction": 1})
	canvas.draw_line(Vector2(center_x - 42.0, preview_bottom - 30.0), vortex, _draw_primitives.color8(220, 190, 255, 145), 2.0)
	for spark_idx in range(8):
		var spark_angle: float = local_progress * TAU * 1.5 + float(spark_idx) * TAU / 8.0
		var spark_pos := vortex + Vector2(cos(spark_angle) * (20.0 + float(spark_idx % 3) * 10.0), sin(spark_angle) * (10.0 + float(spark_idx % 4) * 5.0))
		canvas.draw_circle(spark_pos, 2.0, _draw_primitives.color8(210, 180, 255, 150))


func _draw_viper_glitch_clone_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2800) / 2800.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var base_y: float = preview_bottom - 6.0
	for scan_y in range(int(preview_top + 2.0), int(preview_bottom), 6):
		canvas.draw_line(Vector2(preview_left + 4.0, float(scan_y)), Vector2(preview_right - 4.0, float(scan_y)), _draw_primitives.color8(255, 255, 255, 14), 1.0)
	for block_idx in range(12):
		var block_w: float = 8.0 + float(block_idx % 3) * 4.0
		var block_h: float = 2.0 + float(block_idx % 2)
		@warning_ignore("integer_division")
		@warning_ignore("shadowed_global_identifier")
		var seed: float = sin(float(time_ms / 36 + block_idx * 23))
		var block_x: float = lerp(preview_left + 8.0, preview_right - block_w - 8.0, fposmod(seed * 0.5 + 0.5 + float(block_idx) * 0.173, 1.0))
		@warning_ignore("integer_division")
		var block_y: float = lerp(preview_top + 6.0, preview_bottom - block_h - 6.0, fposmod(cos(float(time_ms / 41 + block_idx * 11)) * 0.5 + 0.5, 1.0))
		var block_color: Color = [_draw_primitives.color8(255, 70, 140, 55), _draw_primitives.color8(80, 230, 255, 55), _draw_primitives.color8(255, 240, 120, 55)][block_idx % 3]
		canvas.draw_rect(Rect2(Vector2(block_x, block_y), Vector2(block_w, block_h)), block_color, true)
	var clone_gap: float = 48.0 + sin(local_progress * TAU * 2.0) * 4.0
	for side in [-1.0, 1.0]:
		var tint_color: Color = _draw_primitives.color8(255, 90, 190) if side < 0.0 else _draw_primitives.color8(80, 235, 255)
		_draw_viper_mini_character(canvas, center_x + side * clone_gap, base_y, {"alpha": (128.0 + 36.0 * sin(local_progress * TAU + side)) / 255.0, "tint": tint_color})
	var split_shift: float = 2.0 + 2.0 * sin(local_progress * TAU * 2.0)
	_draw_viper_mini_character(canvas, center_x - split_shift, base_y, {"alpha": 112.0 / 255.0, "tint": _draw_primitives.color8(255, 70, 140)})
	_draw_viper_mini_character(canvas, center_x + split_shift, base_y, {"alpha": 112.0 / 255.0, "tint": _draw_primitives.color8(80, 230, 255)})
	_draw_viper_mini_character(canvas, center_x, base_y)
	for band_idx in range(3):
		var band_color: Color = [_draw_primitives.color8(255, 70, 140, 95), _draw_primitives.color8(80, 230, 255, 95), _draw_primitives.color8(120, 255, 205, 95)][band_idx]
		canvas.draw_rect(Rect2(Vector2(center_x - 3.0 + float(band_idx - 1) * 4.0, preview_top + 6.0), Vector2(4.0, preview_bottom - preview_top - 12.0)), band_color, true)
	_draw_preview_ball(canvas, Vector2(center_x, preview_top + 16.0), 6.0, [_draw_primitives.color8(52, 95, 255), _draw_primitives.color8(130, 205, 255), _draw_primitives.color8(255, 250, 255)])
	canvas.draw_arc(Vector2(center_x, base_y - 6.0), 12.0 + local_progress * 14.0, 0.0, TAU, 36, _draw_primitives.color8(60, 220, 150, 90), 2.0)
	canvas.draw_arc(Vector2(center_x, base_y - 6.0), max(8.0, 6.0 + local_progress * 10.0), 0.0, TAU, 36, _draw_primitives.color8(255, 80, 160, 70), 1.0)


func _draw_viper_ignition_preview(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2400) / 2400.0
	var pulse: float = 0.5 + 0.5 * sin(local_progress * TAU * 2.0)
	var center_x: float = float(metrics["center_x"])
	var preview_bottom: float = float(metrics["bottom"])
	var caster_x: float = center_x
	var caster_y: float = preview_bottom - 6.0 - pulse * 3.0
	_draw_viper_mini_character(canvas, caster_x + 2.0, caster_y + 1.0, {"alpha": 170.0 / 255.0, "tint": _draw_primitives.color8(255, 138, 58)})
	_draw_viper_mini_character(canvas, caster_x, caster_y)
	var aura_center := Vector2(caster_x, caster_y - 14.0)
	canvas.draw_circle(aura_center, 18.0 + pulse * 8.0, _draw_primitives.color8(255, 114, 36, 88))
	canvas.draw_circle(aura_center, 11.0 + pulse * 5.0, _draw_primitives.color8(255, 176, 92, 112))
	canvas.draw_circle(aura_center, max(5.0, 5.0 + pulse * 3.0), _draw_primitives.color8(255, 244, 180, 120))
	for flame_idx in range(4):
		var flame_angle: float = local_progress * TAU * 0.8 + float(flame_idx) * PI * 0.5 + PI * 0.25
		var base_r: float = 16.0 + pulse * 6.0
		var base := aura_center + Vector2(cos(flame_angle) * base_r, sin(flame_angle) * base_r * 0.65)
		var tip := aura_center + Vector2(cos(flame_angle) * (base_r + 14.0), -4.0 + sin(flame_angle) * (base_r + 14.0) * 0.75)
		var perp: float = flame_angle + PI * 0.5
		var half_w: float = 4.0 + float(flame_idx)
		var flame_points := PackedVector2Array([
			tip,
			base + Vector2(cos(perp), sin(perp)) * half_w,
			base - Vector2(cos(perp), sin(perp)) * half_w,
		])
		canvas.draw_colored_polygon(flame_points, _draw_primitives.color8(255, 132, 48, 158))
		var outline := PackedVector2Array(flame_points)
		outline.append(tip)
		canvas.draw_polyline(outline, _draw_primitives.color8(255, 226, 164, 115), 1.0)
	for ember_idx in range(14):
		@warning_ignore("integer_division")
		var ember_x: float = caster_x + sin(float(time_ms / 42 + ember_idx * 19)) * 34.0
		@warning_ignore("integer_division")
		var ember_y: float = caster_y - 40.0 + cos(float(time_ms / 47 + ember_idx * 13)) * 16.0
		var ember_r: float = 2.0 if ember_idx < 5 else 1.0
		var ember_alpha: float = 90.0 + float(ember_idx % 4) * 20.0
		var ember_color: Color = _draw_primitives.color8(255, 220, 120, ember_alpha) if ember_idx % 3 == 0 else _draw_primitives.color8(255, 145, 64, ember_alpha)
		canvas.draw_circle(Vector2(ember_x, ember_y), ember_r, ember_color)
	for ray_idx in range(6):
		var ray_angle: float = float(ray_idx) / 6.0 * TAU + local_progress * PI * 0.4
		var ray_len: float = 14.0 + float(ray_idx) * 2.0
		canvas.draw_line(aura_center, aura_center + Vector2(cos(ray_angle) * ray_len, sin(ray_angle) * ray_len * 0.7), _draw_primitives.color8(255, 204, 122, 70), 2.0)


func _draw_viper_wall_leap_raid_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var progress := float(Time.get_ticks_msec() % 2800) / 2800.0
	var left := float(metrics["left"]) + 24.0
	var right := float(metrics["right"]) - 24.0
	var top := float(metrics["top"]) + 12.0
	var bottom := float(metrics["bottom"]) - 7.0
	var entry := Vector2(left, bottom)
	var enemy := Vector2(right, top + 8.0)
	var travel := progress * 2.0 if progress < 0.5 else (1.0 - progress) * 2.0
	var infiltrator := entry.lerp(enemy, travel) + Vector2(0.0, -sin(PI * travel) * 24.0)
	var arc_points := PackedVector2Array()
	for index in range(20):
		var t := float(index) / 19.0
		arc_points.append(entry.lerp(enemy, t) + Vector2(0.0, -sin(PI * t) * 24.0))
	canvas.draw_polyline(arc_points, Color(color.r, color.g, color.b, 0.55), 2.0)
	_draw_preview_paddle(canvas, entry, _draw_primitives.color8(90, 120, 155))
	_draw_preview_paddle(canvas, enemy, _draw_primitives.color8(235, 90, 105))
	_draw_viper_mini_character(canvas, infiltrator.x, infiltrator.y, {"alpha": 0.58, "tint": color, "direction": 1 if progress < 0.5 else -1})
	var fuse_center := enemy + Vector2(-10.0, 20.0)
	var fuse_ratio := fposmod(progress * 4.0, 1.0)
	canvas.draw_arc(fuse_center, 8.0 + fuse_ratio * 18.0, 0.0, TAU, 28, Color(1.0, 0.55, 0.22, 0.75 * (1.0 - fuse_ratio)), 2.0)
	canvas.draw_line(enemy + Vector2(-26.0, 8.0), enemy + Vector2(12.0, -8.0), Color(0.72, 0.95, 1.0, 0.78), 3.0)


func _draw_viper_input_overlay(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color, time_ms: int) -> void:
	var spec_value: Variant = VIPER_EFFECT_INPUT_OVERLAY.get(effect_type, [])
	if not (spec_value is Array) or (spec_value as Array).size() < 2:
		return
	var spec: Array = spec_value
	var kind: String = str(spec[0])
	var value: String = str(spec[1])
	var metrics: Dictionary = _preview_metrics(rect)
	var center := Vector2(float(metrics["center_x"]), float(metrics["top"]) + 14.0)
	if kind == "sequence":
		var letters: Array = _split_key_letters(value)
		@warning_ignore("integer_division")
		var slot_idx: int = int(time_ms / 500) % (letters.size() + 1)
		if slot_idx >= letters.size():
			return
		_draw_preview_keycap_row(canvas, center, letters, "arrow", slot_idx, color)
		return
	var cycle_pos: float = fposmod(float(time_ms), VIPER_INPUT_CYCLE_MS) / VIPER_INPUT_CYCLE_MS
	if cycle_pos >= VIPER_INPUT_VISIBLE_RATIO:
		return
	if kind == "hold":
		_draw_viper_hold_keycap(canvas, center, value, color, cycle_pos / VIPER_INPUT_VISIBLE_RATIO)
	elif kind == "combo":
		_draw_viper_combo_keycap(canvas, center, value, color)
	elif kind == "plus":
		_draw_preview_keycap_row(canvas, center, _split_key_letters(value), "plus", -1, color)


func _draw_viper_hold_keycap(canvas: CanvasItem, center: Vector2, letter: String, color: Color, pulse_phase: float) -> void:
	_draw_preview_keycap(canvas, center, letter)
	var pulse: float = 0.5 + 0.5 * sin(pulse_phase * TAU)
	_draw_primitives.draw_round_rect_outline(canvas, Rect2(center - Vector2(10.0, 9.0), Vector2(20.0, 18.0)), _draw_primitives.alpha(color, max(60.0, 180.0 * pulse + 60.0) / 255.0), 4.0, 1.0)
	for dot_idx in range(3):
		canvas.draw_circle(center + Vector2(-2.0 + float(dot_idx) * 2.0, 10.0 + float(dot_idx)), 1.0, _draw_primitives.alpha(color, 200.0 / 255.0))


func _draw_viper_combo_keycap(canvas: CanvasItem, center: Vector2, letter: String, color: Color) -> void:
	_draw_preview_keycap(canvas, center, letter)
	var cb_x: float = center.x + 11.0
	canvas.draw_line(Vector2(cb_x, center.y - 3.0), Vector2(cb_x + 3.0, center.y), _draw_primitives.alpha(color, 220.0 / 255.0), 1.0)
	canvas.draw_line(Vector2(cb_x + 3.0, center.y), Vector2(cb_x, center.y + 3.0), _draw_primitives.alpha(color, 220.0 / 255.0), 1.0)
	canvas.draw_line(Vector2(cb_x + 3.0, center.y - 3.0), Vector2(cb_x + 6.0, center.y), _draw_primitives.alpha(color, 220.0 / 255.0), 1.0)
	canvas.draw_line(Vector2(cb_x + 6.0, center.y), Vector2(cb_x + 3.0, center.y + 3.0), _draw_primitives.alpha(color, 220.0 / 255.0), 1.0)


func _draw_commando_effect_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color) -> void:
	match effect_type:
		"supply_green":
			_draw_commando_supply_drop_preview(canvas, rect, color)
		"emergency_red":
			_draw_commando_emergency_reload_preview(canvas, rect, color)
		_:
			_draw_commando_firearm_preview(canvas, rect, effect_type, color)


func _draw_commando_supply_drop_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 3200) / 3200.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var floor_y: float = preview_bottom - 2.0
	var soldier_pos := Vector2(preview_left + 50.0, floor_y)
	var plane_x: float = preview_left + 12.0 + fposmod(local_progress * 240.0, preview_right - preview_left - 24.0)
	var crate_phase: float = clamp((local_progress - 0.18) / 0.70, 0.0, 1.0)
	var crate_pos := Vector2(center_x + 36.0 * sin(crate_phase * PI), preview_top + 12.0 + (floor_y - preview_top - 20.0) * crate_phase)
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), _draw_primitives.color8(82, 130, 80, 54), 2.0)
	_draw_commando_mini_character(canvas, soldier_pos.x, soldier_pos.y, {"pose": "radio"})
	for signal_idx in range(3):
		var signal_radius: float = 14.0 + float(signal_idx) * 9.0 + sin(float(time_ms) * 0.006) * 2.0
		canvas.draw_arc(soldier_pos + Vector2(9.0, -32.0), signal_radius, -PI * 0.75, -PI * 0.22, 18, _draw_primitives.alpha(color, max(45.0, 160.0 - float(signal_idx) * 40.0) / 255.0), 1.5)
	_draw_commando_plane(canvas, Vector2(plane_x, preview_top + 10.0), color)
	_draw_commando_parachute_crate(canvas, crate_pos, color, crate_phase)
	for sparkle_idx in range(6):
		var sparkle_angle: float = float(sparkle_idx) * TAU / 6.0 + local_progress * TAU
		var sparkle_pos := crate_pos + Vector2(cos(sparkle_angle) * 22.0, sin(sparkle_angle) * 10.0)
		canvas.draw_circle(sparkle_pos, 1.8, _draw_primitives.alpha(color, 150.0 / 255.0))
	_draw_preview_keycap(canvas, Vector2(preview_left + 22.0, preview_top + 14.0), "S")
	_draw_preview_mouse(canvas, Vector2(preview_left + 44.0, preview_top + 14.0), false)


func _draw_commando_emergency_reload_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2600) / 2600.0
	var center_x: float = float(metrics["center_x"])
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var floor_y: float = preview_bottom - 2.0
	var soldier_pos := Vector2(center_x - 44.0, floor_y)
	var magazine_pos := Vector2(center_x + 30.0, floor_y - 26.0)
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), _draw_primitives.color8(130, 72, 64, 54), 2.0)
	_draw_commando_mini_character(canvas, soldier_pos.x, soldier_pos.y, {"pose": "reload"})
	_draw_commando_pistol(canvas, soldier_pos + Vector2(25.0, -31.0), color, local_progress)
	var filled_rounds: int = clampi(int(floor(local_progress * 6.0)), 0, 5)
	_draw_commando_magazine(canvas, magazine_pos, color, filled_rounds)
	for arc_idx in range(3):
		var radius: float = 17.0 + float(arc_idx) * 8.0 + sin(local_progress * TAU) * 2.0
		canvas.draw_arc(magazine_pos, radius, -PI * 0.20, PI * 1.25, 26, _draw_primitives.alpha(color, max(45.0, 160.0 - float(arc_idx) * 38.0) / 255.0), 2.0)
	for round_idx in range(5):
		var round_phase: float = clamp(local_progress * 1.4 - float(round_idx) * 0.13, 0.0, 1.0)
		var start := Vector2(preview_right - 30.0 - float(round_idx) * 8.0, preview_top + 14.0)
		var finish := magazine_pos + Vector2(-5.0 + float(round_idx) * 3.0, -9.0)
		var pos: Vector2 = start.lerp(finish, 1.0 - pow(1.0 - round_phase, 2.0))
		canvas.draw_rect(Rect2(pos - Vector2(2.0, 5.0), Vector2(4.0, 10.0)), _draw_primitives.color8(255, 215, 115, 180), true)
	_draw_preview_keycap(canvas, Vector2(preview_left + 24.0, preview_top + 14.0), "↓")
	_draw_preview_arrow(canvas, Vector2(preview_left + 42.0, preview_top + 14.0))
	_draw_preview_keycap(canvas, Vector2(preview_left + 60.0, preview_top + 14.0), "↓")


func _draw_commando_firearm_preview(canvas: CanvasItem, rect: Rect2, effect_type: String, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2400) / 2400.0
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var floor_y: float = preview_bottom - 2.0
	var soldier_pos := Vector2(preview_left + 56.0, floor_y)
	var muzzle := soldier_pos + Vector2(31.0, -32.0)
	var target := Vector2(preview_right - 36.0, preview_top + 26.0)
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), _draw_primitives.color8(92, 104, 80, 50), 2.0)
	_draw_commando_mini_character(canvas, soldier_pos.x, soldier_pos.y, {"pose": "fire"})
	_draw_commando_pistol(canvas, muzzle - Vector2(8.0, 0.0), color, local_progress)
	match effect_type:
		"firearm_support":
			_draw_commando_support_marker(canvas, target, color, local_progress)
		"firearm_trap":
			_draw_commando_trap_marker(canvas, target + Vector2(-8.0, 32.0), color, local_progress)
		"firearm_drone":
			_draw_commando_drone(canvas, target + Vector2(-10.0, -10.0), color, local_progress)
		"firearm_net":
			_draw_commando_net_projectile(canvas, muzzle, target, color, local_progress)
		"firearm_bazooka":
			_draw_commando_rocket(canvas, muzzle, target, color, local_progress)
		_:
			_draw_commando_bullets(canvas, muzzle, target, color, local_progress, effect_type == "firearm_ak47")
	_draw_preview_mouse(canvas, Vector2(preview_left + 22.0, preview_top + 14.0), true)
	_draw_preview_keycap(canvas, Vector2(preview_left + 44.0, preview_top + 14.0), "SP")


func _draw_commando_plane(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	var body := Rect2(center + Vector2(-20.0, -4.0), Vector2(34.0, 8.0))
	canvas.draw_rect(body, _draw_primitives.color8(58, 76, 64, 220), true)
	canvas.draw_rect(Rect2(body.position + Vector2(4.0, -3.0), Vector2(10.0, 4.0)), _draw_primitives.color8(176, 205, 168, 230), true)
	var wing := PackedVector2Array([
		center + Vector2(-4.0, -3.0),
		center + Vector2(18.0, -17.0),
		center + Vector2(10.0, -2.0),
		center + Vector2(-5.0, 10.0),
	])
	canvas.draw_colored_polygon(wing, _draw_primitives.alpha(color, 170.0 / 255.0))
	canvas.draw_line(center + Vector2(-20.0, 3.0), center + Vector2(-28.0, 10.0), _draw_primitives.color8(58, 76, 64, 210), 3.0)


func _draw_commando_parachute_crate(canvas: CanvasItem, center: Vector2, color: Color, phase: float) -> void:
	var canopy_center := center + Vector2(0.0, -20.0)
	var canopy_rect := Rect2(canopy_center - Vector2(22.0, 13.0), Vector2(44.0, 24.0))
	_draw_primitives.draw_ellipse_arc(canvas, canopy_rect, PI, TAU, _draw_primitives.alpha(color, 185.0 / 255.0), 2.0)
	canvas.draw_line(canopy_center + Vector2(-18.0, 0.0), center + Vector2(-9.0, -7.0), _draw_primitives.color8(210, 226, 204, 150), 1.0)
	canvas.draw_line(canopy_center + Vector2(18.0, 0.0), center + Vector2(9.0, -7.0), _draw_primitives.color8(210, 226, 204, 150), 1.0)
	canvas.draw_line(canopy_center, center + Vector2(0.0, -7.0), _draw_primitives.color8(210, 226, 204, 150), 1.0)
	var crate_rect := Rect2(center - Vector2(12.0, 8.0), Vector2(24.0, 16.0))
	_draw_primitives.draw_panel(canvas, crate_rect, _draw_primitives.color8(96, 84, 54, 230), _draw_primitives.alpha(color, 190.0 / 255.0), 2.0, 2.0)
	canvas.draw_line(crate_rect.position + Vector2(3.0, 3.0), crate_rect.end - Vector2(3.0, 3.0), _draw_primitives.color8(196, 166, 92, 170), 1.0)
	canvas.draw_line(Vector2(crate_rect.end.x - 3.0, crate_rect.position.y + 3.0), Vector2(crate_rect.position.x + 3.0, crate_rect.end.y - 3.0), _draw_primitives.color8(196, 166, 92, 170), 1.0)
	if phase >= 0.94:
		canvas.draw_arc(center, 20.0 + (phase - 0.94) * 80.0, 0.0, TAU, 28, _draw_primitives.alpha(color, 120.0 / 255.0), 2.0)


func _draw_commando_pistol(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	var body := Rect2(center + Vector2(-8.0, -4.0), Vector2(20.0, 7.0))
	canvas.draw_rect(body, _draw_primitives.color8(35, 38, 36, 235), true)
	canvas.draw_rect(Rect2(body.position + Vector2(2.0, 1.0), Vector2(9.0, 2.0)), _draw_primitives.alpha(color, 150.0 / 255.0), true)
	canvas.draw_rect(Rect2(center + Vector2(-7.0, 2.0), Vector2(5.0, 10.0)), _draw_primitives.color8(64, 54, 42, 235), true)
	if progress > 0.45:
		canvas.draw_line(center + Vector2(13.0, -1.0), center + Vector2(23.0, -1.0), _draw_primitives.alpha(color, 170.0 / 255.0), 2.0)


func _draw_commando_magazine(canvas: CanvasItem, center: Vector2, color: Color, filled_rounds: int) -> void:
	var mag_rect := Rect2(center - Vector2(9.0, 18.0), Vector2(18.0, 36.0))
	_draw_primitives.draw_panel(canvas, mag_rect, _draw_primitives.color8(34, 37, 34, 232), _draw_primitives.alpha(color, 120.0 / 255.0), 2.0, 3.0)
	for round_idx in range(5):
		var slot_y: float = mag_rect.end.y - 6.0 - float(round_idx) * 6.0
		var round_color: Color = _draw_primitives.color8(255, 216, 118, 220) if round_idx < filled_rounds else _draw_primitives.color8(80, 82, 76, 190)
		canvas.draw_rect(Rect2(Vector2(center.x - 5.0, slot_y - 2.0), Vector2(10.0, 3.0)), round_color, true)


func _draw_commando_support_marker(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	canvas.draw_arc(center, 18.0 + sin(progress * TAU) * 3.0, 0.0, TAU, 36, _draw_primitives.alpha(color, 180.0 / 255.0), 2.0)
	canvas.draw_line(center + Vector2(-16.0, 0.0), center + Vector2(16.0, 0.0), _draw_primitives.alpha(color, 190.0 / 255.0), 1.5)
	canvas.draw_line(center + Vector2(0.0, -16.0), center + Vector2(0.0, 16.0), _draw_primitives.alpha(color, 190.0 / 255.0), 1.5)
	for shell_idx in range(3):
		var shell_pos := center + Vector2(-14.0 + float(shell_idx) * 14.0, -42.0 + progress * 38.0)
		canvas.draw_line(shell_pos, shell_pos + Vector2(0.0, 13.0), _draw_primitives.color8(255, 138, 76, 170), 3.0)


func _draw_commando_trap_marker(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	var trap_rect := Rect2(center - Vector2(18.0, 7.0), Vector2(36.0, 14.0))
	_draw_primitives.draw_panel(canvas, trap_rect, _draw_primitives.color8(56, 46, 40, 230), _draw_primitives.alpha(color, 130.0 / 255.0), 2.0, 5.0)
	for tooth_idx in range(5):
		var tooth_x: float = trap_rect.position.x + 5.0 + float(tooth_idx) * 6.0
		canvas.draw_line(Vector2(tooth_x, trap_rect.position.y + 2.0), Vector2(tooth_x + 3.0, trap_rect.position.y - 8.0 - sin(progress * TAU) * 3.0), _draw_primitives.color8(220, 224, 210, 190), 1.5)
	canvas.draw_circle(center + Vector2(-26.0 + progress * 52.0, -16.0), 7.0, _draw_primitives.alpha(color, 190.0 / 255.0))


func _draw_commando_drone(canvas: CanvasItem, center: Vector2, color: Color, progress: float) -> void:
	var hover: float = sin(progress * TAU) * 5.0
	var body_center := center + Vector2(0.0, hover)
	_draw_primitives.draw_panel(canvas, Rect2(body_center - Vector2(12.0, 6.0), Vector2(24.0, 12.0)), _draw_primitives.color8(44, 50, 48, 230), _draw_primitives.alpha(color, 130.0 / 255.0), 2.0, 4.0)
	for arm_dir in [-1.0, 1.0]:
		canvas.draw_line(body_center + Vector2(arm_dir * 10.0, -2.0), body_center + Vector2(arm_dir * 24.0, -8.0), _draw_primitives.color8(90, 110, 90, 190), 2.0)
		canvas.draw_arc(body_center + Vector2(arm_dir * 28.0, -10.0), 7.0, 0.0, TAU, 18, _draw_primitives.alpha(color, 150.0 / 255.0), 1.5)
	canvas.draw_circle(body_center, 3.0, _draw_primitives.color8(255, 96, 70, 220))


func _draw_commando_net_projectile(canvas: CanvasItem, start: Vector2, target: Vector2, color: Color, progress: float) -> void:
	var net_center: Vector2 = start.lerp(target, progress)
	for trail_idx in range(6):
		var trail_phase: float = max(0.0, progress - float(trail_idx) * 0.08)
		var trail_pos: Vector2 = start.lerp(target, trail_phase)
		canvas.draw_circle(trail_pos, max(1.0, 4.0 - float(trail_idx) * 0.4), _draw_primitives.alpha(color, max(35.0, 150.0 - float(trail_idx) * 20.0) / 255.0))
	var net_rect := Rect2(net_center - Vector2(18.0, 12.0), Vector2(36.0, 24.0))
	for line_idx in range(4):
		var x: float = net_rect.position.x + float(line_idx) * net_rect.size.x / 3.0
		canvas.draw_line(Vector2(x, net_rect.position.y), Vector2(x, net_rect.end.y), _draw_primitives.alpha(color, 170.0 / 255.0), 1.0)
		var y: float = net_rect.position.y + float(line_idx) * net_rect.size.y / 3.0
		canvas.draw_line(Vector2(net_rect.position.x, y), Vector2(net_rect.end.x, y), _draw_primitives.alpha(color, 170.0 / 255.0), 1.0)


func _draw_commando_rocket(canvas: CanvasItem, start: Vector2, target: Vector2, color: Color, progress: float) -> void:
	var rocket_pos: Vector2 = start.lerp(target, progress)
	var dir: Vector2 = (target - start).normalized()
	var side := Vector2(-dir.y, dir.x)
	canvas.draw_colored_polygon(PackedVector2Array([
		rocket_pos + dir * 12.0,
		rocket_pos - dir * 10.0 + side * 5.0,
		rocket_pos - dir * 7.0,
		rocket_pos - dir * 10.0 - side * 5.0,
	]), _draw_primitives.color8(88, 92, 86, 230))
	for flame_idx in range(4):
		var flame_pos := rocket_pos - dir * (12.0 + float(flame_idx) * 5.0)
		canvas.draw_circle(flame_pos, max(2.0, 6.0 - float(flame_idx)), _draw_primitives.color8(255, 154, 58, max(70.0, 190.0 - float(flame_idx) * 34.0)))
	if progress > 0.82:
		canvas.draw_arc(target, 28.0 * ((progress - 0.82) / 0.18), 0.0, TAU, 32, _draw_primitives.alpha(color, 180.0 / 255.0), 2.0)


func _draw_commando_bullets(canvas: CanvasItem, start: Vector2, target: Vector2, color: Color, progress: float, rapid: bool) -> void:
	var burst_count: int = 5 if rapid else 2
	for bullet_idx in range(burst_count):
		var bullet_phase: float = fposmod(progress + float(bullet_idx) * (0.16 if rapid else 0.34), 1.0)
		var pos: Vector2 = start.lerp(target, bullet_phase)
		canvas.draw_line(pos - Vector2(10.0, 0.0), pos + Vector2(6.0, 0.0), _draw_primitives.color8(255, 214, 105, 210), 2.0)
		canvas.draw_circle(pos + Vector2(7.0, 0.0), 2.0, _draw_primitives.alpha(color, 160.0 / 255.0))


func _draw_commando_mini_character(canvas: CanvasItem, cx: float, cy: float, options: Dictionary = {}) -> void:
	var pose: String = str(options.get("pose", "idle"))
	var alpha: float = float(options.get("alpha", 1.0))
	var tint: Color = _draw_primitives.get_color(options.get("tint", Color.WHITE), Color.WHITE)
	var armor: Color = _draw_primitives.tint(_draw_primitives.color8(78, 112, 58, 235.0 * alpha), tint)
	var armor_dark: Color = _draw_primitives.tint(_draw_primitives.color8(44, 66, 42, 235.0 * alpha), tint)
	var trim: Color = _draw_primitives.tint(_draw_primitives.color8(154, 188, 104, 225.0 * alpha), tint)
	var skin: Color = _draw_primitives.tint(_draw_primitives.color8(218, 176, 128, 235.0 * alpha), tint)
	canvas.draw_circle(Vector2(cx, cy - 2.0), 16.0, _draw_primitives.alpha(Color.BLACK, 0.22 * alpha))
	canvas.draw_line(Vector2(cx - 6.0, cy - 12.0), Vector2(cx - 11.0, cy - 2.0), armor_dark, 4.0)
	canvas.draw_line(Vector2(cx + 6.0, cy - 12.0), Vector2(cx + 11.0, cy - 2.0), armor_dark, 4.0)
	_draw_primitives.draw_panel(canvas, Rect2(Vector2(cx - 11.0, cy - 39.0), Vector2(22.0, 28.0)), armor, Color.TRANSPARENT, 0.0, 5.0)
	canvas.draw_rect(Rect2(Vector2(cx - 6.0, cy - 34.0), Vector2(12.0, 6.0)), trim, true)
	_draw_primitives.draw_ellipse(canvas, Rect2(Vector2(cx - 11.0, cy - 56.0), Vector2(22.0, 18.0)), armor_dark, true)
	_draw_primitives.draw_ellipse(canvas, Rect2(Vector2(cx - 8.0, cy - 51.0), Vector2(16.0, 8.0)), skin, true)
	canvas.draw_rect(Rect2(Vector2(cx - 8.0, cy - 49.0), Vector2(16.0, 3.0)), _draw_primitives.color8(42, 52, 48, 230.0 * alpha), true)
	if pose == "radio":
		canvas.draw_line(Vector2(cx - 9.0, cy - 33.0), Vector2(cx - 23.0, cy - 43.0), armor_dark, 3.0)
		canvas.draw_rect(Rect2(Vector2(cx - 27.0, cy - 47.0), Vector2(7.0, 11.0)), _draw_primitives.color8(28, 34, 30, 235.0 * alpha), true)
		canvas.draw_line(Vector2(cx - 24.0, cy - 47.0), Vector2(cx - 29.0, cy - 55.0), trim, 1.0)
	elif pose == "reload":
		canvas.draw_line(Vector2(cx + 9.0, cy - 33.0), Vector2(cx + 22.0, cy - 29.0), armor_dark, 3.0)
		canvas.draw_line(Vector2(cx - 9.0, cy - 32.0), Vector2(cx + 10.0, cy - 25.0), armor_dark, 3.0)
	else:
		canvas.draw_line(Vector2(cx + 9.0, cy - 33.0), Vector2(cx + 27.0, cy - 32.0), armor_dark, 3.0)
		canvas.draw_line(Vector2(cx - 9.0, cy - 33.0), Vector2(cx - 20.0, cy - 25.0), armor_dark, 3.0)


func _split_key_letters(value: String) -> Array:
	var result: Array = []
	for part in value.split(",", false):
		result.append(str(part))
	return result


func _draw_viper_blade_wave(canvas: CanvasItem, tip: Vector2, travel_phase: float, dark_mode: bool) -> void:
	var fan_w: float = 74.0 if dark_mode else 56.0
	var fan_h: float = 42.0 if dark_mode else 32.0
	for echo_idx in range(3, 0, -1):
		var echo_phase: float = max(0.0, travel_phase - float(echo_idx) * 0.12)
		if echo_phase <= 0.0:
			continue
		var echo_tip := tip + Vector2(0.0, float(echo_idx) * (7.0 + travel_phase * 4.0))
		var echo_scale: float = 1.0 - float(echo_idx) * 0.09
		_draw_viper_blade_fan(canvas, echo_tip, fan_w * echo_scale, fan_h * echo_scale, dark_mode, 0.18 + echo_phase * 0.18)
	_draw_viper_blade_fan(canvas, tip, fan_w, fan_h, dark_mode, 1.0)


func _draw_viper_blade_fan(canvas: CanvasItem, tip: Vector2, fan_w: float, fan_h: float, dark_mode: bool, alpha_scale: float) -> void:
	var layer_specs: Array = [
		[1.10, _draw_primitives.color8(14, 0, 2, 36)],
		[0.94, _draw_primitives.color8(46, 2, 8, 68)],
		[0.78, _draw_primitives.color8(136, 14, 22, 132)],
		[0.52, _draw_primitives.color8(242, 84, 64, 198)],
	] if dark_mode else [
		[1.00, _draw_primitives.color8(52, 28, 92, 28)],
		[0.82, _draw_primitives.color8(82, 40, 128, 52)],
		[0.62, _draw_primitives.color8(154, 98, 210, 112)],
		[0.40, _draw_primitives.color8(204, 170, 240, 148)],
	]
	for spec in layer_specs:
		var scale: float = float(spec[0])
		var c: Color = _draw_primitives.alpha(_draw_primitives.get_color(spec[1], Color.WHITE), alpha_scale)
		var points := PackedVector2Array([
			tip,
			tip + Vector2(-fan_w * 0.5 * scale, fan_h * scale),
			tip + Vector2(0.0, fan_h * 0.68 * scale),
			tip + Vector2(fan_w * 0.5 * scale, fan_h * scale),
		])
		canvas.draw_colored_polygon(points, c)
	var edge_color: Color = _draw_primitives.color8(255, 105, 90) if dark_mode else _draw_primitives.color8(210, 182, 255)
	canvas.draw_line(tip, tip + Vector2(-fan_w * 0.48, fan_h), _draw_primitives.alpha(edge_color, alpha_scale), 2.0)
	canvas.draw_line(tip, tip + Vector2(fan_w * 0.48, fan_h), _draw_primitives.alpha(edge_color, alpha_scale), 2.0)


func _draw_viper_target_dummy(canvas: CanvasItem, base: Vector2, accent_color: Color, stun_phase: float) -> void:
	var body_rect := Rect2(Vector2(base.x - 14.0, base.y - 42.0), Vector2(28.0, 38.0))
	var head_rect := Rect2(Vector2(base.x - 12.0, body_rect.position.y - 12.0), Vector2(24.0, 18.0))
	_draw_primitives.draw_panel(canvas, body_rect, _draw_primitives.color8(18, 22, 34, 220), _draw_primitives.alpha(accent_color, 85.0 / 255.0), 2.0, 8.0)
	_draw_primitives.draw_panel(canvas, body_rect.grow_individual(-6.0, -6.0, -6.0, -6.0), _draw_primitives.color8(70, 88, 118, 220), Color.TRANSPARENT, 0.0, 6.0)
	_draw_primitives.draw_ellipse(canvas, head_rect, _draw_primitives.color8(28, 34, 48, 230), true)
	_draw_primitives.draw_ellipse(canvas, head_rect.grow_individual(-4.0, -5.0, -4.0, -5.0), _draw_primitives.color8(120, 140, 185, 220), true)
	canvas.draw_line(Vector2(head_rect.position.x + 6.0, head_rect.get_center().y), Vector2(head_rect.end.x - 6.0, head_rect.get_center().y), _draw_primitives.color8(255, 235, 245), 2.0)
	canvas.draw_line(Vector2(base.x - 7.0, body_rect.position.y + 15.0), Vector2(base.x + 7.0, body_rect.position.y + 15.0), _draw_primitives.color8(138, 165, 215), 2.0)
	canvas.draw_line(Vector2(base.x, body_rect.position.y + 9.0), Vector2(base.x, body_rect.position.y + 23.0), _draw_primitives.color8(138, 165, 215), 2.0)
	for arm_dir in [-1.0, 1.0]:
		canvas.draw_line(Vector2(base.x + arm_dir * 10.0, body_rect.position.y + 11.0), Vector2(base.x + arm_dir * 19.0, body_rect.position.y + 24.0), _draw_primitives.color8(65, 80, 110), 3.0)
		canvas.draw_line(Vector2(base.x + arm_dir * 5.0, body_rect.end.y - 4.0), Vector2(base.x + arm_dir * 9.0, body_rect.end.y + 10.0), _draw_primitives.color8(55, 65, 98), 3.0)
	if stun_phase > 0.0:
		var orb_radius: float = 16.0 + stun_phase * 3.0
		for orb_idx in range(3):
			var orb_angle: float = stun_phase * TAU + float(orb_idx) * TAU / 3.0
			var orb_pos := Vector2(base.x + cos(orb_angle) * orb_radius, head_rect.position.y - 2.0 + sin(orb_angle * 1.2) * 6.0)
			canvas.draw_circle(orb_pos, 3.0, accent_color if orb_idx != 1 else _draw_primitives.color8(255, 220, 180))
			canvas.draw_arc(orb_pos, 4.0, 0.0, TAU, 18, _draw_primitives.alpha(accent_color, 170.0 / 255.0), 1.0)


func _draw_viper_mini_character(canvas: CanvasItem, cx: float, cy: float, options: Dictionary = {}) -> void:
	var _b: float = float(options.get("block", 4.0))
	var pose: String = str(options.get("pose", "idle"))
	var direction: int = int(options.get("direction", 1))
	if direction == 0:
		direction = 1
	var alpha: float = float(options.get("alpha", 1.0))
	var tint: Color = _draw_primitives.get_color(options.get("tint", Color.WHITE), Color.WHITE)
	var palette: Dictionary = _viper_palette(alpha, tint)
	var core := Vector2(cx, cy - 22.0)
	var lean: float = 0.0
	if pose in ["fly_right", "fly_left"]:
		lean = float(direction) * 8.0
	elif pose == "fly_down":
		lean = 0.0
	elif pose in ["kick_left", "kick_right"]:
		lean = float(direction) * 4.0
	_draw_primitives.draw_ellipse(canvas, Rect2(Vector2(cx - 18.0, cy - 2.0), Vector2(36.0, 6.0)), _draw_primitives.alpha(Color.BLACK, 0.22 * alpha), true)
	if pose in ["wall_left", "wall_right"]:
		var wall_dir: float = -1.0 if pose == "wall_left" else 1.0
		core = Vector2(cx - wall_dir * 2.0, cy - 23.0)
		canvas.draw_line(core + Vector2(-wall_dir * 3.0, -4.0), core + Vector2(-wall_dir * 15.0, -14.0), palette["limb"], 3.0)
		canvas.draw_line(core + Vector2(-wall_dir * 2.0, 4.0), core + Vector2(-wall_dir * 14.0, 13.0), palette["limb"], 3.0)
	else:
		canvas.draw_line(core + Vector2(-5.0, 12.0), Vector2(cx - 9.0, cy - 2.0), palette["limb"], 3.0)
		canvas.draw_line(core + Vector2(5.0, 12.0), Vector2(cx + 10.0, cy - 2.0), palette["limb"], 3.0)
	var torso_points := PackedVector2Array([
		core + Vector2(-9.0 + lean * 0.15, -9.0),
		core + Vector2(8.0 + lean * 0.20, -7.0),
		core + Vector2(10.0 + lean * 0.30, 10.0),
		core + Vector2(-8.0 + lean * 0.15, 12.0),
	])
	canvas.draw_colored_polygon(torso_points, palette["suit"])
	var inner_points := PackedVector2Array([
		core + Vector2(-4.0 + lean * 0.12, -5.0),
		core + Vector2(4.0 + lean * 0.18, -4.0),
		core + Vector2(5.0 + lean * 0.22, 7.0),
		core + Vector2(-4.0 + lean * 0.12, 8.0),
	])
	canvas.draw_colored_polygon(inner_points, palette["chest"])
	canvas.draw_line(core + Vector2(-11.0, -5.0), core + Vector2(-20.0 - float(direction) * 4.0, 1.0), palette["limb"], 3.0)
	canvas.draw_line(core + Vector2(11.0, -4.0), core + Vector2(20.0 + float(direction) * 7.0, -1.0), palette["limb"], 3.0)
	canvas.draw_line(core + Vector2(20.0 + float(direction) * 7.0, -1.0), core + Vector2(29.0 * float(direction), -9.0), palette["blade"], 2.0)
	var head_center := core + Vector2(lean * 0.2, -20.0)
	_draw_primitives.draw_ellipse(canvas, Rect2(head_center - Vector2(8.0, 9.0), Vector2(16.0, 18.0)), palette["hood"], true)
	_draw_primitives.draw_ellipse(canvas, Rect2(head_center - Vector2(5.0, 4.0), Vector2(10.0, 7.0)), palette["visor"], true)
	canvas.draw_line(head_center + Vector2(-4.0, -1.0), head_center + Vector2(4.0, -1.0), palette["visor_core"], 2.0)
	var scarf_dir: float = -float(direction)
	if pose in ["wall_left", "wall_right"]:
		scarf_dir = -1.0 if pose == "wall_left" else 1.0
	var scarf := PackedVector2Array([
		head_center + Vector2(-scarf_dir * 5.0, 5.0),
		head_center + Vector2(-scarf_dir * 19.0, 9.0 + sin(float(Time.get_ticks_msec()) * 0.01) * 2.0),
		head_center + Vector2(-scarf_dir * 7.0, 10.0),
	])
	canvas.draw_colored_polygon(scarf, palette["scarf"])


func _viper_palette(alpha: float, tint: Color) -> Dictionary:
	return {
		"hood": _draw_primitives.tint(_draw_primitives.color8(34, 12, 54, 255.0 * alpha), tint),
		"visor": _draw_primitives.tint(_draw_primitives.color8(108, 248, 214, 235.0 * alpha), tint),
		"visor_core": _draw_primitives.tint(_draw_primitives.color8(225, 255, 246, 255.0 * alpha), tint),
		"suit": _draw_primitives.tint(_draw_primitives.color8(54, 18, 88, 235.0 * alpha), tint),
		"chest": _draw_primitives.tint(_draw_primitives.color8(122, 48, 184, 230.0 * alpha), tint),
		"limb": _draw_primitives.tint(_draw_primitives.color8(164, 96, 232, 225.0 * alpha), tint),
		"blade": _draw_primitives.tint(_draw_primitives.color8(214, 188, 255, 245.0 * alpha), tint),
		"scarf": _draw_primitives.tint(_draw_primitives.color8(88, 255, 210, 210.0 * alpha), tint),
	}


# 오딘의 눈 어둠의 늪 미리보기: 변신 폼(좌하단) -> 보스(우상단)로 12연쇄
# 어둠 수정 가시가 순차로 솟고, 막바지에 보스가 밀려나는 씬. 클릭 큐는
# 사이클 초반 펄스 링(키캡 헬퍼의 허용-문자 elif 함정 회피 — 마우스 안내는
# control row가 소유). 좌표는 전부 _preview_metrics 패널 내부.
func _draw_odins_dark_swamp_preview(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var metrics: Dictionary = _preview_metrics(rect)
	var time_ms: int = Time.get_ticks_msec()
	var local_progress: float = float(time_ms % 2600) / 2600.0
	var preview_left: float = float(metrics["left"])
	var preview_right: float = float(metrics["right"])
	var preview_top: float = float(metrics["top"])
	var preview_bottom: float = float(metrics["bottom"])
	var floor_y: float = preview_bottom - 2.0
	canvas.draw_line(Vector2(preview_left + 8.0, floor_y), Vector2(preview_right - 8.0, floor_y), Color(90.0 / 255.0, 110.0 / 255.0, 145.0 / 255.0, 45.0 / 255.0), 2.0)
	var player := Vector2(preview_left + 42.0, preview_bottom - 10.0)
	var boss_base := Vector2(preview_right - 40.0, preview_top + 18.0)
	_draw_primitives.draw_round_rect(canvas, Rect2(player + Vector2(-10.0, -20.0), Vector2(20.0, 24.0)), Color(64.0 / 255.0, 34.0 / 255.0, 108.0 / 255.0, 200.0 / 255.0), 5.0)
	canvas.draw_circle(player + Vector2(4.0, -13.0), 1.8, Color(1.0, 0.30, 0.28, 0.95))
	var wave_t: float = clamp((local_progress - 0.16) / 0.62, 0.0, 1.0)
	var hit_t: float = clamp((local_progress - 0.82) / 0.18, 0.0, 1.0)
	var boss := boss_base + Vector2(hit_t * 10.0, -sin(hit_t * PI) * 3.0)
	var boss_color := Color(120.0 / 255.0, 132.0 / 255.0, 160.0 / 255.0, 200.0 / 255.0).lerp(Color(0.85, 0.30, 0.28, 0.9), hit_t * 0.7)
	_draw_primitives.draw_round_rect(canvas, Rect2(boss + Vector2(-13.0, -5.0), Vector2(26.0, 10.0)), boss_color, 4.0)
	if local_progress < 0.16:
		var cue_t: float = local_progress / 0.16
		canvas.draw_arc(player + Vector2(0.0, -8.0), 10.0 + cue_t * 8.0, 0.0, TAU, 28, _draw_primitives.alpha(color, (1.0 - cue_t) * 0.55), 1.4)
	for spike_index in range(12):
		var spawn_t: float = float(spike_index) / 12.0
		if wave_t <= spawn_t:
			continue
		var rise_t: float = clamp((wave_t - spawn_t) / 0.14, 0.0, 1.0)
		var path_t: float = (float(spike_index) + 0.5) / 12.0
		var base_x: float = lerp(player.x + 16.0, boss.x - 6.0, path_t)
		var base_y: float = lerp(floor_y, preview_top + 30.0, path_t * 0.55)
		var spike_h: float = (7.0 + path_t * 9.0) * rise_t
		var half_w: float = 2.4 + path_t * 1.4
		var tip := Vector2(base_x, base_y - spike_h)
		var spike_points := PackedVector2Array([
			Vector2(base_x - half_w, base_y),
			tip,
			Vector2(base_x + half_w, base_y),
		])
		canvas.draw_colored_polygon(spike_points, Color(0.36, 0.18, 0.56, 0.55 + rise_t * 0.35))
		canvas.draw_circle(tip, 1.4, _draw_primitives.alpha(color, 0.5 + rise_t * 0.4))
	if wave_t > 0.35:
		var ball_t: float = clamp((wave_t - 0.35) / 0.5, 0.0, 1.0)
		var ball_x: float = lerp(player.x + 60.0, player.x + 84.0, ball_t)
		var ball_y: float = floor_y - 12.0 - sin(ball_t * PI) * 22.0
		canvas.draw_circle(Vector2(ball_x, ball_y), 3.2, Color(1.0, 1.0, 1.0, 0.85))


func _preview_metrics(rect: Rect2) -> Dictionary:
	var center: Vector2 = rect.get_center()
	return {
		"center_x": center.x,
		"center_y": center.y,
		"left": center.x - 118.0,
		"right": center.x + 118.0,
		"top": center.y - 42.0,
		"bottom": center.y + 42.0,
	}


func _draw_smasher_mini_character(canvas: CanvasItem, cx: float, cy: float, options: Dictionary = {}) -> Dictionary:
	var b: float = float(options.get("block", 4.0))
	var direction: int = int(options.get("direction", 0))
	var swing_ratio: float = float(options.get("swing_ratio", 0.0))
	var head_offset_y: float = float(options.get("head_offset_y", 0.0))
	var show_paddle: bool = bool(options.get("show_paddle", true))
	var show_shield: bool = bool(options.get("show_shield", true))
	var paddle_lift: float = float(options.get("paddle_lift", 0.0))
	var alpha: float = float(options.get("alpha", 1.0))
	var tint: Color = _draw_primitives.get_color(options.get("tint", Color.WHITE), Color.WHITE)
	var rotation: float = float(options.get("rotation", 0.0))
	var rotation_center: Vector2 = _draw_primitives.get_vector2(options, "rotation_center", Vector2(cx, cy - 28.0))
	var torso_y: float = cy - 1.5 * b
	var arm_swing: float = swing_ratio * 1.2 * b
	var palette: Dictionary = _smasher_palette(alpha, tint)

	var helmet_rect := Rect2(Vector2(cx - 2.7 * b * 0.5, torso_y - 3.1 * b + head_offset_y), Vector2(2.7 * b, 2.2 * b))
	_draw_primitives.draw_ellipse_xf(canvas, helmet_rect, palette["helmet"], true, 1.0, rotation, rotation_center)
	_draw_primitives.draw_ellipse_xf(canvas, Rect2(Vector2(helmet_rect.position.x - 0.5 * b, helmet_rect.get_center().y - 0.5 * b), Vector2(0.8 * b, 1.4 * b)), palette["helmet_side"], true, 1.0, rotation, rotation_center)
	_draw_primitives.draw_ellipse_xf(canvas, Rect2(Vector2(helmet_rect.end.x - 0.3 * b, helmet_rect.get_center().y - 0.5 * b), Vector2(0.8 * b, 1.4 * b)), palette["helmet_side"], true, 1.0, rotation, rotation_center)
	var visor_rect := Rect2(Vector2(cx - 0.9 * b, helmet_rect.get_center().y - 0.1 * b), Vector2(1.8 * b, 0.9 * b))
	_draw_primitives.draw_ellipse_xf(canvas, visor_rect, palette["visor"], true, 1.0, rotation, rotation_center)
	_draw_primitives.draw_ellipse_xf(canvas, visor_rect.grow_individual(-0.4 * b, -0.3 * b, -0.4 * b, -0.3 * b), palette["visor_core"], true, 1.0, rotation, rotation_center)
	_draw_primitives.draw_ellipse_xf(canvas, helmet_rect.grow_individual(-0.6 * b, -0.5 * b, -0.6 * b, -0.5 * b), palette["helmet_high"], false, 1.0, rotation, rotation_center)
	_draw_primitives.draw_rect_xf(canvas, Rect2(Vector2(cx - 0.2 * b, helmet_rect.position.y + 0.2 * b), Vector2(max(1.0, 0.4 * b), 1.5 * b)), palette["helmet_high"], rotation, rotation_center)

	var chest_rect := Rect2(Vector2(cx - 3.4 * b * 0.5, torso_y - 0.4 * b), Vector2(3.4 * b, 2.2 * b))
	_draw_primitives.draw_rect_xf(canvas, chest_rect, palette["armor_outer"], rotation, rotation_center)
	var mid_rect: Rect2 = chest_rect.grow_individual(-0.5 * b, -0.4 * b, -0.5 * b, -0.4 * b)
	_draw_primitives.draw_rect_xf(canvas, mid_rect, palette["armor_mid"], rotation, rotation_center)
	var inner_panel: Rect2 = mid_rect.grow_individual(-0.5 * b, -0.3 * b, -0.5 * b, -0.3 * b)
	_draw_primitives.draw_rect_xf(canvas, inner_panel, palette["armor_inner"], rotation, rotation_center)
	_draw_primitives.draw_rect_outline_xf(canvas, chest_rect, palette["trim"], 1.0, rotation, rotation_center)
	_draw_primitives.draw_line_xf(canvas, Vector2(cx, inner_panel.position.y + 0.2 * b), Vector2(cx, inner_panel.end.y - 0.2 * b), palette["accent"], max(1.0, 0.15 * b), rotation, rotation_center)

	var abs_rect := Rect2(Vector2(cx - 1.1 * b, inner_panel.end.y - 0.1 * b), Vector2(2.2 * b, 1.2 * b))
	_draw_primitives.draw_rect_xf(canvas, abs_rect, palette["undersuit"], rotation, rotation_center)
	var belt_rect := Rect2(Vector2(cx - 1.8 * b, abs_rect.end.y - 0.1 * b), Vector2(3.6 * b, 0.7 * b))
	_draw_primitives.draw_rect_xf(canvas, belt_rect, palette["belt"], rotation, rotation_center)

	var left_pauldron := [Vector2(cx - 2.0 * b, torso_y - 0.4 * b), Vector2(cx - 1.1 * b, torso_y - 0.8 * b), Vector2(cx - 0.8 * b, torso_y + 0.7 * b), Vector2(cx - 1.9 * b, torso_y + 0.8 * b)]
	var right_pauldron := [Vector2(cx + 2.0 * b, torso_y - 0.4 * b), Vector2(cx + 1.1 * b, torso_y - 0.8 * b), Vector2(cx + 0.8 * b, torso_y + 0.7 * b), Vector2(cx + 1.9 * b, torso_y + 0.8 * b)]
	_draw_primitives.draw_poly_xf(canvas, left_pauldron, palette["armor_mid"], rotation, rotation_center)
	_draw_primitives.draw_poly_xf(canvas, right_pauldron, palette["armor_mid"], rotation, rotation_center)
	_draw_primitives.draw_line_xf(canvas, left_pauldron[0], left_pauldron[1], palette["trim"], 1.0, rotation, rotation_center)
	_draw_primitives.draw_line_xf(canvas, right_pauldron[0], right_pauldron[1], palette["trim"], 1.0, rotation, rotation_center)

	var left_shoulder := Vector2(cx - 1.6 * b, torso_y)
	var left_offset: float = arm_swing if direction == -1 else 0.0
	var left_elbow := Vector2(left_shoulder.x - 0.9 * b - left_offset, torso_y + 0.1 * b)
	var left_wrist := Vector2(left_elbow.x - 0.7 * b - left_offset, torso_y - 0.3 * b - (0.8 * b if direction == -1 and swing_ratio > 0.0 else 0.0))
	var right_shoulder := Vector2(cx + 1.6 * b, torso_y)
	var right_offset: float = arm_swing if direction == 1 else 0.0
	var right_elbow := Vector2(right_shoulder.x + 0.9 * b + right_offset, torso_y + 0.1 * b)
	var right_wrist := Vector2(right_elbow.x + 0.7 * b + right_offset, torso_y - 0.3 * b - (0.8 * b if direction == 1 and swing_ratio > 0.0 else 0.0))

	for limb in [[left_shoulder, left_elbow], [left_elbow, left_wrist], [right_shoulder, right_elbow], [right_elbow, right_wrist]]:
		_draw_primitives.draw_line_xf(canvas, limb[0], limb[1], palette["arm_light"], max(2.0, 0.8 * b), rotation, rotation_center)
		_draw_primitives.draw_line_xf(canvas, limb[0], limb[1], palette["armor_mid"], max(1.0, 0.55 * b), rotation, rotation_center)
	_draw_primitives.draw_circle_xf(canvas, left_wrist, max(2.0, 0.4 * b), palette["glove"], rotation, rotation_center)
	_draw_primitives.draw_circle_xf(canvas, right_wrist, max(2.0, 0.4 * b), palette["glove"], rotation, rotation_center)

	if show_shield:
		var shield_center := right_wrist + Vector2(0.5 * b, -0.3 * b)
		_draw_primitives.draw_preview_pentagon_xf(canvas, shield_center, 1.8 * b * 1.1, -90.0, palette["shield_glow"], rotation, rotation_center)
		_draw_primitives.draw_preview_pentagon_xf(canvas, shield_center, 1.8 * b, -90.0, Color(0.0, 0.0, 0.0, 0.0), rotation, rotation_center, palette["shield_ring"], max(1.0, 0.3 * b))
		_draw_primitives.draw_preview_pentagon_xf(canvas, shield_center, 1.8 * b * 0.5, -90.0, palette["shield_core"], rotation, rotation_center)

	var paddle_pos: Dictionary = {}
	if show_paddle:
		var handle_end := left_wrist + Vector2(-0.3 * b, -1.0 * b - (0.5 * b if swing_ratio > 0.0 else 0.0) - paddle_lift * 4.0)
		_draw_primitives.draw_line_xf(canvas, left_wrist, handle_end, palette["handle"], max(2.0, 0.35 * b), rotation, rotation_center)
		var paddle_center := handle_end + Vector2(-0.8 * b, -0.3 * b)
		var paddle_r: float = 1.5 * b
		_draw_primitives.draw_circle_xf(canvas, paddle_center + Vector2(1.0, 1.0), paddle_r, palette["paddle_shadow"], rotation, rotation_center)
		_draw_primitives.draw_circle_xf(canvas, paddle_center, paddle_r, palette["paddle"], rotation, rotation_center)
		_draw_primitives.draw_circle_xf(canvas, paddle_center, max(1.0, paddle_r - 0.25 * b), palette["paddle_core"], rotation, rotation_center)
		paddle_pos = {"center": _draw_primitives.rotate_point(paddle_center, rotation, rotation_center), "radius": paddle_r}

	return {
		"char_top": cy - 4.5 * b,
		"helmet_top": _draw_primitives.rotate_point(Vector2(cx, helmet_rect.position.y), rotation, rotation_center).y,
		"left_wrist": _draw_primitives.rotate_point(left_wrist, rotation, rotation_center),
		"right_wrist": _draw_primitives.rotate_point(right_wrist, rotation, rotation_center),
		"paddle_pos": paddle_pos,
	}


func _smasher_palette(alpha: float, tint: Color) -> Dictionary:
	return {
		"helmet": _draw_primitives.tint(Color(70.0 / 255.0, 102.0 / 255.0, 162.0 / 255.0, alpha), tint),
		"helmet_side": _draw_primitives.tint(Color(58.0 / 255.0, 82.0 / 255.0, 136.0 / 255.0, alpha), tint),
		"helmet_high": _draw_primitives.tint(Color(148.0 / 255.0, 182.0 / 255.0, 236.0 / 255.0, alpha), tint),
		"visor": _draw_primitives.tint(Color(170.0 / 255.0, 224.0 / 255.0, 1.0, alpha), tint),
		"visor_core": _draw_primitives.tint(Color(126.0 / 255.0, 192.0 / 255.0, 246.0 / 255.0, alpha), tint),
		"armor_outer": _draw_primitives.tint(Color(80.0 / 255.0, 96.0 / 255.0, 150.0 / 255.0, alpha), tint),
		"armor_mid": _draw_primitives.tint(Color(60.0 / 255.0, 76.0 / 255.0, 120.0 / 255.0, alpha), tint),
		"armor_inner": _draw_primitives.tint(Color(46.0 / 255.0, 58.0 / 255.0, 92.0 / 255.0, alpha), tint),
		"trim": _draw_primitives.tint(Color(190.0 / 255.0, 206.0 / 255.0, 236.0 / 255.0, alpha), tint),
		"accent": _draw_primitives.tint(Color(118.0 / 255.0, 214.0 / 255.0, 1.0, alpha), tint),
		"undersuit": _draw_primitives.tint(Color(36.0 / 255.0, 40.0 / 255.0, 58.0 / 255.0, alpha), tint),
		"arm_light": _draw_primitives.tint(Color(132.0 / 255.0, 152.0 / 255.0, 204.0 / 255.0, alpha), tint),
		"glove": _draw_primitives.tint(Color(198.0 / 255.0, 182.0 / 255.0, 164.0 / 255.0, alpha), tint),
		"paddle": _draw_primitives.tint(Color(220.0 / 255.0, 56.0 / 255.0, 74.0 / 255.0, alpha), tint),
		"paddle_core": _draw_primitives.tint(Color(244.0 / 255.0, 116.0 / 255.0, 132.0 / 255.0, alpha), tint),
		"paddle_shadow": _draw_primitives.tint(Color(154.0 / 255.0, 42.0 / 255.0, 58.0 / 255.0, alpha), tint),
		"handle": _draw_primitives.tint(Color(174.0 / 255.0, 132.0 / 255.0, 98.0 / 255.0, alpha), tint),
		"belt": _draw_primitives.tint(Color(88.0 / 255.0, 78.0 / 255.0, 108.0 / 255.0, alpha), tint),
		"shield_glow": _draw_primitives.tint(Color(70.0 / 255.0, 160.0 / 255.0, 1.0, alpha), tint),
		"shield_ring": _draw_primitives.tint(Color(120.0 / 255.0, 210.0 / 255.0, 1.0, alpha), tint),
		"shield_core": _draw_primitives.tint(Color(200.0 / 255.0, 252.0 / 255.0, 1.0, alpha), tint),
	}


func _draw_blue_energy_ball(canvas: CanvasItem, pos: Vector2, radius: float) -> void:
	for i in range(3):
		canvas.draw_circle(pos, radius + 3.0 - float(i), Color((30.0 + float(i) * 15.0) / 255.0, (80.0 + float(i) * 25.0) / 255.0, (180.0 + float(i) * 15.0) / 255.0))
	canvas.draw_circle(pos, radius, Color(100.0 / 255.0, 180.0 / 255.0, 1.0))
	canvas.draw_circle(pos + Vector2(-1.0, -1.0), 2.0, Color(200.0 / 255.0, 235.0 / 255.0, 1.0))


func _draw_preview_ball(canvas: CanvasItem, pos: Vector2, radius: float = 6.0, glow_colors: Array = [], core_color: Color = Color.WHITE) -> void:
	var colors: Array = glow_colors
	if colors.is_empty():
		colors = [Color(36.0 / 255.0, 92.0 / 255.0, 210.0 / 255.0), Color(88.0 / 255.0, 164.0 / 255.0, 1.0), Color(220.0 / 255.0, 242.0 / 255.0, 1.0)]
	for idx in range(colors.size()):
		var c: Color = _draw_primitives.get_color(colors[idx], Color.WHITE)
		canvas.draw_circle(pos, radius + float(colors.size() - idx) * 2.0, _draw_primitives.alpha(c, min(1.0, (48.0 + float(idx) * 36.0) / 255.0)))
	canvas.draw_circle(pos, radius, core_color)
	canvas.draw_circle(pos + Vector2(-1.0, -1.0), max(1.0, radius / 3.0), Color.WHITE)


func _draw_preview_keycap_row(canvas: CanvasItem, center: Vector2, letters: Array, separator: String = "plus", active_idx: int = -1, accent_color: Color = Color.WHITE) -> void:
	if letters.is_empty():
		return
	var keycap_w := 16.0
	var sep_w := 8.0
	var total_w: float = float(letters.size()) * keycap_w + max(0.0, float(letters.size() - 1)) * sep_w
	var start_x: float = center.x - total_w * 0.5 + keycap_w * 0.5
	for i in range(letters.size()):
		var kx: float = start_x + float(i) * (keycap_w + sep_w)
		_draw_preview_keycap(canvas, Vector2(kx, center.y), str(letters[i]))
		if active_idx == i:
			_draw_primitives.draw_round_rect_outline(canvas, Rect2(Vector2(kx - 9.0, center.y - 8.0), Vector2(18.0, 16.0)), _draw_primitives.alpha(accent_color, 220.0 / 255.0), 3.0, 1.0)
		if i < letters.size() - 1:
			var sx: float = kx + keycap_w * 0.5 + sep_w * 0.5
			if separator == "arrow":
				_draw_preview_arrow(canvas, Vector2(sx, center.y))
			else:
				_draw_preview_plus(canvas, Vector2(sx, center.y))


func _draw_preview_keycap(canvas: CanvasItem, center: Vector2, letter: String) -> void:
	var rect := Rect2(center - Vector2(8.0, 7.0), Vector2(16.0, 14.0))
	_draw_primitives.draw_round_rect(canvas, rect, Color(25.0 / 255.0, 30.0 / 255.0, 40.0 / 255.0), 3.0)
	_draw_primitives.draw_round_rect_outline(canvas, rect, Color(70.0 / 255.0, 75.0 / 255.0, 85.0 / 255.0), 3.0, 1.0)
	_draw_primitives.draw_round_rect(canvas, Rect2(rect.position + Vector2(2.0, 2.0), Vector2(12.0, 8.0)), Color(45.0 / 255.0, 50.0 / 255.0, 60.0 / 255.0), 2.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var size := 9
		var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
		canvas.draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color.WHITE)


func _draw_preview_mouse(canvas: CanvasItem, center: Vector2, button_left: bool = true) -> void:
	var rect := Rect2(center + Vector2(-5.0, -6.0), Vector2(10.0, 14.0))
	_draw_primitives.draw_round_rect(canvas, rect, Color(35.0 / 255.0, 40.0 / 255.0, 50.0 / 255.0), 3.0)
	_draw_primitives.draw_round_rect_outline(canvas, rect, Color(75.0 / 255.0, 80.0 / 255.0, 90.0 / 255.0), 3.0, 1.0)
	_draw_primitives.draw_round_rect(canvas, Rect2(center + Vector2(-4.0, -5.0), Vector2(4.0, 5.0)), Color(1.0, 200.0 / 255.0, 80.0 / 255.0) if button_left else Color(55.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0), 1.0)
	_draw_primitives.draw_round_rect(canvas, Rect2(center + Vector2(0.0, -5.0), Vector2(4.0, 5.0)), Color(55.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0) if button_left else Color(1.0, 200.0 / 255.0, 80.0 / 255.0), 1.0)
	canvas.draw_line(center + Vector2(-1.0, -5.0), center + Vector2(-1.0, 3.0), Color(45.0 / 255.0, 50.0 / 255.0, 60.0 / 255.0), 1.0)


func _draw_preview_plus(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0), 1.0)
	canvas.draw_line(center + Vector2(0.0, -3.0), center + Vector2(0.0, 3.0), Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0), 1.0)


func _draw_preview_arrow(canvas: CanvasItem, center: Vector2) -> void:
	var c := Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0)
	canvas.draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), c, 1.0)
	canvas.draw_line(center + Vector2(1.0, -2.0), center + Vector2(3.0, 0.0), c, 1.0)
	canvas.draw_line(center + Vector2(1.0, 2.0), center + Vector2(3.0, 0.0), c, 1.0)


func _draw_ghost_charge(canvas: CanvasItem, anchors: Dictionary, color: Color, phase: float, time_ms: int) -> void:
	var paddle: Dictionary = _draw_primitives.get_dictionary(anchors.get("paddle_pos", {}))
	if paddle.is_empty():
		return
	var p_center: Vector2 = _draw_primitives.get_vector2(paddle, "center", Vector2.ZERO)
	var p_radius: float = float(paddle.get("radius", 6.0))
	var charge := p_center + Vector2(0.0, -p_radius - 6.0)
	var pulse: float = 1.0 + 0.18 * sin(float(time_ms) * 0.025)
	var core_r: float = max(2.0, (3.0 + phase * 5.0) * pulse)
	for ring_idx in range(4):
		canvas.draw_arc(charge, core_r + float(ring_idx) * 3.0, 0.0, TAU, 36, _draw_primitives.alpha(color, max(30.0, (150.0 - float(ring_idx) * 30.0) * phase) / 255.0), 1.0)
	canvas.draw_circle(charge, core_r, color)
	canvas.draw_circle(charge + Vector2(-1.0, -1.0), max(1.0, core_r * 0.5), Color(235.0 / 255.0, 200.0 / 255.0, 1.0))
	for ghost_idx in range(3):
		var ga: float = TAU * float(ghost_idx) / 3.0 + float(time_ms) * 0.004
		var gd: float = 12.0 + sin(float(time_ms) * 0.008 + float(ghost_idx)) * 3.0
		var gpos: Vector2 = charge + Vector2(cos(ga), sin(ga)) * gd
		canvas.draw_circle(gpos, 3.0, _draw_primitives.alpha(color, 160.0 / 255.0))
		canvas.draw_circle(gpos + Vector2(0.0, -1.0), 2.0, Color(220.0 / 255.0, 200.0 / 255.0, 1.0))


func _draw_small_ghost(canvas: CanvasItem, pos: Vector2, color: Color, time_ms: int) -> void:
	canvas.draw_circle(pos + Vector2(0.0, -4.0), 7.0, _draw_primitives.alpha(color, 200.0 / 255.0))
	canvas.draw_circle(pos + Vector2(-2.0, -6.0), 2.0, Color(220.0 / 255.0, 200.0 / 255.0, 1.0, 200.0 / 255.0))
	canvas.draw_circle(pos + Vector2(2.0, -6.0), 2.0, Color(220.0 / 255.0, 200.0 / 255.0, 1.0, 200.0 / 255.0))
	canvas.draw_line(pos + Vector2(-2.0, -1.0), pos + Vector2(2.0, -1.0), Color(40.0 / 255.0, 0.0, 60.0 / 255.0), 1.0)
	for tail_idx in range(3):
		var tx: float = pos.x + sin(float(time_ms) * 0.005 + float(tail_idx)) * 3.0
		var ty: float = pos.y + 4.0 + float(tail_idx) * 4.0
		canvas.draw_circle(Vector2(tx, ty), max(2.0, 6.0 - float(tail_idx)), _draw_primitives.alpha(color, max(40.0, 140.0 - float(tail_idx) * 35.0) / 255.0))


func _draw_bezier_polyline(canvas: CanvasItem, start: Vector2, finish: Vector2, lift: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for s in range(7):
		var t: float = float(s) / 6.0
		points.append(start.lerp(finish, t) + Vector2(0.0, sin(t * PI) * lift))
	canvas.draw_polyline(points, color, width)


func _draw_mini_star_gd(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(5):
		var outer_angle: float = deg_to_rad(-90.0 + float(i) * 72.0)
		var inner_angle: float = deg_to_rad(-90.0 + float(i) * 72.0 + 36.0)
		points.append(center + Vector2(cos(outer_angle), sin(outer_angle)) * size)
		points.append(center + Vector2(cos(inner_angle), sin(inner_angle)) * size * 0.4)
	canvas.draw_colored_polygon(points, color)
