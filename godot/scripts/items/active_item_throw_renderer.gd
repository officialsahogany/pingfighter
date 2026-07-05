extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const GrenadeRenderer := preload("res://scripts/items/active_item_throw_grenade_renderer.gd")
const FlareRenderer := preload("res://scripts/items/active_item_throw_flare_renderer.gd")
const MolotovRenderer := preload("res://scripts/items/active_item_throw_molotov_renderer.gd")
const DynamiteRenderer := preload("res://scripts/items/active_item_throw_dynamite_renderer.gd")
const TearGasRenderer := preload("res://scripts/items/active_item_throw_tear_gas_renderer.gd")
const BoomerangRenderer := preload("res://scripts/items/active_item_throw_boomerang_renderer.gd")
const SpiderMineRenderer := preload("res://scripts/items/active_item_throw_spider_mine_renderer.gd")
const SlipRenderer := preload("res://scripts/items/active_item_throw_slip_renderer.gd")

const TEAR_GAS_ICON_PATH := ActiveItemCatalog.TEAR_GAS_ICON_PATH
const BOOMERANG_ICON_PATH := ActiveItemCatalog.BOOMERANG_ICON_PATH
const BOOMERANG_METAL_ICON_PATH := ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH
const BANANA_ICON_PATH := ActiveItemCatalog.BANANA_ICON_PATH
const SOAP_ICON_PATH := ActiveItemCatalog.SOAP_ICON_PATH
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_DRAW_SIZE := 36.0
const FLARE_THROW_WINDUP_MSEC := 600
const FLARE_DRAW_SIZE := 34.0
const TEAR_GAS_THROW_WINDUP_MSEC := 600
const TEAR_GAS_DRAW_SIZE := 36.0
const TEAR_GAS_RADIUS := 180.0
const TEAR_GAS_RADIUS_X := 240.0
const TEAR_GAS_ARMED_DELAY_FRAMES := 180.0
const TEAR_GAS_ZONE_DURATION_FRAMES := 960.0
const TEAR_GAS_RENDER_PARTICLE_LIMIT := 14
const TEAR_GAS_RENDER_TOTAL_PARTICLE_LIMIT := 22
const TEAR_GAS_PARTICLE_ALPHA_CUTOFF := 0.012
const TEAR_GAS_PUFF_TEXTURE_SIZE := 96
const DYNAMITE_DRAW_SIZE := 46.0
const DYNAMITE_THROW_WINDUP_MSEC := 500
const LOW_THROW_PREVIEW_Y_ADJUSTMENT := -10.0
const MOLOTOV_DRAW_SIZE := 36.0
const MOLOTOV_THROW_WINDUP_MSEC := 600
const BOOMERANG_DRAW_SIZE := 42.0
const BANANA_DRAW_SIZE := 64.0
const BANANA_LANDED_DRAW_SIZE := 72.0
const BANANA_LAND_DURATION_FRAMES := 180.0
const SOAP_DRAW_SIZE := 48.0
const SOAP_LANDED_DRAW_SIZE := 56.0
const SOAP_LAND_DURATION_FRAMES := 240.0
const SOAP_PARTICLE_ALPHA_CUTOFF := 0.02
const SPIDER_MINE_DRAW_SIZE := 32.0
const SPIDER_MINE_THROW_WINDUP_MSEC := 600

var grenade_icon_texture: Texture2D
var flare_icon_texture: Texture2D
var tear_gas_icon_texture: Texture2D
var dynamite_icon_texture: Texture2D
var molotov_icon_texture: Texture2D
var boomerang_icon_texture: Texture2D
var boomerang_metal_icon_texture: Texture2D
var banana_icon_texture: Texture2D
var soap_icon_texture: Texture2D
var spider_mine_icon_texture: Texture2D
var spider_mine_crawl_sheet_texture: Texture2D
var spider_mine_installed_idle_sheet_texture: Texture2D
var spider_mine_deploy_sheet_texture: Texture2D

