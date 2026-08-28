extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const Stage4PonkMagneticAssets := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_assets.gd")

const MAGNETIC_FIELD_SHEET_PATH := Stage4PonkMagneticAssets.MAGNETIC_FIELD_SHEET_PATH
const CHARGE_GLYPH_TEXTURE_PATH := Stage4PonkMagneticAssets.CHARGE_GLYPH_TEXTURE_PATH
const LATTICE_TEXTURE_PATH := Stage4PonkMagneticAssets.LATTICE_TEXTURE_PATH
const PRISM_SHARD_TEXTURE_PATH := Stage4PonkMagneticAssets.PRISM_SHARD_TEXTURE_PATH
const ARC_RIBBON_TEXTURE_PATH := Stage4PonkMagneticAssets.ARC_RIBBON_TEXTURE_PATH
const COLLAPSE_BURST_TEXTURE_PATH := Stage4PonkMagneticAssets.COLLAPSE_BURST_TEXTURE_PATH
const PROJECTILE_ORB_TEXTURE_PATH := Stage4PonkMagneticAssets.PROJECTILE_ORB_TEXTURE_PATH
const PROJECTILE_TRAIL_TEXTURE_PATH := Stage4PonkMagneticAssets.PROJECTILE_TRAIL_TEXTURE_PATH
const IMPACT_BURST_TEXTURE_PATH := Stage4PonkMagneticAssets.IMPACT_BURST_TEXTURE_PATH
const MAGNETIC_FIELD_COLS := Stage4PonkMagneticAssets.MAGNETIC_FIELD_COLS
const MAGNETIC_FIELD_ROWS := Stage4PonkMagneticAssets.MAGNETIC_FIELD_ROWS
const MAGNETIC_FIELD_FRAME_COUNT := Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_COUNT
const NORMAL_RADIUS := 160.0
const ARC_COUNT := 3
const COLLAPSE_BURST_IN_SECONDS := 0.10
const COLLAPSE_BURST_HOLD_SECONDS := 0.10
const COLLAPSE_BURST_OUT_SECONDS := 0.10
const PROJECTILE_ORB_IN_START_SECONDS := 0.20
const PROJECTILE_ORB_IN_SECONDS := 0.15
const PROJECTILE_TRAIL_START_SECONDS := 0.30
const CHARGE_GLYPH_OUT_PROGRESS := 0.24
const IMPACT_BURST_IN_SECONDS := 0.05
const IMPACT_BURST_HOLD_SECONDS := 0.04
const IMPACT_BURST_OUT_SECONDS := 0.06

var open_value := 0.0
var elapsed_sec := 0.0

var _state: Dictionary = {}
var _active := false
var _charge_glyph_sprite: Sprite2D = null
var _lattice_sprite: Sprite2D = null
var _sheet_sprite: Sprite2D = null
var _arc_sprites: Array[Sprite2D] = []
var _arc_materials: Array[ShaderMaterial] = []
var _prism_particles: GPUParticles2D = null
var _collapse_sprite: Sprite2D = null
var _impact_burst_sprite: Sprite2D = null
var _projectile_trail_sprite: Sprite2D = null
var _projectile_orb_sprite: Sprite2D = null
var _charge_glyph_material: ShaderMaterial = null
var _lattice_material: ShaderMaterial = null
var _collapse_material: ShaderMaterial = null
var _impact_burst_material: ShaderMaterial = null
var _projectile_orb_material: ShaderMaterial = null
var _projectile_trail_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _open_tween: Tween = null
var _charge_glyph_preset_name := ""
var _lattice_preset_name := ""

