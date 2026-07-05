extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const HOST_NAME := "PonkAwakenAuraFxHost"
const BACKPLATE_TEXTURE_PATH := "res://assets/sprites/stage4/effects/stage4_ponk_awaken_aura_backplate_imagegen_v1.png"
const MOTE_TEXTURE_PATH := "res://assets/sprites/stage4/effects/stage4_ponk_awaken_aura_mote_imagegen_v1.png"
const ARC_TEXTURE_PATH := "res://assets/sprites/stage4/effects/stage4_ponk_awaken_aura_arc_imagegen_v1.png"
const WRITHE_SHADER_PATH := "res://shaders/mythic_writhe.gdshader"
const ARC_SHADER_PATH := "res://shaders/mythic_arc_flow.gdshader"
const Z_INDEX := 14
const ARC_COUNT := 3
const AURA_COLOR := Color(0.64, 0.36, 1.0, 1.0)
const AURA_CORE_COLOR := Color(0.94, 0.74, 1.0, 1.0)
const GOLD_COLOR := Color(0.95, 0.70, 0.26, 1.0)

static var _backplate_texture: Texture2D = null
static var _mote_texture: Texture2D = null
static var _arc_texture: Texture2D = null
static var _writhe_shader: Shader = null
static var _arc_shader: Shader = null
static var _prewarm_assets_done := false
static var _prewarm_step_index := 0
static var _pending_host: Node = null
static var _active_hosts: Array = []

var open_value := 0.0
var elapsed_sec := 0.0

var _state: Dictionary = {}
var _active := false
var _backplate_sprite: Sprite2D = null
var _arc_sprites: Array[Sprite2D] = []
var _arc_materials: Array[ShaderMaterial] = []
var _mote_particles: GPUParticles2D = null
var _backplate_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _open_tween: Tween = null


static func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


static func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0:
			_get_backplate_texture()
		1:
			_get_mote_texture()
		2:
			_get_arc_texture()
		3:
			_get_writhe_shader()
			_get_arc_shader()
		4:
			_build_mote_particle_material()
		_:
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 4:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


static func has_loaded_textures() -> bool:
	return _backplate_texture != null and _mote_texture != null and _arc_texture != null


static func has_loaded_pipeline() -> bool:
	return has_loaded_textures() and _writhe_shader != null and _arc_shader != null


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"awaken_aura_fx_shader_host_pipeline": _get_writhe_shader() != null and _get_arc_shader() != null,
		"awaken_aura_fx_shader_layers": 2,
		"awaken_aura_fx_gpu_particle_layers": 1,
		"awaken_aura_fx_texture_pieces_ready": has_loaded_textures(),
		"awaken_aura_backplate_png_slot": _is_png_texture_loaded(BACKPLATE_TEXTURE_PATH, _get_backplate_texture()),
		"awaken_aura_mote_png_slot": _is_png_texture_loaded(MOTE_TEXTURE_PATH, _get_mote_texture()),
		"awaken_aura_arc_png_slot": _is_png_texture_loaded(ARC_TEXTURE_PATH, _get_arc_texture()),
		"awaken_aura_backplate_texture_path": BACKPLATE_TEXTURE_PATH,
		"awaken_aura_mote_texture_path": MOTE_TEXTURE_PATH,
		"awaken_aura_arc_texture_path": ARC_TEXTURE_PATH,
		"awaken_aura_z_index": Z_INDEX,
	}


static func register_host_for_cleanup(host: Node) -> void:
	_pending_host = host
	_remember_host(host)


static func hide_all_existing_hosts() -> void:
	if _pending_host != null and is_instance_valid(_pending_host) and not _pending_host.is_queued_for_deletion():
		if _pending_host.has_method("set_active"):
			_pending_host.set_active(false)
	var next_hosts: Array = []
	for host_ref in _active_hosts:
		var host: Node = _resolve_host_ref(host_ref)
		if host == null or not is_instance_valid(host) or host.is_queued_for_deletion():
			continue
		if host.has_method("set_active"):
			host.set_active(false)
		next_hosts.append(host_ref)
	_active_hosts = next_hosts


