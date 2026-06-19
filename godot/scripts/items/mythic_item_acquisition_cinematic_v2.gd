extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const WRITHE_SHADER := preload("res://shaders/mythic_writhe.gdshader")
const ARC_SHADER := preload("res://shaders/mythic_arc_flow.gdshader")

const BACKPLATE_TEXTURE_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_backplate.png"
const SHARD_TEXTURE_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_shard.png"
const ARC_TEXTURE_PATH := "res://assets/sprites/effects/mythic_acquisition/mythic_arc_ribbon.png"

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

const PHASE_BUILDUP := "build"
const PHASE_IGNITE := "ignite"
const PHASE_WHITE_FADE := "white_fade"
const PHASE_REVEAL := "reveal"
const PHASE_ABSORB := "absorb"
const PHASE_IMPACT := "impact"

const BUILDUP_DURATION := 1.2
const IGNITE_DURATION := 0.4
const WHITE_FADE_DURATION := 0.5
const REVEAL_CLICK_DELAY := 0.5
const ABSORB_DURATION := 1.5
const IMPACT_DURATION := 0.5
const LEGEND_AFTER_STOP_DELAY := 1.5

const ICON_SIZE := 96.0
const BACKPLATE_BASE_SIZE := 620.0
const ARC_LENGTH := 720.0
const ARC_THICKNESS := 96.0
const PROCEDURAL_TEXTURE_PREWARM_ROWS_PER_STEP := 48

# --- Impact "punch" (타격감) tuning -------------------------------------------
# These drive the original-style hit feel: accelerating buildup pre-shocks, a
# sharp white flash + screen shake at ignite, a chroma split tied to the shake,
# and a paddle-slam burst with cross light rays. The cinematic already runs
# while the game is paused, so the "hitstop" beat is expressed through a held
# bright flash + held shake envelope rather than freezing the phase timeline
# (the locked phase-lifecycle smoke test depends on the timeline staying intact).
const SHAKE_MAX_OFFSET := 30.0
const SHAKE_DECAY := 3.2
const EXTRA_FLASH_DECAY := 4.5
const WHITE_OUT_DECAY := 3.0
const BUILDUP_TICK_TIMES: Array[float] = [0.40, 0.66, 0.86, 1.02, 1.13]
const BEAM_GOLDEN_ANGLE := 2.39996323

var active := false
var phase := PHASE_BUILDUP
var phase_timer := 0.0
var elapsed := 0.0
var item_data: Dictionary = {}
var display_name := ""
var item_texture: Texture2D = null
var icon_frame_count := 1
var icon_frame_msec := 33
var icon_source_inset := 0.0
var item_origin := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
var player_center := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
var rng := RandomNumberGenerator.new()
var legend_after_played := false
var legend_after_stop_timer := 0.0
var absorb_started := false
var _backplate_texture: Texture2D = null
var _shard_texture: Texture2D = null
var _arc_texture: Texture2D = null

var _backplate: Sprite2D = null
var _backplate_mat: ShaderMaterial = null
var _backplate_intensity := 0.0
var _backplate_alpha := 0.0
var _backplate_scale := 0.6

var _arcs: Array[Sprite2D] = []
var _arc_alpha := 0.0
var _arc_extension := 0.0

var _ambient_particles: GPUParticles2D = null
var _burst_particles: GPUParticles2D = null
var _absorb_particles: GPUParticles2D = null

var _icon_backdrop: Sprite2D = null
var _icon_backdrop_alpha := 0.0
var _icon_backdrop_scale := 1.0
var _icon_sprite: Sprite2D = null
var _icon_alpha := 0.0
var _icon_scale := 0.0
var _icon_float_offset := 0.0

var _white_flash_alpha := 0.0
var _white_flash_texture: Texture2D = null
var _vignette_alpha := 0.0
var _vignette_texture: Texture2D = null
var _paddle_glow_intensity := 0.0
var _shake_trauma := 0.0
var _shake_offset := Vector2.ZERO
var _extra_flash := 0.0
var _white_out_alpha := 0.0
var _buildup_tick_index := 0
var _light_beams: Array = []
var _beam_angle_cursor := 0.0

static var _assets_prewarmed := false
static var _prewarm_assets_step_index := 0
static var _shared_icon_backdrop_texture: Texture2D = null
static var _shared_vignette_texture: Texture2D = null
static var _shared_white_flash_texture: Texture2D = null
static var _icon_backdrop_prewarm_data := PackedByteArray()
static var _icon_backdrop_prewarm_y := 0
static var _vignette_prewarm_data := PackedByteArray()
static var _vignette_prewarm_y := 0
static var _white_flash_prewarm_data := PackedByteArray()
static var _white_flash_prewarm_y := 0


static func reset_for_test() -> void:
	_assets_prewarmed = false
	_prewarm_assets_step_index = 0
	_shared_icon_backdrop_texture = null
	_shared_vignette_texture = null
	_shared_white_flash_texture = null
	_icon_backdrop_prewarm_data = PackedByteArray()
	_icon_backdrop_prewarm_y = 0
	_vignette_prewarm_data = PackedByteArray()
	_vignette_prewarm_y = 0
	_white_flash_prewarm_data = PackedByteArray()
	_white_flash_prewarm_y = 0


static func should_use_item_data(source: Dictionary) -> bool:
	var item_type: String = str(source.get("type", "")).to_lower()
	var rarity: String = str(source.get("rarity", "")).to_lower()
	return item_type == "mythic" or item_type == "legendary" or rarity == "mythic" or rarity == "legendary"


static func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


static func prewarm_assets_step() -> bool:
	if _assets_prewarmed:
		return true
	match _prewarm_assets_step_index:
		0:
			if not _prewarm_texture_path_step(
				BACKPLATE_TEXTURE_PATH,
				"Missing mythic acquisition backplate texture: %s",
				"Failed to load mythic acquisition backplate texture: %s"
			):
				return false
		1:
			if not _prewarm_texture_path_step(
				SHARD_TEXTURE_PATH,
				"Missing mythic acquisition shard texture: %s",
				"Failed to load mythic acquisition shard texture: %s"
			):
				return false
		2:
			if not _prewarm_texture_path_step(
				ARC_TEXTURE_PATH,
				"Missing mythic acquisition arc texture: %s",
				"Failed to load mythic acquisition arc texture: %s"
			):
				return false
		3:
			if not _prewarm_icon_backdrop_texture_step():
				return false
		4:
			if not _prewarm_soft_vignette_texture_step():
				return false
		5:
			if not _prewarm_soft_white_flash_texture_step():
				return false
		_:
			_assets_prewarmed = true
			_prewarm_assets_step_index = 0
			return true
	_prewarm_assets_step_index += 1
	return false