static var _magnetic_sheet_texture: Texture2D = null
static var _charge_glyph_texture: Texture2D = null
static var _lattice_texture: Texture2D = null
static var _prism_shard_texture: Texture2D = null
static var _arc_ribbon_texture: Texture2D = null
static var _collapse_burst_texture: Texture2D = null
static var _projectile_orb_texture: Texture2D = null
static var _projectile_trail_texture: Texture2D = null
static var _impact_burst_texture: Texture2D = null
static var _lattice_shader: Shader = null
static var _arc_shader: Shader = null
static var _collapse_shader: Shader = null
static var _projectile_orb_shader: Shader = null
static var _projectile_trail_shader: Shader = null
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
			_get_magnetic_sheet_texture()
		1:
			_get_charge_glyph_texture()
			_get_lattice_texture()
		2:
			_get_prism_shard_texture()
			_get_arc_ribbon_texture()
		3:
			_get_collapse_burst_texture()
			_get_projectile_orb_texture()
		4:
			_get_projectile_trail_texture()
			_get_impact_burst_texture()
		5:
			WritheEmber.prewarm()
		6:
			_get_lattice_shader()
			_get_arc_shader()
		7:
			_get_collapse_shader()
			_get_projectile_orb_shader()
			_get_projectile_trail_shader()
		8:
			_build_prism_particle_material()
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
		"magnetic_fx_shader_host_pipeline": (
			WritheEmber.has_preset("magnetic_charge_glyph")
			and WritheEmber.has_preset("magnetic_lattice")
			and _get_arc_shader() != null
			and _get_collapse_shader() != null
			and _get_projectile_orb_shader() != null
			and _get_projectile_trail_shader() != null
		),
		"magnetic_fx_shader_layers": 8,
		"magnetic_fx_gpu_particle_layers": 1,
		"magnetic_fx_texture_pieces_ready": (
			_get_magnetic_sheet_texture() != null
			and _is_png_texture_loaded(CHARGE_GLYPH_TEXTURE_PATH, _get_charge_glyph_texture())
			and _is_png_texture_loaded(LATTICE_TEXTURE_PATH, _get_lattice_texture())
			and _is_png_texture_loaded(PRISM_SHARD_TEXTURE_PATH, _get_prism_shard_texture())
			and _is_png_texture_loaded(ARC_RIBBON_TEXTURE_PATH, _get_arc_ribbon_texture())
		),
		"magnetic_phase2_fx_texture_pieces_ready": (
			_is_png_texture_loaded(COLLAPSE_BURST_TEXTURE_PATH, _get_collapse_burst_texture())
			and _is_png_texture_loaded(PROJECTILE_ORB_TEXTURE_PATH, _get_projectile_orb_texture())
			and _is_png_texture_loaded(PROJECTILE_TRAIL_TEXTURE_PATH, _get_projectile_trail_texture())
			and _is_png_texture_loaded(IMPACT_BURST_TEXTURE_PATH, _get_impact_burst_texture())
		),
		"magnetic_upgrade_fx_texture_pieces_ready": (
			_is_png_texture_loaded(CHARGE_GLYPH_TEXTURE_PATH, _get_charge_glyph_texture())
			and _is_png_texture_loaded(IMPACT_BURST_TEXTURE_PATH, _get_impact_burst_texture())
		),
		"magnetic_fx_charge_glyph_png_slot": _is_png_texture_loaded(CHARGE_GLYPH_TEXTURE_PATH, _get_charge_glyph_texture()),
		"magnetic_fx_lattice_png_slot": _is_png_texture_loaded(LATTICE_TEXTURE_PATH, _get_lattice_texture()),
		"magnetic_fx_prism_shard_png_slot": _is_png_texture_loaded(PRISM_SHARD_TEXTURE_PATH, _get_prism_shard_texture()),
		"magnetic_fx_arc_ribbon_png_slot": _is_png_texture_loaded(ARC_RIBBON_TEXTURE_PATH, _get_arc_ribbon_texture()),
		"magnetic_fx_collapse_burst_png_slot": _is_png_texture_loaded(COLLAPSE_BURST_TEXTURE_PATH, _get_collapse_burst_texture()),
		"magnetic_fx_projectile_orb_png_slot": _is_png_texture_loaded(PROJECTILE_ORB_TEXTURE_PATH, _get_projectile_orb_texture()),
		"magnetic_fx_projectile_trail_png_slot": _is_png_texture_loaded(PROJECTILE_TRAIL_TEXTURE_PATH, _get_projectile_trail_texture()),
		"magnetic_fx_impact_burst_png_slot": _is_png_texture_loaded(IMPACT_BURST_TEXTURE_PATH, _get_impact_burst_texture()),
		"magnetic_fx_charge_glyph_texture_path": CHARGE_GLYPH_TEXTURE_PATH,
		"magnetic_fx_lattice_texture_path": LATTICE_TEXTURE_PATH,
		"magnetic_fx_prism_shard_texture_path": PRISM_SHARD_TEXTURE_PATH,
		"magnetic_fx_arc_ribbon_texture_path": ARC_RIBBON_TEXTURE_PATH,
		"magnetic_fx_collapse_burst_texture_path": COLLAPSE_BURST_TEXTURE_PATH,
		"magnetic_fx_projectile_orb_texture_path": PROJECTILE_ORB_TEXTURE_PATH,
		"magnetic_fx_projectile_trail_texture_path": PROJECTILE_TRAIL_TEXTURE_PATH,
		"magnetic_fx_impact_burst_texture_path": IMPACT_BURST_TEXTURE_PATH,
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
	z_index = 14
	_additive_material = _make_additive_material()
	_build_children()
	set_active(should_remain_active and has_runtime_assets())
	if should_remain_active:
		_apply_state()
		queue_redraw()


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _lattice_sprite == null:
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and can_handle_state(_state))
	if not visible:
		return
	elapsed_sec = float(_state.get("elapsed", float(Time.get_ticks_msec()) * 0.001))
	_apply_state()
	queue_redraw()


func set_active(active: bool) -> void:
	if active and not _active:
		_start_open_tween()
	_active = active
	visible = active
	set_process(false)
	if _charge_glyph_sprite != null:
		_charge_glyph_sprite.visible = false
	if _lattice_sprite != null:
		_lattice_sprite.visible = false
	if _sheet_sprite != null:
		_sheet_sprite.visible = false
	for arc_sprite in _arc_sprites:
		arc_sprite.visible = false
	if _collapse_sprite != null:
		_collapse_sprite.visible = false
	if _impact_burst_sprite != null:
		_impact_burst_sprite.visible = false
	if _projectile_trail_sprite != null:
		_projectile_trail_sprite.visible = false
	if _projectile_orb_sprite != null:
		_projectile_orb_sprite.visible = false
	if _prism_particles != null:
		_prism_particles.emitting = false
	if not active:
		_stop_open_tween()
		open_value = 0.0
		_charge_glyph_preset_name = ""
		_lattice_preset_name = ""


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	_stop_open_tween()
	_state.clear()
	open_value = 0.0
	elapsed_sec = 0.0
	_charge_glyph_preset_name = ""
	_lattice_preset_name = ""
	if _prism_particles != null and is_instance_valid(_prism_particles):
		_prism_particles.restart()
	if free_self:
		queue_free()


func has_runtime_assets() -> bool:
	return bool(build_pipeline_status().get("magnetic_fx_texture_pieces_ready", false))


func has_phase2_assets() -> bool:
	return bool(build_pipeline_status().get("magnetic_phase2_fx_texture_pieces_ready", false))


