extends RefCounted

const ARROW_LENGTH := 16.0
const ARCHER_PART_COUNT := 9
const ARCHER_BOW_POINT_COUNT := 13
const ARCHER_BODY_ALPHA := 0.5

const BONE_COLOR := Color(0.82, 0.88, 0.78, 1.0)
const BONE_SHADOW := Color(0.12, 0.18, 0.16, 1.0)
const SOUL_COLOR := Color(0.36, 0.95, 0.78, 1.0)
const GOLD_COLOR := Color(1.0, 0.78, 0.24, 1.0)
const ARROW_COLOR := Color(0.60, 1.0, 0.84, 1.0)
const GOLD_ARROW_COLOR := Color(1.0, 0.86, 0.26, 1.0)

# Stateless renderer for the Skeleton Archer scene. Runtime collections and
# gameplay clocks remain owned by the skill and are borrowed without copying.


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2,
	particles: Array[Dictionary],
	dying_archers: Array[Dictionary],
	archers: Array[Dictionary],
	arrows: Array[Dictionary],
	emerge_duration: float,
	death_duration: float,
	arrow_draw_time: float
) -> void:
	if canvas == null:
		return
	_draw_particles(canvas, shake_offset, particles)
	for dying in dying_archers:
		_draw_dying_archer(canvas, dying, shake_offset, death_duration)
	for archer in archers:
		_draw_archer(canvas, archer, shake_offset, emerge_duration, arrow_draw_time)
	for arrow in arrows:
		_draw_arrow(canvas, arrow, shake_offset)


func _draw_archer(
	canvas: CanvasItem,
	archer: Dictionary,
	shake_offset: Vector2,
	emerge_duration: float,
	arrow_draw_time: float
) -> void:
	var spawn_time := float(archer.get("spawn_time", 0.0))
	var emerge_progress := clampf(spawn_time / maxf(0.001, emerge_duration), 0.0, 1.0)
	var alpha := 1.0 if emerge_progress >= 1.0 else clampf(emerge_progress * 1.5, 0.0, 1.0)
	if alpha <= 0.01:
		return
	# Render the summoned archer at 50% opacity. Folding it into the master alpha here (before
	# the palette is built and before any layer draws) makes the WHOLE figure translucent --
	# the palette colors carry it, and the layers that take `alpha` directly (hem underglow,
	# emerge fx, soul motes) inherit it too.
	alpha *= ARCHER_BODY_ALPHA
	var is_golden := bool(archer.get("is_golden", false))
	var pos := _get_dict_vector2(archer, "pos", Vector2.ZERO) + shake_offset
	pos.y += 14.0 + (1.0 - emerge_progress) * 20.0 + float(archer.get("body_bob", 0.0))
	var palette := _get_archer_palette(is_golden, alpha)
	# Clean "Lumion Spirit-Revenant": ONE convex cloak-bell silhouette + a skull-lantern hero +
	# 링파츠 hardware (twin shoulder pods, forehead + chest-core gems). The figure HOVERS -- no
	# anatomy (ribcage / spine / vertebrae / legs / feet / teeth), so nothing is small enough to
	# alias into the old grey stroke-smear. ~32-42 primitives instead of ~150-250.
	_draw_archer_hem_underglow(canvas, pos, palette, alpha)
	_draw_archer_emerge_fx(canvas, pos, spawn_time, emerge_progress, is_golden, alpha)
	_draw_archer_cloak_bell(canvas, pos, emerge_progress, spawn_time, archer, palette, alpha)
	_draw_archer_shoulder_pods(canvas, pos, emerge_progress, palette, alpha)
	var skull_center := _get_archer_part_pos(pos, emerge_progress, 0, Vector2(0.0, -34.0))
	_draw_archer_skull_lantern(canvas, skull_center, spawn_time, emerge_progress, palette, alpha)
	_draw_archer_chest_core(canvas, archer, pos, spawn_time, emerge_progress, palette, alpha, arrow_draw_time)
	_draw_archer_bow_and_arms(canvas, archer, pos, emerge_progress, spawn_time, palette, arrow_draw_time)
	_draw_archer_soul_motes(canvas, pos, spawn_time, is_golden, alpha)


