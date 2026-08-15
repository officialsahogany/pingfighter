extends Control

# R3-B candidate-only retained exterior renderer. Static environment art is
# compiled once at bind time. Camera movement changes one world-root transform;
# actor animation changes only the two retained actor sprites. Buildings,
# semantic decor, player, and guardian share one actual Y-sort root. Buildings
# intentionally have no Shadow child: the approved plot pads are the canonical
# grounding treatment unless a later real-capture A/B reopens that decision.

const PlazaActorRenderer := preload("res://scripts/plaza/plaza_actor_renderer.gd")
const PlazaActorVisualProjection := preload("res://scripts/plaza/plaza_actor_visual_projection.gd")
const PlazaBackgroundProjection := preload("res://scripts/plaza/plaza_background_projection.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaR3EnvironmentLayoutCompiler := preload("res://scripts/plaza/plaza_r3_environment_layout_compiler.gd")

const SCHEMA_VERSION := "plaza_r3_exterior_retained_host_v1"
const PLAYER_DRAW_SIZE_WORLD := PlazaActorVisualProjection.PLAYER_SPRITE_DRAW_SIZE
const PLAYER_FOOT_OFFSET_WORLD := PlazaActorVisualProjection.PLAYER_SPRITE_FOOT_OFFSET
const DEFAULT_GUARDIAN_DRAW_SIZE_WORLD := 92.0

var _active := false
var _bound := false
var _rejection_reason := "not_bound"
var _layout_fingerprint := ""
var _plan_fingerprint := ""
var _projection: Dictionary = {}
var _successful_bind_count := 0
var _successful_sync_count := 0

var _clip_host: Control = null
var _world_root: Node2D = null
var _background_root: Node2D = null
var _sort_root: Node2D = null
var _building_items: Array[Node2D] = []
var _decor_items: Array[Node2D] = []
var _player_item: Node2D = null
var _guardian_item: Node2D = null
var _player_sprite: Sprite2D = null
var _guardian_sprite: Sprite2D = null
var _player_textures: Dictionary = {}
var _guardian_texture: Texture2D = null
var _guardian_grid_cols := 1
var _guardian_grid_rows := 1
var _guardian_frame_count := 1
var _guardian_draw_size_world := DEFAULT_GUARDIAN_DRAW_SIZE_WORLD
var _guardian_enabled := false
var _mix_material: CanvasItemMaterial = null
var _add_material: CanvasItemMaterial = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	set_process(false)
	_build_roots()


func bind_scene(
	layout: Dictionary,
	environment_plan: Dictionary,
	visual_config: Dictionary,
	projection: Dictionary
) -> bool:
	set_active(false)
	var layout_validation := PlazaMapRoadSkeletonR3.validate_layout(layout)
	if not bool(layout_validation.get("valid", false)):
		return _reject("r3_layout_validation_failed")
	var layout_fingerprint := str(layout.get("fingerprint", ""))
	if layout_fingerprint == "" or PlazaMapRoadSkeletonR3.build_fingerprint(layout) != layout_fingerprint:
		return _reject("stale_layout_fingerprint")
	if str(environment_plan.get("layout_fingerprint", "")) != layout_fingerprint:
		return _reject("plan_layout_fingerprint_mismatch")
	var plan_fingerprint := str(environment_plan.get("fingerprint", ""))
	if plan_fingerprint == "" or PlazaR3EnvironmentLayoutCompiler.build_fingerprint(environment_plan) != plan_fingerprint:
		return _reject("stale_environment_plan_fingerprint")
	var plan_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(environment_plan, layout, true)
	if not bool(plan_validation.get("valid", false)):
		return _reject("environment_plan_validation_failed")
	if not PlazaMapProjection.is_valid_snapshot(projection):
		return _reject("projection_invalid")
	var visual_result := _compile_visual_config(visual_config)
	if not bool(visual_result.get("valid", false)):
		return _reject(str(visual_result.get("reason", "visual_config_invalid")))

	_restore_scene_root_contracts()
	_clear_bound_nodes()
	var static_result := _build_static_scene(layout, environment_plan)
	if not bool(static_result.get("valid", false)):
		_clear_bound_nodes()
		return _reject(str(static_result.get("reason", "static_scene_invalid")))
	_apply_visual_config(visual_result)
	_build_actor_items()
	_layout_fingerprint = layout_fingerprint
	_plan_fingerprint = plan_fingerprint
	_projection = projection.duplicate(true)
	_apply_projection(projection)
	_bound = true
	_rejection_reason = ""
	_successful_bind_count += 1
	set_active(true)
	return true


func sync_dynamic(state: Dictionary, projection: Dictionary) -> bool:
	if not _bound:
		return _reject("not_bound")
	if not PlazaMapProjection.is_valid_snapshot(projection):
		return _reject("projection_invalid")
	var player_position_value: Variant = state.get("player_world_position", null)
	var guardian_position_value: Variant = state.get("guardian_world_position", null)
	var ticks_value: Variant = state.get("ticks_msec", null)
	var moving_value: Variant = state.get("player_moving", null)
	var facing_value: Variant = state.get("player_facing", null)
	if not (player_position_value is Vector2) or typeof(ticks_value) != TYPE_INT:
		return _reject("player_frame_type_invalid")
	if typeof(moving_value) != TYPE_BOOL or typeof(facing_value) != TYPE_INT:
		return _reject("player_motion_type_invalid")
	var player_world := player_position_value as Vector2
	var ticks_msec := int(ticks_value)
	var facing := int(facing_value)
	if not player_world.is_finite() or ticks_msec < 0 or not [-1, 1].has(facing):
		return _reject("player_frame_invalid")
	var guardian_world := Vector2.ZERO
	if _guardian_enabled:
		if not (guardian_position_value is Vector2):
			return _reject("guardian_frame_type_invalid")
		guardian_world = guardian_position_value as Vector2
		if not guardian_world.is_finite():
			return _reject("guardian_frame_invalid")

	# No mutation occurs until the complete dynamic state passes preflight.
	_restore_scene_root_contracts()
	_restore_static_sort_contracts()
	_apply_projection(projection)
	_apply_player_frame(player_world, bool(moving_value), facing, ticks_msec)
	if _guardian_enabled:
		_apply_guardian_frame(guardian_world, ticks_msec)
	_update_building_glow(ticks_msec)
	_projection = projection.duplicate(true)
	_rejection_reason = ""
	_successful_sync_count += 1
	set_active(true)
	return true


func set_active(active: bool) -> void:
	_active = active and _bound
	visible = _active
	if _clip_host != null:
		_clip_host.visible = _active
	set_process(false)


func clear_transient_canvas_items() -> void:
	set_active(false)
	_clear_bound_nodes()
	_bound = false
	_layout_fingerprint = ""
	_plan_fingerprint = ""
	_projection.clear()
	_rejection_reason = "cleared"


func get_sort_root_for_test() -> Node2D:
	return _sort_root


func get_player_item_for_test() -> Node2D:
	return _player_item


func get_guardian_item_for_test() -> Node2D:
	return _guardian_item


func get_building_item_for_test(building_type: String) -> Node2D:
	for item in _building_items:
		if str(item.get_meta("building_type", "")) == building_type:
			return item
	return null


func get_sort_contract_status() -> Dictionary:
	var direct_items: Array[Node2D] = []
	for child in _sort_root.get_children():
		if child is Node2D:
			direct_items.append(child as Node2D)
	var scene_root_contract_valid := (
		_root_contract_valid(_world_root)
		and _root_contract_valid(_background_root)
		and _root_contract_valid(_sort_root)
		and not _world_root.y_sort_enabled
		and not _background_root.y_sort_enabled
		and _sort_root.y_sort_enabled
	)
	var direct_contract_valid := _sort_root.y_sort_enabled and _root_contract_valid(_sort_root)
	var child_contract_valid := true
	var material_contract_valid := (
		_mix_material != null
		and _add_material != null
		and _mix_material.blend_mode == CanvasItemMaterial.BLEND_MODE_MIX
		and _add_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
	)
	var building_shadow_count := 0
	var real_actor_texture_count := 0
	for item in direct_items:
		direct_contract_valid = direct_contract_valid and _node_contract_valid(item)
		var role := str(item.get_meta("sort_role", ""))
		if role == "building" and item.has_node("Shadow"):
			building_shadow_count += 1
		for child in item.get_children():
			if not (child is CanvasItem):
				continue
			var canvas_child := child as CanvasItem
			child_contract_valid = child_contract_valid and _canvas_contract_valid(canvas_child)
			var expected_material: Material = null
			if role == "building" and child.name == "Base":
				expected_material = _mix_material
			elif role == "building" and (child.name == "SignEmissive" or child.name == "WindowGlowMask"):
				expected_material = _add_material
			material_contract_valid = material_contract_valid and canvas_child.material == expected_material
		if (role == "player" or role == "guardian") and item.has_node("Sprite"):
			var sprite := item.get_node("Sprite") as Sprite2D
			if sprite.texture != null and sprite.region_enabled:
				real_actor_texture_count += 1
	var expected_actor_count := 2 if _guardian_enabled else 1
	return {
		"valid": (
			_bound
			and scene_root_contract_valid
			and direct_contract_valid
			and child_contract_valid
			and material_contract_valid
			and building_shadow_count == 0
			and real_actor_texture_count == expected_actor_count
			and _player_item != null
			and (_guardian_item != null) == _guardian_enabled
		),
		"schema_version": SCHEMA_VERSION,
		"direct_item_count": direct_items.size(),
		"building_count": _building_items.size(),
		"decor_count": _decor_items.size(),
		"building_shadow_count": building_shadow_count,
		"real_actor_texture_count": real_actor_texture_count,
		"expected_actor_count": expected_actor_count,
		"sort_root_y_sort_enabled": _sort_root.y_sort_enabled,
		"scene_root_contract_valid": scene_root_contract_valid,
		"direct_contract_valid": direct_contract_valid,
		"child_contract_valid": child_contract_valid,
		"material_contract_valid": material_contract_valid,
	}


func get_debug_status() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"active": _active,
		"bound": _bound,
		"visible": visible,
		"rejection_reason": _rejection_reason,
		"layout_fingerprint": _layout_fingerprint,
		"plan_fingerprint": _plan_fingerprint,
		"successful_bind_count": _successful_bind_count,
		"successful_sync_count": _successful_sync_count,
		"projection": _projection.duplicate(true),
		"sort_contract": get_sort_contract_status(),
	}


