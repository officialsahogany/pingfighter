extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

const GLYPH_TEXTURE_PATH := "res://assets/sprites/characters/viper/chaos_spear/viper_chaos_glyph_imagegen_v1.png"
const SPEAR_TEXTURE_PATH := "res://assets/sprites/characters/viper/chaos_spear/viper_chaos_spear_silhouette_imagegen_v1.png"
const TRAIL_TEXTURE_PATH := "res://assets/sprites/characters/viper/chaos_spear/viper_chaos_spear_trail_imagegen_v1.png"
const IMPACT_BURST_TEXTURE_PATH := "res://assets/sprites/characters/viper/chaos_spear/viper_chaos_impact_burst_imagegen_v1.png"
const CRACKS_TEXTURE_PATH := "res://assets/sprites/characters/viper/chaos_spear/viper_chaos_cracks_pattern_imagegen_v1.png"
const QUAD_ASPECT := 2.6
const BASE_HEIGHT := 200.0
const OPEN_SCALE_DURATION_SEC := 0.55
const OPEN_BRIGHTNESS_DURATION_SEC := 0.65
const RING_BASE_RADIUS_LOCAL := 110.0
const ORBIT_BASE_RADIUS_LOCAL := 60.0
const PHASE3_BURST_IN_RATIO := 0.28
const PHASE3_BURST_HOLD_RATIO := 0.28
const PARTICLE_FIXED_FPS := 30
const INFLOW_PARTICLE_AMOUNT := 48
const ORBIT_PARTICLE_AMOUNT := 36
const STORM_PARTICLE_AMOUNT := 56
const EMBER_PARTICLE_AMOUNT := 32
const CHARGE_PARTICLE_AMOUNT := 28

var elapsed_sec := 0.0
var pulse_value := 0.0
var breath_value := 0.0
var _cracks_intensity := 0.0

var _state: Dictionary = {}
var _last_spawn_msec: int = 0
var _open_msec: int = -1
var _last_alpha: float = 0.0
var _cracks_phase_key := ""
var _cracks_preset_name := ""

var _cracks_sprite: Sprite2D = null
var _glyph_sprite: Sprite2D = null
var _disk_quad: ColorRect = null
var _disk_material: ShaderMaterial = null
var _inflow_particles: GPUParticles2D = null
var _orbit_particles: GPUParticles2D = null
var _storm_particles: GPUParticles2D = null
var _ember_particles: GPUParticles2D = null
var _charge_particles: GPUParticles2D = null
var _trail_sprite: Sprite2D = null
var _spear_sprite: Sprite2D = null
var _impact_sprite: Sprite2D = null
var _glyph_material: ShaderMaterial = null
var _trail_material: ShaderMaterial = null
var _impact_material: ShaderMaterial = null
var _cracks_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _pulse_tween: Tween = null
var _breath_tween: Tween = null
var _cracks_intensity_tween: Tween = null

static var _glyph_texture: Texture2D = null
static var _spear_texture: Texture2D = null
static var _trail_texture: Texture2D = null
static var _impact_burst_texture: Texture2D = null
static var _cracks_texture: Texture2D = null
static var _texture_layer_shader: Shader = null
static var _prewarmed := false
static var _prewarm_step_index := 0

static func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


static func prewarm_assets_step() -> bool:
	if _prewarmed:
		return true
	match _prewarm_step_index:
		0:
			ImpactFlareTextureCache.prewarm()
		1:
			_get_glyph_texture()
		2:
			_get_spear_texture()
		3:
			_get_trail_texture()
		4:
			_get_impact_burst_texture()
		5:
			_get_cracks_texture()
		6:
			_get_texture_layer_shader()
		7:
			WritheEmber.prewarm()
		8:
			_build_disk_material()
		9:
			_build_inflow_particle_material()
		10:
			_build_orbit_particle_material()
		11:
			_build_storm_particle_material()
		12:
			_build_ember_particle_material()
		13:
			_build_charge_particle_material()
		_:
			_prewarmed = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"chaos_spear_shader_host_pipeline": (
			_get_texture_layer_shader() != null
			and WritheEmber.has_preset("chaos_cracks")
			and _build_disk_material() != null
		),
		"chaos_spear_shader_layers": 5,
		"chaos_spear_gpu_particle_layers": 5,
		"chaos_spear_texture_pieces_ready": (
			_is_png_texture_loaded(GLYPH_TEXTURE_PATH, _get_glyph_texture())
			and _is_png_texture_loaded(SPEAR_TEXTURE_PATH, _get_spear_texture())
			and _is_png_texture_loaded(TRAIL_TEXTURE_PATH, _get_trail_texture())
			and _is_png_texture_loaded(IMPACT_BURST_TEXTURE_PATH, _get_impact_burst_texture())
			and _is_png_texture_loaded(CRACKS_TEXTURE_PATH, _get_cracks_texture())
		),
		"chaos_spear_glyph_png_slot": _is_png_texture_loaded(GLYPH_TEXTURE_PATH, _get_glyph_texture()),
		"chaos_spear_silhouette_png_slot": _is_png_texture_loaded(SPEAR_TEXTURE_PATH, _get_spear_texture()),
		"chaos_spear_trail_png_slot": _is_png_texture_loaded(TRAIL_TEXTURE_PATH, _get_trail_texture()),
		"chaos_spear_impact_burst_png_slot": _is_png_texture_loaded(IMPACT_BURST_TEXTURE_PATH, _get_impact_burst_texture()),
		"chaos_spear_cracks_png_slot": _is_png_texture_loaded(CRACKS_TEXTURE_PATH, _get_cracks_texture()),
		"chaos_spear_glyph_texture_path": GLYPH_TEXTURE_PATH,
		"chaos_spear_silhouette_texture_path": SPEAR_TEXTURE_PATH,
		"chaos_spear_trail_texture_path": TRAIL_TEXTURE_PATH,
		"chaos_spear_impact_burst_texture_path": IMPACT_BURST_TEXTURE_PATH,
		"chaos_spear_cracks_texture_path": CRACKS_TEXTURE_PATH,
	}


