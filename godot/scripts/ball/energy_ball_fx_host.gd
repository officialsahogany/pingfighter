extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const BALL_VISUAL_SCALE := 1.575
const BALL_FX_BRIGHTNESS := 0.68
const CORE_QUAD_SIZE := 88.0
const PULSE_RISE_SEC := 0.34
const PULSE_FALL_SEC := 0.46
const PULSE_PERIOD_SEC := PULSE_RISE_SEC + PULSE_FALL_SEC
const RAY_COUNT := 7
const SEVERE_LOD_AURA_PARTICLE_THRESHOLD := 0.50
const AIR_STRIKE_GPU_BURST_SKIP_LOD_THRESHOLD := 0.50
const HIT_BURST_PREWARM_KINDS := [
	"hit",
	"player_paddle",
	"boss_paddle",
	"viper_blade",
	"viper_dark_blade",
	"viper_shadow_step",
	"viper_marshal",
	"viper_core_flip",
	"viper_double_marshal",
	"viper_air_strike",
	"smasher_wheel",
	"shield_kiting",
]
const PREWARM_BASE_STEP_COUNT := 4

var pulse_value := 0.0
var burst_value := 0.0
var elapsed_sec := 0.0
var speed_intensity := 0.0
var boost_active := false
var skill_mode := ""
var skill_intensity := 0.0
var fx_lod_scale := 1.0

var _core_quad: ColorRect = null
var _aura_particles: GPUParticles2D = null
var _burst_particles: GPUParticles2D = null
var _core_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _burst_tween: Tween = null
var _last_boost_active := false
var _last_aura_mode := ""
var _last_lod_scale := 1.0
var _last_hit_event_id := -1
var _last_hit_kind := ""
static var _prewarm_assets_step_index := 0


static func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


static func prewarm_assets_step() -> bool:
	var total_steps := PREWARM_BASE_STEP_COUNT + HIT_BURST_PREWARM_KINDS.size()
	if _prewarm_assets_step_index >= total_steps:
		return true
	match _prewarm_assets_step_index:
		0:
			ImpactFlareTextureCache.get_glow_texture()
		1:
			_build_core_shader_material()
		2:
			_build_particle_process_material(false)
		3:
			_build_particle_process_material(true)
		_:
			var hit_kind_index := _prewarm_assets_step_index - PREWARM_BASE_STEP_COUNT
			if hit_kind_index >= 0 and hit_kind_index < HIT_BURST_PREWARM_KINDS.size():
				_build_burst_process_material(1.0, str(HIT_BURST_PREWARM_KINDS[hit_kind_index]))
	_prewarm_assets_step_index += 1
	return _prewarm_assets_step_index >= total_steps


func _ready() -> void:
	z_as_relative = false
	z_index = 12
	_additive_material = _make_additive_material()
	_build_children()
	_prime_hit_burst_particles()
	set_process(false)
	set_active(false)


func sync_state(
	screen_pos: Vector2,
	render_scale: float,
	ball_vel: Vector2,
	next_boost_active: bool,
	active: bool,
	hit_pulse_event: Dictionary = {},
	next_skill_mode: String = "",
	next_lod_scale: float = 1.0
) -> void:
	if _core_quad == null:
		_build_children()
	set_active(active)
	if not active:
		return
	position = screen_pos
	scale = Vector2.ONE * max(0.01, render_scale) * BALL_VISUAL_SCALE
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	speed_intensity = clamp(ball_vel.length() / 24.0, 0.0, 1.0)
	boost_active = next_boost_active
	skill_mode = _normalize_skill_mode(next_skill_mode)
	skill_intensity = 0.0 if skill_mode == "" else clamp(0.62 + speed_intensity * 0.38, 0.0, 1.0)
	fx_lod_scale = clamp(next_lod_scale, 0.35, 1.0)
	_update_pulse_value()
	_apply_hit_pulse_event(hit_pulse_event)
	_update_core_quad()
	_update_particles()
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if _core_quad != null:
		_core_quad.visible = active
	if _aura_particles != null:
		_aura_particles.emitting = active
	if _burst_particles != null and not active:
		_burst_particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = null
	if free_self:
		queue_free()