func _build_roots() -> void:
	_mix_material = CanvasItemMaterial.new()
	_mix_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_clip_host = Control.new()
	_clip_host.name = "MapSafeClip"
	_clip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_host.clip_contents = true
	add_child(_clip_host)
	_world_root = Node2D.new()
	_world_root.name = "WorldRoot"
	_clip_host.add_child(_world_root)
	_background_root = Node2D.new()
	_background_root.name = "Background"
	_world_root.add_child(_background_root)
	_sort_root = Node2D.new()
	_sort_root.name = "WorldYSort"
	_world_root.add_child(_sort_root)
	_restore_scene_root_contracts()


func _compile_visual_config(config: Dictionary) -> Dictionary:
	var player_value: Variant = config.get("player_textures", null)
	if not (player_value is Dictionary):
		return _invalid("player_textures_type_invalid")
	var player := player_value as Dictionary
	var has_sprite_value: Variant = player.get("has_sprite", null)
	if typeof(has_sprite_value) != TYPE_BOOL or not bool(has_sprite_value):
		return _invalid("player_sprite_missing")
	for key in ["idle", "walk_left", "walk_right"]:
		if not (player.get(key, null) is Texture2D):
			return _invalid("player_texture_missing:%s" % key)
	var player_cols_value: Variant = player.get("grid_cols", null)
	var player_rows_value: Variant = player.get("grid_rows", null)
	var player_frames_value: Variant = player.get("frame_count", null)
	if typeof(player_cols_value) != TYPE_INT or typeof(player_rows_value) != TYPE_INT or typeof(player_frames_value) != TYPE_INT:
		return _invalid("player_grid_type_invalid")
	var player_cols := int(player_cols_value)
	var player_rows := int(player_rows_value)
	var player_frames := int(player_frames_value)
	if player_cols <= 0 or player_rows <= 0 or player_frames <= 0 or player_frames > player_cols * player_rows:
		return _invalid("player_grid_invalid")

	var guardian_enabled_value: Variant = config.get("guardian_enabled", false)
	if typeof(guardian_enabled_value) != TYPE_BOOL:
		return _invalid("guardian_enabled_type_invalid")
	var guardian_enabled := bool(guardian_enabled_value)
	var guardian_texture: Texture2D = null
	var guardian_cols := 1
	var guardian_rows := 1
	var guardian_frames := 1
	var guardian_draw_size := DEFAULT_GUARDIAN_DRAW_SIZE_WORLD
	if guardian_enabled:
		var texture_value: Variant = config.get("guardian_texture", null)
		if not (texture_value is Texture2D):
			return _invalid("guardian_texture_missing")
		guardian_texture = texture_value as Texture2D
		var guardian_cols_value: Variant = config.get("guardian_grid_cols", null)
		var guardian_rows_value: Variant = config.get("guardian_grid_rows", null)
		var guardian_frames_value: Variant = config.get("guardian_frame_count", null)
		if typeof(guardian_cols_value) != TYPE_INT or typeof(guardian_rows_value) != TYPE_INT or typeof(guardian_frames_value) != TYPE_INT:
			return _invalid("guardian_grid_type_invalid")
		guardian_cols = int(guardian_cols_value)
		guardian_rows = int(guardian_rows_value)
		guardian_frames = int(guardian_frames_value)
		var draw_size_value: Variant = config.get("guardian_draw_size_world", null)
		if not _positive_finite_number(draw_size_value):
			return _invalid("guardian_draw_size_invalid")
		guardian_draw_size = float(draw_size_value)
		if guardian_cols <= 0 or guardian_rows <= 0 or guardian_frames <= 0 or guardian_frames > guardian_cols * guardian_rows:
			return _invalid("guardian_grid_invalid")
	return {
		"valid": true,
		"player_textures": player.duplicate(false),
		"guardian_enabled": guardian_enabled,
		"guardian_texture": guardian_texture,
		"guardian_grid_cols": guardian_cols,
		"guardian_grid_rows": guardian_rows,
		"guardian_frame_count": guardian_frames,
		"guardian_draw_size_world": guardian_draw_size,
	}