func _ready() -> void:
	var should_remain_active := visible and not _state.is_empty()
	z_as_relative = false
	z_index = 16
	_additive_material = _make_additive_material()
	_build_children()
	_start_tweens()
	set_active(should_remain_active and can_handle_state(_state))
	if should_remain_active:
		_apply_state()
		queue_redraw()


func prewarm_runtime_nodes() -> void:
	prewarm_assets()
	if _additive_material == null:
		_additive_material = _make_additive_material()
	_build_children()
	set_active(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _disk_quad == null:
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and can_handle_state(_state))
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func set_active(active: bool) -> void:
	var was_active := visible
	visible = active
	set_process(false)
	if not active:
		if _cracks_sprite != null:
			_cracks_sprite.visible = false
		if _glyph_sprite != null:
			_glyph_sprite.visible = false
		_kill_cracks_intensity_tween()
		if _inflow_particles != null:
			_inflow_particles.emitting = false
		if _orbit_particles != null:
			_orbit_particles.emitting = false
		if _storm_particles != null:
			_storm_particles.emitting = false
		if _ember_particles != null:
			_ember_particles.emitting = false
		if _charge_particles != null:
			_charge_particles.emitting = false
		if _disk_quad != null:
			_disk_quad.visible = false
		if _trail_sprite != null:
			_trail_sprite.visible = false
		if _spear_sprite != null:
			_spear_sprite.visible = false
		if _impact_sprite != null:
			_impact_sprite.visible = false
		_last_spawn_msec = 0
		_open_msec = -1
		_last_alpha = 0.0
		_cracks_phase_key = ""
		_cracks_preset_name = ""
		_cracks_intensity = 0.0
		return
	if was_active:
		return
	if _cracks_sprite != null:
		_cracks_sprite.visible = false
	if _glyph_sprite != null:
		_glyph_sprite.visible = false
	if _disk_quad != null:
		_disk_quad.visible = false
	if _trail_sprite != null:
		_trail_sprite.visible = false
	if _spear_sprite != null:
		_spear_sprite.visible = false
	if _impact_sprite != null:
		_impact_sprite.visible = false
	if _inflow_particles != null:
		_inflow_particles.emitting = false
	if _orbit_particles != null:
		_orbit_particles.emitting = false
	if _storm_particles != null:
		_storm_particles.emitting = false
	if _ember_particles != null:
		_ember_particles.emitting = false
	if _charge_particles != null:
		_charge_particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null
	_kill_cracks_intensity_tween()
	if free_self:
		queue_free()