static func _prewarm_texture_path_step(
	path: String,
	missing_warning: String,
	failed_warning: String
) -> bool:
	var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		missing_warning,
		failed_warning
	)
	return bool(result.get("done", true))


static func resolve_player_center(runtime_owner: Object, constants: Dictionary = {}) -> Vector2:
	var field_height: float = float(constants.get("field_height", FIELD_HEIGHT))
	var base_width: float = float(constants.get("player_base_paddle_width", 155.0))
	var base_height: float = float(constants.get("player_base_paddle_height", 50.0))
	var player_pos: Vector2 = _get_static_vector2(
		_safe_static_owner_get(runtime_owner, "player_pos", Vector2(302.5, field_height - base_height))
	)
	var paddle_width: float = max(
		1.0,
		float(_safe_static_owner_get(runtime_owner, "player_paddle_width", base_width))
	)
	var paddle_height: float = max(
		1.0,
		float(_safe_static_owner_get(runtime_owner, "player_paddle_height", base_height))
	)
	return player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)


func _ready() -> void:
	z_index = 100
	z_as_relative = false
	top_level = true
	visible = false
	rng.randomize()
	prewarm_assets()
	_load_effect_textures()
	_build_node_tree()


func _load_effect_textures() -> void:
	_backplate_texture = ProjectResourceLoader.load_texture(
		BACKPLATE_TEXTURE_PATH,
		"Missing mythic acquisition backplate texture: %s",
		"Failed to load mythic acquisition backplate texture: %s"
	)
	_shard_texture = ProjectResourceLoader.load_texture(
		SHARD_TEXTURE_PATH,
		"Missing mythic acquisition shard texture: %s",
		"Failed to load mythic acquisition shard texture: %s"
	)
	_arc_texture = ProjectResourceLoader.load_texture(
		ARC_TEXTURE_PATH,
		"Missing mythic acquisition arc texture: %s",
		"Failed to load mythic acquisition arc texture: %s"
	)


func _build_node_tree() -> void:
	_backplate = Sprite2D.new()
	_backplate.texture = _backplate_texture
	_backplate.centered = true
	_backplate.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	_backplate.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_backplate_mat = ShaderMaterial.new()
	_backplate_mat.shader = WRITHE_SHADER
	_backplate_mat.set_shader_parameter("elapsed", 0.0)
	_backplate_mat.set_shader_parameter("intensity", 0.0)
	_backplate_mat.set_shader_parameter("distort_strength", 0.012)
	_backplate_mat.set_shader_parameter("flow_speed", 1.0)
	_backplate_mat.set_shader_parameter("pulse_speed", 1.6)
	_backplate_mat.set_shader_parameter("breath_amp", 0.18)
	_backplate_mat.set_shader_parameter("chroma_strength", 0.003)
	_backplate_mat.set_shader_parameter("core_dim_strength", 0.0)
	_backplate_mat.set_shader_parameter("core_dim_radius", 0.28)
	_backplate_mat.set_shader_parameter("core_dim_softness", 0.20)
	_backplate.material = _backplate_mat
	# Scale base sprite so it covers ~620 px regardless of source resolution
	var bp_w: float = max(1.0, float(_backplate_texture.get_width()) if _backplate_texture != null else BACKPLATE_BASE_SIZE)
	var bp_unit: float = BACKPLATE_BASE_SIZE / bp_w
	_backplate.set_meta("base_unit", bp_unit)
	_backplate.scale = Vector2(bp_unit * 0.6, bp_unit * 0.6)
	add_child(_backplate)

	for i in range(4):
		var arc := Sprite2D.new()
		arc.texture = _arc_texture
		arc.centered = true
		arc.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
		arc.rotation = float(i) * (PI * 0.5) + PI * 0.25
		arc.scale = Vector2(0.0, 0.0)
		arc.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var arc_mat := ShaderMaterial.new()
		arc_mat.shader = ARC_SHADER
		arc_mat.set_shader_parameter("elapsed", 0.0)
		arc_mat.set_shader_parameter("intensity", 1.0)
		arc_mat.set_shader_parameter("scroll_speed", 1.5)
		arc_mat.set_shader_parameter("fade_softness", 0.18)
		arc_mat.set_shader_parameter("pulse_amp", 0.15)
		arc_mat.set_shader_parameter("tint", Color(1.0, 0.92, 0.55, 1.0))
		arc.material = arc_mat
		add_child(arc)
		_arcs.append(arc)

	_ambient_particles = _build_ambient_particles()
	add_child(_ambient_particles)

	_burst_particles = _build_burst_particles()
	add_child(_burst_particles)

	_absorb_particles = _build_absorb_particles()
	add_child(_absorb_particles)

	_icon_backdrop = Sprite2D.new()
	_icon_backdrop.texture = _build_icon_backdrop_texture()
	_icon_backdrop.centered = true
	_icon_backdrop.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	_icon_backdrop.scale = Vector2.ZERO
	_icon_backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_icon_backdrop.z_index = 4
	add_child(_icon_backdrop)

	_icon_sprite = Sprite2D.new()
	_icon_sprite.centered = true
	_icon_sprite.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	_icon_sprite.scale = Vector2.ZERO
	_icon_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_icon_sprite.z_index = 5
	add_child(_icon_sprite)


