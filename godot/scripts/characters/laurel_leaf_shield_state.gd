extends RefCounted

const PERK_ID := "perk_laurel_shield"
const ORBIT_RADIUS := 196.0
const ELLIPSE_Y := 0.30
const FRONT_THRESHOLD := 30.0
const LEAF_SIZE := 19.0
const HITBOX_SIZE := 35.0
const REGEN_DELAY_FRAMES := 30.0 * 60.0
const ROTATION_SPEED := 1.8
const PARTICLE_COUNT := 15
const FIELD_HEIGHT := 750.0
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const LOD_ACTIVE_THRESHOLD := 0.99
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.66
const LOD_GLOW_SEGMENTS := 10
const LOD_PARTICLE_STRIDE := 2
const SEVERE_LOD_PARTICLE_STRIDE := 3
const MAX_DISPLAY_LEAF_COUNT := 3

var active := false
var leaf_count := 0
var leaves: Array = []
var current_angle := 0.0
var owner_center := Vector2.ZERO
var particles: Array = []


func reset() -> void:
	deactivate()


func deactivate() -> void:
	active = false
	leaf_count = 0
	leaves.clear()
	particles.clear()
	current_angle = 0.0


func update_from_runtime(owner: Object, registry: Object, delta: float) -> void:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var target_count := 0
	if runtime_perk_state != null and runtime_perk_state.has_method("get_laurel_leaf_count"):
		target_count = max(0, int(runtime_perk_state.get_laurel_leaf_count(registry)))
	if target_count <= 0:
		if active:
			deactivate()
		return

	owner_center = _read_player_center(owner)
	if not active or leaf_count != target_count or leaves.size() != target_count:
		activate(target_count)
	_update(max(0.0, float(delta)) * 60.0)


func activate(count: int) -> void:
	leaf_count = max(0, count)
	if leaf_count <= 0:
		deactivate()
		return
	active = true
	current_angle = 0.0
	leaves.clear()
	particles.clear()
	for i in range(leaf_count):
		leaves.append({
			"active": true,
			"base_angle": TAU * float(i) / float(max(1, leaf_count)),
			"regen_timer": 0.0,
			"type": randi_range(0, 3),
			"size_variation": randf_range(0.8, 1.2),
		})


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not active:
		return {}
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return {}
	owner_center = _get_player_center(context)
	if owner_center == Vector2.ZERO:
		return {}

	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_radius: float = _get_ball_radius(context)
	var display_leaf_mask := get_display_leaf_mask()
	for logical_index in range(leaves.size()):
		if (display_leaf_mask & (1 << logical_index)) == 0:
			continue
		var leaf: Dictionary = leaves[logical_index]
		var leaf_pos: Vector2 = _get_leaf_position(leaf)
		if leaf_pos.y < owner_center.y - FRONT_THRESHOLD:
			continue
		if ball_pos.distance_to(leaf_pos) < ball_radius + HITBOX_SIZE:
			_destroy_leaf(leaf, leaf_pos)
			_play_hit_feedback(deps)
			return {
				"ball_vel": _build_reflect_velocity(ball_vel),
				"laurel_leaf_hit": true,
			}
	return {}


func has_visible_effects() -> bool:
	return active or not particles.is_empty()


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, effect_lod_scale: float = 1.0) -> void:
	if canvas == null:
		return
	var clamped_lod_scale: float = clamp(effect_lod_scale, 0.0, 1.0)
	var lod_active: bool = _is_lod_active(clamped_lod_scale)
	var severe_lod: bool = _is_severe_lod_active(clamped_lod_scale)
	var draw_order: Array = []
	if active:
		var display_leaf_mask := get_display_leaf_mask()
		for logical_index in range(leaves.size()):
			if (display_leaf_mask & (1 << logical_index)) == 0:
				continue
			var leaf: Dictionary = leaves[logical_index]
			var angle := _get_leaf_angle(leaf)
			var depth: float = sin(angle)
			draw_order.append({
				"depth": depth,
				"angle": angle,
				"position": _get_leaf_position(leaf) + shake_offset,
				"leaf": leaf,
			})
		draw_order.sort_custom(Callable(self, "_sort_leaf_draw_order"))

	for entry in draw_order:
		if lod_active:
			_draw_leaf_lod(canvas, entry, severe_lod)
		else:
			_draw_leaf(canvas, entry)
	_draw_particles(canvas, shake_offset, clamped_lod_scale)