func _apply_visual_config(result: Dictionary) -> void:
	_player_textures = (result.get("player_textures", {}) as Dictionary).duplicate(false)
	_guardian_enabled = bool(result.get("guardian_enabled", false))
	_guardian_texture = result.get("guardian_texture", null) as Texture2D
	_guardian_grid_cols = int(result.get("guardian_grid_cols", 1))
	_guardian_grid_rows = int(result.get("guardian_grid_rows", 1))
	_guardian_frame_count = int(result.get("guardian_frame_count", 1))
	_guardian_draw_size_world = float(result.get("guardian_draw_size_world", DEFAULT_GUARDIAN_DRAW_SIZE_WORLD))


func _build_static_scene(layout: Dictionary, plan: Dictionary) -> Dictionary:
	var ground_result := _add_plan_sprite(_background_root, plan.get("ground_draw", {}) as Dictionary, -1000)
	if not bool(ground_result.get("valid", false)):
		return ground_result
	for record in _dictionary_array(plan.get("road_draws", [])):
		var road_result := _add_plan_sprite(_background_root, record, -800)
		if not bool(road_result.get("valid", false)):
			return road_result
	for record in _dictionary_array(plan.get("plot_pad_draws", [])):
		var pad_result := _add_plan_sprite(_background_root, record, -600)
		if not bool(pad_result.get("valid", false)):
			return pad_result
	for record in _dictionary_array(plan.get("decor_draws", [])):
		var decor_result := _add_sorted_plan_sprite(record)
		if not bool(decor_result.get("valid", false)):
			return decor_result
	for spec in _dictionary_array(layout.get("building_specs", [])):
		var building_result := _add_building(spec)
		if not bool(building_result.get("valid", false)):
			return building_result
	return {"valid": true}