func _build_ambient_particles() -> GPUParticles2D:
	var gp := GPUParticles2D.new()
	gp.amount = 24
	gp.lifetime = 1.35
	gp.preprocess = 0.45
	gp.randomness = 0.6
	gp.texture = _shard_texture
	gp.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 340.0
	pm.emission_ring_inner_radius = 285.0
	pm.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	pm.emission_ring_height = 0.0
	pm.direction = Vector3(0.0, 0.0, 0.0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 14.0
	pm.radial_accel_min = -18.0
	pm.radial_accel_max = 12.0
	pm.tangential_accel_min = 14.0
	pm.tangential_accel_max = 46.0
	pm.scale_min = 0.006
	pm.scale_max = 0.017
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -45.0
	pm.angular_velocity_max = 45.0
	pm.color = Color(1.0, 0.84, 0.45, 1.0)
	var color_ramp := Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 0.84, 0.45, 0.0))
	color_ramp.add_point(0.25, Color(1.0, 0.84, 0.45, 0.34))
	color_ramp.add_point(0.85, Color(0.78, 0.45, 0.95, 0.16))
	color_ramp.add_point(1.0, Color(0.78, 0.45, 0.95, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = color_ramp
	pm.color_ramp = gradient_tex
	gp.process_material = pm
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gp.material = canvas_mat
	gp.emitting = false
	return gp


func _build_burst_particles() -> GPUParticles2D:
	var gp := GPUParticles2D.new()
	gp.amount = 200
	gp.lifetime = 0.7
	gp.one_shot = true
	gp.explosiveness = 1.0
	gp.randomness = 0.4
	gp.texture = _shard_texture
	gp.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, 0.0, 0.0)
	pm.spread = 180.0
	pm.gravity = Vector3(0.0, 80.0, 0.0)
	pm.initial_velocity_min = 360.0
	pm.initial_velocity_max = 680.0
	pm.damping_min = 90.0
	pm.damping_max = 190.0
	pm.scale_min = 0.018
	pm.scale_max = 0.048
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -240.0
	pm.angular_velocity_max = 240.0
	var color_ramp := Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 1.0, 0.95, 1.0))
	color_ramp.add_point(0.30, Color(1.0, 0.85, 0.4, 1.0))
	color_ramp.add_point(0.70, Color(0.95, 0.55, 0.85, 0.6))
	color_ramp.add_point(1.0, Color(0.55, 0.30, 0.85, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = color_ramp
	pm.color_ramp = gradient_tex
	gp.process_material = pm
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gp.material = canvas_mat
	gp.emitting = false
	return gp


func _build_absorb_particles() -> GPUParticles2D:
	var gp := GPUParticles2D.new()
	gp.amount = 90
	gp.lifetime = 1.3
	gp.preprocess = 0.0
	gp.randomness = 0.45
	gp.texture = _shard_texture
	gp.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 220.0
	pm.emission_ring_inner_radius = 100.0
	pm.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	pm.emission_ring_height = 0.0
	pm.direction = Vector3(0.0, 0.0, 0.0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 30.0
	pm.radial_accel_min = -380.0
	pm.radial_accel_max = -260.0
	pm.tangential_accel_min = 240.0
	pm.tangential_accel_max = 380.0
	pm.scale_min = 0.020
	pm.scale_max = 0.050
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	var color_ramp := Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 0.95, 0.7, 1.0))
	color_ramp.add_point(0.5, Color(1.0, 0.78, 0.32, 0.95))
	color_ramp.add_point(1.0, Color(0.78, 0.45, 0.95, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = color_ramp
	pm.color_ramp = gradient_tex
	gp.process_material = pm
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gp.material = canvas_mat
	gp.emitting = false
	return gp


func _build_icon_backdrop_texture() -> Texture2D:
	return _get_or_build_icon_backdrop_texture()


static func _prewarm_icon_backdrop_texture_step() -> bool:
	if _shared_icon_backdrop_texture != null:
		_icon_backdrop_prewarm_data = PackedByteArray()
		_icon_backdrop_prewarm_y = 0
		return true
	var size: int = 256
	if _icon_backdrop_prewarm_data.is_empty():
		_icon_backdrop_prewarm_data.resize(size * size * 4)
		_icon_backdrop_prewarm_y = 0
	var center_x: float = float(size) * 0.5
	var center_y: float = float(size) * 0.5
	var radius: float = float(size) * 0.5
	var red := _color_to_byte(0.012)
	var green := _color_to_byte(0.010)
	var blue := _color_to_byte(0.024)
	var end_y: int = int(min(size, _icon_backdrop_prewarm_y + PROCEDURAL_TEXTURE_PREWARM_ROWS_PER_STEP))
	var offset: int = _icon_backdrop_prewarm_y * size * 4
	for y in range(_icon_backdrop_prewarm_y, end_y):
		for x in range(size):
			var dx: float = float(x) - center_x
			var dy: float = float(y) - center_y
			var d: float = sqrt(dx * dx + dy * dy) / radius
			var alpha: float = float(clamp(1.0 - smoothstep(0.34, 1.0, d), 0.0, 1.0))
			alpha = pow(alpha, 1.25) * 0.74
			_write_pixel(_icon_backdrop_prewarm_data, offset, red, green, blue, _alpha_to_byte(alpha))
			offset += 4
	_icon_backdrop_prewarm_y = end_y
	if _icon_backdrop_prewarm_y < size:
		return false
	var image: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, _icon_backdrop_prewarm_data)
	_shared_icon_backdrop_texture = ImageTexture.create_from_image(image)
	_icon_backdrop_prewarm_data = PackedByteArray()
	_icon_backdrop_prewarm_y = 0
	return true


static func _get_or_build_icon_backdrop_texture() -> Texture2D:
	if _shared_icon_backdrop_texture != null:
		return _shared_icon_backdrop_texture
	_icon_backdrop_prewarm_data = PackedByteArray()
	_icon_backdrop_prewarm_y = 0
	var size: int = 256
	var data := PackedByteArray()
	data.resize(size * size * 4)
	var center_x: float = float(size) * 0.5
	var center_y: float = float(size) * 0.5
	var radius: float = float(size) * 0.5
	var offset := 0
	var red := _color_to_byte(0.012)
	var green := _color_to_byte(0.010)
	var blue := _color_to_byte(0.024)
	for y in range(size):
		for x in range(size):
			var dx: float = float(x) - center_x
			var dy: float = float(y) - center_y
			var d: float = sqrt(dx * dx + dy * dy) / radius
			var alpha: float = float(clamp(1.0 - smoothstep(0.34, 1.0, d), 0.0, 1.0))
			alpha = pow(alpha, 1.25) * 0.74
			_write_pixel(data, offset, red, green, blue, _alpha_to_byte(alpha))
			offset += 4
	var image: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	_shared_icon_backdrop_texture = ImageTexture.create_from_image(image)
	return _shared_icon_backdrop_texture


func _build_soft_vignette_texture() -> Texture2D:
	return _get_or_build_soft_vignette_texture()


static func _prewarm_soft_vignette_texture_step() -> bool:
	if _shared_vignette_texture != null:
		_vignette_prewarm_data = PackedByteArray()
		_vignette_prewarm_y = 0
		return true
	var width: int = int(FIELD_WIDTH)
	var height: int = int(FIELD_HEIGHT)
	if _vignette_prewarm_data.is_empty():
		_vignette_prewarm_data.resize(width * height * 4)
		_vignette_prewarm_y = 0
	var center_x: float = float(width) * 0.5
	var center_y: float = float(height) * 0.5
	var half_width: float = max(1.0, float(width) * 0.5)
	var half_height: float = max(1.0, float(height) * 0.5)
	var end_y: int = int(min(height, _vignette_prewarm_y + PROCEDURAL_TEXTURE_PREWARM_ROWS_PER_STEP))
	var offset: int = _vignette_prewarm_y * width * 4
	for y in range(_vignette_prewarm_y, end_y):
		var normalized_y: float = (float(y) - center_y) / half_height
		for x in range(width):
			var normalized_x: float = (float(x) - center_x) / half_width
			var d: float = sqrt(normalized_x * normalized_x + normalized_y * normalized_y)
			var alpha: float = 1.0 - smoothstep(0.62, 1.0, d)
			alpha = pow(clamp(alpha, 0.0, 1.0), 0.92) * 0.78
			_write_pixel(_vignette_prewarm_data, offset, 0, 0, 0, _alpha_to_byte(alpha))
			offset += 4
	_vignette_prewarm_y = end_y
	if _vignette_prewarm_y < height:
		return false
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, _vignette_prewarm_data)
	_shared_vignette_texture = ImageTexture.create_from_image(image)
	_vignette_prewarm_data = PackedByteArray()
	_vignette_prewarm_y = 0
	return true


static func _get_or_build_soft_vignette_texture() -> Texture2D:
	if _shared_vignette_texture != null:
		return _shared_vignette_texture
	_vignette_prewarm_data = PackedByteArray()
	_vignette_prewarm_y = 0
	var width: int = int(FIELD_WIDTH)
	var height: int = int(FIELD_HEIGHT)
	var data := PackedByteArray()
	data.resize(width * height * 4)
	var center_x: float = float(width) * 0.5
	var center_y: float = float(height) * 0.5
	var half_width: float = max(1.0, float(width) * 0.5)
	var half_height: float = max(1.0, float(height) * 0.5)
	var offset := 0
	for y in range(height):
		var normalized_y: float = (float(y) - center_y) / half_height
		for x in range(width):
			var normalized_x: float = (float(x) - center_x) / half_width
			var d: float = sqrt(normalized_x * normalized_x + normalized_y * normalized_y)
			var alpha: float = 1.0 - smoothstep(0.62, 1.0, d)
			alpha = pow(clamp(alpha, 0.0, 1.0), 0.92) * 0.78
			_write_pixel(data, offset, 0, 0, 0, _alpha_to_byte(alpha))
			offset += 4
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	_shared_vignette_texture = ImageTexture.create_from_image(image)
	return _shared_vignette_texture


func _build_soft_white_flash_texture() -> Texture2D:
	return _get_or_build_soft_white_flash_texture()


static func _prewarm_soft_white_flash_texture_step() -> bool:
	if _shared_white_flash_texture != null:
		_white_flash_prewarm_data = PackedByteArray()
		_white_flash_prewarm_y = 0
		return true
	var width: int = int(FIELD_WIDTH)
	var height: int = int(FIELD_HEIGHT)
	if _white_flash_prewarm_data.is_empty():
		_white_flash_prewarm_data.resize(width * height * 4)
		_white_flash_prewarm_y = 0
	var center_x: float = float(width) * 0.5
	var center_y: float = float(height) * 0.5
	var half_width: float = max(1.0, float(width) * 0.5)
	var half_height: float = max(1.0, float(height) * 0.5)
	var end_y: int = int(min(height, _white_flash_prewarm_y + PROCEDURAL_TEXTURE_PREWARM_ROWS_PER_STEP))
	var offset: int = _white_flash_prewarm_y * width * 4
	for y in range(_white_flash_prewarm_y, end_y):
		var normalized_y: float = (float(y) - center_y) / half_height
		for x in range(width):
			var normalized_x: float = (float(x) - center_x) / half_width
			var d: float = sqrt(normalized_x * normalized_x + normalized_y * normalized_y)
			var alpha: float = 1.0 - smoothstep(0.54, 1.0, d)
			alpha = pow(clamp(alpha, 0.0, 1.0), 0.58)
			_write_pixel(_white_flash_prewarm_data, offset, 255, 255, 255, _alpha_to_byte(alpha))
			offset += 4
	_white_flash_prewarm_y = end_y
	if _white_flash_prewarm_y < height:
		return false
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, _white_flash_prewarm_data)
	_shared_white_flash_texture = ImageTexture.create_from_image(image)
	_white_flash_prewarm_data = PackedByteArray()
	_white_flash_prewarm_y = 0
	return true


