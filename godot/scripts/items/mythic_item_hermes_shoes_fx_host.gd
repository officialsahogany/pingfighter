extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const Z_INDEX := 8
const VISIBILITY_PADDING := 220.0
const DEFAULT_PADDLE_SIZE := Vector2(155.0, 50.0)
const WAKE_SPRITE_COUNT := 7
const TRAIL_PARTICLE_AMOUNT := 56
const TRAIL_PARTICLE_LIFETIME := 0.55
const SPARK_PARTICLE_AMOUNT := 24
const SPARK_PARTICLE_LIFETIME := 0.34
const BASE_TRAIL_EMISSION_RATE := 14.0
const MOTION_TRAIL_EMISSION_RATE := 96.0
const MOTION_REFERENCE_PX_PER_FRAME := 9.0
const MAX_TRACKED_DELTA := 22.0
const FADE_IN_SEC := 0.18
const FADE_OUT_SEC := 0.32

static var _prewarm_done := false

var _additive_material: CanvasItemMaterial = null
var _glow_rect: ColorRect = null
var _glow_material: ShaderMaterial = null
var _wake_sprites: Array[Sprite2D] = []
var _trail_particles: GPUParticles2D = null
var _spark_particles: GPUParticles2D = null
var _trail_process: ParticleProcessMaterial = null
var _spark_process: ParticleProcessMaterial = null
var _opacity_tween: Tween = null
var _active := false
var _opacity := 0.0
var _player_center := Vector2.ZERO
var _player_size := DEFAULT_PADDLE_SIZE
var _move_delta := 0.0
var _motion_intensity := 0.0
var _elapsed_sec := 0.0
var _render_scale := 1.0


static func prewarm_assets() -> void:
	if _prewarm_done:
		return
	ImpactFlareTextureCache.get_sparkle_texture()
	ImpactFlareTextureCache.get_glow_texture()
	_build_glow_shader()
	_build_trail_process_material()
	_build_spark_process_material()
	_prewarm_done = true


func _ready() -> void:
	z_as_relative = false
	z_index = Z_INDEX
	_additive_material = _make_additive_material()
	_build_children()
	visible = _active or _opacity > 0.001
	_apply_runtime_state()
	set_process(visible)


func _process(_delta: float) -> void:
	_apply_runtime_state()
	if not _active and _opacity <= 0.001:
		visible = false
		set_process(false)


func sync_state(
	player_center: Vector2,
	player_size: Vector2,
	active: bool,
	move_delta_x: float,
	shake_offset: Vector2,
	fps_scale: float,
	render_scale: float = 1.0
) -> void:
	if _glow_rect == null:
		_build_children()
	var was_active := _active
	_active = active
	visible = _opacity > 0.001 or active
	_player_center = player_center + shake_offset
	_player_size = player_size if player_size.length_squared() > 1.0 else DEFAULT_PADDLE_SIZE
	_move_delta = clamp(move_delta_x, -MAX_TRACKED_DELTA, MAX_TRACKED_DELTA)
	var step: float = max(0.0, fps_scale)
	_elapsed_sec += step * (1.0 / 60.0)
	var motion_target: float = clamp(abs(_move_delta) / MOTION_REFERENCE_PX_PER_FRAME, 0.0, 1.0)
	var blend: float = clamp(step * 0.35, 0.0, 1.0)
	_motion_intensity = lerp(_motion_intensity, motion_target, blend)
	position = _player_center
	_render_scale = max(0.001, render_scale)
	scale = Vector2(_render_scale, _render_scale)
	if active != was_active:
		_animate_opacity(1.0 if active else 0.0)
	_apply_runtime_state()
	if _opacity > 0.001 or _active:
		set_process(true)


func tear_down(free_self: bool = false) -> void:
	_active = false
	_kill_opacity_tween()
	_opacity = 0.0
	_stop_and_clear_particles(_trail_particles)
	_stop_and_clear_particles(_spark_particles)
	visible = false
	set_process(false)
	if free_self:
		queue_free()


func _apply_runtime_state() -> void:
	var alpha: float = clamp(_opacity, 0.0, 1.0)
	if alpha <= 0.001:
		modulate = Color(1.0, 1.0, 1.0, 0.0)
		if _trail_particles != null:
			_trail_particles.emitting = false
		if _spark_particles != null:
			_spark_particles.emitting = false
		if _glow_rect != null:
			_glow_rect.visible = false
		_set_wake_visible(false)
		return
	modulate = Color(1.0, 1.0, 1.0, alpha)
	_update_glow(alpha)
	_update_texture_wake(alpha)
	_update_trail(alpha)
	_update_spark(alpha)


