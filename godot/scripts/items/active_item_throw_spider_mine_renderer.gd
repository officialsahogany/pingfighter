extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const SPIDER_MINE_ICON_PATH := ActiveItemCatalog.SPIDER_MINE_ICON_PATH
const SPIDER_MINE_CRAWL_SHEET_PATH := "res://assets/sprites/items/spider_mine_crawl_sheet.png"
const SPIDER_MINE_INSTALLED_IDLE_SHEET_PATH := "res://assets/sprites/items/spider_mine_installed_idle_sheet.png"
const SPIDER_MINE_DEPLOY_SHEET_PATH := "res://assets/sprites/items/spider_mine_deploy_sheet.png"
const SPIDER_MINE_DRAW_SIZE := 32.0
const SPIDER_MINE_EXPLOSION_DURATION_FRAMES := 22.0
const SPIDER_MINE_START_DELAY_FRAMES := 60.0
const SPIDER_MINE_EMBED_DELAY_FRAMES := 60.0
const SPIDER_MINE_SELF_DESTRUCT_WARNING_FRAMES := 120.0
const SPIDER_MINE_SELF_DESTRUCT_FAST_FRAMES := 180.0
const SPIDER_MINE_FLASH_INTERVAL_FRAMES := 6.0
const SPIDER_MINE_SHEET_COLUMNS := 4
const SPIDER_MINE_SHEET_FRAME_COUNT := 16
const SPIDER_MINE_SHEET_DRAW_SIZE := 44.0
const SPIDER_MINE_WALL_VISUAL_TUCK := 18.0
const SPIDER_MINE_CRAWL_FRAME_INTERVAL_FRAMES := 4.0
const SPIDER_MINE_IDLE_FRAME_INTERVAL_FRAMES := 6.0
const SPIDER_MINE_CRAWL_STEP_PHASE_PER_FRAME := 0.4
const SPIDER_MINE_GLOW_PHASE_PER_FRAME := 0.08
const SPIDER_MINE_LEG_DXS := [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]
const SPIDER_MINE_LEG_DYS := [8.0, -3.0, 2.0, 2.0, -3.0, 8.0]
const SPIDER_MINE_LEG_PHASES := [0.0, 1.5, 3.0, 0.8, 2.3, 3.8]

var spider_mine_icon_texture: Texture2D
var spider_mine_crawl_sheet_texture: Texture2D
var spider_mine_installed_idle_sheet_texture: Texture2D
var spider_mine_deploy_sheet_texture: Texture2D
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	match _prewarm_step_index:
		0:
			_touch_texture(get_spider_mine_icon_texture())
		1:
			_touch_texture(get_spider_mine_crawl_sheet_texture())
		2:
			_touch_texture(get_spider_mine_installed_idle_sheet_texture())
		3:
			_touch_texture(get_spider_mine_deploy_sheet_texture())
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func get_asset_status() -> Dictionary:
	var crawl_sheet: Texture2D = get_spider_mine_crawl_sheet_texture()
	var installed_idle_sheet: Texture2D = get_spider_mine_installed_idle_sheet_texture()
	var deploy_sheet: Texture2D = get_spider_mine_deploy_sheet_texture()
	return {
		"crawl_sheet_loaded": crawl_sheet != null,
		"installed_idle_sheet_loaded": installed_idle_sheet != null,
		"deploy_sheet_loaded": deploy_sheet != null,
		"crawl_sheet_path": SPIDER_MINE_CRAWL_SHEET_PATH,
		"installed_idle_sheet_path": SPIDER_MINE_INSTALLED_IDLE_SHEET_PATH,
		"deploy_sheet_path": SPIDER_MINE_DEPLOY_SHEET_PATH,
		"sheet_columns": SPIDER_MINE_SHEET_COLUMNS,
		"sheet_frame_count": SPIDER_MINE_SHEET_FRAME_COUNT,
		"sheet_draw_size": SPIDER_MINE_SHEET_DRAW_SIZE,
	}


