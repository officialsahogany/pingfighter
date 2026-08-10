extends RefCounted

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaBackgroundProjection := preload("res://scripts/plaza/plaza_background_projection.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")

const CULL_MARGIN := 80.0
const SHADOW_HEIGHT := 18.0


static func draw(
	canvas: CanvasItem,
	spec: Dictionary,
	camera_x: float,
	viewport_width: float,
	building_baseline_y: float,
	scale: float,
	ticks_msec: int
) -> void:
	if canvas == null:
		return
	var base_texture: Texture2D = spec.get("base_texture", null)
	if base_texture == null:
		return
	var world_rect := resolve_world_rect(spec)
	var local_rect := PlazaWorldGeometry.world_rect_to_local(world_rect, camera_x, scale)
	if local_rect.position.x > viewport_width + CULL_MARGIN or local_rect.end.x < -CULL_MARGIN:
		return
	var shadow_rect := Rect2(
		Vector2(local_rect.position.x + local_rect.size.x * 0.12, building_baseline_y * scale),
		Vector2(local_rect.size.x * 0.76, SHADOW_HEIGHT * scale)
	)
	canvas.draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.22), true)
	canvas.draw_texture_rect(base_texture, local_rect, false)
	var pulse := PlazaBackgroundProjection.discrete_flicker(get_flicker_seed(spec), ticks_msec)
	var sign_texture: Texture2D = spec.get("sign_texture", null)
	if sign_texture != null:
		canvas.draw_texture_rect(sign_texture, local_rect, false, Color(1.0, 1.0, 1.0, 0.72 + pulse * 0.22))
	var window_texture: Texture2D = spec.get("window_texture", null)
	if window_texture != null:
		canvas.draw_texture_rect(window_texture, local_rect, false, Color(1.0, 0.93, 0.78, 0.56 + pulse * 0.12))


static func resolve_world_rect(spec: Dictionary) -> Rect2:
	var world_rect: Rect2 = spec.get("visual_rect", Rect2())
	if world_rect.size != Vector2.ZERO:
		return world_rect
	var source_size: Vector2 = spec.get("source_size", Vector2.ONE)
	var origin_pivot: Vector2 = spec.get("origin_pivot", source_size * 0.5)
	var display_scale := float(spec.get("display_scale", 1.0))
	var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
	return Rect2(pivot_pos - origin_pivot * display_scale, source_size * display_scale)


static func get_flicker_seed(spec: Dictionary) -> String:
	var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
	return "%s:%d" % [str(spec.get("type", "")), int(round(pivot_pos.x))]


# Production retained-mode factory. The immediate draw() entrypoint above stays
# as a compatibility surface, while PlazaMapWorldHost owns these live nodes.
static func create_retained_visual() -> Node2D:
	return RetainedBuildingVisual.new()


# The renderer owns the prewarm call chain, but the asset loader owns resource
# state. Keep this as a direct delegation: a missing dynamic method must never
# be interpreted as "already warm".
static func prewarm_assets_step(
	manifest_paths: Array[String],
	use_threaded_texture_loads: bool = true,
	prewarm_key: String = "hwangyeok_2d_v1"
) -> bool:
	return PlazaAssetLoader.prewarm_building_assets_step(
		manifest_paths,
		use_threaded_texture_loads,
		prewarm_key
	)


