@tool
extends Control

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CharacterSelectVfxMaterial := preload("res://scripts/ui/character_select_vfx_material.gd")

const ASSET_ROOT := "res://assets/ui/character_select_vfx/"
const DEEP_BACKPLATE_PATH := ASSET_ROOT + "character_select_chamber_backplate.png"
const PARTICLE_MOTE_PATH := ASSET_ROOT + "character_select_particle_mote.png"
const FLOOR_RING_PATH := ASSET_ROOT + "character_select_floor_ring.png"
const LIGHT_SLIT_PATH := ASSET_ROOT + "character_select_light_slit.png"

const MANDALA_PATHS := {
	"ufo_player": ASSET_ROOT + "character_select_mandala_ufo_player.png",
	"soldier": ASSET_ROOT + "character_select_mandala_soldier.png",
	"viper": ASSET_ROOT + "character_select_mandala_viper.png",
	"blacksmith": ASSET_ROOT + "character_select_mandala_blacksmith.png",
	"optimus": ASSET_ROOT + "character_select_mandala_optimus.png",
}

const PARTICLE_FIXED_FPS := 30
const CONFIRM_DECAY_SECONDS := 0.42

var _character_id: String = ""
var _active: bool = false
var _elapsed: float = 0.0
var _hover_target: float = 0.0
var _hover_amount: float = 0.0
var _confirm_amount: float = 0.0
var _look_offset: Vector2 = Vector2.ZERO

var _background_outer_rect: ColorRect = null
var _background_inner_rect: ColorRect = null
var _confirm_flash_rect: ColorRect = null
var _backplate_rect: TextureRect = null
var _mandala_rect: TextureRect = null
var _floor_ring_rect: TextureRect = null
var _light_slit_rects: Array[TextureRect] = []
var _mote_particles: GPUParticles2D = null
var _mote_process_material: ParticleProcessMaterial = null

var _additive_canvas_material: CanvasItemMaterial = null
var _floor_ring_material: ShaderMaterial = null
var _light_slit_materials: Array[ShaderMaterial] = []


static func get_vfx_texture_paths() -> Array[String]:
	return [
		DEEP_BACKPLATE_PATH,
		PARTICLE_MOTE_PATH,
		FLOOR_RING_PATH,
		LIGHT_SLIT_PATH,
		MANDALA_PATHS["ufo_player"],
		MANDALA_PATHS["soldier"],
		MANDALA_PATHS["viper"],
		MANDALA_PATHS["blacksmith"],
		MANDALA_PATHS["optimus"],
	]


static func get_mandala_texture_path(character_id: String) -> String:
	return str(MANDALA_PATHS.get(character_id, MANDALA_PATHS["ufo_player"]))


static func prewarm_materials() -> void:
	CharacterSelectVfxMaterial.prewarm()


static func build_pipeline_status() -> Dictionary:
	prewarm_materials()
	return {
		"texture_paths": get_vfx_texture_paths(),
		"material_family_ready": true,
		"character_presets": MANDALA_PATHS.keys(),
	}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	_build_layers()
	var resized_callback := Callable(self, "_on_resized")
	if not is_connected("resized", resized_callback):
		connect("resized", resized_callback)
	set_process(false)


func _exit_tree() -> void:
	var resized_callback := Callable(self, "_on_resized")
	if is_connected("resized", resized_callback):
		disconnect("resized", resized_callback)
	clear_runtime_state()
	_release_layer_resources()


func set_character(character_data: Dictionary) -> void:
	var next_id := str(character_data.get("id", character_data.get("character_id", "")))
	if next_id == "":
		set_active(false)
		return
	_build_layers()
	var changed := next_id != _character_id
	_character_id = next_id
	_apply_particle_palette()
	if changed and _mote_particles != null:
		_mote_particles.emitting = false
		_mote_particles.restart()
	_apply_texture_assets()
	set_active(true)
	_layout_layers()
	_update_runtime_uniforms()


func set_hover_amount(value: float) -> void:
	_hover_target = clampf(value, 0.0, 1.0)
	if _active:
		set_process(true)


