extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const TEAR_GAS_ICON_PATH := ActiveItemCatalog.TEAR_GAS_ICON_PATH
const TEAR_GAS_DRAW_SIZE := 36.0
const TEAR_GAS_RADIUS := 180.0
const TEAR_GAS_RADIUS_X := 240.0
const TEAR_GAS_ARMED_DELAY_FRAMES := 180.0
const TEAR_GAS_RENDER_PARTICLE_LIMIT := 16
const TEAR_GAS_RENDER_TOTAL_PARTICLE_LIMIT := 24
const TEAR_GAS_PARTICLE_ALPHA_CUTOFF := 0.012
const TEAR_GAS_PUFF_TEXTURE_SIZE := 96
const TEAR_GAS_BASE_HAZE_ALPHA_MULT := 0.22
const FILLED_ELLIPSE_SEGMENTS := 32

static var _tear_gas_puff_texture: ImageTexture = null
static var _filled_ellipse_mesh: ArrayMesh = null

var tear_gas_icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_tear_gas_icon_texture())
	_touch_texture(get_tear_gas_puff_texture())
	_get_filled_ellipse_mesh()


func draw_tear_gas_projectiles(canvas: CanvasItem, tear_gas_projectiles: Array, shake_offset: Vector2) -> void:
	if tear_gas_projectiles.is_empty():
		return
	get_tear_gas_puff_texture()
	var texture: Texture2D = get_tear_gas_icon_texture()
	var font: Font = ThemeDB.fallback_font
	for projectile_value in tear_gas_projectiles:
		if not (projectile_value is Dictionary):
			continue
		var projectile: Dictionary = projectile_value
		var center: Vector2 = _get_vector2(projectile, "position", Vector2.ZERO) + shake_offset
		if bool(projectile.get("arrived", false)) and not bool(projectile.get("emitted", false)):
			var timer_frames: float = clamp(float(projectile.get("timer_frames", 0.0)), 0.0, TEAR_GAS_ARMED_DELAY_FRAMES)
			var remaining: float = max(0.0, TEAR_GAS_ARMED_DELAY_FRAMES - timer_frames)
			var blink: bool = int(timer_frames / 12.0) % 2 == 0
			_draw_filled_ellipse(canvas, Rect2(center + Vector2(-17.0, 8.0), Vector2(34.0, 7.0)), Color(0.0, 0.0, 0.0, 0.32))
			if blink:
				canvas.draw_circle(center + Vector2(9.0, -6.0), 3.0, Color(0.92, 0.08, 0.04, 0.95))
			if texture != null:
				_draw_rotated_texture_region(
					canvas,
					texture,
					Rect2(Vector2.ZERO, texture.get_size()),
					center + Vector2(0.0, -4.0),
					Vector2(28.0, 28.0),
					0.0
				)
			else:
				draw_tear_gas_fallback(canvas, center + Vector2(0.0, -4.0), 0.0, 0.85)
			if font != null:
				var count_text: String = str(int(ceil(remaining / 60.0)))
				var font_size: int = 14
				var text_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
				canvas.draw_string(
					font,
					center + Vector2(-text_size.x * 0.5, -25.0),
					count_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					font_size,
					Color(0.90, 1.0, 0.82, 0.95)
				)
			continue

		_draw_projectile_trail(canvas, projectile.get("trail", []), shake_offset, 3.0, Color(150.0 / 255.0, 160.0 / 255.0, 145.0 / 255.0, 1.0), 0.24)

		var angle: float = float(projectile.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(TEAR_GAS_DRAW_SIZE, TEAR_GAS_DRAW_SIZE),
				angle
			)
		else:
			draw_tear_gas_fallback(canvas, center, angle, 1.0)