func get_snapshot() -> Dictionary:
	var active_count := _count_active_leaves()
	return {
		"active": active,
		"leaf_count": leaf_count,
		"active_leaf_count": active_count,
		"display_leaf_count": get_display_leaf_count(),
		"display_active_leaf_count": get_display_active_leaf_count(),
		"owner_center": owner_center,
		"particle_count": particles.size(),
		"current_angle": current_angle,
	}


func get_display_leaf_count() -> int:
	if leaf_count <= 0:
		return 0
	# Gameplay keeps its authored 1/3/5 blocking leaves. Presentation alone
	# compresses those ranks to 1/2/3 silhouettes and caps effective overflow.
	return mini(MAX_DISPLAY_LEAF_COUNT, ceili(float(leaf_count) * 0.5))


func get_display_active_leaf_count() -> int:
	return _project_display_active_leaf_count(
		_count_active_leaves(),
		get_display_leaf_count()
	)


func get_display_leaf_mask() -> int:
	var active_leaf_count := _count_active_leaves()
	var display_active_leaf_count := _project_display_active_leaf_count(
		active_leaf_count,
		get_display_leaf_count()
	)
	var active_index := 0
	var display_mask := 0
	for logical_index in range(leaves.size()):
		var leaf: Dictionary = leaves[logical_index]
		if not bool(leaf.get("active", false)):
			continue
		if _is_display_representative(
			active_index,
			active_leaf_count,
			display_active_leaf_count
		):
			display_mask |= 1 << logical_index
		active_index += 1
	return display_mask


func _update(fps_scale: float) -> void:
	if not active:
		_update_particles(fps_scale)
		return
	current_angle = fposmod(current_angle + ROTATION_SPEED * fps_scale / 60.0, TAU)
	for leaf in leaves:
		if bool(leaf.get("active", false)):
			continue
		var timer: float = float(leaf.get("regen_timer", 0.0)) + fps_scale
		if timer >= REGEN_DELAY_FRAMES:
			leaf["active"] = true
			leaf["regen_timer"] = 0.0
			leaf["type"] = randi_range(0, 3)
			leaf["size_variation"] = randf_range(0.8, 1.2)
		else:
			leaf["regen_timer"] = timer
	_update_particles(fps_scale)