func _add_plan_sprite(parent: Node2D, record: Dictionary, z_index: int) -> Dictionary:
	var texture_result := _load_record_texture(record)
	if not bool(texture_result.get("valid", false)):
		return texture_result
	var transform_result := _read_plan_transform(record)
	if not bool(transform_result.get("valid", false)):
		return transform_result
	var sprite := _new_sprite(str(record.get("id", "")), null)
	sprite.texture = texture_result.get("texture", null) as Texture2D
	var anchor := transform_result.get("world_position", Vector2.ZERO) as Vector2
	var source_anchor := transform_result.get("source_anchor_pixels", Vector2.ZERO) as Vector2
	var world_scale := transform_result.get("world_scale", Vector2.ONE) as Vector2
	sprite.position = anchor - source_anchor * world_scale
	sprite.scale = world_scale
	sprite.rotation_degrees = float(record.get("rotation_degrees", 0.0))
	sprite.flip_h = bool(record.get("flip_h", false))
	sprite.flip_v = bool(record.get("flip_v", false))
	sprite.modulate = transform_result.get("modulate", Color.WHITE) as Color
	sprite.z_index = z_index
	parent.add_child(sprite)
	return {"valid": true}


func _add_sorted_plan_sprite(record: Dictionary) -> Dictionary:
	var texture_result := _load_record_texture(record)
	if not bool(texture_result.get("valid", false)):
		return texture_result
	var transform_result := _read_plan_transform(record)
	if not bool(transform_result.get("valid", false)):
		return transform_result
	var wrapper := _new_sort_item(str(record.get("id", "")), "decor")
	var anchor := transform_result.get("world_position", Vector2.ZERO) as Vector2
	var source_anchor := transform_result.get("source_anchor_pixels", Vector2.ZERO) as Vector2
	var world_scale := transform_result.get("world_scale", Vector2.ONE) as Vector2
	wrapper.position = anchor
	wrapper.set_meta("sort_anchor_world", anchor)
	var sprite := _new_sprite("Sprite", null)
	sprite.texture = texture_result.get("texture", null) as Texture2D
	sprite.position = -source_anchor * world_scale
	sprite.scale = world_scale
	sprite.modulate = transform_result.get("modulate", Color.WHITE) as Color
	sprite.set_meta("expected_modulate", sprite.modulate)
	wrapper.add_child(sprite)
	_sort_root.add_child(wrapper)
	_decor_items.append(wrapper)
	return {"valid": true}