func can_handle_state(next_state: Dictionary) -> bool:
	if bool(next_state.get("projectile_active", false)) or bool(next_state.get("projectile_fade_active", false)):
		return has_phase2_assets()
	return has_runtime_assets()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"process_active": is_processing(),
		"shader_layers": _get_shader_layer_count(),
		"gpu_particle_layers": _get_gpu_particle_layer_count(),
		"texture_pieces_ready": has_runtime_assets(),
		"phase2_texture_pieces_ready": has_phase2_assets(),
		"charge_glyph_png_slot": _is_png_texture_loaded(CHARGE_GLYPH_TEXTURE_PATH, _get_charge_glyph_texture()),
		"lattice_png_slot": _is_png_texture_loaded(LATTICE_TEXTURE_PATH, _get_lattice_texture()),
		"prism_shard_png_slot": _is_png_texture_loaded(PRISM_SHARD_TEXTURE_PATH, _get_prism_shard_texture()),
		"arc_ribbon_png_slot": _is_png_texture_loaded(ARC_RIBBON_TEXTURE_PATH, _get_arc_ribbon_texture()),
		"collapse_burst_png_slot": _is_png_texture_loaded(COLLAPSE_BURST_TEXTURE_PATH, _get_collapse_burst_texture()),
		"projectile_orb_png_slot": _is_png_texture_loaded(PROJECTILE_ORB_TEXTURE_PATH, _get_projectile_orb_texture()),
		"projectile_trail_png_slot": _is_png_texture_loaded(PROJECTILE_TRAIL_TEXTURE_PATH, _get_projectile_trail_texture()),
		"impact_burst_png_slot": _is_png_texture_loaded(IMPACT_BURST_TEXTURE_PATH, _get_impact_burst_texture()),
		"charge_glyph_writhe_shader": WritheEmber.is_material_using_shader(_charge_glyph_material),
		"lattice_writhe_shader": WritheEmber.is_material_using_shader(_lattice_material),
		"charge_glyph_visible": _charge_glyph_sprite != null and _charge_glyph_sprite.visible,
		"phase2_active": bool(_state.get("projectile_active", false)) or bool(_state.get("projectile_fade_active", false)),
		"collapse_burst_visible": _collapse_sprite != null and _collapse_sprite.visible,
		"impact_burst_visible": _impact_burst_sprite != null and _impact_burst_sprite.visible,
		"projectile_orb_visible": _projectile_orb_sprite != null and _projectile_orb_sprite.visible,
		"projectile_trail_visible": _projectile_trail_sprite != null and _projectile_trail_sprite.visible,
		"uses_viewport_layout": abs(scale.x - float(_state.get("render_scale", 1.0))) < 0.001,
}


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _charge_glyph_sprite == null:
		_charge_glyph_sprite = Sprite2D.new()
		_charge_glyph_sprite.name = "PonkMagneticChargeGlyph"
		_charge_glyph_sprite.centered = true
		_charge_glyph_sprite.z_index = -3
		_charge_glyph_sprite.texture = _get_charge_glyph_texture()
		_charge_glyph_material = WritheEmber.build_material("magnetic_charge_glyph")
		_charge_glyph_sprite.material = _charge_glyph_material
		_charge_glyph_sprite.visible = false
		add_child(_charge_glyph_sprite)
		_charge_glyph_preset_name = "magnetic_charge_glyph"
	if _lattice_sprite == null:
		_lattice_sprite = Sprite2D.new()
		_lattice_sprite.name = "PonkMagneticLatticeBackplate"
		_lattice_sprite.centered = true
		_lattice_sprite.z_index = -2
		_lattice_sprite.texture = _get_lattice_texture()
		_lattice_material = WritheEmber.build_material("magnetic_lattice")
		_lattice_sprite.material = _lattice_material
		_lattice_sprite.visible = false
		add_child(_lattice_sprite)
		_lattice_preset_name = "magnetic_lattice"
	if _sheet_sprite == null:
		_sheet_sprite = Sprite2D.new()
		_sheet_sprite.name = "PonkMagneticFieldSheet"
		_sheet_sprite.centered = true
		_sheet_sprite.z_index = -1
		_sheet_sprite.texture = _get_magnetic_sheet_texture()
		_sheet_sprite.region_enabled = true
		_sheet_sprite.material = _additive_material
		_sheet_sprite.visible = false
		add_child(_sheet_sprite)
	while _arc_sprites.size() < ARC_COUNT:
		var arc_sprite := Sprite2D.new()
		arc_sprite.name = "PonkMagneticArcRibbon%d" % (_arc_sprites.size() + 1)
		arc_sprite.centered = true
		arc_sprite.z_index = 0
		arc_sprite.texture = _get_arc_ribbon_texture()
		var arc_material := _build_arc_material()
		arc_sprite.material = arc_material
		arc_sprite.visible = false
		add_child(arc_sprite)
		_arc_sprites.append(arc_sprite)
		_arc_materials.append(arc_material)
	if _prism_particles == null:
		_prism_particles = GPUParticles2D.new()
		_prism_particles.name = "PonkMagneticPrismShardParticles"
		_prism_particles.amount = 72
		_prism_particles.lifetime = 1.12
		_prism_particles.one_shot = false
		_prism_particles.explosiveness = 0.0
		_prism_particles.randomness = 0.88
		_prism_particles.fixed_fps = 60
		_prism_particles.local_coords = true
		_prism_particles.visibility_rect = Rect2(-360.0, -320.0, 720.0, 640.0)
		_prism_particles.texture = _get_prism_shard_texture()
		_prism_particles.material = _additive_material
		_prism_particles.process_material = _build_prism_particle_material()
		_prism_particles.z_index = 0
		_prism_particles.emitting = false
		add_child(_prism_particles)
	if _projectile_trail_sprite == null:
		_projectile_trail_sprite = Sprite2D.new()
		_projectile_trail_sprite.name = "PonkMagneticProjectileTrail"
		_projectile_trail_sprite.centered = true
		_projectile_trail_sprite.z_index = 0
		_projectile_trail_sprite.texture = _get_projectile_trail_texture()
		_projectile_trail_material = _build_projectile_trail_material()
		_projectile_trail_sprite.material = _projectile_trail_material
		_projectile_trail_sprite.visible = false
		add_child(_projectile_trail_sprite)
	if _collapse_sprite == null:
		_collapse_sprite = Sprite2D.new()
		_collapse_sprite.name = "PonkMagneticCollapseBurst"
		_collapse_sprite.centered = true
		_collapse_sprite.z_index = 1
		_collapse_sprite.texture = _get_collapse_burst_texture()
		_collapse_material = _build_collapse_material()
		_collapse_sprite.material = _collapse_material
		_collapse_sprite.visible = false
		add_child(_collapse_sprite)
	if _impact_burst_sprite == null:
		_impact_burst_sprite = Sprite2D.new()
		_impact_burst_sprite.name = "PonkMagneticImpactBurst"
		_impact_burst_sprite.centered = true
		_impact_burst_sprite.z_index = 5
		_impact_burst_sprite.texture = _get_impact_burst_texture()
		_impact_burst_material = _build_collapse_material()
		_impact_burst_sprite.material = _impact_burst_material
		_impact_burst_sprite.visible = false
		add_child(_impact_burst_sprite)
	if _projectile_orb_sprite == null:
		_projectile_orb_sprite = Sprite2D.new()
		_projectile_orb_sprite.name = "PonkMagneticProjectileOrb"
		_projectile_orb_sprite.centered = true
		_projectile_orb_sprite.z_index = 1
		_projectile_orb_sprite.texture = _get_projectile_orb_texture()
		_projectile_orb_material = _build_projectile_orb_material()
		_projectile_orb_sprite.material = _projectile_orb_material
		_projectile_orb_sprite.visible = false
		add_child(_projectile_orb_sprite)