func _get_archer_palette(is_golden: bool, alpha: float) -> Dictionary:
	# Eyes + forehead/chest gems stay CYAN even on the golden variant so the focal points read
	# against an otherwise all-gold body.
	var eye_glow := _with_alpha(Color(0.624, 0.910, 0.816, 1.0), alpha)
	var eye_core := _with_alpha(Color(0.239, 0.941, 0.776, 1.0), alpha)
	if is_golden:
		var g_bone := _with_alpha(Color(1.0, 0.94, 0.76, 1.0), alpha)
		return {
			"cloak_core": _with_alpha(Color(0.353, 0.251, 0.071, 1.0), alpha),
			"cloak_mid": _with_alpha(Color(0.46, 0.34, 0.12, 1.0), alpha),
			"cloak_rim": _with_alpha(Color(1.0, 0.808, 0.369, 1.0), alpha),
			"plate_dark": _with_alpha(Color(0.16, 0.115, 0.035, 1.0), alpha),
			"bone": g_bone,
			"bone_cream": g_bone,
			"soul_glow": Color(1.0, 0.824, 0.227, 1.0),
			"soul_core": Color(1.0, 0.902, 0.420, 1.0),
			"eye_glow": eye_glow,
			"eye_core": eye_core,
			"bow_dark": _with_alpha(Color(0.42, 0.30, 0.08, 1.0), alpha),
			"bow_lit": _with_alpha(Color(1.0, 0.86, 0.42, 1.0), alpha),
			"string": _with_alpha(Color(1.0, 0.88, 0.40, 1.0), alpha),
			"arrow": _with_alpha(Color(1.0, 0.90, 0.50, 1.0), alpha),
		}
	var bone_cream := _with_alpha(Color(0.906, 0.945, 0.886, 1.0), alpha)
	return {
		"cloak_core": _with_alpha(Color(0.055, 0.090, 0.106, 1.0), alpha),
		"cloak_mid": _with_alpha(Color(0.102, 0.165, 0.180, 1.0), alpha),
		"cloak_rim": _with_alpha(Color(0.247, 0.404, 0.420, 1.0), alpha),
		"plate_dark": _with_alpha(Color(0.106, 0.141, 0.125, 1.0), alpha),
		"bone": bone_cream,
		"bone_cream": bone_cream,
		"soul_glow": Color(0.624, 0.910, 0.816, 1.0),
		"soul_core": Color(0.239, 0.941, 0.776, 1.0),
		"eye_glow": eye_glow,
		"eye_core": eye_core,
		"bow_dark": _with_alpha(Color(0.122, 0.227, 0.227, 1.0), alpha),
		"bow_lit": _with_alpha(Color(0.498, 0.847, 0.753, 1.0), alpha),
		"string": _with_alpha(Color(0.624, 0.910, 0.816, 1.0), alpha),
		"arrow": _with_alpha(Color(0.624, 0.910, 0.816, 1.0), alpha),
	}


func _draw_archer_hem_underglow(canvas: CanvasItem, pos: Vector2, palette: Dictionary, alpha: float) -> void:
	# A soft soul pool where the feet used to be -- stands in for the absent legs and sells the
	# "hovering summoned spirit" read. Sits under the collision center (old ground-shadow spot).
	var soul := _palette_color(palette, "soul_glow", SOUL_COLOR)
	canvas.draw_circle(pos + Vector2(0.0, 13.0), 11.0, _with_alpha(soul, 0.09 * alpha))
	canvas.draw_circle(pos + Vector2(0.0, 13.0), 6.0, _with_alpha(soul, 0.11 * alpha))


func _draw_archer_emerge_fx(canvas: CanvasItem, pos: Vector2, phase: float, emerge_progress: float, is_golden: bool, alpha: float) -> void:
	if emerge_progress >= 1.0:
		return
	var soul_base := GOLD_ARROW_COLOR if is_golden else SOUL_COLOR
	var remain := 1.0 - emerge_progress
	var spark_count := int(8.0 * remain)
	for spark_index in range(spark_count):
		var angle := float(spark_index) / maxf(1.0, float(spark_count)) * TAU + phase * 8.0
		var dist := 35.0 * remain
		var spark_pos := pos + Vector2(cos(angle), sin(angle)) * dist + Vector2(0.0, -20.0)
		var spark_color := _with_alpha(soul_base, 0.78 * remain * alpha)
		canvas.draw_circle(spark_pos, 1.2 + float(spark_index % 3) * 0.6, spark_color)
		if spark_index % 3 == 0:
			canvas.draw_circle(spark_pos, 3.0, _with_alpha(soul_base, 0.20 * remain * alpha))
	if emerge_progress > 0.3:
		for line_index in range(6):
			var line_angle := float(line_index) * TAU / 6.0 + phase * 3.0
			var line_start := pos + Vector2(cos(line_angle), sin(line_angle)) * (30.0 * remain) + Vector2(0.0, -20.0)
			canvas.draw_line(line_start, pos + Vector2(0.0, -20.0), _with_alpha(soul_base, 0.55 * remain * alpha), 1.0, true)
	if emerge_progress > 0.1 and emerge_progress < 0.8:
		var ring_alpha := 0.40 * (1.0 - absf(emerge_progress - 0.4) / 0.4) * alpha
		canvas.draw_arc(pos + Vector2(0.0, 32.0), 20.0 * minf(1.0, emerge_progress * 3.0), 0.0, TAU, 40, _with_alpha(soul_base, ring_alpha), 1.2, true)


