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
const STARPOINT_HALO_SHADER := preload("res://shaders/playfield/starpoint_soft_halo.gdshader")

const HOST_NAME := "CommonStarpointVisualHost"
# Max simultaneous active drops across all stages. Most stages keep ~10 active
# at peak; 32 leaves headroom for treasure-hunt / mythic bursts.
const MAX_SLOTS := 32
# Quad half-size = drop size * QUAD_SIZE_FACTOR so the outermost glow layer
# (size * 4.0 in the original CPU code) still fits inside the quad.
const QUAD_SIZE_FACTOR := 4.0
# Soft-halo quad extends 1.5x beyond the star's outer halo radius so the
# premium aura has room to breathe outside the existing 4-layer glow.
const HALO_QUAD_FACTOR := 6.0
# Side length of the prebaked radial-falloff texture used by the soft halo
# layer. Bigger than the 4x4 star white tex because the soft halo relies on a
# smooth gradient sample rather than a flat fill.
const HALO_TEXTURE_SIZE := 128
# Spawn-tween durations chosen to feel premium but not slow (~0.45s peak).
const HALO_SPAWN_TWEEN_ALPHA_DURATION := 0.3
const HALO_SPAWN_TWEEN_SCALE_DURATION := 0.45
# Z above the pillar background and obstacle layer; below ball / paddle.
const HOST_Z_INDEX := 12

static var _prewarmed: bool = false
static var _shader_ready: bool = false
static var _halo_shader_ready: bool = false
static var _white_texture: Texture2D = null
static var _halo_texture: Texture2D = null
# Pending pointer is shared across all per-stage callers; only the single
# active stage's renderer reaches this code on any given frame, so a single
# static slot is enough to dedupe the deferred add_child gap.
static var _pending_host: Node = null

var _slots: Array[Sprite2D] = []
var _halo_slots: Array[Sprite2D] = []
var _slot_was_visible: Array[bool] = []
var _slot_tweens: Array[Tween] = []
var _slot_count: int = 0
var _frame_slot_index: int = 0


# Resource prewarm path: ensures the shader resource is loaded and the shared
# 4x4 white texture is built before any stage's draw frame tries to push a slot.
static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_shader_ready = STARPOINT_SHADER is Shader
	_halo_shader_ready = STARPOINT_HALO_SHADER is Shader
	_get_or_create_white_texture()
	_get_or_create_halo_texture()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"common_starpoint_drop_shader_ready": _shader_ready,
		"common_starpoint_drop_max_slots": MAX_SLOTS,
		"common_starpoint_drop_white_texture_ready": _white_texture != null,
		"common_starpoint_soft_halo_shader_ready": _halo_shader_ready,
		"common_starpoint_soft_halo_texture_ready": _halo_texture != null,
	}


static func _get_or_create_white_texture() -> Texture2D:
	if _white_texture != null:
		return _white_texture
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(img)
	return _white_texture


# Build the prebaked radial-falloff alpha gradient used by the soft halo layer.
# A `cos^2(d * PI/2)` curve in [0,1] is gentler at the rim than a linear
# smoothstep and cheaper than a per-frame shader-side falloff that would need
# pow() or smoothstep() per fragment. Generated once at prewarm.
static func _get_or_create_halo_texture() -> Texture2D:
	if _halo_texture != null:
		return _halo_texture
	var size: int = HALO_TEXTURE_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var dx: float = (float(x) + 0.5) - half
			var dy: float = (float(y) + 0.5) - half
			var d: float = sqrt(dx * dx + dy * dy) / half
			var a: float = 0.0
			if d < 1.0:
				var c: float = cos(d * PI * 0.5)
				a = c * c
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_halo_texture = ImageTexture.create_from_image(img)
	return _halo_texture


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
	var slot_index: int = _frame_slot_index
	var slot: Sprite2D = _slots[slot_index]
	if slot == null:
		return
	var mat: ShaderMaterial = slot.material as ShaderMaterial
	_apply_slot(slot, mat, state)
	var halo_slot: Sprite2D = _halo_slots[slot_index]
	var halo_mat: ShaderMaterial = halo_slot.material as ShaderMaterial if halo_slot != null else null
	if halo_slot != null:
		_apply_halo_slot(halo_slot, halo_mat, state)
	# Spawn / despawn edge detection. Spawn = was hidden last frame, visible
	# this frame -> kick the premium scale + alpha tween. Despawn = was visible,
	# now hidden (drop's raw life reached zero in flight) -> stop any running
	# spawn tween so it doesn't keep writing to a slot that's about to be reused.
	var visible_this_frame: bool = slot.visible
	var was_visible: bool = _slot_was_visible[slot_index]
	if visible_this_frame and not was_visible:
		if halo_slot != null and halo_slot.visible and halo_mat != null:
			_kick_halo_spawn_tween(halo_slot, halo_mat, slot_index)
	elif was_visible and not visible_this_frame:
		_kill_slot_tween(slot_index)
	_slot_was_visible[slot_index] = visible_this_frame
	_frame_slot_index += 1


func end_frame() -> void:
	for i in range(_frame_slot_index, _slot_count):
		var slot: Sprite2D = _slots[i]
		if slot != null:
			slot.visible = false
		var halo_slot: Sprite2D = _halo_slots[i] if i < _halo_slots.size() else null
		if halo_slot != null:
			halo_slot.visible = false
		_kill_slot_tween(i)
		_slot_was_visible[i] = false


