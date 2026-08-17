extends RefCounted

const WIDTH := 760.0
const HEIGHT := 750.0
const HUG_ZONE_WIDTH := 350.0
const HUG_ZONE_TOP := 600.0


func prewarm_assets_step() -> bool:
	return true


func reset() -> void:
	pass


func clear_transient_canvas_items() -> void:
	pass


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2 = Vector2.ZERO) -> void:
	var variant := str(context.get("stage_boss_variant", ""))
	if variant == "alice":
		_draw_alice_mirror(canvas, context)
		_draw_alice_size_shift(canvas, context, shake_offset)
		_draw_alice_rabbits(canvas, context, shake_offset)
		_draw_alice(canvas, context, shake_offset)
		return
	if variant != "teddy_bear":
		return
	_draw_deadly_hug(canvas, context, shake_offset)
	_draw_ghost_curve(canvas, context, shake_offset)
	_draw_cotton_bombs(canvas, context, shake_offset)
	_draw_cotton_throw(canvas, context, shake_offset)
	_draw_heart_beam(canvas, context, shake_offset)
	_draw_teddy(canvas, context, shake_offset)
	_draw_player_slow(canvas, context, shake_offset)
	_draw_whiteout(canvas, context)


func _draw_alice(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(330.0, 25.0))), Vector2(330.0, 25.0))
	var paddle_size := _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	# Alice's authored full-body silhouette is taller than the 40px collision
	# paddle, so anchor her below it instead of clipping the head at playfield Y0.
	var center := boss_pos + Vector2(paddle_size.x * 0.5, paddle_size.y * 0.55 + 40.0) + shake_offset
	var hit_ratio := clampf(float(context.get("stage3_alice_hit_ratio", 0.0)), 0.0, 1.0)
	center += Vector2(sin(hit_ratio * 29.0) * hit_ratio * 2.0, -sin(hit_ratio * PI) * 3.0)
	var blue := Color("6298e8")
	var blue_dark := Color("315baf")
	var blue_light := Color("98c2ff")
	var apron := Color("f7f3ff")
	var apron_shadow := Color("dcd8eb")
	var gold := Color("f3cd69")
	var gold_dark := Color("b88428")
	var skin := Color("ffdfc6")
	var pink := Color("ff91ba")
	# Shadow, striped stockings and shoes.
	_draw_alice_ellipse(canvas, center + Vector2(0.0, 43.0), Vector2(45.0, 8.0), Color(0.02, 0.02, 0.05, 0.38))
	for side in [-1.0, 1.0]:
		canvas.draw_rect(Rect2(center + Vector2(side * 14.0 - 5.0, 25.0), Vector2(10.0, 19.0)), apron, true)
		canvas.draw_line(center + Vector2(side * 19.0, 31.0), center + Vector2(side * 9.0, 31.0), blue_dark, 2.0, true)
		canvas.draw_line(center + Vector2(side * 19.0, 38.0), center + Vector2(side * 9.0, 38.0), blue_dark, 2.0, true)
		_draw_alice_ellipse(canvas, center + Vector2(side * 16.0, 44.0), Vector2(11.0, 5.0), Color("28243a"))
	# Five-panel royal-blue skirt and white apron.
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-20.0, -2.0), center + Vector2(20.0, -2.0),
		center + Vector2(40.0, 31.0), center + Vector2(-40.0, 31.0),
	]), blue)
	for panel in range(5):
		var x := -32.0 + panel * 16.0
		canvas.draw_line(center + Vector2(x, 25.0), center + Vector2(x * 0.55, 1.0), Color(blue_light, 0.55), 2.0, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13.0, 0.0), center + Vector2(13.0, 0.0),
		center + Vector2(23.0, 27.0), center + Vector2(-23.0, 27.0),
	]), apron)
	for x in range(-20, 21, 8):
		canvas.draw_circle(center + Vector2(float(x), 28.0), 3.0, apron_shadow)
	# Torso and puff sleeves.
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-18.0, -24.0), center + Vector2(18.0, -24.0),
		center + Vector2(20.0, 4.0), center + Vector2(-20.0, 4.0),
	]), blue_dark)
	_draw_alice_ellipse(canvas, center + Vector2(-24.0, -16.0), Vector2(10.0, 9.0), blue_light)
	_draw_alice_ellipse(canvas, center + Vector2(24.0, -16.0), Vector2(10.0, 9.0), blue_light)
	canvas.draw_line(center + Vector2(-28.0, -12.0), center + Vector2(-33.0, 10.0), skin, 7.0, true)
	canvas.draw_line(center + Vector2(28.0, -12.0), center + Vector2(33.0, 10.0), skin, 7.0, true)
	# Long blonde hair behind the face.
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-28.0, -62.0), center + Vector2(28.0, -62.0),
		center + Vector2(31.0, 2.0), center + Vector2(18.0, -5.0),
		center + Vector2(8.0, 4.0), center + Vector2(0.0, -6.0),
		center + Vector2(-10.0, 4.0), center + Vector2(-19.0, -5.0),
		center + Vector2(-31.0, 2.0),
	]), gold_dark)
	# Face, bangs, blue bow and expressive eyes.
	_draw_alice_ellipse(canvas, center + Vector2(0.0, -46.0), Vector2(24.0, 23.0), skin)
	_draw_alice_ellipse(canvas, center + Vector2(0.0, -62.0), Vector2(27.0, 15.0), gold)
	for offset in [-15.0, -7.0, 2.0, 11.0]:
		canvas.draw_colored_polygon(PackedVector2Array([
			center + Vector2(offset - 7.0, -60.0), center + Vector2(offset + 7.0, -60.0), center + Vector2(offset, -40.0),
		]), gold)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -68.0), center + Vector2(-19.0, -79.0), center + Vector2(-16.0, -61.0),
	]), blue_dark)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -68.0), center + Vector2(19.0, -79.0), center + Vector2(16.0, -61.0),
	]), blue_dark)
	canvas.draw_circle(center + Vector2(0.0, -68.0), 5.0, blue_light)
	for eye_x in [-9.0, 9.0]:
		_draw_alice_ellipse(canvas, center + Vector2(eye_x, -47.0), Vector2(5.0, 7.0), Color("ffffff"))
		canvas.draw_circle(center + Vector2(eye_x, -46.0), 3.0, blue_dark)
		canvas.draw_circle(center + Vector2(eye_x - 1.0, -48.0), 1.0, Color("ffffff"))
	canvas.draw_arc(center + Vector2(0.0, -35.0), 6.0, 0.15, PI - 0.15, 10, pink, 2.0, true)
	# Hand mirror: the source sprite's defining prop.
	var mirror_center := center + Vector2(42.0, -27.0)
	canvas.draw_line(center + Vector2(33.0, 7.0), mirror_center + Vector2(-2.0, 13.0), Color("b8913b"), 5.0, true)
	_draw_alice_ellipse(canvas, mirror_center, Vector2(14.0, 19.0), Color("c59b46"))
	_draw_alice_ellipse(canvas, mirror_center, Vector2(10.0, 15.0), Color("cfe2ff"))
	canvas.draw_line(mirror_center + Vector2(-6.0, -8.0), mirror_center + Vector2(5.0, 5.0), Color(1.0, 1.0, 1.0, 0.8), 2.0, true)


