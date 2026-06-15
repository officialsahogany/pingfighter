extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const WritheEmberMaterial := preload("res://scripts/effects/writhe_ember_material.gd")

const MAX_ACTOR_NODES := 2
const BEAM_TEXTURE_SIZE := Vector2i(128, 384)
const BEAM_BASE_HEIGHT := 230.0
const BEAM_BASE_WIDTH := 70.0

static var _beam_texture: ImageTexture = null

var pulse_value := 0.0
var elapsed_sec := 0.0
var actor_states: Array[Dictionary] = []

var _outer_beams: Array[Sprite2D] = []
var _inner_beams: Array[Sprite2D] = []
var _ground_rings: Array[Sprite2D] = []
var _core_glows: Array[Sprite2D] = []
var _mote_particles: Array[GPUParticles2D] = []
var _streak_particles: Array[GPUParticles2D] = []
var _outer_materials: Array[ShaderMaterial] = []
var _inner_materials: Array[ShaderMaterial] = []
var _additive_material: CanvasItemMaterial = null
var _pulse_tween: Tween = null


static func prewarm_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	WritheEmberMaterial.prewarm()
	_get_beam_texture()


func _ready() -> void:
	z_as_relative = false
	z_index = 18
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_additive_material = _make_additive_material()
	_start_tween()
	set_process(false)
	set_active(false)


func sync_state(next_actor_states: Array, active: bool) -> void:
	actor_states = _coerce_actor_states(next_actor_states)
	_ensure_actor_count(actor_states.size())
	set_active(active and not actor_states.is_empty())
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_actor_slots()


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if active:
		return
	for sprite in _outer_beams:
		sprite.visible = false
	for sprite in _inner_beams:
		sprite.visible = false
	for sprite in _ground_rings:
		sprite.visible = false
	for sprite in _core_glows:
		sprite.visible = false
	for particles in _mote_particles:
		particles.emitting = false
	for particles in _streak_particles:
		particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if free_self:
		queue_free()


func get_active_actor_count() -> int:
	if not visible:
		return 0
	return actor_states.size()


func _ensure_actor_count(count: int) -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	var target_count := clampi(count, 0, MAX_ACTOR_NODES)
	while _outer_beams.size() < target_count:
		var outer := _make_beam_sprite("electrocution_field")
		add_child(outer)
		_outer_beams.append(outer)
		_outer_materials.append(outer.material as ShaderMaterial)

		var inner := _make_beam_sprite("electrocution_field_peak")
		inner.z_index = 3
		add_child(inner)
		_inner_beams.append(inner)
		_inner_materials.append(inner.material as ShaderMaterial)

		var ring := Sprite2D.new()
		ring.texture = ImpactShockwaveTextureCache.get_full_ring_texture()
		ring.material = _additive_material
		ring.centered = true
		ring.visible = false
		ring.z_index = 1
		add_child(ring)
		_ground_rings.append(ring)

		var core := Sprite2D.new()
		core.texture = ImpactFlareTextureCache.get_glow_texture()
		core.material = _additive_material
		core.centered = true
		core.visible = false
		core.z_index = 4
		add_child(core)
		_core_glows.append(core)

		var motes := GPUParticles2D.new()
		motes.amount = 42
		motes.lifetime = 0.72
		motes.one_shot = false
		motes.explosiveness = 0.0
		motes.randomness = 0.82
		motes.fixed_fps = 60
		motes.local_coords = true
		motes.visibility_rect = Rect2(-180.0, -310.0, 360.0, 340.0)
		motes.texture = ImpactFlareTextureCache.get_sparkle_texture()
		motes.material = _additive_material
		motes.process_material = _build_mote_particle_material()
		motes.emitting = false
		motes.z_index = 5
		add_child(motes)
		_mote_particles.append(motes)

		var streaks := GPUParticles2D.new()
		streaks.amount = 30
		streaks.lifetime = 0.58
		streaks.one_shot = false
		streaks.explosiveness = 0.0
		streaks.randomness = 0.74
		streaks.fixed_fps = 60
		streaks.local_coords = true
		streaks.visibility_rect = Rect2(-150.0, -340.0, 300.0, 380.0)
		streaks.texture = _get_beam_texture()
		streaks.material = _additive_material
		streaks.process_material = _build_streak_particle_material()
		streaks.emitting = false
		streaks.z_index = 2
		add_child(streaks)
		_streak_particles.append(streaks)