func _draw() -> void:
	if not visible:
		return
	var ray_alpha: float = clamp(
		0.025 + speed_intensity * 0.055 + burst_value * 0.24 + (0.060 if boost_active else 0.0) + skill_intensity * 0.040,
		0.0,
		0.34
	) * BALL_FX_BRIGHTNESS
	if ray_alpha <= 0.01:
		return
	var beat: float = 0.72 + pulse_value * 0.28
	var ray_len: float = 25.0 + speed_intensity * 14.0 + burst_value * 26.0 + (12.0 if boost_active else 0.0) + skill_intensity * 10.0
	var inner: float = 9.0
	var ray_count: int = max(3, int(round(float(RAY_COUNT) * fx_lod_scale)))
	for i in range(ray_count):
		var angle: float = elapsed_sec * (1.6 + float(i % 3) * 0.24) + TAU * float(i) / float(ray_count)
		var direction := Vector2(cos(angle), sin(angle))
		var start: Vector2 = direction * inner
		var end: Vector2 = direction * (ray_len + sin(elapsed_sec * 5.0 + float(i)) * 3.0)
		var color: Color = _get_hit_ray_color(ray_alpha * beat)
		draw_line(start, end, color, 1.0 + speed_intensity * 0.8 + burst_value * 1.2, true)


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _core_quad == null:
		_core_quad = ColorRect.new()
		_core_quad.name = "EnergyBallShaderCore"
		_core_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_core_quad.color = Color.WHITE
		_core_quad.modulate = Color(1.0, 1.0, 1.0, BALL_FX_BRIGHTNESS)
		_core_material = _build_core_shader_material()
		_core_quad.material = _core_material
		add_child(_core_quad)
	if _aura_particles == null:
		_aura_particles = GPUParticles2D.new()
		_aura_particles.name = "EnergyBallGpuAuraParticles"
		_aura_particles.amount = 30
		_aura_particles.lifetime = 0.42
		_aura_particles.one_shot = false
		_aura_particles.explosiveness = 0.0
		_aura_particles.randomness = 0.72
		_aura_particles.fixed_fps = 60
		_aura_particles.local_coords = true
		_aura_particles.visibility_rect = Rect2(-90.0, -90.0, 180.0, 180.0)
		_aura_particles.texture = ImpactFlareTextureCache.get_glow_texture()
		_aura_particles.material = _additive_material
		_aura_particles.process_material = _build_particle_process_material(false)
		_aura_particles.emitting = false
		add_child(_aura_particles)
	if _burst_particles == null:
		_burst_particles = GPUParticles2D.new()
		_burst_particles.name = "EnergyBallGpuHitBurstParticles"
		_burst_particles.amount = 42
		_burst_particles.lifetime = 0.26
		_burst_particles.one_shot = true
		_burst_particles.explosiveness = 0.96
		_burst_particles.randomness = 0.78
		_burst_particles.fixed_fps = 60
		_burst_particles.local_coords = false
		_burst_particles.visibility_rect = Rect2(-120.0, -120.0, 240.0, 240.0)
		_burst_particles.texture = ImpactFlareTextureCache.get_glow_texture()
		_burst_particles.material = _additive_material
		_burst_particles.process_material = _build_burst_process_material(1.0, "hit")
		_burst_particles.emitting = false
		add_child(_burst_particles)
	_update_pulse_value()
	_update_core_quad()
	_update_particles()


func _prime_hit_burst_particles() -> void:
	if _burst_particles == null:
		return
	var burst_mat: ParticleProcessMaterial = _burst_particles.process_material
	if burst_mat == null:
		burst_mat = _build_burst_process_material(1.0, "hit")
		_burst_particles.process_material = burst_mat
	for kind in HIT_BURST_PREWARM_KINDS:
		_configure_burst_process_material(burst_mat, 1.0, kind)
	var previous_amount: int = _burst_particles.amount
	_burst_particles.amount = 54
	_burst_particles.emitting = false
	_burst_particles.restart()
	_burst_particles.emitting = false
	_burst_particles.amount = previous_amount
	_configure_burst_process_material(burst_mat, 1.0, "hit")


func _update_pulse_value() -> void:
	var phase: float = fposmod(elapsed_sec, PULSE_PERIOD_SEC)
	if phase <= PULSE_RISE_SEC:
		var rise_t: float = clamp(phase / PULSE_RISE_SEC, 0.0, 1.0)
		pulse_value = sin(rise_t * PI * 0.5)
		return
	var fall_t: float = clamp((phase - PULSE_RISE_SEC) / PULSE_FALL_SEC, 0.0, 1.0)
	pulse_value = cos(fall_t * PI * 0.5)


