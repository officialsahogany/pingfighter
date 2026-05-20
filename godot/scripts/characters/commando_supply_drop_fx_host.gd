extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const QUAD_BASE_SIZE := 128.0
const SPARK_RAY_COUNT := 10

var pulse_value := 0.0
var elapsed_sec := 0.0

var _state: Dictionary = {}
var _core_quad: ColorRect = null
var _drop_particles: GPUParticles2D = null
var _crash_particles: GPUParticles2D = null
var _core_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _pulse_tween: Tween = null
var _last_signature := ""
var _last_anchor_source := ""

static var _core_shader: Shader = null
static var _assets_prewarmed := false


static func prewarm_assets() -> void:
	if _assets_prewarmed:
		return
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	_get_core_shader()
	_build_particle_process_material(Color(0.56, 0.92, 1.0, 0.68), 1.0, false)
	_build_particle_process_material(Color(1.0, 0.48, 0.12, 0.86), 1.0, true)
	_assets_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"shader_host_pipeline": _get_core_shader() != null,
		"gpu_particle_pipeline": true,
		"fx_host_shader_layers": 1,
		"fx_host_gpu_particle_layers": 2,
		"fx_host_texture_pieces_ready": (
			ImpactFlareTextureCache.get_glow_texture() != null
			and ImpactFlareTextureCache.get_burst_texture() != null
			and ImpactFlareTextureCache.get_sparkle_texture() != null
			and ImpactShockwaveTextureCache.get_full_ring_texture() != null
		),
	}


func _ready() -> void:
	var should_remain_active := visible and not _get_anchor().is_empty()
	z_as_relative = false
	z_index = 14
	_additive_material = _make_additive_material()
	_build_children()
	_start_pulse_tween()
	set_active(should_remain_active)
	if should_remain_active:
		_apply_state()
		queue_redraw()


func sync_state(
	snapshot: Dictionary,
	shake_offset: Vector2,
	active: bool,
	layout_context: Dictionary = {}
) -> void:
	if _core_quad == null:
		_build_children()
	if is_inside_tree() and (_pulse_tween == null or not _pulse_tween.is_valid()):
		_start_pulse_tween()
	_state = {
		"snapshot": snapshot.duplicate(false),
		"shake_offset": shake_offset,
		"game_offset": _get_vector2(layout_context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
		"render_scale": max(0.01, float(layout_context.get("render_scale", 1.0))),
	}
	set_active(active)
	if not active:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	# The battle playfield draw fanout drives this host through sync_state().
	# Keeping a detached _process callback active makes the FX run outside the
	# frame shell and shows up as engine-process gap in perf logs.
	set_process(false)
	if _core_quad != null:
		_core_quad.visible = active
	if _drop_particles != null:
		_drop_particles.emitting = active and _last_anchor_source in ["aircraft", "drop", "collectible"]
	if _crash_particles != null and not active:
		_crash_particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"shader_layers": 1 if _core_material != null else 0,
		"gpu_particle_layers": _get_gpu_particle_layer_count(),
		"texture_pieces_ready": bool(build_pipeline_status().get("fx_host_texture_pieces_ready", false)),
		"loop_tween_active": _pulse_tween != null and _pulse_tween.is_valid(),
		"last_signature": _last_signature,
		"anchor_source": _last_anchor_source,
	}


