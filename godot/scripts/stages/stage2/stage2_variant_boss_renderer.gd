extends RefCounted


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	match str(context.get("stage_boss_variant", "")):
		"molewang":
			_draw_tunnel_spikes(canvas, context, shake_offset)
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
		var age := float(mole.get("age", 0.0))
		var emerge := clampf(age / (12.0 / 60.0), 0.0, 1.0)
		if age > (72.0 / 60.0):
			emerge = clampf(1.0 - (age - 72.0 / 60.0) / (12.0 / 60.0), 0.0, 1.0)
		var center := _as_vector2(mole.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(center + Vector2(0.0, 8.0), 20.0, Color(0.20, 0.13, 0.08, 0.75))
		canvas.draw_circle(center + Vector2(0.0, 10.0 - 18.0 * emerge), 15.0, Color("d5a62e"))
		canvas.draw_circle(center + Vector2(-5.0, 6.0 - 18.0 * emerge), 2.0, Color("17110b"))
		canvas.draw_circle(center + Vector2(5.0, 6.0 - 18.0 * emerge), 2.0, Color("17110b"))


func _draw_arachne(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(315.0, 25.0))), Vector2(315.0, 25.0)) + shake_offset
	var boss_size := _as_vector2(context.get("boss_paddle_size", Vector2(130.0, 52.0)), Vector2(130.0, 52.0))
	var center := boss_pos + Vector2(boss_size.x * 0.5, boss_size.y + 16.0 + float(context.get("arachne_rage_stomp_offset_y", 0.0)))
	var hit_flash := clampf(float(context.get("arachne_hit_progress", 0.0)), 0.0, 1.0) * 0.22
	var rage_tint := clampf(float(context.get("arachne_rage_red_tint", 0.0)), 0.0, 1.0)
	var body_color := Color("281c16").lerp(Color.WHITE, hit_flash).lerp(Color("8f1816"), rage_tint * 0.55)
	var leg_color := Color("3a2018").lerp(Color("8b211d"), rage_tint * 0.45)
	for pair_index in range(4):
		var y_offset := -18.0 + float(pair_index) * 12.0
		var reach := 48.0 + float(3 - pair_index) * 5.0
		for side in [-1.0, 1.0]:
			var hip := center + Vector2(side * 15.0, y_offset)
			var knee := center + Vector2(side * (32.0 + float(pair_index) * 3.0), y_offset - 14.0 + float(pair_index) * 5.0)
			var foot := center + Vector2(side * reach, 18.0 + float(pair_index) * 7.0)
			canvas.draw_polyline(PackedVector2Array([hip, knee, foot]), leg_color, 6.0)
			canvas.draw_circle(knee, 4.2, Color("4d2d22"))
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
	if bool(context.get("arachne_web_rescue_active", false)):
		var boss_pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(315.0, 25.0))), Vector2(315.0, 25.0)) + Vector2(65.0, 57.0) + shake_offset
		var ball_pos := _as_vector2(context.get("arachne_web_rescue_ball_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		for index in range(3):
			var offset := Vector2(float(index - 1) * 5.0, 0.0)
			canvas.draw_line(boss_pos + offset, ball_pos + offset, Color(0.90, 0.90, 0.96, 0.85), 2.0)
		canvas.draw_arc(ball_pos, 17.0, 0.0, TAU, 24, Color(0.95, 0.95, 1.0, 0.75), 2.0)


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