func _apply_state() -> void:
	if _state.is_empty():
		return
	var render_scale: float = maxf(0.001, float(_state.get("render_scale", 1.0)))
	position = _as_vector2(_state.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	scale = Vector2(render_scale, render_scale)

	var boss_center: Vector2 = _get_boss_center()
	var radius: float = maxf(24.0, float(_state.get("radius", NORMAL_RADIUS)))
	var frame: int = int(_state.get("frame", 0)) % MAGNETIC_FIELD_FRAME_COUNT
	var enraged: bool = bool(_state.get("enraged", false))
	var field_active: bool = bool(_state.get("active", false))
	var progress: float = clampf(float(_state.get("progress", 0.0)), 0.0, 1.0)
	var phase2_active: bool = bool(_state.get("projectile_active", false)) or bool(_state.get("projectile_fade_active", false))
	var projectile_elapsed: float = maxf(0.0, float(_state.get("projectile_elapsed", 0.0)))
	var projectile_radius: float = _get_projectile_radius(radius)
	var field_alpha: float = _get_field_alpha(field_active, phase2_active, projectile_elapsed)

	_update_charge_glyph(boss_center, radius, field_active, progress, phase2_active)
	_update_lattice(boss_center, radius, field_alpha, enraged)
	_update_sheet(boss_center, radius, frame, field_alpha)
	_update_arcs(boss_center, radius, field_alpha, enraged)
	_update_prism_particles(boss_center, radius, field_alpha, enraged, field_active)
	_update_collapse_burst(boss_center, radius, projectile_elapsed, phase2_active, enraged)
	_update_projectile(projectile_radius, projectile_elapsed, phase2_active, enraged)
	_update_impact_burst(projectile_radius, enraged)


func _update_charge_glyph(center: Vector2, radius: float, field_active: bool, progress: float, phase2_active: bool) -> void:
	var texture: Texture2D = _get_charge_glyph_texture()
	if _charge_glyph_sprite == null or texture == null:
		return
	var alpha: float = _get_charge_glyph_alpha(progress) if field_active and not phase2_active else 0.0
	_charge_glyph_sprite.visible = alpha > 0.01
	if not _charge_glyph_sprite.visible:
		return
	var texture_size: Vector2 = texture.get_size()
	var collapse_t: float = _smoothstep(0.12, CHARGE_GLYPH_OUT_PROGRESS, progress)
	var draw_size: float = radius * 2.05 * lerpf(0.60, 0.12, collapse_t) * (0.92 + open_value * 0.08)
	_charge_glyph_sprite.position = center
	_charge_glyph_sprite.rotation = elapsed_sec * 1.5
	_charge_glyph_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_charge_glyph_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _charge_glyph_material != null:
		if _charge_glyph_preset_name != "magnetic_charge_glyph":
			WritheEmber.apply_preset(_charge_glyph_material, "magnetic_charge_glyph")
			_charge_glyph_preset_name = "magnetic_charge_glyph"
		_charge_glyph_material.set_shader_parameter("elapsed", elapsed_sec)
		_charge_glyph_material.set_shader_parameter("intensity", clampf(alpha * (1.0 + open_value * 0.22), 0.0, 1.2))


func _update_lattice(center: Vector2, radius: float, alpha: float, enraged: bool) -> void:
	var texture: Texture2D = _get_lattice_texture()
	if _lattice_sprite == null or texture == null:
		return
	_lattice_sprite.visible = alpha > 0.01
	if not _lattice_sprite.visible:
		return
	var draw_size: float = radius * (2.48 + (0.16 if enraged else 0.0)) * (0.82 + open_value * 0.18)
	var texture_size: Vector2 = texture.get_size()
	_lattice_sprite.position = center
	_lattice_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_lattice_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _lattice_material != null:
		var preset_name := "magnetic_lattice_enraged" if enraged else "magnetic_lattice"
		if preset_name != _lattice_preset_name:
			WritheEmber.apply_preset(_lattice_material, preset_name)
			_lattice_preset_name = preset_name
		_lattice_material.set_shader_parameter("elapsed", elapsed_sec)
		_lattice_material.set_shader_parameter("intensity", clampf(alpha * (1.05 if enraged else 0.92), 0.0, 1.45))


func _update_sheet(center: Vector2, radius: float, frame: int, alpha: float) -> void:
	var texture: Texture2D = _get_magnetic_sheet_texture()
	if _sheet_sprite == null or texture == null:
		return
	_sheet_sprite.visible = alpha > 0.01
	if not _sheet_sprite.visible:
		return
	var sheet_size: Vector2 = texture.get_size()
	var cell_size := Vector2(sheet_size.x / float(MAGNETIC_FIELD_COLS), sheet_size.y / float(MAGNETIC_FIELD_ROWS))
	var col: int = frame % MAGNETIC_FIELD_COLS
	var row: int = int(floor(float(frame) / float(MAGNETIC_FIELD_COLS))) % MAGNETIC_FIELD_ROWS
	var draw_size: float = radius * 2.72 * (0.90 + open_value * 0.10)
	_sheet_sprite.position = center
	_sheet_sprite.region_rect = Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)
	_sheet_sprite.scale = Vector2(draw_size / maxf(1.0, cell_size.x), draw_size / maxf(1.0, cell_size.y))
	_sheet_sprite.modulate = Color(0.82, 1.0, 1.0, alpha * 0.78)


