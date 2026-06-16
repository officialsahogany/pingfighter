extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const Stage4PonkMeditationAssets := preload("res://scripts/stages/stage4/stage4_ponk_meditation_assets.gd")

const MANDALA_TEXTURE_PATH := Stage4PonkMeditationAssets.MANDALA_TEXTURE_PATH
const LOTUS_PETAL_TEXTURE_PATH := Stage4PonkMeditationAssets.LOTUS_PETAL_TEXTURE_PATH
const SUTRA_SHARD_TEXTURE_PATH := Stage4PonkMeditationAssets.SUTRA_SHARD_TEXTURE_PATH
const LOCK_BURST_TEXTURE_PATH := Stage4PonkMeditationAssets.LOCK_BURST_TEXTURE_PATH
const RELEASE_BURST_TEXTURE_PATH := Stage4PonkMeditationAssets.RELEASE_BURST_TEXTURE_PATH
const RELEASE_TRAIL_TEXTURE_PATH := Stage4PonkMeditationAssets.RELEASE_TRAIL_TEXTURE_PATH
const TRAIL_POINT_LIMIT := 32
const TRAIL_GLOW_WIDTH := 30.0
const TRAIL_CORE_WIDTH := 11.0
const MANDALA_BASE_SIZE := 230.0
const RELEASE_LINE_WIDTH := 20.0
const LOCK_BURST_START_PROGRESS := 0.18
const LOCK_BURST_IN_PROGRESS := 0.045
const LOCK_BURST_HOLD_PROGRESS := 0.040
const LOCK_BURST_OUT_PROGRESS := 0.085

var pulse_value := 0.0
var breath_value := 0.0
var open_value := 0.0
var release_flash := 0.0
var elapsed_sec := 0.0

var _state: Dictionary = {}
var _active := false
var _last_release_id := -1

var _mandala_quad: ColorRect = null
var _mandala_sprite: Sprite2D = null
var _lock_burst_sprite: Sprite2D = null
var _release_burst_sprite: Sprite2D = null
var _release_trail_sprite: Sprite2D = null
var _mandala_material: ShaderMaterial = null
var _mandala_image_material: ShaderMaterial = null
var _lock_burst_material: ShaderMaterial = null
var _release_burst_material: ShaderMaterial = null
var _release_trail_material: ShaderMaterial = null
var _trail_glow_line: Line2D = null
var _trail_core_line: Line2D = null
var _release_line: Line2D = null
var _trail_material: ShaderMaterial = null
var _release_material: ShaderMaterial = null
var _mote_particles: GPUParticles2D = null
var _petal_particles: GPUParticles2D = null
var _release_particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null
var _pulse_tween: Tween = null
var _breath_tween: Tween = null
var _open_tween: Tween = null
var _release_tween: Tween = null

static var _mandala_texture: Texture2D = null
static var _petal_texture: Texture2D = null
static var _sutra_texture: Texture2D = null
static var _lock_burst_texture: Texture2D = null
static var _release_burst_texture: Texture2D = null
static var _release_trail_texture: Texture2D = null
static var _mandala_shader: Shader = null
static var _mandala_image_shader: Shader = null
static var _sprite_layer_shader: Shader = null
static var _trail_shader: Shader = null
static var _release_shader: Shader = null
static var _prewarm_assets_done := false
static var _prewarm_step_index := 0


static func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


static func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0:
			ImpactFlareTextureCache.prewarm()
		1:
			_get_mandala_texture()
			_get_petal_texture()
		2:
			_get_sutra_texture()
			_get_lock_burst_texture()
		3:
			_get_release_burst_texture()
			_get_release_trail_texture()
		4:
			WritheEmber.prewarm()
		5:
			_get_mandala_shader()
			_get_sprite_layer_shader()
		6:
			_get_trail_shader()
			_get_release_shader()
		7:
			_build_mote_particle_material()
			_build_petal_particle_material()
		8:
			_build_release_particle_material()
		_:
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 8:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"meditation_fx_shader_host_pipeline": (
			(WritheEmber.has_preset("meditation_mandala") or _get_mandala_shader() != null)
			and _get_sprite_layer_shader() != null
			and _get_trail_shader() != null
			and _get_release_shader() != null
		),
		"meditation_fx_shader_layers": 6,
		"meditation_fx_gpu_particle_layers": 3,
		"meditation_fx_texture_pieces_ready": (
			ImpactFlareTextureCache.get_glow_texture() != null
			and ImpactFlareTextureCache.get_sparkle_texture() != null
			and (_get_mandala_texture() != null or _get_mandala_shader() != null)
			and _get_petal_texture() != null
			and _get_sutra_texture() != null
			and _get_lock_burst_texture() != null
			and _get_release_burst_texture() != null
			and _get_release_trail_texture() != null
		),
		"meditation_upgrade_fx_texture_pieces_ready": (
			_is_png_texture_loaded(LOCK_BURST_TEXTURE_PATH, _get_lock_burst_texture())
			and _is_png_texture_loaded(RELEASE_BURST_TEXTURE_PATH, _get_release_burst_texture())
			and _is_png_texture_loaded(RELEASE_TRAIL_TEXTURE_PATH, _get_release_trail_texture())
		),
		"meditation_fx_mandala_png_slot": _get_mandala_texture() != null,
		"meditation_fx_lotus_petal_png_slot": _is_png_texture_loaded(LOTUS_PETAL_TEXTURE_PATH, _get_petal_texture()),
		"meditation_fx_sutra_shard_png_slot": _is_png_texture_loaded(SUTRA_SHARD_TEXTURE_PATH, _get_sutra_texture()),
		"meditation_fx_lock_burst_png_slot": _is_png_texture_loaded(LOCK_BURST_TEXTURE_PATH, _get_lock_burst_texture()),
		"meditation_fx_release_burst_png_slot": _is_png_texture_loaded(RELEASE_BURST_TEXTURE_PATH, _get_release_burst_texture()),
		"meditation_fx_release_trail_png_slot": _is_png_texture_loaded(RELEASE_TRAIL_TEXTURE_PATH, _get_release_trail_texture()),
		"meditation_fx_mandala_texture_path": MANDALA_TEXTURE_PATH,
		"meditation_fx_lotus_petal_texture_path": LOTUS_PETAL_TEXTURE_PATH,
		"meditation_fx_sutra_shard_texture_path": SUTRA_SHARD_TEXTURE_PATH,
		"meditation_fx_lock_burst_texture_path": LOCK_BURST_TEXTURE_PATH,
		"meditation_fx_release_burst_texture_path": RELEASE_BURST_TEXTURE_PATH,
		"meditation_fx_release_trail_texture_path": RELEASE_TRAIL_TEXTURE_PATH,
	}