func _draw() -> void:
	if not visible:
		return
	var anchor: Dictionary = _get_anchor()
	if anchor.is_empty():
		return
	var source: String = str(anchor.get("source", "drop"))
	var color: Color = _get_color(anchor, "color", Color(0.56, 0.92, 1.0, 0.70))
	var secondary: Color = _get_color(anchor, "secondary", Color(1.0, 0.74, 0.28, 0.70))
	var radius: float = max(12.0, float(anchor.get("radius", 30.0)))
	var beat: float = 0.68 + pulse_value * 0.32
	ImpactFlareTextureCache.draw_glow(self, Vector2.ZERO, radius * 1.60, color, 0.10 * beat)
	if source == "explosion":
		ImpactShockwaveTextureCache.draw_full_ring(self, Vector2.ZERO, radius * (0.88 + pulse_value * 0.18), secondary, 0.26 * beat)
		ImpactFlareTextureCache.draw_burst(self, Vector2.ZERO, radius * 0.96, secondary, 0.18 * beat)
	elif source == "aircraft":
		ImpactShockwaveTextureCache.draw_full_ring(self, Vector2.ZERO, radius * (0.64 + pulse_value * 0.10), color, 0.10 * beat)
		_draw_scan_lines(radius, color, beat)
	else:
		ImpactShockwaveTextureCache.draw_full_ring(self, Vector2.ZERO, radius * (0.74 + pulse_value * 0.12), secondary, 0.18 * beat)
		ImpactFlareTextureCache.draw_sparkle(self, Vector2.ZERO, radius * 0.55, color, 0.18 * beat)
	for i in range(SPARK_RAY_COUNT):
		var angle: float = elapsed_sec * (1.0 + float(i % 3) * 0.16) + TAU * float(i) / float(SPARK_RAY_COUNT)
		var dir := Vector2(cos(angle), sin(angle))
		var inner: float = radius * (0.18 + 0.04 * pulse_value)
		var outer: float = radius * (0.50 + 0.16 * sin(elapsed_sec * 2.6 + float(i)))
		draw_line(dir * inner, dir * outer, Color(secondary.r, secondary.g, secondary.b, 0.10 * beat), 1.1, true)


func _draw_scan_lines(radius: float, color: Color, beat: float) -> void:
	for i in range(5):
		var y: float = -radius * 0.45 + float(i) * radius * 0.22
		var wobble: float = sin(elapsed_sec * 3.0 + float(i)) * radius * 0.05
		draw_line(Vector2(-radius * 0.72 + wobble, y), Vector2(radius * 0.72 + wobble, y), Color(color.r, color.g, color.b, 0.08 * beat), 1.0, true)


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _core_quad == null:
		_core_quad = ColorRect.new()
		_core_quad.name = "CommandoSupplyDropShaderCore"
		_core_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_core_quad.color = Color.WHITE
		_core_material = _build_core_shader_material()
		_core_quad.material = _core_material
		add_child(_core_quad)
	if _drop_particles == null:
		_drop_particles = GPUParticles2D.new()
		_drop_particles.name = "CommandoSupplyDropGpuDriftParticles"
		_drop_particles.amount = 28
		_drop_particles.lifetime = 0.42
		_drop_particles.one_shot = false
		_drop_particles.explosiveness = 0.10
		_drop_particles.randomness = 0.72
		_drop_particles.fixed_fps = 60
		_drop_particles.local_coords = true
		_drop_particles.visibility_rect = Rect2(-180.0, -180.0, 360.0, 360.0)
		_drop_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_drop_particles.material = _additive_material
		_drop_particles.process_material = _build_particle_process_material(Color(0.56, 0.92, 1.0, 0.62), 0.85, false)
		_drop_particles.emitting = false
		add_child(_drop_particles)
	if _crash_particles == null:
		_crash_particles = GPUParticles2D.new()
		_crash_particles.name = "CommandoSupplyDropGpuCrashParticles"
		_crash_particles.amount = 52
		_crash_particles.lifetime = 0.52
		_crash_particles.one_shot = true
		_crash_particles.explosiveness = 0.92
		_crash_particles.randomness = 0.82
		_crash_particles.fixed_fps = 60
		_crash_particles.local_coords = true
		_crash_particles.visibility_rect = Rect2(-220.0, -220.0, 440.0, 440.0)
		_crash_particles.texture = ImpactFlareTextureCache.get_glow_texture()
		_crash_particles.material = _additive_material
		_crash_particles.process_material = _build_particle_process_material(Color(1.0, 0.48, 0.12, 0.82), 1.0, true)
		_crash_particles.emitting = false
		add_child(_crash_particles)