static func _remember_host(host: Node) -> void:
	if host == null:
		return
	for host_ref in _active_hosts:
		if _resolve_host_ref(host_ref) == host:
			return
	_active_hosts.append(weakref(host))


static func _resolve_host_ref(host_ref: Variant) -> Node:
	if host_ref is WeakRef:
		var value: Variant = (host_ref as WeakRef).get_ref()
		return (value as Node) if value is Node else null
	return (host_ref as Node) if host_ref is Node else null


func prewarm_runtime_nodes() -> void:
	prewarm_assets()
	if _additive_material == null:
		_additive_material = _make_additive_material()
	_build_children()
	set_active(false)


func _ready() -> void:
	_remember_host(self)
	var should_remain_active := visible or _active
	z_as_relative = false
	z_index = Z_INDEX
	_additive_material = _make_additive_material()
	_build_children()
	set_active(should_remain_active and has_runtime_assets())
	if should_remain_active:
		_apply_state()


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _backplate_sprite == null:
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and can_handle_state(_state))
	if not visible:
		return
	elapsed_sec = float(_state.get("elapsed", float(Time.get_ticks_msec()) * 0.001))
	_apply_state()


func set_active(active: bool) -> void:
	if active and not _active:
		_start_open_tween()
	_active = active
	visible = active
	set_process(false)
	if _backplate_sprite != null:
		_backplate_sprite.visible = active
	for arc_sprite in _arc_sprites:
		arc_sprite.visible = active
	if _mote_particles != null:
		_mote_particles.emitting = active
	if not active:
		_stop_open_tween()
		open_value = 0.0
		if _backplate_sprite != null:
			_backplate_sprite.visible = false
		for arc_sprite in _arc_sprites:
			arc_sprite.visible = false
		if _mote_particles != null:
			_mote_particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	_stop_open_tween()
	if free_self:
		queue_free()


func has_runtime_assets() -> bool:
	return has_loaded_textures() and _get_writhe_shader() != null and _get_arc_shader() != null


func can_handle_state(next_state: Dictionary) -> bool:
	return has_runtime_assets() and float(next_state.get("intensity", 0.0)) > 0.001


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"visible": visible,
		"z_index": z_index,
		"z_as_relative": z_as_relative,
		"texture_pieces_ready": has_runtime_assets(),
		"backplate_png_slot": _is_png_texture_loaded(BACKPLATE_TEXTURE_PATH, _get_backplate_texture()),
		"mote_png_slot": _is_png_texture_loaded(MOTE_TEXTURE_PATH, _get_mote_texture()),
		"arc_png_slot": _is_png_texture_loaded(ARC_TEXTURE_PATH, _get_arc_texture()),
		"has_backplate_sprite": _backplate_sprite != null and is_instance_valid(_backplate_sprite),
		"arc_sprite_count": _arc_sprites.size(),
		"has_mote_particles": _mote_particles != null and is_instance_valid(_mote_particles),
		"backplate_blend_add": _is_additive_material(_backplate_sprite.material if _backplate_sprite != null else null),
		"arc_blend_add": _are_arc_materials_additive(),
		"particles_blend_add": _is_additive_material(_mote_particles.material if _mote_particles != null else null),
		"backplate_alpha": _backplate_sprite.modulate.a if _backplate_sprite != null else 0.0,
		"backplate_scale_x": _backplate_sprite.scale.x if _backplate_sprite != null else 0.0,
		"visible_arc_count": _get_visible_arc_count(),
		"mote_amount_ratio": _mote_particles.amount_ratio if _mote_particles != null else 0.0,
		"mote_emitting": _mote_particles.emitting if _mote_particles != null else false,
		"enraged": bool(_state.get("enraged", false)),
		"uses_viewport_layout": abs(scale.x - float(_state.get("render_scale", 1.0))) < 0.001,
	}


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _backplate_sprite == null:
		_backplate_sprite = Sprite2D.new()
		_backplate_sprite.name = "PonkAwakenAuraBackplate"
		_backplate_sprite.centered = true
		_backplate_sprite.z_index = -2
		_backplate_sprite.texture = _get_backplate_texture()
		_backplate_material = _build_backplate_material()
		_backplate_sprite.material = _backplate_material
		_backplate_sprite.visible = false
		add_child(_backplate_sprite)
	while _arc_sprites.size() < ARC_COUNT:
		var arc_sprite := Sprite2D.new()
		arc_sprite.name = "PonkAwakenAuraArc%d" % (_arc_sprites.size() + 1)
		arc_sprite.centered = true
		arc_sprite.z_index = -1 + _arc_sprites.size()
		arc_sprite.texture = _get_arc_texture()
		var arc_material := _build_arc_material()
		arc_sprite.material = arc_material
		arc_sprite.visible = false
		add_child(arc_sprite)
		_arc_sprites.append(arc_sprite)
		_arc_materials.append(arc_material)
	if _mote_particles == null:
		_mote_particles = GPUParticles2D.new()
		_mote_particles.name = "PonkAwakenAuraMoteParticles"
		_mote_particles.amount = 48
		_mote_particles.amount_ratio = 0.0
		_mote_particles.lifetime = 1.45
		_mote_particles.one_shot = false
		_mote_particles.explosiveness = 0.0
		_mote_particles.randomness = 0.30
		_mote_particles.fixed_fps = 60
		_mote_particles.local_coords = true
		_mote_particles.visibility_rect = Rect2(-260.0, -260.0, 520.0, 520.0)
		_mote_particles.texture = _get_mote_texture()
		_mote_particles.material = _additive_material
		_mote_particles.process_material = _build_mote_particle_material()
		_mote_particles.z_index = 3
		_mote_particles.emitting = false
		add_child(_mote_particles)