func set_look_offset(value: Vector2) -> void:
	_look_offset = value
	_update_runtime_uniforms()


func set_interaction_state(hover_amount: float, click_flash: float, active: bool) -> void:
	set_hover_amount(hover_amount)
	if click_flash > 0.01:
		_confirm_amount = maxf(_confirm_amount, clampf(click_flash, 0.0, 1.0) * 0.34)
	set_active(active or _character_id != "")


func play_confirm(config: Dictionary = {}) -> void:
	_build_layers()
	_confirm_amount = maxf(_confirm_amount, float(config.get("amount", 1.0)))
	_hover_target = maxf(_hover_target, 0.65)
	set_active(true)
	if _mote_particles != null:
		_mote_particles.restart()
		_mote_particles.emitting = true
	_update_runtime_uniforms()


func set_active(value: bool) -> void:
	_active = value
	visible = value
	if not value:
		_hover_target = 0.0
		_hover_amount = 0.0
		_confirm_amount = 0.0
		if _mote_particles != null:
			_mote_particles.emitting = false
		set_process(false)
		_update_runtime_uniforms()
		return
	if _character_id != "":
		_build_layers()
		if _mote_particles != null:
			_mote_particles.emitting = true
		set_process(true)


func clear_runtime_state() -> void:
	_active = false
	_character_id = ""
	_hover_target = 0.0
	_hover_amount = 0.0
	_confirm_amount = 0.0
	_look_offset = Vector2.ZERO
	visible = false
	if _mote_particles != null:
		_mote_particles.emitting = false
	set_process(false)
	_update_runtime_uniforms()


func _release_layer_resources() -> void:
	if _mote_particles != null:
		_mote_particles.emitting = false
		_mote_particles.texture = null
		_mote_particles.material = null
		_mote_particles.process_material = null
	if _mote_process_material != null:
		_mote_process_material.color_ramp = null
		_mote_process_material.scale_curve = null
	if _confirm_flash_rect != null:
		_confirm_flash_rect.material = null
	if _backplate_rect != null:
		_backplate_rect.texture = null
		_backplate_rect.material = null
	if _mandala_rect != null:
		_mandala_rect.texture = null
		_mandala_rect.material = null
	if _floor_ring_rect != null:
		_floor_ring_rect.texture = null
		_floor_ring_rect.material = null
	for rect in _light_slit_rects:
		if rect == null:
			continue
		rect.texture = null
		rect.material = null
	_mote_process_material = null
	_additive_canvas_material = null
	_floor_ring_material = null
	_light_slit_materials.clear()
	_free_layer_node(_background_outer_rect)
	_free_layer_node(_background_inner_rect)
	_free_layer_node(_mote_particles)
	_free_layer_node(_confirm_flash_rect)
	_free_layer_node(_backplate_rect)
	_free_layer_node(_mandala_rect)
	_free_layer_node(_floor_ring_rect)
	for rect in _light_slit_rects:
		_free_layer_node(rect)
	_mote_particles = null
	_confirm_flash_rect = null
	_background_outer_rect = null
	_background_inner_rect = null
	_backplate_rect = null
	_mandala_rect = null
	_floor_ring_rect = null
	_light_slit_rects.clear()
	CharacterSelectVfxMaterial.clear_caches()


func _free_layer_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() == self:
		remove_child(node)
	node.free()


func get_runtime_status() -> Dictionary:
	return {
		"active": _active,
		"visible": visible,
		"character_id": _character_id,
		"clip_contents": clip_contents,
		"process_enabled": is_processing(),
		"hover_amount": _hover_amount,
		"confirm_amount": _confirm_amount,
		"look_offset": _look_offset,
		"gpu_particle_layers": 1 if _mote_particles != null else 0,
		"particles_emitting": _mote_particles != null and _mote_particles.emitting,
		"texture_layers": _get_texture_layer_count(),
	}