func prewarm_runtime_nodes() -> void:
	prewarm_assets()
	if _additive_material == null:
		_additive_material = _make_additive_material()
	_build_children()
	set_active(false)


func _ready() -> void:
	var should_remain_active := visible or _active
	z_as_relative = false
	z_index = 15
	_additive_material = _make_additive_material()
	_build_children()
	set_active(should_remain_active)
	if should_remain_active:
		_apply_state()
		queue_redraw()


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _mandala_quad == null:
		_build_children()
	_state = next_state.duplicate(false)
	if _state.get("trails", null) is Array:
		_state["trails"] = (_state["trails"] as Array).duplicate(false)
	set_active(active)
	if not active:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func set_active(active: bool) -> void:
	if active and (not _active or _pulse_tween == null or not _pulse_tween.is_valid()):
		_start_loop_tweens()
	if active and not _active:
		_start_open_tween()
	_active = active
	visible = active
	set_process(false)
	if _mandala_quad != null:
		_mandala_quad.visible = active
	if _mandala_sprite != null:
		_mandala_sprite.visible = active and _get_mandala_texture() != null
	if _lock_burst_sprite != null:
		_lock_burst_sprite.visible = false
	if _release_burst_sprite != null:
		_release_burst_sprite.visible = false
	if _release_trail_sprite != null:
		_release_trail_sprite.visible = false
	if _trail_glow_line != null:
		_trail_glow_line.visible = active
	if _trail_core_line != null:
		_trail_core_line.visible = active
	if _release_line != null:
		_release_line.visible = false
	if not active:
		_stop_all_tweens()
		_set_particles_emitting(_mote_particles, false)
		_set_particles_emitting(_petal_particles, false)
		_set_particles_emitting(_release_particles, false)
		_last_release_id = -1
		open_value = 0.0
		release_flash = 0.0


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	_stop_all_tweens()
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"process_active": is_processing(),
		"shader_layers": _get_shader_layer_count(),
		"gpu_particle_layers": _get_gpu_particle_layer_count(),
		"texture_pieces_ready": bool(build_pipeline_status().get("meditation_fx_texture_pieces_ready", false)),
		"mandala_png_slot": _get_mandala_texture() != null,
		"lotus_petal_png_slot": _is_png_texture_loaded(LOTUS_PETAL_TEXTURE_PATH, _get_petal_texture()),
		"sutra_shard_png_slot": _is_png_texture_loaded(SUTRA_SHARD_TEXTURE_PATH, _get_sutra_texture()),
		"lock_burst_png_slot": _is_png_texture_loaded(LOCK_BURST_TEXTURE_PATH, _get_lock_burst_texture()),
		"release_burst_png_slot": _is_png_texture_loaded(RELEASE_BURST_TEXTURE_PATH, _get_release_burst_texture()),
		"release_trail_png_slot": _is_png_texture_loaded(RELEASE_TRAIL_TEXTURE_PATH, _get_release_trail_texture()),
		"mandala_writhe_shader": WritheEmber.is_material_using_shader(_mandala_image_material),
		"lock_burst_visible": _lock_burst_sprite != null and _lock_burst_sprite.visible,
		"release_burst_visible": _release_burst_sprite != null and _release_burst_sprite.visible,
		"release_trail_visible": _release_trail_sprite != null and _release_trail_sprite.visible,
		"trail_point_count": _get_trail_points().size(),
		"release_id": _last_release_id,
		"uses_viewport_layout": abs(scale.x - float(_state.get("render_scale", 1.0))) < 0.001,
}


func _draw() -> void:
	if not visible:
		return
	var trail_points: PackedVector2Array = _get_trail_points()
	var alpha: float = _get_alpha()
	if trail_points.size() > 0:
		_draw_trail_texture_pieces(trail_points, alpha)
	var release_active: bool = bool(_state.get("release_active", false))
	if release_active:
		_draw_release_texture_pieces(alpha)