func _draw_archer_cloak_bell(canvas: CanvasItem, pos: Vector2, emerge_progress: float, phase: float, archer: Dictionary, palette: Dictionary, alpha: float) -> void:
	# ONE convex filled bell = the whole silhouette. During emerge it rises out of the hem pool
	# (scale-y 0.2->1). Replaces the old 11 sway-strokes + 7 torn-hem strokes + 4 fold strokes.
	var grow := lerpf(0.2, 1.0, emerge_progress)
	var sway := sin(phase * 2.5) * 2.0
	var bow_side := 1.0 if float(archer.get("velocity_x", 0.0)) >= 0.0 else -1.0
	var cloak_core := _palette_color(palette, "cloak_core", BONE_SHADOW)
	var cloak_mid := _palette_color(palette, "cloak_mid", BONE_SHADOW)
	var cloak_rim := _palette_color(palette, "cloak_rim", BONE_COLOR)
	# Bell verts (clockwise from hood peak). Upper verts stay put; only the hem scales/sways so
	# the figure grows up from the floor without shearing.
	var bell := PackedVector2Array([
		pos + Vector2(0.0, -33.0 * grow),
		pos + Vector2(13.0, -30.0 * grow),
		pos + Vector2(9.0, -12.0 * grow),
		pos + Vector2(11.0 + sway, 10.0 * grow),
		pos + Vector2(5.5, 8.0 * grow),
		pos + Vector2(0.0, 10.0 * grow),
		pos + Vector2(-5.5, 8.0 * grow),
		pos + Vector2(-11.0 - sway, 10.0 * grow),
		pos + Vector2(-9.0, -12.0 * grow),
		pos + Vector2(-13.0, -30.0 * grow),
	])
	canvas.draw_polygon(bell, PackedColorArray([cloak_core, cloak_core, cloak_core, cloak_core, cloak_core, cloak_core, cloak_core, cloak_core, cloak_core, cloak_core]))
	var band := PackedVector2Array([
		pos + Vector2(0.0, -30.0 * grow),
		pos + Vector2(10.0, -27.0 * grow),
		pos + Vector2(7.0, -4.0 * grow),
		pos + Vector2(-7.0, -4.0 * grow),
		pos + Vector2(-10.0, -27.0 * grow),
	])
	canvas.draw_polygon(band, PackedColorArray([cloak_mid, cloak_mid, cloak_mid, cloak_mid, cloak_mid]))
	var rim := PackedVector2Array([
		pos + Vector2(0.0, -32.0 * grow),
		pos + Vector2(bow_side * 13.0, -28.0 * grow),
		pos + Vector2(bow_side * 9.0, -12.0 * grow),
		pos + Vector2(bow_side * (11.0 + sway), 10.0 * grow),
	])
	canvas.draw_polyline(rim, _with_alpha(cloak_rim, cloak_rim.a * 0.9), 1.5, true)


func _draw_archer_shoulder_pods(canvas: CanvasItem, pos: Vector2, emerge_progress: float, palette: Dictionary, alpha: float) -> void:
	# Twin 링파츠 hardware that widen the silhouette top. Drawn before the skull so the skull
	# dome can overlap them slightly.
	var plate_dark := _palette_color(palette, "plate_dark", BONE_SHADOW)
	var cream := _palette_color(palette, "bone_cream", BONE_COLOR)
	var inlay := _palette_color(palette, "eye_glow", SOUL_COLOR)
	var rim := _palette_color(palette, "cloak_rim", BONE_COLOR)
	for side in [-1.0, 1.0]:
		var offset := _archer_assemble_offset(3, emerge_progress)
		var pod := pos + offset + Vector2(side * 11.0, -26.0)
		canvas.draw_circle(pod, 3.6, plate_dark)
		canvas.draw_circle(pod, 2.6, cream)
		canvas.draw_circle(pod, 1.0, inlay)
		canvas.draw_arc(pod, 3.4, 0.0, TAU, 16, _with_alpha(rim, rim.a * 0.8), 1.0, true)


func _draw_archer_skull_lantern(canvas: CanvasItem, skull_center: Vector2, phase: float, emerge_progress: float, palette: Dictionary, alpha: float) -> void:
	# Hero block: a clean cream dome + jaw inside a dark hood mouth, a forehead gem, and the
	# boldened glowing eyes -- the single strong interior detail. No sutures/teeth/nose/cheekbones.
	var cloak_core := _palette_color(palette, "cloak_core", BONE_SHADOW)
	var plate_dark := _palette_color(palette, "plate_dark", BONE_SHADOW)
	var cream := _palette_color(palette, "bone_cream", BONE_COLOR)
	var eye_glow := _palette_color(palette, "eye_glow", SOUL_COLOR)
	var eye_core := _palette_color(palette, "eye_core", SOUL_COLOR)
	# hood mouth shadow seats the skull "lit inside the hood"
	canvas.draw_circle(skull_center + Vector2(0.0, 1.0), 8.5, cloak_core)
	# dome + jaw + crisp construct rim
	canvas.draw_circle(skull_center + Vector2(0.0, 1.0), 9.0, plate_dark)
	canvas.draw_circle(skull_center, 8.0, cream)
	var jaw := PackedVector2Array([
		skull_center + Vector2(-4.5, 5.0),
		skull_center + Vector2(4.5, 5.0),
		skull_center + Vector2(3.4, 9.5),
		skull_center + Vector2(-3.4, 9.5),
	])
	canvas.draw_polygon(jaw, PackedColorArray([cream, cream, cream, cream]))
	canvas.draw_arc(skull_center, 8.0, 0.0, TAU, 28, _with_alpha(plate_dark, plate_dark.a * 0.9), 1.0, true)
	# forehead gem (signature 링파츠), kept small so it never out-shouts the eyes
	var fg := skull_center + Vector2(0.0, -6.0)
	canvas.draw_circle(fg, 2.0, plate_dark)
	canvas.draw_circle(fg, 1.3, eye_glow)
	canvas.draw_circle(fg, 0.7, eye_core)
	# eyes (THE focal point): one shared synced pulse so the pair reads symmetric, and the glow
	# radius always exceeds the socket so neither eye flickers down to a bare dark ring.
	var pulse := 0.7 + 0.3 * sin(phase * 3.2)
	canvas.draw_circle(skull_center + Vector2(0.0, -1.0), 6.0, _with_alpha(eye_glow, eye_glow.a * 0.20 * pulse))
	for side in [-1.0, 1.0]:
		var eye := skull_center + Vector2(side * 3.6, -1.0)
		canvas.draw_circle(eye, 2.6, plate_dark)
		canvas.draw_circle(eye, 2.7 + pulse * 0.6, _with_alpha(eye_glow, eye_glow.a * 0.95))
		canvas.draw_circle(eye, 1.0, eye_core)