func get_layer_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node in [_floor_ring_rect, _confirm_flash_rect]:
		var control := node as Control
		if control != null and control.visible:
			rects.append(Rect2(control.position, control.size))
	for rect in _light_slit_rects:
		if rect != null and rect.visible:
			rects.append(Rect2(rect.position, rect.size))
	return rects


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += maxf(delta, 0.0)
	var hover_step: float = clampf(delta * 8.0, 0.0, 1.0)
	_hover_amount = lerpf(_hover_amount, _hover_target, hover_step)
	if _confirm_amount > 0.0:
		_confirm_amount = maxf(0.0, _confirm_amount - delta / CONFIRM_DECAY_SECONDS)
	_update_runtime_uniforms()


func _on_resized() -> void:
	_layout_layers()
	_update_runtime_uniforms()


func _build_layers() -> void:
	if _mote_particles != null and is_instance_valid(_mote_particles):
		return
	CharacterSelectVfxMaterial.prewarm()
	_additive_canvas_material = CharacterSelectVfxMaterial.build_additive_canvas_material()

	_background_outer_rect = ColorRect.new()
	_background_outer_rect.name = "BackdropBase"
	_background_outer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_outer_rect.color = Color(0.018, 0.020, 0.034, 0.98)
	_background_outer_rect.z_index = -6
	add_child(_background_outer_rect)

	_background_inner_rect = ColorRect.new()
	_background_inner_rect.name = "BackdropInner"
	_background_inner_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_inner_rect.color = Color(0.026, 0.032, 0.052, 0.92)
	_background_inner_rect.z_index = -5
	add_child(_background_inner_rect)

	_backplate_rect = _build_texture_layer("DeepBackplate", DEEP_BACKPLATE_PATH, null, -4)
	_mandala_rect = _build_texture_layer("CharacterMandala", get_mandala_texture_path(_character_id), null, -3)

	for side_index in range(2):
		var slit_material := CharacterSelectVfxMaterial.build_light_slit_flow_material()
		var slit_rect := _build_texture_layer(
			"LightSlitFlow%s" % str(side_index + 1),
			LIGHT_SLIT_PATH,
			slit_material,
			0
		)
		_light_slit_rects.append(slit_rect)
		_light_slit_materials.append(slit_material)

	_floor_ring_material = CharacterSelectVfxMaterial.build_floor_ring_flow_material()
	_floor_ring_rect = _build_texture_layer("FloorRingFlow", FLOOR_RING_PATH, _floor_ring_material, 1)

	_confirm_flash_rect = ColorRect.new()
	_confirm_flash_rect.name = "ConfirmFlashTint"
	_confirm_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_flash_rect.color = Color.WHITE
	_confirm_flash_rect.material = _additive_canvas_material
	_confirm_flash_rect.visible = false
	_confirm_flash_rect.z_index = 4
	add_child(_confirm_flash_rect)

	_mote_process_material = _build_mote_process_material()
	_mote_particles = GPUParticles2D.new()
	_mote_particles.name = "DataMoteParticles"
	_mote_particles.amount = 78
	_mote_particles.amount_ratio = 0.48
	_mote_particles.lifetime = 4.6
	_mote_particles.preprocess = 1.0
	_mote_particles.one_shot = false
	_mote_particles.explosiveness = 0.0
	_mote_particles.randomness = 0.74
	_mote_particles.fixed_fps = PARTICLE_FIXED_FPS
	_mote_particles.local_coords = true
	_mote_particles.texture = _load_vfx_texture(PARTICLE_MOTE_PATH)
	_mote_particles.material = _additive_canvas_material
	_mote_particles.process_material = _mote_process_material
	_mote_particles.emitting = false
	_mote_particles.z_index = 5
	add_child(_mote_particles)

	_apply_particle_palette()
	_apply_texture_assets()
	_layout_layers()
	_update_runtime_uniforms()


func _apply_particle_palette() -> void:
	if _mote_process_material == null:
		return
	var palette := CharacterSelectVfxMaterial.get_palette(_character_id)
	var primary: Color = palette["primary"]
	var accent: Color = palette["accent"]
	_mote_process_material.color = Color(primary.r, primary.g, primary.b, 0.86)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(accent.r, accent.g, accent.b, 0.0))
	gradient.set_color(1, Color(primary.r, primary.g, primary.b, 0.0))
	gradient.add_point(0.18, Color(accent.r, accent.g, accent.b, 0.86))
	gradient.add_point(0.62, Color(primary.r, primary.g, primary.b, 0.58))
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	_mote_process_material.color_ramp = gradient_texture
	if _confirm_flash_rect != null:
		_confirm_flash_rect.color = Color(primary.r, primary.g, primary.b, 0.0)