func _apply_state() -> void:
	if _state.is_empty() or _disk_quad == null:
		return
	var phase: String = str(_state.get("phase", "blackhole"))
	var target_center: Vector2 = _as_vector2(_state.get("screen_center", Vector2.ZERO), Vector2.ZERO)
	var current_center: Vector2 = _as_vector2(_state.get("screen_current", target_center), target_center)
	var origin_center: Vector2 = _as_vector2(_state.get("screen_origin", current_center), current_center)
	var player_center: Vector2 = _as_vector2(_state.get("screen_player_center", current_center), current_center)
	var size: float = max(1.0, float(_state.get("screen_size", BASE_HEIGHT)))
	var alpha: float = clamp(float(_state.get("alpha", 1.0)), 0.0, 1.0)
	var progress: float = clamp(float(_state.get("progress", 0.0)), 0.0, 1.0)
	var phase_progress: float = clamp(float(_state.get("phase_progress", progress)), 0.0, 1.0)
	var spawn_msec: int = int(_state.get("spawn_msec", 0))
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	var enraged: bool = bool(_state.get("enraged", false))
	var flight_angle: float = float(_state.get("flight_angle", 0.0))
	var disk_alpha: float = alpha if phase in ["blackhole", "fade"] else 0.0
	_sync_cracks_phase_intensity(phase, enraged)

	if spawn_msec != _last_spawn_msec:
		_last_spawn_msec = spawn_msec
		_open_msec = Time.get_ticks_msec()
	_last_alpha = disk_alpha

	var open_scale: float = _get_open_scale()
	var open_brightness: float = _get_open_brightness()

	var disk_height: float = size * open_scale
	var disk_width: float = disk_height * QUAD_ASPECT
	var disk_size := Vector2(disk_width, disk_height)
	_disk_quad.position = target_center - disk_size * 0.5
	_disk_quad.size = disk_size
	_disk_quad.visible = disk_alpha > 0.001

	if _disk_material != null:
		_disk_material.set_shader_parameter("elapsed", elapsed_sec)
		_disk_material.set_shader_parameter("pulse", pulse_value)
		_disk_material.set_shader_parameter("breath", breath_value)
		_disk_material.set_shader_parameter("blackhole_alpha", disk_alpha)
		_disk_material.set_shader_parameter("progress", progress)
		_disk_material.set_shader_parameter("open_brightness", open_brightness)

	_update_glyph(player_center, size, render_scale, phase, phase_progress, alpha, enraged)
	_update_spear(origin_center, current_center, target_center, size, render_scale, phase, phase_progress, alpha, flight_angle, enraged)
	_update_trail(origin_center, current_center, target_center, size, render_scale, phase, phase_progress, alpha, flight_angle, enraged)
	_update_impact(target_center, size, phase, phase_progress, alpha, enraged)
	_update_cracks(target_center, size, phase, phase_progress, alpha, enraged)

	# Particle nodes are stretched horizontally so circular emission becomes
	# an ellipse matching the disk shape.
	var size_factor: float = size / BASE_HEIGHT
	var particle_scale := Vector2(size_factor * QUAD_ASPECT * 0.85, size_factor)
	var storm_scale := Vector2(size_factor * QUAD_ASPECT * 0.95, size_factor * 1.05)
	var ember_scale := Vector2(size_factor * QUAD_ASPECT, size_factor * 1.10)
	_inflow_particles.position = target_center
	_inflow_particles.scale = particle_scale
	_inflow_particles.emitting = disk_alpha > 0.05
	_orbit_particles.position = target_center
	_orbit_particles.scale = particle_scale
	_orbit_particles.emitting = disk_alpha > 0.05
	_storm_particles.position = target_center
	_storm_particles.scale = storm_scale
	_storm_particles.emitting = disk_alpha > 0.05
	_ember_particles.position = target_center
	_ember_particles.scale = ember_scale
	_ember_particles.emitting = disk_alpha > 0.05

	var inflow_mat: ParticleProcessMaterial = _inflow_particles.process_material
	if inflow_mat != null:
		inflow_mat.color = Color(0.84, 0.52, 1.0, disk_alpha * (0.55 + pulse_value * 0.16 + open_brightness * 0.45))
	var orbit_mat: ParticleProcessMaterial = _orbit_particles.process_material
	if orbit_mat != null:
		orbit_mat.color = Color(1.0, 0.84, 0.42, disk_alpha * (0.65 + pulse_value * 0.22 + open_brightness * 0.50))
	var storm_mat: ParticleProcessMaterial = _storm_particles.process_material
	if storm_mat != null:
		storm_mat.color = Color(1.0, 0.52, 0.96, disk_alpha * (0.50 + pulse_value * 0.20 + open_brightness * 0.55))
	var ember_mat: ParticleProcessMaterial = _ember_particles.process_material
	if ember_mat != null:
		ember_mat.color = Color(1.0, 0.74, 0.30, disk_alpha * (0.42 + pulse_value * 0.18 + open_brightness * 0.62))


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _cracks_sprite == null:
		_cracks_sprite = Sprite2D.new()
		_cracks_sprite.name = "ChaosSpearCracksPattern"
		_cracks_sprite.centered = true
		_cracks_sprite.z_index = -2
		_cracks_sprite.texture = _get_cracks_texture()
		_cracks_sprite.material = WritheEmber.build_material("chaos_cracks")
		_cracks_sprite.visible = false
		add_child(_cracks_sprite)
		_cracks_material = _cracks_sprite.material as ShaderMaterial
		_cracks_preset_name = "chaos_cracks"

	if _glyph_sprite == null:
		_glyph_sprite = Sprite2D.new()
		_glyph_sprite.name = "ChaosSpearGlyph"
		_glyph_sprite.centered = true
		_glyph_sprite.z_index = -1
		_glyph_sprite.texture = _get_glyph_texture()
		_glyph_sprite.material = _make_texture_layer_material()
		_glyph_sprite.visible = false
		add_child(_glyph_sprite)
		_glyph_material = _glyph_sprite.material as ShaderMaterial

	if _disk_quad == null:
		_disk_quad = ColorRect.new()
		_disk_quad.name = "ChaosSpearBlackholeDisk"
		_disk_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disk_quad.z_index = 0
		_disk_quad.color = Color.WHITE
		_disk_quad.material = _build_disk_material()
		_disk_quad.visible = false
		add_child(_disk_quad)
		_disk_material = _disk_quad.material as ShaderMaterial

	if _inflow_particles == null:
		_inflow_particles = GPUParticles2D.new()
		_inflow_particles.name = "ChaosSpearInflowParticles"
		_inflow_particles.z_index = 1
		_inflow_particles.amount = INFLOW_PARTICLE_AMOUNT
		_inflow_particles.lifetime = 0.95
		_inflow_particles.one_shot = false
		_inflow_particles.explosiveness = 0.0
		_inflow_particles.randomness = 0.92
		_inflow_particles.fixed_fps = PARTICLE_FIXED_FPS
		_inflow_particles.local_coords = true
		_inflow_particles.visibility_rect = Rect2(-460.0, -280.0, 920.0, 560.0)
		_inflow_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_inflow_particles.material = _additive_material
		_inflow_particles.process_material = _build_inflow_particle_material()
		_inflow_particles.emitting = false
		add_child(_inflow_particles)

	if _orbit_particles == null:
		_orbit_particles = GPUParticles2D.new()
		_orbit_particles.name = "ChaosSpearOrbitParticles"
		_orbit_particles.z_index = 1
		_orbit_particles.amount = ORBIT_PARTICLE_AMOUNT
		_orbit_particles.lifetime = 1.40
		_orbit_particles.one_shot = false
		_orbit_particles.explosiveness = 0.0
		_orbit_particles.randomness = 0.74
		_orbit_particles.fixed_fps = PARTICLE_FIXED_FPS
		_orbit_particles.local_coords = true
		_orbit_particles.visibility_rect = Rect2(-380.0, -240.0, 760.0, 480.0)
		_orbit_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_orbit_particles.material = _additive_material
		_orbit_particles.process_material = _build_orbit_particle_material()
		_orbit_particles.emitting = false
		add_child(_orbit_particles)

	if _storm_particles == null:
		_storm_particles = GPUParticles2D.new()
		_storm_particles.name = "ChaosSpearStormParticles"
		_storm_particles.z_index = 1
		_storm_particles.amount = STORM_PARTICLE_AMOUNT
		_storm_particles.lifetime = 1.20
		_storm_particles.one_shot = false
		_storm_particles.explosiveness = 0.0
		_storm_particles.randomness = 0.95
		_storm_particles.fixed_fps = PARTICLE_FIXED_FPS
		_storm_particles.local_coords = true
		_storm_particles.visibility_rect = Rect2(-560.0, -340.0, 1120.0, 680.0)
		_storm_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_storm_particles.material = _additive_material
		_storm_particles.process_material = _build_storm_particle_material()
		_storm_particles.emitting = false
		add_child(_storm_particles)

	if _ember_particles == null:
		_ember_particles = GPUParticles2D.new()
		_ember_particles.name = "ChaosSpearEmberParticles"
		_ember_particles.z_index = 1
		_ember_particles.amount = EMBER_PARTICLE_AMOUNT
		_ember_particles.lifetime = 0.55
		_ember_particles.one_shot = false
		_ember_particles.explosiveness = 0.0
		_ember_particles.randomness = 0.88
		_ember_particles.fixed_fps = PARTICLE_FIXED_FPS
		_ember_particles.local_coords = true
		_ember_particles.visibility_rect = Rect2(-520.0, -320.0, 1040.0, 640.0)
		_ember_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_ember_particles.material = _additive_material
		_ember_particles.process_material = _build_ember_particle_material()
		_ember_particles.emitting = false
		add_child(_ember_particles)

	if _charge_particles == null:
		_charge_particles = GPUParticles2D.new()
		_charge_particles.name = "ChaosSpearChargeParticles"
		_charge_particles.z_index = 3
		_charge_particles.amount = CHARGE_PARTICLE_AMOUNT
		_charge_particles.lifetime = 0.38
		_charge_particles.one_shot = false
		_charge_particles.explosiveness = 0.0
		_charge_particles.randomness = 0.86
		_charge_particles.fixed_fps = PARTICLE_FIXED_FPS
		_charge_particles.local_coords = true
		_charge_particles.visibility_rect = Rect2(-140.0, -140.0, 280.0, 280.0)
		_charge_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_charge_particles.material = _additive_material
		_charge_particles.process_material = _build_charge_particle_material()
		_charge_particles.emitting = false
		add_child(_charge_particles)

	if _trail_sprite == null:
		_trail_sprite = Sprite2D.new()
		_trail_sprite.name = "ChaosSpearTrail"
		_trail_sprite.centered = true
		_trail_sprite.z_index = 2
		_trail_sprite.texture = _get_trail_texture()
		_trail_sprite.material = _make_texture_layer_material()
		_trail_sprite.visible = false
		add_child(_trail_sprite)
		_trail_material = _trail_sprite.material as ShaderMaterial

	if _spear_sprite == null:
		_spear_sprite = Sprite2D.new()
		_spear_sprite.name = "ChaosSpearSilhouette"
		_spear_sprite.centered = true
		_spear_sprite.z_index = 3
		_spear_sprite.texture = _get_spear_texture()
		_spear_sprite.visible = false
		add_child(_spear_sprite)

	if _impact_sprite == null:
		_impact_sprite = Sprite2D.new()
		_impact_sprite.name = "ChaosSpearImpactBurst"
		_impact_sprite.centered = true
		_impact_sprite.z_index = 4
		_impact_sprite.texture = _get_impact_burst_texture()
		_impact_sprite.material = _make_texture_layer_material()
		_impact_sprite.visible = false
		add_child(_impact_sprite)
		_impact_material = _impact_sprite.material as ShaderMaterial