func _update_core_quad() -> void:
	if _core_quad == null:
		return
	var lod_radius_scale: float = lerp(0.82, 1.0, fx_lod_scale)
	var burst_lod_scale: float = lerp(0.55, 1.0, fx_lod_scale)
	var quad_size: float = CORE_QUAD_SIZE * (
		0.88
		+ speed_intensity * 0.10
		+ pulse_value * 0.06
		+ burst_value * 0.34 * burst_lod_scale
		+ (0.18 if boost_active else 0.0)
	) * lod_radius_scale
	_core_quad.position = Vector2(-quad_size * 0.5, -quad_size * 0.5)
	_core_quad.size = Vector2(quad_size, quad_size)
	if _core_material != null:
		_core_material.set_shader_parameter("elapsed", elapsed_sec)
		_core_material.set_shader_parameter("pulse", pulse_value)
		_core_material.set_shader_parameter("burst", burst_value)
		_core_material.set_shader_parameter("speed_intensity", speed_intensity)
		_core_material.set_shader_parameter("boost_active", 1.0 if boost_active else 0.0)
		_core_material.set_shader_parameter("skill_mode", _get_shader_skill_mode())
		_core_material.set_shader_parameter("skill_intensity", skill_intensity)


func _update_particles() -> void:
	if _aura_particles == null:
		return
	if fx_lod_scale < SEVERE_LOD_AURA_PARTICLE_THRESHOLD:
		_aura_particles.emitting = false
		return
	var aura_mode: String = "boost" if boost_active else skill_mode
	if boost_active != _last_boost_active or aura_mode != _last_aura_mode or abs(fx_lod_scale - _last_lod_scale) > 0.01:
		var base_amount := 52 if boost_active else (44 if skill_mode != "" else 30)
		_aura_particles.amount = max(10, int(round(float(base_amount) * fx_lod_scale)))
		_aura_particles.process_material = _build_particle_process_material(boost_active or skill_mode != "")
		_last_boost_active = boost_active
		_last_aura_mode = aura_mode
		_last_lod_scale = fx_lod_scale
	var mat: ParticleProcessMaterial = _aura_particles.process_material
	if mat != null:
		mat.color = _get_aura_particle_color()
		mat.initial_velocity_min = 18.0 + speed_intensity * 18.0
		mat.initial_velocity_max = 54.0 + speed_intensity * 54.0
	_aura_particles.emitting = visible