func _draw_archer_chest_core(
	canvas: CanvasItem,
	archer: Dictionary,
	pos: Vector2,
	phase: float,
	emerge_progress: float,
	palette: Dictionary,
	alpha: float,
	arrow_draw_time: float
) -> void:
	# Second 링파츠 focal + the string's nock anchor. Ignites LAST during emerge (a clean
	# construct-boot "power-on" beat), and its halo brightens while the shot charges.
	if emerge_progress < 0.75:
		return
	var ignite := clampf((emerge_progress - 0.75) / 0.25, 0.0, 1.0)
	var plate_dark := _palette_color(palette, "plate_dark", BONE_SHADOW)
	var cream := _palette_color(palette, "bone_cream", BONE_COLOR)
	var gem := _palette_color(palette, "eye_glow", SOUL_COLOR)
	var gem_core := _palette_color(palette, "eye_core", SOUL_COLOR)
	var rim := _palette_color(palette, "cloak_rim", BONE_COLOR)
	var center := pos + Vector2(0.0, -16.0)
	var draw_progress := 0.0
	if bool(archer.get("is_drawing", false)):
		draw_progress = clampf(float(archer.get("draw_timer", 0.0)) / maxf(0.001, arrow_draw_time), 0.0, 1.0)
	var pulse := 0.6 + 0.4 * sin(phase * 3.0)
	var halo := (0.20 * pulse + 0.30 * draw_progress) * ignite
	canvas.draw_circle(center, 3.5 + pulse * 2.0 + draw_progress * 2.0, _with_alpha(gem, gem.a * halo))
	_draw_hexagon(canvas, center, 4.0, plate_dark)
	_draw_hexagon(canvas, center, 2.8, cream)
	canvas.draw_circle(center, 2.4 * ignite, _with_alpha(gem, gem.a * ignite))
	canvas.draw_circle(center, 1.2 * ignite, _with_alpha(gem_core, gem_core.a * ignite))
	canvas.draw_arc(center, 4.0, 0.0, TAU, 14, _with_alpha(rim, rim.a * 0.8 * ignite), 1.0, true)