func has_runtime_assets() -> bool:
	return _has_texture_pieces()


func can_handle_state(next_state: Dictionary) -> bool:
	var phase: String = str(next_state.get("phase", "blackhole"))
	if phase in ["blackhole", "fade"]:
		return true
	return has_runtime_assets()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"processing": is_processing(),
		"texture_pieces_ready": has_runtime_assets(),
		"shader_layers": 5,
		"gpu_particle_layers": 5,
		"glyph_png_slot": _is_png_texture_loaded(GLYPH_TEXTURE_PATH, _get_glyph_texture()),
		"spear_png_slot": _is_png_texture_loaded(SPEAR_TEXTURE_PATH, _get_spear_texture()),
		"trail_png_slot": _is_png_texture_loaded(TRAIL_TEXTURE_PATH, _get_trail_texture()),
		"impact_burst_png_slot": _is_png_texture_loaded(IMPACT_BURST_TEXTURE_PATH, _get_impact_burst_texture()),
		"cracks_png_slot": _is_png_texture_loaded(CRACKS_TEXTURE_PATH, _get_cracks_texture()),
		"cracks_writhe_shader": WritheEmber.is_material_using_shader(_cracks_material),
		"cracks_intensity": _cracks_intensity,
		"cracks_distort_strength": _get_cracks_shader_float("distort_strength"),
		"cracks_lateral_strength": _get_cracks_shader_float("lateral_strength"),
		"cracks_jitter_strength": _get_cracks_shader_float("jitter_strength"),
		"cracks_bolt_flow_speed": _get_cracks_shader_float("bolt_flow_speed"),
		"cracks_flicker_speed": _get_cracks_shader_float("flicker_speed"),
		"phase": str(_state.get("phase", "")),
		"glyph_visible": _glyph_sprite != null and _glyph_sprite.visible,
		"spear_visible": _spear_sprite != null and _spear_sprite.visible,
		"trail_visible": _trail_sprite != null and _trail_sprite.visible,
		"impact_burst_visible": _impact_sprite != null and _impact_sprite.visible,
		"cracks_visible": _cracks_sprite != null and _cracks_sprite.visible,
		"blackhole_visible": _disk_quad != null and _disk_quad.visible,
	}


static func _has_texture_pieces() -> bool:
	return (
		_get_glyph_texture() != null
		and _get_spear_texture() != null
		and _get_trail_texture() != null
		and _get_impact_burst_texture() != null
		and _get_cracks_texture() != null
	)


func _update_glyph(
	player_center: Vector2,
	size: float,
	render_scale: float,
	phase: String,
	phase_progress: float,
	alpha: float,
	enraged: bool
) -> void:
	if _glyph_sprite == null or _get_glyph_texture() == null:
		return
	var glyph_alpha: float = 0.0
	if phase == "startup":
		glyph_alpha = alpha * _smoothstep(0.0, 0.42, phase_progress)
	elif phase == "flying":
		glyph_alpha = alpha * (1.0 - _smoothstep(0.0, 0.70, phase_progress))
	if glyph_alpha <= 0.01:
		_glyph_sprite.visible = false
		return
	_glyph_sprite.visible = true
	_glyph_sprite.position = player_center + Vector2(0.0, -38.0 * render_scale)
	_glyph_sprite.rotation = -elapsed_sec * (0.9 if enraged else 0.6)
	_apply_sprite_width(_glyph_sprite, _get_glyph_texture(), size * (1.10 + phase_progress * 0.06))
	_glyph_sprite.modulate = Color(1.0, 1.0, 1.0, glyph_alpha)
	_set_texture_layer_params(_glyph_material, glyph_alpha, enraged, 0.0, 0.16, 6.0, 0.010 if not enraged else 0.015, 0.08)


