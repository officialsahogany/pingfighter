extends RefCounted

const ARACHNE_LEG_TEMPLATES := [
	[0.09, -0.035, 0.30, -0.19, 0.35, 0.13],
	[0.09, -0.005, 0.33, -0.10, 0.37, 0.22],
	[0.09, 0.025, 0.31, -0.01, 0.34, 0.32],
	[0.09, 0.050, 0.25, 0.07, 0.27, 0.39],
]
const ARACHNE_LEG_PHASE_OFFSETS := [0.00, 0.50, 0.58, 0.08, 0.16, 0.66, 0.74, 0.24]
const ARACHNE_SWING_RATIO := 0.40


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	match str(context.get("stage_boss_variant", "")):
		"molewang":
			_draw_tunnel_warning(canvas, context, shake_offset)
			_draw_tunnel_spikes(canvas, context, shake_offset)
			_draw_friend_mole_particles(canvas, context, shake_offset)
			_draw_friend_moles(canvas, context, shake_offset)
			_draw_molewang(canvas, context, shake_offset)
		"arachne":
			_draw_arachne_webs(canvas, context, shake_offset)
			_draw_arachne(canvas, context, shake_offset)


func _draw_molewang(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(330.0, 25.0))), Vector2(330.0, 25.0)) + shake_offset
	var boss_size := _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	# GRT-052: the Python procedural frame placed its ground line 18 px below
	# the live paddle bottom. Anchor that absolute bottom-line gap to Godot's
	# current hitbox instead of copying the old sprite-center offset.
	var center := boss_pos + Vector2(boss_size.x * 0.5, boss_size.y + 18.0)
	var hit_progress := clampf(float(context.get("molewang_hit_emerge_progress", 0.0)), 0.0, 1.0)
	var claw_active := bool(context.get("molewang_spinning_claw_active", false))
	var tunnel_active := bool(context.get("molewang_tunnel_active", false))
	var tunnel_phase := str(context.get("molewang_tunnel_phase", "idle"))
	var emerge := 0.0
	if hit_progress > 0.0:
		var elapsed := 1.0 - hit_progress
		emerge = clampf(elapsed / 0.18, 0.0, 1.0) if elapsed < 0.55 else clampf((1.0 - elapsed) / 0.45, 0.0, 1.0)
	if claw_active:
		emerge = 1.0
	if tunnel_active:
		emerge = 1.0
		if tunnel_phase == "warn":
			emerge = 1.0 - clampf(float(context.get("molewang_tunnel_progress", 0.0)), 0.0, 1.0)
		elif tunnel_phase == "return":
			emerge = 1.0 - clampf(float(context.get("molewang_tunnel_progress", 0.0)), 0.0, 1.0)
	_draw_ground_mound(canvas, center)
	if emerge <= 0.04:
		return
	var body_height := 62.0 * emerge
	var body_rect := Rect2(center.x - 24.0, center.y - body_height, 48.0, body_height + 10.0)
	canvas.draw_rect(body_rect, Color("8c6846"), true)
	canvas.draw_circle(Vector2(center.x, center.y - body_height), 24.0, Color("af875f"))
	canvas.draw_arc(Vector2(center.x, center.y - body_height), 24.0, PI, TAU, 24, Color("60442e"), 3.0)
	var face_y := center.y - body_height + 5.0
	for side in [-1.0, 1.0]:
		var eye := Vector2(center.x + side * 9.0, face_y)
		canvas.draw_circle(eye, 4.2, Color.WHITE)
		canvas.draw_circle(eye, 2.2, Color("16100b"))
	_draw_nose(canvas, Vector2(center.x, face_y + 11.0))
	_draw_crown(canvas, Vector2(center.x, center.y - body_height - 18.0))
	if claw_active:
		_draw_claw(canvas, center, int(context.get("molewang_spinning_claw_direction", 1)), float(context.get("molewang_spinning_claw_progress", 0.0)))


func _draw_ground_mound(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-34.0, 6.0), center + Vector2(-24.0, -2.0), center + Vector2(0.0, -8.0),
		center + Vector2(25.0, -2.0), center + Vector2(35.0, 6.0), center + Vector2(0.0, 11.0),
	]), Color("6f5030"))
	canvas.draw_arc(center + Vector2(0.0, 2.0), 26.0, PI, TAU, 20, Color("ba8751"), 3.0)


