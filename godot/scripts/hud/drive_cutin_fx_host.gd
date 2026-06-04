extends Node2D

# Particle layer (piece 3 of the Smasher Drive cut-in 3-piece modular VFX).
# GPUParticles2D-only node, rendered IN FRONT of the immediate-mode portrait as a
# rising cyan drive-energy sparkle. The backplate (piece 1) and arc (piece 2) are drawn
# immediate-mode behind the portrait by skill_cutin_overlay_host.draw_drive_cutin
# (correct layering requires them in the portrait's _draw pass), so this host owns
# only the particle node.
#
# Coordinate space: the drive cut-in is a SCREEN-space HUD overlay (the playfield
# draw_set_transform is reset to identity before HUD overlays draw), so this host
# positions itself directly in view (screen pixel) space -- position = view_size *
# anchor, scale = view_size.y / REF_HEIGHT -- NOT the game_offset + pos*render_scale
# playfield formula the inferno hosts use. Do NOT add game_offset/render_scale here
# or the sparkle drifts off the portrait.
#
# Single-cleanup contract (mirrors stage5 inferno trail host): set_active(false)
# hides visible + stops particle emission in one call; no scattered teardown.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const PARTICLE_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_particle.png"
const REF_HEIGHT := 750.0
const ANCHOR_X := 0.135            # cluster center-x as a fraction of view width
const ANCHOR_Y := 0.30             # cluster center-y as a fraction of view height
const PARTICLE_AMOUNT := 22
const PARTICLE_FIXED_FPS := 30
const QUALITY_GATE := 0.5
const Z_INDEX := 40
const PARTICLE_COLOR := Color(0.42, 1.0, 0.96, 0.88)
const PARTICLE_COLOR_ENRAGED := Color(0.70, 1.0, 1.0, 0.98)

const ACTIVE_SYNC_GRACE_MSEC := 140

var _particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null
var _last_active_sync_msec: int = 0

static var _prewarmed := false
static var _particle_texture: Texture2D = null


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_particle_texture = ProjectResourceLoader.load_texture(PARTICLE_PATH, "", "")
	_prewarmed = true


static func _get_particle_texture() -> Texture2D:
	if _particle_texture == null:
		_particle_texture = ProjectResourceLoader.load_texture(PARTICLE_PATH, "", "")
	return _particle_texture


func _ready() -> void:
	z_as_relative = false
	z_index = Z_INDEX
	_additive_material = _make_additive_material()
	_build_children()
	set_active(false)


func sync_state(state: Dictionary, active: bool) -> void:
	if _particles == null:
		_build_children()
	var view_size: Vector2 = _as_vector2(state.get("view_size", Vector2.ZERO), Vector2.ZERO)
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		set_active(false)
		return
	var quality_scale: float = clampf(float(state.get("quality_scale", 1.0)), 0.0, 1.0)
	var allow: bool = active and quality_scale >= QUALITY_GATE
	set_active(allow)
	if not visible:
		return
	# Self-timeout guard: the cut-in draw path early-returns on result/intro/grip
	# screens, so the frame controller may stop calling sync_state while embers are
	# still mid-flight. _process auto-hides if no active sync arrives within the
	# grace window, preventing an ember leak over those screens.
	_last_active_sync_msec = Time.get_ticks_msec()
	set_process(true)
	# Screen-space anchor under the top-left portrait; uniform scale keeps the
	# ember cluster proportional to the (view-size-driven) immediate-mode portrait.
	# slide_px slides the cluster in/out with the portrait (enter left->right, exit
	# back to the left) so the whole cut-in moves as one.
	var slide_px: float = float(state.get("slide_px", 0.0))
	position = Vector2(view_size.x * ANCHOR_X + slide_px, view_size.y * ANCHOR_Y)
	var s: float = view_size.y / REF_HEIGHT
	scale = Vector2(s, s)
	var progress: float = clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	var enraged: bool = bool(state.get("enraged", false))
	# Emit during the in/hold window; stop feeding new embers as the cut-in exits
	# so the cluster fades out naturally instead of popping.
	if _particles != null:
		_particles.emitting = progress < 0.74
		var pm: ParticleProcessMaterial = _particles.process_material
		if pm != null:
			pm.color = PARTICLE_COLOR if not enraged else PARTICLE_COLOR_ENRAGED


func _process(_delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if Time.get_ticks_msec() - _last_active_sync_msec > ACTIVE_SYNC_GRACE_MSEC:
		set_active(false)


func set_active(active: bool) -> void:
	visible = active
	if not active:
		set_process(false)
		if _particles != null:
			_particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	var particle_color := Color.TRANSPARENT
	if _particles != null:
		var pm: ParticleProcessMaterial = _particles.process_material
		if pm != null:
			particle_color = pm.color
	return {
		"active": visible,
		"particles_emitting": _particles != null and _particles.emitting,
		"particle_texture_ready": _get_particle_texture() != null,
		"particle_color": particle_color,
	}


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _particles == null:
		_particles = GPUParticles2D.new()
		_particles.name = "DriveCutinEmberParticles"
		_particles.amount = PARTICLE_AMOUNT
		_particles.lifetime = 0.75
		_particles.one_shot = false
		_particles.explosiveness = 0.0
		_particles.randomness = 0.85
		_particles.fixed_fps = PARTICLE_FIXED_FPS
		_particles.local_coords = true
		_particles.visibility_rect = Rect2(-260.0, -320.0, 520.0, 560.0)
		_particles.texture = _get_particle_texture()
		_particles.material = _additive_material
		_particles.process_material = _build_ember_process_material()
		_particles.emitting = false
		_particles.z_index = 0
		add_child(_particles)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_ember_process_material() -> ParticleProcessMaterial:
	# Rising cyan drive sparks swirling up around the portrait (ref/750 space; the host
	# scale maps it to screen). Gentle upward drift + lateral wander + scale fade.
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 32.0
	mat.gravity = Vector3(0.0, -38.0, 0.0)
	mat.initial_velocity_min = 26.0
	mat.initial_velocity_max = 64.0
	mat.tangential_accel_min = -36.0
	mat.tangential_accel_max = 36.0
	mat.damping_min = 8.0
	mat.damping_max = 24.0
	mat.scale_min = 0.018
	mat.scale_max = 0.05
	mat.color = PARTICLE_COLOR
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(95.0, 150.0, 0.0)
	# Fade alpha over life via a ramp so embers wink out smoothly.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.18, Color(1.0, 1.0, 1.0, 1.0))
	ramp.add_point(0.6, Color(1.0, 1.0, 1.0, 0.7))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