static func _get_or_build_soft_white_flash_texture() -> Texture2D:
	if _shared_white_flash_texture != null:
		return _shared_white_flash_texture
	_white_flash_prewarm_data = PackedByteArray()
	_white_flash_prewarm_y = 0
	var width: int = int(FIELD_WIDTH)
	var height: int = int(FIELD_HEIGHT)
	var data := PackedByteArray()
	data.resize(width * height * 4)
	var center_x: float = float(width) * 0.5
	var center_y: float = float(height) * 0.5
	var half_width: float = max(1.0, float(width) * 0.5)
	var half_height: float = max(1.0, float(height) * 0.5)
	var offset := 0
	for y in range(height):
		var normalized_y: float = (float(y) - center_y) / half_height
		for x in range(width):
			var normalized_x: float = (float(x) - center_x) / half_width
			var d: float = sqrt(normalized_x * normalized_x + normalized_y * normalized_y)
			var alpha: float = 1.0 - smoothstep(0.54, 1.0, d)
			alpha = pow(clamp(alpha, 0.0, 1.0), 0.58)
			_write_pixel(data, offset, 255, 255, 255, _alpha_to_byte(alpha))
			offset += 4
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	_shared_white_flash_texture = ImageTexture.create_from_image(image)
	return _shared_white_flash_texture


static func _write_pixel(data: PackedByteArray, offset: int, r: int, g: int, b: int, a: int) -> void:
	data[offset] = r
	data[offset + 1] = g
	data[offset + 2] = b
	data[offset + 3] = a


static func _alpha_to_byte(alpha: float) -> int:
	return int(clamp(round(alpha * 255.0), 0.0, 255.0))


static func _color_to_byte(channel: float) -> int:
	return int(clamp(round(channel * 255.0), 0.0, 255.0))


func _recenter_on_viewport() -> void:
	# Force the cinematic to align to viewport center regardless of parent transform.
	# Without this, if owner.add_child() attaches us under a node whose origin is
	# the monitor/scene-root top-left (not the game field), the field-local
	# coordinates render at (0,0) of monitor space and surface as a top-left box.
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var vp_size: Vector2 = viewport.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	set_global_position((vp_size - Vector2(FIELD_WIDTH, FIELD_HEIGHT)) * 0.5)