class RetainedBuildingVisual:
	extends Node2D

	var _shadow: Polygon2D = null
	var _base_sprite: Sprite2D = null
	var _sign_sprite: Sprite2D = null
	var _window_sprite: Sprite2D = null
	var _base_material: CanvasItemMaterial = null
	var _sign_material: CanvasItemMaterial = null
	var _window_material: CanvasItemMaterial = null
	var _has_sign := false
	var _has_window := false
	var _last_synced_ticks_msec := -1


	func _init() -> void:
		z_as_relative = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		set_process(false)
		_build_children()
		set_active(false)


	func sync_state(
		spec: Dictionary,
		camera_x: float,
		viewport_width: float,
		building_baseline_y: float,
		render_scale: float,
		ticks_msec: int
	) -> bool:
		# Retained nodes do not inherit an immediate-mode early return. Always
		# fail closed, then explicitly re-enable after a complete valid sync.
		set_active(false)
		if viewport_width <= 1.0 or render_scale <= 0.0:
			return false
		var base_texture_value: Variant = spec.get("base_texture", null)
		if not (base_texture_value is Texture2D):
			return false
		var world_rect := _resolve_world_rect(spec)
		if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
			return false
		var local_rect := PlazaWorldGeometry.world_rect_to_local(world_rect, camera_x, render_scale)
		if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
			return false
		if local_rect.position.x > viewport_width + CULL_MARGIN or local_rect.end.x < -CULL_MARGIN:
			return false

		_build_children()
		var base_texture := base_texture_value as Texture2D
		_apply_sprite_rect(_base_sprite, base_texture, local_rect)
		_base_sprite.modulate = Color.WHITE

		var shadow_left := local_rect.position.x + local_rect.size.x * 0.12
		var shadow_top := building_baseline_y * render_scale
		var shadow_size := Vector2(local_rect.size.x * 0.76, SHADOW_HEIGHT * render_scale)
		_shadow.polygon = PackedVector2Array([
			Vector2(shadow_left, shadow_top),
			Vector2(shadow_left + shadow_size.x, shadow_top),
			Vector2(shadow_left + shadow_size.x, shadow_top + shadow_size.y),
			Vector2(shadow_left, shadow_top + shadow_size.y),
		])

		var pulse := PlazaBackgroundProjection.discrete_flicker(
			_get_flicker_seed(spec),
			ticks_msec
		)
		var sign_texture_value: Variant = spec.get("sign_texture", null)
		_has_sign = sign_texture_value is Texture2D
		if _has_sign:
			_apply_sprite_rect(_sign_sprite, sign_texture_value as Texture2D, local_rect)
			var sign_color := _coerce_color(spec.get("sign_glow_color", Color.WHITE), Color.WHITE)
			var sign_strength := maxf(0.0, float(spec.get("sign_glow_strength", 1.0)))
			_sign_sprite.modulate = Color(
				sign_color.r,
				sign_color.g,
				sign_color.b,
				clampf(sign_color.a * (0.72 + pulse * 0.22) * sign_strength, 0.0, 4.0)
			)

		var window_texture_value: Variant = spec.get("window_texture", null)
		_has_window = window_texture_value is Texture2D
		if _has_window:
			_apply_sprite_rect(_window_sprite, window_texture_value as Texture2D, local_rect)
			var window_color := _coerce_color(spec.get("window_glow_color", Color(1.0, 0.93, 0.78, 1.0)), Color(1.0, 0.93, 0.78, 1.0))
			var window_strength := maxf(0.0, float(spec.get("window_glow_strength", 1.0)))
			_window_sprite.modulate = Color(
				window_color.r,
				window_color.g,
				window_color.b,
				clampf(window_color.a * (0.56 + pulse * 0.12) * window_strength, 0.0, 4.0)
			)

		_last_synced_ticks_msec = ticks_msec
		_activate_synced_layers()
		return true


	func set_active(active: bool) -> void:
		visible = active
		set_process(false)
		if active:
			return
		if _shadow != null:
			_shadow.visible = false
		if _base_sprite != null:
			_base_sprite.visible = false
		if _sign_sprite != null:
			_sign_sprite.visible = false
		if _window_sprite != null:
			_window_sprite.visible = false


	func clear_transient_canvas_items() -> void:
		set_active(false)


	func tear_down(free_self: bool = false) -> void:
		set_active(false)
		if free_self:
			queue_free()


	func get_layer_status() -> Dictionary:
		var base_bound_material: CanvasItemMaterial = _base_sprite.material as CanvasItemMaterial if _base_sprite != null and _base_sprite.material is CanvasItemMaterial else null
		var sign_bound_material: CanvasItemMaterial = _sign_sprite.material as CanvasItemMaterial if _sign_sprite != null and _sign_sprite.material is CanvasItemMaterial else null
		var window_bound_material: CanvasItemMaterial = _window_sprite.material as CanvasItemMaterial if _window_sprite != null and _window_sprite.material is CanvasItemMaterial else null
		return {
			"active": visible,
			"process_enabled": is_processing(),
			"base_visible": _base_sprite != null and _base_sprite.visible,
			"sign_visible": _sign_sprite != null and _sign_sprite.visible,
			"window_visible": _window_sprite != null and _window_sprite.visible,
			"base_blend_mode": _base_material.blend_mode if _base_material != null else -1,
			"sign_blend_mode": _sign_material.blend_mode if _sign_material != null else -1,
			"window_blend_mode": _window_material.blend_mode if _window_material != null else -1,
			"base_material_id": _base_material.get_instance_id() if _base_material != null else 0,
			"sign_material_id": _sign_material.get_instance_id() if _sign_material != null else 0,
			"window_material_id": _window_material.get_instance_id() if _window_material != null else 0,
			"base_bound_material_id": base_bound_material.get_instance_id() if base_bound_material != null else 0,
			"sign_bound_material_id": sign_bound_material.get_instance_id() if sign_bound_material != null else 0,
			"window_bound_material_id": window_bound_material.get_instance_id() if window_bound_material != null else 0,
			"base_bound_blend_mode": base_bound_material.blend_mode if base_bound_material != null else -1,
			"sign_bound_blend_mode": sign_bound_material.blend_mode if sign_bound_material != null else -1,
			"window_bound_blend_mode": window_bound_material.blend_mode if window_bound_material != null else -1,
			"base_texture_size": _sprite_texture_size(_base_sprite),
			"sign_texture_size": _sprite_texture_size(_sign_sprite),
			"window_texture_size": _sprite_texture_size(_window_sprite),
			"base_position": _base_sprite.position if _base_sprite != null else Vector2.ZERO,
			"sign_position": _sign_sprite.position if _sign_sprite != null else Vector2.ZERO,
			"window_position": _window_sprite.position if _window_sprite != null else Vector2.ZERO,
			"base_scale": _base_sprite.scale if _base_sprite != null else Vector2.ZERO,
			"sign_scale": _sign_sprite.scale if _sign_sprite != null else Vector2.ZERO,
			"window_scale": _window_sprite.scale if _window_sprite != null else Vector2.ZERO,
			"base_render_rect": _sprite_render_rect(_base_sprite),
			"sign_render_rect": _sprite_render_rect(_sign_sprite),
			"window_render_rect": _sprite_render_rect(_window_sprite),
			"sign_modulate": _sign_sprite.modulate if _sign_sprite != null else Color.TRANSPARENT,
			"window_modulate": _window_sprite.modulate if _window_sprite != null else Color.TRANSPARENT,
			"last_synced_ticks_msec": _last_synced_ticks_msec,
			"all_layer_z_zero": (
				_shadow != null and _shadow.z_index == 0
				and _base_sprite != null and _base_sprite.z_index == 0
				and _sign_sprite != null and _sign_sprite.z_index == 0
				and _window_sprite != null and _window_sprite.z_index == 0
			),
		}


	func _build_children() -> void:
		if _shadow != null:
			return
		_base_material = _make_blend_material(CanvasItemMaterial.BLEND_MODE_MIX)
		_sign_material = _make_blend_material(CanvasItemMaterial.BLEND_MODE_ADD)
		_window_material = _make_blend_material(CanvasItemMaterial.BLEND_MODE_ADD)

		_shadow = Polygon2D.new()
		_shadow.name = "Shadow"
		_shadow.color = Color(0.0, 0.0, 0.0, 0.22)
		_shadow.z_index = 0
		add_child(_shadow)

		# Keep every descendant at the host's effective z=-1. Positive relative
		# child z values would climb back to the plaza root's opaque/UI plane.
		# Same-z sibling insertion order preserves shadow -> base -> glows.
		_base_sprite = _make_sprite("Base", _base_material)
		add_child(_base_sprite)
		_sign_sprite = _make_sprite("SignEmissive", _sign_material)
		add_child(_sign_sprite)
		_window_sprite = _make_sprite("WindowGlow", _window_material)
		add_child(_window_sprite)


	func _activate_synced_layers() -> void:
		visible = true
		# The accepted 3/4 building bases already paint their ground contact.
		# Reusing the legacy rectangular shadow reads as a detached gray slab on
		# the pale street and crosses in front of the player.
		_shadow.visible = false
		_base_sprite.visible = true
		_sign_sprite.visible = _has_sign
		_window_sprite.visible = _has_window
		set_process(false)


	func _apply_sprite_rect(sprite: Sprite2D, texture: Texture2D, rect: Rect2) -> void:
		sprite.texture = texture
		sprite.position = rect.position
		var texture_size := texture.get_size()
		if texture_size.x <= 0.0 or texture_size.y <= 0.0:
			sprite.scale = Vector2.ONE
			return
		sprite.scale = rect.size / texture_size


	func _make_sprite(sprite_name: String, sprite_material: Material) -> Sprite2D:
		var sprite := Sprite2D.new()
		sprite.name = sprite_name
		sprite.centered = false
		sprite.material = sprite_material
		sprite.z_index = 0
		sprite.visible = false
		return sprite


	func _make_blend_material(blend_mode: int) -> CanvasItemMaterial:
		var next_material := CanvasItemMaterial.new()
		next_material.blend_mode = blend_mode as CanvasItemMaterial.BlendMode
		return next_material


	func _sprite_texture_size(sprite: Sprite2D) -> Vector2:
		if sprite == null or sprite.texture == null:
			return Vector2.ZERO
		return sprite.texture.get_size()


	func _sprite_render_rect(sprite: Sprite2D) -> Rect2:
		return Rect2(sprite.position, _sprite_texture_size(sprite) * sprite.scale) if sprite != null else Rect2()


	func _coerce_color(value: Variant, fallback: Color) -> Color:
		if value is Color:
			return value as Color
		if value is String:
			return Color.from_string(str(value), fallback)
		return fallback


	func _resolve_world_rect(spec: Dictionary) -> Rect2:
		var world_rect: Rect2 = spec.get("visual_rect", Rect2())
		if world_rect.size != Vector2.ZERO:
			return world_rect
		var source_size: Vector2 = spec.get("source_size", Vector2.ONE)
		var origin_pivot: Vector2 = spec.get("origin_pivot", source_size * 0.5)
		var display_scale := float(spec.get("display_scale", 1.0))
		var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
		return Rect2(pivot_pos - origin_pivot * display_scale, source_size * display_scale)


	func _get_flicker_seed(spec: Dictionary) -> String:
		var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
		return "%s:%d" % [str(spec.get("type", "")), int(round(pivot_pos.x))]