func _update_arcs(center: Vector2, radius: float, alpha: float, enraged: bool) -> void:
	var texture: Texture2D = _get_arc_ribbon_texture()
	if texture == null:
		return
	var visible_arcs := alpha > 0.01
	var texture_size: Vector2 = texture.get_size()
	var rotation_speed: float = 0.72 * (1.5 if enraged else 1.0)
	var draw_size: float = radius * 2.58 * 0.85 * (0.96 + 0.05 * sin(elapsed_sec * 4.0))
	for idx in range(_arc_sprites.size()):
		var arc_sprite: Sprite2D = _arc_sprites[idx]
		arc_sprite.visible = visible_arcs
		if not visible_arcs:
			continue
		arc_sprite.position = center
		arc_sprite.rotation = elapsed_sec * rotation_speed + float(idx) * TAU / float(ARC_COUNT)
		arc_sprite.scale = Vector2(
			draw_size * (1.0 + 0.045 * sin(elapsed_sec * 3.3 + float(idx))) / maxf(1.0, texture_size.x),
			draw_size * 0.90 / maxf(1.0, texture_size.y)
		)
		arc_sprite.modulate = Color(1.0, 1.0, 1.0, alpha * (0.62 + 0.10 * float(idx == 0)))
		if idx < _arc_materials.size() and _arc_materials[idx] != null:
			_arc_materials[idx].set_shader_parameter("elapsed", elapsed_sec)
			_arc_materials[idx].set_shader_parameter("alpha_scale", alpha)
			_arc_materials[idx].set_shader_parameter("enraged", 1.0 if enraged else 0.0)
			_arc_materials[idx].set_shader_parameter("phase_offset", float(idx) * 0.21)


func _update_prism_particles(center: Vector2, radius: float, alpha: float, enraged: bool, field_active: bool) -> void:
	if _prism_particles == null:
		return
	_prism_particles.position = center
	_prism_particles.amount = 108 if enraged else 72
	_prism_particles.emitting = field_active and alpha > 0.04
	var prism_mat: ParticleProcessMaterial = _prism_particles.process_material
	if prism_mat != null:
		prism_mat.emission_ring_radius = radius * 0.94
		prism_mat.emission_ring_inner_radius = radius * 0.68
		prism_mat.initial_velocity_min = 18.0 * (1.35 if enraged else 1.0)
		prism_mat.initial_velocity_max = 86.0 * (1.35 if enraged else 1.0)
		prism_mat.radial_accel_min = 38.0 * (1.35 if enraged else 1.0)
		prism_mat.radial_accel_max = 128.0 * (1.35 if enraged else 1.0)
		prism_mat.scale_min = 0.022 if not enraged else 0.028
		prism_mat.scale_max = 0.074 if not enraged else 0.092
		prism_mat.color = Color(0.42, 0.96, 1.0, alpha * (0.54 + (0.18 if enraged else 0.0)))


func _update_collapse_burst(center: Vector2, radius: float, projectile_elapsed: float, phase2_active: bool, enraged: bool) -> void:
	var texture: Texture2D = _get_collapse_burst_texture()
	if _collapse_sprite == null or texture == null:
		return
	var alpha: float = _get_collapse_burst_alpha(projectile_elapsed) if phase2_active else 0.0
	_collapse_sprite.visible = alpha > 0.01
	if not _collapse_sprite.visible:
		return
	var texture_size: Vector2 = texture.get_size()
	var peak_scale: float = 1.5 if enraged else 1.2
	var scale_progress: float = _ease_out_cubic(clampf(projectile_elapsed / 0.30, 0.0, 1.0))
	var collapse_scale: float = lerpf(0.40, peak_scale, scale_progress)
	var draw_size: float = radius * 2.62 * collapse_scale
	_collapse_sprite.position = center
	_collapse_sprite.rotation = -projectile_elapsed * 3.0
	_collapse_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_collapse_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _collapse_material != null:
		_collapse_material.set_shader_parameter("elapsed", elapsed_sec)
		_collapse_material.set_shader_parameter("alpha_scale", alpha)
		_collapse_material.set_shader_parameter("enraged", 1.0 if enraged else 0.0)


func _update_projectile(radius: float, projectile_elapsed: float, phase2_active: bool, enraged: bool) -> void:
	var projectile_pos: Vector2 = _get_projectile_pos()
	var projectile_velocity: Vector2 = _get_projectile_velocity()
	var fade_ratio: float = _get_projectile_fade_ratio()
	var orb_alpha: float = _get_projectile_orb_alpha(projectile_elapsed) * fade_ratio if phase2_active else 0.0
	var trail_alpha: float = _get_projectile_trail_alpha(projectile_elapsed) * fade_ratio if phase2_active else 0.0
	_update_projectile_trail(projectile_pos, projectile_velocity, radius, trail_alpha, enraged)
	_update_projectile_orb(projectile_pos, radius, orb_alpha, enraged)


func _update_projectile_orb(center: Vector2, radius: float, alpha: float, enraged: bool) -> void:
	var texture: Texture2D = _get_projectile_orb_texture()
	if _projectile_orb_sprite == null or texture == null:
		return
	_projectile_orb_sprite.visible = alpha > 0.01
	if not _projectile_orb_sprite.visible:
		return
	var texture_size: Vector2 = texture.get_size()
	var breath_amp: float = 0.25 if enraged else 0.15
	var breath: float = 1.0 + breath_amp * (0.5 + 0.5 * sin(elapsed_sec * 8.0))
	var draw_size: float = radius * 1.62 * breath
	_projectile_orb_sprite.position = center
	_projectile_orb_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_projectile_orb_sprite.modulate = Color(1.2 if enraged else 1.0, 1.0, 1.0, alpha)
	if _projectile_orb_material != null:
		_projectile_orb_material.set_shader_parameter("elapsed", elapsed_sec)
		_projectile_orb_material.set_shader_parameter("alpha_scale", alpha)
		_projectile_orb_material.set_shader_parameter("enraged", 1.0 if enraged else 0.0)