func _normalize_skill_mode(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "drive" or normalized == "power_smashing" or normalized == "ghost_shot":
		return normalized
	return ""


func _get_shader_skill_mode() -> float:
	if skill_mode == "drive":
		return 1.0
	if skill_mode == "power_smashing":
		return 2.0
	if skill_mode == "ghost_shot":
		return 3.0
	return 0.0


func _get_aura_particle_color() -> Color:
	if boost_active:
		return Color(1.0, 0.76, 1.0, 0.70 * BALL_FX_BRIGHTNESS)
	if skill_mode == "drive":
		return Color(1.0, 0.88, 0.36, (0.58 + skill_intensity * 0.18) * BALL_FX_BRIGHTNESS)
	if skill_mode == "power_smashing":
		return Color(1.0, 0.46, 0.16, (0.62 + skill_intensity * 0.20) * BALL_FX_BRIGHTNESS)
	if skill_mode == "ghost_shot":
		return Color(0.70, 0.18, 1.0, (0.60 + skill_intensity * 0.18) * BALL_FX_BRIGHTNESS)
	return Color(0.76, 0.96, 1.0, (0.54 + speed_intensity * 0.20) * BALL_FX_BRIGHTNESS)


func _apply_hit_pulse_event(hit_pulse_event: Dictionary) -> void:
	var event_id: int = int(hit_pulse_event.get("id", 0))
	if event_id <= 0 or event_id == _last_hit_event_id:
		return
	_last_hit_event_id = event_id
	var intensity: float = clamp(float(hit_pulse_event.get("intensity", speed_intensity)), 0.0, 1.0)
	var kind: String = str(hit_pulse_event.get("kind", "hit"))
	var burst_pos: Vector2 = _get_hit_burst_screen_pos(hit_pulse_event)
	_trigger_hit_burst(intensity, kind, burst_pos)


func _trigger_hit_burst(intensity: float, kind: String, burst_screen_pos: Vector2) -> void:
	_last_hit_kind = kind
	var burst_strength: float = clamp(0.55 + intensity * 0.65 + speed_intensity * 0.28, 0.45, 1.35)
	burst_value = burst_strength
	if _burst_particles != null:
		if _should_skip_gpu_hit_burst(kind):
			_burst_particles.emitting = false
		else:
			_burst_particles.global_position = burst_screen_pos
			var base_burst_amount := 54 if _is_heavy_hit_kind(kind) else 42
			_burst_particles.amount = max(16, int(round(float(base_burst_amount) * fx_lod_scale)))
			var burst_mat: ParticleProcessMaterial = _burst_particles.process_material
			if burst_mat == null:
				burst_mat = _build_burst_process_material(1.0, kind)
				_burst_particles.process_material = burst_mat
			_configure_burst_process_material(burst_mat, burst_strength, kind)
			_burst_particles.emitting = false
			_burst_particles.restart()
			_burst_particles.emitting = true
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	if is_inside_tree():
		_burst_tween = create_tween()
		_burst_tween.tween_property(self, "burst_value", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _get_hit_burst_screen_pos(hit_pulse_event: Dictionary) -> Vector2:
	var screen_pos: Variant = hit_pulse_event.get("screen_pos", global_position)
	if screen_pos is Vector2:
		return screen_pos
	return global_position


static func _build_core_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float burst = 0.0;
uniform float speed_intensity = 0.0;
uniform float boost_active = 0.0;
uniform float skill_mode = 0.0;
uniform float skill_intensity = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float outer = smoothstep(1.10, 0.12, r);
	float core = smoothstep(0.46, 0.0, r);
	float spiral_a = sin(angle * 7.0 - elapsed * (4.8 + speed_intensity * 2.2) + r * 18.0);
	float spiral_b = sin(angle * -5.0 + elapsed * (3.2 + boost_active * 2.0) + r * 24.0);
	float spiral = max(0.0, spiral_a) * 0.55 + max(0.0, spiral_b) * 0.35;
	float ring_phase = fract(r * (4.8 + speed_intensity * 1.6 + boost_active * 1.3) - elapsed * (0.66 + speed_intensity * 0.84));
	float ring = smoothstep(0.50, 0.43, abs(ring_phase - 0.5));
	float burst_ring = smoothstep(0.13, 0.0, abs(r - (0.30 + burst * 0.42))) * outer;
	float scan = 0.72 + 0.28 * sin((UV.y + UV.x * 0.11) * 140.0 + elapsed * 18.0);
	float alpha = outer * scan * (core * 0.18 + spiral * 0.12 + ring * 0.15 + burst_ring * burst * 0.52);
	alpha *= 0.32 + speed_intensity * 0.18 + pulse * 0.10 + boost_active * 0.22 + burst * 0.42;
	vec3 cyan = vec3(0.24, 0.82, 1.0);
	vec3 violet = vec3(0.92, 0.56, 1.0);
	vec3 white_blue = vec3(0.84, 0.98, 1.0);
	vec3 drive_gold = vec3(1.0, 0.88, 0.28);
	vec3 power_orange = vec3(1.0, 0.38, 0.10);
	vec3 ghost_purple = vec3(0.46, 0.08, 0.82);
	vec3 ghost_dark = vec3(0.035, 0.0, 0.09);
	float drive_mask = 1.0 - clamp(abs(skill_mode - 1.0), 0.0, 1.0);
	float power_mask = 1.0 - clamp(abs(skill_mode - 2.0), 0.0, 1.0);
	float ghost_mask = 1.0 - clamp(abs(skill_mode - 3.0), 0.0, 1.0);
	float warm_skill_mask = max(drive_mask, power_mask) * skill_intensity;
	float ghost_skill_mask = ghost_mask * skill_intensity;
	float skill_mask = max(warm_skill_mask, ghost_skill_mask);
	vec3 skill_color = mix(drive_gold, power_orange, power_mask);
	vec3 color = mix(cyan, violet, clamp(max(0.0, spiral_b) + boost_active * 0.38, 0.0, 1.0));
	color = mix(color, white_blue, core * 0.45 + pulse * 0.10 + burst * 0.24);
	color = mix(color, skill_color, warm_skill_mask * (0.28 + core * 0.16 + ring * 0.12));
	vec3 ghost_color = mix(ghost_dark, ghost_purple, 0.42 + ring * 0.22 + spiral * 0.14);
	ghost_color = mix(ghost_color, vec3(0.84, 0.46, 1.0), core * 0.16 + pulse * 0.06);
	color = mix(color, ghost_color, ghost_skill_mask * (0.56 + core * 0.12));
	COLOR = vec4(color, clamp(alpha * (0.72 + warm_skill_mask * 0.16 + ghost_skill_mask * 0.06), 0.0, 0.52));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _build_particle_process_material(boost: bool) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 24.0 if boost else 18.0
	mat.initial_velocity_max = 120.0 if boost else 54.0
	mat.radial_accel_min = -130.0 if boost else -70.0
	mat.radial_accel_max = -26.0 if boost else 12.0
	mat.tangential_accel_min = -120.0 if boost else -70.0
	mat.tangential_accel_max = 120.0 if boost else 70.0
	mat.damping_min = 12.0
	mat.damping_max = 38.0
	mat.scale_min = 0.024
	mat.scale_max = 0.074 if boost else 0.054
	mat.color = Color(1.0, 0.76, 1.0, 0.70 * BALL_FX_BRIGHTNESS) if boost else Color(0.76, 0.96, 1.0, 0.58 * BALL_FX_BRIGHTNESS)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 19.0 if boost else 14.0
	return mat


static func _build_burst_process_material(strength: float, kind: String) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	_configure_burst_process_material(mat, strength, kind)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	return mat


static func _configure_burst_process_material(mat: ParticleProcessMaterial, strength: float, kind: String) -> void:
	if mat == null:
		return
	mat.initial_velocity_min = 92.0 * strength
	mat.initial_velocity_max = 245.0 * strength
	mat.radial_accel_min = 35.0 * strength
	mat.radial_accel_max = 160.0 * strength
	mat.tangential_accel_min = -160.0 * strength
	mat.tangential_accel_max = 160.0 * strength
	mat.damping_min = 54.0
	mat.damping_max = 138.0
	mat.scale_min = 0.034
	mat.scale_max = 0.118 if kind == "shield_kiting" else 0.092
	mat.color = _get_burst_particle_color(kind)


func _get_hit_ray_color(alpha: float) -> Color:
	if _last_hit_kind == "shield_kiting":
		return Color(0.62, 1.0, 0.96, alpha)
	if _last_hit_kind == "viper_air_strike":
		return Color(0.38, 1.0, 0.86, alpha)
	if _last_hit_kind.begins_with("viper"):
		return Color(0.96, 0.42, 1.0, alpha)
	if _last_hit_kind == "wall" or _last_hit_kind == "brick_wall" or _last_hit_kind == "holy_barrier":
		return Color(0.90, 0.96, 1.0, alpha)
	if skill_mode == "drive":
		return Color(1.0, 0.86, 0.30, alpha)
	if skill_mode == "power_smashing":
		return Color(1.0, 0.40, 0.14, alpha)
	if skill_mode == "ghost_shot":
		return Color(0.78, 0.22, 1.0, alpha)
	return Color(0.62, 0.92, 1.0, alpha)


static func _is_heavy_hit_kind(kind: String) -> bool:
	return (
		kind == "shield_kiting"
		or kind == "viper_dark_blade"
		or kind == "viper_marshal"
		or kind == "viper_core_flip"
		or kind == "viper_double_marshal"
		or kind == "viper_air_strike"
	)


func _should_skip_gpu_hit_burst(kind: String) -> bool:
	return kind == "viper_air_strike" and fx_lod_scale <= AIR_STRIKE_GPU_BURST_SKIP_LOD_THRESHOLD


static func _get_burst_particle_color(kind: String) -> Color:
	if kind == "shield_kiting":
		return Color(0.52, 1.0, 0.92, 0.88 * BALL_FX_BRIGHTNESS)
	if kind == "viper_dark_blade" or kind == "viper_double_marshal":
		return Color(1.0, 0.24, 0.84, 0.92 * BALL_FX_BRIGHTNESS)
	if kind == "viper_blade" or kind == "viper_shadow_step" or kind == "viper_marshal" or kind == "viper_core_flip":
		return Color(0.86, 0.32, 1.0, 0.88 * BALL_FX_BRIGHTNESS)
	if kind == "viper_air_strike":
		return Color(0.28, 1.0, 0.86, 0.88 * BALL_FX_BRIGHTNESS)
	if kind == "boss_paddle":
		return Color(0.96, 0.78, 1.0, 0.82 * BALL_FX_BRIGHTNESS)
	if kind == "wall" or kind == "brick_wall" or kind == "holy_barrier":
		return Color(0.86, 0.96, 1.0, 0.80 * BALL_FX_BRIGHTNESS)
	return Color(0.70, 0.94, 1.0, 0.84 * BALL_FX_BRIGHTNESS)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat
