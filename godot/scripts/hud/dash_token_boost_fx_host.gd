extends Node2D

# Dash orb boost-state shader overlay host.
#
# Replaces three heavy CPU canvas.draw_* paths on the dash orb with a single
# GPU shader quad per visible boost state:
#   * _draw_boost_charging_dash_sector  (pillar_dash_token_fill_renderer.gd, line ~198)
#   * _draw_boost_charging_rainbow_ring (pillar_dash_orb_renderer.gd, line ~148)
#   * "HALF" ready pulse glow (drawn additively underneath the existing CPU "HALF" label)
#
# The host owns a fixed pool of Sprite2D + ShaderMaterial slots (player dash +
# boss dash + room for future overlays). Each call to `sync_slot(...)` claims
# the next slot in the current frame; `end_frame()` hides any leftover slots
# from the previous frame. The renderer chain calls `begin_frame()` once per
# frame before issuing dash orb draws.

const BOOST_SHADER := preload("res://shaders/hud/dash_token_boost_ring.gdshader")

const MAX_SLOTS := 4
# Quad half-size is orb_radius * QUAD_RADIUS_FACTOR. Must be large enough to
# contain the rainbow ring band sitting just outside orb_radius.
const QUAD_RADIUS_FACTOR := 1.5
# Z above orb body + token (canvas z 0) so the additive overlay sits on top.
const HOST_Z_INDEX := 6

static var _prewarmed: bool = false
static var _shader_ready: bool = false
static var _white_texture: Texture2D = null

var _slots: Array[Sprite2D] = []
var _slot_count: int = 0
var _frame_slot_index: int = 0


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_shader_ready = BOOST_SHADER is Shader
	_get_or_create_white_texture()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"dash_token_boost_ring_shader_ready": _shader_ready,
		"dash_token_boost_ring_max_slots": MAX_SLOTS,
		"dash_token_boost_ring_white_texture_ready": _white_texture != null,
	}


static func _get_or_create_white_texture() -> Texture2D:
	if _white_texture != null:
		return _white_texture
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(img)
	return _white_texture


func _ready() -> void:
	z_as_relative = false
	z_index = HOST_Z_INDEX
	_build_slot_pool()


func begin_frame() -> void:
	_frame_slot_index = 0


func sync_slot(center: Vector2, orb_radius: float, scale_factor: float, state: Dictionary) -> void:
	if _slot_count == 0:
		_build_slot_pool()
	if _frame_slot_index >= _slot_count:
		return
	var slot: Sprite2D = _slots[_frame_slot_index]
	if slot == null:
		return
	var mat: ShaderMaterial = slot.material as ShaderMaterial
	_apply_slot(slot, mat, center, orb_radius, scale_factor, state)
	_frame_slot_index += 1


func end_frame() -> void:
	for i in range(_frame_slot_index, _slot_count):
		var slot: Sprite2D = _slots[i]
		if slot != null:
			slot.visible = false


func set_active(value: bool) -> void:
	visible = value
	if not value:
		for slot in _slots:
			if slot != null:
				slot.visible = false


func tear_down(deferred: bool = true) -> void:
	if deferred:
		queue_free()
	else:
		free()


func _build_slot_pool() -> void:
	if _slot_count > 0:
		return
	var tex: Texture2D = _get_or_create_white_texture()
	for i in range(MAX_SLOTS):
		var slot := Sprite2D.new()
		slot.name = "BoostSlot%d" % i
		slot.texture = tex
		slot.centered = true
		slot.visible = false
		var mat := ShaderMaterial.new()
		mat.shader = BOOST_SHADER
		slot.material = mat
		add_child(slot)
		_slots.append(slot)
	_slot_count = MAX_SLOTS


func _apply_slot(
	slot: Sprite2D,
	mat: ShaderMaterial,
	center: Vector2,
	orb_radius: float,
	_scale_factor: float,
	state: Dictionary
) -> void:
	var sector_intensity: float = clamp(float(state.get("sector_intensity", 0.0)), 0.0, 1.0)
	var rainbow_intensity: float = clamp(float(state.get("rainbow_intensity", 0.0)), 0.0, 1.0)
	var half_ready_intensity: float = clamp(float(state.get("half_ready_intensity", 0.0)), 0.0, 1.0)
	var plasma_ball_intensity: float = clamp(float(state.get("plasma_ball_intensity", 0.0)), 0.0, 1.0)
	var any_intensity := sector_intensity + rainbow_intensity + half_ready_intensity + plasma_ball_intensity
	if any_intensity <= 0.001:
		slot.visible = false
		return
	slot.visible = true
	slot.position = center
	var quad_size: float = max(8.0, orb_radius) * QUAD_RADIUS_FACTOR * 2.0
	var tex: Texture2D = slot.texture
	var tex_w: float = float(tex.get_width()) if tex != null else 4.0
	if tex_w > 0.0:
		slot.scale = Vector2.ONE * (quad_size / tex_w)
	if mat == null:
		return
	mat.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
	mat.set_shader_parameter("orb_radius_norm", 1.0 / QUAD_RADIUS_FACTOR)
	mat.set_shader_parameter("outer_extent_norm", 1.0)
	mat.set_shader_parameter("sector_intensity", sector_intensity)
	mat.set_shader_parameter("sector_progress", float(state.get("sector_progress", 0.0)))
	mat.set_shader_parameter("sector_start_angle", float(state.get("sector_start_angle", 0.0)))
	mat.set_shader_parameter("sector_end_angle", float(state.get("sector_end_angle", TAU)))
	mat.set_shader_parameter("rainbow_intensity", rainbow_intensity)
	mat.set_shader_parameter("rainbow_rotation", float(state.get("rainbow_rotation", 0.0)))
	mat.set_shader_parameter("half_ready_intensity", half_ready_intensity)
	mat.set_shader_parameter("plasma_ball_intensity", plasma_ball_intensity)
	var base_color: Variant = state.get("base_token_color", Color(0.98, 0.46, 0.36, 1.0))
	if base_color is Color:
		mat.set_shader_parameter("base_token_color", base_color)
	var plasma_core_color: Variant = state.get("plasma_core_color", Color(1.0, 0.86, 1.0, 1.0))
	if plasma_core_color is Color:
		mat.set_shader_parameter("plasma_core_color", plasma_core_color)
	var plasma_tendril_color: Variant = state.get("plasma_tendril_color", Color(0.96, 0.40, 1.0, 1.0))
	if plasma_tendril_color is Color:
		mat.set_shader_parameter("plasma_tendril_color", plasma_tendril_color)
	var plasma_tendril_count: int = clamp(int(state.get("plasma_tendril_count", 5)), 2, 8)
	mat.set_shader_parameter("plasma_tendril_count", plasma_tendril_count)