func _update_particles(fps_scale: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle["position"] = _get_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + _get_vector2(particle.get("velocity", Vector2.ZERO), Vector2.ZERO) * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		if float(particle.get("life", 0.0)) <= 0.0:
			particles.remove_at(i)
		else:
			particles[i] = particle


func _count_active_leaves() -> int:
	var active_leaf_count := 0
	for leaf in leaves:
		if bool(leaf.get("active", false)):
			active_leaf_count += 1
	return active_leaf_count


func _project_display_active_leaf_count(active_leaf_count: int, display_leaf_count: int) -> int:
	if active_leaf_count <= 0 or leaf_count <= 0 or display_leaf_count <= 0:
		return 0
	return mini(
		display_leaf_count,
		ceili(float(active_leaf_count * display_leaf_count) / float(leaf_count))
	)


func _is_display_representative(
	active_index: int,
	active_leaf_count: int,
	display_active_leaf_count: int
) -> bool:
	if active_index < 0 or active_index >= active_leaf_count or display_active_leaf_count <= 0:
		return false
	if display_active_leaf_count >= active_leaf_count or active_index == 0:
		return true
	var bucket := floori(
		float(active_index * display_active_leaf_count) / float(active_leaf_count)
	)
	var previous_bucket := floori(
		float((active_index - 1) * display_active_leaf_count) / float(active_leaf_count)
	)
	return bucket != previous_bucket


func _get_leaf_angle(leaf: Dictionary) -> float:
	return current_angle + float(leaf.get("base_angle", 0.0))


func _get_leaf_position(leaf: Dictionary) -> Vector2:
	var angle := _get_leaf_angle(leaf)
	return owner_center + Vector2(cos(angle) * ORBIT_RADIUS, sin(angle) * ORBIT_RADIUS * ELLIPSE_Y)


func _destroy_leaf(leaf: Dictionary, position: Vector2) -> void:
	leaf["active"] = false
	leaf["regen_timer"] = 0.0
	var colors := [
		Color(1.0, 215.0 / 255.0, 100.0 / 255.0),
		Color(1.0, 240.0 / 255.0, 150.0 / 255.0),
		Color(1.0, 200.0 / 255.0, 80.0 / 255.0),
		Color(220.0 / 255.0, 180.0 / 255.0, 60.0 / 255.0),
		Color(1.0, 1.0, 200.0 / 255.0),
	]
	for _i in range(PARTICLE_COUNT):
		particles.append({
			"position": position,
			"velocity": Vector2(randf_range(-3.0, 3.0), randf_range(-4.0, 1.0)),
			"life": randf_range(20.0, 40.0),
			"max_life": 40.0,
			"color": colors[randi_range(0, colors.size() - 1)],
		})


func _build_reflect_velocity(ball_vel: Vector2) -> Vector2:
	var speed: float = ball_vel.length()
	if speed <= 0.0:
		speed = 8.0
	var boosted_speed: float = speed * randf_range(1.2, 1.5)
	var angle: float = -PI * 0.5 + randf_range(-PI / 3.0, PI / 3.0)
	return Vector2(cos(angle), sin(angle)) * boosted_speed


func _draw_leaf(canvas: CanvasItem, entry: Dictionary) -> void:
	var depth: float = float(entry.get("depth", 0.0))
	var angle: float = float(entry.get("angle", 0.0))
	var leaf: Dictionary = entry.get("leaf", {})
	var position: Vector2 = _get_vector2(entry.get("position", Vector2.ZERO), Vector2.ZERO)
	var depth_factor: float = 0.6 + 0.4 * ((depth + 1.0) * 0.5)
	var alpha_f: float = 0.5 + 0.5 * ((depth + 1.0) * 0.5)
	var size_variation: float = float(leaf.get("size_variation", 1.0))
	var sz: float = max(2.0, LEAF_SIZE * depth_factor * size_variation)

	# Surface +x maps to axis (radially outward = leaf tip), surface +y maps to perp.
	var axis := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-axis.y, axis.x)

	# Elliptical golden glow oriented with the leaf (matches Python ArenaLeafShield).
	var glow_w: float = sz * 4.0
	var glow_h: float = sz * 3.0
	var glow_color := Color(1.0, 215.0 / 255.0, 100.0 / 255.0, (40.0 / 255.0) * alpha_f)
	_draw_oriented_ellipse(canvas, position, axis, perp, 0.0, 0.0, glow_w * 0.5, glow_h * 0.5, glow_color, 24)

	var leaf_w: float = max(4.0, sz * 2.5)
	var leaf_h: float = max(3.0, sz * 1.2)
	var leaf_type: int = int(leaf.get("type", 0))
	match leaf_type:
		0:
			_draw_leaf_type_0(canvas, position, axis, perp, leaf_w, leaf_h, depth_factor)
		1:
			_draw_leaf_type_1(canvas, position, axis, perp, leaf_w, leaf_h, depth_factor)
		2:
			_draw_leaf_type_2(canvas, position, axis, perp, leaf_w, leaf_h, depth_factor)
		_:
			_draw_leaf_type_3(canvas, position, axis, perp, leaf_w, leaf_h, depth_factor)


func _draw_leaf_lod(canvas: CanvasItem, entry: Dictionary, severe_lod: bool) -> void:
	var depth: float = float(entry.get("depth", 0.0))
	var angle: float = float(entry.get("angle", 0.0))
	var leaf: Dictionary = entry.get("leaf", {})
	var position: Vector2 = _get_vector2(entry.get("position", Vector2.ZERO), Vector2.ZERO)
	var depth_factor: float = 0.6 + 0.4 * ((depth + 1.0) * 0.5)
	var alpha_f: float = 0.5 + 0.5 * ((depth + 1.0) * 0.5)
	var size_variation: float = float(leaf.get("size_variation", 1.0))
	var sz: float = max(2.0, LEAF_SIZE * depth_factor * size_variation)
	var axis := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-axis.y, axis.x)
	var leaf_w: float = max(4.0, sz * (2.25 if severe_lod else 2.55))
	var leaf_h: float = max(3.0, sz * (0.82 if severe_lod else 1.02))
	var stem: Vector2 = position - axis * leaf_w * 0.46
	var tip: Vector2 = position + axis * leaf_w * 0.46
	var leaf_type: int = int(leaf.get("type", 0))
	var base_color := Color(
		220.0 / 255.0 * depth_factor,
		178.0 / 255.0 * depth_factor,
		54.0 / 255.0 * depth_factor,
		0.86 * alpha_f
	)
	var highlight_color := Color(
		1.0 * depth_factor,
		235.0 / 255.0 * depth_factor,
		120.0 / 255.0 * depth_factor,
		0.72 * alpha_f
	)
	var vein_color := Color(
		125.0 / 255.0 * depth_factor,
		92.0 / 255.0 * depth_factor,
		25.0 / 255.0 * depth_factor,
		0.84 * alpha_f
	)
	if not severe_lod and depth > -0.45:
		var glow_color := Color(1.0, 215.0 / 255.0, 100.0 / 255.0, (24.0 / 255.0) * alpha_f)
		_draw_oriented_ellipse(canvas, position, axis, perp, 0.0, 0.0, leaf_w * 0.90, leaf_h * 1.45, glow_color, LOD_GLOW_SEGMENTS)

	var shoulder_x: float = 0.18 if severe_lod else 0.22
	var shoulder_y: float = 0.46 if severe_lod else 0.54
	var rear_y: float = 0.30 if leaf_type == 1 else 0.38
	var stem_y: float = 0.10 if leaf_type == 2 else 0.13
	var body_points := PackedVector2Array([
		tip,
		position + axis * leaf_w * shoulder_x + perp * leaf_h * shoulder_y,
		position - axis * leaf_w * 0.16 + perp * leaf_h * rear_y,
		position - axis * leaf_w * 0.38 + perp * leaf_h * stem_y,
		stem,
		position - axis * leaf_w * 0.38 - perp * leaf_h * stem_y,
		position - axis * leaf_w * 0.16 - perp * leaf_h * rear_y,
		position + axis * leaf_w * shoulder_x - perp * leaf_h * shoulder_y,
	])
	canvas.draw_colored_polygon(body_points, base_color)
	if not severe_lod:
		var highlight_points := PackedVector2Array([
			position + axis * leaf_w * 0.28 + perp * leaf_h * 0.12,
			position + axis * leaf_w * 0.02 + perp * leaf_h * 0.26,
			position - axis * leaf_w * 0.24 + perp * leaf_h * 0.12,
			position - axis * leaf_w * 0.08 - perp * leaf_h * 0.02,
		])
		canvas.draw_colored_polygon(highlight_points, highlight_color)
	canvas.draw_line(stem + axis * leaf_w * 0.08, tip - axis * leaf_w * 0.08, vein_color, 1.0, true)
	if not severe_lod and depth > -0.25:
		var vein_span: float = leaf_w * 0.22
		for i in range(2):
			var anchor: Vector2 = stem + axis * (leaf_w * (0.42 + float(i) * 0.16))
			canvas.draw_line(anchor, anchor - axis * vein_span + perp * leaf_h * 0.34, vein_color, 1.0, true)
			canvas.draw_line(anchor, anchor - axis * vein_span - perp * leaf_h * 0.34, vein_color, 1.0, true)


# ----- leaf-space drawing helpers ---------------------------------------------
# Surface coords (px, py) range over (0..w, 0..h); the leaf is centered in the
# surface and rotated so surface +x aligns with axis (radial outward) and
# surface +y aligns with perp. We compute world points directly without
# touching draw_set_transform (CanvasItem-transform reset trap).

func _draw_pyg_ellipse(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		half_w: float, half_h: float,
		left: float, top: float, ew: float, eh: float,
		color: Color, segments: int = 18) -> void:
	if ew <= 0.0 or eh <= 0.0:
		return
	var cx_local: float = left + ew * 0.5 - half_w
	var cy_local: float = top + eh * 0.5 - half_h
	_draw_oriented_ellipse(canvas, position, axis, perp, cx_local, cy_local, ew * 0.5, eh * 0.5, color, segments)


func _draw_oriented_ellipse(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		cx_local: float, cy_local: float, rw: float, rh: float,
		color: Color, segments: int = 18) -> void:
	if rw <= 0.0 or rh <= 0.0 or segments < 3:
		return
	var pts := PackedVector2Array()
	pts.resize(segments)
	for i in segments:
		var t: float = float(i) / float(segments) * TAU
		var lx: float = cx_local + cos(t) * rw
		var ly: float = cy_local + sin(t) * rh
		pts[i] = position + axis * lx + perp * ly
	canvas.draw_colored_polygon(pts, color)


func _draw_pyg_line(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		half_w: float, half_h: float,
		x1: float, y1: float, x2: float, y2: float,
		color: Color, line_width: float = 1.0) -> void:
	var p1: Vector2 = position + axis * (x1 - half_w) + perp * (y1 - half_h)
	var p2: Vector2 = position + axis * (x2 - half_w) + perp * (y2 - half_h)
	canvas.draw_line(p1, p2, color, max(1.0, line_width), true)


func _draw_pyg_polygon(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		half_w: float, half_h: float,
		points_local: PackedVector2Array,
		color: Color) -> void:
	if points_local.size() < 3:
		return
	var pts := PackedVector2Array()
	pts.resize(points_local.size())
	for i in points_local.size():
		var p: Vector2 = points_local[i]
		pts[i] = position + axis * (p.x - half_w) + perp * (p.y - half_h)
	canvas.draw_colored_polygon(pts, color)


# pygame.draw.arc convention: 0 rad = right, increases CCW visually (pygame
# flips sin internally so positive angle goes "up" on screen). We match that
# by subtracting sin(ang) when computing surface y.
func _draw_pyg_arc(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		half_w: float, half_h: float,
		left: float, top: float, ew: float, eh: float,
		start_angle: float, end_angle: float,
		color: Color, line_width: float, segments: int = 16) -> void:
	if ew <= 0.0 or eh <= 0.0 or segments < 1:
		return
	var cx_local: float = left + ew * 0.5 - half_w
	var cy_local: float = top + eh * 0.5 - half_h
	var rw: float = ew * 0.5
	var rh: float = eh * 0.5
	var prev: Vector2 = Vector2.ZERO
	for i in (segments + 1):
		var t: float = float(i) / float(segments)
		var ang: float = lerp(start_angle, end_angle, t)
		var lx: float = cx_local + cos(ang) * rw
		var ly: float = cy_local - sin(ang) * rh
		var pt: Vector2 = position + axis * lx + perp * ly
		if i > 0:
			canvas.draw_line(prev, pt, color, max(1.0, line_width), true)
		prev = pt


# ----- per-type leaf renderers (port of ArenaLeafShield._draw_leaf_type_*) ----