func _start_pulse_tween() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "pulse_value", 1.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "pulse_value", 0.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _apply_state() -> void:
	var anchor: Dictionary = _get_anchor()
	if anchor.is_empty():
		set_active(false)
		return
	var pos: Vector2 = _get_vector2(anchor.get("pos", Vector2.ZERO), Vector2.ZERO)
	var shake_offset: Vector2 = _get_vector2(_state.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = _get_vector2(_state.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	position = game_offset + (pos + shake_offset) * render_scale
	scale = Vector2(render_scale, render_scale)
	_last_anchor_source = str(anchor.get("source", ""))
	_update_core_quad(anchor)
	_update_particles(anchor)
	var signature: String = _build_anchor_signature(anchor)
	if signature != _last_signature:
		_last_signature = signature
		_restart_crash_particles(anchor)


func _update_core_quad(anchor: Dictionary) -> void:
	if _core_quad == null or anchor.is_empty():
		return
	var radius: float = max(14.0, float(anchor.get("radius", 30.0)))
	var quad_size: float = max(QUAD_BASE_SIZE, radius * (3.10 + pulse_value * 0.35))
	_core_quad.position = Vector2(-quad_size * 0.5, -quad_size * 0.5)
	_core_quad.size = Vector2(quad_size, quad_size)
	if _core_material != null:
		_core_material.set_shader_parameter("elapsed", elapsed_sec)
		_core_material.set_shader_parameter("pulse", pulse_value)
		_core_material.set_shader_parameter("base_color", _get_color(anchor, "color", Color(0.56, 0.92, 1.0, 0.70)))
		_core_material.set_shader_parameter("secondary_color", _get_color(anchor, "secondary", Color(1.0, 0.74, 0.28, 0.70)))
		_core_material.set_shader_parameter("source_mode", _get_source_mode(anchor))
		_core_material.set_shader_parameter("alpha_scale", _get_anchor_alpha(anchor))


func _update_particles(anchor: Dictionary) -> void:
	if anchor.is_empty():
		return
	var source: String = str(anchor.get("source", "drop"))
	var color: Color = _get_color(anchor, "color", Color(0.56, 0.92, 1.0, 0.68))
	var secondary: Color = _get_color(anchor, "secondary", Color(1.0, 0.48, 0.12, 0.82))
	var radius: float = max(12.0, float(anchor.get("radius", 30.0)))
	if _drop_particles != null:
		_drop_particles.position = Vector2.ZERO
		_drop_particles.emitting = visible and source in ["aircraft", "drop", "collectible"]
		_configure_particle_process_material(_drop_particles.process_material, color, clamp(radius / 32.0, 0.55, 1.65), false)
	if _crash_particles != null:
		_crash_particles.position = Vector2.ZERO
		_configure_particle_process_material(_crash_particles.process_material, secondary, clamp(radius / 36.0, 0.75, 2.00), true)


func _restart_crash_particles(anchor: Dictionary) -> void:
	if _crash_particles == null:
		return
	if str(anchor.get("source", "")) != "explosion":
		_crash_particles.emitting = false
		return
	_crash_particles.restart()
	_crash_particles.emitting = true


func _get_anchor() -> Dictionary:
	var snapshot: Dictionary = _state.get("snapshot", {})
	var explosion_effects: Array = _get_array(snapshot.get("explosion_effects", []))
	if not explosion_effects.is_empty():
		return _anchor_from_effect(explosion_effects[0], "explosion", 42.0, Color(1.0, 0.44, 0.12, 0.82), Color(1.0, 0.82, 0.28, 0.80))
	var collectible_drops: Array = _get_array(snapshot.get("collectible_drops", []))
	if not collectible_drops.is_empty():
		return _anchor_from_effect(collectible_drops[0], "collectible", 32.0, Color(0.56, 0.92, 1.0, 0.70), Color(0.95, 0.82, 0.44, 0.72))
	var drop_effects: Array = _get_array(snapshot.get("drop_effects", []))
	if not drop_effects.is_empty():
		return _anchor_from_effect(drop_effects[0], "drop", 34.0, Color(0.56, 0.92, 1.0, 0.70), Color(0.95, 0.82, 0.44, 0.72))
	if bool(snapshot.get("active", false)) or bool(snapshot.get("aircraft_crashing", false)):
		return {
			"source": "aircraft",
			"pos": _get_vector2(snapshot.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO),
			"radius": 46.0,
			"color": Color(0.52, 0.82, 1.0, 0.62),
			"secondary": Color(1.0, 0.76, 0.28, 0.60),
		}
	return {}


func _anchor_from_effect(value: Variant, source: String, fallback_radius: float, color: Color, secondary: Color) -> Dictionary:
	var entry: Dictionary = _get_dict(value).duplicate(true)
	entry["source"] = source
	entry["pos"] = _get_vector2(entry.get("pos", entry.get("drop_position", Vector2.ZERO)), Vector2.ZERO)
	entry["radius"] = max(8.0, float(entry.get("radius", fallback_radius)))
	entry["color"] = _get_color(entry, "color", color)
	entry["secondary"] = _get_color(entry, "secondary", secondary)
	return entry


func _build_anchor_signature(anchor: Dictionary) -> String:
	var pos: Vector2 = _get_vector2(anchor.get("pos", Vector2.ZERO), Vector2.ZERO)
	return "%s:%s:%d:%d:%d" % [
		str(anchor.get("source", "")),
		str(anchor.get("kind", "")),
		int(round(pos.x)),
		int(round(pos.y)),
		int(round(float(anchor.get("radius", 0.0)))),
	]


func _get_anchor_alpha(anchor: Dictionary) -> float:
	var life: float = max(0.0, float(anchor.get("life", 0.0)))
	var duration: float = max(0.001, float(anchor.get("duration", life)))
	if life <= 0.0:
		return 0.70
	return clamp(life / duration, 0.14, 0.90)


func _get_source_mode(anchor: Dictionary) -> float:
	match str(anchor.get("source", "drop")):
		"aircraft":
			return 1.0
		"explosion":
			return 2.0
		"collectible":
			return 3.0
	return 0.0


func _get_gpu_particle_layer_count() -> int:
	var count := 0
	if _drop_particles != null:
		count += 1
	if _crash_particles != null:
		count += 1
	return count


static func _build_core_shader_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_core_shader()
	return material


static func _get_core_shader() -> Shader:
	if _core_shader != null:
		return _core_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform vec4 base_color : source_color = vec4(0.56, 0.92, 1.0, 0.70);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.74, 0.28, 0.70);
uniform float source_mode = 0.0;
uniform float alpha_scale = 0.72;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float outer = smoothstep(1.06, 0.10, r);
	float core = smoothstep(0.32, 0.0, r);
	float ring = smoothstep(0.035, 0.0, abs(r - (0.44 + pulse * 0.10)));
	float sweep = sin(angle * (5.0 + source_mode) + r * 19.0 - elapsed * (3.5 + source_mode));
	float spokes = max(0.0, sweep) * smoothstep(0.94, 0.18, r);
	float scan = 0.72 + 0.28 * sin((UV.y + UV.x * 0.22) * 112.0 + elapsed * 16.0);
	float explosion_mask = 1.0 - clamp(abs(source_mode - 2.0), 0.0, 1.0);
	float collectible_mask = 1.0 - clamp(abs(source_mode - 3.0), 0.0, 1.0);
	float alpha = outer * scan * (core * 0.26 + ring * (0.17 + explosion_mask * 0.08) + spokes * (0.10 + collectible_mask * 0.05));
	alpha *= alpha_scale * (0.34 + pulse * 0.15 + explosion_mask * 0.10 + collectible_mask * 0.05);
	vec3 color = mix(base_color.rgb, secondary_color.rgb, clamp(core * 0.36 + ring * 0.36 + spokes * 0.18, 0.0, 1.0));
	color = mix(color, vec3(1.0, 0.94, 0.66), core * (0.26 + explosion_mask * 0.18));
	COLOR = vec4(color, clamp(alpha, 0.0, 0.44));
}
"""
	_core_shader = shader
	return _core_shader


static func _build_particle_process_material(color: Color, strength: float, explosive: bool) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_configure_particle_process_material(mat, color, strength, explosive)
	return mat


static func _configure_particle_process_material(
	mat: ParticleProcessMaterial,
	color: Color,
	strength: float,
	explosive: bool
) -> void:
	if mat == null:
		return
	var safe_strength: float = max(0.1, strength)
	mat.color = color
	mat.emission_sphere_radius = 8.0 + safe_strength * (16.0 if explosive else 7.0)
	mat.initial_velocity_min = (68.0 if explosive else 16.0) * safe_strength
	mat.initial_velocity_max = (210.0 if explosive else 58.0) * safe_strength
	mat.radial_accel_min = (-30.0 if explosive else -22.0) * safe_strength
	mat.radial_accel_max = (145.0 if explosive else 22.0) * safe_strength
	mat.tangential_accel_min = -110.0 * safe_strength
	mat.tangential_accel_max = 110.0 * safe_strength
	mat.damping_min = 24.0 if explosive else 9.0
	mat.damping_max = 96.0 if explosive else 30.0
	mat.scale_min = 0.024 if explosive else 0.016
	mat.scale_max = (0.098 if explosive else 0.050) * safe_strength


func _get_color(entry: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = entry.get(key, fallback)
	if value is Color:
		return value
	return fallback


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
