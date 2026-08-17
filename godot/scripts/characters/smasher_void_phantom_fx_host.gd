extends Node2D

# Detached particle/Tween lane for Void Phantom's three-piece modular VFX.
# Textured MIX/ADD passes stay in the renderer so the writhe shader is applied
# once and canvas.material is restored there. This host owns only the particle
# piece and phase envelope; it never resets a parent draw transform.

class PlayfieldClip:
	extends Control

	func configure(enabled: bool, next_size: Vector2) -> void:
		size = next_size
		clip_contents = enabled


const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const PARTICLE_PATH := "res://assets/sprites/skills/void_phantom_vfx/void_phantom_particle.png"
const GAME_SIZE := Vector2(760.0, 750.0)
const PARTICLE_AMOUNT := 26
const PARTICLE_FIXED_FPS := 30
const PARTICLE_QUALITY_GATE := 0.52
const CHARGE_TWEEN_SECONDS := 0.18
const RELEASE_TWEEN_SECONDS := 0.28
const RELEASE_POP_SCALE := 1.36
const CHARGE_SYNC_TIMEOUT_SECONDS := 0.12
const RELEASE_SYNC_TIMEOUT_SECONDS := 0.34

var _state: Dictionary = {}
var _phase_envelope := 1.0
var _last_phase := ""
var _phase_tween: Tween = null
var _playfield_clip: PlayfieldClip = null
var _particles: GPUParticles2D = null
var _charge_process_material: ParticleProcessMaterial = null
var _release_process_material: ParticleProcessMaterial = null
var _sync_timeout: Timer = null

static var _particle_texture: Texture2D = null
static var _prewarmed := false


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_get_particle_texture()
	_prewarmed = true


func prewarm_node_pipeline() -> void:
	prewarm_assets()
	_build_children()
	set_active(false)


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"particle_texture_ready": _get_particle_texture() != null,
		"particle_amount": PARTICLE_AMOUNT,
		"particle_fixed_fps": PARTICLE_FIXED_FPS,
	}


static func build_screen_position_for_tests(
	playfield_pos: Vector2,
	shake_offset: Vector2,
	game_offset: Vector2,
	render_scale: float
) -> Vector2:
	return game_offset + (playfield_pos + shake_offset) * maxf(0.01, render_scale)