func _update_glow(alpha: float) -> void:
	if _glow_rect == null:
		return
	var width: float = max(48.0, _player_size.x * 1.65)
	var height: float = max(28.0, _player_size.y * 1.55)
	_glow_rect.position = Vector2(-width * 0.5, -height * 0.5)
	_glow_rect.size = Vector2(width, height)
	_glow_rect.visible = true
	if _glow_material != null:
		_glow_material.set_shader_parameter("elapsed", _elapsed_sec)
		_glow_material.set_shader_parameter("motion", _motion_intensity)
		_glow_material.set_shader_parameter("opacity", alpha)
		_glow_material.set_shader_parameter("direction", sign(_move_delta))


func _update_trail(alpha: float) -> void:
	if _trail_particles == null:
		return
	var rate: float = BASE_TRAIL_EMISSION_RATE + MOTION_TRAIL_EMISSION_RATE * _motion_intensity
	_trail_particles.emitting = alpha > 0.02
	_trail_particles.amount_ratio = clamp(0.32 + 0.68 * alpha, 0.0, 1.0)
	if _trail_process != null:
		var half_w: float = _player_size.x * 0.42
		_trail_process.emission_box_extents = Vector3(half_w, _player_size.y * 0.25, 0.0)
		_trail_process.initial_velocity_min = 28.0 + 64.0 * _motion_intensity
		_trail_process.initial_velocity_max = 92.0 + 128.0 * _motion_intensity
		_trail_process.direction = Vector3(-sign(_move_delta) * 0.55, -1.0, 0.0)
		_trail_process.gravity = Vector3(0.0, -42.0, 0.0)
		_trail_process.color = _get_trail_color(alpha)
	_trail_particles.speed_scale = 1.0 + _motion_intensity * 0.55
	if rate <= 0.0:
		_trail_particles.emitting = false


func _update_texture_wake(alpha: float) -> void:
	if _wake_sprites.is_empty():
		return
	var direction: float = sign(_move_delta)
	var texture_size: float = float(ImpactFlareTextureCache.SPARKLE_TEXTURE_SIZE)
	if is_zero_approx(direction):
		for i in range(_wake_sprites.size()):
			var idle_sprite: Sprite2D = _wake_sprites[i]
			var idle_side: float = -1.0 if i % 2 == 0 else 1.0
			var idle_rank: float = floor(float(i) * 0.5)
			var idle_size: float = 13.0 + idle_rank * 2.5
			var idle_alpha: float = alpha * (0.16 - idle_rank * 0.018)
			var idle_pulse: float = 0.72 + 0.28 * sin(_elapsed_sec * 5.7 + float(i) * 1.91)
			idle_sprite.visible = idle_alpha > 0.015
			idle_sprite.position = Vector2(
				idle_side * (_player_size.x * (0.26 + idle_rank * 0.05)),
				_player_size.y * 0.28 + sin(_elapsed_sec * 4.1 + float(i)) * 2.5
			)
			idle_sprite.scale = Vector2.ONE * idle_size / max(1.0, texture_size)
			idle_sprite.rotation = _elapsed_sec * (0.45 + idle_rank * 0.16) * idle_side
			idle_sprite.modulate = Color(0.78, 0.94, 1.0, max(0.0, idle_alpha * idle_pulse))
		return
	var wake_strength: float = clamp(0.24 + _motion_intensity * 0.88, 0.0, 1.0)
	for i in range(_wake_sprites.size()):
		var sprite: Sprite2D = _wake_sprites[i]
		var t: float = float(i) / max(1.0, float(_wake_sprites.size() - 1))
		var back_distance: float = _player_size.x * (0.28 + t * 0.68)
		var side_wave: float = sin(_elapsed_sec * (7.0 + t * 2.0) + float(i) * 1.73)
		var sprite_size: float = lerp(24.0, 10.0, t) * (0.88 + 0.18 * side_wave)
		var twinkle: float = 0.66 + 0.34 * sin(_elapsed_sec * (9.0 + t * 4.0) + float(i) * 2.37)
		var sprite_alpha: float = alpha * wake_strength * pow(1.0 - t * 0.78, 1.35) * twinkle
		sprite.visible = sprite_alpha > 0.02
		sprite.position = Vector2(
			-direction * back_distance,
			_player_size.y * (0.12 + t * 0.20) + side_wave * (4.0 + t * 6.0)
		)
		sprite.scale = Vector2.ONE * sprite_size / max(1.0, texture_size)
		sprite.rotation = _elapsed_sec * (0.9 + t * 1.8) * direction + t * PI
		sprite.modulate = Color(
			lerp(0.70, 1.0, t),
			lerp(0.92, 0.98, t),
			1.0,
			clamp(sprite_alpha, 0.0, 0.76)
		)