func _draw_leaf_type_0(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		w: float, h: float, depth_factor: float) -> void:
	var half_w: float = w * 0.5
	var half_h: float = h * 0.5
	var base_gold := Color(180.0 / 255.0 * depth_factor, 140.0 / 255.0 * depth_factor, 50.0 / 255.0 * depth_factor)
	var mid_gold := Color(220.0 / 255.0 * depth_factor, 180.0 / 255.0 * depth_factor, 60.0 / 255.0 * depth_factor)
	var light_gold := Color(255.0 / 255.0 * depth_factor, 215.0 / 255.0 * depth_factor, 80.0 / 255.0 * depth_factor)
	var highlight := Color(255.0 / 255.0 * depth_factor, 240.0 / 255.0 * depth_factor, 150.0 / 255.0 * depth_factor)
	var vein_color := Color(150.0 / 255.0 * depth_factor, 110.0 / 255.0 * depth_factor, 30.0 / 255.0 * depth_factor)
	var w_third: float = floor(w / 3.0)
	var w_fifth: float = floor(w / 5.0)
	var h_half: float = floor(h * 0.5)
	var h_quarter: float = floor(h * 0.25)
	var h_three_q: float = floor(h * 0.75)
	# Outer shadow / main leaf body.
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h, 1.0, 1.0, w - 2.0, h - 2.0, base_gold)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h, 2.0, 2.0, w - 4.0, h - 4.0, mid_gold)
	# Stacked highlight near stem-side upper quadrant.
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h, 3.0, 2.0, w_third, h_half, light_gold)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h, 4.0, 3.0, w_fifth, floor(h / 3.0), highlight)
	# Central spine.
	_draw_pyg_line(canvas, position, axis, perp, half_w, half_h, w - 2.0, h_half, 3.0, h_half, vein_color, 2.0)
	# Lateral veins.
	for i in range(3):
		var offset: float = float(i + 1) * w_fifth
		_draw_pyg_line(canvas, position, axis, perp, half_w, half_h,
			w - offset, h_half, w - offset - 4.0, h_quarter + 1.0, vein_color, 1.0)
		_draw_pyg_line(canvas, position, axis, perp, half_w, half_h,
			w - offset, h_half, w - offset - 4.0, h_three_q - 1.0, vein_color, 1.0)


func _draw_leaf_type_1(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		w: float, h: float, depth_factor: float) -> void:
	var half_w: float = w * 0.5
	var half_h: float = h * 0.5
	var base_gold := Color(170.0 / 255.0 * depth_factor, 130.0 / 255.0 * depth_factor, 40.0 / 255.0 * depth_factor)
	var mid_gold := Color(210.0 / 255.0 * depth_factor, 170.0 / 255.0 * depth_factor, 55.0 / 255.0 * depth_factor)
	var light_gold := Color(245.0 / 255.0 * depth_factor, 205.0 / 255.0 * depth_factor, 70.0 / 255.0 * depth_factor)
	var highlight := Color(255.0 / 255.0 * depth_factor, 235.0 / 255.0 * depth_factor, 140.0 / 255.0 * depth_factor)
	var vein_color := Color(140.0 / 255.0 * depth_factor, 100.0 / 255.0 * depth_factor, 25.0 / 255.0 * depth_factor)
	# Lance-shaped outer polygon.
	var pts := PackedVector2Array([
		Vector2(w - 2.0, h * 0.5),
		Vector2(w * 2.0 / 3.0, h * 0.2),
		Vector2(w * 0.25, h * 0.25),
		Vector2(3.0, h * 0.5),
		Vector2(w * 0.25, h * 0.75),
		Vector2(w * 2.0 / 3.0, h * 0.8),
	])
	_draw_pyg_polygon(canvas, position, axis, perp, half_w, half_h, pts, base_gold)
	# Inner polygon (scaled toward center).
	var inner := PackedVector2Array()
	inner.resize(pts.size())
	for i in pts.size():
		var p: Vector2 = pts[i]
		inner[i] = Vector2(p.x * 0.9 + w * 0.05, p.y * 0.85 + h * 0.075)
	_draw_pyg_polygon(canvas, position, axis, perp, half_w, half_h, inner, mid_gold)
	# Highlight stack.
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h,
		floor(w / 3.0), floor(h * 0.25), floor(w * 0.25), floor(h / 3.0), light_gold)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h,
		floor(w / 3.0) + 2.0, floor(h * 0.25) + 2.0, floor(w / 6.0), floor(h * 0.2), highlight)
	# Central spine.
	_draw_pyg_line(canvas, position, axis, perp, half_w, half_h,
		w - 3.0, floor(h * 0.5), 5.0, floor(h * 0.5), vein_color, 2.0)