func _update_projectile_trail(center: Vector2, velocity: Vector2, radius: float, alpha: float, enraged: bool) -> void:
	var texture: Texture2D = _get_projectile_trail_texture()
	if _projectile_trail_sprite == null or texture == null:
		return
	_projectile_trail_sprite.visible = alpha > 0.01
	if not _projectile_trail_sprite.visible:
		return
	var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.001 else Vector2.DOWN
	var trail_length_scale: float = 1.3 if enraged else 1.0
	var texture_size: Vector2 = texture.get_size()
	var trail_size := Vector2(radius * 3.80 * trail_length_scale, radius * 1.55)
	_projectile_trail_sprite.position = center - direction * trail_size.x * 0.36
	_projectile_trail_sprite.rotation = direction.angle()
	_projectile_trail_sprite.scale = Vector2(trail_size.x / maxf(1.0, texture_size.x), trail_size.y / maxf(1.0, texture_size.y))
	_projectile_trail_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _projectile_trail_material != null:
		_projectile_trail_material.set_shader_parameter("elapsed", elapsed_sec)
		_projectile_trail_material.set_shader_parameter("alpha_scale", alpha)
		_projectile_trail_material.set_shader_parameter("enraged", 1.0 if enraged else 0.0)


func _update_impact_burst(radius: float, enraged: bool) -> void:
	var texture: Texture2D = _get_impact_burst_texture()
	if _impact_burst_sprite == null or texture == null:
		return
	var fade_active: bool = bool(_state.get("projectile_fade_active", false)) and not bool(_state.get("projectile_active", false))
	var fade_total: float = maxf(0.001, float(_state.get("projectile_fade_total", 0.15)))
	var fade_timer: float = clampf(float(_state.get("projectile_fade_timer", 0.0)), 0.0, fade_total)
	var impact_elapsed: float = fade_total - fade_timer
	var alpha: float = _get_impact_burst_alpha(impact_elapsed) if fade_active else 0.0
	_impact_burst_sprite.visible = alpha > 0.01
	if not _impact_burst_sprite.visible:
		return
	var texture_size: Vector2 = texture.get_size()
	var impact_pos: Vector2 = _get_projectile_pos()
	var peak_scale: float = 1.8 if enraged else 1.6
	var scale_progress: float = _ease_out_cubic(clampf(impact_elapsed / 0.30, 0.0, 1.0))
	var draw_size: float = radius * 2.18 * lerpf(0.30, peak_scale, scale_progress)
	_impact_burst_sprite.position = impact_pos
	_impact_burst_sprite.rotation = impact_elapsed * 5.8
	_impact_burst_sprite.scale = Vector2(draw_size / maxf(1.0, texture_size.x), draw_size / maxf(1.0, texture_size.y))
	_impact_burst_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	if _impact_burst_material != null:
		_impact_burst_material.set_shader_parameter("elapsed", elapsed_sec)
		_impact_burst_material.set_shader_parameter("alpha_scale", alpha)
		_impact_burst_material.set_shader_parameter("enraged", 1.0 if enraged else 0.0)