func _add_building(spec: Dictionary) -> Dictionary:
	var building_type := str(spec.get("type", ""))
	var visual_value: Variant = spec.get("visual_rect", null)
	var anchor_value: Variant = spec.get("sort_anchor_world", null)
	var sign_color_value: Variant = spec.get("sign_glow_color", null)
	var window_color_value: Variant = spec.get("window_glow_color", null)
	var sign_strength_value: Variant = spec.get("sign_glow_strength", null)
	var window_strength_value: Variant = spec.get("window_glow_strength", null)
	if building_type == "" or not (visual_value is Rect2) or not (anchor_value is Vector2):
		return _invalid("building_geometry_type_invalid")
	if not (sign_color_value is Color) or not (window_color_value is Color):
		return _invalid("building_glow_color_type_invalid")
	if not _nonnegative_finite_number(sign_strength_value) or not _nonnegative_finite_number(window_strength_value):
		return _invalid("building_glow_strength_invalid")
	var visual_rect := visual_value as Rect2
	var anchor := anchor_value as Vector2
	var sign_color := sign_color_value as Color
	var window_color := window_color_value as Color
	if not _finite_rect(visual_rect) or not visual_rect.has_area() or not anchor.is_finite():
		return _invalid("building_geometry_invalid")
	if not _finite_color(sign_color) or not _finite_color(window_color):
		return _invalid("building_glow_color_invalid")
	var wrapper := _new_sort_item("Building_%s" % building_type, "building")
	wrapper.position = anchor
	wrapper.set_meta("building_type", building_type)
	wrapper.set_meta("sort_anchor_world", anchor)
	wrapper.set_meta("sign_glow_color", sign_color)
	wrapper.set_meta("window_glow_color", window_color)
	wrapper.set_meta("sign_glow_strength", float(sign_strength_value))
	wrapper.set_meta("window_glow_strength", float(window_strength_value))
	for layer in [
		{"name": "Base", "key": "base_texture", "material": _mix_material},
		{"name": "SignEmissive", "key": "sign_texture", "material": _add_material},
		{"name": "WindowGlowMask", "key": "window_texture", "material": _add_material},
	]:
		var texture_value: Variant = spec.get(str(layer.get("key", "")), null)
		if not (texture_value is Texture2D):
			wrapper.free()
			return _invalid("building_texture_missing")
		var sprite := _new_sprite(str(layer.get("name", "")), layer.get("material", null))
		var texture := texture_value as Texture2D
		sprite.texture = texture
		sprite.position = visual_rect.position - anchor
		sprite.scale = visual_rect.size / Vector2(texture.get_width(), texture.get_height())
		wrapper.add_child(sprite)
	_sort_root.add_child(wrapper)
	_building_items.append(wrapper)
	return {"valid": true}


