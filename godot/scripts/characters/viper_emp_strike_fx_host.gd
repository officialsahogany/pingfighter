extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const BASE_PREP_SIZE := 150.0
const BASE_JET_SIZE := Vector2(86.0, 235.0)
const BASE_SHOCKWAVE_HEIGHT := 172.0
const BASE_HIT_BURST_SIZE := 118.0
const PARTICLE_FIXED_FPS := 30
const SHOCKWAVE_TEXTURE_RINGS := 2

static var _cached_prep_material: ShaderMaterial = null
static var _cached_jet_material: ShaderMaterial = null
static var _cached_shockwave_material: ShaderMaterial = null
static var _cached_charge_particle_material: ParticleProcessMaterial = null
static var _cached_jet_particle_material: ParticleProcessMaterial = null
static var _cached_shockwave_particle_material: ParticleProcessMaterial = null
static var _cached_hit_particle_material: ParticleProcessMaterial = null
static var _cached_additive_material: CanvasItemMaterial = null
static var _prewarmed := false
static var _prewarm_step_index := 0

var pulse_value := 0.0
var breath_value := 0.0
var hit_flash_value := 0.0
var shock_flash_value := 0.0
var elapsed_sec := 0.0

var _state: Dictionary = {}
var _prep_quad: ColorRect = null
var _jet_quad: ColorRect = null
var _shockwave_quad: ColorRect = null
var _prep_material: ShaderMaterial = null
var _jet_material: ShaderMaterial = null
var _shockwave_material: ShaderMaterial = null
var _charge_particles: GPUParticles2D = null
var _jet_particles: GPUParticles2D = null
var _shockwave_particles: GPUParticles2D = null
var _hit_particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null
var _pulse_tween: Tween = null
var _breath_tween: Tween = null
var _hit_tween: Tween = null
var _shock_tween: Tween = null
var _last_hit_spawn_msec := 0
var _last_shock_spawn_msec := 0


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
			ImpactShockwaveTextureCache.prewarm()
		2:
			_build_prep_material()
		3:
			_build_jet_material()
		4:
			_build_shockwave_material()
		5:
			_build_charge_particle_material()
		6:
			_build_jet_particle_material()
		7:
			_build_shockwave_particle_material()
		8:
			_build_hit_particle_material()
		9:
			_make_additive_material()
		_:
			_prewarmed = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func _ready() -> void:
	z_as_relative = false
	z_index = 17
	_additive_material = _make_additive_material()
	_build_children()
	set_active(false)