func _apply_texture_assets() -> void:
	if _mandala_rect != null:
		_mandala_rect.texture = _load_vfx_texture(get_mandala_texture_path(_character_id))


func _layout_layers() -> void:
	var view_size := size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var floor_y: float = view_size.y * 0.80
	if _background_outer_rect != null:
		_background_outer_rect.position = Vector2.ZERO
		_background_outer_rect.size = view_size
	if _background_inner_rect != null:
		_background_inner_rect.position = Vector2(8.0, 8.0)
		_background_inner_rect.size = view_size - Vector2(16.0, 16.0)
	if _backplate_rect != null:
		_backplate_rect.size = view_size * 1.036
	var mandala_side: float = min(view_size.x * 0.78, view_size.y * 0.62)
	if _mandala_rect != null:
		_mandala_rect.size = Vector2(mandala_side, mandala_side)
		_mandala_rect.pivot_offset = _mandala_rect.size * 0.5
	var slit_size := Vector2(view_size.x * 0.22, view_size.y * 0.70)
	for side_index in range(_light_slit_rects.size()):
		var slit_rect := _light_slit_rects[side_index]
		if slit_rect == null:
			continue
		var base_x: float = view_size.x * (0.08 if side_index == 0 else 0.70)
		slit_rect.position = Vector2(base_x, view_size.y * 0.075)
		slit_rect.size = slit_size
		slit_rect.pivot_offset = slit_size * 0.5
	var ring_size := Vector2(view_size.x * 0.78, view_size.y * 0.14)
	if _floor_ring_rect != null:
		_floor_ring_rect.position = Vector2((view_size.x - ring_size.x) * 0.5, floor_y - ring_size.y * 0.45)
		_floor_ring_rect.size = ring_size
		_floor_ring_rect.pivot_offset = ring_size * 0.5
	if _confirm_flash_rect != null:
		_confirm_flash_rect.position = Vector2.ZERO
		_confirm_flash_rect.size = view_size
	if _mote_particles != null:
		_mote_particles.position = Vector2(view_size.x * 0.5, view_size.y * 0.62)
		_mote_particles.visibility_rect = Rect2(
			Vector2(-view_size.x * 0.52, -view_size.y * 0.58),
			Vector2(view_size.x * 1.04, view_size.y * 0.92)
		)
	if _mote_process_material != null:
		_mote_process_material.emission_box_extents = Vector3(view_size.x * 0.42, view_size.y * 0.34, 0.0)