func _build_actor_items() -> void:
	_player_item = _new_sort_item("Player", "player")
	_add_contact_shadow(_player_item, 24.0, 8.5)
	_player_sprite = _new_sprite("Sprite", null)
	_player_sprite.region_enabled = true
	_player_item.add_child(_player_sprite)
	_sort_root.add_child(_player_item)
	if not _guardian_enabled:
		return
	_guardian_item = _new_sort_item("Guardian", "guardian")
	_add_contact_shadow(_guardian_item, maxf(14.0, _guardian_draw_size_world * 0.26), maxf(5.0, _guardian_draw_size_world * 0.095))
	_guardian_sprite = _new_sprite("Sprite", null)
	_guardian_sprite.region_enabled = true
	_guardian_item.add_child(_guardian_sprite)
	_sort_root.add_child(_guardian_item)


func _apply_projection(projection: Dictionary) -> void:
	var safe_rect := projection.get("safe_rect", Rect2()) as Rect2
	var origin := projection.get("screen_origin", Vector2.ZERO) as Vector2
	var projection_scale := float(projection.get("projection_scale", 1.0))
	position = Vector2.ZERO
	size = safe_rect.end
	_clip_host.position = safe_rect.position
	_clip_host.size = safe_rect.size
	_world_root.position = origin - safe_rect.position
	_world_root.scale = Vector2.ONE * projection_scale


func _apply_player_frame(world_position: Vector2, moving: bool, facing: int, ticks_msec: int) -> void:
	_restore_sort_item(_player_item)
	_player_item.position = world_position
	_player_item.set_meta("sort_anchor_world", world_position)
	var texture_key := PlazaActorRenderer.get_player_texture_key(_player_textures, moving, facing)
	var texture := _player_textures.get(texture_key, null) as Texture2D
	var frame_count := maxi(1, int(_player_textures.get("frame_count", 1)))
	var frame := PlazaActorVisualProjection.get_player_sprite_frame(ticks_msec, moving, frame_count)
	var cols := maxi(1, int(_player_textures.get("grid_cols", 1)))
	var rows := maxi(1, int(_player_textures.get("grid_rows", 1)))
	var region := PlazaActorVisualProjection.get_sheet_frame_rect(texture.get_size(), frame, cols, rows)
	_restore_sprite(_player_sprite, null)
	_player_sprite.texture = texture
	_player_sprite.region_enabled = true
	_player_sprite.region_rect = region
	_player_sprite.position = PLAYER_FOOT_OFFSET_WORLD - Vector2(PLAYER_DRAW_SIZE_WORLD.x * 0.5, PLAYER_DRAW_SIZE_WORLD.y)
	_player_sprite.scale = PLAYER_DRAW_SIZE_WORLD / region.size
	_player_sprite.visible = true
	_restore_contact_shadow(_player_item)