func _apply_state() -> void:
	if _state.is_empty():
		return
	var render_scale: float = maxf(0.001, float(_state.get("render_scale", 1.0)))
	position = _as_vector2(_state.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	scale = Vector2(render_scale, render_scale)
	var intensity: float = clampf(float(_state.get("intensity", 0.0)), 0.0, 1.0)
	var center: Vector2 = _as_vector2(_state.get("boss_center", Vector2(380.0, 78.0)), Vector2(380.0, 78.0))
	var enraged: bool = bool(_state.get("enraged", false))
	var active_arcs: int = 3 if intensity >= 0.90 else 2
	var speed_scale: float = 1.15 if enraged else 1.0
	_update_backplate(center, intensity, enraged, speed_scale)
	_update_arcs(center, intensity, active_arcs, enraged, speed_scale)
	_update_motes(center, intensity, enraged)


func _update_backplate(center: Vector2, intensity: float, enraged: bool, speed_scale: float) -> void:
	var texture: Texture2D = _get_backplate_texture()
	if _backplate_sprite == null or texture == null:
		return
	var alpha: float = _get_backplate_alpha(intensity)
	_backplate_sprite.visible = alpha > 0.01
	if not _backplate_sprite.visible:
		return
	var texture_size: Vector2 = texture.get_size()
	var draw_size: float = 250.0 * _get_backplate_scale(intensity) * (0.94 + open_value * 0.12 + 0.025 * sin(elapsed_sec * 1.4))
	_backplate_sprite.position = center
	_backplate_sprite.rotation = elapsed_sec * 0.10 * speed_scale
	_backplate_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_backplate_sprite.modulate = Color(1.0, 1.0, 1.0, alpha * (0.72 + open_value * 0.28))
	if _backplate_material != null:
		_apply_backplate_material_params(_backplate_material, intensity, enraged, speed_scale)


func _update_arcs(center: Vector2, intensity: float, active_arcs: int, enraged: bool, speed_scale: float) -> void:
	var texture: Texture2D = _get_arc_texture()
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	var speeds := [0.55, -0.38, 0.24]
	var scales := [0.85, 1.0, 1.15]
	var base_size: float = 235.0 * (0.94 + intensity * 0.18 + open_value * 0.08)
	for idx in range(_arc_sprites.size()):
		var arc_sprite: Sprite2D = _arc_sprites[idx]
		var arc_active: bool = idx < active_arcs and intensity > 0.04
		arc_sprite.visible = arc_active
		if not arc_active:
			continue
		arc_sprite.position = center
		arc_sprite.rotation = elapsed_sec * float(speeds[idx]) * speed_scale + TAU * float(idx) / float(ARC_COUNT)
		var draw_size: float = base_size * float(scales[idx])
		arc_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
		arc_sprite.modulate = Color(1.0, 1.0, 1.0, _get_arc_alpha(intensity, idx))
		if idx < _arc_materials.size() and _arc_materials[idx] != null:
			_arc_materials[idx].set_shader_parameter("elapsed", elapsed_sec * speed_scale + float(idx) * 0.17)
			_arc_materials[idx].set_shader_parameter("intensity", clampf(0.70 + intensity * 0.55, 0.0, 1.45))
			var tint := AURA_CORE_COLOR.lerp(GOLD_COLOR, 0.36 + float(idx) * 0.16)
			if enraged:
				tint = tint.lerp(Color(1.0, 0.22, 0.30, 1.0), 0.35)
			_arc_materials[idx].set_shader_parameter("tint", tint)
			_arc_materials[idx].set_shader_parameter("scroll_speed", (1.5 + float(idx) * 0.2) * speed_scale)


func _update_motes(center: Vector2, intensity: float, enraged: bool) -> void:
	if _mote_particles == null:
		return
	_mote_particles.position = center
	_mote_particles.emitting = intensity > 0.04
	_mote_particles.amount_ratio = clampf(_get_mote_rate_per_second(intensity) / 18.0, 0.0, 1.0)
	var mat := _mote_particles.process_material as ParticleProcessMaterial
	if mat != null:
		mat.color = AURA_CORE_COLOR.lerp(GOLD_COLOR, 0.34)
		if enraged:
			mat.color = mat.color.lerp(Color(1.0, 0.24, 0.30, 1.0), 0.35)
		mat.color.a = clampf(0.20 + intensity * 0.55, 0.0, 0.85)
		mat.emission_ring_radius = 70.0 + intensity * 18.0
		mat.emission_ring_inner_radius = 54.0 + intensity * 10.0
		mat.initial_velocity_min = 10.0 + intensity * 8.0
		mat.initial_velocity_max = 30.0 + intensity * 24.0


func _get_backplate_alpha(intensity: float) -> float:
	if intensity >= 0.90:
		return 0.80
	if intensity >= 0.50:
		return lerpf(0.45, 0.80, clampf((intensity - 0.55) / 0.45, 0.0, 1.0))
	return lerpf(0.0, 0.35, clampf(intensity / 0.42, 0.0, 1.0))


func _get_backplate_scale(intensity: float) -> float:
	if intensity >= 0.90:
		return 1.12
	if intensity >= 0.50:
		return lerpf(1.0, 1.12, clampf((intensity - 0.55) / 0.45, 0.0, 1.0))
	return lerpf(0.70, 0.92, clampf(intensity / 0.42, 0.0, 1.0))


func _get_arc_alpha(intensity: float, idx: int) -> float:
	var base: float = 0.26 + intensity * 0.38
	if idx == 2 and intensity < 0.90:
		return 0.0
	return clampf(base * (0.82 + 0.10 * float(idx)), 0.0, 0.78)


func _get_mote_rate_per_second(intensity: float) -> float:
	if intensity >= 0.90:
		return 18.0
	if intensity >= 0.50:
		return 8.0 + clampf((intensity - 0.55) / 0.45, 0.0, 1.0) * 10.0
	return 6.0 * clampf(intensity / 0.42, 0.0, 1.0)


func _apply_backplate_material_params(material: ShaderMaterial, intensity: float, enraged: bool, speed_scale: float) -> void:
	var hot := AURA_CORE_COLOR
	if enraged:
		hot = hot.lerp(Color(1.0, 0.22, 0.30, 1.0), 0.35)
	material.set_shader_parameter("elapsed", elapsed_sec * speed_scale)
	material.set_shader_parameter("intensity", clampf(0.72 + intensity * 0.46 + open_value * 0.10, 0.0, 1.35))
	material.set_shader_parameter("distort_strength", 0.006)
	material.set_shader_parameter("flow_speed", 0.7 * speed_scale)
	material.set_shader_parameter("pulse_speed", 0.85 * speed_scale)
	material.set_shader_parameter("breath_amp", 0.12)
	material.set_shader_parameter("core_dim_strength", 0.55)
	material.set_shader_parameter("core_dim_radius", 0.30)
	material.set_shader_parameter("hot_color", hot)
	material.set_shader_parameter("cool_color", AURA_COLOR)
	material.set_shader_parameter("ember_color", GOLD_COLOR)


func _start_open_tween() -> void:
	_stop_open_tween()
	open_value = 0.0
	_open_tween = create_tween()
	_open_tween.set_trans(Tween.TRANS_BACK)
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "open_value", 1.0, 0.50)