func prewarm_runtime_nodes() -> void:
	prewarm_assets()
	if _additive_material == null:
		_additive_material = _make_additive_material()
	_build_children()
	set_active(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _prep_quad == null:
		_additive_material = _make_additive_material()
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active)
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if active:
		process_mode = Node.PROCESS_MODE_INHERIT
		_start_loop_tweens()
		return
	if not active:
		_hide_quad(_prep_quad)
		_hide_quad(_jet_quad)
		_hide_quad(_shockwave_quad)
		_set_particles_emitting(_charge_particles, false)
		_set_particles_emitting(_jet_particles, false)
		_set_particles_emitting(_shockwave_particles, false)
		_set_particles_emitting(_hit_particles, false)
		_last_hit_spawn_msec = 0
		_last_shock_spawn_msec = 0
		hit_flash_value = 0.0
		shock_flash_value = 0.0
		pulse_value = 0.0
		breath_value = 0.0
		_kill_loop_tweens()
		_kill_one_shot_tweens()
		process_mode = Node.PROCESS_MODE_DISABLED


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	for tween in [_pulse_tween, _breath_tween, _hit_tween, _shock_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_pulse_tween = null
	_breath_tween = null
	_hit_tween = null
	_shock_tween = null
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	var particle_count := 0
	for particles in [_charge_particles, _jet_particles, _shockwave_particles, _hit_particles]:
		if particles != null:
			particle_count += 1
	var shader_count := 0
	@warning_ignore("shadowed_variable_base_class")
	for material in [_prep_material, _jet_material, _shockwave_material]:
		if material != null:
			shader_count += 1
	return {
		"shader_layers": shader_count,
		"gpu_particle_layers": particle_count,
		"texture_pieces_ready": ImpactFlareTextureCache.get_glow_texture() != null and ImpactShockwaveTextureCache.get_full_ring_texture() != null,
		"loop_tween_active": _pulse_tween != null and _pulse_tween.is_valid(),
		"active": visible,
		"processing": is_processing(),
		"process_mode": process_mode,
		"charge_emitting": _charge_particles != null and _charge_particles.emitting,
		"jet_emitting": _jet_particles != null and _jet_particles.emitting,
		"shockwave_emitting": _shockwave_particles != null and _shockwave_particles.emitting,
		"hit_emitting": _hit_particles != null and _hit_particles.emitting,
	}


func _draw() -> void:
	if not visible:
		return
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	_draw_prep_texture_layers(render_scale)
	_draw_jet_texture_layers(render_scale)
	_draw_shockwave_texture_layers(render_scale)
	_draw_hit_texture_layers(render_scale)
	_draw_hit_text(render_scale)


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _prep_quad == null:
		_prep_quad = _make_quad("EmpPrepCore", _build_prep_material())
		add_child(_prep_quad)
		_prep_material = _prep_quad.material as ShaderMaterial
	if _jet_quad == null:
		_jet_quad = _make_quad("EmpJetColumn", _build_jet_material())
		add_child(_jet_quad)
		_jet_material = _jet_quad.material as ShaderMaterial
	if _shockwave_quad == null:
		_shockwave_quad = _make_quad("EmpShockwaveBand", _build_shockwave_material())
		add_child(_shockwave_quad)
		_shockwave_material = _shockwave_quad.material as ShaderMaterial
	if _charge_particles == null:
		_charge_particles = _make_particles("EmpChargeParticles", 28, 0.58, _build_charge_particle_material(), ImpactFlareTextureCache.get_sparkle_texture())
		add_child(_charge_particles)
	if _jet_particles == null:
		_jet_particles = _make_particles("EmpJetParticles", 36, 0.42, _build_jet_particle_material(), ImpactFlareTextureCache.get_sparkle_texture())
		add_child(_jet_particles)
	if _shockwave_particles == null:
		_shockwave_particles = _make_particles("EmpShockwaveParticles", 48, 0.72, _build_shockwave_particle_material(), ImpactFlareTextureCache.get_sparkle_texture())
		add_child(_shockwave_particles)
	if _hit_particles == null:
		_hit_particles = _make_particles("EmpHitBurstParticles", 40, 0.46, _build_hit_particle_material(), ImpactFlareTextureCache.get_burst_texture())
		_hit_particles.one_shot = true
		_hit_particles.explosiveness = 0.88
		add_child(_hit_particles)


func _start_loop_tweens() -> void:
	if not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		pass
	else:
		_pulse_tween = create_tween()
		_pulse_tween.set_loops()
		_pulse_tween.tween_property(self, "pulse_value", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_pulse_tween.tween_property(self, "pulse_value", 0.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if _breath_tween != null and _breath_tween.is_valid():
		pass
	else:
		_breath_tween = create_tween()
		_breath_tween.set_loops()
		_breath_tween.tween_property(self, "breath_value", 1.0, 0.92).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_breath_tween.tween_property(self, "breath_value", 0.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _kill_loop_tweens() -> void:
	for tween in [_pulse_tween, _breath_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_pulse_tween = null
	_breath_tween = null


func _kill_one_shot_tweens() -> void:
	for tween in [_hit_tween, _shock_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_hit_tween = null
	_shock_tween = null


func _apply_state() -> void:
	if _state.is_empty():
		return
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	var hold_active: bool = bool(_state.get("hold_active", false))
	var phase: int = int(_state.get("phase", -1))
	var hold_ratio: float = clamp(float(_state.get("hold_ratio", 0.0)), 0.0, 1.0)
	var prep_progress: float = clamp(float(_state.get("prep_progress", 0.0)), 0.0, 1.0)
	var shock_progress: float = clamp(float(_state.get("shockwave_progress", 0.0)), 0.0, 1.0)
	var shock_alpha: float = clamp(float(_state.get("shockwave_alpha", 0.0)), 0.0, 1.0)
	var shock_radius: float = max(38.0, float(_state.get("shockwave_radius", 38.0 + shock_progress * 220.0)))
	var height_ratio: float = clamp(float(_state.get("height_ratio", 0.0)), 0.0, 1.0)
	var player_center: Vector2 = _as_vector2(_state.get("screen_player_center", Vector2.ZERO), Vector2.ZERO)
	var foot: Vector2 = _as_vector2(_state.get("screen_foot", player_center), player_center)
	var shock_center: Vector2 = _as_vector2(_state.get("screen_shockwave_center", foot), foot)
	var hit_pos: Vector2 = _as_vector2(_state.get("screen_hit_pos", shock_center), shock_center)

	var prep_visible := hold_active or phase == 0
	var prep_alpha: float = (0.30 + hold_ratio * 0.52) if hold_active else (0.76 - prep_progress * 0.10)
	var prep_size: float = (84.0 + hold_ratio * 74.0 if hold_active else BASE_PREP_SIZE + prep_progress * 82.0) * render_scale
	_apply_quad(_prep_quad, player_center, Vector2(prep_size, prep_size), prep_visible, prep_alpha)
	if _prep_material != null:
		_prep_material.set_shader_parameter("elapsed", elapsed_sec)
		_prep_material.set_shader_parameter("pulse", pulse_value)
		_prep_material.set_shader_parameter("breath", breath_value)
		_prep_material.set_shader_parameter("progress", max(hold_ratio, prep_progress))
		_prep_material.set_shader_parameter("alpha", prep_alpha)

	var jet_visible := phase == 1
	var jet_size := Vector2(BASE_JET_SIZE.x * (0.95 + height_ratio * 0.28), BASE_JET_SIZE.y * (0.82 + height_ratio * 0.35)) * render_scale
	var jet_center := foot - Vector2(0.0, jet_size.y * 0.42)
	_apply_quad(_jet_quad, jet_center, jet_size, jet_visible, 0.84)
	if _jet_material != null:
		_jet_material.set_shader_parameter("elapsed", elapsed_sec)
		_jet_material.set_shader_parameter("pulse", pulse_value)
		_jet_material.set_shader_parameter("height_ratio", height_ratio)
		_jet_material.set_shader_parameter("alpha", 0.84 if jet_visible else 0.0)

	var shock_visible := shock_alpha > 0.01
	var shock_width: float = max(120.0 + 740.0 * shock_progress, shock_radius * 2.0 + 96.0) * render_scale
	var shock_height: float = BASE_SHOCKWAVE_HEIGHT * (0.86 + (1.0 - shock_progress) * 0.28) * render_scale
	_apply_quad(_shockwave_quad, shock_center + Vector2(0.0, -12.0 * render_scale), Vector2(shock_width, shock_height), shock_visible, shock_alpha)
	if _shockwave_material != null:
		_shockwave_material.set_shader_parameter("elapsed", elapsed_sec)
		_shockwave_material.set_shader_parameter("pulse", pulse_value)
		_shockwave_material.set_shader_parameter("progress", shock_progress)
		_shockwave_material.set_shader_parameter("flash", shock_flash_value)
		_shockwave_material.set_shader_parameter("alpha", shock_alpha)

	_sync_continuous_particles(render_scale, hold_active, phase, prep_alpha, player_center, foot, shock_visible, shock_center, shock_alpha, shock_progress, shock_radius)
	_sync_one_shot_particles(hit_pos, render_scale)


func _sync_continuous_particles(
	render_scale: float,
	hold_active: bool,
	phase: int,
	prep_alpha: float,
	player_center: Vector2,
	foot: Vector2,
	shock_visible: bool,
	shock_center: Vector2,
	shock_alpha: float,
	shock_progress: float,
	shock_radius: float
) -> void:
	if _charge_particles != null:
		_charge_particles.position = player_center
		_charge_particles.scale = Vector2.ONE * render_scale * (0.78 + pulse_value * 0.10)
		_charge_particles.emitting = hold_active or phase == 0
		var charge_mat: ParticleProcessMaterial = _charge_particles.process_material
		if charge_mat != null:
			charge_mat.color = Color(0.34, 0.96, 1.0, clamp(prep_alpha, 0.0, 0.95))
	if _jet_particles != null:
		_jet_particles.position = foot
		_jet_particles.scale = Vector2(render_scale * 0.78, render_scale * 1.34)
		_jet_particles.emitting = phase == 1
	if _shockwave_particles != null:
		_shockwave_particles.position = shock_center
		_shockwave_particles.scale = Vector2(render_scale * max(1.0 + shock_progress * 2.25, shock_radius / 130.0), render_scale * 0.48)
		_shockwave_particles.emitting = shock_visible
		var shock_mat: ParticleProcessMaterial = _shockwave_particles.process_material
		if shock_mat != null:
			shock_mat.color = Color(0.45, 0.96, 1.0, shock_alpha * (0.56 + shock_flash_value * 0.34))


func _sync_one_shot_particles(hit_pos: Vector2, render_scale: float) -> void:
	var hit_spawn_msec: int = int(_state.get("hit_spawn_msec", 0))
	if hit_spawn_msec <= 0 or _hit_particles == null:
		return
	_hit_particles.position = hit_pos
	_hit_particles.scale = Vector2.ONE * render_scale * (0.58 + clamp(float(_state.get("height_ratio", 0.0)), 0.0, 1.0) * 0.20)
	if hit_spawn_msec != _last_hit_spawn_msec:
		_last_hit_spawn_msec = hit_spawn_msec
		_start_hit_tween()
		_hit_particles.restart()
		_hit_particles.emitting = true
	var shock_spawn_msec: int = int(_state.get("shockwave_spawn_msec", 0))
	if shock_spawn_msec > 0 and shock_spawn_msec != _last_shock_spawn_msec:
		_last_shock_spawn_msec = shock_spawn_msec
		_start_shock_tween()


func _start_hit_tween() -> void:
	hit_flash_value = 1.0
	if not is_inside_tree():
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "hit_flash_value", 0.0, 0.36).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _start_shock_tween() -> void:
	shock_flash_value = 1.0
	if not is_inside_tree():
		return
	if _shock_tween != null and _shock_tween.is_valid():
		_shock_tween.kill()
	_shock_tween = create_tween()
	_shock_tween.tween_property(self, "shock_flash_value", 0.0, 0.48).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _draw_prep_texture_layers(render_scale: float) -> void:
	if _prep_quad == null or not _prep_quad.visible:
		return
	var center: Vector2 = _prep_quad.position + _prep_quad.size * 0.5
	var progress: float = clamp(float(_state.get("prep_progress", _state.get("hold_ratio", 0.0))), 0.0, 1.0)
	var alpha: float = clamp(float(_state.get("hold_ratio", 0.0)) * 0.44 + 0.30, 0.0, 0.82)
	if int(_state.get("phase", -1)) == 0:
		alpha = 0.64
	_draw_ring_texture(center, (42.0 + progress * 60.0) * render_scale, Color(0.38, 0.98, 1.0, alpha))
	_draw_centered_texture(ImpactFlareTextureCache.get_burst_texture(), center, (74.0 + pulse_value * 18.0) * render_scale, Color(1.0, 0.62, 0.20, alpha * 0.30))
	_draw_centered_texture(ImpactFlareTextureCache.get_sparkle_texture(), center, (26.0 + breath_value * 8.0) * render_scale, Color(0.92, 1.0, 1.0, alpha * 0.60))


func _draw_jet_texture_layers(render_scale: float) -> void:
	if _jet_quad == null or not _jet_quad.visible:
		return
	var center: Vector2 = _jet_quad.position + _jet_quad.size * 0.5
	_draw_centered_texture(ImpactFlareTextureCache.get_glow_texture(), center, max(_jet_quad.size.x, _jet_quad.size.y) * 0.62, Color(1.0, 0.52, 0.14, 0.28))
	_draw_centered_texture(ImpactFlareTextureCache.get_sparkle_texture(), center + Vector2(0.0, _jet_quad.size.y * 0.32), 46.0 * render_scale, Color(0.56, 0.98, 1.0, 0.54))


func _draw_shockwave_texture_layers(render_scale: float) -> void:
	if _shockwave_quad == null or not _shockwave_quad.visible:
		return
	var center: Vector2 = _as_vector2(_state.get("screen_shockwave_center", Vector2.ZERO), Vector2.ZERO)
	var progress: float = clamp(float(_state.get("shockwave_progress", 0.0)), 0.0, 1.0)
	var alpha: float = clamp(float(_state.get("shockwave_alpha", 0.0)), 0.0, 1.0)
	var shock_radius: float = max(38.0, float(_state.get("shockwave_radius", 38.0 + progress * 220.0))) * render_scale
	for i in range(SHOCKWAVE_TEXTURE_RINGS):
		var radius: float = max(12.0 * render_scale, shock_radius - float(i) * 28.0 * render_scale)
		_draw_ring_texture(center + Vector2(0.0, -8.0 * render_scale), radius, Color(0.36, 0.96, 1.0, alpha * (0.38 - float(i) * 0.07)))
	_draw_centered_texture(ImpactFlareTextureCache.get_burst_texture(), center, (96.0 + progress * 58.0) * render_scale, Color(1.0, 0.72, 0.24, alpha * (0.28 + shock_flash_value * 0.26)))


func _draw_hit_texture_layers(render_scale: float) -> void:
	if hit_flash_value <= 0.01:
		return
	var center: Vector2 = _as_vector2(_state.get("screen_hit_pos", Vector2.ZERO), Vector2.ZERO)
	_draw_centered_texture(ImpactFlareTextureCache.get_burst_texture(), center, BASE_HIT_BURST_SIZE * render_scale * (1.0 + (1.0 - hit_flash_value) * 0.35), Color(0.38, 0.98, 1.0, hit_flash_value * 0.52))
	_draw_ring_texture(center, (34.0 + (1.0 - hit_flash_value) * 72.0) * render_scale, Color(1.0, 0.82, 0.34, hit_flash_value * 0.55))


func _draw_hit_text(_render_scale: float) -> void:
	var hit_text_timer: float = float(_state.get("hit_text_timer", 0.0))
	if hit_text_timer <= 0.0:
		return
	var hit_text_frames: float = max(1.0, float(_state.get("hit_text_frames", 50.0)))
	var timer_ratio: float = clamp(hit_text_timer / hit_text_frames, 0.0, 1.0)
	var progress: float = 1.0 - timer_ratio
	var alpha: float = clamp(progress / 0.14, 0.0, 1.0) * clamp(timer_ratio / 0.32, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	var center: Vector2 = _as_vector2(_state.get("screen_hit_text_pos", _state.get("screen_hit_pos", Vector2.ZERO)), Vector2.ZERO)
	center.y -= (26.0 + progress * 36.0) * render_scale
	var text_width: float = 270.0 * render_scale
	var font_size: int = int(round((24.0 + sin(progress * PI) * 3.0) * render_scale))
	var origin := Vector2(center.x - text_width * 0.5, center.y)
	var text := "EMP 스트라이크"
	draw_string(font, origin + Vector2(3.0, 3.0) * render_scale, text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.02, 0.03, 0.06, alpha * 0.84))
	draw_string(font, origin + Vector2(-1.0, 0.0) * render_scale, text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.20, 0.96, 1.0, alpha * 0.55))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(1.0, 0.86, 0.48, alpha))


func _apply_quad(quad: ColorRect, center: Vector2, size: Vector2, active: bool, alpha: float) -> void:
	if quad == null:
		return
	quad.visible = active and alpha > 0.01 and size.x > 1.0 and size.y > 1.0
	if not quad.visible:
		return
	quad.position = center - size * 0.5
	quad.size = size


@warning_ignore("shadowed_variable_base_class")
func _make_quad(node_name: String, material: ShaderMaterial) -> ColorRect:
	var quad := ColorRect.new()
	quad.name = node_name
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quad.color = Color.WHITE
	quad.material = material
	quad.visible = false
	return quad


func _make_particles(node_name: String, amount: int, lifetime: float, process_material: ParticleProcessMaterial, texture: Texture2D) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.88
	particles.fixed_fps = PARTICLE_FIXED_FPS
	particles.local_coords = true
	particles.visibility_rect = Rect2(-520.0, -360.0, 1040.0, 720.0)
	particles.texture = texture
	particles.material = _additive_material
	particles.process_material = process_material
	particles.emitting = false
	return particles


func _hide_quad(quad: ColorRect) -> void:
	if quad != null:
		quad.visible = false


func _set_particles_emitting(particles: GPUParticles2D, emitting: bool) -> void:
	if particles != null:
		particles.emitting = emitting


func _draw_centered_texture(texture: Texture2D, center: Vector2, size_px: float, color: Color) -> void:
	if texture == null or size_px <= 0.0 or color.a <= 0.0:
		return
	var size := Vector2(size_px, size_px)
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, color)


func _draw_ring_texture(center: Vector2, radius: float, color: Color) -> void:
	var texture: Texture2D = ImpactShockwaveTextureCache.get_full_ring_texture()
	if texture == null or radius <= 0.0 or color.a <= 0.0:
		return
	var draw_radius: float = max(1.0, radius / ImpactShockwaveTextureCache.RING_RADIUS_RATIO)
	var size := Vector2(draw_radius * 2.0, draw_radius * 2.0)
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, color)


static func _build_prep_material() -> ShaderMaterial:
	if _cached_prep_material != null:
		return _cached_prep_material.duplicate(true) as ShaderMaterial
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float breath = 0.0;
uniform float progress = 0.0;
uniform float alpha = 1.0;

float ring(float r, float center, float width) {
	return smoothstep(width, 0.0, abs(r - center));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float outer = smoothstep(1.0, 0.12, r);
	float scan = 0.5 + 0.5 * sin((a * 10.0) + elapsed * 7.0);
	float swirl = 0.5 + 0.5 * cos(a * 4.0 - r * 8.0 + elapsed * 5.2);
	float ring_a = ring(r, 0.42 + progress * 0.20 + breath * 0.02, 0.055);
	float inner = smoothstep(0.48, 0.02, r) * (0.35 + pulse * 0.25);
	float sparks = pow(scan, 8.0) * smoothstep(0.92, 0.20, r) * 0.35;
	float body = (ring_a * 0.95 + inner + swirl * 0.18 + sparks) * outer * alpha;
	vec3 cool = vec3(0.20, 0.90, 1.0);
	vec3 hot = vec3(1.0, 0.62, 0.18);
	vec3 color = mix(cool, hot, clamp(inner + pulse * 0.25, 0.0, 1.0));
	COLOR = vec4(color, clamp(body, 0.0, 0.92));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	_cached_prep_material = material
	return _cached_prep_material.duplicate(true) as ShaderMaterial


static func _build_jet_material() -> ShaderMaterial:
	if _cached_jet_material != null:
		return _cached_jet_material.duplicate(true) as ShaderMaterial
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float height_ratio = 0.0;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = smoothstep(0.40, 0.0, abs(p.x));
	float edge = smoothstep(0.82, 0.18, abs(p.x));
	float vertical = smoothstep(1.0, -0.55, p.y) * smoothstep(-1.1, 0.22, p.y);
	float streak = 0.5 + 0.5 * sin((p.y * 16.0) - elapsed * 14.0 + sin(p.x * 8.0));
	float beam = (core * 0.70 + edge * pow(streak, 4.0) * 0.38) * vertical;
	beam *= 0.78 + pulse * 0.22 + height_ratio * 0.10;
	vec3 color = mix(vec3(1.0, 0.45, 0.12), vec3(0.36, 0.96, 1.0), clamp(core + p.y * 0.18, 0.0, 1.0));
	COLOR = vec4(color, clamp(beam * alpha, 0.0, 0.88));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	_cached_jet_material = material
	return _cached_jet_material.duplicate(true) as ShaderMaterial


static func _build_shockwave_material() -> ShaderMaterial:
	if _cached_shockwave_material != null:
		return _cached_shockwave_material.duplicate(true) as ShaderMaterial
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float pulse = 0.0;
uniform float progress = 0.0;
uniform float flash = 0.0;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float y_band = smoothstep(0.58, 0.0, abs(p.y));
	float core = smoothstep(0.20, 0.0, abs(p.y + 0.08));
	float edge = smoothstep(1.0, 0.0, abs(p.x));
	float ripple = 0.5 + 0.5 * sin((abs(p.x) * 22.0) - elapsed * 18.0 + progress * 6.0);
	float crackle = pow(ripple, 6.0) * y_band * edge;
	float a = (core * (0.46 + flash * 0.28) + crackle * 0.45 + y_band * 0.16) * edge;
	a *= alpha * (1.0 - progress * 0.18 + pulse * 0.08);
	vec3 cool = vec3(0.34, 0.95, 1.0);
	vec3 hot = vec3(1.0, 0.76, 0.26);
	vec3 color = mix(cool, hot, clamp(core + flash * 0.55, 0.0, 1.0));
	COLOR = vec4(color, clamp(a, 0.0, 0.92));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	_cached_shockwave_material = material
	return _cached_shockwave_material.duplicate(true) as ShaderMaterial


static func _build_charge_particle_material() -> ParticleProcessMaterial:
	if _cached_charge_particle_material != null:
		return _cached_charge_particle_material.duplicate(true) as ParticleProcessMaterial
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 36.0
	mat.initial_velocity_max = 96.0
	mat.radial_accel_min = -140.0
	mat.radial_accel_max = -40.0
	mat.tangential_accel_min = -180.0
	mat.tangential_accel_max = 180.0
	mat.damping_min = 6.0
	mat.damping_max = 22.0
	mat.scale_min = 0.020
	mat.scale_max = 0.070
	mat.color = Color(0.34, 0.96, 1.0, 0.78)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 70.0
	mat.emission_ring_inner_radius = 28.0
	mat.emission_ring_height = 0.0
	_cached_charge_particle_material = mat
	return _cached_charge_particle_material.duplicate(true) as ParticleProcessMaterial


static func _build_jet_particle_material() -> ParticleProcessMaterial:
	if _cached_jet_particle_material != null:
		return _cached_jet_particle_material.duplicate(true) as ParticleProcessMaterial
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 24.0
	mat.gravity = Vector3(0.0, 80.0, 0.0)
	mat.initial_velocity_min = 110.0
	mat.initial_velocity_max = 280.0
	mat.radial_accel_min = -20.0
	mat.radial_accel_max = 30.0
	mat.tangential_accel_min = -18.0
	mat.tangential_accel_max = 18.0
	mat.damping_min = 16.0
	mat.damping_max = 40.0
	mat.scale_min = 0.025
	mat.scale_max = 0.085
	mat.color = Color(1.0, 0.62, 0.18, 0.76)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 18.0
	_cached_jet_particle_material = mat
	return _cached_jet_particle_material.duplicate(true) as ParticleProcessMaterial


static func _build_shockwave_particle_material() -> ParticleProcessMaterial:
	if _cached_shockwave_particle_material != null:
		return _cached_shockwave_particle_material.duplicate(true) as ParticleProcessMaterial
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 260.0
	mat.radial_accel_min = 40.0
	mat.radial_accel_max = 180.0
	mat.tangential_accel_min = -24.0
	mat.tangential_accel_max = 24.0
	mat.damping_min = 14.0
	mat.damping_max = 58.0
	mat.scale_min = 0.018
	mat.scale_max = 0.060
	mat.color = Color(0.45, 0.96, 1.0, 0.64)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 74.0
	mat.emission_ring_inner_radius = 64.0
	mat.emission_ring_height = 0.0
	_cached_shockwave_particle_material = mat
	return _cached_shockwave_particle_material.duplicate(true) as ParticleProcessMaterial


static func _build_hit_particle_material() -> ParticleProcessMaterial:
	if _cached_hit_particle_material != null:
		return _cached_hit_particle_material.duplicate(true) as ParticleProcessMaterial
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, 50.0, 0.0)
	mat.initial_velocity_min = 120.0
	mat.initial_velocity_max = 360.0
	mat.radial_accel_min = -120.0
	mat.radial_accel_max = 80.0
	mat.tangential_accel_min = -160.0
	mat.tangential_accel_max = 160.0
	mat.damping_min = 28.0
	mat.damping_max = 88.0
	mat.scale_min = 0.018
	mat.scale_max = 0.064
	mat.color = Color(1.0, 0.82, 0.34, 0.84)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 22.0
	_cached_hit_particle_material = mat
	return _cached_hit_particle_material.duplicate(true) as ParticleProcessMaterial


static func _make_additive_material() -> CanvasItemMaterial:
	if _cached_additive_material != null:
		return _cached_additive_material.duplicate(true) as CanvasItemMaterial
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cached_additive_material = mat
	return _cached_additive_material.duplicate(true) as CanvasItemMaterial


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