func trigger(acquired_item_data: Dictionary, pickup_position: Vector2, target_player_center: Vector2, registry: Object = null) -> void:
	active = true
	visible = true
	phase = PHASE_BUILDUP
	phase_timer = 0.0
	elapsed = 0.0
	item_data = acquired_item_data.duplicate(true)
	display_name = _resolve_display_name(item_data)
	item_origin = pickup_position
	player_center = target_player_center
	legend_after_played = false
	legend_after_stop_timer = 0.0
	absorb_started = false
	_backplate_intensity = 0.0
	_backplate_alpha = 0.0
	_backplate_scale = 0.6
	_arc_alpha = 0.0
	_arc_extension = 0.0
	_icon_backdrop_alpha = 0.0
	_icon_backdrop_scale = 1.0
	_icon_alpha = 0.0
	_icon_scale = 0.0
	_icon_float_offset = 0.0
	_paddle_glow_intensity = 0.0
	_shake_trauma = 0.0
	_shake_offset = Vector2.ZERO
	_extra_flash = 0.0
	_white_out_alpha = 0.0
	_buildup_tick_index = 0
	_light_beams.clear()
	_beam_angle_cursor = rng.randf() * TAU
	_white_flash_alpha = 0.0
	_vignette_alpha = 1.0
	position = Vector2.ZERO
	if _backplate != null:
		_backplate.rotation = 0.0
	_load_item_texture()
	_apply_icon_texture()
	if _ambient_particles != null:
		_ambient_particles.restart()
		_ambient_particles.emitting = true
	if _burst_particles != null:
		_burst_particles.emitting = false
	if _absorb_particles != null:
		_absorb_particles.emitting = false
	_recenter_on_viewport()
	queue_redraw()
	_play_first_audio(registry, ["play_legendary_open", "play_pandora", "play_active_item"])


func reset(registry: Object = null) -> void:
	if legend_after_played:
		_play_first_audio(registry, ["stop_legendary_after"])
	active = false
	visible = false
	phase = PHASE_BUILDUP
	phase_timer = 0.0
	elapsed = 0.0
	item_data.clear()
	display_name = ""
	item_texture = null
	legend_after_played = false
	legend_after_stop_timer = 0.0
	absorb_started = false
	_backplate_intensity = 0.0
	_backplate_alpha = 0.0
	_arc_alpha = 0.0
	_arc_extension = 0.0
	_icon_backdrop_alpha = 0.0
	_icon_backdrop_scale = 1.0
	_icon_alpha = 0.0
	_icon_scale = 0.0
	_paddle_glow_intensity = 0.0
	_shake_trauma = 0.0
	_shake_offset = Vector2.ZERO
	_extra_flash = 0.0
	_white_out_alpha = 0.0
	_buildup_tick_index = 0
	_light_beams.clear()
	_beam_angle_cursor = 0.0
	_white_flash_alpha = 0.0
	_vignette_alpha = 0.0
	position = Vector2.ZERO
	if _ambient_particles != null:
		_ambient_particles.emitting = false
	if _burst_particles != null:
		_burst_particles.emitting = false
	if _absorb_particles != null:
		_absorb_particles.emitting = false
	queue_redraw()


func is_active() -> bool:
	return active


func is_waiting_for_click() -> bool:
	return active and phase == PHASE_REVEAL and phase_timer >= REVEAL_CLICK_DELAY and not absorb_started


func handle_input(event: InputEvent, registry: Object = null) -> bool:
	if not active:
		return false
	var requested := false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		requested = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		requested = touch_event.pressed
	elif GamepadInput.is_confirm_event(event):
		requested = true
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		requested = key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_SPACE
			or key_event.physical_keycode == KEY_SPACE
			or key_event.keycode == KEY_ENTER
			or key_event.physical_keycode == KEY_ENTER
		)
	if requested and is_waiting_for_click():
		_start_absorb(registry)
	return true


func update(delta: float, registry: Object = null) -> void:
	if not active:
		return
	var dt: float = max(0.0, delta)
	elapsed += dt
	phase_timer += dt
	_update_legend_after_stop(dt, registry)
	_update_shake(dt)
	_update_light_beams(dt)
	_extra_flash = max(0.0, _extra_flash - dt * EXTRA_FLASH_DECAY)
	_white_out_alpha = max(0.0, _white_out_alpha - dt * WHITE_OUT_DECAY)

	match phase:
		PHASE_BUILDUP:
			_update_buildup()
			if phase_timer >= BUILDUP_DURATION:
				_start_ignite(registry)
		PHASE_IGNITE:
			_update_ignite()
			if phase_timer >= IGNITE_DURATION:
				_set_phase(PHASE_WHITE_FADE)
		PHASE_WHITE_FADE:
			_update_white_fade()
			if phase_timer >= WHITE_FADE_DURATION:
				_set_phase(PHASE_REVEAL)
		PHASE_REVEAL:
			_update_reveal(dt)
		PHASE_ABSORB:
			_update_absorb()
			if phase_timer >= ABSORB_DURATION:
				_start_impact(registry)
		PHASE_IMPACT:
			_update_impact()
			if phase_timer >= IMPACT_DURATION:
				reset(registry)

	_apply_visual_state()
	queue_redraw()


