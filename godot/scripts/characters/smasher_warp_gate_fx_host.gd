extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const MAX_PORTAL_NODES := 10
const SHARD_COUNT := 8
const ARC_SEGMENTS := 18
const BASE_SIZE := 240.0
const OPEN_SCALE_DURATION_SEC := 0.34
const OPEN_BURST_DURATION_SEC := 0.62
const OPEN_BRIGHTNESS_DURATION_SEC := 0.42
const OPEN_BURST_RING_THICKNESS := 0.12

var pulse_value := 0.0
var breath_value := 0.0
var elapsed_sec := 0.0
var portal_states: Array[Dictionary] = []

var _core_quads: Array[ColorRect] = []
var _aura_particles: Array[GPUParticles2D] = []
var _spark_particles: Array[GPUParticles2D] = []
var _streak_particles: Array[GPUParticles2D] = []
var _core_materials: Array[ShaderMaterial] = []
var _additive_material: CanvasItemMaterial = null
var _pulse_tween: Tween = null
var _breath_tween: Tween = null
var _slot_last_spawn_msec: Array[int] = []
var _slot_open_msec: Array[int] = []


static func prewarm_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	_build_portal_core_material()
	_build_aura_particle_material()
	_build_spark_particle_material()
	_build_streak_particle_material()


func _ready() -> void:
	z_as_relative = false
	z_index = 14
	_additive_material = _make_additive_material()
	_start_tweens()
	set_process(false)
	set_active(false)


func sync_state(next_portal_states: Array, active: bool) -> void:
	portal_states = _coerce_portal_states(next_portal_states)
	_ensure_portal_slot_count(portal_states.size())
	set_active(active and not portal_states.is_empty())
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_portal_slots()
	_update_core_uniforms()
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if not active:
		for particles in _aura_particles:
			particles.emitting = false
		for particles in _spark_particles:
			particles.emitting = false
		for particles in _streak_particles:
			particles.emitting = false
		for quad in _core_quads:
			quad.visible = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null
	if free_self:
		queue_free()


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed_sec += delta
	_update_core_uniforms()
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	for slot in range(portal_states.size()):
		_draw_portal_pieces(slot, portal_states[slot])


func _ensure_portal_slot_count(count: int) -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	var target_count: int = clampi(count, 0, MAX_PORTAL_NODES)
	while _core_quads.size() < target_count:
		var quad := ColorRect.new()
		quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quad.color = Color.WHITE
		quad.material = _build_portal_core_material()
		quad.visible = false
		add_child(quad)
		_core_quads.append(quad)
		_core_materials.append(quad.material as ShaderMaterial)

		var aura := GPUParticles2D.new()
		aura.amount = 32
		aura.lifetime = 0.72
		aura.one_shot = false
		aura.explosiveness = 0.0
		aura.randomness = 0.78
		aura.fixed_fps = 60
		aura.local_coords = true
		aura.visibility_rect = Rect2(-180.0, -220.0, 360.0, 440.0)
		aura.texture = ImpactFlareTextureCache.get_glow_texture()
		aura.material = _additive_material
		aura.process_material = _build_aura_particle_material()
		aura.emitting = false
		add_child(aura)
		_aura_particles.append(aura)

		var sparks := GPUParticles2D.new()
		sparks.amount = 18
		sparks.lifetime = 0.38
		sparks.one_shot = false
		sparks.explosiveness = 0.16
		sparks.randomness = 0.86
		sparks.fixed_fps = 60
		sparks.local_coords = true
		sparks.visibility_rect = Rect2(-170.0, -220.0, 340.0, 440.0)
		sparks.texture = ImpactFlareTextureCache.get_sparkle_texture()
		sparks.material = _additive_material
		sparks.process_material = _build_spark_particle_material()
		sparks.emitting = false
		add_child(sparks)
		_spark_particles.append(sparks)

		var streaks := GPUParticles2D.new()
		streaks.amount = 22
		streaks.lifetime = 0.62
		streaks.one_shot = false
		streaks.explosiveness = 0.0
		streaks.randomness = 0.92
		streaks.fixed_fps = 60
		streaks.local_coords = true
		streaks.visibility_rect = Rect2(-260.0, -300.0, 520.0, 600.0)
		streaks.texture = ImpactFlareTextureCache.get_sparkle_texture()
		streaks.material = _additive_material
		streaks.process_material = _build_streak_particle_material()
		streaks.emitting = false
		add_child(streaks)
		_streak_particles.append(streaks)

		_slot_last_spawn_msec.append(0)
		_slot_open_msec.append(-1)


