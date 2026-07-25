extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const CLOUD_TEXTURE_PATH := "res://assets/sprites/skills/smasher_wheel_vfx/pungun_cloud_puff.png"
const ORBIT_CLOUD_COUNT := 9
const SWIRL_PARTICLE_AMOUNT := 24
const BURST_PARTICLE_AMOUNT := 28
const BASE_ORBIT_RADIUS := 58.0
const ORBIT_RADIUS_SPAN := 76.0
const ORBIT_SPEED := 5.2

var elapsed_sec := 0.0

var _state: Dictionary = {}
var _orbit_clouds: Array[Sprite2D] = []
var _swirl_particles: GPUParticles2D = null
var _burst_particles: GPUParticles2D = null
var _last_burst_serial := 0

static var _cloud_texture: Texture2D = null
static var _prewarmed := false


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_get_cloud_texture()
	_build_swirl_particle_material(1)
	_build_burst_particle_material()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"cloud_texture_ready": _get_cloud_texture() != null,
		"orbit_cloud_count": ORBIT_CLOUD_COUNT,
		"swirl_particle_amount": SWIRL_PARTICLE_AMOUNT,
		"burst_particle_amount": BURST_PARTICLE_AMOUNT,
	}


func _ready() -> void:
	z_as_relative = true
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_children()
	set_process(false)
	set_active(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _orbit_clouds.is_empty():
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and _can_handle_state(_state))
	if not visible:
		_last_burst_serial = int(_state.get("burst_serial", 0))
		return

	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	position = _as_vector2(_state.get("screen_center", Vector2.ZERO), Vector2.ZERO)
	scale = Vector2(render_scale, render_scale)
	var current_msec: int = int(_state.get("current_msec", Time.get_ticks_msec()))
	var start_msec: int = int(_state.get("start_msec", current_msec))
	elapsed_sec = max(0.0, float(current_msec - start_msec) / 1000.0)
	_apply_orbit_clouds()
	_apply_swirl_particles()
	_sync_hit_burst(render_scale)
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	for cloud: Sprite2D in _orbit_clouds:
		cloud.visible = active
	if _swirl_particles != null:
		_swirl_particles.emitting = active
	if not active and _burst_particles != null:
		_burst_particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	_state.clear()
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	var visible_orbit_count := 0
	for cloud: Sprite2D in _orbit_clouds:
		if cloud.visible:
			visible_orbit_count += 1
	return {
		"active": visible,
		"cloud_texture_ready": _get_cloud_texture() != null,
		"orbit_cloud_count": _orbit_clouds.size(),
		"visible_orbit_count": visible_orbit_count,
		"swirl_emitting": _swirl_particles != null and _swirl_particles.emitting,
		"burst_emitting": _burst_particles != null and _burst_particles.emitting,
		"last_burst_serial": _last_burst_serial,
	}


func get_orbit_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for cloud: Sprite2D in _orbit_clouds:
		snapshot.append({
			"position": cloud.position,
			"rotation": cloud.rotation,
			"scale": cloud.scale,
			"alpha": cloud.modulate.a,
			"visible": cloud.visible,
		})
	return snapshot


func _draw() -> void:
	if not visible:
		return
	var direction: float = float(_normalized_direction())
	var spin: float = elapsed_sec * ORBIT_SPEED * direction
	for ring_index: int in range(3):
		var radius: float = 48.0 + float(ring_index) * 22.0
		var start_angle: float = spin + float(ring_index) * 1.35
		var arc_color := Color(0.70, 0.88, 1.0, 0.20 - float(ring_index) * 0.035)
		draw_arc(Vector2.ZERO, radius, start_angle, start_angle + direction * PI * 1.18, 28, arc_color, 2.4 - float(ring_index) * 0.35, true)
	var core_pulse: float = 0.5 + 0.5 * sin(elapsed_sec * 9.0)
	draw_circle(Vector2.ZERO, 18.0 + core_pulse * 4.0, Color(0.70, 0.90, 1.0, 0.08 + core_pulse * 0.05))
	draw_arc(Vector2.ZERO, 31.0 + core_pulse * 3.0, 0.0, TAU, 36, Color(0.95, 0.98, 1.0, 0.34), 2.0, true)


func _build_children() -> void:
	var texture: Texture2D = _get_cloud_texture()
	if texture == null:
		return
	while _orbit_clouds.size() < ORBIT_CLOUD_COUNT:
		var cloud := Sprite2D.new()
		cloud.name = "PungunOrbitCloud%d" % _orbit_clouds.size()
		cloud.centered = true
		cloud.texture = texture
		cloud.visible = false
		cloud.z_index = 1 + (_orbit_clouds.size() % 3)
		cloud.flip_h = _orbit_clouds.size() % 2 == 1
		add_child(cloud)
		_orbit_clouds.append(cloud)

	if _swirl_particles == null:
		_swirl_particles = GPUParticles2D.new()
		_swirl_particles.name = "PungunSwirlClouds"
		_swirl_particles.amount = SWIRL_PARTICLE_AMOUNT
		_swirl_particles.lifetime = 0.72
		_swirl_particles.one_shot = false
		_swirl_particles.explosiveness = 0.0
		_swirl_particles.randomness = 0.82
		_swirl_particles.fixed_fps = 48
		_swirl_particles.local_coords = true
		_swirl_particles.visibility_rect = Rect2(-220.0, -180.0, 440.0, 360.0)
		_swirl_particles.texture = texture
		_swirl_particles.process_material = _build_swirl_particle_material(1)
		_swirl_particles.emitting = false
		_swirl_particles.z_index = 0
		add_child(_swirl_particles)

	if _burst_particles == null:
		_burst_particles = GPUParticles2D.new()
		_burst_particles.name = "PungunScatterBurst"
		_burst_particles.amount = BURST_PARTICLE_AMOUNT
		_burst_particles.lifetime = 0.64
		_burst_particles.one_shot = true
		_burst_particles.explosiveness = 0.96
		_burst_particles.randomness = 0.90
		_burst_particles.fixed_fps = 60
		_burst_particles.local_coords = true
		_burst_particles.visibility_rect = Rect2(-280.0, -240.0, 560.0, 480.0)
		_burst_particles.texture = texture
		_burst_particles.process_material = _build_burst_particle_material()
		_burst_particles.emitting = false
		_burst_particles.z_index = 5
		add_child(_burst_particles)