func draw(_canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	# Compatibility wrapper. Visual rendering happens through child nodes
	# and the local _draw() function. Re-apply viewport-center alignment
	# every frame so the cinematic does not drift back to (0,0); shake_offset
	# stacks on top.
	if not active:
		return
	var total_shake: Vector2 = shake_offset + _shake_offset
	var viewport: Viewport = get_viewport()
	if viewport != null:
		var vp_size: Vector2 = viewport.get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			set_global_position((vp_size - Vector2(FIELD_WIDTH, FIELD_HEIGHT)) * 0.5 + total_shake)
			return
	position = total_shake


func _draw() -> void:
	if not active:
		return
	# Overscan the full-screen overlays by the shake amplitude so the screen
	# shake never reveals an un-darkened / un-flashed sliver at a screen edge.
	var overscan: float = SHAKE_MAX_OFFSET + 8.0
	var overlay_rect := Rect2(
		Vector2(-overscan, -overscan),
		Vector2(FIELD_WIDTH + overscan * 2.0, FIELD_HEIGHT + overscan * 2.0)
	)
	# Soft vignette behind everything. A hard rect reads as a visible box once
	# this detached host is centered in viewport space.
	if _vignette_alpha > 0.001:
		if _vignette_texture == null:
			_vignette_texture = _build_soft_vignette_texture()
		draw_texture_rect(
			_vignette_texture,
			overlay_rect,
			false,
			Color(1.0, 1.0, 1.0, clamp(_vignette_alpha, 0.0, 1.0))
		)
	# Buildup light-leak beams — sharp strands that shoot out one at a time during
	# the rising tension. Drawn over the dim vignette but behind the central glow
	# so they read as light leaking out from the core.
	_draw_light_beams()
	# Soft white flash overlay. A field-sized draw_rect leaves a visible square
	# during the brightest phase.
	if _white_flash_alpha > 0.001:
		if _white_flash_texture == null:
			_white_flash_texture = _build_soft_white_flash_texture()
		draw_texture_rect(
			_white_flash_texture,
			overlay_rect,
			false,
			Color(1.0, 1.0, 1.0, clamp(_white_flash_alpha, 0.0, 1.0))
		)
	# Full-screen flat white-out punch. This cinematic is the topmost layer
	# (z_index 100, top_level, and the project uses no CanvasLayers), so a huge
	# rect centered on the field center blankets the ENTIRE monitor — beyond the
	# central game canvas into the pillar / letterbox margins. The viewport clips
	# the overdraw, so the oversize is free.
	if _white_out_alpha > 0.001:
		var white_out_reach: float = 5000.0
		var white_out_rect := Rect2(
			Vector2(FIELD_WIDTH * 0.5 - white_out_reach, FIELD_HEIGHT * 0.5 - white_out_reach),
			Vector2(white_out_reach * 2.0, white_out_reach * 2.0)
		)
		draw_rect(white_out_rect, Color(1.0, 1.0, 1.0, clamp(_white_out_alpha, 0.0, 1.0)), true)
	# Paddle glow halo + slam cross-rays (additive feel via warm color over the
	# dim vignette). The cross rays sell the paddle "slam" impact landing.
	if _paddle_glow_intensity > 0.001:
		var glow_i: float = clamp(_paddle_glow_intensity, 0.0, 1.0)
		var pulse: float = 1.0 + (1.0 - glow_i) * 0.6
		var radius: float = 90.0 * pulse
		var glow_color := Color(1.0, 0.85, 0.4, glow_i * 0.55)
		draw_circle(player_center, radius, glow_color)
		draw_circle(player_center, radius * 0.6, Color(1.0, 1.0, 0.92, glow_i * 0.35))
		draw_circle(player_center, radius * 0.3, Color(1.0, 1.0, 1.0, glow_i * 0.5))
		_draw_paddle_slam_rays(player_center, glow_i)


func _draw_paddle_slam_rays(center: Vector2, intensity: float) -> void:
	var reach: float = 250.0 * (0.45 + intensity * 0.85)
	var warm := Color(1.0, 0.92, 0.6, intensity * 0.5)
	var core := Color(1.0, 1.0, 0.95, intensity * 0.85)
	# Horizontal beam (widest), with a bright thin core for an additive look.
	var h := Vector2(reach, 0.0)
	draw_line(center - h, center + h, warm, 9.0)
	draw_line(center - h, center + h, core, 2.5)
	# Vertical beam — shorter downward since the paddle hugs the bottom.
	var v_up := Vector2(0.0, reach * 0.62)
	var v_dn := Vector2(0.0, reach * 0.26)
	draw_line(center - v_up, center + v_dn, warm, 7.0)
	draw_line(center - v_up, center + v_dn, core, 2.0)
	# Diagonal X beams.
	var diag: float = reach * 0.6 * 0.7071
	var d1 := Vector2(diag, diag)
	var d2 := Vector2(diag, -diag)
	draw_line(center - d1, center + d1, warm, 4.5)
	draw_line(center - d2, center + d2, warm, 4.5)


func _draw_light_beams() -> void:
	if _light_beams.is_empty():
		return
	var center := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	for beam in _light_beams:
		var age: float = float(beam.get("age", 0.0))
		var life: float = float(beam.get("life", 0.5))
		if life <= 0.0:
			continue
		var ext: float = clamp(age / max(0.01, float(beam.get("extend_time", 0.12))), 0.0, 1.0)
		var ext_eased: float = 1.0 - pow(1.0 - ext, 3.0)
		var head: float = float(beam.get("max_len", 600.0)) * ext_eased
		var inner: float = 16.0
		if head <= inner:
			continue
		var ang: float = float(beam.get("angle", 0.0))
		var dir := Vector2(cos(ang), sin(ang))
		var p0 := center + dir * inner
		var p1 := center + dir * head
		var fade_in: float = clamp(age / 0.07, 0.0, 1.0)
		var fade_out: float = clamp((life - age) / max(0.01, life * 0.5), 0.0, 1.0)
		var alpha: float = fade_in * fade_out
		if alpha <= 0.001:
			continue
		var base_col: Color = beam.get("color", Color(1.0, 0.85, 0.45))
		var w: float = float(beam.get("width", 4.0))
		# Soft warm glow line + bright thin core + a hot head point to sell the
		# "streak shooting out" read.
		draw_line(p0, p1, Color(base_col.r, base_col.g, base_col.b, alpha * 0.45), w)
		draw_line(p0, p1, Color(1.0, 1.0, 0.96, alpha * 0.9), max(1.5, w * 0.32))
		draw_circle(p1, clamp(w * 0.6, 2.0, 14.0), Color(1.0, 1.0, 0.95, alpha * 0.85))


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"phase_timer": phase_timer,
		"elapsed": elapsed,
		"item_name": str(item_data.get("name", "")),
		"display_name": display_name,
		"player_center": player_center,
		"waiting_for_click": is_waiting_for_click(),
		"absorb_started": absorb_started,
		"icon_alpha": _icon_alpha,
		"backplate_intensity": _backplate_intensity,
		"shake_trauma": _shake_trauma,
	}


func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_timer = 0.0
	if phase == PHASE_WHITE_FADE and _ambient_particles != null:
		_ambient_particles.emitting = false
		_ambient_particles.restart()
		_ambient_particles.emitting = false


func _start_ignite(registry: Object) -> void:
	_set_phase(PHASE_IGNITE)
	_add_shake(1.0)
	_white_out_alpha = 1.0
	_light_beams.clear()
	if _burst_particles != null:
		_burst_particles.restart()
		_burst_particles.emitting = true
	_play_first_audio(registry, ["play_legendary_after", "play_pandora", "play_active_item"])
	legend_after_played = true


func _start_absorb(registry: Object) -> void:
	if absorb_started:
		return
	absorb_started = true
	_set_phase(PHASE_ABSORB)
	_add_shake(0.35)
	if legend_after_played:
		legend_after_stop_timer = LEGEND_AFTER_STOP_DELAY
	if _absorb_particles != null:
		_absorb_particles.restart()
		_absorb_particles.emitting = true
	_play_first_audio(registry, ["play_legendary_ending", "play_item_get"])


func _start_impact(_registry: Object) -> void:
	_set_phase(PHASE_IMPACT)
	_add_shake(0.72)
	if _ambient_particles != null:
		_ambient_particles.emitting = false
	if _absorb_particles != null:
		_absorb_particles.emitting = false
	_paddle_glow_intensity = 1.0


func _add_shake(amount: float) -> void:
	_shake_trauma = clamp(_shake_trauma + amount, 0.0, 1.0)


func _update_shake(dt: float) -> void:
	if _shake_trauma <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	_shake_trauma = max(0.0, _shake_trauma - dt * SHAKE_DECAY)
	# Trauma^2 falloff so the shake hits hard, then drops away cleanly.
	var power: float = _shake_trauma * _shake_trauma
	var mag: float = power * SHAKE_MAX_OFFSET
	_shake_offset = Vector2(
		rng.randf_range(-1.0, 1.0) * mag,
		rng.randf_range(-1.0, 1.0) * mag
	)