func _start_tweens() -> void:
	if not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "pulse_value", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "pulse_value", 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = create_tween()
	_breath_tween.set_loops()
	_breath_tween.tween_property(self, "breath_value", 1.0, 0.86).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(self, "breath_value", 0.0, 0.74).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _apply_portal_slots() -> void:
	var now_msec: int = Time.get_ticks_msec()
	for slot in range(_core_quads.size()):
		var slot_active: bool = slot < portal_states.size()
		_core_quads[slot].visible = slot_active
		_aura_particles[slot].emitting = slot_active
		_spark_particles[slot].emitting = slot_active
		_streak_particles[slot].emitting = slot_active
		if not slot_active:
			_slot_last_spawn_msec[slot] = 0
			_slot_open_msec[slot] = -1
			continue
		var state: Dictionary = portal_states[slot]
		var spawn_msec: int = int(state.get("spawn_msec", 0))
		if spawn_msec != _slot_last_spawn_msec[slot]:
			_slot_last_spawn_msec[slot] = spawn_msec
			_slot_open_msec[slot] = now_msec
		_apply_portal_slot(slot, state)


func _apply_portal_slot(slot: int, state: Dictionary) -> void:
	var center: Vector2 = _as_vector2(state.get("screen_center", Vector2.ZERO), Vector2.ZERO)
	var size: float = max(1.0, float(state.get("screen_size", BASE_SIZE)))
	var side: int = int(state.get("side", 1))
	var alpha: float = clamp(float(state.get("alpha", 1.0)), 0.0, 1.0)
	var progress: float = clamp(float(state.get("progress", 0.0)), 0.0, 1.0)
	var tint: Color = _as_color(state.get("tint", Color(0.92, 0.45, 1.0, 0.88)), Color(0.92, 0.45, 1.0, 0.88))
	var hot: Color = _as_color(state.get("hot", Color(1.0, 0.84, 0.36)), Color(1.0, 0.84, 0.36))
	var open_scale: float = _get_slot_open_scale(slot)
	var open_brightness: float = _get_slot_open_brightness(slot)
	var core_size := Vector2(size * 0.64, size * 0.98) * open_scale
	var quad: ColorRect = _core_quads[slot]
	quad.position = center - core_size * 0.5
	quad.size = core_size
	@warning_ignore("shadowed_variable_base_class")
	var material: ShaderMaterial = _core_materials[slot]
	if material != null:
		material.set_shader_parameter("elapsed", elapsed_sec)
		material.set_shader_parameter("pulse", pulse_value)
		material.set_shader_parameter("breath", breath_value)
		material.set_shader_parameter("portal_alpha", alpha)
		material.set_shader_parameter("side", -1.0 if side < 0 else 1.0)
		material.set_shader_parameter("burst_progress", progress)
		material.set_shader_parameter("open_brightness", open_brightness)
		material.set_shader_parameter("tint_color", Vector4(tint.r, tint.g, tint.b, alpha))
		material.set_shader_parameter("hot_color", Vector4(hot.r, hot.g, hot.b, 1.0))

	var particle_scale := Vector2(size / BASE_SIZE * 0.60, size / BASE_SIZE * 1.05)
	_aura_particles[slot].position = center
	_aura_particles[slot].scale = particle_scale
	_spark_particles[slot].position = center
	_spark_particles[slot].scale = particle_scale
	_streak_particles[slot].position = center
	_streak_particles[slot].scale = particle_scale

	var aura_mat: ParticleProcessMaterial = _aura_particles[slot].process_material
	if aura_mat != null:
		aura_mat.color = Color(tint.r, tint.g, tint.b, alpha * (0.42 + pulse_value * 0.14 + open_brightness * 0.30))
	var spark_mat: ParticleProcessMaterial = _spark_particles[slot].process_material
	if spark_mat != null:
		spark_mat.color = Color(hot.r, hot.g, hot.b, alpha * (0.62 + pulse_value * 0.18 + open_brightness * 0.40))
	var streak_mat: ParticleProcessMaterial = _streak_particles[slot].process_material
	if streak_mat != null:
		streak_mat.color = Color(tint.r, tint.g, tint.b, alpha * (0.34 + pulse_value * 0.12 + open_brightness * 0.28))