func draw_spider_mines(canvas: CanvasItem, spider_mines: Array, shake_offset: Vector2) -> void:
	if spider_mines.is_empty():
		return
	for mine_value in spider_mines:
		if not (mine_value is Dictionary):
			continue
		var mine: Dictionary = mine_value
		var state: String = str(mine.get("state", "spawn"))
		var center: Vector2 = _get_vector2(mine, "position", Vector2.ZERO) + Vector2(0.0, float(mine.get("embed_depth", 0.0))) + shake_offset
		var render_center: Vector2 = _get_spider_mine_render_center(center, mine, state)
		if state == "exploding":
			_draw_spider_mine_explosion(canvas, render_center, mine)
			continue

		if state == "embedding":
			var embed_progress: float = 1.0 - clamp(float(mine.get("embed_timer", 0.0)) / SPIDER_MINE_EMBED_DELAY_FRAMES, 0.0, 1.0)
			canvas.draw_circle(render_center, 28.0 * embed_progress, Color(220.0 / 255.0, 160.0 / 255.0, 1.0, 0.35 * embed_progress))

		if state == "armed":
			var armed_time: float = float(mine.get("armed_elapsed", 0.0))
			var flash_interval: float = SPIDER_MINE_FLASH_INTERVAL_FRAMES
			if armed_time >= SPIDER_MINE_SELF_DESTRUCT_FAST_FRAMES:
				flash_interval = max(1.0, SPIDER_MINE_FLASH_INTERVAL_FRAMES / 3.0)
			elif armed_time >= SPIDER_MINE_SELF_DESTRUCT_WARNING_FRAMES:
				flash_interval = max(2.0, SPIDER_MINE_FLASH_INTERVAL_FRAMES / 2.0)
			if armed_time >= SPIDER_MINE_SELF_DESTRUCT_WARNING_FRAMES and int(armed_time / flash_interval) % 2 == 0:
				canvas.draw_circle(render_center, 24.0 + 4.0 * sin(float(Time.get_ticks_msec()) * 0.02), Color(1.0, 80.0 / 255.0, 110.0 / 255.0, 0.42), false, 3.0)

		var sprite_angle_degrees: float = get_spider_mine_sheet_angle_degrees(mine, state)
		var drew_sheet: bool = _draw_spider_mine_sheet(canvas, render_center, mine, state, sprite_angle_degrees)
		if not drew_sheet:
			_draw_spider_mine_legs(canvas, render_center, mine, state)
			var texture: Texture2D = get_spider_mine_icon_texture()
			if texture != null:
				_draw_rotated_texture_region(
					canvas,
					texture,
					Rect2(Vector2.ZERO, texture.get_size()),
					render_center,
					Vector2(SPIDER_MINE_DRAW_SIZE, SPIDER_MINE_DRAW_SIZE),
					sprite_angle_degrees
				)
			else:
				_draw_spider_mine_fallback(canvas, render_center, mine, state, float(mine.get("armed_elapsed", 0.0)), sprite_angle_degrees)

		var beacon_center: Vector2 = _get_spider_mine_beacon_center(render_center, drew_sheet, sprite_angle_degrees)
		var flash_timer: float = float(mine.get("flash_timer", 0.0))
		if flash_timer > 0.0 and int(flash_timer / SPIDER_MINE_FLASH_INTERVAL_FRAMES) % 2 == 0:
			canvas.draw_circle(beacon_center, 13.0, Color(1.0, 200.0 / 255.0, 120.0 / 255.0, 0.55))
		if state == "armed":
			var pulse: float = 0.6 + 0.4 * sin(float(mine.get("armed_elapsed", 0.0)) * 0.18)
			canvas.draw_circle(beacon_center, max(3.0, 5.0 * pulse), Color(1.0, 110.0 / 255.0, 140.0 / 255.0, 0.88))


func draw_spider_mine_particles(canvas: CanvasItem, spider_mine_particles: Array, shake_offset: Vector2) -> void:
	if spider_mine_particles.is_empty():
		return
	for particle_value in spider_mine_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_frames: float = float(particle.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(particle.get("max_life_frames", 34.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= 0.0:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)) * (0.55 + 0.45 * life))
		var color: Color = _get_color(particle.get("color", Color(1.0, 160.0 / 255.0, 90.0 / 255.0, 1.0)), Color(1.0, 160.0 / 255.0, 90.0 / 255.0, 1.0))
		canvas.draw_circle(center, size, Color(color.r, color.g, color.b, color.a * life))