func _draw_hexagon(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(6):
		var a := float(i) / 6.0 * TAU - PI * 0.5
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
		cols.append(color)
	canvas.draw_polygon(pts, cols)


func _draw_archer_bow_and_arms(
	canvas: CanvasItem,
	archer: Dictionary,
	pos: Vector2,
	emerge_progress: float,
	phase: float,
	palette: Dictionary,
	arrow_draw_time: float
) -> void:
	var bow_side := 1.0 if float(archer.get("velocity_x", 0.0)) >= 0.0 else -1.0
	var offset := _archer_assemble_offset(1, emerge_progress)
	var aim_dir := 1.0 if bool(archer.get("caster_is_top", false)) else -1.0
	if bool(archer.get("is_drawing", false)) and emerge_progress >= 1.0:
		var draw_progress := clampf(float(archer.get("draw_timer", 0.0)) / maxf(0.001, arrow_draw_time), 0.0, 1.0)
		_draw_drawing_bow_pose(canvas, pos + offset, bow_side, aim_dir, draw_progress, phase, palette)
	else:
		_draw_resting_bow_pose(canvas, pos + offset, bow_side, palette)


func _draw_drawing_bow_pose(canvas: CanvasItem, pos: Vector2, bow_side: float, aim_dir: float, draw_progress: float, phase: float, palette: Dictionary) -> void:
	var cream := _palette_color(palette, "bone", BONE_COLOR)
	var shadow := _palette_color(palette, "plate_dark", BONE_SHADOW)
	var bow_dark := _palette_color(palette, "bow_dark", GOLD_COLOR)
	var bow_lit := _palette_color(palette, "bow_lit", GOLD_COLOR)
	var string_color := _palette_color(palette, "string", BONE_COLOR)
	var soul_core := _palette_color(palette, "soul_core", SOUL_COLOR)
	# Arrows fire up at the boss. The bow is held out on the lead side at a 3/4 tilt aimed
	# up-and-outward; the string is pulled to the chest and the nocked arrow runs through the
	# grip at the target (bow held the correct way round). Cleaned to single-bone arms + a
	# 3-pass bow -- no elbow joints, no grip wrap, no rune dots.
	var aim := Vector2(bow_side * 0.34, aim_dir).normalized()
	var grip := pos + Vector2(bow_side * 19.0, -19.0)
	var bow_points := _build_recurve_bow_points(grip, aim, 13.0, 6.0)
	var nock := grip - aim * (12.0 * draw_progress)

	# bow arm: one clean bone over a 1px shadow
	var bow_shoulder := pos + Vector2(bow_side * 6.0, -22.0)
	canvas.draw_line(bow_shoulder + Vector2(1.0, 1.0), grip + Vector2(1.0, 1.0), shadow, 2.4, true)
	canvas.draw_line(bow_shoulder, grip, cream, 2.0, true)

	# bow body: 3 passes only (dark shadow / bone core / lit edge toward target) + tip dots
	_draw_polyline_segments(canvas, _offset_points(bow_points, Vector2(1.0, 1.0)), bow_dark, 3.0)
	_draw_polyline_segments(canvas, bow_points, cream, 2.0)
	_draw_polyline_segments(canvas, _offset_points(_slice_points(bow_points, 2, bow_points.size() - 2), aim), bow_lit, 1.0)
	canvas.draw_circle(bow_points[0], 1.2, soul_core)
	canvas.draw_circle(bow_points[bow_points.size() - 1], 1.2, soul_core)

	# string: two limb tips back to the nock, brightening into soul-core as the shot charges
	if draw_progress > 0.4:
		var glow := _with_alpha(soul_core, soul_core.a * 0.5 * draw_progress)
		canvas.draw_line(bow_points[0], nock, glow, 2.0, true)
		canvas.draw_line(bow_points[bow_points.size() - 1], nock, glow, 2.0, true)
	canvas.draw_line(bow_points[0], nock, string_color, 1.0, true)
	canvas.draw_line(bow_points[bow_points.size() - 1], nock, string_color, 1.0, true)

	# draw arm: one clean bone pulling the string to the chest
	var draw_shoulder := pos + Vector2(-bow_side * 5.0, -20.0)
	canvas.draw_line(draw_shoulder + Vector2(1.0, 1.0), nock + Vector2(1.0, 1.0), shadow, 2.4, true)
	canvas.draw_line(draw_shoulder, nock, cream, 2.0, true)
	canvas.draw_circle(nock, 1.4, cream)

	# arrow: nock -> through the grip -> tip, pointing along the aim line at the target
	if draw_progress > 0.15:
		_draw_aiming_arrow(canvas, nock, grip + aim * 22.0, aim, draw_progress, phase, palette)


func _draw_resting_bow_pose(canvas: CanvasItem, pos: Vector2, bow_side: float, palette: Dictionary) -> void:
	# Relaxed: bow held low on the lead side, vertical, ONE arm (no second hand / shoulder bone).
	var cream := _palette_color(palette, "bone", BONE_COLOR)
	var shadow := _palette_color(palette, "plate_dark", BONE_SHADOW)
	var bow_dark := _palette_color(palette, "bow_dark", GOLD_COLOR)
	var bow_lit := _palette_color(palette, "bow_lit", GOLD_COLOR)
	var string_color := _palette_color(palette, "string", BONE_COLOR)
	var soul_core := _palette_color(palette, "soul_core", SOUL_COLOR)
	var shoulder := pos + Vector2(bow_side * 6.0, -20.0)
	var hand := pos + Vector2(bow_side * 15.0, -8.0)
	canvas.draw_line(shoulder + Vector2(1.0, 1.0), hand + Vector2(1.0, 1.0), shadow, 2.4, true)
	canvas.draw_line(shoulder, hand, cream, 2.0, true)
	# Smooth vertical bow (limbs top/bottom, belly bowing outward) built from the same recurve
	# helper with a horizontal aim, so the resting bow is a clean arc instead of a sharp zig.
	var bow_points := _build_recurve_bow_points(hand, Vector2(bow_side, 0.0), 12.0, 5.0)
	var top_tip := bow_points[0]
	var bottom_tip := bow_points[bow_points.size() - 1]
	_draw_polyline_segments(canvas, _offset_points(bow_points, Vector2(1.0, 1.0)), bow_dark, 3.0)
	_draw_polyline_segments(canvas, bow_points, cream, 2.0)
	_draw_polyline_segments(canvas, _offset_points(_slice_points(bow_points, 2, bow_points.size() - 2), Vector2(bow_side, 0.0)), _with_alpha(bow_lit, bow_lit.a * 0.7), 1.0)
	canvas.draw_line(top_tip, bottom_tip, _with_alpha(string_color, string_color.a * 0.7), 1.0, true)
	canvas.draw_circle(top_tip, 1.1, soul_core)
	canvas.draw_circle(bottom_tip, 1.1, soul_core)


func _draw_aiming_arrow(canvas: CanvasItem, nock: Vector2, arrow_tip: Vector2, aim: Vector2, draw_progress: float, phase: float, palette: Dictionary) -> void:
	var shadow := _palette_color(palette, "plate_dark", BONE_SHADOW)
	var cream := _palette_color(palette, "bone_cream", BONE_COLOR)
	var arrow := _palette_color(palette, "arrow", ARROW_COLOR)
	var highlight := _palette_color(palette, "soul_core", SOUL_COLOR)
	var soul := _palette_color(palette, "soul_core", SOUL_COLOR)
	var perp := Vector2(-aim.y, aim.x)
	# straight shaft from the nock through the grip to the tip (shadow / body / highlight)
	canvas.draw_line(nock + Vector2(1.0, 1.0), arrow_tip + Vector2(1.0, 1.0), shadow, 2.0, true)
	canvas.draw_line(nock, arrow_tip, arrow, 2.0, true)
	canvas.draw_line(nock, nock.lerp(arrow_tip, 0.55), cream, 1.0, true)
	# solid arrowhead pointing along the aim line at the target
	var head_point := arrow_tip + aim * 6.0
	var head_left := arrow_tip + perp * 3.2 + aim * 0.5
	var head_right := arrow_tip - perp * 3.2 + aim * 0.5
	canvas.draw_polygon(
		PackedVector2Array([head_point, head_left, head_right]),
		PackedColorArray([highlight, highlight, highlight])
	)
	canvas.draw_line(head_left, head_point, shadow, 1.0, true)
	canvas.draw_line(head_right, head_point, shadow, 1.0, true)
	# symmetric fletching barbs at the tail (nock), swept back away from the target
	canvas.draw_line(nock, nock - aim * 3.4 + perp * 2.4, arrow, 1.0, true)
	canvas.draw_line(nock, nock - aim * 3.4 - perp * 2.4, arrow, 1.0, true)
	if draw_progress > 0.7:
		var charge := (draw_progress - 0.7) / 0.3
		canvas.draw_circle(arrow_tip + aim * 3.0, 3.0 + sin(phase * 8.0) * 0.5, _with_alpha(soul, 0.30 * charge))


func _draw_archer_soul_motes(canvas: CanvasItem, pos: Vector2, phase: float, is_golden: bool, alpha: float) -> void:
	var soul := GOLD_ARROW_COLOR if is_golden else SOUL_COLOR
	for mote_index in range(3):
		var angle := phase * 2.4 + float(mote_index) * 2.1
		var radius := 8.0 + float(mote_index % 2) * 5.0
		var mote_pos := pos + Vector2(cos(angle) * radius, -26.0 + sin(angle * 1.4) * 9.0)
		canvas.draw_circle(mote_pos, 1.0 + float(mote_index % 2), _with_alpha(soul, (0.18 + 0.06 * sin(angle)) * alpha))
	if is_golden:
		for aura_index in range(4):
			var angle := phase * 1.8 + float(aura_index) * TAU / 4.0
			var aura_pos := pos + Vector2(cos(angle) * 18.0, -25.0 + sin(angle) * 14.0)
			canvas.draw_circle(aura_pos, 1.2, _with_alpha(GOLD_ARROW_COLOR, 0.25 * alpha))


func _build_recurve_bow_points(grip: Vector2, aim: Vector2, bow_half: float, bow_belly: float) -> PackedVector2Array:
	# Bow centered on the grip, oriented to the aim line: the limbs run along the axis
	# perpendicular to the aim, the belly bows TOWARD the target (the rounded back faces the
	# boss), and the limb tips taper back TOWARD the archer so the string and the pulled-back
	# nock sit on the archer's side -- holding the bow the correct way round, not reversed.
	var axis := Vector2(-aim.y, aim.x)
	var points := PackedVector2Array()
	for point_index in range(13):
		var t := float(point_index) / float(ARCHER_BOW_POINT_COUNT - 1)
		var along := (t - 0.5) * 2.0 * bow_half
		var belly := sin(t * PI) * bow_belly
		var recurve := 0.0
		if t < 0.15 or t > 0.85:
			recurve = 2.0 * (1.0 - minf(t, 1.0 - t) / 0.15)
		points.append(grip + axis * along + aim * (belly - recurve))
	return points


func _archer_assemble_offset(part_index: int, emerge_progress: float) -> Vector2:
	if emerge_progress >= 1.0:
		return Vector2.ZERO
	var part_start := (float(part_index) / float(ARCHER_PART_COUNT)) * 0.4
	var part_progress := clampf((emerge_progress - part_start) / 0.6, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - part_progress, 3.0)
	var angle := (float(part_index) / float(ARCHER_PART_COUNT)) * TAU + float(part_index) * 1.3
	var start_dist := 40.0 + float(part_index) * 8.0
	return Vector2(cos(angle), sin(angle)) * start_dist * (1.0 - ease)


func _get_archer_part_pos(pos: Vector2, emerge_progress: float, part_index: int, local_offset: Vector2) -> Vector2:
	return pos + local_offset + _archer_assemble_offset(part_index, emerge_progress)


func _palette_color(palette: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = palette.get(key, fallback)
	if value is Color:
		return value
	return fallback


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = clampf(alpha, 0.0, 1.0)
	return result


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for index in range(points.size()):
		shifted.append(points[index] + offset)
	return shifted


func _slice_points(points: PackedVector2Array, start_index: int, end_index: int) -> PackedVector2Array:
	var sliced := PackedVector2Array()
	for index in range(start_index, end_index):
		if index >= 0 and index < points.size():
			sliced.append(points[index])
	return sliced


func _draw_polyline_segments(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	for index in range(maxi(0, points.size() - 1)):
		canvas.draw_line(points[index], points[index + 1], color, width, true)


func _draw_dying_archer(canvas: CanvasItem, dying: Dictionary, shake_offset: Vector2, death_duration: float) -> void:
	var timer := float(dying.get("timer", 0.0))
	var progress := clampf(timer / maxf(0.001, death_duration), 0.0, 1.0)
	var alpha := clampf(1.0 - progress, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var origin := _get_dict_vector2(dying, "pos", Vector2.ZERO) + shake_offset + Vector2(0.0, 14.0)
	# Clean teal-cream death shards, cohesive with the redesigned spirit palette.
	var bone := _with_alpha(Color(0.906, 0.945, 0.886, 1.0), alpha)
	var bright := _with_alpha(Color(0.95, 0.98, 0.94, 1.0), alpha * 0.70)
	var cream := _with_alpha(Color(0.55, 0.86, 0.78, 1.0), alpha * 0.50)
	var bow_color := _with_alpha(Color(0.498, 0.847, 0.753, 1.0), alpha)
	var string_color := _with_alpha(Color(0.624, 0.910, 0.816, 1.0), alpha * 0.60)
	var fragments: Array = dying.get("fragments", []) as Array
	for fragment in fragments:
		var pos := _get_dict_vector2(fragment, "pos", Vector2.ZERO) + shake_offset
		var rotation := float(fragment.get("rotation", 0.0))
		var length := float(fragment.get("length", 8.0))
		var side := Vector2(cos(rotation), sin(rotation)) * length * 0.5
		if bool(fragment.get("is_bow", false)):
			canvas.draw_line(pos - side, pos + side, bow_color, 2.0, true)
			var mid := pos + Vector2(sin(rotation) * 3.0, 0.0)
			canvas.draw_line(pos - side, mid, string_color, 1.0, true)
		else:
			canvas.draw_line(pos - side, pos + side, bone, 2.0, true)
			canvas.draw_circle(pos - side, 2.0, bright)
			canvas.draw_line(pos - side, pos + side, cream, 1.0, true)
	if progress < 0.3:
		var wave_t := progress / 0.3
		canvas.draw_arc(origin + Vector2(0.0, -20.0), 40.0 * wave_t, 0.0, TAU, 44, _with_alpha(SOUL_COLOR, 0.58 * (1.0 - wave_t)), 2.0, true)
	if progress < 0.8:
		var skull_pos := origin + Vector2(sin(progress * 5.0) * 5.0, -30.0 - 20.0 * progress)
		var skull_alpha := alpha * (1.0 - progress / 0.8)
		canvas.draw_arc(skull_pos, 6.0, 0.0, PI, 16, _with_alpha(bone, skull_alpha), 2.0, true)
		canvas.draw_circle(skull_pos + Vector2(-2.0, -1.0), 2.0, _with_alpha(SOUL_COLOR, skull_alpha * 0.80))
	var soul_count := int(8.0 + 12.0 * progress)
	for soul_index in range(soul_count):
		var soul_angle := float(soul_index) * 0.55 + progress * 6.0
		var soul_dist := 8.0 + 15.0 * progress + 5.0 * sin(soul_angle)
		var soul_pos := origin + Vector2(cos(soul_angle) * soul_dist * 0.7, -20.0 - 50.0 * progress + sin(soul_angle * 2.0) * 8.0)
		var soul_alpha := alpha * 0.5 * (0.5 + 0.5 * sin(float(soul_index) + progress * 10.0))
		if soul_alpha > 0.03:
			canvas.draw_circle(soul_pos, 1.0 + float(soul_index % 3) * 0.4, _with_alpha(SOUL_COLOR, soul_alpha))
	if progress > 0.3:
		var dust_count := int(6.0 * (progress - 0.3))
		for dust_index in range(dust_count):
			var dust_x := -25.0 + float(dust_index) * 10.0 + sin(progress * 9.0 + float(dust_index)) * 3.0
			var dust_y := -3.0 + float(dust_index % 3) * 4.0
			canvas.draw_circle(origin + Vector2(dust_x, dust_y), 1.0, _with_alpha(Color(0.70, 0.64, 0.48, 1.0), 0.30 * alpha))


func _draw_arrow(canvas: CanvasItem, arrow: Dictionary, shake_offset: Vector2) -> void:
	var pos := _get_dict_vector2(arrow, "pos", Vector2.ZERO) + shake_offset
	var vel := _get_dict_vector2(arrow, "vel", Vector2.UP)
	var direction := vel.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.UP
	var is_golden := bool(arrow.get("is_golden", false))
	var shaft_dark := Color(0.78, 0.58, 0.16, 1.0) if is_golden else Color(0.46, 0.42, 0.34, 1.0)
	var shaft_mid := GOLD_ARROW_COLOR if is_golden else Color(0.74, 0.70, 0.58, 1.0)
	var shaft_light := Color(1.0, 0.90, 0.38, 1.0) if is_golden else Color(0.88, 0.84, 0.70, 1.0)
	var head_outer := Color(0.86, 0.60, 0.12, 1.0) if is_golden else Color(0.32, 0.68, 0.38, 1.0)
	var head_inner := Color(1.0, 0.82, 0.25, 1.0) if is_golden else Color(0.55, 0.86, 0.52, 1.0)
	var head_edge := Color(0.54, 0.36, 0.08, 1.0) if is_golden else Color(0.22, 0.42, 0.20, 1.0)
	var feather_a := Color(0.62, 0.44, 0.10, 1.0) if is_golden else Color(0.24, 0.21, 0.17, 1.0)
	var feather_b := Color(0.82, 0.58, 0.16, 1.0) if is_golden else Color(0.34, 0.30, 0.24, 1.0)
	var feather_highlight := Color(0.94, 0.70, 0.20, 1.0) if is_golden else Color(0.46, 0.40, 0.32, 1.0)
	var trail_base := GOLD_ARROW_COLOR if is_golden else SOUL_COLOR
	var energy_color := Color(1.0, 0.90, 0.40, 1.0) if is_golden else Color(0.46, 1.0, 0.55, 1.0)
	var perpendicular := direction.rotated(PI * 0.5)
	var trail: Array = arrow.get("trail", []) as Array
	for index in range(trail.size()):
		var point_value: Variant = trail[index]
		if not (point_value is Vector2):
			continue
		var t := float(index + 1) / float(trail.size())
		var trail_pos := (point_value as Vector2) + shake_offset
		canvas.draw_circle(trail_pos, maxf(1.0, 2.6 * t), _with_alpha(trail_base, 0.18 * t))
		if index > 0:
			var previous_value: Variant = trail[index - 1]
			if previous_value is Vector2:
				canvas.draw_line((previous_value as Vector2) + shake_offset, trail_pos, _with_alpha(trail_base, 0.10 * t), 1.0, true)
	for wind_index in range(2):
		var wind_side := 1.0 if wind_index == 0 else -1.0
		var start := pos - direction * (6.0 + float(wind_index) * 5.0) + perpendicular * wind_side * (2.0 + float(wind_index))
		var end := start - direction * 5.0
		canvas.draw_line(start, end, _with_alpha(energy_color, 0.18), 1.0, true)
	var tip := pos + direction * 6.0
	var tail := pos - direction * ARROW_LENGTH
	canvas.draw_line(tail + Vector2(1.0, 1.0), pos + Vector2(1.0, 1.0), shaft_dark, 1.0, true)
	canvas.draw_line(tail, pos, shaft_mid, 2.0, true)
	canvas.draw_line(tail + direction * 2.0, pos - direction * 1.0, shaft_light, 1.0, true)
	var left := pos + perpendicular * 2.5 - direction
	var right := pos - perpendicular * 2.5 - direction
	canvas.draw_line(tip, left, head_outer, 2.0, true)
	canvas.draw_line(tip, right, head_outer, 2.0, true)
	canvas.draw_line(tip, pos, head_inner, 1.0, true)
	canvas.draw_line(left, right, head_edge, 1.0, true)
	for feather_side_index in range(2):
		var side := -1.0 if feather_side_index == 0 else 1.0
		var feather_base := tail + direction
		var feather_tip := tail - direction * 5.0 + perpendicular * side * 2.5
		var feather_edge := tail - direction * 3.0 + perpendicular * side * 0.5
		var feather_color := feather_a if side < 0.0 else feather_b
		canvas.draw_line(feather_base, feather_edge, feather_color, 2.0, true)
		canvas.draw_line(feather_edge, feather_tip, feather_color, 2.0, true)
		canvas.draw_line(feather_base, feather_tip, feather_highlight, 1.0, true)
	canvas.draw_circle(tail, 1.1, shaft_dark)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2, particles: Array[Dictionary]) -> void:
	for particle in particles:
		var age := float(particle.get("age", 0.0))
		var life := maxf(0.001, float(particle.get("life", 0.001)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var color: Color = particle.get("color", SOUL_COLOR)
		color.a *= ratio
		var pos := _get_dict_vector2(particle, "pos", Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, float(particle.get("size", 2.0)) * (0.7 + ratio * 0.5), color)


func _draw_bone_line(canvas: CanvasItem, start_pos: Vector2, end_pos: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(start_pos, end_pos, color, width, true)
	canvas.draw_circle(start_pos, maxf(1.1, width * 0.72), color)
	canvas.draw_circle(end_pos, maxf(1.1, width * 0.72), color)


func _get_dict_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
