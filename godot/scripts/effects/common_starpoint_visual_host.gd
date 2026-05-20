extends Node2D

# Shared starpoint-drop shader overlay host. One slot per active drop; each
# slot is a Sprite2D + ShaderMaterial that the per-stage `_draw_starpoint_drops`
# function fills via `sync_drop(state)` after `begin_frame()`. After all drops
# are synced for the frame the caller invokes `end_frame()` to hide any slots
# that the previous frame had claimed but this frame did not.
#
# This replaces four near-identical CPU loops in:
#   stage1_balloon_event.gd:_draw_starpoint_drops
#   stage2_pillar_obstacle_visual_renderer.gd:draw_starpoint_drops
#   stage3_menhera_skill_effect_renderer.gd:_draw_starpoint_drops
#   stage4_bird_event.gd:_draw_starpoint_drops
# The CPU paths remain as a runtime fallback for early-boot frames before the
# deferred add_child lands and for headless tests where no scene tree exists.

const STARPOINT_SHADER := preload("res://shaders/playfield/starpoint_drop.gdshader")

const HOST_NAME := "CommonStarpointVisualHost"
# Max simultaneous active drops across all stages. Most stages keep ~10 active
# at peak; 32 leaves headroom for treasure-hunt / mythic bursts.
const MAX_SLOTS := 32
# Quad half-size = drop size * QUAD_SIZE_FACTOR so the outermost glow layer
# (size * 4.0 in the original CPU code) still fits inside the quad.
const QUAD_SIZE_FACTOR := 4.0
# Z above the pillar background and obstacle layer; below ball / paddle.
const HOST_Z_INDEX := 12

static var _prewarmed: bool = false
static var _shader_ready: bool = false
static var _white_texture: Texture2D = null
# Pending pointer is shared across all per-stage callers; only the single
# active stage's renderer reaches this code on any given frame, so a single
# static slot is enough to dedupe the deferred add_child gap.
static var _pending_host: Node = null

var _slots: Array[Sprite2D] = []
var _slot_count: int = 0
var _frame_slot_index: int = 0


# Resource prewarm path: ensures the shader resource is loaded and the shared
# 4x4 white texture is built before any stage's draw frame tries to push a slot.
static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_shader_ready = STARPOINT_SHADER is Shader
	_get_or_create_white_texture()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"common_starpoint_drop_shader_ready": _shader_ready,
		"common_starpoint_drop_max_slots": MAX_SLOTS,
		"common_starpoint_drop_white_texture_ready": _white_texture != null,
	}


static func _get_or_create_white_texture() -> Texture2D:
	if _white_texture != null:
		return _white_texture
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(img)
	return _white_texture


# Per-stage callers look up the host via this factory rather than tracking the
# Node themselves. The pattern mirrors stage5_hongryun_inferno_charge_fx_host /
# pillar_dash_token_boost_fx_host: try a parent.get_node_or_null cache, fall
# back to a static pending pointer that bridges the deferred add_child gap,
# and only create a fresh host when nothing else exists.
static func get_or_create_on_canvas(canvas: CanvasItem) -> Node:
	if canvas == null or not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_pending_host = null
		return existing
	if _pending_host != null and is_instance_valid(_pending_host) and not _pending_host.is_queued_for_deletion():
		return _pending_host
	# Preloading the same script we're in would cause a circular dep at parse
	# time; using load() inside the factory is cheap (script cache hits) and
	# matches the convention seen across other FX hosts that defer this to
	# runtime.
	var host: Node = load("res://scripts/effects/common_starpoint_visual_host.gd").new()
	host.name = HOST_NAME
	_pending_host = host
	parent.call_deferred("add_child", host)
	return host


func _ready() -> void:
	z_as_relative = false
	z_index = HOST_Z_INDEX
	_build_slot_pool()


func begin_frame() -> void:
	_frame_slot_index = 0