func _apply_guardian_frame(world_position: Vector2, ticks_msec: int) -> void:
	_restore_sort_item(_guardian_item)
	_guardian_item.position = world_position
	_guardian_item.set_meta("sort_anchor_world", world_position)
	var frame := PlazaActorVisualProjection.get_loop_frame(ticks_msec, PlazaActorVisualProjection.LINGPET_COMPANION_LOOP_MSEC, _guardian_frame_count)
	var region := PlazaActorVisualProjection.get_sheet_frame_rect(_guardian_texture.get_size(), frame, _guardian_grid_cols, _guardian_grid_rows)
	_restore_sprite(_guardian_sprite, null)
	_guardian_sprite.texture = _guardian_texture
	_guardian_sprite.region_enabled = true
	_guardian_sprite.region_rect = region
	_guardian_sprite.position = Vector2(-_guardian_draw_size_world * 0.5, -_guardian_draw_size_world + 8.0)
	_guardian_sprite.scale = Vector2.ONE * (_guardian_draw_size_world / maxf(1.0, region.size.x))
	_guardian_sprite.visible = true
	_restore_contact_shadow(_guardian_item)


func _update_building_glow(ticks_msec: int) -> void:
	for item in _building_items:
		var building_type := str(item.get_meta("building_type", ""))
		var pulse := PlazaBackgroundProjection.discrete_flicker("r3b:%s" % building_type, ticks_msec)
		var sign := item.get_node("SignEmissive") as Sprite2D
		var window := item.get_node("WindowGlowMask") as Sprite2D
		_restore_sprite(sign, _add_material)
		_restore_sprite(window, _add_material)
		var sign_color := item.get_meta("sign_glow_color", Color.WHITE) as Color
		var window_color := item.get_meta("window_glow_color", Color.WHITE) as Color
		var sign_strength := float(item.get_meta("sign_glow_strength", 1.0))
		var window_strength := float(item.get_meta("window_glow_strength", 1.0))
		sign.modulate = _glow_modulate(sign_color, sign_strength, 0.72 + pulse * 0.22)
		window.modulate = _glow_modulate(window_color, window_strength, 0.56 + pulse * 0.12)


func _load_record_texture(record: Dictionary) -> Dictionary:
	var path := str(record.get("texture_path", ""))
	if path == "":
		return _invalid("environment_texture_path_missing")
	var value: Variant = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if not (value is Texture2D):
		return _invalid("environment_texture_load_failed")
	return {"valid": true, "texture": value as Texture2D}


func _read_plan_transform(record: Dictionary) -> Dictionary:
	var position_value: Variant = record.get("world_position", null)
	var anchor_value: Variant = record.get("source_anchor_pixels", null)
	var scale_value: Variant = record.get("world_scale", null)
	var modulate_value: Variant = record.get("modulate", Color.WHITE)
	if not (position_value is Vector2) or not (anchor_value is Vector2) or not (scale_value is Vector2):
		return _invalid("environment_transform_type_invalid")
	if not (modulate_value is Color):
		return _invalid("environment_modulate_type_invalid")
	var world_position := position_value as Vector2
	var source_anchor := anchor_value as Vector2
	var world_scale := scale_value as Vector2
	var modulate := modulate_value as Color
	if not world_position.is_finite() or not source_anchor.is_finite() or not world_scale.is_finite():
		return _invalid("environment_transform_nonfinite")
	if not _finite_color(modulate):
		return _invalid("environment_modulate_nonfinite")
	if world_scale.x <= 0.0 or world_scale.y <= 0.0:
		return _invalid("environment_scale_invalid")
	return {
		"valid": true,
		"world_position": world_position,
		"source_anchor_pixels": source_anchor,
		"world_scale": world_scale,
		"modulate": modulate,
	}


func _new_sort_item(node_name: String, role: String) -> Node2D:
	var item := Node2D.new()
	item.name = node_name
	item.set_meta("sort_role", role)
	_restore_sort_item(item)
	return item


func _new_sprite(node_name: String, material_value: Variant) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	var expected_material: Material = material_value as Material if material_value is Material else null
	_restore_sprite(sprite, expected_material)
	return sprite


