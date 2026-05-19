extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")

const GLOW_QUAD_BASE_SIZE := 108.0
const SPARK_RAY_COUNT := 9

var pulse_value := 0.0
var elapsed_sec := 0.0

var _state: Dictionary = {}
var _core_quad: ColorRect = null
var _impact_particles: GPUParticles2D = null
var _muzzle_particles: GPUParticles2D = null
var _core_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _pulse_tween: Tween = null
var _last_signature := ""
var _last_anchor_source := ""

static var _core_shader: Shader = null
static var _prewarmed: bool = false


# Idempotent. The two `_build_particle_process_material()` calls below allocate
# fresh `ParticleProcessMaterial` resources, configure ~13 properties, and then
# throw them away — the return values are never captured. Their only purpose
# is to warm Godot's GPU shader-compile path for that material type. After the
# first run, repeated calls are pure waste (allocation + GC every frame), so
# the `_prewarmed` static flag short-circuits subsequent invocations.
static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_prewarmed = true
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	_get_core_shader()
	_build_particle_process_material(Color(1.0, 0.72, 0.28, 0.72), 1.0, false)
	_build_particle_process_material(Color(1.0, 0.46, 0.16, 0.78), 1.0, true)


static func reset_prewarm_cache_for_test() -> void:
	_prewarmed = false


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
	z_index = 16
	_additive_material = _make_additive_material()
	_build_children()
	_start_pulse_tween()
	set_active(should_remain_active)
	if should_remain_active:
		_apply_state()
		queue_redraw()