func _update_spear(
	_origin_center: Vector2,
	current_center: Vector2,
	target_center: Vector2,
	size: float,
	render_scale: float,
	phase: String,
	phase_progress: float,
	alpha: float,
	flight_angle: float,
	enraged: bool
) -> void:
	if _spear_sprite == null or _get_spear_texture() == null:
		return
	var spear_alpha: float = 0.0
	var tip := current_center
	var angle: float = flight_angle
	var width: float = size * 0.86
	match phase:
		"startup":
			spear_alpha = alpha * _smoothstep(0.0, 0.52, phase_progress)
			tip = current_center + Vector2(0.0, (-10.0 - 18.0 * phase_progress) * render_scale)
			angle = deg_to_rad(-75.0)
			width = size * (0.52 + phase_progress * 0.18)
		"flying":
			spear_alpha = alpha
			tip = current_center
			angle = flight_angle
			width = size * (0.92 if enraged else 0.86)
		"impact":
			spear_alpha = alpha * 0.94
			tip = target_center
			angle = flight_angle + PI * 0.5
			width = size * 0.92
		"blackhole":
			var collapse_t: float = clamp(phase_progress / 0.34, 0.0, 1.0)
			spear_alpha = alpha * (1.0 - collapse_t) * 0.92
			tip = target_center
			angle = flight_angle + PI * 0.5 + elapsed_sec * 0.20
			width = lerpf(size * 0.92, size * 0.30, _ease_out_cubic(collapse_t))
		"fade":
			spear_alpha = alpha * max(0.0, 1.0 - phase_progress) * 0.35
			tip = target_center
			angle = flight_angle + PI * 0.5 + elapsed_sec * 0.20
			width = size * 0.30
	if spear_alpha <= 0.01:
		_spear_sprite.visible = false
		if _charge_particles != null:
			_charge_particles.emitting = false
		return
	var dir := Vector2(cos(angle), sin(angle))
	_spear_sprite.visible = true
	_spear_sprite.position = tip - dir * width * 0.46
	_spear_sprite.rotation = angle
	_apply_sprite_width(_spear_sprite, _get_spear_texture(), width)
	_spear_sprite.modulate = Color(1.08 if enraged else 1.0, 1.0, 1.0, spear_alpha)
	if _charge_particles != null:
		var charge_active: bool = phase == "startup" and phase_progress >= 0.30
		_charge_particles.position = tip
		_charge_particles.scale = Vector2.ONE * render_scale
		_charge_particles.emitting = charge_active and spear_alpha > 0.08
		var charge_mat: ParticleProcessMaterial = _charge_particles.process_material
		if charge_mat != null:
			charge_mat.color = Color(1.0, 0.46, 0.96, spear_alpha * (0.58 + phase_progress * 0.22))


func _update_trail(
	origin_center: Vector2,
	current_center: Vector2,
	target_center: Vector2,
	size: float,
	_render_scale: float,
	phase: String,
	phase_progress: float,
	alpha: float,
	flight_angle: float,
	enraged: bool
) -> void:
	if _trail_sprite == null or _get_trail_texture() == null:
		return
	var trail_alpha: float = 0.0
	if phase == "flying":
		trail_alpha = alpha * _smoothstep(0.0, 0.25, phase_progress) * (1.0 - _smoothstep(0.78, 1.0, phase_progress))
	elif phase == "impact":
		trail_alpha = alpha * (1.0 - _smoothstep(0.0, 0.16, phase_progress)) * 0.55
	if trail_alpha <= 0.01:
		_trail_sprite.visible = false
		return
	var dir := Vector2(cos(flight_angle), sin(flight_angle))
	var distance: float = max(1.0, origin_center.distance_to(target_center))
	var length_scale: float = 1.5 if enraged else 1.0
	var trail_width: float = clamp(distance * 0.62, size * 0.88, size * 1.55) * length_scale
	var spear_width: float = size * 0.86
	var head_pos: Vector2 = current_center - dir * spear_width * 0.54
	_trail_sprite.visible = true
	_trail_sprite.position = head_pos - dir * trail_width * 0.50
	_trail_sprite.rotation = flight_angle
	_apply_sprite_width(_trail_sprite, _get_trail_texture(), trail_width)
	_trail_sprite.modulate = Color(1.0, 1.0, 1.0, trail_alpha)
	_set_texture_layer_params(_trail_material, trail_alpha, enraged, 0.90 if not enraged else 1.20, 0.04, 9.0, 0.006, 0.02)


func _update_impact(
	target_center: Vector2,
	size: float,
	phase: String,
	phase_progress: float,
	alpha: float,
	enraged: bool
) -> void:
	if _impact_sprite == null or _get_impact_burst_texture() == null:
		return
	if phase != "impact":
		_impact_sprite.visible = false
		return
	var burst_alpha: float = 0.0
	if phase_progress < PHASE3_BURST_IN_RATIO:
		burst_alpha = phase_progress / PHASE3_BURST_IN_RATIO
	elif phase_progress < PHASE3_BURST_IN_RATIO + PHASE3_BURST_HOLD_RATIO:
		burst_alpha = 1.0
	else:
		burst_alpha = 1.0 - ((phase_progress - PHASE3_BURST_IN_RATIO - PHASE3_BURST_HOLD_RATIO) / max(0.001, 1.0 - PHASE3_BURST_IN_RATIO - PHASE3_BURST_HOLD_RATIO))
	burst_alpha = clamp(burst_alpha, 0.0, 1.0) * alpha
	if burst_alpha <= 0.01:
		_impact_sprite.visible = false
		return
	var peak_scale: float = 1.8 if enraged else 1.4
	var burst_scale: float = lerpf(0.30, peak_scale, _ease_out_cubic(phase_progress))
	_impact_sprite.visible = true
	_impact_sprite.position = target_center
	_impact_sprite.rotation = phase_progress * PI * 0.25
	_apply_sprite_width(_impact_sprite, _get_impact_burst_texture(), size * 1.12 * burst_scale)
	_impact_sprite.modulate = Color(1.0, 1.0, 1.0, burst_alpha)
	_set_texture_layer_params(_impact_material, burst_alpha, enraged, 0.0, 0.10, 18.0, 0.014 if not enraged else 0.021, 0.12)