func _add_contact_shadow(parent: Node2D, radius_x: float, radius_y: float) -> void:
	var shadow := Polygon2D.new()
	shadow.name = "ContactShadow"
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(cos(angle) * radius_x, 6.0 + sin(angle) * radius_y))
	shadow.polygon = points
	shadow.color = Color(0.0, 0.0, 0.0, 0.18)
	_restore_canvas_item(shadow)
	parent.add_child(shadow)


func _restore_contact_shadow(item: Node2D) -> void:
	var shadow := item.get_node("ContactShadow") as Polygon2D
	_restore_canvas_item(shadow)
	shadow.material = null
	shadow.color = Color(0.0, 0.0, 0.0, 0.18)
	shadow.visible = true


func _restore_sort_item(item: Node2D) -> void:
	_restore_canvas_item(item)
	item.material = null
	item.y_sort_enabled = false
	item.modulate = Color.WHITE


func _restore_sprite(sprite: Sprite2D, expected_material: Material = null) -> void:
	_restore_canvas_item(sprite)
	sprite.material = expected_material
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.modulate = Color.WHITE
	sprite.visible = true


func _restore_canvas_item(item: CanvasItem) -> void:
	item.z_index = 0
	item.z_as_relative = true
	item.top_level = false
	item.use_parent_material = false
	item.self_modulate = Color.WHITE
	item.show_behind_parent = false
	item.visible = true


func _node_contract_valid(item: Node2D) -> bool:
	return (
		_canvas_contract_valid(item)
		and item.material == null
		and not item.y_sort_enabled
		and item.modulate.is_equal_approx(Color.WHITE)
		and item.visible
	)


func _canvas_contract_valid(item: CanvasItem) -> bool:
	return (
		item.z_index == 0
		and item.z_as_relative
		and not item.top_level
		and not item.use_parent_material
		and item.self_modulate.is_equal_approx(Color.WHITE)
		and not item.show_behind_parent
		and item.visible
	)


func _restore_scene_root_contracts() -> void:
	for item in [_world_root, _background_root, _sort_root]:
		if item == null:
			continue
		_restore_canvas_item(item)
		item.material = null
		item.modulate = Color.WHITE
	_world_root.y_sort_enabled = false
	_background_root.y_sort_enabled = false
	_sort_root.y_sort_enabled = true


func _restore_static_sort_contracts() -> void:
	for item in _decor_items:
		_restore_sort_item(item)
		if item.has_node("Sprite"):
			var sprite := item.get_node("Sprite") as Sprite2D
			_restore_sprite(sprite, null)
			sprite.modulate = sprite.get_meta("expected_modulate", Color.WHITE) as Color
	for item in _building_items:
		_restore_sort_item(item)
		_restore_sprite(item.get_node("Base") as Sprite2D, _mix_material)
		_restore_sprite(item.get_node("SignEmissive") as Sprite2D, _add_material)
		_restore_sprite(item.get_node("WindowGlowMask") as Sprite2D, _add_material)


func _root_contract_valid(item: Node2D) -> bool:
	return (
		_canvas_contract_valid(item)
		and item.material == null
		and item.modulate.is_equal_approx(Color.WHITE)
	)


func _clear_bound_nodes() -> void:
	for parent in [_background_root, _sort_root]:
		if parent == null:
			continue
		for child in parent.get_children():
			parent.remove_child(child)
			child.free()
	_building_items.clear()
	_decor_items.clear()
	_player_item = null
	_guardian_item = null
	_player_sprite = null
	_guardian_sprite = null
	_player_textures.clear()
	_guardian_texture = null
	_guardian_enabled = false


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value as Array:
		if entry is Dictionary:
			result.append(entry as Dictionary)
	return result


func _finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


func _positive_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)) and float(value) > 0.0


func _nonnegative_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)) and float(value) >= 0.0


func _finite_color(color: Color) -> bool:
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)


func _glow_modulate(color: Color, strength: float, pulse: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(color.a * pulse * strength, 0.0, 4.0))


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}


func _reject(reason: String) -> bool:
	_rejection_reason = reason
	set_active(false)
	return false