func _spawn_buildup_beam(idx: int) -> void:
	# Light strands "leak out" from the center per buildup tick, escalating in
	# count + thickness as the tension rises. Widths are randomized wide and the
	# lengths overshoot the central glow so a tick momentarily sweeps the whole
	# screen (the original chest-crack beat the player loved).
	var count: int = 2 + int(round(float(idx) * 1.6)) + rng.randi_range(0, 2)
	var palette: Array = [
		Color(1.0, 0.84, 0.45),
		Color(1.0, 1.0, 0.95),
		Color(0.62, 0.66, 1.0),
	]
	for _n in range(count):
		_beam_angle_cursor += BEAM_GOLDEN_ANGLE + rng.randf_range(-0.22, 0.22)
		_light_beams.append({
			"angle": _beam_angle_cursor,
			"age": 0.0,
			"life": 0.7 + rng.randf() * 0.5,
			"extend_time": 0.07 + rng.randf() * 0.05,
			"max_len": 900.0 + rng.randf() * 560.0,
			"width": (rng.randf_range(14.0, 22.0) + float(idx) * rng.randf_range(3.0, 6.0)) * rng.randf_range(1.2, 1.8),
			"color": palette[rng.randi() % palette.size()],
		})


func _update_light_beams(dt: float) -> void:
	if _light_beams.is_empty():
		return
	var i: int = _light_beams.size() - 1
	while i >= 0:
		var beam: Dictionary = _light_beams[i]
		beam["age"] = float(beam.get("age", 0.0)) + dt
		if float(beam["age"]) >= float(beam.get("life", 0.5)):
			_light_beams.remove_at(i)
		i -= 1


func _update_buildup() -> void:
	var t: float = clamp(phase_timer / BUILDUP_DURATION, 0.0, 1.0)
	var eased: float = ease(t, 0.4)
	# Accelerating pre-shock "cracks": fire escalating shake + flash + backplate
	# flare blips at the tick times so the buildup reads as rising tension that
	# is about to burst (the original light-crack beats).
	while _buildup_tick_index < BUILDUP_TICK_TIMES.size() and phase_timer >= BUILDUP_TICK_TIMES[_buildup_tick_index]:
		var idx: int = _buildup_tick_index
		_add_shake(0.14 + float(idx) * 0.06)
		_extra_flash = max(_extra_flash, 0.26 + float(idx) * 0.11)
		_spawn_buildup_beam(idx)
		_buildup_tick_index += 1
	_backplate_alpha = eased
	_backplate_intensity = lerp(0.4, 1.0, eased) + _extra_flash * 1.3
	_backplate_scale = lerp(0.55, 1.0, eased) + _extra_flash * 0.04
	_arc_alpha = 0.0
	_arc_extension = 0.0
	_icon_backdrop_alpha = 0.0
	_icon_alpha = 0.0
	_icon_scale = 0.0
	_white_flash_alpha = _extra_flash


func _update_ignite() -> void:
	var t: float = clamp(phase_timer / IGNITE_DURATION, 0.0, 1.0)
	var eased: float = ease(t, 0.3)
	# Brightness + scale OVERSHOOT punch on the explosion frame, settling fast.
	var punch: float = ease(t, 0.25)
	_backplate_intensity = lerp(1.9, 1.1, punch)
	_backplate_alpha = 1.0
	_backplate_scale = lerp(1.30, 1.12, punch)
	_arc_alpha = lerp(1.0, 0.7, eased)
	_arc_extension = eased
	_icon_backdrop_alpha = 0.0
	# Sharp white flash that HOLDS near full for the first third of ignite then
	# falls off — the held bright frame substitutes for a hitstop pause.
	_white_flash_alpha = max(_extra_flash, clamp((1.0 - t) * 1.5, 0.0, 1.0))


func _update_white_fade() -> void:
	var t: float = clamp(phase_timer / WHITE_FADE_DURATION, 0.0, 1.0)
	var fade: float = 1.0 - t
	# Gentle settle glow only — the hard flash already fired during ignite.
	_white_flash_alpha = 0.4 * fade
	_backplate_intensity = lerp(1.1, 0.9, t)
	_backplate_alpha = 1.0
	_arc_alpha = lerp(0.7, 0.35, t)
	_icon_backdrop_alpha = 0.0


func _update_reveal(dt: float) -> void:
	_white_flash_alpha = 0.0
	var reveal_in: float = clamp(phase_timer / 0.45, 0.0, 1.0)
	var reveal_eased: float = ease(reveal_in, 0.4)
	_icon_alpha = reveal_in
	_icon_scale = lerp(0.0, 1.0, reveal_eased)
	_icon_backdrop_alpha = 0.68 * reveal_eased
	_icon_backdrop_scale = lerp(0.42, 0.72, reveal_eased)
	_icon_float_offset = sin(elapsed * 1.6) * 5.0
	_backplate_intensity = 0.42 + 0.04 * sin(elapsed * 1.3)
	_backplate_alpha = 0.62
	_arc_alpha = 0.35 + 0.05 * sin(elapsed * 0.9)
	if _backplate != null:
		_backplate.rotation += dt * 0.18


func _update_absorb() -> void:
	var t: float = clamp(phase_timer / ABSORB_DURATION, 0.0, 1.0)
	var eased: float = ease(t, 0.6)
	_backplate_alpha = lerp(1.0, 0.0, eased)
	_backplate_intensity = lerp(0.95, 1.5, eased)
	_backplate_scale = lerp(1.0, 0.35, eased)
	_arc_alpha = lerp(0.35, 0.0, eased)
	_icon_backdrop_alpha = lerp(0.68, 0.18, eased)
	_icon_backdrop_scale = lerp(0.72, 0.38, eased)
	var center: Vector2 = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	var spiral_angle: float = eased * TAU * 1.8
	var radius: float = (1.0 - eased) * 60.0
	var spiral_pos: Vector2 = Vector2(cos(spiral_angle), sin(spiral_angle)) * radius
	var icon_pos: Vector2 = center.lerp(player_center, eased) + spiral_pos
	if _icon_sprite != null:
		_icon_sprite.position = icon_pos
	_icon_alpha = lerp(1.0, 0.4, eased)
	_icon_scale = lerp(1.0, 0.25, eased)


func _update_impact() -> void:
	var t: float = clamp(phase_timer / IMPACT_DURATION, 0.0, 1.0)
	_paddle_glow_intensity = (1.0 - t)
	# Quick white pop on the paddle-slam landing frame.
	_white_flash_alpha = clamp(1.0 - t * 2.4, 0.0, 1.0) * 0.6
	_icon_alpha = 0.0
	_icon_backdrop_alpha = 0.0
	_backplate_alpha = 0.0
	_arc_alpha = 0.0