var _grenade_renderer: Object = GrenadeRenderer.new()
var _flare_renderer: Object = FlareRenderer.new()
var _molotov_renderer: Object = MolotovRenderer.new()
var _dynamite_renderer: Object = DynamiteRenderer.new()
var _tear_gas_renderer: Object = TearGasRenderer.new()
var _boomerang_renderer: Object = BoomerangRenderer.new()
var _spider_mine_renderer: Object = SpiderMineRenderer.new()
var _slip_renderer: Object = SlipRenderer.new()
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	match _prewarm_step_index:
		0:
			_grenade_renderer.prewarm_assets()
			grenade_icon_texture = _grenade_renderer.get_grenade_icon_texture()
		1:
			_flare_renderer.prewarm_assets()
			flare_icon_texture = _flare_renderer.get_flare_icon_texture()
		2:
			_molotov_renderer.prewarm_assets()
			molotov_icon_texture = _molotov_renderer.get_molotov_icon_texture()
		3:
			_dynamite_renderer.prewarm_assets()
			dynamite_icon_texture = _dynamite_renderer.get_dynamite_icon_texture()
		4:
			_tear_gas_renderer.prewarm_assets()
			_touch_texture(_get_tear_gas_icon_texture())
		5:
			_boomerang_renderer.prewarm_assets()
			_touch_texture(_get_boomerang_icon_texture())
			_touch_texture(_get_boomerang_icon_texture(true))
		6:
			if not bool(_spider_mine_renderer.prewarm_assets_step()):
				return false
			_sync_spider_mine_texture_aliases()
		7:
			_slip_renderer.prewarm_assets()
			_touch_texture(_get_banana_icon_texture())
			_touch_texture(_get_soap_icon_texture())
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func get_spider_mine_asset_status() -> Dictionary:
	_sync_spider_mine_texture_aliases()
	return _spider_mine_renderer.get_asset_status()


func deactivate_all_hosts() -> void:
	if _molotov_renderer != null and _molotov_renderer.has_method("deactivate_all_hosts"):
		_molotov_renderer.deactivate_all_hosts()