func _make_beam_sprite(preset_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _get_beam_texture()
	sprite.centered = true
	sprite.visible = false
	sprite.z_index = 2
	sprite.material = WritheEmberMaterial.build_material(preset_name)
	return sprite


func _start_tween() -> void:
	if not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "pulse_value", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "pulse_value", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _apply_actor_slots() -> void:
	for slot in range(_outer_beams.size()):
		var slot_active := slot < actor_states.size()
		_outer_beams[slot].visible = slot_active
		_inner_beams[slot].visible = slot_active
		_ground_rings[slot].visible = slot_active
		_core_glows[slot].visible = slot_active
		_mote_particles[slot].emitting = slot_active
		_streak_particles[slot].emitting = slot_active
		if slot_active:
			_apply_actor_slot(slot, actor_states[slot])


func _apply_actor_slot(slot: int, state: Dictionary) -> void:
	var foot_pos: Vector2 = _as_vector2(state.get("screen_pos", Vector2.ZERO), Vector2.ZERO)
	var progress := clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	var strength := maxf(0.1, float(state.get("strength", 1.0)))
	var eased := _smooth_unit(progress)
	var bell := clampf(1.0 - absf(eased * 2.0 - 1.0), 0.0, 1.0)
	var edge_gate := _smooth_unit(clampf(progress / 0.16, 0.0, 1.0)) * _smooth_unit(clampf((1.0 - progress) / 0.16, 0.0, 1.0))
	var alpha := clampf((0.24 + bell * 0.86 + pulse_value * 0.12) * edge_gate * strength, 0.0, 1.0)
	var height := BEAM_BASE_HEIGHT * (0.72 + bell * 0.46) * strength
	var width := BEAM_BASE_WIDTH * (0.76 + bell * 0.34) * strength
	var beam_center := foot_pos + Vector2(0.0, -height * 0.50 + 8.0 * strength)
	var hot := Color(0.88, 1.0, 1.0, 1.0)
	var cyan := Color(0.0, 0.88, 1.0, 1.0)
	var magenta := Color(1.0, 0.22, 0.92, 1.0)

	_apply_beam_sprite(_outer_beams[slot], _outer_materials[slot], beam_center, width * 1.32, height * 1.03, Color(cyan.r, cyan.g, cyan.b, alpha * 0.42), 0.92 + bell * 0.42)
	_apply_beam_sprite(_inner_beams[slot], _inner_materials[slot], beam_center + Vector2(0.0, -height * 0.03), width * 0.46, height * 1.12, Color(hot.r, hot.g, hot.b, alpha * 0.82), 1.18 + bell * 0.62)

	var ring_radius := Vector2(width * (0.90 + bell * 0.42), maxf(9.0, width * 0.18)) * (0.86 + progress * 0.28)
	_apply_texture_sprite(_ground_rings[slot], foot_pos + Vector2(0.0, 5.0 * strength), ring_radius * 2.0, Color(cyan.r, cyan.g, cyan.b, alpha * 0.48))
	_apply_texture_sprite(_core_glows[slot], foot_pos + Vector2(0.0, -height * (0.18 + bell * 0.18)), Vector2(width * 2.1, height * 0.78), Color(magenta.r, magenta.g, magenta.b, alpha * 0.22))

	_apply_particle_slot(_mote_particles[slot], foot_pos + Vector2(0.0, -height * 0.42), Vector2(width / BEAM_BASE_WIDTH, height / BEAM_BASE_HEIGHT), Color(cyan.r, cyan.g, cyan.b, alpha * 0.82))
	_apply_particle_slot(_streak_particles[slot], foot_pos + Vector2(0.0, -height * 0.08), Vector2(width / BEAM_BASE_WIDTH * 0.74, height / BEAM_BASE_HEIGHT * 1.08), Color(hot.r, hot.g, hot.b, alpha * 0.58))


func _apply_beam_sprite(
	sprite: Sprite2D,
	material: ShaderMaterial,
	center: Vector2,
	width: float,
	height: float,
	modulate_color: Color,
	intensity: float
) -> void:
	sprite.position = center
	sprite.scale = Vector2(width / float(BEAM_TEXTURE_SIZE.x), height / float(BEAM_TEXTURE_SIZE.y))
	sprite.modulate = modulate_color
	if material != null:
		material.set_shader_parameter("elapsed", elapsed_sec)
		material.set_shader_parameter("intensity", intensity)


func _apply_texture_sprite(sprite: Sprite2D, center: Vector2, size_px: Vector2, modulate_color: Color) -> void:
	var texture_size := Vector2.ONE
	if sprite.texture != null:
		texture_size = sprite.texture.get_size()
	sprite.position = center
	sprite.scale = Vector2(size_px.x / maxf(1.0, texture_size.x), size_px.y / maxf(1.0, texture_size.y))
	sprite.modulate = modulate_color


func _apply_particle_slot(particles: GPUParticles2D, center: Vector2, next_scale: Vector2, color: Color) -> void:
	particles.position = center
	particles.scale = next_scale
	particles.emitting = color.a > 0.02
	var mat: ParticleProcessMaterial = particles.process_material
	if mat != null:
		mat.color = color


static func _build_mote_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 24.0
	mat.gravity = Vector3(0.0, -210.0, 0.0)
	mat.initial_velocity_min = 16.0
	mat.initial_velocity_max = 76.0
	mat.damping_min = 8.0
	mat.damping_max = 28.0
	mat.scale_min = 0.030
	mat.scale_max = 0.075
	mat.color = Color(0.20, 0.95, 1.0, 0.72)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(54.0, 34.0, 0.0)
	return mat


static func _build_streak_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 10.0
	mat.gravity = Vector3(0.0, -420.0, 0.0)
	mat.initial_velocity_min = 70.0
	mat.initial_velocity_max = 210.0
	mat.damping_min = 0.0
	mat.damping_max = 18.0
	mat.scale_min = 0.18
	mat.scale_max = 0.34
	mat.color = Color(0.86, 1.0, 1.0, 0.62)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(34.0, 8.0, 0.0)
	return mat


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _coerce_actor_states(next_actor_states: Array) -> Array[Dictionary]:
	var typed_states: Array[Dictionary] = []
	for value in next_actor_states:
		if value is Dictionary:
			typed_states.append((value as Dictionary).duplicate(true))
		if typed_states.size() >= MAX_ACTOR_NODES:
			break
	return typed_states


static func _get_beam_texture() -> ImageTexture:
	if _beam_texture != null:
		return _beam_texture
	_beam_texture = _build_beam_texture()
	return _beam_texture


static func _build_beam_texture() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(BEAM_TEXTURE_SIZE.x * BEAM_TEXTURE_SIZE.y * 4)
	var center_x := (float(BEAM_TEXTURE_SIZE.x) - 1.0) * 0.5
	var offset := 0
	for y in range(BEAM_TEXTURE_SIZE.y):
		var v := float(y) / maxf(1.0, float(BEAM_TEXTURE_SIZE.y - 1))
		var vertical := pow(maxf(0.0, sin(v * PI)), 0.46)
		var tip_fade := _smooth_unit_static(clampf(v / 0.08, 0.0, 1.0)) * _smooth_unit_static(clampf((1.0 - v) / 0.12, 0.0, 1.0))
		for x in range(BEAM_TEXTURE_SIZE.x):
			var nx := absf((float(x) - center_x) / center_x)
			var core := pow(maxf(0.0, 1.0 - nx * 1.26), 2.2)
			var halo := pow(maxf(0.0, 1.0 - nx), 1.15) * 0.34
			var lane := pow(maxf(0.0, 1.0 - absf(nx - 0.42) * 7.5), 1.8) * 0.28
			var alpha := clampf((core + halo + lane) * vertical * tip_fade, 0.0, 1.0)
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(alpha))
			offset += 4
	var image := Image.create_from_data(BEAM_TEXTURE_SIZE.x, BEAM_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)


static func _write_pixel(data: PackedByteArray, offset: int, r: int, g: int, b: int, a: int) -> void:
	data[offset] = r
	data[offset + 1] = g
	data[offset + 2] = b
	data[offset + 3] = a


static func _alpha_to_byte(alpha: float) -> int:
	return int(clamp(round(alpha * 255.0), 0.0, 255.0))


static func _smooth_unit_static(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _smooth_unit(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