func _apply_orbit_clouds() -> void:
	var direction: float = float(_normalized_direction())
	var texture: Texture2D = _get_cloud_texture()
	if texture == null:
		return
	var texture_width: float = max(1.0, texture.get_width())
	for index: int in range(_orbit_clouds.size()):
		var cloud: Sprite2D = _orbit_clouds[index]
		var cycle: float = fposmod(elapsed_sec * (1.28 + float(index % 3) * 0.11) + float(index) / float(ORBIT_CLOUD_COUNT), 1.0)
		var angle: float = direction * (elapsed_sec * ORBIT_SPEED + float(index) * TAU / float(ORBIT_CLOUD_COUNT))
		var radius: float = BASE_ORBIT_RADIUS + ORBIT_RADIUS_SPAN * cycle + sin(elapsed_sec * 6.0 + float(index) * 1.7) * 7.0
		cloud.position = Vector2(cos(angle) * radius, sin(angle) * radius * 0.46 - 5.0)
		cloud.rotation = angle + direction * (0.42 + cycle * 0.80)
		var target_width: float = 42.0 + cycle * 54.0 + float(index % 2) * 8.0
		var piece_scale: float = target_width / texture_width
		cloud.scale = Vector2(piece_scale, piece_scale)
		var fade: float = pow(max(0.0, sin(cycle * PI)), 0.55)
		var depth_tint: float = 0.78 + 0.22 * float(index % 3) / 2.0
		cloud.modulate = Color(0.78 * depth_tint, 0.88 * depth_tint, 1.0, 0.18 + fade * 0.70)
		cloud.visible = true


func _apply_swirl_particles() -> void:
	if _swirl_particles == null:
		return
	var direction: int = _normalized_direction()
	var process_mat: ParticleProcessMaterial = _swirl_particles.process_material
	if process_mat == null or signf(process_mat.tangential_accel_min) != float(direction):
		_swirl_particles.process_material = _build_swirl_particle_material(direction)
	_swirl_particles.emitting = true


func _sync_hit_burst(render_scale: float) -> void:
	var burst_serial: int = int(_state.get("burst_serial", 0))
	if burst_serial == _last_burst_serial:
		return
	_last_burst_serial = burst_serial
	if burst_serial <= 0 or _burst_particles == null:
		return
	var burst_screen_pos: Vector2 = _as_vector2(_state.get("burst_screen_pos", position), position)
	_burst_particles.position = (burst_screen_pos - position) / max(0.01, render_scale)
	_burst_particles.emitting = false
	_burst_particles.restart()
	_burst_particles.emitting = true


func _can_handle_state(next_state: Dictionary) -> bool:
	return bool(next_state.get("active", false)) and next_state.get("screen_center", null) is Vector2


func _normalized_direction() -> int:
	return -1 if int(_state.get("direction", 1)) < 0 else 1


static func _build_swirl_particle_material(direction: int) -> ParticleProcessMaterial:
	var normalized_direction := -1 if direction < 0 else 1
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 24.0
	mat.initial_velocity_max = 72.0
	mat.radial_accel_min = 38.0
	mat.radial_accel_max = 92.0
	mat.tangential_accel_min = 150.0 * float(normalized_direction)
	mat.tangential_accel_max = 260.0 * float(normalized_direction)
	mat.damping_min = 24.0
	mat.damping_max = 62.0
	mat.scale_min = 0.075
	mat.scale_max = 0.17
	mat.angle_min = -32.0
	mat.angle_max = 32.0
	mat.color = Color(0.76, 0.88, 1.0, 0.42)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 62.0
	mat.emission_ring_inner_radius = 24.0
	mat.emission_ring_height = 0.0
	return mat


static func _build_burst_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, -26.0, 0.0)
	mat.initial_velocity_min = 86.0
	mat.initial_velocity_max = 228.0
	mat.radial_accel_min = 52.0
	mat.radial_accel_max = 150.0
	mat.tangential_accel_min = -110.0
	mat.tangential_accel_max = 110.0
	mat.damping_min = 42.0
	mat.damping_max = 105.0
	mat.scale_min = 0.08
	mat.scale_max = 0.22
	mat.angle_min = -75.0
	mat.angle_max = 75.0
	mat.color = Color(0.88, 0.95, 1.0, 0.76)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 26.0
	return mat


static func _get_cloud_texture() -> Texture2D:
	if _cloud_texture == null:
		_cloud_texture = ProjectResourceLoader.load_texture(
			CLOUD_TEXTURE_PATH,
			"Pungun Cheonseonmu cloud texture missing",
			"Pungun Cheonseonmu cloud texture load failed"
		)
	return _cloud_texture


static func reset_textures_for_test() -> void:
	_cloud_texture = null
	_prewarmed = false


func _as_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	return fallback