func _update_legend_after_stop(dt: float, registry: Object) -> void:
	if legend_after_stop_timer <= 0.0:
		return
	legend_after_stop_timer = max(0.0, legend_after_stop_timer - dt)
	if legend_after_stop_timer <= 0.0:
		_play_first_audio(registry, ["stop_legendary_after"])
		legend_after_played = false
		legend_after_played = false


func _apply_visual_state() -> void:
	if _backplate != null and _backplate_mat != null:
		_backplate_mat.set_shader_parameter("elapsed", elapsed)
		_backplate_mat.set_shader_parameter("intensity", _backplate_intensity)
		_backplate_mat.set_shader_parameter("core_dim_strength", _get_backplate_core_dim_strength())
		# Chroma split scales with shake trauma so the color aberration spikes on
		# the same frames the screen punches (ignite / paddle slam).
		_backplate_mat.set_shader_parameter("chroma_strength", clamp(0.003 + _shake_trauma * 0.024, 0.0, 0.03))
		_backplate.modulate = Color(1.0, 1.0, 1.0, clamp(_backplate_alpha, 0.0, 1.0))
		var base_unit: float = float(_backplate.get_meta("base_unit", 1.0))
		var s: float = base_unit * _backplate_scale
		_backplate.scale = Vector2(s, s)

	for arc in _arcs:
		if arc.material is ShaderMaterial:
			(arc.material as ShaderMaterial).set_shader_parameter("elapsed", elapsed)
		var tex_w: float = max(1.0, float(arc.texture.get_width()))
		var tex_h: float = max(1.0, float(arc.texture.get_height()))
		var arc_size_x: float = (ARC_LENGTH * _arc_extension) / tex_w
		var arc_size_y: float = ARC_THICKNESS / tex_h
		arc.scale = Vector2(arc_size_x, arc_size_y)
		arc.modulate = Color(1.0, 1.0, 1.0, clamp(_arc_alpha, 0.0, 1.0))

	if _icon_backdrop != null:
		var backdrop_pos := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
		if phase == PHASE_REVEAL:
			backdrop_pos.y += _icon_float_offset
		elif phase == PHASE_ABSORB and _icon_sprite != null:
			backdrop_pos = _icon_sprite.position
		_icon_backdrop.position = backdrop_pos
		_icon_backdrop.scale = Vector2(_icon_backdrop_scale, _icon_backdrop_scale)
		_icon_backdrop.modulate = Color(1.0, 1.0, 1.0, clamp(_icon_backdrop_alpha, 0.0, 1.0))

	if _icon_sprite != null and item_texture != null:
		var src_rect: Rect2 = _get_icon_source_rect()
		if icon_frame_count > 1 and src_rect.size.x > 0.0 and src_rect.size.y > 0.0:
			_icon_sprite.region_enabled = true
			_icon_sprite.region_rect = src_rect
		var ref_w: float
		var ref_h: float
		if _icon_sprite.region_enabled:
			ref_w = max(1.0, src_rect.size.x)
			ref_h = max(1.0, src_rect.size.y)
		else:
			ref_w = max(1.0, float(item_texture.get_width()))
			ref_h = max(1.0, float(item_texture.get_height()))
		var target_size: float = ICON_SIZE * _icon_scale
		var fit: float = target_size / max(ref_w, ref_h)
		_icon_sprite.scale = Vector2(fit, fit)
		_icon_sprite.modulate = Color(1.0, 1.0, 1.0, clamp(_icon_alpha, 0.0, 1.0))
		if phase == PHASE_REVEAL:
			_icon_sprite.position = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5 + _icon_float_offset)

	if _absorb_particles != null and absorb_started:
		var pm: ParticleProcessMaterial = _absorb_particles.process_material as ParticleProcessMaterial
		if pm != null:
			var center: Vector2 = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
			var dir: Vector2 = (player_center - center).normalized()
			pm.gravity = Vector3(dir.x * 480.0, dir.y * 480.0, 0.0)


func _get_backplate_core_dim_strength() -> float:
	match phase:
		PHASE_BUILDUP:
			return 0.20
		PHASE_IGNITE:
			return 0.0
		PHASE_WHITE_FADE:
			return 0.45
		PHASE_REVEAL:
			return 0.84
		PHASE_ABSORB:
			return 0.86
		_:
			return 0.0


func _apply_icon_texture() -> void:
	if _icon_sprite == null:
		return
	if item_texture == null:
		_icon_sprite.texture = null
		_icon_sprite.region_enabled = false
		return
	_icon_sprite.texture = item_texture
	if icon_frame_count > 1:
		var src_rect: Rect2 = _get_icon_source_rect()
		if src_rect.size.x > 0.0 and src_rect.size.y > 0.0:
			_icon_sprite.region_enabled = true
			_icon_sprite.region_rect = src_rect
			return
	_icon_sprite.region_enabled = false


func _load_item_texture() -> void:
	item_texture = null
	icon_frame_count = max(1, int(item_data.get("icon_frame_count", 1)))
	icon_frame_msec = max(1, int(item_data.get("icon_frame_msec", 33)))
	icon_source_inset = max(0.0, float(item_data.get("icon_source_inset", 0.0)))
	var path := str(item_data.get("icon_sheet_path", ""))
	if path == "":
		path = str(item_data.get("icon_path", ""))
	if path == "":
		return
	item_texture = ProjectResourceLoader.load_imported_texture(path)


func _get_icon_source_rect() -> Rect2:
	if item_texture == null:
		return Rect2()
	var texture_size: Vector2 = item_texture.get_size()
	var frame_count: int = max(1, icon_frame_count)
	var frame_width: float = texture_size.x / float(frame_count)
	var frame_index: int = 0
	if frame_count > 1:
		frame_index = int(floor(float(Time.get_ticks_msec()) / float(icon_frame_msec))) % frame_count
	var inset: float = min(icon_source_inset, max(0.0, min(frame_width, texture_size.y) * 0.42))
	return Rect2(
		Vector2(frame_width * float(frame_index) + inset, inset),
		Vector2(max(1.0, frame_width - inset * 2.0), max(1.0, texture_size.y - inset * 2.0))
	)


func _resolve_display_name(source: Dictionary) -> String:
	for key in ["qualified_display_name", "korean_name", "display_name", "name"]:
		var value := str(source.get(key, ""))
		if value != "":
			return LanguageSettings.translate_text(value)
	return LanguageSettings.translate_text("신화 아이템")


func _play_first_audio(registry: Object, method_names: Array[String]) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


static func _safe_static_owner_get(runtime_owner: Object, key: String, fallback: Variant) -> Variant:
	if runtime_owner == null:
		return fallback
	var value: Variant = runtime_owner.get(key)
	return fallback if value == null else value


static func _get_static_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
