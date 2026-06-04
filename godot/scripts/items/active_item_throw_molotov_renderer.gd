extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MolotovFxHost := preload("res://scripts/items/active_item_molotov_fx_host.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const MOLOTOV_ICON_PATH := ActiveItemCatalog.MOLOTOV_ICON_PATH
const MOLOTOV_DRAW_SIZE := 36.0
const MOLOTOV_FIRE_DURATION_FRAMES := 150.0
const MOLOTOV_FIRE_ALPHA_CUTOFF := 0.015
const MOLOTOV_FX_HOST_POOL_SIZE := 3
const MOLOTOV_FX_HOST_NAME_PREFIX := "ActiveItemMolotovFxHost"
const MOLOTOV_PLAYFIELD_GAME_WIDTH := 760.0
const MOLOTOV_PLAYFIELD_GAME_HEIGHT := 750.0
const FILLED_ELLIPSE_SEGMENTS := 32

static var _filled_ellipse_mesh: ArrayMesh = null

var molotov_icon_texture: Texture2D

@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts: Array = []
@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts_zone_ids: Array = []
@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts_burst_triggered: Array = []
@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts_canvas: Object = null

var _molotov_view_layout: Object = null
var _molotov_view_cached_viewport_size: Vector2 = Vector2.ZERO
var _molotov_view_cached_game_offset: Vector2 = Vector2.ZERO
var _molotov_view_cached_render_scale: float = 1.0
var _flame_additive_material: CanvasItemMaterial = null

# Host-node name prefix. Configurable so other fire-zone owners (e.g. the Red
# Dragon lingpet breath) can reuse this exact molotov fire-zone effect with a
# SEPARATE host pool instead of fighting over the same nodes as the molotov item.
var _fx_host_name_prefix: String = MOLOTOV_FX_HOST_NAME_PREFIX


func set_fx_host_name_prefix(prefix: String) -> void:
	var trimmed := prefix.strip_edges()
	if trimmed != "":
		_fx_host_name_prefix = trimmed


# Public cleanup for reusers that hold this renderer outside the per-frame draw
# loop (no canvas needed): tear all owned fire-zone hosts down to hidden.
func deactivate_all_hosts() -> void:
	_deactivate_all_molotov_hosts()


func prewarm_assets() -> void:
	MolotovFxHost.prewarm_assets()
	ImpactFlareTextureCache.prewarm()
	_touch_texture(get_molotov_icon_texture())
	_get_filled_ellipse_mesh()


func draw_molotovs(canvas: CanvasItem, molotovs: Array, shake_offset: Vector2) -> void:
	if molotovs.is_empty():
		return
	var texture: Texture2D = get_molotov_icon_texture()
	for molotov_value in molotovs:
		if not (molotov_value is Dictionary):
			continue
		var molotov: Dictionary = molotov_value
		_draw_projectile_trail_with_hot_core(
			canvas,
			molotov.get("trail", []),
			shake_offset,
			3.0,
			Color(1.0, 120.0 / 255.0, 30.0 / 255.0, 1.0),
			0.28,
			1.8,
			Color(1.0, 220.0 / 255.0, 80.0 / 255.0, 1.0),
			Vector2(0.0, -2.0),
			0.21
		)

		var center: Vector2 = _get_vector2(molotov, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(molotov.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(MOLOTOV_DRAW_SIZE, MOLOTOV_DRAW_SIZE),
				angle
			)
		else:
			draw_molotov_fallback(canvas, center, angle, 1.0)


func draw_molotov_fire_zones(canvas: CanvasItem, fire_zones: Array, shake_offset: Vector2) -> void:
	_sync_molotov_fx_hosts(canvas, fire_zones, shake_offset)
	if fire_zones.is_empty():
		return
	for zone_value in fire_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var width: float = float(zone.get("width", 150.0))
		var height: float = float(zone.get("height", 60.0))
		var max_duration: float = max(1.0, float(zone.get("max_duration_frames", MOLOTOV_FIRE_DURATION_FRAMES)))
		var remaining: float = clamp(float(zone.get("duration_frames", max_duration)), 0.0, max_duration)
		var life_ratio: float = clamp(remaining / max_duration, 0.0, 1.0)
		var has_host: bool = _is_zone_handled_by_host(int(zone.get("zone_id", 0)))

		if not has_host:
			var outer_rect := Rect2(center - Vector2(width * 0.5 + 20.0, height * 0.5 + 15.0), Vector2(width + 40.0, height + 30.0))
			_draw_filled_ellipse(canvas, outer_rect, Color(20.0 / 255.0, 10.0 / 255.0, 5.0 / 255.0, 0.20 * life_ratio))
			_draw_filled_ellipse(canvas, Rect2(center - Vector2(width * 0.43, height * 0.43), Vector2(width * 0.86, height * 0.86)), Color(150.0 / 255.0, 40.0 / 255.0, 10.0 / 255.0, 0.30 * life_ratio))
			_draw_filled_ellipse(canvas, Rect2(center - Vector2(width * 0.30, height * 0.30), Vector2(width * 0.60, height * 0.60)), Color(1.0, 100.0 / 255.0, 20.0 / 255.0, 0.38 * life_ratio))

			var time_phase: float = float(Time.get_ticks_msec()) / 100.0
			for wave_i in range(2):
				var wave_alpha: float = 0.16 * life_ratio * (1.0 - float(wave_i) * 0.18)
				if wave_alpha <= 0.01:
					continue
				var wave_w: float = width * (0.9 - float(wave_i) * 0.1)
				var wave_h: float = max(2.0, 8.0 - float(wave_i))
				var wave_y: float = sin(time_phase + float(wave_i) * 0.8) * 3.0
				_draw_filled_ellipse(
					canvas,
					Rect2(center + Vector2(-wave_w * 0.5, -height * 0.5 - 15.0 - float(wave_i) * 8.0 + wave_y), Vector2(wave_w, wave_h)),
					Color(1.0, 200.0 / 255.0, 100.0 / 255.0, wave_alpha)
				)

		var flames: Array = zone.get("flames", [])
		if not flames.is_empty():
			# Busy multi-layer flickering flames (ported from the original
			# pingfighter "고퀄리티 드래곤 브레스" effect) draw additively so they stack
			# as bright living fire over the shader floor/dome host.
			var flame_alpha_scale: float = 0.72 if has_host else 1.0
			var prev_flame_material: Material = canvas.material
			canvas.material = _get_flame_additive_material()
			for flame_value in flames:
				if flame_value is Dictionary:
					_draw_molotov_flame(canvas, flame_value, shake_offset, life_ratio * flame_alpha_scale)
			canvas.material = prev_flame_material


func draw_molotov_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var bottle_top: Vector2 = _rotated_local(center, Vector2(0.0, -14.0 * scale), angle)
	var bottle_bottom: Vector2 = _rotated_local(center, Vector2(0.0, 12.0 * scale), angle)
	canvas.draw_line(bottle_top, bottle_bottom, Color(45.0 / 255.0, 95.0 / 255.0, 60.0 / 255.0, 1.0), max(4.0, 7.0 * scale))
	canvas.draw_line(bottle_top, bottle_bottom, Color(75.0 / 255.0, 150.0 / 255.0, 90.0 / 255.0, 0.65), max(2.0, 4.0 * scale))
	canvas.draw_circle(bottle_bottom, 8.0 * scale, Color(35.0 / 255.0, 70.0 / 255.0, 45.0 / 255.0, 1.0))
	canvas.draw_circle(bottle_bottom + Vector2(-2.0, -2.0) * scale, 4.0 * scale, Color(120.0 / 255.0, 190.0 / 255.0, 120.0 / 255.0, 0.35))
	var flame_tip: Vector2 = _rotated_local(center, Vector2(0.0, -22.0 * scale), angle)
	canvas.draw_circle(flame_tip, 6.0 * scale, Color(1.0, 90.0 / 255.0, 20.0 / 255.0, 0.95))
	canvas.draw_circle(flame_tip + Vector2(0.0, -2.0) * scale, 3.0 * scale, Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 0.92))


func get_molotov_icon_texture() -> Texture2D:
	if molotov_icon_texture == null:
		molotov_icon_texture = ProjectResourceLoader.load_texture(
			MOLOTOV_ICON_PATH,
			"Missing molotov icon at %s",
			"Failed to load molotov icon at %s"
		)
	return molotov_icon_texture


func _sync_molotov_fx_hosts(canvas: CanvasItem, fire_zones: Array, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	if not _is_molotov_host_quality_ok():
		_deactivate_all_molotov_hosts()
		return
	_ensure_molotov_host_pool(canvas)
	if _molotov_fx_hosts.is_empty():
		return
	var playfield_game_offset: Vector2 = _molotov_view_cached_game_offset
	var playfield_render_scale: float = _molotov_view_cached_render_scale
	if not fire_zones.is_empty():
		var layout: Dictionary = _get_molotov_playfield_layout(canvas)
		playfield_game_offset = layout.get("game_offset", Vector2.ZERO)
		playfield_render_scale = max(0.001, float(layout.get("render_scale", 1.0)))

	var slot_used: Array = []
	slot_used.resize(_molotov_fx_hosts.size())
	for slot_idx in range(slot_used.size()):
		slot_used[slot_idx] = false

	var assigned: Array = []
	assigned.resize(fire_zones.size())
	for zone_idx in range(fire_zones.size()):
		assigned[zone_idx] = -1
		var zone_value: Variant = fire_zones[zone_idx]
		if not (zone_value is Dictionary):
			continue
		var zone_id: int = int(zone_value.get("zone_id", 0))
		if zone_id <= 0:
			continue
		for slot_idx in range(_molotov_fx_hosts.size()):
			if slot_used[slot_idx]:
				continue
			if int(_molotov_fx_hosts_zone_ids[slot_idx]) == zone_id:
				assigned[zone_idx] = slot_idx
				slot_used[slot_idx] = true
				break

	for zone_idx in range(fire_zones.size()):
		if assigned[zone_idx] >= 0:
			continue
		var zone_value: Variant = fire_zones[zone_idx]
		if not (zone_value is Dictionary):
			continue
		var zone_id: int = int(zone_value.get("zone_id", 0))
		if zone_id <= 0:
			continue
		for slot_idx in range(_molotov_fx_hosts.size()):
			if slot_used[slot_idx]:
				continue
			assigned[zone_idx] = slot_idx
			slot_used[slot_idx] = true
			_molotov_fx_hosts_zone_ids[slot_idx] = zone_id
			_molotov_fx_hosts_burst_triggered[slot_idx] = false
			break

	for slot_idx in range(_molotov_fx_hosts.size()):
		var host: Object = _molotov_fx_hosts[slot_idx]
		if host == null or not is_instance_valid(host):
			continue
		if not slot_used[slot_idx]:
			if host.has_method("set_active"):
				host.set_active(false)
			_molotov_fx_hosts_zone_ids[slot_idx] = 0
			_molotov_fx_hosts_burst_triggered[slot_idx] = false

	for zone_idx in range(fire_zones.size()):
		var slot_idx: int = assigned[zone_idx]
		if slot_idx < 0:
			continue
		var zone_value: Variant = fire_zones[zone_idx]
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		var host: Object = _molotov_fx_hosts[slot_idx]
		if host == null or not is_instance_valid(host):
			continue
		var center_game: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var width: float = float(zone.get("width", 150.0))
		var height: float = float(zone.get("height", 60.0))
		var max_duration: float = max(1.0, float(zone.get("max_duration_frames", MOLOTOV_FIRE_DURATION_FRAMES)))
		var remaining: float = clamp(float(zone.get("duration_frames", max_duration)), 0.0, max_duration)
		var life_ratio: float = clamp(remaining / max_duration, 0.0, 1.0)
		var age_frames: float = float(zone.get("age_frames", 0.0))
		if not bool(_molotov_fx_hosts_burst_triggered[slot_idx]) and age_frames < 4.0:
			if host.has_method("trigger_explosion_burst"):
				host.trigger_explosion_burst()
			_molotov_fx_hosts_burst_triggered[slot_idx] = true
		var center_screen: Vector2 = playfield_game_offset + center_game * playfield_render_scale
		var host_state := {
			"zone_pos": center_screen,
			"width": width,
			"height": height,
			"life_ratio": life_ratio,
			"age_frames": age_frames,
			"render_scale": playfield_render_scale,
			"quality_scale": 1.0,
		}
		if host.has_method("sync_state"):
			host.sync_state(host_state, life_ratio > 0.0)


func _is_zone_handled_by_host(zone_id: int) -> bool:
	if zone_id <= 0:
		return false
	for slot_idx in range(_molotov_fx_hosts_zone_ids.size()):
		if int(_molotov_fx_hosts_zone_ids[slot_idx]) != zone_id:
			continue
		var host: Object = _molotov_fx_hosts[slot_idx]
		if host == null or not is_instance_valid(host):
			return false
		return bool(host.visible)
	return false


func _is_molotov_host_quality_ok() -> bool:
	return true


func _ensure_molotov_host_pool(canvas: CanvasItem) -> void:
	if _molotov_fx_hosts_canvas == canvas and _molotov_fx_hosts.size() == MOLOTOV_FX_HOST_POOL_SIZE:
		var all_valid := true
		for host in _molotov_fx_hosts:
			if host == null or not is_instance_valid(host):
				all_valid = false
				break
		if all_valid:
			return
	if not (canvas is Node):
		return
	var parent: Node = canvas as Node
	_molotov_fx_hosts.clear()
	_molotov_fx_hosts_zone_ids.clear()
	_molotov_fx_hosts_burst_triggered.clear()
	_molotov_fx_hosts_canvas = canvas
	for slot_idx in range(MOLOTOV_FX_HOST_POOL_SIZE):
		var host_name: String = "%s%d" % [_fx_host_name_prefix, slot_idx]
		var existing: Node = parent.get_node_or_null(host_name)
		var host: Node
		if existing != null and is_instance_valid(existing):
			host = existing
		else:
			host = MolotovFxHost.new()
			host.name = host_name
			host.visible = false
			parent.call_deferred("add_child", host)
		_molotov_fx_hosts.append(host)
		_molotov_fx_hosts_zone_ids.append(0)
		_molotov_fx_hosts_burst_triggered.append(false)


func _deactivate_all_molotov_hosts() -> void:
	for slot_idx in range(_molotov_fx_hosts.size()):
		var host: Object = _molotov_fx_hosts[slot_idx]
		if host != null and is_instance_valid(host) and host.has_method("set_active"):
			host.set_active(false)
		_molotov_fx_hosts_zone_ids[slot_idx] = 0
		_molotov_fx_hosts_burst_triggered[slot_idx] = false


func _get_molotov_playfield_layout(canvas: CanvasItem) -> Dictionary:
	# FX hosts are child nodes, so they need the same screen-space projection
	# that the playfield draw transform applies to direct canvas draws.
	if canvas == null:
		return {"game_offset": Vector2.ZERO, "render_scale": 1.0}
	var viewport_rect: Rect2 = canvas.get_viewport_rect()
	var viewport_size: Vector2 = viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return {"game_offset": Vector2.ZERO, "render_scale": 1.0}
	if (
		not viewport_size.is_equal_approx(_molotov_view_cached_viewport_size)
		or _molotov_view_layout == null
	):
		if _molotov_view_layout == null:
			_molotov_view_layout = BattleViewLayout.new()
		var layout: Dictionary = _molotov_view_layout.build_game_layout(
			viewport_size,
			MOLOTOV_PLAYFIELD_GAME_WIDTH,
			MOLOTOV_PLAYFIELD_GAME_HEIGHT
		)
		_molotov_view_cached_viewport_size = viewport_size
		var layout_offset_value: Variant = layout.get("game_offset", Vector2.ZERO)
		_molotov_view_cached_game_offset = (
			layout_offset_value if layout_offset_value is Vector2 else Vector2.ZERO
		)
		_molotov_view_cached_render_scale = max(0.001, float(layout.get("render_scale", 1.0)))
	return {
		"game_offset": _molotov_view_cached_game_offset,
		"render_scale": _molotov_view_cached_render_scale,
	}


func _get_flame_additive_material() -> CanvasItemMaterial:
	if _flame_additive_material == null:
		_flame_additive_material = CanvasItemMaterial.new()
		_flame_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _flame_additive_material


# Single flickering flame tongue: four soft additive layers (dark-red smoke ->
# red/orange -> orange/yellow -> yellow-white core) plus a rising trail and the
# occasional spark -- the original pingfighter multi-layer flame look. Drawn with
# the additive material already bound by the caller.
func _draw_molotov_flame(canvas: CanvasItem, flame: Dictionary, shake_offset: Vector2, zone_life: float) -> void:
	var center: Vector2 = _get_vector2(flame, "position", Vector2.ZERO) + shake_offset
	var size: float = max(2.0, float(flame.get("size", 8.0)))
	var lifetime: float = max(0.0, float(flame.get("lifetime_frames", 20.0)))
	var max_lifetime: float = max(1.0, float(flame.get("max_lifetime_frames", 40.0)))
	var fl_ratio: float = clamp(lifetime / max_lifetime, 0.0, 1.0)
	var draw_life: float = fl_ratio * zone_life
	if draw_life <= MOLOTOV_FIRE_ALPHA_CUTOFF:
		return
	var cp: float = float(flame.get("color_phase", 0.0))
	var glow: Texture2D = ImpactFlareTextureCache.get_glow_texture()
	if glow == null:
		return
	for layer in range(4):
		var lr: float = float(layer) / 3.0
		var layer_size: float = max(2.0, size * (1.0 - lr * 0.45))
		var col: Color = _flame_layer_color(layer, cp, draw_life)
		var wobble := Vector2(
			sin(cp * 8.0 + float(layer)) * (1.5 + float(layer) * 0.5),
			cos(cp * 6.0 + float(layer) * 0.5) * (1.0 + float(layer) * 0.3) - float(layer) * 2.0
		)
		_draw_flame_glow(canvas, glow, center + wobble, layer_size * 2.3, col)
	# Rising trail above larger, younger flames.
	if fl_ratio > 0.4 and size > 8.0:
		for t in range(2):
			var trail_size: float = max(2.0, size * 0.28 * (1.0 - float(t) * 0.3))
			var trail_alpha: float = 0.22 * draw_life * (1.0 - float(t) * 0.4)
			_draw_flame_glow(canvas, glow, center + Vector2(0.0, -size - float(t) * 6.0), trail_size * 2.4, Color(1.0, 0.70, 0.31, trail_alpha))
	# Occasional bright spark.
	if randf() < 0.10 * fl_ratio:
		var spark_off := Vector2(randf_range(-size, size), randf_range(-size * 1.5, size * 0.5))
		_draw_flame_glow(canvas, glow, center + spark_off, randf_range(3.0, 5.0), Color(1.0, 0.98, 0.86, 0.85 * draw_life))


func _flame_layer_color(layer: int, cp: float, life: float) -> Color:
	match layer:
		0:
			return Color(clampf((120.0 + 40.0 * sin(cp * 3.0)) / 255.0, 0.0, 1.0), 30.0 / 255.0, 10.0 / 255.0, clampf(0.31 * life, 0.0, 1.0))
		1:
			return Color(clampf((220.0 + 35.0 * sin(cp * 4.0)) / 255.0, 0.0, 1.0), clampf((60.0 + 40.0 * sin(cp * 5.0)) / 255.0, 0.0, 1.0), 10.0 / 255.0, clampf(0.55 * life, 0.0, 1.0))
		2:
			return Color(1.0, clampf((150.0 + 60.0 * sin(cp * 4.0)) / 255.0, 0.0, 1.0), clampf((30.0 + 30.0 * sin(cp * 6.0)) / 255.0, 0.0, 1.0), clampf(0.70 * life, 0.0, 1.0))
		_:
			return Color(1.0, clampf((230.0 + 25.0 * sin(cp * 3.0)) / 255.0, 0.0, 1.0), clampf((150.0 + 80.0 * sin(cp * 5.0)) / 255.0, 0.0, 1.0), clampf(0.78 * life, 0.0, 1.0))


func _draw_flame_glow(canvas: CanvasItem, glow: Texture2D, center: Vector2, size_px: float, color: Color) -> void:
	if size_px <= 0.0 or color.a <= 0.0:
		return
	var s := Vector2(size_px, size_px)
	canvas.draw_texture_rect(glow, Rect2(center - s * 0.5, s), false, color)


func _draw_projectile_trail_with_hot_core(
	canvas: CanvasItem,
	trail: Array,
	shake_offset: Vector2,
	radius: float,
	color: Color,
	alpha_scale: float,
	core_radius: float,
	core_color: Color,
	core_offset: Vector2,
	core_alpha_scale: float
) -> void:
	var trail_count: int = trail.size()
	if trail_count <= 0:
		return
	var stride: int = 2 if trail_count > 5 else 1
	var core_start: int = max(0, trail_count - 3)
	for i in range(0, trail_count, stride):
		var trail_pos: Variant = trail[i]
		if not (trail_pos is Vector2):
			continue
		var trail_point: Vector2 = trail_pos
		var ratio: float = float(i + 1) / float(trail_count)
		var draw_pos: Vector2 = trail_point + shake_offset
		canvas.draw_circle(draw_pos, radius, Color(color.r, color.g, color.b, ratio * alpha_scale))
		if i >= core_start:
			canvas.draw_circle(draw_pos + core_offset, core_radius, Color(core_color.r, core_color.g, core_color.b, ratio * core_alpha_scale))


func _draw_filled_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if color.a <= 0.0 or rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var radius: Vector2 = rect.size * 0.5
	var center: Vector2 = rect.get_center()
	var transform := Transform2D(Vector2(radius.x, 0.0), Vector2(0.0, radius.y), center)
	canvas.draw_mesh(_get_filled_ellipse_mesh(), null, transform, color)


static func _get_filled_ellipse_mesh() -> ArrayMesh:
	if _filled_ellipse_mesh != null:
		return _filled_ellipse_mesh
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	for step in range(FILLED_ELLIPSE_SEGMENTS):
		var angle: float = TAU * float(step) / float(FILLED_ELLIPSE_SEGMENTS)
		vertices.append(Vector3(cos(angle), sin(angle), 0.0))
	for step in range(FILLED_ELLIPSE_SEGMENTS):
		indices.append(0)
		indices.append(step + 1)
		indices.append((step + 1) % FILLED_ELLIPSE_SEGMENTS + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_filled_ellipse_mesh = mesh
	return _filled_ellipse_mesh


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var angle: float = deg_to_rad(angle_degrees)
	var half_size: Vector2 = draw_size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(_rotated_local(center, corner, angle))
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, texture)


func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:
	return center + Vector2(
		local.x * cos(angle) - local.y * sin(angle),
		local.x * sin(angle) + local.y * cos(angle)
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_width()
