extends Node2D

# Screen-space cyan energy burst for the defeat chance-gem shatter.
# The host is driven by the modal continue screen's elapsed shatter progress,
# not by physics. It owns one WritheEmber quad plus a bounded cyan sparkle
# particle layer, and has one cleanup path through set_active(false).

const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const HOST_NAME := "DefeatGemShatterFxHost"
const PRESET_NAME := "chance_gem_shatter_cyan"
const Z_INDEX := 1240
const REF_HEIGHT := 720.0
const QUALITY_GATE := 0.45
const ACTIVE_SYNC_GRACE_MSEC := 160
const QUAD_TEXTURE_SIZE := 128
const QUAD_BASE_SCALE := 1.34
const PARTICLE_AMOUNT := 40
const PARTICLE_FIXED_FPS := 30
const ERUPT_END := 0.15
const COLLAPSE_START := 0.70

static var _prewarmed := false
static var _quad_texture: ImageTexture = null
static var _spark_texture: Texture2D = null
static var _burst_texture: Texture2D = null
static var _prewarm_material: ShaderMaterial = null
static var _spark_process_material: ParticleProcessMaterial = null

var _burst_sprite: Sprite2D = null
var _energy_sprite: Sprite2D = null
var _spark_particles: GPUParticles2D = null
var _energy_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _last_active_sync_msec: int = 0
var _last_intensity: float = 0.0
var _last_progress: float = 0.0


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	WritheEmber.prewarm()
	ImpactFlareTextureCache.prewarm()
	_quad_texture = _get_quad_texture()
	_spark_texture = ImpactFlareTextureCache.get_sparkle_texture()
	_burst_texture = ImpactFlareTextureCache.get_burst_texture()
	_prewarm_material = WritheEmber.build_material(PRESET_NAME)
	_spark_process_material = _build_spark_process_material()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"preset_ready": WritheEmber.has_preset(PRESET_NAME),
		"quad_texture_ready": _quad_texture != null,
		"spark_texture_ready": _spark_texture != null,
		"burst_texture_ready": _burst_texture != null,
		"spark_amount": PARTICLE_AMOUNT,
		"fixed_fps": PARTICLE_FIXED_FPS,
		"z_index": Z_INDEX,
	}