func _draw_nose(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_circle(center, 5.5, Color("e09691"))
	canvas.draw_circle(center + Vector2(-1.5, -1.5), 1.5, Color("f5b4aa"))


func _draw_crown(canvas: CanvasItem, center: Vector2) -> void:
	var points := PackedVector2Array([
		center + Vector2(-16.0, 10.0), center + Vector2(-14.0, -5.0), center + Vector2(-6.0, 3.0),
		center, center + Vector2(7.0, 3.0), center + Vector2(15.0, -5.0), center + Vector2(16.0, 10.0),
	])
	canvas.draw_colored_polygon(points, Color("d7b437"))
	canvas.draw_polyline(points, Color("8c6f1c"), 2.0)
	canvas.draw_circle(center + Vector2(0.0, 5.0), 2.5, Color("cb322f"))


func _draw_claw(canvas: CanvasItem, center: Vector2, direction: int, progress: float) -> void:
	var dir := 1.0 if direction >= 0 else -1.0
	var angle := lerpf(-1.3, 1.0, clampf(progress, 0.0, 1.0)) * dir
	for index in range(3):
		var radius := 42.0 + float(index) * 7.0
		canvas.draw_arc(center + Vector2(dir * 4.0, -25.0), radius, angle - 0.55 * dir, angle, 16, Color("fff7dc"), 4.0)


func build_tunnel_warning_geometry(context: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> Dictionary:
	if str(context.get("stage_boss_variant", "")) != "molewang" or not bool(context.get("molewang_tunnel_warning_active", false)):
		return {}
	var boss_pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(330.0, 25.0))), Vector2(330.0, 25.0))
	var boss_size := _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var boss_center := boss_pos + boss_size * 0.5 + shake_offset
	var player_pos := _as_vector2(context.get("player_pos", Vector2(302.5, 700.0)), Vector2(302.5, 700.0))
	var player_size := _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center := player_pos + player_size * 0.5 + shake_offset
	var pulse := sin(clampf(float(context.get("molewang_tunnel_progress", 0.0)), 0.0, 1.0) * 15.0) * 0.5 + 0.5
	var cross_size := 12.0 + pulse * 4.0
	return {
		"pulse": pulse,
		"boss_exclamation_triangle": PackedVector2Array([
			boss_center + Vector2(0.0, -34.0),
			boss_center + Vector2(-10.0, -20.0),
			boss_center + Vector2(10.0, -20.0),
		]),
		"boss_exclamation_stem": PackedVector2Array([
			boss_center + Vector2(0.0, -31.0),
			boss_center + Vector2(0.0, -22.0),
		]),
		"boss_exclamation_dot": boss_center + Vector2(0.0, -19.0),
		"player_foot_cross_a": PackedVector2Array([
			player_center + Vector2(-cross_size, -cross_size),
			player_center + Vector2(cross_size, cross_size),
		]),
		"player_foot_cross_b": PackedVector2Array([
			player_center + Vector2(cross_size, -cross_size),
			player_center + Vector2(-cross_size, cross_size),
		]),
	}


func _draw_tunnel_warning(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var geometry := build_tunnel_warning_geometry(context, shake_offset)
	if geometry.is_empty():
		return
	var pulse := float(geometry.get("pulse", 0.0))
	canvas.draw_colored_polygon(geometry["boss_exclamation_triangle"], Color(1.0, 0.31, 0.20, 0.71 + 0.29 * pulse))
	var highlight := Color(1.0, 1.0, 0.78, 0.71 + 0.29 * pulse)
	var stem: PackedVector2Array = geometry["boss_exclamation_stem"]
	canvas.draw_line(stem[0], stem[1], highlight, 2.0)
	canvas.draw_circle(geometry["boss_exclamation_dot"], 1.5, highlight)
	var cross_color := Color(1.0, 0.24, 0.16, 0.35 + 0.45 * pulse)
	var cross_a: PackedVector2Array = geometry["player_foot_cross_a"]
	var cross_b: PackedVector2Array = geometry["player_foot_cross_b"]
	canvas.draw_line(cross_a[0], cross_a[1], cross_color, 3.0)
	canvas.draw_line(cross_b[0], cross_b[1], cross_color, 3.0)


func _draw_tunnel_spikes(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var spikes: Array = context.get("molewang_tunnel_spikes", [])
	for value in spikes:
		if not (value is Dictionary):
			continue
		var spike: Dictionary = value
		var pos := _as_vector2(spike.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var age := float(spike.get("age", 0.0))
		var life := maxf(0.001, float(spike.get("life", 1.0)))
		var ratio := clampf(age / life, 0.0, 1.0)
		var envelope := clampf(ratio * 8.0, 0.0, 1.0) * clampf((1.0 - ratio) * 7.0, 0.0, 1.0)
		var height := float(spike.get("height", 45.0)) * envelope
		var half_width := float(spike.get("width", 6.0))
		canvas.draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-half_width, 0.0), pos + Vector2(0.0, -height), pos + Vector2(half_width, 0.0),
		]), Color("d6c7a6"))
		canvas.draw_line(pos + Vector2(-half_width - 4.0, 1.0), pos + Vector2(half_width + 4.0, 1.0), Color("795536"), 3.0)