func _ready() -> void:
	z_as_relative = false
	z_index = 9
	set_process(false)
	_build_children()
	if bool(_state.get("active", false)) and _state.get("screen_pos") is Vector2:
		var pending_state: Dictionary = _state.duplicate(false)
		_last_phase = ""
		sync_state(pending_state, true)
	else:
		set_active(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _particles == null:
		_build_children()
	_state = next_state.duplicate(false)
	_state["active"] = active
	if not active or not (_state.get("screen_pos") is Vector2):
		set_active(false)
		return
	set_active(true)
	var next_phase: String = str(_state.get("phase", ""))
	_sync_timeout.wait_time = (
		RELEASE_SYNC_TIMEOUT_SECONDS if next_phase == "release" else CHARGE_SYNC_TIMEOUT_SECONDS
	)
	if _sync_timeout.is_inside_tree():
		_sync_timeout.start()
	if next_phase != _last_phase:
		_start_phase_envelope(next_phase)
		_last_phase = next_phase
	_apply_state()


func set_active(active: bool) -> void:
	visible = active
	if not active:
		_kill_phase_tween()
		_phase_envelope = 1.0
		_last_phase = ""
		if _particles != null:
			_particles.emitting = false
		if _sync_timeout != null:
			_sync_timeout.stop()


func get_phase_envelope() -> float:
	return _phase_envelope


func get_debug_status() -> Dictionary:
	return {
		"visible": visible,
		"emitting": _particles != null and _particles.emitting,
		"phase": _last_phase,
		"phase_envelope": _phase_envelope,
		"screen_pos": position,
		"render_scale": scale.x,
		"process_enabled": is_processing(),
	}


func _apply_state() -> void:
	if _particles == null or not visible:
		return
	var screen_pos: Vector2 = _state.get("screen_pos", Vector2.ZERO)
	var game_offset: Vector2 = _state.get("game_offset", Vector2.ZERO)
	var render_scale: float = maxf(0.01, float(_state.get("render_scale", 1.0)))
	position = screen_pos
	scale = Vector2.ONE * render_scale

	var clip_local_origin: Vector2 = (game_offset - screen_pos) / render_scale
	_playfield_clip.position = clip_local_origin
	_playfield_clip.configure(true, GAME_SIZE)
	_particles.position = -clip_local_origin

	var phase: String = str(_state.get("phase", "charge"))
	var quality_scale: float = clampf(float(_state.get("quality_scale", 1.0)), 0.0, 1.0)
	var intensity: float = clampf(float(_state.get("intensity", 1.0)) * _phase_envelope, 0.0, 1.5)
	var allow_particles: bool = quality_scale >= PARTICLE_QUALITY_GATE and intensity > 0.04
	if phase == "charge":
		var ratio: float = clampf(float(_state.get("charge_ratio", 0.0)), 0.0, 1.0)
		_particles.one_shot = false
		_particles.process_material = _charge_process_material
		_particles.emitting = allow_particles
		_charge_process_material.emission_ring_radius = lerpf(54.0, 26.0, ratio)
		_charge_process_material.emission_ring_inner_radius = lerpf(43.0, 18.0, ratio)
		_charge_process_material.color = Color(0.72, 0.94, 1.0, 0.34 + 0.55 * intensity)
	else:
		_release_process_material.color = Color(0.84, 0.98, 1.0, 0.42 + 0.44 * intensity)
		if not allow_particles:
			_particles.emitting = false


func _start_phase_envelope(next_phase: String) -> void:
	_kill_phase_tween()
	if next_phase == "release":
		_phase_envelope = RELEASE_POP_SCALE
		_restart_release_particles()
		_start_tween(RELEASE_POP_SCALE, 0.0, RELEASE_TWEEN_SECONDS)
	else:
		_phase_envelope = 0.0
		_start_tween(0.0, 1.0, CHARGE_TWEEN_SECONDS)


func _start_tween(from_value: float, to_value: float, duration: float) -> void:
	if not is_inside_tree():
		_phase_envelope = 1.0 if to_value > 0.0 else from_value
		return
	_phase_tween = create_tween()
	_phase_tween.tween_method(
		Callable(self, "_set_phase_envelope"),
		from_value,
		to_value,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_phase_envelope(value: float) -> void:
	_phase_envelope = maxf(0.0, value)
	if visible:
		_apply_state()


func _kill_phase_tween() -> void:
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	_phase_tween = null


func _restart_release_particles() -> void:
	if _particles == null:
		return
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 0.88
	_particles.process_material = _release_process_material
	_particles.restart()
	_particles.emitting = true


func _build_children() -> void:
	if _sync_timeout == null:
		_sync_timeout = Timer.new()
		_sync_timeout.name = "VoidPhantomSyncTimeout"
		_sync_timeout.one_shot = true
		_sync_timeout.timeout.connect(_on_sync_timeout)
		add_child(_sync_timeout)
	if _playfield_clip == null:
		_playfield_clip = PlayfieldClip.new()
		_playfield_clip.name = "VoidPhantomPlayfieldClip"
		_playfield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_playfield_clip.configure(true, GAME_SIZE)
		add_child(_playfield_clip)
	if _charge_process_material == null:
		_charge_process_material = _build_particle_process_material(false)
	if _release_process_material == null:
		_release_process_material = _build_particle_process_material(true)
	if _particles == null:
		_particles = GPUParticles2D.new()
		_particles.name = "VoidPhantomSpiritMotes"
		_particles.amount = PARTICLE_AMOUNT
		_particles.lifetime = 0.72
		_particles.one_shot = false
		_particles.explosiveness = 0.0
		_particles.randomness = 0.92
		_particles.fixed_fps = PARTICLE_FIXED_FPS
		_particles.local_coords = true
		_particles.visibility_rect = Rect2(-180.0, -180.0, 360.0, 360.0)
		_particles.texture = _get_particle_texture()
		var additive_material := CanvasItemMaterial.new()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_particles.material = additive_material
		_particles.process_material = _charge_process_material
		_particles.emitting = false
		_playfield_clip.add_child(_particles)


func _on_sync_timeout() -> void:
	# Detached hosts cannot rely on the parent's draw fanout for round/reset
	# cleanup. If the owner stops syncing, terminate visibility and emission.
	set_active(false)


static func _build_particle_process_material(release: bool) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.ZERO
	material.spread = 180.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 78.0 if release else 4.0
	material.initial_velocity_max = 132.0 if release else 12.0
	material.radial_accel_min = 42.0 if release else -68.0
	material.radial_accel_max = 92.0 if release else -24.0
	material.tangential_accel_min = -44.0
	material.tangential_accel_max = 44.0
	material.damping_min = 5.0 if release else 9.0
	material.damping_max = 16.0 if release else 22.0
	material.scale_min = 0.10
	material.scale_max = 0.23 if release else 0.18
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	material.emission_ring_radius = 26.0 if release else 54.0
	material.emission_ring_inner_radius = 7.0 if release else 43.0
	material.emission_ring_height = 0.0
	material.scale_curve = _build_scale_curve()
	material.color_ramp = _build_fade_ramp()
	return material


static func _build_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.0
	curve.add_point(Vector2(0.0, 0.12))
	curve.add_point(Vector2(0.16, 1.0))
	curve.add_point(Vector2(0.66, 0.72))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _build_fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.68, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.62, 0.90, 1.0, 0.0),
		Color(0.82, 0.98, 1.0, 1.0),
		Color(0.64, 0.82, 1.0, 0.62),
		Color(0.18, 0.30, 0.76, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _get_particle_texture() -> Texture2D:
	if _particle_texture == null:
		_particle_texture = ProjectResourceLoader.load_texture(
			PARTICLE_PATH,
			"Void Phantom particle texture missing",
			"Void Phantom particle texture load failed"
		)
	return _particle_texture


static func reset_for_test() -> void:
	_particle_texture = null
	_prewarmed = false