static func _get_quad_texture() -> ImageTexture:
	if _quad_texture != null:
		return _quad_texture
	var image := Image.create(QUAD_TEXTURE_SIZE, QUAD_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(QUAD_TEXTURE_SIZE - 1) * 0.5, float(QUAD_TEXTURE_SIZE - 1) * 0.5)
	var radius := float(QUAD_TEXTURE_SIZE) * 0.46
	for y in range(QUAD_TEXTURE_SIZE):
		for x in range(QUAD_TEXTURE_SIZE):
			var rel := (Vector2(float(x), float(y)) - center) / radius
			var dist := rel.length()
			if dist >= 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			var angle := atan2(rel.y, rel.x)
			var edge_fade := 1.0 - _smoothstep(0.72, 1.0, dist)
			var inner_fade := _smoothstep(0.10, 0.24, dist)
			var branch_a := pow(maxf(0.0, 0.5 + 0.5 * sin(angle * 9.0 + dist * 18.0)), 6.0)
			var branch_b := pow(maxf(0.0, 0.5 + 0.5 * sin(angle * 15.0 - dist * 24.0)), 9.0)
			var core := pow(1.0 - dist, 2.8) * 0.34
			var alpha := clampf((core + (branch_a * 0.72 + branch_b * 0.55) * inner_fade) * edge_fade, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_quad_texture = ImageTexture.create_from_image(image)
	return _quad_texture


func _ready() -> void:
	z_as_relative = false
	z_index = Z_INDEX
	_additive_material = _make_additive_material()
	_build_children()
	set_active(false)


func sync_state(state: Dictionary, active: bool) -> void:
	if _energy_sprite == null or _spark_particles == null:
		set_active(false)
		return
	var view_size: Vector2 = _as_vector2(state.get("view_size", Vector2.ZERO), Vector2.ZERO)
	var gem_center: Vector2 = _as_vector2(state.get("gem_center", Vector2.ZERO), Vector2.ZERO)
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		set_active(false)
		return
	var quality_scale := clampf(float(state.get("quality_scale", 1.0)), 0.0, 1.0)
	var progress := clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	var envelope := _energy_envelope(progress)
	var intensity := envelope * (0.80 + quality_scale * 0.28)
	var allow := active and quality_scale >= QUALITY_GATE and intensity > 0.01 and progress < 1.0
	set_active(allow)
	if not visible:
		return
	_last_active_sync_msec = Time.get_ticks_msec()
	_last_progress = progress
	_last_intensity = intensity
	position = gem_center
	var s := view_size.y / REF_HEIGHT
	scale = Vector2(s, s)
	var erupt := 1.0 - clampf(progress / ERUPT_END, 0.0, 1.0)
	var collapse := clampf((progress - COLLAPSE_START) / (1.0 - COLLAPSE_START), 0.0, 1.0)
	var quad_scale := QUAD_BASE_SCALE + envelope * 0.28 + erupt * 0.24 - collapse * 0.10
	if _energy_sprite != null:
		_energy_sprite.scale = Vector2(quad_scale, quad_scale)
		_energy_sprite.modulate = Color(1.0, 1.0, 1.0, clampf(0.22 + intensity * 0.78 + erupt * 0.10, 0.0, 0.85))
	if _burst_sprite != null:
		var burst_alpha := clampf(0.08 + intensity * 0.34 + erupt * 0.20, 0.0, 0.48)
		var burst_scale := quad_scale * (1.12 + envelope * 0.20 + erupt * 0.14)
		_burst_sprite.scale = Vector2(burst_scale, burst_scale)
		_burst_sprite.rotation = float(state.get("elapsed", 0.0)) * 0.42
		_burst_sprite.modulate = Color(0.44, 0.82, 1.0, burst_alpha)
	if _energy_material != null:
		_energy_material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
		_energy_material.set_shader_parameter("intensity", intensity)
	if _spark_particles != null:
		_spark_particles.emitting = progress >= 0.035 and progress <= 0.92 and intensity > 0.045


func _process(_delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if Time.get_ticks_msec() - _last_active_sync_msec > ACTIVE_SYNC_GRACE_MSEC:
		set_active(false)


func set_active(active: bool) -> void:
	var was_active := visible
	visible = active
	set_process(active)
	if _burst_sprite != null:
		_burst_sprite.visible = active
	if _energy_sprite != null:
		_energy_sprite.visible = active
	if _spark_particles != null and not active:
		_spark_particles.emitting = false
	if _spark_particles != null and active and not was_active:
		_spark_particles.restart()
		_spark_particles.emitting = true
	if not active:
		_last_intensity = 0.0
		_last_progress = 0.0


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"burst_visible": _burst_sprite != null and _burst_sprite.visible,
		"z_as_relative": z_as_relative,
		"z_index": z_index,
		"particles_emitting": _spark_particles != null and _spark_particles.emitting,
		"particle_amount": _spark_particles.amount if _spark_particles != null else 0,
		"particle_fixed_fps": _spark_particles.fixed_fps if _spark_particles != null else 0,
		"local_coords": _spark_particles.local_coords if _spark_particles != null else false,
		"preset_ready": WritheEmber.has_preset(PRESET_NAME),
		"intensity": _last_intensity,
		"progress": _last_progress,
		"position": position,
		"scale": scale,
	}


func force_timeout_for_test() -> void:
	_last_active_sync_msec = Time.get_ticks_msec() - ACTIVE_SYNC_GRACE_MSEC - 1
	_process(0.0)


func _build_children() -> void:
	prewarm_assets()
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _burst_sprite == null:
		_burst_sprite = Sprite2D.new()
		_burst_sprite.name = "CyanGemShatterBurst"
		_burst_sprite.centered = true
		_burst_sprite.texture = _burst_texture
		_burst_sprite.material = _additive_material
		_burst_sprite.visible = false
		_burst_sprite.z_index = -1
		add_child(_burst_sprite)
	if _energy_sprite == null:
		_energy_sprite = Sprite2D.new()
		_energy_sprite.name = "CyanGemShatterWritheQuad"
		_energy_sprite.centered = true
		_energy_sprite.texture = _get_quad_texture()
		_energy_material = WritheEmber.build_material(PRESET_NAME)
		_energy_material.set_shader_parameter("intensity", 0.0)
		_energy_sprite.material = _energy_material
		_energy_sprite.visible = false
		_energy_sprite.z_index = 0
		add_child(_energy_sprite)
	if _spark_particles == null:
		_spark_particles = GPUParticles2D.new()
		_spark_particles.name = "CyanGemShatterSparks"
		_spark_particles.amount = PARTICLE_AMOUNT
		_spark_particles.lifetime = 0.48
		_spark_particles.one_shot = false
		_spark_particles.explosiveness = 0.18
		_spark_particles.randomness = 0.82
		_spark_particles.fixed_fps = PARTICLE_FIXED_FPS
		_spark_particles.local_coords = true
		_spark_particles.visibility_rect = Rect2(-190.0, -190.0, 380.0, 380.0)
		_spark_particles.texture = _spark_texture
		_spark_particles.material = _additive_material
		_spark_particles.process_material = _spark_process_material.duplicate()
		_spark_particles.emitting = false
		_spark_particles.z_index = 1
		add_child(_spark_particles)


static func _build_spark_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, 18.0, 0.0)
	mat.initial_velocity_min = 54.0
	mat.initial_velocity_max = 150.0
	mat.radial_accel_min = 28.0
	mat.radial_accel_max = 110.0
	mat.tangential_accel_min = -64.0
	mat.tangential_accel_max = 64.0
	mat.damping_min = 18.0
	mat.damping_max = 42.0
	mat.scale_min = 0.026
	mat.scale_max = 0.078
	mat.color = Color(0.58, 0.92, 1.0, 1.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 38.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.12, Color(0.82, 1.0, 1.0, 0.95))
	ramp.add_point(0.42, Color(0.32, 0.66, 1.0, 0.72))
	ramp.add_point(0.78, Color(0.20, 0.42, 1.0, 0.20))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


static func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _energy_envelope(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if p < ERUPT_END:
		return _ease_out_cubic(p / ERUPT_END)
	if p < COLLAPSE_START:
		var sustain := (p - ERUPT_END) / (COLLAPSE_START - ERUPT_END)
		return 0.88 + 0.08 * sin(sustain * PI * 3.0)
	return 1.0 - _ease_in_out_cubic((p - COLLAPSE_START) / (1.0 - COLLAPSE_START))


static func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func _ease_in_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