func draw_spider_mine_windup_fallback(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_circle(center, 13.0, Color(58.0 / 255.0, 64.0 / 255.0, 90.0 / 255.0, 1.0))
	canvas.draw_circle(center + Vector2(0.0, -2.0), 5.0, Color(200.0 / 255.0, 90.0 / 255.0, 130.0 / 255.0, 1.0))


func get_spider_mine_icon_texture() -> Texture2D:
	if spider_mine_icon_texture == null:
		spider_mine_icon_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_ICON_PATH,
			"Missing spider mine icon at %s",
			"Failed to load spider mine icon at %s"
		)
	return spider_mine_icon_texture


func get_spider_mine_crawl_sheet_texture() -> Texture2D:
	if spider_mine_crawl_sheet_texture == null:
		spider_mine_crawl_sheet_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_CRAWL_SHEET_PATH,
			"Missing spider mine crawl sheet at %s",
			"Failed to load spider mine crawl sheet at %s"
		)
	return spider_mine_crawl_sheet_texture


func get_spider_mine_installed_idle_sheet_texture() -> Texture2D:
	if spider_mine_installed_idle_sheet_texture == null:
		spider_mine_installed_idle_sheet_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_INSTALLED_IDLE_SHEET_PATH,
			"Missing spider mine installed idle sheet at %s",
			"Failed to load spider mine installed idle sheet at %s"
		)
	return spider_mine_installed_idle_sheet_texture


func get_spider_mine_deploy_sheet_texture() -> Texture2D:
	if spider_mine_deploy_sheet_texture == null:
		spider_mine_deploy_sheet_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_DEPLOY_SHEET_PATH,
			"Missing spider mine deploy sheet at %s",
			"Failed to load spider mine deploy sheet at %s"
		)
	return spider_mine_deploy_sheet_texture


func get_spider_mine_sheet_texture_for_state(state: String) -> Texture2D:
	if state == "floor" or state == "wall":
		return get_spider_mine_crawl_sheet_texture()
	if state == "spawn" or state == "embedding":
		return get_spider_mine_deploy_sheet_texture()
	if state == "armed":
		return get_spider_mine_installed_idle_sheet_texture()
	return get_spider_mine_installed_idle_sheet_texture()


func get_spider_mine_sheet_frame(mine: Dictionary, state: String) -> int:
	if state == "spawn":
		var spawn_progress: float = 1.0 - clamp(float(mine.get("delay_timer", 0.0)) / SPIDER_MINE_START_DELAY_FRAMES, 0.0, 1.0)
		return clamp(int(floor(spawn_progress * float(SPIDER_MINE_SHEET_FRAME_COUNT))), 0, SPIDER_MINE_SHEET_FRAME_COUNT - 1)
	if state == "embedding":
		var embed_progress: float = 1.0 - clamp(float(mine.get("embed_timer", 0.0)) / SPIDER_MINE_EMBED_DELAY_FRAMES, 0.0, 1.0)
		return clamp(int(floor(embed_progress * float(SPIDER_MINE_SHEET_FRAME_COUNT))), 0, SPIDER_MINE_SHEET_FRAME_COUNT - 1)
	if state == "floor" or state == "wall":
		var crawl_elapsed: float = float(mine.get("step_phase", 0.0)) / SPIDER_MINE_CRAWL_STEP_PHASE_PER_FRAME
		return _get_spider_mine_loop_frame(crawl_elapsed, SPIDER_MINE_CRAWL_FRAME_INTERVAL_FRAMES)
	if state == "armed":
		return _get_spider_mine_loop_frame(float(mine.get("armed_elapsed", 0.0)), SPIDER_MINE_IDLE_FRAME_INTERVAL_FRAMES)
	var glow_elapsed: float = float(mine.get("glow_phase", 0.0)) / SPIDER_MINE_GLOW_PHASE_PER_FRAME
	return _get_spider_mine_loop_frame(glow_elapsed, SPIDER_MINE_IDLE_FRAME_INTERVAL_FRAMES)