func _draw_friend_moles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var moles: Array = context.get("molewang_friend_moles", [])
	for value in moles:
		if not (value is Dictionary):
			continue
		var mole: Dictionary = value
		var phase := str(mole.get("phase", "rising"))
		var phase_age := float(mole.get("phase_age", 0.0))
		var emerge := 1.0
		if phase == "rising":
			emerge = clampf(phase_age / (12.0 / 60.0), 0.0, 1.0)
		elif phase == "falling":
			emerge = clampf(1.0 - phase_age / (12.0 / 60.0), 0.0, 1.0)
		var center := _as_vector2(mole.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(center + Vector2(0.0, 8.0), 20.0, Color(0.20, 0.13, 0.08, 0.75))
		canvas.draw_circle(center + Vector2(0.0, 10.0 - 18.0 * emerge), 15.0, Color("d5a62e"))
		canvas.draw_circle(center + Vector2(-5.0, 6.0 - 18.0 * emerge), 2.0, Color("17110b"))
		canvas.draw_circle(center + Vector2(5.0, 6.0 - 18.0 * emerge), 2.0, Color("17110b"))


func _draw_friend_mole_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	for value in context.get("molewang_friend_mole_particles", []):
		if not (value is Dictionary):
			continue
		var particle: Dictionary = value
		var pos := _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var life := maxf(0.001, float(particle.get("life", 0.25)))
		var alpha := clampf(1.0 - float(particle.get("age", 0.0)) / life, 0.0, 1.0)
		var size := maxf(1.0, float(particle.get("size", 2.0)))
		var color_value: Variant = particle.get("color", Color("8b5a2b"))
		var color: Color = color_value if color_value is Color else Color("8b5a2b")
		color.a *= alpha
		if str(particle.get("kind", "dirt")) == "star":
			var points := PackedVector2Array()
			for point_index in range(11):
				var radius := size if point_index % 2 == 0 else size * 0.42
				var angle := -PI * 0.5 + float(point_index) * PI / 5.0
				points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
			canvas.draw_polyline(points, color, 2.0)
		else:
			canvas.draw_circle(pos, size, color)


func _draw_arachne(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(315.0, 25.0))), Vector2(315.0, 25.0)) + shake_offset
	var boss_size := _as_vector2(context.get("boss_paddle_size", Vector2(130.0, 52.0)), Vector2(130.0, 52.0))
	var hit_progress := clampf(float(context.get("arachne_hit_progress", 0.0)), 0.0, 1.0)
	var hit_direction := signf(float(context.get("arachne_hit_direction", 1)))
	var hit_recoil := sin((1.0 - hit_progress) * PI) * hit_progress * -hit_direction * 7.0
	var body_bob := float(context.get("arachne_body_bob", 0.0)) * 120.0
	var center := boss_pos + Vector2(boss_size.x * 0.5 + hit_recoil, boss_size.y + 16.0 + body_bob + float(context.get("arachne_rage_stomp_offset_y", 0.0)))
	var hit_flash := hit_progress * 0.22
	var rage_tint := clampf(float(context.get("arachne_rage_red_tint", 0.0)), 0.0, 1.0)
	var body_color := Color("281c16").lerp(Color.WHITE, hit_flash).lerp(Color("8f1816"), rage_tint * 0.55)
	var leg_color := Color("3a2018").lerp(Color("8b211d"), rage_tint * 0.45)
	var motion_direction := int(context.get("arachne_motion_direction", 0))
	var motion_speed := float(context.get("arachne_motion_speed", 0.0))
	var gait_phase := float(context.get("arachne_step_phase", 0.0))
	var twitch_value: Variant = context.get("arachne_leg_twitch", [])
	var leg_twitch: Array = twitch_value if twitch_value is Array else []
	for pair_index in range(4):
		for side in [-1.0, 1.0]:
			var leg_index := pair_index * 2 + (1 if side > 0.0 else 0)
			var twitch := float(leg_twitch[leg_index]) if leg_index < leg_twitch.size() else 0.0
			_draw_arachne_leg(canvas, center, pair_index, side, leg_index, motion_direction, motion_speed, gait_phase, twitch, hit_progress, leg_color)
	canvas.draw_circle(center + Vector2(0.0, 15.0), 30.0, Color("201712"))
	canvas.draw_circle(center + Vector2(0.0, -13.0), 23.0, body_color)
	for chevron_index in range(3):
		var chevron_y := center.y + 3.0 + float(chevron_index) * 9.0
		var width := 17.0 - float(chevron_index) * 2.0
		canvas.draw_polyline(PackedVector2Array([
			Vector2(center.x - width, chevron_y), Vector2(center.x, chevron_y + 7.0), Vector2(center.x + width, chevron_y),
		]), Color("c98a38"), 3.0)
	for side in [-1.0, 1.0]:
		for eye_index in range(2):
			var eye_pos := center + Vector2(side * (5.0 + float(eye_index) * 5.0), -18.0 + float(eye_index) * 5.0)
			canvas.draw_circle(eye_pos, 2.8, Color("7d2017"))
			canvas.draw_circle(eye_pos + Vector2(-0.5, -0.5), 0.9, Color("f5ddc9"))
		var fang_root := center + Vector2(side * 7.0, 1.0)
		canvas.draw_colored_polygon(PackedVector2Array([
			fang_root, fang_root + Vector2(side * 5.0, 11.0), fang_root + Vector2(side * 1.0, 8.0),
		]), Color("b63827"))
	for particle_value in context.get("arachne_venom_particles", []):
		if particle_value is not Dictionary:
			continue
		var particle: Dictionary = particle_value
		var particle_pos := center + Vector2(0.0, 6.0) + _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var alpha := clampf(float(particle.get("remaining", 0.0)) / maxf(0.001, float(particle.get("lifetime", 0.55))), 0.0, 1.0)
		var particle_size := maxf(1.0, float(particle.get("size", 1.5)))
		canvas.draw_circle(particle_pos, particle_size * 2.2, Color(0.24, 0.62, 0.20, alpha * 0.22))
		canvas.draw_circle(particle_pos, particle_size, Color(0.56, 0.93, 0.28, alpha * 0.95))


