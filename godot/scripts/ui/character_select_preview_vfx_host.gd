@tool
extends Control

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CharacterSelectVfxMaterial := preload("res://scripts/ui/character_select_vfx_material.gd")

const ASSET_ROOT := "res://assets/ui/character_select_vfx/"
const DEEP_BACKPLATE_PATH := ASSET_ROOT + "character_select_deep_backplate.png"
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

var _confirm_flash_rect: ColorRect = null
var _mote_particles: GPUParticles2D = null
var _mote_process_material: ParticleProcessMaterial = null

var _additive_canvas_material: CanvasItemMaterial = null


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
	set_active(true)
	_layout_layers()
	_update_runtime_uniforms()


func set_hover_amount(value: float) -> void:
	_hover_target = clampf(value, 0.0, 1.0)
	if _active:
		set_process(true)


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
	_mote_process_material = null
	_additive_canvas_material = null
	_free_layer_node(_mote_particles)
	_free_layer_node(_confirm_flash_rect)
	_mote_particles = null
	_confirm_flash_rect = null
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
		"gpu_particle_layers": 1 if _mote_particles != null else 0,
		"particles_emitting": _mote_particles != null and _mote_particles.emitting,
		"texture_layers": 0,
	}


func get_layer_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node in [_confirm_flash_rect]:
		var control := node as Control
		if control != null and control.visible:
			rects.append(Rect2(control.position, control.size))
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


func _build_layers() -> void:
	if _mote_particles != null and is_instance_valid(_mote_particles):
		return
	CharacterSelectVfxMaterial.prewarm()
	_additive_canvas_material = CharacterSelectVfxMaterial.build_additive_canvas_material()

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


func _layout_layers() -> void:
	var view_size := size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
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
	if _confirm_flash_rect != null:
		var palette := CharacterSelectVfxMaterial.get_palette(_character_id)
		var primary: Color = palette["primary"]
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


func _load_vfx_texture(path: String) -> Texture2D:
	if path == "":
		return null
	return ProjectResourceLoader.load_imported_texture(
		path,
		"Missing character-select VFX texture: %s",
		"Failed to load character-select VFX texture: %s"
	)
