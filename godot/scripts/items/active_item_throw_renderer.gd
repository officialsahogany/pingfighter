extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const MolotovFxHost := preload("res://scripts/items/active_item_molotov_fx_host.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")

const GRENADE_ICON_PATH := ActiveItemCatalog.GRENADE_ICON_PATH
const FLARE_ICON_PATH := ActiveItemCatalog.FLARE_ICON_PATH
const TEAR_GAS_ICON_PATH := ActiveItemCatalog.TEAR_GAS_ICON_PATH
const DYNAMITE_ICON_PATH := ActiveItemCatalog.DYNAMITE_ICON_PATH
const MOLOTOV_ICON_PATH := ActiveItemCatalog.MOLOTOV_ICON_PATH
const BOOMERANG_ICON_PATH := ActiveItemCatalog.BOOMERANG_ICON_PATH
const BOOMERANG_METAL_ICON_PATH := ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH
const BANANA_ICON_PATH := ActiveItemCatalog.BANANA_ICON_PATH
const SOAP_ICON_PATH := ActiveItemCatalog.SOAP_ICON_PATH
const SPIDER_MINE_ICON_PATH := ActiveItemCatalog.SPIDER_MINE_ICON_PATH
const SPIDER_MINE_CRAWL_SHEET_PATH := "res://assets/sprites/items/spider_mine_crawl_sheet.png"
const SPIDER_MINE_INSTALLED_IDLE_SHEET_PATH := "res://assets/sprites/items/spider_mine_installed_idle_sheet.png"
const SPIDER_MINE_DEPLOY_SHEET_PATH := "res://assets/sprites/items/spider_mine_deploy_sheet.png"
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
const DYNAMITE_PLACED_DRAW_SIZE := 48.0
const DYNAMITE_THROW_WINDUP_MSEC := 500
const DYNAMITE_COUNTDOWN_FRAMES := 420.0
const DYNAMITE_EXPLOSION_RADIUS := 350.0
const DYNAMITE_EXPLOSION_DURATION_FRAMES := 36.0
const DYNAMITE_PARTICLE_ALPHA_CUTOFF := 0.025
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
const SPIDER_MINE_EXPLOSION_DURATION_FRAMES := 22.0
const SPIDER_MINE_START_DELAY_FRAMES := 60.0
const SPIDER_MINE_EMBED_DELAY_FRAMES := 60.0
const SPIDER_MINE_SELF_DESTRUCT_WARNING_FRAMES := 120.0
const SPIDER_MINE_SELF_DESTRUCT_FAST_FRAMES := 180.0
const SPIDER_MINE_FLASH_INTERVAL_FRAMES := 6.0
const SPIDER_MINE_SHEET_COLUMNS := 4
const SPIDER_MINE_SHEET_FRAME_COUNT := 16
const SPIDER_MINE_SHEET_DRAW_SIZE := 44.0
const SPIDER_MINE_CRAWL_FRAME_INTERVAL_FRAMES := 4.0
const SPIDER_MINE_IDLE_FRAME_INTERVAL_FRAMES := 6.0
const SPIDER_MINE_CRAWL_STEP_PHASE_PER_FRAME := 0.4
const SPIDER_MINE_GLOW_PHASE_PER_FRAME := 0.08
const SPIDER_MINE_LEG_DXS := [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]
const SPIDER_MINE_LEG_DYS := [8.0, -3.0, 2.0, 2.0, -3.0, 8.0]
const SPIDER_MINE_LEG_PHASES := [0.0, 1.5, 3.0, 0.8, 2.3, 3.8]
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

static var _tear_gas_puff_texture: ImageTexture = null
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


func prewarm_assets() -> void:
	MolotovFxHost.prewarm_assets()
	_touch_texture(_get_grenade_icon_texture())
	_touch_texture(_get_flare_icon_texture())
	_touch_texture(_get_tear_gas_icon_texture())
	_touch_texture(_get_tear_gas_puff_texture())
	_touch_texture(_get_dynamite_icon_texture())
	_touch_texture(_get_molotov_icon_texture())
	_touch_texture(_get_boomerang_icon_texture())
	_touch_texture(_get_boomerang_icon_texture(true))
	_touch_texture(_get_banana_icon_texture())
	_touch_texture(_get_soap_icon_texture())
	_touch_texture(_get_spider_mine_icon_texture())
	_touch_texture(_get_spider_mine_crawl_sheet_texture())
	_touch_texture(_get_spider_mine_installed_idle_sheet_texture())
	_touch_texture(_get_spider_mine_deploy_sheet_texture())
	_get_filled_ellipse_mesh()