func _apply_state() -> void:
	if _state.is_empty():
		return
	var render_scale: float = maxf(0.001, float(_state.get("render_scale", 1.0)))
	position = _as_vector2(_state.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	scale = Vector2(render_scale, render_scale)

	var boss_center: Vector2 = _get_boss_center()
	var ball_pos: Vector2 = _get_ball_pos()
	var alpha: float = _get_alpha()
	var progress: float = clampf(float(_state.get("progress", 0.0)), 0.0, 1.0)
	var release_active: bool = bool(_state.get("release_active", false))
	var release_progress: float = clampf(float(_state.get("release_progress", 0.0)), 0.0, 1.0)
	var trail_points: PackedVector2Array = _get_trail_points()

	_update_mandala(boss_center, alpha, progress, release_progress)
	_update_lock_burst(boss_center, alpha, progress)
	_update_trail_lines(trail_points, ball_pos, alpha, release_active, release_progress)
	_update_release_burst(ball_pos, alpha, release_active, release_progress)
	_update_release_trail(ball_pos, alpha, release_active, release_progress)
	_update_particles(boss_center, ball_pos, alpha, release_active)

	var release_id: int = int(_state.get("release_id", -1))
	if release_active and release_id != _last_release_id:
		_last_release_id = release_id
		_restart_release_particles()
		_start_release_tween()


func _update_mandala(boss_center: Vector2, alpha: float, progress: float, release_progress: float) -> void:
	var mandala_texture: Texture2D = _get_mandala_texture()
	if mandala_texture != null and _mandala_sprite != null:
		var sprite_size: Vector2 = mandala_texture.get_size()
		var mandala_size: float = MANDALA_BASE_SIZE * (0.92 + open_value * 0.22 + breath_value * 0.045 + release_progress * 0.20)
		_mandala_sprite.position = boss_center
		_mandala_sprite.scale = Vector2(mandala_size / maxf(1.0, sprite_size.x), mandala_size / maxf(1.0, sprite_size.y))
		_mandala_sprite.visible = alpha > 0.01
		_mandala_sprite.modulate = Color(1.0, 1.0, 1.0, alpha * (0.84 + open_value * 0.16))
		if _mandala_image_material != null:
			_mandala_image_material.set_shader_parameter("elapsed", elapsed_sec)
			_mandala_image_material.set_shader_parameter(
				"intensity",
				clampf(0.78 + pulse_value * 0.16 + release_flash * 0.34 + open_value * 0.12, 0.0, 1.45)
			)
		if _mandala_quad != null:
			_mandala_quad.visible = false
		return
	if _mandala_quad == null:
		return
	var size: float = MANDALA_BASE_SIZE * (0.84 + open_value * 0.22 + breath_value * 0.045 + release_progress * 0.18)
	_mandala_quad.position = boss_center - Vector2(size, size) * 0.5
	_mandala_quad.size = Vector2(size, size)
	_mandala_quad.visible = alpha > 0.01
	if _mandala_material != null:
		_mandala_material.set_shader_parameter("elapsed", elapsed_sec)
		_mandala_material.set_shader_parameter("pulse", pulse_value)
		_mandala_material.set_shader_parameter("breath", breath_value)
		_mandala_material.set_shader_parameter("open_value", open_value)
		_mandala_material.set_shader_parameter("release_flash", release_flash)
		_mandala_material.set_shader_parameter("alpha_scale", alpha)
		_mandala_material.set_shader_parameter("progress", progress)


func _update_lock_burst(boss_center: Vector2, alpha: float, progress: float) -> void:
	var texture: Texture2D = _get_lock_burst_texture()
	if _lock_burst_sprite == null or texture == null:
		return
	var burst_alpha: float = _get_lock_burst_alpha(progress) * alpha
	_lock_burst_sprite.visible = burst_alpha > 0.01
	if not _lock_burst_sprite.visible:
		return
	var texture_size: Vector2 = texture.get_size()
	var burst_t: float = clampf(
		(progress - LOCK_BURST_START_PROGRESS)
		/ maxf(0.001, LOCK_BURST_IN_PROGRESS + LOCK_BURST_HOLD_PROGRESS + LOCK_BURST_OUT_PROGRESS),
		0.0,
		1.0
	)
	var draw_size: float = MANDALA_BASE_SIZE * lerpf(0.50, 1.30, _ease_out_cubic(burst_t))
	_lock_burst_sprite.position = boss_center
	_lock_burst_sprite.rotation = -elapsed_sec * 0.58
	_lock_burst_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_lock_burst_sprite.modulate = Color(1.0, 1.0, 1.0, burst_alpha)
	_set_sprite_layer_params(_lock_burst_material, burst_alpha, 0.0, 0.006, 0.10, 7.0, 0.12)


func _update_release_burst(ball_pos: Vector2, alpha: float, release_active: bool, release_progress: float) -> void:
	var texture: Texture2D = _get_release_burst_texture()
	if _release_burst_sprite == null or texture == null:
		return
	var burst_alpha: float = _get_release_burst_alpha(release_progress) * alpha if release_active else 0.0
	_release_burst_sprite.visible = burst_alpha > 0.01
	if not _release_burst_sprite.visible:
		return
	var texture_size: Vector2 = texture.get_size()
	var scale_progress: float = _ease_out_cubic(clampf(release_progress / 0.30, 0.0, 1.0))
	var draw_size: float = MANDALA_BASE_SIZE * lerpf(0.40, 1.50, scale_progress)
	var origin: Vector2 = _as_vector2(_state.get("release_origin", ball_pos), ball_pos) + _get_shake_offset()
	_release_burst_sprite.position = origin
	_release_burst_sprite.rotation = elapsed_sec * 0.72
	_release_burst_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_release_burst_sprite.modulate = Color(1.0, 1.0, 1.0, burst_alpha)
	_set_sprite_layer_params(_release_burst_material, burst_alpha, 0.0, 0.008, 0.18, 9.5, 0.18)


func _update_release_trail(ball_pos: Vector2, alpha: float, release_active: bool, release_progress: float) -> void:
	var texture: Texture2D = _get_release_trail_texture()
	if _release_trail_sprite == null or texture == null:
		return
	var trail_alpha: float = alpha * (1.0 - _smoothstep(0.62, 1.0, release_progress)) if release_active else 0.0
	_release_trail_sprite.visible = trail_alpha > 0.01
	if not _release_trail_sprite.visible:
		return
	var origin: Vector2 = _as_vector2(_state.get("release_origin", ball_pos), ball_pos) + _get_shake_offset()
	var release_pos: Vector2 = _as_vector2(_state.get("release_pos", ball_pos), ball_pos) + _get_shake_offset()
	var velocity: Vector2 = _as_vector2(_state.get("release_velocity", Vector2.DOWN), Vector2.DOWN)
	if release_pos.distance_to(origin) < 24.0 and velocity.length_squared() > 0.001:
		release_pos = origin + velocity.normalized() * (110.0 + release_progress * 160.0)
	var direction: Vector2 = (release_pos - origin).normalized() if release_pos.distance_squared_to(origin) > 0.001 else Vector2.DOWN
	var texture_size: Vector2 = texture.get_size()
	var length: float = maxf(90.0, origin.distance_to(release_pos) * 1.18)
	var trail_size := Vector2(length + 80.0, RELEASE_LINE_WIDTH * 5.8 * (1.0 - release_progress * 0.22))
	_release_trail_sprite.position = release_pos - direction * trail_size.x * 0.32
	_release_trail_sprite.rotation = direction.angle()
	_release_trail_sprite.scale = Vector2(trail_size.x / maxf(1.0, texture_size.x), trail_size.y / maxf(1.0, texture_size.y))
	_release_trail_sprite.modulate = Color(1.0, 1.0, 1.0, trail_alpha)
	_set_sprite_layer_params(_release_trail_material, trail_alpha, 0.55, 0.004, 0.08, 12.0, 0.10)


func _update_trail_lines(
	trail_points: PackedVector2Array,
	ball_pos: Vector2,
	alpha: float,
	release_active: bool,
	release_progress: float
) -> void:
	if _trail_glow_line == null or _trail_core_line == null:
		return
	_trail_glow_line.clear_points()
	_trail_core_line.clear_points()
	for point in trail_points:
		_trail_glow_line.add_point(point)
		_trail_core_line.add_point(point)
	if trail_points.size() == 1:
		_trail_glow_line.add_point(ball_pos)
		_trail_core_line.add_point(ball_pos)
	_trail_glow_line.width = TRAIL_GLOW_WIDTH * (0.78 + breath_value * 0.18)
	_trail_core_line.width = TRAIL_CORE_WIDTH * (0.86 + pulse_value * 0.20)
	_trail_glow_line.default_color = Color(0.84, 0.56, 1.0, 0.44 * alpha)
	_trail_core_line.default_color = Color(1.0, 0.88, 0.38, 0.78 * alpha)
	if _trail_material != null:
		_trail_material.set_shader_parameter("elapsed", elapsed_sec)
		_trail_material.set_shader_parameter("pulse", pulse_value)
		_trail_material.set_shader_parameter("breath", breath_value)
		_trail_material.set_shader_parameter("alpha_scale", alpha)

	if _release_line == null:
		return
	_release_line.clear_points()
	_release_line.visible = release_active
	if release_active:
		var origin: Vector2 = _as_vector2(_state.get("release_origin", ball_pos), ball_pos) + _get_shake_offset()
		var release_pos: Vector2 = _as_vector2(_state.get("release_pos", ball_pos), ball_pos) + _get_shake_offset()
		var direction: Vector2 = _as_vector2(_state.get("release_velocity", Vector2.DOWN), Vector2.DOWN)
		if release_pos.distance_to(origin) < 24.0 and direction.length() > 0.001:
			release_pos = origin + direction.normalized() * (90.0 + release_progress * 120.0)
		_release_line.add_point(origin)
		_release_line.add_point(release_pos)
		_release_line.width = RELEASE_LINE_WIDTH * (1.0 - release_progress * 0.42)
		_release_line.default_color = Color(1.0, 0.92, 0.50, 0.76 * alpha * (1.0 - release_progress * 0.40))
		if _release_material != null:
			_release_material.set_shader_parameter("elapsed", elapsed_sec)
			_release_material.set_shader_parameter("flash", release_flash)
			_release_material.set_shader_parameter("alpha_scale", alpha * (1.0 - release_progress * 0.25))


func _update_particles(boss_center: Vector2, ball_pos: Vector2, alpha: float, release_active: bool) -> void:
	if _mote_particles != null:
		_mote_particles.position = boss_center
		_mote_particles.emitting = alpha > 0.04
		var mote_mat: ParticleProcessMaterial = _mote_particles.process_material
		if mote_mat != null:
			mote_mat.color = Color(1.0, 0.82, 0.36, alpha * (0.55 + pulse_value * 0.20))
	if _petal_particles != null:
		_petal_particles.position = ball_pos
		_petal_particles.emitting = alpha > 0.06 and not release_active
		var petal_mat: ParticleProcessMaterial = _petal_particles.process_material
		if petal_mat != null:
			petal_mat.color = Color(0.96, 0.78, 1.0, alpha * (0.54 + breath_value * 0.18))
	if _release_particles != null:
		var release_pos: Vector2 = _as_vector2(_state.get("release_origin", ball_pos), ball_pos) + _get_shake_offset()
		_release_particles.position = release_pos


func _draw_trail_texture_pieces(points: PackedVector2Array, alpha: float) -> void:
	var glow_texture: Texture2D = ImpactFlareTextureCache.get_glow_texture()
	var sutra_texture: Texture2D = _get_sutra_texture()
	var petal_texture: Texture2D = _get_petal_texture()
	for idx in range(points.size()):
		var point: Vector2 = points[idx]
		var t: float = float(idx) / maxf(1.0, float(points.size() - 1))
		var fade: float = pow(clampf(t, 0.0, 1.0), 0.7)
		var pulse: float = 0.72 + 0.28 * sin(elapsed_sec * 5.2 + float(idx) * 0.45)
		var glow_size: float = lerpf(18.0, 38.0, fade) * (0.86 + breath_value * 0.16)
		if glow_texture != null:
			draw_texture_rect(
				glow_texture,
				Rect2(point - Vector2(glow_size, glow_size) * 0.5, Vector2(glow_size, glow_size)),
				false,
				Color(1.0, 0.78, 0.30, alpha * fade * 0.18 * pulse)
			)
		if idx % 3 == 0 and sutra_texture != null:
			var strip_size := Vector2(20.0 + fade * 18.0, 7.0 + fade * 3.0)
			var offset := Vector2(sin(elapsed_sec * 2.0 + float(idx)) * 5.0, cos(elapsed_sec * 1.7 + float(idx)) * 3.0)
			draw_texture_rect(
				sutra_texture,
				Rect2(point + offset - strip_size * 0.5, strip_size),
				false,
				Color(1.0, 0.86, 0.38, alpha * fade * 0.42)
			)
		if idx % 4 == 1 and petal_texture != null:
			var petal_size := Vector2(11.0 + fade * 8.0, 8.0 + fade * 5.0)
			draw_texture_rect(
				petal_texture,
				Rect2(point + Vector2(4.0, -6.0) - petal_size * 0.5, petal_size),
				false,
				Color(0.95, 0.70, 1.0, alpha * fade * 0.34)
			)


func _draw_release_texture_pieces(alpha: float) -> void:
	var origin: Vector2 = _as_vector2(_state.get("release_origin", _get_ball_pos()), _get_ball_pos()) + _get_shake_offset()
	var glow_texture: Texture2D = ImpactFlareTextureCache.get_burst_texture()
	if glow_texture == null:
		return
	var release_progress: float = clampf(float(_state.get("release_progress", 0.0)), 0.0, 1.0)
	var size: float = 70.0 + release_flash * 54.0 + release_progress * 28.0
	draw_texture_rect(
		glow_texture,
		Rect2(origin - Vector2(size, size) * 0.5, Vector2(size, size)),
		false,
		Color(1.0, 0.88, 0.42, alpha * (0.28 + release_flash * 0.36) * (1.0 - release_progress * 0.55))
	)


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _mandala_quad == null:
		_mandala_quad = ColorRect.new()
		_mandala_quad.name = "PonkMeditationMandalaShader"
		_mandala_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mandala_quad.color = Color.WHITE
		_mandala_quad.z_index = -2
		_mandala_material = _build_mandala_material()
		_mandala_quad.material = _mandala_material
		_mandala_quad.visible = false
		add_child(_mandala_quad)
	if _mandala_sprite == null:
		_mandala_sprite = Sprite2D.new()
		_mandala_sprite.name = "PonkMeditationMandalaPng"
		_mandala_sprite.centered = true
		_mandala_sprite.z_index = -2
		_mandala_sprite.texture = _get_mandala_texture()
		_mandala_image_material = WritheEmber.build_material("meditation_mandala")
		_mandala_sprite.material = _mandala_image_material
		_mandala_sprite.visible = false
		add_child(_mandala_sprite)
	if _release_burst_sprite == null:
		_release_burst_sprite = Sprite2D.new()
		_release_burst_sprite.name = "PonkMeditationReleaseBurst"
		_release_burst_sprite.centered = true
		_release_burst_sprite.z_index = -1
		_release_burst_sprite.texture = _get_release_burst_texture()
		_release_burst_material = _make_sprite_layer_material()
		_release_burst_sprite.material = _release_burst_material
		_release_burst_sprite.visible = false
		add_child(_release_burst_sprite)
	if _lock_burst_sprite == null:
		_lock_burst_sprite = Sprite2D.new()
		_lock_burst_sprite.name = "PonkMeditationLockBurst"
		_lock_burst_sprite.centered = true
		_lock_burst_sprite.z_index = 3
		_lock_burst_sprite.texture = _get_lock_burst_texture()
		_lock_burst_material = _make_sprite_layer_material()
		_lock_burst_sprite.material = _lock_burst_material
		_lock_burst_sprite.visible = false
		add_child(_lock_burst_sprite)
	if _release_trail_sprite == null:
		_release_trail_sprite = Sprite2D.new()
		_release_trail_sprite.name = "PonkMeditationReleaseTrail"
		_release_trail_sprite.centered = true
		_release_trail_sprite.z_index = 3
		_release_trail_sprite.texture = _get_release_trail_texture()
		_release_trail_material = _make_sprite_layer_material()
		_release_trail_sprite.material = _release_trail_material
		_release_trail_sprite.visible = false
		add_child(_release_trail_sprite)
	if _trail_glow_line == null:
		_trail_glow_line = _make_trail_line("PonkMeditationTrailGlow", TRAIL_GLOW_WIDTH, Color(0.80, 0.56, 1.0, 0.34))
		_trail_glow_line.z_index = 0
		_trail_material = _build_trail_material()
		_trail_glow_line.material = _trail_material
		add_child(_trail_glow_line)
	if _trail_core_line == null:
		_trail_core_line = _make_trail_line("PonkMeditationTrailCore", TRAIL_CORE_WIDTH, Color(1.0, 0.86, 0.34, 0.78))
		_trail_core_line.z_index = 0
		add_child(_trail_core_line)
	if _release_line == null:
		_release_line = _make_trail_line("PonkMeditationReleaseBeam", RELEASE_LINE_WIDTH, Color(1.0, 0.92, 0.50, 0.78))
		_release_line.z_index = 2
		_release_material = _build_release_material()
		_release_line.material = _release_material
		_release_line.visible = false
		add_child(_release_line)
	if _mote_particles == null:
		_mote_particles = _make_particles(
			"PonkMeditationMoteParticles",
			72,
			1.85,
			_build_mote_particle_material(),
			ImpactFlareTextureCache.get_sparkle_texture()
		)
		_mote_particles.z_index = 1
		add_child(_mote_particles)
	if _petal_particles == null:
		_petal_particles = _make_particles(
			"PonkMeditationPetalParticles",
			46,
			0.72,
			_build_petal_particle_material(),
			_get_petal_texture()
		)
		_petal_particles.z_index = 1
		add_child(_petal_particles)
	if _release_particles == null:
		_release_particles = _make_particles(
			"PonkMeditationReleaseBurstParticles",
			64,
			0.48,
			_build_release_particle_material(),
			ImpactFlareTextureCache.get_sparkle_texture()
		)
		_release_particles.one_shot = true
		_release_particles.explosiveness = 0.96
		_release_particles.z_index = 1
		add_child(_release_particles)


func _make_trail_line(node_name: String, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.visible = false
	return line


func _make_particles(
	node_name: String,
	amount: int,
	lifetime: float,
	process_material: ParticleProcessMaterial,
	texture: Texture2D
) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.86
	particles.fixed_fps = 60
	particles.local_coords = true
	particles.visibility_rect = Rect2(-320.0, -260.0, 640.0, 520.0)
	particles.texture = texture
	particles.material = _additive_material
	particles.process_material = process_material
	particles.emitting = false
	return particles


func _start_loop_tweens() -> void:
	if not is_inside_tree():
		return
	_stop_loop_tweens()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "pulse_value", 1.0, 0.44).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "pulse_value", 0.0, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_breath_tween = create_tween()
	_breath_tween.set_loops()
	_breath_tween.tween_property(self, "breath_value", 1.0, 1.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(self, "breath_value", 0.0, 1.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _stop_loop_tweens() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null


func _start_open_tween() -> void:
	if not is_inside_tree():
		open_value = 1.0
		return
	_stop_open_tween()
	open_value = 0.0
	_open_tween = create_tween()
	_open_tween.tween_property(self, "open_value", 1.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_open_tween() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null


func _start_release_tween() -> void:
	if not is_inside_tree():
		release_flash = 0.0
		return
	_stop_release_tween()
	release_flash = 1.0
	_release_tween = create_tween()
	_release_tween.tween_property(self, "release_flash", 0.0, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _stop_release_tween() -> void:
	if _release_tween != null and _release_tween.is_valid():
		_release_tween.kill()
	_release_tween = null


func _stop_all_tweens() -> void:
	_stop_loop_tweens()
	_stop_open_tween()
	_stop_release_tween()


func _restart_release_particles() -> void:
	if _release_particles == null:
		return
	_release_particles.restart()
	_release_particles.emitting = true


func _get_trail_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var trails: Array = _get_array(_state.get("trails", []))
	var shake_offset: Vector2 = _get_shake_offset()
	var start_index: int = max(0, trails.size() - TRAIL_POINT_LIMIT)
	for idx in range(start_index, trails.size()):
		var trail: Dictionary = _get_dict(trails[idx])
		if trail.is_empty():
			continue
		var life: float = float(trail.get("life", 34.0))
		if life <= 0.0:
			continue
		points.append(_as_vector2(trail.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset)
	var ball_pos: Vector2 = _get_ball_pos()
	if points.is_empty() or points[points.size() - 1].distance_to(ball_pos) > 1.0:
		points.append(ball_pos)
	return points


func _get_alpha() -> float:
	var active: bool = bool(_state.get("active", false))
	var release_active: bool = bool(_state.get("release_active", false))
	if active:
		var progress: float = clampf(float(_state.get("progress", 0.0)), 0.0, 1.0)
		var intro: float = _smoothstep(0.0, 0.18, progress)
		var outro: float = 1.0 - _smoothstep(0.84, 1.0, progress)
		return clampf(intro * outro, 0.08, 1.0)
	if release_active:
		var release_progress: float = clampf(float(_state.get("release_progress", 0.0)), 0.0, 1.0)
		return clampf(1.0 - release_progress, 0.0, 0.86)
	return 0.0


func _get_boss_center() -> Vector2:
	return _as_vector2(_state.get("boss_center", Vector2(380.0, 78.0)), Vector2(380.0, 78.0)) + _get_shake_offset()


func _get_ball_pos() -> Vector2:
	return _as_vector2(_state.get("ball_pos", Vector2(380.0, 150.0)), Vector2(380.0, 150.0)) + _get_shake_offset()


func _get_shake_offset() -> Vector2:
	return _as_vector2(_state.get("shake_offset", Vector2.ZERO), Vector2.ZERO)


func _get_shader_layer_count() -> int:
	var count := 0
	if _mandala_material != null:
		count += 1
	if _mandala_image_material != null:
		count += 1
	if _trail_material != null:
		count += 1
	if _release_material != null:
		count += 1
	@warning_ignore("shadowed_variable_base_class")
	for material in [_lock_burst_material, _release_burst_material, _release_trail_material]:
		if material != null:
			count += 1
	return count


func _get_gpu_particle_layer_count() -> int:
	var count := 0
	if _mote_particles != null:
		count += 1
	if _petal_particles != null:
		count += 1
	if _release_particles != null:
		count += 1
	return count


func _set_particles_emitting(particles: GPUParticles2D, emitting: bool) -> void:
	if particles != null:
		particles.emitting = emitting


func _set_sprite_layer_params(
	shader_material: ShaderMaterial,
	alpha: float,
	scroll_x: float,
	chromatic_strength: float,
	pulse_amp: float,
	pulse_speed: float,
	warm_boost: float
) -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("elapsed", elapsed_sec)
	shader_material.set_shader_parameter("alpha_scale", clampf(alpha, 0.0, 1.0))
	shader_material.set_shader_parameter("scroll_x", scroll_x)
	shader_material.set_shader_parameter("chromatic_strength", chromatic_strength)
	shader_material.set_shader_parameter("pulse_amp", pulse_amp)
	shader_material.set_shader_parameter("pulse_speed", pulse_speed)
	shader_material.set_shader_parameter("warm_boost", warm_boost)


func _get_lock_burst_alpha(progress: float) -> float:
	var t: float = progress - LOCK_BURST_START_PROGRESS
	if t < 0.0:
		return 0.0
	if t < LOCK_BURST_IN_PROGRESS:
		return _smoothstep(0.0, LOCK_BURST_IN_PROGRESS, t)
	var hold_end: float = LOCK_BURST_IN_PROGRESS + LOCK_BURST_HOLD_PROGRESS
	if t < hold_end:
		return 1.0
	var out_end: float = hold_end + LOCK_BURST_OUT_PROGRESS
	if t < out_end:
		return 1.0 - _smoothstep(hold_end, out_end, t)
	return 0.0


func _get_release_burst_alpha(release_progress: float) -> float:
	if release_progress < 0.10:
		return _smoothstep(0.0, 0.10, release_progress)
	if release_progress < 0.20:
		return 1.0
	if release_progress < 0.55:
		return 1.0 - _smoothstep(0.20, 0.55, release_progress)
	return 0.0


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_mandala_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_mandala_shader()
	return material


static func _build_mandala_image_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_mandala_image_shader()
	return material


static func _build_trail_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_trail_shader()
	return material


static func _build_release_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_release_shader()
	return material


static func _make_sprite_layer_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_sprite_layer_shader()
	return material


static func _get_mandala_shader() -> Shader:
	if _mandala_shader != null:
		return _mandala_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float breath = 0.0;
uniform float open_value = 1.0;
uniform float release_flash = 0.0;
uniform float alpha_scale = 1.0;
uniform float progress = 0.0;

float band(float r, float center, float width) {
	return smoothstep(width, 0.0, abs(r - center));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float outer = smoothstep(1.08, 0.12, r);
	float spin = elapsed * (0.45 + breath * 0.10);
	float petals = pow(0.5 + 0.5 * cos(angle * 12.0 - spin * 3.0), 4.0);
	float lotus = pow(0.5 + 0.5 * sin(angle * 8.0 + r * 8.0 + spin * 2.2), 3.0);
	float ring_a = band(r, 0.34 + breath * 0.018, 0.030);
	float ring_b = band(r, 0.56 + pulse * 0.020, 0.026);
	float ring_c = band(r, 0.82 - progress * 0.04, 0.018);
	float scan = 0.70 + 0.30 * sin((UV.x + UV.y) * 80.0 + elapsed * 6.0);
	float seam = pow(max(0.0, sin(angle * 24.0 + elapsed * 2.0)), 8.0) * smoothstep(0.92, 0.26, r);
	float core = smoothstep(0.26, 0.0, r) * (0.35 + pulse * 0.14 + release_flash * 0.34);
	float body = outer * scan * (
		ring_a * 0.58
		+ ring_b * 0.46
		+ ring_c * 0.38
		+ petals * smoothstep(0.90, 0.28, r) * 0.20
		+ lotus * smoothstep(0.72, 0.18, r) * 0.16
		+ seam * 0.22
		+ core
	);
	body *= alpha_scale * (0.70 + open_value * 0.30 + release_flash * 0.45);
	vec3 gold = vec3(1.0, 0.74, 0.26);
	vec3 lotus_color = vec3(0.86, 0.54, 1.0);
	vec3 calm = vec3(0.44, 0.82, 1.0);
	vec3 color = mix(lotus_color, gold, clamp(ring_a + ring_b + core, 0.0, 1.0));
	color = mix(color, calm, seam * 0.38);
	color = mix(color, vec3(1.0, 0.94, 0.70), release_flash * outer * 0.45);
	COLOR = vec4(color, clamp(body, 0.0, 0.86));
}
"""
	_mandala_shader = shader
	return _mandala_shader


static func _get_mandala_image_shader() -> Shader:
	if _mandala_image_shader != null:
		return _mandala_image_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float breath = 0.0;
uniform float open_value = 1.0;
uniform float release_flash = 0.0;
uniform float alpha_scale = 1.0;
uniform float progress = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float angle = elapsed * 0.25;
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated = vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + vec2(0.5);
	float bounds_mask = step(0.0, rotated.x) * step(rotated.x, 1.0) * step(0.0, rotated.y) * step(rotated.y, 1.0);
	rotated = clamp(rotated, vec2(0.0), vec2(1.0));
	vec4 tex = texture(TEXTURE, rotated);
	float r = length(centered);
	float radial = smoothstep(0.54, 0.46, r);
	float breath_alpha = 0.40 + 0.60 * (0.5 + 0.5 * sin(elapsed * 2.1 + breath * 1.4));
	float ring_pulse = 0.88 + pulse * 0.12 + release_flash * 0.24;
	float alpha = tex.a * bounds_mask * radial * alpha_scale * breath_alpha * ring_pulse * (0.82 + open_value * 0.18);
	vec3 color = tex.rgb;
	color = mix(color, vec3(1.0, 0.88, 0.52), release_flash * 0.22);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.92));
}
"""
	_mandala_image_shader = shader
	return _mandala_image_shader


static func _get_sprite_layer_shader() -> Shader:
	if _sprite_layer_shader != null:
		return _sprite_layer_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float alpha_scale = 1.0;
uniform float scroll_x = 0.0;
uniform float chromatic_strength = 0.006;
uniform float pulse_amp = 0.12;
uniform float pulse_speed = 8.0;
uniform float warm_boost = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + elapsed * scroll_x);
	vec2 centered = UV - vec2(0.5);
	vec2 dir = normalize(centered + vec2(0.0001));
	vec4 tex = texture(TEXTURE, uv);
	vec4 red_sample = texture(TEXTURE, clamp(uv + dir * chromatic_strength, vec2(0.0), vec2(1.0)));
	vec4 blue_sample = texture(TEXTURE, clamp(uv - dir * chromatic_strength, vec2(0.0), vec2(1.0)));
	vec3 color = tex.rgb;
	color.r = max(color.r, red_sample.r * 1.04);
	color.b = max(color.b, blue_sample.b * 1.08);
	color = mix(color, vec3(1.0, 0.86, 0.42), warm_boost);
	float pulse = 1.0 + pulse_amp * (0.5 + 0.5 * sin(elapsed * pulse_speed));
	COLOR = vec4(color, clamp(tex.a * alpha_scale * pulse * COLOR.a, 0.0, 0.96));
}
"""
	_sprite_layer_shader = shader
	return _sprite_layer_shader


static func _get_trail_shader() -> Shader:
	if _trail_shader != null:
		return _trail_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float breath = 0.0;
uniform float alpha_scale = 1.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float edge = smoothstep(1.0, 0.0, across);
	float core = smoothstep(0.38, 0.0, across);
	float flow = 0.5 + 0.5 * sin(UV.x * 28.0 - elapsed * 8.0);
	float sutra = pow(flow, 5.0) * edge;
	float alpha = (edge * 0.20 + core * 0.52 + sutra * 0.34) * alpha_scale * (0.78 + pulse * 0.18 + breath * 0.08);
	vec3 violet = vec3(0.74, 0.46, 1.0);
	vec3 gold = vec3(1.0, 0.82, 0.30);
	vec3 white = vec3(1.0, 0.96, 0.78);
	vec3 color = mix(violet, gold, clamp(core + sutra * 0.50, 0.0, 1.0));
	color = mix(color, white, core * 0.28);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.82));
}
"""
	_trail_shader = shader
	return _trail_shader


static func _get_release_shader() -> Shader:
	if _release_shader != null:
		return _release_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float flash = 0.0;
uniform float alpha_scale = 1.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float edge = smoothstep(1.0, 0.0, across);
	float core = smoothstep(0.28, 0.0, across);
	float dash = 0.5 + 0.5 * sin(UV.x * 34.0 - elapsed * 18.0);
	float alpha = (edge * 0.22 + core * 0.62 + pow(dash, 6.0) * 0.28) * alpha_scale * (0.78 + flash * 0.55);
	vec3 color = mix(vec3(1.0, 0.54, 0.22), vec3(1.0, 0.96, 0.64), clamp(core + flash * 0.35, 0.0, 1.0));
	COLOR = vec4(color, clamp(alpha, 0.0, 0.92));
}
"""
	_release_shader = shader
	return _release_shader


static func _build_mote_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 34.0
	mat.radial_accel_min = -18.0
	mat.radial_accel_max = 22.0
	mat.tangential_accel_min = -90.0
	mat.tangential_accel_max = 90.0
	mat.damping_min = 8.0
	mat.damping_max = 26.0
	mat.scale_min = 0.018
	mat.scale_max = 0.070
	mat.color = Color(1.0, 0.82, 0.36, 0.66)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 92.0
	mat.emission_ring_inner_radius = 28.0
	mat.emission_ring_height = 0.0
	return mat


static func _build_petal_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	var png_loaded: bool = _is_png_texture_loaded(LOTUS_PETAL_TEXTURE_PATH, _get_petal_texture())
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 16.0
	mat.initial_velocity_max = 68.0
	mat.radial_accel_min = -30.0
	mat.radial_accel_max = 24.0
	mat.tangential_accel_min = -160.0
	mat.tangential_accel_max = 160.0
	mat.damping_min = 12.0
	mat.damping_max = 36.0
	mat.scale_min = 0.010 if png_loaded else 0.055
	mat.scale_max = 0.027 if png_loaded else 0.145
	mat.color = Color(0.96, 0.78, 1.0, 0.62)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	return mat


static func _build_release_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 68.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 90.0
	mat.initial_velocity_max = 260.0
	mat.radial_accel_min = -40.0
	mat.radial_accel_max = 160.0
	mat.tangential_accel_min = -120.0
	mat.tangential_accel_max = 120.0
	mat.damping_min = 18.0
	mat.damping_max = 80.0
	mat.scale_min = 0.026
	mat.scale_max = 0.095
	mat.color = Color(1.0, 0.84, 0.34, 0.82)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 12.0
	return mat


static func _get_mandala_texture() -> Texture2D:
	if _mandala_texture != null:
		return _mandala_texture
	_mandala_texture = ProjectResourceLoader.load_texture(MANDALA_TEXTURE_PATH)
	return _mandala_texture


static func _get_petal_texture() -> Texture2D:
	if _petal_texture != null:
		return _petal_texture
	var loaded: Texture2D = ProjectResourceLoader.load_texture(LOTUS_PETAL_TEXTURE_PATH)
	if loaded != null:
		_petal_texture = loaded
		return _petal_texture
	var size := 64
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2((float(size) - 1.0) * 0.5, (float(size) - 1.0) * 0.5)
	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x), float(y)) - center
			p.x *= 0.72
			p.y *= 1.52
			var d: float = p.length() / 28.0
			var vein: float = _smoothstep(0.08, 0.0, abs(p.x) / 28.0) * _smoothstep(1.0, 0.0, abs(p.y) / 28.0)
			var alpha: float = pow(maxf(0.0, 1.0 - d), 1.6)
			var tip: float = _smoothstep(1.0, 0.0, abs((float(y) - center.y) / 30.0))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha * (0.72 + vein * 0.28) * tip, 0.0, 1.0)))
	_petal_texture = ImageTexture.create_from_image(image)
	return _petal_texture


static func _get_sutra_texture() -> Texture2D:
	if _sutra_texture != null:
		return _sutra_texture
	var loaded: Texture2D = ProjectResourceLoader.load_texture(SUTRA_SHARD_TEXTURE_PATH)
	if loaded != null:
		_sutra_texture = loaded
		return _sutra_texture
	var width := 96
	var height := 32
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var uv := Vector2(float(x) / float(width - 1), float(y) / float(height - 1))
			var edge: float = _smoothstep(0.0, 0.18, uv.y) * (1.0 - _smoothstep(0.82, 1.0, uv.y))
			var body: float = _smoothstep(0.0, 0.10, uv.x) * (1.0 - _smoothstep(0.90, 1.0, uv.x)) * edge
			@warning_ignore("integer_division")
			var stripe: float = 0.22 if (x / 8) % 2 == 0 else 0.0
			var glyph: float = 0.0
			if x % 17 < 3 and y > 8 and y < 24:
				glyph = 0.36
			var alpha: float = clampf(body * (0.46 + stripe + glyph), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_sutra_texture = ImageTexture.create_from_image(image)
	return _sutra_texture


static func _get_lock_burst_texture() -> Texture2D:
	if _lock_burst_texture != null:
		return _lock_burst_texture
	var loaded: Texture2D = ProjectResourceLoader.load_texture(LOCK_BURST_TEXTURE_PATH)
	if loaded != null:
		_lock_burst_texture = loaded
		return _lock_burst_texture
	_lock_burst_texture = ImpactFlareTextureCache.get_burst_texture()
	return _lock_burst_texture


static func _get_release_burst_texture() -> Texture2D:
	if _release_burst_texture != null:
		return _release_burst_texture
	var loaded: Texture2D = ProjectResourceLoader.load_texture(RELEASE_BURST_TEXTURE_PATH)
	if loaded != null:
		_release_burst_texture = loaded
		return _release_burst_texture
	_release_burst_texture = ImpactFlareTextureCache.get_burst_texture()
	return _release_burst_texture


static func _get_release_trail_texture() -> Texture2D:
	if _release_trail_texture != null:
		return _release_trail_texture
	_release_trail_texture = ProjectResourceLoader.load_texture(RELEASE_TRAIL_TEXTURE_PATH)
	return _release_trail_texture


static func _is_png_texture_loaded(path: String, texture: Texture2D) -> bool:
	if texture == null:
		return false
	var loaded: Texture2D = ProjectResourceLoader.load_texture(path)
	return loaded != null and loaded == texture


static func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if abs(edge1 - edge0) <= 0.0001:
		return 0.0
	var t: float = clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _ease_out_cubic(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