func _update_runtime_uniforms() -> void:
	var confirm_curve: float = _confirm_amount * _confirm_amount
	var palette := CharacterSelectVfxMaterial.get_palette(_character_id)
	var primary: Color = palette["primary"]
	var accent: Color = palette["accent"]
	var view_size := size
	var drift := Vector2(
		sin(_elapsed * 0.31) * view_size.x * 0.008,
		cos(_elapsed * 0.27 + 0.8) * view_size.y * 0.006
	) + _look_offset * 0.10
	if _backplate_rect != null:
		_backplate_rect.visible = _active
		_backplate_rect.position = -view_size * 0.018 + drift
		# Chamber backplate is authored dark with a baked vignette; run it
		# near-opaque so the room reads as space instead of a faint texture.
		_backplate_rect.modulate = Color(1.0, 1.0, 1.0, 0.88 + _hover_amount * 0.08)
	if _mandala_rect != null:
		_mandala_rect.visible = _active
		_mandala_rect.position = Vector2((view_size.x - _mandala_rect.size.x) * 0.5, view_size.y * 0.085) - drift * 0.36
		_mandala_rect.rotation = _elapsed * 0.030
		var mandala_pulse: float = 1.0 + sin(_elapsed * 1.05) * 0.010 + _hover_amount * 0.018
		_mandala_rect.scale = Vector2(mandala_pulse, mandala_pulse)
		_mandala_rect.modulate = Color(1.0, 1.0, 1.0, 0.25 + _hover_amount * 0.08)
	for side_index in range(_light_slit_rects.size()):
		var slit_rect := _light_slit_rects[side_index]
		if slit_rect == null:
			continue
		slit_rect.visible = _active
		slit_rect.rotation = sin(_elapsed * 0.22 + float(side_index)) * 0.018
		if view_size.x > 1.0 and view_size.y > 1.0:
			slit_rect.position.y = view_size.y * 0.075 + sin(_elapsed * 0.72 + float(side_index) * 1.7) * view_size.y * 0.020
		var slit_material := _light_slit_materials[side_index] if side_index < _light_slit_materials.size() else null
		if slit_material != null:
			slit_material.set_shader_parameter("elapsed", _elapsed)
			slit_material.set_shader_parameter("opacity", 0.28 + sin(_elapsed * 1.1 + float(side_index)) * 0.05 + _hover_amount * 0.07)
			slit_material.set_shader_parameter("phase", float(side_index) * 0.17)
			slit_material.set_shader_parameter("primary_color", primary)
			slit_material.set_shader_parameter("accent_color", accent)
	if _floor_ring_rect != null:
		_floor_ring_rect.visible = _active
		var ring_scale: float = 1.0 + sin(_elapsed * 1.55) * 0.018 + _hover_amount * 0.026
		_floor_ring_rect.scale = Vector2(ring_scale, ring_scale)
	if _floor_ring_material != null:
		_floor_ring_material.set_shader_parameter("elapsed", _elapsed)
		_floor_ring_material.set_shader_parameter("opacity", 0.34 + _hover_amount * 0.10)
		_floor_ring_material.set_shader_parameter("primary_color", primary)
		_floor_ring_material.set_shader_parameter("accent_color", accent)
	if _confirm_flash_rect != null:
		_confirm_flash_rect.visible = confirm_curve > 0.002
		_confirm_flash_rect.modulate = Color(primary.r, primary.g, primary.b, confirm_curve * 0.13)
	if _mote_particles != null:
		_mote_particles.visible = _active
		_mote_particles.emitting = _active
		_mote_particles.amount_ratio = clampf(0.38 + _hover_amount * 0.28 + confirm_curve * 0.34, 0.0, 1.0)


func _build_mote_process_material() -> ParticleProcessMaterial:
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, -1.0, 0.0)
	process_material.spread = 18.0
	process_material.gravity = Vector3(0.0, -4.0, 0.0)
	process_material.initial_velocity_min = 8.0
	process_material.initial_velocity_max = 22.0
	process_material.damping_min = 0.2
	process_material.damping_max = 1.1
	process_material.scale_min = 0.18
	process_material.scale_max = 0.62
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(260.0, 220.0, 0.0)
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))
	scale_curve.add_point(Vector2(0.22, 0.86))
	scale_curve.add_point(Vector2(0.72, 0.64))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_curve_texture := CurveTexture.new()
	scale_curve_texture.curve = scale_curve
	process_material.scale_curve = scale_curve_texture
	return process_material


func _build_texture_layer(layer_name: String, texture_path: String, layer_material: Material, layer_z_index: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = layer_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = _load_vfx_texture(texture_path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.material = layer_material
	rect.visible = false
	rect.z_index = layer_z_index
	add_child(rect)
	return rect


func _get_texture_layer_count() -> int:
	var count := 0
	if _backplate_rect != null:
		count += 1
	if _mandala_rect != null:
		count += 1
	if _floor_ring_rect != null:
		count += 1
	for rect in _light_slit_rects:
		if rect != null:
			count += 1
	return count


func _load_vfx_texture(path: String) -> Texture2D:
	if path == "":
		return null
	return ProjectResourceLoader.load_imported_texture(
		path,
		"Missing character-select VFX texture: %s",
		"Failed to load character-select VFX texture: %s"
	)