func _draw_alice_mirror(canvas: CanvasItem, context: Dictionary) -> void:
	var ratio := clampf(float(context.get("stage3_alice_mirror_ratio", 0.0)), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var phase := float(context.get("stage3_alice_mirror_phase", 0.0))
	var border := Color(0.68, 0.82, 1.0, 0.30 + ratio * 0.55)
	canvas.draw_rect(Rect2(Vector2(3.0, 3.0), Vector2(WIDTH - 6.0, HEIGHT - 6.0)), Color(0.22, 0.35, 0.70, 0.08 * ratio), true)
	canvas.draw_rect(Rect2(Vector2(5.0, 5.0), Vector2(WIDTH - 10.0, HEIGHT - 10.0)), border, false, 5.0, true)
	for index in range(9):
		var x := fmod(phase * (0.7 + index * 0.05) + index * 97.0, WIDTH)
		var y := 80.0 + fmod(index * 113.0, HEIGHT - 160.0)
		canvas.draw_line(Vector2(x - 18.0, y - 12.0), Vector2(x, y), Color(0.85, 0.93, 1.0, 0.38 * ratio), 2.0, true)
		canvas.draw_line(Vector2(x, y), Vector2(x + 12.0, y + 20.0), Color(0.85, 0.93, 1.0, 0.30 * ratio), 2.0, true)


func _draw_alice_size_shift(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var ratio := clampf(float(context.get("stage3_alice_size_shift_ratio", 0.0)), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var ball_pos := _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var scale_value := float(context.get("stage3_alice_size_shift_scale", 1.0))
	var pulse := 5.0 + sin(ratio * 30.0) * 3.0
	var color := Color("ff91cf") if scale_value > 1.0 else Color("78e7ff")
	canvas.draw_circle(ball_pos, maxf(8.0, float(context.get("ball_size", 28.6)) * 0.5) + pulse, Color(color, 0.35), false, 3.0, true)
	for index in range(6):
		var angle := TAU * float(index) / 6.0 + ratio * 8.0
		canvas.draw_circle(ball_pos + Vector2.from_angle(angle) * (25.0 + pulse), 3.0, Color(color, 0.75))


func _draw_alice_rabbits(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var windup := clampf(float(context.get("stage3_alice_rabbit_windup_ratio", 0.0)), 0.0, 1.0)
	if windup > 0.0:
		var center := _boss_bottom_center(context) + shake_offset
		for index in range(3):
			var angle := (1.0 - windup) * PI * 3.0 + index * TAU / 3.0
			_draw_rabbit(canvas, center + Vector2.from_angle(angle) * 20.0 * windup, 9.0 + 4.0 * (1.0 - windup), 0.0, Color(1.0, 0.82, 0.91, 0.82))
	for value in _as_array(context.get("stage3_alice_rabbit_projectiles", [])):
		if value is Dictionary:
			var rabbit: Dictionary = value
			var pos := _as_vector2(rabbit.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
			pos.y -= absf(sin(float(rabbit.get("hop_phase", 0.0)))) * 8.0
			_draw_rabbit(canvas, pos, float(rabbit.get("size", 18.0)), float(rabbit.get("ear_angle", 0.0)), Color("fff2f7"))
	var player_pos := _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size := _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center := player_pos + player_size * 0.5
	for value in _as_array(context.get("stage3_alice_perched_rabbits", [])):
		if value is Dictionary:
			var rabbit: Dictionary = value
			var size := float(rabbit.get("size", 18.0))
			var pos := Vector2(player_center.x + float(rabbit.get("offset_x", 0.0)), player_pos.y - size - absf(sin(float(rabbit.get("hop_phase", 0.0)))) * 6.0) + shake_offset
			_draw_rabbit(canvas, pos, size, sin(float(rabbit.get("taunt_phase", 0.0))) * 0.18, Color("fff2f7"))
	for value in _as_array(context.get("stage3_alice_rabbit_burst_particles", [])):
		if value is Dictionary:
			var particle: Dictionary = value
			var alpha := clampf(float(particle.get("life", 0.0)) / maxf(0.001, float(particle.get("max_life", 0.5))), 0.0, 1.0)
			canvas.draw_circle(_as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset, 3.5, Color(1.0, 0.78, 0.86, alpha))


func _draw_rabbit(canvas: CanvasItem, center: Vector2, size: float, ear_angle: float, color: Color) -> void:
	var body_size := maxf(6.0, size)
	_draw_alice_ellipse(canvas, center + Vector2(0.0, body_size * 0.18), Vector2(body_size * 0.68, body_size * 0.55), color)
	_draw_alice_ellipse(canvas, center + Vector2(0.0, -body_size * 0.42), Vector2(body_size * 0.50, body_size * 0.48), color)
	var ear_dx := sin(ear_angle) * body_size * 0.25
	_draw_alice_ellipse(canvas, center + Vector2(-body_size * 0.23 + ear_dx, -body_size), Vector2(body_size * 0.20, body_size * 0.55), color)
	_draw_alice_ellipse(canvas, center + Vector2(body_size * 0.23 - ear_dx, -body_size), Vector2(body_size * 0.20, body_size * 0.55), color)
	canvas.draw_circle(center + Vector2(-body_size * 0.18, -body_size * 0.47), maxf(1.5, body_size * 0.08), Color("4b315a"))
	canvas.draw_circle(center + Vector2(body_size * 0.18, -body_size * 0.47), maxf(1.5, body_size * 0.08), Color("4b315a"))
	canvas.draw_circle(center + Vector2(0.0, -body_size * 0.28), maxf(1.4, body_size * 0.07), Color("ff91b8"))


func _draw_alice_ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, color)


func _draw_teddy(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var boss_pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(330.0, 25.0))), Vector2(330.0, 25.0))
	var paddle_size := _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var center := boss_pos + Vector2(paddle_size.x * 0.5, paddle_size.y * 0.55) + shake_offset
	var hit_ratio := clampf(float(context.get("stage3_teddy_hit_ratio", 0.0)), 0.0, 1.0)
	var jitter := Vector2(sin(hit_ratio * 31.0) * hit_ratio * 2.0, cos(hit_ratio * 23.0) * hit_ratio)
	center += jitter
	var fur_dark := Color("674022")
	var fur_shadow := Color("825837")
	var fur := Color("a8784e")
	var fur_light := Color("d2af87")
	var belly := Color("e7ceb0")
	var pink := Color("f45b91")
	var pink_dark := Color("9f294f")
	var stitch := Color("50301d")
	_draw_ellipse(canvas, center + Vector2(0.0, 36.0), Vector2(42.0, 9.0), Color(0.02, 0.02, 0.02, 0.38))
	# Legs and paws.
	_draw_ellipse(canvas, center + Vector2(-20.0, 29.0), Vector2(15.0, 24.0), fur_shadow)
	_draw_ellipse(canvas, center + Vector2(20.0, 29.0), Vector2(15.0, 24.0), fur_shadow)
	_draw_ellipse(canvas, center + Vector2(-21.0, 42.0), Vector2(16.0, 8.0), fur_light)
	_draw_ellipse(canvas, center + Vector2(21.0, 42.0), Vector2(16.0, 8.0), fur_light)
	# Arms, including the hit-swing silhouette.
	var swing := sin(hit_ratio * PI) * 18.0
	_draw_ellipse(canvas, center + Vector2(-39.0 - swing, 7.0 - swing * 0.3), Vector2(13.0, 27.0), fur_shadow)
	_draw_ellipse(canvas, center + Vector2(39.0 + swing, 7.0 - swing * 0.3), Vector2(13.0, 27.0), fur_shadow)
	# Right-arm bandage.
	for index in range(3):
		canvas.draw_line(
			center + Vector2(30.0 + index * 4.0, -4.0 + index * 5.0),
			center + Vector2(47.0 + index * 2.0, 2.0 + index * 5.0),
			Color("eee5d8"),
			3.0,
			true
		)
	# Body, belly patch and stitches.
	_draw_ellipse(canvas, center + Vector2(0.0, 12.0), Vector2(37.0, 36.0), fur)
	_draw_ellipse(canvas, center + Vector2(-8.0, 2.0), Vector2(20.0, 24.0), Color(fur_light, 0.35))
	_draw_ellipse(canvas, center + Vector2(0.0, 18.0), Vector2(22.0, 23.0), belly)
	_draw_stitches(canvas, center + Vector2(0.0, 18.0), Vector2(22.0, 23.0), stitch)
	# Burst shoulder seam with exposed cotton.
	canvas.draw_polyline(PackedVector2Array([
		center + Vector2(-31.0, -5.0),
		center + Vector2(-25.0, 0.0),
		center + Vector2(-31.0, 5.0),
		center + Vector2(-24.0, 10.0),
	]), stitch, 3.0, true)
	for cotton_offset in [Vector2(-35.0, -2.0), Vector2(-37.0, 4.0), Vector2(-32.0, 8.0)]:
		canvas.draw_circle(center + cotton_offset, 5.0, Color("fff7ed"))
	# Ears and head.
	_draw_ellipse(canvas, center + Vector2(-25.0, -34.0), Vector2(14.0, 14.0), fur_dark)
	_draw_ellipse(canvas, center + Vector2(25.0, -34.0), Vector2(14.0, 14.0), fur_dark)
	_draw_ellipse(canvas, center + Vector2(-25.0, -34.0), Vector2(8.0, 8.0), fur_light)
	_draw_ellipse(canvas, center + Vector2(25.0, -34.0), Vector2(8.0, 8.0), fur_light)
	_draw_ellipse(canvas, center + Vector2(0.0, -23.0), Vector2(34.0, 29.0), fur)
	_draw_ellipse(canvas, center + Vector2(-8.0, -32.0), Vector2(20.0, 13.0), Color(fur_light, 0.28))
	# Left yandere heart eye.
	_draw_heart(canvas, center + Vector2(-13.0, -26.0), 7.0, pink)
	# Right missing button eye, thread and dangling button.
	canvas.draw_circle(center + Vector2(13.0, -26.0), 6.0, Color("2a1b14"))
	canvas.draw_line(center + Vector2(9.0, -30.0), center + Vector2(17.0, -22.0), pink_dark, 2.0, true)
	canvas.draw_line(center + Vector2(17.0, -30.0), center + Vector2(9.0, -22.0), pink_dark, 2.0, true)
	canvas.draw_line(center + Vector2(14.0, -20.0), center + Vector2(20.0, -9.0), stitch, 1.5, true)
	canvas.draw_circle(center + Vector2(21.0, -7.0), 5.0, Color("1c1715"))
	canvas.draw_circle(center + Vector2(19.5, -8.5), 1.2, Color("d7c0a4"))
	canvas.draw_circle(center + Vector2(22.5, -5.5), 1.2, Color("d7c0a4"))
	# Muzzle, nose and X-stitch mouth.
	_draw_ellipse(canvas, center + Vector2(0.0, -11.0), Vector2(17.0, 12.0), belly)
	_draw_ellipse(canvas, center + Vector2(0.0, -16.0), Vector2(6.0, 4.0), Color("39251c"))
	canvas.draw_line(center + Vector2(-6.0, -9.0), center + Vector2(6.0, -3.0), stitch, 2.0, true)
	canvas.draw_line(center + Vector2(6.0, -9.0), center + Vector2(-6.0, -3.0), stitch, 2.0, true)
	# Safety pin and pink ribbon.
	canvas.draw_arc(center + Vector2(-31.0, -39.0), 9.0, -PI * 0.65, PI * 0.65, 12, Color("d7dde0"), 2.0, true)
	canvas.draw_line(center + Vector2(-37.0, -45.0), center + Vector2(-24.0, -33.0), Color("d7dde0"), 2.0, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(20.0, -48.0), center + Vector2(8.0, -56.0), center + Vector2(10.0, -43.0),
	]), pink)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(20.0, -48.0), center + Vector2(32.0, -56.0), center + Vector2(30.0, -43.0),
	]), pink)
	canvas.draw_circle(center + Vector2(20.0, -48.0), 5.0, pink_dark)