func _draw_arachne_leg(canvas: CanvasItem, center: Vector2, pair_index: int, side: float, leg_index: int, motion_direction: int, motion_speed: float, gait_phase: float, twitch: float, hit_progress: float, leg_color: Color) -> void:
	var template: Array = ARACHNE_LEG_TEMPLATES[pair_index]
	var visual_width := 160.0
	var visual_height := 120.0
	var hip := center + Vector2(side * float(template[0]) * visual_width, float(template[1]) * visual_height)
	var knee := center + Vector2(side * float(template[2]) * visual_width, float(template[3]) * visual_height)
	var foot := center + Vector2(side * float(template[4]) * visual_width, float(template[5]) * visual_height)
	if motion_direction != 0:
		var speed_ratio := minf(motion_speed / 100.0, 1.0)
		var cycle := fposmod(gait_phase + float(ARACHNE_LEG_PHASE_OFFSETS[leg_index]), 1.0)
		if cycle < ARACHNE_SWING_RATIO:
			var swing_ratio := cycle / ARACHNE_SWING_RATIO
			var smoothed := _arachne_smoothstep(swing_ratio)
			var lift := sin(swing_ratio * PI)
			foot.y -= lift * visual_height * 0.13 * speed_ratio
			knee.y -= lift * visual_height * 0.07 * speed_ratio
			var lateral := sin(swing_ratio * PI) * visual_width * 0.09 * speed_ratio
			foot.x += side * lateral
			knee.x += side * lateral * 0.35
			foot.x += float(motion_direction) * smoothed * visual_width * 0.035 * speed_ratio
			knee.x += float(motion_direction) * smoothed * visual_width * 0.018 * speed_ratio
		else:
			var stance_ratio := (cycle - ARACHNE_SWING_RATIO) / (1.0 - ARACHNE_SWING_RATIO)
			var smoothed := _arachne_smoothstep(stance_ratio)
			var lateral_remaining := 1.0 - smoothed
			foot.x += side * lateral_remaining * visual_width * 0.045 * speed_ratio
			knee.x += side * lateral_remaining * visual_width * 0.015 * speed_ratio
			foot.x += float(motion_direction) * (1.0 - smoothed) * visual_width * 0.035 * speed_ratio
			foot.x -= float(motion_direction) * smoothed * visual_width * 0.030 * speed_ratio
			knee.x += float(motion_direction) * (1.0 - smoothed) * visual_width * 0.018 * speed_ratio
			knee.x -= float(motion_direction) * smoothed * visual_width * 0.012 * speed_ratio
			foot.y = center.y + float(template[5]) * visual_height
	else:
		knee += Vector2(twitch * visual_width * 0.20, twitch * visual_height * 0.10)
		foot.x += twitch * visual_width * 0.25
	if hit_progress > 0.0 and pair_index == 0:
		var hit_elapsed := 1.0 - hit_progress
		var kick := sin((hit_elapsed / 0.20) * PI * 0.5) if hit_elapsed < 0.20 else maxf(0.0, cos(((hit_elapsed - 0.20) / 0.80) * PI * 0.5))
		knee += Vector2(side * kick * visual_width * 0.04, kick * visual_height * 0.18)
		foot += Vector2(-side * kick * visual_width * 0.10, kick * visual_height * 0.28)
	var hit_spasm := sin(float(leg_index) * 1.73 + (1.0 - hit_progress) * 25.0) * 5.0 * hit_progress
	knee.x += hit_spasm
	var coxa := hip.lerp(knee, 0.22)
	var mid_joint := knee.lerp(foot, 0.55)
	var points := [hip, coxa, knee, mid_joint, foot]
	var widths := [6.8, 6.0, 4.8, 3.4]
	for segment_index in range(4):
		canvas.draw_line(points[segment_index], points[segment_index + 1], Color("1e120d"), float(widths[segment_index]) + 2.0)
		canvas.draw_line(points[segment_index], points[segment_index + 1], leg_color, float(widths[segment_index]))
	for joint_index in range(1, 4):
		var radius := 4.2 if joint_index == 2 else 3.2
		canvas.draw_circle(points[joint_index], radius + 1.2, Color("21130e"))
		canvas.draw_circle(points[joint_index], radius, Color("604033"))
	canvas.draw_line(foot, foot + Vector2(side * 2.2, 1.2), Color("1b100c"), 1.8)