# Push one drop's render state into the next free slot. `state` keys:
#   "pos" (Vector2, world space), "size" (float, star outer radius in px),
#   "life" (float, raw life counter, alpha = clamp(life * 2 / 255, 0, 1)),
#   "rotation" (float, radians), "glow_intensity" (float, 0..1),
#   "star_detector_bonus" (bool), "glow_color" / "fill_color" / "outline_color"
#   (Color, per-stage palette overrides), "elapsed" (float, seconds for shimmer).
func sync_drop(state: Dictionary) -> void:
	if _slot_count == 0:
		_build_slot_pool()
	if _frame_slot_index >= _slot_count:
		return
	var slot: Sprite2D = _slots[_frame_slot_index]
	if slot == null:
		return
	var mat: ShaderMaterial = slot.material as ShaderMaterial
	_apply_slot(slot, mat, state)
	_frame_slot_index += 1


func end_frame() -> void:
	for i in range(_frame_slot_index, _slot_count):
		var slot: Sprite2D = _slots[i]
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
		slot.name = "StarpointSlot%d" % i
		slot.texture = tex
		slot.centered = true
		slot.visible = false
		var mat := ShaderMaterial.new()
		mat.shader = STARPOINT_SHADER
		slot.material = mat
		add_child(slot)
		_slots.append(slot)
	_slot_count = MAX_SLOTS


func _apply_slot(slot: Sprite2D, mat: ShaderMaterial, state: Dictionary) -> void:
	var pos: Vector2 = _as_vector2(state.get("pos", Vector2.ZERO))
	var size: float = max(1.0, float(state.get("size", 12.0)))
	var raw_life: float = float(state.get("life", 0.0))
	var alpha: float = clampf(raw_life * 2.0 / 255.0, 0.0, 1.0)
	if alpha <= 0.0:
		slot.visible = false
		return
	slot.visible = true
	slot.position = pos
	# Quad half-size = size * QUAD_SIZE_FACTOR so the outermost glow layer fits.
	var quad_size: float = size * QUAD_SIZE_FACTOR * 2.0
	var tex: Texture2D = slot.texture
	var tex_w: float = float(tex.get_width()) if tex != null else 4.0
	if tex_w > 0.0:
		slot.scale = Vector2.ONE * (quad_size / tex_w)
	if mat == null:
		return
	# size_norm = star outer radius / quad half-size = 1.0 / QUAD_SIZE_FACTOR.
	mat.set_shader_parameter("size_norm", 1.0 / QUAD_SIZE_FACTOR)
	mat.set_shader_parameter("inner_radius_ratio", 0.5)
	mat.set_shader_parameter("alpha", alpha)
	mat.set_shader_parameter("glow_intensity", clampf(float(state.get("glow_intensity", 1.0)), 0.0, 1.0))
	mat.set_shader_parameter("rotation", float(state.get("rotation", 0.0)))
	mat.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
	var glow_color: Color = _as_color(state.get("glow_color", Color(1.0, 0.45, 0.74, 1.0)), Color(1.0, 0.45, 0.74, 1.0))
	var fill_color: Color = _as_color(state.get("fill_color", Color(1.0, 0.0, 0.0, 1.0)), Color(1.0, 0.0, 0.0, 1.0))
	var outline_color: Color = _as_color(state.get("outline_color", Color(1.0, 1.0, 0.0, 1.0)), Color(1.0, 1.0, 0.0, 1.0))
	mat.set_shader_parameter("glow_color", glow_color)
	mat.set_shader_parameter("fill_color", fill_color)
	mat.set_shader_parameter("outline_color", outline_color)
	# Stage 1's original drop uses a 4-tip sparkle (STARPOINT_DROP_STAR_POINTS = 8);
	# Stage 2/3/4 use 5-tip stars. Per-drop selection lets us keep both shapes
	# unchanged from the legacy CPU draws.
	var tip_count: int = clamp(int(state.get("star_tip_count", 5)), 3, 8)
	mat.set_shader_parameter("star_tip_count", tip_count)
	var shimmer: float = 1.0 if bool(state.get("star_detector_bonus", false)) else 0.0
	mat.set_shader_parameter("detector_shimmer_intensity", shimmer)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