func _update_spark(alpha: float) -> void:
	if _spark_particles == null:
		return
	var trigger: bool = _motion_intensity > 0.18 and alpha > 0.05
	_spark_particles.emitting = trigger
	if _spark_process != null:
		var half_w: float = _player_size.x * 0.45
		_spark_process.emission_box_extents = Vector3(half_w, _player_size.y * 0.18, 0.0)
		_spark_process.initial_velocity_min = 18.0 + 36.0 * _motion_intensity
		_spark_process.initial_velocity_max = 64.0 + 84.0 * _motion_intensity
		_spark_process.color = _get_spark_color(alpha)


func _get_trail_color(alpha: float) -> Color:
	var warmth: float = 0.55 + _motion_intensity * 0.35
	return Color(
		clamp(0.74 + warmth * 0.20, 0.0, 1.0),
		clamp(0.86 + warmth * 0.12, 0.0, 1.0),
		1.0,
		(0.55 + 0.30 * alpha) * (0.55 + 0.45 * alpha)
	)


func _get_spark_color(alpha: float) -> Color:
	return Color(1.0, 0.96, 0.62, 0.78 * alpha)


func _animate_opacity(target: float) -> void:
	_kill_opacity_tween()
	if not is_inside_tree():
		_opacity = target
		return
	var duration: float = FADE_IN_SEC if target > _opacity else FADE_OUT_SEC
	_opacity_tween = create_tween()
	_opacity_tween.tween_property(self, "_opacity", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kill_opacity_tween() -> void:
	if _opacity_tween != null and _opacity_tween.is_valid():
		_opacity_tween.kill()
	_opacity_tween = null


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _glow_rect == null:
		_glow_rect = ColorRect.new()
		_glow_rect.name = "HermesShoesUnderGlow"
		_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow_rect.color = Color.WHITE
		_glow_material = _build_glow_shader()
		_glow_rect.material = _glow_material
		_glow_rect.z_index = -2
		_glow_rect.visible = false
		add_child(_glow_rect)
	if _wake_sprites.is_empty():
		for i in range(WAKE_SPRITE_COUNT):
			var sprite := Sprite2D.new()
			sprite.name = "HermesShoesWakeSparkle%d" % i
			sprite.centered = true
			sprite.texture = ImpactFlareTextureCache.get_sparkle_texture()
			sprite.material = _additive_material
			sprite.z_index = 1 + i
			sprite.visible = false
			add_child(sprite)
			_wake_sprites.append(sprite)
	if _trail_particles == null:
		_trail_particles = GPUParticles2D.new()
		_trail_particles.name = "HermesShoesSparkleTrail"
		_trail_particles.amount = TRAIL_PARTICLE_AMOUNT
		_trail_particles.lifetime = TRAIL_PARTICLE_LIFETIME
		_trail_particles.one_shot = false
		_trail_particles.explosiveness = 0.0
		_trail_particles.randomness = 0.78
		_trail_particles.fixed_fps = 60
		_trail_particles.local_coords = false
		_trail_particles.visibility_rect = Rect2(
			-VISIBILITY_PADDING,
			-VISIBILITY_PADDING,
			VISIBILITY_PADDING * 2.0,
			VISIBILITY_PADDING * 2.0
		)
		_trail_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_trail_particles.material = _additive_material
		_trail_process = _build_trail_process_material()
		_trail_particles.process_material = _trail_process
		_trail_particles.z_index = 0
		_trail_particles.emitting = false
		add_child(_trail_particles)
	if _spark_particles == null:
		_spark_particles = GPUParticles2D.new()
		_spark_particles.name = "HermesShoesSparkleAccents"
		_spark_particles.amount = SPARK_PARTICLE_AMOUNT
		_spark_particles.lifetime = SPARK_PARTICLE_LIFETIME
		_spark_particles.one_shot = false
		_spark_particles.explosiveness = 0.0
		_spark_particles.randomness = 0.92
		_spark_particles.fixed_fps = 60
		_spark_particles.local_coords = false
		_spark_particles.visibility_rect = Rect2(
			-VISIBILITY_PADDING,
			-VISIBILITY_PADDING,
			VISIBILITY_PADDING * 2.0,
			VISIBILITY_PADDING * 2.0
		)
		_spark_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_spark_particles.material = _additive_material
		_spark_process = _build_spark_process_material()
		_spark_particles.process_material = _spark_process
		_spark_particles.z_index = 8
		_spark_particles.emitting = false
		add_child(_spark_particles)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_glow_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float motion = 0.0;
uniform float opacity = 0.0;
uniform float direction = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	p.x *= 1.45;
	float r = length(p);
	float halo = pow(max(0.0, 1.0 - r), 2.6);
	float core = pow(max(0.0, 1.0 - r * 1.8), 4.2);
	float sweep_phase = elapsed * (3.4 + motion * 2.6) + direction * 0.6;
	float sweep = smoothstep(0.45, 0.10, abs(p.x - sin(sweep_phase) * 0.62));
	sweep *= pow(max(0.0, 1.0 - abs(p.y)), 1.7);
	float scan = 0.5 + 0.5 * sin((UV.x + UV.y * 0.18) * 26.0 + elapsed * 6.0);
	vec3 cool = vec3(0.62, 0.90, 1.0);
	vec3 warm = vec3(1.0, 0.94, 0.58);
	vec3 color = mix(cool, warm, clamp(motion * 0.7 + sweep * 0.5, 0.0, 1.0));
	float alpha = (halo * 0.16 + core * 0.22 + sweep * 0.32) * opacity;
	alpha *= 0.65 + 0.35 * scan;
	COLOR = vec4(color, clamp(alpha, 0.0, 0.55));
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	return shader_material


static func _build_trail_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(DEFAULT_PADDLE_SIZE.x * 0.42, DEFAULT_PADDLE_SIZE.y * 0.25, 0.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 32.0
	mat.gravity = Vector3(0.0, -42.0, 0.0)
	mat.initial_velocity_min = 28.0
	mat.initial_velocity_max = 96.0
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	mat.damping_min = 22.0
	mat.damping_max = 64.0
	mat.scale_min = 0.060
	mat.scale_max = 0.145
	mat.color = Color(0.84, 0.94, 1.0, 0.74)
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.18, 1.0))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_texture := CurveTexture.new()
	alpha_texture.curve = alpha_curve
	mat.alpha_curve = alpha_texture
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.6))
	scale_curve.add_point(Vector2(0.35, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.2))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	mat.scale_curve = scale_texture
	return mat


