extends Node2D

# 홍련폭염 준비기간(phase 1) 화염 응축 VFX 호스트.
# 모듈러 VFX 레이어링 1차 구현 - WritheEmber 셰이더 쿼드 + inward GPUParticles2D.
# playfield_renderer의 direct-draw aura는 fallback으로 그대로 유지된다.

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

const BASE_QUAD_SIZE := 240.0
const MIN_QUAD_SIZE := 110.0
const EMBER_PARTICLE_AMOUNT := 36
const PARTICLE_FIXED_FPS := 30
const PEAK_RATIO_THRESHOLD := 0.65
const HEAT_TEXTURE_SIZE := 192

var elapsed_sec := 0.0

var _state: Dictionary = {}
var _heat_sprite: Sprite2D = null
var _heat_material: ShaderMaterial = null
var _ember_particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null
var _current_preset := ""

static var _heat_texture: ImageTexture = null
static var _prewarmed := false


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	ImpactFlareTextureCache.prewarm()
	WritheEmber.prewarm()
	_get_heat_texture()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"stage5_hongryun_inferno_charge_shader_ready": (
			WritheEmber.has_preset("hongryun_inferno_charge")
			and WritheEmber.has_preset("hongryun_inferno_charge_peak")
		),
		"stage5_hongryun_inferno_charge_heat_texture_ready": _get_heat_texture() != null,
		"stage5_hongryun_inferno_charge_particle_amount": EMBER_PARTICLE_AMOUNT,
	}


func _ready() -> void:
	z_as_relative = false
	z_index = 12
	_additive_material = _make_additive_material()
	_build_children()
	set_active(visible and not _state.is_empty())


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _heat_sprite == null:
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and can_handle_state(_state))
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func can_handle_state(next_state: Dictionary) -> bool:
	return bool(next_state.get("phase_active", false))


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if not active:
		if _heat_sprite != null:
			_heat_sprite.visible = false
		if _ember_particles != null:
			_ember_particles.emitting = false
		_current_preset = ""
		return


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"preset": _current_preset,
		"heat_texture_ready": _get_heat_texture() != null,
		"shader_ready": _heat_material != null and WritheEmber.is_material_using_shader(_heat_material),
		"ember_emitting": _ember_particles != null and _ember_particles.emitting,
	}