func draw_tear_gas_zones(canvas: CanvasItem, tear_gas_zones: Array, shake_offset: Vector2) -> void:
	if tear_gas_zones.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var remaining_particle_budget := TEAR_GAS_RENDER_TOTAL_PARTICLE_LIMIT
	for zone_value in tear_gas_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var radius_y: float = max(1.0, float(zone.get("radius", TEAR_GAS_RADIUS)))
		var radius_x: float = max(1.0, float(zone.get("radius_x", TEAR_GAS_RADIUS_X)))
		var opacity: float = clamp(float(zone.get("opacity", 0.0)), 0.0, 1.0)
		if opacity <= 0.0:
			continue
		var pulse: float = 0.5 + 0.5 * sin(float(now_msec) * 0.004)
		_draw_tear_gas_base_haze(canvas, center, radius_x, radius_y, opacity, pulse, now_msec)

		var particles: Array = zone.get("particles", [])
		var particle_count: int = particles.size()
		if remaining_particle_budget <= 0:
			continue
		var rendered_particle_count: int = min(particle_count, TEAR_GAS_RENDER_PARTICLE_LIMIT, remaining_particle_budget)
		for draw_index in range(rendered_particle_count):
			var particle_index: int = int(floor(float(draw_index) * float(particle_count) / float(rendered_particle_count)))
			var particle_value: Variant = particles[particle_index]
			if not (particle_value is Dictionary):
				continue
			_draw_tear_gas_particle(canvas, particle_value, shake_offset, opacity)
		remaining_particle_budget -= rendered_particle_count


func draw_tear_gas_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var body_top: Vector2 = _rotated_local(center, Vector2(0.0, -11.0 * scale), angle)
	var body_bottom: Vector2 = _rotated_local(center, Vector2(0.0, 11.0 * scale), angle)
	canvas.draw_line(body_top, body_bottom, Color(0.34, 0.36, 0.32, 1.0), max(5.0, 9.0 * scale))
	canvas.draw_line(body_top, body_bottom, Color(0.58, 0.62, 0.52, 0.95), max(2.0, 4.0 * scale))
	canvas.draw_circle(body_top, 5.0 * scale, Color(0.22, 0.24, 0.22, 1.0))
	canvas.draw_circle(body_bottom, 5.0 * scale, Color(0.20, 0.21, 0.18, 1.0))
	canvas.draw_circle(_rotated_local(center, Vector2(4.0 * scale, -5.0 * scale), angle), 2.0 * scale, Color(0.95, 0.08, 0.04, 0.95))


func get_tear_gas_icon_texture() -> Texture2D:
	if tear_gas_icon_texture == null:
		tear_gas_icon_texture = ProjectResourceLoader.load_texture(
			TEAR_GAS_ICON_PATH,
			"Missing tear gas icon at %s",
			"Failed to load tear gas icon at %s"
		)
	return tear_gas_icon_texture


func get_tear_gas_puff_texture() -> ImageTexture:
	if _tear_gas_puff_texture != null:
		return _tear_gas_puff_texture
	_tear_gas_puff_texture = _build_tear_gas_puff_texture()
	return _tear_gas_puff_texture


func _draw_projectile_trail(canvas: CanvasItem, trail: Array, shake_offset: Vector2, radius: float, color: Color, alpha_scale: float) -> void:
	var trail_count: int = trail.size()
	if trail_count <= 0:
		return
	var stride: int = 2 if trail_count > 5 else 1
	for i in range(0, trail_count, stride):
		var trail_pos: Variant = trail[i]
		if not (trail_pos is Vector2):
			continue
		var trail_point: Vector2 = trail_pos
		var alpha: float = float(i + 1) / float(trail_count) * alpha_scale
		canvas.draw_circle(trail_point + shake_offset, radius, Color(color.r, color.g, color.b, alpha))