func _arachne_smoothstep(value: float) -> float:
	var normalized := clampf(value, 0.0, 1.0)
	return normalized * normalized * (3.0 - 2.0 * normalized)


func _draw_arachne_webs(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var projectile_value: Variant = context.get("arachne_web_trap_projectile", {})
	if projectile_value is Dictionary and not projectile_value.is_empty():
		_draw_web_projectile(canvas, projectile_value, shake_offset)
	for value in context.get("arachne_rage_projectiles", []):
		if value is Dictionary:
			_draw_web_projectile(canvas, value, shake_offset)
	for value in context.get("arachne_web_traps", []):
		if value is Dictionary:
			_draw_web_trap(canvas, value, shake_offset)
	for value in context.get("arachne_web_break_bursts", []):
		if not (value is Dictionary):
			continue
		var burst: Dictionary = value
		var center := _as_vector2(burst.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var ratio := clampf(float(burst.get("age", 0.0)) / 0.55, 0.0, 1.0)
		var color := Color("ffd750") if bool(burst.get("golden", false)) else Color("ded7d0")
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			canvas.draw_line(center + Vector2.from_angle(angle) * 8.0, center + Vector2.from_angle(angle) * lerpf(12.0, 48.0, ratio), Color(color, 1.0 - ratio), 2.0)
	_draw_arachne_web_rescue(canvas, context, shake_offset)


func resolve_arachne_rescue_draw_method(context: Dictionary) -> StringName:
	if not bool(context.get("arachne_web_rescue_active", false)):
		return StringName()
	match str(context.get("arachne_web_rescue_phase", "")):
		"shoot":
			return &"_draw_arachne_web_rescue_shoot"
		"hold_wait":
			return &"_draw_arachne_web_rescue_hold_wait"
		"pull":
			return &"_draw_arachne_web_rescue_pull"
		"hold":
			return &"_draw_arachne_web_rescue_hold"
		"strike":
			return &"_draw_arachne_web_rescue_strike"
	return StringName()


func _draw_arachne_web_rescue(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var draw_method := resolve_arachne_rescue_draw_method(context)
	if draw_method.is_empty():
		return
	var boss_anchor := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(315.0, 25.0))), Vector2(315.0, 25.0)) + Vector2(65.0, 57.0) + shake_offset
	var ball_anchor := _as_vector2(context.get("arachne_web_rescue_ball_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var progress := clampf(float(context.get("arachne_web_rescue_progress", 0.0)), 0.0, 1.0)
	call(draw_method, canvas, boss_anchor, ball_anchor, progress)


func _draw_arachne_web_rescue_shoot(canvas: CanvasItem, boss_anchor: Vector2, ball_anchor: Vector2, progress: float) -> void:
	var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
	var head := boss_anchor.lerp(ball_anchor, eased)
	var axis := head - boss_anchor
	var normal := axis.normalized().orthogonal() if axis.length_squared() > 0.001 else Vector2.RIGHT
	canvas.draw_line(boss_anchor, head, Color(0.68, 0.76, 1.0, 0.24), 13.0)
	canvas.draw_line(boss_anchor, head, Color(0.94, 0.96, 1.0, 0.94), 4.5)
	for strand_index in range(5):
		var strand_offset := float(strand_index - 2) * 4.0
		var wave := sin(progress * PI * 2.0 + float(strand_index) * 1.25) * 3.0
		var points := PackedVector2Array([
			boss_anchor + normal * strand_offset * 0.25,
			boss_anchor.lerp(head, 0.34) + normal * (strand_offset + wave),
			boss_anchor.lerp(head, 0.70) + normal * (strand_offset * 0.55 - wave),
			head + normal * strand_offset * 0.15,
		])
		canvas.draw_polyline(points, Color(0.88, 0.91, 1.0, 0.68), 1.6)
	for trail_index in range(4):
		var trail_ratio := maxf(0.0, eased - float(trail_index + 1) * 0.055)
		var trail_pos := boss_anchor.lerp(ball_anchor, trail_ratio)
		canvas.draw_circle(trail_pos, 8.0 - float(trail_index) * 1.3, Color(0.72, 0.82, 1.0, 0.28 - float(trail_index) * 0.045))
	canvas.draw_circle(head, 14.0, Color(0.55, 0.68, 1.0, 0.25))
	canvas.draw_circle(head, 7.0, Color(0.96, 0.98, 1.0, 0.96))
	for spark_index in range(4):
		var spark_dir := Vector2.from_angle(TAU * float(spark_index) / 4.0 + progress * 1.7)
		var spark_center := boss_anchor + spark_dir * (9.0 + 3.0 * sin(progress * PI))
		canvas.draw_colored_polygon(PackedVector2Array([
			spark_center + spark_dir * 4.5,
			spark_center + spark_dir.orthogonal() * 2.0,
			spark_center - spark_dir * 4.5,
			spark_center - spark_dir.orthogonal() * 2.0,
		]), Color(0.94, 0.97, 1.0, 0.82))
	var target_center := Vector2(ball_anchor.x, maxf(ball_anchor.y + 8.0, 28.0))
	canvas.draw_circle(target_center, 22.0, Color(0.45, 0.58, 1.0, 0.10))
	canvas.draw_arc(target_center, 19.0, 0.0, PI, 24, Color(0.91, 0.94, 1.0, 0.86), 3.0)
	canvas.draw_line(target_center + Vector2(-13.0, 7.0), target_center + Vector2(13.0, 7.0), Color(0.96, 0.97, 1.0, 0.88), 2.0)
	canvas.draw_line(target_center + Vector2(0.0, -2.0), target_center + Vector2(0.0, 19.0), Color(0.96, 0.97, 1.0, 0.88), 2.0)


func _draw_arachne_web_rescue_hold_wait(canvas: CanvasItem, boss_anchor: Vector2, ball_anchor: Vector2, progress: float) -> void:
	var pulse := 1.0 + sin(progress * TAU * 4.0) * 0.08
	var cocoon_center := Vector2(ball_anchor.x, maxf(ball_anchor.y + 10.0, 30.0))
	canvas.draw_line(boss_anchor, ball_anchor, Color(0.57, 0.68, 0.96, 0.22), 11.0)
	canvas.draw_line(boss_anchor, ball_anchor, Color(0.92, 0.94, 1.0, 0.78), 3.2)
	canvas.draw_circle(cocoon_center, 27.0 * pulse, Color(0.55, 0.66, 0.96, 0.13))
	canvas.draw_colored_polygon(PackedVector2Array([
		cocoon_center + Vector2(0.0, -22.0 * pulse),
		cocoon_center + Vector2(18.0 * pulse, 0.0),
		cocoon_center + Vector2(0.0, 27.0 * pulse),
		cocoon_center + Vector2(-18.0 * pulse, 0.0),
	]), Color(0.86, 0.89, 1.0, 0.24))
	for strand_index in range(6):
		var x_offset := lerpf(-15.0, 15.0, float(strand_index) / 5.0)
		canvas.draw_polyline(PackedVector2Array([
			cocoon_center + Vector2(x_offset * 0.25, -20.0),
			cocoon_center + Vector2(-x_offset, 2.0),
			cocoon_center + Vector2(x_offset * 0.45, 24.0),
		]), Color(0.95, 0.96, 1.0, 0.76), 1.8)
	canvas.draw_arc(cocoon_center, 19.0 * pulse, 0.0, TAU, 28, Color(0.98, 0.98, 1.0, 0.82), 2.4)


func _draw_arachne_web_rescue_pull(canvas: CanvasItem, boss_anchor: Vector2, ball_anchor: Vector2, progress: float) -> void:
	var pull_axis := boss_anchor - ball_anchor
	var pull_dir := pull_axis.normalized() if pull_axis.length_squared() > 0.001 else Vector2.DOWN
	canvas.draw_line(ball_anchor, boss_anchor, Color(0.48, 0.61, 0.96, 0.18), 15.0)
	canvas.draw_line(ball_anchor, boss_anchor, Color(0.94, 0.96, 1.0, 0.90), 4.0)
	for ghost_index in range(3, 0, -1):
		var ghost_center := boss_anchor + pull_dir * (float(ghost_index) * 18.0 + progress * 8.0)
		var alpha := 0.07 + float(4 - ghost_index) * 0.035
		canvas.draw_circle(ghost_center + Vector2(0.0, 8.0), 31.0, Color(0.42, 0.30, 0.35, alpha))
		canvas.draw_circle(ghost_center + Vector2(0.0, -15.0), 22.0, Color(0.68, 0.72, 0.94, alpha * 0.75))
	for streak_index in range(5):
		var side := float(streak_index - 2) * 9.0
		var normal := pull_dir.orthogonal()
		var start := boss_anchor + normal * side + pull_dir * 24.0
		canvas.draw_line(start, start + pull_dir * (28.0 + progress * 18.0), Color(0.82, 0.87, 1.0, 0.52), 2.0)
	var tether_head := boss_anchor.lerp(ball_anchor, 0.22 + progress * 0.18)
	canvas.draw_circle(tether_head, 10.0, Color(0.88, 0.92, 1.0, 0.32))
	canvas.draw_circle(tether_head, 4.0, Color(0.98, 0.99, 1.0, 0.92))


func _draw_arachne_web_rescue_hold(canvas: CanvasItem, boss_anchor: Vector2, ball_anchor: Vector2, progress: float) -> void:
	var pulse := 1.0 + sin(progress * TAU * 3.0) * 0.07
	canvas.draw_line(boss_anchor, ball_anchor, Color(0.58, 0.68, 1.0, 0.18), 12.0)
	canvas.draw_line(boss_anchor, ball_anchor, Color(0.95, 0.96, 1.0, 0.78), 3.2)
	canvas.draw_circle(ball_anchor, 29.0 * pulse, Color(0.48, 0.58, 0.96, 0.14))
	canvas.draw_circle(ball_anchor, 16.0, Color(0.88, 0.91, 1.0, 0.20))
	for spoke_index in range(6):
		var angle := TAU * float(spoke_index) / 6.0 + progress * 0.35
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var tip := ball_anchor + direction * 38.0 * pulse
		canvas.draw_colored_polygon(PackedVector2Array([
			ball_anchor + tangent * 3.0,
			tip,
			ball_anchor - tangent * 3.0,
		]), Color(0.82, 0.86, 1.0, 0.18))
		canvas.draw_line(ball_anchor, tip, Color(0.96, 0.97, 1.0, 0.78), 2.0)
	for ring_index in range(2):
		canvas.draw_arc(ball_anchor, (21.0 + float(ring_index) * 11.0) * pulse, 0.0, TAU, 36, Color(0.94, 0.95, 1.0, 0.58), 2.0)


func _draw_arachne_web_rescue_strike(canvas: CanvasItem, boss_anchor: Vector2, ball_anchor: Vector2, progress: float) -> void:
	# The rescue triggers inside the top 25 px. Keep the widest shockwave and
	# its shards biased inward instead of centering them on the scoring edge.
	var impact_center := Vector2(ball_anchor.x, maxf(ball_anchor.y + 8.0, 66.0))
	var expansion := clampf(progress * 1.35, 0.0, 1.0)
	canvas.draw_line(boss_anchor, impact_center, Color(0.90, 0.93, 1.0, 0.30 * (1.0 - progress)), 10.0)
	canvas.draw_circle(impact_center, lerpf(12.0, 42.0, expansion), Color(0.52, 0.64, 1.0, 0.22 * (1.0 - progress)))
	canvas.draw_circle(impact_center, lerpf(8.0, 24.0, expansion), Color(0.96, 0.97, 1.0, 0.34 * (1.0 - progress)))
	canvas.draw_arc(impact_center, lerpf(15.0, 55.0, expansion), 0.0, TAU, 48, Color(0.89, 0.93, 1.0, 0.90 * (1.0 - progress)), 4.0)
	canvas.draw_arc(impact_center, lerpf(8.0, 35.0, expansion), 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.82 * (1.0 - progress)), 2.5)
	for shard_index in range(8):
		var direction := Vector2.from_angle(TAU * float(shard_index) / 8.0 + 0.18)
		var tangent := direction.orthogonal()
		var shard_center := impact_center + direction * lerpf(18.0, 62.0, expansion)
		var shard_length := 11.0 + float(shard_index % 3) * 3.0
		canvas.draw_colored_polygon(PackedVector2Array([
			shard_center + direction * shard_length,
			shard_center + tangent * 3.5,
			shard_center - direction * shard_length * 0.45,
			shard_center - tangent * 3.5,
		]), Color(0.92, 0.95, 1.0, 0.86 * (1.0 - progress)))


func _draw_web_projectile(canvas: CanvasItem, projectile: Dictionary, shake_offset: Vector2) -> void:
	var start := _as_vector2(projectile.get("start", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var target := _as_vector2(projectile.get("target", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var ratio := clampf(float(projectile.get("age", 0.0)) / maxf(0.001, float(projectile.get("duration", 0.58))), 0.0, 1.0)
	var eased := 1.0 - (1.0 - ratio) * (1.0 - ratio)
	var head := start.lerp(target, eased)
	var color := Color("ffd750") if bool(projectile.get("golden", false)) else Color("ef5350") if bool(projectile.get("rage", false)) else Color("eee9e5")
	canvas.draw_line(start, head, color, 3.0)
	canvas.draw_circle(head, 7.0, color)


func _draw_web_trap(canvas: CanvasItem, trap: Dictionary, shake_offset: Vector2) -> void:
	var center := _as_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var radius := float(trap.get("radius", 50.0))
	var expand := clampf(1.0 - float(trap.get("expand", 0.0)) / 0.2, 0.0, 1.0)
	radius *= expand
	var color := Color("ffd750") if bool(trap.get("golden", false)) else Color("de3d3a") if bool(trap.get("rage", false)) else Color("d7d1cc")
	for ring in range(1, 5):
		canvas.draw_arc(center, radius * float(ring) / 4.0, 0.0, TAU, 32, Color(color, 0.72), 1.8)
	for index in range(8):
		canvas.draw_line(center, center + Vector2.from_angle(TAU * float(index) / 8.0) * radius, Color(color, 0.72), 1.8)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