func _stop_open_tween() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null


func _build_backplate_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_writhe_shader()
	_apply_backplate_material_params(mat, 0.55, false, 1.0)
	return mat


func _build_arc_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_arc_shader()
	mat.set_shader_parameter("elapsed", 0.0)
	mat.set_shader_parameter("intensity", 1.0)
	mat.set_shader_parameter("scroll_speed", 1.5)
	mat.set_shader_parameter("fade_softness", 0.18)
	mat.set_shader_parameter("pulse_amp", 0.15)
	mat.set_shader_parameter("tint", AURA_CORE_COLOR.lerp(GOLD_COLOR, 0.45))
	return mat


static func _build_mote_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 24.0
	mat.gravity = Vector3(0.0, -18.0, 0.0)
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 42.0
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0
	mat.scale_min = 0.018
	mat.scale_max = 0.050
	mat.radial_accel_min = 4.0
	mat.radial_accel_max = 20.0
	mat.tangential_accel_min = -18.0
	mat.tangential_accel_max = 18.0
	mat.color = Color(1.0, 0.86, 0.44, 0.65)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 70.0
	mat.emission_ring_inner_radius = 54.0
	mat.emission_ring_height = 0.0
	return mat


static func _get_backplate_texture() -> Texture2D:
	if _backplate_texture == null:
		_backplate_texture = ProjectResourceLoader.load_texture(BACKPLATE_TEXTURE_PATH)
	return _backplate_texture