func sync_state(
	draw_items: Dictionary,
	shake_offset: Vector2,
	active: bool,
	layout_context: Dictionary = {}
) -> void:
	if _core_quad == null:
		_build_children()
	if is_inside_tree() and (_pulse_tween == null or not _pulse_tween.is_valid()):
		_start_pulse_tween()
	_state = {
		"draw_items": draw_items.duplicate(false),
		"shake_offset": shake_offset,
		"game_offset": Stage1ContextReader.as_vector2(layout_context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
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
	# The stage actor renderer syncs this detached host from the battle draw
	# path; an active _process callback would run outside the frame shell.
	set_process(false)
	if _core_quad != null:
		_core_quad.visible = active
	if _muzzle_particles != null:
		_muzzle_particles.emitting = active
	if _impact_particles != null and not active:
		_impact_particles.emitting = false


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
	var color: Color = _get_color(anchor, "color", Color(1.0, 0.72, 0.28, 0.72))
	var secondary: Color = _get_color(anchor, "secondary", Color(1.0, 0.42, 0.14, 0.72))
	var radius: float = float(anchor.get("radius", 24.0))
	var source: String = str(anchor.get("source", "impact"))
	var beat: float = 0.68 + pulse_value * 0.32
	ImpactFlareTextureCache.draw_glow(self, Vector2.ZERO, radius * 1.45, color, 0.10 * beat)
	if source == "impact":
		ImpactShockwaveTextureCache.draw_full_ring(self, Vector2.ZERO, radius * (0.84 + pulse_value * 0.14), secondary, 0.22 * beat)
		ImpactFlareTextureCache.draw_burst(self, Vector2.ZERO, radius * 0.92, secondary, 0.16 * beat)
	elif source == "muzzle":
		var direction: Vector2 = Stage1ContextReader.as_vector2(anchor.get("direction", Vector2.UP), Vector2.UP)
		var dir: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.UP
		ImpactFlareTextureCache.draw_burst(self, dir * radius * 0.22, radius * 0.70, secondary, 0.20 * beat)
	else:
		ImpactShockwaveTextureCache.draw_full_ring(self, Vector2.ZERO, radius * (0.70 + pulse_value * 0.10), secondary, 0.14 * beat)
	for i in range(SPARK_RAY_COUNT):
		var angle: float = elapsed_sec * (1.2 + float(i % 2) * 0.25) + TAU * float(i) / float(SPARK_RAY_COUNT)
		var dir := Vector2(cos(angle), sin(angle))
		var inner: float = radius * (0.20 + 0.05 * pulse_value)
		var outer: float = radius * (0.58 + 0.18 * sin(elapsed_sec * 3.0 + float(i)))
		draw_line(dir * inner, dir * outer, Color(secondary.r, secondary.g, secondary.b, 0.12 * beat), 1.2, true)


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _core_quad == null:
		_core_quad = ColorRect.new()
		_core_quad.name = "CommandoFirearmShaderCore"
		_core_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_core_quad.color = Color.WHITE
		_core_material = _build_core_shader_material()
		_core_quad.material = _core_material
		add_child(_core_quad)
	if _muzzle_particles == null:
		_muzzle_particles = GPUParticles2D.new()
		_muzzle_particles.name = "CommandoFirearmGpuMuzzleParticles"
		_muzzle_particles.amount = 24
		_muzzle_particles.lifetime = 0.22
		_muzzle_particles.one_shot = false
		_muzzle_particles.explosiveness = 0.12
		_muzzle_particles.randomness = 0.72
		_muzzle_particles.fixed_fps = 60
		_muzzle_particles.local_coords = true
		_muzzle_particles.visibility_rect = Rect2(-128.0, -128.0, 256.0, 256.0)
		_muzzle_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_muzzle_particles.material = _additive_material
		_muzzle_particles.process_material = _build_particle_process_material(Color(1.0, 0.76, 0.28, 0.70), 0.78, false)
		_muzzle_particles.emitting = false
		add_child(_muzzle_particles)
	if _impact_particles == null:
		_impact_particles = GPUParticles2D.new()
		_impact_particles.name = "CommandoFirearmGpuImpactParticles"
		_impact_particles.amount = 42
		_impact_particles.lifetime = 0.36
		_impact_particles.one_shot = true
		_impact_particles.explosiveness = 0.92
		_impact_particles.randomness = 0.82
		_impact_particles.fixed_fps = 60
		_impact_particles.local_coords = true
		_impact_particles.visibility_rect = Rect2(-180.0, -180.0, 360.0, 360.0)
		_impact_particles.texture = ImpactFlareTextureCache.get_glow_texture()
		_impact_particles.material = _additive_material
		_impact_particles.process_material = _build_particle_process_material(Color(1.0, 0.44, 0.14, 0.80), 1.0, true)
		_impact_particles.emitting = false
		add_child(_impact_particles)


func _start_pulse_tween() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "pulse_value", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "pulse_value", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _apply_state() -> void:
	var anchor: Dictionary = _get_anchor()
	if anchor.is_empty():
		set_active(false)
		return
	var pos: Vector2 = Stage1ContextReader.as_vector2(anchor.get("pos", Vector2.ZERO), Vector2.ZERO)
	var shake_offset: Vector2 = Stage1ContextReader.as_vector2(_state.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	var game_offset: Vector2 = Stage1ContextReader.as_vector2(_state.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	position = game_offset + (pos + shake_offset) * render_scale
	scale = Vector2(render_scale, render_scale)
	_last_anchor_source = str(anchor.get("source", ""))
	_update_core_quad(anchor)
	_update_particles(anchor)
	var signature: String = _build_anchor_signature(anchor)
	if signature != _last_signature:
		_last_signature = signature
		_restart_impact_particles(anchor)


func _update_core_quad(anchor: Dictionary) -> void:
	if _core_quad == null or anchor.is_empty():
		return
	var radius: float = max(12.0, float(anchor.get("radius", 26.0)))
	var quad_size: float = max(GLOW_QUAD_BASE_SIZE, radius * (3.15 + pulse_value * 0.35))
	_core_quad.position = Vector2(-quad_size * 0.5, -quad_size * 0.5)
	_core_quad.size = Vector2(quad_size, quad_size)
	if _core_material != null:
		_core_material.set_shader_parameter("elapsed", elapsed_sec)
		_core_material.set_shader_parameter("pulse", pulse_value)
		_core_material.set_shader_parameter("base_color", _get_color(anchor, "color", Color(1.0, 0.72, 0.28, 0.72)))
		_core_material.set_shader_parameter("secondary_color", _get_color(anchor, "secondary", Color(1.0, 0.42, 0.14, 0.72)))
		_core_material.set_shader_parameter("source_mode", _get_source_mode(anchor))
		_core_material.set_shader_parameter("alpha_scale", _get_anchor_alpha(anchor))


func _update_particles(anchor: Dictionary) -> void:
	if anchor.is_empty():
		return
	var color: Color = _get_color(anchor, "color", Color(1.0, 0.72, 0.28, 0.72))
	var secondary: Color = _get_color(anchor, "secondary", Color(1.0, 0.42, 0.14, 0.72))
	var radius: float = max(10.0, float(anchor.get("radius", 24.0)))
	var source: String = str(anchor.get("source", "impact"))
	if _muzzle_particles != null:
		_muzzle_particles.position = Vector2.ZERO
		_muzzle_particles.emitting = visible and source == "muzzle"
		var muzzle_mat: ParticleProcessMaterial = _muzzle_particles.process_material
		_configure_particle_process_material(muzzle_mat, color, clamp(radius / 28.0, 0.55, 1.45), false)
	if _impact_particles != null:
		_impact_particles.position = Vector2.ZERO
		var impact_mat: ParticleProcessMaterial = _impact_particles.process_material
		_configure_particle_process_material(impact_mat, secondary, clamp(radius / 30.0, 0.65, 1.85), true)


func _restart_impact_particles(anchor: Dictionary) -> void:
	if _impact_particles == null:
		return
	var source: String = str(anchor.get("source", "impact"))
	if source == "muzzle":
		_impact_particles.emitting = false
		return
	_impact_particles.restart()
	_impact_particles.emitting = true


func _get_anchor() -> Dictionary:
	var draw_items: Dictionary = _state.get("draw_items", {})
	var impact_flashes: Array = _get_array(draw_items.get("impact_flashes", []))
	if not impact_flashes.is_empty():
		return _anchor_from_entry(impact_flashes[0], "impact", 26.0)
	var lingering_effects: Array = _get_array(draw_items.get("lingering_effects", []))
	if not lingering_effects.is_empty():
		return _anchor_from_lingering(lingering_effects[0])
	var muzzle_flashes: Array = _get_array(draw_items.get("muzzle_flashes", []))
	if not muzzle_flashes.is_empty():
		return _anchor_from_entry(muzzle_flashes[0], "muzzle", 16.0)
	return {}


func _anchor_from_lingering(value: Variant) -> Dictionary:
	var effect: Dictionary = _get_dict(value)
	var width: float = float(effect.get("width", 96.0))
	var height: float = float(effect.get("height", 54.0))
	var anchor := _anchor_from_entry(effect, "lingering", max(width, height) * 0.28)
	anchor["radius"] = max(16.0, max(width, height) * 0.30)
	return anchor


func _anchor_from_entry(value: Variant, source: String, fallback_radius: float) -> Dictionary:
	var entry: Dictionary = _get_dict(value).duplicate(true)
	entry["source"] = source
	entry["pos"] = Stage1ContextReader.as_vector2(entry.get("pos", Vector2.ZERO), Vector2.ZERO)
	entry["radius"] = max(6.0, float(entry.get("radius", fallback_radius)))
	return entry


func _build_anchor_signature(anchor: Dictionary) -> String:
	var pos: Vector2 = Stage1ContextReader.as_vector2(anchor.get("pos", Vector2.ZERO), Vector2.ZERO)
	return "%s:%s:%d:%d:%d" % [
		str(anchor.get("source", "")),
		str(anchor.get("kind", "")),
		int(round(pos.x)),
		int(round(pos.y)),
		int(round(float(anchor.get("radius", 0.0)))),
	]


func _get_anchor_alpha(anchor: Dictionary) -> float:
	var timer: float = max(0.0, float(anchor.get("timer_frames", 0.0)))
	var max_timer: float = max(1.0, float(anchor.get("max_timer_frames", timer)))
	if timer <= 0.0:
		return 0.72
	return clamp(timer / max_timer, 0.12, 0.92)


func _get_source_mode(anchor: Dictionary) -> float:
	var source: String = str(anchor.get("source", "impact"))
	if source == "muzzle":
		return 1.0
	if source == "lingering":
		return 2.0
	return 0.0


func _get_gpu_particle_layer_count() -> int:
	var count := 0
	if _muzzle_particles != null:
		count += 1
	if _impact_particles != null:
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
uniform vec4 base_color : source_color = vec4(1.0, 0.72, 0.28, 0.72);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.42, 0.14, 0.72);
uniform float source_mode = 0.0;
uniform float alpha_scale = 0.72;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float outer = smoothstep(1.08, 0.12, r);
	float core = smoothstep(0.34, 0.0, r);
	float ring = smoothstep(0.035, 0.0, abs(r - (0.42 + pulse * 0.10)));
	float ripple = sin(angle * (7.0 + source_mode * 1.5) + r * 20.0 - elapsed * (4.2 + source_mode));
	float spokes = max(0.0, ripple) * smoothstep(0.94, 0.18, r);
	float scan = 0.74 + 0.26 * sin((UV.y + UV.x * 0.18) * 126.0 + elapsed * 18.0);
	float muzzle_mask = 1.0 - clamp(abs(source_mode - 1.0), 0.0, 1.0);
	float field_mask = 1.0 - clamp(abs(source_mode - 2.0), 0.0, 1.0);
	float alpha = outer * scan * (core * 0.28 + ring * (0.18 + muzzle_mask * 0.08) + spokes * (0.11 + field_mask * 0.06));
	alpha *= alpha_scale * (0.34 + pulse * 0.14 + muzzle_mask * 0.08 + field_mask * 0.05);
	vec3 color = mix(base_color.rgb, secondary_color.rgb, clamp(core * 0.42 + ring * 0.32 + spokes * 0.18, 0.0, 1.0));
	color = mix(color, vec3(1.0, 0.92, 0.62), core * (0.30 + muzzle_mask * 0.18));
	COLOR = vec4(color, clamp(alpha, 0.0, 0.42));
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
	mat.emission_sphere_radius = 8.0 + safe_strength * (12.0 if explosive else 5.0)
	mat.initial_velocity_min = (60.0 if explosive else 18.0) * safe_strength
	mat.initial_velocity_max = (190.0 if explosive else 64.0) * safe_strength
	mat.radial_accel_min = (-40.0 if explosive else -30.0) * safe_strength
	mat.radial_accel_max = (130.0 if explosive else 18.0) * safe_strength
	mat.tangential_accel_min = -120.0 * safe_strength
	mat.tangential_accel_max = 120.0 * safe_strength
	mat.damping_min = 28.0 if explosive else 10.0
	mat.damping_max = 102.0 if explosive else 34.0
	mat.scale_min = 0.026 if explosive else 0.018
	mat.scale_max = (0.095 if explosive else 0.052) * safe_strength


func _get_color(entry: Dictionary, key: String, fallback: Color) -> Color:
	return Stage1ContextReader.as_color(entry.get(key, fallback), fallback)


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
