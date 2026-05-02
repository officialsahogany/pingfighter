extends RefCounted

const Stage1PillarLayerGeometry := preload("res://scripts/stages/stage1/stage1_pillar_layer_geometry.gd")

var geometry: Object = Stage1PillarLayerGeometry.new()


func draw(
	canvas: CanvasItem,
	cloud_sprite_texture: Texture2D,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	scale_factor: float,
	time: float
) -> void:
	if cloud_sprite_texture == null:
		return
	var h: float = view_size.y
	var left_w: float = max(0.0, game_offset.x)
	var right_x: float = game_offset.x + game_size.x
	var right_w: float = max(0.0, view_size.x - right_x)
	var specs: Array[Dictionary] = [
		{"rect": Rect2(0.0, h * 0.08, max(1.0, left_w), h * 0.22), "sprite": 0, "speed": 0.24, "amp_x": 32.0, "amp_y": 6.0, "phase": 0.0, "flip": false, "center": Vector2(0.50, 0.46), "alpha": 212.0 / 255.0},
		{"rect": Rect2(0.0, h * 0.55, max(1.0, left_w), h * 0.25), "sprite": 3, "speed": 0.19, "amp_x": 38.0, "amp_y": 7.0, "phase": 1.7, "flip": false, "center": Vector2(0.47, 0.48), "alpha": 196.0 / 255.0},
		{"rect": Rect2(right_x, h * 0.09, max(1.0, right_w), h * 0.22), "sprite": 1, "speed": 0.22, "amp_x": -34.0, "amp_y": 6.0, "phase": 2.4, "flip": true, "center": Vector2(0.50, 0.47), "alpha": 212.0 / 255.0},
		{"rect": Rect2(right_x, h * 0.57, max(1.0, right_w), h * 0.25), "sprite": 4, "speed": 0.18, "amp_x": -40.0, "amp_y": 7.0, "phase": 3.6, "flip": true, "center": Vector2(0.53, 0.49), "alpha": 196.0 / 255.0},
	]
	for spec in specs:
		_draw_cloud_spec(canvas, cloud_sprite_texture, view_size, scale_factor, time, spec)


func _draw_cloud_spec(canvas: CanvasItem, texture: Texture2D, view_size: Vector2, scale_factor: float, time: float, spec: Dictionary) -> void:
	var spec_rect: Rect2 = spec["rect"]
	var spec_center: Vector2 = spec["center"]
	var bounds: Rect2 = geometry.clip_rect(spec_rect, view_size)
	if bounds.size.x <= 2.0 or bounds.size.y <= 2.0:
		return
	var source_region: Rect2 = geometry.get_sheet_region(texture, 3, 2, int(spec["sprite"]))
	var layer_bounds := Rect2(bounds.position, bounds.size * Vector2(0.88, 0.86))
	layer_bounds.position += bounds.size * Vector2(0.06, 0.07)
	var dest: Rect2 = geometry.fit_region_rect(source_region, layer_bounds, spec_center)
	var phase_t: float = time * float(spec["speed"]) + float(spec["phase"])
	var offset := Vector2(
		round(sin(phase_t) * float(spec["amp_x"]) * scale_factor),
		round(cos(phase_t * 0.73) * float(spec["amp_y"]) * scale_factor)
	)
	dest.position += offset
	geometry.draw_texture_region(canvas, texture, dest, source_region, float(spec["alpha"]), bool(spec["flip"]))