func _update_cracks(
	target_center: Vector2,
	size: float,
	phase: String,
	phase_progress: float,
	alpha: float,
	enraged: bool
) -> void:
	if _cracks_sprite == null or _get_cracks_texture() == null:
		return
	var cracks_alpha: float = 0.0
	var cracks_scale: float = 1.0
	match phase:
		"impact":
			cracks_alpha = alpha * (1.0 if enraged else 0.85) * _smoothstep(0.0, 0.82, phase_progress)
			cracks_scale = lerpf(0.60, 1.0, _ease_out_cubic(phase_progress))
		"blackhole":
			var pulse_amp: float = 0.18 if enraged else 0.10
			cracks_alpha = alpha * ((1.0 if enraged else 0.60) + sin(elapsed_sec * 4.2) * pulse_amp)
			cracks_scale = 1.0 + 0.04 * sin(elapsed_sec * 2.4)
		"fade":
			cracks_alpha = alpha * 0.60 * (1.0 - _smoothstep(0.0, 1.0, phase_progress))
			cracks_scale = 1.0
	if cracks_alpha <= 0.01:
		_cracks_sprite.visible = false
		return
	_cracks_sprite.visible = true
	_cracks_sprite.position = target_center
	_cracks_sprite.rotation = sin(elapsed_sec * 0.35) * 0.025
	_apply_sprite_width(_cracks_sprite, _get_cracks_texture(), size * 1.82 * cracks_scale)
	_cracks_sprite.modulate = Color(1.0, 1.0, 1.0, clamp(cracks_alpha, 0.0, 1.0))
	_set_cracks_writhe_params(enraged)