func _start_open_tween() -> void:
	if not is_inside_tree():
		open_value = 1.0
		return
	_stop_open_tween()
	open_value = 0.0
	_open_tween = create_tween()
	_open_tween.tween_property(self, "open_value", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_open_tween() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null


func _get_boss_center() -> Vector2:
	return _as_vector2(_state.get("boss_center", Vector2(380.0, 78.0)), Vector2(380.0, 78.0)) + _as_vector2(_state.get("shake_offset", Vector2.ZERO), Vector2.ZERO)


func _get_projectile_pos() -> Vector2:
	var fallback: Vector2 = _as_vector2(_state.get("projectile_pos", Vector2(380.0, 78.0)), Vector2(380.0, 78.0))
	if bool(_state.get("projectile_fade_active", false)) and not bool(_state.get("projectile_active", false)):
		fallback = _as_vector2(_state.get("projectile_fade_pos", fallback), fallback)
	return fallback + _as_vector2(_state.get("shake_offset", Vector2.ZERO), Vector2.ZERO)


func _get_projectile_velocity() -> Vector2:
	var fallback := Vector2.DOWN
	if bool(_state.get("projectile_fade_active", false)) and not bool(_state.get("projectile_active", false)):
		return _as_vector2(_state.get("projectile_fade_velocity", fallback), fallback)
	return _as_vector2(_state.get("projectile_velocity", fallback), fallback)


func _get_projectile_radius(fallback: float) -> float:
	if bool(_state.get("projectile_fade_active", false)) and not bool(_state.get("projectile_active", false)):
		return maxf(12.0, float(_state.get("projectile_fade_radius", fallback)))
	return maxf(12.0, float(_state.get("projectile_radius", fallback)))


func _get_projectile_fade_ratio() -> float:
	if not bool(_state.get("projectile_fade_active", false)):
		return 1.0
	return clampf(float(_state.get("projectile_fade_timer", 0.0)) / maxf(0.001, float(_state.get("projectile_fade_total", 0.15))), 0.0, 1.0)


func _get_field_alpha(field_active: bool, phase2_active: bool, projectile_elapsed: float) -> float:
	if not field_active and phase2_active:
		return clampf(1.0 - _smoothstep(0.0, 0.30, projectile_elapsed), 0.0, 1.0)
	if not field_active:
		return 0.0
	var progress: float = clampf(float(_state.get("progress", 0.0)), 0.0, 1.0)
	var intro: float = _smoothstep(0.0, 0.12, progress)
	var outro: float = 1.0 - _smoothstep(0.88, 1.0, progress)
	var breath: float = 0.78 + 0.22 * sin(elapsed_sec * 6.0)
	return clampf(intro * outro * breath * (0.72 + open_value * 0.28), 0.0, 1.0)


func _get_collapse_burst_alpha(projectile_elapsed: float) -> float:
	if projectile_elapsed < 0.0:
		return 0.0
	if projectile_elapsed < COLLAPSE_BURST_IN_SECONDS:
		return _smoothstep(0.0, COLLAPSE_BURST_IN_SECONDS, projectile_elapsed)
	var hold_end: float = COLLAPSE_BURST_IN_SECONDS + COLLAPSE_BURST_HOLD_SECONDS
	if projectile_elapsed < hold_end:
		return 1.0
	var out_end: float = hold_end + COLLAPSE_BURST_OUT_SECONDS
	if projectile_elapsed < out_end:
		return 1.0 - _smoothstep(hold_end, out_end, projectile_elapsed)
	return 0.0


func _get_projectile_orb_alpha(projectile_elapsed: float) -> float:
	return _smoothstep(PROJECTILE_ORB_IN_START_SECONDS, PROJECTILE_ORB_IN_START_SECONDS + PROJECTILE_ORB_IN_SECONDS, projectile_elapsed)


func _get_projectile_trail_alpha(projectile_elapsed: float) -> float:
	return _smoothstep(PROJECTILE_TRAIL_START_SECONDS, PROJECTILE_TRAIL_START_SECONDS + 0.10, projectile_elapsed)


func _get_charge_glyph_alpha(progress: float) -> float:
	if progress < 0.08:
		return _smoothstep(0.0, 0.08, progress)
	if progress < 0.14:
		return 1.0
	if progress < CHARGE_GLYPH_OUT_PROGRESS:
		return 1.0 - _smoothstep(0.14, CHARGE_GLYPH_OUT_PROGRESS, progress)
	return 0.0


func _get_impact_burst_alpha(impact_elapsed: float) -> float:
	if impact_elapsed < 0.0:
		return 0.0
	if impact_elapsed < IMPACT_BURST_IN_SECONDS:
		return _smoothstep(0.0, IMPACT_BURST_IN_SECONDS, impact_elapsed)
	var hold_end: float = IMPACT_BURST_IN_SECONDS + IMPACT_BURST_HOLD_SECONDS
	if impact_elapsed < hold_end:
		return 1.0
	var out_end: float = hold_end + IMPACT_BURST_OUT_SECONDS
	if impact_elapsed < out_end:
		return 1.0 - _smoothstep(hold_end, out_end, impact_elapsed)
	return 0.0


func _get_shader_layer_count() -> int:
	var count := 0
	if _charge_glyph_material != null:
		count += 1
	if _lattice_material != null:
		count += 1
	@warning_ignore("shadowed_variable_base_class")
	for material in _arc_materials:
		if material != null:
			count += 1
	@warning_ignore("shadowed_variable_base_class")
	for material in [_collapse_material, _projectile_orb_material, _projectile_trail_material, _impact_burst_material]:
		if material != null:
			count += 1
	return count


func _get_gpu_particle_layer_count() -> int:
	return 1 if _prism_particles != null else 0


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_lattice_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_lattice_shader()
	return material


static func _build_arc_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_arc_shader()
	return material


static func _build_collapse_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_collapse_shader()
	return material


static func _build_projectile_orb_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_projectile_orb_shader()
	return material


static func _build_projectile_trail_material() -> ShaderMaterial:
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = _get_projectile_trail_shader()
	return material


static func _get_lattice_shader() -> Shader:
	if _lattice_shader != null:
		return _lattice_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float alpha_scale = 1.0;
uniform float enraged = 0.0;
uniform float open_value = 1.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float angle = elapsed * 0.4 * mix(1.0, 1.5, enraged);
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated = vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + vec2(0.5);
	float bounds = step(0.0, rotated.x) * step(rotated.x, 1.0) * step(0.0, rotated.y) * step(rotated.y, 1.0);
	vec2 uv = clamp(rotated, vec2(0.0), vec2(1.0));
	vec2 dir = normalize(centered + vec2(0.0001));
	float chroma = 0.010 + enraged * 0.008;
	vec4 tex = texture(TEXTURE, uv);
	vec4 red = texture(TEXTURE, clamp(uv + dir * chroma, vec2(0.0), vec2(1.0)));
	vec4 blue = texture(TEXTURE, clamp(uv - dir * chroma, vec2(0.0), vec2(1.0)));
	tex.r = max(tex.r, red.r * 0.92);
	tex.b = max(tex.b, blue.b * 1.08);
	float breath = 0.60 + 0.40 * (0.5 + 0.5 * sin(elapsed * 6.0));
	float pulse_boost = mix(1.0, 1.30, enraged);
	float alpha = tex.a * bounds * alpha_scale * breath * pulse_boost * (0.78 + open_value * 0.22);
	vec3 color = tex.rgb;
	color = mix(color, vec3(0.70, 1.0, 1.0), 0.08 + enraged * 0.06);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.94));
}
"""
	_lattice_shader = shader
	return _lattice_shader


static func _get_arc_shader() -> Shader:
	if _arc_shader != null:
		return _arc_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float alpha_scale = 1.0;
uniform float enraged = 0.0;
uniform float phase_offset = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + elapsed * mix(0.50, 0.72, enraged) + phase_offset);
	vec4 tex = texture(TEXTURE, uv);
	float breath = 0.62 + 0.38 * (0.5 + 0.5 * sin(elapsed * 5.6 + phase_offset * 6.28318));
	float alpha = tex.a * alpha_scale * breath * mix(0.88, 1.18, enraged);
	vec3 color = tex.rgb;
	color = mix(color, vec3(0.62, 0.96, 1.0), 0.06);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.88));
}
"""
	_arc_shader = shader
	return _arc_shader


static func _get_collapse_shader() -> Shader:
	if _collapse_shader != null:
		return _collapse_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float alpha_scale = 1.0;