func _draw_tear_gas_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2, zone_life: float) -> void:
	var life_frames: float = float(particle.get("life_frames", 0.0))
	var max_life_frames: float = max(1.0, float(particle.get("max_life_frames", 80.0)))
	var life_ratio: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
	if life_ratio <= 0.0 or zone_life <= 0.0:
		return
	var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var size: float = max(1.0, float(particle.get("size", 10.0)))
	var aspect: float = max(0.25, float(particle.get("aspect", 1.4)))
	var depth: float = clamp(float(particle.get("depth", 0.5)), 0.0, 1.0)
	var tone: int = int(particle.get("color_tone", particle.get("tone", 0)))
	var variant: int = int(particle.get("variant", 0))
	@warning_ignore("shadowed_global_identifier")
	var seed: int = _get_smoke_particle_seed(particle, center)
	var depth_alpha_mult: float = 0.6 + 0.4 * depth
	var main: Color = _get_tear_gas_smoke_tone(tone, 1, depth)
	var core: Color = _get_tear_gas_smoke_tone(tone, 2, depth)
	var particle_type: String = str(particle.get("type", "smoke_cloud"))
	if particle_type == "smoke_pillar":
		var alpha: float = min(zone_life, (150.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		_draw_tear_gas_layered_texture_puff(canvas, center, Vector2(max(3.0, size * aspect), max(3.0, size * 1.3)), seed + variant * 101, main, core, alpha, depth)
	elif particle_type == "smoke_wisp":
		var alpha: float = min(zone_life, (175.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		_draw_tear_gas_texture_puff(canvas, center, Vector2(max(1.0, size * 1.15), max(1.0, size * 0.88)), main, alpha * 0.9)
	elif particle_type == "smoke_tendril":
		var alpha: float = min(zone_life, (125.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.RIGHT)
		var stretch: float = clamp(velocity.length() * 0.22, 0.8, 1.55)
		_draw_tear_gas_texture_puff(canvas, center, Vector2(max(3.0, size * aspect * stretch), max(2.0, size * 0.82)), main, alpha * 0.88)
	else:
		var alpha: float = min(zone_life, (180.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		_draw_tear_gas_layered_texture_puff(canvas, center, Vector2(max(4.0, size * aspect), max(4.0, size)), seed + variant * 409, main, core, alpha, depth)


func _draw_tear_gas_base_haze(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, opacity: float, pulse: float, now_msec: int) -> void:
	var base_alpha: float = TEAR_GAS_BASE_HAZE_ALPHA_MULT * opacity
	if base_alpha <= 0.0:
		return
	# Diffuse ground-hugging haze built from feathered puff textures (NOT hard
	# mesh ellipses) so the cloud base reads as soft smoke instead of a flat,
	# stacked "glow disc". Each puff overlaps generously and stays low-alpha.
	var ground_tone: Color = _get_tear_gas_smoke_tone(0, 1, 0.40)
	_draw_tear_gas_texture_puff(
		canvas,
		center + Vector2(0.0, radius_y * 0.06),
		Vector2(radius_x * 0.74, radius_y * 0.34),
		ground_tone,
		base_alpha * 0.50
	)
	for i in range(3):
		@warning_ignore("shadowed_global_identifier")
		var seed := 7300 + i * 79
		var drift := Vector2(
			_stable_signed(seed, i, 0) * radius_x * 0.30 + sin(float(now_msec) * 0.0012 + float(i)) * 3.0,
			_stable_signed(seed, i, 1) * radius_y * 0.10
		)
		var rx: float = radius_x * (0.30 + 0.12 * _stable_unit(seed, i, 2))
		var ry: float = radius_y * (0.16 + 0.06 * _stable_unit(seed, i, 3))
		var tone: Color = _get_tear_gas_smoke_tone(i % 3, 1, 0.45 + pulse * 0.18)
		_draw_tear_gas_texture_puff(canvas, center + drift, Vector2(rx, ry), tone, base_alpha * (0.38 + 0.14 * pulse))


func _draw_tear_gas_layered_texture_puff(
	canvas: CanvasItem,
	center: Vector2,
	radius: Vector2,
	smoke_seed: int,
	main: Color,
	core: Color,
	alpha: float,
	depth: float
) -> void:
	if alpha <= 0.0:
		return
	_draw_tear_gas_texture_puff(canvas, center, radius, main, alpha * 0.9)
	if depth < 0.35:
		return
	var core_offset := Vector2(
		_stable_signed(smoke_seed, 0, 5) * radius.x * 0.16,
		_stable_signed(smoke_seed, 0, 6) * radius.y * 0.12
	)
	_draw_tear_gas_texture_puff(canvas, center + core_offset, radius * 0.46, core, alpha * 0.42)


func _draw_tear_gas_texture_puff(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, alpha: float) -> void:
	if alpha <= 0.0 or radius.x <= 0.5 or radius.y <= 0.5:
		return
	var texture: Texture2D = get_tear_gas_puff_texture()
	if texture == null:
		_draw_smoke_ellipse(canvas, center, radius.x, radius.y, Color(color.r, color.g, color.b, alpha))
		return
	var draw_size := Vector2(radius.x * 2.0, radius.y * 2.0)
	canvas.draw_texture_rect(
		texture,
		Rect2(center - draw_size * 0.5, draw_size),
		false,
		Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))
	)


static func _build_tear_gas_puff_texture() -> ImageTexture:
	var image: Image = Image.create(TEAR_GAS_PUFF_TEXTURE_SIZE, TEAR_GAS_PUFF_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(TEAR_GAS_PUFF_TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	for y in range(TEAR_GAS_PUFF_TEXTURE_SIZE):
		var dy: float = (float(y) - center_coord) / max_dist
		for x in range(TEAR_GAS_PUFF_TEXTURE_SIZE):
			var dx: float = (float(x) - center_coord) / max_dist
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			# Low-frequency angular turbulence so large puffs read as billowing
			# smoke lobes instead of a smooth radial disc. The dense core is left
			# untouched; only the body / rim falloff is broken up.
			var ang: float = atan2(dy, dx)
			var turbulence: float = 0.5
			turbulence += 0.22 * sin(ang * 3.0 + dist * 4.0)
			turbulence += 0.16 * sin(ang * 5.0 - dist * 6.5 + 1.7)
			turbulence += 0.12 * sin(ang * 8.0 + dist * 9.0 + 3.1)
			# Cartesian octave breaks the radial n-fold symmetry so the (always
			# axis-aligned) puff does not repeat an identical star across the cloud.
			turbulence += 0.16 * sin(dx * 6.3 + dy * 4.1 + 2.0)
			var lobe: float = clamp(0.70 + turbulence * 0.34, 0.52, 1.12)
			var core_alpha: float = pow(max(0.0, 1.0 - dist * 1.55), 2.2) * 0.82
			var body_alpha: float = pow(max(0.0, 1.0 - dist), 1.65) * 0.94 * lobe
			var rim_alpha: float = pow(max(0.0, 1.0 - abs(dist - 0.58) / 0.42), 2.6) * 0.12 * lobe
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clamp(core_alpha + body_alpha + rim_alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _draw_smoke_ellipse(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	if color.a <= 0.0 or radius_x <= 0.5 or radius_y <= 0.5:
		return
	_draw_filled_ellipse(canvas, Rect2(center - Vector2(radius_x, radius_y), Vector2(radius_x * 2.0, radius_y * 2.0)), color)


func _get_tear_gas_smoke_tone(tone: int, layer: int, depth: float) -> Color:
	# Tear-gas identity: predominantly pale chemical yellow-green haze (tone 0/1),
	# with a cooler neutral grey (tone 2) mixed in so the cloud never reads mono-green.
	var base := Color(168.0 / 255.0, 176.0 / 255.0, 150.0 / 255.0, 1.0)
	if tone == 1:
		# pale chemical yellow
		if layer == 0:
			base = Color(146.0 / 255.0, 142.0 / 255.0, 112.0 / 255.0, 1.0)
		elif layer == 1:
			base = Color(182.0 / 255.0, 176.0 / 255.0, 140.0 / 255.0, 1.0)
		else:
			base = Color(216.0 / 255.0, 210.0 / 255.0, 172.0 / 255.0, 1.0)
	elif tone == 2:
		# cool neutral grey (variation lane)
		if layer == 0:
			base = Color(124.0 / 255.0, 130.0 / 255.0, 132.0 / 255.0, 1.0)
		elif layer == 1:
			base = Color(158.0 / 255.0, 164.0 / 255.0, 164.0 / 255.0, 1.0)
		else:
			base = Color(188.0 / 255.0, 194.0 / 255.0, 194.0 / 255.0, 1.0)
	else:
		# primary pale yellow-green chemical haze
		if layer == 0:
			base = Color(132.0 / 255.0, 138.0 / 255.0, 116.0 / 255.0, 1.0)
		elif layer == 1:
			base = Color(168.0 / 255.0, 176.0 / 255.0, 150.0 / 255.0, 1.0)
		else:
			base = Color(206.0 / 255.0, 212.0 / 255.0, 182.0 / 255.0, 1.0)
	var depth_offset: float = -0.06 + 0.12 * clamp(depth, 0.0, 1.0)
	return Color(
		clamp(base.r + depth_offset, 0.0, 1.0),
		clamp(base.g + depth_offset, 0.0, 1.0),
		clamp(base.b + depth_offset, 0.0, 1.0),
		1.0
	)


func _get_smoke_particle_seed(particle: Dictionary, center: Vector2) -> int:
	@warning_ignore("shadowed_global_identifier")
	var seed: int = int(particle.get("seed", 0))
	if seed == 0:
		seed = int(abs(center.x * 31.0 + center.y * 17.0 + float(particle.get("variant", 0)) * 101.0 + float(particle.get("phase", 0.0)) * 1000.0))
	return seed


@warning_ignore("shadowed_global_identifier")
func _stable_unit(seed: int, index: int, channel: int) -> float:
	var value: float = sin(float(seed % 100000) * 12.9898 + float(index) * 78.233 + float(channel) * 37.719) * 43758.5453
	return fposmod(value, 1.0)


@warning_ignore("shadowed_global_identifier")
func _stable_signed(seed: int, index: int, channel: int) -> float:
	return _stable_unit(seed, index, channel) * 2.0 - 1.0


func _draw_filled_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if color.a <= 0.0 or rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var radius: Vector2 = rect.size * 0.5
	var center: Vector2 = rect.get_center()
	var transform := Transform2D(Vector2(radius.x, 0.0), Vector2(0.0, radius.y), center)
	canvas.draw_mesh(_get_filled_ellipse_mesh(), null, transform, color)


static func _get_filled_ellipse_mesh() -> ArrayMesh:
	if _filled_ellipse_mesh != null:
		return _filled_ellipse_mesh
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	for step in range(FILLED_ELLIPSE_SEGMENTS):
		var angle: float = TAU * float(step) / float(FILLED_ELLIPSE_SEGMENTS)
		vertices.append(Vector3(cos(angle), sin(angle), 0.0))
	for step in range(FILLED_ELLIPSE_SEGMENTS):
		indices.append(0)
		indices.append(step + 1)
		indices.append((step + 1) % FILLED_ELLIPSE_SEGMENTS + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_filled_ellipse_mesh = mesh
	return _filled_ellipse_mesh


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var angle: float = deg_to_rad(angle_degrees)
	var half_size: Vector2 = draw_size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(_rotated_local(center, corner, angle))
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, texture)


func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:
	return center + Vector2(
		local.x * cos(angle) - local.y * sin(angle),
		local.x * sin(angle) + local.y * cos(angle)
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_width()