func _sync_cracks_phase_intensity(phase: String, enraged: bool) -> void:
	var phase_key := "%s:%s" % [phase, "enraged" if enraged else "normal"]
	if phase_key == _cracks_phase_key:
		return
	_cracks_phase_key = phase_key
	_kill_cracks_intensity_tween()
	var base_intensity: float = 1.3 if enraged else 1.0
	if not is_inside_tree():
		match phase:
			"impact":
				_cracks_intensity = base_intensity
			"blackhole":
				_cracks_intensity = 0.85 * base_intensity
			_:
				_cracks_intensity = 0.0
		return
	match phase:
		"impact":
			var peak: float = 1.4 * base_intensity
			_cracks_intensity_tween = create_tween()
			_cracks_intensity_tween.tween_property(self, "_cracks_intensity", peak, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_cracks_intensity_tween.tween_property(self, "_cracks_intensity", base_intensity, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"blackhole":
			_cracks_intensity_tween = create_tween()
			_cracks_intensity_tween.tween_property(self, "_cracks_intensity", 0.85 * base_intensity, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"fade":
			_cracks_intensity_tween = create_tween()
			_cracks_intensity_tween.tween_property(self, "_cracks_intensity", 0.0, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			_cracks_intensity = 0.0


func _kill_cracks_intensity_tween() -> void:
	if _cracks_intensity_tween != null and _cracks_intensity_tween.is_valid():
		_cracks_intensity_tween.kill()
	_cracks_intensity_tween = null


func _set_cracks_writhe_params(enraged: bool) -> void:
	if _cracks_material == null:
		return
	var preset_name := "chaos_cracks_enraged" if enraged else "chaos_cracks"
	if preset_name != _cracks_preset_name:
		WritheEmber.apply_preset(_cracks_material, preset_name)
		_cracks_preset_name = preset_name
	_cracks_material.set_shader_parameter("elapsed", elapsed_sec)
	_cracks_material.set_shader_parameter("intensity", max(0.0, _cracks_intensity))


func _get_cracks_shader_float(parameter_name: String) -> float:
	if _cracks_material == null:
		return 0.0
	var value: Variant = _cracks_material.get_shader_parameter(parameter_name)
	if value == null:
		return 0.0
	return float(value)


func _apply_sprite_width(sprite: Sprite2D, texture: Texture2D, draw_width: float) -> void:
	if sprite == null or texture == null:
		return
	var texture_width: float = max(1.0, float(texture.get_width()))
	var uniform_scale: float = max(0.001, draw_width / texture_width)
	sprite.scale = Vector2(uniform_scale, uniform_scale)


func _set_texture_layer_params(
	shader_material: ShaderMaterial,
	alpha: float,
	enraged: bool,
	scroll_x: float,
	pulse_amp: float,
	pulse_speed: float,
	chromatic_strength: float,
	warm_boost: float
) -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("elapsed", elapsed_sec)
	shader_material.set_shader_parameter("alpha_scale", clamp(alpha, 0.0, 1.0))
	shader_material.set_shader_parameter("enraged", 1.0 if enraged else 0.0)
	shader_material.set_shader_parameter("scroll_x", scroll_x)
	shader_material.set_shader_parameter("pulse_amp", pulse_amp)
	shader_material.set_shader_parameter("pulse_speed", pulse_speed)
	shader_material.set_shader_parameter("chromatic_strength", chromatic_strength)
	shader_material.set_shader_parameter("warm_boost", warm_boost)


func _start_tweens() -> void:
	if not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "pulse_value", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "pulse_value", 0.0, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = create_tween()
	_breath_tween.set_loops()
	_breath_tween.tween_property(self, "breath_value", 1.0, 1.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(self, "breath_value", 0.0, 0.92).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _get_open_scale() -> float:
	if _open_msec < 0:
		return 1.0
	var elapsed: float = float(Time.get_ticks_msec() - _open_msec) / 1000.0
	if elapsed >= OPEN_SCALE_DURATION_SEC:
		return 1.0
	return Tween.interpolate_value(0.0, 1.0, elapsed, OPEN_SCALE_DURATION_SEC, Tween.TRANS_BACK, Tween.EASE_OUT)


func _get_open_brightness() -> float:
	if _open_msec < 0:
		return 0.0
	var elapsed: float = float(Time.get_ticks_msec() - _open_msec) / 1000.0
	if elapsed >= OPEN_BRIGHTNESS_DURATION_SEC:
		return 0.0
	return Tween.interpolate_value(1.0, -1.0, elapsed, OPEN_BRIGHTNESS_DURATION_SEC, Tween.TRANS_EXPO, Tween.EASE_OUT)


static func _build_disk_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float breath = 0.0;
uniform float blackhole_alpha = 1.0;
uniform float progress = 0.0;
uniform float open_brightness = 0.0;

float ring_band_at(float r, float center, float width) {
	return smoothstep(width, 0.0, abs(r - center));
}

float hash(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);

	// Logarithmic spiral twist — arms wind tighter near event horizon.
	float spin_speed = 0.42 + breath * 0.08;
	float arm_count = 3.0;
	float twist = 2.6 * log(r * 5.0 + 1.0);
	float spiral_phase = angle * arm_count - twist + elapsed * spin_speed * arm_count;
	float spiral_band = 0.5 + 0.5 * cos(spiral_phase);
	spiral_band = pow(spiral_band, 2.2);

	// Secondary fainter spiral arms going opposite direction.
	float counter_phase = angle * 2.0 + twist * 0.4 - elapsed * spin_speed * 0.6;
	float counter_band = 0.5 + 0.5 * cos(counter_phase);
	counter_band = pow(counter_band, 3.0) * 0.45;

	// Envelope shapes.
	float outer = smoothstep(1.06, 0.18, r);
	float event_horizon = 0.30 + breath * 0.014;
	float void_mask = smoothstep(event_horizon - 0.04, event_horizon + 0.02, r);

	// Bright accretion ring and photon (Einstein) ring.
	float accretion_ring = ring_band_at(r, event_horizon + 0.05, 0.07) * (0.95 + pulse * 0.20);
	float photon_ring = ring_band_at(r, 0.52, 0.045) * 0.55;

	// Outer rim halo with chromatic split.
	vec2 dir = vec2(cos(angle), sin(angle));
	float chroma = 0.020 + pulse * 0.012;
	float r_red = length(p - dir * chroma);
	float r_blue = length(p + dir * chroma);
	float rim = ring_band_at(r, 0.95, 0.07) * 0.45;
	float rim_red = ring_band_at(r_red, 0.95, 0.085);
	float rim_blue = ring_band_at(r_blue, 0.95, 0.085);

	// Disk dust scatter — spiral arms + counter arms inside the disk band.
	float disk_band = smoothstep(0.96, 0.32, r) * void_mask;
	float dust = (spiral_band + counter_band) * disk_band;

	// Procedural starfield — high-frequency hash dots that sparkle.
	vec2 sp = p * 13.0;
	vec2 cell = floor(sp);
	vec2 frac_sp = fract(sp) - 0.5;
	float h = hash(cell);
	float star_dot = step(0.962, h);
	float star_intensity = star_dot * smoothstep(0.18, 0.0, length(frac_sp));
	float twinkle = 0.55 + 0.45 * sin(elapsed * 6.0 + h * 30.0);
	star_intensity *= (0.6 + 0.4 * twinkle) * outer * smoothstep(event_horizon, 1.0, r);

	float a = outer * (
		dust * 0.55
		+ accretion_ring * 0.95
		+ photon_ring * 0.55
		+ rim * 0.45
	);
	a += star_intensity * 0.85;
	a *= blackhole_alpha * (0.78 + pulse * 0.20 + open_brightness * 0.55);

	// Color stops.
	vec3 cool = vec3(0.32, 0.10, 0.78);
	vec3 mid = vec3(0.74, 0.40, 1.0);
	vec3 hot = vec3(1.0, 0.74, 0.30);
	vec3 photon = vec3(1.0, 0.92, 0.78);
	vec3 milky = vec3(0.92, 0.84, 1.0);

	vec3 color = mix(cool, mid, clamp(dust * 1.4, 0.0, 1.0));
	color = mix(color, hot, accretion_ring * 0.65);
	color = mix(color, photon, photon_ring * 0.60);
	color = mix(color, milky, star_intensity * 0.7);

	// Apply chromatic offset to rim only.
	vec3 rim_color = color;
	rim_color.r += rim_red * 0.45;
	rim_color.b += rim_blue * 0.45;
	color = mix(color, rim_color, smoothstep(0.0, 0.05, rim));

	// Activation flash boost — brief warm-white wash.
	color = mix(color, vec3(1.0, 0.92, 0.78), open_brightness * 0.30 * outer);

	COLOR = vec4(color, clamp(a, 0.0, 0.95));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _get_texture_layer_shader() -> Shader:
	if _texture_layer_shader != null:
		return _texture_layer_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float alpha_scale = 1.0;
uniform float enraged = 0.0;
uniform float scroll_x = 0.0;
uniform float pulse_amp = 0.0;
uniform float pulse_speed = 6.0;
uniform float chromatic_strength = 0.0;
uniform float warm_boost = 0.0;

void fragment() {
	vec2 uv = UV;
	if (abs(scroll_x) > 0.0001) {
		uv.x = fract(uv.x + elapsed * scroll_x);
	}
	vec2 centered = uv - vec2(0.5);
	vec2 dir = normalize(centered + vec2(0.0001));
	vec4 tex = texture(TEXTURE, uv);
	vec4 red = texture(TEXTURE, clamp(uv + dir * chromatic_strength, vec2(0.0), vec2(1.0)));
	vec4 blue = texture(TEXTURE, clamp(uv - dir * chromatic_strength, vec2(0.0), vec2(1.0)));
	vec3 color = tex.rgb;
	color.r = max(color.r, red.r * (0.92 + chromatic_strength * 5.0));
	color.b = max(color.b, blue.b * (1.02 + chromatic_strength * 5.0));
	color.r *= mix(1.0, 1.08, enraged);
	color = mix(color, vec3(1.0, 0.78, 0.32), warm_boost);
	float pulse = 1.0 + pulse_amp * (0.5 + 0.5 * sin(elapsed * pulse_speed));
	COLOR = vec4(color, clamp(tex.a * alpha_scale * pulse * mix(1.0, 1.16, enraged), 0.0, 0.96));
}
"""
	_texture_layer_shader = shader
	return _texture_layer_shader


static func _build_inflow_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 8.0
	mat.radial_accel_min = -380.0
	mat.radial_accel_max = -200.0
	mat.tangential_accel_min = -160.0
	mat.tangential_accel_max = -40.0
	mat.damping_min = 0.0
	mat.damping_max = 8.0
	mat.scale_min = 0.025
	mat.scale_max = 0.075
	mat.color = Color(0.78, 0.48, 1.0, 0.45)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = RING_BASE_RADIUS_LOCAL
	mat.emission_ring_inner_radius = RING_BASE_RADIUS_LOCAL - 18.0
	mat.emission_ring_height = 0.0
	return mat


static func _build_orbit_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 130.0
	mat.radial_accel_min = -60.0
	mat.radial_accel_max = 30.0
	mat.tangential_accel_min = -260.0
	mat.tangential_accel_max = -110.0
	mat.damping_min = 4.0
	mat.damping_max = 22.0
	mat.scale_min = 0.020
	mat.scale_max = 0.055
	mat.color = Color(1.0, 0.82, 0.42, 0.65)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = ORBIT_BASE_RADIUS_LOCAL
	mat.emission_ring_inner_radius = ORBIT_BASE_RADIUS_LOCAL - 12.0
	mat.emission_ring_height = 0.0
	return mat


static func _build_storm_particle_material() -> ParticleProcessMaterial:
	# Outer storm ring — bigger, denser swirl just outside the disk that
	# spirals violently around the perimeter while drifting slowly inward.
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 60.0
	mat.radial_accel_min = -180.0
	mat.radial_accel_max = -70.0
	mat.tangential_accel_min = -460.0
	mat.tangential_accel_max = -240.0
	mat.damping_min = 4.0
	mat.damping_max = 18.0
	mat.scale_min = 0.045
	mat.scale_max = 0.115
	mat.color = Color(1.0, 0.52, 0.96, 0.55)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 195.0
	mat.emission_ring_inner_radius = 165.0
	mat.emission_ring_height = 0.0
	return mat


static func _build_ember_particle_material() -> ParticleProcessMaterial:
	# Hot embers / debris flung outward from the accretion ring then dragged
	# back. Short lifetime + high velocity gives a sparking storm feel.
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 140.0
	mat.initial_velocity_max = 280.0
	mat.radial_accel_min = -260.0
	mat.radial_accel_max = -80.0
	mat.tangential_accel_min = -320.0
	mat.tangential_accel_max = -120.0
	mat.damping_min = 30.0
	mat.damping_max = 110.0
	mat.scale_min = 0.018
	mat.scale_max = 0.060
	mat.color = Color(1.0, 0.74, 0.30, 0.70)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 80.0
	mat.emission_ring_inner_radius = 55.0
	mat.emission_ring_height = 0.0
	return mat


static func _build_charge_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 16.0
	mat.initial_velocity_max = 64.0
	mat.radial_accel_min = -92.0
	mat.radial_accel_max = -28.0
	mat.tangential_accel_min = -160.0
	mat.tangential_accel_max = 160.0
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	mat.damping_min = 8.0
	mat.damping_max = 28.0
	mat.scale_min = 0.030
	mat.scale_max = 0.090
	mat.color = Color(1.0, 0.46, 0.96, 0.65)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 32.0
	mat.emission_ring_inner_radius = 5.0
	mat.emission_ring_height = 0.0
	return mat


static func _get_glyph_texture() -> Texture2D:
	if _glyph_texture != null:
		return _glyph_texture
	_glyph_texture = ProjectResourceLoader.load_texture(GLYPH_TEXTURE_PATH)
	return _glyph_texture


static func _get_spear_texture() -> Texture2D:
	if _spear_texture != null:
		return _spear_texture
	_spear_texture = ProjectResourceLoader.load_texture(SPEAR_TEXTURE_PATH)
	return _spear_texture


static func _get_trail_texture() -> Texture2D:
	if _trail_texture != null:
		return _trail_texture
	_trail_texture = ProjectResourceLoader.load_texture(TRAIL_TEXTURE_PATH)
	return _trail_texture


static func _get_impact_burst_texture() -> Texture2D:
	if _impact_burst_texture != null:
		return _impact_burst_texture
	_impact_burst_texture = ProjectResourceLoader.load_texture(IMPACT_BURST_TEXTURE_PATH)
	return _impact_burst_texture


static func _get_cracks_texture() -> Texture2D:
	if _cracks_texture != null:
		return _cracks_texture
	_cracks_texture = ProjectResourceLoader.load_texture(CRACKS_TEXTURE_PATH)
	return _cracks_texture


static func _is_png_texture_loaded(path: String, texture: Texture2D) -> bool:
	if texture == null:
		return false
	var loaded: Texture2D = ProjectResourceLoader.load_texture(path)
	return loaded != null and loaded == texture


func _make_texture_layer_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_texture_layer_shader()
	return mat


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if abs(edge1 - edge0) <= 0.0001:
		return 0.0
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