static func _get_mote_texture() -> Texture2D:
	if _mote_texture == null:
		_mote_texture = ProjectResourceLoader.load_texture(MOTE_TEXTURE_PATH)
	return _mote_texture


static func _get_arc_texture() -> Texture2D:
	if _arc_texture == null:
		_arc_texture = ProjectResourceLoader.load_texture(ARC_TEXTURE_PATH)
	return _arc_texture


static func _get_writhe_shader() -> Shader:
	if _writhe_shader == null:
		_writhe_shader = load(WRITHE_SHADER_PATH)
	return _writhe_shader


static func _get_arc_shader() -> Shader:
	if _arc_shader == null:
		_arc_shader = load(ARC_SHADER_PATH)
	return _arc_shader


static func _is_png_texture_loaded(path: String, texture: Texture2D) -> bool:
	if texture == null:
		return false
	var loaded: Texture2D = ProjectResourceLoader.load_texture(path)
	return loaded != null


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _is_additive_material(material: Variant) -> bool:
	if material is CanvasItemMaterial:
		return (material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		return shader != null and shader.code.find("blend_add") >= 0
	return false


func _are_arc_materials_additive() -> bool:
	for arc_sprite in _arc_sprites:
		if not _is_additive_material(arc_sprite.material):
			return false
	return not _arc_sprites.is_empty()


func _get_visible_arc_count() -> int:
	var count := 0
	for arc_sprite in _arc_sprites:
		if arc_sprite.visible:
			count += 1
	return count


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