func _kill_slot_tween(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_tweens.size():
		return
	var prev: Tween = _slot_tweens[slot_index]
	if prev != null and prev.is_valid():
		prev.kill()
	_slot_tweens[slot_index] = null


func tear_down(deferred: bool = true) -> void:
	if deferred:
		queue_free()
	else:
		free()


func _build_slot_pool() -> void:
	if _slot_count > 0:
		return
	var tex: Texture2D = _get_or_create_white_texture()
	var halo_tex: Texture2D = _get_or_create_halo_texture()
	# Halo slots are added FIRST so they draw underneath the star slots (Node2D
	# sibling draw order = child index). The premium soft aura sits behind the
	# crisp star body, never in front of it.
	for i in range(MAX_SLOTS):
		var halo := Sprite2D.new()
		halo.name = "StarpointHaloSlot%d" % i
		halo.texture = halo_tex
		halo.centered = true
		halo.visible = false
		var halo_mat := ShaderMaterial.new()
		halo_mat.shader = STARPOINT_HALO_SHADER
		halo_mat.set_shader_parameter("halo_texture", halo_tex)
		halo.material = halo_mat
		add_child(halo)
		_halo_slots.append(halo)
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
		_slot_was_visible.append(false)
		_slot_tweens.append(null)
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
	# Iridescent body shimmer for the normal pink drops; detector drops can
	# still pass a smaller value (or zero) so the cyan rim isn't washed out by
	# competing hue cycling.
	var iridescent: float = clampf(float(state.get("iridescent_shimmer_intensity", 0.0)), 0.0, 1.0)
	mat.set_shader_parameter("iridescent_shimmer_intensity", iridescent)
	# Cross-shaped sparkle ray "shining" highlight. Stages that want the
	# jewel-like sparkle pass 1.0; gold-palette / detector drops can suppress
	# it by passing 0 so their identity (gold / cyan rim) reads cleanly.
	var sparkle: float = clampf(float(state.get("sparkle_ray_intensity", 0.0)), 0.0, 1.0)
	mat.set_shader_parameter("sparkle_ray_intensity", sparkle)


func _apply_halo_slot(slot: Sprite2D, mat: ShaderMaterial, state: Dictionary) -> void:
	var raw_life: float = float(state.get("life", 0.0))
	var alpha: float = clampf(raw_life * 2.0 / 255.0, 0.0, 1.0)
	if alpha <= 0.0:
		slot.visible = false
		return
	slot.visible = true
	slot.position = _as_vector2(state.get("pos", Vector2.ZERO))
	var size: float = max(1.0, float(state.get("size", 12.0)))
	# Halo quad extends 1.5x beyond the star's outer halo radius. Sprite2D.scale
	# only sizes the quad — the spawn-tween animates `spawn_scale` on the shader
	# instead, so the per-frame quad scaling never fights the running tween.
	var quad_size: float = size * HALO_QUAD_FACTOR * 2.0
	var tex: Texture2D = slot.texture
	var tex_w: float = float(tex.get_width()) if tex != null else float(HALO_TEXTURE_SIZE)
	if tex_w > 0.0:
		slot.scale = Vector2.ONE * (quad_size / tex_w)
	if mat == null:
		return
	mat.set_shader_parameter("alpha", alpha)
	mat.set_shader_parameter("glow_intensity", clampf(float(state.get("glow_intensity", 1.0)), 0.0, 1.0))
	mat.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
	# The halo color follows the star's glow palette so each stage's identity
	# stays consistent (pink for normal, cyan for detector, gold for stage 4).
	var glow_color: Color = _as_color(state.get("glow_color", Color(1.0, 0.45, 0.74, 1.0)), Color(1.0, 0.45, 0.74, 1.0))
	mat.set_shader_parameter("halo_color", glow_color)
	# Star-detector drops already carry a cyan rim from the star shader; muting
	# both halo sparkles and the iridescent rim there keeps the cyan identity
	# from getting washed out by the additive premium layer.
	var is_detector: bool = bool(state.get("star_detector_bonus", false))
	mat.set_shader_parameter("sparkle_intensity", 0.55 if is_detector else 0.95)
	mat.set_shader_parameter("iridescent_rim_intensity", 0.0 if is_detector else 0.55)


# Premium spawn animation kicked once per drop's first visible frame: alpha
# fades in over 0.3s (sine ease-out) and the halo zooms from scale=0.3 -> 1.0
# over 0.45s with EASE_OUT_BACK so the drop "pops" instead of appearing flat.
# Driven by a Godot Tween via tween_method so it animates a shader uniform
# without writing to slot.scale (which is set per-frame by _apply_halo_slot).
func _kick_halo_spawn_tween(halo_slot: Sprite2D, mat: ShaderMaterial, slot_index: int) -> void:
	var prev: Tween = _slot_tweens[slot_index]
	if prev != null and prev.is_valid():
		prev.kill()
	halo_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	mat.set_shader_parameter("spawn_scale", 0.3)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(halo_slot, "modulate:a", 1.0, HALO_SPAWN_TWEEN_ALPHA_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		Callable(self, "_apply_spawn_scale_to_material").bind(mat),
		0.3,
		1.0,
		HALO_SPAWN_TWEEN_SCALE_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_slot_tweens[slot_index] = tween


# Tween_method callback for the spawn-scale shader uniform. The Tween node
# tweens the float value and forwards it here together with the bound material;
# if the material was freed between tween start and the next frame (slot pool
# tear-down, scene change), the null guard prevents a callback-on-dead-object
# crash without dragging the tween into a hard fail.
func _apply_spawn_scale_to_material(value: float, mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("spawn_scale", value)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