func _draw_leaf_type_2(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		w: float, h: float, depth_factor: float) -> void:
	var half_w: float = w * 0.5
	var half_h: float = h * 0.5
	var base_gold := Color(190.0 / 255.0 * depth_factor, 150.0 / 255.0 * depth_factor, 55.0 / 255.0 * depth_factor)
	var mid_gold := Color(225.0 / 255.0 * depth_factor, 185.0 / 255.0 * depth_factor, 65.0 / 255.0 * depth_factor)
	var light_gold := Color(255.0 / 255.0 * depth_factor, 220.0 / 255.0 * depth_factor, 90.0 / 255.0 * depth_factor)
	var highlight := Color(255.0 / 255.0 * depth_factor, 245.0 / 255.0 * depth_factor, 160.0 / 255.0 * depth_factor)
	var vein_color := Color(155.0 / 255.0 * depth_factor, 115.0 / 255.0 * depth_factor, 35.0 / 255.0 * depth_factor)
	var edge_color := Color(130.0 / 255.0 * depth_factor, 95.0 / 255.0 * depth_factor, 25.0 / 255.0 * depth_factor)
	# Rounded outline.
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h, 0.0, 0.0, w, h, edge_color)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h, 1.0, 1.0, w - 2.0, h - 2.0, base_gold)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h, 3.0, 2.0, w - 6.0, h - 4.0, mid_gold)
	# Highlights.
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h,
		floor(w * 0.25), floor(h * 0.2), floor(w / 3.0), floor(h * 0.5), light_gold)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h,
		floor(w * 0.25) + 2.0, floor(h * 0.2) + 2.0, floor(w * 0.2), floor(h / 3.0), highlight)
	# Soft veins: arc then central spine.
	_draw_pyg_arc(canvas, position, axis, perp, half_w, half_h,
		2.0, floor(h * 0.25), w - 4.0, floor(h * 0.5), PI, 0.0, vein_color, 2.0, 16)
	_draw_pyg_line(canvas, position, axis, perp, half_w, half_h,
		w - 2.0, floor(h * 0.5), 4.0, floor(h * 0.5), vein_color, 1.0)