func _draw_cotton_throw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var windup := clampf(float(context.get("stage3_teddy_cotton_throw_windup_ratio", 0.0)), 0.0, 1.0)
	if windup > 0.0:
		var center := _boss_bottom_center(context) + shake_offset
		for index in range(4):
			var angle := (1.0 - windup) * TAU * 2.0 + index * PI * 0.5
			canvas.draw_circle(center + Vector2.from_angle(angle) * 25.0 * windup, 5.0 + 5.0 * (1.0 - windup), Color(1.0, 0.94, 0.91, 0.75))
	for value in _as_array(context.get("stage3_teddy_cotton_projectiles", [])):
		if not (value is Dictionary):
			continue
		var projectile: Dictionary = value
		var pos := _as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := float(projectile.get("size", 22.0))
		var pulse := 1.0 + sin(float(projectile.get("wobble", 0.0)) * 2.0) * 0.10
		canvas.draw_circle(pos, size * pulse + 4.0, Color(1.0, 0.62, 0.74, 0.28))
		canvas.draw_circle(pos, size * pulse, Color("fff5f0"))
		canvas.draw_circle(pos + Vector2(-4.0, -5.0), size * 0.45, Color("ffffff"))


func _draw_cotton_bombs(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var windup := clampf(float(context.get("stage3_teddy_cotton_bomb_windup_ratio", 0.0)), 0.0, 1.0)
	if windup > 0.0:
		var center := _boss_bottom_center(context) + shake_offset
		for index in range(5):
			var angle := (1.0 - windup) * TAU * 3.0 + index * TAU / 5.0
			canvas.draw_circle(center + Vector2.from_angle(angle) * 30.0 * windup, 7.0 + 7.0 * (1.0 - windup), Color(1.0, 0.48, 0.65, 0.7))
	for value in _as_array(context.get("stage3_teddy_cotton_bombs", [])):
		if not (value is Dictionary):
			continue
		var bomb: Dictionary = value
		var pos := _as_vector2(bomb.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := float(bomb.get("size", 24.0)) * (1.0 + sin(float(bomb.get("pulse", 0.0)) * 3.0) * 0.15)
		canvas.draw_circle(pos, size + 8.0, Color(1.0, 0.25, 0.3, 0.26), false, 3.0, true)
		canvas.draw_circle(pos, size, Color("ffc8dc"))
		canvas.draw_circle(pos + Vector2(-4.0, -5.0), size * 0.55, Color("fff0f5"))
	for value in _as_array(context.get("stage3_teddy_cotton_fragments", [])):
		if not (value is Dictionary):
			continue
		var fragment: Dictionary = value
		var pos := _as_vector2(fragment.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := float(fragment.get("size", 10.0))
		canvas.draw_circle(pos, size, Color("ffb5cf"))
		canvas.draw_circle(pos + Vector2(-2.0, -2.0), size * 0.45, Color("ffe8f0"))


func _draw_ghost_curve(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	for value in _as_array(context.get("stage3_teddy_ghost_trail", [])):
		if not (value is Dictionary):
			continue
		var trail: Dictionary = value
		var life := clampf(float(trail.get("life", 0.0)), 0.0, 1.0)
		var pos := _as_vector2(trail.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := float(trail.get("size", 14.0))
		canvas.draw_circle(pos, size * (0.7 + life * 0.3), Color(0.58, 0.95, 0.86, life * 0.45), false, 2.0, true)


func _draw_deadly_hug(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if bool(context.get("stage3_teddy_hug_rush_active", false)):
		_draw_hug_silhouette(canvas, Vector2(WIDTH * 0.5, float(context.get("stage3_teddy_hug_rush_y", 0.0))) + shake_offset, 1.55, Color(0.60, 0.34, 0.25, 0.72))
	var ratio := clampf(float(context.get("stage3_teddy_hug_ratio", 0.0)), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var fade := minf(1.0, (1.0 - ratio) * 10.0) * minf(1.0, ratio * 5.0)
	var zone := Rect2(Vector2((WIDTH - HUG_ZONE_WIDTH) * 0.5, HUG_ZONE_TOP) + shake_offset, Vector2(HUG_ZONE_WIDTH, HEIGHT - HUG_ZONE_TOP))
	canvas.draw_rect(zone, Color(0.21, 0.09, 0.05, 0.36 * fade), true)
	canvas.draw_rect(zone, Color(0.72, 0.34, 0.20, 0.75 * fade), false, 3.0, true)
	for x in range(int(zone.position.x), int(zone.end.x) + 1, 30):
		canvas.draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), Color(0.58, 0.35, 0.25, 0.35 * fade), 1.0)
	for y in range(int(zone.position.y), int(zone.end.y) + 1, 30):
		canvas.draw_line(Vector2(zone.position.x, y), Vector2(zone.end.x, y), Color(0.58, 0.35, 0.25, 0.35 * fade), 1.0)
	_draw_ellipse(canvas, zone.get_center() + Vector2(-72.0, 15.0), Vector2(90.0, 25.0), Color(0.57, 0.32, 0.22, 0.24 * fade))
	_draw_ellipse(canvas, zone.get_center() + Vector2(72.0, 15.0), Vector2(90.0, 25.0), Color(0.57, 0.32, 0.22, 0.24 * fade))


func _draw_hug_silhouette(canvas: CanvasItem, center: Vector2, scale_value: float, color: Color) -> void:
	_draw_ellipse(canvas, center + Vector2(0.0, 18.0) * scale_value, Vector2(42.0, 46.0) * scale_value, color)
	canvas.draw_circle(center + Vector2(0.0, -26.0) * scale_value, 28.0 * scale_value, color)
	canvas.draw_circle(center + Vector2(-24.0, -49.0) * scale_value, 12.0 * scale_value, color)
	canvas.draw_circle(center + Vector2(24.0, -49.0) * scale_value, 12.0 * scale_value, color)
	canvas.draw_circle(center + Vector2(-10.0, -29.0) * scale_value, 4.0 * scale_value, Color(0.05, 0.03, 0.03, color.a))
	canvas.draw_circle(center + Vector2(10.0, -29.0) * scale_value, 4.0 * scale_value, Color(0.05, 0.03, 0.03, color.a))


func _draw_heart_beam(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	for value in _as_array(context.get("stage3_teddy_heart_trail", [])):
		if value is Dictionary:
			var trail: Dictionary = value
			_draw_heart(canvas, _as_vector2(trail.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset, 5.0, Color(1.0, 0.32, 0.56, float(trail.get("life", 0.0)) * 0.55))
	var projectile: Variant = context.get("stage3_teddy_heart_projectile", {})
	if projectile is Dictionary and not projectile.is_empty():
		var pos := _as_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		_draw_heart(canvas, pos, float(projectile.get("size", 12.0)), Color("ff6098"))
	for value in _as_array(context.get("stage3_teddy_heart_particles", [])):
		if value is Dictionary:
			var particle: Dictionary = value
			_draw_heart(
				canvas,
				_as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset,
				float(particle.get("size", 4.0)),
				Color(1.0, 0.35, 0.58, clampf(float(particle.get("life", 0.0)), 0.0, 1.0))
			)


func _draw_player_slow(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var ratio := clampf(float(context.get("stage3_teddy_cotton_slow_ratio", 0.0)), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var pos := _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var size := _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	_draw_ellipse(canvas, pos + Vector2(size.x * 0.5, size.y - 3.0) + shake_offset, Vector2(size.x * 0.5 + 20.0, 10.0), Color(1.0, 0.45, 0.70, ratio * 0.55))


func _draw_whiteout(canvas: CanvasItem, context: Dictionary) -> void:
	var ratio := clampf(float(context.get("stage3_teddy_blackout_ratio", 0.0)), 0.0, 1.0)
	if ratio > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), Color(1.0, 1.0, 1.0, ratio), true)


func _draw_heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var lobe := size * 0.48
	canvas.draw_circle(center + Vector2(-lobe, -lobe * 0.35), lobe, color)
	canvas.draw_circle(center + Vector2(lobe, -lobe * 0.35), lobe, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size, 0.0),
		center + Vector2(size, 0.0),
		center + Vector2(0.0, size * 1.25),
	]), color)


func _draw_stitches(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var tangent := Vector2(-sin(angle), cos(angle)) * 3.0
		var point := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		canvas.draw_line(point - tangent, point + tangent, color, 1.0, true)


func _draw_ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	canvas.draw_set_transform(center, 0.0, Vector2(maxf(0.001, radii.x), maxf(0.001, radii.y)))
	canvas.draw_circle(Vector2.ZERO, 1.0, color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _boss_bottom_center(context: Dictionary) -> Vector2:
	var pos := _as_vector2(context.get("boss_draw_pos", context.get("boss_pos", Vector2(330.0, 25.0))), Vector2(330.0, 25.0))
	var size := _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	return pos + Vector2(size.x * 0.5, size.y)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