uniform float enraged = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 dir = normalize(centered + vec2(0.0001));
	float chroma = 0.014 + enraged * 0.010;
	vec2 red_uv = clamp(UV + dir * chroma, vec2(0.0), vec2(1.0));
	vec2 blue_uv = clamp(UV - dir * chroma, vec2(0.0), vec2(1.0));
	vec4 tex = texture(TEXTURE, UV);
	vec4 red = texture(TEXTURE, red_uv);
	vec4 blue = texture(TEXTURE, blue_uv);
	tex.r = max(tex.r, red.r * 1.02);
	tex.b = max(tex.b, blue.b * 1.10);
	float pulse = 0.88 + 0.12 * sin(elapsed * 18.0);
	COLOR = vec4(tex.rgb, clamp(tex.a * alpha_scale * pulse * mix(1.0, 1.22, enraged), 0.0, 0.96));
}
"""
	_collapse_shader = shader
	return _collapse_shader


static func _get_projectile_orb_shader() -> Shader:
	if _projectile_orb_shader != null:
		return _projectile_orb_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float alpha_scale = 1.0;
uniform float enraged = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float angle = elapsed * mix(1.5, 2.25, enraged);
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated = vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + vec2(0.5);
	float bounds = step(0.0, rotated.x) * step(rotated.x, 1.0) * step(0.0, rotated.y) * step(rotated.y, 1.0);
	vec4 tex = texture(TEXTURE, clamp(rotated, vec2(0.0), vec2(1.0)));
	float breath = 0.85 + mix(0.15, 0.25, enraged) * (0.5 + 0.5 * sin(elapsed * 8.0));
	vec3 color = tex.rgb;
	color.r *= mix(1.0, 1.2, enraged);
	COLOR = vec4(color, clamp(tex.a * bounds * alpha_scale * breath, 0.0, 0.94));
}
"""
	_projectile_orb_shader = shader
	return _projectile_orb_shader


static func _get_projectile_trail_shader() -> Shader:
	if _projectile_trail_shader != null:
		return _projectile_trail_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float alpha_scale = 1.0;
uniform float enraged = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + elapsed * mix(0.80, 1.10, enraged));
	vec4 tex = texture(TEXTURE, uv);
	float fade = smoothstep(0.02, 0.16, UV.x) * (1.0 - smoothstep(0.96, 1.0, UV.x));
	COLOR = vec4(tex.rgb, clamp(tex.a * fade * alpha_scale * mix(0.90, 1.12, enraged), 0.0, 0.88));
}
"""
	_projectile_trail_shader = shader
	return _projectile_trail_shader


static func _build_prism_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 86.0
	mat.radial_accel_min = 38.0
	mat.radial_accel_max = 128.0
	mat.tangential_accel_min = -140.0
	mat.tangential_accel_max = 140.0
	mat.angular_velocity_min = -115.0
	mat.angular_velocity_max = 115.0
	mat.damping_min = 16.0
	mat.damping_max = 58.0
	mat.scale_min = 0.022
	mat.scale_max = 0.074
	mat.color = Color(0.42, 0.96, 1.0, 0.62)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = NORMAL_RADIUS * 0.94
	mat.emission_ring_inner_radius = NORMAL_RADIUS * 0.68
	mat.emission_ring_height = 0.0
	return mat


static func _get_magnetic_sheet_texture() -> Texture2D:
	if _magnetic_sheet_texture != null:
		return _magnetic_sheet_texture
	_magnetic_sheet_texture = ProjectResourceLoader.load_texture(MAGNETIC_FIELD_SHEET_PATH)
	return _magnetic_sheet_texture


static func _get_charge_glyph_texture() -> Texture2D:
	if _charge_glyph_texture != null:
		return _charge_glyph_texture
	_charge_glyph_texture = ProjectResourceLoader.load_texture(CHARGE_GLYPH_TEXTURE_PATH)
	return _charge_glyph_texture


static func _get_lattice_texture() -> Texture2D:
	if _lattice_texture != null:
		return _lattice_texture
	_lattice_texture = ProjectResourceLoader.load_texture(LATTICE_TEXTURE_PATH)
	return _lattice_texture


static func _get_prism_shard_texture() -> Texture2D:
	if _prism_shard_texture != null:
		return _prism_shard_texture
	_prism_shard_texture = ProjectResourceLoader.load_texture(PRISM_SHARD_TEXTURE_PATH)
	return _prism_shard_texture


static func _get_arc_ribbon_texture() -> Texture2D:
	if _arc_ribbon_texture != null:
		return _arc_ribbon_texture
	_arc_ribbon_texture = ProjectResourceLoader.load_texture(ARC_RIBBON_TEXTURE_PATH)
	return _arc_ribbon_texture


static func _get_collapse_burst_texture() -> Texture2D:
	if _collapse_burst_texture != null:
		return _collapse_burst_texture
	_collapse_burst_texture = ProjectResourceLoader.load_texture(COLLAPSE_BURST_TEXTURE_PATH)
	return _collapse_burst_texture


static func _get_projectile_orb_texture() -> Texture2D:
	if _projectile_orb_texture != null:
		return _projectile_orb_texture
	_projectile_orb_texture = ProjectResourceLoader.load_texture(PROJECTILE_ORB_TEXTURE_PATH)
	return _projectile_orb_texture


static func _get_projectile_trail_texture() -> Texture2D:
	if _projectile_trail_texture != null:
		return _projectile_trail_texture
	_projectile_trail_texture = ProjectResourceLoader.load_texture(PROJECTILE_TRAIL_TEXTURE_PATH)
	return _projectile_trail_texture


static func _get_impact_burst_texture() -> Texture2D:
	if _impact_burst_texture != null:
		return _impact_burst_texture
	var loaded: Texture2D = ProjectResourceLoader.load_texture(IMPACT_BURST_TEXTURE_PATH)
	if loaded != null:
		_impact_burst_texture = loaded
		return _impact_burst_texture
	_impact_burst_texture = _get_collapse_burst_texture()
	return _impact_burst_texture


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