func get_spider_mine_sheet_angle_degrees(mine: Dictionary, state: String) -> float:
	if state == "wall" or state == "embedding" or state == "armed":
		return 90.0 if str(mine.get("side", "left")) == "left" else -90.0
	return 0.0


func get_spider_mine_sheet_source_rect(texture: Texture2D, frame_index: int) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var frame: int = clamp(frame_index, 0, SPIDER_MINE_SHEET_FRAME_COUNT - 1)
	var column: int = frame % SPIDER_MINE_SHEET_COLUMNS
	var row: int = int(floor(float(frame) / float(SPIDER_MINE_SHEET_COLUMNS)))
	var cell_size := Vector2(
		texture_size.x / float(SPIDER_MINE_SHEET_COLUMNS),
		texture_size.y / float(SPIDER_MINE_SHEET_COLUMNS)
	)
	return Rect2(Vector2(float(column) * cell_size.x, float(row) * cell_size.y), cell_size)


func _get_spider_mine_render_center(center: Vector2, mine: Dictionary, state: String) -> Vector2:
	var should_tuck: bool = state == "wall" or state == "embedding" or state == "armed"
	if state == "exploding":
		var position: Vector2 = _get_vector2(mine, "position", center)
		should_tuck = is_equal_approx(position.x, float(mine.get("wall_x", position.x)))
	if not should_tuck:
		return center
	var wall_dir: float = -1.0 if str(mine.get("side", "left")) == "left" else 1.0
	return center + Vector2(wall_dir * SPIDER_MINE_WALL_VISUAL_TUCK, 0.0)


func _draw_spider_mine_sheet(
	canvas: CanvasItem,
	center: Vector2,
	mine: Dictionary,
	state: String,
	angle_degrees: float
) -> bool:
	var texture: Texture2D = get_spider_mine_sheet_texture_for_state(state)
	if texture == null:
		return false
	var source_rect: Rect2 = get_spider_mine_sheet_source_rect(
		texture,
		get_spider_mine_sheet_frame(mine, state)
	)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	_draw_rotated_texture_region(
		canvas,
		texture,
		source_rect,
		center,
		Vector2(SPIDER_MINE_SHEET_DRAW_SIZE, SPIDER_MINE_SHEET_DRAW_SIZE),
		angle_degrees
	)
	return true


func _get_spider_mine_loop_frame(elapsed_frames: float, frame_interval: float) -> int:
	return int(floor(max(0.0, elapsed_frames) / max(1.0, frame_interval))) % SPIDER_MINE_SHEET_FRAME_COUNT


func _get_spider_mine_beacon_center(center: Vector2, using_sheet: bool, angle_degrees: float) -> Vector2:
	var angle: float = deg_to_rad(angle_degrees)
	if using_sheet:
		return center + Vector2(0.0, -SPIDER_MINE_SHEET_DRAW_SIZE * 0.26).rotated(angle)
	return center + Vector2(0.0, -2.0).rotated(angle)