func _draw_leaf_type_3(canvas: CanvasItem, position: Vector2, axis: Vector2, perp: Vector2,
		w: float, h: float, depth_factor: float) -> void:
	var half_w: float = w * 0.5
	var half_h: float = h * 0.5
	var base_gold := Color(175.0 / 255.0 * depth_factor, 135.0 / 255.0 * depth_factor, 45.0 / 255.0 * depth_factor)
	var mid_gold := Color(215.0 / 255.0 * depth_factor, 175.0 / 255.0 * depth_factor, 60.0 / 255.0 * depth_factor)
	var light_gold := Color(250.0 / 255.0 * depth_factor, 210.0 / 255.0 * depth_factor, 75.0 / 255.0 * depth_factor)
	var highlight := Color(255.0 / 255.0 * depth_factor, 238.0 / 255.0 * depth_factor, 145.0 / 255.0 * depth_factor)
	var vein_color := Color(145.0 / 255.0 * depth_factor, 105.0 / 255.0 * depth_factor, 28.0 / 255.0 * depth_factor)
	# Serrated outer polygon (matches ArenaLeafShield._draw_leaf_type_3 sweep).
	var pts := PackedVector2Array()
	var num_teeth := 6
	for i in (num_teeth * 2 + 1):
		var t: float = float(i) / float(num_teeth * 2)
		var x: float = w - 2.0 - (w - 4.0) * t
		var y_offset: float = 0.0
		if i % 2 != 0:
			if i < num_teeth:
				y_offset = h / 8.0
			else:
				y_offset = -h / 8.0
		var base_y: float = h * 0.5
		var curve: float = sin(t * PI) * (h / 3.0)
		var y: float
		if i <= num_teeth:
			y = base_y - curve + y_offset
		else:
			y = base_y + curve + y_offset
		y = clamp(y, 1.0, h - 1.0)
		pts.append(Vector2(x, y))
	_draw_pyg_polygon(canvas, position, axis, perp, half_w, half_h, pts, base_gold)
	# Inner highlight stack.
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h,
		floor(w / 6.0), floor(h * 0.25), floor(w * 2.0 / 3.0), floor(h * 0.5), mid_gold)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h,
		floor(w * 0.25), floor(h * 0.25), floor(w / 3.0), floor(h / 3.0), light_gold)
	_draw_pyg_ellipse(canvas, position, axis, perp, half_w, half_h,
		floor(w * 0.25) + 3.0, floor(h * 0.25) + 2.0, floor(w * 0.2), floor(h * 0.2), highlight)
	# Central spine.
	_draw_pyg_line(canvas, position, axis, perp, half_w, half_h,
		w - 3.0, floor(h * 0.5), 5.0, floor(h * 0.5), vein_color, 2.0)
	# Lateral veins.
	for i in range(2):
		var offset: float = float(i + 1) * floor(w * 0.25)
		_draw_pyg_line(canvas, position, axis, perp, half_w, half_h,
			w - offset, floor(h * 0.5), w - offset - 5.0, floor(h / 3.0), vein_color, 1.0)
		_draw_pyg_line(canvas, position, axis, perp, half_w, half_h,
			w - offset, floor(h * 0.5), w - offset - 5.0, floor(h * 2.0 / 3.0), vein_color, 1.0)


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2, effect_lod_scale: float = 1.0) -> void:
	var stride: int = _get_particle_render_stride(effect_lod_scale)
	for i in range(particles.size()):
		if stride > 1 and i % stride != 0:
			continue
		var particle: Dictionary = particles[i]
		var life: float = max(0.0, float(particle.get("life", 0.0)))
		var max_life: float = max(1.0, float(particle.get("max_life", 40.0)))
		var ratio: float = clamp(life / max_life, 0.0, 1.0)
		if ratio <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var color: Color = particle.get("color", Color(1.0, 220.0 / 255.0, 100.0 / 255.0))
		var radius: float = max(1.0, life / 8.0)
		canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.86 * ratio))


func _is_lod_active(effect_lod_scale: float) -> bool:
	return effect_lod_scale < LOD_ACTIVE_THRESHOLD


func _is_severe_lod_active(effect_lod_scale: float) -> bool:
	return effect_lod_scale <= SEVERE_LOD_ACTIVE_THRESHOLD


func _get_particle_render_stride(effect_lod_scale: float) -> int:
	if _is_severe_lod_active(effect_lod_scale):
		return SEVERE_LOD_PARTICLE_STRIDE
	if _is_lod_active(effect_lod_scale):
		return LOD_PARTICLE_STRIDE
	return 1


func _sort_leaf_draw_order(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("depth", 0.0)) < float(b.get("depth", 0.0))


func _play_hit_feedback(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		audio = _get_instance(deps.get("registry", null), "game_audio")
	if audio != null:
		if audio.has_method("play_leaf_shield"):
			audio.play_leaf_shield()
		elif audio.has_method("play_wall_hit"):
			audio.play_wall_hit()
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("trigger_hit_flash"):
		feedback.trigger_hit_flash()


func _read_player_center(owner: Object) -> Vector2:
	if owner == null:
		return owner_center
	var player_pos: Variant = owner.get("player_pos")
	var player_size := DEFAULT_PLAYER_SIZE
	var width_value: Variant = owner.get("player_paddle_width")
	var height_value: Variant = owner.get("player_paddle_height")
	if width_value != null:
		player_size.x = max(1.0, float(width_value))
	if height_value != null:
		player_size.y = max(1.0, float(height_value))
	if player_pos is Vector2:
		return player_pos + player_size * 0.5
	return Vector2(380.0, FIELD_HEIGHT - player_size.y * 0.5)


func _get_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", DEFAULT_PLAYER_SIZE), DEFAULT_PLAYER_SIZE)
	if player_pos == Vector2.ZERO:
		return owner_center
	return player_pos + player_size * 0.5


func _get_ball_radius(context: Dictionary) -> float:
	var default_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	return max(1.0, max(float(context.get("ball_render_radius", default_radius)), default_radius))


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