func get_spider_mine_asset_status() -> Dictionary:
	var crawl_sheet: Texture2D = _get_spider_mine_crawl_sheet_texture()
	var installed_idle_sheet: Texture2D = _get_spider_mine_installed_idle_sheet_texture()
	var deploy_sheet: Texture2D = _get_spider_mine_deploy_sheet_texture()
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
	_draw_tear_gas_zones(canvas, tear_gas_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.tear_gas_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_tear_gas_projectiles(canvas, tear_gas_projectiles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.tear_gas_projectiles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_molotov_fire_zones(canvas, molotov_fire_zones, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.molotov_fire_zones", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_placed_dynamites(canvas, placed_dynamites, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.placed_dynamites", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_dynamites(canvas, dynamites, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.dynamites", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_molotovs(canvas, molotovs, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.molotovs", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_landed_bananas(canvas, landed_bananas, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.landed_bananas", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_bananas(canvas, banana_projectiles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.banana_projectiles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_soap_foam_trails(canvas, soap_foam_trails, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.soap_foam_trails", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_landed_soaps(canvas, landed_soaps, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.landed_soaps", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_soaps(canvas, soap_projectiles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.soap_projectiles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_banana_particles(canvas, banana_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.banana_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_soap_particles(canvas, soap_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.soap_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_boomerang_particles(canvas, boomerang_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.boomerang_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_boomerangs(canvas, boomerangs, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.boomerangs", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_spider_mines(canvas, spider_mines, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.spider_mines", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_spider_mine_particles(canvas, spider_mine_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.throw.spider_mine_particles", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_dynamite_explosions(canvas, dynamite_explosions, shake_offset)
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
			_get_tear_gas_puff_texture()
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
			_draw_tear_gas_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "dynamite":
			_draw_dynamite_fallback(canvas, throw_pos, angle, 1.0, false, 0.0)
		elif item_name == "molotov":
			_draw_molotov_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "boomerang":
			_draw_boomerang_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "banana":
			_draw_banana_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "soap":
			_draw_soap_fallback(canvas, throw_pos, angle, 1.0)
		elif item_name == "spider_mine":
			canvas.draw_circle(throw_pos, 13.0, Color(58.0 / 255.0, 64.0 / 255.0, 90.0 / 255.0, 1.0))
			canvas.draw_circle(throw_pos + Vector2(0.0, -2.0), 5.0, Color(200.0 / 255.0, 90.0 / 255.0, 130.0 / 255.0, 1.0))
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


func _draw_tear_gas_projectiles(canvas: CanvasItem, tear_gas_projectiles: Array, shake_offset: Vector2) -> void:
	if tear_gas_projectiles.is_empty():
		return
	_get_tear_gas_puff_texture()
	var texture: Texture2D = _get_tear_gas_icon_texture()
	var font: Font = ThemeDB.fallback_font
	for projectile_value in tear_gas_projectiles:
		if not (projectile_value is Dictionary):
			continue
		var projectile: Dictionary = projectile_value
		var center: Vector2 = _get_vector2(projectile, "position", Vector2.ZERO) + shake_offset
		if bool(projectile.get("arrived", false)) and not bool(projectile.get("emitted", false)):
			var timer_frames: float = clamp(float(projectile.get("timer_frames", 0.0)), 0.0, TEAR_GAS_ARMED_DELAY_FRAMES)
			var remaining: float = max(0.0, TEAR_GAS_ARMED_DELAY_FRAMES - timer_frames)
			var blink: bool = int(timer_frames / 12.0) % 2 == 0
			_draw_filled_ellipse(canvas, Rect2(center + Vector2(-17.0, 8.0), Vector2(34.0, 7.0)), Color(0.0, 0.0, 0.0, 0.32))
			if blink:
				canvas.draw_circle(center + Vector2(9.0, -6.0), 3.0, Color(0.92, 0.08, 0.04, 0.95))
			if texture != null:
				_draw_rotated_texture_region(
					canvas,
					texture,
					Rect2(Vector2.ZERO, texture.get_size()),
					center + Vector2(0.0, -4.0),
					Vector2(28.0, 28.0),
					0.0
				)
			else:
				_draw_tear_gas_fallback(canvas, center + Vector2(0.0, -4.0), 0.0, 0.85)
			if font != null:
				var count_text: String = str(int(ceil(remaining / 60.0)))
				var font_size: int = 14
				var text_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
				canvas.draw_string(
					font,
					center + Vector2(-text_size.x * 0.5, -25.0),
					count_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					font_size,
					Color(0.90, 1.0, 0.82, 0.95)
				)
			continue

		_draw_projectile_trail(canvas, projectile.get("trail", []), shake_offset, 3.0, Color(150.0 / 255.0, 160.0 / 255.0, 145.0 / 255.0, 1.0), 0.24)

		var angle: float = float(projectile.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(TEAR_GAS_DRAW_SIZE, TEAR_GAS_DRAW_SIZE),
				angle
			)
		else:
			_draw_tear_gas_fallback(canvas, center, angle, 1.0)


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


func _draw_tear_gas_zones(canvas: CanvasItem, tear_gas_zones: Array, shake_offset: Vector2) -> void:
	if tear_gas_zones.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var remaining_particle_budget := TEAR_GAS_RENDER_TOTAL_PARTICLE_LIMIT
	for zone_value in tear_gas_zones:
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var radius_y: float = max(1.0, float(zone.get("radius", TEAR_GAS_RADIUS)))
		var radius_x: float = max(1.0, float(zone.get("radius_x", TEAR_GAS_RADIUS_X)))
		var opacity: float = clamp(float(zone.get("opacity", 0.0)), 0.0, 1.0)
		if opacity <= 0.0:
			continue
		var pulse: float = 0.5 + 0.5 * sin(float(now_msec) * 0.004)
		_draw_tear_gas_base_haze(canvas, center, radius_x, radius_y, opacity, pulse, now_msec)

		var particles: Array = zone.get("particles", [])
		var particle_count: int = particles.size()
		if remaining_particle_budget <= 0:
			continue
		var rendered_particle_count: int = min(particle_count, TEAR_GAS_RENDER_PARTICLE_LIMIT, remaining_particle_budget)
		for draw_index in range(rendered_particle_count):
			var particle_index: int = int(floor(float(draw_index) * float(particle_count) / float(rendered_particle_count)))
			var particle_value: Variant = particles[particle_index]
			if not (particle_value is Dictionary):
				continue
			_draw_tear_gas_particle(canvas, particle_value, shake_offset, opacity)
		remaining_particle_budget -= rendered_particle_count


func _draw_tear_gas_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2, zone_life: float) -> void:
	var life_frames: float = float(particle.get("life_frames", 0.0))
	var max_life_frames: float = max(1.0, float(particle.get("max_life_frames", 80.0)))
	var life_ratio: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
	if life_ratio <= 0.0 or zone_life <= 0.0:
		return
	var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var size: float = max(1.0, float(particle.get("size", 10.0)))
	var aspect: float = max(0.25, float(particle.get("aspect", 1.4)))
	var depth: float = clamp(float(particle.get("depth", 0.5)), 0.0, 1.0)
	var tone: int = int(particle.get("color_tone", particle.get("tone", 0)))
	var variant: int = int(particle.get("variant", 0))
	@warning_ignore("shadowed_global_identifier")
	var seed: int = _get_smoke_particle_seed(particle, center)
	var depth_alpha_mult: float = 0.6 + 0.4 * depth
	var main: Color = _get_tear_gas_smoke_tone(tone, 1, depth)
	var core: Color = _get_tear_gas_smoke_tone(tone, 2, depth)
	var particle_type: String = str(particle.get("type", "smoke_cloud"))
	if particle_type == "smoke_pillar":
		var alpha: float = min(zone_life, (120.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		_draw_tear_gas_layered_texture_puff(canvas, center, Vector2(max(3.0, size * aspect), max(3.0, size * 1.3)), seed + variant * 101, main, core, alpha, depth)
	elif particle_type == "smoke_wisp":
		var alpha: float = min(zone_life, (160.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		_draw_tear_gas_texture_puff(canvas, center, Vector2(max(1.0, size * 1.15), max(1.0, size * 0.88)), main, alpha * 0.82)
	elif particle_type == "smoke_tendril":
		var alpha: float = min(zone_life, (100.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.RIGHT)
		var stretch: float = clamp(velocity.length() * 0.22, 0.8, 1.55)
		_draw_tear_gas_texture_puff(canvas, center, Vector2(max(3.0, size * aspect * stretch), max(2.0, size * 0.82)), main, alpha * 0.76)
	else:
		var alpha: float = min(zone_life, (140.0 / 255.0) * life_ratio * depth_alpha_mult)
		if alpha <= TEAR_GAS_PARTICLE_ALPHA_CUTOFF:
			return
		_draw_tear_gas_layered_texture_puff(canvas, center, Vector2(max(4.0, size * aspect), max(4.0, size)), seed + variant * 409, main, core, alpha, depth)


func _draw_tear_gas_base_haze(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, opacity: float, pulse: float, now_msec: int) -> void:
	var base_alpha: float = 0.08 * opacity
	if base_alpha <= 0.0:
		return
	_draw_smoke_ellipse(canvas, center + Vector2(0.0, radius_y * 0.04), radius_x * 0.68, radius_y * 0.25, Color(0.34, 0.35, 0.31, base_alpha * 0.65))
	for i in range(3):
		@warning_ignore("shadowed_global_identifier")
		var seed := 7300 + i * 79
		var drift := Vector2(
			_stable_signed(seed, i, 0) * radius_x * 0.26 + sin(float(now_msec) * 0.0012 + float(i)) * 3.0,
			_stable_signed(seed, i, 1) * radius_y * 0.11
		)
		var rx: float = radius_x * (0.24 + 0.08 * _stable_unit(seed, i, 2))
		var ry: float = radius_y * (0.10 + 0.04 * _stable_unit(seed, i, 3))
		var tone := _get_tear_gas_smoke_tone(i % 3, 1, 0.45 + pulse * 0.18)
		_draw_smoke_ellipse(canvas, center + drift, rx, ry, Color(tone.r, tone.g, tone.b, base_alpha * (0.42 + 0.14 * pulse)))


func _draw_tear_gas_layered_texture_puff(
	canvas: CanvasItem,
	center: Vector2,
	radius: Vector2,
	smoke_seed: int,
	main: Color,
	core: Color,
	alpha: float,
	depth: float
) -> void:
	if alpha <= 0.0:
		return
	_draw_tear_gas_texture_puff(canvas, center, radius, main, alpha * 0.76)
	if depth < 0.35:
		return
	var core_offset := Vector2(
		_stable_signed(smoke_seed, 0, 5) * radius.x * 0.16,
		_stable_signed(smoke_seed, 0, 6) * radius.y * 0.12
	)
	_draw_tear_gas_texture_puff(canvas, center + core_offset, radius * 0.46, core, alpha * 0.32)


func _draw_tear_gas_texture_puff(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, alpha: float) -> void:
	if alpha <= 0.0 or radius.x <= 0.5 or radius.y <= 0.5:
		return
	var texture: Texture2D = _get_tear_gas_puff_texture()
	if texture == null:
		_draw_smoke_ellipse(canvas, center, radius.x, radius.y, Color(color.r, color.g, color.b, alpha))
		return
	var draw_size := Vector2(radius.x * 2.0, radius.y * 2.0)
	canvas.draw_texture_rect(
		texture,
		Rect2(center - draw_size * 0.5, draw_size),
		false,
		Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))
	)


func _get_tear_gas_puff_texture() -> ImageTexture:
	if _tear_gas_puff_texture != null:
		return _tear_gas_puff_texture
	_tear_gas_puff_texture = _build_tear_gas_puff_texture()
	return _tear_gas_puff_texture


static func _build_tear_gas_puff_texture() -> ImageTexture:
	var image: Image = Image.create(TEAR_GAS_PUFF_TEXTURE_SIZE, TEAR_GAS_PUFF_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center_coord: float = (float(TEAR_GAS_PUFF_TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	for y in range(TEAR_GAS_PUFF_TEXTURE_SIZE):
		var dy: float = (float(y) - center_coord) / max_dist
		for x in range(TEAR_GAS_PUFF_TEXTURE_SIZE):
			var dx: float = (float(x) - center_coord) / max_dist
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			var core_alpha: float = pow(max(0.0, 1.0 - dist * 1.55), 2.2) * 0.62
			var body_alpha: float = pow(max(0.0, 1.0 - dist), 1.65) * 0.74
			var rim_alpha: float = pow(max(0.0, 1.0 - abs(dist - 0.58) / 0.42), 2.6) * 0.12
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clamp(core_alpha + body_alpha + rim_alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _draw_tear_gas_cloud_puff(
	canvas: CanvasItem,
	center: Vector2,
	width: float,
	height: float,
	smoke_seed: int,
	outer_color: Color,
	main: Color,
	core: Color,
	alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var outer_count: int = 3 + int(floor(_stable_unit(smoke_seed, 0, 0) * 2.0))
	for i in range(outer_count):
		var offset := Vector2(
			_stable_signed(smoke_seed, i, 1) * width * 0.48,
			_stable_signed(smoke_seed, i, 2) * height * 0.38
		)
		var rx: float = max(2.0, height * (0.30 + 0.32 * _stable_unit(smoke_seed, i, 3)))
		var ry: float = max(2.0, height * (0.26 + 0.28 * _stable_unit(smoke_seed, i, 4)))
		_draw_smoke_ellipse(canvas, center + offset, rx * (1.12 + width / max(1.0, height) * 0.10), ry, Color(outer_color.r, outer_color.g, outer_color.b, alpha * 0.34))

	var main_count: int = 3 + int(floor(_stable_unit(smoke_seed, 1, 0) * 2.0))
	for i in range(main_count):
		var offset := Vector2(
			_stable_signed(smoke_seed, i + 11, 1) * width * 0.32,
			_stable_signed(smoke_seed, i + 11, 2) * height * 0.26
		)
		var rx: float = max(2.0, height * (0.28 + 0.28 * _stable_unit(smoke_seed, i + 11, 3)))
		var ry: float = max(2.0, height * (0.25 + 0.26 * _stable_unit(smoke_seed, i + 11, 4)))
		_draw_smoke_ellipse(canvas, center + offset, rx * (1.04 + width / max(1.0, height) * 0.08), ry, Color(main.r, main.g, main.b, alpha * 0.58))

	var core_count: int = 1 + int(floor(_stable_unit(smoke_seed, 2, 0) * 2.0))
	for i in range(core_count):
		var offset := Vector2(
			_stable_signed(smoke_seed, i + 23, 1) * width * 0.18,
			_stable_signed(smoke_seed, i + 23, 2) * height * 0.16
		)
		var radius: float = max(1.5, height * (0.18 + 0.18 * _stable_unit(smoke_seed, i + 23, 3)))
		_draw_smoke_ellipse(canvas, center + offset, radius * (1.05 + width / max(1.0, height) * 0.06), radius, Color(core.r, core.g, core.b, alpha * 0.42))


func _draw_tear_gas_pillar_puff(
	canvas: CanvasItem,
	center: Vector2,
	width: float,
	height: float,
	smoke_seed: int,
	main: Color,
	core: Color,
	alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var count: int = 2 + int(floor(_stable_unit(smoke_seed, 0, 0) * 2.0))
	for i in range(count):
		var t: float = float(i) / float(max(1, count - 1))
		var offset := Vector2(
			_stable_signed(smoke_seed, i, 1) * width * 0.36,
			lerp(-height * 0.48, height * 0.34, t) + _stable_signed(smoke_seed, i, 2) * height * 0.13
		)
		var rx: float = max(1.5, width * (0.45 + 0.38 * _stable_unit(smoke_seed, i, 3)))
		var ry: float = max(2.0, height * (0.16 + 0.16 * _stable_unit(smoke_seed, i, 4)))
		_draw_smoke_ellipse(canvas, center + offset, rx, ry, Color(main.r, main.g, main.b, alpha * 0.58))

	for i in range(1):
		var offset := Vector2(
			_stable_signed(smoke_seed, i + 17, 1) * width * 0.24,
			_stable_signed(smoke_seed, i + 17, 2) * height * 0.22
		)
		var radius: float = max(1.5, width * (0.28 + 0.18 * _stable_unit(smoke_seed, i + 17, 3)))
		_draw_smoke_ellipse(canvas, center + offset, radius, radius * 0.86, Color(core.r, core.g, core.b, alpha * 0.40))


@warning_ignore("shadowed_global_identifier")
func _draw_tear_gas_wisp_puff(canvas: CanvasItem, center: Vector2, size: float, seed: int, main: Color, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var count: int = 1 + int(floor(_stable_unit(seed, 0, 0) * 2.0))
	for i in range(count):
		var radius: float = max(1.0, size * (0.62 + 0.28 * _stable_unit(seed, i, 1)))
		var offset := Vector2(
			_stable_signed(seed, i, 2) * size * 0.55,
			_stable_signed(seed, i, 3) * size * 0.45
		)
		canvas.draw_circle(center + offset, radius, Color(min(1.0, main.r + 0.08), min(1.0, main.g + 0.08), min(1.0, main.b + 0.05), alpha * 0.78))


func _draw_tear_gas_tendril_puff(
	canvas: CanvasItem,
	center: Vector2,
	width: float,
	height: float,
	velocity: Vector2,
	smoke_seed: int,
	main: Color,
	alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var direction: Vector2 = velocity.normalized()
	if direction.length() <= 0.001:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var count: int = 2 + int(floor(_stable_unit(smoke_seed, 0, 0) * 2.0))
	var tendril_color := Color(main.r, main.g, main.b, alpha * 0.58)
	for i in range(count):
		var t: float = float(i) / float(max(1, count - 1))
		var offset: Vector2 = direction * lerp(-width * 0.45, width * 0.45, t)
		offset += normal * _stable_signed(smoke_seed, i, 1) * height * 0.42
		var rx: float = max(1.4, height * (0.42 + 0.32 * _stable_unit(smoke_seed, i, 2)))
		var ry: float = max(1.2, height * (0.28 + 0.22 * _stable_unit(smoke_seed, i, 3)))
		canvas.draw_circle(center + offset, (rx + ry) * 0.5, tendril_color)


func _draw_smoke_ellipse(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	if color.a <= 0.0 or radius_x <= 0.5 or radius_y <= 0.5:
		return
	_draw_filled_ellipse(canvas, Rect2(center - Vector2(radius_x, radius_y), Vector2(radius_x * 2.0, radius_y * 2.0)), color)


func _get_tear_gas_smoke_tone(tone: int, layer: int, depth: float) -> Color:
	var base := Color(155.0 / 255.0, 152.0 / 255.0, 145.0 / 255.0, 1.0)
	if tone == 1:
		if layer == 0:
			base = Color(140.0 / 255.0, 125.0 / 255.0, 110.0 / 255.0, 1.0)
		elif layer == 1:
			base = Color(165.0 / 255.0, 148.0 / 255.0, 130.0 / 255.0, 1.0)
		else:
			base = Color(190.0 / 255.0, 175.0 / 255.0, 155.0 / 255.0, 1.0)
	elif tone == 2:
		if layer == 0:
			base = Color(120.0 / 255.0, 128.0 / 255.0, 135.0 / 255.0, 1.0)
		elif layer == 1:
			base = Color(145.0 / 255.0, 152.0 / 255.0, 160.0 / 255.0, 1.0)
		else:
			base = Color(170.0 / 255.0, 178.0 / 255.0, 185.0 / 255.0, 1.0)
	else:
		if layer == 0:
			base = Color(130.0 / 255.0, 128.0 / 255.0, 122.0 / 255.0, 1.0)
		elif layer == 1:
			base = Color(155.0 / 255.0, 152.0 / 255.0, 145.0 / 255.0, 1.0)
		else:
			base = Color(180.0 / 255.0, 178.0 / 255.0, 172.0 / 255.0, 1.0)
	var depth_offset: float = -0.06 + 0.12 * clamp(depth, 0.0, 1.0)
	return Color(
		clamp(base.r + depth_offset, 0.0, 1.0),
		clamp(base.g + depth_offset, 0.0, 1.0),
		clamp(base.b + depth_offset, 0.0, 1.0),
		1.0
	)


func _get_smoke_particle_seed(particle: Dictionary, center: Vector2) -> int:
	@warning_ignore("shadowed_global_identifier")
	var seed: int = int(particle.get("seed", 0))
	if seed == 0:
		seed = int(abs(center.x * 31.0 + center.y * 17.0 + float(particle.get("variant", 0)) * 101.0 + float(particle.get("phase", 0.0)) * 1000.0))
	return seed


@warning_ignore("shadowed_global_identifier")
func _stable_unit(seed: int, index: int, channel: int) -> float:
	var value: float = sin(float(seed % 100000) * 12.9898 + float(index) * 78.233 + float(channel) * 37.719) * 43758.5453
	return fposmod(value, 1.0)


@warning_ignore("shadowed_global_identifier")
func _stable_signed(seed: int, index: int, channel: int) -> float:
	return _stable_unit(seed, index, channel) * 2.0 - 1.0


func _draw_dynamites(canvas: CanvasItem, dynamites: Array, shake_offset: Vector2) -> void:
	if dynamites.is_empty():
		return
	var texture: Texture2D = _get_dynamite_icon_texture()
	for dynamite_value in dynamites:
		if not (dynamite_value is Dictionary):
			continue
		var dynamite: Dictionary = dynamite_value
		_draw_projectile_trail(canvas, dynamite.get("trail", []), shake_offset, 3.0, Color(1.0, 120.0 / 255.0, 80.0 / 255.0, 1.0), 0.24)

		var center: Vector2 = _get_vector2(dynamite, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(dynamite.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(DYNAMITE_DRAW_SIZE, DYNAMITE_DRAW_SIZE),
				angle
			)
		else:
			_draw_dynamite_fallback(canvas, center, angle, 1.0, false, 0.0)


func _draw_placed_dynamites(canvas: CanvasItem, placed_dynamites: Array, shake_offset: Vector2) -> void:
	if placed_dynamites.is_empty():
		return
	var texture: Texture2D = _get_dynamite_icon_texture()
	var font: Font = ThemeDB.fallback_font
	for placed_value in placed_dynamites:
		if not (placed_value is Dictionary):
			continue
		var placed: Dictionary = placed_value
		var center: Vector2 = _get_vector2(placed, "position", Vector2.ZERO) + shake_offset
		var countdown: float = float(placed.get("countdown_frames", DYNAMITE_COUNTDOWN_FRAMES))
		var pulse_timer: float = float(placed.get("pulse_timer", 0.0))
		var wobble: float = float(placed.get("wobble_angle", 0.0))
		if countdown < 180.0:
			var blink_speed: float = 0.2 if countdown < 60.0 else 0.1
			if int(pulse_timer * blink_speed) % 2 == 0:
				var warning_radius: float = 20.0 + 5.0 * sin(pulse_timer * 0.3)
				canvas.draw_circle(center, warning_radius, Color(1.0, 50.0 / 255.0, 50.0 / 255.0, 150.0 / 255.0), false, 3.0)

		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(DYNAMITE_PLACED_DRAW_SIZE, DYNAMITE_PLACED_DRAW_SIZE),
				wobble
			)
			_draw_dynamite_flame(canvas, center, wobble, DYNAMITE_PLACED_DRAW_SIZE / DYNAMITE_DRAW_SIZE, countdown)
		else:
			_draw_dynamite_fallback(canvas, center, wobble, DYNAMITE_PLACED_DRAW_SIZE / DYNAMITE_DRAW_SIZE, true, countdown)

		if font != null:
			var count_text: String = str(int(floor(countdown / 60.0)) + 1)
			var font_size: int = 24
			var text_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			var text_pos := center + Vector2(-text_size.x * 0.5, -30.0 + text_size.y * 0.35)
			var bg_rect := Rect2(text_pos - Vector2(5.0, text_size.y - 2.0), text_size + Vector2(10.0, 6.0))
			canvas.draw_rect(bg_rect, Color(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 200.0 / 255.0))
			canvas.draw_rect(bg_rect, Color(1.0, 100.0 / 255.0, 100.0 / 255.0, 1.0), false, 2.0)
			canvas.draw_string(font, text_pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)


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


func _draw_bananas(canvas: CanvasItem, banana_projectiles: Array, shake_offset: Vector2) -> void:
	if banana_projectiles.is_empty():
		return
	var texture: Texture2D = _get_banana_icon_texture()
	for banana_value in banana_projectiles:
		if not (banana_value is Dictionary):
			continue
		var banana: Dictionary = banana_value
		_draw_projectile_trail(canvas, banana.get("trail", []), shake_offset, 3.0, Color(1.0, 225.0 / 255.0, 70.0 / 255.0, 1.0), 0.24)

		var center: Vector2 = _get_vector2(banana, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(banana.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(BANANA_DRAW_SIZE, BANANA_DRAW_SIZE),
				angle
			)
		else:
			_draw_banana_fallback(canvas, center, angle, 1.0)


func _draw_landed_bananas(canvas: CanvasItem, landed_bananas: Array, shake_offset: Vector2) -> void:
	if landed_bananas.is_empty():
		return
	var texture: Texture2D = _get_banana_icon_texture()
	for landed_value in landed_bananas:
		if not (landed_value is Dictionary):
			continue
		var landed: Dictionary = landed_value
		var timer_frames: int = int(landed.get("timer_frames", BANANA_LAND_DURATION_FRAMES))
		@warning_ignore("integer_division")
		if timer_frames < 60 and int(timer_frames / 5) % 2 == 0:
			continue
		var center: Vector2 = _get_vector2(landed, "position", Vector2.ZERO) + shake_offset
		if not bool(landed.get("slip_triggered", false)):
			_draw_filled_ellipse(canvas, Rect2(center + Vector2(-30.0, 5.0), Vector2(60.0, 10.0)), Color(1.0, 1.0, 0.0, 80.0 / 255.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(BANANA_LANDED_DRAW_SIZE, BANANA_LANDED_DRAW_SIZE),
				15.0
			)
		else:
			_draw_banana_fallback(canvas, center, 15.0, BANANA_LANDED_DRAW_SIZE / BANANA_DRAW_SIZE)


func _draw_banana_particles(canvas: CanvasItem, banana_particles: Array, shake_offset: Vector2) -> void:
	if banana_particles.is_empty():
		return
	for particle_value in banana_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_frames: float = float(particle.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(particle.get("max_life_frames", 40.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= 0.0:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 5.0)) * life)
		var color: Color = _get_color(particle.get("color", Color(1.0, 225.0 / 255.0, 50.0 / 255.0, 1.0)), Color(1.0, 225.0 / 255.0, 50.0 / 255.0, 1.0))
		canvas.draw_circle(center, size, Color(color.r, color.g, color.b, color.a * life))


func _draw_soaps(canvas: CanvasItem, soap_projectiles: Array, shake_offset: Vector2) -> void:
	if soap_projectiles.is_empty():
		return
	var texture: Texture2D = _get_soap_icon_texture()
	for soap_value in soap_projectiles:
		if not (soap_value is Dictionary):
			continue
		var soap: Dictionary = soap_value
		_draw_projectile_trail(canvas, soap.get("trail", []), shake_offset, 3.0, Color(190.0 / 255.0, 230.0 / 255.0, 1.0, 1.0), 0.22)

		var center: Vector2 = _get_vector2(soap, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(soap.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(SOAP_DRAW_SIZE, SOAP_DRAW_SIZE),
				angle
			)
		else:
			_draw_soap_fallback(canvas, center, angle, 1.0)


func _draw_landed_soaps(canvas: CanvasItem, landed_soaps: Array, shake_offset: Vector2) -> void:
	if landed_soaps.is_empty():
		return
	var texture: Texture2D = _get_soap_icon_texture()
	for landed_value in landed_soaps:
		if not (landed_value is Dictionary):
			continue
		var landed: Dictionary = landed_value
		var timer_frames: int = int(landed.get("timer_frames", SOAP_LAND_DURATION_FRAMES))
		@warning_ignore("integer_division")
		if timer_frames < 60 and int(timer_frames / 5) % 2 == 0:
			continue
		var center: Vector2 = _get_vector2(landed, "position", Vector2.ZERO) + shake_offset
		var wobble: float = sin(float(landed.get("wobble_phase", 0.0))) * 3.0
		_draw_soap_puddle(canvas, center + Vector2(0.0, 8.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center + Vector2(wobble, 0.0),
				Vector2(SOAP_LANDED_DRAW_SIZE, SOAP_LANDED_DRAW_SIZE),
				wobble * 2.0
			)
		else:
			_draw_soap_fallback(canvas, center + Vector2(wobble, 0.0), wobble * 2.0, SOAP_LANDED_DRAW_SIZE / SOAP_DRAW_SIZE)


func _draw_soap_particles(canvas: CanvasItem, soap_particles: Array, shake_offset: Vector2) -> void:
	if soap_particles.is_empty():
		return
	for particle_value in soap_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var age: float = float(particle.get("age", 0.0))
		var lifetime: float = max(0.001, float(particle.get("lifetime", 0.8)))
		var life: float = clamp(1.0 - age / lifetime, 0.0, 1.0)
		if life <= SOAP_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var radius: float = max(1.0, float(particle.get("radius", 4.0))) * (0.65 + life * 0.35)
		var color: Color = _get_color(particle.get("color", Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0)), Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0))
		canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, color.a * 0.55 * life), false, max(1.0, radius * 0.22))
		if life > 0.28:
			canvas.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.28), max(1.0, radius * 0.24), Color(1.0, 1.0, 1.0, 0.38 * life))


func _draw_soap_foam_trails(canvas: CanvasItem, soap_foam_trails: Array, shake_offset: Vector2) -> void:
	if soap_foam_trails.is_empty():
		return
	for foam_value in soap_foam_trails:
		if not (foam_value is Dictionary):
			continue
		var foam: Dictionary = foam_value
		var life_frames: float = float(foam.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(foam.get("max_life_frames", 45.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= SOAP_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(foam, "position", Vector2.ZERO) + shake_offset
		var radius: float = max(1.0, float(foam.get("size", 5.0))) * (0.6 + 0.4 * life)
		canvas.draw_circle(center, radius, Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 0.46 * life), false, max(1.0, radius * 0.22))
		if life > 0.22:
			canvas.draw_circle(center, max(1.0, radius - 1.0), Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.15 * life))


func _draw_soap_puddle(canvas: CanvasItem, center: Vector2) -> void:
	_draw_filled_ellipse(canvas, Rect2(center - Vector2(35.0, 8.0), Vector2(70.0, 16.0)), Color(180.0 / 255.0, 220.0 / 255.0, 1.0, 0.24))
	_draw_filled_ellipse(canvas, Rect2(center - Vector2(25.0, 5.0), Vector2(50.0, 10.0)), Color(200.0 / 255.0, 235.0 / 255.0, 1.0, 0.18))


func _draw_spider_mines(canvas: CanvasItem, spider_mines: Array, shake_offset: Vector2) -> void:
	if spider_mines.is_empty():
		return
	for mine_value in spider_mines:
		if not (mine_value is Dictionary):
			continue
		var mine: Dictionary = mine_value
		var state: String = str(mine.get("state", "spawn"))
		var center: Vector2 = _get_vector2(mine, "position", Vector2.ZERO) + Vector2(0.0, float(mine.get("embed_depth", 0.0))) + shake_offset
		if state == "exploding":
			_draw_spider_mine_explosion(canvas, center, mine)
			continue

		if state == "embedding":
			var embed_progress: float = 1.0 - clamp(float(mine.get("embed_timer", 0.0)) / SPIDER_MINE_EMBED_DELAY_FRAMES, 0.0, 1.0)
			canvas.draw_circle(center, 28.0 * embed_progress, Color(220.0 / 255.0, 160.0 / 255.0, 1.0, 0.35 * embed_progress))

		if state == "armed":
			var armed_time: float = float(mine.get("armed_elapsed", 0.0))
			var flash_interval: float = SPIDER_MINE_FLASH_INTERVAL_FRAMES
			if armed_time >= SPIDER_MINE_SELF_DESTRUCT_FAST_FRAMES:
				flash_interval = max(1.0, SPIDER_MINE_FLASH_INTERVAL_FRAMES / 3.0)
			elif armed_time >= SPIDER_MINE_SELF_DESTRUCT_WARNING_FRAMES:
				flash_interval = max(2.0, SPIDER_MINE_FLASH_INTERVAL_FRAMES / 2.0)
			if armed_time >= SPIDER_MINE_SELF_DESTRUCT_WARNING_FRAMES and int(armed_time / flash_interval) % 2 == 0:
				canvas.draw_circle(center, 24.0 + 4.0 * sin(float(Time.get_ticks_msec()) * 0.02), Color(1.0, 80.0 / 255.0, 110.0 / 255.0, 0.42), false, 3.0)

		var drew_sheet: bool = _draw_spider_mine_sheet(canvas, center, mine, state)
		if not drew_sheet:
			_draw_spider_mine_legs(canvas, center, mine, state)
			var texture: Texture2D = _get_spider_mine_icon_texture()
			if texture != null:
				_draw_rotated_texture_region(
					canvas,
					texture,
					Rect2(Vector2.ZERO, texture.get_size()),
					center,
					Vector2(SPIDER_MINE_DRAW_SIZE, SPIDER_MINE_DRAW_SIZE),
					0.0
				)
			else:
				_draw_spider_mine_fallback(canvas, center, mine, state, float(mine.get("armed_elapsed", 0.0)), 0.0)

		var beacon_center: Vector2 = _get_spider_mine_beacon_center(center, drew_sheet)
		var flash_timer: float = float(mine.get("flash_timer", 0.0))
		if flash_timer > 0.0 and int(flash_timer / SPIDER_MINE_FLASH_INTERVAL_FRAMES) % 2 == 0:
			canvas.draw_circle(beacon_center, 13.0, Color(1.0, 200.0 / 255.0, 120.0 / 255.0, 0.55))
		if state == "armed":
			var pulse: float = 0.6 + 0.4 * sin(float(mine.get("armed_elapsed", 0.0)) * 0.18)
			canvas.draw_circle(beacon_center, max(3.0, 5.0 * pulse), Color(1.0, 110.0 / 255.0, 140.0 / 255.0, 0.88))


func _draw_spider_mine_sheet(canvas: CanvasItem, center: Vector2, mine: Dictionary, state: String) -> bool:
	var texture: Texture2D = _get_spider_mine_sheet_texture_for_state(state)
	if texture == null:
		return false
	var source_rect: Rect2 = _get_spider_mine_sheet_source_rect(
		texture,
		_get_spider_mine_sheet_frame(mine, state)
	)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	_draw_rotated_texture_region(
		canvas,
		texture,
		source_rect,
		center,
		Vector2(SPIDER_MINE_SHEET_DRAW_SIZE, SPIDER_MINE_SHEET_DRAW_SIZE),
		0.0
	)
	return true


func _get_spider_mine_sheet_texture_for_state(state: String) -> Texture2D:
	if state == "floor" or state == "wall":
		return _get_spider_mine_crawl_sheet_texture()
	if state == "spawn" or state == "embedding":
		return _get_spider_mine_deploy_sheet_texture()
	if state == "armed":
		return _get_spider_mine_installed_idle_sheet_texture()
	return _get_spider_mine_installed_idle_sheet_texture()


func _get_spider_mine_sheet_frame(mine: Dictionary, state: String) -> int:
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


func _get_spider_mine_loop_frame(elapsed_frames: float, frame_interval: float) -> int:
	return int(floor(max(0.0, elapsed_frames) / max(1.0, frame_interval))) % SPIDER_MINE_SHEET_FRAME_COUNT


func _get_spider_mine_sheet_source_rect(texture: Texture2D, frame_index: int) -> Rect2:
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


func _get_spider_mine_beacon_center(center: Vector2, using_sheet: bool) -> Vector2:
	if using_sheet:
		return center + Vector2(0.0, -SPIDER_MINE_SHEET_DRAW_SIZE * 0.26)
	return center + Vector2(0.0, -2.0)


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


func _draw_spider_mine_particles(canvas: CanvasItem, spider_mine_particles: Array, shake_offset: Vector2) -> void:
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


func _draw_boomerangs(canvas: CanvasItem, boomerangs: Array, shake_offset: Vector2) -> void:
	if boomerangs.is_empty():
		return
	for boomerang_value in boomerangs:
		if not (boomerang_value is Dictionary):
			continue
		var boomerang: Dictionary = boomerang_value
		var gauntlet_equipped: bool = bool(boomerang.get("gauntlet_equipped", false))
		var texture: Texture2D = _get_boomerang_icon_texture(gauntlet_equipped)
		var trail: Array = boomerang.get("trail", [])
		for i in range(max(0, trail.size() - 1)):
			var p1_value: Variant = trail[i]
			var p2_value: Variant = trail[i + 1]
			if not (p1_value is Vector2) or not (p2_value is Vector2):
				continue
			var ratio: float = float(i + 1) / float(max(1, trail.size()))
			var alpha: float = (0.10 + ratio * 0.34) if gauntlet_equipped else (0.08 + ratio * 0.24)
			var trail_color := Color(120.0 / 255.0, 225.0 / 255.0, 1.0, alpha) if gauntlet_equipped else Color(220.0 / 255.0, 165.0 / 255.0, 85.0 / 255.0, alpha)
			canvas.draw_line(p1_value + shake_offset, p2_value + shake_offset, trail_color, max(1.0, ratio * (6.0 if gauntlet_equipped else 5.0)))

		var center: Vector2 = _get_vector2(boomerang, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(boomerang.get("angle_degrees", 0.0))
		if gauntlet_equipped:
			canvas.draw_circle(center, 43.0, Color(80.0 / 255.0, 210.0 / 255.0, 1.0, 0.16))
			canvas.draw_circle(center, 28.0, Color(220.0 / 255.0, 1.0, 1.0, 0.08))
		elif str(boomerang.get("phase", "outgoing")) == "returning":
			canvas.draw_circle(center, 39.0, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 0.14))
			canvas.draw_circle(center, 31.0, Color(150.0 / 255.0, 220.0 / 255.0, 1.0, 0.10))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(BOOMERANG_DRAW_SIZE, BOOMERANG_DRAW_SIZE),
				angle
			)
		else:
			_draw_boomerang_fallback(canvas, center, angle, 1.0)


func _draw_boomerang_particles(canvas: CanvasItem, boomerang_particles: Array, shake_offset: Vector2) -> void:
	if boomerang_particles.is_empty():
		return
	for particle_value in boomerang_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var age: float = float(particle.get("age", 0.0))
		var lifetime: float = max(0.001, float(particle.get("lifetime", 0.6)))
		var life: float = clamp(1.0 - age / lifetime, 0.0, 1.0)
		if life <= 0.0:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var radius: float = max(1.0, float(particle.get("radius", 3.0))) * (0.45 + life * 0.55)
		var color: Color = _get_color(particle.get("color", Color(200.0 / 255.0, 130.0 / 255.0, 60.0 / 255.0, 1.0)), Color(200.0 / 255.0, 130.0 / 255.0, 60.0 / 255.0, 1.0))
		canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, color.a * life))


func _draw_dynamite_explosions(canvas: CanvasItem, dynamite_explosions: Array, shake_offset: Vector2) -> void:
	if dynamite_explosions.is_empty():
		return
	for explosion_value in dynamite_explosions:
		if not (explosion_value is Dictionary):
			continue
		var explosion: Dictionary = explosion_value
		var center: Vector2 = _get_vector2(explosion, "position", Vector2.ZERO) + shake_offset
		var progress: float = clamp(float(explosion.get("progress", 0.0)), 0.0, 1.0)
		var shockwave_radius: float = float(explosion.get("shockwave_radius", 0.0))
		if shockwave_radius > 5.0 and progress < 0.6:
			var shock_life: float = max(0.0, 1.0 - progress / 0.6)
			var width: float = max(2.0, 20.0 * (1.0 - progress))
			_draw_safe_circle_outline(canvas, center, shockwave_radius + 6.0, Color(1.0, 100.0 / 255.0, 30.0 / 255.0, 70.0 / 255.0 * shock_life), width + 5.0)
			_draw_safe_circle_outline(canvas, center, shockwave_radius - 18.0, Color(1.0, 220.0 / 255.0, 110.0 / 255.0, 150.0 / 255.0 * shock_life), max(2.0, width - 4.0))

		for wave_value in explosion.get("secondary_waves", []):
			if not (wave_value is Dictionary):
				continue
			var wave: Dictionary = wave_value
			var radius: float = float(wave.get("radius", 0.0))
			if radius > 0.0 and radius < DYNAMITE_EXPLOSION_RADIUS:
				var alpha: float = (150.0 / 255.0) * (1.0 - radius / DYNAMITE_EXPLOSION_RADIUS)
				_draw_safe_circle_outline(canvas, center, radius, Color(1.0, 180.0 / 255.0, 80.0 / 255.0, alpha), max(1.0, 8.0 - radius / 40.0))

		if progress < 0.25:
			var flash_progress: float = progress / 0.25
			var flash_radius: float = 150.0 * (1.0 - flash_progress * 0.7)
			var flash_alpha: float = 1.0 - flash_progress
			canvas.draw_circle(center, flash_radius, Color(1.0, 150.0 / 255.0, 50.0 / 255.0, 0.5 * flash_alpha))
			canvas.draw_circle(center, flash_radius * 0.35, Color(1.0, 1.0, 240.0 / 255.0, min(1.0, flash_alpha + 0.12)))

		_draw_dynamite_smoke_clouds(canvas, explosion.get("smoke_clouds", []), shake_offset)
		_draw_dynamite_sparks(canvas, explosion.get("sparks", []), shake_offset)
		_draw_dynamite_fire_particles(canvas, explosion.get("particles", []), shake_offset)


func _draw_safe_circle_outline(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 1.0 or width <= 0.0 or color.a <= 0.0:
		return
	var safe_width: float = min(width, max(1.0, radius * 0.85))
	canvas.draw_circle(center, radius, color, false, safe_width)


func _draw_dynamite_smoke_clouds(canvas: CanvasItem, smoke_clouds: Array, shake_offset: Vector2) -> void:
	for cloud_value in smoke_clouds:
		if not (cloud_value is Dictionary):
			continue
		var cloud: Dictionary = cloud_value
		var life_frames: float = float(cloud.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(cloud.get("max_life_frames", 36.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= DYNAMITE_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(cloud, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(cloud.get("size", 20.0)))
		for i in range(2):
			var radius: float = max(1.0, size - float(i) * size / 2.5)
			var gray: float = (62.0 + float(i) * 32.0) / 255.0
			var alpha: float = (120.0 / 255.0) * life / float(i + 1)
			canvas.draw_circle(center, radius, Color(gray, gray, gray, alpha))


func _draw_dynamite_sparks(canvas: CanvasItem, sparks: Array, shake_offset: Vector2) -> void:
	for spark_value in sparks:
		if not (spark_value is Dictionary):
			continue
		var spark: Dictionary = spark_value
		var life_frames: float = float(spark.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(spark.get("max_life_frames", 20.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= DYNAMITE_PARTICLE_ALPHA_CUTOFF:
			continue
		var pos: Vector2 = _get_vector2(spark, "position", Vector2.ZERO) + shake_offset
		var vel: Vector2 = _get_vector2(spark, "velocity", Vector2.ZERO)
		var tail: Vector2 = pos - vel * 0.3
		var color := Color(1.0, 230.0 / 255.0, 180.0 / 255.0, life)
		canvas.draw_line(pos, tail, Color(color.r, color.g, color.b, color.a * 0.5), 1.0)
		canvas.draw_circle(pos, 2.5, color)


func _draw_dynamite_fire_particles(canvas: CanvasItem, particles: Array, shake_offset: Vector2) -> void:
	for particle_value in particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_frames: float = float(particle.get("life_frames", 0.0))
		var max_life_frames: float = max(1.0, float(particle.get("max_life_frames", 30.0)))
		var life: float = clamp(life_frames / max_life_frames, 0.0, 1.0)
		if life <= DYNAMITE_PARTICLE_ALPHA_CUTOFF:
			continue
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)))
		var color_type: String = str(particle.get("color_type", "fire"))
		var color := Color(1.0, 120.0 / 255.0 + 100.0 / 255.0 * life, 30.0 / 255.0 * life, life * life)
		if color_type == "spark":
			color = Color(1.0, 230.0 / 255.0 + 25.0 / 255.0 * life, 180.0 / 255.0 + 75.0 / 255.0 * life, life * life)
		elif color_type == "ember":
			color = Color(200.0 / 255.0 + 55.0 / 255.0 * life, 60.0 / 255.0 + 60.0 / 255.0 * life, 20.0 / 255.0 * life, life * life)
		if color.a > 0.08:
			canvas.draw_circle(center, size + 1.5, Color(color.r, color.g * 0.5, color.b * 0.5, color.a * 0.28))
		canvas.draw_circle(center, size, color)


func _draw_dynamite_fallback(
	canvas: CanvasItem,
	center: Vector2,
	angle_degrees: float,
	scale: float,
	fuse_lit: bool,
	countdown: float
) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var stick_offsets := [-9.0, 0.0, 9.0]
	var stick_lengths := [22.0, 26.0, 22.0]
	var stick_widths := [8.0, 10.0, 8.0]
	for i in range(stick_offsets.size()):
		var x_offset: float = float(stick_offsets[i]) * scale
		var half_len: float = float(stick_lengths[i]) * 0.5 * scale
		var width: float = float(stick_widths[i]) * scale
		var top: Vector2 = _rotated_local(center, Vector2(x_offset, -half_len), angle)
		var bottom: Vector2 = _rotated_local(center, Vector2(x_offset, half_len), angle)
		canvas.draw_line(top, bottom, Color(150.0 / 255.0, 30.0 / 255.0, 30.0 / 255.0, 1.0), width + 2.0)
		canvas.draw_circle(top, width * 0.5 + 1.0, Color(150.0 / 255.0, 30.0 / 255.0, 30.0 / 255.0, 1.0))
		canvas.draw_circle(bottom, width * 0.5 + 1.0, Color(150.0 / 255.0, 30.0 / 255.0, 30.0 / 255.0, 1.0))
		canvas.draw_line(top, bottom, Color(200.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 1.0), width)
		var highlight_top: Vector2 = _rotated_local(center, Vector2(x_offset - width * 0.18, -half_len + 1.0 * scale), angle)
		var highlight_bottom: Vector2 = _rotated_local(center, Vector2(x_offset - width * 0.18, half_len - 1.0 * scale), angle)
		canvas.draw_line(highlight_top, highlight_bottom, Color(240.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 0.75), max(1.0, width * 0.34))

	for y_offset in [-6.0, 6.0]:
		var left: Vector2 = _rotated_local(center, Vector2(-13.0 * scale, y_offset * scale), angle)
		var right: Vector2 = _rotated_local(center, Vector2(13.0 * scale, y_offset * scale), angle)
		canvas.draw_line(left, right, Color(139.0 / 255.0, 90.0 / 255.0, 43.0 / 255.0, 1.0), max(2.0, 4.0 * scale))

	var fuse_start: Vector2 = _rotated_local(center, Vector2(0.0, -14.0 * scale), angle)
	var fuse_end: Vector2 = _rotated_local(center, Vector2(0.0, -22.0 * scale), angle)
	canvas.draw_line(fuse_start, fuse_end, Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0, 1.0), max(1.0, 2.0 * scale))
	if fuse_lit:
		_draw_dynamite_flame(canvas, center, angle_degrees, scale, countdown)


func _draw_dynamite_flame(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float, countdown: float) -> void:
	var fuse_progress: float = clamp(countdown / DYNAMITE_COUNTDOWN_FRAMES, 0.0, 1.0)
	var local_y: float = lerp(-14.0, -22.0, fuse_progress) * scale
	var flame_center: Vector2 = _rotated_local(center, Vector2(0.0, local_y), deg_to_rad(angle_degrees))
	var flame_intensity: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.02)
	canvas.draw_circle(flame_center, 4.0 * scale, Color(flame_intensity, 150.0 / 255.0 * flame_intensity, 50.0 / 255.0, 1.0))
	canvas.draw_circle(flame_center, 2.0 * scale, Color(1.0, 1.0, 150.0 / 255.0, 1.0))
	for i in range(1):
		var jitter := Vector2(sin(countdown * 0.31 + float(i)) * 2.4, cos(countdown * 0.27 + float(i)) * 1.6)
		canvas.draw_circle(
			flame_center + jitter * scale,
			max(1.0, scale),
			Color(1.0, 200.0 / 255.0, 100.0 / 255.0, 0.9)
		)


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


func _draw_tear_gas_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var body_top: Vector2 = _rotated_local(center, Vector2(0.0, -11.0 * scale), angle)
	var body_bottom: Vector2 = _rotated_local(center, Vector2(0.0, 11.0 * scale), angle)
	canvas.draw_line(body_top, body_bottom, Color(0.34, 0.36, 0.32, 1.0), max(5.0, 9.0 * scale))
	canvas.draw_line(body_top, body_bottom, Color(0.58, 0.62, 0.52, 0.95), max(2.0, 4.0 * scale))
	canvas.draw_circle(body_top, 5.0 * scale, Color(0.22, 0.24, 0.22, 1.0))
	canvas.draw_circle(body_bottom, 5.0 * scale, Color(0.20, 0.21, 0.18, 1.0))
	canvas.draw_circle(_rotated_local(center, Vector2(4.0 * scale, -5.0 * scale), angle), 2.0 * scale, Color(0.95, 0.08, 0.04, 0.95))


func _draw_boomerang_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var spread: float = deg_to_rad(75.0)
	var arm_length: float = 19.0 * scale
	var arm_width: float = max(2.0, 5.0 * scale)
	var a1: float = angle - spread * 0.5
	var a2: float = angle + spread * 0.5
	var end1: Vector2 = center + Vector2(cos(a1), sin(a1)) * arm_length
	var end2: Vector2 = center + Vector2(cos(a2), sin(a2)) * arm_length
	canvas.draw_line(center, end1, Color(90.0 / 255.0, 50.0 / 255.0, 20.0 / 255.0, 1.0), arm_width + 2.0)
	canvas.draw_line(center, end2, Color(90.0 / 255.0, 50.0 / 255.0, 20.0 / 255.0, 1.0), arm_width + 2.0)
	canvas.draw_line(center, end1, Color(170.0 / 255.0, 110.0 / 255.0, 55.0 / 255.0, 1.0), arm_width)
	canvas.draw_line(center, end2, Color(215.0 / 255.0, 165.0 / 255.0, 85.0 / 255.0, 1.0), arm_width)
	canvas.draw_circle(center, 4.0 * scale, Color(1.0, 210.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_banana_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var angle: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var points := PackedVector2Array()
	for i in range(16):
		var t: float = float(i) / 15.0
		var local_x: float = lerp(-20.0, 20.0, t) * scale
		var local_y: float = (-10.0 * sin(t * PI)) * scale
		points.append(center + Vector2(
			local_x * cos_a - local_y * sin_a,
			local_x * sin_a + local_y * cos_a
		))
	for i in range(15, -1, -1):
		var t: float = float(i) / 15.0
		var local_x: float = lerp(-20.0, 20.0, t) * scale
		var local_y: float = (-4.0 * sin(t * PI) + 8.0) * scale
		points.append(center + Vector2(
			local_x * cos_a - local_y * sin_a,
			local_x * sin_a + local_y * cos_a
		))
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, Color(227.0 / 255.0, 189.0 / 255.0, 52.0 / 255.0, 1.0))
	var stem: Vector2 = center + Vector2(-20.0 * scale * cos_a, -20.0 * scale * sin_a)
	var tip: Vector2 = center + Vector2(20.0 * scale * cos_a - 2.0 * scale * sin_a, 20.0 * scale * sin_a + 2.0 * scale * cos_a)
	canvas.draw_circle(stem, 3.0 * scale, Color(154.0 / 255.0, 165.0 / 255.0, 67.0 / 255.0, 1.0))
	canvas.draw_circle(tip, 2.5 * scale, Color(89.0 / 255.0, 60.0 / 255.0, 31.0 / 255.0, 1.0))


func _draw_soap_fallback(canvas: CanvasItem, center: Vector2, angle_degrees: float, scale: float) -> void:
	var body_size := Vector2(25.0, 17.0) * scale
	var angle: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var corners := [
		Vector2(-body_size.x * 0.5, -body_size.y * 0.5),
		Vector2(body_size.x * 0.5, -body_size.y * 0.5),
		Vector2(body_size.x * 0.5, body_size.y * 0.5),
		Vector2(-body_size.x * 0.5, body_size.y * 0.5),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(center + Vector2(
			corner.x * cos_a - corner.y * sin_a,
			corner.x * sin_a + corner.y * cos_a
		))
	canvas.draw_polygon(points, PackedColorArray([
		Color(140.0 / 255.0, 200.0 / 255.0, 240.0 / 255.0, 1.0),
		Color(180.0 / 255.0, 225.0 / 255.0, 1.0, 1.0),
		Color(110.0 / 255.0, 170.0 / 255.0, 220.0 / 255.0, 1.0),
		Color(140.0 / 255.0, 200.0 / 255.0, 240.0 / 255.0, 1.0),
	]))
	canvas.draw_line(points[0].lerp(points[1], 0.25), points[0].lerp(points[1], 0.75), Color(230.0 / 255.0, 250.0 / 255.0, 1.0, 0.95), max(1.0, 2.0 * scale))
	canvas.draw_circle(center + Vector2(13.0, -8.0) * scale, 3.0 * scale, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.75), false, max(1.0, scale))
	canvas.draw_circle(center + Vector2(-14.0, -5.0) * scale, 2.0 * scale, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.75), false, max(1.0, scale))


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
	if dynamite_icon_texture == null:
		dynamite_icon_texture = ProjectResourceLoader.load_texture(
			DYNAMITE_ICON_PATH,
			"Missing dynamite icon at %s",
			"Failed to load dynamite icon at %s"
		)
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
	if spider_mine_icon_texture == null:
		spider_mine_icon_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_ICON_PATH,
			"Missing spider mine icon at %s",
			"Failed to load spider mine icon at %s"
		)
	return spider_mine_icon_texture


func _get_spider_mine_crawl_sheet_texture() -> Texture2D:
	if spider_mine_crawl_sheet_texture == null:
		spider_mine_crawl_sheet_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_CRAWL_SHEET_PATH,
			"Missing spider mine crawl sheet at %s",
			"Failed to load spider mine crawl sheet at %s"
		)
	return spider_mine_crawl_sheet_texture


func _get_spider_mine_installed_idle_sheet_texture() -> Texture2D:
	if spider_mine_installed_idle_sheet_texture == null:
		spider_mine_installed_idle_sheet_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_INSTALLED_IDLE_SHEET_PATH,
			"Missing spider mine installed idle sheet at %s",
			"Failed to load spider mine installed idle sheet at %s"
		)
	return spider_mine_installed_idle_sheet_texture


func _get_spider_mine_deploy_sheet_texture() -> Texture2D:
	if spider_mine_deploy_sheet_texture == null:
		spider_mine_deploy_sheet_texture = ProjectResourceLoader.load_texture(
			SPIDER_MINE_DEPLOY_SHEET_PATH,
			"Missing spider mine deploy sheet at %s",
			"Failed to load spider mine deploy sheet at %s"
		)
	return spider_mine_deploy_sheet_texture


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
