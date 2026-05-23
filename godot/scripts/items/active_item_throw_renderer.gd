extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const MolotovFxHost := preload("res://scripts/items/active_item_molotov_fx_host.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const DynamiteRenderer := preload("res://scripts/items/active_item_throw_dynamite_renderer.gd")
const TearGasRenderer := preload("res://scripts/items/active_item_throw_tear_gas_renderer.gd")
const BoomerangRenderer := preload("res://scripts/items/active_item_throw_boomerang_renderer.gd")
const SpiderMineRenderer := preload("res://scripts/items/active_item_throw_spider_mine_renderer.gd")
const SlipRenderer := preload("res://scripts/items/active_item_throw_slip_renderer.gd")

const GRENADE_ICON_PATH := ActiveItemCatalog.GRENADE_ICON_PATH
const FLARE_ICON_PATH := ActiveItemCatalog.FLARE_ICON_PATH
const TEAR_GAS_ICON_PATH := ActiveItemCatalog.TEAR_GAS_ICON_PATH
const MOLOTOV_ICON_PATH := ActiveItemCatalog.MOLOTOV_ICON_PATH
const BOOMERANG_ICON_PATH := ActiveItemCatalog.BOOMERANG_ICON_PATH
const BOOMERANG_METAL_ICON_PATH := ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH
const BANANA_ICON_PATH := ActiveItemCatalog.BANANA_ICON_PATH
const SOAP_ICON_PATH := ActiveItemCatalog.SOAP_ICON_PATH
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_DRAW_SIZE := 36.0
const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const GRENADE_EXPLOSION_FIRE_RINGS := 5
const GRENADE_EXPLOSION_SMOKE_PUFFS := 3
const GRENADE_EXPLOSION_SPARKS := 4
const FLARE_THROW_WINDUP_MSEC := 600
const FLARE_DRAW_SIZE := 34.0
const FLARE_RADIUS := 180.0
const FLARE_FLASH_LAYERS := 1
const FLARE_GLOW_LAYERS := 1
const TEAR_GAS_THROW_WINDUP_MSEC := 600
const TEAR_GAS_DRAW_SIZE := 36.0
const TEAR_GAS_RADIUS := 180.0
const TEAR_GAS_RADIUS_X := 384.0
const TEAR_GAS_ARMED_DELAY_FRAMES := 180.0
const TEAR_GAS_ZONE_DURATION_FRAMES := 960.0
const TEAR_GAS_RENDER_PARTICLE_LIMIT := 10
const TEAR_GAS_RENDER_TOTAL_PARTICLE_LIMIT := 16
const TEAR_GAS_PARTICLE_ALPHA_CUTOFF := 0.012
const TEAR_GAS_PUFF_TEXTURE_SIZE := 96
const DYNAMITE_DRAW_SIZE := 46.0
const DYNAMITE_THROW_WINDUP_MSEC := 500
const MOLOTOV_DRAW_SIZE := 36.0
const MOLOTOV_THROW_WINDUP_MSEC := 600
const MOLOTOV_FIRE_DURATION_FRAMES := 150.0
const MOLOTOV_FIRE_ALPHA_CUTOFF := 0.015
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
const FILLED_ELLIPSE_SEGMENTS := 32

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

static var _filled_ellipse_mesh: ArrayMesh = null

# Modular VFX host pool for molotov fire zones. Each fire zone is matched to
# one host via zone_id; idle hosts stay attached to the canvas with
# visible=false. Capped at MOLOTOV_FX_HOST_POOL_SIZE so a runaway molotov
# spam can't blow out the GPU particle budget. Excess zones fall back to the
# legacy canvas-draw embellishment.
const MOLOTOV_FX_HOST_POOL_SIZE := 3
const MOLOTOV_FX_HOST_NAME_PREFIX := "ActiveItemMolotovFxHost"
const MOLOTOV_FX_HOST_QUALITY_GATE := 0.45
const MOLOTOV_PLAYFIELD_GAME_WIDTH := 760.0
const MOLOTOV_PLAYFIELD_GAME_HEIGHT := 750.0
@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts: Array = []
@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts_zone_ids: Array = []
@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts_burst_triggered: Array = []
@warning_ignore("unused_private_class_variable")
var _molotov_fx_hosts_canvas: Object = null

# Playfield-letterbox screen-space layout cache. The playfield canvas is drawn
# via `canvas.draw_set_transform(game_offset + shake * render_scale, render_scale)`
# every frame in battle_scene_drawer.gd; that transform only affects subsequent
# `draw_*()` calls and does NOT propagate to child Node2D positions. So host
# nodes attached to the canvas render in screen space, not game space — they
# need the same game_offset + render_scale applied manually to land inside the
# playfield rect instead of leaking into the left/right pillar chrome area.
# This trap is documented in CLAUDE.md's "Godot Playfield / Pillar / Overlay
# Clip Reality" section and matched 1:1 by stage5_hongryun_inferno_burst_fx_host.
var _molotov_view_layout: Object = null
var _molotov_view_cached_viewport_size: Vector2 = Vector2.ZERO
var _molotov_view_cached_game_offset: Vector2 = Vector2.ZERO
var _molotov_view_cached_render_scale: float = 1.0
var _dynamite_renderer: Object = DynamiteRenderer.new()
var _tear_gas_renderer: Object = TearGasRenderer.new()
var _boomerang_renderer: Object = BoomerangRenderer.new()
var _spider_mine_renderer: Object = SpiderMineRenderer.new()
var _slip_renderer: Object = SlipRenderer.new()


func prewarm_assets() -> void:
	MolotovFxHost.prewarm_assets()
	_dynamite_renderer.prewarm_assets()
	dynamite_icon_texture = _dynamite_renderer.get_dynamite_icon_texture()
	_tear_gas_renderer.prewarm_assets()
	_boomerang_renderer.prewarm_assets()
	_spider_mine_renderer.prewarm_assets()
	_sync_spider_mine_texture_aliases()
	_slip_renderer.prewarm_assets()
	_touch_texture(_get_grenade_icon_texture())
	_touch_texture(_get_flare_icon_texture())
	_touch_texture(_get_tear_gas_icon_texture())
	_touch_texture(_get_molotov_icon_texture())
	_touch_texture(_get_boomerang_icon_texture())
	_touch_texture(_get_boomerang_icon_texture(true))
	_touch_texture(_get_banana_icon_texture())
	_touch_texture(_get_soap_icon_texture())
	_get_filled_ellipse_mesh()


func get_spider_mine_asset_status() -> Dictionary:
	_sync_spider_mine_texture_aliases()
	return _spider_mine_renderer.get_asset_status()


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
	_draw_grenades(canvas, grenades, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.grenades", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_flares(canvas, flares, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.flares", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_tear_gas_renderer.draw_tear_gas_zones(canvas, tear_gas_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.tear_gas_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_tear_gas_renderer.draw_tear_gas_projectiles(canvas, tear_gas_projectiles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.tear_gas_projectiles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_molotov_fire_zones(canvas, molotov_fire_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.molotov_fire_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_dynamite_renderer.draw_placed_dynamites(canvas, placed_dynamites, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.placed_dynamites", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_dynamite_renderer.draw_dynamites(canvas, dynamites, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.dynamites", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_molotovs(canvas, molotovs, shake_offset)
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
	_draw_explosion_zones(canvas, explosion_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.explosion_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_flare_zones(canvas, flare_zones, shake_offset)
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
		var start_pos: Vector2 = _get_vector2(pending_throw, "start_position", Vector2.ZERO) + shake_offset
		var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos) + shake_offset
		var lift_pos: Vector2 = start_pos + Vector2(0.0, -34.0 - sin(progress * PI) * 12.0)
		var throw_pos: Vector2 = lift_pos.lerp(target_pos, max(0.0, (progress - 0.72) / 0.28) * 0.18)
		var angle: float = lerp(0.0, -35.0, progress)
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
			canvas.draw_circle(throw_pos, 11.0, Color(1.0, 1.0, 200.0 / 255.0, 1.0))
		elif item_name == "tear_gas":
			_tear_gas_renderer.draw_tear_gas_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "dynamite":
			_dynamite_renderer.draw_dynamite_fallback(canvas, throw_pos, angle, 1.0, false, 0.0)
		elif item_name == "molotov":
			_draw_molotov_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "boomerang":
			_boomerang_renderer.draw_boomerang_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "banana":
			_slip_renderer.draw_banana_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "soap":
			_slip_renderer.draw_soap_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "spider_mine":
			_spider_mine_renderer.draw_spider_mine_windup_fallback(canvas, throw_pos)
		else:
			canvas.draw_circle(throw_pos, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_grenades(canvas: CanvasItem, grenades: Array, shake_offset: Vector2) -> void:
	if grenades.is_empty():
		return
	var texture: Texture2D = _get_grenade_icon_texture()
	for grenade_value in grenades:
		if not (grenade_value is Dictionary):
			continue
		var grenade: Dictionary = grenade_value
		_draw_projectile_trail(canvas, grenade.get("trail", []), shake_offset, 3.0, Color(1.0, 190.0 / 255.0, 80.0 / 255.0, 1.0), 0.28)

		var center: Vector2 = _get_vector2(grenade, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(grenade.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(GRENADE_DRAW_SIZE, GRENADE_DRAW_SIZE),
				angle
			)
		else:
			canvas.draw_circle(center, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_flares(canvas: CanvasItem, flares: Array, shake_offset: Vector2) -> void:
	if flares.is_empty():
		return
	var texture: Texture2D = _get_flare_icon_texture()
	for flare_value in flares:
		if not (flare_value is Dictionary):
			continue
		var flare: Dictionary = flare_value
		var center: Vector2 = _get_vector2(flare, "position", Vector2.ZERO) + shake_offset
		if bool(flare.get("arrived", false)) and not bool(flare.get("exploded", false)):
			var timer_frames: int = int(flare.get("timer_frames", 0.0))
			if timer_frames % 10 < 5:
				canvas.draw_circle(center, 12.0, Color(1.0, 1.0, 100.0 / 255.0, 0.95))
			canvas.draw_circle(center, 8.0, Color(1.0, 200.0 / 255.0, 0.0, 1.0), false, 2.0)
			continue

		_draw_projectile_trail(canvas, flare.get("trail", []), shake_offset, 3.5, Color(1.0, 1.0, 180.0 / 255.0, 1.0), 0.34)

		var angle: float = float(flare.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(FLARE_DRAW_SIZE, FLARE_DRAW_SIZE),
				angle
			)
		else:
			canvas.draw_circle(center, 10.0, Color(1.0, 1.0, 200.0 / 255.0, 1.0))


func _draw_projectile_trail(canvas: CanvasItem, trail: Array, shake_offset: Vector2, radius: float, color: Color, alpha_scale: float) -> void:
	var trail_count: int = trail.size()
	if trail_count <= 0:
		return
	var stride: int = 2 if trail_count > 5 else 1
	for i in range(0, trail_count, stride):
		var trail_pos: Variant = trail[i]
		if not (trail_pos is Vector2):
			continue
		var trail_point: Vector2 = trail_pos
		var alpha: float = float(i + 1) / float(trail_count) * alpha_scale
		canvas.draw_circle(trail_point + shake_offset, radius, Color(color.r, color.g, color.b, alpha))


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


func _draw_molotovs(canvas: CanvasItem, molotovs: Array, shake_offset: Vector2) -> void:
	if molotovs.is_empty():
		return
	var texture: Texture2D = _get_molotov_icon_texture()
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
			_draw_molotov_fallback(canvas, center, angle, 1.0)


func _draw_molotov_fire_zones(canvas: CanvasItem, fire_zones: Array, shake_offset: Vector2) -> void:
	# Modular VFX host pool owns the heavy shader+particle layers (ember floor,
	# flame dome, char ring, explosion burst, ember sparks). Sync it first so
	# the canvas-draw block below knows which zones to fall back on for the
	# legacy 3-ellipse stack.
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
			# Legacy canvas-draw fallback when the host pool is full or a
			# render-quality gate (e.g. low-LOD) is active. Same look as
			# before the modular VFX refactor.
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

		# Per-flame embers are kept regardless — they're small bright flickers
		# riding on top of the shader fire bed, and they carry the gameplay
		# spawn/spread/lifetime that the host's GPU particles approximate but
		# do not authoritatively own. When a host is active the host's
		# ember sparks dominate, but a thin layer of these legacy embers
		# keeps the silhouette feeling lively even at low quality.
		var flames: Array = zone.get("flames", [])
		var flame_alpha_scale: float = 0.55 if has_host else 1.0
		for flame_value in flames:
			if not (flame_value is Dictionary):
				continue
			_draw_molotov_flame(canvas, flame_value, shake_offset, life_ratio * flame_alpha_scale)


func _sync_molotov_fx_hosts(canvas: CanvasItem, fire_zones: Array, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	if not _is_molotov_host_quality_ok():
		# Fast-path: release all hosts.
		_deactivate_all_molotov_hosts()
		return
	_ensure_molotov_host_pool(canvas)
	if _molotov_fx_hosts.is_empty():
		return
	# Compute the same playfield-letterbox transform that battle_scene_drawer
	# applies via draw_set_transform around _draw_playfield_scene. The canvas
	# tree transform itself is identity, so child Node2Ds (our hosts) must
	# project game coords into screen coords manually or they render in the
	# pillar area off-playfield. See the layout-cache comment block above.
	var playfield_game_offset: Vector2 = _molotov_view_cached_game_offset
	var playfield_render_scale: float = _molotov_view_cached_render_scale
	if not fire_zones.is_empty():
		var layout: Dictionary = _get_molotov_playfield_layout(canvas)
		playfield_game_offset = layout.get("game_offset", Vector2.ZERO)
		playfield_render_scale = max(0.001, float(layout.get("render_scale", 1.0)))

	# Build the slot assignment: each fire zone gets matched to its host by
	# zone_id (sticky across frames). New zones grab the next free slot. If
	# the pool is full, extra zones get no host and fall back to canvas-draw.
	var slot_used: Array = []
	slot_used.resize(_molotov_fx_hosts.size())
	for slot_idx in range(slot_used.size()):
		slot_used[slot_idx] = false

	var assigned: Array = []  # zone_id -> slot_idx
	assigned.resize(fire_zones.size())
	for zone_idx in range(fire_zones.size()):
		assigned[zone_idx] = -1
		var zone_value: Variant = fire_zones[zone_idx]
		if not (zone_value is Dictionary):
			continue
		var zone_id: int = int(zone_value.get("zone_id", 0))
		if zone_id <= 0:
			continue
		# First pass: keep the existing slot if this zone already had one.
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
		# Second pass: take the next free slot for new zones.
		for slot_idx in range(_molotov_fx_hosts.size()):
			if slot_used[slot_idx]:
				continue
			assigned[zone_idx] = slot_idx
			slot_used[slot_idx] = true
			_molotov_fx_hosts_zone_ids[slot_idx] = zone_id
			_molotov_fx_hosts_burst_triggered[slot_idx] = false
			break

	# Apply state to every assigned host; deactivate unassigned hosts.
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
		# Trigger the one-shot explosion burst on the first frame this zone
		# acquires a host. age_frames is ticked by update_fire_zones so
		# spawn-frame age is ~0 and it grows from there.
		var age_frames: float = float(zone.get("age_frames", 0.0))
		if not bool(_molotov_fx_hosts_burst_triggered[slot_idx]) and age_frames < 4.0:
			if host.has_method("trigger_explosion_burst"):
				host.trigger_explosion_burst()
			_molotov_fx_hosts_burst_triggered[slot_idx] = true
		# Project game-space zone center into screen-space (host nodes do not
		# inherit the canvas's draw_set_transform — see layout-cache comment).
		# render_scale also feeds the host's tree-scale so sprite sizes match
		# the rest of the playfield's render scaling.
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
	# A future hook for BattleRenderQuality LOD; for now hosts always run
	# when the platform supports them. Particles still self-gate via the
	# host's EMBER_PARTICLE_QUALITY_GATE.
	return true


func _ensure_molotov_host_pool(canvas: CanvasItem) -> void:
	if _molotov_fx_hosts_canvas == canvas and _molotov_fx_hosts.size() == MOLOTOV_FX_HOST_POOL_SIZE:
		# Already wired to this canvas; nothing to do.
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
	# Reset pool — if the canvas changed (e.g. scene reload), let stale hosts
	# auto-free via their queue_free path when the scene is torn down.
	_molotov_fx_hosts.clear()
	_molotov_fx_hosts_zone_ids.clear()
	_molotov_fx_hosts_burst_triggered.clear()
	_molotov_fx_hosts_canvas = canvas
	for slot_idx in range(MOLOTOV_FX_HOST_POOL_SIZE):
		var host_name: String = "%s%d" % [MOLOTOV_FX_HOST_NAME_PREFIX, slot_idx]
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
	# Mirrors what BattleViewLayout produces in the per-frame draw_context so
	# host Node2D positions land at the same screen coords as the canvas's
	# draw_set_transform would have produced. Cached on the viewport size so
	# the cost is a few floats per frame in steady state. See the layout-cache
	# comment block at the top of the file for the trap rationale.
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


func _draw_molotov_flame(canvas: CanvasItem, flame: Dictionary, shake_offset: Vector2, zone_life: float) -> void:
	var center: Vector2 = _get_vector2(flame, "position", Vector2.ZERO) + shake_offset
	var size: float = max(2.0, float(flame.get("size", 8.0)))
	var lifetime: float = max(0.0, float(flame.get("lifetime_frames", 20.0)))
	var max_lifetime: float = max(1.0, float(flame.get("max_lifetime_frames", 40.0)))
	var life: float = clamp(lifetime / max_lifetime, 0.0, 1.0) * zone_life
	if life <= MOLOTOV_FIRE_ALPHA_CUTOFF:
		return
	for layer in range(2):
		var layer_ratio: float = float(layer)
		var layer_size: float = max(2.0, size * (1.0 - layer_ratio * 0.5))
		var color: Color
		if layer == 0:
			color = Color(160.0 / 255.0, 25.0 / 255.0, 5.0 / 255.0, 0.34 * life)
		else:
			color = Color(1.0, 245.0 / 255.0, 160.0 / 255.0, 0.70 * life)
		canvas.draw_circle(center + Vector2(0.0, -layer_ratio * size * 0.25), layer_size, color)


func _draw_molotov_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
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


func _draw_explosion_zones(canvas: CanvasItem, explosion_zones: Array, shake_offset: Vector2) -> void:
	if explosion_zones.is_empty():
		return
	for zone_value in explosion_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		GrenadeExplosionDrawer.draw_zone(canvas, zone, shake_offset)


func _draw_flare_zones(canvas: CanvasItem, flare_zones: Array, shake_offset: Vector2) -> void:
	if flare_zones.is_empty():
		return
	for zone_value in flare_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var radius: float = float(zone.get("radius", FLARE_RADIUS))
		var intensity: float = clamp(float(zone.get("intensity", 1.0)), 0.0, 1.0)
		if intensity <= 0.0:
			continue

		if bool(zone.get("flash", false)):
			canvas.draw_rect(Rect2(shake_offset, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(1.0, 1.0, 230.0 / 255.0, (180.0 / 255.0) * intensity))
			for i in range(FLARE_FLASH_LAYERS):
				var layer_radius: float = radius * (1.0 - float(i) * 0.18)
				var alpha: float = intensity * (1.0 - float(i) * 0.28)
				if alpha > 0.0 and layer_radius > 1.0:
					canvas.draw_circle(center, layer_radius, Color(1.0, 1.0, 240.0 / 255.0, alpha))
			if intensity > 0.85:
				var cross_length: float = radius * 2.0
				canvas.draw_line(center + Vector2(-cross_length, 0.0), center + Vector2(cross_length, 0.0), Color.WHITE, 5.0)
				canvas.draw_line(center + Vector2(0.0, -cross_length), center + Vector2(0.0, cross_length), Color.WHITE, 5.0)
		else:
			for i in range(FLARE_GLOW_LAYERS):
				var layer_radius: float = radius * (1.0 - float(i) * 0.2)
				var alpha: float = (100.0 / 255.0) * intensity * (1.0 - float(i) * 0.3)
				if alpha > 0.0 and layer_radius > 1.0:
					canvas.draw_circle(center, layer_radius, Color(1.0, 1.0, 200.0 / 255.0, alpha))


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
	if grenade_icon_texture == null:
		grenade_icon_texture = ProjectResourceLoader.load_texture(
			GRENADE_ICON_PATH,
			"Missing grenade icon at %s",
			"Failed to load grenade icon at %s"
		)
	return grenade_icon_texture


func _get_flare_icon_texture() -> Texture2D:
	if flare_icon_texture == null:
		flare_icon_texture = ProjectResourceLoader.load_texture(
			FLARE_ICON_PATH,
			"Missing flare icon at %s",
			"Failed to load flare icon at %s"
		)
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
	if molotov_icon_texture == null:
		molotov_icon_texture = ProjectResourceLoader.load_texture(
			MOLOTOV_ICON_PATH,
			"Missing molotov icon at %s",
			"Failed to load molotov icon at %s"
		)
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


func _get_spider_mine_sheet_source_rect(texture: Texture2D, frame_index: int) -> Rect2:
	return _spider_mine_renderer.get_spider_mine_sheet_source_rect(texture, frame_index)


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