static func _build_spark_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(DEFAULT_PADDLE_SIZE.x * 0.45, DEFAULT_PADDLE_SIZE.y * 0.18, 0.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 64.0
	mat.gravity = Vector3(0.0, -16.0, 0.0)
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 84.0
	mat.angular_velocity_min = -240.0
	mat.angular_velocity_max = 240.0
	mat.damping_min = 10.0
	mat.damping_max = 32.0
	mat.scale_min = 0.040
	mat.scale_max = 0.105
	mat.color = Color(1.0, 0.96, 0.62, 0.86)
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.12, 1.0))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_texture := CurveTexture.new()
	alpha_texture.curve = alpha_curve
	mat.alpha_curve = alpha_texture
	return mat


func _set_wake_visible(next_visible: bool) -> void:
	for sprite in _wake_sprites:
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = next_visible


func _stop_and_clear_particles(particles: GPUParticles2D) -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.restart()
	particles.emitting = false


func get_debug_status() -> Dictionary:
	var visible_wake_count := 0
	for sprite in _wake_sprites:
		if sprite != null and is_instance_valid(sprite) and sprite.visible:
			visible_wake_count += 1
	return {
		"active": _active,
		"visible": visible,
		"opacity": _opacity,
		"position": position,
		"scale": scale,
		"z_index": z_index,
		"render_scale": _render_scale,
		"glow_visible": _glow_rect != null and _glow_rect.visible,
		"wake_sprite_count": _wake_sprites.size(),
		"wake_visible_count": visible_wake_count,
		"trail_emitting": _trail_particles != null and _trail_particles.emitting,
		"trail_local_coords": _trail_particles != null and _trail_particles.local_coords,
		"spark_emitting": _spark_particles != null and _spark_particles.emitting,
		"spark_local_coords": _spark_particles != null and _spark_particles.local_coords,
	}