func draw(
	canvas: CanvasItem,
	pending_throws: Array,
	grenades: Array,
	flares: Array,
	tear_gas_projectiles: Array,
	tear_gas_zones: Array,
	dynamites: Array,
	placed_dynamites: Array,
	molotovs: Array,
	molotov_fire_zones: Array,
	boomerangs: Array,
	banana_projectiles: Array,
	landed_bananas: Array,
	soap_projectiles: Array,
	landed_soaps: Array,
	boomerang_particles: Array,
	banana_particles: Array,
	soap_particles: Array,
	soap_foam_trails: Array,
	spider_mines: Array,
	spider_mine_particles: Array,
	dynamite_explosions: Array,
	explosion_zones: Array,
	flare_zones: Array,
	shake_offset: Vector2 = Vector2.ZERO,
	perf_logger: Object = null
) -> void:
	if canvas == null:
		return
	var detail_perf_logger: Object = perf_logger if _should_sample_detail(perf_logger, "active_item.throw") else null
	var sample_start: int = _perf_begin(detail_perf_logger)
	_draw_grenade_throw_windups(canvas, pending_throws, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.windups", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_grenade_renderer.draw_grenades(canvas, grenades, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.grenades", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_flare_renderer.draw_flares(canvas, flares, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.flares", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_tear_gas_renderer.draw_tear_gas_zones(canvas, tear_gas_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.tear_gas_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_tear_gas_renderer.draw_tear_gas_projectiles(canvas, tear_gas_projectiles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.tear_gas_projectiles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_molotov_renderer.draw_molotov_fire_zones(canvas, molotov_fire_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.molotov_fire_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_dynamite_renderer.draw_placed_dynamites(canvas, placed_dynamites, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.placed_dynamites", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_dynamite_renderer.draw_dynamites(canvas, dynamites, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.dynamites", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_molotov_renderer.draw_molotovs(canvas, molotovs, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.molotovs", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_slip_renderer.draw_landed_bananas(canvas, landed_bananas, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.landed_bananas", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_slip_renderer.draw_bananas(canvas, banana_projectiles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.banana_projectiles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_slip_renderer.draw_soap_foam_trails(canvas, soap_foam_trails, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.soap_foam_trails", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_slip_renderer.draw_landed_soaps(canvas, landed_soaps, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.landed_soaps", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_slip_renderer.draw_soaps(canvas, soap_projectiles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.soap_projectiles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_slip_renderer.draw_banana_particles(canvas, banana_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.banana_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_slip_renderer.draw_soap_particles(canvas, soap_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.soap_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_boomerang_renderer.draw_boomerang_particles(canvas, boomerang_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.boomerang_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_boomerang_renderer.draw_boomerangs(canvas, boomerangs, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.boomerangs", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_spider_mine_renderer.draw_spider_mines(canvas, spider_mines, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.spider_mines", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_spider_mine_renderer.draw_spider_mine_particles(canvas, spider_mine_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.spider_mine_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_dynamite_renderer.draw_dynamite_explosions(canvas, dynamite_explosions, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.dynamite_explosions", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_grenade_renderer.draw_explosion_zones(canvas, explosion_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.explosion_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_flare_renderer.draw_flare_zones(canvas, flare_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.flare_zones", sample_start)


func _draw_grenade_throw_windups(canvas: CanvasItem, pending_throws: Array, shake_offset: Vector2) -> void:
	if pending_throws.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	for pending_value in pending_throws:
		if not (pending_value is Dictionary):
			continue
		var pending_throw: Dictionary = pending_value
		var item_name: String = str(pending_throw.get("item_name", "grenade"))
		if item_name == "tear_gas":
			_tear_gas_renderer.get_tear_gas_puff_texture()
		var fallback_duration_msec: int = _get_throw_item_windup_msec(item_name)
		var start_msec: int = int(pending_throw.get("start_msec", now_msec))
		var release_msec: int = int(pending_throw.get("release_msec", start_msec + fallback_duration_msec))
		var duration_msec: int = max(1, release_msec - start_msec)
		var progress: float = clamp(float(now_msec - start_msec) / float(duration_msec), 0.0, 1.0)
		var pending_start_pos: Vector2 = _get_vector2(pending_throw, "start_position", Vector2.ZERO) + shake_offset
		var launch_pos: Vector2 = _get_windup_preview_launch_position(pending_start_pos, item_name)
		var throw_pos: Vector2 = _get_windup_preview_position(launch_pos, progress)
		var angle: float = _get_windup_preview_angle(progress)
		var gauntlet_throw: bool = bool(pending_throw.get("gauntlet_equipped", false))
		var texture: Texture2D = _get_throw_item_icon_texture(item_name, gauntlet_throw)
		var draw_size: float = _get_throw_item_draw_size(item_name)
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				throw_pos,
				Vector2(draw_size, draw_size),
				angle
			)
		elif item_name == "flare":
			_flare_renderer.draw_flare_fallback(canvas, throw_pos, 1.1)
		elif item_name == "tear_gas":
			_tear_gas_renderer.draw_tear_gas_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "dynamite":
			_dynamite_renderer.draw_dynamite_fallback(canvas, throw_pos, angle, 1.0, false, 0.0)
		elif item_name == "molotov":
			_molotov_renderer.draw_molotov_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "boomerang":
			_boomerang_renderer.draw_boomerang_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "banana":
			_slip_renderer.draw_banana_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "soap":
			_slip_renderer.draw_soap_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "spider_mine":
			_spider_mine_renderer.draw_spider_mine_windup_fallback(canvas, throw_pos)
		else:
			_grenade_renderer.draw_grenade_fallback(canvas, throw_pos)


func _get_windup_preview_position(start_pos: Vector2, progress: float) -> Vector2:
	# The wind-up preview cocks the held item up and settles it back to the
	# launch point by release (progress == 1.0), so the live projectile — which
	# spawns at that same launch point — takes over with no visible snap. Do NOT
	# drift toward the target here: the live projectile owns all forward travel,
	# and any lead would teleport back to the hand the instant it spawns.
	var clamped_progress: float = clamp(progress, 0.0, 1.0)
	var lift: float = sin(clamped_progress * PI) * 40.0
	return start_pos + Vector2(0.0, -lift)


func _get_windup_preview_launch_position(start_pos: Vector2, item_name: String) -> Vector2:
	if item_name == "banana" or item_name == "dynamite" or item_name == "soap":
		return start_pos + Vector2(0.0, LOW_THROW_PREVIEW_Y_ADJUSTMENT)
	return start_pos


func _get_windup_preview_angle(progress: float) -> float:
	# Returns to 0 at release to match the live projectile's initial rotation,
	# keeping the hand-off seamless.
	return sin(clamp(progress, 0.0, 1.0) * PI) * -35.0


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


func _get_grenade_icon_texture() -> Texture2D:
	grenade_icon_texture = _grenade_renderer.get_grenade_icon_texture()
	return grenade_icon_texture


func _get_flare_icon_texture() -> Texture2D:
	flare_icon_texture = _flare_renderer.get_flare_icon_texture()
	return flare_icon_texture


func _get_tear_gas_icon_texture() -> Texture2D:
	if tear_gas_icon_texture == null:
		tear_gas_icon_texture = ProjectResourceLoader.load_texture(
			TEAR_GAS_ICON_PATH,
			"Missing tear gas icon at %s",
			"Failed to load tear gas icon at %s"
		)
	return tear_gas_icon_texture


func _get_dynamite_icon_texture() -> Texture2D:
	dynamite_icon_texture = _dynamite_renderer.get_dynamite_icon_texture()
	return dynamite_icon_texture


func _get_molotov_icon_texture() -> Texture2D:
	molotov_icon_texture = _molotov_renderer.get_molotov_icon_texture()
	return molotov_icon_texture


func _get_boomerang_icon_texture(use_metal: bool = false) -> Texture2D:
	if use_metal:
		if boomerang_metal_icon_texture == null:
			boomerang_metal_icon_texture = ProjectResourceLoader.load_texture(
				BOOMERANG_METAL_ICON_PATH,
				"Missing metal boomerang icon at %s",
				"Failed to load metal boomerang icon at %s"
			)
		if boomerang_metal_icon_texture != null:
			return boomerang_metal_icon_texture
	if boomerang_icon_texture == null:
		boomerang_icon_texture = ProjectResourceLoader.load_texture(
			BOOMERANG_ICON_PATH,
			"Missing boomerang icon at %s",
			"Failed to load boomerang icon at %s"
		)
	return boomerang_icon_texture


func _get_banana_icon_texture() -> Texture2D:
	if banana_icon_texture == null:
		banana_icon_texture = ProjectResourceLoader.load_texture(
			BANANA_ICON_PATH,
			"Missing banana icon at %s",
			"Failed to load banana icon at %s"
		)
	return banana_icon_texture


func _get_soap_icon_texture() -> Texture2D:
	if soap_icon_texture == null:
		soap_icon_texture = ProjectResourceLoader.load_texture(
			SOAP_ICON_PATH,
			"Missing soap icon at %s",
			"Failed to load soap icon at %s"
		)
	return soap_icon_texture


func _get_spider_mine_icon_texture() -> Texture2D:
	spider_mine_icon_texture = _spider_mine_renderer.get_spider_mine_icon_texture()
	return spider_mine_icon_texture


func _get_spider_mine_crawl_sheet_texture() -> Texture2D:
	spider_mine_crawl_sheet_texture = _spider_mine_renderer.get_spider_mine_crawl_sheet_texture()
	return spider_mine_crawl_sheet_texture


func _get_spider_mine_installed_idle_sheet_texture() -> Texture2D:
	spider_mine_installed_idle_sheet_texture = _spider_mine_renderer.get_spider_mine_installed_idle_sheet_texture()
	return spider_mine_installed_idle_sheet_texture


func _get_spider_mine_deploy_sheet_texture() -> Texture2D:
	spider_mine_deploy_sheet_texture = _spider_mine_renderer.get_spider_mine_deploy_sheet_texture()
	return spider_mine_deploy_sheet_texture


func _get_spider_mine_sheet_texture_for_state(state: String) -> Texture2D:
	return _spider_mine_renderer.get_spider_mine_sheet_texture_for_state(state)


func _get_spider_mine_sheet_frame(mine: Dictionary, state: String) -> int:
	return _spider_mine_renderer.get_spider_mine_sheet_frame(mine, state)


func _get_spider_mine_sheet_angle_degrees(mine: Dictionary, state: String) -> float:
	return _spider_mine_renderer.get_spider_mine_sheet_angle_degrees(mine, state)


func _get_spider_mine_sheet_source_rect(texture: Texture2D, frame_index: int) -> Rect2:
	return _spider_mine_renderer.get_spider_mine_sheet_source_rect(texture, frame_index)


func _get_spider_mine_render_center(center: Vector2, mine: Dictionary, state: String) -> Vector2:
	return _spider_mine_renderer._get_spider_mine_render_center(center, mine, state)


func _sync_spider_mine_texture_aliases() -> void:
	spider_mine_icon_texture = _spider_mine_renderer.get_spider_mine_icon_texture()
	spider_mine_crawl_sheet_texture = _spider_mine_renderer.get_spider_mine_crawl_sheet_texture()
	spider_mine_installed_idle_sheet_texture = _spider_mine_renderer.get_spider_mine_installed_idle_sheet_texture()
	spider_mine_deploy_sheet_texture = _spider_mine_renderer.get_spider_mine_deploy_sheet_texture()


func _get_throw_item_icon_texture(item_name: String, boomerang_metal: bool = false) -> Texture2D:
	if item_name == "flare":
		return _get_flare_icon_texture()
	if item_name == "tear_gas":
		return _get_tear_gas_icon_texture()
	if item_name == "dynamite":
		return _get_dynamite_icon_texture()
	if item_name == "molotov":
		return _get_molotov_icon_texture()
	if item_name == "boomerang":
		return _get_boomerang_icon_texture(boomerang_metal)
	if item_name == "banana":
		return _get_banana_icon_texture()
	if item_name == "soap":
		return _get_soap_icon_texture()
	if item_name == "spider_mine":
		return _get_spider_mine_icon_texture()
	return _get_grenade_icon_texture()


func _get_throw_item_draw_size(item_name: String) -> float:
	if item_name == "flare":
		return FLARE_DRAW_SIZE
	if item_name == "tear_gas":
		return TEAR_GAS_DRAW_SIZE
	if item_name == "dynamite":
		return DYNAMITE_DRAW_SIZE
	if item_name == "molotov":
		return MOLOTOV_DRAW_SIZE
	if item_name == "boomerang":
		return BOOMERANG_DRAW_SIZE
	if item_name == "banana":
		return BANANA_DRAW_SIZE
	if item_name == "soap":
		return SOAP_DRAW_SIZE
	if item_name == "spider_mine":
		return SPIDER_MINE_DRAW_SIZE
	return GRENADE_DRAW_SIZE


func _get_throw_item_windup_msec(item_name: String) -> int:
	if item_name == "flare":
		return FLARE_THROW_WINDUP_MSEC
	if item_name == "tear_gas":
		return TEAR_GAS_THROW_WINDUP_MSEC
	if item_name == "dynamite":
		return DYNAMITE_THROW_WINDUP_MSEC
	if item_name == "molotov":
		return MOLOTOV_THROW_WINDUP_MSEC
	if item_name == "boomerang":
		return 400
	if item_name == "banana":
		return 500
	if item_name == "soap":
		return 500
	if item_name == "spider_mine":
		return SPIDER_MINE_THROW_WINDUP_MSEC
	return GRENADE_THROW_WINDUP_MSEC


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
		texture.get_size()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _should_sample_detail(perf_logger: Object, label: String) -> bool:
	if perf_logger == null or not perf_logger.has_method("should_sample_detail"):
		return false
	return bool(perf_logger.should_sample_detail(label))