func _update_core_uniforms() -> void:
	for slot in range(min(portal_states.size(), _core_materials.size())):
		@warning_ignore("shadowed_variable_base_class")
		var material: ShaderMaterial = _core_materials[slot]
		if material == null:
			continue
		material.set_shader_parameter("elapsed", elapsed_sec)
		material.set_shader_parameter("pulse", pulse_value)
		material.set_shader_parameter("breath", breath_value)
		material.set_shader_parameter("open_brightness", _get_slot_open_brightness(slot))


func _get_slot_open_scale(slot: int) -> float:
	if slot < 0 or slot >= _slot_open_msec.size():
		return 1.0
	var open_msec: int = _slot_open_msec[slot]
	if open_msec < 0:
		return 1.0
	var elapsed: float = float(Time.get_ticks_msec() - open_msec) / 1000.0
	if elapsed >= OPEN_SCALE_DURATION_SEC:
		return 1.0
	return Tween.interpolate_value(0.0, 1.0, elapsed, OPEN_SCALE_DURATION_SEC, Tween.TRANS_BACK, Tween.EASE_OUT)


func _get_slot_open_burst_radius(slot: int) -> float:
	if slot < 0 or slot >= _slot_open_msec.size():
		return 0.0
	var open_msec: int = _slot_open_msec[slot]
	if open_msec < 0:
		return 0.0
	var elapsed: float = float(Time.get_ticks_msec() - open_msec) / 1000.0
	if elapsed >= OPEN_BURST_DURATION_SEC:
		return 0.0
	return Tween.interpolate_value(0.0, 1.0, elapsed, OPEN_BURST_DURATION_SEC, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _get_slot_open_burst_alpha(slot: int) -> float:
	if slot < 0 or slot >= _slot_open_msec.size():
		return 0.0
	var open_msec: int = _slot_open_msec[slot]
	if open_msec < 0:
		return 0.0
	var elapsed: float = float(Time.get_ticks_msec() - open_msec) / 1000.0
	if elapsed >= OPEN_BURST_DURATION_SEC:
		return 0.0
	return Tween.interpolate_value(1.0, -1.0, elapsed, OPEN_BURST_DURATION_SEC, Tween.TRANS_CUBIC, Tween.EASE_OUT)


func _get_slot_open_brightness(slot: int) -> float:
	if slot < 0 or slot >= _slot_open_msec.size():
		return 0.0
	var open_msec: int = _slot_open_msec[slot]
	if open_msec < 0:
		return 0.0
	var elapsed: float = float(Time.get_ticks_msec() - open_msec) / 1000.0
	if elapsed >= OPEN_BRIGHTNESS_DURATION_SEC:
		return 0.0
	return Tween.interpolate_value(1.0, -1.0, elapsed, OPEN_BRIGHTNESS_DURATION_SEC, Tween.TRANS_EXPO, Tween.EASE_OUT)


func _get_slot_inflow_progress(slot: int) -> float:
	# 0.0 = just-opened (shards far out), 1.0 = settled into orbit (steady state forever).
	if slot < 0 or slot >= _slot_open_msec.size():
		return 1.0
	var open_msec: int = _slot_open_msec[slot]
	if open_msec < 0:
		return 1.0
	var elapsed: float = float(Time.get_ticks_msec() - open_msec) / 1000.0
	if elapsed >= OPEN_BURST_DURATION_SEC:
		return 1.0
	return Tween.interpolate_value(0.0, 1.0, elapsed, OPEN_BURST_DURATION_SEC, Tween.TRANS_CUBIC, Tween.EASE_OUT)


func _draw_portal_pieces(slot: int, state: Dictionary) -> void:
	var center: Vector2 = _as_vector2(state.get("screen_center", Vector2.ZERO), Vector2.ZERO)
	var size: float = max(1.0, float(state.get("screen_size", BASE_SIZE)))
	var side: int = int(state.get("side", 1))
	var alpha: float = clamp(float(state.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= 0.0:
		_draw_open_burst_ring(slot, center, size, state)
		return
	var progress: float = clamp(float(state.get("progress", 0.0)), 0.0, 1.0)
	var tint: Color = _as_color(state.get("tint", Color(0.92, 0.45, 1.0, 0.88)), Color(0.92, 0.45, 1.0, 0.88))
	var hot: Color = _as_color(state.get("hot", Color(1.0, 0.84, 0.36)), Color(1.0, 0.84, 0.36))
	var cyan := Color(0.36, 0.92, 1.0)
	var radius_size := Vector2(size * 0.24, size * 0.43)
	var side_sign: float = -1.0 if side < 0 else 1.0
	var local_phase: float = elapsed_sec * 1.65 + side_sign * 0.8 + progress * 2.2

	ImpactFlareTextureCache.draw_glow(self, center, size * (0.52 + breath_value * 0.05), tint, alpha * 0.10)
	_draw_oval_ring(center, radius_size * (0.76 + breath_value * 0.035), cyan, alpha * 0.16)
	_draw_orbit_shards(center, radius_size, side_sign, tint, hot, alpha, local_phase)
	_draw_swirl_arcs(center, radius_size, side_sign, tint, cyan, hot, alpha, local_phase)

	var throat_x: float = side_sign * radius_size.x * (0.32 + 0.05 * sin(local_phase * 1.6))
	draw_line(
		center + Vector2(throat_x, -radius_size.y * 0.86),
		center + Vector2(throat_x, radius_size.y * 0.86),
		Color(hot.r, hot.g, hot.b, alpha * 0.68),
		4.0 + pulse_value * 3.4,
		true
	)

	_draw_open_burst_ring(slot, center, size, state)


func _draw_open_burst_ring(slot: int, center: Vector2, size: float, state: Dictionary) -> void:
	var burst_radius: float = _get_slot_open_burst_radius(slot)
	var burst_alpha: float = _get_slot_open_burst_alpha(slot)
	if burst_radius <= 0.0 or burst_alpha <= 0.001:
		return
	var tint: Color = _as_color(state.get("tint", Color(0.92, 0.45, 1.0, 0.88)), Color(0.92, 0.45, 1.0, 0.88))
	var hot: Color = _as_color(state.get("hot", Color(1.0, 0.84, 0.36)), Color(1.0, 0.84, 0.36))
	var base_radius := Vector2(size * 0.30, size * 0.50)
	var ring_radius: Vector2 = base_radius * (0.55 + burst_radius * 1.45)
	var ring_color: Color = tint.lerp(hot, 0.45)
	_draw_oval_ring(center, ring_radius, Color(ring_color.r, ring_color.g, ring_color.b), burst_alpha * 0.55)
	# Inner faster echo for extra punch.
	var inner_radius: Vector2 = base_radius * (0.40 + burst_radius * 0.95)
	_draw_oval_ring(center, inner_radius, Color(hot.r, hot.g, hot.b), burst_alpha * 0.35)


func _draw_orbit_shards(
	center: Vector2,
	radius_size: Vector2,
	side_sign: float,
	tint: Color,
	hot: Color,
	alpha: float,
	local_phase: float
) -> void:
	for i in range(SHARD_COUNT):
		var fi: float = float(i)
		var angle: float = local_phase * (0.85 + float(i % 3) * 0.12) * side_sign + fi * TAU / float(SHARD_COUNT)
		var length: float = 8.0 + float(i % 4) * 3.0 + pulse_value * 5.0
		var orbit: float = 0.78 + 0.10 * sin(local_phase + fi)
		var pos := center + Vector2(cos(angle) * radius_size.x * orbit, sin(angle) * radius_size.y * orbit)
		var tangent := Vector2(-sin(angle), cos(angle)) * side_sign
		var color: Color = hot if i % 3 == 0 else tint
		draw_line(
			pos - tangent * length * 0.45,
			pos + tangent * length * 0.55,
			Color(color.r, color.g, color.b, alpha * (0.30 + pulse_value * 0.18)),
			1.2 + pulse_value * 0.8,
			true
		)


func _draw_swirl_arcs(
	center: Vector2,
	radius_size: Vector2,
	side_sign: float,
	tint: Color,
	cyan: Color,
	hot: Color,
	alpha: float,
	local_phase: float
) -> void:
	for layer in range(4):
		var lf: float = float(layer)
		@warning_ignore("shadowed_variable_base_class")
		var scale: float = 0.42 + lf * 0.15
		var start: float = local_phase * (1.15 + lf * 0.12) * side_sign + lf * 1.38
		var sweep: float = PI * (0.34 + lf * 0.045) * side_sign
		var color: Color = tint.lerp(hot if layer % 2 == 0 else cyan, 0.42)
		_draw_ellipse_arc(
			center,
			radius_size * scale,
			start,
			sweep,
			Color(color.r, color.g, color.b, alpha * (0.34 - lf * 0.045)),
			max(1.0, 2.2 - lf * 0.24)
		)


func _draw_ellipse_arc(center: Vector2, radius_size: Vector2, start_angle: float, sweep: float, color: Color, width: float) -> void:
	if color.a <= 0.0:
		return
	var points := PackedVector2Array()
	for i in range(ARC_SEGMENTS + 1):
		var ratio: float = float(i) / float(ARC_SEGMENTS)
		var angle: float = start_angle + sweep * ratio
		points.append(center + Vector2(cos(angle) * radius_size.x, sin(angle) * radius_size.y))
	draw_polyline(points, color, width, true)


func _draw_oval_ring(center: Vector2, radius_size: Vector2, color: Color, alpha: float) -> void:
	var ring_ratio: float = max(0.001, float(ImpactShockwaveTextureCache.RING_RADIUS_RATIO))
	var half_extents: Vector2 = radius_size / ring_ratio
	draw_texture_rect(
		ImpactShockwaveTextureCache.get_full_ring_texture(),
		Rect2(center - half_extents, half_extents * 2.0),
		false,
		Color(color.r, color.g, color.b, alpha)
	)


static func _build_portal_core_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float breath = 0.0;
uniform float portal_alpha = 1.0;
uniform float side = 1.0;
uniform float burst_progress = 0.0;
uniform float open_brightness = 0.0;
uniform vec4 tint_color = vec4(0.92, 0.45, 1.0, 1.0);
uniform vec4 hot_color = vec4(1.0, 0.84, 0.36, 1.0);

float ring_band_at(float r, float center, float width) {
	return smoothstep(width, 0.0, abs(r - center));
}

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	p.x *= 1.72;
	float angle_raw = atan(p.y, p.x);
	vec2 dir = vec2(cos(angle_raw), sin(angle_raw));

	// Subtle radial refraction warp on the inner field — gives a depth bend.
	float refract_amp = 0.018 + pulse * 0.014;
	float refract_phase = sin(angle_raw * 3.0 - elapsed * 1.6) * refract_amp;
	vec2 p_warp = p + dir * refract_phase;
	float r = length(p_warp);
	float angle = atan(p_warp.y, p_warp.x);

	// Chromatic radial offset for the rim — R outside, B inside.
	float chroma = 0.022 + breath * 0.012;
	float r_red = length(p_warp - dir * chroma);
	float r_blue = length(p_warp + dir * chroma);

	// Envelope shapes.
	float outer = smoothstep(1.22, 0.10, r);
	float inner_void = smoothstep(0.14, 0.46, r);
	float core = smoothstep(0.20, 0.0, r) * (0.82 + pulse * 0.30);
	float core_pinpoint = smoothstep(0.07, 0.0, r);

	// Cinematic rim line — narrow, with chromatic ghost copies.
	float rim_main = ring_band_at(r, 0.985, 0.045) * (0.85 + pulse * 0.15);
	float rim_red = ring_band_at(r_red, 0.985, 0.062);
	float rim_blue = ring_band_at(r_blue, 0.985, 0.062);

	// Breathing inner ring.
	float ring_band = ring_band_at(r, 0.72 + breath * 0.05, 0.090);

	// Multi-octave swirl — two coarse + one detail.
	float spiral_a = sin(angle * 5.0 * side - elapsed * 4.2 + r * 13.0);
	float spiral_b = sin(angle * -7.0 * side + elapsed * 3.1 + r * 19.0);
	float spiral_c = sin(angle * 11.0 * side + elapsed * 5.5 + r * 27.0);
	float spiral = max(0.0, spiral_a) * 0.48
		+ max(0.0, spiral_b) * 0.30
		+ max(0.0, spiral_c) * 0.16;

	// Energy lanes (inward streaks).
	float lane_phase = fract(r * (3.4 + pulse * 0.50) + angle * 0.12 * side - elapsed * 0.86);
	float lane = smoothstep(0.36, 0.0, abs(lane_phase - 0.5));

	// Throat (tear-through-space slit on the wall side).
	float throat = smoothstep(0.085, 0.0, abs(p_warp.x - side * (0.58 + pulse * 0.05)))
		* smoothstep(1.02, 0.20, abs(p_warp.y));

	// Burst — open / wrap shockwave inside the disc.
	float burst = smoothstep(0.16, 0.0, abs(r - (0.36 + burst_progress * 0.52)))
		* (1.0 - burst_progress);

	float interior_alpha = inner_void * (
		spiral * 0.22
		+ lane * 0.18
		+ ring_band * 0.36
		+ throat * 0.40
		+ burst * 0.50
	);
	float rim_alpha = (rim_main + rim_red * 0.55 + rim_blue * 0.55) * 0.55;
	float core_alpha = core * 0.55 + core_pinpoint * 0.55;

	float alpha = outer * (interior_alpha + rim_alpha + core_alpha);
	alpha *= portal_alpha * (0.78 + pulse * 0.22 + open_brightness * 0.50);

	vec3 tint = tint_color.rgb;
	vec3 hot = hot_color.rgb;
	vec3 cyan = vec3(0.34, 0.92, 1.0);

	vec3 base = mix(tint, hot, clamp(throat * 0.80 + ring_band * 0.30 + burst * 0.55 + core * 0.45, 0.0, 1.0));
	base = mix(base, cyan, clamp(max(0.0, spiral_b) * 0.22 + lane * 0.16, 0.0, 0.42));

	// Apply chromatic offset only on the rim — warm shift outside, cool shift inside.
	vec3 rim_color = base;
	rim_color.r += rim_red * 0.50;
	rim_color.b += rim_blue * 0.50;
	float rim_blend = smoothstep(0.0, 0.02, rim_alpha);
	vec3 color = mix(base, rim_color, rim_blend);

	// Hot core pinpoint — white-yellow flash at the very center.
	color = mix(color, mix(hot, vec3(1.0), 0.55), core_pinpoint * 0.75);

	// Activation flash boost — brief warm-white wash on the whole disc.
	color = mix(color, mix(hot, vec3(1.0), 0.40), open_brightness * 0.35 * outer);

	COLOR = vec4(color, clamp(alpha, 0.0, 0.95));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _build_aura_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 70.0
	mat.radial_accel_min = -75.0
	mat.radial_accel_max = 18.0
	mat.tangential_accel_min = -160.0
	mat.tangential_accel_max = 160.0
	mat.damping_min = 16.0
	mat.damping_max = 48.0
	mat.scale_min = 0.020
	mat.scale_max = 0.068
	mat.color = Color(0.92, 0.45, 1.0, 0.46)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 72.0
	return mat


static func _build_spark_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 36.0
	mat.initial_velocity_max = 118.0
	mat.radial_accel_min = 8.0
	mat.radial_accel_max = 80.0
	mat.tangential_accel_min = -110.0
	mat.tangential_accel_max = 110.0
	mat.damping_min = 26.0
	mat.damping_max = 92.0
	mat.scale_min = 0.018
	mat.scale_max = 0.054
	mat.color = Color(1.0, 0.84, 0.36, 0.72)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 64.0
	return mat


static func _build_streak_particle_material() -> ParticleProcessMaterial:
	# Inflow streaks — emit on a ring around the portal and accelerate
	# strongly inward, leaving long stretched trails toward the throat.
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 12.0
	# Negative radial accel pulls particles toward the emitter center.
	mat.radial_accel_min = -440.0
	mat.radial_accel_max = -260.0
	mat.tangential_accel_min = -40.0
	mat.tangential_accel_max = 40.0
	mat.damping_min = 0.0
	mat.damping_max = 14.0
	mat.scale_min = 0.030
	mat.scale_max = 0.085
	mat.color = Color(0.92, 0.45, 1.0, 0.42)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 165.0
	mat.emission_ring_inner_radius = 135.0
	mat.emission_ring_height = 0.0
	# Stretch particles along their motion vector for streak look.
	mat.particle_flag_align_y = false
	return mat


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _coerce_portal_states(next_portal_states: Array) -> Array[Dictionary]:
	var typed_states: Array[Dictionary] = []
	for state in next_portal_states:
		if state is Dictionary:
			typed_states.append((state as Dictionary).duplicate(false))
	return typed_states


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