func _apply_state() -> void:
	if _heat_sprite == null:
		return
	var ball_pos: Vector2 = _as_vector2(_state.get("ball_pos", Vector2(380.0, 375.0)), Vector2(380.0, 375.0))
	var ratio: float = clamp(float(_state.get("charge_ratio", 0.0)), 0.0, 1.0)
	var enraged: bool = bool(_state.get("enraged", false))
	var quality_scale: float = clamp(float(_state.get("quality_scale", 1.0)), 0.0, 1.0)

	# Choose preset by charge progress. Switch to peak variant in last third
	# OR when boss is enraged (low HP) for hotter look.
	var preset_name := "hongryun_inferno_charge"
	if ratio >= PEAK_RATIO_THRESHOLD or enraged:
		preset_name = "hongryun_inferno_charge_peak"
	if preset_name != _current_preset:
		WritheEmber.apply_preset(_heat_material, preset_name)
		_current_preset = preset_name

	# Compression: quad shrinks from 240 → 110 as ratio approaches 1.0.
	var quad_size: float = lerp(BASE_QUAD_SIZE, MIN_QUAD_SIZE, _ease_in_cubic(ratio))
	_heat_sprite.position = ball_pos
	var heat_texture := _get_heat_texture()
	if heat_texture != null:
		var tex_size: Vector2 = heat_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			_heat_sprite.scale = Vector2(quad_size / tex_size.x, quad_size / tex_size.y)
	_heat_sprite.visible = true

	# Brightness/alpha ramps with ratio; subtle breath via shader handles
	# the lower-frequency pulse, so we only need the global envelope here.
	var base_alpha: float = 0.32 + ratio * 0.55
	if enraged:
		base_alpha = min(1.0, base_alpha + 0.10)
	# Quality-scale damping so low-LOD machines do not over-blend.
	base_alpha *= 0.55 + 0.45 * quality_scale
	_heat_sprite.modulate = Color(1.0, 1.0, 1.0, clamp(base_alpha, 0.0, 1.0))

	if _heat_material != null:
		_heat_material.set_shader_parameter("elapsed", elapsed_sec)
		_heat_material.set_shader_parameter("intensity", 0.85 + ratio * 0.35)

	# Inward ember particles ring around the ball.
	if _ember_particles != null:
		_ember_particles.position = ball_pos
		var particle_scale: float = 0.85 + ratio * 0.35
		_ember_particles.scale = Vector2(particle_scale, particle_scale)
		# LOD gate: drop particles on severe quality LOD.
		var allow_particles: bool = quality_scale >= 0.55
		_ember_particles.emitting = allow_particles
		var process_mat: ParticleProcessMaterial = _ember_particles.process_material
		if process_mat != null:
			var ember_color := Color(1.0, 0.46, 0.16, 0.62 + ratio * 0.30)
			if enraged:
				ember_color = Color(1.0, 0.30, 0.10, 0.74 + ratio * 0.24)
			process_mat.color = ember_color
			# Pull harder toward center as compression peaks.
			process_mat.radial_accel_min = -120.0 - 220.0 * ratio
			process_mat.radial_accel_max = -60.0 - 140.0 * ratio
			# Ring radius shrinks slightly so spawn band hugs the compression.
			var ring_radius: float = 86.0 - 26.0 * ratio
			process_mat.emission_ring_radius = ring_radius
			process_mat.emission_ring_inner_radius = max(8.0, ring_radius - 22.0)


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()

	if _heat_sprite == null:
		_heat_sprite = Sprite2D.new()
		_heat_sprite.name = "InfernoChargeHeatCore"
		_heat_sprite.centered = true
		_heat_sprite.texture = _get_heat_texture()
		_heat_sprite.material = WritheEmber.build_material("hongryun_inferno_charge")
		_heat_sprite.visible = false
		_heat_sprite.z_index = 0
		add_child(_heat_sprite)
		_heat_material = _heat_sprite.material as ShaderMaterial
		_current_preset = "hongryun_inferno_charge"

	if _ember_particles == null:
		_ember_particles = GPUParticles2D.new()
		_ember_particles.name = "InfernoChargeEmberParticles"
		_ember_particles.amount = EMBER_PARTICLE_AMOUNT
		_ember_particles.lifetime = 0.65
		_ember_particles.one_shot = false
		_ember_particles.explosiveness = 0.0
		_ember_particles.randomness = 0.92
		_ember_particles.fixed_fps = PARTICLE_FIXED_FPS
		_ember_particles.local_coords = true
		_ember_particles.visibility_rect = Rect2(-220.0, -220.0, 440.0, 440.0)
		_ember_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_ember_particles.material = _additive_material
		_ember_particles.process_material = _build_inward_ember_material()
		_ember_particles.emitting = false
		_ember_particles.z_index = 2
		add_child(_ember_particles)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_inward_ember_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 12.0
	# Negative radial accel = pull inward toward emission center.
	mat.radial_accel_min = -180.0
	mat.radial_accel_max = -100.0
	mat.tangential_accel_min = -60.0
	mat.tangential_accel_max = 60.0
	mat.damping_min = 12.0
	mat.damping_max = 38.0
	mat.scale_min = 0.022
	mat.scale_max = 0.060
	mat.color = Color(1.0, 0.46, 0.16, 0.62)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 86.0
	mat.emission_ring_inner_radius = 62.0
	mat.emission_ring_height = 0.0
	return mat


# Procedural radial heat field pattern. Produces concentric "flame curl"
# rings the WritheEmber shader can warp into living embers without needing
# a new imagegen PNG. Built once and shared.
static func _get_heat_texture() -> ImageTexture:
	if _heat_texture != null:
		return _heat_texture
	var size := HEAT_TEXTURE_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = (float(size) - 1.0) * 0.5
	var max_dist: float = max(1.0, center)
	for y in range(size):
		var dy: float = (float(y) - center) / max_dist
		for x in range(size):
			var dx: float = (float(x) - center) / max_dist
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist >= 1.0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			# Concentric ring pattern with falloff toward edge.
			var rings: float = 0.5 + 0.5 * sin(dist * 14.0 - 1.2)
			rings = pow(rings, 1.6)
			# Soft outer falloff so corners are clean and rotation/scale
			# does not bake square fringes.
			var radial_falloff: float = pow(max(0.0, 1.0 - dist), 1.4)
			# Hot core bias keeps the center bright before the shader warps.
			var core: float = pow(max(0.0, 1.0 - dist * 1.8), 2.0) * 0.85
			var alpha: float = clamp(rings * radial_falloff * 0.78 + core, 0.0, 1.0)
			var r: float = 1.0
			var g: float = clamp(0.18 + 0.50 * radial_falloff + 0.25 * core, 0.0, 1.0)
			var b: float = clamp(0.05 + 0.15 * core, 0.0, 1.0)
			image.set_pixel(x, y, Color(r, g, b, alpha))
	_heat_texture = ImageTexture.create_from_image(image)
	return _heat_texture


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _ease_in_cubic(t: float) -> float:
	return t * t * t