func _draw_spider_mine_legs(canvas: CanvasItem, center: Vector2, mine: Dictionary, state: String) -> void:
	var leg_visibility: float = 1.0
	if state == "embedding":
		var embed_progress: float = 1.0 - clamp(float(mine.get("embed_timer", 0.0)) / SPIDER_MINE_EMBED_DELAY_FRAMES, 0.0, 1.0)
		leg_visibility = max(0.0, 1.0 - embed_progress)
	elif state == "armed":
		leg_visibility = 0.0
	if leg_visibility <= 0.01:
		return

	var step_phase: float = float(mine.get("step_phase", 0.0))
	var leg_amp: float = 4.4 if state == "floor" or state == "wall" else 1.6
	var contact_dir: float = -1.0 if str(mine.get("side", "left")) == "left" else 1.0
	for i in range(SPIDER_MINE_LEG_DXS.size()):
		var dx: float = SPIDER_MINE_LEG_DXS[i]
		var dy: float = SPIDER_MINE_LEG_DYS[i]
		var phase_shift: float = SPIDER_MINE_LEG_PHASES[i]
		var swing: float = sin(step_phase + phase_shift) * leg_amp
		var base_pos: Vector2
		var tip_pos: Vector2
		if state == "wall" or state == "embedding":
			base_pos = center + Vector2(dx * 0.2, dy * 0.15 + 2.0)
			tip_pos = center + Vector2(
				contact_dir * (SPIDER_MINE_DRAW_SIZE * 0.5 - 3.0),
				dy * 0.6 + cos(step_phase * 0.45 + phase_shift) * 1.6
			)
		else:
			base_pos = center + Vector2(dx * 0.35, 3.0)
			tip_pos = center + Vector2((dx * 1.4 + swing) * leg_visibility, SPIDER_MINE_DRAW_SIZE * 0.5 - 4.0 + cos(step_phase * 0.5 + phase_shift) * (2.4 * leg_visibility))
		var outer_width: float = max(1.0, 5.0 * leg_visibility)
		var inner_width: float = max(1.0, 2.0 * leg_visibility)
		canvas.draw_line(base_pos, tip_pos, Color(30.0 / 255.0, 35.0 / 255.0, 55.0 / 255.0, 1.0), outer_width)
		canvas.draw_line(base_pos + Vector2(0.0, -2.0), tip_pos + Vector2(0.0, -2.0), Color(150.0 / 255.0, 170.0 / 255.0, 220.0 / 255.0, 0.9), inner_width)


func _draw_spider_mine_fallback(canvas: CanvasItem, center: Vector2, mine: Dictionary, state: String, armed_elapsed: float, angle_degrees: float) -> void:
	var glow_strength: float = 0.4 + 0.4 * sin(float(mine.get("glow_phase", 0.0)))
	var angle: float = deg_to_rad(angle_degrees)
	var accent := Color(
		(80.0 + glow_strength * 120.0) / 255.0,
		(40.0 + glow_strength * 60.0) / 255.0,
		(120.0 + glow_strength * 100.0) / 255.0,
		1.0
	)
	canvas.draw_circle(center, 14.0, Color(58.0 / 255.0, 64.0 / 255.0, 90.0 / 255.0, 1.0))
	canvas.draw_circle(center + Vector2(0.0, -1.0).rotated(angle), 10.0, accent)
	if state == "armed":
		var pulse: float = 0.6 + 0.4 * sin(armed_elapsed * 0.18)
		canvas.draw_circle(center + Vector2(0.0, -2.0).rotated(angle), max(3.0, 5.0 * pulse), Color(1.0, 110.0 / 255.0, 140.0 / 255.0, 1.0))
	else:
		canvas.draw_circle(center + Vector2(0.0, -2.0).rotated(angle), 5.0, Color(200.0 / 255.0, 90.0 / 255.0, 130.0 / 255.0, 1.0))


func _draw_spider_mine_explosion(canvas: CanvasItem, center: Vector2, mine: Dictionary) -> void:
	var max_timer: float = max(1.0, float(mine.get("max_explosion_timer", SPIDER_MINE_EXPLOSION_DURATION_FRAMES)))
	var timer: float = clamp(float(mine.get("explosion_timer", max_timer)), 0.0, max_timer)
	var progress: float = 1.0 - timer / max_timer
	var radius: float = 26.0 + progress * 30.0
	var alpha: float = max(0.0, 0.78 * (1.0 - progress))
	canvas.draw_circle(center, radius, Color(1.0, 160.0 / 255.0, 90.0 / 255.0, alpha))
	canvas.draw_circle(center, max(4.0, radius * 0.5), Color(1.0, 230.0 / 255.0, 180.0 / 255.0, alpha * 0.52))
	canvas.draw_circle(center, radius + 8.0, Color(150.0 / 255.0, 110.0 / 255.0, 220.0 / 255.0, alpha * 0.48), false, 3.0)


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


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_width()
