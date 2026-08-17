extends RefCounted


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or str(context.get("stage_boss_variant", "")) != "molewang":
		return
	_draw_tunnel_spikes(canvas, context, shake_offset)
	_draw_friend_moles(canvas, context, shake_offset)
	_draw_molewang(canvas, context, shake_offset)


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


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
